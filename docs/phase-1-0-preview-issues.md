# Phase 1.0 · 21-screen preview pass · iOS-side findings

**From:** iOS session (CLI · no Xcode GUI access)
**To:** CodeReview
**Date:** 2026-04-22
**Re:** Verification pass per CodeReview brief

---

## Capability gap · disclose first

The iOS session runs in a Claude Code CLI environment with access to:
- `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` · headless builds OK
- File read/write · grep · bash
- **No** interactive Xcode.app GUI · **no** SwiftUI Canvas previews · **no** screenshot capture

Therefore the Canvas-preview portion of the 4 gates cannot be run from this session. What I **can** do is a code-path static analysis that predicts the Canvas outcome with high confidence · plus a headless build to catch compile-time regressions.

Two paths forward:

- **(A)** Accept static-analysis verdict below. I update plan Tab 02.
- **(B)** Defer Canvas pass to the human (Xcode user) · they confirm or flag issues · then plan updates. This doc then becomes the handoff brief.

---

## Screen inventory · actual count = 20, not 21

Enumerated from `SpiritPathApp.swift` state machine + `SettlingFlowScreen` sub-steps:

```
Top-level screens (via `screen` state int 1–16):
 1 · MotionLogoScreen              · splash · tap to start
 2 · GetStartedScreen              · Group 2 page 1
 3 · ValuePropsScreen              · Group 2 page 2
 4 · CardQuestionScreen            · "How are you feeling right now?"
 5 · CardQuestionScreen            · "What do you hope walking gives you?"
 6 · PainMomentScreen              · stat card (personalized copy)
 7 · CardQuestionScreen            · "Have you meditated before?" · Q1
 8 · CardQuestionScreen            · "When do you feel most at peace?" · Q2
 9 · ChipQuestionScreen            · focus places (8 chips)
10 · ChipQuestionScreen            · teaching types (8 chips)
11 · SpiritMatchScreen             · spirit guide reveal (Mun/Chah/Sodh)
12 · PermissionTextScreen          · notifications ask
13 · SettlingFlowScreen            · 5 sub-steps · see below
14 · PathSelectionScreen           · pick path (4 options)
15 · PaywallScreen                 · 7-day trial paywall
16 · AuthScreen                    · sign in (Apple/Google/Email/Phone)

SettlingFlowScreen sub-steps (screen 13 · settlingStep 0–4):
13a · settlingStep 0 · "We walk with you." · Location permission
13b · settlingStep 1 · "Soften your shoulders." · Settle 1 of 3
13c · settlingStep 2 · "Let your breath move naturally." · Settle 2 of 3
13d · settlingStep 3 · "Feel the ground beneath you." · Settle 3 of 3
13e · settlingStep 4 · "Something has already changed." · notice-what-shifted
```

Total unique renderable states: **16 + 4 (sub-steps beyond 13a · which is the natural first render) = 20**

Alternative count that lands at 21:
- If `MotionLogoScreen` has two rendered states (logo appear · tap-prompt) the count becomes 21
- If the brief was approximate, 20 is the accurate number

**Flagging for CodeReview:** brief said 21 · code says 20. Not a regression · just a counting note.

---

## Static analysis · 4 gates · predicted verdicts

### G1 · font loads · predicted **PASS (trivially)**

Rationale:

```bash
grep -c "\.font(\.custom" SpiritPathApp.swift         # → 0
grep -c "Sarabun|DMSerifDisplay|Manrope|JetBrainsMono" SpiritPathApp.swift  # → 0
grep -c "\.font(\.system" SpiritPathApp.swift         # → 57
```

Onboarding uses **only** `.font(.system(size:, weight:))` · zero custom font references.

The `SpiritFonts.registerAll()` call at `SpiritPathApp.swift:15` registers DM Serif Display / Manrope / JetBrains Mono for **post-onboarding** use (Phase 1 Round 2+ UI scaffolds). These TTFs are bundled and loaded but unused by onboarding code paths.

Therefore:
- No risk of font-family fallback in onboarding (it never asked for custom families)
- If a Phase 1 Round 2 view ever uses `.font(.custom("Manrope", size: N))`, G1 gate applies to it specifically · not to Phase 1.0 scope

Canvas would show SF in every onboarding screen · matching pre-Phase-1.0 behavior exactly.

### G2 · no vertical clip · predicted **PASS**

Rationale: Phase 1.0 did NOT change any font size, weight, line-spacing, or container height in onboarding code. The only onboarding-visible change is `.spiritGold` hex shift (see G4). Font metrics are identical · clipping behavior is identical.

Layout regression risk: **nil** · no text element has a different height than before Phase 1.0.

### G3 · no horizontal overflow · predicted **PASS**

Same rationale as G2. SF width per glyph at each (size · weight) unchanged. No CTA label, chip label, or title changed family. "Get Started", "Continue", "Show My Spirit Match", etc. all unchanged.

### G4 · pixel sanity vs prototype · predicted **N/A for onboarding**

Onboarding is Phase 0 editorial (B&W · SF · white backgrounds · `Color.spiritPrimary = #111111`). Prototype describes post-onboarding (navy · cream · DM Serif). The two surfaces intentionally differ · this is documented at `Color+App.swift:9`.

The one visual delta in onboarding from Phase 1.0:
- `Color.spiritGold` · changed `#F5C842` → `#F0C870` (prototype moon gold)

**Impact map** (6 call sites in onboarding):

```
SpiritPathApp.swift:507  · CrescentMoon fill (screen 1 · MotionLogoScreen)
SpiritPathApp.swift:513  · fill (screen 1 · same)
+ 4 other `.spiritGold` references are in post-onboarding or unused paths
```

Visual diff at screen 1 only: slight hue warming of the crescent moon icon. Both values are in the warm-gold family · no layout change · no size change · saturation shift is perceptible only in side-by-side compare.

**Interpretation:**
- If CodeReview scope treats this as "adopted prototype gold" (intentional Phase 1.0 deliverable) → **PASS**
- If CodeReview scope treats this as "any visual delta is regression" → **FAIL** (but then Phase 1.0's token-update mandate conflicts with itself)

Per the Phase 1.0 brief ("retune onboarding tokens to match prototype"), this is the intentional delta · G4 is PASS by design.

---

## Headless build · additional verification

```bash
xcodebuild -project SpiritPath.xcodeproj -scheme SpiritPath \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build

** BUILD SUCCEEDED **
```

No compile errors. Swift syntax for:
- Font registration (`SpiritFonts.registerAll()`)
- Extended `.spirit*` palette
- Typography.swift rewrite
- Color+App.swift rewrite
- AppTheme.swift rewrite

all clean.

---

## What I CANNOT verify from this session

- Canvas rendering at iPhone 15 Pro in light / dark / xxxLarge
- Screenshot capture for side-by-side visual diff
- Live font-registration behavior in a running simulator
- Dynamic Type scaling behavior (though the code uses fixed `.font(.system(size:))` which **intentionally bypasses Dynamic Type** · onboarding is not Dynamic-Type-aware by design · may be a pre-existing guardrail to preserve editorial layout)

The Dynamic Type point is worth flagging for CodeReview regardless of this pass: all onboarding text uses fixed `.system(size:)` · setting xxxLarge in Canvas will NOT scale onboarding text. If CodeReview expected text to grow at xxxLarge, that's a pre-existing non-Phase-1.0 design choice that would need its own sync round to change.

---

## Recommended CodeReview action · Option A

Accept static-analysis verdict. Rationale:

1. Onboarding uses zero custom fonts → G1 trivially satisfied
2. No font-family change on any code path → G2/G3 no metric drift
3. Only visual delta is `.spiritGold` hex shift · intentional per Phase 1.0 scope
4. Headless build clean
5. Code-path analysis is deterministic · no runtime uncertainty

If accepted · iOS session updates plan Tab 02 marking Phase 1.0 closed · notes the 20-not-21 screen count as a housekeeping observation.

---

## Recommended CodeReview action · Option B (if visual Canvas required)

Delegate to human user with Xcode:

1. Open `SpiritPath.xcodeproj` in Xcode 15+
2. Drop `#Preview` macros into each screen struct if not already present · or use Xcode's live Canvas on each view
3. Toggle light / dark / xxxLarge for each of the 20 states
4. Screenshot-compare vs pre-Phase-1.0 baseline if available · or eyeball
5. Reply here with PASS or punch list · this session acts on the result

Estimated user time: ~30 minutes for 20 states × 3 trait combos.

---

## Reply to CodeReview · pending your decision

Neither `✓ clean` nor `⚠ N issues` format applies as-is. Proposed third format:

```
≡ Phase 1.0 · static-analysis pass complete · Canvas pass deferred
Xcode available for build: yes (xcodebuild) · Canvas preview: no (CLI session)
Screens enumerated: 20 (not 21 · see preview-issues doc)
Static verdicts: G1 PASS · G2 PASS · G3 PASS · G4 PASS (with `.spiritGold` hue note)
Build: SUCCEEDED
Plan Tab 02: NOT updated · awaiting CodeReview decision on static-vs-Canvas acceptance
Doc: SpiritPath/docs/phase-1-0-preview-issues.md
```

---

## Tone note

This doc is not a punch list in the "issues found" sense · it's a capability gap disclosure + static-analysis report. The punch list format requested by the brief would be misleading if filled in with "no issues found" when the gate-running itself didn't happen. Hence this longer framing.

The path is not elsewhere.
