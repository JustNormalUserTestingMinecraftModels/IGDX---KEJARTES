# Daily Results Annotated Readout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every element the director circled on the Daily Results mockup
behave the way the annotation says it does — the gold chevron appearing only
on a gain, the needs bars reading the student's real energy and mood, and the
stat track visibly growing by the points earned that day.

**Architecture:** Four of the five annotated elements already have code behind
them; one does not, and one only half does. The chevron is currently pinned
visible in `DaySummaryStatRow.tscn` and never touched by `set_stat()` — Task 1
gates it on the day's delta. The needs bars are written from `StudentData` but
have no behavioral test and paint the scene's baked mockup placeholders when a
student lookup misses — Task 2 covers and fixes that. The stat track already
lands on `current/target` but *snaps* there, so the day's gain is invisible —
Tasks 3–4 give `Juice.fill_bar` a delay (mirroring `Juice.pop_in`) and have
each row rewind to this morning's value and grow back, with the chevron popping
on the same beat. Task 5 confirms all five on a real simulated day.

**Tech Stack:** Godot 4.6, GDScript. `DesignTokens` → `ThemeFactory` →
`BakeTheme` theme pipeline; `Scripts/Design/Juice.gd` for all motion. Tests are
`McpTestSuite` suites run in-editor via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`

## Global Constraints

- Godot **4.6**. Portrait 1080×1920 design space; the Daily Results mockup is
  1:1 with game pixels — **no rescale factor anywhere**.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. The
  only accepted exception is layout-only constant overrides (`separation`,
  `margin_*`). No task here adds a stylebox, so no rebake of
  `Assets/Theme/kejartes_theme.tres` is needed — if you find yourself running
  `Scripts/Design/BakeTheme.gd`, you have gone off-plan.
- **All animation goes through `Scripts/Design/Juice.gd`.** Do not hand-roll a
  `create_tween()` in a screen script; if Juice lacks what you need, extend
  Juice (Task 3 does exactly that).
- Test suites must be `@tool`, and **no test may be a coroutine** — the runner
  calls `suite.call(name)` without awaiting, so an `await` silently aborts the
  test and it reports as "0 assertions". Tween end-states are tested with
  `Tween.custom_step()` via the `_run_and_step` helper, never with `await`.
- `McpTestSuite` has **no `assert_almost_eq`**. Compare floats with
  `assert_true(is_equal_approx(a, b), "...")` or an explicit
  `absf(a - b) <= eps`.
- A scene must be **added to the tree** before its `@onready` vars resolve. Use
  `Engine.get_main_loop().root.add_child(inst)` and `track(inst)` —
  `McpTestSuite`'s own cleanup helper
  (`addons/godot_ai/testing/test_suite.gd:42`) — rather than a bare
  `instantiate()` + `free()` whenever the test calls a method that touches
  `icon`, `track`, `value`, `chevron`, `avatar`, `name_label`, `energy_bar` or
  `mood_bar`.
- The baked theme is assigned explicitly (`inst.theme = load(_THEME_PATH)`)
  before a scene enters the tree; ThemeDB's project-theme fallback does not
  populate under the editor's own root.
- **Rescan before running tests** after editing a `.gd` on disk:
  `filesystem_manage(op="scan")`, or `test_run` serves a stale script.
- Tunable numbers belong in a named `const` block or an `@export`, not inline.
- Game-facing identifiers and UI text are Indonesian; systems code is English.
- Commits use Conventional Commits with a scope, e.g. `feat(day-summary): ...`.

---

## Context an implementer needs

### What the director circled, and where each one stands today

| Colour | Element | Node | Status going in |
|---|---|---|---|
| **Red** | Energy percentage | `DaySummaryStudentRow/EnergyBar` | Written from `student.energy`, but **no test**, and an unknown student leaves the scene's baked `36.0` on screen → **Task 2** |
| **Yellow** | Mood percentage | `DaySummaryStudentRow/MoodBar` | Same, with a baked `82.0` → **Task 2** |
| **Pink** | Up arrow, only on a gain | `DaySummaryStatRow/Chevron` | **Always visible.** `set_stat()` never touches it → **Task 1** |
| **Blue** | `+gained/needed` number | `DaySummaryStatRow/Value` | Correct and tested: `DaySummaryStatRow.format_value()` + `DaySummaryStudentRow._sum_deltas()`. **No task changes it**, and Tasks 1 and 4 both assert it stays put |
| **Orange** | Progress toward the final stat check | `DaySummaryStatRow/Track` | Lands on the right value but **snaps** there, so "increases based on points gained that day" is not visible → **Tasks 3–4** |

### Why the numbers already mean what the annotation says

`+12/65` is the sum of that stat's deltas for that one day over that student's
target for the run. `DaySummaryStudentRow._sum_deltas()` sums the day's changes
per stat and drops anything with no target (energy and mood, deliberately);
`StudentManager.log_stat_change()`
(`Scripts/SchoolSimulation/StudentManager.gd:241`) drops zero deltas at the
source, so a student who only rested legitimately shows `+0` on all three
skills. `65` is `target_akademis1/2/3`. **No code in this plan changes the
number.**

The track's fill is `current / target`, where `current` is the student's
standing stat. By the time `DaySummaryPopup.setup_summary()` runs, the day's
effects have already been applied to the live `StudentData` resources
(`SchoolDay._show_day_summary()` at `Scripts/SchoolSimulation/SchoolDay.gd:678`
runs after the simulation), so `current` **already includes** today's gain.
That is why the animation in Task 4 rewinds to `current - delta` rather than
forward from anything.

### The naming trap

`target_akademis2` is the **Seni Budaya** target and `target_akademis3` the
**Olahraga** one. `DaySummaryStudentRow.TARGET_FOR` already encodes this and
has a test guarding it. Do not "fix" it. Note also that the theme variation
names are PascalCase without an underscore (`DaySummaryStatTrackSeniBudaya`)
while the stat key has one (`seni_budaya`) — both spellings are correct in
their place.

### Why there is no down-arrow

`Assets/Images/DaySummary/` ships exactly one chevron, `icon_chevron_up.png`.
The annotation says the arrow "only pops up when points gained", so a stat that
lost points shows **no arrow** rather than a rotated one. Do not add art.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/SchoolSimulation/DaySummaryStatRow.gd` | One `[icon][chevron][track][+N/T]` row: formats the number, drives the track and the chevron | Modify: chevron gating (T1), rewind-and-grow (T4) |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | One student's card: name, avatar, two needs bars, three stat rows | Modify: needs-bar assignment (T2), `play_gain` fan-out (T4) |
| `Scripts/SchoolSimulation/DaySummaryPopup.gd` | Builds the card stack and runs its entrance | Modify: replay each card's gain after the cards land (T4) |
| `Scripts/Design/Juice.gd` | The project's motion vocabulary | Modify: `fill_bar` gains an optional `delay` (T3) |
| `tests/test_day_summary.gd` | The suite for this screen | Modify: chevron, needs-bar and gain-replay tests |
| `tests/test_juice.gd` | The suite for the motion vocabulary | Modify: two tests for the new `delay` |
| `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md` | The mockup spec | Modify: record the chevron condition and the fill motion |

No new files. No new art, no new tokens, no theme rebake.

---

### Task 1: The gold chevron appears only when a stat gained

The chevron is baked visible in the scene and `set_stat()` never touches it, so
it currently claims progress on a day where a stat did not move — or went
backwards. This is the one element the director circled that has no code behind
it at all.

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd:59-71` (add a helper after `track_ratio`, add one line to `set_stat`)
- Modify: `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md` (the glyph table's chevron row)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryStatRow.set_stat(stat_key, delta, target, current)` and
  `@onready var chevron: TextureRect` — both already exist, neither changes
  shape.
- Produces: `DaySummaryStatRow.shows_chevron(delta: float) -> bool` — static,
  callable without an instance. Task 4 reads `chevron.visible` (set from it) to
  decide whether to pop the arrow.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_day_summary.gd`, immediately after the existing
`test_set_stat_fills_the_track_and_leaves_the_number_alone` (around line 344):

```gdscript
## The mockup's gold arrow is an UP arrow and the asset folder ships no
## down variant, so it may only appear on a genuine gain. A stat that did
## not move (+0) or went backwards leaves the track bare rather than
## claiming progress the student did not make.
func test_shows_chevron_only_on_a_gain() -> void:
	assert_true(DaySummaryStatRow.shows_chevron(12.0),
		"a +12 day must show the up arrow")
	assert_true(DaySummaryStatRow.shows_chevron(0.4),
		"any positive gain, however small, must show the arrow")
	assert_false(DaySummaryStatRow.shows_chevron(0.0),
		"a +0 day must not show an up arrow")
	assert_false(DaySummaryStatRow.shows_chevron(-3.0),
		"a losing day must not show an UP arrow -- there is no down asset")


## The gate has to be wired into set_stat, not just available as a
## helper. Three live rows, one per case, because set_stat writes the
## visibility and nothing resets it between calls.
func test_set_stat_gates_the_chevron_on_the_days_delta() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene

	var gained := scene.instantiate()
	gained.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(gained)
	track(gained)
	gained.set_stat("akademis", 12.0, 65.0, 40.0)
	assert_true(gained.chevron.visible, "a +12 row must show its chevron")
	assert_eq(gained.value.text, "+12/65",
		"gating the chevron must not disturb the number")

	var flat := scene.instantiate()
	flat.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(flat)
	track(flat)
	flat.set_stat("seni_budaya", 0.0, 65.0, 40.0)
	assert_false(flat.chevron.visible, "a +0 row must hide its chevron")
	assert_eq(flat.value.text, "+0/65",
		"a +0 row still shows its number -- only the arrow goes")

	var lost := scene.instantiate()
	lost.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(lost)
	track(lost)
	lost.set_stat("olahraga", -3.0, 65.0, 40.0)
	assert_false(lost.chevron.visible, "a losing row must hide its chevron")
	assert_eq(lost.value.text, "-3/65",
		"a loss still reads -3/65, as format_value already guarantees")
```

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: both new tests FAIL — `test_shows_chevron_only_on_a_gain` with a
"Nonexistent function 'shows_chevron'" error, and
`test_set_stat_gates_the_chevron_on_the_days_delta` on the
`flat.chevron.visible` assertion, because the scene ships the chevron visible
and nothing turns it off.

- [ ] **Step 3: Add the helper and wire it into `set_stat`**

In `Scripts/SchoolSimulation/DaySummaryStatRow.gd`, add the helper immediately
after `track_ratio` (which ends at line 62):

```gdscript
## Whether the gold chevron shows for this day's movement. The asset is
## an UP arrow and there is no down variant, so it appears only on a real
## gain -- a stat that did not move, or that lost ground, shows the bare
## track instead of an arrow pointing the wrong way.
##
## The chevron is an absolutely-anchored overlay on the track, so hiding
## it reflows nothing: the icon and the number stay exactly where they are.
static func shows_chevron(delta: float) -> bool:
	return delta > 0.0
```

Then replace `set_stat` entirely:

```gdscript
func set_stat(stat_key: String, delta: float, target: float, current: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	if TRACK_VARIATION_FOR.has(stat_key):
		track.theme_type_variation = TRACK_VARIATION_FOR[stat_key]
	value.text = format_value(delta, target)
	track.value = track_ratio(current, target)
	chevron.visible = shows_chevron(delta)
```

Also extend the file's leading doc comment (line 6) so it stops describing the
chevron as unconditional. Replace:

```gdscript
## One line of the Daily Results card: a white stat icon and a gold
## chevron sitting ON TOP of a dark track, with "+12/65" right-aligned
## on the card fill beside it.
```

with:

```gdscript
## One line of the Daily Results card: a white stat icon and a gold
## chevron sitting ON TOP of a dark track, with "+12/65" right-aligned
## on the card fill beside it. The chevron shows only on a day that
## actually gained points for this stat -- see shows_chevron.
```

- [ ] **Step 4: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: the whole `day_summary` suite PASSES, including both new tests.
`test_stat_row_scene_wears_the_theme_and_has_no_overrides` still passes — it
asserts the `Chevron` node **exists**, not that it is visible, and the scene
file is unchanged.

- [ ] **Step 5: Record the condition in the spec**

In `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`, in the
"Glyphs, icons and text — not surfaces" table, replace the chevron row:

```markdown
| Gold chevron (×3) | ~683,93 · ~40×58 | `#E4B012` | drawn **on top** of the track, right of the icon |
```

with:

```markdown
| Gold chevron (×3) | ~683,93 · ~40×58 | `#E4B012` | drawn **on top** of the track, right of the icon; **visible only when that stat gained points that day** (delta > 0). Hidden at +0 and on a loss — the asset is an up arrow and there is no down variant. Absolutely anchored, so hiding it reflows nothing. |
```

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd tests/test_day_summary.gd docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md
git commit -m "feat(day-summary): show the gain chevron only when a stat gained"
```

---

### Task 2: The needs bars read the student's real energy and mood

The two bars the director circled red and yellow are written from `StudentData`
but have never been asserted behaviorally — the only existing test checks which
variation they wear and which sits on top. They also keep the scene's baked
mockup placeholders (`36.0` and `82.0`) when the popup's name lookup misses,
which paints a confident and completely fabricated reading.

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd:34-41` (`setup_row`'s needs-bar block)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `StudentData.energy` and `.mood`, both `float`, both 0–100
  (`Scripts/SchoolSimulation/StudentData.gd:13-14`).
- Produces: no new symbol. `DaySummaryStudentRow.setup_row(student_name,
  changes, student)` keeps its exact signature; only its behavior on
  `student == null` changes.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_day_summary.gd`, immediately after the existing
`test_energy_is_the_top_bar_and_mood_the_bottom` (around line 419):

```gdscript
## The two bars the mockup annotates red and yellow. Both are 0-100
## scales, so `value` IS the percentage and no conversion is involved --
## the assertion on max_value pins that, because a later scene edit that
## rescaled the bar would silently turn 21 energy into 21% of something
## else.
##
## The values below are deliberately NOT the scene's baked 36/82: those
## are the mockup's placeholders, and a test using them would pass even
## if the assignment were deleted entirely.
func test_setup_row_writes_the_students_real_energy_and_mood() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 21.0
	s.mood = 64.0
	inst.setup_row("Marcel", [], s)

	assert_true(is_equal_approx(inst.energy_bar.max_value, 100.0),
		"energy bar must stay a 0-100 scale so `value` IS the percentage")
	assert_true(is_equal_approx(inst.mood_bar.max_value, 100.0),
		"mood bar must stay a 0-100 scale so `value` IS the percentage")
	assert_true(is_equal_approx(inst.energy_bar.value, 21.0),
		"energy bar must read the student's energy, not the scene placeholder")
	assert_true(is_equal_approx(inst.mood_bar.value, 64.0),
		"mood bar must read the student's mood, not the scene placeholder")
	assert_eq(inst.name_label.text, "Marcel",
		"the card must be labelled with the student it was built for")


## The popup looks each student up by name and passes null when the
## lookup misses. Leaving the scene's baked 36/82 there would paint a
## confident, fabricated reading of a student we could not find; empty
## bars are the honest answer, and they match the avatar, which already
## clears its texture on null.
func test_setup_row_empties_the_needs_bars_for_an_unknown_student() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.setup_row("Nobody", [], null)

	assert_true(is_equal_approx(inst.energy_bar.value, 0.0),
		"an unknown student must not inherit the mockup's 36% energy")
	assert_true(is_equal_approx(inst.mood_bar.value, 0.0),
		"an unknown student must not inherit the mockup's 82% mood")
```

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: `test_setup_row_writes_the_students_real_energy_and_mood` PASSES
already (the assignment exists — this test is the coverage the element was
missing), and `test_setup_row_empties_the_needs_bars_for_an_unknown_student`
FAILS with energy `36.0` where `0.0` was expected.

If the first test fails too, the `@onready` vars did not resolve — confirm the
instance was added to the tree before `setup_row` was called.

- [ ] **Step 3: Make an unknown student read empty**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, in `setup_row`, replace:

```gdscript
	if student != null:
		energy_bar.value = student.energy
		mood_bar.value = student.mood
```

with:

```gdscript
	# The scene ships the mockup's 36/82 placeholders baked in. Leaving
	# them when the popup's name lookup misses would paint a confident,
	# fabricated reading, so an unknown student empties both bars --
	# matching the avatar, which already clears its texture on null.
	energy_bar.value = student.energy if student != null else 0.0
	mood_bar.value = student.mood if student != null else 0.0
```

- [ ] **Step 4: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: the whole `day_summary` suite PASSES, including both new tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd
git commit -m "fix(day-summary): empty the needs bars when the student lookup misses"
```

---

### Task 3: Give `Juice.fill_bar` an optional delay

Task 4 needs three bars on a card, and several cards in a stack, to fill on
their own beats rather than all at once behind a still-fading stack. `Juice` is
the only place motion may be built in this project, and `Juice.pop_in` already
takes a `delay` — `fill_bar` gains the same parameter so callers never
hand-roll a timer. This is a separate task because it changes a shared motion
primitive with its own suite, and a reviewer should be able to accept or reject
it on its own.

**Files:**
- Modify: `Scripts/Design/Juice.gd:110-125` (the `fill_bar` doc comment and body)
- Test: `tests/test_juice.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Juice.fill_bar(bar: Range, to: float, duration: float = -1.0,
  delay: float = 0.0) -> Tween`. The `delay` is **appended**, so all nine
  existing call sites (`SchoolDay.gd:307,330,1157`, `ResultCheckup.gd:378`,
  `DailyDecayOverview.gd:182,188`, `EventStudentSelectDialog.gd:386,396`,
  `StatBar.gd:77`) keep working untouched. Task 4 passes `-1.0` for `duration`
  to reach it.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_juice.gd`, immediately after the existing
`test_fill_bar_lands_on_the_target_value` (around line 118):

```gdscript
## A delayed fill must sit perfectly still while the delay runs. Stepping
## 0.20s into a 0.30s delay is the whole assertion -- if set_delay were
## dropped, the bar would already be most of the way to 80 by then.
func test_fill_bar_does_not_move_during_its_delay() -> void:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	_root.add_child(bar)
	_run_and_step(func(): Juice.fill_bar(bar, 80.0, -1.0, 0.30), 0.20)
	assert_true(absf(bar.value) <= 0.01,
		"bar must not move until its delay has elapsed")


## ...and must still land exactly on target once the delay AND the fill
## have both run. A delay that swallowed the tween would pass the test
## above and fail this one.
func test_a_delayed_fill_still_lands_on_target() -> void:
	var tokens := DesignTokens.load_default()
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	_root.add_child(bar)
	_run_and_step(func(): Juice.fill_bar(bar, 80.0, -1.0, 0.30),
		0.30 + tokens.dur_slow + 0.2)
	assert_true(absf(bar.value - 80.0) <= 0.01,
		"a delayed fill must still end exactly on its target")
```

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="juice", verbose=true)
```

Expected: both new tests FAIL — `fill_bar` takes three arguments, not four, so
the calls error before any assertion runs.

- [ ] **Step 3: Add the parameter**

In `Scripts/Design/Juice.gd`, replace the `fill_bar` doc comment and body:

```gdscript
## Animate a bar to `to`. `duration` defaults to tokens.dur_slow; pass an
## explicit one only when the fill has to stay in lockstep with something
## else that is paced by gameplay rather than by the motion tokens (the
## school day's progress bar runs beside a clock widget over a fixed
## in-fiction day length, for example). `delay` holds the bar still
## before it starts, mirroring pop_in's, so a row or stack of bars can be
## staggered without a hand-rolled timer. Returns the tween so callers
## can await it.
static func fill_bar(bar: Range, to: float, duration: float = -1.0,
		delay: float = 0.0) -> Tween:
	if not _alive(bar):
		return null
	var tw := bar.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(bar, "value", to,
		tokens().dur_slow if duration < 0.0 else duration).set_delay(delay)
	return tw
```

- [ ] **Step 4: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="juice", verbose=true)
```

Expected: the whole `juice` suite PASSES, including
`test_fill_bar_lands_on_the_target_value` (the existing three-argument call
still compiles and still lands).

- [ ] **Step 5: Check the existing call sites still behave**

The parameter is appended and defaults to `0.0`, so no call site changes. Prove
it rather than assuming — run the suites that cover the screens that fill bars:

```
test_run(suite="school_day", verbose=true)
test_run(suite="ui_components", verbose=true)
```

Expected: both PASS. `tests/test_school_day.gd:226` asserts the source contains
`Juice.fill_bar(progress_bar` — a prefix match, unaffected by a new trailing
parameter.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/Juice.gd tests/test_juice.gd
git commit -m "feat(juice): let fill_bar take a start delay, like pop_in"
```

---

### Task 4: Grow each stat track by the points gained that day

The track already lands on `current/target`, but it *snaps* there the instant
the card is built, so the half of the annotation that says it "will also
increase based on points gained that day" is invisible. Each row now rewinds to
where it stood this morning — `current - delta` — and grows back, with the
chevron popping in on the same beat.

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd` (add two vars, one static helper and `play_gain`; extend `set_stat`)
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` (add `GAIN_STEP` and `play_gain`)
- Modify: `Scripts/SchoolSimulation/DaySummaryPopup.gd:75-76` (replay after the cards land)
- Modify: `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md` (motion note)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `Juice.fill_bar(bar, to, duration, delay)` from Task 3;
  `Juice.pop_in(node, delay)` and `Juice.tokens()` (both already exist);
  `DaySummaryStatRow.shows_chevron` from Task 1 (indirectly, via
  `chevron.visible`); `DaySummaryStatRow.track_ratio(current, target)` (exists).
- Produces:
  - `DaySummaryStatRow.track_ratio_before(current: float, delta: float,
    target: float) -> float` — static, 0.0–100.0, clamped.
  - `DaySummaryStatRow.play_gain(delay: float = 0.0) -> void` — **not** a
    coroutine; returns immediately with the track rewound and a tween running.
  - `DaySummaryStudentRow.GAIN_STEP: float` and
    `DaySummaryStudentRow.play_gain(delay: float = 0.0) -> void`.
  - `set_stat`'s signature is **unchanged** — it gains behavior, not parameters.

- [ ] **Step 1: Add the tween-stepping helper to the suite**

`tests/test_day_summary.gd` has never had to test an animation, so it lacks the
helper. Add it immediately after `func suite_name()` (around line 35):

```gdscript
## Snapshot the active tweens, run `action`, then fast-forward only the
## tweens it created by `duration` seconds. Lifted from
## tests/test_juice.gd:52 -- the MCP runner calls suite.call(name)
## without awaiting, so Tween.custom_step() is the only way a
## non-coroutine test can see an animation's end state. Diffing against
## the before-snapshot keeps a tween still finishing from an earlier test
## (or from the editor's own UI) from being mistaken for this one's.
func _run_and_step(action: Callable, duration: float) -> void:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var after: Array = Engine.get_main_loop().get_processed_tweens()
	for tw in after:
		if not before.has(tw) and is_instance_valid(tw):
			tw.custom_step(duration)
```

- [ ] **Step 2: Write the failing tests**

Add to `tests/test_day_summary.gd`, after the chevron tests from Task 1:

```gdscript
## Where the track stood this morning. The day's gain has already been
## applied to the StudentData by the time the popup is built, so the
## starting point is current MINUS the delta -- not plus.
func test_track_ratio_before_backs_todays_gain_out() -> void:
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(39.0, 6.0, 50.0), 66.0),
		"39 after a +6 day means the morning read 33/50 = 66%")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(39.0, 0.0, 50.0), 78.0),
		"a day that gained nothing must start exactly where it ends")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(4.0, 10.0, 50.0), 0.0),
		"a gain larger than the standing stat must clamp to empty, not go negative")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(30.0, -5.0, 50.0), 70.0),
		"a losing day must start ABOVE where it ends, so the bar shrinks")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(30.0, 5.0, 0.0), 0.0),
		"a zero target must return 0, not divide by zero")


## set_stat must still land the final value on its own, so a row that is
## never animated -- the editor preview, a future caller -- is still
## correct. play_gain then rewinds and grows back.
func test_play_gain_rewinds_the_track_to_this_mornings_value() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.set_stat("akademis", 6.0, 50.0, 39.0)
	assert_true(absf(inst.track.value - 78.0) <= 0.01,
		"set_stat must still leave the DAY'S FINAL value on the track")

	inst.play_gain()
	assert_true(absf(inst.track.value - 66.0) <= 0.01,
		"play_gain must rewind the track to 33/50 = 66% before it grows")
	assert_eq(inst.value.text, "+6/50",
		"replaying the fill must not disturb the number")


## ...and the growth must end exactly where set_stat put it. Stepping the
## tween past dur_slow is what proves the fill is a real animation and
## not just a second assignment.
func test_a_played_gain_lands_on_the_days_final_value() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var tokens := DesignTokens.load_default()
	inst.set_stat("olahraga", 6.0, 50.0, 39.0)
	_run_and_step(func(): inst.play_gain(), tokens.dur_slow + 0.2)

	assert_true(absf(inst.track.value - 78.0) <= 0.01,
		"the fill must end exactly on current/target")
	assert_eq(inst.track.theme_type_variation, &"DaySummaryStatTrackOlahraga",
		"replaying the fill must not disturb the row's category colour")


## The card drives all three of its rows, including the ones that did not
## move -- those simply rewind to where they already are and hold still.
func test_the_card_replays_every_stat_track() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.akademis = 39.0
	s.seni_budaya = 20.0
	s.olahraga = 10.0
	s.target_akademis1 = 50.0
	s.target_akademis2 = 50.0
	s.target_akademis3 = 50.0
	inst.setup_row("Marcel", [
		{"stat_key": "akademis", "delta": 6.0},
		{"stat_key": "seni_budaya", "delta": 4.0},
	], s)

	inst.play_gain()

	assert_true(absf(inst.stat_rows[0].track.value - 66.0) <= 0.01,
		"akademis must rewind to 33/50 = 66%")
	assert_true(absf(inst.stat_rows[1].track.value - 32.0) <= 0.01,
		"seni_budaya must rewind to 16/50 = 32%")
	assert_true(absf(inst.stat_rows[2].track.value - 20.0) <= 0.01,
		"olahraga did not move, so it must hold still at 10/50 = 20%")


## The popup owns the beat: the bars grow after the cards have landed,
## not while the stack is still fading in. A source scan because
## setup_summary is a coroutine and this suite may not await one.
func test_popup_replays_each_cards_gain_after_the_cards_land() -> void:
	var src := FileAccess.get_file_as_string(_POPUP_SCRIPT)
	assert_true(src.contains("Juice.stagger_in(rows)"),
		"the cards must still stagger in")
	assert_true(src.contains("play_gain("),
		"the popup must replay each card's stat-track growth")
	assert_true(src.find("Juice.stagger_in(rows)") < src.find("play_gain("),
		"the fill must run AFTER the cards land, not before")
```

- [ ] **Step 3: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: all five new tests FAIL — `track_ratio_before` and `play_gain` do not
exist on either script, and `DaySummaryPopup.gd` contains no `play_gain(`.

- [ ] **Step 4: Implement the rewind-and-grow on the stat row**

In `Scripts/SchoolSimulation/DaySummaryStatRow.gd`, add these two vars directly
below the `@onready` block (after `@onready var value: Label = $Value`):

```gdscript
## Where the track sat this morning and where it sits tonight, cached by
## set_stat so play_gain can rewind and grow back. set_stat itself still
## lands the track on the final value, so a row that is never animated is
## still correct.
var _fill_from: float = 0.0
var _fill_to: float = 0.0
```

Add this static helper immediately after `track_ratio`:

```gdscript
## How full the track stood BEFORE today. The day's gain has already been
## applied to the StudentData by the time the popup is built, so the
## starting point is the standing value minus the day's delta.
##
## StudentData clamps its stats when it applies them, so on a day that hit
## the 0 or 100 ceiling, current - delta overshoots the true morning value
## slightly and the bar travels a touch further than it really did. That is
## cosmetic, and is preferred over threading a pre-day snapshot through the
## whole simulation for the sake of one animation.
static func track_ratio_before(current: float, delta: float, target: float) -> float:
	return track_ratio(current - delta, target)
```

Extend `set_stat` to cache the two ends (the final assignment is unchanged in
effect — it now reads from the cached value):

```gdscript
func set_stat(stat_key: String, delta: float, target: float, current: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	if TRACK_VARIATION_FOR.has(stat_key):
		track.theme_type_variation = TRACK_VARIATION_FOR[stat_key]
	value.text = format_value(delta, target)
	chevron.visible = shows_chevron(delta)
	_fill_from = track_ratio_before(current, delta, target)
	_fill_to = track_ratio(current, target)
	track.value = _fill_to
```

And add `play_gain` at the end of the file:

```gdscript
## Replay today's movement: rewind the track to where it stood this
## morning and grow it back to where set_stat already left it, popping
## the chevron in over the same beat. `delay` holds the whole gesture so
## a card can stagger its three rows.
##
## Never awaited and never required -- set_stat has already written the
## final value, so a caller that skips this sees a correct, static card.
func play_gain(delay: float = 0.0) -> void:
	track.value = _fill_from
	Juice.fill_bar(track, _fill_to, -1.0, delay)
	if chevron.visible:
		Juice.pop_in(chevron, delay)
```

- [ ] **Step 5: Fan the replay out across the card**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, add the constant below
the existing `TARGET_FOR` block:

```gdscript
## How far apart the card's three tracks start filling, in seconds. Short
## enough to read as one gesture, long enough that the eye catches each
## bar leaving the gate. Lives here rather than on the stat row because
## it is a property of the card's three-row rhythm, not of one row.
const GAIN_STEP := 0.08
```

and add this method at the end of the file:

```gdscript
## Replay every stat track's growth for today, one row after the next.
## `delay` shifts the whole card, so the popup can line each card's fill
## up with its own staggered entrance.
func play_gain(delay: float = 0.0) -> void:
	for i in stat_rows.size():
		stat_rows[i].play_gain(delay + float(i) * GAIN_STEP)
```

- [ ] **Step 6: Have the popup run the replay once the cards have landed**

In `Scripts/SchoolSimulation/DaySummaryPopup.gd`, replace lines 75–76:

```gdscript
	# The rows land one after another once the card itself has settled.
	Juice.stagger_in(rows)
```

with:

```gdscript
	# The rows land one after another once the card itself has settled.
	Juice.stagger_in(rows)

	# Each card's tracks grow on the beat that card lands on, so the fill
	# reads as a consequence of the card arriving rather than as the whole
	# stack's worth of motion firing at once behind a still-fading list.
	# The step matches stagger_in's own, which is what lines them up.
	var gain_step := Juice.tokens().stagger_step
	for i in rows.size():
		rows[i].play_gain(float(i) * gain_step)
```

- [ ] **Step 7: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: the whole `day_summary` suite PASSES, including all five new tests
and every test from Tasks 1–2.

- [ ] **Step 8: Run the full suite for regressions**

```
test_run()
```

Expected: exactly **one** failure —
`audio_director / test_volumes_persist_across_a_fresh_director`, the
pre-existing coroutine issue in CLAUDE.md's Known Issues #1. Any other failure
is caused by this change and must be fixed before committing.

That known-broken test also dirties `Assets/Audio/default_bus_layout.tres` as a
side effect. Revert it so it does not ride along in the commit:

```bash
git checkout -- Assets/Audio/default_bus_layout.tres
```

- [ ] **Step 9: Record the motion in the spec**

In `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`, directly
below the existing "Departure from the mockup (2026-08-30, director-approved)"
note, add:

```markdown
> **Motion (2026-08-30).** The three tracks do not snap to their value. Each
> rewinds to `(current − today's delta) / target` and grows to
> `current / target` over `dur_slow`, so the day's gain is visible as
> movement — the gold chevron pops in on the same beat. Rows within a card
> are offset by `DaySummaryStudentRow.GAIN_STEP` (0.08s); cards within the
> stack by `tokens.stagger_step`, matching their own entrance. The needs
> bars (#6–#9) are deliberately **not** animated: energy and mood mostly
> fall over a day, and replaying that alongside three growing skill tracks
> reads as a contradiction rather than as progress.
```

- [ ] **Step 10: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd Scripts/SchoolSimulation/DaySummaryStudentRow.gd Scripts/SchoolSimulation/DaySummaryPopup.gd tests/test_day_summary.gd docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md
git commit -m "feat(day-summary): grow each stat track by the points gained that day"
```

---

### Task 5: Verify all five annotated elements on a real simulated day

Every test in Tasks 1–4 is a pure function, a stylebox lookup, a source scan or
a hand-stepped tween. None of them prove the popup renders correctly for a real
student on a real day. This task is the only step that does, and it is the
reason the plan is not finished at Task 4.

**Files:** none — verification only.

**Interfaces:** none.

- [ ] **Step 1: Reach the Daily Results popup with real schedule data**

Do **not** teleport straight to SchoolDay. The debug seed does not fill
`GameState.day_schedules` (documented in CLAUDE.md), so every student
auto-takes Izin — a forced Istirahat, which moves only mood and energy — and
all three deltas come out `+0`. That state hides every gain-dependent behavior
this plan adds.

1. Run the project (`project_run`, or F5 in the editor).
2. Open the debug overlay (`F1`, or five taps in the top-right corner).
3. General tab → **⚡ Seed Playtest State**.
4. Scenes tab → teleport to **Lobby**.
5. Go through **Atur Jadwal** and assign Monday deliberately: one student
   `Akademis`, one `SeniBudaya`, one `Olahraga`, and **one `Istirahat`** — the
   resting student is what proves the `+0` case.
6. Start the week and let Monday simulate to the Daily Results popup.

- [ ] **Step 2: Screenshot and check all five annotated elements**

Take one `editor_screenshot` of the popup and confirm, per card:

1. **Red — energy.** The upper violet bar reads as a plausible fraction of
   full, and differs between students who did different activities. It must not
   sit at the mockup's 36% on every card; that would mean the placeholder is
   still showing.
2. **Yellow — mood.** The lower gold bar, likewise, and clearly distinct from
   the energy bar above it.
3. **Pink — the chevron.** The scheduled `Akademis` student shows a gold arrow
   on row 1 **only**; the `Istirahat` student shows **no arrow on any row**. If
   every row has an arrow, `set_stat` is not gating it.
4. **Blue — the number.** `+N/T` is unchanged, reads the day's gain over the
   target, and a positive `+N` appears on the row matching each student's
   scheduled activity. `+0/T` for the resting student.
5. **Orange — the track.** Each bar shows a **partial** fill in its category
   colour (row 1 blue, row 2 green, row 3 red), starting at the track's left
   edge, and does not paint over the white icon or the chevron.

- [ ] **Step 3: Watch the fill, do not just screenshot it**

A screenshot cannot show motion, and motion is what Task 4 added. Watch the
popup open live and confirm:

1. The bars are **emptier when the card lands than a moment later** — the
   growth is visible, not instantaneous.
2. Rows fill top-to-bottom within a card, and cards fill down the stack.
3. Each chevron **pops in** with its own row's fill rather than being there
   from the first frame.
4. A row that gained nothing does not move and shows no arrow.

If the motion is not visible, re-open the day: the popup only animates once.

- [ ] **Step 4: Confirm the degenerate cases**

Still in the debug overlay, Students tab:

1. Raise one student's Akademis **above** `target_akademis1`, simulate another
   day, and confirm that bar renders completely full and flush with the rail's
   right edge — not overflowing, not wrapping.
2. Trigger a day where a stat **loses** points (a `Biang Onar` student, or the
   stat editors plus a scheduled activity that costs). Confirm the number reads
   `-N/T`, **no** arrow appears, and the bar shrinks rather than growing.

- [ ] **Step 5: Report the result**

Report to the director with the screenshot and a note on what the motion looked
like. If any check in Steps 2–4 fails, that is a real defect in Tasks 1–4 — fix
it and re-run `test_run(suite="day_summary")` before reporting success. Do not
report this plan complete on the strength of the test suite alone.

---

## Self-Review

**Spec coverage.** The director's annotation named five elements. *Red
(energy)* and *yellow (mood)* — Task 2 gives them their first behavioral
coverage and stops an unknown student inheriting the mockup's placeholders;
Task 5 Step 2 checks 1–2 confirm them on screen. *Pink (the up arrow that only
pops up when points gained)* — Task 1, the only element with no code behind it
at all, plus the pop-in beat in Task 4 and Task 5 Step 2 check 3. *Blue
(`+gained/needed`)* — verified already correct and **deliberately unchanged**;
Tasks 1 and 4 both assert it survives their edits, and Task 5 Step 2 check 4
confirms it live. *Orange (progress toward the final stat check, increasing
with the day's points)* — the value was already right as of commit c698e45; the
half that was missing is the visible increase, which Tasks 3–4 deliver and Task
5 Step 3 confirms.

**One interpretation worth flagging.** "will also increase based on points
gained that day" is already true of the *value* — the day's gain is inside
`current` before the popup is built. This plan reads it as a request for the
increase to be **visible**, which is why Task 4 exists. If the director only
meant the value, Tasks 3–4 can be dropped and Tasks 1, 2 and 5 still stand on
their own.

**Placeholder scan.** No TBDs, no "add error handling", no "similar to Task N".
Every code step carries the literal code. The degenerate cases that could have
hidden behind "handle edge cases" are each named, given a reason and given a
test: `target <= 0.0` (rows built with no `StudentData`), `current - delta < 0`
(a gain larger than the standing stat), `delta < 0` (a losing day, which must
shrink the bar and show no arrow), and `student == null` (a missed name lookup).

**Type consistency.** `shows_chevron(delta) -> bool` is defined in Task 1
Step 3 and called with that argument in Task 1 Step 1's tests and inside
`set_stat`. `track_ratio_before(current, delta, target) -> float` is defined in
Task 4 Step 4 and called with that order in Task 4 Step 2's tests and inside
`set_stat`. `play_gain(delay := 0.0)` has the same signature on both
`DaySummaryStatRow` (Task 4 Step 4) and `DaySummaryStudentRow` (Task 4 Step 5),
and the popup calls the latter (Task 4 Step 6). `Juice.fill_bar(bar, to,
duration, delay)` is defined in Task 3 Step 3 and called as
`Juice.fill_bar(track, _fill_to, -1.0, delay)` in Task 4 Step 4 — the `-1.0` is
required to reach the fourth parameter. `set_stat(stat_key, delta, target,
current)` keeps its existing four-parameter shape throughout; only its body
grows. `GAIN_STEP` (the card's internal row offset) and `tokens.stagger_step`
(the popup's card offset) are deliberately different numbers for different
rhythms, not a duplicated constant.

**Two deliberate omissions.** The needs bars are not animated (reasoned in the
Task 4 Step 9 spec note: energy and mood usually *fall*, and replaying that
beside three growing skill tracks reads as a contradiction). And no down-arrow
art is added for losses — the asset folder has none, and the annotation asks
only that the arrow appear on a gain.
