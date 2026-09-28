@tool
class_name SafeAreaMargin
extends MarginContainer

## A MarginContainer that keeps its contents clear of notches, punch
## holes, and gesture bars, plus the project's standard screen margin.
##
## Wrap the top-level content of every full-screen scene in one of these.

## Largest share of an axis a device inset may take; a reading past it is
## clamped (and warned about on a device).
const MAX_INSET_FRACTION := 0.4

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
		var mobile := OS.has_feature("mobile")
		var fullscreen := _window_is_fullscreen()
		inset = device_inset(safe, win, size, mobile, fullscreen)
		# Silent clamping would hide a real, larger inset on some future
		# device (foldables, unusual notches) with no diagnostic trail --
		# warn whenever the raw value actually needed correcting.
		if mobile and fullscreen:
			var raw := _raw_inset(safe, win, size)
			if raw != inset:
				push_warning(
					"SafeAreaMargin: safe-area inset %s clamped to %s (window %s, safe area %s)"
					% [raw, inset, win, safe])

	add_theme_constant_override("margin_left",
		int(base + inset.x + extra_margin.x))
	add_theme_constant_override("margin_top",
		int(base + inset.y + extra_margin.y))
	add_theme_constant_override("margin_right",
		int(base + inset.z + extra_margin.z))
	add_theme_constant_override("margin_bottom",
		int(base + inset.w + extra_margin.w))


## The device inset (left, top, right, bottom) in `area`'s space, given the
## display's safe area and the window size in physical pixels.
##
## get_display_safe_area() reports the MONITOR's safe area, not one clipped
## to this window. On a fullscreen phone the window IS the monitor, so the
## difference is the notch and gesture bar. Anywhere else -- a desktop run,
## the editor's embedded game, a windowed or split-screen app -- it measures
## the gap between the window and the monitor edge instead: large and
## positive for a small window (the embedded 1063x1891 run lost 768px at the
## bottom), negative for one larger than the reported area. So the inset is
## zero unless this is a mobile build in a fullscreen window, and desktop
## runs show the phone layout. (Android reports fullscreen only in immersive
## mode, the export default; a non-immersive export reads no inset here.)
static func device_inset(safe: Rect2i, win: Vector2i, area: Vector2,
		is_mobile: bool, is_fullscreen: bool) -> Vector4:
	if not is_mobile or not is_fullscreen:
		return Vector4.ZERO
	var raw := _raw_inset(safe, win, area)
	# An inset can only shrink the available space, never grow it, and no
	# real notch or gesture bar takes 40% of an axis -- the cap keeps a
	# bogus reading from consuming the screen.
	return Vector4(
		clampf(raw.x, 0.0, area.x * MAX_INSET_FRACTION),
		clampf(raw.y, 0.0, area.y * MAX_INSET_FRACTION),
		clampf(raw.z, 0.0, area.x * MAX_INSET_FRACTION),
		clampf(raw.w, 0.0, area.y * MAX_INSET_FRACTION))


## The unclamped inset: how far the safe area sits in from each window edge,
## scaled from physical pixels into `area`'s space (the 1080-wide reference
## space), or the insets come out far too small on a high-DPI phone.
static func _raw_inset(safe: Rect2i, win: Vector2i, area: Vector2) -> Vector4:
	var scale_x := area.x / maxf(float(win.x), 1.0)
	var scale_y := area.y / maxf(float(win.y), 1.0)
	return Vector4(
		float(safe.position.x) * scale_x,
		float(safe.position.y) * scale_y,
		float(win.x - safe.end.x) * scale_x,
		float(win.y - safe.end.y) * scale_y)


static func _window_is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN 		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
