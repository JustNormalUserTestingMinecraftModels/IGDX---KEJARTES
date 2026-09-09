# Minigame art pass and quiz card chrome — design

**Date:** 2026-09-09
**Status:** approved, not yet implemented
**Scope:** `Scenes/Minigames/Akademis/*` (PilihanGanda, Menjodohkan,
QuestionCard, AnswerCard), `Scenes/Minigames/SeniBudaya/BuatBatik.tscn`,
`Scripts/Minigames/Akademis/PilihanGanda.gd`, the two question-bank JSONs, and
new art imported to `Assets/Images/`. No autoload, no `GameState`, no theme
rebake.

## Problem

Three minigames still ship the placeholder art they were prototyped with, and
in two of them the placeholder actively destroys the authored card styling.

**1. Meme JPGs stand in as card and button art.** `KiperLeft.jpg`,
`KiperRight.jpg` and `DiagonalRight.jpg` — reaction-meme screenshots — are
wired into three `@export` slots:

| Scene | Export | Placeholder |
|---|---|---|
| PilihanGanda | `choice_btn_normal_texture` | `KiperRight.jpg` |
| Menjodohkan | `card_question_bg_texture` | `KiperLeft.jpg` |
| Menjodohkan | `card_answer_bg_texture` | `KiperRight.jpg` |
| BuatBatik | `tool0..3_texture` | `KiperIdle/Left/Right.jpg`, `DiagonalRight.jpg` |
| BuatBatik | `canvas_cloth_texture` | `komodo_dragon.jpg` |

**2. The placeholder does not sit behind the card — it replaces it.**
`QuestionCard.tscn` and `AnswerCard.tscn` each already author a rounded
`StyleBoxFlat` panel (corner radius 10, border, shadow). But
`Menjodohkan.gd:439-443` and `:484-488` do this whenever the bg export is set:

```gdscript
if bg_tex and card_question_bg_texture:
    bg_tex.texture = card_question_bg_texture
    var transparent_sb = StyleBoxEmpty.new()
    card.add_theme_stylebox_override("panel", transparent_sb)
```

The authored card style is swapped for `StyleBoxEmpty`, so the meme is the
entire card. Clearing the export skips this block and the real card returns —
no script change needed on the Menjodohkan side.

**3. PilihanGanda has no rounded-rect fallback at all.** Clearing its texture
export alone is not enough: `answer_btn_normal_style` is null, so buttons fall
back to the theme's base `Button`, which `ThemeFactory._build_base_overrides`
builds with `_pill()` — a capsule, not a rounded rectangle.

**4. Emoji as iconography.** BuatBatik's four tool slots render `✏ 🖊 🎨 🔥`
as `IconLabel` text, which CLAUDE.md bans outright.

**5. No real batik art.** `layer0..3_pattern_texture` are all null, so each
completed step reveals a flat translucent `ColorRect` from `LAYER_COLORS`
rather than a batik phase.

## Approach

**Author the styling locally in the minigame scenes and wire all new art
through the `@export` knobs that already exist.**

CLAUDE.md places `Scenes/Minigames/**` explicitly outside the design-system
scope ("minigames inherit the Theme but had no polish pass"), and those scenes
already author local `StyleBoxFlat` sub-resources. This follows the pattern
that is already there, and needs no `ThemeFactory` change, no rebake, and no
editor restart.

**Rejected: promote quiz chrome into `ThemeFactory`** as `QuizCard` /
`QuizChoiceButton` type variations. Cleaner in the abstract, but it
contradicts the minigame scoping rule, requires a manual theme rebake (there
is no MCP entry point for `BakeTheme.gd`), and drags in `DISPLAY_ROSTER`
updates in `tests/test_theme_factory.gd` — a lot of moving parts for chrome
used on two screens.

**Rejected: clear the placeholders and stop.** Cheapest, but PilihanGanda
would render pills instead of rounded rectangles, would lose its press
animation (see below), and neither game would gain heading typography.

## 1. PilihanGanda

### Rounded-rect answer buttons

Clear `choice_btn_normal_texture`. Author three `StyleBoxFlat` sub-resources in
`PilihanGanda.tscn` and assign them to the exports that already exist for
exactly this path:

| Export | Style |
|---|---|
| `answer_btn_normal_style` | card surface, corner radius 24, border, drop shadow |
| `answer_btn_correct_style` | same geometry, `state_success` fill |
| `answer_btn_wrong_style` | same geometry, `state_danger` fill |

Radius 24 matches the project's `radius_md` token. The shadow lives in the
stylebox, the way every other stylebox in this project carries its own.

### Fix the no-texture path in `_apply_choice_btn_textures()`

The function early-returns when no texture is set:

```gdscript
func _apply_choice_btn_textures(btn: Button) -> void:
    if choice_btn_normal_texture == null:
        if answer_btn_normal_style:
            btn.add_theme_stylebox_override("normal", answer_btn_normal_style)
        return          # skips everything below
    ...
    btn.pivot_offset = ...
    btn.button_down.connect(_on_choice_btn_down.bind(btn))
    btn.button_up.connect(_on_choice_btn_up.bind(btn))
```

Everything after the return — the press-shrink tween wiring and the
hover/pressed/disabled styleboxes — is skipped. Taking the flat path today
would silently drop the button press feel.

Restructure so both paths share that tail: the flat branch sets
`normal`/`hover` from the exported style and derives `pressed`/`disabled` by
duplicating it and applying the **existing** `choice_btn_pressed_tint` and
`choice_btn_disabled_tint` exports, then both branches fall through to the
shared press-animation wiring. No new exports.

### Remove the per-button shadow Panel

`_make_choice_shadow()` (added earlier on 2026-09-09) attaches a transparent
`Panel` with `show_behind_parent` to every choice button purely to cast a
shadow. The authored stylebox now carries `shadow_size`/`shadow_offset`
directly, so that node is redundant — delete the helper and its call site.

This lowers real runtime construction in the file from 2 to 1, so
`tests/test_viewport_editability.gd`'s `ALLOWED` entry for `PilihanGanda.gd`
must drop back to `1` in the same commit, with its comment restored. Leaving
it at 2 fails `test_baseline_is_not_stale`, which is the ratchet working as
intended.

### Head text

Set the scene's existing `font` export to `res://Assets/Fonts/Boohong.otf`.
`PilihanGanda.gd` already pushes that font onto the progress label, the
question label and every choice button. The sizes are already exactly on
heading tokens — `question_font_size` 48 = `font_h2`, `answer_btn_font_size`
36 = `font_title` — so this single Inspector value turns the screen's text
into heading typography with no code churn.

## 2. Menjodohkan

**Clear `card_question_bg_texture` and `card_answer_bg_texture`.** That alone
restores the authored rounded card, per the `StyleBoxEmpty` mechanism above.

**Raise the card corner radius from 10 to 24** in `QuestionCard.tscn` and
`AnswerCard.tscn`, matching `radius_md` and the PilihanGanda buttons.

**Head text on each card's `TextLabel`:** remove the static
`theme_override_colors/font_color` and `theme_override_font_sizes/font_size`
from both `.tscn` files and set `theme_type_variation = &"H2Label"`
(Boohong display font, `text_primary` ink).

**The runtime size ladder stays.** `Menjodohkan.gd:418-426` sizes the label by
string length (36 / 32 / 28 / 24) and drops it to 24 again when the question
carries an image (`:434-435`). A `theme_override` beats a type variation, so
the variation supplies font and colour while the ladder keeps long questions
inside the fixed 850×380 card. Do not "clean this up" — removing it overflows
long questions. Boohong is wider than Open Sans at the same size, so verify
the longest question live; adjust the ladder only if text actually clips.

## 3. BuatBatik

### Tools

The Downloads numbering skips 2; the images map unambiguously by what they
depict.

| Export | Tool | Source file | Imported as |
|---|---|---|---|
| `tool0_texture` | Pencil | `Tool0.png` (pencil) | `batik_tool_pencil.png` |
| `tool1_texture` | Canting | `Tool1.png` (canting) | `batik_tool_canting.png` |
| `tool2_texture` | Pewarna | `Tool3.png` (dye bottles) | `batik_tool_pewarna.png` |
| `tool3_texture` | Kompor | `Tool4.png` (wax wok) | `batik_tool_kompor.png` |

`_apply_visual_exports()` hides `IconLabel` whenever a tool texture is present,
so wiring these also removes the four emoji glyphs.

**Tool slot backgrounds.** Each slot sits on a hardcoded `Bg` `ColorRect`
(grey / red / blue / yellow). No replacement art was supplied and the tool PNGs
are transparent, so give each of the four slots the same rounded card
background — radius 24 on the card surface, matching the quiz chrome — instead
of four arbitrary colour blocks.

A `ColorRect` draws a flat rectangle and cannot carry a `StyleBox`, so each
`Bg` node becomes a `Panel` with a rounded `StyleBoxFlat`. Godot cannot change
a node's type in place: each one is delete-and-recreate through the editor,
keeping the name `Bg` and its full-rect anchors so
`BuatBatik.gd:181-183` — which walks every `Control` child of a slot and sets
`MOUSE_FILTER_IGNORE` so the background never steals the drag — keeps working
untouched.

### Canvas phases

Five phases map to one base plus four step reveals. Verified by inspection:
fase1 is blank cloth with fabric folds, fase2 is the pencil sketch.

| Export | Phase | Source file |
|---|---|---|
| `canvas_cloth_texture` | starting cloth | `batik fase1.png` |
| `layer0_pattern_texture` | after Pencil | `batik fase2.png` |
| `layer1_pattern_texture` | after Canting | `batik fase3.png` |
| `layer2_pattern_texture` | after Pewarna | `batik fase4.png` |
| `layer3_pattern_texture` | after Kompor | `batik fase5.png` |

`_add_correct_layer()` already builds a full-rect `TextureRect` per step and
stacks it in `LayersContainer`. Each phase image is a full opaque cloth, so
each reveal covers the previous one and the progression reads correctly with
no script change.

**Layer captions stay as they are.** Each revealed layer draws a centred
`LAYER_LABELS` caption at font size 16 with a black outline. It is illegible at
1080 wide, but fixing it is a separate concern from this art pass.

## 4. Quiz question images

Five illustrated PNGs replace the five photo JPGs the question banks load.

| Source file | Imported as | Replaces |
|---|---|---|
| `monas.png` | `Assets/Images/monas.png` | `monas_monument.jpg` |
| `borobudur.png` | `Assets/Images/borobudur.png` | `borobudur_temple.jpg` |
| `komodo.png` | `Assets/Images/komodo.png` | `komodo_dragon.jpg` |
| `wayang.png` | `Assets/Images/wayang.png` | `wayang_kulit.jpg` |
| `bhineka tunggal ika.png` | `Assets/Images/bhineka_tunggal_ika.png` | `garuda_pancasila.jpg` |

Three places reference them and all three must be repointed:

- `Assets/Data/pilihanganda_questions.json`
- `Assets/Data/menjodohkan_questions.json`
- the `fallback_questions` array in `PilihanGanda.gd` (hardcoded
  `res://Assets/Images/monas_monument.jpg`)

Delete a superseded `.jpg` only after confirming nothing else references it.
`BuatBatik.tscn` currently holds `borobudur_temple.jpg` and `komodo_dragon.jpg`
as `ext_resource` entries; both drop out of that scene as part of this work.

## Asset import locations

Batik art goes to `Assets/Images/Textures/` as `batik_fase1..5.png` and
`batik_tool_*.png`, following the flat convention already used for minigame art
(`Gawang.jpg`, `field_bg.jpg`, `dance_*.png`, `raket_*.png`). Quiz images go to
`Assets/Images/` beside the files they replace.

Copies are made from `C:\Users\user\Downloads\`; source files are left in place.

## Out of scope

Recorded so they are not mistaken for oversights:

- The `Q1` badges and the 🔒 lock overlay in `QuestionCard`/`AnswerCard` keep
  their current styling. "Head text" means the main content text of each box.
- The centred batik layer captions (see above).
- `MinigameTutorial`, score HUD and result popup chrome are untouched.

## Testing

1. Full `test_run` — 1085 tests across 78 suites, expected green. No suite
   targets these three minigames directly, so the exposure is the shared
   ratchets: `test_viewport_editability` (construction counts) and
   `test_script_documentation` (`##` on every script and `@export`).
2. `test_viewport_editability.gd`'s `ALLOWED` entry for `PilihanGanda.gd`
   drops 2 → 1 in the same commit.
3. Live pass through all three minigames via the debug overlay's
   **Minigames → Luncurkan Minigame Mandiri** launcher, screenshotting each:
   - PilihanGanda: rounded answer buttons, heading text, press-shrink still
     animates, correct/wrong flash still recolours.
   - Menjodohkan: rounded cards on both carousels, heading text, longest
     question does not clip.
   - BuatBatik: four tool icons with no emoji, and all four steps completed in
     order so every batik phase is seen.

## Risks

- **Editor cache.** Scene work before script work, and check
  `git diff HEAD -- '*.gd'` after any `scene_save`, per CLAUDE.md rule 4b.
- **Boohong metrics.** Wider than Open Sans; the Menjodohkan size ladder and
  the PilihanGanda button height (`answer_btn_min_height` 100) are the two
  places text could clip. Both are verified live, and both are single
  Inspector values if adjustment is needed.
- **Import settings.** The batik phases are large (0.8–1.5 MB PNGs) and the
  cloth is portrait; they render into a fixed `CanvasRect`, so default import
  settings are expected to be fine.
