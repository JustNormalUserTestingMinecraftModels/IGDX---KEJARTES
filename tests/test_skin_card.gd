@tool
extends McpTestSuite

## SkinCard.tscn / .gd: one skin in SkinSelect's carousel, and the static
## snap rule the carousel settles with (spec:
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md section 4,
## "The carousel"). settle_index is static so it is testable without a tree
## or a frame, the same shape as BasketTray.classify_drag.

const CARD := "res://Scenes/Skins/SkinCard.tscn"
const BLUR := "res://Scenes/Skins/skin_option_blur_material.tres"


func suite_name() -> String:
	return "skin_card"


func _new_card() -> SkinCard:
	var card: SkinCard = (load(CARD) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func test_show_skin_loads_that_skins_splash() -> void:
	var card := _new_card()
	card.show_skin("Shinta", "skin1", false)
	assert_eq(card.skin_id, "skin1")
	var art := card.get_node("Art") as TextureRect
	assert_true(art.texture != null, "the card must have a splash")
	if art.texture == null:
		return
	assert_eq(art.texture.resource_path, StudentSkins.layer_path("Shinta", "skin1", "splash"))
	assert_false(card.get_node("Lock").visible)


func test_locked_skin_shows_the_lock() -> void:
	var card := _new_card()
	card.show_skin("Shinta", "skin1", true)
	assert_true(card.get_node("Lock").visible)


## The two-state swap from the spec: selected is crisp and full colour,
## unselected is dimmed and carries the blur material. Assigning a preloaded
## material is a reference swap, not runtime construction.
func test_selected_card_is_crisp_and_unselected_is_dimmed_and_blurred() -> void:
	var card := _new_card()
	card.show_skin("Shinta", StudentSkins.DEFAULT_ID, false)
	var art := card.get_node("Art") as TextureRect

	card.set_selected(true)
	assert_eq(art.modulate, Color.WHITE)
	assert_true(art.material == null, "the selected card must not be blurred")

	card.set_selected(false)
	assert_eq(art.modulate, card.unselected_modulate)
	assert_true(art.material != null, "an unselected card must be blurred")
	if art.material == null:
		return
	assert_eq(art.material.resource_path, BLUR)


## The splash art is 1080x1920 but the band above the tray is 1080x1337, so
## a card that filled the screen would crop the outfit at the knees -- on
## the one screen whose job is showing the outfit. 1337 tall at the art's
## own 9:16 is 752 wide.
func test_card_is_sized_to_fit_the_whole_figure_above_the_tray() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_true(src.contains("custom_minimum_size = Vector2(752, 1337)"))


func test_settle_index_stays_put_for_a_small_slow_drag() -> void:
	assert_eq(SkinCard.settle_index(0, 40.0, 0.0, 812.0, 2), 0)


func test_settle_index_advances_past_the_halfway_mark() -> void:
	assert_eq(SkinCard.settle_index(0, -500.0, 0.0, 812.0, 2), 1)


## A flick decides on its own, whatever distance it covered.
func test_settle_index_follows_a_fast_flick() -> void:
	assert_eq(SkinCard.settle_index(0, -20.0, -900.0, 812.0, 2), 1)
	assert_eq(SkinCard.settle_index(1, 20.0, 900.0, 812.0, 2), 0)


func test_settle_index_clamps_at_both_ends() -> void:
	assert_eq(SkinCard.settle_index(0, 900.0, 2000.0, 812.0, 2), 0)
	assert_eq(SkinCard.settle_index(1, -900.0, -2000.0, 812.0, 2), 1)
