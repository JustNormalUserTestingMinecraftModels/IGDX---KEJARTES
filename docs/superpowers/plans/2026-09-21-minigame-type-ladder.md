# Minigame Type Ladder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking. Do not use subagent-driven-development here — the Godot AI bridge
> takes one client and a subagent that connects displaces this session.

**Goal:** Put every minigame's text on the three token rungs 36/64/96, route
PilihanGanda onto the shared `QuestionCard` with a real image slot, and raise
the two inks that cannot reach 4.5:1.

**Architecture:** Seven new `ThemeFactory` type variations replace 25
hard-coded sizes and every `theme_override_*` in the six minigame scenes.
`QuestionCard.tscn` — already shared by Password, Variabel and Menjodohkan —
gains PilihanGanda as a fourth user, so its typography is fixed once for four
screens. No new runtime construction; the `viewport_editability` ratchet only
turns down.

**Tech Stack:** Godot 4.6, GDScript, `ThemeFactory`/`DesignTokens` baked theme,
`McpTestSuite` suites run through the Godot AI MCP bridge.

**Spec:** `docs/superpowers/specs/2026-09-21-minigame-type-ladder-design.md`

## Global Constraints

- Working directory is the worktree
  `.claude/worktrees/minigame-type-ladder`, branch `feat/minigame-type-ladder`.
  Never `cd` to the main checkout.
- **The bridge's active editor serves the MAIN checkout, not this worktree.**
  Task 1 Step 1 stands up a second editor on the worktree and captures its
  `session_id`. Every `test_run` / `script_patch` / `scene_open` / `scene_save`
  call in this plan passes `session_id="<worktree>"`. Never call
  `session_activate` — other sessions share the server.
- **Never hand-edit a `.tscn` while that editor is attached.** Go through
  `scene_open` → `node_create` / `node_set_property` / `node_manage` →
  `scene_save`. `anchors_preset` is inert (set the four anchors); numbers are
  unquoted; `node_create` appends last so z-order needs `move_node`.
- **Do scene work first, script work second within a task.** `scene_save`
  flushes every open script tab over whatever was patched. After patching a
  script, restart that editor before the next `scene_save`.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` variation. The only
  accepted exception is a layout-only constant (`separation`, `margin_*`).
- **No emoji as UI iconography.** Use a transparent SVG texture.
- Game-facing identifiers and all UI text are **Indonesian**; systems code is
  English.
- `Balance.gd` is collaborator-owned — read it, never edit it.
- Rebaking the theme writes `Assets/Theme/kejartes_theme.tres`. After a rebake,
  **restart the editor before any `scene_save`**, or the cached theme merges
  stale stylebox props by id and the save writes it back. Diff the bake before
  every commit.
- Commits: Conventional Commits with a scope, e.g.
  `fix(minigames): put the question card on the type ladder`. End every commit
  message with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- PowerShell 5.1 splits a `git commit -m` here-string at an embedded `"` —
  write the message to a file and `git commit -F`, or use the Bash tool.

## The three rungs

| Rung | Token | Role |
|---|---|---|
| 96 | `font_display_size` | score |
| 64 | `font_h1` | question |
| 36 | `font_title` | choices, meta, badge, overlay, wheel headers |

28 (`font_body_size`) is the floor, reserved for dense rows. Nothing else.

---

### Task 1: The suite and the seven variations

**Files:**
- Create: `tests/test_minigame_typography.gd`
- Modify: `Scripts/Design/ThemeFactory.gd`
- Modify: `Assets/Theme/kejartes_theme.tres` (rebaked output, not hand-edited)

**Interfaces:**
- Produces: seven theme type variations that every later task consumes by
  name — `MinigameQuestionLabel` (Label, 64), `MinigameChoiceButton` (Button,
  36), `MinigameMetaLabel` (Label, 36), `MinigameBadgeLabel` (Label, 36),
  `MinigameOverlayLabel` (Label, 36), `MinigameWheelHeaderWarm` (Label, 36),
  `MinigameWheelHeaderCool` (Label, 36).
- Produces: `suite_name()` → `"minigame_typography"`, the argument every later
  `test_run` in this plan passes.

- [ ] **Step 1: Stand up the worktree editor and capture its session_id**

The bridge's active editor is the main checkout's. Seed this worktree's
`.godot` from the main checkout so the import does not run from cold, then
launch a second editor against the worktree's `project.godot`. Do not kill any
existing `Godot_v*.exe`, and do not call `session_activate`.

```bash
robocopy "../../../.godot" ".godot" /E /NFL /NDL /NJH /NJS >/dev/null; true
```

Launch the editor (the Godot exe path is a directory — resolve it first), then:

Run: `session_manage(op="list")`
Expected: two sessions. Record the one whose `project_path` ends in
`.claude/worktrees/minigame-type-ladder/`. That id is `<worktree>` in every
step below.

- [ ] **Step 2: Write the failing test**

Create `tests/test_minigame_typography.gd`:

```gdscript
@tool
extends McpTestSuite

## Pins the minigame type ladder: every minigame text size is one of the
## three token rungs (36 font_title, 64 font_h1, 96 font_display_size), and
## each role reaches its size through a ThemeFactory variation rather than a
## theme_override_* or an add_theme_font_size_override literal.
##
## Source-text scans in the house style -- these scenes cannot be
## instantiated headlessly. Must be @tool or the runner reports the class
## abstract, and no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_typography"

## Every variation this pass adds, with the token rung it must carry.
const VARIATIONS: Dictionary = {
	"MinigameQuestionLabel": 64,
	"MinigameChoiceButton": 36,
	"MinigameMetaLabel": 36,
	"MinigameBadgeLabel": 36,
	"MinigameOverlayLabel": 36,
	"MinigameWheelHeaderWarm": 36,
	"MinigameWheelHeaderCool": 36,
}

func test_theme_factory_declares_every_minigame_variation() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Design/ThemeFactory.gd")
	assert_false(src.is_empty(), "ThemeFactory.gd must be readable")
	for name in VARIATIONS:
		assert_true(src.contains('"%s"' % name),
			"ThemeFactory.gd must declare the %s variation" % name)

func test_every_variation_is_baked_at_its_rung() -> void:
	var theme := load("res://Assets/Theme/kejartes_theme.tres") as Theme
	assert_true(theme != null, "the baked theme must load")
	for name in VARIATIONS:
		var want: int = VARIATIONS[name]
		assert_true(theme.has_font_size("font_size", name),
			"%s must carry a baked font_size" % name)
		assert_eq(theme.get_font_size("font_size", name), want,
			"%s must be %d" % [name, want])
```

- [ ] **Step 3: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL — `ThemeFactory.gd must declare the MinigameQuestionLabel
variation`, and the baked-size test fails on the same names.

- [ ] **Step 4: Add the seven variations to ThemeFactory**

Add one `_add_minigame_typography(theme, tokens)` builder near the other
minigame blocks and call it from the same place the existing minigame
variations are registered. Each variation is documented with a `##` line —
`tests/test_script_documentation.gd` is a hard rule.

```gdscript
## Ink for the two Menjodohkan wheel headers. Both clear 4.5:1 on
## surface_card: brand_primary 7.2:1, cat_akademis 5.1:1. The colours they
## replace -- Color(0.85,0.45,0.1) and Color(0.2,0.5,0.85) -- are mid-tone
## (luminance 0.27 and 0.21) and cannot reach the body floor on any ground.
static func _add_minigame_typography(theme: Theme, tokens: DesignTokens) -> void:
	# The question: body copy, so the body face, at font_h1.
	theme.add_type("MinigameQuestionLabel")
	theme.set_type_variation("MinigameQuestionLabel", "Label")
	theme.set_font_size("font_size", "MinigameQuestionLabel", tokens.font_h1)
	theme.set_color("font_color", "MinigameQuestionLabel", tokens.text_primary)

	# Counters and meta on a card.
	theme.add_type("MinigameMetaLabel")
	theme.set_type_variation("MinigameMetaLabel", "Label")
	theme.set_font_size("font_size", "MinigameMetaLabel", tokens.font_title)
	theme.set_color("font_color", "MinigameMetaLabel", tokens.text_secondary)

	# The QuestionCard badge: cream on the brand fill, display face.
	theme.add_type("MinigameBadgeLabel")
	theme.set_type_variation("MinigameBadgeLabel", "Label")
	theme.set_font_size("font_size", "MinigameBadgeLabel", tokens.font_title)
	theme.set_color("font_color", "MinigameBadgeLabel", tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", "MinigameBadgeLabel", tokens.font_display)

	# Text drawn over art: cream with the same 8px outline ShopHubTileLabel uses.
	theme.add_type("MinigameOverlayLabel")
	theme.set_type_variation("MinigameOverlayLabel", "Label")
	theme.set_font_size("font_size", "MinigameOverlayLabel", tokens.font_title)
	theme.set_color("font_color", "MinigameOverlayLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "MinigameOverlayLabel", 8)
	theme.set_color("font_outline_color", "MinigameOverlayLabel", Color(0, 0, 0, 0.75))

	for pair in [["MinigameWheelHeaderWarm", tokens.brand_primary],
			["MinigameWheelHeaderCool", tokens.cat_akademis]]:
		var wheel: String = pair[0]
		theme.add_type(wheel)
		theme.set_type_variation(wheel, "Label")
		theme.set_font_size("font_size", wheel, tokens.font_title)
		theme.set_color("font_color", wheel, pair[1])
		if tokens.font_display != null:
			theme.set_font("font", wheel, tokens.font_display)

	_add_minigame_choice_button(theme, tokens)
```

The choice button is its own builder because it needs styleboxes:

```gdscript
## PilihanGanda's answer buttons. Display face at font_title on the card
## surface, so a choice reads as tappable against the page.
static func _add_minigame_choice_button(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "MinigameChoiceButton"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")
	theme.set_font_size("font_size", NAME, tokens.font_title)
	theme.set_color("font_color", NAME, tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", NAME, tokens.font_display)
```

- [ ] **Step 5: Rebake the theme**

Run `Scripts/Design/BakeTheme.gd` via the worktree editor (File > Run,
Ctrl+Shift+X), or let the `theme_rebake` suite do it:

Run: `test_run(suite="theme_rebake", session_id="<worktree>")`
Expected: PASS, and `Assets/Theme/kejartes_theme.tres` is rewritten.

- [ ] **Step 6: Restart the worktree editor**

A changed `@export` default or a fresh bake keeps serving the cached instance
otherwise. Kill only the worktree editor's `editor_pid`, relaunch, and
re-capture `<worktree>` from `session_manage(op="list")`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 2 tests.

Run: `test_run(suite="theme_factory", session_id="<worktree>")`
Expected: PASS, 32 tests (the baseline).

Run: `test_run(suite="script_documentation", session_id="<worktree>")`
Expected: PASS, 2 tests.

- [ ] **Step 8: Commit**

```bash
git add tests/test_minigame_typography.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres
git commit -F <message file>
```

Message: `feat(minigames): add the seven type-ladder variations`

Check `git diff HEAD~1 -- Assets/Theme/kejartes_theme.tres` shows only added
types — stylebox ids renumber between branches, so a large unrelated diff means
the bake picked up a stale cache and the editor needs another restart.

---

### Task 2: QuestionCard on the ladder

**Files:**
- Modify: `Scenes/Minigames/Akademis/QuestionCard.tscn`
- Modify: `tests/test_minigame_typography.gd`

**Interfaces:**
- Consumes: the seven variations from Task 1.
- Produces: `QuestionCard.tscn` with `VBox/RowImage` at
  `custom_minimum_size = Vector2(0, 620)`, `VBox/TextLabel` on
  `MinigameQuestionLabel`, `StatusBadge/BadgeLabel` on `MinigameBadgeLabel`,
  and `LockOverlay/LockIcon` a `TextureRect` (not a Label). Tasks 3–5 rely on
  these node paths being unchanged apart from `LockIcon`'s type.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_typography.gd`:

```gdscript
## The shared question card, instanced by Password, Variabel, Menjodohkan
## and (from this pass) PilihanGanda.
const CARD := "res://Scenes/Minigames/Akademis/QuestionCard.tscn"

func test_question_card_carries_no_font_size_override() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_false(src.contains("theme_override_font_sizes/font_size"),
		"QuestionCard.tscn must reach its sizes through variations")

func test_question_card_image_slot_is_sized_for_real_art() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_true(src.contains("custom_minimum_size = Vector2(0, 620)"),
		"QuestionCard.tscn's RowImage slot must be 620 tall")

func test_question_card_uses_the_ladder_variations() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	for name in ["MinigameQuestionLabel", "MinigameBadgeLabel"]:
		assert_true(src.contains(name),
			"QuestionCard.tscn must use the %s variation" % name)

func test_question_card_has_no_emoji_lock() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_false(src.contains("🔒"),
		"the lock must be icon_lock.svg, not an emoji -- CLAUDE.md bans emoji iconography")
	assert_true(src.contains("icon_lock.svg"),
		"QuestionCard.tscn must reference Assets/Images/UI/Placeholders/icon_lock.svg")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL on all four — the card still carries `font_size = 28` and
`font_size = 64`, `RowImage` is 116, and `LockIcon` holds 🔒.

- [ ] **Step 3: Edit the card through the editor**

`scene_open(path="res://Scenes/Minigames/Akademis/QuestionCard.tscn",
session_id="<worktree>")`, then via `batch_execute`:

| Node | Property | Value |
|---|---|---|
| `VBox/RowImage` | `custom_minimum_size` | `Vector2(0, 620)` |
| `VBox/TextLabel` | `theme_type_variation` | `MinigameQuestionLabel` |
| `VBox/TextLabel` | `custom_minimum_size` | `Vector2(0, 268)` |
| `StatusBadge/BadgeLabel` | `theme_type_variation` | `MinigameBadgeLabel` |
| `LockOverlay/LockText` | `theme_type_variation` | `MinigameOverlayLabel` |
| root `QuestionCard` | `custom_minimum_size` | `Vector2(850, 960)` |

Then clear the overrides the variations replace — remove
`theme_override_font_sizes/font_size` and `theme_override_colors/font_color`
from `TextLabel`, `BadgeLabel` and `LockText` by setting each to `null` via
`node_set_property`.

Recolour the two hand-rolled styleboxes from `Color(0.85, 0.45, 0.1)` to
`brand_primary` `Color(0.478, 0.290, 0.169)`: the card border
(`StyleBoxFlat_452ld.border_color`) and the badge fill
(`StyleBoxFlat_badge.bg_color`).

Replace the lock: `node_manage` delete `LockOverlay/LockVBox/LockIcon`, then
`node_create` a `TextureRect` of the same name in the same parent, `texture =
res://Assets/Images/UI/Placeholders/icon_lock.svg`, `expand_mode = 1`,
`stretch_mode = 5`, `custom_minimum_size = Vector2(0, 96)`. A node's type can
only be changed by delete-and-recreate, and `node_create` appends last — use
`move_node` to put it back above `LockText`.

`scene_save(session_id="<worktree>")`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 6 tests.

Run: `test_run(suite="minigame_card_shadows", session_id="<worktree>")`
Expected: PASS — the card's shadow stylebox is pinned; the recolour must not
have disturbed `shadow_size = 12` / `shadow_offset = Vector2(0, 6)`.

Run: `test_run(suite="kalkulator", session_id="<worktree>")`
Expected: PASS — Password and Variabel instance this card.

Run: `test_run(suite="minigame_art", session_id="<worktree>")`
Expected: PASS, 22 tests.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/Akademis/QuestionCard.tscn tests/test_minigame_typography.gd
git commit -F <message file>
```

Message: `fix(minigames): put the shared question card on the type ladder`

---

### Task 3: PilihanGanda instances the card

**Files:**
- Modify: `Scenes/Minigames/Akademis/PilihanGanda.tscn`
- Modify: `tests/test_minigame_typography.gd`

**Interfaces:**
- Consumes: `QuestionCard.tscn` from Task 2.
- Produces: `PilihanGanda.tscn` with `VBoxContainer/SoalCard` (a `QuestionCard`
  instance) where the `QuestionImage` / `ProgressLabel` / `QuestionLabel` trio
  used to be. Task 4's `@onready` paths depend on exactly these names.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_typography.gd`:

```gdscript
const PILIHAN := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"

func test_pilihan_ganda_instances_the_shared_card() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN)
	assert_true(src.contains("QuestionCard.tscn"),
		"PilihanGanda.tscn must instance the shared QuestionCard")
	assert_true(src.contains('name="SoalCard"'),
		"the instance must be named SoalCard, as Password and Variabel name theirs")

func test_pilihan_ganda_drops_the_loose_trio() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN)
	for gone in ['name="QuestionImage"', 'name="ProgressLabel"', 'name="QuestionLabel"']:
		assert_false(src.contains(gone),
			"PilihanGanda.tscn must no longer declare %s -- the card owns it" % gone)

func test_pilihan_ganda_carries_no_font_size_override() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN)
	assert_false(src.contains("theme_override_font_sizes/font_size"),
		"PilihanGanda.tscn's 14px and 18px overrides must be gone")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL — the scene still declares the trio and the two overrides.

- [ ] **Step 3: Edit the scene through the editor**

`scene_open(path="res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
session_id="<worktree>")`.

Delete `VBoxContainer/QuestionImage`, `VBoxContainer/ProgressLabel` and
`VBoxContainer/QuestionLabel` with `node_manage`.

Instance `QuestionCard.tscn` under `VBoxContainer`, name it `SoalCard`, and
`move_node` it directly after `ScoreHUD`. On the instance **root only** (child
overrides silently do not serialise):

| Property | Value |
|---|---|
| `custom_minimum_size` | `Vector2(0, 960)` |
| `size_flags_horizontal` | `3` |
| `size_flags_vertical` | `3` |

Set `ChoicesGrid`'s `theme_override_constants/v_separation` to `12` — a
layout-only constant, which the house rule permits.

`scene_save(session_id="<worktree>")`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 9 tests.

Run: `test_run(suite="tall_screen_layout", session_id="<worktree>")`
Expected: PASS — `size_flags_vertical = 3` is what sends the extra 480px on a
20:9 phone into the picture instead of dead margin.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/Akademis/PilihanGanda.tscn tests/test_minigame_typography.gd
git commit -F <message file>
```

Message: `feat(pilihan-ganda): move the question onto the shared card`

---

### Task 4: PilihanGanda drives the card

**Files:**
- Modify: `Scripts/Minigames/Akademis/PilihanGanda.gd:107,164,237-267,298-307`
- Modify: `Scripts/Minigames/Akademis/SoalFit.gd` (docstring only)
- Modify: `tests/test_minigame_typography.gd`

**Interfaces:**
- Consumes: `SoalCard` from Task 3; `MinigameChoiceButton` from Task 1;
  `SoalFit.font_size(label, badge, text, max_size, min_size) -> int`.
- Produces: nothing later tasks consume.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_typography.gd`:

```gdscript
const PILIHAN_GD := "res://Scripts/Minigames/Akademis/PilihanGanda.gd"

func test_pilihan_ganda_has_no_font_size_literals() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN_GD)
	assert_false(src.contains("add_theme_font_size_override"),
		"PilihanGanda.gd must reach sizes through SoalFit and variations")

func test_pilihan_ganda_choice_rows_clear_the_touch_floor() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN_GD)
	assert_true(src.contains("answer_btn_min_height: int       = 130"),
		"answer_btn_min_height must be 130 -- 100 is under the 48dp touch floor")

func test_pilihan_ganda_fits_the_question_with_soalfit() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN_GD)
	assert_true(src.contains("SoalFit.font_size"),
		"the question must step down the ladder rather than clip")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL on all three.

- [ ] **Step 3: Patch the script**

Use `script_patch` (it matches bytes exactly and refreshes the loaded script;
a plain write needs a no-op `script_patch` afterwards to force the reload).

Repoint the `@onready` nodes at the card:

```gdscript
@onready var soal_card: Control = $VBoxContainer/SoalCard
@onready var question_label: Label = soal_card.find_child("TextLabel", true, false) as Label
@onready var question_image: TextureRect = soal_card.find_child("RowImage", true, false) as TextureRect
@onready var progress_label: Label = soal_card.find_child("BadgeLabel", true, false) as Label
```

Raise the touch floor:

```gdscript
## Minimum height (px) of each answer button, regardless of text length.
## 130 is the project's ~48dp touch floor in the 1080-wide design space.
@export var answer_btn_min_height: int       = 130
```

Replace the progress block — the badge is short, so it loses the score, which
`MinigameScoreHUD` already shows:

```gdscript
	if progress_label:
		progress_label.text = "Soal %d/%d" % [current_question_index + 1, active_questions.size()]
```

Replace the question block:

```gdscript
	if question_label:
		question_label.text = q_data.get("question", "")
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		question_label.add_theme_font_size_override("font_size",
			_fit_font_size(question_label.text))
```

…and add the fitter beside it, mirroring Password and Variabel:

```gdscript
## Largest size, from question_font_size down to min_question_font_size, at
## which the question fits the card without running under the Soal N/M badge.
func _fit_font_size(text: String) -> int:
	return SoalFit.font_size(question_label,
		soal_card.find_child("StatusBadge", true, false) as Control,
		text, question_font_size, min_question_font_size)
```

Retune the two exports to the rungs and drop the ones the variations own:

```gdscript
## Largest size for the question text; SoalFit shrinks from here.
@export var question_font_size: int  = 64
## Smallest size SoalFit will shrink a long question to.
@export var min_question_font_size: int = 36
```

Delete `progress_font_size`, `answer_btn_font_size` and every
`add_theme_font_override("font", font)` on these three labels — the variations
carry the face. In the choice-button loop replace the two override lines with:

```gdscript
			btn.theme_type_variation = &"MinigameChoiceButton"
```

The `_fit_font_size` call is the one remaining
`add_theme_font_size_override`; the test above forbids the literal form, so
keep the call expression (`_fit_font_size(...)`) rather than a number. If the
scan cannot distinguish them, tighten the assertion to forbid
`add_theme_font_size_override("font_size", ` followed by a digit.

Finally, correct `SoalFit.gd`'s docstring — it now serves four screens:

```gdscript
## Fits question text to the SoalCard (QuestionCard.tscn) on the Akademis
## quizzes: Variabel, Password, PilihanGanda and Menjodohkan's tiles.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 12 tests.

Run: `test_run(suite="script_documentation", session_id="<worktree>")`
Expected: PASS — every `@export` still carries its `##` line.

Run: `test_run(suite="viewport_editability", session_id="<worktree>")`
Expected: PASS. If `test_baseline_is_not_stale` fails it prints the exact
literal — paste the lowered count into `BASELINE` in this same commit. The
ratchet only turns down.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/Akademis/PilihanGanda.gd Scripts/Minigames/Akademis/SoalFit.gd tests/test_minigame_typography.gd
git commit -F <message file>
```

Message: `fix(pilihan-ganda): fit the question and raise the choice rows to 130`

---

### Task 5: Menjodohkan's headers and its duplicated size chains

**Files:**
- Modify: `Scenes/Minigames/Akademis/Menjodohkan.tscn`
- Modify: `Scripts/Minigames/Akademis/Menjodohkan.gd:415-445,465-495`
- Modify: `tests/test_minigame_typography.gd`

**Interfaces:**
- Consumes: `MinigameWheelHeaderWarm`, `MinigameWheelHeaderCool` from Task 1;
  `SoalFit.font_size` as in Task 4.

- [ ] **Step 1: Write the failing test**

```gdscript
const MENJODOHKAN := "res://Scenes/Minigames/Akademis/Menjodohkan.tscn"
const MENJODOHKAN_GD := "res://Scripts/Minigames/Akademis/Menjodohkan.gd"

func test_menjodohkan_headers_clear_the_contrast_floor() -> void:
	var src := FileAccess.get_file_as_string(MENJODOHKAN)
	for dead in ["Color(0.85, 0.45, 0.1, 1)", "Color(0.2, 0.5, 0.85, 1)"]:
		assert_false(src.contains(dead),
			"%s is mid-tone and cannot reach 4.5:1 on the card" % dead)
	for name in ["MinigameWheelHeaderWarm", "MinigameWheelHeaderCool"]:
		assert_true(src.contains(name),
			"Menjodohkan.tscn must use the %s variation" % name)

func test_menjodohkan_has_one_size_ladder_not_two_chains() -> void:
	var src := FileAccess.get_file_as_string(MENJODOHKAN_GD)
	for dead in ['"font_size", 90', '"font_size", 80', '"font_size", 70', '"font_size", 60']:
		assert_false(src.contains(dead),
			"the hand-rolled %s chain must be SoalFit's job" % dead)
	assert_true(src.contains("SoalFit.font_size"),
		"Menjodohkan.gd must fit tile text with SoalFit")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL on both.

- [ ] **Step 3: Scene first — the two headers**

`scene_open` Menjodohkan, then on the question-wheel header Label set
`theme_type_variation = "MinigameWheelHeaderWarm"`, and on the answer-wheel
header Label `"MinigameWheelHeaderCool"`. Clear
`theme_override_colors/font_color` and
`theme_override_font_sizes/font_size` on both (set to `null`). Leave the two
`Color(...)` values on any non-text node untouched — the test only forbids
them on these labels, so if the scan trips on an unrelated node, narrow it to
the header nodes' property lines.

`scene_save(session_id="<worktree>")`, then **restart the worktree editor**
before the script patch in the next step.

- [ ] **Step 4: Script second — replace both chains**

Both call sites (around `:422` and `:472`) carry the same four-branch ladder.
Replace each with one call. The tiles are `QuestionCard` instances, so the
badge argument is the card's own `StatusBadge`:

```gdscript
			txt_lbl.add_theme_font_size_override("font_size",
				SoalFit.font_size(txt_lbl,
					card.find_child("StatusBadge", true, false) as Control,
					txt_lbl.text, 96, 36))
```

Add the preload at the top of the file if it is not already there:

```gdscript
const SoalFit = preload("res://Scripts/Minigames/Akademis/SoalFit.gd")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 14 tests.

Run: `test_run(suite="viewport_editability", session_id="<worktree>")`
Expected: PASS — Menjodohkan's `BASELINE` is 2; if the chains' removal lowers
it, paste the printed literal in this commit.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Minigames/Akademis/Menjodohkan.tscn Scripts/Minigames/Akademis/Menjodohkan.gd tests/test_minigame_typography.gd
git commit -F <message file>
```

Message: `fix(menjodohkan): raise the wheel headers to 4.5:1 and fold the size chains`

---

### Task 6: BuatBatik's two sub-floor labels

**Files:**
- Modify: `Scripts/Minigames/SeniBudaya/BuatBatik.gd:512-520,553-561`
- Modify: `tests/test_minigame_typography.gd`

**Interfaces:**
- Consumes: `MinigameOverlayLabel` from Task 1.

- [ ] **Step 1: Write the failing test**

```gdscript
const BATIK_GD := "res://Scripts/Minigames/SeniBudaya/BuatBatik.gd"

func test_buat_batik_has_no_sub_floor_text() -> void:
	var src := FileAccess.get_file_as_string(BATIK_GD)
	assert_false(src.contains('add_theme_font_size_override("font_size", 16)'),
		"16px is 57% of the 28px body floor")
	assert_true(src.contains("MinigameOverlayLabel"),
		"BuatBatik's layer labels must use the overlay variation")

func test_buat_batik_drops_the_warning_glyph() -> void:
	var src := FileAccess.get_file_as_string(BATIK_GD)
	assert_false(src.contains("⚠"),
		"neither Boohong nor Open Sans carries this glyph -- see DEBT.md")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL on both.

- [ ] **Step 3: Patch both call sites**

At each of the two sites, the four override lines collapse to one variation —
the variation already carries 36px cream with an 8px black outline:

```gdscript
	lbl.theme_type_variation = &"MinigameOverlayLabel"
```

…replacing:

```gdscript
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
```

And drop the glyph:

```gdscript
	lbl.text = "Urutan Salah!"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 16 tests.

Run: `test_run(suite="minigame_art", session_id="<worktree>")`
Expected: PASS, 22 tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/SeniBudaya/BuatBatik.gd tests/test_minigame_typography.gd
git commit -F <message file>
```

Message: `fix(buat-batik): raise the layer labels off the 16px floor`

---

### Task 7: Badminton's score HUD anchor

**Files:**
- Modify: `Scenes/Minigames/Olahraga/Badminton.tscn`
- Modify: `tests/test_minigame_typography.gd`

**Interfaces:**
- Consumes: nothing. Produces: nothing.

- [ ] **Step 1: Write the failing test**

```gdscript
const BADMINTON := "res://Scenes/Minigames/Olahraga/Badminton.tscn"

func test_badminton_hud_is_anchored_not_offset() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON)
	assert_false(src.contains("offset_left = 390.0"),
		"the HUD must be anchored, not pinned at a raw 390px offset")
	assert_true(src.contains("anchor_left = 0.5"),
		"the HUD must be top-centre anchored so a 20:9 phone puts the extra height in the court")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: FAIL — the scene still carries `offset_left = 390.0`.

- [ ] **Step 3: Re-anchor the HUD**

`scene_open` Badminton. On `ScoreHUD` set `layout_mode = 1` first (a Control
under a plain Control starts in position mode, where anchors are not saved),
then the four anchors — `anchor_left = 0.5`, `anchor_right = 0.5`,
`anchor_top = 0`, `anchor_bottom = 0` — with `grow_horizontal = 2`,
`grow_vertical = 1`, `offset_top = 40`, `offset_bottom = 40`,
`offset_left = 0`, `offset_right = 0`. `anchors_preset` is inert; set the four
anchors. `scene_save(session_id="<worktree>")`.

The court itself needs nothing: `Badminton.gd:141–205` already rebuilds walls,
goals and paddles from `get_viewport_rect()`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="minigame_typography", session_id="<worktree>")`
Expected: PASS, 17 tests.

Run: `test_run(suite="badminton_visuals", session_id="<worktree>")`
Expected: PASS.

Run: `test_run(suite="minigame_score_hud", session_id="<worktree>")`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/Olahraga/Badminton.tscn tests/test_minigame_typography.gd
git commit -F <message file>
```

Message: `fix(badminton): anchor the score HUD to the top edge`

---

### Task 8: Full suite, ratchet reconcile, and the docs

**Files:**
- Modify: `tests/test_viewport_editability.gd` (only if a count dropped)
- Modify: `docs/superpowers/DEBT.md`
- Modify: `docs/superpowers/CHANGELOG.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Run the full suite**

Run: `test_run(session_id="<worktree>")`
Expected: every suite green. Budget one editor restart — a full run is 15–20s
of near-continuous main-thread work and the transport does not survive it. The
results are still valid when the drop happens after the reply arrives.

A single failing theme assertion may just be ordering: a suite that reads the
baked theme before `theme_rebake` runs sees the old bake. Re-run that suite
alone before believing it.

- [ ] **Step 2: Reconcile the ratchet**

If `viewport_editability`'s `test_baseline_is_not_stale` failed, paste the
printed literals into `BASELINE`. Counts may only go down in this pass; a
count that went **up** means something was built at runtime that should be a
node in the `.tscn` — fix the code, not the number.

- [ ] **Step 3: Check the two files a full run rewrites**

```bash
git status --porcelain
```

`Assets/Theme/kejartes_theme.tres` (rebaked by the `theme_rebake` suite) is
intended here — diff it and keep it. `Assets/Audio/default_bus_layout.tres` is
`AudioDirector` rewriting itself on boot — `git checkout --` it.

- [ ] **Step 4: Update DEBT.md and CHANGELOG.md**

In `DEBT.md`, delete the resolved entries rather than marking them done, and
add one new entry for what this pass deliberately left:

> **Minigame art slots (2026-09-21).** `monas.png` (1080×1920) and
> `borobudur.png` (1920×1920) are background-sized assets standing in as
> question illustrations. `QuestionCard`'s 620px slot centres them without
> distortion — monas renders 349×620 — but a cropped landscape export at the
> same paths would fill it properly.

In `CHANGELOG.md`, newest first, one entry for the pass.

- [ ] **Step 5: Commit**

```bash
git add tests/test_viewport_editability.gd docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md Assets/Theme/kejartes_theme.tres
git commit -F <message file>
```

Message: `docs(minigames): record the type-ladder pass`

---

## Self-review

**Spec coverage.** Every spec section maps to a task: the ladder and its
variations → Task 1; `QuestionCard` typography, border, badge and lock →
Task 2; PilihanGanda's card adoption and the vertical budget → Task 3; the
image slot, `SoalFit` and the 130px touch floor → Tasks 2 and 4; Menjodohkan's
contrast and its duplicated chains → Task 5; BuatBatik's sub-floor labels and
the `⚠` glyph → Task 6; Badminton's HUD anchor → Task 7; the ratchet, DEBT and
CHANGELOG → Task 8. The spec's "Not doing" list is not implemented anywhere,
which is correct.

**Placeholder scan.** No TBD/TODO; every code step carries the actual code.
Two steps are deliberately conditional rather than vague — Task 4 Step 4 and
Task 5 Step 5 paste a `BASELINE` literal *that the failing test prints*, and
Task 8 Step 2 does the same. That is the ratchet's documented workflow, not a
placeholder.

**Type consistency.** `SoalFit.font_size(label, badge, text, max_size,
min_size) -> int` is called with the same five-argument shape in Tasks 4 and 5.
The node names `SoalCard`, `TextLabel`, `RowImage`, `BadgeLabel`,
`StatusBadge` are used identically in Tasks 2, 3, 4 and 5. The seven variation
names in Task 1's `VARIATIONS` dict are spelled the same everywhere they are
consumed.

**One known risk, carried into the summary.** Task 4's test forbids
`add_theme_font_size_override` outright, but the `SoalFit` call site legitimately
uses it. Task 4 Step 3 names the fallback (tighten the assertion to the literal
form). If the first run trips on this, that is expected, not a defect.
