-- Synthetic identities and all effects roll back; no mail/push is dispatched.
begin;
set local statement_timeout = '15s';
insert into auth.users(id,email,raw_user_meta_data) values
('ee190000-0000-4000-8000-000000000001','share190-owner@example.invalid','{}'),
('ee190000-0000-4000-8000-000000000002','share190-a@example.invalid','{}'),
('ee190000-0000-4000-8000-000000000003','share190-b@example.invalid','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal) values
('ee190000-0000-4000-8000-000000000011','ee190000-0000-4000-8000-000000000001',now(),now(),'aal1'),
('ee190000-0000-4000-8000-000000000012','ee190000-0000-4000-8000-000000000002',now(),now(),'aal1');
insert into public.entitlements(user_id,product_id,source) values ('ee190000-0000-4000-8000-000000000001','paskluis_plus','complimentary');
select set_config('request.jwt.claims','{"sub":"ee190000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee190000-0000-4000-8000-000000000011"}',true);
set local role authenticated;
select public.claim_device_session('share190-owner','Synthetic regression',false);
do $$declare kind text; result jsonb;begin
 foreach kind in array array['QR-code','QR-set','Pasje','Cadeaukaart'] loop
  result:=public.share_card_by_email('share190-a@example.invalid','test-'||kind,kind,jsonb_build_object('name','Synthetic','type',kind,'code','test-code','codes','one|||two','used','false|||false','currentBalance','0'));
  if result->>'membership_id' is null then raise exception 'SHARE_FAILED';end if;
  perform public.share_card_by_email('share190-b@example.invalid','test-'||kind,kind,jsonb_build_object('name','Synthetic','type',kind,'code','test-code'));
 end loop;
 perform public.revoke_all_shared_card_access('test-Cadeaukaart');
end$$;
reset role;
do $$begin
 if exists(select 1 from public.card_share_members m join public.shared_cards c on c.id=m.shared_card_id where c.owner_id='ee190000-0000-4000-8000-000000000001' and c.card_type='Cadeaukaart' and m.revoked_at is null) then raise exception 'RECIPIENT_ACCESS_REMAINS';end if;
 if not exists(select 1 from public.shared_cards where owner_id='ee190000-0000-4000-8000-000000000001' and card_type='Cadeaukaart' and deleted_at is not null) then raise exception 'CARD_NOT_DELETED';end if;
 if (select count(*) from public.card_share_members m join public.shared_cards c on c.id=m.shared_card_id where c.owner_id='ee190000-0000-4000-8000-000000000001' and m.revoked_at is null)<>6 then raise exception 'UNRELATED_SHARES_CHANGED';end if;
end$$;
select set_config('request.jwt.claims','{"sub":"ee190000-0000-4000-8000-000000000002","role":"authenticated","session_id":"ee190000-0000-4000-8000-000000000012"}',true);
set local role authenticated;
select public.claim_device_session('share190-recipient','Synthetic regression',false);
do $$begin
 if exists(select 1 from public.shared_cards where card_external_id='test-Cadeaukaart') then raise exception 'REVOKED_CARD_READABLE';end if;
 if (select count(*) from public.shared_cards where card_external_id in ('test-QR-code','test-QR-set','test-Pasje'))<>3 then raise exception 'ACTIVE_CARD_NOT_READABLE';end if;
end$$;
rollback;
