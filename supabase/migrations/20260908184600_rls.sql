-- Landmarks: Row Level Security
-- Security is enforced here, not in the client. Every table is locked down.

alter table public.profiles enable row level security;
alter table public.landmarks enable row level security;
alter table public.visits enable row level security;
alter table public.follows enable row level security;
alter table public.visit_likes enable row level security;
alter table public.visit_comments enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;

-- ---------------------------------------------------------------------------
-- Visibility helper
-- ---------------------------------------------------------------------------

-- Single source of truth for "can the current user see this check-in".
-- Security definer so it can read `visits` and `follows` without recursing
-- back through the policies that call it.
create or replace function public.can_see_visit(target_visit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits v
    where v.id = target_visit_id
      and (
        v.user_id = (select auth.uid())
        or v.visibility = 'public'
        or (
          v.visibility = 'followers'
          and exists (
            select 1
            from public.follows f
            where f.followee_id = v.user_id
              and f.follower_id = (select auth.uid())
          )
        )
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create policy "Profiles are readable by authenticated users"
on public.profiles for select to authenticated
using (true);

-- The signup trigger creates the row; this covers backfills and retries.
create policy "Users insert their own profile"
on public.profiles for insert to authenticated
with check (id = (select auth.uid()));

create policy "Users update their own profile"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- landmarks
-- ---------------------------------------------------------------------------

create policy "Landmarks are readable by authenticated users"
on public.landmarks for select to authenticated
using (true);

create policy "Users submit landmarks"
on public.landmarks for insert to authenticated
with check (created_by = (select auth.uid()) and is_verified = false);

create policy "Users update landmarks they submitted"
on public.landmarks for update to authenticated
using (created_by = (select auth.uid()) and is_verified = false)
with check (created_by = (select auth.uid()) and is_verified = false);

-- ---------------------------------------------------------------------------
-- visits
-- ---------------------------------------------------------------------------

create policy "Visits are readable when visible to the viewer"
on public.visits for select to authenticated
using (
  user_id = (select auth.uid())
  or visibility = 'public'
  or (
    visibility = 'followers'
    and exists (
      select 1
      from public.follows f
      where f.followee_id = visits.user_id
        and f.follower_id = (select auth.uid())
    )
  )
);

create policy "Users create their own visits"
on public.visits for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "Users update their own visits"
on public.visits for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "Users delete their own visits"
on public.visits for delete to authenticated
using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- follows
-- ---------------------------------------------------------------------------

create policy "Follows are readable by authenticated users"
on public.follows for select to authenticated
using (true);

create policy "Users follow as themselves"
on public.follows for insert to authenticated
with check (follower_id = (select auth.uid()));

create policy "Users unfollow as themselves"
on public.follows for delete to authenticated
using (follower_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- visit_likes
-- ---------------------------------------------------------------------------

create policy "Likes are readable when the visit is visible"
on public.visit_likes for select to authenticated
using ((select public.can_see_visit(visit_id)));

create policy "Users like as themselves"
on public.visit_likes for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.can_see_visit(visit_id))
);

create policy "Users remove their own likes"
on public.visit_likes for delete to authenticated
using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- visit_comments
-- ---------------------------------------------------------------------------

create policy "Comments are readable when the visit is visible"
on public.visit_comments for select to authenticated
using ((select public.can_see_visit(visit_id)));

create policy "Users comment as themselves"
on public.visit_comments for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.can_see_visit(visit_id))
);

create policy "Users update their own comments"
on public.visit_comments for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- The visit owner can also moderate comments on their own check-in.
create policy "Users delete their own comments or comments on their visits"
on public.visit_comments for delete to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.visits v
    where v.id = visit_comments.visit_id
      and v.user_id = (select auth.uid())
  )
);

-- ---------------------------------------------------------------------------
-- badges
-- ---------------------------------------------------------------------------

create policy "Badges are readable by authenticated users"
on public.badges for select to authenticated
using (true);

-- Badges are granted by the award_badges trigger only, so there is no insert
-- policy here on purpose.
create policy "Earned badges are readable by authenticated users"
on public.user_badges for select to authenticated
using (true);
