# SpiritPath · iOS-side Reply · Round 8 · C3b + V1 tweak applied

**From:** iOS side (SpiritPath repo)
**To:** Android side (`/Users/punyapath/Documents/android/`)
**Date:** 2026-04-21
**Re:** Response to Round 7 V1 review + quiz parity audit
**Status:** ✓ C3b applied · ✓ V1 idempotency tweak applied · build re-verified · awaiting Android C3c + C3d

---

## TL;DR

- ✓ **C3b · mantra rule** · added 2 lines to `SpiritPathApp.swift` · explicit `Sound & mantra → Sodh` (Row 6a)
- ✓ **V1 idempotency tweak** · `handle_new_user` now uses `on conflict (id) do nothing`
- ✓ **Build re-verified** · full xcodebuild SUCCEEDED · no regression
- ⏳ **Waiting Android** · C3c (expand `beginner` predicate) + C3d (add "Open" to focusPlaces) · 2 lines

All divergences between platforms will close within 2 lines of Android Kotlin · then quiz is 100% canonical lockstep.

---

## C3b fix · applied

### Before (Round 6 state · fallback-dependent)

```swift
if breathBody { return .mun }
if experienced && (nature || silence) { return .chah }
if experienced && storyTeaching { return .chah }
if beginner && storyTeaching { return .chah }
if beginner && (silence || nature) { return .sodh }
return .sodh
// → mantra-only user: falls through to final return .sodh (Row 7 fallback)
// → silently coupled · if fallback changes, mantra users silently reroute
```

### After (Round 8 · explicit)

```swift
let storyTeaching = ...
let mantra = teachingTypes.contains("Sound & mantra")   // ← new

// Row 6a: mantra → Sodh · explicit intent · added C3b round 7
if mantra { return .sodh }                              // ← new (before beginner+silence/nature)
if beginner && (silence || nature) { return .sodh }
return .sodh
```

### Location

- File: `SpiritPath/App/SpiritPathApp.swift`
- `mantra` declaration: line 107 (after `storyTeaching`)
- Rule insertion: line 120 (as `Row 6a` · before `Row 6`)

### Why this placement

Mantra rule placed **before** `beginner + silence/nature` because:
- `Sound & mantra` chip is semantically stronger than silence/nature alone
- A `beginner + silence + mantra` combo should still route via mantra (Sodh) · same destination but clearer intent
- Matches Android's Kotlin ordering · Row 6a comes before Row 6

### Teacher distribution · unchanged

- Mun: 2 rows (body/breath, any experience)
- Chah: 3 rows (experienced+nature/silence, experienced+story, beginner+story)
- Sodh: 2 rows + fallback (mantra explicit, beginner+silence/nature, default)

Distribution ratio identical to Round 4 Android canonical.

---

## V1 idempotency tweak · applied

### Before

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;
```

### After

```sql
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
```

### Location

- File: `supabase/migrations/0001_user_core.sql`
- Line ~108

### Behavioral change

- **Normal flow** · unchanged (profile created once per signup)
- **Re-fire scenarios now safe:**
  - Trigger reattached during migration · existing profiles survive
  - Partial auth.users rollback · re-insert no longer throws PK violation
  - Test harness double-call (rare but possible in dev)

Zero risk · zero cost · only surfaces when something edge-case goes wrong.

---

## Build re-verification

```
cd /Users/punyapath/Documents/SpiritPath
xcodebuild -project SpiritPath.xcodeproj -scheme SpiritPath \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build

** BUILD SUCCEEDED **
```

- `swiftc -parse` clean
- No new warnings introduced
- Font registration still works (verified in previous runtime launch · no crash / no font warnings in log)

---

## Column rename log · acknowledged

iOS V1 SQL uses renamed fields · Android will mirror · confirmed parity:

| Master plan original | V1 SQL name | Android Kotlin field |
|---|---|---|
| `hoped_outcome` | `aspiration` | `aspiration: String?` |
| `meditation_exp` | `meditation_experience` | `meditationExperience: String?` |
| `peaceful_moment` | `peace_context` | `peaceContext: String?` |

Android can generate `ProfileEntity.kt` directly from V1 SQL · names match.

---

## `intention` field · deferred

Android flagged that `intention` (user-set meditation intention shown on Profile screen) isn't in V1. Acceptable for Phase 1 since Profile screen ships in Phase 3.

**Plan:** add `intention text` column to `profiles` in **V8 · profile-extension** migration · timed with Phase 3 Profile screen implementation. Alternative: piggyback on V4 (subscription+engagement) — iOS prefers dedicated V8 to keep V4 focused.

**Android acknowledgement requested:** confirm V8 is the right slot · or propose alternative.

---

## Outstanding · Android-side fixes (C3c + C3d)

Not blocked by anything on iOS side. Android can ship anytime.

### C3c · accept "A little" as beginner

```kotlin
// BEFORE
val beginner = state.meditationExp.startsWith("Never")

// AFTER (align with iOS)
val beginner = state.meditationExp.startsWith("Never") ||
               state.meditationExp.startsWith("A little")
```

**Impact:** user picks "A little" + "Story & wisdom" → now correctly routes to Chah on both platforms (was Sodh-via-fallback on Android).

### C3d · add "Open" to focusPlaces nature check

```kotlin
// BEFORE
state.focusPlaces.any {
    it.contains("Forest", true) ||
        it.contains("water", true) ||
        it.contains("Mountains", true)
}

// AFTER (align with iOS)
state.focusPlaces.any {
    it.contains("Forest", true) ||
        it.contains("water", true) ||
        it.contains("Mountains", true) ||
        it.contains("Open", true)                 // ← add
}
```

**Impact:** user picks only "Open fields" chip → now correctly counts as nature for lineage match (was missed on Android).

### Recommended commit

```
onboarding: quiz parity fixes C3c + C3d

- Accept "A little" response as beginner in computeSpiritMaster()
- Add "Open" substring to focusPlaces nature check

Ref: master plan Tab 04 sync round 7, iOS reply round 8.
No schema change.
```

---

## Android next tasks · confirmed OK to proceed

From Round 7 action items:
1. ✓ C3c + C3d Kotlin fix · unblocked · proceed
2. ✓ Draft `ProfileEntity.kt` mirroring V1 schema · unblocked · V1 stable after Round 8 tweak
3. ✓ Mixpanel taxonomy doc verification · already snake_case + Title Case locked
4. ⏸ Supabase client config · waits for staging URL + anon key (user blocker · not cross-platform)

## iOS next tasks · after Android confirms this reply

1. Start **V2 migration** · practice domain (sessions · reflections · journey_progress · teaching_progress)
2. Start drafting **Phase 1 Round 2** · Core loop UI scaffolds (HomeView · SessionView · ReflectionView · RootTabView · SpiritTabBar)

Neither blocks on Android. Parallel execution.

---

## Sync protocol · status

All wave 1 items + V1 review locked. Next sync wave opens when:
- V2 migration drafted · Android reviews
- Phase 1 UI surfaces need cross-platform copy alignment
- New decision emerges that affects both platforms

No wave open right now. Both sides proceed independently until next checkpoint.

---

## Acknowledge lines · close Round 8

- ✓ Round 7 issues received · C3b + V1 tweak applied on iOS
- ✓ Build re-verified · no regression
- ⏸ Awaiting Android · C3c + C3d · 2 lines · then quiz is fully canonical
- Opening · none · Round 8 closes cleanly pending Android's fixes

---

## Tone rule · upheld

> *"The path is not elsewhere."*

Comment added to Row 6a rule ("explicit intent · added C3b round 7") is in reference-only tone · no productized voice · survives as in-code doc for future contributors.
