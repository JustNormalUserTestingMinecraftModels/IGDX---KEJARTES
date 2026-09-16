@tool
extends PanelContainer
class_name WeekRecapPill

## One headline total on ResultCheckup's week banner: an icon, a number,
## and a ring pulse that fires as the number lands (2026-09-03 spec
## section 4).
##
## A template, instanced four times by WeekRecapBanner. It knows nothing
## about which total it is showing -- the banner supplies the icon, the
## formatted text and the tint -- so adding a fifth pill later needs no
## change here.
##
## @tool so the editor's test runner can instantiate and inspect it.

## Emitted after a clean press-then-release inside this pill's own rect.
## A release outside the rect (a drag-off) cancels the gesture silently --
## no signal, matching how a Button's own click-cancel behaves.
signal pill_tapped

## The pill's icon. Left null the pill still lays out; the icon slot
## simply renders empty.
@onready var icon: TextureRect = $Icon
## The formatted number. Tinted via self_modulate by set_pill, never by a
## font colour override.
@onready var value_label: Label = $Value
## The one-shot pulse fired when this pill's count-up lands.
@onready var ring: RewardParticles = $Ring

## True between a press inside this pill's rect and the matching release,
## however that release resolves. Distinguishes a genuine tap from a
## stray release event this pill never started.
var _is_pressed: bool = false


## Populate the pill. `tint` colours only the number, never the icon --
## the icon SVGs carry their own colour and multiplying them would muddy
## it.
func set_pill(icon_texture: Texture2D, value_text: String,
		tint: Color) -> void:
	if icon:
		icon.texture = icon_texture
	if value_label:
		value_label.text = value_text
		value_label.self_modulate = tint


## Count this pill's number up from zero after `delay`, pulsing the ring
## and ticking once as it lands. `formatter` turns the running float into
## the pill's own text, so the money pill groups thousands and the poin
## pill signs itself without this script knowing the difference.
##
## A coroutine -- never call it from a test; the runner does not await.
func play_count_up(to_value: float, formatter: Callable,
		delay: float = 0.0) -> void:
	if Engine.is_editor_hint():
		return
	Juice.count_up_formatted(value_label, 0.0, to_value, formatter, delay)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	AudioDirector.play_sfx(&"tally")
	if ring:
		ring.fire()


## Tap detection: press starts the pressed-feel and arms the gesture;
## release either fires pill_tapped (inside the rect) or just resolves
## the pressed-feel (outside it, a cancelled drag-off). Requires
## mouse_filter = STOP on the root, set in the .tscn.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_is_pressed = true
		Juice.press(self)
	elif _is_pressed:
		_is_pressed = false
		Juice.release(self)
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			pill_tapped.emit()
