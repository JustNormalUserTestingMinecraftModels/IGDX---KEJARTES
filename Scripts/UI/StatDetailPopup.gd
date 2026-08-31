@tool
class_name StatDetailPopup
extends CanvasLayer


## The stat-detail modal a player gets by tapping a bar on a student card.
##
## Instantiated by Scripts/ReportCard/report_card.gd and
## Scripts/StudentCard/student_card.gd, which previously each carried their
## own verbatim copy of this as 168 lines of runtime construction. Every node
## it draws now lives in Scenes/UI/StatDetailPopup.tscn, so the layout is
## editable in the 2D viewport.
##
## Affects: nothing outside itself. It reads a student dictionary, plays two
## SFX through AudioDirector, and emits `closed` when it finishes its exit
## animation. It never writes GameState.
##
## @tool so the scene previews correctly in the editor. _ready() only caches
## node references and wires signals -- both are safe in an editor session --
## so nothing here needs an Engine.is_editor_hint() guard.

## Emitted after the close animation finishes and this node has been freed
## from the tree. Callers use it to re-show whatever they hid.
signal closed

## How long the scrim takes to fade in behind the card.
@export var scrim_fade_in_seconds: float = 0.22
## How long the card takes to slide off the bottom edge on close.
@export var close_slide_seconds: float = 0.26
## How long the scrim takes to fade back out on close.
@export var scrim_fade_out_seconds: float = 0.22

@onready var scrim: ColorRect = $Scrim
@onready var card: PanelContainer = $Scrim/Card
@onready var icon_rect: TextureRect = $Scrim/Card/Layout/Header/Row/IconRect
@onready var glyph_label: Label = $Scrim/Card/Layout/Header/Row/GlyphLabel
@onready var category_label: Label = $Scrim/Card/Layout/Header/Row/Titles/CategoryLabel
@onready var name_label: Label = $Scrim/Card/Layout/Header/Row/Titles/NameLabel
@onready var close_button: Button = $Scrim/Card/Layout/Header/Row/CloseButton
@onready var value_label: Label = $Scrim/Card/Layout/Body/BodyLayout/ValueLabel
@onready var bar: StatBar = $Scrim/Card/Layout/Body/BodyLayout/Bar
@onready var description_label: Label = $Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel

## Guards against a double close: the exit tween and the scrim tap can both
## fire, and freeing twice crashes.
var _is_closing: bool = false


func _ready() -> void:
	scrim.color = _scrim_color(0.0)
	close_button.pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_input)


## The project's modal scrim at a given opacity. `alpha_scale` of 0 gives the
## same hue at zero opacity, which is what the fades tween from and back to --
## tweening between two different hues would flash mid-fade.
func _scrim_color(alpha_scale: float = 1.0) -> Color:
	var c := DesignTokens.load_default().scrim_color()
	c.a *= alpha_scale
	return c


## Fill every label and the bar from one entry of StatInfo.BARS.
## Call before adding the popup to the tree, or immediately after -- it needs
## the @onready references, so it must run inside the tree.
##
## `icon` is the screen's own artwork for this bar (report_card and
## student_card each carry their own @export'd icon set). Pass null to fall
## back to the emoji glyph from StatInfo.
##
## Affects: this popup's own nodes only.
func configure(bar_name: String, s_data: Dictionary, icon: Texture2D) -> void:
	var info := StatInfo.get_bar(bar_name)
	if info.is_empty():
		# An unknown bar name means a caller typo. Show an empty popup rather
		# than taking the screen down.
		category_label.text = ""
		name_label.text = ""
		value_label.text = ""
		description_label.text = ""
		icon_rect.visible = false
		glyph_label.visible = false
		return

	var value := StatInfo.value_of(bar_name, s_data)

	category_label.text = info["category_label"]
	name_label.text = info["display_name"]
	description_label.text = info["description"]
	value_label.text = "%s: %d / %d" % [
		String(info["display_name"]).to_upper(), int(value), int(bar.max_value)]

	# Exactly one of the two icon paths shows. The texture wins when the
	# screen supplied one; the emoji is the fallback the old code used.
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	glyph_label.text = info["glyph"]
	glyph_label.visible = icon == null

	bar.category = info["token_category"]
	bar.set_stat(value, false)


## Play the reveal: place the card above the bottom edge, pop it in, fade the
## scrim up. A coroutine because the card's height is only known after one
## layout pass. Callers must NOT await it -- fire and forget.
##
## Affects: this popup's nodes, and plays the popup_open SFX.
func open() -> void:
	AudioDirector.play_sfx(&"popup_open")
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	card.position = Vector2(
		(vp.x - card.size.x) * 0.5,
		vp.y - card.size.y - float(DesignTokens.load_default().space_md))
	Juice.pop_in(card)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(scrim, "color", _scrim_color(), scrim_fade_in_seconds)


## Slide the card out, fade the scrim, free this node, emit `closed`.
## Safe to call twice; the second call is ignored.
##
## Affects: frees this node. Plays the popup_close SFX.
func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	AudioDirector.play_sfx(&"popup_close")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "position:y", vp.y, close_slide_seconds)
	tw.tween_property(scrim, "color", _scrim_color(0.0), scrim_fade_out_seconds)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


## Tapping anywhere on the scrim dismisses, matching the shipped behaviour.
func _on_scrim_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		close()

