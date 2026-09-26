-- Caregiver mode + richer profiles.
-- Adds is_caregiver flag, caregiver↔patient consent links, and RLS so an
-- active caregiver can read (and log doses for) a consenting patient.

-- ---------------------------------------------------------------------------
-- profiles — caregiver flag / role
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_caregiver boolean not null default false;

alter table public.profiles
  add column if not exists role text not null default 'individual';

-- Backfill role from is_caregiver for existing rows.
update public.profiles
set role = case when is_caregiver then 'family_caregiver' else 'individual' end
where role is null or role = '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_role_check'
  ) then
    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('individual', 'family_caregiver', 'professional'));
  end if;
end $$;

-- Keep signup metadata → profile in sync.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := coalesce(new.raw_user_meta_data ->> 'name', '');
  v_is_caregiver boolean := coalesce(
    (new.raw_user_meta_data ->> 'is_caregiver')::boolean,
    false
  );
  v_role text := coalesce(
    nullif(new.raw_user_meta_data ->> 'role', ''),
    case when v_is_caregiver then 'family_caregiver' else 'individual' end
  );
begin
  insert into public.profiles (id, name, is_caregiver, role)
  values (new.id, v_name, v_is_caregiver, v_role)
  on conflict (id) do update
    set name = excluded.name,
        is_caregiver = excluded.is_caregiver,
        role = excluded.role;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- caregiver_links — explicit, revocable consent
-- Patient generates an invite code; caregiver redeems it.
-- Patient may revoke at any time (status → revoked).
-- ---------------------------------------------------------------------------
create table if not exists public.caregiver_links (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references auth.users (id) on delete cascade,
  caregiver_id    uuid references auth.users (id) on delete cascade,
  status          text not null default 'pending'
                    check (status in ('pending', 'active', 'revoked')),
  invite_code     text not null,
  -- How the caregiver labels this person (e.g. "Mom", "Mrs. Silva").
  label           text not null default '',
  created_at      timestamptz not null default now(),
  consented_at    timestamptz,
  revoked_at      timestamptz,
  updated_at      timestamptz not null default now(),
  constraint caregiver_links_invite_code_unique unique (invite_code),
  constraint caregiver_links_pair_unique unique (patient_id, caregiver_id)
);

create index if not exists caregiver_links_caregiver_id_idx
  on public.caregiver_links (caregiver_id);
create index if not exists caregiver_links_patient_id_idx
  on public.caregiver_links (patient_id);
create index if not exists caregiver_links_invite_code_idx
  on public.caregiver_links (invite_code);

create trigger caregiver_links_set_updated_at
  before update on public.caregiver_links
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Helpers for RLS
-- ---------------------------------------------------------------------------
create or replace function public.is_active_caregiver_of(p_patient uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.caregiver_links l
    where l.caregiver_id = auth.uid()
      and l.patient_id = p_patient
      and l.status = 'active'
  );
$$;

create or replace function public.is_patient_of_link(p_patient uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() = p_patient;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.caregiver_links enable row level security;

-- Patients see / manage their own links (invites they created, people watching them).
create policy "caregiver_links_select_patient"
  on public.caregiver_links for select
  using (auth.uid() = patient_id);

-- Caregivers see links they belong to (active or pending once claimed).
create policy "caregiver_links_select_caregiver"
  on public.caregiver_links for select
  using (auth.uid() = caregiver_id);

-- Anyone authenticated may look up a pending invite by code (redeem flow).
-- Scoped: only pending rows with no caregiver yet are visible this way.
create policy "caregiver_links_select_pending_invite"
  on public.caregiver_links for select
  using (status = 'pending' and caregiver_id is null);

-- Patient creates invites.
create policy "caregiver_links_insert_patient"
  on public.caregiver_links for insert
  with check (auth.uid() = patient_id and caregiver_id is null);

-- Caregiver claims a pending invite (sets caregiver_id = self, status active).
create policy "caregiver_links_update_claim"
  on public.caregiver_links for update
  using (
    (status = 'pending' and caregiver_id is null)
    or auth.uid() = patient_id
    or auth.uid() = caregiver_id
  )
  with check (
    auth.uid() = patient_id
    or auth.uid() = caregiver_id
    or (caregiver_id = auth.uid() and status = 'active')
  );

-- Patient or caregiver may soft-delete (we prefer revoke via update; allow delete for cleanup).
create policy "caregiver_links_delete_parties"
  on public.caregiver_links for delete
  using (auth.uid() = patient_id or auth.uid() = caregiver_id);

-- Profiles: caregivers can read names of people they care for.
create policy "profiles_select_as_caregiver"
  on public.profiles for select
  using (public.is_active_caregiver_of(id));

-- Medications: caregivers can read a consenting patient's list.
create policy "medications_select_as_caregiver"
  on public.medications for select
  using (public.is_active_caregiver_of(user_id));

-- Dose events: caregivers can read + log on behalf of a consenting patient.
create policy "dose_events_select_as_caregiver"
  on public.dose_events for select
  using (public.is_active_caregiver_of(user_id));

create policy "dose_events_insert_as_caregiver"
  on public.dose_events for insert
  with check (public.is_active_caregiver_of(user_id));
