# Day-Passing Sky Cinematic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `BookClockWidget`'s procedural cat pocket-watch with a
full-screen cinematic in which a square sky texture rotates counter-clockwise
around a stationary school-on-a-hill foreground, reading as one school day
passing.

**Architecture:** The widget keeps its class name and its entire public API
(`set_day()`, `set_progress()`, `reset()`) so `SchoolDay.gd` drives it
unchanged. What changes is what it *is*: instead of a ~110 px tall `Control`
inside the `DayScreen` VBox that builds `TextureRect`s at runtime and paints
itself in `_draw()`, it becomes a full-rect backdrop node — a `.tscn` holding
two authored `TextureRect` layers, and a `@tool` script whose only job is
responsive geometry plus a progress→rotation mapping. `set_progress()` sets
rotation *directly* (never tweens); the caller in `SchoolDay.gd` already
drives it through `TRANS_QUAD` + `EASE_IN_OUT` tweens, and the widget adds its
own `smoothstep` on top so the sweep eases in and out even under a linear
driver.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` (`test_run` via the
`godot-ai` MCP server).

**Spec:** `docs/superpowers/mockups/day-transition-mockup.png` (the screen as
it should read) and `docs/superpowers/mockups/day-transition-mechanism.png`
(the rotation the arrows describe). Both are copied into place by Task 1.

## Global Constraints

- **Never hand-edit a `.tscn` while the editor is attached.** Every scene
  change in this plan goes through `scene_open` → `node_create` /
  `node_set_property` / `node_manage` / `batch_execute` → `scene_save`. The
  editor's in-memory copy wins and will silently overwrite a text edit.
- **Rescan after editing a `.gd`, before running tests:**
  `filesystem_manage(op="scan")`. `test_run` serves a stale autoload otherwise.
- **No `theme_override_*`.** Use a `ThemeFactory` type variation. The only
  accepted exception is a layout-only constant (`separation`, `margin_*`).
  Nothing in this plan should need either.
- **No visual built at runtime.** Static chrome is a node in the `.tscn`.
  Responsive geometry is a `@tool` script driven by documented `@export`
  knobs — that is the sanctioned pattern this widget uses.
- **Every script needs a `##` file header and a `##` line on every `@export`.**
  Enforced by `tests/test_script_documentation.gd`.
- **Test suites must be `@tool`, and no test may be a coroutine.** The runner
  does `suite.call(name)` without awaiting; an `await` silently aborts the
  test and reports "0 assertions".
- **Rotation direction is counter-clockwise on screen.** Godot's `rotation` is
  clockwise-positive with y down, so the sweep runs from `0°` to a *negative*
  angle. This matches the mechanism reference: the top-left of the sky travels
  down-left while the bottom-right travels up-right.
- **UI text is Indonesian; systems code is English.** Nothing in this plan adds
  user-visible text.
- Commits use Conventional Commits with a scope, e.g. `feat(school-day): …`.

## File Structure

| File | Responsibility |
|---|---|
| `Assets/Images/SchoolDay/transition_background.png` | The 1600×1599 square sky. Rotates. |
| `Assets/Images/SchoolDay/transition_foreground.png` | The 369×654 school-and-hill overlay. Stationary. |
| `docs/superpowers/mockups/day-transition-mockup.png` | Reference: the composited screen. |
| `docs/superpowers/mockups/day-transition-mechanism.png` | Reference: the rotation arrows. |
| `Scripts/SchoolSimulation/BookClockWidget.gd` | **Rewritten.** Responsive geometry + progress→rotation mapping. No drawing, no runtime node construction. |
| `Scenes/SchoolSimulation/BookClockWidget.tscn` | **Rewritten.** Full-rect `Control` + `SkyBackground` + `SchoolForeground` `TextureRect`s, textures assigned in the scene. |
| `Scenes/SchoolSimulation/SchoolDay.tscn` | **Modified.** Widget re-parented from `DayScreen` to the root, between `Background` and `DayScreen`. |
| `Scripts/SchoolSimulation/SchoolDay.gd` | **Modified.** Two node paths (`@onready` ref, `_DAY_CHROME_PATHS`). |
| `tests/test_sky_transition.gd` | **New suite.** Behavioral coverage of the mapping, geometry, and scene shape. |
| `tests/test_viewport_editability.gd` | **Modified.** `BASELINE` entry for `BookClockWidget.gd` drops 3 → 0. |
| `tests/test_school_day.gd` | **Modified.** Header comment: the widget script is `@tool` now. |

---

### Task 1: Import the assets and the reference mockups

Nothing here is code — but the rest of the plan cannot compile without the
imported textures, and the executor of a later task must be able to read the
mockups to judge their work.

**Files:**
- Create: `Assets/Images/SchoolDay/transition_background.png`
- Create: `Assets/Images/SchoolDay/transition_foreground.png`
- Create: `docs/superpowers/mockups/day-transition-mockup.png`
- Create: `docs/superpowers/mockups/day-transition-mechanism.png`

**Interfaces:**
- Consumes: nothing.
- Produces: two importable texture paths, used verbatim by Task 3 —
  `res://Assets/Images/SchoolDay/transition_background.png` and
  `res://Assets/Images/SchoolDay/transition_foreground.png`.

- [ ] **Step 1: Copy the four files into the project**

```bash
mkdir -p Assets/Images/SchoolDay
cp "/c/Users/user/Downloads/transition_background.png" Assets/Images/SchoolDay/transition_background.png
cp "/c/Users/user/Downloads/transition_foreground.png" Assets/Images/SchoolDay/transition_foreground.png
cp "/c/Users/user/Downloads/mockup_transition.png" docs/superpowers/mockups/day-transition-mockup.png
cp "/c/Users/user/Downloads/mechanissm.png" docs/superpowers/mockups/day-transition-mechanism.png
```

- [ ] **Step 2: Make the editor import them**

Call the MCP tool `filesystem_manage(op="scan")`, then wait for it to return.

- [ ] **Step 3: Verify the import produced `.import` sidecars**

```bash
ls Assets/Images/SchoolDay/
```

Expected: four entries — both `.png` files and both `.png.import` files. If
the `.import` files are missing, the scan did not complete; re-run Step 2.
Do not proceed without them — `load()` on an unimported texture returns
`null` and Task 3 will silently produce a blank screen.

- [ ] **Step 4: Confirm the dimensions are what the geometry assumes**

```bash
python -c "
import struct
for f in ['Assets/Images/SchoolDay/transition_background.png','Assets/Images/SchoolDay/transition_foreground.png']:
    d=open(f,'rb').read(32); print(f, *struct.unpack('>II', d[16:24]))
"
```

Expected exactly:
```
Assets/Images/SchoolDay/transition_background.png 1600 1599
Assets/Images/SchoolDay/transition_foreground.png 369 654
```

The background must be (near-)square — the cover-scale math in Task 2 assumes
the rotating layer is square. The foreground's 369×654 is 0.5642, within a
third of a percent of the project's 1080×1920 (0.5625), so
`STRETCH_KEEP_ASPECT_COVERED` crops it imperceptibly.

- [ ] **Step 5: Commit**

```bash
git add Assets/Images/SchoolDay docs/superpowers/mockups
git commit -m "feat(school-day): import the day-transition sky and school art

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Rewrite `BookClockWidget.gd` as the sky cinematic

The whole script is replaced. Everything the old file did — `_draw()`, the
procedural clock, the book fallbacks, the progress bar, `Image.create()` PNG
generation, `add_child()` of `TextureRect`s and a `Control` — goes away. What
survives is the three-method public API and nothing else.

**Files:**
- Modify (full rewrite): `Scripts/SchoolSimulation/BookClockWidget.gd`
- Create: `tests/test_sky_transition.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces, all on `class_name BookClockWidget extends Control`:
  - `func set_day(day_name: String) -> void` — stores the name, resets progress to 0.
  - `func set_progress(value: float) -> void` — clamps to 0..1, applies rotation immediately.
  - `func reset() -> void` — clears the name, resets progress to 0.
  - `func day_name() -> String` — the stored weekday.
  - `func progress() -> float` — the stored raw (un-eased) progress.
  - `func eased_progress() -> float` — progress after the smoothstep.
  - `func current_rotation_degrees() -> float` — the sky angle for the current progress.
  - `const SKY_NODE := "SkyBackground"`, `const FOREGROUND_NODE := "SchoolForeground"` — the child names Task 3's scene must use.
  - `@export` knobs: `start_rotation_degrees`, `total_rotation_degrees`, `ease_in_out`, `sky_cover_margin`.

- [ ] **Step 1: Write the failing test suite**

Create `tests/test_sky_transition.gd` with exactly this content:

```gdscript
@tool
extends McpTestSuite

## The day-passing cinematic on SchoolDay: a square sky texture that
## rotates counter-clockwise around a stationary school foreground.
##
## Everything here is synchronous by construction. set_progress() applies
## rotation directly rather than tweening it, and set_size() fires
## NOTIFICATION_RESIZED immediately, so no test in this suite needs to
## await -- which the runner could not honour anyway (it calls
## suite.call(name) without awaiting).

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _WIDGET_SCENE := "res://Scenes/SchoolSimulation/BookClockWidget.tscn"
const _WIDGET_SCRIPT := "res://Scripts/SchoolSimulation/BookClockWidget.gd"

## The project's design resolution. The cover-scale assertions below are
## written against it.
const _DESIGN_SIZE := Vector2(1080, 1920)


func suite_name() -> String:
	return "sky_transition"


func _instantiate(path: String) -> Control:
	var scene: PackedScene = load(path)
	var inst := scene.instantiate() as Control
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


## A widget sized to the design resolution, so geometry is deterministic.
func _sized_widget() -> Control:
	var w := _instantiate(_WIDGET_SCENE)
	w.size = _DESIGN_SIZE
	return w


# ------------------------------------------------ scene shape

func test_scene_has_both_named_layers() -> void:
	var w := _instantiate(_WIDGET_SCENE)
	var sky := w.get_node_or_null("SkyBackground")
	var fg := w.get_node_or_null("SchoolForeground")
	assert_not_null(sky, "the rotating sky layer must be named SkyBackground")
	assert_not_null(fg, "the stationary layer must be named SchoolForeground")
	assert_true(sky is TextureRect, "SkyBackground must be a TextureRect")
	assert_true(fg is TextureRect, "SchoolForeground must be a TextureRect")


func test_both_layers_carry_their_texture_from_the_scene() -> void:
	var w := _instantiate(_WIDGET_SCENE)
	var sky: TextureRect = w.get_node("SkyBackground")
	var fg: TextureRect = w.get_node("SchoolForeground")
	assert_not_null(sky.texture, "the sky texture must be assigned in the .tscn, not at runtime")
	assert_not_null(fg.texture, "the foreground texture must be assigned in the .tscn, not at runtime")


func test_the_foreground_is_drawn_over_the_sky() -> void:
	var w := _instantiate(_WIDGET_SCENE)
	var sky_idx := w.get_node("SkyBackground").get_index()
	var fg_idx := w.get_node("SchoolForeground").get_index()
	assert_true(fg_idx > sky_idx,
		"SchoolForeground must come after SkyBackground so it paints on top")


func test_no_layer_swallows_input() -> void:
	# A full-screen Control defaults to MOUSE_FILTER_STOP, which would eat
	# SchoolDay's tap-to-continue. All three nodes must ignore the mouse.
	var w := _instantiate(_WIDGET_SCENE)
	assert_eq(w.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the cinematic root must not intercept taps")
	for child_name in ["SkyBackground", "SchoolForeground"]:
		var c: Control = w.get_node(child_name)
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			child_name + " must not intercept taps")


# ------------------------------------------------ progress -> rotation

func test_progress_zero_is_the_start_angle() -> void:
	var w := _sized_widget()
	w.call("set_progress", 0.0)
	assert_eq(w.call("current_rotation_degrees"), w.get("start_rotation_degrees"),
		"progress 0 must sit exactly on the authored morning pose")


func test_progress_one_is_the_full_sweep() -> void:
	var w := _sized_widget()
	w.call("set_progress", 1.0)
	var expected: float = w.get("start_rotation_degrees") + w.get("total_rotation_degrees")
	assert_true(absf(w.call("current_rotation_degrees") - expected) < 0.001,
		"progress 1 must land exactly on start + total")


func test_the_sweep_turns_counter_clockwise() -> void:
	# Godot's rotation is clockwise-positive with y down, so a
	# counter-clockwise sweep must end at a smaller angle than it started.
	var w := _sized_widget()
	w.call("set_progress", 0.0)
	var start: float = w.call("current_rotation_degrees")
	w.call("set_progress", 1.0)
	assert_true(w.call("current_rotation_degrees") < start,
		"the sky must turn counter-clockwise, matching the mechanism reference")


func test_rotation_is_monotone_across_the_day() -> void:
	var w := _sized_widget()
	var previous: float = INF
	for i in range(21):
		w.call("set_progress", float(i) / 20.0)
		var current: float = w.call("current_rotation_degrees")
		assert_true(current <= previous + 0.001,
			"the sky must never turn back on itself at progress %f" % (float(i) / 20.0))
		previous = current


func test_the_sweep_eases_in_and_out() -> void:
	# smoothstep's defining property: it is slower than linear in the
	# first quarter, faster than linear across the middle.
	var w := _sized_widget()
	assert_true(w.get("ease_in_out"), "the widget must ship with easing on")
	w.call("set_progress", 0.25)
	assert_true(w.call("eased_progress") < 0.25,
		"the first quarter of the day must move less than linear (ease in)")
	w.call("set_progress", 0.75)
	assert_true(w.call("eased_progress") > 0.75,
		"the last quarter must have already covered more than linear (ease out)")
	w.call("set_progress", 0.5)
	assert_true(absf(float(w.call("eased_progress")) - 0.5) < 0.001,
		"the easing must stay symmetric about the midpoint")


func test_progress_is_clamped() -> void:
	var w := _sized_widget()
	w.call("set_progress", -3.0)
	assert_eq(w.call("progress"), 0.0, "progress must clamp at 0")
	w.call("set_progress", 42.0)
	assert_eq(w.call("progress"), 1.0, "progress must clamp at 1")


func test_the_sky_node_actually_receives_the_rotation() -> void:
	var w := _sized_widget()
	w.call("set_progress", 1.0)
	var sky: TextureRect = w.get_node("SkyBackground")
	assert_true(absf(sky.rotation_degrees - float(w.call("current_rotation_degrees"))) < 0.001,
		"set_progress must push the angle onto SkyBackground immediately")


func test_the_foreground_never_rotates() -> void:
	var w := _sized_widget()
	w.call("set_progress", 0.6)
	var fg: TextureRect = w.get_node("SchoolForeground")
	assert_eq(fg.rotation, 0.0, "the school must stay put while the sky turns")


# ------------------------------------------------ lifecycle

func test_set_day_starts_the_sweep_from_morning() -> void:
	var w := _sized_widget()
	w.call("set_progress", 0.8)
	w.call("set_day", "Senin")
	assert_eq(w.call("progress"), 0.0, "a new day must restart the sweep")
	assert_eq(w.call("day_name"), "Senin", "set_day must record the weekday")


func test_reset_clears_day_and_progress() -> void:
	var w := _sized_widget()
	w.call("set_day", "Jumat")
	w.call("set_progress", 0.9)
	w.call("reset")
	assert_eq(w.call("progress"), 0.0, "reset must rewind the sweep")
	assert_eq(w.call("day_name"), "", "reset must clear the weekday")


# ------------------------------------------------ responsive geometry

func test_the_sky_is_square_and_centred() -> void:
	var w := _sized_widget()
	var sky: TextureRect = w.get_node("SkyBackground")
	assert_true(absf(sky.size.x - sky.size.y) < 0.001,
		"the rotating layer must be square or it will wobble")
	var sky_centre := sky.position + sky.size * 0.5
	var widget_centre := _DESIGN_SIZE * 0.5
	assert_true(sky_centre.distance_to(widget_centre) < 0.001,
		"the sky must be centred on the screen, or it will orbit off-axis")


func test_the_sky_pivots_about_its_own_centre() -> void:
	var w := _sized_widget()
	var sky: TextureRect = w.get_node("SkyBackground")
	assert_true(sky.pivot_offset.distance_to(sky.size * 0.5) < 0.001,
		"rotating about anything but the centre would swing the sky off-screen")


func test_the_sky_covers_the_screen_at_every_angle() -> void:
	# The worst case for a rotating square is its inscribed circle: any
	# point further from the centre than size/2 can rotate out of frame.
	# So the inscribed circle must reach the screen's corners.
	var w := _sized_widget()
	var sky: TextureRect = w.get_node("SkyBackground")
	var inscribed_radius: float = sky.size.x * 0.5
	var corner_distance: float = _DESIGN_SIZE.length() * 0.5
	assert_true(inscribed_radius >= corner_distance,
		"a corner of the page would show through at some angle: radius %f < %f"
			% [inscribed_radius, corner_distance])


func test_the_foreground_fills_the_screen_exactly() -> void:
	var w := _sized_widget()
	var fg: TextureRect = w.get_node("SchoolForeground")
	assert_eq(fg.position, Vector2.ZERO, "the foreground must start at the origin")
	assert_eq(fg.size, _DESIGN_SIZE, "the foreground must fill the screen")


func test_geometry_follows_a_resize() -> void:
	var w := _sized_widget()
	w.size = Vector2(720, 1280)
	var sky: TextureRect = w.get_node("SkyBackground")
	var sky_centre := sky.position + sky.size * 0.5
	assert_true(sky_centre.distance_to(Vector2(360, 640)) < 0.001,
		"the sky must re-centre when the viewport changes")
	assert_true(sky.size.x * 0.5 >= Vector2(720, 1280).length() * 0.5,
		"the sky must re-cover when the viewport changes")


# ------------------------------------------------ the old widget is gone

func test_no_procedural_drawing_survives() -> void:
	var src := FileAccess.get_file_as_string(_WIDGET_SCRIPT)
	for banned in ["func _draw(", "draw_circle(", "draw_arc(", "Image.create(", "save_png("]:
		assert_false(src.contains(banned),
			"the cinematic is authored art now, not procedural: found " + banned)


func test_no_runtime_node_construction_survives() -> void:
	var src := FileAccess.get_file_as_string(_WIDGET_SCRIPT)
	assert_false(src.contains("add_child("),
		"both layers live in the .tscn; nothing may be built at runtime")


func test_every_export_is_documented() -> void:
	# Mirrors tests/test_script_documentation.gd's rule, checked here too
	# so this suite fails loudly if a knob is added without a ## line.
	var lines := FileAccess.get_file_as_string(_WIDGET_SCRIPT).split("\n")
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("@export") \
				and not lines[i].strip_edges().begins_with("@export_group"):
			var previous := lines[i - 1].strip_edges() if i > 0 else ""
			assert_true(previous.begins_with("##"),
				"every @export needs a ## line above it, missing on: " + lines[i].strip_edges())
```

- [ ] **Step 2: Run the suite to verify it fails**

Call `filesystem_manage(op="scan")`, then
`test_run(suite="sky_transition")`.

Expected: FAIL. The scene still holds the old single-`Control` layout, so
`test_scene_has_both_named_layers` fails on a null `SkyBackground`, and the
mapping tests fail on missing methods. This is the point — the suite is
pinning behaviour that does not exist yet.

- [ ] **Step 3: Replace `Scripts/SchoolSimulation/BookClockWidget.gd` entirely**

Overwrite the file with exactly this:

```gdscript
@tool
extends Control
class_name BookClockWidget

## The day-passing cinematic behind the SchoolDay screen.
##
## Two full-screen layers: a square sky texture that rotates about the
## screen centre, and a stationary school-on-a-hill foreground painted
## over it. As the school day advances, set_progress() turns the sky so
## the bright half sweeps away and the night half swings in, and the
## whole screen reads as one day passing.
##
## This file used to draw a procedural cat pocket-watch. It no longer
## draws anything: both layers are authored TextureRects in the scene,
## and all this script does is responsive geometry plus the
## progress-to-rotation mapping. The name and the public API
## (set_day / set_progress / reset) are unchanged so SchoolDay.gd drives
## it exactly as before.
##
## Direction: Godot's rotation is clockwise-positive with y down, so the
## counter-clockwise sweep the mechanism reference asks for runs from 0
## to a NEGATIVE angle. See docs/superpowers/mockups/
## day-transition-mechanism.png.
##
## @tool, so the composited cinematic previews live in the editor
## viewport. Nothing in _ready() has a side effect outside this widget's
## own children, so it needs no Engine.is_editor_hint() gate.

## Child that holds the rotating sky. Task 3's scene must use this name.
const SKY_NODE := "SkyBackground"
## Child that holds the stationary school and hill.
const FOREGROUND_NODE := "SchoolForeground"

@export_group("Motion")
## The sky's angle at progress 0.0, in degrees -- its "morning" pose.
@export var start_rotation_degrees: float = 0.0:
	set(value):
		start_rotation_degrees = value
		_apply_rotation()
## Degrees swept across one whole school day. Negative turns the sky
## counter-clockwise on screen, which is the direction the mechanism
## reference's arrows describe. -180 carries the bright half of the sky
## all the way across and brings the night half down in its place.
@export var total_rotation_degrees: float = -180.0:
	set(value):
		total_rotation_degrees = value
		_apply_rotation()
## When true, progress runs through smoothstep before it maps to an
## angle, so the sweep eases in and out even under a linear driver.
## SchoolDay.gd also eases its own tween; the two compose harmlessly.
@export var ease_in_out: bool = true:
	set(value):
		ease_in_out = value
		_apply_rotation()

@export_group("Layout")
## Slack multiplied into the sky's cover size. The maths already covers
## the screen exactly; this absorbs rounding on odd aspect ratios so a
## corner of the page can never flash through mid-rotation.
@export var sky_cover_margin: float = 1.02:
	set(value):
		sky_cover_margin = value
		_fit_layers()

# ── Internal state ────────────────────────────────────────────────────────────
var _progress: float = 0.0
var _day_name: String = ""


func _ready() -> void:
	_fit_layers()
	_apply_rotation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_layers()


# ── Public API ────────────────────────────────────────────────────────────────

## Starts a fresh day. Records the weekday and rewinds the sky to morning.
func set_day(day_name_in: String) -> void:
	_day_name = day_name_in
	set_progress(0.0)


## Places the sky for a point in the school day, 0.0 (morning) to 1.0
## (night). Applies the angle immediately rather than tweening it -- the
## caller owns the timing, and already eases it.
func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_apply_rotation()


## Rewinds to morning and forgets the weekday.
func reset() -> void:
	_day_name = ""
	set_progress(0.0)


## The weekday currently being simulated, as handed in by set_day().
func day_name() -> String:
	return _day_name


## Raw progress through the day, 0.0 to 1.0, before easing.
func progress() -> float:
	return _progress


## Progress after the easing curve -- what actually drives the angle.
func eased_progress() -> float:
	if ease_in_out:
		return smoothstep(0.0, 1.0, _progress)
	return _progress


## The sky's angle, in degrees, for the current progress.
func current_rotation_degrees() -> float:
	return start_rotation_degrees + eased_progress() * total_rotation_degrees


# ── Internals ─────────────────────────────────────────────────────────────────

func _sky_layer() -> TextureRect:
	return get_node_or_null(SKY_NODE) as TextureRect


func _foreground_layer() -> TextureRect:
	return get_node_or_null(FOREGROUND_NODE) as TextureRect


func _apply_rotation() -> void:
	var sky := _sky_layer()
	if sky != null:
		sky.rotation_degrees = current_rotation_degrees()


## Sizes and centres both layers for the current control rect.
##
## The sky is grown to a square whose side equals the screen's diagonal.
## That makes its INSCRIBED circle reach the screen's corners, and the
## inscribed circle is exactly the region a rotating square is guaranteed
## to keep covered -- so no corner can ever swing into view. At the
## project's 1080x1920 that is a 2203 px square from a 1600 px source,
## i.e. about 1.38x, which the art is drawn loose enough to take.
func _fit_layers() -> void:
	var rect := size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return

	var sky := _sky_layer()
	if sky != null:
		var side: float = rect.length() * sky_cover_margin
		sky.size = Vector2(side, side)
		sky.position = (rect - sky.size) * 0.5
		sky.pivot_offset = sky.size * 0.5

	var foreground := _foreground_layer()
	if foreground != null:
		foreground.position = Vector2.ZERO
		foreground.size = rect
```

- [ ] **Step 4: Run the suite — the mapping tests should now pass**

Call `filesystem_manage(op="scan")`, then
`test_run(suite="sky_transition")`.

Expected: the four scene-shape tests and every geometry test still FAIL
(`SkyBackground` does not exist yet — Task 3 creates it), but
`test_no_procedural_drawing_survives`, `test_no_runtime_node_construction_survives`
and `test_every_export_is_documented` PASS. The progress/lifecycle tests
(`test_progress_zero_is_the_start_angle`, `test_the_sweep_eases_in_and_out`,
`test_progress_is_clamped`, `test_set_day_starts_the_sweep_from_morning`,
`test_reset_clears_day_and_progress`, `test_the_sweep_turns_counter_clockwise`,
`test_rotation_is_monotone_across_the_day`) also PASS — they read the
mapping, not the nodes.

If a mapping test fails, fix the script before moving on. Do not proceed to
Task 3 to "make the rest go green".

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/BookClockWidget.gd tests/test_sky_transition.gd
git commit -m "feat(school-day): turn BookClockWidget into a rotating sky cinematic

Replaces the procedural cat pocket-watch with a progress-to-rotation
mapping over two authored layers. The public API is unchanged, so
SchoolDay.gd still drives it as before.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Rebuild `BookClockWidget.tscn` with the two authored layers

**Files:**
- Modify (rebuild through the editor): `Scenes/SchoolSimulation/BookClockWidget.tscn`

**Interfaces:**
- Consumes: the two texture paths from Task 1; `SKY_NODE` / `FOREGROUND_NODE`
  and the `@export` knobs from Task 2.
- Produces: a `BookClockWidget.tscn` whose root is a full-rect
  `MOUSE_FILTER_IGNORE` `Control` with children `SkyBackground` then
  `SchoolForeground`, both `TextureRect`s with their texture assigned in the
  scene. Task 4 instances this scene.

**Critical:** do not hand-edit this `.tscn`. The editor's cached copy wins and
the next `scene_save` overwrites the text. Everything below goes through MCP
calls.

**Also critical:** the scene's existing `uid://cx6n3hr2evpn1` must survive.
`SchoolDay.tscn` references this scene by path, not uid, so a changed uid
will not break the load — but `tests/test_project_hygiene.gd` fails the build
on a stale `ext_resource` uid, so opening and re-saving the existing scene
(rather than creating a new file) is the safe route. The steps below edit in
place.

- [ ] **Step 1: Open the scene and delete the old root's leftovers**

```
scene_open(path="res://Scenes/SchoolSimulation/BookClockWidget.tscn")
```

The scene is a bare `Control` with the script attached and no children (the
old widget built its children at runtime). There is nothing to delete. Confirm
with:

```
scene_get_hierarchy()
```

Expected: a single node `BookClockWidget` of type `Control`, no children. If
children *do* exist (a stale editor session may have persisted the
runtime-built `InsideDial` / `CoverPlate` / `OuterFrame`), delete each with
`node_manage(op="delete_node", ...)` before continuing.

- [ ] **Step 2: Reconfigure the root and create both layers in one batch**

```
batch_execute(commands=[
  {"type": "set_property", "node_path": ".", "property": "custom_minimum_size", "value": {"x": 0, "y": 0}},
  {"type": "set_property", "node_path": ".", "property": "anchor_left",   "value": 0},
  {"type": "set_property", "node_path": ".", "property": "anchor_top",    "value": 0},
  {"type": "set_property", "node_path": ".", "property": "anchor_right",  "value": 1},
  {"type": "set_property", "node_path": ".", "property": "anchor_bottom", "value": 1},
  {"type": "set_property", "node_path": ".", "property": "mouse_filter",  "value": 2},
  {"type": "set_property", "node_path": ".", "property": "clip_contents", "value": true},

  {"type": "create_node", "parent_path": ".", "node_type": "TextureRect", "node_name": "SkyBackground"},
  {"type": "set_property", "node_path": "SkyBackground", "property": "texture",
   "value": "res://Assets/Images/SchoolDay/transition_background.png"},
  {"type": "set_property", "node_path": "SkyBackground", "property": "expand_mode",  "value": 1},
  {"type": "set_property", "node_path": "SkyBackground", "property": "stretch_mode", "value": 6},
  {"type": "set_property", "node_path": "SkyBackground", "property": "mouse_filter", "value": 2},

  {"type": "create_node", "parent_path": ".", "node_type": "TextureRect", "node_name": "SchoolForeground"},
  {"type": "set_property", "node_path": "SchoolForeground", "property": "texture",
   "value": "res://Assets/Images/SchoolDay/transition_foreground.png"},
  {"type": "set_property", "node_path": "SchoolForeground", "property": "expand_mode",  "value": 1},
  {"type": "set_property", "node_path": "SchoolForeground", "property": "stretch_mode", "value": 6},
  {"type": "set_property", "node_path": "SchoolForeground", "property": "mouse_filter", "value": 2}
])
```

Notes on the magic numbers, all of them Godot 4.6 enum values:
- `mouse_filter = 2` is `Control.MOUSE_FILTER_IGNORE`. Non-negotiable: a
  full-screen `Control` defaults to `MOUSE_FILTER_STOP` and would swallow
  SchoolDay's tap-to-continue.
- `expand_mode = 1` is `TextureRect.EXPAND_IGNORE_SIZE`, so the script's
  explicit `size` wins over the texture's natural size.
- `stretch_mode = 6` is `TextureRect.STRETCH_KEEP_ASPECT_COVERED`, so neither
  layer letterboxes.
- `clip_contents = true` on the root keeps the oversized sky from painting
  outside the widget's rect.
- `create_node` appends, so `SkyBackground` lands at index 0 and
  `SchoolForeground` at index 1 — the paint order the plan wants. Do not
  reorder.
- Numbers must be unquoted. `anchors_preset` is inert; set the four anchors,
  which the batch does.

- [ ] **Step 3: Save the scene**

```
scene_save()
```

- [ ] **Step 4: Run the suite — it should now be fully green**

Call `filesystem_manage(op="scan")`, then
`test_run(suite="sky_transition")`.

Expected: PASS, all tests. If `test_the_sky_covers_the_screen_at_every_angle`
fails, `_fit_layers()` did not run — check that the root really is full-rect
anchored so it receives a non-zero size.

If `test_both_layers_carry_their_texture_from_the_scene` fails with a null
texture, the import from Task 1 did not complete; re-run
`filesystem_manage(op="scan")` and re-save the scene.

- [ ] **Step 5: Commit**

```bash
git add Scenes/SchoolSimulation/BookClockWidget.tscn
git commit -m "feat(school-day): author the sky and school layers in the widget scene

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Promote the widget to a full-screen backdrop in SchoolDay

The cinematic is the whole screen now, so it can no longer live as a ~110 px
row inside the `DayScreen` VBox. It moves to the `SchoolDay` root, between
`Background` and `DayScreen`, so the day's labels and bars read over it.

**Files:**
- Modify (through the editor): `Scenes/SchoolSimulation/SchoolDay.tscn`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:86`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:679-685`

**Interfaces:**
- Consumes: the `BookClockWidget.tscn` from Task 3.
- Produces: the widget reachable at `$BookClockWidget` from `SchoolDay.gd`.
  The three call sites (`SchoolDay.gd:329`, `:330`, `:366`, `:386`) are
  untouched — they go through `book_clock_widget`, which is what gets
  repointed.

- [ ] **Step 1: Write the failing test**

Append these two tests to `tests/test_sky_transition.gd`:

```gdscript
# ------------------------------------------------ placement in SchoolDay

const _SCHOOL_DAY_SCENE := "res://Scenes/SchoolSimulation/SchoolDay.tscn"
const _SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"


func test_the_cinematic_is_a_full_screen_backdrop_not_a_vbox_row() -> void:
	var day := _instantiate(_SCHOOL_DAY_SCENE)
	assert_null(day.get_node_or_null("DayScreen/BookClockWidget"),
		"the cinematic must no longer be a row inside the DayScreen VBox")
	var widget := day.get_node_or_null("BookClockWidget")
	assert_not_null(widget, "the cinematic must sit on the SchoolDay root")
	var background := day.get_node_or_null("Background")
	var day_screen := day.get_node_or_null("DayScreen")
	assert_true(widget.get_index() > background.get_index(),
		"the cinematic must paint over the page background")
	assert_true(widget.get_index() < day_screen.get_index(),
		"the day's labels and bars must read over the cinematic")


func test_school_day_points_at_the_new_path() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_false(src.contains("DayScreen/BookClockWidget"),
		"no reference to the old VBox path may survive")
	assert_true(src.contains("$BookClockWidget"),
		"the @onready ref must point at the root-level node")
```

`assert_null` is not in `McpTestSuite`. Use this instead in the first test:

```gdscript
	assert_true(day.get_node_or_null("DayScreen/BookClockWidget") == null,
		"the cinematic must no longer be a row inside the DayScreen VBox")
```

- [ ] **Step 2: Run it to verify it fails**

`filesystem_manage(op="scan")`, then `test_run(suite="sky_transition")`.

Expected: both new tests FAIL — the widget is still at
`DayScreen/BookClockWidget` and the script still names that path.

- [ ] **Step 3: Move the node in SchoolDay.tscn**

The plugin cannot re-parent a node, so this is delete-then-recreate. Note the
old node carried `unique_id=337990511`; the recreated node gets a fresh one,
which is expected and harmless.

```
scene_open(path="res://Scenes/SchoolSimulation/SchoolDay.tscn")
```

```
node_manage(op="delete_node", node_path="DayScreen/BookClockWidget")
```

Then create the instance on the root. `node_create` appends, so it lands last
and must be moved to index 1 (directly after `Background`, before
`DayScreen`):

```
node_create(parent_path=".",
            scene_path="res://Scenes/SchoolSimulation/BookClockWidget.tscn",
            node_name="BookClockWidget")
```

```
batch_execute(commands=[
  {"type": "set_property", "node_path": "BookClockWidget", "property": "anchor_left",   "value": 0},
  {"type": "set_property", "node_path": "BookClockWidget", "property": "anchor_top",    "value": 0},
  {"type": "set_property", "node_path": "BookClockWidget", "property": "anchor_right",  "value": 1},
  {"type": "set_property", "node_path": "BookClockWidget", "property": "anchor_bottom", "value": 1},
  {"type": "set_property", "node_path": "BookClockWidget", "property": "mouse_filter",  "value": 2},
  {"type": "move_node",    "node_path": "BookClockWidget", "to_index": 1}
])
```

```
scene_save()
```

Verify with `scene_get_hierarchy()`: the root's children must read
`Background`, `BookClockWidget`, `DayScreen`, then the rest, in that order.

- [ ] **Step 4: Repoint the script**

In `Scripts/SchoolSimulation/SchoolDay.gd`, line 86, change:

```gdscript
@onready var book_clock_widget: Control   = $DayScreen/BookClockWidget
```

to:

```gdscript
@onready var book_clock_widget: Control   = $BookClockWidget
```

Then in the `_DAY_CHROME_PATHS` block at lines 679-685, **delete** the
`"DayScreen/BookClockWidget",` entry so the block reads:

```gdscript
## Nodes on the DayScreen that would otherwise read through the summary
## popup's scrim and collide with the card stack. Paths, not @onready refs,
## because several are optional depending on how far the day got.
##
## The sky cinematic is deliberately absent: it is the screen's backdrop
## now, not chrome, and should keep turning behind the summary's scrim.
const _DAY_CHROME_PATHS := [
	"DayScreen/DayNumberLabel",
	"DayScreen/DayLabel",
	"DayScreen/ProgressBar",
	"DayScreen/StatusLabel",
]
```

Do not replace it with `"BookClockWidget"` — hiding the backdrop mid-summary
would flash the page colour through.

- [ ] **Step 5: Run the suite and the SchoolDay suite**

`filesystem_manage(op="scan")`, then:

```
test_run(suite="sky_transition")
test_run(suite="school_day")
```

Expected: both PASS. `school_day` exercises `_DAY_CHROME_PATHS` and the scene
shape, so a regression there means the re-parent went wrong.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/SchoolDay.tscn Scripts/SchoolSimulation/SchoolDay.gd tests/test_sky_transition.gd
git commit -m "feat(school-day): promote the day cinematic to a full-screen backdrop

Moves BookClockWidget out of the DayScreen VBox onto the SchoolDay root,
between Background and DayScreen, and drops it from _DAY_CHROME_PATHS so
the sky keeps turning behind the day-summary scrim.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Lower the editability ratchet and clear the dead placeholders

The old widget was carrying 3 units of runtime-visual-construction debt and
generating two PNGs into the project on every `_ready()`. Both are gone; the
ratchet and the filesystem should say so.

**Files:**
- Modify: `tests/test_viewport_editability.gd:80`
- Modify: `tests/test_school_day.gd:31-36` (header comment only)
- Delete: `Assets/Images/UI/Placeholders/clock_outer.png` (+ `.import`)
- Delete: `Assets/Images/UI/Placeholders/clock_inside.png` (+ `.import`)

**Interfaces:**
- Consumes: the rewritten script from Task 2.
- Produces: nothing new. This task only removes debt.

- [ ] **Step 1: Confirm nothing else references the generated placeholders**

```bash
grep -rn "clock_outer\|clock_inside" --include="*.gd" --include="*.tscn" --include="*.tres" .
```

Expected: no matches. Task 2 deleted the only two references (both inside
`_draw_clock`). If anything *does* match, stop and report it rather than
deleting the files.

- [ ] **Step 2: Delete the generated placeholder PNGs**

```bash
rm -f Assets/Images/UI/Placeholders/clock_outer.png Assets/Images/UI/Placeholders/clock_outer.png.import Assets/Images/UI/Placeholders/clock_inside.png Assets/Images/UI/Placeholders/clock_inside.png.import
```

These were written at runtime by `generate_png_placeholders()`, which no
longer exists. If the files were never committed, this is a no-op — that is
fine.

- [ ] **Step 3: Lower the BASELINE**

In `tests/test_viewport_editability.gd`, line 80, change:

```gdscript
	"res://Scripts/SchoolSimulation/BookClockWidget.gd": 3,
```

to:

```gdscript
	"res://Scripts/SchoolSimulation/BookClockWidget.gd": 0,
```

Do not delete the line — the ratchet reads a per-file count, and 0 is the
record that this file is now clean.

- [ ] **Step 4: Correct the stale note in the SchoolDay suite**

In `tests/test_school_day.gd`, the header comment at lines 31-36 currently
claims none of the scripts it covers is `@tool`. `BookClockWidget.gd` now is.
Replace that bullet:

```
##  * None of these scripts is @tool, so _ready() does not fire for an
##    editor-instantiated scene. Every assertion here therefore reads
##    either scene-declared state or script source text, never
##    runtime-built state. (Verified empirically: SchoolDay._ready()
##    calls start_simulation(), which would build a StudentManager off
##    GameState -- it does not run here.)
```

with:

```
##  * SchoolDay.gd is not @tool, so its _ready() does not fire for an
##    editor-instantiated scene. Every assertion here therefore reads
##    either scene-declared state or script source text, never
##    runtime-built state. (Verified empirically: SchoolDay._ready()
##    calls start_simulation(), which would build a StudentManager off
##    GameState -- it does not run here.) BookClockWidget.gd IS @tool as
##    of the 2026-09-03 sky cinematic, but its _ready() only lays out its
##    own two children, so nothing here is disturbed.
```

- [ ] **Step 5: Run the whole suite**

`filesystem_manage(op="scan")`, then `test_run()` with no suite filter.

Expected: every suite green. Compare the totals against the last known-good
figures in CLAUDE.md (45 suites, 568 tests) plus this plan's new suite —
the count should have grown by the number of tests in
`tests/test_sky_transition.gd`, and nothing should have gone red.

If `test_viewport_editability` fails claiming a count *below* baseline, that
is the ratchet telling you to lower the number further — set it to whatever
it reports and re-run.

- [ ] **Step 6: Look at it**

Tests cannot judge whether the day labels stay readable over a photographic
sky. Seed and screenshot:

1. Run the project (`project_run`).
2. Open the debug overlay (`F1`, or 5 taps top-right) → General tab →
   **⚡ Seed Playtest State**.
3. The seed does **not** fill `day_schedules`, so go through Atur Jadwal and
   assign a week before SchoolDay will simulate. Then let a day run.
4. `editor_screenshot` at roughly 25%, 50% and 90% through a day.

Check three things and report them:
- Does a corner of the page ever show through as the sky turns? (It should
  not — if it does, raise `sky_cover_margin`.)
- Does the sweep read as a day passing, or does 180° feel like too much or
  too little? (Tune `total_rotation_degrees`.)
- Are `DayNumberLabel`, `DayLabel` and `StatusLabel` still legible over the
  clouds? If not, that is a follow-up — the right fix is a `Scrim` type
  variation behind `DayScreen`, not a `theme_override_*`.

- [ ] **Step 7: Commit**

```bash
git add tests/test_viewport_editability.gd tests/test_school_day.gd Assets/Images/UI/Placeholders
git commit -m "chore(school-day): clear the book-clock's editability debt

BookClockWidget builds nothing at runtime any more, so its BASELINE
entry drops 3 -> 0 and the PNGs it used to generate are gone.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notes and deliberate decisions

**The name stays `BookClockWidget`.** It is a semantic lie now — there is no
book and no clock — but renaming it would touch `SchoolDay.tscn`'s
`ext_resource`, `SchoolDay.gd`, two test suites and the editability BASELINE
for zero behavioural gain, and this project has a standing convention of
leaving load-bearing names alone (`loby.gd`, `koprasi.gd`). If you want the
rename, do it as its own commit after this plan lands, not inside it.

**Easing is applied twice, on purpose.** `SchoolDay.gd` tweens `set_progress`
with `TRANS_QUAD` + `EASE_IN_OUT` across each of the day's two phases, and the
widget then runs `smoothstep` over the value it receives. The composition is
smooth and slightly more pronounced at the ends than either alone. If it reads
as too sluggish at the start of a day, turn the widget's `ease_in_out` off
rather than touching `SchoolDay.gd` — the caller's easing is shared with the
progress bar and the decay bars.

**The day is driven in two phases with an event roll between them.** Progress
runs 0 → `trigger_pct` (a random 50-80%), the event fires, then
`trigger_pct` → 100%. The sky therefore pauses mid-sweep while an event
overlay is up. That is correct and reads fine — the day is genuinely paused.

**`Background` (SimulationBackground.gd) is now hidden** behind an opaque
full-screen cinematic. It is left in place because `SchoolDay.gd` still tweens
its `bg_color` and `pattern_type` per day, and other tests read it. Removing
it is a separate cleanup and is not part of this plan.

## Self-review

- **Spec coverage.** "The whole cinematic where the background rotates around
  the foreground" → Tasks 2-4. "Simulating a day passing" → the −180° sweep,
  Task 2. "Ease in and out" → `ease_in_out`/`smoothstep`, pinned by
  `test_the_sweep_eases_in_and_out`. Rotation direction from the mechanism
  image → pinned by `test_the_sweep_turns_counter_clockwise`. "The mockup is
  the mobile screen preview" (i.e. full-screen, not a widget) → Task 4 plus
  `test_the_cinematic_is_a_full_screen_backdrop_not_a_vbox_row`.
- **Placeholder scan.** No TBDs. Every code step carries the literal file
  content or the literal MCP call. Every test step names the expected result.
- **Type consistency.** `SKY_NODE`/`FOREGROUND_NODE` ("SkyBackground",
  "SchoolForeground") are defined in Task 2 and used as the literal node names
  in Task 3 and in every test. `set_progress`/`set_day`/`reset` keep the
  signatures `SchoolDay.gd:329-330,366,386` already call. `day_name()` is a
  method and `_day_name` the field, so the `set_day(day_name_in: String)`
  parameter is renamed to avoid shadowing.
