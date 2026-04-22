-- ============================================================================
-- SpiritPath · Migration 0003 · Content domain + seed
-- ============================================================================
-- Creates: lineages · stages · teaching_units · teacher_quotes · sound_tracks
--          + RLS Pattern B (authenticated read) + Pattern C (subscription gate)
--          + FK add for teaching_progress.teaching_unit_id (deferred from V2)
-- Seed: 3 lineages · 15 stages (subtitles) · 4 sound_tracks
-- Deferred seed: teaching_units content · teacher_quotes · stage anchor + trap
-- Platform: iOS + Android unified · content port verbatim from prototype JSX
-- Reference: master plan §07 · Tab 04 Round 12
-- Content source: /Users/punyapath/Downloads/SpiritPath/src/screen-journey.jsx
-- ============================================================================

-- ─── 1. lineages · 3 rows (Mun · Sodh · Chah) ─────────────────────────────

create table public.lineages (
  id                  text primary key,           -- 'mun' | 'sodh' | 'chah'
  name                text not null,              -- 'Luang Pu Mun Bhūridatto'
  short_name          text,                       -- 'Luang Pu Mun'
  thai_name           text,                       -- 'หลวงปู่มั่น ภูริทัตโต'
  years               text,                       -- '1870–1949'
  tradition           text,                       -- 'Thai Forest · Kammaṭṭhāna'
  note                text,                       -- teaching emphasis summary
  accent_color_hex    text not null default '#f0c870',   -- Compare dot color
  glyph_symbol        text not null default '◆',          -- single char
  display_order       int not null default 0,
  active              bool not null default true
);

comment on table public.lineages is
  '3 Thai lineages from prototype · read-only in client · service_role writes seed + future edits';

-- ─── 2. stages · 15 rows (3 lineages × 5 stages) ──────────────────────────

create table public.stages (
  lineage_id       text not null references public.lineages(id),
  stage_index      int  not null check (stage_index between 1 and 5),
  title            text not null,              -- shared across lineages: 'The Outer Path', ...
  subtitle         text,                       -- per-lineage · prototype STAGE_SUBS
  key_image_ref    text,                       -- asset bundle path (Phase 2+)
  trap_warning     text,                       -- "meditation candy" trap · deferred seed
  anchor_phrase    text,                       -- anchor for this stage · deferred seed

  primary key (lineage_id, stage_index)
);

comment on table public.stages is
  '5 developmental stages per lineage · composite PK · title is shared across lineages · subtitle + anchor + trap are lineage-specific';

-- ─── 3. teaching_units · per-stage per-mode content · paid-gated ─────────

create table public.teaching_units (
  id                    text primary key,      -- e.g. 'mun_1_listen_01'
  lineage_id            text not null references public.lineages(id),
  stage_index           int not null check (stage_index between 1 and 5),
  mode                  public.teaching_mode not null,    -- listen | understand | reflect
  order_index           int not null default 0,

  title                 text not null,
  duration_sec          int,
  audio_url             text,                  -- Supabase Storage (bucket: audio)
  transcript_url        text,
  chapters              jsonb,                 -- for listen mode
  body                  jsonb,                 -- for understand/reflect mode
  source_passage_refs   text[],                -- citations

  version               int  not null default 1,
  published             bool not null default false,

  foreign key (lineage_id, stage_index)
    references public.stages(lineage_id, stage_index)
);

comment on table public.teaching_units is
  '3-mode teaching content per lineage × stage · paid-gated via RLS Pattern C · Stage 1 free preview · Stage 2-5 require active subscription';

-- FK add-back from V2 · now that teaching_units exists
alter table public.teaching_progress
  add constraint fk_teaching_progress_unit
  foreign key (teaching_unit_id)
  references public.teaching_units(id)
  on delete cascade;

-- ─── 4. teacher_quotes · per-stage quotes with translations ───────────────

create table public.teacher_quotes (
  id                uuid primary key default gen_random_uuid(),
  lineage_id        text not null references public.lineages(id),
  stage_index       int  not null check (stage_index between 1 and 5),

  english_text      text not null,
  thai_text         text,
  transliteration   text,                     -- e.g. 'Sammā Arahaṃ'
  source_ref        text,                     -- citation

  foreign key (lineage_id, stage_index)
    references public.stages(lineage_id, stage_index)
);

comment on table public.teacher_quotes is
  'Quotes attributed to each teacher per stage · shown on Journey and Teaching screens · Pali/Thai transliteration optional';

-- ─── 5. sound_tracks · 4 rows (rain · forest · bells · silence) ──────────

create table public.sound_tracks (
  id                text primary key,            -- 'rain' | 'forest' | 'bells' | 'silence'
  category          text not null,
  audio_url         text,                        -- Supabase Storage · null during Phase 1 (bundled)
  loop_seamless     bool not null default true,
  credit            text,                        -- source / creator attribution
  active            bool not null default true
);

comment on table public.sound_tracks is
  'Sound Bath audio tracks · used in Stillness tab · Phase 1 bundled in-app · Phase 2+ switches to remote via feature_flag audio_delivery';

-- ─── 6. Indexes ───────────────────────────────────────────────────────────

-- teaching_units · lookup by lineage + stage + mode + order
create index idx_teaching_units_lookup
  on public.teaching_units(lineage_id, stage_index, mode, order_index)
  where published = true;

-- teacher_quotes · lookup by lineage + stage
create index idx_teacher_quotes_lookup
  on public.teacher_quotes(lineage_id, stage_index);

-- ─── 7. RLS · Pattern B (authenticated read · service_role write) ────────

alter table public.lineages        enable row level security;
alter table public.stages          enable row level security;
alter table public.teacher_quotes  enable row level security;
alter table public.sound_tracks    enable row level security;

-- Pattern B (Option A from Round 11 S2) · require authenticated on ALL content reads
-- App requires auth post-onboarding · no reason to expose content to anonymous scrapers

create policy "lineages_read_active"
  on public.lineages for select
  using (auth.role() = 'authenticated' and active = true);

create policy "stages_read"
  on public.stages for select
  using (auth.role() = 'authenticated');

create policy "teacher_quotes_read"
  on public.teacher_quotes for select
  using (auth.role() = 'authenticated');

create policy "sound_tracks_read_active"
  on public.sound_tracks for select
  using (auth.role() = 'authenticated' and active = true);

-- No INSERT/UPDATE/DELETE policies · service_role bypasses RLS for seed + admin edits

-- ─── 8. RLS · Pattern C · teaching_units stage-1-only placeholder ─────────
-- V3 cannot reference user_subscriptions · that table ships in V4
-- This placeholder keeps V3 standalone-applicable · V4 drops + recreates with full gate
-- Safe-by-default: only stage 1 readable · stages 2-5 invisible to all clients until V4

alter table public.teaching_units enable row level security;

create policy "teaching_units_free_or_paid"
  on public.teaching_units for select
  using (
    published = true
    and stage_index = 1
  );

comment on policy "teaching_units_free_or_paid" on public.teaching_units is
  'RLS Pattern C placeholder · V3 · stage 1 only · V4 upgrades to full subscription gate';

-- ─── 9. Seed · lineages (3 rows · verbatim from screen-journey.jsx) ──────

insert into public.lineages (
  id, name, short_name, thai_name, years, tradition, note,
  accent_color_hex, glyph_symbol, display_order
) values
  ('mun',
   'Luang Pu Mun Bhūridatto',
   'Luang Pu Mun',
   'หลวงปู่มั่น ภูริทัตโต',
   '1870–1949',
   'Thai Forest · Kammaṭṭhāna',
   'Walking as primary practice. Body as scripture. Awareness as ground.',
   '#f0c870',
   '◆',
   1),
  ('sodh',
   'Luang Pu Sodh Candasaro',
   'Luang Pu Sodh',
   'หลวงปู่สด จนฺทสโร',
   '1884–1959',
   'Dhammakāya method',
   E'The clear crystal sphere at the body''s center. Stillness as the gateway inward.',
   '#c8a8f0',
   '☉',
   2),
  ('chah',
   'Ajahn Chah Subhaddo',
   'Luang Por Chah',
   'หลวงพ่อชา สุภทฺโท',
   '1918–1992',
   'Thai Forest · Wat Pah Pong',
   E'Ordinary mind, radical simplicity. ''Let go a little, peace a little.''',
   '#a8d0a0',
   '✦',
   3)
on conflict (id) do nothing;

-- ─── 10. Seed · stages (15 rows · subtitles verbatim from STAGE_SUBS) ────

-- 5 stage titles are shared across lineages
-- Subtitles vary per lineage · E'\n' preserves original line breaks from prototype

insert into public.stages (lineage_id, stage_index, title, subtitle) values
  -- Mun · Thai Forest · Kammaṭṭhāna
  ('mun', 1, 'The Outer Path',      E'A whole-in-motion,\nnoticing the world'),
  ('mun', 2, 'The Quiet Ground',    E'Moments of stillness\nbegin to appear'),
  ('mun', 3, 'The Inner Forest',    E'Attention softens,\nawareness deepens'),
  ('mun', 4, 'The Silent Temple',   E'The mind rests, clear\nand unhurried'),
  ('mun', 5, 'Open Awareness',      'No effort. Just being.'),

  -- Sodh · Dhammakāya · Light
  ('sodh', 1, 'The Outer Path',     E'Sammā Arahaṃ —\narriving at the center'),
  ('sodh', 2, 'The Quiet Ground',   E'Stopping itself\nis the fulfillment'),
  ('sodh', 3, 'The Inner Forest',   E'The first sphere\nappears at Base 7'),
  ('sodh', 4, 'The Silent Temple',  E'Through eighteen bodies,\none inward movement'),
  ('sodh', 5, 'Open Awareness',     E'The one path —\nwhat remains, remains'),

  -- Chah · Thai Forest · Wat Pah Pong
  ('chah', 1, 'The Outer Path',     E'Rain water —\nthe mind already pure'),
  ('chah', 2, 'The Quiet Ground',   E'ไม่แน่ · not for sure.\nThe glass is already broken'),
  ('chah', 3, 'The Inner Forest',   E'The farmer watches\nthe buffalo · ผู้รู้'),
  ('chah', 4, 'The Silent Temple',  E'Both ends of the snake bite.\nWho is watching?'),
  ('chah', 5, 'Open Awareness',     E'The tree does not know itself.\nIt is as it is.')
on conflict (lineage_id, stage_index) do nothing;

-- Note · anchor_phrase + trap_warning left NULL · seed in a future migration after
-- reading prototype content files: teaching-data.jsx · teaching-data-sodh.jsx ·
-- teaching-data-chah.jsx · screen-compare.jsx · PROMPT for curriculum - *.md

-- ─── 11. Seed · sound_tracks (4 rows · audio_url null during Phase 1) ────

insert into public.sound_tracks (id, category, audio_url, loop_seamless, active) values
  ('rain',    'ambient',  null, true, true),
  ('forest',  'ambient',  null, true, true),
  ('bells',   'ritual',   null, true, true),
  ('silence', 'silence',  null, true, true)
on conflict (id) do nothing;

comment on column public.sound_tracks.audio_url is
  'NULL during Phase 1 · client falls back to app-bundled audio · switched to Supabase Storage URL via feature_flag audio_delivery = "remote" in Phase 2+';

-- ─── 12. Deferred for a future content migration ──────────────────────────

-- stages.anchor_phrase: per stage · anchor suggestion shown at session start
-- stages.trap_warning: per stage · "meditation candy" trap description
-- teaching_units content: 3 modes × 5 stages × 3 lineages = up to 45 units
-- teacher_quotes: 1+ per stage per lineage · english + thai + transliteration
-- sound_tracks audio_url: when Phase 2 remote delivery enabled

-- These require reading:
--   /Users/punyapath/Downloads/SpiritPath/src/teaching-data.jsx
--   /Users/punyapath/Downloads/SpiritPath/src/teaching-data-sodh.jsx
--   /Users/punyapath/Downloads/SpiritPath/src/teaching-data-chah.jsx
--   /Users/punyapath/Downloads/SpiritPath/src/screen-compare.jsx
--   /Users/punyapath/Downloads/SpiritPath/PROMPT for curriculum - *.md
