-- Certo — initial schema.
-- Tables: profiles, medications, dose_events.
-- Row Level Security is enabled on every table; users can only touch their own rows.

-- gen_random_uuid() lives in pgcrypto; make sure it is available.
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- profiles — one row per auth user (created automatically on signup).
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  name       text not null default '',
  locale     text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- medications — the user's medication list and schedule.
-- ---------------------------------------------------------------------------
create table if not exists public.medications (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  name             text not null,
  dosage           text not null default '',
  instruction      text not null default '',
  category         text not null default '',
  notes            text not null default '',
  -- Scheduled times as display strings, e.g. {"9:00 AM","1:00 PM","9:00 PM"}.
  times            text[] not null default '{}',
  pill_color_index smallint not null default 0,
  status           text not null default 'active'
                     check (status in ('active', 'paused', 'finished')),
  started_at       date not null default current_date,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists medications_user_id_idx on public.medications (user_id);

-- ---------------------------------------------------------------------------
-- dose_events — history of taken / skipped / mismatch / uncertain actions.
-- ---------------------------------------------------------------------------
create table if not exists public.dose_events (
  id            uuid primary key default gen_random_uuid(),
  medication_id uuid not null references public.medications (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  action        text not null default 'taken'
                  check (action in ('taken', 'skipped', 'mismatch', 'uncertain')),
  created_at    timestamptz not null default now()
);

create index if not exists dose_events_user_id_idx on public.dose_events (user_id);
create index if not exists dose_events_medication_id_idx on public.dose_events (medication_id);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Keep `updated_at` fresh on update.
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger medications_set_updated_at
  before update on public.medications
  for each row execute function public.set_updated_at();

-- Auto-create a profile row when a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles     enable row level security;
alter table public.medications  enable row level security;
alter table public.dose_events  enable row level security;

-- profiles
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- medications
create policy "medications_select_own" on public.medications
  for select using (auth.uid() = user_id);
create policy "medications_insert_own" on public.medications
  for insert with check (auth.uid() = user_id);
create policy "medications_update_own" on public.medications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "medications_delete_own" on public.medications
  for delete using (auth.uid() = user_id);

-- dose_events
create policy "dose_events_select_own" on public.dose_events
  for select using (auth.uid() = user_id);
create policy "dose_events_insert_own" on public.dose_events
  for insert with check (auth.uid() = user_id);
create policy "dose_events_delete_own" on public.dose_events
  for delete using (auth.uid() = user_id);
