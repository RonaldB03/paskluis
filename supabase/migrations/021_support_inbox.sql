begin;
alter table public.support_threads add column if not exists locale text not null default 'nl'
 check(locale in ('nl','en'));
alter table public.support_threads add column if not exists client_context jsonb not null default '{}';
alter table public.support_threads add column if not exists response_due_at timestamptz;
alter table public.support_threads add column if not exists last_customer_message_at timestamptz;
alter table public.support_messages drop constraint support_messages_sender_kind_check;
alter table public.support_messages add constraint support_messages_sender_kind_check
 check(sender_kind in ('user','guest','staff','automatic'));
create unique index support_one_ack_per_thread on public.support_messages(thread_id) where sender_kind='automatic';

create table public.support_canned_replies (
 id uuid primary key default gen_random_uuid(), title text not null,
 body_nl text not null, body_en text not null default '', active boolean not null default true
);
alter table public.support_canned_replies enable row level security;
create policy "Staff manage reply templates" on public.support_canned_replies
 for all to authenticated using(public.is_staff()) with check(public.is_staff());
grant select,insert,update,delete on public.support_canned_replies to authenticated;
insert into public.support_canned_replies(title,body_nl,body_en) values
 ('Meer informatie','Bedankt voor je bericht. Kun je aangeven welke stappen je hebt uitgevoerd en wat je op het scherm ziet? Deel geen wachtwoorden, kaartnummers of pincodes.','Thank you for your message. Could you describe the steps you took and what you see on screen? Do not share passwords, card numbers or PINs.'),
 ('Opgelost','Fijn dat het weer werkt! Heb je nog een vraag? Je kunt ons altijd opnieuw een bericht sturen. Groetjes, team PasKluis','Glad it works again! If you have another question, you can always send us a new message. Best wishes, team PasKluis');
create table public.service_incidents (
 id uuid primary key default gen_random_uuid(), title_nl text not null, body_nl text not null,
 title_en text not null default '', body_en text not null default '', active boolean not null default true,
 updated_at timestamptz not null default now()
);
alter table public.service_incidents enable row level security;
create policy "Read active service notices" on public.service_incidents for select using(active or public.is_staff());
create policy "Staff manage service notices" on public.service_incidents for all to authenticated using(public.is_staff()) with check(public.is_staff());
grant select on public.service_incidents to anon,authenticated;
grant insert,update,delete on public.service_incidents to authenticated;

-- Payloads contain identifiers only, never card codes, PINs or conversation text.
create table public.notification_outbox (
 id bigint generated always as identity primary key,
 event_key text not null unique, event_type text not null check(event_type in ('card_shared','support_reply','support_question')),
 recipient_id uuid references auth.users(id) on delete cascade,
 thread_id uuid references public.support_threads(id) on delete cascade,
 membership_id uuid references public.card_share_members(id) on delete cascade,
 created_at timestamptz not null default now(), available_at timestamptz not null default now(),
 attempts int not null default 0, locked_until timestamptz, delivered_at timestamptz,
 last_error text, push_done boolean not null default false, email_done boolean not null default false
);
alter table public.notification_outbox enable row level security;
create policy "Staff read delivery status" on public.notification_outbox for select to authenticated using(public.is_staff());
grant select on public.notification_outbox to authenticated;
create index notification_outbox_due on public.notification_outbox(available_at) where delivered_at is null;
create or replace function public.claim_notification_jobs() returns setof public.notification_outbox
language sql security definer set search_path='' as $$
 update public.notification_outbox set attempts=attempts+1,locked_until=now()+interval '5 minutes'
 where id in (select id from public.notification_outbox where delivered_at is null
 and attempts<8 and available_at<=now() and (locked_until is null or locked_until<now())
 order by id for update skip locked limit 25) returning *;
$$;
revoke all on function public.claim_notification_jobs() from public,anon,authenticated;
grant execute on function public.claim_notification_jobs() to service_role;

create or replace function public.validate_support_message() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if pg_trigger_depth()>1 and new.sender_kind='automatic' then return new; end if;
 if new.sender_id is null then new.sender_kind:='guest';
 elsif new.sender_id=auth.uid() and public.is_staff() then new.sender_kind:='staff';
 else new.sender_kind:='user'; end if;
 if exists(select 1 from public.support_threads where id=new.thread_id and status='closed') then
  raise exception 'CONVERSATION_CLOSED'; end if;
 if (select count(*) from public.support_messages where thread_id=new.thread_id and created_at>now()-interval '1 minute')>=12 then
  raise exception 'TOO_MANY_MESSAGES'; end if;
 return new;
end; $$;
create trigger validate_support_message before insert on public.support_messages
for each row execute function public.validate_support_message();

create or replace function public.update_support_thread_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare t public.support_threads; ack text;
begin
 if new.sender_kind='automatic' then return new; end if;
 select * into t from public.support_threads where id=new.thread_id for update;
 if new.sender_kind='staff' then
  update public.support_threads set updated_at=now(),status='waiting_for_user',
   assigned_to=coalesce(assigned_to,new.sender_id),
   first_responded_at=coalesce(first_responded_at,now()),response_due_at=null where id=t.id;
  insert into public.notification_outbox(event_key,event_type,recipient_id,thread_id)
   values('support-reply:'||new.id,'support_reply',t.user_id,t.id) on conflict do nothing;
 else
  update public.support_threads set updated_at=now(),status='open',last_customer_message_at=now(),
   response_due_at=coalesce(response_due_at,now()+interval '12 hours') where id=t.id;
  -- Existing conversations must not get an unsolicited retrospective acknowledgement.
  if (select count(*) from public.support_messages where thread_id=t.id)=1 then
   ack:=case when t.locale='en' then
    'Thank you for your message! We aim to reply personally within 12 hours. You will receive a notification when our reply is ready. Best wishes, team PasKluis'
    else 'Bedankt voor je bericht! We streven ernaar om je vraag binnen 12 uur persoonlijk te beantwoorden. Je ontvangt een melding zodra er een antwoord voor je klaarstaat. Groetjes, team PasKluis' end;
   insert into public.support_messages(thread_id,sender_id,sender_kind,message,created_at)
    values(t.id,null,'automatic',ack,clock_timestamp()) on conflict do nothing;
  end if;
  insert into public.notification_outbox(event_key,event_type,thread_id)
   values('support-question:'||new.id,'support_question',t.id) on conflict do nothing;
 end if;
 return new;
end; $$;

create or replace function public.create_support_conversation(
 p_token text,p_name text,p_email text,p_subject text,p_message text,
 p_category text default 'overig',p_locale text default 'nl',p_context jsonb default '{}'
) returns uuid language plpgsql security definer set search_path='' as $$
declare new_id uuid; uid uuid:=auth.uid(); token_hash text;
begin
 if length(trim(coalesce(p_subject,''))) not between 2 and 100 or
 length(trim(coalesce(p_message,''))) not between 1 and 5000 then raise exception 'INVALID_MESSAGE'; end if;
 if p_locale not in ('nl','en') or p_category not in ('account','plus','kaarten','delen','meldingen','import','privacy','overig') then raise exception 'INVALID_CATEGORY'; end if;
 if uid is null then
  if length(coalesce(p_token,'')) not between 32 and 256 or length(trim(coalesce(p_name,''))) not between 2 and 100
   or length(p_email)>254 or p_email!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'INVALID_CONTACT'; end if;
  token_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
 end if;
 if (select count(*) from public.support_threads where created_at>now()-interval '1 hour' and
 (user_id=uid or guest_email=lower(trim(p_email)) or guest_token_hash=token_hash))>=5 then raise exception 'TOO_MANY_REQUESTS'; end if;
 insert into public.support_threads(user_id,guest_name,guest_email,guest_token_hash,subject,category,locale,client_context)
 values(uid,case when uid is null then trim(p_name) end,case when uid is null then lower(trim(p_email)) end,token_hash,
 trim(p_subject),p_category,p_locale,jsonb_build_object('platform',left(p_context->>'platform',20),'version',left(p_context->>'version',30))) returning id into new_id;
 insert into public.support_messages(thread_id,sender_id,sender_kind,message) values(new_id,uid,case when uid is null then 'guest' else 'user' end,trim(p_message));
 return new_id;
end; $$;
revoke all on function public.create_support_conversation(text,text,text,text,text,text,text,jsonb) from public;
grant execute on function public.create_support_conversation(text,text,text,text,text,text,text,jsonb) to anon,authenticated;

create or replace function public.guest_support_messages_v2(p_token text,p_thread_id uuid)
returns table(id uuid,sender_id uuid,sender_kind text,message text,created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select m.id,m.sender_id,m.sender_kind,m.message,m.created_at from public.support_messages m
 join public.support_threads t on t.id=m.thread_id where t.id=p_thread_id
 and length(coalesce(p_token,'')) between 32 and 256
 and t.guest_token_hash=encode(extensions.digest(p_token,'sha256'),'hex') order by m.created_at,m.id;
$$;
revoke all on function public.guest_support_messages_v2(text,uuid) from public;
grant execute on function public.guest_support_messages_v2(text,uuid) to anon,authenticated;

create or replace function public.queue_shared_card_notification() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.revoked_at is null and new.removed_by_recipient_at is null and
 (tg_op='INSERT' or old.revoked_at is not null or old.removed_by_recipient_at is not null) then
  insert into public.notification_outbox(event_key,event_type,recipient_id,membership_id)
  values('card-shared:'||new.id||':'||gen_random_uuid(),'card_shared',new.recipient_id,new.id);
 end if;
 return new;
end; $$;
create trigger queue_shared_card_notification after insert or update on public.card_share_members
for each row execute function public.queue_shared_card_notification();
-- Start the target timer for existing unanswered conversations without sending messages.
update public.support_threads set response_due_at=updated_at+interval '12 hours'
where status='open' and response_due_at is null;

-- Guest push registration uses the same high-entropy conversation credential.
create table public.guest_support_push_tokens(
 guest_token_hash text primary key,token text not null unique,locale text not null default 'nl',updated_at timestamptz not null default now()
);
alter table public.guest_support_push_tokens enable row level security;
revoke all on public.guest_support_push_tokens from anon,authenticated;
create or replace function public.register_guest_support_push(p_token text,p_push_token text,p_locale text)
returns void language plpgsql security definer set search_path='' as $$
declare h text:=encode(extensions.digest(p_token,'sha256'),'hex');
begin
 if length(coalesce(p_token,'')) not between 32 and 256 or length(coalesce(p_push_token,'')) not between 20 and 4096 then raise exception 'INVALID_TOKEN';end if;
 if not exists(select 1 from public.support_threads where guest_token_hash=h) then raise exception 'NO_CONVERSATION';end if;
 delete from public.guest_support_push_tokens where token=p_push_token and guest_token_hash<>h;
 insert into public.guest_support_push_tokens(guest_token_hash,token,locale) values(h,p_push_token,case when p_locale='en' then 'en' else 'nl' end)
 on conflict(guest_token_hash) do update set token=excluded.token,locale=excluded.locale,updated_at=now();
end; $$;
revoke all on function public.register_guest_support_push(text,text,text) from public;
grant execute on function public.register_guest_support_push(text,text,text) to anon,authenticated;

commit;
