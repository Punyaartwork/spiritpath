# SpiritPath · Android Sync · Unified Supabase Architecture

**From:** iOS side (SpiritPath repo) · **To:** Android side (`/Users/punyapath/Documents/android/`)
**Date:** 2026-04-21
**Status:** Proposal · requires Android-side review and reply

---

## TL;DR

iOS ได้ตรวจ `docs/supabase-architecture.html` ฉบับ Android แล้ว · <ins>ดีมาก · adopt หลัก ๆ เกือบทั้งหมด</ins> · จะเขียน iOS architecture ให้ตรงกัน 100% · แต่มี **5 การแก้ที่ต้องทำฝั่ง Android** เพื่อให้ schema รองรับทั้ง 2 platform · และ **5 ข้อ adopt จาก Android มา iOS** (ไม่ต้องทำอะไร · แค่แจ้งไว้)

Supabase project คาดว่าใช้ **ตัวเดียวกันทั้ง 2 platform** — schema ต้อง identical — platform-specific code อยู่ใน adapter layer (Room + ExoPlayer + Health Connect บน Android, SwiftData + AVFoundation + HealthKit บน iOS)

---

## Context (สำหรับ Android Claude ที่ไม่ได้อ่านประวัติ)

- **App:** SpiritPath · Thai forest-tradition meditation app (Mun · Sodh · Chah)
- **Target:** English-speaking meditators in US · en-US · USD · us-east-1
- **Positioning:** serious meditators (not beginners) · 3 lineages × 5 stages
- **Paywall:** screen 19 ใน onboarding · 7-day free trial · annual subscription
- **Analytics:** Mixpanel · Title Case events · ไม่มี ATT
- **Backend:** Supabase (us-east-1) · Postgres 15 · RLS-first

---

## 5 แก้ที่ต้องทำ **ฝั่ง Android**

### A1 · เพิ่ม `night_log_entries` table

Prototype มี Stillness → NightLog screen (ดู `src/screen-stillness-subs.jsx` ของ web prototype) · before-sleep reflection · ไฟล์ Android ตอนนี้ไม่มี table นี้

```sql
create table public.night_log_entries (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  logged_at       timestamptz not null,
  body_ciphertext bytea,        -- encrypted on device · Keystore (Android) / Keychain (iOS)
  mood            text,
  created_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

alter table public.night_log_entries enable row level security;
-- Pattern A (user owns rows) policies
create policy "users_select_own" on public.night_log_entries
  for select using (auth.uid() = user_id and deleted_at is null);
create policy "users_insert_own" on public.night_log_entries
  for insert with check (auth.uid() = user_id);
create policy "users_update_own" on public.night_log_entries
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index idx_night_log_user_time on public.night_log_entries(user_id, logged_at desc)
  where deleted_at is null;
```

Body เข้ารหัสใน device — server เก็บ `bytea` opaque — Key derive จาก Keystore (Android) หรือ Keychain (iOS)

### A2 · เปลี่ยน `user_subscriptions.provider` เป็น enum

ไฟล์เดิมเขียน `provider text · 'google_play'` — ต้องเปิดรับ Apple ด้วย เพราะ iOS ใช้ StoreKit 2

```sql
create type subscription_provider as enum ('apple', 'google');

alter table user_subscriptions
  alter column provider type subscription_provider
  using provider::subscription_provider;
```

### A3 · เพิ่ม `feature_flags` table

iOS ใช้ Mixpanel Experiments เป็นหลัก · แต่บาง flag ต้อง query จาก Postgres (เช่น `audio_delivery: bundle|remote` เพื่อ switch จาก app-bundled → Supabase Storage CDN โดยไม่ปล่อย version ใหม่)

```sql
create table public.feature_flags (
  key         text primary key,
  value_json  jsonb not null,
  description text,
  updated_at  timestamptz not null default now()
);

alter table public.feature_flags enable row level security;
create policy "authenticated_read" on public.feature_flags
  for select using (auth.role() = 'authenticated');
-- no write policy · service_role only

-- seed
insert into public.feature_flags (key, value_json, description) values
  ('audio_delivery',   '"bundle"'::jsonb, 'bundle | remote'),
  ('accent_mode',      '"warm"'::jsonb,   'warm | cool'),
  ('paywall_variant',  '"default"'::jsonb, 'A/B variant key');
```

### A4 · ปรับ Apple Sign-in row ในตาราง auth providers

ไฟล์เดิมเขียน *"Only useful ถ้าจะทำ iOS version"* / *"N/A Android"* — <ins>iOS implement แน่นอน</ins> · แก้เป็น

```
| Apple Sign-in | Phase 1 · iOS only       | Apple Services ID · private-email-relay · iOS client config |
| Google OAuth  | Phase 1 · both platforms |                                                            |
| Email magic   | Phase 1 · both platforms |                                                            |
| Phone OTP     | Phase 2 · both platforms |                                                            |
```

User ที่ sign in ด้วย Apple บน iOS จะใช้ Supabase user ID เดียวกันได้บน Android เมื่อ sign in ด้วย email ที่ Apple private relay สร้าง · <em>หรือ</em> ด้วย Google OAuth ที่ใช้ email ปกติ

### A5 · แก้ header "11 tables"

Header HTML เขียน `11 tables · 6 domains · 2 storage buckets · 3 edge functions` · นับจริงในเอกสาร = **15 tables · 5 domains · 3 buckets · 6 edge functions** · หลังเพิ่ม A1 + A3 แล้วจะเป็น **17 tables · 5 domains · 3 buckets · 6 edge functions**

---

## 5 ข้อที่ iOS จะ **adopt จาก Android** (ไม่ต้องทำอะไรฝั่ง Android · แจ้งให้รู้)

| # | ไอเดียจาก Android | iOS จะเอามาใช้ |
|---|---|---|
| B1 | Soft delete ด้วย `deleted_at` ทุก user-data table | ✓ adopt · แทน hard delete |
| B2 | Subscription gate ใน RLS (Pattern C) · Stage 1 free / 2–5 paid | ✓ adopt |
| B3 | Offline sync fields ใน sessions (`client_created_at`, `synced_at`) | ✓ adopt · iOS Core Data queue → Supabase |
| B4 | Content normalized เป็น 4 tables: `lineages · stages · teaching_units · teacher_quotes` (ไม่ใช่ 1 big teachings) | ✓ adopt · ของ iOS เดิมเป็น 1 table · เปลี่ยน |
| B5 | Compliance tables: `data_export_requests` · `account_deletion_requests` | ✓ adopt · แทน fire-and-forget edge function |

---

## Final unified schema summary · 17 tables

### User domain (6)
`profiles` · `sessions` · `reflections` · `journey_progress` · `teaching_progress` · **`night_log_entries`** (ใหม่)

### Content domain (5)
`lineages` · `stages` · `teaching_units` · `teacher_quotes` · `sound_tracks`

### Subscription + Engagement (3)
`user_subscriptions` (+enum `apple|google`) · `notification_prefs` · `practice_window`

### Compliance (2)
`data_export_requests` · `account_deletion_requests`

### Config (1)
**`feature_flags`** (ใหม่)

---

## Platform adapter layer · ของต่างกันได้ (ไม่กระทบ schema)

| Concern | iOS | Android |
|---|---|---|
| Local storage | SwiftData / Core Data | Room |
| Audio | AVFoundation | ExoPlayer (Media3) |
| Health | HealthKit · mindful minutes write-back | Health Connect · optional |
| Notifications | UNUserNotificationCenter + schedule | WorkManager + NotificationCompat |
| Subscription SDK | StoreKit 2 หรือ RevenueCat | Google Play Billing v6 |
| Encryption key | Keychain-derived | Android Keystore |
| Auth providers Phase 1 | Apple + Google + Email | Google + Email |
| Deep link | Universal Links | App Links |

---

## Edge functions · matrix ต่อ platform

| Function | Called by | Platform |
|---|---|---|
| `verify-apple-receipt` | iOS client หลัง purchase | iOS only |
| `handle-apple-notif` | Apple Subscription Notifications v2 webhook | iOS only |
| `verify-play-purchase` | Android client หลัง purchase | Android only |
| `handle-play-webhook` | Google Pub/Sub | Android only |
| `generate-weekly-reflection` | pg_cron Sundays 8pm local | both |
| `process-data-export` | `data_export_requests` insert | both |
| `process-account-deletion` | pg_cron daily | both |
| `sync-journey-progress` | DB trigger on `sessions.completed` | both (DB-side) |

= **8 edge functions** total · 2 iOS-only · 2 Android-only · 4 shared

---

## Migration order (ทั้ง 2 platform ใช้ migration เดียวกัน)

Android's existing 5-migration plan + additions:

1. **Core user domain + auth trigger** — `profiles` + auto-create trigger + `updated_at` trigger
2. **Practice domain** — `sessions` (w/ soft-delete + sync fields) · `reflections` · `journey_progress` · `teaching_progress` · RLS Pattern A + indexes
3. **Content domain + seed** — `lineages` · `stages` · `teaching_units` · `teacher_quotes` · `sound_tracks` · seed 3 lineages × 5 stages + sound_tracks placeholder · RLS Pattern B
4. **Subscription + engagement** — `user_subscriptions` (+enum provider) · `notification_prefs` · `practice_window` · RLS Pattern A + Pattern C (subscription gate)
5. **Compliance** — `data_export_requests` · `account_deletion_requests` + RLS + edge function hooks
6. **New · night log** — `night_log_entries` + RLS Pattern A
7. **New · config** — `feature_flags` + RLS (authenticated read) + seed 3 flags

---

## If Android side pushes back

ถ้าไม่ agree กับบาง decision · reply กลับมา · iOS side พร้อมปรับ · เป้าหมายคือ schema identical 100% ไม่มี fork

ประเด็นที่อาจโต้แย้ง:

- **night_log_entries** — ถ้ายังไม่ถึง Phase 2 ของ Android · ยัง skip ได้ · แต่ schema ต้องมีไว้ก่อน (iOS ต้องการ Phase 2)
- **feature_flags** — ถ้า Android ใช้ Firebase Remote Config แทน · เหลือแค่ iOS ใช้ table นี้ · แต่ไม่ควรมี fork
- **subscription_provider enum** — <em>ไม่มีทางเลี่ยง</em> · ต้องเพิ่ม 'apple' ใน type เพราะ iOS จะ purchase ผ่าน StoreKit

---

## Deliverable ที่ iOS จะทำให้หลังได้ reply

1. `docs/plan.html §07 Backend` rewrite เป็น unified 17-table architecture
2. `docs/plan.html Tab 03 · ERD` ปรับเป็น 17 tables
3. Migration files ร่วมกัน · commit ใน Supabase CLI repo ที่ใช้ร่วมกัน (ใครเป็นเจ้าของ supabase/migrations โฟลเดอร์?)
4. iOS client จะ query/mutate ผ่าน unified schema · Android ทำเช่นเดียวกัน

---

## คำถามที่ iOS side ต้องการคำตอบ

1. **Supabase project:** ใช้ project เดียวกันทั้ง 2 platform จริงมั้ย? (URL + anon key ร่วมกัน)
2. **Migration repo:** ใครเก็บ `supabase/migrations/*.sql`? iOS repo, Android repo, หรือ repo กลาง?
3. **Seed data ownership:** ใครจะเขียน seed สำหรับ `lineages` · `stages` · `teaching_units` · `teacher_quotes`? (แนะนำ iOS side เพราะมี prototype content อยู่แล้ว)
4. **A1 night_log_entries:** OK เพิ่มมั้ย หรือขอเลื่อน?
5. **A2 subscription_provider enum:** OK เปลี่ยนมั้ย (จำเป็นถ้า iOS ship)
6. **A3 feature_flags:** OK เพิ่มมั้ย หรือใช้ Firebase Remote Config?
7. **A4 Apple Sign-in:** OK เปลี่ยน "N/A" เป็น "iOS only" มั้ย?

---

## Tone rule (สำคัญ · ตรงกับที่ prototype วางไว้)

> *"The path is not elsewhere."*

- ไม่มี gamification copy
- ไม่มี streaks-are-great · on-fire · keep-it-up
- Thai/Pali terms OK แต่ต้องมีคำแปลเมื่อเจอครั้งแรก
- quiet · direct · never productized

ใช้ tone นี้กับ error messages · notification body · empty states · ทุก string ที่ user เห็น
