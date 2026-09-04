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

Two suites, source-text scans in the style of `tests/test_project_hygiene.gd`
— no scene instantiation needed, no main scene required, both run in well
under a second.

- `tests/test_script_documentation.gd` — **a plain rule.** Every non-exempt
  script must have a `##` file header in its first 12 lines, and every
  `@export` must carry a `##` line immediately above it. This was a ratchet
  (`PENDING_HEADERS`/`PENDING_EXPORT_DOCS` allowlists) until the 2026-08-31
  21-task documentation sweep emptied both; Task 21 deleted the allowlists
  and the two "not stale" tests along with them. There is nothing left to
  paste over — a failure just names the offending file and fixes it.
- `tests/test_viewport_editability.gd` — **still a ratchet.** Counts
  `Type.new()` construction of visual node types per script and compares
  against two frozen dictionaries: `BASELINE` (still owed a conversion —
  see "Known gaps" below) and `ALLOWED` (reviewed and judged permanent, with
  a comment on each entry saying why). A file's count may never exceed
  `BASELINE[file] + ALLOWED[file]`, and a second test fails if either
  dictionary goes stale (a file's count dropped below its entry but the
  entry wasn't lowered to match) — that keeps a conversion from silently
  regressing later. A failing "stale" test prints a ready-to-paste GDScript
  literal — copy it over `BASELINE` (adjusting for anything that should move
  to `ALLOWED` instead), rescan (`filesystem_manage(op="scan")`), and
  re-run. A failing "no growth" test names the offending file directly;
  convert it to Pattern A/B/C, or (rare) add a reviewed, commented entry to
  `ALLOWED`.

## Known gaps

`tests/test_viewport_editability.gd`'s `BASELINE` still carries real,
unconverted runtime UI construction — the 21-task pass (2026-08-31)
converted every shared-across-screens case (popups, cards, rows, panels
duplicated 2-3 times) but did not attempt every remaining file. Largest
entries, as candidates for a future pass:

- `Scripts/AturJadwal/atur_jadwal.gd` (17) and `Scripts/Pengaturan.gd` (12) —
  each builds its own settings/tutorial chrome by hand; likely Pattern A/C
  candidates similar to TutorialPanel.
- `Scripts/CutScene/cut_scene.gd` (15) — dialogue/choice UI, never surveyed
  for extraction.
- `Scripts/Minigames/UI/MinigameTutorial.gd` (12) and
  `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` (11) — both build a
  full popup by hand; likely Pattern B candidates.
- `Scripts/Minigames/UI/BaseMinigame.gd` (4) — `ui_layer`, `pause_button`
  (with its procedural fallback-draw `Control`), and `visual_timer` are
  built once per game session; a real extraction here needs to account for
  the procedural drawing fallback, not just move nodes into a scene.
- The remaining minigames (`Menjodohkan.gd`, `Password.gd`, `Variabel.gd`,
  `Badminton.gd`, `MainBola.gd`, `BuatBatik.gd`, `LombaMenari.gd`, each
  2-8) and screens (`loby.gd`, `inventory.gd`, `rakbarang_1.gd`,
  `student_list.gd`, `StudentCardView.gd`, `DailyDecayOverview.gd`,
  `ResultCheckup.gd`, `SchoolDay.gd`, `student_card.gd`,
  `TutorialArrow.gd`) — smaller counts, mostly single-purpose chrome
  (a background swap, a fallback drawer) not yet surveyed for whether a
  scene conversion is worthwhile. The 2026-09-04 reward pass converted the
  one piece of chrome shared across all seven scoring minigames — the
  in-run score readout — onto `Scenes/Minigames/UI/MinigameScoreHUD.tscn`
  (icon, value, target and a combo chip, all authored nodes), so any future
  survey of these files should start from what's left *after* that: the
  `BASELINE` counts above are unchanged because the readout was never a
  `.new()` call site (it was `theme_override_*` styling on an existing
  `ScoreLabel`, out of scope for this ratchet), but every scoring minigame
  now mounts `MinigameScoreHUD` instead of hand-styling its own label — use
  that template for any new minigame's score display rather than
  reinventing it.

Do not batch-move these into `ALLOWED` without reading each one — the
`ALLOWED` entries that exist were promoted individually in Task 21 after
confirming the construction is genuinely per-call dynamic (varies with game
state) or a conditional texture-vs-procedural swap already accepted
elsewhere in the project, not because moving them was convenient.
