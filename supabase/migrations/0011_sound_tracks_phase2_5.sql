-- ============================================================================
-- SpiritPath · Migration 0011 · Phase 2.5 sound_tracks
-- ============================================================================
-- Adds: 'stream' soundscape (prototype has 5 · V3 had 4 · missing stream)
-- Updates: audio_url on existing 4 + new 1 → bundle:// scheme for in-app
--          bundled mp3 lookup. Decision 1 ambient bundle locked · feature_flag
--          audio_delivery=bundle. Phase 3 swaps to https:// CDN URLs when
--          audio_delivery=remote.
-- Idempotent · re-runnable.
-- ============================================================================

-- ─── 1. INSERT new track (idempotent) ─────────────────────────────────────

insert into public.sound_tracks (id, category, audio_url, loop_seamless, active) values
  ('stream', 'ambient', 'bundle://soundbath_stream.mp3', true, true)
on conflict (id) do nothing;

-- ─── 2. UPDATE existing 4 tracks to populate audio_url with bundle:// scheme ─

update public.sound_tracks
   set audio_url = 'bundle://soundbath_silence.mp3'
 where id = 'silence' and audio_url is null;

update public.sound_tracks
   set audio_url = 'bundle://soundbath_rain.mp3'
 where id = 'rain' and audio_url is null;

update public.sound_tracks
   set audio_url = 'bundle://soundbath_forest.mp3'
 where id = 'forest' and audio_url is null;

update public.sound_tracks
   set audio_url = 'bundle://soundbath_bells.mp3'
 where id = 'bells' and audio_url is null;

-- ─── 3. Comment update · audio_url scheme convention ──────────────────────

comment on column public.sound_tracks.audio_url is
  'Audio source URL · bundle://<filename> for Phase 2.5 in-app bundled mp3 · https://<...> for Phase 3 CDN delivery (feature_flag audio_delivery=remote) · NULL forbidden post Phase 2.5';
