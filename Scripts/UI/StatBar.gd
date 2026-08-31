@tool
class_name StatBar
extends ProgressBar

## An animated, category-tinted stat bar. Replaces the ad-hoc
## ProgressBar + ValueLabel pairs currently duplicated across
## AturJadwal, SemesterEnd, and StudentCard.

## One of: Akademis, Olahraga, SeniBudaya, Istirahat, Libur.
## Anything else falls back to text_secondary — never invisible.
@export var category: String = "Akademis":
	set(value):
		category = value
		_apply_tint()

## Which theme variation this bar wears. The student card's redesigned
## pills use "StatPill", whose track is painted into the card art; every
## other screen keeps the shared "StatBar" look.
@export var variation: StringName = &"StatBar":
	set(value):
		variation = value
		if is_inside_tree():
			theme_type_variation = value

## When true, overlays a centered "value_format % value" Label on top of
## the fill -- most callers leave this off and show the number in a
## separate InfoLabel/StudentStatRow instead.
@export var show_value_label: bool = false:
	set(value):
		show_value_label = value
		_sync_label()

## printf format for the value label. Use "%d%%" for a percentage.
@export var value_format: String = "%d"

var _label: Label


func _ready() -> void:
	theme_type_variation = variation
	show_percentage = false
	min_value = 0.0
	max_value = 100.0
	_apply_tint()
	_sync_label()


func _apply_tint() -> void:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	# The theme's fill stylebox is white, so self_modulate is the tint.
	self_modulate = tokens.category_color(category)


func _sync_label() -> void:
	if not is_inside_tree():
		return
	if show_value_label and _label == null:
		_label = Label.new()
		_label.name = "ValueLabel"
		_label.theme_type_variation = &"CaptionLabel"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		_label.text = value_format % int(round(value))
	elif not show_value_label and _label != null:
		_label.queue_free()
		_label = null


## Set the bar's value, optionally animating the fill and the label
## count-up together. Input is clamped: decay math upstream can overshoot.
func set_stat(new_value: float, animate: bool = true) -> void:
	var target := clampf(new_value, min_value, max_value)
	if animate:
		var previous := value
		Juice.fill_bar(self, target)
		if _label != null:
			Juice.count_up(_label, previous, target, value_format)
	else:
		value = target
		if _label != null:
			_label.text = value_format % int(round(target))
