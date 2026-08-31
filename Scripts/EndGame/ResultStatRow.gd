@tool
class_name ResultStatRow
extends VBoxContainer

## One Akademis/Seni Budaya/Olahraga stat row on a SemesterEnd result
## card. Extracted from the near-identical inline subtrees that used to
## be duplicated per student card (Icon + Title + Value label pair,
## plus a ProgressBar with hand-built fill/background StyleBoxes) so a
## designer can retune the row -- or add a fourth subject -- in one
## place instead of four-plus copies.
##
## The bar's own tint comes from StatBar's `category` (the subject's
## identity color, e.g. Akademis blue). The value label is tinted
## separately by whether THIS row's value met its target -- that is a
## per-row pass/fail signal independent of category identity, and is
## the direct replacement for the old code's ad-hoc green/red
## ProgressBar fill.

## One of StatBar's recognized categories: Akademis, Olahraga, SeniBudaya.
@export var category: String = "Akademis":
	set(value):
		category = value
		if is_node_ready():
			_progress.category = value

## Subject icon shown on Labels/Icon.
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_icon_rect.texture = value

## Subject name shown on Labels/Title (e.g. "Akademis").
@export var label_text: String = "":
	set(value):
		label_text = value
		if is_node_ready():
			_title_label.text = value

@onready var _icon_rect: TextureRect = $Labels/Icon
@onready var _title_label: Label = $Labels/Title
@onready var _value_label: Label = $Labels/Value
@onready var _progress: StatBar = $Progress


func _ready() -> void:
	_progress.category = category
	_icon_rect.texture = icon
	_title_label.text = label_text


## Set this row's value/target pair. `animate` drives the bar fill and
## the value label's count-up via Juice, matching StatBar.set_stat's own
## animate flag so tests and non-visual call sites can opt out.
func set_result(value: float, target: float, animate: bool = true) -> void:
	var is_tuntas := value >= target
	_progress.max_value = maxf(target, 1.0)

	var tokens := DesignTokens.load_default()
	_value_label.add_theme_color_override("font_color",
		tokens.state_success if is_tuntas else tokens.state_danger)

	var target_int := int(target)
	if animate:
		var previous := _progress.value
		_progress.set_stat(value)
		Juice.count_up(_value_label, previous, value, "%d/" + str(target_int))
	else:
		_progress.value = value
		_value_label.text = "%d/%d" % [int(value), target_int]
