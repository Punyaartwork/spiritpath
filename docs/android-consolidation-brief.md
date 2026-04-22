# SpiritPath · Android Consolidation Brief

**Paste ข้อความข้างล่าง (ทั้ง section "## Brief for Android Claude") ให้ Android Claude session**

---

## Brief for Android Claude

### TL;DR

User ได้ consolidate planning docs ระหว่าง iOS + Android เป็น **master plan เดียว** · อยู่ที่ iOS repo · ทั้ง 2 platform ยึดเป็น single source of truth

### What changed · 2026-04-21

1. **`android/docs/plan.html` ถูก archive** → ย้ายไป `android/docs/.archive/plan.html.pre-master-2026-04-21` · เลิกใช้
2. **Master plan** อยู่ที่ `/Users/punyapath/Documents/codereview/plan.html` (iOS repo) · Phase 2 จะย้ายไป `spiritpath-backend` repo dedicated
3. **New pointer file**: `android/docs/master-plan-ref.md` · ใช้เป็น entry point ทุก session
4. **Tab 04 · Sync protocol** เพิ่มใน master plan · archive ของ coordination rounds ทั้งหมด (A1–A5 · C1–C5 · Q1–Q7)
5. **Conventions locked** · Mixpanel naming · quiz matrix · night log crypto spec · feature flags behavior · HealthKit policy · ทั้งหมดอยู่ใน Tab 04 · Locked items reference

### What you need to do now

**1 · อ่าน pointer file ก่อน:**
```
Read android/docs/master-plan-ref.md
```

**2 · อ่าน master plan:**
```
Read /Users/punyapath/Documents/codereview/plan.html
(หรือเปิดใน browser: file:///Users/punyapath/Documents/codereview/plan.html)
```

**3 · Focus 3 tabs หลัก:**
- **Tab 01 · Plan** · architecture · design system · phases
- **Tab 02 · Actions** · หา row ที่ owner = `Android` หรือ `both`
- **Tab 04 · Sync protocol** · ประวัติ decision · locked items reference

**4 · Ignore เดิม:**
- `android/docs/plan.html` · archived · ไม่ใช้
- `android/docs/dashboard.html` · historical · superseded by master Tab 02
- `android/docs/supabase-architecture.html` · historical · superseded by master §07

### What stays in Android repo (ยังใช้)

- `app/` · Kotlin Compose source code
- `docs/onboarding-reskin*.html` · Android UI re-skin spec (Android-specific task)
- `docs/supabase-android-reply*.md` · historical sync responses (wave 1 archive · referenced from master Tab 04)
- `docs/master-plan-ref.md` · pointer to iOS master (new · created 2026-04-21)

### Locked items · wave 1 (2026-04-21)

ทั้งหมดอยู่ใน master Tab 04 · สรุปสั้น ๆ:

**Architecture (A1–A5):**
- 17 tables · 5 domains · 3 buckets · 8 edge functions
- Added: `night_log_entries` · `feature_flags`
- `subscription_provider` enum `('apple', 'google')`

**Coordination (C1–C5):**
- **C1** Night log crypto · AES-256-GCM · key alias `spiritpath.nightlog.v1`
- **C2** Feature flags · 1hr TTL · hardcoded defaults · no Realtime
- **C3** Quiz matrix · 7-row canonical · Mun 2 · Chah 3 · Sodh 1 + fallback
- **C4** Mixpanel · events `"Title Case with Spaces"` · properties `snake_case`
- **C5** HealthKit/Health Connect · both write mindful session · not synced via Supabase

**Questions (Q1–Q7):**
- Q1 · one Supabase project (staging + prod)
- Q2 · Phase 1 `SpiritPath/supabase/` · Phase 2 dedicated repo
- Q3 · iOS owns V3 content seed
- Q4–Q7 · see Tab 04

### Immediate Android tasks (จาก master Tab 02)

1. **Quiz matrix swap** · ใช้ 7-row canonical · <ins>Android กำลังทำบน branch `codex/onboarding-dark-reskin` อยู่แล้ว</ins>
2. **Mixpanel event taxonomy** · rewrite ใน Android doc ให้ตรง Title Case + snake_case
3. **Phase 1 skeletons** · Home · Session · Reflection viewmodels
4. **Night log encryption client** · wait for V6 migration to land · implement Phase 2
5. **Feature flags repository** · implement cache + 1hr TTL · wire after V7

### Sync protocol กฎ

ถ้าต้องการเปลี่ยน decision ใหญ่ (schema · convention · tone policy) ที่กระทบ iOS ด้วย:

1. เขียน prompt ตาม template ใน master Tab 04 · "Template · เปิด sync round ใหม่"
2. Save file ใน `android/docs/` · ชื่อ <code>android-sync-&lt;topic&gt;.md</code>
3. User paste มา iOS side · iOS Claude reply
4. Converge · iOS update master plan · Android adopt

**ไม่ต้องเปิด round สำหรับ:** Android UI tweaks · Kotlin-specific refactors · Android-only capabilities · Thai translation

### Key file paths reference

| Path | Purpose |
|---|---|
| `/Users/punyapath/Documents/codereview/plan.html` | iOS master plan · canonical |
| `/Users/punyapath/Documents/android/docs/master-plan-ref.md` | Android pointer · session entry |
| `/Users/punyapath/Documents/SpiritPath/docs/android-sync-prompt.md` | Round 1 · initial architecture proposal |
| `/Users/punyapath/Documents/SpiritPath/docs/ios-sync-reply.md` | Round 3 · C1/C2/C5 accept · C4 counter |
| `/Users/punyapath/Documents/SpiritPath/docs/ios-sync-reply-2.md` | Round 5 · C3 closure · all locked |
| `/Users/punyapath/Documents/android/docs/supabase-android-reply*.md` | Android wave-1 replies (Rounds 2 + 4) |
| `/Users/punyapath/Documents/SpiritPath/supabase/` | Migration files · Phase 1 (ยังไม่มี · iOS จะสร้าง) |

### Master plan URL · deep links

- `file:///Users/punyapath/Documents/codereview/plan.html` · default Tab 01
- `file:///Users/punyapath/Documents/codereview/plan.html#actions` · owner-based tasks
- `file:///Users/punyapath/Documents/codereview/plan.html#flow` · system diagrams
- `file:///Users/punyapath/Documents/codereview/plan.html#sync` · coordination log

### Tone rule (applies to all strings · Android Compose included)

> *"The path is not elsewhere."*

Quiet · direct · never productized · no gamification · Thai/Pali terms with translation on first occurrence per screen

### Acknowledge + proceed

หลังอ่าน master plan แล้ว · reply confirm:
- ✓ Read master plan
- ✓ อ่าน locked items (A1–A5 · C1–C5 · Q1–Q7) เข้าใจ
- งาน Android ต่อไปคือ: (list 1–2 items ที่จะทำต่อ)

ถ้ามีข้อสงสัยเกี่ยวกับ locked items · เปิด sync round ใหม่ได้เลย · อย่าเดาเอง

---

## End of brief
