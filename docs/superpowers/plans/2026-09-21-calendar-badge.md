# EventDialogue calendar badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild EventDialogue's weekly status badge on the lobby's daily-login
calendar art, and resize the week fraction so Kelas 9's `12/16` fits its tilted page.

**Architecture:** Four commits. The theme variation lands first so the scene has
something to point at; the art and geometry second; the two-size fraction third,
because it is the only change that touches scene and script together; cleanup last.

**Tech Stack:** Godot 4.6, GDScript, the `godot-ai` MCP bridge, `McpTestSuite`.

Spec: `docs/superpowers/specs/2026-09-21-calendar-badge-design.md`

## Global Constraints

- **No `theme_override_*`.** Use a `ThemeFactory` type variation. The only
  accepted exception is a layout-only constant (`separation`, `margin_*`).
  `tests/test_event_dialogue.gd` scans the `.tscn` for the four banned kinds.
- **No visual built at runtime.** Static chrome is a node in the `.tscn`.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` -> `node_set_property` / `node_manage` -> `scene_save`. A node's
  *type* can only be changed by delete-and-recreate.
- **Scene work first, script work second.** `scene_save` flushes stale script
  tabs over whatever you patched. After patching a `.gd`, restart the editor
  before the next `scene_save`.
- **Rescan after editing a `.gd`, before running tests** — prefer making edits
  through `script_patch` so the reload happens for you.
- **A new tunable number** goes in a named `const` block or an `@export` in the
  script that owns the behaviour, never inline.
- **Every `@export` and every script needs a `##` doc line**
  (`tests/test_script_documentation.gd`).
- **Indonesian** for game-facing identifiers and UI text; English for systems code.
- Measured values, copied verbatim from the spec: safe page field
  **0.218..0.927 x 0.44..0.84**, node **204x248**, numerator **56**,
  denominator **32**, `12/16` at 56/32 = **113px** in a **144px** field.

---

### Task 1: The `CalendarWeekLabel` theme variation

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (const block near `:46`, `_build_event_dialogue` near `:130`)
- Modify: `tests/test_event_dialogue.gd` (`_VARIATIONS` near `:289`, `test_factory_builds_the_dialogue_variations` near `:300`)
- Rebake: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces: `ThemeFactory.CALENDAR_WEEK_SIZE : int` (= 56) and a theme type
  variation `CalendarWeekLabel` based on `RichTextLabel`, carrying
  `normal_font_size`, `normal_font` and `default_color`. Tasks 2 and 3 point the
  scene's `WeekLabel` at it.

- [ ] **Step 1: Write the failing test**

In `tests/test_event_dialogue.gd`, add the variation to `_VARIATIONS`:

```gdscript
const _VARIATIONS := {
	"EventDialoguePanel": &"PanelContainer", "EventDialogueText": &"RichTextLabel",
	"DayBannerPanel": &"PanelContainer", "DayBannerLabel": &"Label", "CalendarLabel": &"Label",
	"CalendarWeekLabel": &"RichTextLabel",
}
```

and add these three lines to `test_factory_builds_the_dialogue_variations`,
directly after the existing `assert_eq(theme.get_font("font", "CalendarLabel"), t.font_body_bold)`:

```gdscript
	assert_eq(theme.get_font("normal_font", "CalendarWeekLabel"), t.font_body_bold)
	assert_eq(theme.get_font_size("normal_font_size", "CalendarWeekLabel"),
		ThemeFactory.CALENDAR_WEEK_SIZE)
	assert_eq(theme.get_color("default_color", "CalendarWeekLabel"), t.text_primary)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="event_dialogue")`
Expected: FAIL — `CalendarWeekLabel base type` (the variation does not exist),
and `test_the_bake_declares_the_dialogue_variations` fails too because
`_VARIATIONS` now names a type the bake has never seen.

- [ ] **Step 3: Add the constant**

In `Scripts/Design/ThemeFactory.gd`, directly under the existing
`const DAY_BANNER_OUTLINE := 12` block:

```gdscript
## The week fraction's numerator size. 56 is the largest size at which Kelas
## 9's widest string, "12/16", clears the daily-login calendar's tilted page
## (113 px of a 144 px field); at 64 it is 174 px and overflows.
const CALENDAR_WEEK_SIZE := 56
```

- [ ] **Step 4: Build the variation**

In `_build_event_dialogue`, directly after the existing `for spec in [...]` loop
that builds `DayBannerLabel` and `CalendarLabel`:

```gdscript
	theme.add_type("CalendarWeekLabel")
	theme.set_type_variation("CalendarWeekLabel", "RichTextLabel")
	theme.set_font_size("normal_font_size", "CalendarWeekLabel", CALENDAR_WEEK_SIZE)
	theme.set_color("default_color", "CalendarWeekLabel", tokens.text_primary)
	if bold != null:
		theme.set_font("normal_font", "CalendarWeekLabel", bold)
```

- [ ] **Step 5: Rebake the theme**

Run `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X) in the editor.
Then `git diff --stat Assets/Theme/kejartes_theme.tres` — expect it changed.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="event_dialogue")` then `test_run(suite="theme_factory")`
Expected: PASS on both.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_event_dialogue.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): add the CalendarWeekLabel variation"
```

- [ ] **Step 8: Restart the editor**

A `class_name` script changed. Stop the project, `filesystem_manage(op="scan")`,
then restart Godot so the next `scene_save` writes fresh script tabs.

---

### Task 2: The lobby art, and the page geometry

**Files:**
- Modify: `Scripts/SchoolSimulation/EventDialogueCatalog.gd:27`
- Modify: `Scenes/SchoolSimulation/EventDialogue.tscn` (`Header/Calendar`, `Header/Calendar/Text`)
- Modify: `tests/test_event_dialogue.gd`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `EventDialogueCatalog.CALENDAR_BADGE` now
  `res://Assets/Images/UI/icon_daily_login.png`; `Header/Calendar` is 204x248;
  `Header/Calendar/Text` is anchored to the tilted page. Task 3's fit test reads
  both.

- [ ] **Step 1: Write the failing tests**

Add both to `tests/test_event_dialogue.gd`, after `test_the_scene_is_authored_and_themed`:

```gdscript
func test_the_calendar_uses_the_lobby_art() -> void:
	assert_eq(EventDialogueCatalog.CALENDAR_BADGE,
		"res://Assets/Images/UI/icon_daily_login.png",
		"the header calendar is the lobby's daily-login calendar")
	var d = _dialogue("nasi_kotak")
	var cal := d.get_node("Header/Calendar") as TextureRect
	assert_eq(cal.offset_right - cal.offset_left, 204.0, "204x248 matches the art's aspect")
	assert_eq(cal.offset_bottom - cal.offset_top, 248.0)


func test_the_text_block_sits_on_the_calendar_page() -> void:
	var d = _dialogue("nasi_kotak")
	var text := d.get_node("Header/Calendar/Text") as Control
	for pair in [["anchor_left", 0.218], ["anchor_right", 0.927],
			["anchor_top", 0.44], ["anchor_bottom", 0.84]]:
		var got: float = text.get(pair[0])
		assert_true(absf(got - float(pair[1])) < 0.001,
			"%s is %f, want %f -- the page is a sheared quad, not the node's rect"
				% [pair[0], got, pair[1]])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="event_dialogue")`
Expected: FAIL — `CALENDAR_BADGE` is still `.../EventDialogue/calendar_badge.png`,
the node is 208 wide, and the anchors are still `0.0/1.0 x 0.42/0.96`.

- [ ] **Step 3: Point the constant at the lobby art**

In `Scripts/SchoolSimulation/EventDialogueCatalog.gd`, replace line 27:

```gdscript
## The header calendar. Shared with the lobby's daily-login button so the two
## surfaces carry one calendar; its cream page is a sheared quad, which is why
## Header/Calendar/Text is anchored inside it rather than across the node.
const CALENDAR_BADGE := "res://Assets/Images/UI/icon_daily_login.png"
```

Note this leaves the `ART_DIR + ...` form behind deliberately — the art no longer
lives in `Assets/Images/EventDialogue/`.

- [ ] **Step 4: Edit the scene through the editor**

`scene_open("res://Scenes/SchoolSimulation/EventDialogue.tscn")`, then
`batch_execute` with these `set_property` commands, then `scene_save`:

| Node | Property | Value |
|---|---|---|
| `Header/Calendar` | `texture` | `res://Assets/Images/UI/icon_daily_login.png` |
| `Header/Calendar` | `offset_right` | `308` |
| `Header/Calendar/Text` | `anchor_left` | `0.218` |
| `Header/Calendar/Text` | `anchor_right` | `0.927` |
| `Header/Calendar/Text` | `anchor_top` | `0.44` |
| `Header/Calendar/Text` | `anchor_bottom` | `0.84` |

Numbers unquoted. `anchors_preset` is inert — the four anchors are what save.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="event_dialogue")`
Expected: PASS. `test_the_scene_is_authored_and_themed` still passes — it
asserts the node's texture equals `CALENDAR_BADGE`, and both moved together.

- [ ] **Step 6: Check nothing else was written**

```bash
git status --porcelain
```

Expect only the three intended files. If a `.gd` you did not edit appears, a
stale script tab was flushed — `git checkout --` it.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/EventDialogueCatalog.gd Scenes/SchoolSimulation/EventDialogue.tscn tests/test_event_dialogue.gd
git commit -m "feat(event-dialogue): use the lobby calendar for the week badge"
```

---

### Task 3: The two-size week fraction

The only change that touches scene and script together: `WeekLabel` has to become
a `RichTextLabel` in the scene and in the `@onready` type at the same time, or
`_ready()` fails on a type mismatch. Scene first, then the script, then restart.

**Files:**
- Modify: `Scenes/SchoolSimulation/EventDialogue.tscn` (`Header/Calendar/Text/WeekLabel`)
- Modify: `Scripts/SchoolSimulation/EventDialogue.gd:24`, `:62`, and the `@export` block
- Modify: `tests/test_event_dialogue.gd:220`, `:263`

**Interfaces:**
- Consumes: `ThemeFactory.CALENDAR_WEEK_SIZE` (Task 1), the page anchors (Task 2).
- Produces: `EventDialogue.week_denominator_font_size : int` (= 32) and
  `week_label : RichTextLabel` whose `get_parsed_text()` is the player-visible
  fraction.

- [ ] **Step 1: Write the failing tests**

In `tests/test_event_dialogue.gd`, change the assertion in
`test_open_dresses_the_screen` (currently `assert_eq(d.week_label.text, "2/6")`):

```gdscript
	assert_eq(d.week_label.get_parsed_text(), "2/6", "the player sees the bare fraction")
```

In `test_the_scene_is_authored_and_themed`'s `want` dict, change `WeekLabel`:

```gdscript
		"Header/Calendar/Text/WeekLabel": &"CalendarWeekLabel",
```

And add the fit test after `test_the_text_block_sits_on_the_calendar_page`:

```gdscript
func test_the_widest_week_fits_the_calendar_page() -> void:
	var d = _dialogue("nasi_kotak")
	var cal := d.get_node("Header/Calendar") as TextureRect
	var text := d.get_node("Header/Calendar/Text") as Control
	var field: float = (text.anchor_right - text.anchor_left) \
		* (cal.offset_right - cal.offset_left)
	var bold: Font = DesignTokens.load_default().font_body_bold
	assert_true(bold != null, "font_body_bold is set")
	if bold == null:
		return
	# Kelas 9 is the binding case: Balance.JUMLAH_MINGGU_KELAS_9 is 16.
	var widest: float = bold.get_string_size("12", HORIZONTAL_ALIGNMENT_LEFT, -1,
		ThemeFactory.CALENDAR_WEEK_SIZE).x
	widest += bold.get_string_size("/16", HORIZONTAL_ALIGNMENT_LEFT, -1,
		d.week_denominator_font_size).x
	assert_true(widest < field,
		"Kelas 9's 12/16 is %.0f px in a %.0f px page" % [widest, field])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="event_dialogue")`
Expected: FAIL — `get_parsed_text` does not exist on a `Label`, the variation is
still `DayBannerLabel`, and `week_denominator_font_size` does not exist.

- [ ] **Step 3: Retype the node in the scene**

`scene_open`, then delete `Header/Calendar/Text/WeekLabel` and recreate it as a
`RichTextLabel` under `Header/Calendar/Text` — a node's type cannot be changed in
place. `node_create` appends last, which is where `WeekLabel` already belongs
(below `MingguLabel`), so no `move_node` is needed. Set:

| Property | Value |
|---|---|
| `theme_type_variation` | `CalendarWeekLabel` |
| `bbcode_enabled` | `true` |
| `fit_content` | `true` |
| `scroll_active` | `false` |
| `autowrap_mode` | `0` |
| `layout_mode` | `2` |
| `text` | `[center]2[font_size=32]/6[/font_size][/center]` |

`RichTextLabel` has no `horizontal_alignment` — centring is the `[center]` tag,
which is why the authored default above carries it and why `open()` writes it
too. Then `scene_save`.

- [ ] **Step 4: Patch the script**

In `Scripts/SchoolSimulation/EventDialogue.gd`, change line 24:

```gdscript
@onready var week_label: RichTextLabel = $Header/Calendar/Text/WeekLabel
```

Add beside the existing `typewriter_chars_per_second` export:

```gdscript
## Point size of the week fraction's denominator ("/16"). The numerator uses
## the CalendarWeekLabel variation's own size; this one rides inline in BBCode,
## so it lives here rather than in ThemeFactory.
@export var week_denominator_font_size: int = 32
```

And replace line 62:

```gdscript
	week_label.text = "[center]%d[font_size=%d]/%d[/font_size][/center]" % [
		week, week_denominator_font_size, max_weeks]
```

- [ ] **Step 5: Restart the editor**

A script was patched after a scene save. Stop the project,
`filesystem_manage(op="scan")`, restart Godot so every tab reloads from disk.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="event_dialogue")`
Expected: PASS, including `12/16 is 113 px in a 144 px page`.

- [ ] **Step 7: Check nothing else was written**

```bash
git status --porcelain
```

- [ ] **Step 8: Commit**

```bash
git add Scenes/SchoolSimulation/EventDialogue.tscn Scripts/SchoolSimulation/EventDialogue.gd tests/test_event_dialogue.gd
git commit -m "fix(event-dialogue): size the week fraction to the calendar page"
```

---

### Task 4: Retire the old badge

**Files:**
- Delete: `Assets/Images/EventDialogue/calendar_badge.png`, `calendar_badge.png.import`
- Modify: `docs/superpowers/DEBT.md:59`

- [ ] **Step 1: Prove the art is unreferenced**

```bash
grep -rn "calendar_badge" --include="*.gd" --include="*.tscn" --include="*.tres" .
```

Expected: no hits outside the two files being deleted. If anything hits, stop and
fix that reference first.

- [ ] **Step 2: Delete the art and its import**

```bash
git rm Assets/Images/EventDialogue/calendar_badge.png Assets/Images/EventDialogue/calendar_badge.png.import
```

- [ ] **Step 3: Drop the resolved entry from DEBT.md**

In `docs/superpowers/DEBT.md`, remove `calendar_badge.png` from the placeholder
list around line 59, leaving the surrounding entries intact. The entry is deleted
once resolved, not marked done.

- [ ] **Step 4: Run the full suite**

Run: `test_run()` with no suite filter.
Expected: every suite green. Budget one editor restart afterwards — a full run
drops the bridge.

- [ ] **Step 5: Check the two files a full run rewrites**

```bash
git status --porcelain -- Assets/Theme/kejartes_theme.tres default_bus_layout.tres
```

`git checkout --` whichever you did not intend to change. The rebake from Task 1
is intended and already committed; a fresh diff here means the run rebaked again.

- [ ] **Step 6: Commit**

```bash
git add -A Assets/Images/EventDialogue docs/superpowers/DEBT.md
git commit -m "chore(assets): retire the placeholder calendar badge"
```
