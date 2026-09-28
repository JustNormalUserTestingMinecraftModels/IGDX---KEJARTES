# Lomba Menari Note Arrow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Lomba Menari's text-glyph note arrows (`←` `→` `↖` `↗` typed into a runtime `Label` over a code-drawn coloured box) with one real, chunky arrow texture that is turned and tinted per lane.

**Architecture:** One right-pointing arrow PNG (white fill, dark outline) lives in a new `MenariNote.tscn` template: a `Control` root plus an `Arrow` `TextureRect` child. `LombaMenari.gd` instances the template instead of building a `TextureRect` + `Label`. It turns the `Arrow` child to the lane's direction (reusing the existing `ARROW_DIRECTIONS` table) and tints it with the lane's existing `*_note_color` export through `self_modulate`. The root keeps the breathing sway `rotation` it already gets every frame, and the child carries the direction, so the two never fight. The eight unused per-direction texture exports are deleted.

**Tech Stack:** Godot 4.6 GDScript, Godot AI MCP (`test_run`, `scene_manage`, `node_create`, `node_set_property`, `scene_save`, `script_patch`, `filesystem_manage`), Python 3 + Pillow 12 (one-off asset recolour).

## Global Constraints

- Tests are `McpTestSuite` suites in `tests/test_*.gd`. They must be `@tool`, and **no test may be a coroutine** (no `await`). Run them only through the Godot AI MCP `test_run` tool, never headless.
- **Never hand-edit a `.tscn` while the editor is attached.** Build scenes through `scene_manage` / `node_create` / `node_set_property` / `scene_save`.
- **Do scene work first and script work second.** `scene_save` writes stale script tabs back to disk. After every `scene_save`, run `git diff HEAD -- '*.gd'` and restore any `.gd` you did not mean to change.
- Edit `.gd` files through `script_patch`, so the editor reloads them. After any outside edit to a `.gd`, do a no-op `script_patch` on that file before `test_run`.
- Every script keeps a `##` file header, and every `@export` keeps a `##` doc line (`tests/test_script_documentation.gd`).
- Runtime visual construction is ratcheted per file (`tests/test_viewport_editability.gd`). A conversion that lowers a file's count must lower its `BASELINE` literal in the same commit.
- Commits use Conventional Commits with a scope (`feat(menari): …`) and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Minigames sit outside the design system (`ThemeFactory` / tokens), so lane colours stay `@export`s on the minigame, as today.
- Work happens in the worktree `.claude/worktrees/menari-note-arrow` on branch `feat/menari-note-arrow`, with its own Godot editor (godot-ai session `menari-note-arrow@…`). Pass that `session_id` on every godot-ai call; the main checkout is shared with other sessions.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `Assets/Images/Minigames/SeniBudaya/note_arrow.png` | Create | The note art: 512×512, points **right**, white fill (so a tint shows true), dark outline. Drop-replaceable at this path. |
| `Scenes/Minigames/SeniBudaya/MenariNote.tscn` | Create | The note template: `MenariNote` (Control) → `Arrow` (TextureRect, full rect). |
| `Scripts/Minigames/SeniBudaya/LombaMenari.gd` | Modify | Instances the template, turns and tints `Arrow`, drops the glyph `Label`, the procedural note box and the eight texture exports. |
| `tests/test_lomba_menari_arrow.gd` | Create | Pins the art's direction and fill, the template's shape, and the script's use of it. |
| `tests/test_viewport_editability.gd:74` | Modify | `LombaMenari.gd` baseline 4 → 1. |
| `docs/superpowers/DEBT.md` | Modify | Delete the resolved glyph note; list the new generated asset. |
| `docs/superpowers/CHANGELOG.md` | Modify | One entry for the pass. |

---

### Task 1: The arrow art

**Files:**
- Create: `Assets/Images/Minigames/SeniBudaya/note_arrow.png`
- Create: `tests/test_lomba_menari_arrow.gd`

**Interfaces:**
- Produces: `res://Assets/Images/Minigames/SeniBudaya/note_arrow.png`, a 512×512 RGBA arrow pointing +x, with white fill and a dark outline. Task 2 assigns it.

- [ ] **Step 1: Write the failing test**

Create `tests/test_lomba_menari_arrow.gd`:

```gdscript
@tool
extends McpTestSuite

## LombaMenari's note arrow (2026-09-28): one right-pointing, white-filled,
## dark-outlined texture in a MenariNote.tscn template, turned and tinted per
## lane, replacing the ←/→/↖/↗ glyphs Boohong and Open Sans cannot draw. The
## art is checked by pixels, the template by instancing it, and the script by
## source scan plus its pure arrow_rotation() helper, since the minigame
## cannot be played inside the editor.
##
## Must be @tool; no test here may be a coroutine.

const ARROW_PATH := "res://Assets/Images/Minigames/SeniBudaya/note_arrow.png"
const NOTE_SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/MenariNote.tscn"
const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"


func suite_name() -> String:
	return "lomba_menari_arrow"


# ─── the art

func _arrow_image() -> Image:
	var img := (load(ARROW_PATH) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	return img


## How many rows of column `x` are opaque.
func _opaque_span(img: Image, x: int) -> int:
	var n := 0
	for y in img.get_height():
		if img.get_pixel(x, y).a > 0.5:
			n += 1
	return n


## Pointing right puts the narrow shaft on the left and the wide head on the
## right, so a column through the head is taller than one through the shaft.
func test_the_arrow_art_points_right() -> void:
	var img := _arrow_image()
	var w := img.get_width()
	var shaft := _opaque_span(img, int(w * 0.3))
	var head := _opaque_span(img, int(w * 0.6))
	assert_gt(shaft, 0, "the shaft is opaque at 30% width")
	assert_gt(head, shaft, "the head (60%%) is taller than the shaft (30%%): %d vs %d" % [head, shaft])


## A white fill takes the lane tint through self_modulate without muddying it.
func test_the_arrow_fill_is_white() -> void:
	var img := _arrow_image()
	var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	assert_gt(c.a, 0.9, "the centre is inside the arrow")
	assert_gt(minf(c.r, minf(c.g, c.b)), 0.9, "and it is white, not yellow: %s" % c)


## The dark outline is what separates the arrow from the busy stage.
func test_the_arrow_keeps_a_dark_outline() -> void:
	var img := _arrow_image()
	var darkest := 1.0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a > 0.9:
				darkest = minf(darkest, p.get_luminance())
	assert_true(darkest < 0.3, "an opaque pixel is dark (outline): darkest luminance %.2f" % darkest)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="lomba_menari_arrow")`
Expected: all three tests FAIL, because `load(ARROW_PATH)` returns null (the file does not exist yet).

- [ ] **Step 3: Generate the art**

The source is the game's existing chunky arrow, `Assets/Images/UI/Placeholders/arrow.png` (512×512, pointing **down**). It is **translucent by design**: its yellow fill sits at alpha 180 and its black outline at 220–245. A note must be solid, so rescale alpha until the fill is opaque (the outline clips to 255, and the anti-aliased edge keeps its ramp). Then rotate it to point right and move the fill to white, keeping the edge blend. Run from the project root:

```bash
mkdir -p Assets/Images/Minigames/SeniBudaya
python - <<'EOF2'
from PIL import Image
FILL_ALPHA = 180  # the source fill's alpha; scaled up to 255 so the note is solid
src = Image.open("Assets/Images/UI/Placeholders/arrow.png").convert("RGBA")
img = src.rotate(90)  # PIL turns counter-clockwise: down -> right
px = img.load()
w, h = img.size
lum = lambda p: 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
body = [px[x, y] for x in range(w) for y in range(h) if px[x, y][3] >= FILL_ALPHA - 10]
dark = min(body, key=lum)
lo, hi = lum(dark), max(lum(p) for p in body)
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        t = max(0.0, min(1.0, (lum((r, g, b)) - lo) / (hi - lo)))
        rgb = tuple(round(dark[i] + t * (255 - dark[i])) for i in range(3))
        px[x, y] = rgb + (min(255, round(a * 255 / FILL_ALPHA)),)
img.save("Assets/Images/Minigames/SeniBudaya/note_arrow.png")
print("dark outline", dark, "size", img.size, "centre", img.getpixel((256, 256)))
EOF2
```

Expected output: `dark outline (0, 0, 0, …) size (512, 512) centre (255, 255, 255, 255)`.

- [ ] **Step 4: Import it**

Run: `filesystem_manage(op="scan")`
Expected: `note_arrow.png.import` now exists next to the PNG.

- [ ] **Step 5: Run the test to verify it passes**

Run: `test_run(suite="lomba_menari_arrow")`
Expected: 3/3 PASS.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/Minigames/SeniBudaya/note_arrow.png Assets/Images/Minigames/SeniBudaya/note_arrow.png.import tests/test_lomba_menari_arrow.gd tests/test_lomba_menari_arrow.gd.uid
git commit -m "feat(menari): a right-pointing white note arrow" -m "Recoloured and turned from UI/Placeholders/arrow.png so a lane tint shows true." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The note template scene

**Files:**
- Create: `Scenes/Minigames/SeniBudaya/MenariNote.tscn`
- Modify: `tests/test_lomba_menari_arrow.gd` (append)

**Interfaces:**
- Consumes: `note_arrow.png` from Task 1.
- Produces: `res://Scenes/Minigames/SeniBudaya/MenariNote.tscn`, with root `MenariNote: Control` (96×96, `mouse_filter = IGNORE`) and child `Arrow: TextureRect` (anchors 0,0 → 1,1, `expand_mode = IGNORE_SIZE`, `stretch_mode = KEEP_ASPECT_CENTERED`, `texture = note_arrow.png`, `mouse_filter = IGNORE`). Task 3 instances it and reaches `Arrow` by name.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_lomba_menari_arrow.gd`:

```gdscript


# ─── the template

func test_the_note_template_carries_the_arrow() -> void:
	var note := load(NOTE_SCENE_PATH).instantiate() as Control
	track(note)
	assert_true(note != null, "MenariNote.tscn's root is a Control")
	var arrow := note.get_node_or_null("Arrow") as TextureRect
	assert_true(arrow != null, "it has an Arrow TextureRect child")
	assert_eq(arrow.texture.resource_path, ARROW_PATH, "wearing note_arrow.png")
	assert_eq(arrow.anchor_right, 1.0, "Arrow fills the note horizontally")
	assert_eq(arrow.anchor_bottom, 1.0, "and vertically")
	assert_eq(arrow.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "so it scales with the note")
	assert_eq(arrow.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "without squashing")


## Swipes are read in _input(), never by the GUI, so a note must not eat them.
func test_the_note_ignores_the_mouse() -> void:
	var note := load(NOTE_SCENE_PATH).instantiate() as Control
	track(note)
	assert_eq(note.mouse_filter, Control.MOUSE_FILTER_IGNORE, "root ignores the mouse")
	assert_eq((note.get_node("Arrow") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Arrow too")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="lomba_menari_arrow")`
Expected: the two new tests FAIL (`load(NOTE_SCENE_PATH)` is null); Task 1's three still PASS.

- [ ] **Step 3: Build the scene in the editor**

Make these calls in order:

1. `scene_manage(op="create", params={"path": "res://Scenes/Minigames/SeniBudaya/MenariNote.tscn", "root_type": "Control", "root_name": "MenariNote"})`
2. `node_set_property` on `/MenariNote`: `size` = `Vector2(96, 96)`, `mouse_filter` = `2`.
3. `node_create(type="TextureRect", name="Arrow", parent_path="/MenariNote")`
4. `node_set_property` on `/MenariNote/Arrow`: `anchor_right` = `1.0`, `anchor_bottom` = `1.0`, `offset_right` = `0.0`, `offset_bottom` = `0.0`, `expand_mode` = `1`, `stretch_mode` = `5`, `mouse_filter` = `2`, `texture` = `"res://Assets/Images/Minigames/SeniBudaya/note_arrow.png"`.
5. `scene_save()`

- [ ] **Step 4: Check the save touched nothing else**

Run: `git status --short` and `git diff HEAD -- '*.gd'`
Expected: only `MenariNote.tscn` is new. No `.gd` diff (restore any with `git checkout -- <file>`). Open the new `.tscn` and confirm it has `Arrow` with `anchor_right = 1.0` and the texture `ext_resource` carries a `uid=`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `test_run(suite="lomba_menari_arrow")`
Expected: 5/5 PASS.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Minigames/SeniBudaya/MenariNote.tscn tests/test_lomba_menari_arrow.gd
git commit -m "feat(menari): MenariNote template with the arrow" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: LombaMenari uses the template

**Files:**
- Modify: `Scripts/Minigames/SeniBudaya/LombaMenari.gd:21-39` (exports), `:149-151` (consts), `:439-519` (`_spawn_single_note`), `:656-713` (`_animate_swiped_note`), `:751-777` (`_show_swipe_effect`), plus a new static helper beside `grade_for_distance()`
- Modify: `tests/test_viewport_editability.gd:74`
- Modify: `tests/test_lomba_menari_arrow.gd` (append)

**Interfaces:**
- Consumes: `MenariNote.tscn` (root `Control`, child `Arrow: TextureRect`) from Task 2; the existing `ARROW_DIRECTIONS: Dictionary` (NoteType → unit `Vector2`) and `left_note_color` / `right_note_color` / `top_left_note_color` / `top_right_note_color`.
- Produces: `const NOTE_SCENE: PackedScene`, `static func arrow_rotation(type: int) -> float` and `@export var swiped_arrow_lighten: float = 0.35`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_lomba_menari_arrow.gd`:

```gdscript


# ─── the script

## LombaMenari.gd declares no class_name; reached through a preloaded const,
## as tests/test_lomba_menari_timing.gd does.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")


func _src() -> String:
	return FileAccess.get_file_as_string(SCRIPT_PATH)


func test_notes_are_instanced_from_the_template() -> void:
	var src := _src()
	assert_contains(src, "NOTE_SCENE.instantiate()", "a note comes from MenariNote.tscn")
	assert_false(src.contains("TextureRect.new()"), "not a TextureRect built in code")


func test_no_arrow_glyphs_remain() -> void:
	var src := _src()
	for glyph in ["←", "→", "↖", "↗"]:
		assert_false(src.contains(glyph), "no %s glyph: the fonts cannot draw it" % glyph)
	assert_false(src.contains("ArrowLabel"), "the glyph Label is gone")


func test_the_per_direction_texture_slots_are_gone() -> void:
	var src := _src()
	for slot in ["left_note_texture", "right_note_texture", "top_left_note_texture",
			"top_right_note_texture", "left_swiped_texture", "right_swiped_texture",
			"top_left_swiped_texture", "top_right_swiped_texture"]:
		assert_false(src.contains(slot), "%s is gone: one arrow is turned per lane" % slot)


## The art points right (angle 0), so each lane's turn is its direction's angle.
func test_arrow_rotation_turns_the_art_toward_each_lane() -> void:
	var cases := {
		MenariScript.NoteType.RIGHT: 0.0,
		MenariScript.NoteType.LEFT: PI,
		MenariScript.NoteType.TOP_LEFT: -0.75 * PI,
		MenariScript.NoteType.TOP_RIGHT: -0.25 * PI,
	}
	for type in cases:
		var got: float = MenariScript.arrow_rotation(type)
		var want: float = cases[type]
		assert_true(absf(angle_difference(got, want)) < 0.001,
			"lane %d turns %.3f rad, wants %.3f" % [type, got, want])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="lomba_menari_arrow")`
Expected: the four new tests FAIL (the glyphs, `TextureRect.new()` and the slots are all still there, and `arrow_rotation` does not exist). The first five still PASS.

- [ ] **Step 3: Delete the eight texture exports**

`script_patch` `LombaMenari.gd`: remove this whole block (lines 21-39):

```gdscript
@export_group("Note Textures (Incoming PNGs)")
## Sprite for an unswiped LEFT note approaching the hit zone.
@export var left_note_texture: Texture2D
## Same as left_note_texture, for RIGHT.
@export var right_note_texture: Texture2D
## Same as left_note_texture, for TOP_LEFT.
@export var top_left_note_texture: Texture2D
## Same as left_note_texture, for TOP_RIGHT.
@export var top_right_note_texture: Texture2D

@export_group("Swiped Textures (Feedback PNGs)")
## Sprite briefly shown on a LEFT note after a successful swipe.
@export var left_swiped_texture: Texture2D
## Same as left_swiped_texture, for RIGHT.
@export var right_swiped_texture: Texture2D
## Same as left_swiped_texture, for TOP_LEFT.
@export var top_left_swiped_texture: Texture2D
## Same as left_swiped_texture, for TOP_RIGHT.
@export var top_right_swiped_texture: Texture2D

```

`LombaMenari.tscn` sets none of these, so no scene edit is needed.

- [ ] **Step 4: Retarget the lane colours and add the swipe lighten**

In the `Visual - Note Colors` group, the four colour exports now tint the arrow rather than fill a box. Replace:

```gdscript
## Procedural-mode tint for LEFT notes, used when left_note_texture is null.
@export var left_note_color: Color     = Color(1.0, 0.2, 0.2)
```

with:

```gdscript
## Tint for LEFT notes' arrow (MenariNote.tscn's white Arrow, via
## self_modulate), and the colour a swiped LEFT note lightens from.
@export var left_note_color: Color     = Color(1.0, 0.2, 0.2)
```

Then, directly after the `top_right_note_color` line, add:

```gdscript
## How far a swiped note's arrow lightens toward white as it flies off, the
## hit's flash. 0 keeps the lane colour; 1 is pure white.
@export_range(0.0, 1.0, 0.05) var swiped_arrow_lighten: float = 0.35
```

- [ ] **Step 5: Add the template const and the rotation helper**

After the `const DanceCamera := preload(...)` line (~151), add:

```gdscript

## One note: a Control holding the Arrow TextureRect. The art points right;
## _spawn_single_note() turns Arrow with arrow_rotation() and tints it per lane.
const NOTE_SCENE := preload("res://Scenes/Minigames/SeniBudaya/MenariNote.tscn")
```

Directly above `static func grade_for_distance(`, add:

```gdscript
## The angle that turns MenariNote's right-pointing arrow toward `type`'s
## direction, from the same ARROW_DIRECTIONS table the swipe reader uses.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func arrow_rotation(type: int) -> float:
	return (ARROW_DIRECTIONS[type] as Vector2).angle()

```

- [ ] **Step 6: Rewrite `_spawn_single_note`'s construction**

Replace:

```gdscript
	var note = TextureRect.new()
	note.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
```

with:

```gdscript
	var note: Control = NOTE_SCENE.instantiate()
```

In the same function, replace the variable declarations and the `match` block:

```gdscript
	var move_dir = Vector2.ZERO
	var fallback_color = Color.WHITE
	var arrow = ""
	var tex = null
	
	match type:
		NoteType.LEFT:
			tex = left_note_texture
			fallback_color = left_note_color
			arrow = "←"
			move_dir = Vector2(1, 0)
		NoteType.RIGHT:
			tex = right_note_texture
			fallback_color = right_note_color
			arrow = "→"
			move_dir = Vector2(-1, 0)
		NoteType.TOP_LEFT:
			tex = top_left_note_texture
			fallback_color = top_left_note_color
			arrow = "↖"
			move_dir = Vector2(0.7071, 0.7071)
		NoteType.TOP_RIGHT:
			tex = top_right_note_texture
			fallback_color = top_right_note_color
			arrow = "↗"
			move_dir = Vector2(-0.7071, 0.7071)
```

with:

```gdscript
	var move_dir = Vector2.ZERO
	var tint = Color.WHITE
	
	match type:
		NoteType.LEFT:
			tint = left_note_color
			move_dir = Vector2(1, 0)
		NoteType.RIGHT:
			tint = right_note_color
			move_dir = Vector2(-1, 0)
		NoteType.TOP_LEFT:
			tint = top_left_note_color
			move_dir = Vector2(0.7071, 0.7071)
		NoteType.TOP_RIGHT:
			tint = top_right_note_color
			move_dir = Vector2(-0.7071, 0.7071)
```

Then replace everything from `	if tex:` down to and including `	note.add_child(label)`:

```gdscript
	if tex:
		note.texture = tex
		note.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		note.texture = _create_rounded_box_texture(fallback_color, Color.WHITE, 4)
	
	# Visual text indicator inside note
	var label = Label.new()
	label.name = "ArrowLabel"
	label.text = arrow
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.visible = (tex == null)
	
	note.add_child(label)
```

with:

```gdscript
	# The root keeps the breathing sway's rotation; the Arrow child carries
	# the lane's direction, so the two never overwrite each other.
	var arrow: TextureRect = note.get_node("Arrow")
	arrow.pivot_offset = note_size / 2.0
	arrow.rotation = arrow_rotation(type)
	arrow.self_modulate = tint
```

- [ ] **Step 7: Rewrite `_animate_swiped_note`'s texture swap**

Replace the declarations and `match` block:

```gdscript
	var arrow_char = ""
	var target_color = Color.WHITE
	var slide_dir = Vector2.ZERO
	var rot_target = 0.0
	var swiped_tex: Texture2D = null
	
	match swipe_type:
		NoteType.LEFT:
			arrow_char = "←"
			target_color = left_note_color
			slide_dir = Vector2(-160, 0)
			rot_target = -0.3
			swiped_tex = left_swiped_texture
		NoteType.RIGHT:
			arrow_char = "→"
			target_color = right_note_color
			slide_dir = Vector2(160, 0)
			rot_target = 0.3
			swiped_tex = right_swiped_texture
		NoteType.TOP_LEFT:
			arrow_char = "↖"
			target_color = top_left_note_color
			slide_dir = Vector2(-120, -120)
			rot_target = -0.4
			swiped_tex = top_left_swiped_texture
		NoteType.TOP_RIGHT:
			arrow_char = "↗"
			target_color = top_right_note_color
			slide_dir = Vector2(120, -120)
			rot_target = 0.4
			swiped_tex = top_right_swiped_texture
			
	if swiped_tex:
		note.texture = swiped_tex
		note.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label = note.get_node_or_null("ArrowLabel")
		if label:
			label.visible = false
	else:
		# Glow color calculation (slightly brighter note color)
		var glow_color = Color(target_color.r * 1.25, target_color.g * 1.25, target_color.b * 1.25, 0.9)
		note.texture = _create_rounded_box_texture(glow_color, Color.WHITE, 5)
		var label = note.get_node_or_null("ArrowLabel")
		if label:
			label.text = arrow_char
			label.visible = true
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
```

with:

```gdscript
	var target_color = Color.WHITE
	var slide_dir = Vector2.ZERO
	var rot_target = 0.0
	
	match swipe_type:
		NoteType.LEFT:
			target_color = left_note_color
			slide_dir = Vector2(-160, 0)
			rot_target = -0.3
		NoteType.RIGHT:
			target_color = right_note_color
			slide_dir = Vector2(160, 0)
			rot_target = 0.3
		NoteType.TOP_LEFT:
			target_color = top_left_note_color
			slide_dir = Vector2(-120, -120)
			rot_target = -0.4
		NoteType.TOP_RIGHT:
			target_color = top_right_note_color
			slide_dir = Vector2(120, -120)
			rot_target = 0.4
	
	# The hit's flash: the arrow lightens toward white as it flies off.
	var arrow := note.get_node_or_null("Arrow") as TextureRect
	if arrow:
		arrow.self_modulate = target_color.lightened(swiped_arrow_lighten)
```

The tween that follows (slide, scale, rotation, fade, `queue_free`) is unchanged.

- [ ] **Step 7b: The hit flash wears the arrow too**

`_show_swipe_effect()` (~line 751) flashes a big glyph `Label` over the hit zone on every hit, with its own copy of the four lane colours. Give it the same template. Directly above `const NOTE_SCENE`, add:

```gdscript
## Side, in pixels, of the arrow that flashes over the hit zone on a hit,
## the size the glyph Label it replaced was centred at.
const SWIPE_EFFECT_SIZE := 100.0

```

Then replace the start of `_show_swipe_effect()`, from `	var effect = Label.new()` down to and including `	add_child(effect)`:

```gdscript
	var effect = Label.new()
	var arrow_char = ""
	var color = Color.WHITE
	
	match swipe_type:
		NoteType.LEFT:
			arrow_char = "←"
			color = Color(1.0, 0.2, 0.2)
		NoteType.RIGHT:
			arrow_char = "→"
			color = Color(0.2, 0.5, 1.0)
		NoteType.TOP_LEFT:
			arrow_char = "↖"
			color = Color(1.0, 0.8, 0.1)
		NoteType.TOP_RIGHT:
			arrow_char = "↗"
			color = Color(0.2, 0.8, 0.3)
			
	effect.text = arrow_char
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.add_theme_font_size_override("font_size", 96)
	effect.add_theme_color_override("font_color", color)
	effect.add_theme_constant_override("outline_size", 16)
	effect.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Position at center of hit zone
	effect.global_position = hit_zone.global_position + hit_zone.size / 2 - Vector2(50, 50)
	add_child(effect)
```

with (the lane colours now come from the exports instead of a hardcoded copy; their defaults are the same values):

```gdscript
	var effect: Control = NOTE_SCENE.instantiate()
	var color = Color.WHITE
	
	match swipe_type:
		NoteType.LEFT:
			color = left_note_color
		NoteType.RIGHT:
			color = right_note_color
		NoteType.TOP_LEFT:
			color = top_left_note_color
		NoteType.TOP_RIGHT:
			color = top_right_note_color
	
	var effect_size := Vector2(SWIPE_EFFECT_SIZE, SWIPE_EFFECT_SIZE)
	effect.size = effect_size
	var arrow: TextureRect = effect.get_node("Arrow")
	arrow.pivot_offset = effect_size / 2.0
	arrow.rotation = arrow_rotation(swipe_type)
	arrow.self_modulate = color
	
	# Position at center of hit zone
	effect.global_position = hit_zone.global_position + hit_zone.size / 2 - effect_size / 2.0
	add_child(effect)
```

The drift tween below it is unchanged.

- [ ] **Step 8: Check nothing else still reads the removed names**

Run: `grep -nE "fallback_color|arrow_char|swiped_tex|ArrowLabel|_note_texture|_swiped_texture" Scripts/Minigames/SeniBudaya/LombaMenari.gd`
Expected: no output. `_create_rounded_box_texture` must still exist, because the hit zone uses it at ~line 289.

- [ ] **Step 9: Lower the ratchet**

`script_patch` `tests/test_viewport_editability.gd` line 74:

```gdscript
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd": 4,
```

→

```gdscript
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd": 1,
```

The one left is `_show_hit_feedback`'s grade-word `Label.new()` (SEMPURNA!/BAGUS!/UPS!), which is real text and out of this plan's scope.

- [ ] **Step 10: Run the tests to verify they pass**

Run each:
- `test_run(suite="lomba_menari_arrow")`: expected 9/9 PASS.
- `test_run(suite="lomba_menari_timing")`: expected all PASS, unchanged.
- `test_run(suite="viewport_editability")`: expected all PASS. If `test_baseline_is_not_stale` prints a different literal, the count scan disagrees with this plan; paste what it prints and note why.
- `test_run(suite="script_documentation")`: expected all PASS (every new `@export` and const has a `##` line).

- [ ] **Step 11: Commit**

```bash
git add Scripts/Minigames/SeniBudaya/LombaMenari.gd tests/test_lomba_menari_arrow.gd tests/test_viewport_editability.gd
git commit -m "feat(menari): notes wear the arrow template, not glyphs" -m "Each note instances MenariNote.tscn; its Arrow child is turned by ARROW_DIRECTIONS and tinted with the lane colour. Drops the glyph Label, the procedural note box and eight unused texture slots; LombaMenari's runtime-UI baseline falls 4 -> 1." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: See it in the game, then write it down

**Files:**
- Modify: `docs/superpowers/DEBT.md` (the Boohong punctuation note, ~lines 370-371, and the `## Placeholder art` "Generated placeholder art" list)
- Modify: `docs/superpowers/CHANGELOG.md` (new top entry)
- Modify: `CLAUDE.md` (the suite/test count line under `## Testing`)

- [ ] **Step 1: Watch the notes fly**

1. `project_run()`.
2. Open the debug overlay (`F1`), go to the **Minigames** tab and press **Lomba Menari (Seni)** (the standalone launcher).
3. Once notes are on screen, freeze them in one call: `editor_manage(op="game_eval", params={"code": "Engine.time_scale = 0.02\nreturn 'frozen'"})`.
4. `editor_screenshot(source="game", max_resolution=0)`.

Expected: each note is a chunky arrow with a dark outline, pointing the way to swipe (left lane ←, right lane →, the two top lanes ↖ ↗) and tinted red, blue, yellow or green. There is no square box behind it and no tofu or font-fallback glyph.

5. Swipe one (or set `Engine.time_scale = 1.0` and play a few): the hit arrow flashes lighter and flies off as before.
6. `project_manage(op="stop")`.

If an arrow points the wrong way, the art's direction and `arrow_rotation()` disagree: re-check Task 1's rotate direction against `test_the_arrow_art_points_right`, not the code.

- [ ] **Step 2: Update DEBT.md**

In the Boohong punctuation note, delete this sentence (it is resolved):

```
`LombaMenari`'s ←/→/↖/↗ are body text, but Open Sans has no `←` either, so
they ride system fallback too (minigames sit outside the design system).
```

In `## Placeholder art` → **Generated placeholder art**, add to the list:

```
`Minigames/SeniBudaya/note_arrow.png` (Lomba Menari's note, recoloured white
and turned to point right from `UI/Placeholders/arrow.png` with Pillow; a
replacement must point **right**, keep a white fill for the lane tint and a
dark outline, and `tests/test_lomba_menari_arrow.gd` checks all three),
```

- [ ] **Step 3: Add the changelog entry**

At the top of `docs/superpowers/CHANGELOG.md`, under the intro and above the newest entry:

```markdown
## 2026-09-28 — Lomba Menari's notes are real arrows

The notes used to be a code-drawn coloured box with a `←`/`→`/`↖`/`↗`
typed on it (and a bigger one flashed over the hit zone on each hit), glyphs neither Boohong nor Open Sans can draw, so they rode
the device's fallback font. Each note is now `MenariNote.tscn`: one chunky,
white-filled arrow (`note_arrow.png`, from the game's existing arrow art),
turned per lane from `ARROW_DIRECTIONS` and tinted with the lane's
`*_note_color`. A hit lightens it by `swiped_arrow_lighten` as it flies off.
The eight never-filled per-direction texture slots are gone, and
`LombaMenari.gd`'s runtime-UI baseline fell 4 → 1.
```

- [ ] **Step 4: Full suite, then the count**

Run a full `test_run()` (budget an editor restart afterwards; the bridge may drop). Fix real breakage only. Then run `git status`: `Assets/Theme/kejartes_theme.tres` and `default_bus_layout.tres` may be dirty from the run, so `git checkout --` them if you did not intend them. Update the count in `CLAUDE.md`'s `## Testing` line (`163 suites, 2509 tests (2026-09-28)`) to what the run reports. This pass adds one suite and nine tests, so expect 164 suites.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -m "docs(menari): note arrow pass, debt and suite count" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Ship**

Finish the branch with the `ship-pr` skill (`.claude/skills/ship-pr/SKILL.md`).
