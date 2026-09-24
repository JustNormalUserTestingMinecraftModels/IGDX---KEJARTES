@tool
extends Control

## The full-screen "something is about to happen" warning (2026-09-12
## event-cards spec, section 2; redesigned as a school news announcement in
## the 2026-09-24 SchoolDay liveliness pass, layer 7). The panel slides in
## from the right edge, holds, and leaves through the left.
##
## On it: the megaphone pops in and wiggles, and a single caution-tape band
## rolls in carrying a marker -- the event's KATEGORI and its MODE (MINIGAME,
## KABAR, or PILIHAN for the choice events, which warns that Tolak / Terima is
## coming) -- over the title, which types in. The ground behind is a diagonal
## gradient in the event's category colour (Akademis blue, Olahraga red, Seni
## Budaya green; Cuaca storm grey, Sosial warm amber), so the colour says what
## kind of event it is at a glance. With no category it keeps the flat panel.
##
## It fronts both kinds of mid-day interruption: the minigames and the random
## events. Everything is authored in the scene; the script only moves it,
## sets its words and recolours the gradient.

## The megaphone art on the panel. Swappable from the Inspector.
@export var icon_texture: Texture2D = preload("res://Assets/Images/SchoolDay/eventwarning_icon.png"):
	set(v):
		icon_texture = v
		if is_node_ready():
			icon.texture = v
## Seconds the panel takes to cover the screen from the right edge.
@export_range(0.05, 2.0, 0.01) var slide_in_duration: float = 0.35
## Seconds the panel rests on screen with the icon and caption showing.
@export_range(0.1, 5.0, 0.05) var hold_duration: float = 1.1
## Seconds the panel takes to leave through the left edge.
@export_range(0.05, 2.0, 0.01) var slide_out_duration: float = 0.35
## Seconds the caution band takes to roll out to full width.
@export_range(0.05, 1.0, 0.01) var band_roll_duration: float = 0.28
## Seconds the title takes to type in, inside the hold.
@export_range(0.05, 1.0, 0.01) var type_duration: float = 0.45
## How fast the tape's stripes scroll, px per second.
@export_range(0.0, 400.0, 1.0) var stripe_speed: float = 90.0

## Width of one repeat of the tape texture: the stripes wrap every this many
## px, so the scroll never jumps.
const STRIPE_PERIOD := 64.0
## How far the megaphone wiggles as the notice lands, px.
const WIGGLE_PX := 10.0
## The marker's word for each category the notice can carry.
const CATEGORY_WORDS := {
	"Akademis": "AKADEMIS",
	"SeniBudaya": "SENI BUDAYA",
	"Olahraga": "OLAHRAGA",
	"Cuaca": "CUACA",
	"Sosial": "SOSIAL",
}

@onready var panel: Panel = $Panel
@onready var gradient_rect: TextureRect = $Panel/Gradient
@onready var icon: TextureRect = $Panel/Center/Content/Icon
@onready var band: Control = $Panel/Center/Content/Band
@onready var marker: Label = $Panel/Center/Content/Band/Rows/Marker
@onready var caption: Label = $Panel/Center/Content/Band/Rows/Caption
@onready var tape_top: Control = $Panel/Center/Content/Band/Rows/TapeTop/Stripes
@onready var tape_bottom: Control = $Panel/Center/Content/Band/Rows/TapeBottom/Stripes

var _stripe_x := 0.0


func _ready() -> void:
	icon.texture = icon_texture
	if Engine.is_editor_hint():
		return
	panel.position.x = panel_x(&"enter", size.x)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or GameSettings.reduce_motion or tape_top == null:
		return
	_stripe_x = fposmod(_stripe_x + stripe_speed * delta, STRIPE_PERIOD)
	# The two tapes run opposite ways, like the police-line tape they mimic.
	tape_top.position.x = -_stripe_x
	tape_bottom.position.x = -STRIPE_PERIOD + _stripe_x


## Where the panel's left edge sits at each stage of the pass, for a screen
## `width` wide: off the right edge, resting, off the left edge.
static func panel_x(stage: StringName, width: float) -> float:
	match stage:
		&"enter":
			return width
		&"exit":
			return -width
		_:
			return 0.0


## "AKADEMIS · PILIHAN": the band's marker for a category and a mode. Either
## half may be missing. Set in the body face, which carries the "·".
static func marker_text(category: String, mode: String) -> String:
	var parts: Array[String] = []
	var word: String = CATEGORY_WORDS.get(category, "")
	if word != "":
		parts.append(word)
	if mode != "":
		parts.append(mode)
	return " · ".join(parts)


## The gradient's three stops for a category, deep to light: the skill
## categories take their own colour and its on-dark variant; Cuaca and Sosial
## are not skill categories, so they take neutral storm grey and warm amber
## rather than borrowing a skill's colour. Empty for anything else.
static func gradient_colors(category: String, tokens: DesignTokens) -> Array[Color]:
	var mid: Color
	var light: Color
	match category:
		"Akademis", "SeniBudaya", "Olahraga":
			mid = tokens.category_color(category)
			light = tokens.category_color_on_dark(category)
		"Cuaca":
			mid = Color.SLATE_GRAY
			light = Color.SLATE_GRAY.lightened(0.3)
		"Sosial":
			mid = tokens.state_warning.darkened(0.35)
			light = tokens.state_warning
		_:
			return []
	return [mid.darkened(0.7), mid, light]


func _apply_gradient(category: String) -> void:
	var colors := gradient_colors(category, DesignTokens.load_default())
	gradient_rect.visible = not colors.is_empty()
	var tex := gradient_rect.texture as GradientTexture2D
	if colors.is_empty() or tex == null or tex.gradient == null:
		return
	for i in colors.size():
		tex.gradient.set_color(i, colors[i])


## Slide through the screen once showing `caption_text`, marked with the
## event's `category` and `mode`, then free. Awaitable: SchoolDay waits on it
## before the minigame or event begins.
func play_warning(caption_text: String, category: String = "", mode: String = "") -> void:
	caption.text = caption_text
	marker.text = marker_text(category, mode)
	marker.visible = marker.text != ""
	_apply_gradient(category)
	AudioDirector.play_sfx(&"event_announce")
	var width := size.x
	panel.position.x = panel_x(&"enter", width)
	icon.modulate.a = 0.0
	caption.modulate.a = 0.0
	# Hidden through the slide; the roll starts once the panel has landed.
	band.modulate.a = 0.0

	var slide_in := create_tween()
	slide_in.tween_property(panel, "position:x", panel_x(&"rest", width), slide_in_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide_in.finished

	Juice.pop_in(icon)
	Juice.fade_in(caption)
	# The band is a container child, and a container resets its children's
	# scale whenever it sorts -- setting the caption queues one. So the roll
	# starts from zero here, after that sort has run, not before the slide.
	band.pivot_offset = band.size * 0.5
	band.scale.x = 0.0
	band.modulate.a = 1.0
	var roll := create_tween()
	roll.tween_property(band, "scale:x", 1.0, band_roll_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if GameSettings.reduce_motion:
		caption.visible_ratio = 1.0
	else:
		caption.visible_ratio = 0.0
		roll.tween_property(caption, "visible_ratio", 1.0, type_duration)
		# The megaphone wiggles as the notice lands.
		roll.parallel().tween_callback(Juice.shake.bind(icon, WIGGLE_PX))
	await get_tree().create_timer(hold_duration).timeout

	var slide_out := create_tween()
	slide_out.tween_property(panel, "position:x", panel_x(&"exit", width), slide_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await slide_out.finished
	queue_free()
