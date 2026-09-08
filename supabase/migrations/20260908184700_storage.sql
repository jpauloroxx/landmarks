-- Landmarks: storage buckets
-- Objects are keyed by "<user id>/<uuid>.jpg" so ownership is the first path
-- segment, which is what the policies below check.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('visit-photos', 'visit-photos', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- avatars
-- ---------------------------------------------------------------------------

create policy "Avatars are publicly readable"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "Users upload their own avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

create policy "Users replace their own avatar"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and (select auth.uid())::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'avatars'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

create policy "Users delete their own avatar"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

-- ---------------------------------------------------------------------------
-- visit-photos
-- ---------------------------------------------------------------------------

-- The bucket is readable to anyone holding the URL; which check-ins a viewer
-- can discover is still governed by the RLS policies on `public.visits`.
create policy "Visit photos are publicly readable"
on storage.objects for select
using (bucket_id = 'visit-photos');

create policy "Users upload their own visit photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'visit-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

create policy "Users replace their own visit photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'visit-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'visit-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

create policy "Users delete their own visit photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'visit-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);
