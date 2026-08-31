# Authoring guide: viewport-editable UI

**Plan:** `docs/superpowers/plans/2026-08-31-viewport-editable-ui-and-script-docs.md`
**Spec:** `docs/superpowers/specs/2026-08-31-viewport-editable-ui-and-script-docs-design.md`

## Why

A human must be able to open a `.tscn`, **see** the thing on screen, **select**
it, change it, save, and have the change survive the next run. Anything a
script builds with `SomeControl.new()` at runtime fails all four: the editor
shows nothing (or a placeholder), there is no node to click, there is nowhere
to drag it, and there is no scene data to save.

Measured on 2026-08-31, before this guide existed: roughly 340 lines across 30
scripts construct a visual node at runtime, and 22 scripts had no file header.
Two projects made the cost concrete. `MainBola.tscn` declared every node —
`FieldBG`, `Goalie`, `Ball`, the goalposts — with no position and no size;
`_setup_layout()` placed all of them from magic fractions at runtime, so
opening the scene showed an empty viewport. And `report_card.gd` and
`student_card.gd` each carried the same 168-line stat-popup builder, verbatim
except for whitespace — a change to one silently didn't reach the other.

## Pattern A — static chrome lives in the scene

Anything that always exists is a node in the `.tscn`, positioned and themed by
scene data, reached from the script with `@onready`. No `.new()`, no
`add_theme_*`, no assignment to `position`/`size` from code.

```gdscript
# Before
var lbl := Label.new()
lbl.text = "0 - 0"
lbl.add_theme_font_size_override("font_size", 48)
add_child(lbl)

# After
@onready var score_label: Label = $HUDLayer/ScoreLabel
```

`Scenes/Minigames/Olahraga/MainBola.tscn`'s `HUDLayer` — with `ScoreLabel`,
`AttemptsLabel` and `SwipeHint` as real nodes, styled through
`theme_override_font_sizes` in the scene — is the in-tree example of the good
form.

## Pattern B — repeated items are a `PackedScene` template

Rows, cards, slots and list items are authored once as their own small scene
and instantiated at runtime. The template is what a human edits; every
instance follows. The parent script holds
`@export var row_scene: PackedScene = preload(…)` so even the choice of
template is swappable in the Inspector, not just its contents.

This is the established pattern already in the tree:
`Scenes/AturJadwal/ActivityRow.tscn`,
`Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`,
`Scenes/EndGame/ResultStatRow.tscn`, `Scenes/StudentList/StickyNote.tscn`.

## Pattern C — responsive geometry is `@tool` + `@export` knobs

`project.godot` sets `window/stretch/aspect="expand"`, so viewport height
genuinely varies by device and some layout has to be computed rather than
authored as fixed positions. Those layouts keep their computation, but:

- every magic number becomes an `@export` with a `##` doc line, so it is a
  labelled slider in the Inspector rather than a literal buried in a function;
- the script is `@tool` and re-runs its layout pass whenever a knob changes,
  so the 2D viewport shows the real result and dragging a slider updates it
  live, instead of only being correct once the game runs.

```gdscript
@tool
extends Control

## Goal mouth width, as a fraction of viewport width.
@export_range(0.1, 1.0, 0.01) var goal_width_frac: float = 0.88:
	set(value):
		goal_width_frac = value
		if is_inside_tree():
			_setup_layout()
```

The honest answer for procedural layout is to keep it procedural and make it
previewable — not to fake static positions that would break the moment the
game runs on a different aspect ratio.

## Asset references

Art a person might swap is an `@export var … : Texture2D`, so it accepts a
drag-and-drop from the FileSystem dock straight onto the Inspector slot.
`load("res://…")` inside a function body is not acceptable for art — it
hides the choice from the editor entirely. `preload` inside a `const` table
is acceptable only for data that is not art (e.g. the cutscene script's
CG/text pairs), and even those get an `@export` override where practical.

`Scripts/Minigames/Olahraga/Badminton.gd`'s `@export_group("Visual - …")`
blocks are the model already in the tree — one `##` line per texture slot,
each with a real default, each reachable from the Inspector:

```gdscript
@export_group("Visual - Rackets")
## Drag a PNG here for the Player racket.
@export var player_racket_texture: Texture2D = null
```

## What is exempt

- `Scripts/Debug/DebugManager.gd` — a programmatic developer overlay, already
  out of scope for the design system per `CLAUDE.md`.
- `addons/**` — third-party.
- `-REFERENCE-/prototype/**` — reference-only, not built, not imported.

## The documentation standard

Four rules. Two are mechanically checked; two are review-time judgment calls
no regex can make.

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

Worked example, from `Scripts/GameState.gd`'s header:

```gdscript
## The source of truth for a run.
##
## An autoload. Everything the player does between the main menu and the
## semester end lands here: the approved roster, the week's schedules, the
## current week and grade, money, and the inventory. There is deliberately no
## save system -- a run is session-scoped.
##
## The trap: `approved_students` holds Array[Dictionary] whose keys are the
## UI's names -- `akademis1/2/3` are academic/seni/olahraga, and
## `kepribadian1/2` are mood/energy. StudentData, used inside the simulation,
## has real field names instead. That mismatch is the most common source of
## bugs here.
```

Rules 1 and 2 are enforced by `tests/test_script_documentation.gd`. Rules 3
and 4 are review-time conventions — a test that could be satisfied by
`## does the thing` would buy compliance instead of documentation, so there
is no test for them. Do them anyway; they are the half that actually helps a
reader.

Language follows the existing convention: comments and doc blocks in English,
game-facing identifiers and UI strings in Indonesian.

## How this is enforced

Two ratchet suites, source-text scans in the style of
`tests/test_project_hygiene.gd` — no scene instantiation needed, no main
scene required, both run in well under a second.

- `tests/test_viewport_editability.gd` — counts `Type.new()` construction of
  visual node types per script, compares against a frozen `BASELINE`
  dictionary, and fails if any file's count exceeds its baseline. A second
  test fails if the baseline is stale (a file's count dropped below its
  baseline entry but the entry wasn't lowered to match) — that keeps a
  conversion from silently regressing later.
- `tests/test_script_documentation.gd` — the same shape, for missing file
  headers (`PENDING_HEADERS`) and undocumented `@export`s
  (`PENDING_EXPORT_DOCS`).

A failing "not stale" test prints a ready-to-paste GDScript literal — copy it
over the constant it names, rescan (`filesystem_manage(op="scan")`), and
re-run. A failing "no growth" test names the offending file directly; convert
it to Pattern A/B/C, or add the missing `##` line.

Once every screen is converted and every script documented, both ratchets
close into plain rules with no allowlist — see Task 21 of the plan.
