# Shorten Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tiny Lobby **Shorten** button that opens a Jangan Skip Dialog / Skip Dialog panel. With Skip Dialog on, the eight minigames skip their EventDialogue line.

**Architecture:**
- **The setting.** A saved `GameSettings.skip_event_dialogue` bool.
- **The rule.** One catalog rule decides which dialogues it skips: `shorten_skips()`, which is true for TAP entries except Nasi Kotak and Hujan.
- **The skip.** SchoolDay returns early from `_show_event_dialogue()`.
- **The panel.** A self-contained `ShortenPanel.tscn` popup, instanced by `loby.gd` when the new button is pressed.

**Tech Stack:** Godot 4.6 GDScript. Tests are McpTestSuite suites run through the godot-ai MCP `test_run`.

Spec: `docs/superpowers/specs/2026-09-14-shorten-dialog-design.md`.

## Global Constraints

- **Suites.** Every suite is `@tool`, extends `McpTestSuite`, overrides `suite_name()`, and has no coroutine tests. Run a suite with `test_run(suite="<suite_name()>")`.
- **Scripts.** Every script has a `##` header in its first 12 lines and a `##` line directly above every `@export`.
- **No `theme_override_*`** except layout constants (`separation`, `margin_*`). Styling goes through ThemeFactory variations.
- **No runtime visual construction:** no `Control.new()`. Build `.tscn` files through the editor MCP, never by hand while the editor is attached.
- **Editor authoring.** Children of a plain `Control` need `layout_mode = 1` before their anchors or offsets are set. `node_create` appends last, so reorder with `node_manage(op="move")` when z-order matters.
- **Button heights.** A themed button's authored height must be a size step: 96, 128 or 160.
- **Save hazard order.** Existing scripts change only through `script_patch`, which keeps open editor tabs in sync. Scene work comes first and script patches second; `loby.gd` is patched only after `loby.tscn` has been saved. After every `scene_save`, check that `git diff HEAD -- '*.gd'` lists only this task's files.
- **Balance.gd is read-only.**
- **Labels.** Use exactly "Shorten", "Jangan Skip Dialog" and "Skip Dialog". The status lines are "Sekarang: dialog minigame ditampilkan." and "Sekarang: dialog minigame dilewati." No emoji.
- **Settings file.** Tests must never write the real `user://settings.cfg`: `ShortenPanel.pick()` saves only outside the editor, and the suite restores `GameSettings.skip_event_dialogue` in teardown.
- **Running the game.** Use `project_run(..., autosave=false)`.
- **Commits.** Conventional Commits with a scope, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Never stage `addons/godot_ai/utils/update_activation_runner.gd*`.

## File map

| File | Responsibility |
|---|---|
| `Scripts/GameSettings.gd` | `skip_event_dialogue`, saved as `[pengaturan] skip_dialog` |
| `Scripts/SchoolSimulation/EventDialogueCatalog.gd` | `SHORTEN_KEEPS`, `shorten_skips(key)` |
| `Scripts/SchoolSimulation/SchoolDay.gd` | early return in `_show_event_dialogue()` |
| `Scripts/Lobby/ShortenPanel.gd` (new) | wires the two options and the scrim; fills the status line; closes |
| `Scenes/Lobby/ShortenPanel.tscn` (new) | Scrim, centred Card, title, status, two buttons |
| `Scenes/Lobby/loby.tscn` | `ShortenButton` on the money row, under the popups |
| `Scripts/Lobby/loby.gd` | wires `ShortenButton`; instances the panel |
| `tests/test_shorten.gd` (new) | the setting, the rule, SchoolDay, the panel, the Lobby button |
| `tests/test_lobby.gd`, `tests/test_lobby_layout.gd`, `tests/test_confirm_pair_semantics.gd` | the button's touch target and face clearance; the panel counts as non-destructive |
| `CLAUDE.md`, `docs/superpowers/CHANGELOG.md` | docs |

---

### Task 1: The setting and the skip rule

**Files:**
- Modify: `Scripts/GameSettings.gd`, `Scripts/SchoolSimulation/EventDialogueCatalog.gd`, `Scripts/SchoolSimulation/SchoolDay.gd`, all through `script_patch`
- Create: `tests/test_shorten.gd`

**Interfaces:**
- Produces:
  - `GameSettings.skip_event_dialogue: bool` (default `false`)
  - `EventDialogueCatalog.SHORTEN_KEEPS: Array`
  - `static EventDialogueCatalog.shorten_skips(key: String) -> bool`

- [ ] **Step 1: Write the failing tests**

`tests/test_shorten.gd`:

```gdscript
@tool
extends McpTestSuite

## Shorten (2026-09-14 shorten-dialog spec): the GameSettings switch, which
## dialogues it skips, SchoolDay's early return, the Lobby button and its panel.

const _GAME_SETTINGS := "res://Scripts/GameSettings.gd"
const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const _LOBBY_SCENE := "res://Scenes/Lobby/loby.tscn"
const _LOBBY_SCRIPT := "res://Scripts/Lobby/loby.gd"
const _PANEL_SCENE := "res://Scenes/Lobby/ShortenPanel.tscn"
const _PANEL_SCRIPT := "res://Scripts/Lobby/ShortenPanel.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _MINIGAME_KEYS := ["Menjodohkan", "Variabel", "PilihanGanda", "Password",
	"MainBola", "Badminton", "BuatBatik", "LombaMenari"]

var _saved_skip: bool


func suite_name() -> String:
	return "shorten"


func setup() -> void:
	_saved_skip = GameSettings.skip_event_dialogue


func teardown() -> void:
	GameSettings.skip_event_dialogue = _saved_skip


## The body of `fn` in `src`, up to the next top-level func.
func _body(src: String, fn: String) -> String:
	var start := src.find("\nfunc %s(" % fn)
	if start == -1:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


# ── the setting ──────────────────────────────────────────────────────────────

func test_the_setting_starts_off() -> void:
	var fresh = load(_GAME_SETTINGS).new()
	assert_false(fresh.skip_event_dialogue, "dialogues show until the player asks to skip")
	fresh.free()


func test_the_setting_is_saved_and_loaded_beside_the_tutorial_switch() -> void:
	var src := FileAccess.get_file_as_string(_GAME_SETTINGS)
	assert_contains(src, 'config.set_value("pengaturan", "skip_dialog", skip_event_dialogue)')
	assert_contains(src, 'skip_event_dialogue = config.get_value("pengaturan", "skip_dialog", false)')


# ── what Shorten skips ───────────────────────────────────────────────────────

func test_shorten_skips_exactly_the_eight_minigames() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		assert_eq(EventDialogueCatalog.shorten_skips(key), key in _MINIGAME_KEYS, key)


func test_shorten_keeps_the_parent_the_rain_and_every_choice() -> void:
	for key in ["nasi_kotak", "hujan", "les_akademis", "latihan_olahraga", "workshop_seni"]:
		assert_false(EventDialogueCatalog.shorten_skips(key), key + " keeps its dialogue")
	assert_false(EventDialogueCatalog.shorten_skips("NoSuchKey"), "an unknown key is not skipped")


func test_school_day_skips_before_it_builds_anything() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_show_event_dialogue")
	var skip := body.find("if GameSettings.skip_event_dialogue and EventDialogueCatalog.shorten_skips(key):")
	var build := body.find("dialogue_scene.instantiate()")
	assert_true(skip != -1 and build > skip, "Shorten returns before the dialogue is instanced")
	assert_contains(body.substr(skip, 120), "return true", "a skipped dialogue lets the minigame carry on")
```

- [ ] **Step 2: Run it to see it fail**

`filesystem_manage(op="scan")`, then `test_run(suite="shorten")`. Expected: the suite reports broken or failed, because `skip_event_dialogue` and `shorten_skips` do not exist yet.

- [ ] **Step 3: GameSettings**

Use `script_patch` on `res://Scripts/GameSettings.gd`. First patch, the variable:

old: `var minigame_tutorial_enabled: bool = true\n`

new:
```gdscript
var minigame_tutorial_enabled: bool = true
## Shorten (Lobby panel, 2026-09-14): true skips the EventDialogue line before
## each minigame. Saved beside the tutorial switch.
var skip_event_dialogue: bool = false
```

Second patch, saving: after the line `config.set_value("pengaturan", "minigame_tutorial", minigame_tutorial_enabled)`, add `config.set_value("pengaturan", "skip_dialog", skip_event_dialogue)` at the same indent.

Third patch, loading: after the line `minigame_tutorial_enabled = config.get_value("pengaturan", "minigame_tutorial", true)`, add `skip_event_dialogue = config.get_value("pengaturan", "skip_dialog", false)` at the same indent.

- [ ] **Step 4: The catalog rule**

Use `script_patch` on `res://Scripts/SchoolSimulation/EventDialogueCatalog.gd`. Insert this directly before `## True when \`key\` has a dialogue.`:

```gdscript
## TAP entries the Lobby's Shorten switch never skips: the parent's lunch and
## the rain are scenes in their own right, not minigame intros (2026-09-14
## shorten-dialog spec).
const SHORTEN_KEEPS := ["nasi_kotak", "hujan"]


## True when Shorten skips this entry's dialogue: a TAP entry (there is no
## choice to make) that is not in SHORTEN_KEEPS. An unknown key is never
## skipped.
static func shorten_skips(key: String) -> bool:
	return entry(key).get("mode", "") == MODE_TAP and not SHORTEN_KEEPS.has(key)


```

- [ ] **Step 5: SchoolDay's early return**

Use `script_patch` on `res://Scripts/SchoolSimulation/SchoolDay.gd`.

old:
```gdscript
	if not EventDialogueCatalog.has_entry(key):
		return true
	var dialogue_scene = event_dialogue_scene
```

new:
```gdscript
	if not EventDialogueCatalog.has_entry(key):
		return true
	# Shorten (Lobby): the player chose to skip the choice-free minigame lines.
	if GameSettings.skip_event_dialogue and EventDialogueCatalog.shorten_skips(key):
		return true
	var dialogue_scene = event_dialogue_scene
```

- [ ] **Step 6: Run to see it pass**

`test_run(suite="shorten")`, then `test_run(suite="event_dialogue")` and `test_run(suite="school_day")`. Expected: all pass. If `shorten` still sees an old GameSettings, do a no-op `script_patch` on `GameSettings.gd` and run it again.

- [ ] **Step 7: Commit**

```bash
git add Scripts/GameSettings.gd Scripts/SchoolSimulation/EventDialogueCatalog.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_shorten.gd tests/test_shorten.gd.uid
git commit -m "feat(shorten): the saved switch and which dialogues it skips"
```

---

### Task 2: The Shorten panel

**Files:**
- Create: `Scripts/Lobby/ShortenPanel.gd` with `Write`; it is a new file that no editor tab holds
- Create: `Scenes/Lobby/ShortenPanel.tscn`, built in the editor
- Modify: `tests/test_shorten.gd`, `tests/test_confirm_pair_semantics.gd`

**Interfaces:**
- Consumes: `GameSettings.skip_event_dialogue` (Task 1).
- Produces (used by Task 3):
  - `signal closed`
  - `open() -> void`
  - `refresh() -> void`
  - `pick(skip: bool) -> void`
  - nodes `scrim`, `status_label`, `skip_button`, `keep_button`
  - exports `status_shown_text` and `status_skipped_text`

- [ ] **Step 1: Append the failing panel tests** to `tests/test_shorten.gd`

```gdscript
# ── the panel ────────────────────────────────────────────────────────────────

## Instantiated with the baked theme under the editor root, tracked for
## cleanup. Untyped: typed as Control, GDScript rejects the script members.
func _panel():
	var p = (load(_PANEL_SCENE) as PackedScene).instantiate()
	p.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func test_the_panel_offers_the_two_options_as_written() -> void:
	var p = _panel()
	assert_eq((p.get_node("Center/Card/Content/TitleLabel") as Label).text, "Shorten")
	assert_eq(p.skip_button.text, "Skip Dialog")
	assert_eq(p.keep_button.text, "Jangan Skip Dialog")
	assert_eq(p.skip_button.theme_type_variation, &"PrimaryButton", "an ordinary choice: one filled")
	assert_eq(p.keep_button.theme_type_variation, &"SecondaryButton", "and one quiet")


func test_skip_dialog_turns_shorten_on_and_closes() -> void:
	GameSettings.skip_event_dialogue = false
	var p = _panel()
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	p.skip_button.pressed.emit()
	assert_true(GameSettings.skip_event_dialogue, "Skip Dialog turns Shorten on")
	assert_true(closed[0], "and closes the panel")


func test_jangan_skip_dialog_turns_shorten_off_and_closes() -> void:
	GameSettings.skip_event_dialogue = true
	var p = _panel()
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	p.keep_button.pressed.emit()
	assert_false(GameSettings.skip_event_dialogue, "Jangan Skip Dialog turns Shorten off")
	assert_true(closed[0], "and closes the panel")


func test_the_status_line_follows_the_setting() -> void:
	GameSettings.skip_event_dialogue = true
	var p = _panel()
	assert_eq(p.status_label.text, "Sekarang: dialog minigame dilewati.")
	GameSettings.skip_event_dialogue = false
	p.refresh()
	assert_eq(p.status_label.text, "Sekarang: dialog minigame ditampilkan.")


func test_the_scrim_waits_for_the_open_then_closes_unchanged() -> void:
	GameSettings.skip_event_dialogue = true
	var p = _panel()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"popup-dismiss rule: the opening tap must not also close it")
	p.open()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_STOP, "after the open, the dim closes")
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	p._on_scrim_gui_input(tap)
	assert_true(closed[0], "tapping the dim closes the panel")
	assert_true(GameSettings.skip_event_dialogue, "without changing the setting")


func test_the_panel_is_authored_and_never_saves_from_the_editor() -> void:
	var src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_false(src.contains(".new("), "the panel is fully authored")
	assert_contains(src, "if not Engine.is_editor_hint():\n\t\tGameSettings.save_settings()",
		"tests must never write the real settings file")
	var scene := FileAccess.get_file_as_string(_PANEL_SCENE)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in ShortenPanel.tscn")
```

In `tests/test_confirm_pair_semantics.gd`, add `"res://Scenes/Lobby/ShortenPanel.tscn",` to `NON_DESTRUCTIVE_SCENES`.

- [ ] **Step 2: Run to see them fail**

`filesystem_manage(op="scan")`, then `test_run(suite="shorten")`. Expected: the six panel tests fail because the scene does not exist; the Task 1 tests still pass. `confirm_pair_semantics` fails because it cannot open the scene.

- [ ] **Step 3: Write the script**

`Scripts/Lobby/ShortenPanel.gd`:

```gdscript
@tool
extends Control

## The Lobby's Shorten panel (2026-09-14 shorten-dialog spec). Two options
## set GameSettings.skip_event_dialogue: Skip Dialog skips the line before
## each minigame, Jangan Skip Dialog keeps it. Tapping the dim background
## closes the panel unchanged. Every node is authored in ShortenPanel.tscn;
## the script only wires it, fills the status line and closes.

## Emitted once, when the panel closes for any reason.
signal closed

## Status line when the minigame lines are shown.
@export var status_shown_text: String = "Sekarang: dialog minigame ditampilkan."
## Status line when Shorten skips them.
@export var status_skipped_text: String = "Sekarang: dialog minigame dilewati."

@onready var scrim: Panel = $Scrim
@onready var card: PanelContainer = $Center/Card
@onready var status_label: Label = $Center/Card/Content/StatusLabel
@onready var skip_button: Button = $Center/Card/Content/SkipButton
@onready var keep_button: Button = $Center/Card/Content/KeepButton

var _is_closed := false


func _ready() -> void:
	skip_button.pressed.connect(pick.bind(true))
	keep_button.pressed.connect(pick.bind(false))
	scrim.gui_input.connect(_on_scrim_gui_input)
	refresh()


## Show the panel. The scrim starts at MOUSE_FILTER_IGNORE (the popup-dismiss
## rule) and only starts catching taps once the pop-in is done, so the tap
## that opened the panel can never also close it.
func open() -> void:
	refresh()
	if Engine.is_editor_hint() or not is_inside_tree():
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	AudioDirector.play_sfx(&"popup_open")
	Juice.pop_in(card)
	var arm := create_tween()
	arm.tween_interval(Juice.tokens().dur_normal)
	arm.tween_callback(func(): scrim.mouse_filter = Control.MOUSE_FILTER_STOP)


## Write the status line from the current setting.
func refresh() -> void:
	status_label.text = status_skipped_text if GameSettings.skip_event_dialogue else status_shown_text


## Turn Shorten on (true) or off (false), save it, and close.
func pick(skip: bool) -> void:
	GameSettings.skip_event_dialogue = skip
	if not Engine.is_editor_hint():
		GameSettings.save_settings()
	_close()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	if _is_closed:
		return
	_is_closed = true
	closed.emit()
	queue_free()
```

Then run `filesystem_manage(op="scan")`.

- [ ] **Step 4: Build the scene in the editor**

Run `scene_manage(op="create", params={"path": "res://Scenes/Lobby/ShortenPanel.tscn", "root_type": "Control", "root_name": "ShortenPanel"})`. Then call `batch_execute` with `create_node {type, name, parent_path}` and `set_property {path, property, value}`, creating the nodes in this order:

| Node (parent) | Type | Properties |
|---|---|---|
| root `/ShortenPanel` | Control | anchor_right 1, anchor_bottom 1, grow_horizontal 2, grow_vertical 2, mouse_filter 0 |
| Scrim (root) | Panel | layout_mode 1, anchor_right 1, anchor_bottom 1, mouse_filter 2, theme_type_variation "Scrim" |
| Center (root) | CenterContainer | layout_mode 1, anchor_right 1, anchor_bottom 1, mouse_filter 2 |
| Card (Center) | PanelContainer | theme_type_variation "Card", custom_minimum_size {x: 840, y: 0} |
| Content (Card) | VBoxContainer | mouse_filter 2, theme_override_constants/separation 32 |
| TitleLabel (Content) | Label | theme_type_variation "H2Label", text "Shorten", horizontal_alignment 1 |
| StatusLabel (Content) | Label | theme_type_variation "BodyLabel", text "Sekarang: dialog minigame ditampilkan.", horizontal_alignment 1, autowrap_mode 3 |
| SkipButton (Content) | Button | theme_type_variation "PrimaryButton", text "Skip Dialog" |
| KeepButton (Content) | Button | theme_type_variation "SecondaryButton", text "Jangan Skip Dialog" |

Last, attach `res://Scripts/Lobby/ShortenPanel.gd` to the root with `attach_script {path, script_path}`, then run `scene_save`. Check that `git diff HEAD -- '*.gd'` lists only this task's files.

- [ ] **Step 5: Run to see them pass**

`test_run(suite="shorten")`, `test_run(suite="confirm_pair_semantics")` and `test_run(suite="button_geometry")`. Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Lobby/ShortenPanel.gd Scripts/Lobby/ShortenPanel.gd.uid Scenes/Lobby/ShortenPanel.tscn tests/test_shorten.gd tests/test_confirm_pair_semantics.gd
git commit -m "feat(shorten): the Jangan Skip Dialog / Skip Dialog panel"
```

---

### Task 3: The Lobby button

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` in the editor, then `Scripts/Lobby/loby.gd` through `script_patch`
- Modify: `tests/test_shorten.gd`, `tests/test_lobby.gd`, `tests/test_lobby_layout.gd`

**Interfaces:**
- Consumes: `ShortenPanel.open()` (Task 2).
- Produces: node `ShortenButton`, `const SHORTEN_PANEL_SCENE`, `func _on_shorten_pressed()`.

- [ ] **Step 1: Append the failing Lobby tests** to `tests/test_shorten.gd`

```gdscript
# ── the Lobby button ─────────────────────────────────────────────────────────

## The source block of one node, from its header to the next section.
func _node_block(src: String, node_name: String) -> String:
	var start := src.find('[node name="%s" ' % node_name)
	if start == -1:
		return ""
	var end := src.find("\n[", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


func test_the_shorten_button_sits_on_the_money_row() -> void:
	var block := _node_block(FileAccess.get_file_as_string(_LOBBY_SCENE), "ShortenButton")
	assert_contains(block, 'type="Button" parent="."')
	assert_contains(block, 'theme_type_variation = &"SecondaryButton"')
	assert_contains(block, 'text = "Shorten"')
	assert_contains(block, "offset_top = 1392.0")
	assert_contains(block, "offset_bottom = 1488.0")
	var left := float(block.get_slice("offset_left = ", 1).get_slice("\n", 0))
	var right := float(block.get_slice("offset_right = ", 1).get_slice("\n", 0))
	assert_true(left > 144.0 and right < 700.0,
		"between the daily-login icon (..144) and the money chip (700..), got %f..%f" % [left, right])


func test_the_popups_draw_over_the_shorten_button() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCENE)
	var btn := src.find('[node name="ShortenButton" ')
	assert_true(btn != -1, "ShortenButton exists")
	assert_true(btn < src.find('[node name="DailyReward" '), "the reward popup covers it")
	assert_true(btn < src.find('[node name="ColorRect" '), "the tutorial overlay covers it")


func test_the_shorten_button_opens_the_panel() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	assert_contains(src, 'const SHORTEN_PANEL_SCENE := preload("res://Scenes/Lobby/ShortenPanel.tscn")')
	var wire := src.find("shorten_button.pressed.connect(_on_shorten_pressed)")
	var gate := src.find("if GameState.lobby_tutorial_completed or GameState.minggu_ke > 1:")
	assert_true(wire != -1 and wire < gate, "wired once, before the tutorial split")
	var body := _body(src, "_on_shorten_pressed")
	assert_contains(body, "SHORTEN_PANEL_SCENE.instantiate()")
	assert_contains(body, "add_child(panel)")
	assert_contains(body, "panel.open()")
```

In `tests/test_lobby.gd`, `test_interactive_controls_meet_the_minimum_touch_target`, after `paths.append("DailyReward/ButtonClaim")`, add `paths.append("ShortenButton")`.

In `tests/test_lobby_layout.gd`, `test_hud_does_not_sit_on_the_front_row_faces`, change `for name in ["DisplayUang", "DailyLogin"]:` to `for name in ["DisplayUang", "DailyLogin", "ShortenButton"]:`.

- [ ] **Step 2: Run to see them fail**

`filesystem_manage(op="scan")`, then `test_run(suite="shorten")`. Expected: the three Lobby tests fail. `lobby` and `lobby_layout` fail on the missing node.

- [ ] **Step 3: Add the button to loby.tscn** in the editor

1. `scene_open("res://Scenes/Lobby/loby.tscn")`.
2. `batch_execute`: `create_node {type: "Button", name: "ShortenButton", parent_path: "/Lobby"}`, then set these properties in this order: layout_mode 1, theme_type_variation "SecondaryButton", text "Shorten", offset_left 168, offset_top 1392, offset_right 408, offset_bottom 1488. The scene root's name is whatever `scene_get_hierarchy` reports; use it in the paths.
3. `node_manage(op="get_children")` on the root to find `DailyReward`'s index, then `node_manage(op="move", params={"path": ".../ShortenButton", "index": <DailyReward's index>})`, which places the button directly before it.
4. `scene_save`. Check that `git diff HEAD -- '*.gd'` is empty apart from this task's test files.

- [ ] **Step 4: Wire it in loby.gd** through `script_patch`

Read `Scripts/Lobby/loby.gd` lines 13–60 and 780–830 first for exact anchors.

1. After `const HAND_FALLBACK_NAME := "Doni"`, add:
```gdscript

## The Shorten popup (2026-09-14 shorten-dialog spec), instanced over the hub
## when ShortenButton is pressed. It frees itself when it closes.
const SHORTEN_PANEL_SCENE := preload("res://Scenes/Lobby/ShortenPanel.tscn")
```
2. After `@onready var inventory_button = $Inventory`, add `@onready var shorten_button = $ShortenButton`.
3. In the juice loop list, change `inventory_button, daily_login_btn, claim_button]` to `inventory_button, shorten_button, daily_login_btn, claim_button]`.
4. After `color_rect.mouse_filter = Control.MOUSE_FILTER_STOP`, add:
```gdscript

	if not shorten_button.pressed.is_connected(_on_shorten_pressed):
		shorten_button.pressed.connect(_on_shorten_pressed)
```
5. Before `func _on_student_pressed():`, add:
```gdscript
## Opens the Shorten panel over the hub.
func _on_shorten_pressed() -> void:
	var panel = SHORTEN_PANEL_SCENE.instantiate()
	add_child(panel)
	panel.open()


```

- [ ] **Step 5: Run to see them pass**

`test_run` on `shorten`, `lobby`, `lobby_layout`, `button_geometry`, `viewport_editability` and `script_documentation`. Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Lobby/loby.tscn Scripts/Lobby/loby.gd tests/test_shorten.gd tests/test_lobby.gd tests/test_lobby_layout.gd
git commit -m "feat(lobby): the Shorten button opens the dialogue-skip panel"
```

---

### Task 4: See it live, then write it down

**Files:**
- Modify: `CLAUDE.md` (the loop sentence) and `docs/superpowers/CHANGELOG.md` (a new top entry)

- [ ] **Step 1: The Lobby and the panel**

`project_run(mode="main", autosave=false)`. In `game_eval`, call DebugManager's `_seed_playtest_state()`, then `Transition.change_scene("res://Scenes/Lobby/loby.tscn")`, then wait 1.5 s. Take `editor_screenshot(source="game", max_resolution=0)`. Judge it at full size: the "Shorten" button sits on the money row, clear of the daily-login icon and the coins, and its text fits.

Next, in one `game_eval`, press the button through `get_viewport().push_input(ev, true)` at its rect's centre: a motion event, a press, then a release. Wait one frame, and return whether a `ShortenPanel` child exists and what its status text says. Take another screenshot.

Then press **Skip Dialog** the same way. Confirm that `GameSettings.skip_event_dialogue == true` and that the panel is gone.

- [ ] **Step 2: The skip in SchoolDay**

In `game_eval`:
1. `Transition.change_scene("res://Scenes/SchoolSimulation/SchoolDay.tscn")`, then wait 1.5 s and set `sd.is_skipped = true`.
2. `var skipped: bool = await sd._show_event_dialogue("MainBola")`. Expect `true` right away, with no `EventDialogue` child.
3. Call `sd._show_event_dialogue("nasi_kotak")` without awaiting it, wait one frame, and expect an `EventDialogue` child. Close it with two `tap()`s.

Finally turn Shorten off again through the panel's **Jangan Skip Dialog**, so the owner's settings file ends on the default. Then `project_manage(op="stop")`.

- [ ] **Step 3: Docs**

CLAUDE.md: after the sentence ending "…before their picker." in the loop paragraph, add: "The Lobby's **Shorten** button (`GameSettings.skip_event_dialogue`, saved) skips the minigame lines; Nasi Kotak, Hujan and the choice events keep theirs."

CHANGELOG: add a top entry, `## 2026-09-14 — Shorten: skip the minigame dialogue from the Lobby`. Cover what was built, the rule (`shorten_skips`), the setting and its save key, and the popup-dismiss detail.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git commit -m "docs(shorten): changelog and project guide"
```

---

### Task 5: Full suite

- [ ] **Step 1:** Run `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, then `test_run()`. Expected: all pass. Note the totals.
- [ ] **Step 2:** Check `git status`. If `kejartes_theme.tres` changed, compare it with the sub-resource IDs normalised. If the only difference is renumbering, restore it with `git checkout --`. Restore `default_bus_layout.tres` too if it changed.
- [ ] **Step 3:** Update CLAUDE.md's Testing count ("N suites, M tests (2026-09-14)") and commit it as `docs: suite count after Shorten`.
- [ ] **Step 4:** If the editor hung after the full run (`Responding: False`), restart it: kill only its PID, then relaunch.
