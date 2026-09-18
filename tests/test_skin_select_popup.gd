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
	var layer := p.get_node("OptionLayer") as Control
	assert_false(layer.visible)
	var bb := layer.get_node("BackBuffer") as BackBufferCopy
	assert_eq(bb.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_lt_index(layer, "BackBuffer", "Blur2")
	assert_eq((layer.get_node("Blur2") as ColorRect).material.resource_path, "res://Scenes/Skins/skin_option_blur_material.tres")
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
	assert_true((p.get_node("OptionLayer") as Control).visible)
	var list := p.get_node("OptionLayer/Column/Scroll/List")
	assert_eq(list.get_child_count(), StudentSkins.skins_for("Thea").size())
	assert_eq((list.get_child(1) as SkinOptionTile).skin_id, "skin1")


func test_reopening_the_column_does_not_stack_tiles() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(0)
	p.open_column(1)
	var list := p.get_node("OptionLayer/Column/Scroll/List")
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
	var list := p.get_node("OptionLayer/Column/Scroll/List")
	assert_false((list.get_child(0) as SkinOptionTile).disabled, "default is never locked")
	assert_true((list.get_child(1) as SkinOptionTile).disabled)


func test_picking_a_tile_equips_and_closes_the_column() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(2)
	var tile := p.get_node("OptionLayer/Column/Scroll/List").get_child(1) as SkinOptionTile
	tile.pressed.emit()
	assert_eq(GameState.equipped_skin("Marcel"), "skin1")
	assert_false((p.get_node("OptionLayer") as Control).visible)
	var art := p.get_node("Safe/UI/Card/Slots/Slot3/Frame/Mask/Art") as TextureRect
	assert_eq(art.texture.resource_path, "res://Assets/Images/Skins/Marcel/splash_marcel_skin1.png")


func test_blur2_tap_closes_the_column() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	(p.get_node("OptionLayer/Blur2") as Control).gui_input.emit(ev)
	assert_false((p.get_node("OptionLayer") as Control).visible)


func test_android_back_closes_column_then_popup() -> void:
	var p := _popup()
	p.open(_roster())
	p.open_column(0)
	p.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false((p.get_node("OptionLayer") as Control).visible, "first back closes the column")
	assert_false(p._closing)
	p.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(p._closing, "second back closes the popup")


func test_setuju_closes_once() -> void:
	var p := _popup()
	p.open(_roster())
	var count := [0]
	p.closed.connect(func() -> void: count[0] += 1)
	(p.get_node("Safe/UI/Card/Setuju") as Button).pressed.emit()
	assert_true(p._closing)
	p.close()
	assert_eq(count[0], 0, "closed fires after the fade, not twice")
