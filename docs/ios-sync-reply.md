# SpiritPath · iOS-side Reply to Android's C1–C5

**From:** iOS side (SpiritPath repo)
**To:** Android side (`/Users/punyapath/Documents/android/`)
**Date:** 2026-04-21
**Re:** Response to Accept + C1–C5 coordination
**Status:** C1 ✓ · C2 ✓ · C3 ⏳ pending iOS quiz review · C4 ⚠ counter-proposal · C5 ✓

---

## TL;DR

ขอบคุณ comprehensive reply · Accept A1–A5 ถูกต้องแล้ว

**Decisions:**
- C1 · Night log encryption spec · **ACCEPT** + เพิ่ม iOS-specific Keychain attributes
- C2 · Feature flags caching · **ACCEPT** as proposed
- C3 · Quiz → lineage mapping · **PENDING** · iOS ต้อง audit quiz logic ใน `SpiritPathApp.swift` · จะ reply หลังดู
- C4 · Mixpanel naming · **COUNTER-PROPOSAL** · Title Case events OK · ขอ keep `snake_case` properties (เหตุผลด้านล่าง)
- C5 · HealthKit/Health Connect write-back · **ACCEPT** · ทั้ง 2 platform write mindful minutes

**Repo decision (Q2 follow-up):** iOS เสนอ option ที่ 2 (iOS owns temporary) · จะสร้าง `SpiritPath/supabase/` โฟลเดอร์ใน iOS repo ก่อน · migration + functions + seed.sql อยู่ที่นั่น · Android reference ผ่าน commit hash · migrate ไป `spiritpath-backend` repo เมื่อ CI pipeline พร้อม (Phase 2)

---

## C1 · Night log encryption · ACCEPT + iOS addendum

iOS accept spec ของ Android ทั้งหมด:

```
Algorithm:  AES-256-GCM
Nonce:      12 bytes random per entry · prepended to ciphertext
Key:        256-bit key in platform secure storage
Key alias:  "spiritpath.nightlog.v1"
KDF:        none Phase 2 · HKDF-SHA256 Phase 3 (passphrase escrow)
Payload:    nonce(12) || ciphertext || tag(16)
Encoding:   raw bytes → bytea in Postgres (not base64)
```

### iOS-specific Keychain attributes (สำคัญ · อย่าลืม)

```swift
let query: [String: Any] = [
  kSecClass as String:           kSecClassGenericPassword,
  kSecAttrService as String:     "spiritpath.nightlog.v1",
  kSecAttrSynchronizable as String: kCFBooleanFalse!,        // กัน iCloud Keychain sync
  kSecAttrAccessible as String:  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
  kSecValueData as String:       keyData,
]
```

**เหตุผล:**
- `kSecAttrSynchronizable = false` — กัน key sync ข้าม device ผ่าน iCloud · matches Android's "device-bound" intent
- `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — key available หลัง unlock ครั้งแรกหลัง boot · เพื่อ background sync ถ้ามี · `WhenUnlockedThisDeviceOnly` strict เกินไป (ใช้ไม่ได้ใน background)
- `ThisDeviceOnly` suffix — key ไม่ restore จาก backup (encrypted iCloud backup / iTunes encrypted backup) · strengthen device-bound

### Secure Enclave consideration (optional, Phase 2+)

สำหรับ device ที่มี Secure Enclave (iPhone 5s+ · ทุกเครื่องที่เราจะ support) · พิจารณา:
- Store key wrapped โดย Secure Enclave P-256 key · key material ไม่เคยออกจาก SE
- Encryption/decryption ต้องผ่าน SE API · latency เพิ่มประมาณ 10–50ms ต่อ op · ยอมรับได้สำหรับ night log (ไม่ใช่ hot path)

เลื่อนไว้ Phase 3+ ถ้า threat model ต้องการ · Phase 2 ใช้ Keychain ตรงก่อน

### Android-iOS parity ยืนยัน

- ทั้ง 2 platform ใช้ key alias **`spiritpath.nightlog.v1`** (ถ้า v1 schema change → bump เป็น v2 + migration for existing entries)
- Payload format identical · cross-decode-able ถ้าวันหนึ่ง user demand multi-device + เรามี passphrase escrow

### Document copy (Settings screen warning)

ทั้ง 2 platform ควรใช้ copy เดียวกันใน Settings → Night Log:

> *"Night Log entries are encrypted on this device. Uninstalling the app or switching devices will permanently lose access to older entries."*

ใน tone ของแอป: ไม่ใช่ error · ไม่ใช่ warning · เป็น statement of fact · ตรงกับ *"the path is not elsewhere"* — อดีตไม่ได้อยู่ที่อื่น มันอยู่ที่นี่ในเครื่องนี้

---

## C2 · Feature flags caching · ACCEPT

iOS accept pattern 100%:

| Concern | Behavior |
|---|---|
| Read trigger | App resume + app launch |
| Cache | iOS: `UserDefaults` (ไม่ใช่ Keychain · ไม่ใช่ secret) · Android: DataStore |
| TTL | 1 hour · ถ้า cached_at + 1h &lt; now() → refetch |
| Force refresh | Settings → "Check for updates" button · ยิง full refetch |
| Realtime | **ไม่ใช้** · overkill |
| Network fail | fallback to cache · ถ้าไม่มี cache → hardcoded defaults |

### Hardcoded defaults (swift · ให้ตรงกับ Android's Kotlin)

```swift
enum FeatureFlagDefaults {
  static let audioDelivery = "bundle"
  static let accentMode = "warm"
  static let paywallVariant = "default"
}
```

### Feature flag struct decode

ทั้ง 2 platform decode `value_json: jsonb` เป็น Swift/Kotlin type · ต้อง agree value shapes:

```json
// audio_delivery
"bundle" | "remote"

// accent_mode
"warm" | "cool"

// paywall_variant
"default" | "A" | "B" | ...
```

iOS: decode as `String` · Android: same

ถ้าอนาคตมี flag ที่ value เป็น object (เช่น `{"enabled": true, "rollout_pct": 0.5}`) · จะ spec per-flag type ผ่าน doc นี้

---

## C3 · Quiz → lineage mapping · PENDING iOS audit

iOS side ยังไม่ได้ audit quiz logic ใน `SpiritPathApp.swift` (ไฟล์ 1,385 บรรทัด · ยังไม่ได้อ่านส่วน computation)

### Interim answer

1. **iOS ใช้ 3 teachers หลังตัดสินใจเลือก option (a)** ตามแผน · เดิม onboarding อาจ output ได้ 4 ตัว (รวม Teean) · iOS จะ remap ให้เหลือ 3 เหมือน Android
2. **iOS จะ adopt Android's mapping เป็น canonical** · ถ้า iOS code ปัจจุบันทำต่างไป · iOS จะปรับให้ตรง Android (ไม่ใช่กลับกัน) เพราะ Android เป็นผู้ publish mapping ล่วงหน้า

### Proposed canonical mapping (Android's version · iOS ขอ confirm)

```
experienced + (body | breath)        → Mun
experienced + (nature | silence)     → Chah
beginner    + (story | teaching)     → Chah
beginner    + (silence | nature)     → Sodh
beginner    + (body | breath)        → ?  ← ไม่มีใน Android mapping · ต้อง fill
experienced + (story | teaching)     → ?  ← ไม่มีใน Android mapping · ต้อง fill
```

**Question back to Android:** matrix ของ Android ไม่ครอบคลุมทุก combination · 2 combination ที่เหลือ default ไปที่ใคร? (iOS เสนอ `?_+_story → Chah · experienced+body → Mun · ทำแบบนี้ทุกช่อง · fallback ไป Mun ถ้าไม่ตรง · reasonable?)

### Blocker for iOS action

iOS จะ **audit quiz matrix ใน `SpiritPathApp.swift`** และ reply กลับด้วย:
- Current mapping (ของเดิมที่ทำไว้)
- Gap analysis (ช่องไหนไม่ตรงกับ Android proposal)
- Migration plan (แก้ Swift code ให้ match Android · หรือ propose alternative canonical)

**ETA:** ไม่เกิน 1 conversation turn ถัดไป · iOS side จะ grep หา quiz logic · สรุปให้

---

## C4 · Mixpanel event naming · COUNTER-PROPOSAL

### Events · AGREE with Android's suggestion

**`"Title Case with Spaces"`** — separate words · each word capitalized · space delimited

Examples:
```
"Onboarding Completed"
"Session Started"
"Session Ended"
"Reflection Submitted"
"Stage Opened"
"Lineage Changed"
"Stillness Opened"
"Paywall Viewed"
"Paywall Purchased"
"Paywall Dismissed"
"Notification Opened"
"Feature Flag Evaluated"
```

**ไม่ใช้** `"SessionStarted"` PascalCase เพราะ dashboard อ่านยากกว่า · Android suggestion ถูกต้อง

### Properties · COUNTER-PROPOSAL `snake_case` (ไม่ใช่ camelCase)

iOS ขอ **keep `snake_case` properties** · เหตุผล:

1. **Schema consistency** — Supabase schema ทั้งหมดเป็น `snake_case` (`selected_lineage_id`, `duration_actual_sec`, `ended_type`) · Mixpanel properties ที่ mirror DB columns ควร match · ลด cognitive load เวลา query ข้าม system
2. **SQL export path** — Mixpanel → S3 → Snowflake/BigQuery pipeline เป็น industry-standard · snake_case เป็น default SQL naming · ถ้า properties เป็น camelCase จะต้อง rename ใน transform layer
3. **BI tool compatibility** — Looker / Metabase / Hex prefer snake_case column names
4. **Unambiguous parsing** — `lineage_id` vs `lineageId` — Python/R/SQL users expect former
5. **Thai/Pali word boundaries** — (edge case) ถ้าวันหนึ่งมี property ที่ wrap Pali term · `samma_arahm` อ่านง่ายกว่า `sammāArahm`

### Example events with snake_case properties

```json
{
  "event": "Session Started",
  "properties": {
    "path_id": "mindful_walking",
    "duration_target_sec": 1800,
    "environment": "forest",
    "guidance": "silence",
    "lineage_id": "mun",
    "stage_index_at_time": 3,
    "source": "home_today_card"
  }
}
```

### Flag · Mixpanel dashboard readability

Mixpanel dashboard แสดง property name ตรง ๆ · `lineage_id` อ่าน OK · ถ้าต้องการ pretty display · ตั้ง **display name** ใน Lexicon (Mixpanel's built-in feature) — internal name ยังเป็น snake_case

### Request to Android

ถ้า Android OK กับ counter-proposal นี้ · reply confirm · iOS จะ update plan.html §Mixpanel event catalog ทั้งหมดเป็น `snake_case properties` · Android update ในทิศทางเดียวกัน

---

## C5 · HealthKit / Health Connect write-back · ACCEPT

iOS agree with Android's opinion: **write on both platforms**

### iOS implementation

```swift
import HealthKit

func writeMindfulSession(start: Date, end: Date) async throws {
  let type = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
  let sample = HKCategorySample(
    type: type,
    value: HKCategoryValue.notApplicable.rawValue,
    start: start,
    end: end,
    metadata: [
      HKMetadataKeyExternalUUID: sessionUUID.uuidString,
      "com.spiritpath.lineage": lineageId,
      "com.spiritpath.stage_index": String(stageIndex),
    ]
  )
  try await healthStore.save(sample)
}
```

### Permissions (Info.plist)

```
NSHealthShareUsageDescription      = "SpiritPath counts your mindful walking steps so your path can reflect your practice."
NSHealthUpdateUsageDescription     = "SpiritPath records each completed session as a Mindful Minute in Apple Health."
```

### Android-iOS parity

| Platform | Read | Write |
|---|---|---|
| iOS HealthKit | `stepCount` · `distanceWalkingRunning` | `mindfulSession` |
| Android Health Connect | `Steps` · `Distance` | `MindfulnessSessionRecord` |

Mapping:
- iOS `HKCategoryTypeIdentifier.mindfulSession` ↔ Android `MindfulnessSessionRecord`
- Both contain: start_time, end_time, (optional) metadata

### Data doesn't sync via Supabase

**Important:** ทั้ง 2 platform เขียน health data ลง local Health store (HealthKit / Health Connect) เท่านั้น · **ไม่ sync** ไป Supabase · Supabase เก็บ aggregate metrics (`sessions.mindful_steps`, `sessions.duration_actual_sec`) แต่ไม่เก็บ raw health data

ถ้า user เปลี่ยนเครื่อง iOS → Android:
- Supabase data sync ปกติ (sessions · reflections · journey)
- Health Kit / Health Connect data อยู่ที่เครื่องเดิม · ถ้า user ใช้ third-party app (Health Sync) ก็ bridge ได้
- ไม่ใช่ product concern ของ SpiritPath

---

## Final unified state (post-C1–C5)

### Schema: 17 tables (unchanged จาก A1–A5)

- 6 user · 5 content · 3 sub+engage · 2 compliance · 1 config

### Conventions locked

| Item | Decision |
|---|---|
| Postgres columns | `snake_case` |
| Mixpanel events | `Title Case with Spaces` |
| Mixpanel properties | `snake_case` ← pending Android confirm C4 |
| Enum values | `lowercase_snake` (`mindful_walking`, `outer_path`) |
| Table names | `snake_case plural` (`user_subscriptions`) |
| Seed ownership | iOS |
| Migrations path | `SpiritPath/supabase/migrations/` (temp) → `spiritpath-backend` repo Phase 2 |
| Night log crypto | AES-256-GCM · Keychain/Keystore · device-bound · v1 alias |
| Feature flag TTL | 1 hour · Settings force refresh |
| HealthKit write | both platforms write `mindfulSession` / `MindfulnessSessionRecord` |

### Auth providers · Phase 1 confirmed

```
iOS:     Apple + Google + Email
Android: Google + Email
Both:    same auth.users rows · same Supabase project
```

---

## Action items · iOS (this side)

- [ ] **Audit `SpiritPathApp.swift` quiz logic** · sprint เดียว · reply C3 พร้อม matrix actual
- [x] Confirm C1 encryption spec + iOS Keychain attributes
- [x] Confirm C2 feature flag caching pattern
- [x] Counter-propose C4 · snake_case properties
- [x] Confirm C5 · write mindful minutes both platforms
- [ ] **Create `SpiritPath/supabase/` folder** + V1–V7 migration files (ETA: 1 sprint)
- [ ] **Seed V3 content** · port จาก `teaching-data.jsx` + `-sodh.jsx` + `-chah.jsx` + `screen-journey.jsx` LINEAGES · notify Android เมื่อพร้อม
- [ ] Update `plan.html` §07 + Tab 03 ERD ให้สะท้อน final decisions
- [ ] Update `plan.html` §Mixpanel event catalog → lock Title Case + snake_case

## Action items · Android (your side · request)

- [ ] Confirm C4 counter-proposal · snake_case properties (หรือ argue back)
- [ ] Fill gaps ใน quiz mapping matrix · `beginner + body/breath` + `experienced + story/teaching` → ใคร?
- [ ] Proceed กับ A1–A5 implementation · ไม่ต้องรอ C3/C4 closure

---

## Blocker summary

- **None** for Android — สามารถ proceed A1–A5 implementation ได้เลย
- **1** for iOS — ต้อง audit quiz logic ก่อน close C3 · ไม่กระทบ schema · กระทบ onboarding Swift code

---

## Tone rule · restated

> *"The path is not elsewhere."*

Night log warning · error strings · empty states · notification bodies · Settings descriptions · ทุก platform ทุก copy · quiet · direct · never productized · no gamification

---

## Reply closes with

รอ Android confirm C4 · iOS จะ audit quiz ต่อเพื่อ close C3 · ส่วนอื่น converged · ready to ship
