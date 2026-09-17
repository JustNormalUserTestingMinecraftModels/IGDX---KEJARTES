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


# ─── the scene

func _shop() -> Control:
	var shop := (load(SCENE) as PackedScene).instantiate() as Control
	track(shop)
	return shop


func _rect(c: Control) -> Rect2:
	return Rect2(c.offset_left, c.offset_top,
		c.offset_right - c.offset_left, c.offset_bottom - c.offset_top)


func test_the_three_layers_stack_full_size_and_let_taps_through() -> void:
	var stage := _shop().get_node_or_null("Stage") as Control
	assert_true(stage != null, "missing the Stage")
	if stage == null:
		return
	var art := {
		"Background": "res://Assets/Images/Shop/Koperasi/shop_background.png",
		"Herman": "res://Assets/Images/Shop/Koperasi/shop_herman.png",
		"Foreground": "res://Assets/Images/Shop/Koperasi/shop_foreground.png",
	}
	for layer in art:
		var tex := stage.get_node_or_null(layer) as TextureRect
		assert_true(tex != null, layer + " missing")
		if tex == null:
			continue
		assert_eq(tex.texture.resource_path, art[layer], layer + "'s art")
		assert_eq(tex.texture.get_size(), Vector2(1080, 1920), layer + " is drawn at 1080x1920")
		assert_eq(Vector4(tex.anchor_left, tex.anchor_top, tex.anchor_right, tex.anchor_bottom),
			Vector4(0, 0, 1, 1), layer + " fills the stage")
		assert_eq(tex.mouse_filter, Control.MOUSE_FILTER_IGNORE, layer + " never eats a tap")
	var order := ["Background", "Barang1", "Barang6", "Herman", "Foreground",
		"ChatBubble", "BackButton", "TrayDock"]
	for i in range(order.size() - 1):
		assert_true(stage.get_node(order[i]).get_index() < stage.get_node(order[i + 1]).get_index(),
			"%s draws under %s" % [order[i], order[i + 1]])


## Measured off newshop_mockup.png's circles: diameter 180, centres
## x 126 / 490 and y 400 / 676 / 944, numbered row by row.
func test_six_slots_sit_on_the_mockups_circles() -> void:
	var stage := _shop().get_node("Stage")
	var want := [Rect2(36, 310, 180, 180), Rect2(400, 310, 180, 180),
		Rect2(36, 586, 180, 180), Rect2(400, 586, 180, 180),
		Rect2(36, 854, 180, 180), Rect2(400, 854, 180, 180)]
	for i in range(6):
		var slot := stage.get_node_or_null("Barang%d" % (i + 1)) as TextureButton
		assert_true(slot != null, "Barang%d missing" % (i + 1))
		if slot == null:
			continue
		assert_eq(_rect(slot), want[i], "Barang%d's circle" % (i + 1))
		assert_true(slot.get_node_or_null("PriceTag") != null,
			"Barang%d's price tag is in the scene" % (i + 1))
	assert_true(stage.get_node_or_null("Barang7") == null, "six slots, no more")


func test_the_bubble_points_at_herman() -> void:
	var bubble := _shop().get_node_or_null("Stage/ChatBubble") as Control
	assert_true(bubble != null, "missing Stage/ChatBubble")
	if bubble == null:
		return
	assert_eq(_rect(bubble), Rect2(36, 23, 1010, 345), "box plus tail, off the mockup")
	assert_eq(bubble.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var body := bubble.get_node("Body") as PanelContainer
	assert_eq(body.theme_type_variation, &"ShopChatBubble")
	assert_eq(_rect(body), Rect2(0, 0, 1010, 233), "the box")
	var tail := bubble.get_node("Tail") as TextureRect
	assert_eq(tail.texture.resource_path, TAIL)
	assert_eq(_rect(tail), Rect2(751, 230, 65, 115), "tip at (852, 368) on screen")
	var text := bubble.get_node("Body/Text") as RichTextLabel
	assert_eq(text.theme_type_variation, &"EventDialogueText", "the game's speaking voice")
	assert_true(text.text.length() > 0, "placeholder copy until the real lines land")


func test_the_old_landing_is_gone() -> void:
	var raw := FileAccess.get_file_as_string(SCENE)
	for gone in ["KEBUTUHAN SEKOLAH", "ShopShelfButton", "Illustration4.jpg", "rak2.jpg"]:
		assert_false(raw.contains(gone), "koprasi.tscn still carries " + gone)
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/koprasi.gd")
	assert_false(src.contains("_on_rak1_pressed"), "no shelf toggle: the counter is the screen")
