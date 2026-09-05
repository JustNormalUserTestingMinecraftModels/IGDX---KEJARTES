# TesNotice Grade-Letter Scenarios Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Do NOT use subagent-driven-development for this plan** — the Godot AI MCP backend is single-client (see Global Constraints); a subagent that tries to run `test_run` displaces the orchestrator's session. Subagents may still be used to draft code, but the orchestrator must be the one holding the editor connection and running every `test_run`.

**Goal:** Add four new debug-overlay scenarios — one each for RunResult's A, B, C and D letter grades — that teleport into `TesNotice.tscn` with a roster and stat tally tuned to resolve to that exact letter.

**Architecture:** Pure extension of the existing `EndGameRehearsal.gd` rehearsal jig (already used by the Lulus/Gagal/Campur debug buttons): four new named presets (data only — new dictionary entries, no new functions) plus four new buttons in `DebugManager.gd` wired to the handler that pattern already uses.

**Tech Stack:** GDScript (Godot 4.6), `McpTestSuite`-based tests run in-editor via the `godot-ai` MCP `test_run` tool.

## Global Constraints

- Suites `extend McpTestSuite`, are `@tool`, and contain no coroutines (no `await` in any test function) — the runner does `suite.call(name)` without awaiting.
- Any script the editor already has open must be rescanned (`mcp__godot-ai__project_manage` / filesystem rescan, or a no-op `script_patch`) before the next `test_run`, or the runner serves stale bytecode. Prefer editing through `mcp__godot-ai__script_patch` so this is automatic.
- The `godot-ai` MCP backend is single-client: only the orchestrator (this session) may hold it. Do not dispatch a subagent that itself calls any `mcp__godot-ai__*` tool.
- `Balance.gd` values are collaborator-owned — this plan does not touch it (it only reads `Balance.STAR_WIN_THRESHOLD` indirectly through `GameState.check_semester_passed()`, already true of the existing presets).
- Indonesian for game-facing UI text (button labels); English is fine for code comments, matching the surrounding file.

---

### Task 1: Four new grade-letter presets in `EndGameRehearsal.gd`

**Files:**
- Modify: `Scripts/Debug/EndGameRehearsal.gd:18-20` (preset constants), `:43-47` (`CLEARED_COUNTS`), `:191-204` (`REHEARSAL_STATS`)
- Test: `tests/test_end_game_rehearsal.gd`

**Interfaces:**
- Consumes: `EndGameRehearsal.build_roster(preset, grade, source_students)`, `EndGameRehearsal.arm(preset, source_students)`, `EndGameRehearsal.snapshot()`/`restore()` — all unchanged, already defined in this file.
- Produces: four new string constants `EndGameRehearsal.PRESET_GRADE_A`, `PRESET_GRADE_B`, `PRESET_GRADE_C`, `PRESET_GRADE_D`, each a valid key into `CLEARED_COUNTS` and `REHEARSAL_STATS`. Task 2 (`DebugManager.gd`) references these four constants by name.

- [ ] **Step 1: Write the four failing tests**

Open `tests/test_end_game_rehearsal.gd` and add this helper plus four tests, right after `test_arm_seeds_a_run_stats_tally_matched_to_the_preset()` (before the `snapshot / restore` section divider):

```gdscript
## Four-student stand-in source. The grade-scenario presets' CLEARED_COUNTS
## arrays assume a four-slot roster (mirroring DebugManager.DEFAULT_STUDENTS'
## length, and RunGrade's event/target fractions which are computed over the
## whole roster) -- same technique
## test_campur_gives_each_slot_a_different_cleared_count() uses.
func _fake_source_four() -> Array:
	var source := _fake_source()
	source.append(source[0].duplicate())
	source.append(source[1].duplicate())
	return source


## Computes the letter RunResult itself would show for the currently-armed
## GameState -- the exact same three calls _compute_grade() makes
## (Scripts/EndGame/RunResult.gd:109-114).
func _resulting_letter() -> String:
	var counted: Array = GameState.count_targets_cleared()
	var passed := not GameState.run_failed and GameState.check_semester_passed()
	var run_score := RunGrade.score(GameState.run_stats,
		int(counted[0]), int(counted[1]), GameState.approved_students.size())
	return RunGrade.letter(run_score, passed)


func test_arm_makes_the_grade_a_preset_resolve_to_an_a() -> void:
	var snap := EndGameRehearsal.snapshot()
	GameState.current_grade = 7

	EndGameRehearsal.arm(EndGameRehearsal.PRESET_GRADE_A, _fake_source_four())
	assert_eq(_resulting_letter(), "A",
		"the grade-A preset must resolve to exactly 'A', not 'A+' or 'A-'")

	EndGameRehearsal.restore(snap)


func test_arm_makes_the_grade_b_preset_resolve_to_a_b() -> void:
	var snap := EndGameRehearsal.snapshot()
	GameState.current_grade = 7

	EndGameRehearsal.arm(EndGameRehearsal.PRESET_GRADE_B, _fake_source_four())
	assert_eq(_resulting_letter(), "B",
		"the grade-B preset must resolve to exactly 'B', not 'B+' or 'B-'")

	EndGameRehearsal.restore(snap)


func test_arm_makes_the_grade_c_preset_resolve_to_a_c() -> void:
	var snap := EndGameRehearsal.snapshot()
	GameState.current_grade = 7

	EndGameRehearsal.arm(EndGameRehearsal.PRESET_GRADE_C, _fake_source_four())
	assert_eq(_resulting_letter(), "C",
		"the grade-C preset must resolve to exactly 'C', not 'C+' or 'C-'")

	EndGameRehearsal.restore(snap)


func test_arm_makes_the_grade_d_preset_resolve_to_a_d() -> void:
	var snap := EndGameRehearsal.snapshot()
	GameState.current_grade = 7

	EndGameRehearsal.arm(EndGameRehearsal.PRESET_GRADE_D, _fake_source_four())
	assert_eq(_resulting_letter(), "D",
		"the grade-D preset must fail to pass, which forces the letter to 'D' " +
		"regardless of score")

	EndGameRehearsal.restore(snap)
```

- [ ] **Step 2: Run the suite to verify the four new tests fail**

Use `mcp__godot-ai__test_run` with `suite_name: "end_game_rehearsal"`.
Expected: the suite reports an error (undefined constants `PRESET_GRADE_A` etc. — likely a parse/compile failure for the whole suite, since GDScript resolves `EndGameRehearsal.PRESET_GRADE_A` at parse time). Confirm the failure is about the missing constants, not something else.

- [ ] **Step 3: Add the four presets to `EndGameRehearsal.gd`**

Using `mcp__godot-ai__script_patch` (or `Edit`, followed by a rescan/no-op patch per Global Constraints), make these three edits to `Scripts/Debug/EndGameRehearsal.gd`:

Immediately after the existing preset constants (after `const PRESET_CAMPUR := "campur"`, currently line 20):

```gdscript

## Four more presets, added for testing RunResult's letter grade directly
## rather than the win/lose narrative above -- see RunGrade.gd's weights
## (targets 55%, minigames 20%, money 15%, events 10%). Each is tuned so
## RunGrade.score()/letter() lands solidly inside one band, assuming the
## debug roster's fixed 4 students / 12 academic targets. Full arithmetic:
## docs/superpowers/specs/2026-09-05-tesnotice-grade-scenarios-design.md
const PRESET_GRADE_A := "grade_a"
const PRESET_GRADE_B := "grade_b"
const PRESET_GRADE_C := "grade_c"
const PRESET_GRADE_D := "grade_d"
```

In `CLEARED_COUNTS` (currently lines 43-47), add four entries so the dict reads:

```gdscript
const CLEARED_COUNTS := {
	PRESET_LULUS: [3, 3, 3, 3],
	PRESET_GAGAL: [0, 0, 0, 0],
	PRESET_CAMPUR: [3, 2, 1, 0],
	PRESET_GRADE_A: [3, 3, 3, 3],
	PRESET_GRADE_B: [3, 3, 2, 1],
	PRESET_GRADE_C: [3, 2, 2, 1],
	PRESET_GRADE_D: [2, 1, 1, 0],
}
```

In `REHEARSAL_STATS` (currently lines 191-204), add four entries so the dict reads:

```gdscript
const REHEARSAL_STATS := {
	PRESET_LULUS: {
		"won": 8, "lost": 1, "points": 64.0, "items": 6,
		"money": 24000, "events": 4,
	},
	PRESET_GAGAL: {
		"won": 1, "lost": 7, "points": -22.0, "items": 1,
		"money": 4000, "events": 1,
	},
	PRESET_CAMPUR: {
		"won": 5, "lost": 4, "points": 18.0, "items": 3,
		"money": 12000, "events": 2,
	},
	# Grade-letter scenarios. Cleared-ratio comes from CLEARED_COUNTS above;
	# money/minigames/events here are tuned to land the total score a few
	# points inside the target band (see the design spec for the arithmetic).
	PRESET_GRADE_A: {
		"won": 6, "lost": 5, "points": 20.0, "items": 4,
		"money": 20000, "events": 4,
	},
	PRESET_GRADE_B: {
		"won": 6, "lost": 4, "points": 24.0, "items": 3,
		"money": 12000, "events": 2,
	},
	PRESET_GRADE_C: {
		"won": 0, "lost": 0, "points": 0.0, "items": 1,
		"money": 10000, "events": 0,
	},
	PRESET_GRADE_D: {
		"won": 1, "lost": 6, "points": -18.0, "items": 1,
		"money": 2000, "events": 1,
	},
}
```

- [ ] **Step 4: Rescan and run the suite to verify all tests pass**

Rescan/reload `Scripts/Debug/EndGameRehearsal.gd` per Global Constraints, then run `mcp__godot-ai__test_run` with `suite_name: "end_game_rehearsal"`.
Expected: PASS — every test in the suite green, including the four new ones and every pre-existing one (nothing about the file's existing behavior changed, only additions).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/EndGameRehearsal.gd tests/test_end_game_rehearsal.gd
git commit -m "feat(debug): add A/B/C/D grade-letter rehearsal presets"
```

---

### Task 2: Wire the four scenario buttons into the debug overlay

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd:1261-1287` (`_build_scenes_panel`, the Gladi Resik section)
- Test: `tests/test_debug_manager.gd`

**Interfaces:**
- Consumes: `EndGameRehearsal.PRESET_GRADE_A/B/C/D` (from Task 1), `DebugManager._start_end_game_rehearsal(preset: String) -> void` (already defined, unchanged).
- Produces: nothing new consumed elsewhere — this is the leaf UI wiring.

- [ ] **Step 1: Write the failing wiring test**

Add this test to `tests/test_debug_manager.gd`, directly after `test_rehearsal_buttons_exist_for_all_three_presets()`:

```gdscript
func test_grade_scenario_buttons_exist_for_all_four_presets() -> void:
	var body := _function_body(_source(), "_build_scenes_panel")
	for preset in ["PRESET_GRADE_A", "PRESET_GRADE_B", "PRESET_GRADE_C", "PRESET_GRADE_D"]:
		assert_true(body.contains("EndGameRehearsal." + preset),
			"the Scenes tab must offer the %s grade scenario" % preset)
	assert_true(body.contains("_start_end_game_rehearsal"),
		"the grade scenarios must reuse the existing rehearsal handler, " +
		"not a parallel code path")
```

- [ ] **Step 2: Run the suite to verify the new test fails**

Use `mcp__godot-ai__test_run` with `suite_name: "debug_manager"`.
Expected: FAIL on `test_grade_scenario_buttons_exist_for_all_four_presets` (the four `PRESET_GRADE_*` strings are not yet present in `_build_scenes_panel`'s source). All other tests in the suite still pass.

- [ ] **Step 3: Add the four buttons to `_build_scenes_panel`**

Using `mcp__godot-ai__script_patch` (or `Edit` + rescan), insert this block into `Scripts/Debug/DebugManager.gd` between the end of the `for r in rehearsals:` loop and the `var btn_restore = Button.new()` line (currently lines 1280-1282), so the shared restore button ends up below both button groups:

```gdscript

	var sep_grade = HSeparator.new()
	vbox.add_child(sep_grade)

	var lbl_grade = Label.new()
	lbl_grade.text = "Skenario Nilai Akhir (A/B/C/D, mulai dari Notice Tes Besar):"
	lbl_grade.add_theme_font_size_override("font_size", 26)
	vbox.add_child(lbl_grade)

	var grade_scenarios = [
		{"name": "Nilai A", "preset": EndGameRehearsal.PRESET_GRADE_A},
		{"name": "Nilai B", "preset": EndGameRehearsal.PRESET_GRADE_B},
		{"name": "Nilai C", "preset": EndGameRehearsal.PRESET_GRADE_C},
		{"name": "Nilai D", "preset": EndGameRehearsal.PRESET_GRADE_D},
	]
	for g in grade_scenarios:
		var btn_g = Button.new()
		btn_g.text = " 🎯 Skenario: " + g["name"]
		btn_g.custom_minimum_size = Vector2(0, 95)
		btn_g.add_theme_font_size_override("font_size", 21)
		btn_g.pressed.connect(func(): _start_end_game_rehearsal(g["preset"]))
		vbox.add_child(btn_g)
```

- [ ] **Step 4: Rescan and run the suite to verify it passes**

Rescan/reload `Scripts/Debug/DebugManager.gd` per Global Constraints, then run `mcp__godot-ai__test_run` with `suite_name: "debug_manager"`.
Expected: PASS — every test green, including the new one.

- [ ] **Step 5: Run the full project suite**

Run `mcp__godot-ai__test_run` with no suite filter (or however the tool expresses "all suites") to confirm nothing elsewhere regressed. Expected: all 45 suites green (the two touched suites plus 43 unrelated ones).

- [ ] **Step 6: Manual smoke-check (visual, not covered by source-scan tests)**

With `Scenes/MainMenu/main_menu.tscn` open (or any scene), open the debug overlay (5-tap top-right corner, or F1), go to the Scenes tab, confirm the new "Skenario Nilai Akhir (A/B/C/D)" section renders below "Gladi Resik Akhir Kelas" with four buttons. Press "Skenario: Nilai A" via `mcp__godot-ai__editor_screenshot` + the coordinate-rescaling procedure in `CLAUDE.md`'s "Working efficiently here" section, confirm it teleports to `TesNotice.tscn`. This one press is enough to prove the wiring end-to-end; the letter itself is already proven by Task 1's behavioral tests, and playing all four through to RunResult is not necessary.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Debug/DebugManager.gd tests/test_debug_manager.gd
git commit -m "feat(debug): add Scenes-tab buttons for the A/B/C/D grade scenarios"
```
