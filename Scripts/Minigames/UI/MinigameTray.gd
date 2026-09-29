@tool
class_name MinigameTray
extends Container

## The button minigames' bottom plank (spec 2026-09-29 minigame mobile
## layout, 3.2), on the NotebookFrame pattern: a host scene drops its
## controls in as direct children of this instance's root (children of an
## instance's root always save) and the tray stacks them top to bottom,
## then lays its own HintLabel -- tagged HINT_META -- last. The plank is the
## MinigameTrayPanel stylebox, drawn here; it bleeds past this rect so the
## wood reaches the screen edges while the content stays inside the
## SafeAreaMargin. Height is the content's; a host's Spacer takes the slack.
##
## Affects: only its own children. BaseMinigame calls set_hint() and
## settle(); nothing here reaches up.

## Marks the tray's own HintLabel, so it is never treated as host content.
const HINT_META := &"minigame_tray_hint"
## The hint's alpha after the player's first correct action (ours; spec 6).
const SETTLED_ALPHA := 0.6
## Inner padding (left, top, right, bottom) between the plank's edge and
## its content. No side padding since 2026-09-30 (minigame hierarchy, 4):
## the host's SafeAreaMargin already holds everything 48 px (screen_margin)
## from the screen edge, and the tray's content keeps that one edge.
const PADDING := Vector4i(0, 28, 0, 24)

## The one-line hint under the controls.
@export var hint_text: String = "":
	set(value):
		hint_text = value
		_apply_hint()
## Gap in px between stacked host rows, and above the hint.
@export_range(0, 64, 1) var separation: int = 16:
	set(value):
		separation = value
		update_minimum_size()
		queue_sort()


## The running settle fade, killed by the next settle() or set_hint().
var _settle_tween: Tween


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		sort_now()
	elif what == NOTIFICATION_READY:
		_apply_hint()


func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel"), Rect2(Vector2.ZERO, size))


## Every visible Control child except the hint, in scene order.
func _host_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control != null and control.visible and not control.has_meta(HINT_META):
			rows.append(control)
	return rows


func _hint() -> Label:
	return get_node_or_null("HintLabel") as Label


func _get_minimum_size() -> Vector2:
	var width := 0.0
	var height := float(PADDING.y + PADDING.w)
	var rows := _host_rows()
	for row in rows:
		var m := row.get_combined_minimum_size()
		width = maxf(width, m.x)
		height += m.y
	height += float(separation * maxi(0, rows.size() - 1))
	var hint := _hint()
	if hint != null and hint.visible:
		height += hint.get_combined_minimum_size().y + (separation if not rows.is_empty() else 0)
	return Vector2(width + PADDING.x + PADDING.z, height)


## Lay the host rows out top-down, then the hint along the bottom.
func sort_now() -> void:
	var inner_w := size.x - PADDING.x - PADDING.z
	var y := float(PADDING.y)
	for row in _host_rows():
		var h := row.get_combined_minimum_size().y
		fit_child_in_rect(row, Rect2(PADDING.x, y, inner_w, h))
		y += h + separation
	var hint := _hint()
	if hint != null and hint.visible:
		var hh := hint.get_combined_minimum_size().y
		fit_child_in_rect(hint, Rect2(PADDING.x, size.y - PADDING.w - hh, inner_w, hh))
	queue_redraw()


## Show `text` as the hint, at full strength.
func set_hint(text: String) -> void:
	hint_text = text
	_kill_settle_tween()
	var hint := _hint()
	if hint != null:
		hint.modulate.a = 1.0


## Fade the hint to SETTLED_ALPHA; it stays readable and never hides.
func settle() -> void:
	var hint := _hint()
	if hint == null:
		return
	if Engine.is_editor_hint():
		hint.modulate.a = SETTLED_ALPHA
	else:
		_kill_settle_tween()
		_settle_tween = hint.create_tween()
		_settle_tween.tween_property(hint, "modulate:a", SETTLED_ALPHA,
			Juice.tokens().dur_normal)


func _kill_settle_tween() -> void:
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	_settle_tween = null


func _apply_hint() -> void:
	var hint := _hint()
	if hint == null:
		return
	hint.text = hint_text
	hint.visible = hint_text != ""
	update_minimum_size()
	queue_sort()
