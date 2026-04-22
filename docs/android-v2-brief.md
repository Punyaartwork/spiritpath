# SpiritPath · V2 Migration Review Brief · paste-ready

**Paste section "## Brief for Android Claude · V2 review" ให้ Android session**

---

## Brief for Android Claude · V2 review

### TL;DR · V2 drafted · opens wave 2 / sync round 10

iOS ส่ง V2 migration ให้ review · Android alignment 6 patterns ครบทุกข้อ · รอ confirm ก่อน apply staging

**File:** `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0002_practice.sql`
**Size:** 298 lines · 39 DDL statements
**Domain:** Practice (sessions · reflections · journey_progress · teaching_progress)

### ✅ Android's 6 alignment requests (from Round 9) · verified

| # | Pattern | V2 status |
|---|---|---|
| 1 | uuid PK + FK cascade (client-gen sessions) | ✓ `sessions.id uuid primary key` no default · client generates · `on delete cascade` to profiles |
| 2 | Soft delete via `deleted_at` | ✓ sessions + reflections have `deleted_at timestamptz` |
| 3 | RLS Pattern A with soft-delete filter on SELECT | ✓ all 4 tables · SELECT policy filters `deleted_at is null` where applicable |
| 4 | Reuse `set_updated_at()` from V1 | ✓ attached to reflections · journey_progress · teaching_progress (sessions is append-only) |
| 5 | Use `session_type` + `teaching_mode` enums | ✓ `sessions.type session_type not null` · `teaching_progress.mode teaching_mode not null` |
| 6 | Indexes on `user_id + started_at DESC` | ✓ `idx_sessions_user_started` + `idx_sessions_user_completed` + 3 more partial indexes |

### Table-by-table quick reference

**`sessions`** (16 columns)
- `id uuid primary key` · no default · **client-generated offline-first**
- `user_id` FK cascade
- `type session_type not null` · walking/quiet/breath/sound_bath
- `started_at · ended_at · duration_target_sec · duration_actual_sec`
- `mindful_steps · total_steps · moments_of_return` · all `int default 0`
- `lineage_id` + `stage_index_at_time` · snapshots at session start
- `prefs_snapshot jsonb` · `{place, pace, duration_target, ground, environment, guidance}`
- `completed bool default false`
- `client_created_at` (device clock · authoritative for sync ordering)
- `synced_at` (null until pushed) · drives sync queue index
- `deleted_at` (soft delete)

**`reflections`** (7 columns)
- `id uuid default gen_random_uuid()` · server-generated (no offline-first here · created via API)
- `session_id uuid unique` · 1:1 enforcement · cascade delete
- `note_text · anchor_phrase`
- soft delete + updated_at trigger

**`journey_progress`** (9 columns) · 1 row per user
- PK = `user_id` · not `id`
- `lineage_id not null` · **created client-side on onboarding complete** (not via auth trigger since lineage is required)
- `current_stage int check (1..5)` · NOT advanced by trigger (app logic decides)
- `stages_entered_at jsonb` · `{"1": "2026-04-21T10:00:00Z", "2": null, ...}` · append-only
- `total_sessions · total_duration_sec · last_activity_at`

**`teaching_progress`** (7 columns) · composite PK
- PK = `(user_id, teaching_unit_id)`
- `teaching_unit_id text not null` · **FK to teaching_units deferred to V3** (table doesn't exist yet)
- `mode teaching_mode not null` · listen/understand/reflect
- `completion_pct numeric(3,2)` · 0.00–1.00
- `last_position_sec int` · audio scrubber resume
- `completed_at`

### 5 indexes

| Index | Table | Cols | Partial predicate |
|---|---|---|---|
| `idx_sessions_user_started` | sessions | user_id, started_at DESC | `where deleted_at is null` |
| `idx_sessions_user_completed` | sessions | user_id, started_at DESC | `where completed = true and deleted_at is null` |
| `idx_sessions_sync_queue` | sessions | user_id, client_created_at | `where synced_at is null and deleted_at is null` |
| `idx_reflections_user_created` | reflections | user_id, created_at DESC | `where deleted_at is null` |
| `idx_teaching_progress_user_recent` | teaching_progress | user_id, updated_at DESC | (none) |

### `sync_journey_progress` trigger

**Fires:** `after insert or update of completed on sessions`

**Edge condition:** only when `new.completed = true` AND (`old is null` OR `old.completed is distinct from new.completed`) AND `lineage_id is not null`

**Effect:** upserts `journey_progress` with:
- `total_sessions += 1`
- `total_duration_sec += duration_actual_sec`
- `last_activity_at = ended_at` (if non-null)
- `stages_entered_at[stage_index_at_time] = ended_at` (first-reach wins · immutable)

**Does NOT:**
- Advance `current_stage` (app logic · based on practice quality, not quantity)
- Fire on `completed = false → true → false` reversal (edge condition guards)
- Decrement on soft delete

### Deferred item · V3 work (flag for context)

When V3 creates `teaching_units` table, it must include:

```sql
alter table public.teaching_progress
  add constraint fk_teaching_progress_unit
  foreign key (teaching_unit_id)
  references public.teaching_units(id)
  on delete cascade;
```

Android shouldn't implement this in V2 · V3 responsibility.

### Android next task (when ready)

**Option 1 · Review + apply V2 to Supabase staging**
- Pull migration file
- Run `supabase db push` (or paste in SQL editor)
- Test: insert sessions → verify RLS · update completed=true → verify journey_progress row auto-created
- Reply: OK or found issues

**Option 2 · Draft Kotlin entities**
- `SessionEntity.kt` · offline-first · client-gen UUID · matches 16 columns
- `ReflectionEntity.kt` · 1:1 with session
- `JourneyProgressEntity.kt` · PK = user_id · stages_entered_at as `Map<String, Instant>` · TypeConverter for jsonb
- `TeachingProgressEntity.kt` · composite PK · `@Entity(primaryKeys = ["userId", "teachingUnitId"])`
- Do NOT wire Room yet · Hilt decision pending

### Questions back to iOS side (non-blocking)

1. **`stage_index_at_time` naming** · Android original V2 draft named it `stage_id_at_time` · iOS uses `stage_index_at_time` · OK to adopt index (more explicit)?
2. **`prefs_snapshot` jsonb shape** · Android agree with keys: `place · pace · duration_target · ground · environment · guidance`? Android `practice_window` table has more fields · should snapshot include all?
3. **`sync_journey_progress` current_stage initialization** · When first session completes with `stage_index_at_time = 3`, we set `current_stage = 3` (COALESCE to 1 if null). If user had manual progress elsewhere, this could overwrite lower stage. Is that OK?
4. **Audio playback progress** · `teaching_progress.last_position_sec` resumes audio · but sessions are different (not teaching units). Is there a separate mechanism for session playback resume, or is session always listened start-to-end?

### Tone rule

> *"The path is not elsewhere."*

SQL comments follow tone · informative · reference sync protocol rounds for future contributors.

### Acknowledge format

Reply กลับมา:
- ✓ Read V2 migration · 298 lines · 39 DDL
- Reviewed: OK / issues found · list
- Next Android task: (Option 1 apply staging, Option 2 entities, both, or something else)
- Answers Q1–Q4 above

---

## End of brief
