begin;
alter table public.support_threads add column if not exists closed_at timestamptz;
-- Legacy closures start their retention clock at rollout, avoiding early deletion.
update public.support_threads set closed_at=now() where status='closed' and closed_at is null;
create table if not exists public.support_customer_state (
 thread_id uuid primary key references public.support_threads(id) on delete cascade,
 read_at timestamptz, hidden_at timestamptz
);
alter table public.support_customer_state enable row level security;
revoke all on public.support_customer_state from public,anon,authenticated;
grant all on public.support_customer_state to service_role;
create table if not exists public.support_retention_holds (
 thread_id uuid primary key references public.support_threads(id) on delete cascade,
 reason text not null check(length(trim(reason)) between 10 and 500),
 review_at timestamptz not null check(review_at <= now()+interval '90 days'),
 updated_by uuid default auth.uid(),
 updated_at timestamptz default now()
);
alter table public.support_retention_holds enable row level security;
revoke all on public.support_retention_holds from public,anon,authenticated;
grant select,insert,update,delete on public.support_retention_holds to authenticated;
grant all on public.support_retention_holds to service_role;
create policy "Staff manage bounded retention exceptions" on public.support_retention_holds
 for all to authenticated using(public.is_staff()) with check(public.is_staff());
create table if not exists public.support_storage_cleanup (
 storage_path text primary key, created_at timestamptz not null default now()
);
alter table public.support_storage_cleanup enable row level security;
revoke all on public.support_storage_cleanup from public,anon,authenticated;
grant all on public.support_storage_cleanup to service_role;

create or replace function public.track_support_closure() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then new.closed_at:=case when new.status='closed' then now() else null end;
 elsif new.status is distinct from old.status then
  new.closed_at:=case when new.status='closed' then now() else null end;
 else new.closed_at:=old.closed_at;
 end if;
 return new;
end; $$;
revoke all on function public.track_support_closure() from public,anon,authenticated;
create trigger support_closure before insert or update on public.support_threads
 for each row execute function public.track_support_closure();

create or replace function public.queue_support_attachment_cleanup() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.support_storage_cleanup(storage_path) values(old.storage_path) on conflict do nothing;
 return old;
end; $$;
revoke all on function public.queue_support_attachment_cleanup() from public,anon,authenticated;
create trigger support_attachment_cleanup before delete on public.support_attachments
 for each row execute function public.queue_support_attachment_cleanup();

create index if not exists support_staff_reply_time on public.support_messages(thread_id,created_at)
 where sender_kind='staff';

create or replace function public.support_inbox(p_token text default null)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',t.id,'subject',t.subject,'status',t.status,'created_at',t.created_at,'updated_at',t.updated_at,
  'is_guest',t.user_id is null,
  'has_unread_reply',coalesce(m.last_reply>s.read_at,s.read_at is null and m.last_reply is not null),
  'last_staff_reply_at',m.last_reply
 ) order by t.updated_at desc),'[]'::jsonb)
 from public.support_threads t
 left join public.support_customer_state s on s.thread_id=t.id
 left join lateral(select max(created_at) last_reply from public.support_messages
   where thread_id=t.id and sender_kind='staff') m on true
 where ((t.user_id=auth.uid() and public.has_active_device_session())
   or (t.user_id is null and length(coalesce(p_token,'')) between 32 and 256
     and t.guest_token_hash=encode(extensions.digest(p_token,'sha256'),'hex')))
 and (s.hidden_at is null or m.last_reply>s.hidden_at);
$$;
revoke all on function public.support_inbox(text) from public;
grant execute on function public.support_inbox(text) to anon,authenticated;

create or replace function public.support_customer_action(
 p_thread_id uuid,p_action text,p_token text default null,p_read_at timestamptz default null)
returns void language plpgsql security definer set search_path='' as $$
declare t public.support_threads; reply_at timestamptz;
begin
 select * into t from public.support_threads where id=p_thread_id for update;
 if not found or ((t.user_id=auth.uid() and public.has_active_device_session())
   or (t.user_id is null and length(coalesce(p_token,'')) between 32 and 256
     and t.guest_token_hash=encode(extensions.digest(p_token,'sha256'),'hex'))) is not true then
   raise exception 'CONVERSATION_UNAVAILABLE' using errcode='42501';
 end if;
 if p_action='hide' then
  insert into public.support_customer_state(thread_id,hidden_at) values(t.id,clock_timestamp())
   on conflict(thread_id) do update set hidden_at=excluded.hidden_at;
 elsif p_action='read' then
  select max(created_at) into reply_at from public.support_messages
   where thread_id=t.id and sender_kind='staff' and created_at<=least(p_read_at,now());
  if reply_at is not null then
   insert into public.support_customer_state(thread_id,read_at) values(t.id,reply_at)
    on conflict(thread_id) do update set read_at=greatest(public.support_customer_state.read_at,excluded.read_at);
  end if;
 else raise exception 'INVALID_ACTION';
 end if;
end; $$;
revoke all on function public.support_customer_action(uuid,text,text,timestamptz) from public;
grant execute on function public.support_customer_action(uuid,text,text,timestamptz) to anon,authenticated;

create or replace function public.purge_expired_support() returns jsonb
language plpgsql security definer set search_path='' as $$
declare attachments_count integer; threads_count integer;
begin
 -- Holds expire unless staff actively review and justify an extension.
 delete from public.support_attachments a using public.support_threads t
 where a.thread_id=t.id and t.status='closed' and t.closed_at<now()-interval '30 days'
 and not exists(select 1 from public.support_retention_holds h where h.thread_id=t.id and h.review_at>now());
 get diagnostics attachments_count=row_count;
 -- Cascades also remove messages, notes, customer state, holds and notification jobs.
 with expired as (
  delete from public.support_threads t where t.status='closed' and t.closed_at<now()-interval '6 months'
  and not exists(select 1 from public.support_retention_holds h where h.thread_id=t.id and h.review_at>now())
  returning id
 )
 select count(*) into threads_count from expired;
 -- The audit trigger contains snapshots; remove those after the subject is gone.
 delete from public.admin_audit_log a where a.entity_type='support_threads'
 and not exists(select 1 from public.support_threads t where t.id::text=a.entity_id);
 delete from public.guest_support_push_tokens p where not exists(
  select 1 from public.support_threads t where t.guest_token_hash=p.guest_token_hash);
 return jsonb_build_object('attachments',attachments_count,'threads',threads_count);
end; $$;
revoke all on function public.purge_expired_support() from public,anon,authenticated;
grant execute on function public.purge_expired_support() to service_role;
select cron.schedule('paskluis-support-retention','37 2 * * *','select public.purge_expired_support();');
notify pgrst,'reload schema';
commit;
