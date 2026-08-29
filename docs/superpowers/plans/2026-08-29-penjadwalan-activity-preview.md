# Penjadwalan Activity-Preview Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Penjadwalan popup (the "sticky note" that opens when you tap a day in Atur Jadwal) so each of the five activity rows shows an icon plus a preview of *what that activity will do* — sourced from `Balance.gd` instead of the file's own shadow constants.

**Architecture:** Extract the preview arithmetic into a pure static helper (`ActivityPreview`) that reads `Balance.gd` and is testable without instantiating any scene. Build one reusable `ActivityRow` widget for the row layout (icon + pill + outlined name), then rebuild the popup's five children from it. The three skill rows keep their existing `StatBar` progress-toward-target fill and only swap the label from a percentage to the gain delta; Wirausaha and Libur get static pills with two value chips each.

**Tech Stack:** Godot 4.6, GDScript. `StatBar` (`Scripts/UI/StatBar.gd`), `ThemeFactory` design-token pipeline, `McpTestSuite` test runner.

**Spec:** No separate spec document — this plan was written directly from a user-supplied mockup image plus the four clarifying answers recorded under "Design Decisions" below. That section is the spec.

## Global Constraints

- Game-facing identifiers and all UI text are **Indonesian**; engine and systems code is English.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).
- Tunable gameplay numbers belong in `Balance.gd`, not inline literals.
- Every interactive control must be at least `tokens.touch_target_min` (96px) tall — `tests/test_atur_jadwal.gd::test_interactive_controls_meet_the_minimum_touch_target` enforces this.
- Test suites must be `@tool` and **no test may be a coroutine** (the runner calls `suite.call(name)` without awaiting).
- Run `filesystem_manage(op="scan")` after editing any `.gd` and before `test_run`, or the runner serves a stale autoload.
- The category **keys** used in code stay `Akademis` / `SeniBudaya` / `Olahraga` / `Wirausaha` / `Istirahat`. Only the **displayed labels** change.

## Design Decisions

These four answers came from the user and are binding:

1. **The progress bar stays.** The three skill rows keep the existing `StatBar` fill showing progress toward target. Only the *label* changes — from `"80%"` to the gain delta `"+3"`.
2. **Preview numbers come from `Balance.gd`.** `atur_jadwal.gd` currently defines its own `BASE_GAIN`, `HOBBY_BONUS_GAIN`, `MOOD_LOSS_*`, `ENERGY_LOSS_*`, `DAYOFF_GAIN_*`, and `WIRAUSAHA_*` constants that shadow `Balance.gd`. These get wired through.
3. **No pre-rolling.** The preview shows a stable estimate; the simulation keeps rolling its own randomness at week-run time exactly as it does today. `StudentData.apply_jadwal_activity` is **not** modified.
4. **Colour scheme is out of scope.** The user's second mockup image (purple/green/orange/red/teal blobs) is explicitly deferred — `design_tokens.tres` category colours are left alone.

Two further notes from investigation:

- The mockup's numbers (`+19`, `+100.000`) are **placeholder art**, not targets. Real values: a grade-7 study day gains 3 (6 on specialty); Wirausaha pays 120–320G.
- The mockup's card art (yellow-green with a purple border) was not supplied as an asset. The popup keeps its existing `stickynotes.png` background. Swapping the card art is a separate future change.

## Displayed Values

Single source for every number the popup shows. `<grade>` is `GameState.current_grade`.

| Row | Displayed label | Left chip | Right chip |
|---|---|---|---|
| Akademik | `Akademik` | — | `+3` / `+6` (gain) |
| Seni Budaya | `Seni Budaya` | — | `+3` / `+6` (gain) |
| Atletik | `Atletik` | — | `+3` / `+6` (gain) |
| Wirausaha | `Wirausaha` | `-10` (energy) | `+120~320` (money) |
| Libur | `Libur` | `+20~30` (energy) | `+15~25` (mood) |

Skill gain = `BELAJAR_POIN_KELAS_<grade>`, plus `BELAJAR_BONUS_FAVORIT_KELAS_<grade>` when the category is the student's specialty. Values above are grade 7.

Fixed Balance values render as one number; ranged values render as `min~max`.

## File Structure

- **Create** `Scripts/AturJadwal/ActivityPreview.gd` — pure static helper. Turns `(category, student, grade)` into display strings. No scene, no node access, fully unit-testable. Owns *all* preview arithmetic.
- **Create** `tests/test_activity_preview.gd` — unit tests for the above.
- **Create** `Scripts/AturJadwal/ActivityRow.gd` + `Scenes/AturJadwal/ActivityRow.tscn` — the reusable row widget (a `Button` containing icon + pill + outlined name).
- **Modify** `Scripts/Design/ThemeFactory.gd` — add the `PreviewPill` and `PreviewChipLabel` variations.
- **Modify** `Scripts/AturJadwal/atur_jadwal.gd` — delete the shadow constants, route through `ActivityPreview`, populate the rows.
- **Modify** `Scenes/AturJadwal/atur_jadwal.tscn` — replace the five ad-hoc popup buttons with five `ActivityRow` instances in a `VBoxContainer`, add the back button.
- **Modify** `tests/test_atur_jadwal.gd` — update the popup structure tests.

---

### Task 1: ActivityPreview pure helper

Extracts every preview number into one testable file. Nothing renders yet; this task's deliverable is correct arithmetic sourced from `Balance.gd`.

**Files:**
- Create: `Scripts/AturJadwal/ActivityPreview.gd`
- Test: `tests/test_activity_preview.gd`

**Interfaces:**
- Consumes: `Balance` (autoloaded `class_name`), `GameState.current_grade`.
- Produces, for Task 2 and Task 4:
  - `ActivityPreview.skill_gain(category: String, student: Dictionary, grade: int) -> float`
  - `ActivityPreview.chips_for(category: String, student: Dictionary, grade: int) -> Array[Dictionary]` — each entry is `{"icon": String, "text": String}` where `icon` is one of `""`, `"energy"`, `"mood"`, `"money"`.
  - `ActivityPreview.energy_cost(category: String) -> float`
  - `ActivityPreview.mood_cost(category: String) -> float`
  - `ActivityPreview.format_range(low: float, high: float, prefix_sign: bool) -> String`

- [ ] **Step 1: Write the failing test**

Create `tests/test_activity_preview.gd`:

```gdscript
@tool
extends McpTestSuite

## ActivityPreview is the single source of every number the Penjadwalan
## popup displays. These tests pin it to Balance.gd: if a tester edits a
## Balance number, the preview must move with it. A hardcoded literal
## here would silently break that promise.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "activity_preview"


## A student whose specialty is Akademis. hobby_category "Akademik" is the
## UI spelling; the bridge normalizes it to "Akademis" (see CLAUDE.md).
func _student_akademis() -> Dictionary:
	return {"hobby_category": "Akademik", "name": "Uji"}


func _student_seniman() -> Dictionary:
	return {"hobby_category": "SeniBudaya", "name": "Uji"}


func test_skill_gain_uses_balance_for_a_non_specialty_subject() -> void:
	var gain := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 7)
	assert_eq(gain, Balance.BELAJAR_POIN_KELAS_7,
		"a non-specialty subject gains exactly the grade's base points")


func test_skill_gain_adds_the_specialty_bonus() -> void:
	var gain := ActivityPreview.skill_gain("Akademis", _student_akademis(), 7)
	assert_eq(gain, Balance.BELAJAR_POIN_KELAS_7 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_7,
		"the student's own specialty gains base + bonus")


func test_skill_gain_is_grade_aware() -> void:
	var g7 := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 7)
	var g8 := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 8)
	var g9 := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 9)
	assert_eq(g7, Balance.BELAJAR_POIN_KELAS_7, "grade 7 reads its own field")
	assert_eq(g8, Balance.BELAJAR_POIN_KELAS_8, "grade 8 reads its own field")
	assert_eq(g9, Balance.BELAJAR_POIN_KELAS_9, "grade 9 reads its own field")


## "Akademik" is the UI spelling of the "Akademis" category. A student whose
## hobby_category is "Akademik" must still get the specialty bonus on the
## "Akademis" row -- this mismatch is the single most common bug here.
func test_akademik_hobby_spelling_still_earns_the_specialty_bonus() -> void:
	var gain := ActivityPreview.skill_gain("Akademis", _student_akademis(), 7)
	assert_true(gain > Balance.BELAJAR_POIN_KELAS_7,
		"hobby_category 'Akademik' must match the 'Akademis' category")


func test_skill_row_has_one_chip_showing_the_gain() -> void:
	var chips := ActivityPreview.chips_for("SeniBudaya", _student_seniman(), 7)
	assert_eq(chips.size(), 1, "a skill row shows a single gain chip")
	assert_eq(chips[0]["icon"], "", "the skill chip carries no inline icon")
	var expected := Balance.BELAJAR_POIN_KELAS_7 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
	assert_eq(chips[0]["text"], "+%d" % int(expected),
		"the skill chip shows the signed gain")


func test_wirausaha_shows_energy_cost_then_money_range() -> void:
	var chips := ActivityPreview.chips_for("Wirausaha", _student_akademis(), 7)
	assert_eq(chips.size(), 2, "Wirausaha shows an energy chip and a money chip")
	assert_eq(chips[0]["icon"], "energy", "first chip is energy")
	assert_eq(chips[0]["text"], "-%d" % int(Balance.WIRAUSAHA_BIAYA_ENERGI),
		"energy cost is a fixed Balance value, shown as one number")
	assert_eq(chips[1]["icon"], "money", "second chip is money")
	assert_eq(chips[1]["text"], "+%d~%d" % [Balance.WIRAUSAHA_UANG_MIN, Balance.WIRAUSAHA_UANG_MAX],
		"money is a range, shown as min~max")


func test_libur_shows_energy_and_mood_recovery_ranges() -> void:
	var chips := ActivityPreview.chips_for("Istirahat", _student_akademis(), 7)
	assert_eq(chips.size(), 2, "Libur shows an energy chip and a mood chip")
	assert_eq(chips[0]["icon"], "energy", "first chip is energy")
	assert_eq(chips[0]["text"],
		"+%d~%d" % [int(Balance.LIBUR_ENERGI_PULIH_MIN), int(Balance.LIBUR_ENERGI_PULIH_MAX)],
		"energy recovery is a range")
	assert_eq(chips[1]["icon"], "mood", "second chip is mood")
	assert_eq(chips[1]["text"],
		"+%d~%d" % [int(Balance.LIBUR_MOOD_PULIH_MIN), int(Balance.LIBUR_MOOD_PULIH_MAX)],
		"mood recovery is a range")


func test_format_range_collapses_equal_bounds_to_one_number() -> void:
	assert_eq(ActivityPreview.format_range(10.0, 10.0, true), "+10",
		"a range whose bounds match renders as a single number")
	assert_eq(ActivityPreview.format_range(10.0, 20.0, true), "+10~20",
		"a genuine range renders as min~max")


func test_costs_for_a_study_day_come_from_balance() -> void:
	var e := ActivityPreview.energy_cost("Akademis")
	var m := ActivityPreview.mood_cost("Akademis")
	assert_eq(e, Balance.BELAJAR_BIAYA_ENERGI_MAX, "study energy cost reads Balance")
	assert_eq(m, Balance.BELAJAR_BIAYA_MOOD_MAX, "study mood cost reads Balance")


## Istirahat RECOVERS -- its stored cost must be negative, matching the sign
## convention day_schedules has always used.
func test_istirahat_costs_are_negative_because_it_recovers() -> void:
	assert_true(ActivityPreview.energy_cost("Istirahat") < 0.0,
		"Istirahat recovers energy, so its 'cost' is negative")
	assert_true(ActivityPreview.mood_cost("Istirahat") < 0.0,
		"Istirahat recovers mood, so its 'cost' is negative")


func test_no_hardcoded_balance_literals_in_the_helper() -> void:
	# The whole point of this file is that it holds no numbers of its own.
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ActivityPreview.gd")
	var regex := RegEx.new()
	regex.compile("(?<![\\w.])\\d+\\.\\d+")
	var allowed := ["0.0", "1.0"]
	for m in regex.search_all(src):
		assert_true(allowed.has(m.get_string()),
			"ActivityPreview must hold no balance literals; found " + m.get_string())
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="activity_preview")
```

Expected: FAIL — the suite aborts with a script error, `Identifier "ActivityPreview" not declared in the current scope`, because the file does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `Scripts/AturJadwal/ActivityPreview.gd`:

```gdscript
@tool
class_name ActivityPreview

## Every number the Penjadwalan popup shows, in one place, read from
## Balance.gd. Pure static functions -- no nodes, no scene, no state --
## so the numbers can be unit-tested without instantiating the screen.
##
## This file deliberately holds NO literals of its own. If you find
## yourself typing a number here, it belongs in Balance.gd instead.
##
## Note on preview honesty: the simulation rolls fresh randomness when the
## week actually runs (StudentData.apply_jadwal_activity). These functions
## return a stable estimate, not the exact value the student will get --
## the same contract SchoolDay._preview_gain has always used.


## The student's specialty, normalized. The roster stores the UI spelling
## "Akademik"; every category key in code is "Akademis". Getting this
## wrong silently drops the specialty bonus.
static func _specialty_of(student: Dictionary) -> String:
	var hobby: String = student.get("hobby_category", "")
	if hobby == "Akademik":
		return "Akademis"
	return hobby


## Points this category adds in ONE day, for this student, at this grade.
static func skill_gain(category: String, student: Dictionary, grade: int) -> float:
	var base := Balance.BELAJAR_POIN_CADANGAN
	var bonus := Balance.BELAJAR_BONUS_FAVORIT_CADANGAN
	match grade:
		7:
			base = Balance.BELAJAR_POIN_KELAS_7
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
		8:
			base = Balance.BELAJAR_POIN_KELAS_8
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
		9:
			base = Balance.BELAJAR_POIN_KELAS_9
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
	if _specialty_of(student) == category:
		return base + bonus
	return base


## Render a Balance range for display. Equal bounds collapse to one number
## so a fixed value does not read as a fake range ("+10", not "+10~10").
static func format_range(low: float, high: float, prefix_sign: bool) -> String:
	var sign_text := "+" if prefix_sign else "-"
	if is_equal_approx(low, high):
		return "%s%d" % [sign_text, int(low)]
	return "%s%d~%d" % [sign_text, int(low), int(high)]


## The chips shown inside one row's pill, left to right.
## Each entry: {"icon": "" | "energy" | "mood" | "money", "text": String}
static func chips_for(category: String, student: Dictionary, grade: int) -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	match category:
		"Wirausaha":
			chips.append({
				"icon": "energy",
				"text": format_range(Balance.WIRAUSAHA_BIAYA_ENERGI, Balance.WIRAUSAHA_BIAYA_ENERGI, false),
			})
			chips.append({
				"icon": "money",
				"text": format_range(Balance.WIRAUSAHA_UANG_MIN, Balance.WIRAUSAHA_UANG_MAX, true),
			})
		"Istirahat":
			chips.append({
				"icon": "energy",
				"text": format_range(Balance.LIBUR_ENERGI_PULIH_MIN, Balance.LIBUR_ENERGI_PULIH_MAX, true),
			})
			chips.append({
				"icon": "mood",
				"text": format_range(Balance.LIBUR_MOOD_PULIH_MIN, Balance.LIBUR_MOOD_PULIH_MAX, true),
			})
		_:
			var gain := skill_gain(category, student, grade)
			chips.append({"icon": "", "text": "+%d" % int(gain)})
	return chips


## Energy this category costs for one day, in the sign convention
## day_schedules has always used: positive drains, negative recovers.
static func energy_cost(category: String) -> float:
	match category:
		"Istirahat":
			return -Balance.LIBUR_ENERGI_PULIH_MAX
		"Wirausaha":
			return Balance.WIRAUSAHA_BIAYA_ENERGI
		_:
			return Balance.BELAJAR_BIAYA_ENERGI_MAX


## Mood this category costs for one day. Same sign convention as energy_cost.
static func mood_cost(category: String) -> float:
	match category:
		"Istirahat":
			return -Balance.LIBUR_MOOD_PULIH_MAX
		"Wirausaha":
			return Balance.WIRAUSAHA_BIAYA_MOOD
		_:
			return Balance.BELAJAR_BIAYA_MOOD_MAX
```

- [ ] **Step 4: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="activity_preview")
```

Expected: PASS, 12 tests.

If `test_no_hardcoded_balance_literals_in_the_helper` fails, you typed a number into the helper — move it to `Balance.gd`.

- [ ] **Step 5: Run the full suite to confirm nothing regressed**

```
filesystem_manage(op="scan")
test_run()
```

Expected: the previous total plus 12, with **exactly one** failure — the known `audio_director::test_volumes_persist_across_a_fresh_director` coroutine bug documented in CLAUDE.md's Known Issues. Any other failure is yours.

- [ ] **Step 6: Commit**

```bash
git add Scripts/AturJadwal/ActivityPreview.gd tests/test_activity_preview.gd
git commit -m "feat(atur-jadwal): add ActivityPreview, a Balance-sourced preview helper"
```

---

### Task 2: Wire atur_jadwal.gd's shadow constants to Balance

`atur_jadwal.gd` defines its own copies of numbers that also live in `Balance.gd`. CLAUDE.md calls this file out by name as "not yet wired". This task removes the shadows so a tester's `Balance.gd` edit actually moves the screen.

**Files:**
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:97-109` (the constant block), `:548-555` (`_compute_pending_gain`), `:958-983` (`_on_activity_selected`), `:1291-1300` (tutorial autofill)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `ActivityPreview.skill_gain()`, `ActivityPreview.energy_cost()`, `ActivityPreview.mood_cost()` from Task 1.
- Produces: no new public API. `GameState.day_schedules[id][day]` keeps its exact existing shape — `{category, mood_cost, energy_cost}` — which `test_day_schedules_still_written_in_the_same_shape` and `_compute_total_loss` both depend on.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_atur_jadwal.gd`:

```gdscript
## CLAUDE.md flags atur_jadwal.gd as holding its own copies of numbers that
## also live in Balance.gd. A shadow constant means the tester edits Balance,
## reruns, and the screen does not move -- the exact failure Balance.gd exists
## to prevent.
func test_no_shadow_balance_constants_remain() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for shadowed in [
		"BASE_GAIN", "HOBBY_BONUS_GAIN",
		"MOOD_LOSS_MIN", "MOOD_LOSS_MAX",
		"ENERGY_LOSS_MIN", "ENERGY_LOSS_MAX",
		"DAYOFF_GAIN_MIN", "DAYOFF_GAIN_MAX",
		"WIRAUSAHA_MOOD_MIN", "WIRAUSAHA_MOOD_MAX",
		"WIRAUSAHA_ENERGY_MIN", "WIRAUSAHA_ENERGY_MAX",
	]:
		assert_true(not src.contains("const " + shadowed),
			"atur_jadwal.gd must not redeclare " + shadowed + "; read Balance.gd via ActivityPreview")


## The projected-gain readout was grade-blind: it hardcoded grade 7's numbers,
## so grades 8 and 9 previewed gains their students would never get.
func test_pending_gain_is_grade_aware() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("ActivityPreview.skill_gain"),
		"_compute_pending_gain must delegate to ActivityPreview so it follows the grade")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: FAIL — both new tests fail; the constants are still declared and `_compute_pending_gain` still uses `HOBBY_BONUS_GAIN`.

- [ ] **Step 3: Delete the shadow constant block**

In `Scripts/AturJadwal/atur_jadwal.gd`, delete lines 97–109 entirely:

```gdscript
const BASE_GAIN := 3.0       # Must match StudentManager.gd apply_jadwal_activity base_gain
const HOBBY_BONUS_GAIN := 6.0  # Must match base_gain + specialty_bonus (3 + 3 = 6 total for specialty)

const MOOD_LOSS_MIN := 10
const MOOD_LOSS_MAX := 15
const ENERGY_LOSS_MIN := 15
const ENERGY_LOSS_MAX := 20
const DAYOFF_GAIN_MIN := 20
const DAYOFF_GAIN_MAX := 30
const WIRAUSAHA_MOOD_MIN := 8
const WIRAUSAHA_MOOD_MAX := 14
const WIRAUSAHA_ENERGY_MIN := 10
const WIRAUSAHA_ENERGY_MAX := 16
```

Replace with a comment pointing at the new source:

```gdscript
## Every preview number this screen shows now comes from Balance.gd via
## ActivityPreview. Do not reintroduce local copies -- a shadow constant
## means the tester edits Balance and the screen silently ignores it.
```

- [ ] **Step 4: Route `_compute_pending_gain` through ActivityPreview**

Replace `_compute_pending_gain` (was lines 548–555):

```gdscript
func _compute_pending_gain(category: String, student: Dictionary) -> float:
	var schedules = _get_current_schedules()
	var count := 0
	for day in schedules.keys():
		if schedules[day]["category"] == category:
			count += 1
	return count * ActivityPreview.skill_gain(category, student, GameState.current_grade)
```

- [ ] **Step 5: Route the two schedule-writing sites through ActivityPreview**

In `_on_activity_selected` (was lines 965–975), replace the whole `mood_cost` / `energy_cost` if/elif/else block:

```gdscript
		var mood_cost: int = int(ActivityPreview.mood_cost(category))
		var energy_cost: int = int(ActivityPreview.energy_cost(category))
```

In the tutorial autofill (was lines 1295–1296), replace:

```gdscript
					var mood_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
					var energy_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
```

with:

```gdscript
					var mood_cost = int(ActivityPreview.mood_cost("Istirahat"))
					var energy_cost = int(ActivityPreview.energy_cost("Istirahat"))
```

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: PASS. In particular `test_day_schedules_still_written_in_the_same_shape` must still pass — the dict keys are unchanged, only their source moved.

- [ ] **Step 7: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure.

- [ ] **Step 8: Commit**

```bash
git add Scripts/AturJadwal/atur_jadwal.gd tests/test_atur_jadwal.gd
git commit -m "fix(atur-jadwal): read preview numbers from Balance instead of local copies"
```

---

### Task 3: ActivityRow widget

The reusable row: an icon box, a pill, and the outlined category name. Built and tested standalone before the popup depends on it.

**Files:**
- Create: `Scripts/AturJadwal/ActivityRow.gd`, `Scenes/AturJadwal/ActivityRow.tscn`
- Modify: `Scripts/Design/ThemeFactory.gd`
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: `ActivityPreview.chips_for()` from Task 1; the `StatBar` class; `DesignTokens`.
- Produces, for Task 4:
  - `ActivityRow` extends `Button`, `class_name ActivityRow`
  - `@export var category: String` — one of the five category keys
  - `@export var display_name: String` — the Indonesian label shown to the player
  - `@export var icon_texture: Texture2D`
  - `ActivityRow.refresh(student: Dictionary, grade: int, progress_percent: float) -> void`
  - Signal: the inherited `Button.pressed`

- [ ] **Step 1: Add the two theme variations**

In `Scripts/Design/ThemeFactory.gd`, immediately after the `CardSectionLabel` block (currently ending at line 309), add:

```gdscript
	# -- Penjadwalan preview pill: the dark slab a row's numbers sit on. --
	var preview_pill := StyleBoxFlat.new()
	preview_pill.bg_color = tokens.surface_overlay
	preview_pill.corner_radius_top_left = tokens.radius_md
	preview_pill.corner_radius_top_right = tokens.radius_md
	preview_pill.corner_radius_bottom_left = tokens.radius_md
	preview_pill.corner_radius_bottom_right = tokens.radius_md
	preview_pill.content_margin_left = tokens.space_sm
	preview_pill.content_margin_right = tokens.space_sm
	preview_pill.content_margin_top = tokens.space_xs
	preview_pill.content_margin_bottom = tokens.space_xs
	theme.add_type("PreviewPill")
	theme.set_stylebox("panel", "PreviewPill", preview_pill)

	# -- The numbers inside that pill: white on the dark slab. --
	theme.add_type("PreviewChipLabel")
	theme.set_type_variation("PreviewChipLabel", "Label")
	theme.set_font_size("font_size", "PreviewChipLabel", tokens.font_h2)
	theme.set_color("font_color", "PreviewChipLabel", tokens.text_on_brand)
```

- [ ] **Step 2: Write the failing test**

Create `tests/test_activity_row.gd`:

```gdscript
@tool
extends McpTestSuite

## ActivityRow is the Penjadwalan popup's repeated row: icon, a pill of
## preview numbers, and the outlined category name. These tests pin its
## structure and its theming, because the popup builds five of them and a
## silent styling failure would be invisible until someone opened the game.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

const _SCENE_PATH := "res://Scenes/AturJadwal/ActivityRow.tscn"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "activity_row"


var _row: Button


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_row = scene.instantiate()
	_row.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_row)
	track(_row)


func teardown() -> void:
	if is_instance_valid(_row):
		_row.queue_free()
	_row = null


func test_scene_instantiates_as_a_button() -> void:
	assert_true(_row != null, "ActivityRow.tscn must load")
	assert_true(_row is Button, "the whole row must be tappable, so its root is a Button")


func test_row_meets_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	assert_true(_row.custom_minimum_size.y >= float(tokens.touch_target_min),
		"a row must be at least touch_target_min tall")


func test_row_has_the_nodes_the_script_reaches_for() -> void:
	for path in ["IconBox/Icon", "Pill", "Pill/Chips", "NameLabel"]:
		assert_true(_row.get_node_or_null(path) != null,
			"ActivityRow.tscn must declare the node: " + path)


func test_name_label_uses_the_outlined_variation() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.theme_type_variation, &"CardSectionLabel",
		"the category name is white-on-art, so it needs the outlined variation")


func test_pill_uses_the_preview_pill_variation() -> void:
	var pill := _row.get_node_or_null("Pill") as PanelContainer
	assert_true(pill != null, "Pill must exist")
	assert_eq(pill.theme_type_variation, &"PreviewPill",
		"the pill must wear the PreviewPill variation, not a theme_override")


func test_theme_declares_the_new_variations() -> void:
	var theme: Theme = load(_THEME_PATH)
	for variation in ["PreviewPill", "PreviewChipLabel"]:
		assert_true(theme.get_type_list().has(variation),
			"the baked theme must declare " + variation + " -- did you forget to rebake?")


func test_scene_has_no_theme_overrides() -> void:
	# The project rule: styling flows from the theme, never from per-node
	# overrides. Layout-only constants (separation, margin_*) are exempt.
	var src := FileAccess.get_file_as_string(_SCENE_PATH)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in ActivityRow.tscn: " + line)


func test_refresh_writes_the_skill_gain_into_a_chip() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Akademis"
	_row.refresh(student, 7, 50.0)
	var chips := _row.get_node("Pill/Chips")
	assert_true(chips.get_child_count() >= 1, "refresh must populate at least one chip")


func test_refresh_builds_two_chips_for_libur() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Istirahat"
	_row.refresh(student, 7, 0.0)
	var chips := _row.get_node("Pill/Chips")
	assert_eq(chips.get_child_count(), 2,
		"Libur shows an energy chip and a mood chip")


## Rebuilding must not accumulate. Opening the popup five times used to be
## enough to stack fifteen stale chips behind the live ones.
func test_refresh_is_idempotent() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Istirahat"
	_row.refresh(student, 7, 0.0)
	var after_first := _row.get_node("Pill/Chips").get_child_count()
	_row.refresh(student, 7, 0.0)
	_row.refresh(student, 7, 0.0)
	assert_eq(_row.get_node("Pill/Chips").get_child_count(), after_first,
		"refresh must clear old chips before adding new ones")
```

- [ ] **Step 3: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL — `ActivityRow.tscn` does not exist, so `setup()` errors.

- [ ] **Step 4: Write the ActivityRow script**

Create `Scripts/AturJadwal/ActivityRow.gd`:

```gdscript
@tool
class_name ActivityRow
extends Button

## One row of the Penjadwalan popup: an icon, a pill of preview numbers,
## and the category name. The whole row is the Button -- the player taps
## anywhere on it to assign that activity to the selected day.
##
## The three skill rows also carry a StatBar showing progress toward the
## student's target; Wirausaha and Libur have no target, so their pill
## holds only chips.

## One of: Akademis, SeniBudaya, Olahraga, Wirausaha, Istirahat.
@export var category: String = "Akademis"

## The Indonesian label the player reads. Deliberately separate from
## `category`: the UI says "Atletik" where the code says "Olahraga".
@export var display_name: String = "Akademik":
	set(value):
		display_name = value
		if is_inside_tree():
			var label := get_node_or_null("NameLabel") as Label
			if label:
				label.text = value

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			var icon := get_node_or_null("IconBox/Icon") as TextureRect
			if icon:
				icon.texture = value

## Icons for the inline chips, keyed by the "icon" field ActivityPreview
## returns. Assigned in the scene so the paths live in one place.
@export var energy_icon: Texture2D
@export var mood_icon: Texture2D
@export var money_icon: Texture2D


func _ready() -> void:
	var label := get_node_or_null("NameLabel") as Label
	if label:
		label.text = display_name
	var icon := get_node_or_null("IconBox/Icon") as TextureRect
	if icon:
		icon.texture = icon_texture


func _icon_for(key: String) -> Texture2D:
	match key:
		"energy": return energy_icon
		"mood": return mood_icon
		"money": return money_icon
		_: return null


## Repopulate this row for the given student. `progress_percent` drives the
## StatBar fill on skill rows and is ignored on Wirausaha/Libur, which have
## no target to progress toward.
func refresh(student: Dictionary, grade: int, progress_percent: float) -> void:
	var chips := get_node_or_null("Pill/Chips")
	if chips == null:
		return

	# Clear first: refresh is called every time the popup opens, and
	# appending without clearing stacks stale chips behind the live ones.
	for child in chips.get_children():
		child.queue_free()
		chips.remove_child(child)

	for chip in ActivityPreview.chips_for(category, student, grade):
		var tex := _icon_for(chip["icon"])
		if tex != null:
			var chip_icon := TextureRect.new()
			chip_icon.texture = tex
			chip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip_icon.custom_minimum_size = Vector2(48, 48)
			chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chips.add_child(chip_icon)
		var chip_label := Label.new()
		chip_label.theme_type_variation = &"PreviewChipLabel"
		chip_label.text = chip["text"]
		chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(chip_label)

	var bar := get_node_or_null("Pill/StatBar") as StatBar
	if bar:
		# Only the three skill rows carry a bar; the others left it out.
		bar.set_stat(progress_percent)
```

- [ ] **Step 5: Build the ActivityRow scene**

Create `Scenes/AturJadwal/ActivityRow.tscn` with this node tree. Set it up in the editor (`scene_manage`/`node_create`), or write the `.tscn` directly:

```
ActivityRow            Button      script=ActivityRow.gd, custom_minimum_size=(0, 96)
├── Layout             HBoxContainer   full-rect anchors, mouse_filter=Ignore,
│   │                                  theme_override_constants/separation = 16
│   ├── IconBox        PanelContainer  theme_type_variation="PreviewPill"
│   │   └── Icon       TextureRect     custom_minimum_size=(64,64),
│   │                                  stretch_mode=KeepAspectCentered
│   └── Pill           PanelContainer  theme_type_variation="PreviewPill",
│       │                              size_flags_horizontal=ExpandFill
│       ├── StatBar    StatBar         (skill rows only -- delete on Wirausaha/Libur)
│       └── Chips      HBoxContainer   alignment=End,
│                                      theme_override_constants/separation = 12
└── NameLabel          Label           theme_type_variation="CardSectionLabel",
                                       anchored bottom-right
```

Every child except the root must have `mouse_filter = Control.MOUSE_FILTER_IGNORE` so taps reach the root `Button`.

Assign the three chip icons on the root node:
- `energy_icon` → `res://Assets/Images/StudentCard/stat_energy.png`
- `mood_icon` → `res://Assets/Images/StudentCard/stat_mood.png`
- `money_icon` → leave null (no money icon ships; the money chip renders as text only)

- [ ] **Step 6: Rebake the theme**

`BakeTheme.gd` is an `EditorScript` (File > Run), which is not reachable over MCP. Run the same three lines through a live game instead:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "var t = DesignTokens.load_default()\nvar th = ThemeFactory.build(t)\nreturn ResourceSaver.save(th, \"res://Assets/Theme/kejartes_theme.tres\")"})
project_manage(op="stop")
filesystem_manage(op="scan")
```

Expected: `game_eval` returns `0` (`OK`).

- [ ] **Step 7: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 10 tests. If `test_theme_declares_the_new_variations` fails, the rebake in Step 6 did not land — rerun it.

- [ ] **Step 8: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure. Watch `theme_factory` and `student_card` especially — they assert against the same baked theme file you just rewrote.

- [ ] **Step 9: Commit**

```bash
git add Scripts/AturJadwal/ActivityRow.gd Scenes/AturJadwal/ActivityRow.tscn \
        Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres \
        tests/test_activity_row.gd
git commit -m "feat(atur-jadwal): add the ActivityRow preview widget"
```

---

### Task 4: Rebuild the Penjadwalan popup

Swap the five ad-hoc buttons for five `ActivityRow` instances and wire them up.

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn:372-473` (the whole `Penjadwalan/TextureRect` subtree)
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:52-60` (`@onready` refs), `:206-219` (`_tint_popup_activity_buttons`), `:913-923` (`_connect_activity_buttons`), `:999-1008` (`_update_popup_stats`)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `ActivityRow` (`category`, `display_name`, `refresh()`, `pressed`) from Task 3; `ActivityPreview` from Task 1.
- Produces: no new public API. `_on_activity_selected(category: String)` keeps its existing signature and behaviour.

- [ ] **Step 1: Write the failing test**

In `tests/test_atur_jadwal.gd`, **replace** the existing `test_popup_category_bars_are_statbars` with:

```gdscript
## The popup's five picks are ActivityRows now: icon, preview pill, name.
func test_popup_has_five_activity_rows() -> void:
	var root := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows")
	assert_true(root != null, "the popup must hold its rows in a Rows container")
	var found := {}
	for child in root.get_children():
		if child is ActivityRow:
			found[child.category] = child
	for category in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
		assert_true(found.has(category),
			"the popup must offer an ActivityRow for " + category)
	assert_eq(found.size(), 5, "exactly five activity rows, no more")


## The three skill rows keep their progress-toward-target bar; the other two
## have no target, so they must not carry one.
func test_only_skill_rows_carry_a_stat_bar() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	for child in root.get_children():
		if not (child is ActivityRow):
			continue
		var bar := child.get_node_or_null("Pill/StatBar")
		var is_skill: bool = child.category in ["Akademis", "SeniBudaya", "Olahraga"]
		if is_skill:
			assert_true(bar != null, child.category + " must keep its StatBar")
		else:
			assert_true(bar == null, child.category + " has no target, so no StatBar")


## The UI says "Atletik" where the code says "Olahraga". Keeping the two
## apart is what lets the label change without breaking every category match.
func test_display_names_are_indonesian_and_decoupled_from_category_keys() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	var expected := {
		"Akademis": "Akademik",
		"SeniBudaya": "Seni Budaya",
		"Olahraga": "Atletik",
		"Wirausaha": "Wirausaha",
		"Istirahat": "Libur",
	}
	for child in root.get_children():
		if child is ActivityRow:
			assert_eq(child.display_name, expected[child.category],
				child.category + " must display as " + expected[child.category])


func test_popup_still_has_a_back_button() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack")
	assert_true(back != null, "the popup needs its own back control")
	assert_true(back is BaseButton, "the back control must be tappable")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: FAIL — there is no `Rows` node yet.

- [ ] **Step 3: Rebuild the popup subtree in the scene**

In `Scenes/AturJadwal/atur_jadwal.tscn`, delete the five buttons and three progress bars under `Penjadwalan/TextureRect` (lines 388–473) and replace them with:

```
Penjadwalan/TextureRect          (unchanged: the sticky-note background)
├── Rows                 VBoxContainer   anchors_preset=15, margins inset ~80px,
│   │                                    theme_override_constants/separation = 24
│   ├── RowAkademik      ActivityRow  category="Akademis",   display_name="Akademik",
│   │                                 icon=stat_akademis.png,   keeps Pill/StatBar
│   ├── RowSeniBudaya    ActivityRow  category="SeniBudaya", display_name="Seni Budaya",
│   │                                 icon=stat_senibudaya.png, keeps Pill/StatBar
│   ├── RowAtletik       ActivityRow  category="Olahraga",   display_name="Atletik",
│   │                                 icon=stat_olahraga.png,   keeps Pill/StatBar
│   ├── RowWirausaha     ActivityRow  category="Wirausaha",  display_name="Wirausaha",
│   │                                 icon=stat_energy.png,     DELETE Pill/StatBar
│   └── RowLibur         ActivityRow  category="Istirahat",  display_name="Libur",
│                                     icon=stat_mood.png,       DELETE Pill/StatBar
└── PopupBack            Button       bottom-left, custom_minimum_size=(96, 96),
                                      theme_type_variation="SecondaryButton", text="←"
```

Set each row's `category` on the instance, not by editing `ActivityRow.tscn`.

Icon paths, all under `res://Assets/Images/StudentCard/`: `stat_akademis.png`, `stat_senibudaya.png`, `stat_olahraga.png`, `stat_energy.png`, `stat_mood.png`. These already ship in the deep purple the mockup uses — no new art is needed.

- [ ] **Step 4: Update the script's node references**

In `Scripts/AturJadwal/atur_jadwal.gd`, replace the popup `@onready` block (was lines 52–60):

```gdscript
# --- Penjadwalan Popup ---
@onready var penjadwalan_popup = $Penjadwalan
@onready var popup_rows = $Penjadwalan/TextureRect/Rows
@onready var popup_back_btn = $Penjadwalan/TextureRect/PopupBack
```

- [ ] **Step 5: Replace the three functions that drove the old buttons**

Replace `_tint_popup_activity_buttons` (was lines 206–219) — the rows carry their own art now, so the per-button tint is gone. Delete the function and its call site in `_ready` (was line 157).

Replace `_connect_activity_buttons` (was lines 913–923):

```gdscript
func _connect_activity_buttons():
	for row in popup_rows.get_children():
		if not (row is ActivityRow):
			continue
		if not row.pressed.is_connected(_on_activity_selected.bind(row.category)):
			row.pressed.connect(_on_activity_selected.bind(row.category))
	if popup_back_btn and not popup_back_btn.pressed.is_connected(_hide_penjadwalan_popup):
		popup_back_btn.pressed.connect(_hide_penjadwalan_popup)
```

Replace `_update_popup_stats` (was lines 999–1008):

```gdscript
## The three skill rows show progress toward that subject's target; the
## other two have no target and ignore the percentage they are handed.
func _update_popup_stats():
	var student = GameState.selected_student
	if student.is_empty():
		return
	var progress := {
		"Akademis": _percent(student.get("akademis1", 50.0), student.get("target_akademis1", 65.0)),
		"SeniBudaya": _percent(student.get("akademis2", 50.0), student.get("target_akademis2", 65.0)),
		"Olahraga": _percent(student.get("akademis3", 50.0), student.get("target_akademis3", 65.0)),
	}
	for row in popup_rows.get_children():
		if row is ActivityRow:
			row.refresh(student, GameState.current_grade, progress.get(row.category, 0.0))
```

Note the roster's key mapping, which does not line up with its names: `akademis1` is academic, `akademis2` is **seni budaya**, `akademis3` is **olahraga**. Getting this wrong is the single most common bug in this codebase.

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: PASS, including the pre-existing `test_scene_has_no_theme_overrides` and `test_interactive_controls_meet_the_minimum_touch_target`.

- [ ] **Step 7: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure.

- [ ] **Step 8: Verify it visually in the running game**

Do not click through the game to reach this state — seed it:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "DebugManager._seed_playtest_state()\nawait get_tree().process_frame\nget_tree().change_scene_to_file(\"res://Scenes/AturJadwal/atur_jadwal.tscn\")\nawait get_tree().process_frame\nawait get_tree().process_frame\nreturn get_tree().current_scene.name"})
editor_manage(op="game_eval", params={"code":
  "var s = get_tree().current_scene\nGameState.selected_day = \"Senin\"\nGameState.selected_student = GameState.approved_students[0]\ns._show_penjadwalan_popup()\nawait get_tree().process_frame\nreturn s.penjadwalan_popup_open"})
editor_screenshot(source="game", max_resolution=800)
```

Confirm against the mockup: five rows, each with its icon on the left, numbers right-aligned in the dark pill, the outlined name at the row's bottom-right, and the back arrow at bottom-left. Then check the numbers are real — a grade-7 non-specialist should read `+3`, their specialty `+6`, Wirausaha `-10` and `+120~320`, Libur `+20~30` and `+15~25`.

Tap a row and confirm it still assigns the day:

```
editor_manage(op="game_eval", params={"code":
  "var s = get_tree().current_scene\ns._on_activity_selected(\"Wirausaha\")\nawait get_tree().process_frame\nvar sid = GameState.selected_student.get(\"id\")\nreturn GameState.day_schedules[sid][\"Senin\"]"})
project_manage(op="stop")
```

Expected: `{category: "Wirausaha", mood_cost: 6, energy_cost: 10}` — the shape unchanged, the values now from `Balance.gd`.

- [ ] **Step 9: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn Scripts/AturJadwal/atur_jadwal.gd \
        tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): rebuild the Penjadwalan popup around ActivityRow"
```

---

## Self-Review

**Spec coverage.** Each of the four binding decisions maps to a task. (1) "Progress bar stays, label shows the delta" — Task 3's `refresh()` sets both the `StatBar` fill and the chip text, and Task 4's `test_only_skill_rows_carry_a_stat_bar` pins which rows keep a bar. (2) "Wire to Balance" — Task 1 builds the helper, Task 2 deletes the shadow constants and has a test asserting they stay gone. (3) "No pre-rolling" — no task touches `StudentData.apply_jadwal_activity`; `ActivityPreview` is documented as returning an estimate. (4) "Colours deferred" — no task modifies `design_tokens.tres`.

**Placeholder scan.** No TBDs. Every code step carries the actual code. The two visual steps (Task 3 Step 5, Task 4 Step 3) give explicit node trees with types, variations, and asset paths rather than "build the layout".

**Type consistency.** `ActivityPreview.chips_for()` returns `Array[Dictionary]` with keys `icon`/`text` in Task 1; Task 3's `refresh()` reads exactly `chip["icon"]` and `chip["text"]`. `ActivityRow.refresh(student, grade, progress_percent)` is declared in Task 3 and called with three arguments in Task 4. `energy_cost`/`mood_cost` are defined in Task 1 and called in Task 2. `category` values are the same five keys throughout.

**One risk worth flagging to the executor.** Task 3 Step 6 rewrites `Assets/Theme/kejartes_theme.tres`, which `test_theme_factory` and `test_student_card` also assert against. Task 3 Step 8's full-suite run is what catches a bad rebake — do not skip it.

**A deliberate non-extraction.** `_compute_total_loss` (`atur_jadwal.gd:557`) reads `energy_cost` back out of `day_schedules` to warn about overtired students. Task 2 changes where those stored numbers come from but not the fact that they are stored, so that warning keeps working. This is why Task 2 keeps the dict shape instead of dropping the now-derivable fields.
