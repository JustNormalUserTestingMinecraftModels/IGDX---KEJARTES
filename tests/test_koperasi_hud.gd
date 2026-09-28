@tool
extends McpTestSuite

## Koperasi's coin counter and purchase-feedback message were built in
## _ready() every time the shop scene loaded -- permanent chrome, not
## per-item content, so it belongs in the scene (Pattern A).
##
## The dynamic per-call message colour is a ThemeFactory variation swapped
## via theme_type_variation, instead of add_theme_color_override with a
## token colour picked at runtime. Since the 2026-09-17 chat-bubble pass,
## Koperasi.gd only ever shows the success variation on MessageLabel --
## EMPTY/POOR now speak through Pak Herman's ChatBubble instead.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "koperasi_hud"


const SCENE_PATH := "res://Scenes/Koperasi/Koperasi.tscn"
const SCRIPT_PATH := "res://Scripts/Koperasi/Koperasi.gd"
const BASKET_TRAY_SCENE_PATH := "res://Scenes/Koperasi/BasketTray.tscn"


func test_coin_hud_and_message_live_in_the_scene() -> void:
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for node_name in ["MessageLabel"]:
		assert_contains(text, node_name, "Koperasi.tscn is missing %s" % node_name)


## The 2026-09-28 koperasi-top-band-promo Task 6 pass: the ledge coin HUD
## moved into the tray footer's Kas Kelas pill, driven from Koperasi.gd
## through the tray rather than a local coin_label.
func test_koperasi_shows_the_kas_through_the_tray() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "tray.show_kas(", "Koperasi.gd should drive the tray's Kas pill")
	assert_false(src.contains("%CoinHUD"), "the coin HUD moved into the tray footer")


func test_basket_tray_scene_carries_the_kas_and_total_pills() -> void:
	var text := FileAccess.get_file_as_string(BASKET_TRAY_SCENE_PATH)
	for node_name in ["KasPill", "TotalPill", "KasLabel", "TotalNumber"]:
		assert_contains(text, node_name, "BasketTray.tscn is missing %s" % node_name)
	assert_contains(text, "&\"KasCaptionLabel\"", "BasketTray.tscn is missing KasCaptionLabel")


func test_koperasi_builds_no_chrome_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("HBoxContainer.new("), "coin HUD should be a scene node")
	assert_false(src.contains("func _setup_coin_display"), "coin display setup should be gone")
	assert_false(src.contains("func _setup_message_label"), "message label setup should be gone")
	assert_false(src.contains('load("res://Assets/Images/Shop/Koin.png")'),
		"the coin art should be assigned in the scene")


## The 2026-09-17 chat-bubble pass (Task 2) moved the EMPTY/POOR failure
## paths off MessageLabel and into Pak Herman's bubble (DialogueCatalog's
## &"EMPTY"/&"POOR" events) -- see the polish spec, "Contextual dialogue
## bubble" section. MessageLabel is now success-only, so it needs just the
## one ThemeFactory variation; ShopMessageWarning/ShopMessageDanger stay
## registered in ThemeFactory for any other caller, they are just no longer
## Koperasi.gd's job to reach for.
func test_show_message_swaps_theme_variation_and_errors_route_through_the_bubble() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains('add_theme_color_override("font_color"'),
		"the message label must swap theme_type_variation, not override a colour")
	assert_contains(src, "ShopMessageSuccess", "missing message variation: ShopMessageSuccess")
	assert_contains(src, 'say(&"EMPTY")', "empty-cart Beli should route through the bubble")
	assert_contains(src, 'say(&"POOR")', "insufficient-funds Beli should route through the bubble")


## The body of a source-text function, from its signature up to (not
## including) the next top-level "func " -- or to end of file for the last
## function. Lets a scan pin what one function does without matching the
## same text elsewhere in the file.
func _body(src: String, signature: String) -> String:
	var at: int = src.find(signature)
	if at < 0:
		return ""
	var next: int = src.find("\nfunc ", at + 1)
	return src.substr(at, (src.length() if next < 0 else next) - at)


## The 2026-09-28 koperasi-top-band-promo Task 7 pass: Beli withdraws
## visibly from the Kas Kelas pill, and the withdrawal must play after the
## money has actually left (GameState.player_money -= total), not before.
func test_beli_withdraws_from_the_kas() -> void:
	var body: String = _body(FileAccess.get_file_as_string(SCRIPT_PATH), "func _on_beli_pressed()")
	var deduct_at: int = body.find("GameState.player_money -= total")
	var play_at: int = body.find("tray.play_withdrawal(total)")
	assert_true(deduct_at != -1 and play_at > deduct_at,
		"the withdrawal plays after the money actually leaves")


## play_withdrawal()'s "-total" float takes its colour from the theme
## (TotalNumberOver's font_color), never a literal Color.
func test_the_withdrawal_takes_its_red_from_the_theme() -> void:
	var body: String = _body(FileAccess.get_file_as_string("res://Scripts/Koperasi/BasketTray.gd"),
		"func play_withdrawal(")
	assert_true(body.contains("create_floating_text"), "a -total floats out of the Kas")
	assert_true(body.contains("get_theme_color("), "its colour is the theme's, not a literal")
