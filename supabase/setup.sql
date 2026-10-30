-- SEOUL, OUR PICKS — Supabase setup
-- Run this once in the Supabase SQL Editor of a NEW project.
-- It creates the tables, row level security, and a private storage bucket.
-- Nothing in this file is private: the trip itself lives in the private bucket (app.html),
-- which only the three members can read after logging in.

-- ---------------------------------------------------------------------------
-- Members: only users listed here can read or write anything.
-- ---------------------------------------------------------------------------
create table if not exists public.members (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name    text not null check (char_length(name) between 1 and 40),
  role    text not null default 'member' check (role in ('owner', 'member'))
);

create or replace function public.is_member()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (select 1 from public.members m where m.user_id = (select auth.uid()));
$$;

create or replace function public.is_owner()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (select 1 from public.members m where m.user_id = (select auth.uid()) and m.role = 'owner');
$$;

revoke all on function public.is_member() from public, anon;
revoke all on function public.is_owner()  from public, anon;
grant execute on function public.is_member() to authenticated;
grant execute on function public.is_owner()  to authenticated;

-- ---------------------------------------------------------------------------
-- answers: one row per member (wishes, meal votes, nickname, comment)
-- plan:    shared rows written by the owner ('decisions', 'edits')
-- ---------------------------------------------------------------------------
create table if not exists public.answers (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data       jsonb not null check (pg_column_size(data) < 64000),
  updated_at timestamptz not null default now()
);

create table if not exists public.plan (
  key        text primary key check (key in ('decisions', 'edits')),
  data       jsonb not null check (pg_column_size(data) < 256000),
  updated_at timestamptz not null default now()
);

alter table public.members enable row level security;
alter table public.answers enable row level security;
alter table public.plan    enable row level security;

-- Nobody who is not logged in gets anything.
revoke all on public.members, public.answers, public.plan from anon;
revoke all on public.members, public.answers, public.plan from authenticated;
grant select                         on public.members to authenticated;
grant select, insert, update, delete on public.answers to authenticated;
grant select, insert, update, delete on public.plan    to authenticated;

drop policy if exists "members: members can read" on public.members;
create policy "members: members can read" on public.members
  for select to authenticated using ((select public.is_member()));

drop policy if exists "answers: members can read" on public.answers;
create policy "answers: members can read" on public.answers
  for select to authenticated using ((select public.is_member()));

drop policy if exists "answers: write own row" on public.answers;
create policy "answers: write own row" on public.answers
  for insert to authenticated
  with check (user_id = (select auth.uid()) and (select public.is_member()));

drop policy if exists "answers: update own row" on public.answers;
create policy "answers: update own row" on public.answers
  for update to authenticated
  using (user_id = (select auth.uid()) and (select public.is_member()))
  with check (user_id = (select auth.uid()));

drop policy if exists "answers: delete own row" on public.answers;
create policy "answers: delete own row" on public.answers
  for delete to authenticated
  using (user_id = (select auth.uid()) and (select public.is_member()));

drop policy if exists "plan: members can read" on public.plan;
create policy "plan: members can read" on public.plan
  for select to authenticated using ((select public.is_member()));

drop policy if exists "plan: owner can insert" on public.plan;
create policy "plan: owner can insert" on public.plan
  for insert to authenticated with check ((select public.is_owner()));

drop policy if exists "plan: owner can update" on public.plan;
create policy "plan: owner can update" on public.plan
  for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));

drop policy if exists "plan: owner can delete" on public.plan;
create policy "plan: owner can delete" on public.plan
  for delete to authenticated using ((select public.is_owner()));

-- Keep updated_at honest (the browser cannot set it to anything else).
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end; $$;

drop trigger if exists answers_touch on public.answers;
create trigger answers_touch before insert or update on public.answers
  for each row execute function public.touch_updated_at();
drop trigger if exists plan_touch on public.plan;
create trigger plan_touch before insert or update on public.plan
  for each row execute function public.touch_updated_at();

-- Live updates for the other two phones.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'answers') then
    alter publication supabase_realtime add table public.answers;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'plan') then
    alter publication supabase_realtime add table public.plan;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Private storage bucket "trip": holds app.html (the trip itself).
-- Upload it from the dashboard (Storage → trip). Members can only read it.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('trip', 'trip', false, 2097152, array['text/html'])
on conflict (id) do update set public = false;

drop policy if exists "trip: members can read" on storage.objects;
create policy "trip: members can read" on storage.objects
  for select to authenticated
  using (bucket_id = 'trip' and (select public.is_member()));
