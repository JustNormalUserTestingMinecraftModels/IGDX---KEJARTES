# Viewport-Editable Visuals & Script Documentation — Design

**Date:** 2026-08-31
**Status:** accepted
**Plan:** `docs/superpowers/plans/2026-08-31-viewport-editable-ui-and-script-docs.md`

## Problem

Two quality-of-life complaints from the programmer working this repo:

1. **Visuals are not editable in the 2D viewport.** Large parts of the UI —
   and some of the gameplay art — exist only at runtime. A human who opens a
   `.tscn` sees an empty or placeholder scene, cannot select the thing they
   want to move, and has to go read GDScript to change a colour or nudge a
   panel.
2. **Scripts do not say what they do or what they affect.** Reading any of
   the four 1,000+ line screens means reconstructing intent from the code.

### Measured baseline (2026-08-31)

Counted over `Scripts/**/*.gd` — 68 scripts, 24,417 lines.

| Symptom | Count | Worst offenders |
|---|---|---|
| Lines constructing a visual node with `Type.new()` | ~340 across 30 files | `DebugManager` 98, `BaseMinigame` 33, `student_card` 32, `report_card` 27, `SchoolDay` 21 |
| Lines calling `add_theme_*` / setting `theme_override` from code | ~550 across 20+ files | `DebugManager` 128, `BaseMinigame` 67, `Menjodohkan` 34, `Variabel` 33 |
| Lines assigning geometry (`position`/`custom_minimum_size`/offsets) from code | ~180 across 20+ files | `DebugManager` 42, `student_card` 16, `StudentCardView` 14 |
| Scripts with no `##` doc block in their first 12 lines | 22 of 68 | — |
| Scripts with zero `@export` | 27 of 68 | — |

Two concrete, verified instances that drive the plan's early tasks:

- **`Scenes/Minigames/Olahraga/MainBola.tscn` is a skeleton.** `FieldBG`,
  `GoalBack`, `GoalNet`, `Crossbar`, `PostLeft`, `PostRight`, `Goalie`,
  `Ball`, `TargetBox` all carry no position and no size in the scene file.
  Every one of them is placed by `MainBola.gd::_setup_layout()` at runtime,
  and its five textures are fetched by hardcoded `load("res://…")` paths in
  `_load_textures()`. Opening the scene shows nothing.
- **`report_card.gd` and `student_card.gd` contain the same 168-line popup
  builder, verbatim.** `report_card.gd:287-455` and
  `student_card.gd:1057-1230` differ only in whitespace. Each builds a
  CanvasLayer, a scrim, a card, a header, an icon, three labels, a `StatBar`
  and a description entirely in code. There are two of these pairs (the stat
  popup and the trait popup), so roughly 680 duplicated lines in total.

## Definition: "viewport-editable"

A visual is viewport-editable when a human can open a `.tscn`, **see it**,
**select it**, change it, save, and have the change survive the next run.

Three legal patterns cover every case in this project. A fourth — build it
with `.new()` in `_ready()` — is what we are retiring.

### Pattern A — static chrome lives in the scene

Anything that always exists is a node in the `.tscn`, positioned and themed by
scene data, reached from the script with `@onready`. No `.new()`, no
`add_theme_*`, no assignment to `position`/`size` from code.

### Pattern B — repeated items are a `PackedScene` template

Rows, cards, slots and list items are authored once as their own small scene
and instantiated at runtime. The template is what the human edits; every
instance follows. The parent script holds
`@export var row_scene: PackedScene = preload(…)` so even the choice of
template is swappable in the Inspector. This is already the established
pattern here — `ActivityRow.tscn`, `DaySummaryStudentRow.tscn`,
`ResultStatRow.tscn`, `StickyNote.tscn`.

### Pattern C — responsive geometry is `@tool` + `@export` knobs

`project.godot` sets `stretch/aspect="expand"`, so viewport height genuinely
varies by device and some layouts must be computed. Those keep their
computation, but:

- every magic number becomes an `@export` with a `##` doc line, so it is a
  labelled slider in the Inspector rather than a literal buried in a function;
- the script is `@tool` and re-runs its layout pass in the editor, so the 2D
  viewport shows the real result and dragging a knob updates it live.

The human edits through the Inspector instead of by dragging, and still sees
the truth in the viewport. That is the honest answer for procedural layout;
faking it with static positions would break on non-16:9 devices.

### Asset references

Art a person might swap is an `@export var … : Texture2D`, so it accepts a
drag-and-drop from the FileSystem dock. `load("res://…")` inside a function is
not acceptable for art. `preload` inside a `const` table is acceptable only
for data-driven sets that are not art (e.g. the cutscene script's CG/text
pairs), and even those get an `@export` override where practical.

`Badminton.gd` is the model already in the tree: `@export_group("Visual - …")`
blocks with a `##` line per entry, and the `.tscn` supplying the textures.

## The ratchet

Converting 340 call sites is not one change. Rather than a rule nothing obeys,
two new suites freeze the current numbers per file and fail if any file grows:

- `tests/test_viewport_editability.gd` — per-file count of runtime visual
  construction. May only go down.
- `tests/test_script_documentation.gd` — per-file list of missing file
  headers, and per-file count of undocumented `@export`s. May only go down.

Both fail in **both** directions: exceeding the baseline is a regression, and
dropping below it means the baseline is stale and must be lowered in the same
commit. That is what makes it a ratchet rather than a wish.

Neither suite instantiates a scene, so both are source-text scans in the
established style of `tests/test_project_hygiene.gd` — cheap, no main scene
required, no coroutines.

## Documentation standard

Four rules, all mechanically checkable:

1. **File header.** Every script opens with a `##` block: what this file is,
   who drives it, and what it affects elsewhere. Where it mutates
   `GameState`, say which keys.
2. **Every `@export` carries a `##` line above it.** Godot surfaces that text
   as the Inspector tooltip, so this rule pays out directly in the editor.
3. **Every function that is not a one-line accessor carries a `##` line**
   stating what it does *and what it affects* — the node it mutates, the
   autoload it writes, the signal it emits.
4. **Section banners** (`# ─── Name ───`) group related members. Already used
   in `Badminton.gd`, `MainBola.gd`, `report_card.gd`; make it universal.

Rules 1 and 2 are enforced by the suite. Rules 3 and 4 are review-time
conventions — a regex cannot tell a useful sentence from a restated function
name, and a test that could be satisfied by `## does the thing` would buy
compliance instead of documentation.

Language follows the existing convention: comments and doc blocks in English,
game-facing identifiers and UI strings in Indonesian.

## Non-goals

- `Scripts/Debug/DebugManager.gd` — a programmatic developer overlay, already
  out of scope for the design system per `CLAUDE.md`. Exempt from both suites.
- `addons/**` and `-REFERENCE-/prototype/**` — third-party and reference-only.
- No visual redesign. Every task is behaviour-preserving: the same pixels,
  reachable from the editor.
- No new persistence in `GameState`.
