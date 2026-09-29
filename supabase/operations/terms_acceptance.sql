-- Terms snapshot and append-only, account-scoped acceptance receipts.
create table public.terms_versions (
 version text primary key,
 document_hash text not null check(length(document_hash)=64),
 unique(version, document_hash)
);
alter table public.terms_versions enable row level security;
revoke all on public.terms_versions from public, anon, authenticated;
grant select on public.terms_versions to authenticated;
create policy "Read terms versions" on public.terms_versions for select to authenticated using(true);
insert into public.terms_versions values ('2026-09-29','04f259a3f13ce8e5a4799d7b48029336fe64870051bbb9e7ef470cfcdf6e0c0a');
create table public.terms_acceptances (
 user_id uuid not null references auth.users(id) on delete cascade,
 version text not null,
 document_hash text not null,
 accepted_at timestamptz not null,
 received_at timestamptz not null default now(),
 language text not null check(language in ('nl','en')),
 primary key(user_id,version),
 foreign key(version,document_hash) references public.terms_versions(version,document_hash)
);
alter table public.terms_acceptances enable row level security;
revoke all on public.terms_acceptances from public, anon, authenticated;
grant select on public.terms_acceptances to authenticated;
grant insert(user_id,version,document_hash,accepted_at,language) on public.terms_acceptances to authenticated;
create policy "Read own terms acceptance" on public.terms_acceptances for select to authenticated
 using((select auth.uid())=user_id and (select public.has_active_device_session()));
create policy "Record own terms acceptance" on public.terms_acceptances for insert to authenticated
 with check((select auth.uid())=user_id and (select public.has_active_device_session()));
grant all on public.terms_versions,public.terms_acceptances to service_role;
