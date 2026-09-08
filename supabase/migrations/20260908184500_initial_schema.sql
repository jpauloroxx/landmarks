-- Landmarks: core schema
-- Profiles, landmark catalog, check-ins, social graph, badges.

create extension if not exists postgis with schema extensions;
create extension if not exists citext with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.landmark_category as enum (
  'monument',
  'museum',
  'park',
  'viewpoint',
  'building',
  'natural',
  'other'
);

create type public.visit_visibility as enum ('public', 'followers', 'private');

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username extensions.citext not null unique
    check (length(username) between 3 and 30 and username ~ '^[a-z0-9_]+$'),
  display_name text check (length(display_name) <= 60),
  bio text check (length(bio) <= 280),
  -- Object path inside the `avatars` storage bucket, not a full URL.
  avatar_url text,
  home_city text,
  follower_count integer not null default 0,
  following_count integer not null default 0,
  visit_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Every auth user gets a profile immediately, so screens never have to handle
-- a signed-in user without one. The username is a placeholder the user renames.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate text;
begin
  candidate := regexp_replace(lower(split_part(new.email, '@', 1)), '[^a-z0-9_]', '', 'g');

  if length(candidate) < 3 then
    candidate := 'explorer';
  end if;

  candidate := left(candidate, 20) || '_' || left(replace(new.id::text, '-', ''), 6);

  insert into public.profiles (id, username)
  values (new.id, candidate)
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- landmarks
-- ---------------------------------------------------------------------------

create table public.landmarks (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null check (length(name) between 1 and 120),
  description text,
  category public.landmark_category not null default 'other',
  location extensions.geography(point, 4326) not null,
  address text,
  city text,
  country_code char(2),
  cover_photo_url text,
  -- Null for seeded landmarks, set for user submissions.
  created_by uuid references public.profiles (id) on delete set null,
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);

create index landmarks_location_idx on public.landmarks using gist (location);
create index landmarks_category_idx on public.landmarks (category);
create index landmarks_city_idx on public.landmarks (city);

-- Landmarks near a point, closest first. Used by the check-in screen.
create or replace function public.landmarks_nearby(
  lat double precision,
  lng double precision,
  radius_meters double precision default 5000,
  max_results integer default 25
)
returns table (
  id uuid,
  slug text,
  name text,
  category public.landmark_category,
  city text,
  cover_photo_url text,
  distance_meters double precision
)
language sql
stable
set search_path = ''
as $$
  select
    l.id,
    l.slug,
    l.name,
    l.category,
    l.city,
    l.cover_photo_url,
    extensions.st_distance(l.location, extensions.st_makepoint(lng, lat)::extensions.geography) as distance_meters
  from public.landmarks l
  where extensions.st_dwithin(l.location, extensions.st_makepoint(lng, lat)::extensions.geography, radius_meters)
  order by distance_meters
  limit max_results;
$$;

-- ---------------------------------------------------------------------------
-- visits (check-ins)
-- ---------------------------------------------------------------------------

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  landmark_id uuid not null references public.landmarks (id) on delete cascade,
  visited_at timestamptz not null default now(),
  note text check (length(note) <= 500),
  -- Object path inside the `visit-photos` storage bucket.
  photo_url text,
  rating smallint check (rating between 1 and 5),
  visibility public.visit_visibility not null default 'public',
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index visits_user_idx on public.visits (user_id, visited_at desc);
create index visits_landmark_idx on public.visits (landmark_id, visited_at desc);
create index visits_feed_idx on public.visits (visited_at desc) where visibility <> 'private';

-- ---------------------------------------------------------------------------
-- follows
-- ---------------------------------------------------------------------------

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create index follows_followee_idx on public.follows (followee_id, created_at desc);

-- ---------------------------------------------------------------------------
-- likes and comments
-- ---------------------------------------------------------------------------

create table public.visit_likes (
  visit_id uuid not null references public.visits (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (visit_id, user_id)
);

create index visit_likes_user_idx on public.visit_likes (user_id, created_at desc);

create table public.visit_comments (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create index visit_comments_visit_idx on public.visit_comments (visit_id, created_at);

-- ---------------------------------------------------------------------------
-- badges
-- ---------------------------------------------------------------------------

create table public.badges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null,
  description text,
  icon text,
  -- Supported shapes:
  --   {"type": "visit_count", "count": 10}
  --   {"type": "category_count", "category": "museum", "count": 5}
  --   {"type": "city_count", "city": "Lisbon", "count": 3}
  --   {"type": "landmark", "slug": "eiffel-tower"}
  criteria jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.user_badges (
  user_id uuid not null references public.profiles (id) on delete cascade,
  badge_id uuid not null references public.badges (id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- ---------------------------------------------------------------------------
-- Denormalized counters
-- ---------------------------------------------------------------------------

create or replace function public.sync_follow_counts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set following_count = following_count + 1 where id = new.follower_id;
    update public.profiles set follower_count = follower_count + 1 where id = new.followee_id;
    return new;
  else
    update public.profiles set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    update public.profiles set follower_count = greatest(follower_count - 1, 0) where id = old.followee_id;
    return old;
  end if;
end;
$$;

create trigger follows_sync_counts
after insert or delete on public.follows
for each row execute function public.sync_follow_counts();

create or replace function public.sync_visit_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set visit_count = visit_count + 1 where id = new.user_id;
    return new;
  else
    update public.profiles set visit_count = greatest(visit_count - 1, 0) where id = old.user_id;
    return old;
  end if;
end;
$$;

create trigger visits_sync_count
after insert or delete on public.visits
for each row execute function public.sync_visit_count();

create or replace function public.sync_like_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.visits set like_count = like_count + 1 where id = new.visit_id;
    return new;
  else
    update public.visits set like_count = greatest(like_count - 1, 0) where id = old.visit_id;
    return old;
  end if;
end;
$$;

create trigger visit_likes_sync_count
after insert or delete on public.visit_likes
for each row execute function public.sync_like_count();

create or replace function public.sync_comment_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.visits set comment_count = comment_count + 1 where id = new.visit_id;
    return new;
  else
    update public.visits set comment_count = greatest(comment_count - 1, 0) where id = old.visit_id;
    return old;
  end if;
end;
$$;

create trigger visit_comments_sync_count
after insert or delete on public.visit_comments
for each row execute function public.sync_comment_count();

-- ---------------------------------------------------------------------------
-- Badge awarding
-- ---------------------------------------------------------------------------

-- Runs after each check-in and grants any badge whose criteria the user now
-- meets. Adding a badge is an insert into `badges`, not a code change.
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
    when 'visit_count' then
      (select count(*) from public.visits v where v.user_id = new.user_id)
        >= (b.criteria ->> 'count')::int
    when 'category_count' then
      (select count(distinct v.landmark_id)
       from public.visits v
       join public.landmarks l on l.id = v.landmark_id
       where v.user_id = new.user_id
         and l.category::text = b.criteria ->> 'category')
        >= (b.criteria ->> 'count')::int
    when 'city_count' then
      (select count(distinct v.landmark_id)
       from public.visits v
       join public.landmarks l on l.id = v.landmark_id
       where v.user_id = new.user_id
         and l.city = b.criteria ->> 'city')
        >= (b.criteria ->> 'count')::int
    when 'landmark' then
      exists (
        select 1
        from public.visits v
        join public.landmarks l on l.id = v.landmark_id
        where v.user_id = new.user_id
          and l.slug = b.criteria ->> 'slug'
      )
    else false
  end
  on conflict (user_id, badge_id) do nothing;

  return new;
end;
$$;

create trigger visits_award_badges
after insert on public.visits
for each row execute function public.award_badges();
