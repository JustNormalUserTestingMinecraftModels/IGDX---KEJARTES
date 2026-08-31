# Viewport-Editable Visuals & Script Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every sprite, layout and UI element in the game selectable and editable from the Godot 2D viewport or the Inspector, and give every script a header and per-export documentation that says what it does and what it affects.

**Architecture:** Three legal authoring patterns replace runtime UI construction — static chrome as nodes in the `.tscn` (Pattern A), repeated items as `PackedScene` templates (Pattern B), and responsive geometry as `@tool` + `@export` knobs that preview live in the editor (Pattern C). Two new source-scanning test suites act as a one-way ratchet: they freeze the current per-file violation counts and fail if any file grows, so the conversion can land screen by screen without the rule ever being aspirational. Conversion tasks are ordered by payoff — the shared popups first (they delete ~680 duplicated lines while becoming editable), then the minigame art, then the shop, then the school-sim screens, then the documentation sweep.

**Tech Stack:** Godot 4.6, GDScript, `mobile` renderer, portrait 1080×1920 with `stretch/aspect="expand"`. Tests are `McpTestSuite` suites under `tests/`, run inside the editor via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-08-31-viewport-editable-ui-and-script-docs-design.md`

## Global Constraints

These apply to every task and are not repeated per task.

- **Never add a `theme_override_*`, and never call `add_theme_*` from code.**
  Use a `ThemeFactory` type variation instead. If none fits, add a new
  variation in `Scripts/Design/ThemeFactory.gd` and rebake by running
  `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X), which writes
  `Assets/Theme/kejartes_theme.tres`. The only accepted exception is
  layout-only constant overrides (`separation`, `margin_*`). Existing
  variations: `PrimaryButton`, `SecondaryButton`, `DangerButton`,
  `SuccessButton`, `LobbyNavButton`, `QuirkBadge`, `PersonaBadge`, `Card`,
  `SunkenPanel`, `Scrim`, `DisplayLabel`, `H1Label`, `H2Label`, `TitleLabel`,
  `CaptionLabel`, `MicroLabel`, `BarLabel`, `CardSectionLabel`, `BioLabel`,
  `BioValue`, `StatBar`, `StatPill`, `TraitPill`, `PreviewRow`, `PreviewPill`,
  `PreviewPillFlat`, `PreviewChipLabel`, `PreviewRowLabel`, `ResultHeroLabel`,
  `ResultBodyLabel`, `DaySummaryName`, `DaySummaryStat`,
  `DaySummaryAvatarFrame`, `DaySummaryEnergyBar`, `DaySummaryMoodBar`,
  `DaySummaryStatTrackAkademis`, `DaySummaryStatTrackSeniBudaya`,
  `DaySummaryStatTrackOlahraga`.
- **All colours, radii, spacing and font sizes come from
  `Assets/Theme/design_tokens.tres`** via `DesignTokens.load_default()`.
- **Test suites must be `@tool`** or the runner reports the class
  abstract/broken.
- **No test may be a coroutine.** The runner does `suite.call(name)` without
  awaiting; an `await` silently aborts the test mid-way and it reports "0
  assertions".
- **Scripts the runner instantiates live must be `@tool` too**, with real
  side effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
  Pure signal wiring and static UI construction stay ungated so tests can
  exercise them. See the header of `Scripts/CutScene/cut_scene.gd` for the
  established explanation.
- **Rescan the filesystem after editing any `.gd`, before running tests** —
  `filesystem_manage(op="scan")` via the Godot AI MCP. `test_run` serves a
  stale autoload otherwise, and you will debug a phantom.
- **Comments and doc blocks are English. Game-facing identifiers and all UI
  strings are Indonesian.** Match the surrounding file.
- **Do not rename `loby.gd` or `koprasi.gd`.** The misspellings are
  load-bearing.
- **Behaviour-preserving.** No task here may change what the player sees, only
  where it is authored. If a conversion would change pixels, stop and report
  rather than "improving" it in passing.
- **Commit after every task** using Conventional Commits with a scope, e.g.
  `refactor(report-card): extract stat popup to an editable scene`.

## File Structure

**New files**

| Path | Responsibility |
|---|---|
| `tests/test_viewport_editability.gd` | Ratchet: per-file count of runtime visual-node construction may only fall. |
| `tests/test_script_documentation.gd` | Ratchet: file-header doc blocks and per-`@export` doc lines may only improve. |
| `docs/superpowers/design/authoring-guide.md` | The three patterns and the documentation standard, as a human-readable reference. |
| `Scripts/UI/StatInfo.gd` | Single source of truth for the five stat bars: display name, category label, description, glyph, DesignTokens key. |
| `Scenes/UI/StatDetailPopup.tscn` + `Scripts/UI/StatDetailPopup.gd` | The stat-detail modal, authored as a scene. Replaces two identical 168-line code builders. |
| `Scenes/UI/TraitDetailPopup.tscn` + `Scripts/UI/TraitDetailPopup.gd` | The quirk/persona-detail modal, authored as a scene. Replaces two more code builders. |
| `Scenes/Inventory/InventorySlot.tscn` + `Scripts/Inventory/InventorySlot.gd` | One inventory grid slot, authored once. |
| `Scenes/Koperasi/RakBarangPopup.tscn` + `Scripts/Koperasi/RakBarangPopup.gd` | The shelf item-detail popup and its blur layer. |
| `Scenes/UI/TutorialPanel.tscn` + `Scripts/UI/TutorialPanel.gd` | The onboarding coach-mark panel used by StudentCard. |
| `Scenes/Minigames/UI/MinigameHUD.tscn` | The score/timer chrome `BaseMinigame` currently builds in code. |

**Modified files**

| Path | Change |
|---|---|
| `Scenes/Minigames/Olahraga/MainBola.tscn` | Gains real positions, sizes and art for every node. |
| `Scripts/Minigames/Olahraga/MainBola.gd` | `@tool`; `load()` paths become `@export` textures; `_setup_layout()` magic fractions become `@export` knobs with live editor preview. |
| `Scenes/Minigames/Olahraga/Badminton.tscn` | Placeholder `ColorRect`s become `Sprite2D`s fed by the existing `@export` textures. |
| `Scripts/Minigames/Olahraga/Badminton.gd` | Drops runtime `Sprite2D` creation; binds to the scene's sprites. |
| `Scripts/ReportCard/report_card.gd` | −~340 lines: both popup builders replaced by scene instantiation. |
| `Scripts/StudentCard/student_card.gd` | −~380 lines: both popup builders and the tutorial panel replaced by scenes. |
| `Scripts/Inventory/inventory.gd` | Slot construction replaced by `InventorySlot.tscn`. |
| `Scenes/Koperasi/koprasi.tscn` / `Scripts/Koperasi/koprasi.gd` | Coin HUD and message label move into the scene. |
| `Scripts/Koperasi/rakbarang_1.gd` | Popup and blur layer move into scenes. |
| `Scripts/Minigames/UI/BaseMinigame.gd` | HUD construction replaced by `MinigameHUD.tscn`. |
| `Scripts/SchoolSimulation/SchoolDay.gd`, `DailyDecayOverview.gd`, `EventStudentSelectDialog.gd` | Runtime chrome moved into their scenes. |
| `CLAUDE.md` | Gains a short "Authoring rules" pointer to the new guide. |
| Every remaining `Scripts/**/*.gd` | File header doc block; `##` line above every `@export`. |

---

## Phase 0 — Guardrails

Nothing converts safely without a ratchet. These three tasks build it.

---

### Task 1: Viewport-editability ratchet suite

**Files:**
- Create: `tests/test_viewport_editability.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `tests/test_viewport_editability.gd` exposing
  `const BASELINE: Dictionary` mapping `res://`-absolute script paths to an
  integer count of runtime visual constructions. Every later conversion task
  lowers entries in this dictionary.

- [ ] **Step 1: Write the failing test**

Create `tests/test_viewport_editability.gd`:

```gdscript
@tool
extends McpTestSuite

## Ratchet on runtime UI construction.
##
## The project's quality-of-life rule is that a human must be able to open a
## .tscn, see every sprite/panel/label, select it and change it. Anything a
## script builds with `SomeControl.new()` at runtime is invisible in the
## editor: it cannot be selected, moved, re-themed or previewed.
##
## This suite does not forbid runtime construction outright -- roughly 340
## call sites predate the rule. It freezes the count per file and fails if
## any file grows. When a conversion legitimately lowers a file's count the
## second test fails and prints the exact literal to paste into BASELINE.
## That is the ratchet: it only turns one way.
##
## Affects nothing at runtime. This is a source-text scan in the same style
## as tests/test_project_hygiene.gd -- it instantiates nothing, needs no
## scene open, and costs a few milliseconds.
##
## Must be @tool or the runner reports the class abstract/broken, and no test
## here may be a coroutine -- the runner calls suite.call(name) without
## awaiting.

func suite_name() -> String:
	return "viewport_editability"


## Node types whose runtime construction hides a visual from the 2D viewport.
## Resource types (StyleBoxFlat, ShaderMaterial) are deliberately absent --
## they are covered by the theme rule in CLAUDE.md, not by this one.
const VISUAL_TYPES: Array[String] = [
	"Control", "Panel", "PanelContainer", "MarginContainer", "CenterContainer",
	"VBoxContainer", "HBoxContainer", "GridContainer", "ScrollContainer",
	"AspectRatioContainer", "HSeparator", "VSeparator", "HFlowContainer",
	"Label", "RichTextLabel", "Button", "TextureButton", "CheckBox",
	"TextureRect", "ColorRect", "NinePatchRect",
	"ProgressBar", "TextureProgressBar", "StatBar",
	"Sprite2D", "AnimatedSprite2D", "Line2D", "Polygon2D",
	"CPUParticles2D", "GPUParticles2D", "CanvasLayer",
]

## Files this rule deliberately does not cover. DebugManager is a
## programmatic developer overlay, already out of scope for the design system
## per CLAUDE.md.
const EXEMPT: Array[String] = [
	"res://Scripts/Debug/DebugManager.gd",
]

## Per-file count of runtime visual construction, frozen 2026-08-31.
## Lower these as conversions land. Never raise one.
const BASELINE: Dictionary = {}


## True when `c` could be part of a GDScript identifier.
func _is_ident_char(c: String) -> bool:
	if c == "_":
		return true
	if c >= "0" and c <= "9":
		return true
	var lower := c.to_lower()
	return lower >= "a" and lower <= "z"


## Count non-overlapping occurrences of `needle` in `hay` that are not
## preceded by an identifier character. Without that guard "Label.new("
## would also match inside "MyCustomLabel.new(".
func _occurrences(hay: String, needle: String) -> int:
	var n := 0
	var from := 0
	while true:
		var at := hay.find(needle, from)
		if at == -1:
			return n
		if at == 0 or not _is_ident_char(hay[at - 1]):
			n += 1
		from = at + needle.length()
	return n


## How many visual nodes this source text builds at runtime. Whole-line
## comments are skipped, so documenting a call site does not count as making
## one.
func _count_runtime_visuals(src: String) -> int:
	var total := 0
	for raw in src.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		for type_name in VISUAL_TYPES:
			total += _occurrences(line, type_name + ".new(")
	return total


## Every res:// path under `root` ending in `suffix`.
func _all_files_under(root: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(suffix):
				out.append(dir.path_join(f))
	return out


## { script_path: count } for every non-exempt script that builds at least
## one visual node at runtime.
func _scan() -> Dictionary:
	var out := {}
	for path in _all_files_under("res://Scripts", ".gd"):
		if EXEMPT.has(path):
			continue
		var n := _count_runtime_visuals(FileAccess.get_file_as_string(path))
		if n > 0:
			out[path] = n
	return out


## Render a scan result as a pasteable GDScript dictionary literal, so a
## failing run tells you exactly what to write.
func _as_literal(scan: Dictionary) -> String:
	var keys: Array = scan.keys()
	keys.sort()
	var lines: Array[String] = ["const BASELINE: Dictionary = {"]
	for k in keys:
		lines.append("\t\"%s\": %d," % [k, scan[k]])
	lines.append("}")
	return "\n".join(lines)


func test_no_script_builds_more_ui_at_runtime_than_its_baseline() -> void:
	var current := _scan()
	var grown: Array[String] = []
	for path in current:
		var allowed: int = int(BASELINE.get(path, 0))
		if int(current[path]) > allowed:
			grown.append("  %s: baseline %d, now %d" % [path, allowed, current[path]])
	grown.sort()
	assert_true(grown.is_empty(),
		("These scripts build more visual nodes at runtime than the baseline "
		+ "allows. Author them in a .tscn instead -- see "
		+ "docs/superpowers/design/authoring-guide.md.\n"
		+ "\n".join(grown)))


func test_baseline_is_not_stale() -> void:
	var current := _scan()
	var shrunk: Array[String] = []
	for path in BASELINE:
		var now: int = int(current.get(path, 0))
		if now < int(BASELINE[path]):
			shrunk.append("  %s: baseline %d, now %d" % [path, BASELINE[path], now])
	shrunk.sort()
	assert_true(shrunk.is_empty(),
		("The ratchet turned -- lower these in BASELINE in the same commit, or "
		+ "the improvement can silently regress later.\n"
		+ "\n".join(shrunk)
		+ "\n\nCurrent scan, paste over BASELINE:\n"
		+ _as_literal(current)))
```

- [ ] **Step 2: Run the suite to verify it fails**

Rescan first — `test_run` serves stale scripts otherwise:

```
filesystem_manage(op="scan")
test_run(suite="viewport_editability")
```

Expected: `test_no_script_builds_more_ui_at_runtime_than_its_baseline` FAILS,
listing ~29 scripts. `BASELINE` is empty, so every file is over its implied
zero.

- [ ] **Step 3: Generate the baseline from the scanner**

Do not hand-type the numbers. Temporarily replace the body of
`test_baseline_is_not_stale` with:

```gdscript
	assert_true(false, _as_literal(_scan()))
```

Rescan, run the suite, copy the printed dictionary literal over
`const BASELINE: Dictionary = {}`, then restore the real body from Step 1.

- [ ] **Step 4: Run the suite to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="viewport_editability")
```

Expected: both tests PASS.

- [ ] **Step 5: Prove the ratchet bites in both directions**

Add a throwaway `var _probe := Label.new()` to `Scripts/UI/StatBar.gd`,
rescan, run. Expected: the first test FAILS naming `StatBar.gd`. Remove the
line. Then lower one `BASELINE` entry by 1, rescan, run. Expected: the second
test FAILS and prints a pasteable literal. Restore the entry. Rescan and run:
both PASS.

- [ ] **Step 6: Run the whole suite for regressions**

```
test_run()
```

Expected: all suites green — the 425 existing tests plus the 2 new ones.

- [ ] **Step 7: Commit**

```bash
git add tests/test_viewport_editability.gd && git commit -m "test(hygiene): ratchet runtime UI construction per script"
```

---

### Task 2: Script-documentation ratchet suite

**Files:**
- Create: `tests/test_script_documentation.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `tests/test_script_documentation.gd` exposing
  `const PENDING_HEADERS: Array[String]` (scripts still lacking a file-header
  doc block) and `const PENDING_EXPORT_DOCS: Dictionary` (script path →
  count of `@export` declarations with no `##` line above them). Phase 5's
  tasks empty both.

- [ ] **Step 1: Write the failing test**

Create `tests/test_script_documentation.gd`:

```gdscript
@tool
extends McpTestSuite

## Ratchet on script documentation.
##
## Two mechanically checkable halves of the documentation standard in
## docs/superpowers/design/authoring-guide.md:
##
##   1. Every script opens with a `##` block saying what it is and what it
##      affects.
##   2. Every `@export` carries a `##` line immediately above it. Godot
##      surfaces that text as the Inspector tooltip, so this rule is the one
##      that pays out directly in the editor.
##
## Rules 3 and 4 of the standard -- per-function doc lines and section
## banners -- are review-time conventions, not tested here. A regex cannot
## tell a useful sentence from a restated function name, and a test that
## `## does the thing` would satisfy buys compliance instead of documentation.
##
## Both lists below shrink and never grow. A path that has been fixed but
## left in PENDING_HEADERS fails just as loudly as a new violation.
##
## Affects nothing at runtime -- source-text scan only, no scene needed.
## Must be @tool, and no test here may be a coroutine.

func suite_name() -> String:
	return "script_documentation"


## Scripts still lacking a file-header doc block, frozen 2026-08-31.
## Remove entries as they are documented. Never add one.
const PENDING_HEADERS: Array[String] = []

## script_path -> number of undocumented @export declarations, frozen
## 2026-08-31. Lower these as they are documented. Never raise one.
const PENDING_EXPORT_DOCS: Dictionary = {}

## Same exemption as the editability ratchet: a programmatic developer
## overlay, out of scope for the design system per CLAUDE.md.
const EXEMPT: Array[String] = [
	"res://Scripts/Debug/DebugManager.gd",
]

## How far into a file the header block may start. Leaves room for `@tool`,
## `class_name`, `extends` and a blank line.
const HEADER_SEARCH_LINES: int = 12


## Every res:// path under `root` ending in `suffix`.
func _all_files_under(root: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(suffix):
				out.append(dir.path_join(f))
	return out


## Every non-exempt gameplay script, sorted for stable failure messages.
func _all_scripts() -> Array[String]:
	var out: Array[String] = []
	for p in _all_files_under("res://Scripts", ".gd"):
		if not EXEMPT.has(p):
			out.append(p)
	out.sort()
	return out


## True when the first HEADER_SEARCH_LINES lines contain a `##` doc line.
func _has_file_header(src: String) -> bool:
	var lines := src.split("\n")
	var limit: int = mini(HEADER_SEARCH_LINES, lines.size())
	for i in range(limit):
		if lines[i].strip_edges().begins_with("##"):
			return true
	return false


## Count `@export` declarations with no `##` line directly above them.
## An `@export_group`/`@export_subgroup`/`@export_category` banner is not a
## declaration and is skipped; a blank line or a plain `#` comment between the
## doc and the export breaks the association, which matches how Godot itself
## attaches Inspector tooltips.
func _undocumented_exports(src: String) -> int:
	var lines := src.split("\n")
	var n := 0
	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if not line.begins_with("@export"):
			continue
		if line.begins_with("@export_group") \
			or line.begins_with("@export_subgroup") \
			or line.begins_with("@export_category"):
			continue
		var documented := false
		var j := i - 1
		# Walk back over a multi-line `##` block; stop at anything else.
		while j >= 0 and lines[j].strip_edges().begins_with("##"):
			documented = true
			j -= 1
		if not documented:
			n += 1
	return n


## script_path -> undocumented-export count, for files with at least one.
func _scan_exports() -> Dictionary:
	var out := {}
	for path in _all_scripts():
		var n := _undocumented_exports(FileAccess.get_file_as_string(path))
		if n > 0:
			out[path] = n
	return out


## Scripts with no file-header doc block.
func _scan_headers() -> Array[String]:
	var out: Array[String] = []
	for path in _all_scripts():
		if not _has_file_header(FileAccess.get_file_as_string(path)):
			out.append(path)
	return out


## Render an Array[String] as a pasteable GDScript literal.
func _as_array_literal(name: String, items: Array[String]) -> String:
	var lines: Array[String] = ["const %s: Array[String] = [" % name]
	for s in items:
		lines.append("\t\"%s\"," % s)
	lines.append("]")
	return "\n".join(lines)


## Render a Dictionary as a pasteable GDScript literal.
func _as_dict_literal(name: String, d: Dictionary) -> String:
	var keys: Array = d.keys()
	keys.sort()
	var lines: Array[String] = ["const %s: Dictionary = {" % name]
	for k in keys:
		lines.append("\t\"%s\": %d," % [k, d[k]])
	lines.append("}")
	return "\n".join(lines)


func test_every_script_has_a_file_header_doc_block() -> void:
	var missing := _scan_headers()
	var unexpected: Array[String] = []
	for path in missing:
		if not PENDING_HEADERS.has(path):
			unexpected.append("  " + path)
	assert_true(unexpected.is_empty(),
		("These scripts have no `##` header block in their first %d lines. "
		% HEADER_SEARCH_LINES)
		+ "Say what the file is, who drives it, and what it affects.\n"
		+ "\n".join(unexpected))


func test_pending_header_list_is_not_stale() -> void:
	var missing := _scan_headers()
	var fixed: Array[String] = []
	for path in PENDING_HEADERS:
		if not missing.has(path):
			fixed.append("  " + path)
	assert_true(fixed.is_empty(),
		"These scripts are documented now -- drop them from PENDING_HEADERS "
		+ "in the same commit.\n"
		+ "\n".join(fixed)
		+ "\n\nCurrent scan, paste over PENDING_HEADERS:\n"
		+ _as_array_literal("PENDING_HEADERS", missing))


func test_no_script_gains_undocumented_exports() -> void:
	var current := _scan_exports()
	var grown: Array[String] = []
	for path in current:
		var allowed: int = int(PENDING_EXPORT_DOCS.get(path, 0))
		if int(current[path]) > allowed:
			grown.append("  %s: allowed %d, now %d" % [path, allowed, current[path]])
	grown.sort()
	assert_true(grown.is_empty(),
		"Every @export needs a `##` line above it -- Godot shows it as the "
		+ "Inspector tooltip.\n"
		+ "\n".join(grown))


func test_pending_export_doc_counts_are_not_stale() -> void:
	var current := _scan_exports()
	var shrunk: Array[String] = []
	for path in PENDING_EXPORT_DOCS:
		var now: int = int(current.get(path, 0))
		if now < int(PENDING_EXPORT_DOCS[path]):
			shrunk.append("  %s: allowed %d, now %d" % [path, PENDING_EXPORT_DOCS[path], now])
	shrunk.sort()
	assert_true(shrunk.is_empty(),
		"The ratchet turned -- lower these in PENDING_EXPORT_DOCS in the same "
		+ "commit.\n"
		+ "\n".join(shrunk)
		+ "\n\nCurrent scan, paste over PENDING_EXPORT_DOCS:\n"
		+ _as_dict_literal("PENDING_EXPORT_DOCS", current))
```

- [ ] **Step 2: Run the suite to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
```

Expected: `test_every_script_has_a_file_header_doc_block` FAILS listing ~22
scripts, and `test_no_script_gains_undocumented_exports` FAILS listing the
files whose exports lack `##` lines. Both `PENDING_*` lists are empty.

- [ ] **Step 3: Generate both baselines from the scanner**

Temporarily replace the two "not stale" test bodies with:

```gdscript
	assert_true(false, _as_array_literal("PENDING_HEADERS", _scan_headers()))
```

and

```gdscript
	assert_true(false, _as_dict_literal("PENDING_EXPORT_DOCS", _scan_exports()))
```

Rescan, run, paste both printed literals over the empty constants, then
restore the real bodies from Step 1.

- [ ] **Step 4: Run the suite to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
```

Expected: all four tests PASS.

- [ ] **Step 5: Prove the ratchet bites**

Add `@export var _probe: int = 0` with no `##` above it to
`Scripts/UI/StatBar.gd`, rescan, run. Expected:
`test_no_script_gains_undocumented_exports` FAILS naming `StatBar.gd`. Remove
it. Then add a `##` line above one currently-undocumented export somewhere in
`PENDING_EXPORT_DOCS`, rescan, run. Expected:
`test_pending_export_doc_counts_are_not_stale` FAILS with a pasteable
literal. Revert. Rescan and run: all four PASS.

- [ ] **Step 6: Run the whole suite for regressions**

```
test_run()
```

Expected: all suites green.

- [ ] **Step 7: Commit**

```bash
git add tests/test_script_documentation.gd && git commit -m "test(hygiene): ratchet script header and export documentation"
```

---

### Task 3: The authoring guide

**Files:**
- Create: `docs/superpowers/design/authoring-guide.md`
- Modify: `CLAUDE.md` (add a pointer under the visual-system section)

**Interfaces:**
- Consumes: the two suites from Tasks 1 and 2 — the guide names them as the
  enforcement mechanism.
- Produces: a doc path that every later task's failure messages point at.

- [ ] **Step 1: Write the guide**

Create `docs/superpowers/design/authoring-guide.md` with these sections, in
this order. Write real prose, not headings with TODOs.

1. **Why** — one paragraph: a human must be able to open a `.tscn`, see the
   thing, select it, change it, and have the change survive. Quote the
   measured baseline from the spec (~340 runtime construction sites, 22
   undocumented scripts).
2. **Pattern A — static chrome lives in the scene.** Anything that always
   exists is a node in the `.tscn`, reached with `@onready`. Show the
   before/after: `var lbl := Label.new(); lbl.text = "…"; add_child(lbl)`
   versus a `ScoreLabel` node in the scene plus
   `@onready var score_label: Label = $HUDLayer/ScoreLabel`. Name
   `Scenes/Minigames/Olahraga/MainBola.tscn`'s `HUDLayer` as the in-tree
   example of the good form.
3. **Pattern B — repeated items are a `PackedScene` template.** Author the
   row once, instantiate at runtime, hold the template in
   `@export var row_scene: PackedScene = preload(…)` so even the choice is
   swappable. Point at the four templates already in the tree:
   `Scenes/AturJadwal/ActivityRow.tscn`,
   `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`,
   `Scenes/EndGame/ResultStatRow.tscn`, `Scenes/StudentList/StickyNote.tscn`.
4. **Pattern C — responsive geometry is `@tool` + `@export` knobs.** Explain
   that `project.godot` sets `stretch/aspect="expand"`, so viewport height
   really does vary and some layout must be computed. The rule is that every
   magic number becomes a documented `@export`, and the script is `@tool` and
   re-runs its layout pass in the editor so the viewport shows the truth.
   Give the canonical shape:

```gdscript
@tool
extends Control

## Goal mouth width, as a fraction of viewport width.
@export_range(0.1, 1.0, 0.01) var goal_width_frac: float = 0.88:
	set(value):
		goal_width_frac = value
		if is_inside_tree():
			_setup_layout()
```

5. **Art references.** `@export var … : Texture2D` so the FileSystem dock can
   drag onto it. Never `load("res://…")` for art inside a function. Point at
   `Scripts/Minigames/Olahraga/Badminton.gd`'s
   `@export_group("Visual - Rackets")` block as the model already in the tree.
6. **What is exempt.** `Scripts/Debug/DebugManager.gd`, `addons/**`,
   `-REFERENCE-/prototype/**`.
7. **The documentation standard.** The four rules from the spec, with a
   worked example header taken from a real file.
8. **How this is enforced.** `tests/test_viewport_editability.gd` and
   `tests/test_script_documentation.gd`, both ratchets; how to read their
   failure output and paste the regenerated literal.

- [ ] **Step 2: Add the pointer to CLAUDE.md**

In the "Visual system — read this before touching any UI" section, directly
after the line reading
`Full detail: `docs/superpowers/design/style-guide.md`.`, add:

```markdown
**The second rule: no visual is built at runtime.** Static chrome is a node in
the `.tscn`; repeated rows are a `PackedScene` template; responsive geometry
is a `@tool` script driven by documented `@export` knobs. Two ratchet suites
(`tests/test_viewport_editability.gd`, `tests/test_script_documentation.gd`)
freeze the current violation counts and fail if any file grows.

Full detail: `docs/superpowers/design/authoring-guide.md`.
```

- [ ] **Step 3: Verify the guide's claims against the tree**

Every path the guide names must exist. Run:

```bash
for p in Scenes/AturJadwal/ActivityRow.tscn Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scenes/EndGame/ResultStatRow.tscn Scenes/StudentList/StickyNote.tscn Scripts/Minigames/Olahraga/Badminton.gd Scripts/Debug/DebugManager.gd docs/superpowers/design/style-guide.md; do test -e "$p" || echo "MISSING: $p"; done
```

Expected: no output.

- [ ] **Step 4: Run the whole suite**

```
test_run()
```

Expected: all suites green. (Documentation changes cannot break tests; this
confirms the CLAUDE.md edit did not corrupt anything the suites read.)

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/design/authoring-guide.md CLAUDE.md && git commit -m "docs(design): add the viewport-editable authoring guide"
```

---
## Phase 1 — The shared popups

The single largest win in the codebase. `report_card.gd:287-455` and
`student_card.gd:1057-1230` are the same 168 lines with only whitespace
differing; the trait popups (`report_card.gd:457-587`,
`student_card.gd:1226-1355`) are a second such pair. Extracting both into
scenes deletes roughly 680 duplicated lines *and* makes four modals editable.

---

### Task 4: `StatInfo` — one table for the five stat bars

Both screens hardcode the same if/elif chain mapping a bar name to a display
name, a description, a glyph, a needs-vs-stats label and a DesignTokens
category. That table has to exist once before the popup scene can be
data-driven.

**Files:**
- Create: `Scripts/UI/StatInfo.gd`
- Test: `tests/test_stat_info.gd`

**Interfaces:**
- Consumes: `Scripts/Design/DesignTokens.gd` (`category_color`).
- Produces:
  - `class_name StatInfo`
  - `const BARS: Dictionary` — bar name → `{display_name, category_label,
    glyph, token_category, data_key, description}`
  - `static func get_bar(bar_name: String) -> Dictionary` — empty dict for an
    unknown name.
  - `static func token_category(bar_name: String) -> String` — `""` for an
    unknown name.
  - `static func value_of(bar_name: String, s_data: Dictionary) -> float`

- [ ] **Step 1: Write the failing test**

Create `tests/test_stat_info.gd`:

```gdscript
@tool
extends McpTestSuite

## StatInfo is the one table describing the five bars a student card shows.
## Before it existed, report_card.gd and student_card.gd each carried their
## own copy of the same if/elif chain, and the two had already drifted in
## whitespace. These tests pin the contract the popup scene reads.
##
## Affects nothing at runtime -- pure data assertions, no scene instantiated.
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "stat_info"


## The five bars a student card shows, in card order.
const EXPECTED_BARS: Array[String] = [
	"Kepribadian1", "Kepribadian2", "Akademis1", "Akademis2", "Akademis3",
]


func test_table_covers_exactly_the_five_card_bars() -> void:
	var keys: Array = StatInfo.BARS.keys()
	keys.sort()
	var expected: Array = EXPECTED_BARS.duplicate()
	expected.sort()
	assert_eq(keys, expected, "StatInfo.BARS must describe exactly the five bars")


func test_every_bar_carries_every_field() -> void:
	var required: Array[String] = [
		"display_name", "category_label", "glyph",
		"token_category", "data_key", "description",
	]
	for bar_name in StatInfo.BARS:
		var entry: Dictionary = StatInfo.BARS[bar_name]
		for field in required:
			assert_has_key(entry, field, "%s is missing %s" % [bar_name, field])
			assert_ne(entry[field], "", "%s.%s must not be empty" % [bar_name, field])


func test_needs_and_skills_are_labelled_apart() -> void:
	# Mood and Energy are needs; the three skills are stats. The popup header
	# prints this word, so a mix-up is visible to the player.
	assert_eq(StatInfo.BARS["Kepribadian1"]["category_label"], "NEEDS")
	assert_eq(StatInfo.BARS["Kepribadian2"]["category_label"], "NEEDS")
	assert_eq(StatInfo.BARS["Akademis1"]["category_label"], "STATS")
	assert_eq(StatInfo.BARS["Akademis2"]["category_label"], "STATS")
	assert_eq(StatInfo.BARS["Akademis3"]["category_label"], "STATS")


func test_token_categories_match_the_shipped_bar_colours() -> void:
	# Mood and Energy are not schedule categories, so they borrow the two
	# accents no skill uses: Istirahat (violet) for Mood, Libur (amber) for
	# Energy. This is the mapping report_card.gd::BAR_CATEGORY shipped with.
	assert_eq(StatInfo.token_category("Kepribadian1"), "Istirahat")
	assert_eq(StatInfo.token_category("Kepribadian2"), "Libur")
	assert_eq(StatInfo.token_category("Akademis1"), "Akademis")
	assert_eq(StatInfo.token_category("Akademis2"), "SeniBudaya")
	assert_eq(StatInfo.token_category("Akademis3"), "Olahraga")


func test_unknown_bar_degrades_instead_of_crashing() -> void:
	# Callers pass a bar name straight from a node name; a typo must not take
	# the screen down.
	assert_eq(StatInfo.get_bar("Nonsense"), {})
	assert_eq(StatInfo.token_category("Nonsense"), "")
	assert_eq(StatInfo.value_of("Nonsense", {}), 0.0)


func test_value_of_reads_the_gamestate_key_not_the_bar_name() -> void:
	# The bar is named "Akademis2" but the GameState dictionary key is
	# "akademis2" and it means seni_budaya. This mismatch is the single most
	# common source of bugs in this project -- pin it.
	var s_data := {
		"kepribadian1": 61.0, "kepribadian2": 42.0,
		"akademis1": 10.0, "akademis2": 20.0, "akademis3": 30.0,
	}
	assert_eq(StatInfo.value_of("Kepribadian1", s_data), 61.0)
	assert_eq(StatInfo.value_of("Kepribadian2", s_data), 42.0)
	assert_eq(StatInfo.value_of("Akademis2", s_data), 20.0)


func test_descriptions_are_indonesian_player_facing_copy() -> void:
	# UI text in this project is Indonesian. A description that slipped into
	# English would ship straight to the player.
	for bar_name in StatInfo.BARS:
		var desc: String = StatInfo.BARS[bar_name]["description"]
		assert_gt(desc.length(), 40, "%s description is too short to be real copy" % bar_name)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="stat_info")
```

Expected: FAIL — `StatInfo` is not a known identifier.

- [ ] **Step 3: Write the implementation**

Create `Scripts/UI/StatInfo.gd`. The five descriptions and glyphs are copied
verbatim from `Scripts/ReportCard/report_card.gd:335-364` — this is a move,
not a rewrite, and the strings must not change.

```gdscript
@tool
class_name StatInfo
extends RefCounted

## The one table describing the five bars a student card shows.
##
## Read by Scenes/UI/StatDetailPopup.tscn to fill its header, its bar tint and
## its description, and by report_card.gd / student_card.gd to colour the bars
## on the card itself. Before this existed both screens carried their own copy
## of the same if/elif chain.
##
## Affects: presentation only. Nothing here writes GameState.
##
## Naming trap, and the reason `data_key` exists: the bar node is called
## "Akademis2" but the GameState dictionary key is "akademis2" and it holds
## seni_budaya. Never index a student dictionary with a bar name.

## bar name -> everything the UI needs to render that bar.
##
## `token_category` is a DesignTokens category key, not a schedule category.
## Mood and Energy are needs rather than skills, so they borrow the two
## accents no skill uses -- Istirahat (violet) for Mood, Libur (amber) for
## Energy -- which keeps all five bars mutually distinguishable while every
## colour still comes from one token set.
const BARS: Dictionary = {
	"Kepribadian1": {
		"display_name": "Mood",
		"category_label": "NEEDS",
		"glyph": "😊",
		"token_category": "Istirahat",
		"data_key": "kepribadian1",
		"description": "Mood mempengaruhi tingkat kemauan murid belajar. Jika mood rendah, murid akan stress dan performanya menurun!",
	},
	"Kepribadian2": {
		"display_name": "Energy",
		"category_label": "NEEDS",
		"glyph": "⚡",
		"token_category": "Libur",
		"data_key": "kepribadian2",
		"description": "Energy digunakan untuk melakukan aktivitas. Pastikan energy cukup sebelum memberikan tugas berat!",
	},
	"Akademis1": {
		"display_name": "Akademis",
		"category_label": "STATS",
		"glyph": "📚",
		"token_category": "Akademis",
		"data_key": "akademis1",
		"description": "Menunjukkan tingkat kemampuan murid dalam memahami pelajaran akademis dan teoritis.",
	},
	"Akademis2": {
		"display_name": "Seni Budaya",
		"category_label": "STATS",
		"glyph": "🎨",
		"token_category": "SeniBudaya",
		"data_key": "akademis2",
		"description": "Menunjukkan tingkat kemampuan murid dalam menciptakan dan memahami karya kesenian.",
	},
	"Akademis3": {
		"display_name": "Olahraga",
		"category_label": "STATS",
		"glyph": "⚽",
		"token_category": "Olahraga",
		"data_key": "akademis3",
		"description": "Menunjukkan tingkat kemampuan fisik dan kebugaran tubuh murid dalam bidang olahraga.",
	},
}


## Everything known about one bar, or {} when the name is not one of the five.
## Callers pass a node name straight through, so an unknown name must degrade
## rather than crash the screen.
static func get_bar(bar_name: String) -> Dictionary:
	return BARS.get(bar_name, {})


## The DesignTokens category key for a bar, or "" when unknown.
## Affects: the bar's tint via DesignTokens.category_color().
static func token_category(bar_name: String) -> String:
	var entry: Dictionary = BARS.get(bar_name, {})
	return entry.get("token_category", "")


## Read this bar's current value out of a GameState student dictionary.
## Affects: nothing -- read-only. Returns 0.0 for an unknown bar or a student
## dictionary missing the key.
static func value_of(bar_name: String, s_data: Dictionary) -> float:
	var entry: Dictionary = BARS.get(bar_name, {})
	if entry.is_empty():
		return 0.0
	return float(s_data.get(entry["data_key"], 0.0))
```

- [ ] **Step 4: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="stat_info")
```

Expected: 7 tests PASS.

- [ ] **Step 5: Update both ratchet baselines**

`StatInfo.gd` is a new script. It builds no visuals, so it does not enter
`test_viewport_editability.gd`'s `BASELINE`. It has a header and no exports,
so it does not enter either `PENDING_*` list. Confirm rather than assume:

```
test_run()
```

Expected: all suites green, including `viewport_editability` and
`script_documentation`. If either ratchet fails, paste the regenerated
literal it prints.

- [ ] **Step 6: Commit**

```bash
git add Scripts/UI/StatInfo.gd tests/test_stat_info.gd && git commit -m "feat(ui): add StatInfo, the single table for the five card bars"
```

---

### Task 5: `StatDetailPopup.tscn` and rewire ReportCard

**Files:**
- Create: `Scenes/UI/StatDetailPopup.tscn`
- Create: `Scripts/UI/StatDetailPopup.gd`
- Modify: `Scripts/ReportCard/report_card.gd` — replace `_show_bar_popup`
  (lines 287-455) and delete `BAR_CATEGORY` (lines 267-273)
- Test: `tests/test_stat_detail_popup.gd`

**Interfaces:**
- Consumes: `StatInfo.get_bar`, `StatInfo.value_of`, `StatInfo.token_category`
  (Task 4); `StatBar` (`Scripts/UI/StatBar.gd`) with `category`, `max_value`,
  `set_stat(value, animate)`; `DesignTokens.load_default()`;
  `Juice.pop_in(control)`; `AudioDirector.play_sfx(name)`.
- Produces:
  - `class_name StatDetailPopup extends CanvasLayer`
  - `signal closed`
  - `func configure(bar_name: String, s_data: Dictionary, icon: Texture2D) -> void`
  - `func open() -> void` — coroutine; plays the reveal. Callers do not await.
  - `func close() -> void`
  - The scene at `res://Scenes/UI/StatDetailPopup.tscn`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_stat_detail_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## The stat-detail modal, now a scene rather than 168 lines of construction
## duplicated between report_card.gd and student_card.gd.
##
## These tests instantiate the scene (cheap -- it is a dozen nodes) and check
## the node contract the two callers rely on, plus the source-level guarantee
## that neither caller rebuilt its own copy.
##
## Must be @tool; no test here may be a coroutine, so nothing calls open().

func suite_name() -> String:
	return "stat_detail_popup"


const SCENE_PATH := "res://Scenes/UI/StatDetailPopup.tscn"

## A student dictionary shaped like GameState.approved_students entries.
const SAMPLE := {
	"kepribadian1": 61.0, "kepribadian2": 42.0,
	"akademis1": 10.0, "akademis2": 20.0, "akademis3": 30.0,
}


func _make() -> StatDetailPopup:
	var scene: PackedScene = load(SCENE_PATH)
	var popup: StatDetailPopup = scene.instantiate()
	track(popup)
	return popup


func test_scene_exists_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	assert_not_null(_make())


func test_scene_supplies_every_node_the_script_binds() -> void:
	# The whole point of the extraction: these nodes live in the .tscn where a
	# human can select them, not in an _ready() that builds them.
	var popup := _make()
	for path in ["Scrim", "Scrim/Card", "Scrim/Card/Layout/Header",
			"Scrim/Card/Layout/Header/Row/IconRect",
			"Scrim/Card/Layout/Header/Row/Titles/CategoryLabel",
			"Scrim/Card/Layout/Header/Row/Titles/NameLabel",
			"Scrim/Card/Layout/Header/Row/CloseButton",
			"Scrim/Card/Layout/Body/BodyLayout/ValueLabel",
			"Scrim/Card/Layout/Body/BodyLayout/Bar",
			"Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel"]:
		assert_not_null(popup.get_node_or_null(path), "missing node: %s" % path)


func test_configure_fills_the_header_and_body_from_stat_info() -> void:
	var popup := _make()
	popup.configure("Akademis2", SAMPLE, null)
	assert_eq(popup.get_node("Scrim/Card/Layout/Header/Row/Titles/CategoryLabel").text, "STATS")
	assert_eq(popup.get_node("Scrim/Card/Layout/Header/Row/Titles/NameLabel").text, "Seni Budaya")
	assert_contains(
		popup.get_node("Scrim/Card/Layout/Body/BodyLayout/ValueLabel").text, "20")
	assert_contains(
		popup.get_node("Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel").text, "kesenian")


func test_configure_tints_the_bar_with_the_right_category() -> void:
	# Akademis2 is seni_budaya, not academics. Getting this wrong paints the
	# bar the wrong colour and is invisible in a source diff.
	var popup := _make()
	popup.configure("Akademis2", SAMPLE, null)
	var bar: StatBar = popup.get_node("Scrim/Card/Layout/Body/BodyLayout/Bar")
	assert_eq(bar.category, "SeniBudaya")
	assert_eq(bar.value, 20.0)


func test_configure_falls_back_to_the_glyph_when_no_icon_texture() -> void:
	var popup := _make()
	popup.configure("Kepribadian1", SAMPLE, null)
	var icon_rect: TextureRect = popup.get_node("Scrim/Card/Layout/Header/Row/IconRect")
	var glyph: Label = popup.get_node("Scrim/Card/Layout/Header/Row/GlyphLabel")
	assert_false(icon_rect.visible, "icon rect should hide when there is no texture")
	assert_true(glyph.visible, "glyph label should show when there is no texture")
	assert_eq(glyph.text, "😊")


func test_configure_on_an_unknown_bar_does_not_crash() -> void:
	var popup := _make()
	popup.configure("Nonsense", SAMPLE, null)
	assert_eq(popup.get_node("Scrim/Card/Layout/Header/Row/Titles/NameLabel").text, "")


func test_scene_has_no_theme_overrides() -> void:
	# Project rule: styling comes from ThemeFactory variations, never from
	# theme_override_* on a node.
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for line in text.split("\n"):
		if line.begins_with("theme_override_") and not line.begins_with("theme_override_constants/"):
			assert_true(false, "theme override in the scene file: " + line)


func test_report_card_no_longer_builds_the_popup_itself() -> void:
	# Not checked here: "TraitPopupPanel" -- both this popup and the
	# still-unconverted trait popup (Task 7) set `popup.name = "TraitPopupPanel"`
	# in the shipped code, so the string legitimately survives in the file
	# until Task 7 also lands. Task 7's own test checks its removal via
	# artifacts unique to the trait-popup builder instead.
	var src := FileAccess.get_file_as_string("res://Scripts/ReportCard/report_card.gd")
	assert_false(src.contains("StatBar.new("),
		"report_card.gd still builds the stat popup's bar by hand")
	assert_contains(src, "StatDetailPopup",
		"report_card.gd should instantiate the extracted scene")
	assert_false(src.contains("const BAR_CATEGORY"),
		"BAR_CATEGORY moved to StatInfo.token_category()")
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="stat_detail_popup")
```

Expected: every test FAILS — the scene does not exist.

- [ ] **Step 3: Author the scene**

Build `Scenes/UI/StatDetailPopup.tscn` in the editor (or via
`scene_manage`/`node_create`) with exactly this tree. Every value below is
scene data — none of it is set from code:

```
StatDetailPopup            CanvasLayer   layer = 100, script = StatDetailPopup.gd
└─ Scrim                   ColorRect     anchors preset Full Rect,
                                         mouse_filter = Stop,
                                         color = (0,0,0,0)  [faded in at runtime]
   └─ Card                 PanelContainer theme_type_variation = "Card",
                                         anchors preset Center Bottom,
                                         custom_minimum_size = (1015, 0)
      └─ Layout            VBoxContainer  theme_override_constants/separation = 0
         ├─ Header         MarginContainer margin_left/right = 32,
         │                                 margin_top = 32, margin_bottom = 24
         │  └─ Row         HBoxContainer   theme_override_constants/separation = 24
         │     ├─ IconRect TextureRect     custom_minimum_size = (80, 80),
         │     │                           expand_mode = Ignore Size,
         │     │                           stretch_mode = Keep Aspect Centered
         │     ├─ GlyphLabel Label         theme_type_variation = "H1Label",
         │     │                           vertical_alignment = Center
         │     ├─ Titles   VBoxContainer   size_flags_horizontal = Expand Fill
         │     │  ├─ CategoryLabel Label   theme_type_variation = "CaptionLabel"
         │     │  └─ NameLabel     Label   theme_type_variation = "H2Label"
         │     └─ CloseButton      Button  text = "✕",
         │                                 theme_type_variation = "SecondaryButton",
         │                                 custom_minimum_size = (96, 96),
         │                                 size_flags_vertical = Shrink Begin
         └─ Body           PanelContainer  theme_type_variation = "SunkenPanel"
            └─ BodyLayout  VBoxContainer   theme_override_constants/separation = 24
               ├─ ValueLabel       Label   theme_type_variation = "H2Label"
               ├─ Bar              StatBar custom_minimum_size = (0, 58)
               └─ DescriptionLabel Label   theme_type_variation = "TitleLabel",
                                           autowrap_mode = Word (Smart),
                                           theme_override_constants/line_spacing = 12
```

Two notes on the numbers, both preserving current behaviour:

- `Card.custom_minimum_size.x = 1015` is `1080 * 0.94`, the width the old code
  computed from the live viewport. At `stretch/aspect="expand"` the viewport
  *width* stays 1080, so a literal is exact here; only height varies.
- `CloseButton` and `Bar` sizes are `touch_target_min` and
  `touch_target_min * 0.6`. Read the shipped value out of
  `Assets/Theme/design_tokens.tres` and use it; if it is not 96, use the real
  number and adjust the tree above.

`theme_override_constants/*` entries are the layout-only exception the
project's rule permits — separation, margins and line spacing. Do not add any
other override.

- [ ] **Step 4: Write the popup script**

Create `Scripts/UI/StatDetailPopup.gd`:

```gdscript
@tool
class_name StatDetailPopup
extends CanvasLayer

## The stat-detail modal a player gets by tapping a bar on a student card.
##
## Instantiated by Scripts/ReportCard/report_card.gd and
## Scripts/StudentCard/student_card.gd, which previously each carried their
## own verbatim copy of this as 168 lines of runtime construction. Every node
## it draws now lives in Scenes/UI/StatDetailPopup.tscn, so the layout is
## editable in the 2D viewport.
##
## Affects: nothing outside itself. It reads a student dictionary, plays two
## SFX through AudioDirector, and emits `closed` when it finishes its exit
## animation. It never writes GameState.
##
## @tool so the scene previews correctly in the editor. _ready() only caches
## node references and wires signals -- both are safe in an editor session --
## so nothing here needs an Engine.is_editor_hint() guard.

## Emitted after the close animation finishes and this node has been freed
## from the tree. Callers use it to re-show whatever they hid.
signal closed

## How long the scrim takes to fade in behind the card.
@export var scrim_fade_in_seconds: float = 0.22
## How long the card takes to slide off the bottom edge on close.
@export var close_slide_seconds: float = 0.26
## How long the scrim takes to fade back out on close.
@export var scrim_fade_out_seconds: float = 0.22

@onready var scrim: ColorRect = $Scrim
@onready var card: PanelContainer = $Scrim/Card
@onready var icon_rect: TextureRect = $Scrim/Card/Layout/Header/Row/IconRect
@onready var glyph_label: Label = $Scrim/Card/Layout/Header/Row/GlyphLabel
@onready var category_label: Label = $Scrim/Card/Layout/Header/Row/Titles/CategoryLabel
@onready var name_label: Label = $Scrim/Card/Layout/Header/Row/Titles/NameLabel
@onready var close_button: Button = $Scrim/Card/Layout/Header/Row/CloseButton
@onready var value_label: Label = $Scrim/Card/Layout/Body/BodyLayout/ValueLabel
@onready var bar: StatBar = $Scrim/Card/Layout/Body/BodyLayout/Bar
@onready var description_label: Label = $Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel

## Guards against a double close: the exit tween and the scrim tap can both
## fire, and freeing twice crashes.
var _is_closing: bool = false


func _ready() -> void:
	scrim.color = _scrim_color(0.0)
	close_button.pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_input)


## The project's modal scrim at a given opacity. `alpha_scale` of 0 gives the
## same hue at zero opacity, which is what the fades tween from and back to --
## tweening between two different hues would flash mid-fade.
func _scrim_color(alpha_scale: float = 1.0) -> Color:
	var c := DesignTokens.load_default().scrim_color()
	c.a *= alpha_scale
	return c


## Fill every label and the bar from one entry of StatInfo.BARS.
## Call before adding the popup to the tree, or immediately after -- it needs
## the @onready references, so it must run inside the tree.
##
## `icon` is the screen's own artwork for this bar (report_card and
## student_card each carry their own @export'd icon set). Pass null to fall
## back to the emoji glyph from StatInfo.
##
## Affects: this popup's own nodes only.
func configure(bar_name: String, s_data: Dictionary, icon: Texture2D) -> void:
	var info := StatInfo.get_bar(bar_name)
	if info.is_empty():
		# An unknown bar name means a caller typo. Show an empty popup rather
		# than taking the screen down.
		category_label.text = ""
		name_label.text = ""
		value_label.text = ""
		description_label.text = ""
		icon_rect.visible = false
		glyph_label.visible = false
		return

	var value := StatInfo.value_of(bar_name, s_data)

	category_label.text = info["category_label"]
	name_label.text = info["display_name"]
	description_label.text = info["description"]
	value_label.text = "%s: %d / %d" % [
		String(info["display_name"]).to_upper(), int(value), int(bar.max_value)]

	# Exactly one of the two icon paths shows. The texture wins when the
	# screen supplied one; the emoji is the fallback the old code used.
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	glyph_label.text = info["glyph"]
	glyph_label.visible = icon == null

	bar.category = info["token_category"]
	bar.set_stat(value, false)


## Play the reveal: place the card above the bottom edge, pop it in, fade the
## scrim up. A coroutine because the card's height is only known after one
## layout pass. Callers must NOT await it -- fire and forget.
##
## Affects: this popup's nodes, and plays the popup_open SFX.
func open() -> void:
	AudioDirector.play_sfx(&"popup_open")
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	card.position = Vector2(
		(vp.x - card.size.x) * 0.5,
		vp.y - card.size.y - float(DesignTokens.load_default().space_md))
	Juice.pop_in(card)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(scrim, "color", _scrim_color(), scrim_fade_in_seconds)


## Slide the card out, fade the scrim, free this node, emit `closed`.
## Safe to call twice; the second call is ignored.
##
## Affects: frees this node. Plays the popup_close SFX.
func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	AudioDirector.play_sfx(&"popup_close")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "position:y", vp.y, close_slide_seconds)
	tw.tween_property(scrim, "color", _scrim_color(0.0), scrim_fade_out_seconds)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


## Tapping anywhere on the scrim dismisses, matching the shipped behaviour.
func _on_scrim_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		close()
```

- [ ] **Step 5: Rewire ReportCard**

In `Scripts/ReportCard/report_card.gd`:

1. Delete `const BAR_CATEGORY := {…}` (lines 267-273) and its doc comment.
2. Change `_get_bar_color` to read from `StatInfo`:

```gdscript
## The accent colour a given bar wears, from DesignTokens via StatInfo.
## Affects: the tint of the bars drawn on the card itself.
func _get_bar_color(bname: String) -> Color:
	return DesignTokens.load_default().category_color(StatInfo.token_category(bname))
```

3. Replace the whole of `_show_bar_popup` (lines 287-455) with:

```gdscript
## The scene the stat-detail modal is authored in. Exported so the popup can
## be restyled or swapped without touching this screen.
@export var stat_popup_scene: PackedScene = preload("res://Scenes/UI/StatDetailPopup.tscn")

## Open the stat-detail modal for one bar.
##
## Affects: adds a CanvasLayer child to `kertas`, hides the page-turn arrows
## while it is open, and sets `_active_popup` so a second tap is ignored.
## No longer a coroutine -- StatDetailPopup.open() owns the reveal.
func _show_bar_popup(kertas: Control, bname: String, s_data: Dictionary) -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()

	var popup: StatDetailPopup = stat_popup_scene.instantiate()
	_active_popup = popup
	kertas.add_child(popup)
	popup.configure(bname, s_data, _get_stat_icon(bname))
	popup.closed.connect(_on_detail_popup_closed)
	popup.open()

## Restore the page-turn arrows and clear the guard once a modal finishes its
## exit animation. Shared by the stat and trait popups.
func _on_detail_popup_closed() -> void:
	_active_popup = null
	if next_kanan: next_kanan.show()
	if next_kiri: next_kiri.show()
```

4. Leave `_close_trait_popup` alone for now — the trait popup still uses it
   and Task 7 removes it.

Note: the old `_show_bar_popup` did **not** re-show the arrows on close (only
`_close_trait_popup` did, via nothing — the arrows were left hidden until the
next `_show_page`). If re-showing them here changes visible behaviour, drop
the two `show()` calls from `_on_detail_popup_closed` and keep the shipped
behaviour. Verify by opening a stat popup and closing it before and after.

- [ ] **Step 6: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="stat_detail_popup")
test_run(suite="report_card")
```

Expected: `stat_detail_popup` 8 PASS; `report_card` still green.

- [ ] **Step 7: Verify it visually, once**

Seed rather than play: press `F1` (or 5 taps in the top-right corner), hit
**⚡ Seed Playtest State**, then use the overlay's **Scenes** tab to teleport
to ReportCard. Tap a stat bar. Take one `editor_screenshot`. The popup must
look identical to before: same width, same card, same bar tint, same slide-up.

- [ ] **Step 8: Lower the editability baseline**

`report_card.gd` drops roughly 15 runtime visual constructions. Run:

```
test_run(suite="viewport_editability")
```

Expected: `test_baseline_is_not_stale` FAILS and prints the new literal. Paste
it over `BASELINE`, rescan, re-run. Expected: both PASS.

- [ ] **Step 9: Run the whole suite**

```
test_run()
```

Expected: all suites green.

- [ ] **Step 10: Commit**

```bash
git add Scenes/UI/StatDetailPopup.tscn Scripts/UI/StatDetailPopup.gd Scripts/ReportCard/report_card.gd tests/test_stat_detail_popup.gd tests/test_viewport_editability.gd && git commit -m "refactor(report-card): extract the stat popup to an editable scene"
```

---

### Task 6: Rewire StudentCard onto the same popup

The duplicate. `student_card.gd:1057-1230` is the same builder; this task
deletes it.

**Files:**
- Modify: `Scripts/StudentCard/student_card.gd` — delete `_show_bar_popup`
  (1056-1224) and `const BAR_CATEGORY` (1036-1042)
- Test: `tests/test_stat_detail_popup.gd` (add one test)

**Interfaces:**
- Consumes: `StatDetailPopup.configure/open/closed` and
  `StatInfo.token_category` exactly as Task 5 defined them. No new API.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_stat_detail_popup.gd`:

```gdscript
func test_student_card_no_longer_builds_the_popup_itself() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	assert_contains(src, "StatDetailPopup",
		"student_card.gd should instantiate the extracted scene")
	assert_false(src.contains("const BAR_CATEGORY"),
		"BAR_CATEGORY moved to StatInfo.token_category()")


func test_the_two_screens_share_one_popup_implementation() -> void:
	# The regression this whole task exists to prevent: the two screens each
	# carried a verbatim copy of the same 168-line builder, and they had
	# already drifted. Neither may build a StatBar for a popup again.
	for path in ["res://Scripts/ReportCard/report_card.gd",
			"res://Scripts/StudentCard/student_card.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("StatBar.new("),
			"%s builds a StatBar in code -- use StatDetailPopup" % path)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="stat_detail_popup")
```

Expected: both new tests FAIL.

- [ ] **Step 3: Apply the same rewire**

In `Scripts/StudentCard/student_card.gd`, make exactly the changes Task 5
Step 5 made to `report_card.gd`:

1. Delete `const BAR_CATEGORY := {…}` (lines 1036-1042).
2. Rewrite `_get_bar_color` (line 1046-1047) to use
   `StatInfo.token_category(bname)`.
3. Replace `_show_bar_popup` (lines 1056-1224) with the same short version.
   StudentCard has no page-turn arrows, so drop the `next_kanan`/`next_kiri`
   lines; check what this screen hides while a popup is open (grep for
   `_active_popup` around line 1054) and preserve exactly that.
4. Add the `@export var stat_popup_scene: PackedScene = preload(…)` line
   beside the screen's other exports, with a `##` doc line above it.

- [ ] **Step 4: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="stat_detail_popup")
test_run(suite="student_card")
test_run(suite="student_card_layout")
```

Expected: all green.

- [ ] **Step 5: Verify it visually, once**

Seed, teleport to StudentCard, tap a stat bar, one screenshot. Identical to
before.

- [ ] **Step 6: Lower the editability baseline and run everything**

```
test_run(suite="viewport_editability")
```

Paste the regenerated `BASELINE`, rescan, then:

```
test_run()
```

Expected: all suites green.

- [ ] **Step 7: Commit**

```bash
git add Scripts/StudentCard/student_card.gd tests/test_stat_detail_popup.gd tests/test_viewport_editability.gd && git commit -m "refactor(student-card): reuse the shared stat popup scene"
```

---

### Task 7: `TraitDetailPopup.tscn` and rewire both screens

The second duplicated pair: `report_card.gd:457-587` and
`student_card.gd:1226-1355`.

**Files:**
- Create: `Scenes/UI/TraitDetailPopup.tscn`, `Scripts/UI/TraitDetailPopup.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` — add a `TraitPopupHeader` variation
- Modify: `Scripts/ReportCard/report_card.gd` — replace `_show_trait_popup`,
  delete `_close_trait_popup`
- Modify: `Scripts/StudentCard/student_card.gd` — same
- Test: `tests/test_trait_detail_popup.gd`

**Interfaces:**
- Consumes: `DesignTokens.brand_primary`, `DesignTokens.cat_istirahat`,
  `Juice.pop_in`, `AudioDirector.play_sfx`,
  `StudentCardView.quirk_description()` / `persona_description()`.
- Produces:
  - `class_name TraitDetailPopup extends CanvasLayer`
  - `signal closed`
  - `func configure(trait_kind: String, trait_name: String, description: String) -> void`
    where `trait_kind` is `"quirk"` or `"persona"`
  - `func open() -> void` (coroutine), `func close() -> void`
  - `ThemeFactory` variation `TraitPopupHeader` — a `PanelContainer` panel with
    `radius_lg` top corners, `space_md`/`space_sm` content margins, and a
    **white** background so the script can tint it with `self_modulate`.

- [ ] **Step 1: Add the theme variation**

The shipped header builds a `StyleBoxFlat` at runtime purely to carry the
quirk-vs-persona accent. A white-backed variation plus `self_modulate` gets
the same pixels with no `add_theme_stylebox_override`. In
`Scripts/Design/ThemeFactory.gd`, beside the other panel variations
(around line 157, where `SunkenPanel` is defined), add:

```gdscript
	# A card header whose accent is chosen at runtime. The background is
	# white so the caller can tint it with self_modulate -- the accent is the
	# one value on this surface that genuinely varies per instance (quirk
	# versus persona), and no fixed variation can express it. Every other
	# value still comes from a token.
	theme.add_type("TraitPopupHeader")
	theme.set_type_variation("TraitPopupHeader", "PanelContainer")
	var trait_header := StyleBoxFlat.new()
	trait_header.bg_color = Color.WHITE
	trait_header.corner_radius_top_left = tokens.radius_lg
	trait_header.corner_radius_top_right = tokens.radius_lg
	trait_header.content_margin_left = tokens.space_md
	trait_header.content_margin_top = tokens.space_sm
	trait_header.content_margin_right = tokens.space_md
	trait_header.content_margin_bottom = tokens.space_sm
	theme.set_stylebox("panel", "TraitPopupHeader", trait_header)
```

Match the surrounding code's local-variable naming for `tokens` — read the
enclosing function before pasting.

Then rebake: File > Run (Ctrl+Shift+X) on `Scripts/Design/BakeTheme.gd`.
This rewrites `Assets/Theme/kejartes_theme.tres`.

- [ ] **Step 2: Write the failing test**

Create `tests/test_trait_detail_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## The quirk/persona detail modal, extracted from the verbatim copies in
## report_card.gd and student_card.gd.
##
## The one thing that genuinely varies per instance is the header accent --
## brand_primary for a quirk, cat_istirahat for a persona -- so these tests
## pin that mapping as well as the node contract.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "trait_detail_popup"


const SCENE_PATH := "res://Scenes/UI/TraitDetailPopup.tscn"


func _make() -> TraitDetailPopup:
	var popup: TraitDetailPopup = load(SCENE_PATH).instantiate()
	track(popup)
	return popup


func test_scene_exists_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	assert_not_null(_make())


func test_scene_supplies_every_node_the_script_binds() -> void:
	var popup := _make()
	for path in ["Scrim", "Scrim/Card", "Scrim/Card/Layout/Header",
			"Scrim/Card/Layout/Header/Row/GlyphLabel",
			"Scrim/Card/Layout/Header/Row/Titles/KindLabel",
			"Scrim/Card/Layout/Header/Row/Titles/NameLabel",
			"Scrim/Card/Layout/Header/Row/CloseButton",
			"Scrim/Card/Layout/Body/DescriptionLabel"]:
		assert_not_null(popup.get_node_or_null(path), "missing node: %s" % path)


func test_header_uses_the_theme_variation_not_a_runtime_stylebox() -> void:
	var popup := _make()
	var header: PanelContainer = popup.get_node("Scrim/Card/Layout/Header")
	assert_eq(header.theme_type_variation, &"TraitPopupHeader")
	assert_false(header.has_theme_stylebox_override("panel"),
		"the accent must come from self_modulate, not a stylebox override")


func test_quirk_and_persona_get_their_own_accent() -> void:
	var tokens := DesignTokens.load_default()
	var quirk := _make()
	quirk.configure("quirk", "Kutu Buku", "Suka membaca.")
	assert_eq(quirk.get_node("Scrim/Card/Layout/Header").self_modulate,
		tokens.brand_primary)
	assert_eq(quirk.get_node("Scrim/Card/Layout/Header/Row/Titles/KindLabel").text, "QUIRK")
	assert_eq(quirk.get_node("Scrim/Card/Layout/Header/Row/GlyphLabel").text, "⚡")

	var persona := _make()
	persona.configure("persona", "Tekun", "Belajar terus.")
	assert_eq(persona.get_node("Scrim/Card/Layout/Header").self_modulate,
		tokens.cat_istirahat)
	assert_eq(persona.get_node("Scrim/Card/Layout/Header/Row/Titles/KindLabel").text, "PERSONA")
	assert_eq(persona.get_node("Scrim/Card/Layout/Header/Row/GlyphLabel").text, "🌟")


func test_description_keeps_the_gameplay_effect_prefix() -> void:
	# Player-facing Indonesian copy shipped with this exact prefix.
	var popup := _make()
	popup.configure("quirk", "Kutu Buku", "Suka membaca.")
	assert_contains(
		popup.get_node("Scrim/Card/Layout/Body/DescriptionLabel").text,
		"EFEK GAMEPLAY")


func test_neither_screen_builds_a_trait_popup_by_hand() -> void:
	for path in ["res://Scripts/ReportCard/report_card.gd",
			"res://Scripts/StudentCard/student_card.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "TraitDetailPopup", "%s should use the scene" % path)
		assert_false(src.contains("_close_trait_popup"),
			"%s still owns the hand-rolled popup teardown" % path)
		assert_false(src.contains("StyleBoxFlat.new("),
			"%s builds a stylebox in code -- use the TraitPopupHeader variation" % path)


func test_scene_has_no_theme_overrides() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for line in text.split("\n"):
		if line.begins_with("theme_override_") and not line.begins_with("theme_override_constants/"):
			assert_true(false, "theme override in the scene file: " + line)
```

- [ ] **Step 3: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="trait_detail_popup")
```

Expected: every test FAILS — the scene does not exist. (The theme-variation
test may pass trivially once the scene exists; that is fine.)

- [ ] **Step 4: Author the scene**

`Scenes/UI/TraitDetailPopup.tscn`, same skeleton as `StatDetailPopup` with a
tinted header and no bar:

```
TraitDetailPopup           CanvasLayer   layer = 100, script = TraitDetailPopup.gd
└─ Scrim                   ColorRect     Full Rect, mouse_filter = Stop, color = (0,0,0,0)
   └─ Card                 PanelContainer theme_type_variation = "Card",
                                         Center Bottom, custom_minimum_size = (1015, 0)
      └─ Layout            VBoxContainer  separation = 0
         ├─ Header         PanelContainer theme_type_variation = "TraitPopupHeader"
         │  └─ Row         HBoxContainer  separation = 18
         │     ├─ GlyphLabel Label        theme_type_variation = "H1Label",
         │     │                          vertical_alignment = Center
         │     ├─ Titles   VBoxContainer  size_flags_horizontal = Expand Fill
         │     │  ├─ KindLabel Label      theme_type_variation = "BarLabel"
         │     │  └─ NameLabel Label      theme_type_variation = "BarLabel",
         │     │                          autowrap_mode = Word (Smart)
         │     └─ CloseButton Button      text = "✕",
         │                                theme_type_variation = "SecondaryButton",
         │                                custom_minimum_size = (96, 96),
         │                                size_flags_vertical = Shrink Begin
         └─ Body           PanelContainer theme_type_variation = "SunkenPanel"
            └─ DescriptionLabel Label     theme_type_variation = "TitleLabel",
                                          autowrap_mode = Word (Smart),
                                          theme_override_constants/line_spacing = 12
```

`KindLabel` and `NameLabel` use `BarLabel` because both sit on the saturated
accent header — that is exactly the backdrop `BarLabel` exists for (white
glyph, dark rim). This is unchanged from the shipped code.

- [ ] **Step 5: Write the popup script**

Create `Scripts/UI/TraitDetailPopup.gd`. It is `StatDetailPopup` with the bar
removed and the accent added — copy that file's structure, including the doc
header shape, `_scrim_color`, `open`, `close` and `_on_scrim_input` verbatim,
and replace `configure` with:

```gdscript
## Player-facing prefix on every trait description. Indonesian, ships as-is.
const EFFECT_PREFIX := "💡  EFEK GAMEPLAY:\n"

## Fill the popup for one quirk or persona.
##
## `trait_kind` is "quirk" or "persona"; anything else is treated as a
## persona. The accent it selects is the one value on this surface that
## varies per instance -- it matches the QuirkBadge / PersonaBadge button
## variations, so tapping a badge opens a popup headed in that badge's colour.
##
## Affects: this popup's own nodes only.
func configure(trait_kind: String, trait_name: String, description: String) -> void:
	var is_quirk := trait_kind == "quirk"
	var tokens := DesignTokens.load_default()
	header.self_modulate = tokens.brand_primary if is_quirk else tokens.cat_istirahat
	glyph_label.text = "⚡" if is_quirk else "🌟"
	kind_label.text = "QUIRK" if is_quirk else "PERSONA"
	name_label.text = trait_name
	description_label.text = EFFECT_PREFIX + description
```

with `@onready var header: PanelContainer = $Scrim/Card/Layout/Header` and the
matching `kind_label` / `name_label` / `glyph_label` / `description_label`
bindings.

- [ ] **Step 6: Rewire both screens**

In `report_card.gd` and `student_card.gd`, replace `_show_trait_popup` and
delete `_close_trait_popup` entirely. The replacement, in both files:

```gdscript
## The scene the trait-detail modal is authored in.
@export var trait_popup_scene: PackedScene = preload("res://Scenes/UI/TraitDetailPopup.tscn")

## Open the quirk/persona detail modal.
##
## Affects: adds a CanvasLayer child to `kertas` and sets `_active_popup`.
## `on_close` is invoked after the exit animation -- StudentCard's onboarding
## tutorial chains its next step off it.
func _show_trait_popup(kertas: Control, type: String, name: String,
		desc: String, on_close: Callable = Callable()) -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	var popup: TraitDetailPopup = trait_popup_scene.instantiate()
	_active_popup = popup
	kertas.add_child(popup)
	popup.configure(type, name, desc)
	popup.closed.connect(func() -> void:
		_active_popup = null
		if on_close.is_valid():
			on_close.call())
	popup.open()
```

Keep the arrow-hiding lines `report_card.gd` had (`next_kanan.hide()` /
`next_kiri.hide()`) — StudentCard has no arrows, so its copy omits them.

- [ ] **Step 7: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="trait_detail_popup")
test_run(suite="report_card")
test_run(suite="student_card")
test_run(suite="theme_factory")
test_run(suite="design_tokens")
```

Expected: all green. `theme_factory` covers the new variation; if that suite
enumerates variations against a fixed list, add `TraitPopupHeader` to it.

- [ ] **Step 8: Verify it visually, once**

Seed, teleport to StudentCard, tap a quirk badge and then a persona badge.
One screenshot each. The header accents must match the badge colours exactly
as before. `self_modulate` on a white stylebox and a coloured stylebox are
only identical when the base is pure white — if the accents look washed out,
the baked stylebox is not white; fix the variation, rebake, re-check.

- [ ] **Step 9: Lower both ratchet baselines**

Both screens lose ~14 more constructions each; both gain one documented
export.

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both regenerated literals, rescan, re-run.

- [ ] **Step 10: Run the whole suite**

```
test_run()
```

Expected: all suites green.

- [ ] **Step 11: Commit**

```bash
git add Scenes/UI/TraitDetailPopup.tscn Scripts/UI/TraitDetailPopup.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres Scripts/ReportCard/report_card.gd Scripts/StudentCard/student_card.gd tests/test_trait_detail_popup.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(ui): extract the trait popup to a shared editable scene"
```

---
## Phase 2 — Minigame sprites and layout

The part of the request that says "every sprite". Badminton is nearly there
already; MainBola is the worst case in the project; `BaseMinigame` builds
every shared overlay by hand, including a 339-line result popup.

---

### Task 8: Badminton — the sprites live in the scene

`Badminton.gd` already exposes its art as `@export`s and the `.tscn` already
supplies the textures. What it does not do is put the `Sprite2D`s in the
scene: `_ready()` (lines 169-238) finds each `ColorRect` placeholder, hides
it, and creates a `Sprite2D` sibling at runtime. Open the scene today and you
see three flat rectangles, not the rackets and shuttlecock.

**Files:**
- Modify: `Scenes/Minigames/Olahraga/Badminton.tscn`
- Modify: `Scripts/Minigames/Olahraga/Badminton.gd` — lines 165-238 (sprite
  creation), 281-325 (the hit/squash animations that branch on
  sprite-vs-rect), 453 (the score flash)
- Test: `tests/test_badminton_visuals.gd`

**Interfaces:**
- Consumes: the existing `@export var shuttlecock_texture / player_racket_texture /
  enemy_racket_texture / racket_hit_texture: Texture2D` and their `*_color`
  companions, unchanged.
- Produces: `Puck/Sprite2D`, `PlayerPaddle/Sprite2D`, `EnemyPaddle/Sprite2D`
  as real nodes in the scene; `puck_sprite`, `player_paddle_sprite`,
  `enemy_paddle_sprite` become `@onready` bindings rather than variables
  assigned during construction.

- [ ] **Step 1: Write the failing test**

Create `tests/test_badminton_visuals.gd`:

```gdscript
@tool
extends McpTestSuite

## Badminton's art must be visible in the 2D viewport, not conjured in
## _ready(). The scene ships three ColorRect placeholders that the script used
## to hide and replace with runtime Sprite2Ds -- meaning a human opening the
## scene saw rectangles and could not position the rackets.
##
## Affects nothing at runtime. Scene-file text scan plus one instantiation.
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "badminton_visuals"


const SCENE_PATH := "res://Scenes/Minigames/Olahraga/Badminton.tscn"


func test_every_moving_piece_has_a_sprite_node_in_the_scene() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	for path in ["Puck/Sprite2D", "PlayerPaddle/Sprite2D", "EnemyPaddle/Sprite2D"]:
		var sprite := root.get_node_or_null(path) as Sprite2D
		assert_not_null(sprite, "missing scene node: %s" % path)
		assert_not_null(sprite.texture,
			"%s has no texture -- the scene should supply it, not _ready()" % path)


func test_the_script_no_longer_creates_sprites_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Olahraga/Badminton.gd")
	assert_false(src.contains("Sprite2D.new("),
		"Badminton.gd still builds sprites in code")


func test_placeholder_colorrects_are_gone_from_the_scene() -> void:
	# They existed only as a stand-in before there was art. Leaving them in
	# means the next person edits the wrong node.
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for parent in ["Puck", "PlayerPaddle", "EnemyPaddle"]:
		assert_false(
			text.contains('[node name="ColorRect" type="ColorRect" parent="%s"' % parent),
			"%s still carries the placeholder ColorRect" % parent)


func test_textures_still_come_from_exports_on_the_root() -> void:
	# The Inspector drag-and-drop path must survive the refactor: an artist
	# swaps raket_1.png on the root, and both the scene sprite and the hit
	# animation follow.
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for export_name in ["shuttlecock_texture", "player_racket_texture",
			"enemy_racket_texture", "racket_hit_texture"]:
		assert_contains(text, export_name,
			"%s is no longer assigned in the scene" % export_name)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="badminton_visuals")
```

Expected: `test_every_moving_piece_has_a_sprite_node_in_the_scene`,
`test_the_script_no_longer_creates_sprites_at_runtime` and
`test_placeholder_colorrects_are_gone_from_the_scene` all FAIL.

- [ ] **Step 3: Edit the scene**

In `Scenes/Minigames/Olahraga/Badminton.tscn`, for each of `Puck`,
`PlayerPaddle` and `EnemyPaddle`: delete the `ColorRect` child and add a
`Sprite2D` child named `Sprite2D`, centered on its parent (`position` =
(0, 0), `centered` = true).

Assign the textures in the scene, matching the root's existing `@export`
values so the two agree:

- `Puck/Sprite2D.texture` = `res://Assets/Images/Textures/puck.png`
- `PlayerPaddle/Sprite2D.texture` = `res://Assets/Images/Textures/raket_1.png`
- `EnemyPaddle/Sprite2D.texture` = `res://Assets/Images/Textures/raket_1.png`

Set each sprite's `scale` so it covers its collision shape: the puck's
`CircleShape2D` has radius 30 and each paddle's has radius 50, so the sprite
should read as 60px and 100px wide respectively. Compute the scale from the
real PNG dimensions rather than guessing — check them with the FileSystem
dock's import preview.

Now that they are scene nodes, **drag them in the 2D viewport to check they
land on their collision shapes.** That is the whole point of this task; do it
before moving on.

- [ ] **Step 4: Simplify the script**

In `Scripts/Minigames/Olahraga/Badminton.gd`:

1. Replace the three cached-node vars (lines 56-59) with `@onready` bindings:

```gdscript
# ─── Visual nodes ────────────────────────────────────────────────────────────
# These are real nodes in Badminton.tscn, positioned and textured there.
# The @export textures below still win at runtime so an artist can override
# the scene's choice from the root's Inspector without opening the subtree.
@onready var puck_sprite: Sprite2D = $Puck/Sprite2D
@onready var player_paddle_sprite: Sprite2D = $PlayerPaddle/Sprite2D
@onready var enemy_paddle_sprite: Sprite2D = $EnemyPaddle/Sprite2D
```

2. Replace the whole runtime-construction block (lines 165-238) with an
   apply pass that only pushes the exports onto the existing nodes:

```gdscript
## Push the root's @export art onto the scene's sprites.
##
## The scene already supplies a texture for each piece; these exports let an
## artist override all three from one Inspector panel without opening the
## subtree. A null export leaves the scene's own choice alone, and the
## `*_color` exports tint via modulate so a monochrome PNG can be recoloured.
##
## Affects: the three Sprite2D nodes' texture and modulate. Nothing else.
func _apply_visual_exports() -> void:
	if shuttlecock_texture != null:
		puck_sprite.texture = shuttlecock_texture
	puck_sprite.modulate = shuttlecock_color
	if player_racket_texture != null:
		player_paddle_sprite.texture = player_racket_texture
	player_paddle_sprite.modulate = player_racket_color
	if enemy_racket_texture != null:
		enemy_paddle_sprite.texture = enemy_racket_texture
	enemy_paddle_sprite.modulate = enemy_racket_color
```

   Call `_apply_visual_exports()` from `_ready()` where the old block ran.

3. Delete every `get_node_or_null("ColorRect")` branch. The animations at
   lines 281-325 and the score flash at line 453 each branch on
   sprite-vs-rect; now there is only ever a sprite, so keep the sprite arm and
   drop the fallback. Preserve the comment at line 287 explaining that the
   punch is relative to the node's resting scale.

- [ ] **Step 5: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="badminton_visuals")
```

Expected: 4 tests PASS.

- [ ] **Step 6: Play the minigame once**

Open the debug overlay (`F1`), use its **minigame launcher** to start
Badminton. Confirm: the shuttlecock and both rackets render, the racket
squash on contact still fires, the hit-pose texture swap still happens, and
scoring still flashes. This one genuinely needs playing — the failure mode is
an invisible sprite, which no test catches.

- [ ] **Step 7: Lower the editability baseline and run everything**

```
test_run(suite="viewport_editability")
```

Paste the regenerated `BASELINE`, rescan, then `test_run()`. Expected: all
suites green.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Minigames/Olahraga/Badminton.tscn Scripts/Minigames/Olahraga/Badminton.gd tests/test_badminton_visuals.gd tests/test_viewport_editability.gd && git commit -m "refactor(badminton): author the sprites in the scene instead of _ready()"
```

---

### Task 9: MainBola — a scene you can actually see

The worst case in the project. `MainBola.tscn` declares `FieldBG`, `GoalBack`,
`GoalNet`, `Crossbar`, `PostLeft`, `PostRight`, `Goalie`, `Ball` and
`TargetBox` with **no position and no size**. Everything is placed by
`_setup_layout()` (lines 146-277) at runtime, and the five textures come from
hardcoded `load("res://Assets/Images/Textures/…")` calls in `_load_textures()`
(lines 137-142). Open the scene and the viewport is empty.

`project.godot` sets `stretch/aspect="expand"`, so viewport height genuinely
varies and the fractional layout must stay. This is Pattern C from the
authoring guide: keep the computation, make every fraction a documented
`@export`, make the script `@tool`, and re-run the layout in the editor so the
viewport shows the truth and dragging a slider updates it live.

**Files:**
- Modify: `Scenes/Minigames/Olahraga/MainBola.tscn`
- Modify: `Scripts/Minigames/Olahraga/MainBola.gd` — lines 1-70 (exports),
  137-142 (`_load_textures`), 146-277 (`_setup_layout`)
- Test: `tests/test_main_bola_layout.gd`

**Interfaces:**
- Consumes: `BaseMinigame` (`screen_size`, `difficulty`, `win_game`,
  `lose_game`), unchanged.
- Produces on `MainBola.gd`:
  - `@export var goalie_idle_texture / goalie_left_texture /
    goalie_right_texture / goalie_fail_texture / ball_texture /
    field_background_texture: Texture2D`
  - `@export_range` layout knobs: `goal_top_frac`, `goal_height_frac`,
    `goal_width_frac`, `post_width_frac`, `crossbar_height_frac`,
    `goalie_width_frac`, `goalie_height_frac`, `goalie_depth_frac`,
    `ball_start_height_frac`, `ball_radius_frac`, `target_size_frac`
  - each with a setter that calls `_setup_layout()` when inside the tree.

- [ ] **Step 1: Write the failing test**

Create `tests/test_main_bola_layout.gd`:

```gdscript
@tool
extends McpTestSuite

## MainBola shipped as an invisible scene: every node had no position and no
## size, and _setup_layout() placed all of them at runtime from magic
## fractions buried in the function body. Its five textures came from
## hardcoded load() paths, so an artist could not swap them.
##
## project.godot sets stretch/aspect="expand", so viewport height really does
## vary and the fractional layout has to stay. The rule this suite enforces is
## Pattern C: the fractions are documented @exports, the script is @tool, and
## the art is @export'd Texture2D.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "main_bola_layout"


const SCRIPT_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
const SCENE_PATH := "res://Scenes/Minigames/Olahraga/MainBola.tscn"

## Every art slot the script used to fetch with a hardcoded load().
const TEXTURE_EXPORTS: Array[String] = [
	"goalie_idle_texture", "goalie_left_texture", "goalie_right_texture",
	"goalie_fail_texture", "ball_texture", "field_background_texture",
]

## Every magic fraction _setup_layout() used to hardcode.
const LAYOUT_EXPORTS: Array[String] = [
	"goal_top_frac", "goal_height_frac", "goal_width_frac",
	"post_width_frac", "crossbar_height_frac",
	"goalie_width_frac", "goalie_height_frac", "goalie_depth_frac",
	"ball_start_height_frac", "ball_radius_frac", "target_size_frac",
]


func test_script_is_tool_so_the_viewport_previews_the_layout() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.begins_with("@tool"),
		"MainBola.gd must be @tool or the editor shows an empty scene")


func test_no_art_is_fetched_by_hardcoded_path() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains('load("res://Assets/Images/Textures/'),
		"MainBola.gd still load()s art by path -- use @export Texture2D")


func test_every_texture_slot_is_an_export() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for name in TEXTURE_EXPORTS:
		assert_contains(src, "@export var %s: Texture2D" % name,
			"missing texture export: %s" % name)


func test_every_layout_fraction_is_a_documented_export() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var lines := src.split("\n")
	for name in LAYOUT_EXPORTS:
		var found := -1
		for i in range(lines.size()):
			if lines[i].contains("var %s" % name) and lines[i].strip_edges().begins_with("@export"):
				found = i
				break
		assert_gt(found, 0, "missing layout export: %s" % name)
		assert_true(lines[found - 1].strip_edges().begins_with("##"),
			"%s has no ## doc line -- it would be an unlabelled Inspector slider" % name)


func test_layout_reruns_when_a_knob_changes() -> void:
	# Without the setter, dragging a slider in the Inspector does nothing
	# until the game runs -- which defeats the point of previewing.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for name in LAYOUT_EXPORTS:
		var at := src.find("var %s" % name)
		assert_gt(at, 0, "missing export: %s" % name)
		var tail := src.substr(at, 320)
		assert_contains(tail, "_setup_layout()",
			"%s does not re-run the layout when set" % name)


func test_scene_positions_every_visual_node() -> void:
	# The scene, not the script, is where a human reads the layout. Every
	# node the script places must carry a position in the scene file too, so
	# opening it shows the real thing.
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	for path in ["FieldBG", "GoalBack", "GoalNet", "Crossbar",
			"PostLeft", "PostRight", "Goalie", "Ball", "TargetBox"]:
		var node := root.get_node_or_null(path)
		assert_not_null(node, "missing node: %s" % path)
	# Ball and Goalie are the two the player watches; if these are at the
	# origin the scene is still the old empty skeleton.
	assert_ne((root.get_node("Ball") as Node2D).position, Vector2.ZERO,
		"Ball sits at the origin -- the scene was never given a real position")
	assert_ne((root.get_node("Goalie") as Node2D).position, Vector2.ZERO,
		"Goalie sits at the origin -- the scene was never given a real position")
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="main_bola_layout")
```

Expected: all 6 tests FAIL.

- [ ] **Step 3: Convert the art to exports**

At the top of `Scripts/Minigames/Olahraga/MainBola.gd`, add `@tool` on line 1
and add an art group beside the existing `Visual - Typography` group. The six
defaults are the exact paths `_load_textures()` and `_setup_layout()` used, so
behaviour is unchanged:

```gdscript
# ─── Visual - Art ────────────────────────────────────────────────────────────
@export_group("Visual - Art")
## The goalkeeper standing ready, before the shot resolves.
@export var goalie_idle_texture: Texture2D = preload("res://Assets/Images/Textures/KiperIdle.jpg")
## The goalkeeper diving left. Shown when the save resolves to the left.
@export var goalie_left_texture: Texture2D = preload("res://Assets/Images/Textures/KiperLeft.jpg")
## The goalkeeper diving right.
@export var goalie_right_texture: Texture2D = preload("res://Assets/Images/Textures/KiperRight.jpg")
## The goalkeeper beaten. Shown on a scored goal.
@export var goalie_fail_texture: Texture2D = preload("res://Assets/Images/Textures/Fail.jpg")
## The ball.
@export var ball_texture: Texture2D = preload("res://Assets/Images/Textures/bola.png")
## The pitch and goal frame behind everything. When this is set the procedural
## goal overlays (GoalBack, GoalNet, Crossbar, PostLeft, PostRight) hide, so
## the artwork's own goalposts show cleanly instead of being double-drawn.
@export var field_background_texture: Texture2D = preload("res://Assets/Images/Textures/Gawang.jpg")
```

Delete `_load_textures()` (lines 137-142) and the five `tex_*` variables
(lines 53-57); replace every `tex_idle` / `tex_left` / `tex_right` /
`tex_fail` / `tex_ball` reference with the matching export name. Delete the
`ResourceLoader.exists` .jpg/.png probe inside `_setup_layout()` — an export
either holds a texture or is null, and null is the "hide the background" case.

Verify each `preload` path resolves before running:

```bash
for p in KiperIdle.jpg KiperLeft.jpg KiperRight.jpg Fail.jpg bola.png Gawang.jpg; do test -e "Assets/Images/Textures/$p" || echo "MISSING: $p"; done
```

If `Gawang.jpg` is absent but `Gawang.png` is present, use the `.png` path —
the shipped code probed for both.

- [ ] **Step 4: Convert the layout fractions to knobs**

Every literal fraction in `_setup_layout()` becomes an export with a `##` line
and a setter. The values below are exactly what lines 149-163 hardcode, so the
game looks identical:

```gdscript
# ─── Layout knobs ────────────────────────────────────────────────────────────
# project.godot sets stretch/aspect="expand", so viewport height varies by
# device and this layout has to be computed rather than authored as fixed
# positions. Each knob below is a fraction of the viewport; changing one
# re-runs _setup_layout() immediately, in the editor as well as at runtime.
@export_group("Layout")

## Top edge of the goal mouth, as a fraction of viewport height.
@export_range(0.0, 1.0, 0.005) var goal_top_frac: float = 0.28:
	set(value):
		goal_top_frac = value
		if is_inside_tree():
			_setup_layout()

## Height of the goal mouth, as a fraction of viewport height.
@export_range(0.05, 1.0, 0.005) var goal_height_frac: float = 0.28:
	set(value):
		goal_height_frac = value
		if is_inside_tree():
			_setup_layout()

## Width of the goal mouth, as a fraction of viewport width.
@export_range(0.1, 1.0, 0.005) var goal_width_frac: float = 0.88:
	set(value):
		goal_width_frac = value
		if is_inside_tree():
			_setup_layout()
```

…and the same shape for `post_width_frac` (0.020 of width),
`crossbar_height_frac` (0.013 of height), `target_size_frac` (0.18 of width),
`ball_start_height_frac` (0.86 of height), plus `goalie_width_frac`,
`goalie_height_frac`, `goalie_depth_frac` (0.76 — the goalie's position
between the goal's top and bottom edge) and `ball_radius_frac`. Read lines
216-260 for the goalie and ball numbers rather than inventing them; every
default must be the literal that is there today.

Then rewrite the body of `_setup_layout()` to read the knobs instead of the
literals, and add a `##` header to it saying what it affects:

```gdscript
## Place every visual node from the layout knobs above.
##
## Runs on _ready(), on viewport resize, and whenever a knob changes -- in the
## editor as well as at runtime, which is what makes the 2D viewport show the
## real layout instead of an empty scene.
##
## Affects: the position and size of FieldBG, GoalBack, GoalNet, Crossbar,
## PostLeft, PostRight, GoalArea's collision shape, Goalie (and its
## CollisionShape2D and GFX), Ball (same), and TargetBox. Writes the cached
## goal_left_x / goal_right_x / goal_top_y / goal_bot_y / ball_start_pos /
## goalie_base_pos values the shot resolution reads.
func _setup_layout() -> void:
```

Guard the runtime-only work in `_ready()` behind `Engine.is_editor_hint()` per
the project's `@tool` convention, but leave `_setup_layout()` itself ungated —
running it in the editor is the entire point.

Also set `screen_size` from `get_viewport_rect().size` at the top of
`_setup_layout()` rather than relying on `_ready()`, so an editor-side call
has a viewport size to work from.

- [ ] **Step 5: Bake the result into the scene**

Open `Scenes/Minigames/Olahraga/MainBola.tscn`. With the script now `@tool`,
the viewport shows the real layout. Save the scene so the computed positions
and sizes persist as scene data — that is what makes
`test_scene_positions_every_visual_node` pass and what a human sees on the
next open.

Give `Goalie/GFX` and `Ball/GFX` their textures in the scene too, so the art
shows without running the game.

Then **verify the knobs live**: select the root, drag `goal_width_frac` in the
Inspector, and watch the posts move in the viewport. If they do not, the
setter is not firing — fix that before continuing, because it is the
deliverable.

- [ ] **Step 6: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="main_bola_layout")
```

Expected: 6 tests PASS.

- [ ] **Step 7: Play the minigame once**

Debug overlay (`F1`) → minigame launcher → MainBola. Confirm: the pitch
renders, the goalie animates left/right/fail, the ball flies, the target box
oscillates, and scoring still ends the game. The `Gawang` background must
still suppress the procedural goal overlays.

- [ ] **Step 8: Update both ratchets and run everything**

`MainBola.gd` gains ~17 documented exports and loses no visual construction
(it never had any — its problem was the empty scene), so
`script_documentation` may need its `PENDING_EXPORT_DOCS` regenerated.

```
test_run(suite="script_documentation")
```

Paste any regenerated literal, rescan, then `test_run()`.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Minigames/Olahraga/MainBola.tscn Scripts/Minigames/Olahraga/MainBola.gd tests/test_main_bola_layout.gd tests/test_script_documentation.gd && git commit -m "refactor(mainbola): author the pitch in the scene with @export layout knobs"
```

---

### Task 10: `BaseMinigame` — the countdown and quit dialog become scenes

`_play_countdown()` (lines 289-322) and `_show_quit_confirmation()` (lines
350-472) build a CanvasLayer, a scrim, a card, labels and two buttons each.
Every minigame inherits them, so both appear in all eight games and neither
can be seen in any scene.

**Files:**
- Create: `Scenes/Minigames/UI/MinigameCountdown.tscn`,
  `Scripts/Minigames/UI/MinigameCountdown.gd`
- Create: `Scenes/Minigames/UI/QuitConfirmDialog.tscn`,
  `Scripts/Minigames/UI/QuitConfirmDialog.gd`
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd` — lines 289-322, 350-472
- Test: `tests/test_minigame_overlays.gd`

**Interfaces:**
- Consumes: the existing `BaseMinigame` exports, all preserved and forwarded —
  `countdown_font`, `countdown_font_size`, `countdown_font_color`,
  `countdown_outline_color`, `countdown_outline_size`, `countdown_steps_text`,
  `quit_dialog_message_text`, `quit_dialog_yes_button_text`,
  `quit_dialog_no_button_text`, `quit_dialog_bg_texture`,
  `quit_dialog_bg_color`, `quit_dialog_card_texture`, `quit_dialog_card_color`,
  `quit_dialog_card_border_color`, `quit_dialog_yes_button_texture`,
  `quit_dialog_no_button_texture`, `quit_dialog_font`, `quit_dialog_font_size`,
  `quit_dialog_font_color`.
- Produces:
  - `class_name MinigameCountdown extends CanvasLayer` with
    `signal finished`, `func configure(steps: Array[String], font: Font,
    font_size: int, font_color: Color, outline_color: Color,
    outline_size: int) -> void` and `func play() -> void` (coroutine).
  - `class_name QuitConfirmDialog extends CanvasLayer` with
    `signal confirmed`, `signal cancelled`, and a `configure(...)` taking the
    nine quit-dialog exports above.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_overlays.gd`:

```gdscript
@tool
extends McpTestSuite

## The countdown and the quit confirmation are shared by all eight minigames.
## Both used to be built node-by-node inside BaseMinigame, so neither could be
## opened, seen or restyled in the editor.
##
## Every @export BaseMinigame already had for them is preserved and forwarded
## through configure(), so an artist's Inspector workflow is unchanged.
##
## Must be @tool; no test here may be a coroutine, so nothing calls play().

func suite_name() -> String:
	return "minigame_overlays"


const COUNTDOWN_PATH := "res://Scenes/Minigames/UI/MinigameCountdown.tscn"
const QUIT_PATH := "res://Scenes/Minigames/UI/QuitConfirmDialog.tscn"


func test_both_overlays_exist_as_scenes() -> void:
	assert_true(ResourceLoader.exists(COUNTDOWN_PATH), "%s is missing" % COUNTDOWN_PATH)
	assert_true(ResourceLoader.exists(QUIT_PATH), "%s is missing" % QUIT_PATH)


func test_countdown_scene_carries_its_label() -> void:
	var node: Node = load(COUNTDOWN_PATH).instantiate()
	track(node)
	var label := node.get_node_or_null("Center/CountLabel") as Label
	assert_not_null(label, "MinigameCountdown needs a Center/CountLabel node")


func test_quit_dialog_scene_carries_its_message_and_buttons() -> void:
	var node: Node = load(QUIT_PATH).instantiate()
	track(node)
	for path in ["Backdrop", "Center/Card/Margin/Layout/MessageLabel",
			"Center/Card/Margin/Layout/Buttons/YesButton",
			"Center/Card/Margin/Layout/Buttons/NoButton"]:
		assert_not_null(node.get_node_or_null(path), "missing node: %s" % path)


func test_quit_dialog_configure_applies_the_exported_copy() -> void:
	var node = load(QUIT_PATH).instantiate()
	track(node)
	node.configure("Yakin?", "Iya", "Tidak", null, Color.BLACK, null,
		Color.WHITE, Color.RED, null, null, null, 46, Color.WHITE)
	assert_eq(node.get_node("Center/Card/Margin/Layout/MessageLabel").text, "Yakin?")
	assert_eq(node.get_node("Center/Card/Margin/Layout/Buttons/YesButton").text, "Iya")
	assert_eq(node.get_node("Center/Card/Margin/Layout/Buttons/NoButton").text, "Tidak")


func test_quit_dialog_emits_confirmed_and_cancelled() -> void:
	var node = load(QUIT_PATH).instantiate()
	track(node)
	assert_true(node.has_signal("confirmed"), "QuitConfirmDialog needs a confirmed signal")
	assert_true(node.has_signal("cancelled"), "QuitConfirmDialog needs a cancelled signal")


func test_base_minigame_no_longer_builds_either_overlay() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "MinigameCountdown", "BaseMinigame should instantiate the scene")
	assert_contains(src, "QuitConfirmDialog", "BaseMinigame should instantiate the scene")
	assert_false(src.contains("CenterContainer.new("),
		"BaseMinigame still builds overlay chrome by hand")


func test_every_shipped_export_survived() -> void:
	# The refactor must not quietly drop an Inspector slot an artist uses.
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	for name in ["countdown_font", "countdown_font_size", "countdown_font_color",
			"countdown_outline_color", "countdown_outline_size",
			"countdown_steps_text", "quit_dialog_message_text",
			"quit_dialog_yes_button_text", "quit_dialog_no_button_text",
			"quit_dialog_bg_texture", "quit_dialog_bg_color",
			"quit_dialog_card_texture", "quit_dialog_card_color",
			"quit_dialog_card_border_color", "quit_dialog_yes_button_texture",
			"quit_dialog_no_button_texture", "quit_dialog_font",
			"quit_dialog_font_size", "quit_dialog_font_color"]:
		assert_contains(src, name, "export %s disappeared in the refactor" % name)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="minigame_overlays")
```

Expected: all tests except `test_every_shipped_export_survived` FAIL.

- [ ] **Step 3: Author `MinigameCountdown.tscn`**

```
MinigameCountdown   CanvasLayer      layer = 200, script = MinigameCountdown.gd
└─ Center           CenterContainer  anchors preset Full Rect
   └─ CountLabel    Label            text = "3", horizontal/vertical alignment Center
```

Read `BaseMinigame.gd:289-322` and reproduce the layer number, the label's
alignment and the per-step tween exactly. The font, size, colour and outline
are **not** set in the scene — they arrive through `configure()` from
BaseMinigame's exports, which is where an artist already sets them.

- [ ] **Step 4: Author `QuitConfirmDialog.tscn`**

```
QuitConfirmDialog        CanvasLayer      layer = 300, script = QuitConfirmDialog.gd
├─ Backdrop              TextureRect      Full Rect, mouse_filter = Stop
│                                         (a null texture leaves it a flat colour
│                                          via modulate -- matches the shipped
│                                          texture-or-ColorRect branch)
└─ Center                CenterContainer  Full Rect
   └─ Card               PanelContainer   theme_type_variation = "Card"
      └─ Margin          MarginContainer  margin_* per BaseMinigame.gd:400-406
         └─ Layout       VBoxContainer
            ├─ MessageLabel Label         autowrap_mode = Word (Smart),
            │                             horizontal_alignment = Center
            └─ Buttons   HBoxContainer
               ├─ YesButton Button        theme_type_variation = "DangerButton"
               └─ NoButton  Button        theme_type_variation = "SecondaryButton"
```

The shipped code builds a `StyleBoxTexture` when a card texture is set and a
`StyleBoxFlat` otherwise. Preserve that: `configure()` keeps the branch, but
it now sets the styleboxes on **one** node in a scene rather than building the
whole subtree. This is the one place in this plan where a runtime stylebox
survives, because the texture is an artist-supplied `@export` that no baked
theme variation can anticipate — note that in the script's doc header.

- [ ] **Step 5: Rewire `BaseMinigame`**

Replace `_play_countdown()`'s body with instantiate + configure + `await
overlay.play()`, and `_show_quit_confirmation()`'s body with instantiate +
configure + connect `confirmed`/`cancelled` to the existing handlers. Hold the
two scenes as exports so a game can override them:

```gdscript
## The countdown overlay every minigame plays before the first input.
@export var countdown_scene: PackedScene = preload("res://Scenes/Minigames/UI/MinigameCountdown.tscn")
## The "are you sure you want to quit" confirmation.
@export var quit_dialog_scene: PackedScene = preload("res://Scenes/Minigames/UI/QuitConfirmDialog.tscn")
```

Keep `_play_button_boing()` (line 473) wired to the dialog's two buttons —
that animation is shipped behaviour.

- [ ] **Step 6: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="minigame_overlays")
```

Expected: 7 tests PASS.

- [ ] **Step 7: Exercise both overlays in a real game**

Debug overlay → launch any minigame. The countdown must play as before. Then
open the pause menu and choose quit: the confirmation must appear, "Tidak"
must return to the game, "Iya" must abandon it. Check a second game too — the
whole point is that all eight share these.

- [ ] **Step 8: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both regenerated literals, rescan, `test_run()`. Expected: all green.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Minigames/UI/MinigameCountdown.tscn Scripts/Minigames/UI/MinigameCountdown.gd Scenes/Minigames/UI/QuitConfirmDialog.tscn Scripts/Minigames/UI/QuitConfirmDialog.gd Scripts/Minigames/UI/BaseMinigame.gd tests/test_minigame_overlays.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(minigames): extract the countdown and quit dialog to scenes"
```

---

### Task 11: `BaseMinigame` — the result popup becomes a scene

`_show_result_overlay()` spans lines 702-1041: 339 lines building the
win/lose card, the star row, the score readout, the stat deltas and the
continue button. It is the single largest UI builder in the project outside
the exempt debug overlay, and it is what every player sees at the end of
every minigame.

**Files:**
- Create: `Scenes/Minigames/UI/MinigameResultPopup.tscn`,
  `Scripts/Minigames/UI/MinigameResultPopup.gd`
- Create: `Scenes/Minigames/UI/ResultStar.tscn`, `Scripts/Minigames/UI/ResultStar.gd`
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd` — lines 679-700
  (`_draw_star_polygon`) and 702-1041
- Test: `tests/test_minigame_result_popup.gd`

**Interfaces:**
- Consumes: `BaseMinigame`'s existing result exports, all preserved —
  `win_title_text`, `lose_title_text`, `win_subtitle_text`,
  `lose_subtitle_text`, `win_title_color`, `lose_title_color`,
  `win_subtitle_color`, `lose_subtitle_color`, `result_title_font_size`,
  `result_subtitle_font_size`, `popup_card_texture`, `popup_card_color`,
  `popup_border_color`, `popup_dim_color`, `popup_star_texture`,
  `popup_star_empty_texture`, `popup_star_color`, `popup_star_empty_color`,
  `popup_star_size`, `popup_button_texture`, `popup_button_color`,
  `popup_button_text`, `popup_title_font`, `popup_body_font`,
  `popup_title_font_size`, `popup_score_font_size`, `popup_stat_font_size`,
  `popup_title_win_color`, `popup_title_lose_color`.
  Also `_calculate_stars(score, max_score, is_win) -> int` (line 667), which
  stays on `BaseMinigame` — it is game logic, not presentation.
- Produces:
  - `class_name ResultStar extends Control` with
    `func set_filled(filled: bool, filled_tex: Texture2D, empty_tex: Texture2D,
    filled_color: Color, empty_color: Color) -> void`. A star with no texture
    draws the same polygon `_draw_star_polygon` drew — move that code here.
  - `class_name MinigameResultPopup extends CanvasLayer` with
    `signal continued`, `func configure(is_win: bool, stars: int, score: int,
    max_score: int, subtitle: String, style: Dictionary) -> void` and
    `func play() -> void` (coroutine), where `style` is a dictionary of the
    29 exports above, forwarded verbatim.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_result_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## The end-of-minigame result card: 339 lines of runtime construction in
## BaseMinigame._show_result_overlay(), seen by every player after every one
## of the eight minigames, and impossible to open in the editor.
##
## Star rendering moves to its own tiny scene so the row is a container of
## real nodes rather than nine hand-placed polygons.
##
## Must be @tool; no test here may be a coroutine, so nothing calls play().

func suite_name() -> String:
	return "minigame_result_popup"


const POPUP_PATH := "res://Scenes/Minigames/UI/MinigameResultPopup.tscn"
const STAR_PATH := "res://Scenes/Minigames/UI/ResultStar.tscn"

## The style dictionary configure() takes, with neutral values.
const STYLE := {
	"card_texture": null, "card_color": Color.BLACK,
	"border_color": Color.WHITE, "dim_color": Color(0, 0, 0, 0.75),
	"star_texture": null, "star_empty_texture": null,
	"star_color": Color.YELLOW, "star_empty_color": Color.GRAY,
	"star_size": Vector2(88, 88),
	"button_texture": null, "button_color": Color.ORANGE,
	"button_text": "Lanjutkan",
	"title_font": null, "body_font": null,
	"title_font_size": 68, "score_font_size": 52, "stat_font_size": 34,
	"title_win_color": Color.YELLOW, "title_lose_color": Color.ORANGE,
	"win_title_text": "Kamu Berhasil! 🎉",
	"lose_title_text": "Belum Tepat, Coba Lagi Lain Kali!",
}


func _make() -> Node:
	var node: Node = load(POPUP_PATH).instantiate()
	track(node)
	return node


func test_both_scenes_exist() -> void:
	assert_true(ResourceLoader.exists(POPUP_PATH), "%s is missing" % POPUP_PATH)
	assert_true(ResourceLoader.exists(STAR_PATH), "%s is missing" % STAR_PATH)


func test_popup_scene_carries_every_node_the_script_binds() -> void:
	var node := _make()
	for path in ["Dim", "Center/Card/Margin/Layout/TitleLabel",
			"Center/Card/Margin/Layout/StarRow",
			"Center/Card/Margin/Layout/ScoreLabel",
			"Center/Card/Margin/Layout/SubtitleLabel",
			"Center/Card/Margin/Layout/ContinueButton"]:
		assert_not_null(node.get_node_or_null(path), "missing node: %s" % path)


func test_win_and_lose_pick_different_titles() -> void:
	var win := _make()
	win.configure(true, 3, 5, 5, "", STYLE)
	assert_eq(win.get_node("Center/Card/Margin/Layout/TitleLabel").text,
		STYLE["win_title_text"])
	var lose := _make()
	lose.configure(false, 0, 1, 5, "", STYLE)
	assert_eq(lose.get_node("Center/Card/Margin/Layout/TitleLabel").text,
		STYLE["lose_title_text"])


func test_star_row_holds_three_stars_and_fills_the_right_count() -> void:
	var node := _make()
	node.configure(true, 2, 4, 5, "", STYLE)
	var row: Node = node.get_node("Center/Card/Margin/Layout/StarRow")
	assert_eq(row.get_child_count(), 3, "the result card always shows three stars")
	var filled := 0
	for star in row.get_children():
		if star.is_filled:
			filled += 1
	assert_eq(filled, 2)


func test_score_readout_shows_score_over_max() -> void:
	var node := _make()
	node.configure(true, 3, 4, 5, "", STYLE)
	var text: String = node.get_node("Center/Card/Margin/Layout/ScoreLabel").text
	assert_contains(text, "4")
	assert_contains(text, "5")


func test_continue_button_emits_continued() -> void:
	var node := _make()
	assert_true(node.has_signal("continued"),
		"MinigameResultPopup needs a continued signal")


func test_base_minigame_no_longer_builds_the_result_card() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "MinigameResultPopup", "BaseMinigame should instantiate the scene")
	assert_false(src.contains("func _draw_star_polygon"),
		"star drawing moved to ResultStar.gd")


func test_star_calculation_stayed_on_base_minigame() -> void:
	# _calculate_stars is game logic, not presentation. Moving it into the
	# popup would put a rule in a view.
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "func _calculate_stars")
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="minigame_result_popup")
```

Expected: every test except `test_star_calculation_stayed_on_base_minigame`
FAILS.

- [ ] **Step 3: Author `ResultStar.tscn` and its script**

```
ResultStar   Control      custom_minimum_size = (88, 88), script = ResultStar.gd
└─ Icon      TextureRect  Full Rect, expand_mode = Ignore Size,
                          stretch_mode = Keep Aspect Centered
```

`ResultStar.gd` keeps a `var is_filled: bool` the tests read, applies the
filled/empty texture and colour in `set_filled()`, and falls back to `_draw()`
with the polygon moved verbatim from `BaseMinigame._draw_star_polygon()`
(lines 679-700) when both textures are null. Hide `Icon` in the polygon case.

- [ ] **Step 4: Author `MinigameResultPopup.tscn`**

```
MinigameResultPopup           CanvasLayer      layer = 400, script = …
├─ Dim                        ColorRect        Full Rect, mouse_filter = Stop
└─ Center                     CenterContainer  Full Rect
   └─ Card                    PanelContainer   theme_type_variation = "Card"
      └─ Margin               MarginContainer
         └─ Layout            VBoxContainer
            ├─ TitleLabel     Label            horizontal_alignment = Center,
            │                                  autowrap_mode = Word (Smart)
            ├─ StarRow        HBoxContainer    alignment = Center,
            │                                  three ResultStar instances
            ├─ ScoreLabel     Label            horizontal_alignment = Center
            ├─ SubtitleLabel  Label            horizontal_alignment = Center,
            │                                  autowrap_mode = Word (Smart)
            └─ ContinueButton Button           theme_type_variation = "PrimaryButton"
```

The three `ResultStar` instances are children **in the scene**, not spawned
in `configure()` — a fixed count is exactly the case where instancing in the
scene beats a loop.

Read lines 702-1041 for the spacing, the entrance animation and the order the
elements reveal in, and reproduce them. Do not redesign; this task is a move.

- [ ] **Step 5: Rewire `BaseMinigame`**

Replace `_show_result_overlay()`'s body with instantiate + configure +
`play()`, forwarding all 29 exports into the `style` dictionary. Delete
`_draw_star_polygon`. Keep `_calculate_stars` where it is. Add:

```gdscript
## The end-of-game result card. A minigame can override this to show its own.
@export var result_popup_scene: PackedScene = preload("res://Scenes/Minigames/UI/MinigameResultPopup.tscn")
```

- [ ] **Step 6: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="minigame_result_popup")
```

Expected: 8 tests PASS.

- [ ] **Step 7: Win and lose one game each**

Debug overlay → launch a minigame → win it, then launch again and lose it.
Both cards must render as before: correct title colour, correct star count,
correct score line, working continue button that returns to the calling
screen. Then check one more minigame, because all eight share this card.

- [ ] **Step 8: Update the ratchets and run everything**

`BaseMinigame.gd` should drop from 33 runtime constructions to a handful.

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both regenerated literals, rescan, `test_run()`.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Minigames/UI/MinigameResultPopup.tscn Scripts/Minigames/UI/MinigameResultPopup.gd Scenes/Minigames/UI/ResultStar.tscn Scripts/Minigames/UI/ResultStar.gd Scripts/Minigames/UI/BaseMinigame.gd tests/test_minigame_result_popup.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(minigames): extract the result card and stars to scenes"
```

---
## Phase 3 — Shop and inventory

The ported koperasi/inventory code styles itself entirely from GDScript: 29
`add_theme_*` calls in `inventory.gd`, 21 in `koprasi.gd`, and every grid slot
built node-by-node.

---

### Task 12: `InventorySlot.tscn`

`inventory.gd::_create_item_slot()` (lines 250-330) builds a `PanelContainer`,
two `StyleBoxFlat`s, a `VBoxContainer`, a `TextureRect`, an `HBoxContainer`, a
spacer and a `Label` for every item the player owns — once per item, every
time the category filter changes.

**Files:**
- Create: `Scenes/Inventory/InventorySlot.tscn`, `Scripts/Inventory/InventorySlot.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` — add `InventorySlot` and
  `InventorySlotSelected` variations
- Modify: `Scripts/Inventory/inventory.gd` — lines 250-330 (`_create_item_slot`),
  619-627 (`_show_empty_message`)
- Test: `tests/test_inventory_slot.gd`

**Interfaces:**
- Consumes: `ItemData` (`icon`, `category`, `item_name`), `AnimUtils.staggered_entrance`.
- Produces:
  - `class_name InventorySlot extends PanelContainer`
  - `signal slot_pressed(item: ItemData)`
  - `func setup(item: ItemData, quantity: int) -> void`
  - `func set_selected(selected: bool) -> void`
  - `var item: ItemData` — the slot's payload, read by `inventory.gd`
  - `ThemeFactory` variations `InventorySlot` / `InventorySlotSelected`, both
    `PanelContainer` variations with `radius_md` corners, a 4px left border and
    a 1px (normal) or 2px (selected) remaining border, both **white-bordered**
    so the category accent applies via `self_modulate` on a child
    `CategoryStripe` — the slot's per-item accent is the only value that
    cannot be baked.

- [ ] **Step 1: Write the failing test**

Create `tests/test_inventory_slot.gd`:

```gdscript
@tool
extends McpTestSuite

## One inventory grid slot, authored once as a scene instead of built
## node-by-node for every item on every category change.
##
## Affects nothing at runtime. Instantiates the slot scene, which is a handful
## of nodes. Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "inventory_slot"


const SCENE_PATH := "res://Scenes/Inventory/InventorySlot.tscn"


func _make() -> InventorySlot:
	var slot: InventorySlot = load(SCENE_PATH).instantiate()
	track(slot)
	return slot


func _sample_item() -> ItemData:
	var item := ItemData.new()
	track(item)
	item.item_name = "Buku Tulis"
	item.category = "School Supplies"
	return item


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var slot := _make()
	for path in ["Layout/Icon", "Layout/QuantityRow/QuantityLabel", "CategoryStripe"]:
		assert_not_null(slot.get_node_or_null(path), "missing node: %s" % path)


func test_setup_fills_the_icon_and_quantity() -> void:
	var slot := _make()
	var item := _sample_item()
	slot.setup(item, 7)
	assert_eq((slot.get_node("Layout/QuantityRow/QuantityLabel") as Label).text, "×7")
	assert_eq(slot.item, item)


func test_selection_swaps_the_theme_variation_not_a_stylebox() -> void:
	var slot := _make()
	slot.setup(_sample_item(), 1)
	assert_eq(slot.theme_type_variation, &"InventorySlot")
	slot.set_selected(true)
	assert_eq(slot.theme_type_variation, &"InventorySlotSelected")
	slot.set_selected(false)
	assert_eq(slot.theme_type_variation, &"InventorySlot")
	assert_false(slot.has_theme_stylebox_override("panel"),
		"selection must not build styleboxes at runtime")


func test_pressing_a_slot_emits_its_item() -> void:
	var slot := _make()
	assert_true(slot.has_signal("slot_pressed"), "InventorySlot needs slot_pressed")


func test_inventory_no_longer_builds_slots_or_styleboxes() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Inventory/inventory.gd")
	assert_contains(src, "InventorySlot", "inventory.gd should instantiate the scene")
	assert_false(src.contains("func _create_item_slot"),
		"_create_item_slot should be gone")
	assert_false(src.contains("slot_styles"),
		"the runtime stylebox cache is no longer needed")


func test_empty_message_is_a_scene_node_not_a_runtime_label() -> void:
	# The "inventory kosong" state is a permanent part of the screen, so it
	# belongs in inventory.tscn where a human can restyle it.
	var text := FileAccess.get_file_as_string("res://Scenes/Inventory/inventory.tscn")
	assert_contains(text, "EmptyMessageLabel",
		"inventory.tscn should carry the empty-state label")
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="inventory_slot")
```

Expected: every test FAILS.

- [ ] **Step 3: Add the two theme variations and rebake**

In `Scripts/Design/ThemeFactory.gd`, beside `Card` and `SunkenPanel`, add
`InventorySlot` and `InventorySlotSelected`. Copy the geometry from
`inventory.gd:259-286` — `radius 12` becomes `tokens.radius_md`, and the
`SLOT_BG` / `SLOT_SELECTED_BG` constants at the top of `inventory.gd` become
token lookups. Read the shipped constants and pick the nearest token; if none
matches within a hair, add the colour to `DesignTokens` rather than inlining it.

Rebake: File > Run (Ctrl+Shift+X) on `Scripts/Design/BakeTheme.gd`.

- [ ] **Step 4: Author the slot scene**

```
InventorySlot        PanelContainer  theme_type_variation = "InventorySlot",
                                     custom_minimum_size = (260, 340),
                                     size_flags_horizontal = Expand Fill,
                                     mouse_filter = Stop, script = InventorySlot.gd
├─ CategoryStripe    ColorRect       anchors preset Left Wide, width 4,
│                                    mouse_filter = Ignore
└─ Layout            VBoxContainer   separation = 6, mouse_filter = Ignore
   ├─ Icon           TextureRect     custom_minimum_size = (200, 260),
   │                                 expand_mode = Ignore Size,
   │                                 stretch_mode = Keep Aspect Centered,
   │                                 size_flags h/v = Expand Fill,
   │                                 mouse_filter = Ignore
   └─ QuantityRow    HBoxContainer   alignment = End, mouse_filter = Ignore
      └─ QuantityLabel Label         theme_type_variation = "BarLabel",
                                     mouse_filter = Ignore
```

`CategoryStripe` replaces the 4px left border the runtime stylebox drew, and
being a real node it takes the per-item accent through `color` — no stylebox
needed. `QuantityLabel` uses `BarLabel` (white glyph, dark rim), which is what
the shipped `GOLD` + shadow overrides were approximating; if the gold reads as
essential, add a `QuantityLabel` variation to `ThemeFactory` instead of
overriding.

The `HBoxContainer` `alignment = End` replaces the spacer `Control` the old
code inserted.

- [ ] **Step 5: Write the slot script**

`Scripts/Inventory/InventorySlot.gd`:

```gdscript
@tool
class_name InventorySlot
extends PanelContainer

## One item tile in the inventory grid.
##
## Instantiated by Scripts/Inventory/inventory.gd once per owned item. Before
## this scene existed, inventory.gd rebuilt eight nodes and two StyleBoxFlats
## per item on every category-filter change.
##
## Affects: nothing outside itself. It emits `slot_pressed` and lets the
## screen decide what that means; it never touches GameState or the Cart.

## Emitted when the player taps this tile. Carries the tile's own item so the
## screen does not have to map node back to data.
signal slot_pressed(pressed_item: ItemData)

## Accent colour per item category, applied to the left stripe. Exposed so a
## new category can be given a colour without editing code.
@export var category_colors: Dictionary = {}
## The stripe colour for a category not listed above.
@export var default_category_color: Color = Color(0.6, 0.6, 0.65)

@onready var stripe: ColorRect = $CategoryStripe
@onready var icon: TextureRect = $Layout/Icon
@onready var quantity_label: Label = $Layout/QuantityRow/QuantityLabel

## The item this tile shows. Read by inventory.gd when the tile is tapped.
var item: ItemData = null


func _ready() -> void:
	theme_type_variation = &"InventorySlot"
	gui_input.connect(_on_gui_input)


## Fill the tile from one owned item.
##
## Affects: this tile's icon, quantity text, stripe colour and `item`. Nothing
## else. Safe to call again to re-use a pooled tile.
func setup(p_item: ItemData, quantity: int) -> void:
	item = p_item
	icon.texture = p_item.icon
	quantity_label.text = "×%d" % quantity
	stripe.color = category_colors.get(p_item.category, default_category_color)


## Swap between the resting and selected look.
##
## Affects: this tile's theme variation only. Both looks are baked into the
## theme, so nothing is constructed here.
func set_selected(selected: bool) -> void:
	theme_type_variation = &"InventorySlotSelected" if selected else &"InventorySlot"


func _on_gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed and item != null:
		slot_pressed.emit(item)
```

- [ ] **Step 6: Rewire `inventory.gd`**

Replace `_create_item_slot` with:

```gdscript
## The scene one grid tile is authored in.
@export var slot_scene: PackedScene = preload("res://Scenes/Inventory/InventorySlot.tscn")

## Add one tile to the grid for an owned item.
##
## Affects: adds a child to `grid` and starts its staggered entrance. The
## tile owns its own look; this function only supplies data and wiring.
func _create_item_slot(item: ItemData, quantity: int, slot_index: int = 0) -> void:
	var slot: InventorySlot = slot_scene.instantiate()
	slot.category_colors = CATEGORY_COLORS
	slot.default_category_color = DEFAULT_CATEGORY_COLOR
	grid.add_child(slot)
	slot.setup(item, quantity)
	slot.slot_pressed.connect(_on_slot_pressed)
	AnimUtils.staggered_entrance(slot, slot_index * 0.06)
```

Adapt `_on_slot_input(slot, item)` into `_on_slot_pressed(item)` — it no
longer needs the node, because selection is now `slot.set_selected(…)` on
whichever tile the screen tracks. Delete the `slot_styles` dictionary.

For `_show_empty_message()` (lines 619-627): add an `EmptyMessageLabel` to
`Scenes/Inventory/inventory.tscn` (a `Label`, `CaptionLabel` variation,
centered, `visible = false`) and have the function set its `text` and
`visible` instead of building one.

- [ ] **Step 7: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="inventory_slot")
test_run(suite="inventory")
```

Expected: both green.

- [ ] **Step 8: Verify it visually, once**

Seed Playtest State fills the inventory. Teleport to the Lobby, open
Inventory. Check: tiles render with icons and `×N` badges, the category
stripe colours match, tapping selects, the category filter still works, and
an empty category shows the empty message. One screenshot.

- [ ] **Step 9: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both literals, rescan, `test_run()`.

- [ ] **Step 10: Commit**

```bash
git add Scenes/Inventory/InventorySlot.tscn Scripts/Inventory/InventorySlot.gd Scenes/Inventory/inventory.tscn Scripts/Inventory/inventory.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_inventory_slot.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(inventory): author the grid slot as a scene"
```

---

### Task 13: Koperasi — the coin HUD and message belong in the scene

`koprasi.gd::_setup_coin_display()` (lines 46-73) builds an `HBoxContainer`, a
`TextureRect` and a `Label` at a hardcoded `Vector2(20, 20)`, loads the coin
art by path, and applies six theme overrides.
`_setup_message_label()` (lines 75-90) builds another label at
`vp.y * 0.47`. Both are permanent chrome — Pattern A.

**Files:**
- Modify: `Scenes/Koperasi/koprasi.tscn`
- Modify: `Scripts/Koperasi/koprasi.gd` — lines 46-90, plus
  `_setup_main_buttons` (91-110+) where it builds button styleboxes
- Modify: `Scripts/Design/ThemeFactory.gd` — add a `CoinLabel` variation
- Test: `tests/test_koperasi.gd` (extend the existing suite)

**Interfaces:**
- Consumes: `DesignTokens.currency_gold`.
- Produces: `Scenes/Koperasi/koprasi.tscn` nodes `CoinHUD`, `CoinHUD/CoinIcon`,
  `CoinHUD/CoinLabel`, `MessageLabel`; `ThemeFactory` variation `CoinLabel`
  (gold font from `tokens.currency_gold`, black shadow at offset 2/2).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi.gd`:

```gdscript
func test_coin_hud_and_message_live_in_the_scene() -> void:
	# Permanent chrome. Building it in _ready() meant a human could not move
	# the coin counter without editing a Vector2 literal in GDScript.
	var text := FileAccess.get_file_as_string("res://Scenes/Koperasi/koprasi.tscn")
	for node_name in ["CoinHUD", "CoinIcon", "CoinLabel", "MessageLabel"]:
		assert_contains(text, node_name, "koprasi.tscn is missing %s" % node_name)


func test_koperasi_builds_no_chrome_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/koprasi.gd")
	assert_false(src.contains("HBoxContainer.new("), "coin HUD should be a scene node")
	assert_false(src.contains("Label.new("), "labels should be scene nodes")
	assert_false(src.contains("StyleBoxFlat.new("),
		"button styling belongs in a ThemeFactory variation")
	assert_false(src.contains('load("res://Assets/Images/Shop/Koin.png")'),
		"the coin art should be assigned in the scene")


func test_coin_label_uses_the_theme_variation() -> void:
	var text := FileAccess.get_file_as_string("res://Scenes/Koperasi/koprasi.tscn")
	assert_contains(text, 'theme_type_variation = &"CoinLabel"')
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="koperasi")
```

Expected: the three new tests FAIL.

- [ ] **Step 3: Add the `CoinLabel` variation and rebake**

In `ThemeFactory.gd`, beside the other label variations (around line 187), add
`CoinLabel` as a `Label` variation with `font_size` 40, `font_color` =
`tokens.currency_gold`, `font_shadow_color` = black, `shadow_offset_x/y` = 2.
Rebake.

- [ ] **Step 4: Author the nodes in `koprasi.tscn`**

```
CoinHUD          HBoxContainer  position = (20, 20), separation = 10, z_index = 10
├─ CoinIcon      TextureRect    texture = res://Assets/Images/Shop/Koin.png,
│                               custom_minimum_size = (60, 60),
│                               expand_mode = Ignore Size,
│                               stretch_mode = Keep Aspect Centered
└─ CoinLabel     Label          theme_type_variation = "CoinLabel",
                                vertical_alignment = Center

MessageLabel     Label          anchors preset Center Wide (anchor_top = 0.47),
                                horizontal_alignment = Center,
                                theme_type_variation = "H2Label",
                                z_index = 20, text = ""
```

The message label's old `position.y = vp.y * 0.47` becomes `anchor_top = 0.47`
— an anchor is the scene-native way to say the same thing, and it stays
correct as viewport height varies.

- [ ] **Step 5: Simplify the script**

Delete `_setup_coin_display()` and `_setup_message_label()` entirely. Replace
the `coin_container` / `coin_label` / `message_label` variables with:

```gdscript
@onready var coin_label: Label = $CoinHUD/CoinLabel
@onready var message_label: Label = $MessageLabel
```

For `_setup_main_buttons()`: move the button styling to a `ThemeFactory`
variation too (`ShopShelfButton`, a `Button` variation using
`tokens.brand_primary` and `tokens.radius_md`) and set
`theme_type_variation` on the two buttons in the scene. Keep the idle-pulse
animation — that is behaviour, not styling.

- [ ] **Step 6: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="koperasi")
test_run(suite="theme_factory")
```

Expected: green.

- [ ] **Step 7: Verify it visually, once**

Seed, teleport to Lobby, open Koperasi. The coin counter must sit where it
did, in the same gold with the same shadow; a purchase message must still
appear at the same height. One screenshot.

- [ ] **Step 8: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both literals, rescan, `test_run()`.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Koperasi/koprasi.tscn Scripts/Koperasi/koprasi.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_koperasi.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(koperasi): move the coin HUD and message into the scene"
```

---

### Task 14: `RakBarangPopup.tscn`

`rakbarang_1.gd` builds a blur `CanvasLayer` with a `ShaderMaterial`, an input
blocker, a popup `CanvasLayer`, a container and a duplicated `TextureRect`
(lines 117-190). The shelf item detail is the screen's main interaction and
none of it can be opened in the editor.

**Files:**
- Create: `Scenes/Koperasi/RakBarangPopup.tscn`, `Scripts/Koperasi/RakBarangPopup.gd`
- Modify: `Scripts/Koperasi/rakbarang_1.gd` — lines 110-200
- Test: `tests/test_rakbarang_popup.gd`

**Interfaces:**
- Consumes: `ItemData`, `Cart` (autoload), `AudioDirector`.
- Produces:
  - `class_name RakBarangPopup extends CanvasLayer`
  - `signal add_to_cart_pressed(item: ItemData)`, `signal closed`
  - `func configure(item: ItemData) -> void`, `func open() -> void`,
    `func close() -> void`
  - The blur shader lives on a `BlurRect` node in the scene with its
    `ShaderMaterial` assigned there, not built in `_ready()`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_rakbarang_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## The koperasi shelf's item-detail popup, extracted from rakbarang_1.gd.
##
## The blur is the interesting part: it was a ShaderMaterial built in _ready()
## and attached to a runtime ColorRect, so nobody could see or tune it in the
## editor. It is now a node with its material assigned in the scene.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "rakbarang_popup"


const SCENE_PATH := "res://Scenes/Koperasi/RakBarangPopup.tscn"


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var node: Node = load(SCENE_PATH).instantiate()
	track(node)
	for path in ["BlurRect", "InputBlocker", "Content/ItemImage"]:
		assert_not_null(node.get_node_or_null(path), "missing node: %s" % path)


func test_the_blur_material_is_assigned_in_the_scene() -> void:
	var node: Node = load(SCENE_PATH).instantiate()
	track(node)
	var blur := node.get_node("BlurRect") as ColorRect
	assert_not_null(blur.material,
		"the blur ShaderMaterial should be scene data, not built in _ready()")


func test_popup_emits_its_two_signals() -> void:
	var node: Node = load(SCENE_PATH).instantiate()
	track(node)
	assert_true(node.has_signal("add_to_cart_pressed"))
	assert_true(node.has_signal("closed"))


func test_rakbarang_no_longer_builds_the_popup() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/rakbarang_1.gd")
	assert_contains(src, "RakBarangPopup", "rakbarang_1.gd should instantiate the scene")
	assert_false(src.contains("ShaderMaterial.new("),
		"the blur material belongs in the scene")
	assert_false(src.contains("CanvasLayer.new("),
		"rakbarang_1.gd still builds layers at runtime")
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="rakbarang_popup")
```

Expected: all four FAIL.

- [ ] **Step 3: Author the scene**

```
RakBarangPopup     CanvasLayer  layer per rakbarang_1.gd:145, script = …
├─ BlurRect        ColorRect    Full Rect, material = the shipped blur
│                               ShaderMaterial (save it as a .tres beside the
│                               scene and assign it here)
├─ InputBlocker    ColorRect    Full Rect, mouse_filter = Stop,
│                               color transparent
└─ Content         Control      Full Rect
   └─ ItemImage    TextureRect  centered, expand_mode = Ignore Size,
                                stretch_mode = Keep Aspect Centered
```

Read `rakbarang_1.gd:117-190` for the exact layer numbers, the blur shader
resource path and the `duplikat` TextureRect's placement, and reproduce them.
The shader currently comes from a conditional — if the shader file is missing
the code skips the material. In the scene, assign it directly; if the file
does not exist, that is a bug to report, not to paper over.

- [ ] **Step 4: Write the popup script and rewire the shelf**

`Scripts/Koperasi/RakBarangPopup.gd` follows the same shape as
`StatDetailPopup.gd`: `@onready` bindings, `configure(item)`, `open()`,
`close()`, two signals, a full doc header saying it affects nothing but its
own nodes and the Cart via the screen.

In `rakbarang_1.gd`, replace the construction block with instantiate +
configure + connect + open, held behind:

```gdscript
## The shelf's item-detail popup.
@export var popup_scene: PackedScene = preload("res://Scenes/Koperasi/RakBarangPopup.tscn")
```

- [ ] **Step 5: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="rakbarang_popup")
test_run(suite="koperasi")
```

Expected: green.

- [ ] **Step 6: Verify the whole purchase flow once**

Seed, Lobby → Koperasi → a shelf → tap an item. The blur must appear, the
item image must show, adding to the cart must work, and closing must restore
input. Do the full buy so the money actually moves — this is the flow the
project guide warns takes forty-five calls to drive by simulated clicks, so
do it by hand once rather than scripting it.

- [ ] **Step 7: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both literals, rescan, `test_run()`.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Koperasi/RakBarangPopup.tscn Scripts/Koperasi/RakBarangPopup.gd Scripts/Koperasi/rakbarang_1.gd tests/test_rakbarang_popup.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(koperasi): extract the shelf item popup to a scene"
```

---

## Phase 4 — School simulation

`SchoolDay.gd`, `DailyDecayOverview.gd` and `EventStudentSelectDialog.gd` each
build the same shape by hand: a student card with a name, and rows of
icon + `StatBar` + info label. Extracting that pair serves all three.

---

### Task 15: `StudentStatRow.tscn` — the row all three screens rebuild

`SchoolDay.gd:496-535`, `DailyDecayOverview.gd:208-235` and the equivalent in
`EventStudentSelectDialog.gd` each construct an `HBoxContainer`, a
`TextureRect` (or emoji `Label` fallback), a `StatBar` and an info `Label`.

**Files:**
- Create: `Scenes/SchoolSimulation/StudentStatRow.tscn`,
  `Scripts/SchoolSimulation/StudentStatRow.gd`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — lines 496-535
- Modify: `Scripts/SchoolSimulation/DailyDecayOverview.gd` — lines 208-235
- Test: `tests/test_student_stat_row.gd`

**Interfaces:**
- Consumes: `StatBar` (`category`, `max_value`, `set_stat`), `StatInfo`
  (Task 4) for the icon glyph and token category.
- Produces:
  - `class_name StudentStatRow extends HBoxContainer`
  - `func setup(bar_name: String, value: float, info_text: String,
    icon: Texture2D) -> void`
  - `func animate_to(value: float) -> void` — forwards to
    `StatBar.set_stat(value, true)`
  - nodes `Icon` (TextureRect), `Glyph` (Label), `Bar` (StatBar),
    `InfoLabel` (Label)

- [ ] **Step 1: Write the failing test**

Create `tests/test_student_stat_row.gd`:

```gdscript
@tool
extends McpTestSuite

## One "icon + bar + number" row. SchoolDay, DailyDecayOverview and
## EventStudentSelectDialog each built their own copy of this four-node
## structure, so a change to the row shape meant three edits and the three had
## already drifted.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "student_stat_row"


const SCENE_PATH := "res://Scenes/SchoolSimulation/StudentStatRow.tscn"


func _make() -> StudentStatRow:
	var row: StudentStatRow = load(SCENE_PATH).instantiate()
	track(row)
	return row


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var row := _make()
	for path in ["Icon", "Glyph", "Bar", "InfoLabel"]:
		assert_not_null(row.get_node_or_null(path), "missing node: %s" % path)


func test_setup_fills_the_bar_and_the_info_text() -> void:
	var row := _make()
	row.setup("Akademis1", 47.0, "47 / 100", null)
	assert_eq((row.get_node("Bar") as StatBar).value, 47.0)
	assert_eq((row.get_node("InfoLabel") as Label).text, "47 / 100")


func test_setup_tints_the_bar_from_stat_info() -> void:
	var row := _make()
	row.setup("Akademis3", 10.0, "", null)
	assert_eq((row.get_node("Bar") as StatBar).category, "Olahraga")


func test_icon_and_glyph_are_mutually_exclusive() -> void:
	var with_glyph := _make()
	with_glyph.setup("Kepribadian2", 30.0, "", null)
	assert_false((with_glyph.get_node("Icon") as TextureRect).visible)
	assert_true((with_glyph.get_node("Glyph") as Label).visible)
	assert_eq((with_glyph.get_node("Glyph") as Label).text, "⚡")


func test_all_three_screens_use_the_shared_row() -> void:
	for path in ["res://Scripts/SchoolSimulation/SchoolDay.gd",
			"res://Scripts/SchoolSimulation/DailyDecayOverview.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "StudentStatRow", "%s should use the shared row" % path)
		assert_false(src.contains("StatBar.new("),
			"%s still builds a bar by hand" % path)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="student_stat_row")
```

Expected: all five FAIL.

- [ ] **Step 3: Author the scene**

```
StudentStatRow   HBoxContainer  separation per SchoolDay.gd:497, script = …
├─ Icon          TextureRect    custom_minimum_size per SchoolDay.gd:504,
│                               expand_mode = Ignore Size,
│                               stretch_mode = Keep Aspect Centered
├─ Glyph         Label          theme_type_variation = "H2Label",
│                               vertical_alignment = Center
├─ Bar           StatBar        size_flags_horizontal = Expand Fill
└─ InfoLabel     Label          theme_type_variation = "CaptionLabel"
```

Read the three shipped versions before fixing the numbers; where they differ,
take SchoolDay's (it is the one the player sees most) and note the deviation
in the commit message so the difference is not silently lost.

- [ ] **Step 4: Write the row script and rewire both screens**

`Scripts/SchoolSimulation/StudentStatRow.gd` mirrors `InventorySlot.gd`'s
shape: `@tool`, a doc header naming its three callers, `@onready` bindings,
`setup()` and `animate_to()` each with a `##` line saying what they affect.

In `SchoolDay.gd` and `DailyDecayOverview.gd`, replace the row builders with
instantiate + `setup()`, held behind an exported `PackedScene` as in the
earlier tasks.

- [ ] **Step 5: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="student_stat_row")
test_run(suite="school_day")
test_run(suite="day_summary")
```

Expected: green.

- [ ] **Step 6: Verify it visually, once**

SchoolDay needs a filled schedule, which Seed Playtest State does **not**
provide. Seed, then go through Atur Jadwal once to assign a week, then run
SchoolDay. Check the day summary rows and the daily decay overview: same
icons, same bar colours, same numbers, same fill animation. One screenshot of
each.

- [ ] **Step 7: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both literals, rescan, `test_run()`.

- [ ] **Step 8: Commit**

```bash
git add Scenes/SchoolSimulation/StudentStatRow.tscn Scripts/SchoolSimulation/StudentStatRow.gd Scripts/SchoolSimulation/SchoolDay.gd Scripts/SchoolSimulation/DailyDecayOverview.gd tests/test_student_stat_row.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(school-sim): share one StudentStatRow scene across three screens"
```

---

### Task 16: `TutorialPanel.tscn` — the coach-mark both screens rebuild

`student_card.gd:278-330` and `SchoolDay.gd:1294-1346` build the same
panel — title label, separator, body label, separator, prompt label — with
drifted numbers: StudentCard clamps its width to
`min(vp.x * 0.92, 1000)` and SchoolDay to `min(vp.x * 0.85, 900)`, and
SchoolDay wraps the contents in a 30px `MarginContainer` that StudentCard
does not have.

**Preserve both.** The width becomes an export each screen sets to its own
value; the margin becomes an export defaulting to StudentCard's zero and set
to 30 by SchoolDay. Unifying them is a visual change, which this plan does
not authorise — flag the drift in the commit message and leave the decision to
the user.

**Files:**
- Create: `Scenes/UI/TutorialPanel.tscn`, `Scripts/UI/TutorialPanel.gd`
- Modify: `Scripts/StudentCard/student_card.gd` — lines 278-330
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — lines 1282-1346
- Test: `tests/test_tutorial_panel.gd`

**Interfaces:**
- Consumes: `TutorialStepData` (already defined in `student_card.gd`),
  `DesignTokens`.
- Produces:
  - `class_name TutorialPanel extends PanelContainer`
  - `@export var width_fraction: float`, `@export var max_width: float`,
    `@export var content_margin: int`
  - `func show_step(title: String, body: String, prompt: String) -> void`
  - nodes `Margin/Layout/TitleLabel`, `Margin/Layout/BodyLabel`,
    `Margin/Layout/PromptLabel`, plus the two `HSeparator`s.

- [ ] **Step 1: Write the failing test**

Create `tests/test_tutorial_panel.gd`:

```gdscript
@tool
extends McpTestSuite

## The onboarding coach-mark. student_card.gd and SchoolDay.gd each built it,
## and the two copies had already drifted: 0.92/1000 versus 0.85/900 on the
## width clamp, and a 30px content margin on one side only.
##
## The scene keeps both behaviours available as exports rather than picking a
## winner -- unifying them would change what the player sees, which is out of
## scope for the extraction.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "tutorial_panel"


const SCENE_PATH := "res://Scenes/UI/TutorialPanel.tscn"


func _make() -> TutorialPanel:
	var panel: TutorialPanel = load(SCENE_PATH).instantiate()
	track(panel)
	return panel


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var panel := _make()
	for path in ["Margin/Layout/TitleLabel", "Margin/Layout/BodyLabel",
			"Margin/Layout/PromptLabel"]:
		assert_not_null(panel.get_node_or_null(path), "missing node: %s" % path)


func test_show_step_fills_all_three_labels() -> void:
	var panel := _make()
	panel.show_step("Judul", "Isi penjelasan.", "Ketuk untuk lanjut")
	assert_eq(panel.get_node("Margin/Layout/TitleLabel").text, "Judul")
	assert_eq(panel.get_node("Margin/Layout/BodyLabel").text, "Isi penjelasan.")
	assert_eq(panel.get_node("Margin/Layout/PromptLabel").text, "Ketuk untuk lanjut")


func test_width_and_margin_are_exports_so_both_screens_keep_their_look() -> void:
	var panel := _make()
	for prop in ["width_fraction", "max_width", "content_margin"]:
		assert_true(prop in panel, "TutorialPanel needs an exported %s" % prop)


func test_each_screen_still_sets_its_own_shipped_numbers() -> void:
	var card := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	assert_contains(card, "0.92", "StudentCard's width fraction was lost")
	assert_contains(card, "1000", "StudentCard's max width was lost")
	var day := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_contains(day, "0.85", "SchoolDay's width fraction was lost")
	assert_contains(day, "900", "SchoolDay's max width was lost")


func test_neither_screen_builds_the_panel_by_hand() -> void:
	for path in ["res://Scripts/StudentCard/student_card.gd",
			"res://Scripts/SchoolSimulation/SchoolDay.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "TutorialPanel", "%s should instantiate the scene" % path)
		assert_false(src.contains("HSeparator.new("),
			"%s still builds the panel's separators" % path)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="tutorial_panel")
```

Expected: all five FAIL.

- [ ] **Step 3: Author the scene**

```
TutorialPanel        PanelContainer  theme_type_variation = "Card",
                                     mouse_filter = Ignore, script = …
└─ Margin            MarginContainer  margin_* = 0 (set by content_margin)
   └─ Layout         VBoxContainer
      ├─ TitleLabel  Label            theme_type_variation = "H2Label",
      │                               autowrap_mode = Word (Smart)
      ├─ Separator1  HSeparator
      ├─ BodyLabel   Label            theme_type_variation = "TitleLabel",
      │                               autowrap_mode = Word (Smart)
      ├─ Separator2  HSeparator
      └─ PromptLabel Label            theme_type_variation = "CaptionLabel",
                                      horizontal_alignment = Center
```

Read both shipped builders for the label variations before fixing them — the
comment at `student_card.gd:284-288` records a deliberate earlier decision to
put the panel on the `Card` surface; keep that.

- [ ] **Step 4: Write the script and rewire both screens**

`Scripts/UI/TutorialPanel.gd` with the three exports (each with a `##` line),
a `_apply_geometry()` that clamps the width and pushes `content_margin` into
the `MarginContainer`'s four constants, and `show_step()`. Call
`_apply_geometry()` from `_ready()` and from each export's setter, so the
panel previews correctly in the viewport.

In each caller, instantiate the scene, set `width_fraction` / `max_width` /
`content_margin` to that screen's shipped numbers, and replace the
`_tutorial_title_label` / `_tutorial_body_label` / `_tutorial_prompt_label`
variables with a single `_tutorial_panel: TutorialPanel` and calls to
`show_step()`.

SchoolDay also builds a dimming `Panel` overlay at line 1282 — add that to
the scene as a `Scrim` sibling with `visible = false`, exposed as
`@export var show_scrim: bool = false`, so StudentCard keeps its
scrim-less look.

- [ ] **Step 5: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="tutorial_panel")
test_run(suite="student_card")
test_run(suite="school_day")
```

Expected: green.

- [ ] **Step 6: Verify both tutorials once**

The lobby tutorial flag is bypassed by Seed Playtest State, so to see the
StudentCard onboarding you need an unseeded run: start from MainMenu, go
through the cutscene to StudentCard, and step the tutorial. Then seed, assign
a week, and run SchoolDay to see its tutorial. Both must match their shipped
widths and margins. One screenshot each, side by side with the pre-change
screenshots if you took them.

- [ ] **Step 7: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both literals, rescan, `test_run()`.

- [ ] **Step 8: Commit**

Mention the drift in the message so the difference stays on the record:

```bash
git add Scenes/UI/TutorialPanel.tscn Scripts/UI/TutorialPanel.gd Scripts/StudentCard/student_card.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_tutorial_panel.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(ui): share one TutorialPanel scene, preserving each screen's width"
```

---

### Task 17: The remaining school-sim cards

`SchoolDay.gd:405-470` (the per-student summary card),
`DailyDecayOverview.gd:129-200` (its card) and
`EventStudentSelectDialog.gd:109-240` (its card and buttons) are the last
large runtime builders outside the exempt debug overlay.

**Files:**
- Create: `Scenes/SchoolSimulation/StudentSummaryCard.tscn`,
  `Scripts/SchoolSimulation/StudentSummaryCard.gd`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — lines 405-470, 560-660
- Modify: `Scripts/SchoolSimulation/DailyDecayOverview.gd` — lines 85-205
- Modify: `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` — lines 105-240
- Test: `tests/test_student_summary_card.gd`

**Interfaces:**
- Consumes: `StudentStatRow` (Task 15) — the card holds a `Rows` container and
  instantiates rows into it; `StatInfo` (Task 4).
- Produces:
  - `class_name StudentSummaryCard extends PanelContainer`
  - `func setup(student_name: String, portrait: Texture2D, subtitle: String) -> void`
  - `func add_stat_row(bar_name: String, value: float, info_text: String,
    icon: Texture2D) -> StudentStatRow`
  - `func clear_rows() -> void`
  - nodes `Margin/Layout/Header/Portrait`, `Margin/Layout/Header/Titles/NameLabel`,
    `Margin/Layout/Header/Titles/SubtitleLabel`, `Margin/Layout/Rows`

- [ ] **Step 1: Write the failing test**

Create `tests/test_student_summary_card.gd`:

```gdscript
@tool
extends McpTestSuite

## The per-student card three school-sim screens each rebuilt: SchoolDay's day
## summary, DailyDecayOverview's decay readout, and the event student picker.
##
## The card owns its chrome; rows come from StudentStatRow, so the two scenes
## compose rather than duplicating each other.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "student_summary_card"


const SCENE_PATH := "res://Scenes/SchoolSimulation/StudentSummaryCard.tscn"


func _make() -> StudentSummaryCard:
	var card: StudentSummaryCard = load(SCENE_PATH).instantiate()
	track(card)
	return card


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var card := _make()
	for path in ["Margin/Layout/Header/Portrait",
			"Margin/Layout/Header/Titles/NameLabel",
			"Margin/Layout/Header/Titles/SubtitleLabel",
			"Margin/Layout/Rows"]:
		assert_not_null(card.get_node_or_null(path), "missing node: %s" % path)


func test_setup_fills_the_header() -> void:
	var card := _make()
	card.setup("Budi", null, "Akademis")
	assert_eq(card.get_node("Margin/Layout/Header/Titles/NameLabel").text, "Budi")
	assert_eq(card.get_node("Margin/Layout/Header/Titles/SubtitleLabel").text, "Akademis")


func test_rows_are_added_and_cleared() -> void:
	var card := _make()
	card.setup("Budi", null, "")
	card.add_stat_row("Akademis1", 40.0, "40 / 100", null)
	card.add_stat_row("Akademis2", 50.0, "50 / 100", null)
	assert_eq(card.get_node("Margin/Layout/Rows").get_child_count(), 2)
	card.clear_rows()
	assert_eq(card.get_node("Margin/Layout/Rows").get_child_count(), 0)


func test_rows_are_the_shared_row_scene() -> void:
	var card := _make()
	card.setup("Budi", null, "")
	var row := card.add_stat_row("Akademis3", 30.0, "", null)
	assert_true(row is StudentStatRow, "the card must compose StudentStatRow")


func test_all_three_screens_use_the_shared_card() -> void:
	for path in ["res://Scripts/SchoolSimulation/SchoolDay.gd",
			"res://Scripts/SchoolSimulation/DailyDecayOverview.gd",
			"res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "StudentSummaryCard", "%s should use the shared card" % path)
		assert_false(src.contains("PanelContainer.new("),
			"%s still builds a card by hand" % path)
```

- [ ] **Step 2: Run test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="student_summary_card")
```

Expected: all five FAIL.

- [ ] **Step 3: Author the scene**

```
StudentSummaryCard      PanelContainer  theme_type_variation = "Card", script = …
└─ Margin               MarginContainer  margins per SchoolDay.gd:422-428
   └─ Layout            VBoxContainer
      ├─ Header         HBoxContainer
      │  ├─ Portrait    TextureRect      expand_mode = Ignore Size,
      │  │                               stretch_mode = Keep Aspect Centered
      │  └─ Titles      VBoxContainer    size_flags_horizontal = Expand Fill
      │     ├─ NameLabel     Label       theme_type_variation = "H2Label"
      │     └─ SubtitleLabel Label       theme_type_variation = "CaptionLabel"
      └─ Rows           VBoxContainer
```

The shipped `SchoolDay.gd:412` builds a `StyleBoxTexture` when a card texture
is supplied. If that texture is an `@export`, keep the branch in `setup()` and
document why (same reasoning as the quit dialog in Task 10); if it is a
hardcoded path, move it to an `@export` on the card and assign it in the scene.

- [ ] **Step 4: Write the script and rewire all three screens**

`Scripts/SchoolSimulation/StudentSummaryCard.gd` — `@tool`, doc header naming
its three callers, `@onready` bindings, and the three methods each with a `##`
line saying what they affect.

Rewire the three screens one at a time, running `test_run()` after each, so a
break is attributable. `EventStudentSelectDialog.gd` also builds two buttons
with `StyleBoxTexture`s (lines 142-176); those buttons are permanent chrome —
put them in `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn` and give
them theme variations.

- [ ] **Step 5: Run test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="student_summary_card")
test_run(suite="school_day")
test_run(suite="day_summary")
test_run(suite="result_checkup")
```

Expected: green.

- [ ] **Step 6: Verify all three surfaces once**

Seed, assign a week through Atur Jadwal, run SchoolDay through to a
ResultCheckup. Confirm: the day-summary cards, the daily decay overview and
an event student-select dialog all render as before. Random events do not
fire on demand — use the debug overlay's event trigger if it has one, or run
two weeks. One screenshot of each surface.

- [ ] **Step 7: Update the ratchets and run everything**

```
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
```

Paste both literals, rescan, `test_run()`. At this point every non-exempt
script's `BASELINE` entry should be small or absent.

- [ ] **Step 8: Commit**

```bash
git add Scenes/SchoolSimulation/StudentSummaryCard.tscn Scripts/SchoolSimulation/StudentSummaryCard.gd Scenes/SchoolSimulation/EventStudentSelectDialog.tscn Scripts/SchoolSimulation/SchoolDay.gd Scripts/SchoolSimulation/DailyDecayOverview.gd Scripts/SchoolSimulation/EventStudentSelectDialog.gd tests/test_student_summary_card.gd tests/test_viewport_editability.gd tests/test_script_documentation.gd && git commit -m "refactor(school-sim): share one StudentSummaryCard scene across three screens"
```

---
## Phase 5 — The documentation sweep

The second half of the request: every script says what it does and what it
affects. Measured on 2026-08-31, that means **21 missing file headers** (22
minus the exempt `DebugManager.gd`) and roughly **370 undocumented `@export`s**
across 35 files.

Three waves, grouped so each wave is one coherent reading session. Each wave
lands the file headers *and* the `@export` doc lines for its group, then
lowers both `PENDING_*` lists. A wave is not "add comments" — it is a read of
each file until you can state what it affects, which is the only thing that
makes the sentence worth writing.

**The standard, restated so the executor does not have to go find it:**

1. **File header** — a `##` block in the first 12 lines: what this file is,
   who drives it, and what it affects elsewhere. Where it mutates `GameState`,
   name the keys.
2. **Every `@export`** gets a `##` line immediately above it. Godot shows that
   text as the Inspector tooltip.
3. **Every function that is not a one-line accessor** gets a `##` line saying
   what it does *and what it affects* — the node it mutates, the autoload it
   writes, the signal it emits.
4. **Section banners** (`# ─── Name ───`) group related members.

Rules 1 and 2 are tested. Rules 3 and 4 are review-time; do them anyway, they
are the half that actually helps a reader.

**What not to write.** `## The player's money.` above `@export var money: int`
restates the name and helps nobody. `## Rupiah the player can spend in
Koperasi. Paid out from pending_earnings at week end, not during the week.`
tells a reader something they could not have guessed. If the honest sentence
is just the variable name, the variable is well named and the useful sentence
is about its *effect* instead.

---

### Task 18: Document the autoloads and core systems

These are the files everything else reads. Documenting them first makes the
next two waves faster.

**Files (headers where missing, `##` on every `@export` in all of them):**
- `Scripts/GameState.gd` — header
- `Scripts/Inventory/Cart.gd` — header
- `Scripts/Inventory/ItemData.gd` — header + 9 exports
- `Scripts/Inventory/ItemDatabase.gd` — header
- `Scripts/SchoolSimulation/StudentData.gd` — header + 20 exports
- `Scripts/SchoolSimulation/StudentManager.gd` — header
- `Scripts/TouchFeedback/TouchFeedbackEffect.gd` — header
- `Scripts/TouchFeedback/TouchFeedbackManager.gd` — header
- `Scripts/TutorialArrow.gd` — header
- `Scripts/Pengaturan.gd` — header
- `Scripts/Design/DesignTokens.gd` — 60 exports
- `Scripts/Audio/AudioDirector.gd` — 26 exports
- `Scripts/UI/UIPolish.gd` — 1 export
- `Scripts/UI/StatBar.gd` — 1 export
- `Scripts/Transition/transition.gd` — 1 export
- Test: `tests/test_script_documentation.gd` (lower both lists)

**Interfaces:**
- Consumes: the ratchet from Task 2.
- Produces: no API change. Documentation only — if a signature changes, that
  is a different task and should be raised, not smuggled in here.

- [ ] **Step 1: Confirm the current failure surface**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
```

Expected: PASS — the ratchet is satisfied by the `PENDING_*` lists. Note the
entries for the 15 files above; those are what this task empties.

- [ ] **Step 2: Write the file headers**

For each of the 10 files needing one, read it first, then write a header that
answers three questions. Worked example for `Scripts/GameState.gd`, the most
important one in the project:

```gdscript
## The source of truth for a run.
##
## An autoload. Everything the player does between the main menu and the
## semester end lands here: the approved roster, the week's schedules, the
## current week and grade, money, and the inventory. There is deliberately no
## save system -- a run is session-scoped, and adding persistence here is a
## design change, not a refactor.
##
## Written by: student_card.gd (approves the roster into `approved_students`),
## atur_jadwal.gd (fills `day_schedules`), StudentManager.write_back_to_gamestate()
## (pushes simulated stats back after each day), koprasi.gd and Cart
## (`money`, `inventory`), and DebugManager (every field, on purpose).
##
## Read by: every screen.
##
## The trap: `approved_students` holds Array[Dictionary] whose keys are the
## UI's names -- `akademis1/2/3` are academic/seni/olahraga, and
## `kepribadian1/2` are mood/energy. StudentData, used inside the simulation,
## has real field names instead. convert_to_student_data_array() bridges in
## and StudentManager.write_back_to_gamestate() bridges out. The two namings
## do not line up, and that mismatch is the most common source of bugs here.
```

Do not copy that text to other files. Each header must be true of its own
file; a generic header is worse than none because it reads as verified when
it is not.

For `StudentData.gd` the header must say that every quirk coefficient is an
`@export` tuned in the Inspector, and that nothing here should be hardcoded.
For `TouchFeedbackManager.gd` and `UIPolish.gd`, say which nodes they reach
into automatically and how to opt a node out
(`node.set_meta(Juice.NO_AUTO_JUICE, true)`).

- [ ] **Step 3: Document the exports**

`DesignTokens.gd` (60) and `AudioDirector.gd` (26) are the bulk. For
`DesignTokens`, each colour/radius/spacing token's doc line should say **where
it is used**, because that is what a designer needs to predict the blast
radius of a change:

```gdscript
## The saturated brand colour. Fills PrimaryButton, the quirk badge, and the
## quirk popup's header. Changing this re-tints roughly half the game's
## call-to-action surfaces -- rebake after editing.
@export var brand_primary: Color = Color(...)
```

For `StudentData.gd`'s 20 exports — the quirk and personality coefficients —
each doc line must say which quirk it belongs to and which direction it moves
the number:

```gdscript
## Kutu Buku: multiplier on akademis gain. Above 1.0 makes the bookworm learn
## faster; the energy cost is unchanged, so this is a pure upside.
@export var kutu_buku_akademis_multiplier: float = 1.25
```

Read the actual usage before writing each line. A doc line that guesses the
direction of a coefficient is worse than no line.

- [ ] **Step 4: Lower both pending lists**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
```

Expected: `test_pending_header_list_is_not_stale` and
`test_pending_export_doc_counts_are_not_stale` both FAIL with pasteable
literals. Paste both, rescan, re-run. Expected: all four tests PASS.

- [ ] **Step 5: Run the whole suite**

```
test_run()
```

Expected: all suites green. Documentation cannot change behaviour, so any
failure here means an edit slipped outside a comment — find it before
committing.

- [ ] **Step 6: Commit**

```bash
git add Scripts/GameState.gd Scripts/Inventory/Cart.gd Scripts/Inventory/ItemData.gd Scripts/Inventory/ItemDatabase.gd Scripts/SchoolSimulation/StudentData.gd Scripts/SchoolSimulation/StudentManager.gd Scripts/TouchFeedback Scripts/TutorialArrow.gd Scripts/Pengaturan.gd Scripts/Design/DesignTokens.gd Scripts/Audio/AudioDirector.gd Scripts/UI/UIPolish.gd Scripts/UI/StatBar.gd Scripts/Transition/transition.gd tests/test_script_documentation.gd && git commit -m "docs(core): document the autoloads, StudentData and the design tokens"
```

---

### Task 19: Document the screens

**Files (headers where missing, `##` on every `@export`, `##` on every
non-trivial function):**
- `Scripts/AturJadwal/atur_jadwal.gd` — header + 1 export
- `Scripts/AturJadwal/ActivityRow.gd` — 3 exports
- `Scripts/Lobby/loby.gd` — header + 10 exports
- `Scripts/Koperasi/koprasi.gd` — header
- `Scripts/StudentCard/student_card.gd` — header + 6 exports
- `Scripts/ReportCard/report_card.gd` — 6 exports
- `Scripts/SchoolSimulation/SchoolDay.gd` — header + 17 exports
- `Scripts/SchoolSimulation/ResultCheckup.gd` — 9 exports
- `Scripts/SchoolSimulation/DailyDecayOverview.gd` — 6 exports
- `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` — 8 exports
- `Scripts/SchoolSimulation/EventAnnouncement.gd` — 5 exports
- `Scripts/SchoolSimulation/EventWarning.gd` — 4 exports
- `Scripts/SchoolSimulation/BookClockWidget.gd` — 3 exports
- `Scripts/SchoolSimulation/DaySummaryPopup.gd` — 1 export
- `Scripts/SchoolSimulation/SimulationBackground.gd` — 2 exports
- `Scripts/StudentList/StickyNote.gd` — 2 exports
- `Scripts/EndGame/ResultStatRow.gd` — 2 exports
- Test: `tests/test_script_documentation.gd`

**Interfaces:**
- Consumes: the ratchet from Task 2.
- Produces: no API change.

- [ ] **Step 1: Write the headers**

The four screens needing one are the four largest files in the project. Each
header must name what the screen writes back to `GameState`, because that is
what a reader cannot see from the file. Worked example for
`Scripts/AturJadwal/atur_jadwal.gd`:

```gdscript
## Atur Jadwal: the player assigns each approved student one activity per
## school day, then commits the week.
##
## Reached from the Lobby. On commit it fills GameState.day_schedules --
## a dictionary keyed by student id, each holding five category strings --
## and hands off to StudentList and then SchoolDay, which simulate it.
##
## Categories are Akademis / SeniBudaya / Olahraga / Istirahat / Wirausaha.
## Two legacy spellings are normalised on the way in: "Akademik" becomes
## "Akademis" and "DayOff" becomes "Istirahat". A student whose energy has
## fallen to 5 or below is forced to "Izin", which is Istirahat under a
## different label -- the player cannot override that.
##
## Affects: GameState.day_schedules only. It never touches stats; SchoolDay
## does that when the week runs.
```

`loby.gd`, `student_card.gd` and `SchoolDay.gd` get the same treatment. For
`SchoolDay.gd`, the header must be explicit that it is the one screen that
mutates student stats, and that it does so through
`StudentManager.write_back_to_gamestate()` rather than by writing
`approved_students` directly.

- [ ] **Step 2: Document the exports**

`SchoolDay.gd`'s 17 and `loby.gd`'s 10 are mostly art and timing slots. Each
doc line says what it changes on screen:

```gdscript
## Seconds one simulated school day takes to play out. Lower it to review the
## day summary faster; the stat maths is unaffected, only the pacing.
@export var day_duration_seconds: float = 2.5
```

- [ ] **Step 3: Document the functions**

This is rule 3, the untested half. Work through each screen's functions and
give every one that is not a one-line accessor a `##` line. The bar: a reader
who has never opened the file should be able to predict the side effects.
Prefer naming the affected node or autoload over describing the algorithm —
the code already describes the algorithm.

- [ ] **Step 4: Lower both pending lists**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
```

Paste both regenerated literals, rescan, re-run. Expected: all four PASS.

- [ ] **Step 5: Run the whole suite**

```
test_run()
```

Expected: all suites green.

- [ ] **Step 6: Commit**

```bash
git add Scripts/AturJadwal Scripts/Lobby Scripts/Koperasi/koprasi.gd Scripts/StudentCard/student_card.gd Scripts/ReportCard/report_card.gd Scripts/SchoolSimulation Scripts/StudentList/StickyNote.gd Scripts/EndGame/ResultStatRow.gd tests/test_script_documentation.gd && git commit -m "docs(screens): document every screen's header, exports and functions"
```

---

### Task 20: Document the minigames

The last group, and the one with the most exports: `BaseMinigame.gd` alone has
36 undocumented, and every game inherits them.

**Files:**
- `Scripts/Minigames/UI/BaseMinigame.gd` — header + 36 exports
- `Scripts/Minigames/UI/MinigameMenu.gd` — header + 9 exports
- `Scripts/Minigames/UI/MinigameTutorial.gd` — 10 exports
- `Scripts/Minigames/UI/PauseMenu.gd` — 13 exports
- `Scripts/Minigames/Akademis/Menjodohkan.gd` — header + 30 exports
- `Scripts/Minigames/Akademis/PilihanGanda.gd` — header + 15 exports
- `Scripts/Minigames/Akademis/Password.gd` — 12 exports
- `Scripts/Minigames/Akademis/Variabel.gd` — 19 exports
- `Scripts/Minigames/SeniBudaya/BuatBatik.gd` — header + 22 exports
- `Scripts/Minigames/SeniBudaya/LombaMenari.gd` — header + 25 exports
- `Scripts/Minigames/Olahraga/Badminton.gd` — 11 exports
- `Scripts/Minigames/Olahraga/MainBola.gd` — 6 exports
- Test: `tests/test_script_documentation.gd`

**Interfaces:**
- Consumes: the ratchet from Task 2.
- Produces: no API change.

- [ ] **Step 1: Write `BaseMinigame.gd`'s header**

It is the base class for all eight games, so its header is load-bearing:

```gdscript
## The base every minigame extends.
##
## Owns the shared lifecycle -- start_minigame(difficulty, time_limit),
## activate_minigame(), win_game()/lose_game() -- plus the chrome every game
## shows: the countdown, the pause button, the pause menu, the quit
## confirmation and the end-of-game result card. A subclass supplies only its
## own play area and scoring.
##
## Every visual slot is an @export so a game (or an artist) can override the
## look per game without subclassing the chrome. The overlays themselves are
## scenes -- MinigameCountdown, QuitConfirmDialog, MinigameResultPopup -- and
## the exports are forwarded into them.
##
## Affects: GameState only through the calling screen. A minigame reports its
## result upward; it never writes stats itself. Difficulty scales with
## GameState.current_grade -- see the grade table in CLAUDE.md.
##
## Not covered by the design system: minigames inherit the Theme but had no
## polish pass, so a theme variation may not exist for a given surface here.
```

- [ ] **Step 2: Document `BaseMinigame`'s 36 exports**

They fall into five groups already marked by section banners: result copy,
popup card art, popup stars, popup buttons and fonts, countdown, quit dialog.
Each line says what the slot paints and when the player sees it:

```gdscript
## Shown as the result card's title after a win. Indonesian, player-facing.
@export var win_title_text: String = "Kamu Berhasil! 🎉"

## The star texture for an earned star on the result card. Leave null to draw
## the built-in polygon instead -- ResultStar falls back to it automatically.
@export var popup_star_texture: Texture2D = null
```

- [ ] **Step 3: Document the eight games**

Each game's header says what the player does, what winning means, and which
skill it feeds. Its exports are almost all art and difficulty knobs; say what
each one changes on screen and which difficulty tier it applies to where that
varies.

- [ ] **Step 4: Empty both pending lists**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
```

Paste both regenerated literals. After this wave `PENDING_HEADERS` should be
`[]` and `PENDING_EXPORT_DOCS` should be `{}`. If they are not, something in
an earlier wave was missed — find it rather than leaving the entry.

- [ ] **Step 5: Run the whole suite**

```
test_run()
```

Expected: all suites green.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Minigames tests/test_script_documentation.gd && git commit -m "docs(minigames): document BaseMinigame and all eight games"
```

---

### Task 21: Close the ratchets

Both `PENDING_*` lists are now empty and every non-exempt script's
editability baseline should be at or near zero. Turn the ratchets into plain
rules so the next contributor gets a clear failure rather than a puzzle about
a baseline dictionary.

**Files:**
- Modify: `tests/test_script_documentation.gd`
- Modify: `tests/test_viewport_editability.gd`
- Modify: `docs/superpowers/design/authoring-guide.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: everything above.
- Produces: two suites with no allowlists — `PENDING_HEADERS`,
  `PENDING_EXPORT_DOCS` and the two "not stale" tests are deleted; the
  remaining tests assert zero directly.

- [ ] **Step 1: Confirm both lists are actually empty**

```
filesystem_manage(op="scan")
test_run(suite="script_documentation")
test_run(suite="viewport_editability")
```

Read the constants in both files. If `PENDING_HEADERS` is not `[]` or
`PENDING_EXPORT_DOCS` is not `{}`, **stop and finish Phase 5** — do not close
a ratchet that is still carrying debt.

`BASELINE` in `test_viewport_editability.gd` will not be empty, and that is
expected: a few legitimate runtime constructions survive (a pooled particle,
a dynamically-sized list). For each surviving entry, decide one of two things
and record it in the commit message:

- it is legitimate → move the path into a new `ALLOWED` constant with a
  one-line comment saying why, or
- it is unconverted work → leave it in `BASELINE` and add a follow-up note in
  the authoring guide's "known gaps" section.

Do not silently convert `BASELINE` into `ALLOWED` wholesale; that would undo
the whole phase.

- [ ] **Step 2: Simplify `test_script_documentation.gd`**

Delete `PENDING_HEADERS`, `PENDING_EXPORT_DOCS`,
`test_pending_header_list_is_not_stale` and
`test_pending_export_doc_counts_are_not_stale`. Rewrite the two survivors to
assert zero:

```gdscript
func test_every_script_has_a_file_header_doc_block() -> void:
	var missing := _scan_headers()
	assert_true(missing.is_empty(),
		("These scripts have no `##` header block in their first %d lines. "
		% HEADER_SEARCH_LINES)
		+ "Say what the file is, who drives it, and what it affects.\n  "
		+ "\n  ".join(missing))


func test_every_export_has_an_inspector_doc_comment() -> void:
	var current := _scan_exports()
	var offenders: Array[String] = []
	for path in current:
		offenders.append("  %s: %d undocumented" % [path, current[path]])
	offenders.sort()
	assert_true(offenders.is_empty(),
		"Every @export needs a `##` line above it -- Godot shows it as the "
		+ "Inspector tooltip.\n"
		+ "\n".join(offenders))
```

Update the suite's header block: it is no longer a ratchet, it is a rule.

- [ ] **Step 3: Rewrite `test_viewport_editability.gd`'s framing**

Rename `BASELINE` to `ALLOWED` if and only if every surviving entry was
justified in Step 1, and put the justification comment beside each entry.
Otherwise leave it named `BASELINE` and keep both directions of the ratchet —
an honest half-finished ratchet beats a dishonest clean rule.

- [ ] **Step 4: Update the docs**

In `docs/superpowers/design/authoring-guide.md`, change the "How this is
enforced" section from ratchet language to rule language, and add a "Known
gaps" section listing anything left in `ALLOWED`/`BASELINE` with its reason.

In `CLAUDE.md`, update the pointer added in Task 3 to say the rules are
enforced outright, and add one line to the "Known issues" section if any gap
survived.

- [ ] **Step 5: Prove the rules bite**

Add `var _probe := Label.new()` to `Scripts/UI/StatBar.gd` and an undocumented
`@export var _probe2: int = 0` to the same file. Rescan, run both suites.
Expected: both FAIL, each naming `StatBar.gd`. Remove both lines, rescan,
re-run. Expected: both PASS.

- [ ] **Step 6: Run everything, twice**

```
test_run()
```

Then close and reopen the editor, open
`Scenes/Splashscreen/Splashscreen.tscn`, and run again — several suites assume
the main scene is open and return a `scene_warning` when it is not.

Expected: all suites green in both runs.

- [ ] **Step 7: Play one full week end to end**

The last check that nothing in 21 tasks broke the game. From a cold start:
MainMenu → CutScene → StudentCard (approve a roster) → Lobby → Atur Jadwal
(assign five days) → StudentList → SchoolDay (let the week simulate, hit at
least one minigame) → ResultCheckup → Lobby. Confirm every screen renders and
every popup opens.

- [ ] **Step 8: Commit**

```bash
git add tests/test_script_documentation.gd tests/test_viewport_editability.gd docs/superpowers/design/authoring-guide.md CLAUDE.md && git commit -m "test(hygiene): close the editability and documentation ratchets"
```

---

## Self-Review

Run against the spec after the plan was written.

**Spec coverage.** Every section of
`docs/superpowers/specs/2026-08-31-viewport-editable-ui-and-script-docs-design.md`
maps to at least one task:

| Spec section | Tasks |
|---|---|
| Pattern A — static chrome in the scene | 8, 13, 17 |
| Pattern B — `PackedScene` templates | 5, 6, 7, 10, 11, 12, 15, 16, 17 |
| Pattern C — `@tool` + `@export` knobs | 9, 16 |
| Asset references become `@export Texture2D` | 8, 9, 13 |
| The ratchet | 1, 2, 21 |
| Documentation standard | 3, 18, 19, 20 |
| Non-goals (DebugManager, addons, prototype) | 1, 2 (`EXEMPT`), 3, 21 |

**Placeholder scan.** No "TBD", no "add error handling", no "similar to Task
N", no test step without test code. Three places deliberately say *read the
shipped source for the exact number* rather than quoting one — Task 9 Step 4
(the goalie/ball fractions at `MainBola.gd:216-260`), Task 15 Step 3 (row
spacing, which differs across the three screens) and Task 17 Step 3 (card
margins). Those are not placeholders: quoting a number I have not read would
be worse than telling the executor where the truth is, and each names the
exact file and line range.

**Type consistency.** Checked across tasks:
`StatInfo.get_bar` / `token_category` / `value_of` are used with the same
signatures in Tasks 4, 5, 6, 15, 17. `configure()` / `open()` / `close()` /
`closed` is the same shape on `StatDetailPopup`, `TraitDetailPopup`,
`RakBarangPopup`. `setup()` is the shape on the non-modal components
(`InventorySlot`, `StudentStatRow`, `StudentSummaryCard`). `StatBar.set_stat`
is called with the real two-argument signature from `Scripts/UI/StatBar.gd`.
`BASELINE` / `PENDING_HEADERS` / `PENDING_EXPORT_DOCS` are named identically
everywhere they are updated.

**One thing the executor should watch.** Tasks 5-7 and 10-17 each end by
regenerating a ratchet literal. If two tasks are done in parallel by different
workers, those literals will conflict. Run the conversion tasks in sequence,
or regenerate the literal after merging rather than before.
