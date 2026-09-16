@tool
class_name WeekRecapPillInfoPopup
extends CanvasLayer

## The explainer a player gets by tapping a headline pill on
## ResultCheckup's week recap banner (2026-09-03 interactivity spec,
## section 3.3).
##
## Structurally a smaller sibling of Scenes/UI/StatDetailPopup.tscn: same
## scrim+card shell, same tap-anywhere-on-scrim-to-close behaviour, same
## open()/close() timing shape. No StatBar and no numeric value line --
## unlike a student's stat, a pill has no 0-100 value to visualize, just
## an icon, a title, and one sentence of explanation.
##
## Affects: nothing outside itself. Plays two SFX through AudioDirector
## and emits `closed` when its exit animation finishes. Never writes
## GameState.
##
## @tool so the scene previews correctly in the editor. _ready() only
## caches node references and wires signals -- both are safe in an
## editor session -- so nothing here needs an Engine.is_editor_hint()
## guard.

## Emitted after the close animation finishes and this node has been
## freed from the tree.
signal closed

## How long the scrim takes to fade in behind the card.
@export var scrim_fade_in_seconds: float = 0.22
## How long the card takes to slide off the bottom edge on close.
@export var close_slide_seconds: float = 0.26
## How long the scrim takes to fade back out on close.
@export var scrim_fade_out_seconds: float = 0.22

@onready var scrim: ColorRect = $Scrim
@onready var card: PanelContainer = $Scrim/Card
@onready var icon_rect: TextureRect = $Scrim/Card/Layout/Header/IconRect
@onready var title_label: Label = $Scrim/Card/Layout/Header/TitleLabel
@onready var close_button: Button = $Scrim/Card/Layout/Header/CloseButton
@onready var body_label: Label = $Scrim/Card/Layout/BodyLabel

## Guards against a double close: the exit tween and the scrim tap can
## both fire, and freeing twice crashes.
var _is_closing: bool = false


func _ready() -> void:
	scrim.color = _scrim_color(0.0)
	close_button.pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_input)


## The project's modal scrim at a given opacity. `alpha_scale` of 0 gives
## the same hue at zero opacity, which is what the fades tween from and
## back to -- tweening between two different hues would flash mid-fade.
func _scrim_color(alpha_scale: float = 1.0) -> Color:
	var c := DesignTokens.load_default().scrim_color()
	c.a *= alpha_scale
	return c


## Fill the icon, title, and body from one pill's fixed copy. Call before
## adding the popup to the tree, or immediately after -- it needs the
## @onready references, so it must run inside the tree.
func configure(icon: Texture2D, title: String, body: String) -> void:
	icon_rect.texture = icon
	title_label.text = title
	body_label.text = body


## Reveal: place the card above the bottom edge, pop it in, fade the
## scrim up. A coroutine because the card's height is only known after
## one layout pass. Callers must NOT await it -- fire and forget.
func open() -> void:
	AudioDirector.play_sfx(&"pill_popup_open")
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
func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	AudioDirector.play_sfx(&"pill_popup_close")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "position:y", vp.y, close_slide_seconds)
	tw.tween_property(scrim, "color", _scrim_color(0.0), scrim_fade_out_seconds)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


## Tapping anywhere on the scrim dismisses, matching StatDetailPopup.
func _on_scrim_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		close()
