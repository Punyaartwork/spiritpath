-- ============================================================================
-- SpiritPath · Migration 0006 · Night log
-- ============================================================================
-- Creates: night_log_entries · client-encrypted body · RLS Pattern A
-- Encryption (C1 · locked 2026-04-21):
--   Algorithm:   AES-256-GCM
--   Nonce:       12 bytes random · prepended to ciphertext
--   Key alias:   'spiritpath.nightlog.v1'
--   Key access:  Keychain (iOS · kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly ·
--                kSecAttrSynchronizable = false) / AndroidKeyStore (PURPOSE_ENCRYPT |
--                PURPOSE_DECRYPT · requireAuthenticationOnLaunch = false) · device-bound
--   Payload:     nonce(12) ‖ ciphertext ‖ tag(16)  → bytea
--   Schema ver:  v1 (bump alias to v2 if spec changes · migration required)
-- Server sees only opaque bytes · plaintext never leaves device.
-- ============================================================================

-- ─── 1. night_log_entries ─────────────────────────────────────────────────

create table public.night_log_entries (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,

  logged_at       timestamptz not null,       -- device clock at log time (user's local night)
  body_ciphertext bytea,                      -- AES-256-GCM encrypted · see header
  mood            text,                       -- free-form mood tag (not encrypted · aggregate analytics friendly)

  deleted_at      timestamptz,                -- soft delete
  created_at      timestamptz not null default now()
);

comment on table public.night_log_entries is
  'Before-sleep reflection · body encrypted on device with AES-256-GCM · server opaque · device-bound key in Keychain/Keystore · uninstall = permanent loss of old entries (documented in Settings copy)';
comment on column public.night_log_entries.body_ciphertext is
  'nonce(12) ‖ ciphertext ‖ tag(16) · key alias spiritpath.nightlog.v1 · schema version bump requires migration to spiritpath.nightlog.v2 + re-encrypt flow';
comment on column public.night_log_entries.mood is
  'Free-form text mood tag · intentionally NOT encrypted · enables aggregate mood-over-time analytics without breaking privacy posture (no PII · no text content)';

-- ─── 2. Index · hot path ─────────────────────────────────────────────────

-- Recent-first list · partial on soft-delete
create index idx_night_log_user_time
  on public.night_log_entries(user_id, logged_at desc)
  where deleted_at is null;

-- ─── 3. RLS · Pattern A · self-only ──────────────────────────────────────

alter table public.night_log_entries enable row level security;

create policy "night_log_select_own"
  on public.night_log_entries for select
  using (auth.uid() = user_id and deleted_at is null);

create policy "night_log_insert_own"
  on public.night_log_entries for insert
  with check (auth.uid() = user_id);

create policy "night_log_update_own"
  on public.night_log_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- No DELETE policy · soft delete via UPDATE deleted_at
-- Hard delete cascades when profiles row is removed by account-deletion edge function

-- ─── Copy lock · Settings → Night Log (C1 Round 8) ───────────────────────
-- Both platforms use identical verbatim string:
--   "Night Log entries are encrypted on this device. Uninstalling the app or
--    switching devices will permanently lose access to older entries."
-- Quiet · direct · statement of fact · matches "the path is not elsewhere" tone
