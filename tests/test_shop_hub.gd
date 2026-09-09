@tool
extends McpTestSuiteCompat

## The Lobby's shop button now lands on a hub that splits consumables
## from cosmetics, rather than dropping straight into the Koperasi.
##
## The hub's backdrop is the Koperasi's own artwork behind the project's
## existing screen-space blur shader, so it needs no image asset of its
## own -- the mockup's blurred minimarket photo is not in the repo and
## would have been the only photograph in an illustrated game.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "shop_hub"


const HUB_SCENE := "res://Scenes/Koperasi/ShopHub.tscn"
const TILE_SCENE := "res://Scenes/Koperasi/ShopHubTile.tscn"
const COSMETIC_SCENE := "res://Scenes/Koperasi/CosmeticShop.tscn"
const HUB_SCRIPT := "res://Scripts/Koperasi/shop_hub.gd"
const COSMETIC_SCRIPT := "res://Scripts/Koperasi/cosmetic_shop.gd"
const LOBBY_SCRIPT := "res://Scripts/Lobby/loby.gd"
const KOPRASI_SCRIPT := "res://Scripts/Koperasi/koprasi.gd"
const DEBUG_SCRIPT := "res://Scripts/Debug/DebugManager.gd"


func test_every_new_scene_loads() -> void:
	for path in [HUB_SCENE, TILE_SCENE, COSMETIC_SCENE]:
		assert_not_null(load(path) as PackedScene, "%s should load" % path)


func test_hub_offers_exactly_two_destinations() -> void:
	var hub := (load(HUB_SCENE) as PackedScene).instantiate()
	var tiles := hub.get_node_or_null("Tiles")
	assert_not_null(tiles, "the hub needs a Tiles container")
	assert_not_null(hub.get_node_or_null("Tiles/ItemsTile"), "hub needs an items tile")
	assert_not_null(hub.get_node_or_null("Tiles/CosmeticsTile"), "hub needs a cosmetics tile")
	assert_eq(tiles.get_child_count(), 2,
		"the hub is a fork, not a menu -- exactly two tiles")
	hub.free()


func test_hub_tiles_are_themed_buttons_not_bare_controls() -> void:
	var hub := (load(HUB_SCENE) as PackedScene).instantiate()
	for tile_name in ["ItemsTile", "CosmeticsTile"]:
		var tile := hub.get_node("Tiles/%s" % tile_name)
		assert_true(tile is Button, "%s should be a Button" % tile_name)
		assert_eq(tile.theme_type_variation, &"ShopHubTile",
			"%s should take the shared ShopHubTile look" % tile_name)
	hub.free()


func test_hub_labels_are_indonesian() -> void:
	# The mockup was labelled in English; this project's UI is Indonesian.
	var hub := (load(HUB_SCENE) as PackedScene).instantiate()
	var items := hub.get_node("Tiles/ItemsTile/Content/Caption") as Label
	var cosmetics := hub.get_node("Tiles/CosmeticsTile/Content/Caption") as Label
	assert_eq(items.text, "Makanan & Barang", "items tile should be Indonesian")
	assert_eq(cosmetics.text, "Kosmetik", "cosmetics tile should be Indonesian")
	hub.free()


func test_hub_carries_no_english_ui_copy() -> void:
	# Only visible strings. Node names like "CosmeticsTile" are
	# engine-side identifiers and are allowed to be English -- it is the
	# copy the player reads that has to be Indonesian.
	var scene_text := FileAccess.get_file_as_string(HUB_SCENE)
	for line in scene_text.split("
"):
		if not (line.begins_with("text = ") or line.begins_with("caption_text = ")):
			continue
		for english in ["Foods & Items", "Cosmetics", "Back", "Shop", "Items"]:
			assert_false(line.contains(english),
				"'%s' is English UI copy; this project's UI is Indonesian" % english)


func test_each_tile_wears_its_own_icon() -> void:
	var hub := (load(HUB_SCENE) as PackedScene).instantiate()
	var items_icon := hub.get_node("Tiles/ItemsTile/Content/Icon") as TextureRect
	var cosmetics_icon := hub.get_node("Tiles/CosmeticsTile/Content/Icon") as TextureRect
	assert_not_null(items_icon.texture, "the items tile needs an icon")
	assert_not_null(cosmetics_icon.texture, "the cosmetics tile needs an icon")
	assert_ne(items_icon.texture, cosmetics_icon.texture,
		"the two tiles must not share one icon")
	hub.free()


func test_tile_icons_are_real_svgs_not_emoji() -> void:
	var scene_text := FileAccess.get_file_as_string(TILE_SCENE)
	var hub_text := FileAccess.get_file_as_string(HUB_SCENE)
	assert_contains(hub_text + scene_text, "icon_shop_items.svg",
		"the items icon should be a real transparent SVG")
	assert_contains(hub_text + scene_text, "icon_shop_cosmetics.svg",
		"the cosmetics icon should be a real transparent SVG")


func test_hub_blurs_the_real_koperasi_art_with_the_existing_shader() -> void:
	var scene_text := FileAccess.get_file_as_string(HUB_SCENE)
	assert_contains(scene_text, "Illustration4.jpg",
		"the hub should blur the screen its items tile actually leads to")
	assert_contains(scene_text, "shop_hub_blur_material.tres",
		"the backdrop should carry the blur material")
	var mat := load("res://Scenes/Koperasi/shop_hub_blur_material.tres") as ShaderMaterial
	assert_not_null(mat, "the blur material should load")
	assert_eq(mat.shader.resource_path, "res://Scripts/Shaders/blur.gdshader",
		"reuse the project's existing screen-space blur, do not add another")


func test_blur_is_actually_turned_on() -> void:
	# The shader's lod defaults to 0.0, which is no blur at all. A hub
	# that shipped with the default would look like the plain Koperasi.
	var mat := load("res://Scenes/Koperasi/shop_hub_blur_material.tres") as ShaderMaterial
	assert_gt(float(mat.get_shader_parameter("lod")), 0.0,
		"lod must be above 0 or the backdrop is not blurred at all")
	assert_gt(float(mat.get_shader_parameter("darkness")), 0.0,
		"some dim is needed so the tiles read over the artwork")


func test_hub_routes_to_the_two_shops() -> void:
	var src := FileAccess.get_file_as_string(HUB_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/koprasi.tscn",
		"the items tile should reach the existing shop")
	assert_contains(src, "res://Scenes/Koperasi/CosmeticShop.tscn",
		"the cosmetics tile should reach the cosmetic stub")


func test_lobby_now_opens_the_hub_not_the_shop_directly() -> void:
	var src := FileAccess.get_file_as_string(LOBBY_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/ShopHub.tscn",
		"the Lobby's shop button should land on the hub")
	assert_false(src.contains("res://Scenes/Koperasi/koprasi.tscn"),
		"the Lobby should no longer reach the item shop directly")


func test_koprasi_back_button_returns_to_the_hub() -> void:
	# The player arrived from the hub and expects to land back on it.
	var src := FileAccess.get_file_as_string(KOPRASI_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/ShopHub.tscn",
		"backing out of the shop should land on the hub, not the Lobby")


func test_cosmetic_stub_has_a_way_out() -> void:
	var scene := (load(COSMETIC_SCENE) as PackedScene).instantiate()
	assert_not_null(scene.get_node_or_null("BackButton"),
		"a stub screen with no way out is a trap")
	var src := FileAccess.get_file_as_string(COSMETIC_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/ShopHub.tscn",
		"the stub should return to the hub")
	scene.free()


func test_cosmetic_stub_says_it_is_unbuilt() -> void:
	# A wholly blank screen reads as a bug rather than as "not yet".
	var scene := (load(COSMETIC_SCENE) as PackedScene).instantiate()
	var label := scene.get_node_or_null("ComingSoonLabel") as Label
	assert_not_null(label, "the stub should say it is coming, not sit blank")
	assert_eq(label.text, "Segera Hadir", "and say so in Indonesian")
	scene.free()


func test_debug_overlay_can_teleport_to_the_hub() -> void:
	var src := FileAccess.get_file_as_string(DEBUG_SCRIPT)
	assert_contains(src, "res://Scenes/Koperasi/ShopHub.tscn",
		"the hub should be reachable without walking the Lobby")
