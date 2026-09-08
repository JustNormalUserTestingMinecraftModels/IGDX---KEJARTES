# Sprite Rigs, Dialog Restyle, Day Phases and Shop Hub — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land five independent presentation changes from
`docs/superpowers/specs/2026-09-07-sprite-rig-and-shop-hub-design.md` —
a two-state goalie, a layered dancer rig, a restyled event dialog, a
three-pose day cycle, and a new shop hub.

**Architecture:** Each task swaps runtime-constructed or hardcoded
presentation for authored scenes driven by documented `@export` knobs.
Three of the five lower the `test_viewport_editability.gd` ratchet.
Nothing here changes gameplay maths.

**Tech Stack:** Godot 4.6, GDScript, `godot-ai` MCP editor bridge,
`McpTestSuite` test suites, `ThemeFactory` design tokens.

## Global Constraints

Every task's requirements implicitly include this section.

- **Godot 4.6**, mobile renderer, portrait 1080×1920 design space.
- **Test suites must be `@tool`** and extend `McpTestSuite`, or the
  runner reports them abstract.
- **No test may be a coroutine.** The runner does `suite.call(name)`
  without awaiting; an `await` aborts the test silently and it reports
  "0 assertions".
- **Scripts the runner instantiates live must be `@tool`**, with real
  side effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` → `node_create` / `node_set_property` / `node_manage` →
  `scene_save`. A node's *type* can only be changed by delete-and-recreate.
- **`anchors_preset` is inert** over MCP — set the four anchors. Numbers
  must be unquoted (`1`, not `"1.0"`). `node_create` appends last, so
  z-order needs `move_node`.
- **Rescan after editing a `.gd`, before `test_run`**, or a stale
  autoload is served. If the file was edited from *outside* the editor,
  a scan is not enough — do a no-op `script_patch` on it (add and remove
  a blank line) to force the reload. It logs a benign
  `GDScript reload failed with error code 43` and then works.
- **The MCP bridge is single-client.** A subagent that connects
  displaces this session. Subagents write code; the session runs the editor.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type
  variation. Only layout-only constant overrides (`separation`,
  `margin_*`) are accepted.
- **No emoji as UI iconography.** Real transparent SVG textures only.
- **New SVGs must draw glyphs as stroked paths, never `<text>`** —
  Godot rasterises SVG through ThorVG, which silently drops text elements.
- **All UI text is Indonesian.** Engine and systems code is English.
- **`Balance.gd` is collaborator-owned. Read it; never edit it.**
- **Every script needs a `##` file header and a `##` line on every
  `@export`** — enforced by `tests/test_script_documentation.gd`.
- **`test_viewport_editability.gd`'s `BASELINE` is lowered only, never raised.**
- Tunable numbers belong in a named `const` block or an `@export`, never inline.
- Commits use Conventional Commits with a scope.

**Source art** is in the Windows `Downloads` folder
(`C:/Users/user/Downloads/`): `kiper_idle.png`, `kiper_jump.png`,
`dance_body_idle.png`, `dance_body_side.png`, `dance_body_up.png`,
`dance_head.png`. All are 1280×1280 RGBA.

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `Assets/Images/Textures/kiper_idle.png` | goalie ready pose |
| `Assets/Images/Textures/kiper_jump.png` | goalie dive pose |
| `Assets/Images/Textures/dance_body_{idle,side,up}.png` | dancer body poses |
| `Assets/Images/Textures/dance_head.png` | dancer head layer |
| `Scenes/Minigames/SeniBudaya/DancerRig.tscn` | two-layer dancer |
| `Scripts/Minigames/SeniBudaya/DancerRig.gd` | rig geometry + pose API |
| `Scenes/SchoolSimulation/EventStudentCard.tscn` | one selectable student card |
| `Scripts/SchoolSimulation/EventStudentCard.gd` | card population + preview |
| `Scenes/Koperasi/ShopHub.tscn` + `ShopHubTile.tscn` | shop hub |
| `Scripts/Koperasi/shop_hub.gd` | hub routing |
| `Scenes/Koperasi/CosmeticShop.tscn` | cosmetic stub |
| `Scripts/Koperasi/cosmetic_shop.gd` | stub back button |
| `Assets/Images/Shop/UI/icon_shop_{items,cosmetics}.svg` | hub tile icons |
| `Assets/Images/UI/Placeholders/icon_{benefit,cost,tired,specialty,check}.svg` | dialog icons |
| `tests/test_dancer_rig.gd`, `tests/test_shop_hub.gd`, `tests/test_book_clock_phases.gd` | new coverage |

**Modify:** `Scripts/Minigames/Olahraga/MainBola.gd`,
`Scripts/Minigames/SeniBudaya/LombaMenari.gd`,
`Scripts/SchoolSimulation/EventStudentSelectDialog.gd`,
`Scripts/SchoolSimulation/BookClockWidget.gd`,
`Scripts/SchoolSimulation/SchoolDay.gd:355`,
`Scripts/Lobby/loby.gd:788`, `Scripts/Koperasi/koprasi.gd:102`,
`Scripts/Design/ThemeFactory.gd`, `Scripts/Debug/DebugManager.gd`,
`tests/test_main_bola_layout.gd`, `tests/test_viewport_editability.gd`.

---

## Task 1: Goalie two-state textures and dive flip

**Files:**
- Create: `Assets/Images/Textures/kiper_idle.png`, `Assets/Images/Textures/kiper_jump.png`
- Modify: `Scripts/Minigames/Olahraga/MainBola.gd:5-13`, `:329-332`, `:536-538`
- Modify: `Scenes/Minigames/Olahraga/MainBola.tscn` (Goalie/GFX texture ref)
- Test: `tests/test_main_bola_layout.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `MainBola.gd` exports `goalie_idle_texture: Texture2D`,
  `goalie_jump_texture: Texture2D`, `jump_faces_right: bool`,
  `center_block_uses_jump: bool`. Task 2 relies on none of these.

- [ ] **Step 1: Copy the two sprites into the project and import them**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
cp "C:/Users/user/Downloads/kiper_idle.png" Assets/Images/Textures/kiper_idle.png
cp "C:/Users/user/Downloads/kiper_jump.png" Assets/Images/Textures/kiper_jump.png
```

Then trigger the import through the editor so `.import` files are
generated — MCP `filesystem_manage(op="scan")`. Do not write `.import`
files by hand.

- [ ] **Step 2: Update the texture-export list in the test to the new shape**

In `tests/test_main_bola_layout.gd`, replace the `TEXTURE_EXPORTS` const:

```gdscript
## Every art slot the script used to fetch with a hardcoded load().
## The goalkeeper collapsed from four textures to two on 2026-09-07:
## one idle, one dive, with direction carried by flip_h instead.
const TEXTURE_EXPORTS: Array[String] = [
	"goalie_idle_texture", "goalie_jump_texture",
	"ball_texture", "field_background_texture",
]

## Textures the two-state goalie retired. Named so a revert is loud.
const RETIRED_TEXTURE_EXPORTS: Array[String] = [
	"goalie_left_texture", "goalie_right_texture", "goalie_fail_texture",
]
```

Add these tests to the same file:

```gdscript
func test_goalie_has_exactly_two_pose_textures() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "kiper_idle.png",
		"goalie_idle_texture should preload the new alpha PNG")
	assert_contains(src, "kiper_jump.png",
		"goalie_jump_texture should preload the new alpha PNG")


func test_retired_goalie_textures_are_gone() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in RETIRED_TEXTURE_EXPORTS:
		assert_false(src.contains(retired),
			"%s should have been removed with the two-state goalie" % retired)


func test_dive_direction_uses_flip_h_not_a_texture_swap() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "goalie_gfx.flip_h",
		"dive direction should mirror the one jump sprite, not swap textures")
	assert_contains(src, "jump_faces_right",
		"which way the jump art faces must stay an Inspector toggle")
```

- [ ] **Step 3: Run the suite and confirm the new tests fail**

Run MCP `test_run` scoped to `main_bola_layout`.
Expected: FAIL — `kiper_idle.png` not found in source, `goalie_left_texture` still present.

- [ ] **Step 4: Rewrite the goalie export block**

Replace `MainBola.gd:5-13` (the four goalie texture exports) with:

```gdscript
# ─── Visual - Art ────────────────────────────────────────────────────────────
@export_group("Visual - Art")
## The goalkeeper standing ready, before the shot resolves.
@export var goalie_idle_texture: Texture2D = preload("res://Assets/Images/Textures/kiper_idle.png")
## The goalkeeper diving. One sprite serves both directions -- a left dive
## is this same art mirrored, so the pose only had to be drawn once.
@export var goalie_jump_texture: Texture2D = preload("res://Assets/Images/Textures/kiper_jump.png")
## True when goalie_jump_texture is drawn diving toward screen-RIGHT.
## Flip this if a replacement dive sprite faces the other way; nothing
## else needs to change.
@export var jump_faces_right: bool = true
## When true a centre block also shows the dive pose. Off by default:
## on dive_dir == 0 the keeper does not move, so he should not be mid-air.
@export var center_block_uses_jump: bool = false
```

- [ ] **Step 5: Replace the texture swap with a mirror**

At `MainBola.gd:536-538`, replace:

```gdscript
	# ── Set goalie direction texture ─────────────────────────
	if goalie_gfx:
		goalie_gfx.texture = goalie_left_texture if dive_dir < 0 else goalie_right_texture
```

with:

```gdscript
	# ── Set goalie pose ──────────────────────────────────────
	# One dive sprite serves both sides: flip_h mirrors it. The XOR
	# against jump_faces_right means a replacement sprite drawn facing
	# the other way needs an Inspector toggle, not a code edit.
	if goalie_gfx:
		if dive_dir == 0 and not center_block_uses_jump:
			goalie_gfx.texture = goalie_idle_texture
			goalie_gfx.flip_h = false
		else:
			goalie_gfx.texture = goalie_jump_texture
			goalie_gfx.flip_h = (dive_dir < 0) == jump_faces_right
```

- [ ] **Step 6: Clear the mirror when the keeper resets**

At `MainBola.gd:667-669`, the reset already restores the idle texture.
Add the flip reset so a left dive does not leave the idle pose mirrored:

```gdscript
	# Goalie returns to center, texture back to idle
	if goalie_gfx:
		goalie_gfx.texture = goalie_idle_texture
		goalie_gfx.flip_h = false
```

- [ ] **Step 7: Point the scene's Goalie/GFX at the new texture**

Through the editor, not by hand:
`scene_open("res://Scenes/Minigames/Olahraga/MainBola.tscn")` →
`node_set_property` on `Goalie/GFX` `texture` to
`res://Assets/Images/Textures/kiper_idle.png` → `scene_save`.

- [ ] **Step 8: Rescan, then run the suite**

`filesystem_manage(op="scan")`, then `test_run` on `main_bola_layout`.
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Assets/Images/Textures/kiper_*.png* Scripts/Minigames/Olahraga/MainBola.gd Scenes/Minigames/Olahraga/MainBola.tscn tests/test_main_bola_layout.gd
git commit -m "feat(minigame): two-state goalie with mirrored dive

Four opaque .jpg goalie textures collapse to two alpha PNGs. Dive
direction is now flip_h on the one jump sprite rather than a
left/right texture pair, and goalie_fail_texture goes with them --
it was declared and never read.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: Goalie idle breathing

**Files:**
- Modify: `Scripts/Minigames/Olahraga/MainBola.gd` (exports, `_process`, `_apply_layout`)
- Test: `tests/test_main_bola_layout.gd`

**Interfaces:**
- Consumes: `goalie_gfx` and `goalie_idle_texture` from Task 1.
- Produces: `_breathe_goalie(delta: float) -> void`, exports
  `breath_rate: float`, `breath_scale_amount: float`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_main_bola_layout.gd`:

```gdscript
func test_goalie_breathing_is_tunable_not_hardcoded() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for knob in ["breath_rate", "breath_scale_amount"]:
		assert_contains(src, "@export var %s" % knob,
			"breathing amplitude and rate must be Inspector knobs")


func test_goalie_breathing_pivots_at_the_feet() -> void:
	# A standing character scaled about its middle lifts off the goal
	# line. The pivot has to sit at bottom-centre, and it has to be
	# rewritten in _apply_layout because that function rewrites size.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "goalie_gfx.pivot_offset",
		"breathing needs an explicit pivot")
	assert_contains(src, "goalie_gfx.size.y)",
		"the pivot's y should be the full height, i.e. the feet")


func test_goalie_breathing_pauses_while_a_shot_resolves() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "func _breathe_goalie",
		"breathing should live in its own function, not inline in _process")
	assert_contains(src, "is_resolving",
		"breathing must yield to the dive animation")
```

- [ ] **Step 2: Run the suite and confirm the three new tests fail**

`test_run` on `main_bola_layout`. Expected: FAIL — `breath_rate` absent.

- [ ] **Step 3: Add the two exports**

In the `Visual - Art` group in `MainBola.gd`, after `center_block_uses_jump`:

```gdscript
## How fast the idle keeper breathes, in radians per second.
@export var breath_rate: float = 3.2
## How far the idle breath scales the keeper, as a fraction of his size.
## 0.03 is a 3% swell -- readable at a glance without reading as a bounce.
@export var breath_scale_amount: float = 0.03
```

- [ ] **Step 4: Set the pivot where the layout writes the size**

In `_apply_layout`, inside `if goalie_gfx:` at `MainBola.gd:329-332`,
after `goalie_gfx.position = ...`:

```gdscript
			# Breathe about the feet, not the middle: a standing figure
			# scaled about its centre lifts off the goal line. This has
			# to live here rather than in _ready because this function
			# rewrites goalie_gfx.size on every resize.
			goalie_gfx.pivot_offset = Vector2(goalie_gfx.size.x * 0.5, goalie_gfx.size.y)
```

- [ ] **Step 5: Add the breathing function and call it**

Add near the other goalie helpers:

```gdscript
## A slow swell on the idle keeper, so he does not read as a still image
## between shots. Suspended while a shot resolves -- the dive tween owns
## the sprite then -- and rewound to rest so a dive never starts from a
## mid-breath scale.
func _breathe_goalie(delta: float) -> void:
	if goalie_gfx == null:
		return
	if is_resolving or is_game_over or not is_game_active:
		goalie_gfx.scale = Vector2.ONE
		breath_time = 0.0
		return
	breath_time += delta * breath_rate
	var swell: float = sin(breath_time) * breath_scale_amount
	# Chest expands slightly more than it widens, as a real breath does.
	goalie_gfx.scale = Vector2(1.0 - swell * 0.5, 1.0 + swell)
```

Declare the accumulator beside the other goalie state (near `MainBola.gd:161`):

```gdscript
var breath_time: float = 0.0
```

Call it in `_process`, **before** the early-return guard at
`MainBola.gd:205-206`, so the reset branch still runs while resolving:

```gdscript
func _process(delta: float) -> void:
	super._process(delta)
	_breathe_goalie(delta)
	if not is_game_active or is_resolving or is_game_over:
		return
```

- [ ] **Step 6: Rescan and run the suite**

`filesystem_manage(op="scan")`, then `test_run` on `main_bola_layout`.
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Minigames/Olahraga/MainBola.gd tests/test_main_bola_layout.gd
git commit -m "feat(minigame): idle breathing on the goalkeeper

Sine swell on the goalie sprite between shots, pivoted at the feet so
he stays planted on the goal line, suspended and rewound while a dive
resolves. Rate and amplitude are Inspector knobs.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: `DancerRig` scene and script

**Files:**
- Create: `Assets/Images/Textures/dance_body_{idle,side,up}.png`, `dance_head.png`
- Create: `Scripts/Minigames/SeniBudaya/DancerRig.gd`
- Create: `Scenes/Minigames/SeniBudaya/DancerRig.tscn`
- Test: `tests/test_dancer_rig.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name DancerRig`, with
  `enum Pose { IDLE, SIDE, UP }`,
  `set_pose(pose: Pose, flipped: bool) -> void`,
  `set_failed(on: bool) -> void`,
  `head_offset_ratio: Vector2`.
  Task 4 calls exactly these.

- [ ] **Step 1: Copy the four sprites in and import them**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
for f in dance_body_idle dance_body_side dance_body_up dance_head; do
  cp "C:/Users/user/Downloads/$f.png" "Assets/Images/Textures/$f.png"
done
```

Then MCP `filesystem_manage(op="scan")`.

- [ ] **Step 2: Write the failing test suite**

Create `tests/test_dancer_rig.gd`:

```gdscript
@tool
extends McpTestSuite

## The dancer is two layers, not one sprite: a body that swaps pose and
## mirrors, and a head that does neither. The head's offset was solved
## against dance_mockup.png by minimising per-pixel difference, not
## eyeballed -- see the 2026-09-07 design doc.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "dancer_rig"


const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/DancerRig.gd"
const SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/DancerRig.tscn"

## The offset solved against the mockup, on the sprites' 1280 canvas.
const SOLVED_HEAD_OFFSET_PX := Vector2(2.0, 28.0)
const SPRITE_CANVAS := 1280.0


func test_script_is_tool_so_the_composite_previews_in_the_editor() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.begins_with("@tool"),
		"DancerRig must be @tool or the head sits unplaced in the viewport")


func test_scene_has_a_body_and_a_head_layer() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	assert_not_null(packed, "DancerRig.tscn should load")
	var rig := packed.instantiate()
	assert_not_null(rig.get_node_or_null("Body"), "rig needs a Body layer")
	assert_not_null(rig.get_node_or_null("Head"), "rig needs a Head layer")
	rig.free()


func test_head_offset_ratio_matches_the_solved_mockup_offset() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var rig := packed.instantiate() as DancerRig
	var expected := SOLVED_HEAD_OFFSET_PX / SPRITE_CANVAS
	assert_true(rig.head_offset_ratio.is_equal_approx(expected),
		"head_offset_ratio should be the solved (2,28)/1280, got %s" % rig.head_offset_ratio)
	rig.free()


func test_side_pose_mirrors_the_body_but_never_the_head() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var rig := packed.instantiate() as DancerRig
	rig.set_pose(DancerRig.Pose.SIDE, true)
	var body := rig.get_node("Body") as TextureRect
	var head := rig.get_node("Head") as TextureRect
	assert_true(body.flip_h, "a flipped pose must mirror the body")
	assert_false(head.flip_h, "the head must never mirror -- her face stays put")
	rig.free()


func test_unflipped_pose_leaves_the_body_unmirrored() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var rig := packed.instantiate() as DancerRig
	rig.set_pose(DancerRig.Pose.SIDE, true)
	rig.set_pose(DancerRig.Pose.SIDE, false)
	var body := rig.get_node("Body") as TextureRect
	assert_false(body.flip_h, "set_pose must clear a previous mirror, not latch it")
	rig.free()


func test_each_pose_selects_its_own_body_texture() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var rig := packed.instantiate() as DancerRig
	var body := rig.get_node("Body") as TextureRect
	rig.set_pose(DancerRig.Pose.IDLE, false)
	var idle_tex := body.texture
	rig.set_pose(DancerRig.Pose.SIDE, false)
	var side_tex := body.texture
	rig.set_pose(DancerRig.Pose.UP, false)
	var up_tex := body.texture
	assert_ne(idle_tex, side_tex, "IDLE and SIDE must not share art")
	assert_ne(side_tex, up_tex, "SIDE and UP must not share art")
	rig.free()


func test_failed_tints_the_rig_red_and_clears() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var rig := packed.instantiate() as DancerRig
	rig.set_failed(true)
	assert_ne(rig.modulate, Color.WHITE, "a miss should tint the rig")
	rig.set_failed(false)
	assert_eq(rig.modulate, Color.WHITE, "clearing a miss should restore the tint")
	rig.free()
```

- [ ] **Step 3: Run it and confirm it fails**

`test_run` on `dancer_rig`. Expected: FAIL — script and scene do not exist.

- [ ] **Step 4: Write `DancerRig.gd`**

Create `Scripts/Minigames/SeniBudaya/DancerRig.gd`:

```gdscript
@tool
extends Control
class_name DancerRig

## The dance minigame's character, as two layers rather than one sprite.
##
## The body swaps between three poses and mirrors for the left-hand
## arrows; the head is a single texture that never swaps and never
## mirrors, so her face and hairclip stay fixed while the body dances.
##
## Both layers draw the same 1280x1280 source canvas into the same rect
## with STRETCH_KEEP_ASPECT_CENTERED, so they align at zero offset. The
## head then shifts by head_offset_ratio, which was solved by
## compositing dance_head over dance_body_idle and minimising per-pixel
## difference against dance_mockup.png -- not eyeballed. All three body
## poses put the neck within a few pixels of the same spot, so one
## offset serves every pose.
##
## @tool, so the composite previews in the editor viewport. Nothing in
## _ready() has a side effect outside this rig's own children.

## The body's three poses. SIDE covers both side arrows and UP covers
## both diagonal-up arrows; direction comes from the `flipped` argument.
enum Pose { IDLE, SIDE, UP }

@export_group("Art")
## Body at rest, between notes.
@export var body_idle_texture: Texture2D = preload("res://Assets/Images/Textures/dance_body_idle.png")
## Body with one arm thrown out sideways. Used for LEFT and RIGHT.
@export var body_side_texture: Texture2D = preload("res://Assets/Images/Textures/dance_body_side.png")
## Body with arms crossed upward. Used for TOP_LEFT and TOP_RIGHT.
@export var body_up_texture: Texture2D = preload("res://Assets/Images/Textures/dance_body_up.png")
## The head layer. One texture for every pose, and it never mirrors.
@export var head_texture: Texture2D = preload("res://Assets/Images/Textures/dance_head.png")

@export_group("Layout")
## Where the head sits relative to the body, as a fraction of the drawn
## square. Solved against dance_mockup.png as (+2, +28) px on the
## sprites' own 1280 canvas. Change this only against a new mockup.
@export var head_offset_ratio: Vector2 = Vector2(2.0 / 1280.0, 28.0 / 1280.0):
	set(value):
		head_offset_ratio = value
		_place_head()

@export_group("State")
## Tint applied by set_failed(). Red enough to read as a miss over the
## stage background without hiding the pose underneath it.
@export var fail_tint: Color = Color(1.0, 0.45, 0.45, 1.0)

@onready var body: TextureRect = $Body
@onready var head: TextureRect = $Head


func _ready() -> void:
	_place_head()
	set_pose(Pose.IDLE, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_head()


## Shows one pose, optionally mirrored. `flipped` mirrors the BODY only:
## the head is deliberately excluded so her face does not swap sides
## every time a left-hand arrow comes up.
func set_pose(pose: Pose, flipped: bool) -> void:
	if body == null:
		body = get_node_or_null("Body") as TextureRect
	if body == null:
		return
	match pose:
		Pose.SIDE:
			body.texture = body_side_texture
		Pose.UP:
			body.texture = body_up_texture
		_:
			body.texture = body_idle_texture
	body.flip_h = flipped


## Tints the whole rig for a missed note, or clears the tint. The shake
## and droop motion stays with the caller -- this only says "missed".
func set_failed(on: bool) -> void:
	modulate = fail_tint if on else Color.WHITE


## Offsets the head against the drawn square. With
## STRETCH_KEEP_ASPECT_CENTERED and a square source, the drawn image is
## min(width, height) on both axes regardless of the rect's own aspect,
## so that is what the ratio scales against -- not the rect.
func _place_head() -> void:
	if head == null:
		head = get_node_or_null("Head") as TextureRect
	if head == null:
		return
	var drawn_square: float = minf(size.x, size.y)
	head.position = head_offset_ratio * drawn_square
```

- [ ] **Step 5: Build `DancerRig.tscn` through the editor**

`scene_manage(op="create")` a `Control` root named `DancerRig`, attach
the script, then `node_create` two `TextureRect` children named `Body`
and `Head` **in that order** so the head draws on top (`node_create`
appends last, which is what we want here).

On both children set: the four anchors to `0,0,1,1`, `expand_mode = 1`,
`stretch_mode = 5` (`STRETCH_KEEP_ASPECT_CENTERED`), `mouse_filter = 2`.
Set `Body.texture` to `dance_body_idle.png` and `Head.texture` to
`dance_head.png`. `scene_save`.

- [ ] **Step 6: Rescan and run the suite**

`filesystem_manage(op="scan")`, then `test_run` on `dancer_rig`.
Expected: PASS, 8 tests.

- [ ] **Step 7: Commit**

```bash
git add Assets/Images/Textures/dance_*.png* Scripts/Minigames/SeniBudaya/DancerRig.gd Scenes/Minigames/SeniBudaya/DancerRig.tscn tests/test_dancer_rig.gd
git commit -m "feat(minigame): layered head and body rig for the dancer

Body swaps between three poses and mirrors for the left-hand arrows;
the head is one texture that never swaps and never mirrors. Head
offset solved against dance_mockup.png rather than eyeballed, and
stored as a ratio so it survives any rect size.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Wire the rig into `LombaMenari`

**Files:**
- Modify: `Scripts/Minigames/SeniBudaya/LombaMenari.gd:69-79`, `:152`, `:210-229`, `:247-252`, `:675-780`
- Modify: `Scenes/Minigames/SeniBudaya/LombaMenari.tscn` (CharacterDisplay node type)
- Modify: `tests/test_viewport_editability.gd` (`BASELINE`)

**Interfaces:**
- Consumes: `DancerRig.set_pose(pose, flipped)`, `DancerRig.set_failed(on)`,
  `DancerRig.Pose` from Task 3.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_dancer_rig.gd`:

```gdscript
const MENARI_SCRIPT := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"


func test_menari_drives_the_rig_instead_of_swapping_textures() -> void:
	var src := FileAccess.get_file_as_string(MENARI_SCRIPT)
	assert_contains(src, "character_display.set_pose",
		"LombaMenari should drive the rig, not assign textures directly")
	assert_false(src.contains("character_display.texture ="),
		"direct texture assignment should be gone with the rig")


func test_menari_retired_the_six_flat_dancer_textures() -> void:
	var src := FileAccess.get_file_as_string(MENARI_SCRIPT)
	for retired in ["dancer_idle_texture", "dancer_left_texture",
			"dancer_right_texture", "dancer_top_left_texture",
			"dancer_top_right_texture", "dancer_fail_texture"]:
		assert_false(src.contains(retired),
			"%s should have been replaced by the rig's own exports" % retired)


func test_menari_no_longer_builds_a_fallback_label_or_texture() -> void:
	# Both were runtime visual construction, and the label carried emoji
	# as iconography. The rig always has real art, so neither is needed.
	var src := FileAccess.get_file_as_string(MENARI_SCRIPT)
	assert_false(src.contains("_create_flat_texture"),
		"the procedural fallback texture should be gone")
	assert_false(src.contains("dancer_label"),
		"the emoji fallback label should be gone")
```

- [ ] **Step 2: Run it and confirm the three new tests fail**

`test_run` on `dancer_rig`. Expected: FAIL — `character_display.texture =` still present.

- [ ] **Step 3: Swap the node type in the scene**

A node's type cannot be changed in place. Through the editor:
`scene_open("res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn")` →
`node_manage(op="delete")` on `CharacterDisplay` → `node_create` a
`DancerRig.tscn` instance named `CharacterDisplay` → restore its four
anchors (`0.167, 0.2, 0.826, 0.65`) and offsets
(`left 7.639984, top 11.0, right 10.919983`) → `move_node` it back
above `NotesParent` → clear the six `dancer_*_texture` properties on the
`LombaMenari` root → `scene_save`.

- [ ] **Step 4: Delete the six texture exports**

Remove `LombaMenari.gd:69-79` (the `dancer_idle_texture` through
`dancer_fail_texture` block) entirely. The art now lives on the rig.

- [ ] **Step 5: Retype the display reference**

At `LombaMenari.gd:152`:

```gdscript
@onready var character_display: DancerRig = $CharacterDisplay
```

- [ ] **Step 6: Delete the fallback label and procedural texture**

In `_ready` (around `:210-229`), delete the `dancer_label` construction
block entirely — the `Label.new()` through
`character_display.add_child(dancer_label)` lines — keeping the
`character_display.pivot_offset` line and the `_set_dancer_idle()` call.
Delete the `var dancer_label: Label` declaration at `:154`, the
`_create_flat_texture` function, and every remaining reference to both.

- [ ] **Step 7: Rewrite the three pose functions**

Replace `_set_dancer_idle` (`:675`):

```gdscript
func _set_dancer_idle() -> void:
	is_dancer_failed = false
	dancer_base_rotation = 0.0
	dancer_base_scale = Vector2.ONE
	if not character_display:
		return
	character_display.set_pose(DancerRig.Pose.IDLE, false)
	character_display.set_failed(false)
```

In `_play_dancer_motion` (`:694`), replace the `target_tex` selection
and assignment with a pose-and-mirror call. The mapping is:

```gdscript
	# One body pose per axis, mirrored for the left-hand arrows. RIGHT
	# and TOP_RIGHT are the drawn direction; LEFT and TOP_LEFT are the
	# same art flipped. The head never flips -- see DancerRig.
	var pose: DancerRig.Pose = DancerRig.Pose.IDLE
	var flipped: bool = false
	match swipe_type:
		SWIPE_RIGHT:
			pose = DancerRig.Pose.SIDE
		SWIPE_LEFT:
			pose = DancerRig.Pose.SIDE
			flipped = true
		SWIPE_TOP_RIGHT:
			pose = DancerRig.Pose.UP
		SWIPE_TOP_LEFT:
			pose = DancerRig.Pose.UP
			flipped = true
	character_display.set_pose(pose, flipped)
	character_display.set_failed(false)
```

Use whatever the file's actual swipe-type constant names are — read
`LombaMenari.gd:428` and the `_play_dancer_motion` match block first and
match them exactly rather than assuming `SWIPE_*`.

In `_play_dancer_fail_motion` (`:766-780`), replace the texture/label
branch with:

```gdscript
	# No fail pose was drawn for this character. A miss is the idle pose
	# tinted red, plus the shake-and-droop below.
	character_display.set_pose(DancerRig.Pose.IDLE, false)
	character_display.set_failed(true)
```

and delete the `character_display.modulate = Color.WHITE` line that
followed it — `set_failed` owns the tint now.

- [ ] **Step 8: Lower the editability ratchet**

In `tests/test_viewport_editability.gd`, lower the `LombaMenari.gd`
`BASELINE` entry from `5`. Run the suite first to learn the true new
number, then set it to exactly that. **Lower only — never raise.**

- [ ] **Step 9: Rescan and run the full suite**

`filesystem_manage(op="scan")`, then a full `test_run`.
Expected: PASS across all suites.

- [ ] **Step 10: Commit**

```bash
git add Scripts/Minigames/SeniBudaya/LombaMenari.gd Scenes/Minigames/SeniBudaya/LombaMenari.tscn tests/test_dancer_rig.gd tests/test_viewport_editability.gd
git commit -m "feat(minigame): drive the dancer through the layered rig

Six flat textures become three body poses plus a fixed head. Drops the
procedural fallback texture and the emoji fallback label with it,
lowering the viewport-editability baseline for this file.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: `EventStudentCard` scene

**Files:**
- Create: `Assets/Images/UI/Placeholders/icon_{benefit,cost,tired,specialty,check}.svg`
- Create: `Scripts/SchoolSimulation/EventStudentCard.gd`
- Create: `Scenes/SchoolSimulation/EventStudentCard.tscn`
- Modify: `Scripts/Design/ThemeFactory.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryAvatar.tscn`, `DaySummaryStatRow.tscn`,
  `DaySummaryNeedsBar.gd`, and
  `DaySummaryStatRow.set_stat(stat_key: String, delta: float, target: float, current: float)`.
- Produces: `class_name EventStudentCard` with
  `setup(student: StudentData, category: String) -> void`,
  `set_preview(stat_delta: float, energy_delta: float, mood_delta: float) -> void`,
  `is_selected() -> bool`, `set_selectable(on: bool) -> void`,
  and signal `selection_changed(selected: bool)`.
  Task 6 calls exactly these.

- [ ] **Step 1: Author the five SVG icons**

White-on-transparent, 64×64 viewBox, **glyphs as stroked `<path>`
elements — never `<text>`**. Godot rasterises SVG through ThorVG, which
drops text elements silently; `tests/test_end_cutscene.gd` guards the
same trap for the cutscene stamps.

Match the flat style of the existing
`Assets/Images/UI/Placeholders/icon_*.svg` files — read one first.

- `icon_benefit.svg` — an upward chevron
- `icon_cost.svg` — a downward chevron
- `icon_tired.svg` — closed eye / droop
- `icon_specialty.svg` — a star
- `icon_check.svg` — a tick, for the selected badge

- [ ] **Step 2: Add the `EventSelectCard` theme variation**

In `Scripts/Design/ThemeFactory.gd`, beside the other button variations
(near line 35), add:

```gdscript
	_add_button_variation(theme, tokens, "EventSelectCard",
		tokens.surface_card, tokens.surface_card,
		tokens.surface_sunken, tokens.text_primary)
```

Use the token names that actually exist on `DesignTokens` — read
`Scripts/Design/DesignTokens.gd` and the neighbouring
`_add_button_variation` calls first, and match them.

Then rebake. `Scripts/Design/BakeTheme.gd` is an `EditorScript` with no
MCP entry point, so with the editor attached use the transient-suite
route: write a throwaway `@tool` `McpTestSuite` into `res://tests/`
whose single test does `ThemeFactory.build()` + `ResourceSaver.save()`
to `res://Assets/Theme/kejartes_theme.tres`, run it with `test_run`,
then delete it.

- [ ] **Step 3: Write the failing tests**

Append to `tests/test_day_summary.gd`:

```gdscript
const EVENT_CARD_SCENE := "res://Scenes/SchoolSimulation/EventStudentCard.tscn"


func test_event_card_reuses_the_day_summary_parts() -> void:
	var packed := load(EVENT_CARD_SCENE) as PackedScene
	assert_not_null(packed, "EventStudentCard.tscn should load")
	var card := packed.instantiate()
	assert_not_null(card.get_node_or_null("Avatar"),
		"the event card should reuse DaySummaryAvatar")
	assert_not_null(card.get_node_or_null("EnergyBar"),
		"the event card should reuse the DaySummary needs bars")
	assert_not_null(card.get_node_or_null("MoodBar"), "ditto mood")
	for i in range(1, 4):
		assert_not_null(card.get_node_or_null("StatRow%d" % i),
			"the event card should carry all three DaySummaryStatRows")
	card.free()


func test_event_card_is_a_toggle_not_a_scaled_checkbox() -> void:
	var packed := load(EVENT_CARD_SCENE) as PackedScene
	var card := packed.instantiate()
	assert_true(card is Button, "the whole card should be the tap target")
	assert_true(card.toggle_mode, "the card should latch when selected")
	assert_eq(card.theme_type_variation, &"EventSelectCard",
		"selection state should come from the theme, not a bespoke stylebox")
	card.free()


func test_event_card_reports_its_selection() -> void:
	var packed := load(EVENT_CARD_SCENE) as PackedScene
	var card := packed.instantiate() as EventStudentCard
	assert_false(card.is_selected(), "a fresh card starts unselected")
	card.button_pressed = true
	assert_true(card.is_selected(), "pressing the card selects it")
	card.free()


func test_event_card_refuses_selection_when_not_selectable() -> void:
	# A tired student cannot be sent, and the card has to say so.
	var packed := load(EVENT_CARD_SCENE) as PackedScene
	var card := packed.instantiate() as EventStudentCard
	card.set_selectable(false)
	assert_true(card.disabled, "an unselectable card must not accept a tap")
	card.free()
```

- [ ] **Step 4: Run and confirm failure**

`test_run` on `day_summary`. Expected: FAIL — scene does not exist.

- [ ] **Step 5: Write `EventStudentCard.gd`**

Create `Scripts/SchoolSimulation/EventStudentCard.gd`:

```gdscript
@tool
extends Button
class_name EventStudentCard

## One selectable student on the event dialog, wearing DaySummary's
## chrome.
##
## The whole card is the toggle. That deletes the 2.4x-scaled Godot
## CheckBox this screen used to carry -- which matched nothing else in
## the game -- and turns a 992x410 card into the tap target, which
## matters on a 1080-wide portrait phone. The selected look comes from
## the EventSelectCard theme variation's pressed stylebox rather than a
## bespoke StyleBoxFlat.
##
## Every part here is a DaySummary component reused as-is: the avatar,
## the two needs bars, the three stat rows. The one thing this adds over
## a DaySummary row is set_preview(), which shows what accepting the
## event would do.

## Fired when the player toggles this card. `selected` is the new state.
signal selection_changed(selected: bool)

## Stat keys in the order the three rows are laid out, matching
## DaySummaryStudentRow so both cards read the same way.
const STAT_ORDER: Array[String] = ["akademis", "seni_budaya", "olahraga"]

## Which stat key each schedule category previews against.
const STAT_KEY_FOR_CATEGORY := {
	"Akademis": "akademis",
	"SeniBudaya": "seni_budaya",
	"Olahraga": "olahraga",
}

@export_group("State")
## Badge shown in the card's corner while it is selected.
@export var selected_badge_texture: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_check.svg")

@onready var avatar: Control = $Avatar
@onready var name_label: Label = $NameLabel
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var mood_bar: ProgressBar = $MoodBar
@onready var select_badge: TextureRect = $SelectBadge

var _student: StudentData = null
var _category: String = "Akademis"


func _ready() -> void:
	toggled.connect(_on_toggled)
	if select_badge:
		select_badge.visible = false


## Writes the student's CURRENT stats onto the card, with no preview.
## Call set_preview() afterwards to layer a proposed change over it.
func setup(student: StudentData, category: String) -> void:
	_student = student
	_category = category
	if student == null:
		return
	name_label.text = student.student_name
	avatar.set_student(student)
	energy_bar.set_need("energy", student.energy)
	mood_bar.set_need("mood", student.mood)
	set_selectable(not student.is_tired())
	_write_stat_rows(0.0)


## Layers a proposed change over the current values: the event's own
## stat row travels to what it would become, and both needs bars follow.
## Pass zeroes to rewind to the plain current-value view.
func set_preview(stat_delta: float, energy_delta: float, mood_delta: float) -> void:
	if _student == null:
		return
	_write_stat_rows(stat_delta)
	energy_bar.set_need("energy", clampf(_student.energy + energy_delta, 0.0, 100.0))
	mood_bar.set_need("mood", clampf(_student.mood + mood_delta, 0.0, 100.0))


## True when the player has this student marked to take part.
func is_selected() -> bool:
	return button_pressed


## A tired student cannot be sent; the card refuses the tap and dims.
func set_selectable(on: bool) -> void:
	disabled = not on
	if not on:
		button_pressed = false


func _write_stat_rows(event_stat_delta: float) -> void:
	var preview_key: String = STAT_KEY_FOR_CATEGORY.get(_category, "akademis")
	var values := {
		"akademis": _student.akademis,
		"seni_budaya": _student.seni_budaya,
		"olahraga": _student.olahraga,
	}
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		var row := get_node("StatRow%d" % (i + 1))
		var current: float = values[key]
		# Only the event's own category previews a change. The other two
		# show where the student stands today, which is the whole point
		# of matching DaySummary here.
		var delta: float = event_stat_delta if key == preview_key else 0.0
		row.set_stat(key, delta, 100.0, current)


func _on_toggled(pressed: bool) -> void:
	if select_badge:
		select_badge.visible = pressed
	selection_changed.emit(pressed)
```

Before writing this, read `Scripts/SchoolSimulation/DaySummaryStudentRow.gd:136`
(`_write_stat_rows`) and confirm the `target` argument `set_stat` expects
— `TARGET_FOR` there may supply a per-stat target rather than a flat
100.0. Match whatever it does.

- [ ] **Step 6: Build `EventStudentCard.tscn` through the editor**

Copy the geometry from `DaySummaryStudentRow.tscn` — same
`custom_minimum_size = Vector2(992, 410)`, same child offsets — but with
a `Button` root carrying `toggle_mode = true` and
`theme_type_variation = &"EventSelectCard"`, and one extra `SelectBadge`
TextureRect in the top-right corner.

Children, in draw order: `CardArt`, `Avatar` (DaySummaryAvatar instance),
`NameLabel`, `EnergyBar`, `MoodBar`, `StatRow1..3` (DaySummaryStatRow
instances), `SelectBadge`. `scene_save`.

- [ ] **Step 7: Rescan and run**

`filesystem_manage(op="scan")`, then `test_run` on `day_summary`.
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Assets/Images/UI/Placeholders/icon_*.svg* Scripts/SchoolSimulation/EventStudentCard.gd Scenes/SchoolSimulation/EventStudentCard.tscn Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_day_summary.gd
git commit -m "feat(schoolday): DaySummary-styled selectable student card

The event dialog's per-student card as a PackedScene built from the
DaySummary components, with the whole card as the toggle instead of a
2.4x-scaled CheckBox. Adds the EventSelectCard theme variation and the
five SVG icons that replace emoji on this screen.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Rewire `EventStudentSelectDialog` onto the card

**Files:**
- Modify: `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` (most of it)
- Modify: `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn`
- Modify: `tests/test_viewport_editability.gd` (`BASELINE`)

**Interfaces:**
- Consumes: `EventStudentCard.setup`, `.set_preview`, `.is_selected`,
  `.set_selectable`, `.selection_changed` from Task 5.
- Produces: nothing later tasks depend on. The
  `event_decision_made(accepted: bool, selected_students: Array[StudentData])`
  signal is unchanged, so `SchoolDay.gd:1034` needs no edit.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_day_summary.gd`:

```gdscript
const EVENT_DIALOG_SCRIPT := "res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd"


func test_event_dialog_instantiates_cards_instead_of_building_them() -> void:
	var src := FileAccess.get_file_as_string(EVENT_DIALOG_SCRIPT)
	assert_contains(src, "EventStudentCard.tscn",
		"cards should come from a PackedScene, not from HBoxContainer.new()")
	for built in ["HBoxContainer.new()", "VBoxContainer.new()",
			"CheckBox.new()", "StatBar.new()"]:
		assert_false(src.contains(built),
			"%s is runtime visual construction and should be gone" % built)


func test_event_dialog_carries_no_emoji_iconography() -> void:
	var src := FileAccess.get_file_as_string(EVENT_DIALOG_SCRIPT)
	for glyph in ["📢", "📈", "📉", "😴", "🌟", "📚", "⚽", "🎨", "⚡", "😊"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography; %s should be an SVG" % glyph)


func test_event_dialog_dropped_the_button_texture_override_path() -> void:
	# StyleBoxTexture overrides are what let these three buttons drift
	# out of the theme every other screen uses.
	var src := FileAccess.get_file_as_string(EVENT_DIALOG_SCRIPT)
	assert_false(src.contains("StyleBoxTexture"),
		"buttons should take their look from the theme, not a texture override")
	for retired in ["button_select_all_texture", "button_cancel_texture",
			"button_confirm_texture"]:
		assert_false(src.contains(retired),
			"%s should have been removed with the override path" % retired)
```

- [ ] **Step 2: Run and confirm failure**

`test_run` on `day_summary`. Expected: FAIL.

- [ ] **Step 3: Replace card construction with instantiation**

Delete `_create_card`, `_add_stat_bar_row`, `_make_badge`,
`_apply_bar_preview` and `_set_mouse_filter_pass` from
`EventStudentSelectDialog.gd`. Replace `_populate_student_cards` with:

```gdscript
const CARD_SCENE := preload("res://Scenes/SchoolSimulation/EventStudentCard.tscn")


func _populate_student_cards() -> void:
	if students_container == null:
		return
	for child in students_container.get_children():
		child.queue_free()
	card_widgets.clear()

	var cards: Array = []
	for student in student_list:
		var card: EventStudentCard = CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		students_container.add_child(card)
		card.setup(student, event_data.get("category", "Akademis"))
		card.selection_changed.connect(
			func(_on): _update_card_preview(student.student_name))
		card_widgets[student.student_name] = card
		cards.append(card)

	Juice.stagger_in(cards)
	_update_confirm_button()
```

`card_widgets` now maps name → `EventStudentCard` rather than name →
Dictionary-of-widgets. Every read of it changes shape accordingly.

- [ ] **Step 4: Rewrite the preview to drive the card**

```gdscript
func _update_card_preview(student_name: String) -> void:
	var card := card_widgets.get(student_name) as EventStudentCard
	if card == null:
		return
	var category: String = event_data.get("category", "Akademis")
	var checked: bool = card.is_selected()
	if not checked:
		card.set_preview(0.0, 0.0, 0.0)
		_update_confirm_button()
		return

	var student: StudentData = card._student
	var energy_cost: float = float(event_data.get("energy_cost", -15.0))
	# Specialty students spend less energy on their own category, and
	# the preview has to show the discounted figure or it lies.
	if energy_cost < 0.0:
		energy_cost = roundf(energy_cost * student.get_category_efficiency_multiplier(category))
	card.set_preview(
		float(event_data.get("stat_boost", 15.0)),
		energy_cost,
		float(event_data.get("mood_boost", 0.0)))
	_update_confirm_button()
```

Reading `card._student` reaches into the card's internals. Add a
`func student() -> StudentData: return _student` accessor to
`EventStudentCard.gd` in Task 5's file and call that instead.

- [ ] **Step 5: Update the three selection loops**

`_on_select_all_pressed`, `_on_confirm_pressed` and
`_update_confirm_button` all currently dig a `checkbox` out of a
Dictionary. Each becomes a direct card call — for example:

```gdscript
func _update_confirm_button() -> void:
	var count := 0
	for student_name in card_widgets:
		var card := card_widgets[student_name] as EventStudentCard
		if card and card.is_selected():
			count += 1
	if confirm_button:
		confirm_button.text = confirm_format_text % count
		confirm_button.disabled = (count == 0)
```

- [ ] **Step 6: Strip the button override path and the emoji**

Delete `button_select_all_texture`, `button_cancel_texture`,
`button_confirm_texture` and the whole `for btn in btns:` block in
`_apply_visual_exports` that builds `StyleBoxTexture`s. Keep the font
override loop.

In `setup_event`, replace the emoji cost/benefit line:

```gdscript
	if cost_benefit_label:
		cost_benefit_label.text = "Manfaat: %s\nBiaya: %s" % [benefit_info, cost_info]
```

In the scene, set `TitleLabel.text` to `"JUDUL EVENT"` (no 📢) and give
`CostBenefitLabel` two sibling `TextureRect`s using `icon_benefit.svg`
and `icon_cost.svg`. Also set all three action buttons'
`custom_minimum_size` to `Vector2(0, 96)` — `ConfirmButton` and the two
in `SecondaryHBox` already have it; confirm rather than assume.

- [ ] **Step 7: Lower the editability ratchet**

Lower `EventStudentSelectDialog.gd`'s `BASELINE` entry from `11`. Run
the suite first to learn the true new number, then set exactly that.

- [ ] **Step 8: Rescan and run the full suite**

`filesystem_manage(op="scan")`, then a full `test_run`.
Expected: PASS across all suites.

- [ ] **Step 9: Commit**

```bash
git add Scripts/SchoolSimulation/EventStudentSelectDialog.gd Scenes/SchoolSimulation/EventStudentSelectDialog.tscn tests/test_day_summary.gd tests/test_viewport_editability.gd
git commit -m "refactor(schoolday): rebuild the event dialog on DaySummary chrome

Per-student cards come from a PackedScene instead of being assembled
from raw containers at runtime, the scaled CheckBox becomes a toggle
card, eleven emoji become SVG icons, and the StyleBoxTexture override
path that let the action buttons drift out of theme is gone. The
on-check stat preview is unchanged.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: `BookClockWidget` three poses, event at midday

**Files:**
- Modify: `Scripts/SchoolSimulation/BookClockWidget.gd:39-58`, plus new API
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:355`, `:370-371`, `:390-391`
- Test: `tests/test_book_clock_phases.gd` (new)

**Interfaces:**
- Consumes: nothing.
- Produces: `BookClockWidget.Phase` enum (`DAWN`, `MIDDAY`, `EVENING`),
  `set_phase(phase: Phase) -> void`,
  `transition_to(phase: Phase, duration: float) -> Tween`.
  `set_progress(value: float)`, `set_day`, `reset`, `day_name` are unchanged.

- [ ] **Step 1: Write the failing test suite**

Create `tests/test_book_clock_phases.gd`:

```gdscript
@tool
extends McpTestSuite

## The school day used to be one continuous sky sweep with the event
## landing at a random 50-80% of it. It is now three named poses and two
## transitions, with the event pinned to midday.
##
## Must be @tool; no test here may be a coroutine -- which is why
## transition_to is tested by inspecting the Tween it returns rather
## than by awaiting it.

func suite_name() -> String:
	return "book_clock_phases"


const SCRIPT_PATH := "res://Scripts/SchoolSimulation/BookClockWidget.gd"
const SCENE_PATH := "res://Scenes/SchoolSimulation/BookClockWidget.tscn"
const SCHOOLDAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"


func test_three_poses_are_exports_not_magic_numbers() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for knob in ["dawn_rotation_degrees", "midday_rotation_degrees",
			"evening_rotation_degrees"]:
		assert_contains(src, "@export var %s" % knob,
			"each pose must be tunable in the Inspector")


func test_retired_the_single_sweep_exports() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in ["start_rotation_degrees", "total_rotation_degrees"]:
		assert_false(src.contains(retired),
			"%s is superseded by the three pose exports" % retired)


func test_set_phase_snaps_the_sky_to_each_pose() -> void:
	var widget := (load(SCENE_PATH) as PackedScene).instantiate() as BookClockWidget
	var sky := widget.get_node("SkyBackground") as Control
	widget.set_phase(BookClockWidget.Phase.DAWN)
	assert_true(is_equal_approx(sky.rotation_degrees, widget.dawn_rotation_degrees),
		"DAWN should place the sky at its dawn angle")
	widget.set_phase(BookClockWidget.Phase.MIDDAY)
	assert_true(is_equal_approx(sky.rotation_degrees, widget.midday_rotation_degrees),
		"MIDDAY should place the sky at its midday angle")
	widget.set_phase(BookClockWidget.Phase.EVENING)
	assert_true(is_equal_approx(sky.rotation_degrees, widget.evening_rotation_degrees),
		"EVENING should place the sky at its evening angle")
	widget.free()


func test_transition_to_returns_its_tween_so_schoolday_can_await_it() -> void:
	var widget := (load(SCENE_PATH) as PackedScene).instantiate() as BookClockWidget
	var tween := widget.transition_to(BookClockWidget.Phase.MIDDAY, 1.0)
	assert_not_null(tween, "transition_to must hand its Tween back to the caller")
	assert_true(tween is Tween, "and it must actually be a Tween")
	widget.free()


func test_set_progress_still_maps_through_the_midday_pose() -> void:
	# Old callers and the day progress bar keep working; the middle of
	# the day now lands exactly on the midday pose rather than halfway
	# along one long sweep.
	var widget := (load(SCENE_PATH) as PackedScene).instantiate() as BookClockWidget
	var sky := widget.get_node("SkyBackground") as Control
	widget.set_progress(0.5)
	assert_true(is_equal_approx(sky.rotation_degrees, widget.midday_rotation_degrees),
		"progress 0.5 should sit on the midday pose")
	widget.free()


func test_event_fires_at_midday_not_at_a_random_afternoon_point() -> void:
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_contains(src, "EVENT_TRIGGER_PCT",
		"the event trigger point must be a named const")
	assert_false(src.contains("randf_range(0.5, 0.8)"),
		"the event should no longer land at a random point in the day")
```

- [ ] **Step 2: Run and confirm failure**

`test_run` on `book_clock_phases`. Expected: FAIL — exports absent.

- [ ] **Step 3: Replace the two sweep exports with three poses**

In `BookClockWidget.gd`, replace the `start_rotation_degrees` and
`total_rotation_degrees` exports (`:39-52`) with:

```gdscript
## The three poses the school day rests at. The defaults reproduce the
## old single -180 sweep exactly -- midday is simply the halfway angle,
## named -- so nothing moves on screen until the timing changes.
##
## Godot's rotation is clockwise-positive with y down, so the
## counter-clockwise sweep the mechanism reference asks for runs
## toward NEGATIVE angles.

## The sky's angle at the start of the school day.
@export var dawn_rotation_degrees: float = 0.0:
	set(value):
		dawn_rotation_degrees = value
		_apply_rotation()
## The sky's angle when the day's event rolls.
@export var midday_rotation_degrees: float = -90.0:
	set(value):
		midday_rotation_degrees = value
		_apply_rotation()
## The sky's angle when the school day ends.
@export var evening_rotation_degrees: float = -180.0:
	set(value):
		evening_rotation_degrees = value
		_apply_rotation()
```

- [ ] **Step 4: Add the phase enum and API**

```gdscript
## The day's three resting poses. The event rolls at MIDDAY.
enum Phase { DAWN, MIDDAY, EVENING }


## The angle one phase rests at.
func angle_for_phase(phase: Phase) -> float:
	match phase:
		Phase.MIDDAY:
			return midday_rotation_degrees
		Phase.EVENING:
			return evening_rotation_degrees
		_:
			return dawn_rotation_degrees


## Snaps the sky to one pose with no animation.
func set_phase(phase: Phase) -> void:
	_progress = _progress_for_phase(phase)
	_apply_rotation()


## Sweeps the sky to one pose and hands the Tween back, so the caller
## can await it and line the rest of the screen up with the sweep.
## Easing lives here rather than at the call site so motion-lab has one
## place to patch.
func transition_to(phase: Phase, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_method(set_progress, _progress, _progress_for_phase(phase), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween


func _progress_for_phase(phase: Phase) -> float:
	match phase:
		Phase.MIDDAY:
			return 0.5
		Phase.EVENING:
			return 1.0
		_:
			return 0.0
```

- [ ] **Step 5: Remap `_apply_rotation` piecewise through midday**

Find `_apply_rotation` and replace its angle computation so the first
half of the day interpolates dawn→midday and the second half
midday→evening:

```gdscript
	var eased: float = _progress
	if ease_in_out:
		eased = smoothstep(0.0, 1.0, _progress)
	# Piecewise, so progress 0.5 lands exactly on the midday pose
	# regardless of where the three angles are set.
	var angle: float
	if eased <= 0.5:
		angle = lerpf(dawn_rotation_degrees, midday_rotation_degrees, eased * 2.0)
	else:
		angle = lerpf(midday_rotation_degrees, evening_rotation_degrees, (eased - 0.5) * 2.0)
	sky.rotation_degrees = angle
```

Read the existing `_apply_rotation` body first and keep its null guards
and its node lookup (`SKY_NODE`) exactly as they are.

- [ ] **Step 6: Pin the event to midday in `SchoolDay.gd`**

Add to the const block near the top of the file:

```gdscript
## The day's event rolls at midday -- the BookClock's middle pose --
## rather than at a random point in the afternoon.
const EVENT_TRIGGER_PCT := 50.0
```

At `:355`, replace `var trigger_pct = randf_range(0.5, 0.8) * 100.0`
with `var trigger_pct := EVENT_TRIGGER_PCT`.

At `:370-371` and `:390-391` the two `tween_method` calls that drive
`set_progress` stay as they are — they already sweep 0→50 and 50→100,
which now lands on the two named poses. Leave the progress bar and the
decay-bar pacing untouched.

- [ ] **Step 7: Rescan and run the full suite**

`filesystem_manage(op="scan")`, then a full `test_run`.
Expected: PASS across all suites.

- [ ] **Step 8: Commit**

```bash
git add Scripts/SchoolSimulation/BookClockWidget.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_book_clock_phases.gd
git commit -m "feat(schoolday): three-pose day cycle with the event at midday

The sky's single continuous sweep becomes three named poses and two
transitions, and the day's event stops landing at a random 50-80% of
the afternoon and lands on the midday pose. transition_to returns its
Tween so the easing has one place to be tuned.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 9: Tune the transition in motion-lab**

Invoke the `motion-lab` skill against
`BookClockWidget.transition_to`. Hand the resulting preset token back to
the user to confirm, then patch it into `transition_to` and commit
separately. **Do not guess a curve — this step is the user's call.**

---

## Task 8: Shop hub and cosmetic stub

**Files:**
- Create: `Assets/Images/Shop/UI/icon_shop_items.svg`, `icon_shop_cosmetics.svg`
- Create: `Scenes/Koperasi/ShopHubTile.tscn`, `ShopHub.tscn`, `CosmeticShop.tscn`
- Create: `Scripts/Koperasi/shop_hub.gd`, `cosmetic_shop.gd`
- Modify: `Scripts/Lobby/loby.gd:788`, `Scripts/Koperasi/koprasi.gd:102`
- Modify: `Scripts/Design/ThemeFactory.gd`, `Scripts/Debug/DebugManager.gd`
- Test: `tests/test_shop_hub.gd` (new)

**Interfaces:**
- Consumes: `Transition.change_scene(path: String, style)`,
  `Scripts/Shaders/blur.gdshader` (uniforms `lod`, `darkness`).
- Produces: `res://Scenes/Koperasi/ShopHub.tscn` as the Lobby's new shop
  destination, and `res://Scenes/Koperasi/CosmeticShop.tscn`.

- [ ] **Step 1: Author the two tile icons**

`Assets/Images/Shop/UI/icon_shop_items.svg` (a drink cup beside a
burger) and `icon_shop_cosmetics.svg` (a t-shirt), matching the
mockup's silhouettes. White fill, transparent background, 128×128
viewBox, **paths only, no `<text>`**.

- [ ] **Step 2: Write the failing test suite**

Create `tests/test_shop_hub.gd`:

```gdscript
@tool
extends McpTestSuite

## The Lobby's shop button now lands on a hub that splits consumables
## from cosmetics, rather than dropping straight into the Koperasi.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "shop_hub"


const HUB_SCENE := "res://Scenes/Koperasi/ShopHub.tscn"
const COSMETIC_SCENE := "res://Scenes/Koperasi/CosmeticShop.tscn"
const HUB_SCRIPT := "res://Scripts/Koperasi/shop_hub.gd"
const LOBBY_SCRIPT := "res://Scripts/Lobby/loby.gd"
const KOPRASI_SCRIPT := "res://Scripts/Koperasi/koprasi.gd"


func test_both_new_scenes_load() -> void:
	assert_not_null(load(HUB_SCENE) as PackedScene, "ShopHub.tscn should load")
	assert_not_null(load(COSMETIC_SCENE) as PackedScene, "CosmeticShop.tscn should load")


func test_hub_offers_exactly_two_destinations() -> void:
	var hub := (load(HUB_SCENE) as PackedScene).instantiate()
	assert_not_null(hub.get_node_or_null("Tiles/ItemsTile"), "hub needs an items tile")
	assert_not_null(hub.get_node_or_null("Tiles/CosmeticsTile"), "hub needs a cosmetics tile")
	hub.free()


func test_hub_labels_are_indonesian() -> void:
	# The mockup was labelled in English; the project's UI is Indonesian.
	var src := FileAccess.get_file_as_string(HUB_SCRIPT)
	var scene_text := FileAccess.get_file_as_string(HUB_SCENE)
	var both := src + scene_text
	assert_contains(both, "Makanan & Barang", "items tile should be Indonesian")
	assert_contains(both, "Kosmetik", "cosmetics tile should be Indonesian")
	assert_false(both.contains("Foods & Items"), "no English UI copy")
	assert_false(both.contains("Cosmetics"), "no English UI copy")


func test_hub_blurs_the_real_koperasi_art_with_the_existing_shader() -> void:
	var scene_text := FileAccess.get_file_as_string(HUB_SCENE)
	assert_contains(scene_text, "Illustration4.jpg",
		"the hub should blur the screen the items tile actually leads to")
	assert_contains(scene_text, "blur.gdshader",
		"reuse the existing screen-space blur rather than a baked image")


func test_hub_routes_to_the_two_shops() -> void:
	var src := FileAccess.get_file_as_string(HUB_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/koprasi.tscn",
		"the items tile should reach the existing shop")
	assert_contains(src, "res://Scenes/Koperasi/CosmeticShop.tscn",
		"the cosmetics tile should reach the cosmetic stub")


func test_lobby_now_opens_the_hub_not_the_shop_directly() -> void:
	var src := FileAccess.get_file_as_string(LOBBY_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/ShopHub.tscn",
		"the Lobby's shop button should land on the hub")


func test_koprasi_back_button_returns_to_the_hub() -> void:
	var src := FileAccess.get_file_as_string(KOPRASI_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/ShopHub.tscn",
		"backing out of the shop should land on the hub, not the Lobby")
```

- [ ] **Step 3: Run and confirm failure**

`test_run` on `shop_hub`. Expected: FAIL — scenes do not exist.

- [ ] **Step 4: Add the `ShopHubTile` theme variation and rebake**

In `ThemeFactory.gd`, beside the other button variations:

```gdscript
	_add_button_variation(theme, tokens, "ShopHubTile",
		tokens.surface_card, tokens.surface_card,
		tokens.brand_primary, tokens.text_primary)
```

Use token names that exist — read `DesignTokens.gd` first. Rebake via
the transient-suite route described in Task 5 Step 2.

- [ ] **Step 5: Write `shop_hub.gd`**

Create `Scripts/Koperasi/shop_hub.gd`:

```gdscript
extends Control

## The fork between the two shops.
##
## The Lobby's shop button used to drop straight into the Koperasi. It
## now lands here, which splits consumables from cosmetics and gives the
## cosmetic shop somewhere to exist before it is built.
##
## The backdrop is the Koperasi's own art behind the project's existing
## screen-space blur shader, so this screen needs no image asset of its
## own and reads plainly as "the shop, out of focus".

## Where the "Makanan & Barang" tile leads.
@export var items_scene_path: String = "res://Scenes/Koperasi/koprasi.tscn"
## Where the "Kosmetik" tile leads.
@export var cosmetics_scene_path: String = "res://Scenes/Koperasi/CosmeticShop.tscn"
## Where the back button leads.
@export var back_scene_path: String = "res://Scenes/Lobby/loby.tscn"

@onready var items_tile: Button = $Tiles/ItemsTile
@onready var cosmetics_tile: Button = $Tiles/CosmeticsTile
@onready var back_button: Button = $BackButton


func _ready() -> void:
	items_tile.pressed.connect(_on_items_pressed)
	cosmetics_tile.pressed.connect(_on_cosmetics_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _on_items_pressed() -> void:
	AudioDirector.play_sfx(&"select")
	Transition.change_scene(items_scene_path, Transition.Style.WIPE)


func _on_cosmetics_pressed() -> void:
	AudioDirector.play_sfx(&"select")
	Transition.change_scene(cosmetics_scene_path, Transition.Style.WIPE)


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	Transition.change_scene(back_scene_path, Transition.Style.WIPE)
```

Confirm `AudioDirector` cue ids `select` and `cancel` exist before
using them — `EventStudentSelectDialog.gd` uses both, so they should.

- [ ] **Step 6: Write `cosmetic_shop.gd`**

```gdscript
extends Control

## The cosmetic shop, deliberately unbuilt.
##
## Ships as a backdrop, a heading and a back button so the hub's second
## tile leads somewhere rather than nowhere. Everything else waits on a
## design pass.

## Where the back button leads.
@export var back_scene_path: String = "res://Scenes/Koperasi/ShopHub.tscn"

@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	Transition.change_scene(back_scene_path, Transition.Style.WIPE)
```

- [ ] **Step 7: Build `ShopHubTile.tscn` through the editor**

A `Button` root named `ShopHubTile`, `theme_type_variation =
&"ShopHubTile"`, `custom_minimum_size = Vector2(420, 520)`, containing a
`VBoxContainer` with an `Icon` TextureRect (`expand_mode = 1`,
`stretch_mode = 5`, `custom_minimum_size = Vector2(240, 240)`) above a
`Label` with `theme_type_variation = &"H2Label"` and
`horizontal_alignment = 1`, `autowrap_mode = 2`.

- [ ] **Step 8: Build `ShopHub.tscn` through the editor**

Root `Control` named `ShopHub`, full-rect anchors, script attached.
Children in draw order:

1. `Backdrop` — `TextureRect`, full rect, `texture` =
   `res://Assets/Images/Shop/Illustration4.jpg`, `expand_mode = 1`,
   `stretch_mode = 6`
2. `BlurLayer` — `ColorRect`, full rect, with a new `ShaderMaterial`
   whose shader is `res://Scripts/Shaders/blur.gdshader`,
   `shader_parameter/lod = 2.5`, `shader_parameter/darkness = 0.35`
3. `Tiles` — `HBoxContainer`, centred, `separation = 48`, holding two
   `ShopHubTile.tscn` instances named `ItemsTile` and `CosmeticsTile`.
   Set `ItemsTile`'s icon to `icon_shop_items.svg` and its label to
   `"Makanan & Barang"`; `CosmeticsTile`'s to `icon_shop_cosmetics.svg`
   and `"Kosmetik"`.
4. `BackButton` — `Button`, `theme_type_variation = &"SecondaryButton"`,
   `text = "Kembali"`, `custom_minimum_size = Vector2(0, 96)`, anchored
   bottom.

`scene_save`.

- [ ] **Step 9: Build `CosmeticShop.tscn` through the editor**

Same `Backdrop` + `BlurLayer` pair as the hub, plus a centred `Label`
with `theme_type_variation = &"H1Label"` and `text = "Segera Hadir"`,
and the same `BackButton`. `scene_save`.

- [ ] **Step 10: Retarget the two navigation calls**

`Scripts/Lobby/loby.gd:788`:

```gdscript
	Transition.change_scene("res://Scenes/Koperasi/ShopHub.tscn", Transition.Style.WIPE)
```

`Scripts/Koperasi/koprasi.gd:102`:

```gdscript
	Transition.change_scene("res://Scenes/Koperasi/ShopHub.tscn", Transition.Style.WIPE)
```

Update `koprasi.gd`'s file-header comment at `:9`, which says it routes
back to the Lobby — that stops being true here.

- [ ] **Step 11: Add a debug teleport**

In `Scripts/Debug/DebugManager.gd`'s Scenes tab, add a ShopHub entry
beside the existing MainMenu / Lobby / StudentCard / AturJadwal /
SchoolDay / SemesterEnd / Splashscreen buttons, following whatever
pattern is already there.

- [ ] **Step 12: Rescan and run the full suite**

`filesystem_manage(op="scan")`, then a full `test_run`.
Expected: PASS across all suites, including the seven new `shop_hub` tests.

- [ ] **Step 13: Commit**

```bash
git add Assets/Images/Shop/UI/ Scenes/Koperasi/ShopHub.tscn Scenes/Koperasi/ShopHubTile.tscn Scenes/Koperasi/CosmeticShop.tscn Scripts/Koperasi/shop_hub.gd Scripts/Koperasi/cosmetic_shop.gd Scripts/Lobby/loby.gd Scripts/Koperasi/koprasi.gd Scripts/Design/ThemeFactory.gd Scripts/Debug/DebugManager.gd Assets/Theme/kejartes_theme.tres tests/test_shop_hub.gd
git commit -m "feat(shop): hub screen splitting items from cosmetics

The Lobby's shop button now lands on a hub with two tiles rather than
dropping straight into the Koperasi. Backdrop reuses the existing
screen-space blur over the Koperasi's own art, so the screen needs no
new image asset. The cosmetic shop ships as a deliberate stub.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 9: Documentation and final verification

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `CLAUDE.md`

- [ ] **Step 1: Run the whole suite one more time**

Full `test_run`. Every suite green. If anything fails, fix it — do not
record a pass that did not happen.

- [ ] **Step 2: Add a changelog entry**

Newest first in `docs/superpowers/CHANGELOG.md`, covering all five
changes and pointing at the spec.

- [ ] **Step 3: Update `CLAUDE.md`**

- Under **Outstanding debt & placeholders**, add the cosmetic shop stub
  and the five new placeholder SVG icons.
- Remove nothing that is still true. The layered-face and ratchet
  entries stay.
- Update the ratchet-debt entry's file count if the three lowered
  `BASELINE` entries changed it.
- Keep the file under its 20,000-character soft budget.

- [ ] **Step 4: Commit and report**

```bash
git add docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -m "docs: record the sprite rig, dialog, day phase and shop hub pass

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

Report to the user: what landed, the final `test_run` numbers, and the
one open item — the motion-lab transition curve from Task 7 Step 9.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: §1 → Tasks 1–2,
§2 → Tasks 3–4, §3 → Tasks 5–6, §4 → Task 7, §5 → Task 8, Testing →
folded into each task plus Task 9.

**Known soft spots, flagged rather than papered over:**

- Task 4 Step 7 and Task 7 Step 5 both say "read the existing code
  first and match its actual names". Those two functions could not be
  quoted verbatim without re-reading `LombaMenari.gd:694-760` and
  `BookClockWidget.gd:_apply_rotation` at implementation time. The
  instruction is explicit rather than guessed.
- Task 5's `set_stat` `target` argument is stated as `100.0` with an
  instruction to check `DaySummaryStudentRow.TARGET_FOR` first — that
  const suggests per-stat targets, and the card should match the row.
- Task 6 Step 4 initially reached into `card._student`; corrected inline
  to add a `student()` accessor in Task 5.
- The `BASELINE` numbers in Tasks 4 and 6 are deliberately not
  predicted. The instruction is to run the suite, read the true number,
  and set exactly that — lowering only.

**Type consistency.** `DancerRig.Pose` / `set_pose(pose, flipped)` /
`set_failed(on)` are used identically in Tasks 3 and 4.
`EventStudentCard.setup` / `set_preview` / `is_selected` /
`set_selectable` / `student()` / `selection_changed` are used
identically in Tasks 5 and 6. `BookClockWidget.Phase` /
`set_phase` / `transition_to(phase, duration)` are used identically in
Task 7's tests and implementation.
