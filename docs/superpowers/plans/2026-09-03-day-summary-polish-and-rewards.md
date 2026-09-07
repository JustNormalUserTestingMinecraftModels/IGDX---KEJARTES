# Day Summary & Weekly Result Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken stat-row layout on the Daily Results card, give energy
and mood an icon and a tier word inside their own bars, and reward student
progress on both the nightly popup and the weekly `ResultCheckup` with authored
particle bursts and new SFX.

**Architecture:** Everything renders through one shared template,
`Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` — the nightly
`DaySummaryPopup` and the weekly `ResultCheckup` both instantiate it, so a fix
made once lands on both screens. New visuals are authored `.tscn` templates
(`RewardBurst`, `CelebrationConfetti`) instantiated by
script, never constructed node-by-node at runtime. All colour and type comes
from baked `ThemeFactory` variations built out of tokens that already exist.

**Tech Stack:** Godot 4.6, GDScript, the project's `DesignTokens`/`ThemeFactory`
baked-theme pipeline, `Juice.gd` animation helpers, `AudioDirector` autoload,
`McpTestSuite` tests run in-editor via the `godot-ai` MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md`

## Global Constraints

Copied from `CLAUDE.md` and the spec. Every task's requirements include these.

- **Never hand-edit a `.tscn` while the editor is attached.** Its in-memory copy
  wins and the next `scene_save` silently overwrites your text edit. All scene
  work goes through MCP: `scene_open` → `node_create` / `node_set_property` /
  `node_manage` / `batch_execute` → `scene_save`.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. The
  only accepted exception is a layout-only constant (`separation`, `margin_*`).
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`;
  repeated rows are a `PackedScene` template.
- **Every script needs a `##` file header and a `##` line on every `@export`.**
  Enforced by `tests/test_script_documentation.gd`.
- **Test suites must be `@tool`, must extend `McpTestSuite`, and must not be
  coroutines** — the runner calls `suite.call(name)` without awaiting.
- **Scripts the runner instantiates live must be `@tool`**, with real side
  effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
  Signal wiring stays ungated.
- **Rescan after editing a `.gd`, before running tests**
  (`filesystem_manage(op="scan")`). If the file was written from outside the
  editor, also force a reload with a no-op `script_patch` on that same file
  (add and remove a blank line).
- **UI text is Indonesian**; engine/systems code is English.
- **No emoji as iconography.** Icons are transparent PNG/SVG textures.
- **Tunable numbers live in a named `const` block or an `@export`**, never
  inline.
- **The Godot MCP bridge is single-client.** If you delegate, subagents write
  code; the controller session holds the editor and runs every `test_run`.
- Godot **4.6**, portrait 1080×1920, `mobile` renderer.

---

### Task 1: Fix the stat row's mis-anchored value label

The bug: `DaySummaryStatRow.tscn`'s `Value` label is anchored right-centre but
offset `-321 / -121`, putting its right edge 121 px inside the row and its body
directly over the `Track` (which ends at `-200`). The script's `VALUE_WIDTH = 200`
is already correct; the scene disagrees with it. Also re-pitch the three rows in
the card to an even 97 px.

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` (node `Value`)
- Modify: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` (nodes `StatRow1-3`)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryStatRow.VALUE_WIDTH` (`int`, 200), `ROW_HEIGHT` (`int`, 96) — already exist.
- Produces: nothing new. Later tasks rely only on the corrected geometry.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_day_summary.gd`:

```gdscript
## The 2026-09-03 fix: the "+12/65" label owns the row's right-hand
## VALUE_WIDTH and nothing else. It used to be offset -321/-121, which
## laid it straight over the Track and is what "StatRow is bugged" meant.
func test_stat_row_value_label_sits_right_of_the_track() -> void:
	var row := load("res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn").instantiate()
	var value: Label = row.get_node("Value")
	var track: ProgressBar = row.get_node("Track")
	assert_eq(value.offset_left, -float(DaySummaryStatRow.VALUE_WIDTH),
		"Value.offset_left must be -VALUE_WIDTH")
	assert_eq(value.offset_right, 0.0,
		"Value must reach the row's right edge")
	assert_true(track.offset_right <= value.offset_left,
		"Track must end where Value begins -- they must not overlap")
	row.free()


## Three rows, one pitch. They were 97 / 100 apart, which reads as a
## misaligned bottom row against the card art.
func test_card_pitches_its_three_stat_rows_evenly() -> void:
	var card := load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn").instantiate()
	var tops: Array[float] = []
	for n in ["StatRow1", "StatRow2", "StatRow3"]:
		var r: Control = card.get_node(n)
		tops.append(r.offset_top)
		assert_eq(r.offset_bottom - r.offset_top,
			float(DaySummaryStatRow.ROW_HEIGHT),
			"%s must be ROW_HEIGHT tall" % n)
	assert_eq(tops[1] - tops[0], tops[2] - tops[1],
		"the three stat rows must be evenly pitched")
	card.free()
```

- [ ] **Step 2: Run the tests to verify they fail**

MCP: `test_run(suite="day_summary")`.
Expected: both new tests FAIL — `Value.offset_left must be -VALUE_WIDTH`
(got `-321`) and `the three stat rows must be evenly pitched` (97 vs 100).

- [ ] **Step 3: Fix the two scenes through the editor**

`DaySummaryStatRow.tscn` — `scene_open`, then on node `Value`:

```
node_set_property(node_path="Value", property="offset_left", value=-200)
node_set_property(node_path="Value", property="offset_right", value=0)
```

then `scene_save`.

`DaySummaryStudentRow.tscn` — `scene_open`, then:

```
StatRow1: offset_top = 57,  offset_bottom = 153
StatRow2: offset_top = 154, offset_bottom = 250
StatRow3: offset_top = 251, offset_bottom = 347
```

then `scene_save`. Numbers must be unquoted (`57`, not `"57.0"`).

- [ ] **Step 4: Run the tests to verify they pass**

MCP: `test_run(suite="day_summary")`. Expected: whole suite green.

- [ ] **Step 5: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStatRow.tscn Scenes/SchoolSimulation/DaySummaryStudentRow.tscn tests/test_day_summary.gd && git commit -m "fix(daysummary): stop the stat value label printing over its track"
```

---

### Task 2: The needs-bar script and its one theme variation

An icon and an Indonesian tier word that live **inside** the card's existing
energy and mood `ProgressBar`s, per spec §3.2. There is no new node stacked
above or below those bars — a second bar-shaped element per need is exactly the
redundancy this design rules out. The bar keeps its fill, its geometry and its
existing `DaySummaryEnergyBar` / `DaySummaryMoodBar` variation.

**Files:**
- Create: `Scripts/SchoolSimulation/DaySummaryNeedsBar.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` (in `_build_day_summary`)
- Create then delete: `tests/test_zzz_rebake.gd` (transient rebake harness)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DesignTokens.day_stat_size`, `day_glyph_outline`,
  `text_outline_size`, `font_display` — all already exist. **Add no new
  `@export` to `DesignTokens`**: a new one is invisible to a running editor and
  would force a restart.
- Produces:
  - `class_name DaySummaryNeedsBar extends ProgressBar`
  - `DaySummaryNeedsBar.TIER_WORDS` — `Dictionary`, `{need_key: Array}`
  - `static DaySummaryNeedsBar.word_for(need_key: String, value: float) -> String`
  - `DaySummaryNeedsBar.set_need(need_key: String, value: float) -> void`
  - Theme variation `&"DaySummaryNeedsLabel"`.

Note the scene work is deliberately deferred to Task 3: this script's `@onready`
children do not exist until that task authors them, so the two land together and
only Task 3's tests instantiate the card.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`. This task tests only what does not need
the scene — the tier logic and the bake:

```gdscript
## The bar shows a word, not a number: the precise value is already
## carried by the bar's own fill, and the week's delta by DeltaLabel.
func test_needs_bar_words_follow_the_spec_tiers() -> void:
	assert_eq(DaySummaryNeedsBar.word_for("energy", 0.0), "Lelah")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 33.0), "Lelah")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 34.0), "Cukup")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 66.0), "Cukup")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 67.0), "Bugar")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 100.0), "Bugar")
	assert_eq(DaySummaryNeedsBar.word_for("mood", 10.0), "Sedih")
	assert_eq(DaySummaryNeedsBar.word_for("mood", 50.0), "Biasa")
	assert_eq(DaySummaryNeedsBar.word_for("mood", 90.0), "Senang")
	# An unknown need must not fabricate a mood.
	assert_eq(DaySummaryNeedsBar.word_for("stamina", 50.0), "")


## The word's variation must survive the bake, or it renders as a bare
## default Label -- dark, unrimmed, illegible on the bar's fill.
func test_theme_bakes_the_needs_label_variation() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_true(theme.has_font_size("font_size", "DaySummaryNeedsLabel"),
		"DaySummaryNeedsLabel must bake a font size")
	assert_true(theme.has_color("font_color", "DaySummaryNeedsLabel"),
		"DaySummaryNeedsLabel must bake a font colour")
```

- [ ] **Step 2: Run it to verify it fails**

MCP: `test_run(suite="day_summary")`.
Expected: FAIL — `Identifier "DaySummaryNeedsBar" not declared in the current scope`.

- [ ] **Step 3: Write the needs-bar script**

`Scripts/SchoolSimulation/DaySummaryNeedsBar.gd`:

```gdscript
@tool
extends ProgressBar
class_name DaySummaryNeedsBar

## The Daily Results card's energy or mood bar, now carrying an icon and
## an Indonesian tier word ("Lelah", "Senang") INSIDE itself. See the
## 2026-09-03 spec, section 3.2.
##
## Deliberately not a separate chip node: the card already has one bar per
## need, and a second bar-shaped element stacked beside it would read as a
## redundant duplicate. The bar keeps its fill -- that fill IS the precise
## reading the word summarises -- and its DaySummaryEnergyBar /
## DaySummaryMoodBar variation.
##
## The pre-existing DeltaLabel child is untouched: it is right-aligned and
## carries the week's signed number, while Word is left-aligned beside the
## icon, so the two never collide.

## Tier words per need, low to high, matched to TIER_CUTS. Indonesian,
## like every other game-facing string.
const TIER_WORDS := {
	"energy": ["Lelah", "Cukup", "Bugar"],
	"mood": ["Sedih", "Biasa", "Senang"],
}

## Upper bounds (inclusive) of the first two tiers, on the 0-100 scale.
## Anything above the second cut takes the top word.
const TIER_CUTS := [33.0, 66.0]

## Which icon each need wears. These are the project's existing
## transparent SVGs -- named for the need, as the design ask specified.
const ICON_FOR := {
	"energy": "res://Assets/Images/UI/Placeholders/icon_energy.svg",
	"mood": "res://Assets/Images/UI/Placeholders/icon_mood.svg",
}

@onready var icon: TextureRect = $Icon
@onready var word_label: Label = $Word


## The tier word for a need at a value. An unrecognised need returns ""
## rather than guessing -- a fabricated mood on the card would read as
## real data.
static func word_for(need_key: String, value: float) -> String:
	if not TIER_WORDS.has(need_key):
		return ""
	var words: Array = TIER_WORDS[need_key]
	for i in TIER_CUTS.size():
		if value <= float(TIER_CUTS[i]):
			return String(words[i])
	return String(words[words.size() - 1])


## Set the bar's value and dress its icon and word from one call. The
## card's two needs bars are written through this and nothing else, so the
## fill and the word can never disagree.
func set_need(need_key: String, need_value: float) -> void:
	value = need_value
	if ICON_FOR.has(need_key):
		icon.texture = load(ICON_FOR[need_key])
	word_label.text = word_for(need_key, need_value)
```

- [ ] **Step 4: Add the one variation to ThemeFactory**

In `Scripts/Design/ThemeFactory.gd`, at the end of `_build_day_summary`, append:

```gdscript
	# The 2026-09-03 needs word, which sits ON the energy/mood bar rather
	# than in a chip of its own -- so there is no new stylebox here, only
	# type. Same white-on-dark-rim inversion the rest of this card uses,
	# one step down from DaySummaryStat so a long word fits inside the bar.
	# Built only from tokens that already exist: a NEW DesignTokens
	# @export is invisible to a running editor and would make this bake
	# need a restart.
	theme.add_type("DaySummaryNeedsLabel")
	theme.set_type_variation("DaySummaryNeedsLabel", "Label")
	theme.set_font_size("font_size", "DaySummaryNeedsLabel",
		tokens.day_stat_size - 4)
	theme.set_color("font_color", "DaySummaryNeedsLabel", Color.WHITE)
	theme.set_constant("outline_size", "DaySummaryNeedsLabel",
		maxi(2, tokens.text_outline_size / 2))
	theme.set_color("font_outline_color", "DaySummaryNeedsLabel",
		tokens.day_glyph_outline)
	if tokens.font_display != null:
		theme.set_font("font", "DaySummaryNeedsLabel", tokens.font_display)
```

- [ ] **Step 5: Rebake the theme headlessly**

There is no MCP entry point for `Scripts/Design/BakeTheme.gd`. Write a transient
suite `tests/test_zzz_rebake.gd`:

```gdscript
@tool
extends McpTestSuite

## Transient: drives the theme rebake that File > Run normally does.
## Delete after running (see CLAUDE.md, "Working efficiently here").

func suite_name() -> String:
	return "zzz_rebake"

func test_rebake() -> void:
	var theme := ThemeFactory.build()
	var err := ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
	assert_eq(err, OK, "theme must save")
```

Then, in order: `filesystem_manage(op="scan")` → a no-op `script_patch` on
`Scripts/Design/ThemeFactory.gd` (add and remove a blank line; a benign
`GDScript reload failed with error code 43` in the log is expected) →
`test_run(suite="zzz_rebake")` → delete `tests/test_zzz_rebake.gd` and its
`.uid`.

- [ ] **Step 6: Run the tests to verify they pass**

`filesystem_manage(op="scan")`, then `test_run(suite="day_summary")`.
Expected: the two new tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryNeedsBar.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_day_summary.gd && git commit -m "feat(daysummary): add the needs-bar tier word and its theme variation"
```

---

### Task 3: Put the icon and word inside the card's two needs bars

The scene half of Task 2. `EnergyBar` and `MoodBar` keep their type, their
variation and their exact geometry — they gain a script and two children, and
nothing is added beside them.

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryNeedsBar.set_need(need_key, value)` and
  `DaySummaryNeedsBar.word_for(...)` from Task 2.
- Produces: the card's `energy_bar` / `mood_bar` `@onready` vars change type
  from `ProgressBar` to `DaySummaryNeedsBar`. No new node on the card.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## One node per need, not two. The icon and word live INSIDE the bar --
## a sibling chip beside it would duplicate the bar's own shape, which is
## the redundancy this design rules out.
func test_needs_bars_carry_their_icon_and_word_inside_themselves() -> void:
	var card := load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn").instantiate()
	for n in ["EnergyBar", "MoodBar"]:
		var bar := card.get_node_or_null(n) as DaySummaryNeedsBar
		assert_true(bar != null, "%s must be a DaySummaryNeedsBar" % n)
		assert_true(bar.get_node_or_null("Icon") != null,
			"%s must own its Icon" % n)
		assert_true(bar.get_node_or_null("Word") != null,
			"%s must own its Word" % n)
		assert_true(bar.get_node_or_null("DeltaLabel") != null,
			"%s must keep its existing DeltaLabel" % n)
	# No stacked second element per need.
	assert_true(card.get_node_or_null("EnergyPill") == null,
		"there must be no separate energy chip node")
	assert_true(card.get_node_or_null("MoodPill") == null,
		"there must be no separate mood chip node")
	card.free()


## Both entry points write the bars through set_need, so the fill and the
## word can never disagree.
func test_card_fills_its_needs_bars_on_both_paths() -> void:
	var theme: Theme = load(_THEME_PATH)
	var card := load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn").instantiate()
	card.theme = theme
	add_child(card)

	var student := StudentData.new()
	student.student_name = "Shinta"
	student.energy = 20.0
	student.mood = 90.0

	card.setup_row("Shinta", [], student)
	assert_eq(card.energy_bar.value, 20.0)
	assert_eq(card.energy_bar.get_node("Word").text, "Lelah")
	assert_eq(card.mood_bar.get_node("Word").text, "Senang")
	assert_true(card.energy_bar.get_node("Icon").texture != null,
		"the energy bar must carry icon_energy")

	card.setup_week_row(student)
	assert_eq(card.energy_bar.get_node("Word").text, "Lelah",
		"the weekly path must write the same word")
	assert_eq(card.mood_bar.value, 90.0)

	card.queue_free()
```

- [ ] **Step 2: Run it to verify it fails**

`test_run(suite="day_summary")`. Expected: FAIL — `EnergyBar must be a DaySummaryNeedsBar`.

- [ ] **Step 3: Add the script and the two children to each bar**

`scene_open` `DaySummaryStudentRow.tscn`. Leave `EnergyBar` and `MoodBar` where
they are (`offset_left = 336`, `offset_right = 579`; energy `113..181`, mood
`201..268`) and leave their `theme_type_variation` alone. On each, `script_attach`
`res://Scripts/SchoolSimulation/DaySummaryNeedsBar.gd`, then `node_create` two
children:

```
EnergyBar / MoodBar  (unchanged ProgressBar, now scripted)
  Icon : TextureRect
    anchors: left=0, top=0.5, right=0, bottom=0.5   # left-centre
    offset_left=14, offset_top=-22, offset_right=58, offset_bottom=22
    expand_mode = 1                # IGNORE_SIZE
    stretch_mode = 5               # KEEP_ASPECT_CENTERED
    texture = icon_energy.svg (EnergyBar) / icon_mood.svg (MoodBar)
  Word : Label
    anchors: left=0, top=0.5, right=0, bottom=0.5
    offset_left=68, offset_top=-26, offset_right=220, offset_bottom=26
    theme_type_variation = "DaySummaryNeedsLabel"
    text = "Lelah" (EnergyBar) / "Senang" (MoodBar)
    vertical_alignment = 1
  DeltaLabel : Label            # pre-existing, untouched, right-aligned
```

`anchors_preset` is inert — set the four anchors individually. Numbers must be
unquoted. `scene_save`.

- [ ] **Step 4: Widen the card script's two bar types and route through set_need**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, change the two existing
`@onready` declarations (do not add new ones):

```gdscript
## The two needs bars now carry their own icon and tier word inside
## themselves (2026-09-03 spec section 3.2), so they are typed as
## DaySummaryNeedsBar rather than plain ProgressBar. Everything else about
## them -- geometry, fill, variation -- is unchanged.
@onready var energy_bar: DaySummaryNeedsBar = $EnergyBar
@onready var mood_bar: DaySummaryNeedsBar = $MoodBar
```

In `setup_row`, replace the two plain assignments:

```gdscript
	energy_bar.set_need("energy", student.energy if student != null else 0.0)
	mood_bar.set_need("mood", student.mood if student != null else 0.0)
```

In `setup_week_row`'s null branch, replace `energy_bar.value = 0.0` /
`mood_bar.value = 0.0`:

```gdscript
		energy_bar.set_need("energy", 0.0)
		mood_bar.set_need("mood", 0.0)
```

and in its populated branch, replace `energy_bar.value = student.energy` /
`mood_bar.value = student.mood`:

```gdscript
	energy_bar.set_need("energy", student.energy)
	mood_bar.set_need("mood", student.mood)
```

Leave `_show_needs_delta` and the `DeltaLabel` calls exactly as they are — the
week's signed number keeps its own home.

Note for Task 7: `play_gain`'s `_play_needs_travel(bar, from, delay)` still
reads and writes `bar.value` directly, which is correct — it animates the fill
only, and the word is a tier summary that must not flicker mid-travel.

- [ ] **Step 5: Run the tests to verify they pass**

`filesystem_manage(op="scan")`, then `test_run(suite="day_summary")` and
`test_run(suite="result_checkup")`. Expected: both green.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd && git commit -m "feat(daysummary): put the needs icon and tier word inside the energy and mood bars"
```

---

### Task 4: Generate the placeholder particle sprites

Three transparent PNGs, drawn with flat geometry straight into an `Image` —
the same constraint and the same mould as
`Scripts/Design/GenerateStickyNoteIcons.gd` (no Python / ImageMagick / Inkscape
on this machine). The visual team replaces the files in place, so the names are
load-bearing.

**Files:**
- Create: `Scripts/Design/GenerateParticleSprites.gd`
- Creates (as output): `Assets/Images/Particles/particle_star.png`,
  `particle_confetti.png`, `particle_ring.png`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the three PNG paths above. Tasks 5 and 8 reference them by path.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The particle art is a placeholder by contract: the visual team drops
## real PNGs in at these exact names, so the names are load-bearing and
## a rename must break the build here.
func test_particle_sprites_exist_and_are_transparent() -> void:
	var paths := [
		"res://Assets/Images/Particles/particle_star.png",
		"res://Assets/Images/Particles/particle_confetti.png",
		"res://Assets/Images/Particles/particle_ring.png",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "missing particle sprite: " + p)
		var tex: Texture2D = load(p)
		assert_true(tex != null, "must load as a texture: " + p)
		var img := tex.get_image()
		assert_true(img.detect_alpha() != Image.ALPHA_NONE,
			"particle sprite must have a transparent background: " + p)
```

- [ ] **Step 2: Run it to verify it fails**

`test_run(suite="day_summary")`. Expected: FAIL — `missing particle sprite: res://Assets/Images/Particles/particle_star.png`.

- [ ] **Step 3: Write the generator**

`Scripts/Design/GenerateParticleSprites.gd`:

```gdscript
@tool
extends EditorScript

## One-time generator for the three reward-particle placeholder sprites
## (2026-09-03 spec section 3.3). Run it from the editor via File > Run
## (Ctrl+Shift+X).
##
## No Python / ImageMagick / Inkscape is installed on this machine, so the
## shapes are drawn straight into an Image with flat geometry -- the same
## constraint Scripts/Design/GenerateStickyNoteIcons.gd documents. They
## are deliberately crude: they exist so the bursts have something to
## throw, not as finished art. The visual team overrides these PNGs in
## place later -- KEEP THE FILE NAMES.

const SIZE := 128
const OUT_DIR := "res://Assets/Images/Particles/"

## White, so a GPUParticles2D's colour ramp can tint each sprite freely.
const INK := Color(1.0, 1.0, 1.0, 1.0)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_draw_star(), OUT_DIR + "particle_star.png")
	_save(_draw_confetti(), OUT_DIR + "particle_confetti.png")
	_save(_draw_ring(), OUT_DIR + "particle_ring.png")
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
	print("[GenerateParticleSprites] wrote 3 placeholders to ", OUT_DIR)


func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	assert(err == OK)


## A four-point sparkle: alpha falls off with distance along whichever
## axis is farther, pinched by the nearer one, which concaves the disc
## into points without rasterising a polygon.
func _draw_star() -> Image:
	var img := _blank()
	var c := float(SIZE) * 0.5
	for y in range(SIZE):
		for x in range(SIZE):
			var dx: float = absf(float(x) - c) / c
			var dy: float = absf(float(y) - c) / c
			var far: float = maxf(dx, dy)
			var near: float = minf(dx, dy)
			var a: float = clampf(1.0 - far - near * 3.0, 0.0, 1.0)
			a = pow(a, 0.6)
			if a > 0.0:
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return img


## A rounded rectangle chip, 60% wide and 90% tall, corners eased with a
## distance-to-inset-box test.
func _draw_confetti() -> Image:
	var img := _blank()
	var half_w := float(SIZE) * 0.30
	var half_h := float(SIZE) * 0.45
	var radius := float(SIZE) * 0.10
	var c := float(SIZE) * 0.5
	for y in range(SIZE):
		for x in range(SIZE):
			var dx: float = absf(float(x) - c) - (half_w - radius)
			var dy: float = absf(float(y) - c) - (half_h - radius)
			var dist: float = Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
			if dist <= radius:
				var a: float = clampf((radius - dist) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return img


## A soft hollow ring -- the burst's "pop" shockwave.
func _draw_ring() -> Image:
	var img := _blank()
	var c := float(SIZE) * 0.5
	var mid := float(SIZE) * 0.38
	var thickness := float(SIZE) * 0.08
	for y in range(SIZE):
		for x in range(SIZE):
			var d: float = Vector2(float(x) - c, float(y) - c).length()
			var a: float = clampf(1.0 - absf(d - mid) / thickness, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return img
```

- [ ] **Step 4: Run the generator and re-import**

`filesystem_manage(op="scan")`, then in the editor: File > Run
(Ctrl+Shift+X) on `Scripts/Design/GenerateParticleSprites.gd`. Confirm the log
line `[GenerateParticleSprites] wrote 3 placeholders to res://Assets/Images/Particles/`,
then `filesystem_manage(op="scan")` again so the `.import` files land.

- [ ] **Step 5: Run the test to verify it passes**

`test_run(suite="day_summary")`. Expected: `test_particle_sprites_exist_and_are_transparent` PASSes.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/GenerateParticleSprites.gd Assets/Images/Particles tests/test_day_summary.gd && git commit -m "feat(daysummary): generate the three reward-particle placeholder sprites"
```

---

### Task 5: The two particle scenes

Both authored in `.tscn` (never built at runtime), both one-shot, both
self-freeing.

**Files:**
- Create: `Scripts/SchoolSimulation/RewardParticles.gd`
- Create: `Scenes/SchoolSimulation/RewardBurst.tscn`
- Create: `Scenes/SchoolSimulation/CelebrationConfetti.tscn`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: the three PNGs from Task 4; `AudioDirector.play_sfx(&"sparkle")`
  from Task 6 (harmless before Task 6 lands — `play_sfx` is null-safe).
- Produces: `class_name RewardParticles`, with
  `fire(delay: float = 0.0) -> void` and the `@export var plays_sfx: bool`.
  Attached to the root of both scenes.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## Both bursts must be one-shot and start idle: a looping emitter left
## running under a card would never free and would leak per row, per day.
func test_particle_scenes_are_one_shot_and_start_idle() -> void:
	for path in [
		"res://Scenes/SchoolSimulation/RewardBurst.tscn",
		"res://Scenes/SchoolSimulation/CelebrationConfetti.tscn",
	]:
		var fx := load(path).instantiate() as GPUParticles2D
		assert_true(fx != null, "must be a GPUParticles2D: " + path)
		assert_true(fx.one_shot, "must be one_shot: " + path)
		assert_true(not fx.emitting, "must start idle: " + path)
		assert_true(fx.texture != null, "must carry a sprite: " + path)
		assert_true(fx.process_material != null,
			"must carry a ParticleProcessMaterial: " + path)
		fx.free()
```

- [ ] **Step 2: Run it to verify it fails**

`test_run(suite="day_summary")`. Expected: FAIL — the scenes do not exist.

- [ ] **Step 3: Write the shared script**

`Scripts/SchoolSimulation/RewardParticles.gd`:

```gdscript
@tool
extends GPUParticles2D
class_name RewardParticles

## A one-shot congratulation burst (2026-09-03 spec section 3.3), shared
## by the per-stat RewardBurst and the screen-wide CelebrationConfetti --
## the two scenes differ only in their authored emitter settings, never
## in code.
##
## Fire-and-forget: fire() restarts the emitter and frees the node once
## the burst has run out, so a caller never has to track it. Nothing here
## builds a material or a texture; both are authored in the .tscn.

## How long after the burst's lifetime before the node frees itself.
## Covers the longest a single particle can outlive `lifetime` under the
## emitter's own randomness.
const CLEANUP_GRACE := 0.5

## Whether firing also plays the sparkle cue. Turned off for the second
## and later bursts of one gesture, so a card with three gaining rows
## does not play the same sound three times in 160 ms.
@export var plays_sfx: bool = true


## Restart the burst after `delay` seconds and free this node when it is
## spent. Safe to call on a node that is already emitting -- restart()
## rewinds rather than stacking. A coroutine, so never call it from a
## test: the MCP runner does not await.
func fire(delay: float = 0.0) -> void:
	if Engine.is_editor_hint():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	restart()
	emitting = true
	if plays_sfx:
		AudioDirector.play_sfx(&"sparkle")
	await get_tree().create_timer(lifetime + CLEANUP_GRACE).timeout
	queue_free()
```

- [ ] **Step 4: Build `RewardBurst.tscn` through the editor**

`scene_manage` a new scene at `res://Scenes/SchoolSimulation/RewardBurst.tscn`,
one node, then `scene_save`:

```
RewardBurst : GPUParticles2D   (root)
  script = res://Scripts/SchoolSimulation/RewardParticles.gd
  texture = res://Assets/Images/Particles/particle_star.png
  amount = 14
  lifetime = 0.7
  one_shot = true
  emitting = false
  explosiveness = 0.85
  local_coords = false
  process_material = a new ParticleProcessMaterial with:
    emission_shape = 1            # sphere
    emission_sphere_radius = 24
    direction = Vector3(0, -1, 0)
    spread = 45
    initial_velocity_min = 120
    initial_velocity_max = 260
    gravity = Vector3(0, 420, 0)
    scale_min = 0.18
    scale_max = 0.34
    angular_velocity_min = -220
    angular_velocity_max = 220
    color = Color("ffd76a")       # the card's gold, matching the chevron
```

Create the `ParticleProcessMaterial` with `material_manage` (or
`resource_manage`) and assign it with `node_set_property`; do not construct it
from a script.

- [ ] **Step 5: Build `CelebrationConfetti.tscn` through the editor**

Same shape, wider and slower:

```
CelebrationConfetti : GPUParticles2D   (root)
  script = res://Scripts/SchoolSimulation/RewardParticles.gd
  texture = res://Assets/Images/Particles/particle_confetti.png
  amount = 90
  lifetime = 2.4
  one_shot = true
  emitting = false
  explosiveness = 0.25
  local_coords = false
  process_material = a new ParticleProcessMaterial with:
    emission_shape = 3            # box
    emission_box_extents = Vector3(540, 8, 1)   # the full 1080 width
    direction = Vector3(0, 1, 0)
    spread = 25
    initial_velocity_min = 90
    initial_velocity_max = 240
    gravity = Vector3(0, 300, 0)
    scale_min = 0.22
    scale_max = 0.45
    angular_velocity_min = -320
    angular_velocity_max = 320
```

- [ ] **Step 6: Run the test to verify it passes**

`filesystem_manage(op="scan")`, then `test_run(suite="day_summary")`.
Expected: `test_particle_scenes_are_one_shot_and_start_idle` PASSes.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/RewardParticles.gd Scenes/SchoolSimulation/RewardBurst.tscn Scenes/SchoolSimulation/CelebrationConfetti.tscn tests/test_day_summary.gd && git commit -m "feat(daysummary): add the reward burst and celebration confetti scenes"
```

---

### Task 6: Add the two SFX slots

`AudioDirector` reaches its streams only through `@export` slots and a
`_resolve_sfx` match; screens never load audio directly (enforced by
`tests/test_audio_coverage.gd::test_no_screen_loads_an_audio_file_directly`).
Task 5's `RewardParticles.fire()` already calls `&"sparkle"`, so this task is
what stops that call silently no-op'ing.

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd`
- Modify: whichever scene/resource carries the `AudioDirector` autoload's
  exported streams (assign the two placeholder `.ogg` files there)
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `AudioDirector.play_sfx(&"tally")` and `play_sfx(&"sparkle")`,
  both answering `true` from `AudioDirector.has_sfx(...)`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_audio_director.gd`:

```gdscript
## The 2026-09-03 polish pass's two new cues. They alias existing files
## for now (pop.ogg / reward.ogg) -- placeholder streams, real ids.
func test_the_polish_pass_cues_resolve() -> void:
	assert_true(AudioDirector.has_sfx(&"tally"),
		"sfx_tally must be filled -- the stat chevron cue")
	assert_true(AudioDirector.has_sfx(&"sparkle"),
		"sfx_sparkle must be filled -- the reward burst cue")
```

- [ ] **Step 2: Run it to verify it fails**

`test_run(suite="audio_director")`. Expected: FAIL — `sfx_tally must be filled`.

- [ ] **Step 3: Add the two slots**

In `Scripts/Audio/AudioDirector.gd`, after the `sfx_reward` export:

```gdscript
## `play_sfx(&"tally")`: a Daily Results stat row's gold chevron pops in
## on a day that gained. Placeholder: aliases SFX/pop.ogg until a real
## tick lands.
@export var sfx_tally: AudioStream
## `play_sfx(&"sparkle")`: a reward burst or the weekly celebration
## confetti fires. Placeholder: aliases SFX/reward.ogg.
@export var sfx_sparkle: AudioStream
```

and in `_resolve_sfx`, beside the existing arms:

```gdscript
		&"tally": return sfx_tally
		&"sparkle": return sfx_sparkle
```

- [ ] **Step 4: Fill the two slots in the editor**

`filesystem_manage(op="scan")`, then a no-op `script_patch` on
`Scripts/Audio/AudioDirector.gd` (add and remove a blank line) — a new `@export`
is invisible to a running editor otherwise. Then set:

```
sfx_tally   = res://Assets/Audio/SFX/pop.ogg
sfx_sparkle = res://Assets/Audio/SFX/reward.ogg
```

- [ ] **Step 5: Run the tests to verify they pass**

`test_run(suite="audio_director")` and `test_run(suite="audio_coverage")`.
Expected: both green. `test_audio_director` snapshots and restores the global
AudioServer bus state, so a run must leave
`Assets/Audio/default_bus_layout.tres` unmodified — if `git status` shows it
dirty after this, that is a new leak, not the old known issue.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd && git commit -m "feat(audio): add the tally and sparkle cues for the results polish pass"
```

---

### Task 7: Fire the per-row bursts and the tally cue from the card

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd`
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `RewardParticles.fire(delay)` and `plays_sfx` (Task 5);
  `AudioDirector.play_sfx(&"tally")` / `&"sparkle"` (Task 6);
  `DaySummaryStatRow.shows_chevron(delta) -> bool` (already exists).
- Produces: `DaySummaryStatRow.play_gain(delay: float = 0.0, with_burst: bool = true)`
  — the second parameter is new and defaults so existing callers need no change;
  `DaySummaryStudentRow.gained_ground() -> bool`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## Only a real gain earns a burst. A flat or losing day must stay quiet,
## or the reward stops meaning anything.
func test_only_a_gaining_card_reports_ground_gained() -> void:
	var theme: Theme = load(_THEME_PATH)
	var card := load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn").instantiate()
	card.theme = theme
	add_child(card)

	var student := StudentData.new()
	student.student_name = "Shinta"
	student.target_akademis1 = 65.0
	student.target_akademis2 = 65.0
	student.target_akademis3 = 65.0
	student.akademis = 30.0

	card.setup_row("Shinta", [], student)
	assert_true(not card.gained_ground(),
		"a day with no changes must not celebrate")

	card.setup_row("Shinta", [{"stat_key": "akademis", "delta": -4.0}], student)
	assert_true(not card.gained_ground(),
		"a losing day must not celebrate")

	card.setup_row("Shinta", [{"stat_key": "akademis", "delta": 12.0}], student)
	assert_true(card.gained_ground(),
		"a gaining day must celebrate")

	card.queue_free()


## The burst rides the chevron: same condition, same beat.
func test_stat_row_bursts_exactly_when_it_shows_a_chevron() -> void:
	var src := _script_source(
		"res://Scripts/SchoolSimulation/DaySummaryStatRow.gd")
	assert_true(src.contains("BURST_SCENE"),
		"the stat row must instance the authored burst scene")
	assert_true(src.contains('play_sfx(&"tally")'),
		"the chevron pop must play the tally cue")
	assert_true(not src.contains("GPUParticles2D.new()"),
		"particles must come from the .tscn, never be built at runtime")
```

If `tests/test_day_summary.gd` has no `_script_source` helper yet, add one —
this is the project's established source-scan pattern:

```gdscript
## Read a .gd as text. Many tests here are source scans rather than
## behavioural, because a lot of this UI cannot be driven headlessly.
func _script_source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()
```

- [ ] **Step 2: Run it to verify it fails**

`test_run(suite="day_summary")`. Expected: FAIL — `Invalid call. Nonexistent function 'gained_ground'`.

- [ ] **Step 3: Fire the burst from the stat row**

In `Scripts/SchoolSimulation/DaySummaryStatRow.gd`, add to the constant block:

```gdscript
## The authored one-shot burst thrown at a row that gained. Instanced,
## never built -- see the project's "no visual is built at runtime" rule.
const BURST_SCENE := "res://Scenes/SchoolSimulation/RewardBurst.tscn"
```

and replace `play_gain` and its doc comment with:

```gdscript
## Replay today's movement: rewind the track to where it stood this
## morning and grow it back to where set_stat already left it, popping
## the chevron in over the same beat and -- on a day that actually
## gained -- throwing a star burst from the chevron. `delay` holds the
## whole gesture so a card can stagger its three rows.
##
## `with_burst` lets the card suppress the sound on the second and later
## bursts of one gesture, so three gaining rows do not fire three sparkle
## cues 80 ms apart; see DaySummaryStudentRow.play_gain.
##
## Never awaited and never required -- set_stat has already written the
## final value, so a caller that skips this sees a correct, static card.
##
## Call set_stat first: this reads the two ends it cached, which default
## to 0.0 and would otherwise empty the track.
func play_gain(delay: float = 0.0, with_burst: bool = true) -> void:
	track.value = _fill_from
	Juice.fill_bar(track, _fill_to, -1.0, delay)
	if chevron.visible:
		Juice.pop_in(chevron, delay)
		_play_burst(delay, with_burst)
	Juice.count_up_formatted(value, 0.0, _delta,
		func(v: float) -> String: return format_value(v, _target), delay)


## The gain's reward: a star burst centred on the chevron, plus the tally
## tick on the same beat. Editor-gated -- the test runner builds these
## rows to inspect them, not to watch them.
func _play_burst(delay: float, plays_sfx: bool) -> void:
	if Engine.is_editor_hint():
		return
	var fx := load(BURST_SCENE).instantiate() as RewardParticles
	fx.plays_sfx = plays_sfx
	fx.position = chevron.position + chevron.size * 0.5
	add_child(fx)
	fx.fire(delay)
	if plays_sfx:
		AudioDirector.play_sfx(&"tally")
```

- [ ] **Step 4: Let the card suppress duplicate cues and report its verdict**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, add a cache beside the
existing `_energy_delta` / `_mood_delta` fields:

```gdscript
## Whether any of the three skills moved UP on the day (or week) this
## card is currently showing. Written by _write_stat_rows, read by
## gained_ground() -- the screens use it to decide whether to celebrate.
var _gained_ground: bool = false
```

At the top of `_write_stat_rows`, add `_gained_ground = false`, and inside its
loop, after the `stat_rows[i].set_stat(...)` call:

```gdscript
		if float(deltas.get(key, 0.0)) > 0.0:
			_gained_ground = true
```

Add the accessor:

```gdscript
## True when at least one skill gained on the day (or week) this card is
## showing. The screens gate their celebration on it -- a flat or losing
## card stays quiet, so the reward keeps meaning something.
func gained_ground() -> bool:
	return _gained_ground
```

Finally, in `play_gain`, replace the stat-row loop so only the first gaining row
carries the sound:

```gdscript
	# Only the first burst of the card's gesture carries the sparkle cue:
	# three gaining rows 80 ms apart would otherwise fire it three times.
	var sfx_spent := false
	for i in stat_rows.size():
		var wants_sfx := not sfx_spent and stat_rows[i].chevron.visible
		if wants_sfx:
			sfx_spent = true
		stat_rows[i].play_gain(delay + float(i) * GAIN_STEP, wants_sfx)
```

- [ ] **Step 5: Run the tests to verify they pass**

`filesystem_manage(op="scan")`, then `test_run(suite="day_summary")` and
`test_run(suite="school_day")`. Expected: both green.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd && git commit -m "feat(daysummary): burst stars and tick the tally when a stat gains"
```

---

### Task 8: Celebrate the week on ResultCheckup

The weekly screen already replays every card's growth (and now their bursts,
free, via Task 7). This adds the screen-wide confetti on top, once, and only
when the week actually went somewhere.

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn`
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `DaySummaryStudentRow.gained_ground()` (Task 7),
  `RewardParticles.fire(delay)` (Task 5), `Juice.tokens().stagger_step`.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
## The weekly celebration is authored, gated and singular: one confetti
## node in the scene, fired only when a card actually gained, never
## constructed at runtime.
func test_checkup_celebrates_only_a_week_that_gained() -> void:
	var src := _source("res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_true(src.contains("gained_ground()"),
		"the confetti must be gated on a card having gained ground")
	assert_true(src.contains("celebration"),
		"the checkup must reference its authored confetti node")
	assert_true(not src.contains("GPUParticles2D.new()"),
		"the confetti must come from the .tscn, never be built at runtime")


func test_checkup_scene_carries_an_idle_confetti_node() -> void:
	var screen := load("res://Scenes/SchoolSimulation/ResultCheckup.tscn").instantiate()
	var fx := screen.get_node_or_null("Celebration") as GPUParticles2D
	assert_true(fx != null, "ResultCheckup must author a Celebration node")
	assert_true(not fx.emitting, "the confetti must start idle")
	assert_true(fx.one_shot, "the confetti must be one_shot")
	screen.free()
```

If `tests/test_result_checkup.gd` has no `_source` helper, copy the one from
`tests/test_audio_coverage.gd:16`:

```gdscript
func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()
```

- [ ] **Step 2: Run it to verify it fails**

`test_run(suite="result_checkup")`. Expected: FAIL — `ResultCheckup must author a Celebration node`.

- [ ] **Step 3: Add the confetti node to the scene**

`scene_open` `res://Scenes/SchoolSimulation/ResultCheckup.tscn`. Instance
`res://Scenes/SchoolSimulation/CelebrationConfetti.tscn` as a child of the root,
renamed `Celebration`, then:

```
position = Vector2(540, -40)     # centred on the 1080-wide screen, just above its top edge
z_index  = 100                   # over the cards
```

`node_create` appends last, which is the z-order we want — but set `z_index`
anyway so a later node cannot bury it. `scene_save`.

- [ ] **Step 4: Fire it from the screen**

In `Scripts/SchoolSimulation/ResultCheckup.gd`, add to the `@onready` block:

```gdscript
## The week's celebration, authored in the scene and fired at most once
## per screen -- see _play_entrance_animations.
@onready var celebration: RewardParticles = $Celebration
```

In `_play_entrance_animations`, after the `cards[i].play_week_gain(...)` loop and
before the `await get_tree().create_timer(t.dur_slow).timeout` line:

```gdscript
	# One celebration for the whole week, landing just behind the last
	# card's own burst -- and only if the week went somewhere. A flat or
	# losing week gets the report without the party.
	var week_gained := false
	for card in cards:
		if card.gained_ground():
			week_gained = true
			break
	if week_gained:
		celebration.fire(float(cards.size()) * t.stagger_step)
```

`_play_entrance_animations` already returns early under
`Engine.is_editor_hint()`, so the test runner never fires this.

- [ ] **Step 5: Run the tests to verify they pass**

`filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`.
Expected: green.

- [ ] **Step 6: Run the whole suite**

`test_run()` with no suite argument. Expected: every suite green — in
particular `script_documentation`, `viewport_editability`, `project_hygiene`
and `audio_coverage`, which are the ratchets this plan's new scripts and scenes
are most likely to trip. Fix anything red before committing.

- [ ] **Step 7: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd && git commit -m "feat(resultcheckup): rain confetti on a week that gained ground"
```

---

### Task 9: Verify on screen and record the pass

Everything above is verified by tests; this task is the one genuinely visual
check, plus the documentation the project expects at the end of a pass.

**Files:**
- Modify: `CLAUDE.md` ("Current work" section)
- Modify: `docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md`
  (add a STATUS block)

**Interfaces:**
- Consumes: everything.
- Produces: nothing.

- [ ] **Step 1: Reach the weekly screen without playing the game**

`project_run`, then `F1` (or five taps top-right) for the debug overlay →
General tab → **⚡ Seed Playtest State** → Scenes tab. The seed does *not* fill
`day_schedules`, so schedule a week through Atur Jadwal first, then run
SchoolDay through to the nightly popup and on to ResultCheckup.

- [ ] **Step 2: Screenshot both screens and check them against the reference**

`editor_screenshot` on the nightly popup and on ResultCheckup. Confirm, against
the supplied reference image:

- "+12/65" sits to the RIGHT of its coloured track, never over it
- the three stat rows are evenly pitched against the card art
- each needs bar carries its icon and Indonesian tier word inside itself — one
  element per need, with nothing stacked above or below it
- stars burst from a gaining row's chevron; confetti falls on ResultCheckup

- [ ] **Step 3: Record the pass**

Add a STATUS block to
`docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md` naming any
deviation you had to make (crude placeholder art and the two aliased SFX are
expected deviations, already documented in §4 — note anything beyond them).
Then add a paragraph to `CLAUDE.md`'s "Current work" section in the style of the
entries already there: what landed, and that the particle PNGs and the `tally` /
`sparkle` streams are placeholders the visual and audio teams replace in place.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md && git commit -m "docs(daysummary): record the 2026-09-03 results polish and reward pass"
```
