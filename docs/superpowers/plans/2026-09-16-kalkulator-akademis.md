# Kalkulator for Variabel and Password — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Re-skin the two number-entry Akademis minigames onto the artist's
calculator: desk background, Menjodohkan's question card, a drawn calculator
with a live LCD and keys that squish onto their skirt, and two Lobby-style
action buttons.

**Architecture:** Two new authored sub-scenes — `KalkulatorKey.tscn` (one key
cap, its own press animation) and `Kalkulator.tscn` (body texture + LCD + a
3x3 `GridContainer` of nine keys + a hideable wide `0`) — are instanced into
`Variabel.tscn` and `Password.tscn`. The two game scripts stop building
numpads with `Button.new()` and instead connect one `digit_pressed` signal.
Every visual is a node in a `.tscn`.

**Tech Stack:** Godot 4.6.2, GDScript, `@tool` scripts, the Godot AI MCP
bridge (`scene_open` / `node_create` / `node_set_property` / `scene_save` /
`script_patch` / `test_run`).

## Global Constraints

- **Worktree, and its own editor.** All work happens in
  `.claude/worktrees/kalkulator-akademis` on branch `feat/kalkulator-akademis`.
  Every MCP call passes `session_id="kalkulator-akademis@17ec"` — re-read it
  from `session_manage(op="list")` after any editor restart, and **never**
  call `session_activate`: other sessions share this server.
- **Never hand-edit a `.tscn`.** The editor is attached; its in-memory copy
  wins. Go through `scene_open` → `node_create` / `node_set_property` /
  `batch_execute` → `scene_save`. `anchors_preset` is inert (set the four
  anchors). Numbers are unquoted. A `Control` created under a plain `Control`
  starts in position mode — set `layout_mode = 1` before setting anchors.
- **Scene work first, script work second, within each task.** A `scene_save`
  flushes every open script tab over whatever was patched. After the last
  `scene_save` of a task, check `git diff HEAD -- '*.gd'` for files you were
  not editing.
- **Edit `.gd` through `script_patch`**, so the editor serves fresh bytecode
  to the next `test_run`. It matches bytes exactly.
- **No `theme_override_*`** except layout-only constants (`separation`,
  `margin_*`). The two action buttons use
  `theme_type_variation = &"LobbyCtaButton"`.
- **No emoji as UI iconography.**
- **UI text is Indonesian**; engine/systems code is English. The two buttons
  read `Hapus` and `Kirim`.
- **Every script needs a `##` file header and a `##` line on every `@export`**
  (`tests/test_script_documentation.gd`).
- **Test suites are `@tool`, extend `McpTestSuite`, and no test may be a
  coroutine** — the runner calls `suite.call(name)` without awaiting.
- **Prefer targeted `test_run(suite=...)`.** A full run drops the bridge;
  take it once, at Task 7, and restart the editor after it.
- The design is `docs/superpowers/specs/2026-09-16-kalkulator-akademis-design.md`.
  Re-read it when a geometry number is needed; every anchor fraction below is
  copied from its two tables.

---

### Task 1: `KalkulatorKey` — one key cap that squishes and darkens

**Files:**
- Create: `Scenes/Minigames/Akademis/KalkulatorKey.tscn`
- Create: `Scripts/Minigames/Akademis/KalkulatorKey.gd`
- Test: `tests/test_kalkulator.gd`

**Interfaces:**
- Produces: `KalkulatorKey` (a `Button`) with `@export var key_text: String`,
  `signal key_pressed(key_text: String)`, and child nodes named `Visual`,
  `Visual/Cap`, `Visual/Digit`. Task 2 instances it ten times.

- [ ] **Step 1: Write the failing test**

Create `tests/test_kalkulator.gd`:

```gdscript
@tool
extends McpTestSuite

## Scan and live checks for the 2026-09-16 calculator skin on the two
## number-entry Akademis minigames. Mostly source-text and asset-existence
## checks in the style of tests/test_minigame_art.gd, plus two live
## instantiation tests -- KalkulatorKey.tscn and Kalkulator.tscn have no
## autoload dependencies, so they can be built in-process.
##
## Must be @tool or the runner reports the class abstract/broken, and no
## test here may be a coroutine -- the runner calls suite.call(name)
## without awaiting.
## See docs/superpowers/specs/2026-09-16-kalkulator-akademis-design.md.

func suite_name() -> String:
	return "kalkulator"

const KEY_SCENE := "res://Scenes/Minigames/Akademis/KalkulatorKey.tscn"
const KEY_SCRIPT := "res://Scripts/Minigames/Akademis/KalkulatorKey.gd"
const CAP_TEXTURE := "res://Assets/Images/UI/Kalkulator/kalkulator_button.png"


func test_key_cap_texture_imports_as_texture2d() -> void:
	assert_true(ResourceLoader.exists(CAP_TEXTURE), "missing art: " + CAP_TEXTURE)
	assert_true(load(CAP_TEXTURE) as Texture2D != null,
		CAP_TEXTURE + " did not import as a Texture2D")


func test_key_scene_wires_the_cap_texture() -> void:
	var src := FileAccess.get_file_as_string(KEY_SCENE)
	assert_true(src.contains(CAP_TEXTURE), "KalkulatorKey.tscn must draw the cap art")


## The brief asked for "darkened and squished", so the press must move both
## scale and modulate. A scale-only tween is the generic UIPolish press and
## would not read as a key going down onto its skirt.
func test_key_press_squishes_and_darkens() -> void:
	var src := FileAccess.get_file_as_string(KEY_SCRIPT)
	assert_true(src.contains("button_down"), "the key animates on button_down")
	assert_true(src.contains("\"scale\""), "the press tweens scale (the squish)")
	assert_true(src.contains("\"modulate\""), "the press tweens modulate (the darken)")
	assert_true(src.contains("NO_AUTO_JUICE"),
		"the key opts out of UIPolish so there is only one press animation")


## User amendment 2026-09-16: key digits use the heading font, in white.
## DisplayLabel is on test_theme_factory's DISPLAY_ROSTER, so it is Boohong.
func test_key_digit_is_the_heading_font_in_white() -> void:
	var src := FileAccess.get_file_as_string(KEY_SCENE)
	assert_true(src.contains("theme_type_variation = &\"DisplayLabel\""),
		"the digit uses the heading face")
	assert_true(src.contains("theme_override_colors/font_color = Color(1, 1, 1, 1)"),
		"the digit is white")


func test_a_key_renders_its_digit_and_reports_it() -> void:
	var key := (load(KEY_SCENE) as PackedScene).instantiate()
	key.key_text = "7"
	var seen: Array[String] = []
	key.key_pressed.connect(func(t: String): seen.append(t))
	# _ready() is what copies key_text onto the Digit label.
	add_child(key)
	var digit := key.get_node("Visual/Digit") as Label
	assert_eq(digit.text, "7", "the key shows the digit it is configured with")
	key.emit_signal("pressed")
	assert_eq(seen, ["7"] as Array[String], "a press reports its own digit")
	key.queue_free()
```

Write it with the `Write` tool (it is a new file, so there is no stale editor
buffer to fight), then
`filesystem_manage(op="scan", session_id="kalkulator-akademis@17ec")`.

- [ ] **Step 2: Run it to make sure it fails**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`

Expected: FAIL — `KalkulatorKey.tscn` and `KalkulatorKey.gd` do not exist, so
`FileAccess.get_file_as_string` returns `""` and the `load()` returns null.

- [ ] **Step 3: Write the key script**

`script_create` (or `Write` + `scan`) `Scripts/Minigames/Akademis/KalkulatorKey.gd`:

```gdscript
@tool
extends Button

## One calculator key cap.
##
## The art (kalkulator_button.png) draws its own recessed skirt under the
## cap, so a press is animated as the cap squishing down ONTO that skirt --
## scale toward the bottom edge plus a darkening modulate -- rather than the
## uniform shrink UIPolish gives every other Button. Only the `Visual` child
## moves, so the Button's own hit rect never shifts under the finger.
##
## @tool so the editor shows the digit as authored. It has no _ready() side
## effects beyond its own visuals, so no Engine.is_editor_hint() guard is
## needed.

## Emitted on release, carrying this key's own character.
signal key_pressed(key_text: String)

## The character this key types. Also the label the cap shows.
@export var key_text: String = "1":
	set(value):
		key_text = value
		_sync_digit()

## Scale the cap squishes to while held. Wider than tall: a key going down
## bulges a little as it flattens.
@export var press_scale: Vector2 = Vector2(1.03, 0.88)

## Tint multiplied over the cap while held. Below 1 on every channel, so the
## key darkens rather than changing hue.
@export var press_tint: Color = Color(0.68, 0.68, 0.72, 1.0)

## Seconds the squish takes. Short: a key should feel instant.
@export var press_duration: float = 0.06

## Seconds the spring back takes. Longer than the squish, with TRANS_BACK.
@export var release_duration: float = 0.16

@onready var visual: Control = $Visual
@onready var digit_label: Label = $Visual/Digit

func _ready() -> void:
	_sync_digit()
	# One press animation, not two: UIPolish auto-juices every Button.
	set_meta(Juice.NO_AUTO_JUICE, true)
	if visual:
		visual.resized.connect(_park_pivot)
		_park_pivot()
	# Ungated on purpose: this is pure signal wiring with no side effects, and
	# the test runner lives inside the editor, where is_editor_hint() is true.
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(func(): key_pressed.emit(key_text))

## Puts the scale origin at the cap's bottom centre, so the squish presses
## the cap down onto its skirt instead of shrinking it toward its middle.
func _park_pivot() -> void:
	if is_instance_valid(visual):
		visual.pivot_offset = Vector2(visual.size.x * 0.5, visual.size.y)

func _sync_digit() -> void:
	var lbl := get_node_or_null("Visual/Digit") as Label
	if lbl:
		lbl.text = key_text

func _on_down() -> void:
	if not is_instance_valid(visual):
		return
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(visual, "scale", press_scale, press_duration)
	tw.tween_property(visual, "modulate", press_tint, press_duration)

func _on_up() -> void:
	if not is_instance_valid(visual):
		return
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", Vector2.ONE, release_duration)
	tw.tween_property(visual, "modulate", Color.WHITE, release_duration)
```

- [ ] **Step 4: Build the key scene through the editor**

```
scene_manage(op="create", params={"path": "res://Scenes/Minigames/Akademis/KalkulatorKey.tscn",
                                  "root_type": "Button", "root_name": "KalkulatorKey"},
             session_id="kalkulator-akademis@17ec")
```

Then one `batch_execute` (plugin command names, unquoted numbers):

- `set_property` on `/KalkulatorKey`: `flat = true`, `focus_mode = 0`,
  `mouse_default_cursor_shape = 2`, `custom_minimum_size = Vector2(180, 180)`.
- `attach_script` `res://Scripts/Minigames/Akademis/KalkulatorKey.gd`.
- `create_node` `Control` named `Visual` under `/KalkulatorKey`; then
  `set_property` `layout_mode = 1`, `anchor_left = 0`, `anchor_top = 0`,
  `anchor_right = 1`, `anchor_bottom = 1`, `mouse_filter = 2`.
- `create_node` `TextureRect` named `Cap` under `/KalkulatorKey/Visual`;
  `layout_mode = 1`, four anchors 0/0/1/1, `mouse_filter = 2`,
  `expand_mode = 1`, `stretch_mode = 0`,
  `texture = res://Assets/Images/UI/Kalkulator/kalkulator_button.png`.
- `create_node` `Label` named `Digit` under `/KalkulatorKey/Visual`;
  `layout_mode = 1`, four anchors 0/0/1/1, `mouse_filter = 2`,
  `horizontal_alignment = 1`, `vertical_alignment = 1`,
  `theme_type_variation = "DisplayLabel"`, `text = "1"`, and
  `theme_override_colors/font_color = Color(1, 1, 1, 1)` — the user's
  2026-09-16 amendment: the heading face (Boohong, which `DisplayLabel`
  carries per `DISPLAY_ROSTER`), coloured white. The cap is
  near-black, and CLAUDE.md puts minigames outside the design system, which is
  why `Menjodohkan.tscn` carries the same kind of override.

Then `scene_save(session_id=...)`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`
Expected: PASS, 5 tests.

If `test_a_key_renders_its_digit_and_reports_it` fails on the digit, the
`Digit` label is at the wrong path — check with
`scene_get_hierarchy`, not by reading the `.tscn` from disk.

- [ ] **Step 6: Check for collateral script writes and commit**

```bash
git diff HEAD --stat -- '*.gd'
```

Expect only `KalkulatorKey.gd` and `tests/test_kalkulator.gd`. Then:

```bash
git add Scenes/Minigames/Akademis/KalkulatorKey.tscn Scripts/Minigames/Akademis/KalkulatorKey.gd Scripts/Minigames/Akademis/KalkulatorKey.gd.uid tests/test_kalkulator.gd tests/test_kalkulator.gd.uid
git commit -F <message file>
```

Message: `feat(kalkulator): add the key cap that squishes onto its skirt`

---

### Task 2: `Kalkulator` — body, LCD and the key field

**Files:**
- Create: `Scenes/Minigames/Akademis/Kalkulator.tscn`
- Create: `Scripts/Minigames/Akademis/Kalkulator.gd`
- Modify: `tests/test_kalkulator.gd`

**Interfaces:**
- Consumes: `KalkulatorKey` from Task 1 (`key_text`, `key_pressed`).
- Produces: `Kalkulator` (an `AspectRatioContainer`) with
  `signal digit_pressed(digit: String)`,
  `@export var show_zero_key: bool`,
  `func set_layar(text: String) -> void`,
  `func set_layar_color(c: Color) -> void`,
  `func set_keys_disabled(disabled: bool) -> void`.
  Tasks 3 and 4 instance it and call exactly these.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_kalkulator.gd`:

```gdscript
const KALK_SCENE := "res://Scenes/Minigames/Akademis/Kalkulator.tscn"
const BODY_TEXTURE := "res://Assets/Images/UI/Kalkulator/kalkulator_base.png"


func test_body_texture_imports_as_texture2d() -> void:
	assert_true(ResourceLoader.exists(BODY_TEXTURE), "missing art: " + BODY_TEXTURE)
	assert_true(load(BODY_TEXTURE) as Texture2D != null,
		BODY_TEXTURE + " did not import as a Texture2D")


func test_kalkulator_instances_ten_authored_keys() -> void:
	var src := FileAccess.get_file_as_string(KALK_SCENE)
	assert_eq(src.count("instance=ExtResource"), 10,
		"nine digit keys plus the wide zero, all authored -- none built at runtime")
	assert_true(src.contains(BODY_TEXTURE), "Kalkulator.tscn must draw the body art")


## Guards the mapping, not mere presence: a transposed 3 and 7 leaves every
## key_text still in the file.
func test_every_digit_zero_to_nine_has_exactly_one_key() -> void:
	var kalk = _live(KALK_SCENE)
	var seen: Array[String] = []
	for key in kalk.find_children("*", "Button", true, false):
		seen.append(str(key.key_text))
	seen.sort()
	assert_eq(seen, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] as Array[String],
		"exactly one key per digit")


func test_hiding_the_zero_key_hides_only_that_row() -> void:
	var kalk = _live(KALK_SCENE)
	kalk.show_zero_key = false
	assert_false(kalk.get_node("Body/ZeroRow").visible, "Variabel needs no zero")
	assert_true(kalk.get_node("Body/KeyGrid").visible, "the 1-9 grid always shows")
	kalk.show_zero_key = true
	assert_true(kalk.get_node("Body/ZeroRow").visible, "Password needs the zero back")


func test_a_key_press_reaches_the_kalkulator_as_a_digit() -> void:
	var kalk = _live(KALK_SCENE)
	var seen: Array[String] = []
	kalk.digit_pressed.connect(func(d: String): seen.append(d))
	kalk.get_node("Body/KeyGrid/Key5").emit_signal("pressed")
	assert_eq(seen, ["5"] as Array[String], "the key's digit relays out of the calculator")


func test_disabling_the_keys_disables_every_one() -> void:
	var kalk = _live(KALK_SCENE)
	kalk.set_keys_disabled(true)
	for key in kalk.find_children("*", "Button", true, false):
		assert_true(key.disabled, "%s must lock while an answer is being judged" % key.name)
	kalk.set_keys_disabled(false)
	assert_false((kalk.get_node("Body/KeyGrid/Key1") as Button).disabled, "and unlock after")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`
Expected: FAIL — `Kalkulator.tscn` does not exist.

- [ ] **Step 3: Write the calculator script**

`Scripts/Minigames/Akademis/Kalkulator.gd`:

```gdscript
@tool
extends AspectRatioContainer

## The drawn calculator: body art, a live LCD, and an authored key field.
##
## The root is an AspectRatioContainer at the body texture's own ratio, so
## the calculator keeps the artwork's proportions and centres itself in
## whatever slot the game scene gives it -- including the taller slot a 20:9
## phone produces.
##
## Every key is an authored KalkulatorKey.tscn instance. Nothing here is
## built at runtime; the script only relays presses and toggles state.
##
## @tool so show_zero_key previews in the editor. Its _ready() touches only
## its own visuals, so no Engine.is_editor_hint() guard is needed.

## Emitted when any key is pressed, carrying that key's character.
signal digit_pressed(digit: String)

## Shows the wide 0 key under the 1-9 grid. Password's answers run to three
## digits and need it; Variabel's are always 1-9 and it stays hidden there,
## leaving the plain body space the mockup draws.
@export var show_zero_key: bool = true:
	set(value):
		show_zero_key = value
		var row := get_node_or_null("Body/ZeroRow") as Control
		if row:
			row.visible = value

## What the LCD reads before the player types anything.
@export var layar_placeholder: String = "0"

## Colour of the digits on the green LCD. Dark, so they read like a real
## segment display rather than glowing.
@export var layar_color: Color = Color(0.13, 0.16, 0.12, 1.0)

@onready var layar: Label = $Body/Layar

func _ready() -> void:
	show_zero_key = show_zero_key
	if layar:
		layar.add_theme_color_override("font_color", layar_color)
		layar.text = layar_placeholder
	for key in _keys():
		# By name: the loop variable is typed Node, which has no key_pressed.
		key.connect("key_pressed", func(d: String): digit_pressed.emit(d))

## Every authored key, in tree order.
func _keys() -> Array[Node]:
	return find_children("*", "Button", true, false)

## Shows `text` on the LCD, or the placeholder when it is empty.
func set_layar(text: String) -> void:
	if layar:
		layar.text = text if text != "" else layar_placeholder

## Recolours the LCD digits -- green on a correct answer, red on a wrong one.
func set_layar_color(c: Color) -> void:
	if layar:
		layar.add_theme_color_override("font_color", c)

## Restores the LCD's authored digit colour.
func reset_layar_color() -> void:
	set_layar_color(layar_color)

## Locks or unlocks every key at once, while an answer is being judged.
func set_keys_disabled(disabled: bool) -> void:
	for key in _keys():
		(key as Button).disabled = disabled
```

`add_theme_color_override` on a Label is a runtime colour change on a
minigame screen, which CLAUDE.md puts outside the design system — the same
thing `Password.gd` and `Variabel.gd` already do for correct/error tints.

- [ ] **Step 4: Build the calculator scene through the editor**

`scene_manage(op="create", …)` with `root_type = "AspectRatioContainer"`,
`root_name = "Kalkulator"`. Then, in `batch_execute` batches:

Root: `ratio = 0.7263`, `stretch_mode = 2` (FIT), `alignment_horizontal = 1`,
`alignment_vertical = 1`; `attach_script` `Kalkulator.gd`.

`Body` (`Control` under `/Kalkulator`): `layout_mode = 1`, anchors
0 / 0 / 1 / 1, `mouse_filter = 2`.

`Body/BodyTexture` (`TextureRect`): `layout_mode = 1`, anchors 0 / 0 / 1 / 1,
`mouse_filter = 2`, `expand_mode = 1`, `stretch_mode = 0`,
`texture = res://Assets/Images/UI/Kalkulator/kalkulator_base.png`.

`Body/Layar` (`Label`): `layout_mode = 1`, `anchor_left = 0.0968`,
`anchor_top = 0.0943`, `anchor_right = 0.9028`, `anchor_bottom = 0.274`,
`offset_left = 28`, `offset_right = -28`, `offset_top = 0`,
`offset_bottom = 0`, `mouse_filter = 2`, `horizontal_alignment = 2` (right),
`vertical_alignment = 1`, `theme_type_variation = "DisplayLabel"`,
`clip_text = true`, `text = "0"`.

`Body/KeyGrid` (`GridContainer`): `layout_mode = 1`, `anchor_left = 0.1242`,
`anchor_top = 0.2896`, `anchor_right = 0.856`, `anchor_bottom = 0.8188`,
all four offsets 0, `columns = 3`,
`theme_override_constants/h_separation = 6`,
`theme_override_constants/v_separation = 6`.

Nine `add_scene` / `create_node` instances of
`res://Scenes/Minigames/Akademis/KalkulatorKey.tscn` under `Body/KeyGrid`,
named `Key1` … `Key9` in that order (a `GridContainer` fills left-to-right,
top-to-bottom, so tree order is reading order). On each **root**:
`size_flags_horizontal = 3`, `size_flags_vertical = 3`, `key_text = "1"` …
`"9"`, and `custom_minimum_size = Vector2(0, 0)` so the grid's own sizing
wins. Overrides on an instance's *children* are dropped on save — set
nothing below the root.

`Body/ZeroRow` (`HBoxContainer`): `layout_mode = 1`, `anchor_left = 0.1242`,
`anchor_top = 0.8245`, `anchor_right = 0.856`, `anchor_bottom = 0.9971`,
all four offsets 0, `alignment = 1` (centre).

One more `KalkulatorKey.tscn` instance under `Body/ZeroRow` named `Key0`:
`key_text = "0"`, `custom_minimum_size = Vector2(274, 0)`,
`size_flags_vertical = 3`.

`scene_save(session_id=...)`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`
Expected: PASS, 11 tests.

`test_kalkulator_instances_ten_authored_keys` counts
`instance=ExtResource` lines; if it reads 11 the body texture was instanced
as a scene rather than set as a texture.

- [ ] **Step 6: Look at it**

```
scene_open("res://Scenes/Minigames/Akademis/Kalkulator.tscn", session_id=...)
editor_screenshot(session_id=...)
```

Judge at full size: the nine caps should sit inside the body with even
gutters, and the LCD label should sit inside the green field, not over its
bezel. Fix anchors through `node_set_property` + `scene_save` if not.

- [ ] **Step 7: Commit**

```bash
git diff HEAD --stat -- '*.gd'
git add Scenes/Minigames/Akademis/Kalkulator.tscn Scripts/Minigames/Akademis/Kalkulator.gd Scripts/Minigames/Akademis/Kalkulator.gd.uid tests/test_kalkulator.gd
git commit -F <message file>
```

Message: `feat(kalkulator): add the calculator body, LCD and key field`

---

### Task 3: Rebuild `Variabel.tscn` on the calculator

**Files:**
- Modify: `Scenes/Minigames/Akademis/Variabel.tscn`
- Modify: `Scripts/Minigames/Akademis/Variabel.gd`
- Modify: `tests/test_kalkulator.gd`

**Interfaces:**
- Consumes: `Kalkulator` from Task 2 (`digit_pressed`, `show_zero_key`,
  `set_layar`, `set_layar_color`, `reset_layar_color`, `set_keys_disabled`).
- Produces: the node layout Task 4 copies for Password —
  `Background`, `HeaderRow/ScoreHUD`, `SoalCard`, `KalkulatorSlot/Kalkulator`,
  `AksiRow/BtnHapus`, `AksiRow/BtnKirim`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_kalkulator.gd`:

```gdscript
const MEJA := "res://Assets/Images/UI/meja_background.png"
const CARD_SCENE := "res://Scenes/Minigames/Akademis/QuestionCard.tscn"

## Every placeholder these two scenes used to draw. Password rendered a
## badminton court over the desk because its background_texture export
## pointed at one and _apply_visual_exports() applies it at runtime.
const _STALE_ART := ["lapanganBadminton", "KiperLeft", "DiagonalLeft", "DiagonalRight"]


func test_variabel_sits_on_the_desk() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Variabel.tscn")
	assert_true(src.contains(MEJA), "Variabel.tscn must draw meja_background, like Menjodohkan")
	for stale in _STALE_ART:
		assert_false(src.contains(stale), "Variabel.tscn still references " + stale)


func test_variabel_uses_the_shared_calculator_and_question_card() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Variabel.tscn")
	assert_true(src.contains(KALK_SCENE), "Variabel.tscn instances the calculator")
	assert_true(src.contains(CARD_SCENE), "the white paper is Menjodohkan's QuestionCard")
	assert_true(src.contains("show_zero_key = false"),
		"Variabel's answers are always 1-9, so its zero key stays hidden")


func test_variabel_action_buttons_use_the_lobby_design() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Variabel.tscn")
	assert_eq(src.count("theme_type_variation = &\"LobbyCtaButton\""), 2,
		"Hapus and Kirim both wear the Lobby CTA design")
	assert_true(src.contains("text = \"Hapus\""), "clear reads Hapus, not CLear")
	assert_true(src.contains("text = \"Kirim\""), "submit reads Kirim, not submit")


func test_variabel_builds_no_numpad_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/Variabel.gd")
	assert_false(src.contains("Button.new("), "the keys are authored nodes now")
	assert_false(src.contains("HBoxContainer.new("), "so is the zero row")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`
Expected: FAIL — four new failures; the scene still has `DiagonalLeft` and a
`VBoxContainer`, and the script still calls `Button.new(`.

- [ ] **Step 3: Rebuild the scene through the editor**

`scene_open("res://Scenes/Minigames/Akademis/Variabel.tscn", session_id=...)`.

Delete `VBoxContainer` **except** the `ScoreHUD` inside it — easier to
`delete_node` the whole `VBoxContainer` and add a fresh `MinigameScoreHUD.tscn`
instance, since `tests/test_minigame_score_hud.gd` only requires the scene to
instance that PackedScene.

Then build, all with `layout_mode = 1` and explicit anchors (`anchors_preset`
is inert):

| Node | type / scene | anchors L,T,R,B |
|---|---|---|
| `Background` | keep the existing `TextureRect` | 0,0,1,1 — set `texture` = `res://Assets/Images/UI/meja_background.png`, `expand_mode = 1`, `stretch_mode = 6` |
| `HeaderRow` | `HBoxContainer`, `alignment = 1`, `mouse_filter = 2` | 0.25, 0.0146, 0.75, 0.0875 |
| `HeaderRow/ScoreHUD` | instance `res://Scenes/Minigames/UI/MinigameScoreHUD.tscn` | `size_flags_horizontal = 4` |
| `SoalCard` | instance `res://Scenes/Minigames/Akademis/QuestionCard.tscn` | 0.1685, 0.0938, 0.8306, 0.2734, offsets 0 |
| `KalkulatorSlot` | `Control`, `mouse_filter = 2` | 0, 0.2896, 1, 0.8328 |
| `KalkulatorSlot/Kalkulator` | instance `res://Scenes/Minigames/Akademis/Kalkulator.tscn` | 0,0,1,1, offsets 0, `show_zero_key = false` |
| `AksiRow` | `HBoxContainer`, `theme_override_constants/separation = 76` | 0.0778, 0.8635, 0.9333, 0.9448 |
| `AksiRow/BtnHapus` | `Button`, `theme_type_variation = "LobbyCtaButton"`, `text = "Hapus"`, `size_flags_horizontal = 3` | — |
| `AksiRow/BtnKirim` | `Button`, `theme_type_variation = "LobbyCtaButton"`, `text = "Kirim"`, `size_flags_horizontal = 3` | — |

Root `Variabel`: clear the now-dead `numpad_btn_normal_texture` and
`submit_btn_normal_texture` exports, and set
`background_texture = res://Assets/Images/UI/meja_background.png`.

`node_create` appends last, so after adding everything, `move_node`
`Background` to index 0.

`scene_save(session_id=...)`.

- [ ] **Step 4: Rewrite the script (after the save, never before)**

Through `script_patch` on `Scripts/Minigames/Akademis/Variabel.gd`:

Delete the `Visual - Input Box` and `Visual - Numpad` `@export_group`s
entirely (`input_box_texture`, `input_box_min_height`,
`input_box_texture_margin`, `input_box_font_color`, `input_box_placeholder`,
`input_box_placeholder_color`, `numpad_btn_size`, `clear_btn_height`,
`numpad_btn_normal_texture`, `submit_btn_normal_texture`,
`numpad_btn_pressed_tint`, `numpad_btn_disabled_tint`,
`numpad_btn_press_scale`, `numpad_btn_press_duration`,
`numpad_btn_texture_margin`), and the functions `_setup_numpad`,
`_apply_keypad_btn_textures`, `_apply_button_texture_override`,
`_on_numpad_btn_down`, `_on_numpad_btn_up`, `_make_btn_stylebox`, and the
`numpad_bottom_row` var.

Replace the `@onready` block with:

```gdscript
@onready var score_hud: MinigameScoreHUD = $HeaderRow/ScoreHUD
@onready var progress_label: Label       = $SoalCard/StatusBadge/BadgeLabel
@onready var equation_label: Label       = $SoalCard/VBox/TextLabel
@onready var kalkulator: Control         = $KalkulatorSlot/Kalkulator
@onready var clear_button: Button        = $AksiRow/BtnHapus
@onready var submit_button: Button       = $AksiRow/BtnKirim
```

`_ready()` becomes:

```gdscript
func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if kalkulator:
		kalkulator.digit_pressed.connect(_on_numpad_pressed)
```

Then, everywhere the old code touched `input_line_edit`:

- `input_line_edit.text += num_str` → keep the entry in a new
  `var typed_answer: String = ""`, append there, then
  `kalkulator.set_layar(typed_answer)`.
- `input_line_edit.text = ""` → `typed_answer = ""`,
  `kalkulator.set_layar("")`, `kalkulator.reset_layar_color()`.
- `input_line_edit.text.to_int()` → `typed_answer.to_int()`.
- the correct / error / reveal colour overrides →
  `kalkulator.set_layar_color(correct_color / error_color / reveal_color)`.
- `input_line_edit.text = "Jawaban: %d"` → `kalkulator.set_layar(str(expected_answer))`.
- `_set_numpad_disabled(d)` → `kalkulator.set_keys_disabled(d)`.
- `_play_jump_animation(input_line_edit)` → `_play_jump_animation(kalkulator)`.
- `_show_time_boost_popup()`'s `start_pos` falls back to
  `kalkulator.global_position + Vector2(kalkulator.size.x * 0.5, 0.0)`.

`progress_label.text` becomes `"Soal %d/%d" % [current_question_index + 1,
active_questions.size()]` — the score is already in the HUD, and the badge is
a narrow pill.

Add the question-text ladder to `_show_current_question()`, sized for the
715x345 card:

```gdscript
	if equation_label:
		equation_label.text = q_data["eq_text"]
		equation_label.remove_theme_color_override("font_color")
		equation_label.add_theme_font_size_override("font_size",
			_fit_font_size(q_data["eq_text"]))
```

```gdscript
## Font size that keeps a question inside the 715x345 SoalCard. The card is
## shorter than Menjodohkan's 850x480 wheel card, and Variabel's equation
## blocks are the longest text either quiz shows -- four lines, then five
## more once the variable reveal appends its values.
func _fit_font_size(text: String) -> int:
	var lines := text.split("\n").size()
	if lines <= 2:
		return equation_font_size
	elif lines <= 4:
		return 52
	elif lines <= 6:
		return 44
	return 36
```

and drop `equation_font_size`'s default from 72 to 64.

`_show_variable_reveal()` re-runs `_fit_font_size` on the appended text, so
the reveal does not overflow what the question fit.

`reveal_answers()` loses its `input_line_edit.editable = false`.

- [ ] **Step 5: Run the tests**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`
Expected: PASS.

Then the two suites that also read these files:

Run: `test_run(suite="minigame_score_hud", session_id=...)` — expect PASS
Run: `test_run(suite="script_documentation", session_id=...)` — expect PASS

- [ ] **Step 6: Look at it**

`scene_open` Variabel, `editor_screenshot`, judged at full size. Then run it:
`project_run` and use the debug overlay's minigame launcher to open Variabel,
checking that a key visibly squishes and darkens under a press, the LCD shows
what was typed, and no equation is clipped.

- [ ] **Step 7: Commit**

```bash
git diff HEAD --stat -- '*.gd'
git add Scenes/Minigames/Akademis/Variabel.tscn Scripts/Minigames/Akademis/Variabel.gd tests/test_kalkulator.gd
git commit -F <message file>
```

Message: `feat(variabel): put the quiz on the desk and the calculator`

---

### Task 4: Rebuild `Password.tscn` on the calculator

**Files:**
- Modify: `Scenes/Minigames/Akademis/Password.tscn`
- Modify: `Scripts/Minigames/Akademis/Password.gd`
- Modify: `tests/test_kalkulator.gd`

**Interfaces:**
- Consumes: everything Task 3 produced. Password's layout is identical except
  `show_zero_key` stays `true`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_kalkulator.gd`:

```gdscript
func test_password_sits_on_the_desk() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Password.tscn")
	assert_true(src.contains(MEJA), "Password.tscn must draw meja_background")
	for stale in _STALE_ART:
		assert_false(src.contains(stale), "Password.tscn still references " + stale)


## The regression this pass fixes: background_texture pointed at a badminton
## court, and _apply_visual_exports() paints it over the desk at runtime, so
## the Background node's own texture was never what the player saw.
func test_password_background_export_matches_its_background_node() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Password.tscn")
	var line := ""
	for raw in src.split("\n"):
		if raw.begins_with("background_texture = "):
			line = raw
	assert_true(line != "", "Password.tscn still sets a background_texture export")
	var id := line.split("\"")[1]
	var meja_id := ""
	for raw in src.split("\n"):
		if raw.begins_with("[ext_resource") and raw.contains(MEJA):
			meja_id = raw.split("id=\"")[1].split("\"")[0]
	assert_eq(id, meja_id, "the export must point at the same desk the node draws")


func test_password_uses_the_shared_calculator_and_question_card() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Password.tscn")
	assert_true(src.contains(KALK_SCENE), "Password.tscn instances the calculator")
	assert_true(src.contains(CARD_SCENE), "the white paper is Menjodohkan's QuestionCard")
	assert_false(src.contains("show_zero_key = false"),
		"Password's answers run to three digits, so it keeps the zero key")


func test_password_action_buttons_use_the_lobby_design() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Password.tscn")
	assert_eq(src.count("theme_type_variation = &\"LobbyCtaButton\""), 2,
		"Hapus and Kirim both wear the Lobby CTA design")
	assert_true(src.contains("text = \"Hapus\""), "clear reads Hapus")
	assert_true(src.contains("text = \"Kirim\""), "submit reads Kirim")


func test_password_builds_no_keypad_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/Password.gd")
	assert_false(src.contains("Button.new("), "the keys are authored nodes now")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `test_run(suite="kalkulator", session_id="kalkulator-akademis@17ec")`
Expected: FAIL — five new failures.

- [ ] **Step 3: Rebuild the scene**

Identical to Task 3's Step 3, on `Password.tscn`, with these differences:

- `KalkulatorSlot/Kalkulator` leaves `show_zero_key` at its `true` default
  (do not set the property at all, so the test's `assert_false(... "show_zero_key = false")`
  holds).
- The root's `background_texture` export changes from `lapanganBadminton.jpg`
  to `res://Assets/Images/UI/meja_background.png`, and
  `keypad_btn_normal_texture` is cleared.
- `tutorial_title` and `tutorial_instructions` stay as authored.

`scene_save(session_id=...)`.

- [ ] **Step 4: Rewrite the script**

Through `script_patch` on `Scripts/Minigames/Akademis/Password.gd`. Same
deletions as Task 3: the `Visual - Input Box` and `Visual - Keypad`
`@export_group`s, `_setup_keypad`, `_apply_keypad_btn_textures`,
`_on_keypad_btn_down`, `_on_keypad_btn_up`, `_make_btn_stylebox`.

```gdscript
@onready var score_hud: MinigameScoreHUD = $HeaderRow/ScoreHUD
@onready var progress_label: Label       = $SoalCard/StatusBadge/BadgeLabel
@onready var problem_label: Label        = $SoalCard/VBox/TextLabel
@onready var kalkulator: Control         = $KalkulatorSlot/Kalkulator
@onready var clear_button: Button        = $AksiRow/BtnHapus
@onready var submit_button: Button       = $AksiRow/BtnKirim
```

```gdscript
func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()
	if submit_button:
		submit_button.pressed.connect(_on_enter_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if kalkulator:
		kalkulator.digit_pressed.connect(_on_keypad_pressed)
```

`input_label` becomes the same `typed_answer: String` + `kalkulator.set_layar()`
pair as Task 3, with the same colour calls. Fit `problem_label` through the
shared `SoalFit.font_size()` exactly as `Variabel.gd` does after Task 3
(`const SoalFit := preload(...)`, `_fit_font_size()`, `_refit_equation` on
`resized`) — its one-line sums keep the full size. (Task 3 replaced the
line-count ladder with this measured fit after it clipped on playtest.)
`progress_label.text` becomes `"Soal %d/%d"`.

The old in-grid `Enter` and `C` keys are gone; `_on_enter_pressed` and
`_on_clear_pressed` keep their names and are now driven by the two action
buttons.

- [ ] **Step 5: Run the tests**

Run: `test_run(suite="kalkulator", session_id=...)` — expect PASS
Run: `test_run(suite="minigame_score_hud", session_id=...)` — expect PASS
Run: `test_run(suite="minigame_star_rubric", session_id=...)` — expect PASS
Run: `test_run(suite="script_documentation", session_id=...)` — expect PASS

- [ ] **Step 6: Look at it**

`scene_open` Password, `editor_screenshot` at full size. Confirm the wide `0`
sits centred under the grid and inside the body, and that a three-digit entry
(`198`) fits the LCD without clipping.

- [ ] **Step 7: Commit**

```bash
git diff HEAD --stat -- '*.gd'
git add Scenes/Minigames/Akademis/Password.tscn Scripts/Minigames/Akademis/Password.gd tests/test_kalkulator.gd
git commit -F <message file>
```

Message: `feat(password): put the quiz on the desk and the calculator`

---

### Task 5: Turn the runtime-construction ratchet

**Files:**
- Modify: `tests/test_viewport_editability.gd:69-71`

**Interfaces:**
- Consumes: the two rewritten scripts from Tasks 3 and 4.

- [ ] **Step 1: Run the ratchet and read what it prints**

Run: `test_run(suite="viewport_editability", session_id="kalkulator-akademis@17ec")`

Expected: FAIL. The suite's second test detects that `Password.gd` and
`Variabel.gd` now build fewer visuals than `BASELINE` freezes, and prints the
exact literal to paste back.

- [ ] **Step 2: Paste the printed literal**

`script_patch` `tests/test_viewport_editability.gd`, replacing

```gdscript
	"res://Scripts/Minigames/Akademis/Password.gd": 4,
	"res://Scripts/Minigames/Akademis/Variabel.gd": 4,
```

with whatever the suite printed — expected to be

```gdscript
	"res://Scripts/Minigames/Akademis/Variabel.gd": 1,
```

(`Password.gd` drops to zero and leaves `BASELINE`; `Variabel.gd` keeps the
one `Label.new()` that spawns the floating `+20s` popup). Use the printed
numbers, not these, if they differ.

- [ ] **Step 3: Run it to verify it passes**

Run: `test_run(suite="viewport_editability", session_id=...)`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/test_viewport_editability.gd
git commit -F <message file>
```

Message: `test(viewport): lower the ratchet for the two calculator quizzes`

---

### Task 6: Record the pass

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`
- Modify: `docs/superpowers/DEBT.md` (only if a rung or an asset is left owing)

- [ ] **Step 1: Add the changelog entry**

Newest first, in the file's established shape: what the two screens look like
now, that the calculator is a shared `Kalkulator.tscn` + `KalkulatorKey.tscn`,
that Password's background export was painting a badminton court over the
desk, and the two texture downscales (7458x10265 → 1080x1487,
1716x1620 → 360x340).

- [ ] **Step 2: Add a DEBT entry only if something is owed**

If the `_fit_font_size` rungs were tuned by eye against a screenshot and a
longer question could still clip, add one line under the existing minigame
grouping. If nothing is owed, change nothing — an empty entry is worse than
no entry.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/DEBT.md
git commit -F <message file>
```

Message: `docs(kalkulator): record the calculator pass`

---

### Task 7: Full suite, and clean the tree

**Files:** none — verification only.

- [ ] **Step 1: Run the whole suite**

Run: `test_run(session_id="kalkulator-akademis@17ec")`

Expected: every suite green. Budget one editor restart after this — a full run
is 15-20 s of main-thread work and the bridge does not survive it. The
results are still valid once the reply arrives.

- [ ] **Step 2: Fix any real breakage, then re-run only the suites you touched**

A failing theme assertion in a full run may just be suite ordering
(`theme_rebake` saves the theme mid-run). Re-run that suite alone before
believing it.

- [ ] **Step 3: Revert the editor's incidental writes**

A full run rebakes `Assets/Theme/kejartes_theme.tres`; `AudioDirector`
rewrites `Assets/Audio/default_bus_layout.tres` on every boot; and this
worktree's editor also rewrites twelve portrait/splash `*.png.import` files,
dropping `etc2_astc`. Stop the worktree editor first (it rewrites them again
on reimport), then:

```bash
git status --porcelain
git checkout -- Assets/Audio/default_bus_layout.tres
git checkout -- Assets/Images/MuridPotrait Assets/Images/SplashArtMurid
```

Keep the theme rebake only if a token actually changed — it did not in this
pass, so revert it too. `addons/godot_ai/utils/update_activation_runner.gd`
is the plugin's own untracked file; leave it untracked, do not commit it.

- [ ] **Step 4: Confirm the tree is clean and the branch is right**

```bash
git branch --show-current
git status --porcelain --untracked-files=no
git log --oneline origin/Textures..HEAD
```

Expect `feat/kalkulator-akademis`, empty porcelain, and six commits.
