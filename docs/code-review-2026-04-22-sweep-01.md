# SpiritPath · Code Review · 2026-04-22 · Sweep 01

**Scope:** Full 8-category cross-platform sweep · iOS + Android + Supabase
**Trigger:** Wave 5 close · pre-V3.1 + pre-Phase 1 Round 2 baseline
**Reviewer:** CodeReview agent · read-only pass

> *"The path is not elsewhere."*

---

## Health dashboard

| Metric | Value |
|---|---|
| Sync rounds | 19 |
| Waves closed | 5 |
| Migrations drafted | 7 / 7 |
| Migrations applied to staging | 0 / 7 (user-blocked · creds pending) |
| iOS entity coverage | 0 / 17 (intentional · direct-Supabase path · Phase 1 R2) |
| Android entity coverage | 17 / 17 |
| Android repositories | 1 (FeatureFlagsRepository only) |
| Cross-platform drift issues | **1** (quiz predicate implementation) |
| Tone violations | 0 (onboarding pass; Phase 3+ surfaces unbuilt) |
| Convention violations (SQL) | 0 |
| Convention violations (Kotlin/Swift) | 0 |
| Open sync rounds | 0 (6 flagged files reconciled as closed) |
| Mixpanel events instrumented | 0 / 0 (pre-instrumentation · preventive only) |
| Open blockers (user-owned) | 3 (Supabase creds · Hilt decision · Play Console IDs) |

---

## Critical issues (L4)

✓ None.

---

## Drift alerts (L2 / L3)

### 🚨 DRIFT · Quiz predicate implementation (L3 · Round 20 recommended)

**Matrix logic is in sync · predicate implementations have diverged.**

All 7 rows fire in the canonical order on both platforms · Row 6a correctly returns Sodh before Row 6b · Row 7 fallback → Sodh on both. The divergence is in HOW the predicates test the raw `OnboardingState` strings.

| Predicate | iOS ([SpiritPathApp.swift:101-127](SpiritPath/App/SpiritPathApp.swift)) | Android ([SpiritPathOnboarding.kt:1271-1308](../../android/app/src/main/java/com/dekphut/spiritpath/feature/onboarding/presentation/SpiritPathOnboarding.kt)) | Locked spec (C3c · R7) |
|---|---|---|---|
| `beginner` | `meditationExp.contains("Never") \|\| .contains("A little")` | `meditationExp.startsWith("Never") \|\| .startsWith("A little")` | `startsWith` |
| `experienced` | `meditationExp.contains("Yes")` | `meditationExp.startsWith("Yes")` | `startsWith` |
| `silence` | Array.contains(`"Silence-based"`) exact | `any { it.contains("Silence", ignoreCase=true) }` substring | unspecified |
| `nature` (teachingTypes) | Array.contains(`"Nature connection"`) exact | `any { it.contains("Nature", ignoreCase=true) }` substring | unspecified |
| `nature` (focusPlaces) | Array.contains each of `"Forest / Park"`, `"Near water"`, `"Open fields"`, `"Mountains"` exact | substring match on `"Forest"`, `"water"`, `"Mountains"`, `"Open"` | C3d locked the set of 4 tokens, not matching semantics |
| `breath/body` | Array.contains(`"Breathwork"`) OR Array.contains(`"Body awareness"`) exact | `any { it.contains("Breath", true) }` OR `any { it.contains("Body", true) }` substring | unspecified |
| `story` | Array.contains(`"Story & wisdom"` / `"Buddhist teaching"` / `"Gentle guidance"`) exact | substring on `"Story"` / `"Buddhist"` / `"Gentle"` | C3a locked the 3 tokens, not matching semantics |
| `mantra` | Array.contains(`"Sound & mantra"`) single exact | `any { it.contains("Sound", true) \|\| it.contains("mantra", true) }` — **OR across two fragments** | C3a locked the single `"Sound & mantra"` chip |

**Why this is a real drift, not cosmetic:**

1. **iOS violates the C3c locked spec.** R7 locked `startsWith` for experience predicates on both platforms. iOS is using `contains`.
2. **Mantra predicate is asymmetric.** If a future chip contains `"Sound"` without `"& mantra"` (e.g., a "Sound bath" chip), Android routes to Sodh Row 6a · iOS does not. The OR-across-fragments form on Android is a superset of the iOS form.
3. **Chip label coupling differs.** iOS is brittle-locked to exact chip labels (`"Forest / Park"`). A label tweak on either platform silently decouples routing on iOS while Android keeps matching by fragment. This is drift risk waiting to fire on the next copy change.

**In today's onboarding chip set the outcomes converge** · all expected chip strings satisfy both matchers · so user-facing results are currently identical. But this is luck, not design.

**Recommendation:**

Open **Round 20 · Quiz Predicate Canonical Form** to lock:
- Experience predicates: `startsWith` on both platforms (iOS adopts)
- Chip label predicates: either (a) exact-equals on both · or (b) case-insensitive substring on both · one canonical form
- Single chip for `mantra`: `"Sound & mantra"` exact-equals on both (preferred · matches C3a lock explicitly)
- Add a test vector set in the round doc that exercises each row + current chip labels so future changes can't silently drift

**Files to change after round locks:**
- `SpiritPath/SpiritPath/App/SpiritPathApp.swift:102-108` (7 predicate lines)
- `android/app/src/main/java/com/dekphut/spiritpath/feature/onboarding/presentation/SpiritPathOnboarding.kt:1273-1297` (predicate block)

---

## Parity check

| Convention | iOS | Android | Status |
|---|---|---|---|
| Quiz matrix (7 rows · order · outcomes) | ✓ | ✓ | OK |
| Quiz predicate implementation | `contains` + exact-array | `startsWith` + substring | ⚠ drift · see above |
| Row 6a mantra → Sodh (early return) | ✓ line 122 | ✓ line 1304 | OK |
| Schema column-for-column · 17 tables | n/a (no entities yet) | 17 / 17 | OK for now |
| Enum values · 8 enums | n/a | ✓ | OK |
| Client-generated `sessions.id` | locked in SQL (no server default) | `SessionEntity.id: String(UUID)` | OK |
| Offline-first fields (`client_created_at` · `synced_at`) | locked in SQL | present in `SessionEntity` | OK |
| Night log AES-256-GCM · `bytea` / `ByteArray` + equals/hashCode | locked in SQL | `NightLogEntryEntity` lines 88-113 | OK |
| `journey_progress.stages_entered_at` jsonb | locked in SQL | serialized `String` with converter | OK |
| Feature flags seed idempotency | `ON CONFLICT (key) DO NOTHING` | n/a (seed runs in Postgres) | OK |
| RLS Pattern A (self-only · user-data) | n/a | n/a (server-side) | ✓ all 11 tables |
| RLS Pattern B (authenticated read · content) | n/a | n/a | ✓ 5 tables + feature_flags |
| RLS Pattern C (subscription gate · teaching_units) | n/a | n/a | ✓ stage_index = 1 OR active subscription |
| Soft delete · `deleted_at` filter on SELECT | n/a | n/a | ✓ 6 user-data tables (journey/teaching progress + prefs + windows correctly omit) |
| Seed idempotency across V3 + V7 | n/a | n/a | ✓ all 4 seed INSERTs use `ON CONFLICT DO NOTHING` |
| Naming · snake_case columns · plural snake_case tables · lowercase_snake enums | n/a | n/a | ✓ 100% compliance |
| Mixpanel taxonomy (events Title Case · properties snake_case) | 0 events | 0 events | ✓ no drift possible yet · preventive |
| Tone rule (gamification · productized voice · medical claims) | clean | clean | ✓ onboarding |

---

## Convention violations

✓ No violations across SQL, Kotlin entities, or naming.

All 4 seed INSERT statements are idempotent:
- `0003_content.sql:221` lineages · `ON CONFLICT (id) DO NOTHING`
- `0003_content.sql:249` stages · `ON CONFLICT (lineage_id, stage_index) DO NOTHING`
- `0003_content.sql:262` sound_tracks · `ON CONFLICT (id) DO NOTHING`
- `0007_feature_flags.sql:57` feature_flags · `ON CONFLICT (key) DO NOTHING`

---

## Tone violations

✓ No violations. Both onboarding files hold the tone rule.

### Observations (L1 · not violations)

- **Pali term `Kammaṭṭhāna`** appears in both files as part of `SpiritMaster.mun.style` / `SpiritMatch.mun.style` copy: `"Forest · Kammaṭṭhāna"`. iOS line 147 · Android line 118. No translation mechanism is visible in the onboarding surface today. This is acceptable for onboarding (the term appears alongside "Forest" as a bridge) but when the lineage card renders on the Spirit Match result screen and later on Profile/Journey, a first-occurrence translation or tooltip should appear per locked tone rule. Track for Phase 1 Round 2 (iOS) and Android equivalent.
- **Night Log encryption warning copy** is not yet present in either file. This is expected · the copy lands on the Night Log Settings surface post-Phase 1. When it lands, the string must be verbatim (ios-sync-reply.md line 74 locked form):
  > *"Night Log entries are encrypted on this device. Uninstalling the app or switching devices will permanently lose access to older entries."*

---

## Mixpanel taxonomy audit

Current state · **0 events instrumented** on either platform. No drift possible today.

**Preventive lock · for future reference when instrumentation begins (Phase 1 Round 2+):**

- Event names: `"Title Case with Spaces"` · e.g. `"Session Started"` · `"Quiz Completed"` · `"Lineage Selected"`
- Property keys: `snake_case` · e.g. `lineage_id` · `duration_target_sec` · `stage_index`
- Enum property values: `lowercase_snake` · matching Postgres enum values exactly · e.g. `"mindful_walking"` · `"trial"` · `"outer_path"`
- Feature flag keys: `snake_case` flat · e.g. `audio_delivery` (not `audio.delivery`)
- Parity gate: no Mixpanel dashboard created until BOTH platforms emit the event with identical props
- Both sides should reference a single source-of-truth events document when rolling out any new event · propose creating `SpiritPath/docs/mixpanel-taxonomy.md` at first instrumentation

---

## Sync protocol status

### Flagged files reconciled

All 6 files that surfaced `⏳`/`awaiting`/`pending` markers are legacy status lines from when the round was in flight · each is closed by a subsequent round:

| File | Round | Marker | Closed by |
|---|---|---|---|
| `SpiritPath/docs/ios-sync-reply.md` | iOS reply to C1-C5 | `⏳` on C3 + C4 counter | `ios-sync-reply-2.md` (C3) · `supabase-android-reply-2.md` (C4) |
| `SpiritPath/docs/ios-sync-reply-3.md` | R8 · C3b + V1 idempotency | `awaiting Android C3c+C3d` | `android/docs/android-sync-round9.md` (C3c + C3d applied) |
| `android/docs/android-sync-round9.md` | R9 · C3c+C3d+ProfileEntity | Status line is "wave 1 closed" · marker false-positive | Self-closing |
| `android/docs/android-sync-round10.md` | R10 · V2 review | Status "wave 2 closed" · false-positive | Self-closing |
| `android/docs/android-sync-round17.md` | R17 · V4 review | Status "wave 4 closed" · false-positive | Self-closing |
| `android/docs/android-sync-round19.md` | R19 · V5+V6+V7 batch | Status "wave 5 closed" · false-positive | Self-closing |

**Open rounds: 0.** Paper trail is coherent.

### Round numbering gaps · expected

| Gap | Explanation |
|---|---|
| R1 | `SpiritPath/docs/android-sync-prompt.md` (initial iOS → Android brief) |
| R3 | Embedded in `android/docs/supabase-android-reply.md` (Android first reply to iOS R1) |
| R5 | iOS-side C3 closure acknowledged in `ios-sync-reply-2.md` (Android has no separate R5 doc; R5 = iOS side of the round-3 Android follow-up) |
| R15 | iOS V3 S1+S2 work applied in-code · no separate doc · closed by `ios-sync-reply-4.md` (R14) |
| R16 | iOS V4 brief = `SpiritPath/docs/android-v4-brief.md` (paste-ready brief, not numbered round) |
| R18 | iOS V5+V6+V7 batch brief = `SpiritPath/docs/android-v5-v7-brief.md` (paste-ready brief, not numbered round) |

All gaps are expected by design (one-sided rounds or paste-ready briefs counted against iOS round counter).

### Round 20 · recommended opening

**Title:** Quiz Predicate Canonical Form
**Owner to draft:** either side · iOS has the bigger change (adopt `startsWith` + normalize chip matching); Android already matches the locked C3c spec for experience predicates.
**TL;DR items:**
- Lock `startsWith` for `beginner` / `experienced`
- Lock a single matching strategy (exact-equals OR case-insensitive-substring) for `teachingTypes` / `focusPlaces` chip labels
- Pin the exact chip label source-of-truth so a copy edit cascades to both matchers
- Add a test vector table to the round doc exercising each row with the current chip set

CodeReview agent will not open this round unilaterally (per protocol) · recommend iOS session draft it given iOS is the side that needs to move.

---

## Observations (non-blocking)

- **iOS entity coverage 0/17** is not a drift. iOS is designed to hit Supabase directly via swift-supabase SDK. If Phase 1 Round 2 decides to add a local SwiftData/CoreData cache for offline session drafts, entity parity review reopens at that point.
- **Android `FeatureFlagsRepository`** is the sole repository in `core/data/repository/`. All other domain repos (sessions · reflections · journey · teachings · subscriptions · night log · profile · content) remain to be built · expected per Phase 1 Round 2 plan.
- **Android branch `codex/onboarding-dark-reskin` is dirty** with 3 modified `.idea` files + untracked `docs/` + `CLAUDE.md`. Not reviewed (out of scope per plan). Flag for Android session to clean before next push.
- **Supabase migrations 0/7 applied to staging** · user-blocked on Supabase staging URL + anon key. Not a review finding · a tracked open blocker.
- **HealthKit / Health Connect write** per C5 lock is not coded on either side yet · preventive note only.

---

## Next checkpoints

**iOS**
1. Draft **Round 20 · Quiz Predicate Canonical Form** · propose `startsWith` + single-strategy chip matching · include test vectors
2. Continue Phase 1 Round 2 UI scaffolding (HomeView · SessionView · ReflectionView · JourneyView · TeachingsView) per consolidation brief
3. Draft V3.1 content-depth seed migration (per wave 5 close)
4. When Round 20 locks, apply predicate update in `SpiritPathApp.swift:102-108`

**Android**
1. Review Round 20 when iOS drafts · confirm or counter-propose
2. Clean working tree on `codex/onboarding-dark-reskin` · commit or stash `.idea` + untracked docs before next push
3. Begin ViewModel + repository layer for onboarding once dark-reskin closes · prepare for Home/Session scaffolds matching iOS Phase 1 Round 2

**User-owned (blockers)**
1. Provision Supabase staging project · deliver `SUPABASE_URL` + `SUPABASE_ANON_KEY` to both agents (unblocks V1–V7 push + RLS smoke tests)
2. Ratify Hilt DI choice for Android (brief references as pending)
3. Create App Store Connect + Play Console product IDs for annual subscription (unblocks `user_subscriptions.product_id` seed + StoreKit/Billing wiring)

---

## Verification · sweep completeness

1. ✓ Report written to `SpiritPath/docs/code-review-2026-04-22-sweep-01.md`
2. ✓ Health dashboard populated with current values
3. ✓ All 8 audit categories have a section · empty ones marked `✓ no violations` explicitly
4. ✓ 6 "open" sync docs reconciled to closed state
5. ✓ Round numbering gaps (R1/R3/R5/R15/R16/R18) each explained
6. ✓ Next checkpoints present for iOS · Android · user
7. ✓ No source code changes made · only this report
8. ✓ No sync round files created unilaterally · Round 20 recommended only

---

*End of sweep 01. Next sweep: after Round 20 closes OR after V3.1 seed lands OR after Phase 1 R2 first UI commits, whichever first.*
