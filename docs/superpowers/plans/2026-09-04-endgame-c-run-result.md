# End-Game Plan C — RunResult Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild RunResult to the mockup_resultscreen: the win/lose backdrop dimmed under a scrim, an A/B/C/D badge stamped in, a horizontally scrollable row of per-student report papers, a **Detail** popup with five run metrics, and a **Konfirmasi** button that always opens the Kelas 7–9 difficulty selection.

**Architecture:** `RunResult.gd` keeps its scoring (`RunGrade.score`/`letter`) and gains `RunGrade.badge()` to collapse eleven letters into four badge textures. The six-row report becomes a five-metric `DetailsPopup` authored in the scene. Report papers are a `ReportPaper.tscn` template instanced per student (the same reviewed exception the old rows used). Automatic grade advance is removed: confirm resets the run's per-grade state, sets `GameState.open_level_select`, and routes to `cut_scene.tscn`, whose `_ready` opens the level-select modal when that flag is set. `RunStats` gains a `schedules_assigned` counter, incremented at AturJadwal's one genuine player assignment.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` via `godot-ai` MCP `test_run`; scenes built by the controller in the editor.

**Spec:** The user's 2026-09-04 end-game brief, bullet 5, and its Q&A. **Depends on Plans A and B** (`2026-09-04-endgame-a-statcheck.md`, `2026-09-04-endgame-b-win-lose-screens.md`): `GameState.run_failed`, `EndScreen`'s CG backdrops, `check_semester_passed()` on the star rule.

## Requirements (from the brief)

1. The win/lose background is blurred, then a badge — placeholder A, B, C, D for the run's performance — is stamped (mockup_resultscreen).
2. The report papers of each student (placeholder; design to come) appear and scroll left and right.
3. A **details** button shows: total events attended, students' overall mood, total scheduling, total money gained, and failures.
4. A **confirm** button takes the player to the difficulty selection menu (Kelas 7–9).

## Decisions taken as defaults (override any by name)

- **D1 "Blurred":** this codebase retired its blur shaders in favour of the `Scrim` theme panel (`atur_jadwal.gd:120,852`), and every end-game screen already dims a backdrop that way. RunResult shows the **same CG the preceding win/lose screen used** (chosen by `GameState.run_failed`) under a `Scrim` — dimmed, not Gaussian-blurred. A true blur would mean re-introducing the retired shader ColorRect; out of scope.
- **D2 Badge mapping:** collapse `RunGrade`'s bands — A = A+/A/A- (score ≥ 80), B = B+/B/B- (≥ 56), C = C+/C/C- (≥ 40), D = failed run or below 40. Scoring untouched.
- **D3 Metrics:** events = `run_stats.event_student_count()`; overall mood = mean of `approved_students[*]["kepribadian1"]` (0 when empty); total scheduling = new `run_stats.schedules_assigned`, counted at `AturJadwal._on_activity_selected()` (holiday auto-locks are not player scheduling and are not counted); money = `run_stats.wirausaha_money`; failures = `run_stats.minigames_lost`. The old report's "Minigame selesai", "Total poin minigame" and "Barang dipakai" rows are not in the brief and are dropped.
- **D4 Report paper:** name + portrait on a `Card` panel, one per student, in a horizontal `ScrollContainer`. Real design later.
- **D5 Confirm, win or lose:** always opens level select. Roster prep on confirm is what a grade transition does today (mood/energy to 80, `base_akademis*` erased so targets recompute); the grade-9 win still sets `is_game_beaten` and saves settings. Nothing advances `current_grade` — the player's pick in the modal calls `GameState.set_grade()`.
- **D6 Heading:** "Laporan Murid:" above the papers for both verdicts (the mockup's "Murid Lulus:" would be false on a loss).

## Global Constraints

- Test suites `@tool` + `McpTestSuite`; **no coroutine tests**; `test_run(suite=…)`; `filesystem_manage(op="scan")` after external `.gd` edits; no-op `script_patch` if stale.
- **Scenes built by the controller in the editor**; `anchors_preset` inert; numbers unquoted; `node_create` appends last.
- **No `theme_override_*`** (ThemeFactory variations only); **no runtime-built visuals** (templates instanced per call are the reviewed exception, registered in `tests/test_viewport_editability.gd` `ALLOWED`); **no emoji iconography**.
- Indonesian UI text, English identifiers; tunables in `const`/`@export` with `##` docs; `##` file headers.
- No save system beyond the existing `GameSettings` (which persists `is_game_beaten`).
- Conventional Commits with a scope; name files explicitly, never `git add -A`.
- Baseline before this plan: Plan B's full suite, **808 tests, 56 suites**.

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/EndGame/RunGrade.gd` (modify) | `badge(letter) -> String`. |
| `Assets/Images/UI/Placeholders/badge_a.svg` … `badge_d.svg` (create) | Placeholder badges. |
| `Scripts/EndGame/RunStats.gd` (modify) | `schedules_assigned`, `record_schedule()`, reset. |
| `Scripts/AturJadwal/atur_jadwal.gd:979-993` (modify) | Count the assignment. |
| `Scripts/GameState.gd` (modify) | `open_level_select: bool`. |
| `Scripts/CutScene/cut_scene.gd:79-86` (modify) | Honour the flag. |
| `Scripts/EndGame/ReportPaper.gd` + `Scenes/EndGame/ReportPaper.tscn` (create) | Per-student paper template. |
| `Scripts/EndGame/RunResult.gd` (rewrite) + `Scenes/EndGame/RunResult.tscn` (controller rebuild) | The screen. |
| Tests | `tests/test_run_stats.gd`, `tests/test_atur_jadwal.gd`, `tests/test_cutscene.gd`, `tests/test_end_game_rehearsal.gd` (allowlist), `tests/test_run_result.gd` (rewrite), `tests/test_viewport_editability.gd` (comment). |
| `CLAUDE.md` (modify) | Flow + progression note. |

---

### Task 1: `RunGrade.badge()` and the four placeholder badges

**Files:**
- Modify: `Scripts/EndGame/RunGrade.gd`
- Create: `Assets/Images/UI/Placeholders/badge_a.svg`, `badge_b.svg`, `badge_c.svg`, `badge_d.svg`
- Test: `tests/test_run_stats.gd` (append — RunGrade's tests live there)

**Interfaces:**
- Produces: `RunGrade.badge(letter_text: String) -> String` returning `"A"|"B"|"C"|"D"`; `RunGrade.BADGE_TEXTURES: Dictionary` mapping those four to `res://` paths.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_stats.gd`:

```gdscript
# ───────────────────────────────────────────────────── badge collapse (Plan C)

func test_badge_collapses_eleven_letters_to_four() -> void:
	for l in ["A+", "A", "A-"]:
		assert_eq(RunGrade.badge(l), "A", l + " is an A badge")
	for l in ["B+", "B", "B-"]:
		assert_eq(RunGrade.badge(l), "B", l + " is a B badge")
	for l in ["C+", "C", "C-"]:
		assert_eq(RunGrade.badge(l), "C", l + " is a C badge")
	assert_eq(RunGrade.badge("D"), "D", "D stays D")
	assert_eq(RunGrade.badge(""), "D", "an unknown letter falls to D, never to a blank badge")


func test_every_badge_has_a_texture_that_loads() -> void:
	for b in ["A", "B", "C", "D"]:
		assert_true(RunGrade.BADGE_TEXTURES.has(b), b + " is mapped")
		var path: String = RunGrade.BADGE_TEXTURES[b]
		assert_true(ResourceLoader.exists(path), path + " exists")
		assert_true(load(path) is Texture2D, path + " is a texture")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_stats")`
Expected: FAIL — suite fails to load (`Static function "badge()" not found in base "RunGrade"`).

- [ ] **Step 3: Write the badges and the mapping**

Four SVGs, `badge_a.svg` … `badge_d.svg` — same file, different letter and colour (A `#2fb85a`, B `#2e5bff`, C `#f5a623`, D `#c42b3c`):

```svg
<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg"><circle cx="100" cy="100" r="86" fill="#ffffff" stroke="#2fb85a" stroke-width="12"/><text x="100" y="138" text-anchor="middle" font-family="Arial, sans-serif" font-size="112" font-weight="bold" fill="#2fb85a">A</text></svg>
```

Append to `Scripts/EndGame/RunGrade.gd`:

```gdscript

## The result screen shows four badges, not eleven letters. The +/- bands
## still drive the caption text; this only picks the art.
const BADGE_TEXTURES := {
	"A": "res://Assets/Images/UI/Placeholders/badge_a.svg",
	"B": "res://Assets/Images/UI/Placeholders/badge_b.svg",
	"C": "res://Assets/Images/UI/Placeholders/badge_c.svg",
	"D": "res://Assets/Images/UI/Placeholders/badge_d.svg",
}


## Collapse a letter() result to its badge: the first character for the
## A/B/C bands, D for a failed run -- and D for anything unrecognised, so
## a typo can never leave the screen without a badge.
static func badge(letter_text: String) -> String:
	if letter_text.is_empty():
		return LETTER_FAILED
	var first := letter_text.substr(0, 1)
	if first in ["A", "B", "C"]:
		return first
	return LETTER_FAILED
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_stats")` — PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/RunGrade.gd Assets/Images/UI/Placeholders/badge_a.svg Assets/Images/UI/Placeholders/badge_b.svg Assets/Images/UI/Placeholders/badge_c.svg Assets/Images/UI/Placeholders/badge_d.svg Assets/Images/UI/Placeholders/badge_a.svg.import Assets/Images/UI/Placeholders/badge_b.svg.import Assets/Images/UI/Placeholders/badge_c.svg.import Assets/Images/UI/Placeholders/badge_d.svg.import tests/test_run_stats.gd
git commit -m "feat(endgame): collapse the run grade to an A/B/C/D badge

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Count scheduling in `RunStats`

**Files:**
- Modify: `Scripts/EndGame/RunStats.gd`
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:979-993` (`_on_activity_selected`)
- Test: `tests/test_run_stats.gd` (append), `tests/test_atur_jadwal.gd` (append)

**Interfaces:**
- Produces: `RunStats.schedules_assigned: int`, `RunStats.record_schedule() -> void`; `reset()` zeroes it.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_stats.gd`:

```gdscript
func test_record_schedule_counts_and_reset_clears_it() -> void:
	var s := RunStats.new()
	assert_eq(s.schedules_assigned, 0, "starts at 0")
	s.record_schedule()
	s.record_schedule()
	assert_eq(s.schedules_assigned, 2, "two assignments counted")
	s.reset()
	assert_eq(s.schedules_assigned, 0, "reset clears it")
```

Append to `tests/test_atur_jadwal.gd` (it scans `atur_jadwal.gd` as source — reuse its existing source-reading helper; if it has none, read with `FileAccess.get_file_as_string`):

```gdscript
## Plan C: the result screen's "total scheduling" counts genuine player
## assignments -- this handler -- and not the holiday auto-locks in
## _check_and_lock_holidays().
func test_a_player_assignment_is_recorded_on_run_stats() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	var start := src.find("func _on_activity_selected(")
	var end := src.find("\nfunc ", start + 1)
	var body := src.substr(start, end - start)
	assert_true(body.contains("GameState.run_stats.record_schedule()"),
		"_on_activity_selected records the assignment")
	var lock_start := src.find("func _check_and_lock_holidays(")
	var lock_end := src.find("\nfunc ", lock_start + 1)
	assert_false(src.substr(lock_start, lock_end - lock_start).contains("record_schedule"),
		"holiday auto-locks are not player scheduling and are not counted")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_stats")` and `test_run(suite="atur_jadwal")`
Expected: `run_stats` fails to load (`schedules_assigned` unknown); `atur_jadwal`'s new test fails on the first assertion.

- [ ] **Step 3: Write the implementation**

In `Scripts/EndGame/RunStats.gd`, after `event_student_ids` (line 29) add:

```gdscript
## Activity slots the player assigned this grade -- every confirmed pick in
## AturJadwal's activity popup. Holiday auto-locks are not counted.
@export var schedules_assigned: int = 0
```

After `record_wirausaha()` add:

```gdscript

func record_schedule() -> void:
	schedules_assigned += 1
```

In `reset()`, add `schedules_assigned = 0` after `wirausaha_money = 0`.

In `Scripts/AturJadwal/atur_jadwal.gd`, inside `_on_activity_selected()`, directly after the `GameState.day_schedules[student_id][GameState.selected_day] = {…}` assignment closes (line 992), add:

```gdscript
		GameState.run_stats.record_schedule()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_stats")`, `test_run(suite="atur_jadwal")`, `test_run(suite="end_game_rehearsal")` (its `REHEARSAL_STATS` seeding does not set the new field; it stays 0 — fine).
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/RunStats.gd Scripts/AturJadwal/atur_jadwal.gd tests/test_run_stats.gd tests/test_atur_jadwal.gd
git commit -m "feat(endgame): count player scheduling on RunStats

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `GameState.open_level_select` and the cutscene gate

**Files:**
- Modify: `Scripts/GameState.gd` (add the flag near `debug_level_select_enabled`)
- Modify: `Scripts/CutScene/cut_scene.gd:79-86` (`_ready` gate)
- Modify: `tests/test_end_game_rehearsal.gd` (`_DELIBERATELY_UNSNAPSHOTTED`)
- Test: `tests/test_cutscene.gd` (append)

**Interfaces:**
- Produces: `GameState.open_level_select: bool` — set by RunResult's confirm, consumed and cleared by `cut_scene._ready()`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_cutscene.gd`:

```gdscript
## Plan C: RunResult's Konfirmasi always sends the player to the Kelas
## 7-9 modal, win or lose, by setting GameState.open_level_select. The
## cutscene honours it once and clears it, so the next real boot is
## unaffected.
func test_ready_opens_level_select_when_run_result_asked_for_it() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_ready")
	assert_true(body.contains("GameState.open_level_select"),
		"_ready reads the flag")
	var read_at := body.find("if GameState.open_level_select")
	var clear_at := body.find("GameState.open_level_select = false")
	var modal_at := body.find("show_level_select_modal()")
	assert_true(read_at != -1 and clear_at != -1 and modal_at != -1,
		"read, clear, open -- all present")
	assert_true(read_at < clear_at and clear_at < modal_at,
		"the flag is cleared before the modal opens, so it can never re-fire")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="cutscene")` — the new test fails on "_ready reads the flag".

- [ ] **Step 3: Write the implementation**

In `Scripts/GameState.gd`, after `var debug_level_select_enabled: bool = true` add:

```gdscript
## One-shot: RunResult's Konfirmasi sets this so the cutscene opens the
## Kelas 7-9 modal on the next boot of cut_scene.tscn, win or lose.
## Cleared by cut_scene._ready() the moment it is honoured.
var open_level_select: bool = false
```

In `Scripts/CutScene/cut_scene.gd`, replace the `_ready` gate (the block Plan A left):

```gdscript
	# Show level selection BEFORE playing intro cutscene if unlocked or in debug mode
	if GameState.is_game_beaten or GameState.debug_level_select_enabled:
		show_level_select_modal()
	else:
		GameState.set_grade(7)
		show_current()
```

with:

```gdscript
	# Level select opens when RunResult asked for it (one-shot, cleared
	# here), when the game is beaten, or in debug mode; otherwise the
	# intro plays into a fresh Kelas 7.
	if GameState.open_level_select or GameState.is_game_beaten \
			or GameState.debug_level_select_enabled:
		GameState.open_level_select = false
		show_level_select_modal()
	else:
		GameState.set_grade(7)
		show_current()
```

In `tests/test_end_game_rehearsal.gd`'s `_DELIBERATELY_UNSNAPSHOTTED`, add:

```gdscript
	"open_level_select": "one-shot routing flag, consumed by cut_scene._ready(); never run state",
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="cutscene")`, `test_run(suite="end_game_rehearsal")` (the reflection ratchet sees the new field and finds it allowlisted).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/GameState.gd Scripts/CutScene/cut_scene.gd tests/test_cutscene.gd tests/test_end_game_rehearsal.gd
git commit -m "feat(cutscene): open level select on demand via GameState.open_level_select

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: `ReportPaper` template

**Files:**
- Create: `Scripts/EndGame/ReportPaper.gd`
- Controller: `Scenes/EndGame/ReportPaper.tscn`
- Test: `tests/test_run_result.gd` (append)

**Interfaces:**
- Produces: `ReportPaper` (`class_name`, `extends PanelContainer`), `func bind(student: Dictionary) -> void` taking an `approved_students` entry (`name`, `portrait` path).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_result.gd`:

```gdscript
# ──────────────────────────────────────────────────────── ReportPaper (Plan C)

const _PAPER_PATH := "res://Scenes/EndGame/ReportPaper.tscn"


func test_the_paper_template_loads_with_name_and_portrait() -> void:
	var paper = load(_PAPER_PATH).instantiate()
	track(paper)
	assert_true(paper is ReportPaper, "wears ReportPaper.gd")
	assert_true(paper.get_node_or_null("Column/Nama") is Label, "Nama")
	assert_true(paper.get_node_or_null("Column/Portrait") is TextureRect, "Portrait")


func test_bind_writes_the_name_and_loads_the_portrait() -> void:
	var paper = load(_PAPER_PATH).instantiate()
	Engine.get_main_loop().root.add_child(paper)
	track(paper)
	paper.bind({"name": "Citra", "portrait": "res://Assets/Images/UI/Placeholders/icon_akademis.svg"})
	assert_eq(paper.get_node("Column/Nama").text, "Citra", "name")
	assert_true(paper.get_node("Column/Portrait").texture != null, "portrait loaded")
	Engine.get_main_loop().root.remove_child(paper)


func test_bind_survives_a_missing_portrait() -> void:
	var paper = load(_PAPER_PATH).instantiate()
	Engine.get_main_loop().root.add_child(paper)
	track(paper)
	paper.bind({"name": "Tanpa Foto"})
	assert_eq(paper.get_node("Column/Nama").text, "Tanpa Foto", "name still lands")
	Engine.get_main_loop().root.remove_child(paper)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_result")` — suite fails to load (`ReportPaper` unknown).

- [ ] **Step 3: Write the script**

`Scripts/EndGame/ReportPaper.gd`:

```gdscript
@tool
class_name ReportPaper
extends PanelContainer

## One student's report paper on the result screen -- a placeholder until
## the real design arrives: name and portrait on a Card panel. Instanced
## per student by RunResult into its horizontal scroller (the same
## reviewed per-call-dynamic exception RunResult's old rows used).

@onready var nama: Label = $Column/Nama
@onready var portrait: TextureRect = $Column/Portrait


## Fill from an approved_students dictionary. A missing or unloadable
## portrait path leaves the template's stand-in texture in place.
func bind(student: Dictionary) -> void:
	nama.text = String(student.get("name", ""))
	var path := String(student.get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		portrait.texture = load(path)
```

- [ ] **Step 4: Controller — build `ReportPaper.tscn`**

```
scene_manage(op="create", params={"path": "res://Scenes/EndGame/ReportPaper.tscn", "root_type": "PanelContainer", "root_name": "ReportPaper"})
script_attach("/ReportPaper", "res://Scripts/EndGame/ReportPaper.gd")
/ReportPaper            PanelContainer  theme_type_variation "Card"; custom_minimum_size {380,560}
  Column                VBoxContainer   alignment 1
    Portrait            TextureRect     custom_minimum_size {300,300}; expand_mode 1; stretch_mode 5;
                                        texture "res://Assets/Images/UI/Placeholders/icon_akademis.svg"
    Nama                Label           theme_type_variation "TitleLabel"; horizontal_alignment 1; text "Nama"
scene_save()
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_result")` — the 3 new tests PASS (the pre-existing ones are still green; they are rewritten in Task 5).

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/ReportPaper.gd Scripts/EndGame/ReportPaper.gd.uid Scenes/EndGame/ReportPaper.tscn tests/test_run_result.gd
git commit -m "feat(endgame): add the ReportPaper template

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: The RunResult screen

**Files:**
- Rewrite: `Scripts/EndGame/RunResult.gd`
- Controller: `Scenes/EndGame/RunResult.tscn` (rebuild `MarginContainer/Column` and add `DetailsPopup`)
- Modify: `tests/test_run_result.gd` (rewrite the screen tests), `tests/test_viewport_editability.gd` (comment on the `RunResult.gd` entry)

**Interfaces:**
- Consumes: Tasks 1–4; `RunResultRow.set_row(label, value, suffix, icon)` and `play_count_up(seconds)`; `Juice`; `Transition.change_scene`; `GameSettings.save_settings()`.
- Produces: `RunResult` methods `_build_papers()`, `_compute_grade()`, `_slam_badge()`, `_open_details()`, `_close_details()`, `_apply_confirm() -> String`; `static func average_mood(roster: Array) -> float`; `const CUTSCENE_SCENE`, `const BACKDROP_WIN`, `const BACKDROP_LOSE`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_run_result.gd`, delete `test_the_screen_has_a_backdrop_grade_card_and_rows_box`, `test_the_rows_box_starts_empty_in_the_scene`, `test_it_reports_all_six_figures`, `test_it_applies_grade_progression_and_exits_to_the_menu`, and change `test_the_script_actually_compiles` to check `"_build_papers"`, `"_compute_grade"`, `"_apply_confirm"`. In `test_it_plays_the_report_bgm_and_the_grade_stings` remove the `coin` line (no money row on the main screen now). Then append:

```gdscript
# ───────────────────────────────────────────────────── the screen (Plan C)

func test_the_screen_has_the_mockup_chrome() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	track(screen)
	assert_true(screen.get_node_or_null("Backdrop") is TextureRect, "Backdrop")
	assert_true(screen.get_node_or_null("Scrim") is Panel, "Scrim -- the 'blur'")
	assert_true(screen.get_node_or_null("MarginContainer/Column/Badge") is TextureRect, "Badge")
	assert_true(screen.get_node_or_null("MarginContainer/Column/GradeCaption") is Label, "caption")
	assert_true(screen.get_node_or_null("MarginContainer/Column/Heading") is Label, "heading")
	assert_true(screen.get_node_or_null("MarginContainer/Column/Papers") is ScrollContainer,
		"Papers scroller")
	assert_true(screen.get_node_or_null("MarginContainer/Column/Papers/PaperRow") is HBoxContainer,
		"PaperRow, where papers are instanced")
	assert_true(screen.get_node_or_null("MarginContainer/Column/Buttons/BtnDetail") is Button, "Detail")
	assert_true(screen.get_node_or_null("MarginContainer/Column/Buttons/BtnKonfirmasi") is Button,
		"Konfirmasi")


func test_the_papers_scroll_horizontally_and_start_empty() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	track(screen)
	var papers: ScrollContainer = screen.get_node("MarginContainer/Column/Papers")
	assert_eq(papers.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "scrolls left/right")
	assert_eq(papers.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "never vertically")
	assert_eq(screen.get_node("MarginContainer/Column/Papers/PaperRow").get_child_count(), 0,
		"papers are instanced from ReportPaper.tscn at runtime")


func test_the_details_popup_is_authored_hidden_with_five_rows() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	track(screen)
	var popup = screen.get_node_or_null("DetailsPopup")
	assert_true(popup is Control and not popup.visible, "DetailsPopup exists and starts hidden")
	var rows = screen.get_node_or_null("DetailsPopup/CenterContainer/Card/VBox/Rows")
	assert_true(rows != null, "Rows")
	assert_eq(rows.get_child_count(), 5, "exactly the brief's five metrics, authored")
	for child in rows.get_children():
		assert_true(child is RunResultRow, "each row is a RunResultRow instance")
	assert_true(screen.get_node_or_null("DetailsPopup/CenterContainer/Card/VBox/BtnTutup") is Button,
		"a close button")


func test_average_mood_is_the_mean_of_kepribadian1() -> void:
	assert_true(is_equal_approx(RunResult.average_mood([
		{"kepribadian1": 40.0}, {"kepribadian1": 80.0}]), 60.0), "mean of two")
	assert_true(is_equal_approx(RunResult.average_mood([]), 0.0), "empty is 0, no divide by zero")
	assert_true(is_equal_approx(RunResult.average_mood([{"name": "no mood key"}]), 0.0),
		"a missing key reads as 0")


func test_the_five_metrics_are_the_ones_the_brief_named() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for label in ["Event diikuti", "Rata-rata mood murid", "Total penjadwalan",
			"Uang dari wirausaha", "Kegagalan"]:
		assert_true(src.contains(label), "details include '%s'" % label)
	assert_true(src.contains("event_student_count()"), "events from RunStats")
	assert_true(src.contains("average_mood(GameState.approved_students)"), "mood from the roster")
	assert_true(src.contains("schedules_assigned"), "scheduling from RunStats")
	assert_true(src.contains("wirausaha_money"), "money from RunStats")
	assert_true(src.contains("minigames_lost"), "failures = minigames lost")


func test_the_backdrop_follows_the_verdict_under_a_scrim() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("const BACKDROP_WIN := \"res://Assets/Images/CG/cg2.jpg\""),
		"the win screen's CG")
	assert_true(src.contains("const BACKDROP_LOSE := \"res://Assets/Images/CG/cg0.jpg\""),
		"the lose screen's CG")
	assert_true(src.contains("BACKDROP_LOSE if GameState.run_failed else BACKDROP_WIN"),
		"picked by verdict")


func test_the_badge_is_stamped_from_run_grade() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("RunGrade.badge("), "the letter collapses to a badge")
	assert_true(src.contains("RunGrade.BADGE_TEXTURES"), "the badge art comes from the map")
	assert_true(src.contains("badge.scale = Vector2(3.0, 3.0)"), "slams down from 3x")
	assert_true(src.contains("play_sfx(&\"stamp\")"), "the stamp cue")


func test_confirm_always_opens_level_select_and_never_advances_the_grade() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.open_level_select = true"),
		"confirm arms the level-select modal")
	assert_true(src.contains("const CUTSCENE_SCENE := \"res://Scenes/CutScene/cut_scene.tscn\""),
		"and routes to the cutscene, which hosts the modal")
	assert_false(src.contains("current_grade += 1"),
		"no automatic grade advance -- the player picks")
	assert_false(src.contains("res://Scenes/MainMenu/main_menu.tscn"),
		"a loss no longer bounces to the main menu")
	assert_true(src.contains("GameState.is_game_beaten = true"),
		"a grade-9 win still unlocks level select for good")
	assert_true(src.contains("GameSettings.save_settings()"), "and persists it")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_result")`
Expected: FAIL — `average_mood` is a missing static (load failure), or if the parser is lenient, the chrome/source tests fail on the old scene.

- [ ] **Step 3: Rewrite `RunResult.gd`**

The `class_name` is new and required: the suite calls `RunResult.average_mood()` statically. A static function on a non-`@tool` script is still callable from the editor — `@tool` governs instances, not statics — so the screen stays non-`@tool`.

```gdscript
class_name RunResult
extends Control

## The last screen of a run (Plan C, 2026-09-04): the win/lose backdrop
## dimmed under a scrim, the run's A/B/C/D badge stamped in, one report
## paper per student in a horizontal scroller, a Detail popup with the five
## run metrics, and Konfirmasi -- which always opens the Kelas 7-9 modal.
##
## Deliberately NOT @tool: _ready() reads GameState, starts BGM and runs a
## tween chain. Tests are structural checks on a bare instantiate() plus
## source scans.
##
## Progression: this screen no longer advances the grade. It resets the
## per-grade state and hands the choice to the level-select modal via
## GameState.open_level_select.

@export_group("Reveal Timing")
## Pause after the papers land before the badge slams.
@export var badge_delay: float = 0.5
## Stagger between papers appearing.
@export var paper_stagger: float = 0.12

const PAPER_SCENE := preload("res://Scenes/EndGame/ReportPaper.tscn")
const CUTSCENE_SCENE := "res://Scenes/CutScene/cut_scene.tscn"
## The same CGs WinScreen/LoseScreen show, so this reads as the same place.
const BACKDROP_WIN := "res://Assets/Images/CG/cg2.jpg"
const BACKDROP_LOSE := "res://Assets/Images/CG/cg0.jpg"

const ICON_EVENT := preload("res://Assets/Images/UI/Placeholders/icon_event.svg")
const ICON_MOOD := preload("res://Assets/Images/UI/Placeholders/icon_mood.svg")
const ICON_JADWAL := preload("res://Assets/Images/UI/Placeholders/icon_istirahat.svg")
const ICON_UANG := preload("res://Assets/Images/UI/Placeholders/icon_uang.svg")
const ICON_GAGAL := preload("res://Assets/Images/UI/Placeholders/icon_minigame_kalah.svg")

## One caption per letter band, so the grade says something.
const GRADE_CAPTIONS := {
	"A+": "Sempurna. Tidak ada yang tertinggal.",
	"A": "Luar biasa. Kelas ini beruntung punya kamu.",
	"A-": "Sangat baik. Hampir sempurna.",
	"B+": "Baik sekali. Masih ada ruang untuk rapi.",
	"B": "Baik. Targetnya tercapai.",
	"B-": "Cukup baik. Beberapa hal bisa lebih halus.",
	"C+": "Lulus, dengan perjuangan.",
	"C": "Lulus tipis. Lain kali lebih awal.",
	"C-": "Nyaris tidak lulus, tapi lulus.",
	"D": "Belum berhasil. Mereka masih menunggumu.",
}

@onready var backdrop: TextureRect = $Backdrop
@onready var badge: TextureRect = $MarginContainer/Column/Badge
@onready var grade_caption: Label = $MarginContainer/Column/GradeCaption
@onready var heading: Label = $MarginContainer/Column/Heading
@onready var paper_row: HBoxContainer = $MarginContainer/Column/Papers/PaperRow
@onready var btn_detail: Button = $MarginContainer/Column/Buttons/BtnDetail
@onready var btn_konfirmasi: Button = $MarginContainer/Column/Buttons/BtnKonfirmasi
@onready var details_popup: Control = $DetailsPopup
@onready var details_rows: VBoxContainer = $DetailsPopup/CenterContainer/Card/VBox/Rows
@onready var btn_tutup: Button = $DetailsPopup/CenterContainer/Card/VBox/BtnTutup

var _grade_text: String = "D"
var _exiting: bool = false


func _ready() -> void:
	btn_detail.pressed.connect(_open_details)
	btn_tutup.pressed.connect(_close_details)
	btn_konfirmasi.pressed.connect(_on_konfirmasi_pressed)
	AudioDirector.play_bgm(&"run_result")

	backdrop.texture = load(BACKDROP_LOSE if GameState.run_failed else BACKDROP_WIN)
	heading.text = "Laporan Murid:"
	badge.modulate.a = 0.0
	grade_caption.text = ""
	details_popup.visible = false

	_build_papers()
	_compute_grade()
	_fill_details()
	_play_reveal()


## One ReportPaper per approved student. Reviewed per-call-dynamic
## exception (roster size) -- tests/test_viewport_editability.gd ALLOWED.
func _build_papers() -> void:
	for student in GameState.approved_students:
		var paper: ReportPaper = PAPER_SCENE.instantiate()
		paper_row.add_child(paper)
		paper.bind(student)
		paper.modulate.a = 0.0


func _compute_grade() -> void:
	var counted: Array = GameState.count_targets_cleared()
	var passed := not GameState.run_failed and GameState.check_semester_passed()
	var run_score := RunGrade.score(GameState.run_stats,
		int(counted[0]), int(counted[1]), GameState.approved_students.size())
	_grade_text = RunGrade.letter(run_score, passed)


## Mean mood across the roster's approved_students dictionaries
## (kepribadian1 -- see the naming quirk in CLAUDE.md). 0 for an empty
## roster, and a missing key reads as 0 rather than erroring.
static func average_mood(roster: Array) -> float:
	if roster.is_empty():
		return 0.0
	var sum := 0.0
	for s in roster:
		sum += float(s.get("kepribadian1", 0.0))
	return sum / float(roster.size())


## The five authored rows, in the brief's order.
func _fill_details() -> void:
	var stats: RunStats = GameState.run_stats
	var spec := [
		[ICON_EVENT, "Event diikuti", float(stats.event_student_count()), " murid"],
		[ICON_MOOD, "Rata-rata mood murid", average_mood(GameState.approved_students), ""],
		[ICON_JADWAL, "Total penjadwalan", float(stats.schedules_assigned), " slot"],
		[ICON_UANG, "Uang dari wirausaha", float(stats.wirausaha_money), "G"],
		[ICON_GAGAL, "Kegagalan", float(stats.minigames_lost), ""],
	]
	for i in range(mini(spec.size(), details_rows.get_child_count())):
		var row: RunResultRow = details_rows.get_child(i)
		row.set_row(String(spec[i][1]), float(spec[i][2]), String(spec[i][3]),
			spec[i][0] as Texture2D)


## Papers stagger in, then the badge slams.
func _play_reveal() -> void:
	Juice.pop_in(heading)
	var i := 0
	for paper in paper_row.get_children():
		Juice.pop_in(paper, float(i) * paper_stagger)
		i += 1
	await get_tree().create_timer(float(i) * paper_stagger + badge_delay).timeout
	if not is_instance_valid(self):
		return
	_slam_badge()


func _slam_badge() -> void:
	var b := RunGrade.badge(_grade_text)
	badge.texture = load(RunGrade.BADGE_TEXTURES[b])
	grade_caption.text = String(GRADE_CAPTIONS.get(_grade_text, ""))

	Juice.set_pivot_center(badge)
	badge.scale = Vector2(3.0, 3.0)
	badge.modulate.a = 0.0
	var t := Juice.tokens()
	var tw := badge.create_tween().set_parallel(true)
	tw.tween_property(badge, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(badge, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(badge.get_parent(), 8.0)
		if RunGrade.is_top_grade(_grade_text):
			AudioDirector.play_sfx(&"reward")
		elif _grade_text == "D":
			AudioDirector.play_sfx(&"fail"))


func _open_details() -> void:
	AudioDirector.play_sfx(&"popup_open")
	details_popup.visible = true
	Juice.fade_in(details_popup)
	for row in details_rows.get_children():
		row.play_count_up(0.7)


func _close_details() -> void:
	AudioDirector.play_sfx(&"popup_close")
	details_popup.visible = false


func _on_konfirmasi_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	var destination := _apply_confirm()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene(destination)


## Reset the per-grade state and hand the grade choice to the level-select
## modal. Roster prep is what a grade transition always did (mood/energy
## back to 80, base_akademis* erased so initialize_grade_targets()
## re-baselines). A grade-9 win additionally unlocks level select for good.
## Nothing here touches current_grade -- the modal's pick calls set_grade().
func _apply_confirm() -> String:
	if not GameState.run_failed and GameState.current_grade >= 9:
		GameState.is_game_beaten = true
		GameSettings.save_settings()

	for student in GameState.approved_students:
		student["kepribadian1"] = 80.0
		student["kepribadian2"] = 80.0
		student.erase("base_akademis1")
		student.erase("base_akademis2")
		student.erase("base_akademis3")
	GameState.day_schedules.clear()
	GameState.minggu_ke = 1
	GameState.returned_from_student_card = false
	GameState.lobby_tutorial_completed = true
	GameState.run_stats.reset()
	GameState.run_failed = false

	GameState.open_level_select = true
	return CUTSCENE_SCENE
```

- [ ] **Step 4: Controller — rebuild `RunResult.tscn`**

Open the scene, delete the old `MarginContainer/Column` children (`TitleLabel`, `GradeCard`, `RowsBox`, `BtnSelesai`) with `node_manage(op="delete")`, keep `Backdrop`, `Scrim`, `MarginContainer`, `Column`, then build:

```
/RunResult/MarginContainer/Column                 VBoxContainer (existing) alignment 1
  Badge                    TextureRect  custom_minimum_size {260,260}; expand_mode 1; stretch_mode 5;
                           size_flags_horizontal 4; texture ".../badge_d.svg"; modulate a 0
  GradeCaption             Label  theme_type_variation "CaptionLabel"; horizontal_alignment 1; text ""
  Heading                  Label  theme_type_variation "H2Label"; horizontal_alignment 1; text "Laporan Murid:"
  Papers                   ScrollContainer  custom_minimum_size {0,600}; horizontal_scroll_mode 1 (AUTO); vertical_scroll_mode 0 (DISABLED)
    PaperRow               HBoxContainer   (papers instanced here at runtime)
  Buttons                  HBoxContainer   alignment 1
    BtnDetail              Button  theme_type_variation "SecondaryButton"; text "Detail"; custom_minimum_size {360,96}
    BtnKonfirmasi          Button  theme_type_variation "PrimaryButton";   text "Konfirmasi"; custom_minimum_size {360,96}

/RunResult/DetailsPopup    Control  anchors 0,0,1,1 offsets 0; visible false; mouse_filter 0       # LAST child
  Scrim2                   Panel  theme_type_variation "Scrim"; anchors 0,0,1,1 offsets 0
  CenterContainer          CenterContainer  anchors 0,0,1,1 offsets 0
    Card                   PanelContainer  theme_type_variation "Card"
      VBox                 VBoxContainer  custom_minimum_size {820,0}
        Title              Label  theme_type_variation "H2Label"; horizontal_alignment 1; text "Detail Semester"
        Rows               VBoxContainer
          Row1..Row5       node_create(scene_path="res://Scenes/EndGame/RunResultRow.tscn")  ×5
        BtnTutup           Button  theme_type_variation "SecondaryButton"; text "Tutup"; custom_minimum_size {300,96}
scene_save()
```

In `tests/test_viewport_editability.gd`, update the `RunResult.gd` entry's comment: "instances one ReportPaper per student into Papers/PaperRow (the six rows moved into the authored DetailsPopup)". The value stays `0`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="run_result")`, `test_run(suite="viewport_editability")`, `test_run(suite="audio_coverage")`.
Expected: all PASS. `audio_coverage` needs no edit — its only `coin` references are the generic known-cue list (:119) and a Lobby entry (:211); it never asserted RunResult's money chime, and the money row now lives in the popup and does not chime.

- [ ] **Step 6: Live check, once (controller)**

`project_run(mode="main")` → F1 → Scenes → **Gladi Resik: Semua Lulus** → through StatCheck and WinScreen → tap → **RunResult**: cg2 under the scrim, four papers stagger in, the A badge slams; **Detail** opens the popup with five counting rows; **Konfirmasi** wipes to the cutscene with the Kelas 7–9 modal open. Pick Kelas 8 → intro → StudentCard. Then F1 → **Pulihkan**. One `editor_screenshot(source="game")` of the stamped result and one of the popup.

- [ ] **Step 7: Commit**

```bash
git add Scripts/EndGame/RunResult.gd Scenes/EndGame/RunResult.tscn tests/test_run_result.gd tests/test_viewport_editability.gd
git commit -m "feat(endgame): rebuild RunResult with a badge, report papers, details and level-select confirm

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Documentation and the full-suite gate

**Files:**
- Modify: `CLAUDE.md` — the flow line and the "RunResult owns grade progression" sentences (the "Loop:" paragraph, the 2026-09-02 entry, and the Plan A/B paragraph).

- [ ] **Step 1: Update the docs**

Flow: **TesNotice → ExamProgress → StatCheck → WinScreen / LoseScreen → RunResult → CutScene (level select) → StudentCard**. Replace "RunResult owns grade progression" with: "Since Plan C, RunResult no longer advances the grade: Konfirmasi resets the per-grade state (`_apply_confirm()`), sets `GameState.open_level_select`, and routes to `cut_scene.tscn`, whose `_ready` opens the Kelas 7–9 modal once and clears the flag. The player's pick calls `GameState.set_grade()`. A grade-9 win still sets `is_game_beaten` and saves settings. The report's five metrics live in the authored `DetailsPopup`; `RunStats.schedules_assigned` (counted at `AturJadwal._on_activity_selected`) is new. The badge is `RunGrade.badge()` — A/B/C/D placeholders in `Assets/Images/UI/Placeholders/badge_*.svg`."

Also update the rehearsal paragraph: after a rehearsal reaches RunResult, **Konfirmasi now opens level select** rather than returning to MainMenu — press Pulihkan before picking a grade, or the pick will run `set_grade()` over the rehearsal state (the snapshot still restores it afterwards).

- [ ] **Step 2: Run the full suite**

Run: `filesystem_manage(op="scan")`, `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, `test_run()`.
Expected: **all passing, 56 suites.** Count from 808: +2 (run_stats badge) +1 (run_stats schedule) +1 (atur_jadwal) +1 (cutscene) +3 (paper) −4 (deleted run_result tests) +8 (new run_result) = **820**. Any failure is a regression from this plan.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(endgame): describe the redesigned RunResult and player-chosen progression

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

(If `CLAUDE.md` carries unrelated uncommitted hunks, the controller commits it with the revert-commit-reapply procedure.)
