@tool
class_name BasketTray
extends Control

## The koperasi basket tray, docked at the bottom of the shelf screen: the
## items the player has picked stand on its plank at their own heights, each
## with a ×N badge, and its footer carries the running total and the one
## Beli button.
##
## The root is a bare anchor (authoring guide, Pattern C); Body carries the
## geometry. Slots are placed by hand rather than by a container, so layout is
## synchronous: tests assert real positions, and the shop reads a slot's
## landing rect the moment the cart changes -- no frame of waiting.

## Emitted when the player presses Beli. koprasi.gd owns the purchase.
signal buy_pressed
## Emitted when the player holds a tray item to return one to the shelf.
signal remove_requested(item_name: String)
## Emitted on a quick tap on a tray item.
signal slot_tapped(item_name: String)

## Gap between two items on the plank, in pixels, before the row is fitted.
@export var item_gap: float = 20.0:
	set(value):
		item_gap = value
		if is_inside_tree():
			_layout_slots()

## Scale on every item's own size before the row is fitted to the plank.
## 1.0 keeps an item exactly as tall as its authored display size.
@export var item_scale: float = 1.0:
	set(value):
		item_scale = value
		if is_inside_tree():
			_layout_slots()

const SLOT_SCENE := preload("res://Scenes/Koperasi/TraySlot.tscn")

@onready var _items: Control = $Body/Items
@onready var _empty_state: Control = $Body/EmptyState
@onready var _hint: Label = $Body/Hint
@onready var _total_label: Label = $Body/Footer/TotalLabel
@onready var _beli_button: Button = $Body/Footer/BeliButton
@onready var _emblem: Control = $Body/Emblem
@onready var _emblem_badge: Control = $Body/Emblem/CountBadge
@onready var _emblem_count: Label = $Body/Emblem/CountBadge/Count

## item_name -> TraySlot, in the order the lines entered the cart.
var _slots: Dictionary = {}
## The entries last handed to refresh().
var _entries: Dictionary = {}
## item_name -> units bought but still flying in; refresh() hides them.
var _held: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()
	if is_instance_valid(_beli_button) and not _beli_button.pressed.is_connected(_on_beli_pressed):
		_beli_button.pressed.connect(_on_beli_pressed)


## Redraws the tray from Cart-shaped entries:
## item_name -> {"data": ItemData, "quantity": int}.
func refresh(entries: Dictionary) -> void:
	_ensure_nodes()
	_entries = entries
	for item_name in _slots.keys():
		if not entries.has(item_name):
			var gone: Node = _slots[item_name]
			_slots.erase(item_name)
			gone.queue_free()
	var shown_units := 0
	for item_name in entries:
		var slot: TraySlot = _slots.get(item_name)
		if slot == null:
			slot = SLOT_SCENE.instantiate()
			_items.add_child(slot)
			slot.remove_requested.connect(_on_slot_remove_requested)
			slot.tapped.connect(_on_slot_tapped)
			_slots[item_name] = slot
		var shown := int(entries[item_name]["quantity"]) - int(_held.get(item_name, 0))
		slot.bind(entries[item_name]["data"], maxi(shown, 1))
		# A hold-to-return shrinks the slot before the cart hears of it; a
		# line that still has units must come back at full size.
		slot.scale = Vector2.ONE
		slot.modulate.a = 1.0 if shown > 0 else 0.0
		shown_units += maxi(shown, 0)
	_layout_slots()
	var empty := entries.is_empty()
	_empty_state.visible = empty
	_hint.visible = not empty
	_emblem_count.text = str(shown_units)
	_emblem_badge.visible = shown_units > 0
	_total_label.text = "Total: %s koin" % format_koin(Cart.total_of(entries))


## Call BEFORE Cart.add_item(): the refresh that follows keeps the new unit
## hidden until land() says its flight has arrived.
func hold_for_landing(item_name: String) -> void:
	_held[item_name] = int(_held.get(item_name, 0)) + 1


## One unit of item_name has landed: show it and pop its slot. Returns the
## slot, or null if the line left the cart mid-flight.
func land(item_name: String) -> Control:
	if _held.has(item_name):
		_held[item_name] -= 1
		if _held[item_name] <= 0:
			_held.erase(item_name)
	refresh(_entries)
	var slot: TraySlot = _slots.get(item_name)
	if slot != null and slot.is_inside_tree():
		AnimUtils.spawn_pop(slot)
	return slot


## Forgets every unit still in flight -- the cart was bought or emptied.
func clear_held() -> void:
	_held.clear()


## Where a unit of item_name lands, in global coordinates: its slot's rect,
## or the whole row while the line has no slot.
func landing_rect_for(item_name: String) -> Rect2:
	_ensure_nodes()
	var slot: TraySlot = _slots.get(item_name)
	if slot == null:
		return _items.get_global_rect()
	return slot.get_global_rect()


## The slot showing item_name, or null.
func get_slot(item_name: String) -> TraySlot:
	return _slots.get(item_name)


## The basket emblem, which bounces when an item lands.
func get_emblem() -> Control:
	_ensure_nodes()
	return _emblem


## Reads the emblem's unit count. Exists so tests need not know node paths.
func get_emblem_count_text() -> String:
	_ensure_nodes()
	return _emblem_count.text


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


## Places every slot on the plank: each at its own size (times item_scale),
## bottoms on the plank line, the row centred. A row wider than the plank, or
## an item taller than the room above it, shrinks evenly to fit.
func _layout_slots() -> void:
	_ensure_nodes()
	var order: Array = _slots.keys()
	if order.is_empty():
		return
	var room: Vector2 = _items.size
	var row_w := item_gap * float(order.size() - 1)
	var tallest := 0.0
	for item_name in order:
		var s: Vector2 = _slots[item_name].natural_size * item_scale
		row_w += s.x
		tallest = maxf(tallest, s.y)
	var fit := 1.0
	if row_w > room.x:
		fit = room.x / row_w
	if tallest * fit > room.y:
		fit = room.y / tallest
	var x := (room.x - row_w * fit) / 2.0
	for item_name in order:
		var slot: TraySlot = _slots[item_name]
		var s: Vector2 = slot.natural_size * item_scale * fit
		slot.size = s
		slot.position = Vector2(x, room.y - s.y)
		# spawn_pop and shrink_and_fade scale about the pivot without setting
		# it: from the foot, a landing grows up off the plank.
		slot.pivot_offset = Vector2(s.x * 0.5, s.y)
		x += s.x + item_gap * fit


func _on_beli_pressed() -> void:
	buy_pressed.emit()


func _on_slot_remove_requested(item_name: String) -> void:
	remove_requested.emit(item_name)


func _on_slot_tapped(item_name: String) -> void:
	slot_tapped.emit(item_name)


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
	if not is_instance_valid(_emblem):
		_emblem = get_node_or_null("Body/Emblem")
	if not is_instance_valid(_emblem_badge):
		_emblem_badge = get_node_or_null("Body/Emblem/CountBadge")
	if not is_instance_valid(_emblem_count):
		_emblem_count = get_node_or_null("Body/Emblem/CountBadge/Count")
