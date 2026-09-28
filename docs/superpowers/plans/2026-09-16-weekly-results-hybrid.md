# Weekly Results Hybrid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans`
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Drop `ResultCheckup`'s SISWA / RIWAYAT tabs and give it back the
rebuild's **Logs** + **Selanjutnya** row, with the week's history moving into
`WeekLogsPopup`. The banner, pills, header, cards and confetti stay.

**Architecture:** One indivisible change first — scene, script and suite move
together, because a screen with a button row and no wiring (or wiring and no
buttons) is not reviewable. Then the two things the tabs were keeping alive
are retired, then the docs. Scene work goes through the editor, never a text
edit, and always before script work.

**Tech Stack:** Godot 4.6.2, GDScript, `McpTestSuite` suites over the Godot
AI MCP bridge.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-09-16-weekly-results-hybrid-design.md`.
- **Worktree:** `.claude/worktrees/revert-weekly-results`, branch
  `worktree-revert-weekly-results`, continuing the revert already committed.
- **Editor session:** this worktree has **its own** Godot editor. Every
  `test_run`, `scene_*` and `node_*` call passes its `session_id`, re-read
  from `session_manage(op="list")` after each restart — it changes every time.
  Never `session_activate`; never kill every Godot process, only this
  worktree's `editor_pid`.
- **Never hand-edit `ResultCheckup.tscn`.** The attached editor's in-memory
  copy wins and the next `scene_save` silently overwrites a text edit
  (CLAUDE.md → 4). Go `scene_open` → `node_manage` / `node_create` /
  `node_set_property` → `scene_save`.
- **Scene work first, script work second** (CLAUDE.md → 4b). `scene_save`
  flushes every open script tab over whatever was patched, so once Task 1's
  script edits begin there must be no further `scene_save`. Restart the
  editor between the two halves.
- **Refresh the editor before every test step** — a restart, not a scan; a
  full `filesystem_manage(op="scan")` dropped this editor's session earlier
  in the session:
  1. `session_manage(op="list")` → note `editor_pid`.
  2. `Stop-Process -Id <that pid> -Force` — that pid only.
  3. `Start-Process "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" -ArgumentList @("--path","<worktree>","-e") -WindowStyle Minimized`
  4. `session_manage(op="list")` until the worktree session reappears.
- **`node_create` appends last**, numbers are unquoted (`160`, not `"160.0"`),
  `anchors_preset` is inert, and a node's type can only change by
  delete-and-recreate.
- **Baseline: 1632/1637.** Five failures — `inventory` (2) and
  `light_ground_text` (3) — are pre-existing on `origin/Textures` from PR
  #48 and are the floor for every "Expected" below.
- **`Balance.gd` is collaborator-owned** — untouched here.
- **No `theme_override_*`** on anything new; use a `ThemeFactory` variation.
  Layout-only constants (`separation`) are the accepted exception.
- **No emoji as UI iconography** — `result_checkup` scans for them.
- **Conventional Commits with a scope**, each message ending:
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- Write commit messages to a file, `git commit -F <file>`; run git as plain,
  separate commands (no `cd &&`, heredocs or process substitution).

## File Structure

| File | Change |
|---|---|
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | `TabBar`, `HistoryPane`, `PaneStack`, `BtnClose` out; `StudentsPane` moves under `ScrollContainer`; `Buttons/LogsButton` + `Buttons/NextButton` in |
| `Scripts/SchoolSimulation/ResultCheckup.gd` | tab/pane machinery out, Logs wiring in |
| `tests/test_result_checkup.gd` | tab/pane coverage deleted, Logs coverage added, paths updated |
| `tests/test_school_day.gd` | touch-target map → the two buttons |
| `tests/test_viewport_editability.gd` | `ResultCheckup.gd` baseline entry |
| `Scripts/Design/ThemeFactory.gd` + `Assets/Theme/kejartes_theme.tres` | retire `WeekTabButton`, rebake |
| `Scripts/Audio/AudioDirector.gd`, `Assets/Audio/SFX/pane_swipe.ogg*` | retire the cue |
| `tests/test_audio_director.gd`, `tests/test_audio_coverage.gd` | drop `pane_swipe` |
| `Scripts/SchoolSimulation/WeekHistoryRow.gd` | docs point at `WeekLogsPopup` again |
| `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md` | two orphans resolved; new entry |

---

### Task 1: Tabs out, Logs and Selanjutnya in

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn` (editor only)
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Test: `tests/test_result_checkup.gd`, `tests/test_school_day.gd`,
  `tests/test_viewport_editability.gd`

**Interfaces:**
- Consumes: `WeekLogsPopup` — `set_history(entries: Array) -> void`,
  `open(animate_rows: bool = true) -> void`, `row_count() -> int`, and the
  `closed` signal. `WeekRecapBanner.set_recap(recap: Dictionary)` and
  `play_entrance()`, unchanged.
- Produces: `ResultCheckup.logs_button` / `next_button` (`Button`),
  `open_logs() -> void`, `@export var logs_popup_scene: PackedScene`,
  `logs_button_text` / `next_button_text`, and `var _history: Array`.
  `initialize_checkup(student_manager, week_earnings := 0)` and the
  `checkup_closed` signal keep their exact signatures.

#### Scene half — do all of this before touching any script

- [ ] **Step 1: Open the scene**

`scene_open(path="res://Scenes/SchoolSimulation/ResultCheckup.tscn",
session_id=<worktree session>)`, then
`scene_get_hierarchy` to confirm the node paths below still read as this plan
expects.

- [ ] **Step 2: Delete the tabs, the history pane and the close button**

`node_manage(op="delete_node", ...)` on each, in this order:

```
Margin/VBox/TabBar
Margin/VBox/ScrollContainer/PaneStack/HistoryPane
Margin/VBox/BtnClose
```

`HistoryPane`'s `EmptyLabel` goes with its parent; the sheet has its own
empty state (`WeekLogsPopup.empty_text`).

- [ ] **Step 3: Move the card list up and delete `PaneStack`**

`StudentsPane` is a plain `VBoxContainer` authored empty — the cards are
instanced into it at runtime — so recreate it rather than reparent it.
Reparenting is what re-owned an instanced scene's internals and duplicated
StudentList's avatar nodes during the tall-phone pass; recreating an empty
container has none of that risk.

Delete `Margin/VBox/ScrollContainer/PaneStack`, then
`node_create` a `VBoxContainer` named `StudentsPane` under
`Margin/VBox/ScrollContainer`, and `node_set_property` it to exactly what it
had:

```
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 28
alignment = 1
```

(`separation` is the layout-only constant override the style guide allows.)

- [ ] **Step 4: Add the button row**

`node_create` an `HBoxContainer` named `Buttons` under `Margin/VBox`. It
appends last, which is where `BtnClose` was, so no `move_node` is needed —
confirm that with `scene_get_hierarchy` rather than assuming.

```
layout_mode = 2
theme_override_constants/separation = 120
alignment = 1
```

Then `node_create` two `Button`s under it, `LogsButton` first, `NextButton`
second, each set to:

```
layout_mode = 2
custom_minimum_size = Vector2(0, 160)
size_flags_horizontal = 3
theme_type_variation = &"ResultButton"
```

with `text = "Logs"` and `text = "Selanjutnya"` respectively. Equal
`size_flags_horizontal = 3` is deliberate: the display face sets SELANJUTNYA
in capitals and needs ~435 px, which is why the row is split rather than
given the mockup's fixed 368 (2026-09-14 spec).

- [ ] **Step 5: Assign the sheet to the new export**

The root's `logs_popup_scene` export does not exist until Task 1's script
half runs, so this is set **after** the script edit, in Step 12. Do not try
it now — setting a property the script has no `@export` for is dropped on
save.

- [ ] **Step 6: Save the scene, then restart the editor**

`scene_save(session_id=<worktree session>)`.

Then restart per Global Constraints. This is the hard boundary between the
scene half and the script half: after this point there must be **no further
`scene_save`** in this task, or the editor's open script tabs are written
back over the patched script.

- [ ] **Step 7: Check the save wrote what you meant**

```bash
git diff Scenes/SchoolSimulation/ResultCheckup.tscn
```

Expected: `TabBar`, `TabSiswa`, `TabRiwayat`, `PaneStack`, `HistoryPane`,
`EmptyLabel` and `BtnClose` gone; `StudentsPane` reparented under
`ScrollContainer` with its four properties; `Buttons`, `LogsButton`,
`NextButton` added. Nothing else changed — in particular `Banner`,
`ScrollFade` and `Celebration` must be untouched.

#### Script half

- [ ] **Step 8: Strip the tab and pane machinery**

From `Scripts/SchoolSimulation/ResultCheckup.gd`, delete:

- `enum Pane { SISWA = 0, RIWAYAT = 1 }` and its doc comment;
- `const PANE_SLIDE_DISTANCE := 40.0` and its doc comment;
- the `tab_students_text` and `tab_history_text` exports, and the whole
  `# ── Visual - Tabs ──` group header;
- the `button_close_texture` and `close_button_text` exports (the
  `# ── Visual - Buttons ──` group stays, with the two new exports from
  Step 9);
- the `history_row_scene` export — the sheet carries its own;
- the `tab_siswa`, `tab_riwayat`, `history_pane`, `history_empty_label` and
  `btn_close` `@onready` lines;
- `var _active_pane`, `var _pane_scroll`, `var _history_animated`,
  `var _history_rows`, with their doc comments;
- `func show_pane`, `func _transition_panes`, `func _sync_tab_buttons`,
  `func _update_tab_counts`, `func _play_history_entrance`;
- in `_ready`, the two `tab_*.pressed.connect(show_pane.bind(...))` lines and
  the `_sync_tab_buttons()` call;
- in `_apply_visual_exports`, every branch that writes to `tab_siswa`,
  `tab_riwayat` or `btn_close` (including the `button_close_texture` swap).

- [ ] **Step 9: Add the Logs wiring**

Exports, in the `# ── Visual - Buttons ──` group:

```gdscript
## The Logs button's label.
@export var logs_button_text: String = "Logs"
## The Selanjutnya button's label.
@export var next_button_text: String = "Selanjutnya"
```

In the `# ── Wiring ──` group, replacing `history_row_scene`:

```gdscript
## The Logs sheet, WeekLogsPopup.tscn, instanced on each Logs tap.
@export var logs_popup_scene: PackedScene
```

The two `@onready`s, replacing the five deleted ones:

```gdscript
@onready var logs_button: Button = $Margin/VBox/Buttons/LogsButton
@onready var next_button: Button = $Margin/VBox/Buttons/NextButton
```

State, replacing the four deleted vars:

```gdscript
## This week's history, handed to each Logs sheet.
var _history: Array = []
## Latched on the first Logs open: the rows' stamp-and-shake entrance plays
## once, so reopening the sheet never re-fires the stamp cue.
var _logs_seen: bool = false
## The open Logs sheet, or null.
var _logs_popup: Control = null
```

And `open_logs`, lifted unchanged from the rebuild:

```gdscript
## Open the week's history as a sheet. Refuses to stack a second one, so a
## double tap on Logs is harmless; the rows' entrance plays on the first
## open only.
func open_logs() -> void:
	if is_instance_valid(_logs_popup):
		return
	var popup := logs_popup_scene.instantiate() as WeekLogsPopup
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.set_history(_history)
	popup.closed.connect(func(): _logs_popup = null)
	_logs_popup = popup
	popup.open(not _logs_seen)
	_logs_seen = true
```

- [ ] **Step 10: Rewire `_ready`, `initialize_checkup` and the entrance**

In `_ready`, the signal wiring stays ungated so the runner can exercise it:

```gdscript
	btn_close.pressed.connect(_on_close_pressed)
```

becomes

```gdscript
	logs_button.pressed.connect(open_logs)
	next_button.pressed.connect(_on_close_pressed)
	logs_button.text = logs_button_text
	next_button.text = next_button_text
```

and the editor-gated tail:

```gdscript
	btn_close.modulate.a = 0.0
	btn_close.disabled = true
```

becomes

```gdscript
	for b in [logs_button, next_button]:
		b.modulate.a = 0.0
		b.disabled = true
```

In `initialize_checkup`, the history block:

```gdscript
	for child in history_pane.get_children():
		if child != history_empty_label:
			child.queue_free()
	_history_rows.clear()

	if student_manager == null:
		_update_tab_counts(0, 0)
		return
```

becomes

```gdscript
	_history = []

	if student_manager == null:
		return
```

and the block that built rows into the pane:

```gdscript
	var history: Array = student_manager.minigame_history
	history_empty_label.visible = history.is_empty()
	for entry in history:
		var row := history_row_scene.instantiate() as WeekHistoryRow
		history_pane.add_child(row)
		row.set_entry(entry)
		_set_mouse_filter_pass(row)
		_history_rows.append(row)

	_update_tab_counts(cards.size(), history.size())
	_play_entrance_animations(cards)
```

becomes

```gdscript
	_history = student_manager.minigame_history.duplicate()
	_play_entrance_animations(cards)
```

In `_play_entrance_animations`, the finale:

```gdscript
	var button_tween = create_tween()
	button_tween.tween_property(btn_close, "modulate:a", 1.0, t.dur_fast)
	btn_close.disabled = false
	banner.start_idle_bounce()
```

becomes

```gdscript
	for b in [logs_button, next_button]:
		var button_tween := create_tween()
		button_tween.tween_property(b, "modulate:a", 1.0, t.dur_fast)
		# Enabled only once shown, like the rebuild's finale: a button
		# enabled while still invisible can take a tap meant for something
		# else.
		button_tween.tween_callback(func(): b.disabled = false)
	banner.start_idle_bounce()
```

In `_on_close_pressed`, whatever it disables must become both buttons, so a
second tap during the fade-out cannot re-fire or open Logs. Read the function
and update it to match.

Finally, update the file's `##` header: it describes "a pinned
WeekRecapBanner over two tabbed panes". It is now a pinned banner over one
card list, with Logs and Selanjutnya beneath. `script_documentation` will not
catch a merely stale header, so this is on you.

- [ ] **Step 11: Delete the tab and pane tests**

From `tests/test_result_checkup.gd`, delete outright — these cover a feature
that no longer exists, so they are not adapted:

```
test_default_tab_is_siswa
test_switching_tabs_swaps_pane_visibility_without_freeing
test_each_pane_keeps_its_own_scroll_offset
test_history_pane_animation_latch_fires_only_once
test_pane_transition_is_gated_on_editor_hint
test_pane_transition_direction_is_derived_not_hardcoded
```

Keep every `test_history_row_*` test: `WeekHistoryRow` still exists and the
sheet still renders it.

- [ ] **Step 12: Rewrite the structural tests**

`test_screen_authors_the_banner_tabs_and_both_panes` → rename to
`test_screen_authors_the_banner_the_list_and_the_buttons` and change its path
list to:

```gdscript
	for path in ["Margin/VBox/Banner",
			"Margin/VBox/ScrollContainer/StudentsPane",
			"Margin/VBox/Buttons/LogsButton",
			"Margin/VBox/Buttons/NextButton"]:
```

`test_banner_and_tabs_sit_outside_the_scroll` → rename to
`test_the_banner_and_buttons_sit_outside_the_scroll`, and swap the `TabBar`
assertion for:

```gdscript
	assert_false(scroll.is_ancestor_of(screen.get_node("Margin/VBox/Buttons")),
		"and so must the button row")
```

`test_students_pane_uses_the_spec_separation` → path becomes
`"Margin/VBox/ScrollContainer/StudentsPane"`; the `28` assertion is unchanged.

`test_the_checkup_keeps_its_history_and_its_close_button` → rename to
`test_the_checkup_keeps_the_weeks_history_for_the_sheet` and replace its body
after `inst.initialize_checkup(manager)` with:

```gdscript
	assert_eq(inst._history.size(), 1,
		"the week's minigame log is kept for the Logs sheet")
	assert_not_null(inst.get_node_or_null("Margin/VBox/Buttons/NextButton"),
		"Selanjutnya must survive the tab removal")
```

`test_scene_carries_no_emoji_and_no_dead_section_headers` keeps its emoji
scan; its two `StudentsHeader` / `HistoryHeader` assertions still hold and
stay as they are.

- [ ] **Step 13: Add the Logs coverage**

Append to `tests/test_result_checkup.gd`. `_LOGS_SCENE` must be declared as a
const beside `_CHECKUP_SCENE` if the suite does not already have it:

```gdscript
const _LOGS_SCENE := "res://Scenes/SchoolSimulation/WeekLogsPopup.tscn"


## The Logs sheet is a scene of its own, instanced on each Logs tap.
func test_the_checkup_scene_supplies_the_logs_sheet() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var packed: PackedScene = inst.logs_popup_scene
	assert_not_null(packed, "ResultCheckup.tscn must assign logs_popup_scene")
	assert_eq(packed.resource_path, _LOGS_SCENE, "Logs opens WeekLogsPopup")
	inst.free()


func test_the_buttons_read_as_the_mockup() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	assert_eq(inst.logs_button.text, "Logs", "the left button is Logs")
	assert_eq(inst.next_button.text, "Selanjutnya", "the right one moves on")


func test_the_buttons_wear_the_result_style() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for n in ["LogsButton", "NextButton"]:
		assert_true(src.contains(n), "%s is authored in the scene" % n)
	assert_true(src.contains('theme_type_variation = &"ResultButton"'),
		"both buttons use the ResultButton variation, not an override")
	assert_false(src.contains("theme_override_styles"),
		"no stylebox override sneaks in with them")


func test_logs_opens_one_sheet_with_the_weeks_history() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Rabu", "category": "Event", "game_name": "Hujan Deras", "won": true},
	])
	inst.initialize_checkup(manager)
	inst.logs_button.pressed.emit()
	inst.logs_button.pressed.emit()
	var sheets: Array = []
	for child in inst.get_children():
		if child is WeekLogsPopup:
			sheets.append(child)
	assert_eq(sheets.size(), 1,
		"Logs opens the sheet, and a second tap never stacks another")
	if sheets.size() == 1:
		assert_eq(sheets[0].row_count(), 2,
			"every minigame and event of the week reaches the sheet")


func test_the_rows_entrance_plays_on_the_first_open_only() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	inst.initialize_checkup(null)
	assert_false(inst._logs_seen, "nothing opened yet")
	inst.open_logs()
	assert_true(inst._logs_seen, "the first open latches")


func test_the_script_no_longer_carries_the_tabs() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for dead in ["enum Pane", "PANE_SLIDE_DISTANCE", "show_pane",
			"_sync_tab_buttons", "_update_tab_counts", "tab_siswa",
			"tab_riwayat", "history_pane", "pane_swipe"]:
		assert_false(src.contains(dead),
			"%s belongs to the retired tabs" % dead)
```

Then, back in the editor, set the scene's new export — this is Step 5's
deferred work, and it is a **property set on the scene root**, which is the
one place an override reliably serialises:

`scene_open`, `node_set_property(node_path=".",
property="logs_popup_scene", value="res://Scenes/SchoolSimulation/WeekLogsPopup.tscn")`,
`scene_save`. Then restart the editor once more before running tests.

- [ ] **Step 14: Update the two neighbouring suites**

`tests/test_school_day.gd`, in the touch-target map:

```gdscript
		"res://Scenes/SchoolSimulation/ResultCheckup.tscn": [
			"Margin/VBox/BtnClose"],
```

becomes

```gdscript
		"res://Scenes/SchoolSimulation/ResultCheckup.tscn": [
			"Margin/VBox/Buttons/LogsButton", "Margin/VBox/Buttons/NextButton"],
```

`tests/test_viewport_editability.gd`: run the suite first and let it tell you
the number. The history rows this screen used to build have moved into
`WeekLogsPopup`, which carries its own entry, so `ResultCheckup.gd`'s should
fall from `1`. Set it to whatever the suite reports it now needs — and only
downwards. If it reports more than 1, stop: something in Step 10 built UI at
runtime that should have been authored.

- [ ] **Step 15: Run the suites**

Refresh the editor per Global Constraints.

Run: `test_run(suite="result_checkup", session_id=<worktree session>)`
Expected: PASS, with the six deleted tests gone and the five new ones present.

Run: `test_run(suite="week_logs_popup", session_id=<worktree session>)`
Expected: PASS — the sheet itself is unchanged; it simply has a caller again.

Run: `test_run(suite="school_day", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="viewport_editability", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="debug_manager", session_id=<worktree session>)`
Expected: PASS — `initialize_checkup(manager, coins)` is unchanged.

Run: `test_run(suite="paper_confetti", session_id=<worktree session>)`
Expected: PASS — the confetti is not touched by any step here.

Run: `test_run(suite="week_report_rehearsal", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="script_documentation", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="lobby_style_buttons", session_id=<worktree session>)`
Expected: PASS — and `ResultButton` now has a real call site behind its
assertion.

- [ ] **Step 16: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd tests/test_school_day.gd tests/test_viewport_editability.gd
```

Message: `feat(weekly-results): trade the SISWA/RIWAYAT tabs for Logs and Selanjutnya`.
Say in the body that the history moved into `WeekLogsPopup` rather than being
dropped, and that the tab coverage was deleted with the feature rather than
adapted.

---

### Task 2: Retire `WeekTabButton` and `pane_swipe`

Both were restored two commits ago for the tabs. The tabs are gone.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`
- Regenerate: `Assets/Theme/kejartes_theme.tres`
- Modify: `Scripts/Audio/AudioDirector.gd`
- Delete: `Assets/Audio/SFX/pane_swipe.ogg`, `pane_swipe.ogg.import`
- Test: `tests/test_audio_director.gd`, `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: Task 1's screen, which references neither.
- Produces: nothing. `RecapBannerPanel`, `RecapPillPanel`,
  `RecapPillValueLabel`, `pill_tap`, `pill_popup_open` and
  `pill_popup_close` all **stay** — the banner and pills still use them.

- [ ] **Step 1: Drop `WeekTabButton` from `_build_week_recap`**

In `Scripts/Design/ThemeFactory.gd`, delete from the comment
`# The tab. A real pressed state is what makes the active tab legible`
down to and including
`theme.set_font_size("font_size", "WeekTabButton", tokens.font_title)`,
along with the `tab_normal` and `tab_pressed` locals. Keep the function, its
`_build_week_recap` call in `build()`, and the three pill/banner types above
it.

`WeekTabButton` is **not** in `test_theme_factory`'s `DISPLAY_ROSTER`
(only `RecapPillValueLabel` is, and it stays), so that roster needs no edit.

- [ ] **Step 2: Drop the `pane_swipe` cue**

In `Scripts/Audio/AudioDirector.gd`, delete the `sfx_pane_swipe` export with
its three doc lines, and its `&"pane_swipe": return sfx_pane_swipe` arm.
Leave `sfx_pill_tap`, `sfx_pill_popup_open` and `sfx_pill_popup_close` alone.

```bash
git rm Assets/Audio/SFX/pane_swipe.ogg Assets/Audio/SFX/pane_swipe.ogg.import
```

- [ ] **Step 3: Narrow the two audio suites**

`tests/test_audio_director.gd` — `test_pill_and_pane_sfx_are_registered`
loses `pane_swipe` and is renamed for what it now covers:

```gdscript
func test_pill_sfx_are_registered() -> void:
	for id in [&"pill_tap", &"pill_popup_open", &"pill_popup_close"]:
		assert_true(AudioDirector.has_sfx(id),
			"AudioDirector has no stream registered for %s" % id)
```

`tests/test_audio_coverage.gd` — the known-id list line becomes:

```gdscript
		"pill_tap", "pill_popup_open", "pill_popup_close",
```

- [ ] **Step 4: Refresh, rebake, and verify the bake by content**

Refresh the editor per Global Constraints, then rebake
(`Scripts/Design/BakeTheme.gd` via File > Run, or the `theme_rebake` suite,
which saves in process).

Run: `test_run(suite="theme_rebake", session_id=<worktree session>)`
Expected: PASS, and `Assets/Theme/kejartes_theme.tres` modified.

```bash
grep -c "WeekTabButton" Assets/Theme/kejartes_theme.tres
```

Expected: `0`. A non-zero count means the editor served a cached theme —
restart it and rebake before going on. Then confirm the pills survived:

```bash
grep -c "RecapBannerPanel\|RecapPillPanel\|RecapPillValueLabel" Assets/Theme/kejartes_theme.tres
```

Expected: non-zero.

- [ ] **Step 5: Run the affected suites**

Run: `test_run(suite="audio_director", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="audio_coverage", session_id=<worktree session>)`
Expected: PASS — it scans `res://Scripts` for `play_sfx` ids, so a
`pane_swipe` call left anywhere would fail here. That is the real check that
Task 1 Step 8 removed it.

Run: `test_run(suite="theme_factory", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="button_geometry", session_id=<worktree session>)`
Expected: PASS — one fewer Button variation to check.

Run: `test_run(suite="lobby_style_buttons", session_id=<worktree session>)`
Expected: PASS.

Run: `test_run(suite="result_checkup", session_id=<worktree session>)`
Expected: PASS — `test_theme_carries_the_recap_variations` asserts the
banner/pill variations. If it also asserts `WeekTabButton`, drop that one
assertion; it is asserting a retired variation, not catching a bug.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd tests/test_audio_coverage.gd
```

```bash
git add -A Assets/Audio/SFX
```

Message: `chore(weekly-results): retire the week-tab variation and the pane-swipe cue`.

---

### Task 3: Docs, and the full suite

**Files:**
- Modify: `Scripts/SchoolSimulation/WeekHistoryRow.gd`
- Modify: `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`
- Test: the whole suite

- [ ] **Step 1: Point `WeekHistoryRow`'s docs back at the sheet**

This reverses the previous commit's Task 4, because the RIWAYAT tab it named
has gone again. Header:

```gdscript
## One line of the week's RIWAYAT: a minigame that was played or an event
## that fired (2026-09-03 spec section 5).
```

becomes

```gdscript
## One line of the week's Logs sheet (WeekLogsPopup): a minigame that was
## played or an event that fired (2026-09-03 spec section 5; the RIWAYAT tab
## that first held these rows was retired on 2026-09-16).
```

and the `_is_event` comment goes from
`## Read by ResultCheckup._play_history_entrance to choose stamp vs. shake`
back to
`## Read by WeekLogsPopup._play_rows_entrance to choose stamp vs. shake`.

- [ ] **Step 2: Resolve two thirds of the revert's debt entry**

In `docs/superpowers/DEBT.md`, the entry **Three orphans from the Weekly
Results revert (2026-09-16)** now has one orphan left. Rewrite it as a single
entry for the ribbon art alone — `ResultButton` and `WeekLogsPopup` both have
call sites again, so their bullets are **deleted, not marked done**, per
`CLAUDE.md`'s rule for this file. Drop the closing "Resolve as one piece"
line with them.

- [ ] **Step 3: Write the changelog entry**

Insert above the `## 2026-09-16 — Weekly Results reverted to the 2026-09-03
report` entry — newest first, and this is the same day. Head it
`## 2026-09-16 — Weekly Results: tabs out, Logs and Selanjutnya in`, and
cover: what replaced what; that the history moved into `WeekLogsPopup`
rather than being dropped; that `ResultButton` and `WeekLogsPopup` stopped
being orphans while the ribbon art did not; that `WeekTabButton` and
`pane_swipe` were retired one commit after being restored, and why; and the
final totals.

- [ ] **Step 4: Run the full suite**

Refresh the editor per Global Constraints first.

Run: `test_run(session_id=<worktree session>)` with no `suite`.
Expected: the five pre-existing `inventory` / `light_ground_text` failures
and nothing else.

A full run is 15–20s of main-thread work and can drop the bridge after the
reply arrives; the results still count. Budget one restart afterwards.

```bash
git status --porcelain
```

Keep the theme bake from Task 2. `git checkout --`
`Assets/Audio/default_bus_layout.tres` if the run rewrote it. Leave the
twelve `*.png.import` files alone — that churn predates this branch.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/WeekHistoryRow.gd docs/superpowers/CHANGELOG.md docs/superpowers/DEBT.md
```

Message: `docs(changelog): Weekly Results trades its tabs for the Logs sheet`.

---

## Self-review

**Spec coverage.** *What goes* → Task 1 Steps 2–3 (scene) and 8 (script);
*What comes back* → Steps 4, 9, 10, and the export set in Step 13; *What
stays* → no step touches the banner, pills, popup, header, `ScrollFade`,
cards, confetti or the three pill cues, and Task 2 Step 1 explicitly keeps
the three pill/banner variations; *What is retired, again* → Task 2;
*Debt this resolves* → Task 3 Step 2; *Risks* → Task 1 Step 10 (the finale),
Step 14 (both neighbouring suites), Step 11 (deleted coverage), and the
Global Constraints (pre-existing red); *Decisions* → Step 3 (flatten
`PaneStack`) and Task 2 (retire both).

**Placeholders.** Two steps say "read the function and update it": Task 1
Step 10's `_on_close_pressed` and Step 14's `viewport_editability` number.
The first is a three-line function whose new content is fully determined by
the two button names given above; the second is deliberately not guessed,
because the ratchet must be set to what the suite reports rather than to what
a plan predicted. Task 2 Step 5's note about
`test_theme_carries_the_recap_variations` is conditional for the same reason
— the assertion is read, not assumed.

**Type consistency.** `logs_button` / `next_button`, `open_logs()`,
`logs_popup_scene`, `logs_button_text` / `next_button_text`, `_history`,
`_logs_seen` and `_logs_popup` are spelled identically in the Interfaces
block, Steps 9, 10, 13 and the tests. The node paths
`Margin/VBox/Buttons/LogsButton`, `Margin/VBox/Buttons/NextButton` and
`Margin/VBox/ScrollContainer/StudentsPane` are spelled identically in Steps
3, 4, 9, 12, 13 and 14. `WeekLogsPopup`'s `set_history` / `open` /
`row_count` / `closed` match the API in `Scripts/SchoolSimulation/WeekLogsPopup.gd`.
