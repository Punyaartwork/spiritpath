# SpiritPath · CodeReview-side brief · Round 28 · Phase 2 Mixpanel events lock · 4 events

**From:** CodeReview
**To:** Android session (Path B canonical) · iOS catch-up post Apple Developer
**Date:** 2026-05-01
**Re:** Lock 4 deferred R22 events for Phase 2 wiring · stage_opened · lineage_changed · stillness_opened · feature_flag_evaluated · Path B Android-only signs · iOS adopts when re-engaged
**Status:** ⏳ open · awaiting Android sign · iOS sign batched with Apple Developer catch-up

---

## TL;DR

- 4 events deferred per R22 ("Deferred to Phase 2+") now locked ahead of Phase 2.1 wiring
- Phase 2.1 fires 2 (stage_opened · lineage_changed) · Phase 2.3 fires stillness_opened · Phase 2.x opportunistic fires feature_flag_evaluated (throttled)
- Naming convention C4-r2 (snake_case object_verb · R22 lock) applies
- Property keys snake_case · enum values lowercase_snake (existing rules)
- Android signs solo Path B · iOS adopts contracts during catch-up · single source-of-truth for both platforms

---

## Event 1 · `stage_opened`

**When:** User taps a stage card in JourneyView · OR enters TeachingView for a specific stage·mode (Phase 2.2)

**Phase 2.1 firing:** Tap on stage card in JourneyScreen → fires with `mode_first_opened = "browse"` (no mode entered yet · Phase 2.1 doesn't ship TeachingView)

**Phase 2.2 firing:** TeachingView entry per stage·mode → updates `mode_first_opened` to `"listen"` / `"understand"` / `"reflect"` based on first tab opened (preserve cohort attribution)

**Properties:**

| Key | Type | Value |
|---|---|---|
| `lineage_id` | string (enum) | `mun` · `sodh` · `chah` · current selected lineage |
| `stage_index` | number | 1-5 · stage user opened |
| `mode_first_opened` | string (enum) | `browse` (Phase 2.1 default) · `listen` · `understand` · `reflect` (Phase 2.2+) |
| `is_current_stage` | boolean | true if stage_index == `journey_progress.current_stage` · false otherwise |

**Throttling:** None at SDK · natural per-tap · user can re-tap stage repeatedly · multiple events expected (cohort = "first time on stage" derivable via Mixpanel funnel · don't deduplicate at fire-site)

---

## Event 2 · `lineage_changed`

**When:** User selects a different lineage in LineagePicker bottom sheet (JourneyView header card tap → bottom sheet · select different option)

**Phase 2.1 firing:** LineagePicker selection callback fires AFTER `profile.selected_lineage_id` UPDATE succeeds · before bottom sheet dismiss

**Properties:**

| Key | Type | Value |
|---|---|---|
| `from_lineage_id` | string (enum) | previous `selected_lineage_id` value · `mun`/`sodh`/`chah` |
| `to_lineage_id` | string (enum) | new `selected_lineage_id` value · ≠ from_lineage_id |
| `current_stage` | number | snapshot of `journey_progress.current_stage` at time of switch · 1-5 |

**Throttling:** None · users may switch lineages multiple times to compare · all switches tracked

---

## Event 3 · `stillness_opened`

**When:** User navigates to the Stillness tab (Phase 2.3 ship)

**Phase 2.1:** NOT fired (Stillness tab placeholder per Phase 1.1)
**Phase 2.3:** Fires on first composition entry of StillnessScreen per app session (1 event per session even if user navigates away + back)

**Properties:**

| Key | Type | Value |
|---|---|---|
| `time_of_day_hour` | number | 0-23 · local device time hour at fire moment · cohort: morning/evening users |
| `had_session_today` | boolean | true if user completed a `session_ended` (any type) since local midnight · false otherwise |
| `entry_source` | string | `tab_bar` · `notification` · `home_card` · `deep_link` · how user arrived at Stillness |

**Throttling:** Once per app session (in-process) · session = launch-to-backgrounded · prevents flood when user oscillates between tabs

---

## Event 4 · `feature_flag_evaluated`

**When:** `FeatureFlagsRepository.getFlag(key)` is called and returns a value

**Phase 2.1:** NOT fired (no new flags consulted Phase 2.1 · 3 existing flags from Wave 5 not Phase-2.1 wired)
**Phase 2.x ship:** Fires opportunistically · whenever feature_flags read happens · throttled per (flag_key + session)

**Properties:**

| Key | Type | Value |
|---|---|---|
| `flag_key` | string | `audio_delivery` · `accent_mode` · `paywall_variant` · or future flags |
| `flag_value` | string | stringified value at evaluation time (e.g. `"bundle"` · `"warm"` · `"default"`) |
| `default_used` | boolean | true if hardcoded default returned (cache miss + server unreachable) · false if cache or server-fresh value used |
| `source` | string | `cache` · `server` · `default` · which layer answered |

**Throttling:** **Once per flag_key per app session** · if user evaluates `audio_delivery` 100 times in one app session, fires 1 event · in-memory Set<String> tracks fired keys until app process death

---

## Cross-platform parity rules

- All 4 events fire identically on iOS once Apple Developer unlocks (Path B period: Android = canonical)
- Property keys snake_case (per C4-r2)
- Enum values match Postgres wire form (`mun` not `Mun`)
- Mixpanel event names snake_case object_verb (per R22 C4-r2)

---

## Timing precision

- `stage_opened` · fired immediately on tap · before any navigation transition
- `lineage_changed` · fired AFTER profile UPDATE succeeds · before bottom sheet animation completes
- `stillness_opened` · fired on `LaunchedEffect(Unit)` at StillnessScreen composition · before first frame
- `feature_flag_evaluated` · fired on getFlag() return · after value resolution

---

## Privacy + data minimization

- No PII in any event
- `current_stage` numeric only
- `time_of_day_hour` is 0-23 only (local hour · NOT exact timestamp · cohort granularity)
- All super-properties (M3-M7 R22 locks) auto-attach as before

---

## Sub-actions for AnalyticsClient (Android · Phase 2.1 wiring)

Extend `AnalyticsEvent` sealed class with 4 new variants:

```kotlin
sealed class AnalyticsEvent {
    // Phase 1.5 · 5 events (existing)
    data class OnboardingCompleted(...)
    data class SessionStarted(...)
    data class SessionEnded(...)
    data class ReflectionSubmitted(...)
    data class PaywallViewed(...)

    // Phase 2 · 4 events (R28 new)
    data class StageOpened(
        val lineageId: String,
        val stageIndex: Int,
        val modeFirstOpened: String,  // "browse" / "listen" / "understand" / "reflect"
        val isCurrentStage: Boolean,
    ) : AnalyticsEvent() {
        override val name = "stage_opened"
        override fun toProps() = JSONObject().apply {
            put("lineage_id", lineageId)
            put("stage_index", stageIndex)
            put("mode_first_opened", modeFirstOpened)
            put("is_current_stage", isCurrentStage)
        }
    }

    data class LineageChanged(
        val fromLineageId: String,
        val toLineageId: String,
        val currentStage: Int,
    ) : AnalyticsEvent() {
        override val name = "lineage_changed"
        override fun toProps() = JSONObject().apply {
            put("from_lineage_id", fromLineageId)
            put("to_lineage_id", toLineageId)
            put("current_stage", currentStage)
        }
    }

    data class StillnessOpened(
        val timeOfDayHour: Int,
        val hadSessionToday: Boolean,
        val entrySource: String,
    ) : AnalyticsEvent() {
        override val name = "stillness_opened"
        override fun toProps() = JSONObject().apply {
            put("time_of_day_hour", timeOfDayHour)
            put("had_session_today", hadSessionToday)
            put("entry_source", entrySource)
        }
    }

    data class FeatureFlagEvaluated(
        val flagKey: String,
        val flagValue: String,
        val defaultUsed: Boolean,
        val source: String,
    ) : AnalyticsEvent() {
        override val name = "feature_flag_evaluated"
        override fun toProps() = JSONObject().apply {
            put("flag_key", flagKey)
            put("flag_value", flagValue)
            put("default_used", defaultUsed)
            put("source", source)
        }
    }
}
```

Phase 2.1 implementation lands `StageOpened` + `LineageChanged` · Phase 2.3 lands `StillnessOpened` · Phase 2.x retrofit lands `FeatureFlagEvaluated` in `FeatureFlagsRepository.getFlag()`.

iOS catch-up matches the same 4-case enum extension in `AnalyticsEvent.swift` (parked Path B).

---

## Locked items · new for wave 21 (R28 sign)

| ID | Topic | Lock |
|---|---|---|
| M14 | `stage_opened` event spec · 4 properties · fires on stage card tap + TeachingView entry | per Event 1 above |
| M15 | `lineage_changed` event spec · 3 properties · fires after profile UPDATE succeeds | per Event 2 above |
| M16 | `stillness_opened` event spec · 3 properties · once-per-session throttle | per Event 3 above |
| M17 | `feature_flag_evaluated` event spec · 4 properties · once-per-key-per-session throttle | per Event 4 above |
| M18 | Phase 2 event firing fan-out plan · M14/M15 in 2.1 · M16 in 2.3 · M17 opportunistic 2.x | sequential per phase |

---

## Acknowledge format · Android-side sign (Path B)

```
✓ Read R28 · 4 Mixpanel events accepted
  · stage_opened · 4 props
  · lineage_changed · 3 props
  · stillness_opened · 3 props (Phase 2.3)
  · feature_flag_evaluated · 4 props (Phase 2.x)
AnalyticsEvent sealed class extension plan: <inline · or defer to Phase 2.1 implementation>
Throttle implementation pattern: <in-memory Set per app session>
Sign: ✓
Next: Phase 2.1 wires M14 + M15 · Phase 2.3 wires M16 · Phase 2.x wires M17
iOS catch-up: matches 4 events in AnalyticsEvent.swift post Apple Developer
```

iOS sign batched with Apple Developer catch-up · CodeReview tracks contract for both platforms.

---

## Tone rule

> *"The path is not elsewhere."*
