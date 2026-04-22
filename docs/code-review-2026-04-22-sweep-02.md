# SpiritPath · Code Review · 2026-04-22 · Sweep 02

**Scope:** All changes since Sweep 01 (same day · earlier) · Phase 1.0 close · Phase 1.4 hookup · Phase 1.5 wiring · R21 · R22 · paper trail alignment
**Trigger:** user-requested CodeReview submission after R22 locked + iOS Live View verified
**Reviewer:** CodeReview agent
**Previous sweep:** `SpiritPath/docs/code-review-2026-04-22-sweep-01.md` (4 hours earlier)

> *"The path is not elsewhere."*

---

## Health dashboard

| Metric | Value · change since Sweep 01 |
|---|---|
| Sync rounds | 22 (+3 since Sweep 01: R20 still pending · R21 · R22) |
| Waves closed | 7 (+2 · wave 6 R21 migration fixes · wave 7 R22 Mixpanel) |
| Migrations drafted | 8 / 8 (+1 · `0005_compliance_enum_prep.sql` inserted R21) |
| Migrations applied to staging | **8 / 8** ✅ live on `yepgrbljewjktvuyhxso` (up from 0 / 7) |
| iOS entity coverage | 0 / 17 (unchanged · direct-Supabase path · Phase 1 R2 pending) |
| Android entity coverage | 17 / 17 (unchanged) |
| Android repositories | 1 (`FeatureFlagsRepository`) unchanged |
| Cross-platform drift issues | **0** (quiz predicate still latent · see R20) |
| Cross-platform Mixpanel parity | **100%** · 5 events · 33 property keys · 1:1 match iOS ↔ Android |
| Tone violations | 0 |
| Convention violations | 0 |
| Open sync rounds | 2 (R20 · unopened but recommended · R22 wave 8 pending first-fire verification) |
| Mixpanel events instrumented | 2 / 5 live (onboarding_completed · paywall_viewed) · 3 stubbed (session_started · session_ended · reflection_submitted) · both platforms |
| Mixpanel events ingested to staging | **iOS: ✓ 4 events in Live View · Android: ⏳ pending emulator run** |
| Open blockers (user-owned) | 7 · see Observations |

---

## Critical issues (L4)

✓ None this sweep.

Sweep 01's lone L3 (quiz predicate drift R20) remains unopened but not critical (Wave 1 was locked with permissive matching; current chip set does not trigger divergence in production paths; risk materializes only if chip labels change).

---

## Drift alerts (L2 / L3)

### ⏳ R20 · Quiz predicate canonical form · **still recommended · not opened**

Status unchanged from Sweep 01. iOS uses `String.contains()` + exact-array matching on chip labels · Android uses `String.startsWith()` + case-insensitive substring matching. Matrix logic identical · predicate implementations drifted. Current chip set masks it; a copy edit would trigger silent divergence.

**Recommendation:** iOS session drafts R20 after current Phase 1.5 close (lower priority than active Phase 1.5 Live View verification). CodeReview will audit R20 content when drafted.

### ✅ Resolved since Sweep 01

| Item | Sweep 01 status | Sweep 02 status |
|---|---|---|
| Supabase staging push (user-blocked on creds) | ⏳ open blocker | ✅ V1-V8 applied · staging live · R21 closed |
| V1 `compliance_request_status` enum completion (5 vs 6 values · SQL vs Kotlin drift) | **undetected** · Sweep 01 missed this | ✅ caught during push · `0005_compliance_enum_prep.sql` landed · R21 closed |
| V3/V4 Pattern C ordering bug (forward-dep on user_subscriptions) | **undetected** · Sweep 01 was static-only | ✅ caught during push · V3 placeholder + V4 upgrade block · R21 closed |
| Mixpanel taxonomy lock | 0 events · preventive only | ✅ 5 events locked R22 · 2 live · 3 stubbed · iOS Live View verified |
| C4 event naming (Title Case vs snake_case) | locked Title Case | ✅ flipped to snake_case object_verb R22 |
| iOS creds update to new staging | flagged pending | ✅ `Supabase.swift` updated · `Secrets.swift` deleted |
| Android `Constants.kt` stale values | flagged (trial days · stale tables · OneSignal) | ✅ cleaned up in Android Phase 1.4 hookup commit |
| Android R21 doc-string renumber (V5/V6/V7 → V6/V7/V8) | not yet triggered | ✅ 5 entity files updated |

---

## Convention violations

✓ No violations.

- All SQL snake_case ✓
- All Postgres enum values lowercase_snake ✓
- All migration seed INSERTs idempotent (`on conflict do nothing`) ✓
- All RLS policies Pattern A/B/C correct ✓
- All Mixpanel event names snake_case object_verb (post R22) ✓
- All Mixpanel property keys snake_case ✓
- All Mixpanel enum values lowercase_snake (matches Postgres wire values) ✓

---

## Tone violations

✓ No violations.

- Onboarding strings unchanged · still hold tone rule (per Sweep 01 audit)
- Mixpanel event names + property keys are internal telemetry · not user-visible · tone rule scope clarified in R22 Part 1

---

## Parity check

| Convention | iOS | Android | Status |
|---|---|---|---|
| Supabase project ref · `yepgrbljewjktvuyhxso` | ✓ `Supabase.swift:12` | ✓ `Constants.kt:5` | ✓ match |
| Anon key · `sb_publishable_FqHw...04` | ✓ | ✓ | ✓ match |
| Schema column-for-column · 17 tables | n/a (no entities yet) | 17 / 17 | ✓ OK |
| Enum values · 8 enums + 6-value `compliance_request_status` | n/a | ✓ 6 values (ahead of SQL before R21 · SQL now aligned) | ✓ post-R21 |
| Quiz matrix (7 rows · order · outcomes) | ✓ | ✓ | ✓ |
| Quiz predicate implementation | contains + exact-array | startsWith + substring | ⚠ drift (R20) |
| Mixpanel event names (5) | typed `AnalyticsEvent` enum · snake_case | sealed class `AnalyticsEvent` · snake_case | ✓ 5/5 match |
| Mixpanel property keys (33 total) | iOS dict | Android JSONObject | ✓ 33/33 match |
| Mixpanel distinct_id = `auth.user.id` | ✓ planned (auth Phase 1.7) | ✓ planned (auth Phase 1.7) | ✓ parity plan |
| Mixpanel consent gate · `profiles.tracking_opt_out` cached | ✓ `UserDefaults` | ✓ `SharedPreferences` | ✓ |
| Mixpanel `reset()` on logout | stub in `Analytics.reset()` | stub in `AnalyticsClient.reset()` | ✓ |
| Mixpanel re-identify on foreground | `scenePhase .active` | `ProcessLifecycleOwner ON_START` | ✓ platform-idiomatic parity |
| PrivacyInfo / Data Safety | `PrivacyInfo.xcprivacy` created · `NSPrivacyTracking=false` | Play Data Safety form update deferred until prod | ✓ appropriate per platform |
| Commit hygiene | 2 commits on main (`3fa5dd1` mega + `27cc474` + `576eab3`) | 5 commits on `codex/onboarding-dark-reskin` (logical split) | ⚠ iOS squashed · Android clean (cosmetic · not drift) |

---

## Sync protocol status

### Closed this sweep (waves 6–7)

- **R21** · `SpiritPath/docs/codereview-round21.md` · V3/V4 ordering · V1 enum completion · V5-V7 renumber · staging schema live · wave 6 closed
- **R22** · `SpiritPath/docs/codereview-round22.md` · C4 revision + Mixpanel taxonomy lock · iOS + Android signed · 5 events locked · 2 live · 3 stubbed · wave 7 closed

### Still recommended but not opened

- **R20** · quiz predicate canonical form · iOS session to draft · low priority · non-blocking
- **R23** (future · not yet framed) · Phase 1.7 bundle · Auth Apple/Google + StoreKit 2 + Sentry/Crashlytics + Fastlane+TestFlight lane · activates Mixpanel identify hooks currently stubbed

### Pending verification (wave 8 trigger)

- Android emulator Live View first-fire · when `onboarding_completed` + `paywall_viewed` ingest cleanly → wave 8 closes → Phase 1.5 formal close

### Locked items · new since Sweep 01

Wave 6 (R21):
- V1a · `compliance_request_status` = 6 values
- V3a · Pattern C forward-dep split rule
- M1 · Supabase CLI filename convention
- M2 · ALTER TYPE ADD VALUE migration isolation

Wave 7 (R22):
- C4-r2 · event naming flip to snake_case object_verb
- M3 · Mixpanel distinct_id = `auth.user.id` · never email
- M4 · re-identify on every foreground
- M5 · `profiles.tracking_opt_out` = consent source of truth
- M6 · Phase 1.5 taxonomy · 5 events
- M7 · Value Moment = `session_ended` with `completed=true` AND `duration_actual_sec ≥ duration_target_sec × 0.8`

### Paper trail files added this sweep

```
SpiritPath/docs/codereview-round21.md
SpiritPath/docs/codereview-round22.md
SpiritPath/docs/code-review-2026-04-22-sweep-02.md   (this file)
```

All reachable from plan Tab 04 round cards.

---

## Observations (L1 · non-blocking)

### New observations this sweep

- **O1 · iOS single mega-commit** — `3fa5dd1 Phase 1.0 · Retune onboarding tokens` contains 48 files · 5824 insertions · bundles Phase 1.0 + Phase 1.4 + R21 migrations + R22 docs + sync paper trail + IDE config. `git log --grep="Phase 1.4"` returns 0 hits · can't cherry-pick / revert Phase 1.4 independently of Phase 1.0. Cosmetic · git-bisect ergonomics decayed. Not fixable post-push (force-push to main risky). Recorded as commit-hygiene lesson for future phases.
- **O2 · supabase/.temp was briefly tracked** — caught in `27cc474` · gitignored + untracked. Lesson: `.gitignore` should include `supabase/.temp/` by default before any `supabase link` runs.
- **O3 · Android `SpiritPathApplication.kt` · CLAUDE.md doc drift** — Android's CLAUDE.md file-map line 60 aspirationally listed `SpiritPathApplication.kt` before the class existed. Now it exists · drift resolved. General rule: don't list files in CLAUDE.md until they exist.
- **O4 · iOS commit attribution mismatch** — iOS session had 2 bundled changes (Phase 1.0 + Phase 1.4 hookup) then added Mixpanel wiring as separate commit `576eab3`. Commit message says "Phase 1.0" but 70%+ of content is Phase 1.4 + R21 paper trail. Historical-only · paper trail reconstructable via sync round docs in `SpiritPath/docs/`.
- **O5 · Mixpanel events geo-tagged to Bangkok** · dev location · not a concern · auto-collected from IP. Confirm before prod whether Mixpanel should strip/keep geo per App Privacy disclosure.
- **O6 · `moments_of_return` stub at 0** · both platforms send 0 constant · session mechanic not implemented · revisit Phase 1.3.

### Observations still carried forward from Sweep 01

- **O7 · Onboarding · Dynamic Type not scaling** · fixed `.font(.system(size:))` · intentional editorial preservation · pre-existing · out of Phase 1.0 scope · needs product/design weigh-in if changes
- **O8 · Onboarding · inline hex** · `#AAAAAA` · `#CCCCCC` · `#E0E0E0` · `#F5F5F5` · `#0B1628` · not tokenized in `spirit*` palette · deferred to future Phase 0 cleanup
- **O9 · iOS Swift entity coverage 0/17** · direct-Supabase path · not drift · Phase 1 R2 pending
- **O10 · Kammaṭṭhāna term** · present in `SpiritMatch.mun.style` both platforms · no translation mechanism on profile surface today · track for Phase 1.2 (HomeView) / Phase 3 (Profile)

### Sweep 01 audit gap · L1 lesson (logged)

Sweep 01 reported `ComplianceRequestStatus | PENDING, PROCESSING, READY, DELIVERED, FAILED | ✓` · missed 6th value `CANCELLED`. Enum count compared per-class · not cross-file SQL usage. **Rule added to CodeReview audit procedure:** per-enum check must include SQL usages across all migration files · not just `CREATE TYPE` definitions. Self-correcting procedural change · no sync round.

---

## Phase status snapshot

| Phase | iOS | Android | Blockers |
|---|---|---|---|
| **Phase 1.0** · tokens + fonts | ✅ CLOSED 2026-04-22 | n/a (own dark reskin path) | — |
| **Phase 1.1** · RootTabView + Screen enum | ⏳ not started | ⏳ not started (parallel nav spike also pending) | none |
| **Phase 1.2** · HomeView | ⏳ not started | ⏳ not started | Phase 1.1 |
| **Phase 1.3** · Practice + Session + Reflection | ⏳ not started | ⏳ not started | Phase 1.1 · activates 3 stubbed Mixpanel events |
| **Phase 1.4** · Supabase schema + RLS | ✅ schema live V1-V8 · creds hooked | ✅ entities 17/17 · creds hooked | Auth providers (user) |
| **Phase 1.5** · Mixpanel SDK + events | ✅ code landed · ✅ Live View verified (4 events) | ✅ code landed · ⏳ Live View pending emulator | Android emulator run |
| **Phase 1.6** · HealthKit / Health Connect | ⏳ not started | ⏳ not started | Phase 1.3 session mechanic |
| **Phase 1.7** · Auth + StoreKit + Crash + CI | ⏳ not started · activates Mixpanel identify hooks | ⏳ not started (Hilt decision pending · Play product IDs pending) | user-owned (Apple/Google providers · Hilt · product IDs) |

---

## Next checkpoints

### User-owned (7 open blockers · prioritized)

1. **Android emulator Live View verification** · run emulator · complete onboarding · confirm `onboarding_completed` + `paywall_viewed` ingest · **closes wave 8 · Phase 1.5**
2. **Push 2 local commits** · iOS `576eab3` on main · Android `2b8519f` on `codex/onboarding-dark-reskin` · CLI has no creds · manual `git push`
3. **Mixpanel dashboard 3 setup** · timezone (immutable) · Simplified ID Merge (before first authenticated user) · Data Standards (snake_case enforcement)
4. **Mixpanel dev vs prod project decision** (D1) · current token is unknown-env · recommend creating dev project before Phase 1.3 real events flow
5. **Supabase Auth providers** · Apple + Google in dashboard → Authentication → Providers · unblocks Phase 1.7 identify hook activation
6. **Hilt decision** (D4) · blocks Android Phase 1.7 retrofit
7. **Play Console product IDs** · blocks Android StoreKit/Billing subscription wiring

### Platform next actions

- **iOS session** · after Phase 1.5 closes · next task is Phase 1.1 (RootTabView + Screen enum · flat state machine per app.jsx)
- **Android session** · after Android Live View verifies · next task is Phase 1.1 nav spike (Navigation Compose 2.8)
- **CodeReview** · next sweep triggers on: (a) Phase 1.1 landing (b) R20 opening (c) any future migration (d) Phase 1.3 unlock of stubbed Mixpanel events

---

## Verification · sweep completeness checklist

1. ✓ Report file written to `SpiritPath/docs/code-review-2026-04-22-sweep-02.md`
2. ✓ Health dashboard populated with all current metrics
3. ✓ All 8 audit categories touched (parity · convention · tone · schema · enum · RLS · naming · Mixpanel)
4. ✓ R21 · R22 closure recorded · wave 6 · wave 7 confirmed closed
5. ✓ Open rounds list: R20 (recommended) + R22 wave 8 trigger (emulator verification)
6. ✓ Phase status snapshot covers all 8 Phase 1 sub-tasks
7. ✓ Paper trail references all reachable via plan Tab 04 or direct file paths
8. ✓ No source code changes made this sweep · only the report file
9. ✓ No sync round files created unilaterally

---

*End of Sweep 02. Next sweep trigger: Phase 1.1 landing OR R20 opening OR Phase 1.3 Session-Reflection UI commits (activates 3 stubbed Mixpanel events).*
