-- ============================================================================
-- SpiritPath · Migration 0004 · Subscription + Engagement
-- ============================================================================
-- Creates: user_subscriptions · notification_prefs · practice_window
--          + RLS Pattern A on all 3
--          + 2 indexes on user_subscriptions (active lookup + period_end range)
--          + updated_at triggers on all 3
-- Extends: handle_new_user() trigger (from V1) now auto-creates notification_prefs
--          + practice_window rows at signup time (defaults apply)
-- Platform: iOS + Android unified
-- Reference: master plan §07 · Tab 04 Round 15 (wave 3 closed · V4 next)
-- Android alignment (Round 9+): all 6 patterns (uuid PK · deleted_at · Pattern A ·
--                               reuse set_updated_at · enums · user_id indexes)
-- Makes real: V3 Pattern C subscription gate on teaching_units
-- ============================================================================

-- ─── 1. user_subscriptions · N:1 with user (history of subscriptions) ────

create table public.user_subscriptions (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.profiles(id) on delete cascade,

  provider                 public.subscription_provider not null,    -- 'apple' | 'google'
  product_id               text not null,                            -- e.g. 'sp_annual_2026'

  -- receipt identifier · unique across platform · what app reports after purchase
  provider_purchase_token  text unique,

  -- lifecycle state · enum locked in V1 · used by RLS Pattern C in V3
  status                   public.subscription_status not null,      -- trial · active · grace · expired · cancelled

  -- billing timeline
  trial_started_at         timestamptz,
  current_period_start     timestamptz,
  current_period_end       timestamptz,
  auto_renew               bool not null default true,

  -- server-side verification
  last_verified_at         timestamptz not null default now(),

  -- soft delete · keeps history for analytics + compliance · hard delete via edge function
  deleted_at               timestamptz,

  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

comment on table public.user_subscriptions is
  '1:N with profiles · each subscription purchase creates a row · webhooks update status/period_end · soft delete preserves history · RLS Pattern C in V3 references this table for teaching_units gate';
comment on column public.user_subscriptions.provider_purchase_token is
  'Apple receipt transaction_id OR Google Play purchase_token · unique across platform · used to dedupe webhook events';
comment on column public.user_subscriptions.last_verified_at is
  'When edge function (verify-apple-receipt / verify-play-purchase) last validated with store · used to detect stale server state';

-- ─── 2. notification_prefs · 1:1 with user (local notification config) ──

create table public.notification_prefs (
  user_id                    uuid primary key references public.profiles(id) on delete cascade,

  -- morning bell · gentle wake-time meditation reminder
  morning_bell_enabled       bool not null default true,
  morning_bell_at            time not null default '07:00',

  -- evening reminder · wind-down Stillness prompt
  evening_reminder_enabled   bool not null default true,
  evening_reminder_at        time not null default '21:00',

  -- quiet hours · notifications suppressed between these times
  quiet_hours_start          time not null default '22:00',
  quiet_hours_end            time not null default '06:00',

  -- tone asset key · resolves to bundled audio on device
  tone_ref                   text default 'tibetan_bell',

  updated_at                 timestamptz not null default now()
);

comment on table public.notification_prefs is
  '1:1 with profiles · auto-created by handle_new_user trigger with US-friendly defaults · client reads this + profiles.timezone to schedule local notifications (UNUserNotificationCenter / WorkManager)';

-- ─── 3. practice_window · 1:1 with user (session default prefs) ──────────

create table public.practice_window (
  user_id               uuid primary key references public.profiles(id) on delete cascade,

  -- when user typically practices · clamps session scheduling windows
  start_hour            int not null default 6  check (start_hour between 0 and 23),
  end_hour              int not null default 22 check (end_hour between 0 and 23),

  -- session-level defaults · copied into sessions.prefs_snapshot at session start
  pace_mode             text not null default 'forest',     -- forest · temple · city
  default_duration_sec  int  not null default 1800,          -- 30 min
  default_place         text not null default 'temple',
  default_ground        text not null default 'grass',

  updated_at            timestamptz not null default now()
);

comment on table public.practice_window is
  '1:1 with profiles · auto-created with defaults at signup · session prefs snapshot in sessions.prefs_snapshot pulls from here · does NOT store per-session overrides';

-- ─── 4. Indexes on user_subscriptions ────────────────────────────────────

-- active subscription lookup · used by Pattern C gate on teaching_units
create index idx_user_subs_active
  on public.user_subscriptions(user_id, status)
  where deleted_at is null
    and status in ('trial', 'active', 'grace');

-- period_end range scan · used by pg_cron jobs to flip 'active' → 'expired'
create index idx_user_subs_period_end
  on public.user_subscriptions(current_period_end)
  where status in ('trial', 'active', 'grace');

-- No index for notification_prefs / practice_window · PK lookup is O(1) already · 1 row per user

-- ─── 5. RLS · Pattern A · self-only ──────────────────────────────────────

alter table public.user_subscriptions  enable row level security;
alter table public.notification_prefs  enable row level security;
alter table public.practice_window     enable row level security;

-- user_subscriptions
create policy "user_subscriptions_select_own"
  on public.user_subscriptions for select
  using (auth.uid() = user_id and deleted_at is null);

create policy "user_subscriptions_insert_own"
  on public.user_subscriptions for insert
  with check (auth.uid() = user_id);

create policy "user_subscriptions_update_own"
  on public.user_subscriptions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- notification_prefs (no deleted_at · 1:1 with user · cascade only)
create policy "notification_prefs_select_own"
  on public.notification_prefs for select
  using (auth.uid() = user_id);

create policy "notification_prefs_insert_own"
  on public.notification_prefs for insert
  with check (auth.uid() = user_id);

create policy "notification_prefs_update_own"
  on public.notification_prefs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- practice_window (no deleted_at · 1:1 with user · cascade only)
create policy "practice_window_select_own"
  on public.practice_window for select
  using (auth.uid() = user_id);

create policy "practice_window_insert_own"
  on public.practice_window for insert
  with check (auth.uid() = user_id);

create policy "practice_window_update_own"
  on public.practice_window for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── 6. updated_at triggers · reuse set_updated_at from V1 ───────────────

create trigger tr_user_subscriptions_updated
  before update on public.user_subscriptions
  for each row execute function public.set_updated_at();

create trigger tr_notification_prefs_updated
  before update on public.notification_prefs
  for each row execute function public.set_updated_at();

create trigger tr_practice_window_updated
  before update on public.practice_window
  for each row execute function public.set_updated_at();

-- ─── 7. Extend handle_new_user · auto-create prefs + window at signup ────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- profiles (V1 · idempotent via Round 8 tweak)
  insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;

  -- notification_prefs (V4 · defaults from schema · 1:1 with user)
  insert into public.notification_prefs (user_id) values (new.id)
    on conflict (user_id) do nothing;

  -- practice_window (V4 · defaults from schema · 1:1 with user)
  insert into public.practice_window (user_id) values (new.id)
    on conflict (user_id) do nothing;

  -- journey_progress NOT created here · requires lineage_id (not null) · client creates after onboarding completes
  -- user_subscriptions NOT created here · created when user purchases (Apple/Google receipt verification)

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Auto-provisions user-bound 1:1 rows at auth.users insert · profiles (V1) · notification_prefs + practice_window (V4) · idempotent · journey_progress + user_subscriptions deferred to post-signup flows';

-- Trigger on_auth_user_created from V1 already binds to this function · no recreate needed

-- ─── 8. Upgrade V3 Pattern C on teaching_units · user_subscriptions now exists ───
-- Drops V3 placeholder (stage-1-only) · recreates with full subscription gate
-- Atomic within this migration's transaction · no window where teaching_units has no policy
-- Fix applied R21 · V3 push failed on missing user_subscriptions reference · split into
--   V3 placeholder (stage 1 only) + V4 upgrade (full gate)

drop policy if exists "teaching_units_free_or_paid" on public.teaching_units;

create policy "teaching_units_free_or_paid"
  on public.teaching_units for select
  using (
    published = true
    and (
      stage_index = 1
      or exists (
        select 1 from public.user_subscriptions
        where user_id = auth.uid()
          and status in ('trial', 'active', 'grace')
          and current_period_end > now()
          and deleted_at is null
      )
    )
  );

comment on policy "teaching_units_free_or_paid" on public.teaching_units is
  'RLS Pattern C · Stage 1 = free preview · Stage 2-5 require active user_subscriptions row (status in trial/active/grace AND not expired AND not soft-deleted) · upgraded from V3 placeholder';
