-- ============================================================================
--  V12 · Stage advancement RLS · Phase 2.7a
-- ============================================================================
--
--  Server-side validation for journey_progress.current_stage advancement.
--  Client-side advancement (checkAndAdvanceStage) is the authoritative path,
--  but RLS prevents tampered clients from skipping stages or advancing
--  without practice.
--
--  Composite rule per stage transition:
--    - sessions-in-stage  (walking · completed · started_at >= entered_at)
--    - days-in-stage      (now() - entered_at)
--
--  Threshold table MUST stay in sync with:
--    - iOS    SpiritPath/Core/Domain/StageAdvancementRule.swift
--    - Android (Phase 2.7a) StageAdvancementRule.kt
--
-- ============================================================================

create or replace function public.can_advance_stage(
  p_user_id   uuid,
  p_from_stage int,
  p_to_stage   int
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entered_at        timestamptz;
  v_session_count     int;
  v_days_in_stage     int;
  v_required_sessions int;
  v_required_days     int;
begin
  -- Single-step forward advancement only · range 2..5
  if p_to_stage <> p_from_stage + 1 then
    return false;
  end if;
  if p_to_stage < 2 or p_to_stage > 5 then
    return false;
  end if;

  -- Threshold table · keep in sync with iOS StageAdvancementRule + Android StageAdvancementRule.kt
  v_required_sessions := case p_to_stage
    when 2 then 7
    when 3 then 14
    when 4 then 21
    when 5 then 30
  end;
  v_required_days := case p_to_stage
    when 2 then 14
    when 3 then 30
    when 4 then 45
    when 5 then 60
  end;

  -- Read stages_entered_at[p_from_stage] · timestamp user entered current stage
  select (stages_entered_at ->> p_from_stage::text)::timestamptz
    into v_entered_at
  from public.journey_progress
  where user_id = p_user_id;

  if v_entered_at is null then
    return false;
  end if;

  -- Sessions-in-stage = walking · completed · not deleted · started_at >= entered_at
  select count(*)
    into v_session_count
  from public.sessions
  where user_id     = p_user_id
    and session_type = 'walking'
    and completed    = true
    and deleted_at   is null
    and started_at   >= v_entered_at;

  -- Days-in-stage · whole-day floor since entered_at
  v_days_in_stage := extract(day from (now() - v_entered_at))::int;

  return v_session_count >= v_required_sessions
     and v_days_in_stage  >= v_required_days;
end;
$$;

comment on function public.can_advance_stage is
  'Validates stage advancement on UPDATE · single-step only · sessions-in-stage + days-in-stage thresholds · keep thresholds synced with client StageAdvancementRule (iOS Swift + Android Kotlin).';

-- ─── Replace journey_progress UPDATE policy with rule-aware version ─────────
drop policy if exists "journey_progress_update_own" on public.journey_progress;

create policy "journey_progress_update_own"
  on public.journey_progress for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (
      -- Allow updates that don't touch current_stage (totals · last_activity_at · stages_entered_at first-set)
      current_stage = (select current_stage from public.journey_progress where user_id = auth.uid())
      -- OR a valid advancement
      or public.can_advance_stage(
           auth.uid(),
           (select current_stage from public.journey_progress where user_id = auth.uid()),
           current_stage
         )
    )
  );
