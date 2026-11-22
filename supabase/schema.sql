-- AralMap — Supabase schema. Run once in the Supabase dashboard:
-- SQL Editor → New query → paste this file → Run.
--
-- Stores each user's favorites as one JSON array. Row Level Security makes
-- every row visible and writable only by its owner.

create table if not exists public.user_favorites (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  places     jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_favorites enable row level security;

drop policy if exists "Read own favorites" on public.user_favorites;
create policy "Read own favorites" on public.user_favorites
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Insert own favorites" on public.user_favorites;
create policy "Insert own favorites" on public.user_favorites
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Update own favorites" on public.user_favorites;
create policy "Update own favorites" on public.user_favorites
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Delete own favorites" on public.user_favorites;
create policy "Delete own favorites" on public.user_favorites
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- In-app account deletion (required by Google Play for apps with accounts).
-- Deletes the caller's auth user; their favorites go with it (cascade).
create or replace function public.delete_my_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = (select auth.uid());
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
