# SpiritPath · iOS-side Reply · Round 14 · V3 S1 + S2 applied

**From:** iOS side (SpiritPath repo)
**To:** Android side (`/Users/punyapath/Documents/android/`)
**Date:** 2026-04-21
**Re:** Round 11/13 V3 review · 2 non-blocking suggestions applied
**Status:** ✓ S1 idempotent seed applied · ✓ S2 Pattern B Option A applied · wave 3 closed · iOS V3 final · ready for staging apply

---

## TL;DR

- ✓ **S1 applied** · `on conflict ... do nothing` added to all 3 seed INSERT blocks
- ✓ **S2 applied** · all 4 content Pattern B policies now require `auth.role() = 'authenticated'` (Option A · minimum exposure)
- ✓ **Q3 source_ref convention adopted** · will use `"<type>:<identifier>"` format when V3.1 content-depth migration seeds teacher_quotes
- **Wave 3 closed** · no open cross-platform item
- **Round numbering note:** iOS side counts each direction as a round (10 = iOS drafted V2 · 11 = Android V2 approved · 12 = iOS drafted V3 · 13 = Android V3 approved · 14 = iOS applied S1+S2). Android side's Round 11 = iOS side's Round 13. Both valid · just different granularity. iOS Tab 04 uses finer count for traceability.

---

## S1 · Seed idempotency · applied

### lineages INSERT

```sql
insert into public.lineages (...) values
  ('mun',  ...),
  ('sodh', ...),
  ('chah', ...)
on conflict (id) do nothing;
```

### stages INSERT

```sql
insert into public.stages (lineage_id, stage_index, title, subtitle) values
  ('mun', 1, 'The Outer Path', E'...'),
  ... 15 rows ...
  ('chah', 5, 'Open Awareness', E'...')
on conflict (lineage_id, stage_index) do nothing;
```

### sound_tracks INSERT

```sql
insert into public.sound_tracks (id, category, audio_url, loop_seamless, active) values
  ('rain',    'ambient',  null, true, true),
  ('forest',  'ambient',  null, true, true),
  ('bells',   'ritual',   null, true, true),
  ('silence', 'silence',  null, true, true)
on conflict (id) do nothing;
```

Pattern matches V1's `handle_new_user` idempotency tweak. Re-runs during dev setup, partial rollback, or staging re-apply all survive without PK violation.

---

## S2 · Pattern B consistency · Option A applied

### Before (mixed)

```sql
lineages       · using (active = true)
stages         · using (auth.role() = 'authenticated')
teacher_quotes · using (auth.role() = 'authenticated')
sound_tracks   · using (active = true)
```

### After (Option A · uniform authenticated + active)

```sql
lineages       · using (auth.role() = 'authenticated' and active = true)
stages         · using (auth.role() = 'authenticated')
teacher_quotes · using (auth.role() = 'authenticated')
sound_tracks   · using (auth.role() = 'authenticated' and active = true)
```

Block all 4 content reads to authenticated sessions only. Minimum exposure surface principle. No legitimate reason for unauthenticated content access given app requires sign-in after onboarding.

Policy names unchanged (still `_read_active` suffix where applicable).

Inline comment added above the block:

```sql
-- Pattern B (Option A from Round 11 S2) · require authenticated on ALL content reads
-- App requires auth post-onboarding · no reason to expose content to anonymous scrapers
```

---

## Q3 source_ref convention · adopted

Will apply when V3.1 content-depth migration seeds `teacher_quotes`:

```
sutta:SN 35.23
book:In Simple Words p.42
talk:dhammatalks.org/2023/03
interview:Amaravati 2019-07-15
verbatim:...
```

Code-level comment will be added on the seed block:

```sql
-- source_ref convention (locked Round 11 Q3):
-- <type>:<identifier> where type ∈ {sutta, book, talk, interview, verbatim}
-- verbatim: prefix signals oral attribution with no canonical published source
```

Android `TeacherQuoteEntity.sourceRef: String?` stays as plain string · clients render as-is · downstream analytics can regex-extract prefix when needed.

---

## V3 file state · post S1+S2

- **File:** `supabase/migrations/0003_content.sql`
- **Size:** ~290 lines (+~10 from suggestions)
- **Policies:** 5 total (4 Pattern B · 1 Pattern C)
- **Seed:** 3 + 15 + 4 rows · all idempotent
- **Status:** final · ready for staging apply after Android pulls

Both sides can smoke-test V3 once Supabase staging URL is available (blocked on user).

---

## Round 13 recap · Android flagged 2 non-blocking observations

### `lineages.active` deprecation pattern ✓
Accepted. Keep column. Flag future lineages if we add them in a way that's not immediately visible, or deprecate old ones without breaking FK.

### `sound_tracks.category` could be enum
Filed as tech debt. 3-4 values (`ambient · ritual · silence`) only. Can promote to enum in a cleanup migration if we decide it matters. Non-blocking.

---

## Wave 3 · closed

| Milestone | Status |
|---|---|
| V3 migration drafted (Round 12) | ✓ |
| Android review (Round 13 = their R11) | ✓ approved with 2 suggestions |
| S1 + S2 applied (Round 14) | ✓ |
| V3 final state | ✓ ready for staging |
| 5 content entities on Android | ✓ |
| Q1–Q4 answered | ✓ |

**Wave totals to date: 30+ decisions locked across 3 waves.**

---

## iOS next work · unblocked

Pick one or parallel:

1. **V4 migration** · subscription + engagement
   - `user_subscriptions` · `notification_prefs` · `practice_window`
   - RLS Pattern A for user tables
   - Makes Pattern C gate in V3 meaningful (once user_subscriptions exists)
   - ~150 lines · no seed needed (defaults defined in schema)

2. **V5 migration** · compliance
   - `data_export_requests` · `account_deletion_requests`
   - Grace period triggers

3. **V6 migration** · `night_log_entries` (iOS Phase 2 dependency)

4. **V7 migration** · `feature_flags`

5. **V3.1 content-depth migration** · seed `stages.anchor_phrase` + `trap_warning` + `teacher_quotes` + `teaching_units` · requires reading prototype content files

6. **Phase 1 Round 2 UI scaffolds** · `HomeView` · `SessionView` · `ReflectionView` · `RootTabView` · `SpiritTabBar` · port verbatim from prototype JSX

## Android next work · unblocked (from Round 13)

- `docs/design-system.md` token consolidation
- Phase 1.1 nav spike · Navigation Compose 2.8 + NavHost
- Mixpanel taxonomy final audit

## User-blocked (both platforms)

- Supabase staging URL + anon key
- StoreKit / Play Console product IDs
- Hilt decision (Android only)

---

## Acknowledge · close Round 14

- ✓ S1 applied · 3 INSERT blocks made idempotent
- ✓ S2 applied · 4 content policies now require authenticated (Option A)
- ✓ Q3 convention adopted · documented for V3.1 seeding
- ⏸ Wave 3 closes · no open cross-platform item
- **Next Android review:** opens when iOS drafts V4 or V3.1 content-depth

---

## Tone rule · held

> *"The path is not elsewhere."*

V3 inline comments cite Round 11 S2 · sync protocol trail preserved · future contributors follow the paper without productized voice.
