-- Landmarks: reshape the check-in schema into a national parks photo feed.
--
-- The product is posts (photo + optional caption + mapped park location) on a
-- public feed, not generic landmark check-ins. Renames preserve the tables
-- rather than dropping them, so existing auth users keep their profiles.

-- ---------------------------------------------------------------------------
-- Clear the check-in era seed data
-- ---------------------------------------------------------------------------

delete from public.visits;
delete from public.badges;
delete from public.landmarks;

-- ---------------------------------------------------------------------------
-- Tables and columns
-- ---------------------------------------------------------------------------

alter table public.landmarks rename to parks;
alter table public.visits rename to posts;
alter table public.visit_likes rename to post_likes;
alter table public.visit_comments rename to post_comments;

alter table public.posts rename column landmark_id to park_id;
alter table public.posts rename column note to caption;
alter table public.posts rename column visited_at to taken_at;
alter table public.post_likes rename column visit_id to post_id;
alter table public.post_comments rename column visit_id to post_id;
alter table public.profiles rename column visit_count to post_count;

-- Parks are a curated catalog of US national parks, so the landmark-era
-- category and city columns do not apply. Parks can span several states.
drop index if exists public.landmarks_category_idx;
drop index if exists public.landmarks_city_idx;

alter table public.parks drop column category;
alter table public.parks drop column city;
alter table public.parks drop column country_code;
alter table public.parks add column state_codes char(2)[] not null default '{}';

-- Returns the category enum, so it has to go before the type does.
drop function public.landmarks_nearby(double precision, double precision, double precision, integer);

drop type public.landmark_category;

-- The photo is the post, so it is required. The per-post location is where the
-- photo was actually taken, which can be far from the park's center pin; it
-- falls back to parks.location when the user skips the map step.
alter table public.posts alter column photo_url set not null;
alter table public.posts add column location extensions.geography(point, 4326);

create index posts_location_idx on public.posts using gist (location);

-- ---------------------------------------------------------------------------
-- Index and policy names
-- ---------------------------------------------------------------------------

alter index public.landmarks_location_idx rename to parks_location_idx;
alter index public.landmarks_created_by_idx rename to parks_created_by_idx;
alter index public.visits_user_idx rename to posts_user_idx;
alter index public.visits_landmark_idx rename to posts_park_idx;
alter index public.visits_feed_idx rename to posts_feed_idx;
alter index public.visit_likes_user_idx rename to post_likes_user_idx;
alter index public.visit_comments_visit_idx rename to post_comments_post_idx;
alter index public.visit_comments_user_idx rename to post_comments_user_idx;

alter policy "Landmarks are readable by authenticated users" on public.parks
  rename to "Parks are readable by authenticated users";
alter policy "Users submit landmarks" on public.parks
  rename to "Users submit parks";
alter policy "Users update landmarks they submitted" on public.parks
  rename to "Users update parks they submitted";
alter policy "Visits are readable when visible to the viewer" on public.posts
  rename to "Posts are readable when visible to the viewer";
alter policy "Users create their own visits" on public.posts
  rename to "Users create their own posts";
alter policy "Users update their own visits" on public.posts
  rename to "Users update their own posts";
alter policy "Users delete their own visits" on public.posts
  rename to "Users delete their own posts";
alter policy "Users delete their own comments or comments on their visits"
  on public.post_comments
  rename to "Users delete their own comments or comments on their posts";

-- ---------------------------------------------------------------------------
-- Visibility helper
-- ---------------------------------------------------------------------------

-- Policies depend on the old function, so they are dropped and recreated
-- around the rename.
drop policy "Likes are readable when the visit is visible" on public.post_likes;
drop policy "Users like as themselves" on public.post_likes;
drop policy "Comments are readable when the visit is visible" on public.post_comments;
drop policy "Users comment as themselves" on public.post_comments;

drop function public.can_see_visit(uuid);

create or replace function public.can_see_post(target_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.posts p
    where p.id = target_post_id
      and (
        p.user_id = (select auth.uid())
        or p.visibility = 'public'
        or (
          p.visibility = 'followers'
          and exists (
            select 1
            from public.follows f
            where f.followee_id = p.user_id
              and f.follower_id = (select auth.uid())
          )
        )
      )
  );
$$;

create policy "Likes are readable when the post is visible"
on public.post_likes for select to authenticated
using ((select public.can_see_post(post_id)));

create policy "Users like as themselves"
on public.post_likes for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.can_see_post(post_id))
);

create policy "Comments are readable when the post is visible"
on public.post_comments for select to authenticated
using ((select public.can_see_post(post_id)));

create policy "Users comment as themselves"
on public.post_comments for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.can_see_post(post_id))
);

-- ---------------------------------------------------------------------------
-- Nearby parks
-- ---------------------------------------------------------------------------

create or replace function public.parks_nearby(
  lat double precision,
  lng double precision,
  radius_meters double precision default 200000,
  max_results integer default 25
)
returns table (
  id uuid,
  slug text,
  name text,
  state_codes char(2)[],
  cover_photo_url text,
  distance_meters double precision
)
language sql
stable
set search_path = ''
as $$
  select
    p.id,
    p.slug,
    p.name,
    p.state_codes,
    p.cover_photo_url,
    extensions.st_distance(p.location, extensions.st_makepoint(lng, lat)::extensions.geography) as distance_meters
  from public.parks p
  where extensions.st_dwithin(p.location, extensions.st_makepoint(lng, lat)::extensions.geography, radius_meters)
  order by distance_meters
  limit max_results;
$$;

-- ---------------------------------------------------------------------------
-- Counters
-- ---------------------------------------------------------------------------

create or replace function public.sync_post_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set post_count = post_count + 1 where id = new.user_id;
    return new;
  else
    update public.profiles set post_count = greatest(post_count - 1, 0) where id = old.user_id;
    return old;
  end if;
end;
$$;

drop trigger visits_sync_count on public.posts;
drop function public.sync_visit_count();

create trigger posts_sync_count
after insert or delete on public.posts
for each row execute function public.sync_post_count();

alter trigger visit_likes_sync_count on public.post_likes rename to post_likes_sync_count;
alter trigger visit_comments_sync_count on public.post_comments rename to post_comments_sync_count;

-- ---------------------------------------------------------------------------
-- Badges
-- ---------------------------------------------------------------------------

create or replace function public.award_badges()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_badges (user_id, badge_id)
  select new.user_id, b.id
  from public.badges b
  where case b.criteria ->> 'type'
    when 'post_count' then
      (select count(*) from public.posts p where p.user_id = new.user_id)
        >= (b.criteria ->> 'count')::int
    when 'park_count' then
      (select count(distinct p.park_id) from public.posts p where p.user_id = new.user_id)
        >= (b.criteria ->> 'count')::int
    when 'state_count' then
      (select count(distinct s)
       from public.posts p
       join public.parks pk on pk.id = p.park_id
       cross join lateral unnest(pk.state_codes) as s
       where p.user_id = new.user_id)
        >= (b.criteria ->> 'count')::int
    when 'park' then
      exists (
        select 1
        from public.posts p
        join public.parks pk on pk.id = p.park_id
        where p.user_id = new.user_id
          and pk.slug = b.criteria ->> 'slug'
      )
    else false
  end
  on conflict (user_id, badge_id) do nothing;

  return new;
end;
$$;

alter trigger visits_award_badges on public.posts rename to posts_award_badges;

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

drop policy "Visit photos are publicly readable" on storage.objects;
drop policy "Users upload their own visit photos" on storage.objects;
drop policy "Users replace their own visit photos" on storage.objects;
drop policy "Users delete their own visit photos" on storage.objects;

-- The empty `visit-photos` bucket is left behind because Supabase rejects
-- deletes against storage tables from SQL. Remove it from the dashboard.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-photos', 'post-photos', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "Post photos are publicly readable"
on storage.objects for select
using (bucket_id = 'post-photos');

create policy "Users upload their own post photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'post-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

create policy "Users replace their own post photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'post-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'post-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);

create policy "Users delete their own post photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'post-photos'
  and (select auth.uid())::text = (storage.foldername(name))[1]
);
