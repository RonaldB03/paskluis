-- Additive migration: existing Dutch clients, FAQs and token registrations remain valid.
begin;
alter table public.help_faqs add column if not exists category_en text not null default '';
alter table public.help_faqs add column if not exists question_en text not null default '';
alter table public.help_faqs add column if not exists answer_en text not null default '';
alter table public.push_device_tokens add column if not exists locale text not null default 'nl' check (locale in ('nl', 'en'));

-- A caller may only change the language of their own registered device.
create or replace function public.set_push_device_locale(p_device_id text, p_locale text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_locale is null or p_locale not in ('nl', 'en') then raise exception 'Unsupported locale'; end if;
  update public.push_device_tokens set locale = p_locale, updated_at = now()
    where user_id = auth.uid() and device_id = p_device_id;
end;
$$;
revoke all on function public.set_push_device_locale(text,text) from public, anon;
grant execute on function public.set_push_device_locale(text,text) to authenticated;

-- Seed translations only where none exists; preserve later administrator edits.
update public.help_faqs set category_en='Adding cards', question_en='How do I add a card?', answer_en='Tap +. Choose a loyalty card, QR code or gift card. Scan, enter details manually or import a photo or screenshot.' where question='Hoe voeg ik een kaart toe?' and question_en='' and answer_en='';
update public.help_faqs set category_en='Adding cards', question_en='Can I import a card from a screenshot?', answer_en='Yes. Choose import when adding a card and select the screenshot or photo. Always check the detected code before saving.' where question='Kan ik een kaart uit een screenshot halen?' and question_en='' and answer_en='';
update public.help_faqs set category_en='Privacy', question_en='Where are my cards stored?', answer_en='Your regular cards, barcodes, PINs and images stay locally on your phone. They are not automatically uploaded to PasKluis or the admin portal.' where question='Waar worden mijn kaarten bewaard?' and question_en='' and answer_en='';
update public.help_faqs set category_en='Location', question_en='Is my location saved?', answer_en='When you enable location-based cards, PasKluis can remember on this device where you used a card. Your card usage history is not sent to the admin portal.' where question='Wordt mijn locatie opgeslagen?' and question_en='' and answer_en='';
update public.help_faqs set category_en='Sharing', question_en='How does a shared card work?', answer_en='The sender needs Plus. Recipients without Plus can view the card. If you both have Plus, you can both update it.' where question='Hoe werkt een gedeelde kaart?' and question_en='' and answer_en='';
update public.help_faqs set category_en='Sharing', question_en='Is the PIN of a gift card shared too?', answer_en='Yes. A gift card is always shared in full, including its PIN or scratch code. PasKluis warns you before you share it.' where question='Wordt de pincode van een cadeaukaart meegedeeld?' and question_en='' and answer_en='';
update public.help_faqs set category_en='PasKluis Plus', question_en='What do I get with PasKluis Plus?', answer_en='With Plus you can store unlimited gift cards and share loyalty cards and gift cards. Plus costs €1.99 once, with no subscription.' where question='Wat krijg ik met PasKluis Plus?' and question_en='' and answer_en='';
update public.help_faqs set category_en='Account', question_en='Do I need an account?', answer_en='No. You can use loyalty cards, QR codes and one gift card without an account. An account is needed for Plus and sharing. Customer support is also available without signing in.' where question='Heb ik een account nodig?' and question_en='' and answer_en='';
update public.help_faqs set answer=replace(answer,'Tik rechtsboven op +.','Tik op +.') where question='Hoe voeg ik een kaart toe?' and answer like 'Tik rechtsboven op +.%';
commit;
