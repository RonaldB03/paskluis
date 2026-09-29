-- Apply terms_acceptance.sql in an isolated test database first.
begin;
-- Isolated test database only; all changes and fixtures are rolled back.
create or replace function public.has_active_device_session() returns boolean language sql as $$select true$$;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.terms_acceptances(user_id,version,document_hash,accepted_at,language)
 select auth.uid(),version,document_hash,now(),'nl' from public.terms_versions;
do $$begin
 if (select count(*) from public.terms_acceptances)<>1 then raise exception 'own receipt missing'; end if;
 begin
  update public.terms_acceptances set language='en';
  raise exception 'update allowed';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.terms_acceptances;
  raise exception 'delete allowed';
 exception when insufficient_privilege then null; end;
end$$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$begin
 if (select count(*) from public.terms_acceptances)<>0 then raise exception 'cross-account read allowed'; end if;
 begin
  insert into public.terms_acceptances(user_id,version,document_hash,accepted_at,language)
   select '11111111-1111-4111-8111-111111111111',version,document_hash,now(),'nl' from public.terms_versions;
  raise exception 'cross-account write allowed';
 exception when insufficient_privilege then null; end;
end$$;
set local role anon;
do $$begin
 begin
  perform 1 from public.terms_acceptances;
  raise exception 'anonymous read allowed';
 exception when insufficient_privilege then null; end;
end$$;
reset role;
select 'terms RLS passed' as result;

rollback;
