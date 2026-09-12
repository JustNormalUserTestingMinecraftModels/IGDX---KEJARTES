@tool
extends McpTestSuite

## StudentCardButton: the toggle Button that hosts the real DaySummary card
## for the event picker and the item screen (2026-09-12 event-cards spec,
## 1.3). It owns the card's rect (Pattern C), scales the fixed-offset art to
## its own width, and makes every part of the card hand taps to the Button.

const _CARD := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"


func suite_name() -> String:
	return "student_card_button"


## A bare wrapper around the real card, the shape both wrapper scenes have.
func _wrapper() -> StudentCardButton:
	var b := StudentCardButton.new()
	var card: Control = (load(_CARD) as PackedScene).instantiate()
	card.name = "Card"
	var badge := TextureRect.new()
	badge.name = "SelectBadge"
	card.add_child(badge)
	b.add_child(card)
	Engine.get_main_loop().root.add_child(b)
	track(b)
	return b


func test_fit_scale_never_upscales() -> void:
	assert_eq(StudentCardButton.fit_scale(1200.0, 992.0, 1.0), 1.0)
	assert_true(absf(StudentCardButton.fit_scale(944.0, 992.0, 1.0) - 944.0 / 992.0) < 0.0001)
	assert_eq(StudentCardButton.fit_scale(500.0, 0.0, 1.0), 1.0, "no divide by zero")


func test_wrapper_owns_the_card_rect_at_944() -> void:
	var b := _wrapper()
	b.size = Vector2(944, 400)
	# The fit also runs on NOTIFICATION_RESIZED; calling it directly keeps the
	# test independent of when Godot delivers that notification.
	b._fit_card()
	var card := b.get_node("Card") as Control
	assert_eq(card.position, Vector2.ZERO)
	assert_eq(card.size, Vector2(992, 410), "the card keeps its design size")
	assert_true(absf(card.scale.x - 944.0 / 992.0) < 0.001, "and scales to fit")
	assert_true(absf(b.custom_minimum_size.y - 410.0 * 944.0 / 992.0) < 0.5,
		"the wrapper's height follows the scale")


func test_wrapper_draws_native_size_at_992() -> void:
	var b := _wrapper()
	b.size = Vector2(992, 410)
	b._fit_card()
	assert_eq((b.get_node("Card") as Control).scale, Vector2.ONE)


func test_every_card_part_ignores_the_mouse() -> void:
	var b := _wrapper()
	var stack: Array[Node] = [b.get_node("Card")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s would swallow the tap meant for the card" % n.name)
		stack.append_array(n.get_children())


func test_unselectable_card_dims_and_drops_selection() -> void:
	var b := _wrapper()
	b.button_pressed = true
	b.set_selectable(false)
	assert_true(b.disabled)
	assert_false(b.is_selected(), "an unselectable card drops its selection")
	assert_true(absf(b.modulate.a - 0.55) <= 0.01)
	assert_eq(b.card.avatar.modulate, Color(0.7, 0.7, 0.75, 1.0))
	b.set_selectable(true)
	assert_eq(b.modulate.a, 1.0)
	assert_eq(b.card.avatar.modulate, Color.WHITE)


func test_select_badge_follows_the_toggle() -> void:
	var b := _wrapper()
	assert_false(b.select_badge.visible)
	b.button_pressed = true
	assert_true(b.select_badge.visible)
	b.button_pressed = false
	assert_false(b.select_badge.visible)
