begin;
create or replace function public.retry_failed_notifications() returns int
language plpgsql security definer set search_path='' as $$
declare retried int;
begin
 if not public.is_staff() then raise exception 'ACCESS_DENIED'; end if;
 update public.notification_outbox set attempts=0,available_at=now(),locked_until=null
 where delivered_at is null and attempts>=8 and (locked_until is null or locked_until<now());
 get diagnostics retried=row_count;
 return retried;
end; $$;
revoke all on function public.retry_failed_notifications() from public,anon;
grant execute on function public.retry_failed_notifications() to authenticated;
update public.help_faqs set
 answer='Alleen met jouw toestemming gebruikt PasKluis je locatie. Voor het zoeken naar filialen wordt je zoeklocatie via Supabase aan Google Places doorgegeven. Een afgerond zoekgebied en winkelresultaten worden maximaal 24 uur hergebruikt. Afstanden zijn bij benadering en hemelsbreed. Locatiekaarten kun je uitschakelen.',
 answer_en='Only with your permission does PasKluis use your location. To find branches, your search location is sent through Supabase to Google Places. A rounded search area and store results are reused for up to 24 hours. Distances are approximate and straight-line. You can disable location cards.'
where question='Wordt mijn locatie opgeslagen?';
update public.app_settings set input_type='switch' where key='store_purchase_enabled';
commit;
