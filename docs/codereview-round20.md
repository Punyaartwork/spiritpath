# SpiritPath · CodeReview-side brief · Round 20 · Quiz predicate canonical form

**From:** CodeReview
**To:** iOS + Android sessions (both must sign)
**Date:** 2026-04-22
**Re:** Lock predicate implementation for Spirit Match quiz matcher · iOS currently uses `String.contains` + `Array.contains` exact · Android uses `startsWith` + case-insensitive substring · matrix logic matches but predicate implementations have drifted
**Status:** ⏳ open · awaiting iOS + Android acknowledge · flagged since Sweep 01 (2026-04-22 · same day) · small latent drift
**Priority:** low · masked by current chip set · will surface on any chip-label copy edit

---

## TL;DR

- Quiz matcher's 7-row matrix + Row 6a mantra + Row 7 fallback = ✓ identical on both platforms
- Predicate IMPLEMENTATION diverged: iOS permissive-substring on experience + exact-array on chips · Android strict-prefix on experience + case-insensitive-substring on chips
- C3c (Round 7) locked `startsWith` for experience predicates · **Android matches · iOS violates**
- No chip-label predicate rule was ever explicitly locked · both platforms picked different strategies
- **R20 locks:** (a) `startsWith` for experience on both (iOS adopts) · (b) EXACT-EQUALS for chip labels on both (Android switches from substring) · (c) single chip-label source-of-truth
- Current behavior converges (no drift visible in production) · R20 prevents future silent divergence on any chip copy edit

---

## Evidence · current state

**iOS** ([SpiritPathApp.swift:101-127](SpiritPath/SpiritPath/App/SpiritPathApp.swift#L101)):
```swift
let beginner    = meditationExp.contains("Never") || meditationExp.contains("A little")
let experienced = meditationExp.contains("Yes")
let silence     = teachingTypes.contains("Silence-based")                                  // Array.contains exact
let nature      = teachingTypes.contains("Nature connection")
                  || focusPlaces.contains("Forest / Park")
                  || focusPlaces.contains("Near water")
                  || focusPlaces.contains("Open fields")
                  || focusPlaces.contains("Mountains")
let breathBody  = teachingTypes.contains("Breathwork") || teachingTypes.contains("Body awareness")
let storyTeach  = teachingTypes.contains("Story & wisdom")
                  || teachingTypes.contains("Buddhist teaching")
                  || teachingTypes.contains("Gentle guidance")
let mantra      = teachingTypes.contains("Sound & mantra")
```

**Android** ([SpiritPathOnboarding.kt:1271-1297](android/app/src/main/java/com/dekphut/spiritpath/feature/onboarding/presentation/SpiritPathOnboarding.kt#L1271)):
```kotlin
val beginner    = state.meditationExp.startsWith("Never") || state.meditationExp.startsWith("A little")
val experienced = state.meditationExp.startsWith("Yes")
val hasSilence  = state.teachingTypes.any { it.contains("Silence", ignoreCase = true) }     // substring
val hasNature   = state.teachingTypes.any { it.contains("Nature", ignoreCase = true) }
                  || state.focusPlaces.any { it.contains("Forest", true)
                                             || it.contains("water", true)
                                             || it.contains("Mountains", true)
                                             || it.contains("Open", true) }
val hasBody     = state.teachingTypes.any { it.contains("Body", true) }
val hasBreath   = state.teachingTypes.any { it.contains("Breath", true) }
val hasStory    = state.teachingTypes.any { it.contains("Story", true)
                                            || it.contains("Buddhist", true)
                                            || it.contains("Gentle", true) }
val hasMantra   = state.teachingTypes.any { it.contains("Sound", true) || it.contains("mantra", true) }
```

## 2 concrete drift risks today

1. **iOS violates C3c · `contains` instead of `startsWith`** · if future chip text contains "Never" anywhere (e.g. "I've not meditated much, never tried") iOS classifies as beginner · Android doesn't · divergent routing
2. **`mantra` predicate semantic gap** · iOS requires exact `"Sound & mantra"` chip · Android fires on any chip containing `"Sound"` OR `"mantra"`. A future "Sound bath" chip would route to Sodh on Android but not iOS.

Current chip labels (`"Sound & mantra"` · `"Silence-based"` · `"Forest / Park"` · etc.) mask both risks. Copy changes trigger.

---

## Canonical form · R20 locks

### C3e (new · extends C3c)

```
experience predicates:  String.startsWith      on both platforms
chip label predicates:  exact-equals match     on both platforms
chip label source:      single constants file referenced by both matchers
case sensitivity:       exact match is case-sensitive · chip labels are canonical
```

**Rationale · why exact-equals (not substring):**
- Predictable · no silent match on future chip additions
- Forces intentional chip vocabulary additions · every chip is declared
- Cleaner taxonomy when Mixpanel events include `peace_context` / `meditation_experience` raw strings (R22 locks these as event properties · they flow to dashboard · substring-matched chip strings would drift analytics too)
- No ignoreCase branching · reasoning-simple

**Rationale · startsWith for experience:**
- C3c locked · iOS just needs to flip
- Experience answers are single free-form strings with known prefixes (`"Never"` · `"A little"` · `"Yes, I've tried"`) · startsWith is the cleanest fit

### Chip label canonical vocabulary (do not change without sync round)

| Category | Values (exact strings) | Row predicate |
|---|---|---|
| `teachingTypes` | `"Silence-based"` · `"Nature connection"` · `"Breathwork"` · `"Body awareness"` · `"Story & wisdom"` · `"Buddhist teaching"` · `"Gentle guidance"` · `"Sound & mantra"` | `hasSilence` · `hasNature` · `hasBreathBody` · `hasStoryTeaching` · `hasMantra` |
| `focusPlaces` | `"Forest / Park"` · `"Near water"` · `"Open fields"` · `"Mountains"` (+ any non-nature places not mapped) | `hasNature` (supplements `teachingTypes`) |
| `meditationExp` prefixes | `"Never"` · `"A little"` · `"Yes"` | `beginner` · `experienced` |

Any chip-label change requires a sync round · both predicates + Mixpanel property values update together · no surprise wire drift.

---

## Implementation patches

### iOS · [SpiritPathApp.swift:101-127](SpiritPath/SpiritPath/App/SpiritPathApp.swift#L101)

```diff
 var spiritMatch: SpiritMatch {
-    let beginner = meditationExp.contains("Never") || meditationExp.contains("A little")
-    let experienced = meditationExp.contains("Yes")
+    let beginner = meditationExp.hasPrefix("Never") || meditationExp.hasPrefix("A little")
+    let experienced = meditationExp.hasPrefix("Yes")
     let silence = teachingTypes.contains("Silence-based")
     let nature = teachingTypes.contains("Nature connection")
               || focusPlaces.contains("Forest / Park")
               || focusPlaces.contains("Near water")
               || focusPlaces.contains("Open fields")
               || focusPlaces.contains("Mountains")
     let breathBody = teachingTypes.contains("Breathwork")
                   || teachingTypes.contains("Body awareness")
     let storyTeaching = teachingTypes.contains("Story & wisdom")
                      || teachingTypes.contains("Buddhist teaching")
                      || teachingTypes.contains("Gentle guidance")
     let mantra = teachingTypes.contains("Sound & mantra")
     // ... 7-row matrix unchanged
 }
```

Diff is 3 lines · no logic change beyond prefix-match flip.

### Android · [SpiritPathOnboarding.kt:1271-1297](android/app/src/main/java/com/dekphut/spiritpath/feature/onboarding/presentation/SpiritPathOnboarding.kt#L1271)

```diff
 private fun computeSpiritMaster(state: OnboardingState): SpiritMaster {
     val beginner    = state.meditationExp.startsWith("Never") || state.meditationExp.startsWith("A little")
     val experienced = state.meditationExp.startsWith("Yes")
-    val hasSilence  = state.teachingTypes.any { it.contains("Silence", ignoreCase = true) }
-    val hasNature   = state.teachingTypes.any { it.contains("Nature", ignoreCase = true) } ||
-        state.focusPlaces.any {
-            it.contains("Forest", true) ||
-                it.contains("water", true) ||
-                it.contains("Mountains", true) ||
-                it.contains("Open", true)
-        }
-    val hasBody   = state.teachingTypes.any { it.contains("Body", true) }
-    val hasBreath = state.teachingTypes.any { it.contains("Breath", true) }
-    val hasStory  = state.teachingTypes.any {
-        it.contains("Story", true) ||
-            it.contains("Buddhist", true) ||
-            it.contains("Gentle", true)
-    }
-    val hasMantra = state.teachingTypes.any {
-        it.contains("Sound", true) || it.contains("mantra", true)
-    }
+    val hasSilence      = "Silence-based" in state.teachingTypes
+    val hasNature       = "Nature connection" in state.teachingTypes ||
+                          state.focusPlaces.any { it in NATURE_PLACES }
+    val hasBreathOrBody = "Breathwork" in state.teachingTypes ||
+                          "Body awareness" in state.teachingTypes
+    val hasStory        = "Story & wisdom" in state.teachingTypes ||
+                          "Buddhist teaching" in state.teachingTypes ||
+                          "Gentle guidance" in state.teachingTypes
+    val hasMantra       = "Sound & mantra" in state.teachingTypes

     return when {
-        hasBody || hasBreath -> SpiritMaster.mun
-        experienced && (hasNature || hasSilence) -> SpiritMaster.chah
-        // ... same matrix
+        hasBreathOrBody -> SpiritMaster.mun
+        experienced && (hasNature || hasSilence) -> SpiritMaster.chah
+        experienced && hasStory -> SpiritMaster.chah
+        beginner && hasStory -> SpiritMaster.chah
+        hasMantra -> SpiritMaster.sodh
+        beginner && (hasSilence || hasNature) -> SpiritMaster.sodh
+        else -> SpiritMaster.sodh
     }
 }

+private val NATURE_PLACES = setOf("Forest / Park", "Near water", "Open fields", "Mountains")
```

Android also collapses `hasBody` / `hasBreath` into single `hasBreathOrBody` (iOS uses single `breathBody` already) · tighter parity.

### Both · canonical chip vocabulary constants (optional · recommended)

iOS: `SpiritPath/Core/Constants/QuizVocabulary.swift` · struct with arrays of chip labels
Android: `app/src/main/java/com/dekphut/spiritpath/core/constants/QuizVocabulary.kt` · object with constants

Optional for R20 (both sides already inline · no DRY violation today) · lock file existence if a Phase 3 Settings adds "edit quiz answers" surface.

---

## Questions back to both platforms

1. Accept R20 canonical form (startsWith + exact-equals on both)?
2. iOS · apply the 3-line predicate diff · recompile · smoke-test the 7-row matrix
3. Android · apply the substring→exact-equals swap + `NATURE_PLACES` set · recompile · smoke-test
4. Either side object to the exact-equals choice? (reasonable counter: substring is more forgiving to typos in chip labels)

---

## Acknowledge format

Each platform replies:

```
✓ Read R20 · canonical form accepted
  · startsWith for experience · agreed
  · exact-equals for chip labels · agreed
  · chip vocabulary snapshot · confirmed 8 teachingTypes + 4 focusPlaces
Applied diff: <file:line>
Build: <PASS | FAIL>
Smoke-test: ran 7 row-fire scenarios via debug state fixtures · all produce locked outcomes
Commit: <sha> fix: R20 · quiz predicate canonical form · <platform> adopts
Pushed: <✓ origin | ⏳ pending user push>
```

If counter-proposing · state the alternative + reason · CodeReview will iterate R20.

---

## Locked this wave (R20 · wave 9 when both sign)

| ID | Topic | Locked |
|---|---|---|
| C3e | Quiz experience predicate | `String.startsWith` on both platforms (extends C3c) |
| C3f | Quiz chip label predicate | exact-equals (`Array.contains` / `in`) on both · NO substring match |
| C3g | Chip vocabulary source-of-truth | 8 teachingTypes + 4 focusPlaces + 3 experience-prefixes listed above · change requires sync round |

---

## Tone rule

> *"The path is not elsewhere."*
