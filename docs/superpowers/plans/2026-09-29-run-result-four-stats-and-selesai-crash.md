# RunResult: four stats, owner icons, and the Selesai crash — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the game crashing when a beaten Kelas 9 run presses Selesai. Cut the end-game report (RunResult) from six rows to four (Minigame selesai, Minigame kalah, Uang dari wirausaha, Event yang diikuti), drawn with the owner's new icons.

**Architecture:** The crash is a Godot 4.6.2 engine bug: a `const Dictionary[String, PackedStringArray]` built from array literals comes out corrupted, and iterating it segfaults. We replace it with an untyped const `Dictionary` of plain Arrays and add a project-wide scan so the pattern cannot return. The report change touches three layers. `RunStats` drops its dead tallies (`minigame_points`, `items_used`) and swaps the per-student event set for a per-event counter (`events_joined`). `RunGrade` scores events against a named full-marks constant instead of roster size. `RunResult` builds four rows from four PNG icons in `Assets/Images/UI/Icons/`.

**Tech Stack:** Godot 4.6.2, GDScript, the Godot AI MCP bridge (`test_run`, `script_patch`, `logs_read`, `project_run`), Google Drive connector (icon download).

**Spec:** No separate spec. The requirements are the user's request of 2026-09-29, quoted verbatim:
> replace the murid ikut event with event yang diikuti, remove barang dipakai and total minigame points, replace the existing with gamewin, gamelose, coin, event, also there is a crash when finishing end game or when completing the end game — https://drive.google.com/drive/folders/1wf9xzaYgbiigPFWR3QcT0AZBNEKeD86k

## Global Constraints

- Godot **4.6.2**; tests run **only** inside the editor through the MCP `test_run` tool (never headless). Suites are `@tool`, and no test may `await`.
- Edit `.gd` files through `script_patch`. If a file was written from outside the editor, do a no-op `script_patch` on it before `test_run`, or the editor serves the stale copy.
- **Never hand-edit a `.tscn` while the editor is attached.** No task in this plan needs a scene edit.
- `Balance.gd` is not ours: do not touch it. New tunables go in a named `const` in the owning script (like `RunGrade.WEIGHT_*`).
- All UI text is Indonesian. Every script keeps its `##` header and a `##` line on every `@export` (`tests/test_script_documentation.gd`).
- No emoji as icons. No `theme_override_*` except the layout constants already present.
- Commits: Conventional Commits with a scope, ending with the attribution line
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The main checkout is shared across sessions. Work on a fresh branch off `Textures` in a worktree (`superpowers:using-git-worktrees`), for example `fix/run-result-four-stats`.
- After each `scene_save` (none planned), or any full `test_run`, check `git status`. `git checkout --` only `Assets/Theme/kejartes_theme.tres` and `default_bus_layout.tres` if the run rewrote them.

## Background: the crash, root-caused

Evidence is in `%APPDATA%\Godot\app_userdata\KejarTes Ver9.00\logs\godot2026-09-29T14.49.45.log`. The log comes from a Gladi Resik `grade_a` (Kelas 9 pass) followed by pressing Selesai:

```
ERROR: RunResult: no static  on res://Scripts/AturJadwal/AturJadwal.gd to reset   (x3)
CrashHandlerException: Program crashed with signal 11
GDScript backtrace: [0] _apply_progression (RunResult.gd:364)  [1] _on_selesai_pressed (RunResult.gd:268)
```

The flag name is an **empty string**. AturJadwal lists **two** flags but **three** errors fire, and the next entry segfaults. The loop is walking a corrupted `PackedStringArray`. A standalone headless repro with no project code reproduces it exactly:

```gdscript
extends SceneTree
const TYPED: Dictionary[String, PackedStringArray] = {"a": ["x", "y"], "b": ["z"]}
const PLAIN := {"a": ["x", "y"], "b": ["z"]}
func _init() -> void:
	for k in PLAIN:
		for f: String in PLAIN[k]: print(k, " -> ", f)    # a -> x, a -> y, b -> z  (correct)
	for k: String in TYPED:
		print(typeof(TYPED[k]), " size=", TYPED[k].size()) # 28 size=24  (garbage)
		for f: String in TYPED[k]: print(k, " -> '", f, "'") # a -> '' x3, then signal 11
	quit()
```

Only the beaten-game branch of `RunResult._apply_progression()` walks `TUTORIAL_FLAGS`, so the crash hits exactly when the whole game is completed. The grep found no other `Dictionary[…, Packed*Array]` const in the project. The existing `test_every_tutorial_flag_to_reset_exists_on_its_script` passes in the editor, which reads the constant through `get_script_constant_map()`, so it did not catch this.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Scripts/EndGame/RunResult.gd` | modify | untyped `TUTORIAL_FLAGS`; four rows, four new icon consts |
| `tests/test_project_hygiene.gd` | modify | new scan: no const typed dictionary with packed-array values |
| `Scripts/EndGame/RunStats.gd` | modify | drop `minigame_points`, `items_used`, `event_student_ids`; add `events_joined` |
| `Scripts/EndGame/RunGrade.gd` | modify | event part = `events_joined / EVENTS_FULL_MARKS` |
| `Scripts/SchoolSimulation/SchoolDay.gd` | modify | three roster loops → `record_event()` |
| `Scripts/SchoolSimulation/StudentManager.gd` | modify | `record_minigame(won)` (no points) |
| `Scripts/GameState.gd` | modify | drop `run_stats.record_item_use(quantity)` |
| `Scripts/Debug/EndGameRehearsal.gd` | modify | seed `events_joined`; drop points/items keys |
| `Assets/Images/UI/Icons/{gamewin,gamelose,coin,event}_icon.png` | create | owner art from Drive |
| `Assets/Images/UI/Icons/README.md` | modify | four new rows |
| `tests/test_run_stats.gd`, `tests/test_run_result.gd`, `tests/test_school_day.gd`, `tests/test_economy_state.gd`, `tests/test_end_game_rehearsal.gd`, `tests/test_ui_icons.gd` | modify | follow the new API |
| `docs/superpowers/CHANGELOG.md` | modify | one entry, newest first |

Icon mapping (Drive file → row):

| Drive file | Drive id | Saved as | Row |
|---|---|---|---|
| `gamewin_icon.png` | `1AVhRQO8tNjOwLIgPWKpkD2YyvupcWZ8d` | `gamewin_icon.png` | Minigame selesai |
| `gamelose_icon.png` | `1ISJBfHD3fYSqzvTTsxx2W29UwivC6Pnh` | `gamelose_icon.png` | Minigame kalah |
| `coin_icon.png` | `10yCpevpK67uFkk96swT6MFgUjmOYX48f` | `coin_icon.png` | Uang dari wirausaha |
| `calendar_icon.png` | `1HgcL9PUblixLdJ8WWj3KurRYQpIbvajU` | `event_icon.png` | Event yang diikuti |

The folder holds no file named "event". `calendar_icon.png` is assumed to be the event icon, and `star_icon.png` goes unused, since its only use would be the removed points row. **Confirm with the owner before Task 4.**

---

### Task 1: Fix the Selesai crash

**Files:**
- Modify: `Scripts/EndGame/RunResult.gd:90-96` (the `TUTORIAL_FLAGS` const)
- Test: `tests/test_project_hygiene.gd` (new test at the end)

**Interfaces:**
- Consumes: nothing.
- Produces: `RunResult.TUTORIAL_FLAGS` stays a `path -> [flag, …]` map. Its value type is now plain `Array`, not `PackedStringArray`, and `_reset_static_flag(path, flag)` is unchanged.

- [ ] **Step 1: Write the failing regression scan**

Append to `tests/test_project_hygiene.gd`:

```gdscript
## Godot 4.6.2 corrupts a const typed Dictionary whose values are packed
## arrays built from array literals: every element reads as "" and walking
## it segfaults. RunResult.TUTORIAL_FLAGS did this and crashed every beaten
## game on Selesai (2026-09-29). Plain Arrays in an untyped const are safe.
func test_no_const_typed_dictionary_of_packed_arrays() -> void:
	var offenders: Array[String] = []
	var re := RegEx.create_from_string(
		"(?m)^\\s*const\\s+\\w+\\s*:\\s*Dictionary\\[[^\\]]*Packed\\w+Array\\s*\\]")
	for path in _gd_files_under("res://Scripts"):
		if re.search(FileAccess.get_file_as_string(path)) != null:
			offenders.append(path)
	assert_eq(offenders, [] as Array[String],
		"const Dictionary[..., Packed*Array] crashes on 4.6.2: %s" % [offenders])


func _gd_files_under(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_gd_files_under(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	return out
```

If `test_project_hygiene.gd` already defines a recursive `.gd` walker, reuse it and do not add `_gd_files_under` (grep `func _` in that file first).

- [ ] **Step 2: Run it and confirm it fails**

`test_run(suite="project_hygiene")`. Expected: FAIL, listing `res://Scripts/EndGame/RunResult.gd`.

- [ ] **Step 3: Replace the const**

In `Scripts/EndGame/RunResult.gd`, replace lines 90-96 with:

```gdscript
## The first-run tutorial flags a beaten game resets, by the script that owns
## them as static vars. StudentList's walkthrough flag once pointed at Lobby.gd,
## which has none, and the old silent guard hid it.
##
## Untyped on purpose: as a const Dictionary[String, PackedStringArray] this
## read back corrupted on Godot 4.6.2 (every flag "" and a segfault walking it),
## which crashed every beaten game on Selesai. Pinned by
## test_project_hygiene's test_no_const_typed_dictionary_of_packed_arrays.
const TUTORIAL_FLAGS := {
	"res://Scripts/AturJadwal/AturJadwal.gd": ["tutorial_phase1_done", "tutorial_phase3_done"],
	"res://Scripts/StudentList/StudentList.gd": ["tutorial_shown"],
}
```

The loop at lines 362-364 (`for path: String in TUTORIAL_FLAGS:` / `for flag: String in TUTORIAL_FLAGS[path]:`) stays as it is. The repro shows typed loop variables over plain Arrays are fine.

- [ ] **Step 4: Run the suites and confirm they pass**

`test_run(suite="project_hygiene")` and `test_run(suite="run_result")`. Expected: PASS, including `test_every_tutorial_flag_to_reset_exists_on_its_script`.

- [ ] **Step 5: Verify live that the crash is gone**

1. `project_run` with the main scene. Press F1 → Scenes → **🎭 Gladi Resik Akhir Kelas** → preset `grade_a`. It arms Kelas 9, week 8/8, and teleports to TesNotice.
2. Play through TesNotice → ExamProgress → StatCheck → EndCutscene → RunResult. Wait for the badge, then press **Kembali ke Menu**.
3. `logs_read(source="game")`. Expected: no `no static  on` error and no `CrashHandlerException`. MainMenu loads and `GameState grade set to: Kelas 7` is logged. On a crash the game-log buffer can lose the tail, so also check the newest file in `%APPDATA%\Godot\app_userdata\KejarTes Ver9.00\logs\`.
4. `project_manage(op="stop")`.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/RunResult.gd tests/test_project_hygiene.gd
git commit -m "fix(run-result): stop the beaten-game Selesai crash

A const Dictionary[String, PackedStringArray] reads back corrupted on
Godot 4.6.2; walking TUTORIAL_FLAGS segfaulted on every Kelas 9 pass.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: RunStats and RunGrade — count events, drop dead tallies

**Files:**
- Modify: `Scripts/EndGame/RunStats.gd` (whole file)
- Modify: `Scripts/EndGame/RunGrade.gd:18-22, 52-55`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:876-880, 1251-1255, 1633-1637`
- Modify: `Scripts/SchoolSimulation/StudentManager.gd:115, 129` (and the `roster_points` declaration above line 105)
- Modify: `Scripts/GameState.gd:556`
- Modify: `Scripts/Debug/EndGameRehearsal.gd:217-258, 286-299`
- Test: `tests/test_run_stats.gd`, `tests/test_school_day.gd:506`, `tests/test_economy_state.gd:201-237`, `tests/test_end_game_rehearsal.gd:265-270`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces, used by Task 3:
  - `RunStats.minigames_won: int`, `RunStats.minigames_lost: int`, `RunStats.wirausaha_money: int`, `RunStats.events_joined: int`
  - `RunStats.record_minigame(won: bool) -> void`
  - `RunStats.record_wirausaha(amount: int) -> void`
  - `RunStats.record_event() -> void`
  - `RunStats.minigames_played() -> int`, `RunStats.minigame_win_rate() -> float`, `RunStats.reset() -> void`
  - `RunGrade.EVENTS_FULL_MARKS: int = 4`
  - `RunGrade.score(stats, targets_cleared, targets_total, roster_size)` keeps its signature. `roster_size` is no longer read, but stays so RunResult's call does not change. Its `##` doc says so.
- Removed: `minigame_points`, `items_used`, `event_student_ids`, `record_item_use()`, `record_event_student()`, `event_student_count()`.

Why `EVENTS_FULL_MARKS = 4`: today every event marks the whole roster (see the SchoolDay comments), so the old event part was 0 before the first event and full marks after it. Four is the roster size the rehearsal presets are tuned against. With `events_joined / 4`, every rehearsal preset scores exactly what it did before (each preset's `events` is at most 4 = roster size), and real play now earns the part gradually. Like `MONEY_FULL_MARKS`, it is an estimate pending the balance pass.

- [ ] **Step 1: Rewrite `tests/test_run_stats.gd` against the new API**

Replace lines 13-87 (from `test_new_run_stats_starts_at_zero` through `_perfect_stats`) with:

```gdscript
func test_new_run_stats_starts_at_zero() -> void:
	var s := RunStats.new()
	assert_eq(s.minigames_won, 0, "menang starts at 0")
	assert_eq(s.minigames_lost, 0, "kalah starts at 0")
	assert_eq(s.wirausaha_money, 0, "money starts at 0")
	assert_eq(s.events_joined, 0, "no events yet")


func test_record_minigame_splits_wins_and_losses() -> void:
	var s := RunStats.new()
	s.record_minigame(true)
	s.record_minigame(true)
	s.record_minigame(false)
	assert_eq(s.minigames_won, 2, "two wins counted")
	assert_eq(s.minigames_lost, 1, "one loss counted")
	assert_eq(s.minigames_played(), 3, "played is the sum")


func test_minigame_win_rate_is_zero_when_nothing_played() -> void:
	var s := RunStats.new()
	assert_eq(s.minigame_win_rate(), 0.0, "no divide by zero")


func test_minigame_win_rate_is_wins_over_played() -> void:
	var s := RunStats.new()
	s.record_minigame(true)
	s.record_minigame(false)
	s.record_minigame(false)
	s.record_minigame(false)
	assert_eq(s.minigame_win_rate(), 0.25, "1 of 4")


func test_every_event_counts() -> void:
	var s := RunStats.new()
	s.record_event()
	s.record_event()
	s.record_event()
	assert_eq(s.events_joined, 3, "each event is one more, no dedupe")


func test_money_accumulates() -> void:
	var s := RunStats.new()
	s.record_wirausaha(1500)
	s.record_wirausaha(500)
	assert_eq(s.wirausaha_money, 2000, "money summed")


func test_reset_clears_everything() -> void:
	var s := RunStats.new()
	s.record_minigame(true)
	s.record_minigame(false)
	s.record_wirausaha(100)
	s.record_event()
	s.reset()
	assert_eq(s.minigames_won, 0, "wins cleared")
	assert_eq(s.minigames_lost, 0, "losses cleared")
	assert_eq(s.wirausaha_money, 0, "money cleared")
	assert_eq(s.events_joined, 0, "events cleared")


func test_the_dropped_tallies_are_gone() -> void:
	var s := RunStats.new()
	for prop in ["minigame_points", "items_used", "event_student_ids"]:
		assert_false(prop in s, "%s no longer exists" % prop)


func test_events_score_against_full_marks_not_roster() -> void:
	var s := RunStats.new()
	for i in range(RunGrade.EVENTS_FULL_MARKS / 2):
		s.record_event()
	assert_eq(RunGrade.score(s, 0, 12, 4), RunGrade.WEIGHT_EVENTS / 2.0,
		"half the full-marks events earn half the event weight")


func _perfect_stats() -> RunStats:
	var s := RunStats.new()
	for i in range(10):
		s.record_minigame(true)
	s.record_wirausaha(RunGrade.MONEY_FULL_MARKS)
	for i in range(RunGrade.EVENTS_FULL_MARKS):
		s.record_event()
	return s
```

Leave the rest of the file (`test_perfect_run_scores_one_hundred` onward) unchanged.

- [ ] **Step 2: Update the other suites' expectations**

`tests/test_school_day.gd:506`: change the scanned string from `"GameState.run_stats.record_event_student("` to `"GameState.run_stats.record_event()"`. Update that assertion's message to match.

`tests/test_economy_state.gd`: delete `test_using_an_item_records_it_in_run_stats` and `test_a_refused_item_use_does_not_record` (lines 201-232), since the tally they pinned is gone. At line 237 change `GameState.run_stats.record_minigame(true, 10.0)` to `GameState.run_stats.record_minigame(true)`.

`tests/test_end_game_rehearsal.gd:265-270`: the comment explains that the preset needs four distinct roster ids because `record_event_student()` dedupes. Read the test under it. If it asserts on `event_student_count()` / `event_student_ids`, switch it to `GameState.run_stats.events_joined == int(REHEARSAL_STATS[preset]["events"])`. Rewrite the comment to say events are now a plain count, so ids no longer matter for events (keep any part that is still true for the cleared-target counts).

Then `grep -rn "minigame_points\|items_used\|event_student\|record_item_use" tests Scripts`. Any remaining hit outside the files this task already lists must be handled in this task.

- [ ] **Step 3: Run the suites and confirm they fail**

`test_run(suite="run_stats")`. Expected: FAIL/errors on `record_event`, `events_joined`, `EVENTS_FULL_MARKS`.

- [ ] **Step 4: Rewrite `Scripts/EndGame/RunStats.gd`**

```gdscript
@tool
class_name RunStats
extends Resource

## The per-grade tally the run-result screen reports on.
##
## One instance lives on GameState (`GameState.run_stats`) and is reset
## whenever a grade starts. It is written from three places that already
## know these events happen -- StudentManager.record_minigame_result(),
## SchoolDay._pay_out_wirausaha(), and SchoolDay's event branches -- and
## read only by RunGrade and RunResult.
##
## Session-scoped, like everything else on GameState: this is a Resource
## for the typed fields and the Inspector, NOT because it is ever saved.

## Minigames the roster won this grade.
@export var minigames_won: int = 0
## Minigames the roster lost this grade.
@export var minigames_lost: int = 0
## Rupiah paid out from wirausaha this grade.
@export var wirausaha_money: int = 0
## Events the class took part in this grade. The whole roster attends every
## event, so this is one per event, not one per student.
@export var events_joined: int = 0


func record_minigame(won: bool) -> void:
	if won:
		minigames_won += 1
	else:
		minigames_lost += 1


func record_wirausaha(amount: int) -> void:
	wirausaha_money += amount


func record_event() -> void:
	events_joined += 1


func minigames_played() -> int:
	return minigames_won + minigames_lost


func minigame_win_rate() -> float:
	var played := minigames_played()
	if played <= 0:
		return 0.0
	return float(minigames_won) / float(played)


func reset() -> void:
	minigames_won = 0
	minigames_lost = 0
	wirausaha_money = 0
	events_joined = 0
```

- [ ] **Step 5: Update `Scripts/EndGame/RunGrade.gd`**

After line 21 (`const MONEY_FULL_MARKS := 20000`), add:

```gdscript

## Events joined that earn full marks on the event component. Four matches
## the roster the rehearsal presets are tuned against, so their letters are
## unchanged; an estimate awaiting the balance pass, like MONEY_FULL_MARKS.
const EVENTS_FULL_MARKS := 4
```

Replace the event block (lines 52-55) with:

```gdscript
	var event_part := WEIGHT_EVENTS * clampf(
		float(stats.events_joined) / float(EVENTS_FULL_MARKS), 0.0, 1.0)
```

Add a `##` doc line directly above `static func score(`:

```gdscript
## `roster_size` is no longer read (events score against EVENTS_FULL_MARKS);
## it stays so RunResult's call and the tests' calls need no change.
```

`test_score_handles_empty_roster_without_dividing_by_zero` still holds: the divisor is now a non-zero const.

- [ ] **Step 6: Update the writers**

`Scripts/SchoolSimulation/SchoolDay.gd`, in each of the three places (`_trigger_random_event`, the outcome branch near line 1251, `force_event`), replace:

```gdscript
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))
```

with (keeping each site's indentation):

```gdscript
	GameState.run_stats.record_event()
```

`Scripts/SchoolSimulation/StudentManager.gd`: change line 129 to `GameState.run_stats.record_minigame(won)`. Then delete the `roster_points` declaration and the `roster_points += …` line (115), but only if nothing else reads `roster_points`. Grep the function first. If something else does read it, leave both and only change the call.

`Scripts/GameState.gd:556`: delete `run_stats.record_item_use(quantity)`.

`Scripts/Debug/EndGameRehearsal.gd`: in each `REHEARSAL_STATS` entry, delete the `"points": …` and `"items": …` keys and keep `won`, `lost`, `money`, `events`. Replace the body of `_seed_run_stats` from `stats.minigame_points = …` to the end of the event loop with:

```gdscript
	stats.wirausaha_money = int(spec["money"])
	stats.events_joined = int(spec["events"])
	GameState.run_stats = stats
```

If `roster` is now unused in `_seed_run_stats`, rename the parameter `_roster`. Also fix any `##` comment above `REHEARSAL_STATS` that describes points, items or event ids.

- [ ] **Step 7: Rescan and run the suites**

`filesystem_manage(op="scan")`, then a no-op `script_patch` on `RunStats.gd` (it is a `class_name` script). Run `test_run` for `run_stats`, `run_grade_ranks`, `school_day`, `economy_state`, `end_game_rehearsal`, `student_manager` (if it exists). Expected: all PASS. `test_run_grade_ranks` pins the letter per rehearsal preset. If one changed, the preset's `events` exceeded 4 or the grep missed a writer; fix the cause, not the test.

- [ ] **Step 8: Commit**

```bash
git add Scripts/EndGame/RunStats.gd Scripts/EndGame/RunGrade.gd Scripts/SchoolSimulation/SchoolDay.gd Scripts/SchoolSimulation/StudentManager.gd Scripts/GameState.gd Scripts/Debug/EndGameRehearsal.gd tests/
git commit -m "refactor(run-stats): count events joined, drop points and items tallies

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Bring in the owner's four icons

**Files:**
- Create: `Assets/Images/UI/Icons/gamewin_icon.png`, `gamelose_icon.png`, `coin_icon.png`, `event_icon.png`
- Modify: `Assets/Images/UI/Icons/README.md` (usage table)
- Test: `tests/test_ui_icons.gd:14-27`

**Interfaces:**
- Consumes: the owner's answer on the event icon (see the mapping table's note).
- Produces: four imported `Texture2D` paths, `res://Assets/Images/UI/Icons/{gamewin,gamelose,coin,event}_icon.png`, used by Task 4.

- [ ] **Step 1: Pin the icons in the test first**

In `tests/test_ui_icons.gd`, append `"gamewin_icon", "gamelose_icon", "coin_icon", "event_icon"` to `NAMES`, and the same four to `FINISHED`. They are owner art, held to size and transparency only.

- [ ] **Step 2: Run and confirm it fails**

`test_run(suite="ui_icons")`. Expected: FAIL, "gamewin_icon exists and imports" and the others.

- [ ] **Step 3: Download the four PNGs from Drive**

For each row of the mapping table, call the Drive connector `download_file_content(fileId=<id>)`. Write the base64 `content` to a scratchpad file, then decode it into place:

```powershell
$b64 = Get-Content "<scratchpad>\gamewin.b64" -Raw
[IO.File]::WriteAllBytes("Assets/Images/UI/Icons/gamewin_icon.png", [Convert]::FromBase64String($b64))
```

Save `calendar_icon.png` as `event_icon.png`. Then `filesystem_manage(op="scan")` so Godot writes the `.import` files. Check each image with the Read tool to confirm a transparent background and one centred subject.

- [ ] **Step 4: Run and confirm it passes**

`test_run(suite="ui_icons")`. Expected: PASS. `gamewin`/`gamelose` are 540 px; `coin` and `calendar` must also be ≥ 256 px with a transparent corner. If one fails, report it to the owner rather than editing their art.

- [ ] **Step 5: Document them**

Add to the README's usage table, before the `home.svg` row:

```markdown
| `gamewin_icon.png` (owner art) | Minigames won | RunResult's "Minigame selesai" row | `test_run_result` |
| `gamelose_icon.png` (owner art) | Minigames lost | RunResult's "Minigame kalah" row | `test_run_result` |
| `coin_icon.png` (owner art) | Money earned | RunResult's "Uang dari wirausaha" row | `test_run_result` |
| `event_icon.png` (owner art) | Events joined | RunResult's "Event yang diikuti" row | `test_run_result` |
```

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/UI/Icons/ tests/test_ui_icons.gd
git commit -m "feat(icons): add the owner's minigame, coin and event icons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: RunResult shows four rows

**Files:**
- Modify: `Scripts/EndGame/RunResult.gd:3-4, 70-78, 139-168`
- Modify: `tests/test_viewport_editability.gd` (only the `ALLOWED` comment for RunResult, if it says "six")
- Test: `tests/test_run_result.gd:217-221, 281-287`

**Interfaces:**
- Consumes: `RunStats.minigames_won`, `.minigames_lost`, `.wirausaha_money`, `.events_joined` (Task 2); the four icon paths (Task 3).
- Produces: nothing further.

- [ ] **Step 1: Rewrite the two row tests**

In `tests/test_run_result.gd`, replace `test_it_reports_all_six_figures` with:

```gdscript
func test_it_reports_the_four_figures() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for label in ["Minigame selesai", "Minigame kalah", "Uang dari wirausaha",
			"Event yang diikuti"]:
		assert_true(src.contains('"%s"' % label), "the report includes '%s'" % label)
	for gone in ["Total poin minigame", "Barang dipakai", "Murid ikut event"]:
		assert_false(src.contains('"%s"' % gone), "'%s' is no longer reported" % gone)
	assert_true(src.contains("stats.events_joined"), "events come from events_joined")
```

Replace the path assertion in `test_the_report_uses_texture_icons_not_emoji` (lines 283-284) with:

```gdscript
	for icon in ["gamewin_icon", "gamelose_icon", "coin_icon", "event_icon"]:
		assert_true(src.contains("Assets/Images/UI/Icons/%s.png" % icon),
			"the rows use the owner's %s" % icon)
```

- [ ] **Step 2: Run and confirm it fails**

`test_run(suite="run_result")`. Expected: FAIL on the new labels and icon paths.

- [ ] **Step 3: Update `Scripts/EndGame/RunResult.gd`**

Header, lines 3-4:

```gdscript
## The last screen of a run: what the player actually did this grade,
## reported as four counted-up figures and one letter grade.
```

Replace the six icon consts (lines 70-78) with:

```gdscript
## The report's four icons, the owner's art, preloaded so a row swap costs
## nothing at reveal time. Documented in Assets/Images/UI/Icons/README.md.
const ICON_MINIGAME_MENANG := preload("res://Assets/Images/UI/Icons/gamewin_icon.png")
const ICON_MINIGAME_KALAH := preload("res://Assets/Images/UI/Icons/gamelose_icon.png")
const ICON_UANG := preload("res://Assets/Images/UI/Icons/coin_icon.png")
const ICON_EVENT := preload("res://Assets/Images/UI/Icons/event_icon.png")
```

In `_build_rows()`, change "The six rows" / "six frozen rows" in its `##` comment to "four", and replace the `spec` array with:

```gdscript
	var spec := [
		[ICON_MINIGAME_MENANG, "Minigame selesai", float(stats.minigames_won), ""],
		[ICON_MINIGAME_KALAH, "Minigame kalah", float(stats.minigames_lost), ""],
		[ICON_UANG, "Uang dari wirausaha", float(stats.wirausaha_money), "G"],
		[ICON_EVENT, "Event yang diikuti", float(stats.events_joined), " event"],
	]
```

The `_money_row` match on `"Uang dari wirausaha"` stays as it is.

`grep -n "six" tests/test_viewport_editability.gd`. If RunResult's `ALLOWED` comment says six rows, make it four. Do not change the count value.

- [ ] **Step 4: Run and confirm it passes**

No-op `script_patch` on `RunResult.gd`, then `test_run` for `run_result`, `viewport_editability`, `script_documentation`, `tall_screen_layout`. Expected: all PASS.

- [ ] **Step 5: Look at it once**

`project_run`, then Gladi Resik `grade_a`, and play to RunResult. Take one full-size `editor_screenshot` of the rows once the badge has landed. Check for four rows, the new icons at the 72 px slot with nothing clipped, and a value reading like `3 EVENT`. Then press **Kembali ke Menu** and confirm, as in Task 1 Step 5, that no crash is logged. `project_manage(op="stop")`.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/RunResult.gd tests/test_run_result.gd tests/test_viewport_editability.gd
git commit -m "feat(run-result): report four figures with the owner's icons

Event yang diikuti replaces Murid ikut event; Total poin minigame and
Barang dipakai are gone.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Full suite, changelog, ship

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (new entry at the top)

- [ ] **Step 1: Changelog entry**

Add at the top of `docs/superpowers/CHANGELOG.md`, following the style of the entries already there:

```markdown
## 2026-09-29 — RunResult: four figures, owner icons, Selesai crash

- **Crash:** every beaten game (Kelas 9 pass) segfaulted on Selesai.
  `RunResult.TUTORIAL_FLAGS` was a `const Dictionary[String,
  PackedStringArray]`, which Godot 4.6.2 reads back corrupted (flags `""`,
  then signal 11 while iterating). Now an untyped const of plain Arrays;
  `test_project_hygiene` bans the pattern project-wide.
- **Report:** six rows → four. *Event yang diikuti* (`RunStats.events_joined`,
  one per event) replaces *Murid ikut event*; *Total poin minigame* and
  *Barang dipakai* are gone, with their tallies. `RunGrade` scores events
  against `EVENTS_FULL_MARKS = 4`; rehearsal letters unchanged.
- **Icons:** owner art `gamewin/gamelose/coin/event_icon.png` in `UI/Icons/`.
```

- [ ] **Step 2: Full run**

One full `test_run` (budget an editor restart afterwards; see CLAUDE.md). Expected: every suite green. Then `git status`, and `git checkout --` the rebaked theme and the bus layout if they changed.

- [ ] **Step 3: Commit and ship**

```bash
git add docs/superpowers/CHANGELOG.md
git commit -m "docs(changelog): RunResult four figures and the Selesai crash

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then finish with the `ship-pr` skill.

---

## Self-review

- **Coverage:** crash → Task 1. "Murid ikut event" → "Event yang diikuti" → Tasks 2 and 4. Remove "Barang dipakai" and "Total poin minigame" → Tasks 2 and 4. Icons gamewin/gamelose/coin/event → Tasks 3 and 4.
- **Names used across tasks:** `record_event()`, `events_joined`, `record_minigame(won)`, `EVENTS_FULL_MARKS`, the four icon paths `Assets/Images/UI/Icons/{gamewin,gamelose,coin,event}_icon.png`. These match in Tasks 2, 3 and 4.
- **Open question for the owner:** is `calendar_icon.png` the event icon? The plan assumes yes. `star_icon.png` is unused.
