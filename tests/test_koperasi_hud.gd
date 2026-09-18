@tool
extends McpTestSuite

## Koperasi's coin counter and purchase-feedback message were built in
## _ready() every time the shop scene loaded -- permanent chrome, not
## per-item content, so it belongs in the scene (Pattern A).
##
## The dynamic per-call message colour is a ThemeFactory variation swapped
## via theme_type_variation, instead of add_theme_color_override with a
## token colour picked at runtime. Since the 2026-09-17 chat-bubble pass,
## koprasi.gd only ever shows the success variation on MessageLabel --
## EMPTY/POOR now speak through Pak Herman's ChatBubble instead.
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


## The 2026-09-17 chat-bubble pass (Task 2) moved the EMPTY/POOR failure
## paths off MessageLabel and into Pak Herman's bubble (DialogueCatalog's
## &"EMPTY"/&"POOR" events) -- see the polish spec, "Contextual dialogue
## bubble" section. MessageLabel is now success-only, so it needs just the
## one ThemeFactory variation; ShopMessageWarning/ShopMessageDanger stay
## registered in ThemeFactory for any other caller, they are just no longer
## koprasi.gd's job to reach for.
func test_show_message_swaps_theme_variation_and_errors_route_through_the_bubble() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains('add_theme_color_override("font_color"'),
		"the message label must swap theme_type_variation, not override a colour")
	assert_contains(src, "ShopMessageSuccess", "missing message variation: ShopMessageSuccess")
	assert_contains(src, 'say(&"EMPTY")', "empty-cart Beli should route through the bubble")
	assert_contains(src, 'say(&"POOR")', "insufficient-funds Beli should route through the bubble")
