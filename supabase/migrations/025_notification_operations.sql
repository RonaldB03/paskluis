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
update public.app_settings set value=to_jsonb('Je eigen kaarten blijven op dit toestel. Gedeelde kaarten worden online opgeslagen. Voor locatiekaarten wordt je zoeklocatie via Supabase aan Google Places doorgegeven. Support verwerkt je bericht en contactgegevens. Er is geen automatische cloudback-up van je eigen kaarten.'::text) where key='privacy_message';
insert into public.app_settings(key,value,label,description,category,is_public,input_type) values
('privacy_message_en',to_jsonb('Your own cards stay on this device. Shared cards are stored online. Location searches send your search location through Supabase to Google Places. Support processes your message and contact details. Your own cards have no automatic cloud backup.'::text),'Privacytekst English','Engelse korte privacyuitleg.','content',true,'textarea'),
('help_add_card_text_en',to_jsonb('Tap + to add a loyalty card, QR code or gift card. Scan, enter details manually or import a photo or screenshot. Always check the detected store and code before saving.'::text),'Hulptekst English','Engelse hulp bij kaarten toevoegen.','content',true,'textarea'),
('maintenance_message_en',to_jsonb('PasKluis online services are temporarily undergoing maintenance. Your own local cards remain available.'::text),'Onderhoudstekst English','Engelse onderhoudsmelding.','app',true,'textarea')
on conflict(key) do nothing;
commit;
