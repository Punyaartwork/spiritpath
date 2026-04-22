# SpiritPath · V5 + V6 + V7 Batch Review Brief · paste-ready

**Paste section "## Brief for Android Claude · V5+V6+V7 review" ให้ Android session**

---

## Brief for Android Claude · V5+V6+V7 review

### TL;DR · 3 migrations · V1-V7 complete · all 17 tables shipped

iOS drafted **V5 (compliance) + V6 (night_log) + V7 (feature_flags)** in one batch · closes out all 17-table schema · ~244 SQL lines total across 3 files

**Files:**
- `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0005_compliance.sql` · 111 lines
- `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0006_night_log.sql` · 69 lines
- `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0007_feature_flags.sql` · 64 lines

**Total coverage post-batch:** V1 + V2 + V3 + V4 + V5 + V6 + V7 = 7 migrations · ~1,190 SQL lines · 17 tables · 5 domains

---

## V5 · Compliance (CCPA + GDPR)

### Tables (2)

**`data_export_requests`** · "right to know"
```
id                uuid PK default gen_random_uuid()
user_id           uuid FK profiles cascade
requested_at      timestamptz default now()
status            compliance_request_status default 'pending'
ready_url         text       (set by edge function · presigned URL · 7-day TTL)
completed_at     timestamptz (set by edge function)
```

**`account_deletion_requests`** · "right to delete"
```
id                uuid PK default gen_random_uuid()
user_id           uuid FK profiles cascade
requested_at      timestamptz default now()
scheduled_for     timestamptz NOT NULL  (set by trigger · requested_at + 30 days)
status            compliance_request_status default 'pending'
reason            text  (optional user-submitted)
processed_at      timestamptz
```

### Trigger · `schedule_deletion_grace`

```sql
create or replace function public.schedule_deletion_grace()
returns trigger language plpgsql as $$
begin
  new.scheduled_for := new.requested_at + interval '30 days';
  return new;
end;
$$;

create trigger tr_deletion_grace
  before insert on public.account_deletion_requests
  for each row execute function public.schedule_deletion_grace();
```

30-day grace window · user can cancel during grace via UPDATE status='cancelled' (RLS allows this specific transition)

### RLS Pattern A · SELECT + INSERT only (with 1 UPDATE exception)

- `data_export_requests` · SELECT own + INSERT own · no UPDATE (edge function uses service_role)
- `account_deletion_requests` · SELECT own + INSERT own + UPDATE own only to cancel (`status = 'pending' → 'cancelled'`)
- No DELETE policies · historical records for audit trail

### Indexes (2)

- `idx_account_deletion_due` · pg_cron sweep · `where status = 'pending'`
- `idx_data_export_user_recent` · client poll

### Edge functions consume (future · per Round 15 standby)

- `process-data-export` · on INSERT → ZIP user data → upload to `exports` Storage bucket → update `ready_url + completed_at`
- `process-account-deletion` · pg_cron daily · `where scheduled_for < now() AND status = 'pending'` → hard-delete cascade

---

## V6 · Night log (encrypted · C1)

### Table (1)

```
id              uuid PK default gen_random_uuid()
user_id         uuid FK profiles cascade
logged_at       timestamptz NOT NULL  (device clock at log time)
body_ciphertext bytea                 (AES-256-GCM encrypted · see header)
mood            text                  (NOT encrypted · aggregate-friendly)
deleted_at      timestamptz           (soft delete)
created_at      timestamptz default now()
```

### Encryption spec (C1 locked · documented in SQL header)

```
Algorithm:   AES-256-GCM
Nonce:       12 bytes random · prepended to ciphertext
Key alias:   'spiritpath.nightlog.v1'
Key access:
  iOS     · Keychain · kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
           · kSecAttrSynchronizable = false · device-bound
  Android · AndroidKeyStore · PURPOSE_ENCRYPT | PURPOSE_DECRYPT
           · requireAuthenticationOnLaunch = false · device-bound
Payload:     nonce(12) ‖ ciphertext ‖ tag(16) → bytea
Schema ver:  v1 (bump alias to v2 if spec changes · migration required)
```

**`mood` is intentionally NOT encrypted** · free-form text tag · enables aggregate mood-over-time analytics without breaking privacy posture (no PII content)

### RLS Pattern A · self-only with soft-delete filter on SELECT

### Index (1)

- `idx_night_log_user_time` · recent-first list · `where deleted_at is null`

### Settings copy lock (C1 Round 8 · both platforms)

> *"Night Log entries are encrypted on this device. Uninstalling the app or switching devices will permanently lose access to older entries."*

Quiet · direct · no error tone · matches *"the path is not elsewhere"*

---

## V7 · Feature flags

### Table (1)

```
key         text PK                   (snake_case)
value_json  jsonb NOT NULL            (typed per flag)
description text
updated_at  timestamptz default now()
```

### RLS Pattern B · authenticated read

```sql
create policy "feature_flags_read"
  on public.feature_flags for select
  using (auth.role() = 'authenticated');
```

### Seed (3 rows · C2 locked values · idempotent)

```sql
insert into public.feature_flags (key, value_json, description) values
  ('audio_delivery',  '"bundle"'::jsonb,  'bundle | remote'),
  ('accent_mode',     '"warm"'::jsonb,    'warm | cool'),
  ('paywall_variant', '"default"'::jsonb, 'A/B variant key')
on conflict (key) do nothing;
```

### Client behavior (C2 locked)

- **iOS** · `UserDefaults` cache · 1-hour TTL
- **Android** · DataStore Preferences cache · 1-hour TTL
- **Settings** · "Check for updates" button · force refresh
- **Fallback** · hardcoded defaults if network fail + no cache:
  ```
  audio_delivery  = "bundle"
  accent_mode     = "warm"
  paywall_variant = "default"
  ```
- **No Realtime** · intentional · flags are lightly-changing config not live state

---

## Android tasks (Round 18 trigger)

### Option 1 · Review + apply V5/V6/V7 to Supabase staging
- Pull 3 migration files
- Run in order after V4 applied
- Smoke test:
  - Insert test account_deletion_request → verify scheduled_for = +30 days
  - UPDATE status to 'cancelled' as user → verify RLS allows
  - UPDATE status to 'delivered' as user → verify RLS blocks
  - Select feature_flags → verify 3 seed rows visible
- Reply: OK or issues

### Option 2 · Draft 4 remaining Kotlin entities
- `DataExportRequestEntity.kt` (V5)
- `AccountDeletionRequestEntity.kt` (V5)
- `NightLogEntryEntity.kt` (V6) · includes encryption client adapter · AES-256-GCM · key alias reference
- `FeatureFlagEntity.kt` (V7) · plus `FeatureFlagsRepository.kt` with 1-hour cache + hardcoded defaults

Closes **17/17 entity coverage** on Android side.

### Option 3 · Parallel work from Round 15 queue
- `docs/design-system.md` token consolidation
- Phase 1.1 nav spike
- Mixpanel taxonomy audit

---

## Questions back to iOS (non-blocking · Round 18)

1. **V5 · `account_deletion_requests` UPDATE policy** · user can flip status to `'cancelled'` but also to any other value via client? Policy `with check` restricts to `('pending', 'cancelled')`. Confirm this is the right constraint · or should we restrict even more to `'cancelled'` only?

2. **V6 · `mood` field values** · lock enum or keep freeform? Suggested values: `'peaceful' · 'restless' · 'grateful' · 'anxious' · 'tired' · 'clear'` or leave client-freeform?

3. **V7 · flag key naming** · snake_case locked · but what about hierarchical keys like `audio.delivery` or `experiment.paywall_v2`? Stick with flat snake_case for now?

4. **V7 · Mixpanel Experiments integration** · Android Round 9 noted "Mixpanel Experiments could partially replace feature_flags table". Now that both exist, which wins when values conflict? iOS proposal: **Supabase feature_flags = slow-changing config (hours TTL)** · **Mixpanel Experiments = A/B test variants (client-owned · short-lived)** · non-overlapping concerns.

---

## Status after Round 18

| Wave | Content | Closed |
|---|---|---|
| 1 · Architecture | A1–A5 + C1–C5 + Q1–Q7 + NB1–NB5 + V1 | ✓ |
| 2 · Practice | V2 + 4 entities | ✓ |
| 3 · Content | V3 + 5 entities + S1/S2 | ✓ |
| 4 · Subscription + Engagement | V4 + 3 entities | ✓ |
| 5 · Compliance + Night log + Feature flags | V5/V6/V7 batch | ⏳ this review |
| 3.1 · Content-depth | V3.1 (deferred) | ⏸ |

**iOS remaining:** V3.1 content-depth (needs prototype reading) · Phase 1 Round 2 UI scaffolds

### Tone rule · held

> *"The path is not elsewhere."*

SQL comments thread compliance flows · encryption invariants · subscription-provider ownership without productized voice.

### Acknowledge format

Reply กลับมา:
- ✓ Read V5 · V6 · V7
- Reviewed: OK / issues per migration
- Next Android task: Option 1 / 2 / 3 / combo
- Answers Q1–Q4

---

## End of brief
