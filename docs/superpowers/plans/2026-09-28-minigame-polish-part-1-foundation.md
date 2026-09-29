# Minigame Polish Part 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every step is tagged **[editor]** (needs the live Godot editor through the godot-ai MCP bridge — the controller does it; the bridge is single-client, so a subagent that connects displaces the controller and gets nothing) or **[code]** (plain file edits or shell a subagent can do).

**Revision (2026-09-28): clean-code pass, rebased on Textures 32bb618.**
- Added the **Clean code** block to Global Constraints; every snippet now obeys it (typed loop variables and Variant reads, `int(tokens.outline_width / 2.0)` like the rest of ThemeFactory instead of a float passed to an int, the `+ 0.2` shadow boost named `MINIGAME_CARD_SHADOW_ALPHA_BOOST`, `%Unique` + `@onready` node refs, a loud `push_error` on a missing node, guard clauses, no dead code).
- `_build_minigame_kit()` is now a table of contents over three one-job helpers plus small shared builders, so the pill/plank/icon-button rim box and the display-text block are written once. Every new type also gets `theme.add_type()`, like every existing helper. Built values are unchanged except for the decisions below.
- **Human decisions (2026-09-28), applied:**
  1. **The card rim and the answer-button shadow follow the spec.**
     - `MinigameCard`'s rim is cream (`outline_card`, spec §3 "cream rim"), where the original plan had `brand_primary_dark`.
     - `MinigameAnswerButton` casts the spec's hard `brandD` drop shadow (§4.1): `brand_primary_dark` at `shadow_offset`, with `MINIGAME_HARD_SHADOW_BLUR` (1, the least blur StyleBoxFlat still draws), where the original plan had no shadow.
     - The spec defines no focus or disabled state, so both are derived from tokens the way `_add_button_variation` derives its own:
       - **Pressed** sinks, with the shadow offset halved.
       - **Disabled** fades fill and rim toward `surface_sunken` by `_add_button_variation`'s amounts (0.7 and 0.5, named `MINIGAME_DISABLED_*_FADE`), drops the shadow and greys its text to `text_disabled`. The original plan's disabled state had the same fill as normal.
       - **Focus** is new. It is a rim-only gold (`currency_gold`) overlay: Godot draws focus over the current state, and the house focus rim, `brand_primary`, would vanish into this button's own fill.
     - `font_hover/pressed/focus_color` are `text_on_brand`, as in the house helper.
     - The tests pin all of it.
  2. **Score HUD restyle deferred.** The header wraps `MinigameScoreHUD` unchanged, and Task 6 records the debt.
  3. **The timer button is display-only in Part 1.** It has no signal, and Task 6 records the follow-on in DEBT.
  - Test counts move with these decisions: `minigame_kit` ends at 12 tests (Task 1: 3, Task 2: 6, Task 3: 3), and `minigame_header` at 7.
- **`test_run(suite=…)` takes the suite's `suite_name()`, not its file name.** The runner filters on `suite_name()` and rejects an unknown name with INVALID_PARAMS. The old plan's `suite="test_theme_factory"` would never have run, and its two new suites had no `suite_name()`, so both would have shared the name "unnamed". Every call is corrected, and the new suites return `"minigame_kit"` and `"minigame_header"`.
- **Rebake fixed:** an agent cannot use File > Run. Task 4 rebakes with `test_run(suite="theme_rebake")`, run alone, restarting the editor both before it (ThemeFactory does not hot-reload) and after it (a rebake followed by a `scene_save` writes stale theme props back).
- **Pins move with the factory, task by task** (CLAUDE.md: "change the roster and ThemeFactory together"). `DISPLAY_ROSTER` gains `MinigameAnswerButton` in Task 2 and `MinigameHudValue`/`MinigamePlankLabel` in Task 3. Before, it waited for Task 4, which left `display_font_roster_is_exact` red for two commits.
- **New conflict fixed:** `MinigameHudIconButton` uses `radius_pill`, which fails `tests/test_button_geometry.gd`'s one-fixed-radius rule. Task 3 adds a reasoned `RADIUS_EXEMPT` entry, the same one `CardArrowButton` has: a fixed square, so a pill radius draws an exact circle.
- **New conflict fixed:** Task 5 no longer forks the score pill. `Scenes/Minigames/UI/MinigameScoreHUD.tscn` already exists and seven minigames mount it. It has `set_score(value: int)`, which the plan's `set_score(text: String)` collided with, and the spec (§4.2) says "extend rather than fork". `MinigameHeader` now **instances** `MinigameScoreHUD` in its centre and forwards calls down to it. The `score_text` export is gone, and the header is TDD'd test-first.
- Tests use `suite_setup` fixtures (one theme build per suite, not one per assertion), explicit `DesignTokens` types (the cold-start `:=` inference trap), a `has_stylebox` assertion before each cast (the theme's fallback stylebox is never null), and no dead `if false` line.
- Added **Before you start** (work on `origin/feat/minigame-polish-part-1`, merge `origin/Textures` at 32bb618 or later into it) and **Task 6** (docs, DEBT, suite count, full run, `ship-pr`). Every code task's verification runs `test_run(suite="clean_code")`.
- The ambient-kit merge (83077f7 → 32bb618) touched none of ThemeFactory, DesignTokens, `test_theme_factory.gd`, the bake, `ci/` or the minigame folders. So the `expected` list, `DISPLAY_ROSTER` and the clean-code baseline are as the original plan found them. The only moves are the suite count, now 162 suites and 2455 tests, and two new autoloads (`LookLayer`, `RewardFeedback`) that this plan does not touch.

**Goal:** Build the shared minigame UI kit — the "Bingkai Kayu" card family, answer button, image plate, and HUD chrome — as `ThemeFactory` type variations, plus one reusable `MinigameHeader` scene. Every later minigame phase then has a real, tested vocabulary to consume.

**Architecture:** Add one `_build_minigame_kit()` table-of-contents helper to `ThemeFactory` that registers the new variations from existing `DesignTokens`. It adds no new tokens, so there is no Resource-restart hazard. Prove each variation with a dedicated `minigame_kit` suite that builds the theme in-process. Pin each variation in `test_theme_factory`/`test_button_geometry` in the same task that adds it. Rebake once, in Task 4. Finally, build a small `@tool` `MinigameHeader.tscn`/`.gd` strip: pause icon-button, the existing `MinigameScoreHUD` instance, and a timer icon-button.

**Tech Stack:** Godot 4.6 (GDScript), `ThemeFactory`/`DesignTokens` theme system, `McpTestSuite`/`McpTestSuiteCompat` suites run via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-28-minigame-polish-part-1-design.md` (read §3 Locked decisions and §4.1–4.2 before starting).

## Scope

This is **Plan 1 of a series.** It builds the *foundation only*: the theme
variations and the shared HUD scene. Applying the kit to actual minigames is
left to **follow-on plans**, which consume the variation names produced here:
the `PilihanGanda` quiz reference screen, the Tutorial/Pause/Quit overlays,
win/lose, Menjodohkan, the gameplay minigames, the motion pass, restyling
`MinigameScoreHUD` onto `MinigameHudPill`/`MinigameHudValue`, and swapping
`BaseMinigame`'s runtime-built pause button for `MinigameHeader`. The split is
deliberate. Those plans' "Consumes" interfaces are the exact variation
strings this plan finalizes in Task 4, and those strings do not exist until
this plan lands.

**This plan produces working, testable software on its own:** a baked theme that
declares the minigame kit, plus an instantiable `MinigameHeader` scene, both
covered by green suites. Nothing in the running game changes yet: no minigame
mounts the header.

## Global Constraints

From the spec / `CLAUDE.md` / `docs/superpowers/design/clean-code.md` — every task implicitly includes these:

- **No new `theme_override_*`.** Style only through `ThemeFactory` type variations. Only layout-only constant overrides (`separation`, `margin_*`) are allowed.
- **No `Balance.gd` edits.** Not touched in this plan.
- **No new persistence.**
- **Every script gets a `##` file-header and a `##` line on every `@export`** (`tests/test_script_documentation.gd`, header within the first 12 lines).
- **No runtime-built visuals** beyond the documented ratchet (`tests/test_viewport_editability.gd`). Static chrome = nodes in the `.tscn`.
- **Indonesian** UI text; **no emoji as iconography** — real transparent SVG textures only.
- **Sub-scene `@export`s go on the instance ROOT** (child overrides are dropped on save).
- **File names PascalCase** for `.gd`/`.tscn`; a `class_name X` script is named `X.gd`. **Conventional Commits with a scope** (e.g. `feat(minigame-kit): …`). Run `git branch --show-current` before every commit: another session can switch the shared checkout's branch.
- **Test suites** are `@tool`, define `suite_name()`, and contain no coroutine tests (no `await`). **`test_run(suite="<suite_name()>")`**: e.g. `theme_factory`, never `test_theme_factory`. Some suites want `Scenes/MainMenu/MainMenu.tscn` open (`scene_warning`); open it before trusting a failure.
- **Editing workflow:**
  - Edit `.tscn` only through the editor (`scene_open` → `node_*`/`batch_execute` → `scene_save`), never by hand while the editor is attached. Diff every scene after every save.
  - **Scene work first, script work second.** After any `scene_save`, check `git diff HEAD -- '*.gd'` for scripts you were not editing. Once you have patched a script, restart the editor before the next `scene_save`.
  - After a `.gd` is edited from outside the editor, a subagent's write included, do a **no-op `script_patch` on that file** before `test_run`, or the runner serves a stale copy.
  - **ThemeFactory does not hot-reload** (the patch reports `reloaded: false`, "error code 43"). When it does that, prove the file parses and then restart the editor before any `test_run` that builds the theme, and always before a rebake. Parse check:
    `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --check-only --script res://Scripts/Design/ThemeFactory.gd`
    It is valid because ThemeFactory names no autoload.
  - `ThemeFactory` and `MinigameHeader` carry `class_name`. Before a `project_run` after editing them, `project_manage(op="stop")`, `filesystem_manage(op="scan")`, then relaunch. Editor restarts are pre-authorized at task boundaries.
- **Rebake hazard.** Rebaking `kejartes_theme.tres` (`test_run(suite="theme_rebake")`) is issued **alone** — never in a batch with a `scene_open`/`scene_save`. **Restart the editor after a rebake and before any later `scene_save`**, or the editor writes stale style props, merged by sub-resource id, back into the bake. `git diff` the bake before committing. It should change only by the lines the new variations imply. For any other change, close the editor without saving, `git checkout --` the bake, restart, and rebake again.
- **Prefer targeted `test_run(suite="…")`** over full runs. A full run rebakes `kejartes_theme.tres`, rewrites `default_bus_layout.tres`, and drops the bridge, so budget one editor restart for it. Run `git status` after any full run and `git checkout --` whatever you did not intend.

### Clean code (`docs/superpowers/design/clean-code.md`; ⚙ = ratchet-enforced)

The ratchet is `ci/clean_code_scan.gd`, run by `test_run(suite="clean_code")`. Its baseline is `ci/clean_code_baseline.gd` and its permanent exceptions are `ci/clean_code_allowed.gd`. It measures `Scripts/` only. `tests/` is exempt from everything except the legacy-stat-key and misspelled-name rules, but this plan writes its tests to the same standard anyway.

- **Type everything ⚙.** Every `var` has `: Type` or an obvious `:=`. When the right-hand side is a Variant (a Dictionary read, `load()`, `instantiate()`), name the type: `var fill: Color = fills[state]`. Loop variables are typed (`for state: String in …`). Every function has typed parameters and a `->` return type. **ThemeFactory gets no exception here**: it has zero untyped entries today, so one untyped declaration fails the suite as "grew". Store `DesignTokens.load_default()` in an explicit `var tokens: DesignTokens`, because a cold-start `:=` inference once failed to load.
- **No magic numbers ⚙.**
  - Logic numbers get a named `const` block at the top of the script that owns them, with a `##` line.
  - Designer-tuned values get an `@export` with a `##` line.
  - Layout numbers (sizes, offsets, anchors) go in the `.tscn`.
  - `0`, `1`, `2`, `-1` and `0.5` are fine inline.
  - `ThemeFactory.gd` is on `ALLOWED.BARE_NUMBERS`, but it still names every single-screen value in a `##`-documented const directly above its section (`PICKER_*`, `SKIN_*`). Follow the file: the card's shadow boost becomes `MINIGAME_CARD_SHADOW_ALPHA_BOOST`.
  - **`MinigameHeader.gd` gets no exception.**
- **One job per function; ≤ 50 code lines ⚙.**
  - `ThemeFactory.gd` is on `ALLOWED.LONG_FUNCTIONS` and `ALLOWED.LARGE_SCRIPTS`, so its length is not measured. This plan splits the kit into one-job helpers anyway.
  - `ThemeFactory.gd` is **not** exempt from the untyped, duplicate-body, legacy-key, file-name or res://-path rules.
  - **New non-ThemeFactory scripts (`MinigameHeader.gd`) get no exception at all**, and start at zero debt. Engine callbacks read like a table of contents.
- **Flat, not nested.** Use guard clauses and early `return`; no if-pyramids.
- **No duplicated bodies ⚙.** No 5+-code-line function body may be identical across two files. Behaviour with visuals is one component scene, instanced: `MinigameHeader` instances `MinigameScoreHUD` instead of re-implementing it.
- **Signals up, calls down.** The header announces `pause_pressed`. Its owner calls `setup()`/`set_score()` down, and the header forwards them down to its child. It never reaches up with `get_parent()` or into another screen with `/root/…`.
- **`%UniqueName` node refs, taken once:** `@onready var _pause_button: Button = %PauseButton`, never a `$A/B/C` path.
- **Fail loudly.** A missing required node is a `push_error("MinigameHeader: …")`, not a silent skip. Leave no `print("DEBUG`.
- **No commented-out code.** Comments explain *why*.
- **Boy Scout rule.** A function you touch ends no longer and no less typed than you found it. This plan touches only `ThemeFactory.build()`, which gains one call line.
- **Keep the ratchet green.** Every code task ends with `test_run(suite="clean_code")`.
  - **"grew"**: fix the code; never raise the baseline.
  - **"shrank"**: lock it in, in the same commit, by running
    `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd`,
    check that `git diff ci/clean_code_baseline.gd` only lowers numbers or removes entries, then do a no-op `script_patch` of the baseline so the open editor serves it.
  - No task here is expected to shrink or grow anything. The only new production script is clean from its first commit.

---

## Before you start

- [ ] **[editor]** Close Godot **without saving** before touching the checkout (CLAUDE.md 4b). Kill only `Godot_v*.exe`, never another session's.
- [ ] **[code]** In one command, check that the shared checkout is idle: `git status --short; git reflog -1; git branch --show-current`. If another session is mid-work in the main checkout, do this in a worktree and verify with a second editor (see memory "Verify worktree code in a second editor").
- [ ] **[code]** Branch from the remote plan branch, never from the checkout's current branch:
  ```bash
  git fetch origin
  git switch feat/minigame-polish-part-1 2>/dev/null || git switch -c feat/minigame-polish-part-1 --track origin/feat/minigame-polish-part-1
  git merge --ff-only origin/feat/minigame-polish-part-1   # a local copy must match the remote plan branch
  git merge-base --is-ancestor 32bb618 origin/Textures && echo "Textures has the ambient kit"
  git merge origin/Textures   # brings 32bb618 or later into the branch
  ```
  The branch's base is 83077f7, and it holds only the spec and this plan. The merge is docs vs. code, so no conflict is expected; if `ci/clean_code_baseline.gd` or the bake ever conflicts, follow clean-code.md and the rebake memory rather than hand-merging. Then run `git log --oneline -1 origin/Textures` and check that the merge commit contains it.
- [ ] **[editor]** Relaunch the editor, open `Scenes/MainMenu/MainMenu.tscn`, and take a baseline: `test_run(suite="theme_factory")`, `test_run(suite="button_geometry")` and `test_run(suite="clean_code")`. All should be green before any change.

---

## File Structure

- `Scripts/Design/ThemeFactory.gd` — **modify.**
  - Add one call, `_build_minigame_kit(theme, tokens)`, inside `build()`.
  - Add a `# --- minigame kit` section directly after `_build_minigame_typography()`, before the `# --- progress` banner. It holds `_build_minigame_kit()` (table of contents), `_build_minigame_card_family()`, `_build_minigame_answer_button()` and `_build_minigame_hud()`, plus the shared builders `_add_minigame_panel()`, `_add_minigame_gold_label()`, `_set_minigame_display_text()`, `_minigame_answer_box()`, `_minigame_rim_box()` and `_minigame_tab_box()`.
- `tests/test_minigame_kit.gd` — **create.** Suite `minigame_kit`. It is build-based: it calls `ThemeFactory.build(...)` once in `suite_setup`, with no dependency on the baked file.
- `tests/test_theme_factory.gd` — **modify.**
  - `DISPLAY_ROSTER` gains `MinigameAnswerButton` (Task 2), and `MinigameHudValue` and `MinigamePlankLabel` (Task 3).
  - The `expected` list in `test_every_declared_variation_exists` gains all nine names (Task 4).
- `tests/test_button_geometry.gd` — **modify (Task 3).** A reasoned `RADIUS_EXEMPT` entry for `MinigameHudIconButton`.
- `Assets/Theme/kejartes_theme.tres` — **regenerate (Task 4)** via `test_run(suite="theme_rebake")`; committed.
- `Scripts/Minigames/UI/MinigameHeader.gd` — **create.** `@tool`, `class_name MinigameHeader`.
- `Scenes/Minigames/UI/MinigameHeader.tscn` — **create** (editor only). Pause button, an **instance of the existing `MinigameScoreHUD.tscn`**, and a timer button.
- `tests/test_minigame_header.gd` — **create.** Suite `minigame_header`.
- `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`, `CLAUDE.md` (suite count only) — **modify (Task 6).**

**Existing things this plan reuses rather than duplicates** (checked against Textures 32bb618):
- `MinigameScoreHUD` (scene plus script: score pop, burst, combo chip, `setup`/`set_score`/`set_combo`/`set_label_text`) is the header's centre.
- `ScoreHudPanel`/`ScoreHudValueLabel` stay as they are. Restyling the shared HUD onto the kit is a follow-on (see Scope).
- `MinigameChoiceButton` (PilihanGanda's cream answer buttons, via `_add_button_variation`) stays as it is. `MinigameAnswerButton` is the new brand-filled look that the reference-screen plan will swap in.
- None of the nine new variation names exists yet.

**Variation names produced by this plan** (the interface later plans consume):
`MinigameCard`, `MinigameCardInner`, `MinigameImagePlate`, `MinigameAnswerButton`,
`MinigameHudPill`, `MinigameHudValue`, `MinigameHudIconButton`, `MinigamePlankPanel`,
`MinigamePlankLabel`.

---

### Task 1: Card family variations (MinigameCard / MinigameCardInner / MinigameImagePlate)

The Bingkai Kayu card is a wooden frame (`MinigameCard`, brand-filled) wrapping a cream inner (`MinigameCardInner`), with an optional recessed image plate (`MinigameImagePlate`). All three reuse existing tokens.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add the kit section, call it in `build()`)
- Test: `tests/test_minigame_kit.gd` (create)

**Interfaces:**
- Consumes: `DesignTokens` fields `brand_primary`, `outline_card`, `surface_card`, `preview_pill_fill`, `preview_pill_shadow_color`/`_size`/`_offset`, `outline_width` (a **float**, 6.0), `radius_lg`, `radius_md`, `shadow_color`, `shadow_size`, `shadow_offset`, `space_xs`, `space_md`.
- Produces: theme type variations `MinigameCard` (Panel), `MinigameCardInner` (Panel), `MinigameImagePlate` (Panel).

- [ ] **Step 1: Write the failing test** — **[code]**

Create `tests/test_minigame_kit.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## Proves the shared minigame UI kit variations ThemeFactory._build_minigame_kit()
## registers (spec 2026-09-28 minigame-polish-part-1, section 4.1).
## Build-based: the theme is constructed in process once per run, so this never
## depends on the baked kejartes_theme.tres (test_theme_factory pins the bake).
## Affects nothing at runtime. Must be @tool, and no test here may be a coroutine.

var _tokens: DesignTokens
var _theme: Theme


func suite_name() -> String:
	return "minigame_kit"


## One theme build for the whole suite.
func suite_setup(_ctx: Dictionary) -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


## `variation`'s `item` stylebox as a StyleBoxFlat, or null. Asserting
## has_stylebox first matters: Theme.get_stylebox() returns the engine's
## fallback box, never null, for a type that does not exist.
func _flat(item: String, variation: String) -> StyleBoxFlat:
	assert_true(_theme.has_stylebox(item, variation),
		"%s must define stylebox: %s" % [variation, item])
	return _theme.get_stylebox(item, variation) as StyleBoxFlat


func test_minigame_card_is_a_wood_frame() -> void:
	var frame: StyleBoxFlat = _flat("panel", "MinigameCard")
	if frame == null:
		return
	assert_true(frame.bg_color.is_equal_approx(_tokens.brand_primary),
		"frame is filled with the brand wood colour")
	assert_gt(frame.border_width_top, 0, "the frame has a visible rim")
	assert_true(frame.border_color.is_equal_approx(_tokens.outline_card),
		"the rim is cream, so the card pops on the bright wood (spec section 3)")
	assert_gt(frame.shadow_size, 0, "the card is lifted off the wood by a shadow")


func test_minigame_card_inner_is_cream() -> void:
	var inner: StyleBoxFlat = _flat("panel", "MinigameCardInner")
	if inner == null:
		return
	assert_true(inner.bg_color.is_equal_approx(_tokens.surface_card),
		"inner face is the cream card colour")


func test_minigame_image_plate_is_a_recessed_slot() -> void:
	var plate: StyleBoxFlat = _flat("panel", "MinigameImagePlate")
	if plate == null:
		return
	assert_true(plate.bg_color.is_equal_approx(_tokens.preview_pill_fill),
		"plate uses the recessed slot colour")
```

- [ ] **Step 2: Run the test to verify it fails** — **[editor]**

`filesystem_manage(op="scan")` so the new suite is discovered. Then run `test_run(suite="minigame_kit")`.
Expected: FAIL (3 tests). The `has_stylebox` assertions fail for `MinigameCard`, `MinigameCardInner` and `MinigameImagePlate`. If the reply is INVALID_PARAMS "No suite named 'minigame_kit'", discovery missed the file: do a no-op `script_patch` on it and re-run.

- [ ] **Step 3: Add the kit section and register it** — **[code]**

In `Scripts/Design/ThemeFactory.gd`, `build()`, add the call after `_build_school_day_liveliness(theme, tokens)` and before `_build_base_overrides(theme, tokens)`:

```gdscript
	_build_minigame_kit(theme, tokens)
```

Then insert this section directly after `_build_minigame_typography()` ends, before the `# ----…---- progress` banner:

```gdscript
# ------------------------------------------------------------ minigame kit

## The shared minigame UI kit, "Bingkai Kayu" (2026-09-28, spec
## docs/superpowers/specs/2026-09-28-minigame-polish-part-1-design.md, 4.1).
## All from existing tokens -- no new tokens, so no Resource-restart hazard.
##   MinigameCard           the wooden frame: brand fill, cream rim, lifted.
##   MinigameCardInner      the cream face inside the frame.
##   MinigameImagePlate     the recessed slot a picture question sits in.
## Tasks 2 and 3 of the plan extend this list.

## How far the card's shadow alpha is raised over shadow_color's, so the
## frame still pops on the bright light-orange wood backdrop.
const MINIGAME_CARD_SHADOW_ALPHA_BOOST := 0.2


static func _build_minigame_kit(theme: Theme, tokens: DesignTokens) -> void:
	_build_minigame_card_family(theme, tokens)


## MinigameCard, MinigameCardInner and MinigameImagePlate.
static func _build_minigame_card_family(theme: Theme, tokens: DesignTokens) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = tokens.brand_primary
	frame.set_border_width_all(int(tokens.outline_width))
	frame.border_color = tokens.outline_card
	frame.set_corner_radius_all(tokens.radius_lg)
	frame.set_content_margin_all(tokens.space_xs)
	var lifted: Color = tokens.shadow_color
	lifted.a = minf(1.0, tokens.shadow_color.a + MINIGAME_CARD_SHADOW_ALPHA_BOOST)
	frame.shadow_color = lifted
	frame.shadow_size = tokens.shadow_size
	frame.shadow_offset = tokens.shadow_offset
	_add_minigame_panel(theme, "MinigameCard", frame)

	var inner := StyleBoxFlat.new()
	inner.bg_color = tokens.surface_card
	inner.set_corner_radius_all(tokens.radius_md)
	inner.set_content_margin_all(tokens.space_md)
	_add_minigame_panel(theme, "MinigameCardInner", inner)

	var plate := StyleBoxFlat.new()
	plate.bg_color = tokens.preview_pill_fill
	plate.set_corner_radius_all(tokens.radius_md)
	plate.shadow_color = tokens.preview_pill_shadow_color
	plate.shadow_size = tokens.preview_pill_shadow_size
	plate.shadow_offset = tokens.preview_pill_shadow_offset
	_add_minigame_panel(theme, "MinigameImagePlate", plate)


## Register `name` as a Panel variation drawn by `box`. Base "Panel", like
## every panel variation here, even where the node is a PanelContainer.
static func _add_minigame_panel(theme: Theme, name: String, box: StyleBox) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Panel")
	theme.set_stylebox("panel", name, box)
```

Value check against the original plan:
- Rim: `int(6.0)` = 6, now in cream `outline_card` per the spec (decision 1; it was `brand_primary_dark`).
- `set_content_margin_all(space_xs)` is the four `content_margin_*` = `space_xs` lines.
- Shadow alpha: `min(1, 0.30 + 0.2)` = 0.5.

- [ ] **Step 4: Reload and run the tests to verify they pass** — **[editor]**

1. Do a no-op `script_patch` on `Scripts/Design/ThemeFactory.gd`. If it reports `reloaded: false`, run the `--check-only` command from Global Constraints (exit 0 expected), then restart the editor.
2. Run `test_run(suite="minigame_kit")`. Expected: PASS (3 tests).
3. Run `test_run(suite="button_geometry")` → PASS, then `test_run(suite="clean_code")` → PASS, with no "grew" and no "shrank".

Do **not** expect `theme_factory` to be fully green yet. `test_baked_theme_matches_what_the_factory_builds` fails until the Task 4 rebake.

- [ ] **Step 5: Commit** — **[code]**

```bash
git branch --show-current   # must print feat/minigame-polish-part-1
git add Scripts/Design/ThemeFactory.gd tests/test_minigame_kit.gd tests/test_minigame_kit.gd.uid
git commit -m "feat(minigame-kit): Bingkai Kayu card, inner and image-plate variations"
```

(Add the `.uid` only if the editor generated one. Check `git status --short` first.)

---

### Task 2: Answer button variation (MinigameAnswerButton)

A solid brand-filled answer button, per spec §4.1:
- a light-lit rim at rest, with a full-width top edge;
- the spec's **hard `brandD` drop shadow**;
- padding at the small button step.

The spec names only `hover` and `pressed`. `focus` and `disabled` are derived from tokens the way `_add_button_variation` does it (decision 1 in the revision note):
- pressed sinks, with the shadow halved;
- disabled fades toward `surface_sunken`, drops the shadow and greys its text;
- focus is a rim-only gold overlay.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (extend the kit)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`, same task as the font it pins)
- Test: `tests/test_minigame_kit.gd` (add tests)

**Interfaces:**
- Consumes: `DesignTokens` `brand_primary`, `brand_primary_light`, `brand_primary_dark`, `surface_sunken`, `currency_gold`, `text_on_brand`, `text_disabled`, `radius_button`, `outline_width`, `shadow_offset`, `btn_pad_v_s`, `space_lg`, `font_display`, `font_title`.
- Produces: `MinigameAnswerButton` (Button) with `normal`/`hover`/`pressed`/`disabled`/`focus` styleboxes at `radius_button`, so `test_button_geometry`'s fixed-radius rule holds with no exemption. Also a hard `brand_primary_dark` shadow, per-state font colours, the display font, and `font_title` size.

- [ ] **Step 1: Write the failing test** — **[code]**

Append to `tests/test_minigame_kit.gd`. Put the consts directly under the `var _theme` line, and the tests at the end of the file:

```gdscript
## The answer button's five styleboxes: the spec's four plus a derived focus.
const ANSWER_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
## Slack, px, for padding built from int tokens.
const PAD_TOLERANCE := 1.0
```

```gdscript
func test_answer_button_has_all_five_states() -> void:
	for state: String in ANSWER_STATES:
		assert_true(_theme.has_stylebox(state, "MinigameAnswerButton"),
			"MinigameAnswerButton must define stylebox: " + state)


func test_answer_button_is_brand_filled_and_touch_sized() -> void:
	var resting: StyleBoxFlat = _flat("normal", "MinigameAnswerButton")
	if resting == null:
		return
	assert_true(resting.bg_color.is_equal_approx(_tokens.brand_primary),
		"filled with the brand colour")
	assert_gt(resting.border_width_top, 0, "has the light-lit top edge as a border")
	var pad_v: float = resting.content_margin_top + resting.content_margin_bottom
	assert_true(pad_v >= float(_tokens.btn_pad_v_s) * 2.0 - PAD_TOLERANCE,
		"vertical padding matches the small button step")


func test_answer_button_uses_the_display_font() -> void:
	if _tokens.font_display == null:
		return
	assert_eq(_theme.get_font("font", "MinigameAnswerButton"), _tokens.font_display,
		"answer text is set in the display face")


## Spec 4.1: a hard brandD drop shadow, which sinks while pressed.
func test_answer_button_casts_a_hard_brand_dark_shadow() -> void:
	var resting: StyleBoxFlat = _flat("normal", "MinigameAnswerButton")
	var pressed: StyleBoxFlat = _flat("pressed", "MinigameAnswerButton")
	if resting == null or pressed == null:
		return
	assert_true(resting.shadow_color.is_equal_approx(_tokens.brand_primary_dark),
		"the shadow is the dark brand tone")
	assert_eq(resting.shadow_size, ThemeFactory.MINIGAME_HARD_SHADOW_BLUR,
		"a hard edge: the least blur StyleBoxFlat still draws")
	assert_eq(resting.shadow_offset, _tokens.shadow_offset, "dropped by the house offset")
	assert_true(pressed.shadow_offset.y < resting.shadow_offset.y, "pressing sinks the button")


## Not in the spec; derived like _add_button_variation's disabled state.
func test_answer_button_disabled_state_reads_as_disabled() -> void:
	var resting: StyleBoxFlat = _flat("normal", "MinigameAnswerButton")
	var disabled: StyleBoxFlat = _flat("disabled", "MinigameAnswerButton")
	if resting == null or disabled == null:
		return
	assert_false(disabled.bg_color.is_equal_approx(resting.bg_color),
		"a disabled answer is visibly different from a live one")
	assert_eq(disabled.shadow_size, 0, "a disabled button lies flat")
	var disabled_text: Color = _theme.get_color("font_disabled_color", "MinigameAnswerButton")
	assert_true(disabled_text.is_equal_approx(_tokens.text_disabled), "and its text greys out")


## Godot draws focus OVER the current state, so it must be a rim, not a fill.
func test_answer_button_focus_is_a_gold_rim_overlay() -> void:
	var focus: StyleBoxFlat = _flat("focus", "MinigameAnswerButton")
	if focus == null:
		return
	assert_false(focus.draw_center, "focus draws no fill over the state beneath it")
	assert_true(focus.border_color.is_equal_approx(_tokens.currency_gold),
		"a gold rim reads on the brand wood fill")
```

- [ ] **Step 2: Run the test to verify it fails** — **[editor]**

Do a no-op `script_patch` on `tests/test_minigame_kit.gd`, then run `test_run(suite="minigame_kit")`. Expected: FAIL. The six new tests fail and the three Task 1 tests pass. The `ThemeFactory.MINIGAME_HARD_SHADOW_BLUR` reference may instead fail to resolve, which reports the suite as broken; that counts as the same red.

- [ ] **Step 3: Extend the kit** — **[code]**

In `Scripts/Design/ThemeFactory.gd`:

1. Add one line to the kit's `##` table, under `MinigameImagePlate`:
```gdscript
##   MinigameAnswerButton   solid brand answer button: light rim at rest, a
##                          hard brand-dark drop shadow, gold focus rim.
```

2. Make `_build_minigame_kit()` read:
```gdscript
static func _build_minigame_kit(theme: Theme, tokens: DesignTokens) -> void:
	_build_minigame_card_family(theme, tokens)
	_build_minigame_answer_button(theme, tokens)
```

3. Under `MINIGAME_CARD_SHADOW_ALPHA_BOOST`, add:
```gdscript
## The answer button's hard drop shadow (spec 4.1, "brandD hard shadow"):
## StyleBoxFlat draws no shadow at a blur of 0, so this is the least blur
## that still draws -- a crisp edge under the full shadow_offset drop.
const MINIGAME_HARD_SHADOW_BLUR := 1
## How far a disabled answer button fades toward surface_sunken: its fill,
## then its rim. The amounts _add_button_variation uses for every house
## button, so a disabled answer reads like any other disabled button.
const MINIGAME_DISABLED_FILL_FADE := 0.7
const MINIGAME_DISABLED_RIM_FADE := 0.5
```

4. After `_build_minigame_card_family()`, add:
```gdscript
## MinigameAnswerButton. The spec defines rest, hover and pressed; focus and
## disabled are derived from tokens the way _add_button_variation derives its
## own. Only the resting state rims in the light brand tone, the "gold-lit"
## edge; hover and pressed rim dark.
static func _build_minigame_answer_button(theme: Theme, tokens: DesignTokens) -> void:
	var name := "MinigameAnswerButton"
	theme.add_type(name)
	theme.set_type_variation(name, "Button")
	var drop: Vector2 = tokens.shadow_offset
	theme.set_stylebox("normal", name,
		_minigame_answer_box(tokens, tokens.brand_primary, tokens.brand_primary_light, drop))
	theme.set_stylebox("hover", name,
		_minigame_answer_box(tokens, tokens.brand_primary_light, tokens.brand_primary_dark, drop))
	# Pressed sinks: the shadow halves, as in _add_button_variation.
	theme.set_stylebox("pressed", name,
		_minigame_answer_box(tokens, tokens.brand_primary_dark, tokens.brand_primary_dark, drop * 0.5))
	theme.set_stylebox("disabled", name, _minigame_answer_disabled_box(tokens))
	theme.set_stylebox("focus", name, _minigame_answer_focus_box(tokens))
	_set_minigame_display_text(theme, tokens, name, tokens.text_on_brand, tokens.font_title)
	for key: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(key, name, tokens.text_on_brand)
	theme.set_color("font_disabled_color", name, tokens.text_disabled)


## One answer-button state: `fill`, the house button radius, a half-width
## rim in `rim` with a full-width top edge, the small step's padding, and
## the hard brand-dark shadow dropped by `drop`.
static func _minigame_answer_box(tokens: DesignTokens, fill: Color, rim: Color,
		drop: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(tokens.radius_button)
	box.set_border_width_all(int(tokens.outline_width / 2.0))
	box.border_width_top = int(tokens.outline_width)
	box.border_color = rim
	box.content_margin_top = tokens.btn_pad_v_s
	box.content_margin_bottom = tokens.btn_pad_v_s
	box.content_margin_left = tokens.space_lg
	box.content_margin_right = tokens.space_lg
	box.shadow_color = tokens.brand_primary_dark
	box.shadow_size = MINIGAME_HARD_SHADOW_BLUR
	box.shadow_offset = drop
	return box


## Disabled: the resting box faded toward surface_sunken, lying flat.
static func _minigame_answer_disabled_box(tokens: DesignTokens) -> StyleBoxFlat:
	var box := _minigame_answer_box(tokens,
		tokens.brand_primary.lerp(tokens.surface_sunken, MINIGAME_DISABLED_FILL_FADE),
		tokens.brand_primary_dark.lerp(tokens.surface_sunken, MINIGAME_DISABLED_RIM_FADE),
		tokens.shadow_offset)
	box.shadow_size = 0
	return box


## Focus: Godot draws it OVER the current state, so it is a rim with no fill
## and no shadow. Gold, because the house focus rim (brand_primary) is this
## button's own fill and would vanish.
static func _minigame_answer_focus_box(tokens: DesignTokens) -> StyleBoxFlat:
	var box := _minigame_answer_box(tokens, tokens.brand_primary, tokens.currency_gold,
		tokens.shadow_offset)
	box.draw_center = false
	box.shadow_size = 0
	return box


## Colour, size and -- when the slot is filled -- the display face for a
## text-bearing kit variation. Every caller must be on DISPLAY_ROSTER.
static func _set_minigame_display_text(theme: Theme, tokens: DesignTokens, name: String,
		color: Color, font_size: int) -> void:
	theme.set_color("font_color", name, color)
	theme.set_font_size("font_size", name, font_size)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)
```

Value check against the original plan's loop:
- **Unchanged:**
  - Fills: `normal` = `brand_primary`, `hover` = `_light`, `pressed` = `_dark`.
  - Rim: `_light` on `normal`, `_dark` on `hover`/`pressed`.
  - Border widths: 3 on each side and 6 on top.
  - Padding, radius and font.
- **Changed by decision 1:**
  - Every state now casts the hard `brand_primary_dark` shadow: blur 1 at `shadow_offset` (0, 6), halved to (0, 3) when pressed, none when disabled or focused.
  - `disabled` was identical to `normal`'s fill. It is now `brand_primary` lerped 0.7 toward `surface_sunken`, with its rim lerped 0.5, and its text is `text_disabled`.
  - `focus` is new: a gold rim-only overlay.
  - `font_hover/pressed/focus_color` = `text_on_brand`.
- **ThemeFactory exceptions:**
  - `drop * 0.5` uses the trivial 0.5, and ThemeFactory is on `ALLOWED.BARE_NUMBERS` anyway.
  - The new values are still named consts, in the file's style.
  - `_build_minigame_answer_button` is about 20 code lines, and every helper is under 20.

- [ ] **Step 4: Pin the display font** — **[code]**

In `tests/test_theme_factory.gd`, `DISPLAY_ROSTER`, append after the `"TrayBadgeLabel",` line:

```gdscript
	# 2026-09-28 minigame kit (Minigame Polish Part 1): the answer button.
	# Task 3 adds the HUD value and the plank label under this comment.
	"MinigameAnswerButton",
```

- [ ] **Step 5: Reload and run the tests to verify they pass** — **[editor]**

1. Do a no-op `script_patch` on `ThemeFactory.gd` (if it reports `reloaded: false`: `--check-only`, then restart), on `tests/test_minigame_kit.gd` and on `tests/test_theme_factory.gd`.
2. Run `test_run(suite="minigame_kit")` → PASS (9 tests).
3. Run `test_run(suite="theme_factory")`. `test_display_font_roster_is_exact` should pass. The only expected failure is `test_baked_theme_matches_what_the_factory_builds` (stale bake, Task 4).
4. Run `test_run(suite="button_geometry")` → PASS, then `test_run(suite="clean_code")` → PASS.

- [ ] **Step 6: Commit** — **[code]**

```bash
git branch --show-current
git add Scripts/Design/ThemeFactory.gd tests/test_minigame_kit.gd tests/test_theme_factory.gd
git commit -m "feat(minigame-kit): brand-filled answer button with hard shadow, focus and disabled states"
```

---

### Task 3: HUD + plank variations

The shared HUD chrome:
- a score pill (`MinigameHudPill` panel plus `MinigameHudValue` gold label);
- round icon buttons (`MinigameHudIconButton`);
- the carved plank tab (`MinigamePlankPanel` plus `MinigamePlankLabel`).

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (extend the kit)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`)
- Modify: `tests/test_button_geometry.gd` (`RADIUS_EXEMPT`, **new vs. the original plan**)
- Test: `tests/test_minigame_kit.gd` (add tests)

**Interfaces:**
- Consumes: `DesignTokens` `brand_primary`, `brand_primary_dark`, `outline_card`, `outline_width`, `radius_pill`, `radius_md`, `currency_gold`, `space_md`, `space_xs`, `font_display`, `font_title`, `font_caption`. The scene uses `touch_target_min` (96) for the icon buttons' size.
- Produces: `MinigameHudPill` (Panel), `MinigameHudValue` (Label), `MinigameHudIconButton` (Button, 4 states, no font), `MinigamePlankPanel` (Panel), `MinigamePlankLabel` (Label).

- [ ] **Step 1: Write the failing test** — **[code]**

Append to `tests/test_minigame_kit.gd`. Put the const next to `ANSWER_STATES`, and the tests at the end of the file:

```gdscript
## The icon button's four styleboxes.
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]
```

```gdscript
func test_hud_pill_and_value() -> void:
	var pill: StyleBoxFlat = _flat("panel", "MinigameHudPill")
	if pill != null:
		assert_true(pill.bg_color.is_equal_approx(_tokens.brand_primary_dark), "pill is dark brand")
	assert_true(_theme.get_color("font_color", "MinigameHudValue").is_equal_approx(_tokens.currency_gold),
		"score value is gold")


## The icon buttons' size is authored on the node (touch_target_min square in
## MinigameHeader.tscn); the theme's job is the four states and the round shape.
func test_hud_icon_button_has_all_states_and_is_round() -> void:
	for state: String in BUTTON_STATES:
		assert_true(_theme.has_stylebox(state, "MinigameHudIconButton"),
			"MinigameHudIconButton must define stylebox: " + state)
	var resting: StyleBoxFlat = _flat("normal", "MinigameHudIconButton")
	assert_true(resting != null and resting.corner_radius_top_left >= _tokens.radius_md,
		"icon button is round")


func test_plank_panel_and_label() -> void:
	var plank: StyleBoxFlat = _flat("panel", "MinigamePlankPanel")
	assert_true(plank != null and plank.bg_color.is_equal_approx(_tokens.brand_primary_dark),
		"plank panel is dark brand")
	assert_true(_theme.get_color("font_color", "MinigamePlankLabel").is_equal_approx(_tokens.currency_gold),
		"plank label text is gold")
```

(The original plan's `var mn: Vector2 = … if false else Vector2.ZERO` line is dropped. It was dead code, an unused variable and an int/Vector2 ternary.)

- [ ] **Step 2: Run the test to verify it fails** — **[editor]**

Do a no-op `script_patch` on the test file, then run `test_run(suite="minigame_kit")`. Expected: FAIL. The three new tests fail and the nine earlier tests pass.

- [ ] **Step 3: Extend the kit** — **[code]**

In `Scripts/Design/ThemeFactory.gd`:

1. Add to the kit's `##` table:
```gdscript
##   MinigameHudPill        the dark score pill with a cream rim,
##   MinigameHudValue       and its gold display-face number.
##   MinigameHudIconButton  the round pause/timer chrome. A fixed square in
##                          MinigameHeader.tscn, so radius_pill is a circle.
##   MinigamePlankPanel     the carved plank tab (SOAL / JAWABAN / titles)
##   MinigamePlankLabel     and its gold display-face text.
```

2. Make `_build_minigame_kit()` read:
```gdscript
static func _build_minigame_kit(theme: Theme, tokens: DesignTokens) -> void:
	_build_minigame_card_family(theme, tokens)
	_build_minigame_answer_button(theme, tokens)
	_build_minigame_hud(theme, tokens)
```

3. Under the Task 2 consts, add:
```gdscript
## The Button states the HUD icon button styles.
const MINIGAME_BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]
```

4. After `_set_minigame_display_text()`, add:
```gdscript
## MinigameHudPill + MinigameHudValue, MinigamePlankPanel + MinigamePlankLabel,
## and MinigameHudIconButton. The pill and the plank are one box that differs
## only in its corners.
static func _build_minigame_hud(theme: Theme, tokens: DesignTokens) -> void:
	_add_minigame_panel(theme, "MinigameHudPill", _minigame_tab_box(tokens, tokens.radius_pill))
	_add_minigame_gold_label(theme, tokens, "MinigameHudValue", tokens.font_title)
	_add_minigame_panel(theme, "MinigamePlankPanel", _minigame_tab_box(tokens, tokens.radius_md))
	_add_minigame_gold_label(theme, tokens, "MinigamePlankLabel", tokens.font_caption)

	# An icon, never text, so no font: it stays off DISPLAY_ROSTER.
	var icon_button := "MinigameHudIconButton"
	theme.add_type(icon_button)
	theme.set_type_variation(icon_button, "Button")
	for state: String in MINIGAME_BUTTON_STATES:
		var fill: Color = tokens.brand_primary if state == "pressed" else tokens.brand_primary_dark
		theme.set_stylebox(state, icon_button, _minigame_rim_box(tokens, fill, tokens.radius_pill))


## A gold display-face Label variation at `font_size`.
static func _add_minigame_gold_label(theme: Theme, tokens: DesignTokens, name: String,
		font_size: int) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Label")
	_set_minigame_display_text(theme, tokens, name, tokens.currency_gold, font_size)


## A dark brand tab with a cream rim and the pill's padding, at `radius`.
static func _minigame_tab_box(tokens: DesignTokens, radius: int) -> StyleBoxFlat:
	var box := _minigame_rim_box(tokens, tokens.brand_primary_dark, radius)
	box.content_margin_left = tokens.space_md
	box.content_margin_right = tokens.space_md
	box.content_margin_top = tokens.space_xs
	box.content_margin_bottom = tokens.space_xs
	return box


## A flat `fill` box with `radius` corners and a half-width outline_card rim.
static func _minigame_rim_box(tokens: DesignTokens, fill: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(int(tokens.outline_width / 2.0))
	box.border_color = tokens.outline_card
	return box
```

Value check against the original plan:
- Pill: `brand_primary_dark`, `radius_pill`, a 3 px `outline_card` rim, and `md`/`xs` margins.
- Plank: the same, at `radius_md`.
- Icon button: `brand_primary_dark` (`brand_primary` when pressed), `radius_pill`, a 3 px `outline_card` rim, and no margins.
- Labels: gold, the display face, at `font_title` and `font_caption`.

- [ ] **Step 4: Move the pins with the factory** — **[code]**

1. In `tests/test_theme_factory.gd`, `DISPLAY_ROSTER`, extend the Task 2 block:
```gdscript
	# 2026-09-28 minigame kit (Minigame Polish Part 1): the answer button,
	# the HUD score value and the plank label. The kit's panels and its icon
	# button carry no font.
	"MinigameAnswerButton", "MinigameHudValue", "MinigamePlankLabel",
```
Replace the Task 2 comment and single-name line with this. It is a "these and only these" roster, and the panels and `MinigameHudIconButton` must stay off it.

2. In `tests/test_button_geometry.gd`, `RADIUS_EXEMPT`, add after `"CardArrowButton"`:
```gdscript
	"MinigameHudIconButton":
		"fixed touch_target_min square in MinigameHeader.tscn, so radius_pill yields an exact circle -- no height-dependent-radius risk, like CardArrowButton",
```
Without it, `test_every_button_variation_uses_one_fixed_radius` fails: 999 ≠ `radius_button`.

- [ ] **Step 5: Reload and run the tests to verify they pass** — **[editor]**

1. Do a no-op `script_patch` on `ThemeFactory.gd` (if it reports `reloaded: false`: `--check-only`, then restart) and on the three test files.
2. Run `test_run(suite="minigame_kit")` → PASS (12 tests).
3. Run `test_run(suite="button_geometry")` → PASS, including `test_exempt_variations_still_exist`.
4. Run `test_run(suite="theme_factory")`. The only expected failure is `test_baked_theme_matches_what_the_factory_builds`.
5. Run `test_run(suite="clean_code")` → PASS.

- [ ] **Step 6: Commit** — **[code]**

```bash
git branch --show-current
git add Scripts/Design/ThemeFactory.gd tests/test_minigame_kit.gd tests/test_theme_factory.gd tests/test_button_geometry.gd
git commit -m "feat(minigame-kit): HUD pill, icon button and plank variations"
```

---

### Task 4: Pin the declared variations and rebake the theme

Pin the nine names in the declared-variation list, rebake the baked theme, and confirm the whole theme suite is green.

**Files:**
- Modify: `tests/test_theme_factory.gd` (the `expected` list only; `DISPLAY_ROSTER` already moved in Tasks 2 and 3)
- Regenerate + commit: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Consumes: the nine variations from Tasks 1–3.
- Produces: a baked theme that declares them, and a fully green `theme_factory` suite.

- [ ] **Step 1: Extend the declared-variation list** — **[code]**

In `tests/test_theme_factory.gd`, `test_every_declared_variation_exists`, append to the `expected` array, after the `"EventDialoguePanel", …, "CalendarLabel",` line. The list is unchanged by the ambient-kit merge.

```gdscript
		"MinigameCard", "MinigameCardInner", "MinigameImagePlate",
		"MinigameAnswerButton", "MinigameHudPill", "MinigameHudValue",
		"MinigameHudIconButton", "MinigamePlankPanel", "MinigamePlankLabel",
```

- [ ] **Step 2: Run the theme factory suite** — **[editor]**

Do a no-op `script_patch` on `tests/test_theme_factory.gd`, then run `test_run(suite="theme_factory")`.
Expected: `test_every_declared_variation_exists` and `test_display_font_roster_is_exact` PASS. `test_baked_theme_matches_what_the_factory_builds` **FAILS**, listing the nine types. The bake is stale; the next steps fix it.

- [ ] **Step 3: Restart the editor** — **[editor]**

ThemeFactory was patched in Tasks 1–3 and does not hot-reload, and a rebake runs whatever factory bytecode the editor holds. Close Godot (nothing unsaved should be open), relaunch, and open `Scenes/MainMenu/MainMenu.tscn`.

- [ ] **Step 4: Rebake — alone** — **[editor]**

Run `test_run(suite="theme_rebake")` as its own call. Do not batch it with any scene operation. It does `ThemeFactory.build()` plus `ResourceSaver.save()` to `Assets/Theme/kejartes_theme.tres`, the same work as `BakeTheme.gd`'s File > Run, which an agent cannot trigger.

- [ ] **Step 5: Diff the bake** — **[code]**

`git diff --stat Assets/Theme/kejartes_theme.tres`, then read the diff.
- **Expected:** additions for the nine types, meaning their StyleBoxFlat sub-resources, variation entries and colour, font and size lines.
- **If existing styleboxes changed values** (for example a `content_margin_*` moving on an unrelated type): the editor merged stale props. Close it without saving, `git checkout -- Assets/Theme/kejartes_theme.tres`, relaunch, and repeat Steps 4–5.
- Id renumbering alone is possible, but on a purely additive change treat it as a warning sign and read the diff closely.

- [ ] **Step 6: Run the theme suites again to verify they fully pass** — **[editor]**

1. Run `test_run(suite="theme_factory")` → all PASS, including `test_baked_theme_matches_what_the_factory_builds`.
2. Run `test_run(suite="button_geometry")` and `test_run(suite="minigame_kit")` → PASS.
3. Run `test_run(suite="clean_code")` → PASS.

- [ ] **Step 7: Restart the editor before any scene work** — **[editor]**

A rebake followed by a `scene_save` writes the cached theme's stale props back into the bake. Close Godot and relaunch before Task 5, even though no scene was touched in this task.

- [ ] **Step 8: Commit** — **[code]**

```bash
git branch --show-current
git status --short   # expect only the two files below
git add tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(minigame-kit): pin new variations and rebake the baked theme"
```

---

### Task 5: Shared MinigameHeader scene

A reusable HUD strip that every minigame will instance:
- the pause icon-button (left);
- the **existing shared score readout** `MinigameScoreHUD` (centre), instanced rather than forked, so the pop, burst, combo chip and its tests stay in one place;
- the timer icon-button (right). It is **display-only in Part 1** (decision 3): it has no signal and no handler, and only `show_timer` and `timer_icon` drive it. Wiring it to `BaseMinigame`'s timer is a follow-on plan's job, recorded in DEBT by Task 6. Do not add a `timer_pressed` signal here.

Icons arrive through root `@export`s, so the art (an asset dependency) drops in without scene surgery. The `MinigameScoreHUD` instance is wrapped **unchanged** (decision 2). Restyling it onto `MinigameHudPill`/`MinigameHudValue` is deferred and recorded in DEBT.

**Files:**
- Test: `tests/test_minigame_header.gd` (create first)
- Create: `Scripts/Minigames/UI/MinigameHeader.gd`
- Create: `Scenes/Minigames/UI/MinigameHeader.tscn` (editor only)

**Interfaces:**
- Consumes:
  - `MinigameHudIconButton` (Task 3);
  - `Scenes/Minigames/UI/MinigameScoreHUD.tscn` / `MinigameScoreHUD` (`setup(hud_icon: Texture2D, target: int)`, `set_score(value: int)`, `set_combo(value: int)`, `set_label_text(text: String)`, public `value_label`);
  - `DesignTokens.touch_target_min` (96), authored as a size in the `.tscn`.
- Produces: `MinigameHeader` (Control) with:
  - `signal pause_pressed`;
  - `@export var show_timer: bool`, `@export var pause_icon: Texture2D` and `@export var timer_icon: Texture2D`;
  - `func setup(score_icon: Texture2D, target: int) -> void`, `func set_score(value: int) -> void`, `func set_combo(value: int) -> void` and `func set_label_text(text: String) -> void`, all forwarded down to the score HUD.
  - No timer signal: the timer button is display-only in Part 1.
- **Changed from the original plan:** no `score_text` export, and `set_score` takes the int score, matching `MinigameScoreHUD`. The label format ("7", "/ 3", or Badminton's "7 - 6" via `set_label_text`) stays the HUD's job.

- [ ] **Step 1: Write the failing test** — **[code]**

Create `tests/test_minigame_header.gd`:

```gdscript
@tool
extends McpTestSuite

## Proves the shared MinigameHeader strip: its icon buttons wear the kit's
## MinigameHudIconButton variation, its centre is the shared MinigameScoreHUD
## (instanced, not forked), and its root API forwards down to it. Instances are
## added to the editor root and tracked, so @onready and _ready run; the
## header's own runtime side effects are editor-gated. The scene is load()ed,
## not preloaded, so this suite still parses before the scene exists.
## Must be @tool, and no test here may be a coroutine.

const HEADER_PATH := "res://Scenes/Minigames/UI/MinigameHeader.tscn"
const SCRIPT_PATH := "res://Scripts/Minigames/UI/MinigameHeader.gd"
const SCORE_HUD_PATH := "res://Scenes/Minigames/UI/MinigameScoreHUD.tscn"
const ICON_SKOR := "res://Assets/Images/UI/Placeholders/icon_skor.svg"
## The unique names the script binds.
const BOUND_NODES: Array[String] = ["%PauseButton", "%TimerButton", "%ScoreHud"]
## A sample round: 2 of 3.
const SAMPLE_TARGET := 3
const SAMPLE_SCORE := 2


func suite_name() -> String:
	return "minigame_header"


func _make() -> MinigameHeader:
	var scene: PackedScene = load(HEADER_PATH)
	var header: MinigameHeader = scene.instantiate()
	Engine.get_main_loop().root.add_child(header)
	track(header)
	return header


func test_the_scene_carries_every_node_the_script_binds() -> void:
	var header: MinigameHeader = _make()
	for unique_name: String in BOUND_NODES:
		assert_true(header.get_node_or_null(unique_name) != null,
			"%s is an authored unique-name node" % unique_name)


func test_pause_and_timer_are_hud_icon_buttons() -> void:
	var header: MinigameHeader = _make()
	for unique_name: String in ["%PauseButton", "%TimerButton"]:
		var button: Button = header.get_node(unique_name)
		assert_eq(button.theme_type_variation, &"MinigameHudIconButton",
			"%s wears the HUD icon-button variation" % unique_name)


func test_the_centre_is_the_shared_score_hud() -> void:
	var header: MinigameHeader = _make()
	var hud: Node = header.get_node("%ScoreHud")
	assert_eq(hud.scene_file_path, SCORE_HUD_PATH,
		"the score readout is an instance of MinigameScoreHUD.tscn, not a fork")


func test_set_score_reaches_the_shared_readout() -> void:
	var header: MinigameHeader = _make()
	header.setup(load(ICON_SKOR) as Texture2D, SAMPLE_TARGET)
	header.set_score(SAMPLE_SCORE)
	var hud: MinigameScoreHUD = header.get_node("%ScoreHud")
	assert_eq(hud.value_label.text, str(SAMPLE_SCORE), "set_score forwards down to the HUD")


func test_show_timer_false_hides_the_timer_button() -> void:
	var header: MinigameHeader = _make()
	header.show_timer = false
	var timer_button: Button = header.get_node("%TimerButton")
	assert_false(timer_button.visible, "show_timer drives the timer button")


func test_the_pause_button_announces_pause_pressed() -> void:
	var header: MinigameHeader = _make()
	var presses: Array[int] = [0]
	header.pause_pressed.connect(func() -> void: presses[0] += 1)
	var pause_button: Button = header.get_node("%PauseButton")
	pause_button.pressed.emit()
	assert_eq(presses[0], 1, "a press is announced up, once")


func test_the_header_adds_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("add_theme_"), "chrome comes from the theme variations")
	var scene_src := FileAccess.get_file_as_string(HEADER_PATH)
	for banned: String in ["theme_override_colors", "theme_override_fonts",
			"theme_override_font_sizes", "theme_override_styles", "theme_override_icons"]:
		assert_false(scene_src.contains(banned), "no %s in the header scene" % banned)
```

- [ ] **Step 2: Run the test to verify it fails** — **[editor]**

Run `filesystem_manage(op="scan")`, then `test_run(suite="minigame_header")`.
Expected: FAIL. `MinigameHeader` is unknown and the scene is missing. If the reply instead reports the suite as broken because the `MinigameHeader` type does not resolve yet, that is the same red and is fine. Carry on.

- [ ] **Step 3: Write the script** — **[code]**

Create `Scripts/Minigames/UI/MinigameHeader.gd`. It is a new file and not open in any editor tab, so writing it before the scene work cannot be clobbered by a `scene_save`.

```gdscript
@tool
class_name MinigameHeader
extends Control

## Shared minigame top HUD strip (spec 2026-09-28 minigame-polish-part-1, 4.2):
## a pause icon-button (left), the shared score readout (centre) and a timer
## icon-button (right). The centre is an instance of MinigameScoreHUD.tscn --
## "extend rather than fork" -- so the score's pop, burst and combo chip stay
## in one component. Chrome comes from the MinigameHudIconButton variation;
## icons arrive through these root @exports because an instance's children
## drop their overrides on save.
##
## Affects: only its own children. Presentational: the owning minigame
## connects `pause_pressed` and calls setup() / set_score() down; this never
## reaches up. The timer button is display-only for now: it has no signal,
## and only show_timer and timer_icon drive it. @tool so the strip previews
## in the editor.

## Emitted when the player presses the pause icon-button.
signal pause_pressed

## Whether the right-hand timer icon-button is shown.
@export var show_timer: bool = true:
	set(value):
		show_timer = value
		_apply_exports()
## Pause button icon: a transparent SVG, never an emoji.
@export var pause_icon: Texture2D:
	set(value):
		pause_icon = value
		_apply_exports()
## Timer button icon: a transparent SVG, never an emoji.
@export var timer_icon: Texture2D:
	set(value):
		timer_icon = value
		_apply_exports()

@onready var _pause_button: Button = %PauseButton
@onready var _timer_button: Button = %TimerButton
@onready var _score_hud: MinigameScoreHUD = %ScoreHud


func _ready() -> void:
	if not _has_required_nodes():
		return
	_connect_pause_button()
	if Engine.is_editor_hint():
		return
	_apply_exports()


## Install the score readout's icon and target (MinigameScoreHUD.setup).
func setup(score_icon: Texture2D, target: int) -> void:
	_score_hud.setup(score_icon, target)


## Show the current score; a rise pops the readout (MinigameScoreHUD.set_score).
func set_score(value: int) -> void:
	_score_hud.set_score(value)


## Show or hide the combo chip (MinigameScoreHUD.set_combo).
func set_combo(value: int) -> void:
	_score_hud.set_combo(value)


## Write the score verbatim, for a two-sided score like Badminton's "7 - 6".
func set_label_text(text: String) -> void:
	_score_hud.set_label_text(text)


## True when the scene carries every node this script drives. A missing one
## means MinigameHeader.tscn is broken, so it is an error, not a silent skip.
func _has_required_nodes() -> bool:
	if _pause_button != null and _timer_button != null and _score_hud != null:
		return true
	push_error("MinigameHeader: PauseButton, TimerButton or ScoreHud is missing its unique name in MinigameHeader.tscn")
	return false


## Pure signal wiring, so it stays ungated and tests can press the button.
func _connect_pause_button() -> void:
	if _pause_button.pressed.is_connected(_on_pause_button_pressed):
		return
	_pause_button.pressed.connect(_on_pause_button_pressed)


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()


## Push the root @exports down onto the buttons. The setters call this while
## a scene is still loading, before the children exist -- hence the guard.
func _apply_exports() -> void:
	if not is_node_ready() or not _has_required_nodes():
		return
	_timer_button.visible = show_timer
	_timer_button.icon = timer_icon
	_pause_button.icon = pause_icon
```

Compliance notes:
- There are no bare numbers.
- Every var, parameter and return is typed.
- The longest function is 5 code lines, and every forwarder is one line, so no duplicate-body risk.
- The editor-gated `_apply_exports()` in `_ready()` keeps the original plan's behaviour: runtime applies the exports on ready, and the editor applies them only when an export changes.

- [ ] **Step 4: Build the scene in the editor** — **[editor]**

Do a no-op `script_patch` on the new script, then `filesystem_manage(op="scan")`. Build a new scene with `node_create`/`batch_execute` and save it with `scene_save` to `Scenes/Minigames/UI/MinigameHeader.tscn`. Per the authoring guide's MCP gotchas: `anchors_preset` is inert (set the four anchors), set `layout_mode = 1` before anchors on a Control under a plain Control, and numbers go unquoted.

- Root `MinigameHeader` (Control):
  - attach `Scripts/Minigames/UI/MinigameHeader.gd`;
  - top-wide: anchors left 0, top 0, right 1, bottom 0; `offset_bottom = 96`;
  - `custom_minimum_size = Vector2(0, 96)`, which is `touch_target_min`;
  - `mouse_filter = 2` (IGNORE), so the strip never eats taps between its buttons.
- `Row` (HBoxContainer), child of the root:
  - `layout_mode = 1`, full rect (anchors 0/0/1/1);
  - `mouse_filter = 2`.
  - Its separation comes from the theme's HBoxContainer rhythm. If a gap is needed, `theme_override_constants/separation` is the one allowed override.
- `PauseButton` (Button), child of `Row`:
  - `unique_name_in_owner = true`;
  - `theme_type_variation = &"MinigameHudIconButton"`;
  - `custom_minimum_size = Vector2(96, 96)`;
  - `expand_icon = true`, `icon_alignment = 1` (center), so the drop-in SVG fits the disc.
- `Center` (CenterContainer), child of `Row`: `size_flags_horizontal = 3` (expand fill), `mouse_filter = 2`.
- `ScoreHud`, child of `Center`:
  - an **instance** of `res://Scenes/Minigames/UI/MinigameScoreHUD.tscn`;
  - set `unique_name_in_owner = true` on this instance ROOT, which does serialise;
  - touch nothing inside the instance, because child overrides are dropped on save.
  - The CenterContainer sizes it from its `_get_minimum_size()`, which avoids the "instanced root loses its rect under a plain Control" trap.
- `TimerButton` (Button), child of `Row`: the same properties as `PauseButton`.

No `theme_override_*` other than an optional `separation`. Then `scene_save`, and afterwards:
1. Diff the new `.tscn`. It must contain no `[node … parent="Row/Center/ScoreHud/…"]` block without `instance=`, and no baked runtime state.
2. `git diff HEAD -- '*.gd'` must show only files this plan edits.
3. `git status --short` must not list the bake. If it does, see Task 4 Step 5.

- [ ] **Step 5: Run the tests to verify they pass** — **[editor]**

Do a no-op `script_patch` on `tests/test_minigame_header.gd`, then run:
1. `test_run(suite="minigame_header")` → PASS (7 tests). If a `theme_type_variation` reads as an empty StringName, the property was not saved: re-open the scene, set it with `node_set_property`, `scene_save`, then rescan.
2. `test_run(suite="minigame_score_hud")` → PASS. The shared HUD is untouched.

- [ ] **Step 6: Run the documentation, editability and clean-code suites** — **[editor]**

1. `test_run(suite="script_documentation")` → PASS: the `##` header sits within the first 12 lines, and each `@export` has a `##` line directly above it.
2. `test_run(suite="viewport_editability")` → PASS: the header builds no visuals at runtime and every node is static in the `.tscn`. Do not add it to `BASELINE` or `ALLOWED`.
3. `test_run(suite="clean_code")` → PASS. The new script is clean from its first commit. A "grew" here means a bare number, an untyped declaration or a long function slipped in: fix the code.

- [ ] **Step 7: Commit** — **[code]**

```bash
git branch --show-current
git status --short   # expect the three new files (+ .uid files), nothing else
git add Scripts/Minigames/UI/MinigameHeader.gd Scripts/Minigames/UI/MinigameHeader.gd.uid Scenes/Minigames/UI/MinigameHeader.tscn tests/test_minigame_header.gd tests/test_minigame_header.gd.uid
git commit -m "feat(minigame-kit): reusable MinigameHeader HUD strip over the shared score HUD"
```

---

### Task 6: Close-out — docs, debt, full run, ship

**Files:** `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`, `CLAUDE.md` (suite-count line only).

- [ ] **Step 1: Record the pass** — **[code]**

1. `CHANGELOG.md`: add a newest-first entry, "2026-09-28 — Minigame Polish Part 1: foundation kit". Cover:
   - the nine variations and what each is for;
   - `MinigameHeader` composed over `MinigameScoreHUD`;
   - the `MinigameHudIconButton` radius exemption;
   - the answer button's spec-driven hard shadow and its derived focus and disabled states;
   - a pointer to the spec and this plan.
2. `DEBT.md`: one grouped entry, "Minigame Polish Part 1 follow-ons (2026-09-28)", under "Deferred and pending", with the art bullet cross-referenced from "Placeholder art". Four bullets:
   - **Score HUD restyle deferred (decision 2).** `MinigameScoreHUD` still wears `ScoreHudPanel`/`ScoreHudValueLabel`, and `MinigameHeader` wraps it unchanged. Moving it onto `MinigameHudPill`/`MinigameHudValue` restyles all seven scoring minigames at once. It also needs its `TargetLabel` (`ResultBodyLabel`) and combo chip re-checked for contrast on the dark pill (`tests/test_light_ground_text.gd`).
   - **The timer button is display-only (decision 3).** `MinigameHeader`'s `TimerButton` has no signal and no behaviour. The follow-on plan wires it to `BaseMinigame`'s timer (today `_create_visual_timer()`), or turns it into a pure readout.
   - **No pause or timer icon art.** `pause_icon`/`timer_icon` stay unassigned until the transparent SVGs exist (spec §6).
   - **No minigame mounts `MinigameHeader` yet.** `BaseMinigame` still builds its pause button at runtime, which is the existing `viewport_editability` baseline debt.
   - End with one line saying the later Part 1 plans resolve all four.
3. `CLAUDE.md`: update only the "N suites, M tests (date)" line, from the full run's totals in Step 2.
   - Two suites are added, for 164 suites.
   - The test count grows by 19 (`minigame_kit` 12, `minigame_header` 7) over 2455, so expect about 2474.
   - Take the real numbers from the run.

- [ ] **Step 2: Full suite run** — **[editor]**

1. Restart the editor first: scripts were patched in Task 5, and a full run is 15–20 s of main-thread work that drops the bridge.
2. Open `Scenes/MainMenu/MainMenu.tscn` and run a full `test_run()`. Results are valid if the reply arrives before the drop.
3. Run `git status --short`, then `git checkout -- default_bus_layout.tres`.
4. `git diff Assets/Theme/kejartes_theme.tres` must be empty, since the full run's `theme_rebake` should reproduce the Task 4 bake. If it is not empty, investigate before continuing; do not commit a surprise bake.
5. Restart the editor, then run `test_run(suite="clean_code")` → PASS once more on the final tree.

- [ ] **Step 3: Commit the docs** — **[code]**

```bash
git branch --show-current
git add docs/superpowers/CHANGELOG.md docs/superpowers/DEBT.md CLAUDE.md
git commit -m "docs(minigame-kit): changelog, debt and suite count for Part 1 foundation"
```

- [ ] **Step 4: Ship** — **[editor]** (the controller runs the skill)

Finish with the `ship-pr` skill. It runs the full suite and a local review, pushes, opens the PR into `Textures` and stamps the tested commit. Right after `gh pr create`, bind the PR (`bind_pr` + `set_monitor`). Per the spec's §8 gate, **label the PR `hold` until the mentor signs off on the mockups**, since `ci/auto_merge.sh` would otherwise merge it.

---

## Self-Review

**Spec coverage (this plan = spec §4.1 + §4.2's HUD only):**
- §4.1 card, button, image plate, HUD and plank variations → Tasks 1–3. ✓
- §3's cream card rim and §4.1's hard `brandD` answer shadow are now as the spec says (decision 1), pinned by `minigame_kit`. Focus and disabled are derived from tokens because the spec defines neither. ✓
- The score HUD restyle (decision 2) and the timer's behaviour (decision 3) are deferred explicitly and recorded in DEBT by Task 6. ✓
- §4.1 rebake and ThemeFactory/`DISPLAY_ROSTER` pinning → Tasks 2–4. ✓
- §4.2 shared HUD scene → Task 5, now extending `MinigameScoreHUD` by composition, as §4.2 asks. ✓
- **Deliberately deferred to follow-on plans** (stated in Scope):
  - the `WoodNavArrow`, `MinigamePairChip*` and `MinigameToolCard*` variations;
  - the answer button's correct/wrong script-driven paths;
  - the overlay redesigns, win/lose and Menjodohkan;
  - gameplay-minigame polish and bug fixes;
  - the motion vocabulary;
  - restyling `MinigameScoreHUD` onto the kit;
  - mounting `MinigameHeader` in `BaseMinigame`.

**Placeholder scan:** No "TBD", "handle edge cases" or "similar to Task N". Every code step carries real GDScript. The one asset gap (pause/timer icon art) is handled structurally via root `@export`s and recorded in `DEBT.md` (Task 6).

**Type consistency:**
- Variation strings are identical across Tasks 1–6, the pins and the tests: `MinigameCard`, `MinigameCardInner`, `MinigameImagePlate`, `MinigameAnswerButton`, `MinigameHudPill`, `MinigameHudValue`, `MinigameHudIconButton`, `MinigamePlankPanel`, `MinigamePlankLabel`.
- `MinigameHeader`'s API is consistent between the script and its test: `pause_pressed`, `show_timer`, `pause_icon`, `timer_icon`, `setup(Texture2D, int)`, `set_score(int)`, `set_combo(int)`, `set_label_text(String)`.
- Suite names are consistent everywhere: `minigame_kit`, `minigame_header`, `theme_factory`, `theme_rebake`, `button_geometry`, `minigame_score_hud`, `script_documentation`, `viewport_editability`, `clean_code`.

**Clean-code check:**
- Every new function in `Scripts/` is typed and single-job.
- The only non-trivial number in new logic is named (`MINIGAME_CARD_SHADOW_ALPHA_BOOST`).
- Node refs are `%Unique` via `@onready`, a missing node is a `push_error`, and there is no commented-out code.
- The ratchet is run in every task, and no baseline entry is expected to move.

**Note for the executor:** `minigame_kit` intentionally has no baked-file dependency (it calls `ThemeFactory.build()` directly). So through Tasks 1–3 the only expected red anywhere is `theme_factory`'s `test_baked_theme_matches_what_the_factory_builds`, which Task 4 reconciles. If an assertion about a token value fails, check the current value in `DesignTokens.gd` rather than assuming the constant in this plan; values were verified against Textures 32bb618 on 2026-09-28.
