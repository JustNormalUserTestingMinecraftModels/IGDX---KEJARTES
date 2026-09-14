# Exam CG and Inventory Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Stay inline: the Godot bridge takes one client. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ExamProgress shows the user's `cg_ujian` art, and every text on the Inventory item sheet and the item-application screen reads at 36 px or more.

**Architecture:** The ExamProgress change is one resource swap on the `Backdrop` TextureRect, plus deleting the orphaned placeholder. The text change moves five nodes onto variations that already exist (`EventBodyLabel` at 36 px and `H2Label` at 48 px, both dark ink on the light `Card`), so ThemeFactory, the tokens and the bake do not change. A new suite checks the size of every text node on these screens through the baked theme.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` run through the godot-ai MCP `test_run`, scene edits through the MCP node tools.

**Spec:** `docs/superpowers/specs/2026-09-14-exam-cg-and-inventory-text-design.md`

## Global Constraints

- The work happens in the worktree `.claude/worktrees/project-guide-audit` on branch `feat/exam-cg-and-inventory-text`.
- Every godot-ai call passes this worktree editor's `session_id`, currently `project-guide-audit@9539`. Re-list with `session_manage(op="list")` after any editor restart. Never call `session_activate`.
- Never hand-edit a `.tscn` while this editor runs. Use `scene_open` → `node_set_property` → `scene_save`.
- After any `scene_save`, run `git diff HEAD --stat -- '*.gd'` and revert any `.gd` you did not mean to change.
- Edit existing `.gd` files with `script_patch`, so the editor never serves a stale copy. A new test file is written, then followed by `filesystem_manage(op="scan")`.
- Never add a `theme_override_*`. `Balance.gd` is not touched. The UI copy does not change.
- `git add` only explicit paths. Commits use Conventional Commits with a scope and end with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Any game run rewrites `Assets/Audio/default_bus_layout.tres`, and a full `test_run` rewrites `Assets/Theme/kejartes_theme.tres`. Revert both before committing unless the change is intended.

---

### Task 1: ExamProgress shows cg_ujian

**Files:**
- Modify: `tests/test_exam_progress.gd` (add one test after `test_the_scene_hands_the_script_a_real_pan_distance`)
- Modify: `Scenes/EndGame/ExamProgress.tscn` (`Backdrop.texture`)
- Add: `Assets/Images/CG/cg_ujian.png` and its `.import` (already downloaded and imported, untracked)
- Delete: `Assets/Images/CG/cg_test.jpg` and `Assets/Images/CG/cg_test.jpg.import`

**Interfaces:** none. The scene keeps its node names, and `ExamProgress.gd` does not change.

- [ ] **Step 1: Write the failing test.** Insert it with `script_patch` into `res://tests/test_exam_progress.gd`, directly before `func _collect_overrides`:

```gdscript
func test_the_backdrop_shows_the_exam_art() -> void:
	var backdrop: TextureRect = _screen.get_node("Backdrop")
	assert_true(backdrop.texture != null, "Backdrop has a texture")
	assert_eq(backdrop.texture.resource_path, "res://Assets/Images/CG/cg_ujian.png",
		"ExamProgress shows the user's cg_ujian art (2026-09-14), not the cg_test placeholder")
	assert_false(FileAccess.file_exists("res://Assets/Images/CG/cg_test.jpg"),
		"cg_test.jpg is deleted: ExamProgress was its only user")


```

- [ ] **Step 2: Run it and see it fail**

Run: `test_run(suite="exam_progress", session_id="project-guide-audit@9539")`
Expected: 1 failure in `test_the_backdrop_shows_the_exam_art`, because the texture path is still `cg_test.jpg`. Every other test passes.

- [ ] **Step 3: Swap the texture and delete the placeholder**

```
scene_open(path="res://Scenes/EndGame/ExamProgress.tscn", session_id=…)
node_set_property(path="/ExamProgress/Backdrop", property="texture",
                  value="res://Assets/Images/CG/cg_ujian.png", session_id=…)
scene_save(session_id=…)
```
```bash
git rm -q Assets/Images/CG/cg_test.jpg Assets/Images/CG/cg_test.jpg.import
git diff HEAD --stat -- '*.gd'   # expect only tests/test_exam_progress.gd
```
Then run `filesystem_manage(op="scan", session_id=…)`.

- [ ] **Step 4: Run it and see it pass**

Run: `test_run(suite="exam_progress", session_id=…)`
Expected: all pass. Also confirm `grep -n "cg_ujian" Scenes/EndGame/ExamProgress.tscn` shows the ext_resource line.

- [ ] **Step 5: Commit**

```bash
git add tests/test_exam_progress.gd Scenes/EndGame/ExamProgress.tscn Assets/Images/CG/cg_ujian.png Assets/Images/CG/cg_ujian.png.import
git commit -m "feat(exam-progress): show the cg_ujian art behind the fill" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
(The `git rm` from Step 3 is already staged.)

---

### Task 2: No small text on the item screens

**Files:**
- Create: `tests/test_inventory_text_size.gd` (and the `.uid` the editor generates)
- Modify: `Scenes/Inventory/ItemDetailSheet.tscn` (`DescLabel`)
- Modify: `Scenes/Inventory/EfekRow.tscn` (`ValueLabel`, `ExplainLabel`)
- Modify: `Scenes/Inventory/ApplyItemScreen.tscn` (`RecapCount`, `EffectSummary`)
- Modify: `tests/test_light_ground_text.gd` (comments only, at the Inventory block, about line 161)

**Interfaces:** the node names are unchanged, so `test_light_ground_text.gd`'s paths (`Sheet/Margin/VBox/EfekList/Row*/ValueLabel`) stay valid.

- [ ] **Step 1: Write the failing suite.** Write `tests/test_inventory_text_size.gd`, then run `filesystem_manage(op="scan", session_id=…)`:

```gdscript
@tool
extends McpTestSuite

## The Inventory item sheet and the item-application screen read at a
## comfortable size (2026-09-14; spec
## docs/superpowers/specs/2026-09-14-exam-cg-and-inventory-text-design.md).
## On the 1080-wide canvas 36 px is about 12 sp, the floor for comfortable
## secondary text on a phone. Every Label, and every Button with text, is
## resolved through the baked theme the way Godot resolves it: a node
## override, then the variation and its base chain, then the class, then the
## theme default. Scenes are instantiated but never added to the tree, so no
## _ready runs; sub-scenes the screens spawn at runtime are listed directly.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _SCENES := [
	"res://Scenes/Inventory/inventory.tscn",
	"res://Scenes/Inventory/InventorySlot.tscn",
	"res://Scenes/Inventory/ItemDetailSheet.tscn",
	"res://Scenes/Inventory/ApplyItemScreen.tscn",
	"res://Scenes/Inventory/ApplyStudentRow.tscn",
]
const _FLOOR_PX := 36

## Reviewed exceptions: shared components whose size belongs to other screens
## too. Variation -> the smallest size it may have here.
const ALLOWED := {
	# The shared DaySummary card's need words (also DaySummaryPopup,
	# EventStudentCard, ResultCheckup, WeekHistoryRow).
	"DaySummaryNeedsLabel": 30,
	# The empty-grid hint, shared with ResultCheckup.
	"EmptyStateLabel": 32,
}

## The 18 and 22 px styles this pass moved these screens off.
const _RETIRED := ["CaptionLabel", "MicroLabel", "ResultDeltaLabel"]

var _theme: Theme


func suite_name() -> String:
	return "inventory_text_size"


func suite_setup(_ctx: Dictionary) -> void:
	_theme = load(_THEME_PATH)


func test_no_text_on_the_item_screens_is_below_the_floor() -> void:
	for path in _SCENES:
		var root: Node = load(path).instantiate()
		for node in _text_nodes(root):
			var variation := String(node.theme_type_variation)
			var px := _font_size(node)
			var floor_px: int = ALLOWED.get(variation, _FLOOR_PX)
			assert_true(px >= floor_px, "%s: %s (%s) resolves to %d px, under %d"
				% [path.get_file(), root.get_path_to(node),
				variation if variation != "" else node.get_class(), px, floor_px])
		root.free()


func test_no_text_here_wears_a_retired_small_style() -> void:
	for path in _SCENES:
		var root: Node = load(path).instantiate()
		for node in _text_nodes(root):
			assert_false(_RETIRED.has(String(node.theme_type_variation)),
				"%s: %s still wears %s"
				% [path.get_file(), root.get_path_to(node), node.theme_type_variation])
		root.free()


func _text_nodes(root: Node) -> Array:
	var out := []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label or (n is Button and (n as Button).text != ""):
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _font_size(node: Control) -> int:
	if node.has_theme_font_size_override("font_size"):
		return node.get_theme_font_size("font_size")
	var t := String(node.theme_type_variation)
	while t != "":
		if _theme.has_font_size("font_size", t):
			return _theme.get_font_size("font_size", t)
		t = String(_theme.get_type_variation_base(t))
	var cls := "Button" if node is Button else "Label"
	if _theme.has_font_size("font_size", cls):
		return _theme.get_font_size("font_size", cls)
	return _theme.default_font_size
```

- [ ] **Step 2: Run it and see it fail**

Run: `test_run(suite="inventory_text_size", session_id=…)`
Expected: both tests fail, naming exactly these nodes: ItemDetailSheet `DescLabel` (22), the five `EfekList/Row*/ValueLabel` (22) and `ExplainLabel` (18), and ApplyItemScreen `RecapCount` and `EffectSummary` (22). If any other node is named, stop and report it: the spec did not list it.

- [ ] **Step 3: Restyle the five nodes through the editor**

```
scene_open(path="res://Scenes/Inventory/EfekRow.tscn", session_id=…)
node_set_property(path="/EfekRow/ValueLabel", property="theme_type_variation", value="H2Label", session_id=…)
node_set_property(path="/EfekRow/ExplainLabel", property="theme_type_variation", value="EventBodyLabel", session_id=…)
scene_save(session_id=…)

scene_open(path="res://Scenes/Inventory/ItemDetailSheet.tscn", session_id=…)
node_set_property(path="/ItemDetailSheet/Sheet/Margin/VBox/DescLabel", property="theme_type_variation", value="EventBodyLabel", session_id=…)
scene_save(session_id=…)

scene_open(path="res://Scenes/Inventory/ApplyItemScreen.tscn", session_id=…)
node_set_property(path="/ApplyItemScreen/Margin/Card/Margin/VBox/RecapStrip/RecapCount", property="theme_type_variation", value="EventBodyLabel", session_id=…)
node_set_property(path="/ApplyItemScreen/Margin/Card/Margin/VBox/EffectSummary", property="theme_type_variation", value="EventBodyLabel", session_id=…)
scene_save(session_id=…)
```
Edit `EfekRow.tscn` itself, not the rows inside ItemDetailSheet. Overrides on an instance's children are dropped on save. Then run `git diff HEAD --stat -- '*.gd'`: expect only the two test files.

- [ ] **Step 4: Run the affected suites and see them pass**

Run: `test_run(suite="inventory_text_size", …)`, then `item_detail_sheet`, `apply_item_screen`, `apply_student_row` and `light_ground_text`, each with `session_id`.
Expected: all pass. `light_ground_text` now measures `H2Label`'s dark ink on the white Card, and `H2Label` is in the bake.

- [ ] **Step 5: Correct the contrast suite's now-stale comments** with `script_patch` in `res://tests/test_light_ground_text.gd`. Replace

```gdscript
# ──────────────────────── Inventory, which shares ResultDeltaLabel

## The item sheet's "+N" beside each stat an item moves. Nothing tints it,
## so its letters are white on the sheet's white Card.
```
with
```gdscript
# ──────────────────────── Inventory's item sheet

## The item sheet's "+N" beside each stat an item moves. Since 2026-09-14 it
## is H2Label's dark ink (it was white ResultDeltaLabel before), measured on
## the sheet's white Card.
```
Run: `test_run(suite="light_ground_text", …)`. Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add tests/test_inventory_text_size.gd tests/test_inventory_text_size.gd.uid tests/test_light_ground_text.gd Scenes/Inventory/EfekRow.tscn Scenes/Inventory/ItemDetailSheet.tscn Scenes/Inventory/ApplyItemScreen.tscn
git commit -m "feat(inventory): make the item sheet and apply screen text readable" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Check it at full size

**Files:** none unless the sheet overflows. The contingency is at the end of this task.

- [ ] **Step 1: Reach the item sheet.** Run `project_run(session_id=…)`. Press `F1`, then read the overlay with `game_manage(op="get_ui_elements", params={"root_path": "/root/DebugManager", "max_depth": 4})`. Click **⚡ Seed Playtest State**, then **Scenes → Lobby**. Each click is a `motion` input then a `button` input, at `window = global * original_width / 1080`. In the Lobby, click the Inventory nav button, then the **Bank Soal** slot, which has the longest description (68 characters).
- [ ] **Step 2: Judge it.** Read `Sheet` and `ApplyButton` with `get_ui_elements` a frame after the sheet opens, not in the same call that opens it. Then take `editor_screenshot(source="game", max_resolution=0, session_id=…)`. Pass when all text is readable, no label runs past the sheet, and `ApplyButton`'s bottom edge is at or above 1920 − the sheet margin.
- [ ] **Step 3: The apply screen.** Click **Pakai ke Siswa** and take a full-size screenshot of ApplyItemScreen. Pass when the recap and summary lines read at their new size and nothing is clipped.
- [ ] **Step 4: ExamProgress.** Run `project_manage(op="stop", …)`, then `project_run(mode="custom", scene="res://Scenes/EndGame/ExamProgress.tscn", …)`. Take full-size screenshots about 1 s and 3.5 s in. Pass when the new art covers the screen, pans left, and shows no edge. Then stop the game.
- [ ] **Step 5: Clean up the runs**

```bash
git status --porcelain
git checkout -- Assets/Audio/default_bus_layout.tres   # only if listed
```

- [ ] **Contingency: only if Step 2 shows an overflow.** Wrap the sheet's middle in a ScrollContainer so the button stays pinned:
  - Under `Sheet/Margin/VBox`, add a `ScrollContainer` named `Body`, with `size_flags_vertical = 3` and `horizontal_scroll_mode = 0`. Add a `VBoxContainer` child named `BodyList` with `size_flags_horizontal = 3`. Use `batch_execute` with `create_node` and `set_property`, then `move_node` to place `Body` right after `TopRow`.
  - Move `DescLabel`, `EfekHeader` and `EfekList` into `BodyList`, keeping their order.
  - Update every test path that walks through `Sheet/Margin/VBox/EfekList` or `Sheet/Margin/VBox/DescLabel` to add `Body/BodyList/`: `grep -rn "Margin/VBox/EfekList\|Margin/VBox/DescLabel" tests Scripts`.
  - Re-run Task 2 Step 4 and this task's Step 2, then commit as `fix(inventory): let the item sheet's body scroll`.

---

### Task 4: Record it, then the full suite

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (a new entry at the top)
- Modify: `docs/superpowers/DEBT.md` (one entry under "Deferred and pending")
- Modify: `CLAUDE.md` (the suite count line in `## Testing` only)

- [ ] **Step 1: Changelog entry**, newest first, directly above the first existing `## 2026-09-14` heading:

```markdown
## 2026-09-14 — Exam art and readable inventory text

ExamProgress now shows the user's `cg_ujian.png` (1920x1920, from their Google
Drive) behind the fill, in place of the `cg_test.jpg` placeholder, which is
deleted. The pan is unchanged: 216 px over the 4 s fill, across the middle
1296 of the art's 1920 columns.

The Inventory item sheet and the item-application screen had nine texts at 18
or 22 px, about 6-7 sp on a phone. They now use existing variations: the item
description, each effect's explanation, the effect summary and "Sisa ×N" are
`EventBodyLabel` (36 px, dark ink), and each effect's "+N" is `H2Label` (48 px,
display face, dark ink). The Brief had offered the student cards' 52 px
`DaySummaryStat` for "+N", but that style is white with a dark rim, made for
the cards' dark tracks, so it would not read on the sheet's near-white Card.
No token changed and nothing was rebaked. The new suite `inventory_text_size`
holds every text on these screens at 36 px or more, with two reviewed shared
exceptions (the 30 px need words, the 32 px empty-state hint).
```
If Task 3's contingency ran, add a sentence saying the item sheet's body now scrolls.

- [ ] **Step 2: DEBT.md entry**, under `## Deferred and pending`:

```markdown
**ExamProgress shows only the middle of cg_ujian (2026-09-14).** The art is
1920x1920, but `Backdrop` is 1296 wide and pans 216 px, so the outer 312 px on
each side never show. Showing it all means a 1920-wide `Backdrop` and
`pan_pixels = -840` (a faster pan over the same 4 s), plus the 1296 in
`tests/test_exam_progress.gd`'s width test.
```

- [ ] **Step 3: Full suite**

Run: `test_run(session_id=…)` with no `suite`.
Expected: all pass, with totals of 106 suites and 1505 + the new tests. Then run `git status --porcelain`, and `git checkout --` `Assets/Theme/kejartes_theme.tres` and `Assets/Audio/default_bus_layout.tres` if the run rewrote them.

- [ ] **Step 4: Suite count.** In `CLAUDE.md` `## Testing`, replace `105 suites, 1505 tests (2026-09-14)` with the real totals from Step 3.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/DEBT.md CLAUDE.md
git commit -m "docs(exam-cg-inventory-text): changelog, the pan's hidden edges, suite count" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
