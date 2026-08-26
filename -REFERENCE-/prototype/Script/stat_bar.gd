extends ProgressBar

@onready var value_label: Label = $ValueLabel
@onready var goal_marker: Control = get_node_or_null("GoalMarker")

@export var target_value: float = 65.0
@export var goal_value: float = 0.0:
	set(v):
		goal_value = v
		_update_goal_marker()

var pending_gain: float = 0.0

func _ready():
	resized.connect(_update_goal_marker)
	_ensure_goal_marker()
	_update_goal_marker()

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

func set_stat(current: float, target: float):
	target_value = target
	max_value = target_value
	value = current
	_update_label()
	_update_goal_marker()

func set_current(current: float):
	set_stat(current, target_value)

func set_goal(goal: float):
	goal_value = goal
	_update_goal_marker()

func set_pending_gain(gain: float):
	pending_gain = gain
	_update_label()

func _update_label():
	if not value_label:
		return
	var text = "%d/%d" % [int(value), int(max_value)]
	if pending_gain > 0:
		text += " (+%d)" % int(pending_gain)
	elif pending_gain < 0:
		text += " (%d)" % int(pending_gain)
	value_label.text = text
	if value >= max_value:
		value_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		value_label.add_theme_color_override("font_color", Color.RED)

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
