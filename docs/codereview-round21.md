# SpiritPath · CodeReview-side brief · Round 21 · Migration ordering + V1 enum completion + V5-V7 renumber

**From:** CodeReview
**To:** iOS + Android sessions (both notified)
**Date:** 2026-04-22
**Re:** Staging push unblocked · 3 drift fixes applied to get V1-V8 live on staging Supabase
**Status:** ✅ CLOSED · all migrations applied to `yepgrbljewjktvuyhxso` · wave 6 closed
**Initiated by:** CodeReview during user-led `supabase db push` · 2 sequential failures caught + patched

---

## TL;DR

- **Staging pushed clean · V1-V8 applied on `yepgrbljewjktvuyhxso`** · all 17 tables live · all 8 enums live (compliance_request_status now has 6 values)
- 3 drift fixes landed together:
  1. **V3/V4 Pattern C split** · V3 `teaching_units_free_or_paid` policy cannot reference `user_subscriptions` (V4 table) · V3 ships stage-1-only placeholder · V4 drops + recreates with full subscription gate
  2. **V1 `compliance_request_status` enum completion** · V1 shipped with 5 values · V5 policy uses 6 (`'cancelled'` missing) · new migration `0005_compliance_enum_prep.sql` adds via `ALTER TYPE ADD VALUE` standalone (Postgres cannot use new enum value in same txn it's added)
  3. **V5/V6/V7 renumbered to V6/V7/V8** · Supabase CLI migration regex `^\d+_.*\.sql$` rejects non-digit infix (`0004a_`) · rename was the only path to insert between V4 and V5-content
- 🚨 Sweep 01 enum audit gap logged as L1 lesson · count comparison on `ComplianceRequestStatus` reported `✓` but actually SQL had 5 · Kotlin had 6 · next sweep must do cross-check of SQL usage across files, not just per-enum count
- Android entities already ship the correct 6-value enum · no Android code change · comment-string housekeeping (V5/V6/V7 tags → V6/V7/V8) deferred as non-blocking

---

## Fix 1 · V3/V4 Pattern C split

**File A:** `SpiritPath/supabase/migrations/0003_content.sql:156-175`

Before (ships Pattern C inline · fails at push):
```sql
create policy "teaching_units_free_or_paid"
  on public.teaching_units for select
  using (
    published = true
    and (
      stage_index = 1
      or exists (
        select 1 from public.user_subscriptions   -- ← forward-dep to V4
        ...
      )
    )
  );
```

After (V3 placeholder · stage-1-only):
```sql
create policy "teaching_units_free_or_paid"
  on public.teaching_units for select
  using (
    published = true
    and stage_index = 1
  );
```

**File B:** `SpiritPath/supabase/migrations/0004_subscription_engagement.sql` · appended upgrade block:
```sql
-- ─── 5. Upgrade V3 Pattern C on teaching_units · user_subscriptions now exists ───
drop policy if exists "teaching_units_free_or_paid" on public.teaching_units;
create policy "teaching_units_free_or_paid"
  on public.teaching_units for select
  using (
    published = true
    and (
      stage_index = 1
      or exists (
        select 1 from public.user_subscriptions
        where user_id = auth.uid()
          and status in ('trial', 'active', 'grace')
          and current_period_end > now()
          and deleted_at is null
      )
    )
  );
```

**Why:** Postgres `CREATE POLICY ... USING (... FROM <table> ...)` resolves table refs at creation time · cannot reference a table that ships in a later migration. Previous V3 comment (lines 177-180) claimed "Postgres defers FK-like checks in policies" · this was wrong · removed in the fix.

**Effect during V3-only window (pre-V4 apply):** only stage 1 readable · safe by default · no paid content leak.

**Effect after V4 applies:** full Pattern C subscription gate active · stage_index = 1 free OR active subscription in trial/active/grace and not expired and not soft-deleted.

---

## Fix 2 · V1 `compliance_request_status` enum completion

**New file:** `SpiritPath/supabase/migrations/0005_compliance_enum_prep.sql`

```sql
-- V1 · compliance_request_status enum completion · shipped missing 'cancelled' value
-- ... (full header comment in file)

alter type public.compliance_request_status add value if not exists 'cancelled';

comment on type public.compliance_request_status is
  'Lifecycle of compliance requests (data_export · account_deletion) · 6 values · terminal states = delivered / failed / cancelled · R21 ensured cancelled landed after V1 shipped incomplete';
```

**Root cause:** V1 `0001_user_core.sql:51` defined enum as `('pending', 'processing', 'ready', 'delivered', 'failed')` · 5 values. V5 (now V6) `0006_compliance.sql:98` policy `account_deletion_cancel_own` uses `status in ('pending', 'cancelled')` · references 6th value. V1 author forgot to include `'cancelled'` · drift masked by sweep 01 enum count bug.

**Why standalone migration:** Postgres 12+ allows `ALTER TYPE ADD VALUE` inside a transaction · BUT the new value cannot be used in the same transaction it was added. So V6 policy cannot `ALTER TYPE` + `CREATE POLICY` in one file. Standalone migration forces commit between the two operations.

**Cross-platform parity:** Android entity `ComplianceRequestStatus` enum at `DataExportRequestEntity.kt:54-60` already ships all 6 values (`PENDING · PROCESSING · READY · DELIVERED · FAILED · CANCELLED`). Android shipped correct · V1 SQL was incomplete. `0005_compliance_enum_prep.sql` restores parity.

**iOS entities (Phase 1 R2 · not yet built):** must include all 6 values when drafted · tracked.

---

## Fix 3 · V5/V6/V7 → V6/V7/V8 renumber

**Files renamed:**
- `0005_compliance.sql` → `0006_compliance.sql`
- `0006_night_log.sql` → `0007_night_log.sql`
- `0007_feature_flags.sql` → `0008_feature_flags.sql`

**New 0005 slot:** `0005_compliance_enum_prep.sql` (Fix 2 above)

**Reason for rename over lex-sort hack:**

iOS session initially tried `0004a_compliance_enum_prep.sql` (letter infix between `0004_` and `0005_`). Supabase CLI rejected it · migration filename regex expects digits-only prefix followed by underscore (`^\d+_.*\.sql$`). Alternative digit-only lex-sort attempts failed too (`00041_` sorts after `0004_` but before `0005_` requires comparing underscore 0x5F vs digit 0x31 · underscore is larger · so `00041_` sorts before `0004_` which is worse). Rename was the only path.

**Safety of rename:**
- V1-V4 applied on remote · remote migration log stops at `0004` · no collision risk when renamed files push as `0006`/`0007`/`0008`
- V5/V6/V7 never successfully applied (both push attempts failed on V5) · no transactional residue · `schema_migrations` table has no rows for them
- Android never tagged file path in code · only in doc-string comments (cosmetic · deferred)

---

## Push result · verified

Local migration list after fixes:

```
Local | Remote | Time
------|--------|------
0001  | 0001   | ✓ user_core (profiles + enums + handle_new_user)
0002  | 0002   | ✓ practice (sessions · reflections · journey · teaching_progress)
0003  | 0003   | ✓ content (lineages · stages · teaching_units · teacher_quotes · sound_tracks · placeholder Pattern C)
0004  | 0004   | ✓ subscription_engagement (user_subscriptions · notification_prefs · practice_window · Pattern C upgrade)
0005  | 0005   | ✓ compliance_enum_prep (ALTER TYPE ADD VALUE 'cancelled')  [NEW · R21]
0006  | 0006   | ✓ compliance (data_export_requests · account_deletion_requests)  [was 0005]
0007  | 0007   | ✓ night_log (night_log_entries · encrypted)  [was 0006]
0008  | 0008   | ✓ feature_flags (feature_flags + seed)  [was 0007]
```

**Staging URL:** https://supabase.com/dashboard/project/yepgrbljewjktvuyhxso
**Expected dashboard state:**
- Database → Tables · **17 tables** · profiles · sessions · reflections · journey_progress · teaching_progress · lineages · stages · teaching_units · teacher_quotes · sound_tracks · user_subscriptions · notification_prefs · practice_window · data_export_requests · account_deletion_requests · night_log_entries · feature_flags
- Database → Types · **8 enums** · compliance_request_status = 6 values
- Database → Policies · `teaching_units_free_or_paid` final form = full subscription gate (V4-upgraded)
- Database → Triggers · `handle_new_user` on `auth.users`

---

## Sweep 01 audit gap · L1 lesson logged

Sweep 01 (2026-04-22 · earlier same day) reported "`ComplianceRequestStatus | PENDING, PROCESSING, READY, DELIVERED, FAILED | ✓`" · **wrong**. Android enum class has 6 values (includes `CANCELLED`) · sweep agent missed by doing per-enum count without cross-checking SQL usage across migrations.

**Rule for next sweep:**
- Per-enum check must include:
  1. Enum definition in `CREATE TYPE ... AS ENUM (...)` across all migrations
  2. Kotlin enum class values in all entity files
  3. **Any `status in (...)` · `status = '...'` · column equality or check across all migration SQL files** (this would have caught `'cancelled'` use in V5 policy without definition)
- If #3 finds a value not in #1, flag as ENUM_DRIFT (SQL-internal) regardless of Kotlin side

Rule added to CodeReview audit procedure · no sync round needed to implement (procedure change is internal to CodeReview agent).

---

## Cross-platform action items

### iOS session · ✅ done
- Applied V3/V4 Pattern C split
- Created `0005_compliance_enum_prep.sql`
- Renamed `0005/0006/0007` → `0006/0007/0008`
- Deleted dead file `0004a_compliance_enum_prep.sql` (replaced by renumbered `0005_`)
- Push succeeded · V1-V8 applied to remote

### Android session · cosmetic housekeeping (non-blocking · no git push needed until bundled)
Update doc-string comments in these entity files · reference migration numbers only:
- `DataExportRequestEntity.kt` header · `V5` → `V6`
- `AccountDeletionRequestEntity.kt` header · `V5` → `V6`
- `NightLogEntryEntity.kt` header · `V6` → `V7`
- `FeatureFlagEntity.kt` header · `V7` → `V8`
- `FeatureFlagsRepository.kt` header (if references · `V7` → `V8`)

No logic change · no Kotlin enum change · no Room schema change. Pure doc-string find-replace.

Bundle into next Android commit · do not ship as standalone commit.

### User-owned (unblocked after this round)
- Set up Apple + Google providers in Supabase dashboard Authentication → Providers
- Configure redirect URL: `https://yepgrbljewjktvuyhxso.supabase.co/auth/v1/callback`
- After providers set · smoke test auth from either platform · confirm `profiles` row auto-creates via `handle_new_user` trigger
- Android session: clean working tree (`.idea` files + untracked `docs/` + `CLAUDE.md`) before next push
- Android session: fix stale values in `core/util/Constants.kt` (trial days 14 → 7 · remove OneSignal placeholder · remove stale table constants · remove duplicate `util/Constants.kt`)

### CodeReview
- R21 doc drafted (this file)
- Plan Tab 04 card to append
- Sweep 02 triggered on: next migration OR Phase 1.1 lands OR R20 opens (quiz predicates · still recommended)

---

## Paper trail · cross-references

- **Round 11 Q4 smoke test** (Pattern C subscription gate readable end-to-end) · now actually runnable on staging · V4 upgrade block makes the gate live
- **Sweep 01** (2026-04-22 earlier) · missed enum count bug · corrected in this round
- **Plan Tab 04 · Wave 5 close (Round 19)** · claimed V1-V7 ready for push · actually had 2 latent bugs revealed only by `supabase db push`
- **Plan Tab 01 · §09 phase sequencing** · Phase 1.4 (Supabase schema + RLS) now partially complete · Auth providers + smoke test still pending

---

## Locked items · new for wave 6

| ID | Topic | Locked value |
|---|---|---|
| V1a | `compliance_request_status` enum values | 6 values · `pending` · `processing` · `ready` · `delivered` · `failed` · `cancelled` · ship in V1 + V5 (enum prep) |
| V3a | Pattern C forward-dep rule | RLS policies referencing tables in later migrations must be split: placeholder in earlier migration · upgrade (drop + recreate) in the migration that introduces the referenced table |
| M1 | Migration filename convention | Supabase CLI strict: `^\d+_<name>\.sql$` · no letter infix · always renumber for insertions · preserve paper trail via sync round doc |
| M2 | Enum ADD VALUE migration isolation | Any `ALTER TYPE ADD VALUE` must be standalone migration · new value cannot be used in same transaction |

---

## Tone rule

> *"The path is not elsewhere."*

---

**Wave 6 closed · paper trail intact · staging schema live.**
