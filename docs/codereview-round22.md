# SpiritPath · CodeReview-side brief · Round 22 · C4 revision + Mixpanel taxonomy lock · Phase 1.5

**From:** CodeReview
**To:** iOS + Android sessions (both must sign)
**Date:** 2026-04-22
**Re:** (a) revise C4 event-naming from `"Title Case with Spaces"` → `snake_case` · (b) lock Mixpanel taxonomy for Phase 1.5 · 5 events · before any SDK wiring
**Status:** ⏳ open · awaiting iOS + Android acknowledge · **no code lands on either platform until both sign**
**Project token:** `373e5c078bbe0d04b8be993cfb818df5`

---

## TL;DR

- **C4 revised:** event names flip from `"Session Started"` → `session_started` · property keys stay `snake_case` · enum values stay `lowercase_snake` · other conventions unchanged
- **Value Moment:** `session_ended` with `completed=true` · primary KPI event for SpiritPath
- **5 events locked** for Phase 1.5 · no runtime-constructed names · no dynamic event names
- **Identity:** Supabase `auth.user.id` (UUID) = Mixpanel distinct_id · never email · `reset()` on logout · `identify()` on every app re-open (not only first-time)
- **Consent gate:** respect `profiles.tracking_opt_out` column · `opt_out_tracking()` before any event fires
- **User-owned dashboard tasks:** verify **timezone** (set once · immutable) + **Simplified ID Merge = enabled** BEFORE any events ship · enable Data Standards with snake_case enforcement
- **Deferred to Phase 2+ rounds:** `stage_opened` · `lineage_changed` · `stillness_opened` · `feature_flag_evaluated` (Phase 2) · `notification_opened` · `paywall_purchased` · `paywall_dismissed` (Phase 3)

---

## Part 1 · C4 revision · new event-naming convention

**Why flip now:**
- Mixpanel skill's Data Standards module enforces snake_case default · fighting the default adds governance friction for no gain
- `object_verb` pattern (`session_started` · `reflection_submitted`) matches event taxonomy best practices across industry · Lexicon / Funnels / Cohorts read cleanly
- SpiritPath's product tone rule applies to user-visible strings · internal telemetry names are developer-facing · they can be terse and snake_case without breaking the tone lock
- Title Case was locked in Round 3-5 (C4) before any Mixpanel integration existed · now that wiring begins, re-lock to what the tool wants

**Revised C4 table · locked this round:**

| Dimension | Old (C4 · Round 3-5) | New (C4 · Round 22) | Effect |
|---|---|---|---|
| Event names | `"Title Case with Spaces"` | `snake_case object_verb` | flip |
| Property keys | `snake_case` | `snake_case` | unchanged |
| User property keys | `snake_case` | `snake_case` | unchanged |
| Property values (enums) | `lowercase_snake` | `lowercase_snake` | unchanged |
| Feature flag keys | `snake_case flat` | `snake_case flat` | unchanged |

**Scope of flip:** ONLY Mixpanel event names. All other naming conventions stand. No Postgres / SwiftUI / Kotlin refactor needed · zero existing events to migrate (0 instrumented).

**Paper trail update:** after R22 locks, `codereview/plan.html` Tab 04 locked items table C4 row updates to new value · `codereview/prompt.md` bootstrap Naming section updates · both done in same commit as R22 card.

---

## Part 2 · 5 events · Phase 1.5 taxonomy

All 5 events fire on BOTH iOS and Android. Parity is mandatory. Dashboards blocked until both sides emit identical event + properties.

### Event 1 · `onboarding_completed`

**When:** user finishes final onboarding screen (after `SpiritMatchScreen` → path + auth completion) · fires exactly once per user lifetime
**Fires from:** iOS `SpiritPathApp.swift` in the handler that persists `onboardingCompletedAt` · Android equivalent in onboarding flow exit handler

**Properties:**
| Key | Type | Value | Notes |
|---|---|---|---|
| `selected_lineage_id` | string (enum) | `mun` · `sodh` · `chah` | from Spirit Match result |
| `chosen_path_id` | string (enum) | `mindful_walking` · `everyday` · `body` · `retreat` | from path selection |
| `meditation_experience` | string | raw answer text · e.g. `"Yes, for a while"` | Q1 answer · not the beginner/experienced classification |
| `peace_context` | string | raw answer text | Q2 answer |
| `environment_tags_count` | number | count of focus-places selected | cardinality only · not the raw array |
| `guidance_tags_count` | number | count of teaching-types selected | cardinality only |
| `notifications_granted` | boolean | true/false | from permission prompt outcome |
| `location_granted` | boolean | true/false | from permission prompt outcome |

### Event 2 · `session_started`

**When:** user taps "Begin" on Practice/Session setup · timer starts
**Fires from:** iOS `SessionView` on start · Android equivalent

**Properties:**
| Key | Type | Value | Notes |
|---|---|---|---|
| `session_uuid` | string (UUID) | client-generated UUID | same ID used for `sessions.id` in Postgres · allows cross-join |
| `session_type` | string (enum) | `walking` · `quiet` · `breath` · `sound_bath` | matches `session_type` Postgres enum |
| `lineage_id` | string (enum) | `mun` · `sodh` · `chah` | snapshot from `profiles.selected_lineage_id` at session time |
| `stage_index_at_time` | number | 1-5 | snapshot from `journey_progress.current_stage` |
| `duration_target_sec` | number | e.g. 300 · 600 · 1800 | user pick before start |
| `place` | string | `temple` · `forest` · `water` · etc. | practice_window default or override |
| `ground` | string | `grass` · `stone` · etc. | practice_window default or override |
| `pace_mode` | string | `forest` · `temple` · etc. | practice_window snapshot |

### Event 3 · `session_ended` · **Value Moment**

**When:** session ends · either user completes it (`completed=true`) or abandons it (`completed=false`)
**Fires from:** iOS `SessionView` on completion/dismiss · Android equivalent

**Properties:**
| Key | Type | Value | Notes |
|---|---|---|---|
| `session_uuid` | string (UUID) | same as `session_started` | enables funnel matching |
| `session_type` | string (enum) | matches `session_started` | redundant but needed for event-level cohorts |
| `lineage_id` | string (enum) | matches `session_started` | redundant |
| `stage_index_at_time` | number | matches `session_started` | redundant |
| `duration_target_sec` | number | from start | |
| `duration_actual_sec` | number | measured | Value Moment predicate: ≥ target × 0.8 for "meaningful completion" · flag in Lexicon |
| `mindful_steps` | number | from CoreMotion/Health Connect during session | 0 if permission denied |
| `total_steps` | number | raw pedometer count | 0 if permission denied |
| `moments_of_return` | number | count of "bring back to breath" events during session | 0 if not tracked yet |
| `completed` | boolean | true = session finished naturally · false = user bailed | **KPI flag** |
| `ended_reason` | string | `natural` · `user_abort` · `background_timeout` · `phone_call` | optional · null if not categorized |

### Event 4 · `reflection_submitted`

**When:** user taps Save on Reflection screen after a session
**Fires from:** iOS `ReflectionView` on save · Android equivalent

**Properties:**
| Key | Type | Value | Notes |
|---|---|---|---|
| `session_uuid` | string (UUID) | links to session | |
| `note_length_chars` | number | length of text | **do NOT send note text itself** · privacy |
| `anchor_phrase_set` | boolean | true if user chose an anchor phrase · false if skipped | |
| `time_since_session_end_sec` | number | gap between session_ended and reflection_submitted | |

### Event 5 · `paywall_viewed`

**When:** paywall screen renders (not on app first boot if already subscribed)
**Fires from:** iOS `PaywallScreen` on appear · Android equivalent

**Properties:**
| Key | Type | Value | Notes |
|---|---|---|---|
| `paywall_variant` | string | from `feature_flags.paywall_variant` · default `"default"` | |
| `trigger_source` | string | `onboarding` · `paywall_gate` · `settings_upgrade` · `feature_locked` | where the user was before reaching paywall |
| `has_previous_trial` | boolean | whether user has a historical `user_subscriptions` row with `trial` status | |

---

## Part 3 · Super properties · fire on every event

Set once after app launch · auto-attached to all subsequent events. Set + re-set on every app foreground.

| Key | Type | Source | Notes |
|---|---|---|---|
| `app_version` | string | e.g. `1.0.0` | from Bundle / BuildConfig |
| `build_number` | number | e.g. 42 | CFBundleVersion / versionCode |
| `platform` | string | `ios` · `android` | hardcoded per platform |
| `device_model` | string | e.g. `iPhone16,2` · `Pixel 8 Pro` | auto-collected by SDK by default · keep |
| `os_version` | string | e.g. `17.4` · `14` | auto-collected |
| `locale` | string | e.g. `en-US` | from profiles.locale or device |
| `selected_lineage_id` | string (enum) | from `profiles.selected_lineage_id` after onboarding | null before onboarding |
| `current_stage` | number | from `journey_progress.current_stage` | 1-5 · null before first session |
| `has_active_subscription` | boolean | computed from user_subscriptions query | refreshed on foreground |

---

## Part 4 · User properties · set on identify

Run after Supabase auth succeeds. Call `Mixpanel.people.set([...])` or equivalent.

| Key | Type | Source | Notes |
|---|---|---|---|
| `$email` | string | from Supabase auth (if email available) | `$email` is Mixpanel reserved profile field · OK to set · do not use as distinct_id |
| `$first_seen_at` | date | from `profiles.created_at` | alias for `createdAt` · let Mixpanel handle if auto-set |
| `onboarding_completed_at` | date | from `profiles.onboarding_completed_at` | null before onboarding |
| `selected_lineage_id` | string (enum) | from `profiles.selected_lineage_id` | |
| `chosen_path_id` | string (enum) | from `profiles.chosen_path_id` | |
| `timezone` | string | e.g. `America/New_York` | from `profiles.timezone` |
| `tracking_opt_out` | boolean | from `profiles.tracking_opt_out` | profile-level for audit |

---

## Part 5 · Identity flow · critical rules

**Distinct ID = Supabase auth user UUID.** Never email. Never device ID for authenticated users.

```
App launch
  → Mixpanel init (with opt-out check)
  → has cached Supabase session?
    → yes · call Mixpanel.identify(session.user.id) immediately
           · call Mixpanel.people.set(user_props from profiles)
    → no · anonymous distinct_id until auth

User signs in
  → Supabase auth success
  → Mixpanel.identify(user.id)     · links pre-auth events to this user via alias
  → Mixpanel.people.set(user_props from profiles query)

User signs out
  → Mixpanel.reset()               · clears distinct_id and device-bound cache
  → opt_out_tracking stays consistent with user preference

Every app re-open (even when already logged in)
  → Mixpanel.identify(user.id) again    · skill rule · prevents session merge bugs
```

**Never:**
- Use email as distinct_id (GDPR · CCPA · changes of email break identity)
- Omit `reset()` on logout (next user's events merge into previous session)
- Construct event names at runtime (creates thousands of unique names)

---

## Part 6 · Consent gate · CCPA compliance

`profiles.tracking_opt_out` (boolean · default false · nullable) is the authoritative flag. Wire:

```
App launch
  → read tracking_opt_out from profiles
    · if offline · read cached value from UserDefaults (iOS) / DataStore (Android)
    · if no cached value · default to false (opt-in by default for analytics · lawful under CCPA notice model · App Privacy manifest declares analytics)
  → if opt_out_tracking == true:
    · Mixpanel.opt_out_tracking()
    · do NOT flush buffered events · let SDK drop them
  → else:
    · Mixpanel.opt_in_tracking()  (or omit · default is opt-in)

User flips opt-out in Settings (Phase 3 UI · stubbed now)
  → UPDATE profiles.tracking_opt_out
  → refresh Mixpanel state to match
  → if flipped to true · call opt_out_tracking()
  → if flipped to false · call opt_in_tracking()

Cross-device sync
  → tracking_opt_out is stored on profiles · RLS Pattern A · self-only
  → on new device login · read profiles.tracking_opt_out first · then identify + opt state
```

**App Privacy manifest (iOS) must declare:** `NSPrivacyTracking = false` (Mixpanel is first-party analytics · not third-party tracking per Apple definition) · `NSPrivacyCollectedDataTypes` includes crash data + product interaction.

**Google Play Data Safety form (Android)** declares equivalent: analytics collection · no third-party sharing (Mixpanel is self-hosted analytics from user's POV).

---

## Part 7 · User-owned dashboard tasks (BEFORE any events ship)

These are irreversible or critical setup. Do in this order:

1. **Timezone** · Dashboard → Project Settings → Timezone → set to the reporting timezone (likely `America/New_York` per brief · or `America/Los_Angeles` if US West bias) · **one-time · cannot change retroactively · events already ingested will stay in the set timezone**
2. **Simplified ID Merge** · Dashboard → Project Settings → Identity → verify Simplified ID Merge is ENABLED · if not · enable it before any event lands · **critical · data corruption risk if events ship before this flag is on**
3. **Data Standards** · Dashboard → Lexicon → Data Standards → enable · events enforce `snake_case` · properties enforce `snake_case` · this catches typo drift automatically
4. **Create dev + prod project split** (recommended · not required Phase 1.5) · dev project for testing · prod for live · can defer to Phase 3 if staging is the only environment for now

**Token currently in plan:** `373e5c078bbe0d04b8be993cfb818df5` · unknown yet whether this is dev or prod · user to confirm · if prod · create a dev token before wiring and use dev token for Phase 1.5 dev cycle.

---

## Part 8 · Governance · enabled after events start flowing

After first events land (expected within 1 week of platform wiring):

- **Lexicon:** add description + tags + example values for each of the 5 events (CodeReview can draft descriptions post-R22)
- **Event Approval:** require review before new events appear in Lexicon (prevents ad-hoc event creation by future contributors)
- **Roles:** user = Data Owner + Analyst · engineers per platform = Engineer role · CodeReview = Data Governor
- **Deprecation rule:** if an event needs to be removed later · HIDE (not drop) for one quarter before removal

---

## Part 9 · SDK wiring · minimal references (details in platform prompts)

### iOS (Swift · SPM)

```swift
// Package.swift or SPM UI: add mixpanel-swift pinned to major version
// https://github.com/mixpanel/mixpanel-swift

import Mixpanel

// In SpiritPathApp.init or AppDelegate
Mixpanel.initialize(
    token: "373e5c078bbe0d04b8be993cfb818df5",
    trackAutomaticEvents: false   // disable auto session events · we control everything
)

// Consent gate
if profile.trackingOptOut {
    Mixpanel.mainInstance().optOutTracking()
}

// Super properties
Mixpanel.mainInstance().registerSuperProperties([
    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown",
    "platform": "ios",
    // ...
])

// Track an event
Mixpanel.mainInstance().track(event: "session_ended", properties: [
    "session_uuid": session.id.uuidString,
    "completed": true,
    // ...
])
```

### Android (Kotlin · Gradle)

```kotlin
// app/build.gradle.kts
// implementation("com.mixpanel.android:mixpanel-android:7.+")

import com.mixpanel.android.mpmetrics.MixpanelAPI

// In Application onCreate
val mixpanel = MixpanelAPI.getInstance(
    applicationContext,
    "373e5c078bbe0d04b8be993cfb818df5",
    false  // trackAutomaticEvents = false
)

// Consent gate
if (profile.trackingOptOut) {
    mixpanel.optOutTracking()
}

// Super properties
mixpanel.registerSuperProperties(JSONObject().apply {
    put("app_version", BuildConfig.VERSION_NAME)
    put("platform", "android")
    // ...
})

// Track
mixpanel.track("session_ended", JSONObject().apply {
    put("session_uuid", session.id)
    put("completed", true)
})
```

---

## Part 10 · Action items · both platforms

### iOS session (after R22 signs)
- Add `mixpanel-swift` SPM dependency
- Create `Core/Services/Analytics.swift` wrapper (thin) · centralize event names as typed enum `AnalyticsEvent` · prevents string drift
- Init + super properties + consent gate in app startup
- Identity wiring in auth flow (sign-in success + sign-out)
- Wire the 5 events at their call sites (call sites don't exist yet for `session_started` / `session_ended` / `reflection_submitted` / `paywall_viewed` · stub the wrapper now · actual call sites land with Phase 1.2 / 1.3)
- `onboarding_completed` can fire today (onboarding ships)
- Add `NSPrivacyTracking = false` to app privacy manifest

### Android session (after R22 signs)
- Add `com.mixpanel.android:mixpanel-android` Gradle dependency
- Create `core/analytics/AnalyticsClient.kt` wrapper · typed event sealed class · mirror iOS
- Init + super properties + consent gate in `SpiritPathApplication.onCreate()` (create if not exist)
- Identity wiring in auth flow
- Wire events at call sites (most don't exist yet · stub now · land with Phase 1.2/1.3 Compose screens)
- `onboarding_completed` can fire today
- Update Play Data Safety form after first event lands

### User-owned
- Dashboard tasks Part 7 (1-4)
- Decide: is `373e5c078bbe0d04b8be993cfb818df5` dev or prod token? · create the other if needed
- Sign off R22 before platform sessions proceed

### CodeReview · post-sign
- Update `codereview/plan.html` Tab 04 locked items · C4 row flipped · add R22 card
- Update `codereview/prompt.md` bootstrap Naming section · reflect snake_case events
- Draft Lexicon descriptions for the 5 events
- Produce paste-ready iOS + Android prompts

---

## Questions back to platform sessions

1. **iOS:** confirm Mixpanel-swift SPM install procedure + version pin strategy (pin to `4.+` or specific minor?)
2. **iOS:** `NSPrivacyTracking = false` manifest update · confirm App Privacy report shape matches (no third-party SDKs declared)
3. **Android:** confirm Gradle resolution for `mixpanel-android:7.+` · is there a pinned version preferred per existing SDK set?
4. **Android:** `SpiritPathApplication` class exists in the project? If not · create it now (needed for init hook) · update manifest `android:name`
5. **Both:** confirm you have the Supabase auth pattern available to call `Mixpanel.identify(user.id)` from (session observer hook · callback · etc.)

---

## Acknowledge format

Reply (each platform separately):

```
✓ Read R22 · C4 revision + Mixpanel taxonomy accepted
SDK install plan: <brief · version pin>
Event wrapper location: <path to Analytics.swift / AnalyticsClient.kt>
Consent gate wiring: <where · in which class>
Identity wiring: <where · in which auth callback>
Stubbed events (awaiting Phase 1.2/1.3): <list>
Live events (shippable today): onboarding_completed
Answers Q1-Q5: <inline>
Next: awaiting CodeReview post-sign update to plan Tab 04 + prompt.md + platform prompts
```

Both platforms must sign before any SDK install commit lands.

---

## Locked items · new for wave 7

| ID | Topic | Locked value |
|---|---|---|
| C4-r2 | Event naming convention | `snake_case object_verb` (was Title Case Spaces · flipped R22) · properties stay snake_case · enum values stay lowercase_snake |
| M3 | Mixpanel distinct_id | Supabase auth.user.id (UUID) · never email |
| M4 | Mixpanel re-identify | Every app foreground · not only first-time · prevents session merge bugs |
| M5 | Mixpanel opt-out source of truth | `profiles.tracking_opt_out` column · Pattern A RLS · cross-device consistent |
| M6 | Mixpanel taxonomy Phase 1.5 | 5 events locked: `onboarding_completed` · `session_started` · `session_ended` · `reflection_submitted` · `paywall_viewed` |
| M7 | Mixpanel Value Moment | `session_ended` with `completed=true` AND `duration_actual_sec ≥ duration_target_sec × 0.8` |

---

## Tone rule

> *"The path is not elsewhere."*

Applies to user-visible copy · not to internal event names. R22 clarifies this scope.

---

**Round 22 open · awaiting iOS + Android sign.**
