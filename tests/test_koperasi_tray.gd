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
	# Project convention bans emoji as UI iconography (2026-09-02).
	var paths := [
		"res://Scripts/Koperasi/koprasi.gd",
		"res://Scripts/Koperasi/rakbarang_1.gd",
	]
	for path in paths:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "%s missing" % path)
		if f == null:
			continue
		var src := f.get_as_text()
		for glyph in [char(0x1F6D2), char(0x21A9)]:
			assert_false(src.contains(glyph),
				"%s still contains an emoji glyph" % path)

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
