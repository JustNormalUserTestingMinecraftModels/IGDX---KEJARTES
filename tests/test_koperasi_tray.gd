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
