# Minigame Mobile Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give all eight minigames one phone layout: a notch-safe top strip
(pause · score · timer + a progress bar), a full-bleed play field, and a
bottom wood tray (button games) or floating hint pill (sports games). Add a
short "CARA MAIN" how-to card and notebook-frame pause/quit dialogs.

**Architecture:** There are four shared scenes:
- `MinigameHeader`: Part 1's, extended.
- `MinigameTray`: a `@tool` Container on the `NotebookFrame` pattern.
- `MinigameHintPill`.
- `HowToStepRow`, driven by `MinigameHowTo` resources.

Each minigame `.tscn` places them under a `SafeAreaMargin`. `BaseMinigame`
finds them by unique name (`%MinigameHeader`, `%MinigameTray`,
`%MinigameHintPill`) and wires pause, timer, progress and hints. Until the
last game is migrated it keeps its old code-built pause and timer as a
fallback; Task 16 deletes that fallback.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` text scenes, `ThemeFactory` +
`BakeTheme.gd`, `McpTestSuite` suites run through the godot-ai MCP
`test_run`.

**Spec:** `docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md`
(read it first). Worktree:
`C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/minigame-mobile-layout/`
on branch `feat/minigame-mobile-layout`. **Every path in this plan is
relative to that worktree.** Never edit the main checkout.

## Global Constraints

- Godot **4.6**; portrait 1080×1920 design size; tall phones run 1080×2400.
- **No `theme_override_*`** in any scene or script this plan touches. The one
  exception is layout-only constants (`separation`, `margin_*`). New looks are
  `ThemeFactory` variations; rebake after changing `ThemeFactory.gd`.
- **No visual built at runtime.** A new `X.new()` for a visual node type fails
  `tests/test_viewport_editability.gd`. Repeated rows are `PackedScene`
  templates (`instantiate()` is fine), and responsive drawing is a `@tool`
  script with documented `@export`s.
- **Every script:** a `##` header comment and a `##` line on every
  `@export` (`tests/test_script_documentation.gd`).
- **Every test suite:** `@tool`, `extends McpTestSuite`, a
  `suite_name()`, and **no `await` in any test**.
- **UI text is Indonesian. No emoji or dingbats**: U+2300–23FF,
  U+2600–27BF, U+2B00–2BFF, U+1F000–1FAFF and U+FE0F are banned. `×` and
  the Arrows block are allowed.
- **Button roles:**
  - mint `PrimaryButton`/`PrimaryButtonM`: the one main action (Mulai,
    Kirim, Selesai, Lanjutkan, "Tidak, lanjut main");
  - brown `SecondaryButton`/`SecondaryButtonM`: neutral (Hapus, Kunci,
    Batalkan, Pengaturan);
  - tomato `DangerButton`/`DangerButtonM`: destructive (Keluar, "Ya,
    keluar");
  - gold is never a button;
  - minigame answer buttons stay cream, with their styleboxes authored in the
    scene (commit `c228b4ef`).
- **Type ladder:** 36 (`font_title`) / 64 (`font_h1`) / 96
  (`font_display_size`); 28 (`font_body_size`) only for dense rows.
  - Boohong (display face) for the pill, bar label, planks and buttons.
  - Open Sans (body, theme default) for hints and how-to lines.
- **Our new tunables** are named `const`s or `@export`s in the owning
  script:
  - hint settle alpha **0.6**;
  - timer danger window **5.0 s**;
  - thumb line **0.55** of frame height;
  - tray padding **Vector4i(28, 28, 28, 24)**;
  - progress bar size **560×48**.
- **`Balance.gd` is never edited.**
- **Hand-edit a `.tscn` only with the Godot editor for this worktree
  CLOSED.** Afterwards open it in the editor, `scene_save` it once to
  normalise, and `git diff` it.
- **Scene work first, script work second** inside a task (CLAUDE.md 4b).
  After patching a script, restart the editor before the next `scene_save`.
- Tests run through the godot-ai MCP. The **controller** (the session running
  the editor) runs every `test_run`; implementer subagents write files only
  and never connect to the bridge.
- **Commits:** Conventional Commits with a scope, ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Write the
  message to a file and `git commit -F` it (PowerShell mangles `-m` with
  quotes).

## Editor recipe for this worktree (controller only)

The godot-ai bridge serves several editors. **Always pass `session_id`** for
this worktree's editor once it is listed
(`session_manage(op="list")` → the row whose `project_path` ends in
`/worktrees/minigame-mobile-layout/`). Never `session_activate`, and never
kill processes you did not start: other sessions share the machine.

- **Launch:** start `Godot_v4.6.2-stable_win64.exe --editor --path
  "<worktree>"` in the background. The executable lives in the Godot install
  directory; see the memory note `godot-editor-restarts-are-authorized`.
  - On a first launch in a fresh worktree, let the import finish, then run
    `filesystem_manage(op="scan")`.
- **Restart:** `editor_manage(op="quit", session_id=…)`, then relaunch as
  above.
- **Targeted tests:** `test_run(suite="<suite_name>", session_id=…)`.

## File map

| File | Status | Responsibility |
|---|---|---|
| `Assets/Images/UI/Icons/pause.svg`, `timer.svg`, `swipe_up.svg`, `howto_tap.svg`, `howto_swipe.svg`, `howto_drag.svg`, `howto_read.svg`, `howto_timer.svg`, `howto_target.svg` | create | placeholder pictograms (cream fill, dark outline) |
| `Assets/Images/UI/Icons/README.md` | modify | "Where each icon is used" rows |
| `Scripts/Design/ThemeFactory.gd` | modify | 6 new variations; lipped HUD icon button |
| `Assets/Theme/kejartes_theme.tres` | rebake | baked output |
| `tests/test_theme_factory.gd` | modify | `DISPLAY_ROSTER` |
| `Scripts/Minigames/UI/TimerRing.gd` | create | `@tool` drained-ring drawer |
| `Scripts/Minigames/UI/ProgressTicks.gd` | create | `@tool` segment dividers |
| `Scenes/Minigames/UI/MinigameHeader.tscn`, `Scripts/Minigames/UI/MinigameHeader.gd` | modify | progress row, timer slot, glyph icons, `set_progress`, `set_time` |
| `Scenes/Minigames/UI/MinigameTray.tscn`, `Scripts/Minigames/UI/MinigameTray.gd` | create | bottom plank container + hint |
| `Scenes/Minigames/UI/MinigameHintPill.tscn`, `Scripts/Minigames/UI/MinigameHintPill.gd` | create | floating hint pill |
| `Scripts/Minigames/UI/MinigameHowTo.gd`, `MinigameHowToStep.gd` | create | how-to data resources |
| `Resources/Minigames/HowTo/*.tres` (8) | create | each game's card content |
| `Scenes/Minigames/UI/HowToStepRow.tscn`, `Scripts/Minigames/UI/HowToStepRow.gd` | create | one step row template |
| `Scenes/Minigames/UI/MinigameTutorial.tscn`, `Scripts/Minigames/UI/MinigameTutorial.gd` | rewrite | CARA MAIN notebook dialog |
| `Scenes/Minigames/UI/PauseMenu.tscn`, `Scripts/Minigames/UI/PauseMenu.gd` | rewrite | JEDA notebook dialog |
| `Scenes/Minigames/UI/QuitConfirmDialog.tscn`, `Scripts/Minigames/UI/QuitConfirmDialog.gd` | rewrite | KELUAR? notebook dialog |
| `Scripts/Minigames/UI/BaseMinigame.gd` | modify | header/hint/progress wiring, how-to flow, countdown fix, then fallback removal |
| `Scripts/GameState.gd` | modify | `seen_minigame_how_to` session set |
| 8 minigame `.tscn` + `.gd` | modify | per-game layout (Tasks 9–15) |
| `tests/test_minigame_layout_kit.gd` | create | kit: icons, variations, tray, pill, how-to rows, resources |
| `tests/test_minigame_layout.gd` | create | per-game layout contract (grows task by task) |
| `tests/test_minigame_header.gd` | modify | progress, timer, glyphs |
| `tests/test_popup_frames.gd`, `test_minigame_overlays.gd`, `test_viewport_editability.gd`, `test_ui_text_glyphs.gd`, `test_minigame_score_hud.gd`, `test_kalkulator.gd`, `test_button_roles_phase3.gd`, `test_minigame_typography.gd`, `test_tall_screen_layout.gd` | modify | rosters and paths |
| `docs/superpowers/DEBT.md`, `CHANGELOG.md`, `CLAUDE.md` | modify | Task 16 |

---

### Task 0: Refresh the branch from Textures

The branch was cut from `feat/minigame-polish-part-1`, which is 329 commits
behind `origin/Textures` and conflicts in `CLAUDE.md`, `docs/superpowers/DEBT.md`
and `Assets/Theme/kejartes_theme.tres`.

**Files:** merge only.

- [ ] **Step 1: Make sure no editor has this worktree open**, then merge.

```bash
git -C "<worktree>" fetch origin
git -C "<worktree>" merge --no-ff origin/Textures
```

Expected: `CONFLICT` in exactly `CLAUDE.md`, `docs/superpowers/DEBT.md` and
`Assets/Theme/kejartes_theme.tres`. If anything else conflicts, stop and
report.

- [ ] **Step 2: Resolve `CLAUDE.md`** by taking Textures' version, then
re-adding nothing. Part 1's CLAUDE.md edits were only its suite count and a
Current-work line, and Textures' file is newer.

```bash
git -C "<worktree>" checkout --theirs CLAUDE.md
```

- [ ] **Step 3: Resolve `DEBT.md`** by hand: keep both sides' entries. Part
1's "Minigame kit" entries go under the minigame heading Textures uses. No
conflict markers may remain:
`git -C "<worktree>" diff --check` prints nothing.

- [ ] **Step 4: Resolve the baked theme by rebaking, never by hand-merging**
(memory: `resolve-theme-bake-conflicts-by-rebaking`).

```bash
git -C "<worktree>" checkout --theirs Assets/Theme/kejartes_theme.tres
```

Then launch the worktree editor (recipe above). Once it has imported, open
`Scripts/Design/BakeTheme.gd` and run it: `script_manage` or File > Run. If
the MCP has no run entry, run the `theme_rebake` suite, which calls
`ResourceSaver.save()` on the bake. Then quit and relaunch the editor
(memory: `rebake-alone-never-beside-scene-ops`).

- [ ] **Step 5: Verify.**

```
test_run(suite="theme_factory", session_id=…)
test_run(suite="minigame_kit", session_id=…)
test_run(suite="minigame_header", session_id=…)
test_run(suite="popup_frames", session_id=…)
```

Expected: all PASS.

- [ ] **Step 6: Commit the merge.**

```bash
git -C "<worktree>" add -A
git -C "<worktree>" commit -F msg.txt   # "Merge origin/Textures into feat/minigame-mobile-layout"
```

---

### Task 1: Placeholder icons

**Files:**
- Create: the nine SVGs in `Assets/Images/UI/Icons/`
- Modify: `Assets/Images/UI/Icons/README.md`
- Test: `tests/test_minigame_layout_kit.gd` (create), plus the existing `tests/test_ui_icons.gd`

**Interfaces:**
- Produces: `res://Assets/Images/UI/Icons/{pause,timer,swipe_up,howto_tap,howto_swipe,howto_drag,howto_read,howto_timer,howto_target}.svg`

- [ ] **Step 1: Write the failing test.** Create
`tests/test_minigame_layout_kit.gd`:

```gdscript
@tool
extends McpTestSuite

## The minigame mobile-layout kit (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 3):
## its icons, theme variations, tray, hint pill, how-to rows and resources.
## Each piece is pinned by the task that adds it. Must be @tool, and no
## test here may be a coroutine.

const ICON_DIR := "res://Assets/Images/UI/Icons/"
## Every placeholder pictogram the layout kit points at.
const KIT_ICONS: Array[String] = ["pause", "timer", "swipe_up", "howto_tap",
	"howto_swipe", "howto_drag", "howto_read", "howto_timer", "howto_target"]


func suite_name() -> String:
	return "minigame_layout_kit"


func test_every_kit_icon_exists() -> void:
	for icon: String in KIT_ICONS:
		var path := ICON_DIR + icon + ".svg"
		assert_true(ResourceLoader.exists(path), path + " is a kit icon")


func test_every_kit_icon_is_listed_in_the_readme() -> void:
	var readme := FileAccess.get_file_as_string(ICON_DIR + "README.md")
	for icon: String in KIT_ICONS:
		assert_contains(readme, "`" + icon + ".svg`", icon + " has a README row")
```

- [ ] **Step 2: Run it and check it fails.** (The controller, after a
scan.) `test_run(suite="minigame_layout_kit")`. Expected: FAIL, "pause.svg
is a kit icon".

- [ ] **Step 3: Create the SVGs.** They share the house placeholder style:
256×256, a cream fill `#FFF6E8`, a `#3B2412` outline of 14px, and round joins.
Write each file exactly:

`pause.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<rect x="64" y="48" width="44" height="160" rx="12"/><rect x="148" y="48" width="44" height="160" rx="12"/>
</g>
</svg>
```
`timer.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<rect x="104" y="20" width="48" height="28" rx="8"/><circle cx="128" cy="144" r="88"/><path d="M128 144V92M128 144l36 24" fill="none" stroke-width="18"/>
</g>
</svg>
```
`swipe_up.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<path d="M128 28l56 64h-34v68h-44V92H72z"/><circle cx="128" cy="204" r="30"/>
</g>
</svg>
```
`howto_tap.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<circle cx="112" cy="72" r="40" fill="none"/><path d="M112 72v96l-24-20c-14-12-34 6-22 22l52 58h78c10-36 18-60 18-84v-40c0-18-26-18-26 0v-8c0-18-28-18-28 0v-4c0-18-26-18-26 0V72c0-18-22-18-22 0z"/>
</g>
</svg>
```
`howto_swipe.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<path d="M40 64h120M128 32l36 32-36 32" fill="none"/><path d="M112 104v84l-20-16c-14-12-32 6-20 20l44 44h70c8-30 14-50 14-70v-34c0-16-24-16-24 0v-6c0-16-24-16-24 0v-4c0-16-22-16-22 0v-18c0-16-18-16-18 0z"/>
</g>
</svg>
```
`howto_drag.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<rect x="28" y="140" width="84" height="84" rx="14"/><rect x="148" y="28" width="84" height="84" rx="14" stroke-dasharray="18 14" fill="none"/><path d="M92 124L172 60M140 60h32v32" fill="none"/>
</g>
</svg>
```
`howto_read.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<path d="M128 64c-28-20-64-24-96-16v152c32-8 68-4 96 16 28-20 64-24 96-16V48c-32-8-68-4-96 16z"/><path d="M128 64v152" fill="none"/>
</g>
</svg>
```
`howto_timer.svg`: same as `timer.svg`, plus a minus badge.
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<circle cx="112" cy="144" r="80"/><path d="M112 144V96M112 144l32 20" fill="none" stroke-width="18"/><circle cx="196" cy="68" r="40"/><path d="M176 68h40" fill="none" stroke-width="16"/>
</g>
</svg>
```
`howto_target.svg`
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<g fill="#FFF6E8" stroke="#3B2412" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<circle cx="128" cy="128" r="100"/><circle cx="128" cy="128" r="60"/><circle cx="128" cy="128" r="20" fill="#3B2412"/>
</g>
</svg>
```

- [ ] **Step 4: Add the README rows.** In
`Assets/Images/UI/Icons/README.md`, under "Where each icon is used", insert
before the `home.svg…` row:

```markdown
| `pause.svg` | Pause a minigame | `MinigameHeader`'s `PauseButton/Glyph` | `test_minigame_layout_kit` |
| `timer.svg` | Time left | `MinigameHeader`'s `TimerButton/Glyph` | `test_minigame_layout_kit` |
| `swipe_up.svg` | Swipe up | MainBola's hint pill | `test_minigame_layout_kit` |
| `howto_tap.svg`, `howto_swipe.svg`, `howto_drag.svg`, `howto_read.svg`, `howto_timer.svg`, `howto_target.svg` | How-to steps | the `CARA MAIN` card's step rows, via `Resources/Minigames/HowTo/*.tres` | `test_minigame_layout_kit` |
```

- [ ] **Step 5: Run the tests and check they pass.** The controller runs
`filesystem_manage(op="scan")` and waits for the import, then
`test_run(suite="minigame_layout_kit")` and `test_run(suite="ui_icons")`.
Expected: both PASS. `ui_icons` checks the transparent corner and the
light-fill-plus-dark-outline rule on every file in the folder.

- [ ] **Step 6: Commit.**

```bash
git add Assets/Images/UI/Icons tests/test_minigame_layout_kit.gd
git commit -F msg.txt   # feat(minigame-layout): placeholder pause, timer and how-to icons
```

---

### Task 2: Theme variations

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (the `# minigame kit` section)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`)
- Rebake: `Assets/Theme/kejartes_theme.tres`
- Test: `tests/test_minigame_layout_kit.gd`

**Interfaces:**
- Produces these theme type variations:

| Variation | Base | Face | Used by |
|---|---|---|---|
| `MinigameProgressBar` | ProgressBar | — | the header's `ProgressBar` |
| `MinigameProgressLabel` | Label | display, 28 | the header's `ProgressLabel` |
| `MinigameTrayPanel` | Panel | — | `MinigameTray` (`panel` stylebox) |
| `MinigameHintLabel` | Label | body, 36, cream | the tray's and pill's `HintLabel` |
| `MinigameHintPillPanel` | Panel | — | `MinigameHintPill` |
| `MinigameHowToLabel` | Label | body, 36, dark ink | `HowToStepRow`'s `Text` |

  `MinigameHudIconButton` becomes a lipped brown button.

- [ ] **Step 1: Write the failing tests.** Append to
`tests/test_minigame_layout_kit.gd`:

```gdscript
const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## variation -> the base type it must extend.
const LAYOUT_VARIATIONS := {
	"MinigameProgressBar": "ProgressBar",
	"MinigameProgressLabel": "Label",
	"MinigameTrayPanel": "Panel",
	"MinigameHintLabel": "Label",
	"MinigameHintPillPanel": "Panel",
	"MinigameHowToLabel": "Label",
}


func _theme() -> Theme:
	return ThemeFactory.build(DesignTokens.load_default())


func test_layout_variations_exist_with_their_base() -> void:
	var theme := _theme()
	for name: String in LAYOUT_VARIATIONS:
		assert_eq(String(theme.get_type_variation_base(name)), LAYOUT_VARIATIONS[name],
			name + " extends " + LAYOUT_VARIATIONS[name])


func test_hints_and_how_to_lines_use_the_body_face_at_36() -> void:
	var theme := _theme()
	var tokens := DesignTokens.load_default()
	for name: String in ["MinigameHintLabel", "MinigameHowToLabel"]:
		assert_eq(theme.get_font_size("font_size", name), tokens.font_title, name + " is 36")
		assert_false(theme.has_font("font", name), name + " keeps the body face")


func test_the_progress_label_is_display_face_at_the_dense_rung() -> void:
	var theme := _theme()
	var tokens := DesignTokens.load_default()
	assert_eq(theme.get_font_size("font_size", "MinigameProgressLabel"), tokens.font_body_size)
	assert_eq(theme.get_font("font", "MinigameProgressLabel"), tokens.font_display)


func test_the_tray_plank_bleeds_past_its_rect() -> void:
	var box := _theme().get_stylebox("panel", "MinigameTrayPanel") as StyleBoxFlat
	assert_true(box != null, "the tray plank is a StyleBoxFlat")
	if box == null:
		return
	assert_true(box.expand_margin_bottom > 0.0 and box.expand_margin_left > 0.0,
		"the plank draws past the safe area to the screen edges")
	assert_eq(box.corner_radius_bottom_left, 0, "square bottom corners")


func test_the_hud_icon_button_is_lipped() -> void:
	var box := _theme().get_stylebox("normal", "MinigameHudIconButton")
	assert_true(LippedBox.is_lipped(box), "the pause/timer chrome is a lipped face")
```

- [ ] **Step 2: Run them and check they fail.**
`test_run(suite="minigame_layout_kit")`. Expected: FAIL on
`MinigameProgressBar`.

- [ ] **Step 3: Implement it.** In `Scripts/Design/ThemeFactory.gd`,
replace the icon-button block inside `_build_minigame_hud` with the lipped
builder, and call a new `_build_minigame_layout` from `_build_minigame_kit`.

In `_build_minigame_kit`, add a last line:

```gdscript
	_build_minigame_layout(theme, tokens)
```

In `_build_minigame_hud`, replace from `# An icon, never text, so no font…`
through the `focus` stylebox line with:

```gdscript
	# Lipped and brown like every neutral button (2026-09-28 UI depth pass).
	# _add_button_variation also sets the display face, so the variation is
	# on DISPLAY_ROSTER even though it carries a picture, never text.
	_add_button_variation(theme, tokens, "MinigameHudIconButton",
		tokens.brand_primary_light, tokens.brand_primary_dark, tokens.radius_pill)
	theme.set_stylebox("focus", "MinigameHudIconButton", _minigame_hud_icon_focus_box(tokens))
```

Append after `_minigame_hud_icon_focus_box`:

```gdscript
# ------------------------------------------------- minigame mobile layout

## The minigame mobile layout's chrome (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 3 and 5).
##   MinigameProgressBar    the dark track + gold fill under the score pill.
##   MinigameProgressLabel  its display-face label, at the dense rung.
##   MinigameTrayPanel      the brown bottom plank; bleeds past its rect so
##                          it reaches the screen edges from inside the
##                          SafeAreaMargin.
##   MinigameHintLabel      the one-line hint, body face, cream.
##   MinigameHintPillPanel  the translucent pill the sports games float.
##   MinigameHowToLabel     a CARA MAIN step line, body face, dark ink.

## How far the tray plank draws past its own rect: sideways past the safe
## area's screen margin, and down past any gesture-bar inset.
const MINIGAME_TRAY_BLEED_SIDE := 120.0
const MINIGAME_TRAY_BLEED_BOTTOM := 400.0
## The hint pill's backing alpha over surface_overlay.
const MINIGAME_HINT_PILL_ALPHA := 0.72


static func _build_minigame_layout(theme: Theme, tokens: DesignTokens) -> void:
	var track := _minigame_rim_box(tokens, tokens.brand_primary_dark, tokens.radius_pill)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tokens.currency_gold
	fill.set_corner_radius_all(tokens.radius_pill)
	theme.add_type("MinigameProgressBar")
	theme.set_type_variation("MinigameProgressBar", "ProgressBar")
	theme.set_stylebox("background", "MinigameProgressBar", track)
	theme.set_stylebox("fill", "MinigameProgressBar", fill)

	theme.add_type("MinigameProgressLabel")
	theme.set_type_variation("MinigameProgressLabel", "Label")
	_set_minigame_display_text(theme, tokens, "MinigameProgressLabel",
		tokens.text_on_brand, tokens.font_body_size)
	theme.set_constant("outline_size", "MinigameProgressLabel", tokens.lipped_label_outline)
	theme.set_color("font_outline_color", "MinigameProgressLabel", tokens.brand_primary_dark)

	var plank := StyleBoxFlat.new()
	plank.bg_color = tokens.brand_primary
	plank.border_width_top = int(tokens.outline_width)
	plank.border_color = tokens.brand_primary_dark
	plank.corner_radius_top_left = tokens.radius_lg
	plank.corner_radius_top_right = tokens.radius_lg
	plank.expand_margin_left = MINIGAME_TRAY_BLEED_SIDE
	plank.expand_margin_right = MINIGAME_TRAY_BLEED_SIDE
	plank.expand_margin_bottom = MINIGAME_TRAY_BLEED_BOTTOM
	_add_minigame_panel(theme, "MinigameTrayPanel", plank)

	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(tokens.surface_overlay, MINIGAME_HINT_PILL_ALPHA)
	pill.set_corner_radius_all(tokens.radius_pill)
	pill.content_margin_left = tokens.space_md
	pill.content_margin_right = tokens.space_md
	pill.content_margin_top = tokens.space_xs
	pill.content_margin_bottom = tokens.space_xs
	_add_minigame_panel(theme, "MinigameHintPillPanel", pill)

	for pair in [["MinigameHintLabel", tokens.text_on_brand],
			["MinigameHowToLabel", tokens.text_primary]]:
		theme.add_type(pair[0])
		theme.set_type_variation(pair[0], "Label")
		theme.set_font_size("font_size", pair[0], tokens.font_title)
		theme.set_color("font_color", pair[0], pair[1])
```

If `tokens.lipped_label_outline` does not exist, grep `DesignTokens.gd` for
`lipped_label_outline` first. It is used by `_apply_lipped_text` on
Textures.

In `tests/test_theme_factory.gd`, add this to `DISPLAY_ROSTER`, after
the `"MinigameWinLine", "MinigameWinStatLabel",` line:

```gdscript
	# 2026-09-29 minigame mobile layout: the progress label, and the HUD icon
	# button (lipped via _add_button_variation, which sets the display face).
	"MinigameProgressLabel", "MinigameHudIconButton",
```

- [ ] **Step 4: Rebake and run the tests.** Rebake (Task 0, Step 4), then
restart the editor and run:
`test_run(suite="minigame_layout_kit")`, `test_run(suite="theme_factory")`,
`test_run(suite="minigame_kit")`. Expected: all PASS.
  - `minigame_kit`'s icon-button tests still hold: the radius is
    `radius_pill`, and focus is still the gold rim.
  - If `theme_factory` reports a font stray, add that name to the roster
    with a comment.

- [ ] **Step 5: Commit.** Diff the bake first (memory
`rebake-alone-never-beside-scene-ops`). It should gain only the new
variations and the icon button's lipped boxes.

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd tests/test_minigame_layout_kit.gd
git commit -F msg.txt   # feat(minigame-layout): progress, tray, hint and how-to variations; lipped HUD icon button
```

---

### Task 3: Header progress row, timer ring and glyph icons

**Files:**
- Create: `Scripts/Minigames/UI/TimerRing.gd`, `Scripts/Minigames/UI/ProgressTicks.gd`
- Modify: `Scenes/Minigames/UI/MinigameHeader.tscn`, `Scripts/Minigames/UI/MinigameHeader.gd`
- Test: `tests/test_minigame_header.gd`

**Interfaces:**
- Consumes: `MinigameProgressBar`, `MinigameProgressLabel` and `MinigameHudIconButton` (Task 2); `pause.svg` and `timer.svg` (Task 1)
- Produces: `MinigameHeader` gains:
  - `set_progress(value: int, max_value: int, label: String) -> void`
  - `set_time(left: float, total: float) -> void`
  - `set_pause_enabled(enabled: bool) -> void`
  - the exports `show_score: bool`, `show_progress: bool`, `segmented: bool` and `danger_seconds: float`
  - the unique nodes `%ProgressBar`, `%ProgressLabel`, `%Ring`, `%Ticks`, `%PauseGlyph` and `%TimerGlyph`
  - The existing `pause_pressed`, `setup`, `set_score`, `set_combo`, `set_label_text` and `show_timer` stay unchanged.

- [ ] **Step 1: Write the failing tests.** Append to
`tests/test_minigame_header.gd`:

```gdscript
func test_set_progress_fills_the_bar_and_writes_the_label() -> void:
	var header: MinigameHeader = _make()
	header.set_progress(3, 10, "Soal 3/10")
	var bar: ProgressBar = header.get_node("%ProgressBar")
	assert_eq(bar.max_value, 10.0, "max follows the round length")
	assert_eq(bar.value, 3.0, "value is written straight through in the editor")
	assert_eq((header.get_node("%ProgressLabel") as Label).text, "Soal 3/10")


func test_segmented_draws_one_tick_per_step() -> void:
	var header: MinigameHeader = _make()
	header.segmented = true
	header.set_progress(1, 4, "Langkah 1/4")
	assert_eq((header.get_node("%Ticks") as ProgressTicks).segments, 4)
	header.segmented = false
	header.set_progress(1, 4, "Langkah 1/4")
	assert_eq((header.get_node("%Ticks") as ProgressTicks).segments, 0)


func test_set_time_drains_the_ring_and_turns_danger_late() -> void:
	var header: MinigameHeader = _make()
	header.set_time(20.0, 40.0)
	var ring: TimerRing = header.get_node("%Ring")
	assert_true(is_equal_approx(ring.fraction, 0.5), "half the time left, half a ring")
	assert_false(ring.danger, "not yet in the danger window")
	header.set_time(header.danger_seconds - 0.1, 40.0)
	assert_true(ring.danger, "the last danger_seconds turn the ring red")


func test_hidden_score_and_progress_hide_their_nodes() -> void:
	var header: MinigameHeader = _make()
	header.show_score = false
	header.show_progress = false
	assert_false((header.get_node("%ScoreHud") as Control).visible)
	assert_false((header.get_node("%ProgressBar") as Control).is_visible_in_tree())


func test_hidden_timer_keeps_its_slot_so_the_pill_stays_centred() -> void:
	var header: MinigameHeader = _make()
	header.show_timer = false
	var slot := header.get_node("Stack/Row/TimerSlot") as Control
	assert_true(slot.visible, "the slot stays, only the button hides")
	assert_eq(slot.custom_minimum_size, Vector2(96, 96))


func test_icons_are_glyph_children_not_button_icons() -> void:
	var header: MinigameHeader = _make()
	assert_eq((header.get_node("%PauseGlyph") as TextureRect).texture.resource_path,
		"res://Assets/Images/UI/Icons/pause.svg")
	assert_eq((header.get_node("%TimerGlyph") as TextureRect).texture.resource_path,
		"res://Assets/Images/UI/Icons/timer.svg")
	assert_true((header.get_node("%PauseButton") as Button).icon == null,
		"a lipped button squeezes an icon; the glyph is a child")


func test_set_pause_enabled_disables_the_button() -> void:
	var header: MinigameHeader = _make()
	header.set_pause_enabled(false)
	assert_true((header.get_node("%PauseButton") as Button).disabled)
```

- [ ] **Step 2: Run them and check they fail.**
`test_run(suite="minigame_header")`. Expected: the new tests FAIL with
`%ProgressBar` missing.

- [ ] **Step 3: Write the two drawers.**

`Scripts/Minigames/UI/TimerRing.gd`:
```gdscript
@tool
class_name TimerRing
extends Control

## The minigame header's time-left ring (spec 2026-09-29 minigame mobile
## layout, 3.1): a dark track with a gold arc that drains clockwise from
## twelve o'clock, turning state_danger for the last seconds. Drawn, not
## built: responsive geometry from documented @exports, so nothing is added
## to the tree at runtime. Colours come from the design tokens.

## Share of the time still left, 0..1.
@export_range(0.0, 1.0, 0.001) var fraction: float = 1.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()
## True inside the header's danger window; the arc turns state_danger.
@export var danger: bool = false:
	set(value):
		danger = value
		queue_redraw()
## Ring stroke width in px.
@export_range(2.0, 40.0, 1.0) var ring_width: float = 10.0:
	set(value):
		ring_width = value
		queue_redraw()
## Arc resolution, in points round a full circle.
const POINTS := 64


func _draw() -> void:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - ring_width / 2.0
	draw_arc(centre, radius, 0.0, TAU, POINTS, tokens.brand_primary_dark, ring_width, true)
	if fraction <= 0.0:
		return
	var start := -PI / 2.0
	var colour: Color = tokens.state_danger if danger else tokens.currency_gold
	draw_arc(centre, radius, start, start + TAU * fraction, POINTS, colour, ring_width, true)
```

`Scripts/Minigames/UI/ProgressTicks.gd`:
```gdscript
@tool
class_name ProgressTicks
extends Control

## Segment dividers over the minigame header's progress bar (spec 2026-09-29
## minigame mobile layout, 3.1): with `segments` > 1 it draws segments - 1
## vertical lines, so BuatBatik's four tool steps read as four cells. Drawn,
## not built; 0 or 1 draws nothing.

## How many cells to divide the bar into; 0 or 1 = a plain bar.
@export_range(0, 20, 1) var segments: int = 0:
	set(value):
		segments = maxi(0, value)
		queue_redraw()
## Divider stroke width in px.
@export_range(1.0, 12.0, 1.0) var tick_width: float = 4.0:
	set(value):
		tick_width = value
		queue_redraw()


func _draw() -> void:
	if segments <= 1:
		return
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	for i in range(1, segments):
		var x := size.x * float(i) / float(segments)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), tokens.brand_primary_dark, tick_width)
```

- [ ] **Step 4: Rewrite `MinigameHeader.tscn`** (editor closed). Keep the
existing `uid`, the two ext_resources and every existing node's
`unique_id`, and add ext_resources for the scripts and icons. The full
file:

```ini
[gd_scene format=3 uid="uid://bfy1n2cpht386"]

[ext_resource type="Script" uid="uid://cuoe5ctkfarjp" path="res://Scripts/Minigames/UI/MinigameHeader.gd" id="1_ord25"]
[ext_resource type="PackedScene" uid="uid://c252mxoppqb74" path="res://Scenes/Minigames/UI/MinigameScoreHUD.tscn" id="2_nm1gy"]
[ext_resource type="Script" path="res://Scripts/Minigames/UI/TimerRing.gd" id="3_ring"]
[ext_resource type="Script" path="res://Scripts/Minigames/UI/ProgressTicks.gd" id="4_ticks"]
[ext_resource type="Script" path="res://Scripts/UI/ButtonGlyph.gd" id="5_glyph"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Icons/pause.svg" id="6_pause"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Icons/timer.svg" id="7_timer"]

[node name="MinigameHeader" type="Control" unique_id=615373285]
custom_minimum_size = Vector2(0, 160)
layout_mode = 3
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 160.0
grow_horizontal = 2
mouse_filter = 2
script = ExtResource("1_ord25")
pause_icon = ExtResource("6_pause")
timer_icon = ExtResource("7_timer")

[node name="Stack" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_override_constants/separation = 16

[node name="Row" type="HBoxContainer" parent="Stack" unique_id=576564000]
layout_mode = 2
mouse_filter = 2

[node name="PauseButton" type="Button" parent="Stack/Row" unique_id=388898880]
unique_name_in_owner = true
custom_minimum_size = Vector2(96, 96)
layout_mode = 2
theme_type_variation = &"MinigameHudIconButton"

[node name="PauseGlyph" type="TextureRect" parent="Stack/Row/PauseButton"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 22.0
offset_top = 18.0
offset_right = -22.0
offset_bottom = -26.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
script = ExtResource("5_glyph")

[node name="Center" type="CenterContainer" parent="Stack/Row" unique_id=2133430264]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="ScoreHud" parent="Stack/Row/Center" unique_id=584836618 instance=ExtResource("2_nm1gy")]
unique_name_in_owner = true
layout_mode = 2

[node name="TimerSlot" type="Control" parent="Stack/Row"]
custom_minimum_size = Vector2(96, 96)
layout_mode = 2
mouse_filter = 2

[node name="TimerButton" type="Button" parent="Stack/Row/TimerSlot" unique_id=1827989972]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
focus_mode = 0
mouse_filter = 2
theme_type_variation = &"MinigameHudIconButton"

[node name="Ring" type="Control" parent="Stack/Row/TimerSlot/TimerButton"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("3_ring")

[node name="TimerGlyph" type="TextureRect" parent="Stack/Row/TimerSlot/TimerButton"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 28.0
offset_top = 24.0
offset_right = -28.0
offset_bottom = -32.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="ProgressRow" type="CenterContainer" parent="Stack"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2

[node name="ProgressBar" type="ProgressBar" parent="Stack/ProgressRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(560, 48)
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"MinigameProgressBar"
max_value = 1.0
show_percentage = false

[node name="Ticks" type="Control" parent="Stack/ProgressRow/ProgressBar"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("4_ticks")

[node name="ProgressLabel" type="Label" parent="Stack/ProgressRow/ProgressBar"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"MinigameProgressLabel"
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 5: Update `MinigameHeader.gd`.** Keep everything already
there, and change or add the following. In the `##` header, append this
paragraph:

```gdscript
## Mobile layout (spec 2026-09-29 minigame mobile layout, 3.1): a progress
## row under the strip (set_progress), a drained timer ring (set_time), and
## pause/timer pictures as ButtonGlyph children rather than Button.icon,
## because a lipped button's content margins squeeze an icon. A hidden
## timer keeps its 96px slot so the score pill stays centred.
```

Add these exports after `timer_icon`:

```gdscript
## Whether the centre score pill shows (BuatBatik has no score).
@export var show_score: bool = true:
	set(value):
		show_score = value
		_apply_exports()
## Whether the progress row under the strip shows.
@export var show_progress: bool = true:
	set(value):
		show_progress = value
		_apply_exports()
## Draw the progress bar as max_value cells (BuatBatik's four steps).
@export var segmented: bool = false
## The last seconds in which the timer ring turns state_danger (ours; spec 6).
@export_range(0.0, 30.0, 0.5) var danger_seconds: float = 5.0
```

Replace the `@onready` block with:

```gdscript
@onready var _pause_button: Button = %PauseButton
@onready var _timer_button: Button = %TimerButton
@onready var _score_hud: MinigameScoreHUD = %ScoreHud
@onready var _pause_glyph: TextureRect = %PauseGlyph
@onready var _timer_glyph: TextureRect = %TimerGlyph
@onready var _ring: TimerRing = %Ring
@onready var _progress_row: Control = %ProgressRow
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_label: Label = %ProgressLabel
@onready var _ticks: ProgressTicks = %Ticks
```

Add these public methods after `set_label_text`:

```gdscript
## Fill the progress bar to value/max_value and write its label verbatim
## ("Soal 3/10"). In the running game the fill tweens (Juice.fill_bar); in
## the editor it is written straight, so tests read it back at once.
func set_progress(value: int, max_value: int, label: String) -> void:
	_progress_bar.max_value = maxf(1.0, float(max_value))
	_progress_label.text = label
	_ticks.segments = max_value if segmented else 0
	if Engine.is_editor_hint():
		_progress_bar.value = float(value)
	else:
		Juice.fill_bar(_progress_bar, float(value))


## Drain the timer ring to left/total, red inside danger_seconds.
func set_time(left: float, total: float) -> void:
	_ring.fraction = 0.0 if total <= 0.0 else left / total
	_ring.danger = left <= danger_seconds


## Enable or disable the pause button (the game disables it once it ends).
func set_pause_enabled(enabled: bool) -> void:
	_pause_button.disabled = not enabled
```

Update `_has_required_nodes` to check all ten `@onready` nodes, and its
`push_error` text to "MinigameHeader: a unique-name node is missing in
MinigameHeader.tscn". Replace the body of `_apply_exports` with:

```gdscript
	if not is_node_ready() or not _has_required_nodes():
		return
	_timer_button.visible = show_timer
	_score_hud.visible = show_score
	_progress_row.visible = show_progress
	_pause_glyph.texture = pause_icon
	_timer_glyph.texture = timer_icon
```

- [ ] **Step 6: Normalise and test.** The controller opens the editor,
`scene_open` then `scene_save` on `MinigameHeader.tscn`, and diffs it. Then:
- `test_run(suite="minigame_header")`: PASS, the old tests and the seven new
  ones.
- `test_run(suite="script_documentation")`: PASS.
- `test_run(suite="viewport_editability")`: PASS. The drawers use no
  `.new()`.

- [ ] **Step 7: Commit.**

```bash
git add Scenes/Minigames/UI/MinigameHeader.tscn Scripts/Minigames/UI tests/test_minigame_header.gd
git commit -F msg.txt   # feat(minigame-layout): header progress row, drained timer ring, glyph icons
```

---

### Task 4: `MinigameTray` and `MinigameHintPill`

**Files:**
- Create: `Scripts/Minigames/UI/MinigameTray.gd`, `Scenes/Minigames/UI/MinigameTray.tscn`
- Create: `Scripts/Minigames/UI/MinigameHintPill.gd`, `Scenes/Minigames/UI/MinigameHintPill.tscn`
- Test: `tests/test_minigame_layout_kit.gd`

**Interfaces:**
- Consumes: `MinigameTrayPanel`, `MinigameHintLabel` and `MinigameHintPillPanel` (Task 2)
- Produces:
  - `MinigameTray` (Container): export `hint_text: String` and `separation: int`; methods `set_hint(text: String)` and `settle()`; const `SETTLED_ALPHA := 0.6`; constants `HINT_META := &"minigame_tray_hint"` and `PADDING := Vector4i(28, 28, 28, 24)`.
  - `MinigameHintPill` (PanelContainer): exports `hint_text: String` and `icon_texture: Texture2D`; methods `set_hint(text: String)` and `settle()`.

- [ ] **Step 1: Write the failing tests.** Append to
`tests/test_minigame_layout_kit.gd`:

```gdscript
const LayoutFrame := preload("res://tests/layout_frame.gd")
const TRAY := "res://Scenes/Minigames/UI/MinigameTray.tscn"
const PILL := "res://Scenes/Minigames/UI/MinigameHintPill.tscn"


func _tray_with(children: int) -> MinigameTray:
	var tray := (load(TRAY) as PackedScene).instantiate() as MinigameTray
	for i in children:
		var c := Control.new()
		c.custom_minimum_size = Vector2(0, 100)
		tray.add_child(c)
	var frame := Control.new()
	frame.size = Vector2(984, 1000)
	frame.theme = load(THEME_PATH)
	frame.add_child(tray)
	Engine.get_main_loop().root.add_child(frame)
	track(frame)
	tray.size = Vector2(984, tray.get_combined_minimum_size().y)
	tray.sort_now()
	return tray


func test_the_tray_stacks_host_content_above_its_hint() -> void:
	var tray := _tray_with(2)
	var hint := tray.get_node("HintLabel") as Control
	var first := tray.get_child(tray.get_child_count() - 2) as Control
	var second := tray.get_child(tray.get_child_count() - 1) as Control
	assert_true(first.position.y < second.position.y, "host children stack in order")
	assert_true(second.position.y + second.size.y <= hint.position.y, "the hint is last")
	assert_true(hint.has_meta(MinigameTray.HINT_META), "the hint is tray chrome, not host content")


func test_the_tray_is_as_tall_as_its_content() -> void:
	var one := _tray_with(1).get_combined_minimum_size().y
	var two := _tray_with(2).get_combined_minimum_size().y
	assert_true(is_equal_approx(two - one, 100.0 + MinigameTray.new().separation),
		"each host row adds its height plus one separation")


func test_tray_settle_fades_the_hint_but_never_hides_it() -> void:
	var tray := _tray_with(1)
	tray.set_hint("Ketuk jawaban yang benar")
	var hint := tray.get_node("HintLabel") as Label
	assert_eq(hint.text, "Ketuk jawaban yang benar")
	tray.settle()
	assert_true(is_equal_approx(hint.modulate.a, MinigameTray.SETTLED_ALPHA))
	tray.set_hint("Urutan salah!")
	assert_true(is_equal_approx(hint.modulate.a, 1.0), "a new hint comes back at full strength")


func test_the_pill_ignores_taps_and_shows_its_icon() -> void:
	var pill := (load(PILL) as PackedScene).instantiate() as MinigameHintPill
	pill.icon_texture = load(ICON_DIR + "swipe_up.svg")
	Engine.get_main_loop().root.add_child(pill)
	track(pill)
	assert_eq(pill.mouse_filter, Control.MOUSE_FILTER_IGNORE, "gestures pass through")
	assert_true((pill.get_node("%Icon") as TextureRect).visible, "an icon shows when set")
	pill.set_hint("Geser ke atas untuk menendang")
	assert_eq((pill.get_node("%HintLabel") as Label).text, "Geser ke atas untuk menendang")
	pill.settle()
	assert_true(is_equal_approx((pill.get_node("%HintLabel") as Label).modulate.a,
		MinigameHintPill.SETTLED_ALPHA))
```

The line `MinigameTray.new().separation` builds a throwaway Container to
read a default; free it right away. Replace that line with:

```gdscript
	var probe := MinigameTray.new()
	var sep := probe.separation
	probe.free()
	assert_true(is_equal_approx(two - one, 100.0 + sep),
		"each host row adds its height plus one separation")
```

- [ ] **Step 2: Run them and check they fail.**
`test_run(suite="minigame_layout_kit")`. Expected: FAIL, "Could not
find type MinigameTray" or the scene is missing.

- [ ] **Step 3: Write `Scripts/Minigames/UI/MinigameTray.gd`.**

```gdscript
@tool
class_name MinigameTray
extends Container

## The button minigames' bottom plank (spec 2026-09-29 minigame mobile
## layout, 3.2), on the NotebookFrame pattern: a host scene drops its
## controls in as direct children of this instance's root (children of an
## instance's root always save) and the tray stacks them top to bottom,
## then lays its own HintLabel -- tagged HINT_META -- last. The plank is the
## MinigameTrayPanel stylebox, drawn here; it bleeds past this rect so the
## wood reaches the screen edges while the content stays inside the
## SafeAreaMargin. Height is the content's; a host's Spacer takes the slack.
##
## Affects: only its own children. BaseMinigame calls set_hint() and
## settle(); nothing here reaches up.

## Marks the tray's own HintLabel, so it is never treated as host content.
const HINT_META := &"minigame_tray_hint"
## The hint's alpha after the player's first correct action (ours; spec 6).
const SETTLED_ALPHA := 0.6
## Inner padding (left, top, right, bottom) between the plank's edge and
## its content.
const PADDING := Vector4i(28, 28, 28, 24)

## The one-line hint under the controls.
@export var hint_text: String = "":
	set(value):
		hint_text = value
		_apply_hint()
## Gap in px between stacked host rows, and above the hint.
@export_range(0, 64, 1) var separation: int = 16:
	set(value):
		separation = value
		update_minimum_size()
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		sort_now()
	elif what == NOTIFICATION_READY:
		_apply_hint()


func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel"), Rect2(Vector2.ZERO, size))


## Every visible Control child except the hint, in scene order.
func _host_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control != null and control.visible and not control.has_meta(HINT_META):
			rows.append(control)
	return rows


func _hint() -> Label:
	return get_node_or_null("HintLabel") as Label


func _get_minimum_size() -> Vector2:
	var width := 0.0
	var height := float(PADDING.y + PADDING.w)
	var rows := _host_rows()
	for row in rows:
		var m := row.get_combined_minimum_size()
		width = maxf(width, m.x)
		height += m.y
	height += float(separation * maxi(0, rows.size() - 1))
	var hint := _hint()
	if hint != null and hint.visible:
		height += hint.get_combined_minimum_size().y + (separation if not rows.is_empty() else 0)
	return Vector2(width + PADDING.x + PADDING.z, height)


## Lay the host rows out top-down, then the hint along the bottom.
func sort_now() -> void:
	var inner_w := size.x - PADDING.x - PADDING.z
	var y := float(PADDING.y)
	for row in _host_rows():
		var h := row.get_combined_minimum_size().y
		fit_child_in_rect(row, Rect2(PADDING.x, y, inner_w, h))
		y += h + separation
	var hint := _hint()
	if hint != null:
		var hh := hint.get_combined_minimum_size().y
		fit_child_in_rect(hint, Rect2(PADDING.x, size.y - PADDING.w - hh, inner_w, hh))
	queue_redraw()


## Show `text` as the hint, at full strength.
func set_hint(text: String) -> void:
	hint_text = text
	var hint := _hint()
	if hint != null:
		hint.modulate.a = 1.0


## Fade the hint to SETTLED_ALPHA; it stays readable and never hides.
func settle() -> void:
	var hint := _hint()
	if hint == null:
		return
	if Engine.is_editor_hint():
		hint.modulate.a = SETTLED_ALPHA
	else:
		hint.create_tween().tween_property(hint, "modulate:a", SETTLED_ALPHA,
			Juice.tokens().dur_normal)


func _apply_hint() -> void:
	var hint := _hint()
	if hint == null:
		return
	hint.text = hint_text
	hint.visible = hint_text != ""
	update_minimum_size()
	queue_sort()
```

- [ ] **Step 4: Write `Scenes/Minigames/UI/MinigameTray.tscn`.**

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameTray.gd" id="1_tray"]

[node name="MinigameTray" type="Container"]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 0
theme_type_variation = &"MinigameTrayPanel"
script = ExtResource("1_tray")

[node name="HintLabel" type="Label" parent="."]
layout_mode = 2
theme_type_variation = &"MinigameHintLabel"
horizontal_alignment = 1
autowrap_mode = 3
metadata/minigame_tray_hint = true
```

- [ ] **Step 5: Write `Scripts/Minigames/UI/MinigameHintPill.gd`.**

```gdscript
@tool
class_name MinigameHintPill
extends PanelContainer

## The sports minigames' floating hint (spec 2026-09-29 minigame mobile
## layout, 3.3): a translucent pill anchored bottom-centre, level with the
## tray's hint in the button games, with an optional picture (MainBola's
## swipe-up). It ignores taps so every gesture reaches the game's _input.
##
## Affects: only its own children. BaseMinigame calls set_hint() / settle().

## The hint's alpha after the first successful action (ours; spec 6).
const SETTLED_ALPHA := 0.6

## The hint line.
@export var hint_text: String = "":
	set(value):
		hint_text = value
		_apply_exports()
## Optional picture left of the text; null hides the Icon.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply_exports()


func _ready() -> void:
	_apply_exports()


## Show `text` at full strength.
func set_hint(text: String) -> void:
	hint_text = text
	var label := get_node_or_null("%HintLabel") as Label
	if label != null:
		label.modulate.a = 1.0


## Fade the text to SETTLED_ALPHA; it never hides.
func settle() -> void:
	var label := get_node_or_null("%HintLabel") as Label
	if label == null:
		return
	if Engine.is_editor_hint():
		label.modulate.a = SETTLED_ALPHA
	else:
		label.create_tween().tween_property(label, "modulate:a", SETTLED_ALPHA,
			Juice.tokens().dur_normal)


func _apply_exports() -> void:
	if not is_node_ready():
		return
	(%HintLabel as Label).text = hint_text
	var icon := %Icon as TextureRect
	icon.texture = icon_texture
	icon.visible = icon_texture != null
```

- [ ] **Step 6: Write `Scenes/Minigames/UI/MinigameHintPill.tscn`.**

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameHintPill.gd" id="1_pill"]

[node name="MinigameHintPill" type="PanelContainer"]
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_bottom = -24.0
grow_horizontal = 2
grow_vertical = 0
mouse_filter = 2
theme_type_variation = &"MinigameHintPillPanel"
script = ExtResource("1_pill")

[node name="Row" type="HBoxContainer" parent="."]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 16
alignment = 1

[node name="Icon" type="TextureRect" parent="Row"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="HintLabel" type="Label" parent="Row"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"MinigameHintLabel"
vertical_alignment = 1
```

- [ ] **Step 7: Normalise and test.** The controller scans, then
`scene_open` and `scene_save` on both new scenes, and diffs them. Then
`test_run(suite="minigame_layout_kit")`,
`test_run(suite="script_documentation")` and
`test_run(suite="viewport_editability")`. Expected: PASS. The test file's
`Control.new()` is in `tests/`, which the ratchet does not scan; confirm
that the scan root excludes `res://tests`.

- [ ] **Step 8: Commit.**

```bash
git add Scripts/Minigames/UI/MinigameTray.gd Scenes/Minigames/UI/MinigameTray.tscn Scripts/Minigames/UI/MinigameHintPill.gd Scenes/Minigames/UI/MinigameHintPill.tscn tests/test_minigame_layout_kit.gd
git commit -F msg.txt   # feat(minigame-layout): the bottom tray and the floating hint pill
```

---

### Task 5: How-to resources and the step row

**Files:**
- Create: `Scripts/Minigames/UI/MinigameHowTo.gd`, `Scripts/Minigames/UI/MinigameHowToStep.gd`
- Create: `Scripts/Minigames/UI/HowToStepRow.gd`, `Scenes/Minigames/UI/HowToStepRow.tscn`
- Create: `Resources/Minigames/HowTo/{PilihanGanda,Password,Variabel,Menjodohkan,BuatBatik,MainBola,Badminton,LombaMenari}.tres`
- Test: `tests/test_minigame_layout_kit.gd`

**Interfaces:**
- Produces:
  - `class_name MinigameHowTo extends Resource`: `title: String`, `steps: Array[MinigameHowToStep]`
  - `class_name MinigameHowToStep extends Resource`: `icon: Texture2D`, `text: String`
  - `HowToStepRow` (HBoxContainer, `@tool`): exports `icon_texture` and `step_text`
  - `const HOW_TO_DIR := "res://Resources/Minigames/HowTo/"`, one `<ScriptBaseName>.tres` per game

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const HOW_TO_DIR := "res://Resources/Minigames/HowTo/"
const GAMES: Array[String] = ["PilihanGanda", "Password", "Variabel", "Menjodohkan",
	"BuatBatik", "MainBola", "Badminton", "LombaMenari"]
## The banned pictograph ranges (style guide, "No emoji or dingbats").
const BANNED := [[0x2300, 0x23FF], [0x2600, 0x27BF], [0x2B00, 0x2BFF],
	[0x1F000, 0x1FAFF], [0xFE0F, 0xFE0F]]


func _has_banned(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		for r in BANNED:
			if c >= r[0] and c <= r[1]:
				return true
	return false


func test_every_game_has_a_how_to_card_of_two_or_three_steps() -> void:
	for game: String in GAMES:
		var how := load(HOW_TO_DIR + game + ".tres") as MinigameHowTo
		assert_true(how != null, game + " has a MinigameHowTo")
		if how == null:
			continue
		assert_true(how.title != "", game + " has a title")
		assert_true(how.steps.size() >= 2 and how.steps.size() <= 3, game + ": 2-3 steps")
		for step in how.steps:
			assert_true(step.icon != null, game + ": every step has a picture")
			assert_false(step.text.to_lower().contains("lorem"), game + ": no placeholder text")
			assert_false(_has_banned(step.text + how.title), game + ": no emoji")


func test_a_step_row_shows_its_picture_and_line() -> void:
	var row := (load("res://Scenes/Minigames/UI/HowToStepRow.tscn") as PackedScene).instantiate()
	row.icon_texture = load(ICON_DIR + "howto_tap.svg")
	row.step_text = "Ketuk jawaban yang benar."
	Engine.get_main_loop().root.add_child(row)
	track(row)
	assert_eq((row.get_node("%Icon") as TextureRect).texture, row.icon_texture)
	var text := row.get_node("%Text") as Label
	assert_eq(text.text, "Ketuk jawaban yang benar.")
	assert_eq(text.theme_type_variation, &"MinigameHowToLabel")
```

- [ ] **Step 2: Run them and check they fail.** Expected: FAIL,
"PilihanGanda has a MinigameHowTo".

- [ ] **Step 3: Write the resource scripts.**

`Scripts/Minigames/UI/MinigameHowToStep.gd`:
```gdscript
class_name MinigameHowToStep
extends Resource

## One step of a minigame's CARA MAIN card (spec 2026-09-29 minigame mobile
## layout, 3.4): a picture and one short Indonesian line.

## The step's picture, from Assets/Images/UI/Icons/howto_*.svg.
@export var icon: Texture2D
## One short line, Indonesian, no emoji.
@export_multiline var text: String = ""
```

`Scripts/Minigames/UI/MinigameHowTo.gd`:
```gdscript
class_name MinigameHowTo
extends Resource

## A minigame's CARA MAIN card content (spec 2026-09-29 minigame mobile
## layout, 3.4). One .tres per game in Resources/Minigames/HowTo/, named
## after the game's script; BaseMinigame.how_to points at it. Replaces the
## old tutorial_title / tutorial_instructions strings and their emoji
## fallback table.

## The game's name, shown as the card's heading.
@export var title: String = ""
## Two or three steps, top to bottom.
@export var steps: Array[MinigameHowToStep] = []
```

- [ ] **Step 4: Write the step row.**

`Scripts/Minigames/UI/HowToStepRow.gd`:
```gdscript
@tool
extends HBoxContainer

## One CARA MAIN step (spec 2026-09-29 minigame mobile layout, 3.4): a 96px
## picture and one body-face line. A template: MinigameTutorial instances
## one per MinigameHowToStep, so no row is built from code. The content
## arrives through these root @exports, because an instance's children drop
## their overrides on save.

## The step's picture.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply()
## The step's line.
@export var step_text: String = "":
	set(value):
		step_text = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	(%Icon as TextureRect).texture = icon_texture
	(%Text as Label).text = step_text
```

`Scenes/Minigames/UI/HowToStepRow.tscn`:
```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/HowToStepRow.gd" id="1_row"]

[node name="HowToStepRow" type="HBoxContainer"]
theme_override_constants/separation = 28
script = ExtResource("1_row")

[node name="Icon" type="TextureRect" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(96, 96)
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Text" type="Label" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(560, 0)
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"MinigameHowToLabel"
vertical_alignment = 1
autowrap_mode = 3
```

- [ ] **Step 5: Write the eight `.tres` files.** They all share this shape.
Here is `Resources/Minigames/HowTo/PilihanGanda.tres`:

```ini
[gd_resource type="Resource" script_class="MinigameHowTo" load_steps=7 format=3]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameHowTo.gd" id="1_howto"]
[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameHowToStep.gd" id="2_step"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Icons/howto_read.svg" id="3_a"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Icons/howto_tap.svg" id="4_b"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Icons/howto_timer.svg" id="5_c"]

[sub_resource type="Resource" id="Step_1"]
script = ExtResource("2_step")
icon = ExtResource("3_a")
text = "Baca soalnya baik-baik."

[sub_resource type="Resource" id="Step_2"]
script = ExtResource("2_step")
icon = ExtResource("4_b")
text = "Ketuk satu jawaban yang benar."

[sub_resource type="Resource" id="Step_3"]
script = ExtResource("2_step")
icon = ExtResource("5_c")
text = "Jawaban salah memotong waktu 3 detik."

[resource]
script = ExtResource("1_howto")
title = "Pilihan Ganda"
steps = Array[ExtResource("2_step")]([SubResource("Step_1"), SubResource("Step_2"), SubResource("Step_3")])
```

The other seven use the same layout, with this content. Icons are
`howto_<name>.svg`, and `load_steps` = ext_resources + sub_resources + 1.

| File | title | step 1 (icon · text) | step 2 | step 3 |
|---|---|---|---|---|
| `Password.tres` | Password | read · "Hitung soal di kartu." | tap · "Ketik jawabannya di kalkulator." | timer · "Tekan Kirim. Salah memotong waktu 5 detik." |
| `Variabel.tres` | Variabel | read · "Cari nilai huruf yang belum diketahui." | tap · "Ketik angkanya, lalu tekan Kirim." | timer · "Benar menambah waktu 20 detik." |
| `Menjodohkan.tres` | Menjodohkan | swipe · "Geser kartu soal dan kartu jawaban." | tap · "Tekan Kunci untuk memasangkan keduanya." | target · "Semua terpasang? Tekan Selesai." |
| `BuatBatik.tres` | Membuat Batik | drag · "Seret alat ke kanvas." | read · "Urutannya: Pensil, Canting, Pewarna, Kompor." | timer · "Urutan salah memotong waktu." |
| `MainBola.tres` | Tendangan Penalti | swipe · "Geser bola ke atas untuk menendang." | target · "Arahkan ke kotak target di gawang." | read · "Cetak gol sebelum tendanganmu habis." |
| `Badminton.tres` | Badminton | drag · "Geser pemukulmu di bawah layar." | target · "Pantulkan kok melewati lawan." | read · "Raih skor target lebih dulu." |
| `LombaMenari.tres` | Lomba Menari | swipe · "Geser searah panah saat panah masuk lingkaran." | target · "Tepat waktu memberi skor lebih besar." | timer · "Terlalu banyak terlewat berarti kalah." |

- [ ] **Step 6: Scan and test.** The controller runs
`filesystem_manage(op="scan")` (new `class_name`s), then
`test_run(suite="minigame_layout_kit")` and
`test_run(suite="script_documentation")`. Expected: PASS. If a `.tres`
fails to load, open it in the editor and re-save it to let Godot fill in
uids.

- [ ] **Step 7: Commit.**

```bash
git add Scripts/Minigames/UI/MinigameHowTo*.gd Scripts/Minigames/UI/HowToStepRow.gd Scenes/Minigames/UI/HowToStepRow.tscn Resources/Minigames/HowTo tests/test_minigame_layout_kit.gd
git commit -F msg.txt   # feat(minigame-layout): how-to resources for all eight games and the step row
```

---

### Task 6: The CARA MAIN card (`MinigameTutorial`, redesigned)

**Files:**
- Rewrite: `Scenes/Minigames/UI/MinigameTutorial.tscn`, `Scripts/Minigames/UI/MinigameTutorial.gd`
- Modify: `tests/test_popup_frames.gd` (`POPUPS`), `tests/test_viewport_editability.gd` (`BASELINE`)
- Test: `tests/test_minigame_layout_kit.gd`

**Interfaces:**
- Consumes: `MinigameHowTo`, `HowToStepRow.tscn` (Task 5); `NotebookFrame.tscn`; `SafeAreaMargin.gd`
- Produces:
  - `MinigameTutorial` (CanvasLayer, layer 500, `@tool`, `class_name MinigameTutorial`)
  - `setup(how_to: MinigameHowTo) -> void`
  - `signal tutorial_finished`, emitted only by the Mulai button
  - frame path `Safe/Center/Frame`

- [ ] **Step 1: Write the failing tests.**

Append to `tests/test_minigame_layout_kit.gd`:

```gdscript
const TUTORIAL := "res://Scenes/Minigames/UI/MinigameTutorial.tscn"


func test_the_card_fills_one_row_per_step_and_the_title() -> void:
	var card := (load(TUTORIAL) as PackedScene).instantiate() as MinigameTutorial
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.setup(load(HOW_TO_DIR + "PilihanGanda.tres"))
	assert_eq((card.get_node("%GameTitle") as Label).text, "Pilihan Ganda")
	assert_eq(card.get_node("%Steps").get_child_count(), 3, "one HowToStepRow per step")


func test_only_mulai_finishes_the_card() -> void:
	var card := (load(TUTORIAL) as PackedScene).instantiate() as MinigameTutorial
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var fired := [false]
	card.tutorial_finished.connect(func() -> void: fired[0] = true)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	(card.get_node("Scrim") as Control).gui_input.emit(tap)
	assert_false(fired[0], "a tap on the scrim does nothing")
	(card.get_node("%Mulai") as Button).pressed.emit()
	assert_true(fired[0], "Mulai starts the game")


func test_mulai_is_the_mint_main_action() -> void:
	var src := FileAccess.get_file_as_string(TUTORIAL)
	assert_contains(src, "theme_type_variation = &\"PrimaryButtonM\"")
	assert_contains(src, "text = \"Mulai\"")
```

In `tests/test_popup_frames.gd`, add this `POPUPS` row after the
`TutorialPanel` row:

```gdscript
	"res://Scenes/Minigames/UI/MinigameTutorial.tscn": ["Safe/Center/Frame", "dialog", "safe"],
```

In `tests/test_viewport_editability.gd`, **delete** the `BASELINE` line
`"res://Scripts/Minigames/UI/MinigameTutorial.gd": 12,` (the ratchet
turns 12 → 0).

- [ ] **Step 2: Run them and check they fail.** Run the suites
`minigame_layout_kit` and `popup_frames`. Expected: FAIL (`%GameTitle`
missing; no NotebookFrame at `Safe/Center/Frame`).

- [ ] **Step 3: Rewrite `Scenes/Minigames/UI/MinigameTutorial.tscn`**
(editor closed). Keep the file's existing `uid` line: read it first and
copy the `[gd_scene … uid="…"]` header verbatim. Also keep the existing
script ext_resource's `uid` if it has one.

```ini
[gd_scene format=3 uid="<KEEP EXISTING>"]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameTutorial.gd" id="1_tut"]
[ext_resource type="Script" path="res://Scripts/UI/SafeAreaMargin.gd" id="2_safe"]
[ext_resource type="PackedScene" path="res://Scenes/UI/NotebookFrame.tscn" id="3_frame"]

[node name="MinigameTutorial" type="CanvasLayer"]
process_mode = 3
layer = 500
script = ExtResource("1_tut")

[node name="Scrim" type="Panel" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"Scrim"

[node name="Safe" type="MarginContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_safe")

[node name="Center" type="CenterContainer" parent="Safe"]
layout_mode = 2
mouse_filter = 2

[node name="Frame" parent="Safe/Center" instance=ExtResource("3_frame")]
unique_name_in_owner = true
layout_mode = 2
title_text = "CARA MAIN"
ring_count = 4
show_well = false
show_close = false

[node name="Column" type="VBoxContainer" parent="Safe/Center/Frame"]
custom_minimum_size = Vector2(760, 0)
layout_mode = 2
theme_override_constants/separation = 36

[node name="GameTitle" type="Label" parent="Safe/Center/Frame/Column"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"H2Label"
horizontal_alignment = 1

[node name="Steps" type="VBoxContainer" parent="Safe/Center/Frame/Column"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 28

[node name="Mulai" type="Button" parent="Safe/Center/Frame/Column"]
unique_name_in_owner = true
custom_minimum_size = Vector2(420, 0)
layout_mode = 2
size_flags_horizontal = 4
theme_type_variation = &"PrimaryButtonM"
text = "Mulai"
```

- [ ] **Step 4: Rewrite `Scripts/Minigames/UI/MinigameTutorial.gd`.**

```gdscript
@tool
class_name MinigameTutorial
extends CanvasLayer

## The CARA MAIN card a minigame shows before its first round (spec
## 2026-09-29 minigame mobile layout, 3.4): a NotebookFrame dialog with the
## game's name, two or three HowToStepRow rows from its MinigameHowTo, and a
## mint Mulai. Only Mulai closes it -- a tap on the scrim does nothing -- so
## nobody skips the card by accident. Replaces the code-built dark box of
## paragraphs; every visual is authored in MinigameTutorial.tscn or
## HowToStepRow.tscn.
##
## Affects: nothing outside itself. BaseMinigame awaits tutorial_finished.

## Emitted when the player presses Mulai.
signal tutorial_finished

## One step row, instanced per MinigameHowToStep.
const STEP_ROW := preload("res://Scenes/Minigames/UI/HowToStepRow.tscn")


func _ready() -> void:
	var mulai := get_node_or_null("%Mulai") as Button
	if mulai != null and not mulai.pressed.is_connected(_on_mulai):
		mulai.pressed.connect(_on_mulai)
	if Engine.is_editor_hint():
		return
	var frame := get_node_or_null("%Frame") as Control
	if frame != null:
		AnimUtils.popup_spring_in(frame)


## Fill the card from `how_to`: the heading and one row per step.
func setup(how_to: MinigameHowTo) -> void:
	(%GameTitle as Label).text = how_to.title if how_to != null else ""
	var steps := %Steps as VBoxContainer
	for child in steps.get_children():
		steps.remove_child(child)
		child.queue_free()
	if how_to == null:
		return
	var rows: Array = []
	for step in how_to.steps:
		var row := STEP_ROW.instantiate()
		row.icon_texture = step.icon
		row.step_text = step.text
		steps.add_child(row)
		rows.append(row)
	if not Engine.is_editor_hint():
		Juice.stagger_in(rows)


func _on_mulai() -> void:
	tutorial_finished.emit()
```

Check that `AnimUtils.popup_spring_in(node)` exists with that signature:
`grep -n "func popup_spring_in" Scripts/AnimUtils.gd`. If its signature
differs, match it.

- [ ] **Step 5: Keep the old caller compiling.** `BaseMinigame.activate_minigame()`
still calls `tutorial.setup(active_title, active_instructions)` until
Task 8. So that nothing breaks in between, make this task's change to
`activate_minigame()` now. Replace the line

```gdscript
		tutorial.setup(active_title, active_instructions)
```

with

```gdscript
		tutorial.setup(how_to)
```

and add, next to the other tutorial exports in `BaseMinigame.gd`:

```gdscript
## This game's CARA MAIN card (Resources/Minigames/HowTo/<Game>.tres).
@export var how_to: MinigameHowTo
```

Task 8 finishes the rewiring.

- [ ] **Step 6: Normalise and test.** The controller scans, then
`scene_open` and `scene_save` on `MinigameTutorial.tscn`, and diffs it.
Run these suites: `minigame_layout_kit`, `popup_frames`,
`viewport_editability`, `script_documentation`. Expected: PASS.
`viewport_editability`'s `test_baseline_is_not_stale` passes only because
the line was deleted.

- [ ] **Step 7: Commit.**

```bash
git add Scenes/Minigames/UI/MinigameTutorial.tscn Scripts/Minigames/UI/MinigameTutorial.gd Scripts/Minigames/UI/BaseMinigame.gd tests/test_popup_frames.gd tests/test_viewport_editability.gd tests/test_minigame_layout_kit.gd
git commit -F msg.txt   # feat(minigame-layout): the CARA MAIN card in the notebook frame
```

---

### Task 7: JEDA and KELUAR? dialogs

**Files:**
- Rewrite: `Scenes/Minigames/UI/PauseMenu.tscn`, `Scripts/Minigames/UI/PauseMenu.gd`
- Rewrite: `Scenes/Minigames/UI/QuitConfirmDialog.tscn`, `Scripts/Minigames/UI/QuitConfirmDialog.gd`
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd`: drop the quit-dialog visual exports and the `configure(...)` call
- Modify: `tests/test_popup_frames.gd`, `tests/test_minigame_overlays.gd`, `tests/test_viewport_editability.gd` (`ALLOWED` PauseMenu line)
- Test: those suites

**Interfaces:**
- Produces:
  - `PauseMenu`: a Control root, full rect, with signals `resume_pressed`, `settings_pressed` and `quit_pressed` (unchanged), and the frame at `Safe/Center/Frame`
  - `QuitConfirmDialog`: a CanvasLayer root (layer 210), with signals `confirmed` and `cancelled` (unchanged), the frame at `Safe/Center/Frame` and the buttons `%YesButton` and `%NoButton`
  - `configure()` is **deleted**

- [ ] **Step 1: Read the pinned paths first.** Run
`grep -n "Center/Card\|YesButton\|NoButton\|configure\|CountLabel" tests/test_minigame_overlays.gd`
and note every assertion on QuitConfirmDialog. Those assertions move to the
new paths in Step 5.

- [ ] **Step 2: Write the failing test rows.** In
`tests/test_popup_frames.gd`, add these `POPUPS` rows:

```gdscript
	"res://Scenes/Minigames/UI/PauseMenu.tscn": ["Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/Minigames/UI/QuitConfirmDialog.tscn": ["Safe/Center/Frame", "dialog", "safe"],
```

Append to `tests/test_minigame_layout_kit.gd`:

```gdscript
func test_jeda_and_keluar_wear_their_roles() -> void:
	var pause := FileAccess.get_file_as_string("res://Scenes/Minigames/UI/PauseMenu.tscn")
	assert_contains(pause, "title_text = \"JEDA\"")
	for pair in [["Lanjutkan", "PrimaryButtonM"], ["Pengaturan", "SecondaryButtonM"],
			["Keluar", "DangerButtonM"]]:
		assert_contains(pause, "text = \"%s\"" % pair[0])
	var quit := FileAccess.get_file_as_string("res://Scenes/Minigames/UI/QuitConfirmDialog.tscn")
	assert_contains(quit, "title_text = \"KELUAR?\"")
	assert_contains(quit, "text = \"Tidak, lanjut main\"")
	assert_contains(quit, "text = \"Ya, keluar\"")
	assert_false(pause.contains("Game diberhentikan"), "no error-sounding title")
```

- [ ] **Step 3: Run them and check they fail.** Run the suites
`popup_frames` and `minigame_layout_kit`. Expected: FAIL.

- [ ] **Step 4: Rewrite the pause menu.**
`Scenes/Minigames/UI/PauseMenu.tscn` (keep its `uid`, and the script
ext_resource's `uid` if present):

```ini
[gd_scene format=3 uid="uid://jljfq30m2mse"]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/PauseMenu.gd" id="1_pause"]
[ext_resource type="Script" path="res://Scripts/UI/SafeAreaMargin.gd" id="2_safe"]
[ext_resource type="PackedScene" path="res://Scenes/UI/NotebookFrame.tscn" id="3_frame"]

[node name="PauseMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_pause")

[node name="Scrim" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"Scrim"

[node name="Safe" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_safe")

[node name="Center" type="CenterContainer" parent="Safe"]
layout_mode = 2
mouse_filter = 2

[node name="Frame" parent="Safe/Center" instance=ExtResource("3_frame")]
unique_name_in_owner = true
layout_mode = 2
title_text = "JEDA"
ring_count = 4
show_well = false
show_close = false

[node name="Buttons" type="VBoxContainer" parent="Safe/Center/Frame"]
custom_minimum_size = Vector2(620, 0)
layout_mode = 2
theme_override_constants/separation = 28

[node name="BtnResume" type="Button" parent="Safe/Center/Frame/Buttons"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"PrimaryButtonM"
text = "Lanjutkan"

[node name="BtnSettings" type="Button" parent="Safe/Center/Frame/Buttons"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"SecondaryButtonM"
text = "Pengaturan"

[node name="BtnQuit" type="Button" parent="Safe/Center/Frame/Buttons"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"DangerButtonM"
text = "Keluar"
```

`Scripts/Minigames/UI/PauseMenu.gd`:
```gdscript
@tool
class_name PauseMenu
extends Control

## A minigame's JEDA dialog (spec 2026-09-29 minigame mobile layout, 3.5):
## a NotebookFrame dialog with mint Lanjutkan, brown Pengaturan and tomato
## Keluar. Every visual is authored in PauseMenu.tscn; UIPolish juices the
## buttons. Replaces the dark box and its texture/colour @exports.
##
## Affects: nothing outside itself. BaseMinigame listens to the signals.

## The player wants to keep playing.
signal resume_pressed
## The player opened Pengaturan.
signal settings_pressed
## The player chose Keluar (BaseMinigame then asks KELUAR?).
signal quit_pressed


func _ready() -> void:
	_wire(%BtnResume as Button, resume_pressed)
	_wire(%BtnSettings as Button, settings_pressed)
	_wire(%BtnQuit as Button, quit_pressed)
	if Engine.is_editor_hint():
		return
	AnimUtils.popup_spring_in(%Frame as Control)


## Pure signal wiring, ungated so tests can press the buttons.
func _wire(button: Button, relay: Signal) -> void:
	if not button.pressed.is_connected(relay.emit):
		button.pressed.connect(relay.emit)
```

In `tests/test_viewport_editability.gd`, delete this `ALLOWED` entry and
its comment:
`"res://Scripts/Minigames/UI/PauseMenu.gd": 1,`

- [ ] **Step 5: Rewrite the quit dialog.**
`Scenes/Minigames/UI/QuitConfirmDialog.tscn` (keep its `uid` and the
script ext_resource's `uid="uid://binqx2scuw8a3"`):

```ini
[gd_scene format=3 uid="uid://br4pstl80mtp4"]

[ext_resource type="Script" uid="uid://binqx2scuw8a3" path="res://Scripts/Minigames/UI/QuitConfirmDialog.gd" id="1_1jnih"]
[ext_resource type="Script" path="res://Scripts/UI/SafeAreaMargin.gd" id="2_safe"]
[ext_resource type="PackedScene" path="res://Scenes/UI/NotebookFrame.tscn" id="3_frame"]

[node name="QuitConfirmDialog" type="CanvasLayer"]
process_mode = 3
layer = 210
script = ExtResource("1_1jnih")

[node name="Scrim" type="Panel" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"Scrim"

[node name="Safe" type="MarginContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_safe")

[node name="Center" type="CenterContainer" parent="Safe"]
layout_mode = 2
mouse_filter = 2

[node name="Frame" parent="Safe/Center" instance=ExtResource("3_frame")]
unique_name_in_owner = true
layout_mode = 2
title_text = "KELUAR?"
ring_count = 4
show_well = false
show_close = false

[node name="Layout" type="VBoxContainer" parent="Safe/Center/Frame"]
custom_minimum_size = Vector2(760, 0)
layout_mode = 2
theme_override_constants/separation = 44

[node name="MessageLabel" type="Label" parent="Safe/Center/Frame/Layout"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"MinigameHowToLabel"
text = "Kalau keluar sekarang, minigame ini dianggap gagal."
horizontal_alignment = 1
autowrap_mode = 3

[node name="Buttons" type="VBoxContainer" parent="Safe/Center/Frame/Layout"]
layout_mode = 2
theme_override_constants/separation = 28

[node name="NoButton" type="Button" parent="Safe/Center/Frame/Layout/Buttons"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"PrimaryButtonM"
text = "Tidak, lanjut main"

[node name="YesButton" type="Button" parent="Safe/Center/Frame/Layout/Buttons"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"DangerButtonM"
text = "Ya, keluar"
```

`Scripts/Minigames/UI/QuitConfirmDialog.gd`:
```gdscript
@tool
class_name QuitConfirmDialog
extends CanvasLayer

## The KELUAR? confirmation a minigame's JEDA dialog opens (spec 2026-09-29
## minigame mobile layout, 3.5): a NotebookFrame dialog whose safe choice,
## "Tidak, lanjut main", is mint and on top, and whose destructive choice,
## "Ya, keluar", is tomato. Every visual is authored in the .tscn; the old
## configure() and its texture/colour arguments are gone.
##
## Affects: nothing outside itself. BaseMinigame decides what the signals
## mean (abandon_game() / re-show JEDA).

## The player confirmed quitting.
signal confirmed
## The player backed out.
signal cancelled


func _ready() -> void:
	var yes := %YesButton as Button
	var no := %NoButton as Button
	if not yes.pressed.is_connected(confirmed.emit):
		yes.pressed.connect(confirmed.emit)
	if not no.pressed.is_connected(cancelled.emit):
		no.pressed.connect(cancelled.emit)
	if Engine.is_editor_hint():
		return
	AnimUtils.popup_spring_in(%Frame as Control)
```

- [ ] **Step 6: Update BaseMinigame.** In
`Scripts/Minigames/UI/BaseMinigame.gd`:
- Delete the whole `@export_group("Visual - Quit Dialog Overlay")` block
  (`quit_dialog_message_text` through `quit_dialog_font_color`).
- In `_show_quit_confirmation()`, delete the whole `dialog.configure(...)`
  call.

First confirm that no scene sets those exports:
`grep -rn "quit_dialog_" Scenes/`. Expected: no hits. If a scene sets
one, delete that property line from the scene (editor closed).

Update `tests/test_minigame_overlays.gd`'s QuitConfirmDialog assertions
from Step 1:
- `Center/Card/Margin/Layout/Buttons/YesButton` becomes `%YesButton`;
- `…/NoButton` becomes `%NoButton`;
- `…/MessageLabel` becomes `%MessageLabel`;
- delete any assertion on `configure` or on `Backdrop`.

- [ ] **Step 7: Normalise and test.** Scan, then `scene_open` and
`scene_save` on both scenes, and diff them. Then run these suites:
`popup_frames`, `minigame_overlays`, `minigame_layout_kit`,
`viewport_editability`, `script_documentation`. Expected: PASS.

- [ ] **Step 8: Commit.**

```bash
git add Scenes/Minigames/UI/PauseMenu.tscn Scripts/Minigames/UI/PauseMenu.gd Scenes/Minigames/UI/QuitConfirmDialog.tscn Scripts/Minigames/UI/QuitConfirmDialog.gd Scripts/Minigames/UI/BaseMinigame.gd tests
git commit -F msg.txt   # feat(minigame-layout): JEDA and KELUAR? in the notebook frame
```

---

### Task 8: BaseMinigame wiring, the how-to flow and the countdown fix

**Files:**
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd`, `Scripts/GameState.gd`
- Test: `tests/test_minigame_layout.gd` (create)

**Interfaces:**
- Consumes: `MinigameHeader` (Task 3), `MinigameTray`/`MinigameHintPill` (Task 4), `MinigameTutorial.setup(how_to)` (Task 6)
- Produces on `BaseMinigame`:
  - `func header() -> MinigameHeader`: `%MinigameHeader`, or null
  - `func show_hint(text: String) -> void`
  - `func hint_settle() -> void`
  - `func set_progress(value: int, max_value: int, label: String) -> void`
  - `static func should_show_how_to(enabled: bool, seen: Dictionary, key: String) -> bool`
  - the countdown always plays
- Produces on `GameState`: `var seen_minigame_how_to: Dictionary = {}`, cleared by `forget_session()`
- Keeps the legacy code-built pause and timer **only when `header()` is null** (removed in Task 16)

- [ ] **Step 1: Write the failing tests.** Create
`tests/test_minigame_layout.gd`:

```gdscript
@tool
extends McpTestSuite

## The minigame mobile layout contract (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 4, 6
## and 7): BaseMinigame's wiring and, task by task, each game's scene. Must
## be @tool; no test here may be a coroutine.

const BASE := "res://Scripts/Minigames/UI/BaseMinigame.gd"


func suite_name() -> String:
	return "minigame_layout"


func test_the_card_shows_once_per_session_and_only_when_enabled() -> void:
	var seen := {}
	assert_true(BaseMinigame.should_show_how_to(true, seen, "res://a.tres"))
	seen["res://a.tres"] = true
	assert_false(BaseMinigame.should_show_how_to(true, seen, "res://a.tres"), "seen this session")
	assert_true(BaseMinigame.should_show_how_to(true, seen, "res://b.tres"), "another game")
	assert_false(BaseMinigame.should_show_how_to(false, {}, "res://a.tres"), "setting off")
	assert_false(BaseMinigame.should_show_how_to(true, {}, ""), "a game with no card")


func test_the_countdown_runs_outside_the_tutorial_branch() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	var body := src.substr(src.find("func activate_minigame"))
	body = body.substr(0, body.find("\nfunc ", 1))
	var tut_if := body.find("if should_show_how_to(")
	var countdown := body.find("await _play_countdown()")
	assert_true(tut_if != -1 and countdown != -1, "both steps are in activate_minigame")
	var branch_end := body.find("\n\tawait _play_countdown()")
	assert_true(branch_end != -1, "the countdown sits at the function's own indent, after the if")


func test_forget_session_clears_the_seen_cards() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_contains(src, "var seen_minigame_how_to: Dictionary = {}")
	var forget := src.substr(src.find("func forget_session"))
	forget = forget.substr(0, forget.find("\nfunc ", 1))
	assert_contains(forget, "seen_minigame_how_to = {}")


func test_the_old_tutorial_strings_are_gone() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	for gone: String in ["tutorial_title", "tutorial_instructions",
			"_get_active_tutorial_title", "_get_active_tutorial_instructions"]:
		assert_false(src.contains(gone), gone + " is retired by MinigameHowTo")
```

- [ ] **Step 2: Run them and check they fail.** Run the suite
`minigame_layout`. Expected: FAIL, `should_show_how_to` is not declared.

- [ ] **Step 3: Update GameState.** In `Scripts/GameState.gd`, add near
the other session vars (after `tutorials_bypassed`):

```gdscript
## MinigameHowTo resource paths whose CARA MAIN card has shown this session.
## Session-scoped by design (CLAUDE.md: no new persistence).
var seen_minigame_how_to: Dictionary = {}
```

In `forget_session()`, after `tutorials_bypassed = false`, add:

```gdscript
	seen_minigame_how_to = {}
```

- [ ] **Step 4: Update BaseMinigame.**
1. Delete the `@export_group("Tutorial")` exports `tutorial_title` and
   `tutorial_instructions`, and the whole functions
   `_get_active_tutorial_title()` and `_get_active_tutorial_instructions()`.
   Keep the `how_to` export from Task 6 under an
   `@export_group("Tutorial")` header.
2. Grep for the retired exports and delete their property lines from the
   scenes (editor closed): `grep -rn "tutorial_title\|tutorial_instructions" Scenes/`.
   Expected: `Password.tscn` lines 22–23.
3. Replace `activate_minigame()` with:

```gdscript
func activate_minigame() -> void:
	var key := how_to.resource_path if how_to != null else ""
	if should_show_how_to(GameSettings.minigame_tutorial_enabled,
			GameState.seen_minigame_how_to, key):
		GameState.seen_minigame_how_to[key] = true
		var tutorial: MinigameTutorial = (load("res://Scenes/Minigames/UI/MinigameTutorial.tscn")
			as PackedScene).instantiate()
		_get_or_create_ui_layer().add_child(tutorial)
		tutorial.setup(how_to)
		await tutorial.tutorial_finished
		tutorial.queue_free()
	await _play_countdown()
	is_game_active = true


## Whether to show the CARA MAIN card: the Settings switch is on, the game
## has a card, and it has not shown this session. Pure, so it is testable.
static func should_show_how_to(enabled: bool, seen: Dictionary, key: String) -> bool:
	return enabled and key != "" and not seen.has(key)
```

4. Add the layout accessors under `activate_minigame`:

```gdscript
# --- mobile layout (spec 2026-09-29 minigame mobile layout, 6) ---------

## The scene's shared top strip, or null in a game not yet migrated.
func header() -> MinigameHeader:
	return get_node_or_null("%MinigameHeader") as MinigameHeader


## The scene's tray or hint pill -- whichever it has -- or null.
func _hint_host() -> Node:
	var tray := get_node_or_null("%MinigameTray")
	return tray if tray != null else get_node_or_null("%MinigameHintPill")


## Show `text` in the hint line, at full strength.
func show_hint(text: String) -> void:
	var host := _hint_host()
	if host != null:
		host.set_hint(text)


## Fade the hint once the player has shown they know what to do.
func hint_settle() -> void:
	var host := _hint_host()
	if host != null:
		host.settle()


## Fill the strip's progress bar (value of max_value) and write its label.
func set_progress(value: int, max_value: int, label: String) -> void:
	var strip := header()
	if strip != null:
		strip.set_progress(value, max_value, label)
```

5. In `start_minigame()`, replace the lines that create the timer and the
   pause button:

```gdscript
		has_time_limit = true
		_create_visual_timer()
	else:
		has_time_limit = false
	_create_pause_button()
```

with

```gdscript
		has_time_limit = true
	else:
		has_time_limit = false
	var strip := header()
	if strip != null:
		strip.show_timer = has_time_limit
		strip.set_time(game_time_left, max_game_time)
		strip.set_pause_enabled(true)
		if not strip.pause_pressed.is_connected(_on_pause_button_pressed):
			strip.pause_pressed.connect(_on_pause_button_pressed)
	else:
		# Legacy chrome for a scene not yet migrated; Task 16 deletes it.
		if has_time_limit:
			_create_visual_timer()
		_create_pause_button()
```

6. In `_process`, after the `if visual_timer:` redraw, add:

```gdscript
		var strip := header()
		if strip != null:
			strip.set_time(game_time_left, max_game_time)
```

7. In `_on_pause_button_pressed`, keep the guards. When `header()` is not
   null, call `pause_minigame()` directly; the boing animation belongs to
   the legacy button, and UIPolish juices the header's.

```gdscript
func _on_pause_button_pressed() -> void:
	if not is_game_active or is_paused:
		return
	if header() != null:
		pause_minigame()
		return
	_play_pause_button_boing_animation()
```

8. In `win_game()`, `lose_game()` and `abandon_game()`, add
   `if header() != null: header().set_pause_enabled(false)` next to each
   existing `if pause_button:` block.

- [ ] **Step 5: Reload and test.** Do a no-op `script_patch` on
`Scripts/GameState.gd` and `BaseMinigame.gd` (they were edited outside the
editor), then run the suites `minigame_layout`, `minigame_overlays`,
`viewport_editability` and `script_documentation`. Expected: PASS.
- The code-built count in `BaseMinigame.gd` is unchanged, since the legacy
  fallback is still present.
- Also run `test_run(suite="minigame_score_hud")` and `school_day`.
  Expected: PASS, because no scene has a header yet, so every game still
  takes the legacy path.

- [ ] **Step 6: Commit.**

```bash
git add Scripts/Minigames/UI/BaseMinigame.gd Scripts/GameState.gd Scenes/Minigames/Akademis/Password.tscn tests/test_minigame_layout.gd
git commit -F msg.txt   # feat(minigame-layout): wire the strip, hints and CARA MAIN; the countdown always runs
```

---

### Tasks 9–15: shared per-game recipe

Every game task follows this recipe. Only the per-game table and code
differ.

1. **Contract tests first.** Append the game's test functions (given in the
   task) to `tests/test_minigame_layout.gd`. Run them and see them fail.
2. **Scene (editor closed).** Edit the `.tscn` as a text file:
   - Add ext_resources for `res://Scripts/UI/SafeAreaMargin.gd`,
     `res://Scenes/Minigames/UI/MinigameHeader.tscn`, and either
     `MinigameTray.tscn` or `MinigameHintPill.tscn`.
   - Add the root property `how_to = ExtResource("<id>")` pointing at
     `res://Resources/Minigames/HowTo/<Game>.tres`.
   - Add the `Safe` node:

   ```ini
   [node name="Safe" type="MarginContainer" parent="."]
   layout_mode = 1
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   mouse_filter = 2
   script = ExtResource("<safe id>")
   ```

   - It is the **last** child of the root, so the strip draws over the field.
   - Move the listed nodes by rewriting their `parent="…"`, and rewrite the
     `parent=` of every descendant block to match. Keep each moved node's
     block order, so a parent always precedes its children.
   - Delete the listed nodes, together with **all** their descendant blocks.
   - Remove any ext_resource that is no longer referenced.
3. **Normalise.** Open the scene in the worktree editor, `scene_save` it,
   `git diff` it, and check that only the intended nodes changed. The memory
   notes `stickynote-tool-script-bakes-offsets` and
   `editor-reparent-bakes-instance-internals` explain what to look for.
4. **Script second.** Apply the task's script edits. Run a no-op
   `script_patch` on each edited `.gd`, then restart the editor before any
   further `scene_save`.
5. **Tests.** Run the game's suites (listed in each task),
   `minigame_layout`, `script_documentation` and `viewport_editability`.
6. **Look at it once.** Use the memory recipe `popup-screenshot-harness` to
   render the scene at 1080×1920 and 1080×2400 with the baked theme, or run
   the game with Debug → minigame launcher. Check three things:
   - the strip sits below the top safe margin and nothing overlaps it;
   - the tray or hint sits at the bottom;
   - on 2400 the extra height goes to the field.
7. **Commit** with scope `feat(<game>)`.

The `Safe` block alone does not fill the screen's width for its children;
put a `UI` Control or a `Column` VBoxContainer under it, as each task
says. `SafeAreaMargin` adds the 48px screen margin and any device inset
itself.

---

### Task 9: PilihanGanda

**Files:** `Scenes/Minigames/Akademis/PilihanGanda.tscn`,
`Scripts/Minigames/Akademis/PilihanGanda.gd`, `tests/test_minigame_layout.gd`

**Target tree:**

```
PilihanGanda (root, how_to = PilihanGanda.tres)
├─ Background, Light, Shafts, Bloom        (unchanged)
└─ Safe (SafeAreaMargin)
   └─ Column (VBoxContainer, separation 24, mouse_filter 2)
      ├─ MinigameHeader  (instance, unique)
      ├─ SoalCard        (moved from VBoxContainer; unique_name_in_owner = true)
      ├─ Spacer          (moved; size_flags_vertical = 3)
      └─ MinigameTray    (instance, unique; hint_text = "Ketuk jawaban yang benar")
         └─ ChoicesGrid  (moved from VBoxContainer; unique; columns = 1)
```

Delete: `VBoxContainer` (after moving its children out) and
`VBoxContainer/ScoreHUD`.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const LayoutFrame := preload("res://tests/layout_frame.gd")
const PG := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"


## `node` sits under a SafeAreaMargin.
func _under_safe(node: Node) -> bool:
	var p := node.get_parent() if node != null else null
	while p != null and not (p is SafeAreaMargin):
		p = p.get_parent()
	return p != null


func _scene(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	track(root)
	return root


func test_pilihan_ganda_is_laid_out_in_three_bands() -> void:
	var root := _scene(PG)
	var header := root.get_node_or_null("%MinigameHeader")
	var tray := root.get_node_or_null("%MinigameTray")
	assert_true(_under_safe(header), "the strip is inside the safe area")
	assert_true(_under_safe(tray), "the tray is inside the safe area")
	var grid := root.get_node_or_null("%ChoicesGrid")
	assert_true(grid != null and grid.get_parent() == tray, "the answers live in the tray")
	assert_eq(String(root.how_to.resource_path), "res://Resources/Minigames/HowTo/PilihanGanda.tres")


func test_pilihan_ganda_answers_are_in_thumb_reach() -> void:
	var frame := track(LayoutFrame.stand_up(PG, Vector2(1080, 1920))) as Control
	var tray := frame.get_child(0).get_node("%MinigameTray") as Control
	assert_true(tray.get_global_rect().position.y >= 1920.0 * 0.45,
		"the tray starts in the bottom 55% of the frame")


func test_pilihan_ganda_no_longer_writes_the_badge() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_false(src.contains("Pertanyaan %d dari %d"), "the long badge rewrite is gone")
	assert_contains(src, "set_progress(")
```

- [ ] **Step 2: Run them and check they fail.**

- [ ] **Step 3: Scene.** Apply the target tree (recipe step 2).
  - The `ChoicesGrid` block becomes
    `parent="Safe/Column/MinigameTray"`, gains `unique_name_in_owner = true`
    and keeps its `h_separation`/`v_separation` overrides (layout
    constants).
  - `SoalCard` becomes `parent="Safe/Column"`, gains
    `unique_name_in_owner = true` and keeps its other lines.
  - The header instance:

  ```ini
  [node name="MinigameHeader" parent="Safe/Column" instance=ExtResource("<header id>")]
  unique_name_in_owner = true
  layout_mode = 2
  ```

  - The tray instance:

  ```ini
  [node name="MinigameTray" parent="Safe/Column" instance=ExtResource("<tray id>")]
  unique_name_in_owner = true
  layout_mode = 2
  hint_text = "Ketuk jawaban yang benar"
  ```

- [ ] **Step 4: Script.** In `Scripts/Minigames/Akademis/PilihanGanda.gd`:
  - Line 160: `@onready var score_hud: MinigameScoreHUD = $VBoxContainer/ScoreHUD`
    becomes `@onready var score_hud: MinigameHeader = %MinigameHeader`. The
    header forwards `setup`/`set_score`.
  - Line 169: `choices_container = $VBoxContainer/ChoicesGrid` becomes
    `choices_container = %ChoicesGrid`. `soal_card` becomes `%SoalCard`
    wherever it is looked up by path.
  - Lines 284–287: replace the portrait/landscape column choice with
    `choices_container.columns = 1`. The spec keeps one column.
  - Line 251: replace `progress_label.text = "Soal %d/%d" % [...]` with:

    ```gdscript
    	set_progress(current_question_index, active_questions.size(),
    		"Soal %d/%d" % [current_question_index + 1, active_questions.size()])
    	if status_badge:
    		status_badge.hide()
    ```

  - Line 443: delete the `"Pertanyaan %d dari %d | Skor: %d"` line.
  - The badge no longer reserves room, so pass `null` as SoalFit's badge
    argument at line 257: replace `status_badge` in that `SoalFit.font_size`
    call with `null`.
  - In `_on_choice_pressed`, inside `if index == expected_answer_index:`
    after `score += 1`, add:

    ```gdscript
    		if score == 1:
    			hint_settle()
    ```

  - After the last answer, fill the bar: where the script advances past the
    final question (it calls `win_game()`/`lose_game()` or equivalent), add
    first:
    `set_progress(active_questions.size(), active_questions.size(), "Soal %d/%d" % [active_questions.size(), active_questions.size()])`.

- [ ] **Step 5: Tests.** Run the suites `minigame_layout`,
`minigame_typography` and `minigame_score_hud`.
  - `minigame_typography` asserts `PilihanGanda.tscn` contains
    `QuestionCard.tscn`, `name="SoalCard"` and `name="Spacer"`. Those still
    hold.
  - `minigame_score_hud`'s `test_every_scoring_minigame_mounts_the_shared_hud`
    now fails for PilihanGanda, because the scene holds `MinigameHeader.tscn`.
    Update the test so that it passes when the scene contains either
    `"MinigameScoreHUD.tscn"` or `"MinigameHeader.tscn"`:

  ```gdscript
  		assert_true(src.contains("MinigameScoreHUD.tscn") or src.contains("MinigameHeader.tscn"),
  			"%s instances the shared HUD (directly or through the header)" % path)
  ```

- [ ] **Step 6: Look at it, then commit.**

```bash
git commit -F msg.txt   # feat(pilihan-ganda): the strip, the answer tray and the progress bar
```

---

### Task 10: Password and Variabel

**Files:** both `.tscn`/`.gd` under `Akademis/`, `tests/test_minigame_layout.gd`,
`tests/test_kalkulator.gd`, `tests/test_button_roles_phase3.gd`

**Target tree (identical in both):**

```
Password | Variabel (root, how_to = <Game>.tres)
├─ Background, Light, Shafts, Bloom
└─ Safe
   └─ Column (VBoxContainer, separation 24, mouse_filter 2)
      ├─ MinigameHeader  (unique)
      ├─ SoalCard        (moved; unique; custom_minimum_size = Vector2(760, 0);
      │                   size_flags_horizontal = 4; drop its anchor/offset lines)
      ├─ KalkulatorSlot  (moved; size_flags_vertical = 3; drop its anchor lines)
      │  └─ Kalkulator   (unchanged; unique_name_in_owner = true)
      └─ MinigameTray    (unique; hint_text: Password "Ketik jawaban, lalu Kirim",
         │                Variabel "Cari nilai hurufnya, lalu Kirim")
         └─ AksiRow      (moved; drop its anchor lines; keep separation)
            ├─ BtnHapus  (unique; SecondaryButtonM, "Hapus")
            └─ BtnKirim  (unique; LobbyCtaButton → PrimaryButtonM, "Kirim")
```

Delete: `HeaderRow` and `HeaderRow/ScoreHUD`.

`BtnKirim` moves from `LobbyCtaButton` (the 64px Lobby hero) to
`PrimaryButtonM`: it is still mint and the main action, at the tray's
size.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const KALK_GAMES: Array[String] = ["res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn"]


func test_the_calculator_games_share_one_layout() -> void:
	for path: String in KALK_GAMES:
		var root := _scene(path)
		assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")), path + " strip")
		var tray := root.get_node_or_null("%MinigameTray")
		assert_true(_under_safe(tray), path + " tray")
		var kirim := root.get_node_or_null("%BtnKirim") as Button
		assert_true(kirim != null and kirim.get_parent().get_parent() == tray,
			path + ": Hapus/Kirim ride in the tray")
		assert_eq(kirim.theme_type_variation, &"PrimaryButtonM", path + ": Kirim is mint, tray-sized")
		assert_true(root.get_node_or_null("HeaderRow") == null, path + ": the old header row is gone")
```

- [ ] **Step 2: Run it and check it fails.**

- [ ] **Step 3: Scenes.** Apply the target tree to both.
  - In `Password.tscn`, also make sure `tutorial_title` and
    `tutorial_instructions` are gone (Task 8 removed them).
  - Keep Variabel's `show_zero_key = false` on its `Kalkulator` block.

- [ ] **Step 4: Scripts.** In both `Password.gd` and `Variabel.gd`:

| Old | New |
|---|---|
| `$HeaderRow/ScoreHUD` (type `MinigameScoreHUD`) | `%MinigameHeader` (type `MinigameHeader`) |
| `$SoalCard/StatusBadge/BadgeLabel` | `%SoalCard/StatusBadge/BadgeLabel` |
| `$SoalCard/VBox/TextLabel` | `%SoalCard/VBox/TextLabel` |
| `$KalkulatorSlot/Kalkulator` | `%Kalkulator` |
| `$AksiRow/BtnHapus` | `%BtnHapus` |
| `$AksiRow/BtnKirim` | `%BtnKirim` |
| `get_node_or_null("SoalCard/StatusBadge")` | `get_node_or_null("%SoalCard/StatusBadge")` |

  - In `_update_progress()` (Password :186, Variabel :320), replace the
    `progress_label.text = "Soal %d/%d" % [...]` line with:

    ```gdscript
    	set_progress(current_question_index, active_questions.size(),
    		"Soal %d/%d" % [current_question_index + 1, active_questions.size()])
    	var badge := get_node_or_null("%SoalCard/StatusBadge") as Control
    	if badge:
    		badge.hide()
    ```

  - Wherever `SoalFit.font_size(...)` receives the badge, pass `null`
    instead.
  - Put `if score == 1: hint_settle()` in each correct branch: Password
    `_on_enter_pressed` after `score += 1` (:233), Variabel
    `_on_submit_pressed` after `score += 1` (:351).

- [ ] **Step 5: Update the pinned paths.**
  - `grep -n "AksiRow\|HeaderRow\|LobbyCtaButton" tests/test_kalkulator.gd tests/test_button_roles_phase3.gd`.
  - Every `AksiRow/BtnHapus` / `AksiRow/BtnKirim` path becomes
    `Safe/Column/MinigameTray/AksiRow/BtnHapus` and `…/BtnKirim`.
  - `test_kalkulator`'s "exactly one LobbyCtaButton" assertion becomes
    "exactly one PrimaryButtonM", and the `test_button_roles_phase3`
    assertion that `BtnKirim` is `LobbyCtaButton` becomes `PrimaryButtonM`.
    Both keep their role meaning: mint, main action.

- [ ] **Step 6: Tests.** Run the suites `minigame_layout`, `kalkulator`,
`button_roles_phase3`, `minigame_score_hud` and `minigame_typography`.
Expected: PASS.

- [ ] **Step 7: Look at it, then commit.**
`feat(kalkulator): Password and Variabel on the strip and the tray`

---

### Task 11: Menjodohkan

**Files:** `Scenes/Minigames/Akademis/Menjodohkan.tscn`,
`Scripts/Minigames/Akademis/Menjodohkan.gd`, `tests/test_minigame_layout.gd`

**Target tree:**

```
Menjodohkan (root, how_to = Menjodohkan.tres)
├─ Background, Light, Shafts, Bloom
└─ Safe
   └─ Column (VBoxContainer, separation 16, mouse_filter 2)
      ├─ MinigameHeader   (unique)
      ├─ TopCarousel      (moved; drop its anchors; size_flags_vertical = 3)
      │  ├─ TopHeaderLabel   text = "SOAL"
      │  ├─ QuestionWheelParent
      │  ├─ BtnPrevQ  text = ""  + child Arrow (chevron_left)
      │  └─ BtnNextQ  text = ""  + child Arrow (chevron_right)
      └─ MinigameTray     (unique; hint_text = "Pilih jawaban, lalu tekan Kunci")
         ├─ BottomCarousel   (moved; drop anchors; custom_minimum_size = Vector2(0, 520))
         │  ├─ BottomHeaderLabel  text = "JAWABAN"
         │  ├─ AnswerWheelParent
         │  ├─ BtnPrevA / BtnNextA   text = "" + Arrow children
         └─ ActionRow (was MiddleActionBar; drop anchors, z_index; keep separation)
            ├─ BtnLock    SecondaryButtonM, text = "Kunci"
            └─ BtnSubmit  PrimaryButtonM,   text = "Selesai", disabled = true
```

- Delete `HeaderVBox`, `HeaderVBox/TitleLabel`, `HeaderVBox/ScoreHUD` and
  `HeaderVBox/ProgressHBox`.
- Delete the `StyleBoxFlat_nav_btn` sub_resource, and the nav buttons'
  `theme_override_styles/normal` and `theme_override_font_sizes` lines. The
  four nav buttons take `theme_type_variation = &"SecondaryButton"` and a
  `custom_minimum_size = Vector2(96, 96)`.
- Each gets an `Arrow` child, like the house paging arrows:

```ini
[node name="Arrow" type="TextureRect" parent="Safe/Column/TopCarousel/BtnPrevQ"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 24.0
offset_top = 24.0
offset_right = -24.0
offset_bottom = -24.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("<chevron_left id>")
expand_mode = 1
stretch_mode = 5
script = ExtResource("<ButtonGlyph id>")
```

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const MJ := "res://Scenes/Minigames/Akademis/Menjodohkan.tscn"
const MJ_GD := "res://Scripts/Minigames/Akademis/Menjodohkan.gd"


func test_menjodohkan_answers_and_actions_live_in_the_tray() -> void:
	var root := _scene(MJ)
	var tray := root.get_node_or_null("%MinigameTray")
	assert_true(_under_safe(tray), "tray in the safe area")
	for n: String in ["BottomCarousel", "ActionRow"]:
		var c := root.get_node_or_null("Safe/Column/MinigameTray/" + n)
		assert_true(c != null, n + " rides in the tray")
	assert_true(root.get_node_or_null("HeaderVBox") == null, "title and badge row are gone")


func test_menjodohkan_text_has_no_swipe_captions_or_emoji() -> void:
	var scene := FileAccess.get_file_as_string(MJ)
	var src := FileAccess.get_file_as_string(MJ_GD)
	assert_false(scene.contains("GESER / SWIPE"))
	for glyph: String in ["🔒", "🔓", "✨", "⚪", "✅", "❌", "◀", "▶"]:
		assert_false(scene.contains(glyph) or src.contains(glyph), glyph + " is gone")


func test_menjodohkan_reports_pairs_on_the_bar() -> void:
	assert_contains(FileAccess.get_file_as_string(MJ_GD), "\"Pasangan %d/%d\"")
```

- [ ] **Step 2: Run them and check they fail.**

- [ ] **Step 3: Scene.** Apply the target tree. Add ext_resources for
`chevron_left.svg`, `chevron_right.svg` and `Scripts/UI/ButtonGlyph.gd`.

- [ ] **Step 4: Script edits** in `Scripts/Minigames/Akademis/Menjodohkan.gd`:
  1. **`@onready` block (:180–196).**
     - Delete `title_label`, `progress_hbox` and their uses in
       `_apply_visual_exports` (:215–225).
     - `score_hud` becomes `@onready var score_hud: MinigameHeader = %MinigameHeader`.
     - `$MiddleActionBar…` becomes `$Safe/Column/MinigameTray/ActionRow…`.
     - `$TopCarousel…` becomes `$Safe/Column/TopCarousel…`.
     - `$BottomCarousel…` becomes `$Safe/Column/MinigameTray/BottomCarousel…`.
  2. **Delete `_build_progress_badges()`** (:389–413), its call (:370), the
     `progress_hbox` clearing in `_clear_containers()` (:383),
     `_update_badge_status()` (:804–806) and **every** call to it (:747,
     760, 855, 870, 892), and the `progress_badges` var (:162). Also delete
     the badge-related `@export`s (`badge_font_size`,
     `badge_default_color`, `badge_locked_texture`, and any other
     `badge_*`) and their `##` lines. `grep -n "badge_" Menjodohkan.gd`
     must then only hit `StatusBadge` card lookups.
  3. **`_update_score_ui()` (:510)** becomes:

     ```gdscript
     func _update_score_ui() -> void:
     	if score_hud:
     		score_hud.set_score(locked_matches.size())
     	set_progress(locked_matches.size(), questions_count,
     		"Pasangan %d/%d" % [locked_matches.size(), questions_count])
     ```

  4. **`_update_action_bar_ui()` (:514–570).**
     - The lock button's text becomes `"Batalkan"` when the pair is locked
       and `"Kunci"` otherwise, with no emoji.
     - Replace the `&"DangerButton"` at :532 and the `&"PrimaryButton"` at
       :551 with `&"SecondaryButtonM"`: both are neutral, since Batalkan is
       a reversible clear.
     - Delete the font and colour overrides at :525–528, 542, 545–548 and
       561–565.
  5. **First lock settles the hint.** In `_on_btn_lock_pressed`, after
     `locked_matches[current_q_focus] = current_a_focus` (:757), add
     `if locked_matches.size() == 1: hint_settle()`.
  6. **Fit the cards to their wheel** (the 960px AnswerCard overflowed a
     ~538px slot). In `_animate_wheel`, after `var card = cards[i]`, add:

     ```gdscript
     		var fit := minf(1.0, maxf(10.0, container_h - 18.0) / maxf(1.0, card.size.y))
     ```

     Then change the two scale targets to use it:

     ```gdscript
     		var target_scale = Vector2(fit, fit) if distance == 0 else Vector2(card_side_scale * fit, card_side_scale * fit)
     ```

     Because the pivot is the card's centre (`card.pivot_offset = card.size / 2.0`),
     the centring math stays as it is.
  7. **The viewport resize handler (:266–269)** stays. The carousel sizes
     now come from the container.

- [ ] **Step 5: Tests.** Run the suites `minigame_layout`,
`minigame_typography`, `minigame_score_hud` and `viewport_editability`.
  - Deleting `_build_progress_badges` removes Menjodohkan's `PanelContainer.new()`,
    `StyleBoxFlat.new()` and `Label.new()`. Lower its `BASELINE` in
    `test_viewport_editability.gd` to the number the failure message
    prints.
  - `minigame_typography` pins the headers' `MinigameWheelHeaderWarm/Cool`
    variations, which stay on `TopHeaderLabel`/`BottomHeaderLabel`.

- [ ] **Step 6: Look at it, both a question with a picture and one
without, then commit.**
`feat(menjodohkan): answers and actions in the tray; pairs on the bar`

---

### Task 12: BuatBatik

**Files:** `Scenes/Minigames/SeniBudaya/BuatBatik.tscn`,
`Scripts/Minigames/SeniBudaya/BuatBatik.gd`, `tests/test_minigame_layout.gd`,
`tests/test_minigame_art.gd`

**Target tree:**

```
BuatBatik (root, how_to = BuatBatik.tres)
├─ Background, Light, Bloom
├─ TooltipPanel         (unchanged, stays a root child: it follows the finger)
└─ Safe
   └─ Column (VBoxContainer, separation 24, mouse_filter 2)
      ├─ MinigameHeader  (unique; show_score = false; segmented = true)
      ├─ CanvasRect      (moved; drop anchors; size_flags_vertical = 3)
      │  ├─ CanvasBackground, LayersContainer   (unchanged)
      └─ MinigameTray    (unique; hint_text = "Seret Pensil ke kanvas")
         └─ ToolsContainer (moved; drop anchors; keep separation/alignment)
            └─ Tool0..Tool3 (unchanged)
```

Delete: `TitleLabel`, `InstructionLabel` and `CanvasRect/ProgressStepsLabel`.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const BATIK := "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"
const BATIK_GD := "res://Scripts/Minigames/SeniBudaya/BuatBatik.gd"


func test_batik_tools_live_in_the_tray_and_the_title_is_gone() -> void:
	var root := _scene(BATIK)
	assert_true(root.get_node_or_null("Safe/Column/MinigameTray/ToolsContainer/Tool0") != null)
	for gone: String in ["TitleLabel", "InstructionLabel", "CanvasRect/ProgressStepsLabel"]:
		assert_true(root.get_node_or_null(gone) == null, gone + " is gone")
	var header := root.get_node("%MinigameHeader") as MinigameHeader
	assert_false(header.show_score, "Batik has no score pill")
	assert_true(header.segmented, "the bar reads as four steps")


func test_batik_names_the_next_step_in_the_hint() -> void:
	var src := FileAccess.get_file_as_string(BATIK_GD)
	assert_contains(src, "show_hint(")
	assert_contains(src, "\"Langkah %d/%d\"")
	for glyph: String in ["🔧", "🟨", "✅", "❌", "⬜"]:
		assert_false(src.contains(glyph), glyph + " is gone")
```

- [ ] **Step 2: Run them and check they fail.**

- [ ] **Step 3: Scene.** Apply the target tree.

- [ ] **Step 4: Script edits** in `BuatBatik.gd`:
  1. **Delete** the `@onready` refs to `title_label`, `instruction_label`
     and `progress_steps_label`, and their override blocks (:249–261). Also
     delete the exports `title_font_size`, `instruction_font_size`,
     `title_font_color`, `instruction_font_color` and `progress_font_size`,
     and their `##` lines.
  2. **Add the Indonesian tool names** in `correct_sequence` order:

     ```gdscript
     ## The hint's name for each tool, in correct_sequence order.
     const STEP_TOOL_NAMES := ["Pensil", "Canting", "Pewarna", "Kompor"]
     ```

  3. **Replace `_update_progress_label()` (:722–734)** with:

     ```gdscript
     ## The bar counts placed tools; the hint names the next one.
     func _update_progress_label() -> void:
     	var done := player_sequence.size()
     	var total := correct_sequence.size()
     	set_progress(done, total, "Langkah %d/%d" % [mini(done + 1, total), total])
     	if done < total:
     		show_hint("Seret %s ke kanvas" % STEP_TOOL_NAMES[done])
     ```

     Keep its four call sites.
  4. **Wrong order.** In `_check_tool_drop`'s wrong branch (:455–463), after
     `_add_wrong_layer(step)`, add `show_hint("Urutan salah!")`. The next
     `_update_progress_label()` call restores the step hint.
  5. **First correct tool.** In the correct branch (:449–453), after
     `player_sequence.append(...)`, add
     `if player_sequence.size() == 1: hint_settle()`.
  6. **Tooltip prefix.** At :349, `"🔧 " + tool_name_str` becomes
     `tool_name_str`.
  7. **`_ready` (:147–148)** still calls `start_minigame(1, 30.0)` when
     standalone. Leave it.

- [ ] **Step 5: Tests.** Run the suites `minigame_layout`,
`minigame_art`, `minigame_typography` and `viewport_editability`.
  - `minigame_art` pins `ToolsContainer/ToolN/ToolTextureRect`. Update that
    path to `Safe/Column/MinigameTray/ToolsContainer/ToolN/ToolTextureRect`.
  - `minigame_typography` pins BuatBatik's `MinigameOverlayLabel`, which is
    still used by the layer labels. Keep it.
  - The ratchet count does not change: the layer labels stay per-call
    dynamic.

- [ ] **Step 6: Look at it, including the drag ghost and the tooltip over
the tray, then commit.**
`feat(buat-batik): tools in the tray, steps on the bar, the next tool in the hint`

---

### Task 13: MainBola

**Files:** `Scenes/Minigames/Olahraga/MainBola.tscn`,
`Scripts/Minigames/Olahraga/MainBola.gd`, `tests/test_minigame_layout.gd`

**Target tree.** Every play node stays a direct child of the root;
`test_main_bola_layout.gd` pins that.

```
MainBola (root, how_to = MainBola.tres)
├─ FieldBG, Light, Shafts, Bloom, FieldMarkings, Goal*, GoalArea, TargetBox, Goalie, Ball  (unchanged)
└─ Safe
   └─ UI (Control, mouse_filter 2)
      ├─ MinigameHeader    (unique; layout_mode 1, anchors_preset 10, anchor_right 1)
      └─ MinigameHintPill  (unique; icon_texture = swipe_up.svg;
                            hint_text = "Geser ke atas untuk menendang")
```

Delete: `HUDLayer`, `HUDLayer/AttemptsLabel`, `HUDLayer/SwipeHint` and
`HUDLayer/ScoreHUD`. Leave the dead `Goal*` ColorRects: removing them is
Part 1's job, and `test_main_bola_layout` pins them.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const BOLA := "res://Scenes/Minigames/Olahraga/MainBola.tscn"
const BOLA_GD := "res://Scripts/Minigames/Olahraga/MainBola.gd"


func test_main_bola_has_the_strip_and_the_hint_pill() -> void:
	var root := _scene(BOLA)
	assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")))
	assert_true(_under_safe(root.get_node_or_null("%MinigameHintPill")))
	assert_true(root.get_node_or_null("HUDLayer") == null, "the bespoke HUD layer is gone")


func test_main_bola_speaks_indonesian() -> void:
	var src := FileAccess.get_file_as_string(BOLA_GD) + FileAccess.get_file_as_string(BOLA)
	for english: String in ["Shots Left", "Swipe Up to Shoot"]:
		assert_false(src.contains(english), english + " is gone")
	assert_contains(src, "\"Tendangan %d/%d\"")
```

- [ ] **Step 2: Run them and check they fail.**

- [ ] **Step 3: Scene.** Apply the target tree. The header block:

```ini
[node name="MinigameHeader" parent="Safe/UI" instance=ExtResource("<header id>")]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 160.0
grow_horizontal = 2
```

The pill block:

```ini
[node name="MinigameHintPill" parent="Safe/UI" instance=ExtResource("<pill id>")]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_bottom = -24.0
grow_horizontal = 2
grow_vertical = 0
hint_text = "Geser ke atas untuk menendang"
icon_texture = ExtResource("<swipe_up id>")
```

- [ ] **Step 4: Script edits** in `MainBola.gd`:
  1. `:193` becomes `@onready var score_hud: MinigameHeader = %MinigameHeader`.
     Delete `attempts_label` and `swipe_hint` (:194–195).
  2. `_update_hud()` (:600) becomes:

     ```gdscript
     func _update_hud() -> void:
     	if score_hud:
     		score_hud.set_score(score)
     	var taken := max_attempts - attempts_left
     	set_progress(taken, max_attempts,
     		"Tendangan %d/%d" % [mini(taken + 1, max_attempts), max_attempts])
     ```

     This deletes every `attempts_label`/`swipe_hint` override (:604–615).
  3. `:659–661` (fading `swipe_hint`) becomes `hint_settle()`: the first
     shot settles the hint.
  4. `_notification` (:264) keeps re-running the layout on resize. The
     field layout reads the root's `size`, so the new `Safe` child does
     not move it.

- [ ] **Step 5: Tests.** Run the suites `minigame_layout`,
`main_bola_layout`, `main_bola_shots`, `main_bola_targets` and
`viewport_editability`. Expected: PASS.

- [ ] **Step 6: Look at it** (a shot, then the bar), **then commit.**
`feat(main-bola): the strip and an Indonesian swipe hint replace the English HUD`

---

### Task 14: Badminton

**Files:** `Scenes/Minigames/Olahraga/Badminton.tscn`,
`Scripts/Minigames/Olahraga/Badminton.gd`, `tests/test_minigame_layout.gd`,
`tests/test_minigame_typography.gd`

**Target tree.** The physics bodies stay root children, and `Background`
stays index 0 (`test_badminton_visuals` pins it).

```
Badminton (root, how_to = Badminton.tres)
├─ Background (+ stretch_mode = 6), Light, Shafts, Bloom, Puck, PlayerPaddle, EnemyPaddle, goals, walls
└─ Safe
   └─ UI (Control, mouse_filter 2)
      ├─ MinigameHeader   (unique; show_timer = false; top-wide as in Task 13)
      └─ MinigameHintPill (unique; hint_text = "Geser pemukulmu")
```

Delete: the root-level `ScoreHUD`.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const BADMINTON := "res://Scenes/Minigames/Olahraga/Badminton.tscn"


func test_badminton_has_the_strip_the_pill_and_a_covering_court() -> void:
	var root := _scene(BADMINTON)
	assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")))
	assert_true(_under_safe(root.get_node_or_null("%MinigameHintPill")))
	assert_eq((root.get_node("Background") as TextureRect).stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED, "the court covers, never stretches")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/Minigames/Olahraga/Badminton.gd"),
		"\"Poin %d/%d\"")
```

- [ ] **Step 2: Run it and check it fails.**

- [ ] **Step 3: Scene.** Apply the target tree, and add
`stretch_mode = 6` to `Background`.

`tests/test_minigame_typography.gd` asserts `Badminton.tscn` contains
`anchor_left = 0.5` and not `offset_left = 390.0`. The pill carries
`anchor_left = 0.5`, so that still passes. If it fails, change the
assertion to check that `ScoreHUD` is no longer a root child.

- [ ] **Step 4: Script edits** in `Badminton.gd`:
  1. `:73` becomes `@onready var score_hud: MinigameHeader = %MinigameHeader`.
  2. `_update_score_ui()` (:586) becomes:

     ```gdscript
     func _update_score_ui() -> void:
     	if score_hud:
     		score_hud.set_label_text("%d - %d" % [enemy_score, player_score])
     	set_progress(player_score, target_score, "Poin %d/%d" % [player_score, target_score])
     ```

  3. **First clean return.** In `_on_puck_body_entered` (:255), inside the
     paddle branch, add this at the top of the branch:

     ```gdscript
     		if body == player_paddle and not _hint_settled:
     			_hint_settled = true
     			hint_settle()
     ```

     with `var _hint_settled := false` declared beside `player_score`.

- [ ] **Step 5: Tests.** Run the suites `minigame_layout`,
`badminton_visuals`, `minigame_typography`, `minigame_score_hud` and
`viewport_editability`. Expected: PASS.

- [ ] **Step 6: Look at it** at 1080×2400: check that the court lines still
line up with the walls, since covering may crop its sides. **Then commit.**
If the crop visibly misaligns the court, record it in `DEBT.md` under the
Badminton court entry. Do not revert the cover.
`feat(badminton): the strip, the hint pill and a court that covers tall phones`

---

### Task 15: LombaMenari

**Files:** `Scenes/Minigames/SeniBudaya/LombaMenari.tscn`,
`Scripts/Minigames/SeniBudaya/LombaMenari.gd`, `tests/test_minigame_layout.gd`

**Target tree.** `Background` < `CharacterDisplay` < `HitZone` <
`NotesParent` stay root siblings in that order (`test_lomba_menari_timing`).

```
LombaMenari (root, how_to = LombaMenari.tres)
├─ Background, Light, Shafts, Bloom, CharacterDisplay, HitZone, NotesParent  (unchanged)
└─ Safe
   └─ UI (Control, mouse_filter 2)
      ├─ MinigameHeader   (unique; show_timer = false; top-wide)
      └─ MinigameHintPill (unique; hint_text = "Geser searah panah")
```

Delete: the root-level `ScoreHUD`. Leave `Background`'s offsets alone: that
fix belongs to Part 1 Phase 5, and it interacts with the dance camera's
`background_rest_position`.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
const MENARI := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"
const MENARI_GD := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"


func test_menari_has_the_strip_and_the_pill() -> void:
	var root := _scene(MENARI)
	assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")))
	assert_true(_under_safe(root.get_node_or_null("%MinigameHintPill")))
	assert_true(root.get_node_or_null("ScoreHUD") == null, "the off-centre HUD is gone")


func test_menari_shows_lives_on_the_bar_and_warnings_in_the_pill() -> void:
	var src := FileAccess.get_file_as_string(MENARI_GD)
	assert_contains(src, "\"Nyawa %d/%d\"")
	assert_contains(src, "show_hint(miss_text(")
```

- [ ] **Step 2: Run them and check they fail.**

- [ ] **Step 3: Scene.** Apply the target tree.

- [ ] **Step 4: Script edits** in `LombaMenari.gd`:
  1. `:247` becomes `@onready var score_hud: MinigameHeader = %MinigameHeader`.
     The `set_score`/`set_combo` calls forward unchanged.
  2. Add a helper beside `miss_text`:

     ```gdscript
     ## The strip's lives bar: misses left of the grade's limit.
     func _update_lives() -> void:
     	var left := maxi(0, miss_limit - missed_notes)
     	set_progress(left, miss_limit, "Nyawa %d/%d" % [left, miss_limit])
     ```

     Call it at the end of `start_minigame` (after `score_hud.setup`, :318)
     and after each `missed_notes += 1` (:410).
  3. **The miss warning moves to the pill.** At `:423`, keep
     `_show_hit_feedback(...)` for the grade burst. Then, when
     `misses_left` is inside the warning window
     (`0 < misses_left <= MISS_WARN_REMAINING`), also call
     `show_hint(miss_text(misses_left))`. Keep the
     `misses_left -= 1` / `miss_text(misses_left)` order that
     `test_lomba_menari_misses` pins (:84).
  4. **First good hit.** In `_evaluate_swipe`, inside
     `if grade != Grade.UPS:` (:589), add
     `if score_hud and current_combo == 1: hint_settle()`. The first combo
     step is the first good hit.

- [ ] **Step 5: Tests.** Run the suites `minigame_layout`,
`lomba_menari_timing`, `lomba_menari_misses`, `lomba_menari_arrow`,
`minigame_art` and `minigame_score_hud`. Expected: PASS.

- [ ] **Step 6: Look at it** (miss three notes to see the pill warning),
**then commit.**
`feat(lomba-menari): the strip with a lives bar; miss warnings in the hint pill`

---

### Task 16: Retire the legacy chrome, bring minigames under the glyph rule, docs

**Files:** `Scripts/Minigames/UI/BaseMinigame.gd`,
`tests/test_ui_text_glyphs.gd`, `tests/test_viewport_editability.gd`,
`tests/test_minigame_layout.gd`, `tests/test_tall_screen_layout.gd`,
`docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`, `CLAUDE.md`

- [ ] **Step 1: Write the failing tests.** Append to
`tests/test_minigame_layout.gd`:

```gdscript
const ALL_GAMES: Array[String] = [
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
	"res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn",
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn",
	"res://Scenes/Minigames/Olahraga/MainBola.tscn",
	"res://Scenes/Minigames/Olahraga/Badminton.tscn",
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
]
## Which bottom piece each game uses (spec 4).
const TRAY_GAMES: Array[int] = [0, 1, 2, 3, 4]


func test_every_game_has_the_strip_a_bottom_piece_and_a_card() -> void:
	for i in ALL_GAMES.size():
		var path := ALL_GAMES[i]
		var root := _scene(path)
		assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")), path + ": strip")
		var bottom := "%MinigameTray" if i in TRAY_GAMES else "%MinigameHintPill"
		assert_true(_under_safe(root.get_node_or_null(bottom)), path + ": " + bottom)
		assert_true(root.how_to != null, path + ": has a CARA MAIN card")


func test_base_minigame_builds_no_chrome() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	for gone: String in ["_create_pause_button", "_create_visual_timer",
			"_on_visual_timer_draw", "TextureButton.new()"]:
		assert_false(src.contains(gone), gone + " is retired: the strip is in every scene")


func test_every_game_fills_a_tall_phone() -> void:
	for i in ALL_GAMES.size():
		var frame := track(LayoutFrame.stand_up(ALL_GAMES[i], Vector2(1080, 2400))) as Control
		var root := frame.get_child(0)
		var strip := root.get_node("%MinigameHeader") as Control
		assert_true(strip.get_global_rect().position.y <= 60.0,
			ALL_GAMES[i] + ": the strip rides the top edge")
		var bottom := root.get_node("%MinigameTray" if i in TRAY_GAMES else "%MinigameHintPill") as Control
		assert_true(bottom.get_global_rect().end.y >= 2400.0 - 80.0,
			ALL_GAMES[i] + ": the bottom piece rides the bottom edge")
```

**Memory `full-run-crash-is-message-queue-overflow`:** standing up eight
scenes in one test can flood deferred calls. If the full run crashes, move
the stand-ups into a `suite_setup()` fixture that stands each scene up once.

- [ ] **Step 2: Run them and check they fail.**
`test_base_minigame_builds_no_chrome` fails.

- [ ] **Step 3: Delete the legacy chrome** from `BaseMinigame.gd`:
  - `_create_pause_button()`, `_play_pause_button_boing_animation()`,
    `_create_visual_timer()`, `_on_visual_timer_draw()` and
    `_draw_circle_slice()`;
  - the vars `pause_button` and `visual_timer`;
  - the export `pause_button_texture`;
  - the `else:` legacy branch in `start_minigame`;
  - the `if visual_timer:` redraw in `_process`;
  - the `if pause_button:` blocks in `win_game`/`lose_game`/`abandon_game`.

  `_on_pause_button_pressed` now always calls `pause_minigame()` after its
  guards. Then:
  - Update the `##` header of `BaseMinigame.gd`: replace "Not covered by
    the design system…" with a sentence saying the chrome is the scene's
    `MinigameHeader` / `MinigameTray` / `MinigameHintPill`, found by unique
    name.
  - In `tests/test_viewport_editability.gd`, lower `BaseMinigame.gd`'s
    `BASELINE` to the count the failure message prints (expected 0; if so,
    delete the line).

- [ ] **Step 4: Bring minigames under the glyph rule.** In
`tests/test_ui_text_glyphs.gd`, change `SKIP_DIRS` to
`["res://Scripts/Debug"]`, and update the file's `##` header sentence
about the minigames' exception. Run `test_run(suite="ui_text_glyphs")`.
- Every remaining hit must be cleaned at its source.
- If a hit is typography allowed by the style guide, add it to `ALLOWED`
  with a comment.
- Known leftovers to check: Menjodohkan comments (allowed: comments are
  skipped) and `MinigameMenu.gd` (a debug launcher). If `MinigameMenu.gd`
  hits, add
  `"res://Scripts/Minigames/UI/MinigameMenu.gd": [<exact needle>]` to
  `ALLOWED`, commented "debug-only launcher, not player-facing".

- [ ] **Step 5: Docs.**
  - **`docs/superpowers/CHANGELOG.md`:** add a newest-first entry: "Minigame
    mobile layout (2026-09-29…)". Include one paragraph per shared piece,
    the per-game table from the spec, and the three decisions awaiting
    mentor sign-off.
  - **`docs/superpowers/DEBT.md`:**
    - Add the placeholder icons (`pause`, `timer`, `swipe_up`, the six
      `howto_*`), to be replaced by the owner's set.
    - Add the Badminton crop note, if Task 14 found one.
    - Add "Part 2 coordination: `ScorePill` → ×badge inside
      `MinigameScoreHUD`; Phase 8 re-scoped to key feel + LCD styling".
    - Delete any entry this pass resolved: "tutorial placeholder", MainBola
      English HUD, HUD position entries.
  - **`CLAUDE.md`:**
    - Replace the "Minigames … are explicitly **out of scope** for the
      design system…" sentence with: "Minigames share one layout (strip ·
      field · tray/hint pill, CARA MAIN card; spec
      `docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md`)
      and follow the glyph and popup rules; their inner play art still had
      no polish pass. The debug overlay is out of scope for the design
      system."
    - Update the suite count after the full run.
    - Keep the file under its 23,000-character budget.

- [ ] **Step 6: Full verification (controller).**
  - Close every scene except `Scenes/MainMenu/MainMenu.tscn`, then run a
    full `test_run(session_id=…)`. Budget one editor restart after it
    (CLAUDE.md, "A full test_run drops the bridge").
  - Expected: 0 failures.
  - Then `git status`: revert `default_bus_layout.tres` if it changed. Keep
    `kejartes_theme.tres` only if its diff is the intended bake.
  - Run each minigame once from the Debug launcher at the editor's run
    size. The Debug overlay's minigame launcher starts each one with
    `start_minigame` + `activate_minigame`. Check four things:
    1. CARA MAIN shows on first launch and not on the second.
    2. 3‑2‑1 plays with tutorials off.
    3. JEDA → Keluar → KELUAR? → "Tidak, lanjut main" returns to JEDA.
    4. The timer ring turns red in the last 5 s.

- [ ] **Step 7: Commit, then ship.**

```bash
git add -A
git commit -F msg.txt   # refactor(minigames): retire the code-built chrome; minigames under the glyph rule; docs
```

Then finish the branch with the `ship-pr` skill. It runs the full suite,
does a local review, opens the PR and stamps it. **Label the PR `hold`**:
it carries three decisions awaiting mentor sign-off (spec 9). Merge by hand
once they are signed off.
