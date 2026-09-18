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
