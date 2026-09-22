begin;

-- Snapshot the public staff name when replying, never a login/email address.
alter table public.support_messages add column if not exists sender_name text;
-- Earlier staff-owned app questions were misclassified as replies. An opening
-- message by the thread owner, created with that thread, is a customer question.
-- Preserve the original text/time and never send a retrospective notification.
with repaired as (
 update public.support_messages m set sender_kind = 'user', sender_name = null
 from public.support_threads t
 where m.thread_id = t.id and m.sender_id = t.user_id
  and m.sender_kind = 'staff' and m.created_at = t.created_at
  and not exists (select 1 from public.support_messages earlier
    where earlier.thread_id = t.id and earlier.created_at < m.created_at)
 returning m.thread_id
)
update public.support_threads t set
 first_responded_at = (select min(m.created_at) from public.support_messages m
   where m.thread_id = t.id and m.sender_kind = 'staff'
    and not (m.sender_id = t.user_id and m.created_at = t.created_at)),
 last_customer_message_at = t.created_at
where t.id in (select thread_id from repaired);

update public.support_messages m
set sender_name = coalesce(nullif(left(trim(p.display_name), 100), ''), 'Team PasKluis')
from public.profiles p
where m.sender_id = p.id and m.sender_kind = 'staff' and m.sender_name is null;

create or replace function public.validate_support_message() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 if pg_trigger_depth() > 1 and new.sender_kind = 'automatic' then
  new.sender_name := null;
  return new;
 end if;
 new.sender_name := null;
 if new.sender_id is null then
  new.sender_kind := 'guest';
 elsif new.sender_id = auth.uid() and public.is_staff() and (
   new.sender_kind = 'staff' or not exists (
    select 1 from public.support_threads t where t.id = new.thread_id and t.user_id = new.sender_id
   )
 ) then
  new.sender_kind := 'staff';
  select coalesce(nullif(left(trim(p.display_name), 100), ''), 'Team PasKluis')
   into new.sender_name from public.profiles p where p.id = new.sender_id;
 else
  -- A staff member asking a question from their own app is still the customer.
  new.sender_kind := 'user';
 end if;
 if exists(select 1 from public.support_threads where id = new.thread_id and status = 'closed') then
  raise exception 'CONVERSATION_CLOSED';
 end if;
 if (select count(*) from public.support_messages where thread_id = new.thread_id
     and created_at > now() - interval '1 minute') >= 12 then
  raise exception 'TOO_MANY_MESSAGES';
 end if;
 return new;
end; $$;

-- One authorized snapshot: status retrieval cannot suppress already-read replies.
-- Access matches the existing staff/owner policies and guest-token RPCs.
create or replace function public.support_conversation(p_thread_id uuid, p_token text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare t public.support_threads; items jsonb;
begin
 select * into t from public.support_threads where id = p_thread_id;
 if not found then raise exception 'CONVERSATION_UNAVAILABLE' using errcode = '42501'; end if;
 if (
  coalesce(public.is_staff(), false)
  or (t.user_id = auth.uid() and public.has_active_device_session())
  or (length(coalesce(p_token, '')) between 32 and 256 and
      t.guest_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex'))
 ) is not true then
  raise exception 'CONVERSATION_UNAVAILABLE' using errcode = '42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id', m.id, 'sender_id', m.sender_id, 'sender_kind', m.sender_kind,
  'sender_name', case when m.sender_kind = 'staff' then coalesce(m.sender_name, 'Team PasKluis') end,
  'message', m.message, 'created_at', m.created_at
 ) order by m.created_at, m.id), '[]'::jsonb) into items
 from public.support_messages m where m.thread_id = t.id;
 return jsonb_build_object(
  'thread', jsonb_build_object('id', t.id, 'subject', t.subject, 'status', t.status,
    'created_at', t.created_at, 'updated_at', t.updated_at),
  'is_guest', t.user_id is null,
  'messages', items
 );
end; $$;
revoke all on function public.support_conversation(uuid, text) from public;
grant execute on function public.support_conversation(uuid, text) to anon, authenticated;

-- Enforce push-only customer replies even while the previous worker is deployed.
-- Staff inbox emails for customer questions and authentication emails are unchanged.
create or replace function public.support_notification_channels() returns trigger
language plpgsql set search_path = '' as $$
begin
 if new.event_type = 'support_reply' then new.email_done := true; end if;
 return new;
end; $$;
create trigger support_notification_channels before insert on public.notification_outbox
for each row execute function public.support_notification_channels();
update public.notification_outbox set email_done = true
where event_type = 'support_reply' and delivered_at is null;

notify pgrst, 'reload schema';
commit;
