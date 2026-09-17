-- Central managed brand catalogue and public logo storage.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'brand-logos',
  'brand-logos',
  true,
  2097152,
  array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public reads brand logos" on storage.objects;
create policy "Public reads brand logos"
  on storage.objects for select
  using (bucket_id = 'brand-logos');

drop policy if exists "Admins upload brand logos" on storage.objects;
create policy "Admins upload brand logos"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'brand-logos' and public.is_admin());

drop policy if exists "Admins update brand logos" on storage.objects;
create policy "Admins update brand logos"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'brand-logos' and public.is_admin())
  with check (bucket_id = 'brand-logos' and public.is_admin());

drop policy if exists "Admins delete brand logos" on storage.objects;
create policy "Admins delete brand logos"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'brand-logos' and public.is_admin());

insert into public.brands (
  slug,
  name,
  logo_path,
  brand_color,
  supports_loyalty_card,
  supports_gift_card,
  is_active,
  sort_order
)
values
  ('albert-heijn', 'Albert Heijn', 'assets/logos/albert_heijn.png', '#00A6D6', true, true, true, 10),
  ('kruidvat', 'Kruidvat', 'assets/logos/kruidvat.png', '#E30613', true, false, true, 20),
  ('jumbo', 'Jumbo', 'assets/logos/jumbo.png', '#FFC400', true, true, true, 30),
  ('hema', 'HEMA', 'assets/logos/hema.png', '#E30613', true, true, true, 40)
on conflict (slug) do update set
  name = excluded.name,
  brand_color = excluded.brand_color,
  supports_loyalty_card = excluded.supports_loyalty_card,
  supports_gift_card = excluded.supports_gift_card,
  sort_order = excluded.sort_order,
  updated_at = now();
