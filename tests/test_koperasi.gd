@tool
extends McpTestSuite

## Koperasi (shop). Ported from the teammate's project; this suite pins the
## integration contract rather than the art. Suite is @tool and no test is a
## coroutine, per the runner constraints documented in test_lobby.gd.

func suite_name() -> String:
	return "koperasi"

const _SCENE_PATH := "res://Scenes/Koperasi/koprasi.tscn"
const _SCRIPT_PATH := "res://Scripts/Koperasi/koprasi.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "koprasi.tscn must exist")
	var packed := load(_SCENE_PATH) as PackedScene
	assert_true(packed != null, "koprasi.tscn must load as a PackedScene")

func test_scene_instantiates() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "koprasi.tscn must instantiate")
	scene.free()

func test_no_in_shop_inventory_button() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("Inventory", true, false) == null,
		"the shop must not link to the inventory -- both are lobby siblings")
	scene.free()

func test_back_button_returns_to_lobby() -> void:
	assert_true(_source().contains("res://Scenes/Lobby/loby.tscn"),
		"the shop's back button must return to the lobby")

func test_does_not_reference_source_project_paths() -> void:
	var src := _source()
	assert_false(src.contains("res://Scene/"), "no source-project scene paths")
	assert_false(src.contains("res://Asset/"), "no source-project asset paths")

func test_uses_audio_director_not_sfx_manager() -> void:
	var src := _source()
	assert_false(src.contains("SfxManager"), "SfxManager was not imported")
	assert_true(src.contains("AudioDirector.play_sfx"), "must use AudioDirector")

func test_scene_has_no_source_project_resource_paths() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(raw.contains("res://Asset/"), "scene must not reference res://Asset/")
	assert_false(raw.contains("res://Script/"), "scene must not reference res://Script/")
