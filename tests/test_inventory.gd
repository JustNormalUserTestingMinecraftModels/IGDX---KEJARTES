@tool
extends McpTestSuite

## Inventory screen. Suite is @tool and no test is a coroutine, per the
## runner constraints documented in test_lobby.gd.

func suite_name() -> String:
	return "inventory"

const _SCENE_PATH := "res://Scenes/Inventory/inventory.tscn"
const _SCRIPT_PATH := "res://Scripts/Inventory/inventory.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "inventory.tscn must exist")
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "inventory.tscn must instantiate")
	scene.free()

func test_back_button_returns_to_lobby_not_shop() -> void:
	var src := _source()
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"back must return to the lobby")
	assert_false(src.contains("koprasi.tscn"),
		"the inventory must not link back into the shop")

func test_uses_audio_director_not_sfx_manager() -> void:
	var src := _source()
	assert_false(src.contains("SfxManager"), "SfxManager was not imported")
	assert_true(src.contains("AudioDirector.play_sfx"), "must use AudioDirector")

func test_does_not_reference_source_project_paths() -> void:
	var src := _source()
	assert_false(src.contains("res://Scene/"), "no source-project scene paths")
	assert_false(src.contains("res://Asset/"), "no source-project asset paths")

func test_scene_has_no_source_project_resource_paths() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(raw.contains("res://Asset/"), "scene must not reference res://Asset/")
	assert_false(raw.contains("res://Script/"), "scene must not reference res://Script/")

func test_item_icons_are_preserved_art() -> void:
	## The item icons are finished art, not placeholders. This pins that
	## they still resolve after the port.
	for item_name in ["Komik", "Raket", "Mie Instan"]:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.icon != null, "icon preserved for: " + item_name)
