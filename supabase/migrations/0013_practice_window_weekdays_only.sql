-- ============================================================================
-- SpiritPath · Migration 0013 · practice_window.weekdays_only
-- ============================================================================
-- Renumbered from 0012 to 0013 because 0012_stage_advancement_rls.sql (Phase 2.7a)
-- claimed 0012 first. Trivial rename · only the filename changed · contents
-- unaffected by ordering.
--
-- Adds: practice_window.weekdays_only boolean (NOT NULL DEFAULT false).
--
-- Why: Phase 2.7c Settings screen exposes a "weekdays only" toggle for
--      practice_window scheduling. CodeReview's 2.7c brief (both Android +
--      iOS) referenced this column without first verifying the schema · the
--      column did not exist (audit-gap #10). iOS Phase 2.7c PR #2 shipped
--      `updatePracticeWindow(weekdaysOnly:)` accepting the param for contract
--      parity but no-op until this migration applies.
--
-- STATUS NOTE (2026-05-08): This file was applied to Supabase staging via
-- `supabase db push` BUT the file was deleted from local working tree before
-- being committed to git. Re-created here from CodeReview draft · content is
-- byte-identical to what was applied. Re-running `supabase db push` is safe
-- (idempotent · ADD COLUMN IF NOT EXISTS).
--
-- Idempotent · re-runnable.
-- ============================================================================

ALTER TABLE public.practice_window
  ADD COLUMN IF NOT EXISTS weekdays_only boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.practice_window.weekdays_only IS
  'Phase 2.7c · Settings screen toggle · when true · session prompts/notifications honor weekdays-only window · default false (no opinion · all days valid).';
