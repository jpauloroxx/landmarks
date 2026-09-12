-- Landmarks: resolve Supabase advisor findings.

-- Security advisor: every function in `public` should pin its search path.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Performance advisor: foreign keys not already covered by a primary key or a
-- composite index need their own, otherwise cascading deletes and joins on the
-- parent side fall back to sequential scans.
create index if not exists landmarks_created_by_idx
  on public.landmarks (created_by);

create index if not exists visit_comments_user_idx
  on public.visit_comments (user_id, created_at desc);

create index if not exists user_badges_badge_idx
  on public.user_badges (badge_id);
