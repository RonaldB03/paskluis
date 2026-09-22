begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('support-attachments','support-attachments',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create table public.support_attachments(
 id uuid primary key default gen_random_uuid(),
 thread_id uuid not null references public.support_threads(id) on delete cascade,
 message_id uuid not null references public.support_messages(id) on delete cascade,
 storage_path text not null unique,mime_type text not null,
 size_bytes int not null check(size_bytes between 1 and 5242880),
 created_at timestamptz not null default now()
);
alter table public.support_attachments enable row level security;
-- Access to bytes is only through short-lived URLs after server authorization.
create policy "Read own attachment metadata" on public.support_attachments for select to authenticated
 using(public.is_staff() or exists(select 1 from public.support_threads t where t.id=thread_id and t.user_id=auth.uid()));
grant select on public.support_attachments to authenticated;
create or replace function public.guest_support_attachment_message(p_token text,p_thread_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare message_id uuid; lang text;
begin
 select locale into lang from public.support_threads where id=p_thread_id and user_id is null
  and length(coalesce(p_token,'')) between 32 and 256
  and guest_token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
 if lang is null then raise exception 'ACCESS_DENIED';end if;
 insert into public.support_messages(thread_id,sender_id,sender_kind,message)
 values(p_thread_id,null,'guest',case when lang='en' then 'Screenshot attached' else 'Screenshot bijgevoegd' end)
 returning id into message_id;
 return message_id;
end; $$;
revoke all on function public.guest_support_attachment_message(text,uuid) from public,anon,authenticated;
grant execute on function public.guest_support_attachment_message(text,uuid) to service_role;
create policy "Active support session required" on public.support_threads as restrictive to authenticated
 using(public.has_active_device_session() or public.is_staff()) with check(public.has_active_device_session() or public.is_staff());
create policy "Active support message session required" on public.support_messages as restrictive to authenticated
 using(public.has_active_device_session() or public.is_staff()) with check(public.has_active_device_session() or public.is_staff());
commit;
