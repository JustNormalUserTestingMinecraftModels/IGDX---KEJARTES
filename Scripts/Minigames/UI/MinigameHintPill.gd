@tool
class_name MinigameHintPill
extends PanelContainer

## The sports minigames' floating hint (spec 2026-09-29 minigame mobile
## layout, 3.3): a translucent pill anchored bottom-centre, level with the
## tray's hint in the button games, with an optional picture (MainBola's
## swipe-up). It ignores taps so every gesture reaches the game's _input.
##
## Affects: only its own children. BaseMinigame calls set_hint() / settle().

## The hint's alpha after the first successful action (ours; spec 6).
const SETTLED_ALPHA := 0.6

## The hint line.
@export var hint_text: String = "":
	set(value):
		hint_text = value
		_apply_exports()
## Optional picture left of the text; null hides the Icon.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply_exports()


func _ready() -> void:
	_apply_exports()


## Show `text` at full strength.
func set_hint(text: String) -> void:
	hint_text = text
	var label := get_node_or_null("%HintLabel") as Label
	if label != null:
		label.modulate.a = 1.0


## Fade the text to SETTLED_ALPHA; it never hides.
func settle() -> void:
	var label := get_node_or_null("%HintLabel") as Label
	if label == null:
		return
	if Engine.is_editor_hint():
		label.modulate.a = SETTLED_ALPHA
	else:
		label.create_tween().tween_property(label, "modulate:a", SETTLED_ALPHA,
			Juice.tokens().dur_normal)


func _apply_exports() -> void:
	if not is_node_ready():
		return
	(%HintLabel as Label).text = hint_text
	var icon := %Icon as TextureRect
	icon.texture = icon_texture
	icon.visible = icon_texture != null
