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
	var loby_script: GDScript = load("res://Scripts/Lobby/loby.gd")
	var slot := Control.new()
	track(slot)
	var hand := TextureRect.new()
	hand.name = "Hand_Andi"
	var base_tex := load("res://Assets/Images/MuridPotrait/TanganItems/Andi_Table.png") as Texture2D
	hand.texture = base_tex
	slot.add_child(hand)
	GameState.equip_skin("Andi", "skin1")
	loby_script._apply_hand_skins(slot)
	assert_eq(hand.texture.resource_path, "res://Assets/Images/Skins/Andi/andi_table_skin1.png")
	GameState.equip_skin("Andi", "default")
	loby_script._apply_hand_skins(slot)
	assert_eq(hand.texture, base_tex, "default restores the authored texture")


func test_setup_students_wires_both() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("_apply_hand_skins(h_slot)"))
	assert_true(src.contains("StudentSkins.face_base_for("))
	assert_true(src.contains("face.set_base_texture("))


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
