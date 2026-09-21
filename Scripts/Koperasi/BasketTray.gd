@tool
class_name BasketTray
extends Control

## The koperasi basket tray, docked at the bottom of the shelf screen: the
## items the player has picked stand on its plank at their own heights, each
## with a ×N badge, and its footer carries the running total and the one
## Beli button.
##
## Two ways to move it, both landing in set_state(): the CrateHandle
## koprasi.gd owns, and a drag -- the tray follows a finger between docked
## and hidden, and classify_drag() decides where the release settles. A
## basket emblem in the top-right corner was a third until 2026-09-21; it
## carried the cart's total count and a toggle button, and both moved to
## CrateHandle, which already sits at that exact spot while expanded.
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
## Emitted whenever the tray's expanded/collapsed state actually changes
## (never for a set_state() call that repeats the current state).
signal state_changed(state: int)

## EXPANDED is the tray docked on the shelf; COLLAPSED slides it down by
## tray_offset_collapsed, out of the way, leaving only the crate handle.
enum ViewState { EXPANDED, COLLAPSED }

## How far down (px) the tray slides when collapsed.
@export var tray_offset_collapsed: float = 190.0

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

## Drag speed (px/s) past which a flick decides the tray's resting state on
## its own, whatever the distance covered. Below this the halfway rule wins.
const FLICK_VELOCITY: float = 900.0
## Fraction of the full travel a slow drag must cross to commit to the far
## state. 0.5 is the midpoint: past it the tray goes, short of it it returns.
const COMMIT_FRACTION: float = 0.5
## Drag distance (px) past which the slots under the finger give up their own
## press to the tray. Matches TraySlot.hold_slop's default -- a gesture that
## is a drag to the tray must not also be a tap to a slot, and since
## 2026-09-21 a tap returns an item, so a stolen gesture would empty the cart.
const DRAG_STEALS_AFTER: float = 30.0

const SLOT_SCENE := preload("res://Scenes/Koperasi/TraySlot.tscn")
## Cart's script, so its static total_of() is called on the type rather than
## through the autoload instance (which GDScript warns about).
const CART_SCRIPT := preload("res://Scripts/Inventory/Cart.gd")

@onready var _body: Control = $Body
@onready var _items: Control = $Body/Items
@onready var _empty_state: Control = $Body/EmptyState
@onready var _hint: Label = $Body/Hint
@onready var _total_label: Label = $Body/Footer/TotalLabel
@onready var _beli_button: Button = $Body/Footer/BeliButton

## item_name -> TraySlot, in the order the lines entered the cart.
var _slots: Dictionary = {}
## The entries last handed to refresh().
var _entries: Dictionary = {}
## item_name -> units bought but still flying in; refresh() hides them.
var _held: Dictionary = {}

## Current EXPANDED/COLLAPSED state; see set_state().
var _state: int = ViewState.EXPANDED
## position.y as authored in the scene, captured once in _ready(); every
## slide is relative to this so repeated toggles never drift.
var _base_y: float = 0.0
## The tween driving the current slide, if any -- killed before a new one
## starts so two quick toggles never fight.
var _tray_tween: Tween

## True while a finger is dragging the tray. The slide tween is killed when a
## drag starts, so a drag that interrupts a toggle takes over cleanly instead
## of fighting it for position.y.
var _dragging: bool = false
## Global y where the current drag began.
var _drag_from_y: float = 0.0
## The most recent drag sample, for the release velocity.
var _drag_last_y: float = 0.0
## Time of the most recent drag sample, in milliseconds.
var _drag_last_msec: int = 0
## Release speed in px/s, positive downward. Fed to classify_drag().
var _drag_velocity: float = 0.0
## Whether this drag has already taken the gesture from its slots. Latched so
## the cancel runs once, not on every motion event of the drag.
var _slots_cancelled: bool = false


func _ready() -> void:
	_ensure_nodes()
	_base_y = position.y
	# The drag listens on Body, NOT on this root. The root is a bare anchor
	# (authoring guide, Pattern C): anchors_preset = 0, no offsets, so its
	# rect is zero-sized and it can never be hit-tested. A _gui_input here
	# would never fire however its mouse_filter is set -- which is exactly
	# how the drag shipped broken on first write. Body carries the geometry.
	if is_instance_valid(_body) and not _body.gui_input.is_connected(_on_body_gui_input):
		_body.gui_input.connect(_on_body_gui_input)
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
	_layout_slots()
	var empty := entries.is_empty()
	_empty_state.visible = empty
	_hint.visible = not empty
	_total_label.text = "Total: %s koin" % format_koin(CART_SCRIPT.total_of(entries))


## Call BEFORE Cart.add_item(): the refresh that follows keeps the new unit
## hidden until land() says its flight has arrived.
func hold_for_landing(item_name: String) -> void:
	_held[item_name] = int(_held.get(item_name, 0)) + 1


## Inverse of hold_for_landing(): undoes a hold whose Cart.add_item() then
## failed (the per-frame cap dropped the unit), so the flight that would
## have called land() never spawns. Without this the held count would sit
## one too high forever, permanently hiding a future real unit of
## item_name behind a hold nothing will ever clear.
func release_hold(item_name: String) -> void:
	if _held.has(item_name):
		_held[item_name] -= 1
		if _held[item_name] <= 0:
			_held.erase(item_name)
	refresh(_entries)


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


## Where a released drag settles. `travel` is how far the tray has moved down
## from its docked position, `velocity` the release speed in px/s (positive =
## downward), `span` the full travel between docked and hidden. Returns a
## ViewState value.
##
## Pure on purpose: the runner cannot await, so the rule has to be checkable
## without a frame. end_drag() is the only caller at runtime.
static func classify_drag(travel: float, velocity: float, span: float) -> int:
	if absf(velocity) >= FLICK_VELOCITY:
		return ViewState.COLLAPSED if velocity > 0.0 else ViewState.EXPANDED
	if span <= 0.0:
		return ViewState.EXPANDED
	return ViewState.COLLAPSED if travel >= span * COMMIT_FRACTION else ViewState.EXPANDED


## Begins a drag at global y `at_y`. Kills any running slide first so a drag
## that interrupts a toggle takes over cleanly instead of fighting it.
func begin_drag(at_y: float) -> void:
	if is_instance_valid(_tray_tween) and _tray_tween.is_valid():
		_tray_tween.kill()
	_dragging = true
	_drag_from_y = at_y
	_drag_last_y = at_y
	_drag_last_msec = Time.get_ticks_msec()
	_drag_velocity = 0.0
	_slots_cancelled = false


## Moves the tray to follow a finger at global y `at_y`, clamped to the dock so
## a long drag can never fling it off screen.
func update_drag(at_y: float) -> void:
	if not _dragging:
		return
	var delta_y: float = at_y - _drag_from_y
	# Once the finger has clearly moved, the slots it started on let go: a
	# tap returns an item, so a drag that also counted as a tap would empty
	# the cart a unit at a time.
	if absf(delta_y) > DRAG_STEALS_AFTER and not _slots_cancelled:
		_slots_cancelled = true
		for item_name in _slots:
			var slot: TraySlot = _slots[item_name]
			if is_instance_valid(slot):
				slot.cancel_press()
	var start_y: float = _base_y + (tray_offset_collapsed \
		if _state == ViewState.COLLAPSED else 0.0)
	position.y = clampf(start_y + delta_y, _base_y, _base_y + tray_offset_collapsed)
	var now := Time.get_ticks_msec()
	var dt: float = maxf(float(now - _drag_last_msec) / 1000.0, 0.0001)
	_drag_velocity = (at_y - _drag_last_y) / dt
	_drag_last_y = at_y
	_drag_last_msec = now


## Ends a drag and settles the tray. The settle goes through set_state(), so
## the existing tween, emblem fade, badge rule, HeaderButton hit-test gate and
## state_changed signal all keep working untouched -- koprasi.gd's CrateHandle
## mirror needs no edit.
func end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var travel: float = position.y - _base_y
	var settled: int = classify_drag(travel, _drag_velocity, tray_offset_collapsed)
	if settled == _state:
		# set_state() no-ops on a repeat, which would leave the tray parked
		# mid-slide where the finger dropped it. Slide it home by hand.
		var home_y: float = _base_y + (tray_offset_collapsed \
			if _state == ViewState.COLLAPSED else 0.0)
		if not is_equal_approx(position.y, home_y):
			_tray_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tray_tween.tween_property(self, "position:y", home_y, 0.2)
		return
	set_state(settled, true)


## The drag gesture, received from Body (see _ready). TraySlot's root is
## MOUSE_FILTER_PASS, so a press that lands on an item reaches Body too and a
## drag can start from on top of the cart's contents -- which is where a
## thumb naturally falls. The slot still gets its own press; update_drag()
## takes the gesture off it once the finger passes DRAG_STEALS_AFTER.
func _on_body_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			begin_drag(button.global_position.y)
		else:
			end_drag()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		update_drag(motion.global_position.y)


## Flips between EXPANDED and COLLAPSED, animated.
func toggle() -> void:
	set_state(ViewState.COLLAPSED if _state == ViewState.EXPANDED else ViewState.EXPANDED)


## Slides the tray to state. A repeat of the current state is a no-op (no
## tween, no signal). animate=false snaps immediately -- used by _ready-time
## setup and by tests, which never advance a frame for a tween to run.
func set_state(state: int, animate: bool = true) -> void:
	if state == _state:
		return
	_state = state
	var target_y := _base_y + (tray_offset_collapsed if state == ViewState.COLLAPSED else 0.0)
	if is_instance_valid(_tray_tween) and _tray_tween.is_valid():
		_tray_tween.kill()
	if animate:
		_tray_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tray_tween.set_parallel(true)
		_tray_tween.tween_property(self, "position:y", target_y, 0.28)
	else:
		position.y = target_y
	state_changed.emit(state)


## True while the tray is docked on the shelf (not slid away).
func is_expanded() -> bool:
	return _state == ViewState.EXPANDED


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
	if not is_instance_valid(_body):
		_body = get_node_or_null("Body")
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
