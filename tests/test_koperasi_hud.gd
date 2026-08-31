@tool
extends McpTestSuite

## Koperasi's coin counter and purchase-feedback message were built in
## _ready() every time the shop scene loaded -- permanent chrome, not
## per-item content, so it belongs in the scene (Pattern A).
##
## The dynamic per-call message colour (state_warning/danger/success) is now
## three ThemeFactory variations the screen swaps between via
## theme_type_variation, instead of add_theme_color_override with a token
## colour picked at runtime.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "koperasi_hud"


const SCENE_PATH := "res://Scenes/Koperasi/koprasi.tscn"
const SCRIPT_PATH := "res://Scripts/Koperasi/koprasi.gd"


func test_coin_hud_and_message_live_in_the_scene() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for node_name in ["CoinHUD", "CoinIcon", "CoinLabel", "MessageLabel"]:
		assert_contains(text, node_name, "koprasi.tscn is missing %s" % node_name)


func test_koperasi_builds_no_chrome_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("HBoxContainer.new("), "coin HUD should be a scene node")
	assert_false(src.contains("func _setup_coin_display"), "coin display setup should be gone")
	assert_false(src.contains("func _setup_message_label"), "message label setup should be gone")
	assert_false(src.contains('load("res://Assets/Images/Shop/Koin.png")'),
		"the coin art should be assigned in the scene")


func test_coin_label_uses_the_shop_coin_variation() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	assert_contains(text, 'theme_type_variation = &"ShopCoinLabel"')


func test_show_message_swaps_theme_variation_not_a_colour_override() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains('add_theme_color_override("font_color"'),
		"the message label must swap theme_type_variation, not override a colour")
	for variation in ["ShopMessageWarning", "ShopMessageDanger", "ShopMessageSuccess"]:
		assert_contains(src, variation, "missing message variation: %s" % variation)
