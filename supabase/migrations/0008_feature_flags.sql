-- ============================================================================
-- SpiritPath · Migration 0007 · Feature flags + Config
-- ============================================================================
-- Creates: feature_flags table + RLS Pattern B (authenticated read · service_role write)
-- Seed:    3 feature flags (audio_delivery · accent_mode · paywall_variant)
-- Platform: iOS + Android unified
-- Reference: master plan §07 · Round 15 standby trigger · A3 from wave 1
-- Client-side:
--   iOS:     UserDefaults cache · 1-hour TTL · Settings force-refresh button (C2)
--   Android: DataStore Preferences cache · same TTL · same fallback to hardcoded defaults
-- Hardcoded defaults (ship if network fail + no cache · C2):
--   audio_delivery  = "bundle"
--   accent_mode     = "warm"
--   paywall_variant = "default"
-- ============================================================================

-- ─── 1. feature_flags table ──────────────────────────────────────────────

create table public.feature_flags (
  key         text primary key,       -- snake_case · e.g. 'audio_delivery'
  value_json  jsonb not null,         -- typed per flag · see spec per-flag
  description text,
  updated_at  timestamptz not null default now()
);

comment on table public.feature_flags is
  'Server-controlled config flags · authenticated read · service_role write · values parsed client-side per known key · unknown keys ignored · JSON shape spec per flag documented in master plan §07 Tab 04 C2';

-- ─── 2. updated_at trigger · reuse from V1 ──────────────────────────────

create trigger tr_feature_flags_updated
  before update on public.feature_flags
  for each row execute function public.set_updated_at();

-- ─── 3. RLS · Pattern B · authenticated read ────────────────────────────

alter table public.feature_flags enable row level security;

create policy "feature_flags_read"
  on public.feature_flags for select
  using (auth.role() = 'authenticated');

-- No INSERT/UPDATE/DELETE policies · service_role bypasses RLS for admin edits

-- ─── 4. Seed · 3 initial flags (C2 locked values) ───────────────────────

insert into public.feature_flags (key, value_json, description) values
  ('audio_delivery',
   '"bundle"'::jsonb,
   'Audio source strategy · "bundle" = use in-app audio assets · "remote" = stream from Supabase Storage audio bucket · Phase 1 ships "bundle" · flip to "remote" in Phase 2+ when CDN ready'),
  ('accent_mode',
   '"warm"'::jsonb,
   'Accent palette variant · "warm" = moon gold (default from prototype Tweaks Panel) · "cool" = sage variant · A/B tested via Mixpanel Experiments'),
  ('paywall_variant',
   '"default"'::jsonb,
   'Paywall copy/layout variant key · "default" = prototype screen 19 · other values for A/B experiments · client renders unknown variant as "default"')
on conflict (key) do nothing;

-- Value shapes (C2 locked · enforce client-side · no DB CHECK):
--   audio_delivery  · string enum  · "bundle" | "remote"
--   accent_mode     · string enum  · "warm" | "cool"
--   paywall_variant · string       · "default" | "A" | "B" | ...
-- Future flags with object values (e.g. {"enabled": true, "rollout_pct": 0.5})
-- must spec per-flag shape in master plan before landing here.
