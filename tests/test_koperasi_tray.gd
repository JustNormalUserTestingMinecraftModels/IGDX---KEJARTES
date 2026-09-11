@tool
extends McpTestSuiteCompat

## Suite for the 2026-09-11 Koperasi rework: basket icon, coin-pill price
## tag, shelf item life, and the warm basket tray that replaces the popup.

func suite_name() -> String:
	return "koperasi_tray"

const BASKET_ICON := "res://Assets/Images/Shop/UI/icon_keranjang.svg"

func test_basket_icon_exists() -> void:
	assert_true(ResourceLoader.exists(BASKET_ICON),
		"B3 basket icon missing at %s" % BASKET_ICON)

func test_basket_icon_has_no_text_elements() -> void:
	# Godot rasterises SVG through ThorVG, which silently drops <text>.
	# Everything must be a path, rect, or circle.
	var f := FileAccess.open(BASKET_ICON, FileAccess.READ)
	assert_not_null(f, "could not open %s" % BASKET_ICON)
	if f == null:
		return
	var src := f.get_as_text()
	assert_false(src.contains("<text"),
		"SVG uses <text>, which ThorVG drops on import")

const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

func _baked_theme() -> Theme:
	# CACHE_MODE_IGNORE matters: the editor holds kejartes_theme.tres in
	# memory from startup, so a plain load() returns that cached copy and
	# never sees a fresh rebake.
	return ResourceLoader.load(
		THEME_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme

func test_price_tag_variations_registered() -> void:
	var theme := _baked_theme()
	assert_not_null(theme, "baked theme missing at %s" % THEME_PATH)
	if theme == null:
		return
	for v in ["PriceTag", "PriceTagPressed", "PriceTagDisabled", "BasketTray"]:
		assert_true(theme.has_stylebox("panel", v),
			"variation %s has no panel stylebox" % v)

func test_price_tag_is_green_and_pressed_is_darker() -> void:
	var theme := _baked_theme()
	var rest := theme.get_stylebox("panel", "PriceTag") as StyleBoxFlat
	var pressed := theme.get_stylebox("panel", "PriceTagPressed") as StyleBoxFlat
	assert_not_null(rest, "PriceTag panel is not a StyleBoxFlat")
	if rest == null:
		return
	assert_not_null(pressed, "PriceTagPressed panel is not a StyleBoxFlat")
	if pressed == null:
		return
	assert_true(rest.bg_color.g > rest.bg_color.r,
		"PriceTag should read green")
	assert_true(pressed.bg_color.v < rest.bg_color.v,
		"pressed state must be darker than rest")

func test_basket_tray_has_no_black() -> void:
	# The mentor's note: nothing in the tray may read as premium-black.
	var theme := _baked_theme()
	assert_not_null(theme, "baked theme missing at %s" % THEME_PATH)
	if theme == null:
		return
	assert_true(theme.has_stylebox("panel", "BasketTray"),
		"BasketTray variation is not registered")
	if not theme.has_stylebox("panel", "BasketTray"):
		return
	var tray := theme.get_stylebox("panel", "BasketTray") as StyleBoxFlat
	assert_not_null(tray, "BasketTray panel is not a StyleBoxFlat")
	if tray == null:
		return
	assert_true(tray.bg_color.v > 0.75, "tray surface must stay light and warm")
	assert_true(tray.bg_color.r > tray.bg_color.b, "tray surface must be warm, not cool")


func test_koperasi_scripts_carry_no_emoji() -> void:
	# Project convention bans emoji as UI iconography (2026-09-02). This
	# scans by codepoint range rather than by a list of known glyphs --
	# an earlier two-glyph version of this test passed while three other
	# emoji were still present in koprasi.gd.
	var paths := [
		"res://Scripts/Koperasi/koprasi.gd",
		"res://Scripts/Koperasi/rakbarang_1.gd",
		"res://Scripts/Koperasi/PriceTag.gd",
	]
	for path in paths:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "%s missing" % path)
		if f == null:
			continue
		var src := f.get_as_text()
		var offender := -1
		for i in src.length():
			var c := src.unicode_at(i)
			if (c >= 0x1F000 and c <= 0x1FAFF) \
			or (c >= 0x2600 and c <= 0x27BF) \
			or (c >= 0x2B00 and c <= 0x2BFF) \
			or (c >= 0x2190 and c <= 0x21FF):
				offender = c
				break
		assert_eq(offender, -1,
			"%s contains an emoji codepoint (0x%x)" % [path, offender])

const TRAY_DOTS := "res://Assets/Images/Shop/UI/tray_dots.png"

func test_tray_dot_tile_exists_and_tiles() -> void:
	assert_true(ResourceLoader.exists(TRAY_DOTS), "tray dot tile missing")
	var tex := load(TRAY_DOTS) as Texture2D
	assert_not_null(tex, "tray dot tile did not load as a texture")
	if tex == null:
		return
	assert_eq(tex.get_width(), 26, "tile must be 26px wide to repeat cleanly")
	assert_eq(tex.get_height(), 26, "tile must be 26px tall to repeat cleanly")

const PRICE_TAG_SCENE := "res://Scenes/Koperasi/PriceTag.tscn"

func test_price_tag_scene_exists() -> void:
	assert_true(ResourceLoader.exists(PRICE_TAG_SCENE),
		"PriceTag.tscn missing")

func test_price_tag_shows_price_at_rest() -> void:
	var packed := load(PRICE_TAG_SCENE)
	assert_not_null(packed, "PriceTag.tscn missing")
	if packed == null:
		return
	var tag = packed.instantiate()
	tag.set_price(800)
	assert_eq(tag.get_label_text(), "800",
		"tag should show the bare price at rest")
	tag.free()

func test_price_tag_swaps_to_beli_on_buy() -> void:
	var packed := load(PRICE_TAG_SCENE)
	assert_not_null(packed, "PriceTag.tscn missing")
	if packed == null:
		return
	var tag = packed.instantiate()
	tag.set_price(800)
	tag.play_buy()
	# play_buy sets the label synchronously; only the tween is deferred,
	# so this test never needs to await.
	assert_eq(tag.get_label_text(), "Beli",
		"pressed state must read Beli, not the number")
	tag.free()

func test_price_tag_unaffordable_keeps_the_price_visible() -> void:
	var packed := load(PRICE_TAG_SCENE)
	assert_not_null(packed, "PriceTag.tscn missing")
	if packed == null:
		return
	var tag = packed.instantiate()
	tag.set_price(1200)
	tag.set_affordable(false)
	assert_eq(tag.get_label_text(), "1200",
		"unaffordable tags still show what the item costs")
	assert_eq(tag.theme_type_variation, &"PriceTagDisabled",
		"unaffordable tag should use the neutral variation")
	tag.free()

func test_price_tag_uses_no_theme_overrides() -> void:
	var f := FileAccess.open("res://Scripts/Koperasi/PriceTag.gd", FileAccess.READ)
	assert_not_null(f, "PriceTag.gd missing")
	if f == null:
		return
	assert_false(f.get_as_text().contains("add_theme_"),
		"PriceTag must use type variations, never theme overrides")

func test_price_tag_wipe_node_resolves() -> void:
	# The wipe must live under a plain Control, not directly under the
	# PanelContainer root -- a container overwrites its children's size on
	# every sort, which would stomp the wipe's tweened width.
	var packed := load(PRICE_TAG_SCENE)
	assert_not_null(packed, "PriceTag.tscn missing")
	if packed == null:
		return
	var tag = packed.instantiate()
	var wipe = tag.get_node_or_null("WipeHost/Wipe")
	assert_not_null(wipe, "Wipe must resolve at WipeHost/Wipe")
	var host = tag.get_node_or_null("WipeHost")
	assert_not_null(host, "WipeHost must exist")
	if host != null:
		assert_false(host is Container,
			"WipeHost must be a plain Control, not a Container")
	tag.free()

const RAK_SRC := "res://Scripts/Koperasi/rakbarang_1.gd"

func _rak_source() -> String:
	var f := FileAccess.open(RAK_SRC, FileAccess.READ)
	assert_not_null(f, "rakbarang_1.gd missing")
	if f == null:
		return ""
	return f.get_as_text()

func test_shelf_instances_price_tags() -> void:
	var src := _rak_source()
	assert_true(src.contains("PriceTag.tscn"),
		"shelf should instance the PriceTag scene")
	assert_true(src.contains("set_price("),
		"shelf should push prices through set_price")

func test_shelf_plays_buy_on_press() -> void:
	var src := _rak_source()
	assert_true(src.contains("play_buy()"),
		"_on_barang_pressed should run the tag's buy transition")

func test_shelf_refreshes_affordability() -> void:
	var src := _rak_source()
	assert_true(src.contains("_refresh_affordability"),
		"shelf must recompute which items the player can afford")
	assert_true(src.contains("set_affordable("),
		"affordability must reach the tags")

const SHELF_ITEM_SRC := "res://Scripts/Koperasi/ShelfItem.gd"

func test_shelf_item_script_exists() -> void:
	assert_true(ResourceLoader.exists(SHELF_ITEM_SRC), "ShelfItem.gd missing")

func test_shelf_item_documents_every_export() -> void:
	var f := FileAccess.open(SHELF_ITEM_SRC, FileAccess.READ)
	assert_not_null(f, "ShelfItem.gd missing")
	if f == null:
		return
	var lines := f.get_as_text().split("\n")
	var i := 0
	while i < lines.size():
		if lines[i].strip_edges().begins_with("@export"):
			var prev := lines[i - 1].strip_edges() if i > 0 else ""
			assert_true(prev.begins_with("##"),
				"undocumented @export on line %d" % (i + 1))
		i += 1

func test_shelf_item_bobs_with_a_phase_offset() -> void:
	var f := FileAccess.open(SHELF_ITEM_SRC, FileAccess.READ)
	assert_not_null(f, "ShelfItem.gd missing")
	if f == null:
		return
	assert_true(f.get_as_text().contains("phase"),
		"items must bob out of sync, so the shelf does not pulse in unison")
