update public.app_settings
set value = '"€ 1,99 eenmalig"',
    updated_at = now()
where key = 'lifetime_price_label';

update public.help_faqs
set answer = replace(answer, '€ 2 eenmalig', '€ 1,99 eenmalig'),
    updated_at = now()
where answer like '%€ 2 eenmalig%';
