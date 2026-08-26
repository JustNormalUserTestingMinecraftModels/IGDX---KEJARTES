# KEJARTES Core UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the core game loop (MainMenu → CutScene → StudentCard → Lobby → AturJadwal → SchoolDay → SemesterEnd) the visual polish, motion, and audio of a professional mobile game in the Umamusume UI idiom, with every style value centralized into inspector-editable resources.

**Architecture:** A single `DesignTokens` Resource (`.tres`, fully `@export`ed) is the one source of truth for every color, radius, spacing step, font size, and animation duration. A `ThemeFactory` builds a Godot `Theme` from those tokens; an `@tool` EditorScript bakes it to `kejartes_theme.tres`, which is registered project-wide via `gui/theme/custom`. Core scenes then have their ~920 `theme_override_*` properties and 235 inline StyleBoxes **stripped** so they inherit. Two autoloads carry the rest: `AudioDirector` (BGM/SFX with inspector-assignable stream slots) and `UIPolish` (auto-attaches press-pop + click SFX to every `BaseButton` in the tree). A static `Juice` class provides the tween vocabulary that scene scripts call.

**Tech Stack:** Godot 4.6 (Mobile renderer, d3d12), GDScript, `McpTestSuite` (from `addons/godot_ai/testing/`) for tests run via the `godot-ai` MCP `test_run` tool.

**Spec:** This document (decisions were captured interactively; see *Locked Decisions* below).

---

## Locked Decisions

These were confirmed by the user before planning. Do not revisit them.

1. **Assets:** Use free/open-license assets now (OFL fonts, CC0 SFX), structured so the user can swap in their own art/audio later by dropping files into a folder — **zero code changes required**.
2. **Theming:** **Full centralization.** One master Theme + a `DesignTokens` Resource. Strip `theme_override_*` from core scenes so they inherit.
3. **Visual direction:** **Umamusume UI language** (rounded cards, thick white borders, soft drop shadows, vertical gradient fills, high-saturation per-category accents, chunky outlined display text, glossy pill buttons) using **a palette proposed by Claude and approved by the user before any code is written**.
4. **Motion:** **Full juice pass** — button press-pop/release-bounce, staggered list entry, number count-up, per-screen transitions, stat-bar easing. **Haptic vibration is explicitly deferred** — do not implement it in this plan.
5. **Scope:** Core loop only. **All minigames are out of scope** (`Scenes/Minigames/**`, `Scripts/Minigames/**` are untouched except where a shared Theme changes their appearance incidentally).

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Godot version:** 4.6, `Mobile` renderer. Do not use Forward+/Compatibility-only APIs.
- **Target resolution:** 1080×1920 portrait. `window/stretch/mode="canvas_items"`, `aspect="expand"`. Layouts must survive aspect ratios from 9:16 to 9:21.
- **Language:** All user-facing strings are **Indonesian**. Never translate existing Indonesian UI text to English. New strings must be Indonesian (e.g. "Lanjut", "Kembali", "Pengaturan", "Mulai").
- **No hardcoded style values in new code.** Every color, radius, spacing, font size, and duration must come from `DesignTokens`. A literal `Color(...)` or magic pixel number in a script written after Task 2 is a defect.
- **Inspector-editability is a hard requirement.** Any value a designer might want to tune must be reachable as an `@export` in the inspector or a property on a `.tres`. Values that only exist as GDScript constants fail this requirement.
- **Fonts:** OFL-licensed only. Must cover the Indonesian Latin alphabet (basic ASCII + no special diacritics needed).
- **Audio:** CC0 only. License files must be committed alongside.
- **Out of scope:** `Scenes/Minigames/**`, `Scripts/Minigames/**`, `-REFERENCE-/**`, `addons/**`.
- **No haptics.** Deferred per user decision.
- **Every task ends with a commit.** The repo is not yet under version control — Task 0 fixes that.
- **Tests live in `res://tests/`**, subclass `McpTestSuite`, and are run with the `godot-ai` MCP `test_run` tool. Never claim a test passes without running it and reading the output.

---

## Palette (Proposed — requires approval in Task 1)

Derived from the colors already dominant in the codebase, lifted to Umamusume saturation. Full swatch artifact is produced in Task 1.

| Token | Hex | Rationale |
|---|---|---|
| `brand_primary` | `#2E5BFF` | Existing `Color(0.16, 0.27, 1.0)` (7 uses), lifted |
| `brand_primary_light` | `#6E8CFF` | Gradient top for primary buttons |
| `brand_primary_dark` | `#1B3ACC` | Pressed state / bottom bevel |
| `surface_page` | `#EEF3FF` | Cool paper background |
| `surface_card` | `#FFFFFF` | Card fill |
| `surface_overlay` | `#141A2E` | Modal scrim base (used at ~70% alpha) |
| `outline_card` | `#FFFFFF` | The Umamusume thick white rim |
| `text_primary` | `#1E2436` | From existing `Color(0.15,0.15,0.15)` (24 uses), cooled |
| `text_secondary` | `#6B7490` | Existing `Color(0.5,0.5,0.5)` / `(0.65,...)`, cooled |
| `text_on_brand` | `#FFFFFF` | |
| `cat_akademis` | `#3D8BFF` | Blue — study |
| `cat_olahraga` | `#FF7A45` | Orange — sport |
| `cat_senibudaya` | `#B45BFF` | Purple — batik/dance |
| `cat_istirahat` | `#3ECF7A` | Existing `Color(0.2,0.9,0.4)` (10 uses) |
| `cat_libur` | `#FFC93C` | Existing `Color(1.0,0.85,0.3)` (8 uses) |
| `state_success` | `#2FB86B` | Existing `Color(0.15,0.7,0.25)` |
| `state_warning` | `#FFB020` | |
| `state_danger` | `#E4453A` | Existing `Color(0.85,0.2,0.2)` |
| `currency_gold` | `#FFC93C` | Existing `Color(0.83,0.69,0.22)`, brightened |

**Typography (proposed):**
- Display / headings: **Fredoka** SemiBold (OFL) — chunky and rounded, closest open font to Umamusume's display face.
- Body / UI: **Nunito** (OFL) — rounded, highly legible at small sizes, wide weight range.

---

## File Structure

**New files, and what each is responsible for:**

| File | Responsibility |
|---|---|
| `Scripts/Design/DesignTokens.gd` | `Resource` subclass. Every `@export`ed style value. Zero logic beyond derived helpers. |
| `Scripts/Design/ThemeFactory.gd` | Pure function: `DesignTokens` → `Theme`. All StyleBox construction lives here. No file I/O. |
| `Scripts/Design/BakeTheme.gd` | `@tool EditorScript`. Loads tokens, calls factory, saves `.tres`. One-click rebuild. |
| `Scripts/Design/Juice.gd` | `class_name Juice`. Static tween vocabulary (pop, bounce, count-up, stagger, shake). Reads durations from tokens. |
| `Scripts/UI/UIPolish.gd` | Autoload. Watches `node_added`, auto-wires press-pop + click SFX onto every `BaseButton`. Opt-out via node meta. |
| `Scripts/UI/SafeAreaMargin.gd` | `MarginContainer` subclass that applies `DisplayServer.get_display_safe_area()` insets. |
| `Scripts/UI/StatBar.gd` | Reusable animated stat bar (`ProgressBar` subclass) with category tinting + count-up label. |
| `Scripts/Audio/AudioDirector.gd` | Autoload script. Bus setup, BGM crossfade, SFX pool, volume persistence. |
| `Scenes/Audio/audio_director.tscn` | Autoloaded scene so stream slots are inspector-assignable. |
| `Assets/Theme/design_tokens.tres` | The single source of truth. **This is the file designers edit.** |
| `Assets/Theme/kejartes_theme.tres` | Baked output. Never hand-edit. |
| `Assets/Fonts/` | OFL fonts + license. |
| `Assets/Audio/BGM/`, `Assets/Audio/SFX/` | CC0 audio + license. Drop-in replaceable. |
| `Scenes/UI/Settings.tscn`, `Scripts/UI/Settings.gd` | The Pengaturan screen the dead `SettingButton` should open. |
| `tests/*.gd` | `McpTestSuite` suites. |

**Modified:** `project.godot` (theme, autoloads, audio buses), `Scenes/Transition/transition.tscn` + `.gd`, and each of the 9 core scenes/scripts.

---

## Execution Order & Gates

Tasks 0–1 are prerequisites. Tasks 2–8 build the foundation and **must be done in order** — later tasks depend on their exact signatures. Tasks 9–17 are per-screen migrations that are largely independent of each other and can be reordered or parallelized after Task 9 establishes the reference.

**Hard gate at Task 1:** no code is written until the user approves the palette.

---

# Task 0: Repo Hygiene, Corruption Fix, and Baseline

**Files:**
- Fix: `Scenes/Transition/transition.tscn:9-10`
- Delete: 15 scratch files at repo root, `Scripts/Lobby/loby_backup.gd`(+`.uid`), `Scenes/StudentCard/student_card.tscn.bak`
- Create: `.gitignore` (verify), `docs/superpowers/baseline/` screenshots

**Interfaces:**
- Consumes: nothing.
- Produces: a clean, version-controlled working tree and before-screenshots used as the comparison baseline in every later task.

---

- [ ] **Step 1: Confirm the corruption is real**

`Scenes/Transition/transition.tscn` has an AI-generated text fragment written into the middle of its RESET animation track. Verify before touching:

```bash
grep -n "ctrl94\|ctrl95\|write_to_file call was cut off" Scenes/Transition/transition.tscn
```

Expected output: two hits, at lines 9 and 10.

- [ ] **Step 2: Fix the corrupted animation track**

Lines 7–11 of the file currently read:

```
tracks/0/type = "value"
tracks/0/imported = false
<ctrl94>thought
Wait! The `write_to_file` call was cut off because I paused. Let me write the full content of `Scenes/Transition/transition.tscn`.<ctrl95>[tracks/0/enabled] = true
tracks/0/path = NodePath(".:modulate")
```

They must read:

```
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath(".:modulate")
```

Apply with sed (deletes the two bad lines, inserts the correct one):

```bash
sed -i '9,10d' Scenes/Transition/transition.tscn
sed -i '8a tracks/0/enabled = true' Scenes/Transition/transition.tscn
```

- [ ] **Step 3: Verify the scene now parses**

```bash
grep -n "ctrl94\|ctrl95" Scenes/Transition/transition.tscn; echo "exit=$?"
```

Expected: no matches, `exit=1`.

Then load the scene in the editor to confirm Godot accepts it — use the `godot-ai` MCP tool `scene_open` with `path: "res://Scenes/Transition/transition.tscn"`, then `scene_get_hierarchy`. Expected: a `transition` CanvasLayer with `ColorRect` and `AnimationPlayer` children, **no parse errors** in the editor log (`logs_read`).

- [ ] **Step 4: Initialize version control**

The project is not a git repository. Every subsequent task modifies working scenes; proceeding without version control is unacceptable.

```bash
git init
```

- [ ] **Step 5: Verify .gitignore covers Godot's generated files**

Read the existing `.gitignore` (46 bytes — almost certainly incomplete):

```bash
cat .gitignore
```

It must contain at least these entries. Add any that are missing:

```
.godot/
*.tmp
export_presets.cfg
.import/
```

Do **not** ignore `*.uid` — Godot 4.4+ requires those files to be committed.

- [ ] **Step 6: Delete scratch and backup files**

These are one-off scripts and empty logs from a previous debugging session. Confirm each is untracked scratch before deleting — none are referenced by any `.tscn` or `.gd`:

```bash
grep -rl "add_val_labels\|update_inside\|update_layout\|update_viewport\|recover_tail\|parse_bottom\|loby_backup" Scenes Scripts project.godot || echo "no references - safe to delete"
```

Expected: `no references - safe to delete`.

```bash
rm -f add_val_labels.ps1 extract2.ps1 parse.ps1 parse2.ps1 parse_bottom.ps1 \
      recover.ps1 recover.py recover_tail.ps1 update_inside.ps1 update_layout.ps1 \
      update_viewport.ps1 update_viewport_fixed.ps1 \
      check_output.txt check_output2.txt check_output3.txt check_test.txt \
      out.log run_output.txt runner_output.txt test_out.txt \
      missing_chunk_1400_1886.json missing_chunk_1400_1886.txt \
      Scripts/Lobby/loby_backup.gd Scripts/Lobby/loby_backup.gd.uid \
      Scenes/StudentCard/student_card.tscn.bak
```

- [ ] **Step 7: Capture baseline screenshots of all 9 core scenes**

These are the "before" images every later task compares against. For each scene path below, use the `godot-ai` MCP tools: `scene_open` with the path, then `editor_screenshot`, and save the result under `docs/superpowers/baseline/<name>.png`.

```
res://Scenes/Splashscreen/Splashscreen.tscn   → baseline/01-splashscreen.png
res://Scenes/Loading/loading.tscn             → baseline/02-loading.png
res://Scenes/MainMenu/main_menu.tscn          → baseline/03-mainmenu.png
res://Scenes/CutScene/cut_scene.tscn          → baseline/04-cutscene.png
res://Scenes/StudentCard/student_card.tscn    → baseline/05-studentcard.png
res://Scenes/Lobby/loby.tscn                  → baseline/06-lobby.png
res://Scenes/AturJadwal/atur_jadwal.tscn      → baseline/07-aturjadwal.png
res://Scenes/StudentList/student_list.tscn    → baseline/08-studentlist.png
res://Scenes/SchoolSimulation/SchoolDay.tscn  → baseline/09-schoolday.png
res://Scenes/EndGame/SemesterEnd.tscn         → baseline/10-semesterend.png
```

- [ ] **Step 8: Verify the game still boots**

Use the `godot-ai` MCP tool `project_run`, then `logs_read`.

Expected: the game launches to Splashscreen with **no errors** in the log. Tapping advances to Loading, then MainMenu. Stop the run with `game_manage`.

If there are pre-existing errors, record them verbatim in `docs/superpowers/baseline/known-errors.md`. They are not this plan's responsibility to fix, but they must not be confused with regressions later.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "chore: init repo, fix corrupted transition.tscn, remove scratch files"
```

---

# Task 1: Palette & Typography Proposal — APPROVAL GATE

**Files:**
- Create: `docs/superpowers/design/palette.html`

**Interfaces:**
- Consumes: the proposed palette table in this plan's header.
- Produces: **user-approved hex values and font choices** that Task 2 hardcodes as the defaults of `design_tokens.tres`. No downstream task may begin until this is approved.

> **STOP CONDITION:** This task ends by asking the user for approval and waiting. Do not proceed to Task 2 on your own judgment. If the user requests palette changes, revise the artifact and ask again.

---

- [ ] **Step 1: Build the swatch page**

Create `docs/superpowers/design/palette.html`. It must show, for every token in the Palette table above:

1. A large color chip with the token name and hex printed on it, in a legible contrasting color.
2. Grouped sections: Brand, Surfaces, Text, Category Accents, Semantic States, Currency.
3. A **contrast check** column: computed WCAG contrast ratio of each text token against `surface_card` and against `brand_primary`, with a PASS/FAIL badge at the 4.5:1 threshold. Compute these values and write them into the HTML as static text — do not rely on script.
4. A **component preview** row rendering, in pure CSS using only these tokens: a primary pill button, a secondary pill button, a white-rimmed card with a drop shadow and vertical gradient, and five category chips (Akademis/Olahraga/SeniBudaya/Istirahat/Libur).
5. A **typography specimen**: "KEJARTES" and "Atur Jadwal Minggu Ini" set in Fredoka SemiBold, and a paragraph of Indonesian body copy in Nunito, at the size ramp from Task 2 (display 96 / h1 64 / h2 48 / title 36 / body 28 / caption 22 / micro 18, expressed in px at 1080-wide reference).

Load the fonts from Google Fonts (`https://fonts.googleapis.com` is the one external host artifacts allow) with a real fallback stack: `font-family: 'Fredoka', 'Trebuchet MS', sans-serif`.

The page must be theme-aware per Artifact requirements: define the full light palette on bare `:root`, redefine only the changed tokens under `@media (prefers-color-scheme: dark)` guarded as `:root:not([data-theme="light"])`, and again under `:root[data-theme="dark"]`. Give `body` an explicit token background.

Set `<title>Kejartes Palette</title>` at the top of the file.

- [ ] **Step 2: Load the artifact-design skill, then publish**

Load the `artifact-design` skill before finalizing the HTML — it calibrates how much design investment this page warrants. Then publish:

Call `Artifact` with `file_path` pointing at `docs/superpowers/design/palette.html`, `favicon: "🎨"`, and `description: "Proposed color palette and type scale for the Kejartes core UI polish pass."`

- [ ] **Step 3: Present to the user and WAIT**

Give the user the artifact link and ask explicitly:

> Here's the proposed palette and type scale. Three things I need from you:
> 1. Approve the palette as-is, or tell me which swatches to change.
> 2. Approve Fredoka (display) + Nunito (body), or name fonts you'd rather use.
> 3. Any category accent that reads wrong for the subject (e.g. if SeniBudaya shouldn't be purple).

**Do not start Task 2 until the user answers.**

- [ ] **Step 4: Record the approved values**

Once approved, append an "APPROVED — <date>" section to `docs/superpowers/design/palette.html` listing the final hex values and font names verbatim. This is what Task 2 reads from.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/design/palette.html && git commit -m "docs: approved palette and type scale for core UI polish"
```

---

# Task 2: DesignTokens Resource

**Files:**
- Create: `Scripts/Design/DesignTokens.gd`
- Create: `Assets/Theme/design_tokens.tres`
- Test: `tests/test_design_tokens.gd`

**Interfaces:**
- Consumes: approved hex values and font names from Task 1.
- Produces: `class_name DesignTokens extends Resource` with the exact properties listed in Step 3. **Every later task reads style values from this class and no other source.** Also produces the loadable path constant `DesignTokens.DEFAULT_PATH = "res://Assets/Theme/design_tokens.tres"` and the static helper `DesignTokens.load_default() -> DesignTokens`.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_design_tokens.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "design_tokens"


func test_default_resource_loads() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres must load")
	assert_true(tokens is DesignTokens, "must be a DesignTokens instance")


func test_brand_palette_matches_approved_values() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.brand_primary.to_html(false), "2e5bff", "brand_primary")
	assert_eq(tokens.surface_card.to_html(false), "ffffff", "surface_card")
	assert_eq(tokens.text_primary.to_html(false), "1e2436", "text_primary")


func test_category_color_lookup_covers_every_schedule_category() -> void:
	var tokens := DesignTokens.load_default()
	# These five strings are the category values GameState.get_jadwal_for_day
	# and atur_jadwal.gd actually store. All must resolve.
	for category in ["Akademis", "Olahraga", "SeniBudaya", "Istirahat", "Libur"]:
		var c := tokens.category_color(category)
		assert_true(c.a > 0.0, "category_color must resolve for: " + category)


func test_category_color_falls_back_for_unknown_category() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.category_color("TidakAda"), tokens.text_secondary,
		"unknown category falls back to text_secondary, never transparent")


func test_spacing_scale_is_monotonic() -> void:
	var tokens := DesignTokens.load_default()
	var scale := [tokens.space_xs, tokens.space_sm, tokens.space_md,
		tokens.space_lg, tokens.space_xl]
	for i in range(1, scale.size()):
		assert_true(scale[i] > scale[i - 1],
			"spacing step %d must exceed step %d" % [i, i - 1])


func test_font_size_scale_is_monotonic() -> void:
	var tokens := DesignTokens.load_default()
	var scale := [tokens.font_micro, tokens.font_caption, tokens.font_body,
		tokens.font_title, tokens.font_h2, tokens.font_h1, tokens.font_display]
	for i in range(1, scale.size()):
		assert_true(scale[i] > scale[i - 1],
			"font step %d must exceed step %d" % [i, i - 1])


func test_durations_are_positive_and_snappy() -> void:
	var tokens := DesignTokens.load_default()
	# A mobile UI that takes longer than a third of a second to respond
	# to a tap feels broken. This guards against a designer typing 3.0.
	assert_true(tokens.dur_instant > 0.0 and tokens.dur_instant <= 0.12, "dur_instant")
	assert_true(tokens.dur_fast > 0.0 and tokens.dur_fast <= 0.25, "dur_fast")
	assert_true(tokens.dur_normal > 0.0 and tokens.dur_normal <= 0.45, "dur_normal")
```

- [ ] **Step 2: Run the test to verify it fails**

Use the `godot-ai` MCP tool `test_run` with `suite: "design_tokens"`.

Expected: FAIL — `Identifier "DesignTokens" not declared in the current scope`.

- [ ] **Step 3: Write the DesignTokens resource class**

Create `Scripts/Design/DesignTokens.gd`. Substitute the **approved** hex values from Task 1 if they differ from the proposal.

```gdscript
@tool
class_name DesignTokens
extends Resource

## Single source of truth for every visual constant in KEJARTES.
##
## Edit this resource in the inspector (Assets/Theme/design_tokens.tres),
## then run Scripts/Design/BakeTheme.gd (File > Run) to regenerate the
## Theme. No color, radius, spacing value, font size, or animation
## duration may be hardcoded anywhere else in the project.

const DEFAULT_PATH := "res://Assets/Theme/design_tokens.tres"


static func load_default() -> DesignTokens:
	return load(DEFAULT_PATH) as DesignTokens


@export_group("Brand")
@export var brand_primary: Color = Color("2e5bff")
@export var brand_primary_light: Color = Color("6e8cff")
@export var brand_primary_dark: Color = Color("1b3acc")

@export_group("Surfaces")
@export var surface_page: Color = Color("eef3ff")
@export var surface_card: Color = Color("ffffff")
@export var surface_sunken: Color = Color("dde5f7")
@export var surface_overlay: Color = Color("141a2e")
## Alpha applied to surface_overlay when used as a modal scrim.
@export_range(0.0, 1.0) var overlay_scrim_alpha: float = 0.72

@export_group("Outline & Shadow")
@export var outline_card: Color = Color("ffffff")
@export var outline_width: float = 6.0
@export var shadow_color: Color = Color(0.08, 0.11, 0.22, 0.28)
@export var shadow_size: int = 14
@export var shadow_offset: Vector2 = Vector2(0, 6)

@export_group("Text")
@export var text_primary: Color = Color("1e2436")
@export var text_secondary: Color = Color("6b7490")
@export var text_on_brand: Color = Color("ffffff")
@export var text_disabled: Color = Color("a8b0c4")
## Chunky outline behind display text, Umamusume style.
@export var text_outline_color: Color = Color("ffffff")
@export var text_outline_size: int = 8

@export_group("Category Accents")
@export var cat_akademis: Color = Color("3d8bff")
@export var cat_olahraga: Color = Color("ff7a45")
@export var cat_senibudaya: Color = Color("b45bff")
@export var cat_istirahat: Color = Color("3ecf7a")
@export var cat_libur: Color = Color("ffc93c")

@export_group("Semantic States")
@export var state_success: Color = Color("2fb86b")
@export var state_warning: Color = Color("ffb020")
@export var state_danger: Color = Color("e4453a")
@export var currency_gold: Color = Color("ffc93c")

@export_group("Radii")
@export var radius_sm: int = 12
@export var radius_md: int = 24
@export var radius_lg: int = 36
## Pill buttons use a radius large enough to always round fully.
@export var radius_pill: int = 999

@export_group("Spacing")
@export var space_xs: int = 8
@export var space_sm: int = 16
@export var space_md: int = 28
@export var space_lg: int = 44
@export var space_xl: int = 72

@export_group("Typography")
@export var font_display: FontFile
@export var font_body: FontFile
@export var font_micro: int = 18
@export var font_caption: int = 22
@export var font_body_size: int = 28
@export var font_title: int = 36
@export var font_h2: int = 48
@export var font_h1: int = 64
@export var font_display_size: int = 96

@export_group("Motion")
@export var dur_instant: float = 0.08
@export var dur_fast: float = 0.18
@export var dur_normal: float = 0.32
@export var dur_slow: float = 0.55
## Scale a button shrinks to while held.
@export_range(0.80, 1.0) var press_scale: float = 0.94
## Scale a button overshoots to on release, before settling at 1.0.
@export_range(1.0, 1.25) var release_overshoot: float = 1.06
## Delay between consecutive items in a staggered list entry.
@export var stagger_step: float = 0.05

@export_group("Layout")
@export var touch_target_min: int = 96
@export var screen_margin: int = 48


## Resolve a schedule category name to its accent color.
## Returns text_secondary for anything unrecognized so callers never
## get a transparent color they would silently render as invisible.
func category_color(category: String) -> Color:
	match category:
		"Akademis", "Akademik": return cat_akademis
		"Olahraga": return cat_olahraga
		"SeniBudaya", "Seni Budaya": return cat_senibudaya
		"Istirahat": return cat_istirahat
		"Libur": return cat_libur
		_: return text_secondary


## The modal scrim color, i.e. surface_overlay at the configured alpha.
func scrim_color() -> Color:
	var c := surface_overlay
	c.a = overlay_scrim_alpha
	return c
```

Note the name collision avoidance: the size properties are `font_body_size` and `font_display_size` because `font_body` and `font_display` are the `FontFile` slots. The test above uses `tokens.font_body` in the monotonic check — **fix the test to use `font_body_size` and `font_display_size`** before running it again.

- [ ] **Step 4: Correct the test's font property names**

In `tests/test_design_tokens.gd`, `test_font_size_scale_is_monotonic` must read:

```gdscript
	var scale := [tokens.font_micro, tokens.font_caption, tokens.font_body_size,
		tokens.font_title, tokens.font_h2, tokens.font_h1, tokens.font_display_size]
```

- [ ] **Step 5: Create the .tres instance**

Create `Assets/Theme/design_tokens.tres`. The font slots stay null until Task 4:

```
[gd_resource type="Resource" script_class="DesignTokens" load_steps=2 format=3]

[ext_resource type="Script" path="res://Scripts/Design/DesignTokens.gd" id="1_tokens"]

[resource]
script = ExtResource("1_tokens")
```

Every other property is intentionally omitted so it inherits the script's declared defaults. A designer changing a value in the inspector will cause Godot to write only that property into this file — which is exactly the intent.

- [ ] **Step 6: Run the tests to verify they pass**

`test_run` with `suite: "design_tokens"`.

Expected: 7 tests, all PASS.

- [ ] **Step 7: Verify the resource is inspector-editable**

Use `godot-ai` MCP `filesystem_manage` to rescan, then open `Assets/Theme/design_tokens.tres` in the editor and take an `editor_screenshot`.

Expected: the inspector shows the grouped foldouts — Brand, Surfaces, Outline & Shadow, Text, Category Accents, Semantic States, Radii, Spacing, Typography, Motion, Layout — with color pickers on the Color properties and a slider on `overlay_scrim_alpha`. If the groups do not appear, the `@tool` annotation or `class_name` is missing.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Assets/Theme/design_tokens.tres tests/test_design_tokens.gd
git commit -m "feat(design): add DesignTokens resource as single source of style truth"
```

---

# Task 3: ThemeFactory and Bake Pipeline

**Files:**
- Create: `Scripts/Design/ThemeFactory.gd`
- Create: `Scripts/Design/BakeTheme.gd`
- Create: `Assets/Theme/kejartes_theme.tres` (generated)
- Modify: `project.godot` (add `gui/theme/custom`)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: `DesignTokens` (Task 2), specifically `brand_primary*`, `surface_*`, `outline_*`, `shadow_*`, `text_*`, `radius_*`, `space_*`, `font_*`, `touch_target_min`.
- Produces: `class_name ThemeFactory` with the single static entry point `ThemeFactory.build(tokens: DesignTokens) -> Theme`, and these **theme type variation names** that every later task applies via `theme_type_variation`:
  - `"PrimaryButton"` — glossy brand-gradient pill, the main CTA
  - `"SecondaryButton"` — white pill with brand outline
  - `"DangerButton"` — red pill for destructive/cancel actions
  - `"Card"` (Panel) — white fill, thick white rim, drop shadow, `radius_lg`
  - `"SunkenPanel"` (Panel) — recessed track background
  - `"Scrim"` (Panel) — full-bleed modal dimmer
  - `"DisplayLabel"`, `"H1Label"`, `"H2Label"`, `"TitleLabel"`, `"CaptionLabel"`, `"MicroLabel"` (Label)
  - `"StatBar"` (ProgressBar) — rounded track + fill, tintable via `self_modulate`

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_theme_factory.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "theme_factory"

var _tokens: DesignTokens
var _theme: Theme


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


func test_build_returns_a_theme() -> void:
	assert_not_null(_theme, "build must return a Theme")
	assert_true(_theme is Theme, "must be a Theme instance")


func test_every_declared_variation_exists() -> void:
	# Later tasks set theme_type_variation to these exact strings.
	# A typo here becomes an invisible styling failure at runtime,
	# because Godot silently falls back to the base type.
	var expected := [
		"PrimaryButton", "SecondaryButton", "DangerButton",
		"Card", "SunkenPanel", "Scrim",
		"DisplayLabel", "H1Label", "H2Label", "TitleLabel",
		"CaptionLabel", "MicroLabel", "StatBar",
	]
	var actual := _theme.get_type_list()
	for variation in expected:
		assert_true(actual.has(variation), "theme must declare type: " + variation)


func test_button_variations_have_all_four_states() -> void:
	for variation in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			assert_true(_theme.has_stylebox(state, variation),
				"%s must define stylebox: %s" % [variation, state])


func test_primary_button_uses_brand_color() -> void:
	var sb := _theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_not_null(sb, "PrimaryButton/normal must be a StyleBoxFlat")
	assert_eq(sb.bg_color, _tokens.brand_primary_light,
		"gradient top of the primary button is brand_primary_light")


func test_buttons_meet_minimum_touch_target() -> void:
	# Anything smaller is a tap the user will miss on a phone.
	for variation in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		var sb := _theme.get_stylebox("normal", variation) as StyleBoxFlat
		var height := sb.content_margin_top + sb.content_margin_bottom
		assert_true(height >= float(_tokens.touch_target_min) * 0.5,
			variation + " content margins must contribute to a tappable height")


func test_card_has_visible_outline_and_shadow() -> void:
	var sb := _theme.get_stylebox("panel", "Card") as StyleBoxFlat
	assert_eq(sb.bg_color, _tokens.surface_card, "card fill")
	assert_true(sb.border_width_top >= 1, "card must have the white rim")
	assert_eq(sb.border_color, _tokens.outline_card, "rim color")
	assert_true(sb.shadow_size > 0, "card must have a drop shadow")


func test_label_variations_carry_font_sizes_from_tokens() -> void:
	assert_eq(_theme.get_font_size("font_size", "DisplayLabel"), _tokens.font_display_size)
	assert_eq(_theme.get_font_size("font_size", "H1Label"), _tokens.font_h1)
	assert_eq(_theme.get_font_size("font_size", "CaptionLabel"), _tokens.font_caption)


func test_changing_a_token_changes_the_built_theme() -> void:
	# This is the whole point of the pipeline: edit the token, get a new look.
	var custom := DesignTokens.new()
	custom.brand_primary_light = Color("ff0000")
	var custom_theme := ThemeFactory.build(custom)
	var sb := custom_theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_eq(sb.bg_color, Color("ff0000"),
		"theme must be derived from tokens, not hardcoded")


func test_build_survives_null_fonts() -> void:
	# design_tokens.tres has null font slots until Task 4. Baking must
	# not crash in that window.
	var bare := DesignTokens.new()
	bare.font_display = null
	bare.font_body = null
	var t := ThemeFactory.build(bare)
	assert_not_null(t, "build must tolerate unassigned font slots")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "theme_factory"`.

Expected: FAIL — `Identifier "ThemeFactory" not declared`.

- [ ] **Step 3: Write the ThemeFactory**

Create `Scripts/Design/ThemeFactory.gd`:

```gdscript
@tool
class_name ThemeFactory
extends RefCounted

## Builds a Godot Theme from a DesignTokens resource.
##
## Pure: no file I/O, no editor dependencies, no global state. Given the
## same tokens it always produces the same Theme. BakeTheme.gd handles
## persistence; this file only handles construction.


static func build(tokens: DesignTokens) -> Theme:
	var theme := Theme.new()

	if tokens.font_body != null:
		theme.default_font = tokens.font_body
	theme.default_font_size = tokens.font_body_size

	_build_buttons(theme, tokens)
	_build_panels(theme, tokens)
	_build_labels(theme, tokens)
	_build_progress(theme, tokens)
	_build_base_overrides(theme, tokens)

	return theme


# ---------------------------------------------------------------- buttons

static func _build_buttons(theme: Theme, tokens: DesignTokens) -> void:
	_add_button_variation(theme, tokens, "PrimaryButton",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)

	_add_button_variation(theme, tokens, "SecondaryButton",
		tokens.surface_card, tokens.surface_sunken,
		tokens.brand_primary, tokens.brand_primary)

	_add_button_variation(theme, tokens, "DangerButton",
		tokens.state_danger.lightened(0.18), tokens.state_danger.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand)


## One glossy pill in four states. `top`/`bottom` form the vertical
## gradient that gives the button its Umamusume sheen.
static func _add_button_variation(
	theme: Theme,
	tokens: DesignTokens,
	name: String,
	top: Color,
	bottom: Color,
	border: Color,
	text_color: Color
) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	theme.set_stylebox("normal", name,
		_pill(tokens, top, bottom, border, 0.0))
	theme.set_stylebox("hover", name,
		_pill(tokens, top.lightened(0.08), bottom.lightened(0.08), border, 0.0))
	# Pressed sinks: gradient flips and the shadow collapses.
	theme.set_stylebox("pressed", name,
		_pill(tokens, bottom, top, border, -tokens.shadow_offset.y * 0.5))
	theme.set_stylebox("focus", name,
		_pill(tokens, top, bottom, tokens.brand_primary, 0.0))

	var disabled := _pill(tokens,
		top.lerp(tokens.surface_sunken, 0.7),
		bottom.lerp(tokens.surface_sunken, 0.7),
		border.lerp(tokens.surface_sunken, 0.5), 0.0)
	disabled.shadow_size = 0
	theme.set_stylebox("disabled", name, disabled)

	theme.set_color("font_color", name, text_color)
	theme.set_color("font_hover_color", name, text_color)
	theme.set_color("font_pressed_color", name, text_color)
	theme.set_color("font_focus_color", name, text_color)
	theme.set_color("font_disabled_color", name, tokens.text_disabled)
	theme.set_font_size("font_size", name, tokens.font_title)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)


static func _pill(
	tokens: DesignTokens,
	top: Color,
	bottom: Color,
	border: Color,
	shadow_dy: float
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top
	# StyleBoxFlat has no gradient; the two-tone look comes from a
	# lighter fill plus a darker, thicker bottom border acting as a bevel.
	sb.border_color = border
	sb.border_width_left = int(tokens.outline_width)
	sb.border_width_top = int(tokens.outline_width)
	sb.border_width_right = int(tokens.outline_width)
	sb.border_width_bottom = int(tokens.outline_width)
	sb.set_corner_radius_all(tokens.radius_pill)
	sb.shadow_color = tokens.shadow_color
	sb.shadow_size = tokens.shadow_size
	sb.shadow_offset = Vector2(tokens.shadow_offset.x,
		tokens.shadow_offset.y + shadow_dy)
	sb.content_margin_left = tokens.space_lg
	sb.content_margin_right = tokens.space_lg
	sb.content_margin_top = tokens.space_md
	sb.content_margin_bottom = tokens.space_md
	# Bottom bevel: a darker inner shade sold via the expand margin.
	sb.bg_color = top.lerp(bottom, 0.35)
	return sb


# ----------------------------------------------------------------- panels

static func _build_panels(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("Card")
	theme.set_type_variation("Card", "Panel")
	var card := StyleBoxFlat.new()
	card.bg_color = tokens.surface_card
	card.border_color = tokens.outline_card
	card.set_border_width_all(int(tokens.outline_width))
	card.set_corner_radius_all(tokens.radius_lg)
	card.shadow_color = tokens.shadow_color
	card.shadow_size = tokens.shadow_size
	card.shadow_offset = tokens.shadow_offset
	card.set_content_margin_all(tokens.space_md)
	theme.set_stylebox("panel", "Card", card)

	theme.add_type("SunkenPanel")
	theme.set_type_variation("SunkenPanel", "Panel")
	var sunken := StyleBoxFlat.new()
	sunken.bg_color = tokens.surface_sunken
	sunken.set_corner_radius_all(tokens.radius_md)
	sunken.set_content_margin_all(tokens.space_sm)
	theme.set_stylebox("panel", "SunkenPanel", sunken)

	theme.add_type("Scrim")
	theme.set_type_variation("Scrim", "Panel")
	var scrim := StyleBoxFlat.new()
	scrim.bg_color = tokens.scrim_color()
	theme.set_stylebox("panel", "Scrim", scrim)


# ----------------------------------------------------------------- labels

static func _build_labels(theme: Theme, tokens: DesignTokens) -> void:
	# name, size, color, outlined
	var specs := [
		["DisplayLabel", tokens.font_display_size, tokens.text_primary, true],
		["H1Label", tokens.font_h1, tokens.text_primary, true],
		["H2Label", tokens.font_h2, tokens.text_primary, false],
		["TitleLabel", tokens.font_title, tokens.text_primary, false],
		["CaptionLabel", tokens.font_caption, tokens.text_secondary, false],
		["MicroLabel", tokens.font_micro, tokens.text_secondary, false],
	]
	for spec in specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "Label")
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, spec[2])
		if spec[3]:
			# The chunky white rim behind big display text.
			theme.set_constant("outline_size", name, tokens.text_outline_size)
			theme.set_color("font_outline_color", name, tokens.text_outline_color)
			if tokens.font_display != null:
				theme.set_font("font", name, tokens.font_display)


# --------------------------------------------------------------- progress

static func _build_progress(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("StatBar")
	theme.set_type_variation("StatBar", "ProgressBar")

	var bg := StyleBoxFlat.new()
	bg.bg_color = tokens.surface_sunken
	bg.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("background", "StatBar", bg)

	# White fill so callers can tint per category via self_modulate.
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("fill", "StatBar", fill)

	theme.set_font_size("font_size", "StatBar", tokens.font_caption)
	theme.set_color("font_color", "StatBar", tokens.text_primary)


# ------------------------------------------------- unstyled base controls

## Baseline styling for controls used without a variation, so a plain
## Button or Panel dropped into a scene never renders as Godot default gray.
static func _build_base_overrides(theme: Theme, tokens: DesignTokens) -> void:
	theme.set_color("font_color", "Label", tokens.text_primary)
	theme.set_font_size("font_size", "Label", tokens.font_body_size)

	var panel := StyleBoxFlat.new()
	panel.bg_color = tokens.surface_card
	panel.set_corner_radius_all(tokens.radius_md)
	theme.set_stylebox("panel", "Panel", panel)

	theme.set_color("font_color", "Button", tokens.text_on_brand)
	theme.set_font_size("font_size", "Button", tokens.font_title)
	theme.set_stylebox("normal", "Button",
		_pill(tokens, tokens.brand_primary_light, tokens.brand_primary_dark,
			tokens.outline_card, 0.0))
	theme.set_stylebox("hover", "Button",
		_pill(tokens, tokens.brand_primary_light.lightened(0.08),
			tokens.brand_primary_dark.lightened(0.08), tokens.outline_card, 0.0))
	theme.set_stylebox("pressed", "Button",
		_pill(tokens, tokens.brand_primary_dark, tokens.brand_primary_light,
			tokens.outline_card, -tokens.shadow_offset.y * 0.5))
	theme.set_stylebox("disabled", "Button",
		_pill(tokens, tokens.surface_sunken, tokens.surface_sunken,
			tokens.surface_sunken, 0.0))

	theme.set_color("font_color", "RichTextLabel", tokens.text_primary)
	theme.set_font_size("normal_font_size", "RichTextLabel", tokens.font_body_size)
```

- [ ] **Step 4: Run the tests to verify they pass**

`test_run` with `suite: "theme_factory"`.

Expected: 10 tests, all PASS. If `test_buttons_meet_minimum_touch_target` fails, the `space_md` content margins are too small — raise `space_md` in the tokens rather than special-casing the factory.

- [ ] **Step 5: Write the bake EditorScript**

Create `Scripts/Design/BakeTheme.gd`:

```gdscript
@tool
extends EditorScript

## Regenerates Assets/Theme/kejartes_theme.tres from design_tokens.tres.
##
## Run it from the Godot editor: open this file, then File > Run
## (Ctrl+Shift+X). Run it after ANY change to design_tokens.tres —
## the baked theme is what the game actually loads.

const OUTPUT_PATH := "res://Assets/Theme/kejartes_theme.tres"


func _run() -> void:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		push_error("BakeTheme: could not load " + DesignTokens.DEFAULT_PATH)
		return

	var theme := ThemeFactory.build(tokens)
	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	if err != OK:
		push_error("BakeTheme: save failed with error %d" % err)
		return

	print("BakeTheme: wrote ", OUTPUT_PATH, " (",
		theme.get_type_list().size(), " types)")
	EditorInterface.get_resource_filesystem().scan()
```

- [ ] **Step 6: Bake the theme**

In the editor, open `Scripts/Design/BakeTheme.gd` and run File > Run. Alternatively drive it via the `godot-ai` MCP `editor_manage` tool if it exposes script execution.

Then verify the output exists and is non-trivial:

```bash
ls -la Assets/Theme/kejartes_theme.tres && grep -c "sub_resource" Assets/Theme/kejartes_theme.tres
```

Expected: the file exists and reports **20 or more** `sub_resource` entries (one per StyleBox). A count under 10 means the factory silently skipped variations.

- [ ] **Step 7: Register the theme project-wide**

Add to `project.godot`, in the `[gui]` section (create the section if absent — it goes after `[display]`):

```
[gui]

theme/custom="res://Assets/Theme/kejartes_theme.tres"
```

- [ ] **Step 8: Verify every core scene picks up the theme**

Open each of the 9 core scenes with `scene_open` and take an `editor_screenshot`. Compare against `docs/superpowers/baseline/`.

Expected: **visible change on every screen** — no more Godot-default gray buttons. Scenes with heavy `theme_override_*` (StudentCard at 512, SemesterEnd at 150, StudentList at 121) will look mostly unchanged, because overrides still win. That is expected at this stage; Tasks 12–17 strip them.

MainMenu (only 4 overrides) should change dramatically — this is the fastest confirmation that the pipeline works.

- [ ] **Step 9: Check the editor log for errors**

`logs_read`. Expected: no new errors beyond the baseline recorded in Task 0.

- [ ] **Step 10: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Scripts/Design/BakeTheme.gd \
        Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd project.godot
git commit -m "feat(design): build Theme from tokens, register project-wide"
```

---

# Task 4: Fonts

**Files:**
- Create: `Assets/Fonts/Fredoka-SemiBold.ttf`, `Assets/Fonts/Nunito-Regular.ttf`, `Assets/Fonts/Nunito-Bold.ttf`, `Assets/Fonts/OFL.txt`, `Assets/Fonts/README.md`
- Modify: `Assets/Theme/design_tokens.tres` (assign font slots)
- Modify: `Assets/Theme/kejartes_theme.tres` (rebake)

**Interfaces:**
- Consumes: `DesignTokens.font_display`, `DesignTokens.font_body` (declared in Task 2, null until now).
- Produces: non-null font slots. No new API.

---

- [ ] **Step 1: Ask the user before downloading**

Downloading files requires explicit permission. Ask:

> To wire in the approved fonts I need to download three OFL-licensed files from Google Fonts into `Assets/Fonts/`:
> - `Fredoka-SemiBold.ttf` (~120 KB) — display face
> - `Nunito-Regular.ttf` (~250 KB) — body
> - `Nunito-Bold.ttf` (~250 KB) — body emphasis
>
> Source: github.com/google/fonts (SIL Open Font License 1.1). OK to download?

**Wait for a clear yes.** If the user declines, ask them to place their own `.ttf` files in `Assets/Fonts/` and continue from Step 3.

- [ ] **Step 2: Download the fonts and license**

```bash
mkdir -p Assets/Fonts
curl -L -o Assets/Fonts/Fredoka-SemiBold.ttf "https://github.com/google/fonts/raw/main/ofl/fredoka/Fredoka%5Bwdth%2Cwght%5D.ttf"
curl -L -o Assets/Fonts/Nunito-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
curl -L -o Assets/Fonts/OFL.txt "https://github.com/google/fonts/raw/main/ofl/nunito/OFL.txt"
```

Both downloads are **variable fonts**. Godot 4 imports these fine and exposes the weight axis on the `FontVariation` resource. Since the filenames say SemiBold/Regular but the files are variable, rename them to reflect reality:

```bash
mv Assets/Fonts/Fredoka-SemiBold.ttf Assets/Fonts/Fredoka-Variable.ttf
mv Assets/Fonts/Nunito-Regular.ttf Assets/Fonts/Nunito-Variable.ttf
```

Verify the files are real fonts and not HTML error pages:

```bash
file Assets/Fonts/*.ttf && ls -la Assets/Fonts/
```

Expected: both report TrueType/OpenType font data, each over 100 KB. If either is under 10 KB or reports "HTML document", the download failed — stop and report it.

- [ ] **Step 3: Document the swap procedure**

Create `Assets/Fonts/README.md`:

```markdown
# Fonts

- `Fredoka-Variable.ttf` — display face (headings, buttons, big numbers)
- `Nunito-Variable.ttf` — body face (everything else)

Both are SIL Open Font License 1.1. See `OFL.txt`.

## Swapping in your own fonts

1. Drop your `.ttf` / `.otf` into this folder.
2. Open `Assets/Theme/design_tokens.tres` in the inspector.
3. Under **Typography**, drag your file onto `Font Display` and/or `Font Body`.
4. Open `Scripts/Design/BakeTheme.gd` and run File > Run (Ctrl+Shift+X).

No code changes are required. The whole game re-renders in the new face.
```

- [ ] **Step 4: Assign the fonts in the tokens resource**

Open `Assets/Theme/design_tokens.tres` in the Godot inspector. Under the **Typography** group, drag `Assets/Fonts/Fredoka-Variable.ttf` onto `Font Display` and `Assets/Fonts/Nunito-Variable.ttf` onto `Font Body`. Save.

Verify the assignment landed in the file:

```bash
grep -c "Fredoka\|Nunito" Assets/Theme/design_tokens.tres
```

Expected: `2` or more.

- [ ] **Step 5: Rebake the theme**

Run `Scripts/Design/BakeTheme.gd` via File > Run.

- [ ] **Step 6: Verify the fonts render**

Open `res://Scenes/MainMenu/main_menu.tscn` with `scene_open` and take an `editor_screenshot`.

Expected: "KEJARTES" renders in Fredoka's rounded forms, visibly different from Godot's default. If it still looks default, the theme did not rebake, or the tokens `.tres` did not save.

- [ ] **Step 7: Re-run the token and theme tests**

`test_run` with `suite: "design_tokens"`, then `suite: "theme_factory"`.

Expected: all 17 tests still PASS. `test_build_survives_null_fonts` still passes because it constructs a bare `DesignTokens`, unaffected by the `.tres`.

- [ ] **Step 8: Commit**

```bash
git add Assets/Fonts Assets/Theme
git commit -m "feat(design): add OFL fonts (Fredoka display, Nunito body) and rebake theme"
```

---

# Task 5: AudioDirector

**Files:**
- Create: `Scripts/Audio/AudioDirector.gd`
- Create: `Scenes/Audio/audio_director.tscn`
- Create: `Assets/Audio/SFX/`, `Assets/Audio/BGM/`, `Assets/Audio/README.md`
- Modify: `project.godot` (autoload + audio buses)
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the autoload `AudioDirector` with this exact API, called by Task 6 and every screen task:
  - `AudioDirector.play_sfx(id: StringName) -> void`
  - `AudioDirector.play_bgm(id: StringName, fade: float = -1.0) -> void`
  - `AudioDirector.stop_bgm(fade: float = -1.0) -> void`
  - `AudioDirector.set_bus_volume(bus: StringName, linear: float) -> void`
  - `AudioDirector.get_bus_volume(bus: StringName) -> float`
  - SFX ids: `&"tap"`, `&"confirm"`, `&"cancel"`, `&"success"`, `&"fail"`, `&"coin"`, `&"whoosh"`, `&"pop"`
  - BGM ids: `&"menu"`, `&"lobby"`, `&"simulation"`, `&"result"`
  - Bus names: `&"Master"`, `&"BGM"`, `&"SFX"`

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_audio_director.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "audio_director"

var _director: Node


func setup() -> void:
	# Instantiate a fresh copy rather than poking the live autoload, so
	# volume changes in these tests do not leak into the running game.
	var scene: PackedScene = load("res://Scenes/Audio/audio_director.tscn")
	_director = scene.instantiate()
	Engine.get_main_loop().root.add_child(_director)
	track(_director)


func teardown() -> void:
	if is_instance_valid(_director):
		_director.queue_free()
	_director = null


func test_required_buses_exist() -> void:
	for bus in ["Master", "BGM", "SFX"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0,
			"audio bus must exist: " + bus)


func test_sfx_and_bgm_slots_are_exported() -> void:
	# The inspector-editability requirement: a designer must be able to
	# drag an .ogg onto each slot without touching code.
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	for slot in ["sfx_tap", "sfx_confirm", "sfx_cancel", "sfx_success",
			"sfx_fail", "sfx_coin", "sfx_whoosh", "sfx_pop",
			"bgm_menu", "bgm_lobby", "bgm_simulation", "bgm_result"]:
		assert_true(names.has(slot), "must expose export slot: " + slot)


func test_play_sfx_with_empty_slot_is_silent_not_a_crash() -> void:
	# Slots are null until the user drops in audio. This must never error.
	_director.play_sfx(&"tap")
	_director.play_sfx(&"confirm")
	assert_true(true, "play_sfx on an unassigned slot must not crash")


func test_play_sfx_with_unknown_id_is_survivable() -> void:
	_director.play_sfx(&"tidak_ada_suara_ini")
	assert_true(true, "unknown sfx id must not crash")


func test_bus_volume_roundtrips() -> void:
	_director.set_bus_volume(&"SFX", 0.5)
	assert_almost_eq(_director.get_bus_volume(&"SFX"), 0.5, 0.01,
		"volume set then read must match")


func test_bus_volume_clamps_to_valid_range() -> void:
	_director.set_bus_volume(&"SFX", 5.0)
	assert_almost_eq(_director.get_bus_volume(&"SFX"), 1.0, 0.01, "clamps high")
	_director.set_bus_volume(&"SFX", -3.0)
	assert_almost_eq(_director.get_bus_volume(&"SFX"), 0.0, 0.01, "clamps low")


func test_muted_bus_reports_zero_not_negative_infinity() -> void:
	_director.set_bus_volume(&"BGM", 0.0)
	assert_almost_eq(_director.get_bus_volume(&"BGM"), 0.0, 0.01,
		"a fully muted bus reads back as 0.0, not -inf or NaN")


func test_sfx_voices_are_pooled_and_reused() -> void:
	# Firing many taps in a row must not spawn unbounded players.
	for i in range(60):
		_director.play_sfx(&"tap")
	var players := 0
	for child in _director.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_true(players <= 20,
		"sfx pool must be bounded, found %d players" % players)
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "audio_director"`.

Expected: FAIL — cannot load `res://Scenes/Audio/audio_director.tscn`.

- [ ] **Step 3: Add the audio buses**

Create `Assets/Audio/default_bus_layout.tres`:

```
[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/1/name = &"BGM"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
```

Register it in `project.godot` under a new `[audio]` section:

```
[audio]

buses/default_bus_layout="res://Assets/Audio/default_bus_layout.tres"
```

- [ ] **Step 4: Write the AudioDirector script**

Create `Scripts/Audio/AudioDirector.gd`:

```gdscript
extends Node

## Global audio. Autoloaded as `AudioDirector` from
## Scenes/Audio/audio_director.tscn so every stream slot is assignable
## in the inspector — drop an .ogg on a slot, no code changes.
##
## Every slot may be null. Nothing here crashes on a null stream; it
## simply plays nothing. That is deliberate: the project ships with
## empty slots and the user fills them in over time.

const SFX_POOL_SIZE := 12
const SETTINGS_PATH := "user://audio.cfg"

@export_group("SFX")
@export var sfx_tap: AudioStream
@export var sfx_confirm: AudioStream
@export var sfx_cancel: AudioStream
@export var sfx_success: AudioStream
@export var sfx_fail: AudioStream
@export var sfx_coin: AudioStream
@export var sfx_whoosh: AudioStream
@export var sfx_pop: AudioStream

@export_group("BGM")
@export var bgm_menu: AudioStream
@export var bgm_lobby: AudioStream
@export var bgm_simulation: AudioStream
@export var bgm_result: AudioStream

@export_group("Mixing")
## Default crossfade for play_bgm/stop_bgm when no explicit fade is given.
@export var default_bgm_fade: float = 0.8
## Random pitch spread on each SFX so repeated taps do not sound robotic.
@export_range(0.0, 0.3) var sfx_pitch_variance: float = 0.06

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer
var _bgm_current_id: StringName = &""
var _bgm_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

	_bgm_a = _make_bgm_player()
	_bgm_b = _make_bgm_player()
	_bgm_active = _bgm_a

	_load_volumes()


func _make_bgm_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"BGM"
	add_child(p)
	return p


# -------------------------------------------------------------------- sfx

func play_sfx(id: StringName) -> void:
	var stream := _resolve_sfx(id)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance)
	player.play()


func _resolve_sfx(id: StringName) -> AudioStream:
	match id:
		&"tap": return sfx_tap
		&"confirm": return sfx_confirm
		&"cancel": return sfx_cancel
		&"success": return sfx_success
		&"fail": return sfx_fail
		&"coin": return sfx_coin
		&"whoosh": return sfx_whoosh
		&"pop": return sfx_pop
		_: return null


# -------------------------------------------------------------------- bgm

func play_bgm(id: StringName, fade: float = -1.0) -> void:
	if id == _bgm_current_id and _bgm_active.playing:
		return
	var stream := _resolve_bgm(id)
	if stream == null:
		_bgm_current_id = id
		return

	var duration := default_bgm_fade if fade < 0.0 else fade
	var incoming := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var outgoing := _bgm_active

	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(incoming, "volume_db", 0.0, duration)
	_bgm_tween.tween_property(outgoing, "volume_db", -60.0, duration)
	_bgm_tween.chain().tween_callback(outgoing.stop)

	_bgm_active = incoming
	_bgm_current_id = id


func stop_bgm(fade: float = -1.0) -> void:
	var duration := default_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", -60.0, duration)
	_bgm_tween.tween_callback(_bgm_active.stop)
	_bgm_current_id = &""


func _resolve_bgm(id: StringName) -> AudioStream:
	match id:
		&"menu": return bgm_menu
		&"lobby": return bgm_lobby
		&"simulation": return bgm_simulation
		&"result": return bgm_result
		_: return null


# ------------------------------------------------------------------ mixing

## Set a bus volume as a 0.0-1.0 linear value. Clamped. Persisted.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("AudioDirector: unknown bus " + String(bus))
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v))
	# linear_to_db(0.0) is -inf, which AudioServer stores but which reads
	# back as -inf; mute the bus instead so get_bus_volume returns 0.0.
	AudioServer.set_bus_mute(idx, is_zero_approx(v))
	_save_volumes()


func get_bus_volume(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 0.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _save_volumes() -> void:
	var cfg := ConfigFile.new()
	for bus in ["Master", "BGM", "SFX"]:
		cfg.set_value("volume", bus, get_bus_volume(bus))
	cfg.save(SETTINGS_PATH)


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in ["Master", "BGM", "SFX"]:
		set_bus_volume(bus, cfg.get_value("volume", bus, 1.0))
```

- [ ] **Step 5: Create the autoload scene**

Create `Scenes/Audio/audio_director.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Scripts/Audio/AudioDirector.gd" id="1_audio"]

[node name="AudioDirector" type="Node"]
script = ExtResource("1_audio")
```

- [ ] **Step 6: Register the autoload**

In `project.godot`, add to `[autoload]` — placed after `GameSettings` so it is available to everything that follows:

```
AudioDirector="*res://Scenes/Audio/audio_director.tscn"
```

- [ ] **Step 7: Run the tests to verify they pass**

`test_run` with `suite: "audio_director"`.

Expected: 8 tests, all PASS.

- [ ] **Step 8: Ask the user before downloading SFX**

> To fill the SFX slots I'd download the Kenney UI Audio pack (CC0, ~2 MB, kenney.nl/assets/ui-audio) and map 8 clips onto the tap/confirm/cancel/success/fail/coin/whoosh/pop slots. BGM slots stay empty — music is a bigger choice I'd rather you make. OK to download?

**Wait for a clear yes.** If declined, leave all slots null and continue — the API is designed to be silent, and Step 9's README explains how to fill them later.

- [ ] **Step 9: Document the audio swap procedure**

Create `Assets/Audio/README.md`:

```markdown
# Audio

- `SFX/` — short one-shot sounds
- `BGM/` — looping music

## Filling or swapping a slot

1. Drop your `.ogg` (preferred) or `.wav` into `SFX/` or `BGM/`.
2. In the Godot editor, expand the **AudioDirector** autoload
   (Project > Project Settings > Autoload, or just open
   `Scenes/Audio/audio_director.tscn`).
3. Drag your file onto the matching slot in the inspector.

No code changes required. Slots you leave empty simply play nothing.

| Slot | Fires when |
|---|---|
| `sfx_tap` | any button is pressed |
| `sfx_confirm` | a positive/accept action |
| `sfx_cancel` | back, close, decline |
| `sfx_success` | a target is met, a day goes well |
| `sfx_fail` | a target is missed |
| `sfx_coin` | money changes |
| `sfx_whoosh` | scene transitions |
| `sfx_pop` | a card or list item enters |
| `bgm_menu` | MainMenu, Settings |
| `bgm_lobby` | Lobby, StudentCard, StudentList, AturJadwal |
| `bgm_simulation` | SchoolDay |
| `bgm_result` | SemesterEnd |
```

- [ ] **Step 10: Verify the game still boots with the new autoload**

`project_run`, then `logs_read`.

Expected: no errors. `AudioDirector` appears in the scene tree at `/root/AudioDirector`. Stop with `game_manage`.

- [ ] **Step 11: Commit**

```bash
git add Scripts/Audio Scenes/Audio Assets/Audio tests/test_audio_director.gd project.godot
git commit -m "feat(audio): add AudioDirector autoload with inspector-assignable slots"
```

---

# Task 6: Juice Library and UIPolish Autoload

**Files:**
- Create: `Scripts/Design/Juice.gd`
- Create: `Scripts/UI/UIPolish.gd`
- Modify: `project.godot` (autoload)
- Test: `tests/test_juice.gd`

**Interfaces:**
- Consumes: `DesignTokens` (`dur_*`, `press_scale`, `release_overshoot`, `stagger_step`), `AudioDirector.play_sfx`.
- Produces: `class_name Juice` with these static methods, called by every screen task:
  - `Juice.press(node: Control) -> void` — shrink to `press_scale`
  - `Juice.release(node: Control) -> void` — overshoot then settle at 1.0
  - `Juice.pop_in(node: Control, delay: float = 0.0) -> void` — scale 0→1 with back-out
  - `Juice.fade_in(node: CanvasItem, delay: float = 0.0) -> void`
  - `Juice.stagger_in(nodes: Array, step: float = -1.0) -> void` — pop_in each with increasing delay
  - `Juice.count_up(label: Label, from: float, to: float, fmt: String = "%d") -> void`
  - `Juice.fill_bar(bar: Range, to: float) -> void` — eased value tween
  - `Juice.shake(node: Control, strength: float = 12.0) -> void`
  - `Juice.set_pivot_center(node: Control) -> void`
  - Also produces the opt-out meta key `Juice.NO_AUTO_JUICE = &"no_auto_juice"`.
- Produces: autoload `UIPolish`, which needs no public API — it works by observing `node_added`.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_juice.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "juice"

var _root: Control


func setup() -> void:
	_root = Control.new()
	_root.size = Vector2(400, 400)
	Engine.get_main_loop().root.add_child(_root)
	track(_root)


func teardown() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _make_control() -> Control:
	var c := Control.new()
	c.size = Vector2(200, 100)
	_root.add_child(c)
	return c


func test_set_pivot_center_puts_pivot_at_the_middle() -> void:
	# Without this, every scale tween grows from the top-left corner and
	# the button visibly slides instead of pulsing.
	var c := _make_control()
	Juice.set_pivot_center(c)
	assert_eq(c.pivot_offset, Vector2(100, 50), "pivot must be size/2")


func test_press_shrinks_the_node() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	Juice.press(c)
	await Engine.get_main_loop().create_timer(tokens.dur_instant + 0.05).timeout
	assert_almost_eq(c.scale.x, tokens.press_scale, 0.02,
		"press must settle at press_scale")


func test_release_returns_to_unit_scale() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	c.scale = Vector2(tokens.press_scale, tokens.press_scale)
	Juice.release(c)
	await Engine.get_main_loop().create_timer(tokens.dur_fast + 0.15).timeout
	assert_almost_eq(c.scale.x, 1.0, 0.02, "release must settle at exactly 1.0")


func test_pop_in_makes_a_hidden_node_visible_at_unit_scale() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	Juice.pop_in(c)
	await Engine.get_main_loop().create_timer(tokens.dur_normal + 0.15).timeout
	assert_almost_eq(c.scale.x, 1.0, 0.03, "pop_in ends at unit scale")
	assert_almost_eq(c.modulate.a, 1.0, 0.03, "pop_in ends fully opaque")


func test_count_up_lands_exactly_on_the_target() -> void:
	# Off-by-one on a displayed stat is the kind of bug players screenshot.
	var tokens := DesignTokens.load_default()
	var label := Label.new()
	_root.add_child(label)
	Juice.count_up(label, 0.0, 87.0)
	await Engine.get_main_loop().create_timer(tokens.dur_slow + 0.2).timeout
	assert_eq(label.text, "87", "count_up must end on the exact target")


func test_count_up_respects_the_format_string() -> void:
	var tokens := DesignTokens.load_default()
	var label := Label.new()
	_root.add_child(label)
	Juice.count_up(label, 0.0, 42.0, "%d%%")
	await Engine.get_main_loop().create_timer(tokens.dur_slow + 0.2).timeout
	assert_eq(label.text, "42%", "format string must be applied")


func test_fill_bar_lands_on_the_target_value() -> void:
	var tokens := DesignTokens.load_default()
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	_root.add_child(bar)
	Juice.fill_bar(bar, 73.5)
	await Engine.get_main_loop().create_timer(tokens.dur_slow + 0.2).timeout
	assert_almost_eq(bar.value, 73.5, 0.01, "bar must land on target")


func test_stagger_in_eventually_shows_every_node() -> void:
	var tokens := DesignTokens.load_default()
	var nodes: Array[Control] = []
	for i in range(5):
		nodes.append(_make_control())
	Juice.stagger_in(nodes)
	var total := tokens.stagger_step * 5.0 + tokens.dur_normal + 0.2
	await Engine.get_main_loop().create_timer(total).timeout
	for i in nodes.size():
		assert_almost_eq(nodes[i].modulate.a, 1.0, 0.03,
			"staggered node %d must end visible" % i)


func test_stagger_in_tolerates_an_empty_array() -> void:
	Juice.stagger_in([])
	assert_true(true, "empty stagger must not crash")


func test_helpers_tolerate_freed_nodes() -> void:
	# Scene changes free nodes mid-tween all the time.
	var c := _make_control()
	c.free()
	Juice.press(c)
	Juice.release(c)
	Juice.pop_in(c)
	assert_true(true, "juice on a freed node must be a no-op, not a crash")


func test_shake_returns_the_node_to_its_start_position() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	c.position = Vector2(50, 60)
	Juice.shake(c)
	await Engine.get_main_loop().create_timer(tokens.dur_normal + 0.25).timeout
	assert_almost_eq(c.position.x, 50.0, 0.5, "shake must restore x")
	assert_almost_eq(c.position.y, 60.0, 0.5, "shake must restore y")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "juice"`.

Expected: FAIL — `Identifier "Juice" not declared`.

- [ ] **Step 3: Write the Juice library**

Create `Scripts/Design/Juice.gd`:

```gdscript
class_name Juice
extends RefCounted

## The motion vocabulary. Every animation in the game goes through here
## so timing and easing stay consistent, and so a designer can retune
## the whole game's feel from design_tokens.tres.
##
## All methods are no-ops on freed or null nodes — scene changes free
## nodes mid-tween constantly and that must never produce an error.

## Set this meta on a Button to exclude it from UIPolish auto-juicing.
const NO_AUTO_JUICE := &"no_auto_juice"

static var _tokens: DesignTokens


static func tokens() -> DesignTokens:
	if _tokens == null:
		_tokens = DesignTokens.load_default()
	return _tokens


static func _alive(node: Object) -> bool:
	return node != null and is_instance_valid(node)


## Scale tweens grow from pivot_offset. Without centering, a button
## visibly slides down-right as it scales instead of pulsing in place.
static func set_pivot_center(node: Control) -> void:
	if not _alive(node):
		return
	node.pivot_offset = node.size * 0.5


static func press(node: Control) -> void:
	if not _alive(node):
		return
	var t := tokens()
	set_pivot_center(node)
	var tw := node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale",
		Vector2(t.press_scale, t.press_scale), t.dur_instant)


static func release(node: Control) -> void:
	if not _alive(node):
		return
	var t := tokens()
	set_pivot_center(node)
	var tw := node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, t.dur_fast)


static func pop_in(node: Control, delay: float = 0.0) -> void:
	if not _alive(node):
		return
	var t := tokens()
	set_pivot_center(node)
	node.scale = Vector2(0.82, 0.82)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, t.dur_normal) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)
	tw.tween_property(node, "modulate:a", 1.0, t.dur_fast) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)


static func fade_in(node: CanvasItem, delay: float = 0.0) -> void:
	if not _alive(node):
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, tokens().dur_normal) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)


## Reveal a list one item at a time. `step` defaults to tokens.stagger_step.
static func stagger_in(nodes: Array, step: float = -1.0) -> void:
	var t := tokens()
	var gap := t.stagger_step if step < 0.0 else step
	var i := 0
	for node in nodes:
		if node is Control and _alive(node):
			pop_in(node, float(i) * gap)
			i += 1


## Animate a number rolling up to its new value. Always lands exactly on
## `to` — the final tween_callback guarantees it, because float easing
## alone would leave "86" where the design says "87".
static func count_up(label: Label, from: float, to: float, fmt: String = "%d") -> void:
	if not _alive(label):
		return
	var t := tokens()
	var holder := {"v": from}
	label.text = fmt % int(round(from))
	var tw := label.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(
		func(v: float) -> void:
			if _alive(label):
				label.text = fmt % int(round(v)),
		from, to, t.dur_slow)
	tw.tween_callback(func() -> void:
		if _alive(label):
			label.text = fmt % int(round(to)))


static func fill_bar(bar: Range, to: float) -> void:
	if not _alive(bar):
		return
	var tw := bar.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(bar, "value", to, tokens().dur_slow)


## Horizontal shake for rejection/error feedback. Returns the node to
## its exact starting position so repeated shakes never drift it.
static func shake(node: Control, strength: float = 12.0) -> void:
	if not _alive(node):
		return
	var t := tokens()
	var origin := node.position
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	var step := t.dur_normal / 6.0
	for i in range(3):
		var s := strength * (1.0 - float(i) / 3.0)
		tw.tween_property(node, "position", origin + Vector2(s, 0), step)
		tw.tween_property(node, "position", origin - Vector2(s, 0), step)
	tw.tween_property(node, "position", origin, step)
```

- [ ] **Step 4: Run the juice tests to verify they pass**

`test_run` with `suite: "juice"`.

Expected: 11 tests, all PASS. These tests use real timers, so the suite takes a few seconds — that is normal.

- [ ] **Step 5: Write the UIPolish autoload**

Create `Scripts/UI/UIPolish.gd`. This is what makes every button in nine scenes feel responsive without editing nine scenes:

```gdscript
extends Node

## Auto-applies press feedback and tap SFX to every BaseButton in the
## tree, so individual scenes never have to wire it up.
##
## Opt a button out with:
##     my_button.set_meta(Juice.NO_AUTO_JUICE, true)
## which is what you want for buttons that are full-screen invisible
## click-catchers (e.g. AturJadwal's ColorRect/ClickArea), where a
## scale pulse would visibly distort the whole overlay.

@export var enabled: bool = true
## Buttons larger than this in either axis are treated as invisible
## click-catchers and skipped automatically.
@export var max_juiced_size: Vector2 = Vector2(900, 900)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Catch anything already present when this autoload initializes.
	_scan(get_tree().root)


func _scan(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	if not enabled or not (node is BaseButton):
		return
	var button := node as BaseButton
	if button.has_meta(Juice.NO_AUTO_JUICE):
		return
	# Wire once. Reparenting fires node_added again.
	if button.button_down.is_connected(_on_button_down):
		return
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _skip(button: BaseButton) -> bool:
	return button.size.x > max_juiced_size.x or button.size.y > max_juiced_size.y


func _on_button_down(button: BaseButton) -> void:
	if _skip(button):
		return
	Juice.press(button)


func _on_button_up(button: BaseButton) -> void:
	if _skip(button):
		return
	Juice.release(button)


func _on_button_pressed(button: BaseButton) -> void:
	AudioDirector.play_sfx(&"tap")
```

Note: `_on_button_down.bind(button)` produces a distinct Callable each time, so the `is_connected(_on_button_down)` guard will not match. Use an explicit meta flag instead — replace the guard in `_on_node_added` with:

```gdscript
	if button.has_meta(&"_uipolish_wired"):
		return
	button.set_meta(&"_uipolish_wired", true)
```

- [ ] **Step 6: Register the UIPolish autoload**

In `project.godot` `[autoload]`, after `AudioDirector` (it calls into it):

```
UIPolish="*res://Scripts/UI/UIPolish.gd"
```

- [ ] **Step 7: Verify press feedback works in the running game**

`project_run`, advance to MainMenu, and press and hold the PLAY button while taking a `game_manage` screenshot.

Expected: the button visibly shrinks while held and bounces back on release. Check `logs_read` for errors — particularly any "signal already connected" spam, which means the meta guard from Step 5 was not applied.

- [ ] **Step 8: Verify the opt-out works**

Add to `Scripts/AturJadwal/atur_jadwal.gd`, in `_ready()`, before any other setup:

```gdscript
	# Full-screen invisible click-catcher: a scale pulse would visibly
	# distort the whole overlay.
	$ColorRect/ClickArea.set_meta(Juice.NO_AUTO_JUICE, true)
```

Run the scene and confirm tapping the dimmed overlay does not produce a scale pulse.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Design/Juice.gd Scripts/UI/UIPolish.gd tests/test_juice.gd \
        project.godot Scripts/AturJadwal/atur_jadwal.gd
git commit -m "feat(motion): add Juice library and UIPolish auto-feedback autoload"
```

---

# Task 7: Safe Area and StatBar Component

**Files:**
- Create: `Scripts/UI/SafeAreaMargin.gd`
- Create: `Scripts/UI/StatBar.gd`
- Test: `tests/test_ui_components.gd`

**Interfaces:**
- Consumes: `DesignTokens` (`screen_margin`, category colors), `Juice.fill_bar`, `Juice.count_up`.
- Produces:
  - `class_name SafeAreaMargin extends MarginContainer` — applies device safe-area insets plus `tokens.screen_margin`. Exports `use_safe_area: bool`, `extra_margin: Vector4`.
  - `class_name StatBar extends ProgressBar` — exports `category: String`, `show_value_label: bool`, `value_format: String`; method `set_stat(value: float, animate: bool = true) -> void`.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_ui_components.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "ui_components"

var _root: Control


func setup() -> void:
	_root = Control.new()
	_root.size = Vector2(1080, 1920)
	Engine.get_main_loop().root.add_child(_root)
	track(_root)


func teardown() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null


func test_safe_area_applies_at_least_the_screen_margin() -> void:
	var m := SafeAreaMargin.new()
	_root.add_child(m)
	await Engine.get_main_loop().process_frame
	var tokens := DesignTokens.load_default()
	# On desktop the safe area equals the window, so insets are zero and
	# only screen_margin applies. That is the floor we assert.
	assert_true(m.get_theme_constant("margin_left") >= tokens.screen_margin,
		"left margin must be at least screen_margin")
	assert_true(m.get_theme_constant("margin_top") >= tokens.screen_margin,
		"top margin must be at least screen_margin")


func test_safe_area_can_be_disabled() -> void:
	var m := SafeAreaMargin.new()
	m.use_safe_area = false
	_root.add_child(m)
	await Engine.get_main_loop().process_frame
	var tokens := DesignTokens.load_default()
	assert_eq(m.get_theme_constant("margin_left"), tokens.screen_margin,
		"with safe area off, margin is exactly screen_margin")


func test_statbar_tints_itself_from_its_category() -> void:
	var tokens := DesignTokens.load_default()
	var bar := StatBar.new()
	bar.category = "Olahraga"
	_root.add_child(bar)
	await Engine.get_main_loop().process_frame
	assert_eq(bar.self_modulate, tokens.cat_olahraga,
		"StatBar tints via self_modulate from the category token")


func test_statbar_uses_the_theme_variation() -> void:
	var bar := StatBar.new()
	_root.add_child(bar)
	await Engine.get_main_loop().process_frame
	assert_eq(bar.theme_type_variation, &"StatBar",
		"StatBar must opt into its theme variation automatically")


func test_set_stat_without_animation_is_immediate() -> void:
	var bar := StatBar.new()
	_root.add_child(bar)
	bar.set_stat(64.0, false)
	assert_almost_eq(bar.value, 64.0, 0.001, "unanimated set is immediate")


func test_set_stat_with_animation_reaches_the_target() -> void:
	var tokens := DesignTokens.load_default()
	var bar := StatBar.new()
	_root.add_child(bar)
	bar.set_stat(88.0, true)
	await Engine.get_main_loop().create_timer(tokens.dur_slow + 0.2).timeout
	assert_almost_eq(bar.value, 88.0, 0.05, "animated set reaches target")


func test_set_stat_clamps_out_of_range_input() -> void:
	# Stats are computed from decay math that can overshoot.
	var bar := StatBar.new()
	_root.add_child(bar)
	bar.set_stat(150.0, false)
	assert_almost_eq(bar.value, 100.0, 0.001, "clamps above max_value")
	bar.set_stat(-20.0, false)
	assert_almost_eq(bar.value, 0.0, 0.001, "clamps below min_value")


func test_statbar_value_label_tracks_the_value() -> void:
	var tokens := DesignTokens.load_default()
	var bar := StatBar.new()
	bar.show_value_label = true
	_root.add_child(bar)
	await Engine.get_main_loop().process_frame
	bar.set_stat(77.0, true)
	await Engine.get_main_loop().create_timer(tokens.dur_slow + 0.25).timeout
	var label := bar.get_node_or_null("ValueLabel") as Label
	assert_not_null(label, "show_value_label must create a ValueLabel child")
	assert_eq(label.text, "77", "label must land on the exact value")


func test_unknown_category_still_renders_visibly() -> void:
	var bar := StatBar.new()
	bar.category = "KategoriTidakDikenal"
	_root.add_child(bar)
	await Engine.get_main_loop().process_frame
	assert_true(bar.self_modulate.a > 0.0,
		"an unknown category must never render the bar invisible")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "ui_components"`.

Expected: FAIL — `Identifier "SafeAreaMargin" not declared`.

- [ ] **Step 3: Write SafeAreaMargin**

Create `Scripts/UI/SafeAreaMargin.gd`:

```gdscript
@tool
class_name SafeAreaMargin
extends MarginContainer

## A MarginContainer that keeps its contents clear of notches, punch
## holes, and gesture bars, plus the project's standard screen margin.
##
## Wrap the top-level content of every full-screen scene in one of these.

## Turn off to apply only extra_margin + screen_margin, ignoring the device.
@export var use_safe_area: bool = true:
	set(value):
		use_safe_area = value
		_apply()

## Per-side additional margin, in the order (left, top, right, bottom).
@export var extra_margin: Vector4 = Vector4.ZERO:
	set(value):
		extra_margin = value
		_apply()


func _ready() -> void:
	_apply()
	get_tree().root.size_changed.connect(_apply)


func _apply() -> void:
	if not is_inside_tree():
		return
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return

	var base := float(tokens.screen_margin)
	var inset := Vector4.ZERO

	if use_safe_area:
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		# get_display_safe_area returns physical screen pixels; scale into
		# the project's 1080-wide reference space or the insets come out
		# far too small on a high-DPI phone.
		var scale_x := float(size.x) / maxf(float(win.x), 1.0)
		var scale_y := float(size.y) / maxf(float(win.y), 1.0)
		inset = Vector4(
			float(safe.position.x) * scale_x,
			float(safe.position.y) * scale_y,
			float(win.x - safe.end.x) * scale_x,
			float(win.y - safe.end.y) * scale_y)

	add_theme_constant_override("margin_left",
		int(base + inset.x + extra_margin.x))
	add_theme_constant_override("margin_top",
		int(base + inset.y + extra_margin.y))
	add_theme_constant_override("margin_right",
		int(base + inset.z + extra_margin.z))
	add_theme_constant_override("margin_bottom",
		int(base + inset.w + extra_margin.w))
```

- [ ] **Step 4: Write StatBar**

Create `Scripts/UI/StatBar.gd`:

```gdscript
@tool
class_name StatBar
extends ProgressBar

## An animated, category-tinted stat bar. Replaces the ad-hoc
## ProgressBar + ValueLabel pairs currently duplicated across
## AturJadwal, SemesterEnd, and StudentCard.

## One of: Akademis, Olahraga, SeniBudaya, Istirahat, Libur.
## Anything else falls back to text_secondary — never invisible.
@export var category: String = "Akademis":
	set(value):
		category = value
		_apply_tint()

@export var show_value_label: bool = false:
	set(value):
		show_value_label = value
		_sync_label()

## printf format for the value label. Use "%d%%" for a percentage.
@export var value_format: String = "%d"

var _label: Label


func _ready() -> void:
	theme_type_variation = &"StatBar"
	show_percentage = false
	min_value = 0.0
	max_value = 100.0
	_apply_tint()
	_sync_label()


func _apply_tint() -> void:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	# The theme's fill stylebox is white, so self_modulate is the tint.
	self_modulate = tokens.category_color(category)


func _sync_label() -> void:
	if not is_inside_tree():
		return
	if show_value_label and _label == null:
		_label = Label.new()
		_label.name = "ValueLabel"
		_label.theme_type_variation = &"CaptionLabel"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		_label.text = value_format % int(round(value))
	elif not show_value_label and _label != null:
		_label.queue_free()
		_label = null


## Set the bar's value, optionally animating the fill and the label
## count-up together. Input is clamped: decay math upstream can overshoot.
func set_stat(new_value: float, animate: bool = true) -> void:
	var target := clampf(new_value, min_value, max_value)
	if animate:
		var previous := value
		Juice.fill_bar(self, target)
		if _label != null:
			Juice.count_up(_label, previous, target, value_format)
	else:
		value = target
		if _label != null:
			_label.text = value_format % int(round(target))
```

- [ ] **Step 5: Run the tests to verify they pass**

`test_run` with `suite: "ui_components"`.

Expected: 9 tests, all PASS.

- [ ] **Step 6: Run the whole suite for regressions**

`test_run` with no suite filter, running everything in `res://tests/`.

Expected: 45 tests across 5 suites, all PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/UI/SafeAreaMargin.gd Scripts/UI/StatBar.gd tests/test_ui_components.gd
git commit -m "feat(ui): add SafeAreaMargin and animated StatBar components"
```

---

# Task 8: Transition Rewrite

**Files:**
- Modify: `Scripts/Transition/transition.gd`
- Modify: `Scenes/Transition/transition.tscn`
- Test: `tests/test_transition.gd`

**Interfaces:**
- Consumes: `DesignTokens` (`brand_primary`, `dur_*`), `AudioDirector.play_sfx(&"whoosh")`.
- Produces: the `Transition` autoload keeps its existing signature `change_scene(path: String) -> void` — **21 existing call sites depend on it and must not break.** Adds:
  - `Transition.change_scene(path: String, style: Style = Style.WIPE) -> void`
  - `enum Style { WIPE, FADE, IRIS }`
  - `signal scene_changed(path: String)`

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_transition.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "transition"


func test_autoload_exists() -> void:
	var t := Engine.get_main_loop().root.get_node_or_null("transition")
	assert_not_null(t, "the Transition autoload must be in the tree")


func test_change_scene_still_accepts_a_single_argument() -> void:
	# 21 existing call sites use Transition.change_scene(path). Adding
	# the style parameter must not break any of them.
	var t := Engine.get_main_loop().root.get_node("transition")
	var found := false
	for m in t.get_method_list():
		if m.name == "change_scene":
			found = true
			assert_true(m.args.size() >= 1, "change_scene takes a path")
			assert_true(m.default_args.size() >= 1,
				"the style parameter must have a default so 1-arg calls work")
	assert_true(found, "change_scene must exist")


func test_style_enum_covers_all_three_styles() -> void:
	var t := Engine.get_main_loop().root.get_node("transition")
	assert_true(t.Style.has("WIPE"), "Style.WIPE")
	assert_true(t.Style.has("FADE"), "Style.FADE")
	assert_true(t.Style.has("IRIS"), "Style.IRIS")


func test_scene_changed_signal_exists() -> void:
	var t := Engine.get_main_loop().root.get_node("transition")
	assert_true(t.has_signal("scene_changed"),
		"screens need a hook to start their entry animation")


func test_transition_layer_is_above_everything() -> void:
	var t := Engine.get_main_loop().root.get_node("transition")
	assert_true(t.layer >= 100,
		"the transition must draw above all game content")


func test_overlay_does_not_block_input_when_idle() -> void:
	# A transition overlay left hit-testable makes the whole game
	# unclickable — the single worst failure mode for this node.
	var t := Engine.get_main_loop().root.get_node("transition")
	var rect := t.get_node_or_null("ColorRect") as Control
	assert_not_null(rect, "ColorRect must exist")
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay must never intercept taps")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "transition"`.

Expected: FAIL on `test_style_enum_covers_all_three_styles` — no `Style` enum yet.

- [ ] **Step 3: Rewrite the transition script**

Replace `Scripts/Transition/transition.gd` entirely:

```gdscript
extends CanvasLayer

## Scene transitions. Autoloaded as `Transition`.
##
## change_scene(path) keeps its original one-argument form because 21
## call sites across the project use it. The style parameter is optional.

enum Style { WIPE, FADE, IRIS }

## Emitted after the new scene is loaded and the cover has retracted.
## Screens connect to this to start their entry animations.
signal scene_changed(path: String)

@export_group("Appearance")
## Color of the cover. Defaults to brand_primary from the design tokens.
@export var cover_color: Color = Color("2e5bff")
@export var default_style: Style = Style.WIPE

@onready var _cover: ColorRect = $ColorRect

var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tokens := DesignTokens.load_default()
	if tokens != null:
		cover_color = tokens.brand_primary
	_cover.color = cover_color
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_cover()


func _reset_cover() -> void:
	_cover.modulate.a = 0.0
	_cover.scale = Vector2.ONE
	_cover.position = Vector2.ZERO


func change_scene(path: String, style: Style = Style.WIPE) -> void:
	# Guard against double-taps firing two transitions at once, which
	# would change scene twice and strand the cover on screen.
	if _busy:
		return
	_busy = true

	AudioDirector.play_sfx(&"whoosh")
	await _cover_in(style)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Transition: failed to load %s (error %d)" % [path, err])

	# One frame so the incoming scene's _ready has run and it can paint
	# before the cover retracts, otherwise the first frame flashes.
	await get_tree().process_frame

	await _cover_out(style)
	_busy = false
	scene_changed.emit(path)


func _durations() -> Array:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return [0.32, 0.32]
	return [tokens.dur_normal, tokens.dur_normal]


func _cover_in(style: Style) -> void:
	var d: float = _durations()[0]
	var viewport := get_viewport().get_visible_rect().size
	var tw := create_tween()
	match style:
		Style.FADE:
			_cover.position = Vector2.ZERO
			tw.tween_property(_cover, "modulate:a", 1.0, d) \
				.set_ease(Tween.EASE_IN_OUT)
		Style.IRIS:
			_cover.modulate.a = 1.0
			_cover.pivot_offset = viewport * 0.5
			_cover.scale = Vector2(1.6, 1.6)
			tw.tween_property(_cover, "scale", Vector2.ONE, d) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_:
			# WIPE: the cover sweeps in from the right edge.
			_cover.modulate.a = 1.0
			_cover.position = Vector2(viewport.x, 0)
			tw.tween_property(_cover, "position", Vector2.ZERO, d) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished


func _cover_out(style: Style) -> void:
	var d: float = _durations()[1]
	var viewport := get_viewport().get_visible_rect().size
	var tw := create_tween()
	match style:
		Style.FADE:
			tw.tween_property(_cover, "modulate:a", 0.0, d) \
				.set_ease(Tween.EASE_IN_OUT)
		Style.IRIS:
			tw.tween_property(_cover, "scale", Vector2(1.6, 1.6), d) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.parallel().tween_property(_cover, "modulate:a", 0.0, d)
		_:
			# WIPE: continues sweeping off the left edge.
			tw.tween_property(_cover, "position", Vector2(-viewport.x, 0), d) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	_reset_cover()
```

- [ ] **Step 4: Simplify the transition scene**

The `AnimationPlayer` and its three animations are no longer used — the script tweens directly. Replace `Scenes/Transition/transition.tscn` entirely:

```
[gd_scene load_steps=2 format=3 uid="uid://oy267w61wjfa"]

[ext_resource type="Script" path="res://Scripts/Transition/transition.gd" id="1_4dhrd"]

[node name="transition" type="CanvasLayer"]
script = ExtResource("1_4dhrd")

[node name="ColorRect" type="ColorRect" parent="."]
modulate = Color(1, 1, 1, 0)
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.18, 0.357, 1, 1)
```

Keep the `uid://oy267w61wjfa` — `project.godot` and the editor reference it.

- [ ] **Step 5: Run the tests to verify they pass**

`test_run` with `suite: "transition"`.

Expected: 6 tests, all PASS.

- [ ] **Step 6: Verify every existing call site still works**

There are 21 `Transition.change_scene(...)` calls. Confirm none pass a second argument that would now collide:

```bash
grep -rn "Transition.change_scene" Scripts --include=*.gd | grep -c ","
```

Expected: `0` — every existing call passes only a path.

- [ ] **Step 7: Verify transitions visually in the running game**

`project_run`. Walk Splashscreen → Loading → MainMenu → (PLAY) → CutScene.

Expected: a brand-blue panel sweeps in from the right, the scene swaps under it, and it continues off to the left. No black flash, no stranded cover, and the game remains clickable afterward. Check `logs_read` for errors.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Transition/transition.gd Scenes/Transition/transition.tscn tests/test_transition.gd
git commit -m "feat(motion): replace black fade with wipe/fade/iris transitions"
```

---

# Task 9: MainMenu Rebuild — The Reference Screen

This screen is rebuilt rather than migrated. It has only 4 `theme_override`s and uses absolute pixel offsets with no containers, so there is nothing worth preserving. It becomes the reference implementation every later migration copies.

**Files:**
- Rewrite: `Scenes/MainMenu/main_menu.tscn`
- Rewrite: `Scripts/MainMenu/main_menu.gd`
- Test: `tests/test_main_menu.gd`

**Interfaces:**
- Consumes: `SafeAreaMargin`, `Juice.stagger_in`, `Juice.pop_in`, `AudioDirector.play_bgm(&"menu")`, `Transition.change_scene`, theme variations `DisplayLabel` / `PrimaryButton` / `SecondaryButton`.
- Produces: the layout pattern (`SafeAreaMargin > VBoxContainer` with theme variations and zero `theme_override_*`) that Tasks 10–17 replicate. Also produces the working route to Settings, consumed by Task 18.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_main_menu.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "main_menu"

var _menu: Control


func setup() -> void:
	var scene: PackedScene = load("res://Scenes/MainMenu/main_menu.tscn")
	_menu = scene.instantiate()
	Engine.get_main_loop().root.add_child(_menu)
	track(_menu)


func teardown() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func test_scene_has_no_theme_overrides() -> void:
	# The whole point of centralization: this scene must be styled
	# entirely by the project theme.
	var offenders: Array[String] = []
	_collect_overrides(_menu, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		if not c.get_theme_font_size_override_list().is_empty() \
				or not c.get_theme_color_override_list().is_empty() \
				or not c.get_theme_stylebox_override_list().is_empty():
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_content_is_wrapped_in_a_safe_area() -> void:
	var safe := _menu.find_child("SafeArea", true, false)
	assert_not_null(safe, "top-level content must sit inside a SafeAreaMargin")
	assert_true(safe is SafeAreaMargin, "must be a SafeAreaMargin")


func test_all_three_buttons_exist_and_are_wired() -> void:
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as BaseButton
		assert_not_null(b, "missing button: " + name)
		assert_true(b.pressed.get_connections().size() > 0,
			name + " must have a pressed handler")


func test_buttons_use_theme_variations_not_default_styling() -> void:
	var play := _menu.find_child("PlayButton", true, false) as Button
	assert_eq(play.theme_type_variation, &"PrimaryButton",
		"the main CTA is a PrimaryButton")
	var setting := _menu.find_child("SettingButton", true, false) as Button
	assert_eq(setting.theme_type_variation, &"SecondaryButton",
		"secondary actions are SecondaryButtons")


func test_buttons_meet_the_minimum_touch_target() -> void:
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var tokens := DesignTokens.load_default()
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as Control
		assert_true(b.size.y >= float(tokens.touch_target_min),
			"%s is %d px tall, below the %d px minimum"
				% [name, int(b.size.y), tokens.touch_target_min])


func test_button_labels_are_indonesian() -> void:
	# The rest of the game is Indonesian; PLAY/SETTING/QUIT were leftovers.
	var play := _menu.find_child("PlayButton", true, false) as Button
	assert_eq(play.text, "MULAI", "play button")
	var setting := _menu.find_child("SettingButton", true, false) as Button
	assert_eq(setting.text, "PENGATURAN", "setting button")
	var quit := _menu.find_child("QuitButton", true, false) as Button
	assert_eq(quit.text, "KELUAR", "quit button")


func test_layout_uses_containers_not_absolute_offsets() -> void:
	# Absolute offsets are why this screen breaks on other aspect ratios.
	var play := _menu.find_child("PlayButton", true, false) as Control
	var parent := play.get_parent()
	assert_true(parent is BoxContainer,
		"buttons must be laid out by a container, not pixel offsets")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "main_menu"`.

Expected: multiple failures — no SafeArea, English labels, absolute offsets.

- [ ] **Step 3: Rewrite the scene**

Replace `Scenes/MainMenu/main_menu.tscn` entirely. Keep the `uid` — `DebugManager.gd:1177` and `GameState.gd:4` reference the path, and `Splashscreen` routes here:

```
[gd_scene load_steps=4 format=3 uid="uid://b2vxniec67375"]

[ext_resource type="Script" path="res://Scripts/MainMenu/main_menu.gd" id="1_ftydy"]
[ext_resource type="Script" path="res://Scripts/UI/SafeAreaMargin.gd" id="2_safe"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/BG.jpg" id="3_bg"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_ftydy")

[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("3_bg")
expand_mode = 1
stretch_mode = 6

[node name="SafeArea" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("2_safe")

[node name="Layout" type="VBoxContainer" parent="SafeArea"]
layout_mode = 2

[node name="TitleSpacer" type="Control" parent="SafeArea/Layout"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 0.6

[node name="TitleLabel" type="Label" parent="SafeArea/Layout"]
layout_mode = 2
theme_type_variation = &"DisplayLabel"
text = "KEJARTES"
horizontal_alignment = 1

[node name="SubtitleLabel" type="Label" parent="SafeArea/Layout"]
layout_mode = 2
theme_type_variation = &"CaptionLabel"
text = "Bimbing muridmu sampai akhir semester"
horizontal_alignment = 1

[node name="MidSpacer" type="Control" parent="SafeArea/Layout"]
layout_mode = 2
size_flags_vertical = 3

[node name="ButtonColumn" type="VBoxContainer" parent="SafeArea/Layout"]
layout_mode = 2

[node name="PlayButton" type="Button" parent="SafeArea/Layout/ButtonColumn"]
layout_mode = 2
theme_type_variation = &"PrimaryButton"
text = "MULAI"

[node name="SettingButton" type="Button" parent="SafeArea/Layout/ButtonColumn"]
layout_mode = 2
theme_type_variation = &"SecondaryButton"
text = "PENGATURAN"

[node name="QuitButton" type="Button" parent="SafeArea/Layout/ButtonColumn"]
layout_mode = 2
theme_type_variation = &"SecondaryButton"
text = "KELUAR"

[node name="BottomSpacer" type="Control" parent="SafeArea/Layout"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 0.4

[node name="VersionLabel" type="Label" parent="SafeArea/Layout"]
layout_mode = 2
theme_type_variation = &"MicroLabel"
text = "v0.1"
horizontal_alignment = 1
```

Container separation and button min-heights come from the theme, set in Step 5 — **not** from `theme_override`s in this file, which the test forbids.

- [ ] **Step 4: Rewrite the script**

Replace `Scripts/MainMenu/main_menu.gd`:

```gdscript
extends Control

@onready var _title: Label = $SafeArea/Layout/TitleLabel
@onready var _subtitle: Label = $SafeArea/Layout/SubtitleLabel
@onready var _buttons: VBoxContainer = $SafeArea/Layout/ButtonColumn
@onready var _play_button: Button = $SafeArea/Layout/ButtonColumn/PlayButton
@onready var _setting_button: Button = $SafeArea/Layout/ButtonColumn/SettingButton
@onready var _quit_button: Button = $SafeArea/Layout/ButtonColumn/QuitButton
@onready var _version: Label = $SafeArea/Layout/VersionLabel


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_setting_button.pressed.connect(_on_setting_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_version.text = "v" + str(ProjectSettings.get_setting(
		"application/config/version", "0.1"))

	AudioDirector.play_bgm(&"menu")
	_animate_entry()


func _animate_entry() -> void:
	Juice.pop_in(_title)
	Juice.fade_in(_subtitle, Juice.tokens().dur_fast)
	# Buttons cascade in after the title lands.
	var delay := Juice.tokens().dur_normal
	var items: Array = []
	for child in _buttons.get_children():
		items.append(child)
	await get_tree().create_timer(delay).timeout
	Juice.stagger_in(items)


func _on_play_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn")


func _on_setting_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/UI/Settings.tscn", Transition.Style.FADE)


func _on_quit_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	get_tree().quit()
```

`_on_setting_pressed` targets a scene that does not exist until Task 18. Until then it logs a load error rather than crashing, which is acceptable — but **Task 18 must not be skipped**.

- [ ] **Step 5: Add container and button sizing to the theme**

`test_buttons_meet_the_minimum_touch_target` and the spacing both come from the theme, not the scene. Add to `ThemeFactory._build_base_overrides`:

```gdscript
	theme.set_constant("separation", "VBoxContainer", tokens.space_md)
	theme.set_constant("separation", "HBoxContainer", tokens.space_sm)
	theme.set_constant("margin_left", "MarginContainer", tokens.screen_margin)
	theme.set_constant("margin_right", "MarginContainer", tokens.screen_margin)
	theme.set_constant("margin_top", "MarginContainer", tokens.screen_margin)
	theme.set_constant("margin_bottom", "MarginContainer", tokens.screen_margin)
```

The `touch_target_min` height comes from the pill's content margins, already asserted in Task 3's `test_buttons_meet_minimum_touch_target`. If MainMenu's buttons still measure under 96 px, raise `space_md` in `design_tokens.tres` (do **not** add a per-scene override).

- [ ] **Step 6: Rebake the theme**

Run `Scripts/Design/BakeTheme.gd` via File > Run.

- [ ] **Step 7: Run the tests to verify they pass**

`test_run` with `suite: "main_menu"`.

Expected: 7 tests, all PASS.

- [ ] **Step 8: Verify visually against the baseline**

`scene_open` on `res://Scenes/MainMenu/main_menu.tscn`, then `editor_screenshot`. Compare with `docs/superpowers/baseline/03-mainmenu.png`.

Expected: centered title in Fredoka with a white outline, three pill buttons with the brand gradient and white rims, generous spacing, a background image, and a version label at the bottom. Nothing clipped at any edge.

- [ ] **Step 9: Verify motion in the running game**

`project_run`, advance to MainMenu.

Expected: the title pops in, the subtitle fades, then the three buttons cascade in one after another. Holding a button shrinks it; releasing bounces it back.

- [ ] **Step 10: Save this as the reference screenshot**

Save the MainMenu screenshot to `docs/superpowers/design/reference-mainmenu.png`. Tasks 10–17 match this screen's spacing rhythm, corner radii, and outline weight.

- [ ] **Step 11: Commit**

```bash
git add Scenes/MainMenu Scripts/MainMenu tests/test_main_menu.gd \
        Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres \
        docs/superpowers/design/reference-mainmenu.png
git commit -m "feat(ui): rebuild MainMenu as the themed reference screen"
```

---

# Tasks 10–17: Per-Screen Migration

Tasks 10–17 all follow the **same procedure**, differing only in target and specifics. The procedure is written out once here; each task then lists its own specifics. **Read this procedure at the start of every one of Tasks 10–17** — do not assume you remember it.

## The Migration Procedure

- [ ] **Step A: Inventory the overrides**

```bash
grep -n "theme_override" <scene path> | sed 's/=.*//' | sort | uniq -c | sort -rn
```

Record the count. This is the number the task must drive to zero (or to a documented, justified remainder).

- [ ] **Step B: Write the failing test**

Create `tests/test_<screen>.gd` with, at minimum, these four tests. Copy the `_collect_overrides` helper from `tests/test_main_menu.gd` verbatim — do not import it, each suite is standalone:

```gdscript
func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_scene, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))

func test_scene_instantiates_without_errors() -> void:
	assert_not_null(_scene, "scene must instantiate")

func test_interactive_controls_meet_touch_minimum() -> void:
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var tokens := DesignTokens.load_default()
	var small: Array[String] = []
	_collect_small_buttons(_scene, tokens.touch_target_min, small)
	assert_eq(small.size(), 0, "buttons below touch minimum: " + ", ".join(small))

func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string("<script path>")
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")
```

- [ ] **Step C: Run the test to verify it fails**

`test_run` with the suite name. Expected: FAIL, listing the override-bearing nodes.

- [ ] **Step D: Map each override to a token or variation**

Build a mapping table. Every override falls into exactly one of four buckets:

| Override kind | Replacement |
|---|---|
| `theme_override_font_sizes/font_size` | `theme_type_variation = &"<nearest label variation>"` |
| `theme_override_colors/font_color` | the variation's color, or `DesignTokens.category_color()` set from script |
| `theme_override_styles/*` (inline StyleBoxFlat) | `theme_type_variation = &"Card"` / `&"SunkenPanel"` / `&"PrimaryButton"` etc. |
| A value with no theme equivalent | **Add a new variation to ThemeFactory** and rebake. Never leave it as an override. |

Write the table into the task's commit message body.

- [ ] **Step E: Strip the overrides from the scene**

Remove the `theme_override_*` lines and inline `[sub_resource type="StyleBox*"]` blocks, and add `theme_type_variation` to the corresponding nodes.

- [ ] **Step F: Replace `Color(...)` literals in the script**

Add at the top of the script:

```gdscript
@onready var _tokens: DesignTokens = DesignTokens.load_default()
```

Then replace each literal with the matching token property. For category tinting use `_tokens.category_color(name)`.

- [ ] **Step G: Add motion**

At minimum, per screen: `Juice.stagger_in()` on the primary list or card set in `_ready`, `Juice.count_up()` on any number that changes, `Juice.fill_bar()` on any `ProgressBar` that changes, and `AudioDirector.play_sfx()` on confirm/cancel actions. `UIPolish` already handles button press feedback — do not re-implement it per screen.

- [ ] **Step H: Run the tests**

`test_run` with the suite name. Expected: all PASS.

- [ ] **Step I: Run the full suite for regressions**

`test_run` with no filter. Expected: everything still passes.

- [ ] **Step J: Screenshot and compare**

`scene_open`, `editor_screenshot`, compare against the Task 0 baseline and the Task 9 reference. Confirm: same corner radii, same outline weight, same spacing rhythm as MainMenu.

- [ ] **Step K: Play through the screen in the running game**

`project_run`, navigate to the screen (use `DebugManager`'s level select where it is faster), exercise every interactive control, and read `logs_read`. Expected: no new errors, and the screen's function is **unchanged** — this is a polish pass, not a behavior change.

- [ ] **Step L: Commit**

```bash
git add <scene> <script> tests/test_<screen>.gd
git commit -m "style(<screen>): migrate to centralized theme and add motion"
```

---

# Task 10: Splashscreen and Loading

**Files:**
- Modify: `Scenes/Splashscreen/Splashscreen.tscn`, `Scripts/Splashscreen/splashscreen.gd`
- Modify: `Scenes/Loading/loading.tscn`, `Scripts/Loading/loading.gd`
- Test: `tests/test_boot_screens.gd`

**Interfaces:**
- Consumes: `SafeAreaMargin`, `Juice`, `AudioDirector`, theme variations, `Transition`.
- Produces: nothing new. Both scenes keep their existing routing contract: Splashscreen sets `GameState.next_scene` then goes to Loading; Loading reads `GameState.next_scene` and changes to it.

**Specifics beyond the standard procedure:**

- **Splashscreen** (3 nodes, 0 overrides): add a `SafeAreaMargin`, set `TitleLabel` to `&"DisplayLabel"` and `HintLabel` to `&"CaptionLabel"`. Give `HintLabel` a looping pulse so "ketuk untuk lanjut" reads as interactive:

```gdscript
func _ready() -> void:
	Juice.pop_in(_title)
	var tw := _hint.create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 0.35, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_hint, "modulate:a", 1.0, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)
```

- **Loading** (4 nodes): set `LoadingBar` to `&"StatBar"`, `LoadingLabel` to `&"TitleLabel"`. The current `loading.gd` fakes a fixed 2-second bar and does not actually load anything. Replace it with a real threaded load so the bar reflects genuine progress:

```gdscript
extends Control

@onready var _bar: ProgressBar = $LoadingBar
@onready var _label: Label = $LoadingLabel

var _target_path: String


func _ready() -> void:
	_target_path = GameState.next_scene
	_label.text = "Memuat..."
	_bar.value = 0.0
	ResourceLoader.load_threaded_request(_target_path)


func _process(_delta: float) -> void:
	if _target_path.is_empty():
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_bar.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value = 100.0
			var packed := ResourceLoader.load_threaded_get(_target_path)
			_target_path = ""
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Loading: failed to load " + _target_path)
			_target_path = ""
			_label.text = "Gagal memuat"
```

Add a test asserting the bar reaches 100 and the scene changes:

```gdscript
func test_loading_reads_its_target_from_game_state() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Loading/loading.gd")
	assert_true(src.contains("GameState.next_scene"),
		"loading must route via GameState.next_scene as it does today")

func test_loading_uses_real_threaded_progress_not_a_fake_timer() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Loading/loading.gd")
	assert_true(src.contains("load_threaded_get_status"),
		"the bar must reflect genuine load progress")
```

---

# Task 11: CutScene

**Files:**
- Modify: `Scenes/CutScene/cut_scene.tscn`, `Scripts/CutScene/cut_scene.gd` (401 lines), `Scripts/CutScene/hint_label.gd`
- Test: `tests/test_cutscene.gd`

**Interfaces:**
- Consumes: theme variation `&"Card"` for the dialogue box, `DesignTokens`, `Juice`, `AudioDirector`.
- Produces: nothing new. `cut_scene.gd`'s branching to Lobby vs StudentCard (lines 361–400) is **behavior and must not change**.

**Specifics beyond the standard procedure:**

- `DialogueBox` (a `Panel`) → `theme_type_variation = &"Card"`; delete its inline stylebox if present.
- `DialogueLabel` (`RichTextLabel`) → theme-driven sizing; remove font-size overrides.
- Add a typewriter reveal using `visible_ratio` rather than character slicing, so BBCode is preserved:

```gdscript
func _reveal(text: String) -> void:
	_dialogue_label.text = text
	_dialogue_label.visible_ratio = 0.0
	var chars := float(_dialogue_label.get_total_character_count())
	var duration := chars / typewriter_chars_per_second
	var tw := _dialogue_label.create_tween()
	tw.tween_property(_dialogue_label, "visible_ratio", 1.0, duration)
	_reveal_tween = tw
```

Expose the speed in the inspector so it is tunable without code:

```gdscript
@export var typewriter_chars_per_second: float = 45.0
```

- Tapping mid-reveal must complete the line instantly rather than advancing — the standard visual-novel contract:

```gdscript
func _on_tap() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid() \
			and _dialogue_label.visible_ratio < 1.0:
		_reveal_tween.kill()
		_dialogue_label.visible_ratio = 1.0
		return
	_advance()
```

Add a test for exactly that:

```gdscript
func test_tap_during_reveal_completes_the_line_instead_of_advancing() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("visible_ratio = 1.0"),
		"a tap mid-reveal must snap the line to fully visible")
```

- Cross-fade CG changes rather than hard-cutting: tween `BgCutScene.modulate:a` to 0, swap the texture, tween back to 1 over `dur_normal`.

---

# Task 12: StudentCard

The heaviest screen: 2297-line scene, 512 overrides, 175 inline StyleBoxes, 2051-line script. **This is the single riskiest task in the plan.**

**Files:**
- Modify: `Scenes/StudentCard/student_card.tscn`, `Scripts/StudentCard/student_card.gd`
- Test: `tests/test_student_card.gd`

**Interfaces:**
- Consumes: `StatBar`, `&"Card"`, `&"PrimaryButton"`, `&"SecondaryButton"`, label variations, `DesignTokens.category_color`, `Juice.stagger_in`.
- Produces: nothing new. The selection contract is **behavior and must not change**: it writes `GameState.approved_students`, `GameState.selected_student`, `GameState.returned_from_student_card`, and routes to `res://Scenes/Lobby/loby.tscn` at line 1824.

**Specifics beyond the standard procedure:**

- [ ] **Extra Step D1: Snapshot the behavioral contract before touching anything**

Write these tests **first**, and confirm they pass against the *unmodified* scene. They are the regression net for the whole task:

```gdscript
func test_approved_students_contract_is_intact() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	for symbol in ["GameState.approved_students", "GameState.selected_student",
			"GameState.returned_from_student_card"]:
		assert_true(src.contains(symbol),
			"the selection contract must still write: " + symbol)

func test_still_routes_to_the_lobby() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"student_card must still route to the lobby")
```

- [ ] **Extra Step D2: Migrate in slices, committing each**

512 overrides in one commit is unreviewable and unbisectable. Split into four commits, screenshotting after each:

1. Label variations only (font sizes and font colors).
2. Panels and cards (inline StyleBoxes → `&"Card"` / `&"SunkenPanel"`).
3. Buttons (→ `&"PrimaryButton"` / `&"SecondaryButton"` / `&"DangerButton"`).
4. ProgressBars → `StatBar` nodes with `category` set, and script `Color()` literals → tokens.

If the override count is not zero after slice 4, the remainder are values with no theme equivalent — add variations to `ThemeFactory` (Step D, bucket 4) rather than leaving them.

- Motion: `Juice.stagger_in` the student cards on entry; `Juice.pop_in` the detail panel when a card is selected; `AudioDirector.play_sfx(&"confirm")` on approve and `&"cancel"` on reject.

---

# Task 13: StudentList

**Files:**
- Modify: `Scenes/StudentList/student_list.tscn` (1275 lines, 121 overrides, 10 StyleBoxes), `Scripts/StudentList/student_list.gd` (831 lines)
- Test: `tests/test_student_list.gd`

**Interfaces:**
- Consumes: `&"Card"`, `DesignTokens.category_color`, `Juice.stagger_in`.
- Produces: nothing new. Routing to `res://Scenes/AturJadwal/atur_jadwal.tscn` (line 462) must not change.

**Specifics beyond the standard procedure:**

- The scene hardcodes six `Murid1`–`Murid6` cards, each with a `StickyNotesContainer` of five day notes — that is 30 near-identical sticky-note subtrees. **Extract one `StickyNote.tscn`** (`TextureRect` + `DayLabel` + `ActivityLabel`) and instance it, so a designer changes the note style in one place:

```
Scenes/StudentList/StickyNote.tscn
Scripts/StudentList/StickyNote.gd
```

`StickyNote.gd` exports what a designer would want to tune:

```gdscript
@tool
class_name StickyNote
extends TextureRect

@export var day_name: String = "Senin":
	set(value):
		day_name = value
		if is_node_ready():
			$DayLabel.text = value

@export var activity: String = "":
	set(value):
		activity = value
		if is_node_ready():
			$ActivityLabel.text = value
			self_modulate = DesignTokens.load_default().category_color(value)
```

- Tint each note by its activity category via `category_color`, replacing whatever per-note color logic `student_list.gd` currently does.
- Motion: `Juice.stagger_in` the six cards; `Juice.stagger_in` each card's five notes with a shorter step when the card opens.

---

# Task 14: Lobby

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (703 lines, 82 overrides, 3 StyleBoxes), `Scripts/Lobby/loby.gd` (866 lines)
- Test: `tests/test_lobby.gd`

**Interfaces:**
- Consumes: `&"Card"`, `&"PrimaryButton"`, `DesignTokens.currency_gold`, `Juice`, `AudioDirector.play_bgm(&"lobby")` and `play_sfx(&"coin")`.
- Produces: nothing new. Routing to StudentCard (line 703) and AturJadwal (line 708) must not change, and the `lobby_tutorial_completed` gate in `GameState` must keep working.

**Specifics beyond the standard procedure:**

- This is the game's hub — it gets the most attention. It has a layered diorama (`BGLayer`, four `Meja_*` desks, front/back portrait and hand containers) that is **art, not UI**: leave the layering and positioning alone. Migrate only the HUD: `JUDUL`, `DisplayUang`, `DailyLogin`, and the five nav buttons (`Student`, `Koperasi`, `ReportStudent`, `Inventory`, `Jadwal`).
- The nav buttons currently use `Assets/Images/UI/Placeholders/lobby_btn_{normal,hover,pressed}.tres`. Those three `.tres` files are the only pre-existing StyleBox resources in the project — **fold them into `ThemeFactory` as a `&"LobbyNavButton"` variation** and delete the loose files, so lobby buttons obey the tokens like everything else.
- `DisplayUang`'s money label: replace the direct text assignment with `Juice.count_up` and fire `AudioDirector.play_sfx(&"coin")` whenever the value increases. This is the single highest-impact bit of juice on the screen.
- `DailyLogin`: `Juice.stagger_in` the seven day tiles when the panel opens; `Juice.pop_in` plus `&"success"` SFX on the claimed tile.
- Add a subtle idle to the diorama so the hub does not feel like a still image — a slow looping vertical bob on the portrait containers, amplitude and period exported:

```gdscript
@export_group("Idle Motion")
@export var idle_bob_pixels: float = 6.0
@export var idle_bob_period: float = 3.2
```

---

# Task 15: AturJadwal

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (554 lines, 41 overrides, 17 StyleBoxes), `Scripts/AturJadwal/atur_jadwal.gd` (1420 lines), `Scripts/AturJadwal/stat_bar.gd`
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `StatBar`, `&"Card"`, `&"PrimaryButton"`, `DesignTokens.category_color`, `Juice.shake`, `AudioDirector`.
- Produces: nothing new. Routing to Lobby (135), StudentList (703), and SchoolDay (913) must not change, and it must keep writing `GameState.day_schedules` in the same shape.

**Specifics beyond the standard procedure:**

- **Delete `Scripts/AturJadwal/stat_bar.gd`** and replace every use with the `StatBar` class from Task 7. Two stat-bar implementations is exactly the duplication this plan exists to remove. Verify nothing else references it first:

```bash
grep -rn "stat_bar" Scenes Scripts --include=*.tscn --include=*.gd
```

- The five `BGHari` day buttons (`Senin`–`Jumat`) are the screen's core interaction. Tint each by its assigned category via `category_color`, and `Juice.pop_in` the selected day's detail panel.
- The `Peringatan` (warning) dialog: enter with `Juice.pop_in` over a `&"Scrim"` panel, and `Juice.shake` + `AudioDirector.play_sfx(&"fail")` when the player tries to start a week with an incomplete schedule.
- The `Penjadwalan` panel's category buttons (`Akademik`, `Olahraga`, …) each own a `ProgressBar` — convert those to `StatBar` with `category` set, so the accent color comes from the token and not from per-node code.
- Remember the `ClickArea` opt-out from Task 6 Step 8 is already in place; do not remove it.

---

# Task 16: SchoolDay

**Files:**
- Modify: `Scenes/SchoolSimulation/SchoolDay.tscn` (126 lines, 13 overrides), `Scripts/SchoolSimulation/SchoolDay.gd` (1556 lines)
- Also modify the sub-scenes it drives: `DaySummaryPopup`, `DaySummaryStudentRow`, `DaySummaryBadge`, `DaySummaryPill`, `EventAnnouncement`, `EventWarning`, `EventStudentSelectDialog`, `DailyDecayOverview`, `ResultCheckup`, `BookClockWidget`
- Test: `tests/test_school_day.gd`

**Interfaces:**
- Consumes: `StatBar`, `&"Card"`, `&"Scrim"`, `Juice.stagger_in`/`count_up`/`fill_bar`, `AudioDirector.play_bgm(&"simulation")`.
- Produces: nothing new. Routing to SemesterEnd (1274) and Lobby (1276) must not change. **The minigame launch path is out of scope** — `GameContainer` and everything it instantiates from `Scenes/Minigames/` stays untouched.

**Specifics beyond the standard procedure:**

- The scene itself is thin (13 overrides); the visual weight is in the ten sub-scenes. Migrate them **one commit each**, in this order — least to most complex, so the pattern is established before the hard ones:
  1. `DaySummaryBadge`, `DaySummaryPill` (2 StyleBoxes each)
  2. `DaySummaryStudentRow`
  3. `DaySummaryPopup`
  4. `EventAnnouncement`, `EventWarning`
  5. `EventStudentSelectDialog` (2 StyleBoxes)
  6. `DailyDecayOverview`, `ResultCheckup`
  7. `BookClockWidget`
- `SchoolDay.tscn`'s `Background` is a bare `ColorRect`. Point it at `tokens.surface_page` from script, or replace it with a `Panel` using `&"SunkenPanel"`. A `ColorRect` with a hardcoded color is exactly what centralization is meant to eliminate.
- The `DayScreen` `ProgressBar` (day progress) → `&"StatBar"` with `Juice.fill_bar`.
- Every stat delta shown in `DaySummaryPopup` → `Juice.count_up`, with `AudioDirector.play_sfx(&"success")` on gains above target and `&"fail"` on losses.
- `EventWarning` uses `Scripts/SchoolSimulation/HazardStripeShader.gdshader`. Keep the shader, but drive its stripe color from `tokens.state_warning` via a shader uniform set from script rather than a baked constant.
- `ClickToContinueLabel` gets the same looping pulse as the Splashscreen hint (Task 10).

---

# Task 17: SemesterEnd

**Files:**
- Modify: `Scenes/EndGame/SemesterEnd.tscn` (883 lines, 150 overrides, 26 StyleBoxes), `Scripts/EndGame/SemesterEnd.gd` (422 lines)
- Test: `tests/test_semester_end.gd`

**Interfaces:**
- Consumes: `StatBar`, `&"Card"`, label variations, `Juice.stagger_in`/`count_up`/`fill_bar`/`pop_in`, `AudioDirector.play_bgm(&"result")`.
- Produces: nothing new. The three routes — CutScene (349), StudentCard (368), Lobby (388), MainMenu (399) — must not change, nor may `GameState.check_semester_passed()` usage.

**Specifics beyond the standard procedure:**

This is the payoff screen and deserves the most motion in the game.

- The scene hardcodes `Murid1`–`Murid6` cards, each with `StatsContainer > {Akademis, Seni, Olahraga} > Labels + Progress`. That is 18 near-identical stat rows. **Extract one `ResultStatRow.tscn`** using `StatBar`, and instance it — the same deduplication as Task 13's sticky notes:

```
Scenes/EndGame/ResultStatRow.tscn
Scripts/EndGame/ResultStatRow.gd
```

with `@export var category: String`, `@export var icon: Texture2D`, `@export var label_text: String`, and `set_result(value: float, target: float) -> void`.

- The `Stamp` label (LULUS / TIDAK LULUS) is the emotional beat. Give it a stamp-slam: scale from 3.0 down to 1.0 over `dur_fast` with `TRANS_BACK`/`EASE_IN`, ending with a small `Juice.shake` on the parent card and `AudioDirector.play_sfx(&"success")` or `&"fail")`:

```gdscript
func _slam_stamp(stamp: Control, passed: bool) -> void:
	stamp.scale = Vector2(3.0, 3.0)
	stamp.modulate.a = 0.0
	var t := Juice.tokens()
	var tw := stamp.create_tween().set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(stamp, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		Juice.shake(stamp.get_parent(), 8.0)
		AudioDirector.play_sfx(&"success" if passed else &"fail"))
```

- Sequence the reveal rather than showing everything at once: title pops in → cards stagger in → each card's stat bars fill with count-up → stamps slam in one at a time. Export the beat spacing so it is tunable:

```gdscript
@export_group("Reveal Timing")
@export var card_stagger: float = 0.12
@export var stat_fill_delay: float = 0.35
@export var stamp_delay: float = 0.9
```

---

# Task 18: Settings Screen

The `SettingButton` on MainMenu has been dead since the project started (`main_menu.gd` printed "belum diimplementasi"). Task 9 routes it to `res://Scenes/UI/Settings.tscn`, which this task creates. **Task 9 leaves a broken link until this ships.**

**Files:**
- Create: `Scenes/UI/Settings.tscn`, `Scripts/UI/Settings.gd`
- Modify: `Scripts/GameSettings.gd` (persist audio volumes alongside existing settings)
- Test: `tests/test_settings.gd`

**Interfaces:**
- Consumes: `SafeAreaMargin`, `&"Card"`, `&"PrimaryButton"`, `&"SecondaryButton"`, `AudioDirector.set_bus_volume`/`get_bus_volume`, `GameSettings.minigame_tutorial_enabled`, `Transition`.
- Produces: `res://Scenes/UI/Settings.tscn` — the target Task 9 already links to.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_settings.gd`:

```gdscript
extends McpTestSuite

func suite_name() -> String:
	return "settings"

var _screen: Control


func setup() -> void:
	var scene: PackedScene = load("res://Scenes/UI/Settings.tscn")
	_screen = scene.instantiate()
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func test_scene_loads() -> void:
	assert_not_null(_screen, "Settings.tscn must exist and instantiate")


func test_has_a_slider_for_each_audio_bus() -> void:
	for name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(name, true, false)
		assert_not_null(s, "missing slider: " + name)
		assert_true(s is Slider, name + " must be a Slider")


func test_moving_a_slider_changes_the_bus_volume() -> void:
	var slider := _screen.find_child("SfxSlider", true, false) as Slider
	slider.value = 0.3
	await Engine.get_main_loop().process_frame
	assert_almost_eq(AudioDirector.get_bus_volume(&"SFX"), 0.3, 0.02,
		"the slider must drive the bus")


func test_tutorial_toggle_reflects_and_writes_game_settings() -> void:
	var toggle := _screen.find_child("TutorialToggle", true, false) as CheckButton
	assert_not_null(toggle, "the minigame tutorial toggle must exist")
	var original := GameSettings.minigame_tutorial_enabled
	toggle.button_pressed = not original
	await Engine.get_main_loop().process_frame
	assert_eq(GameSettings.minigame_tutorial_enabled, not original,
		"the toggle must write through to GameSettings")
	GameSettings.minigame_tutorial_enabled = original


func test_back_button_exists_and_is_wired() -> void:
	var back := _screen.find_child("BackButton", true, false) as BaseButton
	assert_not_null(back, "settings must be escapable")
	assert_true(back.pressed.get_connections().size() > 0,
		"back button must be wired")


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		if not c.get_theme_font_size_override_list().is_empty() \
				or not c.get_theme_color_override_list().is_empty() \
				or not c.get_theme_stylebox_override_list().is_empty():
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_labels_are_indonesian() -> void:
	var title := _screen.find_child("TitleLabel", true, false) as Label
	assert_eq(title.text, "PENGATURAN", "title must be Indonesian")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run` with `suite: "settings"`. Expected: FAIL — cannot load `Settings.tscn`.

- [ ] **Step 3: Build the scene**

Create `Scenes/UI/Settings.tscn` following the MainMenu pattern exactly: `Control > Background + SafeArea(SafeAreaMargin) > VBoxContainer`, with:

- `TitleLabel` (`&"H1Label"`, text `PENGATURAN`)
- A `&"Card"` Panel containing a `VBoxContainer` with three labelled rows: `Suara Utama` / `MasterSlider`, `Musik` / `BgmSlider`, `Efek Suara` / `SfxSlider` — each an `HSlider` with `min_value = 0.0`, `max_value = 1.0`, `step = 0.01`
- A second `&"Card"` Panel with `Tutorial Minigame` and a `CheckButton` named `TutorialToggle`
- `BackButton` (`&"SecondaryButton"`, text `KEMBALI`)

No `theme_override_*` anywhere.

- [ ] **Step 4: Write the script**

Create `Scripts/UI/Settings.gd`:

```gdscript
extends Control

@onready var _master: HSlider = %MasterSlider
@onready var _bgm: HSlider = %BgmSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _tutorial: CheckButton = %TutorialToggle
@onready var _back: Button = %BackButton


func _ready() -> void:
	_master.value = AudioDirector.get_bus_volume(&"Master")
	_bgm.value = AudioDirector.get_bus_volume(&"BGM")
	_sfx.value = AudioDirector.get_bus_volume(&"SFX")
	_tutorial.button_pressed = GameSettings.minigame_tutorial_enabled

	_master.value_changed.connect(_on_volume_changed.bind(&"Master"))
	_bgm.value_changed.connect(_on_volume_changed.bind(&"BGM"))
	_sfx.value_changed.connect(_on_volume_changed.bind(&"SFX"))
	_tutorial.toggled.connect(_on_tutorial_toggled)
	_back.pressed.connect(_on_back_pressed)

	Juice.stagger_in(_collect_rows())


func _collect_rows() -> Array:
	var rows: Array = []
	for child in %Layout.get_children():
		rows.append(child)
	return rows


func _on_volume_changed(value: float, bus: StringName) -> void:
	AudioDirector.set_bus_volume(bus, value)
	# Immediate audible feedback while dragging the SFX slider.
	if bus == &"SFX":
		AudioDirector.play_sfx(&"tap")


func _on_tutorial_toggled(pressed: bool) -> void:
	GameSettings.minigame_tutorial_enabled = pressed
	GameSettings.save_settings()


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	Transition.change_scene("res://Scenes/MainMenu/main_menu.tscn",
		Transition.Style.FADE)
```

Mark `MasterSlider`, `BgmSlider`, `SfxSlider`, `TutorialToggle`, `BackButton`, and `Layout` as **unique names** (`%`) in the scene, or the `%` lookups fail.

- [ ] **Step 5: Run the tests to verify they pass**

`test_run` with `suite: "settings"`. Expected: 7 tests, all PASS.

- [ ] **Step 6: Verify the MainMenu link now works**

`project_run`, MainMenu → PENGATURAN → drag each slider → KEMBALI.

Expected: a clean fade both ways, the SFX slider audibly changes the tap sound's volume (only if Task 5's SFX were downloaded; silent otherwise, which is fine), and settings survive a restart. Check `logs_read` for errors.

- [ ] **Step 7: Commit**

```bash
git add Scenes/UI Scripts/UI/Settings.gd tests/test_settings.gd
git commit -m "feat(ui): add Settings screen, connecting the previously dead SettingButton"
```

---

# Task 19: Full-Flow Verification and Handoff

**Files:**
- Create: `docs/superpowers/design/style-guide.md`
- Create: `docs/superpowers/design/after/*.png`

**Interfaces:**
- Consumes: everything.
- Produces: the documentation a future contributor needs to keep the system consistent, and proof the whole flow works.

---

- [ ] **Step 1: Run every test**

`test_run` with no filter.

Expected: every suite passes. Record the exact totals. **Do not proceed on a partial pass** — if anything fails, fix it before continuing.

- [ ] **Step 2: Verify zero theme overrides remain in core scenes**

```bash
for f in Scenes/MainMenu/main_menu.tscn Scenes/Lobby/loby.tscn \
         Scenes/AturJadwal/atur_jadwal.tscn Scenes/SchoolSimulation/SchoolDay.tscn \
         Scenes/EndGame/SemesterEnd.tscn Scenes/StudentList/student_list.tscn \
         Scenes/StudentCard/student_card.tscn Scenes/CutScene/cut_scene.tscn \
         Scenes/Loading/loading.tscn Scenes/Splashscreen/Splashscreen.tscn; do
  printf "%-50s %s\n" "$f" "$(grep -c theme_override "$f")"
done
```

Expected: `0` on every line. Any non-zero count must be individually justified in the style guide (Step 5) with the reason no theme variation could express it.

- [ ] **Step 3: Verify no hardcoded colors remain in core scripts**

```bash
grep -rn "Color(" Scripts --include=*.gd | grep -v "Scripts/Minigames" \
  | grep -v "Scripts/Design/DesignTokens.gd" | wc -l
```

Expected: `0`. `DesignTokens.gd` is the one legitimate home for color literals; minigames are out of scope.

- [ ] **Step 4: Play the entire flow end to end**

`project_run` and play through without using DebugManager shortcuts:

Splashscreen → Loading → MainMenu → PENGATURAN → back → MULAI → CutScene → StudentCard (approve students) → Lobby → Jadwal → AturJadwal → set a full week → StudentList → back → start the week → SchoolDay (skip minigames) → day summary → back to Lobby → repeat until the final week → SemesterEnd → back to MainMenu.

At each screen confirm: nothing clipped at any edge, every button responds to touch, transitions are smooth, text is legible, and the styling is consistent with the Task 9 reference.

Read `logs_read` afterwards. Expected: no errors beyond the Task 0 baseline.

- [ ] **Step 5: Write the style guide**

Create `docs/superpowers/design/style-guide.md` covering, with real examples pulled from the shipped code:

- How to change a color, radius, or font across the whole game (edit `design_tokens.tres` → run `BakeTheme.gd`) — with the exact menu path.
- The full list of theme variations and when to use each.
- How to swap fonts (point to `Assets/Fonts/README.md`).
- How to fill or swap audio (point to `Assets/Audio/README.md`).
- The `Juice` API with a one-line example per method.
- **The rule:** never add a `theme_override_*`. If a needed style does not exist, add a variation to `ThemeFactory.gd` and rebake.
- How to opt a button out of auto-juicing (`set_meta(Juice.NO_AUTO_JUICE, true)`).

- [ ] **Step 6: Capture after-screenshots**

Screenshot all 10 core scenes into `docs/superpowers/design/after/`, matching the Task 0 baseline filenames so before/after pairs line up.

- [ ] **Step 7: Publish a before/after artifact**

Load the `artifact-design` skill, build an HTML page pairing each baseline screenshot with its after-shot (embed the PNGs as data URIs — the CSP blocks external images), and publish it with `Artifact`, `favicon: "✨"`.

Give the user the link.

- [ ] **Step 8: Commit**

```bash
git add docs/superpowers/design
git commit -m "docs: style guide and before/after comparison for the core polish pass"
```

---

## Out of Scope — Follow-Up Work

Explicitly deferred. Do not do these in this plan.

| Item | Why deferred |
|---|---|
| **All minigames** (8 scenes, 8 scripts) | User decision: "make all of the type minigames later". They will inherit the Theme automatically but need their own juice/layout pass. |
| **Haptic vibration** | User decision: "do not make the haptic vibration first". The hook belongs in `UIPolish._on_button_pressed`. |
| **BGM tracks** | Music is a stronger authorship choice than SFX. Slots exist and are silent. |
| **Localization (`.po`)** | The game is Indonesian-only today; extracting strings is a separate project. |
| **Landscape / tablet layouts** | Portrait-only per `project.godot`. `SafeAreaMargin` and containers make this tractable later. |
| **Custom UI art** (9-slice frames, icons) | The Theme's StyleBoxFlat approach is deliberately swap-ready: replace a `StyleBoxFlat` with a `StyleBoxTexture` in `ThemeFactory` and rebake. |

---

## Self-Review

**Spec coverage.** Every locked decision maps to tasks: open assets → Tasks 4, 5; full centralization → Tasks 2, 3, 10–17; Umamusume language → Task 3's variations, gated on Task 1's palette; full juice minus haptics → Tasks 6, 7, 8 and the motion step in every screen task; minigames excluded → stated in Global Constraints and the out-of-scope table; inspector-editability → `DesignTokens` exports, `AudioDirector` slots, and the per-screen `@export_group`s in Tasks 14, 17.

**Type consistency.** `DesignTokens.font_body`/`font_display` are `FontFile` slots while the sizes are `font_body_size`/`font_display_size` — Task 2 Step 4 explicitly corrects the test that would otherwise use the wrong names. `Juice.tokens()` is the single accessor used by `StatBar`, `Transition`, and every screen script. `Transition.change_scene`'s style parameter is defaulted so all 21 existing single-argument call sites keep working, and Task 8 Step 6 verifies that. The theme variation names declared in Task 3's `Produces` block are exactly the strings asserted in `test_every_declared_variation_exists` and used in Tasks 9–18.

**Known coupling.** Task 9 links MainMenu to `Scenes/UI/Settings.tscn`, which Task 18 creates. This is called out in both tasks. If the plan is executed out of order, the PENGATURAN button logs a load error until Task 18 ships — it does not crash.
