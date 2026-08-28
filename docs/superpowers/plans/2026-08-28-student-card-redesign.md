# Student Card Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the student card's visual design — new painted background, a two-column grid of icon-labelled stat pills, a three-row bio panel, and restyled trait buttons — across both the StudentCard approval screen and the ReportCard viewer.

**Architecture:** The new background art (`page_blank.png`) has the paper, the bio panel, the portrait frame, and all five empty stat-pill *tracks* painted into it. So the card becomes one texture swap plus precise overlay positioning: five `ProgressBar` fills sitting exactly on the painted tracks, five icon clusters beside them, and text laid over the painted panel. Because all twelve card subtrees (6 per scene) share one `ext_resource` and one shared renderer, nearly every change lands in **one file** — `Scripts/StudentCard/StudentCardView.gd` — rather than being duplicated twelve times.

**Tech Stack:** Godot 4.6, GDScript, the project's `DesignTokens`/`ThemeFactory` theme pipeline, the in-editor `McpTestSuite` runner.

**Spec:** No separate design doc. This plan is written from the mockups supplied 2026-08-28 (Citra, Doni, Shinta, Marcel, Andi, Thea), the asset set delivered with them, and the decisions recorded in "Design Decisions" below.

## Global Constraints

- Godot **4.6**, GDScript. Design space is **1080×1920** (`project.godot:37-38`).
- **Never add a `theme_override_*`** carrying color, font, or stylebox information. `tests/test_student_card.gd::test_scene_has_no_theme_overrides` enforces this on the scene. Use a `ThemeFactory` type variation and rebake.
- Test suites live in `tests/test_*.gd`, extend `McpTestSuite`, and **must be `@tool`**.
- **No test may be a coroutine** — the runner calls `suite.call(name)` without awaiting; an `await` silently aborts the test and it reports "0 assertions".
- **The Godot MCP bridge is single-client.** Subagents must never call `mcp__godot-ai__*`; the controller runs every test, scan, launch, and screenshot and supplies the results. See `CLAUDE.md` → "Working efficiently here".
- After editing any `.gd`, run `filesystem_manage(op="scan")` before `test_run`, or the editor serves a stale script.
- `touch_target_min` is **96 px** (`Scripts/Design/DesignTokens.gd:102`). Any new interactive control must meet it.
- Game-facing UI text is **Indonesian**; code and comments are English.
- Conventional Commits with a scope.

## Design Decisions

Settled with the user before planning:

1. **Both screens change identically.** StudentCard and ReportCard share `StudentCardView`, so one renderer serves both.
2. **Stat pills fill like bars, with no text.** The icon identifies the stat; no name label, no value readout.
3. **Bio shows Nama / Jenis Kelamin / Tanggal Lahir.** `Agama` is dropped from display.
4. **Tap target is the icon *and* its (i) badge**, not the pill. The pill becomes non-interactive.
5. **Trait names and data stay exactly as they are.** Only the styling and the dropped `QUIRK:`/`PERSONA:` prefixes change. The mockups show renamed traits, but renaming them would silently detach gameplay effects — `StudentData.gd` branches on the exact quirk strings — so that is explicitly out of scope for this plan.

## Measured Geometry

Taken from `page_blank.png` (1080×1920) by pixel analysis. All values are card-local, and the card node is resized to exactly 1080 wide in Task 3 so these map 1:1.

| Element | x | y | w | h |
|---|---|---|---|---|
| Akademis pill track | 284 | 763 | 211 | 67 |
| SeniBudaya pill track | 284 | 888 | 211 | 67 |
| Olahraga pill track | 284 | 1014 | 211 | 67 |
| Mood pill track | 716 | 762 | 211 | 67 |
| Energy pill track | 717 | 888 | 211 | 67 |
| Portrait interior (blue) | 647 | 299 | 273 | 357 |
| Bio panel interior (purple) | 120 | 300 | 489 | 367 |
| Paper area | 52 | 238 | 993 | 1479 |

Art bounds inside the two button textures (used as `region_rect`, so no file trimming is needed):

| Texture | Canvas | Art x | y | w | h |
|---|---|---|---|---|---|
| `Progress bar fill.png` | 256×256 | 59 | 65 | 150 | 127 |
| `button_long.png` | 640×640 | 20 | 277 | 601 | 91 |

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Assets/Images/StudentCard/*` | The delivered art, imported under one folder. | Create |
| `Scripts/Design/ThemeFactory.gd` | Adds `StatPill`, `TraitPill`, `BioLabel`, `BioValue` variations. | Modify |
| `Scripts/UI/StatBar.gd` | Gains an exported `variation` so a bar can opt into `StatPill`. | Modify |
| `Scripts/StudentCard/StudentCardView.gd` | **The bulk of the work.** Positions pills, builds icon clusters, builds the bio panel, styles trait buttons. Serves both screens. | Modify |
| `Scripts/StudentCard/student_card.gd` | Roster data gains two fields; `CARD_ROW_ORDER` updated. | Modify |
| `Scripts/ReportCard/report_card.gd` | Roster data gains the same two fields. | Modify |
| `Scenes/StudentCard/student_card.tscn` | Background `ext_resource` swap; card width normalised. | Modify |
| `Scenes/ReportCard/report_card.tscn` | Same two edits. | Modify |
| `tests/test_student_card_layout.gd` | New suite pinning the redesign's contract. | Create |
| `tests/test_student_card.gd` | Existing assertions updated where the redesign moves things. | Modify |

**Why one renderer, not twelve scene edits:** every `KertasMurid1..6` in both scenes is structurally identical and shares `ExtResource("8_hodfn")`. `StudentCardView.build_stat_bars` already positions children programmatically (it sets `offset_left`, anchors, and creates an `InfoIcon` at runtime). Continuing that pattern means layout changes happen once in code instead of sixty times in `.tscn` text.

---

# Task 1: Import the art

**Files:**
- Create: `Assets/Images/StudentCard/` (8 files)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Produces: eight `res://Assets/Images/StudentCard/*.png` paths consumed by Tasks 3, 4, 6, and 8.

- [ ] **Step 1: Copy the files**

Source files are in `C:\Users\ASUS\Downloads`. Note the rename — `Progress bar fill.png` has spaces, which are awkward in `res://` paths.

```bash
cd "C:/Users/ASUS/Downloads/KejarTestAlphaVer2.15/new-game-project"
mkdir -p Assets/Images/StudentCard
cd "C:/Users/ASUS/Downloads"
TARGET="C:/Users/ASUS/Downloads/KejarTestAlphaVer2.15/new-game-project/Assets/Images/StudentCard"
cp "page_blank.png"          "$TARGET/card_bg.png"
cp "Progress bar fill.png"   "$TARGET/pill_fill.png"
cp "button_long.png"         "$TARGET/trait_button.png"
cp "info.png"                "$TARGET/icon_info.png"
cp "academy.png"             "$TARGET/stat_akademis.png"
cp "Gunungan.png"            "$TARGET/stat_senibudaya.png"
cp "athletic.png"            "$TARGET/stat_olahraga.png"
cp "mood.png"                "$TARGET/stat_mood.png"
cp "energy.png"              "$TARGET/stat_energy.png"
```

That is nine copies for eight destinations plus the background — verify nine files land.

- [ ] **Step 2: Let Godot import them**

**Controller action** (subagents cannot reach the MCP bridge):

```
filesystem_manage(op="scan")
```

Godot writes a `.import` sidecar per texture. Expected: nine `.png` files and nine `.png.import` files in `Assets/Images/StudentCard/`.

- [ ] **Step 3: Write the failing test**

Create `tests/test_student_card_layout.gd`:

```gdscript
@tool
extends McpTestSuite

## Student card redesign (2026-08-28). Pins the contract of the new layout:
## imported art, pill geometry over the painted tracks, icon clusters, and
## the bio panel. Suite is @tool and no test is a coroutine, per the runner
## constraints documented in test_lobby.gd.

const _ART := "res://Assets/Images/StudentCard/"

const _EXPECTED_ART := [
	"card_bg.png", "pill_fill.png", "trait_button.png", "icon_info.png",
	"stat_akademis.png", "stat_senibudaya.png", "stat_olahraga.png",
	"stat_mood.png", "stat_energy.png",
]


func suite_name() -> String:
	return "student_card_layout"


func test_every_redesign_texture_is_imported() -> void:
	for file_name in _EXPECTED_ART:
		var path := _ART + file_name
		assert_true(ResourceLoader.exists(path), "missing art: " + path)


func test_card_background_is_the_full_design_size() -> void:
	var tex: Texture2D = load(_ART + "card_bg.png")
	assert_eq(tex.get_width(), 1080, "card_bg must be 1080 wide")
	assert_eq(tex.get_height(), 1920, "card_bg must be 1920 tall")
```

- [ ] **Step 4: Run it and confirm it fails**

**Controller action:**

```
test_run(suite="student_card_layout")
```

Expected: FAIL before the copy, PASS after. If run after Step 2, expect PASS — in that case confirm the RED state by temporarily asserting a nonexistent filename, watching it fail, then reverting.

- [ ] **Step 5: Commit**

```bash
git add Assets/Images/StudentCard tests/test_student_card_layout.gd
git commit -m "feat(student-card): import the redesign art"
```

---

# Task 2: Add `jenis_kelamin` and `tanggal_lahir` to the roster

**Files:**
- Modify: `Scripts/StudentCard/student_card.gd` (the `student_data_list` block, around lines 874-1000)
- Modify: `Scripts/ReportCard/report_card.gd` (its own copy of the same roster)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Produces: two new string keys on every student dictionary — `"jenis_kelamin"` and `"tanggal_lahir"` — read by Task 7's bio panel.

The existing `"profil"` key stays. `GameState.convert_to_student_data_array()` copies it onto `StudentData.profil`, so removing it would break unrelated code. It simply stops being displayed.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
const _BIO := {
	"Marcel": ["Laki - Laki", "20 September"],
	"Doni":   ["Laki - Laki", "9 Maret"],
	"Andi":   ["Laki - Laki", "25 Januari"],
	"Citra":  ["Perempuan", "17 Desember"],
	"Shinta": ["Perempuan", "4 Juni"],
	"Thea":   ["Perempuan", "15 Mei"],
}


## Both screens keep their own copy of the roster, so both must carry the
## new fields or one screen renders a blank bio panel.
func test_both_rosters_carry_gender_and_birth_date() -> void:
	for script_path in ["res://Scripts/StudentCard/student_card.gd",
			"res://Scripts/ReportCard/report_card.gd"]:
		var src := FileAccess.get_file_as_string(script_path)
		for student_name in _BIO.keys():
			var gender: String = _BIO[student_name][0]
			var born: String = _BIO[student_name][1]
			assert_true(src.contains('"jenis_kelamin": "%s"' % gender),
				"%s must declare jenis_kelamin %s" % [script_path, gender])
			assert_true(src.contains('"tanggal_lahir": "%s"' % born),
				"%s must declare tanggal_lahir %s for %s"
					% [script_path, born, student_name])
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: FAIL — `tanggal_lahir` appears nowhere yet.

- [ ] **Step 3: Add the fields**

In **both** `Scripts/StudentCard/student_card.gd` and `Scripts/ReportCard/report_card.gd`, add two keys to each of the six student dictionaries, immediately after the existing `"profil"` line. Match each student by their `"name"`:

```gdscript
		"jenis_kelamin": "Laki - Laki",
		"tanggal_lahir": "20 September"
```

The six pairs, in the order the rosters declare them:

| `"name"` | `"jenis_kelamin"` | `"tanggal_lahir"` |
|---|---|---|
| Marcel | `Laki - Laki` | `20 September` |
| Doni | `Laki - Laki` | `9 Maret` |
| Andi | `Laki - Laki` | `25 Januari` |
| Citra | `Perempuan` | `17 Desember` |
| Shinta | `Perempuan` | `4 Juni` |
| Thea | `Perempuan` | `15 Mei` |

Remember the `"profil"` line currently ends without a trailing comma in each dictionary — add one before appending.

- [ ] **Step 4: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/StudentCard/student_card.gd Scripts/ReportCard/report_card.gd tests/test_student_card_layout.gd
git commit -m "feat(student-card): add gender and birth date to both rosters"
```

---

# Task 3: Swap the card background and normalise the card width

**Files:**
- Modify: `Scenes/StudentCard/student_card.tscn` (the `8_hodfn` ext_resource line; six `offset_right` values)
- Modify: `Scenes/ReportCard/report_card.tscn` (same two edits)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: `res://Assets/Images/StudentCard/card_bg.png` from Task 1.
- Produces: card nodes exactly **1080×1920**, so Task 5's measured pill offsets map 1:1.

Every `KertasMurid1..6` in both scenes references one shared `ExtResource("8_hodfn")`, so the texture swap is a single line per scene. The width fix is six lines per scene: the cards are currently 1082 wide (`offset_left = -70.0`, `offset_right = 1012.0`) against a 1080 texture, a 2 px horizontal stretch that would smear every measured offset.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
const _SCENES := [
	"res://Scenes/StudentCard/student_card.tscn",
	"res://Scenes/ReportCard/report_card.tscn",
]


## The measured pill offsets in StudentCardView assume the card is exactly
## the texture's own 1080x1920. A card of any other width stretches the
## painted tracks out from under the fills that sit on them.
func test_every_card_is_exactly_the_texture_size() -> void:
	for scene_path in _SCENES:
		var scene: Node = (load(scene_path) as PackedScene).instantiate()
		for i in range(1, 7):
			var card := scene.get_node_or_null("KertasMurid%d" % i) as Control
			assert_true(card != null, "%s missing KertasMurid%d" % [scene_path, i])
			assert_eq(card.size.x, 1080.0,
				"%s KertasMurid%d width" % [scene_path, i])
			assert_eq(card.size.y, 1920.0,
				"%s KertasMurid%d height" % [scene_path, i])
		scene.free()


func test_cards_use_the_new_background() -> void:
	for scene_path in _SCENES:
		var src := FileAccess.get_file_as_string(scene_path)
		assert_true(src.contains("Assets/Images/StudentCard/card_bg.png"),
			scene_path + " must reference the new card background")
		assert_false(src.contains("paper_placeholder.jpg"),
			scene_path + " must no longer reference the placeholder paper")
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `test_run(suite="student_card_layout")`.
Expected: FAIL on both new tests — width is 1082 and the placeholder path is still referenced.

- [ ] **Step 3: Swap the texture**

In **both** `.tscn` files, find this line:

```
[ext_resource type="Texture2D" uid="uid://b0ttj7iunp215" path="res://Assets/Images/UI/paper_placeholder.jpg" id="8_hodfn"]
```

Replace it with (dropping the stale `uid` — Godot resolves by path and rewrites the uid on next save):

```
[ext_resource type="Texture2D" path="res://Assets/Images/StudentCard/card_bg.png" id="8_hodfn"]
```

- [ ] **Step 4: Normalise the card width**

In **both** `.tscn` files, every `KertasMurid1..6` node has:

```
offset_right = 1012.0
```

Change each to:

```
offset_right = 1010.0
```

With `offset_left = -70.0` that yields exactly 1080. Leave `offset_top` and `offset_bottom` alone — they already give 1920. There are six per scene, twelve in total; check the count after editing.

- [ ] **Step 5: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`. Expected: PASS.

Then run the two existing suites, which instantiate these scenes:

```
test_run(suite="student_card")
test_run(suite="report_card")
```

Expected: PASS. If `test_interactive_controls_meet_the_minimum_touch_target` fails, the 2 px narrowing pushed a control under 96 px — report it rather than widening the card back.

- [ ] **Step 6: Commit**

```bash
git add Scenes/StudentCard/student_card.tscn Scenes/ReportCard/report_card.tscn tests/test_student_card_layout.gd
git commit -m "feat(student-card): swap in the painted background at exact design size"
```

---

# Task 4: Theme variations for the pill, trait button, and bio text

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add four variations; call the new builder from `build`)
- Modify: `Scripts/UI/StatBar.gd` (add an exported `variation`)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: `pill_fill.png` and `trait_button.png` from Task 1.
- Produces: theme type variations `StatPill`, `TraitPill`, `BioLabel`, `BioValue`; and `StatBar.variation: StringName` (default `&"StatBar"`), which Task 5 sets to `&"StatPill"`.

`StatBar` is also used by AturJadwal, SemesterEnd, and ResultCheckup, so its existing look must not change — hence a **new** variation rather than an edit to `StatBar`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_theme_factory.gd`:

```gdscript
func test_redesign_variations_exist() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	for variation in ["StatPill", "TraitPill", "BioLabel", "BioValue"]:
		assert_true(theme.has_type(variation),
			"ThemeFactory must define the " + variation + " variation")


## The card background paints the pill tracks, so the bar must draw no
## background of its own -- otherwise a second track renders on top of the
## painted one and the pill looks doubled.
func test_stat_pill_draws_no_background() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var bg := theme.get_stylebox("background", "StatPill")
	assert_true(bg is StyleBoxEmpty,
		"StatPill's background must be empty; the track is painted into the card")


func test_stat_pill_fill_uses_the_texture() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var fill := theme.get_stylebox("fill", "StatPill")
	assert_true(fill is StyleBoxTexture, "StatPill's fill must be textured")
	assert_true(fill.texture != null, "StatPill's fill texture must load")


## StatBar is shared with AturJadwal, SemesterEnd and ResultCheckup. The
## redesign must not have altered how it looks for them.
func test_stat_bar_variation_is_unchanged() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var bg := theme.get_stylebox("background", "StatBar")
	assert_true(bg is StyleBoxFlat, "StatBar keeps its flat track")
```

Also append to `tests/test_ui_components.gd`:

```gdscript
func test_stat_bar_defaults_to_its_own_variation() -> void:
	var bar := StatBar.new()
	assert_eq(bar.variation, &"StatBar",
		"an unconfigured StatBar must keep the shared look")
	bar.free()
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `test_run(suite="theme_factory")` and `test_run(suite="ui_components")`.
Expected: FAIL — none of the variations exist and `StatBar` has no `variation` property.

- [ ] **Step 3: Add the variations to `ThemeFactory.gd`**

Add this function after `_build_progress`:

```gdscript
# ------------------------------------------------- student card redesign

const _CARD_ART := "res://Assets/Images/StudentCard/"


## Variations used only by the student card's redesigned layout. The card
## background art paints the pill tracks, the bio panel, and the portrait
## frame, so these styles deliberately draw less than their siblings: the
## pill contributes only a fill, and the bio text is light because it sits
## on the painted purple panel.
static func _build_student_card(theme: Theme, tokens: DesignTokens) -> void:
	# -- Stat pill: fill only; the track is painted into the card art. --
	theme.add_type("StatPill")
	theme.set_type_variation("StatPill", "ProgressBar")
	theme.set_stylebox("background", "StatPill", StyleBoxEmpty.new())

	var pill_fill := StyleBoxTexture.new()
	pill_fill.texture = load(_CARD_ART + "pill_fill.png")
	# The art sits inset on a 256x256 canvas; region_rect crops to it so no
	# transparent padding is stretched into the bar.
	pill_fill.region_rect = Rect2(59, 65, 150, 127)
	# 28 px keeps both rounded ends intact inside a 67 px tall track
	# (28 + 28 < 67); anything larger would overlap and distort them.
	pill_fill.set_texture_margin_all(28)
	theme.set_stylebox("fill", "StatPill", pill_fill)

	# -- Trait button: one recolourable pill, tinted by the caller. --
	theme.add_type("TraitPill")
	theme.set_type_variation("TraitPill", "Button")

	var trait_normal := StyleBoxTexture.new()
	trait_normal.texture = load(_CARD_ART + "trait_button.png")
	trait_normal.region_rect = Rect2(20, 277, 601, 91)
	trait_normal.set_texture_margin_all(45)
	theme.set_stylebox("normal", "TraitPill", trait_normal)
	theme.set_stylebox("hover", "TraitPill", trait_normal)
	theme.set_stylebox("pressed", "TraitPill", trait_normal)
	theme.set_stylebox("focus", "TraitPill", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "TraitPill", tokens.font_body_size)
	theme.set_color("font_color", "TraitPill", tokens.text_on_brand)

	# -- Bio text: light, because it sits on the painted purple panel. --
	theme.add_type("BioLabel")
	theme.set_type_variation("BioLabel", "Label")
	theme.set_font_size("font_size", "BioLabel", tokens.font_body_size)
	theme.set_color("font_color", "BioLabel", tokens.text_on_brand)

	theme.add_type("BioValue")
	theme.set_type_variation("BioValue", "Label")
	theme.set_font_size("font_size", "BioValue", tokens.font_body_size + 6)
	theme.set_color("font_color", "BioValue", tokens.text_on_brand)
```

Then call it from `build`, immediately after the existing `_build_progress(theme, tokens)` call:

```gdscript
	_build_student_card(theme, tokens)
```

- [ ] **Step 4: Make `StatBar`'s variation configurable**

In `Scripts/UI/StatBar.gd`, add this export beside the existing `category` export:

```gdscript
## Which theme variation this bar wears. The student card's redesigned
## pills use "StatPill", whose track is painted into the card art; every
## other screen keeps the shared "StatBar" look.
@export var variation: StringName = &"StatBar":
	set(value):
		variation = value
		if is_inside_tree():
			theme_type_variation = value
```

Then, in `_ready()`, replace this line:

```gdscript
	theme_type_variation = &"StatBar"
```

with:

```gdscript
	theme_type_variation = variation
```

- [ ] **Step 5: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")`, then `test_run(suite="theme_factory")` and `test_run(suite="ui_components")`. Expected: PASS.

- [ ] **Step 6: Rebake the theme — MANUAL, ask the user**

`ThemeFactory` only describes the theme; `Assets/Theme/kejartes_theme.tres` is what the game loads, and it is regenerated by `Scripts/Design/BakeTheme.gd`, an `EditorScript`. **There is no MCP op that runs an EditorScript**, so this step cannot be automated from this session.

Ask the user to do exactly this in the Godot editor:

> Open `Scripts/Design/BakeTheme.gd` in the Script editor and press **Ctrl+Shift+X** (File > Run). The Output panel should print `BakeTheme: wrote res://Assets/Theme/kejartes_theme.tres (N types)`.

Then verify from this session:

```
filesystem_manage(op="scan")
```

```bash
git diff --stat Assets/Theme/kejartes_theme.tres
grep -c 'StatPill\|TraitPill\|BioLabel\|BioValue' Assets/Theme/kejartes_theme.tres
```

Expected: the `.tres` shows as modified, and the grep count is greater than zero. **Do not proceed to Task 5 until it is** — every later task depends on the baked variations existing.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Scripts/UI/StatBar.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd tests/test_ui_components.gd
git commit -m "feat(student-card): add StatPill, TraitPill and bio text variations"
```

---

# Task 5: Position the stat pills over the painted tracks

**Files:**
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_stat_bars`, lines 117-243)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: `StatBar.variation` and the `StatPill` variation from Task 4; the 1080-wide cards from Task 3.
- Produces: `StudentCardView.PILL_RECTS: Dictionary` mapping bar name → `Rect2`, read by Task 6 to place each icon cluster beside its pill.

The five bars keep their node names (`Kepribadian1`, `Kepribadian2`, `Akademis1`, `Akademis2`, `Akademis3`) and their categories — `tests/test_student_card.gd::test_stat_bars_are_statbars_with_a_category` and `::test_tutorial_target_node_paths_are_unchanged` both depend on that. Only their geometry, styling, and children change.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
## The painted tracks are at fixed pixel positions in the card art, so the
## fills must land exactly on them.
const _EXPECTED_PILLS := {
	"Akademis1": Rect2(284, 763, 211, 67),
	"Akademis2": Rect2(284, 888, 211, 67),
	"Akademis3": Rect2(284, 1014, 211, 67),
	"Kepribadian1": Rect2(716, 762, 211, 67),
	"Kepribadian2": Rect2(717, 888, 211, 67),
}


func test_pill_rects_match_the_painted_tracks() -> void:
	for bar_name in _EXPECTED_PILLS.keys():
		assert_true(StudentCardView.PILL_RECTS.has(bar_name),
			"PILL_RECTS must cover " + bar_name)
		assert_eq(StudentCardView.PILL_RECTS[bar_name], _EXPECTED_PILLS[bar_name],
			"PILL_RECTS[%s] must sit on the painted track" % bar_name)


## The pill shows no text at all in the new design -- the icon beside it
## says which stat it is.
func test_bars_carry_no_text_children() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_false(src.contains('val_lbl.text = "%d / %d"'),
		"the value readout must be gone from the redesigned pill")
	assert_true(src.contains('variation = &"StatPill"'),
		"card bars must opt into the StatPill variation")
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: FAIL — `PILL_RECTS` does not exist.

- [ ] **Step 3: Replace `build_stat_bars`**

In `Scripts/StudentCard/StudentCardView.gd`, replace the whole of `build_stat_bars` (from `static func build_stat_bars` through the end of that function, just before `static func _style_trait_badge`) with:

```gdscript
## Where each pill's fill sits, in card-local pixels. These are the exact
## positions of the tracks painted into card_bg.png, measured from the art;
## the card is sized to the texture's own 1080x1920 so they map 1:1.
const PILL_RECTS := {
	"Akademis1": Rect2(284, 763, 211, 67),
	"Akademis2": Rect2(284, 888, 211, 67),
	"Akademis3": Rect2(284, 1014, 211, 67),
	"Kepribadian1": Rect2(716, 762, 211, 67),
	"Kepribadian2": Rect2(717, 888, 211, 67),
}


## Lays each bar's fill onto its painted track. The redesign moves all
## labelling out of the bar: no stat name, no value readout, and no
## magnifying glass -- the icon cluster beside the pill (see
## build_icon_clusters) both names the stat and carries the tap.
static func build_stat_bars(kertas: Control, s_data: Dictionary, _icon_magnify: Texture2D,
		_on_bar_input: Callable) -> void:
	var values := {
		"Kepribadian1": s_data.get("kepribadian1", 0),
		"Kepribadian2": s_data.get("kepribadian2", 0),
		"Akademis1": s_data.get("akademis1", 0),
		"Akademis2": s_data.get("akademis2", 0),
		"Akademis3": s_data.get("akademis3", 0),
	}

	for bar_name in PILL_RECTS.keys():
		var bar = kertas.get_node_or_null(bar_name)
		if bar == null or not bar is ProgressBar:
			continue

		var rect: Rect2 = PILL_RECTS[bar_name]
		bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bar.offset_left = rect.position.x
		bar.offset_top = rect.position.y
		bar.offset_right = rect.position.x + rect.size.x
		bar.offset_bottom = rect.position.y + rect.size.y
		bar.show_percentage = false

		# The pill is decoration now; the icon cluster takes the input.
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Drop the children the old bar carried: the stat-name label, the
		# value readout, and the magnifier. Leaving any of them would draw
		# text on a pill the design wants blank.
		for child_name in ["Label", "ValueLabel", "InfoIcon"]:
			var stale = bar.get_node_or_null(child_name)
			if stale != null:
				bar.remove_child(stale)
				stale.queue_free()

		if bar is StatBar:
			bar.variation = &"StatPill"
			bar.set_stat(values[bar_name])
		else:
			bar.value = values[bar_name]
```

The two unused parameters keep the signature stable for `populate`'s existing call; Task 6 removes them.

- [ ] **Step 4: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`. Expected: PASS.

Then confirm nothing regressed in the suites that instantiate these scenes:

```
test_run(suite="student_card")
test_run(suite="report_card")
```

Expected: PASS. `test_stat_bars_are_statbars_with_a_category` must still pass — the bars kept their names and categories.

- [ ] **Step 5: Commit**

```bash
git add Scripts/StudentCard/StudentCardView.gd tests/test_student_card_layout.gd
git commit -m "feat(student-card): lay the stat fills onto the painted tracks"
```

---

# Task 6: Icon clusters and the new tap target

**Files:**
- Modify: `Scripts/StudentCard/StudentCardView.gd` (new `build_icon_clusters`; `populate` calls it)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: `PILL_RECTS` from Task 5; the five `stat_*.png` icons and `icon_info.png` from Task 1.
- Produces: five nodes named `IconAkademis1`, `IconAkademis2`, `IconAkademis3`, `IconKepribadian1`, `IconKepribadian2`, each a direct child of the card, each 128×128 and carrying the bar's `gui_input` binding.

The clusters are **siblings of the bars, not children**, so every tutorial path (`KertasMurid1/Kepribadian1` and friends) keeps resolving. 128×128 clears the 96 px `touch_target_min`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
const _ICON_NODES := [
	"IconAkademis1", "IconAkademis2", "IconAkademis3",
	"IconKepribadian1", "IconKepribadian2",
]


## The icon replaces the bar's old name label, and with the magnifier gone
## it is also the only thing the player can tap for information -- so it
## has to clear the touch minimum on its own.
func test_icon_clusters_exist_and_meet_the_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var scene: Node = (load("res://Scenes/StudentCard/student_card.tscn")
		as PackedScene).instantiate()
	scene.theme = load("res://Assets/Theme/kejartes_theme.tres")
	Engine.get_main_loop().root.add_child(scene)
	track(scene)

	for icon_name in _ICON_NODES:
		var icon := scene.get_node_or_null("KertasMurid1/" + icon_name) as Control
		assert_true(icon != null, "missing icon cluster: " + icon_name)
		var side: float = minf(icon.size.x, icon.size.y)
		assert_true(side >= float(tokens.touch_target_min),
			"%s is %d px, below the %d px minimum"
				% [icon_name, int(side), tokens.touch_target_min])


func test_the_pill_no_longer_takes_input() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_true(src.contains("bar.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"the pill must be inert; the icon cluster carries the tap")
	assert_false(src.contains("icon_magnify"),
		"the magnifying glass is replaced by the stat icons")
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: FAIL — no `IconAkademis1` node exists, and `icon_magnify` is still referenced.

- [ ] **Step 3: Build the clusters**

Add to `Scripts/StudentCard/StudentCardView.gd`, after `build_stat_bars`:

```gdscript
const _ICON_SIZE := 128.0
## Gap between the icon's right edge and the pill's left edge.
const _ICON_GAP := 24.0
## The (i) badge, overlapping the icon's bottom-right corner.
const _BADGE_SIZE := 56.0

const _STAT_ICONS := {
	"Akademis1": "stat_akademis.png",
	"Akademis2": "stat_senibudaya.png",
	"Akademis3": "stat_olahraga.png",
	"Kepribadian1": "stat_mood.png",
	"Kepribadian2": "stat_energy.png",
}


## One tappable icon per stat, sitting left of its pill and vertically
## centred on it. Each carries a small (i) badge so the icon reads as
## something you can press.
##
## These are siblings of the bars rather than children on purpose: the
## tutorial addresses bars by string path (`KertasMurid1/Kepribadian1`),
## so nothing may be re-parented under them.
static func build_icon_clusters(kertas: Control, s_data: Dictionary,
		on_bar_input: Callable) -> void:
	for bar_name in _STAT_ICONS.keys():
		var rect: Rect2 = PILL_RECTS[bar_name]
		var node_name := "Icon" + bar_name

		var cluster := kertas.get_node_or_null(node_name) as TextureRect
		if cluster == null:
			cluster = TextureRect.new()
			cluster.name = node_name
			kertas.add_child(cluster)

			var badge := TextureRect.new()
			badge.name = "InfoBadge"
			badge.texture = load(_CARD_ART + "icon_info.png")
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.offset_left = -_BADGE_SIZE
			badge.offset_top = -_BADGE_SIZE
			badge.offset_right = 0.0
			badge.offset_bottom = 0.0
			cluster.add_child(badge)

		cluster.texture = load(_CARD_ART + _STAT_ICONS[bar_name])
		cluster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cluster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cluster.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cluster.offset_left = rect.position.x - _ICON_GAP - _ICON_SIZE
		cluster.offset_top = rect.position.y + rect.size.y * 0.5 - _ICON_SIZE * 0.5
		cluster.offset_right = cluster.offset_left + _ICON_SIZE
		cluster.offset_bottom = cluster.offset_top + _ICON_SIZE

		cluster.mouse_filter = Control.MOUSE_FILTER_STOP
		cluster.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var callable := on_bar_input.bind(kertas, bar_name, s_data)
		if cluster.has_meta("cluster_gui_callable"):
			cluster.gui_input.disconnect(cluster.get_meta("cluster_gui_callable"))
		cluster.gui_input.connect(callable)
		cluster.set_meta("cluster_gui_callable", callable)
```

`_CARD_ART` is declared in `ThemeFactory`; add the same constant to `StudentCardView.gd` near the top of the file, below `extends RefCounted`:

```gdscript
const _CARD_ART := "res://Assets/Images/StudentCard/"
```

- [ ] **Step 4: Call it from `populate` and drop the magnifier**

In `populate`, replace this line:

```gdscript
	build_stat_bars(card, student, icon_magnify, on_bar_input)
```

with:

```gdscript
	build_stat_bars(card, student, on_bar_input)
	build_icon_clusters(card, student, on_bar_input)
```

Change `populate`'s own signature to drop the now-unused texture:

```gdscript
static func populate(card: Control, student: Dictionary,
		on_bar_input: Callable, on_badge_hover_enter: Callable,
		on_badge_hover_exit: Callable, on_badge_pressed: Callable) -> void:
```

And change `build_stat_bars`'s signature to match:

```gdscript
static func build_stat_bars(kertas: Control, s_data: Dictionary,
		_on_bar_input: Callable) -> void:
```

Both callers pass `icon_magnify` and must be updated:
- `Scripts/StudentCard/student_card.gd` — two `StudentCardView.populate(` calls; drop the `icon_magnify` argument from each.
- `Scripts/ReportCard/report_card.gd:57` and `:66` — same.

Leave the `@export var icon_magnify` declaration in `student_card.gd` alone; removing an export changes the scene's serialised properties, which is a bigger edit than this task needs.

- [ ] **Step 5: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then:

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/StudentCard/StudentCardView.gd Scripts/StudentCard/student_card.gd Scripts/ReportCard/report_card.gd tests/test_student_card_layout.gd
git commit -m "feat(student-card): add tappable stat icons, retire the magnifier"
```

---

# Task 7: The bio panel

**Files:**
- Modify: `Scripts/StudentCard/StudentCardView.gd` (new `build_bio_panel`; `populate` calls it)
- Modify: `Scripts/StudentCard/student_card.gd` (`CARD_ROW_ORDER`, line 735)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: `jenis_kelamin` and `tanggal_lahir` from Task 2.
- Produces: a `BioPanel` VBoxContainer on each card, replacing the `Profil` label as the bio surface.

The purple panel itself is painted into the background, so this task only lays text on top of it. The old `Profil`, `Kepribadian`, and `Akademis` labels are hidden — the first is superseded, and the latter two were section headers the new design has no room for.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
func test_bio_panel_renders_the_three_rows() -> void:
	var scene: Node = (load("res://Scenes/StudentCard/student_card.tscn")
		as PackedScene).instantiate()
	scene.theme = load("res://Assets/Theme/kejartes_theme.tres")
	Engine.get_main_loop().root.add_child(scene)
	track(scene)

	var panel := scene.get_node_or_null("KertasMurid1/BioPanel") as Control
	assert_true(panel != null, "KertasMurid1 must have a BioPanel")

	var texts: Array[String] = []
	for child in panel.get_children():
		if child is Label:
			texts.append((child as Label).text)
	for heading in ["Nama:", "Jenis Kelamin:", "Tanggal Lahir:"]:
		assert_true(texts.has(heading), "BioPanel must show the row " + heading)


## The panel is painted into the card art; the text must land inside it.
func test_bio_panel_sits_inside_the_painted_panel() -> void:
	var scene: Node = (load("res://Scenes/StudentCard/student_card.tscn")
		as PackedScene).instantiate()
	scene.theme = load("res://Assets/Theme/kejartes_theme.tres")
	Engine.get_main_loop().root.add_child(scene)
	track(scene)

	var panel := scene.get_node_or_null("KertasMurid1/BioPanel") as Control
	assert_true(panel.position.x >= 120.0, "BioPanel must start inside the paint")
	assert_true(panel.position.y >= 300.0, "BioPanel must start inside the paint")
	assert_true(panel.position.x + panel.size.x <= 609.0,
		"BioPanel must end inside the paint")


func test_superseded_labels_are_hidden() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	for label_name in ["Profil", "Kepribadian", "Akademis"]:
		assert_true(src.contains('"%s"' % label_name),
			"StudentCardView must account for the old label " + label_name)
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: FAIL — no `BioPanel` node exists.

- [ ] **Step 3: Build the panel**

Add to `Scripts/StudentCard/StudentCardView.gd`, after `build_icon_clusters`:

```gdscript
## The painted purple panel's interior, in card-local pixels, measured from
## card_bg.png.
const BIO_PANEL_RECT := Rect2(120, 300, 489, 367)
## Inset so the text does not crowd the painted panel's rounded border.
const _BIO_PADDING := 32.0


## Lays the three bio rows over the painted panel: a heading and a value
## per row. The panel art itself comes from the card background, so this
## only positions text.
##
## Also hides the three labels the redesign supersedes -- `Profil` (whose
## content these rows replace) and the `Kepribadian` / `Akademis` section
## headings, which the icon-led layout has no room for.
static func build_bio_panel(kertas: Control, s_data: Dictionary) -> void:
	for stale_name in ["Profil", "Kepribadian", "Akademis"]:
		var stale := kertas.get_node_or_null(stale_name) as CanvasItem
		if stale != null:
			stale.visible = false

	var panel := kertas.get_node_or_null("BioPanel") as VBoxContainer
	if panel == null:
		panel = VBoxContainer.new()
		panel.name = "BioPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kertas.add_child(panel)

	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = BIO_PANEL_RECT.position.x + _BIO_PADDING
	panel.offset_top = BIO_PANEL_RECT.position.y + _BIO_PADDING
	panel.offset_right = BIO_PANEL_RECT.end.x - _BIO_PADDING
	panel.offset_bottom = BIO_PANEL_RECT.end.y - _BIO_PADDING

	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var rows := [
		["Nama:", str(s_data.get("name", ""))],
		["Jenis Kelamin:", str(s_data.get("jenis_kelamin", ""))],
		["Tanggal Lahir:", str(s_data.get("tanggal_lahir", ""))],
	]
	for row in rows:
		var heading := Label.new()
		heading.text = row[0]
		heading.theme_type_variation = &"BioLabel"
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(heading)

		var value := Label.new()
		value.text = row[1]
		value.theme_type_variation = &"BioValue"
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(value)
```

- [ ] **Step 4: Call it and update the stagger order**

In `populate`, add this immediately after the `build_icon_clusters(...)` call:

```gdscript
	build_bio_panel(card, student)
```

Delete the block in `populate` that writes the old profil text — these five lines:

```gdscript
	# Update Profil
	var profil_label = card.get_node_or_null("Profil")
	if profil_label and profil_label is Label:
		var p_text = "Nama: " + student.get("name", "") + "\n\n"
		p_text += student.get("profil", "")
		profil_label.text = p_text
```

In `Scripts/StudentCard/student_card.gd`, replace `CARD_ROW_ORDER` (line 735) with:

```gdscript
const CARD_ROW_ORDER := ["Nama", "BioPanel", "IconAkademis1", "Akademis1",
	"IconAkademis2", "Akademis2", "IconAkademis3", "Akademis3",
	"IconKepribadian1", "Kepribadian1", "IconKepribadian2", "Kepribadian2",
	"KutuBuku", "KutuBuku2"]
```

This is what the eye follows down the redesigned card: bio, then the skills column, then the needs column, then the traits. `_stagger_in_card` already skips names that do not resolve, so no other change is needed.

- [ ] **Step 5: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then:

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/StudentCard/StudentCardView.gd Scripts/StudentCard/student_card.gd tests/test_student_card_layout.gd
git commit -m "feat(student-card): render the bio rows over the painted panel"
```

---

# Task 8: Restyle the trait buttons

**Files:**
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`populate`'s two `_style_trait_badge` calls; `_style_trait_badge` itself)
- Modify: `Scenes/StudentCard/student_card.tscn` (12 authored variation lines)
- Modify: `Scenes/ReportCard/report_card.tscn` (12 authored variation lines)
- Modify: `tests/test_student_card.gd:131-142` (`test_action_buttons_use_theme_variations`)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: the `TraitPill` variation from Task 4.
- Produces: `KutuBuku` and `KutuBuku2` wearing `TraitPill` with bare trait text.

Per Design Decision 5, the trait **values** are untouched — only the prefixes and the styling change.

**Why the scenes change too.** Both `.tscn` files author `theme_type_variation = &"QuirkBadge"` / `&"PersonaBadge"` on these buttons, and `_style_trait_badge` overwrites it at runtime. Changing only the runtime would leave the scene claiming one style while the player sees another — and `tests/test_student_card.gd::test_action_buttons_use_theme_variations` reads the *authored* value (it never calls `populate`), so it would keep asserting a style that no longer renders. Updating both keeps them honest.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
func test_trait_buttons_use_the_trait_pill_variation() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_true(src.contains('&"TraitPill"'),
		"trait buttons must wear the TraitPill variation")
	assert_false(src.contains('"QUIRK: "'),
		"the QUIRK: prefix is dropped in the redesign")
	assert_false(src.contains('"PERSONA: "'),
		"the PERSONA: prefix is dropped in the redesign")


## Renaming a quirk detaches its gameplay effect -- StudentData.gd branches
## on the exact string -- so the redesign changes only how they are shown.
func test_trait_values_are_unchanged() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/student_card.gd")
	for quirk in ["Kutu Buku", "Semangat Juang", "Penasaran",
			"Penyendiri", "Biang Onar", "Pekerja Keras"]:
		assert_true(src.contains('"quirk": "%s"' % quirk),
			"quirk must keep its gameplay name: " + quirk)
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: FAIL — the prefixes are still there and `TraitPill` is unused.

- [ ] **Step 3: Drop the prefixes**

In `populate`, replace the two `_style_trait_badge` calls with:

```gdscript
	StudentCardView._style_trait_badge(card, "KutuBuku", "quirk",
		student.get("quirk", "-"), student,
		on_badge_hover_enter, on_badge_hover_exit, on_badge_pressed)
	StudentCardView._style_trait_badge(card, "KutuBuku2", "persona",
		student.get("persona", "-").replace("Persona ", ""), student,
		on_badge_hover_enter, on_badge_hover_exit, on_badge_pressed)
```

- [ ] **Step 4: Switch the variation**

In `_style_trait_badge`, replace this line:

```gdscript
	btn.theme_type_variation = &"QuirkBadge" if trait_type == "quirk" else &"PersonaBadge"
```

with:

```gdscript
	# Both traits wear one pill now; the design distinguishes them by
	# position under the "Sifat Pasif" heading, not by colour.
	btn.theme_type_variation = &"TraitPill"
```

- [ ] **Step 5: Update the authored variation in both scenes**

In **both** `Scenes/StudentCard/student_card.tscn` and `Scenes/ReportCard/report_card.tscn`, replace every occurrence of:

```
theme_type_variation = &"QuirkBadge"
```

and

```
theme_type_variation = &"PersonaBadge"
```

with:

```
theme_type_variation = &"TraitPill"
```

There are exactly **6 of each per scene — 24 lines in total**. Verify with:

```bash
grep -c 'theme_type_variation = &"TraitPill"' Scenes/StudentCard/student_card.tscn Scenes/ReportCard/report_card.tscn
grep -c 'QuirkBadge\|PersonaBadge' Scenes/StudentCard/student_card.tscn Scenes/ReportCard/report_card.tscn
```

Expected: `12` for each scene on the first command, `0` on the second.

Leave the `QuirkBadge` and `PersonaBadge` variations in `ThemeFactory.gd` — nothing else uses them today, but deleting them is a separate cleanup and would force another manual rebake.

- [ ] **Step 6: Update the existing variation assertion**

In `tests/test_student_card.gd`, in `test_action_buttons_use_theme_variations`, change these two lines:

```gdscript
		"KertasMurid1/KutuBuku": &"QuirkBadge",
		"KertasMurid1/KutuBuku2": &"PersonaBadge",
```

to:

```gdscript
		"KertasMurid1/KutuBuku": &"TraitPill",
		"KertasMurid1/KutuBuku2": &"TraitPill",
```

- [ ] **Step 7: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then:

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
```

Expected: all PASS. `test_interactive_controls_meet_the_minimum_touch_target` covers `KutuBuku` and `KutuBuku2` — if either drops below 96 px, report it rather than shrinking the assertion.

- [ ] **Step 8: Commit**

```bash
git add Scripts/StudentCard/StudentCardView.gd Scenes/StudentCard/student_card.tscn Scenes/ReportCard/report_card.tscn tests/test_student_card.gd tests/test_student_card_layout.gd
git commit -m "feat(student-card): restyle the trait buttons, drop the prefixes"
```

---

# Task 9: Full verification and the visual pass

**Files:**
- Modify: whichever files the visual pass turns out to need

**Interfaces:**
- Consumes: everything above.
- Produces: a verified build and a record of any offsets that needed nudging.

Automated tests prove structure, not that the art lines up. This task is where a human eye is required.

- [ ] **Step 1: Run every suite**

**Controller action:**

```
filesystem_manage(op="scan")
test_run()
```

Expected: every suite passes except the known pre-existing `audio_director / test_volumes_persist_across_a_fresh_director` ("0 assertions" — it is a coroutine and the runner does not await it; documented in `CLAUDE.md` → Known issues). Any other failure is a real regression from this plan.

- [ ] **Step 2: Look at the StudentCard screen**

**Controller action:**

```
project_run(mode="main")
game_manage(op="input_key", params={"key": "F1", "pressed": true})
```

Click **⚡ Seed Playtest State** at the top of the General tab, then the **Scenes** tab, then **Teleport ke: Pilih Murid (StudentCard)**. Remember a `motion` event must precede each `button` press or Godot will not route the click, and window coordinates are `global_x * original_width / 1080`.

```
editor_screenshot(source="game")
```

Check against the mockups, in this order:
1. The five pill fills sit **exactly** on the painted tracks — no offset, no fill wider or narrower than its track.
2. Each icon sits left of its pill, vertically centred, with its (i) badge on the bottom-right.
3. The three bio rows sit inside the purple panel and do not overflow it.
4. The portrait fills its painted frame.
5. Both trait buttons read as bare trait names under "Sifat Pasif".
6. The old stat-name labels, value readouts, and magnifiers are all gone.

- [ ] **Step 3: Look at the ReportCard screen**

Back out to the Lobby, then **REPORT STUDENT**. Take one screenshot and confirm it matches the StudentCard — both screens go through the same renderer, so any difference is a bug.

- [ ] **Step 4: Nudge whatever is off**

Every layout number lives in one of four constants in `StudentCardView.gd`: `PILL_RECTS`, `_ICON_SIZE`/`_ICON_GAP`/`_BADGE_SIZE`, `BIO_PANEL_RECT`, and `_BIO_PADDING`. Adjust there, never with per-node offsets in the scene.

If a pill's fill is visibly inset from its painted track, the `set_texture_margin_all(28)` in `ThemeFactory._build_student_card` is too large for a 67 px track — reduce it and rebake (Task 4 Step 6, manual).

- [ ] **Step 5: Stop the game and restore the editor scene**

**Controller action:**

```
project_manage(op="stop")
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
```

Leaving the main scene open matters — `test_run` warns and some suites report phantom failures otherwise. Then check the tree: a run dirties `Assets/Audio/default_bus_layout.tres` (the known audio-test artifact) and can re-serialise `Scenes/Splashscreen/Splashscreen.tscn`. Revert both; neither belongs to this work.

- [ ] **Step 6: Commit any adjustments**

```bash
git add Scripts/StudentCard/StudentCardView.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres
git commit -m "fix(student-card): align the overlays with the painted art"
```

---

## Deferred

Recorded so they are not lost, but deliberately out of scope:

- **The renamed traits.** The mockups show twelve new trait names (`Muka Penjual`, `Pengguru`, `Atletik`, `Kamu Gak Diajak`, `Suka Keramaian`, `Santai Dulu Gak Sih`, …) and move `Penasaran` from Andi to Shinta. `StudentData.gd` branches on the exact quirk strings at eleven sites, so adopting them without a mapping would silently strip Doni's `Semangat Juang` bonuses, Thea's `Pekerja Keras` discount, and Andi's `Penasaran` effects. This needs its own decision about whether the *mechanics* follow the name or the student — a balance change, not a visual one.
- **`Agama` (religion).** Dropped from display but still present in each roster's `profil` string, which `StudentData.profil` consumes. Removing the field entirely is a separate cleanup.
- **The mockups' cream variant.** Five of the six mockups show cream paper, no bio panel, black icons and no (i) badges. The delivered `card_bg.png` is the mint version with the panel painted in, so that is what this plan builds. If the cream direction is preferred later, it is a new background plus a re-measure — the code reads all its geometry from constants.
- **Approve / Batal / Belajar buttons.** Untouched by this plan; they keep their current position and styling in the space below the trait buttons. The mockups do not show them.

## Self-Review

**Coverage.** Each of the five Design Decisions maps to a task: (1) is structural — one renderer, exercised by every task's `report_card` run; (2) Tasks 4-5; (3) Tasks 2 and 7; (4) Task 6; (5) Task 8 plus the `test_trait_values_are_unchanged` guard.

**Placeholders.** None. Every step carries the literal code or the exact command and its expected result.

**Type consistency.** `PILL_RECTS` is defined in Task 5 and consumed by Task 6's `build_icon_clusters` and Task 7's neighbour constant. `StatBar.variation: StringName` is added in Task 4 and set in Task 5. `_CARD_ART` is declared in both `ThemeFactory.gd` and `StudentCardView.gd` — deliberately, since neither imports the other. `populate`'s signature changes in Task 6 and all four call sites are named there.

**Existing tests this plan touches.** Checked by grep rather than assumed:
- `test_student_card.gd::test_action_buttons_use_theme_variations` asserts the badge variations — updated in Task 8 Step 6.
- `test_student_card.gd::test_stat_bars_are_statbars_with_a_category` and `::test_tutorial_target_node_paths_are_unchanged` both survive untouched, because every bar keeps its node name, its type, and its category.
- `test_ui_components.gd:131` asserts a `ValueLabel` exists — that is `StatBar.show_value_label` building its own label on a bar the test constructs, not the card's. Task 5 removes the card's `ValueLabel` only, so this is unaffected.
- `test_student_card.gd::test_scene_has_no_theme_overrides` stays green: every style added here is a theme variation, never a per-node override.

**Known risks.**
1. **The manual rebake (Task 4 Step 6).** No MCP op runs an `EditorScript`. Tasks 5-8 all depend on the baked variations, so this gate must be confirmed before continuing.
2. **The textured fill has a border.** `pill_fill.png` carries a purple outline. As a `ProgressBar` fill it is drawn clipped to the current value, so a partly-filled pill will show that border down its cut edge. Task 9 Step 2 check 1 is where this shows up; if it reads badly the fix is a borderless fill texture, not a code change.
3. **Tinting.** `StatBar._apply_tint` sets `self_modulate` to the category colour, which will tint the textured fill's gradient and border along with it. Judge in Task 9; if the art is meant to show its own colours, drop the tint for `StatPill` in `_apply_tint`.
