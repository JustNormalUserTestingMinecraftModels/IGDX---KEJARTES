# PR2 — Menari Bug + Minigame Variety Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Revision (2026-09-28): clean-code pass; status audit.**
>
> **Status: NOT IMPLEMENTED.** Checked against `Textures` @ `a6bc2a15`:
> no `_pick_variant`, no picker class, no `variants_played_*` state, no
> `tests/test_minigame_variants_reachable.gd` or variety suite. Nothing in
> `docs/superpowers/CHANGELOG.md` or `DEBT.md` records the "LombaMenari
> never appears" bug as found or fixed. LombaMenari has had several passes
> since 2026-09-11 (FNF note camera, festival backdrop, dancer rig, wider hit
> window), and `tests/test_minigame_art.gd` / `test_dance_camera.gd` already
> instantiate its scene, so the scene itself loads. `SchoolDay.tscn` still
> sets none of the eight minigame `@export`s; all eight come from the
> `load()` fallbacks in `SchoolDay._ready()`. The spec's PR1 run-length change
> has **not** landed: `Balance.JUMLAH_MINGGU_KELAS_7/8/9` are still 6/12/16.
>
> **What changed in this revision:**
> - **The picker moved out of `SchoolDay.gd`.** SchoolDay is 1638 lines, at
>   its `LARGE_SCRIPTS` cap. The picker is a new `@tool class_name
>   MinigameVarietyPicker extends RefCounted`. SchoolDay only calls it, and
>   the file ends **5 lines shorter** (1633).
> - **Per-grade play counts moved from `GameState` to `RunStats`.** The old
>   plan reset them in `GameState.reset_roster_for_new_grade()`. That call
>   returns early on an empty roster and never runs on a grade-7 restart, a
>   grade-8/9 retry or Forget Session, so old counts would carry into a new
>   attempt. `GameState.run_stats.reset()` already runs at every one of those
>   boundaries. `GameState.gd` is not touched.
> - **Line numbers updated:** the three `randi() % arr.size()` sites are now
>   `SchoolDay.gd:828/833/838` (were 931/935/939).
>   `skip_to_results()` picks a category, never a variant, so it has nothing
>   to change (the old "parallel path at :1293" does not exist).
> - **Bugs fixed in the old snippets:**
>   - The old picker test did `set_script(SchoolDay.gd)` on a Node. SchoolDay
>     is not `@tool`, so its methods do not run in the editor runner.
>   - The unseen-bias test recorded every pick, so after the first roll both
>     variants were "seen". It could never reach 65%.
>   - "Last 2 weeks" was `total - current <= 2`, which is the last **three**
>     weeks. It is now inclusive: `weeks_left_in_grade = max - week + 1 <= 2`.
>   - A 2-slot cooldown over a 2-variant category empties the pool on the
>     third seni pick. The old code then fell back to both variants, so the
>     old test "never back-to-back" would fail. The cooldown window now
>     shrinks to the latest pick instead.
>   - The cooldown was keyed on the file name but the counts on the basename.
>     Both now use `EventDialogueCatalog.minigame_key()`.
>   - `assert_neq` is `assert_ne`.
>   - `_total_weeks_this_grade()` copied `GameState.get_max_weeks()`. The
>     picker reads `GameState.max_minggu` instead.
>   - The test comment said "G7 has 4 weeks". G7 has 6 today.
> - **Reachability test expectation corrected.** `BaseMinigame` is not
>   `@tool`, so an editor-instantiated minigame never runs `_ready()`. The
>   suite is expected to **pass** today. It pins load and instantiate for all
>   eight scenes. The bug hunt is in a real game run (Task 2).
> - The spec's "update `test_school_day.gd`'s picker-fairness test" has no
>   target: no such test exists (only a source scan for the uniform-noise
>   branch, which still holds).
> - Added: **Clean code** constraints, `[editor]`/`[code]` tags, the real
>   `suite_name()`s, a Boy Scout pass on the two SchoolDay functions touched
>   (`_roll_event`, `_pick_minigame_category`), expected baseline diffs per
>   task, and a finishing task (CHANGELOG / DEBT / CLAUDE.md count, full run,
>   ship-pr).

**Goal:** Find out why "LombaMenari never appears", and fix it if there is a defect. Replace uniform-random variant picking with a picker that prefers variety (cooldown, weighted toward unseen variants, and a last-two-weeks safety net), so a player sees every minigame in a category during a grade whenever that category rolls.

**Architecture:**
- **Reachability suite:** loads and instantiates all eight minigame scenes.
- **LombaMenari root cause:** reproduced in a real game run over the MCP bridge.
- **`MinigameVarietyPicker`** (new, `Scripts/SchoolSimulation/MinigameVarietyPicker.gd`): a pure `@tool RefCounted` with no scene access. It owns the per-week cooldown, and SchoolDay holds one per week (a new SchoolDay is instanced every week). It reads and writes per-grade play counts on `GameState.run_stats` (`RunStats`), which every grade boundary already resets.
- **`SchoolDay._roll_event()`** swaps its three uniform picks for `_variety_picker.pick_this_week(...)`.

**Tech Stack:** GDScript 4.6, McpTestSuite, the Godot AI MCP bridge.

**Spec:** `docs/superpowers/specs/2026-09-11-balance-and-depth-design.md`, section "PR2 — Menari bug + variety picker". This plan differs from the spec in three places. Per-grade counts go on `RunStats`, not `GameState` or `SchoolDay`. The picker is its own class, not `SchoolDay._pick_variant`. The safety net covers two weeks inclusive. The spec's run lengths (4/6/8) are PR1's, not today's; the picker reads whatever `GameState.max_minggu` holds.

## Global Constraints

- **Branch** from the latest `origin/Textures` (it carries `tests/test_project_hygiene.gd`'s autoload-inference guard, which no longer accepts `var x := GameState.…`). Work on a feature branch such as `feat/minigame-variety-picker`, in a worktree if another session holds the main checkout. Run `git branch --show-current` before every commit.
- **Tags:** **[editor]** = through the godot-ai bridge in the session that holds it (`test_run`, `script_patch`, `filesystem_manage`, `project_run`, `logs_read`, `game_manage`, editor restart). **[code]** = plain file writes, git and the headless dump tool. The bridge takes one client at a time: subagents do only **[code]** steps.
- All new suites `extends McpTestSuite`, are `@tool`, and return a real `suite_name()`. `test_run(suite=…)` takes that name, not the file name. **No test is a coroutine** (no `await`).
- Scripts the runner instantiates live must be `@tool`, with real side effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`. `MinigameVarietyPicker` has no `_ready()`. `SchoolDay.gd` and `BaseMinigame.gd` stay non-`@tool`.
- After any **[code]** write to a `.gd` while the editor is open, do a **[editor]** no-op `script_patch` on that file before `test_run` (CLAUDE.md, "Working efficiently here", item 5). After adding a new `class_name` or a new `@export` on a Resource (`RunStats`), run `filesystem_manage(op="scan")` and **restart the editor** before trusting a test (a stale class cache fails for no visible reason). A new `.gd` gets a `.gd.uid` from the scan; commit it.
- No `theme_override_*`, no runtime visual construction. This PR adds no UI.
- `Scripts/Balance.gd` is collaborator-owned and **not edited**. The picker's tuning (weights, cooldown, safety-net window) is ours and lives in named `const`s on `MinigameVarietyPicker`. If the collaborator wants it in Balance, propose that in the PR description.
- No new persistence. `RunStats` is session-scoped like the rest of `GameState`.
- Conventional Commits with a scope: `test(minigame): …`, `fix(minigame): …`, `feat(run-stats): …`, `feat(school-day): …`, `docs(…): …`. In PowerShell, write the message to a file and `git commit -F` (a here-string splits at embedded `"`).

### Clean code (`docs/superpowers/design/clean-code.md`)

- **Typed everything:** every `var`, parameter and return. Use `:=` only when the right-hand side's type is obvious. Never write `var x := GameState.…` (the hygiene guard); write `var x: int = GameState.…`.
- **Named numbers:** every meaningful number is a `##`-documented `const` in the script that owns the behaviour (`MinigameVarietyPicker.UNSEEN_WEIGHT`, SchoolDay's `NORMAL_DAY_HOLD`), or an `@export` with a `##` line if a designer tunes it. Only `0`, `1`, `2`, `-1`, `0.5` may stand inline.
- **One job per function, ≤ 50 code lines.** Every function in the picker is well under that.
- **Guard clauses** and early `return`, not `if/else` pyramids. The `_pick_minigame_category` rewrite is an example.
- **No duplicated 5+-line bodies.** The picker replaces three near-identical uniform picks (`SchoolDay.gd:828`, `:833`, `:838`) with one call each. The variant key reuses `EventDialogueCatalog.minigame_key()` rather than a third copy of `get_file().get_basename()`. The weeks-left maths does not re-copy `GameState.get_max_weeks()`' `match`.
- **Signals up, calls down.** SchoolDay (the parent) calls the picker. The picker never reaches into SchoolDay or any scene. It reads `GameState` only in `pick_this_week()`, the one entry point meant for live play. Tests call `pick()` with explicit inputs.
- **Fail loudly.** The picker drops a null scene (a failed `load()`) with `push_error()` naming the category, instead of passing it on silently. A category with no scene left returns null, which `SchoolDay._play_minigame()`'s existing null guard skips.
- **No commented-out code**, and no leftover `print("DEBUG`.
- **Boy Scout on every touched SchoolDay function.** `_roll_event` and `_pick_minigame_category` end no longer and fully typed, with their bare numbers named. No other SchoolDay function is touched.
- **Large script:** `SchoolDay.gd` may not grow by a single line past its `LARGE_SCRIPTS` count (1638). It ends this plan at **1633**.
- **Ratchet green every code task:** **[editor]** `test_run(suite="clean_code")`. When it reports **shrank**, lock it in within the same commit with **[code]**
  `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd`
  then check that `git diff ci/clean_code_baseline.gd` only lowers numbers, and do a no-op `script_patch` of `ci/clean_code_baseline.gd` before re-running `clean_code`. Add `-- --rekey` only if a function with a baseline entry is moved or split. This plan moves none, so the only candidate is Task 2's fix if it splits a baselined LombaMenari/BaseMinigame function.

**Expected baseline diffs** (`ci/clean_code_baseline.gd`):

| After | `SchoolDay.gd` lines | `LARGE_SCRIPTS` SchoolDay | `UNTYPED` SchoolDay | `BARE_NUMBERS` SchoolDay | Other |
|---|---|---|---|---|---|
| Task 1 | 1638 | 1638 | 78 | 54 | none (tests are exempt) |
| Task 2 | 1638 | 1638 | 78 | 54 | none, unless the fix lands in a baselined file (then only lower, via the dump) |
| Task 3 | 1638 | 1638 | 78 | 54 | none: `RunStats.gd` has no entries and stays clean |
| Task 4 | 1638 | 1638 | 78 | 54 | none: the new script starts and stays at zero debt |
| Task 5 | **1633** | **1633** | **62** | **50** | dump required; no `LONG_FUNCTIONS` change (`_roll_event` and `_pick_minigame_category` are under 50 and not listed) |
| Task 6 | 1633 | 1633 | 62 | 50 | none |

---

### Task 1: Reachability suite for all 8 minigame variants

**Files:**
- Create: `tests/test_minigame_variants_reachable.gd` (`suite_name()` = `"minigame_variants_reachable"`)

**Interfaces:**
- Consumes: the eight scenes `SchoolDay._ready()` lazy-loads.
- Produces: a green suite that pins load, instantiate, root script and `BaseMinigame` ancestry for each.

- [ ] **Step 1 [code]: Write the suite**

```gdscript
@tool
extends McpTestSuite

## Every minigame SchoolDay can roll loads, instantiates and carries a root
## script that extends BaseMinigame (the 2026-09-11 balance-and-depth spec's
## reachability test, written while chasing "LombaMenari never appears").
##
## What this cannot see: BaseMinigame is deliberately not @tool (see
## test_minigame_star_rubric.gd), so an editor-instantiated minigame never
## runs _ready(). A throw in _ready() or an empty start_game() invariant only
## shows up in a real game run.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_variants_reachable"


## The eight scenes SchoolDay._ready() lazy-loads, in setup_scenes() order.
const VARIANTS: Array[String] = [
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn",
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
	"res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Olahraga/MainBola.tscn",
	"res://Scenes/Minigames/Olahraga/Badminton.tscn",
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn",
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
]
const BASE_MINIGAME := preload("res://Scripts/Minigames/UI/BaseMinigame.gd")


## True when `script` is `base` or inherits from it. Walks the script chain
## rather than using `is`, which a placeholder instance may not answer.
func _extends(script: Script, base: Script) -> bool:
	var current := script
	while current != null:
		if current == base:
			return true
		current = current.get_base_script()
	return false


func test_every_variant_loads_and_instantiates() -> void:
	for path in VARIANTS:
		var scene := load(path) as PackedScene
		assert_true(scene != null, "load failed: " + path)
		if scene == null:
			continue
		var root: Node = track(scene.instantiate())
		assert_true(is_instance_valid(root), "instantiate failed: " + path)
		assert_true(_extends(root.get_script(), BASE_MINIGAME),
			"root script does not extend BaseMinigame: " + path)
```

- [ ] **Step 2 [editor]: Run it.** `filesystem_manage(op="scan")`, then `test_run(suite="minigame_variants_reachable")`. **Expected: PASS** (LombaMenari already instantiates in `minigame_art` and `dance_camera`). A failure here is a real load defect. Record its text and take it into Task 2 as the first lead.

- [ ] **Step 3 [editor]: Ratchet.** `test_run(suite="clean_code")`: green, no baseline change.

- [ ] **Step 4 [code]: Commit** `tests/test_minigame_variants_reachable.gd` and its `.gd.uid`:
  `test(minigame): pin that every SchoolDay minigame loads and instantiates`.

---

### Task 2: Root-cause "LombaMenari never appears"

**Files:**
- Modify: only whatever the repro points at: `Scripts/Minigames/SeniBudaya/LombaMenari.gd`, `Scenes/Minigames/SeniBudaya/LombaMenari.tscn`, `Scenes/Minigames/SeniBudaya/DancerRig.tscn`, or nothing.

Do any scene work in this task **before** the script tasks that follow (CLAUDE.md 4b: `scene_save` writes stale script tabs back).

- [ ] **Step 1 [editor]: Standalone run.** `project_run`. Open the debug overlay (F1) → Minigames → **Lomba Menari (Seni)**; it goes through `DebugManager._launch_minigame_standalone`. Play it to a result, then `logs_read(source="game")` and `logs_read(source="editor")`. Any error names the fault (hypotheses 2 and 3 in the spec: a `_ready()` throw, or an empty invariant in `start_game()`).

- [ ] **Step 2 [editor]: In-week run.**
  1. Seed with Debug → General → **⚡ Seed Playtest State**.
  2. In AturJadwal, put every student on SeniBudaya for all five days.
  3. Run SchoolDay for two or three weeks. For each seni roll, note which variant plays (the EventWarning plus EventDialogue key) and check `logs_read(source="game")` for errors.

  Hypothesis 1 (a null `lomba_menari_scene` after the `load()` fallback) would show there as a skipped day. `_play_minigame()` returns early on a null scene.

- [ ] **Step 3: Branch on the result.**
  - **Defect found:** fix the root cause. `.gd` edits go through `script_patch`. `.tscn` edits go through `scene_open` → `node_set_property` → `scene_save`, then diff every saved scene (the `DancerRig` `@tool` offsets bake on save). If the defect can be expressed in the editor (load, or a scene-declared value), add an assertion for it to `minigame_variants_reachable`. Boy Scout every function you touch. If a touched function has a `LONG_FUNCTIONS` entry and you split it, run the dump with `-- --rekey`.
  - **Not reproduced:** make no code change. Write down the standalone and in-week evidence for Task 6's CHANGELOG entry. The spec's own figure puts a zero-menari run at ~1.5% odds (ten or so seni rolls at 50/50). From Task 5 on, the safety net forces an unseen variant in the grade's last two weeks whenever a seni minigame rolls there.

- [ ] **Step 4 [editor]: Verify.** `test_run(suite="minigame_variants_reachable")`, `test_run(suite="lomba_menari_timing")`, `test_run(suite="dance_camera")` and `test_run(suite="clean_code")` are all green. Run the dump if `clean_code` shrank.

- [ ] **Step 5 [code]: Commit** (only if Step 3 changed files): `fix(minigame): <one-line root cause>`.

---

### Task 3: Per-grade variant play counts on `RunStats`

**Files:**
- Modify: `Scripts/EndGame/RunStats.gd`. Add `variant_plays`, `record_variant_played()`, `variant_play_count()`, and clear them in `reset()`.
- Modify: `tests/test_run_stats.gd` (`suite_name()` = `"run_stats"`).

**Interfaces:**
- Produces: `RunStats.variant_plays: Dictionary` (`{category: {variant key: plays}}`), `RunStats.record_variant_played(category: String, variant: String) -> void`, `RunStats.variant_play_count(category: String, variant: String) -> int`.
- Resets: `reset()` already runs at every grade boundary: `GameState.set_grade()`, `GameState.forget_session()`, `RunResult._apply_progression()`'s advance and retry branches.

- [ ] **Step 1 [code]: Write the failing tests** in `tests/test_run_stats.gd`

```gdscript
func test_variant_plays_count_per_category() -> void:
	var s := RunStats.new()
	s.record_variant_played("SeniBudaya", "LombaMenari")
	s.record_variant_played("SeniBudaya", "LombaMenari")
	s.record_variant_played("SeniBudaya", "BuatBatik")
	assert_eq(s.variant_play_count("SeniBudaya", "LombaMenari"), 2, "two menari plays")
	assert_eq(s.variant_play_count("SeniBudaya", "BuatBatik"), 1, "one batik play")
	assert_eq(s.variant_play_count("SeniBudaya", "Nonexistent"), 0, "unplayed is 0")
	assert_eq(s.variant_play_count("Olahraga", "LombaMenari"), 0, "counts are per category")
```

In `test_reset_clears_everything`, add `s.record_variant_played("Akademis", "Variabel")` before `s.reset()` and this line after it:

```gdscript
	assert_eq(s.variant_play_count("Akademis", "Variabel"), 0, "variant plays cleared")
```

- [ ] **Step 2 [editor]: Run it.** No-op `script_patch` on `tests/test_run_stats.gd`, then `test_run(suite="run_stats")`. Expected: FAIL (the methods are missing).

- [ ] **Step 3 [code]: Implement** in `Scripts/EndGame/RunStats.gd`. Add after `event_student_ids`:

```gdscript
## Plays per minigame variant this grade, for MinigameVarietyPicker:
## {category: {variant key: plays}}, e.g. {"SeniBudaya": {"LombaMenari": 1}}.
@export var variant_plays: Dictionary = {}
```

Add after `record_event_student()`:

```gdscript
## Counts one play of `variant` (a MinigameVarietyPicker.variant_key()) in
## `category`.
func record_variant_played(category: String, variant: String) -> void:
	var plays: Dictionary = variant_plays.get_or_add(category, {})
	plays[variant] = int(plays.get(variant, 0)) + 1


## How many times `variant` of `category` has played this grade.
func variant_play_count(category: String, variant: String) -> int:
	var plays: Dictionary = variant_plays.get(category, {})
	return int(plays.get(variant, 0))
```

Add `variant_plays.clear()` as the last line of `reset()`. Update the file header's "written from four places … read only by RunGrade and RunResult" sentence to also name `MinigameVarietyPicker`, which both writes and reads `variant_plays`.

- [ ] **Step 4 [editor]: Reload and run.** `RunStats` gained a new `@export`: `filesystem_manage(op="scan")`, restart the editor, then `test_run(suite="run_stats")` and `test_run(suite="clean_code")`. Expected: both PASS, no baseline change.

- [ ] **Step 5 [code]: Commit** `Scripts/EndGame/RunStats.gd` and `tests/test_run_stats.gd`:
  `feat(run-stats): count minigame variant plays per grade`.

---

### Task 4: `MinigameVarietyPicker`

**Files:**
- Create: `Scripts/SchoolSimulation/MinigameVarietyPicker.gd`
- Create: `tests/test_minigame_variety_picker.gd` (`suite_name()` = `"minigame_variety_picker"`)

**Interfaces:**
- Consumes: `RunStats.record_variant_played` / `variant_play_count`, `EventDialogueCatalog.minigame_key`, and `GameState.max_minggu` / `minggu_ke` (in `pick_this_week()` only).
- Produces:
  - `MinigameVarietyPicker.new(stats: RunStats)`
  - `pick(category: String, scenes: Array, weeks_left: int) -> PackedScene`
  - `pick_this_week(category: String, scenes: Array) -> PackedScene`
  - `static variant_key(scene: PackedScene) -> String`
  - `static weeks_left_in_grade(max_weeks: int, week: int) -> int`
  - `cooldown: Array[String]`
  - consts `UNSEEN_WEIGHT`, `SEEN_WEIGHT`, `COOLDOWN_LENGTH`, `SAFETY_NET_WEEKS`

- [ ] **Step 1 [code]: Write the failing suite**

```gdscript
@tool
extends McpTestSuite

## MinigameVarietyPicker: which minigame of a rolled category plays (the
## 2026-09-11 balance-and-depth spec, "PR2 -- Variety picker"). The picker is
## a @tool RefCounted with no scene access, so these are behavioural tests
## that drive it with a fresh RunStats and an explicit weeks-left count. No
## SchoolDay instance is used: SchoolDay is not @tool, so its methods do not
## run in the editor. SchoolDay's wiring is checked by a source scan at the end.
## A fixed seed() makes the weighted tests deterministic.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_variety_picker"


const BATIK := preload("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
const MENARI := preload("res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn")
const SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
## Seeds the global RNG so a weighted run draws the same rolls every time.
const RNG_SEED := 20260928
## Picks in a row for the no-repeat test.
const PICKS_IN_A_ROW := 20
## Enough weighted picks that a 75% expectation cannot fall under 65% by luck.
const WEIGHTED_ROLLS := 1000
## The unseen share the spec promises from 3:1 weights (75% expected).
const MIN_UNSEEN_SHARE := 0.65
## Picks per window in the safety-net test.
const SAFETY_NET_ROLLS := 30
## Far from the grade's end, so the safety net is off.
const MANY_WEEKS_LEFT := 10


func _picker_with_batik_seen() -> MinigameVarietyPicker:
	var stats := RunStats.new()
	stats.record_variant_played("SeniBudaya", "BuatBatik")
	return MinigameVarietyPicker.new(stats)


func test_the_variant_that_just_played_never_plays_next() -> void:
	var picker := MinigameVarietyPicker.new(RunStats.new())
	var previous := ""
	for pick_index in PICKS_IN_A_ROW:
		var picked: PackedScene = picker.pick("SeniBudaya", [BATIK, MENARI], MANY_WEEKS_LEFT)
		var key := MinigameVarietyPicker.variant_key(picked)
		assert_ne(key, previous, "pick %d repeated %s" % [pick_index, key])
		previous = key


func test_an_unseen_variant_is_preferred() -> void:
	seed(RNG_SEED)
	var unseen_picks := 0
	for roll in WEIGHTED_ROLLS:
		# A fresh picker each roll, so the pick it records never makes
		# LombaMenari "seen" for the next one.
		if _picker_with_batik_seen().pick("SeniBudaya", [BATIK, MENARI], MANY_WEEKS_LEFT) == MENARI:
			unseen_picks += 1
	assert_gt(float(unseen_picks) / WEIGHTED_ROLLS, MIN_UNSEEN_SHARE,
		"unseen share %d/%d" % [unseen_picks, WEIGHTED_ROLLS])


func test_the_last_two_weeks_force_an_unseen_variant() -> void:
	seed(RNG_SEED)
	for weeks_left in [MinigameVarietyPicker.SAFETY_NET_WEEKS, 1]:
		for roll in SAFETY_NET_ROLLS:
			assert_eq(_picker_with_batik_seen().pick("SeniBudaya", [BATIK, MENARI], weeks_left), MENARI,
				"%d week(s) left must force the unseen variant" % weeks_left)


func test_the_safety_net_waits_for_the_last_two_weeks() -> void:
	seed(RNG_SEED)
	var seen_picks := 0
	for roll in WEIGHTED_ROLLS:
		var picked: PackedScene = _picker_with_batik_seen().pick(
			"SeniBudaya", [BATIK, MENARI], MinigameVarietyPicker.SAFETY_NET_WEEKS + 1)
		if picked == BATIK:
			seen_picks += 1
	assert_gt(seen_picks, 0, "three weeks out, a seen variant can still play")


func test_weeks_left_counts_the_current_week() -> void:
	assert_eq(MinigameVarietyPicker.weeks_left_in_grade(6, 6), 1, "the final week has 1 left")
	assert_eq(MinigameVarietyPicker.weeks_left_in_grade(6, 5), 2, "week 5 of 6 is in the net")
	assert_eq(MinigameVarietyPicker.weeks_left_in_grade(6, 4), 3, "week 4 of 6 is not")


func test_a_pick_is_recorded_and_cooled_down() -> void:
	var stats := RunStats.new()
	var picker := MinigameVarietyPicker.new(stats)
	var key := MinigameVarietyPicker.variant_key(
		picker.pick("SeniBudaya", [BATIK, MENARI], MANY_WEEKS_LEFT))
	assert_eq(stats.variant_play_count("SeniBudaya", key), 1, "the pick counts for the grade")
	assert_eq(picker.cooldown.size(), 1, "the pick is on cooldown")
	assert_eq(picker.cooldown[0], key, "the cooldown holds the pick's key")


func test_a_missing_scene_is_skipped_not_played() -> void:
	# push_error() is not captured as a SCRIPT ERROR, so no expectation is set.
	var picker := MinigameVarietyPicker.new(RunStats.new())
	assert_eq(picker.pick("SeniBudaya", [BATIK, null], MANY_WEEKS_LEFT), BATIK,
		"a failed load must not reach the pick")
	assert_eq(picker.pick("SeniBudaya", [], MANY_WEEKS_LEFT), null,
		"an empty category picks nothing")


func test_school_day_picks_every_category_through_the_picker() -> void:
	var src := FileAccess.get_file_as_string(SCHOOL_DAY)
	assert_contains(src, "MinigameVarietyPicker.new(GameState.run_stats)")
	for pair in [["Akademis", "akademis_scenes"], ["Olahraga", "olahraga_scenes"],
			["SeniBudaya", "seni_scenes"]]:
		assert_contains(src, '_variety_picker.pick_this_week("%s", %s)' % pair)
		assert_false(src.contains("%s[randi()" % pair[1]),
			pair[1] + " is still picked uniformly")
```

- [ ] **Step 2 [code]: Implement `Scripts/SchoolSimulation/MinigameVarietyPicker.gd`**

```gdscript
@tool
class_name MinigameVarietyPicker
extends RefCounted

## Chooses which minigame of a rolled category plays, preferring variety
## (2026-09-11 balance-and-depth spec, "PR2 -- Variety picker"):
##  * a variant among the last COOLDOWN_LENGTH picks sits out, narrowing to
##    just the last pick when that would leave nothing (a two-variant category);
##  * in the grade's last SAFETY_NET_WEEKS weeks, a variant not yet played
##    this grade is forced while one is left;
##  * otherwise an unseen variant weighs UNSEEN_WEIGHT to a seen one's
##    SEEN_WEIGHT.
##
## SchoolDay holds one per week: a new SchoolDay is instanced every week, so
## the cooldown is the week's. The per-grade play counts live on RunStats,
## which every grade boundary already resets. No scene access, so tests drive
## it directly; @tool so the editor's test runner can.

## An unseen variant's weight, against a seen one's SEEN_WEIGHT.
const UNSEEN_WEIGHT := 3
## A variant already played this grade.
const SEEN_WEIGHT := 1
## How many of the latest picks sit out the next one.
const COOLDOWN_LENGTH := 2
## In the grade's last this-many weeks, counting the current one, an unseen
## variant is forced.
const SAFETY_NET_WEEKS := 2

## Variant keys of the latest picks, oldest first, at most COOLDOWN_LENGTH.
var cooldown: Array[String] = []
## Where the grade's play counts are read and recorded.
var _stats: RunStats


func _init(stats: RunStats) -> void:
	_stats = stats


## `scene`'s variant key: its file name without the extension, e.g.
## "LombaMenari". It is the same key EventDialogueCatalog files lines under.
static func variant_key(scene: PackedScene) -> String:
	return EventDialogueCatalog.minigame_key(scene.resource_path)


## Weeks left in a grade of `max_weeks` weeks during week `week`, counting
## that week: the grade's final week has 1 left.
static func weeks_left_in_grade(max_weeks: int, week: int) -> int:
	return max_weeks - week + 1


## pick() for the week GameState is on.
func pick_this_week(category: String, scenes: Array) -> PackedScene:
	var weeks_left: int = weeks_left_in_grade(GameState.max_minggu, GameState.minggu_ke)
	return pick(category, scenes, weeks_left)


## Picks one of `scenes` (all `category` minigames) with `weeks_left` weeks
## left in the grade, and records the pick. Returns null only when no scene
## loaded; SchoolDay._play_minigame() skips a null.
func pick(category: String, scenes: Array, weeks_left: int) -> PackedScene:
	var loaded := _loaded(category, scenes)
	if loaded.is_empty():
		push_error("MinigameVarietyPicker: no %s minigame can play" % category)
		return null
	var candidates := _off_cooldown(loaded)
	if weeks_left <= SAFETY_NET_WEEKS:
		candidates = _unseen_if_any(category, candidates)
	var picked := _weighted_pick(category, candidates)
	_remember(category, picked)
	return picked


## `scenes` without the nulls a failed load() leaves, reporting each one.
func _loaded(category: String, scenes: Array) -> Array[PackedScene]:
	var loaded: Array[PackedScene] = []
	for scene: PackedScene in scenes:
		if scene == null:
			push_error("MinigameVarietyPicker: a %s minigame scene failed to load" % category)
			continue
		loaded.append(scene)
	return loaded


## `scenes` minus the cooldown, narrowing the window to the latest picks
## until something is left; all of `scenes` when nothing ever is.
func _off_cooldown(scenes: Array[PackedScene]) -> Array[PackedScene]:
	for window in range(cooldown.size(), 0, -1):
		var recent: Array = cooldown.slice(cooldown.size() - window)
		var fresh: Array[PackedScene] = []
		for scene in scenes:
			if not recent.has(variant_key(scene)):
				fresh.append(scene)
		if not fresh.is_empty():
			return fresh
	return scenes


## The candidates not yet played this grade, or all of them when none is left.
func _unseen_if_any(category: String, candidates: Array[PackedScene]) -> Array[PackedScene]:
	var unseen: Array[PackedScene] = []
	for scene in candidates:
		if _plays(category, scene) == 0:
			unseen.append(scene)
	return candidates if unseen.is_empty() else unseen


## One candidate, drawn by weight: UNSEEN_WEIGHT unplayed, SEEN_WEIGHT played.
func _weighted_pick(category: String, candidates: Array[PackedScene]) -> PackedScene:
	var weights: Array[int] = []
	var total := 0
	for scene in candidates:
		var weight: int = UNSEEN_WEIGHT if _plays(category, scene) == 0 else SEEN_WEIGHT
		weights.append(weight)
		total += weight
	var roll := randi() % total
	for index in candidates.size():
		roll -= weights[index]
		if roll < 0:
			return candidates[index]
	# Unreachable: roll < total, so the loop always returns.
	return candidates.back()


## How many times `scene` has played in `category` this grade.
func _plays(category: String, scene: PackedScene) -> int:
	return _stats.variant_play_count(category, variant_key(scene))


## Puts `picked` on the cooldown and counts it for the grade.
func _remember(category: String, picked: PackedScene) -> void:
	cooldown.append(variant_key(picked))
	if cooldown.size() > COOLDOWN_LENGTH:
		cooldown.pop_front()
	_stats.record_variant_played(category, variant_key(picked))
```

- [ ] **Step 3 [editor]: Register and run.** `filesystem_manage(op="scan")` registers the new `class_name` and writes the `.gd.uid`. If the suite reports `MinigameVarietyPicker` unknown, restart the editor. Then run `test_run(suite="minigame_variety_picker")`. Expected: every test PASSes **except** `test_school_day_picks_every_category_through_the_picker`, which stays red until Task 5.

- [ ] **Step 4 [editor]: Ratchet.** `test_run(suite="clean_code")`: green, and the new script adds no entry. If it reports anything for `MinigameVarietyPicker.gd`, fix the code. Never add a baseline entry for a new file.

- [ ] **Step 5 [code]: Commit** the script, the suite and both `.gd.uid` files:
  `feat(school-day): variety-preferring minigame picker (cooldown, unseen weight, last-two-weeks net)`.
  The one red scan test goes green in the next commit. If one PR commit must be all-green, hold this commit and land it together with Task 5.

---

### Task 5: Wire the picker into SchoolDay (Boy Scout `_roll_event`, `_pick_minigame_category`)

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd`
- Modify: `ci/clean_code_baseline.gd` (generated by the dump; never by hand)

**Interfaces:**
- Consumes: `MinigameVarietyPicker.pick_this_week`, `GameState.run_stats`.
- Produces: `SchoolDay._variety_picker: MinigameVarietyPicker`, `SchoolDay.MINIGAME_CATEGORIES`, `SchoolDay.HOLIDAY_STATUS_HOLD`, `SchoolDay.NORMAL_DAY_HOLD`.

Every edit goes through `script_patch` (the file is LF). Several existing tests pin this code, and all must stay green:
- `test_event_dialogue.test_minigames_hear_their_line_between_warning_and_play` and `test_event_warning` pin each branch's warning → dialogue → `_play_minigame(scene, "<Category>")`, so **keep the three branches**.
- `test_minigame_weekly_cap` counts exactly two `_pick_minigame_category(w_akademis, w_olahraga, w_seni)` call sites.
- `test_school_day.test_minigame_category_has_uniform_noise` needs `Balance.MINIGAME_KATEGORI_ACAK_PELUANG`.

- [ ] **Step 1 [editor]: Constants (+6 lines).** After `DAY_CATEGORIES`:

```gdscript
## The minigame categories, in _pick_minigame_category()'s uniform-roll order.
const MINIGAME_CATEGORIES: Array[String] = ["Akademis", "Olahraga", "SeniBudaya"]
```

After `NIGHT_HOLD` in the status-line block:

```gdscript
## Seconds a national holiday's status line holds before the day moves on.
const HOLIDAY_STATUS_HOLD := 1.2
## Seconds an uneventful day's "Hari biasa..." line holds.
const NORMAL_DAY_HOLD := 0.8
```

(Only `_roll_event`'s two timers use these. The `0.8` waits at `:952`/`:969` are in functions this plan does not touch.)

- [ ] **Step 2 [editor]: The picker (+3 lines).** After `var seni_scenes: Array     = []`:

```gdscript
## Picks which minigame of the rolled category plays. A new SchoolDay is
## instanced every week, so this picker's cooldown is the week's.
var _variety_picker: MinigameVarietyPicker = MinigameVarietyPicker.new(GameState.run_stats)
```

- [ ] **Step 3 [editor]: `_pick_minigame_category`, flattened (24 → 10 lines, −14).** Keep its `##` doc. Replace the body with guard clauses and the named category list. The behaviour is identical: `randf()` is still drawn first, and the uniform roll still covers both the noise case and the all-zero case.

```gdscript
func _pick_minigame_category(w_akademis: int, w_olahraga: int, w_seni: int) -> String:
	var total_subject_weight := w_akademis + w_olahraga + w_seni
	if randf() < Balance.MINIGAME_KATEGORI_ACAK_PELUANG or total_subject_weight == 0:
		return MINIGAME_CATEGORIES[randi() % MINIGAME_CATEGORIES.size()]
	var choice := randi() % total_subject_weight
	if choice < w_akademis:
		return "Akademis"
	if choice < w_akademis + w_olahraga:
		return "Olahraga"
	return "SeniBudaya"
```

- [ ] **Step 4 [editor]: `_roll_event`, line-neutral.**
  1. Replace the three uniform picks:

     ```gdscript
     var scene: PackedScene = _variety_picker.pick_this_week("Akademis", akademis_scenes)
     var scene: PackedScene = _variety_picker.pick_this_week("Olahraga", olahraga_scenes)
     var scene: PackedScene = _variety_picker.pick_this_week("SeniBudaya", seni_scenes)
     ```

  2. Type its other ten untyped vars. Use explicit types for anything read from `GameState`, because the hygiene guard rejects `:= GameState.`:
     - `var week: int = GameState.minggu_ke`
     - `var holiday_name: String = …`
     - `var counts: Dictionary = GameState.get_jadwal_for_day(day_name)`
     - `var w_akademis: int`, `w_olahraga: int`, `w_seni: int`
     - `var total_weight := w_normal + w_minigame + w_event`
     - `var outcome := "Normal"`
     - `var roll := randi() % total_weight`
     - `var category_selected := _pick_minigame_category(…)`
  3. Swap `create_timer(1.2)` for `create_timer(HOLIDAY_STATUS_HOLD)` and `create_timer(0.8)` for `create_timer(NORMAL_DAY_HOLD)`.

- [ ] **Step 5 [code]: Measure.** `wc -l Scripts/SchoolSimulation/SchoolDay.gd` should print **1633** (1638 + 6 + 3 − 14). Anything above 1638 is a hard stop: shorten a doc comment, never the tests' pinned strings. Then `git diff HEAD -- '*.gd'` should show only SchoolDay.gd.

- [ ] **Step 6 [editor]: Run the affected suites.**
  - `test_run(suite="minigame_variety_picker")`: now fully green.
  - `test_run(suite="school_day")`, `test_run(suite="event_dialogue")`, `test_run(suite="event_warning")`, `test_run(suite="minigame_weekly_cap")`, `test_run(suite="project_hygiene")`: all still green.
  - `test_run(suite="clean_code")`: expect **shrank**. `LARGE_SCRIPTS` 1638→1633, `UNTYPED` 78→62 (13 in `_roll_event`, 3 in `_pick_minigame_category`), `BARE_NUMBERS` 54→50 (`% 3` twice, `1.2`, `0.8`).

- [ ] **Step 7 [code]: Lock the shrink.** Run
  `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd`
  (no `--rekey`: nothing moved). `git diff ci/clean_code_baseline.gd` must show exactly the three SchoolDay numbers going down. **[editor]** Do a no-op `script_patch` on `ci/clean_code_baseline.gd`, then `test_run(suite="clean_code")` should be green.

- [ ] **Step 8 [editor]: Smoke.** Seed, put every student on SeniBudaya in AturJadwal, and run SchoolDay. No seni variant may play twice in a row within a week. After a few weeks, `game_manage` eval `GameState.run_stats.variant_plays` should show both SeniBudaya variants. `logs_read(source="game")` should be clean.

- [ ] **Step 9 [code]: Commit** `Scripts/SchoolSimulation/SchoolDay.gd` and `ci/clean_code_baseline.gd`:
  `feat(school-day): roll minigame variants through the variety picker`.

---

### Task 6: Docs, full run, ship

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `CLAUDE.md` (the test-count line), and `docs/superpowers/DEBT.md` only if Task 2 left the Menari cause open.

- [ ] **Step 1 [code]: CHANGELOG.** Add a new entry at the top (newest first): `## 2026-MM-DD — Minigame variety picker`. Cover:
  - what the picker guarantees (the three rules and their consts);
  - where the state lives (the cooldown per SchoolDay/week, the counts on `RunStats`, reset at every grade boundary);
  - Task 2's finding: the root cause and fix, or "not reproduced" with the evidence;
  - the new suites `minigame_variants_reachable` and `minigame_variety_picker`;
  - the ratchet diff (SchoolDay 1638→1633 lines, untyped 78→62, bare numbers 54→50).

- [ ] **Step 2 [code]: DEBT.** If Task 2 found no cause, add one grouped entry under the minigame debt: "LombaMenari absence not reproduced (date); picker's safety net mitigates; reopen on a new report with a log". Otherwise DEBT gets nothing. Nothing existing is resolved by this PR.

- [ ] **Step 3 [editor]: Full run.** Restart the editor for a fresh state, open `Scenes/MainMenu/MainMenu.tscn`, then `test_run()` with no suite. Budget one more restart, because the full run drops the bridge. Every suite must be green. Re-run any lone theme-assertion failure on its own before believing it (suite order).

- [ ] **Step 4 [code]: CLAUDE.md count.** Update `Testing`'s "161 suites, 2406 tests (2026-09-27)" to the full run's totals and today's date. There should be two more suites than `Textures` had when this branch forked. That is the only CLAUDE.md change: the pass itself goes in the CHANGELOG.

- [ ] **Step 5 [code]: Clean tree.** `git status`. `git checkout --` the `kejartes_theme.tres` rebake and the `default_bus_layout.tres` rewrite, unless intended. Leave the untracked `addons/godot_ai/utils/update_activation_runner.gd` alone. `git branch --show-current` should be the feature branch.

- [ ] **Step 6 [code]: Commit** `CHANGELOG.md`, `CLAUDE.md` and, if touched, `DEBT.md`:
  `docs(minigame): changelog and test count for the variety picker`.

- [ ] **Step 7: Ship.** Run the `ship-pr` skill. It re-runs the full suite and a local review, opens the PR against `Textures`, and stamps the tested commit. Right after `gh pr create`, `bind_pr` and `set_monitor`. The PR description names the picker's consts as ours, not Balance's, and offers to move them into `Balance.gd` if the collaborator prefers.

## Done when

- `minigame_variants_reachable`, `run_stats`, `minigame_variety_picker`, `school_day`, `event_dialogue`, `event_warning`, `minigame_weekly_cap`, `project_hygiene` and `clean_code` are green, and so is the full run.
- The LombaMenari root cause is fixed, or its non-reproduction is recorded in the CHANGELOG (and DEBT).
- `SchoolDay.gd` is 1633 lines or fewer, and `ci/clean_code_baseline.gd` shows only lowered SchoolDay numbers.
- The manual smoke passes: no back-to-back variant within a week, and both seni variants appear over a few seeded weeks.
- `Scripts/Balance.gd` and `Scripts/GameState.gd` are unchanged.
