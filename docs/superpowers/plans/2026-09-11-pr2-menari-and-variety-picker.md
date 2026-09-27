# PR2 — Menari Bug + Minigame Variety Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the "LombaMenari never appears" bug and replace pure-random minigame variant picking with a variety-preferring picker (cooldown + weighted unseen + last-2-weeks safety net) so players see every minigame at least once per grade.

**Architecture:** One test that instantiates every minigame variant to catch load/init failures. Root-cause debug of LombaMenari via MCP. Picker refactor lives in `SchoolDay.gd` — one new function `_pick_variant()` replaces three direct `randi() % arr.size()` sites (lines 931, 935, 939). Per-grade state on `GameState`, per-week cooldown on `SchoolDay`.

**Tech Stack:** GDScript 4.6, McpTestSuite. Godot AI MCP for the bug repro.

**Spec:** `docs/superpowers/specs/2026-09-11-balance-and-depth-design.md`, section "PR2 — Menari bug + variety picker".

## Global Constraints

- All new test suites `extends McpTestSuite`, marked `@tool`, no coroutines (`await` inside a test silently aborts it — see CLAUDE.md).
- Scripts the runner instantiates live must be `@tool`; real side effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
- Filesystem edits go through `script_patch` when the editor is attached (see CLAUDE.md "Rescan after editing a `.gd`").
- No `theme_override_*`; runtime visual construction stays ratcheted (this PR should not add any).
- Conventional Commits: `fix(minigame): …`, `feat(school-day): …`, `test(minigame): …`.

---

### Task 1: Reachability test for all 8 minigame variants

**Files:**
- Create: `tests/test_minigame_variants_reachable.gd`

**Interfaces:**
- Consumes: `Scenes/Minigames/Akademis/{Menjodohkan,Variabel,PilihanGanda,Password}.tscn`, `Scenes/Minigames/Olahraga/{MainBola,Badminton}.tscn`, `Scenes/Minigames/SeniBudaya/{BuatBatik,LombaMenari}.tscn`.
- Produces: passing suite `test_minigame_variants_reachable` that instantiates each variant and asserts `is_instance_valid`.

- [ ] **Step 1: Write the failing suite**

```gdscript
@tool
extends McpTestSuite

const VARIANTS := [
    "res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
    "res://Scenes/Minigames/Akademis/Variabel.tscn",
    "res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
    "res://Scenes/Minigames/Akademis/Password.tscn",
    "res://Scenes/Minigames/Olahraga/MainBola.tscn",
    "res://Scenes/Minigames/Olahraga/Badminton.tscn",
    "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn",
    "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
]

func test_every_variant_loads_and_instantiates() -> void:
    for path in VARIANTS:
        var scene: PackedScene = load(path)
        assert_true(scene != null, "load failed: " + path)
        var inst: Node = scene.instantiate()
        assert_true(is_instance_valid(inst), "instantiate failed: " + path)
        assert_true(inst.get_script() != null, "no root script: " + path)
        inst.queue_free()
```

- [ ] **Step 2: Run the suite**

Via MCP: `test_run(suite="test_minigame_variants_reachable")`.

Expected: at least LombaMenari row fails (that is the bug we're chasing). Record the error text in the commit message.

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/test_minigame_variants_reachable.gd
git commit -m "test(minigame): assert every variant instantiates cleanly (fails for LombaMenari)"
```

---

### Task 2: Fix the menari bug

**Files:**
- Modify: whichever file the reachability failure points at — one of `Scripts/Minigames/SeniBudaya/LombaMenari.gd`, `Scenes/Minigames/SeniBudaya/LombaMenari.tscn`, or `Scenes/Minigames/SeniBudaya/DancerRig.tscn`.

**Interfaces:**
- Consumes: bug hypothesis from spec (null fallback, `_ready()` throw, or empty invariant).
- Produces: green `test_minigame_variants_reachable` suite.

- [ ] **Step 1: Reproduce inside the editor**

Via MCP: `project_run` → open the game → F1 debug overlay → Minigames tab → launch LombaMenari directly. Read the failure with `logs_read(source="game")`.

Record the failure. If it's:
- **Null resource fallback:** the `@export lomba_menari_scene` on `SchoolDay.tscn` is unset AND `load()` returned null. Set the `@export` in the scene file.
- **`_ready()` throw:** stack trace names the field. Fix that field (audio bus, texture, rhythm data).
- **Empty invariant:** target_score = 0 or rhythm_patterns empty. Fix the resource.

- [ ] **Step 2: Apply the fix**

Use `script_patch` for `.gd` edits (see CLAUDE.md — no hand-edits while editor attached). Use `node_set_property` for `.tscn` edits.

- [ ] **Step 3: Rerun reachability test**

Via MCP: `test_run(suite="test_minigame_variants_reachable")`. Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix(minigame): LombaMenari now reachable — <one-line root cause>"
```

---

### Task 3: State for the variety picker

**Files:**
- Modify: `Scripts/GameState.gd` — add `variants_played_this_grade` dictionary and reset hook.
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — add `_variant_cooldown` array.

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `GameState.variants_played_this_grade: Dictionary` — `{"Akademis": {"Menjodohkan": int, ...}, "Olahraga": {...}, "SeniBudaya": {...}}`.
  - `GameState.record_variant_played(category: String, variant_name: String) -> void`.
  - `GameState.variant_play_count(category: String, variant_name: String) -> int`.
  - `SchoolDay._variant_cooldown: Array[String]` — reset in `start_simulation()`.

- [ ] **Step 1: Write test for GameState record/count**

Create `tests/test_variant_play_tracking.gd`:

```gdscript
@tool
extends McpTestSuite

func test_record_and_count() -> void:
    GameState.variants_played_this_grade = {}
    GameState.record_variant_played("SeniBudaya", "LombaMenari")
    GameState.record_variant_played("SeniBudaya", "LombaMenari")
    GameState.record_variant_played("SeniBudaya", "BuatBatik")
    assert_eq(GameState.variant_play_count("SeniBudaya", "LombaMenari"), 2)
    assert_eq(GameState.variant_play_count("SeniBudaya", "BuatBatik"), 1)
    assert_eq(GameState.variant_play_count("SeniBudaya", "Nonexistent"), 0)

func test_cleared_on_grade_advance() -> void:
    GameState.variants_played_this_grade = {"Akademis": {"Menjodohkan": 3}}
    GameState.reset_variant_tracking_for_new_grade()
    assert_eq(GameState.variants_played_this_grade, {})
```

Run: `test_run(suite="test_variant_play_tracking")` — expected FAIL (methods missing).

- [ ] **Step 2: Implement in GameState**

Add to `Scripts/GameState.gd`:

```gdscript
var variants_played_this_grade: Dictionary = {}

func record_variant_played(category: String, variant_name: String) -> void:
    if not variants_played_this_grade.has(category):
        variants_played_this_grade[category] = {}
    var current: int = variants_played_this_grade[category].get(variant_name, 0)
    variants_played_this_grade[category][variant_name] = current + 1

func variant_play_count(category: String, variant_name: String) -> int:
    if not variants_played_this_grade.has(category):
        return 0
    return int(variants_played_this_grade[category].get(variant_name, 0))

func reset_variant_tracking_for_new_grade() -> void:
    variants_played_this_grade = {}
```

Wire `reset_variant_tracking_for_new_grade()` into the existing `reset_roster_for_new_grade()` at its end.

- [ ] **Step 3: Add cooldown array on SchoolDay**

In `Scripts/SchoolSimulation/SchoolDay.gd`, near line 129 (where `seni_scenes` is declared):

```gdscript
var _variant_cooldown: Array[String] = []
```

In `start_simulation()` (around line 273), reset it: `_variant_cooldown.clear()`.

- [ ] **Step 4: Run test — expected PASS**

Via MCP: `test_run(suite="test_variant_play_tracking")`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/GameState.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_variant_play_tracking.gd
git commit -m "feat(school-day): track variant play counts per grade for variety picker"
```

---

### Task 4: Variety picker function

**Files:**
- Create: `tests/test_variety_picker.gd`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — add `_pick_variant()`, replace three direct-random sites.

**Interfaces:**
- Consumes: `GameState.variant_play_count`, `_variant_cooldown`.
- Produces: `SchoolDay._pick_variant(category: String, scenes: Array) -> PackedScene`.

- [ ] **Step 1: Write the failing tests**

```gdscript
@tool
extends McpTestSuite

const BATIK := preload("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
const MENARI := preload("res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn")

func _fresh_school_day() -> Node:
    var script := load("res://Scripts/SchoolSimulation/SchoolDay.gd")
    var inst := Node.new()
    inst.set_script(script)
    GameState.variants_played_this_grade = {}
    GameState.current_grade = 7
    GameState.current_week = 1
    return inst

func test_cooldown_prevents_back_to_back_same_variant() -> void:
    var sd = _fresh_school_day()
    var picks: Array[String] = []
    for i in 20:
        var p: PackedScene = sd._pick_variant("SeniBudaya", [BATIK, MENARI])
        picks.append(p.resource_path.get_file())
    for i in range(1, picks.size()):
        assert_neq(picks[i], picks[i-1], "back-to-back at %d" % i)

func test_unseen_variant_preferred() -> void:
    var sd = _fresh_school_day()
    GameState.record_variant_played("SeniBudaya", "BuatBatik")
    var menari_count := 0
    for i in 200:
        var p: PackedScene = sd._pick_variant("SeniBudaya", [BATIK, MENARI])
        if p.resource_path.get_file() == "LombaMenari.tscn":
            menari_count += 1
        # reset cooldown so it doesn't fully dictate
        sd._variant_cooldown.clear()
    assert_true(menari_count >= 130, "unseen bias failed: %d/200" % menari_count)

func test_last_two_weeks_forces_unseen() -> void:
    var sd = _fresh_school_day()
    GameState.current_week = 3  # G7 has 4 weeks, so 3 = second-to-last
    GameState.record_variant_played("SeniBudaya", "BuatBatik")
    for i in 30:
        var p: PackedScene = sd._pick_variant("SeniBudaya", [BATIK, MENARI])
        assert_eq(p.resource_path.get_file(), "LombaMenari.tscn",
                  "safety net should force unseen")
        sd._variant_cooldown.clear()
```

Run: `test_run(suite="test_variety_picker")` — expected FAIL.

- [ ] **Step 2: Implement `_pick_variant()` in `SchoolDay.gd`**

Add after `_pick_minigame_category` (around line 973):

```gdscript
## Picks a specific minigame variant with variety bias. See spec section
## "PR2 — Variety picker".
func _pick_variant(category: String, scenes: Array) -> PackedScene:
    if scenes.is_empty():
        return null

    var candidates: Array = scenes.duplicate()

    # Cooldown filter: exclude variants in the recent-play list.
    candidates = candidates.filter(func(s: PackedScene) -> bool:
        return not _variant_cooldown.has(s.resource_path.get_file()))
    if candidates.is_empty():
        candidates = scenes.duplicate()

    # Last-2-weeks safety net: force unseen variants if any exist.
    var total_weeks := _total_weeks_this_grade()
    if total_weeks - GameState.current_week <= 2:
        var unseen := candidates.filter(func(s: PackedScene) -> bool:
            return GameState.variant_play_count(category,
                s.resource_path.get_file().get_basename()) == 0)
        if not unseen.is_empty():
            candidates = unseen

    # Weighted pick: unseen ×3, seen ×1.
    var weights: Array[int] = []
    var total: int = 0
    for s in candidates:
        var w: int = 1 if GameState.variant_play_count(category,
            s.resource_path.get_file().get_basename()) > 0 else 3
        weights.append(w)
        total += w

    var roll := randi() % total
    var acc: int = 0
    var picked: PackedScene = candidates[0]
    for i in candidates.size():
        acc += weights[i]
        if roll < acc:
            picked = candidates[i]
            break

    # Update state.
    var name_key := picked.resource_path.get_file().get_basename()
    _variant_cooldown.append(picked.resource_path.get_file())
    if _variant_cooldown.size() > 2:
        _variant_cooldown.pop_front()
    GameState.record_variant_played(category, name_key)
    return picked

func _total_weeks_this_grade() -> int:
    match GameState.current_grade:
        7: return Balance.JUMLAH_MINGGU_KELAS_7
        8: return Balance.JUMLAH_MINGGU_KELAS_8
        9: return Balance.JUMLAH_MINGGU_KELAS_9
        _: return 6
```

- [ ] **Step 3: Replace the three direct-random sites**

At `SchoolDay.gd:931`, `:935`, `:939`, replace `arr[randi() % arr.size()]` with `_pick_variant(category, arr)`:

```gdscript
# was: var scene = akademis_scenes[randi() % akademis_scenes.size()]
var scene = _pick_variant("Akademis", akademis_scenes)
# same for olahraga and seni
```

Also update the parallel path at `:1293` inside `skip_to_results()` if it does its own random pick.

- [ ] **Step 4: Run all three suites**

Via MCP:
- `test_run(suite="test_variety_picker")` — expected PASS.
- `test_run(suite="test_minigame_variants_reachable")` — still PASS.
- `test_run(suite="test_school_day")` — should still PASS (if any existing test asserted uniform-random distribution, update it).

- [ ] **Step 5: Commit**

```bash
git add tests/test_variety_picker.gd Scripts/SchoolSimulation/SchoolDay.gd
git commit -m "feat(school-day): variety-preferring minigame picker (cooldown + last-2-weeks safety net)"
```

---

## Done when

- `test_minigame_variants_reachable` green.
- `test_variant_play_tracking` green.
- `test_variety_picker` green.
- `test_school_day` still green.
- Manual smoke via debug overlay: force 8 seni rolls, both variants appear at least twice.
- Nothing in Balance.gd changed (that's PR1's concern).
