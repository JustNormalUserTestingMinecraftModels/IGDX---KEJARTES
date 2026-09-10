# StudentList — Warm UI, Part 3

Design spec, 2026-09-10. Follows **Warm UI system, Part 1** (2026-09-09) and
**Cream panel language, Part 2** (2026-09-10). This pass brings the last
TutorialPanel-hosting screen that never had a dedicated design pass into the
same language.

## Why this screen

StudentList is not a list. It is a **one-card-at-a-time carousel that acts as
the scheduling hub**: AturJadwal routes here, you tap a student's paper card,
that sends you back to AturJadwal to set their week, and you return. The
`BELUM TERJADWALKAN` / `SUDAH TERJADWALKAN` badge is the entire point of the
screen.

Four problems, in the order they hurt:

1. **No roster-wide progress.** The screen exists to answer "who still needs a
   schedule?", but you see one student at a time and the page dots carry no
   state. Finding the unscheduled student costs up to four taps.
2. **~330px of dead paper.** The card is 940x1580. The sticky notes stop around
   card-local y=1250. A fifth of the card is blank, and the 3+2 note grid leaves
   a lopsided hole in the second row.
3. **Bare chrome.** `LeftArrow` / `RightArrow` are literal `<` and `>` glyphs
   pinned to the vertical centre of a 1920-tall screen — awkward for a thumb.
   `HeaderLabel` is a floating H1Label with no Indonesian-school framing.
4. **Thin identity.** A stretched square portrait and a name. `hobby_category`,
   `personality` and `quirk` are all present in the student data and none of it
   reaches the screen.

Direction chosen: **enriched carousel**. The alternative — retiring the carousel
for an all-four-at-once roster board — reads better but rewrites the tutorial,
breaks the `Murid1..4` single-card contract, and is a larger pass than this one
should be. It is recorded as a follow-up under "Deferred", below.

## Section 1 — Extract the card

The scene carries **four near-identical ~130-line card subtrees** (`Murid1..4`),
about 600 lines of `.tscn`. Relayouting in place means doing the same work four
times and keeping four copies in sync forever.

Extract the card into `Scenes/StudentList/RosterCard.tscn` +
`Scripts/StudentList/RosterCard.gd` — the same move already made for
`StickyNote`. Instance it four times under `CardContainer`.

**The instance names stay `Murid1`, `Murid2`, `Murid3`, `Murid4`.** This is
load-bearing: `tests/test_student_list.gd` resolves `CardContainer/Murid%d`, and
the tutorial's first step targets `CardContainer`. Keeping the names keeps both
contracts intact.

Per the project's override hazard (overrides serialise only on an instanced
scene's ROOT), every tunable is an `@export` on `RosterCard.gd`, never a
property poked into a child:

| `@export` | Type | Purpose |
|---|---|---|
| `student_name` | `String` | drives `Nama` |
| `portrait_texture` | `Texture2D` | framed portrait |
| `specialty` | `String` | `hobby_category`, drives the specialty chip |
| `persona` | `String` | drives the persona chip and the catatan opener |
| `quirk` | `String` | drives the quirk chip and the catatan observation |
| `is_scheduled` | `bool` | swaps `Belum` / `Sudah` |

One more component comes out of the same principle:

- `Scenes/StudentList/RosterAvatar.tscn` + `RosterAvatar.gd` — `@export
  portrait_texture`, `@export is_scheduled`, `@export is_current` on the root.

A `TraitChip` component was drafted here and **dropped during planning**: Godot's
`Button` carries a native `icon`, so a chip is a themed `Button`, not a scene.
See Section 5.

## Section 2 — Screen layout

Screen is 1080x1920. All coordinates below are screen space.

| Band | y range | Height | Contents |
|---|---|---|---|
| Papan header | 24–140 | 116 | `whiteboard.png` plaque, x 190–890, with `HeaderLabel` (H1Label, `DAFTAR MURID`) centred on it |
| Roster strip | 155–305 | 150 | `RosterStrip` Control, x 70–1010; four `RosterAvatar` buttons |
| Card | 310–1700 | 1390 | `CardContainer`, x 70–1010; four `RosterCard` instances |
| Nav row | 1730–1850 | 120 | `LeftArrow` x 70–230, `PageIndicator` x 440–640, `RightArrow` x 850–1010 |

**Roster strip.** Four avatars, 150x150 (clears `touch_target_min` = 96), evenly
spaced: gap = (940 − 4x150) / 5 = 68, so x = 138, 356, 574, 792. Each carries a
`roster_avatar_frame.png` ring tinted by `self_modulate` — `state_success`
(#35A05A) when that student is scheduled, `state_danger` (#C0392B) when not. The
current card's avatar sits raised (a small negative y offset plus full opacity;
the others sit at reduced opacity). Tapping an avatar jumps the carousel to that
student, reusing the existing `_switch_card(new_index, direction)`.

This band is the fix for problem 1: roster progress is legible without moving.

**Nav row.** `LeftArrow` and `RightArrow` keep `theme_type_variation =
SecondaryButtonL` — `test_nav_arrows_use_theme_variation` pins it — but drop the
`<` / `>` text for `arrow.png` icons, and move from the vertical centre to
y 1730–1850 where a thumb actually rests. `PageIndicator` moves with them and
its dots pick up the same success/danger tint as the roster strip, so progress
reads in two places.

**Safe area.** The nav row's bottom edge sits 70px above the screen bottom. This
scene has no `SafeAreaMargin`; on a device with a home indicator that gap is
tight. Adding one restructures the whole scene and is out of scope here — noted
under "Deferred".

## Section 3 — Card interior

`RosterCard` is 940x1390. Coordinates below are card-local.

| Element | Rect | Notes |
|---|---|---|
| `Nama` | x 30–600, y 30–130 | H2Label, left-aligned (test pins the variation) |
| `Belum` / `Sudah` | x 620–910, y 30–126 | 290x96, clears touch minimum. Stay `Button` on `DangerButton` / `SuccessButton` — both pinned by test |
| `Portrait` | x 190–750, y 150–770 | 560x620, framed, `photo_corner.png` tape at two corners |
| `TraitRow` | x 30–910, y 786–882 | HBoxContainer, `separation = space_sm` (16), three chip `Button`s: `SpecialtyBadge`, `PersonaBadge`, `QuirkBadge` |
| `StickyNotesContainer` | x 30–910, y 906–1096 | five notes, 160x190, at x 30, 210, 390, 570, 750 |
| `CatatanGuru` | x 30–910, y 1126–1346 | ruled strip on `catatan_rule.png` |

Bottom margin 1346–1390 = 44. No dead band remains.

The trait row is **96 tall, not 90**: the chips are `Button` variations and so
are swept by `test_interactive_controls_meet_the_minimum_touch_target`, which
enforces `tokens.touch_target_min` = 96.

**The stamp.** `Belum` / `Sudah` keep their button type and variation so the
tests hold, but are re-skinned with a generated rubber stamp behind the label,
so the state reads as a stamped school document rather than a coloured pill.
This is a texture behind an existing themed button, not a `theme_override_*`.

**The week strip.** Five sticky notes in one row replaces the 3+2 grid, killing
the lopsided hole. Day names abbreviate to `SEN SEL RAB KAM JUM`. Each note
gains its category icon. `StickyNote.gd` grows one `@export icon_texture` on its
root and keeps its existing `day_name` / `activity` setters and its
`DesignTokens.category_color()` tint on `self_modulate`.

**Catatan guru** fills the former void. The note composes from two small tables
rather than a 30-entry lookup: a persona opener plus a quirk observation.

Persona openers:

| Persona | Opener |
|---|---|
| Aktif | Energinya tumpah ke mana-mana. |
| Tekun | Duduk paling depan, catatannya rapi. |
| Kreatif | Selalu punya cara sendiri. |
| Santai | Santai, tapi jangan diremehkan. |
| Seni Dalam Kesunyian | Paling tenang di kelas. |

Quirk observations:

| Quirk | Observation |
|---|---|
| Kutu Buku | Perpustakaan sudah seperti rumah kedua. |
| Penyendiri | Lebih nyaman kerja sendiri daripada berkelompok. |
| Semangat Juang | Tidak pernah menyerah walau tertinggal. |
| Penasaran | Pertanyaannya sering di luar dugaan. |
| Biang Onar | Perlu diawasi kalau jam kosong. |
| Pekerja Keras | Pulang paling akhir, hampir tiap hari. |

Five openers x six observations = thirty combinations from eleven strings. Copy
is first-draft Indonesian, authored not placeholder; it lives in a named `const`
block on `RosterCard.gd` so it is tunable without hunting through logic, per the
project's tunables convention.

## Section 4 — Art

**Reused, already in the repo:** `whiteboard.png`, `arrow.png`,
`shadow_ellipse.png`, `icon_akademis.svg`, `icon_seni.svg`, `icon_olahraga.svg`,
`icon_istirahat.svg`, `icon_libur.svg`, `icon_trait_persona.png`,
`icon_trait_quirk.png`.

**Generated** — PowerShell + `System.Drawing`, transparent, drop-replaceable at
the same path with no code change, and logged in CLAUDE.md's outstanding-debt
list alongside the existing generated-art group:

| File | Purpose |
|---|---|
| `UI/Placeholders/icon_wirausaha.svg` | completes the category icon set; the only one of the six missing today |
| `UI/Placeholders/stamp_sudah.svg` | rubber stamp behind `Sudah` |
| `UI/Placeholders/stamp_belum.svg` | rubber stamp behind `Belum` |
| `UI/StudentList/photo_corner.png` | portrait corner tape |
| `UI/StudentList/roster_avatar_frame.png` | roster strip state ring |
| `UI/StudentList/catatan_rule.png` | ruled strip for the teacher's note |

`icon_wirausaha.svg` is a genuine gap fix, not decoration: `StickyNote` tints for
`Wirausaha` via `category_color()` but has no icon for it, so a Wirausaha day
would be the only note in the week strip without a glyph.

## Section 5 — Theme

**Revised during planning after reading `ThemeFactory` properly.** The original
draft of this section proposed a new `TraitChip` `PanelContainer` variation. That
was redundant:

- `QuirkBadge` and `PersonaBadge` **already exist** as pill-geometry trait chips
  (`_add_button_variation(..., tokens.radius_pill)`), are already in
  `DISPLAY_ROSTER`, and are already in the bake. `ThemeFactory`'s own comment
  calls them "Trait chips (Quirk / Persona)".
- Godot's `Button` has a native `icon` property, so a chip is a `Button` with
  `icon` + `text` + variation. No `TraitChip.tscn` component is needed.
- `RosterAvatar` uses the existing **`GhostButton`** variation, which draws
  nothing at rest specifically so baked art can be the button — exactly this
  case.

So the pass adds **one** variation, `SpecialtyBadge`: `surface_sunken` ground,
`radius_pill`, `brand_primary` border, `text_primary` ink. Specialty gets its own
rather than borrowing a trait badge, because otherwise the three chip kinds would
be indistinguishable. Its accent stays neutral — the category's own colour varies
per student, so it rides on the chip's icon rather than living in a static
variation.

`SpecialtyBadge` is built only from existing tokens, so no new `DesignTokens`
`@export` is added and no editor restart is needed — the discipline that let
`GhostButton` and `CutsceneDialogue` land in Part 2. It **must** be added to
`DISPLAY_ROSTER` (`_add_button_variation` assigns the display font) and the theme
**must** be rebaked, or it renders as an unstyled default `Button` in game while
the suite stays green. It may also need a `RADIUS_EXEMPT` entry in
`tests/test_button_geometry.gd`, as `QuirkBadge` and `PersonaBadge` do.

No `theme_override_*` anywhere. `test_scene_has_no_theme_overrides` and
`test_stickynote_scene_has_no_theme_overrides` both stay green, and the new
templates get the same treatment.

## Section 6 — Tutorial

Three steps become four. `TutorialStepData` entries in
`_populate_default_tutorial_steps()`:

| # | Title | Target | Change |
|---|---|---|---|
| 1 | Daftar Murid | `CardContainer` | unchanged |
| 2 | Status Jadwal | `RosterStrip` | **new** — "Hijau berarti sudah terjadwal, merah berarti belum. Ketuk untuk langsung ke murid itu!" |
| 3 | Navigasi Card | `RightArrow` | unchanged text; target still resolves after the arrow moves to the nav row |
| 4 | Pilih Murid | `""` | unchanged |

The spotlight shader, scrim, `TutorialArrow` and `_highlight_multiple()` are
untouched. `_show_step()` resolves targets by path through `_find_target_node()`,
so the new step needs no new machinery — only that `RosterStrip` exists as a
named node.

`GameState.tutorials_bypassed` and the `tutorial_shown` static both keep working;
`test_debug_tutorial_bypass_skips_the_student_list_tutorial` pins the exact guard
line and it is not being touched.

## Section 7 — Tests

`tests/test_student_list.gd` gains:

- `RosterStrip` exists, holds four `RosterAvatar` instances, each clearing
  `touch_target_min`
- the four `CardContainer/Murid%d` are `RosterCard` instances (the name contract
  survives the extraction)
- `TraitRow` holds three chip `Button`s (`SpecialtyBadge`, `PersonaBadge`,
  `QuirkBadge`) that each clear `touch_target_min`
- `StickyNotesContainer` holds five notes **in one row** — same y, ascending x
- `PageIndicator` and `LeftArrow` / `RightArrow` sit in the lower third of the
  screen, i.e. thumb-reachable
- the tutorial declares four steps and step 2 targets `RosterStrip`

Existing assertions that must stay green unchanged: routes to AturJadwal,
tutorial bypass guard, no theme overrides on either scene, no `Color()` literals
in the scripts, header H1Label, `Belum`/`Sudah`/`Nama` variations, nav-arrow
variation, `StickyNote` per-day wiring, `Juice.stagger_in` wired.

**Ratchet.** `tests/test_viewport_editability.gd` `BASELINE` lists
`res://Scripts/StudentList/student_list.gd` at **8**. That number is frozen and
may only be lowered. This pass must not raise it; extracting the page-indicator
dots into a `PageDot.tscn` template (currently built in
`_build_page_indicators()`) is the cheapest way to lower it, and the
implementation plan should confirm the new number rather than assume it.

**Documentation.** `Scripts/StudentList/student_list.gd` is 792 lines with no
`##` file header. This pass adds one, and every new `@export` on the four new
scripts carries its own `##` line, per `tests/test_script_documentation.gd`.

## Risks and working order

- **Never hand-edit a `.tscn` while the editor is attached.** All scene work goes
  through `scene_open` / `node_create` / `node_set_property` / `scene_save`, or
  `batch_execute`. `anchors_preset` is inert — set the four anchors. Numbers
  unquoted.
- **Scene work first, script work second.** `scene_save` flushes stale script
  buffers over patched `.gd` files. After any `scene_save`, check
  `git diff HEAD -- '*.gd'` for files that were not being edited.
- **`StickyNote.gd` carries a `class_name`.** Adding the `icon_texture`
  `@export` means the next `project_run` fails with "Could not find script for
  class" until `project_manage(op="stop")`, `filesystem_manage(op="scan")` and
  relaunch. A new `@export` on a Resource also needs a full editor restart before
  its default is visible — budget for one.
- **Rebake after the `SpecialtyBadge` variation lands**, via a transient `@tool`
  `McpTestSuite` that calls `ThemeFactory.build()` plus `ResourceSaver.save()`,
  then delete it. `Scripts/Design/BakeTheme.gd` has no MCP entry point.
- **Prefer targeted `test_run(suite=...)`.** A full run drops the bridge; budget
  an editor restart for each one and take them at milestones.

## Deferred

Recorded, not built in this pass:

- **Roster board.** All four students visible at once as pinned paper cards with
  a `MULAI MINGGU` CTA, replacing the carousel. Strongest answer to "who is
  left?" but retires the arrows, the page dots and the `Murid1..4` single-card
  contract, and rewrites the tutorial. Worth its own pass.
- **`SafeAreaMargin` on StudentList.** The nav row clears the screen bottom by
  70px, which is tight against a home indicator. Wrapping the scene is a
  structural change this pass should not carry.
