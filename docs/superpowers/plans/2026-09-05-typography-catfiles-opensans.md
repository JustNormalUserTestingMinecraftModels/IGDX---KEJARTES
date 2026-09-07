# Typography Pass — Catfiles for Heads, Open Sans Medium for Body

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every heading/title in the game renders in `Catfiles.otf`; every body,
caption, and data string renders in `OpenSans-Medium.ttf`.

**Architecture:** The project **already has the head/body split** — `DesignTokens`
exposes `font_display` and `font_body`, `ThemeFactory` applies `font_display` to
selected type variations and `font_body` as the theme's `default_font`. Today both
slots point at `Milker.otf`, so the split is invisible. Two things are therefore
needed, and only two: (1) point the two slots at the new files, and (2) fix
`ThemeFactory`'s *classification*, which currently keys "gets `font_display`" off an
unrelated `outlined` boolean rather than off headingness — which is why `H2Label`
and `TitleLabel`, both headings, currently take the body font. There is **no
scene-by-scene text sweep**: a grep proved there are zero `theme_override_fonts/`
entries in any shipped `.tscn`, so 100% of the game's font family resolves through
the theme.

**Tech Stack:** Godot 4.6, GDScript, `DesignTokens` resource + `ThemeFactory`
baker, `McpTestSuite` suites run through the `godot-ai` MCP `test_run` tool.

## Global Constraints

- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only
  accepted exception: layout-only constants (`separation`, `margin_*`).
  (`CLAUDE.md` → "Visual system".)
- **Never hand-edit a `.tscn` or `.tres` while the editor is attached.** The
  editor's in-memory copy wins and the next `scene_save` silently overwrites the
  text edit. Go through MCP ops or a transient `@tool` suite.
- **Rescan after editing a `.gd`, before running tests** — `test_run` serves stale
  autoloads otherwise. When the `.gd` was edited from outside the editor, a scan is
  not always enough: a no-op `script_patch` on that same file (add and remove a
  blank line) forces the reload.
- **Do not edit `Balance.gd`.** Collaborator-owned.
- Every script needs a `##` file header and a `##` line on every `@export`
  (`tests/test_script_documentation.gd` is a hard ratchet).
- Test suites must be `@tool` and **no test may be a coroutine** — the runner does
  `suite.call(name)` without awaiting.
- Baseline to hold: **64 suites, 940 tests, all green.**
- UI text is Indonesian; systems code is English.
- Commits: Conventional Commits with a scope, e.g. `feat(theme): ...`.

---

## Survey findings (read before Task 1 — this is the whole problem statement)

**Fonts are not imported yet.** `Assets/Fonts/` contains `Catfiles.otf` and 44
OpenSans `.ttf` files, none of which has a `.import` sidecar and none of which
appears in `.godot/imported/`. Godot cannot `load()` them until the editor scans.

**Zero font-family escapes in shipped scenes:**

```
grep -rn "theme_override_fonts/" --include=*.tscn Scenes/   →  0 matches
grep -rn "FontFile"              --include=*.tscn Scenes/   →  0 matches
```

The only two files in the repo that reference `res://Assets/Fonts/` at all are
`Assets/Theme/design_tokens.tres` and `Assets/Theme/kejartes_theme.tres`. Text
surface being retyped: 304 `Label`, 127 `Button`, 2 `RichTextLabel`, 1 `LineEdit`.

**The 70 `theme_override_font_sizes/` entries are sizes, not families**, and all sit
in minigames / koperasi / inventory. They are untouched by this plan.

**The minigame `add_theme_font_override("font", font)` calls are dead code.** Each
minigame script declares `@export var font: Font = null`; grep proves no `.tscn`
assigns it, and every call site is guarded by `if font:`. They no-op today and will
keep no-opping. Task 6 documents this rather than changing behaviour.

### Current classification in `Scripts/Design/ThemeFactory.gd`

`font_body` is the theme `default_font` (line 15-16), so anything not listed below
already resolves to the body font.

Variations that currently take `font_display`:

| Variation | Line | Correct? |
|---|---|---|
| `MainMenuButton` | 166-167 | keep display |
| `PrimaryButton` / `SecondaryButton` / `DangerButton` / `SuccessButton` / `QuirkBadge` / `PersonaBadge` / `LobbyNavButton` (all via `_add_button_variation`) | 207-208 | keep display |
| `DisplayLabel`, `H1Label` | 318-319 | keep display |
| `TraitPill` | 539-540 | keep display |
| `PreviewRowLabel` | 615-616 | keep display |
| `DaySummaryName`, `DaySummaryStat` | 691-692 | keep display |
| `DaySummaryNeedsLabel` | 752-753 | keep display |
| `RecapPillValueLabel` | 793-794 | keep display |
| `ScoreHudValueLabel` | 918-919 | keep display |

**The bug:** in `_build_labels` (line 289-319) `font_display` is applied inside
`if spec[3]:` — the *outlined* flag — not from a headingness flag. Headings that are
not outlined therefore silently take the body font. Task 2 fixes this by adding an
explicit column.

Headings to **promote** to `font_display`:

| Variation | Line | Uses in scenes | Why |
|---|---|---|---|
| `H2Label` | specs table, 293 | 13 | It is a heading. Currently body only because it is not outlined. |
| `TitleLabel` | specs table, 294 | 16 | Same. |
| `CardSectionLabel` | 545-550 | 14 | Section heading on the student card. |
| `ResultHeroLabel` | 388-393 | 1 | The RunResult hero line. Outlined, but built outside `_build_labels` so it never got the font. |

Everything else stays on `font_body`: `CaptionLabel`, `MicroLabel`,
`EmptyStateLabel`, `PageDotLabel`, `ResultBodyLabel`, `ResultDeltaLabel`,
`BioLabel`, `BioValue`, `PreviewChipLabel`, `BodyLabel`, and every untagged
`Label` / `RichTextLabel`.

### Judgment calls — decided, with a one-line flip each

These are the only genuinely arguable rows. Each is decided below; if the user
disagrees on review, the flip is one line.

| Variation | Uses | Decision | Reasoning | To flip |
|---|---|---|---|---|
| `BarLabel` | **130** | **body** (unchanged) | Highest-traffic variation in the game. It is stat-bar chrome — words like "Lelah"/"Senang" and numbers over a 36px bar — reading as data, not a heading. Catfiles is decorative; at 36px inside a bar it is the likeliest place to overflow. | add `theme.set_font("font", "BarLabel", tokens.font_display)` after line 337 |
| Buttons (`PrimaryButton` &c.) | 46 | **display** (unchanged) | Already display today; Indonesian CTA labels are short and prominent. Preserves current look. | delete the `set_font` at 207-208 |
| `CoinLabel` / `ShopCoinLabel` | 2 | **body** (unchanged) | Currency figures; legibility over character. | add `set_font(..., tokens.font_display)` |
| `TraitPill` | 24 | **display** (unchanged) | Already display; it is a badge, not prose. | delete the `set_font` at 539-540 |

---

## File Structure

- **Modify** `Assets/Fonts/*` — no edits, but 45 `.import` sidecars get generated by
  the editor scan in Task 1 and must be committed.
- **Modify** `Scripts/Design/ThemeFactory.gd` — add the `heading` column to
  `_build_labels`; add two `set_font` calls outside it. Task 2.
- **Modify** `Assets/Theme/design_tokens.tres` — repoint `font_display` and
  `font_body`. Written by a transient suite, not by hand. Task 3.
- **Modify** `Assets/Theme/kejartes_theme.tres` — regenerated by the rebake. Task 3.
- **Create then delete** `tests/test_zz_apply_typography.gd` — the transient
  `@tool` suite that stands in for `File > Run` on `BakeTheme.gd`. Task 3.
- **Create** `tests/test_fonts_present.gd` — import + glyph-coverage guard. Task 1.
- **Modify** `tests/test_theme_factory.gd` — pin the classification. Tasks 2 and 4.
- **Modify** `CLAUDE.md` + `docs/superpowers/CHANGELOG.md` + `Assets/Fonts/README.md`
  — Task 6.

---

## Task 1: Import the fonts and prove they load

**Files:**
- Modify: `Assets/Fonts/` (45 generated `.import` sidecars)
- Test: `tests/test_fonts_present.gd` (create)

**Interfaces:**
- Produces: `res://Assets/Fonts/Catfiles.otf` and
  `res://Assets/Fonts/OpenSans-Medium.ttf` loadable as `FontFile`. Tasks 2-6 depend
  on this and on nothing else from this task.

- [ ] **Step 1: Write the failing test**

Create `tests/test_fonts_present.gd`:

```gdscript
@tool
## Guards that the two typography fonts are imported and usable.
##
## Godot cannot `load()` a font that has no `.import` sidecar, and a
## missing sidecar fails silently at bake time -- ThemeFactory's
## `if tokens.font_display != null` guard just skips the assignment and
## every heading quietly falls back to the body font. This suite turns
## that silent fallback into a red test.
extends McpTestSuite

const DISPLAY_PATH := "res://Assets/Fonts/Catfiles.otf"
const BODY_PATH := "res://Assets/Fonts/OpenSans-Medium.ttf"

## Indonesian UI copy plus the digits and punctuation the stat readouts
## use. Every glyph here must exist in both faces or text renders as
## tofu boxes in the shipped build.
const PROBE := "Jadwal Minggu Ini: 12/65 (Seni Budaya) - Rp1.000"


func suite_name() -> String:
	return "fonts_present"


func test_display_font_loads() -> void:
	var f := load(DISPLAY_PATH)
	assert_true(f != null, "Catfiles.otf must be imported (run a filesystem scan)")
	assert_true(f is FontFile, "Catfiles.otf must import as a FontFile")


func test_body_font_loads() -> void:
	var f := load(BODY_PATH)
	assert_true(f != null, "OpenSans-Medium.ttf must be imported")
	assert_true(f is FontFile, "OpenSans-Medium.ttf must import as a FontFile")


func test_display_font_covers_the_ui_alphabet() -> void:
	var f: FontFile = load(DISPLAY_PATH)
	assert_true(f != null, "font must load before glyph coverage can be checked")
	var missing := ""
	for i in PROBE.length():
		var c := PROBE[i]
		if c == " ":
			continue
		if not f.has_char(c.unicode_at(0)):
			missing += c
	assert_eq(missing, "", "Catfiles is missing glyphs: %s" % missing)


func test_body_font_covers_the_ui_alphabet() -> void:
	var f: FontFile = load(BODY_PATH)
	assert_true(f != null, "font must load before glyph coverage can be checked")
	var missing := ""
	for i in PROBE.length():
		var c := PROBE[i]
		if c == " ":
			continue
		if not f.has_char(c.unicode_at(0)):
			missing += c
	assert_eq(missing, "", "OpenSans-Medium is missing glyphs: %s" % missing)
```

- [ ] **Step 2: Run it and confirm it fails**

MCP: `test_run(suite="fonts_present")`
Expected: FAIL — `Catfiles.otf must be imported`. `load()` returns `null` because no
`.import` sidecar exists.

If it *passes* here, the fonts were already imported by an editor that had focus.
Skip to Step 5.

- [ ] **Step 3: Trigger the import**

MCP: `filesystem_manage(op="scan")`

Then confirm the sidecars landed:

```bash
ls Assets/Fonts/Catfiles.otf.import Assets/Fonts/OpenSans-Medium.ttf.import
```

If `filesystem_manage(op="scan")` does not produce them, the fallback is to focus
the Godot editor window once — Godot imports on window focus — then re-run the `ls`.
If Catfiles still fails to import, read `logs_read(source="editor")`; an OTF with a
broken `name` table is the usual cause, and the remedy is to ask the user for a
re-export rather than to work around it.

- [ ] **Step 4: Run it and confirm it passes**

MCP: `test_run(suite="fonts_present")`
Expected: PASS, 4 tests.

A failure on `test_display_font_covers_the_ui_alphabet` is a **real blocker, not a
test to loosen** — it means Catfiles has no lowercase, or no digits, or no
parentheses. Record exactly which glyphs are missing, stop, and report to the user;
do not proceed to Task 3, because a heading font with no lowercase changes the whole
design brief.

- [ ] **Step 5: Commit**

```bash
git add Assets/Fonts tests/test_fonts_present.gd tests/test_fonts_present.gd.uid
git commit -m "chore(fonts): import Catfiles and the Open Sans family"
```

Note: `test_run` generates the `.gd.uid` sidecar. If it is absent, run the suite
once more before committing — a missing `.uid` is what commit `9c26721` had to
clean up.

---

## Task 2: Classify headings explicitly in ThemeFactory

Fixes the `outlined`-flag coupling. No font files change here — both slots are still
Milker, so **this task must produce a zero-pixel visual diff** while moving four
variations onto the `font_display` slot. That is exactly what makes it safe to do
before Task 3.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd:289-319` (specs table + loop),
  `:388-393` (`ResultHeroLabel`), `:545-550` (`CardSectionLabel`)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: `DesignTokens.font_display`, `DesignTokens.font_body` (both already
  exist; unchanged signatures).
- Produces: after `ThemeFactory.build(tokens)`, `theme.get_font("font", <name>)`
  returns `tokens.font_display` for exactly this set —
  `DisplayLabel`, `H1Label`, `H2Label`, `TitleLabel`, `CardSectionLabel`,
  `ResultHeroLabel`, `MainMenuButton`, `PrimaryButton`, `SecondaryButton`,
  `DangerButton`, `SuccessButton`, `QuirkBadge`, `PersonaBadge`, `LobbyNavButton`,
  `TraitPill`, `PreviewRowLabel`, `DaySummaryName`, `DaySummaryStat`,
  `DaySummaryNeedsLabel`, `RecapPillValueLabel`, `ScoreHudValueLabel` —
  and `null` (i.e. inherits `default_font`) for every other variation.
  Task 4 asserts this set verbatim.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_theme_factory.gd`:

```gdscript
func test_headings_take_the_display_font() -> void:
	# H2Label and TitleLabel are headings but are not outlined. Before the
	# 2026-09-05 typography pass they took the body font, because
	# _build_labels keyed the display font off the outline flag.
	var tokens := DesignTokens.load_default()
	if tokens.font_display == null:
		# Nothing to assert while the slot is empty; Task 1/3 fills it.
		assert_true(true, "display slot unassigned, skipping")
		return
	for name in ["DisplayLabel", "H1Label", "H2Label", "TitleLabel"]:
		assert_eq(_theme.get_font("font", name), tokens.font_display,
			"%s must take the display font" % name)


func test_section_and_hero_headings_take_the_display_font() -> void:
	# CardSectionLabel and ResultHeroLabel are built outside _build_labels
	# and so were never reached by its font assignment at all.
	var tokens := DesignTokens.load_default()
	if tokens.font_display == null:
		assert_true(true, "display slot unassigned, skipping")
		return
	assert_eq(_theme.get_font("font", "CardSectionLabel"), tokens.font_display,
		"CardSectionLabel must take the display font")
	assert_eq(_theme.get_font("font", "ResultHeroLabel"), tokens.font_display,
		"ResultHeroLabel must take the display font")


func test_body_labels_do_not_take_the_display_font() -> void:
	# The other half of the contract: promoting headings must not sweep up
	# captions, prose, or stat-bar chrome. BarLabel in particular is the
	# highest-traffic variation in the game (130 scene uses) and stays body.
	for name in ["CaptionLabel", "MicroLabel", "EmptyStateLabel",
			"ResultBodyLabel", "BioLabel", "BarLabel"]:
		assert_true(_theme.get_font("font", name) == null,
			"%s must inherit default_font, not the display font" % name)
```

- [ ] **Step 2: Run it and confirm it fails**

MCP: `test_run(suite="theme_factory")`
Expected: FAIL on `H2Label must take the display font` — `get_font` returns `null`.

Note the two guards return early while `font_display` is unassigned. Right now
`design_tokens.tres` **does** assign it (to Milker), so the guards do not fire and
the tests really run. They exist so this suite stays honest if the slot is ever
cleared.

- [ ] **Step 3: Add the `heading` column to `_build_labels`**

In `Scripts/Design/ThemeFactory.gd`, replace the spec table comment and rows
(currently line 290-307) so each row carries a fifth field:

```gdscript
	# name, size, color, outlined, heading
	#
	# `outlined` and `heading` are deliberately independent. Before
	# 2026-09-05 the display font was applied inside the `outlined`
	# branch, which silently gave every un-outlined heading the body
	# font. Outline is about the backdrop a label sits on; heading is
	# about typographic role. They coincide for DisplayLabel/H1Label and
	# diverge for H2Label/TitleLabel.
	var specs := [
		["DisplayLabel", tokens.font_display_size, tokens.text_primary, true, true],
		["H1Label", tokens.font_h1, tokens.text_primary, true, true],
		["H2Label", tokens.font_h2, tokens.text_primary, false, true],
		["TitleLabel", tokens.font_title, tokens.text_primary, false, true],
		["CaptionLabel", tokens.font_caption, tokens.text_secondary, false, false],
		["MicroLabel", tokens.font_micro, tokens.text_secondary, false, false],
		# PageDotLabel styled the SemesterEnd carousel's page dots and has
		# had no consumer since Plan A deleted that screen. Kept baked
		# rather than removed: dropping a variation needs a theme rebake,
		# which has no headless path. Nothing above this line is unused.
		["PageDotLabel", tokens.font_caption, tokens.text_disabled, false, false],
		# The "no items match this filter" placeholder text. 32px doesn't
		# match a token exactly (nearest are font_body_size 28 / font_title
		# 36); kept as the shipped literal rather than nudging the size.
		["EmptyStateLabel", 32, tokens.text_disabled, false, false],
	]
```

Then rewrite the loop body (currently line 308-319) so the font assignment moves out
of the `outlined` branch:

```gdscript
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
		if spec[4] and tokens.font_display != null:
			theme.set_font("font", name, tokens.font_display)
```

- [ ] **Step 4: Give `CardSectionLabel` and `ResultHeroLabel` the display font**

After the `set_color("font_outline_color", "ResultHeroLabel", ...)` line (currently
:393), add:

```gdscript
	if tokens.font_display != null:
		theme.set_font("font", "ResultHeroLabel", tokens.font_display)
```

After the `set_color("font_outline_color", "CardSectionLabel", ...)` line
(currently :550), add:

```gdscript
	if tokens.font_display != null:
		theme.set_font("font", "CardSectionLabel", tokens.font_display)
```

- [ ] **Step 5: Force the script reload, then run the tests**

Because `ThemeFactory.gd` was edited from outside the editor, a scan alone can serve
stale bytecode. Do a no-op `script_patch` on it (add and remove a blank line) — this
logs a benign `GDScript reload failed with error code 43` and then works.

MCP: `test_run(suite="theme_factory")`
Expected: PASS.

- [ ] **Step 6: Run the whole suite**

MCP: `test_run()`
Expected: 65 suites green (64 original + `fonts_present`), 944+ tests, zero
failures. Nothing visual has changed — both slots are still Milker — so any failure
here is a real regression in the loop rewrite, most likely a lost `outline_size` on
`DisplayLabel`/`H1Label`.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd
git commit -m "fix(theme): classify headings independently of the outline flag"
```

---

## Task 3: Point the tokens at Catfiles / Open Sans Medium and rebake

**Files:**
- Modify: `Assets/Theme/design_tokens.tres` (via script, not by hand)
- Modify: `Assets/Theme/kejartes_theme.tres` (regenerated)
- Create then delete: `tests/test_zz_apply_typography.gd`

**Interfaces:**
- Consumes: the imported fonts from Task 1, the classification from Task 2.
- Produces: `DesignTokens.load_default().font_display.resource_path ==
  "res://Assets/Fonts/Catfiles.otf"` and `.font_body.resource_path ==
  "res://Assets/Fonts/OpenSans-Medium.ttf"`, and a `kejartes_theme.tres` baked from
  them.

There is no MCP entry point for an `EditorScript`, so `Scripts/Design/BakeTheme.gd`
cannot be run headlessly. The documented workaround is a transient `@tool`
`McpTestSuite` that does the work in a test body and is deleted afterwards. This is
also why the tokens are edited by script rather than by hand: the attached editor
caches `.tres` files exactly as it caches `.tscn` files, and would overwrite a text
edit on its next save.

- [ ] **Step 1: Write the transient applier suite**

Create `tests/test_zz_apply_typography.gd`:

```gdscript
@tool
## TRANSIENT -- delete after running once. See
## docs/superpowers/plans/2026-09-05-typography-catfiles-opensans.md Task 3.
##
## Stands in for `File > Run` on Scripts/Design/BakeTheme.gd, which has no
## headless entry point. Repoints the two font slots on design_tokens.tres
## and rebakes kejartes_theme.tres from them.
extends McpTestSuite

const TOKENS_PATH := "res://Assets/Theme/design_tokens.tres"
const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const DISPLAY_PATH := "res://Assets/Fonts/Catfiles.otf"
const BODY_PATH := "res://Assets/Fonts/OpenSans-Medium.ttf"


func suite_name() -> String:
	return "zz_apply_typography"


func test_apply_fonts_and_rebake() -> void:
	var display_font: FontFile = load(DISPLAY_PATH)
	var body_font: FontFile = load(BODY_PATH)
	assert_true(display_font != null, "Catfiles must be imported (Task 1)")
	assert_true(body_font != null, "OpenSans-Medium must be imported (Task 1)")

	var tokens: DesignTokens = load(TOKENS_PATH)
	tokens.font_display = display_font
	tokens.font_body = body_font
	var token_err := ResourceSaver.save(tokens, TOKENS_PATH)
	assert_eq(token_err, OK, "design_tokens.tres must save")

	var theme := ThemeFactory.build(tokens)
	assert_true(theme != null, "bake must return a Theme")
	var theme_err := ResourceSaver.save(theme, THEME_PATH)
	assert_eq(theme_err, OK, "kejartes_theme.tres must save")

	# Prove the bake actually carried the fonts, not just that it saved.
	assert_eq(theme.default_font, body_font,
		"default_font must be the body font")
	assert_eq(theme.get_font("font", "H1Label"), display_font,
		"H1Label must be baked with the display font")
```

`zz_` prefixes the filename so it sorts last and is trivially findable for deletion.

- [ ] **Step 2: Run it**

MCP: `filesystem_manage(op="scan")` then `test_run(suite="zz_apply_typography")`
Expected: PASS, 1 test, 7 assertions.

- [ ] **Step 3: Verify the files on disk actually changed**

```bash
git diff --stat Assets/Theme/
```

Expected: both `design_tokens.tres` and `kejartes_theme.tres` modified.

```bash
grep -n "Assets/Fonts" Assets/Theme/design_tokens.tres
```

Expected: two `ext_resource` lines, one `Catfiles.otf`, one `OpenSans-Medium.ttf`,
and **no remaining `Milker.otf` line**. If Milker is still referenced, the editor's
cached copy won — rescan and re-run Step 2 before doing anything else.

- [ ] **Step 4: Delete the transient suite**

```bash
rm tests/test_zz_apply_typography.gd tests/test_zz_apply_typography.gd.uid
```

- [ ] **Step 5: Rescan and run the full suite**

MCP: `filesystem_manage(op="scan")` then `test_run()`
Expected: 65 suites green (64 original + `fonts_present`, transient deleted), zero
failures.

Suites that assert on *text width or node size* are the plausible failures here,
since the metrics of Catfiles and Open Sans differ from Milker's. Treat any such
failure as a real overflow finding and carry it into Task 5 rather than relaxing the
assertion.

- [ ] **Step 6: Commit**

```bash
git add Assets/Theme/design_tokens.tres Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): set Catfiles as the display font and Open Sans Medium as body"
```

---

## Task 4: Pin the classification against drift

Task 2's tests assert that four specific headings got promoted. This task asserts
the *complete* set both ways, so that a future variation added without thought fails
loudly instead of silently inheriting the wrong face.

**Files:**
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: the `Produces` set listed in Task 2's Interfaces block, verbatim.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_theme_factory.gd`:

```gdscript
## Every variation that must render in the display face. Adding a
## variation to ThemeFactory without adding it here (or deliberately
## leaving it out) will fail test_display_font_roster_is_exact.
const DISPLAY_ROSTER := [
	"DisplayLabel", "H1Label", "H2Label", "TitleLabel",
	"CardSectionLabel", "ResultHeroLabel",
	"MainMenuButton", "PrimaryButton", "SecondaryButton", "DangerButton",
	"SuccessButton", "QuirkBadge", "PersonaBadge", "LobbyNavButton",
	"TraitPill", "PreviewRowLabel",
	"DaySummaryName", "DaySummaryStat", "DaySummaryNeedsLabel",
	"RecapPillValueLabel", "ScoreHudValueLabel",
]


func test_display_font_roster_is_exact() -> void:
	# Both directions. A one-directional check would pass while a new
	# heading quietly inherited the body font, which is the exact bug
	# H2Label and TitleLabel had before 2026-09-05.
	var tokens := DesignTokens.load_default()
	assert_true(tokens.font_display != null, "display slot must be assigned")
	for name in DISPLAY_ROSTER:
		assert_eq(_theme.get_font("font", name), tokens.font_display,
			"%s is on the display roster but did not get the display font" % name)

	var strays := []
	for name in _theme.get_type_list():
		if name in DISPLAY_ROSTER:
			continue
		if _theme.get_font("font", name) == tokens.font_display:
			strays.append(name)
	assert_eq(strays.size(), 0,
		"these got the display font but are not on the roster: %s" % str(strays))


func test_default_font_is_the_body_face() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(_theme.default_font, tokens.font_body,
		"default_font must be the body face so untagged Labels inherit it")


func test_the_two_faces_are_actually_different() -> void:
	# Before 2026-09-05 both slots pointed at Milker.otf, so the whole
	# head/body split existed in code and was invisible on screen. This
	# is the assertion that would have caught that.
	var tokens := DesignTokens.load_default()
	assert_true(tokens.font_display != null, "display slot must be assigned")
	assert_true(tokens.font_body != null, "body slot must be assigned")
	assert_true(tokens.font_display != tokens.font_body,
		"display and body must be different faces")
```

- [ ] **Step 2: Run it**

MCP: `test_run(suite="theme_factory")`
Expected: PASS. If `test_display_font_roster_is_exact` reports strays, reconcile:
either the stray genuinely belongs on the roster (add it, and say so in the commit)
or Task 2 over-applied (remove the `set_font`). Do not just append the stray to the
roster to make the test green.

- [ ] **Step 3: Commit**

```bash
git add tests/test_theme_factory.gd
git commit -m "test(theme): pin the display/body font roster in both directions"
```

---

## Task 5: Overflow and legibility audit

The only genuinely visual task. Catfiles and Open Sans have different x-heights and
advance widths from Milker, so fixed-width pills, bars, and buttons are where this
change breaks. Sizes are **not** adjusted blind: find real overflows, fix those.

**Files:**
- Modify: `Assets/Theme/design_tokens.tres` only if an overflow is found (via the
  same transient-suite technique as Task 3)

- [ ] **Step 1: Seed a playable state**

MCP: `project_run()`. In the running game press `F1` (or 5 taps top-right) to open
the debug overlay, General tab → **⚡ Seed Playtest State**. This gives an approved
roster, 999999G, full inventory, and bypasses the lobby tutorial.

It does **not** fill `day_schedules`, so before screenshotting SchoolDay or
AturJadwal, make one pass through Atur Jadwal to assign a week.

- [ ] **Step 2: Screenshot the dense screens**

Use the overlay's **Scenes** tab to teleport; `editor_screenshot` after each. Capture
in this order — these are the layouts most likely to overflow, densest first:

1. **Lobby** — `LobbyNavButton` × 5, the highest-traffic display-font buttons.
2. **StudentCard** — `CardSectionLabel` (14 uses, newly promoted) and `TraitPill`
   (24 uses) inside fixed-width pills.
3. **AturJadwal** — `PreviewRowLabel`, `TitleLabel`, and the schedule pills.
4. **SchoolDay** — `DaySummaryName` / `DaySummaryStat` / `DaySummaryNeedsLabel`,
   all inside the day-summary card's fixed art frame. The needs label already has a
   dedicated `day_needs_label_size` token *because* a font bump once overran the
   needs pill; it is the single most likely regression on this screen.
5. **StatCheck** and **RunResult** — via the overlay's **🎭 Gladi Resik Akhir
   Kelas** → *Campur*, which ladders 3/2/1/0 cleared targets. Covers
   `ResultHeroLabel` (newly promoted), `ResultBodyLabel`, `BarLabel` at 130 sites,
   and the `StarMeter`. Arm **↩ Pulihkan Run Sebelum Gladi Resik** afterwards —
   RunResult otherwise advances the grade and clears the roster on its way out.
6. **MainMenu** — `MainMenuButton` at 80px, the largest display-font text in the
   game and the fastest place to spot a broken glyph.

Clicking quirks, if a screenshot needs a click to reach: send a `motion` event to
the target before the `button` press (a bare press/release silently does nothing),
and rescale coordinates — `global_rect` is in the 1080-wide design space while input
events take window pixels, so `window_x = global_x * original_width / 1080`, with
`original_width` read from the `editor_screenshot` reply.

- [ ] **Step 3: Judge each screenshot against three questions**

- Is any text **clipped or ellipsised** where it previously fit?
- Is body text **legible at 22px** (`font_caption`) and 18px (`font_micro`)? Open
  Sans Medium is a text face and should be fine; this is a sanity check.
- Does Catfiles **read as a heading** at 36px (`font_title`) — the smallest size it
  now appears at, on `TitleLabel`? A decorative face can fall apart at small sizes.
  If it does, the fix is to demote `TitleLabel` to body (drop its `heading` flag in
  the specs table and its roster entry in Task 4), not to change the font size.

- [ ] **Step 4: Fix only what is actually broken**

For a clipped label, prefer in this order: (a) lower the specific size token —
`day_needs_label_size` and friends exist for exactly this; (b) demote that one
variation to the body face; (c) change layout. Never add a `theme_override_*`.

Apply any token change through a transient suite as in Task 3 — copy that suite,
change the two `tokens.<field> = <value>` lines, run it, delete it. The `.tres` may
not be hand-edited while the editor is attached.

- [ ] **Step 5: Re-run the full suite and commit**

MCP: `test_run()`
Expected: all suites green.

```bash
git add -A
git commit -m "fix(theme): resize the labels Catfiles metrics overran"
```

If Step 3 found nothing to fix, skip this commit entirely — do not manufacture a
change.

---

## Task 6: Document and close out

**Files:**
- Modify: `Assets/Fonts/README.md`
- Modify: `docs/superpowers/CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Record the roles in the fonts README**

Append to `Assets/Fonts/README.md`:

```markdown
## Roles (2026-09-05)

- `Catfiles.otf` — the **display** face. Headings, titles, buttons, badges,
  and stat numerals. Wired as `DesignTokens.font_display`.
- `OpenSans-Medium.ttf` — the **body** face. Everything else, including every
  untagged Label. Wired as `DesignTokens.font_body`, which `ThemeFactory` sets
  as the theme's `default_font`.
- `Milker.otf`, `Baloo2-Variable.ttf`, `Nunito-Variable.ttf` — no longer
  referenced by the theme. Kept in the repo, unused.

The other 43 Open Sans weights are imported but unused. Reach for one only
through a new `DesignTokens` slot, never a `theme_override_fonts/` entry.

Which variations take which face is pinned by `DISPLAY_ROSTER` in
`tests/test_theme_factory.gd`. Change the roster and the factory together.
```

- [ ] **Step 2: Note the dead minigame font exports**

The survey found `@export var font: Font = null` on ten minigame scripts, never
assigned in any `.tscn`, with every use guarded by `if font:`. They are inert and
this pass does not change that. Record it in the CHANGELOG entry rather than editing
the minigames — minigames are explicitly out of scope for the design system.

- [ ] **Step 3: Add the CHANGELOG entry**

Newest first, at the top of `docs/superpowers/CHANGELOG.md`:

```markdown
## 2026-09-05 — Typography: Catfiles heads, Open Sans Medium body

Imported `Catfiles.otf` and the Open Sans family (none had `.import`
sidecars) and pointed `DesignTokens.font_display` / `font_body` at
Catfiles and OpenSans-Medium. Both slots had pointed at `Milker.otf`, so
the head/body split existed in code and was invisible on screen.

Fixed the classification bug behind that: `ThemeFactory._build_labels`
applied the display font inside the `outlined` branch, so `H2Label` and
`TitleLabel` — headings that are not outlined — silently took the body
face. Added an explicit `heading` column and promoted `H2Label`,
`TitleLabel`, `CardSectionLabel` and `ResultHeroLabel`.

`BarLabel` (130 scene uses) stays on the body face deliberately: it is
stat-bar chrome, not a heading.

No scene edits were needed — a grep proved zero `theme_override_fonts/`
entries in any shipped `.tscn`, so the whole font family resolves through
the theme. The 70 `theme_override_font_sizes/` entries are sizes, in
minigames and koperasi/inventory, and were untouched.

Noted in passing, not changed: ten minigame scripts declare
`@export var font: Font = null` and call `add_theme_font_override` behind
`if font:`. No `.tscn` assigns the export, so the calls are inert.

`tests/test_fonts_present.gd` (new) guards import + glyph coverage;
`tests/test_theme_factory.gd` gained `DISPLAY_ROSTER`, asserted in both
directions.
```

- [ ] **Step 4: Update CLAUDE.md**

In the "Visual system" section, after the `design_tokens.tres` paragraph, add:

```markdown
Two faces: **Catfiles** (`font_display`) for headings, titles, buttons and
badges; **Open Sans Medium** (`font_body`) for everything else, as the
theme's `default_font`. Which variation gets which is pinned in both
directions by `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` — change
the roster and `ThemeFactory` together, or the suite fails.
```

Do **not** add a `## Current work` entry — this pass will be complete. Keep the file
under its 20,000-character soft budget; if the addition pushes past it, trim
completed-pass narrative from `## Current work` instead.

- [ ] **Step 5: Final full-suite run**

MCP: `filesystem_manage(op="scan")` then `test_run()`
Expected: 65 suites, 953+ tests, zero failures. Record the real numbers in the
commit message rather than copying these.

- [ ] **Step 6: Commit**

```bash
git add Assets/Fonts/README.md docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -m "docs(theme): record the Catfiles/Open Sans typography split"
```

---

## Rollback

Every step is reversible from git. To revert the *look* without unwinding the
commits, re-run Task 3's transient suite with both slots set back to
`res://Assets/Fonts/Milker.otf`; Task 2's classification fix is correct
independently of which faces are loaded and should be kept.

## Open questions for the user

None are blocking — each has a decided default above, and each flip is one line.

1. **Buttons in Catfiles.** 46 buttons currently take the display face and this plan
   preserves that. If Catfiles is heavier than Milker, the lobby may read as shouty.
2. **`BarLabel` stays body.** 130 uses, the biggest single visual lever in the plan.
3. **Open Sans *Medium* specifically.** As asked. `Regular` is the more conventional
   body weight; Medium will read slightly heavier at 22px captions.

Task 5's screenshots are the place to settle all three.
