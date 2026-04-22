-- ============================================================================
-- SpiritPath · Migration 0001 · User core
-- ============================================================================
-- Creates: all enums · profiles table · triggers (handle_new_user · set_updated_at) · RLS Pattern A
-- Platform: iOS + Android unified (shared schema)
-- Reference: master plan §07 Supabase architecture · Tab 04 Sync protocol wave 1
-- ============================================================================

-- ─── 1. Enums (single source of truth for type constants) ─────────────────

create type public.lineage_id as enum ('mun', 'sodh', 'chah');

create type public.stage_key as enum (
  'outer_path',
  'quiet_ground',
  'inner_forest',
  'silent_temple',
  'open_awareness'
);

create type public.path_id as enum (
  'mindful_walking',
  'everyday',
  'body',
  'retreat'
);

create type public.session_type as enum (
  'walking',
  'quiet',
  'breath',
  'sound_bath'
);

create type public.teaching_mode as enum (
  'listen',
  'understand',
  'reflect'
);

create type public.subscription_status as enum (
  'trial',
  'active',
  'grace',
  'expired',
  'cancelled'
);

create type public.subscription_provider as enum ('apple', 'google');

create type public.compliance_request_status as enum (
  'pending',
  'processing',
  'ready',
  'delivered',
  'failed'
);

-- ─── 2. profiles table ────────────────────────────────────────────────────

create table public.profiles (
  id                        uuid primary key references auth.users(id) on delete cascade,
  display_name              text,
  avatar_url                text,
  selected_teacher_id       text,
  selected_lineage_id       public.lineage_id,
  chosen_path_id            public.path_id,
  environment_tags          text[] not null default '{}',
  guidance_tags             text[] not null default '{}',
  peace_context             text,
  meditation_experience     text,
  emotional_state           text,                        -- expires after 7 days in app logic
  aspiration                text,
  quiz_raw                  jsonb,                       -- full onboarding answers · re-analysis friendly
  onboarding_completed_at   timestamptz,
  timezone                  text not null default 'America/New_York',
  locale                    text not null default 'en',
  tracking_opt_out          bool not null default false,
  deleted_at                timestamptz,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

comment on table public.profiles is
  'User profile · 1:1 with auth.users · RLS Pattern A (self-only) · soft delete via deleted_at';
comment on column public.profiles.quiz_raw is
  'Full onboarding quiz answers as received · kept for potential re-analysis without re-surveying user';
comment on column public.profiles.emotional_state is
  'App logic expires this value 7 days after onboarding_completed_at · do not read after that window';

-- ─── 3. Triggers · functions ──────────────────────────────────────────────

-- 3a. Auto-create profiles row when auth.users row is inserted
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- idempotent · survives trigger re-run, partial rollback, double-fire
  insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;
  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Auto-creates a profiles row for every new auth.users row · security definer to bypass RLS on insert';

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3b. Generic updated_at refresher · reused across every table with updated_at column
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Generic trigger body · sets updated_at = now() on every UPDATE · attach before update on any table with updated_at';

create trigger tr_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ─── 4. RLS Pattern A · user owns rows ────────────────────────────────────

alter table public.profiles enable row level security;

-- SELECT · own row only · filtered by soft delete
create policy "profiles_select_own"
  on public.profiles
  for select
  using (auth.uid() = id and deleted_at is null);

-- INSERT · safety net · trigger handles it but policy blocks manual inserts
create policy "profiles_insert_own"
  on public.profiles
  for insert
  with check (auth.uid() = id);

-- UPDATE · own row only · cannot change id
create policy "profiles_update_own"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No DELETE policy · soft delete via UPDATE deleted_at = now()
-- Hard delete only via account-deletion edge function (service role bypass)
