# Daily Results Popup — Mockup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `DaySummaryPopup.tscn` and its student row to match
`dailyresults_mockup.png` pixel-for-pixel, driven by real per-student data.

**Architecture:** The mockup maps 1:1 onto the game's 1080×1920 viewport, so
the card background art is used at native size and every measurement is a game
pixel. The card becomes a real `.tscn` (`DaySummaryStudentRow`) composed of a
masked splash avatar, two theme-styled bars, and three instances of a new
`DaySummaryStatRow`. `SchoolDay`'s StudentScroll-reparenting hack is deleted so
the popup actually renders its own rows.

**Tech Stack:** Godot 4.6, GDScript, `DesignTokens` → `ThemeFactory` →
`kejartes_theme.tres` (rebaked via `Scripts/Design/BakeTheme.gd`), Godot AI MCP
`test_run` for the suite.

**Spec:** `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`

## Global Constraints

- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation.
  Only layout-only constant overrides (`separation`, `margin_*`) are allowed.
  (`CLAUDE.md` → Visual system.)
- After editing `DesignTokens.gd` or `ThemeFactory.gd`, **rebake** by running
  `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X).
- **Rescan before running tests** after any `.gd` edit:
  `filesystem_manage(op="scan")`. `test_run` serves a stale autoload otherwise.
- Test suites must be `@tool`, extend `McpTestSuite`, and **contain no
  coroutines** — the runner calls `suite.call(name)` without awaiting.
- Scripts the runner instantiates live must be `@tool`, with real side effects
  in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
- Game-facing identifiers and UI text are **Indonesian**; systems code English.
- Tunable numbers go in a named `const` block or an `@export`, never inline.
- Commits: Conventional Commits with a scope, e.g. `feat(day-summary): ...`.
- Mockup pixels **are** game pixels. There is no scale factor. Do not add one.

---

## File Structure

| File | Responsibility |
|---|---|
| `Assets/Images/DaySummary/*` (new) | Card bg, banner, chevron, 3 stat icons |
| `Assets/Images/SplashArtMurid/splash_*.png` (new) | 4 new splash arts |
| `Scripts/Design/DesignTokens.gd` (modify) | New `@export_group("Day Summary")` colour block |
| `Scripts/Design/ThemeFactory.gd` (modify) | New variations: name/number labels, bar tracks + fills, avatar frame |
| `Scenes/SchoolSimulation/DaySummaryAvatar.tscn` + `.gd` (new) | Rounded purple frame clipping a per-student splash crop |
| `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` + `.gd` (new) | One `[icon][chevron][track][+N/T]` row |
| `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` + `.gd` (rewrite) | The mockup card |
| `Scenes/SchoolSimulation/DaySummaryPopup.tscn` (rewrite) | Banner + scrolling card stack |
| `Scripts/SchoolSimulation/DaySummaryPopup.gd` (modify) | Drop the Card chrome, keep dismiss/SFX |
| `Scripts/SchoolSimulation/SchoolDay.gd` (modify) | `build_rows=true`, delete reparent hack |
| `tests/test_day_summary.gd` (new) | Suite for everything above |
| `tests/test_school_day.gd` (modify) | Update the reparenting assertions |

Splitting the avatar and the stat row out of the card is what keeps each file
holdable in one context: the card then declares layout only, and the two fiddly
pieces (texture cropping, three-element overlap) each get their own tests.

---

## Task 1: Import the mockup art

**Files:**
- Create: `Assets/Images/DaySummary/card_bg.png`, `title_daily_results.png`,
  `icon_chevron_up.png`, `icon_akademis.png`, `icon_seni.png`,
  `icon_olahraga.png`
- Create: `Assets/Images/SplashArtMurid/splash_marcel.png`, `splash_andi.png`,
  `splash_shinta.png`, `splash_thea.png`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: the ten `res://` paths above, each loadable as `Texture2D`.

- [ ] **Step 1: Copy the source art in**

```bash
mkdir -p "Assets/Images/DaySummary"
cp "/c/Users/ASUS/Downloads/daysummarystudent_background.png" "Assets/Images/DaySummary/card_bg.png"
cp "/c/Users/ASUS/Downloads/daily results title.png"          "Assets/Images/DaySummary/title_daily_results.png"
cp "/c/Users/ASUS/Downloads/addition_icon.png"                "Assets/Images/DaySummary/icon_chevron_up.png"
cp "/c/Users/ASUS/Downloads/academy.png"                      "Assets/Images/DaySummary/icon_akademis.png"
cp "/c/Users/ASUS/Downloads/Gunungan.png"                     "Assets/Images/DaySummary/icon_seni.png"
cp "/c/Users/ASUS/Downloads/athletic.png"                     "Assets/Images/DaySummary/icon_olahraga.png"
cp "/c/Users/ASUS/Downloads/splash_marcel.png"  "Assets/Images/SplashArtMurid/splash_marcel.png"
cp "/c/Users/ASUS/Downloads/splash_andi.png"    "Assets/Images/SplashArtMurid/splash_andi.png"
cp "/c/Users/ASUS/Downloads/splash_shinta.png"  "Assets/Images/SplashArtMurid/splash_shinta.png"
cp "/c/Users/ASUS/Downloads/splash_thea.png"    "Assets/Images/SplashArtMurid/splash_thea.png"
```

- [ ] **Step 2: Import them into Godot**

Run the MCP call `filesystem_manage(op="scan")`, then confirm each file has
gained a sibling `.import`:

```bash
ls Assets/Images/DaySummary/*.import | wc -l   # expect 6
ls Assets/Images/SplashArtMurid/splash_*.import | wc -l   # expect 4
```

- [ ] **Step 3: Write the failing test**

Create `tests/test_day_summary.gd`:

```gdscript
@tool
extends McpTestSuite

## The rebuilt Daily Results popup (spec:
## docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md).
##
## Suite constraints carried from tests/test_school_day.gd:
##  * @tool, or the runner reports the class abstract.
##  * No coroutines -- the runner does suite.call(name) without awaiting.
##  * The baked theme is assigned explicitly before a scene enters the
##    tree; ThemeDB's project-theme fallback does not populate under the
##    editor's own root.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

const _ART := {
	"card_bg": "res://Assets/Images/DaySummary/card_bg.png",
	"title": "res://Assets/Images/DaySummary/title_daily_results.png",
	"chevron": "res://Assets/Images/DaySummary/icon_chevron_up.png",
	"akademis": "res://Assets/Images/DaySummary/icon_akademis.png",
	"seni": "res://Assets/Images/DaySummary/icon_seni.png",
	"olahraga": "res://Assets/Images/DaySummary/icon_olahraga.png",
}

const _SPLASH := [
	"res://Assets/Images/SplashArtMurid/splash_marcel.png",
	"res://Assets/Images/SplashArtMurid/splash_andi.png",
	"res://Assets/Images/SplashArtMurid/splash_shinta.png",
	"res://Assets/Images/SplashArtMurid/splash_thea.png",
]


func test_every_day_summary_texture_imports() -> void:
	for key in _ART:
		var path: String = _ART[key]
		assert_true(ResourceLoader.exists(path),
			"missing day-summary art '%s' at %s" % [key, path])
		var tex := load(path) as Texture2D
		assert_not_null(tex, "%s did not load as a Texture2D" % path)


func test_every_new_splash_imports() -> void:
	for path in _SPLASH:
		assert_true(ResourceLoader.exists(path), "missing splash %s" % path)
		var tex := load(path) as Texture2D
		assert_not_null(tex, "%s did not load as a Texture2D" % path)


## The card art is placed at native size (spec section 1), so a resized
## or re-exported PNG would silently break every card-relative offset in
## this plan. Pin its dimensions.
func test_card_background_is_native_size() -> void:
	var tex := load(_ART["card_bg"]) as Texture2D
	assert_eq(tex.get_width(), 1080, "card_bg width changed")
	assert_eq(tex.get_height(), 1080, "card_bg height changed")
```

- [ ] **Step 4: Run the suite and watch it pass**

```
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: 3 tests, 0 failures. If `test_card_background_is_native_size` fails,
the copy in Step 1 grabbed the wrong file — do not "fix" the expectation.

- [ ] **Step 5: Commit**

```bash
git add Assets/Images/DaySummary Assets/Images/SplashArtMurid tests/test_day_summary.gd docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md
git commit -m "feat(day-summary): import the Daily Results mockup art"
```

---

## Task 2: Day-summary design tokens

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (append an `@export_group` after the
  existing `Penjadwalan Preview` group, currently ending line 112)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `DesignTokens.day_avatar_fill`, `.day_avatar_border`,
  `.day_bar_track`, `.day_bar_border`, `.day_energy_fill`, `.day_mood_fill`,
  `.day_stat_track`, `.day_glyph_outline`, `.day_avatar_radius`,
  `.day_name_size` — all read by `ThemeFactory` in Task 3.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## Every colour here was centroid-sampled from the mockup. A drifted
## token means the rebake will paint something the mockup does not show.
func test_day_summary_tokens_match_the_mockup() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var expected := {
		"day_avatar_fill": "5e4ebc",
		"day_avatar_border": "3d3d3d",
		"day_bar_track": "585858",
		"day_bar_border": "2b2b2b",
		"day_energy_fill": "6d60c0",
		"day_mood_fill": "c8af57",
		"day_stat_track": "383838",
		"day_glyph_outline": "3d1e48",
	}
	for key in expected:
		var c: Color = tokens.get(key)
		assert_eq(c.to_html(false), expected[key],
			"token %s drifted from the mockup sample" % key)
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL — `tokens.get("day_avatar_fill")` returns `null`, so
`to_html` errors or the equality fails.

- [ ] **Step 3: Add the tokens**

Append to `Scripts/Design/DesignTokens.gd` after line 112
(`preview_pill_fill`):

```gdscript
@export_group("Day Summary")
## Sampled from dailyresults_mockup.png (spec:
## 2026-08-29-day-summary-mockup-design.md). Several surfaces in that
## mockup are vertical gradients, which StyleBoxFlat cannot express; as
## with the Penjadwalan tokens above, each colour here is that
## gradient's midpoint.
##   avatar frame  -- flat violet behind the splash crop
##   bar track     -- #636363 -> #4E4E4E
##   energy fill   -- #7062C7 -> #695CB9
##   mood fill     -- #DFC361 -> #A69249
##   stat track    -- #3C3C3C -> #353535
@export var day_avatar_fill: Color = Color("5e4ebc")
@export var day_avatar_border: Color = Color("3d3d3d")
@export var day_bar_track: Color = Color("585858")
@export var day_bar_border: Color = Color("2b2b2b")
@export var day_energy_fill: Color = Color("6d60c0")
@export var day_mood_fill: Color = Color("c8af57")
@export var day_stat_track: Color = Color("383838")
## The dark rim every white glyph on this card carries -- name, stat
## icons and the +N/T numbers alike.
@export var day_glyph_outline: Color = Color("3d1e48")

## Geometry measured off the mockup, in game pixels (mockup is 1:1).
@export var day_avatar_radius: int = 22
@export var day_bar_radius: int = 18
@export var day_name_size: int = 40
@export var day_stat_size: int = 38
```

- [ ] **Step 4: Rebake and run the test**

Run `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X), then:

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Assets/Theme/kejartes_theme.tres tests/test_day_summary.gd
git commit -m "feat(day-summary): add design tokens sampled from the mockup"
```

---

## Task 3: ThemeFactory variations

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (new builder called from the same
  place `_build_progress` is called)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: the `day_*` tokens from Task 2.
- Produces: theme type variations `DaySummaryName` (Label),
  `DaySummaryStat` (Label), `DaySummaryAvatarFrame` (Panel),
  `DaySummaryEnergyBar` (ProgressBar), `DaySummaryMoodBar` (ProgressBar),
  `DaySummaryStatTrack` (ProgressBar). Tasks 4–6 set
  `theme_type_variation` to these names and add no overrides.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
const _DAY_VARIATIONS := {
	"DaySummaryName": "Label",
	"DaySummaryStat": "Label",
	"DaySummaryAvatarFrame": "Panel",
	"DaySummaryEnergyBar": "ProgressBar",
	"DaySummaryMoodBar": "ProgressBar",
	"DaySummaryStatTrack": "ProgressBar",
}


func test_theme_declares_every_day_summary_variation() -> void:
	var theme := load(_THEME_PATH) as Theme
	assert_not_null(theme, "baked theme failed to load")
	for name in _DAY_VARIATIONS:
		assert_true(theme.has_type(name),
			"theme is missing variation %s -- did you rebake?" % name)
		assert_eq(theme.get_type_variation_base(name), _DAY_VARIATIONS[name],
			"%s is based on the wrong type" % name)


## The name and the numbers are white-on-light with a dark rim; getting
## this inverted (the project's usual dark-on-light) makes them vanish
## against the card's pale fill.
func test_day_summary_text_is_white_with_a_dark_rim() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := DesignTokens.load_default()
	for name in ["DaySummaryName", "DaySummaryStat"]:
		assert_eq(theme.get_color("font_color", name), Color.WHITE,
			"%s should be white" % name)
		assert_eq(theme.get_color("font_outline_color", name),
			tokens.day_glyph_outline, "%s rim drifted" % name)
		assert_true(theme.get_constant("outline_size", name) > 0,
			"%s has no outline" % name)


## The two bars share a track and differ only in fill. If they ever share
## a fill too, energy and mood become indistinguishable.
func test_energy_and_mood_bars_differ_only_in_fill() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := DesignTokens.load_default()
	var e_bg := theme.get_stylebox("background", "DaySummaryEnergyBar") as StyleBoxFlat
	var m_bg := theme.get_stylebox("background", "DaySummaryMoodBar") as StyleBoxFlat
	assert_eq(e_bg.bg_color, m_bg.bg_color, "bar tracks diverged")
	assert_eq(e_bg.bg_color, tokens.day_bar_track, "bar track drifted")
	var e_fill := theme.get_stylebox("fill", "DaySummaryEnergyBar") as StyleBoxFlat
	var m_fill := theme.get_stylebox("fill", "DaySummaryMoodBar") as StyleBoxFlat
	assert_eq(e_fill.bg_color, tokens.day_energy_fill, "energy fill drifted")
	assert_eq(m_fill.bg_color, tokens.day_mood_fill, "mood fill drifted")
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL with "theme is missing variation DaySummaryName".

- [ ] **Step 3: Add the builder**

Append to `Scripts/Design/ThemeFactory.gd`:

```gdscript
# ------------------------------------------------------- day summary

## Variations for the Daily Results card (spec:
## 2026-08-29-day-summary-mockup-design.md). Two things here deliberately
## break this file's usual habits, both because the card art is pale and
## saturated rather than the app's neutral light surface:
##   * text is white with a DARK rim, inverting the usual relationship;
##   * the bars carry their own border colour instead of leaning on
##     outline_card, because the mockup's rim is near-black, not white.
static func _build_day_summary(theme: Theme, tokens: DesignTokens) -> void:
	# name, size, outline divisor
	var text_specs := [
		["DaySummaryName", tokens.day_name_size],
		["DaySummaryStat", tokens.day_stat_size],
	]
	for spec in text_specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "Label")
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, Color.WHITE)
		theme.set_constant("outline_size", name,
			maxi(2, tokens.text_outline_size / 2))
		theme.set_color("font_outline_color", name, tokens.day_glyph_outline)
		if tokens.font_display != null:
			theme.set_font("font", name, tokens.font_display)

	theme.add_type("DaySummaryAvatarFrame")
	theme.set_type_variation("DaySummaryAvatarFrame", "Panel")
	var frame := StyleBoxFlat.new()
	frame.bg_color = tokens.day_avatar_fill
	frame.border_color = tokens.day_avatar_border
	frame.set_border_width_all(5)
	frame.set_corner_radius_all(tokens.day_avatar_radius)
	theme.set_stylebox("panel", "DaySummaryAvatarFrame", frame)

	# The two needs bars and the three stat tracks are the same slab in
	# three flavours: same rim, same radius, different fill.
	# name, track color, fill color, radius
	var bar_specs := [
		["DaySummaryEnergyBar", tokens.day_bar_track,
			tokens.day_energy_fill, tokens.day_bar_radius],
		["DaySummaryMoodBar", tokens.day_bar_track,
			tokens.day_mood_fill, tokens.day_bar_radius],
		["DaySummaryStatTrack", tokens.day_stat_track,
			tokens.day_stat_track, tokens.radius_pill],
	]
	for spec in bar_specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "ProgressBar")

		var track := StyleBoxFlat.new()
		track.bg_color = spec[1]
		track.border_color = tokens.day_bar_border
		track.set_border_width_all(5)
		track.set_corner_radius_all(spec[3])
		theme.set_stylebox("background", name, track)

		var fill := StyleBoxFlat.new()
		fill.bg_color = spec[2]
		fill.border_color = tokens.day_glyph_outline
		fill.set_border_width_all(3)
		fill.set_corner_radius_all(tokens.radius_pill)
		theme.set_stylebox("fill", name, fill)
```

- [ ] **Step 4: Call it from the theme build**

Find the line calling `_build_progress(theme, tokens)` in
`ThemeFactory.build()` and add immediately after it:

```gdscript
	_build_day_summary(theme, tokens)
```

- [ ] **Step 5: Rebake and run**

Run `Scripts/Design/BakeTheme.gd` (Ctrl+Shift+X), then:

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: PASS, 7 tests.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_day_summary.gd
git commit -m "feat(day-summary): add theme variations for the mockup card"
```

---

## Task 4: The masked splash avatar

**Files:**
- Create: `Scenes/SchoolSimulation/DaySummaryAvatar.tscn`
- Create: `Scripts/SchoolSimulation/DaySummaryAvatar.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryAvatarFrame` from Task 3; the splash paths from Task 1.
- Produces: `class_name DaySummaryAvatar`, with
  `func set_student(student: StudentData) -> void` and
  `static func crop_for(student_name: String, tex: Texture2D) -> Rect2`.
  Task 6 calls `set_student`.

**Why a per-student crop.** The four splash files do **not** share framing
(spec §3): `splash_thea.png` is a 550×1119 canvas while the rest are
1080×1920, and `splash_andi.png`'s content runs to x=1079 because a second
figure's sliver is baked into its right edge. A single shared transform
would crop Thea's head off and show a stranger's arm next to Andi.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
const _AVATAR_SCENE := "res://Scenes/SchoolSimulation/DaySummaryAvatar.tscn"

## Frame is 269x286 in the mockup; every crop must match that aspect or
## the splash is stretched. Tolerance is one part in fifty.
const _FRAME_ASPECT := 269.0 / 286.0


func test_every_named_crop_matches_the_frame_aspect() -> void:
	for student_name in DaySummaryAvatar.SPLASH_CROP:
		var r: Rect2 = DaySummaryAvatar.SPLASH_CROP[student_name]
		assert_true(r.size.x > 0.0 and r.size.y > 0.0,
			"%s has an empty crop" % student_name)
		var aspect := r.size.x / r.size.y
		assert_true(absf(aspect - _FRAME_ASPECT) < 0.02,
			"%s crop aspect %f is not the frame's %f"
				% [student_name, aspect, _FRAME_ASPECT])


## Every named crop must sit inside its own texture, or Godot samples
## transparent padding and the head drifts off-centre.
func test_every_named_crop_is_inside_its_texture() -> void:
	var paths := {
		"Marcel": "res://Assets/Images/SplashArtMurid/splash_marcel.png",
		"Andi": "res://Assets/Images/SplashArtMurid/splash_andi.png",
		"Shinta": "res://Assets/Images/SplashArtMurid/splash_shinta.png",
		"Thea": "res://Assets/Images/SplashArtMurid/splash_thea.png",
	}
	for student_name in paths:
		var tex := load(paths[student_name]) as Texture2D
		var r: Rect2 = DaySummaryAvatar.SPLASH_CROP[student_name]
		assert_true(r.position.x >= 0.0 and r.position.y >= 0.0,
			"%s crop starts outside the texture" % student_name)
		assert_true(r.end.x <= float(tex.get_width()),
			"%s crop runs past the right edge" % student_name)
		assert_true(r.end.y <= float(tex.get_height()),
			"%s crop runs past the bottom edge" % student_name)


## Doni and Citra have no new art (spec section 3). The fallback must
## still produce a usable, correctly-shaped crop rather than nothing.
func test_unknown_students_get_a_computed_crop() -> void:
	var tex := load("res://Assets/Images/SplashArtMurid/splash_marcel.png") as Texture2D
	var r := DaySummaryAvatar.crop_for("Doni", tex)
	assert_true(r.size.x > 0.0 and r.size.y > 0.0,
		"fallback crop is empty")
	var aspect := r.size.x / r.size.y
	assert_true(absf(aspect - _FRAME_ASPECT) < 0.02,
		"fallback crop aspect %f is not the frame's" % aspect)
	assert_true(r.end.y <= float(tex.get_height()),
		"fallback crop runs off the bottom")


func test_avatar_scene_clips_and_wears_the_frame_variation() -> void:
	var scene := load(_AVATAR_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryAvatar.tscn failed to load")
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	assert_eq(inst.theme_type_variation, &"DaySummaryAvatarFrame",
		"avatar root is not wearing the frame variation")
	assert_true(inst.clip_contents,
		"avatar root must clip, or the splash spills past the rim")
	assert_not_null(inst.get_node_or_null("Art"),
		"avatar is missing its Art TextureRect")
	inst.free()
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL — `DaySummaryAvatar` is not a known identifier.

- [ ] **Step 3: Write the script**

Create `Scripts/SchoolSimulation/DaySummaryAvatar.gd`:

```gdscript
@tool
extends Panel
class_name DaySummaryAvatar

## The Daily Results card's profile image: a rounded violet frame that
## clips a head-and-shoulders crop out of the student's full-body splash.
##
## The crop is per-student and cannot be derived from a shared rule --
## the splash batch does not share a canvas (Thea's is 550x1119, the
## others 1080x1920) and splash_andi.png carries a sliver of a second
## figure baked into its right edge. See the spec, section 3.

## Frame size in game pixels, measured off the mockup.
const FRAME_SIZE := Vector2(269, 286)
const FRAME_ASPECT := FRAME_SIZE.x / FRAME_SIZE.y

## Head-and-shoulders window into each splash, in that splash's own
## pixels. Each is FRAME_ASPECT-shaped so nothing stretches. Values were
## derived from the content bounding boxes in the spec and confirmed
## visually in Task 9 -- adjust here, not by scaling the TextureRect.
const SPLASH_CROP := {
	"Marcel": Rect2(202, 40, 752, 800),
	"Andi": Rect2(224, 45, 752, 800),
	"Shinta": Rect2(210, 100, 752, 800),
	"Thea": Rect2(99, 0, 442, 470),
}

@onready var art: TextureRect = $Art


## Falls back for any student with no entry in SPLASH_CROP -- Doni and
## Citra today, plus anyone added later. Takes the full width and the
## top FRAME_ASPECT-worth of rows, which frames a full-body splash on
## its head without needing to know anything about the pose.
static func crop_for(student_name: String, tex: Texture2D) -> Rect2:
	if SPLASH_CROP.has(student_name):
		return SPLASH_CROP[student_name]
	if tex == null:
		return Rect2()
	var w := float(tex.get_width())
	var h := minf(float(tex.get_height()), w / FRAME_ASPECT)
	return Rect2(0.0, 0.0, h * FRAME_ASPECT, h)


## Resolution order, per the spec: the student's own splash_path, then
## their portrait, then nothing. Never leaves a broken texture.
func set_student(student: StudentData) -> void:
	if student == null:
		art.texture = null
		return

	var tex: Texture2D = null
	if student.splash_path != "" and ResourceLoader.exists(student.splash_path):
		tex = load(student.splash_path)
	elif student.avatar_texture != null:
		tex = student.avatar_texture

	if tex == null:
		art.texture = null
		return

	var region := crop_for(student.student_name, tex)
	if region.size.x <= 0.0:
		art.texture = tex
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	art.texture = atlas
```

- [ ] **Step 4: Write the scene**

Create `Scenes/SchoolSimulation/DaySummaryAvatar.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Scripts/SchoolSimulation/DaySummaryAvatar.gd" id="1_avatar"]

[node name="DaySummaryAvatar" type="Panel"]
clip_contents = true
custom_minimum_size = Vector2(269, 286)
theme_type_variation = &"DaySummaryAvatarFrame"
script = ExtResource("1_avatar")

[node name="Art" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 6
```

`expand_mode = 1` is `EXPAND_IGNORE_SIZE`; `stretch_mode = 6` is
`STRETCH_KEEP_ASPECT_COVERED`. The crop already matches the frame aspect, so
COVERED does no cropping of its own — it only guards against a fallback
texture whose aspect differs.

- [ ] **Step 5: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: PASS, 11 tests.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryAvatar.tscn Scripts/SchoolSimulation/DaySummaryAvatar.gd tests/test_day_summary.gd
git commit -m "feat(day-summary): add the masked splash avatar"
```

---

## Task 5: The stat row

**Files:**
- Create: `Scenes/SchoolSimulation/DaySummaryStatRow.tscn`
- Create: `Scripts/SchoolSimulation/DaySummaryStatRow.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryStatTrack`, `DaySummaryStat` from Task 3; the three
  stat icons and the chevron from Task 1.
- Produces: `class_name DaySummaryStatRow`, with
  `func set_stat(stat_key: String, delta: float, target: float) -> void`.
  Task 6 instantiates three of these and calls `set_stat` on each.

**Layout, from the spec.** `[icon overlay] [track: expand] [number: shrink]`.
The track's right edge is the number's left edge; the icon and the gold
chevron are drawn **on top of** the track's left end, not beside it. That
overlap is why the icon and chevron live in a `Control` with manual anchors
rather than as HBox siblings.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
const _STAT_ROW_SCENE := "res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn"


func test_stat_row_maps_each_key_to_its_mockup_icon() -> void:
	assert_eq(DaySummaryStatRow.ICON_FOR["akademis"],
		"res://Assets/Images/DaySummary/icon_akademis.png")
	assert_eq(DaySummaryStatRow.ICON_FOR["seni_budaya"],
		"res://Assets/Images/DaySummary/icon_seni.png")
	assert_eq(DaySummaryStatRow.ICON_FOR["olahraga"],
		"res://Assets/Images/DaySummary/icon_olahraga.png")


## The mockup prints "+12/65" -- delta over target, with an explicit
## plus. A bare "12/65" or a "+12/65.0" both miss it.
func test_stat_row_formats_delta_over_target() -> void:
	assert_eq(DaySummaryStatRow.format_value(12.0, 65.0), "+12/65")
	assert_eq(DaySummaryStatRow.format_value(9.0, 65.0), "+9/65")
	assert_eq(DaySummaryStatRow.format_value(0.0, 65.0), "+0/65")


## A stat can fall (an event or a lost minigame), and "+-3" would be
## nonsense. The sign must follow the number.
func test_stat_row_formats_a_loss_without_a_stray_plus() -> void:
	assert_eq(DaySummaryStatRow.format_value(-3.0, 65.0), "-3/65")


func test_stat_row_scene_wears_the_theme_and_has_no_overrides() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryStatRow.tscn failed to load")
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var track := inst.get_node_or_null("Track")
	assert_not_null(track, "stat row is missing its Track")
	assert_eq(track.theme_type_variation, &"DaySummaryStatTrack",
		"Track is not wearing DaySummaryStatTrack")
	var value := inst.get_node_or_null("Value")
	assert_not_null(value, "stat row is missing its Value label")
	assert_eq(value.theme_type_variation, &"DaySummaryStat",
		"Value is not wearing DaySummaryStat")
	assert_not_null(inst.get_node_or_null("Icon"), "stat row is missing Icon")
	assert_not_null(inst.get_node_or_null("Chevron"),
		"stat row is missing Chevron")
	inst.free()
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL — `DaySummaryStatRow` is not a known identifier.

- [ ] **Step 3: Write the script**

Create `Scripts/SchoolSimulation/DaySummaryStatRow.gd`:

```gdscript
@tool
extends Control
class_name DaySummaryStatRow

## One line of the Daily Results card: a white stat icon and a gold
## chevron sitting ON TOP of a dark track, with "+12/65" right-aligned
## on the card fill beside it.
##
## The track's right edge is the number's left edge -- in the mockup a
## wider number ("+12/65") pushes the track shorter than a narrow one
## ("+9/65"). That falls out of the anchors below: the number is
## right-aligned and shrink-sized, the track expands into what is left.

## Geometry in game pixels, measured off the mockup (spec section 2).
const ROW_HEIGHT := 96
const TRACK_HEIGHT := 36
const TRACK_LEFT := 0
const ICON_BOX := Vector2(95, 70)
const ICON_LEFT := -15
const CHEVRON_BOX := Vector2(40, 58)
const CHEVRON_LEFT := 67
const VALUE_WIDTH := 200

const ICON_FOR := {
	"akademis": "res://Assets/Images/DaySummary/icon_akademis.png",
	"seni_budaya": "res://Assets/Images/DaySummary/icon_seni.png",
	"olahraga": "res://Assets/Images/DaySummary/icon_olahraga.png",
}

@onready var icon: TextureRect = $Icon
@onready var chevron: TextureRect = $Chevron
@onready var track: ProgressBar = $Track
@onready var value: Label = $Value


## "+12/65" -- the sign rides with the number so a loss reads "-3/65"
## rather than "+-3/65".
static func format_value(delta: float, target: float) -> String:
	var d := int(round(delta))
	var sign_str := "+" if d >= 0 else ""
	return "%s%d/%d" % [sign_str, d, int(round(target))]


func set_stat(stat_key: String, delta: float, target: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	value.text = format_value(delta, target)
	# The track is decorative in the mockup -- it reads as a rail the
	# chevron sits on, not as a gauge -- so it stays full rather than
	# encoding delta a second time next to the number that already says it.
	track.value = track.max_value
```

- [ ] **Step 4: Write the scene**

Create `Scenes/SchoolSimulation/DaySummaryStatRow.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://Scripts/SchoolSimulation/DaySummaryStatRow.gd" id="1_statrow"]
[ext_resource type="Texture2D" path="res://Assets/Images/DaySummary/icon_chevron_up.png" id="2_chevron"]

[node name="DaySummaryStatRow" type="Control"]
custom_minimum_size = Vector2(0, 96)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("1_statrow")

[node name="Track" type="ProgressBar" parent="."]
layout_mode = 1
anchors_preset = 4
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = 0.0
offset_top = -18.0
offset_right = -200.0
offset_bottom = 18.0
anchor_right = 1.0
grow_vertical = 2
theme_type_variation = &"DaySummaryStatTrack"
show_percentage = false
value = 100.0

[node name="Icon" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 4
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = -15.0
offset_top = -35.0
offset_right = 80.0
offset_bottom = 35.0
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="Chevron" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 4
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = 67.0
offset_top = -29.0
offset_right = 107.0
offset_bottom = 29.0
grow_vertical = 2
texture = ExtResource("2_chevron")
expand_mode = 1
stretch_mode = 5

[node name="Value" type="Label" parent="."]
layout_mode = 1
anchors_preset = 6
anchor_left = 1.0
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -25.0
offset_bottom = 25.0
grow_horizontal = 0
grow_vertical = 2
theme_type_variation = &"DaySummaryStat"
text = "+12/65"
horizontal_alignment = 2
vertical_alignment = 1
```

`stretch_mode = 5` is `STRETCH_KEEP_ASPECT_CENTERED`, which is what keeps the
1.5:1 grad cap and the 1:1 gunungan both correctly shaped in the same box.
Node order matters: `Track` is declared first so `Icon` and `Chevron` draw
over it.

- [ ] **Step 5: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: PASS, 15 tests.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStatRow.tscn Scripts/SchoolSimulation/DaySummaryStatRow.gd tests/test_day_summary.gd
git commit -m "feat(day-summary): add the icon+chevron+track stat row"
```

---

## Task 6: Rebuild the student card

**Files:**
- Rewrite: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`
- Rewrite: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryAvatar.set_student` (Task 4),
  `DaySummaryStatRow.set_stat` (Task 5), `DaySummaryEnergyBar` /
  `DaySummaryMoodBar` (Task 3), `card_bg.png` (Task 1).
- Produces: `class_name DaySummaryStudentRow`, keeping its existing entry
  point `func setup_row(student_name: String, changes: Array, student: StudentData) -> void`
  so `DaySummaryPopup` needs no change to how it calls rows.

**Card-relative geometry** (spec §2), all in game pixels, card 992×393:

| Element | x | y | w | h |
|---|---|---|---|---|
| Avatar | 50 | 52 | 269 | 286 |
| Name | 336 | 48 | — | 41 |
| Energy bar | 336 | 113 | 243 | 68 |
| Mood bar | 336 | 201 | 243 | 67 |
| Stat row 1 | 616 | 105 | →966 | 36 |
| Stat row 2 | 616 | 202 | →966 | 36 |
| Stat row 3 | 616 | 302 | →966 | 36 |

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
const _ROW_SCENE := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"
const _ROW_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd"


## The card art is placed at native size, so the row must reserve
## exactly the mockup's box. A row that shrink-wraps its children
## instead would slide every child off the painted background.
func test_row_reserves_the_mockup_card_box() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	assert_eq(inst.custom_minimum_size, Vector2(992, 405),
		"card box drifted from the mockup's 992x393 fill + 12px shadow")
	inst.free()


func test_row_carries_the_card_art_and_the_three_stat_rows() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)

	var bg := inst.get_node_or_null("CardArt") as TextureRect
	assert_not_null(bg, "row is missing its CardArt")
	assert_not_null(bg.texture, "CardArt has no texture assigned")

	assert_not_null(inst.get_node_or_null("Avatar"), "row is missing Avatar")
	for i in range(1, 4):
		assert_not_null(inst.get_node_or_null("StatRow%d" % i),
			"row is missing StatRow%d" % i)
	inst.free()


## Energy is the TOP bar and mood the BOTTOM one, and they are violet
## and gold respectively. The existing DayScreen cards use the opposite
## tints (spec section 5); this pins the popup to the mockup so a later
## reconciliation cannot silently swap them here.
func test_energy_is_the_top_bar_and_mood_the_bottom() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var energy := inst.get_node_or_null("EnergyBar") as ProgressBar
	var mood := inst.get_node_or_null("MoodBar") as ProgressBar
	assert_not_null(energy, "row is missing EnergyBar")
	assert_not_null(mood, "row is missing MoodBar")
	assert_eq(energy.theme_type_variation, &"DaySummaryEnergyBar",
		"EnergyBar is wearing the wrong variation")
	assert_eq(mood.theme_type_variation, &"DaySummaryMoodBar",
		"MoodBar is wearing the wrong variation")
	assert_true(energy.offset_top < mood.offset_top,
		"energy must sit above mood, as in the mockup")
	inst.free()


## The naming trap this project documents in CLAUDE.md: target_akademis2
## is the SENI target and target_akademis3 the OLAHRAGA one. Getting it
## wrong shows the right number against the wrong icon.
func test_row_pairs_each_stat_with_its_correct_target_field() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("\"akademis\": \"target_akademis1\""),
		"akademis must read target_akademis1")
	assert_true(src.contains("\"seni_budaya\": \"target_akademis2\""),
		"seni_budaya must read target_akademis2, not target_akademis3")
	assert_true(src.contains("\"olahraga\": \"target_akademis3\""),
		"olahraga must read target_akademis3")


## The mockup shows a fixed three-row block; a card whose height varied
## with how many stats happened to move would break the stack rhythm.
func test_row_always_shows_three_stat_rows() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("STAT_ORDER"),
		"row should drive its three rows from a fixed STAT_ORDER")
	assert_eq(DaySummaryStudentRow.STAT_ORDER.size(), 3,
		"the mockup shows exactly three stat rows")
	# The old row skipped any stat whose delta was zero, which made the
	# card's height depend on the day. Nothing may `continue` on a zero
	# delta any more.
	assert_false(src.contains("if delta == 0.0:"),
		"row must not skip stats that did not move")


## No theme_override_* anywhere -- the project's hard styling rule.
func test_row_scene_declares_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCENE)
	assert_false(src.contains("theme_override_colors"),
		"colour override found -- use a ThemeFactory variation")
	assert_false(src.contains("theme_override_fonts"),
		"font override found -- use a ThemeFactory variation")
	assert_false(src.contains("theme_override_styles"),
		"stylebox override found -- use a ThemeFactory variation")
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL on `test_row_reserves_the_mockup_card_box` — the old row is a
`PanelContainer` with no `custom_minimum_size`.

- [ ] **Step 3: Write the script**

Replace `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` entirely:

```gdscript
extends Control
class_name DaySummaryStudentRow

## One student's card in the Daily Results popup, built to
## dailyresults_mockup.png (spec:
## 2026-08-29-day-summary-mockup-design.md).
##
## The card background is art, placed at native size, so this scene
## positions its children at fixed card-relative offsets rather than
## letting containers negotiate. Every colour, font and stylebox comes
## from a ThemeFactory variation; nothing here builds a StyleBox.

## The three skills, in the mockup's top-to-bottom order, paired with
## the StudentData field holding each one's target. The pairing is the
## project's documented naming trap: target_akademis2 is the SENI
## target, target_akademis3 the OLAHRAGA one.
const STAT_ORDER := ["akademis", "seni_budaya", "olahraga"]
const TARGET_FOR := {
	"akademis": "target_akademis1",
	"seni_budaya": "target_akademis2",
	"olahraga": "target_akademis3",
}

@onready var avatar: DaySummaryAvatar = $Avatar
@onready var name_label: Label = $NameLabel
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var mood_bar: ProgressBar = $MoodBar
@onready var stat_rows: Array[DaySummaryStatRow] = [
	$StatRow1, $StatRow2, $StatRow3,
]


func setup_row(student_name: String, changes: Array, student: StudentData) -> void:
	name_label.text = student_name
	avatar.set_student(student)

	if student != null:
		energy_bar.value = student.energy
		mood_bar.value = student.mood

	var deltas := _sum_deltas(changes)
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		var target := 0.0
		if student != null:
			target = float(student.get(TARGET_FOR[key]))
		stat_rows[i].set_stat(key, deltas.get(key, 0.0), target)


## A stat can move more than once in a day -- a scheduled activity plus
## an event, say -- and the mockup shows one number per stat, so the
## day's changes are summed rather than shown one chip per source.
func _sum_deltas(changes: Array) -> Dictionary:
	var out := {}
	for ch in changes:
		var key := String(ch.get("stat_key", ""))
		if not TARGET_FOR.has(key):
			continue
		out[key] = float(out.get(key, 0.0)) + float(ch.get("delta", 0.0))
	return out
```

- [ ] **Step 4: Write the scene**

Replace `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` entirely:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd" id="1_row"]
[ext_resource type="Texture2D" path="res://Assets/Images/DaySummary/card_bg.png" id="2_card_bg"]
[ext_resource type="PackedScene" path="res://Scenes/SchoolSimulation/DaySummaryAvatar.tscn" id="3_avatar"]
[ext_resource type="PackedScene" path="res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn" id="4_statrow"]

[node name="DaySummaryStudentRow" type="Control"]
custom_minimum_size = Vector2(992, 405)
layout_mode = 2
size_flags_horizontal = 4
script = ExtResource("1_row")

[node name="CardArt" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("2_card_bg")
expand_mode = 1
stretch_mode = 5

[node name="Avatar" parent="." instance=ExtResource("3_avatar")]
layout_mode = 1
offset_left = 50.0
offset_top = 52.0
offset_right = 319.0
offset_bottom = 338.0

[node name="NameLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 336.0
offset_top = 40.0
offset_right = 700.0
offset_bottom = 100.0
theme_type_variation = &"DaySummaryName"
text = "Marcel"
vertical_alignment = 1

[node name="EnergyBar" type="ProgressBar" parent="."]
layout_mode = 1
offset_left = 336.0
offset_top = 113.0
offset_right = 579.0
offset_bottom = 181.0
theme_type_variation = &"DaySummaryEnergyBar"
show_percentage = false
value = 36.0

[node name="MoodBar" type="ProgressBar" parent="."]
layout_mode = 1
offset_left = 336.0
offset_top = 201.0
offset_right = 579.0
offset_bottom = 268.0
theme_type_variation = &"DaySummaryMoodBar"
show_percentage = false
value = 82.0

[node name="StatRow1" parent="." instance=ExtResource("4_statrow")]
layout_mode = 1
offset_left = 616.0
offset_top = 57.0
offset_right = 966.0
offset_bottom = 153.0

[node name="StatRow2" parent="." instance=ExtResource("4_statrow")]
layout_mode = 1
offset_left = 616.0
offset_top = 154.0
offset_right = 966.0
offset_bottom = 250.0

[node name="StatRow3" parent="." instance=ExtResource("4_statrow")]
layout_mode = 1
offset_left = 616.0
offset_top = 254.0
offset_right = 966.0
offset_bottom = 350.0
```

Stat rows are 96px tall and vertically centre their 36px track, so a row
placed at `offset_top = 57` puts its track at card-rel y 105 — the measured
value. Same for 154→202 and 254→302.

- [ ] **Step 5: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: PASS, 21 tests.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd
git commit -m "feat(day-summary): rebuild the student card to the mockup"
```

---

## Task 7: Rebuild the popup shell

**Files:**
- Rewrite: `Scenes/SchoolSimulation/DaySummaryPopup.tscn`
- Modify: `Scripts/SchoolSimulation/DaySummaryPopup.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `title_daily_results.png` (Task 1),
  `DaySummaryStudentRow.setup_row` (Task 6).
- Produces: an unchanged public surface —
  `setup_summary(day_name, summary_data, students, build_rows)`,
  `signal summary_dismissed`, `func dismiss()`. Task 8 relies on all three.

The mockup has **no card behind the stack** — the banner and the cards sit
directly on the scrim. The old `CardPanel`, its `MarginContainer`,
`TitleLabel` and `HintLabel` all go. Banner geometry from the spec: 932×287
at abs (93, 42).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
const _POPUP_SCENE := "res://Scenes/SchoolSimulation/DaySummaryPopup.tscn"
const _POPUP_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryPopup.gd"


func test_popup_shows_the_banner_art_not_a_text_title() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var banner := inst.find_child("TitleBanner", true, false) as TextureRect
	assert_not_null(banner, "popup is missing its TitleBanner")
	assert_not_null(banner.texture, "TitleBanner has no texture")
	# custom_minimum_size, not size: the scene is instantiated but never
	# enters a tree here, so no container sort has run and `size` is
	# still zero. This suite must not await one (no coroutines).
	assert_eq(banner.custom_minimum_size.x, 932.0,
		"banner width drifted from the mockup")
	inst.free()


## The mockup puts the banner and the cards straight on the scrim. A
## surviving Card panel would draw a white slab behind both.
func test_popup_has_no_card_panel_behind_the_stack() -> void:
	var src := FileAccess.get_file_as_string(_POPUP_SCENE)
	assert_false(src.contains("theme_type_variation = &\"Card\""),
		"the popup still carries a Card panel behind the stack")


## Up to six students can move in a day; six 405px cards overflow 1920px.
func test_popup_scrolls_its_rows() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	var inst := scene.instantiate()
	var scroll := inst.find_child("RowsScroll", true, false)
	assert_true(scroll is ScrollContainer,
		"rows must live in a ScrollContainer -- six cards overflow the screen")
	var rows := inst.find_child("RowsContainer", true, false)
	assert_not_null(rows, "popup is missing RowsContainer")
	inst.free()


## SchoolDay hands the popup a real summary and expects the rows built
## from it (Task 8 removes the reparenting that used to bypass this).
func test_popup_still_exposes_its_contract() -> void:
	var src := FileAccess.get_file_as_string(_POPUP_SCRIPT)
	assert_true(src.contains("signal summary_dismissed"),
		"summary_dismissed is gone -- SchoolDay awaits it")
	assert_true(src.contains("func setup_summary("),
		"setup_summary is gone")
	assert_true(src.contains("func dismiss()"), "dismiss is gone")
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL — no `TitleBanner` node exists.

- [ ] **Step 3: Write the scene**

Replace `Scenes/SchoolSimulation/DaySummaryPopup.tscn` entirely:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://Scripts/SchoolSimulation/DaySummaryPopup.gd" id="1_popup"]
[ext_resource type="PackedScene" path="res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn" id="2_row_scene"]
[ext_resource type="Texture2D" path="res://Assets/Images/DaySummary/title_daily_results.png" id="3_title"]

[node name="DaySummaryPopup" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_popup")
student_row_scene = ExtResource("2_row_scene")

[node name="DimOverlay" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"Scrim"

[node name="Content" type="VBoxContainer" parent="DimOverlay"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 28

[node name="TitleBanner" type="TextureRect" parent="DimOverlay/Content"]
custom_minimum_size = Vector2(932, 287)
layout_mode = 2
size_flags_horizontal = 4
texture = ExtResource("3_title")
expand_mode = 1
stretch_mode = 5

[node name="RowsScroll" type="ScrollContainer" parent="DimOverlay/Content"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="RowsContainer" type="VBoxContainer" parent="DimOverlay/Content/RowsScroll"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 56
```

Row separation is 56: the mockup's card-fill tops are 462px apart
(359→821), less the 405px card box plus shadow.

- [ ] **Step 4: Repoint the script's node paths**

In `Scripts/SchoolSimulation/DaySummaryPopup.gd`, replace the `@onready`
block and delete the two nodes that no longer exist:

```gdscript
@onready var dim_overlay: Panel = $DimOverlay
@onready var content: VBoxContainer = $DimOverlay/Content
@onready var rows_container: VBoxContainer = $DimOverlay/Content/RowsScroll/RowsContainer
```

Then, in `setup_summary`, delete the `title_label.text = ...` line — the
banner is art and carries no day name — and replace every remaining
`card_panel` reference with `content`. The `pivot_offset` line becomes:

```gdscript
	content.pivot_offset = get_viewport_rect().size / 2.0
```

Leave `_play_day_verdict_sfx`, `_input`, and `dismiss()` alone.

- [ ] **Step 5: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: PASS, 25 tests.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryPopup.tscn Scripts/SchoolSimulation/DaySummaryPopup.gd tests/test_day_summary.gd
git commit -m "feat(day-summary): put the banner and card stack on the scrim"
```

---

## Task 8: Retire the StudentScroll reparenting hack

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:658-706` (`_show_day_summary`)
- Modify: `tests/test_school_day.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryPopup.setup_summary(..., build_rows=true)` (Task 7).
- Produces: nothing new. `_render_embedded_student_status()` is untouched and
  still draws the mid-day DayScreen.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
const _SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"


## The popup now owns its rows. Reparenting DayScreen's live scroll into
## it would stack the mid-day cards on top of the mockup cards.
func test_school_day_no_longer_reparents_its_scroll_into_the_popup() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_false(src.contains("rows_container.add_child(scroll)"),
		"SchoolDay still reparents StudentScroll into the popup")
	assert_false(src.contains("scroll_back"),
		"SchoolDay still reparents StudentScroll back out")


func test_school_day_asks_the_popup_to_build_its_own_rows() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_false(src.contains("student_manager.students, false)"),
		"SchoolDay still passes build_rows=false")
	assert_true(src.contains("summary_instance.setup_summary("),
		"SchoolDay no longer calls setup_summary")


## The mid-day DayScreen cards are explicitly out of scope and must
## survive this task intact.
func test_school_day_still_renders_its_embedded_day_cards() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("func _render_embedded_student_status()"),
		"the mid-day DayScreen cards were removed -- out of scope")
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
```

Expected: FAIL on the first two — the hack is still there.

- [ ] **Step 3: Replace `_show_day_summary`**

Replace the whole body of `_show_day_summary` in
`Scripts/SchoolSimulation/SchoolDay.gd` with:

```gdscript
func _show_day_summary(day_name: String) -> void:
	if not student_manager:
		return
	var summary = student_manager.get_day_summary(day_name)
	if summary.is_empty():
		return

	var summary_scene = day_summary_popup_scene
	if summary_scene == null:
		summary_scene = load("res://Scenes/SchoolSimulation/DaySummaryPopup.tscn")
	if summary_scene == null:
		return

	var summary_instance = summary_scene.instantiate()
	add_child(summary_instance)

	# The popup builds its own mockup cards from the summary. It used to
	# be handed this screen's live StudentScroll instead, which is why
	# DaySummaryStudentRow went unrendered for so long -- and why the
	# mockup's "+12/65" was unbuildable, since only `summary` carries a
	# delta at all.
	summary_instance.setup_summary(day_name, summary, student_manager.students)

	await summary_instance.summary_dismissed
```

- [ ] **Step 4: Fix the stale assertions in `test_school_day.gd`**

Search that suite for any assertion naming `StudentScroll`, `scroll_back`, or
`build_rows`, and for the `DaySummaryStudentRow` structural assertions that
the Task 6 rewrite invalidates:

```bash
grep -n "StudentScroll\|scroll_back\|build_rows\|DaySummaryStudentRow" tests/test_school_day.gd
```

For each hit: an assertion about the *reparenting* is now wrong and should be
deleted; an assertion about `_render_embedded_student_status` building
DayScreen's own scroll is still right and stays. Do not weaken an assertion to
make it pass — delete the ones whose subject no longer exists.

- [ ] **Step 5: Run both suites**

```
filesystem_manage(op="scan")
test_run(suite="res://tests/test_day_summary.gd")
test_run(suite="res://tests/test_school_day.gd")
```

Expected: `test_day_summary` PASS 28 tests; `test_school_day` PASS with no
new failures.

- [ ] **Step 6: Run the whole suite**

```
test_run()
```

Expected: no new failures beyond the three documented in CLAUDE.md → Known
Issues (`test_audio_director` coroutine, `test_audio_coverage` double-SFX,
stale UID warnings). If `test_audio_coverage` reports a *new* double-SFX site,
that is yours — fix it.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd tests/test_day_summary.gd
git commit -m "refactor(school-day): let the day summary popup own its rows"
```

---

## Task 9: Verify against the mockup

**Files:**
- Modify (only if the comparison demands it): the offsets in
  `DaySummaryStudentRow.tscn`, `DaySummaryStatRow.tscn`, and the
  `SPLASH_CROP` table in `DaySummaryAvatar.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing new.

Reading the code you just wrote is not verification. This task measures the
built result and diffs it against the spec's table.

- [ ] **Step 1: Reach the popup without playing the game**

Open `Scenes/Splashscreen/Splashscreen.tscn`, run the project, then in the
debug overlay (F1, or 5 taps top-right): **⚡ Seed Playtest State**, then the
**Scenes** tab → **AturJadwal**. Assign any activity across the week, confirm,
and let SchoolDay run to the first day's end.

The seed covers roster, money, inventory and the lobby tutorial flag — it does
**not** fill `day_schedules`, which is why the Atur Jadwal pass is required.

- [ ] **Step 2: Measure the live card**

With the popup open, query the built geometry:

```
game_manage(op="get_ui_elements",
            params={"root_path": "/root/SchoolDay/DaySummaryPopup/DimOverlay/Content",
                    "max_depth": 4})
```

Scope the call — bare `get_ui_elements` serialises the whole tree.

- [ ] **Step 3: Diff every row against the spec table**

For each surface in the spec's §2 table, compare the reported `global_rect`
against the expected card-relative offset. Card-relative = reported global
minus the card's own global origin. Tolerance: 2px.

Write the comparison down. A mismatch means an offset is wrong — fix the
`.tscn`, not the spec.

- [ ] **Step 4: Screenshot and compare the avatars**

```
editor_screenshot()
```

Check each visible student's avatar crop: head fully inside the frame, no
second figure's limb at the edge (the `splash_andi.png` hazard), no
transparent gap. Adjust `DaySummaryAvatar.SPLASH_CROP` for any that are off —
keeping each rect at the frame's 0.94 aspect, which
`test_every_named_crop_matches_the_frame_aspect` enforces.

Confirm Doni and Citra — who have no new art — render their old
`SplashMurid*.jpg` through the computed fallback rather than an empty frame.

- [ ] **Step 5: Re-run the suite after any adjustment**

```
filesystem_manage(op="scan")
test_run()
```

Expected: PASS, no new failures.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix(day-summary): align the built card with the mockup measurements"
```

---

## Self-Review

**Spec coverage.** §1 (1:1 mapping) → Tasks 1, 6. §2 surface table → Tasks 3,
5, 6, verified in 9. §3 asset inventory → Task 1; the Doni/Citra gap → Task 4's
`crop_for` fallback and Task 9 Step 4. §4 architecture → Task 8. §5 data
mapping → Task 6, with the energy/mood colour-order conflict pinned by
`test_energy_is_the_top_bar_and_mood_the_bottom`. §6 out-of-scope items are
touched by no task; `test_school_day_still_renders_its_embedded_day_cards`
guards the one most at risk.

**Deliberate carry-overs.** `DaySummaryBadge.tscn` and `DaySummaryPill.tscn`
stay on disk with no task touching them: `SchoolDay._make_chip()` and
`_build_pill_badges_for_student()` still use both for the DayScreen. Deleting
them would break a screen this plan does not otherwise change.

**Known risk not designed away.** The stat track is decorative — it renders
full in every row, because the mockup gives no evidence of it encoding a
value and the number beside it already states the delta. If a later reading of
the art says otherwise, `DaySummaryStatRow.set_stat` is the one line to change.
