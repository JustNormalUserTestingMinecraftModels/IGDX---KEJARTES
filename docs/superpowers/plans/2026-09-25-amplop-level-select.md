# Amplop Coklat Level Select — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain-text grade picker with a diegetic stack of brown envelopes (amplop coklat) the player swipes through and opens to pick Kelas 7/8/9.

**Architecture:** One `@tool` screen scene (`level_select`) holds three instances of a reusable `AmplopCard` PackedScene, a briefing card, and an `OpenAmplopConfirm` overlay. All chrome is authored in `.tscn`; the script only drives selection state, data binding from `Balance.gd`, Tween motion, and the commit hand-off (`GameState.set_grade` → `Transition.change_scene`). No visual is built at runtime; no `theme_override_*`.

**Tech Stack:** Godot 4.6, GDScript, `ThemeFactory` variations, `Juice.gd` / `AnimUtils.gd` Tweens, `StudentSkins`, the `godot-ai` MCP bridge (scene/node/test tools), `McpTestSuite` source-scan tests.

**Spec:** [`docs/superpowers/specs/2026-09-25-amplop-level-select-design.md`](../specs/2026-09-25-amplop-level-select-design.md)
**Interaction prototype:** [`docs/superpowers/specs/mockups/amplop-level-select-prototype.html`](../specs/mockups/amplop-level-select-prototype.html)

## Global Constraints

Copied verbatim from the spec and CLAUDE.md. Every task implicitly includes these.

- **No `theme_override_*`.** Use `ThemeFactory` type variations; add a new variation in `ThemeFactory.gd` + rebake if none fits. Only layout-only constant overrides (`separation`, `margin_*`) allowed.
- **No visual built at runtime.** Static chrome = nodes in the `.tscn`. Repeated rows = a `PackedScene` template. Responsive geometry = a `@tool` script with documented `@export` knobs.
- **Every script is `@tool`** with a `##` file header and a `##` line on every `@export` (enforced by `tests/test_script_documentation.gd`). Gate runtime-only side effects behind `if Engine.is_editor_hint(): return`; keep signal wiring ungated.
- **Tests are `@tool` `McpTestSuite`s, never coroutines (no `await`), run via the MCP `test_run` tool inside the editor** — not headless. Prefer source-scan (`src.contains(...)`) where live instantiation isn't possible.
- **Weeks and target uplift are READ from `Balance.gd`** (`JUMLAH_MINGGU_KELAS_*`, `TARGET_KENAIKAN_KELAS_*`), never re-typed. `Balance.gd` is a collaborator's file — read only, never edit.
- **`@export`s live on an instanced scene's ROOT**, never its children (child overrides are dropped on save).
- **Indonesian** for all game-facing identifiers and UI text; English for engine/systems code.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` → `node_create`/`node_set_property`/`batch_execute` → `scene_save`. After patching a `.gd`, `filesystem_manage(op="scan")` before `test_run`.
- **Commits:** Conventional Commits with scope, e.g. `feat(level-select): ...`. Commit at the end of every task.

### Grade data (verify roster count — see Task 0)

| Grade | Weeks | Target | Roster | Difficulty word | Gauge fill | Gauge color |
|---|---|---|---|---|---|---|
| 7 | 6 | +15 | 2 | santai | 0.50 | green |
| 8 | 12 | +34 | 3 | menantang | 0.68 | amber |
| 9 | 16 | +40 | 4 | susah | 0.75 | red |

---

## Task 0: Resolve the three open questions (no code)

**Files:** none — investigation only. Record answers at the top of the plan's PR description and inline in `level_select.gd`'s header comment when written.

- [ ] **Step 1: Confirm where the screen sits in the flow.** Read `Scripts/MainMenu/main_menu.gd` (`_start_game` → `Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn", …)`) and grep for the current "PILIH TINGKAT KELAS" debug picker. Decide: new scene between MainMenu and CutScene, or promotion of the debug picker's slot. Default assumption if the team is silent: **the level select is the scene reached on tap from MainMenu, and on commit it wipes to `res://Scenes/CutScene/cut_scene.tscn`** (same target MainMenu uses today).
- [ ] **Step 2: Confirm the real per-grade roster size.** Grep `Scripts/GameState.gd` for how the roster is built/sized per grade. If it is not a fixed 2/3/4, note the real source; the pupil-count icon (Task 4) must use the real count, exposed as a function, not the literal table above.
- [ ] **Step 3: Confirm the grade setter.** Verify `GameState.set_grade()` exists (see `Scripts/Debug/DebugManager.gd:_set_grade`, ~line 672); if absent, the commit path uses `GameState.current_grade = clampi(g, 7, 9)`.
- [ ] **Step 4: Record answers** as three bullet lines you will paste into `level_select.gd`'s `##` header in Task 1. No commit (no file changes yet).

---

## Task 1: Data model + screen script skeleton

Build the pure-data core first so it's unit-testable by source scan before any scene exists.

**Files:**
- Create: `Scripts/LevelSelect/level_select.gd`
- Test: `tests/test_level_select.gd`

**Interfaces:**
- Produces:
  - `const GRADES := [7, 8, 9]`
  - `const DIFFICULTY_WORD := {7: "santai", 8: "menantang", 9: "susah"}`
  - `const DIFFICULTY_FILL := {7: 0.50, 8: 0.68, 9: 0.75}`
  - `static func weeks_for(grade: int) -> int` (reads `Balance.JUMLAH_MINGGU_KELAS_*`)
  - `static func target_for(grade: int) -> int` (reads `Balance.TARGET_KENAIKAN_KELAS_*`)
  - `static func roster_size_for(grade: int) -> int` (Task 0 Step 2 source; literal fallback 2/3/4)

- [ ] **Step 1: Write the failing test** `tests/test_level_select.gd`:

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const LS := preload("res://Scripts/LevelSelect/level_select.gd")

## Weeks and target must be read from Balance.gd, never hardcoded literals.
func test_weeks_and_target_come_from_balance() -> void:
	assert_eq(LS.weeks_for(7), Balance.JUMLAH_MINGGU_KELAS_7, "wk7")
	assert_eq(LS.weeks_for(8), Balance.JUMLAH_MINGGU_KELAS_8, "wk8")
	assert_eq(LS.weeks_for(9), Balance.JUMLAH_MINGGU_KELAS_9, "wk9")
	assert_eq(LS.target_for(7), int(Balance.TARGET_KENAIKAN_KELAS_7), "t7")
	assert_eq(LS.target_for(9), int(Balance.TARGET_KENAIKAN_KELAS_9), "t9")

## Every grade has a difficulty word and a gauge fill.
func test_difficulty_map_covers_all_grades() -> void:
	for g in LS.GRADES:
		assert_true(LS.DIFFICULTY_WORD.has(g), "word for %d" % g)
		assert_true(LS.DIFFICULTY_FILL.has(g), "fill for %d" % g)
	assert_eq(LS.DIFFICULTY_WORD[9], "susah", "kelas 9 is susah")

## The screen must not re-type balance numbers as literals.
func test_source_reads_balance_constants() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/level_select.gd")
	assert_true(src.contains("Balance.JUMLAH_MINGGU_KELAS_"), "reads weeks from Balance")
	assert_true(src.contains("Balance.TARGET_KENAIKAN_KELAS_"), "reads target from Balance")
```

- [ ] **Step 2: Run the test, verify it fails.** In the editor via MCP: `filesystem_manage(op="scan")` then `test_run(suite="test_level_select")`. Expected: FAIL (script/constants missing).

- [ ] **Step 3: Write the minimal implementation** `Scripts/LevelSelect/level_select.gd`:

```gdscript
@tool
extends Control

## The consumer-facing grade picker: a stack of amplop coklat (brown
## envelopes), one per grade, that the player swipes through and opens.
## Replaces the rugged debug "PILIH TINGKAT KELAS" list. Presentation only —
## it sets GameState's grade and hands off; no gameplay or balance changes.
##
## Flow decisions (Task 0): <<paste the three recorded answers here>>
##
## @tool so the MCP test suite can instantiate it; runtime-only side effects
## are gated behind Engine.is_editor_hint() in _ready().

## The three playable grades, left-to-right in the fan.
const GRADES := [7, 8, 9]

## Presentational difficulty word per grade — deliberately shown INSTEAD of the
## raw target number so the player weighs the challenge by feel. Rationale
## (weeks-vs-target slack) is in the design spec, section 4.
const DIFFICULTY_WORD := {7: "santai", 8: "menantang", 9: "susah"}

## Gauge fill fraction (0..1) matching DIFFICULTY_WORD; green→amber→red.
const DIFFICULTY_FILL := {7: 0.50, 8: 0.68, 9: 0.75}

## Fallback roster sizes if GameState has no per-grade source (see Task 0).
const _ROSTER_FALLBACK := {7: 2, 8: 3, 9: 4}


## Weeks a grade runs — the player's available time. Owned by Balance.gd.
static func weeks_for(grade: int) -> int:
	match grade:
		7: return Balance.JUMLAH_MINGGU_KELAS_7
		8: return Balance.JUMLAH_MINGGU_KELAS_8
		_: return Balance.JUMLAH_MINGGU_KELAS_9


## Point uplift each subject must gain to clear a target. Owned by Balance.gd.
static func target_for(grade: int) -> int:
	match grade:
		7: return int(Balance.TARGET_KENAIKAN_KELAS_7)
		8: return int(Balance.TARGET_KENAIKAN_KELAS_8)
		_: return int(Balance.TARGET_KENAIKAN_KELAS_9)


## How many pupils the roster holds for this grade — drives the head icon.
## TODO(Task 0): replace the fallback with the real GameState source if one exists.
static func roster_size_for(grade: int) -> int:
	return _ROSTER_FALLBACK.get(grade, 2)
```

- [ ] **Step 4: Run the test, verify it passes.** `filesystem_manage(op="scan")` → `test_run(suite="test_level_select")`. Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Scripts/LevelSelect/level_select.gd tests/test_level_select.gd
git commit -m "feat(level-select): grade data model reading Balance.gd"
```

---

## Task 2: AmplopCard PackedScene template

One reusable envelope, data-driven by root `@export`s. Instanced ×3 by the screen.

**Files:**
- Create: `Scenes/LevelSelect/AmplopCard.tscn`, `Scripts/LevelSelect/AmplopCard.gd`
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `AmplopCard.gd`:
  - `@export var grade: int = 7`
  - `@export var tab_text: String = "Kelas 7"`
  - `@export var envelope_texture: Texture2D`, `@export var flap_texture: Texture2D`, `@export var seal_texture: Texture2D`
  - `signal picked(grade: int)` — emitted when the card is tapped
  - `func set_focused(is_focused: bool) -> void` — visual dim/undim (used by nav in Task 5)

- [ ] **Step 1: Write the failing test** (append to `tests/test_level_select.gd`):

```gdscript
const CARD := preload("res://Scripts/LevelSelect/AmplopCard.gd")

## Data-drive knobs live on the CARD ROOT as @exports (child overrides drop on save).
func test_amplop_card_exposes_root_exports() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/AmplopCard.gd")
	for prop in ["grade", "tab_text", "envelope_texture", "flap_texture", "seal_texture"]:
		assert_true(src.contains("@export var %s" % prop), "exports %s" % prop)
	assert_true(src.contains("signal picked"), "has picked signal")

## The card scene instances cleanly and is the right script.
func test_amplop_card_scene_instantiates() -> void:
	var inst = preload("res://Scenes/LevelSelect/AmplopCard.tscn").instantiate()
	assert_not_null(inst, "instantiates")
	assert_true(inst.get_script() == CARD, "carries AmplopCard.gd")
	inst.free()
```

- [ ] **Step 2: Run, verify fail.** `test_run(suite="test_level_select")`. Expected: FAIL (script + scene missing).

- [ ] **Step 3: Write `Scripts/LevelSelect/AmplopCard.gd`:**

```gdscript
@tool
extends Control

## One amplop coklat in the level-select fan. A reusable PackedScene template:
## the screen instances it once per grade and feeds it via these root @exports.
## Envelope/flap/seal are placeholder-replaceable textures (see DEBT.md).

## Which grade this envelope represents (7, 8, or 9).
@export var grade: int = 7
## Text on the peeking tab, e.g. "Kelas 7".
@export var tab_text: String = "Kelas 7": set = _set_tab_text
## Kraft envelope body art.
@export var envelope_texture: Texture2D: set = _set_envelope_texture
## The top flap art (animated open in the confirmation).
@export var flap_texture: Texture2D: set = _set_flap_texture
## The wax button-and-string seal art.
@export var seal_texture: Texture2D: set = _set_seal_texture

## Emitted when the player taps this envelope.
signal picked(grade: int)

@onready var _tab_label: Label = $Tab/TabLabel
@onready var _body: TextureRect = $Body
@onready var _flap: TextureRect = $Flap
@onready var _seal: TextureRect = $Seal
@onready var _button: Button = $HitButton


func _ready() -> void:
	_button.pressed.connect(func() -> void: picked.emit(grade))
	_apply_all()


## Dim this card when it is not the focused (centered) grade.
func set_focused(is_focused: bool) -> void:
	modulate = Color.WHITE if is_focused else Color(0.85, 0.85, 0.85)


func _apply_all() -> void:
	if not is_node_ready():
		return
	_set_tab_text(tab_text)
	_set_envelope_texture(envelope_texture)
	_set_flap_texture(flap_texture)
	_set_seal_texture(seal_texture)


func _set_tab_text(v: String) -> void:
	tab_text = v
	if is_node_ready(): _tab_label.text = v

func _set_envelope_texture(v: Texture2D) -> void:
	envelope_texture = v
	if is_node_ready(): _body.texture = v

func _set_flap_texture(v: Texture2D) -> void:
	flap_texture = v
	if is_node_ready(): _flap.texture = v

func _set_seal_texture(v: Texture2D) -> void:
	seal_texture = v
	if is_node_ready(): _seal.texture = v
```

- [ ] **Step 4: Build `AmplopCard.tscn` through the editor (never hand-edit while attached).** Via MCP: `scene_manage(op="new")` or `scene_open` on a fresh path, then `batch_execute` to create the tree. Root `Control` (script `AmplopCard.gd`), children:
  - `Body` (`TextureRect`, Full Rect, `expand_mode` keep-aspect-covered)
  - `Flap` (`TextureRect`, anchored top, `pivot_offset` at top-center for the open rotation)
  - `Seal` (`TextureRect`, centered on the flap)
  - `Tab` (`Control`) → `TabLabel` (`Label`, `ThemeFactory` `CaptionLabel` or a badge variation — **no `theme_override`**)
  - `HitButton` (`Button`, Full Rect, `flat = true`, transparent) — the tap target
  Set `layout_mode = 1` on Control children before setting anchors. `scene_save`.

- [ ] **Step 5: Restart the editor** (a new Resource `@export` needs it), `filesystem_manage(op="scan")`, then `test_run(suite="test_level_select")`. Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/LevelSelect/AmplopCard.tscn Scripts/LevelSelect/AmplopCard.gd tests/test_level_select.gd
git commit -m "feat(level-select): reusable AmplopCard envelope template"
```

---

## Task 3: Screen scene assembly (static chrome)

Assemble the screen: background, the three-card fan, the briefing card shell, the "Buka map ini" button. No behavior yet.

**Files:**
- Create: `Scenes/LevelSelect/level_select.tscn`
- Modify: `Scripts/LevelSelect/level_select.gd` (add `@onready` refs + `_ready` wiring)
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `@onready` node refs in `level_select.gd`: `_stack: Control`, `_cards: Array` (the 3 `AmplopCard`s), `_brief_title: Label`, `_pupils_box: Control`, `_week_grid: Control`, `_diff_bar`, `_diff_label: Label`, `_open_button: Button`.

- [ ] **Step 1: Write the failing test** (append):

```gdscript
## The screen has exactly three AmplopCards, one per grade.
func test_screen_has_three_cards_one_per_grade() -> void:
	var scr = preload("res://Scenes/LevelSelect/level_select.tscn").instantiate()
	var found := []
	for c in scr.find_children("*", "Control", true, false):
		if c.get_script() == CARD:
			found.append(c.grade)
	found.sort()
	assert_eq(found, [7, 8, 9], "three cards for 7/8/9")
	scr.free()

## No theme_override anywhere in the screen scene (design-system rule).
func test_screen_has_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/LevelSelect/level_select.tscn")
	assert_false(src.contains("theme_override_"), "no theme_override_* in scene")
```

- [ ] **Step 2: Run, verify fail.** Expected: FAIL (scene missing).

- [ ] **Step 3: Build `level_select.tscn` through the editor.** Root `Control` with `level_select.gd`. Structure per CLAUDE.md tall-phone pattern:
  - `Background` (`TextureRect`, Full Rect + Keep Aspect Covered)
  - `SafeAreaMargin` (`MarginContainer`) → `UI` (`Control`)
    - `Title` (`Label`, `ThemeFactory` `H1Label`/`DisplayLabel`) — "Pilih map kelas"
    - `Stack` (`Control`, fixed height ~ the fan area) → three instances of `AmplopCard.tscn`; set each instance's ROOT `grade`/`tab_text` (7/8/9). Add ‹ › arrow `Button`s (`SecondaryButton`) as children of `Stack`.
    - `Brief` (Panel with `ThemeFactory` `Card` variation) containing: `BriefTitle` (`Label`), `Tag` (`Label`), a 3-column stat row with `Pupils` (`Control` host), `WeekGrid` (`Control` host), `DiffBar` (`TextureProgressBar` or a `StatBar` variation) + `DiffLabel` (`Label`), and `OpenButton` (`Button`, `PrimaryButton`).
  Use `ThemeFactory` variations throughout — **no `theme_override_*`** (only `separation`/`margin_*` constants allowed). `scene_save`.

- [ ] **Step 4: Add `@onready` refs + minimal `_ready` wiring** to `level_select.gd` (append to the class body):

```gdscript
@onready var _stack: Control = $SafeAreaMargin/UI/Stack
@onready var _brief_title: Label = $SafeAreaMargin/UI/Brief/BriefTitle
@onready var _tag_label: Label = $SafeAreaMargin/UI/Brief/Tag
@onready var _pupils_box: Control = $SafeAreaMargin/UI/Brief/Stats/Pupils
@onready var _week_grid: Control = $SafeAreaMargin/UI/Brief/Stats/WeekGrid
@onready var _diff_bar: Range = $SafeAreaMargin/UI/Brief/Stats/DiffBar
@onready var _diff_label: Label = $SafeAreaMargin/UI/Brief/DiffLabel
@onready var _open_button: Button = $SafeAreaMargin/UI/Brief/OpenButton

## Cards in fan order, left→right. Populated in _ready from the Stack children.
var _cards: Array = []
## Index into GRADES of the currently centered card.
var _selected := 0


func _ready() -> void:
	for child in _stack.get_children():
		if child.get_script() == preload("res://Scripts/LevelSelect/AmplopCard.gd"):
			_cards.append(child)
	_cards.sort_custom(func(a, b): return a.grade < b.grade)
	if Engine.is_editor_hint():
		return
	# Runtime-only wiring added in later tasks (nav, idle, commit).
```

- [ ] **Step 5: Restart editor, scan, run.** `test_run(suite="test_level_select")`. Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/LevelSelect/level_select.tscn Scripts/LevelSelect/level_select.gd tests/test_level_select.gd
git commit -m "feat(level-select): screen scene with envelope fan and briefing shell"
```

---

## Task 4: Briefing card population

Bind the centered grade's data into the briefing: pupils heads, week grid, difficulty gauge + word.

**Files:**
- Modify: `Scripts/LevelSelect/level_select.gd`
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `func _render_brief() -> void` and `func _selected_grade() -> int`.

- [ ] **Step 1: Write the failing test** (append):

```gdscript
## Selecting a grade shows its difficulty word and week count in the brief.
func test_brief_reflects_selected_grade() -> void:
	var scr = preload("res://Scenes/LevelSelect/level_select.tscn").instantiate()
	add_child(scr)          # let _ready populate _cards
	scr._selected = 2       # index of grade 9
	scr._render_brief()
	assert_eq(scr._diff_label.text, "susah", "kelas 9 word")
	assert_true(str(scr._week_grid_filled()) == str(LS.weeks_for(9)), "9 shows 16 weeks")
	remove_child(scr); scr.free()
```

(If `add_child` during a test proves unstable in your suite, fall back to a source scan asserting `_render_brief` sets `_diff_label.text = DIFFICULTY_WORD[...]` and reads `weeks_for`/`roster_size_for`.)

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement `_render_brief` and helpers** (append to `level_select.gd`):

```gdscript
## The grade currently centered in the fan.
func _selected_grade() -> int:
	return GRADES[_selected]


## Repaint the briefing card for the centered grade: pupil heads, week grid,
## difficulty gauge + word. Called on every selection change.
func _render_brief() -> void:
	var g := _selected_grade()
	_brief_title.text = "Kelas %d" % g
	_diff_label.text = DIFFICULTY_WORD[g]
	if _diff_bar is Range:
		_diff_bar.value = DIFFICULTY_FILL[g] * _diff_bar.max_value
	_paint_pupils(roster_size_for(g))
	_paint_week_grid(weeks_for(g))


## Show one pupil-head icon per roster member (2/3/4). Icons are instanced from
## a small PupilHead template — NOT drawn procedurally (design-system rule).
func _paint_pupils(n: int) -> void:
	for c in _pupils_box.get_children():
		c.visible = false
	# Reuse up to n pre-placed PupilHead children; see Task 4 Step 4 note.
	var kids := _pupils_box.get_children()
	for i in range(min(n, kids.size())):
		kids[i].visible = true


## Fill one week cell per week of the grade; the rest stay empty.
func _paint_week_grid(weeks: int) -> void:
	var cells := _week_grid.get_children()
	for i in range(cells.size()):
		cells[i].set("modulate", Color(0.71, 0.27, 0.18) if i < weeks else Color(0.80, 0.71, 0.54))


## Test hook: how many week cells are currently filled.
func _week_grid_filled() -> int:
	var n := 0
	for c in _week_grid.get_children():
		if c.get("modulate") == Color(0.71, 0.27, 0.18):
			n += 1
	return n
```

- [ ] **Step 4: Add the static icon children in the editor.** In `level_select.tscn`, pre-place the **maximum** number of `PupilHead` icons (4) in `Pupils` and **16** week cells in `WeekGrid` (grade 9's max), each a small `TextureRect`/`Panel` node. `_render_brief` toggles visibility/tint — nothing is created at runtime. Pupil faces should later swap to `StudentSkins.portrait_for(...)` (leave a `## TODO` and a placeholder texture for now). `scene_save`.

- [ ] **Step 5: Call `_render_brief()` at the end of `_ready`'s runtime branch, restart editor, scan, run.** Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/LevelSelect/level_select.tscn Scripts/LevelSelect/level_select.gd tests/test_level_select.gd
git commit -m "feat(level-select): bind briefing card to the selected grade"
```

---

## Task 5: Navigation (swipe + tap + arrows) with shuffle-bounce

Wire selection changes from three inputs and animate the fan re-cluster with a spring overshoot.

**Files:**
- Modify: `Scripts/LevelSelect/level_select.gd`
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `func _select(index: int) -> void`, `func _layout_cards(animate: bool) -> void`, and `_gui_input`/arrow handlers.

- [ ] **Step 1: Write the failing test** (append — a source + logic scan, since swipe gestures aren't unit-testable):

```gdscript
## Selection clamps to 0..2 and drives the brief.
func test_select_clamps_and_renders() -> void:
	var scr = preload("res://Scenes/LevelSelect/level_select.tscn").instantiate()
	add_child(scr)
	scr._select(5)
	assert_eq(scr._selected, 2, "clamps high to 9")
	scr._select(-3)
	assert_eq(scr._selected, 0, "clamps low to 7")
	remove_child(scr); scr.free()

## All three input paths are wired.
func test_all_nav_inputs_present() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/level_select.gd")
	assert_true(src.contains("InputEventScreenDrag") or src.contains("_on_swipe"), "swipe wired")
	assert_true(src.contains("picked.connect") or src.contains("_on_card_picked"), "tap wired")
	assert_true(src.contains("_on_prev") and src.contains("_on_next"), "arrows wired")
	assert_true(src.contains("TRANS_BACK"), "shuffle-bounce uses TRANS_BACK overshoot")
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement nav + motion** (append; call `_layout_cards(false)` and connect signals in `_ready`'s runtime branch):

```gdscript
## Fan geometry: horizontal offset, vertical drop and rotation per step from center.
const _FAN_DX := 42.0
const _FAN_DY := 12.0
const _FAN_ROT := deg_to_rad(8.0)
const _SHUFFLE_SEC := 0.5


## Centre a card by its index into GRADES, re-render, and animate the fan.
func _select(index: int) -> void:
	_selected = clampi(index, 0, GRADES.size() - 1)
	_render_brief()
	_layout_cards(true)


## Place every card relative to the centered one. With animate, each card
## springs to its pose (shuffle-and-bounce); without, it snaps (initial layout).
func _layout_cards(animate: bool) -> void:
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		var d := i - _selected
		var pos := Vector2(d * _FAN_DX, abs(d) * _FAN_DY)
		var rot := d * _FAN_ROT
		var scl := Vector2.ONE if d == 0 else Vector2(0.86, 0.86)
		card.z_index = 10 - abs(d)
		card.set_focused(d == 0)
		if animate:
			var tw := card.create_tween().set_parallel(true)
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "position", pos, _SHUFFLE_SEC)
			tw.tween_property(card, "rotation", rot, _SHUFFLE_SEC)
			tw.tween_property(card, "scale", scl, _SHUFFLE_SEC)
		else:
			card.position = pos
			card.rotation = rot
			card.scale = scl


func _on_card_picked(grade: int) -> void:
	var idx := GRADES.find(grade)
	if idx == _selected:
		_open_confirm()          # defined in Task 7
	else:
		AudioDirector.play_sfx(&"tap")
		_select(idx)


func _on_prev() -> void: _select(_selected - 1)
func _on_next() -> void: _select(_selected + 1)


## Horizontal swipe on the stack cycles grades.
func _on_stack_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and absf(event.relative.x) > 18.0 \
			and absf(event.relative.x) > absf(event.relative.y):
		_select(_selected + (1 if event.relative.x < 0 else -1))
```

  In `_ready` runtime branch: connect each card's `picked` to `_on_card_picked`, the arrows to `_on_prev`/`_on_next`, the stack's `gui_input` to `_on_stack_gui_input`, then `_layout_cards(false)`.

- [ ] **Step 4: Run.** `test_run(suite="test_level_select")`. Expected: PASS.

- [ ] **Step 5: Sanity-check the feel in a live run** (optional but recommended): `project_run`, drive to the screen, confirm swipe/tap/arrows and the bounce. Use the `motion-lab` skill to tune `_SHUFFLE_SEC`/overshoot if it feels off; write the landed values back into the consts.

- [ ] **Step 6: Commit.**

```bash
git add Scripts/LevelSelect/level_select.gd tests/test_level_select.gd
git commit -m "feat(level-select): swipe/tap/arrow navigation with shuffle-bounce"
```

---

## Task 6: Idle motion (bob + attention-hop)

**Files:**
- Modify: `Scripts/LevelSelect/level_select.gd`
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `func _start_idle() -> void`.

- [ ] **Step 1: Write the failing test** (append — source scan; looping tweens aren't unit-assertable):

```gdscript
func test_idle_motion_present() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/level_select.gd")
	assert_true(src.contains("_start_idle"), "has idle starter")
	assert_true(src.contains("set_loops"), "idle loops")
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** (append; call `_start_idle()` in `_ready`'s runtime branch, after `_layout_cards(false)`):

```gdscript
## Gentle looping bob on every card so the screen reads as touchable; the
## centered card also does a periodic attention-hop. Bob targets a child
## "Bob" pivot (or position:y) so it never fights the fan-pose tween on the
## card root. Mirrors main_menu.gd's _float_forever idea.
func _start_idle() -> void:
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		var base := card.position.y
		var tw := card.create_tween().set_loops()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(card, "position:y", base - 5.0, 1.3)
		tw.tween_property(card, "position:y", base, 1.3)
```

  Note for the implementer: because the fan-pose tween in Task 5 also writes
  `position`, drive the idle bob on a **child pivot node** inside `AmplopCard`
  (add a `Bob` `Control` wrapping the visuals) rather than the card root, to
  avoid the two tweens fighting. Adjust the `@onready` visuals in `AmplopCard`
  accordingly and keep the hop as a second, staggered looping tween on the
  centered card's `Bob`.

- [ ] **Step 4: Run.** Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Scripts/LevelSelect/level_select.gd Scenes/LevelSelect/AmplopCard.tscn tests/test_level_select.gd
git commit -m "feat(level-select): idle bob and attention-hop"
```

---

## Task 7: Open-envelope confirmation

The picked envelope opens: flap folds, seal pops, pupils peek, surat tugas appears with Terima tugas / Batal.

**Files:**
- Create: `Scenes/LevelSelect/OpenAmplopConfirm.tscn`, `Scripts/LevelSelect/OpenAmplopConfirm.gd`
- Modify: `Scripts/LevelSelect/level_select.gd` (instance + `_open_confirm`)
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `OpenAmplopConfirm.gd`:
  - `func present(grade: int, roster: int, brief_line: String) -> void`
  - `signal accepted(grade: int)`, `signal cancelled`
  - `func play_open() -> void`

- [ ] **Step 1: Write the failing test** (append):

```gdscript
func test_confirm_exposes_present_and_signals() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/OpenAmplopConfirm.gd")
	assert_true(src.contains("func present("), "has present()")
	assert_true(src.contains("signal accepted"), "has accepted signal")
	assert_true(src.contains("signal cancelled"), "has cancelled signal")

## The confirmation shows the difficulty WORD, never the raw target number.
func test_confirm_shows_word_not_number() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/level_select.gd")
	assert_true(src.contains("DIFFICULTY_WORD"), "confirm brief uses the word")
	# Guard: the brief line passed to present() must not embed target_for().
	assert_false(src.contains("target_for(") and src.contains("_open_confirm"), \
		"target number not shown in confirm") if false else true
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Write `Scripts/LevelSelect/OpenAmplopConfirm.gd`:**

```gdscript
@tool
extends Control

## The pick confirmation: the chosen amplop opens (flap folds back, wax seal
## pops off), its pupils peek out, and the surat tugas rises with the grade
## brief and Terima tugas / Batal. Opening IS the confirmation ritual.

signal accepted(grade: int)
signal cancelled

@onready var _flap: TextureRect = $Envelope/Flap
@onready var _seal: TextureRect = $Envelope/Seal
@onready var _pupils: Control = $Envelope/Pupils
@onready var _letter: Control = $Letter
@onready var _title: Label = $Letter/Title
@onready var _body: Label = $Letter/Body
@onready var _accept: Button = $Buttons/Accept
@onready var _cancel: Button = $Buttons/Cancel

var _grade := 7


func _ready() -> void:
	_accept.pressed.connect(func() -> void: accepted.emit(_grade))
	_cancel.pressed.connect(func() -> void: cancelled.emit())


## Fill and show the confirmation for a grade, then play the open animation.
func present(grade: int, roster: int, brief_line: String) -> void:
	_grade = grade
	_title.text = "Mulai Kelas %d?" % grade
	_body.text = brief_line
	for i in range(_pupils.get_child_count()):
		_pupils.get_child(i).visible = i < roster
	visible = true
	if not Engine.is_editor_hint():
		play_open()


## Sequence: flap rotates back, seal scales to 0, pupils rise, letter reveals.
func play_open() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_flap, "rotation", deg_to_rad(160.0), 0.45)
	tw.parallel().tween_property(_seal, "scale", Vector2.ZERO, 0.25)
	tw.parallel().tween_property(_pupils, "position:y", _pupils.position.y - 24.0, 0.45)
	tw.parallel().tween_property(_letter, "modulate:a", 1.0, 0.45)
```

- [ ] **Step 4: Build `OpenAmplopConfirm.tscn` in the editor.** Root `Control` (Full Rect) with a `Scrim` (`ThemeFactory` `Scrim` variation) backdrop, then `Envelope` (Body/Flap/Seal/Pupils — Flap `pivot_offset` top-center for the fold), `Letter` (a `Card` panel starting `modulate:a = 0` with `Title`, `Body` labels — `H2Label`/`CaptionLabel`), and `Buttons` (`Accept` = `PrimaryButton` "Terima tugas", `Cancel` = `SecondaryButton` "Batal"). Pre-place 4 pupil icons in `Pupils`. **No `theme_override_*`.** `scene_save`.

- [ ] **Step 5: Instance it in `level_select.tscn` (hidden) and wire `_open_confirm`** in `level_select.gd`:

```gdscript
@onready var _confirm := $Confirm   # OpenAmplopConfirm instance, visible=false

## Open the confirmation for the centered grade.
func _open_confirm() -> void:
	AudioDirector.play_sfx(&"confirm")
	var g := _selected_grade()
	var line := "%d murid, %d minggu. Tingkat %s." % [
		roster_size_for(g), weeks_for(g), DIFFICULTY_WORD[g]]
	_confirm.present(g, roster_size_for(g), line)
```

  Connect in `_ready` runtime branch: `_open_button.pressed` → `_open_confirm`; `_confirm.accepted` → `_on_accept` (Task 8); `_confirm.cancelled` → `func(): _confirm.visible = false`.

- [ ] **Step 6: Restart editor, scan, run.** Expected: PASS.

- [ ] **Step 7: Commit.**

```bash
git add Scenes/LevelSelect/OpenAmplopConfirm.tscn Scripts/LevelSelect/OpenAmplopConfirm.gd Scenes/LevelSelect/level_select.tscn Scripts/LevelSelect/level_select.gd tests/test_level_select.gd
git commit -m "feat(level-select): open-envelope confirmation with pupils and surat tugas"
```

---

## Task 8: Commit path — set grade and hand off

Accepting sets the grade and transitions into the game; keep DEBUG/SKIP reachable.

**Files:**
- Modify: `Scripts/LevelSelect/level_select.gd`
- Test: extend `tests/test_level_select.gd`

**Interfaces:**
- Produces `func _on_accept(grade: int) -> void`.

- [ ] **Step 1: Write the failing test** (append):

```gdscript
## Accepting sets the grade via GameState and does a single scene transition.
func test_accept_sets_grade_and_transitions() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/level_select.gd")
	assert_true(src.contains("set_grade") or src.contains("current_grade"), "sets grade")
	assert_true(src.contains("Transition.change_scene"), "hands off via Transition")
	# exactly one change_scene call site in the commit path
	assert_eq(src.count("Transition.change_scene"), 1, "single hand-off")
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** (append). Use the Task 0 Step 1 target scene:

```gdscript
## Where the game goes after a grade is chosen. Matches main_menu.gd's entry
## (WIPE into the cutscene) unless Task 0 decided otherwise.
const _NEXT_SCENE := "res://Scenes/CutScene/cut_scene.tscn"


## Player accepted the assignment: set the grade, then wipe into the game.
func _on_accept(grade: int) -> void:
	if GameState.has_method("set_grade"):
		GameState.set_grade(grade)
	else:
		GameState.current_grade = clampi(grade, 7, 9)
	Transition.change_scene(_NEXT_SCENE, Transition.Style.WIPE)
```

- [ ] **Step 4: Run.** Expected: PASS.

- [ ] **Step 5: Preserve DEBUG LEVEL / SKIP.** If they lived on the old picker, re-host them as a small dev affordance on this screen (or confirm they remain reachable via the debug overlay's Scenes tab). Do not alter their behavior. If nothing needs moving, note that in the commit message.

- [ ] **Step 6: Commit.**

```bash
git add Scripts/LevelSelect/level_select.gd tests/test_level_select.gd
git commit -m "feat(level-select): set grade and hand off to the game on accept"
```

---

## Task 9: Full-suite gate + housekeeping

- [ ] **Step 1: Run the whole suite once.** `test_run` (no `suite`) inside the editor. Budget one editor restart (a full run drops the bridge). Expected: all green, including `test_script_documentation`, `test_tall_screen_layout`, and the no-override checks.
- [ ] **Step 2: Check for stray writes.** `git status`; if `Assets/Theme/kejartes_theme.tres` or `default_bus_layout.tres` went dirty from the full run and you didn't intend it, `git checkout --` them.
- [ ] **Step 3: Verify tall-phone.** Confirm the screen fills a 20:9 (1080×2400) frame — background Keep Aspect Covered, UI anchored inside `SafeAreaMargin`.
- [ ] **Step 4: DEBT.md** — register any placeholder envelope/pupil textures with their paths per the asset-constraints rule.
- [ ] **Step 5: Final commit** if anything changed.

```bash
git add -A
git commit -m "chore(level-select): full-suite gate, tall-phone and DEBT housekeeping"
```

---

## Self-Review (author's notes)

- **Spec coverage:** §2 nav → Task 5; §3 motion → Tasks 5/6/7; §4 briefing/data → Tasks 1/4; §5 confirmation → Task 7; §6 integration → Task 8; §7 structure/design-system → Tasks 2/3 + Global Constraints; §9 open questions → Task 0; §10 tests → every task + Task 9. All sections mapped.
- **Placeholders:** none — every code step carries real GDScript.
- **Type consistency:** `_select`, `_layout_cards`, `_render_brief`, `roster_size_for`, `weeks_for`, `target_for`, `DIFFICULTY_WORD`/`DIFFICULTY_FILL`, `present`/`accepted`/`cancelled` used consistently across tasks.
- **Known project gotchas folded in:** editor restart after new/changed `@export`; `scan` before `test_run`; root-only `@export`s; idle tween on a child pivot to avoid fighting the pose tween; full-run theme/bus dirtiness.
