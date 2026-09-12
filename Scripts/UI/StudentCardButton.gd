@tool
class_name StudentCardButton
extends Button

## A student card the player taps to pick: the real DaySummary card
## (DaySummaryStudentRow, instanced as the child named Card) inside a toggle
## Button. Shared by the event picker's EventStudentCard and the item
## screen's ApplyStudentRow (2026-09-12 event-cards spec, section 1.3).
##
## The wrapper owns the card's rect outright -- position, size and scale --
## because an instanced scene's root under a plain Control loses its rect on
## load (authoring guide, Pattern C). It measures its own width, never the
## viewport, and scales the fixed-offset card art to fit.
##
## Subclasses announce a toggle in their own signal shape by overriding
## _selection_toggled(); the two screens' signals differ.

## The card art's native size. Every offset inside DaySummaryStudentRow is
## measured against it, so the whole card scales as one.
@export var card_design_size: Vector2 = Vector2(992, 410):
	set(v):
		card_design_size = v
		_fit_card()
## The largest scale the card may be drawn at. 1.0 never upscales the art.
@export_range(0.1, 2.0, 0.01) var max_card_scale: float = 1.0:
	set(v):
		max_card_scale = v
		_fit_card()
## Opacity of a card that cannot be picked (a student too tired to go).
@export_range(0.0, 1.0, 0.01) var unavailable_alpha: float = 0.55
## Avatar tint on a card that cannot be picked, so it reads as unavailable
## at a glance rather than only when tapped.
@export var unavailable_avatar_tint: Color = Color(0.7, 0.7, 0.75, 1.0)

## The DaySummary card this wrapper hosts.
@onready var card: DaySummaryStudentRow = get_node_or_null("Card") as DaySummaryStudentRow
## The tick shown while the card is picked, authored under Card so it scales
## with the art.
@onready var select_badge: TextureRect = get_node_or_null("Card/SelectBadge") as TextureRect


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_ignore_mouse_below(card)
	if select_badge:
		select_badge.visible = button_pressed
	_fit_card()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_card()


## The scale the card is drawn at for a wrapper `width` wide.
static func fit_scale(width: float, design_width: float, max_scale: float) -> float:
	if design_width <= 0.0:
		return 1.0
	return minf(max_scale, width / design_width)


## A card that cannot be picked refuses the tap, drops any selection it
## held, dims, and greys its avatar.
func set_selectable(on: bool) -> void:
	disabled = not on
	if not on:
		button_pressed = false
	modulate.a = 1.0 if on else unavailable_alpha
	if card != null and card.avatar != null:
		card.avatar.modulate = Color.WHITE if on else unavailable_avatar_tint


## True while the player has this card picked.
func is_selected() -> bool:
	return button_pressed and not disabled


## Put the card at the wrapper's top-left at its design size, scaled to the
## wrapper's width; the wrapper's minimum height follows the scale. Skipped
## until the wrapper has a width, since a zero scale would hide the card.
func _fit_card() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	var c := get_node_or_null("Card") as Control
	if c == null:
		return
	var s := fit_scale(size.x, card_design_size.x, max_card_scale)
	c.position = Vector2.ZERO
	c.size = card_design_size
	c.scale = Vector2(s, s)
	custom_minimum_size = Vector2(0.0, card_design_size.y * s)


## Taps must reach the Button, not the card's parts. Overrides on an
## instance's children are not saved with the scene, so this runs on load.
func _ignore_mouse_below(node: Node) -> void:
	if node == null:
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_below(child)


func _on_toggled(pressed: bool) -> void:
	if select_badge:
		select_badge.visible = pressed
	_selection_toggled(pressed)


## Override to announce a toggle in the subclass's own signal shape.
func _selection_toggled(_pressed: bool) -> void:
	pass
