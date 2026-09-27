# Event Cards and Slide Warning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the event picker's and item screen's student cards on the real DaySummary card, and replace both the minigame banner and the event announcement with one full-screen mustard warning that slides right to left.

**Architecture:**
- `DaySummaryStudentRow` gains a "current stats" mode (`setup_current_row`, `preview_stat`, `preview_need`, `show_only`), backed by a new standing mode on `DaySummaryStatRow`.
- A new base, `StudentCardButton`, is a toggle Button that hosts that card as its `Card` child, fits it to its own width and hands taps to the Button. `EventStudentCard` and `ApplyStudentRow` both extend it.
- `EventWarning` is rebuilt as an authored mustard panel carrying `eventwarning_icon.png` and a caption, tweened in from the right and out through the left.
- SchoolDay calls `EventWarning` for both minigames and events, and `EventAnnouncement` is deleted.

**Tech Stack:**
- Godot 4.6 GDScript.
- Tests are `McpTestSuite` suites run inside the editor through the godot-ai MCP (`test_run`).
- Scenes are edited through the godot-ai MCP (`scene_open`, `batch_execute`, `scene_save`).

**Spec:** `docs/superpowers/specs/2026-09-12-event-cards-and-slide-warning-design.md`

## Global Constraints

**Engine and tests**
- Godot 4.6, portrait 1080×1920. Tests run in the editor through godot-ai `test_run`. There is no headless path.
- Test suites are `@tool`, `extends McpTestSuite`, and **no test may be a coroutine**: no `await` in any test.

**Project rules**
- Never add a `theme_override_*`. The only accepted exception is layout constants (`separation`, `margin_*`).
- No visual is built at runtime: static chrome is a node in the `.tscn`.
- Every script has a `##` file header, and every `@export` has a `##` line (enforced by `tests/test_script_documentation.gd`).
- No emoji as UI iconography.
- UI text is Indonesian; engine code is English.
- Never edit `Scripts/Balance.gd`.
- Commits use Conventional Commits with a scope, and end with the line `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

**Values fixed by the spec**
- Colours: `event_warning_bg = #9E8830`, `event_warning_ink = #1D196E`.
- Card: design size 992×410, `max_card_scale = 1.0`, `unavailable_alpha = 0.55`, `unavailable_avatar_tint = Color(0.7, 0.7, 0.75, 1.0)`.
- Slide: right to left, pass-through. `slide_in_duration = 0.35` (ease out), `hold_duration = 1.1`, `slide_out_duration = 0.35` (ease in). One cue per warning: `event_announce`.
- Minigame captions: `"KEGIATAN AKADEMIS!"`, `"KEGIATAN OLAHRAGA!"`, `"KEGIATAN SENI BUDAYA!"`. Events use their own title.
- Readouts: standing `"42/60"`, preview `"+15/60"` (the existing `format_value`), capped `"MAKS"`.

---

## How to work in this repo (read before Task 1)

The godot-ai bridge is **single-client**. Only the controller (the session running this plan) talks to the editor. Subagents write files and hand back; the controller runs every MCP step: `test_run`, `scene_open`, `batch_execute`, `scene_save`, `script_patch`, `filesystem_manage`, and restarts.

1. **After any `.gd` written outside the editor** (any plain file write, including a subagent's): make a no-op `script_patch` on that file before `test_run`. Replace a line with itself; a benign "reload failed with error code 43" may be logged. Otherwise `test_run` serves a stale script.
2. **Restart the editor before any `scene_save`** if any `.gd` has been written outside the editor since the last restart. `scene_save` writes every open script tab back over your file. To restart:
   - `taskkill //PID <pid> //F` on this project's `Godot_v4.6.2-stable_win64.exe` editor process. Find it with `session_manage(op="list")` → `editor_pid`. Also kill its game child if one is running. **Never kill `godot-ai.exe`.**
   - Relaunch in the background: `"/c/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --path "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" -e`
   - Wait until `session_manage(op="list")` shows a session.
3. **Scenes are edited only through the editor:** `scene_open` → `batch_execute` → `scene_save`. Never hand-edit a `.tscn` while the editor is running. Task 9 edits one `.tscn` by hand, **with the editor stopped**.
4. **After every `scene_save`,** run `git diff --stat -- '*.gd'`. Any script you did not mean to change means a stale tab was written back: `git checkout -- <file>`, restart, and redo the scene step.
5. **A new or changed `class_name`** needs `filesystem_manage(op="scan")` before tests see it.
6. **A new `@export` on `DesignTokens` needs a full editor restart** before `DesignTokens.load_default()` serves it (Task 7).
7. **Run targeted suites only** (`test_run(suite="...")`). A full `test_run()` drops the bridge, so it happens once, in Task 10.
8. **`batch_execute` details:**
   - Use the plugin command names `create_node`, `set_property` and `delete_node`.
   - Paths start at the edited scene's root name, e.g. `/EventStudentCard/Card`.
   - Numbers are unquoted.
   - A `Control` created under a plain `Control` starts in position mode. **Set `layout_mode` to 1 before setting any anchor.**

## File map

| File | Change | Responsibility |
|---|---|---|
| `Scripts/GameState.gd` | modify | `student_data_from_dict()`: the one Dictionary→StudentData rule |
| `Scripts/SchoolSimulation/DaySummaryStatRow.gd` | modify | standing readout plus a quiet preview on one stat row |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | modify | the "current stats" entry points on the real card |
| `Scripts/UI/StudentCardButton.gd` | create | toggle Button hosting the card: fit, taps, selectable state, badge |
| `Scripts/SchoolSimulation/EventStudentCard.gd` | rewrite | the event picker's wrapper |
| `Scenes/SchoolSimulation/EventStudentCard.tscn` | rebuild (editor) | Button → `Card` instance plus three badges |
| `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` | modify | cards fill the width; stale comments |
| `Scripts/Inventory/ApplyStudentRow.gd` | rewrite | the item screen's wrapper |
| `Scenes/Inventory/ApplyStudentRow.tscn` | recreate (editor) | Button → `Card` instance, badge and LELAH chip |
| `Scenes/Inventory/ApplyItemScreen.tscn` | re-assign (editor) | refresh `student_row_scene`'s UID |
| `Scripts/Design/DesignTokens.gd`, `Scripts/Design/ThemeFactory.gd`, `Assets/Theme/kejartes_theme.tres` | modify / rebake | two tokens, one outline token, two variations |
| `Assets/Images/SchoolDay/eventwarning_icon.png` | create | the Drive icon cropped to its art |
| `Scripts/SchoolSimulation/EventWarning.gd`, `Scenes/SchoolSimulation/EventWarning.tscn` | rewrite / rebuild | the slide warning |
| `Scripts/SchoolSimulation/SchoolDay.gd`, `Scenes/SchoolSimulation/SchoolDay.tscn` | modify | one warning for both paths, emoji-free titles |
| `EventAnnouncement.*`, `AnnouncementBurst.*`, retired placeholders and shader | delete | Task 10 |
| Tests | create / modify | see each task |

---

### Task 1: One Dictionary→StudentData rule on GameState

**Files:**
- Modify: `Scripts/GameState.gd:366-402`
- Create: `tests/test_student_data_bridge.gd`

**Interfaces:**
- Produces: `GameState.student_data_from_dict(dict: Dictionary) -> StudentData`, used by Task 6.

- [ ] **Step 1: Write the failing test**

Create `tests/test_student_data_bridge.gd`:

```gdscript
@tool
extends McpTestSuite

## GameState.student_data_from_dict is the one roster-Dictionary ->
## StudentData rule. convert_to_student_data_array() is built from it, so the
## item screen's cards and the week simulation can never convert a student
## two different ways (2026-09-12 event-cards spec, section 1.5).

func suite_name() -> String:
	return "student_data_bridge"


const _ENTRY := {
	"id": 7, "name": "Citra",
	"akademis1": 41.0, "akademis2": 52.0, "akademis3": 63.0,
	"kepribadian1": 70.0, "kepribadian2": 30.0,
	"target_akademis1": 55.0, "target_akademis2": 60.0, "target_akademis3": 65.0,
	"quirk": "Penyendiri", "hobby_category": "Akademik",
}


func test_single_conversion_copies_stats_and_targets() -> void:
	var sd: StudentData = GameState.student_data_from_dict(_ENTRY)
	assert_eq(sd.id, 7)
	assert_eq(sd.student_name, "Citra")
	assert_eq(sd.akademis, 41.0)
	assert_eq(sd.seni_budaya, 52.0, "akademis2 is seni_budaya")
	assert_eq(sd.olahraga, 63.0, "akademis3 is olahraga")
	assert_eq(sd.mood, 70.0, "kepribadian1 is mood")
	assert_eq(sd.energy, 30.0, "kepribadian2 is energy")
	assert_eq(sd.target_akademis2, 60.0, "target_akademis2 is the SENI target")
	assert_eq(sd.quirk, "Penyendiri")
	assert_eq(sd.specialty_category, "Akademis", "Akademik normalises to Akademis")


func test_array_conversion_matches_the_single_one() -> void:
	var saved: Array[Dictionary] = GameState.approved_students.duplicate(true)
	var one: Array[Dictionary] = [_ENTRY.duplicate()]
	GameState.approved_students = one
	var from_array: Array[StudentData] = GameState.convert_to_student_data_array()
	GameState.approved_students = saved
	var single: StudentData = GameState.student_data_from_dict(_ENTRY)
	assert_eq(from_array.size(), 1)
	for field in ["id", "student_name", "akademis", "seni_budaya", "olahraga",
			"mood", "energy", "target_akademis1", "target_akademis2",
			"target_akademis3", "quirk", "specialty_category"]:
		assert_eq(from_array[0].get(field), single.get(field), "field " + field)


func test_array_function_reuses_the_single_rule() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var start := src.find("func convert_to_student_data_array")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_contains(body, "student_data_from_dict(",
		"the array conversion must reuse the single rule")
	assert_false(body.contains("StudentData.new()"),
		"no second copy of the conversion may survive in the array function")
```

- [ ] **Step 2: Run the test to verify it fails**

Run (godot-ai): `test_run(suite="student_data_bridge")`
Expected: FAIL. The first two tests error on the nonexistent `student_data_from_dict`; the third fails because the body still contains `StudentData.new()`.

- [ ] **Step 3: Implement**

In `Scripts/GameState.gd`, replace lines 366-402 (the `# --- Converter` comment through `return result`) with:

```gdscript
# --- Converter: Dictionary → StudentData (for simulation) ---
## One roster entry as a simulation StudentData. The single conversion rule:
## convert_to_student_data_array() and the item screen's student cards both
## go through here, so a student can never be converted two different ways.
func student_data_from_dict(dict: Dictionary) -> StudentData:
	var sd = StudentData.new()
	sd.id = dict.get("id", 0)
	sd.student_name = dict.get("name", "")
	sd.akademis = dict.get("akademis1", 50.0)
	sd.seni_budaya = dict.get("akademis2", 50.0)
	sd.olahraga = dict.get("akademis3", 50.0)
	sd.mood = dict.get("kepribadian1", 80.0)
	sd.energy = dict.get("kepribadian2", 80.0)

	# 0.0, not 50.0: count_targets_cleared() reads the same three keys
	# with a 0.0 default, and the two sides of the bridge must agree on
	# what an uninitialized target looks like. See target_cleared().
	sd.target_akademis1 = dict.get("target_akademis1", 0.0)
	sd.target_akademis2 = dict.get("target_akademis2", 0.0)
	sd.target_akademis3 = dict.get("target_akademis3", 0.0)
	sd.target_kepribadian1 = dict.get("target_kepribadian1", 50.0)
	sd.target_kepribadian2 = dict.get("target_kepribadian2", 50.0)
	sd.quirk = dict.get("quirk", "")
	sd.persona = dict.get("persona", "")
	sd.personality = dict.get("personality", "Santai")
	sd.profil = dict.get("profil", "")
	sd.splash_path = dict.get("splash", "")

	var port_path = dict.get("portrait", "")
	if port_path != "" and ResourceLoader.exists(port_path):
		sd.avatar_texture = load(port_path)

	# Map hobby_category: "Akademik" → "Akademis"
	var hobby = dict.get("hobby_category", "")
	sd.specialty_category = "Akademis" if hobby == "Akademik" else hobby
	sd.record_initial_stats()
	return sd


func convert_to_student_data_array() -> Array[StudentData]:
	var result: Array[StudentData] = []
	for dict in approved_students:
		result.append(student_data_from_dict(dict))
	return result
```

- [ ] **Step 4: Run the tests to verify they pass**

First make a no-op `script_patch` on `res://Scripts/GameState.gd` (it is an autoload; this reloads it). Then run:
`test_run(suite="student_data_bridge")`, then `test_run(suite="roster_reset")`, then `test_run(suite="economy_state")`
Expected: all PASS. The last two exercise the array conversion.

- [ ] **Step 5: Commit**

```bash
git add Scripts/GameState.gd tests/test_student_data_bridge.gd
git commit -m "refactor(gamestate): one Dictionary-to-StudentData rule" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: A standing mode on DaySummaryStatRow

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd`: a const after `TRACK_VARIATION_FOR` (line 58), a var after `_target` (line 76), two functions after `set_stat` (after line 148).
- Create: `tests/test_card_standing_mode.gd`

**Interfaces:**
- Produces: `static func format_standing(current: float, target: float) -> String`, `func set_standing(stat_key: String, target: float, current: float) -> void` and `func show_preview(delta: float, capped: bool = false) -> void` on `DaySummaryStatRow`, plus `const MAX_TEXT := "MAKS"`. Used by Task 3.

- [ ] **Step 1: Write the failing test**

Create `tests/test_card_standing_mode.gd`:

```gdscript
@tool
extends McpTestSuite

## The DaySummary card's "current stats" mode, which the event picker and
## the item screen read it in (2026-09-12 event-cards spec, sections 1.1 and
## 1.2). DaySummary and ResultCheckup keep their own setup_row /
## setup_week_row paths; nothing here may change those.

const _STAT_ROW := "res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn"
const _CARD := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"
const _STAT_ROW_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryStatRow.gd"


func suite_name() -> String:
	return "card_standing_mode"


func _row() -> DaySummaryStatRow:
	var row: DaySummaryStatRow = (load(_STAT_ROW) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	return row


func test_format_standing_has_no_sign() -> void:
	assert_eq(DaySummaryStatRow.format_standing(42.0, 60.0), "42/60")
	assert_eq(DaySummaryStatRow.format_standing(41.6, 59.5), "42/60",
		"both ends round, like format_value's")


func test_set_standing_shows_current_over_target() -> void:
	var row := _row()
	row.set_standing("seni_budaya", 60.0, 30.0)
	assert_eq(row.value.text, "30/60")
	assert_false(row.chevron.visible, "nothing moved, so no chevron")
	assert_eq(row.track.value, 50.0, "half the target is half the track")
	assert_eq(row.track.theme_type_variation, &"DaySummaryStatTrackSeniBudaya")


func test_show_preview_layers_the_gain() -> void:
	var row := _row()
	row.set_standing("akademis", 60.0, 30.0)
	row.show_preview(15.0)
	assert_eq(row.value.text, "+15/60", "the card's own delta format")
	assert_true(row.chevron.visible, "a gain shows the chevron")
	assert_eq(row.track.value, 75.0, "the track moves to (30 + 15) / 60")


func test_zero_preview_restores_the_standing_view() -> void:
	var row := _row()
	row.set_standing("akademis", 60.0, 30.0)
	row.show_preview(15.0)
	row.show_preview(0.0)
	assert_eq(row.value.text, "30/60")
	assert_false(row.chevron.visible)
	assert_eq(row.track.value, 50.0)


func test_capped_preview_reads_maks() -> void:
	var row := _row()
	row.set_standing("olahraga", 60.0, 100.0)
	row.show_preview(0.0, true)
	assert_eq(row.value.text, "MAKS")
	assert_false(row.chevron.visible, "a full stat has nothing to gain")


func test_preview_path_stays_quiet() -> void:
	# The star burst and the tally cue are the day summary's reward. A
	# preview the player toggles on and off must not fire them.
	var src := FileAccess.get_file_as_string(_STAT_ROW_SCRIPT)
	var start := src.find("func show_preview")
	assert_true(start != -1, "show_preview must exist")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_false(body.contains("_play_burst"), "no star burst on a preview")
	assert_false(body.contains("play_sfx"), "no tally cue on a preview")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="card_standing_mode")`
Expected: FAIL. `format_standing`, `set_standing` and `show_preview` do not exist.

- [ ] **Step 3: Implement**

In `Scripts/SchoolSimulation/DaySummaryStatRow.gd`, directly after the `TRACK_VARIATION_FOR` dictionary (after line 58), add:

```gdscript

## What a capped preview reads: the stat is already at its ceiling, so an
## item or event would add nothing.
const MAX_TEXT := "MAKS"
```

Directly after `var _target: float = 0.0` (line 76), add:

```gdscript

## The standing value set_standing() last wrote, so show_preview() can layer
## a change on top and restore it again.
var _standing_current: float = 0.0
```

Directly after `set_stat` (after its last line, `track.value = _fill_to`), add:

```gdscript


## "42/60": where the student stands now against the run's target, with no
## sign because nothing moved. The event picker and the item screen read
## the card this way; the day summary never does.
static func format_standing(current: float, target: float) -> String:
	return "%d/%d" % [int(round(current)), int(round(target))]


## Show where the student stands, with no movement behind it: the track at
## current/target, the number as format_standing, no chevron. Caches both
## ends so show_preview() can layer a change over them.
func set_standing(stat_key: String, target: float, current: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	if TRACK_VARIATION_FOR.has(stat_key):
		track.theme_type_variation = TRACK_VARIATION_FOR[stat_key]
	_standing_current = current
	_target = target
	_delta = 0.0
	value.text = format_standing(current, target)
	chevron.visible = false
	chevron.modulate.a = 1.0
	chevron.scale = Vector2.ONE
	track.value = track_ratio(current, target)


## Layer a proposed change over the standing view: the number reads
## format_value's "+15/60", the chevron shows on a gain, and the track
## travels to where the change would leave it. `capped` means the stat is
## already at 100: the number reads MAKS and nothing moves. A zero delta,
## uncapped, restores the standing view. Deliberately quiet -- no star
## burst and no tally cue, which belong to the day summary's reward.
func show_preview(delta: float, capped: bool = false) -> void:
	var to_ratio := track_ratio(_standing_current + delta, _target)
	if capped:
		value.text = MAX_TEXT
		chevron.visible = false
		to_ratio = track_ratio(_standing_current, _target)
	elif is_zero_approx(delta):
		value.text = format_standing(_standing_current, _target)
		chevron.visible = false
	else:
		value.text = format_value(delta, _target)
		chevron.visible = shows_chevron(delta)
	if Engine.is_editor_hint() or not is_inside_tree():
		track.value = to_ratio
	else:
		Juice.fill_bar(track, to_ratio)
```

- [ ] **Step 4: Run the tests to verify they pass**

No-op `script_patch` on `res://Scripts/SchoolSimulation/DaySummaryStatRow.gd`, then run:
`test_run(suite="card_standing_mode")` and `test_run(suite="day_summary")`
Expected: both PASS. `day_summary` proves the day and week paths are untouched.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd tests/test_card_standing_mode.gd
git commit -m "feat(day-summary): a standing readout and a quiet preview on the stat row" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The "current stats" mode on DaySummaryStudentRow

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`: vars after `_gained_ground` (line 67), functions appended at the end of the file.
- Modify: `tests/test_card_standing_mode.gd` (append).

**Interfaces:**
- Consumes (Task 2): `DaySummaryStatRow.set_standing(stat_key, target, current)` and `show_preview(delta, capped)`.
- Produces, on `DaySummaryStudentRow`, used by Tasks 5 and 6:
  - `setup_current_row(student: StudentData) -> void`
  - `preview_stat(stat_key: String, delta: float, capped: bool = false) -> void`
  - `preview_need(need_key: String, delta: float) -> void`
  - `show_only(keys: Array) -> void`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_card_standing_mode.gd`:

```gdscript


# ── The card: DaySummaryStudentRow ───────────────────────────────────────────

func _student() -> StudentData:
	var s := StudentData.new()
	s.student_name = "Budi"
	s.akademis = 30.0
	s.seni_budaya = 45.0
	s.olahraga = 60.0
	s.target_akademis1 = 60.0
	s.target_akademis2 = 90.0
	s.target_akademis3 = 60.0
	s.energy = 40.0
	s.mood = 70.0
	return s


func _card() -> DaySummaryStudentRow:
	var card: DaySummaryStudentRow = (load(_CARD) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func test_current_row_shows_standing_values() -> void:
	var card := _card()
	card.setup_current_row(_student())
	assert_eq(card.name_label.text, "Budi")
	assert_eq(card.stat_rows[0].value.text, "30/60")
	assert_eq(card.stat_rows[1].value.text, "45/90",
		"row 2 is seni, measured against target_akademis2")
	assert_eq(card.energy_bar.value, 40.0)
	assert_eq(card.mood_bar.value, 70.0)
	assert_false(card.energy_delta_chevron.visible, "nothing moved yet")
	assert_true(card.energy_bar.icon.texture != null,
		"the real card's needs bars carry their icon")


func test_preview_stat_targets_the_right_row() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.preview_stat("olahraga", 15.0)
	assert_eq(card.stat_rows[2].value.text, "+15/60")
	assert_eq(card.stat_rows[0].value.text, "30/60", "other rows are untouched")


func test_preview_need_moves_the_bar_and_points_the_chevron() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.preview_need("energy", -15.0)
	assert_eq(card.energy_bar.value, 25.0)
	assert_true(card.energy_delta_chevron.visible)
	assert_eq(card.energy_delta_chevron.rotation_degrees, 180.0, "a loss points down")
	assert_false(card.energy_delta_label.visible, "the number stays hidden")
	card.preview_need("energy", 0.0)
	assert_eq(card.energy_bar.value, 40.0, "zero restores the bar")
	assert_false(card.energy_delta_chevron.visible)


func test_show_only_moves_a_single_skill_to_the_top_slot() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.show_only(["olahraga", "mood"])
	var top: DaySummaryStatRow = card.stat_rows[0]
	assert_true(top.visible)
	assert_eq(top.value.text, "60/60", "olahraga fills the top slot")
	assert_eq(top.track.theme_type_variation, &"DaySummaryStatTrackOlahraga")
	assert_false(card.stat_rows[1].visible)
	assert_false(card.stat_rows[2].visible)
	assert_false(card.energy_bar.visible, "energy was not listed")
	assert_true(card.mood_bar.visible)
	card.preview_stat("olahraga", 5.0)
	assert_eq(top.value.text, "+5/60", "previews follow the reassigned row")


func test_show_only_empty_shows_everything() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.show_only(["akademis"])
	card.show_only([])
	for row in card.stat_rows:
		assert_true(row.visible)
	assert_true(card.energy_bar.visible and card.mood_bar.visible)
	assert_eq(card.stat_rows[1].value.text, "45/90", "seni is back in its own row")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="card_standing_mode")`
Expected: FAIL. `setup_current_row` does not exist.

- [ ] **Step 3: Implement**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, directly after `var _gained_ground: bool = false` (line 67), add:

```gdscript

## Each key's standing value and target, cached by setup_current_row so the
## previews and show_only() can work without the StudentData in hand.
var _standing: Dictionary = {}
var _targets: Dictionary = {}

## Which stat row currently shows which skill key. setup_current_row fills it
## in STAT_ORDER; show_only() reassigns it so visible skills fill from the top.
var _row_for_key: Dictionary = {}
```

At the end of the file, append:

```gdscript


## The card as it stands right now, with no day or week behind it. The
## event picker and the item screen read the card this way (2026-09-12
## event-cards spec, 1.1). Both needs bars at their current values with no
## chevron; every stat row at current/target via set_standing().
func setup_current_row(student: StudentData) -> void:
	name_label.text = student.student_name if student != null else ""
	avatar.set_student(student)
	_standing.clear()
	_targets.clear()
	_row_for_key.clear()
	_standing["energy"] = student.energy if student != null else 0.0
	_standing["mood"] = student.mood if student != null else 0.0
	energy_bar.set_need("energy", float(_standing["energy"]))
	mood_bar.set_need("mood", float(_standing["mood"]))
	energy_bar.show()
	mood_bar.show()
	for label in [energy_delta_label, mood_delta_label]:
		label.hide()
	for chevron in [energy_delta_chevron, mood_delta_chevron]:
		chevron.hide()
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		_standing[key] = float(student.get(key)) if student != null else 0.0
		_targets[key] = float(student.get(TARGET_FOR[key])) if student != null else 0.0
		_row_for_key[key] = stat_rows[i]
		stat_rows[i].show()
		stat_rows[i].set_standing(key, float(_targets[key]), float(_standing[key]))
	_gained_ground = false


## Layer a proposed change on one skill's row. A zero delta (uncapped)
## restores it; `capped` makes the row read MAKS because the stat is at 100.
func preview_stat(stat_key: String, delta: float, capped: bool = false) -> void:
	var row: DaySummaryStatRow = _row_for_key.get(stat_key)
	if row != null:
		row.show_preview(delta, capped)


## Move one needs bar to where a proposed change would leave it, with its
## chevron pointing the change's way. A zero delta restores the bar.
func preview_need(need_key: String, delta: float) -> void:
	var is_energy := need_key == "energy"
	var bar: DaySummaryNeedsBar = energy_bar if is_energy else mood_bar
	var label: Label = energy_delta_label if is_energy else mood_delta_label
	var chevron: TextureRect = energy_delta_chevron if is_energy else mood_delta_chevron
	var from_value: float = bar.value
	var to_value := clampf(float(_standing.get(need_key, 0.0)) + delta, 0.0, 100.0)
	bar.set_need(need_key, to_value)
	if not Engine.is_editor_hint() and is_inside_tree():
		bar.value = from_value
		Juice.fill_bar(bar, to_value)
	_show_needs_delta(label, chevron, delta)


## Show only the listed keys ("akademis", "seni_budaya", "olahraga",
## "energy", "mood"). Visible skills fill the stat rows top-down in
## STAT_ORDER, so one boosted skill sits in the top slot; unused rows hide.
## The needs bars keep their slots and hide when not listed. An empty list
## shows everything. Call setup_current_row() first: reassigned rows are
## re-written from its cache.
func show_only(keys: Array) -> void:
	var want_all := keys.is_empty()
	energy_bar.visible = want_all or keys.has("energy")
	mood_bar.visible = want_all or keys.has("mood")
	var shown: Array[String] = []
	for key in STAT_ORDER:
		if want_all or keys.has(key):
			shown.append(key)
	_row_for_key.clear()
	for i in stat_rows.size():
		if i < shown.size():
			var key: String = shown[i]
			_row_for_key[key] = stat_rows[i]
			stat_rows[i].show()
			stat_rows[i].set_standing(key, float(_targets.get(key, 0.0)),
				float(_standing.get(key, 0.0)))
		else:
			stat_rows[i].hide()
```

- [ ] **Step 4: Run the tests to verify they pass**

No-op `script_patch` on `res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, then run:
`test_run(suite="card_standing_mode")`, `test_run(suite="day_summary")`, `test_run(suite="result_checkup")`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_card_standing_mode.gd
git commit -m "feat(day-summary): a current-stats mode on the student card" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: StudentCardButton, the shared tappable wrapper

**Files:**
- Create: `Scripts/UI/StudentCardButton.gd`
- Create: `tests/test_student_card_button.gd`

**Interfaces:**
- Consumes: `DaySummaryStudentRow` (its `avatar` member).
- Produces `StudentCardButton` (`class_name`, `extends Button`), used by Tasks 5 and 6:
  - Members: `card: DaySummaryStudentRow`, `select_badge: TextureRect`.
  - Functions: `set_selectable(on: bool)`, `is_selected() -> bool`, `static func fit_scale(width: float, design_width: float, max_scale: float) -> float`, and the virtual `_selection_toggled(pressed: bool)`.
  - Exports: `card_design_size`, `max_card_scale`, `unavailable_alpha`, `unavailable_avatar_tint`.
  - The hosted scene must have a child named `Card` (a `DaySummaryStudentRow` instance), with `SelectBadge` authored under `Card`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_student_card_button.gd`:

```gdscript
@tool
extends McpTestSuite

## StudentCardButton: the toggle Button that hosts the real DaySummary card
## for the event picker and the item screen (2026-09-12 event-cards spec,
## 1.3). It owns the card's rect (Pattern C), scales the fixed-offset art to
## its own width, and makes every part of the card hand taps to the Button.

const _CARD := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"


func suite_name() -> String:
	return "student_card_button"


## A bare wrapper around the real card, the shape both wrapper scenes have.
func _wrapper() -> StudentCardButton:
	var b := StudentCardButton.new()
	var card: Control = (load(_CARD) as PackedScene).instantiate()
	card.name = "Card"
	var badge := TextureRect.new()
	badge.name = "SelectBadge"
	card.add_child(badge)
	b.add_child(card)
	Engine.get_main_loop().root.add_child(b)
	track(b)
	return b


func test_fit_scale_never_upscales() -> void:
	assert_eq(StudentCardButton.fit_scale(1200.0, 992.0, 1.0), 1.0)
	assert_true(absf(StudentCardButton.fit_scale(944.0, 992.0, 1.0) - 944.0 / 992.0) < 0.0001)
	assert_eq(StudentCardButton.fit_scale(500.0, 0.0, 1.0), 1.0, "no divide by zero")


func test_wrapper_owns_the_card_rect_at_944() -> void:
	var b := _wrapper()
	b.size = Vector2(944, 400)
	# The fit also runs on NOTIFICATION_RESIZED; calling it directly keeps the
	# test independent of when Godot delivers that notification.
	b._fit_card()
	var card := b.get_node("Card") as Control
	assert_eq(card.position, Vector2.ZERO)
	assert_eq(card.size, Vector2(992, 410), "the card keeps its design size")
	assert_true(absf(card.scale.x - 944.0 / 992.0) < 0.001, "and scales to fit")
	assert_true(absf(b.custom_minimum_size.y - 410.0 * 944.0 / 992.0) < 0.5,
		"the wrapper's height follows the scale")


func test_wrapper_draws_native_size_at_992() -> void:
	var b := _wrapper()
	b.size = Vector2(992, 410)
	b._fit_card()
	assert_eq((b.get_node("Card") as Control).scale, Vector2.ONE)


func test_every_card_part_ignores_the_mouse() -> void:
	var b := _wrapper()
	var stack: Array[Node] = [b.get_node("Card")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s would swallow the tap meant for the card" % n.name)
		stack.append_array(n.get_children())


func test_unselectable_card_dims_and_drops_selection() -> void:
	var b := _wrapper()
	b.button_pressed = true
	b.set_selectable(false)
	assert_true(b.disabled)
	assert_false(b.is_selected(), "an unselectable card drops its selection")
	assert_true(absf(b.modulate.a - 0.55) <= 0.01)
	assert_eq(b.card.avatar.modulate, Color(0.7, 0.7, 0.75, 1.0))
	b.set_selectable(true)
	assert_eq(b.modulate.a, 1.0)
	assert_eq(b.card.avatar.modulate, Color.WHITE)


func test_select_badge_follows_the_toggle() -> void:
	var b := _wrapper()
	assert_false(b.select_badge.visible)
	b.button_pressed = true
	assert_true(b.select_badge.visible)
	b.button_pressed = false
	assert_false(b.select_badge.visible)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="student_card_button")`
Expected: FAIL. `StudentCardButton` is an unknown identifier, so the suite fails to load.

- [ ] **Step 3: Implement**

Create `Scripts/UI/StudentCardButton.gd`:

```gdscript
@tool
class_name StudentCardButton
extends Button

## A student card the player taps to pick: the real DaySummary card
## (DaySummaryStudentRow, instanced as the child named Card) inside a toggle
## Button. Shared by the event picker's EventStudentCard and the item
## screen's ApplyStudentRow (2026-09-12 event-cards spec, section 1.3).
##
## The wrapper owns the card's rect outright -- position, size and scale --
## because an instanced scene's root under a plain Control loses its rect on
## load (authoring guide, Pattern C). It measures its own width, never the
## viewport, and scales the fixed-offset card art to fit.
##
## Subclasses announce a toggle in their own signal shape by overriding
## _selection_toggled(); the two screens' signals differ.

## The card art's native size. Every offset inside DaySummaryStudentRow is
## measured against it, so the whole card scales as one.
@export var card_design_size: Vector2 = Vector2(992, 410):
	set(v):
		card_design_size = v
		_fit_card()
## The largest scale the card may be drawn at. 1.0 never upscales the art.
@export_range(0.1, 2.0, 0.01) var max_card_scale: float = 1.0:
	set(v):
		max_card_scale = v
		_fit_card()
## Opacity of a card that cannot be picked (a student too tired to go).
@export_range(0.0, 1.0, 0.01) var unavailable_alpha: float = 0.55
## Avatar tint on a card that cannot be picked, so it reads as unavailable
## at a glance rather than only when tapped.
@export var unavailable_avatar_tint: Color = Color(0.7, 0.7, 0.75, 1.0)

## The DaySummary card this wrapper hosts.
@onready var card: DaySummaryStudentRow = get_node_or_null("Card") as DaySummaryStudentRow
## The tick shown while the card is picked, authored under Card so it scales
## with the art.
@onready var select_badge: TextureRect = get_node_or_null("Card/SelectBadge") as TextureRect


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_ignore_mouse_below(card)
	if select_badge:
		select_badge.visible = button_pressed
	_fit_card()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_card()


## The scale the card is drawn at for a wrapper `width` wide.
static func fit_scale(width: float, design_width: float, max_scale: float) -> float:
	if design_width <= 0.0:
		return 1.0
	return minf(max_scale, width / design_width)


## A card that cannot be picked refuses the tap, drops any selection it
## held, dims, and greys its avatar.
func set_selectable(on: bool) -> void:
	disabled = not on
	if not on:
		button_pressed = false
	modulate.a = 1.0 if on else unavailable_alpha
	if card != null and card.avatar != null:
		card.avatar.modulate = Color.WHITE if on else unavailable_avatar_tint


## True while the player has this card picked.
func is_selected() -> bool:
	return button_pressed and not disabled


## Put the card at the wrapper's top-left at its design size, scaled to the
## wrapper's width; the wrapper's minimum height follows the scale. Skipped
## until the wrapper has a width, since a zero scale would hide the card.
func _fit_card() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	var c := get_node_or_null("Card") as Control
	if c == null:
		return
	var s := fit_scale(size.x, card_design_size.x, max_card_scale)
	c.position = Vector2.ZERO
	c.size = card_design_size
	c.scale = Vector2(s, s)
	custom_minimum_size = Vector2(0.0, card_design_size.y * s)


## Taps must reach the Button, not the card's parts. Overrides on an
## instance's children are not saved with the scene, so this runs on load.
func _ignore_mouse_below(node: Node) -> void:
	if node == null:
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_below(child)


func _on_toggled(pressed: bool) -> void:
	if select_badge:
		select_badge.visible = pressed
	_selection_toggled(pressed)


## Override to announce a toggle in the subclass's own signal shape.
func _selection_toggled(_pressed: bool) -> void:
	pass
```

- [ ] **Step 4: Run the tests to verify they pass**

Run `filesystem_manage(op="scan")` (new `class_name`), then:
`test_run(suite="student_card_button")` and `test_run(suite="script_documentation")`
Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/UI/StudentCardButton.gd Scripts/UI/StudentCardButton.gd.uid tests/test_student_card_button.gd
git commit -m "feat(ui): StudentCardButton, a tappable host for the DaySummary card" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

(If the editor has not written `StudentCardButton.gd.uid` yet, add it in the next task's commit.)

---

### Task 5: EventStudentCard on the real card

**Files:**
- Modify: `tests/test_day_summary.gd:1457-1517` and `:1587-1594` (the event-card block; the dialog tests between them stay).
- Modify: `tests/test_student_summary_card.gd:36` and `:91-96`.
- Rewrite: `Scripts/SchoolSimulation/EventStudentCard.gd`
- Modify: `Scripts/SchoolSimulation/EventStudentSelectDialog.gd:3-9`, `:45-48`, `:171`
- Rebuild (editor): `Scenes/SchoolSimulation/EventStudentCard.tscn`

**Interfaces:**
- Consumes (Task 3): `DaySummaryStudentRow.setup_current_row`, `preview_stat` and `preview_need`.
- Consumes (Task 4): `StudentCardButton`.
- Produces: `EventStudentCard` with its API unchanged: `signal selection_changed(selected: bool)`, `setup(student, category)`, `set_preview(stat_delta, energy_delta, mood_delta)`, `student()`, `is_selected()` and `set_selectable(on)`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_day_summary.gd`, replace `test_event_card_reuses_the_day_summary_parts` and `test_event_card_needs_bars_carry_their_icon_and_word` (lines 1464-1489) with:

```gdscript
func test_event_card_reuses_the_day_summary_parts() -> void:
	# Since 2026-09-12 the event card hosts the REAL DaySummary card rather
	# than a hand-made copy of its layout, so the two can never drift again.
	var packed := load(EVENT_CARD_SCENE) as PackedScene
	assert_not_null(packed, "EventStudentCard.tscn should load")
	var card := packed.instantiate()
	var inner := card.get_node_or_null("Card")
	assert_true(inner is DaySummaryStudentRow, "the event card hosts DaySummaryStudentRow")
	if inner != null:
		assert_eq(inner.scene_file_path,
			"res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	for part in ["Avatar", "EnergyBar", "MoodBar", "StatRow1", "StatRow2", "StatRow3"]:
		assert_not_null(card.get_node_or_null("Card/" + part), part + " comes from the real card")
	card.free()


func test_event_card_needs_bars_carry_their_icon_and_word() -> void:
	var card := (load(EVENT_CARD_SCENE) as PackedScene).instantiate()
	for bar_name in ["EnergyBar", "MoodBar"]:
		var bar := card.get_node("Card/%s" % bar_name)
		assert_not_null(bar.get_node_or_null("Icon"), "%s needs an Icon child" % bar_name)
		assert_not_null(bar.get_node_or_null("Word"), "%s needs a Word child" % bar_name)
	card.free()


func test_event_card_shows_current_stats_and_previews() -> void:
	var card := (load(EVENT_CARD_SCENE) as PackedScene).instantiate() as EventStudentCard
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var s := StudentData.new()
	s.student_name = "Budi"
	s.akademis = 30.0
	s.target_akademis1 = 60.0
	s.energy = 60.0
	s.mood = 50.0
	card.setup(s, "Akademis")
	var row := card.get_node("Card/StatRow1") as DaySummaryStatRow
	assert_eq(row.value.text, "30/60", "the card shows where the student stands")
	assert_true((card.get_node("Card/EnergyBar/Icon") as TextureRect).texture != null,
		"the energy bar carries its icon now")
	card.set_preview(15.0, -15.0, 0.0)
	assert_eq(row.value.text, "+15/60", "selecting layers the event's gain")
	assert_eq((card.get_node("Card/EnergyBar") as DaySummaryNeedsBar).value, 45.0)
	card.set_preview(0.0, 0.0, 0.0)
	assert_eq(row.value.text, "30/60", "zeroes rewind to the standing view")


## Pattern C: an instanced card under a plain Control loses its rect on load
## unless something owns it. StudentCardButton does; this checks the loaded,
## in-tree result, not the scene text.
func test_event_card_keeps_its_card_rect_after_loading() -> void:
	var card := (load(EVENT_CARD_SCENE) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.size = Vector2(992, 410)
	# Run the fit directly rather than waiting on NOTIFICATION_RESIZED.
	card.call("_fit_card")
	var inner := card.get_node("Card") as Control
	assert_eq(inner.position, Vector2.ZERO)
	assert_eq(inner.size, Vector2(992, 410))
	assert_eq(inner.scale, Vector2.ONE, "992 wide is native size")


func test_event_card_badges_sit_on_the_card() -> void:
	# The select badge used to hang 18 px below the card's bottom edge.
	var card := (load(EVENT_CARD_SCENE) as PackedScene).instantiate()
	var bounds := Rect2(Vector2.ZERO, Vector2(992, 410))
	for badge in ["SelectBadge", "TiredBadge", "SpecialtyBadge"]:
		var node := card.get_node_or_null("Card/" + badge) as Control
		assert_true(node != null, badge + " lives under Card so it scales with it")
		if node == null:
			continue
		var r := Rect2(Vector2(node.offset_left, node.offset_top),
			Vector2(node.offset_right - node.offset_left, node.offset_bottom - node.offset_top))
		assert_true(bounds.encloses(r), "%s must sit inside the card" % badge)
	card.free()
```

In the same file, in `test_event_card_is_a_toggle_not_a_scaled_checkbox` (line 1492), add this line after the `assert_true(card is Button, ...)` line:

```gdscript
	assert_true(card is StudentCardButton, "the card uses the shared tappable wrapper")
```

Replace `test_event_card_children_do_not_swallow_the_tap` (lines 1587-1594) with:

```gdscript
func test_event_card_children_do_not_swallow_the_tap() -> void:
	# The whole card is the tap target. Any part left on the default mouse
	# filter would eat the click over its own rect. StudentCardButton sets
	# every Card descendant to IGNORE when it enters the tree.
	var card := (load(EVENT_CARD_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var stack: Array[Node] = [card.get_node("Card")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s should ignore the mouse so the card gets the tap" % n.name)
		stack.append_array(n.get_children())
```

In `tests/test_student_summary_card.gd`:
- Delete line 36 (`const EVENT_SELECT_PATH := ...`).
- Change the loop at line 92 to `for path in [SCHOOL_DAY_PATH, DECAY_PATH]:`.
- After header line 6, add the line `## (EventStudentSelectDialog left this chrome on 2026-09-07; its cards are EventStudentCard.)`

- [ ] **Step 2: Run the tests to verify they fail**

No-op `script_patch` on both test files, then run: `test_run(suite="day_summary", test_name="event_card")`
Expected: FAIL. There is no `Card` child and `EventStudentCard` is not a `StudentCardButton`.

- [ ] **Step 3: Rewrite the script**

Replace the whole of `Scripts/SchoolSimulation/EventStudentCard.gd` with:

```gdscript
@tool
class_name EventStudentCard
extends StudentCardButton

## One selectable student on the event dialog: the real DaySummary card
## (DaySummaryStudentRow, the Card child) inside StudentCardButton's toggle.
## The card shows where the student stands now; selecting it layers the
## event's effect on top (2026-09-12 event-cards spec, section 1.4).

## Fired when the player toggles this card. `selected` is the new state.
signal selection_changed(selected: bool)

## Which stat key each schedule category previews against.
const STAT_KEY_FOR_CATEGORY := {
	"Akademis": "akademis",
	"SeniBudaya": "seni_budaya",
	"Olahraga": "olahraga",
}

## Shown when the student is too tired to be sent.
@onready var tired_badge: TextureRect = get_node_or_null("Card/TiredBadge") as TextureRect
## Shown when the event's category is the student's specialty.
@onready var specialty_badge: TextureRect = get_node_or_null("Card/SpecialtyBadge") as TextureRect

var _student: StudentData = null
var _category: String = "Akademis"


## Writes the student's CURRENT stats onto the card, with no preview. Call
## after the card is in the tree: the card's parts are only ready then.
func setup(student: StudentData, category: String) -> void:
	_student = student
	_category = category
	if student == null:
		return
	card.setup_current_row(student)
	var is_tired: bool = student.is_tired()
	tired_badge.visible = is_tired
	specialty_badge.visible = student.specialty_category == category and not is_tired
	set_selectable(not is_tired)


## Layers the event's effect over the current values: its own category's
## stat row and both needs bars. Pass zeroes to rewind to the standing view.
func set_preview(stat_delta: float, energy_delta: float, mood_delta: float) -> void:
	if _student == null:
		return
	card.preview_stat(STAT_KEY_FOR_CATEGORY.get(_category, "akademis"), stat_delta)
	card.preview_need("energy", energy_delta)
	card.preview_need("mood", mood_delta)


## The student this card stands for, so the dialog can read their efficiency
## multiplier without reaching into the card's internals.
func student() -> StudentData:
	return _student


func _selection_toggled(pressed: bool) -> void:
	selection_changed.emit(pressed)
```

In `Scripts/SchoolSimulation/EventStudentSelectDialog.gd`:
- Replace header lines 3-9 with:

```gdscript
## "Who takes part in this event?" — one selectable card per student with
## a live preview of what accepting would do to their stats.
##
## Each student is an EventStudentCard: the real DaySummary card inside a
## toggle Button (StudentCardButton), showing where the student stands now.
## Selecting a card layers the event's effect on top. The dialog's own
## chrome is theme-driven; nothing here builds a StyleBoxFlat.
```

- Replace the comment at lines 45-48 with:

```gdscript
# Each selectable student is EventStudentCard.tscn: the real DaySummary card
# inside a toggle Button. The cards used to be assembled here at runtime;
# that went on 2026-09-07.
```

- Change line 171 from `card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER` to `card.size_flags_horizontal = Control.SIZE_FILL`.

- [ ] **Step 4: Restart the editor, then rebuild the scene**

Restart the editor (protocol 2), then run `filesystem_manage(op="scan")`, then:

`scene_open(path="res://Scenes/SchoolSimulation/EventStudentCard.tscn")`, then one `batch_execute` with these commands, in order:

```json
[
 {"command": "delete_node", "params": {"path": "/EventStudentCard/CardArt"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/Avatar"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/NameLabel"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/EnergyBar"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/MoodBar"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/StatRow1"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/StatRow2"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/StatRow3"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/SelectBadge"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/TiredBadge"}},
 {"command": "delete_node", "params": {"path": "/EventStudentCard/SpecialtyBadge"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard", "property": "custom_minimum_size", "value": {"x": 0, "y": 0}}},
 {"command": "create_node", "params": {"parent_path": "/EventStudentCard", "name": "Card", "scene_path": "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"}},

 {"command": "create_node", "params": {"parent_path": "/EventStudentCard/Card", "name": "SelectBadge", "type": "TextureRect"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "texture", "value": "res://Assets/Images/UI/Placeholders/icon_check.svg"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "expand_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "stretch_mode", "value": 5}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "mouse_filter", "value": 2}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "visible", "value": false}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "offset_left", "value": 900}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "offset_top", "value": 318}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "offset_right", "value": 972}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SelectBadge", "property": "offset_bottom", "value": 390}},

 {"command": "create_node", "params": {"parent_path": "/EventStudentCard/Card", "name": "TiredBadge", "type": "TextureRect"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "texture", "value": "res://Assets/Images/UI/Placeholders/icon_tired.svg"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "expand_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "stretch_mode", "value": 5}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "mouse_filter", "value": 2}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "visible", "value": false}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "offset_left", "value": 262}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "offset_top", "value": 30}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "offset_right", "value": 332}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/TiredBadge", "property": "offset_bottom", "value": 100}},

 {"command": "create_node", "params": {"parent_path": "/EventStudentCard/Card", "name": "SpecialtyBadge", "type": "TextureRect"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "texture", "value": "res://Assets/Images/UI/Placeholders/icon_star.svg"}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "expand_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "stretch_mode", "value": 5}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "mouse_filter", "value": 2}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "visible", "value": false}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "offset_left", "value": 262}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "offset_top", "value": 30}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "offset_right", "value": 332}},
 {"command": "set_property", "params": {"path": "/EventStudentCard/Card/SpecialtyBadge", "property": "offset_bottom", "value": 100}}
]
```

Then `scene_save()`, then protocol 4 (`git diff --stat -- '*.gd'` shows only the files this task edits).
Check `git diff Scenes/SchoolSimulation/EventStudentCard.tscn`: one `instance=` of `DaySummaryStudentRow.tscn` named `Card`, and three badges with `parent="Card"`.

The tired and specialty badges sit on the avatar's top-right corner. The name label now runs to x = 700, so their old spot at x = 672 would cover it.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="day_summary")`, `test_run(suite="event_student_card_tired")`, `test_run(suite="student_summary_card")`, `test_run(suite="school_day")`, `test_run(suite="viewport_editability")`, `test_run(suite="script_documentation")`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/EventStudentCard.gd Scenes/SchoolSimulation/EventStudentCard.tscn Scripts/SchoolSimulation/EventStudentSelectDialog.gd tests/test_day_summary.gd tests/test_student_summary_card.gd Scripts/UI/StudentCardButton.gd.uid
git commit -m "feat(event-dialog): student cards host the real DaySummary card" -m "Fixes the copy's drift: the needs bars get their icons, the name label matches, the check badge sits back on the card, and the preview animates." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: ApplyStudentRow on the real card

**Files:**
- Rewrite: `tests/test_apply_student_row.gd`
- Modify: `tests/test_light_ground_text.gd:174-188`, `:207`, plus one helper.
- Rewrite: `Scripts/Inventory/ApplyStudentRow.gd`
- Recreate (editor): `Scenes/Inventory/ApplyStudentRow.tscn`
- Re-assign (editor): `Scenes/Inventory/ApplyItemScreen.tscn`

**Interfaces:**
- Consumes (Task 1): `GameState.student_data_from_dict`.
- Consumes (Task 3): `setup_current_row`, `show_only`, `preview_stat` and `preview_need`.
- Consumes (Task 4): `StudentCardButton`.
- Produces: `ApplyStudentRow` with its API unchanged: `signal selection_changed` (no arguments), `KEY`, `tired_energy_threshold`, `student`, `setup(p_student: Dictionary, boosts: Dictionary)`, `set_preview(active: bool)`, `is_selected()`, `can_select()`, `set_selected(on)` and `selected_student_id()`. It also exposes the new `lelah_chip: Control`.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `tests/test_apply_student_row.gd` with:

```gdscript
@tool
extends McpTestSuite

## ApplyStudentRow on the real DaySummary card (2026-09-12 event-cards spec,
## 1.5). The content is unchanged from the old checkbox row: KEY maps to the
## canonical roster keys, only the boosted stats show, the preview raises
## then restores them, a stat at 100 reads MAKS, and a tired student cannot
## be picked and shows LELAH.

func suite_name() -> String:
	return "apply_student_row"


const _ROW := "res://Scenes/Inventory/ApplyStudentRow.tscn"


func _make() -> ApplyStudentRow:
	var row: ApplyStudentRow = (load(_ROW) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	return row


func _student(energy := 50.0) -> Dictionary:
	return {"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": energy,
		"akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0,
		"target_akademis1": 80.0, "target_akademis2": 80.0, "target_akademis3": 80.0}


func test_key_map_targets_canonical_roster_keys() -> void:
	assert_eq(ApplyStudentRow.KEY["akademis"], "akademis1")
	assert_eq(ApplyStudentRow.KEY["seni_budaya"], "akademis2")
	assert_eq(ApplyStudentRow.KEY["olahraga"], "akademis3")
	assert_eq(ApplyStudentRow.KEY["mood"], "kepribadian1")
	assert_eq(ApplyStudentRow.KEY["energy"], "kepribadian2")


func test_row_is_a_card_button_on_the_day_summary_card() -> void:
	var row := _make()
	assert_true(row is StudentCardButton, "the whole card is the tap target")
	assert_true(row.toggle_mode)
	var card := row.get_node_or_null("Card")
	assert_true(card is DaySummaryStudentRow, "the row hosts the real card")
	if card != null:
		assert_eq(card.scene_file_path, "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	assert_true(row.find_child("Check", true, false) == null, "the checkbox is gone")


func test_setup_shows_only_boosted_stats() -> void:
	var row := _make()
	row.setup(_student(), {"mood": 10, "olahraga": 5})
	var card: DaySummaryStudentRow = row.card
	assert_true(card.mood_bar.visible, "mood is boosted")
	assert_false(card.energy_bar.visible, "energy is not")
	assert_true(card.stat_rows[0].visible)
	assert_eq(card.stat_rows[0].value.text, "40/80", "olahraga fills the top slot")
	assert_false(card.stat_rows[1].visible)
	assert_false(card.stat_rows[2].visible)


func test_preview_raises_then_restores() -> void:
	var row := _make()
	row.setup(_student(), {"mood": 20, "akademis": 8})
	var card: DaySummaryStudentRow = row.card
	assert_eq(int(card.mood_bar.value), 50, "the bar starts at current")
	row.set_preview(true)
	assert_eq(int(card.mood_bar.value), 70, "mood previews the boost")
	assert_eq(card.stat_rows[0].value.text, "+8/80", "akademis previews its gain")
	row.set_preview(false)
	assert_eq(int(card.mood_bar.value), 50, "preview off restores current")
	assert_eq(card.stat_rows[0].value.text, "40/80")


func test_stat_at_100_reads_maks() -> void:
	var s := _student()
	s["akademis1"] = 100.0
	var row := _make()
	row.setup(s, {"akademis": 5})
	row.set_preview(true)
	assert_eq(row.card.stat_rows[0].value.text, "MAKS")


func test_tired_student_cannot_be_selected() -> void:
	var row := _make()
	row.setup(_student(4.0), {"mood": 10})
	assert_true(row.disabled, "tired -> the card refuses the tap")
	assert_false(row.is_selected(), "tired student not selected")
	assert_true(row.lelah_chip.visible, "LELAH shows")
	assert_true(absf(row.modulate.a - 0.55) <= 0.01, "and the card dims")


func test_toggle_emits_argumentless_selection_changed() -> void:
	# ApplyItemScreen connects _refresh_confirm, which takes no arguments.
	var row := _make()
	row.setup(_student(), {"mood": 10})
	var hits := [0]
	row.selection_changed.connect(func() -> void: hits[0] += 1)
	row.button_pressed = true
	assert_eq(hits[0], 1)
	assert_true(row.is_selected())
```

In `tests/test_light_ground_text.gd`, replace `test_the_apply_rows_preview_reads_on_its_card` (lines 174-188) with:

```gdscript
## The apply-item preview readout. Since 2026-09-12 it is the DaySummary
## card's stat number laid over its dark track, so it is measured on the
## track's own flat fill in each state the preview leaves it in: standing,
## previewing, and back.
func test_the_apply_rows_preview_reads_on_its_card() -> void:
	var row := _apply_row()
	var value: Label = row.get_node("Card/StatRow1/Value")
	var ground := _track_fill(row.get_node("Card/StatRow1/Track"))
	_assert_reads(value, ground, "on the apply-item card before any preview")
	row.set_preview(true)
	_assert_reads(value, ground, "in the apply-item preview")
	row.set_preview(false)
	_assert_reads(value, ground, "on the apply-item card after the preview")
```

On line 207, change `_apply_row().get_node("Margin/HBox/Col/BarRowAkademis/DeltaLabel")]` to `_apply_row().get_node("Card/StatRow1/Value")]`.

Directly after the `_flat_fill` helper, add:

```gdscript


## A ProgressBar's empty-track colour: the flat fill of its "background"
## stylebox, which is what a label laid over the track reads against.
func _track_fill(bar: Control) -> Color:
	var box := bar.get_theme_stylebox("background") as StyleBoxFlat
	assert_true(box != null, "%s's track must be a flat fill to be measured" % bar.name)
	return box.bg_color if box != null else Color.BLACK
```

- [ ] **Step 2: Run the tests to verify they fail**

No-op `script_patch` on both test files, then run: `test_run(suite="apply_student_row")`
Expected: FAIL. The row is still a PanelContainer with a CheckBox.

- [ ] **Step 3: Rewrite the script**

Replace the whole of `Scripts/Inventory/ApplyStudentRow.gd` with:

```gdscript
@tool
class_name ApplyStudentRow
extends StudentCardButton

## One selectable student on ApplyItemScreen, wearing the real DaySummary
## card (2026-09-12 event-cards spec, section 1.5). The content is unchanged
## from the old checkbox row: only the stats the item boosts are shown,
## picking the card previews the gain, a stat already at 100 reads MAKS, and
## a student too tired to benefit shows LELAH and cannot be picked.

## Fired whenever the player picks or un-picks this student.
signal selection_changed

## Logical boost name -> the roster Dictionary key it writes. Fixed mapping:
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy (the project's canonical keys).
const KEY := {
	"akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
	"mood": "kepribadian1", "energy": "kepribadian2",
}

## kepribadian2 (energy) at or below this forces "Izin" -- such a student
## cannot take the item, so the card cannot be picked.
@export var tired_energy_threshold: float = 5.0

## The LELAH chip, authored under Card. Tinted state_danger at setup.
@onready var lelah_chip: Control = get_node_or_null("Card/LelahChip") as Control

## The roster entry this row stands for.
var student: Dictionary = {}
var _boosts: Dictionary = {}


## Fill the card from a roster entry and the item's non-zero boosts. Call
## after the row is in the tree: the card's parts are only ready then.
func setup(p_student: Dictionary, boosts: Dictionary) -> void:
	student = p_student
	_boosts = {}
	for k in boosts:
		if int(boosts[k]) != 0:
			_boosts[k] = int(boosts[k])
	var sd: StudentData = GameState.student_data_from_dict(student)
	card.setup_current_row(sd)
	card.show_only(_boosts.keys())
	var is_tired := float(student.get("kepribadian2", 100.0)) <= tired_energy_threshold
	lelah_chip.visible = is_tired
	if is_tired:
		lelah_chip.self_modulate = DesignTokens.load_default().state_danger
	set_selectable(not is_tired)


## Show (or clear) what the item would do to each boosted stat.
func set_preview(active: bool) -> void:
	for key in _boosts:
		var cur := float(student.get(KEY[key], 0.0))
		var after := clampf(cur + float(_boosts[key]), 0.0, 100.0)
		var delta := (after - cur) if active else 0.0
		if key == "mood" or key == "energy":
			card.preview_need(key, delta)
		else:
			card.preview_stat(key, delta, active and cur >= 100.0)


## False for a student too tired to take the item.
func can_select() -> bool:
	return not disabled


## Pick or un-pick this student, unless they cannot be picked.
func set_selected(on: bool) -> void:
	if not disabled:
		button_pressed = on


## The roster id of the student this row stands for.
func selected_student_id() -> int:
	return int(student.get("id", -1))


func _selection_toggled(pressed: bool) -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"select")
	set_preview(pressed)
	selection_changed.emit()
```

- [ ] **Step 4: Restart the editor, then recreate the scene**

The root's type changes from PanelContainer to Button, and a node's type cannot be changed in place, so the scene is recreated.

1. Restart the editor (protocol 2). Then delete `Scenes/Inventory/ApplyStudentRow.tscn` from disk and run `filesystem_manage(op="scan")`.
2. `scene_manage(op="create", params={"path": "res://Scenes/Inventory/ApplyStudentRow.tscn", "root_type": "Button", "root_name": "ApplyStudentRow"})`
3. Run one `batch_execute`:

```json
[
 {"command": "set_property", "params": {"path": "/ApplyStudentRow", "property": "script", "value": "res://Scripts/Inventory/ApplyStudentRow.gd"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow", "property": "theme", "value": "res://Assets/Theme/kejartes_theme.tres"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow", "property": "theme_type_variation", "value": "EventSelectCard"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow", "property": "toggle_mode", "value": true}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow", "property": "focus_mode", "value": 0}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow", "property": "size_flags_horizontal", "value": 3}},
 {"command": "create_node", "params": {"parent_path": "/ApplyStudentRow", "name": "Card", "scene_path": "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"}},

 {"command": "create_node", "params": {"parent_path": "/ApplyStudentRow/Card", "name": "SelectBadge", "type": "TextureRect"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "texture", "value": "res://Assets/Images/UI/Placeholders/icon_check.svg"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "expand_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "stretch_mode", "value": 5}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "mouse_filter", "value": 2}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "visible", "value": false}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "offset_left", "value": 900}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "offset_top", "value": 318}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "offset_right", "value": 972}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/SelectBadge", "property": "offset_bottom", "value": 390}},

 {"command": "create_node", "params": {"parent_path": "/ApplyStudentRow/Card", "name": "LelahChip", "type": "PanelContainer"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip", "property": "theme_type_variation", "value": "SunkenPanel"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip", "property": "mouse_filter", "value": 2}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip", "property": "visible", "value": false}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip", "property": "offset_left", "value": 262}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip", "property": "offset_top", "value": 30}},
 {"command": "create_node", "params": {"parent_path": "/ApplyStudentRow/Card/LelahChip", "name": "Text", "type": "Label"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip/Text", "property": "theme_type_variation", "value": "BarLabel"}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip/Text", "property": "text", "value": " LELAH "}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip/Text", "property": "horizontal_alignment", "value": 1}},
 {"command": "set_property", "params": {"path": "/ApplyStudentRow/Card/LelahChip/Text", "property": "vertical_alignment", "value": 1}}
]
```

4. `scene_save()`
5. `scene_open(path="res://Scenes/Inventory/ApplyItemScreen.tscn")`, then `node_set_property(path="/ApplyItemScreen", property="student_row_scene", value="res://Scenes/Inventory/ApplyStudentRow.tscn")` and `scene_save()`. The scene's root is named `ApplyItemScreen`. This rewrites the ext_resource with the new scene's UID.
6. Protocol 4. Then check `git diff Scenes/Inventory/ApplyItemScreen.tscn`: only the `ApplyStudentRow.tscn` ext_resource's `uid=` changes.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="apply_student_row")`, `test_run(suite="apply_item_screen")`, `test_run(suite="light_ground_text")`, `test_run(suite="item_detail_sheet")`, `test_run(suite="use_item_on_students")`, `test_run(suite="project_hygiene")`, `test_run(suite="viewport_editability")`, `test_run(suite="script_documentation")`
Expected: all PASS. `project_hygiene` proves the re-assigned UID resolves.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Inventory/ApplyStudentRow.gd Scenes/Inventory/ApplyStudentRow.tscn Scenes/Inventory/ApplyItemScreen.tscn tests/test_apply_student_row.gd tests/test_light_ground_text.gd
git commit -m "feat(inventory): item-screen rows wear the DaySummary card" -m "Same content (boosted stats only, the preview, MAKS, LELAH); the checkbox row becomes the shared tappable card, and the readout moves to the card's current/target and +N/target." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Warning tokens and theme variations

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (after line 375, `day_needs_label_size`)
- Modify: `Scripts/Design/ThemeFactory.gd` (add a call in `build()` after line 26, plus a new function)
- Modify: `tests/test_theme_factory.gd:326` (`DISPLAY_ROSTER`)
- Create: `tests/test_event_warning.gd`
- Rebake: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces:
  - Tokens `event_warning_bg: Color`, `event_warning_ink: Color` and `event_warning_caption_outline: int`.
  - Theme variations `EventWarningPanel` (a Panel) and `EventWarningCaptionLabel` (a Label).
  - Both variations are used by Task 8.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_event_warning.gd`:

```gdscript
@tool
extends McpTestSuite

## The slide warning (2026-09-12 event-cards spec, section 2): its tokens and
## theme variations, its authored scene and motion, and SchoolDay's use of
## it for both minigames and random events.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "event_warning"


func test_warning_tokens_match_the_mockup() -> void:
	var t := DesignTokens.load_default()
	assert_eq(t.event_warning_bg, Color("9E8830"), "mockup_eventwarning.png's panel")
	assert_eq(t.event_warning_ink, Color("1D196E"), "the icon's outline navy")
	assert_eq(t.event_warning_caption_outline, 16)


func test_factory_builds_both_variations() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	assert_eq(theme.get_type_variation_base("EventWarningPanel"), &"Panel")
	var box := theme.get_stylebox("panel", "EventWarningPanel") as StyleBoxFlat
	assert_true(box != null, "the panel is a flat fill")
	if box != null:
		assert_eq(box.bg_color, t.event_warning_bg)
	assert_eq(theme.get_type_variation_base("EventWarningCaptionLabel"), &"Label")
	assert_eq(theme.get_color("font_color", "EventWarningCaptionLabel"), t.text_on_brand)
	assert_eq(theme.get_color("font_outline_color", "EventWarningCaptionLabel"), t.event_warning_ink)
	assert_eq(theme.get_constant("outline_size", "EventWarningCaptionLabel"),
		t.event_warning_caption_outline)
	assert_eq(theme.get_font_size("font_size", "EventWarningCaptionLabel"), t.font_display_size)


func test_the_bake_declares_both_variations() -> void:
	var baked := ResourceLoader.load(_THEME_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for variation in ["EventWarningPanel", "EventWarningCaptionLabel"]:
		assert_true(baked.get_type_list().has(variation),
			variation + " must be in the baked theme -- rebake")


## WCAG large-text floor (3:1). The caption is display-size, and its navy rim
## must hold the floor on its own.
func test_caption_reads_on_the_panel() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	var fill := _contrast(theme.get_color("font_color", "EventWarningCaptionLabel"),
		t.event_warning_bg)
	var rim := _contrast(t.event_warning_ink, t.event_warning_bg)
	assert_true(maxf(fill, rim) >= 3.0,
		"caption fill %.2f:1, rim %.2f:1 on the panel" % [fill, rim])
	assert_true(rim >= 3.0, "the navy rim alone must hold 3:1, got %.2f" % rim)


func _luminance(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
```

In `tests/test_theme_factory.gd`, directly after the line `"EventDialogHeaderLabel",` (line 326), add:

```gdscript
	# 2026-09-12: the slide warning's caption, display face at DisplayLabel size.
	"EventWarningCaptionLabel",
```

- [ ] **Step 2: Run the tests to verify they fail**

No-op `script_patch` on both test files, then run: `test_run(suite="event_warning")`
Expected: FAIL. The token properties do not exist.

- [ ] **Step 3: Implement**

In `Scripts/Design/DesignTokens.gd`, directly after `@export var day_needs_label_size: int = 30` (line 375), add:

```gdscript

## Event warning (2026-09-12 slide warning, mockup_eventwarning.png).
## The full-screen panel the warning slides through the screen on.
@export var event_warning_bg: Color = Color("9E8830")
## The navy of eventwarning_icon.png's outline. The caption's rim wears it,
## so the words and the megaphone read as one mark.
@export var event_warning_ink: Color = Color("1D196E")
## Thickness of the warning caption's navy rim, in design pixels.
@export var event_warning_caption_outline: int = 16
```

In `Scripts/Design/ThemeFactory.gd`, in `build()`, directly after `_build_minigame_result(theme, tokens)` (line 26), add:

```gdscript
	_build_event_warning(theme, tokens)
```

Then add this function directly after `build()`, before `_add_shop_hub_tile`:

```gdscript


## The slide warning (2026-09-12 event-cards spec, 2.1): a flat mustard
## panel from the mockup, and a display-face caption in the light brand text
## colour rimmed in the icon's navy, so the words and the megaphone read as
## one mark.
static func _build_event_warning(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("EventWarningPanel")
	theme.set_type_variation("EventWarningPanel", "Panel")
	var panel := StyleBoxFlat.new()
	panel.bg_color = tokens.event_warning_bg
	theme.set_stylebox("panel", "EventWarningPanel", panel)

	theme.add_type("EventWarningCaptionLabel")
	theme.set_type_variation("EventWarningCaptionLabel", "Label")
	theme.set_font_size("font_size", "EventWarningCaptionLabel", tokens.font_display_size)
	theme.set_color("font_color", "EventWarningCaptionLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "EventWarningCaptionLabel",
		tokens.event_warning_caption_outline)
	theme.set_color("font_outline_color", "EventWarningCaptionLabel", tokens.event_warning_ink)
	if tokens.font_display != null:
		theme.set_font("font", "EventWarningCaptionLabel", tokens.font_display)
```

- [ ] **Step 4: Restart, rebake, restart again**

1. Restart the editor. A new `@export` on a Resource is invisible until a full restart (protocol 6).
2. Rebake: `test_run(suite="theme_rebake")`. This suite builds the theme and saves it to `kejartes_theme.tres`.
3. `git diff Assets/Theme/kejartes_theme.tres | grep -c EventWarning` must be at least 2. Skim the diff. It should add the two variations; stylebox ids may renumber, and that is expected.
4. Restart the editor again, so no scene save can write a stale cached theme back (memory note: rebake alone, then restart).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="event_warning")`, `test_run(suite="theme_factory")`, `test_run(suite="design_tokens")`, `test_run(suite="script_documentation")`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_event_warning.gd tests/test_theme_factory.gd
git commit -m "feat(theme): tokens and variations for the slide warning" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: The slide warning scene

**Files:**
- Create: `Assets/Images/SchoolDay/eventwarning_icon.png` (plus its `.import`, written by the editor)
- Rewrite: `Scripts/SchoolSimulation/EventWarning.gd`
- Rebuild (editor): `Scenes/SchoolSimulation/EventWarning.tscn`
- Modify: `tests/test_event_warning.gd` (append), `tests/test_event_polish.gd:52-56`, `tests/test_school_day.gd:300-313`, `tests/test_viewport_editability.gd:110`

**Interfaces:**
- Consumes (Task 7): `EventWarningPanel` and `EventWarningCaptionLabel`.
- Produces, used by Task 9:
  - `play_warning(caption_text: String) -> void` (awaitable)
  - `static func panel_x(stage: StringName, width: float) -> float`
  - Exports `icon_texture`, `slide_in_duration`, `hold_duration` and `slide_out_duration`.

- [ ] **Step 1: Crop the icon**

The source is `C:\Users\user\Downloads\eventwarning_icon.png`. If it is missing, download Drive file `1AKGdEm9xNmxJT9LIgGv_0yb8q-67KhOe` (`icon/eventwarning_icon.png`) there first. The art occupies x 179-901, y 472-1190 of the 1080×1920 canvas. Crop it with a 16 px pad on each side (PowerShell):

```powershell
Add-Type -AssemblyName System.Drawing
$src = New-Object System.Drawing.Bitmap 'C:\Users\user\Downloads\eventwarning_icon.png'
$pad = 16
$rect = New-Object System.Drawing.Rectangle (179 - $pad), (472 - $pad), (723 + 2 * $pad), (719 + 2 * $pad)
$out = $src.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
New-Item -ItemType Directory -Force 'Assets\Images\SchoolDay' | Out-Null
$out.Save('Assets\Images\SchoolDay\eventwarning_icon.png', [System.Drawing.Imaging.ImageFormat]::Png)
"$($out.Width)x$($out.Height)"
$out.Dispose(); $src.Dispose()
```

Expected output: `755x751`.

- [ ] **Step 2: Write the failing tests**

Append to `tests/test_event_warning.gd`:

```gdscript


# ── The scene and its motion ─────────────────────────────────────────────────

const _SCENE := "res://Scenes/SchoolSimulation/EventWarning.tscn"
const _SCRIPT := "res://Scripts/SchoolSimulation/EventWarning.gd"
const _ICON := "res://Assets/Images/SchoolDay/eventwarning_icon.png"


func _warning() -> Control:
	var w: Control = (load(_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(w)
	track(w)
	return w


func test_scene_is_the_authored_slide_panel() -> void:
	var w := _warning()
	var panel := w.get_node_or_null("Panel") as Panel
	assert_true(panel != null, "the panel that slides")
	if panel == null:
		return
	assert_eq(panel.theme_type_variation, &"EventWarningPanel")
	assert_eq(panel.anchor_right, 1.0, "the panel covers the screen")
	assert_eq(panel.anchor_bottom, 1.0)
	var icon := w.get_node_or_null("Panel/Center/Content/Icon") as TextureRect
	var caption := w.get_node_or_null("Panel/Center/Content/Caption") as Label
	assert_true(icon != null and caption != null, "icon over caption")
	if caption != null:
		assert_eq(caption.theme_type_variation, &"EventWarningCaptionLabel")
	assert_eq(w.mouse_filter, Control.MOUSE_FILTER_STOP, "taps are swallowed while it runs")
	for retired in ["Background", "TopBar", "BottomBar", "Center"]:
		assert_true(w.get_node_or_null(retired) == null,
			retired + " belonged to the old hazard-stripe warning")


func test_icon_is_the_cropped_art() -> void:
	var tex := load(_ICON) as Texture2D
	assert_true(tex != null, "the cropped art is imported")
	if tex == null:
		return
	assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(755, 751),
		"cropped to the art plus a 16 px pad, not the 1080x1920 canvas")
	var w := _warning()
	assert_eq((w.get("icon_texture") as Texture2D).resource_path, _ICON)
	var icon := w.get_node("Panel/Center/Content/Icon") as TextureRect
	assert_eq(icon.texture.resource_path, _ICON)


func test_panel_passes_right_to_left() -> void:
	var script = load(_SCRIPT)
	assert_eq(script.panel_x(&"enter", 1080.0), 1080.0, "enters from the right edge")
	assert_eq(script.panel_x(&"rest", 1080.0), 0.0)
	assert_eq(script.panel_x(&"exit", 1080.0), -1080.0, "leaves through the left edge")


func test_timings_match_the_spec() -> void:
	var w := _warning()
	assert_eq(w.get("slide_in_duration"), 0.35)
	assert_eq(w.get("hold_duration"), 1.1)
	assert_eq(w.get("slide_out_duration"), 0.35)


func test_one_cue_and_nothing_built() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_contains(src, 'play_sfx(&"event_announce")', "one cue for every warning")
	assert_false(src.contains("popup_open"), "SchoolDay's old second cue is gone")
	assert_false(src.contains(".new("), "the scene is fully authored")
	assert_false(src.contains("⚠"), "no emoji fallback")
```

In `tests/test_event_polish.gd`, replace `test_warning_no_longer_uses_emoji` (lines 52-56) with:

```gdscript
func test_warning_no_longer_uses_emoji() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventWarning.tscn")
	assert_false(src.contains('"⚠️"'), "Warning emoji glyph must be gone")
	assert_true(src.contains("eventwarning_icon.png"),
		"The warning carries the megaphone art (2026-09-12 slide warning)")
```

In `tests/test_school_day.gd`, delete `test_hazard_stripe_color_comes_from_tokens_at_runtime` (lines 300-313). The stripes are gone.

In `tests/test_viewport_editability.gd`, delete the line `"res://Scripts/SchoolSimulation/EventWarning.gd": 2,` (line 110). The `EventAnnouncement.gd` line above it stays until Task 10.

- [ ] **Step 3: Run the tests to verify they fail**

No-op `script_patch` on the four test files, run `filesystem_manage(op="scan")` (imports the icon), then run: `test_run(suite="event_warning")`
Expected: FAIL. There is no `Panel` node and no `panel_x`.

- [ ] **Step 4: Rewrite the script**

Replace the whole of `Scripts/SchoolSimulation/EventWarning.gd` with:

```gdscript
@tool
extends Control

## The full-screen "something is about to happen" warning (2026-09-12
## event-cards spec, section 2). A flat mustard panel carrying the
## eventwarning_icon art and one caption line slides in from the right edge,
## holds, and keeps going out through the left edge. It fronts both kinds of
## mid-day interruption: the three minigames ("KEGIATAN AKADEMIS!") and the
## random events (their own name). Everything is authored in the scene; the
## script only moves it and sets the caption.

## The megaphone art on the panel. Swappable from the Inspector.
@export var icon_texture: Texture2D = preload("res://Assets/Images/SchoolDay/eventwarning_icon.png"):
	set(v):
		icon_texture = v
		if is_node_ready():
			icon.texture = v
## Seconds the panel takes to cover the screen from the right edge.
@export_range(0.05, 2.0, 0.01) var slide_in_duration: float = 0.35
## Seconds the panel rests on screen with the icon and caption showing.
@export_range(0.1, 5.0, 0.05) var hold_duration: float = 1.1
## Seconds the panel takes to leave through the left edge.
@export_range(0.05, 2.0, 0.01) var slide_out_duration: float = 0.35

@onready var panel: Panel = $Panel
@onready var icon: TextureRect = $Panel/Center/Content/Icon
@onready var caption: Label = $Panel/Center/Content/Caption


func _ready() -> void:
	icon.texture = icon_texture
	if Engine.is_editor_hint():
		return
	panel.position.x = panel_x(&"enter", size.x)


## Where the panel's left edge sits at each stage of the pass, for a screen
## `width` wide: off the right edge, resting, off the left edge.
static func panel_x(stage: StringName, width: float) -> float:
	match stage:
		&"enter":
			return width
		&"exit":
			return -width
		_:
			return 0.0


## Slide through the screen once showing `caption_text`, then free. Awaitable:
## SchoolDay waits on it before the minigame or event begins.
func play_warning(caption_text: String) -> void:
	caption.text = caption_text
	AudioDirector.play_sfx(&"event_announce")
	var width := size.x
	panel.position.x = panel_x(&"enter", width)
	icon.modulate.a = 0.0
	caption.modulate.a = 0.0

	var slide_in := create_tween()
	slide_in.tween_property(panel, "position:x", panel_x(&"rest", width), slide_in_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide_in.finished

	Juice.pop_in(icon)
	Juice.fade_in(caption)
	await get_tree().create_timer(hold_duration).timeout

	var slide_out := create_tween()
	slide_out.tween_property(panel, "position:x", panel_x(&"exit", width), slide_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await slide_out.finished
	queue_free()
```

- [ ] **Step 5: Restart the editor, then rebuild the scene**

Restart the editor (protocol 2), then run `filesystem_manage(op="scan")`, `scene_open(path="res://Scenes/SchoolSimulation/EventWarning.tscn")`, and one `batch_execute`:

```json
[
 {"command": "delete_node", "params": {"path": "/EventWarning/Background"}},
 {"command": "delete_node", "params": {"path": "/EventWarning/TopBar"}},
 {"command": "delete_node", "params": {"path": "/EventWarning/BottomBar"}},
 {"command": "delete_node", "params": {"path": "/EventWarning/Center"}},

 {"command": "create_node", "params": {"parent_path": "/EventWarning", "name": "Panel", "type": "Panel"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "layout_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "anchor_right", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "anchor_bottom", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "offset_left", "value": 0}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "offset_top", "value": 0}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "offset_right", "value": 0}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "offset_bottom", "value": 0}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "theme_type_variation", "value": "EventWarningPanel"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel", "property": "mouse_filter", "value": 2}},

 {"command": "create_node", "params": {"parent_path": "/EventWarning/Panel", "name": "Center", "type": "CenterContainer"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center", "property": "layout_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center", "property": "anchor_right", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center", "property": "anchor_bottom", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center", "property": "offset_right", "value": 0}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center", "property": "offset_bottom", "value": 0}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center", "property": "mouse_filter", "value": 2}},

 {"command": "create_node", "params": {"parent_path": "/EventWarning/Panel/Center", "name": "Content", "type": "VBoxContainer"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content", "property": "theme_override_constants/separation", "value": 32}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content", "property": "alignment", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content", "property": "mouse_filter", "value": 2}},

 {"command": "create_node", "params": {"parent_path": "/EventWarning/Panel/Center/Content", "name": "Icon", "type": "TextureRect"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Icon", "property": "texture", "value": "res://Assets/Images/SchoolDay/eventwarning_icon.png"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Icon", "property": "expand_mode", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Icon", "property": "stretch_mode", "value": 5}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Icon", "property": "custom_minimum_size", "value": {"x": 0, "y": 560}}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Icon", "property": "mouse_filter", "value": 2}},

 {"command": "create_node", "params": {"parent_path": "/EventWarning/Panel/Center/Content", "name": "Caption", "type": "Label"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Caption", "property": "theme_type_variation", "value": "EventWarningCaptionLabel"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Caption", "property": "text", "value": "KEGIATAN AKADEMIS!"}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Caption", "property": "horizontal_alignment", "value": 1}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Caption", "property": "autowrap_mode", "value": 3}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Caption", "property": "custom_minimum_size", "value": {"x": 920, "y": 0}}},
 {"command": "set_property", "params": {"path": "/EventWarning/Panel/Center/Content/Caption", "property": "mouse_filter", "value": 2}}
]
```

Then `scene_save()` and protocol 4. `git diff Scenes/SchoolSimulation/EventWarning.tscn` must show:
- `KiperIdle.jpg`, `HazardStripeShader` and `icon_event_warning.png` gone;
- the old script exports (`background_texture`, `caution_icon_texture`, `icon_font_size`) gone;
- the new `Panel/Center/Content` tree.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="event_warning")`, `test_run(suite="event_polish")`, `test_run(suite="school_day")`, `test_run(suite="viewport_editability")`, `test_run(suite="script_documentation")`, `test_run(suite="audio_coverage")`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add Assets/Images/SchoolDay/eventwarning_icon.png Assets/Images/SchoolDay/eventwarning_icon.png.import Scripts/SchoolSimulation/EventWarning.gd Scenes/SchoolSimulation/EventWarning.tscn tests/test_event_warning.gd tests/test_event_polish.gd tests/test_school_day.gd tests/test_viewport_editability.gd
git commit -m "feat(school-day): a mustard warning that slides right to left" -m "Replaces the hazard stripes, the goalkeeper photo and the runtime-built icon with an authored panel carrying eventwarning_icon.png and a caption." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: SchoolDay sends every interruption through the slide warning

**Files:**
- Modify (editor **stopped**): `Scenes/SchoolSimulation/SchoolDay.tscn:5`, `:21`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:43-44`, `:929-941`, the three titles at `:1000`, `:1012` and `:1024` and again at `:1518`, `:1530` and `:1542`, the five `_show_event_announcement` calls, and `:1458-1492`.
- Modify: `tests/test_event_warning.gd` (append)

**Interfaces:**
- Consumes (Task 8): `EventWarning.play_warning(caption_text)`.
- Produces: `SchoolDay._show_event_warning(caption: String) -> void`, with no accent parameter.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_event_warning.gd`:

```gdscript


# ── SchoolDay uses it for everything ─────────────────────────────────────────

const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"


func test_school_day_sends_every_interruption_through_the_slide() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_false(src.contains("_show_event_announcement"), "one warning for both paths")
	assert_false(src.contains("event_announcement_scene"), "the announcement export is gone")
	assert_contains(src, "func _show_event_warning(caption: String)")
	for caption in ["KEGIATAN AKADEMIS!", "KEGIATAN OLAHRAGA!", "KEGIATAN SENI BUDAYA!"]:
		assert_contains(src, '_show_event_warning("%s")' % caption)
	var start := src.find("func _show_event_warning")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_false(body.contains("popup_open"), "the warning plays its own single cue")


func test_event_titles_carry_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	for glyph in ["📚", "⚽", "🎨"]:
		assert_false(src.contains(glyph),
			"event titles reach the warning's caption; %s is emoji iconography" % glyph)


func test_school_day_scene_no_longer_wires_the_announcement() -> void:
	var scene := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/SchoolDay.tscn")
	assert_false(scene.contains("EventAnnouncement.tscn"))
```

- [ ] **Step 2: Run the tests to verify they fail**

No-op `script_patch` on the test file, then run: `test_run(suite="event_warning")`
Expected: FAIL on the three new tests.

- [ ] **Step 3: Stop the editor, then edit the scene by hand**

`SchoolDay.tscn` is heavy (it instances `BookClockWidget`, whose standalone `scene_open` hangs the editor). So this one edit is made with the editor **stopped** (protocol 3):

1. `taskkill` the editor.
2. In `Scenes/SchoolSimulation/SchoolDay.tscn`, delete these two lines:

```
[ext_resource type="PackedScene" uid="uid://rneo43oike8g" path="res://Scenes/SchoolSimulation/EventAnnouncement.tscn" id="3_announcement"]
```

```
event_announcement_scene = ExtResource("3_announcement")
```

3. If the first line of the file carries `load_steps=N`, lower N by 1.

Leave the editor stopped for Step 4.

- [ ] **Step 4: Edit SchoolDay.gd**

1. Delete lines 43-44:

```gdscript
## Popup shown for a non-interactive random event (applies automatically).
@export var event_announcement_scene: PackedScene
```

2. Replace the minigame branch (lines 929-941, from `var tokens := Juice.tokens()` through the `SeniBudaya` `_play_minigame` call) with:

```gdscript
		if category_selected == "Akademis":
			var scene = akademis_scenes[randi() % akademis_scenes.size()]
			await _show_event_warning("KEGIATAN AKADEMIS!")
			await _play_minigame(scene, "Akademis")
		elif category_selected == "Olahraga":
			var scene = olahraga_scenes[randi() % olahraga_scenes.size()]
			await _show_event_warning("KEGIATAN OLAHRAGA!")
			await _play_minigame(scene, "Olahraga")
		else:
			var scene = seni_scenes[randi() % seni_scenes.size()]
			await _show_event_warning("KEGIATAN SENI BUDAYA!")
			await _play_minigame(scene, "SeniBudaya")
```

3. Replace every `"Les Tambahan Akademis 📚"` with `"Les Tambahan Akademis"`, every `"Latihan Olahraga Ekstra ⚽"` with `"Latihan Olahraga Ekstra"`, and every `"Workshop Sanggar Seni 🎨"` with `"Workshop Sanggar Seni"`. There are two occurrences each, in `_trigger_random_event` and `force_event`.
4. Replace every `await _show_event_announcement(` with `await _show_event_warning(`. There are five occurrences.
5. Replace the whole of `_show_event_warning` and `_show_event_announcement` (lines 1458-1492) with:

```gdscript
## Slide the full-screen event warning through once, captioned with what is
## coming -- a minigame's subject or a random event's name -- and wait for it
## to leave (2026-09-12 event-cards spec, 2.3). The warning plays its own cue.
func _show_event_warning(caption: String) -> void:
	var warning_scene = event_warning_scene
	if warning_scene == null:
		warning_scene = load("res://Scenes/SchoolSimulation/EventWarning.tscn")

	if warning_scene == null:
		return

	var warning_instance = warning_scene.instantiate()
	add_child(warning_instance)

	if warning_instance.has_method("play_warning"):
		await warning_instance.play_warning(caption)
	else:
		await get_tree().create_timer(1.5).timeout
		warning_instance.queue_free()
```

6. Update the doc line on `event_warning_scene` (line 39) to:
   `## The sliding warning shown before every minigame and random event.`

- [ ] **Step 5: Relaunch and run the tests to verify they pass**

Relaunch the editor, run `filesystem_manage(op="scan")`, then:
`test_run(suite="event_warning")`, `test_run(suite="school_day")`, `test_run(suite="event_polish")`, `test_run(suite="viewport_editability")`, `test_run(suite="debug_manager")`
Expected: all PASS. `debug_manager` covers the `force_event` path.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd Scenes/SchoolSimulation/SchoolDay.tscn tests/test_event_warning.gd
git commit -m "feat(school-day): one sliding warning for minigames and random events" -m "The subject tint and the extra popup_open cue go, EventAnnouncement is no longer wired, and the three interactive event titles drop their emoji." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Delete the announcement, update docs, full suite, live check

**Files:**
- Delete:
  - `Scenes/SchoolSimulation/EventAnnouncement.tscn`, `Scripts/SchoolSimulation/EventAnnouncement.gd` and `.uid`
  - `Scenes/SchoolSimulation/AnnouncementBurst.tscn`, `Scripts/SchoolSimulation/AnnouncementBurst.gd` and `.uid`
  - `particle_burst.png` (+ `.import`)
  - `icon_event_warning.png`, `icon_event_announce.png` and `bg_event_announce.png` (+ `.import`)
  - `Scripts/SchoolSimulation/HazardStripeShader.gdshader` and `.uid`
  
  Each one only after its grep (Step 1) comes back clean.
- Modify: `tests/test_school_day.gd:52`, `:67`; `tests/test_event_polish.gd:4-7`, `:45-76`; `tests/test_viewport_editability.gd:106-109`, `:114-115`
- Modify: `Scripts/Audio/AudioDirector.gd:93-96`, `Scripts/Design/ThemeFactory.gd:640-642`, `Scripts/SchoolSimulation/StudentSummaryCard.gd:5-10`
- Modify: `CLAUDE.md` (the placeholder list) and `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Find what is safe to delete**

```bash
grep -rn --include=*.gd --include=*.tscn --include=*.tres -e "EventAnnouncement" -e "AnnouncementBurst" -e "particle_burst" -e "icon_event_warning" -e "icon_event_announce" -e "bg_event_announce" -e "HazardStripeShader" Scenes Scripts tests
```

Expected, and the only lines that may appear:
- the two announcement scenes and scripts themselves;
- `tests/test_school_day.gd` (lists), `tests/test_event_polish.gd` (announcement tests) and `tests/test_viewport_editability.gd` (the `ALLOWED` entry);
- comments in `AudioDirector.gd` and `ThemeFactory.gd`.

Anything else means that asset is still in use: **keep it** and note it in the commit message. Record the path grep reports for `particle_burst.png`.

- [ ] **Step 2: Update the tests**

- `tests/test_school_day.gd`: delete the `"EventAnnouncement": ...` line from `_SCENES` (line 52) and the `EventAnnouncement.gd` line from `_SCRIPTS` (line 67).
- `tests/test_event_polish.gd`: delete `test_announcement_no_longer_uses_emoji`, `test_announce_scene_wires_burst`, `test_announce_script_plays_sfx` and `test_announce_script_has_no_emoji_fallback` (lines 45-50 and 59-76). Replace header lines 4-7 with:

```gdscript
## 2026-09-08 mobile-readability and asset-polish pass over the mid-
## simulation event popups: EventStudentSelectDialog (the calmed background
## and bigger body text) and the event warning (real art replacing emoji, per
## CLAUDE.md's no-emoji rule). EventAnnouncement was folded into the sliding
## EventWarning on 2026-09-12.
```

- `tests/test_viewport_editability.gd`: delete the comment block and entry for `EventAnnouncement.gd` (lines 106-109). Then replace the PauseMenu comment (lines 114-115) with:

```gdscript
	# _apply_visual_exports()'s overlay TextureRect: only created when an
	# @export texture is supplied -- a conditional texture-or-procedural swap.
```

- [ ] **Step 3: Stop the editor and delete**

Stop the editor (protocol 2, kill only). Then `git rm` each file Step 1 cleared, including every `.uid` and `.import` beside it. For example:

```bash
git rm Scenes/SchoolSimulation/EventAnnouncement.tscn Scripts/SchoolSimulation/EventAnnouncement.gd Scripts/SchoolSimulation/EventAnnouncement.gd.uid Scenes/SchoolSimulation/AnnouncementBurst.tscn Scripts/SchoolSimulation/AnnouncementBurst.gd Scripts/SchoolSimulation/AnnouncementBurst.gd.uid Scripts/SchoolSimulation/HazardStripeShader.gdshader Scripts/SchoolSimulation/HazardStripeShader.gdshader.uid
git rm Assets/Images/UI/Placeholders/icon_event_warning.png Assets/Images/UI/Placeholders/icon_event_warning.png.import Assets/Images/UI/Placeholders/icon_event_announce.png Assets/Images/UI/Placeholders/icon_event_announce.png.import Assets/Images/UI/Placeholders/bg_event_announce.png Assets/Images/UI/Placeholders/bg_event_announce.png.import
git rm Assets/Images/Particles/particle_burst.png Assets/Images/Particles/particle_burst.png.import
```

- [ ] **Step 4: Fix the stale comments**

- `Scripts/Audio/AudioDirector.gd` lines 93-96 become:

```gdscript
## `play_sfx(&"event_announce")`: the sliding event warning starts its pass
## (EventWarning, before every minigame and random event). Placeholder:
## aliases reward.ogg via a dedicated copy (event_announce.ogg) until a real
## chime lands.
```

- `Scripts/Design/ThemeFactory.gd` lines 640-642: change `(EventAnnouncement, EventWarning, EventStudentSelectDialog)` to `(the event warning and EventStudentSelectDialog)`. Keep the rest of the comment.
- `Scripts/SchoolSimulation/StudentSummaryCard.gd` lines 5-10 become:

```gdscript
## The Card+Margin chrome shared by SchoolDay's day-summary card and
## DailyDecayOverview's decay card. Each screen's actual content (name/badge
## layout, stat rows, tinting) stays hand-built as a child of `margin` -- the
## two screens' content differs in node type and shape, not just numbers, so
## only the genuinely shared outer frame lives here. (EventStudentSelectDialog
## used it too until 2026-09-07; its cards are EventStudentCard now.)
```

- `CLAUDE.md`, "Generated placeholder art": change `the event-popup set (`icon_event_*`, `bg_event_*`, `particle_burst.png`)` to `the event-popup set (`icon_event.svg`, `bg_event_dialog.png`)`. Drop any name Step 1 kept from the deletions back into that list.
- `docs/superpowers/CHANGELOG.md`: add a newest-first entry dated 2026-09-12 in the file's existing format. It summarises:
  - the student cards on the real DaySummary card (event picker and item screen);
  - `StudentCardButton`;
  - the sliding mustard warning replacing both the minigame banner and `EventAnnouncement`;
  - the files deleted;
  - the new art `Assets/Images/SchoolDay/eventwarning_icon.png` (the Drive icon, cropped).

- [ ] **Step 5: Relaunch and run the full suite**

1. Relaunch the editor, then `filesystem_manage(op="scan")` (the `AnnouncementBurst` `class_name` is gone).
2. `scene_open(path="res://Scenes/MainMenu/main_menu.tscn")`.
3. Full `test_run()`. Expected: every suite passes (98 suites before this plan, plus `student_data_bridge`, `card_standing_mode`, `student_card_button` and `event_warning`).
4. The bridge usually drops after a full run; restart the editor.
5. `git status`. `git checkout -- Assets/Audio/default_bus_layout.tres` if it changed. `kejartes_theme.tres` must match the Task 7 commit (the full run rebakes it). If it differs, inspect before keeping anything.

If `project_hygiene` reports unknown Koperasi UIDs (`BasketTray.gd`, `PriceTag.gd`, `TraySlot.gd`), that is this editor's stale filesystem cache. `filesystem_manage(op="reimport", params={"paths": [those three .gd paths]})` and re-run the suite.

- [ ] **Step 6: Live check (full-size screenshots)**

`project_run(mode="main", autosave=false)`. Then, in one `editor_manage(op="game_eval")`:

```gdscript
get_node("/root/DebugManager")._seed_playtest_state()
var w = load("res://Scenes/SchoolSimulation/EventWarning.tscn").instantiate()
get_tree().root.add_child(w)
w.play_warning("KEGIATAN SENI BUDAYA!")
await get_tree().create_timer(0.7).timeout
Engine.time_scale = 0.0
return "warning frozen mid-hold"
```

`editor_screenshot(source="game", max_resolution=0)`. Check:
- the mustard fills the screen;
- the megaphone is centred;
- the caption wraps inside the margins and its navy rim reads.

Then:

```gdscript
Engine.time_scale = 1.0
var d = load("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn").instantiate()
get_tree().root.add_child(d)
var students: Array[StudentData] = GameState.convert_to_student_data_array()
d.setup_event("Les Tambahan Akademis", "Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.", "Akademis +15", "Energy -15", "Akademis", students, 15.0, -15.0, 0.0)
await get_tree().create_timer(1.0).timeout
d.card_widgets.values()[0].button_pressed = true
await get_tree().create_timer(0.8).timeout
return d.card_widgets.size()
```

Screenshot. Check:
- each card is the DaySummary card, with icons on the energy and mood bars and the numbers reading current/target;
- the first card shows `+15/60`-style numbers, the energy bar lower, and the check badge on the card.

Then:

```gdscript
for c in get_tree().root.get_children():
	if c.scene_file_path.ends_with("EventStudentSelectDialog.tscn"):
		c.queue_free()
var item: ItemData = null
for it in ItemDatabase.get_all_items():
	if it.akademis_boost != 0 or it.mood_boost != 0:
		item = it
		break
var s = load("res://Scenes/Inventory/ApplyItemScreen.tscn").instantiate()
get_tree().root.add_child(s)
s.setup(item)
await get_tree().create_timer(1.0).timeout
s._rows[0].button_pressed = true
await get_tree().create_timer(0.8).timeout
return item.item_name
```

Screenshot. Check:
- the rows are the DaySummary card, scaled to the list's width;
- only the item's stats show;
- the picked row shows the gain.

Then `project_manage(op="stop")`. Judge each screenshot **at full size**.

- [ ] **Step 7: Commit**

```bash
git add -A tests Scripts CLAUDE.md docs/superpowers/CHANGELOG.md
git status --short   # confirm only this task's files are staged
git commit -m "chore(school-day): retire EventAnnouncement and its assets" -m "The sliding EventWarning covers both paths now. Deletes the announcement scene and script, its particle burst, the hazard-stripe shader and the three unused event placeholders; fixes the comments that named them." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

After this, the branch is ready for the `ship-pr` skill.
