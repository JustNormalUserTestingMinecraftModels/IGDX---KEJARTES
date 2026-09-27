# Skin System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every student gets an optional skin, picked from a new Lobby popup, that changes their art on every screen except the end-of-grade result.

**Architecture:** A static catalog (`StudentSkins`) maps student name + skin id to four art layers by path convention; `GameState` holds the session's equipped skins and unlock overrides; every picture-of-a-student reader asks `StudentSkins` for the path instead of reading the roster dict. The popup is three authored scenes (masked `SkinFrame`, `SkinSlot`, `SkinOptionTile`) composed in `SkinSelectPopup.tscn`, opened over the Lobby.

**Tech Stack:** Godot 4.6 GDScript, `McpTestSuite` suites run through the Godot AI MCP `test_run` tool.

Spec: `docs/superpowers/specs/2026-09-18-skin-system-design.md`.

## Global Constraints

- Worktree `.claude/worktrees/skin-system`, branch `feat/skin-system`. Every MCP call passes the worktree editor's `session_id` (currently `skin-system@c9cf`; re-list with `session_manage(op="list")` after any editor restart). Never `session_activate`.
- Git: plain single commands only (no `&&`, no `cd`, no heredocs). Commit messages go to a file in the scratchpad (`$TMP/skin_msg.txt`) and `git commit -F`. Conventional Commits with scope `skins` (or `lobby`, `debug`), ending `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- No `theme_override_*` (only layout `separation`/`margin_*`); new looks are ThemeFactory variations, then rebake (`Scripts/Design/BakeTheme.gd`).
- No visual built at runtime except per-call dynamic content (the option tiles, instanced from a PackedScene).
- Every script: `##` file header and a `##` line on every `@export` (`tests/test_script_documentation.gd`).
- Suites are `@tool`, override `suite_name()`, and no test is a coroutine.
- Scripts the runner instantiates are `@tool`; real side effects in `_ready()` sit behind `if Engine.is_editor_hint(): return`, signal wiring stays ungated.
- Scene work through the editor (`scene_open` → `node_*`/`batch_execute` → `scene_save`), never a hand-edited `.tscn` while the editor has it open. Scene work first, script work second; after each `scene_save`, `git diff HEAD -- '*.gd'` for files you were not editing.
- After editing a `.gd` from outside the editor, a no-op `script_patch` on it before `test_run`.
- No emoji in game UI (the debug overlay is exempt). UI text Indonesian.
- Do not edit `Balance.gd`. Do not add persistence: equipped skins are session-scoped.
- Before committing, revert editor noise: `Assets/Audio/default_bus_layout.tres` and any `*.png.import` you did not add.

## File map

| File | Responsibility |
|---|---|
| `Assets/Images/Skins/<Name>/*_skin1.png` (+ `.import`) | the delivered art, one folder per student |
| `Assets/Images/UI/skin_switch.png` | Lobby button icon |
| `Scripts/Skins/BakeSkinPortraits.gd` | one-off headless bake of flat portraits from face-rig layers |
| `Scripts/Skins/StudentSkins.gd` | catalog + path resolvers (static) |
| `Scripts/GameState.gd` | equipped skins, unlock overrides, `skin_changed`, bridge |
| `Scripts/Skins/SkinFrame.gd`, `Scenes/Skins/SkinFrame.tscn` | rounded-rect masked art with a border, crop geometry |
| `Scripts/Skins/SkinSlot.gd`, `Scenes/Skins/SkinSlot.tscn` | tall roster card (frame + name) |
| `Scripts/Skins/SkinOptionTile.gd`, `Scenes/Skins/SkinOptionTile.tscn` | square bust-up, locked tint |
| `Scripts/Skins/SkinSelectPopup.gd`, `Scenes/Skins/SkinSelectPopup.tscn` | the popup and its option column |
| `Scripts/Design/ThemeFactory.gd` | `SkinFrameMask`, `SkinFrameBorder`, `SkinOptionColumn` |
| `Scripts/Lobby/loby.gd`, `Scenes/Lobby/loby.tscn`, `Scripts/Lobby/StudentFace.gd` | button, popup, skinned seats |
| `Scripts/AturJadwal/atur_jadwal.gd`, `Scripts/StudentCard/StudentCardView.gd`, `Scripts/StudentList/student_list.gd` | consumers through the resolver |
| `Scripts/Debug/DebugManager.gd` | lock/unlock-all toggle |
| `tests/test_student_skins.gd`, `tests/test_skin_frame.gd`, `tests/test_skin_select_popup.gd`, `tests/test_lobby_skins.gd` | new suites |

---

### Task 1: Import the skin art and bake the flat portraits

**Files:**
- Create: `Assets/Images/Skins/<Name>/splash_<name>_skin1.png`, `<name>_base_skin1.png`, `<name>_table_skin1.png`, `<name>_portrait_skin1.png` for Andi, Citra, Doni, Marcel, Shinta, Thea
- Create: `Assets/Images/UI/skin_switch.png`
- Create: `Scripts/Skins/BakeSkinPortraits.gd`

**Interfaces:**
- Produces: the 24 PNGs at the paths above (lower-case `<name>` in file names, capitalised `<Name>` folder), imported by the editor.

Source files are in the scratchpad: `…/scratchpad/skins/kos/kosmetik/` (`<Name>_Skin1.png`, `table/<name>_base_skin1.png`, `table/<name>_table_skin1.png`) and `…/scratchpad/skins/skin_switch.png`.

- [ ] **Step 1: Copy the art in**

For each Name in Andi Citra Doni Marcel Shinta Thea (lower = its lower-case):
`<Name>_Skin1.png` → `Assets/Images/Skins/<Name>/splash_<lower>_skin1.png`;
`table/<lower>_base_skin1.png` → `Assets/Images/Skins/<Name>/<lower>_base_skin1.png`;
`table/<lower>_table_skin1.png` → `Assets/Images/Skins/<Name>/<lower>_table_skin1.png`.
`skin_switch.png` → `Assets/Images/UI/skin_switch.png`.
Use a bash `for` loop with `cp`; verify with `ls Assets/Images/Skins/*`.

- [ ] **Step 2: Write the bake script**

`Scripts/Skins/BakeSkinPortraits.gd`:

```gdscript
extends SceneTree

## One-off bake of each student's flat skin portrait (the 1280x1280 picture
## StudentCard, StudentList, AturJadwal and StatCheck show) from their lobby
## face rig. The artist delivers a skin as a new rig Base layer only; the flat
## portrait is that rig at rest (Base, Sclera, Pupil clipped to the Sclera,
## Eyelashes, Eyebrows, plus any extra always-visible layer such as Marcel's
## Glasses), so this composes those layers with Image.blend_rect.
##
## Run headless from the project root:
##   Godot --headless --path . --script res://Scripts/Skins/BakeSkinPortraits.gd
## It first bakes each DEFAULT portrait and prints its mean difference from
## the shipped MuridPotrait/<Name>.png -- the check that the recipe is right --
## then writes Assets/Images/Skins/<Name>/<name>_portrait_skin1.png.
## Not used at runtime.

const NAMES := ["Andi", "Citra", "Doni", "Marcel", "Shinta", "Thea"]
## Layers never part of the resting face.
const SKIP := ["Eyelid"]


func _init() -> void:
	for n in NAMES:
		var lower: String = n.to_lower()
		var rig := (load("res://Scenes/Lobby/%sFace.tscn" % n) as PackedScene).instantiate()
		var default_img := _compose(rig, "")
		var shipped := _raw("res://Assets/Images/MuridPotrait/%s.png" % n)
		print("%s default bake diff: %.4f" % [n, _mean_diff(default_img, shipped)])
		var skin_base := "res://Assets/Images/Skins/%s/%s_base_skin1.png" % [n, lower]
		var out := _compose(rig, skin_base)
		var out_path := ProjectSettings.globalize_path("res://Assets/Images/Skins/%s/%s_portrait_skin1.png" % [n, lower])
		print("  wrote %s: %s" % [out_path, error_string(out.save_png(out_path))])
		rig.free()
	quit()


## The rig's canvas flattened. `base_override` replaces the Base layer's
## texture when non-empty.
func _compose(rig: Node, base_override: String) -> Image:
	var canvas := rig.get_node("Canvas") as Control
	var out := Image.create_empty(1280, 1280, false, Image.FORMAT_RGBA8)
	var sclera_img: Image = null
	var sclera_pos := Vector2i.ZERO
	for child in canvas.get_children():
		var layer := child as TextureRect
		if layer == null or layer.texture == null or String(layer.name) in SKIP:
			continue
		var path := layer.texture.resource_path
		if layer.name == &"Base" and base_override != "":
			path = base_override
		var img := _raw(path)
		var rect_size := Vector2i(layer.size.round())
		if img.get_size() != rect_size:
			img.resize(rect_size.x, rect_size.y, Image.INTERPOLATE_LANCZOS)
		var pos := Vector2i(layer.position.round())
		if layer.name == &"Sclera":
			sclera_img = img
			sclera_pos = pos
		if layer.name == &"Pupil" and sclera_img != null:
			_clip_to(img, pos, sclera_img, sclera_pos)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)
	return out


## Multiplies `img`'s alpha by the mask's alpha where they overlap (and zero
## elsewhere) -- eye_mask.gdshader's job, done on the CPU.
func _clip_to(img: Image, pos: Vector2i, mask: Image, mask_pos: Vector2i) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var m := Vector2i(x, y) + pos - mask_pos
			var a := 0.0
			if m.x >= 0 and m.y >= 0 and m.x < mask.get_width() and m.y < mask.get_height():
				a = mask.get_pixel(m.x, m.y).a
			var c := img.get_pixel(x, y)
			c.a *= a
			img.set_pixel(x, y, c)


func _raw(res_path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _mean_diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		b.resize(a.get_width(), a.get_height())
	var total := 0.0
	var step := 4
	var count := 0
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a)) / 4.0
			count += 1
	return total / count
```

- [ ] **Step 3: Run the bake**

Run (Bash, from the worktree):
`"/c/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --headless --path . --script res://Scripts/Skins/BakeSkinPortraits.gd`
Expected: six `default bake diff` lines, each **below 0.02**, and six `wrote … OK` lines. If a diff is above 0.02, read the six rig `.tscn` files for a layer the script mishandles (hidden layers, a material other than the eye mask), fix `_compose`, re-run. If it cannot be brought under 0.02, stop and report the numbers.

- [ ] **Step 4: Look at the bakes**

Build a contact sheet (PowerShell `System.Drawing`, 6 × 256 px) of the six `_portrait_skin1.png` beside the six shipped portraits and Read it. Expected: same faces and eyes, new clothes; no missing pupils.

- [ ] **Step 5: Import**

`filesystem_manage(op="scan", session_id=…)`, then confirm `.import` files exist next to all 25 new PNGs (`ls Assets/Images/Skins/*/*.import | wc -l` → 24, plus `Assets/Images/UI/skin_switch.png.import`).

- [ ] **Step 6: Commit**

```
git add Assets/Images/Skins Assets/Images/UI/skin_switch.png Assets/Images/UI/skin_switch.png.import Scripts/Skins/BakeSkinPortraits.gd
git commit -F $TMP/skin_msg.txt      # "feat(skins): import Skin1 art and bake flat portraits"
```
(Also `git add` the `BakeSkinPortraits.gd.uid` if the editor wrote one.)

---

### Task 2: StudentSkins catalog and GameState skin state

**Files:**
- Create: `Scripts/Skins/StudentSkins.gd`
- Modify: `Scripts/GameState.gd` (state block after `run_failed`, `forget_session()`, `student_data_from_dict()` lines 484-488)
- Test: `tests/test_student_skins.gd`

**Interfaces:**
- Produces (static, `StudentSkins`): `DEFAULT_ID := "default"`, `NAMES: Array[String]`, `LAYERS := ["splash","portrait","face_base","hand"]`, `skins_for(student_name: String) -> Array[String]`, `has_skin(student_name: String, id: String) -> bool`, `layer_path(student_name: String, id: String, layer: String) -> String`, `splash_for(student: Dictionary) -> String`, `portrait_for(student: Dictionary) -> String`, `face_base_for(student_name: String) -> String` (`""` = keep the scene's), `hand_for(student_name: String) -> String` (`""` = keep), `bust_center(student_name: String) -> Vector2`.
- Produces (`GameState`): `signal skin_changed(student_name: String)`, `var equipped_skins: Dictionary`, `var skin_unlock_overrides: Dictionary`, `equipped_skin(student_name: String) -> String`, `is_skin_unlocked(student_name: String, id: String) -> bool`, `equip_skin(student_name: String, id: String) -> bool`, `set_all_skins_locked(locked: bool) -> void`, `all_skins_locked() -> bool`.

- [ ] **Step 1: Write the failing suite**

`tests/test_student_skins.gd`:

```gdscript
@tool
extends McpTestSuite

## The skin catalog and its session state (spec:
## docs/superpowers/specs/2026-09-18-skin-system-design.md): every path the
## catalog names exists, the default entry is today's art, the resolvers fall
## back to the roster dict, and equipping obeys the lock.

var _saved_equipped: Dictionary
var _saved_overrides: Dictionary


func suite_name() -> String:
	return "student_skins"


func setup() -> void:
	_saved_equipped = GameState.equipped_skins.duplicate()
	_saved_overrides = GameState.skin_unlock_overrides.duplicate()
	GameState.equipped_skins = {}
	GameState.skin_unlock_overrides = {}


func teardown() -> void:
	GameState.equipped_skins = _saved_equipped
	GameState.skin_unlock_overrides = _saved_overrides


func _andi() -> Dictionary:
	return {
		"name": "Andi", "id": 3,
		"splash": "res://Assets/Images/SplashArtMurid/splash_andi.png",
		"portrait": "res://Assets/Images/MuridPotrait/Andi.png",
	}


func test_every_student_has_default_then_skin1() -> void:
	assert_eq(StudentSkins.NAMES.size(), 6)
	for n in StudentSkins.NAMES:
		assert_eq(StudentSkins.skins_for(n), ["default", "skin1"] as Array[String], n)


func test_every_catalog_path_exists() -> void:
	for n in StudentSkins.NAMES:
		for id in StudentSkins.skins_for(n):
			for layer in StudentSkins.LAYERS:
				var p := StudentSkins.layer_path(n, id, layer)
				assert_true(ResourceLoader.exists(p), "%s/%s/%s missing: %s" % [n, id, layer, p])


func test_default_entry_is_todays_art() -> void:
	assert_eq(StudentSkins.layer_path("Thea", "default", "splash"), "res://Assets/Images/SplashArtMurid/splash_thea.png")
	assert_eq(StudentSkins.layer_path("Thea", "default", "portrait"), "res://Assets/Images/MuridPotrait/Thea.png")
	assert_eq(StudentSkins.layer_path("Thea", "default", "face_base"), "res://Assets/Images/MuridPotrait/Thea/thea_base.png")
	assert_eq(StudentSkins.layer_path("Thea", "default", "hand"), "res://Assets/Images/MuridPotrait/TanganItems/Thea_Table.png")


func test_skin1_paths_follow_the_skins_folder() -> void:
	assert_eq(StudentSkins.layer_path("Andi", "skin1", "splash"), "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
	assert_eq(StudentSkins.layer_path("Andi", "skin1", "hand"), "res://Assets/Images/Skins/Andi/andi_table_skin1.png")


func test_unknown_name_and_id() -> void:
	assert_eq(StudentSkins.skins_for("Murid1"), [] as Array[String])
	assert_false(StudentSkins.has_skin("Andi", "skin9"))
	assert_eq(StudentSkins.layer_path("Andi", "skin9", "splash"), "")
	assert_eq(StudentSkins.bust_center("Murid1"), StudentSkins.FALLBACK_BUST_CENTER)


func test_resolvers_fall_back_to_the_dict_when_default() -> void:
	var s := _andi()
	assert_eq(StudentSkins.splash_for(s), s["splash"])
	assert_eq(StudentSkins.portrait_for(s), s["portrait"])
	assert_eq(StudentSkins.face_base_for("Andi"), "")
	assert_eq(StudentSkins.hand_for("Andi"), "")
	var stranger := {"name": "Murid1", "splash": "res://x.png", "portrait": "res://y.png"}
	assert_eq(StudentSkins.splash_for(stranger), "res://x.png")


func test_equipped_skin_wins_and_dict_is_untouched() -> void:
	var s := _andi()
	assert_true(GameState.equip_skin("Andi", "skin1"))
	assert_eq(StudentSkins.splash_for(s), "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
	assert_eq(StudentSkins.portrait_for(s), "res://Assets/Images/Skins/Andi/andi_portrait_skin1.png")
	assert_eq(StudentSkins.face_base_for("Andi"), "res://Assets/Images/Skins/Andi/andi_base_skin1.png")
	assert_eq(StudentSkins.hand_for("Andi"), "res://Assets/Images/Skins/Andi/andi_table_skin1.png")
	assert_eq(s["splash"], "res://Assets/Images/SplashArtMurid/splash_andi.png", "the roster dict keeps its base art")


func test_equip_refuses_unknown_and_locked() -> void:
	assert_false(GameState.equip_skin("Andi", "skin9"))
	GameState.set_all_skins_locked(true)
	assert_true(GameState.all_skins_locked())
	assert_false(GameState.is_skin_unlocked("Andi", "skin1"))
	assert_true(GameState.is_skin_unlocked("Andi", "default"), "default never locks")
	assert_false(GameState.equip_skin("Andi", "skin1"))
	assert_eq(GameState.equipped_skin("Andi"), "default")


func test_locking_all_unequips_a_worn_skin() -> void:
	GameState.equip_skin("Citra", "skin1")
	GameState.set_all_skins_locked(true)
	assert_eq(GameState.equipped_skin("Citra"), "default")
	GameState.set_all_skins_locked(false)
	assert_false(GameState.all_skins_locked())
	assert_true(GameState.equip_skin("Citra", "skin1"))


func test_equip_emits_skin_changed() -> void:
	var got: Array = []
	var cb := func(n: String) -> void: got.append(n)
	GameState.skin_changed.connect(cb)
	GameState.equip_skin("Doni", "skin1")
	GameState.equip_skin("Doni", "skin1")
	GameState.skin_changed.disconnect(cb)
	assert_eq(got, ["Doni"], "emits once; re-equipping the worn skin is silent")


func test_bridge_uses_the_skin() -> void:
	GameState.equip_skin("Andi", "skin1")
	var sd := GameState.student_data_from_dict(_andi())
	assert_eq(sd.splash_path, "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
	assert_eq(sd.avatar_texture.resource_path, "res://Assets/Images/Skins/Andi/andi_portrait_skin1.png")


func test_forget_session_source_clears_skins() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var body := src.substr(src.find("func forget_session"), 2000)
	assert_true(body.contains("equipped_skins = {}"))
	assert_true(body.contains("skin_unlock_overrides = {}"))


func test_grade_reset_keeps_skins() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var body := src.substr(src.find("func reset_roster_for_new_grade"), 900)
	assert_false(body.contains("equipped_skins"), "a skin follows the character across grades")
```

- [ ] **Step 2: Run it — expect failure**

`test_run(suite="student_skins", session_id=…)` → FAIL / parse error (`StudentSkins` undefined).

- [ ] **Step 3: Write the catalog**

`Scripts/Skins/StudentSkins.gd`:

```gdscript
class_name StudentSkins
extends RefCounted

## The skin catalog: which skins each of the six characters has, and where
## each skin's four art layers live. Static -- the equipped skin and lock
## state are GameState's (equipped_skin / is_skin_unlocked).
##
## Paths follow a convention instead of a table, so adding "skin2" for a
## student is: drop four PNGs in Assets/Images/Skins/<Name>/ and append the id
## to SKINS. test_student_skins checks every resulting path exists.
##
## Every screen that turns a student into a picture asks this script
## (splash_for / portrait_for / face_base_for / hand_for) instead of reading
## the roster dict's "splash" / "portrait" keys, which always keep the base
## art. The end-of-grade result screens (WinStage, WinLineup, RunResult) use
## their own win art and do not ask.

## The id of each student's original look. Always first, never locked.
const DEFAULT_ID := "default"
## The four art layers a skin replaces.
const LAYERS: Array[String] = ["splash", "portrait", "face_base", "hand"]
## Skin ids per student, in display order.
const SKINS: Dictionary = {
	"Andi": ["default", "skin1"],
	"Citra": ["default", "skin1"],
	"Doni": ["default", "skin1"],
	"Marcel": ["default", "skin1"],
	"Shinta": ["default", "skin1"],
	"Thea": ["default", "skin1"],
}
## The six characters, in SKINS order.
const NAMES: Array[String] = ["Andi", "Citra", "Doni", "Marcel", "Shinta", "Thea"]
## Whether a non-default skin starts unlocked. Every shipped skin does until
## there is a way to earn one; the debug overlay can lock them all.
const UNLOCKED_BY_DEFAULT := true
## Head centre in splash pixels (1080x1920 canvas), for the bust crops.
## A skin shares its student's registration, so one point per student.
const BUST_CENTERS: Dictionary = {
	"Andi": Vector2(500, 340),
	"Citra": Vector2(540, 360),
	"Doni": Vector2(500, 380),
	"Marcel": Vector2(500, 380),
	"Shinta": Vector2(540, 400),
	"Thea": Vector2(520, 340),
}
## Bust centre for a name not in BUST_CENTERS: upper middle of the canvas.
const FALLBACK_BUST_CENTER := Vector2(540, 380)


static func skins_for(student_name: String) -> Array[String]:
	var out: Array[String] = []
	for id in SKINS.get(student_name, []):
		out.append(String(id))
	return out


static func has_skin(student_name: String, id: String) -> bool:
	return skins_for(student_name).has(id)


## The res:// path of one layer of one skin, or "" when the student, skin or
## layer is unknown.
static func layer_path(student_name: String, id: String, layer: String) -> String:
	if not has_skin(student_name, id) or not LAYERS.has(layer):
		return ""
	var lower := student_name.to_lower()
	if id == DEFAULT_ID:
		match layer:
			"splash": return "res://Assets/Images/SplashArtMurid/splash_%s.png" % lower
			"portrait": return "res://Assets/Images/MuridPotrait/%s.png" % student_name
			"face_base": return "res://Assets/Images/MuridPotrait/%s/%s_base.png" % [student_name, lower]
			"hand": return "res://Assets/Images/MuridPotrait/TanganItems/%s_Table.png" % student_name
	var folder := "res://Assets/Images/Skins/%s/" % student_name
	match layer:
		"splash": return folder + "splash_%s_%s.png" % [lower, id]
		"portrait": return folder + "%s_portrait_%s.png" % [lower, id]
		"face_base": return folder + "%s_base_%s.png" % [lower, id]
		"hand": return folder + "%s_table_%s.png" % [lower, id]
	return ""


## The splash to show for a roster dict: the equipped skin's, else the
## dict's own "splash".
static func splash_for(student: Dictionary) -> String:
	return _resolve(student, "splash")


## The flat portrait to show for a roster dict: the equipped skin's, else the
## dict's own "portrait".
static func portrait_for(student: Dictionary) -> String:
	return _resolve(student, "portrait")


## The equipped skin's face-rig Base layer, or "" to keep the rig's own.
static func face_base_for(student_name: String) -> String:
	return _equipped_layer(student_name, "face_base")


## The equipped skin's desk-hands art, or "" to keep the scene's own.
static func hand_for(student_name: String) -> String:
	return _equipped_layer(student_name, "hand")


static func bust_center(student_name: String) -> Vector2:
	return BUST_CENTERS.get(student_name, FALLBACK_BUST_CENTER)


static func _resolve(student: Dictionary, layer: String) -> String:
	var path := _equipped_layer(str(student.get("name", "")), layer)
	return path if path != "" else str(student.get(layer, ""))


static func _equipped_layer(student_name: String, layer: String) -> String:
	var id: String = GameState.equipped_skin(student_name)
	if id == DEFAULT_ID:
		return ""
	return layer_path(student_name, id, layer)
```

- [ ] **Step 4: Add the GameState state**

In `Scripts/GameState.gd`, after `var run_failed: bool = false` (line 85):

```gdscript

## Emitted when a student's worn skin changes (equip_skin, or a debug lock
## that strips it).
signal skin_changed(student_name: String)
## Student name -> skin id they wear. Absent means StudentSkins.DEFAULT_ID.
## Keyed by name, not roster id, so a skin follows the character across
## grades. Session-scoped like the roster -- not saved.
var equipped_skins: Dictionary = {}
## "Name:skin_id" -> unlocked. Absent means StudentSkins.UNLOCKED_BY_DEFAULT.
## Only the debug overlay writes it (set_all_skins_locked).
var skin_unlock_overrides: Dictionary = {}


func equipped_skin(student_name: String) -> String:
	return equipped_skins.get(student_name, StudentSkins.DEFAULT_ID)


func is_skin_unlocked(student_name: String, id: String) -> bool:
	if not StudentSkins.has_skin(student_name, id):
		return false
	if id == StudentSkins.DEFAULT_ID:
		return true
	return skin_unlock_overrides.get("%s:%s" % [student_name, id], StudentSkins.UNLOCKED_BY_DEFAULT)


## Wears skin `id` on `student_name`. False, and nothing changes, when the
## skin is unknown or locked. Re-equipping the worn skin succeeds silently.
func equip_skin(student_name: String, id: String) -> bool:
	if not is_skin_unlocked(student_name, id):
		return false
	if equipped_skin(student_name) == id:
		return true
	if id == StudentSkins.DEFAULT_ID:
		equipped_skins.erase(student_name)
	else:
		equipped_skins[student_name] = id
	skin_changed.emit(student_name)
	return true


## Debug: lock (or unlock) every non-default skin. Locking strips a worn skin
## back to default, so nothing shows art the player could not pick.
func set_all_skins_locked(locked: bool) -> void:
	for n in StudentSkins.NAMES:
		for id in StudentSkins.skins_for(n):
			if id == StudentSkins.DEFAULT_ID:
				continue
			skin_unlock_overrides["%s:%s" % [n, id]] = not locked
			if locked and equipped_skin(n) == id:
				equip_skin(n, StudentSkins.DEFAULT_ID)


## True when set_all_skins_locked(true) is in force.
func all_skins_locked() -> bool:
	for key in skin_unlock_overrides:
		if skin_unlock_overrides[key] == false:
			return true
	return false
```

In `forget_session()`, after `run_failed = false`:

```gdscript
	equipped_skins = {}
	skin_unlock_overrides = {}
```

In `student_data_from_dict()`, replace lines 484-488:

```gdscript
	sd.splash_path = StudentSkins.splash_for(dict)

	var port_path := StudentSkins.portrait_for(dict)
	if port_path != "" and ResourceLoader.exists(port_path):
		sd.avatar_texture = load(port_path)
```

- [ ] **Step 5: Reload and run**

No-op `script_patch` on `Scripts/GameState.gd` and `Scripts/Skins/StudentSkins.gd` (they were edited from outside), `filesystem_manage(op="scan")`, then `test_run(suite="student_skins", session_id=…)` → all pass. If `GameState` still serves the old script, restart the worktree editor (quit via `editor_manage(op="quit")`, relaunch detached with `Invoke-CimMethod Win32_Process Create`) and re-list the session id.

- [ ] **Step 6: Check the bust centres**

For each student, draw a 12 px dot at `BUST_CENTERS[name]` on a copy of both splashes (PowerShell `System.Drawing`, scaled 0.25) and Read the sheet. Expected: each dot sits between the eyes/nose. Adjust any that miss by more than ~40 source px and re-run the suite.

- [ ] **Step 7: Commit** — `feat(skins): StudentSkins catalog and GameState skin state` (add both scripts, their `.uid`s, the suite and its `.uid`).

---

### Task 3: Route every student-picture reader through the resolver

**Files:**
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:630-634`
- Modify: `Scripts/StudentCard/StudentCardView.gd:74`
- Modify: `Scripts/StudentList/student_list.gd:263`, `:382`
- Modify: `Scripts/Lobby/loby.gd:293`
- Test: `tests/test_student_skins.gd` (append)

**Interfaces:**
- Consumes: `StudentSkins.splash_for(student: Dictionary)`, `StudentSkins.portrait_for(student: Dictionary)`.

- [ ] **Step 1: Append the failing scans**

```gdscript
## Every screen that draws a student from a roster dict goes through the
## resolver (a scan: most of these screens cannot be built headlessly).
func test_consumers_use_the_resolver() -> void:
	var sites := {
		"res://Scripts/AturJadwal/atur_jadwal.gd": ["StudentSkins.splash_for(", "StudentSkins.portrait_for("],
		"res://Scripts/StudentCard/StudentCardView.gd": ["StudentSkins.portrait_for("],
		"res://Scripts/StudentList/student_list.gd": ["StudentSkins.portrait_for("],
		"res://Scripts/Lobby/loby.gd": ["StudentSkins.portrait_for("],
	}
	for path in sites:
		var src := FileAccess.get_file_as_string(path)
		for needle in sites[path]:
			assert_true(src.contains(needle), "%s must call %s" % [path, needle])
		assert_false(src.contains("get(\"portrait\""), "%s still reads the raw portrait key" % path)


func test_result_screens_keep_their_own_art() -> void:
	for path in ["res://Scripts/EndGame/WinStage.gd", "res://Scripts/EndGame/WinLineup.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("StudentSkins"), path)
```

- [ ] **Step 2: Run — expect the first to fail** (`test_run(suite="student_skins", test_name="consumers")`).

- [ ] **Step 3: Edit the five sites**

Read each site first (±10 lines) to get the dict variable's name, then replace:
- `atur_jadwal.gd:630` `student.get("splash", "")` → `StudentSkins.splash_for(student)`; `:634` `student.get("portrait", "")` → `StudentSkins.portrait_for(student)`.
- `StudentCardView.gd:74` `student.get("portrait", "")` → `StudentSkins.portrait_for(student)`.
- `student_list.gd:263` `student_data.get("portrait", "")` → `StudentSkins.portrait_for(student_data)`; `:382` `student.get("portrait", "")` → `StudentSkins.portrait_for(student)`.
- `loby.gd:293` `s.get("portrait", "")` → `StudentSkins.portrait_for(s)`.

Use `script_patch` for each (single-line anchors; LF files).

- [ ] **Step 4: Run** `student_skins`, `atur_jadwal`, `student_list`, `lobby` suites (use each file's `suite_name()`; grep `tests/` for them) → pass.

- [ ] **Step 5: Commit** — `feat(skins): draw students through the skin resolver`.

---

### Task 4: Skinned Lobby seats (face base and desk hands)

**Files:**
- Modify: `Scripts/Lobby/StudentFace.gd` (new method after the exports)
- Modify: `Scripts/Lobby/loby.gd` (`_show_hand_for` caller in `_setup_students`, face block)
- Test: `tests/test_lobby_skins.gd`

**Interfaces:**
- Consumes: `StudentSkins.face_base_for(name) -> String`, `StudentSkins.hand_for(name) -> String`.
- Produces: `StudentFace.set_base_texture(tex: Texture2D) -> void`; loby `_apply_hand_skins(h_slot: Node) -> void`; meta key `&"default_texture"` on Hand_* nodes.

- [ ] **Step 1: Write the failing suite**

`tests/test_lobby_skins.gd`:

```gdscript
@tool
extends McpTestSuite

## The Lobby diorama wears the equipped skin: the face rig's Base layer and
## the Hand_<Name> desk art swap, and swap back for the default.

var _saved: Dictionary


func suite_name() -> String:
	return "lobby_skins"


func setup() -> void:
	_saved = GameState.equipped_skins.duplicate()
	GameState.equipped_skins = {}


func teardown() -> void:
	GameState.equipped_skins = _saved


func test_face_base_swaps() -> void:
	var face := (load("res://Scenes/Lobby/TheaFace.tscn") as PackedScene).instantiate() as StudentFace
	track(face)
	var tex := load("res://Assets/Images/Skins/Thea/thea_base_skin1.png") as Texture2D
	face.set_base_texture(tex)
	assert_eq((face.get_node("Canvas/Base") as TextureRect).texture, tex)


func test_hand_skins_swap_and_restore() -> void:
	var loby_script := load("res://Scripts/Lobby/loby.gd")
	var lobby := Control.new()
	lobby.set_script(loby_script)
	track(lobby)
	var slot := Control.new()
	track(slot)
	var hand := TextureRect.new()
	hand.name = "Hand_Andi"
	var base_tex := load("res://Assets/Images/MuridPotrait/TanganItems/Andi_Table.png") as Texture2D
	hand.texture = base_tex
	slot.add_child(hand)
	GameState.equip_skin("Andi", "skin1")
	lobby._apply_hand_skins(slot)
	assert_eq(hand.texture.resource_path, "res://Assets/Images/Skins/Andi/andi_table_skin1.png")
	GameState.equip_skin("Andi", "default")
	lobby._apply_hand_skins(slot)
	assert_eq(hand.texture, base_tex, "default restores the authored texture")


func test_setup_students_wires_both() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("_apply_hand_skins(h_slot)"))
	assert_true(src.contains("StudentSkins.face_base_for("))
	assert_true(src.contains("face.set_base_texture("))
```

- [ ] **Step 2: Run — expect failure** (`test_run(suite="lobby_skins")`). If instantiating `loby.gd` on a bare Control errors on `@onready` paths, change the second test to call a static helper instead: make `_apply_hand_skins` a `static func` taking the slot, and call `loby_script._apply_hand_skins(slot)` (update the scan accordingly).

- [ ] **Step 3: StudentFace method**

After the `motion_seed` export block in `StudentFace.gd`:

```gdscript

## Swaps the Base layer's art -- how a skin re-dresses the rig. Every other
## layer (eyes, brows, Marcel's glasses) is shared by all of a student's skins.
func set_base_texture(tex: Texture2D) -> void:
	(get_node(CANVAS_PATH).get_node(^"Base") as TextureRect).texture = tex
```

- [ ] **Step 4: Lobby wiring**

In `loby.gd`, after `_show_hand_for(...)` (which only picks the visible node), add `_apply_hand_skins(h_slot)`. In the `if face != null:` block, before `_match_rect`, add:

```gdscript
				var skin_base := StudentSkins.face_base_for(str(s.get("name", "")))
				if skin_base != "":
					face.set_base_texture(load(skin_base))
```

(The rig is re-instanced on every `_setup_students()`, so the default needs no restore.) Add after `_show_hand_for`:

```gdscript
## Dresses every Hand_<Name> node in this slot in its student's equipped
## skin, restoring the authored texture for the default. Only the texture is
## touched: the per-node transforms are hand-authored (see _show_hand_for).
## The first call stashes each node's authored texture in its
## "default_texture" meta so a later default can put it back.
func _apply_hand_skins(h_slot: Node) -> void:
	for child in h_slot.get_children():
		if not child.name.begins_with(HAND_NODE_PREFIX) or not child is TextureRect:
			continue
		var hand := child as TextureRect
		if not hand.has_meta(&"default_texture"):
			hand.set_meta(&"default_texture", hand.texture)
		var who := String(hand.name).substr(HAND_NODE_PREFIX.length())
		var path := StudentSkins.hand_for(who)
		hand.texture = load(path) if path != "" else hand.get_meta(&"default_texture")
```

- [ ] **Step 5: Run** `lobby_skins`, `lobby`, `lobby_layout`, `face_rig_roster`, `student_face` → pass.

- [ ] **Step 6: Commit** — `feat(lobby): seat students in their equipped skin`.

---

### Task 5: Theme variations for the masked frames

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_panels`)
- Rebake: `Assets/Theme/kejartes_theme.tres`
- Test: `tests/test_skin_frame.gd` (created here, extended in Task 6)

**Interfaces:**
- Produces: theme types `SkinFrameMask`, `SkinFrameBorder`, `SkinOptionColumn` (all `Panel` variations).

- [ ] **Step 1: Failing test** — `tests/test_skin_frame.gd`:

```gdscript
@tool
extends McpTestSuite

## SkinFrame (the masked, bordered student art in the skin popup) and the
## theme variations it draws with.


func suite_name() -> String:
	return "skin_frame"


func test_factory_builds_the_skin_panels() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	for name in ["SkinFrameMask", "SkinFrameBorder", "SkinOptionColumn"]:
		assert_eq(theme.get_type_variation_base(name), &"Panel", name)
	var mask := theme.get_stylebox("panel", "SkinFrameMask") as StyleBoxFlat
	assert_eq(mask.bg_color.a, 1.0, "the mask is opaque: it is what clips the art")
	assert_eq(mask.corner_radius_top_left, ThemeFactory.SKIN_FRAME_RADIUS)
	var border := theme.get_stylebox("panel", "SkinFrameBorder") as StyleBoxFlat
	assert_false(border.draw_center, "the border draws no fill over the art")
	assert_eq(border.border_width_left, ThemeFactory.SKIN_BORDER_WIDTH)
	assert_eq(border.border_color, t.brand_primary)
	var column := theme.get_stylebox("panel", "SkinOptionColumn") as StyleBoxFlat
	assert_eq(column.border_color, t.brand_primary)
	assert_eq(column.bg_color, t.surface_card)
```

- [ ] **Step 2: Run — fail.**

- [ ] **Step 3: Implement** — near the other mockup-measured constants at the top of `ThemeFactory.gd`:

```gdscript
## Measured off skinselect_mockup.png: the student frames' corner radius and
## brown outline width. No token matches; the colours still come from tokens.
const SKIN_FRAME_RADIUS := 72
const SKIN_BORDER_WIDTH := 10
## The option column's corner radius (skinselectoption_mockup.png).
const SKIN_COLUMN_RADIUS := 60
```

At the end of `_build_panels`:

```gdscript
	# The skin popup's masked student art (SkinFrame.tscn): an opaque rounded
	# fill that clip_children uses as the mask, and a fill-less brown outline
	# drawn over the art.
	theme.add_type("SkinFrameMask")
	theme.set_type_variation("SkinFrameMask", "Panel")
	var skin_mask := StyleBoxFlat.new()
	skin_mask.bg_color = tokens.surface_card
	skin_mask.set_corner_radius_all(SKIN_FRAME_RADIUS)
	theme.set_stylebox("panel", "SkinFrameMask", skin_mask)

	theme.add_type("SkinFrameBorder")
	theme.set_type_variation("SkinFrameBorder", "Panel")
	var skin_border := StyleBoxFlat.new()
	skin_border.draw_center = false
	skin_border.border_color = tokens.brand_primary
	skin_border.set_border_width_all(SKIN_BORDER_WIDTH)
	skin_border.set_corner_radius_all(SKIN_FRAME_RADIUS)
	theme.set_stylebox("panel", "SkinFrameBorder", skin_border)

	theme.add_type("SkinOptionColumn")
	theme.set_type_variation("SkinOptionColumn", "Panel")
	var skin_column := StyleBoxFlat.new()
	skin_column.bg_color = tokens.surface_card
	skin_column.border_color = tokens.brand_primary
	skin_column.set_border_width_all(SKIN_BORDER_WIDTH)
	skin_column.set_corner_radius_all(SKIN_COLUMN_RADIUS)
	theme.set_stylebox("panel", "SkinOptionColumn", skin_column)
```

- [ ] **Step 4:** no-op `script_patch` on `ThemeFactory.gd`; rebake: `test_run(suite="theme_rebake")` (its `ResourceSaver.save` writes the bake); then `test_run(suite="skin_frame")` and `theme_factory` → pass. `git diff --stat Assets/Theme/kejartes_theme.tres` must show only additions for the three types (diff it by content per the rebake memory; restart the editor before the next `scene_save`).

- [ ] **Step 5: Commit** — `feat(skins): theme variations for the skin frames` (ThemeFactory, bake, suite + uid).

---

### Task 6: SkinFrame — the masked art piece

**Files:**
- Create: `Scripts/Skins/SkinFrame.gd`, `Scenes/Skins/SkinFrame.tscn`
- Test: `tests/test_skin_frame.gd` (append)

**Interfaces:**
- Produces: `class_name SkinFrame extends Control`; `@export var visible_source_height: float = 1050.0`; `@export_range(0.0, 1.0) var face_y_ratio: float = 0.3`; `show_art(tex: Texture2D, center: Vector2) -> void`; nodes `Mask` (Panel, `SkinFrameMask`, `clip_children = 2`), `Mask/Art` (TextureRect), `Border` (Panel, `SkinFrameBorder`).

- [ ] **Step 1: Append failing tests**

```gdscript
const FRAME := "res://Scenes/Skins/SkinFrame.tscn"


func _frame() -> SkinFrame:
	var f := (load(FRAME) as PackedScene).instantiate() as SkinFrame
	track(f)
	return f


func test_scene_contract() -> void:
	var f := _frame()
	var mask := f.get_node("Mask") as Panel
	assert_eq(mask.theme_type_variation, &"SkinFrameMask")
	assert_eq(mask.clip_children, CanvasItem.CLIP_CHILDREN_AND_DRAW)
	assert_true(f.get_node("Mask/Art") is TextureRect)
	assert_eq((f.get_node("Border") as Panel).theme_type_variation, &"SkinFrameBorder")
	assert_eq(f.get_child_count(), 2, "Border is a sibling after Mask, so it is not clipped")
	for n in ["Mask", "Mask/Art", "Border"]:
		assert_eq((f.get_node(n) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, n)


func test_show_art_places_the_face() -> void:
	var f := _frame()
	f.size = Vector2(200, 400)
	f.visible_source_height = 800.0
	f.face_y_ratio = 0.25
	var tex := load("res://Assets/Images/SplashArtMurid/splash_andi.png") as Texture2D
	f.show_art(tex, Vector2(500, 300))
	var art := f.get_node("Mask/Art") as TextureRect
	assert_eq(art.texture, tex)
	assert_eq(art.size, Vector2(540, 960), "scale = 400 / 800")
	assert_eq(art.position, Vector2(100 - 250, 100 - 150), "centre x mid-frame, face at 25% height")


func test_relayout_on_resize() -> void:
	var f := _frame()
	f.size = Vector2(200, 400)
	f.visible_source_height = 800.0
	f.show_art(load("res://Assets/Images/SplashArtMurid/splash_andi.png"), Vector2(500, 300))
	f.size = Vector2(200, 800)
	assert_eq((f.get_node("Mask/Art") as TextureRect).size, Vector2(1080, 1920))


func test_null_texture_clears() -> void:
	var f := _frame()
	f.size = Vector2(200, 400)
	f.show_art(null, Vector2.ZERO)
	assert_eq((f.get_node("Mask/Art") as TextureRect).texture, null)
```

- [ ] **Step 2: Run — fail.**

- [ ] **Step 3: Script** — `Scripts/Skins/SkinFrame.gd`:

```gdscript
@tool
class_name SkinFrame
extends Control

## A student's art cropped into a rounded rectangle with a brown outline --
## the skin popup's tall roster cards and square bust-ups (SkinFrame.tscn,
## mockups skinselect_mockup.png / skinselectoption_mockup.png).
##
## Mask is an opaque rounded Panel with clip_children, so the Art inside it is
## clipped to the rounded shape; Border is a fill-less outline drawn on top as
## a sibling, so it is never clipped. This script only lays out Art: it scales
## the texture so `visible_source_height` source pixels fill the frame's
## height and places the given head point mid-width at `face_y_ratio` down.
## Pure geometry on authored nodes -- nothing is created here.

## Source (splash) pixels shown top-to-bottom. Smaller zooms in.
@export var visible_source_height: float = 1050.0:
	set(v):
		visible_source_height = maxf(v, 1.0)
		_layout()
## Where the head point lands, as a fraction of the frame's height from the top.
@export_range(0.0, 1.0) var face_y_ratio: float = 0.3:
	set(v):
		face_y_ratio = v
		_layout()

var _texture: Texture2D
var _center: Vector2 = Vector2.ZERO


## Shows `tex` with source point `center` (usually StudentSkins.bust_center)
## placed by the knobs above. A null texture clears the frame.
func show_art(tex: Texture2D, center: Vector2) -> void:
	_texture = tex
	_center = center
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var art := get_node_or_null(^"Mask/Art") as TextureRect
	if art == null:
		return
	art.texture = _texture
	if _texture == null or size.y <= 0.0:
		return
	var s := size.y / visible_source_height
	art.size = _texture.get_size() * s
	art.position = Vector2(size.x * 0.5 - _center.x * s, size.y * face_y_ratio - _center.y * s)
```

- [ ] **Step 4: Scene** — through the worktree editor: `scene_manage(op="create")` (or the plugin's new-scene command) `res://Scenes/Skins/SkinFrame.tscn`, root `Control` named `SkinFrame`, script `SkinFrame.gd`, size 200×460, `mouse_filter = 2`. Children:
  - `Mask` Panel: `layout_mode = 1`, anchors 0,0,1,1, offsets 0, `theme_type_variation = &"SkinFrameMask"`, `clip_children = 2`, `mouse_filter = 2`.
  - `Mask/Art` TextureRect: `layout_mode = 1`, anchors all 0, `expand_mode = 1` (ignore size), `stretch_mode = 0` (scale), `mouse_filter = 2`.
  - `Border` Panel: `layout_mode = 1`, anchors 0,0,1,1, `theme_type_variation = &"SkinFrameBorder"`, `mouse_filter = 2`.
  `scene_save`. Check `git diff HEAD -- '*.gd'`.

- [ ] **Step 5: Run** `skin_frame`, `script_documentation`, `viewport_editability` → pass.

- [ ] **Step 6: Commit** — `feat(skins): SkinFrame masked student art`.

---

### Task 7: SkinSlot and SkinOptionTile

**Files:**
- Create: `Scripts/Skins/SkinSlot.gd`, `Scenes/Skins/SkinSlot.tscn`, `Scripts/Skins/SkinOptionTile.gd`, `Scenes/Skins/SkinOptionTile.tscn`
- Test: `tests/test_skin_select_popup.gd` (created here)

**Interfaces:**
- Consumes: `SkinFrame.show_art`, `StudentSkins.splash_for`, `layer_path`, `bust_center`.
- Produces: `class_name SkinSlot extends Button` — `var student_name: String`, `show_student(student: Dictionary) -> void`; nodes `Frame` (SkinFrame), `Name` (Label). `class_name SkinOptionTile extends Button` — `@export var locked_tint: Color`, `var skin_id: String`, `show_skin(student_name: String, id: String, locked: bool) -> void`; node `Frame`.

- [ ] **Step 1: Failing suite** — `tests/test_skin_select_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## The skin popup (spec: docs/superpowers/specs/2026-09-18-skin-system-design.md):
## its slot and tile templates, and the popup that composes them.

const SLOT := "res://Scenes/Skins/SkinSlot.tscn"
const TILE := "res://Scenes/Skins/SkinOptionTile.tscn"
const POPUP := "res://Scenes/Skins/SkinSelectPopup.tscn"

var _saved_equipped: Dictionary
var _saved_overrides: Dictionary


func suite_name() -> String:
	return "skin_select_popup"


func setup() -> void:
	_saved_equipped = GameState.equipped_skins.duplicate()
	_saved_overrides = GameState.skin_unlock_overrides.duplicate()
	GameState.equipped_skins = {}
	GameState.skin_unlock_overrides = {}


func teardown() -> void:
	GameState.equipped_skins = _saved_equipped
	GameState.skin_unlock_overrides = _saved_overrides


func _student(n: String) -> Dictionary:
	return {"name": n, "splash": "res://Assets/Images/SplashArtMurid/splash_%s.png" % n.to_lower(),
		"portrait": "res://Assets/Images/MuridPotrait/%s.png" % n}


func _inst(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	track(n)
	return n


func test_slot_shows_the_equipped_splash_and_name() -> void:
	var slot := _inst(SLOT) as SkinSlot
	slot.size = Vector2(200, 560)
	GameState.equip_skin("Thea", "skin1")
	slot.show_student(_student("Thea"))
	assert_eq(slot.student_name, "Thea")
	assert_eq((slot.get_node("Name") as Label).text, "THEA")
	var art := slot.get_node("Frame/Mask/Art") as TextureRect
	assert_eq(art.texture.resource_path, "res://Assets/Images/Skins/Thea/splash_thea_skin1.png")


func test_slot_contract() -> void:
	var slot := _inst(SLOT) as SkinSlot
	assert_true(slot.get_node("Frame") is SkinFrame)
	assert_eq((slot.get_node("Frame") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((slot.get_node("Name") as Label).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_tile_locked_is_dark_and_disabled() -> void:
	var tile := _inst(TILE) as SkinOptionTile
	tile.show_skin("Andi", "skin1", true)
	assert_true(tile.disabled)
	assert_eq(tile.modulate, tile.locked_tint)
	assert_gt(1.0, tile.locked_tint.v, "the tint darkens")
	tile.show_skin("Andi", "skin1", false)
	assert_false(tile.disabled)
	assert_eq(tile.modulate, Color.WHITE)
	assert_eq(tile.skin_id, "skin1")
	var art := tile.get_node("Frame/Mask/Art") as TextureRect
	assert_eq(art.texture.resource_path, "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
```

- [ ] **Step 2: Run — fail.**

- [ ] **Step 3: Scripts**

`Scripts/Skins/SkinSlot.gd`:

```gdscript
@tool
class_name SkinSlot
extends Button

## One roster card in the skin popup (SkinSlot.tscn): the student's current
## splash in a tall SkinFrame, their name in capitals underneath. The popup
## listens to `pressed` to open this student's skin column.

## Roster name of the student shown, "" before show_student().
var student_name: String = ""


## Shows `student` (a GameState.approved_students dict) in the skin they
## wear now.
func show_student(student: Dictionary) -> void:
	student_name = str(student.get("name", ""))
	(get_node(^"Name") as Label).text = student_name.to_upper()
	var path := StudentSkins.splash_for(student)
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Frame") as SkinFrame).show_art(tex, StudentSkins.bust_center(student_name))
```

`Scripts/Skins/SkinOptionTile.gd`:

```gdscript
@tool
class_name SkinOptionTile
extends Button

## One skin in the popup's option column (SkinOptionTile.tscn): a square
## bust-up of that skin's splash. A locked skin is darkened and disabled.

## Modulate applied to a locked tile.
@export var locked_tint: Color = Color(0.32, 0.32, 0.32, 1.0)

## The skin this tile stands for.
var skin_id: String = ""


func show_skin(student_name: String, id: String, locked: bool) -> void:
	skin_id = id
	var path := StudentSkins.layer_path(student_name, id, "splash")
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Frame") as SkinFrame).show_art(tex, StudentSkins.bust_center(student_name))
	disabled = locked
	modulate = locked_tint if locked else Color.WHITE
```

- [ ] **Step 4: Scenes** (editor):
  - `SkinSlot.tscn`: root `Button` `SkinSlot`, script, `theme_type_variation = &"GhostButton"` (verify it exists: `grep -n '"GhostButton"' Scripts/Design/ThemeFactory.gd`; if not, use `flat = true`), `custom_minimum_size = Vector2(200, 560)`. Children: `Frame` = instance of `SkinFrame.tscn`, `layout_mode = 1`, anchors (0,0,1,0), `offset_bottom = 462`, `mouse_filter = 2`, `visible_source_height = 1050`, `face_y_ratio = 0.28`; `Name` Label, anchors (0,1,1,1), `offset_top = -80`, `theme_type_variation = &"H2Label"`, `horizontal_alignment = 1`, `mouse_filter = 2`.
  - `SkinOptionTile.tscn`: root `Button` `SkinOptionTile`, script, same ghost variation, `custom_minimum_size = Vector2(190, 190)`. Child `Frame` = SkinFrame instance, anchors (0,0,1,1), `mouse_filter = 2`, `visible_source_height = 560`, `face_y_ratio = 0.42`.
  `scene_save` each; `git diff HEAD -- '*.gd'`.

- [ ] **Step 5: Run** `skin_select_popup`, `script_documentation`, `theme_factory` (DISPLAY_ROSTER) → pass.

- [ ] **Step 6: Commit** — `feat(skins): SkinSlot and SkinOptionTile templates`.

---

### Task 8: SkinSelectPopup

**Files:**
- Create: `Scripts/Skins/SkinSelectPopup.gd`, `Scenes/Skins/SkinSelectPopup.tscn`
- Test: `tests/test_skin_select_popup.gd` (append)

**Interfaces:**
- Consumes: `SkinSlot.show_student`, `SkinOptionTile.show_skin`, `GameState.equip_skin`, `GameState.is_skin_unlocked`, `StudentSkins.skins_for`.
- Produces: `class_name SkinSelectPopup extends Control`; `signal closed`; `@export var tile_scene: PackedScene`; `@export var fade_time: float`; `open(students: Array) -> void`; `open_column(index: int) -> void`; `close_column() -> void`; `close() -> void`; `var _open_slot: int`. Node paths: `Blur`, `Safe/UI/Card`, `Safe/UI/Card/Slots/Slot1..Slot4`, `Safe/UI/Card/Setuju`, `Safe/UI/OptionLayer`, `…/OptionLayer/BackBuffer`, `…/OptionLayer/Blur2`, `…/OptionLayer/Column/Scroll/List`.

- [ ] **Step 1: Append failing tests**

```gdscript
func _popup() -> SkinSelectPopup:
	var p := _inst(POPUP) as SkinSelectPopup
	Engine.get_main_loop().root.add_child(p)
	return p


func _roster() -> Array:
	return [_student("Thea"), _student("Doni"), _student("Marcel")]


func test_popup_contract() -> void:
	var p := _inst(POPUP) as Control
	assert_eq((p.get_node("Blur") as ColorRect).material.resource_path, "res://Scenes/Koperasi/shop_hub_blur_material.tres")
	assert_eq((p.get_node("Safe/UI/Card") as Panel).theme_type_variation, &"Card")
	var setuju := p.get_node("Safe/UI/Card/Setuju") as Button
	assert_eq(setuju.text, "SETUJU")
	assert_eq(setuju.theme_type_variation, &"PrimaryButton")
	assert_eq(p.get_node("Safe/UI/Card/Slots").get_child_count(), 4)
	var layer := p.get_node("Safe/UI/OptionLayer") as Control
	assert_false(layer.visible)
	var bb := layer.get_node("BackBuffer") as BackBufferCopy
	assert_eq(bb.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_lt_index(layer, "BackBuffer", "Blur2")
	assert_eq((layer.get_node("Blur2") as ColorRect).material.resource_path, "res://Scenes/Koperasi/shop_hub_blur_material.tres")
	assert_eq((layer.get_node("Column") as Panel).theme_type_variation, &"SkinOptionColumn")
	assert_true(layer.get_node("Column/Scroll") is ScrollContainer)


func assert_lt_index(parent: Node, a: String, b: String) -> void:
	assert_true(parent.get_node(a).get_index() < parent.get_node(b).get_index(), "%s draws before %s" % [a, b])


func test_open_hides_slots_past_the_roster() -> void:
	var p := _popup()
	p.open(_roster())
	for i in 4:
		var slot := p.get_node("Safe/UI/Card/Slots/Slot%d" % (i + 1)) as SkinSlot
		assert_eq(slot.visible, i < 3, "slot %d" % i)
	assert_eq((p.get_node("Safe/UI/Card/Slots/Slot2") as SkinSlot).student_name, "Doni")


func test_open_caps_at_four() -> void:
	var p := _popup()
	p.open(_roster() + [_student("Andi"), _student("Citra")])
	assert_eq((p.get_node("Safe/UI/Card/Slots/Slot4") as SkinSlot).student_name, "Andi")


func test_slot_press_opens_one_tile_per_skin() -> void:
	var p := _popup()
	p.open(_roster())
	(p.get_node("Safe/UI/Card/Slots/Slot1") as SkinSlot).pressed.emit()
	assert_true((p.get_node("Safe/UI/OptionLayer") as Control).visible)
	var list := p.get_node("Safe/UI/OptionLayer/Column/Scroll/List")
	assert_eq(list.get_child_count(), StudentSkins.skins_for("Thea").size())
	assert_eq((list.get_child(1) as SkinOptionTile).skin_id, "skin1")


func test_reopening_the_column_does_not_stack_tiles() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(0)
	p.open_column(1)
	var list := p.get_node("Safe/UI/OptionLayer/Column/Scroll/List")
	var live := 0
	for c in list.get_children():
		if not c.is_queued_for_deletion():
			live += 1
	assert_eq(live, 2)


func test_locked_tiles_are_dark() -> void:
	GameState.set_all_skins_locked(true)
	var p := _popup()
	p.open(_roster())
	p.open_column(1)
	var list := p.get_node("Safe/UI/OptionLayer/Column/Scroll/List")
	assert_false((list.get_child(0) as SkinOptionTile).disabled, "default is never locked")
	assert_true((list.get_child(1) as SkinOptionTile).disabled)


func test_picking_a_tile_equips_and_closes_the_column() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(2)
	var tile := p.get_node("Safe/UI/OptionLayer/Column/Scroll/List").get_child(1) as SkinOptionTile
	tile.pressed.emit()
	assert_eq(GameState.equipped_skin("Marcel"), "skin1")
	assert_false((p.get_node("Safe/UI/OptionLayer") as Control).visible)
	var art := p.get_node("Safe/UI/Card/Slots/Slot3/Frame/Mask/Art") as TextureRect
	assert_eq(art.texture.resource_path, "res://Assets/Images/Skins/Marcel/splash_marcel_skin1.png")


func test_blur2_tap_closes_the_column() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	(p.get_node("Safe/UI/OptionLayer/Blur2") as Control).gui_input.emit(ev)
	assert_false((p.get_node("Safe/UI/OptionLayer") as Control).visible)


func test_setuju_closes_once() -> void:
	var p := _popup()
	p.open(_roster())
	var count := [0]
	p.closed.connect(func() -> void: count[0] += 1)
	(p.get_node("Safe/UI/Card/Setuju") as Button).pressed.emit()
	assert_true(p._closing)
	p.close()
	assert_eq(count[0], 0, "closed fires after the fade, not twice")
```

- [ ] **Step 2: Run — fail.**

- [ ] **Step 3: Script** — `Scripts/Skins/SkinSelectPopup.gd`:

```gdscript
@tool
class_name SkinSelectPopup
extends Control

## The Lobby's skin picker (SkinSelectPopup.tscn; mockups
## skinselect_mockup.png and skinselectoption_mockup.png). A blurred screen,
## a card of up to four roster students in their current skin, and SETUJU.
## Tapping a student opens OptionLayer: a second blur over the card (a
## BackBufferCopy gives it a fresh screen copy, card included) and a
## scrollable column of that student's skins, lined up over the tapped card.
## Picking an unlocked skin equips it at once (GameState.equip_skin) and
## closes the column; a tap on the blur closes it unchanged. SETUJU or back
## closes the popup, emits `closed` and frees it.
##
## Opened by loby.gd with open(GameState.approved_students). @tool so the
## test runner can drive it; the fades are skipped in the editor.

signal closed

## One tile per skin in the option column, instanced per open: the count
## depends on the student tapped, so it is per-call dynamic content.
@export var tile_scene: PackedScene = preload("res://Scenes/Skins/SkinOptionTile.tscn")
## Seconds the popup takes to fade in or out.
@export var fade_time: float = 0.2

const MAX_SLOTS := 4

var _students: Array = []
var _open_slot: int = -1
var _closing: bool = false


func _ready() -> void:
	for i in MAX_SLOTS:
		var slot := _slot(i)
		if not slot.pressed.is_connected(open_column):
			slot.pressed.connect(open_column.bind(i))
	var setuju := get_node(^"Safe/UI/Card/Setuju") as Button
	if not setuju.pressed.is_connected(close):
		setuju.pressed.connect(close)
	var blur2 := get_node(^"Safe/UI/OptionLayer/Blur2") as Control
	if not blur2.gui_input.is_connected(_on_blur2_input):
		blur2.gui_input.connect(_on_blur2_input)


## Fills the card from `students` (roster dicts, first four) and fades in.
func open(students: Array) -> void:
	_students = students.slice(0, MAX_SLOTS)
	for i in MAX_SLOTS:
		var slot := _slot(i)
		slot.visible = i < _students.size()
		if slot.visible:
			slot.show_student(_students[i])
	close_column()
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	AudioDirector.play_sfx(&"tap")


## Shows slot `index`'s skins in the option column over that slot.
func open_column(index: int) -> void:
	if index < 0 or index >= _students.size():
		return
	_open_slot = index
	var student_name := str(_students[index].get("name", ""))
	var list := get_node(^"Safe/UI/OptionLayer/Column/Scroll/List")
	for old in list.get_children():
		list.remove_child(old)
		old.queue_free()
	for id in StudentSkins.skins_for(student_name):
		var tile := tile_scene.instantiate() as SkinOptionTile
		list.add_child(tile)
		tile.show_skin(student_name, id, not GameState.is_skin_unlocked(student_name, id))
		tile.pressed.connect(_on_tile_pressed.bind(id))
	var column := get_node(^"Safe/UI/OptionLayer/Column") as Control
	var slot := _slot(index)
	if slot.is_inside_tree() and column.is_inside_tree():
		column.global_position.x = slot.global_position.x + (slot.size.x - column.size.x) * 0.5
	(get_node(^"Safe/UI/OptionLayer") as Control).show()


func close_column() -> void:
	_open_slot = -1
	(get_node(^"Safe/UI/OptionLayer") as Control).hide()


## Fades out, emits `closed` and frees the popup. Idempotent.
func close() -> void:
	if _closing:
		return
	_closing = true
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_time)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _open_slot >= 0:
		close_column()
	else:
		close()


func _on_tile_pressed(id: String) -> void:
	if _open_slot < 0:
		return
	var student: Dictionary = _students[_open_slot]
	if GameState.equip_skin(str(student.get("name", "")), id):
		_slot(_open_slot).show_student(student)
		close_column()


func _on_blur2_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		close_column()


func _slot(i: int) -> SkinSlot:
	return get_node("Safe/UI/Card/Slots/Slot%d" % (i + 1)) as SkinSlot
```

Note `test_setuju_closes_once` runs in the editor, where `close()` returns before the tween: `_closing` is set, `closed` never fires — which is what it asserts.

- [ ] **Step 4: Scene** (editor) — `res://Scenes/Skins/SkinSelectPopup.tscn`, root `Control` `SkinSelectPopup` full rect (anchors 0,0,1,1), script, `mouse_filter = 0` (stop). Children in this order:
  1. `Blur` ColorRect, full rect, `material = res://Scenes/Koperasi/shop_hub_blur_material.tres`, `mouse_filter = 0` (swallows taps to the Lobby).
  2. `Safe` MarginContainer full rect, script `res://Scripts/UI/SafeAreaMargin.gd`, `mouse_filter = 2`; child `UI` Control, `layout_mode = 2`, `mouse_filter = 2`.
  3. `Safe/UI/Card` Panel `Card`, `layout_mode = 1`, anchors 0.5/0.5/0.5/0.5, offsets left −489, top −501, right 489, bottom 383 (mockup 51,459 → 1029,1343 about the 1080×1920 centre).
  4. `Safe/UI/Card/Slots` HBoxContainer, `layout_mode = 1`, anchors (0,0,1,0), offsets left 24, top 60, right −24, bottom 640, `alignment = 1`, `theme_override_constants/separation = 40` (layout-only, allowed); four `SkinSlot.tscn` instances named `Slot1`..`Slot4`.
  5. `Safe/UI/Card/Setuju` Button, `layout_mode = 1`, anchors 0.5/1/0.5/1, offsets left −224, top −205, right 224, bottom −57, `text = "SETUJU"`, `theme_type_variation = &"PrimaryButton"`.
  6. `Safe/UI/OptionLayer` Control, full rect, `visible = false`, `mouse_filter = 2`; children in order: `BackBuffer` BackBufferCopy (`copy_mode = 2`); `Blur2` ColorRect full rect, same material, `mouse_filter = 0`; `Column` Panel `SkinOptionColumn`, `layout_mode = 1`, anchors 0.5/0.5/0.5/0.5, offsets left −484, top −498, right −244, bottom 250 (mockup 56,462 → 296,1210); `Column/Scroll` ScrollContainer, anchors full, offsets 20/28/−20/−28, `horizontal_scroll_mode = 0`; `Column/Scroll/List` VBoxContainer, `size_flags_horizontal = 3`, `alignment = 1`, `theme_override_constants/separation = 24`.
  `scene_save`; `git diff HEAD -- '*.gd'`.

- [ ] **Step 5: Run** `skin_select_popup`, `tall_screen_layout`, `viewport_editability`, `script_documentation` → pass. If `tall_screen_layout` enumerates scenes and flags the popup, follow its message (it names the rule).

- [ ] **Step 6: Commit** — `feat(skins): SkinSelectPopup with blurred option column`.

---

### Task 9: Lobby skin_switch button

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (new `Safe/UI/BottomBar/SkinSwitchButton`)
- Modify: `Scripts/Lobby/loby.gd` (onready, export, juice list, connect, handler)
- Test: `tests/test_lobby_skins.gd` (append)

**Interfaces:**
- Consumes: `SkinSelectPopup.open(students: Array)`, `closed`.
- Produces: `loby.gd` `@export var skin_select_scene: PackedScene`, `_on_skin_switch_pressed() -> void`.

- [ ] **Step 1: Append failing tests**

```gdscript
func test_lobby_has_the_skin_switch_button() -> void:
	var scene := (load("res://Scenes/Lobby/loby.tscn") as PackedScene).instantiate()
	track(scene)
	var btn := scene.get_node("Safe/UI/BottomBar/SkinSwitchButton") as TextureButton
	assert_true(btn != null)
	assert_true(btn.unique_name_in_owner)
	assert_eq(btn.texture_normal.resource_path, "res://Assets/Images/UI/skin_switch.png")
	assert_eq(Vector2(btn.offset_left, btn.offset_right), Vector2(360, 456), "beside AchievementButton")
	assert_eq(btn.offset_bottom, 96.0)


func test_lobby_opens_the_popup_and_reseats_on_close() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("skin_select_scene.instantiate()"))
	assert_true(src.contains(".open(GameState.approved_students)"))
	assert_true(src.contains(".closed.connect(_setup_students)"))
	assert_true(src.contains("skin_switch_button.pressed.connect(_on_skin_switch_pressed)"))
```

- [ ] **Step 2: Run — fail.**

- [ ] **Step 3: Scene first** (editor, `loby.tscn`): create `TextureButton` `SkinSwitchButton` under `Safe/UI/BottomBar`, `unique_name_in_owner = true`, `layout_mode = 0`, `custom_minimum_size = Vector2(96, 96)`, offsets left 360, top 0, right 456, bottom 96, `texture_normal = res://Assets/Images/UI/skin_switch.png`, `ignore_texture_size = true`, `stretch_mode = 5`. `move_node` it right after `AchievementButton`. `scene_save`; `git diff HEAD -- '*.gd'`. Then restart the worktree editor if any script was patched earlier in this session and not yet reloaded (CLAUDE.md 4b).

- [ ] **Step 4: Script** — in `loby.gd`:
  - after `@onready var achievement_button = %AchievementButton`: `@onready var skin_switch_button = %SkinSwitchButton`
  - in the `Layered Faces` export group's neighbourhood, a new group:

```gdscript
@export_group("Skins")
## The skin picker opened by SkinSwitchButton.
@export var skin_select_scene: PackedScene = preload("res://Scenes/Skins/SkinSelectPopup.tscn")
```

  - add `skin_switch_button` to the `_setup_button_juice` list in `_ready()`;
  - after the achievement connect:

```gdscript
	if not skin_switch_button.pressed.is_connected(_on_skin_switch_pressed):
		skin_switch_button.pressed.connect(_on_skin_switch_pressed)
	skin_switch_button.disabled = GameState.approved_students.is_empty()
```

  - handler near `_on_achievement_pressed`:

```gdscript
## Opens the skin picker over the Lobby. Skins apply the moment one is
## picked; closing re-seats the diorama so its faces and desks wear them.
func _on_skin_switch_pressed() -> void:
	if GameState.approved_students.is_empty():
		return
	var popup := skin_select_scene.instantiate() as SkinSelectPopup
	add_child(popup)
	popup.closed.connect(_setup_students)
	popup.open(GameState.approved_students)
```

- [ ] **Step 5: Run** `lobby_skins`, `lobby`, `lobby_layout`, `tall_screen_layout`, `viewport_editability` → pass. Update `docs/superpowers/design` only if `lobby_layout` pins the BottomBar's children list (it will say).

- [ ] **Step 6: Commit** — `feat(lobby): skin_switch button opens the skin picker`.

---

### Task 10: Debug lock toggle

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd` (general panel, after the Forget Session button; new handler)
- Test: `tests/test_student_skins.gd` (append)

- [ ] **Step 1: Failing scan**

```gdscript
func test_debug_overlay_toggles_skin_locks() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
	assert_true(src.contains("Kunci/Buka Semua Skin"))
	assert_true(src.contains("GameState.set_all_skins_locked(not GameState.all_skins_locked())"))
```

- [ ] **Step 2: Run — fail.**

- [ ] **Step 3: Implement** — after `btn_forget`'s block (same pattern):

```gdscript
	var btn_skins = Button.new()
	btn_skins.text = " 🎨 Kunci/Buka Semua Skin "
	btn_skins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_skins.custom_minimum_size = Vector2(0, 95)
	btn_skins.add_theme_font_size_override("font_size", 23)
	btn_skins.pressed.connect(_toggle_skin_locks)
	vbox.add_child(btn_skins)
```

and the handler:

```gdscript
## Locks every non-default skin, or unlocks them again, so the skin popup's
## darkened locked tiles can be seen while every shipped skin starts unlocked.
func _toggle_skin_locks() -> void:
	GameState.set_all_skins_locked(not GameState.all_skins_locked())
	log_message("Skin: %s" % ("semua terkunci" if GameState.all_skins_locked() else "semua terbuka"))
```

Match the surrounding code's `vbox` variable and `add_child` order (read lines 383-410 first).

- [ ] **Step 4: Run** `student_skins`, `viewport_editability` (DebugManager is out of the design system; if the ratchet counts it, raise nothing — report) → pass.

- [ ] **Step 5: Commit** — `feat(debug): lock or unlock every skin`.

---

### Task 11: Visual check against the mockups

- [ ] **Step 1:** Run the worktree project (`project_run`, session id), open the debug overlay → **⚡ Seed Playtest State** → Scenes → Lobby. Tap `SkinSwitchButton` (`game_manage` input at its centre; read its rect with `get_ui_elements` scoped to `/root/TutorialOverlay/Safe/UI/BottomBar`, `max_depth = 1`). Freeze time (`Engine.time_scale = 0` inside one `game_eval`, per memory) and `editor_screenshot` at full size.
- [ ] **Step 2:** Compare with `skinselect_mockup.png`: blurred Lobby, white card, four tall rounded brown-outlined frames with head-to-waist splashes, names in display face, SETUJU. Fix frame knobs (`visible_source_height`, `face_y_ratio` on `SkinSlot.tscn`'s Frame) or label variation if off; re-run `skin_select_popup`.
- [ ] **Step 3:** Tap slot 1; screenshot; compare with `skinselectoption_mockup.png` (column over slot 1, square bust-ups, card blurred). Tap Skin1; confirm the slot redraws. Debug → 🎨 lock all → reopen column: skin1 tile dark.
- [ ] **Step 4:** SETUJU → Lobby seat shows the new face base and desk art. Then Scenes → Atur Jadwal / Student list: the skin portrait shows.
- [ ] **Step 5:** Tall phone: `resize_window`-equivalent via `project_run` with a 1080×2400 window override if the project supports it, else rely on `tall_screen_layout`. Stop the game; revert `default_bus_layout.tres`.
- [ ] **Step 6:** Commit any knob fixes — `fix(skins): tune frame crops against the mockups`. Send the final screenshots to the user with `SendUserFile`.

---

### Task 12: Docs and the full suite

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (newest first), `docs/superpowers/DEBT.md`, `CLAUDE.md`

- [ ] **Step 1:** CHANGELOG entry: skin system — catalog, popup, lobby button, consumers, debug toggle, baked portraits.
- [ ] **Step 2:** DEBT entries (grouped under a "Skins" heading): equipped skins are session-scoped (not saved); no way to earn/buy a skin yet (all start unlocked; Cosmetic Shop stub); `<Name>Skin1(itemonly).png` delivered but unused (kept only in the Drive zip); flat skin portraits are baked by `Scripts/Skins/BakeSkinPortraits.gd` — re-run it when a skin's base changes.
- [ ] **Step 3:** CLAUDE.md, in "The two student representations" section, one line: `Student art is read through StudentSkins (splash_for / portrait_for / face_base_for / hand_for), never the dict's "splash"/"portrait" keys directly, so the equipped skin shows; only the end-result screens use base art.` Keep under the 23,000-character budget (`wc -c CLAUDE.md`).
- [ ] **Step 4:** Update the suite count in CLAUDE.md's Testing line after the full run.
- [ ] **Step 5: Full suite** — `test_run(session_id=…)` with no suite. Expect all pass. Then `git status`: revert `Assets/Audio/default_bus_layout.tres`, and `Assets/Theme/kejartes_theme.tres` unless it changed only by this branch's three variations. Fix genuine failures; re-run. Note `<passed>/<total>`.
- [ ] **Step 6: Commit** — `docs(skins): changelog, debt and guide line for skins`.
