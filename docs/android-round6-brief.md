# SpiritPath · Round 6 Update · paste-ready

**Paste section "## Brief for Android Claude" ให้ Android session**

---

## Brief for Android Claude

### TL;DR · iOS Round 6 done

iOS side ปิด **Phase 1 · Round 1** เรียบร้อย · V1 migration พร้อมให้ review · เชิญคุณดู 3 ไฟล์:

- `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0001_user_core.sql` ← ตัวใหม่ · ให้ review
- `/Users/punyapath/Documents/codereview/plan.html#sync` · Round 6 entry (Tab 04 · Sync protocol)
- `/Users/punyapath/Documents/SpiritPath/SpiritPath/App/SpiritPathApp.swift` · quiz matrix เปลี่ยนเป็น 7-row canonical

### What's in V1 migration

File: `supabase/migrations/0001_user_core.sql` (~150 lines)

Contains:
- **8 enums:** `lineage_id · stage_key · path_id · session_type · teaching_mode · subscription_status · subscription_provider · compliance_request_status`
- **profiles table:** 18 columns · FK cascade to `auth.users` · soft delete (`deleted_at`) · timezone default `'America/New_York'` · locale `'en'` · `tracking_opt_out` default false · `quiz_raw jsonb` for re-analysis
- **Triggers:**
  - `handle_new_user()` · security definer · auto-creates profiles row on auth signup
  - `set_updated_at()` · generic · attached to profiles table via `tr_profiles_updated`
- **RLS · Pattern A (self-only):**
  - `profiles_select_own` · filters out soft-deleted rows
  - `profiles_insert_own` · safety net (trigger handles it)
  - `profiles_update_own` · immutable id
  - No DELETE policy · soft delete only · hard delete via edge function

### What Android can do next

**Option 1 · Review + apply V1 to Supabase staging**
- Pull migration file (via iOS repo path or ask user for copy)
- Run `supabase db push` (or paste into staging SQL editor)
- Test auth signup → verify profiles row auto-creates
- Reply back to iOS side: migration passes / found issue

**Option 2 · Start Kotlin Room entities mirroring the schema**
- `profiles` table → `ProfileEntity.kt` with same columns
- Enum values identical in Kotlin + Postgres (`lineage_id = "mun" | "sodh" | "chah"`)
- Use `@TypeConverters` for enums
- Android can proceed independently · no iOS blocker

### Changes on iOS side (for your awareness)

1. **Quiz matcher rewritten** · `SpiritPathApp.swift` line 58–79 now matches 7-row canonical 1:1 · comment block flags "do not diverge without cross-platform sync"
2. **Explanation per-teacher** · `SpiritMatchScreen` no longer hardcodes Sodh-specific copy · reads from `match.explanation`
3. **Fonts downloaded** · `Resources/Fonts/` now has `DMSerifDisplay-Regular.ttf`, `DMSerifDisplay-Italic.ttf`, `Manrope-VariableFont_wght.ttf`, `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf` (all OFL license)
4. **Runtime font registration** · `SpiritFonts.registerAll()` called from `SpiritPathApp.init()` · no Info.plist UIAppFonts needed
5. **Forward-looking tokens added** · `Color+App.swift` · `Typography.swift` · `AppTheme.swift` · palette + type scale ready for Phase 1+ post-onboarding screens

### What iOS did NOT do in Round 1 (deferred · awaits user direction)

- Full onboarding reskin (white bg → navy · 21 screens) · requires visual preview pass · separate round
- V2 migration (practice domain: sessions · reflections · journey_progress · teaching_progress) · waits for V1 review pass
- App feature code · HomeView · SessionView etc.

### Android parallel tasks (no iOS blocker)

From master plan Tab 02 · Android-owned:
- Quiz collapse `computeSpiritMaster()` → 3 teachers using 7-row canonical (Android confirmed in Round 4)
- Mixpanel taxonomy update · Title Case events + snake_case properties
- Phase 1 skeletons: Home / Session / Reflection Compose scaffolds
- Room entities for schema tables as they're migrated

### Sync protocol check

ถ้ามีประเด็นใน V1 migration · open sync round 7 ที่:
`/Users/punyapath/Documents/android/docs/android-sync-v1-review.md`

ใช้ template ใน master plan Tab 04 · "Template · เปิด sync round ใหม่"

### Acknowledge format

Reply กลับมา:
- ✓ Read V1 migration
- Reviewed: (OK / issues found: list)
- Next Android task: (what you'll do while iOS proceeds with V2)

### Tone rule

> *"The path is not elsewhere."*

V1 migration was written assuming this tone · comments explain context · no gamification language.

---

## End of brief
