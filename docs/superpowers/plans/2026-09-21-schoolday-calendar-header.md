# The SchoolDay calendar header — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans`
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.
> Do **not** switch to subagent-driven development: the Godot AI bridge is
> single-client, so a subagent that connects displaces this session's editor
> and gets nothing itself.

**Goal:** Give `BookClockWidget` the day and the week in EventDialogue's exact
format, drawn on the daily-login calendar illustration, and confirm the
already-merged BasketTray mouse drag is green on this branch.

**Architecture:** The header is an authored `Header` node in
`BookClockWidget.tscn` mirroring `EventDialogue.tscn`'s, using the same
`ThemeFactory` variations rather than a lookalike. The script gains
`set_week()` beside the existing `set_day()`, both fed from the same
`GameState` values EventDialogue is handed, so the two screens cannot
disagree. Nothing is built at runtime.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` /
`McpTestSuiteCompat`, the `godot-ai` MCP bridge.

## Global Constraints

- **Worktree.** Work happens in
  `.claude/worktrees/gamecode-tray-fireworks-audio` on branch
  `feat/schoolday-calendar-header`, branched from the merged `origin/Textures`
  (`a446560`). Never `git switch` in the main checkout — another session is
  live there.
- **Its own editor.** The bridge's usual editor serves the *main* checkout.
  Task 0 confirms this worktree's editor; **every `test_run` passes that
  `session_id`.** Never call `session_activate`, never kill every Godot
  process — only the worktree's own pid.
- **Tests are `@tool`, and no test may be a coroutine.** The runner calls
  `suite.call(name)` without awaiting; an `await` aborts the test and it
  reports "0 assertions".
- **Never add a `theme_override_*`.** Use a `ThemeFactory` variation. Only
  layout-only constant overrides (`separation`, `margin_*`) are accepted —
  EventDialogue's `Text` VBox uses `separation = -10`, which is that
  exception, and the copy may use it too.
- **No visual is built at runtime.** The header is nodes in the `.tscn`.
- **Documentation is a hard rule** (`tests/test_script_documentation.gd`): a
  `##` file header and a `##` line on every `@export`.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` → `node_create` / `node_set_property` → `scene_save`.
  `anchors_preset` is inert (set the four anchors); numbers must be unquoted.
- **Scene work first, script work second.** `scene_save` flushes stale script
  tabs over whatever you patched. After any `scene_save`, check
  `git diff HEAD -- '*.gd'` for files you were not editing.
- **Prefer `script_patch`** for `.gd` edits. After editing a `.gd` from
  outside the editor, a no-op `script_patch` on that file forces the reload.
- **Game-facing text is Indonesian**; systems code is English.
- **`Balance.gd` is collaborator-owned.** Read it; never edit it.
- **Two files the suite dirties:** `Assets/Theme/kejartes_theme.tres` (the
  `theme_rebake` suite) and `Assets/Audio/default_bus_layout.tres`
  (`AudioDirector` on boot — it captures the local mute state, so committing
  it can ship the game silent). `git checkout --` both unless intended. The
  12 `Assets/Images/**/*.png.import` files that lose their `etc2` entry are
  editor churn from this machine having no Android export templates; never
  commit them.
- Commits are Conventional Commits with a scope. Commit messages go through a
  **file** (`git commit -F`). In this worktree run git as **plain, separate
  commands** — no `cd &&`, no heredocs — or the shell guard refuses them.

---

### Task 0: Confirm the worktree's editor and baseline

**Files:** none.

- [ ] **Step 1: Find this worktree's session**

Run: `session_manage(op="list")`
Expected: a session whose `project_path` ends
`.claude/worktrees/gamecode-tray-fireworks-audio/`. Record its `session_id`.
If it is absent, launch one: the Godot exe is
`C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`
(the "path" is a directory containing the exe), started with
`--editor --path <worktree>`. Its `.godot/` is already warm.

- [ ] **Step 2: Open the main scene**

Run: `scene_open("res://Scenes/MainMenu/main_menu.tscn", session_id=<id>)`.
Several suites assume it; `test_run` returns a `scene_warning` otherwise.

- [ ] **Step 3: Baseline the suites this branch touches**

Run, each with `session_id=<id>`: `test_run(suite="book_clock_phases")`,
`test_run(suite="school_day")`, `test_run(suite="event_dialogue")`,
`test_run(suite="theme_factory")`.
Expected: all green. A red baseline makes every later failure ambiguous.

- [ ] **Step 4: Confirm the merged BasketTray drag is green here**

This is the whole of the second ask (spec §0 — it shipped in PR #65 and
merged today). Run, each with `session_id=<id>`: `test_run(suite="basket_tray")`,
`test_run(suite="koperasi_tray")`, `test_run(suite="koperasi_tap_spam")`,
`test_run(suite="koperasi_tray_retract")`.

Expected: all green, including `basket_tray`'s
`test_the_drag_listens_on_a_node_that_can_actually_be_hit` and
`test_a_slot_passes_its_press_through_to_the_drag_surface` — the two that pin
the drag surface actually being hit-testable.

**Do not rewrite the drag.** If these pass, the mechanism is present and
correct, and the report says so. If one fails, stop and report: that is a
regression in merged code, not this branch's work.

---

### Task 1: `set_week()` and a banner-writing `set_day()`

Script before scene here, deliberately: the scene in Task 2 attaches nothing,
so there is no stale-tab hazard, and Task 2's nodes need these node-name
constants to exist first.

**Files:**
- Modify: `Scripts/SchoolSimulation/BookClockWidget.gd`
- Test: `tests/test_book_clock_phases.gd`

**Interfaces:**
- Consumes: `GameState.minggu_ke` (int), `GameState.get_max_weeks()` (int).
- Produces: `set_week(week: int, max_weeks: int) -> void`,
  `week_text() -> String`, `day_text() -> String`, and the node-name constants
  `DAY_LABEL_PATH` / `WEEK_LABEL_PATH`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_book_clock_phases.gd`:

```gdscript
# ───────────────────────────── the day/week header (2026-09-21)
# BookClockWidget took the weekday through set_day() and displayed nothing;
# the player's only day readout was two bare labels in SchoolDay's corner,
# with no week count anywhere on the screen.

func test_set_week_formats_like_the_event_dialogue() -> void:
	var w = load(SCENE_PATH).instantiate()
	w.set_week(3, 6)
	assert_eq(w.week_text(), "3/6",
		'the week must read "%d/%d", exactly as EventDialogue writes it')
	w.free()


func test_set_day_writes_the_banner_not_just_the_variable() -> void:
	var w = load(SCENE_PATH).instantiate()
	w.set_day("Selasa")
	assert_eq(w.day_name(), "Selasa", "set_day still records the name")
	assert_eq(w.day_text(), "Selasa", "and now it reaches the banner too")
	w.free()


## The grade ladder, which needs no code of its own: get_max_weeks() returns
## 6/12/16 for Kelas 7/8/9. A hard-coded 6 would pass every Kelas 7 test and
## be wrong for two thirds of the game.
func test_the_week_count_follows_the_grade() -> void:
	var w = load(SCENE_PATH).instantiate()
	for pair in [[3, 6], [9, 12], [14, 16]]:
		w.set_week(pair[0], pair[1])
		assert_eq(w.week_text(), "%d/%d" % [pair[0], pair[1]],
			"Kelas with %d weeks must read %d/%d" % [pair[1], pair[0], pair[1]])
	w.free()


func test_reset_clears_the_header() -> void:
	var w = load(SCENE_PATH).instantiate()
	w.set_day("Rabu")
	w.set_week(2, 6)
	w.reset()
	assert_eq(w.day_text(), "", "reset must clear the banner")
	assert_eq(w.week_text(), "", "reset must clear the week")
	w.free()


## The source, not just the format: both screens must read the same two
## GameState values, or they can drift apart by a week.
func test_school_day_feeds_the_header_from_gamestate() -> void:
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_true(src.contains("set_week("),
		"SchoolDay must tell the widget which week it is")
	assert_true(src.contains("GameState.get_max_weeks()"),
		"the week count must come from GameState, not a literal")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="book_clock_phases", session_id=<id>)`
Expected: FAIL — `set_week`, `week_text` and `day_text` do not exist.

- [ ] **Step 3: Implement**

Patch `Scripts/SchoolSimulation/BookClockWidget.gd`. Beside the existing
`SKY_NODE` / `FOREGROUND_NODE` constants:

```gdscript
## The banner Label that carries the weekday. Task 2's scene must match.
const DAY_LABEL_PATH := ^"Header/DayBanner/DayLabel"
## The Label that carries "3/6" on the calendar badge.
const WEEK_LABEL_PATH := ^"Header/Calendar/Text/WeekLabel"
```

Add the week to the internal state beside `_day_name`:

```gdscript
var _week_text: String = ""
```

Replace `set_day()` and `reset()`, and add `set_week()`:

```gdscript
## Starts a fresh day. Records the weekday, writes it to the banner and
## rewinds the sky to morning.
func set_day(day_name_in: String) -> void:
	_day_name = day_name_in
	_write_header()
	set_progress(0.0)


## The week this day belongs to, in EventDialogue's format: "3/6".
##
## max_weeks is grade-scaled (GameState.get_max_weeks() returns 6/12/16 for
## Kelas 7/8/9), so the same call reads 3/6 in Kelas 7 and 3/16 in Kelas 9
## with nothing here to change.
func set_week(week: int, max_weeks: int) -> void:
	_week_text = "%d/%d" % [week, max_weeks]
	_write_header()


## Rewinds to morning and clears the header.
func reset() -> void:
	_day_name = ""
	_week_text = ""
	_write_header()
	set_progress(0.0)


## What the banner reads. Exists so tests need not know node paths.
func day_text() -> String:
	var l := get_node_or_null(DAY_LABEL_PATH) as Label
	return l.text if l != null else ""


## What the calendar badge reads.
func week_text() -> String:
	var l := get_node_or_null(WEEK_LABEL_PATH) as Label
	return l.text if l != null else ""


## Pushes both strings into the authored Labels. Missing nodes are ignored
## rather than erroring: the widget is instanced in tests and previewed in
## the editor, and a half-built scene must not take the day cinematic down
## with it.
func _write_header() -> void:
	var day_label := get_node_or_null(DAY_LABEL_PATH) as Label
	if day_label != null:
		day_label.text = _day_name
	var week_label := get_node_or_null(WEEK_LABEL_PATH) as Label
	if week_label != null:
		week_label.text = _week_text
```

Update the file header's API sentence: it currently says the public API is
`set_day / set_progress / reset`; add `set_week`.

- [ ] **Step 4: Call it from SchoolDay**

In `Scripts/SchoolSimulation/SchoolDay.gd`, find where `set_day` is called on
the widget (`grep -n "set_day" Scripts/SchoolSimulation/SchoolDay.gd`) and add
beside it:

```gdscript
	book_clock_widget.call("set_week", GameState.minggu_ke, GameState.get_max_weeks())
```

Use `.call()` to match how the file already drives the widget
(`book_clock_widget.call("transition_to", …)`), since `book_clock_widget` is
typed `Control`.

- [ ] **Step 5: Run the tests**

Run: `test_run(suite="book_clock_phases", session_id=<id>)`
Expected: the three source/format tests PASS. The node-reading ones
(`day_text`, `week_text`) still return `""` and FAIL — the scene has no header
yet. That is Task 2's red.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/BookClockWidget.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_book_clock_phases.gd
git commit -F <message file>
```

Message: `feat(schoolday): BookClockWidget takes the week as well as the day`

---

### Task 2: The authored header

**Files:**
- Modify: `Scenes/SchoolSimulation/BookClockWidget.tscn`
- Test: `tests/test_book_clock_phases.gd`

**Interfaces:**
- Consumes: `DAY_LABEL_PATH` / `WEEK_LABEL_PATH` from Task 1.
- Produces: the `Header` subtree those paths resolve against.

- [ ] **Step 1: Write the failing test**

```gdscript
## The header is authored, and it is EventDialogue's header rather than a
## lookalike: same variations, not a set of overrides that happen to match.
func test_the_header_is_authored_with_the_shared_variations() -> void:
	var w = load(SCENE_PATH).instantiate()
	for path in [BookClockWidget.DAY_LABEL_PATH, BookClockWidget.WEEK_LABEL_PATH]:
		assert_true(w.get_node_or_null(path) != null,
			"the scene must author %s" % path)
	var banner: Control = w.get_node_or_null("Header/DayBanner")
	assert_true(banner != null, "the day banner must exist")
	if banner != null:
		assert_eq(String(banner.theme_type_variation), "DayBannerPanel",
			"the banner must use EventDialogue's own panel variation")
	var day_label: Label = w.get_node_or_null(BookClockWidget.DAY_LABEL_PATH)
	if day_label != null:
		assert_eq(String(day_label.theme_type_variation), "DayBannerLabel",
			"the day must use EventDialogue's own label variation")
	w.free()


## The illustration asked for by name: the lobby's daily-login calendar, not
## EventDialogue's flat calendar_badge.png and nothing newly drawn.
func test_the_badge_wears_the_daily_login_calendar() -> void:
	var w = load(SCENE_PATH).instantiate()
	var cal: TextureRect = w.get_node_or_null("Header/Calendar")
	assert_true(cal != null, "the calendar badge must exist")
	if cal != null and cal.texture != null:
		assert_true(String(cal.texture.resource_path).ends_with("icon_daily_login.png"),
			"the badge must wear the daily-login calendar")
	w.free()


## The daily-login calendar is drawn in perspective: its paper rises to the
## right. Straight text on it reads as sliding off the page. -9 degrees is
## measured from the art (a least-squares fit through the paper's top edge
## across 48 columns gave -8.97), not eyeballed.
func test_the_badge_text_is_rotated_onto_the_paper() -> void:
	var w = load(SCENE_PATH).instantiate()
	var text_box: Control = w.get_node_or_null("Header/Calendar/Text")
	assert_true(text_box != null, "the badge's text container must exist")
	if text_box != null:
		assert_true(absf(text_box.rotation_degrees - (-9.0)) < 0.5,
			"the text must sit on the tilted paper, got %f" % text_box.rotation_degrees)
	w.free()


## The header must not eat taps meant for the day screen over it.
func test_the_header_ignores_the_mouse() -> void:
	var w = load(SCENE_PATH).instantiate()
	for path in ["Header", "Header/Calendar", "Header/DayBanner"]:
		var n: Control = w.get_node_or_null(path)
		if n != null:
			assert_eq(n.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s must not take input from the screen above it" % path)
	w.free()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="book_clock_phases", session_id=<id>)`
Expected: FAIL — the scene has no `Header`.

- [ ] **Step 3: Build the header through the editor**

`scene_open("res://Scenes/SchoolSimulation/BookClockWidget.tscn")`, then
`node_create` / `node_set_property` (or one `batch_execute`), then
`scene_save`. Remember `anchors_preset` is inert — set the four anchors —
numbers are unquoted, and `node_create` appends last, so the Header lands
above the sky and foreground, which is what it needs.

Mirror `EventDialogue.tscn`'s geometry, which is authored on the same
1080×1920 canvas:

| Node | Type | Properties |
|---|---|---|
| `Header` | `Control` | `anchor_right = 1`, `offset_bottom = 300`, `mouse_filter = 2` |
| `Header/DayBanner` | `PanelContainer` | `offset_left = 250`, `offset_top = 100`, `offset_right = 936`, `offset_bottom = 236`, `mouse_filter = 2`, `theme_type_variation = "DayBannerPanel"` |
| `Header/DayBanner/DayLabel` | `Label` | `theme_type_variation = "DayBannerLabel"`, `text = "Senin"`, `horizontal_alignment = 1`, `vertical_alignment = 1` |
| `Header/Calendar` | `TextureRect` | `offset_left = 104`, `offset_top = 44`, `offset_right = 312`, `offset_bottom = 292`, `mouse_filter = 2`, `texture = res://Assets/Images/UI/icon_daily_login.png`, `expand_mode = 1`, `stretch_mode = 5` |
| `Header/Calendar/Text` | `VBoxContainer` | `anchor_top = 0.40`, `anchor_right = 1.0`, `anchor_bottom = 0.88`, `mouse_filter = 2`, `theme_override_constants/separation = -10`, `alignment = 1`, `rotation_degrees = -9.0` |
| `Header/Calendar/Text/MingguLabel` | `Label` | `theme_type_variation = "CalendarLabel"`, `text = "Minggu"`, `horizontal_alignment = 1` |
| `Header/Calendar/Text/WeekLabel` | `Label` | `theme_type_variation = "DayBannerLabel"`, `text = "2/6"`, `horizontal_alignment = 1` |

`separation = -10` is a layout-only constant, the documented exception to the
override rule, and is copied from EventDialogue rather than invented.

Set `Text`'s `pivot_offset` to its own centre after sizing, so the rotation
turns about the middle of the paper instead of swinging the box off it.

**Immediately after `scene_save`, run `git diff HEAD -- '*.gd'`** and restore
any script you were not editing.

- [ ] **Step 4: Run the tests**

Run: `test_run(suite="book_clock_phases", session_id=<id>)`
Expected: PASS, including Task 1's `day_text` / `week_text` tests, which now
have nodes to write to.

Run: `test_run(suite="viewport_editability", session_id=<id>)`
Expected: PASS — the header is authored, so the runtime-construction ratchet
must not rise.

- [ ] **Step 5: Look at it, at full size**

`editor_screenshot(source="viewport_2d", max_resolution=0)` on the open
BookClockWidget scene. Judge two things a test cannot: whether the text sits
square on the paper, and whether the badge and banner overlap the school
foreground badly. A scaled capture cannot show a few degrees of misalignment —
take it full size.

If the text sits wrong, the knob is `Text`'s anchors and `rotation_degrees`,
**not** the art.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/BookClockWidget.tscn tests/test_book_clock_phases.gd
git commit -F <message file>
```

Message: `feat(schoolday): draw the day and week on the daily-login calendar`

---

### Task 3: Stop the day name appearing twice

**Files:**
- Modify: `Scenes/SchoolSimulation/SchoolDay.tscn`
- Test: `tests/test_school_day.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_school_day.gd`:

```gdscript
## With the banner showing "Senin", DayScreen/DayLabel showed it a second
## time a few hundred pixels away. Hidden, not deleted: this suite pins the
## node path, and removing a node from a shipped scene is a bigger decision
## than de-duplicating a label needs to be.
func test_the_day_name_is_not_shown_twice() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/SchoolDay.tscn")
	var at := src.find('[node name="DayLabel" type="Label" parent="DayScreen"')
	assert_true(at >= 0, "DayScreen/DayLabel must still exist")
	if at < 0:
		return
	var block := src.substr(at, 400)
	assert_true(block.contains("visible = false"),
		"DayLabel must be hidden now the header carries the day")


## DayNumberLabel stays: "Hari 1 dari 5" is the day's place in the WEEK,
## which the header does not carry -- the header is the day's name and the
## week's place in the grade. Three facts, no repeats.
func test_the_day_number_is_still_shown() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/SchoolDay.tscn")
	var at := src.find('[node name="DayNumberLabel" type="Label" parent="DayScreen"')
	assert_true(at >= 0, "DayScreen/DayNumberLabel must exist")
	if at < 0:
		return
	assert_false(src.substr(at, 400).contains("visible = false"),
		"the day-of-week counter must stay visible")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="school_day", session_id=<id>)`
Expected: FAIL — `DayLabel` is visible.

- [ ] **Step 3: Hide the label**

Through the editor: `scene_open` `SchoolDay.tscn`, set
`DayScreen/DayLabel`'s `visible` to `false`, `scene_save`. Then
`git diff HEAD -- '*.gd'` again.

`SchoolDay.gd` keeps writing `day_label.text` — that is harmless on a hidden
Label, and leaving it means the day name is one edit away from coming back if
this proves wrong on a real screen.

- [ ] **Step 4: Run the tests**

Run: `test_run(suite="school_day", session_id=<id>)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scenes/SchoolSimulation/SchoolDay.tscn tests/test_school_day.gd
git commit -F <message file>
```

Message: `fix(schoolday): hide the day label the header now carries`

---

### Task 4: The full suite, the changelog, and the report

- [ ] **Step 1: Run everything**

Run: `test_run(session_id=<id>)` with no `suite`.
Expected: 140 suites green (2028 tests before this branch's additions).

A full run is 15–20 s of near-continuous main-thread work and can drop the
bridge; its results still count once they have arrived. Budget one editor
restart for it.

- [ ] **Step 2: Clean up what the run dirtied**

```bash
git status --porcelain
```

`git checkout --` `Assets/Theme/kejartes_theme.tres`,
`Assets/Audio/default_bus_layout.tres` and the `*.png.import` churn unless a
change there was intended. The bus layout in particular captures the local
mute state — committing it can ship the game silent.

- [ ] **Step 3: Changelog**

Newest first in `docs/superpowers/CHANGELOG.md`: the header, the measured
tilt, the hidden duplicate label, and that the BasketTray drag needed no work
because it had merged that morning. Delete any DEBT.md entry this resolved.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/CHANGELOG.md
git commit -F <message file>
```

Message: `docs(changelog): record the SchoolDay calendar header`

---

## Self-review

**Spec coverage.** §0 (BasketTray already shipped) → Task 0 Step 4, verify
only. §2 API → Task 1. §2 illustration + §3 rotation → Task 2. §2 "avoiding a
doubled day name" → Task 3. §5 grades → Task 1 Step 1's
`test_the_week_count_follows_the_grade`. §4 files and §6 state (none) need no
task.

**Placeholder scan.** Every code step carries real code. Task 1 Step 4 tells
the implementer to `grep` for the real `set_day` call site rather than naming
a guessed line number.

**Type consistency.** `set_week(week: int, max_weeks: int)`, `week_text()`,
`day_text()`, `DAY_LABEL_PATH` and `WEEK_LABEL_PATH` match between Task 1's
tests, Task 1's implementation and Task 2's tests. The node paths in the
constants match the scene table in Task 2 Step 3 exactly
(`Header/DayBanner/DayLabel`, `Header/Calendar/Text/WeekLabel`).
