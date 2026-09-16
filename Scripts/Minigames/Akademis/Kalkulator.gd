@tool
extends AspectRatioContainer

## The drawn calculator: body art, a live LCD, and an authored key field.
##
## The root is an AspectRatioContainer at the body texture's own ratio, so
## the calculator keeps the artwork's proportions and centres itself in
## whatever slot the game scene gives it -- including the taller slot a 20:9
## phone produces.
##
## Every key is an authored KalkulatorKey.tscn instance. Nothing here is
## built at runtime; the script only relays presses and toggles state.
##
## @tool so show_zero_key previews in the editor. Its _ready() touches only
## its own visuals, so no Engine.is_editor_hint() guard is needed.

## Emitted when any key is pressed, carrying that key's character.
signal digit_pressed(digit: String)

## Shows the wide 0 key under the 1-9 grid. Password's answers run to three
## digits and need it; Variabel's are always 1-9 and it stays hidden there,
## leaving the plain body space the mockup draws.
@export var show_zero_key: bool = true:
	set(value):
		show_zero_key = value
		var row := get_node_or_null("Body/ZeroRow") as Control
		if row:
			row.visible = value

## What the LCD reads before the player types anything.
@export var layar_placeholder: String = "0"

## Colour of the digits on the green LCD. Dark, so they read like a real
## segment display rather than glowing.
@export var layar_color: Color = Color(0.13, 0.16, 0.12, 1.0)

@onready var layar: Label = $Body/Layar

func _ready() -> void:
	show_zero_key = show_zero_key
	if layar:
		layar.add_theme_color_override("font_color", layar_color)
		layar.text = layar_placeholder
	for key in _keys():
		# By name: the loop variable is typed Node, which has no key_pressed.
		key.connect("key_pressed", func(d: String): digit_pressed.emit(d))

## Every authored key, in tree order.
func _keys() -> Array[Node]:
	return find_children("*", "Button", true, false)

## Shows `text` on the LCD, or the placeholder when it is empty.
func set_layar(text: String) -> void:
	if layar:
		layar.text = text if text != "" else layar_placeholder

## Recolours the LCD digits -- green on a correct answer, red on a wrong one.
func set_layar_color(c: Color) -> void:
	if layar:
		layar.add_theme_color_override("font_color", c)

## Restores the LCD's authored digit colour.
func reset_layar_color() -> void:
	set_layar_color(layar_color)

## Locks or unlocks every key at once, while an answer is being judged.
func set_keys_disabled(disabled: bool) -> void:
	for key in _keys():
		(key as Button).disabled = disabled
