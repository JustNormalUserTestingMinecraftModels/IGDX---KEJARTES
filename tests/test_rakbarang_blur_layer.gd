@tool
extends McpTestSuite

## rakbarang_1.gd's blur/dim overlay and the popup layer it reparents the
## shelf's existing ReturPanel into (koprasi.tscn:Rak1/Keranjang/
## KeranjangDepan/ReturPanel) are permanent screen chrome, built once and
## toggled visible -- not per-item content. Both are now nodes in
## koprasi.tscn under Rak1 instead of being constructed in _ready().
##
## Two other .new() sites in this script are deliberately untouched:
## _spawn_falling_item()'s "duplikat" TextureRect is a one-shot animation
## clone freed the moment it lands, and _add_item_visual()'s basket icon is
## placed at a randomized runtime position. Neither is "UI a human would
## want to select in the editor" -- they are inherently per-event VFX, not
## authored layout, so converting them to scenes would not make anything
## more editable.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "rakbarang_blur_layer"


const SCENE_PATH := "res://Scenes/Koperasi/koprasi.tscn"
const SCRIPT_PATH := "res://Scripts/Koperasi/rakbarang_1.gd"


func test_blur_and_popup_layers_live_in_the_scene() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for node_name in ["BlurLayer", "BlurRect", "InputBlocker", "PopupLayer", "PopupContainer"]:
		assert_contains(text, node_name, "koprasi.tscn is missing %s under Rak1" % node_name)


func test_the_blur_material_is_scene_data() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	assert_contains(text, "blur.gdshader",
		"the blur ShaderMaterial should be assigned in the scene, not built in _ready()")


func test_rakbarang_no_longer_builds_the_blur_or_popup_layers() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("ShaderMaterial.new("),
		"the blur material belongs in the scene")
	assert_false(src.contains("blur_layer = CanvasLayer.new("),
		"blur_layer should be an @onready binding, not built in _ready()")
	assert_false(src.contains("popup_layer = CanvasLayer.new("),
		"popup_layer should be an @onready binding, not built in _ready()")
	assert_false(src.contains("func _setup_blur_layer"),
		"_setup_blur_layer should be gone now that there is nothing left to build")


func test_falling_item_and_basket_icon_construction_is_unchanged() -> void:
	# These are deliberately out of scope -- see the suite header. Pinned so
	# a future pass touching this file notices if it accidentally removes
	# them rather than leaving them as the documented exception.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "var duplikat = TextureRect.new()")
	assert_contains(src, "var icon_node = TextureRect.new()")
