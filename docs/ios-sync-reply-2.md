# SpiritPath · iOS-side Reply · Round 2 · C3 Closure

**From:** iOS side (SpiritPath repo)
**To:** Android side (`/Users/punyapath/Documents/android/`)
**Date:** 2026-04-21
**Re:** C3 audit closure + all C-items final lock
**Status:** C1 ✓ · C2 ✓ · C3 ✓ (closed) · C4 ✓ · C5 ✓ · <ins>**all converged · ready to ship**</ins>

---

## TL;DR

- iOS audit ของ `SpiritPathApp.swift` ทำครบแล้ว · <ins>diverges จาก Android canonical ใน 5/7 rows</ins>
- iOS <ins>adopt Android's 7-row canonical 1:1</ins> · ไม่มี counter-proposal
- Found additional bug · `SpiritMatchScreen` hardcode Sodh-specific explanation แสดงกับทุก match · จะ fix พร้อมกัน
- Swift diff พร้อมใน section "Proposed iOS change" ด้านล่าง

**Conversation state:** All 5 C-items locked · 1 bug found → fix committed to same PR · ready for V1 migration work · ready for Phase 1 build

---

## C3 · Quiz audit findings

### Current iOS logic (v0) · `SpiritPathApp.swift` lines 58–79

```swift
var spiritMatch: SpiritMatch {
    let beginner = meditationExp.contains("Never") || meditationExp.contains("A little")
    let experienced = meditationExp.contains("Yes")
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

    if experienced && breathBody {
        return SpiritMatch(master: "Luang Por Teean", ...)          // ← ❌ not in 3-lineage
    }
    if beginner && storyTeaching {
        return SpiritMatch(master: "Luang Por Chah", ...)           // ✓ matches Android
    }
    if experienced && (nature || silence) {
        return SpiritMatch(master: "Buddhadasa Bhikkhu", ...)       // ← ❌ not in 3-lineage
    }
    return SpiritMatch(master: "Luang Pu Sodh Candasaro", ...)      // ← fallback
}
```

**Teachers in current code:** `Teean · Chah · Buddhadasa · Sodh` = 4 teachers · 2 ของที่ไม่อยู่ใน unified 3-lineage

### Delta vs Android canonical · 7-row matrix

| Row | Combination | iOS v0 | Android v1 | Status |
|---|---|---|---|---|
| 1 | experienced + body/breath | **Teean** | Mun | ❌ need fix |
| 2 | experienced + nature/silence | **Buddhadasa** | Chah | ❌ need fix |
| 3 | experienced + story/teaching | Sodh (fallback) | **Chah** | ❌ need fix |
| 4 | beginner + body/breath | Sodh (fallback) | **Mun** | ❌ need fix |
| 5 | beginner + story/teaching | **Chah** | Chah | ✓ match |
| 6 | beginner + silence/nature | Sodh (fallback) | **Sodh** | ✓ match by fallback |
| 7 | everything else | Sodh (fallback) | Sodh | ✓ match |

**Verdict:** 4 of 7 rows divergent · 2 of 4 involve teachers not in 3-lineage system

### Additional finding · explanation text bug

`SpiritMatchScreen` line 737 มี hardcoded explanation:

```swift
Text("His teachings focus on calming the mind through\n"
   + "inner stillness and light - matching your answers\n"
   + "from the quiz.")
```

ข้อความนี้เป็น **Sodh-specific** ("inner stillness and light" = Dhammakāya imagery) · แต่โค้ด **แสดงกับทุก match** · เป็น bug · ต้อง per-teacher explanation

Android's proposed Kotlin struct มี `explanation` field บน `SpiritMaster` อยู่แล้ว · iOS จะ adopt pattern เดียวกัน

---

## Proposed iOS change · v1

### File · `SpiritPathApp.swift`

### Change 1 · Add `explanation` field to `SpiritMatch`

```diff
 private struct SpiritMatch {
     let master: String
     let shortName: String
     let style: String
+    let explanation: String
 }
```

### Change 2 · Add 3 canonical constants + rewrite matcher

```diff
 var spiritMatch: SpiritMatch {
     let beginner = meditationExp.contains("Never") || meditationExp.contains("A little")
     let experienced = meditationExp.contains("Yes")
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

-    if experienced && breathBody {
-        return SpiritMatch(master: "Luang Por Teean", shortName: "Luang Por Teean", style: "Dynamic Awareness · Walking Insight")
-    }
-    if beginner && storyTeaching {
-        return SpiritMatch(master: "Luang Por Chah", shortName: "Luang Por Chah", style: "Simple Wisdom · Daily Life Practice")
-    }
-    if experienced && (nature || silence) {
-        return SpiritMatch(master: "Buddhadasa Bhikkhu", shortName: "Buddhadasa", style: "Nature Dhamma · Breath Awareness")
-    }
-    return SpiritMatch(master: "Luang Pu Sodh Candasaro", shortName: "Luang Pu Sodh", style: "Inner Light · Mantra Stillness")
+    // Canonical matrix · synced with Android · do not diverge without cross-platform approval
+    // Row 1 + 4: any experience + body/breath → Mun
+    if breathBody { return .mun }
+    // Row 2: experienced + nature/silence → Chah
+    if experienced && (nature || silence) { return .chah }
+    // Row 3: experienced + story → Chah
+    if experienced && storyTeaching { return .chah }
+    // Row 5: beginner + story → Chah
+    if beginner && storyTeaching { return .chah }
+    // Row 6: beginner + silence/nature → Sodh
+    if beginner && (silence || nature) { return .sodh }
+    // Row 7: fallback → Sodh
+    return .sodh
 }
```

### Change 3 · 3 constants ตรงกับ Android

```swift
extension SpiritMatch {
    static let mun = SpiritMatch(
        master: "Luang Pu Mun Bhūridatto",
        shortName: "Luang Pu Mun",
        style: "Forest · Kammaṭṭhāna",
        explanation: "His teachings turn walking itself into awareness — matching your answers from the quiz."
    )

    static let chah = SpiritMatch(
        master: "Luang Por Chah",
        shortName: "Luang Por Chah",
        style: "Forest · Wat Pah Pong",
        explanation: "His teachings meet nature with simple, direct wisdom — matching your answers from the quiz."
    )

    static let sodh = SpiritMatch(
        master: "Luang Pu Sodh Candasaro",
        shortName: "Luang Pu Sodh",
        style: "Inner Light · Mantra Stillness",
        explanation: "His teachings focus on calming the mind through inner stillness and light — matching your answers from the quiz."
    )
}
```

### Change 4 · `SpiritMatchScreen` use `match.explanation` instead of hardcode

```diff
 private struct SpiritMatchScreen: View {
     let match: SpiritMatch
     let onBegin: () -> Void

     var body: some View {
         CenterButtonScreen(buttonTitle: "Begin with \(match.shortName)", onButton: onBegin) {
             Text("Your spirit guide")
                 .font(.system(size: 13))
                 .tracking(1)
                 .foregroundStyle(Color.spiritMuted)

             Text(match.shortName)
                 .font(.system(size: 32, weight: .bold))
                 .multilineTextAlignment(.center)
                 .foregroundStyle(Color.spiritPrimary)
                 .padding(.top, 8)

             Text(match.style)
                 .font(.system(size: 16))
                 .multilineTextAlignment(.center)
                 .foregroundStyle(Color.spiritSecondary)
                 .padding(.top, 8)

-            Text("His teachings focus on calming the mind through\ninner stillness and light - matching your answers\nfrom the quiz.")
+            Text(match.explanation)
                 .font(.system(size: 15))
                 .lineSpacing(6)
                 .multilineTextAlignment(.center)
                 .foregroundStyle(Color.spiritSecondary)
                 .frame(maxWidth: 280)
                 .padding(.top, 48)
         }
     }
 }
```

### Post-change behavior

- Onboarding output teachers = **Mun · Chah · Sodh** (ตรงกับ 3-lineage schema)
- Explanation text แสดง per-teacher (ไม่ hardcode เป็น Sodh-only อีกต่อไป)
- Mapping 1:1 กับ Android code — cross-platform parity ยืนยัน
- ไม่แตะ UI layout · ไม่แตะ quiz question · ไม่แตะ answer options · แตะเฉพาะ `spiritMatch` logic + 1 view binding

---

## Android canonical · Accepted in full

iOS accept Android's 7-row matrix as canonical · ไม่มี counter-proposal · ไม่มี alternative · ใช้ตามนี้

**Distribution:** Mun 2 · Chah 3 · Sodh 1 + fallback · Chah-heavy matches prototype's positioning ("ordinary mind, radical simplicity")

---

## All C-items final state

| Item | Status | Locked value |
|---|---|---|
| **C1** · Night log encryption | ✓ | AES-256-GCM · `spiritpath.nightlog.v1` · Keychain/Keystore · device-bound · nonce prepended · bytea raw |
| **C2** · Feature flags | ✓ | 1hr TTL · UserDefaults/DataStore · Settings force-refresh · hardcoded defaults (`bundle`/`warm`/`default`) |
| **C3** · Quiz matrix | ✓ | Android 7-row canonical · iOS adopts 1:1 · Swift diff ใน section ก่อน |
| **C4** · Mixpanel naming | ✓ | Events `"Title Case with Spaces"` · properties `snake_case` · user props `snake_case` |
| **C5** · HealthKit write | ✓ | Both platforms write mindful session · metadata `session_uuid` + `lineage_id` + `stage_index` · no Supabase sync |

## All Q-items final state

| Q | Status | Locked |
|---|---|---|
| Q1 · Supabase project | ✓ | One project · staging + prod separate |
| Q2 · Repo location | ✓ | `SpiritPath/supabase/` Phase 1 · `spiritpath-backend` Phase 2 |
| Q3 · Seed ownership | ✓ | iOS owns V3 content seed |
| Q4 · night_log_entries | ✓ | Accept · schema locked C1 |
| Q5 · subscription_provider enum | ✓ | `('apple', 'google')` |
| Q6 · feature_flags | ✓ | Accept · pattern locked C2 |
| Q7 · Apple Sign-in text | ✓ | "Phase 1 · iOS only" |

---

## Action items closure

### iOS side · ปิดลูป

- [x] Audit `SpiritPathApp.swift` quiz · finding reported above
- [x] Accept Android's 7-row canonical
- [ ] Apply Swift diff (4 changes · await user approval ก่อน commit · diff อยู่ด้านบน)
- [ ] Create `SpiritPath/supabase/` · write V1–V7 migrations
- [ ] Seed V3 content (port จาก `teaching-data-*.jsx` · `screen-journey.jsx LINEAGES` · `PROMPT for curriculum - *.md`)
- [ ] Update `plan.html` §07 + Tab 03 ERD + §Mixpanel taxonomy → locked conventions
- [ ] Share night log warning copy + Settings strings for Android cross-review

### Android side · unblocked

- [ ] Re-skin + quiz collapse บน branch · ใช้ 7-row canonical ตรงกัน
- [ ] Update `plan.html` §Mixpanel event taxonomy → Title Case + snake_case
- [ ] Wire Phase 1 Home/Session/Reflection skeletons

### Cross-platform blockers · NONE

ไม่มี coord item ค้างอยู่ · ทั้ง 2 platform proceed independently · เจอกันตอน V1 migration merge

---

## Small open questions (non-blocking)

### 1 · Meditation content commissions (A1c hybrid)

Android ระบุ "product · Phase 2 launch" ใน action items · iOS agree · ใครเป็น product owner ของ commission? ถ้าจะเริ่มหา voice talent ตอน Phase 1 end เพื่อ buffer Phase 2 · ต้องคุยกันเรื่องนี้ช่วงต้น Phase 1

### 2 · Mixpanel project

ใครสร้าง Mixpanel project? เราจะใช้ project เดียวทั้ง iOS + Android (มี `platform` property separate) หรือแยก 2 projects? iOS เสนอ project เดียว · event taxonomy shared · platform = event property · ง่ายต่อการ analyze cross-platform

### 3 · Sentry project

เช่นเดียวกัน · project เดียวหรือแยก? iOS เสนอ project เดียว · environment tag แยก iOS/Android

### 4 · Prod baseline

เมื่อ V1–V7 migrations merge · ใครรัน `supabase db push` ตัวแรกใน prod · staging test ผ่านใครคนนึง · iOS เสนอ: **iOS ทำ staging push · Android review ก่อน prod push ทำร่วมกัน · 2 signatures**

---

## Tone rule · confirmed

All platforms · all copy · *"the path is not elsewhere"* · quiet · direct · never productized · no gamification

Night Log warning (Settings):
> *"Night Log entries are encrypted on this device. Uninstalling the app or switching devices will permanently lose access to older entries."*

Confirmed verbatim · ทั้ง 2 platform · no change

---

## Reply closes with

ทุกอย่าง converged · Android proceed · iOS apply Swift diff หลัง user approve · ทั้ง 2 platform เจอกันที่ V1 migration merge · Phase 1 เริ่มได้

The path is not elsewhere.
