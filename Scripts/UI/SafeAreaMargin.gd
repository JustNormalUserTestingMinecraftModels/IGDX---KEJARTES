@tool
class_name SafeAreaMargin
extends MarginContainer

## A MarginContainer that keeps its contents clear of notches, punch
## holes, and gesture bars, plus the project's standard screen margin.
##
## Wrap the top-level content of every full-screen scene in one of these.

## Turn off to apply only extra_margin + screen_margin, ignoring the device.
@export var use_safe_area: bool = true:
	set(value):
		use_safe_area = value
		_apply()

## Per-side additional margin, in the order (left, top, right, bottom).
@export var extra_margin: Vector4 = Vector4.ZERO:
	set(value):
		extra_margin = value
		_apply()


func _ready() -> void:
	_apply()
	get_tree().root.size_changed.connect(_apply)


func _apply() -> void:
	if not is_inside_tree():
		return
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return

	var base := float(tokens.screen_margin)
	var inset := Vector4.ZERO

	if use_safe_area:
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		# get_display_safe_area returns physical screen pixels; scale into
		# the project's 1080-wide reference space or the insets come out
		# far too small on a high-DPI phone.
		var scale_x := float(size.x) / maxf(float(win.x), 1.0)
		var scale_y := float(size.y) / maxf(float(win.y), 1.0)
		inset = Vector4(
			float(safe.position.x) * scale_x,
			float(safe.position.y) * scale_y,
			float(win.x - safe.end.x) * scale_x,
			float(win.y - safe.end.y) * scale_y)

	add_theme_constant_override("margin_left",
		int(base + inset.x + extra_margin.x))
	add_theme_constant_override("margin_top",
		int(base + inset.y + extra_margin.y))
	add_theme_constant_override("margin_right",
		int(base + inset.z + extra_margin.z))
	add_theme_constant_override("margin_bottom",
		int(base + inset.w + extra_margin.w))
