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
