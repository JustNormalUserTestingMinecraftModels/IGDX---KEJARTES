# Tray gestures, confetti fireworks and the real soundtrack — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans`
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking. Do **not** switch to subagent-driven development: the Godot AI
> bridge is single-client, so a subagent that connects displaces this session's
> editor and gets nothing itself.

**Goal:** Make the koperasi basket tray draggable and tap-to-return, replace
the per-star particle spray with three authored confetti fireworks, wire the
collaborator's 49 real sounds behind AudioDirector's export slots, make the
Android back button do what each screen's own back button does, pin the
already-shipped lobby blink with tests, and clear the theme-override debt on
the screens this branch touches.

**Architecture:** Gestures are classified by **pure static functions**
(`BasketTray.classify_drag`, `TraySlot.classify_release`) so the rules are
testable without advancing a frame — the runner cannot await. The fireworks
are an authored `@tool` scene with three real `GPUParticles2D` children, never
built at runtime. Audio reaches the game only through `AudioDirector`'s
`@export` slots, which `tests/test_audio_coverage.gd` already enforces.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite`
(`addons/godot_ai/testing/test_suite.gd`), the `godot-ai` MCP bridge.

## Global Constraints

- **Worktree.** All work happens in
  `.claude/worktrees/gamecode-tray-fireworks-audio` on branch
  `feat/tray-fireworks-audio`. Never `git switch` in the main checkout — another
  session is live there on `feat/calendar-badge`.
- **Second editor.** The bridge's editor serves the *main* checkout. Task 0
  launches a second editor on this worktree; **every `test_run` call in this
  plan passes that editor's `session_id`.**
- **Tests are `@tool`, and no test may be a coroutine.** The runner does
  `suite.call(name)` without awaiting; an `await` silently aborts the test and
  it reports "0 assertions".
- **Scripts the runner instantiates live must be `@tool`**, with real side
  effects in `_ready()` behind `if Engine.is_editor_hint(): return`.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation.
  Only layout-only constant overrides (`separation`, `margin_*`) are accepted.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`;
  repeated rows are a `PackedScene`; responsive geometry is a `@tool` script
  with documented `@export` knobs.
- **Every script needs documentation:** a `##` file header and a `##` line on
  every `@export` (`tests/test_script_documentation.gd`).
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` → `node_create` / `node_set_property` → `scene_save`.
- **Do scene work first, script work second.** `scene_save` flushes stale
  script tabs over whatever you patched. After any `scene_save`, check
  `git diff HEAD -- '*.gd'` for files you were not editing.
- **Prefer `script_patch`** for `.gd` edits. After editing a `.gd` from
  outside the editor, a **no-op `script_patch` on that same file** forces the
  reload (it logs a benign `GDScript reload failed with error code 43`, then
  works).
- **Game-facing identifiers and all UI text are Indonesian**; systems code is
  English.
- **`Balance.gd` is collaborator-owned.** Read it; never edit it.
- **No emoji as UI iconography.** Use real transparent SVG textures.
- Commits are Conventional Commits with a scope, e.g.
  `feat(koperasi): drag the basket tray`.
- Commit messages go through a **file** (`git commit -F <path>`): PowerShell 5.1
  splits a `git commit -m` here-string at embedded quotes. In this worktree run
  git as **plain, separate commands** — no `cd &&`, no heredocs, no process
  substitution, or the shell guard refuses them.

---

### Task 0: A second editor for this worktree

The suite cannot run headless (`--script` registers no autoloads; running a
*scene* makes `Engine.is_editor_hint()` false and ~143 `@tool` guards fire
their real side effects). The bridge is the only real way, and the bridge's
current editor serves the main checkout.

**Files:**
- Create: `.godot/` in this worktree (generated, gitignored)

- [ ] **Step 1: Seed the worktree's import cache**

Copy the main checkout's `.godot/` so the second editor does not reimport
~3,000 assets on first boot. Plain commands only:

```bash
cp -r "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.godot" ".godot"
```

- [ ] **Step 2: Launch a second editor on this worktree**

The exe path is a directory containing `Godot_v4.6.2-stable_win64.exe`. Launch
it with `--editor --path <this worktree>`. **Never kill all Godot processes** —
other sessions share the machine; leave `Godot_v*.exe` belonging to the main
checkout alone.

- [ ] **Step 3: Confirm the new session attached**

Run: `session_manage(op="list")`
Expected: `count` ≥ 2, one session whose project path ends in
`.claude/worktrees/gamecode-tray-fireworks-audio`. Record its `session_id` —
**every `test_run` below passes it.** Do **not** call `session_activate`: other
sessions share the server.

- [ ] **Step 4: Baseline the suites this branch will touch**

Run: `test_run(suite="basket_tray", session_id=<id>)`,
then `koperasi_tray`, `koperasi_tap_spam`, `minigame_result_popup`,
`student_face`, `face_rig_roster`, `audio_director`, `audio_coverage`.
Expected: all green. A red baseline makes every later failure ambiguous —
if one is red, report it before writing any code. Note that a shared red
suite on `Textures` may already be getting fixed by another session; re-fetch
and grep for the defect before fixing it here.

---

### Task 1: The tray follows a finger

**Files:**
- Modify: `Scripts/Koperasi/BasketTray.gd`
- Test: `tests/test_basket_tray.gd`

**Interfaces:**
- Consumes: `BasketTray.ViewState`, `set_state(state, animate)`, `_base_y`,
  `tray_offset_collapsed` — all already present.
- Produces: `static func classify_drag(travel: float, velocity: float, span: float) -> int`
  returning a `ViewState` value. Task 2 does not use it; Task 7's audit does not
  either. It exists so the drag rule is testable without a frame.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_basket_tray.gd`:

```gdscript
func test_classify_drag_commits_past_the_halfway_point() -> void:
	# span is tray_offset_collapsed: the full travel between docked and hidden.
	assert_eq(BasketTray.classify_drag(120.0, 0.0, 190.0),
		BasketTray.ViewState.COLLAPSED,
		"a slow drag past halfway must settle collapsed")
	assert_eq(BasketTray.classify_drag(70.0, 0.0, 190.0),
		BasketTray.ViewState.EXPANDED,
		"a slow drag short of halfway must spring back expanded")


func test_classify_drag_lets_a_flick_win_outright() -> void:
	# A fast, short downward flick must collapse even though travel is tiny --
	# otherwise a real flick reads as "barely moved, snap back".
	assert_eq(BasketTray.classify_drag(18.0, 1400.0, 190.0),
		BasketTray.ViewState.COLLAPSED,
		"a downward flick must collapse regardless of travel")
	# And the same flick upward must expand from a nearly-collapsed tray.
	assert_eq(BasketTray.classify_drag(172.0, -1400.0, 190.0),
		BasketTray.ViewState.EXPANDED,
		"an upward flick must expand regardless of travel")


func test_classify_drag_clamps_a_nonsense_span() -> void:
	# A zero span must not divide by zero; it settles expanded.
	assert_eq(BasketTray.classify_drag(50.0, 0.0, 0.0),
		BasketTray.ViewState.EXPANDED,
		"a zero span must settle expanded rather than divide by zero")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="basket_tray", session_id=<id>)`
Expected: FAIL — `Invalid call. Nonexistent function 'classify_drag'`.

- [ ] **Step 3: Implement `classify_drag` and the drag gesture**

Patch `Scripts/Koperasi/BasketTray.gd`. Add the constants below the existing
`@export` block:

```gdscript
## Drag speed (px/s) past which a flick decides the tray's resting state on
## its own, whatever the distance covered. Below this the halfway rule wins.
const FLICK_VELOCITY: float = 900.0
## Fraction of the full travel a slow drag must cross to commit to the far
## state. 0.5 is the midpoint: past it the tray goes, short of it it returns.
const COMMIT_FRACTION: float = 0.5
```

Add the pure classifier (a `static func`, so a test needs no instance):

```gdscript
## Where a released drag settles. `travel` is how far the tray has moved down
## from its docked position, `velocity` the release speed in px/s (positive =
## downward), `span` the full travel between docked and hidden.
##
## Pure on purpose: the runner cannot await, so the rule has to be checkable
## without a frame. _end_drag() is the only caller at runtime.
static func classify_drag(travel: float, velocity: float, span: float) -> int:
	if absf(velocity) >= FLICK_VELOCITY:
		return ViewState.COLLAPSED if velocity > 0.0 else ViewState.EXPANDED
	if span <= 0.0:
		return ViewState.EXPANDED
	return ViewState.COLLAPSED if travel >= span * COMMIT_FRACTION else ViewState.EXPANDED
```

Add the drag state next to `_tray_tween`:

```gdscript
## True while a finger is dragging the tray. Blocks the idle tween so a drag
## and a toggle never fight for position.y.
var _dragging: bool = false
## position.y when the current drag began.
var _drag_from_y: float = 0.0
## The most recent drag sample, for the release velocity.
var _drag_last_y: float = 0.0
var _drag_last_msec: int = 0
## Release speed in px/s, positive downward. Fed to classify_drag().
var _drag_velocity: float = 0.0
```

And the gesture itself:

```gdscript
## Begins a drag at global y `at_y`. Kills any running slide first so a drag
## that interrupts a toggle takes over cleanly instead of fighting it.
func begin_drag(at_y: float) -> void:
	if is_instance_valid(_tray_tween) and _tray_tween.is_valid():
		_tray_tween.kill()
	_dragging = true
	_drag_from_y = at_y
	_drag_last_y = at_y
	_drag_last_msec = Time.get_ticks_msec()
	_drag_velocity = 0.0


## Moves the tray to follow a finger at global y `at_y`, clamped to the dock.
func update_drag(at_y: float) -> void:
	if not _dragging:
		return
	var delta_y: float = at_y - _drag_from_y
	var start_y: float = _base_y + (tray_offset_collapsed \
		if _state == ViewState.COLLAPSED else 0.0)
	position.y = clampf(start_y + delta_y, _base_y, _base_y + tray_offset_collapsed)
	var now := Time.get_ticks_msec()
	var dt: float = maxf(float(now - _drag_last_msec) / 1000.0, 0.0001)
	_drag_velocity = (at_y - _drag_last_y) / dt
	_drag_last_y = at_y
	_drag_last_msec = now


## Ends a drag and settles the tray. The settle goes through set_state(), so
## the existing tween, emblem fade, badge rule, HeaderButton hit-test gate and
## state_changed signal all keep working untouched -- koprasi.gd's CrateHandle
## mirror needs no edit.
func end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var travel: float = position.y - _base_y
	var settled: int = classify_drag(travel, _drag_velocity, tray_offset_collapsed)
	if settled == _state:
		# set_state() no-ops on a repeat, which would leave the tray parked
		# mid-slide where the finger dropped it. Slide it home by hand.
		var home_y: float = _base_y + (tray_offset_collapsed \
			if _state == ViewState.COLLAPSED else 0.0)
		if not is_equal_approx(position.y, home_y):
			_tray_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tray_tween.tween_property(self, "position:y", home_y, 0.2)
		return
	set_state(settled, true)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			begin_drag(button.global_position.y)
		else:
			end_drag()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		update_drag(motion.global_position.y)
```

`_gui_input` only fires on a Control that accepts input, so also set
`mouse_filter = MOUSE_FILTER_PASS` on the tray root in `_ready()` — `PASS`, not
`STOP`, so the slots and the Beli button inside still receive their own
presses:

```gdscript
	mouse_filter = MOUSE_FILTER_PASS
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `test_run(suite="basket_tray", session_id=<id>)`
Expected: PASS, and the suite's pre-existing tests still green.

- [ ] **Step 5: Check no neighbouring suite regressed**

Run: `test_run(suite="koperasi_tray", session_id=<id>)` and
`test_run(suite="koperasi_tray_retract", session_id=<id>)`
Expected: PASS. Both drive `set_state()` directly, which is unchanged.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Koperasi/BasketTray.gd tests/test_basket_tray.gd
git commit -F <message file>
```

Message: `feat(koperasi): drag the basket tray up and down`

---

### Task 2: A tap on a tray item returns it

**Files:**
- Modify: `Scripts/Koperasi/TraySlot.gd`
- Modify: `Scripts/Koperasi/koprasi.gd`
- Test: `tests/test_koperasi_tap_spam.gd`

**Interfaces:**
- Consumes: `TraySlot.classify_release(held, drift, hold_threshold, slop)`
  (existing), `BasketTray.begin_drag/update_drag/end_drag` from Task 1.
- Produces: `TraySlot.cancel_press()` — called when a drag steals the gesture.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tap_spam.gd`:

```gdscript
func test_a_quick_tap_returns_one_unit() -> void:
	# The gesture change: a tap used to only nudge. It now returns, like a
	# hold does -- the hold stays, so nobody who learned it loses it.
	var slot := TraySlot.new()
	var returned: Array[String] = []
	slot.remove_requested.connect(func(n: String) -> void: returned.append(n))
	slot._item_name = "Susu"
	# 0.10 s held, 2 px of drift: well under hold_seconds, well under slop.
	slot._press_msec = Time.get_ticks_msec() - 100
	slot._press_pos = Vector2.ZERO
	slot._end_press(Vector2(2.0, 0.0))
	assert_eq(returned.size(), 1, "a quick tap must return exactly one unit")
	assert_eq(returned[0], "Susu", "the returned line must be the tapped one")
	slot.free()


func test_a_drag_across_a_slot_returns_nothing() -> void:
	# Dragging the tray starts on a slot as often as not. Drift past the slop
	# must yield the gesture to the tray, not return an item.
	var slot := TraySlot.new()
	var returned: Array[String] = []
	slot.remove_requested.connect(func(n: String) -> void: returned.append(n))
	slot._item_name = "Susu"
	slot._press_msec = Time.get_ticks_msec() - 100
	slot._press_pos = Vector2.ZERO
	slot._end_press(Vector2(0.0, 80.0))  # 80 px > hold_slop (30)
	assert_true(returned.is_empty(), "a drag must not return an item")
	slot.free()


func test_cancel_press_forgets_the_gesture() -> void:
	var slot := TraySlot.new()
	var returned: Array[String] = []
	slot.remove_requested.connect(func(n: String) -> void: returned.append(n))
	slot._item_name = "Susu"
	slot._press_msec = Time.get_ticks_msec() - 100
	slot._press_pos = Vector2.ZERO
	slot.cancel_press()
	slot._end_press(Vector2.ZERO)
	assert_true(returned.is_empty(),
		"a cancelled press must return nothing even on a clean release")
	slot.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="koperasi_tap_spam", session_id=<id>)`
Expected: FAIL — the first test finds 0 returns (a tap emits `tapped`, not
`remove_requested`), and the third finds no `cancel_press`.

- [ ] **Step 3: Make the tap return, and let a drag cancel the press**

Patch `Scripts/Koperasi/TraySlot.gd`. Update the file header's gesture
sentence:

```gdscript
## Tap it or hold it to return one to the shelf. The hold is the gesture the
## basket always had, moved here from rakbarang_1.gd's _on_item_icon_input
## when the tray replaced the basket popup; the tap was added 2026-09-21
## because holding to undo a mis-tap is a slow answer to a fast mistake.
## A right-click returns one at once. A press that drifts past hold_slop is a
## tray drag, and the slot yields it.
```

Change `_end_press`'s match so a tap returns too:

```gdscript
	match classify_release(held, _press_pos.distance_to(at), hold_seconds, hold_slop):
		&"hold", &"tap":
			remove_requested.emit(_item_name)
			tapped.emit(_item_name)
```

`tapped` still fires: it is public API `koprasi.gd` connects to, and keeping it
means a listener that only wants to know "the player touched a slot" is
unaffected. Add the cancel:

```gdscript
## Forgets the press in progress, so the release that follows does nothing.
## BasketTray calls this once a drag passes hold_slop: a gesture that started
## on a slot but became a tray drag must move the tray, not return an item.
func cancel_press() -> void:
	_press_msec = -1
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	scale = Vector2.ONE
```

Guard `_end_press` against a cancelled press:

```gdscript
func _end_press(at: Vector2) -> void:
	if _press_msec < 0:
		return
	var held := (Time.get_ticks_msec() - _press_msec) / 1000.0
```

- [ ] **Step 4: Have the tray cancel its slots' presses when a drag starts**

In `Scripts/Koperasi/BasketTray.gd`, extend `update_drag()` so that once the
finger passes a slot's slop the slots let go:

```gdscript
	if absf(delta_y) > TraySlot.new().hold_slop and not _slots_cancelled:
		_slots_cancelled = true
		for item_name in _slots:
			(_slots[item_name] as TraySlot).cancel_press()
```

Instantiating a `TraySlot` just to read a default is wasteful and leaks; use a
constant instead. Add beside `FLICK_VELOCITY`:

```gdscript
## Drag distance (px) past which the slots under the finger give up their own
## press to the tray. Matches TraySlot.hold_slop's default -- a gesture that
## is a drag to the tray must not also be a tap to a slot.
const DRAG_STEALS_AFTER: float = 30.0
```

and use it:

```gdscript
	if absf(delta_y) > DRAG_STEALS_AFTER and not _slots_cancelled:
		_slots_cancelled = true
		for item_name in _slots:
			(_slots[item_name] as TraySlot).cancel_press()
```

Declare `var _slots_cancelled: bool = false` with the other drag state, reset
it to `false` in `begin_drag()`.

- [ ] **Step 5: Stop the shop nudging on a tap**

In `Scripts/Koperasi/koprasi.gd`, find the `slot_tapped` handler and remove the
nudge — the tap now returns, and a nudge on top of a return reads as a glitch.
Leave the connection in place (it costs nothing and documents the signal). Read
the handler first:

```bash
grep -n "slot_tapped" -A 12 Scripts/Koperasi/koprasi.gd
```

Replace the nudge body with a comment recording why it is empty.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="koperasi_tap_spam", session_id=<id>)`
Expected: PASS.
Run: `test_run(suite="basket_tray", session_id=<id>)` and
`test_run(suite="koperasi_cart_signals", session_id=<id>)`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Koperasi/TraySlot.gd Scripts/Koperasi/BasketTray.gd Scripts/Koperasi/koprasi.gd tests/test_koperasi_tap_spam.gd
git commit -F <message file>
```

Message: `feat(koperasi): tap a tray item to return it`

---

### Task 3: The star art from Downloads

**Files:**
- Modify: `Assets/Images/UI/star.png` (replaced)
- Test: `tests/test_minigame_result_popup.gd`

**Interfaces:**
- Consumes: `ResultStar.DEFAULT_FILLED_TEXTURE` /
  `DEFAULT_EMPTY_TEXTURE`, both already `res://Assets/Images/UI/star.png`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

The repo's star is 360×360; the file the user asked for is 345×357. Pin the
new one so a stray re-export cannot silently swap it back:

```gdscript
func test_star_art_is_the_shipped_glossy_star() -> void:
	var tex: Texture2D = load(ResultStar.DEFAULT_FILLED_TEXTURE)
	assert_true(tex != null, "star.png must load")
	assert_eq(tex.get_width(), 345, "star.png must be the 345x357 Downloads crop")
	assert_eq(tex.get_height(), 357, "star.png must be the 345x357 Downloads crop")


func test_both_star_slots_use_the_same_art() -> void:
	# A lost star is the same star darkened by popup_star_empty_color, not a
	# different drawing -- that is what makes an empty slot read as "not yet".
	assert_eq(ResultStar.DEFAULT_FILLED_TEXTURE, ResultStar.DEFAULT_EMPTY_TEXTURE,
		"filled and empty stars must share one texture")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="minigame_result_popup", session_id=<id>)`
Expected: FAIL — width is 360, not 345.

- [ ] **Step 3: Drop the file in**

```bash
cp "C:/Users/user/Downloads/star.png" "Assets/Images/UI/star.png"
```

Then `filesystem_manage(op="scan")` so the editor reimports it. The `.import`
file is regenerated; commit it with the PNG.

- [ ] **Step 4: Run the test to verify it passes**

Run: `test_run(suite="minigame_result_popup", session_id=<id>)`
Expected: PASS.

- [ ] **Step 5: Look at it**

`star.png` also feeds StatCheck. Take one **full-size** `editor_screenshot` of
the result card with three stars — a scaled capture cannot show whether the
new crop sits right in its authored box. If the star now floats or crowds its
slot, fix the `Icon` TextureRect's stretch mode in `ResultStar.tscn`, not by
re-cropping the art.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/UI/star.png Assets/Images/UI/star.png.import tests/test_minigame_result_popup.gd
git commit -F <message file>
```

Message: `feat(minigame): use the new star art on the result card`

---

### Task 4: Three confetti fireworks

**Files:**
- Create: `Scenes/Minigames/UI/ConfettiFireworks.tscn`
- Create: `Scripts/Minigames/UI/ConfettiFireworks.gd`
- Modify: `Scripts/Minigames/UI/ResultStar.gd`
- Modify: `Scripts/Minigames/UI/MinigameResultPopup.gd`
- Modify: `Scenes/Minigames/UI/MinigameResultPopup.tscn`
- Test: `tests/test_confetti_fireworks.gd` (new)

**Interfaces:**
- Consumes: `Assets/Images/Particles/particle_confetti.png` (already in repo).
- Produces: `ConfettiFireworks.fire_burst(index: int) -> void` and
  `ConfettiFireworks.burst_position(index: int) -> Vector2`; `burst_count()`
  returns 3.

**Do scene work before script work** — a `scene_save` flushes stale script tabs
over patched `.gd` files.

- [ ] **Step 1: Write the failing test**

Create `tests/test_confetti_fireworks.gd`:

```gdscript
@tool
extends McpTestSuite

## The three-burst celebration that replaced the per-star StarBurst spray.
##
## Placement is the point of the scene: the user asked to be able to see where
## each firework sits, so these tests pin that the three bursts are real
## authored nodes at three distinct points, not one emitter fired three times.

func suite_name() -> String:
	return "confetti_fireworks"


const SCENE := preload("res://Scenes/Minigames/UI/ConfettiFireworks.tscn")


func test_the_scene_carries_exactly_three_bursts() -> void:
	var rig := SCENE.instantiate()
	assert_eq(rig.burst_count(), 3, "the volley must be three fireworks")
	rig.free()


func test_the_three_bursts_sit_at_three_distinct_places() -> void:
	# One emitter fired three times would pass burst_count but fail this.
	var rig := SCENE.instantiate()
	var seen: Array[Vector2] = []
	for i in 3:
		var at: Vector2 = rig.burst_position(i)
		assert_false(seen.has(at), "burst %d must not share a place" % i)
		seen.append(at)
	rig.free()


func test_every_burst_is_confetti_not_stars() -> void:
	var rig := SCENE.instantiate()
	for i in 3:
		var node: GPUParticles2D = rig.get_burst(i)
		assert_true(node != null, "burst %d must exist as a node" % i)
		assert_true(String(node.texture.resource_path).contains("particle_confetti"),
			"burst %d must throw confetti, not stars" % i)
	rig.free()


func test_bursts_start_quiet() -> void:
	# A scene that emits on load would fire the volley the moment the card is
	# instanced, before a single star has landed.
	var rig := SCENE.instantiate()
	for i in 3:
		assert_false(rig.get_burst(i).emitting, "burst %d must wait to be fired" % i)
	rig.free()


func test_result_star_no_longer_sprays_stars() -> void:
	var f := FileAccess.open("res://Scripts/Minigames/UI/ResultStar.gd", FileAccess.READ)
	assert_true(f != null, "ResultStar.gd must exist")
	var src := f.get_as_text()
	assert_false(src.contains("StarBurst.tscn"),
		"the per-star star spray is what the fireworks replace")


func test_the_popup_fires_the_volley() -> void:
	var f := FileAccess.open("res://Scripts/Minigames/UI/MinigameResultPopup.gd", FileAccess.READ)
	assert_true(f != null, "MinigameResultPopup.gd must exist")
	var src := f.get_as_text()
	assert_true(src.contains("fire_burst("),
		"the popup must fire a burst as each star lands")


func test_the_full_house_rain_is_untouched() -> void:
	# ResultConfetti is the separate top-of-screen rain gated at three stars.
	# The fireworks replace the per-star spray, not this.
	var f := FileAccess.open("res://Scripts/Minigames/UI/MinigameResultPopup.gd", FileAccess.READ)
	var src := f.get_as_text()
	assert_true(src.contains("confetti.fire()"),
		"the three-star confetti rain must still fire")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="confetti_fireworks", session_id=<id>)`
Expected: FAIL — the scene does not exist.

- [ ] **Step 3: Write the script**

Create `Scripts/Minigames/UI/ConfettiFireworks.gd`:

```gdscript
@tool
class_name ConfettiFireworks
extends Control

## Three confetti fireworks placed on the result screen, fired one per star as
## the stars land.
##
## Replaces the star-shaped spray ResultStar.celebrate() used to instance into
## each star's own BurstSlot: three bursts at three authored points read as a
## celebration over the whole card, where three sprays behind three stars read
## as the stars themselves fizzing.
##
## Placement is authored, not computed. Each burst is a real GPUParticles2D
## child of Bursts/ in this scene's .tscn, and the designer drags it in the
## editor viewport. While Engine.is_editor_hint() is true this script draws a
## labelled ring at each burst so the three positions are visible without
## pressing play; the rings never draw at runtime.
##
## Not to be confused with Scenes/Minigames/UI/ResultConfetti.tscn, which is
## the separate full-house rain from above the top edge, gated at three stars.
##
## Affects: nothing outside itself. fire_burst() is fire-and-forget.
##
## @tool so the placement rings preview in the editor.

## Node holding the three burst emitters, in firing order.
const BURSTS_PATH := ^"Bursts"
## How many fireworks a volley has. Three, one per star.
const BURST_COUNT: int = 3

## Seconds between one burst and the next when play_volley() runs them as a
## sequence. A volley reads as a celebration; three at once reads as a flash.
@export var burst_delay: float = 0.14
## Radius (px) of the editor-only placement ring drawn at each burst.
@export var marker_radius: float = 34.0
## Colour of the editor-only placement rings. Never drawn at runtime.
@export var marker_color: Color = Color(1.0, 0.45, 0.1, 0.9)


func _ready() -> void:
	for i in BURST_COUNT:
		var burst := get_burst(i)
		if burst != null:
			burst.emitting = false
	queue_redraw()


## How many fireworks this volley has.
func burst_count() -> int:
	return BURST_COUNT


## The emitter for burst `index`, or null when the scene is missing one.
func get_burst(index: int) -> GPUParticles2D:
	var bursts := get_node_or_null(BURSTS_PATH)
	if bursts == null or index < 0 or index >= bursts.get_child_count():
		return null
	return bursts.get_child(index) as GPUParticles2D


## Where burst `index` sits, in this Control's own coordinates.
func burst_position(index: int) -> Vector2:
	var burst := get_burst(index)
	return burst.position if burst != null else Vector2.ZERO


## Sets burst `index` off. Fire-and-forget: the emitter is one_shot, so it
## stops itself. Out-of-range indices are ignored rather than erroring --
## the popup fires one per star and a minigame may award fewer than three.
func fire_burst(index: int) -> void:
	if Engine.is_editor_hint():
		return
	var burst := get_burst(index)
	if burst == null:
		return
	burst.restart()
	burst.emitting = true


## The editor-only placement rings. See the file header: this is how the
## designer sees where the three fireworks are without pressing play.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for i in BURST_COUNT:
		var burst := get_burst(i)
		if burst == null:
			continue
		draw_arc(burst.position, marker_radius, 0.0, TAU, 32, marker_color, 3.0, true)
		draw_line(burst.position - Vector2(marker_radius, 0.0),
			burst.position + Vector2(marker_radius, 0.0), marker_color, 2.0)
		draw_line(burst.position - Vector2(0.0, marker_radius),
			burst.position + Vector2(0.0, marker_radius), marker_color, 2.0)
```

- [ ] **Step 4: Build the scene through the editor**

Never hand-edit the `.tscn` while the editor is attached. Use
`scene_manage` / `node_create` / `node_set_property` / `scene_save`, or one
`batch_execute`. Remember: `anchors_preset` is inert (set the four anchors),
numbers must be unquoted, and `node_create` appends last.

Structure — root `ConfettiFireworks` (`Control`, full rect, script attached,
`mouse_filter = 2` / IGNORE so it never eats the continue button's taps), child
`Bursts` (`Control`), and three `GPUParticles2D` children of `Bursts`.

Placement on the 1080×1920 canvas, arranged around the card rather than on it:

| burst | position |
|---|---|
| `Burst1` | `Vector2(250, 760)` |
| `Burst2` | `Vector2(830, 700)` |
| `Burst3` | `Vector2(540, 1020)` |

Each emitter:

```
emitting = false
one_shot = true
explosiveness = 0.95
amount = 26
lifetime = 1.1
texture = res://Assets/Images/Particles/particle_confetti.png
```

with a `ParticleProcessMaterial`:

```
emission_shape = 1
emission_sphere_radius = 14.0
direction = Vector3(0, -1, 0)
spread = 55.0
initial_velocity_min = 260.0
initial_velocity_max = 520.0
angular_velocity_min = -320.0
angular_velocity_max = 320.0
gravity = Vector3(0, 620, 0)
scale_min = 0.25
scale_max = 0.5
```

A firework launches up and falls back, so `spread = 55` (a cone) with a real
`gravity` — not the star burst's `spread = 180` sphere.

Then `scene_save`. **Immediately after, check `git diff HEAD -- '*.gd'`** for
files you were not editing: the save flushes every open script tab.

- [ ] **Step 5: Stop ResultStar spraying stars**

Patch `Scripts/Minigames/UI/ResultStar.gd`: delete `BURST_SCENE`,
`_BURST_PACKED` and the three lines in `celebrate()` that instantiate and fire
the burst. Keep the `AudioDirector.play_sfx` line and the glow tween. Update
the `celebrate()` doc comment: it no longer adds a child, so drop the
"adds a self-freeing burst under BurstSlot" sentence from **Affects**.

Leave `Scenes/Minigames/UI/StarBurst.tscn` on disk — other callers may use it.

- [ ] **Step 6: Fire the volley from the popup**

Patch `Scripts/Minigames/UI/MinigameResultPopup.gd`. Add the `@onready` beside
`confetti`:

```gdscript
## The three placed fireworks, one fired per star as it lands. Separate from
## `confetti` above, which is the full-house rain from above the top edge.
@onready var fireworks: ConfettiFireworks = $Dim/ConfettiFireworks
```

In the reveal loop, right after `star.celebrate(star_index)`:

```gdscript
		fireworks.fire_burst(star_index)
```

`fire_burst` ignores an out-of-range index, so a one- or two-star finish fires
one or two fireworks and the third stays quiet.

Add the instance to `Scenes/Minigames/UI/MinigameResultPopup.tscn` under `Dim`,
**after** `ResultConfetti` so it draws above, through the editor.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `test_run(suite="confetti_fireworks", session_id=<id>)`
Expected: PASS.
Run: `test_run(suite="minigame_result_popup", session_id=<id>)` and
`test_run(suite="viewport_editability", session_id=<id>)`
Expected: PASS. The second is the runtime-visual-construction ratchet — the
new scene is authored, so it must not raise the BASELINE.

- [ ] **Step 8: Watch it once**

Seed and teleport rather than playing to it: debug overlay → **⚡ Seed Playtest
State**, then the **Scenes** tab's minigame launcher. Win one. Freeze with
`Engine.time_scale = 0.02` inside a single `game_eval` if you need a still —
at exactly 0 the GPU particles vanish. Confirm the three fireworks read as a
volley and not as a single flash; `burst_delay` is the knob.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Minigames/UI/ConfettiFireworks.tscn Scripts/Minigames/UI/ConfettiFireworks.gd Scripts/Minigames/UI/ResultStar.gd Scripts/Minigames/UI/MinigameResultPopup.gd Scenes/Minigames/UI/MinigameResultPopup.tscn tests/test_confetti_fireworks.gd
git commit -F <message file>
```

Message: `feat(minigame): three placed confetti fireworks replace the star spray`

---

### Task 5: The sounds — files, slots, ambience

**Files:**
- Create: `Assets/Audio/SFX/**` (32 files), `Assets/Audio/Ambient/**` (8 files)
- Modify: `Assets/Audio/SFX/LICENSES.md`
- Modify: `Scripts/Audio/AudioDirector.gd`
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Consumes: `AudioDirector.play_sfx(StringName)` (existing).
- Produces: `AudioDirector.play_ambience(id: StringName)`,
  `AudioDirector.stop_ambience()`, `AudioDirector.badge_reveal_stream(band: String) -> AudioStream`.

- [ ] **Step 1: Download the 49 files**

The Drive folder is `1n_bK9LMW5sj3bhhb4brX6j7ko-c3M7dG`, owned by
`hoseagimbil@gmail.com`. Pull each file with the Drive connector's
`download_file_content` (it returns base64; decode to disk). Layout:

- `Assets/Audio/SFX/` ← the 25 top-level `.ogg`s
- `Assets/Audio/SFX/minigame/` ← the 7 under `minigame/`
- `Assets/Audio/Ambient/` ← the 8 ambient `.ogg`s
- `credits.txt` → appended to `Assets/Audio/SFX/LICENSES.md` under a
  `## Drive pack, 2026-09-17` heading, verbatim. Attribution is a licence
  term, not a nicety.

Then `filesystem_manage(op="scan")`.

- [ ] **Step 2: Set the loop flags**

Godot imports `.ogg` as `AudioStreamOggVorbis`. **Only** the ambience loops get
`loop = true` in their `.import`: `classroomAmbient1/2/3`, `thunderstorm1`,
`schoolsimulation1/2`, `writing`. Every SFX one-shot must have `loop = false` —
a looping one-shot turns a UI click into a drone.

- [ ] **Step 3: Write the failing test**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_the_placeholder_aliases_are_gone() -> void:
	# Before the Drive pack landed, these ids all aliased pop.ogg or
	# reward.ogg. A cue that still points at a placeholder is a cue nobody
	# will notice is missing.
	var director := AudioDirector
	for id in ["star_earn_1", "star_earn_2", "star_earn_3", "result_fanfare",
			"sparkle", "coin"]:
		var stream: AudioStream = director.get("sfx_%s" % id)
		assert_true(stream != null, "sfx_%s must have a stream" % id)
		var path := String(stream.resource_path)
		assert_false(path.ends_with("/pop.ogg") or path.ends_with("/reward.ogg"),
			"sfx_%s must no longer alias a placeholder (got %s)" % [id, path])


func test_the_three_star_cues_are_three_different_sounds() -> void:
	# The ladder only reads as a climb if the rungs differ.
	var one := String(AudioDirector.sfx_star_earn_1.resource_path)
	var two := String(AudioDirector.sfx_star_earn_2.resource_path)
	var three := String(AudioDirector.sfx_star_earn_3.resource_path)
	assert_true(one != two and two != three and one != three,
		"star_earn_1/2/3 must be three distinct streams")


func test_new_cue_ids_resolve() -> void:
	for id in ["school_bell", "stat_up", "stat_down", "card_flip",
			"schedule_confirm", "timer_tick", "times_up", "back_tap",
			"shop_browse", "transaction", "item_applied", "apply",
			"tutorial_popup", "result_checkup", "daily_claim"]:
		assert_true(AudioDirector.get("sfx_%s" % id) != null,
			"sfx_%s must have a stream" % id)


func test_randomised_families_have_their_variants() -> void:
	assert_eq(AudioDirector.sfx_transition_sweep.size(), 3,
		"three sweeps, so a scene change never sounds identical twice")
	assert_eq(AudioDirector.sfx_ball_kick.size(), 4, "four ball kicks")
	assert_eq(AudioDirector.sfx_racket_hit.size(), 3, "three racket hits")


func test_badge_reveal_is_a_tier_not_one_cue() -> void:
	var bands := ["Amazing", "Good", "Normal", "Bad", "Disaster"]
	var seen: Array[String] = []
	for band in bands:
		var stream: AudioStream = AudioDirector.badge_reveal_stream(band)
		assert_true(stream != null, "band %s must have a stream" % band)
		var path := String(stream.resource_path)
		assert_false(seen.has(path), "band %s must have its own sound" % band)
		seen.append(path)


func test_an_unknown_badge_band_falls_back_rather_than_erroring() -> void:
	assert_true(AudioDirector.badge_reveal_stream("Nonsense") != null,
		"an unknown band must fall back, not return null into a player")


func test_ambience_loops_and_sfx_do_not() -> void:
	# The one that bites: a looping one-shot becomes a drone.
	for id in ["classroom_1", "thunderstorm"]:
		var stream: AudioStream = AudioDirector.get("amb_%s" % id)
		assert_true(stream != null, "amb_%s must have a stream" % id)
		assert_true(stream.loop, "amb_%s must loop" % id)
	assert_false(AudioDirector.sfx_school_bell.loop, "a bell must not loop")
	assert_false(AudioDirector.sfx_tap.loop, "a tap must not loop")


func test_ambience_plays_on_the_sfx_bus() -> void:
	# No third bus: default_bus_layout.tres is rewritten on boot and a new bus
	# would need a new settings slider to be honest about. Ambience follows
	# the SFX slider, which is what a player expects from "sound effects".
	AudioDirector.play_ambience(&"classroom_1")
	var player: AudioStreamPlayer = AudioDirector.get_ambience_player()
	assert_true(player != null, "the ambience player must exist")
	assert_eq(String(player.bus), "SFX", "ambience must sit on the SFX bus")
	AudioDirector.stop_ambience()
	assert_false(player.playing, "stop_ambience must actually stop it")
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `test_run(suite="audio_director", session_id=<id>)`
Expected: FAIL — the placeholder aliases are still in place and the new ids do
not exist.

- [ ] **Step 5: Re-point the slots and add the new ones**

Patch `Scripts/Audio/AudioDirector.gd`. Re-point the six placeholders:

```gdscript
## The first rung of the three-cue star ladder.
@export var sfx_star_earn_1: AudioStream = preload("res://Assets/Audio/SFX/oneStar.ogg")
## The second rung.
@export var sfx_star_earn_2: AudioStream = preload("res://Assets/Audio/SFX/twoStar.ogg")
## The third and highest rung.
@export var sfx_star_earn_3: AudioStream = preload("res://Assets/Audio/SFX/threeStar.ogg")
## The win sting on the minigame result card.
@export var sfx_result_fanfare: AudioStream = preload("res://Assets/Audio/SFX/winSuccessful.ogg")
## Fires with the full-house confetti.
@export var sfx_sparkle: AudioStream = preload("res://Assets/Audio/SFX/threeStarredPoints.ogg")
## Money earned or spent.
@export var sfx_coin: AudioStream = preload("res://Assets/Audio/SFX/earnMoney.ogg")
## The sliding EventWarning's alert.
@export var sfx_event_announce: AudioStream = preload("res://Assets/Audio/SFX/eventAlert.ogg")
```

Add the fifteen new single slots, each with its own `##` line (required by
`tests/test_script_documentation.gd`) — `sfx_school_bell` ←`Schoolring.ogg`,
`sfx_stat_up` ← `stats-upDing.ogg`, `sfx_stat_down` ← `stats-downDing.ogg`,
`sfx_card_flip` ← `cardFlip.ogg`, `sfx_schedule_confirm` ←
`scheduleConfirmChime.ogg`, `sfx_timer_tick` ← `minigame/timeTicking.ogg`,
`sfx_times_up` ← `minigame/timesUp.ogg`, `sfx_back_tap` ← `BackButtonTap.ogg`,
`sfx_shop_browse` ← `shopBrowseTap.ogg`, `sfx_transaction` ←
`transactionShop.ogg`, `sfx_item_applied` ←
`itemAfterAppliedEachCharacter.ogg`, `sfx_apply` ← `apply.ogg`,
`sfx_tutorial_popup` ← `tutorialPopUp.ogg`, `sfx_result_checkup` ←
`ResultCheckup.ogg`, `sfx_daily_claim` ← `dailyLoginClaim.ogg`.

Add the three randomised families:

```gdscript
## The scene-change sweeps, picked at random so a transition never sounds
## identical twice in a row. Three variants.
@export var sfx_transition_sweep: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/transitionSweep1.ogg"),
	preload("res://Assets/Audio/SFX/transitionSweep2.ogg"),
	preload("res://Assets/Audio/SFX/transitionSweep3.ogg"),
]
## Main Bola's kick, four variants.
@export var sfx_ball_kick: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/minigame/ballKick1.ogg"),
	preload("res://Assets/Audio/SFX/minigame/ballKick2.ogg"),
	preload("res://Assets/Audio/SFX/minigame/ballKick3.ogg"),
	preload("res://Assets/Audio/SFX/minigame/ballKick4.ogg"),
]
## Badminton's racket, three variants.
@export var sfx_racket_hit: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/minigame/racketHit1.ogg"),
	preload("res://Assets/Audio/SFX/minigame/racketHit2.ogg"),
	preload("res://Assets/Audio/SFX/minigame/racketHit3.ogg"),
]
```

Add the badge tier and its lookup:

```gdscript
## EndCutscene's badge reveal, one cue per grade band. A tier, not one sound:
## the badge word is the payoff of a whole grade and a single sting would
## flatten "Disaster" and "Amazing" into the same moment.
@export var sfx_badge_reveal_amazing: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealAmazing.ogg")
## Band "Good".
@export var sfx_badge_reveal_good: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealGood.ogg")
## Band "Normal".
@export var sfx_badge_reveal_normal: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealNormal.ogg")
## Band "Bad".
@export var sfx_badge_reveal_bad: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealBad.ogg")
## Band "Disaster".
@export var sfx_badge_reveal_disaster: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealDisaster.ogg")


## The badge cue for a grade band. An unknown band falls back to Normal
## rather than returning null into a player.
func badge_reveal_stream(band: String) -> AudioStream:
	match band:
		"Amazing": return sfx_badge_reveal_amazing
		"Good": return sfx_badge_reveal_good
		"Bad": return sfx_badge_reveal_bad
		"Disaster": return sfx_badge_reveal_disaster
		_: return sfx_badge_reveal_normal
```

- [ ] **Step 6: Add the ambience player**

```gdscript
@export_group("Ambience")
## Classroom murmur, three variants for SchoolDay.
@export var amb_classroom_1: AudioStream = preload("res://Assets/Audio/Ambient/classroomAmbient1.ogg")
## Second classroom bed.
@export var amb_classroom_2: AudioStream = preload("res://Assets/Audio/Ambient/classroomAmbient2.ogg")
## Third classroom bed.
@export var amb_classroom_3: AudioStream = preload("res://Assets/Audio/Ambient/classroomAmbient3.ogg")
## Rain and thunder, for the Hujan random event.
@export var amb_thunderstorm: AudioStream = preload("res://Assets/Audio/Ambient/thunderstorm1.ogg")
## Pencils and paper, under the academic activity beat.
@export var amb_writing: AudioStream = preload("res://Assets/Audio/Ambient/writing.ogg")
## Outdoor schoolyard bed.
@export var amb_schoolyard_1: AudioStream = preload("res://Assets/Audio/Ambient/schoolsimulation1.ogg")
## Second schoolyard bed.
@export var amb_schoolyard_2: AudioStream = preload("res://Assets/Audio/Ambient/schoolsimulation2.ogg")

## The single looping ambience voice. On the SFX bus on purpose -- see
## play_ambience().
var _ambience: AudioStreamPlayer
```

and, near the SFX pool setup in `_ready()`:

```gdscript
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"SFX"
	add_child(_ambience)
```

```gdscript
## Starts the looping ambience bed `id` (the amb_* slot name without its
## prefix), replacing whatever was playing. On the SFX bus rather than a bus
## of its own: default_bus_layout.tres is rewritten on boot, and a third bus
## would need a third settings slider to be honest about. Ambience following
## the SFX slider is what a player expects from a "sound effects" control.
func play_ambience(id: StringName) -> void:
	var stream: AudioStream = get("amb_%s" % id)
	if stream == null or _ambience == null:
		return
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.play()


## Stops the ambience bed.
func stop_ambience() -> void:
	if _ambience != null:
		_ambience.stop()


## The ambience voice. Exists so tests need not know the node layout.
func get_ambience_player() -> AudioStreamPlayer:
	return _ambience
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `test_run(suite="audio_director", session_id=<id>)`
Expected: PASS.

**Then restart the second editor.** A changed default on a Resource `@export`
— and a *new* `@export` — needs a full editor restart: `load_default()` keeps
serving the cached instance, so the new value silently does not take effect and
a test asserting it fails for no visible reason. Re-run the suite after the
restart before believing a green.

- [ ] **Step 8: Commit**

```bash
git add Assets/Audio Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd
git commit -F <message file>
```

Message: `feat(audio): wire the Drive sound pack behind AudioDirector's slots`

---

### Task 6: Call the new cues from the screens

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd`,
  `Scripts/StudentCard/*.gd`, `Scripts/AturJadwal/*.gd`,
  `Scripts/Minigames/Olahraga/MainBola.gd`,
  `Scripts/Minigames/Olahraga/Badminton.gd`,
  `Scripts/Transition/*.gd`, `Scripts/Koperasi/koprasi.gd`,
  `Scripts/EndGame/*.gd`
- Test: `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: every id added in Task 5.
- Produces: nothing new.

Find the real paths first — the plan names them by area, not by guess:

```bash
grep -rln "play_sfx\|play_bgm" Scripts --include=*.gd
```

- [ ] **Step 1: Write the failing test**

Append to `tests/test_audio_coverage.gd`, following the file's established
source-scan pattern:

```gdscript
func test_each_screen_reaches_its_new_cue() -> void:
	# Source scans, like the rest of this suite: driving each screen
	# headlessly to assert "a sound played" would need a fake AudioServer.
	# This asserts the call sites exist -- it cannot tell you they fire at
	# the right moment, which is what the playtest in the plan is for.
	var expected := {
		"res://Scripts/SchoolSimulation/SchoolDay.gd": ["school_bell", "stat_up", "stat_down"],
		"res://Scripts/Koperasi/koprasi.gd": ["transaction", "shop_browse"],
	}
	for path in expected:
		var src := _source(path)
		for id in expected[path]:
			assert_true(src.contains('play_sfx(&"%s"' % id),
				'%s must call play_sfx(&"%s")' % [path, id])


func test_no_screen_loads_an_audio_file_directly_still_holds() -> void:
	# The pack added 49 files; the temptation to preload one in a screen is
	# highest right now. Re-assert the rule the suite already owns.
	var offenders: Array[String] = []
	_scan_for_audio_loads("res://Scripts", offenders)
	assert_true(offenders.is_empty(),
		"scripts must not load audio directly: " + ", ".join(offenders))
```

Extend `expected` with the other screens once `grep` has confirmed their real
paths. **Do not invent a path** — a test that asserts against a file that does
not exist fails on `_source`'s own assert and tells you nothing.

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="audio_coverage", session_id=<id>)`
Expected: FAIL — the call sites do not exist yet.

- [ ] **Step 3: Add the call sites**

Per the user's coverage table, one `AudioDirector.play_sfx(&"<id>")` at each
moment:

| where | cue |
|---|---|
| SchoolDay day start | `school_bell` |
| SchoolDay stat rises / falls | `stat_up` / `stat_down` |
| SchoolDay, while a day simulates | `play_ambience(&"classroom_1")` |
| Hujan random event | `play_ambience(&"thunderstorm")` |
| StudentCard card turn | `card_flip` |
| AturJadwal week confirmed | `schedule_confirm` |
| Minigame countdown / expiry | `timer_tick` / `times_up` |
| MainBola kick | a random `sfx_ball_kick` |
| Badminton hit | a random `sfx_racket_hit` |
| Transition.change_scene | a random `sfx_transition_sweep` |
| Any back button | `back_tap` |
| Koperasi shelf browse / Beli | `shop_browse` / `transaction` |
| Inventory item applied | `item_applied` |
| EndCutscene badge word | `badge_reveal_stream(band)` |
| ResultCheckup open | `result_checkup` |

For the randomised families add one helper rather than three copies:

```gdscript
## Plays one stream at random from a variant family (sfx_ball_kick and
## friends). A four-variant family repeated on every kick is the difference
## between a game that sounds alive and one that sounds like a metronome.
func play_sfx_variant(family: StringName) -> void:
	var variants: Array = get("sfx_%s" % family)
	if variants == null or variants.is_empty():
		return
	_play_stream(variants[randi() % variants.size()])
```

`_play_stream` is whatever `play_sfx` already calls internally — read
`play_sfx` and reuse its body rather than duplicating the pool logic.

- [ ] **Step 4: Run the test to verify it passes**

Run: `test_run(suite="audio_coverage", session_id=<id>)`
Expected: PASS.

- [ ] **Step 5: Listen to it**

Seed, teleport to SchoolDay (a pass through Atur Jadwal first — the seed does
not fill `day_schedules`), and play one week. A source scan cannot hear a cue
firing twice a frame or an ambience bed that never stops. Listen for: the bell
once per day not per student, the stat dings not machine-gunning down a roster
of six, and the ambience actually stopping when the day ends.

- [ ] **Step 6: Commit**

```bash
git add Scripts tests/test_audio_coverage.gd
git commit -F <message file>
```

Message: `feat(audio): call the new cues from every screen`

---

### Task 7: Pin the lobby blink

The mechanism shipped in `27ae2cc`. This task adds the tests that stop it
regressing, and nothing else. **Do not rewrite `StudentFace.gd`.**

**Files:**
- Test: `tests/test_student_face.gd`, `tests/test_face_rig_roster.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_face.gd`:

```gdscript
func test_idle_blink_waits_between_five_and_ten_seconds() -> void:
	# The user asked for 5-10 s. Pin the window so a later tuning pass has to
	# be deliberate about changing it.
	var face := StudentFace.new()
	assert_eq(face.blink_hold_range, Vector2(5.0, 10.0),
		"idle blinks must be 5-10 s apart")
	assert_true(face.idle_blink_enabled, "rigs must blink by default")
	face.free()


func test_a_blink_uses_the_eyelid_layer() -> void:
	# The Eyelid layer is the closed-eye art. Fading anything else would show
	# an open eye through a closed lid.
	assert_true(StudentFace.LAYER_NAMES.has("Eyelid"),
		"the rig must carry an Eyelid layer")
	var src_file := FileAccess.open("res://Scripts/Lobby/StudentFace.gd", FileAccess.READ)
	assert_true(src_file != null, "StudentFace.gd must exist")
	var src := src_file.get_as_text()
	assert_true(src.contains('_layer("Eyelid")'),
		"the blink must drive the Eyelid layer")


func test_each_rig_blinks_on_its_own_clock() -> void:
	# motion_seed 0 randomises, so the four seats never blink in step. A
	# fixed default would have all of them blink together, which reads as a
	# glitch rather than as life.
	var face := StudentFace.new()
	assert_eq(face.motion_seed, 0,
		"the default seed must randomise so seats blink independently")
	face.free()
```

And to `tests/test_face_rig_roster.gd`:

```gdscript
func test_every_rig_has_eyelid_art() -> void:
	# A rig whose Eyelid layer has no texture blinks invisibly.
	for student_name in StudentSkins.NAMES:
		var path := "res://Assets/Images/MuridPotrait/%s/%s_eyelid.png" % [
			student_name, student_name.to_lower()]
		assert_true(ResourceLoader.exists(path),
			"%s must have eyelid art at %s" % [student_name, path])
```

- [ ] **Step 2: Run the tests**

Run: `test_run(suite="student_face", session_id=<id>)` and
`test_run(suite="face_rig_roster", session_id=<id>)`

Expected: **PASS on the first run.** This task pins shipped behaviour, so a
green here is the point — it is not a test-first red step. If one goes red, the
behaviour is not what the spec claims: stop and report before changing either
the test or the rig.

- [ ] **Step 3: Watch it**

Seed, teleport to the Lobby, and watch for 20 s. The overlay eats the first tap
when a debug teleport is called from `game_eval`, so open the overlay first.
Confirm the six seats blink independently, not in chorus.

- [ ] **Step 4: Commit**

```bash
git add tests/test_student_face.gd tests/test_face_rig_roster.gd
git commit -F <message file>
```

Message: `test(lobby): pin the 5-10 s idle blink and its eyelid art`

---

### Task 8: The device back button

Android delivers the hardware/gesture back press as
`NOTIFICATION_WM_GO_BACK_REQUEST` — **not** as `ui_cancel`, so an `_input`
handler never sees it. Six screens already answer it; seven with a working
on-screen back button do not, and because `quit_on_go_back` defaults to
**true** a back press on those **quits the game and loses the run**.

**Files:**
- Modify: `project.godot`
- Modify: `Scripts/AturJadwal/atur_jadwal.gd`, `Scripts/Koperasi/shop_hub.gd`,
  `Scripts/Koperasi/cosmetic_shop.gd`, `Scripts/ReportCard/report_card.gd`,
  `Scripts/Pengaturan.gd`, `Scripts/UI/Settings.gd`,
  `Scripts/SchoolSimulation/SchoolDay.gd`,
  `Scripts/Minigames/UI/BaseMinigame.gd`
- Test: `tests/test_device_back_button.gd` (new)

**Interfaces:**
- Consumes: each screen's existing `_on_back_pressed()` (or its local name —
  `grep` per file; they are not all spelled the same).
- Produces: nothing new. The point is that back routes to the *existing*
  handler, so the animation, the `AudioDirector` cue and the destination are
  identical to the on-screen button.

- [ ] **Step 1: Write the failing test**

Create `tests/test_device_back_button.gd`:

```gdscript
@tool
extends McpTestSuite

## The Android hardware/gesture back button must do what the screen's own
## back button does.
##
## Source scans, like test_audio_coverage: these screens cannot be
## instantiated headlessly, and Godot delivers the press as a notification
## the runner has no way to post. What this buys: every screen HAS a
## handler and it routes to the screen's own back path. What it does not:
## that the handler runs at the right moment on a real device. The plan's
## Step 5 is a real Android build for that.

func suite_name() -> String:
	return "device_back_button"


## Every screen with an on-screen back button, and the handler its device
## back press must reach. Seven of these had no handler at all before
## 2026-09-21, and because quit_on_go_back defaults to true a back press on
## them quit the game outright.
const SCREENS := {
	"res://Scripts/AturJadwal/atur_jadwal.gd": "_on_back_pressed",
	"res://Scripts/Koperasi/shop_hub.gd": "_on_back_pressed",
	"res://Scripts/Koperasi/cosmetic_shop.gd": "_on_back_pressed",
	"res://Scripts/ReportCard/report_card.gd": "_on_back_pressed",
	"res://Scripts/Pengaturan.gd": "_on_back_pressed",
	"res://Scripts/UI/Settings.gd": "_on_back_pressed",
	"res://Scripts/SchoolSimulation/SchoolDay.gd": "_on_back_pressed",
	"res://Scripts/Koperasi/koprasi.gd": "_on_back_pressed",
	"res://Scripts/Inventory/inventory.gd": "_on_back_pressed",
	"res://Scripts/Achievements/achievements_screen.gd": "_on_back_pressed",
}


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


func test_every_screen_answers_the_go_back_notification() -> void:
	for path in SCREENS:
		assert_true(_source(path).contains("NOTIFICATION_WM_GO_BACK_REQUEST"),
			"%s must answer the device back button" % path)


func test_the_notification_routes_to_the_screens_own_back_handler() -> void:
	# "Works the same as the return button" is the literal requirement: the
	# notification must call the same function, not a second path that drifts
	# from it.
	for path in SCREENS:
		var src := _source(path)
		var handler: String = SCREENS[path]
		var at := src.find("NOTIFICATION_WM_GO_BACK_REQUEST")
		assert_true(at >= 0, "%s must answer the back button" % path)
		# The handler call must appear within the notification block, not
		# merely somewhere in the file (the on-screen button calls it too).
		var after := src.substr(at, 400)
		assert_true(after.contains(handler + "("),
			"%s's back notification must call %s()" % [path, handler])


func test_the_game_no_longer_quits_on_a_back_press() -> void:
	# Without this, a screen that forgets a handler drops the player to the
	# home screen and the run is gone -- roster, money, week and schedules
	# are all session-scoped and none of them reach disk.
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back", true),
		"quit_on_go_back must be false so a stray back press cannot end a run")


func test_a_minigame_back_press_opens_the_pause_menu() -> void:
	# Never an instant exit: a mis-swipe must not forfeit a minigame, and
	# BaseMinigame already owns a quit confirmation for exactly this.
	var src := _source("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_true(src.contains("NOTIFICATION_WM_GO_BACK_REQUEST"),
		"a minigame must answer the back button")
	var at := src.find("NOTIFICATION_WM_GO_BACK_REQUEST")
	var after := src.substr(at, 400)
	assert_false(after.contains("change_scene("),
		"a minigame's back press must open the pause menu, not leave outright")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="device_back_button", session_id=<id>)`
Expected: FAIL — seven screens have no handler and `quit_on_go_back` is unset
(so it reads back as its `true` default).

- [ ] **Step 3: Find each screen's real handler name**

They are **not** all spelled `_on_back_pressed`. Check before writing, and fix
the `SCREENS` dict above to match reality rather than bending the code to the
test:

```bash
grep -n "func _on_back\|func _on_kembali\|func _on_back_button" Scripts/AturJadwal/atur_jadwal.gd Scripts/Koperasi/shop_hub.gd Scripts/Koperasi/cosmetic_shop.gd Scripts/ReportCard/report_card.gd Scripts/Pengaturan.gd Scripts/UI/Settings.gd Scripts/SchoolSimulation/SchoolDay.gd
```

- [ ] **Step 4: Add the handler to each screen**

The established shape, copied from `koprasi.gd:181`. For a screen with no
overlay:

```gdscript
## Android delivers the hardware/gesture back press as a notification, not as
## ui_cancel, so an _input handler never sees it. Routed to the same function
## the on-screen back button calls, so both do exactly the same thing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()
```

For a screen that can raise a sheet or popup, add the guard — otherwise one
back press walks two steps:

```gdscript
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	# The open overlay handles its own back press and frees itself; only fall
	# through to leaving the screen when nothing is up.
	if _sheet != null:
		return
	_on_back_pressed()
```

Where a screen already defines `_notification` (e.g. `report_card.gd:78`
handles `NOTIFICATION_WM_WINDOW_FOCUS_IN`), **add a branch to the existing
function** — a second `_notification` in the same script silently replaces the
first.

For `BaseMinigame.gd`, route to the pause menu rather than an exit — find the
function the on-screen pause button calls and call that.

For `SchoolDay.gd`, read what its on-screen back control actually does before
wiring it; mid-simulation, "back" is not necessarily "leave the week".

- [ ] **Step 5: Stop the game quitting on back**

Add to `project.godot` under `[application]`:

```
config/quit_on_go_back=false
```

MainMenu then owns the only deliberate exit. If MainMenu has no quit path at
all, leave it — adding one is out of scope for this branch, and a back press
that does nothing on the title screen is strictly better than one that ends a
run from Atur Jadwal.

- [ ] **Step 6: Run the test to verify it passes**

Run: `test_run(suite="device_back_button", session_id=<id>)`
Expected: PASS.

`project.godot` is read at boot, so **restart the second editor** before
believing the `quit_on_go_back` assertion — `ProjectSettings` serves the
value the editor started with.

- [ ] **Step 7: Check nothing else regressed**

Run: `test_run(suite="koperasi", session_id=<id>)`,
`test_run(suite="atur_jadwal", session_id=<id>)`,
`test_run(suite="skin_select_popup", session_id=<id>)`
Expected: PASS. The last one already owns a go-back test and is the one most
likely to notice a double-handled press.

- [ ] **Step 8: Press it on a real device**

A source scan cannot tell you a back press fires at the right moment, and the
editor cannot post the notification. Export an Android build (or run the
remote-deploy target) and press the gesture back on: Atur Jadwal, Shop Hub, the
Koperasi with a loaded tray, a minigame mid-round, and SchoolDay mid-week.

Watch for the two failure shapes a scan cannot see: **one press, two steps**
(an overlay and the screen under it both acting) and **a press that quits**
(a screen still falling through).

If no device or export template is available, say so plainly in the final
report rather than claiming this step passed — the code change is still
correct, but it will be unverified on the one platform it exists for.

- [ ] **Step 9: Commit**

```bash
git add project.godot Scripts tests/test_device_back_button.gd
git commit -F <message file>
```

Message: `feat(nav): the device back button does what the screen's back button does`

---

### Task 9: The UI consistency pass

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`, `Assets/Theme/kejartes_theme.tres`
- Modify: the Koperasi, minigame-result and Lobby scenes' overrides
- Modify: `docs/superpowers/DEBT.md`
- Test: `tests/test_theme_factory.gd`

- [ ] **Step 1: Inventory the debt**

```bash
grep -rn "theme_override_font_sizes\|theme_override_styles\|theme_override_colors" Scenes Scripts --include=*.tscn --include=*.gd
```

66 today (29 font_sizes, 23 styles, 14 colors). Group them by screen and write
the whole list into `docs/superpowers/DEBT.md` under a new
`## Theme override debt (2026-09-21)` heading, so the next pass has a work list
instead of a grep.

- [ ] **Step 2: Fix the ones on this branch's screens**

Only the Koperasi screens, `MinigameResultPopup.tscn` / `ResultStar.tscn`, and
`loby.tscn`. For each override, either use an existing `ThemeFactory` variation
or add one and rebake. Leave `theme_override_constants` that are
`separation` / `margin_*` — those are the accepted layout-only exception.

- [ ] **Step 3: Rebake, alone**

Run `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X). **Rebake alone,
never beside scene ops**: the cached theme merges stale stylebox props by id and
a `scene_save` writes it back. Diff the bake before committing:

```bash
git diff --stat Assets/Theme/kejartes_theme.tres
```

If a stylebox you did not touch has moved, restart the editor and rebake again.

- [ ] **Step 4: Run the theme suite**

Run: `test_run(suite="theme_factory", session_id=<id>)`
Expected: PASS. `DISPLAY_ROSTER` pins which variation gets Boohong and which
gets Open Sans in **both** directions — a new variation must be added to the
roster and to `ThemeFactory` together, or the suite fails.

- [ ] **Step 5: Critique the three screens**

Capture each at full size and run `/design-audit-ui` on the captures: the
Koperasi shelf with a loaded tray, the minigame result card at three stars, and
the Lobby. Judge at full size — a scaled capture cannot show 1px detail,
spacing or weight. Fix what the audit finds on these three screens; anything it
raises about a screen this branch does not touch goes into DEBT.md.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres Scenes docs/superpowers/DEBT.md
git commit -F <message file>
```

Message: `refactor(design): move this branch's screens off theme overrides`

---

### Task 10: The full suite and the changelog

- [ ] **Step 1: Restart the second editor**

Budget one restart per full run. Scenes must be saved first; a force-kill is
safe once they are, and the relaunch reloads every script tab from disk. After
editing `.gd` files from outside the editor, a no-op `script_patch` on each one
forces the reload before `test_run` serves a stale autoload.

- [ ] **Step 2: Run everything**

Run: `test_run(session_id=<id>)` with no `suite`.
Expected: 136+ suites green.

A full run is 15–20 s of near-continuous main-thread work and **the bridge does
not survive it** — the drop is expected, and the results are still valid when it
happens after the reply arrives. Budget one editor restart for it.

- [ ] **Step 3: Clean up what the run dirtied**

A full run writes two tracked files: `theme_rebake` calls `ResourceSaver.save()`
in-process (rebaking `Assets/Theme/kejartes_theme.tres`) and `AudioDirector`
rewrites `default_bus_layout.tres` on boot.

```bash
git status --porcelain
```

`git checkout --` whichever you did not intend. Also filter out
`addons/godot_ai/utils/update_activation_runner.gd` — that is the plugin's own
untracked file, not this branch's.

Suite order matters: a suite that reads the baked theme before `theme_rebake`
runs sees the *old* bake, so a single failing theme assertion in a full run may
just be ordering. Re-run that suite alone before believing it.

- [ ] **Step 4: Write the changelog entry**

Newest first in `docs/superpowers/CHANGELOG.md`: the tray gestures, the
fireworks, the sound pack, the blink verification, the override pass. Delete any
DEBT.md entry this branch resolved — an entry is deleted once resolved, not
marked done.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/DEBT.md
git commit -F <message file>
```

Message: `docs(changelog): record the tray, fireworks and audio pass`

---

## Self-review

**Spec coverage.** §1 tray drag → Task 1; §1 tap-to-return → Task 2; §2 star
art → Task 3; §2 fireworks + placement scene → Task 4; §3 sounds → Tasks 5–6;
§3b device back button → Task 8; §0 blink → Task 7; §4 UI consistency →
Task 9. §5 (files) and §6 (grades, no change) need no task. §7 (state) is
covered by Task 2 touching only `Cart`.

**Placeholder scan.** Every code step carries real code. Task 6 deliberately
tells the implementer to `grep` for the real script paths rather than naming
guessed ones, and says why inventing one is worse than looking.

**Type consistency.** `classify_drag` returns `int` (a `ViewState` value)
everywhere. `fire_burst(index: int)`, `burst_position(index: int)`,
`get_burst(index: int)` and `burst_count()` match between the test in Task 4
Step 1 and the script in Step 3. `badge_reveal_stream(band: String)` matches
between the test and the implementation. `play_ambience(id: StringName)` and
`get_ambience_player()` match. `cancel_press()` matches between Task 2's test
and both call sites.
