# SpiritPath — Agent Context
> อ่านไฟล์นี้ก่อนทุกครั้งที่เริ่ม session ใหม่
> ครอบคลุม: iOS · Android · Supabase · Code Review · Task Tracking

---

## PROJECT IDENTITY

**App:** SpiritPath — Thai Buddhist walking meditation  
**Tagline:** "Set Out to Find Your Spirit"  
**Core practice:** เดินจงกรม (Jongkrom / Walking Meditation)  
**Cultural root:** Thai Theravada Buddhism — ห้ามทำให้เป็น westernized wellness  
**Primary language:** English (UI/copy) · Thai (internal docs เท่านั้น)  
**Backend:** Supabase · `https://udhtmvkwgrigoqvdnpjo.supabase.co`  
**Target:** 25–45 · English-speaking · beyond Calm/Headspace

### Spirit Lineages (cross-platform canonical — ห้ามเปลี่ยนโดยไม่ sync)
| id | Teacher | Style |
|----|---------|-------|
| `mun` | Luang Pu Mun Bhūridatto | Forest · Kammaṭṭhāna |
| `chah` | Luang Por Chah | Forest · Wat Pah Pong |
| `sodh` | Luang Pu Sodh Candasaro | Inner Light · Mantra ← default fallback |

---

## REPO STRUCTURE

```
iOS:     /Users/punyapath/Documents/SpiritPath/
Android: /Users/punyapath/Documents/android/
Docs:    /Users/punyapath/Documents/SpiritPath/docs/        ← sync briefs iOS↔Android
Schema:  /Users/punyapath/Documents/SpiritPath/supabase/migrations/
```

### iOS file map
```
SpiritPath/
├── App/
│   └── SpiritPathApp.swift          ← entry + onboarding (16 screens · monolithic ⚠️)
├── Core/Services/
│   └── Secrets.swift                ← API keys
├── Resources/
│   ├── Colors/Color+App.swift       ← design tokens (source of truth)
│   ├── Fonts/Typography.swift       ← AppTextStyle enum
│   ├── Theme/AppTheme.swift
│   ├── Spacing/Spacing.swift
│   ├── Radius/Radius.swift
│   └── Shadows/Shadow.swift
├── Views/Components/
│   ├── PrimaryActionButton.swift
│   ├── ChoiceButton.swift
│   └── ListActionButton.swift
└── Supabase.swift                   ← SupabaseClient singleton
```

### Android file map
```
android/app/src/main/java/com/dekphut/spiritpath/
├── MainActivity.kt
├── SpiritPathApp.kt                 ← Hilt application class
├── feature/onboarding/presentation/
│   └── SpiritPathOnboarding.kt      ← onboarding (monolithic ⚠️ · no ViewModel ⚠️)
├── ui/
│   ├── theme/                       ← AppTheme · Color · Typography · Fonts · Radius · Shadow · Spacing
│   └── components/buttons/          ← PrimaryActionButton · ChoiceButton · ListActionButton
├── core/
│   ├── data/local/entities/         ← Room entities (17 tables · mirror Supabase schema)
│   ├── data/remote/                 ← SupabaseClient · ApiService
│   ├── data/repository/             ← FeatureFlagsRepository (stub)
│   └── util/Constants.kt            ← Supabase URL · ⚠️ table name constants ผิด (ดู Known Issues)
└── di/                              ← Hilt modules
```

---

## TECH STACK

### iOS
- Swift 5.9+ · SwiftUI · iOS 16+ (minSdk 28 on Android → iOS parity target: 16+)
- Architecture: MVVM (กำลัง migrate จาก monolithic)
- Fonts: DMSerifDisplay · Manrope (variable) · JetBrainsMono — registered ใน `SpiritFonts.registerAll()`
- Dependencies: Supabase Swift SDK · (SwiftData สำหรับ local — planned)

### Android
- Kotlin · Jetpack Compose · minSdk **28** · compileSdk 36
- Architecture: Feature-based · MVVM · Hilt DI · Room · StateFlow
- Animation: `FastOutSlowInEasing` ผ่าน `tween(durationMillis)`
- Dependencies: Hilt · Room · Supabase Kotlin SDK (Postgrest · Auth · Storage · Realtime) · Compose BOM

### Supabase Schema (V1–V7 · 17 tables)
```
Domain        Tables
user_core   → profiles
practice    → sessions · reflections · journey_progress · teaching_progress
content     → lineages · stages · teaching_units · teacher_quotes · sound_tracks
              practice_window · notification_prefs
subscription→ user_subscriptions
compliance  → data_export_requests · account_deletion_requests
night_log   → night_log_entries
feature_flag→ feature_flags
```
**Migration files:** `SpiritPath/supabase/migrations/0001–0007.sql`  
**Status:** ⚠️ drafted แต่ยังไม่ push staging

---

## DESIGN TOKENS

### Colors (iOS `Color+App.swift` ← source of truth)
```swift
// Surfaces (dark navy)
appMidnight      = #050A14   // deepest bg
appSurface       = #0A1424   // app default bg
appSurfaceLow    = #111D33   // card bg
appSurfaceRaised = #152544   // raised card
appSurfaceHigh   = #1C2F54   // selected state

// Gold accent
appGold          = #F0C870   // primary
appGoldDeep      = #C49A48   // shadow/gradient end
appGoldTint      = #F7DCA0   // highlight/gradient start
appOnGold        = #0A1424   // text ON gold button

// Ink (cream on dark)
appCream         = #F4E8C8   // primary text
appInkSoft       = #F4E8C8 @ 82%   // body text
appInkMuted      = #F4E8C8 @ 58%   // captions
appInkFaint      = #F4E8C8 @ 32%   // dormant
appInkGhost      = #F4E8C8 @ 12%   // hairlines/borders

// Secondary
appRiver         = #7FB3DD   // river blue · eyebrows
appAlert         = #E8A87C
appOk            = #9EC5A6
```

### Typography (iOS `Typography.swift`)
| Style | Font | Size | Use |
|-------|------|------|-----|
| `displayXL` | DMSerifDisplay-Italic | 48 | metric numbers |
| `displayLG` | DMSerifDisplay-Regular | 34 | greeting |
| `displayMD` | DMSerifDisplay-Italic | 28 | stage titles |
| `displaySM` | DMSerifDisplay-Italic | 20 | headings |
| `serifCard` | DMSerifDisplay-Italic | 17 | teacher names |
| `title` | Manrope Bold | 22 | section titles |
| `body` | Manrope Regular | 16 | paragraph |
| `bodySmall` | Manrope Regular | 13 | subtitles |
| `label` | Manrope Medium | 14 | buttons |
| `eyebrow` | Manrope SemiBold | 10 | uppercase labels |
| `monoNumeral` | JetBrainsMono-Regular | 12 | stats/steps |

### Animation
- iOS: `.easeInOut(duration: 0.4...0.6)` — ห้าม `.spring()` สำหรับ primary transition
- Android: `tween(durationMillis = 500, easing = FastOutSlowInEasing)` — ห้าม `spring()` สำหรับ primary transition
- ต้องรู้สึก "หายใจ" — ไม่กระโดด ไม่เร็ว

---

## ARCHITECTURE RULES

### iOS
```
View (SwiftUI · dumb)
  └── @StateObject ViewModel (owns + creates)
  └── @ObservedObject ViewModel (injected)
       └── async/await (ไม่ใช่ Combine ใน code ใหม่)
            └── Repository → Supabase / SwiftData
```
- ห้าม force unwrap `!` — ใช้ `guard let` / `if let` / nil coalescing
- ทุก View ใหม่ต้องมี `#Preview`
- ใช้ `.task {}` สำหรับ async work ใน View lifecycle
- ใช้ token จาก `Color+App.swift` / `Typography.swift` / `Spacing.swift` เท่านั้น — ห้าม hardcode

### Android
```
Composable (dumb · ห้าม business logic)
  └── collectAsStateWithLifecycle() ← ใช้อันนี้เสมอ (ไม่ใช่ collectAsState())
@HiltViewModel ViewModel
  └── MutableStateFlow<UiState> (ไม่ใช่ mutableStateOf ใน ViewModel)
  └── viewModelScope + Coroutines
       └── Repository → Room (local first) → Supabase
```
- ห้าม hardcode strings — ใช้ `stringResource(R.string.*)`
- ห้าม hardcode colors — ใช้ `AppColors.*` หรือ `MaterialTheme.colorScheme`
- `LazyColumn` ต้องมี `key = { item.id }` ทุกครั้ง
- Side effects: `LaunchedEffect` สำหรับ key-dependent · `SideEffect` สำหรับ sync non-Compose
- `remember { }` ครอบ expensive computation ใน Composable body

### Shared (ทั้งสอง platform — ห้ามแตกต่าง)
1. **`computeSpiritMaster()` — 7-row canonical matrix**
   ```
   row 1+4: hasBody || hasBreath              → mun
   row 2:   experienced + (nature || silence) → chah
   row 3:   experienced + story               → chah
   row 5:   beginner + story                  → chah
   row 6a:  hasMantra                         → sodh
   row 6b:  beginner + (silence || nature)    → sodh
   row 7:   fallback                          → sodh
   ```
   iOS: `SpiritPathApp.swift` · Android: `SpiritPathOnboarding.kt` — ต้อง identical

2. **Supabase enum wire values (string ต้องตรงกัน)**
   ```
   lineage_id:   "mun" | "sodh" | "chah"
   session_type: "walking" | "quiet" | "breath" | "sound_bath"
   stage_key:    "stage_1" … "stage_5"
   ```

3. **Session UUID — client-generated เสมอ** (ไม่ใช่ server default)

4. **Offline-first data flow**
   ```
   Device → Local DB (Room/SwiftData) → sync queue → Supabase
   ```
   ห้าม write Supabase ก่อน — local first เสมอ

5. **`journey_progress.stages_entered_at` format**
   ```json
   {"1": "2026-04-22T10:00:00Z", "2": null, "3": null, "4": null, "5": null}
   ```

6. **ห้าม gamification** — ไม่มี streak counter, badge, point, leaderboard ในทั้งสอง platform

---

## KNOWN ISSUES (priority order)

### 🔴 Critical
**(ไม่มีในตอนนี้)*

### 🟠 High — แก้ใน sprint นี้

**[AND-1] Android `Color.kt` มีค่าผิด**
```
File: android/.../ui/theme/Color.kt
```
```kotlin
// ❌ ผิดทั้งหมด — ต้องแก้
AppColors.NatureGreen  = Color(0xFF000000)  // ดำ — ควรเป็น #4A7C59
AppColors.SurfaceCard  = Color(0xFF000000)  // ดำ — ควรเป็น #111D33
AppColors.TextSecondary = Color(0xFF000000) // ดำ — ควรเป็น #F4E8C8 @ 82%
// ❌ Material default stubs — ลบออก
val Purple80 = Color(0xFFD0BCFF)
val PurpleGrey80 = Color(0xFFCCC2DC)
val Pink80 = Color(0xFFEFB8C8)
```
Fix: map ค่าทั้งหมดให้ตรงกับ iOS `Color+App.swift` (source of truth)

**[AND-2] Android Onboarding ไม่มี ViewModel**
```
File: android/.../feature/onboarding/presentation/SpiritPathOnboarding.kt
```
```kotlin
// ❌ state หายเมื่อ configuration change (rotate/dark mode)
var state by remember { mutableStateOf(OnboardingState()) }
var screen by remember { mutableIntStateOf(1) }
```
Fix: สร้าง `OnboardingViewModel (@HiltViewModel)` · hold state เป็น `StateFlow<OnboardingUiState>` · Composable `collectAsStateWithLifecycle()`

**[AND-3] Android `Constants.kt` table names ผิด**
```
File: android/.../core/util/Constants.kt
```
```kotlin
// ❌ ไม่ตรงกับ Supabase schema จริง
const val TABLE_USERS   = "users"    // ควรเป็น "profiles"
const val TABLE_COURSES = "courses"  // ไม่มีใน schema
const val TABLE_LESSONS = "lessons"  // ควรเป็น "teaching_units"
const val TABLE_MASTERS = "masters"  // ควรเป็น "lineages"
const val TABLE_PATHS   = "paths"    // ควรเป็น "stages"
const val DEFAULT_TRIAL_DAYS = 14    // ❌ PaywallScreen แสดง "7 days"
```

### 🟡 Medium — backlog

**[SUP-1] Supabase migrations ยังไม่ push staging**
```
Files: SpiritPath/supabase/migrations/0001–0007.sql
```
Status: drafted ครบ · ยังไม่ได้ run บน Supabase project จริง

**[IOS-1] `SpiritPathApp.swift` monolithic (~700 lines)**
```
File: SpiritPath/SpiritPath/App/SpiritPathApp.swift
```
ทุก onboarding screen + helper + `computeSpiritMaster` อยู่ในไฟล์เดียว
Fix plan: แยกเป็น `Feature/Onboarding/` folder · OnboardingCoordinator · แต่ละ screen แยกไฟล์

**[AND-4] `SpiritPathOnboarding.kt` monolithic**
```
File: android/.../feature/onboarding/presentation/SpiritPathOnboarding.kt
```
Private token palette ประกาศ local (ไม่ใช้ `AppColors.*`) · ทุก screen ใน file เดียว
Fix plan: แยก screen + migrate สู่ `AppColors.*` · เพิ่ม ViewModel (ดู AND-2)

---

## CODE REVIEW CHECKLIST

### iOS
```
[ ] ไม่มี force unwrap (!)
[ ] ใช้ Color+App.swift tokens — ไม่ hardcode hex
[ ] ใช้ Typography.swift AppTextStyle — ไม่ hardcode font
[ ] Animation .easeInOut(duration: 0.4–0.6)
[ ] Loading / Empty / Error state ครบ
[ ] Airplane mode — ไม่ crash/freeze
[ ] #Preview มีทุก View ใหม่
[ ] accessibilityLabel ครบ · touch target ≥ 44pt
[ ] ไม่มี gamification element
[ ] @State/@StateObject/@ObservedObject ใช้ถูกประเภท
[ ] async work อยู่ใน .task{} หรือ ViewModel (ไม่ใช่ onAppear ที่ block main thread)
```

### Android
```
[ ] ไม่มี hardcoded strings (ใช้ stringResource)
[ ] ไม่มี hardcoded colors (ใช้ AppColors.*)
[ ] collectAsStateWithLifecycle() ✓ (ไม่ใช่ collectAsState())
[ ] remember { } ครอบ expensive computation
[ ] LazyColumn มี key = { item.id }
[ ] Animation tween(500, FastOutSlowInEasing)
[ ] Loading / Empty / Error state ครบ
[ ] Airplane mode — ไม่ crash/freeze
[ ] contentDescription ครบ · touch target ≥ 48dp
[ ] ไม่มี business logic ใน Composable body
[ ] ไม่มี gamification element
[ ] ViewModel state เป็น StateFlow (ไม่ใช่ mutableStateOf)
```

### Cross-platform (ทุก feature ใหม่)
```
[ ] computeSpiritMaster() identical ทั้งสองฝั่ง
[ ] Enum wire values ตรงกับ Supabase schema
[ ] sessions.id = client-generated UUID (ไม่ใช่ server)
[ ] Data flow: local DB first → sync to Supabase
[ ] Feature มี ticket ทั้ง iOS และ Android
[ ] UX flow เหมือนกัน (platform convention ต่างกันได้ แต่ flow เดิม)
```

---

## HOW TO USE THIS FILE

### เริ่ม session ใหม่
วาง prompt นี้ให้ AI อ่าน จากนั้นบอก task ที่จะทำ:
```
Read CLAUDE.md first. I'm about to [TASK]. Let's start.
```

### Code Review
```
Review this [iOS/Android] code against CLAUDE.md conventions:

[วาง code]

File: [path]
Screen/Component: [ชื่อ]
```
AI จะ check ตาม checklist ด้านบน และ flag Known Issues ที่เกี่ยวข้อง

### Sprint Planning
```
Using CLAUDE.md as context, help me plan this week's work.

Done this week:
- iOS: [list]
- Android: [list]

Goal: [sprint goal]
Capacity: iOS [X]d · Android [X]d

Prioritize against Known Issues and next Phase 1 screens.
```

### Architecture Review
```
Using CLAUDE.md as context, evaluate this approach before I code:

Feature: [ชื่อ]
Platform: [iOS/Android/Both]
Offline required: [yes/no]
Supabase tables: [list]

My plan: [อธิบาย]

Check against: offline-first flow · cross-platform parity · known issues
```

### Session Log (ปิดวัน)
```
Using CLAUDE.md as context, write a dev log entry for today:

Done: [list]
Decisions: [list]
Issues found: [list]

Format:
## [DATE] — [summary]
### Done (iOS / Android / Supabase)
### Decisions & Rationale
### Issues Found
### Cross-platform sync status
### Tomorrow #1
### Open Questions
```

---

## CURRENT STATUS (2026-04-22)

| Screen | iOS | Android |
|--------|-----|---------|
| Onboarding (16 screens) | ✅ done · monolithic | ✅ done · monolithic · no VM |
| Design tokens | ✅ Color+App · Typography · Spacing | ⚠️ done but Color.kt has wrong values |
| Button components | ✅ 3 components | ✅ 3 components (mirror iOS) |
| Supabase client | ✅ | ✅ |
| Room entities | — | ✅ 17 entities |
| Supabase migrations | ✅ V1–V7 drafted | ⚠️ not pushed to staging |
| Home screen | ❌ | ❌ |
| Walking Session screen | ❌ | ❌ |
| Reflection screen | ❌ | ❌ |
| Journey Map screen | ❌ | ❌ |
| Teachings Library | ❌ | ❌ |

**Phase 1 next:** Home screen → Walking Session → Reflection → fix Known Issues AND-1/AND-2/AND-3 + push Supabase staging
