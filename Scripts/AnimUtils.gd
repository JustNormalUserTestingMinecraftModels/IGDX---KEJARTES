class_name AnimUtils
extends RefCounted

## Centralized animation utilities for the Koprasi & Inventory project.
## All methods kill previous tweens on the same node to prevent stacking.

# ─── Active tween tracking (prevents stacking) ───
static var _active_tweens: Dictionary = {}  # node instance_id -> Tween

## Kill any previous tween on this node and create a fresh one.
static func _safe_tween(node: Node) -> Tween:
	var key = node.get_instance_id()
	if _active_tweens.has(key):
		var old = _active_tweens[key]
		if is_instance_valid(old) and old.is_running():
			old.kill()
	var tween = node.create_tween()
	_active_tweens[key] = tween
	return tween

## Ensure pivot_offset is centered on a Control node.
static func _center_pivot(node: Control) -> void:
	if node.size.length() > 0:
		node.pivot_offset = node.size / 2
	else:
		node.pivot_offset = Vector2(100, 100)

# ═══════════════════════════════════════════
#  BUTTON / SLOT ANIMATIONS
# ═══════════════════════════════════════════

## Playful squash-stretch bounce with optional tilt. Used for button presses.
static func squash_bounce(node: Control, tilt: float = 0.0) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.18, 0.85), 0.07).set_trans(Tween.TRANS_QUAD)
	if tilt != 0.0:
		tween.parallel().tween_property(node, "rotation_degrees", tilt, 0.07)
	tween.tween_property(node, "scale", Vector2(0.95, 1.08), 0.08).set_trans(Tween.TRANS_QUAD)
	if tilt != 0.0:
		tween.parallel().tween_property(node, "rotation_degrees", -tilt * 0.5, 0.08)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK)
	if tilt != 0.0:
		tween.parallel().tween_property(node, "rotation_degrees", 0.0, 0.1)
	return tween

## Gentle slot selection bounce — squash horizontally then settle.
static func slot_bounce(node: Control) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.12, 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(0.96, 1.06), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Shrink back to normal — used when deselecting a slot.
static func deselect_shrink(node: Control) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Cart basket bounce — subtle squash on item landing.
static func basket_bounce(node: Control) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.06, 0.94), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(0.96, 1.04), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Cart press with tilt — used when tapping the basket.
static func cart_press(node: Control) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.14, 0.86), 0.07).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(node, "rotation_degrees", -3.0, 0.07)
	tween.tween_property(node, "scale", Vector2(0.94, 1.08), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(node, "rotation_degrees", 2.0, 0.08)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(node, "rotation_degrees", 0.0, 0.12)
	return tween

## Back button bounce — squash + counter-clockwise tilt.
static func back_bounce(node: Control) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.25, 0.8), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(node, "rotation_degrees", -18.0, 0.08)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(node, "rotation_degrees", 0.0, 0.12)
	return tween

## Stepper button bounce with directional rotation (for +/- buttons).
static func stepper_bounce(node: Control, direction: float = 1.0) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.06).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(node, "rotation_degrees", direction * 8.0, 0.06)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(node, "rotation_degrees", 0.0, 0.1)
	return tween

# ═══════════════════════════════════════════
#  PANEL / CONTAINER ANIMATIONS
# ═══════════════════════════════════════════

## Spring pop-in — scale from small + fade in. Used for panels and popups.
static func spring_pop_in(node: Control, from_scale: float = 0.85) -> Tween:
	_center_pivot(node)
	node.scale = Vector2(from_scale, from_scale)
	node.modulate.a = 0.0
	var tween = _safe_tween(node)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.15)
	return tween

## Spring pop-out — shrink + fade out, then call an optional callback.
static func spring_pop_out(node: Control, callback: Callable = Callable()) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	if callback.is_valid():
		tween.chain().tween_callback(callback)
	return tween

## Detail panel slide-in from bottom.
static func detail_slide_in(node: Control) -> Tween:
	node.show()
	node.pivot_offset = Vector2(node.size.x / 2, node.size.y)
	node.scale = Vector2(1.0, 0.0)
	node.modulate.a = 0.0
	var tween = _safe_tween(node)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.0, 1.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.15)
	tween.chain().tween_property(node, "scale", Vector2(1.0, 1.0), 0.08)
	return tween

## Detail panel slide-out to bottom, then hide.
static func detail_slide_out(node: Control) -> Tween:
	node.pivot_offset = Vector2(node.size.x / 2, node.size.y)
	var tween = _safe_tween(node)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.0, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(node.hide)
	return tween

## Popup spring pop-in with slight rotation for personality.
static func popup_spring_in(node: Control) -> Tween:
	_center_pivot(node)
	node.scale = Vector2(0.5, 0.5)
	node.rotation_degrees = -3.0
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.06, 1.06), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "rotation_degrees", 0.0, 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)
	return tween

## Popup shrink-out with fade.
static func popup_spring_out(node: Control, overlay: Control, callback: Callable = Callable()) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(0.6, 0.6), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.12)
	if callback.is_valid():
		tween.chain().tween_callback(callback)
	return tween

# ═══════════════════════════════════════════
#  ICON / ITEM ANIMATIONS
# ═══════════════════════════════════════════

## Wobble animation — scale up from small with wiggle rotation. Used for detail icons.
static func wobble(node: Control) -> Tween:
	if not is_instance_valid(node):
		return null
	_center_pivot(node)
	node.rotation_degrees = 0
	node.scale = Vector2(0.7, 0.7)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "rotation_degrees", -6.0, 0.08)
	tween.tween_property(node, "rotation_degrees", 4.0, 0.08)
	tween.tween_property(node, "rotation_degrees", -2.0, 0.06)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.06)
	return tween

## Staggered entrance — pop from zero with overshoot, used for grid item slots.
static func staggered_entrance(node: Control, delay: float) -> Tween:
	_center_pivot(node)
	node.scale = Vector2.ZERO
	node.modulate.a = 0.0
	var tween = node.create_tween()  # Don't use _safe_tween here — multiple slots animate independently
	tween.tween_interval(delay)
	tween.tween_property(node, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "modulate:a", 1.0, 0.12)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

## Spawn pop — item landing in basket area.
static func spawn_pop(node: Control) -> Tween:
	node.scale = Vector2(0.5, 0.5)
	var tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Shrink and fade out — used for removing items from basket.
static func shrink_and_fade(node: Control) -> Tween:
	var tween = _safe_tween(node)
	tween.tween_property(node, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(node, "scale", Vector2(0.3, 0.3), 0.18)
	return tween

# ═══════════════════════════════════════════
#  TEXT / LABEL ANIMATIONS
# ═══════════════════════════════════════════

## Coin pulse — container scale bounce for coin display updates.
static func coin_pulse(container: Control) -> Tween:
	if not is_instance_valid(container):
		return null
	_center_pivot(container)
	var tween = _safe_tween(container)
	tween.tween_property(container, "scale", Vector2(1.22, 1.22), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Stepper qty punch — label scale bounce.
static func qty_punch(node: Control) -> Tween:
	_center_pivot(node)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.35, 1.35), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Message pop-in — spring scale then fade out after delay.
static func message_pop(node: Control, duration: float = 1.5) -> Tween:
	if not is_instance_valid(node):
		return null
	_center_pivot(node)
	node.modulate.a = 1.0
	node.scale = Vector2(0.6, 0.6)
	var tween = _safe_tween(node)
	tween.tween_property(node, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(duration)
	tween.tween_property(node, "modulate:a", 0.0, 0.5)
	return tween

## Floating text — rises up and fades out. Returns the label so caller can parent it.
static func create_floating_text(parent: Node, text: String, at_pos: Vector2, color: Color, font_size: int = 34) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = at_pos - Vector2(100, 30)
	label.z_index = 200
	label.pivot_offset = Vector2(100, 20)
	parent.add_child(label)

	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", at_pos.y - 90.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(label.queue_free)
	return label

## Idle pulse loop — gentle breathing scale animation.
static func idle_pulse(node: Control) -> Tween:
	_center_pivot(node)
	var tween = node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

## Gentle fade-in.
static func fade_in(node: Control, duration: float = 0.35) -> Tween:
	node.modulate.a = 0.0
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	return tween
