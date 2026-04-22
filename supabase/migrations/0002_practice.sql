-- ============================================================================
-- SpiritPath · Migration 0002 · Practice domain
-- ============================================================================
-- Creates: sessions · reflections · journey_progress · teaching_progress
--          + 5 indexes · RLS Pattern A · sync_journey_progress trigger
-- Platform: iOS + Android unified
-- Reference: master plan §07 · Tab 04 Sync protocol wave 1 (A1–A5 · C1–C5)
-- Android alignment (Round 9): uuid PK + cascade · soft delete · Pattern A
--                              · reuse set_updated_at · session_type/teaching_mode enums
--                              · indexes on user_id + started_at DESC
-- ============================================================================

-- ─── 1. sessions · offline-first core table ───────────────────────────────

create table public.sessions (
  -- client-generated UUID · offline-first (no server default · device assigns)
  id                     uuid primary key,

  user_id                uuid not null references public.profiles(id) on delete cascade,

  -- what kind of practice this session represents (C1 / C5 canonical)
  type                   public.session_type not null,

  -- session timing
  started_at             timestamptz not null,
  ended_at               timestamptz,
  duration_target_sec    int check (duration_target_sec >= 0),
  duration_actual_sec    int check (duration_actual_sec >= 0),

  -- step counts (HealthKit / Health Connect source · not synced to server)
  mindful_steps          int not null default 0 check (mindful_steps     >= 0),
  total_steps            int not null default 0 check (total_steps       >= 0),
  moments_of_return      int not null default 0 check (moments_of_return >= 0),

  -- snapshots captured at session start (for historical accuracy if lineage changes)
  lineage_id             public.lineage_id,
  stage_index_at_time    int check (stage_index_at_time between 1 and 5),

  -- session preferences snapshot · enables analytics on actual vs requested
  prefs_snapshot         jsonb not null default '{}'::jsonb,

  -- true only when user tapped "complete" (not "discard")
  completed              bool not null default false,

  -- offline sync fields (Round 2 C1 agreement · client_created_at on device clock)
  client_created_at      timestamptz not null,
  synced_at              timestamptz,

  -- soft delete · no DELETE policy · hard delete via edge function
  deleted_at             timestamptz,

  created_at             timestamptz not null default now()
);

comment on table public.sessions is
  'Practice session log · offline-first (client-generated UUID) · soft delete · step data stays in HealthKit/Health Connect, only aggregates mirrored here';
comment on column public.sessions.client_created_at is
  'Device local clock at session creation · authoritative for ordering when syncing a queue of offline sessions';
comment on column public.sessions.synced_at is
  'NULL = not yet pushed to server · set by client on successful upsert · enables sync-queue index';
comment on column public.sessions.prefs_snapshot is
  'Snapshot of practice_window prefs at session start · JSON: {place,pace,duration_target,ground,environment,guidance}';

-- ─── 2. reflections · 1:1 with sessions ────────────────────────────────────

create table public.reflections (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  session_id      uuid unique not null references public.sessions(id) on delete cascade,

  note_text       text,          -- freeform · user-written reflection
  anchor_phrase   text,          -- anchor chosen from suggestions · matches current stage

  deleted_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.reflections is
  '1:1 with sessions · unique session_id enforces · cascade delete when session deleted · anchor_phrase ties to stages.anchor_phrase content';

-- ─── 3. journey_progress · 1 row per user (overall arc tracker) ───────────

create table public.journey_progress (
  user_id             uuid primary key references public.profiles(id) on delete cascade,

  lineage_id          public.lineage_id not null,
  current_stage       int not null default 1 check (current_stage between 1 and 5),

  -- jsonb map: {"1": "2026-04-21T10:00:00Z", "2": null, ...}
  -- client-friendly shape · updated by sync_journey_progress trigger
  stages_entered_at   jsonb not null default '{}'::jsonb,

  total_sessions      int    not null default 0,
  total_duration_sec  bigint not null default 0,
  last_activity_at    timestamptz,

  updated_at          timestamptz not null default now()
);

comment on table public.journey_progress is
  'Per-user journey state · 1 row · created client-side on onboarding complete (not via auth trigger, because lineage_id is required) · sync_journey_progress trigger maintains totals';
comment on column public.journey_progress.stages_entered_at is
  'Map of stage_index (string key) → first-reached timestamp · never decreases · immutable once set per stage';

-- ─── 4. teaching_progress · per-user × per-unit resume ─────────────────────

-- Note · teaching_unit_id FK is deferred to V3 (requires teaching_units table).
-- Column is plain text here with no referential constraint · V3 adds the FK.

create table public.teaching_progress (
  user_id           uuid not null references public.profiles(id) on delete cascade,
  teaching_unit_id  text not null,  -- FK to teaching_units.id added in V3

  mode              public.teaching_mode not null,
  completion_pct    numeric(3,2) not null default 0 check (completion_pct between 0 and 1),
  last_position_sec int not null default 0 check (last_position_sec >= 0),
  completed_at      timestamptz,

  updated_at        timestamptz not null default now(),

  primary key (user_id, teaching_unit_id)
);

comment on table public.teaching_progress is
  'Per-user progress through a teaching_unit · composite PK · last_position_sec powers audio scrubber resume · FK to teaching_units added in V3';

-- ─── 5. Indexes · hot paths ───────────────────────────────────────────────

-- Home feed · "recent sessions" list · partial on soft-delete
create index idx_sessions_user_started
  on public.sessions(user_id, started_at desc)
  where deleted_at is null;

-- Stats · "completed sessions this week" · partial on completed + soft-delete
create index idx_sessions_user_completed
  on public.sessions(user_id, started_at desc)
  where completed = true and deleted_at is null;

-- Sync queue · client asks "which of my sessions are unsynced?"
create index idx_sessions_sync_queue
  on public.sessions(user_id, client_created_at)
  where synced_at is null and deleted_at is null;

-- Reflection list
create index idx_reflections_user_created
  on public.reflections(user_id, created_at desc)
  where deleted_at is null;

-- Teaching resume · "which units did user touch recently?"
create index idx_teaching_progress_user_recent
  on public.teaching_progress(user_id, updated_at desc);

-- ─── 6. RLS · Pattern A · self-only ───────────────────────────────────────

alter table public.sessions           enable row level security;
alter table public.reflections        enable row level security;
alter table public.journey_progress   enable row level security;
alter table public.teaching_progress  enable row level security;

-- sessions
create policy "sessions_select_own"
  on public.sessions for select
  using (auth.uid() = user_id and deleted_at is null);

create policy "sessions_insert_own"
  on public.sessions for insert
  with check (auth.uid() = user_id);

create policy "sessions_update_own"
  on public.sessions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- reflections
create policy "reflections_select_own"
  on public.reflections for select
  using (auth.uid() = user_id and deleted_at is null);

create policy "reflections_insert_own"
  on public.reflections for insert
  with check (auth.uid() = user_id);

create policy "reflections_update_own"
  on public.reflections for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- journey_progress
create policy "journey_progress_select_own"
  on public.journey_progress for select
  using (auth.uid() = user_id);

create policy "journey_progress_insert_own"
  on public.journey_progress for insert
  with check (auth.uid() = user_id);

create policy "journey_progress_update_own"
  on public.journey_progress for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- teaching_progress
create policy "teaching_progress_select_own"
  on public.teaching_progress for select
  using (auth.uid() = user_id);

create policy "teaching_progress_insert_own"
  on public.teaching_progress for insert
  with check (auth.uid() = user_id);

create policy "teaching_progress_update_own"
  on public.teaching_progress for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- No DELETE policies · soft delete on sessions + reflections · no soft delete on progress tables
-- Hard delete propagates via FK cascade when profiles row is removed (account deletion edge function)

-- ─── 7. Reuse set_updated_at trigger (defined in V1) ──────────────────────

create trigger tr_reflections_updated
  before update on public.reflections
  for each row execute function public.set_updated_at();

create trigger tr_journey_progress_updated
  before update on public.journey_progress
  for each row execute function public.set_updated_at();

create trigger tr_teaching_progress_updated
  before update on public.teaching_progress
  for each row execute function public.set_updated_at();

-- Note · sessions has no updated_at column · it is append-only from client perspective
-- (except completed=true and synced_at which are one-shot writes · not true "updates")

-- ─── 8. sync_journey_progress · auto-maintain journey totals ──────────────

create or replace function public.sync_journey_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only fire when a session transitions to completed=true (edge trigger)
  if new.completed = true
     and (old is null or old.completed is distinct from new.completed)
     and new.lineage_id is not null
  then
    insert into public.journey_progress (
      user_id,
      lineage_id,
      current_stage,
      stages_entered_at,
      total_sessions,
      total_duration_sec,
      last_activity_at
    )
    values (
      new.user_id,
      new.lineage_id,
      coalesce(new.stage_index_at_time, 1),
      case
        when new.stage_index_at_time is not null and new.ended_at is not null
        then jsonb_build_object(new.stage_index_at_time::text, new.ended_at)
        else '{}'::jsonb
      end,
      1,
      coalesce(new.duration_actual_sec, 0),
      new.ended_at
    )
    on conflict (user_id) do update set
      total_sessions     = public.journey_progress.total_sessions + 1,
      total_duration_sec = public.journey_progress.total_duration_sec + coalesce(new.duration_actual_sec, 0),
      last_activity_at   = coalesce(new.ended_at, public.journey_progress.last_activity_at),
      -- stages_entered_at: set if not already present for this stage
      stages_entered_at  = case
        when new.stage_index_at_time is null or new.ended_at is null
          then public.journey_progress.stages_entered_at
        when public.journey_progress.stages_entered_at ? new.stage_index_at_time::text
          then public.journey_progress.stages_entered_at
        else
          public.journey_progress.stages_entered_at
          || jsonb_build_object(new.stage_index_at_time::text, new.ended_at)
      end;
  end if;

  return new;
end;
$$;

comment on function public.sync_journey_progress() is
  'Maintains journey_progress totals when session transitions to completed · stages_entered_at is append-only (first reach wins) · current_stage is NOT advanced by this trigger · app logic decides advancement based on practice quality';

create trigger tr_session_sync_journey
  after insert or update of completed on public.sessions
  for each row execute function public.sync_journey_progress();
