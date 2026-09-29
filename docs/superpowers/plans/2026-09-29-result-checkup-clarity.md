# ResultCheckup Clarity Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the weekly report's three pills self-explanatory (caption, Lobby coin, navy-rimmed number) and make its student cards read and move exactly like the Daily Results cards.

**Architecture:** Pills get a `Caption` Label and two ThemeFactory variations; the banner supplies caption text. The weekly card keeps computing week deltas but dresses and animates through the daily path (`_apply_look(false)` + `play_gain`). The now-dead weekly-only code (chip readout, week needs bars, staged reveal) is then deleted with its scene nodes, theme variations and tests.

**Tech Stack:** Godot 4.6 GDScript, `McpTestSuite` suites run via the godot-ai MCP `test_run` tool, ThemeFactory → `kejartes_theme.tres` bake.

Spec: `docs/superpowers/specs/2026-09-29-result-checkup-clarity-design.md`.

## Global Constraints

- Work only in `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/checkup-clarity/` (branch `feat/result-checkup-clarity`). Every path below is relative to it. Never touch the main checkout.
- Tests run through the worktree's own editor session (`checkup-clarity@…`; re-list with `session_manage(op="list")`, pass `session_id` on every godot-ai call).
- Never add a `theme_override_*` (layout constants excepted). Styling is ThemeFactory variations, then rebake.
- `.tscn` edits go through the editor (`scene_open` → node ops → `scene_save`), scene work before script work; after any `scene_save`, `git diff HEAD -- '*.gd'` for files you did not edit.
- After editing a `.gd` from outside the editor, do a no-op `script_patch` on it before `test_run`.
- No test may `await`. Every new `@export`/script keeps a `##` doc line (`test_script_documentation`).
- Navy is `tokens.event_warning_ink` (#1D196E); no second token with the same hex.
- Captions: `UANG DIDAPAT`, `MINIGAME MENANG`, `EVENT TERJADI`.
- Caption style: `font_display`, `tokens.font_caption` (22), navy `font_color`, no outline.
- Pill number: white `font_color`, navy `font_outline_color`, `outline_size` unchanged (`tokens.text_outline_size`).
- Money icon on the banner: `res://Assets/Images/UI/uang.png`. `Placeholders/icon_uang.svg` stays (RunResult uses it).
- Daily Results popup behaviour must not change.
- Commits: Conventional Commits with scope, message via `git commit -F <file>`, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Rebake: `test_run(suite="theme_rebake")` writes `Assets/Theme/kejartes_theme.tres`; then restart the worktree editor before the next `scene_save` (the cached theme would otherwise be written back). Diff the bake: only the intended variations may change.

---

### Task 1: Pill theme variations

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd:3288-3297` (the `RecapPillValueLabel` block)
- Modify: `tests/test_theme_factory.gd:305-330` (`DISPLAY_ROSTER`)
- Modify: `tests/test_result_checkup.gd:703-712` (`test_theme_carries_the_recap_variations`)
- Regenerate: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces: theme variations `RecapPillValueLabel` (white, navy rim) and `RecapPillCaptionLabel` (display font, 22 px, navy). Task 2's scene uses both names.

- [ ] **Step 1: Write the failing test** — append to `tests/test_result_checkup.gd` after `test_theme_carries_the_recap_variations`:

```gdscript
## The pill number is white with the event warning's navy rim, and the
## caption under it is the display face in the same navy (2026-09-29
## clarity spec).
func test_pill_number_and_caption_wear_the_navy() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_color("font_color", "RecapPillValueLabel"), Color.WHITE,
		"the pill number is white")
	assert_eq(theme.get_color("font_outline_color", "RecapPillValueLabel"),
		tokens.event_warning_ink, "with a navy rim")
	assert_eq(theme.get_constant("outline_size", "RecapPillValueLabel"),
		tokens.text_outline_size, "at the usual rim width")
	assert_true(theme.get_type_list().has("RecapPillCaptionLabel"),
		"the caption variation is built")
	assert_eq(theme.get_font("font", "RecapPillCaptionLabel"), tokens.font_display,
		"the caption is the heading face")
	assert_eq(theme.get_font_size("font_size", "RecapPillCaptionLabel"),
		tokens.font_caption, "at caption size, so each caption fits on one line")
	assert_eq(theme.get_color("font_color", "RecapPillCaptionLabel"),
		tokens.event_warning_ink, "in navy")
```

Also add `"RecapPillCaptionLabel"` to the `for variation in [...]` list in `test_theme_carries_the_recap_variations`.

- [ ] **Step 2: Run to verify it fails**

Run: `test_run(suite="result_checkup", test_name="navy", session_id=...)`
Expected: FAIL (`font_color` is `text_primary`, caption type missing).

- [ ] **Step 3: Implement** — replace the `RecapPillValueLabel` block in `ThemeFactory.gd` with:

```gdscript
	# The pill's number: white on a navy rim, the event warning's own ink,
	# so it reads on the near-white tile (2026-09-29 clarity spec).
	theme.add_type("RecapPillValueLabel")
	theme.set_type_variation("RecapPillValueLabel", "Label")
	theme.set_font_size("font_size", "RecapPillValueLabel", tokens.font_h2)
	theme.set_color("font_color", "RecapPillValueLabel", Color.WHITE)
	theme.set_constant("outline_size", "RecapPillValueLabel", tokens.text_outline_size)
	theme.set_color("font_outline_color", "RecapPillValueLabel", tokens.event_warning_ink)
	if tokens.font_display != null:
		theme.set_font("font", "RecapPillValueLabel", tokens.font_display)

	# What the number counts, under it: the heading face at caption size.
	theme.add_type("RecapPillCaptionLabel")
	theme.set_type_variation("RecapPillCaptionLabel", "Label")
	theme.set_font_size("font_size", "RecapPillCaptionLabel", tokens.font_caption)
	theme.set_color("font_color", "RecapPillCaptionLabel", tokens.event_warning_ink)
	if tokens.font_display != null:
		theme.set_font("font", "RecapPillCaptionLabel", tokens.font_display)
```

Add `"RecapPillCaptionLabel",` after `"RecapPillValueLabel",` in `DISPLAY_ROSTER` (`tests/test_theme_factory.gd`).

- [ ] **Step 4: Rebake and run**

No-op `script_patch` on `ThemeFactory.gd`, then `test_run(suite="theme_rebake")`, then `test_run(suite="result_checkup")` and `test_run(suite="theme_factory")`.
Expected: all PASS. `git diff --stat Assets/Theme/kejartes_theme.tres` shows a small change; open the diff and confirm only the two variations moved.

- [ ] **Step 5: Restart the worktree editor** (stop its PID after checking the CommandLine contains `checkup-clarity`, relaunch detached with `Invoke-CimMethod Win32_Process Create`, re-list the session id).

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd tests/test_result_checkup.gd
git commit -F <msgfile>   # feat(result-checkup): navy-rimmed pill numbers and a caption style
```

---

### Task 2: Captions and the Lobby coin on the pills

**Files:**
- Modify (editor): `Scenes/SchoolSimulation/WeekRecapPill.tscn` — add `Column/Caption`
- Modify (editor): `Scenes/SchoolSimulation/WeekRecapBanner.tscn` — `icon_uang` → `uang.png`
- Modify: `Scripts/SchoolSimulation/WeekRecapPill.gd` (`set_pill`, new `caption_label`)
- Modify: `Scripts/SchoolSimulation/WeekRecapBanner.gd:147-155` (`set_recap`), new `PILL_CAPTION` const
- Test: `tests/test_result_checkup.gd` (`test_pill_scene_stacks_its_icon_above_its_value`, `test_pill_set_pill_writes_text_and_tint`, `test_banner_writes_its_three_totals_in_one_ink`, `test_banner_uses_the_new_tile_icons`)

**Interfaces:**
- Consumes: `RecapPillCaptionLabel`, `RecapPillValueLabel` (Task 1).
- Produces: `WeekRecapPill.set_pill(icon_texture: Texture2D, value_text: String, caption_text: String) -> void`; `WeekRecapBanner.PILL_CAPTION: Dictionary` (`"uang"`, `"menang"`, `"event"` → caption string).

- [ ] **Step 1: Write the failing tests** — replace the four tests named above with:

```gdscript
func test_pill_scene_stacks_icon_value_and_caption() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	var column := pill.get_node_or_null("Column") as VBoxContainer
	assert_not_null(column, "Icon, Value and Caption share one column")
	var icon := pill.get_node_or_null("Column/Icon")
	var value := pill.get_node_or_null("Column/Value") as Label
	var caption := pill.get_node_or_null("Column/Caption") as Label
	assert_not_null(icon, "Icon is authored")
	assert_not_null(value, "Value is authored")
	assert_not_null(caption, "Caption is authored")
	if icon and value and caption:
		assert_true(icon.get_index() < value.get_index()
			and value.get_index() < caption.get_index(),
			"icon, then number, then what the number counts")
		assert_eq(caption.theme_type_variation, &"RecapPillCaptionLabel",
			"the caption takes its variation")
		assert_eq(caption.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"centred under the number")
	assert_not_null(pill.get_node_or_null("Ring"), "Ring emitter is authored")
	pill.free()


func test_pill_set_pill_writes_text_and_caption() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	pill.set_pill(null, "4.200", "UANG DIDAPAT")
	assert_eq((pill.get_node("Column/Value") as Label).text, "4.200",
		"the value label carries the formatted number")
	assert_eq((pill.get_node("Column/Caption") as Label).text, "UANG DIDAPAT",
		"and the caption says what it counts")
	assert_eq((pill.get_node("Column/Value") as Label).self_modulate, Color.WHITE,
		"no per-pill tint: the theme's white and navy do the work")
	pill.queue_free()


func test_banner_captions_its_three_totals() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(banner)
	banner.set_recap({
		"money_earned": 4200, "minigames_won": 3, "minigames_total": 5,
		"events_count": 2,
	})
	assert_eq(_pill_text(banner, "PillUang"), "4.200", "money is grouped")
	assert_eq(_pill_text(banner, "PillMenang"), "3/5", "won over total")
	assert_eq(_pill_text(banner, "PillEvent"), "2", "a bare event count")
	var want := {"PillUang": "UANG DIDAPAT", "PillMenang": "MINIGAME MENANG",
		"PillEvent": "EVENT TERJADI"}
	for n in want:
		assert_eq((banner.get_node("Pills/%s/Column/Caption" % n) as Label).text,
			want[n], "%s says what it counts" % n)
	banner.queue_free()


func test_banner_uses_the_lobby_coin_and_the_tile_icons() -> void:
	var banner = load(_BANNER_SCENE).instantiate()
	assert_eq(banner.icon_uang.resource_path, "res://Assets/Images/UI/uang.png",
		"money wears the Lobby's coin")
	assert_eq(banner.icon_menang.resource_path, "res://Assets/Images/ResultCheckup/icon_minigame.png",
		"minigames wear the soccer ball")
	assert_eq(banner.icon_event.resource_path, "res://Assets/Images/ResultCheckup/icon_event.png",
		"events wear the checklist notebook")
	banner.free()
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="result_checkup", test_name="pill", session_id=...)` and `test_name="banner"`.
Expected: FAIL (no `Caption` node, old icon, `set_pill` third arg is a Color).

- [ ] **Step 3: Scene work (editor, before any script edit)**

```
scene_open("res://Scenes/SchoolSimulation/WeekRecapPill.tscn")
batch_execute([
  {"command":"create_node","params":{"parent_path":"/WeekRecapPill/Column","type":"Label","name":"Caption"}},
  {"command":"set_property","params":{"path":"/WeekRecapPill/Column/Caption","property":"theme_type_variation","value":"RecapPillCaptionLabel"}},
  {"command":"set_property","params":{"path":"/WeekRecapPill/Column/Caption","property":"horizontal_alignment","value":1}},
  {"command":"set_property","params":{"path":"/WeekRecapPill/Column/Caption","property":"mouse_filter","value":2}},
  {"command":"set_property","params":{"path":"/WeekRecapPill/Column/Caption","property":"autowrap_mode","value":3}}
])
scene_save()
scene_open("res://Scenes/SchoolSimulation/WeekRecapBanner.tscn")
node_set_property(path="/WeekRecapBanner", property="icon_uang", value="res://Assets/Images/UI/uang.png")
scene_save()
```

Then `git diff HEAD -- '*.gd'` (must be empty) and diff both scenes: only the Caption node and the `icon_uang` ext_resource may change.

- [ ] **Step 4: Script work** — in `WeekRecapPill.gd`, below `value_label`:

```gdscript
## What the number counts ("UANG DIDAPAT"), under it in the heading face.
@onready var caption_label: Label = $Column/Caption
```

Replace `set_pill`:

```gdscript
## Populate the pill: its icon, its formatted number and the caption that
## says what the number counts. Colour comes from the theme variations
## (white number on a navy rim, navy caption), never from the caller.
func set_pill(icon_texture: Texture2D, value_text: String,
		caption_text: String) -> void:
	if icon:
		icon.texture = icon_texture
	if value_label:
		value_label.text = value_text
	if caption_label:
		caption_label.text = caption_text
```

In `WeekRecapBanner.gd`, next to the per-pill info const add:

```gdscript
## The caption under each pill's number, in PILL_ORDER's keys.
const PILL_CAPTION := {
	"uang": "UANG DIDAPAT",
	"menang": "MINIGAME MENANG",
	"event": "EVENT TERJADI",
}
```

and replace `set_recap`'s body after `_recap = recap` with:

```gdscript
	pill_uang.set_pill(icon_uang,
		WeekRecap.format_money(recap.get("money_earned", 0)), PILL_CAPTION["uang"])
	pill_menang.set_pill(icon_menang, "%d/%d" % [
		recap.get("minigames_won", 0), recap.get("minigames_total", 0)],
		PILL_CAPTION["menang"])
	pill_event.set_pill(icon_event, str(recap.get("events_count", 0)),
		PILL_CAPTION["event"])
```

Update `set_recap`'s `##` comment: drop the "one ink" sentences; say the captions come from `PILL_CAPTION`.
Grep for any other `set_pill(` caller (`grep -rn "set_pill(" Scripts tests`) and convert it the same way.

- [ ] **Step 5: Run**

No-op `script_patch` on both scripts. `test_run(suite="result_checkup")`, `test_run(suite="week_recap_pill_info_popup")`, `test_run(suite="script_documentation")`.
Expected: all PASS.

- [ ] **Step 6: Commit** — `feat(result-checkup): caption the three pills and use the Lobby coin`, adding the two scenes, two scripts and the test file.

---

### Task 3: The weekly card reads and moves like the daily card

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd:63-77, 197-250, 283-349`
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd:198-203` and its header comment (lines 4-13)
- Test: `tests/test_result_checkup.gd` (week-card section, lines 72-436 and 563-587), `tests/test_day_summary.gd:1470-1515`

**Interfaces:**
- Consumes: existing `setup_row`, `play_gain(delay: float)`, `_apply_look(week: bool)`, `_write_stat_rows`.
- Produces: `setup_week_row(student: StudentData, day_name := "")` now dresses the daily look and shows no needs number/arrow; `play_week_gain`, `rewind_week`, `play_needs_week`, `land_week`, `_stop_needs_travel`, `_needs_tweens`, `_energy_to`, `_mood_to`, `_energy_delta`, `_mood_delta` no longer exist. `format_needs_delta` and `_show_needs_delta` stay (the item/event preview path uses them).

- [ ] **Step 1: Rewrite the week-card tests (failing first)** in `tests/test_result_checkup.gd`:

Keep `test_the_card_carries_a_hidden_delta_label_on_each_needs_bar` (the daily card still carries the hidden labels). Delete `test_the_week_card_wears_the_week_needs_bars`, `test_the_week_card_shows_both_needs_deltas`, `test_the_week_card_rewinds_its_needs_bars_to_monday`, `test_the_week_cards_needs_delta_text_is_untouched_by_play_gain`, `test_the_weekly_reveal_rewinds_and_lands_the_chip`, `test_a_rearmed_row_resets_its_chip`. Replace them with:

```gdscript
## The weekly card is the daily card showing a week (2026-09-29 clarity
## spec): nightly needs colours, the plain "+18/65" readout with the gold
## chevron, and no needs numbers or arrows.
func test_the_week_card_wears_the_daily_look() -> void:
	var inst := _card()
	inst.setup_week_row(_student_with_week(
		{"akademis": 40.0, "energy": 80.0, "mood": 70.0},
		{"akademis": 58.0, "energy": 62.0, "mood": 85.0}))
	assert_eq(inst.energy_bar.theme_type_variation, &"DaySummaryEnergyBar",
		"the nightly energy colour")
	assert_eq(inst.mood_bar.theme_type_variation, &"DaySummaryMoodBar",
		"the nightly mood colour")
	assert_true(inst.stat_rows[0].value.visible, "the plain number shows")
	assert_eq(inst.stat_rows[0].value.text, "+18/65", "the week's movement")
	assert_true(inst.stat_rows[0].chevron.visible, "with the gold chevron on a gain")
	for n in [inst.energy_delta_label, inst.mood_delta_label,
			inst.energy_delta_chevron, inst.mood_delta_chevron]:
		assert_false(n.visible, "%s is hidden, as on the daily card" % n.name)


## play_gain replays the week: the needs bars rewind to Monday and travel
## back, and every gauge lands on tonight's value.
func test_the_week_card_replays_with_play_gain() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 26.0, "energy": 80.0, "mood": 40.0},
		{"akademis": 52.0, "energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)
	inst.play_gain()
	assert_true(absf(inst.stat_rows[0].track.value - 40.0) <= 0.01,
		"the track rewinds to Monday's 26/65")
	assert_true(absf(inst.energy_bar.value - 80.0) <= 0.01,
		"energy rewinds to Monday's 80")
	var tokens := DesignTokens.load_default()
	var fresh := _card()
	fresh.setup_week_row(s)
	_run_and_step(func(): fresh.play_gain(), tokens.dur_slow + 0.2)
	assert_true(absf(fresh.stat_rows[0].track.value - 80.0) <= 0.01,
		"the track lands on tonight's 52/65")
	assert_true(absf(fresh.energy_bar.value - 62.0) <= 0.01, "energy lands")
	assert_true(absf(fresh.mood_bar.value - 55.0) <= 0.01, "mood lands")


## The staged weekly reveal is gone: the card has one replay, play_gain.
func test_the_card_has_no_weekly_only_replay() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	for dead in ["func play_week_gain", "func rewind_week", "func play_needs_week",
			"func land_week", "_needs_tweens", "_energy_to", "_energy_delta"]:
		assert_false(src.contains(dead), "%s left with the weekly reveal" % dead)
```

In `test_the_week_card_rewinds_its_tracks_to_monday` and `test_a_played_week_lands_on_tonights_values` replace `play_week_gain()` with `play_gain()` and delete the `energy_delta_label.text` assertion. In `test_the_week_card_empties_itself_for_a_missing_student` keep as is.

In `test_a_reused_card_drops_the_week_look`: rename to `test_a_reused_card_keeps_the_daily_look`; delete the four `chip_row` / `self_modulate` lines (Task 4 removes chips) — keep the variation, `value.visible` and `chevron.visible` assertions.

Replace the checkup-source tests (around line 563-587) so they expect the daily call:

```gdscript
func test_the_checkup_fills_its_cards_after_they_land() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_true(src.contains("Juice.stagger_in(cards)"),
		"the cards stagger in, as in the daily popup")
	assert_true(src.contains("cards[i].play_gain("),
		"each card replays through the daily play_gain")
	assert_true(src.find("Juice.stagger_in(cards)") < src.find("cards[i].play_gain("),
		"the fill is kicked off after stagger_in")
	assert_false(src.contains("play_week_gain"), "the weekly replay is retired")
```

and change the `src.contains("play_week_gain(")` assertion at line ~575 to `src.contains("play_gain(")`.

In `tests/test_day_summary.gd`, the three chevron tests at ~1476, ~1492, ~1506 call `row.setup_week_row(student)`; switch each to `row.setup_current_row(student)` followed by `row.preview_need("energy", <delta>)` with the delta the test already uses, keeping their rotation/visibility assertions (the preview path owns the chevron now). Update the `##` comment above them (line ~1471) to say so.

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="result_checkup")`. Expected: FAIL on the new/changed tests (week look, `play_week_gain` still present).

- [ ] **Step 3: Implement** — in `DaySummaryStudentRow.gd`:

Delete the `_energy_delta`/`_mood_delta`, `_energy_to`/`_mood_to` and `_needs_tweens` vars (lines 63-77) with their comments.

Replace `setup_week_row` (and its `##` block) with:

```gdscript
## The same card, one week wide: ResultCheckup's end-of-week report.
##
## Every delta is "now minus Monday morning", straight off the week-start
## snapshot record_initial_stats() takes when GameState converts the
## roster. Since the 2026-09-29 clarity pass the card otherwise IS the
## daily card: nightly look, no needs numbers, and play_gain replays it --
## the openings cached here are Monday's, so the replay covers the week.
func setup_week_row(student: StudentData, day_name: String = "") -> void:
	_apply_look(false)
	name_label.text = student.student_name if student != null else ""
	avatar.set_student(student, day_name)
	for n in [energy_delta_label, mood_delta_label,
			energy_delta_chevron, mood_delta_chevron]:
		n.hide()

	if student == null:
		energy_bar.set_need("energy", 0.0)
		mood_bar.set_need("mood", 0.0)
		_energy_from = 0.0
		_mood_from = 0.0
		_write_stat_rows({}, null)
		return

	energy_bar.set_need("energy", student.energy)
	mood_bar.set_need("mood", student.mood)
	# StudentData clamps its needs as it applies them, so on a week that
	# hit 0 or 100 this opening overshoots Monday slightly. Cosmetic, the
	# same trade DaySummaryStatRow documents for the stat tracks.
	_energy_from = clampf(student.energy - student.get_energy_delta(), 0.0, 100.0)
	_mood_from = clampf(student.mood - student.get_mood_delta(), 0.0, 100.0)

	_write_stat_rows({
		"akademis": student.get_akademis_delta(),
		"seni_budaya": student.get_seni_delta(),
		"olahraga": student.get_olahraga_delta(),
	}, student)
```

In `play_gain`, delete the two `if energy_delta_label.visible:` / `if mood_delta_label.visible:` count-up branches, and change its doc's "setup_row/setup_week_row" lines only if they mention the needs numbers.

Delete `play_week_gain`, `rewind_week`, `play_needs_week`, `land_week`, `_stop_needs_travel` and their `##` blocks.

In `ResultCheckup.gd` stage 4, replace `cards[i].play_week_gain(float(i) * t.stagger_step)` with `cards[i].play_gain(float(i) * t.stagger_step)`, and rewrite the stage-4 comment to "the nightly popup's own cadence and call". Fix the file header (lines 4-13) where it says the card is "read a week wide" to add "dressed and replayed exactly like the daily card".

- [ ] **Step 4: Run**

No-op `script_patch` on both scripts. `test_run(suite="result_checkup")`, `test_run(suite="day_summary")`, `test_run(suite="card_standing_mode")`, `test_run(suite="week_report_rehearsal")`.
Expected: all PASS.

- [ ] **Step 5: Commit** — `feat(result-checkup): weekly cards read and move like the daily ones`.

---

### Task 4: Retire the weekly-only chip readout and week needs bars

**Files:**
- Modify (editor): `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` — delete `ChipRow` (with `DeltaChip`, `DeltaChipLabel`, `TargetLabel`)
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd` — chip code and the staged-reveal code
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd:30-35, 104-116` (`NEEDS_VARIATION`, `_apply_look`)
- Modify: `Scripts/Design/ThemeFactory.gd` (`WeekEnergyBar`/`WeekMoodBar` ~3216, `DeltaChip*` ~3327-3351)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`: drop `"DeltaChipLabel"`)
- Modify: `docs/superpowers/design/style-guide.md:85, 119`
- Regenerate: `Assets/Theme/kejartes_theme.tres`
- Test: `tests/test_result_checkup.gd` (chip tests ~157-245, `test_the_week_report_variations_are_built` ~1243)

**Interfaces:**
- Consumes: Task 3 (no caller of `set_chip_mode(true)` remains).
- Produces: `DaySummaryStatRow` without `set_chip_mode`, `shows_chip`, `chip_text`, `target_text`, `chip_variation`, `_chip_mode`, `_sync_readout`, `_reset_chip`, `chip_row`, `delta_chip`, `chip_label`, `target_label`, `rewind`, `play_count`, `land_pop`, `land`, `_stop_reveal`, `_reveal_tweens`. `_apply_look()` takes no argument.

- [ ] **Step 1: Confirm nothing else uses them**

```bash
grep -rn "set_chip_mode\|shows_chip\|chip_text\|target_text\|chip_variation\|chip_row\|delta_chip\|\.rewind()\|play_count(\|land_pop\|\.land()\|WeekEnergyBar\|WeekMoodBar\|DeltaChip" Scripts Scenes tests --include=*.gd --include=*.tscn
```

Expected: hits only in `DaySummaryStatRow.gd/.tscn`, `DaySummaryStudentRow.gd`, `ThemeFactory.gd`, `tests/test_result_checkup.gd`, `tests/test_theme_factory.gd`. `MinigameScoreHUD`'s own `target_label` is unrelated. Anything else: stop and keep that piece.

- [ ] **Step 2: Rewrite the tests (failing first)**

In `tests/test_result_checkup.gd` delete `test_the_chip_reads_the_change_and_its_colour` and `test_the_week_card_marks_gains_and_losses_with_chips`. Keep `test_a_weekly_gain_keeps_its_reward_marker` but rewrite its `##` comment to say the weekly gain now rewards from its chevron, like the nightly one (its assertions already hold once `_gain_marker()` returns the chevron). Then in `test_the_week_report_variations_are_built` delete the `DeltaChip*` and `WeekEnergyBar`/`WeekMoodBar` assertions (lines ~1253-1270). Add:

```gdscript
## The chip readout and the week needs colours left with the weekly look
## (2026-09-29 clarity spec): nothing in the theme or the row keeps them.
func test_the_weekly_only_look_is_retired() -> void:
	var types := (load(_THEME_PATH) as Theme).get_type_list()
	for dead in ["DeltaChipGain", "DeltaChipLoss", "DeltaChipLabel",
			"WeekEnergyBar", "WeekMoodBar"]:
		assert_false(types.has(dead), "%s is no longer baked" % dead)
	var row: Node = load("res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn").instantiate()
	assert_null(row.get_node_or_null("ChipRow"), "the stat row has no chip")
	row.free()
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryStatRow.gd")
	for dead in ["set_chip_mode", "func rewind", "func play_count", "func land"]:
		assert_false(src.contains(dead), "%s left with the weekly reveal" % dead)
```

- [ ] **Step 3: Run to verify it fails** — `test_run(suite="result_checkup", test_name="retired")`. Expected: FAIL.

- [ ] **Step 4: Scene work (editor first)**

```
scene_open("res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn")
node_manage(op="delete", path="/DaySummaryStatRow/ChipRow")
scene_save()
```

Diff the scene: only the `ChipRow` subtree goes. `git diff HEAD -- '*.gd'` must be empty.

- [ ] **Step 5: Script work**

`DaySummaryStatRow.gd`: delete the four chip `@onready` vars (73-76), `_reveal_tweens` (97), `_chip_mode` (102), the static `chip_text`, `target_text`, `chip_variation`, `shows_chip`, and `set_chip_mode`, `_sync_readout`, `_reset_chip`, `rewind`, `play_count`, `land_pop`, `land`, `_stop_reveal`, each with its `##` block. Then fix every remaining call site the parser reports: `_count_text` becomes `return format_value(v, _target)` (drop the `chip_row.visible` branch); remove `_sync_readout(...)` / `_reset_chip()` calls from `set_stat`, `set_standing`, `show_preview` and `play_gain`. `_gain_marker()` returns `chevron` unconditionally (drop its chip branch). Keep `_burst_node` and `_get_or_make_burst`: `play_gain`/`_play_burst` still call them.

`DaySummaryStudentRow.gd`: replace `NEEDS_VARIATION` with

```gdscript
## The needs bars' variations: the nightly colours, on every screen since
## the weekly report took the daily look (2026-09-29).
const ENERGY_VARIATION := &"DaySummaryEnergyBar"
const MOOD_VARIATION := &"DaySummaryMoodBar"
```

and `_apply_look` with

```gdscript
## Dress the card: the nightly needs colours and the arrows' gold. Every
## entry point calls it first, so a card re-armed from another screen
## never carries a stale look.
func _apply_look() -> void:
	energy_bar.theme_type_variation = ENERGY_VARIATION
	mood_bar.theme_type_variation = MOOD_VARIATION
	energy_delta_chevron.self_modulate = Color.WHITE
	mood_delta_chevron.self_modulate = Color.WHITE
```

and change the three `_apply_look(false)` calls to `_apply_look()`.

`ThemeFactory.gd`: delete the `WeekEnergyBar`/`WeekMoodBar` entries from the needs-bar spec list (~3216-3219) and the whole `DeltaChipGain`/`DeltaChipLoss`/`DeltaChipLabel` block (~3327-3351). If a token becomes unused (e.g. `cat_energy_on_dark`), leave the token — other screens may read it; `grep` before touching `DesignTokens.gd`, and do not delete tokens in this task.

`tests/test_theme_factory.gd`: remove `"DeltaChipLabel"` from `DISPLAY_ROSTER`.

`style-guide.md`: delete the `DeltaChipGain`/`DeltaChipLoss` sentence (line ~85) and the `WeekEnergyBar`/`WeekMoodBar` bullet (line ~119).

- [ ] **Step 6: Rebake and run**

No-op `script_patch` on the three scripts; `test_run(suite="theme_rebake")`; then `result_checkup`, `day_summary`, `card_standing_mode`, `theme_factory`, `script_documentation`, `clean_code`, `viewport_editability`. Expected: all PASS. Diff the bake: only the five retired variations disappear (plus Task 1's already-committed changes absent from this diff).

- [ ] **Step 7: Restart the worktree editor** (as Task 1 Step 5).

- [ ] **Step 8: Commit** — `refactor(result-checkup): retire the weekly-only chip readout and week bars`.

---

### Task 5: Live check, docs, full suite

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (new entry, newest first)
- Modify: `docs/superpowers/DEBT.md` only if it lists the ResultCheckup placeholder coin or chips (`grep -n "icon_uang\|ResultCheckup\|chip" docs/superpowers/DEBT.md`)

- [ ] **Step 1: Live check.** `project_run(autosave=false, session_id=…)`, then `game_eval`: `DebugManager._seed_playtest_state()`, change scene to the Lobby, `DebugManager._open_week_report_preview()`, wait 5 s. Screenshot the game at full resolution (`max_resolution=0`) and confirm: Lobby coin on the money pill; white numbers with a navy rim; the three captions on one line each in Boohong; cards with purple/orange needs bars and `+N/T` readouts with gold chevrons; no green/red chips. Stop the game.

- [ ] **Step 2: CHANGELOG entry** (top of the list):

```markdown
## 2026-09-29 — ResultCheckup clarity pass

The week banner's pills now say what they count (UANG DIDAPAT, MINIGAME
MENANG, EVENT TERJADI) under white, navy-rimmed numbers, and the money
pill wears the Lobby coin. The weekly student cards are the daily cards
showing a week: same readout, needs colours and entrance. The chip
readout, week needs bars and staged reveal were retired.
Spec: `specs/2026-09-29-result-checkup-clarity-design.md`.
```

- [ ] **Step 3: Full suite.** `test_run(session_id=…)` with no suite. Expected: 0 failures. Then `git checkout -- Assets/Audio/default_bus_layout.tres` if dirty, and confirm `Assets/Theme/kejartes_theme.tres` is unchanged versus HEAD (a full run rebakes it).

- [ ] **Step 4: Commit** — `docs(result-checkup): log the clarity pass`.

- [ ] **Step 5: Ship** with the `ship-pr` skill.
