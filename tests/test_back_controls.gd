@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

## The one canonical back/return glyph. Twelve controls across nine scenes
## draw it; before 2026-09-22 they drew four different pictures between them
## (a 160x145 white arrow, the same arrow at 512x512 with a different alpha
## bbox, a 16x36 chevron, and a pure-#FF0000 stock clipart arrow) plus one
## emoji. This suite is what stops a fifth arriving.
##
## Cross-screen on purpose: it pins the invariant, not any one screen's
## geometry. Each screen's own rect and anchors stay pinned by its own suite.
##
## Must be @tool, and no test here may be a coroutine -- the runner calls each
## test without awaiting, so an `await` silently aborts it and it reports zero
## assertions. Every instantiated scene is freed in the same test.

func suite_name() -> String:
	return "back_controls"


const CANON := "res://Assets/Images/UI/Nav/return_button.png"

## Retired 2026-09-22. No scene may reference any of these again.
const SUPERSEDED: Array[String] = [
	"res://Assets/Images/Achievements/back_arrow.png",
	"res://Assets/Images/Shop/return.png",
	"res://Assets/Images/UI/Placeholders/icon_back.svg",
	"res://Assets/Images/UI/pngwing.com (1).png",
]

## scene -> { node path : property }. `texture_normal` for the five
## TextureButtons, `icon` for the six Buttons -- five of which keep their
## "Kembali" label beside the arrow, while Rapor's 260px box takes the arrow
## alone (its label would not fit beside any icon at all).
const ROSTER := {
	"res://Scenes/Achievements/achievements.tscn": {
		"Safe/UI/BackButton": "texture_normal",
	},
	"res://Scenes/Achievements/AchievementDetailSheet.tscn": {
		"Sheet/Margin/VBox/BackButton": "texture_normal",
	},
	"res://Scenes/AturJadwal/atur_jadwal.tscn": {
		"BackButton": "texture_normal",
		"Penjadwalan/TextureRect/PopupBack": "texture_normal",
	},
	"res://Scenes/Koperasi/koprasi.tscn": {
		"Stage/BackButton": "texture_normal",
	},
	"res://Scenes/Inventory/inventory.tscn": {
		"MainColumn/Header/HeaderCol/Row/BackButton": "icon",
	},
	"res://Scenes/Koperasi/ShopHub.tscn": {
		"BackButton": "icon",
	},
	"res://Scenes/Koperasi/CosmeticShop.tscn": {
		"BackButton": "icon",
	},
	"res://Scenes/ReportCard/report_card.tscn": {
		"Safe/UI/BackButton": "icon",
	},
	"res://Scenes/UI/Settings.tscn": {
		"SafeArea/Layout/BackButton": "icon",
	},
	"res://Scenes/EndGame/RunResult.tscn": {
		"MarginContainer/Column/BtnSelesai": "icon",
	},
	"res://Scenes/SchoolSimulation/SchoolDay.tscn": {
		"DayScreen/BackButton": "icon",
	},
}


## Every back control, whatever its node type, draws the same picture.
func test_every_back_control_draws_the_canonical_texture() -> void:
	for scene_path in ROSTER:
		var packed: PackedScene = load(scene_path)
		assert_true(packed != null, "%s must load" % scene_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		for node_path in ROSTER[scene_path]:
			var prop: String = ROSTER[scene_path][node_path]
			var node: Node = root.get_node_or_null(node_path)
			assert_true(node != null, "%s : %s must exist" % [scene_path, node_path])
			if node == null:
				continue
			var tex: Texture2D = node.get(prop)
			assert_true(tex != null,
				"%s : %s must carry a %s" % [scene_path, node_path, prop])
			if tex != null:
				assert_eq(String(tex.resource_path), CANON,
					"%s : %s draws %s -- every back control must draw the one canonical arrow"
						% [scene_path, node_path, tex.resource_path])
		root.free()


## A leftover `ext_resource` that no node uses is invisible to the test above,
## and it keeps a deleted asset's uid alive in the scene file.
func test_no_scene_still_references_a_superseded_back_asset() -> void:
	for scene_path in ROSTER:
		var src := FileAccess.get_file_as_string(scene_path)
		assert_true(src != "", "%s must be readable" % scene_path)
		for dead in SUPERSEDED:
			assert_false(src.contains(dead),
				"%s still references the retired %s" % [scene_path, dead])


## A 512x512 texture_normal sets a TextureButton's minimum size to 512 unless
## ignore_texture_size is on -- which would silently blow each of these
## layouts apart. All five already carry it; this stops an edit dropping it.
func test_the_texture_buttons_ignore_their_texture_size() -> void:
	var checked := 0
	for scene_path in ROSTER:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		for node_path in ROSTER[scene_path]:
			if ROSTER[scene_path][node_path] != "texture_normal":
				continue
			var btn := root.get_node_or_null(node_path) as TextureButton
			assert_true(btn != null,
				"%s : %s must be a TextureButton" % [scene_path, node_path])
			if btn != null:
				checked += 1
				assert_true(btn.ignore_texture_size,
					"%s : %s must ignore its 512px texture size or its minimum size explodes"
						% [scene_path, node_path])
		root.free()
	assert_eq(checked, 5, "all five TextureButton back controls must be checked")


## The cap keeps each size step at its authored height. The S step solves
## 2 * btn_pad_v_s (30) + font_title (36) = 96, which is also
## touch_target_min -- so a cap above 36 would make the icon the tallest
## content and grow the button past 96. The M step solves
## 2 * btn_pad_v_m (40) + font_h2 (48) = 128 and carries 48.
##
## _add_size_step sets base_type to Button rather than to the parent
## variation, so PrimaryButtonM needs its own entry and does not inherit
## PrimaryButton's.
func test_the_icon_cap_keeps_each_step_at_its_authored_height() -> void:
	var theme: Theme = ResourceLoader.load(
		"res://Assets/Theme/kejartes_theme.tres", "Theme",
		ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(theme != null, "the baked theme must load")
	if theme == null:
		return
	for variation in ["PrimaryButton", "SecondaryButton"]:
		assert_eq(theme.get_constant("icon_max_width", variation), 36,
			"%s's arrow must cap at the display font's line (36) so the button stays 96px"
				% variation)
		assert_eq(theme.get_constant("h_separation", variation), 16,
			"%s needs space_sm between arrow and word; Godot's built-in 4px is too tight"
				% variation)
	assert_eq(theme.get_constant("icon_max_width", "PrimaryButtonM"), 48,
		"the M step is 128px tall and carries a 48px arrow")
	assert_eq(theme.get_constant("h_separation", "PrimaryButtonM"), 16,
		"the M step needs the same space_sm gap")


## The arrow leads the word. Godot's default for `icon_alignment` is already
## LEFT, which means writing it into the .tscn is a no-op -- the editor omits
## default values on save, so the property cannot be pinned in the scene file
## at all. It is pinned here instead, which is strictly better: this catches a
## future `alignment` edit whatever the serializer does.
func test_the_arrow_leads_the_word_on_every_text_button() -> void:
	for scene_path in ROSTER:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		for node_path in ROSTER[scene_path]:
			if ROSTER[scene_path][node_path] != "icon":
				continue
			var btn := root.get_node_or_null(node_path) as Button
			if btn == null:
				continue
			assert_eq(btn.icon_alignment, HORIZONTAL_ALIGNMENT_LEFT,
				"%s : %s must lead with the arrow; centred, the label draws over it"
					% [scene_path, node_path])
		root.free()


## CLAUDE.md bans emoji as UI iconography. SchoolDay's back button carried a
## "back" emoji until 2026-09-22; this pins the ban where it was most recently
## broken. Covers the dingbat/arrow blocks as well as the emoji planes,
## because the chevron this replaced was a typographic character too.
func test_no_back_control_labels_itself_with_an_emoji() -> void:
	for scene_path in ROSTER:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		for node_path in ROSTER[scene_path]:
			if ROSTER[scene_path][node_path] != "icon":
				continue
			var btn := root.get_node_or_null(node_path) as Button
			if btn == null:
				continue
			for c in btn.text:
				var cp := c.unicode_at(0)
				var banned := (cp >= 0x2190 and cp <= 0x2BFF) \
					or (cp >= 0xFE00 and cp <= 0xFE0F) \
					or (cp >= 0x1F000 and cp <= 0x1FAFF)
				assert_false(banned,
					"%s : %s labels itself with codepoint 0x%X -- the arrow is a texture, never a character"
						% [scene_path, node_path, cp])
		root.free()
