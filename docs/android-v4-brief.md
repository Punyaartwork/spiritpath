# SpiritPath · V4 Subscription + Engagement Review Brief · paste-ready

**Paste section "## Brief for Android Claude · V4 review" ให้ Android session**

---

## Brief for Android Claude · V4 review

### TL;DR · V4 drafted · sync round 16 · makes V3 Pattern C real

iOS ส่ง V4 · subscription + engagement · 3 tables + extends handle_new_user to auto-provision prefs

**File:** `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0004_subscription_engagement.sql`
**Size:** 210 lines · 27 DDL statements
**Domain:** Subscription + Engagement · makes V3 Pattern C gate functional

### Tables (3) · all Pattern A self-only

| Table | PK | Soft delete? | Auto-created at signup? |
|---|---|---|---|
| `user_subscriptions` | `id uuid` | ✓ `deleted_at` | ❌ created on purchase event |
| `notification_prefs` | `user_id` (PK=FK) | ❌ (1:1 · cascade) | ✓ via extended `handle_new_user` |
| `practice_window` | `user_id` (PK=FK) | ❌ (1:1 · cascade) | ✓ via extended `handle_new_user` |

### Key decisions verified against Android's 6 alignment patterns

| # | Pattern | V4 status |
|---|---|---|
| 1 | uuid PK + FK cascade | ✓ user_subscriptions.id uuid default gen_random_uuid · notification/practice use user_id PK |
| 2 | Soft delete via `deleted_at` | ✓ user_subscriptions only · the 1:1 tables cascade with profiles |
| 3 | RLS Pattern A with soft-delete filter | ✓ all 9 policies · filter only on user_subscriptions SELECT |
| 4 | Reuse `set_updated_at()` | ✓ 3 triggers attached |
| 5 | Use enums (V1-defined) | ✓ `subscription_provider ('apple'\|'google')` · `subscription_status` |
| 6 | Indexes on hot paths | ✓ 2 partial indexes on user_subscriptions (active lookup + period_end range) |

### user_subscriptions structure (13 columns)

```sql
id                       uuid primary key
user_id                  uuid fk profiles
provider                 subscription_provider    -- 'apple' | 'google'
product_id               text                      -- 'sp_annual_2026'
provider_purchase_token  text unique               -- dedupe webhook events
status                   subscription_status       -- trial | active | grace | expired | cancelled
trial_started_at         timestamptz
current_period_start     timestamptz
current_period_end       timestamptz
auto_renew               bool default true
last_verified_at         timestamptz default now()
deleted_at               timestamptz
created_at, updated_at   timestamptz
```

### Indexes on user_subscriptions

**`idx_user_subs_active`** · partial · drives V3 Pattern C gate
```sql
create index idx_user_subs_active
  on public.user_subscriptions(user_id, status)
  where deleted_at is null
    and status in ('trial', 'active', 'grace');
```

**`idx_user_subs_period_end`** · partial · for pg_cron expiry sweep
```sql
create index idx_user_subs_period_end
  on public.user_subscriptions(current_period_end)
  where status in ('trial', 'active', 'grace');
```

### Extended `handle_new_user()` (replaces V1 version)

```sql
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;
  insert into public.notification_prefs (user_id) values (new.id)
    on conflict (user_id) do nothing;
  insert into public.practice_window (user_id) values (new.id)
    on conflict (user_id) do nothing;
  return new;
end;
$$;
```

All 3 inserts idempotent. `on_auth_user_created` trigger from V1 already binds to this function · no recreate.

### V3 Pattern C · now runnable

V3's `teaching_units_free_or_paid` policy references `user_subscriptions` (forward ref). With V4 landing, the EXISTS subquery can now return matches. Expected behavior:

| User state | Teaching units visible |
|---|---|
| No subscription row | stage_index = 1 only (fallback) |
| Subscription status = active · period_end in future | all published stages |
| Subscription status = active · period_end past | stage_index = 1 only (period_end > now fails) |
| Subscription status = grace · period_end in future | all published stages |
| Subscription status = expired | stage_index = 1 only |
| Subscription status = cancelled | stage_index = 1 only |
| Subscription with deleted_at set | stage_index = 1 only |

Android's Round 11 Q4 smoke test plan is now runnable after V4 applies.

### notification_prefs defaults (US-friendly)

```
morning_bell_enabled     true
morning_bell_at          07:00
evening_reminder_enabled true
evening_reminder_at      21:00
quiet_hours_start        22:00
quiet_hours_end          06:00
tone_ref                 'tibetan_bell'
```

Client reads this + `profiles.timezone` to schedule local notifications. iOS `UNUserNotificationCenter` · Android `WorkManager` · both read the same row.

### practice_window defaults

```
start_hour            6
end_hour              22
pace_mode             'forest'     -- forest | temple | city
default_duration_sec  1800         -- 30 min
default_place         'temple'
default_ground        'grass'
```

Defaults match prototype's `app.jsx` initial prefs state (`duration: '30 MINS' · place: 'temple' · ground: 'grass' · pace: 'forest'`). Session start copies relevant keys into `sessions.prefs_snapshot` (6 keys locked in V2 Round 11 Q2).

### Android next task (when ready)

**Option 1 · Review + apply V4 to Supabase staging**
- Pull migration file
- Run `supabase db push` after V1–V3 applied
- Smoke test: create auth user → verify auto-provisioned `notification_prefs` + `practice_window` rows exist · insert test subscription row → verify teaching_units stage 2+ visible
- Reply: OK or issues

**Option 2 · Draft Kotlin entities**
- `UserSubscriptionEntity.kt` · 13 columns · `Provider` + `Status` enums
- `NotificationPrefsEntity.kt` · 8 columns · 1:1 user · TypeConverter for `time` (LocalTime)
- `PracticeWindowEntity.kt` · 7 columns · 1:1 user
- All read + write on client (user changes settings)

**Option 3 · Parallel · continue Android Phase 1.1 nav spike**
- Not blocked by V4
- Already in-flight per Round 15 Android parallel queue

### Questions back to iOS side (non-blocking)

1. **`subscription_provider` enum completeness** · only `'apple' | 'google'` · what about future Stripe web checkout or Anthropic-native billing? Lock as-is + adopt "not shipping web for now" · or forward-proof with `'stripe'`?
2. **`tone_ref` asset keys** · what values are valid? Lock a list now or leave freeform text until UI design settles?
3. **`pace_mode` values** · `forest · temple · city` · how are these differentiated in UX? Just bg-color/soundscape difference? Lock enum now or keep text?
4. **Grace period logic** · when `status = 'grace'` is set, by who? Apple sends `GRACE_PERIOD_EXPIRED` event · should status flip to `'expired'` server-side via `handle-apple-notif` edge function or remain `'grace'` until current_period_end passes?

### Tone rule

> *"The path is not elsewhere."*

SQL comments cite V1 idempotency tweak · V3 Pattern C · Round references · paper trail clean · no productized language.

### Acknowledge format

Reply กลับมา:
- ✓ Read V4 · 210 lines · 27 DDL · 3 tables
- Reviewed: OK / issues found
- Next Android task: Option 1 / 2 / 3 (or combo)
- Answers Q1–Q4 above

---

## End of brief
