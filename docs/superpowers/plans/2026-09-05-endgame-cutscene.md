# End-Game Cutscene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Do NOT use subagent-driven-development:** the Godot AI MCP backend is single-client (see Global Constraints), so only the orchestrator may drive the editor.

**Goal:** Put a win/lose beat between StatCheck and RunResult — one full-bleed image for the outcome, a badge stamped into the top-left, then a Next button.

**Architecture:** One scene, `EndCutscene.tscn`, on one script, `EndCutscene.gd`. StatCheck already writes `GameState.run_failed`; this screen reads it once in `_ready()` and picks its backdrop, badge and BGM from paired `@export`s. The screen opens under an opaque white overlay, completing the fade StatCheck ends on, then runs a fixed tween/timer chain to the button.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` suites run in-editor via the `godot-ai` MCP `test_run`.

**Spec:** `docs/superpowers/specs/2026-09-05-endgame-cutscene-design.md`. Revises the unimplemented `docs/superpowers/plans/2026-09-04-endgame-b-win-lose-screens.md` (Plan B) — one scene instead of two, a Next button instead of tap-anywhere.

## Global Constraints

- Suites MUST be `@tool` and extend `McpTestSuite`; **no test may be a coroutine** — the runner calls tests without awaiting.
- Scripts the runner instantiates must be `@tool`, with runtime side effects behind `if Engine.is_editor_hint(): return`. **Pure signal wiring stays ungated** so tests can see it.
- A bare `instantiate()` does **not** run `_ready()`. Every "starts hidden / starts disabled" assertion therefore tests the value **authored in the `.tscn`**, not what `_ready()` sets. Author both.
- **Scenes are built through the editor**, never by hand-editing `.tscn` while the editor is attached: `scene_manage(op="create")` → `node_create` / `node_set_property` → `scene_save`. `anchors_preset` is inert — set the four anchors. Numbers unquoted. `node_create` appends last, so z-order needs `move_node`.
- After any `.gd` edit made outside the editor, `filesystem_manage(op="scan")`; a no-op `script_patch` if the runner still serves stale bytecode. Prefer editing via `script_patch`.
- The `godot-ai` MCP backend is single-client — do not dispatch a subagent that calls any `mcp__godot-ai__*` tool.
- **No `theme_override_*`** — use `ThemeFactory` type variations. **No visual built at runtime.** **No emoji as iconography.**
- UI text Indonesian; identifiers and comments English. Tunables are `const`/`@export` with `##` docs; every script gets a `##` file header (enforced by `tests/test_script_documentation.gd`).
- `Balance.gd` is collaborator-owned — not touched by this plan.
- Commits: Conventional Commits with a scope; name files explicitly, never `git add -A`.
- **Baseline before this plan: 909 tests, 61 suites, all green.**

## Decisions

- **D1 Badge art:** two generated placeholder stamps, `stamp_lulus.svg` / `stamp_gagal.svg` — a tilted rounded-rect rubber stamp in green / red with the Indonesian word. Godot rasterises SVG through ThorVG, whose `<text>` support is version-dependent; Task 1 Step 4 **verifies the word actually rendered** and falls back to path-drawn letterforms if it did not.
- **D2 Win backdrop:** `Assets/Images/CG/cg2.jpg`, existing, as a placeholder. The supplied `Downloads/CG_win.jpg` is **not** imported — see the spec's "Note on the win backdrop". The backdrop is an `@export`; final art is an Inspector change.
- **D3 Lose backdrop:** `Downloads/CG_lose.jpg`, imported to `Assets/Images/CG/cg_lose.jpg`.
- **D4 Button label:** `"Lanjut"` — the word `TesNotice.tscn` already uses for its forward button, not the mockup's English "Next".
- **D5 Exit transition:** `Transition.change_scene()`, the project-wide wipe. (StatCheck's *entry* hand-off deliberately bypasses Transition because its blue cover would flash over the white; leaving is unconstrained.)

## File Structure

| File | Responsibility |
|---|---|
| `Assets/Images/CG/cg_lose.jpg` (create) | Lose backdrop, imported from Downloads. |
| `Assets/Images/UI/Placeholders/stamp_lulus.svg`, `stamp_gagal.svg` (create) | Placeholder badges. |
| `Scripts/EndGame/EndCutscene.gd` (create) | Verdict binding, white fade-out, badge slam, button reveal, hand-off. |
| `Scenes/EndGame/EndCutscene.tscn` (create, via editor) | Authored chrome: Backdrop, Badge, BtnNext, WhiteFade. |
| `Scripts/EndGame/StatCheck.gd` (modify) | Both hand-off constants repointed. |
| `Scenes/EndGame/WinScreen.tscn` (delete) | Abandoned Plan B stub. |
| `tests/test_end_cutscene.gd` (create) | Coverage for the new screen. |
| `tests/test_stat_check.gd` (modify) | The hand-off-target test. |
| `tests/test_audio_coverage.gd` (modify) | The result-BGM block Plan A parked. |
| `CLAUDE.md` (modify) | Flow line. |

---

### Task 1: The three assets

**Files:**
- Create: `Assets/Images/CG/cg_lose.jpg`
- Create: `Assets/Images/UI/Placeholders/stamp_lulus.svg`, `Assets/Images/UI/Placeholders/stamp_gagal.svg`
- Test: `tests/test_end_cutscene.gd` (created here, one test only; the rest arrive in Task 2)

**Interfaces:**
- Produces: three importable `Texture2D` resources at the paths above. Task 2 assigns all three to `EndCutscene.tscn`'s exports.

- [ ] **Step 1: Write the failing test**

Create `tests/test_end_cutscene.gd`:

```gdscript
@tool
extends McpTestSuite

## EndCutscene (2026-09-05): the win/lose beat between StatCheck and
## RunResult. One scene, dressed by GameState.run_failed.
##
## Structural checks on a bare instantiate() plus source scans -- the white
## fade-out, the badge slam and the button reveal are a tween/timer chain the
## runner cannot await (see test_lobby.gd's no-coroutine note). Suite is
## @tool and no test is a coroutine.

const _SCENE := "res://Scenes/EndGame/EndCutscene.tscn"
const _SCRIPT := "res://Scripts/EndGame/EndCutscene.gd"


func suite_name() -> String:
	return "end_cutscene"


func test_badges_and_backdrops_exist_on_disk() -> void:
	for p in ["res://Assets/Images/UI/Placeholders/stamp_lulus.svg",
			"res://Assets/Images/UI/Placeholders/stamp_gagal.svg",
			"res://Assets/Images/CG/cg_lose.jpg"]:
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_cutscene")`
Expected: FAIL — all three paths missing.

- [ ] **Step 3: Copy the lose backdrop and write the two stamps**

```bash
cp "/c/Users/user/Downloads/CG_lose.jpg" "Assets/Images/CG/cg_lose.jpg"
```

`Assets/Images/UI/Placeholders/stamp_lulus.svg`:

```svg
<svg viewBox="0 0 320 160" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(-12 160 80)"><rect x="24" y="36" width="272" height="88" rx="14" fill="none" stroke="#2fb85a" stroke-width="10"/><text x="160" y="98" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="54" font-weight="bold" fill="#2fb85a">LULUS</text></g></svg>
```

`Assets/Images/UI/Placeholders/stamp_gagal.svg`:

```svg
<svg viewBox="0 0 320 160" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(-12 160 80)"><rect x="24" y="36" width="272" height="88" rx="14" fill="none" stroke="#c42b3c" stroke-width="10"/><text x="160" y="98" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="54" font-weight="bold" fill="#c42b3c">GAGAL</text></g></svg>
```

- [ ] **Step 4: Import, then verify the word actually rendered (D1)**

Run `filesystem_manage(op="scan")`, then confirm the rasterised stamps contain their word, not just an empty outlined box. Cheapest check: open the two `.svg` files in the editor's inspector preview, or drop one into a scratch `TextureRect` and `editor_screenshot`.

**If the word is missing** (ThorVG dropped `<text>`), replace the `<text>` element in both files with path-drawn letterforms — `LULUS` and `GAGAL` need only L, U, S, G, A, all constructible from straight strokes plus one arc — keeping the same viewBox, rotation, colour and stroke weight. Re-scan and re-check.

- [ ] **Step 5: Run the test to verify it passes**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_cutscene")`
Expected: PASS, 1 test.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/CG/cg_lose.jpg Assets/Images/CG/cg_lose.jpg.import Assets/Images/UI/Placeholders/stamp_lulus.svg Assets/Images/UI/Placeholders/stamp_lulus.svg.import Assets/Images/UI/Placeholders/stamp_gagal.svg Assets/Images/UI/Placeholders/stamp_gagal.svg.import tests/test_end_cutscene.gd tests/test_end_cutscene.gd.uid
git commit -m "feat(endgame): add the lose backdrop and the two placeholder stamps

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `EndCutscene.gd` and `EndCutscene.tscn`

**Files:**
- Create: `Scripts/EndGame/EndCutscene.gd`
- Create (via editor): `Scenes/EndGame/EndCutscene.tscn`
- Test: `tests/test_end_cutscene.gd` (extend)

**Interfaces:**
- Consumes: Task 1's three textures; `GameState.run_failed`; `Juice.set_pivot_center/tokens/pop_in/shake`; `AudioDirector.play_bgm/play_sfx`; `Transition.change_scene`.
- Produces: `EndCutscene` (`class_name`, `extends Control`) with `@export var win_backdrop/lose_backdrop/win_badge/lose_badge: Texture2D`, `@export var win_bgm/lose_bgm: StringName`, `@export var white_fade_seconds/image_hold_seconds/button_delay_seconds: float`, `const RUN_RESULT_SCENE`, `func _slam_badge() -> void`, `func _on_next_pressed() -> void`. Task 3 points StatCheck at `res://Scenes/EndGame/EndCutscene.tscn`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_end_cutscene.gd`:

```gdscript

func _scene() -> Node:
	var s = load(_SCENE).instantiate()
	track(s)
	return s


func test_scene_has_the_chrome() -> void:
	var s := _scene()
	assert_true(s is EndCutscene, "the scene wears EndCutscene.gd")
	assert_true(s.get_node_or_null("Backdrop") is TextureRect, "Backdrop")
	assert_true(s.get_node_or_null("Badge") is TextureRect, "Badge")
	assert_true(s.get_node_or_null("BtnNext") is Button, "BtnNext")
	assert_true(s.get_node_or_null("WhiteFade") is ColorRect, "WhiteFade")


func test_white_overlay_starts_opaque_to_finish_stat_checks_fade() -> void:
	var s := _scene()
	var white: ColorRect = s.get_node("WhiteFade")
	assert_true(is_equal_approx(white.color.a, 1.0),
		"the overlay's colour is fully opaque")
	assert_true(is_equal_approx(white.modulate.a, 1.0),
		"and it is not pre-faded -- StatCheck hands over mid-white")
	assert_eq(white.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay must never eat the Next button's clicks")


func test_white_overlay_draws_over_everything() -> void:
	var s := _scene()
	var kids := s.get_children()
	assert_eq(String(kids[kids.size() - 1].name), "WhiteFade",
		"WhiteFade is the last child, so it covers backdrop, badge and button")


func test_badge_starts_invisible_in_the_top_left() -> void:
	var s := _scene()
	var badge: TextureRect = s.get_node("Badge")
	assert_true(is_equal_approx(badge.modulate.a, 0.0),
		"the badge is invisible until it slams")
	assert_true(badge.position.x < 200.0 and badge.position.y < 400.0,
		"the badge sits in the top-left corner")


func test_next_button_starts_hidden_and_disabled() -> void:
	var s := _scene()
	var btn: Button = s.get_node("BtnNext")
	assert_true(is_equal_approx(btn.modulate.a, 0.0),
		"the button is invisible until the badge has landed")
	assert_true(btn.disabled,
		"and unpressable -- it is the only way forward, so it must not " +
		"be clickable before its cue")


func test_both_verdicts_are_dressed_from_exports() -> void:
	var s := _scene()
	assert_true(s.win_backdrop is Texture2D, "a win backdrop is assigned")
	assert_true(s.lose_backdrop is Texture2D, "a lose backdrop is assigned")
	assert_true(s.win_badge is Texture2D, "a win badge is assigned")
	assert_true(s.lose_badge is Texture2D, "a lose badge is assigned")
	assert_ne(s.win_backdrop, s.lose_backdrop, "the two outcomes look different")
	assert_ne(s.win_badge, s.lose_badge, "so do their badges")
	assert_eq(String(s.win_bgm), "result_win", "win BGM")
	assert_eq(String(s.lose_bgm), "result_lose", "lose BGM")


func test_verdict_comes_from_the_flag_stat_check_wrote() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("GameState.run_failed"),
		"the screen dresses itself from StatCheck's verdict")
	assert_false(src.contains("check_semester_passed"),
		"it must not recompute the verdict -- StatCheck already decided it")


func test_sequence_is_fade_then_slam_then_button() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var fade_at := src.find("tween_property(white_fade, \"modulate:a\", 0.0, white_fade_seconds)")
	var slam_at := src.find("_slam_badge()")
	var enable_at := src.find("btn_next.disabled = false")
	assert_true(fade_at != -1, "the white overlay clears")
	assert_true(slam_at != -1, "the badge slams")
	assert_true(enable_at != -1, "the button becomes pressable")
	assert_true(fade_at < slam_at and slam_at < enable_at,
		"in that order: the image first, then the badge, then the button")


func test_slam_is_the_same_stamp_gesture_run_result_uses() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("badge.scale = Vector2(3.0, 3.0)"), "slams down from 3x")
	assert_true(src.contains("Tween.EASE_IN).set_trans(Tween.TRANS_BACK)"), "back-out overshoot")
	assert_true(src.contains("Juice.shake(badge.get_parent()"), "shakes the screen")
	assert_true(src.contains("AudioDirector.play_sfx(&\"stamp\")"), "the stamp cue")


func test_the_button_is_the_only_way_to_run_result() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const RUN_RESULT_SCENE := \"res://Scenes/EndGame/RunResult.tscn\""),
		"RunResult is the destination")
	assert_true(src.contains("Transition.change_scene(RUN_RESULT_SCENE)"),
		"the hand-off uses the project-wide wipe")
	assert_true(src.contains("btn_next.pressed.connect(_on_next_pressed)"),
		"the button is wired to the hand-off")
	assert_false(src.contains("func _input(") or src.contains("InputEventScreenTouch"),
		"no tap-anywhere path -- the button is the only input")


func test_button_label_is_indonesian() -> void:
	var s := _scene()
	assert_eq(s.get_node("BtnNext").text, "Lanjut",
		"UI text is Indonesian, matching TesNotice's forward button")
```

- [ ] **Step 2: Run to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_cutscene")`
Expected: FAIL — the suite will not load (`Identifier "EndCutscene" not declared`).

- [ ] **Step 3: Write `Scripts/EndGame/EndCutscene.gd`**

```gdscript
@tool
class_name EndCutscene
extends Control

## The win / lose beat between StatCheck and RunResult (2026-09-05).
##
## One scene for both outcomes: StatCheck writes GameState.run_failed
## (StatCheck.gd), this screen reads it once in _ready() and picks a
## backdrop, a badge and a BGM from the paired exports below. Nothing else
## here branches, and it never recomputes the verdict.
##
## Sequence: the scene opens under an opaque white overlay -- completing the
## fade StatCheck ends on, which is why that hand-off deliberately bypasses
## Transition -- fades it out over the image, holds so the image reads,
## slams the badge into the top-left, holds again, then reveals the Next
## button. The button is the only way forward and is disabled until then.
##
## @tool so the MCP test suite can instantiate the scene inside the editor;
## every runtime side effect sits behind Engine.is_editor_hint(). The button
## signal is wired before that guard so the wiring is testable.

@export_group("Win")
## Backdrop shown when the run passed. Placeholder until final art lands.
@export var win_backdrop: Texture2D
## Badge stamped into the top-left when the run passed.
@export var win_badge: Texture2D
## BGM started when the run passed.
@export var win_bgm: StringName = &"result_win"

@export_group("Lose")
## Backdrop shown when the run failed.
@export var lose_backdrop: Texture2D
## Badge stamped into the top-left when the run failed.
@export var lose_badge: Texture2D
## BGM started when the run failed.
@export var lose_bgm: StringName = &"result_lose"

@export_group("Pacing")
## Seconds the opaque white overlay takes to clear.
@export var white_fade_seconds: float = 0.8
## Pause after the white clears, so the image reads before the badge lands.
@export var image_hold_seconds: float = 0.6
## Pause after the badge lands before the Next button appears.
@export var button_delay_seconds: float = 0.5

## Where the button goes.
const RUN_RESULT_SCENE := "res://Scenes/EndGame/RunResult.tscn"

@onready var backdrop: TextureRect = $Backdrop
@onready var badge: TextureRect = $Badge
@onready var btn_next: Button = $BtnNext
@onready var white_fade: ColorRect = $WhiteFade

var _exiting: bool = false


func _ready() -> void:
	btn_next.pressed.connect(_on_next_pressed)

	# Re-asserted here as well as authored in the scene: @tool means the
	# editor may have left any of these mid-edit.
	white_fade.modulate.a = 1.0
	badge.modulate.a = 0.0
	btn_next.modulate.a = 0.0
	btn_next.disabled = true

	if Engine.is_editor_hint():
		return

	_dress_for_verdict()
	_play()


## Reads the verdict once and dresses the screen. StatCheck decided it; this
## screen is only the reveal.
func _dress_for_verdict() -> void:
	var failed: bool = GameState.run_failed
	backdrop.texture = lose_backdrop if failed else win_backdrop
	badge.texture = lose_badge if failed else win_badge
	AudioDirector.play_bgm(lose_bgm if failed else win_bgm)


## The beat, as a coroutine -- never call this from a test.
func _play() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 0.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(image_hold_seconds).timeout
	if not is_inside_tree():
		return

	_slam_badge()
	await get_tree().create_timer(button_delay_seconds).timeout
	if not is_inside_tree():
		return

	btn_next.disabled = false
	Juice.pop_in(btn_next)


## The stamp gesture RunResult._slam_grade() uses for the letter: down from
## 3x with a back-out overshoot, a shake, and the stamp cue.
func _slam_badge() -> void:
	Juice.set_pivot_center(badge)
	badge.scale = Vector2(3.0, 3.0)
	badge.modulate.a = 0.0
	var t := Juice.tokens()
	var tw := badge.create_tween().set_parallel(true)
	tw.tween_property(badge, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(badge, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(badge.get_parent(), 8.0))


## Guarded so a double-tap cannot fire two scene changes, the same way
## TesNotice and RunResult guard theirs.
func _on_next_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	Transition.change_scene(RUN_RESULT_SCENE)
```

- [ ] **Step 4: Build the scene through the editor**

```
scene_manage(op="create", params={"path": "res://Scenes/EndGame/EndCutscene.tscn",
                                  "root_type": "Control", "root_name": "EndCutscene"})
script_attach("/EndCutscene", "res://Scripts/EndGame/EndCutscene.gd")
```

Then create the four children **in this order** (`node_create` appends, and the order is the z-order):

| Node | Type | Properties |
|---|---|---|
| `Backdrop` | `TextureRect` | anchors `0,0,1,1`; offsets `0`; `texture` = `res://Assets/Images/CG/cg2.jpg`; `expand_mode` `1`; `stretch_mode` `6`; `mouse_filter` `2` |
| `Badge` | `TextureRect` | `offset_left` `48`, `offset_top` `120`, `offset_right` `528`, `offset_bottom` `360`; `texture` = `res://Assets/Images/UI/Placeholders/stamp_lulus.svg`; `expand_mode` `1`; `stretch_mode` `5`; `modulate` `Color(1,1,1,0)`; `mouse_filter` `2` |
| `BtnNext` | `Button` | `offset_left` `290`, `offset_top` `1640`, `offset_right` `790`, `offset_bottom` `1780`; `text` `"Lanjut"`; `theme_type_variation` `"PrimaryButton"`; `disabled` `true`; `modulate` `Color(1,1,1,0)` |
| `WhiteFade` | `ColorRect` | anchors `0,0,1,1`; offsets `0`; `color` `Color(1,1,1,1)`; `modulate` `Color(1,1,1,1)`; `mouse_filter` `2` |

Then set the root's exports:

```
node_set_property("/EndCutscene", "win_backdrop",  "res://Assets/Images/CG/cg2.jpg")
node_set_property("/EndCutscene", "win_badge",     "res://Assets/Images/UI/Placeholders/stamp_lulus.svg")
node_set_property("/EndCutscene", "lose_backdrop", "res://Assets/Images/CG/cg_lose.jpg")
node_set_property("/EndCutscene", "lose_badge",    "res://Assets/Images/UI/Placeholders/stamp_gagal.svg")
scene_save()
```

`Backdrop` and `Badge` carry the *win* textures as their authored values purely so the editor preview is not blank; `_dress_for_verdict()` overwrites both at runtime.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` (new `class_name` — a no-op `script_patch` if the runner is stale) then `test_run(suite="end_cutscene")`
Expected: PASS, 12 tests.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/EndCutscene.gd Scripts/EndGame/EndCutscene.gd.uid Scenes/EndGame/EndCutscene.tscn tests/test_end_cutscene.gd
git commit -m "feat(endgame): add the win/lose cutscene beat with a stamped badge

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Route StatCheck into it, and drop the abandoned stub

**Files:**
- Modify: `Scripts/EndGame/StatCheck.gd:20-22`
- Delete: `Scenes/EndGame/WinScreen.tscn`
- Modify: `tests/test_stat_check.gd:280-287`
- Modify: `tests/test_audio_coverage.gd:351-356`

**Interfaces:**
- Consumes: Task 2's `EndCutscene.tscn`.
- Produces: `StatCheck.NEXT_SCENE_WIN` and `NEXT_SCENE_LOSE`, both `"res://Scenes/EndGame/EndCutscene.tscn"`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_stat_check.gd`, replace `test_interim_hand_off_targets_run_result_until_plan_b` (lines 280-287) with:

```gdscript
func test_hand_off_targets_the_end_cutscene_for_both_verdicts() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const NEXT_SCENE_WIN := \"res://Scenes/EndGame/EndCutscene.tscn\""),
		"a win lands on the end cutscene")
	assert_true(src.contains("const NEXT_SCENE_LOSE := \"res://Scenes/EndGame/EndCutscene.tscn\""),
		"so does a loss -- one scene dresses itself from GameState.run_failed")
	assert_true(ResourceLoader.exists("res://Scenes/EndGame/EndCutscene.tscn"),
		"the destination exists")
```

The neighbouring test at line 265 (`"NEXT_SCENE_WIN if not GameState.run_failed else NEXT_SCENE_LOSE"`) stays as-is: the ternary is still there, both arms simply now resolve to the same path, and keeping it means re-pointing one arm later cannot go unnoticed.

In `tests/test_audio_coverage.gd`, replace lines 351-356 with:

```gdscript
	# result_win / result_lose moved off SemesterEnd when StatCheck replaced
	# it, and now start on the end cutscene -- one scene, one of two exported
	# ids chosen by the verdict, so the ids are asserted on the scene rather
	# than on a play_bgm call site.
	var cutscene = load("res://Scenes/EndGame/EndCutscene.tscn").instantiate()
	assert_eq(String(cutscene.win_bgm), "result_win", "the win path plays result_win")
	assert_eq(String(cutscene.lose_bgm), "result_lose", "the lose path plays result_lose")
	cutscene.free()
	var stat_check_src := _source("res://Scripts/EndGame/StatCheck.gd")
	assert_true(stat_check_src.contains('play_bgm(&"exam_notice")'),
		"StatCheck.gd must keep the exam BGM running")
```

- [ ] **Step 2: Run them to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="stat_check")` and `test_run(suite="audio_coverage")`
Expected: `stat_check` fails on the two constants. `audio_coverage` should already pass (the scene exists from Task 2) — it is a guard against the ids drifting.

- [ ] **Step 3: Repoint the constants**

In `Scripts/EndGame/StatCheck.gd`, replace:

```gdscript
## Where the white fade lands. Plan B repoints both at its win/lose
## screens; until then the report follows straight on.
const NEXT_SCENE_WIN := "res://Scenes/EndGame/RunResult.tscn"
const NEXT_SCENE_LOSE := "res://Scenes/EndGame/RunResult.tscn"
```

with:

```gdscript
## Where the white fade lands. Both verdicts land on the same screen --
## EndCutscene dresses itself from GameState.run_failed, which _hand_off()
## writes just below. The ternary at the hand-off is kept rather than
## collapsed so re-pointing one arm stays a one-line change.
const NEXT_SCENE_WIN := "res://Scenes/EndGame/EndCutscene.tscn"
const NEXT_SCENE_LOSE := "res://Scenes/EndGame/EndCutscene.tscn"
```

- [ ] **Step 4: Delete the abandoned stub**

`Scenes/EndGame/WinScreen.tscn` is untracked in git — a half-built copy of CutScene's layout with no script and no stamp, superseded by `EndCutscene.tscn`. Remove it from disk, then `filesystem_manage(op="scan")`.

```bash
rm "Scenes/EndGame/WinScreen.tscn"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="stat_check")`, `test_run(suite="audio_coverage")`, `test_run(suite="end_cutscene")`.
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/StatCheck.gd tests/test_stat_check.gd tests/test_audio_coverage.gd
git commit -m "feat(endgame): hand StatCheck's verdict to the end cutscene

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Live check, docs, and the full-suite gate

**Files:**
- Modify: `CLAUDE.md` (the flow line and the Current work paragraph)

- [ ] **Step 1: Live check both paths**

`project_run(mode="main")` → F1 → **Scenes** tab → **🎯 Skenario: Nilai A**.

Expected: TesNotice → ExamProgress → StatCheck fills 12/12 with the meter at 3.0 → white fade → **EndCutscene**: white clears over `cg2.jpg`, the LULUS stamp slams top-left with a shake, the **Lanjut** button pops in, and pressing it wipes to RunResult showing **A**.

Repeat with **🎯 Skenario: Nilai D** — expect `cg_lose.jpg`, the GAGAL stamp, and a **D**. One `editor_screenshot(source="game")` of each stamped screen. Then press **↩ Pulihkan Run Sebelum Gladi Resik** and `project_manage(op="stop")`.

Note: the overlay's scenario buttons sit below the fold in the Scenes tab and the wheel-scroll input simulation has been unreliable — if a simulated click will not register, drive the check from the unscrolled **🚀 Teleport ke: Notice Tes Besar (TesNotice)** button after arming a preset, or verify by hand.

- [ ] **Step 2: Update the docs**

In `CLAUDE.md`, change the end-of-grade flow line to:

**TesNotice → ExamProgress → StatCheck → EndCutscene → RunResult → MainMenu**

and append to the Current work paragraph:

"The 2026-09-05 pass added `EndCutscene` between StatCheck and RunResult: one scene for both outcomes, dressed from `GameState.run_failed` — a full-bleed backdrop, a LULUS/GAGAL placeholder stamp slammed into the top-left, then a `Lanjut` button. Its win backdrop is a placeholder (`cg2.jpg`); the backdrop and badge are `@export`s."

Also add to **Outstanding debt & placeholders**:

"**End cutscene art.** `EndCutscene`'s win backdrop is `cg2.jpg` standing in for final art, and both badges (`stamp_lulus.svg`, `stamp_gagal.svg`) are generated placeholder stamps. All four are `@export`s on `EndCutscene.tscn`."

- [ ] **Step 3: Run the full suite**

Run: `filesystem_manage(op="scan")`, `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, `test_run()`.
Expected: **921 tests, 62 suites** — 909 + 12 new `end_cutscene` tests; the replaced `stat_check` test nets 0, the rewritten `audio_coverage` block nets 0. Any other change is a regression from this plan.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(endgame): describe the end cutscene beat

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
