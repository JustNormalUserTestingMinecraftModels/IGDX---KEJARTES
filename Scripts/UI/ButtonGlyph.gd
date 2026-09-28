@tool
extends TextureRect

## A picture drawn on a lipped button as its child (the paging arrows'
## `Arrow`, UI depth pass Phase 3) that behaves like the button's own icon:
## held, it drops with the face by exactly as much as the button's label
## would; disabled, it dims. A child is used instead of the Button `icon`
## because the size steps' content margins squeeze an icon to ~15 px.
##
## Nothing here builds a visual. It only nudges this node's authored offsets
## and alpha, and only in the running game -- in the editor the offsets stay
## as authored, so a scene save never bakes a held state in.

## How opaque the picture is while its button is disabled; Godot's own
## default for a disabled Button icon.
@export_range(0.0, 1.0, 0.05) var disabled_alpha: float = 0.4

## The authored top and bottom offsets, read once when the game starts.
var _rest_top := 0.0
var _rest_bottom := 0.0


func _ready() -> void:
	var button := get_parent() as BaseButton
	if button == null:
		return
	_rest_top = offset_top
	_rest_bottom = offset_bottom
	if Engine.is_editor_hint():
		return
	button.draw.connect(follow)


## Match the parent button's current state: sink while held, dim while
## disabled. The button redraws on every state change, so this runs on its
## `draw` signal; tests call it directly.
func follow() -> void:
	var button := get_parent() as BaseButton
	if button == null:
		return
	var sink := label_drop(button) if button.get_draw_mode() in [
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else 0.0
	offset_top = _rest_top + sink
	offset_bottom = _rest_bottom + sink
	self_modulate.a = disabled_alpha if button.disabled else 1.0


## How far the button's label drops between its normal and pressed faces,
## px: the change in the centre of the content box the two styleboxes leave.
static func label_drop(button: Control) -> float:
	var rest := button.get_theme_stylebox(&"normal")
	var held := button.get_theme_stylebox(&"pressed")
	if rest == null or held == null:
		return 0.0
	var rest_mid := rest.content_margin_top - rest.content_margin_bottom
	var held_mid := held.content_margin_top - held.content_margin_bottom
	return (held_mid - rest_mid) * 0.5
