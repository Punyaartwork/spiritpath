# SpiritPath · V3 Content Migration Review Brief · paste-ready

**Paste section "## Brief for Android Claude · V3 review" ให้ Android session**

---

## Brief for Android Claude · V3 review

### TL;DR · V3 drafted · sync round 12 · awaiting Android review

iOS ส่ง V3 content migration · 5 content tables + RLS Pattern B + Pattern C + FK add-back + seed 3 lineages + 15 stages + 4 sound_tracks

**File:** `/Users/punyapath/Documents/SpiritPath/supabase/migrations/0003_content.sql`
**Size:** ~260 lines
**Domain:** Content (public-read · paid-gated for teaching_units)

### Tables created (5 content · 2 RLS patterns)

| Table | PK | RLS | Seed | Notes |
|---|---|---|---|---|
| `lineages` | `id text` | Pattern B · `active = true` | ✓ 3 rows | 3 teachers · thai_name · years · tradition · glyph · accent_color |
| `stages` | composite `(lineage_id, stage_index)` | Pattern B · authenticated | ✓ 15 rows · subtitles only | title shared · subtitle verbatim from prototype STAGE_SUBS |
| `teaching_units` | `id text` | **Pattern C · subscription gate** | ⏸ deferred | 3-mode (listen/understand/reflect) · FK to stages composite |
| `teacher_quotes` | `id uuid` | Pattern B · authenticated | ⏸ deferred | english_text + thai_text + transliteration + source_ref |
| `sound_tracks` | `id text` | Pattern B · `active = true` | ✓ 4 rows | rain · forest · bells · silence · audio_url null Phase 1 |

### FK add-back (V2 follow-up)

```sql
alter table public.teaching_progress
  add constraint fk_teaching_progress_unit
  foreign key (teaching_unit_id)
  references public.teaching_units(id)
  on delete cascade;
```

Closes the V2 deferral. Now `teaching_progress.teaching_unit_id` enforces referential integrity.

### RLS Pattern C · subscription gate (teaching_units)

```sql
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
```

**Forward reference:** policy mentions `user_subscriptions` table · **created in V4**. Between V3 and V4 landing, EXISTS subquery returns empty → only stage_index = 1 rows visible. No paid content will be published before V4 anyway. Safe.

### Indexes

| Index | Table | Cols | Partial predicate |
|---|---|---|---|
| `idx_teaching_units_lookup` | teaching_units | lineage_id, stage_index, mode, order_index | `where published = true` |
| `idx_teacher_quotes_lookup` | teacher_quotes | lineage_id, stage_index | — |

### Seed · lineages (3 rows · verbatim from `screen-journey.jsx` LINEAGES)

```
mun  · Luang Pu Mun Bhūridatto · หลวงปู่มั่น ภูริทัตโต · 1870–1949
       Thai Forest · Kammaṭṭhāna · accent #f0c870 · glyph ◆
sodh · Luang Pu Sodh Candasaro · หลวงปู่สด จนฺทสโร · 1884–1959
       Dhammakāya method · accent #c8a8f0 · glyph ☉
chah · Ajahn Chah Subhaddo · หลวงพ่อชา สุภทฺโท · 1918–1992
       Thai Forest · Wat Pah Pong · accent #a8d0a0 · glyph ✦
```

Accent colors matched to the **Compare dot** colors seen in prototype (`screen-journey.jsx` Compare button's 3 dots). Main UI still uses gold `#f0c870` universally — these accents only appear in Journey lineage card, Compare, Profile glyph (Phase 3).

### Seed · stages (15 rows · subtitles verbatim from STAGE_SUBS)

Shared titles: **The Outer Path · The Quiet Ground · The Inner Forest · The Silent Temple · Open Awareness**

Subtitles per lineage · `E'...\n...'` preserves original line breaks from prototype.

Examples:
- Mun Stage 5: `"No effort. Just being."`
- Sodh Stage 1: `"Sammā Arahaṃ —\narriving at the center"`
- Chah Stage 2: `"ไม่แน่ · not for sure.\nThe glass is already broken"`

All 15 verbatim from `STAGE_SUBS` object in `screen-journey.jsx`.

**`anchor_phrase` + `trap_warning` = NULL** in seed · deferred to a future migration that reads prototype's teaching content files.

### Seed · sound_tracks (4 rows)

```
rain    · ambient · audio_url NULL (Phase 1 bundled)
forest  · ambient · audio_url NULL
bells   · ritual  · audio_url NULL
silence · silence · audio_url NULL
```

`audio_url NULL` during Phase 1 · client falls back to app-bundled audio · switched to Supabase Storage URL via `feature_flags.audio_delivery = "remote"` in Phase 2+.

### Deferred seed · content waiting on prototype reading

Need to port these when time allows:

1. `stages.anchor_phrase` · 15 rows · per stage per lineage
2. `stages.trap_warning` · 15 rows · per stage per lineage
3. `teacher_quotes` · 1+ per stage per lineage · 15+ rows total
4. `teaching_units` · up to 3 modes × 5 stages × 3 lineages = 45 units

**Sources (all in iOS repo at `/Users/punyapath/Downloads/SpiritPath/`):**
- `src/teaching-data.jsx`
- `src/teaching-data-sodh.jsx`
- `src/teaching-data-chah.jsx`
- `src/screen-compare.jsx`
- `PROMPT for curriculum - Ajahn Chah.md`
- `PROMPT for curriculum - Luang Pu Sodh.md`
- `PROMPT for curriculum.md`

Will ship in a dedicated **V3.1 content-depth** migration · scope contained · review same way.

### Android next task (when ready)

**Option 1 · Review + apply V3 to staging**
- Pull migration file
- Run `supabase db push` (or paste in SQL editor)
- Test: authenticated select lineages → see 3 rows · select stages → see 15 rows with subtitles · select teaching_units → only stage_index=1 visible (no subscription yet)
- Reply: OK or issues

**Option 2 · Draft Kotlin content entities**
- `LineageEntity.kt` · mirrors 11 columns
- `StageEntity.kt` · composite PK (lineageId, stageIndex)
- `TeachingUnitEntity.kt` · paid-gated · domain object wraps RLS-filtered query
- `TeacherQuoteEntity.kt`
- `SoundTrackEntity.kt`
- All read-only on client · no insert/update paths

**Option 3 · Parallel · proceed with Android Phase 1.1 nav spike**
- Not blocked by V3 at all
- Navigation Compose 2.8 + NavHost replacing HomePlaceholder
- 1h timebox · separate branch

### Questions back to iOS side (non-blocking)

1. **Accent colors** · I used Compare dot colors (`#f0c870` · `#c8a8f0` · `#a8d0a0`). Android UI uses these anywhere? If not, we can keep them as data-only fields for potential Phase 3 Profile glyph tinting.
2. **`stages.key_image_ref`** column exists but is NULL in seed · do we have image assets planned for stages? Or drop the column until Phase 2+?
3. **`teacher_quotes.source_ref`** · what format? Scripture citation style (e.g. "SN 35.23"), book page ("In Simple Words, p. 42"), or URL? Lock a convention before seeding.
4. **Subscription gate edge** · Pattern C uses `current_period_end > now()` — tested OK when subscription exists but is expired? Should return Stage 1 only · confirm on Android side by inserting expired subscription row after V4 lands.

### Tone rule

> *"The path is not elsewhere."*

Comments in V3 SQL follow tone · cites prototype files + sync rounds · no productized language. Seed text verbatim from prototype · no paraphrasing.

### Acknowledge format

Reply กลับมา:
- ✓ Read V3 · ~260 lines · 5 tables · 2 RLS patterns · seed counts
- Reviewed: OK / issues found
- Next Android task: Option 1/2/3 (or combination)
- Answers Q1–Q4 above

---

## End of brief
