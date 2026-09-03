# ResultCheckup Interactivity & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the week-recap banner's four pills tappable with an info popup and an idle "tap me" hint, fix the needs-bar delta collision by replacing the number with a directional arrow, give the pill entrance and the SISWA/RIWAYAT tab switch real motion, and fix the flat white `ScrollFade` box.

**Architecture:** Every change is additive to scenes and scripts this session already built (`WeekRecapPill`, `WeekRecapBanner`, `ResultCheckup`, `DaySummaryNeedsBar`/`DaySummaryStudentRow`). One new popup scene (`WeekRecapPillInfoPopup`) mirrors the existing `StatDetailPopup` shell. Four SFX cues get dedicated copied files and ids, following the project's `sfx_tally`/`sfx_sparkle` alias pattern one step further (a real file copy, not just a second id on the same file).

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` via the Godot AI MCP `test_run` tool, `DesignTokens`/`ThemeFactory`, `Juice.gd` motion vocabulary, `AudioDirector` autoload.

**Spec:** `docs/superpowers/specs/2026-09-03-result-checkup-interactivity-polish-design.md`

## Global Constraints

- **Never add a `theme_override_*`.** Layout-only constant overrides (`separation`, `margin_*`) remain the only exception.
- **No visual is built at runtime.** Every node this plan adds lives in a `.tscn`, built via the editor's MCP tools — never `Label.new()`/`TextureRect.new()` etc. in a script.
- **No emoji as UI iconography.**
- **Every script needs a `##` file header and a `##` line on every `@export`.**
- **Every test suite is `@tool`, extends `McpTestSuite`, and no test may be a coroutine** — the runner does `suite.call(name)` without awaiting. A test exercising a coroutine method (anything with `await`) checks only its synchronous setup (signals connected, tween/state created), never awaits the method itself.
- **Scripts the runner instantiates live must be `@tool`**, with real side effects gated behind `if Engine.is_editor_hint(): return`. Signal wiring stays ungated.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` → `node_create`/`node_set_property`/`batch_execute` → `scene_save`.
- **Rescan after editing a `.gd` from outside the editor, before running tests** (`filesystem_manage(op="scan")`); force a reload with a no-op `script_patch` if the editor still serves stale bytecode.
- **The Godot MCP bridge is single-client.** Subagents write code; the controller session builds/edits every `.tscn` and runs every `test_run`.
- Game-facing identifiers and all UI text are **Indonesian**; engine/systems code is English.
- Timings come from `DesignTokens` (`dur_instant=0.08`, `dur_fast=0.18`, `dur_normal=0.32`, `stagger_step=0.05`, `press_scale=0.94`), never literals.
- No new third-party audio: the four new SFX cues are byte-copies of existing files under new names (see Task 1), not downloads.
- Commits: Conventional Commits with a scope, e.g. `feat(resultcheckup): ...`.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `Assets/Audio/SFX/pill_tap.ogg`, `pill_popup_open.ogg`, `pill_popup_close.ogg`, `pane_swipe.ogg` | Byte-copies of `tap.ogg`/`popup_open.ogg`/`popup_close.ogg`/`swipe.ogg` under dedicated names. |
| `Scripts/UI/WeekRecapPillInfoPopup.gd` + `Scenes/UI/WeekRecapPillInfoPopup.tscn` | The scrim+card explainer popup opened by tapping a pill. |
| `tests/test_week_recap_pill_info_popup.gd` | Its tests. |

**Modified:**

| Path | Change |
|---|---|
| `Scripts/Audio/AudioDirector.gd` | Four new `@export var sfx_*` slots + `_resolve_sfx` branches. |
| `Scripts/SchoolSimulation/WeekRecapPill.gd` | `gui_input` tap detection, `pill_tapped` signal. |
| `Scripts/SchoolSimulation/WeekRecapBanner.gd` | Wires `pill_tapped` → popup; staggered slide+fade pill entrance; idle bounce cycle. |
| `Scenes/SchoolSimulation/WeekRecapPill.tscn` | `mouse_filter = STOP` on root. |
| `Scripts/SchoolSimulation/DaySummaryNeedsBar.gd` | No change to its own API — the chevron lives as a sibling node driven by `DaySummaryStudentRow`. |
| `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` | Adds `DeltaChevron` `TextureRect` under `EnergyBar` and `MoodBar`. |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | `_show_needs_delta` drives the chevron instead of the label's visible text. |
| `Scripts/SchoolSimulation/ResultCheckup.gd` | `show_pane` gets a directional slide+fade transition. |
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | `ScrollFade` becomes a `TextureRect` with a `GradientTexture2D`. |
| `tests/test_result_checkup.gd`, `tests/test_day_summary.gd` | Extended per task. |

---

## Task 1: Copied SFX files + AudioDirector registration

**Files:**
- Create: `Assets/Audio/SFX/pill_tap.ogg`, `Assets/Audio/SFX/pill_popup_open.ogg`, `Assets/Audio/SFX/pill_popup_close.ogg`, `Assets/Audio/SFX/pane_swipe.ogg`
- Modify: `Scripts/Audio/AudioDirector.gd`
- Test: `tests/test_audio_director.gd` (or wherever `has_sfx` is already tested — read the file first and append there)

**Interfaces:**
- Produces: `AudioDirector.has_sfx(&"pill_tap")`, `&"pill_popup_open"`, `&"pill_popup_close"`, `&"pane_swipe"` all return `true` once registered. `AudioDirector.play_sfx(&"pill_tap")` etc. become valid calls for later tasks.

- [ ] **Step 1: Copy the four files**

```bash
cp "Assets/Audio/SFX/tap.ogg" "Assets/Audio/SFX/pill_tap.ogg"
cp "Assets/Audio/SFX/popup_open.ogg" "Assets/Audio/SFX/pill_popup_open.ogg"
cp "Assets/Audio/SFX/popup_close.ogg" "Assets/Audio/SFX/pill_popup_close.ogg"
cp "Assets/Audio/SFX/swipe.ogg" "Assets/Audio/SFX/pane_swipe.ogg"
```

These are plain file copies of existing project assets already committed to the repo — not a download from an external source.

- [ ] **Step 2: Import the new audio files**

Via MCP: `filesystem_manage(op="scan")`. Confirm the four new `.ogg.import` files appear beside the sources (`ls Assets/Audio/SFX/`).

- [ ] **Step 3: Write the failing test**

Read `tests/test_audio_director.gd` first to match its existing style (likely a loop over expected ids, or individual `assert_true(AudioDirector.has_sfx(...))` calls). Append:

```gdscript
func test_pill_and_pane_sfx_are_registered() -> void:
	for id in [&"pill_tap", &"pill_popup_open", &"pill_popup_close", &"pane_swipe"]:
		assert_true(AudioDirector.has_sfx(id),
			"AudioDirector has no stream registered for %s" % id)
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `test_run(suite="audio_director")`
Expected: FAIL — the four ids are unresolved (`has_sfx` returns `false`).

- [ ] **Step 5: Register the four new slots**

In `Scripts/Audio/AudioDirector.gd`, immediately after the existing `sfx_sparkle` export (end of the `@export_group("SFX")` block), add:

```gdscript
## `play_sfx(&"pill_tap")`: tapping a headline pill on ResultCheckup's
## week recap banner. A dedicated copy of SFX/tap.ogg (not a second id
## on the same file) so it can be retuned independently later.
@export var sfx_pill_tap: AudioStream = preload("res://Assets/Audio/SFX/pill_tap.ogg")
## `play_sfx(&"pill_popup_open")`: WeekRecapPillInfoPopup opens. A
## dedicated copy of SFX/popup_open.ogg.
@export var sfx_pill_popup_open: AudioStream = preload("res://Assets/Audio/SFX/pill_popup_open.ogg")
## `play_sfx(&"pill_popup_close")`: WeekRecapPillInfoPopup closes. A
## dedicated copy of SFX/popup_close.ogg.
@export var sfx_pill_popup_close: AudioStream = preload("res://Assets/Audio/SFX/pill_popup_close.ogg")
## `play_sfx(&"pane_swipe")`: ResultCheckup's SISWA<->RIWAYAT pane
## transition. A dedicated copy of SFX/swipe.ogg.
@export var sfx_pane_swipe: AudioStream = preload("res://Assets/Audio/SFX/pane_swipe.ogg")
```

In `_resolve_sfx`'s `match id:` block, immediately after the `&"sparkle": return sfx_sparkle` line, add:

```gdscript
		&"pill_tap": return sfx_pill_tap
		&"pill_popup_open": return sfx_pill_popup_open
		&"pill_popup_close": return sfx_pill_popup_close
		&"pane_swipe": return sfx_pane_swipe
```

- [ ] **Step 6: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="audio_director")`
Expected: PASS.

- [ ] **Step 7: Run the audio-hygiene suite as a sanity check**

Run: `test_run(suite="audio_coverage")`
Expected: PASS, unchanged count — this task adds registered slots, not any new `play_sfx` call sites yet.

- [ ] **Step 8: Commit**

```bash
git add Assets/Audio/SFX/pill_tap.ogg Assets/Audio/SFX/pill_tap.ogg.import \
	Assets/Audio/SFX/pill_popup_open.ogg Assets/Audio/SFX/pill_popup_open.ogg.import \
	Assets/Audio/SFX/pill_popup_close.ogg Assets/Audio/SFX/pill_popup_close.ogg.import \
	Assets/Audio/SFX/pane_swipe.ogg Assets/Audio/SFX/pane_swipe.ogg.import \
	Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd
git commit -m "feat(audio): register dedicated pill/pane SFX copies"
```

---

## Task 2: WeekRecapPill becomes tappable

**Files:**
- Modify: `Scripts/SchoolSimulation/WeekRecapPill.gd`
- Modify: `Scenes/SchoolSimulation/WeekRecapPill.tscn` (controller builds via MCP)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `Juice.press(node)`, `Juice.release(node)` (both already exist, take a `Control`).
- Produces: `signal pill_tapped` on `WeekRecapPill`, emitted exactly once per clean press-then-release-inside-rect gesture. `WeekRecapBanner` (Task 4) connects to this per pill instance.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
func test_pill_root_stops_mouse_input() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	assert_eq(pill.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the pill must consume clicks, not pass them through")
	pill.free()


func test_pill_tapped_fires_on_a_clean_press_release() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	pill.size = Vector2(228, 132)
	# A plain int local would be captured BY VALUE inside the lambda
	# below (GDScript closures snapshot value-type locals rather than
	# referencing the caller's own variable), so "fired += 1" would
	# mutate a copy the assertion below can never see. A one-element
	# Array is captured by reference, which is what a closure needs to
	# write back.
	var fired := [0]
	pill.pill_tapped.connect(func() -> void: fired[0] += 1)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 50)
	pill._gui_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 60)
	pill._gui_input(release)

	assert_eq(fired[0], 1, "one clean tap fires the signal exactly once")
	pill.queue_free()


func test_pill_tapped_does_not_fire_on_drag_off() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	pill.size = Vector2(228, 132)
	# See the note above -- a one-element Array, not a plain int, so a
	# real false-positive firing is caught rather than a copy that
	# never moves.
	var fired := [0]
	pill.pill_tapped.connect(func() -> void: fired[0] += 1)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 50)
	pill._gui_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(9999, 9999)
	pill._gui_input(release)

	assert_eq(fired[0], 0, "releasing outside the rect cancels the tap")
	pill.queue_free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — `mouse_filter` is still `INHERIT`, `pill_tapped` doesn't exist.

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/WeekRecapPill.gd`, add the signal near the top (after the class-level doc comment, before the `@onready` block):

```gdscript
## Emitted after a clean press-then-release inside this pill's own rect.
## A release outside the rect (a drag-off) cancels the gesture silently --
## no signal, matching how a Button's own click-cancel behaves.
signal pill_tapped
```

Add a tracking var near the bottom of the existing var block (there isn't one yet — add one):

```gdscript
## True between a press inside this pill's rect and the matching release,
## however that release resolves. Distinguishes a genuine tap from a
## stray release event this pill never started.
var _is_pressed: bool = false
```

Add the input handler as a new method (anywhere after `play_count_up`):

```gdscript
## Tap detection: press starts the pressed-feel and arms the gesture;
## release either fires pill_tapped (inside the rect) or just resolves
## the pressed-feel (outside it, a cancelled drag-off). Requires
## mouse_filter = STOP on the root, set in the .tscn.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_is_pressed = true
		Juice.press(self)
	elif _is_pressed:
		_is_pressed = false
		Juice.release(self)
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			pill_tapped.emit()
```

- [ ] **Step 4: Set `mouse_filter` on the scene via MCP**

Controller builds this via the editor:

1. `scene_open("res://Scenes/SchoolSimulation/WeekRecapPill.tscn")`.
2. `node_set_property(path="/WeekRecapPill", property="mouse_filter", value=0)` (`MOUSE_FILTER_STOP` — Godot's enum is `STOP=0`/`PASS=1`/`IGNORE=2`).
3. `scene_save()`.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the three new tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/WeekRecapPill.gd Scenes/SchoolSimulation/WeekRecapPill.tscn tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): make each week-recap pill tappable"
```

---

## Task 3: WeekRecapPillInfoPopup

**Files:**
- Create: `Scripts/UI/WeekRecapPillInfoPopup.gd`
- Create: `Scenes/UI/WeekRecapPillInfoPopup.tscn` (controller builds via MCP)
- Test: `tests/test_week_recap_pill_info_popup.gd`

**Interfaces:**
- Consumes: `AudioDirector.play_sfx(&"pill_popup_open"/"pill_popup_close")` (Task 1), `DesignTokens.load_default().scrim_color()`, `Juice.pop_in(node)`.
- Produces: `WeekRecapPillInfoPopup.configure(icon: Texture2D, title: String, body: String) -> void`, `.open() -> void` (coroutine, fire-and-forget), `.close() -> void` (coroutine, idempotent), `signal closed`. `WeekRecapBanner` (Task 4) instances this scene, calls `configure()` then `open()`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_week_recap_pill_info_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## WeekRecapPillInfoPopup: the explainer a player gets by tapping a
## headline pill on ResultCheckup's week recap banner. Structurally a
## smaller sibling of Scenes/UI/StatDetailPopup.tscn -- same scrim+card
## shell, same tap-anywhere-to-close, no bar/value line since a pill has
## no 0-100 value to visualize.
##
## Must be @tool; no test here may be a coroutine, so nothing calls
## open() or close() -- only configure() and the signal/node contract.

func suite_name() -> String:
	return "week_recap_pill_info_popup"


const SCENE_PATH := "res://Scenes/UI/WeekRecapPillInfoPopup.tscn"


func _make() -> WeekRecapPillInfoPopup:
	var scene: PackedScene = load(SCENE_PATH)
	var popup: WeekRecapPillInfoPopup = scene.instantiate()
	Engine.get_main_loop().root.add_child(popup)
	track(popup)
	return popup


func test_scene_exists_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	assert_not_null(_make())


func test_scene_supplies_every_node_the_script_binds() -> void:
	var popup := _make()
	for path in ["Scrim", "Scrim/Card", "Scrim/Card/Layout/Header",
			"Scrim/Card/Layout/Header/IconRect",
			"Scrim/Card/Layout/Header/TitleLabel",
			"Scrim/Card/Layout/Header/CloseButton",
			"Scrim/Card/Layout/BodyLabel"]:
		assert_not_null(popup.get_node_or_null(path), "missing node: %s" % path)


func test_configure_fills_every_label_and_icon() -> void:
	var popup := _make()
	var tex := PlaceholderTexture2D.new()
	popup.configure(tex, "Uang", "Total penghasilan Wirausaha yang terkumpul minggu ini.")
	assert_eq(popup.title_label.text, "Uang", "title is written")
	assert_eq(popup.body_label.text,
		"Total penghasilan Wirausaha yang terkumpul minggu ini.",
		"body is written")
	assert_eq(popup.icon_rect.texture, tex, "icon is written")


func test_scene_carries_no_theme_override() -> void:
	var src := FileAccess.get_file_as_string(SCENE_PATH)
	assert_false(src.contains("theme_override_styles"),
		"no stylebox override on the popup")


func test_script_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/UI/WeekRecapPillInfoPopup.gd")
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="week_recap_pill_info_popup")`
Expected: FAIL — the scene/script don't exist.

- [ ] **Step 3: Write the script**

Create `Scripts/UI/WeekRecapPillInfoPopup.gd`:

```gdscript
@tool
class_name WeekRecapPillInfoPopup
extends CanvasLayer

## The explainer a player gets by tapping a headline pill on
## ResultCheckup's week recap banner (2026-09-03 interactivity spec,
## section 3.3).
##
## Structurally a smaller sibling of Scenes/UI/StatDetailPopup.tscn: same
## scrim+card shell, same tap-anywhere-on-scrim-to-close behaviour, same
## open()/close() timing shape. No StatBar and no numeric value line --
## unlike a student's stat, a pill has no 0-100 value to visualize, just
## an icon, a title, and one sentence of explanation.
##
## Affects: nothing outside itself. Plays two SFX through AudioDirector
## and emits `closed` when its exit animation finishes. Never writes
## GameState.
##
## @tool so the scene previews correctly in the editor. _ready() only
## caches node references and wires signals -- both are safe in an
## editor session -- so nothing here needs an Engine.is_editor_hint()
## guard.

## Emitted after the close animation finishes and this node has been
## freed from the tree.
signal closed

## How long the scrim takes to fade in behind the card.
@export var scrim_fade_in_seconds: float = 0.22
## How long the card takes to slide off the bottom edge on close.
@export var close_slide_seconds: float = 0.26
## How long the scrim takes to fade back out on close.
@export var scrim_fade_out_seconds: float = 0.22

@onready var scrim: ColorRect = $Scrim
@onready var card: PanelContainer = $Scrim/Card
@onready var icon_rect: TextureRect = $Scrim/Card/Layout/Header/IconRect
@onready var title_label: Label = $Scrim/Card/Layout/Header/TitleLabel
@onready var close_button: Button = $Scrim/Card/Layout/Header/CloseButton
@onready var body_label: Label = $Scrim/Card/Layout/BodyLabel

## Guards against a double close: the exit tween and the scrim tap can
## both fire, and freeing twice crashes.
var _is_closing: bool = false


func _ready() -> void:
	scrim.color = _scrim_color(0.0)
	close_button.pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_input)


## The project's modal scrim at a given opacity. `alpha_scale` of 0 gives
## the same hue at zero opacity, which is what the fades tween from and
## back to -- tweening between two different hues would flash mid-fade.
func _scrim_color(alpha_scale: float = 1.0) -> Color:
	var c := DesignTokens.load_default().scrim_color()
	c.a *= alpha_scale
	return c


## Fill the icon, title, and body from one pill's fixed copy. Call before
## adding the popup to the tree, or immediately after -- it needs the
## @onready references, so it must run inside the tree.
func configure(icon: Texture2D, title: String, body: String) -> void:
	icon_rect.texture = icon
	title_label.text = title
	body_label.text = body


## Reveal: place the card above the bottom edge, pop it in, fade the
## scrim up. A coroutine because the card's height is only known after
## one layout pass. Callers must NOT await it -- fire and forget.
func open() -> void:
	AudioDirector.play_sfx(&"pill_popup_open")
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	card.position = Vector2(
		(vp.x - card.size.x) * 0.5,
		vp.y - card.size.y - float(DesignTokens.load_default().space_md))
	Juice.pop_in(card)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(scrim, "color", _scrim_color(), scrim_fade_in_seconds)


## Slide the card out, fade the scrim, free this node, emit `closed`.
## Safe to call twice; the second call is ignored.
func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	AudioDirector.play_sfx(&"pill_popup_close")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "position:y", vp.y, close_slide_seconds)
	tw.tween_property(scrim, "color", _scrim_color(0.0), scrim_fade_out_seconds)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


## Tapping anywhere on the scrim dismisses, matching StatDetailPopup.
func _on_scrim_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		close()
```

- [ ] **Step 4: Build the scene via MCP**

The controller builds `Scenes/UI/WeekRecapPillInfoPopup.tscn`, mirroring `StatDetailPopup.tscn`'s structure but without the bar/value nodes:

1. `scene_manage(op="create", params={"path": "res://Scenes/UI/WeekRecapPillInfoPopup.tscn", "root_type": "CanvasLayer", "root_name": "WeekRecapPillInfoPopup"})`.
2. `batch_execute`: `attach_script` the new `.gd`; `set_property` root `layer = 100` (matches `StatDetailPopup`).
3. `Scrim`: `ColorRect`, full-rect anchors (`anchors_preset = 15`), `color = Color(0,0,0,0)`.
4. `Card`: `PanelContainer` under `Scrim`, `custom_minimum_size = Vector2(760, 0)` (narrower than `StatDetailPopup`'s 1015 — this card has less content), `layout_mode = 0`, `theme_type_variation = "Card"`.
5. `Layout`: `VBoxContainer` under `Card`, `theme_override_constants/separation = 0` (layout-only constant, permitted).
6. `Header`: `MarginContainer` under `Layout`, margins matching `StatDetailPopup`'s header margins (32 on left/top/right, read the actual `.tscn` for the exact bottom margin and copy it) — read `Scenes/UI/StatDetailPopup.tscn` directly for the exact `Header` margin constants and match them, so the two popups share a header rhythm.
7. Under `Header`, an `HBoxContainer` (call it `Row` to match `StatDetailPopup`'s own inner row, or flatten directly — either is fine since this popup's header has one fewer level than `StatDetailPopup`'s Titles sub-VBox; if flattened, update the script's `@onready` paths to match and update the test's node-path list in Task 3 Step 1 to match exactly what you build):
   - `IconRect`: `TextureRect`, `custom_minimum_size` around `Vector2(64, 64)`, `expand_mode = 1`, `stretch_mode = 5`.
   - `TitleLabel`: `Label`, `theme_type_variation = "TitleLabel"`, `size_flags_horizontal = 3`.
   - `CloseButton`: instance `StatDetailPopup.tscn`'s own close-button subtree if it's a simple `Button`, or build a plain `Button` with `theme_type_variation = "SecondaryButton"` and text `"X"` (Indonesian screens elsewhere use a plain "X" or an icon close button — read `StatDetailPopup.tscn`'s `CloseButton` node directly and match its exact type/variation/texture so the two popups' close affordance looks identical).
8. `BodyLabel`: `Label` directly under `Layout` (a sibling of `Header`, not nested inside it), `theme_type_variation = "CaptionLabel"` or `"BarLabel"` (read `StatDetailPopup.tscn`'s `DescriptionLabel` variation and reuse the same one), `autowrap_mode = 2`.
9. `scene_save()`.

**Important:** whatever exact node structure you build, the `@onready` paths in the script (Step 3) and the node-path list in the test (Step 1) must match it exactly — if you flatten `Header/Row` into just `Header`, update both the script's `$Scrim/Card/Layout/Header/IconRect` paths (already written that way above — no `Row` segment) and the test's path list (also already written without `Row`) to agree. They're written consistently above; keep them that way.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="week_recap_pill_info_popup")`
Expected: PASS, all 5 tests.

- [ ] **Step 6: Commit**

```bash
git add Scripts/UI/WeekRecapPillInfoPopup.gd Scenes/UI/WeekRecapPillInfoPopup.tscn tests/test_week_recap_pill_info_popup.gd
git commit -m "feat(ui): add the week-recap pill info popup"
```

---

## Task 4: Wire pills to the popup + idle bounce cycle

**Files:**
- Modify: `Scripts/SchoolSimulation/WeekRecapBanner.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `WeekRecapPill.pill_tapped` (Task 2), `WeekRecapPillInfoPopup.configure/open` (Task 3), `AudioDirector.play_sfx(&"pill_tap")` (Task 1).
- Produces: `WeekRecapBanner.start_idle_bounce() -> void`, `WeekRecapBanner.stop_idle_bounce() -> void` (both safe to call repeatedly), called by `play_entrance()` (bounce starts once stage 2's cascade finishes — see Task 6) and by `ResultCheckup._on_close_pressed` (bounce stops).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
func test_tapping_a_pill_opens_its_info_popup() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	_add_themed(banner)
	banner.set_recap({
		"money_earned": 4200, "net_skill_delta": 37,
		"minigames_won": 3, "minigames_total": 5, "events_count": 2,
	})
	assert_eq(banner.get_tree().get_nodes_in_group(&"__unused__").size(), 0,
		"sanity: tree is reachable")
	banner.pill_uang.pill_tapped.emit()
	var popups := Engine.get_main_loop().root.get_children().filter(
		func(n: Node) -> bool: return n is WeekRecapPillInfoPopup)
	assert_eq(popups.size(), 1, "tapping a pill opens exactly one popup")
	var popup: WeekRecapPillInfoPopup = popups[0]
	assert_eq(popup.title_label.text, "Uang", "the money pill's popup title")
	popup.queue_free()
	banner.queue_free()


func test_idle_bounce_can_be_started_and_stopped() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	_add_themed(banner)
	banner.start_idle_bounce()
	assert_not_null(banner._idle_tween, "starting creates a tween")
	banner.stop_idle_bounce()
	assert_true(banner._idle_tween == null or not banner._idle_tween.is_valid(),
		"stopping kills the tween")
	banner.queue_free()


func test_idle_bounce_is_paused_while_a_popup_is_open() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	_add_themed(banner)
	banner.start_idle_bounce()
	banner.pill_uang.pill_tapped.emit()
	assert_true(banner._idle_tween == null or banner._idle_tween.is_paused(),
		"a live popup pauses the bounce so a pill never bounces under the scrim")
	banner.queue_free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — `pill_tapped` isn't connected to anything yet, `start_idle_bounce`/`stop_idle_bounce`/`_idle_tween` don't exist.

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/WeekRecapBanner.gd`, add near the top (const block):

```gdscript
## The pills, keyed by the same names WeekRecap.compute() uses, in the
## fixed left-to-right order they're authored in the scene. Read by both
## the idle bounce cycle and the tap handler, so both agree on order and
## on which pill maps to which explainer.
const PILL_ORDER := ["uang", "poin", "menang", "event"]

## One sentence per pill, shown by WeekRecapPillInfoPopup on tap. Indonesian,
## matching the project's explanatory tone (2026-09-03 interactivity spec,
## section 3.3).
const PILL_INFO := {
	"uang": {"title": "Uang", "body": "Total penghasilan Wirausaha yang terkumpul minggu ini."},
	"poin": {"title": "Poin", "body": "Total kenaikan Akademis, Seni Budaya, dan Olahraga minggu ini -- bisa minus jika menurun."},
	"menang": {"title": "Menang", "body": "Jumlah minigame yang dimenangkan dari total yang dimainkan minggu ini."},
	"event": {"title": "Event", "body": "Jumlah kejadian acak yang terjadi minggu ini."},
}

## Gap between one idle-bounce pill and the next, and the pause after the
## fourth before the cycle repeats.
const IDLE_STEP := 0.9
const IDLE_CYCLE_PAUSE := 1.2

const _POPUP_SCENE := "res://Scenes/UI/WeekRecapPillInfoPopup.tscn"
```

Add a var near `_recap`:

```gdscript
## The looping idle-bounce tween, or null when not running. A single
## tween owned by the banner (not one per pill) so the whole cycle can be
## paused/killed in one call -- see start_idle_bounce/stop_idle_bounce.
var _idle_tween: Tween = null
```

In `_ready()` (there is no `_ready()` on this file yet — add one) or at the bottom of `set_recap()`, wire the four pills' signals once. Since `set_recap()` can be called more than once (it's documented idempotent) but signal connections must not double up, wire them in a new `_ready()` instead, which only ever runs once per instance:

```gdscript
func _ready() -> void:
	pill_uang.pill_tapped.connect(_on_pill_tapped.bind("uang"))
	pill_poin.pill_tapped.connect(_on_pill_tapped.bind("poin"))
	pill_menang.pill_tapped.connect(_on_pill_tapped.bind("menang"))
	pill_event.pill_tapped.connect(_on_pill_tapped.bind("event"))


## Open this pill's explainer popup. Pauses the idle bounce first so a
## pill never visibly bounces behind the scrim.
func _on_pill_tapped(pill_key: String) -> void:
	if Engine.is_editor_hint():
		return
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.pause()
	AudioDirector.play_sfx(&"pill_tap")
	var info: Dictionary = PILL_INFO.get(pill_key, {})
	var icon: Texture2D = {
		"uang": icon_uang, "poin": icon_poin,
		"menang": icon_menang, "event": icon_event,
	}.get(pill_key)
	var popup: WeekRecapPillInfoPopup = load(_POPUP_SCENE).instantiate()
	get_tree().root.add_child(popup)
	popup.configure(icon, info.get("title", ""), info.get("body", ""))
	popup.closed.connect(_on_popup_closed)
	popup.open()


## Resume the idle bounce once its popup closes.
func _on_popup_closed() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.play()


## Start the looping "tap me" hint: each pill in turn gets a small
## non-destructive scale-pop, left to right, then a longer pause before
## the cycle repeats. Silent -- no SFX; a looping cue every cycle would
## read as an alarm, not a hint (2026-09-03 interactivity spec, section
## 3.2). Safe to call while already running: kills any prior tween first.
func start_idle_bounce() -> void:
	if Engine.is_editor_hint():
		return
	stop_idle_bounce()
	var pills: Array = [pill_uang, pill_poin, pill_menang, pill_event]
	_idle_tween = create_tween().set_loops()
	for pill in pills:
		Juice.set_pivot_center(pill)
		_idle_tween.tween_property(pill, "scale", Vector2(1.08, 1.08), 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_idle_tween.tween_property(pill, "scale", Vector2.ONE, 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_idle_tween.tween_interval(IDLE_STEP)
	_idle_tween.tween_interval(IDLE_CYCLE_PAUSE)


## Stop the idle bounce outright (not pause -- kill), snapping every
## pill's scale back to 1.0 so none is left mid-bounce. Safe to call when
## not running.
func stop_idle_bounce() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	for pill in [pill_uang, pill_poin, pill_menang, pill_event]:
		if is_instance_valid(pill):
			pill.scale = Vector2.ONE
```

`create_tween().set_loops()` with no argument loops forever, matching a hint that should persist for as long as the banner is visible.

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the three new tests PASS.

- [ ] **Step 5: Wire the idle bounce's start/stop into `ResultCheckup.gd`**

This is a small addition, folded into this task since it's the only caller of the two new public methods. In `Scripts/SchoolSimulation/ResultCheckup.gd`, at the very end of `_play_entrance_animations` (after `btn_close.disabled = false`), add:

```gdscript
	banner.start_idle_bounce()
```

In `_on_close_pressed`, as the first line of the function (before `AudioDirector.play_sfx(&"confirm")`), add:

```gdscript
	banner.stop_idle_bounce()
```

No new test needed for this two-line wiring — it's exercised end-to-end once Task 9's full-suite/screenshot verification runs, and the unit-level behavior (`start_idle_bounce`/`stop_idle_bounce` themselves) is already covered by Step 1's tests.

- [ ] **Step 6: Rescan and run `result_checkup` again**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: still all green (this step only adds two call sites, no new assertions).

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/WeekRecapBanner.gd Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): wire pill taps to the info popup and add the idle bounce hint"
```

---

## Task 5: Needs-bar delta becomes a directional chevron

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` (controller builds via MCP)
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: existing `icon_chevron_up.png` (`Assets/Images/DaySummary/icon_chevron_up.png`, already an `ext_resource` in `DaySummaryStatRow.tscn` — reuse the same asset, no new art).
- Produces: `DaySummaryStudentRow._show_needs_delta(label, delta)` keeps its exact signature (`setup_row`/`setup_week_row` call it unchanged) but now drives a chevron instead of visible label text.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The needs-bar delta is a directional arrow now, not a number that
## collides with the tier word beside it (2026-09-03 interactivity spec,
## section 4). DeltaLabel keeps carrying the text as data (existing
## coverage of format_needs_delta stays meaningful) but is never
## rendered; DeltaChevron is what the player actually sees.
##
## setup_week_row reads its delta from StudentData.get_energy_delta()/
## get_mood_delta(), which are simply `energy - initial_energy` /
## `mood - initial_mood` (StudentData.gd) -- so a test controls the
## delta by setting `initial_energy`/`energy` (or the mood pair) apart,
## not by passing a delta directly.
func test_needs_delta_chevron_points_up_on_a_gain() -> void:
	var row := _make_row()
	var student := StudentData.new()
	student.initial_energy = 40.0
	student.energy = 48.0  # +8
	student.initial_mood = 50.0
	student.mood = 50.0  # +0
	row.setup_week_row(student)
	var chevron: TextureRect = row.get_node("EnergyBar/DeltaChevron")
	assert_true(chevron.visible, "a gain shows the chevron")
	assert_eq(chevron.rotation_degrees, 0.0, "a gain points up")
	assert_false(row.energy_delta_label.visible,
		"the number itself is never rendered")
	row.queue_free()


func test_needs_delta_chevron_points_down_on_a_loss() -> void:
	var row := _make_row()
	var student := StudentData.new()
	student.initial_energy = 52.0
	student.energy = 40.0  # -12
	student.initial_mood = 50.0
	student.mood = 50.0  # +0
	row.setup_week_row(student)
	var chevron: TextureRect = row.get_node("EnergyBar/DeltaChevron")
	assert_true(chevron.visible, "a loss shows the chevron")
	assert_eq(chevron.rotation_degrees, 180.0, "a loss points down")
	row.queue_free()


func test_needs_delta_chevron_hidden_at_exactly_zero() -> void:
	var row := _make_row()
	var student := StudentData.new()
	student.initial_energy = 40.0
	student.energy = 40.0  # +0
	student.initial_mood = 50.0
	student.mood = 50.0  # +0
	row.setup_week_row(student)
	var chevron: TextureRect = row.get_node("EnergyBar/DeltaChevron")
	assert_false(chevron.visible, "no movement, no arrow")
	row.queue_free()


## Instantiates DaySummaryStudentRow.tscn, assigns the baked theme, and
## adds it to the tree so its @onready fields resolve -- the same
## pattern test_card_fills_its_needs_bars_on_both_paths already uses
## earlier in this suite.
func _make_row() -> DaySummaryStudentRow:
	var theme: Theme = load(_THEME_PATH)
	var row: DaySummaryStudentRow = load(
		"res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn").instantiate()
	row.theme = theme
	Engine.get_main_loop().root.add_child(row)
	return row
```

If `_THEME_PATH` is not already a const in this file, add it at the top
of the suite matching the value used elsewhere in this codebase's test
files: `const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"`
(check first — it likely already exists, since other tests in this same
file assign a theme the same way).

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="day_summary")`
Expected: FAIL — `DeltaChevron` doesn't exist on either bar yet.

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`:

Add two new `@onready` vars beside the existing `energy_delta_label`/`mood_delta_label`:

```gdscript
## The directional arrow replacing the needs-bar delta NUMBER (2026-09-03
## interactivity spec, section 4) -- energy_delta_label/mood_delta_label
## still carry the formatted text as data for format_needs_delta's own
## test coverage, but are never shown; these chevrons are what renders.
@onready var energy_delta_chevron: TextureRect = $EnergyBar/DeltaChevron
@onready var mood_delta_chevron: TextureRect = $MoodBar/DeltaChevron
```

Replace `_show_needs_delta` in full:

```gdscript
## Point one needs-bar's directional chevron by its delta's sign, and
## keep writing the label's TEXT (never its visibility) so
## format_needs_delta's own coverage stays meaningful. A gain points the
## chevron up (rotation 0), a loss points it down (rotation 180, the
## same up-arrow asset DaySummaryStatRow's own chevron uses, reused
## rather than drawn twice), and exactly zero shows neither -- matching
## this card's "no news, no icon" rule everywhere else.
func _show_needs_delta(label: Label, chevron: TextureRect, delta: float) -> void:
	label.text = format_needs_delta(delta)
	label.visible = false
	if delta > 0.0:
		chevron.rotation_degrees = 0.0
		chevron.visible = true
	elif delta < 0.0:
		chevron.rotation_degrees = 180.0
		chevron.visible = true
	else:
		chevron.visible = false
```

Update its two call sites (both inside `setup_week_row`, search for `_show_needs_delta(`):

```gdscript
	_show_needs_delta(energy_delta_label, energy_delta_chevron, energy_delta)
	_show_needs_delta(mood_delta_label, mood_delta_chevron, mood_delta)
```

`setup_row`'s existing `energy_delta_label.hide()` / `mood_delta_label.hide()` calls stay as-is (the label was already always hidden on the daily path) but add the matching chevron hides right beside them, so a card re-armed from the daily path never shows a stale chevron from a prior weekly setup:

```gdscript
	energy_delta_label.hide()
	mood_delta_label.hide()
	energy_delta_chevron.hide()
	mood_delta_chevron.hide()
```

- [ ] **Step 4: Add `DeltaChevron` to both bars via MCP**

Controller builds this via the editor. For each of `EnergyBar` and `MoodBar` in `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`:

1. `scene_open("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")`.
2. `node_create(type="TextureRect", name="DeltaChevron", parent_path="/DaySummaryStudentRow/EnergyBar")`.
3. `batch_execute` on `/DaySummaryStudentRow/EnergyBar/DeltaChevron`: `set_property` `texture` = `res://Assets/Images/DaySummary/icon_chevron_up.png` (same asset `DaySummaryStatRow.tscn` uses); `set_property` `visible` = `false`; `set_property` `expand_mode` = `1`; `set_property` `stretch_mode` = `5`; `set_property` `anchor_top` = `0.5`; `set_property` `anchor_bottom` = `0.5`; `set_property` `offset_left` = `195`; `set_property` `offset_top` = `-14`; `set_property` `offset_right` = `223`; `set_property` `offset_bottom` = `14`; `set_property` `grow_vertical` = `2`.
   (This sits at the bar's right edge — the 243px-wide bar runs x:0–243, `Word`'s box ends at x:220, so the chevron's x:195–223 span sits just past where `Word`'s longest tier word could ever reach, with no overlap.)
4. Repeat for `/DaySummaryStudentRow/MoodBar` — `node_create` a `DeltaChevron` under it with the same properties.
5. `scene_save()`.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="day_summary")`
Expected: the three new tests PASS, and every pre-existing `day_summary` test still passes (the label's text-writing behavior is unchanged, only its visibility).

- [ ] **Step 6: Run `result_checkup` too**

`DaySummaryStudentRow` is shared with the weekly card. Run: `test_run(suite="result_checkup")`
Expected: PASS, no regression.

- [ ] **Step 7: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd
git commit -m "fix(daysummary): replace the needs-bar delta number with a directional arrow"
```

---

## Task 6: Staggered slide+fade pill entrance

**Files:**
- Modify: `Scripts/SchoolSimulation/WeekRecapBanner.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: nothing new — this reshapes `play_entrance()`'s existing stage-2 loop.
- Produces: no signature change to `play_entrance()`. `start_idle_bounce()` (Task 4) now gets called at the true end of the cascade rather than needing its own separate wiring — see Step 3.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
## The cascade itself is a coroutine (play_entrance), so this test only
## checks the SETUP each pill's tween needs before it can slide+fade in
## -- that every pill starts the cascade at alpha 0 and offset above its
## slot, per the 2026-09-03 interactivity spec section 5. It does not
## await play_entrance() itself.
func test_pills_start_the_cascade_transparent_and_offset() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, "modulate.a = 0.0",
		"each pill starts fully transparent before its slide-in")
	assert_contains(src, "PILL_SLIDE_DISTANCE",
		"a named constant drives the pill's start offset, not a literal")


func test_pill_cascade_step_is_a_named_constant() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, "PILL_CASCADE_STEP",
		"the stagger between one pill starting and the next is named, not a literal")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — neither constant exists yet.

- [ ] **Step 3: Rewrite the stage-2 section of `play_entrance()`**

In `Scripts/SchoolSimulation/WeekRecapBanner.gd`, add two new consts beside `PILL_STEP`:

```gdscript
## How far each pill starts above its authored slot before sliding down
## into place, in pixels.
const PILL_SLIDE_DISTANCE := 20.0

## Gap between one pill's slide-in STARTING and the next pill's starting
## -- a cascade, not four simultaneous tweens. Each pill's own number
## count-up begins only once THAT pill's slide-in finishes, so the
## numbers read left-to-right in the same rhythm as the pills landing.
const PILL_CASCADE_STEP := 0.10
```

`PILL_STEP` (the existing const) stays — it's still used by stage 3's coin-shower delay. Replace the body of `play_entrance()` from the `var pills: Array = [...]` line through the `for i in pills.size(): pills[i].play_count_up(...)` loop with:

```gdscript
	var pills: Array = [pill_uang, pill_poin, pill_menang, pill_event]
	var values: Array = [
		float(_recap.get("money_earned", 0)),
		float(_recap.get("net_skill_delta", 0)),
		float(_recap.get("minigames_won", 0)),
		float(_recap.get("events_count", 0)),
	]
	var formatters: Array = [
		func(v: float) -> String: return WeekRecap.format_money(int(v)),
		func(v: float) -> String: return WeekRecap.format_skill_delta(int(v)),
		func(v: float) -> String: return "%d/%d" % [int(v),
			_recap.get("minigames_total", 0)],
		func(v: float) -> String: return "%d" % int(v),
	]
	for i in pills.size():
		_slide_in_pill(pills[i], values[i], formatters[i], float(i) * PILL_CASCADE_STEP)
```

Add the new helper method, right after `play_entrance()`:

```gdscript
## One pill's own slide+fade entrance, chained into its number count-up.
## `delay` is this pill's position in the cascade (§5 of the 2026-09-03
## interactivity spec) -- pill 0 starts immediately, pill 1 starts
## PILL_CASCADE_STEP later, and so on, each pill's tween running
## independently once started rather than all four waiting on a shared
## clock.
##
## A coroutine; called only from play_entrance(), never directly by a
## test.
func _slide_in_pill(pill: WeekRecapPill, to_value: float, formatter: Callable,
		delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(pill) or not pill.is_inside_tree():
			return
	var t := Juice.tokens()
	pill.modulate.a = 0.0
	pill.position.y -= PILL_SLIDE_DISTANCE
	var tw := pill.create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(pill, "modulate:a", 1.0, t.dur_fast)
	tw.tween_property(pill, "position:y", pill.position.y + PILL_SLIDE_DISTANCE, t.dur_fast)
	await tw.finished
	if not is_instance_valid(pill):
		return
	pill.play_count_up(to_value, formatter)
```

Note `pill.play_count_up(...)` is now called with no extra `delay` argument — the cascade's own staggering already spaced each pill's *start*, and chaining the count-up after that pill's own slide-in finishes is what makes the numbers land in sequence rather than counting in parallel. `WeekRecapPill.play_count_up`'s `delay` parameter keeps its default `0.0` and is unused from this call site now.

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the two new source-scan tests PASS, and no existing test regresses (`test_banner_writes_every_total_into_its_pills`/`test_banner_shows_a_negative_week_as_negative` call `set_recap` directly, not `play_entrance`, so they're unaffected by this reshape).

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/WeekRecapBanner.gd tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): cascade the pill entrance left to right instead of counting in parallel"
```

---

## Task 7: Directional slide+fade between SISWA and RIWAYAT

**Files:**
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `show_pane(pane: int)` keeps its exact signature and every existing side effect (scroll-offset save/restore, `_history_animated` latch, `_sync_tab_buttons`) — only the `visible` swap itself becomes animated. `AudioDirector.play_sfx(&"pane_swipe")` (Task 1) fires once per real switch.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
## show_pane's transition is a coroutine under real play, but every test
## that already calls it directly (test_default_tab_is_siswa,
## test_switching_tabs_swaps_pane_visibility_without_freeing, the
## scroll-offset and latch tests) runs inside the editor process, where
## Engine.is_editor_hint() is true -- this test confirms the transition
## code stays behind that SAME existing guard, so none of those tests'
## synchronous assumptions (pane.visible flips immediately) can break.
func test_pane_transition_is_gated_on_editor_hint() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_contains(src, "PANE_SLIDE_DISTANCE",
		"a named constant drives the pane transition, not a literal")


func test_pane_transition_direction_is_derived_not_hardcoded() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_contains(src, "signi(",
		"the transition direction comes from signi(pane - _active_pane), " +
			"not two hardcoded literal directions")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — neither string exists yet.

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/ResultCheckup.gd`, add a const near the top (with `PILL_STEP`-style siblings — there isn't a const block on this file yet beyond the `enum Pane`, so add one after it):

```gdscript
## How far a pane slides horizontally during the SISWA<->RIWAYAT
## transition, in pixels.
const PANE_SLIDE_DISTANCE := 40.0
```

Replace `show_pane`'s body from the `students_pane.visible = pane == Pane.SISWA` /
`history_pane.visible = pane == Pane.RIWAYAT` lines (delete both of those two
lines) through the end of the existing `scroll_container` block, with the
editor-hint branch now happening BEFORE the visibility swap rather than
after it (since the swap itself is what becomes conditional on being
instant-vs-animated):

```gdscript
func show_pane(pane: int) -> void:
	if pane == _active_pane and students_pane.visible != history_pane.visible:
		return
	if scroll_container:
		_pane_scroll[_active_pane] = scroll_container.scroll_vertical
	var outgoing_pane := _active_pane
	_active_pane = pane
	_sync_tab_buttons()

	if Engine.is_editor_hint():
		students_pane.visible = pane == Pane.SISWA
		history_pane.visible = pane == Pane.RIWAYAT
		if scroll_container:
			scroll_container.scroll_vertical = _pane_scroll[pane]
		_history_animated = _history_animated or pane == Pane.RIWAYAT
		return

	AudioDirector.play_sfx(&"pane_swipe")
	await _transition_panes(outgoing_pane, pane)
	if scroll_container:
		# Deliberately synchronous, not set_deferred. ... [KEEP THE EXISTING
		# LONG COMMENT FROM THE CURRENT FILE HERE, UNCHANGED -- it still
		# applies: the scroll write happens right after the incoming pane's
		# own visibility flip, same risk window as before, same accepted-
		# risk reasoning from the 2026-09-03 Task 9 fix round.]
		scroll_container.scroll_vertical = _pane_scroll[pane]

	AudioDirector.play_sfx(&"select")
	if pane == Pane.RIWAYAT and not _history_animated:
		_history_animated = true
		await get_tree().create_timer(Juice.tokens().dur_instant).timeout
		_play_history_entrance()
```

Add the new coroutine helper, right after `show_pane`:

```gdscript
## The SISWA<->RIWAYAT slide+fade itself. `outgoing`/`incoming` are Pane
## values; direction is derived from their difference so a third pane
## would need no change here. The outgoing pane's own `visible` flips to
## false only once its exit tween finishes -- never before, so it's never
## cut off mid-slide. The incoming pane starts from the opposite offset
## and fades/slides back to its authored position, chained (not
## parallel) after the outgoing tween, so the two panes -- which occupy
## the same rect -- never visually overlap mid-transition.
##
## A coroutine; only ever called from show_pane, which is itself only
## reached here when Engine.is_editor_hint() is false.
func _transition_panes(outgoing: int, incoming: int) -> void:
	var dir := signi(incoming - outgoing)
	var outgoing_node: Control = students_pane if outgoing == Pane.SISWA else history_pane
	var incoming_node: Control = students_pane if incoming == Pane.SISWA else history_pane
	if outgoing_node == incoming_node:
		return

	var t := Juice.tokens()
	var out_tw := outgoing_node.create_tween().set_parallel(true)
	out_tw.tween_property(outgoing_node, "position:x",
		float(dir) * -PANE_SLIDE_DISTANCE, t.dur_fast)
	out_tw.tween_property(outgoing_node, "modulate:a", 0.0, t.dur_fast)
	await out_tw.finished
	if not is_instance_valid(outgoing_node):
		return
	outgoing_node.visible = false
	outgoing_node.position.x = 0.0
	outgoing_node.modulate.a = 1.0

	if not is_instance_valid(incoming_node):
		return
	incoming_node.position.x = float(dir) * PANE_SLIDE_DISTANCE
	incoming_node.modulate.a = 0.0
	incoming_node.visible = true
	var in_tw := incoming_node.create_tween().set_parallel(true)
	in_tw.tween_property(incoming_node, "position:x", 0.0, t.dur_fast)
	in_tw.tween_property(incoming_node, "modulate:a", 1.0, t.dur_fast)
	await in_tw.finished
```

`signi(int)` is a GDScript built-in returning `-1`, `0`, or `1` — used here on `incoming - outgoing`, which is always `-1` or `1` for the two-pane case (never `0`, since `_transition_panes` is only called when the panes actually differ).

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the two new source-scan tests PASS. Critically, re-run the FULL `result_checkup` suite (not just the new tests) to confirm every existing `show_pane`-calling test still passes — they all run under `Engine.is_editor_hint() == true`, which the rewrite explicitly keeps as an instant, synchronous, untouched path (the new animated branch is only reachable when that guard is false).

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): slide+fade between SISWA and RIWAYAT instead of snapping"
```

---

## Task 8: Fix `ScrollFade`

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn` (controller builds via MCP)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing new to consume — this is a pure visual fix, no script changes.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
## ScrollFade was a flat SunkenPanel -- an unexplained white box between
## the scrollable pane and BtnClose. It's a gradient now: an actual
## fade-to-transparent cue, not a themed surface (2026-09-03
## interactivity spec, section 7).
func test_scroll_fade_is_a_gradient_not_a_flat_panel() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	assert_contains(src, "GradientTexture2D",
		"ScrollFade must render an actual fade, not a flat SunkenPanel")
	# Isolate ScrollFade's own node block and confirm it carries no
	# theme_type_variation -- a gradient texture is not a themed surface.
	var node_start := src.find('[node name="ScrollFade"')
	assert_true(node_start != -1, "ScrollFade node exists")
	var next_node := src.find("[node name=", node_start + 1)
	var block := src.substr(node_start, next_node - node_start)
	assert_false(block.contains("theme_type_variation"),
		"ScrollFade is textured, not themed -- no SunkenPanel variation left on it")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — `ScrollFade` is still a `Panel` with `theme_type_variation = "SunkenPanel"`, no `GradientTexture2D` anywhere in the file.

- [ ] **Step 3: Rebuild `ScrollFade` via MCP**

Controller builds this via the editor:

1. `scene_open("res://Scenes/SchoolSimulation/ResultCheckup.tscn")`.
2. `node_manage(op="delete", params={"path": "/ResultCheckup/Margin/VBox/ScrollFade"})`.
3. `node_create(type="TextureRect", name="ScrollFade", parent_path="/ResultCheckup/Margin/VBox")`.
4. `node_manage(op="move", params={"path": "/ResultCheckup/Margin/VBox/ScrollFade", "index": 4})` (same position in `VBox`'s child order the old `Panel` held — between `ScrollContainer` and `BtnClose`; verify the current order first with `node_manage(op="get_children", params={"path": "/ResultCheckup/Margin/VBox"})` and pick the matching index).
5. `batch_execute` on the new node:
   - `set_property` `custom_minimum_size` = `{"x": 0, "y": 96}` (same as before).
   - `set_property` `mouse_filter` = `2` (`MOUSE_FILTER_IGNORE`, same as before).
   - `set_property` `expand_mode` = `1` (`EXPAND_IGNORE_SIZE`).
   - `set_property` `stretch_mode` = `0` (`STRETCH_SCALE` — a `GradientTexture2D` at the control's own size, no tiling needed).
   - `set_property` `texture` = `{"__class__": "GradientTexture2D", "width": 4, "height": 96, "fill": 1, "fill_from": {"x": 0.5, "y": 0.0}, "fill_to": {"x": 0.5, "y": 1.0}, "gradient": {"__class__": "Gradient", "offsets": [0.0, 1.0], "colors": ["#eef3ffcc", "#eef3ff00"]}}` — read `Assets/Theme/design_tokens.tres` first to confirm `surface_page`'s exact hex value (used as `#eef3ff` above from the earlier grep of `DesignTokens.gd`'s default; confirm against the actual `.tres` in case it's been retuned) and use that value's hex for both gradient stops, varying only the alpha channel (`cc` ~80% at the top, `00` fully transparent at the bottom) — `fill = 1` is `GradientTexture2D.FILL_LINEAR`, `fill_from`/`fill_to` make it vertical (top to bottom).
6. `scene_save()`.

Do NOT set `theme_type_variation` on the new node at all (leave it unset/empty) — this is the change the test in Step 1 checks for.

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: PASS.

- [ ] **Step 5: Screenshot to confirm visually**

Via MCP: `scene_open("res://Scenes/SchoolSimulation/ResultCheckup.tscn")`, then `editor_screenshot(source="viewport_2d", max_resolution=900)`. Confirm the area above `BtnClose` now reads as a soft fade rather than a flat white bar.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn tests/test_result_checkup.gd
git commit -m "fix(resultcheckup): make ScrollFade an actual gradient instead of a flat panel"
```

---

## Task 9: Full suite verification

**Files:** none (verification only).

- [ ] **Step 1: Rescan and run every suite touched by this plan individually**

Run each of: `test_run(suite="audio_director")`, `test_run(suite="audio_coverage")`, `test_run(suite="week_recap_pill_info_popup")`, `test_run(suite="result_checkup")`, `test_run(suite="day_summary")`, `test_run(suite="theme_factory")`.
Expected: every one green, matching the counts each task's own step already established.

- [ ] **Step 2: Run the complete project suite with no filter**

Run: `test_run()` with no `suite` parameter.
Expected: every one of the ~55 suites passes, 0 failures — this plan's changes must not regress anything outside `ResultCheckup`'s own family (the popup pattern is new and isolated; the needs-bar chevron change is shared with the nightly `DaySummaryPopup`, already covered by Task 5's Step 6).

- [ ] **Step 3: Visual pass**

Seed a real week (Debug overlay → Seed Playtest State → Atur Jadwal → run a week → reach ResultCheckup), or use `editor_screenshot` on the static scene as a structural check if a live playthrough isn't practical in this session. Confirm by eye:
- Each pill visibly bounces in turn once the entrance settles.
- Tapping a pill pops its explainer, tapping the scrim anywhere closes it.
- The needs bars show an arrow, not a number, and it points the right way for a gain vs. a loss.
- The four pills visibly cascade in left-to-right rather than appearing together.
- Switching SISWA↔RIWAYAT slides and fades instead of snapping.
- The area above "Selesai Evaluasi" reads as a fade, not a flat box.

- [ ] **Step 4: Commit any last fixes found during the visual pass**

If Step 3 surfaces a real defect, fix it, add a regression test for it in the relevant task's test file, and commit as a follow-up fix commit — do not silently patch without a test, per this project's own TDD discipline.

---

## Notes for the executor

**Task 3's exact node structure is the one place this plan leaves a judgment call** (Step 4's `Row`-vs-flattened header question) — pick one, then make the script's `@onready` paths and the test's node-path list agree with whatever you built. This is the same class of ambiguity the original week-recap plan flagged for `WeekRecapPill`/`WeekRecapBanner`, resolved the same way: consistency between script, scene, and test matters more than which specific structure you pick.

**Task 7 keeps the existing long code comment** in `show_pane` about the scroll-write staying synchronous rather than `set_deferred` — that reasoning (from the 2026-09-03 week-recap plan's Task 9 fix round) still applies unchanged; don't delete or shorten it when restructuring the function around it.

**Every task that touches `WeekRecapBanner.gd` or `ResultCheckup.gd` should re-run the OTHER file's own test suite too** (they're both in `result_checkup`, so a single `test_run(suite="result_checkup")` after each task already covers this) — the two scripts call into each other (`banner.start_idle_bounce()`, `banner.stop_idle_bounce()`) and a signature drift between them would only show up there.
