-- All accounts may opt in to backup; this does not enable device uploads.
-- Preserve explicit disabled rows used by the account-deletion safeguard.
alter table backup_private.accounts alter column enabled set default true;
insert into backup_private.accounts(user_id)
select id from auth.users
on conflict(user_id) do nothing;
