# StudentList — Warm UI Part 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring StudentList into the Warm UI language — roster-progress strip, papan header, trait chips, framed portrait, a five-day note row, thumb-height navigation, and a catatan guru filling the card's dead paper — without breaking the `Murid1..4` node contract the tests and tutorial depend on.

**Architecture:** Extract the four duplicated card subtrees into one `RosterCard.tscn` template instanced four times under the existing names, so the relayout is authored once. Reuse the `QuirkBadge` / `PersonaBadge` / `GhostButton` variations that already ship; add exactly one new variation (`SpecialtyBadge`). Add a `RosterStrip` of four `RosterAvatar` buttons above the card as the roster-progress signal, and one tutorial step to teach it.

**Tech Stack:** Godot 4.6, GDScript, `DesignTokens` / `ThemeFactory` design system, Godot AI MCP for all editor work, `McpTestSuite` suites run via `test_run`.

**Spec:** `docs/superpowers/specs/2026-09-10-studentlist-part-3-design.md`

## Global Constraints

- Portrait 1080x1920. All screen coordinates in this plan are in that space.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` / `node_create` / `node_set_property` / `node_manage` / `scene_save`, or `batch_execute` with the plugin command names (`create_node`, `set_property`, `move_node`, `delete_node`).
- `anchors_preset` is inert — set `anchor_left`/`anchor_top`/`anchor_right`/`anchor_bottom` individually. Numbers unquoted (`1`, not `"1.0"`). `node_create` appends last, so z-order needs `move_node`.
- **Scene work first, script work second.** `scene_save` flushes stale script buffers over patched `.gd` files. After every `scene_save`, run `git diff HEAD -- '*.gd'` and check for files you were not editing.
- **Overrides serialise only on an instanced scene's ROOT.** Every tunable is an `@export` on the sub-scene's root script, never a property set on an instance's child.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Layout-only constant overrides (`separation`, `margin_*`) are the sole exception.
- **No `Color()` literals in scripts** — read colours from `DesignTokens.load_default()`. `tests/test_student_list.gd` scans for this.
- All game-facing text is **Indonesian**. Systems code is English.
- `tokens.touch_target_min` is **96**. Every interactive control must clear it on its smaller axis.
- Every script needs a `##` file header; every `@export` needs its own `##` line (`tests/test_script_documentation.gd`).
- **Prefer `script_patch` for `.gd` edits.** A file written from outside the editor serves stale to `test_run` until a no-op `script_patch` on that same file forces the reload.
- **Editing a `class_name` script breaks the next `project_run`** until `project_manage(op="stop")`, `filesystem_manage(op="scan")`, relaunch.
- **Prefer targeted `test_run(suite=...)`.** A full run takes 15-20s and drops the bridge; budget one editor restart per full run and take them at milestones only.
- `tests/test_viewport_editability.gd` `BASELINE` lists `res://Scripts/StudentList/student_list.gd` at **8**. Frozen — may only be lowered, never raised.

## Deviations from the spec (decided during planning, apply these)

1. **No `TraitChip.tscn`, no `TraitChip` variation.** `QuirkBadge` and `PersonaBadge` already exist in `ThemeFactory` as pill-geometry trait chips and are already in `DISPLAY_ROSTER` and the bake. Godot's `Button` has a native `icon` property, so a chip is a `Button` with `icon` + `text` + variation — no PackedScene needed. Only the specialty chip lacks a variation; Task 1 adds `SpecialtyBadge`.
2. **`RosterAvatar` uses the existing `GhostButton` variation** — it is transparent at rest specifically so baked art can be the button, which is exactly this case.
3. **Trait row is 96 tall, not 90.** The chips are `Button` variations and therefore interactive controls swept by `test_interactive_controls_meet_the_minimum_touch_target`; 90 would fail against `touch_target_min` = 96. Card bands are re-budgeted accordingly in Task 5.

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/Design/ThemeFactory.gd` (modify) | add the `SpecialtyBadge` pill variation |
| `tests/test_theme_factory.gd` (modify) | add `SpecialtyBadge` to `DISPLAY_ROSTER` |
| `Assets/Images/UI/Placeholders/icon_wirausaha.svg` (create) | completes the six-category icon set |
| `Assets/Images/UI/Placeholders/stamp_{sudah,belum}.svg` (create) | rubber stamp behind the status button |
| `Assets/Images/UI/StudentList/{photo_corner,roster_avatar_frame,catatan_rule}.png` (create) | portrait tape, avatar state ring, ruled note strip |
| `Scenes/StudentList/RosterAvatar.tscn` + `Scripts/StudentList/RosterAvatar.gd` (create) | one roster-strip slot: portrait in a state-tinted ring |
| `Scenes/StudentList/RosterCard.tscn` + `Scripts/StudentList/RosterCard.gd` (create) | one student's paper card, authored once |
| `Scenes/StudentList/PageDot.tscn` (create) | page-indicator dot, replacing runtime construction |
| `Scripts/StudentList/StickyNote.gd` (modify) | one new `icon_texture` `@export` |
| `Scenes/StudentList/student_list.tscn` (modify) | screen bands: papan, RosterStrip, CardContainer, nav row |
| `Scripts/StudentList/student_list.gd` (modify) | roster sync, avatar jump, `##` header, PageDot instancing |
| `tests/test_student_list.gd` (modify) | all new structural assertions |

---

### Task 1: `SpecialtyBadge` theme variation

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`
- Modify: `tests/test_theme_factory.gd`
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: `_add_button_variation(theme, tokens, name, top, bottom, border, text_color, radius := -1)`, already in `ThemeFactory.gd`.
- Produces: theme type variation `&"SpecialtyBadge"` — a pill `Button` variation. Task 5 assigns it to the specialty chip.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_theme_factory.gd`, next to the other variation tests:

```gdscript
## The roster card's specialty chip. QuirkBadge and PersonaBadge already
## cover the other two trait kinds; specialty had no chip variation, and
## borrowing one of theirs would have made the three kinds
## indistinguishable. Neutral brand fill -- the category's own colour
## rides on the chip's icon, which varies per student, so it cannot live
## in a static variation.
func test_specialty_badge_is_a_pill_button_variation() -> void:
	var theme := ThemeFactory.build()
	assert_true(theme.has_type("SpecialtyBadge"),
		"ThemeFactory must build a SpecialtyBadge variation")
	var sb := theme.get_stylebox("normal", "SpecialtyBadge")
	assert_true(sb is StyleBoxFlat, "SpecialtyBadge normal must be a StyleBoxFlat")
	var tokens := DesignTokens.load_default()
	assert_eq((sb as StyleBoxFlat).corner_radius_top_left, tokens.radius_pill,
		"SpecialtyBadge must be a pill, like QuirkBadge and PersonaBadge")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `test_run(suite="theme_factory", test_name="specialty_badge")`
Expected: FAIL — `ThemeFactory must build a SpecialtyBadge variation`

- [ ] **Step 3: Add the variation**

In `Scripts/Design/ThemeFactory.gd`, in `_build_buttons`, immediately after the `PersonaBadge` call:

```gdscript
	# The roster card's third chip. Quirk and Persona carry their own
	# accents; specialty stays neutral because its category colour
	# varies per student and rides on the chip's icon instead.
	_add_button_variation(theme, tokens, "SpecialtyBadge",
		tokens.surface_sunken, tokens.surface_sunken.darkened(0.18),
		tokens.brand_primary, tokens.text_primary,
		tokens.radius_pill)
```

- [ ] **Step 4: Add it to the display roster**

`_add_button_variation` assigns the display font, so `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` must list it or the roster test fails. Add at the end of the array:

```gdscript
	# 2026-09-10 StudentList Part 3: the roster card's specialty chip.
	"SpecialtyBadge",
```

- [ ] **Step 5: Rebake the theme**

`BakeTheme.gd` is an `EditorScript` with no MCP entry point, and a variation missing from the bake renders as an unstyled default `Button` in game while the suite stays green. Write this transient suite to `res://tests/test_zz_rebake_temp.gd`:

```gdscript
@tool
extends McpTestSuite

## TRANSIENT. Drives the theme rebake headlessly because
## Scripts/Design/BakeTheme.gd is an EditorScript with no MCP entry
## point. Delete this file immediately after running it.

func suite_name() -> String:
	return "zz_rebake_temp"

func test_rebake() -> void:
	var theme := ThemeFactory.build()
	var err := ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
	assert_eq(err, OK, "rebake must succeed")
```

Run: `test_run(suite="zz_rebake_temp")`, then delete `tests/test_zz_rebake_temp.gd`.

- [ ] **Step 6: Run the theme suites to verify they pass**

Run: `test_run(suite="theme_factory")` then `test_run(suite="button_geometry")`
Expected: both PASS. `button_geometry` matters because `SpecialtyBadge` opts out of `radius_button`; if it fails, add `"SpecialtyBadge"` to that suite's `RADIUS_EXEMPT`, exactly as `QuirkBadge` and `PersonaBadge` are handled.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd tests/test_button_geometry.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): add the SpecialtyBadge chip variation"
```

---

### Task 2: Generated art

**Files:**
- Create: `Assets/Images/UI/Placeholders/icon_wirausaha.svg`
- Create: `Assets/Images/UI/Placeholders/stamp_sudah.svg`
- Create: `Assets/Images/UI/Placeholders/stamp_belum.svg`
- Create: `Assets/Images/UI/StudentList/photo_corner.png`
- Create: `Assets/Images/UI/StudentList/roster_avatar_frame.png`
- Create: `Assets/Images/UI/StudentList/catatan_rule.png`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Produces: six asset paths. Tasks 3, 4 and 5 load them. `roster_avatar_frame.png` and `catatan_rule.png` are drawn **white** so `self_modulate` can tint them from tokens.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_student_list.gd`:

```gdscript
## Part 3's generated art. All six are System.Drawing / hand-written SVG
## placeholders, drop-replaceable at the same path with no code change.
## icon_wirausaha is a genuine gap fix, not decoration: StickyNote already
## tints for Wirausaha via category_color(), so without it a Wirausaha day
## would be the only note in the week strip with no glyph.
func test_part_three_art_exists_and_loads() -> void:
	var paths := [
		"res://Assets/Images/UI/Placeholders/icon_wirausaha.svg",
		"res://Assets/Images/UI/Placeholders/stamp_sudah.svg",
		"res://Assets/Images/UI/Placeholders/stamp_belum.svg",
		"res://Assets/Images/UI/StudentList/photo_corner.png",
		"res://Assets/Images/UI/StudentList/roster_avatar_frame.png",
		"res://Assets/Images/UI/StudentList/catatan_rule.png",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "missing asset: " + p)
		assert_true(load(p) is Texture2D, "not a Texture2D: " + p)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `test_run(suite="student_list", test_name="part_three_art")`
Expected: FAIL — `missing asset: res://Assets/Images/UI/Placeholders/icon_wirausaha.svg`

- [ ] **Step 3: Write the three SVGs**

Match the existing category icons' style: 100x100 viewBox, flat primitives, single line, **no `<text>` elements** — Godot rasterises SVG through ThorVG, which drops text.

`Assets/Images/UI/Placeholders/icon_wirausaha.svg`:

```
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><rect x="14" y="28" width="72" height="14" rx="4" fill="#16c79a"/><rect x="18" y="42" width="64" height="10" rx="3" fill="#0A7A5E"/><rect x="24" y="52" width="52" height="30" rx="4" fill="#0f9c78"/><circle cx="50" cy="67" r="11" fill="#F5D423"/><circle cx="50" cy="67" r="5" fill="#c9a800"/></svg>
```

The stamps are 300x100 rings the status button's own text sits inside — no lettering in the art.

`Assets/Images/UI/Placeholders/stamp_sudah.svg`:

```
<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(-4 150 50)"><rect x="8" y="10" width="284" height="80" rx="12" fill="none" stroke="#35A05A" stroke-width="7" opacity="0.85"/><rect x="20" y="20" width="260" height="60" rx="8" fill="none" stroke="#35A05A" stroke-width="3" opacity="0.55"/></g></svg>
```

`Assets/Images/UI/Placeholders/stamp_belum.svg`:

```
<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(-4 150 50)"><rect x="8" y="10" width="284" height="80" rx="12" fill="none" stroke="#C0392B" stroke-width="7" opacity="0.85"/><rect x="20" y="20" width="260" height="60" rx="8" fill="none" stroke="#C0392B" stroke-width="3" opacity="0.55"/></g></svg>
```

- [ ] **Step 4: Generate the three PNGs**

Run this PowerShell, following the project's established `System.Drawing` placeholder-art convention:

```powershell
Add-Type -AssemblyName System.Drawing
$dir = "Assets/Images/UI/StudentList"
New-Item -ItemType Directory -Force $dir | Out-Null

$b = New-Object System.Drawing.Bitmap 64, 64
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$pts = @(
  (New-Object System.Drawing.Point 0,0),
  (New-Object System.Drawing.Point 64,0),
  (New-Object System.Drawing.Point 0,64)
)
$g.FillPolygon((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(205,214,190,150))), $pts)
$g.Dispose()
$b.Save("$dir/photo_corner.png", [System.Drawing.Imaging.ImageFormat]::Png)
$b.Dispose()

$b = New-Object System.Drawing.Bitmap 160, 160
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 10
$g.DrawEllipse($pen, 8, 8, 143, 143)
$pen.Dispose()
$g.Dispose()
$b.Save("$dir/roster_avatar_frame.png", [System.Drawing.Imaging.ImageFormat]::Png)
$b.Dispose()

$b = New-Object System.Drawing.Bitmap 16, 44
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2
$g.DrawLine($pen, 0, 42, 16, 42)
$pen.Dispose()
$g.Dispose()
$b.Save("$dir/catatan_rule.png", [System.Drawing.Imaging.ImageFormat]::Png)
$b.Dispose()
```

`roster_avatar_frame.png` and `catatan_rule.png` are drawn white on purpose so `self_modulate` can tint them from `DesignTokens` without a `Color()` literal in script. `catatan_rule.png` is 16x44 and tiles vertically to make ruled lines.

- [ ] **Step 5: Import and verify**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="student_list", test_name="part_three_art")`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/UI/Placeholders/icon_wirausaha.svg Assets/Images/UI/Placeholders/stamp_sudah.svg Assets/Images/UI/Placeholders/stamp_belum.svg Assets/Images/UI/StudentList tests/test_student_list.gd
git commit -m "feat(assets): add Part 3 placeholder art and the missing wirausaha icon"
```

---

### Task 3: `RosterAvatar` component

**Files:**
- Create: `Scripts/StudentList/RosterAvatar.gd`
- Create: `Scenes/StudentList/RosterAvatar.tscn`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Consumes: `roster_avatar_frame.png` (Task 2), the `GhostButton` variation (already baked).
- Produces: `class_name RosterAvatar extends Button`, with `@export var portrait_texture: Texture2D`, `@export var is_scheduled: bool`, `@export var is_current: bool`, `@export var inactive_alpha: float`. Task 6 instances four of these; Task 7 sets their state.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_student_list.gd`:

```gdscript
## RosterAvatar is @tool, so unlike student_list.gd its _ready DOES fire
## when the suite adds it to the editor root -- the ring tint below is
## applied state, not an authored default.
func test_roster_avatar_tints_its_ring_from_state_tokens() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	assert_true(packed != null, "RosterAvatar.tscn must exist")
	var tokens := DesignTokens.load_default()

	var done: RosterAvatar = packed.instantiate()
	done.is_scheduled = true
	Engine.get_main_loop().root.add_child(done)
	track(done)
	assert_eq(done.get_node("Ring").self_modulate, tokens.state_success,
		"a scheduled student's ring must read state_success")

	var todo: RosterAvatar = packed.instantiate()
	todo.is_scheduled = false
	Engine.get_main_loop().root.add_child(todo)
	track(todo)
	assert_eq(todo.get_node("Ring").self_modulate, tokens.state_danger,
		"an unscheduled student's ring must read state_danger")


func test_roster_avatar_uses_ghost_button_and_clears_touch_minimum() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	var a: RosterAvatar = packed.instantiate()
	Engine.get_main_loop().root.add_child(a)
	track(a)
	assert_eq(a.theme_type_variation, &"GhostButton",
		"the avatar is baked art behind a transparent button")
	var tokens := DesignTokens.load_default()
	var m := a.get_combined_minimum_size()
	assert_true(minf(m.x, m.y) >= float(tokens.touch_target_min),
		"avatar must clear the touch minimum, got %s" % m)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `test_run(suite="student_list", test_name="roster_avatar")`
Expected: FAIL — `RosterAvatar.tscn must exist`

- [ ] **Step 3: Write the script**

Create `Scripts/StudentList/RosterAvatar.gd`:

```gdscript
@tool
class_name RosterAvatar
extends Button

## One student's slot in the StudentList roster strip: their portrait
## inside a ring tinted green when that student's week is scheduled and
## red when it is not. Four of these sit above the carousel so the
## roster's progress reads without paging through every card, which is
## the problem this screen had -- it asks "who still needs a schedule?"
## and answered it one student at a time.
##
## @tool so the Inspector and the MCP test suite both see applied state
## rather than only authored defaults; every setter guards on
## is_node_ready(), matching StickyNote.gd's established pattern. The
## button itself is the GhostButton variation, which draws nothing at
## rest so the baked ring art can be the button.

## The student's portrait, drawn inside the ring.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			$Portrait.texture = value

## True once this student's week is scheduled. Tints the ring
## state_success; false tints it state_danger.
@export var is_scheduled: bool = false:
	set(value):
		is_scheduled = value
		if is_node_ready():
			_apply_state()

## True for the student the carousel is currently showing. The current
## avatar sits at full opacity, the rest at inactive_alpha.
@export var is_current: bool = false:
	set(value):
		is_current = value
		if is_node_ready():
			_apply_state()

## Opacity for avatars that are not the current card. Low enough to
## recede, high enough that the ring's state colour still reads.
@export_range(0.3, 1.0, 0.05) var inactive_alpha: float = 0.55


func _ready() -> void:
	$Portrait.texture = portrait_texture
	_apply_state()


func _apply_state() -> void:
	var tokens := DesignTokens.load_default()
	$Ring.self_modulate = tokens.state_success if is_scheduled else tokens.state_danger
	modulate.a = 1.0 if is_current else inactive_alpha
```

- [ ] **Step 4: Build the scene through the editor**

`scene_manage` a new scene at `res://Scenes/StudentList/RosterAvatar.tscn`, then via `batch_execute`:

- root `RosterAvatar`, type `Button`, script `res://Scripts/StudentList/RosterAvatar.gd`, `custom_minimum_size = Vector2(150, 150)`, `theme_type_variation = "GhostButton"`, `text = ""`
- child `Portrait`, type `TextureRect`, anchors 0/0/1/1, `offset_left = 14`, `offset_top = 14`, `offset_right = -14`, `offset_bottom = -14`, `expand_mode = 1`, `stretch_mode = 6`, `mouse_filter = 2`
- child `Ring`, type `TextureRect`, anchors 0/0/1/1 with zero offsets, `texture = res://Assets/Images/UI/StudentList/roster_avatar_frame.png`, `expand_mode = 1`, `stretch_mode = 6`, `mouse_filter = 2`

`node_create` appends last, so creating `Portrait` before `Ring` already puts the ring on top. `scene_save`.

- [ ] **Step 5: Run test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="student_list", test_name="roster_avatar")`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Scripts/StudentList/RosterAvatar.gd Scripts/StudentList/RosterAvatar.gd.uid Scenes/StudentList/RosterAvatar.tscn tests/test_student_list.gd
git commit -m "feat(studentlist): add the RosterAvatar strip component"
```

---

### Task 4: Extract `RosterCard`, old interior preserved

Extraction and relayout are split deliberately: this task proves the `Murid1..4` contract survives before any layout work rides on it.

**Files:**
- Create: `Scripts/StudentList/RosterCard.gd`
- Create: `Scenes/StudentList/RosterCard.tscn`
- Modify: `Scenes/StudentList/student_list.tscn`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Produces: `class_name RosterCard extends TextureRect` with `@export var student_name: String`, `@export var portrait_texture: Texture2D`, `@export var specialty: String`, `@export var persona: String`, `@export var quirk: String`, `@export var is_scheduled: bool`, and `static func compose_catatan(persona: String, quirk: String) -> String`. Task 5 lays out its interior; Task 7 reads the exports.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_student_list.gd`:

```gdscript
## The four cards are one template instanced four times now. The instance
## NAMES stay Murid1..4 because test_scene_instantiates resolves
## CardContainer/Murid%d and the tutorial's first step targets
## CardContainer -- keeping the names keeps both contracts.
func test_the_four_cards_are_rostercard_instances_under_their_old_names() -> void:
	for i in range(1, 5):
		var card := _list.get_node_or_null("CardContainer/Murid%d" % i)
		assert_true(card != null, "missing CardContainer/Murid%d" % i)
		assert_true(card is RosterCard,
			"CardContainer/Murid%d must be a RosterCard instance" % i)


## Composed from two small tables rather than a 30-entry lookup: five
## persona openers x six quirk observations.
func test_catatan_composes_persona_then_quirk() -> void:
	assert_eq(RosterCard.compose_catatan("Tekun", "Kutu Buku"),
		"Duduk paling depan, catatannya rapi. Perpustakaan sudah seperti rumah kedua.",
		"catatan must read persona opener then quirk observation")
	assert_eq(RosterCard.compose_catatan("", ""),
		"Belum ada catatan untuk murid ini.",
		"an unknown pairing must still produce a sentence")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `test_run(suite="student_list", test_name="rostercard")` and `test_run(suite="student_list", test_name="catatan")`
Expected: FAIL — `CardContainer/Murid1 must be a RosterCard instance`

- [ ] **Step 3: Write the script**

Create `Scripts/StudentList/RosterCard.gd`:

```gdscript
@tool
class_name RosterCard
extends TextureRect

## One student's paper card in the StudentList carousel. Extracted from
## four near-identical ~130-line inline subtrees (Murid1..4, about 600
## lines of student_list.tscn) so the card is authored once -- the same
## move already made for StickyNote.
##
## Instanced four times under the names Murid1..4. Those names are
## load-bearing: tests/test_student_list.gd resolves CardContainer/Murid%d
## and the tutorial's first step targets CardContainer.
##
## @tool so the Inspector and the MCP test suite see applied state, with
## every setter guarded on is_node_ready() -- StickyNote.gd's pattern.
## Every tunable is an @export on THIS root, never a property set on an
## instance's child: overrides serialise only on an instanced scene's
## root, so a value poked into a child reports success and is dropped on
## save.

## Shown on the Nama label.
@export var student_name: String = "":
	set(value):
		student_name = value
		if is_node_ready():
			$Nama.text = value

## The student's portrait, drawn in the taped frame.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			$PortraitFrame/Portrait.texture = value

## The student's hobby_category. Drives the specialty chip's label and
## icon; see SPECIALTY_ICONS.
@export var specialty: String = "":
	set(value):
		specialty = value
		if is_node_ready():
			_apply_specialty()

## The student's personality. Drives the persona chip and the catatan
## guru's opening line.
@export var persona: String = "":
	set(value):
		persona = value
		if is_node_ready():
			_apply_traits()

## The student's quirk. Drives the quirk chip and the catatan guru's
## closing observation.
@export var quirk: String = "":
	set(value):
		quirk = value
		if is_node_ready():
			_apply_traits()

## True once this student's week is scheduled. Swaps the Sudah stamp in
## for the Belum stamp.
@export var is_scheduled: bool = false:
	set(value):
		is_scheduled = value
		if is_node_ready():
			_apply_scheduled()


## Category icon per specialty, keyed by every spelling the data uses --
## hobby_category ships "Akademik" where the schedule normalises to
## "Akademis", and both must resolve.
const SPECIALTY_ICONS := {
	"Akademis": "res://Assets/Images/UI/Placeholders/icon_akademis.svg",
	"Akademik": "res://Assets/Images/UI/Placeholders/icon_akademis.svg",
	"SeniBudaya": "res://Assets/Images/UI/Placeholders/icon_seni.svg",
	"Seni Budaya": "res://Assets/Images/UI/Placeholders/icon_seni.svg",
	"Olahraga": "res://Assets/Images/UI/Placeholders/icon_olahraga.svg",
	"Istirahat": "res://Assets/Images/UI/Placeholders/icon_istirahat.svg",
	"Wirausaha": "res://Assets/Images/UI/Placeholders/icon_wirausaha.svg",
	"Libur": "res://Assets/Images/UI/Placeholders/icon_libur.svg",
}

## Opening line of the catatan guru, keyed by personality. First-draft
## Indonesian copy -- tunable here rather than buried in logic, per the
## project's tunables convention.
const CATATAN_PERSONA := {
	"Aktif": "Energinya tumpah ke mana-mana.",
	"Tekun": "Duduk paling depan, catatannya rapi.",
	"Kreatif": "Selalu punya cara sendiri.",
	"Santai": "Santai, tapi jangan diremehkan.",
	"Seni Dalam Kesunyian": "Paling tenang di kelas.",
}

## Closing observation of the catatan guru, keyed by quirk.
const CATATAN_QUIRK := {
	"Kutu Buku": "Perpustakaan sudah seperti rumah kedua.",
	"Penyendiri": "Lebih nyaman kerja sendiri daripada berkelompok.",
	"Semangat Juang": "Tidak pernah menyerah walau tertinggal.",
	"Penasaran": "Pertanyaannya sering di luar dugaan.",
	"Biang Onar": "Perlu diawasi kalau jam kosong.",
	"Pekerja Keras": "Pulang paling akhir, hampir tiap hari.",
}

## Shown when neither the persona nor the quirk resolves, so the strip is
## never blank.
const CATATAN_FALLBACK := "Belum ada catatan untuk murid ini."


## Five openers x six observations gives thirty notes from eleven
## strings. Static so it is unit-testable without instancing the scene.
static func compose_catatan(persona_name: String, quirk_name: String) -> String:
	var parts: Array[String] = []
	if CATATAN_PERSONA.has(persona_name):
		parts.append(CATATAN_PERSONA[persona_name])
	if CATATAN_QUIRK.has(quirk_name):
		parts.append(CATATAN_QUIRK[quirk_name])
	if parts.is_empty():
		return CATATAN_FALLBACK
	return " ".join(parts)


func _ready() -> void:
	$Nama.text = student_name
	$PortraitFrame/Portrait.texture = portrait_texture
	_apply_specialty()
	_apply_traits()
	_apply_scheduled()


func _apply_specialty() -> void:
	var chip: Button = $TraitRow/SpecialtyChip
	chip.text = specialty
	if SPECIALTY_ICONS.has(specialty):
		chip.icon = load(SPECIALTY_ICONS[specialty])
	else:
		chip.icon = null


func _apply_traits() -> void:
	$TraitRow/PersonaChip.text = persona
	$TraitRow/QuirkChip.text = quirk
	$CatatanGuru/CatatanLabel.text = compose_catatan(persona, quirk)


func _apply_scheduled() -> void:
	$Belum.visible = not is_scheduled
	$Sudah.visible = is_scheduled
```

- [ ] **Step 4: Build `RosterCard.tscn` with the CURRENT interior**

Create the scene with the root and the *existing* child set copied from `Murid1`, so nothing changes visually yet. Root `RosterCard`, type `TextureRect`, script attached, `texture = res://Assets/Images/UI/paper.png`, `expand_mode = 1`, `mouse_filter = 0`, anchors 0/0/1/1.

Children, each at `Murid1`'s current offsets: `CardButton`, `Belum`, `Sudah`, `Nama`, `PortraitFrame` (new `Control` wrapping the old `Portrait` TextureRect), `StickyNotesContainer` with its five `StickyNote` instances, plus two empty placeholders the script already references — `TraitRow` (`HBoxContainer` holding `SpecialtyChip`, `PersonaChip`, `QuirkChip` Buttons) and `CatatanGuru` (`Control` holding `CatatanLabel`). Give the three chips their variations now (`SpecialtyBadge`, `PersonaBadge`, `QuirkBadge`) so Task 5 only moves geometry.

`scene_save`.

- [ ] **Step 5: Replace the four subtrees in `student_list.tscn`**

`scene_open` `student_list.tscn`. Delete `CardContainer/Murid1..4`. Instance `RosterCard.tscn` four times under `CardContainer`, renaming each to `Murid1`, `Murid2`, `Murid3`, `Murid4`. Set `visible = false` on `Murid2..4`, matching today. Set each instance's `@export`s on its ROOT from `default_students`. `scene_save`.

- [ ] **Step 6: Check for clobbered scripts**

Run: `git diff HEAD -- '*.gd'`
Expected: only the files this task is editing. `scene_save` flushes stale script buffers over patched `.gd` files, so anything else appearing here must be restored with `git checkout --`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="student_list")`
Expected: PASS, including the pre-existing `test_scene_instantiates`, `test_sticky_notes_are_stickynote_instances_wired_per_day` and `test_header_and_status_badges_use_theme_variations` — this is the proof the extraction preserved the contract.

- [ ] **Step 8: Commit**

```bash
git add Scripts/StudentList/RosterCard.gd Scripts/StudentList/RosterCard.gd.uid Scenes/StudentList/RosterCard.tscn Scenes/StudentList/student_list.tscn tests/test_student_list.gd
git commit -m "refactor(studentlist): extract RosterCard from the four inline card subtrees"
```

---

### Task 5: `RosterCard` interior relayout

**Files:**
- Modify: `Scenes/StudentList/RosterCard.tscn`
- Modify: `Scripts/StudentList/StickyNote.gd`
- Modify: `Scenes/StudentList/StickyNote.tscn`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Consumes: `RosterCard`'s exports (Task 4), the stamps and `catatan_rule.png` / `photo_corner.png` (Task 2), `SpecialtyBadge` (Task 1).
- Produces: `StickyNote` gains `@export var icon_texture: Texture2D`.

Card is 940x1390. Band budget, card-local:

| Element | Rect |
|---|---|
| `Nama` | x 30–600, y 30–130 |
| `Belum` / `Sudah` | x 620–910, y 30–126 (290x96) |
| `PortraitFrame` | x 190–750, y 150–770 |
| `TraitRow` | x 30–910, y 786–882 (96 tall) |
| `StickyNotesContainer` | x 30–910, y 906–1096 |
| `CatatanGuru` | x 30–910, y 1126–1346 |

Bottom margin 1346–1390 = 44. Notes are 160x190 at x 30, 210, 390, 570, 750 — pitch 180, five across 880.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_student_list.gd`:

```gdscript
## Five notes in one row replaces the 3+2 grid, which left a lopsided
## hole in the second row and ~330px of dead paper below it.
func test_the_week_strip_is_one_row_of_five() -> void:
	var days := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	for i in range(1, 5):
		var container := _list.get_node_or_null(
			"CardContainer/Murid%d/StickyNotesContainer" % i)
		assert_true(container != null, "missing StickyNotesContainer on Murid%d" % i)
		var last_x := -1.0
		var first_y := -1.0
		for d in days:
			var note := container.get_node_or_null(d) as StickyNote
			assert_true(note != null, "missing note %s on Murid%d" % [d, i])
			if first_y < 0.0:
				first_y = note.offset_top
			assert_eq(note.offset_top, first_y,
				"%s must share the row's y on Murid%d" % [d, i])
			assert_true(note.offset_left > last_x,
				"%s must sit right of the previous note on Murid%d" % [d, i])
			last_x = note.offset_left


func test_trait_row_holds_three_chips_that_clear_the_touch_minimum() -> void:
	var tokens := DesignTokens.load_default()
	var expected := {
		"SpecialtyChip": &"SpecialtyBadge",
		"PersonaChip": &"PersonaBadge",
		"QuirkChip": &"QuirkBadge",
	}
	for i in range(1, 5):
		for chip_name in expected:
			var chip := _list.get_node_or_null(
				"CardContainer/Murid%d/TraitRow/%s" % [i, chip_name]) as Button
			assert_true(chip != null, "missing %s on Murid%d" % [chip_name, i])
			assert_eq(chip.theme_type_variation, expected[chip_name],
				"%s variation on Murid%d" % [chip_name, i])
			assert_true(chip.get_combined_minimum_size().y >= float(tokens.touch_target_min),
				"%s must clear the touch minimum on Murid%d" % [chip_name, i])


## The card's dead band becomes the teacher's note.
func test_catatan_strip_is_populated_per_student() -> void:
	for i in range(1, 5):
		var label := _list.get_node_or_null(
			"CardContainer/Murid%d/CatatanGuru/CatatanLabel" % i) as Label
		assert_true(label != null, "missing CatatanLabel on Murid%d" % i)
		assert_true(label.text.length() > 0,
			"catatan must never be blank on Murid%d" % i)


func test_sticky_notes_carry_a_category_icon() -> void:
	var note := _list.get_node_or_null(
		"CardContainer/Murid1/StickyNotesContainer/Senin") as StickyNote
	assert_true(note != null, "missing Senin note")
	assert_true("icon_texture" in note,
		"StickyNote must expose an icon_texture export")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `test_run(suite="student_list")`
Expected: FAIL — `Senin must share the row's y on Murid1` (today Kamis and Jumat sit on a second row) and `StickyNote must expose an icon_texture export`

- [ ] **Step 3: Add the icon export to `StickyNote`**

`script_patch` `Scripts/StudentList/StickyNote.gd`, inserting after the `activity` export:

```gdscript
## The schedule category's glyph, shown beside the activity name. Set
## from RosterCard so every day in the week strip reads at a glance.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			$Icon.texture = value
```

and extend `_ready()`:

```gdscript
	$Icon.texture = icon_texture
```

`StickyNote.gd` carries a `class_name`, so after this the next `project_run` fails with "Could not find script for class" until `project_manage(op="stop")`, `filesystem_manage(op="scan")` and relaunch. Do that now.

- [ ] **Step 4: Add the `Icon` node to `StickyNote.tscn`**

`scene_open` `StickyNote.tscn`, `node_create` an `Icon` `TextureRect` child, `expand_mode = 1`, `stretch_mode = 6`, `mouse_filter = 2`, sized to sit left of `ActivityLabel`. `scene_save`.

- [ ] **Step 5: Relayout `RosterCard.tscn`**

`scene_open` `RosterCard.tscn` and set the offsets from the band table above via `batch_execute`. Also:

- add `PortraitFrame/CornerTL` and `PortraitFrame/CornerBR` `TextureRect`s on `photo_corner.png`, `mouse_filter = 2`, the second rotated 180
- add `Belum/Stamp` and `Sudah/Stamp` `TextureRect`s on `stamp_belum.svg` / `stamp_sudah.svg`, anchors 0/0/1/1, `mouse_filter = 2`, moved behind the label with `move_node`
- add `CatatanGuru/Rule` `TextureRect` on `catatan_rule.png` with `stretch_mode = 1` (tile), `self_modulate` left white and tinted from script
- `CatatanLabel` takes `theme_type_variation = "CaptionLabel"`, `autowrap_mode = 3`
- resize the five `StickyNote` instances to 160x190 at x 30, 210, 390, 570, 750, all at y 0, and set each one's `icon_texture` **on the instance root**
- shorten each note's `day_name` to `SEN`, `SEL`, `RAB`, `KAM`, `JUM`

`scene_save`. Then `git diff HEAD -- '*.gd'` and restore anything unexpected.

- [ ] **Step 6: Run tests to verify they pass**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="student_list")`
Expected: PASS

Note the pre-existing `test_sticky_notes_are_stickynote_instances_wired_per_day` asserts `note.day_name == day` against full day names. Shortening the labels means that assertion moves to the note's *node name*, not `day_name` — update it in the same commit and say so in the message.

- [ ] **Step 7: Commit**

```bash
git add Scenes/StudentList/RosterCard.tscn Scenes/StudentList/StickyNote.tscn Scripts/StudentList/StickyNote.gd tests/test_student_list.gd
git commit -m "feat(studentlist): relayout the card into six bands with a catatan strip"
```

---

### Task 6: Screen relayout

**Files:**
- Create: `Scenes/StudentList/PageDot.tscn`
- Modify: `Scenes/StudentList/student_list.tscn`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Consumes: `RosterAvatar.tscn` (Task 3).
- Produces: node `RosterStrip` holding `Avatar1..4`; `PageDot.tscn` for Task 7 to instance instead of building dots in code.

Screen bands: papan header y 24–140 (x 190–890); `RosterStrip` y 155–305 (x 70–1010, avatars 150x150 at x 138, 356, 574, 792); `CardContainer` y 310–1700 (x 70–1010); nav row y 1730–1850 with `LeftArrow` x 70–230, `PageIndicator` x 440–640, `RightArrow` x 850–1010.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_roster_strip_holds_four_avatars() -> void:
	var strip := _list.get_node_or_null("RosterStrip")
	assert_true(strip != null, "missing RosterStrip")
	for i in range(1, 5):
		var a := strip.get_node_or_null("Avatar%d" % i)
		assert_true(a != null, "missing RosterStrip/Avatar%d" % i)
		assert_true(a is RosterAvatar, "Avatar%d must be a RosterAvatar" % i)


## The arrows used to sit pinned to the vertical centre of a 1920-tall
## screen, which is nowhere near a thumb. They move to a nav row with
## the page dots.
func test_navigation_sits_in_thumb_reach() -> void:
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := _list.get_node_or_null(n) as Control
		assert_true(c != null, "missing " + n)
		assert_true(c.offset_top >= 1600.0,
			"%s must sit in the lower third, got offset_top %f" % [n, c.offset_top])


func test_header_sits_on_the_papan_plaque() -> void:
	var papan := _list.get_node_or_null("Papan") as TextureRect
	assert_true(papan != null, "missing Papan plaque behind the header")
	var header := _list.get_node_or_null("HeaderLabel") as Label
	assert_true(header != null, "missing HeaderLabel")
	assert_eq(header.theme_type_variation, &"H1Label", "HeaderLabel variation")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `test_run(suite="student_list")`
Expected: FAIL — `missing RosterStrip`

- [ ] **Step 3: Create `PageDot.tscn`**

A `TextureRect` root named `PageDot`, `custom_minimum_size = Vector2(24, 24)`, `expand_mode = 1`, `stretch_mode = 6`, `mouse_filter = 2`, `texture = res://Assets/Images/UI/StudentList/roster_avatar_frame.png`. Task 7 instances it instead of building dots in `_build_page_indicators()`, which is what lowers the editability ratchet.

- [ ] **Step 4: Relayout `student_list.tscn`**

`scene_open`, then via `batch_execute`:

- `node_create` `Papan`, `TextureRect`, `texture = res://Assets/Images/UI/whiteboard.png`, offsets x 190–890 / y 24–140, `mouse_filter = 2`; `move_node` it above `HeaderLabel`
- reposition `HeaderLabel` onto the plaque (x 190–890, y 24–140)
- `node_create` `RosterStrip`, `Control`, x 70–1010, y 155–305; instance `RosterAvatar.tscn` four times under it as `Avatar1..4` at x 138, 356, 574, 792 (local x 68, 286, 504, 722), y 0, each 150x150
- reposition `CardContainer` to x 70–1010, y 310–1700 (from the anchored centre it uses today, switch to explicit anchors 0/0/0/0 plus offsets)
- move `LeftArrow` to x 70–230 / y 1730–1850, `RightArrow` to x 850–1010 / y 1730–1850, `PageIndicator` to x 440–640 / y 1770–1810; clear the arrows' `text` and set `icon = res://Assets/Images/UI/Placeholders/arrow.png`, with `RightArrow` flipped

Keep both arrows on `theme_type_variation = "SecondaryButtonL"` — `test_nav_arrows_use_theme_variation` pins it. `scene_save`, then `git diff HEAD -- '*.gd'`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="student_list")`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Scenes/StudentList/PageDot.tscn Scenes/StudentList/student_list.tscn tests/test_student_list.gd
git commit -m "feat(studentlist): papan header, roster strip and thumb-height navigation"
```

---

### Task 7: Wire the roster strip and lower the ratchet

**Files:**
- Modify: `Scripts/StudentList/student_list.gd`
- Modify: `tests/test_viewport_editability.gd`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Consumes: `RosterAvatar` exports (Task 3), `RosterCard` exports (Task 4), `PageDot.tscn` (Task 6).
- Produces: `_sync_roster_strip()` and `_on_avatar_pressed(index: int)` on `student_list.gd`.

- [ ] **Step 1: Write the failing test**

```gdscript
## Source scans, not behaviour: student_list.gd is deliberately NOT
## @tool, so its _ready never fires in the editor and nothing it would
## populate can be asserted live. See this suite's header note.
func test_roster_strip_is_wired_to_the_carousel() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("func _sync_roster_strip"),
		"the strip must resync when the card changes")
	assert_true(src.contains("func _on_avatar_pressed"),
		"tapping an avatar must jump the carousel")
	assert_true(src.contains("_switch_card("),
		"the jump must reuse the existing carousel switch")


func test_page_dots_come_from_a_template_not_from_code() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/StudentList/PageDot.tscn"),
		"page dots must instance the PageDot template")
	assert_false(src.contains("TextureRect.new()"),
		"no runtime-constructed dots")


func test_the_script_carries_a_file_header() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.begins_with("##"),
		"student_list.gd must open with a ## file header")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `test_run(suite="student_list")`
Expected: FAIL — `the strip must resync when the card changes`

- [ ] **Step 3: Add the file header**

`script_patch` `Scripts/StudentList/student_list.gd`, replacing the bare first line `extends Control` with:

```gdscript
## The roster hub. AturJadwal routes here; tapping a student's paper card
## sends that student back to AturJadwal to have their week set, and the
## player returns. So this screen exists to answer one question -- "who
## still needs a schedule?" -- which is why the RosterStrip above the
## carousel carries every student's state at once rather than making the
## player page through four cards to find out.
##
## Deliberately NOT @tool. This scene's runtime setup reads the GameState
## autoload and builds the tutorial panel dynamically, and Godot only runs
## a plain script's lifecycle callbacks inside an actually-running game
## tree -- so under the MCP test runner _ready() never fires and the suite
## asserts authored .tscn structure and source text instead. See
## tests/test_student_list.gd's header for the full finding.
extends Control
```

- [ ] **Step 4: Wire the strip**

`script_patch` in the roster sync, the avatar handler, and the templated dots:

```gdscript
const PageDotScene := preload("res://Scenes/StudentList/PageDot.tscn")


## Pushes every student's scheduled state and the current index onto the
## strip. Called after _setup_students() and from _switch_card(), so the
## strip and the carousel never disagree.
func _sync_roster_strip() -> void:
	var strip := get_node_or_null("RosterStrip")
	if strip == null:
		return
	for i in range(active_students.size()):
		var avatar := strip.get_node_or_null("Avatar%d" % (i + 1))
		if avatar == null:
			continue
		var student: Dictionary = active_students[i]
		avatar.portrait_texture = load(student.get("portrait", ""))
		avatar.is_scheduled = _is_student_scheduled(student)
		avatar.is_current = (i == current_card_index)
		if not avatar.pressed.is_connected(_on_avatar_pressed):
			avatar.pressed.connect(_on_avatar_pressed.bind(i))


## Jumps straight to a student instead of paging. Reuses the carousel's
## own switch so the slide direction and the animation guard still apply.
func _on_avatar_pressed(index: int) -> void:
	if card_animating or index == current_card_index:
		return
	var direction := 1 if index > current_card_index else -1
	_switch_card(index, direction)
```

Replace the body of `_build_page_indicators()` so it instances `PageDotScene` rather than constructing nodes, and tint each dot in `_update_page_indicators()` from `tokens.state_success` / `tokens.state_danger` to match the strip. Call `_sync_roster_strip()` at the end of `_setup_students()` and at the end of `_switch_card()`.

Implement `_is_student_scheduled(student: Dictionary) -> bool` using the same source `Belum`/`Sudah` visibility already uses in `_setup_students()`, so the strip and the stamp can never disagree.

- [ ] **Step 5: Lower the ratchet**

Run: `test_run(suite="viewport_editability")`
The `BASELINE` entry for `res://Scripts/StudentList/student_list.gd` is 8. Moving the page dots out of code lowers the real count; read the number the suite reports and set `BASELINE` to it. It may only go down — if it went up, a runtime-construction site was added and must be moved into a scene instead.

- [ ] **Step 6: Run tests to verify they pass**

Run: `test_run(suite="student_list")`, then `test_run(suite="viewport_editability")`, then `test_run(suite="script_documentation")`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add Scripts/StudentList/student_list.gd tests/test_student_list.gd tests/test_viewport_editability.gd
git commit -m "feat(studentlist): wire the roster strip and template the page dots"
```

---

### Task 8: Tutorial step for the roster strip

**Files:**
- Modify: `Scripts/StudentList/student_list.gd:506-518`
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Consumes: `RosterStrip` (Task 6), `TutorialStepData` and `_find_target_node(path_str)` (already present).

- [ ] **Step 1: Write the failing test**

```gdscript
## Three steps become four. The new one teaches the only genuinely new
## mechanic; the other three keep their targets, which still resolve
## after the relayout.
func test_tutorial_teaches_the_roster_strip() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("\"Status Jadwal\""),
		"a tutorial step must introduce the roster strip")
	assert_true(src.contains("\"RosterStrip\""),
		"that step must spotlight RosterStrip")
	assert_true(src.contains("\"CardContainer\""),
		"step 1 must still target CardContainer")
	assert_true(src.contains("\"RightArrow\""),
		"the navigation step must still target RightArrow")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `test_run(suite="student_list", test_name="tutorial_teaches")`
Expected: FAIL — `a tutorial step must introduce the roster strip`

- [ ] **Step 3: Add the step**

`script_patch` `_populate_default_tutorial_steps()`, replacing the `defaults` array:

```gdscript
	var defaults = [
		["Daftar Murid", "Disini kalian bebas memilih murid-murid yang belum terjadwalkan untuk belajar selama seminggu!", "CardContainer"],
		["Status Jadwal", "Hijau berarti sudah terjadwal, merah berarti belum. Ketuk untuk langsung ke murid itu!", "RosterStrip"],
		["Navigasi Card", "Geser layar atau tekan tombol panah kanan untuk melihat murid lainnya!", "RightArrow"],
		["Pilih Murid", "Bagus! Sekarang tekan kertas dokumen murid ini untuk mulai mengatur jadwal belajarnya!", ""]
	]
```

No new machinery is needed — `_show_step()` resolves targets by path through `_find_target_node()`, and `RosterStrip` is now a named node.

- [ ] **Step 4: Run test to verify it passes**

Run: `test_run(suite="student_list")`
Expected: PASS, including the untouched `test_debug_tutorial_bypass_skips_the_student_list_tutorial`

- [ ] **Step 5: Commit**

```bash
git add Scripts/StudentList/student_list.gd tests/test_student_list.gd
git commit -m "feat(studentlist): teach the roster strip in the tutorial"
```

---

### Task 9: Live verification and documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Verify in a running game**

`project_manage(op="stop")`, `filesystem_manage(op="scan")`, `project_run(mode="main")`. Reach StudentList: debug overlay (F1 or five taps top-right) > General > **Seed Playtest State**, then Scenes > AturJadwal, and route through to StudentList. The seed does not fill `day_schedules`, so schedule one student first to see a green avatar and a `Sudah` stamp next to three red ones.

Confirm: the roster strip reads at a glance, the arrows are thumb-reachable, the catatan strip is populated per student, and no card shows dead paper.

- [ ] **Step 2: Screenshot at full size**

`editor_screenshot(source="game", max_resolution=0)`. A scaled capture cannot show 1px detail, spacing or weight — signing off a visual change from one is how the 2026-09-10 cream pass shipped a half-finished layout.

- [ ] **Step 3: Check the game log**

Run: `logs_read(source="game")`
Expected: no `push_error`, no missing-node warnings from `RosterCard` or `RosterAvatar`.

- [ ] **Step 4: Full suite run**

Run: `test_run()` with no suite argument. Budget an editor restart afterwards — a full run drops the bridge.

Then check `git status`: a full run rebakes `Assets/Theme/kejartes_theme.tres` (wanted here, it carries `SpecialtyBadge`) and `AudioDirector` rewrites `Assets/Audio/default_bus_layout.tres` on boot (not wanted — `git checkout --` it).

- [ ] **Step 5: Record the art in outstanding debt**

In `CLAUDE.md`'s **Generated placeholder art** entry, extend the path list with the six Part 3 files rather than adding a new paragraph — the file's own rule is "group placeholders, do not list them."

- [ ] **Step 6: Write the changelog entry**

Add a `## 2026-09-10 — StudentList: roster strip and card relayout (Warm UI, Part 3)` section at the top of `docs/superpowers/CHANGELOG.md`, newest first. Cover: why the screen needed it (four problems from the spec), the `RosterCard` extraction and why the `Murid1..4` names survived, the reuse of `QuirkBadge`/`PersonaBadge`/`GhostButton` and the single new `SpecialtyBadge`, the catatan tables, the tutorial's fourth step, and the ratchet number the pass lowered `student_list.gd` to.

- [ ] **Step 7: Update `## Current work` in `CLAUDE.md`**

Point it at this pass, or clear it if the branch is done.

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md docs/superpowers/CHANGELOG.md Assets/Theme/kejartes_theme.tres
git commit -m "docs(studentlist): record Warm UI Part 3"
```

---

## Self-review

**Spec coverage.** Section 1 (extract the card) → Task 4. Section 2 (screen layout) → Task 6. Section 3 (card interior, week strip, catatan) → Task 5, with the copy tables in Task 4's script. Section 4 (art) → Task 2. Section 5 (theme) → Task 1. Section 6 (tutorial) → Task 8. Section 7 (tests, ratchet, documentation) → spread across every task's test step, with the ratchet in Task 7 Step 5 and the `##` header in Task 7 Step 3. Risks → Global Constraints. Deferred items are recorded in the spec and deliberately have no task.

**Deviations.** Three, listed under "Deviations from the spec" above and each carrying its reason: no `TraitChip` (reuse `QuirkBadge`/`PersonaBadge` + native `Button.icon`), `GhostButton` for the avatar, and a 96-tall trait row instead of 90. Task 9 Step 6 should note them in the changelog so the spec and the shipped result do not silently diverge.

**Type consistency.** `RosterCard.compose_catatan(persona_name, quirk_name)` is called in `_apply_traits()` and asserted in Task 4's test with the same signature. `RosterAvatar`'s four exports are set in Task 7's `_sync_roster_strip()` under the same names Task 3 defines. `_switch_card(new_index, direction)` matches the existing signature at `student_list.gd:329`. `_is_student_scheduled(student)` is defined and consumed in Task 7 only.
