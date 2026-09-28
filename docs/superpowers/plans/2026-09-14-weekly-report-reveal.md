# Weekly Report Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The end-of-week report (ResultCheckup) plays out one reward at a time: cards land one by one, each stat counts then pops with a RewardBurst at a climbing pitch, the three summary lines follow in order, and a tap skips to the end.

**Architecture:** A pure `WeekReportReveal` turns every card's three stat deltas and the three summary values into an ordered list of timed steps. `ResultCheckup` plays those steps through one parallel `Tween` of delayed callbacks, and can kill it to skip. The card (`DaySummaryStudentRow`) and its rows (`DaySummaryStatRow`) gain a small week-reveal API (rewind / count / pop / land) beside their untouched nightly `play_gain`.

**Tech Stack:** Godot 4.6 GDScript, godot-ai MCP editor bridge, `McpTestSuite` suites run by `test_run`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-14-weekly-report-reveal-design.md`.
- Work in the worktree `.claude/worktrees/weekly-report-reveal` on branch `feat/weekly-report-reveal`. Its editor is session `weekly-report-reveal@bcf0` (re-list with `session_manage(op="list")` after any editor restart; the id changes). Pass `session_id` on **every** godot-ai call. Never `session_activate`, never kill every Godot process.
- Every test step: `Run: test_run(suite="<x>", session_id="weekly-report-reveal@bcf0")`.
- After editing a `.gd` from outside the editor (Write/Edit tools), force the reload with a **no-op `script_patch`** on that file before `test_run` (CLAUDE.md, "Rescan after editing"). A brand-new `class_name` script also needs `filesystem_manage(op="scan")`.
- Tests: `@tool`, extend `McpTestSuite`, override `suite_name()`, **no coroutines** (no `await` in a test). Tweens are observed with `Tween.custom_step()`.
- Every script opens with a `##` block; every `@export` has a `##` line directly above it (`tests/test_script_documentation.gd`).
- No `theme_override_*`, no runtime-built visuals (`.new()` of a Control/particle), no emoji, UI text Indonesian.
- `Balance.gd` is read-only. New tunables are named consts or `@export`s in the owning script.
- Do not touch `DaySummaryPopup.gd`, `DaySummaryStatRow.play_gain`/`_play_burst`, or `DaySummaryStudentRow.play_gain`/`play_week_gain`: the nightly popup must behave exactly as before.
- No `match` in a function that calls two sfx-playing functions: `tests/test_audio_coverage.gd`'s double-fire scan only understands `elif`/`else`/`return` as exclusion.
- Commits: Conventional Commits with scope `weekly-reveal`, written to a scratchpad file and committed with `git commit -F <file>` (PowerShell 5.1 splits `-m` here-strings). Stage files **by name**; the editor rewrites `Assets/Audio/default_bus_layout.tres` on boot, so never `git add -A`. End every message with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- New `.gd` files get a sibling `.gd.uid` from the editor's scan; stage both.

## File map

| File | Change | Responsibility |
|---|---|---|
| `Scripts/Audio/AudioDirector.gd` | modify `play_sfx` | optional `pitch` multiplier |
| `Scripts/Design/Juice.gd` | add `punch`, `text_center`; extend `count_up_formatted` | motion vocabulary |
| `Scripts/SchoolSimulation/WeekReportReveal.gd` | create | pure reveal timeline + scroll math |
| `Scripts/SchoolSimulation/DaySummaryStatRow.gd` | add week-reveal API | one row's rewind / count / pop / land |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | add week-reveal API | one card's rewind / needs travel / land |
| `Scripts/SchoolSimulation/ResultCheckup.gd` | replace entrance | knobs, pitch, timeline player, skip |
| `tests/test_audio_director.gd` | add test | pitch |
| `tests/test_juice.gd` | add tests | punch, text_center, count duration |
| `tests/test_week_report_reveal.gd` | create | timeline order and math |
| `tests/test_result_checkup.gd` | add + update tests | card/row week API, screen reveal |
| `docs/superpowers/CHANGELOG.md`, `CLAUDE.md` | docs | changelog entry, suite count |

---

### Task 1: `AudioDirector.play_sfx` takes a pitch

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd:202-210`
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Produces: `AudioDirector.play_sfx(id: StringName, pitch: float = 1.0) -> void`. Every existing one-argument call is unchanged.

- [ ] **Step 1: Write the failing test** — append to `tests/test_audio_director.gd`:

```gdscript
## The weekly report climbs its pops in pitch. The usual random spread
## still rides on top, so the voice lands within that spread of the pitch
## asked for -- not at 1.0.
func test_play_sfx_scales_the_voice_by_the_given_pitch() -> void:
	_director.set("sfx_tap", AudioStreamGenerator.new())
	var next: int = _director._sfx_next
	_director.play_sfx(&"tap", 1.5)
	var player: AudioStreamPlayer = _director._sfx_pool[next]
	var spread: float = _director.sfx_pitch_variance
	assert_true(player.pitch_scale >= 1.5 * (1.0 - spread) - 0.001
		and player.pitch_scale <= 1.5 * (1.0 + spread) + 0.001,
		"pitch 1.5 must land within the spread around 1.5, got %f" % player.pitch_scale)
	player.stop()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="audio_director", session_id="weekly-report-reveal@bcf0")`
Expected: FAIL (`play_sfx` takes one argument — "Too many arguments" / 0 assertions).

- [ ] **Step 3: Implement** — replace `play_sfx` in `Scripts/Audio/AudioDirector.gd`:

```gdscript
## Play one sfx cue. `pitch` scales the voice on top of the usual random
## spread: 1.0, every call's default, leaves it exactly as before; the
## weekly report's reveal climbs it one step per pop.
func play_sfx(id: StringName, pitch: float = 1.0) -> void:
	var stream := _resolve_sfx(id)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = pitch * (1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance))
	player.play()
```

- [ ] **Step 4: No-op `script_patch` on `res://Scripts/Audio/AudioDirector.gd`, then run**

Run: `test_run(suite="audio_director", session_id="weekly-report-reveal@bcf0")` and `test_run(suite="audio_coverage", session_id="weekly-report-reveal@bcf0")`
Expected: both PASS.

- [ ] **Step 5: Commit** `Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd` — `feat(weekly-reveal): play_sfx takes an optional pitch`.

---

### Task 2: Juice learns `punch` and `text_center`; counts take a duration

**Files:**
- Modify: `Scripts/Design/Juice.gd` (after `pop_in`; `count_up_formatted` at 117-132)
- Test: `tests/test_juice.gd`

**Interfaces:**
- Produces:
  - `Juice.PUNCH_SCALE := 1.3`
  - `Juice.punch(node: Control, pivot: Vector2 = Vector2(-1.0, -1.0)) -> Tween` — scale-only 1.0 → `PUNCH_SCALE` (`dur_instant`) → 1.0 (`dur_normal`, TRANS_BACK) about `pivot` (node-local; negative = centre). Returns null for a dead node.
  - `Juice.text_center(label: Label) -> Vector2` — centre of the rendered text in the label's space, honouring `horizontal_alignment`.
  - `Juice.count_up_formatted(label, from, to, formatter, delay := 0.0, duration := -1.0) -> Tween` — `duration < 0` means `dur_slow`. Returns null for a dead label.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_juice.gd`:

```gdscript
## A number "landing": the punch overshoots past unit scale and settles
## exactly back on it.
func test_punch_overshoots_then_settles_at_unit_scale() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	var tw := Juice.punch(c)
	tw.custom_step(tokens.dur_instant)
	assert_true(c.scale.x > 1.2, "mid-punch the node must be past unit scale, got %f" % c.scale.x)
	tw.custom_step(tokens.dur_normal + 0.1)
	assert_true(absf(c.scale.x - 1.0) <= 0.02, "the punch must settle at exactly 1.0")


## The punch grows from the pivot it is handed -- the number's own centre --
## and from the middle when handed none.
func test_punch_uses_the_given_pivot() -> void:
	var c := _make_control()
	Juice.punch(c, Vector2(30, 20))
	assert_eq(c.pivot_offset, Vector2(30, 20), "an explicit pivot is used as given")
	var d := _make_control()
	Juice.punch(d)
	assert_eq(d.pivot_offset, Vector2(100, 50), "no pivot means the centre")


func test_punch_tolerates_a_null_node() -> void:
	assert_true(Juice.punch(null) == null, "punch on a null node is a no-op")


## Where the words actually are: a wide right-aligned label's text sits at
## its right end, a left-aligned one's at its left, a centred one's in the
## middle. Left and right mirror each other about the middle.
func test_text_center_follows_the_alignment() -> void:
	var label := Label.new()
	label.text = "+12/65"
	label.size = Vector2(400, 60)
	_root.add_child(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var left := Juice.text_center(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var right := Juice.text_center(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mid := Juice.text_center(label)
	assert_true(left.x > 0.0 and left.x < 200.0, "left text centres left of middle")
	assert_true(right.x > 200.0 and right.x < 400.0, "right text centres right of middle")
	assert_true(absf(left.x + right.x - 400.0) <= 0.5, "left and right mirror about the middle")
	assert_true(absf(mid.x - 200.0) <= 0.5, "centred text sits in the middle")
	assert_true(absf(mid.y - 30.0) <= 0.5, "vertically, the rect's centre")


## A count can be paced by its caller -- the weekly reveal counts each row
## in its own count_seconds -- and hands back its tween.
func test_count_up_formatted_honours_its_duration() -> void:
	var label := Label.new()
	_root.add_child(label)
	var fmt := func(v: float) -> String: return str(int(round(v)))
	var tw := Juice.count_up_formatted(label, 0.0, 40.0, fmt, 0.0, 0.1)
	assert_true(tw is Tween, "the count returns its tween")
	tw.custom_step(0.15)
	assert_eq(label.text, "40", "a 0.1 s count has landed after 0.15 s")


func test_count_up_formatted_defaults_to_dur_slow() -> void:
	var label := Label.new()
	_root.add_child(label)
	var fmt := func(v: float) -> String: return str(int(round(v)))
	var tw := Juice.count_up_formatted(label, 0.0, 40.0, fmt)
	tw.custom_step(0.15)
	assert_true(label.text != "40", "a default-length count is still running at 0.15 s")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="juice", session_id="weekly-report-reveal@bcf0")`
Expected: FAIL — `punch`/`text_center` do not exist; `count_up_formatted` returns nothing.

- [ ] **Step 3: Implement** — in `Scripts/Design/Juice.gd`, add after the `NO_AUTO_JUICE` const:

```gdscript
## How far punch() overshoots before settling back to unit scale.
const PUNCH_SCALE := 1.3
```

Add after `pop_in`:

```gdscript
## A number "landing": a scale-only overshoot to PUNCH_SCALE and back,
## about `pivot` (node-local). Pass text_center(label) for a label whose
## text does not fill its rect, so the pop grows from the number itself
## rather than from the middle of an empty box. A negative pivot means the
## node's centre. Scale only -- pop_in's fade would blink the number out.
static func punch(node: Control, pivot: Vector2 = Vector2(-1.0, -1.0)) -> Tween:
	if not _alive(node):
		return null
	var t := tokens()
	node.pivot_offset = node.size * 0.5 if pivot.x < 0.0 else pivot
	node.scale = Vector2.ONE
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(PUNCH_SCALE, PUNCH_SCALE), t.dur_instant) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale", Vector2.ONE, t.dur_normal) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tw


## The centre of a label's rendered text, in the label's own space: where
## the words actually are, which for a left- or right-aligned label on a
## wide rect is nowhere near size / 2. Honours horizontal_alignment; the
## vertical centre is the rect's, where every single-line label here sits.
static func text_center(label: Label) -> Vector2:
	if not _alive(label):
		return Vector2.ZERO
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := label.size.x * 0.5
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
		x = width * 0.5
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = label.size.x - width * 0.5
	return Vector2(x, label.size.y * 0.5)
```

Replace `count_up_formatted` (keep its doc block, extend it):

```gdscript
## Same as count_up, but the text is built by a caller-supplied formatter
## instead of a single printf pattern -- for labels whose text depends on
## more than one number (a signed delta beside a fixed target, e.g.
## "+12/65"). `formatter` takes the interpolated value and returns the
## full label text; `delay` matches pop_in/fill_bar's, so this can be
## staggered alongside a bar it travels with. `duration` defaults to
## tokens.dur_slow; the weekly reveal passes its own count_seconds. Returns
## the tween so a caller can stop it.
static func count_up_formatted(label: Label, from: float, to: float,
		formatter: Callable, delay: float = 0.0, duration: float = -1.0) -> Tween:
	if not _alive(label):
		return null
	var t := tokens()
	label.text = formatter.call(from)
	var tw := label.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(
		func(v: float) -> void:
			if _alive(label):
				label.text = formatter.call(v),
		from, to, t.dur_slow if duration < 0.0 else duration).set_delay(delay)
	tw.tween_callback(func() -> void:
		if _alive(label):
			label.text = formatter.call(to))
	return tw
```

- [ ] **Step 4: No-op `script_patch` on `res://Scripts/Design/Juice.gd`, then run**

Run: `test_run(suite="juice", session_id="weekly-report-reveal@bcf0")`, then `day_summary` and `result_checkup` (existing callers of `count_up_formatted`).
Expected: all PASS.

- [ ] **Step 5: Commit** `Scripts/Design/Juice.gd tests/test_juice.gd` — `feat(weekly-reveal): Juice.punch, text_center and a paced count`.

---

### Task 3: `WeekReportReveal` — the reveal as a timeline

**Files:**
- Create: `Scripts/SchoolSimulation/WeekReportReveal.gd`
- Create: `tests/test_week_report_reveal.gd` (suite name `week_report_reveal`)

**Interfaces:**
- Produces:
  - Step kinds (StringName consts): `CARD`, `ROW_COUNT`, `ROW_POP`, `LINE`, `LINE_POP`, `FINALE`.
  - `DEFAULT_PACING: Dictionary` with keys `start`, `card_lead`, `count`, `row_gap`, `quiet_row`, `card_gap`, `line_gap`, `finale_gap`.
  - `static func build(row_deltas: Array, line_values: Array, pacing: Dictionary = {}) -> Array` — steps sorted by `at`; each `{at: float, kind: StringName, card: int, row: int, pop_index: int, seconds: float}`. `row` is the stat row for `ROW_*` and the summary line for `LINE*`; `-1` where it does not apply. `pop_index` counts pops (stats and lines together) from 0, `-1` on non-pops. `seconds` is the count length on `ROW_COUNT`/`LINE` (`count` for a gain or non-zero line, `quiet_row` for a non-gaining row, `0.0` for a zero line) and `0.0` elsewhere.
  - `static func scroll_to_show(top: float, bottom: float, view_height: float, current: float) -> float`.

- [ ] **Step 1: Write the failing suite** — create `tests/test_week_report_reveal.gd`:

```gdscript
@tool
extends McpTestSuite

## The weekly report's reveal timeline (WeekReportReveal), checked as data:
## the order cards, rows, pops and summary lines play in, and the scroll
## that follows them. Pure -- nothing is instanced and nothing animates.
## @tool, and no test here may be a coroutine.

const _R := preload("res://Scripts/SchoolSimulation/WeekReportReveal.gd")


func suite_name() -> String:
	return "week_report_reveal"


## The steps of one kind, in timeline order.
func _of(steps: Array, kind: StringName) -> Array:
	var out: Array = []
	for s in steps:
		if s["kind"] == kind:
			out.append(s)
	return out


func _first(steps: Array, kind: StringName, card: int, row: int) -> Dictionary:
	for s in steps:
		if s["kind"] == kind and s["card"] == card and s["row"] == row:
			return s
	return {}


func test_steps_come_back_sorted_by_time() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 3.0], [0.0, 2.0, 0.0]], [100.0, 1.0, 0.0])
	for i in range(1, steps.size()):
		assert_true(float(steps[i]["at"]) >= float(steps[i - 1]["at"]),
			"step %d must not come before step %d" % [i, i - 1])


## Card 1 lands, its three rows play top to bottom, and only then card 2.
func test_cards_land_in_order_each_playing_its_rows_top_to_bottom() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 5.0], [5.0, 5.0, 5.0]], [0.0, 0.0, 0.0])
	var seen: Array = []
	for s in steps:
		if s["kind"] == _R.CARD:
			seen.append("c%d" % s["card"])
		elif s["kind"] == _R.ROW_COUNT:
			seen.append("c%dr%d" % [s["card"], s["row"]])
	assert_eq(seen, ["c0", "c0r0", "c0r1", "c0r2", "c1", "c1r0", "c1r1", "c1r2"],
		"one card at a time, its rows top to bottom")


func test_a_gain_pops_exactly_when_its_count_lands() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 0.0]], [0.0, 0.0, 0.0], {"count": 0.4})
	var count := _first(steps, _R.ROW_COUNT, 0, 0)
	var pop := _first(steps, _R.ROW_POP, 0, 0)
	assert_false(pop.is_empty(), "a gaining row pops")
	assert_true(absf(float(pop["at"]) - float(count["at"]) - 0.4) <= 0.0001,
		"the pop lands count seconds after the count starts")


func test_the_next_row_waits_for_the_pop() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 0.0]], [0.0, 0.0, 0.0])
	var pop0 := _first(steps, _R.ROW_POP, 0, 0)
	var count1 := _first(steps, _R.ROW_COUNT, 0, 1)
	assert_true(float(count1["at"]) > float(pop0["at"]),
		"row 2 starts only after row 1 has landed")


## The game's standing rule: no gain, no celebration.
func test_a_row_that_did_not_gain_never_pops() -> void:
	var steps: Array = _R.build([[0.0, -3.0, 7.0]], [0.0, 0.0, 0.0])
	var pops := _of(steps, _R.ROW_POP)
	assert_eq(pops.size(), 1, "only the gaining row pops")
	assert_eq(int(pops[0]["row"]), 2, "and it is the third row")


func test_count_steps_carry_their_own_length() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 0.0]], [100.0, 0.0, 0.0],
		{"count": 0.4, "quiet_row": 0.15})
	assert_eq(float(_first(steps, _R.ROW_COUNT, 0, 0)["seconds"]), 0.4, "a gain counts in full")
	assert_eq(float(_first(steps, _R.ROW_COUNT, 0, 1)["seconds"]), 0.15, "a flat row settles short")
	assert_eq(float(_first(steps, _R.LINE, -1, 0)["seconds"]), 0.4, "a non-zero line counts in full")
	assert_eq(float(_first(steps, _R.LINE, -1, 1)["seconds"]), 0.0, "a zero line has nothing to count")


func test_the_summary_follows_the_last_row_in_order() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 5.0]], [100.0, 2.0, 1.0])
	var lines := _of(steps, _R.LINE)
	assert_eq(lines.size(), 3, "three summary lines")
	assert_eq([int(lines[0]["row"]), int(lines[1]["row"]), int(lines[2]["row"])], [0, 1, 2],
		"coins, then won, then lost")
	var last_row := _first(steps, _R.ROW_POP, 0, 2)
	assert_true(float(lines[0]["at"]) > float(last_row["at"]),
		"the summary waits for the last row to land")


func test_a_zero_line_does_not_pop() -> void:
	var steps: Array = _R.build([], [1000.0, 0.0, 2.0])
	var pops := _of(steps, _R.LINE_POP)
	assert_eq(pops.size(), 2, "only the non-zero lines pop")
	assert_eq([int(pops[0]["row"]), int(pops[1]["row"])], [0, 2], "coins and lost")


## The pitch climbs through the whole report, stats and lines together.
func test_pop_index_climbs_by_one_across_stats_and_lines() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 5.0]], [100.0, 1.0, 0.0])
	var indices: Array = []
	for s in steps:
		if s["kind"] == _R.ROW_POP or s["kind"] == _R.LINE_POP:
			indices.append(int(s["pop_index"]))
		else:
			assert_eq(int(s["pop_index"]), -1, "a non-pop carries no pop index")
	assert_eq(indices, [0, 1, 2, 3], "one step per pop, in order")


func test_the_finale_comes_last() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 5.0]], [100.0, 1.0, 1.0])
	var last: Dictionary = steps[steps.size() - 1]
	assert_eq(last["kind"], _R.FINALE, "the finale is the last beat")
	assert_eq(_of(steps, _R.FINALE).size(), 1, "and there is exactly one")


func test_an_empty_roster_goes_straight_to_the_summary() -> void:
	var steps: Array = _R.build([], [0.0, 0.0, 0.0], {"start": 0.5})
	assert_eq(steps[0]["kind"], _R.LINE, "no cards, so the first beat is a line")
	assert_eq(float(steps[0]["at"]), 0.5, "on the start offset")


func test_start_offsets_the_whole_timeline() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 0.0]], [0.0, 0.0, 0.0], {"start": 1.0})
	assert_eq(float(steps[0]["at"]), 1.0, "the first card lands on the start offset")


func test_a_bigger_roster_takes_longer() -> void:
	var two: Array = _R.build([[5.0, 5.0, 5.0], [5.0, 5.0, 5.0]], [0.0, 0.0, 0.0])
	var four: Array = _R.build([[5.0, 5.0, 5.0], [5.0, 5.0, 5.0],
		[5.0, 5.0, 5.0], [5.0, 5.0, 5.0]], [0.0, 0.0, 0.0])
	assert_true(float(four[four.size() - 1]["at"]) > float(two[two.size() - 1]["at"]),
		"Kelas 9's four cards run longer than Kelas 7's two")


## The defaults the spec agreed: four gaining Kelas 9 students run about
## nine seconds, well under a quarter-minute.
func test_the_default_pacing_keeps_kelas_9_near_nine_seconds() -> void:
	var gain := [5.0, 5.0, 5.0]
	var steps: Array = _R.build([gain, gain, gain, gain], [1000.0, 3.0, 1.0])
	var total := float(steps[steps.size() - 1]["at"])
	assert_true(total > 7.0 and total < 11.0, "got %.2f s" % total)


# ---------------------------------------------------------------- scrolling

func test_a_card_already_in_view_does_not_scroll() -> void:
	assert_eq(_R.scroll_to_show(100.0, 500.0, 900.0, 0.0), 0.0, "fully shown: stay put")


func test_a_card_below_the_view_scrolls_just_enough() -> void:
	assert_eq(_R.scroll_to_show(932.0, 1342.0, 900.0, 0.0), 442.0,
		"bring its bottom to the view's bottom, no further")


func test_a_card_above_the_view_scrolls_up_to_its_top() -> void:
	assert_eq(_R.scroll_to_show(0.0, 410.0, 900.0, 300.0), 0.0, "scroll back to its top")


func test_a_card_taller_than_the_view_shows_its_top() -> void:
	assert_eq(_R.scroll_to_show(500.0, 1600.0, 900.0, 0.0), 500.0,
		"its top matters more than its bottom")
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run(suite="week_report_reveal", session_id="weekly-report-reveal@bcf0")`
Expected: FAIL / suite broken — `WeekReportReveal.gd` does not exist.

- [ ] **Step 3: Implement** — create `Scripts/SchoolSimulation/WeekReportReveal.gd`:

```gdscript
@tool
class_name WeekReportReveal
extends RefCounted

## The weekly report's reveal as a timeline, worked out before anything
## moves (2026-09-14 weekly-report-reveal spec). ResultCheckup hands it
## every card's three stat deltas and the three summary values, and gets
## back the ordered beats to play: when each card lands, when each row
## counts, when each number pops, when the summary lines follow and when
## the finale fires. Pure data -- no nodes and no tweens -- so the whole
## rhythm is testable without playing it (tests/test_week_report_reveal.gd).

## A card pops in, its needs bars travel, and the list scrolls to it.
const CARD := &"card"
## A stat row starts counting and filling.
const ROW_COUNT := &"row_count"
## A gaining row's number lands: punch, burst, climbing tally.
const ROW_POP := &"row_pop"
## A summary line pops in and starts counting.
const LINE := &"line"
## A non-zero summary line lands: punch and its cue.
const LINE_POP := &"line_pop"
## The confetti, when the week earned it, and the buttons.
const FINALE := &"finale"

## The pacing build() reads. ResultCheckup passes its Reveal exports under
## these keys; a key it leaves out falls back to the value here.
const DEFAULT_PACING := {
	"start": 0.0,
	"card_lead": 0.35,
	"count": 0.35,
	"row_gap": 0.08,
	"quiet_row": 0.15,
	"card_gap": 0.15,
	"line_gap": 0.12,
	"finale_gap": 0.2,
}


## `row_deltas`: one Array per card, its stat rows' deltas top to bottom.
## `line_values`: the summary lines' values top to bottom (coins, won, lost).
## Returns the steps in time order, each
## {at, kind, card, row, pop_index, seconds} -- see the plan's interface
## notes: `row` is the stat row or the summary line, -1 where neither
## applies; `pop_index` counts pops from 0 across stats and lines, -1 on a
## non-pop; `seconds` is a count's length, 0.0 on everything else.
##
## Only a gain pops. A row that did not go up settles on the short
## quiet_row beat, and a zero line arrives already reading 0: the game's
## standing rule that a flat result stays quiet.
static func build(row_deltas: Array, line_values: Array, pacing: Dictionary = {}) -> Array:
	var p: Dictionary = DEFAULT_PACING.duplicate()
	p.merge(pacing, true)
	var steps: Array = []
	var t: float = float(p["start"])
	var pops := 0
	for c in row_deltas.size():
		steps.append(_step(t, CARD, c, -1, -1, 0.0))
		t += float(p["card_lead"])
		var deltas: Array = row_deltas[c]
		for r in deltas.size():
			if float(deltas[r]) > 0.0:
				steps.append(_step(t, ROW_COUNT, c, r, -1, float(p["count"])))
				t += float(p["count"])
				steps.append(_step(t, ROW_POP, c, r, pops, 0.0))
				pops += 1
				t += float(p["row_gap"])
			else:
				steps.append(_step(t, ROW_COUNT, c, r, -1, float(p["quiet_row"])))
				t += float(p["quiet_row"])
		t += float(p["card_gap"])
	for i in line_values.size():
		if float(line_values[i]) != 0.0:
			steps.append(_step(t, LINE, -1, i, -1, float(p["count"])))
			t += float(p["count"])
			steps.append(_step(t, LINE_POP, -1, i, pops, 0.0))
			pops += 1
		else:
			steps.append(_step(t, LINE, -1, i, -1, 0.0))
		t += float(p["line_gap"])
	t += float(p["finale_gap"])
	steps.append(_step(t, FINALE, -1, -1, -1, 0.0))
	return steps


## The scroll offset that shows a card running top..bottom (in the list's
## own space) inside a view `view_height` tall, moving as little as it can
## from `current`: unchanged when the card is already fully shown, just far
## enough down to bring its bottom in when it hangs below, and up to its
## top when it starts above -- or when it is taller than the view.
static func scroll_to_show(top: float, bottom: float, view_height: float, current: float) -> float:
	if top < current:
		return maxf(top, 0.0)
	if bottom > current + view_height:
		return maxf(minf(top, bottom - view_height), 0.0)
	return current


static func _step(at: float, kind: StringName, card: int, row: int,
		pop_index: int, seconds: float) -> Dictionary:
	return {"at": at, "kind": kind, "card": card, "row": row,
		"pop_index": pop_index, "seconds": seconds}
```

- [ ] **Step 4: Register and run** — `filesystem_manage(op="scan", session_id=...)` (new `class_name`), then:

Run: `test_run(suite="week_report_reveal", session_id="weekly-report-reveal@bcf0")` and `test_run(suite="script_documentation", session_id="weekly-report-reveal@bcf0")`
Expected: all PASS. If the Kelas 9 duration test misses its 7–11 s window, report the measured value rather than widening the window.

- [ ] **Step 5: Commit** the script, its `.gd.uid`, the suite and its `.gd.uid` — `feat(weekly-reveal): WeekReportReveal plans the reveal as a timeline`.

---

### Task 4: The card and its rows learn the week reveal

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd` (vars after `_standing_current`; methods appended at the end)
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` (vars after `_mood_delta`; `setup_week_row` caches; methods after `play_week_gain`)
- Test: `tests/test_result_checkup.gd` (it owns the card's weekly reading)

**Interfaces:**
- Consumes: `Juice.punch`, `Juice.text_center`, `Juice.count_up_formatted(..., duration) -> Tween`, `AudioDirector.play_sfx(id, pitch)`.
- Produces:
  - `DaySummaryStatRow.shown_delta() -> float`
  - `DaySummaryStatRow.rewind() -> void` — track at Monday, text `format_value(0, target)`, chevron (if visible) transparent.
  - `DaySummaryStatRow.play_count(seconds: float) -> void`
  - `DaySummaryStatRow.land_pop(pitch: float) -> void`
  - `DaySummaryStatRow.land() -> void` — final values at once; kills the row's reveal tweens.
  - `DaySummaryStudentRow.rewind_week() -> void`, `play_needs_week() -> void`, `land_week() -> void`.

- [ ] **Step 1: Write the failing tests** — add to `tests/test_result_checkup.gd`, after `test_the_week_cards_needs_delta_text_is_untouched_by_play_gain`:

```gdscript
# ------------------------------------------------ the week reveal's API

## The tweens `action` creates, found the way _run_and_step finds them.
func _new_tweens(action: Callable) -> Array:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var out: Array = []
	for tw in Engine.get_main_loop().get_processed_tweens():
		if not before.has(tw) and is_instance_valid(tw):
			out.append(tw)
	return out


## A card set up for the week, 26 -> 52 akademis against 65 (40% -> 80%)
## and energy 80 -> 62, mood 40 -> 55.
func _week_card() -> DaySummaryStudentRow:
	var inst := _card()
	inst.setup_week_row(_student_with_week(
		{"akademis": 26.0, "energy": 80.0, "mood": 40.0},
		{"akademis": 52.0, "energy": 62.0, "mood": 55.0}))
	return inst


func test_a_stat_row_reports_the_delta_it_shows() -> void:
	var inst := _week_card()
	assert_eq(inst.stat_rows[0].shown_delta(), 26.0, "the week's akademis gain")
	assert_eq(inst.stat_rows[1].shown_delta(), 0.0, "seni did not move")


## Before its turn a card waits on Monday: every number at +0, every
## track and needs bar where the week began, the chevron not yet shown.
func test_a_rewound_week_card_waits_on_monday() -> void:
	var inst := _week_card()
	inst.rewind_week()
	var row: DaySummaryStatRow = inst.stat_rows[0]
	assert_true(absf(row.track.value - 40.0) <= 0.01, "the track is back on Monday's 26/65")
	assert_eq(row.value.text, "+0/65", "the number waits at +0")
	assert_true(row.chevron.visible and row.chevron.modulate.a == 0.0,
		"the chevron is armed but not yet shown")
	assert_true(absf(inst.energy_bar.value - 80.0) <= 0.01, "energy on Monday's 80")
	assert_true(absf(inst.mood_bar.value - 40.0) <= 0.01, "mood on Monday's 40")


func test_a_rows_count_lands_on_the_week_in_its_own_time() -> void:
	var inst := _week_card()
	inst.rewind_week()
	_run_and_step(func(): inst.stat_rows[0].play_count(0.2), 0.3)
	assert_eq(inst.stat_rows[0].value.text, "+26/65", "the count lands on the week's gain")
	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01, "and the track on 52/65")


func test_a_rows_count_is_still_running_before_its_time_is_up() -> void:
	var inst := _week_card()
	inst.rewind_week()
	_run_and_step(func(): inst.stat_rows[0].play_count(0.4), 0.1)
	assert_true(inst.stat_rows[0].value.text != "+26/65",
		"a quarter of the way in, the number has not landed")


## A skip lands everything at once, and the counts it interrupted must not
## keep writing half-way numbers over it.
func test_landing_a_week_card_stops_its_counts() -> void:
	var inst := _week_card()
	inst.rewind_week()
	var tweens := _new_tweens(func(): inst.stat_rows[0].play_count(0.4))
	inst.land_week()
	assert_eq(inst.stat_rows[0].value.text, "+26/65", "final number at once")
	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01, "final track at once")
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01, "final energy at once")
	assert_true(inst.stat_rows[0].chevron.modulate.a == 1.0, "the chevron shown")
	for tw in tweens:
		if tw.is_valid():
			assert_false(tw.is_running(), "an interrupted count must be stopped")


func test_the_needs_bars_travel_the_week_on_their_own_call() -> void:
	var inst := _week_card()
	inst.rewind_week()
	var tokens := DesignTokens.load_default()
	_run_and_step(func(): inst.play_needs_week(), tokens.dur_slow + 0.2)
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01, "energy travels to tonight's 62")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01, "mood travels to tonight's 55")


## The pop grows from the number itself: the stat number is right-aligned
## on a wide label, so its pivot sits right of the label's middle.
func test_a_pop_punches_about_the_number() -> void:
	var inst := _week_card()
	inst.land_week()
	var row: DaySummaryStatRow = inst.stat_rows[0]
	var tokens := DesignTokens.load_default()
	var tweens := _new_tweens(func(): row.land_pop(1.2))
	for tw in tweens:
		tw.custom_step(tokens.dur_instant)
	assert_true(row.value.scale.x > 1.1, "mid-pop the number is punched up")
	assert_true(row.value.pivot_offset.x > row.value.size.x * 0.5,
		"about the right-aligned text, not the label's middle")
	for tw in tweens:
		tw.custom_step(tokens.dur_normal + 0.1)
	assert_true(absf(row.value.scale.x - 1.0) <= 0.02, "and it settles back")


## The nightly popup's own path is untouched by the weekly API.
func test_the_week_api_leaves_the_nightly_play_gain_alone() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/DaySummaryStatRow.gd")
	var body := src.substr(src.find("func play_gain("), src.find("func _play_burst(") - src.find("func play_gain("))
	assert_false(body.contains("_reveal_tweens"), "play_gain keeps its own, untracked tweens")
	assert_contains(src, 'play_sfx(&"tally", pitch)', "the week pop climbs")
	assert_contains(src, 'play_sfx(&"tally")', "the nightly burst still plays the plain tally")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="result_checkup", session_id="weekly-report-reveal@bcf0")`
Expected: the new tests FAIL (methods missing); the existing ones still pass.

- [ ] **Step 3a: Implement the row** — in `Scripts/SchoolSimulation/DaySummaryStatRow.gd`, add after `var _standing_current: float = 0.0`:

```gdscript
## The in-flight fill and count of this row's weekly reveal, held so land()
## can stop them: a skip must not leave a number still counting.
var _reveal_tweens: Array[Tween] = []
```

Append at the end of the file:

```gdscript
# ── The weekly reveal (2026-09-14 weekly-report-reveal spec) ─────────
# ResultCheckup plays a card's rows one at a time rather than all at once,
# so the row splits play_gain's single gesture into its beats. play_gain
# and _play_burst above stay exactly as the nightly popup uses them.

## The delta set_stat last cached: what ResultCheckup's reveal timeline
## reads to decide whether this row pops.
func shown_delta() -> float:
	return _delta


## The reveal's opening state: the track back on Monday, the number at +0,
## the chevron armed but transparent until play_count pops it in. Call
## set_stat first.
func rewind() -> void:
	_stop_reveal()
	track.value = _fill_from
	value.text = format_value(0.0, _target)
	value.scale = Vector2.ONE
	if chevron.visible:
		chevron.modulate.a = 0.0


## This row's turn: the track fills and the number counts up over
## `seconds`, and a gaining row's chevron pops in as it starts. Never
## awaited; the caller schedules land_pop() for when the count lands.
func play_count(seconds: float) -> void:
	_stop_reveal()
	var fill := Juice.fill_bar(track, _fill_to, seconds)
	var count := Juice.count_up_formatted(value, 0.0, _delta,
		func(v: float) -> String: return format_value(v, _target), 0.0, seconds)
	for tw in [fill, count]:
		if tw != null:
			_reveal_tweens.append(tw)
	if chevron.visible:
		Juice.pop_in(chevron)


## A gaining row's reward, on the beat its count lands: the number punches
## about its own text, the authored burst fires from it, and the tally
## plays at `pitch`, the report's climbing step. The burst stays silent so
## the climbing tally is the one sound. Editor-gated like _play_burst.
func land_pop(pitch: float) -> void:
	var center := Juice.text_center(value)
	Juice.punch(value, center)
	if Engine.is_editor_hint():
		return
	var burst_scene: PackedScene = load(BURST_SCENE)
	var fx := burst_scene.instantiate() as RewardParticles
	fx.plays_sfx = false
	fx.position = value.position + center
	add_child(fx)
	fx.fire()
	AudioDirector.play_sfx(&"tally", pitch)


## The row on its final values at once: the skip's landing. Stops the
## reveal's fill and count first, so neither writes over it afterwards.
func land() -> void:
	_stop_reveal()
	track.value = _fill_to
	value.text = format_value(_delta, _target)
	value.scale = Vector2.ONE
	_reset_chevron()


func _stop_reveal() -> void:
	for tw in _reveal_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_reveal_tweens.clear()
```

- [ ] **Step 3b: Implement the card** — in `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, add after `var _mood_delta: float = 0.0`:

```gdscript
## Where the two needs bars end the week, cached by setup_week_row so the
## weekly reveal can rewind them to Monday and travel back.
var _energy_to: float = 0.0
var _mood_to: float = 0.0
```

In `setup_week_row`, in the `student == null` branch add `_energy_to = 0.0` and `_mood_to = 0.0` beside `_energy_from = 0.0`; after `_mood_from = clampf(...)` in the main path add:

```gdscript
	_energy_to = student.energy
	_mood_to = student.mood
```

Add after `play_week_gain`:

```gdscript
## The weekly reveal's opening state (2026-09-14 weekly-report-reveal
## spec): every stat row back on Monday with its number at +0, and both
## needs bars on Monday's values. Call setup_week_row first.
func rewind_week() -> void:
	for row in stat_rows:
		row.rewind()
	energy_bar.value = _energy_from
	mood_bar.value = _mood_from


## A card's opening gesture in the weekly reveal, played as it lands: both
## needs bars travel from Monday to tonight. The stat rows wait for their
## own turns (DaySummaryStatRow.play_count).
func play_needs_week() -> void:
	energy_bar.value = _energy_from
	mood_bar.value = _mood_from
	Juice.fill_bar(energy_bar, _energy_to)
	Juice.fill_bar(mood_bar, _mood_to)


## Everything on its final values at once: the skip's landing.
func land_week() -> void:
	for row in stat_rows:
		row.land()
	energy_bar.value = _energy_to
	mood_bar.value = _mood_to
```

- [ ] **Step 4: No-op `script_patch` on both scripts, then run**

Run: `test_run(suite="result_checkup", session_id=...)`, `test_run(suite="day_summary", ...)`, `test_run(suite="card_standing_mode", ...)`, `test_run(suite="audio_coverage", ...)`, `test_run(suite="viewport_editability", ...)`
Expected: all PASS. (`land_pop` has one `play_sfx`; `fx.fire()` is not a local sfx function, so the double-fire scan stays clean.)

- [ ] **Step 5: Commit** both scripts and the suite — `feat(weekly-reveal): the week card rewinds, counts, pops and lands row by row`.

---

### Task 5: ResultCheckup plays the reveal, and a tap skips it

**Files:**
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd` (header, exports, vars, `initialize_checkup`, `_play_entrance`; new helpers)
- Modify: `tests/test_result_checkup.gd` (update two scans; add the screen tests)
- Modify: `docs/superpowers/specs/2026-09-14-weekly-report-reveal-design.md` only if the build diverges from it

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: `ResultCheckup.pop_pitch(index: int, step: float, ceiling: float) -> float` (static), `skip_reveal()`, `_prepare_reveal()`, `_land_all()`, `_build_steps(start := 0.0) -> Array`, and the Reveal `@export`s `card_lead_seconds`, `count_seconds`, `row_gap_seconds`, `quiet_row_seconds`, `card_gap_seconds`, `line_gap_seconds`, `finale_gap_seconds`, `pitch_step`, `pitch_max`.

- [ ] **Step 1: Write the failing tests** — in `tests/test_result_checkup.gd`:

Replace the last two assertions of `test_the_checkup_no_longer_hand_builds_its_stat_bars` (the `play_week_gain(` pair) with:

```gdscript
	assert_true(src.contains("play_count("),
		"the checkup must replay the week, row by row")
```

Replace `test_the_checkup_fills_its_cards_after_they_land` entirely with:

```gdscript
## The weekly report is one reward at a time now (2026-09-14 reveal spec):
## the cards no longer stagger in together, the screen plays the
## WeekReportReveal timeline, each card waiting rewound until its turn.
func test_the_checkup_plays_its_cards_through_the_reveal_timeline() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("Juice.stagger_in(cards)"),
		"the cards no longer land together")
	assert_true(src.contains("WeekReportReveal.build("), "the screen plays the timeline")
	assert_true(src.contains("rewind_week()"), "each card waits on Monday")
	assert_true(src.contains("play_needs_week()"), "and travels its needs bars as it lands")
```

Add at the end of the screen section (after `test_selanjutnya_disables_both_buttons_before_the_fade` or before `_source`):

```gdscript
# ------------------------------------------------------- the reveal

## A screen filled for a week in which the first student gained 12 akademis
## and the minigames went 2 won / 1 lost, with 1.000 coins earned.
func _revealed_checkup():
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.students[0].akademis += 12.0
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Selasa", "category": "Olahraga", "game_name": "Lomba", "won": false},
		{"day": "Kamis", "category": "SeniBudaya", "game_name": "Batik", "won": true},
	])
	inst.initialize_checkup(manager, 1000)
	return inst


func test_each_pop_sounds_one_step_higher_and_caps() -> void:
	var script = load(_CHECKUP_SCRIPT)
	assert_eq(script.pop_pitch(0, 0.06, 1.6), 1.0, "the first pop is at normal pitch")
	assert_true(absf(script.pop_pitch(3, 0.06, 1.6) - 1.18) <= 0.0001, "three steps up")
	assert_eq(script.pop_pitch(100, 0.06, 1.6), 1.6, "never past the ceiling")


func test_the_reveal_pacing_is_exported() -> void:
	var inst = _themed_checkup()
	var names: Array = []
	for p in inst.get_property_list():
		names.append(p.name)
	for knob in ["card_lead_seconds", "count_seconds", "row_gap_seconds",
			"quiet_row_seconds", "card_gap_seconds", "line_gap_seconds",
			"finale_gap_seconds", "pitch_step", "pitch_max"]:
		assert_true(names.has(knob), "the Reveal group exports " + knob)


## The opening frame is the backdrop alone: ribbon, cards and summary lines
## transparent, each card rewound to Monday, each line reading 0.
func test_the_reveal_opens_on_the_backdrop_alone() -> void:
	var inst = _revealed_checkup()
	inst._prepare_reveal()
	assert_eq(inst.title_banner.modulate.a, 0.0, "the ribbon waits")
	var list: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	for card in list.get_children():
		assert_eq(card.modulate.a, 0.0, "every card waits")
	var first: DaySummaryStudentRow = list.get_child(0)
	assert_eq(first.stat_rows[0].value.text,
		"+0/%d" % int(round(first.stat_rows[0]._target)), "rewound to +0")
	for path in ["Margin/Layout/Summary/Lines/CoinRow",
			"Margin/Layout/Summary/Lines/EventWonLabel",
			"Margin/Layout/Summary/Lines/EventLostLabel"]:
		assert_eq(inst.get_node(path).modulate.a, 0.0, path + " waits")
	assert_eq(inst.money_label.text, "0", "the coins wait at 0")
	assert_eq(inst.event_won_label.text, "EVENT BERHASIL : 0", "won waits at 0")


## A skip's landing: every card and line fully shown on its final value.
func test_landing_the_reveal_shows_every_final_value() -> void:
	var inst = _revealed_checkup()
	inst._prepare_reveal()
	inst._land_all()
	var list: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	for card in list.get_children():
		assert_eq(card.modulate.a, 1.0, "every card shown")
	var first: DaySummaryStudentRow = list.get_child(0)
	assert_eq(first.stat_rows[0].value.text,
		"+12/%d" % int(round(first.stat_rows[0]._target)), "the week's gain")
	assert_eq(inst.title_banner.modulate.a, 1.0, "the ribbon shown")
	assert_eq(inst.money_label.text, "+1.000", "the coins")
	assert_eq(inst.event_won_label.text, "EVENT BERHASIL : 2", "won")
	assert_eq(inst.event_lost_label.text, "EVENT GAGAL : 1", "lost")
	assert_eq(inst.get_node("Margin/Layout/Summary/Lines/CoinRow").modulate.a, 1.0,
		"the coin row shown")


## The screen feeds the timeline every card's rows and the three lines.
func test_the_timeline_reads_every_card_and_line() -> void:
	var inst = _revealed_checkup()
	var steps: Array = inst._build_steps()
	var rows := 0
	var lines := 0
	var pops := 0
	for s in steps:
		if s["kind"] == WeekReportReveal.ROW_COUNT:
			rows += 1
		elif s["kind"] == WeekReportReveal.LINE:
			lines += 1
		elif s["kind"] == WeekReportReveal.ROW_POP:
			pops += 1
	var list: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	assert_eq(rows, list.get_child_count() * 3, "three rows per card")
	assert_eq(lines, 3, "coins, won, lost")
	assert_eq(pops, 1, "only the student who gained pops")


## A tap anywhere skips -- but only while the reveal is playing, so Logs,
## Selanjutnya and the drag-scroll behave normally afterwards. It is
## _input() for StatCheck's reason: the full-screen controls would claim
## the tap first.
func test_a_tap_skips_only_while_the_reveal_plays() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	var input_at := src.find("func _input(")
	assert_true(input_at != -1, "the skip listens in _input()")
	var body := src.substr(input_at, src.find("\nfunc ", input_at + 1) - input_at)
	assert_contains(body, "_revealing", "gated on the reveal playing")
	assert_contains(body, "skip_reveal()", "and it skips")
	var skip_at := src.find("func skip_reveal(")
	var skip := src.substr(skip_at, src.find("\nfunc ", skip_at + 1) - skip_at)
	assert_contains(skip, "_reveal_tween.kill()", "the timeline stops")
	assert_contains(skip, "_land_all()", "everything lands")
	assert_contains(skip, "_finale(true)", "and the finale plays")


## Under the editor the entrance returns before scheduling anything, and a
## skip with nothing playing does nothing -- in particular it never lands
## the cards over the values setup_week_row wrote.
func test_the_editor_never_plays_or_skips_the_reveal() -> void:
	var inst = _revealed_checkup()
	assert_false(inst._revealing, "under the editor the reveal never starts")
	assert_true(inst._reveal_tween == null, "and nothing is ever scheduled")
	inst._prepare_reveal()
	inst.skip_reveal()
	var first: DaySummaryStudentRow = inst.get_node("Margin/Layout/CardsScroll/CardsList").get_child(0)
	assert_eq(first.modulate.a, 0.0,
		"a skip while nothing plays is a no-op: the rewound card stays put")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="result_checkup", session_id="weekly-report-reveal@bcf0")`
Expected: the new and updated tests FAIL (no timeline yet).

- [ ] **Step 3: Implement** — in `Scripts/SchoolSimulation/ResultCheckup.gd`:

(a) Extend the header, replacing its second paragraph with:

```gdscript
## Everything visual is an authored scene. This script fills the labels,
## instances the cards and the Logs sheet, and plays the reveal
## (2026-09-14 weekly-report-reveal spec): one reward at a time -- each
## card lands, its three stats count and pop in turn, the three summary
## lines follow, and a tap anywhere lands the lot at once. The rhythm is
## worked out by WeekReportReveal and paced by the Reveal exports.
```

(b) After the `Wiring` group, add:

```gdscript
# ── Reveal ───────────────────────────────────────────────────────────
@export_group("Reveal")
## Seconds between a card popping in and its first stat row starting.
@export var card_lead_seconds: float = 0.35
## Seconds a gaining stat row, or a non-zero summary line, takes to count.
@export var count_seconds: float = 0.35
## Pause after a gaining row pops before the next row starts.
@export var row_gap_seconds: float = 0.08
## Seconds a row that did not gain takes to settle: short, and silent.
@export var quiet_row_seconds: float = 0.15
## Pause after a card's last row before the next card lands.
@export var card_gap_seconds: float = 0.15
## Pause between one summary line and the next.
@export var line_gap_seconds: float = 0.12
## Pause after the last summary line before the confetti and the buttons.
@export var finale_gap_seconds: float = 0.2
## How much higher each pop sounds than the one before (1.0 = normal).
@export var pitch_step: float = 0.06
## The highest a pop climbs, however many gains the week has.
@export var pitch_max: float = 1.6
```

(c) Add `@onready var coin_row: HBoxContainer = $Margin/Layout/Summary/Lines/CoinRow` beside `money_label`.

(d) Add after `var _logs_popup: Control = null`:

```gdscript
## The cards this report shows, top to bottom.
var _cards: Array = []
## The values the summary lines count to, top to bottom: coins, won, lost.
var _line_values: Array = [0, 0, 0]
## True while the reveal plays; a tap only skips while it is.
var _revealing: bool = false
## The reveal's one timeline tween, held so a skip can kill it.
var _reveal_tween: Tween = null
## The summary lines' in-flight counts, held so a skip can stop them.
var _line_tweens: Array[Tween] = []
```

(e) In `initialize_checkup`, after the three label writes, add
`_line_values = [week_earnings, int(recap["minigames_won"]), int(recap["minigames_lost"])]`;
after `var cards: Array = []` loop, replace `_play_entrance(cards)` with:

```gdscript
	_cards = cards
	_play_entrance()
```

and in the `student_manager == null` early return path set `_cards = []` before `return`.

(f) Replace `_play_entrance` with the reveal and its helpers:

```gdscript
## The pitch of a report's `index`-th pop: one `step` higher per pop, never
## past `ceiling`. Restarts each week, because each report is a new screen.
static func pop_pitch(index: int, step: float, ceiling: float) -> float:
	return minf(1.0 + float(index) * step, ceiling)


func _play_entrance() -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return
	_prepare_reveal()
	var t := Juice.tokens()
	var fader := create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished
	if not is_inside_tree():
		return
	Juice.pop_in(title_banner)
	_revealing = true
	_reveal_tween = create_tween().set_parallel(true)
	for step in _build_steps(t.dur_fast):
		_reveal_tween.tween_callback(_run_step.bind(step)).set_delay(float(step["at"]))


## The reveal's opening frame: the backdrop alone. The ribbon, every card
## and every summary line wait transparent (modulate, so nothing reflows as
## they arrive); each card is rewound to Monday and each line reads 0. Not
## editor-gated: it only writes state, so the suite can check it.
func _prepare_reveal() -> void:
	title_banner.modulate.a = 0.0
	for card in _cards:
		card.modulate.a = 0.0
		card.rewind_week()
	for i in _line_values.size():
		_line_node(i).modulate.a = 0.0
		_line_label(i).text = _line_text(i, 0.0)


## This week's reveal as a timeline: every card's three stat deltas and the
## three summary values, paced by the Reveal exports, starting at `start`.
func _build_steps(start: float = 0.0) -> Array:
	var rows: Array = []
	for card in _cards:
		var deltas: Array = []
		for row in card.stat_rows:
			deltas.append(row.shown_delta())
		rows.append(deltas)
	return WeekReportReveal.build(rows, _line_values, {
		"start": start,
		"card_lead": card_lead_seconds,
		"count": count_seconds,
		"row_gap": row_gap_seconds,
		"quiet_row": quiet_row_seconds,
		"card_gap": card_gap_seconds,
		"line_gap": line_gap_seconds,
		"finale_gap": finale_gap_seconds,
	})


## One beat of the timeline. An if/elif chain rather than a match: the
## audio suite's double-fire scan reads elif as "these branches exclude each
## other", and a match's arms as one straight path.
func _run_step(step: Dictionary) -> void:
	var kind: StringName = step["kind"]
	if kind == WeekReportReveal.CARD:
		_land_card(int(step["card"]))
	elif kind == WeekReportReveal.ROW_COUNT:
		_cards[int(step["card"])].stat_rows[int(step["row"])].play_count(float(step["seconds"]))
	elif kind == WeekReportReveal.ROW_POP:
		_cards[int(step["card"])].stat_rows[int(step["row"])].land_pop(
			pop_pitch(int(step["pop_index"]), pitch_step, pitch_max))
	elif kind == WeekReportReveal.LINE:
		_show_line(int(step["row"]), float(step["seconds"]))
	elif kind == WeekReportReveal.LINE_POP:
		_pop_line(int(step["row"]), pop_pitch(int(step["pop_index"]), pitch_step, pitch_max))
	elif kind == WeekReportReveal.FINALE:
		_finale(false)


## A card's arrival: it pops in, its needs bars travel, and the list
## scrolls just far enough to show all of it (two cards fit on screen).
func _land_card(i: int) -> void:
	var card: Control = _cards[i]
	Juice.pop_in(card)
	card.play_needs_week()
	var target := WeekReportReveal.scroll_to_show(card.position.y,
		card.position.y + card.size.y, cards_scroll.size.y,
		float(cards_scroll.scroll_vertical))
	if int(target) != cards_scroll.scroll_vertical:
		var tw := create_tween()
		tw.tween_property(cards_scroll, "scroll_vertical", int(target),
			Juice.tokens().dur_normal).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## The summary line that pops in, top to bottom: the coin row, then the
## two event tallies.
func _line_node(i: int) -> Control:
	return [coin_row, event_won_label, event_lost_label][i]


## The label a summary line counts on.
func _line_label(i: int) -> Label:
	return [money_label, event_won_label, event_lost_label][i]


## How a summary line reads at value `v`.
func _line_text(i: int, v: float) -> String:
	var n := int(round(v))
	if i == 0:
		return format_earnings(n)
	elif i == 1:
		return event_won_prefix + str(n)
	return event_lost_prefix + str(n)


## A summary line's turn: it pops in and counts from 0 over `seconds`. A
## zero line (seconds 0) has nothing to count and arrives reading 0.
func _show_line(i: int, seconds: float) -> void:
	Juice.pop_in(_line_node(i))
	if seconds > 0.0:
		var tw := Juice.count_up_formatted(_line_label(i), 0.0, float(_line_values[i]),
			func(v: float) -> String: return _line_text(i, v), 0.0, seconds)
		if tw != null:
			_line_tweens.append(tw)


## A non-zero summary line lands: the number punches about its own text,
## with the coin cue for the money line and the pop cue for the tallies,
## both at the report's climbing pitch.
func _pop_line(i: int, pitch: float) -> void:
	var label := _line_label(i)
	Juice.punch(label, Juice.text_center(label))
	if i == 0:
		AudioDirector.play_sfx(&"coin", pitch)
	else:
		AudioDirector.play_sfx(&"pop", pitch)


## Land the whole reveal at once: the timeline stops, every card and line
## shows its final values, and the finale plays. Killing is safe here --
## unlike StatCheck's rush, nothing awaits this tween.
func skip_reveal() -> void:
	if not _revealing:
		return
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	_land_all()
	_finale(true)


## Every card and summary line fully shown on its final value: the skip's
## landing. Not editor-gated: it only writes state.
func _land_all() -> void:
	for tw in _line_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_line_tweens.clear()
	title_banner.modulate.a = 1.0
	title_banner.scale = Vector2.ONE
	for card in _cards:
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.land_week()
	for i in _line_values.size():
		var node := _line_node(i)
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
		var label := _line_label(i)
		label.scale = Vector2.ONE
		label.text = _line_text(i, float(_line_values[i]))


## The end of the reveal, played or skipped: the paper confetti and the
## reward cue when a card gained ground, then the buttons. A skipped flat
## week still gets one tally, so the tap lands on a sound.
func _finale(skipped: bool) -> void:
	_revealing = false
	var week_gained := false
	for card in _cards:
		if card.gained_ground():
			week_gained = true
			break
	if week_gained:
		AudioDirector.play_sfx(&"reward")
		var celebration_scene: PackedScene = load(_CELEBRATION_SCENE)
		var celebration := celebration_scene.instantiate() as RewardParticles
		celebration.position = get_node("Celebration").position
		add_child(celebration)
		celebration.fire()
	elif skipped:
		AudioDirector.play_sfx(&"tally")
	var t := Juice.tokens()
	for b in [logs_button, next_button]:
		var tw := create_tween()
		tw.tween_property(b, "modulate:a", 1.0, t.dur_fast)
		b.disabled = false


## A tap anywhere skips the reveal to its end. _input(), like StatCheck's,
## because the full-screen scroll and cards would otherwise claim the tap
## first. It acts only while the reveal plays, so Logs, Selanjutnya and the
## drag-scroll behave normally afterwards.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _revealing:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		get_viewport().set_input_as_handled()
		skip_reveal()
```

Remove the old `Juice.stagger_in(cards)` / `play_week_gain` / timer-based entrance and the old inline celebration block (now in `_finale`).

- [ ] **Step 4: No-op `script_patch` on `ResultCheckup.gd`, then run**

Run: `test_run(suite="result_checkup", ...)`, `audio_coverage`, `viewport_editability`, `script_documentation`, `paper_confetti`, `school_day`, `week_report_reveal`
Expected: all PASS. The double-fire scan must stay clean: `_pop_line` and `_finale` split their cues across `if`/`else`/`elif`, and `_run_step` reaches them only through `elif`s.

- [ ] **Step 5: Commit** `Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd` — `feat(weekly-reveal): the weekly report plays one reward at a time; a tap skips`.

---

### Task 6: See it, run everything, write it down

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (new entry at the top)
- Modify: `CLAUDE.md` (suite/test count line under `## Testing`)

- [ ] **Step 1: Watch it once in the running game.** In the worktree editor: `project_run(session_id=...)`, open the debug overlay's General tab → **⚡ Seed Playtest State**, then reach ResultCheckup through a real week (Lobby → Atur Jadwal → fill the week → StudentList → SchoolDay; use the overlay's cheats to shorten it if it offers them). Take one `editor_screenshot(source="game")` mid-reveal and one after, freezing time in the same `game_eval` as the capture per the memory note (`Engine.time_scale` 0.02 when particles must stay visible). Judge at full size: a card landing on its own, a number mid-punch with sparkles off the number (not the chevron), later cards hidden, the summary hidden until its turn, then everything shown with the buttons. Then tap mid-reveal once and confirm it lands everything and enables the buttons. If reaching ResultCheckup this way proves impractical, say so in the report instead of improvising a data-less instance (memory: a bare ResultCheckup in `game_eval` hung the editor).
- [ ] **Step 2: Full suite.** Run: `test_run(session_id="weekly-report-reveal@bcf0")` (no suite). It can drop the bridge; results that arrived still count. Afterwards `git status`, and `git checkout -- Assets/Audio/default_bus_layout.tres` (and `Assets/Theme/kejartes_theme.tres` if the rebake suite changed it with no token edits). Fix any failure this branch caused and re-run; a failure unrelated to the branch is reported, not fixed.
- [ ] **Step 3: Docs.** Add a CHANGELOG entry (newest first) summarising the reveal, the new `WeekReportReveal`, the new Juice/AudioDirector API and the new suite. Update CLAUDE.md's `107 suites, 1508 tests (2026-09-14)` line to the full run's counts.
- [ ] **Step 4: Commit** the two docs — `docs(weekly-reveal): changelog and suite count`.
