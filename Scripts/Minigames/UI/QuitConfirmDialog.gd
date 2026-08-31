@tool
class_name QuitConfirmDialog
extends CanvasLayer

## The "are you sure you want to quit" confirmation shown from a minigame's
## pause menu.
##
## Instantiated by Scripts/Minigames/UI/BaseMinigame.gd, which previously
## built this whole CanvasLayer/backdrop/card/message/buttons hierarchy by
## hand every time it was shown. Every @export BaseMinigame already had for
## it is still honoured -- configure() takes the same values and applies them
## the same way.
##
## Affects: nothing outside itself. Emits `confirmed` or `cancelled`; the
## caller decides what that means (abandon_game() / re-show the pause menu).
##
## @tool so the scene previews in the editor.

## Emitted when the player confirms quitting (after the button-boing
## animation finishes).
signal confirmed
## Emitted when the player backs out.
signal cancelled

@onready var backdrop: TextureRect = $Backdrop
@onready var card: PanelContainer = $Center/Card
@onready var message_label: Label = $Center/Card/Margin/Layout/MessageLabel
@onready var yes_button: Button = $Center/Card/Margin/Layout/Buttons/YesButton
@onready var no_button: Button = $Center/Card/Margin/Layout/Buttons/NoButton

## A 1x1 white texture, generated once, so `backdrop` can show a flat
## `bg_color` fill via modulate when no @export texture is supplied -- the
## same visual result as the shipped ColorRect fallback, without needing a
## second node type.
var _solid_white: Texture2D = null


func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)


func _solid_white_texture() -> Texture2D:
	if _solid_white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_solid_white = ImageTexture.create_from_image(img)
	return _solid_white


## Fill the dialog from BaseMinigame's quit-dialog @exports.
##
## Affects: this dialog's own nodes only. `card_texture` swaps the card to a
## StyleBoxTexture; otherwise it stays a flat StyleBoxFlat built from
## `card_color` / `card_border_color` -- both are @export-driven, so this is
## the one place in this refactor a runtime stylebox is still built, because
## no baked theme variation can anticipate an artist-supplied texture.
func configure(message: String, yes_text: String, no_text: String,
		bg_texture: Texture2D, bg_color: Color,
		card_texture: Texture2D, card_color: Color, card_border_color: Color,
		yes_button_texture: Texture2D, no_button_texture: Texture2D,
		font: Font, font_size: int, font_color: Color) -> void:
	backdrop.texture = bg_texture if bg_texture != null else _solid_white_texture()
	backdrop.modulate = bg_color

	if card_texture:
		var sb := StyleBoxTexture.new()
		sb.texture = card_texture
		card.add_theme_stylebox_override("panel", sb)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = card_color
		style.set_corner_radius_all(24)
		style.set_border_width_all(4)
		style.border_color = card_border_color
		card.add_theme_stylebox_override("panel", style)

	message_label.text = message
	message_label.add_theme_font_size_override("font_size", font_size)
	message_label.add_theme_color_override("font_color", font_color)
	if font:
		message_label.add_theme_font_override("font", font)

	yes_button.text = "" if yes_button_texture else yes_text
	if yes_button_texture:
		var sb_yes := StyleBoxTexture.new()
		sb_yes.texture = yes_button_texture
		yes_button.add_theme_stylebox_override("normal", sb_yes)
		yes_button.add_theme_stylebox_override("hover", sb_yes)
		yes_button.add_theme_stylebox_override("pressed", sb_yes)

	no_button.text = "" if no_button_texture else no_text
	if no_button_texture:
		var sb_no := StyleBoxTexture.new()
		sb_no.texture = no_button_texture
		no_button.add_theme_stylebox_override("normal", sb_no)
		no_button.add_theme_stylebox_override("hover", sb_no)
		no_button.add_theme_stylebox_override("pressed", sb_no)


## Punch the button, then emit `confirmed`. Does not free this node --
## BaseMinigame owns that, matching the shipped teardown order (it also
## frees the pause menu and clears is_paused before the caller sees this).
func _on_yes_pressed() -> void:
	_play_button_boing(yes_button, func(): confirmed.emit())


## Punch the button, then emit `cancelled`.
func _on_no_pressed() -> void:
	_play_button_boing(no_button, func(): cancelled.emit())


## The same four-step squash tween BaseMinigame._play_button_boing used,
## kept local so this scene has no other runtime dependency on BaseMinigame.
func _play_button_boing(btn: Button, on_complete: Callable) -> void:
	if not btn or not is_instance_valid(btn):
		if on_complete.is_valid(): on_complete.call()
		return

	btn.pivot_offset = btn.size / 2.0
	var tween := get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	tween.tween_property(btn, "scale", Vector2(1.22, 0.75), 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.82, 1.28), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.08, 0.92), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.09)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	if on_complete.is_valid():
		tween.tween_callback(on_complete)
