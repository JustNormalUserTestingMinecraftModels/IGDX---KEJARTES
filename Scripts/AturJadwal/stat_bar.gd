extends ProgressBar

@onready var value_label: Control = $ValueLabel
@onready var goal_marker: Control = get_node_or_null("GoalMarker")
@onready var ghost_marker: ColorRect = get_node_or_null("GhostMarker")

@export var target_value: float = 65.0
@export var goal_value: float = 0.0:
	set(v):
		goal_value = v
		_update_goal_marker()

var base_stat_value: float = 0.0
var pending_gain: float = 0.0

func _ready():
	resized.connect(_on_resized)
	_ensure_goal_marker()
	_ensure_ghost_marker()
	_update_goal_marker()

func _on_resized():
	_update_goal_marker()
	_update_ghost_marker()

func _ensure_goal_marker():
	if not goal_marker:
		goal_marker = get_node_or_null("GoalMarker")
	if not goal_marker:
		var marker = ColorRect.new()
		marker.name = "GoalMarker"
		marker.color = Color(1.0, 0.84, 0.0, 0.9)
		marker.custom_minimum_size = Vector2(4, 0)
		marker.size = Vector2(4, size.y)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		goal_marker = marker

func _ensure_ghost_marker():
	if not ghost_marker:
		ghost_marker = get_node_or_null("GhostMarker")
	if not ghost_marker:
		var marker = ColorRect.new()
		marker.name = "GhostMarker"
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		ghost_marker = marker
		if goal_marker:
			move_child(ghost_marker, goal_marker.get_index())

func set_stat(current: float, target: float):
	target_value = target
	max_value = target_value
	base_stat_value = clampf(current, 0.0, max_value)
	value = base_stat_value
	_update_label()
	_update_goal_marker()
	_update_ghost_marker()

func set_current(current: float):
	set_stat(current, target_value)

func set_goal(goal: float):
	goal_value = goal
	_update_goal_marker()

func set_pending_gain(gain: float):
	pending_gain = gain
	_update_label()
	_update_ghost_marker()

func _get_stat_prefix() -> String:
	match name:
		"Akademis1": return "Akademik: "
		"Akademis2": return "Seni: "
		"Akademis3": return "Olahraga: "
		"Kepribadian1": return "Energi: "
		"Kepribadian2": return "Mood: "
		_: return ""

func _update_label_position_and_style():
	if not value_label:
		return
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left = 12.0
	value_label.offset_top = 0.0
	value_label.offset_right = -12.0
	value_label.offset_bottom = 0.0

	if value_label is Label:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 28)
		value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		value_label.add_theme_constant_override("outline_size", 6)
		value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		value_label.add_theme_constant_override("shadow_offset_x", 2)
		value_label.add_theme_constant_override("shadow_offset_y", 2)

func _update_label():
	if not value_label:
		return

	_update_label_position_and_style()

	var prefix = _get_stat_prefix()
	var display_val: int
	var tag_text := ""
	var tag_color := Color.WHITE

	if pending_gain > 0:
		display_val = int(base_stat_value)
		tag_text = " (+%d)" % int(pending_gain)
		tag_color = Color(0.36, 0.94, 0.45) # Green
	elif pending_gain < 0:
		var predicted = base_stat_value + pending_gain
		if predicted <= 0:
			display_val = 0
			tag_text = " (%d HABIS)" % int(pending_gain)
			tag_color = Color(1.0, 0.35, 0.35) # Red
		else:
			display_val = int(predicted)
			tag_text = " (%d)" % int(pending_gain)
			tag_color = Color(1.0, 0.35, 0.35) # Red
	else:
		display_val = int(base_stat_value)

	var number_text = "%d/%d" % [display_val, int(max_value)]

	if value_label is RichTextLabel:
		var hex_col = "#5df073" if pending_gain > 0 else "#ff5959"
		var bb = "[outline_size=6][outline_color=#000000]"
		bb += "[color=#ffffff]%s[/color]" % prefix
		bb += "[p align=right][color=#ffffff]%s[/color]" % number_text
		if tag_text != "":
			bb += " [color=%s]%s[/color]" % [hex_col, tag_text]
		bb += "[/p][/outline_color][/outline_size]"
		value_label.text = bb
	else:
		# Main value_label shows stat prefix (left inside bar)
		value_label.text = prefix
		value_label.add_theme_color_override("font_color", Color.WHITE)

		# Child gain_label shows number calculation (right side inside bar)
		var gain_label: Label = value_label.get_node_or_null("GainLabel")
		if not gain_label:
			gain_label = Label.new()
			gain_label.name = "GainLabel"
			gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			value_label.add_child(gain_label)

		var font_sz = 28
		gain_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		gain_label.offset_left = 0
		gain_label.offset_top = 0
		gain_label.offset_right = 0
		gain_label.offset_bottom = 0
		gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gain_label.add_theme_font_size_override("font_size", font_sz)
		gain_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		gain_label.add_theme_constant_override("outline_size", 6)
		gain_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		gain_label.add_theme_constant_override("shadow_offset_x", 2)
		gain_label.add_theme_constant_override("shadow_offset_y", 2)

		if tag_text != "":
			gain_label.text = number_text + tag_text
		else:
			gain_label.text = number_text
		gain_label.add_theme_color_override("font_color", Color.WHITE)
		gain_label.show()

func _update_goal_marker():
	_ensure_goal_marker()
	if not goal_marker:
		return
	if max_value <= 0.0 or goal_value <= 0.0:
		goal_marker.visible = false
		return
	goal_marker.visible = true
	goal_marker.size.y = size.y
	var goal_ratio = clamp(goal_value / max_value, 0.0, 1.0)
	goal_marker.position.x = goal_ratio * size.x - (goal_marker.size.x / 2.0)

func _update_ghost_marker():
	_ensure_ghost_marker()
	if not ghost_marker:
		return
	if max_value <= 0.0 or pending_gain == 0.0:
		ghost_marker.visible = false
		value = base_stat_value
		return

	var capped_base = clampf(base_stat_value, 0.0, max_value)

	if pending_gain > 0:
		value = capped_base
		ghost_marker.visible = true
		ghost_marker.size.y = size.y
		ghost_marker.position.y = 0.0
		var start_ratio = clampf(capped_base / max_value, 0.0, 1.0)
		var gain_ratio = clampf(pending_gain / max_value, 0.0, 1.0 - start_ratio)
		ghost_marker.position.x = start_ratio * size.x
		ghost_marker.size.x = gain_ratio * size.x
		ghost_marker.color = Color(0.36, 0.94, 0.45, 0.65)
	else:
		var predicted = capped_base + pending_gain
		if predicted <= 0.0:
			value = 0.0
			ghost_marker.visible = false
		else:
			var capped_predicted = clampf(predicted, 0.0, max_value)
			value = capped_predicted
			ghost_marker.visible = true
			ghost_marker.size.y = size.y
			ghost_marker.position.y = 0.0
			var start_ratio = clampf(capped_predicted / max_value, 0.0, 1.0)
			var loss_ratio = clampf((-pending_gain) / max_value, 0.0, 1.0 - start_ratio)
			ghost_marker.position.x = start_ratio * size.x
			ghost_marker.size.x = loss_ratio * size.x
			ghost_marker.color = Color(1.0, 0.35, 0.35, 0.65)
