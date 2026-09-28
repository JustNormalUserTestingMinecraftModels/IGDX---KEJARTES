# UI Depth Pass — Phase 1 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every button in the game a lip, a gloss band, role colours and a sink-on-press; add the press tick; and ship the `NotebookFrame` and the 16 placeholder icons that Phases 2–3 build on.

**Architecture:**
- **Lipped surfaces.** A new script-backed `LippedStyleBox` draws a lip, a face and a gloss band. `ThemeFactory._button_box()` returns one, so every button variation changes in one rebake. Role colours come from new palette tokens.
- **Press feel.** A small pure `PressFeel` helper decides, per button, between sink and shrink and whether to tick. `UIPolish` calls it.
- **Notebook frame.** `NotebookFrame` is a `@tool` Container scene: its decoration is authored in the `.tscn`, and host content is laid into its page.

**Tech Stack:** Godot 4.6 GDScript, the Godot AI MCP bridge (`test_run`, `script_patch`, `filesystem_manage`, `scene_open`, `scene_save`, `editor_screenshot`), and Python 3 + Pillow 12 for the three one-off placeholder textures.

**Spec:** `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md` (Phase 1 of 3).

## Global Constraints

- **Worktree.** Work in `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/ui-depth-pass/` on branch `feat/ui-depth-pass`. **Every file path you edit must start with that directory.** The parent folder is a different, shared checkout; never touch it.
- **Editor work is the controller's.** Only the controller session drives Godot: `test_run`, `script_patch`, scans, scene saves, screenshots. The bridge is single-client. Implementers write files and report; they never call godot-ai tools.
- **Tests.**
  - Tests are `McpTestSuite` suites in `tests/test_*.gd`, and every suite is `@tool`.
  - **No test may be a coroutine** (no `await`).
  - Helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_gt`, `assert_contains`, `assert_not_null`, `track`.
- **Theme rules.**
  - Never add a `theme_override_*`, except layout-only constants (`separation`, `margin_*`).
  - No visual is built at runtime in `Scripts/`: `test_viewport_editability` ratchets `.new()` of Controls.
- **Documentation.** Every script has a `##` file header, and every `@export` has a `##` line (`test_script_documentation`).
- **Clean code** (`ci/clean_code_scan.gd`, ratcheted by `test_clean_code`) applies to new `Scripts/` files:
  - no numeric literal other than 0, 1, 2 or 0.5 outside a `const` line
  - every `var` typed (`: T` or `:=`)
  - every function with a `->` return type and typed parameters
  - functions ≤ 50 code lines
  - when a count shrinks, lock it in with `ci/clean_code_dump.gd`
- **Colours** are tokens in `Scripts/Design/DesignTokens.gd`, never literals in `ThemeFactory`.
- **Palette** (base / lip), verbatim from the spec:

  | Name | Base | Lip |
  |---|---|---|
  | mint | `2EC99A` | `178A68` |
  | sky | `5EA1E6` | `3469B3` |
  | sunflower | `FFC93C` | `C9801A` |
  | tomato | `E5553E` | `A3301E` |
  | tangerine | `F58A3C` | `BD561A` |
  | cream | `FFF1DC` | `C9A57E` |
  | brown | `brand_primary_light` | `brand_primary_dark` |

- **Role colours:**
  - **mint:** the main action and affirm (`PrimaryButton`, `LobbyCtaButton`, `BookHeroButton`, `SuccessButton`, `ResultButton`, `PlusButton`, `NavTileKoperasi`).
  - **sunflower:** highlight only (`NavTileRapor`, `NotebookTabActive`), **never** a main action.
  - **sky:** `NavTileInventory`, `NotebookTab`.
  - **tomato:** `DangerButton`, `NotebookClose`.
  - **brown:** `SecondaryButton`, `LobbyNavTile`, `MainMenuButton`, `ShopShelfButton`, `CardArrowButton`, `QuirkBadge`.
  - **cream:** `StudentCardSecondaryButton`, `FilterChipButton`, `MinigameChoiceButton`.
  - **Information badges keep their meaning colours:** `RosterStatusBelum`/`Sudah`, `PersonaBadge`, `SpecialtyBadge`, `ResultLogsButton`.
- **Lipped label ink.** A face with `get_luminance()` > `lipped_light_face_luminance` (0.7) gets `text_primary` with no outline. Otherwise `text_on_brand`, outlined 8 px in the lip colour.
- **Press tick:** `PRESS_TICK_MS = 8`, only for the roles in `PressFeel.MAIN_ACTION_ROLES`.
- **Commits** use Conventional Commits with a scope, and end with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. In this worktree, run git as plain separate commands, not `cd … &&` chains.
- **Editor hazards** (CLAUDE.md 4b):
  - scene work first, then scripts
  - after any outside `.gd` write, do a no-op `script_patch` on that file before `test_run`
  - **a new `@export` on a Resource needs a full editor restart**
  - after a rebake, restart before the next scene save
  - check `git status` after full runs, and revert `Assets/Audio/default_bus_layout.tres`

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `Scripts/Design/LippedStyleBox.gd` | Create | The lip/face/gloss surface; `layout()` geometry; `set_vertical_padding()`. |
| `Scripts/Design/DesignTokens.gd` | Modify | Palette pairs, `lip_height`, `gloss_strength`, label-ink tokens, `release_pop_*`. |
| `Scripts/Design/ThemeFactory.gd` | Modify | Lipped buttons, role colours, label ink, the flat path kept for `EventSelectCard`, the notebook variations. |
| `Scripts/Design/PressFeel.gd` | Create | Pure: does this button sink, and does it tick. |
| `Scripts/Design/Juice.gd` | Modify | `pop_release()`. |
| `Scripts/UI/UIPolish.gd` | Modify | Sink-or-shrink per button, and the tick. |
| `Assets/Images/UI/Icons/*.svg` + `README.md` | Create | The 16 placeholder icons and their rules. |
| `Assets/Images/UI/Notebook/*.png` + `README.md` | Create | The ring, rule and sticker textures. |
| `Scripts/UI/NotebookFrame.gd`, `Scenes/UI/NotebookFrame.tscn` | Create | The reusable popup frame. |
| `tests/test_lipped_stylebox.gd`, `test_press_feel.gd`, `test_ui_icons.gd`, `test_notebook_frame.gd` | Create | New suites. |
| `tests/test_design_tokens.gd`, `test_theme_factory.gd`, `test_button_geometry.gd`, `test_lobby_style_buttons.gd`, `test_result_checkup.gd` | Modify | Follow the new surface. |
| `docs/superpowers/design/style-guide.md`, `DEBT.md`, `CHANGELOG.md`, `CLAUDE.md` | Modify | Docs. |

---

### Task 1: `LippedStyleBox`

**Files:**
- Create: `Scripts/Design/LippedStyleBox.gd`
- Test: `tests/test_lipped_stylebox.gd`

**Interfaces:**
- Produces: `class_name LippedStyleBox extends StyleBox` (`@tool`), with:
  - exports `bg_color: Color`, `lip_color: Color`, `lip_height: int`, `corner_radius: int`, `gloss_strength: float`, `shadow_color: Color`, `shadow_size: int`, `shadow_offset: Vector2`, `pressed: bool`
  - consts `GLOSS_INSET_X := 8`, `GLOSS_INSET_TOP := 4`, `GLOSS_HEIGHT_RATIO := 0.34`
  - `func layout(rect: Rect2) -> Dictionary`, returning keys `face: Rect2`, `lip: Rect2`, `gloss: Rect2`, `show_lip: bool`
  - `func set_vertical_padding(pad_v: int) -> void`
  - `func repad() -> void`

- [ ] **Step 1: Write the failing test**

Create `tests/test_lipped_stylebox.gd`:

```gdscript
@tool
extends McpTestSuite

## LippedStyleBox (2026-09-28 UI depth pass): a face on a solid darker lip,
## with a white gloss band. layout() is the geometry _draw() and these tests
## share; set_vertical_padding() keeps a button's height while centring its
## label on the face; and the box must survive a save/load, since the baked
## theme stores it as a script-backed sub-resource.
##
## Must be @tool; no test here may be a coroutine.

const ROUND_TRIP_PATH := "user://test_lipped_stylebox_roundtrip.tres"


func suite_name() -> String:
	return "lipped_stylebox"


func _box(lip: int) -> LippedStyleBox:
	var sb := LippedStyleBox.new()
	sb.lip_height = lip
	return sb


func test_the_face_sits_above_a_lip_of_the_same_size() -> void:
	var parts := _box(8).layout(Rect2(0, 0, 200, 100))
	assert_eq(parts["face"], Rect2(0, 0, 200, 92), "the face is the rect minus the lip")
	assert_eq(parts["lip"], Rect2(0, 8, 200, 92), "the lip is the face moved down by lip_height")
	assert_true(parts["show_lip"], "a resting box shows its lip")


func test_pressed_drops_the_face_onto_the_lip() -> void:
	var sb := _box(8)
	sb.pressed = true
	var parts := sb.layout(Rect2(0, 0, 200, 100))
	assert_eq(parts["face"], Rect2(0, 8, 200, 92), "the face drops by lip_height")
	assert_false(parts["show_lip"], "and the lip is hidden under it")


func test_the_gloss_covers_the_top_third_inset() -> void:
	var gloss: Rect2 = _box(8).layout(Rect2(0, 0, 200, 100))["gloss"]
	assert_eq(gloss.position, Vector2(LippedStyleBox.GLOSS_INSET_X, LippedStyleBox.GLOSS_INSET_TOP),
		"inset from the face's top-left")
	assert_eq(gloss.size.x, 200.0 - 2 * LippedStyleBox.GLOSS_INSET_X, "inset on both sides")
	assert_true(absf(gloss.size.y - 92.0 * LippedStyleBox.GLOSS_HEIGHT_RATIO) < 0.01,
		"a third of the face tall")


func test_the_gloss_follows_the_face_when_pressed() -> void:
	var sb := _box(8)
	sb.pressed = true
	var gloss: Rect2 = sb.layout(Rect2(0, 0, 200, 100))["gloss"]
	assert_eq(gloss.position.y, 8.0 + LippedStyleBox.GLOSS_INSET_TOP, "the gloss sinks with the face")


func test_vertical_padding_keeps_the_height_and_centres_on_the_face() -> void:
	var rest := _box(8)
	rest.set_vertical_padding(24)
	assert_eq(rest.content_margin_top + rest.content_margin_bottom, 48.0, "height unchanged")
	assert_eq(rest.content_margin_top, 20.0, "the label is lifted by half the lip")
	var held := _box(8)
	held.pressed = true
	held.set_vertical_padding(24)
	assert_eq(held.content_margin_top, 28.0, "held: the label drops with the face")
	assert_eq(held.content_margin_top - rest.content_margin_top, 8.0, "by exactly the lip")


func test_vertical_padding_never_goes_negative() -> void:
	var sb := _box(8)
	sb.set_vertical_padding(0)
	assert_eq(sb.content_margin_top, 0.0, "an icon-only button keeps a zero top margin")
	assert_eq(sb.content_margin_bottom, 0.0, "and a zero bottom margin")


func test_repad_keeps_the_padding_after_the_lip_changes() -> void:
	var sb := _box(8)
	sb.set_vertical_padding(24)
	sb.lip_height = 10
	sb.repad()
	assert_eq(sb.content_margin_top, 19.0, "re-centred on the taller lip")
	assert_eq(sb.content_margin_top + sb.content_margin_bottom, 48.0, "same height")


func test_a_zero_lip_is_a_flat_face() -> void:
	var parts := _box(0).layout(Rect2(0, 0, 200, 100))
	assert_eq(parts["face"], Rect2(0, 0, 200, 100), "the face fills the rect")
	assert_false(parts["show_lip"], "and no lip is drawn")


func test_it_survives_a_save_and_load() -> void:
	var sb := _box(9)
	sb.bg_color = Color("2EC99A")
	sb.lip_color = Color("178A68")
	sb.corner_radius = 20
	sb.gloss_strength = 0.4
	sb.pressed = true
	sb.set_vertical_padding(24)
	assert_eq(ResourceSaver.save(sb, ROUND_TRIP_PATH), OK, "saves")
	var back := ResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LippedStyleBox
	assert_true(back != null, "loads back as a LippedStyleBox")
	if back == null:
		return
	assert_eq(back.bg_color, Color("2EC99A"), "face colour")
	assert_eq(back.lip_color, Color("178A68"), "lip colour")
	assert_eq(back.lip_height, 9, "lip height")
	assert_eq(back.corner_radius, 20, "radius")
	assert_true(absf(back.gloss_strength - 0.4) < 0.001, "gloss")
	assert_true(back.pressed, "pressed state")
	assert_eq(back.content_margin_top, 28.0, "margins travel with it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP_PATH))
```

- [ ] **Step 2: Run the test to verify it fails (controller)**

Run `filesystem_manage(op="scan")`, then `test_run(suite="lipped_stylebox")`.
Expected: the suite fails to load, or every test errors on `LippedStyleBox` being an unknown identifier.

- [ ] **Step 3: Write the implementation**

Create `Scripts/Design/LippedStyleBox.gd`:

```gdscript
@tool
class_name LippedStyleBox
extends StyleBox

## A surface with depth for buttons, tabs and panels (2026-09-28 UI depth
## pass; docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md).
##
## Draws three shapes, back to front: a solid darker LIP, the FACE on top of
## it, and a white GLOSS band across the face's top third. pressed = true is
## the held state -- no lip, the face lowered by lip_height -- so a button
## sinks onto its lip on the exact frame of the touch, with no animation to
## lag or skip.
##
## Each shape is drawn by an internal StyleBoxFlat, which keeps Godot's
## anti-aliased corners. layout() is the geometry, pure, so the tests read
## the same numbers _draw() uses.

## Gloss band inset from the face's left and right edges, px.
const GLOSS_INSET_X := 8
## Gloss band inset from the face's top edge, px.
const GLOSS_INSET_TOP := 4
## Gloss band height as a fraction of the face's height.
const GLOSS_HEIGHT_RATIO := 0.34

## The face colour (named like StyleBoxFlat's, so a reader of either type
## finds it in the same place).
@export var bg_color: Color = Color.WHITE:
	set(value):
		bg_color = value
		emit_changed()
## The lip colour: the solid slab showing under the face.
@export var lip_color: Color = Color.BLACK:
	set(value):
		lip_color = value
		emit_changed()
## How far the lip shows below the face, px. 0 draws a flat face.
@export_range(0, 32) var lip_height: int = 0:
	set(value):
		lip_height = maxi(value, 0)
		emit_changed()
## Corner radius of the face and lip, px. Godot clamps it to half the
## shorter side, so a large value makes a pill.
@export var corner_radius: int = 0:
	set(value):
		corner_radius = maxi(value, 0)
		emit_changed()
## Alpha of the white gloss band. 0 hides it.
@export_range(0.0, 1.0) var gloss_strength: float = 0.0:
	set(value):
		gloss_strength = value
		emit_changed()
## The soft drop shadow, drawn under the bottom-most shape.
@export var shadow_color: Color = Color(0, 0, 0, 0):
	set(value):
		shadow_color = value
		emit_changed()
## Blur size of the drop shadow, px.
@export var shadow_size: int = 0:
	set(value):
		shadow_size = maxi(value, 0)
		emit_changed()
## Offset of the drop shadow, px.
@export var shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		shadow_offset = value
		emit_changed()
## True draws the held state: no lip, the face lowered by lip_height.
@export var pressed: bool = false:
	set(value):
		pressed = value
		emit_changed()

var _lip_box: StyleBoxFlat = StyleBoxFlat.new()
var _face_box: StyleBoxFlat = StyleBoxFlat.new()
var _gloss_box: StyleBoxFlat = StyleBoxFlat.new()


## Face, lip and gloss rects for `rect`, and whether the lip shows.
##
## Affects: nothing. Pure.
func layout(rect: Rect2) -> Dictionary:
	var lip := float(lip_height)
	var face_size := Vector2(rect.size.x, maxf(rect.size.y - lip, 0.0))
	var face := Rect2(rect.position + Vector2(0.0, lip if pressed else 0.0), face_size)
	var gloss := Rect2(
		face.position + Vector2(GLOSS_INSET_X, GLOSS_INSET_TOP),
		Vector2(maxf(face.size.x - 2.0 * GLOSS_INSET_X, 0.0), face.size.y * GLOSS_HEIGHT_RATIO))
	return {
		"face": face,
		"lip": Rect2(rect.position + Vector2(0.0, lip), face_size),
		"gloss": gloss,
		"show_lip": lip_height > 0 and not pressed,
	}


## Split `pad_v` between top and bottom so the label centres on the face,
## keeping the sum -- and so the button's height -- unchanged. At rest the
## label rises by half the lip; held, it drops by the same, so it moves
## with the face.
##
## Affects: content_margin_top, content_margin_bottom.
func set_vertical_padding(pad_v: int) -> void:
	var shift := mini(floori(lip_height / 2.0), pad_v)
	var lift := -shift if pressed else shift
	content_margin_top = pad_v - lift
	content_margin_bottom = pad_v + lift


## Re-run set_vertical_padding() with the padding the box already carries,
## after lip_height changed.
##
## Affects: content_margin_top, content_margin_bottom.
func repad() -> void:
	set_vertical_padding(roundi((content_margin_top + content_margin_bottom) / 2.0))


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var parts := layout(rect)
	var show_lip: bool = parts["show_lip"]
	_paint(_lip_box, lip_color, corner_radius)
	_paint(_face_box, bg_color, corner_radius)
	_paint(_gloss_box, Color(1, 1, 1, gloss_strength), maxi(corner_radius - GLOSS_INSET_X, 0))
	var lowest := _lip_box if show_lip else _face_box
	lowest.shadow_color = shadow_color
	lowest.shadow_size = shadow_size
	lowest.shadow_offset = shadow_offset
	if show_lip:
		_lip_box.draw(to_canvas_item, parts["lip"])
	_face_box.draw(to_canvas_item, parts["face"])
	if gloss_strength > 0.0:
		_gloss_box.draw(to_canvas_item, parts["gloss"])


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(shadow_size + ceili(shadow_offset.length()))


static func _paint(box: StyleBoxFlat, color: Color, radius: int) -> void:
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.shadow_size = 0
```

- [ ] **Step 4: Run the test to verify it passes (controller)**

Run `filesystem_manage(op="scan")`, a no-op `script_patch` on both new files, then `test_run(suite="lipped_stylebox")`.
Expected: 9/9 PASS. Then `test_run(suite="script_documentation")` and `test_run(suite="clean_code")`. Expected: both PASS. If `clean_code` reports this new file's untyped count, fix the typing, do not baseline it.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/LippedStyleBox.gd Scripts/Design/LippedStyleBox.gd.uid tests/test_lipped_stylebox.gd tests/test_lipped_stylebox.gd.uid
git commit -m "feat(design): LippedStyleBox, a face on a lip with a gloss band" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Palette and depth tokens

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd`. Add a group after the `Semantic States` group (after `currency_gold`), and two exports at the end of the `Motion` group.
- Test: `tests/test_design_tokens.gd` (append)

**Interfaces:**
- Produces these `DesignTokens` exports:
  - colours: `accent_mint`, `accent_mint_lip`, `accent_sky`, `accent_sky_lip`, `accent_sunflower`, `accent_sunflower_lip`, `accent_tomato`, `accent_tomato_lip`, `accent_tangerine`, `accent_tangerine_lip`, `button_cream`, `button_cream_lip`
  - ints: `lip_height`, `lipped_label_outline`
  - floats: `gloss_strength`, `lipped_light_face_luminance`, `release_pop_scale`, `release_pop_duration`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_design_tokens.gd`:

```gdscript

## 2026-09-28 UI depth pass: the palette pairs, verbatim from the spec.
func test_depth_palette_matches_the_spec() -> void:
	var tokens := DesignTokens.load_default()
	var want := {
		"accent_mint": "2ec99a", "accent_mint_lip": "178a68",
		"accent_sky": "5ea1e6", "accent_sky_lip": "3469b3",
		"accent_sunflower": "ffc93c", "accent_sunflower_lip": "c9801a",
		"accent_tomato": "e5553e", "accent_tomato_lip": "a3301e",
		"accent_tangerine": "f58a3c", "accent_tangerine_lip": "bd561a",
		"button_cream": "fff1dc", "button_cream_lip": "c9a57e",
	}
	for key in want:
		assert_eq((tokens.get(key) as Color).to_html(false), want[key], key)


## Every lip is darker than its face, so the slab reads as a shadow side.
func test_every_lip_is_darker_than_its_face() -> void:
	var tokens := DesignTokens.load_default()
	for base in ["accent_mint", "accent_sky", "accent_sunflower", "accent_tomato",
			"accent_tangerine", "button_cream"]:
		var face: Color = tokens.get(base)
		var lip: Color = tokens.get(base + "_lip")
		assert_true(lip.get_luminance() < face.get_luminance(), base + "'s lip is darker")


func test_depth_and_release_tokens() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.lip_height, 7, "lip_height")
	assert_true(absf(tokens.gloss_strength - 0.5) < 0.001, "gloss_strength")
	assert_true(absf(tokens.lipped_light_face_luminance - 0.7) < 0.001, "label-ink threshold")
	assert_eq(tokens.lipped_label_outline, 8, "label outline")
	assert_true(absf(tokens.release_pop_scale - 1.03) < 0.001, "release pop")
	assert_true(absf(tokens.release_pop_duration - 0.12) < 0.001, "release pop length")
```

- [ ] **Step 2: Run the test to verify it fails (controller)**

No-op `script_patch` on `tests/test_design_tokens.gd`, then `test_run(suite="design_tokens")`.
Expected: the three new tests FAIL (`tokens.get(...)` returns null, and the properties are missing).

- [ ] **Step 3: Add the tokens**

In `Scripts/Design/DesignTokens.gd`, directly after the `currency_gold` export (end of `Semantic States`), insert:

```gdscript

@export_group("Depth Palette")
## Face of the main action and affirm roles -- PrimaryButton, LobbyCtaButton,
## BookHeroButton, SuccessButton, ResultButton, PlusButton, NavTileKoperasi.
## Green means "go" on every screen since the 2026-09-28 UI depth pass.
@export var accent_mint: Color = Color("2EC99A")
## Lip under accent_mint faces.
@export var accent_mint_lip: Color = Color("178A68")
## Face of NavTileInventory and the inactive NotebookTab.
@export var accent_sky: Color = Color("5EA1E6")
## Lip under accent_sky faces.
@export var accent_sky_lip: Color = Color("3469B3")
## Highlight only, never an action: NavTileRapor and the active NotebookTab.
## Gold on a button reads as "buy currency" (scrapbook HUD spec, 3.2).
@export var accent_sunflower: Color = Color("FFC93C")
## Lip under accent_sunflower faces.
@export var accent_sunflower_lip: Color = Color("C9801A")
## Face of DangerButton and NotebookClose.
@export var accent_tomato: Color = Color("E5553E")
## Lip under accent_tomato faces.
@export var accent_tomato_lip: Color = Color("A3301E")
## Secondary warm accent, reserved for Phase 3's screens.
@export var accent_tangerine: Color = Color("F58A3C")
## Lip under accent_tangerine faces.
@export var accent_tangerine_lip: Color = Color("BD561A")
## Face of the cream roles -- StudentCardSecondaryButton, FilterChipButton,
## MinigameChoiceButton.
@export var button_cream: Color = Color("FFF1DC")
## Lip under button_cream faces.
@export var button_cream_lip: Color = Color("C9A57E")
## How far a lipped surface's lip shows below its face, px (LippedStyleBox).
@export_range(0, 24) var lip_height: int = 7
## Alpha of the white gloss band on a lipped button's face.
@export_range(0.0, 1.0) var gloss_strength: float = 0.5
## A lipped button whose face is brighter than this gets dark text_primary
## ink with no outline; a darker face gets outlined text_on_brand.
@export_range(0.0, 1.0) var lipped_light_face_luminance: float = 0.7
## Outline width of the white label on a dark lipped face, px.
@export var lipped_label_outline: int = 8
```

At the end of the `Motion` group, just before `@export_group("Layout")`, insert:

```gdscript
## Scale a lipped button bumps to when released, before settling at 1.0
## (Juice.pop_release). Its pressed stylebox already sank it, so it never
## shrinks.
@export_range(1.0, 1.2) var release_pop_scale: float = 1.03
## Length of that release bump, s.
@export_range(0.05, 0.5) var release_pop_duration: float = 0.12
```

`design_tokens.tres` needs no edit, because unsaved exports read their script defaults.

- [ ] **Step 4: Restart the editor, then run (controller)**

New `@export`s on a Resource need a **full editor restart** (CLAUDE.md). Stop the worktree editor, relaunch it, re-list the sessions, and pass the new `session_id`. Then run:
- `test_run(suite="design_tokens")`. Expected: all PASS.
- `test_run(suite="script_documentation")`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/DesignTokens.gd tests/test_design_tokens.gd
git commit -m "feat(design): depth palette, lip and release tokens" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Every button becomes lipped

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`:
  - `_build_buttons` (~1273)
  - `_build_shop_shelf_button`, `_build_result_button`, `_build_main_menu_button`, `_add_lobby_button`, `_set_content_margins`, `_add_button_variation`, `_add_size_step`, `_button_box` (~1440–1620)
  - the `MinigameChoiceButton` call (~2069)
  - `_thicken_lip` and `_build_lobby_hud` (~2585–2640)
  - `_build_base_overrides` (~2766)
- Modify tests: `tests/test_theme_factory.gd`, `tests/test_button_geometry.gd`, `tests/test_lobby_style_buttons.gd`, `tests/test_result_checkup.gd`
- Regenerate: `Assets/Theme/kejartes_theme.tres` (through the `theme_rebake` suite)

**Interfaces:**
- Consumes: `LippedStyleBox` (Task 1) and the Task 2 tokens.
- Produces:
  - `_button_box(tokens, face: Color, lip: Color, radius: int, pressed := false) -> LippedStyleBox`
  - `_add_button_variation(theme, tokens, name: String, face: Color, lip: Color, radius: int = -1) -> void`
  - `_add_flat_button_variation(...)`, the old 8-argument signature, kept for `EventSelectCard`
  - `_pad_vertical(sb: StyleBox, pad_v: int) -> void`
  - `_apply_lipped_text(theme, tokens, name, face, lip) -> void`
  - a `ThemeFactory.DISABLED_FADE` const
  - after this task, `get_stylebox("normal", <role>)` is a `LippedStyleBox` for every role in the Global Constraints' role table

- [ ] **Step 1: Rewrite the role test suite first (failing)**

Replace everything in `tests/test_lobby_style_buttons.gd` **above** `func test_main_menu_and_weekly_results_keep_their_fit()` with:

```gdscript
@tool
extends McpTestSuite

## Button roles (2026-09-28 UI depth pass, replacing the 2026-09-14
## lobby-style-buttons rule that every action button wore the brown Lobby
## look). Every framed button is now a LippedStyleBox: a face on a darker
## lip, sinking onto the lip when held. Its colours say its role -- mint is
## the main action and affirm on every screen, tomato is danger, brown is
## neutral, cream is quiet, sky and sunflower are the Lobby tiles' and the
## notebook tabs' own. Information badges keep their meaning colours.
## Spec: docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md.

const _STUDENT_CARD := "res://Scenes/StudentCard/StudentCard.tscn"
const _ROSTER_CARD := "res://Scenes/StudentList/RosterCard.tscn"

var _tokens: DesignTokens
var _theme: Theme


func suite_name() -> String:
	return "lobby_style_buttons"


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


## role -> [face token, lip token], every generated size step included.
func _roles() -> Dictionary:
	var t := _tokens
	var mint := [t.accent_mint, t.accent_mint_lip]
	var brown := [t.brand_primary_light, t.brand_primary_dark]
	var tomato := [t.accent_tomato, t.accent_tomato_lip]
	var cream := [t.button_cream, t.button_cream_lip]
	return {
		"PrimaryButton": mint, "PrimaryButtonM": mint, "PrimaryButtonL": mint,
		"SuccessButton": mint, "SuccessButtonL": mint,
		"LobbyCtaButton": mint, "BookHeroButton": mint, "ResultButton": mint,
		"PlusButton": mint, "NavTileKoperasi": mint,
		"NavTileInventory": [t.accent_sky, t.accent_sky_lip],
		"NavTileRapor": [t.accent_sunflower, t.accent_sunflower_lip],
		"DangerButton": tomato, "DangerButtonM": tomato, "DangerButtonL": tomato,
		"SecondaryButton": brown, "SecondaryButtonM": brown, "SecondaryButtonL": brown,
		"LobbyNavTile": brown, "MainMenuButton": brown, "ShopShelfButton": brown,
		"QuirkBadge": brown, "CardArrowButton": [t.brand_primary, t.brand_primary_dark],
		"StudentCardSecondaryButton": cream, "StudentCardSecondaryButtonL": cream,
		"FilterChipButton": cream, "MinigameChoiceButton": cream,
	}


func _box(state: String, name: String) -> LippedStyleBox:
	return _theme.get_stylebox(state, name) as LippedStyleBox


## A variation's resting face, or transparent when it is not lipped.
func _fill(name: String) -> Color:
	var sb := _box("normal", name)
	return sb.bg_color if sb != null else Color(0, 0, 0, 0)


func test_every_role_wears_its_palette_colour() -> void:
	var roles := _roles()
	for name in roles:
		var sb := _box("normal", name)
		assert_true(sb != null, name + "/normal is a LippedStyleBox")
		if sb == null:
			continue
		assert_eq(sb.bg_color, roles[name][0], name + " face")
		assert_eq(sb.lip_color, roles[name][1], name + " lip")


func test_every_role_sinks_onto_its_lip_when_held() -> void:
	for name in _roles():
		var rest := _box("normal", name)
		var held := _box("pressed", name)
		assert_true(rest != null and not rest.pressed and rest.lip_height > 0,
			name + " rests on a lip")
		assert_true(held != null and held.pressed, name + " sinks when held")


func test_gold_is_never_a_main_action() -> void:
	for name in ["PrimaryButton", "LobbyCtaButton", "BookHeroButton", "SuccessButton",
			"ResultButton", "PlusButton"]:
		assert_ne(_fill(name), _tokens.accent_sunflower, name + " is not gold")
		assert_ne(_fill(name), _tokens.currency_gold, name + " does not look like a purchase")


## Outlined light text on a dark face; dark ink with no outline on a light one.
func test_label_ink_follows_the_face() -> void:
	assert_eq(_theme.get_color("font_color", "PrimaryButton"), _tokens.text_on_brand,
		"white on mint")
	assert_eq(_theme.get_constant("outline_size", "PrimaryButton"), _tokens.lipped_label_outline,
		"outlined")
	assert_eq(_theme.get_color("font_outline_color", "PrimaryButton"), _tokens.accent_mint_lip,
		"in the lip colour")
	for light in ["NavTileRapor", "StudentCardSecondaryButtonL", "FilterChipButton"]:
		assert_eq(_theme.get_color("font_color", light), _tokens.text_primary, light + " dark ink")
		assert_eq(_theme.get_constant("outline_size", light), 0, light + " no outline")


func test_student_card_keeps_its_cream_secondary() -> void:
	assert_eq(_fill("StudentCardSecondaryButtonL"), _tokens.button_cream, "cream face")
	assert_eq(_theme.get_font_size("font_size", "StudentCardSecondaryButtonL"),
		_tokens.font_h1, "the L step")


func test_status_badges_keep_their_red_and_green() -> void:
	assert_eq(_fill("RosterStatusBelum"), _tokens.state_danger.lightened(0.18), "BELUM stays red")
	assert_eq(_fill("RosterStatusSudah"), _tokens.state_success.lightened(0.18), "SUDAH stays green")


## The event dialog's student card stays flat: its pressed state means
## SELECTED, which a sink would not say.
func test_the_event_select_card_stays_flat() -> void:
	assert_true(_theme.get_stylebox("normal", "EventSelectCard") is StyleBoxFlat,
		"EventSelectCard keeps its flat selectable card")
```

Then, in the rest of that file (the tests from `test_main_menu_and_weekly_results_keep_their_fit` down), replace every `_flat("…", "…")` call with `_theme.get_stylebox("…", "…")`. Content margins live on `StyleBox`, so those assertions keep working. Delete the old `_flat` helper if any use of it remains.

- [ ] **Step 2: Update the other pinned tests (failing)**

In `tests/test_theme_factory.gd`, replace `test_primary_button_uses_brand_color`:

```gdscript
func test_primary_button_is_the_mint_main_action() -> void:
	var sb := _theme.get_stylebox("normal", "PrimaryButton") as LippedStyleBox
	assert_true(sb != null, "PrimaryButton/normal must be a LippedStyleBox")
	if sb == null:
		return
	assert_eq(sb.bg_color, _tokens.accent_mint, "the main action is mint")
	assert_eq(sb.lip_color, _tokens.accent_mint_lip, "on its darker lip")
```

In `test_buttons_meet_minimum_touch_target`, change `as StyleBoxFlat` to `as StyleBox`.

In `test_changing_a_token_changes_the_built_theme`, change the body to:

```gdscript
	var custom := DesignTokens.new()
	custom.accent_mint = Color("ff0000")
	var custom_theme := ThemeFactory.build(custom)
	var sb := custom_theme.get_stylebox("normal", "PrimaryButton") as LippedStyleBox
	assert_eq(sb.bg_color, Color("ff0000"),
		"theme must be derived from tokens, not hardcoded")
```

In the MainMenuButton test (~191), change `as StyleBoxFlat` to `as LippedStyleBox`. Change the comment above it to `# Since the 2026-09-28 UI depth pass it is a brown lipped box.` The assertion (`brand_primary_light`) stays.

Replace `test_scrapbook_plus_and_hero_are_green`'s body with:

```gdscript
	var plus := _theme.get_stylebox("normal", "PlusButton") as LippedStyleBox
	assert_true(plus != null, "PlusButton/normal is a lipped box")
	if plus == null:
		return
	assert_eq(plus.bg_color, _tokens.accent_mint, "the + wears the main-action green")
	assert_ne(plus.bg_color, _tokens.currency_gold, "a gold + would read as an IAP button")
	var hero := _theme.get_stylebox("normal", "BookHeroButton") as LippedStyleBox
	assert_true(hero != null and hero.bg_color == _tokens.accent_mint,
		"JADWAL wears the main-action green")
	assert_eq(hero.lip_height, ThemeFactory.LOBBY_HUD_LIP, "the scrapbook's thicker lip")
```

In `tests/test_result_checkup.gd` `test_logs_wears_the_light_red_result_button`, change `as StyleBoxFlat` to `as LippedStyleBox`.

In `tests/test_button_geometry.gd`:
- Add this helper under `_button_variations()`:

```gdscript
## A button box's corner radius, whichever surface type it is.
func _radius(sb: StyleBox) -> int:
	if sb is LippedStyleBox:
		return (sb as LippedStyleBox).corner_radius
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).corner_radius_top_left
	return -1
```

- In `test_every_button_variation_uses_one_fixed_radius`, replace the two `as StyleBoxFlat` lookups and the assertion with:

```gdscript
		var sb := _theme.get_stylebox("normal", name)
		if _radius(sb) < 0:
			sb = _theme.get_stylebox("hover", name)
		if _radius(sb) < 0:
			continue
		checked += 1
		assert_eq(_radius(sb), _tokens.radius_button,
			"%s must use radius_button (%d), got %d"
				% [name, _tokens.radius_button, _radius(sb)])
```

- In the natural-height test (~153), change `as StyleBoxFlat` to `as StyleBox`.
- Replace `test_card_arrow_button_is_a_circle`'s body with:

```gdscript
	var sb := _theme.get_stylebox("normal", "CardArrowButton") as LippedStyleBox
	assert_not_null(sb, "CardArrowButton/normal must be a LippedStyleBox")
	assert_eq(sb.corner_radius, _tokens.radius_pill,
		"CardArrowButton is a fixed square, so radius_pill makes it a circle")
	assert_eq(sb.bg_color, _tokens.brand_primary, "arrow face")
	assert_eq(sb.lip_color, _tokens.brand_primary_dark, "arrow lip")
```

- [ ] **Step 3: Run to verify they fail (controller)**

No-op `script_patch` on the four test files, then `test_run` for suites `lobby_style_buttons`, `theme_factory`, `button_geometry` and `result_checkup`.
Expected: the new and changed assertions FAIL, because the theme is still flat.

- [ ] **Step 4: Rewrite the button builders in `ThemeFactory.gd`**

a) Just above `static func _add_button_variation(`, add:

```gdscript
## How far a disabled lipped button's face and lip fade toward surface_sunken.
const DISABLED_FADE := 0.7
```

b) Replace `_add_button_variation` and `_button_box` entirely. Rename the old versions `_add_flat_button_variation` and `_flat_button_box`, with their bodies unchanged except that `_add_flat_button_variation` calls `_flat_button_box`. Keep their doc comments and prefix each with `## Kept for EventSelectCard, whose pressed state means SELECTED.` Then add the new versions:

```gdscript
## One lipped button role in five states (2026-09-28 UI depth pass).
##
## `face` is the resting surface and `lip` the darker slab under it. hover
## and normal share one box, since a touch game has no hover. focus is
## empty, because Godot draws focus OVER normal and a second face would
## double the gloss. pressed is the same box held down; disabled fades
## toward surface_sunken on half a lip. `radius` is -1 for radius_button;
## chips and the arrow pass their own.
static func _add_button_variation(
	theme: Theme,
	tokens: DesignTokens,
	name: String,
	face: Color,
	lip: Color,
	radius: int = -1
) -> void:
	var r: int = tokens.radius_button if radius < 0 else radius
	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	var rest := _button_box(tokens, face, lip, r)
	theme.set_stylebox("normal", name, rest)
	theme.set_stylebox("hover", name, rest)
	theme.set_stylebox("focus", name, StyleBoxEmpty.new())
	theme.set_stylebox("pressed", name, _button_box(tokens, face, lip, r, true))

	var disabled := _button_box(tokens,
		face.lerp(tokens.surface_sunken, DISABLED_FADE),
		lip.lerp(tokens.surface_sunken, DISABLED_FADE), r)
	disabled.lip_height = floori(tokens.lip_height / 2.0)
	disabled.set_vertical_padding(tokens.btn_pad_v_s)
	disabled.shadow_size = 0
	theme.set_stylebox("disabled", name, disabled)

	_apply_lipped_text(theme, tokens, name, face, lip)
	theme.set_font_size("font_size", name, tokens.font_title)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)


## A lipped button's label ink: outlined text_on_brand on a dark face, plain
## text_primary on a light one (above lipped_light_face_luminance), where an
## outline would only muddy it.
static func _apply_lipped_text(theme: Theme, tokens: DesignTokens, name: String,
		face: Color, lip: Color) -> void:
	var light_face := face.get_luminance() > tokens.lipped_light_face_luminance
	var ink := tokens.text_primary if light_face else tokens.text_on_brand
	for key in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(key, name, ink)
	theme.set_color("font_disabled_color", name, tokens.text_disabled)
	theme.set_color("font_outline_color", name, lip)
	theme.set_constant("outline_size", name, 0 if light_face else tokens.lipped_label_outline)


## One lipped surface: `face` on `lip`, with the house gloss, soft shadow
## and padding. `pressed` builds the held state.
static func _button_box(tokens: DesignTokens, face: Color, lip: Color, radius: int,
		pressed: bool = false) -> LippedStyleBox:
	var sb := LippedStyleBox.new()
	sb.bg_color = face
	sb.lip_color = lip
	sb.lip_height = tokens.lip_height
	sb.corner_radius = radius
	sb.gloss_strength = tokens.gloss_strength
	sb.shadow_color = tokens.shadow_color
	sb.shadow_size = tokens.shadow_size
	sb.shadow_offset = tokens.shadow_offset
	sb.pressed = pressed
	sb.content_margin_left = tokens.space_lg
	sb.content_margin_right = tokens.space_lg
	sb.set_vertical_padding(tokens.btn_pad_v_s)
	return sb


## Set a box's vertical padding: a lipped box splits it around its lip, a
## flat one takes it top and bottom.
static func _pad_vertical(sb: StyleBox, pad_v: int) -> void:
	if sb is LippedStyleBox:
		(sb as LippedStyleBox).set_vertical_padding(pad_v)
		return
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
```

c) Replace `_set_content_margins`'s loop body:

```gdscript
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := theme.get_stylebox(state, name)
		sb.content_margin_left = pad_h
		sb.content_margin_right = pad_h
		_pad_vertical(sb, pad_v)
```

d) In `_add_size_step`, replace the stylebox loop and the colour-copy loop with:

```gdscript
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := theme.get_stylebox(state, base).duplicate() as StyleBox
		_pad_vertical(sb, pad_v)
		if pad_h >= 0:
			sb.content_margin_left = pad_h
			sb.content_margin_right = pad_h
		theme.set_stylebox(state, name, sb)

	for key in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color", "font_disabled_color",
			"font_outline_color"]:
		theme.set_color(key, name, theme.get_color(key, base))
	theme.set_constant("outline_size", name, theme.get_constant("outline_size", base))
```

e) Replace `_add_lobby_button`'s body (and its doc line with `## The brown neutral role: brand_primary_light on brand_primary_dark.`):

```gdscript
	_add_button_variation(theme, tokens, name,
		tokens.brand_primary_light, tokens.brand_primary_dark)
```

f) Replace `_thicken_lip`:

```gdscript
## Give every state of a lipped variation a `lip` px lip -- the scrapbook
## tiles' thicker slab -- keeping its padding. disabled keeps half.
static func _thicken_lip(theme: Theme, name: String, lip: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := theme.get_stylebox(state, name) as LippedStyleBox
		if sb == null:
			continue
		sb.lip_height = floori(lip / 2.0) if state == "disabled" else lip
		sb.repad()
```

g) Update the call sites. The new signature is `(theme, tokens, name, face, lip[, radius])`, so the old `border` and `text_color` arguments go.

| Call (where) | New arguments after `name` |
|---|---|
| the `for role in [...]` loop in `_build_buttons` | replace the loop with: `_add_button_variation(theme, tokens, "PrimaryButton", tokens.accent_mint, tokens.accent_mint_lip)`, the same for `"SuccessButton"`, `_add_lobby_button(theme, tokens, "SecondaryButton")`, and `_add_button_variation(theme, tokens, "DangerButton", tokens.accent_tomato, tokens.accent_tomato_lip)` |
| `StudentCardSecondaryButton` | `tokens.button_cream, tokens.button_cream_lip` |
| `RosterStatusBelum` | `tokens.state_danger.lightened(0.18), tokens.state_danger.darkened(0.24)` |
| `RosterStatusSudah` | `tokens.state_success.lightened(0.18), tokens.state_success.darkened(0.24)` |
| `EventSelectCard` | **call `_add_flat_button_variation`** with its current eight arguments unchanged |
| `QuirkBadge` | `tokens.brand_primary_light, tokens.brand_primary_dark, tokens.radius_pill` |
| `PersonaBadge` | `tokens.cat_istirahat.lightened(0.18), tokens.cat_istirahat.darkened(0.24), tokens.radius_pill` |
| `SpecialtyBadge` | `tokens.surface_sunken, tokens.surface_sunken.darkened(0.18), tokens.radius_pill` |
| `LobbyCtaButton` (`_add_lobby_button(theme, tokens, "LobbyCtaButton")`) | `_add_button_variation(theme, tokens, "LobbyCtaButton", tokens.accent_mint, tokens.accent_mint_lip)` |
| `FilterChipButton` | `tokens.button_cream, tokens.button_cream_lip` |
| `CardArrowButton` | `tokens.brand_primary, tokens.brand_primary_dark, tokens.radius_pill` |
| `ResultButton` (`_add_lobby_button(theme, tokens, "ResultButton")` in `_build_result_button`) | `_add_button_variation(theme, tokens, "ResultButton", tokens.accent_mint, tokens.accent_mint_lip)` |
| `ResultLogsButton` | `tokens.result_logs_fill, tokens.result_logs_dark` |
| `MinigameChoiceButton` | `tokens.button_cream, tokens.button_cream_lip` |
| `BookHeroButton` | `tokens.accent_mint, tokens.accent_mint_lip` |
| `NavTileKoperasi` | `tokens.accent_mint, tokens.accent_mint_lip` |
| `NavTileInventory` | `tokens.accent_sky, tokens.accent_sky_lip` (its "may read as Akademis" comment no longer applies; say it is sky now) |
| `NavTileRapor` | `tokens.accent_sunflower, tokens.accent_sunflower_lip` (the label-ink rule now gives it `text_primary`; keep the contrast comment) |
| `PlusButton` | `tokens.accent_mint, tokens.accent_mint_lip` |

Then run `grep -n "_add_button_variation(\|_button_box(" Scripts/Design/ThemeFactory.gd`. Every `_button_box(` call must match the new `(tokens, face, lip, radius[, pressed])` signature. For **any call not listed above**, map it by the same rule: face = the old `top`, lip = the old `bottom`, radius kept. Name it in your report.

h) In `_build_base_overrides`, replace the four `theme.set_stylebox(..., "Button", _button_box(...))` statements with:

```gdscript
	var base_rest := _button_box(tokens, tokens.brand_primary_light,
		tokens.brand_primary_dark, tokens.radius_button)
	theme.set_stylebox("normal", "Button", base_rest)
	theme.set_stylebox("hover", "Button", base_rest)
	theme.set_stylebox("pressed", "Button", _button_box(tokens,
		tokens.brand_primary_light, tokens.brand_primary_dark, tokens.radius_button, true))
	theme.set_stylebox("disabled", "Button", _button_box(tokens,
		tokens.surface_sunken, tokens.surface_sunken.darkened(0.18), tokens.radius_button))
```

i) Run `grep -n "as StyleBoxFlat" Scripts/Design/ThemeFactory.gd`. Any cast that reads a **button** state box (`normal`/`hover`/`pressed`/`focus`/`disabled` of a variation built by `_add_button_variation`) must use `StyleBox`, `_pad_vertical` or `LippedStyleBox` instead. Casts on panel, progress and price-tag boxes stay.

- [ ] **Step 5: Run the targeted suites (controller)**

Do a no-op `script_patch` on `ThemeFactory.gd`, then `test_run` each of:
- `lobby_style_buttons`, `theme_factory`, `button_geometry`, `result_checkup`
- `lipped_stylebox`, `clean_code`, `script_documentation`

Expected: all PASS. If `clean_code` says a count shrank, lock it in: `<Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd`, then check that the baseline diff only lowers numbers.

- [ ] **Step 6: Rebake and restart (controller)**

1. `test_run(suite="theme_rebake")`. This writes `Assets/Theme/kejartes_theme.tres`.
2. `git diff --stat Assets/Theme/kejartes_theme.tres` must show a large diff, and `grep -c "LippedStyleBox.gd" Assets/Theme/kejartes_theme.tres` must print 1.
3. Restart the worktree editor, which reloads the bake cold.
4. Run the full suite with `test_run()` (budget a bridge drop). Fix real breakage: any other suite that cast a button box to `StyleBoxFlat` or pinned the brown fill gets the same treatment as Step 2. Record each suite and change in the report.
5. `git status`; revert `Assets/Audio/default_bus_layout.tres`.

- [ ] **Step 7: Look at it (controller)**

Seed and teleport (CLAUDE.md "Working efficiently"): MainMenu, the Lobby, and StudentCard. Take one full-size screenshot each.

Check:
- every framed button shows a face on a darker lip with a gloss band, and no cream rim
- the Lobby's JADWAL! and Koperasi are mint, Inventory sky, Rapor sunflower with dark ink
- labels are centred on the face

Note anything clipped.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_lobby_style_buttons.gd tests/test_theme_factory.gd tests/test_button_geometry.gd tests/test_result_checkup.gd ci/clean_code_baseline.gd
git commit -m "feat(theme): every button is lipped, coloured by its role" -m "Mint is the main action everywhere, tomato danger, brown neutral, cream quiet; information badges keep their colours. EventSelectCard stays flat." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Include any other suite files changed in Step 6.

---

### Task 4: Sink-or-shrink and the press tick

**Files:**
- Create: `Scripts/Design/PressFeel.gd`
- Modify: `Scripts/Design/Juice.gd` (add `pop_release` after `release`), `Scripts/UI/UIPolish.gd` (`_on_button_down`, `_on_button_up`)
- Test: `tests/test_press_feel.gd`

**Interfaces:**
- Consumes: `LippedStyleBox`, `Haptics.buzz(duration_ms: int)`, and the `release_pop_*` tokens.
- Produces:
  - `class_name PressFeel`, with `const PRESS_TICK_MS := 8`, `const MAIN_ACTION_ROLES: Array[StringName]`, `static func sinks(normal: StyleBox) -> bool` and `static func ticks(variation: StringName) -> bool`
  - `Juice.pop_release(node: Control) -> Tween`

- [ ] **Step 1: Write the failing test**

Create `tests/test_press_feel.gd`:

```gdscript
@tool
extends McpTestSuite

## Press feel (2026-09-28 UI depth pass): a button on a LippedStyleBox sinks
## through its own pressed stylebox, so UIPolish must not also shrink it --
## it pops on release instead. Every other button keeps the shrink. Only the
## main-action roles tick the phone's motor. PressFeel holds both answers,
## pure; UIPolish is an autoload the editor never runs, so its wiring is
## checked by source.
##
## Must be @tool; no test here may be a coroutine.

const UIPOLISH_PATH := "res://Scripts/UI/UIPolish.gd"
const JUICE_PATH := "res://Scripts/Design/Juice.gd"

var _theme: Theme


func suite_name() -> String:
	return "press_feel"


func setup() -> void:
	_theme = ThemeFactory.build(DesignTokens.load_default())


func test_lipped_buttons_sink() -> void:
	for name in ["PrimaryButton", "SecondaryButton", "BookHeroButton", "FilterChipButton"]:
		assert_true(PressFeel.sinks(_theme.get_stylebox("normal", name)), name + " sinks")


func test_lipless_buttons_shrink() -> void:
	assert_false(PressFeel.sinks(_theme.get_stylebox("normal", "ShopHubTile")),
		"an empty tile has no lip to sink onto")
	assert_false(PressFeel.sinks(_theme.get_stylebox("normal", "EventSelectCard")),
		"a flat card shrinks")
	assert_false(PressFeel.sinks(null), "no stylebox, no sink")


func test_only_main_actions_tick() -> void:
	for name in [&"PrimaryButton", &"LobbyCtaButton", &"BookHeroButton", &"SuccessButton",
			&"DangerButton"]:
		assert_true(PressFeel.ticks(name), String(name) + " ticks")
	for name in [&"SecondaryButton", &"LobbyNavTile", &"FilterChipButton", &"", &"NavTileRapor"]:
		assert_false(PressFeel.ticks(name), String(name) + " stays silent")


func test_the_tick_is_haptics_tick_tier() -> void:
	assert_eq(PressFeel.PRESS_TICK_MS, 8, "Haptics' existing Tick tier")


func test_uipolish_uses_press_feel() -> void:
	var src := FileAccess.get_file_as_string(UIPOLISH_PATH)
	assert_contains(src, "Haptics.buzz(PressFeel.PRESS_TICK_MS)", "the tick")
	assert_contains(src, "PressFeel.ticks(", "only for main actions")
	assert_contains(src, "Juice.pop_release(", "lipped buttons pop on release")
	assert_contains(src, "PressFeel.sinks(", "sink or shrink is decided per button")


func test_pop_release_reads_its_tokens() -> void:
	var src := FileAccess.get_file_as_string(JUICE_PATH)
	assert_contains(src, "static func pop_release(", "Juice.pop_release exists")
	assert_contains(src, "release_pop_scale", "bumps to the token's scale")
	assert_contains(src, "release_pop_duration", "over the token's length")
```

- [ ] **Step 2: Run the test to verify it fails (controller)**

Scan, then `test_run(suite="press_feel")`. Expected: FAIL, because `PressFeel` is unknown.

- [ ] **Step 3: Implement**

Create `Scripts/Design/PressFeel.gd`:

```gdscript
@tool
class_name PressFeel
extends RefCounted

## Which press a button gets (2026-09-28 UI depth pass). A button resting on a
## LippedStyleBox sinks through its own pressed stylebox on the touch frame,
## so it must not also shrink -- it gets Juice.pop_release on letting go.
## Every other button keeps Juice.press/release. The main-action roles also
## tick the phone's motor (Haptics.buzz, which honours the Getar setting).
## Pure and static, so UIPolish and the tests share one answer.

## Length of the press tick, ms: Haptics' existing "Tick" tier.
const PRESS_TICK_MS := 8
## The only roles whose press vibrates -- the main action and affirm roles,
## the danger roles, and the notebook's close.
const MAIN_ACTION_ROLES: Array[StringName] = [
	&"BookHeroButton", &"LobbyCtaButton",
	&"PrimaryButton", &"PrimaryButtonM", &"PrimaryButtonL",
	&"SuccessButton", &"SuccessButtonL",
	&"DangerButton", &"DangerButtonM", &"DangerButtonL",
	&"NotebookClose",
]


## True when `normal` -- a button's resting stylebox -- has a lip to sink onto.
static func sinks(normal: StyleBox) -> bool:
	var lipped := normal as LippedStyleBox
	return lipped != null and lipped.lip_height > 0


## True when a button of theme variation `variation` ticks on press.
static func ticks(variation: StringName) -> bool:
	return MAIN_ACTION_ROLES.has(variation)
```

In `Scripts/Design/Juice.gd`, directly after `static func release(...)`'s body, add:

```gdscript


## A lipped button's release (2026-09-28 UI depth pass). Its pressed
## stylebox already sank it, so instead of springing back from a shrink it
## bumps to release_pop_scale and settles, over release_pop_duration.
static func pop_release(node: Control) -> Tween:
	if not _alive(node):
		return null
	var t := tokens()
	set_pivot_center(node)
	var half := t.release_pop_duration * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * t.release_pop_scale, half) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale", Vector2.ONE, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	return tw
```

In `Scripts/UI/UIPolish.gd`, replace `_on_button_down` and `_on_button_up` with:

```gdscript
func _on_button_down(button: BaseButton) -> void:
	if _skip(button):
		return
	if PressFeel.ticks(button.theme_type_variation):
		Haptics.buzz(PressFeel.PRESS_TICK_MS)
	# A lipped button sinks through its own pressed stylebox; shrinking it
	# too would pinch the lip it is sinking onto.
	if not _sinks(button):
		Juice.press(button)


func _on_button_up(button: BaseButton) -> void:
	if _skip(button):
		return
	if _sinks(button):
		Juice.pop_release(button)
	else:
		Juice.release(button)


## True when `button` rests on a LippedStyleBox (see PressFeel).
func _sinks(button: BaseButton) -> bool:
	return PressFeel.sinks(button.get_theme_stylebox(&"normal"))
```

- [ ] **Step 4: Run (controller)**

Do a no-op `script_patch` on `PressFeel.gd`, `Juice.gd` and `UIPolish.gd`, then `test_run` each of:
- `press_feel`
- `juice`
- `motion_adoption`
- `haptics`
- `script_documentation`
- `clean_code`

Expected: all PASS.

Then check it in the game:
1. Run the project and seed the playtest state.
2. In the Lobby, hold JADWAL! and take a screenshot with `Engine.time_scale = 0.02` inside one `game_eval`. The face should be down on the lip.
3. On desktop, the haptic pip flashes on JADWAL! and not on a Secondary button.
4. Stop the game.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/PressFeel.gd Scripts/Design/PressFeel.gd.uid Scripts/Design/Juice.gd Scripts/UI/UIPolish.gd tests/test_press_feel.gd tests/test_press_feel.gd.uid
git commit -m "feat(feel): lipped buttons sink and pop; main actions tick" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The 16 placeholder icons

**Files:**
- Create: `Assets/Images/UI/Icons/{nav_jadwal,nav_students,nav_koperasi,nav_inventory,nav_rapor,chevron_left,chevron_right,exit,close,home,info,music,sound,vibrate,cat_istirahat,cat_wirausaha}.svg`
- Create: `Assets/Images/UI/Icons/README.md`
- Test: `tests/test_ui_icons.gd`

**Interfaces:**
- Produces: `res://Assets/Images/UI/Icons/<name>.svg` for the 16 names. Task 6 uses `close.svg`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_ui_icons.gd`:

```gdscript
@tool
extends McpTestSuite

## The UI icon set (2026-09-28 UI depth pass): one file per job at a fixed
## path, so the owner's chunky set drops in with no code change. A
## replacement must read on BOTH the cream panels and the brown boards, which
## this checks the way the placeholders achieve it: a light fill AND a dark
## outline, on a transparent ground, at least 256 px.
## Rules for replacements: Assets/Images/UI/Icons/README.md.
##
## Must be @tool; no test here may be a coroutine.

const DIR := "res://Assets/Images/UI/Icons/"
const NAMES := [
	"nav_jadwal", "nav_students", "nav_koperasi", "nav_inventory", "nav_rapor",
	"chevron_left", "chevron_right", "exit", "close", "home",
	"info", "music", "sound", "vibrate", "cat_istirahat", "cat_wirausaha",
]
## Minimum side, px.
const MIN_SIDE := 256
## Luminance an opaque pixel must exceed to count as the light fill.
const LIGHT := 0.85
## Luminance an opaque pixel must stay under to count as the dark outline.
const DARK := 0.25


func suite_name() -> String:
	return "ui_icons"


func _image(name: String) -> Image:
	var tex := load(DIR + name + ".svg") as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func test_every_icon_exists_and_is_big_enough() -> void:
	for name in NAMES:
		var img := _image(name)
		assert_true(img != null, name + ".svg exists and imports")
		if img == null:
			continue
		assert_true(img.get_width() >= MIN_SIDE and img.get_height() >= MIN_SIDE,
			"%s is at least %d px" % [name, MIN_SIDE])


func test_every_icon_has_a_transparent_ground() -> void:
	for name in NAMES:
		var img := _image(name)
		if img == null:
			continue
		assert_true(img.get_pixel(0, 0).a < 0.1, name + " has a transparent corner")


func test_every_icon_reads_on_cream_and_on_brown() -> void:
	for name in NAMES:
		var img := _image(name)
		if img == null:
			continue
		var has_light := false
		var has_dark := false
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var p := img.get_pixel(x, y)
				if p.a < 0.9:
					continue
				has_light = has_light or p.get_luminance() > LIGHT
				has_dark = has_dark or p.get_luminance() < DARK
		assert_true(has_light, name + " has a light fill (reads on brown)")
		assert_true(has_dark, name + " has a dark outline (reads on cream)")
```

- [ ] **Step 2: Run to verify it fails (controller)**

Scan, then `test_run(suite="ui_icons")`. Expected: FAIL, because no files exist.

- [ ] **Step 3: Write the icons**

Every file uses this wrapper, with `BODY` replaced per icon:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
BODY
</g>
</svg>
```

| File | BODY |
|---|---|
| `nav_jadwal.svg` | `<rect x="36" y="52" width="184" height="168" rx="28"/><path d="M36 104h184" fill="none"/><path d="M84 32v40M172 32v40" fill="none"/><rect x="76" y="136" width="36" height="32" rx="6" fill="#3B2412" stroke="none"/><rect x="144" y="136" width="36" height="32" rx="6" fill="#3B2412" stroke="none"/>` |
| `nav_students.svg` | `<circle cx="128" cy="84" r="44"/><path d="M48 220c0-48 36-80 80-80s80 32 80 80z"/>` |
| `nav_koperasi.svg` | `<path d="M40 104l20-60h136l20 60z"/><rect x="52" y="104" width="152" height="112" rx="12"/><rect x="104" y="148" width="48" height="68" rx="8"/>` |
| `nav_inventory.svg` | `<path d="M44 96h168l-12 124H56z"/><path d="M92 96V76a36 36 0 0 1 72 0v20" fill="none"/>` |
| `nav_rapor.svg` | `<path d="M64 28h96l40 40v160H64z"/><path d="M92 112h72M92 148h72M92 184h48" fill="none"/>` |
| `chevron_left.svg` | `<path d="M164 36L72 128l92 92 28-28-64-64 64-64z"/>` |
| `chevron_right.svg` | `<path d="M92 36l92 92-92 92-28-28 64-64-64-64z"/>` |
| `exit.svg` | `<rect x="40" y="36" width="104" height="184" rx="16"/><path d="M120 128h96M184 92l36 36-36 36" fill="none"/>` |
| `close.svg` | `<path d="M72 44l56 56 56-56 28 28-56 56 56 56-28 28-56-56-56 56-28-28 56-56-56-56z"/>` |
| `home.svg` | `<path d="M128 36L28 124h32v96h52v-60h32v60h52v-96h32z"/>` |
| `info.svg` | `<circle cx="128" cy="128" r="96"/><circle cx="128" cy="80" r="14" fill="#3B2412" stroke="none"/><path d="M128 116v76" stroke-width="24" fill="none"/>` |
| `music.svg` | `<circle cx="72" cy="188" r="32"/><circle cx="184" cy="164" r="32"/><path d="M104 188V64l112-28v128" fill="none"/>` |
| `sound.svg` | `<path d="M36 100h44l56-48v152l-56-48H36z"/><path d="M168 96a44 44 0 0 1 0 64M192 68a84 84 0 0 1 0 120" fill="none"/>` |
| `vibrate.svg` | `<rect x="80" y="36" width="96" height="184" rx="18"/><path d="M40 92v72M216 92v72" fill="none"/>` |
| `cat_istirahat.svg` | `<path d="M168 40a96 96 0 1 0 60 140A80 80 0 0 1 168 40z"/>` |
| `cat_wirausaha.svg` | `<path d="M100 44h56l-16 32c44 16 76 60 76 100 0 32-28 48-88 48s-88-16-88-48c0-40 32-84 76-100z"/><path d="M104 76h48" fill="none"/>` |

Create `Assets/Images/UI/Icons/README.md`:

```markdown
# UI icons

One file per job, at a fixed path. Scenes point at these paths, so a
replacement drops in with no code change. The current files are
placeholders (2026-09-28, UI depth pass) waiting for the owner's chunky set.

A replacement must:

- keep its file name (SVG, or PNG at the same base name — update the
  scene reference if the extension changes);
- have a transparent background;
- be at least 256 px (SVG imports at its viewBox size);
- read on both the cream panels and the brown boards: a light fill and a
  dark outline, like the placeholders;
- show one subject, roughly centred.

`tests/test_ui_icons.gd` checks the size, the transparent corner and the
light-fill-plus-dark-outline rule.
```

- [ ] **Step 4: Run (controller)**

`filesystem_manage(op="scan")`, then `test_run(suite="ui_icons")`. Expected: 3/3 PASS.

- [ ] **Step 5: Commit**

```bash
git add Assets/Images/UI/Icons tests/test_ui_icons.gd tests/test_ui_icons.gd.uid
git commit -m "feat(icons): 16 placeholder UI icons at fixed paths" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `NotebookFrame`

**Files:**
- Create: `Assets/Images/UI/Notebook/{spiral_ring,paper_rule,sticker_stitch}.png` and `README.md`
- Modify: `Scripts/Design/ThemeFactory.gd`. Add `_build_notebook` and call it from `build()` right after `_build_buttons(theme, tokens)`.
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`), `tests/test_button_geometry.gd` (`RADIUS_EXEMPT`), `tests/test_press_feel.gd` (append)
- Create: `Scripts/UI/NotebookFrame.gd`, `Scenes/UI/NotebookFrame.tscn`
- Test: `tests/test_notebook_frame.gd`

**Interfaces:**
- Consumes: `_add_button_variation`, `_set_content_margins`, `LippedStyleBox`, and `close.svg` (Task 5).
- Produces:
  - theme types: `NotebookCover`, `NotebookPage` (Panel); `NotebookTab`, `NotebookTabActive`, `NotebookClose` (Button); `NotebookSticker` (Label)
  - `class_name NotebookFrame extends Container`, with:
    - signals `tab_selected(index: int)` and `close_pressed`
    - exports `title_text: String`, `tabs: PackedStringArray`, `active_tab: int`, `ring_count: int`, `show_well: bool`, `show_tape: bool`, `tape_color: Color`, `show_close: bool`, `content_padding: Vector4i`
    - `func content_rect() -> Rect2`, `func sort_now() -> void`
    - consts `MAX_TABS := 3`, `MAX_RINGS := 8`, `CHROME_META := &"notebook_chrome"`

- [ ] **Step 1: Generate the textures (implementer)**

Run from the worktree root:

```bash
mkdir -p Assets/Images/UI/Notebook
python - <<'EOF'
from PIL import Image, ImageDraw
d = "Assets/Images/UI/Notebook/"
# spiral_ring.png: a chunky wire loop, light on top, dark underside (72x32).
ring = Image.new("RGBA", (72, 32), (0, 0, 0, 0))
g = ImageDraw.Draw(ring)
g.rounded_rectangle((2, 8, 70, 30), 11, fill=(107, 98, 90, 255))
g.rounded_rectangle((2, 2, 70, 24), 11, fill=(158, 150, 140, 255))
g.rounded_rectangle((6, 4, 66, 13), 6, fill=(255, 255, 255, 255))
ring.save(d + "spiral_ring.png")
# paper_rule.png: a tileable 16x58 strip, two faint rules on transparent.
rule = Image.new("RGBA", (16, 58), (0, 0, 0, 0))
g = ImageDraw.Draw(rule)
g.rectangle((0, 27, 15, 28), fill=(243, 228, 205, 255))
g.rectangle((0, 56, 15, 57), fill=(243, 228, 205, 255))
rule.save(d + "paper_rule.png")
# sticker_stitch.png: a 9-slice cream sticker with a dashed stitch (96x96).
st = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
g = ImageDraw.Draw(st)
g.rounded_rectangle((0, 4, 95, 95), 20, fill=(226, 204, 167, 255))
g.rounded_rectangle((0, 0, 95, 91), 20, fill=(255, 233, 194, 255))
for x in range(22, 74, 16):
    g.rectangle((x, 6, x + 9, 9), fill=(201, 165, 126, 255))
    g.rectangle((x, 82, x + 9, 85), fill=(201, 165, 126, 255))
for y in range(22, 70, 16):
    g.rectangle((6, y, 9, y + 9), fill=(201, 165, 126, 255))
    g.rectangle((86, y, 89, y + 9), fill=(201, 165, 126, 255))
st.save(d + "sticker_stitch.png")
print("ok")
EOF
```

Create `Assets/Images/UI/Notebook/README.md`:

```markdown
# Notebook frame textures

Placeholders (2026-09-28, UI depth pass), generated with Pillow. They are
drop-replaceable at the same path; `Scenes/UI/NotebookFrame.tscn` uses them.

| File | Size | Notes |
|---|---|---|
| `spiral_ring.png` | 72x32 | One wire loop; the frame shows up to 8 down the page's left edge. |
| `paper_rule.png` | 16x58 | Tiles in both directions over the page (`TextureRect` stretch TILE). Keep the rule spacing 29 px and the ground transparent. |
| `sticker_stitch.png` | 96x96 | 9-slice with 28 px patch margins on every side; the dashed stitch must stay outside the middle. |

The washi tape reuses `Assets/Images/AturJadwal/washi_tape.svg`, tinted by
the frame's `tape_color`.
```

- [ ] **Step 2: Write the failing tests**

Append to `tests/test_press_feel.gd`:

```gdscript


func test_every_main_action_role_is_a_theme_variation() -> void:
	var types := _theme.get_type_list()
	for name in PressFeel.MAIN_ACTION_ROLES:
		assert_true(types.has(String(name)), String(name) + " is built by ThemeFactory")
```

In `tests/test_theme_factory.gd`, add `"NotebookTab", "NotebookTabActive", "NotebookClose", "NotebookSticker",` to `DISPLAY_ROSTER`.

In `tests/test_button_geometry.gd`, add to `RADIUS_EXEMPT`:

```gdscript
	"NotebookClose":
		"the notebook frame's fixed 96px corner button; radius_pill makes it a circle",
```

Create `tests/test_notebook_frame.gd`:

```gdscript
@tool
extends McpTestSuite

## NotebookFrame (2026-09-28 UI depth pass): the popup frame every popup
## moves into in Phase 2. Its decoration lives under one Chrome node, authored
## in the .tscn and kept full-size and behind; any other child is host
## content, laid into the page by sort_now(). Tabs and rings are authored,
## only shown or hidden -- never built at runtime.
##
## Must be @tool; no test here may be a coroutine.

const SCENE := "res://Scenes/UI/NotebookFrame.tscn"
const SCRIPT_PATH := "res://Scripts/UI/NotebookFrame.gd"
## Test frame size, px.
const FRAME_SIZE := Vector2(800, 900)


func suite_name() -> String:
	return "notebook_frame"


func _frame() -> NotebookFrame:
	var frame := load(SCENE).instantiate() as NotebookFrame
	track(frame)
	frame.size = FRAME_SIZE
	return frame


func test_host_content_lands_inside_the_page() -> void:
	var frame := _frame()
	var host := Control.new()
	frame.add_child(host)
	frame.sort_now()
	var r := frame.content_rect()
	assert_eq(host.position, r.position, "content starts at the padded corner")
	assert_eq(host.size, r.size, "and fills the padded page")
	assert_true(Rect2(Vector2.ZERO, FRAME_SIZE).encloses(r), "inside the frame")


func test_the_decoration_is_full_size_and_behind() -> void:
	var frame := _frame()
	frame.sort_now()
	var chrome := frame.get_child(0) as Control
	assert_eq(chrome.name, &"Chrome", "the decoration is the first child, drawn first")
	assert_true(chrome.has_meta(NotebookFrame.CHROME_META), "and is marked as chrome")
	assert_eq(chrome.size, FRAME_SIZE, "it spans the whole frame")


func test_tabs_follow_the_export() -> void:
	var frame := _frame()
	frame.tabs = PackedStringArray(["SUARA", "MAIN"])
	frame.active_tab = 0
	var tab0 := frame.get_node("Chrome/Tabs/Tab0") as Button
	var tab1 := frame.get_node("Chrome/Tabs/Tab1") as Button
	var tab2 := frame.get_node("Chrome/Tabs/Tab2") as Button
	assert_true(tab0.visible and tab0.text == "SUARA", "first tab shows its name")
	assert_eq(tab0.theme_type_variation, &"NotebookTabActive", "the active tab is gold")
	assert_eq(tab1.theme_type_variation, &"NotebookTab", "the other is sky")
	assert_false(tab2.visible, "an unused tab hides")
	frame.tabs = PackedStringArray()
	assert_false((frame.get_node("Chrome/Tabs") as Control).visible, "no tabs, no strip")


func test_rings_well_tape_and_close_follow_the_exports() -> void:
	var frame := _frame()
	frame.ring_count = 4
	for i in NotebookFrame.MAX_RINGS:
		assert_eq((frame.get_node("Chrome/Rings/Ring%d" % i) as CanvasItem).visible, i < 4,
			"ring %d" % i)
	frame.show_well = false
	frame.show_tape = false
	frame.show_close = false
	assert_false((frame.get_node("Chrome/Well") as CanvasItem).visible, "well hides")
	assert_false((frame.get_node("Chrome/Tape") as CanvasItem).visible, "tape hides")
	assert_false((frame.get_node("Chrome/Close") as CanvasItem).visible, "close hides")


func test_the_title_reaches_the_sticker() -> void:
	var frame := _frame()
	frame.title_text = "PENGATURAN"
	assert_eq((frame.get_node("Chrome/Sticker/Title") as Label).text, "PENGATURAN")


func test_tab_and_close_presses_become_signals() -> void:
	var frame := _frame()
	frame.tabs = PackedStringArray(["SUARA", "MAIN"])
	var got := []
	frame.tab_selected.connect(func(i: int) -> void: got.append(i))
	frame.close_pressed.connect(func() -> void: got.append("close"))
	(frame.get_node("Chrome/Tabs/Tab1") as Button).pressed.emit()
	(frame.get_node("Chrome/Close") as Button).pressed.emit()
	assert_eq(got, [1, "close"], "tab 1 then close")
	assert_eq(frame.active_tab, 1, "the pressed tab becomes active")


func test_nothing_is_built_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains(".new()"), "every node is authored in the .tscn")
```

- [ ] **Step 3: Run to verify they fail (controller)**

Scan, then `test_run` for `notebook_frame`, `press_feel`, `theme_factory` and `button_geometry`.
Expected: FAIL (the scene, class and variations are missing).

- [ ] **Step 4: Add the theme variations**

In `ThemeFactory.gd`:
- In `build()`, after `_build_buttons(theme, tokens)`, add `_build_notebook(theme, tokens)`.
- Add these near the lobby-HUD section:

```gdscript
# ---------------------------------------------------------------- notebook

## The notebook cover's lip, px: a board, thicker than a button's.
const NOTEBOOK_COVER_LIP := 12
## The page's lip, px: its two paper edges.
const NOTEBOOK_PAGE_LIP := 8


## The notebook popup frame's surfaces (2026-09-28 UI depth pass): a brown
## hardcover on a lip, a cream page on paper edges, sky and gold tabs, a
## tomato round close and the stitched sticker's title.
static func _build_notebook(theme: Theme, tokens: DesignTokens) -> void:
	for spec in [
		["NotebookCover", tokens.brand_primary_light, tokens.brand_primary_dark,
			NOTEBOOK_COVER_LIP, tokens.radius_lg, true],
		["NotebookPage", tokens.outline_card, tokens.surface_sunken,
			NOTEBOOK_PAGE_LIP, tokens.radius_md, false],
	]:
		theme.add_type(spec[0])
		theme.set_type_variation(spec[0], "Panel")
		theme.set_stylebox("panel", spec[0],
			_notebook_panel(tokens, spec[1], spec[2], spec[3], spec[4], spec[5]))

	_add_button_variation(theme, tokens, "NotebookTab", tokens.accent_sky, tokens.accent_sky_lip)
	_add_button_variation(theme, tokens, "NotebookTabActive",
		tokens.accent_sunflower, tokens.accent_sunflower_lip)
	_add_button_variation(theme, tokens, "NotebookClose",
		tokens.accent_tomato, tokens.accent_tomato_lip, tokens.radius_pill)
	_set_content_margins(theme, "NotebookClose", tokens.space_sm, tokens.btn_pad_v_s)
	theme.set_constant("icon_max_width", "NotebookClose", tokens.btn_icon_s)

	theme.add_type("NotebookSticker")
	theme.set_type_variation("NotebookSticker", "Label")
	theme.set_font_size("font_size", "NotebookSticker", tokens.font_h2)
	theme.set_color("font_color", "NotebookSticker", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "NotebookSticker", tokens.font_display)


## A gloss-less lipped panel for the notebook's cover or page.
static func _notebook_panel(tokens: DesignTokens, face: Color, lip: Color,
		lip_height: int, radius: int, shadow: bool) -> LippedStyleBox:
	var sb := LippedStyleBox.new()
	sb.bg_color = face
	sb.lip_color = lip
	sb.lip_height = lip_height
	sb.corner_radius = radius
	if shadow:
		sb.shadow_color = tokens.shadow_color
		sb.shadow_size = tokens.shadow_size
		sb.shadow_offset = tokens.shadow_offset
	return sb
```

- [ ] **Step 5: Write `NotebookFrame.gd` (implementer)**

Create `Scripts/UI/NotebookFrame.gd`:

```gdscript
@tool
class_name NotebookFrame
extends Container

## The notebook popup frame (2026-09-28 UI depth pass;
## docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md). A brown
## hardcover on a lip, a ruled cream page with spiral rings, up to three
## tabs, a stitched sticker title, washi tape and a round close.
##
## Host content: drop your nodes in as children of the frame. Every child
## except the Chrome node is laid into content_rect(); Chrome -- the
## decoration, authored in NotebookFrame.tscn -- stays full-size and, being
## the first child, behind. A dialog is the same frame with no tabs, four
## rings and no well. Nothing here is built at runtime: the three tabs and
## eight rings exist in the scene and are only shown or hidden.

## Emitted when tab `index` is pressed; it has already become active.
signal tab_selected(index: int)
## Emitted when the round close button is pressed.
signal close_pressed

## Most tabs the frame carries: Tab0..Tab2 in the scene.
const MAX_TABS := 3
## Most rings the frame carries: Ring0..Ring7 in the scene.
const MAX_RINGS := 8
## Rings shown by default.
const DEFAULT_RINGS := 7
## Space around the host content by default: left, top, right, bottom, px.
## The left clears the rings and margin line, the top the sticker.
const DEFAULT_PADDING := Vector4i(72, 120, 40, 48)
## How far the sunken well reaches past the content on each side, px.
const WELL_BLEED := 16
## Meta key on the decoration node, which sort_now() keeps full-size.
const CHROME_META := &"notebook_chrome"
## The washi tape's default tint: sunflower, a little see-through.
const DEFAULT_TAPE := Color("FFC93CCC")

## The title on the stitched sticker.
@export var title_text: String = "":
	set(value):
		title_text = value
		_refresh()
## Tab names, left to right; up to MAX_TABS are shown. Empty hides the strip.
@export var tabs: PackedStringArray = PackedStringArray():
	set(value):
		tabs = value
		_refresh()
## Index of the active, gold tab.
@export var active_tab: int = 0:
	set(value):
		active_tab = value
		_refresh()
## How many spiral rings show down the page's left edge.
@export_range(0, MAX_RINGS) var ring_count: int = DEFAULT_RINGS:
	set(value):
		ring_count = value
		_refresh()
## Whether the host content sits in a sunken well.
@export var show_well: bool = true:
	set(value):
		show_well = value
		_refresh()
## Whether a strip of washi tape pins the bottom-left corner.
@export var show_tape: bool = true:
	set(value):
		show_tape = value
		_refresh()
## The washi tape's tint.
@export var tape_color: Color = DEFAULT_TAPE:
	set(value):
		tape_color = value
		_refresh()
## Whether the round close button shows on the top-right corner.
@export var show_close: bool = true:
	set(value):
		show_close = value
		_refresh()
## Space between the frame's edges and the host content: x left, y top,
## z right, w bottom, px.
@export var content_padding: Vector4i = DEFAULT_PADDING:
	set(value):
		content_padding = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_wire()
		_refresh()
	elif what == NOTIFICATION_SORT_CHILDREN:
		sort_now()


## Where host content goes, in the frame's own coordinates.
func content_rect() -> Rect2:
	var pad := content_padding
	return Rect2(Vector2(pad.x, pad.y), size - Vector2(pad.x + pad.z, pad.y + pad.w))


## Lay out every child now: Chrome over the whole frame, host content into
## content_rect(), and the well around it.
func sort_now() -> void:
	for child in get_children():
		var control := child as Control
		if control == null:
			continue
		if control.has_meta(CHROME_META):
			fit_child_in_rect(control, Rect2(Vector2.ZERO, size))
		else:
			fit_child_in_rect(control, content_rect())
	var well := get_node_or_null("Chrome/Well") as Control
	if well != null:
		var r := content_rect().grow(WELL_BLEED)
		well.position = r.position
		well.size = r.size


func _wire() -> void:
	for i in MAX_TABS:
		_tab(i).pressed.connect(_on_tab_pressed.bind(i))
	(get_node("Chrome/Close") as Button).pressed.connect(_on_close_pressed)


func _refresh() -> void:
	if get_node_or_null("Chrome") == null:
		return
	(get_node("Chrome/Sticker/Title") as Label).text = title_text
	(get_node("Chrome/Tabs") as Control).visible = not tabs.is_empty()
	for i in MAX_TABS:
		var tab := _tab(i)
		tab.visible = i < tabs.size()
		if tab.visible:
			tab.text = tabs[i]
			tab.theme_type_variation = &"NotebookTabActive" if i == active_tab else &"NotebookTab"
	for i in MAX_RINGS:
		(get_node("Chrome/Rings/Ring%d" % i) as CanvasItem).visible = i < ring_count
	(get_node("Chrome/Well") as CanvasItem).visible = show_well
	var tape := get_node("Chrome/Tape") as CanvasItem
	tape.visible = show_tape
	tape.self_modulate = tape_color
	(get_node("Chrome/Close") as CanvasItem).visible = show_close
	queue_sort()


func _tab(index: int) -> Button:
	return get_node("Chrome/Tabs/Tab%d" % index) as Button


func _on_tab_pressed(index: int) -> void:
	active_tab = index
	tab_selected.emit(index)


func _on_close_pressed() -> void:
	close_pressed.emit()
```

- [ ] **Step 6: Author `NotebookFrame.tscn` (implementer, editor closed)**

The scene is new, so no editor holds it in memory. The controller **closes the worktree editor** before this step and scans after. Create `Scenes/UI/NotebookFrame.tscn`:

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://Scripts/UI/NotebookFrame.gd" id="1_frame"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Notebook/spiral_ring.png" id="2_ring"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Notebook/paper_rule.png" id="3_rule"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Notebook/sticker_stitch.png" id="4_sticker"]
[ext_resource type="Texture2D" path="res://Assets/Images/AturJadwal/washi_tape.svg" id="5_tape"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Icons/close.svg" id="6_close"]

[node name="NotebookFrame" type="Container"]
custom_minimum_size = Vector2(640, 520)
offset_right = 800.0
offset_bottom = 900.0
script = ExtResource("1_frame")

[node name="Chrome" type="Control" parent="."]
layout_mode = 2
mouse_filter = 2
metadata/notebook_chrome = true

[node name="Cover" type="Panel" parent="Chrome"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -12.0
offset_top = -12.0
offset_right = 20.0
offset_bottom = 24.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_type_variation = &"NotebookCover"

[node name="Tabs" type="HBoxContainer" parent="Chrome"]
layout_mode = 0
offset_left = 72.0
offset_top = -60.0
offset_right = 640.0
offset_bottom = 36.0
theme_override_constants/separation = 12

[node name="Tab0" type="Button" parent="Chrome/Tabs"]
layout_mode = 2
theme_type_variation = &"NotebookTabActive"
text = "TAB"

[node name="Tab1" type="Button" parent="Chrome/Tabs"]
layout_mode = 2
theme_type_variation = &"NotebookTab"
text = "TAB"

[node name="Tab2" type="Button" parent="Chrome/Tabs"]
layout_mode = 2
theme_type_variation = &"NotebookTab"
text = "TAB"

[node name="Page" type="Panel" parent="Chrome"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_type_variation = &"NotebookPage"

[node name="Rules" type="TextureRect" parent="Chrome"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 48.0
offset_top = 24.0
offset_right = -16.0
offset_bottom = -24.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("3_rule")
expand_mode = 1
stretch_mode = 1

[node name="MarginLine" type="ColorRect" parent="Chrome"]
layout_mode = 1
anchors_preset = 9
anchor_bottom = 1.0
offset_left = 44.0
offset_top = 12.0
offset_right = 47.0
offset_bottom = -20.0
grow_vertical = 2
mouse_filter = 2
color = Color(0.94902, 0.627451, 0.556863, 1)

[node name="Well" type="Panel" parent="Chrome"]
layout_mode = 0
mouse_filter = 2
theme_type_variation = &"SunkenPanel"

[node name="Rings" type="VBoxContainer" parent="Chrome"]
layout_mode = 1
anchors_preset = 9
anchor_bottom = 1.0
offset_left = -22.0
offset_top = 48.0
offset_right = 50.0
offset_bottom = -48.0
grow_vertical = 2
mouse_filter = 2
theme_override_constants/separation = 40
alignment = 1

[node name="Ring0" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring1" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring2" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring3" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring4" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring5" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring6" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Ring7" type="TextureRect" parent="Chrome/Rings"]
layout_mode = 2
mouse_filter = 2
texture = ExtResource("2_ring")

[node name="Sticker" type="NinePatchRect" parent="Chrome"]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -180.0
offset_top = 20.0
offset_right = 180.0
offset_bottom = 92.0
grow_horizontal = 2
rotation = -0.0349066
pivot_offset = Vector2(180, 36)
mouse_filter = 2
texture = ExtResource("4_sticker")
patch_margin_left = 28
patch_margin_top = 28
patch_margin_right = 28
patch_margin_bottom = 28

[node name="Title" type="Label" parent="Chrome/Sticker"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"NotebookSticker"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Tape" type="TextureRect" parent="Chrome"]
layout_mode = 1
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = -24.0
offset_top = -40.0
offset_right = 116.0
offset_bottom = 4.0
grow_vertical = 0
rotation = -0.418879
pivot_offset = Vector2(70, 22)
mouse_filter = 2
texture = ExtResource("5_tape")
expand_mode = 1

[node name="Close" type="Button" parent="Chrome"]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -60.0
offset_top = -36.0
offset_right = 36.0
offset_bottom = 60.0
grow_horizontal = 0
theme_type_variation = &"NotebookClose"
icon = ExtResource("6_close")
icon_alignment = 1
expand_icon = true
```

- [ ] **Step 7: Import, stamp uids, run (controller)**

1. Relaunch the worktree editor and `filesystem_manage(op="scan")`.
2. `scene_open("res://Scenes/UI/NotebookFrame.tscn")` then `scene_save()`. This writes the `uid=` into each `ext_resource`.
3. `git diff HEAD -- '*.gd'` must show only intended files.
4. Do a no-op `script_patch` on `NotebookFrame.gd` and `ThemeFactory.gd`.
5. `test_run` each of:
   - `notebook_frame`, `press_feel`, `theme_factory`, `button_geometry`
   - `viewport_editability`, `script_documentation`, `clean_code`

   Expected: all PASS.
6. `test_run(suite="theme_rebake")`, then restart the editor.
7. `editor_screenshot(source="viewport_2d")` with `NotebookFrame.tscn` open, `title_text` "PENGATURAN" and `tabs` ["SUARA", "MAIN"] set in the inspector. **Do not save that scene afterwards.** Check it against `docs/superpowers/specs/mockups/ui-depth-pass/3-notebook-frame.html`: cover lip, page edges, rings, tabs, sticker, tape, close.

- [ ] **Step 8: Commit**

```bash
git add Assets/Images/UI/Notebook Scripts/UI/NotebookFrame.gd Scripts/UI/NotebookFrame.gd.uid Scenes/UI/NotebookFrame.tscn Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_notebook_frame.gd tests/test_notebook_frame.gd.uid tests/test_press_feel.gd tests/test_theme_factory.gd tests/test_button_geometry.gd
git commit -m "feat(ui): NotebookFrame, the popup frame Phase 2 builds on" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Docs, full verification, ship

**Files:**
- Modify: `docs/superpowers/design/style-guide.md`, `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`, `CLAUDE.md`

- [ ] **Step 1: Style guide (implementer)**

In `docs/superpowers/design/style-guide.md`, replace the paragraph under **Buttons** that begins "Since the 2026-09-14 lobby-style-buttons pass, every framed action button wears the Lobby's look…" with:

```markdown
Since the 2026-09-28 UI depth pass every framed button is a
`LippedStyleBox` (`Scripts/Design/LippedStyleBox.gd`): a face on a solid
darker lip with a white gloss band, sinking onto the lip when held (its
`pressed` state), with no rim. Its colours say its role — mint is the main
action and affirm on every screen, tomato is danger, brown is neutral,
cream is quiet; sky and sunflower belong to the Lobby tiles and the
notebook tabs, and sunflower is never an action (gold reads as "buy").
Information badges keep their meaning colours. The palette pairs are the
`accent_*` / `button_cream*` tokens. Labels on a dark face are outlined
white; on a light face they are plain dark ink. `EventSelectCard` stays a
flat box, because its pressed state means *selected*.
```

Then add a section before `## The Juice API`:

```markdown
## The notebook frame

Popups sit in `Scenes/UI/NotebookFrame.tscn`: drop your content in as
children of the frame and it lays them into the page. Set `title_text`,
`tabs` (up to three), `ring_count`, `show_well`, `show_tape` and
`show_close` on the instance's root, and listen to `tab_selected` /
`close_pressed`. A dialog is the same frame with no tabs, four rings and no
well. The ring, rule and sticker textures are placeholders
(`Assets/Images/UI/Notebook/README.md`).
```

- [ ] **Step 2: DEBT and CHANGELOG (implementer)**

In `docs/superpowers/DEBT.md`, under `## Placeholder art`, **Generated placeholder art**, add this item to the list:

```
the 16 UI icons in `Assets/Images/UI/Icons/` (placeholders for the owner's
chunky set; rules in that folder's README, pinned by `test_ui_icons`), the
notebook frame's `spiral_ring.png`, `paper_rule.png` and
`sticker_stitch.png` (`Assets/Images/UI/Notebook/README.md`),
```

Under `## Deferred and pending`, add:

```markdown
**UI depth pass, Phases 2–3 (2026-09-28).** Phase 1 made every button
lipped and shipped `NotebookFrame` and the placeholder icons. Phase 2 moves
every popup into the frame; Phase 3 is the screen-by-screen icon and role
pass, the Lobby tiles' icons included. Spec:
`docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md`.
```

At the top of `docs/superpowers/CHANGELOG.md` (newest first), add:

```markdown
## 2026-09-28 — UI depth pass, Phase 1: lipped buttons

Plan: `docs/superpowers/plans/2026-09-28-ui-depth-pass-phase1.md`.

Every framed button is now a `LippedStyleBox` — a face on a darker lip with
a gloss band and no rim — coloured by its role: mint for the main action on
every screen (matching the Lobby's green JADWAL!), tomato for danger, brown
neutral, cream quiet. Held, a button sinks onto its lip through its pressed
stylebox and pops on release (`Juice.pop_release`); main actions also tick
the motor (`PressFeel`, 8 ms, honouring Getar). The scrapbook Lobby keeps
its layout and gets the same surface. New for Phase 2: `NotebookFrame`, and
16 placeholder icons at fixed paths for the owner's set.
```

- [ ] **Step 3: CLAUDE.md (implementer)**

In `CLAUDE.md` `## Visual system`, after the paragraph that ends "Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).", add:

```markdown
**Buttons are lipped** (`LippedStyleBox`): the role decides the colour, and
mint is the main action on every screen, never gold. **Popups sit in
`NotebookFrame`.** Both: style guide.
```

In `## Current work`, replace the text with:

```markdown
UI depth pass, Phases 2–3 (popups into `NotebookFrame`; the screen pass):
spec docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md. Phase 1
(lipped buttons) is on `feat/ui-depth-pass`.
```

- [ ] **Step 4: Full suite and the count (controller)**

1. Open `Scenes/MainMenu/MainMenu.tscn`, then run a full `test_run()` (budget a restart).
2. Fix real breakage; record it.
3. Update the `## Testing` count line in `CLAUDE.md` to the run's `<suites> suites, <tests> tests (2026-09-28)`.
4. `git status`: revert `Assets/Audio/default_bus_layout.tres`, and keep `kejartes_theme.tres` only if it matches the last intended rebake.
5. Lock in any clean-code shrink with `ci/clean_code_dump.gd`.

- [ ] **Step 5: Screenshots (controller)**

Seed and teleport. Take full-size screenshots at 9:16 of MainMenu, the Lobby, StudentCard, StudentList, AturJadwal (after a pass through it), Koperasi and ResultCheckup (Debug > Scenes > Laporan Mingguan). Take one 20:9 (1080×2400) Lobby shot as well.

Check: lipped buttons, role colours, labels centred, and nothing clipped by the pressed shift. Put anything off in the PR as known follow-ups for Phase 3; fix it now only if it is broken, not merely unpolished.

- [ ] **Step 6: Commit and ship**

```bash
git add docs/superpowers/design/style-guide.md docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md CLAUDE.md ci/clean_code_baseline.gd
git commit -m "docs(ui): depth pass Phase 1 in the style guide, debt and changelog" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then finish the branch with the `ship-pr` skill.
