-- Public help center and privacy-safe support without a PasKluis account.

create table if not exists public.help_faqs (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'Algemeen',
  question text not null,
  answer text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.help_faqs enable row level security;

drop policy if exists "Everyone reads active help FAQs" on public.help_faqs;
create policy "Everyone reads active help FAQs"
  on public.help_faqs for select
  using (is_active or public.is_admin());

drop policy if exists "Admins manage help FAQs" on public.help_faqs;
create policy "Admins manage help FAQs"
  on public.help_faqs for all
  using (public.is_admin())
  with check (public.is_admin());

grant select on public.help_faqs to anon, authenticated;
grant insert, update, delete on public.help_faqs to authenticated;

insert into public.help_faqs (category, question, answer, sort_order)
select seed.category, seed.question, seed.answer, seed.sort_order
from (values
  ('Kaarten toevoegen', 'Hoe voeg ik een kaart toe?', 'Tik rechtsboven op +. Kies daarna een klantenkaart, QR-code of cadeaukaart. Je kunt scannen, handmatig invoeren of een foto of screenshot importeren.', 10),
  ('Kaarten toevoegen', 'Kan ik een kaart uit een screenshot halen?', 'Ja. Kies bij het toevoegen voor importeren en selecteer de screenshot of foto. Controleer de herkende code altijd voordat je de kaart opslaat.', 20),
  ('Privacy', 'Waar worden mijn kaarten bewaard?', 'Je gewone kaarten, barcodes, pincodes en afbeeldingen blijven lokaal op je telefoon. Ze worden niet automatisch naar PasKluis of het beheer geüpload.', 30),
  ('Locatie', 'Wordt mijn locatie opgeslagen?', 'Alleen wanneer jij locatiekaarten inschakelt onthoudt PasKluis lokaal waar je een kaart hebt gebruikt. De precieze locatie en locatiegeschiedenis worden niet naar het beheer gestuurd.', 40),
  ('Delen', 'Hoe werkt een gedeelde kaart?', 'De verzender heeft Plus nodig. Zonder Plus kan de ontvanger de kaart bekijken. Hebben jullie allebei Plus, dan kunnen jullie de kaart allebei bijwerken.', 50),
  ('Delen', 'Wordt de pincode van een cadeaukaart meegedeeld?', 'Ja. Een cadeaukaart wordt altijd volledig gedeeld, inclusief pincode of krascode. PasKluis waarschuwt hiervoor voordat je deelt.', 60),
  ('PasKluis Plus', 'Wat krijg ik met PasKluis Plus?', 'Met Plus bewaar je onbeperkt cadeaukaarten en kun je klanten- en cadeaukaarten delen. Plus kost € 2 eenmalig en is geen abonnement.', 70),
  ('Account', 'Heb ik een account nodig?', 'Nee. Klantenkaarten, QR-codes en één cadeaukaart kun je zonder account gebruiken. Een account is nodig voor Plus, delen en het terugzien van persoonlijke supportgesprekken op meerdere momenten.', 80)
) as seed(category, question, answer, sort_order)
where not exists (
  select 1 from public.help_faqs existing
  where lower(existing.question) = lower(seed.question)
);

alter table public.support_threads
  alter column user_id drop not null,
  add column if not exists guest_name text,
  add column if not exists guest_email text,
  add column if not exists guest_token_hash text;

alter table public.support_messages
  alter column sender_id drop not null,
  add column if not exists sender_kind text not null default 'user';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'support_messages_sender_kind_check'
  ) then
    alter table public.support_messages
      add constraint support_messages_sender_kind_check
      check (sender_kind in ('user', 'guest', 'staff'));
  end if;
end $$;

create index if not exists support_threads_guest_token_idx
  on public.support_threads (guest_token_hash)
  where guest_token_hash is not null;

create or replace function public.create_guest_support_thread(
  p_token text,
  p_name text,
  p_email text,
  p_subject text,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if char_length(coalesce(p_token, '')) < 32 then
    raise exception 'Ongeldige contactcode.';
  end if;
  if char_length(trim(coalesce(p_name, ''))) not between 2 and 100 then
    raise exception 'Vul je naam in.';
  end if;
  if char_length(trim(coalesce(p_email, ''))) not between 5 and 254
     or position('@' in p_email) = 0 then
    raise exception 'Vul een geldig e-mailadres in.';
  end if;
  if char_length(trim(coalesce(p_subject, ''))) not between 2 and 100 then
    raise exception 'Vul een onderwerp in.';
  end if;
  if char_length(trim(coalesce(p_message, ''))) not between 1 and 5000 then
    raise exception 'Vul een bericht in.';
  end if;

  insert into public.support_threads (
    user_id, guest_name, guest_email, guest_token_hash, subject
  ) values (
    null,
    trim(p_name),
    lower(trim(p_email)),
    encode(extensions.digest(p_token, 'sha256'), 'hex'),
    trim(p_subject)
  ) returning id into new_id;

  insert into public.support_messages (
    thread_id, sender_id, sender_kind, message
  ) values (
    new_id, null, 'guest', trim(p_message)
  );

  return new_id;
end;
$$;

create or replace function public.guest_support_threads(p_token text)
returns table (
  id uuid,
  subject text,
  status public.support_status,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.subject, t.status, t.created_at, t.updated_at
  from public.support_threads t
  where char_length(coalesce(p_token, '')) >= 32
    and t.guest_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  order by t.updated_at desc;
$$;

create or replace function public.guest_support_messages(
  p_token text,
  p_thread_id uuid
)
returns table (
  id uuid,
  sender_id uuid,
  message text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.sender_id, m.message, m.created_at
  from public.support_messages m
  join public.support_threads t on t.id = m.thread_id
  where t.id = p_thread_id
    and char_length(coalesce(p_token, '')) >= 32
    and t.guest_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  order by m.created_at;
$$;

create or replace function public.send_guest_support_message(
  p_token text,
  p_thread_id uuid,
  p_message text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(trim(coalesce(p_message, ''))) not between 1 and 5000 then
    raise exception 'Vul een bericht in.';
  end if;
  if not exists (
    select 1 from public.support_threads t
    where t.id = p_thread_id
      and t.status <> 'closed'
      and char_length(coalesce(p_token, '')) >= 32
      and t.guest_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  ) then
    raise exception 'Dit gesprek is niet beschikbaar.';
  end if;
  insert into public.support_messages (
    thread_id, sender_id, sender_kind, message
  ) values (p_thread_id, null, 'guest', trim(p_message));
end;
$$;

grant execute on function public.create_guest_support_thread(text, text, text, text, text)
  to anon, authenticated;
grant execute on function public.guest_support_threads(text)
  to anon, authenticated;
grant execute on function public.guest_support_messages(text, uuid)
  to anon, authenticated;
grant execute on function public.send_guest_support_message(text, uuid, text)
  to anon, authenticated;

drop trigger if exists audit_help_faqs on public.help_faqs;
create trigger audit_help_faqs
  after insert or update or delete on public.help_faqs
  for each row execute function public.write_admin_audit_log();
