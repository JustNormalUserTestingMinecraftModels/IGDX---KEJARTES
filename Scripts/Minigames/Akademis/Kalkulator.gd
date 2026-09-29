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
##
## Keypad geometry (2026-09-30, minigame hierarchy B3): the body art
## (kalkulator_base.png, 1080x1487) paints no key wells, only a flat keypad
## face and an LCD glass. The constants below are those two rects, measured
## as fractions of the body; _apply_keypad_layout() centres the key block on
## the face and fits the display to the glass, so the keys no longer sit
## 29 texture px left of the face's centre, and the 0 row stays off the rim.

## Emitted when any key is pressed, carrying that key's character.
signal digit_pressed(digit: String)

## The painted keypad face, as fractions of the body (measured 2026-09-30).
const FACE_RECT := Rect2(0.0537, 0.2751, 0.9259, 0.7061)
## The LCD glass, as fractions of the body.
const GLASS_RECT := Rect2(0.0963, 0.0935, 0.8074, 0.1560)
## The key block's left and right edges: centred on the face (0.5167) and
## wide enough that key 1 covers most of a stray painted key outline at the
## art's top left (about 0.051-0.275 x 0.293-0.468; logged for the artist).
const KEYPAD_LEFT := 0.085
const KEYPAD_RIGHT := 0.948
## The key block's top, just under the LCD bezel.
const KEYPAD_TOP := 0.300
## The 1-9 grid's bottom while the 0 row shows, and the 0 row's top.
const GRID_BOTTOM := 0.787
const ZERO_TOP := 0.807
## The key block's bottom, inside the face and clear of the rim.
const KEYPAD_BOTTOM := 0.955

## Shows the wide 0 key under the 1-9 grid. Password's answers run to three
## digits and need it; Variabel's are always 1-9 and it stays hidden there,
## leaving the plain body space the mockup draws.
@export var show_zero_key: bool = true:
	set(value):
		show_zero_key = value
		var row := get_node_or_null("Body/ZeroRow") as Control
		if row:
			row.visible = value
		_apply_keypad_layout()

## What the LCD reads before the player types anything.
@export var layar_placeholder: String = "0"

## Colour of the digits on the green LCD. Dark, so they read like a real
## segment display rather than glowing. The same ink MinigameLcdLabel bakes.
@export var layar_color: Color = ThemeFactory.MINIGAME_LCD_INK

@onready var layar: Label = $Body/Layar

func _ready() -> void:
	show_zero_key = show_zero_key
	if layar:
		layar.add_theme_color_override("font_color", layar_color)
		layar.text = layar_placeholder
	for key in _keys():
		# By name: the loop variable is typed Node, which has no key_pressed.
		key.connect("key_pressed", func(d: String): digit_pressed.emit(d))

## Places the key block and the display on the measured art: the grid and
## the 0 row between KEYPAD_LEFT and KEYPAD_RIGHT, the display on the glass.
## Without the 0 row the grid takes its height down to KEYPAD_BOTTOM.
func _apply_keypad_layout() -> void:
	var grid := get_node_or_null("Body/KeyGrid") as Control
	var zero := get_node_or_null("Body/ZeroRow") as Control
	var lcd := get_node_or_null("Body/Layar") as Control
	if grid == null or zero == null or lcd == null:
		return
	var grid_bottom := GRID_BOTTOM if show_zero_key else KEYPAD_BOTTOM
	_set_rect(grid, Rect2(KEYPAD_LEFT, KEYPAD_TOP, KEYPAD_RIGHT - KEYPAD_LEFT,
		grid_bottom - KEYPAD_TOP))
	_set_rect(zero, Rect2(KEYPAD_LEFT, ZERO_TOP, KEYPAD_RIGHT - KEYPAD_LEFT,
		KEYPAD_BOTTOM - ZERO_TOP))
	lcd.anchor_left = GLASS_RECT.position.x
	lcd.anchor_right = GLASS_RECT.end.x
	lcd.anchor_top = GLASS_RECT.position.y
	lcd.anchor_bottom = GLASS_RECT.end.y


## Anchors `node` to `frac` of the body with no offsets.
static func _set_rect(node: Control, frac: Rect2) -> void:
	node.anchor_left = frac.position.x
	node.anchor_top = frac.position.y
	node.anchor_right = frac.end.x
	node.anchor_bottom = frac.end.y
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


## Keeps `target`'s minimum width equal to the calculator body's, now and on
## every resize, so the question card above shares the calculator's column
## (spec 2026-09-30 minigame hierarchy, H6).
func follow_width(target: Control) -> void:
	var body := $Body as Control
	target.custom_minimum_size.x = body.size.x
	body.resized.connect(func() -> void:
		if is_instance_valid(target):
			target.custom_minimum_size.x = body.size.x)


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
