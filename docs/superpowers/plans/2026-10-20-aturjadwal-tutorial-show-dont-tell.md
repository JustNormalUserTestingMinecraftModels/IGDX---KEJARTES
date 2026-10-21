# Atur Jadwal Tutorial: Show, Don't Tell — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Atur Jadwal tutorial readable by a player who skips text: 3 one-line cards, each pointing at exactly one control, the picker nudging toward the right tile, and the card body in the body face.

**Architecture:** The step data stays in `AturJadwal.gd::_populate_default_tutorial_steps()` (rows of `[title, text, target, prompt]`). Phase 2's card names the skill furthest under target, computed by a static helper so it is testable without instancing the scene. The picker reuses the existing `TutorialIdle` (escalating shake after 2.5 s idle) on the focus tile, so no visual is built at runtime. Font change is a new `ThemeFactory` variation, `TutorialBodyLabel`.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` suites run through the Godot AI MCP `test_run`.

**Spec:** No written design; this plan's source is the approved brainstorm (2026-10-20) and its mockup `.superpowers/brainstorm/aturjadwal-tutorial.html`. Owner's complaints, verbatim in substance: hints in Atur Jadwal mislead; players don't read, so the screen must show what to do with little text; the highlight bleeds down over the student splash; all-bold text breaks layout hierarchy.

## Global Constraints

- All player-facing text Indonesian, natural, KBBI-standard; one line per card.
- Never add a `theme_override_*`; type variations only (`ThemeFactory.gd`, then rebake via the `theme_rebake` suite).
- No visual built at runtime: reuse `TutorialIdle` and existing nodes; no new `Control.new()` in `AturJadwal.gd` (`tests/test_viewport_editability.gd` BASELINE must not rise).
- Every `@export` and file keeps its `##` doc line (`tests/test_script_documentation.gd`).
- No test is a coroutine; suites are `@tool`.
- Scene edits go through the editor (`scene_open` → `node_set_property` → `scene_save`) before any script patch; after a `scene_save`, check `git diff HEAD -- '*.gd'` for files you were not editing.
- `Balance.gd` is not touched. `Resources/Minigames/HowTo/Variabel.tres` is someone else's uncommitted change: never stage it.

## Review Focus

1. A student with all three skills already at or over target → the card must still name one skill (the smallest gap, i.e. the largest `target - current`, which may be negative) and never an empty `{stat}`.
2. A student dict missing `target_*` keys → default target 65.0, no crash.
3. Player closes the picker without choosing, then reopens Senin → the subtitle hint still shows, and the idle nudge restarts on the focus tile.
4. Player picks a different tile than the one suggested → assignment still works, phase 3 still fires, hint and nudge clear.
5. Any future step row with a comma-separated target (multi-target) → reintroduces the splash bleed; a test forbids it.

Each is pinned in Task 1 or Task 2 below.

---

## Already in the working tree (uncommitted, from the brainstorm session)

- `AturJadwal.gd`: phases cut to 1 card each; `tutorial_phase2_alt_step` and `_has_akademis_below_target` removed; `_weakest_skill_category(student) -> String` (instance method); `_tutorial_focus_category` var; picker subtitle `"Pilih %s, lalu ketuk Pilih"`; focus cleared when Senin is scheduled.
- `ThemeFactory.gd`: `TutorialBodyLabel` (body face via default_font, `font_body_size`, `text_primary`).
- `Scenes/UI/TutorialPanel.tscn`: `BodyLabel.theme_type_variation = TutorialBodyLabel`.
- `tests/test_theme_factory.gd`: `TutorialBodyLabel` added to `test_body_labels_do_not_take_the_display_font`.
- Suites passing: theme_rebake, theme_factory, atur_jadwal, lobby, script_documentation.

### Task 1: Pin the shipped tutorial rewrite with tests

**Files:**
- Modify: `Scripts/AturJadwal/AturJadwal.gd` (`_weakest_skill_category` → `static func weakest_skill_category`)
- Test: `tests/test_atur_jadwal.gd` (append)

**Interfaces:**
- Produces: `static func weakest_skill_category(student: Dictionary) -> String` returning `"Akademis" | "SeniBudaya" | "Olahraga"`; `var _tutorial_focus_category: String`.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_atur_jadwal.gd`)

```gdscript
const _ATUR := preload("res://Scripts/AturJadwal/AturJadwal.gd")

func test_weakest_skill_is_the_largest_gap_to_target() -> void:
	var s := {"akademis": 60, "target_akademis": 65,
			"seni_budaya": 30, "target_seni_budaya": 65,
			"olahraga": 50, "target_olahraga": 65}
	assert_eq(_ATUR.weakest_skill_category(s), "SeniBudaya")

func test_weakest_skill_when_every_target_is_met() -> void:
	var s := {"akademis": 90, "target_akademis": 65,
			"seni_budaya": 70, "target_seni_budaya": 65,
			"olahraga": 80, "target_olahraga": 65}
	assert_eq(_ATUR.weakest_skill_category(s), "SeniBudaya", "smallest surplus wins")

func test_weakest_skill_defaults_missing_targets_to_65() -> void:
	assert_eq(_ATUR.weakest_skill_category({"akademis": 64, "seni_budaya": 70, "olahraga": 70}), "Akademis")

func test_every_tutorial_step_targets_at_most_one_control() -> void:
	# A comma-separated target cuts one hole round all of them: the splash bleed.
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd")
	var block := src.substr(src.find("func _populate_default_tutorial_steps"))
	block = block.substr(0, block.find("\nfunc ", 10))
	var rx := RegEx.create_from_string('\\[\\s*"[^"]*",\\s*"[^"]*",\\s*"([^"]*)"')
	for m in rx.search_all(block):
		assert_false(m.get_string(1).contains(","), "multi-target step: " + m.get_string(1))

func test_each_tutorial_phase_is_one_card() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd")
	for phase in ["p1_data", "p2_data", "p3_data"]:
		var at := src.find("var %s = [" % phase)
		var body := src.substr(at, src.find("]\n", src.find("\n", at)) - at)
		assert_eq(body.count("\n\t\t\t["), 1, phase + " has exactly one row")

func test_senin_step_names_the_stat_and_the_picker_repeats_it() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd")
	assert_true(src.contains('"{stat} Nama Murid paling jauh dari target. Isi Senin dengan {stat}."'))
	assert_true(src.contains('"Pilih %s, lalu ketuk Pilih"'))
	assert_false(src.contains("Ungu Muda"), "empty days are not purple")

func test_tutorial_card_body_uses_the_body_face() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/UI/TutorialPanel.tscn")
	var at := src.find('[node name="BodyLabel"')
	assert_true(src.substr(at, 300).contains('theme_type_variation = &"TutorialBodyLabel"'))
```

- [ ] **Step 2: Run, expect the three `weakest_skill_category` tests to FAIL** (method not static/renamed); the source scans pass already.

Run: `test_run(suite="atur_jadwal")` with MainMenu open.

- [ ] **Step 3: Make it `static func weakest_skill_category(student: Dictionary) -> String`** via `script_patch`, and update its one caller in `_setup_phase2_tutorial`. Keep the `##` doc lines.

- [ ] **Step 4: Run `atur_jadwal`, `theme_factory`, `script_documentation`** → all PASS.

- [ ] **Step 5: Commit** (stage only these files; not `Variabel.tres`)

```bash
git add Scripts/AturJadwal/AturJadwal.gd Scripts/Design/ThemeFactory.gd Scenes/UI/TutorialPanel.tscn tests/test_atur_jadwal.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "fix(atur-jadwal): one-line, one-target tutorial steps naming the weakest skill"
```

### Task 2: Nudge the suggested tile in the picker

**Files:**
- Modify: `Scripts/AturJadwal/AturJadwal.gd` (`_show_penjadwalan_popup`, `_hide_penjadwalan_popup`, `_on_activity_selected`, new `var _picker_idle: TutorialIdle`)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `_tutorial_focus_category` (Task 1); `TutorialIdle.attach(owner) -> TutorialIdle`, `start(target, cues)`, `stop()`; `_popup_tiles() -> Array[ActivityTile]`, `ActivityTile.category`.
- Produces: `func _focus_tile() -> ActivityTile` (the tile whose `category == _tutorial_focus_category`, else null).

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_picker_nudges_the_focus_tile_while_the_senin_step_runs() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd")
	var show := src.substr(src.find("func _show_penjadwalan_popup"))
	show = show.substr(0, show.find("\nfunc ", 10))
	assert_true(show.contains("_picker_idle.start(_focus_tile()"), "the idle nudge targets the focus tile")
	var hide := src.substr(src.find("func _hide_penjadwalan_popup"))
	hide = hide.substr(0, hide.find("\nfunc ", 10))
	assert_true(hide.contains("_picker_idle.stop()"), "closing the picker stops the nudge")

func test_focus_tile_is_null_outside_the_tutorial() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd")
	var fn := src.substr(src.find("func _focus_tile"))
	fn = fn.substr(0, fn.find("\nfunc ", 10))
	assert_true(fn.contains('_tutorial_focus_category == ""'), "no focus, no nudge")
```

- [ ] **Step 2: Run `atur_jadwal`** → the two new tests FAIL.

- [ ] **Step 3: Implement.** Attach `_picker_idle` once in `_ready` (after the tutorial is built, only when `tutorial_active`); in `_show_penjadwalan_popup`, `if _focus_tile(): _picker_idle.start(_focus_tile(), [])`; in `_hide_penjadwalan_popup` and when `_tutorial_focus_category` is cleared, `_picker_idle.stop()` (null-guarded). Do not pre-select the tile: the player still taps it.

- [ ] **Step 4: Run `atur_jadwal`, `viewport_editability`, `script_documentation`, `clean_code`** → all PASS, BASELINE unchanged.

- [ ] **Step 5: Commit**

```bash
git add Scripts/AturJadwal/AturJadwal.gd tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): nudge the suggested tile in the picker during the tutorial"
```

### Task 3: Live verification and changelog

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (newest-first entry)

- [ ] **Step 1: Replay the tutorial.** `project_run` main → Settings → **Reset Progres** → play to Atur Jadwal (StudentCard approve → Lobby → Atur Jadwal).
- [ ] **Step 2: Full-size `editor_screenshot(source="game", max_resolution=0)` at each of the 3 cards and at the picker after 3 s idle.** Pass when: one control lit per card, no light over the splash, body text visibly lighter than title, card names the student's weakest skill, the focus tile shakes.
- [ ] **Step 3: Screenshot the StudentCard tutorial card** (shares `TutorialPanel.tscn`) and confirm the body face reads well there too; if not, report to the owner rather than forking the panel.
- [ ] **Step 4: Stop the game; `git status`; `git checkout -- default_bus_layout.tres` if AudioDirector rewrote it.**
- [ ] **Step 5: Add the CHANGELOG entry, commit, then finish with the `ship-pr` skill** (full suite + review + PR).

```bash
git add docs/superpowers/CHANGELOG.md
git commit -m "docs(changelog): Atur Jadwal tutorial show-don't-tell pass"
```
