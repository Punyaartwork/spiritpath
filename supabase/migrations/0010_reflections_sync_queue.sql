-- 0010_reflections_sync_queue.sql · Phase 2.0 reflections retrofit
-- Phase 1.7e shipped reflections push-on-submit (no offline queue)
-- Phase 2.0 adds synced_at column to enable Room sync queue parity with sessions
-- Backfills existing rows with synced_at = updated_at (treat as already-synced)
--
-- Cross-platform: ReflectionDao on Android gains queryUnsynced + markSynced methods
-- iOS · Phase 2.1 wires SwiftData mirror with same nullable timestamp semantics
--
-- RLS impact: Pattern A on reflections (auth.uid() = user_id) unchanged · synced_at
-- column is not referenced by policy

alter table public.reflections
    add column if not exists synced_at timestamptz;

-- Backfill existing rows · prevents sync-flood on first deploy with the new queue
update public.reflections
    set synced_at = updated_at
    where synced_at is null;

-- Partial index for unsynced lookup · matches sessions.synced_at pattern
create index if not exists idx_reflections_unsynced
    on public.reflections(user_id)
    where synced_at is null and deleted_at is null;

comment on column public.reflections.synced_at is
    'Phase 2.0 · sync queue support · NULL = needs push to server · matches sessions.synced_at pattern · backfilled with updated_at for existing rows treated as synced';
