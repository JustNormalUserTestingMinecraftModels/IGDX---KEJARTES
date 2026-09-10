# Minigame, Sky and Paper Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land six independent fixes — a 2×, upright, cork-leading badminton shuttle that stops growing on hits; a MainBola goalie you can drag in the 2D editor; BuatBatik tool pictures bound to their tools; a full-turn, ease-out day sky; per-paper shadows on StudentCard and ReportCard; and LombaMenari's festival backdrop.

**Architecture:** Scene work goes through the Godot AI MCP bridge (`scene_open` → `node_*` → `scene_save`); script work goes through `script_patch`/`script_create`. Two small new units carry the new behaviour where it needs its own test: `ShuttlecockSprite.gd` (the shuttle's look) and `PaperShadow.tscn` (one shadow template for twelve papers). Everything else is an edit in place.

**Tech Stack:** Godot 4.6 (mobile renderer, Vulkan), GDScript, Godot AI MCP (`test_run`, `scene_open`, `scene_manage`, `node_create`, `node_set_property`, `node_manage`, `node_get_properties`, `script_create`, `script_patch`, `script_attach`, `scene_save`, `filesystem_manage`, `project_run`, `game_manage`, `editor_screenshot`), PowerShell + System.Drawing for the offline sky render.

**Spec:** `docs/superpowers/specs/2026-09-10-minigame-sky-and-paper-fixes-design.md`

**Execution note:** the MCP bridge is single-client — a subagent that connects displaces this session. Run this plan inline (superpowers:executing-plans). A subagent may only write `.gd` text, and its files then need the no-op `script_patch` below before any test run.

## Global Constraints

- **Never hand-edit a `.tscn` while the editor is attached.** Its in-memory copy wins and the next `scene_save` silently overwrites your text edit. Go through `scene_open` → `node_create` / `node_set_property` / `node_manage` → `scene_save`.
- **Scene work first, script work second.** `scene_save` flushes stale script buffers over whatever you patched. After every `scene_save`, run `git diff HEAD -- '*.gd'` and check for files you were not editing.
- **Edit `.gd` files only through `script_patch`; create them with `script_create`.** `test_run` otherwise serves stale bytecode. If a `.gd` was written from outside the editor anyway, force a reload with two `script_patch` calls on it (add a blank line, then remove it) — it logs a benign `GDScript reload failed with error code 43` and then works.
- **`script_patch` matches bytes exactly.** GDScript here is tab-indented. If an `old_text` below does not match, read the file with `filesystem_manage(op="read_text")` and copy the block verbatim — especially lines carrying emoji or the `─` box-drawing rule.
- **Every test suite must be `@tool`; no test may be a coroutine** — the runner does `suite.call(name)` without awaiting, so an `await` aborts the test and reports "0 assertions".
- **A suite that calls `assert_not_null(` must `extends McpTestSuiteCompat`**, not `McpTestSuite` (guarded in `tests/test_project_hygiene.gd`).
- **No visual is built at runtime** (`tests/test_viewport_editability.gd` ratchet): static chrome is a node in the `.tscn`; repeated items are a `PackedScene` template. When a count drops, lower `BASELINE` in the same commit.
- **Anchors:** `anchors_preset` is inert — set the four `anchor_*` properties, then the four `offset_*` (setting an anchor re-derives the offsets). Numbers are unquoted. `node_create` appends last; use `node_manage(op="move")` for order.
- **Instance overrides serialise only on an instanced scene's root.** Put every property a template needs on its root.
- **Never `scene_open` `Scenes/SchoolSimulation/BookClockWidget.tscn`** over the bridge — it hangs the editor.
- **A new or edited `class_name` script breaks the next game run** until `project_manage(op="stop")` → `filesystem_manage(op="scan")` → relaunch.
- **New scripts carry a `.gd.uid` sidecar; commit it** with the script.
- Game-facing text is Indonesian; engine and systems code is English. Never change `Scripts/Balance.gd`. No emoji as UI iconography.
- Commits: Conventional Commits with a scope, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Do not push.
- Some suites assume `Scenes/MainMenu/main_menu.tscn` is open; `test_run` returns a `scene_warning` naming it. Open it before trusting a failure.

## File map

| File | Task | Change |
|---|---|---|
| `Assets/Images/Textures/budaya_background.jpg` (+ `.import`) | 1 | new, copied from Downloads |
| `Scenes/Minigames/SeniBudaya/LombaMenari.tscn` | 1 | backdrop wiring |
| `Scenes/UI/PaperShadow.tscn` | 2 | new shadow template |
| `Scenes/StudentCard/student_card.tscn`, `Scenes/ReportCard/report_card.tscn` | 2 | a `PaperShadow` in each paper; static `Shadow` deleted |
| `tests/test_paper_shadow.gd` | 2 | new suite |
| `tests/test_report_card.gd` | 2 | root-`Shadow` test removed |
| `Scenes/Minigames/SeniBudaya/BuatBatik.tscn` | 3 | `ToolTextureRect` per tool; `IconLabel`s deleted |
| `Scripts/Minigames/SeniBudaya/BuatBatik.gd` | 3 | overrides matched by name; dead emoji helper gone |
| `tests/test_viewport_editability.gd` | 3 | `BuatBatik.gd` 8 → 7 |
| `tests/test_minigame_art.gd` | 1, 3 | LombaMenari and BuatBatik tests |
| `Scripts/Minigames/Olahraga/ShuttlecockSprite.gd` (+ `.uid`) | 4 | new: the shuttle's look |
| `tests/test_shuttlecock_sprite.gd` | 4 | new behavioural suite |
| `Scenes/Minigames/Olahraga/Badminton.tscn` | 4 | sprite 2×, rotated 90°, script attached |
| `Scripts/Minigames/Olahraga/Badminton.gd` | 4 | hit radius knob; drives `ShuttlecockSprite`; racket squash fix |
| `tests/test_badminton_visuals.gd` | 4 | size, pose, hit-driving tests |
| `Scripts/Minigames/Olahraga/MainBola.gd` | 5 | layout measures `size`; goalie authored |
| `Scenes/Minigames/Olahraga/MainBola.tscn` | 5 | goalie at (540, 946.176); design-space re-save |
| `tests/test_main_bola_layout.gd` | 5 | goalie tests |
| `Scripts/SchoolSimulation/BookClockWidget.gd` | 6 | poses 60 / −300; SINE/OUT; smoothstep off |
| `tests/test_book_clock_phases.gd`, `tests/test_sky_transition.gd` | 6 | preset and easing tests |
| `docs/superpowers/CHANGELOG.md`, `docs/superpowers/design/authoring-guide.md`, `CLAUDE.md` | 7 | docs |

---

### Task 1: LombaMenari festival backdrop

**Files:**
- Create: `Assets/Images/Textures/budaya_background.jpg` (copy of `C:\Users\user\Downloads\budaya_background.jpg`, 1080×1920; Godot writes the `.import`)
- Modify: `Scenes/Minigames/SeniBudaya/LombaMenari.tscn` (through the editor)
- Test: `tests/test_minigame_art.gd` (append)

**Interfaces:**
- Consumes: `_ext_resource_ids(src)` already in `tests/test_minigame_art.gd`.
- Produces: `res://Assets/Images/Textures/budaya_background.jpg`; consts `_MENARI_SCENE`, `_MENARI_BACKDROP` in `test_minigame_art.gd`, which Task 3 appends after.

- [ ] **Step 1: Write the failing tests**

`script_patch` on `res://tests/test_minigame_art.gd`:

old_text:
```gdscript
	assert_false(mj.contains("Color(1, 0.7, 0.3, 1)"),
		"Menjodohkan's question header must not go back to the pale orange")
```
new_text:
```gdscript
	assert_false(mj.contains("Color(1, 0.7, 0.3, 1)"),
		"Menjodohkan's question header must not go back to the pale orange")

## LombaMenari's backdrop. It borrowed Gawang.jpg -- MainBola's football goal
## -- as a placeholder until the festival art arrived on 2026-09-10. See
## docs/superpowers/specs/2026-09-10-minigame-sky-and-paper-fixes-design.md §6.
const _MENARI_SCENE := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"
const _MENARI_BACKDROP := "res://Assets/Images/Textures/budaya_background.jpg"

func test_lomba_menari_backdrop_imports() -> void:
	assert_true(ResourceLoader.exists(_MENARI_BACKDROP), "missing imported art: " + _MENARI_BACKDROP)
	assert_true(load(_MENARI_BACKDROP) is Texture2D, _MENARI_BACKDROP + " did not import as a Texture2D")

func test_lomba_menari_wires_the_festival_backdrop_not_the_football_goal() -> void:
	var src := FileAccess.get_file_as_string(_MENARI_SCENE)
	var ids := _ext_resource_ids(src)
	var needle := "background_texture = ExtResource(\""
	var at := src.find(needle)
	assert_true(at != -1, "LombaMenari.tscn has no background_texture assignment")
	if at != -1:
		var id_start := at + needle.length()
		var res_id := src.substr(id_start, src.find("\"", id_start) - id_start)
		assert_eq(ids.get(res_id, ""), _MENARI_BACKDROP,
			"background_texture must point at the festival backdrop")
	assert_false(src.contains("Gawang.jpg"),
		"LombaMenari.tscn still references MainBola's football goal")

func test_lomba_menari_backdrop_shows_in_the_editor_and_covers_tall_screens() -> void:
	var scene: Node = (load(_MENARI_SCENE) as PackedScene).instantiate()
	track(scene)
	var bg := scene.get_node_or_null("Background") as TextureRect
	assert_true(bg != null, "LombaMenari needs its Background TextureRect")
	if bg == null:
		return
	assert_true(bg.texture != null and bg.texture.resource_path == _MENARI_BACKDROP,
		"the Background node must carry the art itself, so the 2D editor shows it")
	assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"a taller phone must crop the sides, not stretch the art")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="minigame_art")`
Expected: the three `test_lomba_menari_*` tests FAIL (asset missing; `Gawang.jpg` still wired; `Background.texture` null). Every older test still passes.

- [ ] **Step 3: Copy the art in and let Godot import it**

```powershell
Copy-Item -LiteralPath 'C:\Users\user\Downloads\budaya_background.jpg' -Destination 'C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\Assets\Images\Textures\budaya_background.jpg'
```
Then `filesystem_manage(op="scan")`, then confirm the import landed:
```powershell
Test-Path 'C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\Assets\Images\Textures\budaya_background.jpg.import'
```
Expected: `True`. The source stays in Downloads.

- [ ] **Step 4: Wire the scene through the editor**

```
scene_open(path="res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn")
node_set_property(path="/LombaMenari", property="background_texture", value="res://Assets/Images/Textures/budaya_background.jpg")
node_set_property(path="/LombaMenari/Background", property="texture", value="res://Assets/Images/Textures/budaya_background.jpg")
node_set_property(path="/LombaMenari/Background", property="stretch_mode", value=6)
scene_save()
```
Then:
```bash
git diff HEAD -- '*.gd'
git diff -- Scenes/Minigames/SeniBudaya/LombaMenari.tscn
```
Expected: the first prints nothing. The second shows the `Gawang.jpg` `ext_resource` replaced by `budaya_background.jpg`, plus `texture = ExtResource(...)` and `stretch_mode = 6` on `Background`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="minigame_art")`
Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/Textures/budaya_background.jpg Assets/Images/Textures/budaya_background.jpg.import Scenes/Minigames/SeniBudaya/LombaMenari.tscn tests/test_minigame_art.gd
git commit -m "feat(lomba-menari): festival backdrop replaces the football goal" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Paper shadows ride their paper

**Files:**
- Create: `Scenes/UI/PaperShadow.tscn` (through the editor)
- Modify: `Scenes/StudentCard/student_card.tscn`, `Scenes/ReportCard/report_card.tscn` (through the editor)
- Create: `tests/test_paper_shadow.gd`
- Modify: `tests/test_report_card.gd` (remove the root-`Shadow` test)

**Interfaces:**
- Produces: `res://Scenes/UI/PaperShadow.tscn`, root `TextureRect` named `PaperShadow`; one instance named `PaperShadow` as child 0 of every `KertasMurid1..6` in both scenes.

- [ ] **Step 1: Write the failing suite**

`script_create(path="res://tests/test_paper_shadow.gd", content=...)`:

```gdscript
@tool
extends McpTestSuite

## Paper shadows ride their paper. StudentCard and ReportCard used to draw one
## static Shadow behind the whole six-paper stack, so a paper thrown
## off-screen by _transition_page() left its shadow behind on the desk. Every
## paper now carries a PaperShadow.tscn instance as its first child, with
## show_behind_parent: it inherits the paper's position, tilt and fade, and
## draws underneath it. See docs/superpowers/specs/
## 2026-09-10-minigame-sky-and-paper-fixes-design.md §5.
##
## Scene instantiation only -- nothing enters the tree, so no script in
## either screen runs (StatBar.gd on the papers' bars is @tool).
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "paper_shadow"

const _TEMPLATE := "res://Scenes/UI/PaperShadow.tscn"
const _SCENES: Array[String] = [
	"res://Scenes/StudentCard/student_card.tscn",
	"res://Scenes/ReportCard/report_card.tscn",
]
const _PAPERS: Array[String] = [
	"KertasMurid1", "KertasMurid2", "KertasMurid3",
	"KertasMurid4", "KertasMurid5", "KertasMurid6",
]


func test_the_template_is_a_soft_translucent_shadow_drawn_behind_its_parent() -> void:
	var shadow := (load(_TEMPLATE) as PackedScene).instantiate() as TextureRect
	track(shadow)
	assert_true(shadow != null, "PaperShadow.tscn's root must be a TextureRect")
	if shadow == null:
		return
	assert_true(shadow.show_behind_parent, "the shadow must draw under its paper, not over it")
	assert_true(shadow.material is ShaderMaterial, "the shadow needs the soft_shadow ShaderMaterial")
	assert_true(shadow.self_modulate.a < 1.0, "the shadow must be a translucent tint, not opaque")
	assert_eq(shadow.texture.resource_path if shadow.texture else "",
		"res://Assets/Images/StudentCard/card_bg.png", "the shadow is the paper's own silhouette")
	assert_eq(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a shadow must never eat a tap")
	# Full-rect anchors, so the shadow stretches with whatever paper holds it.
	assert_eq(shadow.anchor_right, 1.0, "the shadow must stretch to its paper's width")
	assert_eq(shadow.anchor_bottom, 1.0, "the shadow must stretch to its paper's height")
	# Exactly the old static Shadow's placement relative to its paper.
	assert_eq(shadow.offset_left, 14.0, "the shadow sits 14px right of its paper")
	assert_eq(shadow.offset_right, 14.0, "the shadow keeps its paper's width")
	assert_eq(shadow.offset_top, 18.0, "the shadow sits 18px below its paper")
	assert_eq(shadow.offset_bottom, 18.0, "the shadow keeps its paper's height")
	assert_true(shadow.scale.is_equal_approx(Vector2(1.03, 1.03)), "the shadow is 3% larger than its paper")


func test_every_paper_carries_its_own_shadow() -> void:
	for scene_path in _SCENES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for paper_name in _PAPERS:
			var paper := root.get_node_or_null(paper_name)
			assert_true(paper != null, "%s is missing %s" % [scene_path, paper_name])
			if paper == null:
				continue
			var shadow := paper.get_node_or_null("PaperShadow") as TextureRect
			assert_true(shadow != null, "%s/%s has no PaperShadow child" % [scene_path, paper_name])
			if shadow == null:
				continue
			assert_eq(shadow.scene_file_path, _TEMPLATE,
				"%s/%s's shadow must be the shared template, not a copy" % [scene_path, paper_name])
			assert_eq(shadow.get_index(), 0,
				"%s/%s's shadow should be its first child" % [scene_path, paper_name])
			assert_true(shadow.show_behind_parent,
				"%s/%s's shadow must draw behind its paper" % [scene_path, paper_name])


func test_the_static_stack_shadow_is_gone() -> void:
	for scene_path in _SCENES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		assert_true(root.get_node_or_null("Shadow") == null,
			"%s still has the root-level Shadow, which stays on the desk when a paper flies" % scene_path)
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `test_run(suite="paper_shadow")`
Expected: FAIL — the template does not exist, no paper has a `PaperShadow`, and both scenes still have `Shadow`.

- [ ] **Step 3: Create the template through the editor**

```
scene_manage(op="create", params={"path": "res://Scenes/UI/PaperShadow.tscn", "root_type": "TextureRect", "root_name": "PaperShadow"})
node_set_property(path="/PaperShadow", property="texture", value="res://Assets/Images/StudentCard/card_bg.png")
node_set_property(path="/PaperShadow", property="material", value="res://Scripts/Shaders/soft_shadow_material.tres")
node_set_property(path="/PaperShadow", property="self_modulate", value={"r": 0, "g": 0, "b": 0, "a": 0.33})
node_set_property(path="/PaperShadow", property="show_behind_parent", value=true)
node_set_property(path="/PaperShadow", property="mouse_filter", value=2)
node_set_property(path="/PaperShadow", property="expand_mode", value=1)
node_set_property(path="/PaperShadow", property="anchor_left", value=0)
node_set_property(path="/PaperShadow", property="anchor_top", value=0)
node_set_property(path="/PaperShadow", property="anchor_right", value=1)
node_set_property(path="/PaperShadow", property="anchor_bottom", value=1)
node_set_property(path="/PaperShadow", property="offset_left", value=14)
node_set_property(path="/PaperShadow", property="offset_top", value=18)
node_set_property(path="/PaperShadow", property="offset_right", value=14)
node_set_property(path="/PaperShadow", property="offset_bottom", value=18)
node_set_property(path="/PaperShadow", property="scale", value={"x": 1.03, "y": 1.03})
scene_save()
```
Then `filesystem_manage(op="read_text", params={"path": "res://Scenes/UI/PaperShadow.tscn"})` and confirm every value above is in the file (anchors 1.0, offsets 14/18, `show_behind_parent = true`, the two `ext_resource`s).

- [ ] **Step 4: Put a shadow in every StudentCard paper**

```
scene_open(path="res://Scenes/StudentCard/student_card.tscn")
```
For each N in 1, 2, 3, 4, 5, 6:
```
node_create(parent_path="/StudentCard/KertasMuridN", scene_path="res://Scenes/UI/PaperShadow.tscn", name="PaperShadow")
node_manage(op="move", params={"path": "/StudentCard/KertasMuridN/PaperShadow", "index": 0})
```
Then:
```
node_manage(op="delete", params={"path": "/StudentCard/Shadow"})
scene_save()
```
```bash
git diff HEAD -- '*.gd'
```
Expected: nothing.

- [ ] **Step 5: Put a shadow in every ReportCard paper**

The report card's root is also named `StudentCard` (it was copied from that screen).
```
scene_open(path="res://Scenes/ReportCard/report_card.tscn")
```
For each N in 1, 2, 3, 4, 5, 6:
```
node_create(parent_path="/StudentCard/KertasMuridN", scene_path="res://Scenes/UI/PaperShadow.tscn", name="PaperShadow")
node_manage(op="move", params={"path": "/StudentCard/KertasMuridN/PaperShadow", "index": 0})
```
Then:
```
node_manage(op="delete", params={"path": "/StudentCard/Shadow"})
scene_save()
```
```bash
git diff HEAD -- '*.gd'
git diff --stat
```
Expected: no `.gd` diff; both `.tscn` files changed, plus the new `PaperShadow.tscn`.

- [ ] **Step 6: Retire the old root-`Shadow` test**

`script_patch` on `res://tests/test_report_card.gd`:

old_text:
```gdscript
## The papers sit on a wood desk with nothing lifting them off it. A
## sibling TextureRect wearing the same soft_shadow material DayStickyNote
## uses, drawn behind the card stack, blurs card_bg.png's own alpha
## silhouette so the edge goes soft while the fill stays flat.
func test_the_paper_stack_casts_a_soft_shadow() -> void:
	var scene = load(_SCENE_PATH).instantiate()
	var shadow := scene.get_node_or_null("Shadow") as TextureRect
	# Resolve everything to bools BEFORE freeing: a freed Object reference
	# compares equal to null in GDScript, so asserting on `shadow` itself
	# after scene.free() would fail regardless of whether Shadow was there
	# (test_run_result.gd:242 has the same hazard spelled out).
	var found: bool = shadow != null
	var is_shader: bool = shadow != null and shadow.material is ShaderMaterial
	var behind: bool = shadow != null \
		and shadow.get_index() < scene.get_node("KertasMurid6").get_index()
	var tinted: bool = shadow != null and shadow.self_modulate.a < 1.0
	scene.free()
	assert_true(found, "report_card.tscn needs a Shadow TextureRect")
	assert_true(is_shader, "Shadow needs the soft_shadow ShaderMaterial")
	assert_true(behind, "Shadow must draw behind the paper stack")
	assert_true(tinted, "Shadow must be a translucent tint, not opaque")
```
new_text:
```gdscript
## The papers' soft shadow is no longer one static node behind the stack: each
## paper carries its own PaperShadow.tscn so it flies with the paper. That
## contract lives in tests/test_paper_shadow.gd (2026-09-10).
```

- [ ] **Step 7: Run the suites to verify they pass**

Run, one at a time: `test_run(suite="paper_shadow")`, `test_run(suite="report_card")`, `test_run(suite="student_card")`, `test_run(suite="student_card_layout")`
Expected: PASS, 0 failures in each.

- [ ] **Step 8: Commit**

```bash
git add Scenes/UI/PaperShadow.tscn Scenes/StudentCard/student_card.tscn Scenes/ReportCard/report_card.tscn tests/test_paper_shadow.gd tests/test_paper_shadow.gd.uid tests/test_report_card.gd
git commit -m "feat(paper): every student paper carries its own shadow" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: BuatBatik pictures bound to their tools

**Files:**
- Modify: `Scenes/Minigames/SeniBudaya/BuatBatik.tscn` (through the editor)
- Modify: `Scripts/Minigames/SeniBudaya/BuatBatik.gd` (the input-filter comment; `_apply_visual_exports()` tool block; `_get_tool_icon()`)
- Modify: `tests/test_viewport_editability.gd` (`BuatBatik.gd` 8 → 7)
- Test: `tests/test_minigame_art.gd` (append after Task 1's tests)

**Interfaces:**
- Consumes: Task 1's appended block ends with the `stretch_mode` assertion used as this task's anchor.
- Produces: a `TextureRect` named `ToolTextureRect` inside each of `ToolsContainer/Tool0..Tool3`.

- [ ] **Step 1: Write the failing tests**

`script_patch` on `res://tests/test_minigame_art.gd`:

old_text:
```gdscript
	assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"a taller phone must crop the sides, not stretch the art")
```
new_text:
```gdscript
	assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"a taller phone must crop the sides, not stretch the art")

## Which picture each BuatBatik tool shows, keyed by the tool's NODE NAME.
## _ready() shuffles the four slots -- finding the order is the puzzle -- so a
## picture dealt by slot index lands on the wrong tool (fixed 2026-09-10).
const _BATIK_TOOL_ART: Dictionary = {
	"Tool0": "res://Assets/Images/Textures/batik_tool_pencil.png",
	"Tool1": "res://Assets/Images/Textures/batik_tool_canting.png",
	"Tool2": "res://Assets/Images/Textures/batik_tool_pewarna.png",
	"Tool3": "res://Assets/Images/Textures/batik_tool_kompor.png",
}
const _BATIK_SCENE := "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"
const _BATIK_SCRIPT := "res://Scripts/Minigames/SeniBudaya/BuatBatik.gd"

## Each tool's authored picture, read by tool name, in whatever order the
## slots currently sit.
func _batik_art_by_tool(tools: Node) -> Dictionary:
	var out := {}
	for tool in tools.get_children():
		var tex_rect := tool.get_node_or_null("ToolTextureRect") as TextureRect
		out[str(tool.name)] = tex_rect.texture.resource_path if tex_rect != null and tex_rect.texture != null else ""
	return out

func test_each_batik_tool_carries_its_own_picture_through_a_shuffle() -> void:
	var root: Node = (load(_BATIK_SCENE) as PackedScene).instantiate()
	track(root)
	var tools := root.get_node("ToolsContainer")
	assert_eq(_batik_art_by_tool(tools), _BATIK_TOOL_ART,
		"each tool slot must author its own picture in the scene")
	# Reorder the slots the way _ready()'s shuffle does.
	var kids := tools.get_children()
	kids.reverse()
	for i in range(kids.size()):
		tools.move_child(kids[i], i)
	assert_eq(_batik_art_by_tool(tools), _BATIK_TOOL_ART,
		"a picture must travel with its tool when the slots are reordered")

func test_batik_export_overrides_match_by_tool_name_not_slot() -> void:
	var src := FileAccess.get_file_as_string(_BATIK_SCRIPT)
	assert_false(src.contains("tool_texs[i]"),
		"a picture dealt by slot index lands on the wrong tool after the shuffle")
	assert_true(src.contains("\"Tool0\": tool0_texture"),
		"export overrides must be matched to a tool by its node name")
	assert_false(src.contains("tex_rect.name = \"ToolTextureRect\""),
		"the tool picture is authored in the scene now, not built at runtime")

func test_batik_tools_carry_no_emoji() -> void:
	var root: Node = (load(_BATIK_SCENE) as PackedScene).instantiate()
	track(root)
	for tool in root.get_node("ToolsContainer").get_children():
		assert_true(tool.get_node_or_null("IconLabel") == null,
			"%s still carries an emoji IconLabel; its picture is authored now" % tool.name)
	assert_false(FileAccess.get_file_as_string(_BATIK_SCRIPT).contains("func _get_tool_icon"),
		"_get_tool_icon() only ever returned emoji, and nothing called it")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="minigame_art")`
Expected: the three new `batik` tests FAIL (no `ToolTextureRect` in the scene; `tool_texs[i]` still present; `IconLabel`s present).

- [ ] **Step 3: Author each tool's picture in the scene**

```
scene_open(path="res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
```
For each (N, ART) in (0, `batik_tool_pencil.png`), (1, `batik_tool_canting.png`), (2, `batik_tool_pewarna.png`), (3, `batik_tool_kompor.png`), with `T = /BuatBatik/ToolsContainer/ToolN`:
```
node_create(parent_path="T", type="TextureRect", name="ToolTextureRect")
node_set_property(path="T/ToolTextureRect", property="anchor_left", value=0)
node_set_property(path="T/ToolTextureRect", property="anchor_top", value=0)
node_set_property(path="T/ToolTextureRect", property="anchor_right", value=1)
node_set_property(path="T/ToolTextureRect", property="anchor_bottom", value=1)
node_set_property(path="T/ToolTextureRect", property="offset_left", value=0)
node_set_property(path="T/ToolTextureRect", property="offset_top", value=0)
node_set_property(path="T/ToolTextureRect", property="offset_right", value=0)
node_set_property(path="T/ToolTextureRect", property="offset_bottom", value=0)
node_set_property(path="T/ToolTextureRect", property="expand_mode", value=1)
node_set_property(path="T/ToolTextureRect", property="stretch_mode", value=5)
node_set_property(path="T/ToolTextureRect", property="mouse_filter", value=2)
node_set_property(path="T/ToolTextureRect", property="texture", value="res://Assets/Images/Textures/ART")
node_manage(op="delete", params={"path": "T/IconLabel"})
```
`node_create` appends last, so each picture draws over its slot's `Bg` panel. Then:
```
scene_save()
```
```bash
git diff HEAD -- '*.gd'
```
Expected: nothing. `scene_get_hierarchy()` shows each `ToolN` with exactly `Bg` then `ToolTextureRect`.

- [ ] **Step 4: Match the export overrides by tool name**

`script_patch` on `res://Scripts/Minigames/SeniBudaya/BuatBatik.gd`:

old_text:
```gdscript
		# Prevent tool children (Bg ColorRect, IconLabel) from stealing input focus
```
new_text:
```gdscript
		# Prevent tool children (Bg, ToolTextureRect) from stealing input focus
```

Second `script_patch` on the same file:

old_text:
```gdscript
	# Tool textures
	var tool_texs = [tool0_texture, tool1_texture, tool2_texture, tool3_texture]
	for i in range(min(4, tools_container.get_child_count())):
		var tool_node = tools_container.get_child(i)
		var icon_lbl = tool_node.get_node_or_null("IconLabel") as Label
		var tool_tex = tool_texs[i]
		if tool_tex:
			if icon_lbl: icon_lbl.visible = false
			var tex_rect = tool_node.get_node_or_null("ToolTextureRect") as TextureRect
			if not tex_rect:
				tex_rect = TextureRect.new()
				tex_rect.name = "ToolTextureRect"
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tool_node.add_child(tex_rect)
			tex_rect.texture = tool_tex
```
new_text:
```gdscript
	# Tool textures. Each ToolN authors its own ToolTextureRect in the scene,
	# so its picture travels with it through _ready()'s shuffle. These exports
	# only override that art, matched by NODE NAME -- the slots have already
	# been shuffled by now, so a slot index would deal a picture to the wrong
	# tool.
	var tool_texs := {
		"Tool0": tool0_texture,
		"Tool1": tool1_texture,
		"Tool2": tool2_texture,
		"Tool3": tool3_texture,
	}
	for tool_node in tools_container.get_children():
		var tool_tex: Texture2D = tool_texs.get(str(tool_node.name))
		var tex_rect := tool_node.get_node_or_null("ToolTextureRect") as TextureRect
		if tool_tex and tex_rect:
			tex_rect.texture = tool_tex
```

Third `script_patch` on the same file (delete the dead emoji helper — copy the block from `read_text` if the emoji bytes differ):

old_text:
```gdscript
func _get_tool_icon(tool_name: String) -> String:
	match tool_name:
		"Tool0": return "✏"
		"Tool1": return "🖊"
		"Tool2": return "🎨"
		"Tool3": return "🔥"
	return "?"

```
new_text: `` (empty)

- [ ] **Step 5: Turn the ratchet**

`script_patch` on `res://tests/test_viewport_editability.gd`:

old_text:
```gdscript
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd": 8,
```
new_text:
```gdscript
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd": 7,
```

- [ ] **Step 6: Run the suites to verify they pass**

Run, one at a time: `test_run(suite="minigame_art")`, `test_run(suite="viewport_editability")`, `test_run(suite="minigame_star_rubric")` (it preloads `BuatBatik.gd`), `test_run(suite="script_documentation")`
Expected: PASS, 0 failures in each.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Minigames/SeniBudaya/BuatBatik.tscn Scripts/Minigames/SeniBudaya/BuatBatik.gd tests/test_minigame_art.gd tests/test_viewport_editability.gd
git commit -m "fix(batik): each tool's picture travels with the tool through the shuffle" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Badminton shuttle — 2×, upright, cork leads, no growth

**Files:**
- Create: `Scripts/Minigames/Olahraga/ShuttlecockSprite.gd` (+ `.uid`)
- Create: `tests/test_shuttlecock_sprite.gd`
- Modify: `Scenes/Minigames/Olahraga/Badminton.tscn` (through the editor): `Puck/Sprite2D` scale, rotation, script
- Modify: `Scripts/Minigames/Olahraga/Badminton.gd` (Configuration group; `puck_sprite`; hit radius; `_ready()`; hit handler; `_play_hit_bounce_animation()` removed; racket squash; `_reset_puck()`)
- Test: `tests/test_badminton_visuals.gd` (append)

**Interfaces:**
- Produces `class_name ShuttlecockSprite extends Sprite2D`:
  - `func punch() -> void`
  - `func face(velocity_y: float) -> void` — cork up for a negative `velocity_y`, down otherwise
  - `func reset_pose(cork_up: bool) -> void`
  - `func rest_scale() -> Vector2`
  - `func is_cork_up() -> bool`
  - `@export var punch_scale: float = 1.6`, `@export var punch_half_duration: float = 0.26`, `@export var turn_duration: float = 0.18`
- Produces on `Badminton.gd`: `@export var puck_radius_frac: float = 0.08`.

- [ ] **Step 1: Write the failing behavioural suite**

`script_create(path="res://tests/test_shuttlecock_sprite.gd", content=...)`:

```gdscript
@tool
extends McpTestSuite

## ShuttlecockSprite owns the badminton shuttle's look. The rule under test:
## every animation returns to a REMEMBERED pose, never one read back off the
## live node -- the old hit punch did the latter, so overlapping hits grew
## the shuttle without limit (2026-09-10).
##
## Tweens are driven with Tween.custom_step(), diffed against a snapshot of
## the tree's processed tweens (the technique from test_juice.gd): the runner
## calls each test synchronously, so nothing here may await. Methods go
## through call() so the suite parses even before the class_name is
## registered. Must be @tool.

func suite_name() -> String:
	return "shuttlecock_sprite"

const _SCRIPT := preload("res://Scripts/Minigames/Olahraga/ShuttlecockSprite.gd")
## A non-uniform rest scale, like the scene's, so no test passes by accident
## on Vector2.ONE.
const _REST := Vector2(0.14, 0.1)
## The authored cork-up angle, as Badminton.tscn gives it.
const _UP := 90.0

var _sprite: Sprite2D


func setup() -> void:
	_sprite = Sprite2D.new()
	_sprite.set_script(_SCRIPT)
	_sprite.scale = _REST
	_sprite.rotation_degrees = _UP
	Engine.get_main_loop().root.add_child(_sprite)
	track(_sprite)


func teardown() -> void:
	_sprite = null


## Fast-forward every live tween the tree picked up since `snapshot`.
func _step(snapshot: Array, seconds: float) -> void:
	for tw in Engine.get_main_loop().get_processed_tweens():
		if not snapshot.has(tw) and is_instance_valid(tw) and tw.is_valid():
			tw.custom_step(seconds)


## Rotation folded into [0, 360), so turns that accumulate compare cleanly.
func _facing() -> float:
	return fposmod(_sprite.rotation_degrees, 360.0)


func test_the_authored_pose_is_the_rest_pose() -> void:
	assert_true((_sprite.call("rest_scale") as Vector2).is_equal_approx(_REST),
		"the scene's scale is the rest scale")
	assert_true(_sprite.call("is_cork_up"), "the scene's rotation is the cork-up pose")


func test_a_punch_swells_before_it_settles() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("punch")
	_step(snap, 0.26)
	assert_true(_sprite.scale.x > _REST.x * 1.5,
		"the punch must visibly swell the shuttle, got %s" % _sprite.scale)
	_step(snap, 1.0)
	assert_true(_sprite.scale.is_equal_approx(_REST),
		"a single punch must settle back at the rest scale, got %s" % _sprite.scale)


func test_overlapping_punches_settle_back_to_the_rest_scale() -> void:
	# Each hit lands mid-punch, as the 0.22s hit cooldown allows against a
	# 0.52s punch. Reading the live scale as the base would ratchet upward.
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	for i in range(5):
		_sprite.call("punch")
		_step(snap, 0.1)
	_step(snap, 2.0)
	assert_true(_sprite.scale.is_equal_approx(_REST),
		"five overlapping punches must settle at the rest scale, got %s" % _sprite.scale)


func test_face_turns_only_when_the_direction_changes() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("face", -500.0)
	_step(snap, 1.0)
	assert_true(is_equal_approx(_facing(), _UP), "still flying up must keep the cork up")
	_sprite.call("face", 500.0)
	_step(snap, 1.0)
	assert_true(is_equal_approx(_facing(), _UP + 180.0),
		"flying down must turn the cork down, got %f" % _sprite.rotation_degrees)
	assert_false(_sprite.call("is_cork_up"), "the sprite must know its cork is down")


func test_an_interrupted_turn_still_lands_exactly() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("face", 500.0)
	_step(snap, 0.05)
	_sprite.call("face", -500.0)
	_step(snap, 1.0)
	assert_true(is_equal_approx(_facing(), _UP),
		"two turns must land back on cork-up exactly, got %f" % _sprite.rotation_degrees)


func test_reset_pose_snaps_to_rest_with_the_cork_either_way() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("punch")
	_sprite.call("face", 500.0)
	_step(snap, 0.1)
	_sprite.call("reset_pose", false)
	assert_true(_sprite.scale.is_equal_approx(_REST), "a serve starts at the rest scale")
	assert_true(is_equal_approx(_facing(), _UP + 180.0), "a serve toward the player starts cork-down")
	_step(snap, 2.0)
	assert_true(_sprite.scale.is_equal_approx(_REST), "no stale punch may resume after a reset")
	assert_true(is_equal_approx(_facing(), _UP + 180.0), "no stale turn may resume after a reset")
	_sprite.call("reset_pose", true)
	assert_true(is_equal_approx(_facing(), _UP), "a serve toward the enemy starts cork-up")
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `test_run(suite="shuttlecock_sprite")`
Expected: the suite reports broken — `ShuttlecockSprite.gd` does not exist yet.

- [ ] **Step 3: Create ShuttlecockSprite.gd**

`script_create(path="res://Scripts/Minigames/Olahraga/ShuttlecockSprite.gd", content=...)`:

```gdscript
@tool
extends Sprite2D
class_name ShuttlecockSprite

## The badminton shuttle's look: its resting pose, the swell when a racket
## hits it, and the half-turn that keeps the cork leading the flight.
##
## The physics body (Badminton.tscn's Puck) never rotates or scales for a
## hit; everything the player sees move lives here, on the Sprite2D. Every
## tween below animates towards a value this script REMEMBERS, never towards
## one read back off the live node: the old hit punch read the current,
## possibly mid-punch scale as its resting size, so overlapping hits ratcheted
## the shuttle bigger and bigger (fixed 2026-09-10).
##
## The authored pose is the truth. Whatever scale and rotation the scene gives
## this sprite are its rest scale and its cork-up angle. puck.png draws the
## cork on the LEFT, so the scene turns it 90 degrees clockwise to stand it
## up; re-aligning replacement art is an editor rotate, not a code change.
##
## @tool so the editor-hosted test runner can drive it. _ready() touches
## nothing but this node's own remembered pose.

## How much the shuttle swells on a racket hit, as a multiple of its rest scale.
@export var punch_scale: float = 1.6
## Seconds to swell out, and again to settle back; a punch lasts twice this.
@export var punch_half_duration: float = 0.26
## Seconds for the half-turn after a hit reverses the shuttle's direction.
@export var turn_duration: float = 0.18

var _rest_scale: Vector2 = Vector2.ONE
var _cork_up_degrees: float = 0.0
var _cork_up: bool = true
## Where the running (or last) turn is headed, in degrees. Grows by 180 per
## turn, so a turn interrupted mid-way still has an exact target.
var _target_degrees: float = 0.0
var _punch_tween: Tween = null
var _turn_tween: Tween = null


func _ready() -> void:
	_rest_scale = scale
	_cork_up_degrees = rotation_degrees
	_target_degrees = rotation_degrees
	_cork_up = true


## The scale the shuttle settles back to after every punch.
func rest_scale() -> Vector2:
	return _rest_scale


## True while the cork points up the screen.
func is_cork_up() -> bool:
	return _cork_up


## Swell and settle, starting over if a punch is already running. Always ends
## exactly at the rest scale, however many punches overlap.
func punch() -> void:
	_kill(_punch_tween)
	_punch_tween = create_tween()
	_punch_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_punch_tween.tween_property(self, "scale", _rest_scale * punch_scale, punch_half_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", _rest_scale, punch_half_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Point the cork the way the shuttle is flying: up for a negative
## `velocity_y`, down otherwise. Turns half a circle only when that direction
## changed, and always towards an exact target angle.
func face(velocity_y: float) -> void:
	var going_up := velocity_y < 0.0
	if going_up == _cork_up:
		return
	_cork_up = going_up
	_target_degrees += 180.0
	_kill(_turn_tween)
	_turn_tween = create_tween()
	_turn_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_turn_tween.tween_property(self, "rotation_degrees", _target_degrees, turn_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Snap to the rest scale and to cork-up or cork-down, with no animation.
## Called on every serve, while the puck teleports to its serve spot.
func reset_pose(cork_up: bool) -> void:
	_kill(_punch_tween)
	_kill(_turn_tween)
	scale = _rest_scale
	_cork_up = cork_up
	_target_degrees = _cork_up_degrees if cork_up else _cork_up_degrees + 180.0
	rotation_degrees = _target_degrees


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
```

Then `filesystem_manage(op="scan")` so the new `class_name` is registered before anything types against it.

- [ ] **Step 4: Run the suite to verify it passes**

Run: `test_run(suite="shuttlecock_sprite")`
Expected: PASS, 6 tests, 0 failures.

- [ ] **Step 5: Write the failing Badminton tests**

`script_patch` on `res://tests/test_badminton_visuals.gd`:

old_text:
```gdscript
		assert_contains(text, export_name,
			"%s is no longer assigned in the scene" % export_name)
```
new_text:
```gdscript
		assert_contains(text, export_name,
			"%s is no longer assigned in the scene" % export_name)


const SCRIPT_PATH := "res://Scripts/Minigames/Olahraga/Badminton.gd"
## puck.png is a 1240x1754 canvas; the old scale drew it in an 86.4px box,
## the hit circle's diameter. Doubled on 2026-09-10.
const _PUCK_SCALE := Vector2(0.1393548, 0.0985176)


func test_the_puck_is_twice_its_old_size() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var sprite := root.get_node("Puck/Sprite2D") as Sprite2D
	assert_true(sprite.scale.is_equal_approx(_PUCK_SCALE),
		"Puck/Sprite2D should be drawn at 2x its old scale, got %s" % sprite.scale)
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "@export var puck_radius_frac: float = 0.08",
		"the hit circle doubles with the picture, as an Inspector knob")
	assert_false(src.contains("screen_size.x * 0.04"), "the old literal hit radius must be gone")


func test_the_shuttle_stands_cork_up_in_the_scene() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var sprite := root.get_node("Puck/Sprite2D") as Sprite2D
	assert_true(is_equal_approx(sprite.rotation_degrees, 90.0),
		"puck.png draws the cork on the left; 90 degrees clockwise stands it up")
	assert_eq(sprite.get_script().resource_path,
		"res://Scripts/Minigames/Olahraga/ShuttlecockSprite.gd",
		"the shuttle's look is owned by ShuttlecockSprite.gd")


func test_hits_drive_the_shuttle_rather_than_flipping_it() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("flip_v"),
		"flip_v mirrors a sideways shuttle invisibly; the cork turns instead")
	assert_false(src.contains("var base_scale: Vector2 = puck_sprite.scale"),
		"reading the live, mid-punch scale as the base is what grew the puck")
	assert_contains(src, "puck_sprite.punch()", "a hit swells the shuttle through ShuttlecockSprite")
	assert_contains(src, "puck_sprite.face(puck.linear_velocity.y)",
		"a hit turns the cork to lead the new flight")
	assert_contains(src, "puck_sprite.reset_pose(target_vel.y < 0.0)",
		"a serve snaps the cork toward the receiver")


func test_the_racket_squash_returns_to_remembered_values() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("var base_scale: Vector2 = sprite.scale"),
		"the racket squash must not read its rest scale off a mid-squash sprite")
	assert_false(src.contains("var idle_texture: Texture2D = sprite.texture"),
		"the racket must not capture its idle art mid-swap")
	assert_contains(src, "_racket_rest_scale", "each racket's rest scale is stored once")
	assert_contains(src, "_racket_idle_texture", "each racket's idle art is stored once")
```

Run: `test_run(suite="badminton_visuals")`
Expected: the four new tests FAIL; the four older ones pass.

- [ ] **Step 6: Resize, rotate and script the shuttle in the scene**

```
scene_open(path="res://Scenes/Minigames/Olahraga/Badminton.tscn")
node_set_property(path="/Badminton/Puck/Sprite2D", property="scale", value={"x": 0.1393548, "y": 0.0985176})
node_set_property(path="/Badminton/Puck/Sprite2D", property="rotation_degrees", value=90)
script_attach(path="/Badminton/Puck/Sprite2D", script_path="res://Scripts/Minigames/Olahraga/ShuttlecockSprite.gd")
scene_save()
```
If `rotation_degrees` is rejected, set `rotation` to `1.5707964` instead. Then:
```bash
git diff HEAD -- '*.gd'
git diff -- Scenes/Minigames/Olahraga/Badminton.tscn
```
Expected: no `.gd` diff. The scene diff shows the new `ext_resource` for `ShuttlecockSprite.gd`, and `rotation = 1.5707964`, the doubled `scale` and `script = ExtResource(...)` on `Puck/Sprite2D`.

- [ ] **Step 7: Patch Badminton.gd**

Seven `script_patch` calls on `res://Scripts/Minigames/Olahraga/Badminton.gd`.

7a — the hit-radius knob. old_text:
```gdscript
@export_group("Configuration")
## Speed cap (px/s) on the player paddle's drag-follow movement.
@export var max_paddle_speed: float = 2400.0
```
new_text:
```gdscript
@export_group("Configuration")
## Speed cap (px/s) on the player paddle's drag-follow movement.
@export var max_paddle_speed: float = 2400.0
## The shuttle's hit circle radius, as a fraction of screen width. Doubled
## from 0.04 with the shuttle's picture on 2026-09-10, so the circle still
## matches the art's box (Puck/Sprite2D's scale sets the picture's size).
@export var puck_radius_frac: float = 0.08
```

7b — type the sprite. old_text:
```gdscript
@onready var puck_sprite: Sprite2D = $Puck/Sprite2D
```
new_text:
```gdscript
@onready var puck_sprite: ShuttlecockSprite = $Puck/Sprite2D
```

7c — the hit radius. old_text:
```gdscript
			col.shape.radius = screen_size.x * 0.04
```
new_text:
```gdscript
			col.shape.radius = screen_size.x * puck_radius_frac
```

7d — remember the rackets' poses. old_text:
```gdscript
	_apply_visual_exports()

	if player_goal:
		player_goal.body_entered.connect(_on_player_goal)
```
new_text:
```gdscript
	_apply_visual_exports()
	_remember_racket_poses()

	if player_goal:
		player_goal.body_entered.connect(_on_player_goal)
```

7e — the hit handler. old_text:
```gdscript
var _puck_hit_cooldown: float = 0.0

# Hit Bounce Arc Scale Animation on Puck Visual + Cute Racket Squash Animation
func _on_puck_body_entered(body: Node) -> void:
	if is_scoring_delay:
		return
	if (body == player_paddle or body == enemy_paddle) and _puck_hit_cooldown <= 0.0:
		_puck_hit_cooldown = 0.22 # Prevent multi-hit trigger jitter
		_redirect_puck_towards_opponent(body)
		_play_hit_bounce_animation()
		_play_racket_squash_animation(body as CharacterBody2D)
		if puck_sprite:
			puck_sprite.flip_v = not puck_sprite.flip_v
```
new_text:
```gdscript
var _puck_hit_cooldown: float = 0.0
## Each racket sprite's resting scale and idle art, remembered once in
## _ready() so a squash always returns to them -- never to values read off a
## sprite that is still mid-squash or mid-swap.
var _racket_rest_scale: Dictionary = {}
var _racket_idle_texture: Dictionary = {}
## The running squash per racket sprite, killed before the next one starts.
var _racket_tweens: Dictionary = {}

# Racket hit: re-aim the puck, swell the shuttle, turn its cork to lead the
# new flight, and squash the racket that hit it.
func _on_puck_body_entered(body: Node) -> void:
	if is_scoring_delay:
		return
	if (body == player_paddle or body == enemy_paddle) and _puck_hit_cooldown <= 0.0:
		_puck_hit_cooldown = 0.22 # Prevent multi-hit trigger jitter
		_redirect_puck_towards_opponent(body)
		puck_sprite.punch()
		puck_sprite.face(puck.linear_velocity.y)
		_play_racket_squash_animation(body as CharacterBody2D)
```

7f — delete the old punch and rewrite the racket squash. old_text:
```gdscript
func _play_hit_bounce_animation() -> void:
	if not puck: return

	# Punch relative to the node's resting scale -- a Sprite2D showing a
	# texture much larger than its display size (see shuttlecock_texture)
	# rests at a fractional scale, not 1.0, so animating to absolute
	# values here would permanently blow it up to native texture size.
	var base_scale: Vector2 = puck_sprite.scale

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Scale the sprite only so collision shape stays constant (prevents physics jitter)
	tw.tween_property(puck_sprite, "scale", base_scale * 1.6, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(puck_sprite, "scale", base_scale, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _play_racket_squash_animation(racket: CharacterBody2D) -> void:
	if not racket or not is_instance_valid(racket): return
	var sprite: Sprite2D = player_paddle_sprite if racket == player_paddle else enemy_paddle_sprite

	# Swap to the "hit" pose for the duration of the squash, then back to
	# whatever the sprite was actually showing -- not the @export texture,
	# which may be null while the scene's own baked texture is what is
	# really on screen.
	var idle_texture: Texture2D = sprite.texture
	if racket_hit_texture:
		sprite.texture = racket_hit_texture

	# Punch relative to the node's resting scale -- see _play_hit_bounce_animation's
	# note on why an absolute (1,1) target would be wrong once a racket texture
	# is assigned (its rest scale is a fraction, sized to fit the touch target).
	var base_scale: Vector2 = sprite.scale

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
```
new_text:
```gdscript
## Remember each racket sprite's resting scale and idle art, once, after the
## @export art has been applied. The idle art is whatever the sprite really
## shows -- the scene's baked texture when the @export is null.
func _remember_racket_poses() -> void:
	for sprite in [player_paddle_sprite, enemy_paddle_sprite]:
		if sprite:
			_racket_rest_scale[sprite] = sprite.scale
			_racket_idle_texture[sprite] = sprite.texture

func _play_racket_squash_animation(racket: CharacterBody2D) -> void:
	if not racket or not is_instance_valid(racket): return
	var sprite: Sprite2D = player_paddle_sprite if racket == player_paddle else enemy_paddle_sprite
	if not _racket_rest_scale.has(sprite):
		return

	# Squash relative to the REMEMBERED rest scale: a racket texture rests at
	# a fractional scale sized to its touch target, and a hit can land while
	# the previous squash is still running.
	var base_scale: Vector2 = _racket_rest_scale[sprite]
	var idle_texture: Texture2D = _racket_idle_texture[sprite]

	var previous: Tween = _racket_tweens.get(sprite)
	if previous and previous.is_valid():
		previous.kill()

	# Swap to the "hit" pose for the duration of the squash.
	if racket_hit_texture:
		sprite.texture = racket_hit_texture

	var tw = create_tween()
	_racket_tweens[sprite] = tw
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
```
(The three `tween_property` lines and the `tween_callback` that restores `idle_texture` stay as they are, below this block.)

7g — the serve. Two patches. old_text:
```gdscript
		puck.scale = Vector2(1.0, 1.0)
```
new_text:
```gdscript
		puck.scale = Vector2(1.0, 1.0)
		# The cork leads: it faces the receiver before the serve flies.
		puck_sprite.reset_pose(target_vel.y < 0.0)
```
Then old_text:
```gdscript
		var tween = create_tween()
		_serve_tween = tween
```
new_text:
```gdscript
		# One serve at a time -- a second lob tween would fight this one over
		# the body's position and scale.
		if _serve_tween and _serve_tween.is_valid():
			_serve_tween.kill()
		var tween = create_tween()
		_serve_tween = tween
```

- [ ] **Step 8: Run the suites to verify they pass**

Run, one at a time: `test_run(suite="badminton_visuals")`, `test_run(suite="shuttlecock_sprite")`, `test_run(suite="minigame_star_rubric")` (preloads `Badminton.gd`, so this proves it still parses against the new type), `test_run(suite="viewport_editability")`, `test_run(suite="script_documentation")`
Expected: PASS, 0 failures in each. Also `logs_read(source="editor")` shows no parse error for `Badminton.gd`.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Minigames/Olahraga/ShuttlecockSprite.gd Scripts/Minigames/Olahraga/ShuttlecockSprite.gd.uid Scripts/Minigames/Olahraga/Badminton.gd Scenes/Minigames/Olahraga/Badminton.tscn tests/test_shuttlecock_sprite.gd tests/test_shuttlecock_sprite.gd.uid tests/test_badminton_visuals.gd
git commit -m "fix(badminton): 2x upright shuttle that leads with its cork and stops growing" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: MainBola — drag the goalie in the 2D editor

**Files:**
- Modify: `Scenes/Minigames/Olahraga/MainBola.tscn` (through the editor): Goalie position, then a design-space re-save
- Modify: `Scripts/Minigames/Olahraga/MainBola.gd` (Layout header; `goalie_depth_frac` removed; `goalie_feet_frac` doc; members; `_notification`; `_setup_layout()`; `_place_goalie()`, `_design_size()`, `design_to_screen()`)
- Test: `tests/test_main_bola_layout.gd`

**Interfaces:**
- Produces on `MainBola.gd`: `static func design_to_screen(design_pos: Vector2, design: Vector2, screen: Vector2) -> Vector2`, `func _place_goalie() -> void`, `func _design_size() -> Vector2`.

- [ ] **Step 1: Write the failing tests**

`script_patch` on `res://tests/test_main_bola_layout.gd`:

old_text:
```gdscript
	"goalie_width_frac", "goalie_height_frac", "goalie_depth_frac",
```
new_text:
```gdscript
	"goalie_width_frac", "goalie_height_frac",
```

Second patch — old_text:
```gdscript
	# the goal line goalie_depth_frac picks. This was a hardcoded 0.78
```
new_text:
```gdscript
	# the spot the Goalie node is dragged to. This was a hardcoded 0.78
```

Third patch — old_text:
```gdscript
	assert_contains(src, "is_resolving",
		"breathing must yield to the dive animation")
```
new_text:
```gdscript
	assert_contains(src, "is_resolving",
		"breathing must yield to the dive animation")


## Knobs the draggable goalie retired on 2026-09-10. Named so a revert is loud.
const RETIRED_LAYOUT_EXPORTS: Array[String] = ["goalie_depth_frac"]

## The goal mouth in design space, from the default fractions: top
## 0.28 x 1920, height 0.28 x 1920, width 0.88 x 1080, centred.
const GOAL_MOUTH_DESIGN := Rect2(64.8, 537.6, 950.4, 537.6)


## The text of one function, from its `func` line up to the next `func`.
func _function_body(src: String, fn: String) -> String:
	var at := src.find("func %s(" % fn)
	if at == -1:
		return ""
	var end := src.find("\nfunc ", at + 1)
	return src.substr(at, end - at) if end != -1 else src.substr(at)


func test_goalie_depth_knob_is_retired() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in RETIRED_LAYOUT_EXPORTS:
		assert_false(src.contains(retired),
			"%s is superseded by dragging the Goalie in the 2D editor" % retired)


func test_layout_measures_the_root_not_the_editor_viewport() -> void:
	# Inside the editor the viewport rect is a 2x2 stub (confirmed live on
	# 2026-09-10): the whole layout collapsed into the top-left corner, with
	# the goalie a speck at (1, 0.99).
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var layout := _function_body(src, "_setup_layout")
	assert_false(layout.contains("get_viewport_rect()"),
		"_setup_layout() must not measure the editor's stub viewport")
	assert_contains(layout, "screen_size = size",
		"_setup_layout() must measure the root Control's own size")
	assert_contains(src, "NOTIFICATION_RESIZED",
		"the layout must follow a resize of the root")


func test_the_editor_never_moves_the_goalie() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var layout := _function_body(src, "_setup_layout")
	assert_false(layout.contains("goalie.global_position ="),
		"_setup_layout() must not compute the Goalie's position")
	assert_contains(layout, "_place_goalie()",
		"_setup_layout() hands the Goalie to _place_goalie()")
	var place := _function_body(src, "_place_goalie")
	assert_contains(place, "Engine.is_editor_hint()",
		"_place_goalie() must leave the Goalie where he was dragged in the editor")
	assert_contains(place, "_goalie_design_pos",
		"in game the Goalie's authored position is mapped, not recomputed")


func test_the_scene_goalie_stands_inside_the_goal_mouth() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var pos := (root.get_node("Goalie") as Node2D).position
	assert_true(GOAL_MOUTH_DESIGN.has_point(pos),
		"the Goalie is authored at %s, outside the goal mouth %s" % [pos, GOAL_MOUTH_DESIGN])


func test_design_to_screen_maps_each_axis_proportionally() -> void:
	var s: Script = load(SCRIPT_PATH)
	var design := Vector2(1080, 1920)
	var same: Vector2 = s.call("design_to_screen", Vector2(540, 946.176), design, design)
	assert_true(same.is_equal_approx(Vector2(540, 946.176)),
		"at the design size the authored position is used as-is, got %s" % same)
	var tall: Vector2 = s.call("design_to_screen", Vector2(540, 960), design, Vector2(1080, 2340))
	assert_true(tall.is_equal_approx(Vector2(540, 1170)),
		"on a taller phone he moves down in proportion, like the goal, got %s" % tall)
	var wide: Vector2 = s.call("design_to_screen", Vector2(270, 960), design, Vector2(1440, 1920))
	assert_true(wide.is_equal_approx(Vector2(360, 960)),
		"on a wider screen he moves sideways in proportion, got %s" % wide)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="main_bola_layout")`
Expected: the five new tests FAIL — `goalie_depth_frac` present; `get_viewport_rect()` in `_setup_layout`; no `_place_goalie`; the Goalie sits at (1, 0.9856), outside the mouth; no `design_to_screen`.

- [ ] **Step 3: Author the goalie's spot in the scene (old script still loaded)**

```
scene_open(path="res://Scenes/Minigames/Olahraga/MainBola.tscn", force_reload=true)
node_set_property(path="/MainBola/Goalie", property="position", value={"x": 540, "y": 946.176})
scene_save()
```
```bash
git diff HEAD -- '*.gd'
git diff -- Scenes/Minigames/Olahraga/MainBola.tscn
```
Expected: no `.gd` diff; the scene diff changes only the Goalie's `position` line, to `Vector2(540, 946.176)` — exactly what the old defaults produce at 1080×1920 (537.6 + 537.6 × 0.76).

- [ ] **Step 4: Patch MainBola.gd**

Seven `script_patch` calls on `res://Scripts/Minigames/Olahraga/MainBola.gd`.

4a — the Layout header. old_text:
```gdscript
# positions. Each knob below is a fraction of the viewport; changing one
# re-runs _setup_layout() immediately, in the editor as well as at runtime.
@export_group("Layout")
```
new_text:
```gdscript
# positions. Each knob below is a fraction of the viewport; changing one
# re-runs _setup_layout() immediately, in the editor as well as at runtime.
# The Goalie is the one exception: drag him in the 2D editor, and
# _place_goalie() maps where he was put onto the real screen at runtime.
@export_group("Layout")
```

4b — retire `goalie_depth_frac`. old_text:
```gdscript
## How far the goalkeeper stands into the goal, as a fraction of goal height
## measured down from the goal's top edge.
@export_range(0.0, 1.0, 0.005) var goalie_depth_frac: float = 0.76:
	set(value):
		goalie_depth_frac = value
		if is_inside_tree():
			_setup_layout()

## Where the keeper's feet sit, as a fraction of his sprite height measured
## down from the sprite's top edge. 1.0 stands him on the goal line that
## goalie_depth_frac picks; kiper_idle.png draws the feet flush with the
```
new_text:
```gdscript
## Where the keeper's feet sit, as a fraction of his sprite height measured
## down from the sprite's top edge. 1.0 stands him on the Goalie node's own
## origin -- the spot he is dragged to in the 2D editor. kiper_idle.png
## draws the feet flush with the
```

4c — members. old_text:
```gdscript
var goal_bot_y:   float
var goalie_half_w: float
```
new_text:
```gdscript
var goal_bot_y:   float
var goalie_half_w: float
## The Goalie's authored position in design space -- the project's
## 1080x1920 base size -- wherever he was dragged in the 2D editor. Captured
## at the first in-game layout, before anything moves him.
var _goalie_design_pos: Vector2 = Vector2.ZERO
var _goalie_design_captured: bool = false
```

4d — follow resizes. old_text:
```gdscript
	# Note: start_minigame() and activate_minigame() are called externally
	# by MinigameMenu after the scene is instantiated and faded in.
```
new_text:
```gdscript
	# Note: start_minigame() and activate_minigame() are called externally
	# by MinigameMenu after the scene is instantiated and faded in.


## Re-lay out whenever the root is resized, in the editor as well as in
## game. NOTIFICATION_RESIZED can arrive before _ready(), while the @onready
## node references are still null; is_node_ready() skips that one.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_setup_layout()
```

4e — measure the root. old_text:
```gdscript
## Affects: the position and size of FieldBG, GoalBack, GoalNet, Crossbar,
## PostLeft, PostRight, GoalArea's collision shape, Goalie (and its
## CollisionShape2D and GFX), Ball (same), and TargetBox. Writes the cached
## goal_left_x / goal_right_x / goal_top_y / goal_bot_y / ball_start_pos /
## goalie_base_pos values the shot resolution reads.
func _setup_layout() -> void:
	screen_size = get_viewport_rect().size
	var sw: float = screen_size.x
```
new_text:
```gdscript
## Affects: the position and size of FieldBG, GoalBack, GoalNet, Crossbar,
## PostLeft, PostRight, GoalArea's collision shape, the Goalie's
## CollisionShape2D and GFX (his position belongs to _place_goalie()), Ball
## (and its shape and GFX), and TargetBox. Writes the cached goal_left_x /
## goal_right_x / goal_top_y / goal_bot_y / ball_start_pos values the shot
## resolution reads.
func _setup_layout() -> void:
	# The root's own size, not the viewport's: inside the editor the viewport
	# rect is a 2x2 stub, which collapsed this whole layout into the top-left
	# corner. The root is full-rect, so in game this is the screen and in the
	# editor it is the 1080x1920 design size.
	screen_size = size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var sw: float = screen_size.x
```

4f — hand the goalie over. old_text:
```gdscript
	if goalie:
		# Place goalie grounded on the goal line inside Gawang image
		goalie.global_position = Vector2(sw * 0.5, goal_top + goal_height * goalie_depth_frac)
		goalie_base_pos = goalie.global_position
```
new_text:
```gdscript
	if goalie:
		_place_goalie()
```

4g — the placement helpers. old_text:
```gdscript
# ─── Field markings (_draw callback on Node2D) ───────────────────────────────
func _setup_field_markings() -> void:
```
new_text:
```gdscript
## Put the Goalie where he was authored. In the editor that means leaving
## him exactly where he was dragged -- this never moves him there. In game
## his design-space position is mapped onto the real screen by the same
## proportional rule the goal follows, so on a taller phone he moves down
## with it.
##
## Affects: the Goalie's position (in game only) and goalie_base_pos, the
## origin the dive and the reset tween read.
func _place_goalie() -> void:
	if Engine.is_editor_hint():
		goalie_base_pos = goalie.global_position
		return
	if not _goalie_design_captured:
		_goalie_design_pos = goalie.position
		_goalie_design_captured = true
	goalie.position = design_to_screen(_goalie_design_pos, _design_size(), screen_size)
	goalie_base_pos = goalie.global_position


## The project's base resolution -- the space the scene is authored in.
func _design_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1920)))


## Map a design-space point onto a screen of size `screen`, proportionally on
## each axis -- the rule every fraction in this layout already follows.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func design_to_screen(design_pos: Vector2, design: Vector2, screen: Vector2) -> Vector2:
	if design.x <= 0.0 or design.y <= 0.0:
		return design_pos
	return Vector2(design_pos.x / design.x * screen.x, design_pos.y / design.y * screen.y)


# ─── Field markings (_draw callback on Node2D) ───────────────────────────────
func _setup_field_markings() -> void:
```

- [ ] **Step 5: Re-save the scene in design space**

The new `_setup_layout()` now lays the scene out at 1080×1920 in the editor. Reload so it runs, confirm, and save:
```
scene_open(path="res://Scenes/Minigames/Olahraga/MainBola.tscn", force_reload=true)
node_get_properties(path="/MainBola/Goalie", fields=["position"])
node_get_properties(path="/MainBola/Ball", fields=["position"])
scene_save()
```
Expected: Goalie `(540, 946.176)` (untouched); Ball `(540, 1651.2)` (0.86 × 1920).
```bash
git diff HEAD -- '*.gd'
git diff --stat -- Scenes/Minigames/Olahraga/MainBola.tscn
```
Expected: the `.gd` diff is `MainBola.gd` only. The `.tscn` now carries design-space values for GoalArea, TargetBox, Ball and the GFX nodes. If the scene file did not change (the editor saw nothing dirty), set `/MainBola/Goalie` `position` to `{"x": 540, "y": 946.176}` once more and `scene_save()` again.

- [ ] **Step 6: Run the suites to verify they pass**

Run, one at a time: `test_run(suite="main_bola_layout")`, `test_run(suite="minigame_star_rubric")` (preloads `MainBola.gd`), `test_run(suite="viewport_editability")` (`MainBola.gd` stays at 2), `test_run(suite="script_documentation")`
Expected: PASS, 0 failures in each.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Minigames/Olahraga/MainBola.gd Scenes/Minigames/Olahraga/MainBola.tscn tests/test_main_bola_layout.gd
git commit -m "feat(mainbola): drag the goalie in the 2D editor" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: The day's sky — full turn, easing out

**Files:**
- Modify: `Scripts/SchoolSimulation/BookClockWidget.gd` (class doc; Motion group doc; both pose defaults; `transition_duration` doc; `ease_in_out`; `transition_to()`)
- Test: `tests/test_book_clock_phases.gd`, `tests/test_sky_transition.gd`

**Interfaces:**
- Consumes: nothing new. `SchoolDay.gd` keeps calling `transition_to(BookClockWidget.Phase.EVENING, phase1_dur + _phase_duration())`.
- Produces: `dawn_rotation_degrees` = 60.0, `evening_rotation_degrees` = −300.0, `ease_in_out` = false, and SINE/OUT in `transition_to()`.

- [ ] **Step 1: Write the failing tests**

`script_patch` on `res://tests/test_book_clock_phases.gd` — old_text:
```gdscript
func test_each_pose_sits_on_the_sky_it_is_named_for() -> void:
	var w := _widget()
	assert_eq(w.dawn_rotation_degrees, -90.0, "dawn should be morning breaking")
	assert_eq(w.evening_rotation_degrees, -270.0, "evening should be dusk")
	w.free()
```
new_text:
```gdscript
func test_each_pose_sits_on_the_sky_it_is_named_for() -> void:
	# Picked from a 12-angle contact sheet of the real composite on
	# 2026-09-10: 60 shows the same frame as -300, the darkest one.
	var w := _widget()
	assert_eq(w.dawn_rotation_degrees, 60.0, "dawn should open on the dark sky")
	assert_eq(w.evening_rotation_degrees, -300.0, "evening should close on the dark sky")
	w.free()


func test_the_day_is_one_full_turn() -> void:
	# Dark to dark on the same frame: dawn sits exactly one turn above
	# evening, so sunrise, midday and dusk all pass in between.
	var w := _widget()
	assert_true(is_equal_approx(w.dawn_rotation_degrees - w.evening_rotation_degrees, 360.0),
		"the sky should turn exactly one full circle across the day")
	w.free()
```

Second patch, same file — old_text:
```gdscript
	# Chosen in motion-lab on 2026-09-07: SINE/IN_OUT over 2.0s. A sine
	# ease-in-out is the gentlest of the twelve at both ends, which is
	# what a sky wheeling overhead wants -- no snap into or out of rest.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "Tween.TRANS_SINE", "the tuned transition is SINE")
	assert_contains(src, "Tween.EASE_IN_OUT", "the tuned ease is IN_OUT")
```
new_text:
```gdscript
	# 2026-09-10: the day eases OUT -- it sets off briskly from dawn and
	# settles gently into evening. SINE/OUT over 2.0s per phase is the
	# starting preset; a motion-lab token re-tunes it here and in the script.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "Tween.TRANS_SINE", "the tuned transition is SINE")
	assert_contains(src, "Tween.EASE_OUT", "the day eases out")
	assert_false(src.contains("Tween.EASE_IN_OUT"), "the in-out ease is retired")
```

`script_patch` on `res://tests/test_sky_transition.gd` — old_text:
```gdscript
func test_the_sweep_eases_in_and_out() -> void:
	# smoothstep's defining property: it is slower than linear in the
	# first quarter, faster than linear across the middle.
	var w := _sized_widget()
	assert_true(w.get("ease_in_out"), "the widget must ship with easing on")
	w.call("set_progress", 0.25)
	assert_true(w.call("eased_progress") < 0.25,
		"the first quarter of the day must move less than linear (ease in)")
	w.call("set_progress", 0.75)
	assert_true(w.call("eased_progress") > 0.75,
		"the last quarter must have already covered more than linear (ease out)")
	w.call("set_progress", 0.5)
	assert_true(absf(float(w.call("eased_progress")) - 0.5) < 0.001,
		"the easing must stay symmetric about the midpoint")
```
new_text:
```gdscript
func test_the_tween_owns_the_easing() -> void:
	# Since 2026-09-10 the sweep eases OUT in transition_to()'s tween. The
	# smoothstep layer would put an ease-in back under it, so it ships off
	# and progress maps onto the arc linearly.
	var w := _sized_widget()
	assert_false(w.get("ease_in_out"), "the smoothstep layer must ship off")
	for p in [0.25, 0.5, 0.75]:
		w.call("set_progress", p)
		assert_true(absf(float(w.call("eased_progress")) - p) < 0.001,
			"with the layer off, progress %f must map linearly" % p)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="book_clock_phases")`, then `test_run(suite="sky_transition")`
Expected: `test_each_pose_sits_on_the_sky_it_is_named_for`, `test_the_day_is_one_full_turn`, `test_transition_carries_the_tuned_motion_lab_preset` and `test_the_tween_owns_the_easing` FAIL. Everything else passes.

- [ ] **Step 3: Patch BookClockWidget.gd**

Seven `script_patch` calls on `res://Scripts/SchoolSimulation/BookClockWidget.gd`. Do **not** open its scene.

3a — class doc. old_text:
```gdscript
## foreground painted over it. As the school day advances, set_progress()
## turns the sky so the bright half sweeps away and the night half swings
## in, and the whole screen reads as one day passing.
```
new_text:
```gdscript
## foreground painted over it. As the school day advances, set_progress()
## turns the sky one full circle -- from the dark of dawn, through sunrise
## and the bright midday, back round to the dark of evening -- and the whole
## screen reads as one day passing.
```

3b — Motion group doc. old_text:
```gdscript
## The defaults reproduce the old single -180 sweep exactly. The day was
## two deliberate transitions between three named poses from 2026-09-07,
## with the event pinned to the middle one; from 2026-09-10 it is one
## continuous sweep between these two poses, and the event still rolls at
## the midpoint but the sky no longer stops there.
```
new_text:
```gdscript
## The day was two deliberate transitions between three named poses from
## 2026-09-07, with the event pinned to the middle one; from 2026-09-10 it
## is one continuous sweep between these two poses, and the event still
## rolls at the midpoint but the sky no longer stops there. Later that day
## the sweep grew from a half turn to a full one, starting and ending on
## the darkest frame of the sky art.
```

3c — dawn. old_text:
```gdscript
## The sky's angle at the start of the school day: morning breaking,
## bright sky opening out of the night half.
##
## Dawn and evening were 0 / -180 until a 2026-09-07 screenshot pass
## showed 0 renders as NIGHT, not morning -- the single sweep this
## replaced started at the same value and made the same "morning" claim
## in its docstring, so the art and the naming had disagreed since the
## sweep was written. Shifting the whole arc one quarter-turn puts
## each pose on the sky it is named for, and keeps the sweep
## counter-clockwise (monotonically decreasing) as the mechanism
## reference asks. A third, midday pose sat between them from
## 2026-09-07 until 2026-09-10, when it was retired -- see
## current_rotation_degrees().
@export var dawn_rotation_degrees: float = -90.0:
```
new_text:
```gdscript
## The sky's angle at the start of the school day: still dark, just
## before sunrise.
##
## 60 is the same view as -300, the darkest frame of the sky art, picked
## from a 12-angle contact sheet of the real composite on 2026-09-10 --
## the old -90 opened the day half dark, half bright blue. Dawn sits one
## full turn above evening, so the day sweeps dark -> orange sunrise ->
## blue midday -> dusk -> dark, counter-clockwise (monotonically
## decreasing) as the mechanism reference asks. The poses were 0 / -180
## before 2026-09-07 and -90 / -270 until 2026-09-10; a third, midday pose
## sat between them until it was retired -- see current_rotation_degrees().
@export var dawn_rotation_degrees: float = 60.0:
```

3d — evening. old_text:
```gdscript
## The sky's angle when the school day ends: dusk, first stars returning.
@export var evening_rotation_degrees: float = -270.0:
```
new_text:
```gdscript
## The sky's angle when the school day ends: dark again, on the same frame
## the day started on, one full turn later.
@export var evening_rotation_degrees: float = -300.0:
```

3e — duration doc. old_text:
```gdscript
## How long one phase of the school day takes, in seconds -- the day has
## two, dawn-to-midday and midday-to-evening, each this length. Chosen in
## motion-lab on 2026-09-07 alongside SINE/IN_OUT.
```
new_text:
```gdscript
## How long one phase of the school day takes, in seconds -- the day has
## two, dawn-to-midday and midday-to-evening, each this length, and the
## sky sweeps once across both. 2.0 was chosen in motion-lab on 2026-09-07
## for a half turn; the full turn of 2026-09-10 kept it, so the sky now
## spins twice as fast -- retune it in motion-lab alongside the ease.
```

3f — smoothstep off. old_text:
```gdscript
## When true, progress runs through smoothstep before it maps to an
## angle, so the sweep eases in and out even under a linear driver.
## SchoolDay.gd also eases its own tween; the two compose harmlessly.
@export var ease_in_out: bool = true:
```
new_text:
```gdscript
## When true, progress runs through smoothstep before it maps to an
## angle, so the sweep eases in and out even under a linear driver.
## Off since 2026-09-10: transition_to()'s tween eases OUT, and smoothstep
## underneath it would put the ease-in back.
@export var ease_in_out: bool = false:
```

3g — the ease. old_text:
```gdscript
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
```
new_text:
```gdscript
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 4: Run the suites to verify they pass**

Run, one at a time: `test_run(suite="book_clock_phases")`, `test_run(suite="sky_transition")`, `test_run(suite="school_day")`, `test_run(suite="script_documentation")`
Expected: PASS, 0 failures in each.

- [ ] **Step 5: Check the new day offline**

`SchoolDay` needs a scheduled week to reach, so render the day instead — the same maths as `_fit_layers()`, at SINE/OUT's positions for times 0, ¼, ½, ¾ and 1: progress `sin(t·π/2)` = 0, 0.383, 0.707, 0.924, 1 → angles 60, −77.8, −194.6, −272.6, −300. In PowerShell (scratchpad output):

```powershell
Add-Type -AssemblyName System.Drawing
$root = 'C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project'
$out = Join-Path $env:TEMP 'claude\sky_day_sine_out.png'
$sky = [System.Drawing.Image]::FromFile("$root\Assets\Images\SchoolDay\transition_background.png")
$fg  = [System.Drawing.Image]::FromFile("$root\Assets\Images\SchoolDay\transition_foreground.png")
$W = 1080.0; $H = 1920.0; $f = 0.2; $fw = [int]($W*$f); $fh = [int]($H*$f)
$s = ([Math]::Sqrt(540.0*540.0 + 1920.0*1920.0) * 2.0 * 1.02) / $sky.Width
$angles = @(60, -77.8, -194.6, -272.6, -300)
$sheet = [System.Drawing.Bitmap]::new($angles.Count*$fw, $fh+30)
$gs = [System.Drawing.Graphics]::FromImage($sheet); $gs.Clear([System.Drawing.Color]::White)
$font = [System.Drawing.Font]::new('Arial', 15, [System.Drawing.FontStyle]::Bold)
for ($i=0; $i -lt $angles.Count; $i++) {
  $frame = [System.Drawing.Bitmap]::new($fw, $fh); $g = [System.Drawing.Graphics]::FromImage($frame)
  $g.InterpolationMode = 'HighQualityBilinear'
  $g.TranslateTransform([float]($W*0.5*$f), [float]($H*$f)); $g.RotateTransform([float]$angles[$i])
  $g.ScaleTransform([float]($s*$f), [float]($s*$f)); $g.TranslateTransform([float](-$sky.Width/2.0), [float](-$sky.Height/2.0))
  $g.DrawImage($sky, [float]0, [float]0, [float]$sky.Width, [float]$sky.Height); $g.ResetTransform()
  $g.DrawImage($fg, [float]0, [float]0, [float]$fw, [float]$fh); $g.Dispose()
  $gs.DrawImage($frame, $i*$fw, 30, $fw, $fh); $gs.DrawString(("{0} deg" -f $angles[$i]), $font, [System.Drawing.Brushes]::Black, [float]($i*$fw+6), [float]4)
  $frame.Dispose()
}
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
$sheet.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $gs.Dispose(); $sheet.Dispose(); $sky.Dispose(); $fg.Dispose()
$out
```
Read the PNG. Expected: the first and last frames are the same dark frame; the middle frame is bright blue; the second is the orange sunrise.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/BookClockWidget.gd tests/test_book_clock_phases.gd tests/test_sky_transition.gd
git commit -m "feat(sky): the school day turns one full circle and eases out" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Publish the motion-lab (non-blocking)**

Invoke the `motion-lab` skill for "the SkyBackground day sweep in BookClockWidget" and follow it. The tween is `transition_to()`'s `tween_method(set_progress, …)` in `BookClockWidget.gd`, local to that script, so the guard rail does not apply. Seed the lab with `{element: "SkyBackground", scene: "BookClockWidget.tscn", property: "fill", trans: "SINE", ease: "OUT", duration: 4.0, travel: 1.0}` — `fill`, because the tween drives a 0 → 1 progress value; 4.0, because `SchoolDay` sweeps the sky across both 2.0 s phases. Hand the user the link and carry on with Task 7.

When a token arrives (any later turn):
- Patch `set_trans`/`set_ease` in `transition_to()`.
- Set `transition_duration`'s default to **the token's duration ÷ 2**.
- Update the preset assertions in `test_transition_carries_the_tuned_motion_lab_preset` to match.
- Run `book_clock_phases`, `sky_transition` and `school_day`.
- Commit `feat(sky): tune the day sweep in motion-lab`.

---

### Task 7: Verification and docs

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `docs/superpowers/design/authoring-guide.md`, `CLAUDE.md`

- [ ] **Step 1: Full suite**

```
scene_open(path="res://Scenes/MainMenu/main_menu.tscn")
test_run()
```
Expected: all suites pass. Note the suite and test totals for Step 5. If the bridge drops afterwards, the reply's results still count. Restart the editor (the exe path is `C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`, launched detached through Bash with `--path "<project>" -e`, or `~/godot-restart.sh`) and poll `session_manage(op="list")`.

- [ ] **Step 2: Put back the files a full run rewrites**

```bash
git status --short
```
If `Assets/Theme/kejartes_theme.tres` or `default_bus_layout.tres` changed and nothing in this plan meant to change them:
```bash
git checkout -- Assets/Theme/kejartes_theme.tres default_bus_layout.tres
```

- [ ] **Step 3: Look at it running, at full size**

```
project_manage(op="stop")
filesystem_manage(op="scan")
project_run(mode="main")
```
- Open the debug overlay with `game_manage(op="input_key", params={"key": "F1"})`.
- Find buttons with a scoped `game_manage(op="get_ui_elements", params={"root_path": "/root/DebugManager", "max_depth": 6})`.
- Click with a `motion` event before each `button` press, and convert coordinates with `window_x = global_x * original_width / 1080`.
- Press **⚡ Seed Playtest State**, then from **Luncurkan Minigame Mandiri** launch each game below.
- Capture every check with `editor_screenshot(source="game", max_resolution=0)`:

| Launch | Must see |
|---|---|
| ▶ Badminton (Olahraga) | the shuttle twice its old size, standing upright; on the first serve toward you the cork points down |
| ▶ Main Bola (Olahraga) | the goalie standing on the goal line where he stood before |
| ▶ Buat Batik (Seni) | four tool pictures; press-and-hold each and the tooltip names the tool in the picture |
| ▶ Lomba Menari (Seni) | the "Festival Budaya Indonesia" courtyard behind the dancer, no football goal |

Then, from the Scenes tab, go to **StudentCard**:
- Capture it at rest.
- Press the right arrow and capture again right away, to catch a paper mid-flight with its shadow riding under it.

Then go to **Lobby** → **Raport Murid** and capture the report card the same way.

Any failure here goes back to its task, not to a new one. Stop the game afterwards with `project_manage(op="stop")`.

- [ ] **Step 4: Record the editor-viewport gotcha**

In `docs/superpowers/design/authoring-guide.md`, insert immediately before the `## Asset references` heading:

```markdown
**Measure the root, never the viewport.** Inside the editor
`get_viewport_rect()` is a 2×2 stub, so `@tool` layout code that reads it
collapses the whole scene into the top-left corner — MainBola did, until
2026-09-10. A full-rect root `Control` reports its real `size` in both places
(1080×1920 in the editor, the screen in game), so measure that and re-run the
layout on `NOTIFICATION_RESIZED`. When a human should place something by hand —
MainBola's goalie — leave its position to the scene in the editor and only map
it onto the real screen at runtime.

```

- [ ] **Step 5: Changelog and project guide**

In `docs/superpowers/CHANGELOG.md`, insert above `## 2026-09-10 — Asset refresh and UI pass`:

```markdown
## 2026-09-10 — Minigame, sky and paper fixes

Six independent fixes. Spec:
`docs/superpowers/specs/2026-09-10-minigame-sky-and-paper-fixes-design.md`. Plan:
`docs/superpowers/plans/2026-09-10-minigame-sky-and-paper-fixes.md`.

**Badminton shuttle.** Twice the size, hit circle included (`puck_radius_frac`
0.08), stood upright, and the cork now leads the flight: a racket hit turns it
180°, a serve snaps it toward the receiver. The growth bug was the hit punch
reading the sprite's live scale as its rest — a hit every 0.22 s against a
0.52 s punch ratcheted it up. The shuttle's look moved into
`ShuttlecockSprite.gd`, which remembers its authored pose and is tested by
behaviour; the racket squash had the same flaw and got the same fix.

**MainBola goalie.** `_setup_layout()` measured `get_viewport_rect()`, a 2×2
stub inside the editor, so the whole scene was laid out in a 2×2 box and the
goalie was rewritten on every layout. It now measures the root's `size`; the
goalie's scene position is the truth, left alone in the editor and mapped onto
the real screen in game. `goalie_depth_frac` is retired.

**BuatBatik pictures.** The slots are shuffled, then pictures were dealt by
slot index. Each tool now authors its own `ToolTextureRect`, so the picture
travels with the tool; the emoji `IconLabel`s are gone and the ratchet dropped
8 → 7.

**The day's sky.** A full turn, dawn 60 → evening −300, from the darkest frame
back round to it, easing out (SINE/OUT; smoothstep off). Motion-lab tuning of
the sweep was published for the user.

**Paper shadows.** One `Scenes/UI/PaperShadow.tscn` inside each of the twelve
StudentCard/ReportCard papers, drawn behind it, so a thrown paper takes its
shadow along. The two static stack shadows are deleted.

**LombaMenari backdrop.** `budaya_background.jpg` replaces `Gawang.jpg`,
MainBola's football goal, and covers taller screens instead of stretching.
```

In `CLAUDE.md`, replace the Testing count `89 suites, 1225 tests (2026-09-10)` with the totals from Step 1. If no motion-lab token has arrived by now, add one line under `## Current work`: `Open: motion-lab tuning of the day-sky sweep (BookClockWidget.transition_to; SINE/OUT shipped as the default).`

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/design/authoring-guide.md CLAUDE.md
git commit -m "docs: changelog and authoring note for the minigame, sky and paper fixes" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
