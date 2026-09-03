# ResultCheckup Week Recap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `ResultCheckup` as a pinned week-summary banner over two tabbed panes, with richer history rows and a five-stage gated entrance, so a week's outcome reads at a glance on a 1080×1920 phone.

**Architecture:** A new pure-`RefCounted` `WeekRecap` computes the week's four totals from `StudentManager` + `GameState`, so the arithmetic tests without a scene. The screen's visuals become authored scenes — `WeekRecapBanner`, `WeekRecapPill`, `WeekHistoryRow` — replacing the runtime-built history rows that currently sit in `test_viewport_editability.gd`'s `BASELINE`. `ResultCheckup.gd` shrinks to wiring: build both panes once, switch them with `visible`, and run the entrance choreography.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` via the Godot AI MCP `test_run` tool, `DesignTokens`/`ThemeFactory` theme system, `GPUParticles2D` via the existing `RewardParticles` script.

**Spec:** `docs/superpowers/specs/2026-09-03-result-checkup-week-recap-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated rows are a `PackedScene` template.
- **No emoji as UI iconography.** Use the transparent SVGs in `Assets/Images/UI/Placeholders/`.
- **Every script needs a `##` file header and a `##` line on every `@export`** — enforced by `tests/test_script_documentation.gd`.
- **Every test suite is `@tool`**, extends `McpTestSuite`, and **no test may be a coroutine** — the runner does `suite.call(name)` without awaiting.
- **Scripts the runner instantiates live must be `@tool`**, with real side effects gated behind `if Engine.is_editor_hint(): return`. Signal wiring stays ungated.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` → `node_create`/`node_set_property` → `scene_save`. `anchors_preset` is inert (set the four anchors); numbers must be unquoted; `node_create` appends last so z-order needs `move_node`.
- **Rescan after editing a `.gd`, before running tests** (`filesystem_manage(op="scan")`). If the `.gd` was edited from outside the editor, force a reload with a no-op `script_patch` on that file.
- **The Godot MCP bridge is single-client.** Subagents write code; the controller session builds every `.tscn` and runs every `test_run`.
- Game-facing identifiers and all UI text are **Indonesian**; engine and systems code is English.
- Tunable numbers belong in a named `const` block or an `@export`, not inline.
- Timings come from `DesignTokens` (`dur_fast`/`dur_normal`/`dur_slow`/`stagger_step`), never literals.
- Commits: Conventional Commits with a scope, e.g. `feat(resultcheckup): ...`.

**Available assert methods** (`addons/godot_ai/testing/test_suite.gd`): `assert_eq`, `assert_ne`, `assert_true`, `assert_false`, `assert_gt`, `assert_contains`, `assert_has_key`, `assert_not_null`, `assert_is_error`.

**Existing AudioDirector ids used here** (all already defined — this plan adds none): `whoosh`, `tally`, `coin`, `sparkle`, `reward`, `select`, `stamp`, `popup_open`, `confirm`.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `Scripts/SchoolSimulation/WeekRecap.gd` | Pure arithmetic: one `StudentManager` in, one totals dictionary out. No nodes, no tree. |
| `Scripts/SchoolSimulation/WeekRecapPill.gd` | One pill: icon, value label, count-up, ring pulse. |
| `Scenes/SchoolSimulation/WeekRecapPill.tscn` | The pill template. |
| `Scripts/SchoolSimulation/WeekRecapBanner.gd` | Owns the four pills, the header line, and stages 1–3 of the entrance. |
| `Scenes/SchoolSimulation/WeekRecapBanner.tscn` | The banner, four pills authored in. |
| `Scripts/SchoolSimulation/WeekHistoryRow.gd` | One history entry rendered into three lines + badge. |
| `Scenes/SchoolSimulation/WeekHistoryRow.tscn` | The history row template. |
| `Scenes/SchoolSimulation/CoinShower.tscn` | `RewardParticles` emitter for stage 3. |
| `Assets/Images/Particles/particle_{coin,spark,plus,glow}.png` | Four placeholder sprites. |
| `tests/test_week_recap.gd` | `WeekRecap` arithmetic. |

**Modified:**

| Path | Change |
|---|---|
| `Scripts/SchoolSimulation/ResultCheckup.gd` | Rewrite: delete dead exports + `_create_history_item`, add tabs/panes/choreography. |
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | Restructure per spec §3. |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | `_show_needs_delta` tints from success/danger (spec §4.1). |
| `Scripts/Design/ThemeFactory.gd` | Four new variations (spec §8). |
| `Scenes/SchoolSimulation/RewardBurst.tscn` | Swap `particle_star` → `particle_spark`; add a `particle_plus` sibling emitter. |
| `tests/test_result_checkup.gd` | Extend for banner/tabs/panes/guards. |
| `tests/test_day_summary.gd` | One test for the needs-delta tint. |
| `tests/test_viewport_editability.gd` | Lower `ResultCheckup.gd`'s `BASELINE`. |

---

## Task 1: WeekRecap arithmetic

**Files:**
- Create: `Scripts/SchoolSimulation/WeekRecap.gd`
- Test: `tests/test_week_recap.gd`

**Interfaces:**
- Consumes: `StudentManager.minigame_history` (`Array[Dictionary]` with `day`, `category`, `game_name`, `won`, optional `score`/`max_score`/`results`/`details`/`affected_students`); `StudentManager.daily_stat_log` (`{day_name: Array[{student_name, stat_key, delta, source}]}`); `GameState.pending_earnings` (`{student_id: int}`).
- Produces: `WeekRecap.compute(manager: StudentManager) -> Dictionary` with keys `money_earned: int`, `net_skill_delta: int`, `minigames_won: int`, `minigames_total: int`, `events_count: int`. Also `WeekRecap.format_money(v: int) -> String` and `WeekRecap.format_skill_delta(v: int) -> String`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_week_recap.gd`:

```gdscript
@tool
extends McpTestSuite

## WeekRecap's week-total arithmetic (2026-09-03 spec section 4).
##
## WeekRecap is a plain RefCounted, so every case here runs without
## instantiating a scene -- this is the cheap half of the pass's
## coverage. Suite is @tool and no test is a coroutine, per the runner's
## constraints.

const _RECAP_SCRIPT := "res://Scripts/SchoolSimulation/WeekRecap.gd"


func suite_name() -> String:
	return "week_recap"


## A StudentManager standing in for a simulated week. Built by hand
## rather than by running a real simulation: these tests are about the
## summing, not about what the simulation produces.
func _manager(history: Array, log: Dictionary) -> StudentManager:
	var m := StudentManager.new()
	m.minigame_history.assign(history)
	m.daily_stat_log = log
	return m


func _entry(day: String, category: String, won: bool) -> Dictionary:
	return {"day": day, "category": category, "game_name": "X", "won": won}


func _delta(name_: String, stat_key: String, delta: float) -> Dictionary:
	return {"student_name": name_, "stat_key": stat_key,
		"delta": delta, "source": "activity"}


func test_net_skill_delta_sums_all_three_skills() -> void:
	var m := _manager([], {
		"Senin": [_delta("Budi", "akademis", 10.0),
			_delta("Ani", "seni_budaya", 5.0)],
		"Selasa": [_delta("Budi", "olahraga", 22.0)],
	})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["net_skill_delta"], 37, "10 + 5 + 22 = 37")


func test_net_skill_delta_is_net_not_positive_only() -> void:
	var m := _manager([], {
		"Senin": [_delta("Budi", "akademis", 6.0),
			_delta("Ani", "olahraga", -10.0)],
	})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["net_skill_delta"], -4,
		"a losing week must be allowed to read negative")


func test_needs_deltas_never_leak_into_net_skill_delta() -> void:
	var m := _manager([], {
		"Senin": [_delta("Budi", "energy", -30.0),
			_delta("Budi", "mood", -25.0),
			_delta("Budi", "akademis", 8.0)],
	})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["net_skill_delta"], 8,
		"energy and mood are excluded; only akademis counts")


func test_minigame_tally_excludes_events() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", true),
	], {})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 2, "two non-event wins")
	assert_eq(r["minigames_total"], 3, "the Event entry is not a minigame")
	assert_eq(r["events_count"], 1, "one Event entry")


func test_empty_history_reports_zeroes() -> void:
	var r: Dictionary = WeekRecap.compute(_manager([], {}))
	assert_eq(r["minigames_total"], 0, "no minigames")
	assert_eq(r["events_count"], 0, "no events")
	assert_eq(r["net_skill_delta"], 0, "no movement")


func test_all_event_history_reports_no_minigames() -> void:
	var m := _manager([
		_entry("Senin", "Event", true),
		_entry("Selasa", "Event", true),
	], {})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_total"], 0, "every entry was an Event")
	assert_eq(r["events_count"], 2, "both counted as events")


func test_null_manager_reports_zeroes_rather_than_erroring() -> void:
	var r: Dictionary = WeekRecap.compute(null)
	assert_eq(r["money_earned"], 0, "a null manager is survivable")
	assert_eq(r["minigames_total"], 0, "and reports an empty week")


func test_format_money_groups_thousands_with_a_dot() -> void:
	assert_eq(WeekRecap.format_money(4200), "4.200",
		"Indonesian thousands separator")
	assert_eq(WeekRecap.format_money(0), "0", "zero needs no separator")
	assert_eq(WeekRecap.format_money(1234567), "1.234.567",
		"grouping repeats every three digits")


func test_format_skill_delta_signs_and_neutral_word() -> void:
	assert_eq(WeekRecap.format_skill_delta(37), "+37", "gains carry a +")
	assert_eq(WeekRecap.format_skill_delta(-4), "-4",
		"the minus comes free from %d")
	assert_eq(WeekRecap.format_skill_delta(0), "Netral",
		"exact zero reads as a word, not a bare 0")
```

- [ ] **Step 2: Run the test to verify it fails**

Run via MCP: `test_run(suite="week_recap")`
Expected: FAIL — `WeekRecap` is not a known identifier.

- [ ] **Step 3: Write the implementation**

Create `Scripts/SchoolSimulation/WeekRecap.gd`:

```gdscript
extends RefCounted
class_name WeekRecap

## The week's four headline totals, computed from one StudentManager
## (2026-09-03 spec section 4).
##
## A plain RefCounted rather than a node or an autoload: the numbers on
## ResultCheckup's banner are the most likely thing in this screen to be
## argued about during balancing, and keeping them here means they can be
## tested without instantiating a scene.
##
## Nothing here is persisted. The week's totals are recomputed on demand
## from the live StudentManager, matching GameState's session-scoped
## design.

## The three skill keys that count toward net_skill_delta. energy and
## mood are deliberately absent: summing a mood drop into the same
## integer as an academic gain produces a number that means nothing --
## -12 mood against +12 akademis would cancel to 0 and report a flat week
## that was not flat.
const SKILL_KEYS := ["akademis", "seni_budaya", "olahraga"]

## The history category that marks an entry as a random event rather than
## a played minigame. Everything else is a minigame.
const EVENT_CATEGORY := "Event"

## Shown by the poin pill at exactly zero, in place of a bare "0".
const NEUTRAL_WORD := "Netral"


## Every headline total for the week `manager` just simulated. Safe on a
## null manager, which reports an empty week rather than erroring -- the
## editor's test runner builds ResultCheckup with no simulation behind
## it.
static func compute(manager: StudentManager) -> Dictionary:
	var result := {
		"money_earned": _sum_pending_earnings(),
		"net_skill_delta": 0,
		"minigames_won": 0,
		"minigames_total": 0,
		"events_count": 0,
	}
	if manager == null:
		return result

	var net := 0.0
	for day_name in manager.daily_stat_log:
		for change in manager.daily_stat_log[day_name]:
			if SKILL_KEYS.has(change.get("stat_key", "")):
				net += change.get("delta", 0.0)
	result["net_skill_delta"] = int(round(net))

	for entry in manager.minigame_history:
		if entry.get("category", "") == EVENT_CATEGORY:
			result["events_count"] += 1
		else:
			result["minigames_total"] += 1
			if entry.get("won", false):
				result["minigames_won"] += 1

	return result


## This week's un-paid Wirausaha earnings. GameState empties
## pending_earnings at week end, so this must be read before SchoolDay's
## payout, which is exactly when ResultCheckup runs.
static func _sum_pending_earnings() -> int:
	var total := 0
	for amount in GameState.pending_earnings.values():
		total += int(amount)
	return total


## "4.200" -- Indonesian thousands grouping, which uses a dot where
## English uses a comma.
static func format_money(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	return ("-" if value < 0 else "") + grouped


## "+37" / "-4" / "Netral". The "+" is explicit and the "-" comes free
## from %d, the same sign rule DaySummaryStudentRow.format_needs_delta
## uses. Zero reads as a word because a bare "0" beside a coloured pill
## looks like the pill failed to populate.
static func format_skill_delta(value: int) -> String:
	if value == 0:
		return NEUTRAL_WORD
	return "%s%d" % ["+" if value > 0 else "", value]
```

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="week_recap")`
Expected: PASS, 9 tests.

If the suite reports "Nonexistent function" or an unknown `WeekRecap`, force a script reload with a no-op `script_patch` on `WeekRecap.gd` (add and remove a blank line), then re-run.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/WeekRecap.gd tests/test_week_recap.gd
git commit -m "feat(resultcheckup): add WeekRecap, the week's four headline totals"
```

---

## Task 2: Negative needs deltas read as bad news

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` (`_show_needs_delta`, ~line 203)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `Juice.tokens()` → `DesignTokens` with `state_success`, `state_danger`, `text_primary`.
- Produces: nothing new. `_show_needs_delta(label, delta)` keeps its signature; only the label's `self_modulate` changes.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## A drained week must LOOK drained. format_needs_delta already produced
## "-12", but nothing coloured the label, so a loss rendered in the same
## ink as a gain (2026-09-03 spec section 4.1).
func test_negative_needs_delta_is_tinted_danger() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd")
	assert_contains(src, "state_danger",
		"_show_needs_delta must tint a loss from the danger token")
	assert_contains(src, "state_success",
		"and a gain from the success token")
	assert_false(src.contains("Color("),
		"the tint comes from DesignTokens, never a Color literal")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="day_summary")`
Expected: FAIL — `state_danger` not found in the source.

- [ ] **Step 3: Write the implementation**

Replace `_show_needs_delta` in `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`:

```gdscript
## Write and reveal one needs-bar delta label, tinted by its direction:
## a gain reads success-green, a loss danger-red, and an exactly-flat
## needs bar stays in the card's own ink so "+0" does not claim to be
## good news. self_modulate rather than a font colour override, because
## the label's variation owns its typography (project rule: no
## theme_override_*).
func _show_needs_delta(label: Label, delta: float) -> void:
	label.text = format_needs_delta(delta)
	var t := Juice.tokens()
	if delta > 0.0:
		label.self_modulate = t.state_success
	elif delta < 0.0:
		label.self_modulate = t.state_danger
	else:
		label.self_modulate = t.text_primary
	label.show()
```

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="day_summary")`
Expected: PASS, all previously-green tests still green.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd
git commit -m "fix(daysummary): tint a losing needs delta red instead of gain-green"
```

---

## Task 3: Generate the four particle sprites

**Files:**
- Create: `Assets/Images/Particles/particle_coin.png`, `particle_spark.png`, `particle_plus.png`, `particle_glow.png`
- Create then delete: `tests/test_zzz_transient_particle_gen.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: four 128×128 RGBA8 PNGs, white/greyscale with alpha, so emitters tint them from `DesignTokens` rather than baking a colour in.

There is no Python on this machine and no MCP entry point for an `EditorScript`, so these are generated the way the project generates anything headlessly: a transient `@tool` `McpTestSuite` whose single test writes the files, run once via `test_run`, then deleted.

- [ ] **Step 1: Write the generator suite**

Create `tests/test_zzz_transient_particle_gen.gd`:

```gdscript
@tool
extends McpTestSuite

## TRANSIENT. Generates the four placeholder particle sprites for the
## 2026-09-03 ResultCheckup pass, then is deleted. Present in the repo
## only for the length of one task -- do not extend it, do not rely on
## it.
##
## Exists because there is no Python here and no MCP entry point for an
## EditorScript; a @tool suite run through test_run is the project's
## documented headless escape hatch.

const _DIR := "res://Assets/Images/Particles/"
const _SIZE := 128


func suite_name() -> String:
	return "zzz_transient_particle_gen"


func _blank() -> Image:
	var img := Image.create(_SIZE, _SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	return img


## White with an alpha ramp, so every sprite tints cleanly from a
## ParticleProcessMaterial colour.
func _px(img: Image, x: int, y: int, alpha: float) -> void:
	if x < 0 or y < 0 or x >= _SIZE or y >= _SIZE:
		return
	img.set_pixel(x, y, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))


func test_generate_particle_sprites() -> void:
	var c := float(_SIZE) * 0.5

	# particle_coin: a filled disc with a punched inner ring.
	var coin := _blank()
	for y in _SIZE:
		for x in _SIZE:
			var d := Vector2(x - c, y - c).length()
			if d <= c - 6.0:
				var ring: bool = d > c * 0.55 and d < c * 0.68
				_px(coin, x, y, 0.45 if ring else 1.0)
	coin.save_png(_DIR + "particle_coin.png")

	# particle_spark: a four-point glint -- two crossed tapered spokes.
	var spark := _blank()
	for i in _SIZE:
		var t := abs(float(i) - c) / c
		var falloff := pow(1.0 - t, 2.2)
		var half := int(round(6.0 * falloff))
		for w in range(-half, half + 1):
			_px(spark, i, int(c) + w, falloff)
			_px(spark, int(c) + w, i, falloff)
	spark.save_png(_DIR + "particle_spark.png")

	# particle_plus: a thick, flat plus.
	var plus := _blank()
	var arm := int(_SIZE * 0.38)
	var thick := int(_SIZE * 0.13)
	for i in range(-arm, arm + 1):
		for w in range(-thick, thick + 1):
			_px(plus, int(c) + i, int(c) + w, 1.0)
			_px(plus, int(c) + w, int(c) + i, 1.0)
	plus.save_png(_DIR + "particle_plus.png")

	# particle_glow: a soft radial falloff, squared for a gentle core.
	var glow := _blank()
	for y in _SIZE:
		for x in _SIZE:
			var d2 := Vector2(x - c, y - c).length() / c
			_px(glow, x, y, pow(clampf(1.0 - d2, 0.0, 1.0), 2.0) * 0.85)
	glow.save_png(_DIR + "particle_glow.png")

	for f in ["particle_coin", "particle_spark", "particle_plus",
			"particle_glow"]:
		assert_true(FileAccess.file_exists(_DIR + f + ".png"),
			"%s.png was written" % f)
```

- [ ] **Step 2: Run the generator**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="zzz_transient_particle_gen")`
Expected: PASS, 4 assertions.

- [ ] **Step 3: Import the new textures**

Run: `filesystem_manage(op="scan")`
Expected: four new `.png.import` files appear beside the PNGs. Verify with `ls Assets/Images/Particles/`.

- [ ] **Step 4: Delete the transient suite**

```bash
rm tests/test_zzz_transient_particle_gen.gd tests/test_zzz_transient_particle_gen.gd.uid
```

Then `filesystem_manage(op="scan")` again so the runner forgets it.

- [ ] **Step 5: Commit**

```bash
git add Assets/Images/Particles/
git commit -m "feat(art): add four placeholder particle sprites for the week recap"
```

---

## Task 4: Theme variations and rebake

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`
- Modify (generated): `Assets/Theme/kejartes_theme.tres`
- Create then delete: `tests/test_zzz_transient_theme_rebake.gd`

**Interfaces:**
- Consumes: `DesignTokens` fields `surface_card`, `surface_sunken`, `brand_primary`, `text_on_brand`, `text_primary`, `radius_md`, `radius_pill`, `font_h2`, `font_title`, `outline_width`.
- Produces: four theme type variations usable as `theme_type_variation`: `&"RecapBannerPanel"`, `&"RecapPillPanel"`, `&"RecapPillValueLabel"`, `&"WeekTabButton"`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
## The four variations the recap banner and tab bar need. Without these
## the screen would have to reach for theme_override_*, which the project
## forbids (2026-09-03 spec section 8).
func test_theme_carries_the_recap_variations() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_not_null(theme, "the baked theme loads")
	for variation in ["RecapBannerPanel", "RecapPillPanel",
			"RecapPillValueLabel", "WeekTabButton"]:
		assert_true(theme.has_stylebox("panel", variation)
				or theme.has_stylebox("normal", variation)
				or theme.has_font_size("font_size", variation),
			"%s is baked into the theme" % variation)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — `RecapBannerPanel is baked into the theme`.

- [ ] **Step 3: Add the variations**

In `Scripts/Design/ThemeFactory.gd`, following the file's existing variation-building pattern, add:

```gdscript
	# ── Week recap (ResultCheckup) ───────────────────────────────────
	# The banner is a raised card that must not read as another student
	# card, so it takes the card surface with the brand's own edge.
	var recap_banner := StyleBoxFlat.new()
	recap_banner.bg_color = t.surface_card
	recap_banner.set_corner_radius_all(t.radius_md)
	recap_banner.border_color = t.brand_primary
	recap_banner.set_border_width_all(int(t.outline_width) / 2)
	recap_banner.content_margin_left = t.space_md
	recap_banner.content_margin_right = t.space_md
	recap_banner.content_margin_top = t.space_sm
	recap_banner.content_margin_bottom = t.space_sm
	theme.set_stylebox("panel", "RecapBannerPanel", recap_banner)
	theme.set_type_variation("RecapBannerPanel", "PanelContainer")

	# A pill is a sunken capsule -- the counter-form to the banner it
	# sits inside.
	var recap_pill := StyleBoxFlat.new()
	recap_pill.bg_color = t.surface_sunken
	recap_pill.set_corner_radius_all(t.radius_pill)
	recap_pill.content_margin_left = t.space_sm
	recap_pill.content_margin_right = t.space_sm
	recap_pill.content_margin_top = t.space_xs
	recap_pill.content_margin_bottom = t.space_xs
	theme.set_stylebox("panel", "RecapPillPanel", recap_pill)
	theme.set_type_variation("RecapPillPanel", "PanelContainer")

	# The pill's number. Tinted per-pill via self_modulate, so the
	# variation itself stays neutral.
	theme.set_font_size("font_size", "RecapPillValueLabel", t.font_h2)
	theme.set_color("font_color", "RecapPillValueLabel", t.text_primary)
	if t.font_display:
		theme.set_font("font", "RecapPillValueLabel", t.font_display)
	theme.set_type_variation("RecapPillValueLabel", "Label")

	# The tab. A real pressed state is what makes the active tab legible
	# without any manual tint at the call site.
	var tab_normal := StyleBoxFlat.new()
	tab_normal.bg_color = t.surface_sunken
	tab_normal.corner_radius_top_left = t.radius_md
	tab_normal.corner_radius_top_right = t.radius_md
	tab_normal.content_margin_top = t.space_sm
	tab_normal.content_margin_bottom = t.space_sm
	var tab_pressed := tab_normal.duplicate() as StyleBoxFlat
	tab_pressed.bg_color = t.brand_primary
	theme.set_stylebox("normal", "WeekTabButton", tab_normal)
	theme.set_stylebox("hover", "WeekTabButton", tab_normal)
	theme.set_stylebox("pressed", "WeekTabButton", tab_pressed)
	theme.set_stylebox("focus", "WeekTabButton", tab_normal)
	theme.set_color("font_color", "WeekTabButton", t.text_secondary)
	theme.set_color("font_pressed_color", "WeekTabButton", t.text_on_brand)
	theme.set_color("font_hover_color", "WeekTabButton", t.text_primary)
	theme.set_font_size("font_size", "WeekTabButton", t.font_title)
	theme.set_type_variation("WeekTabButton", "Button")
```

Match the surrounding code's own variable names for the tokens object and the theme object — read the neighbouring block before pasting, and rename `t` / `theme` to whatever that file already uses.

- [ ] **Step 4: Rebake the theme**

There is no MCP entry point for `Scripts/Design/BakeTheme.gd`. Create `tests/test_zzz_transient_theme_rebake.gd`:

```gdscript
@tool
extends McpTestSuite

## TRANSIENT. Rebakes Assets/Theme/kejartes_theme.tres headlessly, then
## is deleted. The documented substitute for File > Run on
## Scripts/Design/BakeTheme.gd, which has no MCP entry point.

func suite_name() -> String:
	return "zzz_transient_theme_rebake"


func test_rebake_theme() -> void:
	var theme: Theme = ThemeFactory.build()
	var err := ResourceSaver.save(theme,
		"res://Assets/Theme/kejartes_theme.tres")
	assert_eq(err, OK, "the baked theme saved")
```

Run: `filesystem_manage(op="scan")`, then `test_run(suite="zzz_transient_theme_rebake")`.
Expected: PASS.

Then delete it:

```bash
rm tests/test_zzz_transient_theme_rebake.gd tests/test_zzz_transient_theme_rebake.gd.uid
```

and `filesystem_manage(op="scan")`.

If `ThemeFactory.build()` reports an unknown property, the editor is serving stale bytecode: apply a no-op `script_patch` to `ThemeFactory.gd` (add and remove a blank line), then re-run.

- [ ] **Step 5: Run the test to verify it passes**

Run: `test_run(suite="result_checkup")`
Expected: `test_theme_carries_the_recap_variations` PASSes.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_result_checkup.gd
git commit -m "feat(theme): add the recap banner, pill and week-tab variations"
```

---

## Task 5: The WeekRecapPill template

**Files:**
- Create: `Scripts/SchoolSimulation/WeekRecapPill.gd`
- Create: `Scenes/SchoolSimulation/WeekRecapPill.tscn` (controller builds via MCP)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `Juice.count_up_formatted(label, from, to, formatter, delay)`, `Juice.tokens()`, `AudioDirector.play_sfx(&"tally")`.
- Produces: `WeekRecapPill.set_pill(icon: Texture2D, value_text: String, tint: Color) -> void` and `WeekRecapPill.play_count_up(to_value: float, formatter: Callable, delay: float) -> void`. Node paths inside the scene: `Icon` (`TextureRect`), `Value` (`Label`), `Ring` (`RewardParticles`).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
const _PILL_SCENE := "res://Scenes/SchoolSimulation/WeekRecapPill.tscn"


func test_pill_scene_has_its_three_authored_nodes() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	assert_not_null(pill.get_node_or_null("Icon"), "Icon is authored")
	assert_not_null(pill.get_node_or_null("Value"), "Value is authored")
	assert_not_null(pill.get_node_or_null("Ring"), "Ring emitter is authored")
	pill.free()


func test_pill_uses_the_theme_variation_not_an_override() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/WeekRecapPill.tscn")
	assert_contains(src, "RecapPillPanel", "the pill takes its variation")
	assert_false(src.contains("theme_override_styles"),
		"no stylebox override on the pill")


func test_pill_set_pill_writes_text_and_tint() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	pill.set_pill(null, "4.200", Color.RED)
	assert_eq((pill.get_node("Value") as Label).text, "4.200",
		"the value label carries the formatted number")
	assert_eq((pill.get_node("Value") as Label).self_modulate, Color.RED,
		"and the caller's tint")
	pill.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — the scene does not exist.

- [ ] **Step 3: Write the script**

Create `Scripts/SchoolSimulation/WeekRecapPill.gd`:

```gdscript
@tool
extends PanelContainer
class_name WeekRecapPill

## One headline total on ResultCheckup's week banner: an icon, a number,
## and a ring pulse that fires as the number lands (2026-09-03 spec
## section 4).
##
## A template, instanced four times by WeekRecapBanner. It knows nothing
## about which total it is showing -- the banner supplies the icon, the
## formatted text and the tint -- so adding a fifth pill later needs no
## change here.
##
## @tool so the editor's test runner can instantiate and inspect it.

## The pill's icon. Left null the pill still lays out; the icon slot
## simply renders empty.
@onready var icon: TextureRect = $Icon
## The formatted number. Tinted via self_modulate by set_pill, never by a
## font colour override.
@onready var value_label: Label = $Value
## The one-shot pulse fired when this pill's count-up lands.
@onready var ring: RewardParticles = $Ring


## Populate the pill. `tint` colours only the number, never the icon --
## the icon SVGs carry their own colour and multiplying them would muddy
## it.
func set_pill(icon_texture: Texture2D, value_text: String,
		tint: Color) -> void:
	if icon:
		icon.texture = icon_texture
	if value_label:
		value_label.text = value_text
		value_label.self_modulate = tint


## Count this pill's number up from zero after `delay`, pulsing the ring
## and ticking once as it lands. `formatter` turns the running float into
## the pill's own text, so the money pill groups thousands and the poin
## pill signs itself without this script knowing the difference.
##
## A coroutine -- never call it from a test; the runner does not await.
func play_count_up(to_value: float, formatter: Callable,
		delay: float = 0.0) -> void:
	if Engine.is_editor_hint():
		return
	Juice.count_up_formatted(value_label, 0.0, to_value, formatter, delay)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	AudioDirector.play_sfx(&"tally")
	if ring:
		ring.fire()
```

- [ ] **Step 4: Build the scene via MCP**

The controller session builds `Scenes/SchoolSimulation/WeekRecapPill.tscn`:

1. `scene_manage(op="new", type="PanelContainer", name="WeekRecapPill")`
2. Root: `theme_type_variation = "RecapPillPanel"`, `custom_minimum_size = Vector2(228, 132)`, attach `WeekRecapPill.gd`.
3. Child `VBoxContainer` named `Body`, `theme_override_constants/separation = 4` (layout-only constant, permitted).
4. Under `Body`: `TextureRect` named `Icon`, `expand_mode = 1` (`EXPAND_IGNORE_SIZE`), `stretch_mode = 5` (`STRETCH_KEEP_ASPECT_CENTERED`), `custom_minimum_size = Vector2(0, 48)`.
5. Under `Body`: `Label` named `Value`, `theme_type_variation = "RecapPillValueLabel"`, `horizontal_alignment = 1`.
6. Child of root: instance `RewardBurst.tscn` renamed `Ring`, `plays_sfx = false`, `amount = 10`, `explosiveness = 1.0`, texture set to `particle_ring.png`, positioned at the pill's centre.
7. `scene_save`.

`Icon` and `Value` must be reachable at `$Icon` / `$Value` from the root — so either place them directly on the root, or add matching `unique_name_in_owner` and use `%Icon`. This plan assumes **direct children of the root**; if you keep the `Body` VBox, update the `@onready` paths to `$Body/Icon` and `$Body/Value` and update the test's `get_node_or_null` paths to match.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the three pill tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/WeekRecapPill.gd Scenes/SchoolSimulation/WeekRecapPill.tscn tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): add the WeekRecapPill template"
```

---

## Task 6: The WeekRecapBanner

**Files:**
- Create: `Scripts/SchoolSimulation/WeekRecapBanner.gd`
- Create: `Scenes/SchoolSimulation/WeekRecapBanner.tscn` (controller builds via MCP)
- Create: `Scenes/SchoolSimulation/CoinShower.tscn` (controller builds via MCP)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `WeekRecap.compute/format_money/format_skill_delta` (Task 1), `WeekRecapPill.set_pill/play_count_up` (Task 5), `GameState.minggu_ke`, `GameState.get_grade_name()`, `AudioDirector.play_sfx(&"whoosh"/&"coin")`.
- Produces: `WeekRecapBanner.set_recap(recap: Dictionary) -> void` and `WeekRecapBanner.play_entrance() -> void`. Node paths: `Header/WeekLabel`, `Header/GradeLabel`, `Pills/PillUang`, `Pills/PillPoin`, `Pills/PillMenang`, `Pills/PillEvent`, `CoinShower`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
const _BANNER_SCENE := "res://Scenes/SchoolSimulation/WeekRecapBanner.tscn"


func test_banner_authors_all_four_pills() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	for pill_name in ["PillUang", "PillPoin", "PillMenang", "PillEvent"]:
		assert_not_null(banner.get_node_or_null("Pills/" + pill_name),
			"%s is authored, not built at runtime" % pill_name)
	banner.free()


func test_banner_writes_every_total_into_its_pills() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	banner.set_recap({
		"money_earned": 4200, "net_skill_delta": 37,
		"minigames_won": 3, "minigames_total": 5, "events_count": 2,
	})
	assert_eq(_pill_text(banner, "PillUang"), "4.200", "money is grouped")
	assert_eq(_pill_text(banner, "PillPoin"), "+37", "poin is signed")
	assert_eq(_pill_text(banner, "PillMenang"), "3/5", "won over total")
	assert_eq(_pill_text(banner, "PillEvent"), "2", "a bare event count")
	banner.free()


func test_banner_shows_a_negative_week_as_negative() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	banner.set_recap({
		"money_earned": 0, "net_skill_delta": -4,
		"minigames_won": 0, "minigames_total": 2, "events_count": 0,
	})
	assert_eq(_pill_text(banner, "PillPoin"), "-4",
		"a losing week is not hidden")
	banner.free()


func _pill_text(banner: Control, pill_name: String) -> String:
	return (banner.get_node("Pills/" + pill_name).get_node("Value")
		as Label).text
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — the banner scene does not exist.

- [ ] **Step 3: Write the script**

Create `Scripts/SchoolSimulation/WeekRecapBanner.gd`:

```gdscript
@tool
extends PanelContainer
class_name WeekRecapBanner

## ResultCheckup's pinned week summary: the week and grade, and the four
## headline totals as WeekRecapPills (2026-09-03 spec sections 3 and 4).
##
## Pinned means it lives OUTSIDE the screen's ScrollContainer, so the
## week's totals stay on screen while the player reads student cards.
##
## Owns entrance stages 1-3 (banner slide, pill count-ups, coin shower).
## Stages 4-5 belong to ResultCheckup, which owns the cards.
##
## @tool so the editor's test runner can instantiate and inspect it.

## Gap between one pill's count-up and the next, in seconds. Long enough
## to read as four separate events rather than one chord.
const PILL_STEP := 0.14

## How far the banner travels down into place on stage 1.
const SLIDE_DISTANCE := 48.0

@onready var week_label: Label = $Header/WeekLabel
@onready var grade_label: Label = $Header/GradeLabel
@onready var pill_uang: WeekRecapPill = $Pills/PillUang
@onready var pill_poin: WeekRecapPill = $Pills/PillPoin
@onready var pill_menang: WeekRecapPill = $Pills/PillMenang
@onready var pill_event: WeekRecapPill = $Pills/PillEvent
@onready var coin_shower: RewardParticles = $CoinShower

# ── Visual - Icons ───────────────────────────────────────────────────
@export_group("Visual - Icons")
## Icon on the money pill.
@export var icon_uang: Texture2D = null
## Icon on the net-skill pill.
@export var icon_poin: Texture2D = null
## Icon on the minigame win/loss pill.
@export var icon_menang: Texture2D = null
## Icon on the event-count pill.
@export var icon_event: Texture2D = null

## The recap this banner is currently showing, cached by set_recap so
## play_entrance can count each pill up to the right number.
var _recap: Dictionary = {}


## Write the week's header line and all four pills. Idempotent -- calling
## it twice simply rewrites the same labels.
func set_recap(recap: Dictionary) -> void:
	_recap = recap
	var t := Juice.tokens()

	if week_label:
		week_label.text = "MINGGU %d" % GameState.minggu_ke
	if grade_label:
		grade_label.text = "%s · Evaluasi Mingguan" % GameState.get_grade_name()

	var money: int = recap.get("money_earned", 0)
	pill_uang.set_pill(icon_uang, WeekRecap.format_money(money),
		t.currency_gold if money > 0 else t.text_primary)

	# The one pill that can report bad news, so the one pill that changes
	# colour with its sign.
	var poin: int = recap.get("net_skill_delta", 0)
	var poin_tint := t.text_primary
	if poin > 0:
		poin_tint = t.state_success
	elif poin < 0:
		poin_tint = t.state_danger
	pill_poin.set_pill(icon_poin, WeekRecap.format_skill_delta(poin),
		poin_tint)

	pill_menang.set_pill(icon_menang, "%d/%d" % [
		recap.get("minigames_won", 0), recap.get("minigames_total", 0)],
		t.text_primary)

	pill_event.set_pill(icon_event,
		str(recap.get("events_count", 0)), t.text_primary)


## Entrance stages 1-3: the banner slides down, the four pills count up
## in sequence, and -- only if the week actually earned money -- coins
## fall from the money pill.
##
## A coroutine; never call it from a test.
func play_entrance() -> void:
	if Engine.is_editor_hint():
		return
	var t := Juice.tokens()

	position.y -= SLIDE_DISTANCE
	modulate.a = 0.0
	AudioDirector.play_sfx(&"whoosh")
	var slide := create_tween().set_parallel(true)
	slide.tween_property(self, "position:y",
		position.y + SLIDE_DISTANCE, t.dur_normal)
	slide.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await slide.finished

	var pills: Array = [pill_uang, pill_poin, pill_menang, pill_event]
	var values: Array = [
		float(_recap.get("money_earned", 0)),
		float(_recap.get("net_skill_delta", 0)),
		float(_recap.get("minigames_won", 0)),
		float(_recap.get("events_count", 0)),
	]
	var formatters: Array = [
		func(v: float) -> String: return WeekRecap.format_money(int(v)),
		func(v: float) -> String: return WeekRecap.format_skill_delta(int(v)),
		func(v: float) -> String: return "%d/%d" % [int(v),
			_recap.get("minigames_total", 0)],
		func(v: float) -> String: return "%d" % int(v),
	]
	for i in pills.size():
		pills[i].play_count_up(values[i], formatters[i],
			float(i) * PILL_STEP)

	# Stage 3. Gated: a week that earned nothing gets no coin shower and
	# no coin cue, the same discipline the cards use for their sparkle.
	if int(_recap.get("money_earned", 0)) > 0:
		await get_tree().create_timer(PILL_STEP).timeout
		if not is_inside_tree():
			return
		AudioDirector.play_sfx(&"coin")
		coin_shower.fire()
```

- [ ] **Step 4: Build both scenes via MCP**

`CoinShower.tscn` — duplicate `RewardBurst.tscn`'s structure:
- Root `GPUParticles2D` named `CoinShower`, script `RewardParticles.gd`, `plays_sfx = false` (the banner plays `coin` itself), `amount = 22`, `lifetime = 1.1`, `one_shot = true`, `explosiveness = 0.6`, texture `particle_coin.png`.
- `ParticleProcessMaterial`: `emission_shape = 3` (box), `emission_box_extents = Vector3(120, 8, 0)`, `direction = Vector3(0, -1, 0)`, `initial_velocity_min = 80`, `initial_velocity_max = 200`, `gravity = Vector3(0, 620, 0)`, `angular_velocity_min = -180`, `angular_velocity_max = 180`, `scale_min = 0.22`, `scale_max = 0.4`, `color` = the tokens' `currency_gold`.

`WeekRecapBanner.tscn`:
1. Root `PanelContainer` named `WeekRecapBanner`, `theme_type_variation = "RecapBannerPanel"`, `custom_minimum_size = Vector2(0, 340)`, script attached.
2. Child `VBoxContainer` named `Layout`, `separation = 20`.
3. Under it `HBoxContainer` named `Header` with `Label` `WeekLabel` (`theme_type_variation = "H1Label"`) and `Label` `GradeLabel` (`theme_type_variation = "CaptionLabel"`, `size_flags_horizontal = 3`, `horizontal_alignment = 2`).
4. Under it `HBoxContainer` named `Pills`, `separation = 16`, `alignment = 1`; instance `WeekRecapPill.tscn` four times as `PillUang`, `PillPoin`, `PillMenang`, `PillEvent`, each `size_flags_horizontal = 3`.
5. Instance `CoinShower.tscn` as a child of the root named `CoinShower`, `z_index = 50`, positioned over `PillUang`.
6. Set the four icon exports on the root to `icon_uang.svg`, `icon_poin.svg`, `icon_minigame_menang.svg`, `icon_event.svg` from `Assets/Images/UI/Placeholders/`.
7. `scene_save`.

**Note the `@onready` paths assume `Header` and `Pills` are direct children of the root.** If you keep the `Layout` VBox as their parent, change them to `$Layout/Header/WeekLabel` etc., and update the test's `get_node` paths to match. Pick one and keep script, scene and test consistent.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the three banner tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/WeekRecapBanner.gd Scenes/SchoolSimulation/WeekRecapBanner.tscn Scenes/SchoolSimulation/CoinShower.tscn tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): add the pinned week recap banner and coin shower"
```

---

## Task 7: The WeekHistoryRow template

**Files:**
- Create: `Scripts/SchoolSimulation/WeekHistoryRow.gd`
- Create: `Scenes/SchoolSimulation/WeekHistoryRow.tscn` (controller builds via MCP)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: history entries as recorded by `StudentManager` — minigames carry `day`, `category`, `game_name`, `won`, `score`, `max_score`, `results`; events carry `day`, `category` == `"Event"`, `game_name`, `won` == `true`, `details`, `affected_students`. Also `DaySummaryBadge.tscn` (a `PanelContainer` with a `Text` child `Label`).
- Produces: `WeekHistoryRow.set_entry(entry: Dictionary) -> void`. Node paths: `Body/Icon`, `Body/Lines/Breadcrumb`, `Body/Lines/TitleRow/NameLabel`, `Body/Lines/TitleRow/Badge`, `Body/Lines/DetailLabel`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
const _HISTORY_ROW_SCENE := "res://Scenes/SchoolSimulation/WeekHistoryRow.tscn"


func test_history_row_renders_a_minigame_win() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	row.set_entry({
		"day": "Senin", "category": "Olahraga",
		"game_name": "Lomba Badminton", "won": true,
		"score": 3, "max_score": 5,
		"results": [{"student_name": "Budi"}, {"student_name": "Doni"}],
	})
	assert_contains(_row_text(row, "Breadcrumb"), "Senin",
		"the day leads the breadcrumb")
	assert_contains(_row_text(row, "Breadcrumb"), "Olahraga",
		"the category follows it")
	assert_eq(_row_text(row, "TitleRow/NameLabel"), "Lomba Badminton",
		"the game name is the row's title")
	assert_contains(_row_text(row, "DetailLabel"), "Budi",
		"participants are named -- this is the new information")
	assert_contains(_row_text(row, "DetailLabel"), "3/5",
		"and the score is carried")


func test_history_row_renders_an_event_with_affected_students() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	row.set_entry({
		"day": "Rabu", "category": "Event", "game_name": "Hujan Deras",
		"won": true, "details": "Semua siswa kehilangan 5 energi",
		"affected_students": ["Ani", "Cici"],
	})
	assert_contains(_row_text(row, "DetailLabel"), "Ani",
		"affected students are named")
	assert_contains(_row_text(row, "DetailLabel"), "kehilangan",
		"and the event's own details are shown")


func test_history_row_hides_the_detail_line_when_there_is_nothing_to_say() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	row.set_entry({"day": "Kamis", "category": "Akademis",
		"game_name": "Password", "won": false})
	var detail: Label = row.get_node("Body/Lines/DetailLabel")
	assert_false(detail.visible,
		"an entry with no participants and no details collapses to two lines")


func test_history_row_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekHistoryRow.gd")
	for glyph in ["📢", "📊", "📝"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography; use the SVG icons")


func _row_text(row: Control, path: String) -> String:
	return (row.get_node("Body/Lines/" + path) as Label).text
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — the history row scene does not exist.

- [ ] **Step 3: Write the script**

Create `Scripts/SchoolSimulation/WeekHistoryRow.gd`:

```gdscript
@tool
extends PanelContainer
class_name WeekHistoryRow

## One line of the week's RIWAYAT: a minigame that was played or an event
## that fired (2026-09-03 spec section 5).
##
## Replaces ResultCheckup._create_history_item(), which built the same
## row node-by-node at runtime -- debt that
## tests/test_viewport_editability.gd ratchets against.
##
## Three lines, because the old one-line row threw information away: the
## breadcrumb (day and category), the title (name and outcome badge), and
## the detail line naming WHO it happened to and WHAT it did. That third
## line is recorded by StudentManager today and shown nowhere.
##
## @tool so the editor's test runner can instantiate and inspect it.

## The history category marking an entry as an event rather than a played
## minigame. Mirrors WeekRecap.EVENT_CATEGORY.
const EVENT_CATEGORY := "Event"

## Separator between the participants and the details on the third line.
const DETAIL_JOIN := "  ·  "

@onready var icon: TextureRect = $Body/Icon
@onready var breadcrumb: Label = $Body/Lines/Breadcrumb
@onready var name_label: Label = $Body/Lines/TitleRow/NameLabel
@onready var badge: PanelContainer = $Body/Lines/TitleRow/Badge
@onready var detail_label: Label = $Body/Lines/DetailLabel

# ── Visual - Icons ───────────────────────────────────────────────────
@export_group("Visual - Icons")
## Leading icon for a minigame that was won.
@export var icon_won: Texture2D = null
## Leading icon for a minigame that was lost.
@export var icon_lost: Texture2D = null
## Leading icon for a random event.
@export var icon_event: Texture2D = null


## Render one StudentManager history entry. Tolerant of a partial entry:
## anything missing simply does not render, rather than printing a
## confident blank.
func set_entry(entry: Dictionary) -> void:
	var t := Juice.tokens()
	var category: String = entry.get("category", "")
	var is_event: bool = category == EVENT_CATEGORY
	var won: bool = entry.get("won", false)

	breadcrumb.text = "%s · %s" % [entry.get("day", ""), category]
	name_label.text = entry.get("game_name", "")

	if icon:
		icon.texture = icon_event if is_event else (
			icon_won if won else icon_lost)

	var badge_text := " EVENT "
	var badge_tint := t.brand_primary
	if not is_event:
		badge_text = " BERHASIL " if won else " GAGAL "
		badge_tint = t.state_success if won else t.state_danger
	badge.self_modulate = badge_tint
	(badge.get_node("Text") as Label).text = badge_text

	var detail := _build_detail(entry)
	detail_label.text = detail
	# Hidden rather than blanked: an empty label still claims its line
	# height and leaves the row looking broken.
	detail_label.visible = detail != ""


## "Budi, Doni  ·  3/5" or "Ani, Cici  ·  Semua siswa kehilangan 5
## energi" -- whichever parts this entry actually carries.
func _build_detail(entry: Dictionary) -> String:
	var parts: Array[String] = []

	var who := _participants(entry)
	if who != "":
		parts.append(who)

	var details: String = entry.get("details", "")
	if details != "":
		parts.append(details)

	if entry.has("max_score") and int(entry.get("max_score", 0)) > 0:
		parts.append("%d/%d" % [int(entry.get("score", 0)),
			int(entry.get("max_score", 0))])

	return DETAIL_JOIN.join(parts)


## The names this entry touched. Events record them directly as
## affected_students; minigames carry a results array of per-student
## dictionaries instead.
func _participants(entry: Dictionary) -> String:
	var names: Array[String] = []
	for who in entry.get("affected_students", []):
		names.append(str(who))
	if names.is_empty():
		for res in entry.get("results", []):
			if res is Dictionary and res.has("student_name"):
				names.append(str(res["student_name"]))
	return ", ".join(names)
```

- [ ] **Step 4: Build the scene via MCP**

1. Root `PanelContainer` named `WeekHistoryRow`, `theme_type_variation = "SunkenPanel"`, `size_flags_horizontal = 3`, script attached.
2. Child `HBoxContainer` named `Body`, `separation = 20`, with `margin`-style padding supplied by the variation.
3. Under `Body`: `TextureRect` named `Icon`, `custom_minimum_size = Vector2(64, 64)`, `expand_mode = 1`, `stretch_mode = 5`.
4. Under `Body`: `VBoxContainer` named `Lines`, `size_flags_horizontal = 3`, `separation = 4`.
5. Under `Lines`: `Label` `Breadcrumb` (`theme_type_variation = "CaptionLabel"`).
6. Under `Lines`: `HBoxContainer` `TitleRow` with `Label` `NameLabel` (`theme_type_variation = "TitleLabel"`, `size_flags_horizontal = 3`, `autowrap_mode = 2`) and an instance of `DaySummaryBadge.tscn` named `Badge`.
7. Under `Lines`: `Label` `DetailLabel` (`theme_type_variation = "MicroLabel"`, `autowrap_mode = 2`).
8. Set the three icon exports to `icon_minigame_menang.svg`, `icon_minigame_kalah.svg`, `icon_event.svg`.
9. `scene_save`.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: the four history-row tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/WeekHistoryRow.gd Scenes/SchoolSimulation/WeekHistoryRow.tscn tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): add the three-line WeekHistoryRow template"
```

---

## Task 8: Restructure ResultCheckup.tscn

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn` (controller builds via MCP)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `WeekRecapBanner.tscn` (Task 6), `WeekHistoryRow.tscn` (Task 7).
- Produces: the node paths `Scripts/SchoolSimulation/ResultCheckup.gd` binds in Task 9 — `Margin/VBox/Banner`, `Margin/VBox/TabBar/TabSiswa`, `Margin/VBox/TabBar/TabRiwayat`, `Margin/VBox/ScrollContainer/PaneStack/StudentsPane`, `Margin/VBox/ScrollContainer/PaneStack/HistoryPane`, `Margin/VBox/ScrollContainer/PaneStack/HistoryPane/EmptyLabel`, `Margin/VBox/BtnClose`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
func test_screen_authors_the_banner_tabs_and_both_panes() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	for path in ["Margin/VBox/Banner",
			"Margin/VBox/TabBar/TabSiswa",
			"Margin/VBox/TabBar/TabRiwayat",
			"Margin/VBox/ScrollContainer/PaneStack/StudentsPane",
			"Margin/VBox/ScrollContainer/PaneStack/HistoryPane",
			"Margin/VBox/ScrollContainer/PaneStack/HistoryPane/EmptyLabel"]:
		assert_not_null(screen.get_node_or_null(path),
			"%s is authored in the scene" % path)
	screen.free()


func test_banner_and_tabs_sit_outside_the_scroll() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var scroll: Node = screen.get_node("Margin/VBox/ScrollContainer")
	assert_false(scroll.is_ancestor_of(screen.get_node("Margin/VBox/Banner")),
		"the banner must stay pinned while the panes scroll")
	assert_false(scroll.is_ancestor_of(screen.get_node("Margin/VBox/TabBar")),
		"and so must the tab bar")
	screen.free()


func test_students_pane_uses_the_spec_separation() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var pane: VBoxContainer = screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane")
	assert_eq(pane.get_theme_constant("separation"), 28,
		"card separation drops 56 -> 28 (spec section 3)")
	screen.free()


func test_scene_carries_no_emoji_and_no_dead_section_headers() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography")
	assert_false(src.contains("StudentsHeader"),
		"the emoji section headers are replaced by the tab labels")
	assert_false(src.contains("HistoryHeader"),
		"both of them")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — `Margin/VBox/Banner` is not authored.

- [ ] **Step 3: Restructure the scene via MCP**

The editor caches every scene, so this is done through `scene_open` → node ops → `scene_save`, never by editing the `.tscn` text.

Delete: `Margin/VBox/HSeparator`, `Margin/VBox/HSeparator2`, `Margin/VBox/ScrollContainer/MainContent/StudentsHeader`, `.../HistoryHeader`, `.../HSeparator`.

Rename/restructure under `Margin/VBox`, in this order (`node_create` appends last, so use `move_node` to get the order right):

1. `Banner` — instance of `WeekRecapBanner.tscn`, first child of `VBox`.
2. `TabBar` — `HBoxContainer`, `separation = 8`, containing two `Button`s: `TabSiswa` and `TabRiwayat`, each `theme_type_variation = "WeekTabButton"`, `toggle_mode = true`, `size_flags_horizontal = 3`, `custom_minimum_size = Vector2(0, 88)`. `TabSiswa.button_pressed = true`.
3. `ScrollContainer` — keep the existing node; `size_flags_vertical = 3`, `horizontal_scroll_mode = 0`.
4. Rename `MainContent` → `PaneStack`; keep `size_flags_horizontal = 3`, set `separation = 0`.
5. Rename `StudentsContainer` → `StudentsPane`, move under `PaneStack`, set `theme_override_constants/separation = 28` and `alignment = 1` (layout-only constant, permitted).
6. Rename `HistoryList` → `HistoryPane`, move under `PaneStack`, `separation = 16`, `visible = false`.
7. Add `EmptyLabel` under `HistoryPane`: `Label`, `theme_type_variation = "EmptyStateLabel"`, `text = "Tidak ada minigame yang dimainkan minggu ini."`, `horizontal_alignment = 1`, `autowrap_mode = 2`, `visible = false`.
8. Add `ScrollFade` — a `TextureRect` or themed `Panel` pinned to the bottom edge of `VBox` above `BtnClose`, `custom_minimum_size = Vector2(0, 96)`, `mouse_filter = 2` (`IGNORE`). Use a themed panel rather than a runtime gradient.
9. Keep `BtnClose` last, and keep `Celebration` as a child of the root at `z_index = 100`.
10. Set the root's `Margin` constants to 36 on all four sides (spec §3).
11. `scene_save`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `test_run(suite="result_checkup")`
Expected: the four structure tests PASS. Tests that reference the old `StudentsContainer`/`HistoryList` paths will now fail — they are updated in Task 9, which is the task that rewrites the script that owns them. That is expected and is the only point in this plan where the suite is knowingly red between tasks.

- [ ] **Step 5: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): restructure the scene into a pinned banner over two panes"
```

---

## Task 9: Rewrite ResultCheckup.gd

**Files:**
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: everything from Tasks 1, 5, 6, 7, plus `DaySummaryStudentRow.setup_week_row/play_week_gain/gained_ground` (unchanged).
- Produces: `initialize_checkup(student_manager: StudentManager) -> void` (unchanged signature) and the `checkup_closed` signal (unchanged).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`, and update any existing test that referenced `StudentsContainer` or `HistoryList` to the new `StudentsPane` / `HistoryPane` paths:

```gdscript
func test_script_no_longer_builds_history_rows_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("_create_history_item"),
		"the runtime row builder is replaced by WeekHistoryRow.tscn")
	assert_false(src.contains("PanelContainer.new()"),
		"no PanelContainer is constructed at runtime")
	assert_false(src.contains("Label.new()"),
		"nor the empty-state Label")


func test_script_drops_the_dead_section_header_exports() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for dead in ["students_section_header_text",
			"history_section_header_text",
			"students_header_icon_texture",
			"history_header_icon_texture",
			"StudentsSectionHeader", "HistorySectionHeader"]:
		assert_false(src.contains(dead),
			"%s never rendered -- it is removed, not repaired" % dead)


func test_script_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned")


func test_default_tab_is_siswa() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	assert_true(screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane").visible,
		"the screen opens on the students pane")
	assert_false(screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/HistoryPane").visible,
		"the history pane starts hidden")
	screen.queue_free()


func test_switching_tabs_swaps_pane_visibility_without_freeing() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	var students: Node = screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane")
	var history: Node = screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/HistoryPane")
	screen.show_pane(1)
	assert_false(students.visible, "students pane hides")
	assert_true(history.visible, "history pane shows")
	assert_true(is_instance_valid(students),
		"panes are hidden, never freed")
	screen.show_pane(0)
	assert_true(students.visible, "and it comes back")
	screen.queue_free()


func test_each_pane_keeps_its_own_scroll_offset() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	var scroll: ScrollContainer = screen.get_node(
		"Margin/VBox/ScrollContainer")
	scroll.scroll_vertical = 400
	screen.show_pane(1)
	assert_eq(scroll.scroll_vertical, 0,
		"the history pane opens at its own top")
	screen.show_pane(0)
	assert_eq(scroll.scroll_vertical, 400,
		"returning to SISWA restores where you were reading")
	screen.queue_free()


func test_history_pane_animation_latch_fires_only_once() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	screen.show_pane(1)
	assert_true(screen._history_animated,
		"the first open latches the animation")
	screen.show_pane(0)
	screen.show_pane(1)
	assert_true(screen._history_animated,
		"and it stays latched, so audio never re-fires")
	screen.queue_free()


## Adds a screen to the tree with the baked theme assigned. ThemeDB's
## project-theme fallback does not populate under the editor's own root,
## so the theme is set explicitly -- the same pattern the suite's other
## in-tree tests use.
func _add_themed(screen: Control) -> void:
	screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(screen)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="result_checkup")`
Expected: FAIL — `_create_history_item` still present, `show_pane` not defined.

- [ ] **Step 3: Write the implementation**

Replace `Scripts/SchoolSimulation/ResultCheckup.gd` in full:

```gdscript
@tool
extends Control

## The end-of-week report: a pinned WeekRecapBanner over two tabbed
## panes -- SISWA (one DaySummaryStudentRow per student, read one week
## wide) and RIWAYAT (the week's minigames and events as WeekHistoryRows)
## -- rebuilt to the 2026-09-03 spec.
##
## Everything visual is an authored scene. This script only decides
## WHICH deltas a card shows (DaySummaryStudentRow.setup_week_row), which
## pane is visible, and when the entrance's five stages fire. Stages 1-3
## belong to the banner; stages 4-5 are here, because this is what owns
## the cards.
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect
## is gated on Engine.is_editor_hint(); signal wiring deliberately is
## not.
##
## Every surface is a theme variation and every accent is a DesignToken;
## this script builds no StyleBoxFlat and holds no Color literal.

signal checkup_closed

## The two panes, in tab order. Indices into _panes and the argument
## show_pane takes.
enum Pane { SISWA = 0, RIWAYAT = 1 }

# ── Visual - Background Overlay ───────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the report. When set it replaces the panel.
@export var background_texture: Texture2D = null

# ── Visual - Header & Typography ──────────────────────────────────────
@export_group("Visual - Header & Typography")
## Main header title.
@export var header_title_text: String = "EVALUASI MINGGUAN SISWA"
## Main header subtitle, under header_title_text.
@export var header_subtitle_text: String = "Perkembangan statistik & riwayat kegiatan selama satu minggu"
## Optional font override applied across the screen's labels. Null keeps
## the theme's default font.
@export var font: Font = null

# ── Visual - Tabs ────────────────────────────────────────────────────
@export_group("Visual - Tabs")
## Label on the students tab. The live count is appended in brackets.
@export var tab_students_text: String = "SISWA"
## Label on the history tab. The live count is appended in brackets.
@export var tab_history_text: String = "RIWAYAT"

# ── Visual - Buttons ─────────────────────────────────────────────────
@export_group("Visual - Buttons")
## Art-supplied close-button texture. Null keeps the theme's button
## styling and shows close_button_text as a plain label instead.
@export var button_close_texture: Texture2D = null
## Label shown on the close button when button_close_texture is null.
@export var close_button_text: String = "Selesai Evaluasi"

# ── Wiring ───────────────────────────────────────────────────────────
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene
## The history row template, WeekHistoryRow.tscn.
@export var history_row_scene: PackedScene

const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/CelebrationConfetti.tscn"

@onready var title_label: Label = $Margin/VBox/HeaderPanel/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/HeaderPanel/SubtitleLabel
@onready var banner: WeekRecapBanner = $Margin/VBox/Banner
@onready var tab_siswa: Button = $Margin/VBox/TabBar/TabSiswa
@onready var tab_riwayat: Button = $Margin/VBox/TabBar/TabRiwayat
@onready var scroll_container: ScrollContainer = $Margin/VBox/ScrollContainer
@onready var students_pane: VBoxContainer = $Margin/VBox/ScrollContainer/PaneStack/StudentsPane
@onready var history_pane: VBoxContainer = $Margin/VBox/ScrollContainer/PaneStack/HistoryPane
@onready var history_empty_label: Label = $Margin/VBox/ScrollContainer/PaneStack/HistoryPane/EmptyLabel
@onready var btn_close: Button = $Margin/VBox/BtnClose

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

## The active tab, as a Pane value.
var _active_pane: int = Pane.SISWA
## Each pane's own last scroll offset, so switching back returns to the
## card you were reading rather than snapping to the top.
var _pane_scroll: Array[int] = [0, 0]
## Latched the first time RIWAYAT opens. Its rows stagger in once; every
## later switch is an instant show, so tabbing back and forth never
## re-fires the stamp cue.
var _history_animated: bool = false
## The instanced history rows, kept so the lazy first animation can reach
## them without re-walking the tree.
var _history_rows: Array = []


func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can
	# exercise it; everything below the guard is a real side effect.
	btn_close.pressed.connect(_on_close_pressed)
	tab_siswa.pressed.connect(show_pane.bind(Pane.SISWA))
	tab_riwayat.pressed.connect(show_pane.bind(Pane.RIWAYAT))
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)
	_sync_tab_buttons()
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	_apply_visual_exports()
	btn_close.modulate.a = 0.0
	btn_close.disabled = true


func initialize_checkup(student_manager: StudentManager) -> void:
	_apply_visual_exports()

	var recap: Dictionary = WeekRecap.compute(student_manager)
	banner.set_recap(recap)

	for child in students_pane.get_children():
		child.queue_free()
	for child in history_pane.get_children():
		if child != history_empty_label:
			child.queue_free()
	_history_rows.clear()

	if student_manager == null:
		_update_tab_counts(0, 0)
		return

	var cards: Array = []
	for student in student_manager.students:
		var card := student_card_scene.instantiate() as DaySummaryStudentRow
		students_pane.add_child(card)
		# Set up only once the card is in the tree: its @onready nodes
		# are null until then. Same order DaySummaryPopup.setup_summary
		# uses.
		card.setup_week_row(student)
		_set_mouse_filter_pass(card)
		cards.append(card)

	var history: Array = student_manager.minigame_history
	history_empty_label.visible = history.is_empty()
	for entry in history:
		var row := history_row_scene.instantiate() as WeekHistoryRow
		history_pane.add_child(row)
		row.set_entry(entry)
		_set_mouse_filter_pass(row)
		_history_rows.append(row)

	_update_tab_counts(cards.size(), history.size())
	_play_entrance_animations(cards)


## Show one pane and hide the other, remembering where each was scrolled
## to. Safe to call with the already-active pane: it is a no-op and plays
## nothing, so a second tap on the live tab is silent.
func show_pane(pane: int) -> void:
	if pane == _active_pane and students_pane.visible != history_pane.visible:
		return
	if scroll_container:
		_pane_scroll[_active_pane] = scroll_container.scroll_vertical
	_active_pane = pane
	students_pane.visible = pane == Pane.SISWA
	history_pane.visible = pane == Pane.RIWAYAT
	if scroll_container:
		scroll_container.scroll_vertical = _pane_scroll[pane]
	_sync_tab_buttons()

	if Engine.is_editor_hint():
		_history_animated = _history_animated or pane == Pane.RIWAYAT
		return

	AudioDirector.play_sfx(&"select")
	if pane == Pane.RIWAYAT and not _history_animated:
		_history_animated = true
		_play_history_entrance()


## Keep the two toggle buttons agreeing with _active_pane. The pressed
## state is what the WeekTabButton variation styles, so no manual tint is
## needed here.
func _sync_tab_buttons() -> void:
	if tab_siswa:
		tab_siswa.button_pressed = _active_pane == Pane.SISWA
	if tab_riwayat:
		tab_riwayat.button_pressed = _active_pane == Pane.RIWAYAT


## "SISWA (4)" / "RIWAYAT (7)" -- so the player can see there is
## something worth tapping before tapping it.
func _update_tab_counts(student_count: int, history_count: int) -> void:
	if tab_siswa:
		tab_siswa.text = "%s (%d)" % [tab_students_text, student_count]
	if tab_riwayat:
		tab_riwayat.text = "%s (%d)" % [tab_history_text, history_count]


func _apply_visual_exports() -> void:
	# The themed panel is the default backdrop; an art-supplied photo
	# replaces it outright. Guarded on `is Panel` so a second call cannot
	# stack another TextureRect.
	var bg = get_node_or_null("Background")
	if bg is Panel and background_texture:
		var tex_rect = TextureRect.new()
		tex_rect.name = "Background"
		tex_rect.texture = background_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.queue_free()
		add_child(tex_rect)
		move_child(tex_rect, 0)

	if title_label:
		title_label.text = header_title_text
		if font: title_label.add_theme_font_override("font", font)

	if subtitle_label:
		subtitle_label.text = header_subtitle_text
		if font: subtitle_label.add_theme_font_override("font", font)

	if btn_close:
		btn_close.text = "" if button_close_texture else close_button_text
		if font: btn_close.add_theme_font_override("font", font)
		if button_close_texture:
			var sb = StyleBoxTexture.new()
			sb.texture = button_close_texture
			btn_close.add_theme_stylebox_override("normal", sb)
			btn_close.add_theme_stylebox_override("hover", sb)
			btn_close.add_theme_stylebox_override("pressed", sb)


func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control:
		if not node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)


## RIWAYAT's lazy first open: rows stagger in, a win stamping into place
## and a loss shaking. Latched by show_pane, so this runs at most once.
func _play_history_entrance() -> void:
	Juice.stagger_in(_history_rows)
	var t := Juice.tokens()
	for i in _history_rows.size():
		var row: WeekHistoryRow = _history_rows[i]
		var entry_won: bool = row.badge.self_modulate == t.state_success
		if entry_won:
			AudioDirector.play_sfx(&"stamp")
		else:
			Juice.shake(row)


func _play_entrance_animations(cards: Array = []) -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return

	var t := Juice.tokens()
	modulate.a = 0.0
	var fader = create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	# Stages 1-3 belong to the banner: slide, four pill count-ups, and
	# the gated coin shower.
	banner.play_entrance()
	await get_tree().create_timer(t.dur_normal).timeout

	# Stage 4. Cards land one at a time, each card's five gauges moving
	# on the beat that card ARRIVES on -- the nightly popup's own
	# cadence, one week long.
	Juice.stagger_in(cards)
	for i in cards.size():
		cards[i].play_week_gain(float(i) * t.stagger_step)

	# Stage 5. One celebration for the whole week, landing just behind
	# the last card's own burst -- and only if the week went somewhere. A
	# flat or losing week gets the report without the party.
	var week_gained := false
	for card in cards:
		if card.gained_ground():
			week_gained = true
			break
	if week_gained:
		AudioDirector.play_sfx(&"reward")
		var celebration_scene: PackedScene = load(_CELEBRATION_SCENE)
		var celebration := celebration_scene.instantiate() as RewardParticles
		celebration.position = get_node("Celebration").position
		add_child(celebration)
		celebration.fire(float(cards.size()) * t.stagger_step)

	await get_tree().create_timer(t.dur_slow).timeout

	var button_tween = create_tween()
	button_tween.tween_property(btn_close, "modulate:a", 1.0, t.dur_fast)
	btn_close.disabled = false


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_scroll = true
			drag_start_y = event.global_position.y
			initial_scroll_v = scroll_container.scroll_vertical
		else:
			is_dragging_scroll = false
	elif event is InputEventMouseMotion and is_dragging_scroll:
		var delta_y = event.global_position.y - drag_start_y
		scroll_container.scroll_vertical = int(initial_scroll_v - delta_y)


func _on_close_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
	await fade_out.finished
	checkup_closed.emit()
```

- [ ] **Step 4: Wire the new export in the scene**

Via MCP: set the root's `history_row_scene` to `WeekHistoryRow.tscn`, then `scene_save`.

- [ ] **Step 5: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup")`
Expected: PASS, every test in the suite including the ones updated from the old node paths.

If a test reports an unknown `show_pane`, force a script reload with a no-op `script_patch` on `ResultCheckup.gd`, then re-run.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/ResultCheckup.gd Scenes/SchoolSimulation/ResultCheckup.tscn tests/test_result_checkup.gd
git commit -m "feat(resultcheckup): rewrite the screen onto tabs, panes and the recap banner"
```

---

## Task 10: Point RewardBurst at the new sprites

**Files:**
- Modify: `Scenes/SchoolSimulation/RewardBurst.tscn` (controller builds via MCP)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `particle_spark.png`, `particle_plus.png` (Task 3).
- Produces: nothing new. `RewardBurst.fire()` is unchanged.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The per-stat burst moves off the generic star onto the pass's own
## sprites (2026-09-03 recap spec section 7).
func test_reward_burst_uses_the_new_particle_sprites() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/RewardBurst.tscn")
	assert_contains(src, "particle_spark.png",
		"the glint replaces the generic star")
	assert_contains(src, "particle_plus.png",
		"and a + rides along with it")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="day_summary")`
Expected: FAIL — `particle_spark.png` not in the scene.

- [ ] **Step 3: Edit the scene via MCP**

1. `scene_open("res://Scenes/SchoolSimulation/RewardBurst.tscn")`.
2. Set the root's `texture` to `res://Assets/Images/Particles/particle_spark.png`.
3. `node_create` a second `GPUParticles2D` child named `PlusBurst`, script `RewardParticles.gd`, `plays_sfx = false`, `amount = 5`, `lifetime = 0.8`, `one_shot = true`, `explosiveness = 1.0`, `texture` = `particle_plus.png`, and a `ParticleProcessMaterial` with `direction = Vector3(0, -1, 0)`, `initial_velocity_min = 90`, `initial_velocity_max = 150`, `gravity = Vector3(0, 260, 0)`, `scale_min = 0.16`, `scale_max = 0.24`.
4. `scene_save`.

`RewardParticles.fire()` frees its own node when spent, and `PlusBurst` is a child of a node that also frees itself — so `PlusBurst` must be fired by the same gesture that fires its parent. Add to `RewardParticles.fire()`, immediately after `emitting = true`:

```gdscript
	# A nested emitter (RewardBurst's PlusBurst) rides the same gesture.
	# Fired directly rather than awaited: this node frees itself when
	# spent, and a child cannot outlive it anyway.
	for child in get_children():
		if child is GPUParticles2D:
			child.restart()
			child.emitting = true
```

- [ ] **Step 4: Rescan and run the test to verify it passes**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="day_summary")`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scenes/SchoolSimulation/RewardBurst.tscn Scripts/SchoolSimulation/RewardParticles.gd tests/test_day_summary.gd
git commit -m "feat(daysummary): point the reward burst at the spark and plus sprites"
```

---

## Task 11: Lower the editability baseline and verify the whole suite

**Files:**
- Modify: `tests/test_viewport_editability.gd`

**Interfaces:**
- Consumes: the now-authored `WeekHistoryRow.tscn` and `EmptyLabel`.
- Produces: nothing.

- [ ] **Step 1: Read the current baseline entry**

```bash
grep -n "ResultCheckup" tests/test_viewport_editability.gd
```

Note the number recorded for `ResultCheckup.gd`.

- [ ] **Step 2: Run the suite to see the new, lower count**

Run: `test_run(suite="viewport_editability")`
Expected: FAIL, reporting that `ResultCheckup.gd`'s actual count is now **below** its `BASELINE` — Task 9 removed `PanelContainer.new()`, `MarginContainer.new()`, `HBoxContainer.new()`, three `Label.new()` calls and the `_make_badge` load.

- [ ] **Step 3: Lower the baseline to the reported actual**

Edit `tests/test_viewport_editability.gd` and set `ResultCheckup.gd`'s `BASELINE` value to the number the run just reported. **The ratchet is one-way: only ever lower it.** If the reported number is higher than the recorded one, stop — something in Task 9 reintroduced runtime construction, and that is a bug to fix rather than a baseline to raise.

- [ ] **Step 4: Run the full suite**

Run: `test_run()` with no suite filter.
Expected: every suite green. Open `Scenes/MainMenu/main_menu.tscn` in the editor first — several suites assume the main scene is open and `test_run` returns a `scene_warning` naming it when it is not.

- [ ] **Step 5: Verify it visually**

Run the game, open the debug overlay (`F1`, or 5 taps top-right), hit **⚡ Seed Playtest State**, then use the **Scenes** tab. `ResultCheckup` is schedule-driven, so the seed alone is not enough — pass through Atur Jadwal and run a week first, then take one `editor_screenshot` of the finished screen.

Check against the spec: the banner and tabs stay pinned while the pane scrolls; the four pills read correctly; both tabs switch without a rebuild; no emoji anywhere; the bottom fade is visible under a full pane.

- [ ] **Step 6: Commit**

```bash
git add tests/test_viewport_editability.gd
git commit -m "test(hygiene): lower ResultCheckup's runtime-construction baseline"
```

---

## Notes for the executor

**Task order matters.** Tasks 1–4 are independent of each other and could run in parallel; Tasks 5–7 depend on 3 and 4 (sprites and theme variations); Task 8 depends on 6 and 7; Task 9 depends on 8; Tasks 10–11 come last.

**The suite is knowingly red between Tasks 8 and 9** — Task 8 renames the node paths that the old script and the old tests bind to, and Task 9 is what updates them. This is the only such window in the plan. Do not "fix" it by reverting Task 8.

**The `@onready` path assumption appears twice** (Tasks 5 and 6). Both scripts assume their key nodes are direct children of the scene root. If you nest them under a layout container instead, update the script's `@onready` paths *and* the test's `get_node` paths in the same commit — a mismatch there fails as a null dereference, which reads like a scene problem and is not.
