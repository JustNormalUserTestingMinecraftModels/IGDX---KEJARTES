@tool
extends McpTestSuite

## The 2026-09-17 Koperasi revamp (spec
## docs/superpowers/specs/2026-09-17-koperasi-shop-revamp-design.md): Pak
## Herman's counter as three art layers, six shelf slots on the mockup's
## circles, and a placeholder chat bubble whose tail matches its box.
##
## Must be @tool; no test here may be a coroutine.

const SCENE := "res://Scenes/Koperasi/koprasi.tscn"
const TAIL := "res://Assets/Images/Shop/UI/chat_bubble_tail.svg"


func suite_name() -> String:
	return "koperasi_shop_layout"


# ─── the bubble's style

func test_the_bubble_is_a_flat_card_box() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("panel", "ShopChatBubble") as StyleBoxFlat
	assert_true(box != null, "ShopChatBubble has a flat panel")
	if box == null:
		return
	assert_eq(theme.get_type_variation_base("ShopChatBubble"), &"PanelContainer")
	assert_eq(box.bg_color, tokens.surface_card, "card white, from the tokens")
	assert_eq(box.corner_radius_top_left, ThemeFactory.SHOP_CHAT_BUBBLE_RADIUS)
	assert_eq(box.shadow_size, 0, "the mockup's bubble has no shadow")


func test_the_tail_is_filled_with_the_bubbles_colour() -> void:
	var svg := FileAccess.get_file_as_string(TAIL)
	assert_true(svg != "", "tail art missing at " + TAIL)
	var want := "#" + DesignTokens.load_default().surface_card.to_html(false).to_upper()
	assert_true(svg.contains('fill="%s"' % want),
		"the tail must match surface_card (%s), or a seam shows where it meets the box" % want)
	for element in ["<text", "<tspan", "<use"]:
		assert_false(svg.contains(element), "ThorVG drops " + element)


func test_the_bubble_is_baked() -> void:
	var baked := ResourceLoader.load("res://Assets/Theme/kejartes_theme.tres", "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_true(baked != null and baked.has_stylebox("panel", "ShopChatBubble"),
		"rebake after adding the variation")
