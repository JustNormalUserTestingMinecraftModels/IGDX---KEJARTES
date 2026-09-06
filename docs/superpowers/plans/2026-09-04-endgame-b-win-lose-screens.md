# End-Game Plan B — Win and Lose Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After StatCheck's white fade, land on a dedicated win screen or lose screen — white fading out over a full-bleed backdrop, a LULUS or GAGAL badge stamped top-left, then tap anywhere to continue to RunResult.

**Architecture:** One script, `EndScreen.gd`, drives two authored scenes, `WinScreen.tscn` and `LoseScreen.tscn`, which differ only in three exported values (backdrop texture, stamp texture, BGM id). The screen starts under an opaque white overlay (completing StatCheck's fade), fades it out, slams the stamp, then accepts a tap. StatCheck's two hand-off constants are repointed here. No branching by verdict inside the script — the verdict already chose which scene loaded.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` tests via the `godot-ai` MCP `test_run`. Scenes are built by the controller through the editor.

**Spec:** The user's 2026-09-04 end-game brief, bullet 4, and its Q&A. **Depends on Plan A** (`docs/superpowers/plans/2026-09-04-endgame-a-statcheck.md`): `StatCheck.NEXT_SCENE_WIN/LOSE`, the `WhiteFade` contract, `GameState.run_failed` written by StatCheck.

## Requirements (from the brief)

1. After the white screen fades out, teleport to `win_screen` or `lose_screen` by verdict (2–3 stars win; 1 and below lose) — not to a cutscene.
2. A badge is stamped on the top-left of the screen.
3. The player can tap anywhere to move on to RunResult.

## Decisions taken as defaults (override any by name)

- **D1 Badge art:** two generated placeholder stamps, `stamp_lulus.svg` and `stamp_gagal.svg` (rotated rounded rectangle with the word), to be swapped for real art. Emoji are banned as iconography, so these are SVG textures.
- **D2 Backgrounds:** reuse existing CG art as placeholders — `cg2.jpg` for the win screen, `cg0.jpg` for the lose screen — full-bleed under KEEP_ASPECT_COVERED.
- **D3 Exit transition:** the tap uses the project-wide default `Transition.change_scene()` wipe. Plan C's RunResult opens on the same backdrop, so the wipe reads as a page turn rather than a scene break.
- **D4 BGM:** `result_win` / `result_lose` — the ids SemesterEnd used to play — start here.

## Global Constraints

- Test suites MUST be `@tool` and extend `McpTestSuite`; **no test may be a coroutine**. The white fade and the stamp slam are tweens the tests never play — they assert on initial state and source text.
- Tests run via `test_run(suite=…)`; `filesystem_manage(op="scan")` after any external `.gd` edit; a no-op `script_patch` if the runner is stale.
- **Scenes are built by the controller through the editor** (`scene_manage(op="create")`, `node_create`, `node_set_property`, `scene_save`); `anchors_preset` is inert — set four anchors + offsets.
- **No `theme_override_*`**; use `ThemeFactory` variations. **No visual built at runtime.** No emoji iconography.
- UI text Indonesian; identifiers English. Tunables in `const`/`@export` with `##` docs; every script has a `##` file header.
- Commits: Conventional Commits with a scope; name files explicitly, never `git add -A`.
- Baseline before this plan: Plan A's full suite, **800 tests, 55 suites**.

## File Structure

| File | Responsibility |
|---|---|
| `Assets/Images/UI/Placeholders/stamp_lulus.svg`, `stamp_gagal.svg` (create) | Placeholder badges. |
| `Scripts/EndGame/EndScreen.gd` (create) | Shared behaviour: white fade-out, stamp slam, tap-to-continue. |
| `Scenes/EndGame/WinScreen.tscn`, `Scenes/EndGame/LoseScreen.tscn` (controller) | Two authored scenes on one script. |
| `Scripts/EndGame/StatCheck.gd` (modify) | `NEXT_SCENE_WIN/LOSE` repointed. |
| `tests/test_end_screens.gd` (create), `tests/test_stat_check.gd` (modify one test), `tests/test_audio_coverage.gd` (modify) | Coverage. |
| `CLAUDE.md` (modify) | Flow line. |

---

### Task 1: The two badges and the shared `EndScreen` script

**Files:**
- Create: `Assets/Images/UI/Placeholders/stamp_lulus.svg`, `Assets/Images/UI/Placeholders/stamp_gagal.svg`
- Create: `Scripts/EndGame/EndScreen.gd`
- Controller: `Scenes/EndGame/WinScreen.tscn`, `Scenes/EndGame/LoseScreen.tscn`
- Test: `tests/test_end_screens.gd` (create)

**Interfaces:**
- Consumes: `Juice.set_pivot_center`, `Juice.shake`, `Juice.tokens()` (`dur_fast`, `dur_instant`); `AudioDirector.play_bgm/play_sfx` (`stamp`, `success`, `fail`, `tap`); `Transition.change_scene(path)`.
- Produces: `EndScreen` (`class_name`, `extends Control`) with `@export var bgm: StringName`, `@export var stamp_texture: Texture2D`, `@export var white_fade_seconds: float = 0.8`, `@export var stamp_delay: float = 0.5`, `const RUN_RESULT_SCENE := "res://Scenes/EndGame/RunResult.tscn"`, `var can_continue: bool`, `func _slam_stamp() -> void`, `func _continue() -> void`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_end_screens.gd`:

```gdscript
@tool
extends McpTestSuite

## WinScreen and LoseScreen (Plan B, 2026-09-04): two authored scenes on
## one EndScreen.gd. Structural checks on bare instantiate()s plus source
## scans -- the white fade-out and the stamp slam are tweens the runner
## cannot await (see test_lobby.gd's no-coroutine note).

const _WIN := "res://Scenes/EndGame/WinScreen.tscn"
const _LOSE := "res://Scenes/EndGame/LoseScreen.tscn"
const _SCRIPT := "res://Scripts/EndGame/EndScreen.gd"


func suite_name() -> String:
	return "end_screens"


func _chrome_ok(path: String) -> void:
	var s = load(path).instantiate()
	track(s)
	assert_true(s is EndScreen, path + " wears EndScreen.gd")
	assert_true(s.get_node_or_null("Backdrop") is TextureRect, path + ": Backdrop")
	assert_true(s.get_node_or_null("Stamp") is TextureRect, path + ": Stamp")
	var white = s.get_node_or_null("WhiteFade")
	assert_true(white is ColorRect, path + ": WhiteFade")
	assert_true(is_equal_approx(white.color.a, 1.0) and is_equal_approx(white.modulate.a, 1.0),
		path + ": WhiteFade starts fully opaque -- it completes StatCheck's fade-in")
	assert_true(s.get_node_or_null("HintLabel") is Label, path + ": tap hint")


func test_win_screen_has_the_chrome() -> void:
	_chrome_ok(_WIN)


func test_lose_screen_has_the_chrome() -> void:
	_chrome_ok(_LOSE)


func test_the_two_scenes_differ_only_in_their_exports() -> void:
	var w = load(_WIN).instantiate()
	var l = load(_LOSE).instantiate()
	track(w)
	track(l)
	assert_eq(String(w.bgm), "result_win", "win BGM")
	assert_eq(String(l.bgm), "result_lose", "lose BGM")
	assert_true(String(w.stamp_texture.resource_path).ends_with("stamp_lulus.svg"), "win stamp")
	assert_true(String(l.stamp_texture.resource_path).ends_with("stamp_gagal.svg"), "lose stamp")
	assert_true(w.get_node("Backdrop").texture != l.get_node("Backdrop").texture,
		"different backdrops")


func test_the_stamp_sits_top_left_and_starts_hidden() -> void:
	for path in [_WIN, _LOSE]:
		var s = load(path).instantiate()
		track(s)
		var stamp: TextureRect = s.get_node("Stamp")
		assert_true(stamp.position.x < 200.0 and stamp.position.y < 300.0,
			path + ": the stamp is anchored to the top-left corner")
		assert_true(is_equal_approx(stamp.modulate.a, 0.0),
			path + ": the stamp is invisible until it slams")


func test_sequence_is_fade_out_then_slam_then_tap() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var fade_at := src.find("tween_property(white_fade, \"modulate:a\", 0.0, white_fade_seconds)")
	var slam_at := src.find("_slam_stamp()")
	var tap_at := src.find("can_continue = true")
	assert_true(fade_at != -1 and slam_at != -1 and tap_at != -1, "all three beats exist")
	assert_true(fade_at < slam_at and slam_at < tap_at,
		"white fades out, then the stamp slams, then taps are accepted -- in that order")
	assert_false(src.contains("run_failed"),
		"no verdict branching here -- the verdict already chose which scene loaded")


func test_tap_anywhere_continues_to_run_result_only_after_the_stamp() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("if not can_continue:"), "taps before the stamp are ignored")
	assert_true(src.contains("InputEventScreenTouch") and src.contains("InputEventMouseButton"),
		"touch and mouse both count as a tap")
	assert_true(src.contains("Transition.change_scene(RUN_RESULT_SCENE)"),
		"the tap hands off to RunResult with the project-wide wipe")
	assert_true(src.contains("const RUN_RESULT_SCENE := \"res://Scenes/EndGame/RunResult.tscn\""),
		"RunResult is the destination")


func test_slam_is_the_stamp_gesture_with_sfx() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("stamp.scale = Vector2(3.0, 3.0)"), "slams down from 3x")
	assert_true(src.contains("Tween.EASE_IN).set_trans(Tween.TRANS_BACK)"), "back-out overshoot")
	assert_true(src.contains("Juice.shake(stamp.get_parent()"), "shakes the screen")
	assert_true(src.contains("AudioDirector.play_sfx(&\"stamp\")"), "the stamp cue")


func test_badges_exist_and_load() -> void:
	for p in ["res://Assets/Images/UI/Placeholders/stamp_lulus.svg",
			"res://Assets/Images/UI/Placeholders/stamp_gagal.svg"]:
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_screens")`
Expected: FAIL — suite fails to load (`Identifier "EndScreen" not declared`).

- [ ] **Step 3: Write the badges**

`Assets/Images/UI/Placeholders/stamp_lulus.svg`:

```svg
<svg viewBox="0 0 320 160" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(-12 160 80)"><rect x="24" y="36" width="272" height="88" rx="14" fill="none" stroke="#2fb85a" stroke-width="10"/><text x="160" y="98" text-anchor="middle" font-family="Arial, sans-serif" font-size="54" font-weight="bold" fill="#2fb85a">LULUS</text></g></svg>
```

`Assets/Images/UI/Placeholders/stamp_gagal.svg`:

```svg
<svg viewBox="0 0 320 160" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(-12 160 80)"><rect x="24" y="36" width="272" height="88" rx="14" fill="none" stroke="#c42b3c" stroke-width="10"/><text x="160" y="98" text-anchor="middle" font-family="Arial, sans-serif" font-size="54" font-weight="bold" fill="#c42b3c">GAGAL</text></g></svg>
```

- [ ] **Step 4: Write `EndScreen.gd`**

```gdscript
@tool
class_name EndScreen
extends Control

## The win / lose beat (Plan B, 2026-09-04). One script, two authored
## scenes -- WinScreen.tscn and LoseScreen.tscn differ only in the three
## exports below. The verdict was decided by StatCheck, which loaded one
## of the two; nothing here re-reads it.
##
## Sequence: the scene opens under an opaque white overlay (finishing the
## white fade StatCheck started), fades it out, slams the stamp into the
## top-left, then accepts a tap anywhere to go on to RunResult.
##
## @tool so the MCP test suite can instantiate the scenes in the editor;
## every runtime side effect sits behind Engine.is_editor_hint().

## Which track starts with the screen: result_win or result_lose.
@export var bgm: StringName = &"result_win"
## The badge that slams in: stamp_lulus.svg or stamp_gagal.svg.
@export var stamp_texture: Texture2D
## Seconds the white overlay takes to clear.
@export var white_fade_seconds: float = 0.8
## Pause after the white clears before the stamp slams.
@export var stamp_delay: float = 0.5

const RUN_RESULT_SCENE := "res://Scenes/EndGame/RunResult.tscn"

@onready var white_fade: ColorRect = $WhiteFade
@onready var stamp: TextureRect = $Stamp
@onready var hint_label: Label = $HintLabel

## Taps are ignored until the stamp has landed.
var can_continue: bool = false
var _exiting: bool = false


func _ready() -> void:
	white_fade.modulate.a = 1.0
	stamp.modulate.a = 0.0
	hint_label.modulate.a = 0.0
	if stamp_texture != null:
		stamp.texture = stamp_texture
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(bgm)
	_play()


## The beat, as a coroutine -- never called from a test.
func _play() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 0.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(stamp_delay).timeout
	if not is_inside_tree():
		return
	_slam_stamp()
	await get_tree().create_timer(Juice.tokens().dur_normal).timeout
	Juice.fade_in(hint_label)
	can_continue = true


## The same slam SemesterEnd's stamp used: down from 3x, a shake, the cue.
func _slam_stamp() -> void:
	Juice.set_pivot_center(stamp)
	stamp.scale = Vector2(3.0, 3.0)
	stamp.modulate.a = 0.0
	var t := Juice.tokens()
	var tw := stamp.create_tween().set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(stamp, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(stamp.get_parent(), 8.0))


func _input(event: InputEvent) -> void:
	if not can_continue:
		return
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if tapped:
		_continue()


func _continue() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene(RUN_RESULT_SCENE)
```

- [ ] **Step 5: Controller — build both scenes in the editor**

Build `WinScreen.tscn`, save, then build `LoseScreen.tscn` identically with the three differing values.

```
scene_manage(op="create", params={"path": "res://Scenes/EndGame/WinScreen.tscn", "root_type": "Control", "root_name": "WinScreen"})
script_attach("/WinScreen", "res://Scripts/EndGame/EndScreen.gd")

/WinScreen                    Control  anchors 0,0,1,1 offsets 0
                              bgm "result_win"; stamp_texture ".../stamp_lulus.svg"
  Backdrop                    TextureRect  texture "res://Assets/Images/CG/cg2.jpg"; size {1080,1920}; expand_mode 1; stretch_mode 6
  Stamp                       TextureRect  texture ".../stamp_lulus.svg"; position {48,120}; size {480,240}; expand_mode 1; stretch_mode 5;
                              modulate {r:1,g:1,b:1,a:0}
  HintLabel                   Label  theme_type_variation "CaptionLabel"; text "Ketuk untuk melanjutkan"; horizontal_alignment 1;
                              position {110,1745}; size {857,60}; mouse_filter 2
  WhiteFade                   ColorRect  color {1,1,1,1}; modulate {r:1,g:1,b:1,a:1}; anchors 0,0,1,1 offsets 0; mouse_filter 2   # LAST child

scene_save()
```

`LoseScreen.tscn`: root `LoseScreen`, `bgm "result_lose"`, `stamp_texture ".../stamp_gagal.svg"`, `Stamp.texture` the same, `Backdrop.texture "res://Assets/Images/CG/cg0.jpg"`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` (new `class_name`; no-op `script_patch` if stale) then `test_run(suite="end_screens")`
Expected: PASS, 8 tests.

- [ ] **Step 7: Commit**

```bash
git add Assets/Images/UI/Placeholders/stamp_lulus.svg Assets/Images/UI/Placeholders/stamp_gagal.svg Assets/Images/UI/Placeholders/stamp_lulus.svg.import Assets/Images/UI/Placeholders/stamp_gagal.svg.import Scripts/EndGame/EndScreen.gd Scripts/EndGame/EndScreen.gd.uid Scenes/EndGame/WinScreen.tscn Scenes/EndGame/LoseScreen.tscn tests/test_end_screens.gd tests/test_end_screens.gd.uid
git commit -m "feat(endgame): add the win and lose screens with a stamped badge

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Route StatCheck into the new screens

**Files:**
- Modify: `Scripts/EndGame/StatCheck.gd` (the two constants)
- Modify: `tests/test_stat_check.gd` (`test_interim_hand_off_targets_run_result_until_plan_b`)
- Modify: `tests/test_audio_coverage.gd` (the result BGM block Plan A rewrote)

**Interfaces:**
- Consumes: Task 1's scenes.
- Produces: `StatCheck.NEXT_SCENE_WIN := "res://Scenes/EndGame/WinScreen.tscn"`, `NEXT_SCENE_LOSE := "res://Scenes/EndGame/LoseScreen.tscn"`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_stat_check.gd`, replace `test_interim_hand_off_targets_run_result_until_plan_b` with:

```gdscript
func test_hand_off_targets_the_win_and_lose_screens() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const NEXT_SCENE_WIN := \"res://Scenes/EndGame/WinScreen.tscn\""),
		"a win lands on WinScreen")
	assert_true(src.contains("const NEXT_SCENE_LOSE := \"res://Scenes/EndGame/LoseScreen.tscn\""),
		"a loss lands on LoseScreen")
	for p in ["res://Scenes/EndGame/WinScreen.tscn", "res://Scenes/EndGame/LoseScreen.tscn"]:
		assert_true(ResourceLoader.exists(p), p + " exists")
```

In `tests/test_audio_coverage.gd`, replace the block Plan A left ("result_win / result_lose moved to Plan B's win/lose screens…") with:

```gdscript
	# The result tracks start on Plan B's screens, one per scene via the
	# shared EndScreen.gd's `bgm` export; the script plays whichever it was
	# given, so the ids are asserted on the scenes, not the source.
	var win = load("res://Scenes/EndGame/WinScreen.tscn").instantiate()
	var lose = load("res://Scenes/EndGame/LoseScreen.tscn").instantiate()
	assert_eq(String(win.bgm), "result_win", "WinScreen plays result_win")
	assert_eq(String(lose.bgm), "result_lose", "LoseScreen plays result_lose")
	win.free()
	lose.free()
	var stat_check_src := _source("res://Scripts/EndGame/StatCheck.gd")
	assert_true(stat_check_src.contains('play_bgm(&"exam_notice")'),
		"StatCheck.gd must keep the exam BGM running")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="stat_check")` and `test_run(suite="audio_coverage")`
Expected: `stat_check` — the new test fails on the `WinScreen.tscn` constant; `audio_coverage` passes already (the scenes exist since Task 1) — that test is a guard.

- [ ] **Step 3: Repoint the constants**

In `Scripts/EndGame/StatCheck.gd` replace:

```gdscript
## Where the white fade lands. Plan B repoints both at its win/lose
## screens; until then the report follows straight on.
const NEXT_SCENE_WIN := "res://Scenes/EndGame/RunResult.tscn"
const NEXT_SCENE_LOSE := "res://Scenes/EndGame/RunResult.tscn"
```

with:

```gdscript
## Where the white fade lands, by verdict. Both screens open under their
## own opaque white overlay and fade it out, so the cut is seamless.
const NEXT_SCENE_WIN := "res://Scenes/EndGame/WinScreen.tscn"
const NEXT_SCENE_LOSE := "res://Scenes/EndGame/LoseScreen.tscn"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="stat_check")`, `test_run(suite="audio_coverage")`, `test_run(suite="end_screens")`.
Expected: all PASS.

- [ ] **Step 5: Live check, once (controller)**

`project_run(mode="main")` → F1 → Scenes → **Gladi Resik: Semua Lulus** (previous plan's rehearsal tool). Expected: … StatCheck fills 12/12, meter at 3.0, white fade → **WinScreen** with white clearing over `cg2.jpg`, LULUS stamp slams top-left, hint appears; a tap wipes to RunResult. Repeat with **Semua Gagal** → LoseScreen, GAGAL. One `editor_screenshot(source="game")` of each stamped screen. Then **Pulihkan**.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/StatCheck.gd tests/test_stat_check.gd tests/test_audio_coverage.gd
git commit -m "feat(endgame): hand StatCheck's verdict to the win and lose screens

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Documentation and the full-suite gate

**Files:**
- Modify: `CLAUDE.md` — the flow line from Plan A.

- [ ] **Step 1: Update the docs**

Change the flow to **TesNotice → ExamProgress → StatCheck → WinScreen / LoseScreen → RunResult → MainMenu** and append to the Plan A paragraph: "Plan B added `WinScreen`/`LoseScreen` (`EndScreen.gd`, one script, two scenes differing only in backdrop, stamp and BGM exports): the white overlay StatCheck ends on fades out here, a LULUS/GAGAL placeholder stamp (`stamp_lulus.svg`/`stamp_gagal.svg`) slams top-left, and a tap anywhere continues to RunResult."

- [ ] **Step 2: Run the full suite**

Run: `filesystem_manage(op="scan")`, `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, `test_run()`.
Expected: **808 tests, 56 suites** (800 + 8 `end_screens`; the replaced `stat_check` test nets 0). Any failure is a regression from this plan.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(endgame): describe the win and lose screens

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

(If `CLAUDE.md` carries unrelated uncommitted hunks, the controller commits it with the revert-commit-reapply procedure.)
