@tool
class_name BasketTray
extends Control

## The koperasi basket tray, docked at the bottom of the shelf screen: the
## items the player has picked stand on its plank, and its footer carries the
## running total and the one Beli button.
##
## The root is a bare anchor (authoring guide, Pattern C); Body carries the
## geometry. refresh() is plain synchronous code, so tests drive it directly
## and the shop can read a slot's landing rect the moment the cart changes.

## Emitted when the player presses Beli. koprasi.gd owns the purchase.
signal buy_pressed

@onready var _items: Control = $Body/Items
@onready var _empty_state: Control = $Body/EmptyState
@onready var _hint: Label = $Body/Hint
@onready var _total_label: Label = $Body/Footer/TotalLabel
@onready var _beli_button: Button = $Body/Footer/BeliButton


func _ready() -> void:
	_ensure_nodes()
	if is_instance_valid(_beli_button) and not _beli_button.pressed.is_connected(_on_beli_pressed):
		_beli_button.pressed.connect(_on_beli_pressed)


## Redraws the tray from Cart-shaped entries:
## item_name -> {"data": ItemData, "quantity": int}.
func refresh(entries: Dictionary) -> void:
	_ensure_nodes()
	var empty := entries.is_empty()
	_empty_state.visible = empty
	_hint.visible = not empty
	_total_label.text = "Total: %s koin" % format_koin(Cart.total_of(entries))


## 2400 -> "2.400": Indonesian groups thousands with a dot.
static func format_koin(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


## Reads the footer. Exists so tests need not know node paths.
func get_total_text() -> String:
	_ensure_nodes()
	return _total_label.text


## The footer's Beli button, for the shop's press feedback.
func get_beli_button() -> Button:
	_ensure_nodes()
	return _beli_button


func _on_beli_pressed() -> void:
	buy_pressed.emit()


## Resolves @onready nodes when a method runs before _ready.
func _ensure_nodes() -> void:
	if not is_instance_valid(_items):
		_items = get_node_or_null("Body/Items")
	if not is_instance_valid(_empty_state):
		_empty_state = get_node_or_null("Body/EmptyState")
	if not is_instance_valid(_hint):
		_hint = get_node_or_null("Body/Hint")
	if not is_instance_valid(_total_label):
		_total_label = get_node_or_null("Body/Footer/TotalLabel")
	if not is_instance_valid(_beli_button):
		_beli_button = get_node_or_null("Body/Footer/BeliButton")
