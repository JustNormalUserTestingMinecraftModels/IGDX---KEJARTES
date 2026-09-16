# Weekly Results Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder top, the green student card, the bare pill
popup and the cramped Logs on Weekly Results with a consistent
kartu-pelajar / report-masthead treatment built from the existing theme
families.

**Architecture:** Pure visual/layout rework of `ResultCheckup` and its four
authored sub-scenes plus one small data addition (a `stars` field on the
week recap). No navigation or simulation changes. New surface looks enter
as reusable `ThemeFactory` variations (never `theme_override_*`, never
runtime-built) and new art enters as generated project-style SVG at real,
drop-replaceable paths.

**Tech Stack:** Godot 4.6, GDScript `@tool` scenes/tests, the `godot-ai`
MCP editor bridge, `ThemeFactory` + `DesignTokens` theming, `Juice` /
`AnimUtils` animation.

**Spec:** `docs/superpowers/specs/2026-09-16-weekly-results-polish-design.md`

## Global Constraints

- **Branch/workspace:** all work on `feat/weekly-results-polish` in the
  worktree `.claude/worktrees/weekly-results-polish`. The shared main
  checkout holds unrelated koperasi WIP — never touch it.
- **No `theme_override_*`** except layout-only constants (`separation`,
  `margin_*`). New looks are `ThemeFactory` variations, then rebake via
  `Scripts/Design/BakeTheme.gd` (File > Run, Ctrl+Shift+X).
- **No visual built at runtime** — static chrome is a node in the `.tscn`;
  responsive geometry is a documented `@tool` `@export`. `##` file header
  and a `##` on every `@export` are mandatory (`test_script_documentation`).
- **Edit scenes through the editor MCP** (`scene_open` → `node_*` /
  `batch_execute` → `scene_save`), never by hand-editing `.tscn` while the
  editor is attached. Do scene work first, script work second; after any
  `.gd` edit `filesystem_manage(op="scan")` before `test_run`; a new/changed
  Resource `@export` default or `class_name` needs an editor restart.
- **Tests run in-editor** via `test_run(suite="...")`; prefer targeted runs
  over full runs (a full run drops the bridge and rebakes the theme + bus
  layout — `git checkout --` anything you did not intend afterward). Suites
  are `@tool`, no coroutines, side effects gated on
  `Engine.is_editor_hint()`. Many assertions are source-text scans
  (`src.contains(...)`) — follow that established pattern.
- **The bridge is single-client:** the human operator runs the editor and
  reports `test_run` results; subagents write code only.
- **Indonesian** for all UI text; English for systems code. Conventional
  Commits with a scope. `Balance.gd` is read-only.
- **Art:** every generated SVG stays drop-replaceable at its path; retire
  `Assets/Images/UI/Placeholders/icon_*.svg` to a non-`Placeholders/` path.
- Pass metric verbatim: `GameState.run_stars() -> float`, win at
  `>= Balance.STAR_WIN_THRESHOLD` (out of 3.0).

---

### Task 1: Add a `stars` field to the week recap

**Files:**
- Modify: `Scripts/SchoolSimulation/WeekRecap.gd` (the `compute()` result dict)
- Test: `tests/test_week_recap.gd`

**Interfaces:**
- Consumes: `GameState.run_stars() -> float`.
- Produces: `WeekRecap.compute(student_manager) -> Dictionary` now carries
  `"stars": float` (0.0–3.0), alongside the existing `money_earned`,
  `net_skill_delta`, `minigames_won`, `minigames_total`, `events_count`.

- [ ] **Step 1: Write the failing test.** In `tests/test_week_recap.gd` add:

```gdscript
func test_compute_includes_stars() -> void:
	var sm := _make_student_manager()  # reuse this suite's existing helper
	var recap: Dictionary = WeekRecap.compute(sm)
	assert_true(recap.has("stars"), "recap must carry a stars field")
	assert_eq(typeof(recap["stars"]), TYPE_FLOAT, "stars is a float")
```

If the suite has no `_make_student_manager` helper, mirror whatever
construction the neighbouring `compute` tests already use.

- [ ] **Step 2: Run to verify it fails.** `filesystem_manage(op="scan")`
  then `test_run(suite="test_week_recap")`. Expected: FAIL (no `stars` key).

- [ ] **Step 3: Implement.** In `WeekRecap.compute()`, seed the result dict
  with `"stars": 0.0`, and before `return result` set:

```gdscript
	result["stars"] = GameState.run_stars()
```

Add a `##` comment noting stars is display-only here; the end-of-grade
screens remain the pass/fail authority.

- [ ] **Step 4: Run to verify it passes.** `filesystem_manage(op="scan")`
  then `test_run(suite="test_week_recap")`. Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Scripts/SchoolSimulation/WeekRecap.gd tests/test_week_recap.gd
git commit -m "feat(week-recap): expose run stars on the weekly recap"
```

---

### Task 2: ThemeFactory variations for the masthead and ID-card header

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add variations near the
  existing `ResultCardPanel` block, ~line 1491)
- Modify: `tests/test_theme_factory.gd` (assert the new variations exist;
  extend `DISPLAY_ROSTER` only if a new label variation takes the display
  font)
- Rebake: `Scripts/Design/BakeTheme.gd` → `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces theme type variations, consumed by later tasks:
  - `RecapMastheadPanel` — brown brand band (derive from the brand-primary
    panel used by `DayBannerPanel`/`EventDialoguePanel`; brand_primary fill,
    top radius, `text_on_brand` intent).
  - `IdCardPanel` — cream card frame with a brand top rule (derive from
    `ResultCardPanel`; add a top border in `brand_primary`). Used by the
    student card AND the popup/logs header so they read as one family.
  - `RecapChipPanel` — the quiet chip ground for the four masthead pills
    (derive from `Card` / `ResultBadgePanel`).
  - `MastheadTitleLabel`, `MastheadMetaLabel`, `MastheadStarsLabel` — only
    if existing `H1Label`/`CaptionLabel`/`DisplayLabel` don't already give
    the on-brand color; prefer reusing existing label variations first.

- [ ] **Step 1: Write the failing test.** In `tests/test_theme_factory.gd`
  add (matching the suite's existing variation-presence pattern):

```gdscript
func test_weekly_results_polish_variations_exist() -> void:
	var theme := ThemeFactory.build()  # use whatever this suite calls
	for v in ["RecapMastheadPanel", "IdCardPanel", "RecapChipPanel"]:
		assert_true(theme.has_stylebox("panel", v), "%s missing" % v)
```

- [ ] **Step 2: Run to verify it fails.** `filesystem_manage(op="scan")`,
  `test_run(suite="test_theme_factory")`. Expected: FAIL.

- [ ] **Step 3: Implement.** In `ThemeFactory.gd`, next to `ResultCardPanel`,
  add each variation following the exact local idiom (a `StyleBoxFlat`
  built from `DesignTokens` fields — `brand_primary`, `surface_card`,
  `outline_card`, radii — then `theme.add_type` / `set_type_variation` /
  `set_stylebox`). For `IdCardPanel`, start from the `ResultCardPanel`
  stylebox and set `border_width_top` with `border_color = tokens.brand_primary`.
  Every color comes from a token; build no `Color(...)` literal.

- [ ] **Step 4: Rebake + verify.** Run `Scripts/Design/BakeTheme.gd`
  (Ctrl+Shift+X), then `filesystem_manage(op="scan")` and
  `test_run(suite="test_theme_factory")`. Expected: PASS. Confirm
  `Assets/Theme/kejartes_theme.tres` changed and is intended.

- [ ] **Step 5: Commit.**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): add masthead and id-card panel variations"
```

---

### Task 3: Generate the report-masthead and pill art

**Files:**
- Create: `Assets/Images/DaySummary/crest.svg` (+ `.import`)
- Create: `Assets/Images/DaySummary/icon_uang.svg`, `icon_poin.svg`,
  `icon_menang.svg`, `icon_event.svg` (+ `.import`) — real replacements for
  `Assets/Images/UI/Placeholders/icon_*.svg`
- Create: `Assets/Images/DaySummary/portrait_frame.svg` (+ `.import`)
- Test: none (assets are asserted where they're wired, Tasks 4–6)

**Interfaces:**
- Produces stable `res://Assets/Images/DaySummary/*.svg` paths the scene
  `@export`s point at. Each SVG is authored in the project's flat,
  warm-line style (brown/cream, no gradients), sized for its slot
  (icons ~48px, crest ~64px, frame the portrait box).

- [ ] **Step 1: Author the SVGs** with the Write tool at the paths above,
  matching the visual weight of existing `Assets/Images/StudentCard/*`
  icons (inspect one first). Keep each a single flat shape set.

- [ ] **Step 2: Import.** `filesystem_manage(op="scan")` so Godot generates
  `.import` files; confirm no import errors in `logs_read(source="editor")`.

- [ ] **Step 3: Commit.**

```bash
git add Assets/Images/DaySummary/*.svg Assets/Images/DaySummary/*.import
git commit -m "feat(art): masthead crest, real pill icons, portrait frame"
```

---

### Task 4: Rebuild the top into a report masthead

**Files:**
- Modify: `Scenes/SchoolSimulation/WeekRecapBanner.tscn` (band + stars + chip strip)
- Modify: `Scripts/SchoolSimulation/WeekRecapBanner.gd` (stars label, real icon exports)
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn` (delete the duplicate `HeaderPanel`)
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd` (drop `title_label`/`subtitle_label` wiring)
- Test: `tests/test_result_checkup.gd`, `tests/test_week_recap.gd` (banner scans)

**Interfaces:**
- Consumes: `WeekRecap.compute()["stars"]` (Task 1); the icons at
  `res://Assets/Images/DaySummary/icon_*.svg` and `crest.svg` (Task 3);
  `RecapMastheadPanel`, `RecapChipPanel` (Task 2).
- Produces: `WeekRecapBanner` with a `MINGGU N · <grade>` line, a stars
  readout, and the four pills on the chip strip; `set_recap` writes the
  stars label; `ResultCheckup` no longer references `HeaderPanel`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_result_checkup.gd`:

```gdscript
func test_duplicate_header_removed() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/ResultCheckup.tscn")
	assert_false(src.contains("HeaderPanel"), "the redundant header must be gone")

func test_masthead_uses_real_pill_icons() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/WeekRecapBanner.tscn")
	assert_false(src.contains("UI/Placeholders/icon_"), "no placeholder icons")
	assert_true(src.contains("DaySummary/icon_uang"), "real money icon wired")

func test_masthead_shows_stars() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_true(src.contains("stars"), "banner surfaces the stars figure")
```

- [ ] **Step 2: Run to verify they fail.** `test_run(suite="test_result_checkup")`.
  Expected: FAIL on all three.

- [ ] **Step 3: Scene work (editor MCP).**
  `scene_open("res://Scenes/SchoolSimulation/WeekRecapBanner.tscn")`, then via
  `batch_execute`: set the banner's `Header` into the `RecapMastheadPanel`
  band; add a `Crest` `TextureRect` (crest.svg) and a `StarsLabel` `Label`
  (existing `DisplayLabel` or a masthead label variation) to the header;
  put the four `PillUang/PillPoin/PillMenang/PillEvent` on a `RecapChipPanel`
  ground; set each pill's icon export to the new `DaySummary/icon_*.svg`.
  `scene_save`. Then `scene_open` `ResultCheckup.tscn`, delete
  `Margin/VBox/HeaderPanel`, `scene_save`.

- [ ] **Step 4: Script work.** In `WeekRecapBanner.gd`: add a
  `@onready var stars_label` for the new node with a `##` doc; in
  `set_recap()` write `stars_label.text = "%.2f / 3.0" % recap.get("stars", 0.0)`;
  point the four `@export var icon_*` defaults / scene assignments at the new
  paths. In `ResultCheckup.gd`: remove the `title_label`/`subtitle_label`
  `@onready`s and every reference in `_apply_visual_exports()`; keep the
  `header_title_text`/`header_subtitle_text` exports out (delete them) since
  the band owns the words now. Add `count_up` on the stars label in
  `play_entrance` (via `Juice`), and a gentle crest idle wobble in
  `start_idle_bounce`. `filesystem_manage(op="scan")`; restart the editor if
  a Resource `@export` default changed.

- [ ] **Step 5: Run to verify pass + visual check.**
  `test_run(suite="test_result_checkup")` and `test_run(suite="test_week_recap")`.
  Expected: PASS. Then seed + screenshot ResultCheckup once (Debug ⚡ Seed →
  📊 Laporan Mingguan) to eyeball the masthead at full size.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/SchoolSimulation/WeekRecapBanner.tscn Scripts/SchoolSimulation/WeekRecapBanner.gd Scenes/SchoolSimulation/ResultCheckup.tscn Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd
git commit -m "feat(weekly-results): report masthead with stars, real icons, no duplicate header"
```

---

### Task 5: Kartu-pelajar student card

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` (retire
  `card_bg.png`; ID-card layout)
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` (only if node
  paths change — keep the `@onready` contract and both `setup_row` /
  `setup_week_row` entry points)
- Test: `tests/test_day_summary.gd`, `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `IdCardPanel` (Task 2); `portrait_frame.svg` (Task 3); the
  existing `StatBarAkademis` / `StatBarSeniBudaya` / `StatBarOlahraga` /
  `StatBarEnergy` / `StatBarMood` and `ResultDeltaLabel` variations.
- Produces: a re-skinned card with the same public node names (`avatar`,
  `name_label`, `stat_rows`, `energy_bar`, `mood_bar`, the delta
  chevrons/labels) so no simulation code changes.

- [ ] **Step 1: Write the failing test.** In `tests/test_day_summary.gd`:

```gdscript
func test_card_retires_green_bg() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	assert_false(src.contains("DaySummary/card_bg.png"), "green card retired")
	assert_true(src.contains("IdCardPanel"), "card uses the id-card frame")
```

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="test_day_summary")`.
  Expected: FAIL.

- [ ] **Step 3: Scene work (editor MCP).** `scene_open` the card. Replace the
  `CardArt` `TextureRect` (card_bg.png) with a `Panel` using `IdCardPanel`.
  Lay out per the spec sketch: left portrait `TextureRect` inside
  `portrait_frame.svg` + a NIS `ResultBadgePanel` chip; right column with
  `NameLabel`, the two existing trait chips, the three `StatRow*` (already
  `StatBar*`-themed), then the two needs sub-bars with their icons +
  `DeltaChevron`s. Preserve every node name the script `@onready`s. Because
  the card was authored at fixed offsets over art, follow authoring-guide
  Pattern C (draw from a child; set `layout_mode=1`). `scene_save`.

- [ ] **Step 4: Reconcile script.** If any `@onready` path moved, update it
  and its `##` doc; otherwise leave `DaySummaryStudentRow.gd` untouched.
  `filesystem_manage(op="scan")`.

- [ ] **Step 5: Run + visual check.** `test_run(suite="test_day_summary")`
  and `test_run(suite="test_result_checkup")`. Expected: PASS. Screenshot the
  card in BOTH contexts: nightly Daily Results (daily delta) and Weekly
  Results (week delta) — confirm it reads correctly for each.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd
git commit -m "feat(day-summary): kartu-pelajar card, retire the green card"
```

---

### Task 6: Pill explainer popup rework

**Files:**
- Modify: `Scenes/UI/WeekRecapPillInfoPopup.tscn`
- Modify: `Scripts/UI/WeekRecapPillInfoPopup.gd` (restated-number label)
- Test: `tests/test_week_recap_pill_info_popup.gd`

**Interfaces:**
- Consumes: `IdCardPanel` header treatment (Task 2); keeps the shared
  `Card` + `Scrim` skeleton and `SecondaryButton` close.
- Produces: `configure(icon, title, body)` unchanged in signature but now
  also driving a large restated value label; `AnimUtils.popup_spring_in`
  entrance.

- [ ] **Step 1: Write the failing test.** In
  `tests/test_week_recap_pill_info_popup.gd`:

```gdscript
func test_popup_stays_on_card_skeleton() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/UI/WeekRecapPillInfoPopup.tscn")
	assert_true(src.contains("Card"), "popup keeps the shared Card ground")
	assert_true(src.contains("Scrim"), "popup keeps the shared Scrim")
	assert_true(src.contains("IdCardPanel"), "popup wears the id-card header family")
```

- [ ] **Step 2: Run to verify it fails.**
  `test_run(suite="test_week_recap_pill_info_popup")`. Expected: FAIL.

- [ ] **Step 3: Scene work.** `scene_open` the popup. Wrap the header row in
  the `IdCardPanel` treatment (icon tile + title + `SecondaryButton` close),
  add a large centered value label (`DisplayLabel`) and a caption below the
  existing body line under a hairline. Keep it on `Card`/`Scrim`. `scene_save`.

- [ ] **Step 4: Script.** In `configure()`, set the new value label from the
  pill's number (pass it through from `WeekRecapBanner._on_pill_tapped`, or
  parse from the existing text if simpler — decide by what's cleanest).
  Swap the entrance to `AnimUtils.popup_spring_in`. Add `##` docs.
  `filesystem_manage(op="scan")`.

- [ ] **Step 5: Run + visual check.**
  `test_run(suite="test_week_recap_pill_info_popup")`. Expected: PASS.
  Screenshot one open pill popup.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/UI/WeekRecapPillInfoPopup.tscn Scripts/UI/WeekRecapPillInfoPopup.gd tests/test_week_recap_pill_info_popup.gd Scripts/SchoolSimulation/WeekRecapBanner.gd
git commit -m "feat(weekly-results): rework the pill explainer popup"
```

---

### Task 7: Readable Logs rows

**Files:**
- Modify: `Scenes/SchoolSimulation/WeekHistoryRow.tscn` (row height, type
  sizes, 40px icon tile, win/loss/event color+tag)
- Modify: `Scripts/SchoolSimulation/WeekHistoryRow.gd` (only if a node moves)
- Test: `tests/test_week_logs_popup.gd`

**Interfaces:**
- Consumes: existing category/state colors from `DesignTokens`; the sheet
  stays on `Card`/`Scrim`.
- Produces: `WeekHistoryRow.set_entry(entry)` unchanged; taller, higher-
  contrast rows.

- [ ] **Step 1: Write the failing test.** In `tests/test_week_logs_popup.gd`
  (or `test_week_history_row` if that's where row scans live), assert the
  row's minimum height and title font size meet a mobile floor, following
  the suite's existing scan idiom, e.g.:

```gdscript
func test_history_row_is_mobile_legible() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/WeekHistoryRow.tscn")
	assert_true(src.contains("custom_minimum_size"), "row sets a comfortable min height")
```

Tighten the assertion to the concrete height/variation you set in Step 3.

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="test_week_logs_popup")`.
  Expected: FAIL.

- [ ] **Step 3: Scene work.** `scene_open` the row. Raise `custom_minimum_size`
  height; bump title to `TitleLabel`-scale and meta to `CaptionLabel`; add a
  40px category-icon tile; encode win (state_success + check), loss
  (state_danger), event (cat_istirahat + EVENT tag) via themed nodes.
  `scene_save`.

- [ ] **Step 4: Reconcile script + scan.** Update any moved `@onready` and
  its `##`. `filesystem_manage(op="scan")`.

- [ ] **Step 5: Run + visual check.** `test_run(suite="test_week_logs_popup")`.
  Expected: PASS. Screenshot the open Logs sheet.

- [ ] **Step 6: Commit.**

```bash
git add Scenes/SchoolSimulation/WeekHistoryRow.tscn Scripts/SchoolSimulation/WeekHistoryRow.gd tests/test_week_logs_popup.gd
git commit -m "feat(weekly-results): enlarge and color-code the logs rows"
```

---

### Task 8: Ratchets, full-suite verification, changelog

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (newest first)
- Possibly: `tests/test_viewport_editability.gd` BASELINE/ALLOWED (only if a
  reviewed dynamic exception genuinely changed — never raise the baseline)

**Interfaces:** none produced; this task proves the pass is green and clean.

- [ ] **Step 1: Run the guardrail suites individually.**
  `test_run(suite="test_tall_screen_layout")`,
  `test_run(suite="test_script_documentation")`,
  `test_run(suite="test_viewport_editability")`,
  `test_run(suite="test_theme_factory")`. Expected: PASS. If tall-phone
  anchoring broke, fix per the authoring guide's "Tall phones". If a
  documentation scan fails, add the missing `##`.

- [ ] **Step 2: Full run once.** `test_run()` (whole suite). Budget one
  editor restart after (a full run drops the bridge). Then check
  `git status` — `git checkout --` any unintended change to
  `kejartes_theme.tres` or `default_bus_layout.tres` (rebake/audio side
  effects, per CLAUDE.md). Re-run alone any single theme assertion that
  failed on ordering before believing it.

- [ ] **Step 3: Changelog.** Prepend a `docs/superpowers/CHANGELOG.md` entry
  summarizing the pass (masthead + stars, kartu-pelajar card, reworked popup
  and logs, retired green card and placeholder icons).

- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/CHANGELOG.md tests/test_viewport_editability.gd
git commit -m "docs(changelog): weekly results polish pass"
```

- [ ] **Step 5: Ship.** Hand off to the `ship-pr` skill (runs the full suite
  + local review, opens the PR against `Textures`, stamps the tested commit).

---

## Self-Review

**Spec coverage:** masthead+stars (Tasks 1,4) · placeholder icons retired
(Tasks 3,4) · living vibe/animation (Task 4) · kartu-pelajar card, green card
retired, shared across both screens (Task 5) · pill popup rework, consistent
skeleton (Task 6) · logs readability (Task 7) · new art at real paths (Task 3)
· ThemeFactory variations + rebake (Task 2) · testing + ratchets + changelog
(Task 8). All spec sections map to a task.

**Placeholder scan:** the two spec "open questions" are resolved in the plan —
stars via `WeekRecap.compute` (Task 1), ID-card header as the `IdCardPanel`
variation (Task 2). No TBD/TODO steps.

**Type consistency:** `stars` (float) is produced in Task 1 and consumed by
name in Task 4; `RecapMastheadPanel`/`IdCardPanel`/`RecapChipPanel` are
produced in Task 2 and consumed by exact name in Tasks 4–7;
`DaySummaryStudentRow`'s `@onready` node names are explicitly preserved in
Task 5 so no simulation code drifts.
