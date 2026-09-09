# Minigame art pass and quiz card chrome — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the meme-JPG placeholders in PilihanGanda, Menjodohkan and BuatBatik with the real art dropped in `Downloads`, and restore rounded-rectangle card chrome with heading typography in the two quiz games.

**Architecture:** Everything is driven by `@export` knobs that already exist on the three minigame scripts, so most of this is Inspector wiring done through the Godot MCP editor bridge, not code. Two exceptions: `PilihanGanda.gd` needs its no-texture style path repaired (it currently early-returns and silently drops the button press animation), and BuatBatik's four tool-slot backgrounds must change node type from `ColorRect` to `Panel` to carry a rounded `StyleBox`.

**Tech Stack:** Godot 4.6.2, GDScript, `godot-ai` MCP bridge, `McpTestSuite` source-scan tests.

**Spec:** `docs/superpowers/specs/2026-09-09-minigame-art-and-quiz-chrome-design.md`

## Global Constraints

These apply to every task below.

- **Never hand-edit a `.tscn` while the editor is attached.** The editor's in-memory copy wins and the next `scene_save` silently overwrites your text edit. All scene changes go through `scene_open` → `node_set_property` / `node_create` / `node_manage` → `scene_save`.
- **Scene paths passed to MCP include the scene root name.** `/PilihanGanda/VBoxContainer`, not `/VBoxContainer` and not `/root/...`.
- **Scene work first, script work second.** `scene_save` flushes stale script buffers over whatever you patched. After any `scene_save`, check `git diff HEAD -- '*.gd'` for files you were not editing.
- **Edit `.gd` files with `script_patch`, not the Write/Edit tools.** A plain file write from outside the editor can leave `test_run` serving stale bytecode. If a `.gd` was written from outside, force a reload with a no-op `script_patch` on that same file.
- **Run `filesystem_manage(op="scan")` after adding new files and before `test_run`.**
- **Every test suite must be `@tool`, must extend `McpTestSuite`, must have a `##` doc header, and no test may be a coroutine** — the runner calls `suite.call(name)` without awaiting, so any `await` silently aborts the test and it reports "0 assertions".
- **Every script and every `@export` needs a `##` doc line** (`tests/test_script_documentation.gd` enforces this).
- **Do not touch `Scripts/Balance.gd`** — collaborator-owned.
- **Game-facing text is Indonesian; systems code is English.**
- **No emoji as UI iconography.**

Design token values used verbatim in this plan:

| Token | Value |
|---|---|
| `radius_md` | `24` |
| `surface_card` | `#ffffff` |
| `text_primary` | `#1e2436` |
| `text_on_brand` | `#ffffff` |
| `state_success` | `#2fb86b` |
| `state_danger` | `#c42b6e` |

---

## File Structure

**Created:**
- `tests/test_minigame_art.gd` — one suite covering all art wiring for the three minigames. Grows task by task.
- `Assets/Images/Textures/batik_fase1..5.png` — canvas phases.
- `Assets/Images/Textures/batik_tool_{pencil,canting,pewarna,kompor}.png` — tool icons.
- `Assets/Images/{monas,borobudur,komodo,wayang,bhineka_tunggal_ika}.png` — quiz question art.

**Modified:**
- `Scenes/Minigames/SeniBudaya/BuatBatik.tscn` — tool + phase textures, four slot backgrounds.
- `Scenes/Minigames/Akademis/Menjodohkan.tscn` — clear two card-bg placeholder exports.
- `Scenes/Minigames/Akademis/QuestionCard.tscn`, `AnswerCard.tscn` — radius 24, heading text.
- `Scenes/Minigames/Akademis/PilihanGanda.tscn` — three authored styleboxes, clear placeholder, Boohong font.
- `Scripts/Minigames/Akademis/PilihanGanda.gd` — repair the flat style path, drop the shadow helper, add a font-colour export, repoint one image path.
- `Assets/Data/pilihanganda_questions.json`, `menjodohkan_questions.json` — repoint five image paths.
- `tests/test_viewport_editability.gd` — ratchet `ALLOWED` back to 1.

**Deleted (Task 7, only after the reference check passes):**
- `Assets/Images/{monas_monument,borobudur_temple,komodo_dragon,wayang_kulit,garuda_pancasila}.jpg` and their `.import` siblings.

---

## Task 1: Import the new art

**Files:**
- Create: `tests/test_minigame_art.gd`
- Create: 14 image files (see steps)

**Interfaces:**
- Produces: the const path arrays `_BATIK_PHASES`, `_BATIK_TOOLS`, `_QUIZ_IMAGES` in `tests/test_minigame_art.gd`, reused by every later task's tests.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_art.gd`:

```gdscript
@tool
extends McpTestSuite

## Art-wiring scan for the three minigames whose placeholder meme JPGs were
## replaced on 2026-09-09 (PilihanGanda, Menjodohkan, BuatBatik). Pure
## source-text and asset-existence checks -- instantiates nothing, needs no
## scene open. See docs/superpowers/specs/2026-09-09-minigame-art-and-quiz-
## chrome-design.md.

func suite_name() -> String:
	return "minigame_art"

## The five batik canvas phases: fase1 is the blank cloth, fase2..5 are the
## results of the Pencil / Canting / Pewarna / Kompor steps.
const _BATIK_PHASES: Array[String] = [
	"res://Assets/Images/Textures/batik_fase1.png",
	"res://Assets/Images/Textures/batik_fase2.png",
	"res://Assets/Images/Textures/batik_fase3.png",
	"res://Assets/Images/Textures/batik_fase4.png",
	"res://Assets/Images/Textures/batik_fase5.png",
]

## The four BuatBatik tool icons, in tool0..tool3 order.
const _BATIK_TOOLS: Array[String] = [
	"res://Assets/Images/Textures/batik_tool_pencil.png",
	"res://Assets/Images/Textures/batik_tool_canting.png",
	"res://Assets/Images/Textures/batik_tool_pewarna.png",
	"res://Assets/Images/Textures/batik_tool_kompor.png",
]

## Illustrated question art replacing the five photo JPGs.
const _QUIZ_IMAGES: Array[String] = [
	"res://Assets/Images/monas.png",
	"res://Assets/Images/borobudur.png",
	"res://Assets/Images/komodo.png",
	"res://Assets/Images/wayang.png",
	"res://Assets/Images/bhineka_tunggal_ika.png",
]

func test_new_art_imports_as_texture2d() -> void:
	for group in [_BATIK_PHASES, _BATIK_TOOLS, _QUIZ_IMAGES]:
		for path in group:
			assert_true(ResourceLoader.exists(path), "missing imported art: " + path)
			var tex := load(path) as Texture2D
			assert_true(tex != null, path + " did not import as a Texture2D")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: suite `minigame_art` FAILS with "missing imported art: res://Assets/Images/Textures/batik_fase1.png".

- [ ] **Step 3: Copy the art in from Downloads**

Source files keep their original names in `Downloads`; the project copies get underscored names. Note `Tool3.png` → pewarna and `Tool4.png` → kompor: the Downloads numbering skips 2, and the mapping below is by what each image depicts (pencil, canting, dye bottles, wax wok).

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
D=/c/Users/user/Downloads
cp "$D/batik fase1.png" Assets/Images/Textures/batik_fase1.png
cp "$D/batik fase2.png" Assets/Images/Textures/batik_fase2.png
cp "$D/batik fase3.png" Assets/Images/Textures/batik_fase3.png
cp "$D/batik fase4.png" Assets/Images/Textures/batik_fase4.png
cp "$D/batik fase5.png" Assets/Images/Textures/batik_fase5.png
cp "$D/Tool0.png" Assets/Images/Textures/batik_tool_pencil.png
cp "$D/Tool1.png" Assets/Images/Textures/batik_tool_canting.png
cp "$D/Tool3.png" Assets/Images/Textures/batik_tool_pewarna.png
cp "$D/Tool4.png" Assets/Images/Textures/batik_tool_kompor.png
cp "$D/monas.png" Assets/Images/monas.png
cp "$D/borobudur.png" Assets/Images/borobudur.png
cp "$D/komodo.png" Assets/Images/komodo.png
cp "$D/wayang.png" Assets/Images/wayang.png
cp "$D/bhineka tunggal ika.png" Assets/Images/bhineka_tunggal_ika.png
```

- [ ] **Step 4: Import them into Godot**

```
filesystem_manage(op="scan")
```

Then confirm every file got an `.import` sibling:

```bash
ls Assets/Images/Textures/batik_*.png.import Assets/Images/{monas,borobudur,komodo,wayang,bhineka_tunggal_ika}.png.import
```

Expected: 14 `.import` files listed. If any are missing, run `filesystem_manage(op="scan")` again — the first scan can race a large PNG import.

- [ ] **Step 5: Run the test to verify it passes**

```
test_run()
```

Expected: suite `minigame_art` PASSES, and the whole run is green (1085 existing tests + the new one).

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/Textures/batik_*.png Assets/Images/Textures/batik_*.png.import \
        Assets/Images/monas.png Assets/Images/borobudur.png Assets/Images/komodo.png \
        Assets/Images/wayang.png Assets/Images/bhineka_tunggal_ika.png \
        Assets/Images/*.png.import tests/test_minigame_art.gd
git commit -m "feat(minigames): import the batik phase art, tool icons and quiz illustrations

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: Wire BuatBatik's tools and canvas phases

**Files:**
- Modify: `Scenes/Minigames/SeniBudaya/BuatBatik.tscn` (root node exports only)
- Test: `tests/test_minigame_art.gd`

**Interfaces:**
- Consumes: `_BATIK_PHASES`, `_BATIK_TOOLS` from Task 1.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_art.gd`:

```gdscript
func test_buatbatik_wires_the_new_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	for group in [_BATIK_PHASES, _BATIK_TOOLS]:
		for path in group:
			assert_true(src.contains(path), "BuatBatik.tscn must reference " + path)

func test_buatbatik_has_no_placeholder_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	for stale in ["Kiper", "DiagonalRight", "komodo_dragon", "borobudur_temple"]:
		assert_false(src.contains(stale),
			"BuatBatik.tscn still references the placeholder " + stale)
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: FAILS with "BuatBatik.tscn must reference res://Assets/Images/Textures/batik_fase1.png" and "still references the placeholder Kiper".

- [ ] **Step 3: Wire the exports through the editor**

```
scene_open(path="res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
```

then one batch:

```
batch_execute(commands=[
  {"command":"set_property","params":{"path":"/BuatBatik","property":"tool0_texture","value":"res://Assets/Images/Textures/batik_tool_pencil.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"tool1_texture","value":"res://Assets/Images/Textures/batik_tool_canting.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"tool2_texture","value":"res://Assets/Images/Textures/batik_tool_pewarna.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"tool3_texture","value":"res://Assets/Images/Textures/batik_tool_kompor.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"canvas_cloth_texture","value":"res://Assets/Images/Textures/batik_fase1.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"layer0_pattern_texture","value":"res://Assets/Images/Textures/batik_fase2.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"layer1_pattern_texture","value":"res://Assets/Images/Textures/batik_fase3.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"layer2_pattern_texture","value":"res://Assets/Images/Textures/batik_fase4.png"}},
  {"command":"set_property","params":{"path":"/BuatBatik","property":"layer3_pattern_texture","value":"res://Assets/Images/Textures/batik_fase5.png"}}
])
```

Then save:

```
scene_save()
```

`_apply_visual_exports()` hides each slot's `IconLabel` whenever a tool texture is present, so this also removes the four emoji glyphs — no separate step needed.

- [ ] **Step 4: Run the test to verify it passes**

```
test_run()
```

Expected: `minigame_art` PASSES. Also confirm no `.gd` was clobbered by the save:

```bash
git diff HEAD --stat -- '*.gd'
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/SeniBudaya/BuatBatik.tscn tests/test_minigame_art.gd
git commit -m "feat(batik): wire the real tool icons and the five batik canvas phases

Replaces the Kiper/Diagonal meme JPGs on the four tool slots and the
komodo photo standing in as cloth. Setting the tool textures also hides
the emoji IconLabels.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Give BuatBatik's tool slots rounded card backgrounds

**Files:**
- Modify: `Scenes/Minigames/SeniBudaya/BuatBatik.tscn` (`ToolsContainer/Tool0..3/Bg`)
- Test: `tests/test_minigame_art.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

Each slot's background is a `ColorRect` in an arbitrary colour (grey `0.5,0.5,0.5`, red `0.65,0.16,0.16`, blue `0.1,0.2,0.6`, yellow `0.85,0.75,0.1`). A `ColorRect` cannot carry a `StyleBox`, so each becomes a `Panel`. Godot cannot change a node's type in place — delete and recreate, keeping the name `Bg` and full-rect anchors so `BuatBatik.gd:181-183` (which sets `MOUSE_FILTER_IGNORE` on every `Control` child so the background never steals the drag) keeps working untouched.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_art.gd`:

```gdscript
func test_buatbatik_tool_slots_use_rounded_panels() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	assert_eq(src.count("[node name=\"Bg\" type=\"Panel\""), 4,
		"all four tool slots need a Panel background that can carry a rounded StyleBox")
	assert_false(src.contains("[node name=\"Bg\" type=\"ColorRect\""),
		"no tool slot may keep its placeholder ColorRect background")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: FAILS with "all four tool slots need a Panel background", actual `0`.

- [ ] **Step 3: Replace the four backgrounds**

```
scene_open(path="res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
```

For each of `Tool0`, `Tool1`, `Tool2`, `Tool3` — run this four times, substituting `N`:

```
node_manage(op="delete", params={"path": "/BuatBatik/ToolsContainer/ToolN/Bg"})
node_create(type="Panel", parent_path="/BuatBatik/ToolsContainer/ToolN", name="Bg")
batch_execute(commands=[
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"layout_mode","value":1}},
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"anchors_preset","value":-1}},
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"anchor_right","value":1}},
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"anchor_bottom","value":1}},
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"grow_horizontal","value":2}},
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"grow_vertical","value":2}},
  {"command":"set_property","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","property":"mouse_filter","value":2}},
  {"command":"move_node","params":{"path":"/BuatBatik/ToolsContainer/ToolN/Bg","index":0}}
])
resource_manage(op="create", params={
  "type": "StyleBoxFlat",
  "path": "/BuatBatik/ToolsContainer/ToolN/Bg",
  "property": "theme_override_styles/panel",
  "properties": {
    "bg_color": "#ffffff",
    "corner_radius_top_left": 24,
    "corner_radius_top_right": 24,
    "corner_radius_bottom_right": 24,
    "corner_radius_bottom_left": 24,
    "border_width_left": 2, "border_width_top": 2,
    "border_width_right": 2, "border_width_bottom": 2,
    "border_color": "#3380d9",
    "shadow_color": {"r": 0, "g": 0, "b": 0, "a": 0.25},
    "shadow_size": 6,
    "shadow_offset": {"x": 0, "y": 3}
  }
})
```

`move_node` to index 0 puts the background behind the icon, matching the original child order. A `theme_override_styles/panel` on a minigame node is fine — CLAUDE.md scopes the no-override rule to the design system, and `Scenes/Minigames/**` is explicitly outside it.

Then save:

```
scene_save()
```

- [ ] **Step 4: Run the test to verify it passes**

```
test_run()
```

Expected: `minigame_art` PASSES. Then `git diff HEAD --stat -- '*.gd'` — expect no output.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/SeniBudaya/BuatBatik.tscn tests/test_minigame_art.gd
git commit -m "feat(batik): stand the tool icons on rounded cards instead of colour blocks

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Restore Menjodohkan's rounded cards and give them heading text

**Files:**
- Modify: `Scenes/Minigames/Akademis/Menjodohkan.tscn` (root exports)
- Modify: `Scenes/Minigames/Akademis/QuestionCard.tscn`, `Scenes/Minigames/Akademis/AnswerCard.tscn`
- Test: `tests/test_minigame_art.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

Clearing the two bg exports is what restores the card: `Menjodohkan.gd:439-443` and `:484-488` overwrite the card's panel with a `StyleBoxEmpty` whenever a bg texture is set, so the authored `StyleBoxFlat` only becomes visible once the export is null.

**Do not remove the runtime font-size ladder** in `Menjodohkan.gd:418-426` (36 / 32 / 28 / 24 by question length, dropping to 24 when the question has an image). A `theme_override` beats a type variation, so `H2Label` supplies the font and ink while the ladder keeps long questions inside the fixed 850×380 card.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_art.gd`:

```gdscript
func test_menjodohkan_cards_are_rounded_and_use_heading_text() -> void:
	for p in ["res://Scenes/Minigames/Akademis/QuestionCard.tscn",
			"res://Scenes/Minigames/Akademis/AnswerCard.tscn"]:
		var src := FileAccess.get_file_as_string(p)
		assert_true(src.contains("corner_radius_top_left = 24"),
			p + " card needs the radius_md corner")
		assert_true(src.contains("theme_type_variation = &\"H2Label\""),
			p + " TextLabel needs the H2Label heading variation")
		assert_false(src.contains("theme_override_font_sizes/font_size = 42"),
			p + " must drop the static 42px TextLabel override")

func test_menjodohkan_has_no_placeholder_card_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
	assert_false(src.contains("Kiper"),
		"Menjodohkan.tscn still references a Kiper meme placeholder")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: FAILS with "card needs the radius_md corner" and "still references a Kiper meme placeholder".

- [ ] **Step 3: Clear the two placeholder exports**

```
scene_open(path="res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
batch_execute(commands=[
  {"command":"set_property","params":{"path":"/Menjodohkan","property":"card_question_bg_texture","value":""}},
  {"command":"set_property","params":{"path":"/Menjodohkan","property":"card_answer_bg_texture","value":""}}
])
scene_save()
```

Passing `""` clears a resource slot.

- [ ] **Step 4: Round the two card templates and set heading text**

```
scene_open(path="res://Scenes/Minigames/Akademis/QuestionCard.tscn")
batch_execute(commands=[
  {"command":"set_property","params":{"path":"/QuestionCard/VBox/TextLabel","property":"theme_type_variation","value":"H2Label"}}
])
scene_save()
```

The card's `StyleBoxFlat` is a sub-resource on the root's `theme_override_styles/panel`. Set its four corners through the node property so the editor rewrites the sub-resource:

```
resource_manage(op="create", params={
  "type": "StyleBoxFlat",
  "path": "/QuestionCard",
  "property": "theme_override_styles/panel",
  "properties": {
    "bg_color": {"r": 0.98, "g": 0.98, "b": 0.98, "a": 1},
    "border_width_left": 2, "border_width_top": 2,
    "border_width_right": 2, "border_width_bottom": 2,
    "border_color": {"r": 0.85, "g": 0.45, "b": 0.1, "a": 1},
    "corner_radius_top_left": 24, "corner_radius_top_right": 24,
    "corner_radius_bottom_right": 24, "corner_radius_bottom_left": 24,
    "shadow_color": {"r": 0, "g": 0, "b": 0, "a": 0.12},
    "shadow_size": 4,
    "shadow_offset": {"x": 0, "y": 2},
    "content_margin_left": 8, "content_margin_top": 6,
    "content_margin_right": 8, "content_margin_bottom": 6
  }
})
scene_save()
```

Now clear the two static overrides that would beat the variation. These are `.tscn` properties, so clear them through the editor rather than by text edit:

```
node_manage(op="get_children", params={"path": "/QuestionCard/VBox"})
```

confirm `TextLabel` is there, then:

```
batch_execute(commands=[
  {"command":"set_property","params":{"path":"/QuestionCard/VBox/TextLabel","property":"theme_override_font_sizes/font_size","value":null}},
  {"command":"set_property","params":{"path":"/QuestionCard/VBox/TextLabel","property":"theme_override_colors/font_color","value":null}}
])
scene_save()
```

Repeat the whole of Step 4 for `AnswerCard.tscn`, substituting the root name `/AnswerCard` and its own border colour `{"r": 0.2, "g": 0.5, "b": 0.85, "a": 1}` (AnswerCard is blue where QuestionCard is orange — keep them distinguishable).

- [ ] **Step 5: Run the test to verify it passes**

```
test_run()
```

Expected: `minigame_art` PASSES, whole run green. Then `git diff HEAD --stat -- '*.gd'` — expect no output.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Minigames/Akademis/Menjodohkan.tscn \
        Scenes/Minigames/Akademis/QuestionCard.tscn \
        Scenes/Minigames/Akademis/AnswerCard.tscn \
        tests/test_minigame_art.gd
git commit -m "feat(menjodohkan): drop the meme card art and show the real rounded cards

Clearing the two bg exports stops Menjodohkan.gd swapping the card's
StyleBoxFlat for a StyleBoxEmpty, so the authored card returns. Corners
go to radius_md and the card text picks up the H2Label heading variation.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Author PilihanGanda's rounded-rect answer button styles

**Files:**
- Modify: `Scenes/Minigames/Akademis/PilihanGanda.tscn` (root exports only)
- Test: `tests/test_minigame_art.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: three sub-resource styleboxes assigned to `answer_btn_normal_style`, `answer_btn_correct_style`, `answer_btn_wrong_style`, consumed by Task 6's script path.

Clearing `choice_btn_normal_texture` alone is **not** enough: with `answer_btn_normal_style` null the buttons fall back to the theme's base `Button`, which `ThemeFactory._build_base_overrides` builds with `_pill()` — a capsule, not a rounded rectangle.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_art.gd`:

```gdscript
func test_pilihanganda_answer_buttons_are_rounded_rects() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	for prop in ["answer_btn_normal_style", "answer_btn_correct_style", "answer_btn_wrong_style"]:
		assert_true(src.contains(prop + " = SubResource("),
			prop + " must be authored as a StyleBox in the scene")
	assert_true(src.contains("corner_radius_top_left = 24"),
		"answer buttons must be rounded rectangles, not the theme's default pill")
	assert_false(src.contains("choice_btn_normal_texture = ExtResource"),
		"the meme placeholder texture must be cleared")

func test_pilihanganda_uses_the_display_font() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	assert_true(src.contains("Boohong.otf"),
		"the scene must set its font export to the Boohong display face for heading text")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: FAILS with "answer_btn_normal_style must be authored as a StyleBox in the scene".

- [ ] **Step 3: Author the three styleboxes and clear the placeholder**

```
scene_open(path="res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
```

Normal — near-white card with the same blue accent as `AnswerCard`, so the two quiz games read as one family:

```
resource_manage(op="create", params={
  "type": "StyleBoxFlat",
  "path": "/PilihanGanda",
  "property": "answer_btn_normal_style",
  "properties": {
    "bg_color": {"r": 0.98, "g": 0.98, "b": 0.98, "a": 1},
    "border_width_left": 2, "border_width_top": 2,
    "border_width_right": 2, "border_width_bottom": 2,
    "border_color": {"r": 0.2, "g": 0.5, "b": 0.85, "a": 1},
    "corner_radius_top_left": 24, "corner_radius_top_right": 24,
    "corner_radius_bottom_right": 24, "corner_radius_bottom_left": 24,
    "shadow_color": {"r": 0, "g": 0, "b": 0, "a": 0.25},
    "shadow_size": 6,
    "shadow_offset": {"x": 0, "y": 3},
    "content_margin_left": 16, "content_margin_top": 10,
    "content_margin_right": 16, "content_margin_bottom": 10
  }
})
```

Correct — `state_success` fill, same geometry:

```
resource_manage(op="create", params={
  "type": "StyleBoxFlat",
  "path": "/PilihanGanda",
  "property": "answer_btn_correct_style",
  "properties": {
    "bg_color": "#2fb86b",
    "border_width_left": 2, "border_width_top": 2,
    "border_width_right": 2, "border_width_bottom": 2,
    "border_color": "#ffffff",
    "corner_radius_top_left": 24, "corner_radius_top_right": 24,
    "corner_radius_bottom_right": 24, "corner_radius_bottom_left": 24,
    "shadow_color": {"r": 0, "g": 0, "b": 0, "a": 0.25},
    "shadow_size": 6,
    "shadow_offset": {"x": 0, "y": 3},
    "content_margin_left": 16, "content_margin_top": 10,
    "content_margin_right": 16, "content_margin_bottom": 10
  }
})
```

Wrong — `state_danger` fill, same geometry:

```
resource_manage(op="create", params={
  "type": "StyleBoxFlat",
  "path": "/PilihanGanda",
  "property": "answer_btn_wrong_style",
  "properties": {
    "bg_color": "#c42b6e",
    "border_width_left": 2, "border_width_top": 2,
    "border_width_right": 2, "border_width_bottom": 2,
    "border_color": "#ffffff",
    "corner_radius_top_left": 24, "corner_radius_top_right": 24,
    "corner_radius_bottom_right": 24, "corner_radius_bottom_left": 24,
    "shadow_color": {"r": 0, "g": 0, "b": 0, "a": 0.25},
    "shadow_size": 6,
    "shadow_offset": {"x": 0, "y": 3},
    "content_margin_left": 16, "content_margin_top": 10,
    "content_margin_right": 16, "content_margin_bottom": 10
  }
})
```

Then clear the meme and set the display font:

```
batch_execute(commands=[
  {"command":"set_property","params":{"path":"/PilihanGanda","property":"choice_btn_normal_texture","value":""}},
  {"command":"set_property","params":{"path":"/PilihanGanda","property":"font","value":"res://Assets/Fonts/Boohong.otf"}}
])
scene_save()
```

The scene's existing sizes are already on heading tokens — `question_font_size` 48 = `font_h2`, `answer_btn_font_size` 36 = `font_title` — so the font export is the only typography change needed.

- [ ] **Step 4: Run the test to verify it passes**

```
test_run()
```

Expected: `minigame_art` PASSES. Then `git diff HEAD --stat -- '*.gd'` — expect no output.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/Akademis/PilihanGanda.tscn tests/test_minigame_art.gd
git commit -m "feat(pilihanganda): author rounded-rect answer button styles

Replaces the KiperRight meme texture with normal/correct/wrong
StyleBoxFlats at radius_md, and switches the scene to the Boohong
display face so question and answer text read as headings.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Repair PilihanGanda's flat style path and drop the shadow helper

**Files:**
- Modify: `Scripts/Minigames/Akademis/PilihanGanda.gd`
- Modify: `tests/test_viewport_editability.gd:111-115`
- Test: `tests/test_minigame_art.gd`

**Interfaces:**
- Consumes: the three styleboxes authored in Task 5.
- Produces: `@export var answer_btn_font_color: Color`.

Two defects to fix together. First, the flat path early-returns, so it never reaches the press-shrink wiring at the bottom of the function — taking that path today silently kills the button press feel. Second, the theme's base `Button` font colour is `text_on_brand` = **white**, which would be invisible on the near-white button from Task 5.

Also delete `_make_choice_shadow()`: it attaches a transparent `Panel` to every button purely to cast a shadow, and the Task 5 stylebox now carries `shadow_size`/`shadow_offset` itself. That drops real runtime construction in this file from 2 back to 1, so `tests/test_viewport_editability.gd`'s `ALLOWED` entry must come down in the same commit or `test_baseline_is_not_stale` fails.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_art.gd`:

```gdscript
func test_choice_buttons_animate_on_both_style_paths() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_false(src.contains("_make_choice_shadow"),
		"the per-button shadow Panel is superseded by the stylebox's own shadow")
	assert_true(src.contains("answer_btn_font_color"),
		"answer buttons need their own ink colour: the theme's Button font is white")
	var flat_branch := src.find("if choice_btn_normal_texture == null:")
	var press_wiring := src.find("button_down.connect")
	assert_true(flat_branch != -1, "the flat-style branch should still exist")
	assert_true(press_wiring > flat_branch,
		"press wiring must come after the branch so both paths reach it")
	if press_wiring > flat_branch:
		var branch_body := src.substr(flat_branch, press_wiring - flat_branch)
		assert_false(branch_body.contains("return"),
			"the flat path must fall through to the shared press-animation wiring")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: FAILS with "the per-button shadow Panel is superseded by the stylebox's own shadow".

- [ ] **Step 3: Add the font-colour export**

```
script_patch(
  path="res://Scripts/Minigames/Akademis/PilihanGanda.gd",
  old_text="## Style flashed on a button the player picked incorrectly.\n@export var answer_btn_wrong_style:   StyleBox = null",
  new_text="## Style flashed on a button the player picked incorrectly.\n@export var answer_btn_wrong_style:   StyleBox = null\n## Ink for answer buttons on the flat-StyleBox path. The theme's Button font\n## colour is text_on_brand (white), which vanishes on a light card.\n@export var answer_btn_font_color: Color = Color(\"1e2436\")"
)
```

- [ ] **Step 4: Rewrite `_apply_choice_btn_textures()`**

Replace the whole function. `old_text` runs from the doc comment down to the last `button_up.connect` line:

```
script_patch(
  path="res://Scripts/Minigames/Akademis/PilihanGanda.gd",
  old_text=<the current function, from "## Applies texture-based StyleBoxes" through "\tbtn.button_up.connect(_on_choice_btn_up.bind(btn))">,
  new_text=<the block below>
)
```

New body:

```gdscript
## Applies the answer-button chrome -- texture StyleBoxes when a PNG is
## supplied, otherwise the rounded-rect StyleBoxes authored in the Inspector.
## Both paths fall through to the shared press-shrink wiring at the end.
func _apply_choice_btn_textures(btn: Button) -> void:
	if choice_btn_normal_texture == null:
		if answer_btn_normal_style:
			btn.add_theme_stylebox_override("normal", answer_btn_normal_style)
			btn.add_theme_stylebox_override("hover",  answer_btn_normal_style)
			btn.add_theme_stylebox_override("focus",  answer_btn_normal_style)
			var sb_pressed_flat := answer_btn_normal_style.duplicate() as StyleBoxFlat
			if sb_pressed_flat:
				sb_pressed_flat.bg_color = sb_pressed_flat.bg_color * choice_btn_pressed_tint
				btn.add_theme_stylebox_override("pressed", sb_pressed_flat)
			var sb_disabled_flat := answer_btn_normal_style.duplicate() as StyleBoxFlat
			if sb_disabled_flat:
				sb_disabled_flat.bg_color = sb_disabled_flat.bg_color * choice_btn_disabled_tint
				btn.add_theme_stylebox_override("disabled", sb_disabled_flat)
		btn.add_theme_color_override("font_color", answer_btn_font_color)
		btn.add_theme_color_override("font_disabled_color", answer_btn_font_color)
	else:
		var sb_normal   = _make_btn_stylebox(choice_btn_normal_texture, Color.WHITE)
		var sb_pressed  = _make_btn_stylebox(choice_btn_normal_texture, choice_btn_pressed_tint)
		var sb_disabled = _make_btn_stylebox(choice_btn_normal_texture, choice_btn_disabled_tint)
		btn.add_theme_stylebox_override("normal",   sb_normal)
		btn.add_theme_stylebox_override("hover",    sb_normal)
		btn.add_theme_stylebox_override("pressed",  sb_pressed)
		btn.add_theme_stylebox_override("disabled", sb_disabled)
		btn.add_theme_stylebox_override("focus",    sb_normal)

	btn.pivot_offset = Vector2(btn.size.x / 2.0, answer_btn_min_height / 2.0)
	btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(_on_choice_btn_down.bind(btn))
	btn.button_up.connect(_on_choice_btn_up.bind(btn))
```

- [ ] **Step 5: Delete the shadow helper and its call site**

```
script_patch(
  path="res://Scripts/Minigames/Akademis/PilihanGanda.gd",
  old_text="\t\t\t\tbtn.add_child(_make_choice_shadow())\n",
  new_text=""
)
```

then remove the function itself (the `##` doc block plus the whole `func _make_choice_shadow() -> Panel:` body, ending at `\treturn shadow`), leaving the `## Builds a StyleBoxTexture...` comment that follows it intact.

- [ ] **Step 6: Lower the ratchet**

```
script_patch(
  path="res://tests/test_viewport_editability.gd",
  old_text="\t# Answer buttons (text and shuffled order regenerate per question: not\n\t# fixed layout) plus the transparent Panel each one carries purely for\n\t# its shadow_* StyleBoxFlat (show_behind_parent) -- the shadow is\n\t# necessarily as dynamic as the button it's attached to, added 2026-09-09.\n\t\"res://Scripts/Minigames/Akademis/PilihanGanda.gd\": 2,",
  new_text="\t# Answer buttons: text and shuffled order regenerate per question: not\n\t# fixed layout.\n\t\"res://Scripts/Minigames/Akademis/PilihanGanda.gd\": 1,"
)
```

- [ ] **Step 7: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run()
```

Expected: `minigame_art` PASSES **and** `viewport_editability` PASSES. If `viewport_editability` reports "allowed 1, now 2", a `Panel.new(` or `Button.new(` is still in the file — recheck Step 5.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Minigames/Akademis/PilihanGanda.gd tests/test_viewport_editability.gd tests/test_minigame_art.gd
git commit -m "fix(pilihanganda): keep the press animation on the flat style path

The no-texture branch returned early, skipping the press-shrink wiring
and every state but normal. Both paths now share that tail. Adds an ink
colour for the light button (the theme's Button font is white) and drops
the per-button shadow Panel, now redundant against the stylebox shadow.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Repoint the quiz question images

**Files:**
- Modify: `Assets/Data/pilihanganda_questions.json` (lines 6, 12, 18)
- Modify: `Assets/Data/menjodohkan_questions.json` (lines 2-5)
- Modify: `Scripts/Minigames/Akademis/PilihanGanda.gd:19`
- Test: `tests/test_minigame_art.gd`

**Interfaces:**
- Consumes: `_QUIZ_IMAGES` from Task 1.
- Produces: nothing.

| Old | New |
|---|---|
| `res://Assets/Images/monas_monument.jpg` | `res://Assets/Images/monas.png` |
| `res://Assets/Images/borobudur_temple.jpg` | `res://Assets/Images/borobudur.png` |
| `res://Assets/Images/komodo_dragon.jpg` | `res://Assets/Images/komodo.png` |
| `res://Assets/Images/wayang_kulit.jpg` | `res://Assets/Images/wayang.png` |
| `res://Assets/Images/garuda_pancasila.jpg` | `res://Assets/Images/bhineka_tunggal_ika.png` |

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_art.gd`:

```gdscript
func test_every_question_image_resolves() -> void:
	for data_path in ["res://Assets/Data/pilihanganda_questions.json",
			"res://Assets/Data/menjodohkan_questions.json"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		assert_true(parsed is Array, data_path + " must parse as a JSON Array")
		if parsed is Array:
			for entry in parsed:
				var img: String = str(entry.get("image", ""))
				if img != "":
					assert_true(ResourceLoader.exists(img),
						data_path + " points at a missing image: " + img)

func test_no_placeholder_quiz_photos_remain() -> void:
	var stale := ["monas_monument", "borobudur_temple", "komodo_dragon",
			"wayang_kulit", "garuda_pancasila"]
	for p in ["res://Assets/Data/pilihanganda_questions.json",
			"res://Assets/Data/menjodohkan_questions.json",
			"res://Scripts/Minigames/Akademis/PilihanGanda.gd"]:
		var src := FileAccess.get_file_as_string(p)
		for stale_name in stale:
			assert_false(src.contains(stale_name), p + " still references " + stale_name)
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run()
```

Expected: FAILS with "pilihanganda_questions.json still references monas_monument".

- [ ] **Step 3: Repoint the two JSON banks**

JSON files are plain data, not editor-cached scenes, so the Edit tool is fine here:

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
sed -i \
  -e 's#Assets/Images/monas_monument.jpg#Assets/Images/monas.png#g' \
  -e 's#Assets/Images/borobudur_temple.jpg#Assets/Images/borobudur.png#g' \
  -e 's#Assets/Images/komodo_dragon.jpg#Assets/Images/komodo.png#g' \
  -e 's#Assets/Images/wayang_kulit.jpg#Assets/Images/wayang.png#g' \
  -e 's#Assets/Images/garuda_pancasila.jpg#Assets/Images/bhineka_tunggal_ika.png#g' \
  Assets/Data/pilihanganda_questions.json Assets/Data/menjodohkan_questions.json
```

- [ ] **Step 4: Repoint the hardcoded fallback question**

```
script_patch(
  path="res://Scripts/Minigames/Akademis/PilihanGanda.gd",
  old_text="\"image\": \"res://Assets/Images/monas_monument.jpg\"",
  new_text="\"image\": \"res://Assets/Images/monas.png\""
)
```

- [ ] **Step 5: Delete the superseded photos, only if nothing references them**

```bash
grep -rn "monas_monument\|borobudur_temple\|komodo_dragon\|wayang_kulit\|garuda_pancasila" \
  --include="*.gd" --include="*.tscn" --include="*.tres" --include="*.json" . \
  | grep -v "^./.claude/worktrees/" | grep -v "^./-REFERENCE-"
```

Expected: no output. `.claude/worktrees/` and `-REFERENCE-/` are stale copies and are deliberately excluded — do not edit them.

Only if that grep is empty:

```bash
rm -f Assets/Images/monas_monument.jpg* Assets/Images/borobudur_temple.jpg* \
      Assets/Images/komodo_dragon.jpg* Assets/Images/wayang_kulit.jpg* \
      Assets/Images/garuda_pancasila.jpg*
```

If the grep prints anything, stop and repoint that reference first.

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run()
```

Expected: full run green, including `minigame_art`.

- [ ] **Step 7: Commit**

```bash
git add Assets/Data/pilihanganda_questions.json Assets/Data/menjodohkan_questions.json \
        Scripts/Minigames/Akademis/PilihanGanda.gd tests/test_minigame_art.gd Assets/Images/
git commit -m "feat(quiz): swap the question photos for the illustrated art

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Live verification pass

**Files:** none modified unless a defect is found.

**Interfaces:**
- Consumes: everything above.

Source scans prove wiring, not appearance. CLAUDE.md requires a live pass for UI work, and three specific things can only be caught on screen: Boohong is wider than Open Sans, so text may clip; the batik phases must stack in the right order; and the tool icons must actually sit on their new cards.

- [ ] **Step 1: Full suite**

```
test_run()
```

Expected: green, 78+ suites.

- [ ] **Step 2: Launch and reach each minigame**

```
project_run()
```

then `input_key(key="F1")` to open the debug overlay, click **Minigames**, and use **Luncurkan Minigame Mandiri**.

Coordinate note: `get_ui_elements` reports rects in the 1080×1920 design space while input events take window pixels. Derive the factor from `editor_screenshot`'s reported `original_width` (a 540-wide window means halve every coordinate). Send a `motion` event to the target before the `button` press — a bare press/release pair silently does nothing.

- [ ] **Step 3: Check PilihanGanda**

Screenshot and confirm: answer buttons are rounded rectangles on the wood table, dark text on light cards (**not** white-on-white), the shadow reads under each button, and text does not clip at `answer_btn_min_height` 100. Tap one answer and confirm the press-shrink animates and the correct/wrong flash recolours the button.

- [ ] **Step 4: Check Menjodohkan**

Screenshot and confirm: both carousels show rounded cards with no meme art, and the longest question fits its card. If a question clips, raise the ladder's break points in `Menjodohkan.gd:418-426` — that is the only intended fix, one value at a time.

- [ ] **Step 5: Check BuatBatik**

Screenshot the opening state, then drag the tools in the correct order — Pencil → Canting → Pewarna → Kompor — screenshotting after each. Confirm: the four tool icons render with no emoji, each sits on a rounded card, the cloth starts as blank fase1, and each step reveals the next phase in order through fase5.

- [ ] **Step 6: Stop the game and commit any fixes**

```
project_manage(op="stop")
```

Commit any adjustment separately with a message naming what the live pass caught.

---

## Self-Review Notes

Checked against the spec:

- Meme placeholders cleared in all three scenes — Tasks 2, 4, 5.
- Rounded rectangles — Task 4 (cards, radius 24) and Task 5 (buttons, radius 24).
- Heading typography — Task 4 (`H2Label`) and Task 5 (Boohong export).
- Batik phases and tools — Task 2; tool slot backgrounds — Task 3.
- Quiz images — Tasks 1 and 7.
- Shadow-Panel removal and ratchet bookkeeping — Task 6.
- Live pass — Task 8.

Two traps the spec flagged are carried into the tasks that hit them: the `StyleBoxEmpty` swap (Task 4 Step 3) and the Menjodohkan runtime font ladder (Task 4 preamble). One trap was found while writing the plan and is not in the spec: the theme's base `Button` ink is `text_on_brand` (white), so the light answer button needs its own font colour — handled by the new export in Task 6 Step 3, and asserted in that task's test.
