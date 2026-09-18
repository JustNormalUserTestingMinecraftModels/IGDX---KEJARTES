@tool
extends Node

## Gives one koperasi shelf item its life: a soft shadow on the plank, a
## slow idle bob at a per-item phase offset so the shelf never pulses in
## unison, a lift when pressed, and a dim when the player cannot afford it.
##
## Attached as a child helper of a shelf TextureButton rather than as that
## button's own script, so the shop's existing press wiring is untouched.

## Vertical travel of the idle bob, in pixels.
@export var bob_distance: float = 6.0

## Seconds for one full bob cycle.
@export var bob_period: float = 2.4

## How far the item rises when pressed, in pixels.
@export var lift_distance: float = 10.0

## Seconds the lift takes to rise, and again to settle.
@export var lift_duration: float = 0.16

## Opacity applied when the item is unaffordable.
@export var dim_alpha: float = 0.55

## Opacity applied to the shelf button while a tap is locked in (ghost
## feedback), so a mashed slot visibly registers the tap instead of looking
## unresponsive.
@export var locked_alpha: float = 0.6

## Failsafe: on_tap() unlocks after this many seconds even if
## on_flight_finished() never arrives (e.g. a scene change mid-flight).
const FLIGHT_TIMEOUT: float = 0.6

## Peak opacity of the gold rim glow behind the item while it is lifted.
@export var glow_alpha: float = 0.85

## Shadow texture laid under the item on the shelf plank.
@export var shadow_texture: Texture2D = preload("res://Assets/Images/UI/Placeholders/shadow_ellipse.png")

var _button: TextureButton
var _shadow: TextureRect
var _phase: float = 0.0
var _base_y: float = 0.0
var _glow: CanvasItem

## True while lift()'s tween owns _button.position.y -- _process must not
## write the bob over it, or the lift is invisible (the bob wins every frame).
var _lifting: bool = false

## Third safeguard layer (shelf debounce): true from a successful on_tap()
## until on_flight_finished() or the FLIGHT_TIMEOUT failsafe clears it.
## While true, on_tap() refuses further taps on this slot.
var _locked: bool = false

## Last value passed to set_dimmed(), so _unlock() (and on_tap's ghost)
## restore the AFFORDABILITY dim rather than always snapping back to full
## opacity -- otherwise a slot that went unaffordable mid-flight (or was
## already unaffordable when tapped) would read as buyable again the moment
## the lock lifts, even though the button is still not tappable at that price.
var _dimmed: bool = false

## Wires this helper to a shelf button: adds the shadow, records the
## resting position, and picks a random bob phase.
func attach_to(button: TextureButton) -> void:
	_button = button
	_base_y = button.position.y
	_phase = randf() * TAU

	if shadow_texture and not is_instance_valid(_shadow):
		_shadow = TextureRect.new()
		_shadow.texture = shadow_texture
		_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow.modulate.a = 0.35
		_shadow.size = Vector2(button.size.x * 0.8, 18.0)
		_shadow.position = Vector2(button.size.x * 0.1, button.size.y - 6.0)
		button.add_child(_shadow)
		button.move_child(_shadow, 0)

	_glow = button.get_node_or_null("Glow")
	if is_instance_valid(_glow):
		_glow.self_modulate = DesignTokens.load_default().currency_gold
		_glow.modulate.a = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_button) or _lifting:
		return
	_phase += delta * TAU / bob_period
	_button.position.y = _base_y + sin(_phase) * bob_distance

## Rises and settles, for the moment the item is bought, with a gold rim glow
## that swells on the way up and fades on the way down. Suspends the idle bob
## for the duration so the tween isn't stomped by _process every frame.
## Returns the tween, so tests can step it.
func lift() -> Tween:
	if not is_instance_valid(_button):
		return null
	_lifting = true
	var tween := _button.create_tween()
	tween.tween_property(_button, "position:y", _base_y - lift_distance, lift_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_glow):
		tween.parallel().tween_property(_glow, "modulate:a", glow_alpha, lift_duration)
	tween.tween_property(_button, "position:y", _base_y, lift_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(_glow):
		tween.parallel().tween_property(_glow, "modulate:a", 0.0, lift_duration)
	tween.tween_callback(_on_lift_finished)
	return tween

## Clears the lift lock and pins the button back to its resting y so the
## bob resumes from _base_y rather than wherever the tween stopped.
func _on_lift_finished() -> void:
	_lifting = false
	if is_instance_valid(_button):
		_button.position.y = _base_y

## Called by rakbarang_1.gd's press handler before it acts on a shelf tap.
## Returns false (and does nothing) while already locked, so a second tap
## landing before the first's flight lands is silently ignored. On success,
## ghosts the button to locked_alpha and arms the FLIGHT_TIMEOUT failsafe --
## the caller must still call on_flight_finished() itself once the flight
## tween ends, on every path (including an early return), or the slot would
## otherwise sit ghosted for up to FLIGHT_TIMEOUT for no visible reason.
func on_tap() -> bool:
	if _locked:
		return false
	_locked = true
	if is_instance_valid(_button):
		_button.modulate.a = locked_alpha
	if is_inside_tree():
		get_tree().create_timer(FLIGHT_TIMEOUT).timeout.connect(_on_flight_timeout)
	return true

## The flight tween landed (or the caller bailed out after a successful
## on_tap()): release the lock immediately rather than waiting on the
## failsafe timer.
func on_flight_finished() -> void:
	_unlock()

## The FLIGHT_TIMEOUT failsafe fired. Godot auto-disconnects a signal whose
## connected object was freed, so this only ever runs on a live instance --
## still guarded for safety since the scene can change mid-flight.
func _on_flight_timeout() -> void:
	if not is_instance_valid(self):
		return
	_unlock()

func _unlock() -> void:
	_locked = false
	if is_instance_valid(_button):
		_button.modulate.a = dim_alpha if _dimmed else 1.0

## Fades the item when its price is out of reach.
func set_dimmed(dim: bool) -> void:
	_dimmed = dim
	if not is_instance_valid(_button):
		return
	if _locked:
		return
	_button.modulate.a = dim_alpha if dim else 1.0

## Sets the stock-pip badge under the shelf button: `total` copies of this
## slot's item are on this week's shelf, `remaining` of them still unsold
## and uncarted. Looks up PipRow -- a static HBoxContainer of Pip1..Pip3
## authored as a sibling of this helper, under the button, in koprasi.tscn
## -- rather than building anything at runtime. Each PipN shows while
## `i < total` and carries a "Fill" child shown while `i < remaining`, so a
## hollow dot (Fill hidden) reads as sold/carted and a hidden PipN reads as
## never on the shelf at all (an item stocked only once or twice).
func set_stock_pips(remaining: int, total: int) -> void:
	if not is_instance_valid(_button):
		return
	var row: Node = _button.get_node_or_null("PipRow")
	if row == null:
		return
	for i in range(row.get_child_count()):
		var pip: CanvasItem = row.get_child(i)
		pip.visible = i < total
		var fill: CanvasItem = pip.get_node_or_null("Fill")
		if fill != null:
			fill.visible = i < remaining
