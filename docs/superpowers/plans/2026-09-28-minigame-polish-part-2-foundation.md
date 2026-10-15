# Minigame Polish Part 2 — Foundation (Depth Kit + Shared HUD) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared Depth Kit (combo tracker, multiplier curve, hit-quality
grading, score→star helper) and the shared HUD (score pill, combo meter, grade
popup, float text) that every KejarTes minigame will plug into for Part 2.

**Architecture:** Approach C — pure-logic primitives live on/near `BaseMinigame`
so any subclass opts in via `register_hit(quality)`; all visuals are authored
`ThemeFactory` variations + reusable `.tscn` nodes, never runtime-built. This
plan covers **only the foundation (spec Phases 1–2)**; per-game wiring (Phases
3–8), motion polish (Phase 9), and the Balance proposal (Phase P) are separate
plans written when reached.

**Tech Stack:** Godot 4.6, GDScript; `McpTestSuite` tests run in-editor via the
Godot AI MCP `test_run` tool; `ThemeFactory` + `DesignTokens` design system.

**Spec:** `docs/superpowers/specs/2026-09-28-minigame-polish-part-2-design.md`
(read it alongside this plan — the plan argues from it).

## Global Constraints

- **Godot 4.6**, portrait mobile; every screen must fill a 20:9 phone (verify on
  the 16:9 embedded run too — vertical crowding is the top risk).
- **No `theme_override_*`** anywhere — use a `ThemeFactory` type variation and
  rebake; only layout-only `separation`/`margin_*` constant overrides are allowed.
- **No runtime-built visuals** beyond the `tests/test_viewport_editability.gd`
  ratchet (`BASELINE` only ever lowers; reviewed exceptions go in `ALLOWED` with
  a comment). Static chrome = nodes in `.tscn`; repeated rows = a `PackedScene`.
- **Every script** gets a `##` file header and a `##` line on every `@export`
  (`tests/test_script_documentation.gd`).
- **All UI text Indonesian**; **no emoji as iconography** — real transparent SVG
  textures only.
- **Never edit `Balance.gd`.** New tunables of ours go in a named `const` block
  or `@export` in the owning script (like `RunGrade.gd`'s `WEIGHT_*`). The actual
  multiplier/threshold numbers are placeholders here pending the Balance-owner
  proposal (spec §4.5).
- **Tests:** suites extend `McpTestSuite`, are `@tool`, contain **no coroutines**
  (no `await`), and run via MCP `test_run`. Scripts instantiated live are `@tool`
  with real `_ready()` side effects gated behind `if Engine.is_editor_hint(): return`.
- **Editor/build hazards:** edit `.tscn` only through the editor (`scene_open` →
  `node_*`/`batch_execute` → `scene_save`); do scene work before script work;
  rescan after editing a `.gd` before `test_run`; a full run rebakes
  `kejartes_theme.tres` and rewrites `default_bus_layout.tres` — `git status`
  after and `git checkout --` what you didn't intend. Prefer targeted
  `test_run(suite=…)`.

---

## File Structure

- `Scripts/Minigames/UI/ComboTracker.gd` **(create)** — pure-logic `RefCounted`:
  combo count, best combo, multiplier from a documented curve. No engine deps,
  fully unit-testable.
- `Scripts/Minigames/UI/MinigameScoring.gd` **(create)** — static helpers: the
  score→star mastery ratio and the shared star cut points. Preloaded, not an
  autoload.
- `Scripts/Minigames/UI/BaseMinigame.gd` **(modify)** — add `HitQuality` enum,
  hold a `ComboTracker`, add `register_hit()`, the three signals, and route the
  existing `get_star_ratio()` default through `MinigameScoring`.
- `Scripts/Design/ThemeFactory.gd` **(modify)** — add `MinigameScorePill`,
  `MinigameComboMeter`, `MinigameGradePopup`, `MinigameFloatText` variations.
- `Scenes/Minigames/UI/ScorePill.tscn` + `Scripts/Minigames/UI/ScorePill.gd`
  **(create)** — authored fused score+multiplier pill with odometer digit nodes
  and a float spawn point; `@export`s on the **root**.
- `Scenes/Minigames/UI/ComboMeter.tscn` + `Scripts/Minigames/UI/ComboMeter.gd`
  **(create)** — authored combo bar + label plank; `@export`s on the root.
- `tests/test_combo_tracker.gd` **(create)** — behavioural unit tests.
- `tests/test_minigame_scoring.gd` **(create)** — behavioural unit tests.
- `tests/test_minigame_depth_kit.gd` **(create)** — `BaseMinigame` integration +
  source-scans for the HUD scenes/scripts.
- `tests/test_theme_factory.gd` **(modify)** — pin the four new variations and
  their `DISPLAY_ROSTER` font assignments.

---

## Task 1: ComboTracker (pure logic)

**Files:**
- Create: `Scripts/Minigames/UI/ComboTracker.gd`
- Test: `tests/test_combo_tracker.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class_name ComboTracker` (extends `RefCounted`).
  - `const MULT_PER_COMBO := 0.25` (placeholder, ours), `const MULT_CAP := 4.0`.
  - `var combo: int`, `var best: int`.
  - `func register(hit: bool) -> void` — `hit==true` increments combo and updates
    `best`; `hit==false` resets combo to 0.
  - `func multiplier() -> float` — `clampf(1.0 + combo * MULT_PER_COMBO, 1.0, MULT_CAP)`.
  - `func reset() -> void` — combo and best back to 0.

- [ ] **Step 1: Write the failing test**

```gdscript
@tool
extends McpTestSuite

const ComboTracker := preload("res://Scripts/Minigames/UI/ComboTracker.gd")

func test_hit_increments_combo_and_multiplier() -> void:
    var c := ComboTracker.new()
    assert_eq(c.multiplier(), 1.0, "starts at x1")
    c.register(true)
    c.register(true)
    assert_eq(c.combo, 2, "two hits -> combo 2")
    assert_eq(c.multiplier(), 1.5, "x1 + 2*0.25 = x1.5")

func test_miss_resets_combo_but_keeps_best() -> void:
    var c := ComboTracker.new()
    c.register(true); c.register(true); c.register(true)
    assert_eq(c.best, 3, "best tracks the peak")
    c.register(false)
    assert_eq(c.combo, 0, "miss resets combo")
    assert_eq(c.multiplier(), 1.0, "multiplier back to x1")
    assert_eq(c.best, 3, "best is unchanged by a miss")

func test_multiplier_is_capped() -> void:
    var c := ComboTracker.new()
    for i in range(50): c.register(true)
    assert_eq(c.multiplier(), 4.0, "multiplier clamps at MULT_CAP")
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run(suite="test_combo_tracker")`. Expected: FAIL (ComboTracker script missing / parse error).

- [ ] **Step 3: Write minimal implementation**

```gdscript
@tool
extends RefCounted
class_name ComboTracker

## Pure-logic combo/streak tracker shared by every Part 2 minigame.
## Owns the running combo, the best combo this round, and the score multiplier
## derived from a documented curve. No engine dependencies -- unit-testable.
## Not an autoload; instance one per minigame. Numbers here are OUR placeholders
## pending the Balance-owner proposal (see the Part 2 spec section 4.5).

## Multiplier gained per point of combo.
const MULT_PER_COMBO := 0.25
## Hard ceiling on the multiplier.
const MULT_CAP := 4.0

## Current unbroken combo.
var combo: int = 0
## Highest combo reached this round.
var best: int = 0

## Advance on a hit, reset to zero on a miss.
func register(hit: bool) -> void:
    if hit:
        combo += 1
        best = max(best, combo)
    else:
        combo = 0

## The current score multiplier, clamped to [1.0, MULT_CAP].
func multiplier() -> float:
    return clampf(1.0 + combo * MULT_PER_COMBO, 1.0, MULT_CAP)

## Clear combo and best (new round).
func reset() -> void:
    combo = 0
    best = 0
```

- [ ] **Step 4: Run test to verify it passes**

Rescan (`filesystem_manage(op="scan")`), then `test_run(suite="test_combo_tracker")`. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/UI/ComboTracker.gd tests/test_combo_tracker.gd
git commit -m "feat(minigames): ComboTracker pure-logic streak/multiplier primitive"
```

---

## Task 2: MinigameScoring (score→star helper)

**Files:**
- Create: `Scripts/Minigames/UI/MinigameScoring.gd`
- Test: `tests/test_minigame_scoring.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class_name MinigameScoring` (extends `RefCounted`), static functions only.
  - `const STAR_RATIO_3 := 0.9`, `const STAR_RATIO_2 := 0.6` (ours, placeholder).
  - `static func mastery_ratio(score: int, max_score: int) -> float` —
    `0.0` when `max_score <= 0`, else `clampf(score/max_score, 0, 1)`.
  - `static func stars_for_ratio(ratio: float) -> int` — 3 at `>=STAR_RATIO_3`,
    2 at `>=STAR_RATIO_2`, else 1.

- [ ] **Step 1: Write the failing test**

```gdscript
@tool
extends McpTestSuite

const S := preload("res://Scripts/Minigames/UI/MinigameScoring.gd")

func test_mastery_ratio_guards_zero_max() -> void:
    assert_eq(S.mastery_ratio(5, 0), 0.0, "no divide-by-zero")
    assert_eq(S.mastery_ratio(3, 6), 0.5, "half mastery")
    assert_eq(S.mastery_ratio(99, 6), 1.0, "clamped to 1.0")

func test_stars_cut_points() -> void:
    assert_eq(S.stars_for_ratio(0.95), 3, "0.9+ -> 3 stars")
    assert_eq(S.stars_for_ratio(0.7), 2, "0.6+ -> 2 stars")
    assert_eq(S.stars_for_ratio(0.3), 1, "below -> 1 star")
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run(suite="test_minigame_scoring")`. Expected: FAIL (script missing).

- [ ] **Step 3: Write minimal implementation**

```gdscript
@tool
extends RefCounted
class_name MinigameScoring

## Shared score->star mapping for every Part 2 minigame, so mastery reads
## consistently across games. Static functions only; preload it, not an autoload.
## Cut points are OUR placeholders pending the Balance-owner proposal (spec 4.5).

## Mastery at or above which a win earns three stars.
const STAR_RATIO_3 := 0.9
## Mastery at or above which a win earns two stars.
const STAR_RATIO_2 := 0.6

## Accumulated score as a fraction of the round's max, clamped to [0,1].
## Returns 0.0 when max_score is unknown/zero.
static func mastery_ratio(score: int, max_score: int) -> float:
    if max_score <= 0:
        return 0.0
    return clampf(float(score) / float(max_score), 0.0, 1.0)

## Turn a mastery ratio into a 1-3 star count.
static func stars_for_ratio(ratio: float) -> int:
    if ratio >= STAR_RATIO_3:
        return 3
    if ratio >= STAR_RATIO_2:
        return 2
    return 1
```

- [ ] **Step 4: Run test to verify it passes**

Rescan, then `test_run(suite="test_minigame_scoring")`. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/UI/MinigameScoring.gd tests/test_minigame_scoring.gd
git commit -m "feat(minigames): MinigameScoring shared score->star helper"
```

---

## Task 3: BaseMinigame depth integration

**Files:**
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd`
- Test: `tests/test_minigame_depth_kit.gd`

**Interfaces:**
- Consumes: `ComboTracker` (Task 1), `MinigameScoring` (Task 2).
- Produces (on `BaseMinigame`):
  - `enum HitQuality { MISS, GOOD, PERFECT }`.
  - `const POINTS_GOOD := 15`, `const POINTS_PERFECT := 30` (ours, placeholder).
  - `var combo_tracker: ComboTracker` (created in `_ready`, ungated so tests can
    exercise it).
  - `signal hit_registered(quality: int, points: int)`,
    `signal combo_changed(combo: int, mult: float)`, `signal combo_broken()`.
  - `func register_hit(quality: int) -> int` — MISS breaks the combo (emits
    `combo_broken`) and returns 0; GOOD/PERFECT advance it, award
    `round(base * multiplier())` where base is `POINTS_GOOD`/`POINTS_PERFECT`,
    add to `score` (if the subclass has one), emit `hit_registered` and
    `combo_changed`, and return the points.
  - `func stars_from_score(score: int, max_score: int) -> int` — delegates to
    `MinigameScoring`.

- [ ] **Step 1: Write the failing test**

```gdscript
@tool
extends McpTestSuite

const Base := preload("res://Scripts/Minigames/UI/BaseMinigame.gd")

func test_register_hit_awards_and_tracks() -> void:
    var g = Base.new()
    g.score = 0
    var p1 = g.register_hit(Base.HitQuality.PERFECT)  # combo 1, x1.0
    assert_eq(p1, 30, "first perfect = 30 * x1.0")
    var p2 = g.register_hit(Base.HitQuality.PERFECT)  # combo 2, x1.25
    assert_eq(p2, 38, "second perfect = round(30 * 1.25)")
    assert_eq(g.score, 68, "score accumulates")
    g.free()

func test_miss_breaks_combo() -> void:
    var g = Base.new()
    g.score = 0
    g.register_hit(Base.HitQuality.GOOD)
    var got_broken := [false]
    g.combo_broken.connect(func(): got_broken[0] = true)
    var p = g.register_hit(Base.HitQuality.MISS)
    assert_eq(p, 0, "miss scores nothing")
    assert_true(got_broken[0], "combo_broken emitted")
    assert_eq(g.combo_tracker.combo, 0, "combo reset")
    g.free()

func test_stars_delegate() -> void:
    var g = Base.new()
    assert_eq(g.stars_from_score(6, 6), 3, "full score -> 3 stars")
    g.free()

func test_hud_scenes_exist_and_are_authored() -> void:
    # Source-scan: the reusable HUD lives in .tscn, not built at runtime.
    assert_true(FileAccess.file_exists("res://Scenes/Minigames/UI/ScorePill.tscn"), "ScorePill.tscn exists")
    assert_true(FileAccess.file_exists("res://Scenes/Minigames/UI/ComboMeter.tscn"), "ComboMeter.tscn exists")
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run(suite="test_minigame_depth_kit")`. Expected: FAIL (`register_hit` / `HitQuality` missing; scenes missing).

- [ ] **Step 3: Write minimal implementation**

Add near the top of `BaseMinigame.gd` (after the existing `signal minigame_won` block):

```gdscript
## Quality of a single scored action, shared by every minigame's hit moment.
enum HitQuality { MISS, GOOD, PERFECT }

## Base points before the combo multiplier. OUR placeholders (Balance owns
## the final numbers -- see the Part 2 spec 4.5).
const POINTS_GOOD := 15
const POINTS_PERFECT := 30

## Emitted for every scored action, carrying its quality and awarded points.
signal hit_registered(quality: int, points: int)
## Emitted whenever the combo count or multiplier changes.
signal combo_changed(combo: int, mult: float)
## Emitted when a miss breaks the current combo.
signal combo_broken()

## The shared streak/multiplier tracker for this minigame.
var combo_tracker := ComboTracker.new()
```

Add these methods to `BaseMinigame.gd`:

```gdscript
## Register one scored action. MISS breaks the combo and scores nothing;
## GOOD/PERFECT advance it and award base points times the current multiplier.
## Returns the points awarded (0 on a miss).
func register_hit(quality: int) -> int:
    if quality == HitQuality.MISS:
        combo_tracker.register(false)
        combo_broken.emit()
        combo_changed.emit(combo_tracker.combo, combo_tracker.multiplier())
        hit_registered.emit(quality, 0)
        return 0
    combo_tracker.register(true)
    var base := POINTS_PERFECT if quality == HitQuality.PERFECT else POINTS_GOOD
    var pts := int(round(base * combo_tracker.multiplier()))
    if "score" in self:
        self.score += pts
    combo_changed.emit(combo_tracker.combo, combo_tracker.multiplier())
    hit_registered.emit(quality, pts)
    return pts

## Shared score->star mapping (delegates to MinigameScoring).
func stars_from_score(current_score: int, max_score: int) -> int:
    return MinigameScoring.stars_for_ratio(MinigameScoring.mastery_ratio(current_score, max_score))
```

Note: `ComboTracker`, `MinigameScoring` resolve by `class_name`; no preload needed
inside `BaseMinigame`. If the editor has not registered them yet, rescan first.

- [ ] **Step 4: Run test to verify the logic tests pass**

Rescan, then `test_run(suite="test_minigame_depth_kit")`. Expected: the three
logic tests PASS; `test_hud_scenes_exist_and_are_authored` still FAILS (scenes
come in Tasks 5–6). That partial result is expected here.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/UI/BaseMinigame.gd tests/test_minigame_depth_kit.gd
git commit -m "feat(minigames): Depth Kit on BaseMinigame (HitQuality, register_hit, signals)"
```

---

## Task 4: ThemeFactory variations for the HUD

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`
- Modify: `tests/test_theme_factory.gd`
- Rebake: run `Scripts/Design/BakeTheme.gd` (File > Run) → writes
  `Assets/Theme/kejartes_theme.tres`.

**Interfaces:**
- Produces four new type variations registered in `ThemeFactory`:
  `MinigameScorePill`, `MinigameComboMeter`, `MinigameGradePopup`,
  `MinigameFloatText`, each drawing colours/radii from `DesignTokens` (wood-brown
  fill, cream rim, gold `font_display` text) — no literals.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_theme_factory.gd` (follow the file's existing assertion style
for a registered variation and its `DISPLAY_ROSTER` entry):

```gdscript
func test_part2_minigame_variations_registered() -> void:
    var src := _read_theme_factory_source()  # existing helper in this suite
    for v in ["MinigameScorePill", "MinigameComboMeter", "MinigameGradePopup", "MinigameFloatText"]:
        assert_true(src.contains(v), "ThemeFactory defines %s" % v)
```

Also add each display-font-bearing variation to `DISPLAY_ROSTER` per the file's
existing convention (score pill, grade popup and float text use `font_display`).

- [ ] **Step 2: Run test to verify it fails**

Run `test_run(suite="test_theme_factory")`. Expected: FAIL (variations absent /
`DISPLAY_ROSTER` mismatch).

- [ ] **Step 3: Write minimal implementation**

In `ThemeFactory.gd`, add the four variations next to the existing ones, styled
through tokens. Illustrative shape (match the file's real helper names for
`StyleBoxFlat`/label setup):

```gdscript
# --- Part 2 minigame HUD ---
# MinigameScorePill: wood-brown fill, cream rim, gold display numerals.
_add_panel_variation(theme, "MinigameScorePill", {
    "bg": tokens.brandD, "border": tokens.cream_rim, "radius": tokens.radius_pill,
})
_add_label_variation(theme, "MinigameScorePill", tokens.font_display, tokens.gold_text)
# MinigameComboMeter: thin bar panel on brandD with cream rim.
_add_panel_variation(theme, "MinigameComboMeter", {
    "bg": tokens.brandD, "border": tokens.cream_rim, "radius": tokens.radius_sm,
})
# MinigameGradePopup: gold display text, heavy, no box.
_add_label_variation(theme, "MinigameGradePopup", tokens.font_display, tokens.gold_text)
# MinigameFloatText: same family, smaller.
_add_label_variation(theme, "MinigameFloatText", tokens.font_display, tokens.gold_text)
```

Use the **actual** token names present in `DesignTokens.gd` (grep for the nearest
existing ones — e.g. the win-card gold, `brandD`, `radius_*`); do not invent
tokens. If a needed colour has no token, add it to `DesignTokens.gd` and rebake.

- [ ] **Step 4: Rebake, then run tests**

Run `Scripts/Design/BakeTheme.gd` via File > Run to regenerate
`kejartes_theme.tres`. Rescan. Then `test_run(suite="test_theme_factory")`.
Expected: PASS. Check `git status`: stage the intended `kejartes_theme.tres`
change; `git checkout --` `default_bus_layout.tres` if a full run touched it.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(minigames): ThemeFactory variations for the Part 2 HUD"
```

---

## Task 5: ScorePill reusable scene

**Files:**
- Create: `Scripts/Minigames/UI/ScorePill.gd`
- Create: `Scenes/Minigames/UI/ScorePill.tscn` (author in the editor)
- Test: extend `tests/test_minigame_depth_kit.gd`

**Interfaces:**
- Consumes: `MinigameScorePill`, `MinigameFloatText` variations (Task 4).
- Produces:
  - `Scenes/Minigames/UI/ScorePill.tscn` root `ScorePill` (a `Control`) with the
    `MinigameScorePill` variation, authored digit labels for the odometer and a
    `FloatSpawn` marker child.
  - `ScorePill.gd` on the root with `@export var caption: String = "SKOR"` and
    `@export var digit_count: int = 5`, plus:
    - `func set_score(value: int) -> void` — animates the odometer via
      `Juice.count_up` (guarded so headless tests don't require the tween).
    - `func set_multiplier(mult: float, hot: bool) -> void`.
    - `func pop_points(amount: int) -> void` — spawns a float via
      `AnimUtils.create_floating_text` at `FloatSpawn`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_minigame_depth_kit.gd`:

```gdscript
func test_scorepill_root_exports_and_api() -> void:
    var ps := load("res://Scenes/Minigames/UI/ScorePill.tscn")
    assert_not_null(ps, "ScorePill.tscn loads")
    var inst = ps.instantiate()
    assert_true("caption" in inst, "root carries caption @export")
    assert_true("digit_count" in inst, "root carries digit_count @export")
    assert_true(inst.has_method("set_score"), "set_score exists")
    assert_true(inst.has_method("set_multiplier"), "set_multiplier exists")
    assert_true(inst.has_method("pop_points"), "pop_points exists")
    inst.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run(suite="test_minigame_depth_kit")`. Expected: this test FAILS
(scene/script missing).

- [ ] **Step 3: Write the script, then author the scene**

Create `ScorePill.gd` first (documented, `@tool`, side effects gated):

```gdscript
@tool
extends Control
class_name ScorePill

## The shared fused score+multiplier pill (Part 2 score design B+C+D):
## a MinigameScorePill panel holding authored odometer digits, a multiplier
## badge, and a FloatSpawn point for +points floaters. Nothing is built at
## runtime -- this script only drives values and animation.

const Juice := preload("res://Scripts/Design/Juice.gd")
const AnimUtils := preload("res://Scripts/AnimUtils.gd")

## Caption shown before the number (e.g. "SKOR", "GOL").
@export var caption: String = "SKOR"
## How many odometer digit slots to show.
@export var digit_count: int = 5

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    # wire caption label text here from the authored node

## Roll the odometer up to value.
func set_score(value: int) -> void:
    # drive the authored digit nodes; use Juice.count_up on the numeric label
    pass

## Update the multiplier badge; hot=true when >= x2 (glow/scale).
func set_multiplier(mult: float, hot: bool) -> void:
    pass

## Spawn a floating "+amount" from FloatSpawn.
func pop_points(amount: int) -> void:
    pass
```

Then author `ScorePill.tscn` in the editor (`scene_open`/`node_create`/
`node_set_property`/`scene_save`): root `Control` named `ScorePill` with the
`MinigameScorePill` variation, a caption `Label`, the digit `Label`(s), a
multiplier badge `Label`, and a `Marker2D`/`Control` named `FloatSpawn`. Attach
`ScorePill.gd` to the root. Fill in the three method bodies to drive the authored
nodes (no `theme_override_*`; use the variation).

- [ ] **Step 4: Run test to verify it passes**

Rescan, then `test_run(suite="test_minigame_depth_kit")`. Expected: the ScorePill
test PASSES.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/UI/ScorePill.gd Scenes/Minigames/UI/ScorePill.tscn tests/test_minigame_depth_kit.gd
git commit -m "feat(minigames): reusable ScorePill scene (fused pill + odometer + floaters)"
```

---

## Task 6: ComboMeter reusable scene

**Files:**
- Create: `Scripts/Minigames/UI/ComboMeter.gd`
- Create: `Scenes/Minigames/UI/ComboMeter.tscn` (author in the editor)
- Test: extend `tests/test_minigame_depth_kit.gd`

**Interfaces:**
- Consumes: `MinigameComboMeter` variation (Task 4).
- Produces:
  - `Scenes/Minigames/UI/ComboMeter.tscn` root `ComboMeter` (`Control`) with the
    bar + a label plank.
  - `ComboMeter.gd` on the root with `@export var label_prefix: String = "COMBO"`
    and `@export var full_at: int = 8` (combo count that fills the bar), plus
    `func set_combo(combo: int, mult: float) -> void` and `func flash_break() -> void`.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_combometer_root_exports_and_api() -> void:
    var ps := load("res://Scenes/Minigames/UI/ComboMeter.tscn")
    assert_not_null(ps, "ComboMeter.tscn loads")
    var inst = ps.instantiate()
    assert_true("label_prefix" in inst, "root carries label_prefix @export")
    assert_true("full_at" in inst, "root carries full_at @export")
    assert_true(inst.has_method("set_combo"), "set_combo exists")
    assert_true(inst.has_method("flash_break"), "flash_break exists")
    inst.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run(suite="test_minigame_depth_kit")`. Expected: this test FAILS.

- [ ] **Step 3: Write the script, then author the scene**

Create `ComboMeter.gd` (documented, `@tool`, gated `_ready`) with the two
`@export`s on the root and the two methods driving an authored bar fill
(a `TextureProgressBar` or a clipped `Panel` fill honouring
`Assets/Images/UI/BarFill/README.md` if it reuses the bar tiles) and a label
plank. Author `ComboMeter.tscn` in the editor with the `MinigameComboMeter`
variation; attach the script to the root; fill the method bodies.

- [ ] **Step 4: Run test to verify it passes**

Rescan, then `test_run(suite="test_minigame_depth_kit")`. Expected: all tests in
the suite now PASS (including `test_hud_scenes_exist_and_are_authored` from Task 3).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/UI/ComboMeter.gd Scenes/Minigames/UI/ComboMeter.tscn tests/test_minigame_depth_kit.gd
git commit -m "feat(minigames): reusable ComboMeter scene (bar + label plank)"
```

---

## Task 7: Foundation verification + docs

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (newest first)
- Verify: full suite

**Interfaces:** none.

- [ ] **Step 1: Run the foundation suites together**

`test_run(suite="test_combo_tracker")`, `test_run(suite="test_minigame_scoring")`,
`test_run(suite="test_minigame_depth_kit")`, `test_run(suite="test_theme_factory")`.
Expected: all PASS.

- [ ] **Step 2: Run the documentation + ratchet guards**

`test_run(suite="test_script_documentation")` (new scripts must have `##` header +
`##` on every `@export`) and `test_run(suite="test_viewport_editability")`
(BASELINE not raised; any dynamic HUD draw documented in ALLOWED). Expected: PASS.

- [ ] **Step 3: One full run at the milestone**

Take one full `test_run` (budget an editor restart afterward — a full run drops
the bridge). Confirm green. `git status`: stage the intended `kejartes_theme.tres`;
`git checkout --` `default_bus_layout.tres` if untouched by intent.

- [ ] **Step 4: Changelog entry**

Add to the top of `docs/superpowers/CHANGELOG.md`:

```markdown
## Minigame Polish Part 2 — Foundation (Depth Kit + shared HUD)
Shared ComboTracker + MinigameScoring primitives, BaseMinigame HitQuality /
register_hit / combo signals, and reusable ScorePill + ComboMeter scenes with
ThemeFactory variations. Per-game wiring is separate plans.
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/CHANGELOG.md
git commit -m "docs(minigames): changelog for Part 2 foundation"
```

---

## What comes next (separate plans)

This foundation unblocks the per-game phases; each is its own plan written from
the spec when the team reaches it:
- **Phase 3** Quiz family (PilihanGanda ref → Password → Variabel).
- **Phase 4** Menjodohkan blind-lock → reveal cascade.
- **Phase 5** LombaMenari timing grades (+ beat-sync seam).
- **Phase 6** Olahraga (Badminton rally-pot+SMASH, MainBola streak+shrink+bonus-zone).
- **Phase 7** BuatBatik precision opt-out.
- **Phase 8** Password/Variabel/Kalkulator bespoke layouts.
- **Phase 9** Motion polish across all.
- **Phase P** Balance-owner proposal for the real numbers (spec §4.5).

## Self-Review notes

- **Spec coverage:** this plan implements spec §4.1 (Depth Kit logic), §4.2
  (shared HUD variations + reusable scenes), and the §4.7 cross-cutting rules for
  the foundation. §4.3–4.6, §4.4 rhythm, §4.5 Balance, §4.6 layouts are named as
  follow-on plans above — intentional scoping, not gaps.
- **Placeholders:** all numeric tunables are explicitly OUR placeholders pending
  the Balance proposal, called out in code comments — not plan TODOs.
- **Type consistency:** `register_hit`/`HitQuality`/`combo_tracker`/`multiplier`/
  `set_score`/`set_multiplier`/`pop_points`/`set_combo`/`flash_break` names are
  used identically across tasks and the tests that assert them.
