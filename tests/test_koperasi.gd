@tool
extends McpTestSuite

## Koperasi (shop). Ported from the teammate's project; this suite pins the
## integration contract rather than the art. Suite is @tool and no test is a
## coroutine, per the runner constraints documented in test_lobby.gd.

func suite_name() -> String:
	return "koperasi"

const _SCENE_PATH := "res://Scenes/Koperasi/Koperasi.tscn"
const _SCRIPT_PATH := "res://Scripts/Koperasi/Koperasi.gd"
const PriceTagScene := preload("res://Scenes/Koperasi/PriceTag.tscn")

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "Koperasi.tscn must exist")
	var packed := load(_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Koperasi.tscn must load as a PackedScene")

func test_scene_instantiates() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "Koperasi.tscn must instantiate")
	scene.free()

func test_no_in_shop_inventory_button() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("Inventory", true, false) == null,
		"the shop must not link to the inventory -- both are lobby siblings")
	scene.free()

func test_back_button_returns_to_the_shop_hub() -> void:
	# Changed 2026-09-07: the Lobby's shop button now lands on the hub,
	# so backing out of the item shop returns there rather than skipping
	# straight past it to the Lobby.
	assert_true(_source().contains("res://Scenes/Koperasi/ShopHub.tscn"),
		"the shop's back button must return to the shop hub")
	assert_false(_source().contains("res://Scenes/Lobby/Lobby.tscn"),
		"the shop should no longer jump straight back to the Lobby")

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

func test_no_placeholder_chrome_textures() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	for placeholder in ["btn_normal", "btn_pressed", "slot_normal", "slot_selected"]:
		assert_false(raw.contains(placeholder),
			"placeholder chrome must be replaced by the theme: " + placeholder)

func test_preserved_art_is_still_referenced() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("Assets/Images/Shop/"),
		"the ported art must still be referenced")

func test_no_raw_color_literals_in_script() -> void:
	## Colors come from DesignTokens, matching the rule test_lobby.gd
	## enforces for the lobby.
	var src := _source()
	assert_false(src.contains("Color(0."),
		"no hardcoded Color() literals -- use DesignTokens")

func test_scene_uses_project_theme() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("kejartes_theme.tres"),
		"the scene root must carry the project theme")

func test_the_top_band_has_a_sign_and_a_promo_board() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scenes/Koperasi/Koperasi.tscn")
	assert_true(src.contains("[node name=\"Signboard\" type=\"Panel\" parent=\"Stage\""),
		"the shop names itself, on the Stage")
	assert_true(src.contains("[node name=\"PromoBoard\" type=\"Panel\" parent=\"Stage\""),
		"and advertises the week's promo")
	assert_false(src.contains("name=\"CoinHUD\""), "the ledge coin HUD is gone")
	assert_true(src.contains("theme_type_variation = &\"KoperasiSignPanel\""), "the sign is lipped brown")
	assert_true(src.contains("theme_type_variation = &\"KoperasiPromoPanel\""), "the board is lipped cream")

func test_promo_board_reads_gamestate() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scripts/Koperasi/PromoBoard.gd")
	assert_true(src.contains("GameState.shop_promo_item"), "the board names the promo item")
	assert_true(src.contains("GameState.shop_promo_percent"), "and its discount")
	assert_true(src.contains("Engine.is_editor_hint()"), "its live fill is editor-gated")

## PromoBoard is a Stage child, so its own _ready() runs BEFORE Stage's --
## children ready before their parent -- and Stage's _ready() is what rolls
## the shelf (and with it shop_promo_item/percent). PromoBoard's own arrival
## is correct only because Koperasi.gd's _ready() nudges it again with
## promo_board.refresh() after Stage has finished, or a fresh shelf's promo
## would never reach the board. Pinned as a source scan: the runner cannot
## await a frame to prove Stage really has rolled by then.
func test_koperasi_ready_refreshes_the_promo_board_after_the_shelf_rolls() -> void:
	var src: String = _source()
	var at: int = src.find("func _ready():")
	assert_true(at != -1, "Koperasi.gd must have a _ready()")
	if at == -1:
		return
	var next_func: int = src.find("\nfunc ", at + 1)
	var body: String = src.substr(at, next_func - at)
	assert_true(body.contains("promo_board.refresh()"),
		"_ready() must refresh PromoBoard after Stage rolls the shelf")

## Control siblings under the same parent draw in scene-declaration order --
## later wins. Pak Herman's ChatBubble must draw OVER the top band, not
## under it, or a shown line gets clipped by Signboard/PromoBoard (fix
## round 1, 2026-09-28: the band was declared after ChatBubble, so it drew
## on top of his speech). Pinned by each node's position in the saved
## Koperasi.tscn text, which is exactly the order the scene loader builds
## the tree in.
func test_chat_bubble_draws_over_the_top_band() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scenes/Koperasi/Koperasi.tscn")
	var signboard_at := src.find("[node name=\"Signboard\" type=\"Panel\" parent=\"Stage\"")
	var promo_board_at := src.find("[node name=\"PromoBoard\" type=\"Panel\" parent=\"Stage\"")
	var chat_bubble_at := src.find("[node name=\"ChatBubble\" type=\"Control\" parent=\"Stage\"")
	assert_true(signboard_at >= 0 and promo_board_at >= 0 and chat_bubble_at >= 0,
		"the band and the chat bubble must all be declared as Stage children")
	assert_true(chat_bubble_at > signboard_at, "ChatBubble must be declared after Signboard, so it draws over it")
	assert_true(chat_bubble_at > promo_board_at, "ChatBubble must be declared after PromoBoard, so it draws over it")

## Task 3: Pak Herman's talk/idle animation. HermanAP must exist with all
## three named animations, and must never key `position` -- the Stage
## re-anchors on tall phones (test_tall_screen_layout.gd), so an absolute
## position key on Herman would pin him instead of moving with the layout.
func test_herman_animation_player_has_idle_talk_and_reset() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("name=\"HermanAP\""),
		"World/Room/Herman must carry a HermanAP AnimationPlayer")
	assert_true(raw.contains("\"idle\": SubResource") or raw.contains("&\"idle\": SubResource"),
		"HermanAP's library must register an idle animation")
	assert_true(raw.contains("\"talk\": SubResource") or raw.contains("&\"talk\": SubResource"),
		"HermanAP's library must register a talk animation")
	assert_true(raw.contains("\"RESET\": SubResource") or raw.contains("&\"RESET\": SubResource"),
		"HermanAP's library must register a RESET animation, so the editor never saves a mid-animation pose")
	# Scan only the Animation sub_resources Herman's own library refers to
	# (Animation_herman_*), not the whole file -- other Stage nodes (like the
	# back button) legitimately key their own local position.
	for id in ["Animation_herman_reset", "Animation_herman_idle", "Animation_herman_talk"]:
		var marker := "id=\"%s\"]" % id
		var start := raw.find(marker)
		assert_true(start != -1, "%s sub_resource not found" % id)
		if start == -1:
			continue
		var next_block := raw.find("[sub_resource", start + 1)
		if next_block == -1:
			next_block = raw.find("[node ", start + 1)
		var block := raw.substr(start, next_block - start)
		assert_false(block.contains(":position\")"),
			"Herman's animations must not key position -- the stage re-anchors on tall phones (%s)" % id)

## Task 4: the promo item's price tag strikes its list price and wears a
## "-N%" badge; a normal tag carries neither.
func test_a_promo_tag_shows_the_list_price_and_badge() -> void:
	var tag: PanelContainer = PriceTagScene.instantiate()
	tag.set_price(800)
	tag.set_promo(1000, 20)
	assert_true(tag.is_promo(), "the tag knows it is on promo")
	assert_eq(tag.get_old_price_text(), "1000", "the list price is shown, struck")
	assert_eq(tag.get_badge_text(), "-20%", "the badge names the percent")
	tag.clear_promo()
	assert_false(tag.is_promo(), "a normal tag drops the promo dress")
	assert_false(tag.get_node("Row/OldPrice").visible, "clear_promo() hides the struck price")
	assert_false(tag.get_node("Row/PromoBadge").visible, "and the badge")
	tag.free()

## play_buy() must not leave a promo tag reading "~~1000~~ Beli -20%" mid-tap --
## the dress hides while "Beli" stands alone, then comes back with the price
## once the tag returns to rest.
func test_play_buy_hides_the_promo_dress_and_set_price_restores_it() -> void:
	var tag: PanelContainer = PriceTagScene.instantiate()
	tag.set_price(800)
	tag.set_promo(1000, 20)
	tag.play_buy()
	assert_true(tag.is_promo(), "play_buy() does not touch _is_promo")
	assert_false(tag.get_node("Row/OldPrice").visible, "play_buy() hides the struck price")
	assert_false(tag.get_node("Row/PromoBadge").visible, "and the badge")
	tag.set_price(800)
	assert_true(tag.is_promo(), "set_price() does not touch _is_promo either")
	assert_true(tag.get_node("Row/OldPrice").visible, "set_price() brings the struck price back")
	assert_true(tag.get_node("Row/PromoBadge").visible, "and the badge")
	tag.free()

func test_the_shelf_dresses_only_the_promo_item() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scripts/Koperasi/KoperasiStage.gd")
	assert_true(src.contains("GameState.shop_promo_item"), "the stage asks which item is on promo")
	assert_true(src.contains("Cart.list_price_of("), "and strikes the list price, not the raw one")
