@tool
class_name ApplyStudentRow
extends StudentCardButton

## One selectable student on ApplyItemScreen, wearing the real DaySummary
## card (2026-09-12 event-cards spec, section 1.5). The content is unchanged
## from the old checkbox row: only the stats the item boosts are shown,
## picking the card previews the gain, a stat already at 100 reads MAKS, and
## a student too tired to benefit shows LELAH and cannot be picked.

## Fired whenever the player picks or un-picks this student.
signal selection_changed

## Logical boost name -> the roster Dictionary key it writes. Fixed mapping:
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy (the project's canonical keys).
const KEY := {
	"akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
	"mood": "kepribadian1", "energy": "kepribadian2",
}

## kepribadian2 (energy) at or below this forces "Izin" -- such a student
## cannot take the item, so the card cannot be picked.
@export var tired_energy_threshold: float = 5.0

## The LELAH chip, authored under Card. Tinted state_danger at setup.
@onready var lelah_chip: Control = get_node_or_null("Card/LelahChip") as Control

## The roster entry this row stands for.
var student: Dictionary = {}
var _boosts: Dictionary = {}


## Fill the card from a roster entry and the item's non-zero boosts. Call
## after the row is in the tree: the card's parts are only ready then.
func setup(p_student: Dictionary, boosts: Dictionary) -> void:
	student = p_student
	_boosts = {}
	for k in boosts:
		if int(boosts[k]) != 0:
			_boosts[k] = int(boosts[k])
	var sd: StudentData = GameState.student_data_from_dict(student)
	card.setup_current_row(sd)
	card.show_only(_boosts.keys())
	var is_tired := float(student.get("kepribadian2", 100.0)) <= tired_energy_threshold
	lelah_chip.visible = is_tired
	if is_tired:
		lelah_chip.self_modulate = DesignTokens.load_default().state_danger
	set_selectable(not is_tired)


## Show (or clear) what the item would do to each boosted stat.
func set_preview(active: bool) -> void:
	for key in _boosts:
		var cur := float(student.get(KEY[key], 0.0))
		var after := clampf(cur + float(_boosts[key]), 0.0, 100.0)
		var delta := (after - cur) if active else 0.0
		if key == "mood" or key == "energy":
			card.preview_need(key, delta)
		else:
			card.preview_stat(key, delta, active and cur >= 100.0)


## False for a student too tired to take the item.
func can_select() -> bool:
	return not disabled


## Pick or un-pick this student, unless they cannot be picked.
func set_selected(on: bool) -> void:
	if not disabled:
		button_pressed = on


## The roster id of the student this row stands for.
func selected_student_id() -> int:
	return int(student.get("id", -1))


func _selection_toggled(toggled_on: bool) -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"select")
	set_preview(toggled_on)
	selection_changed.emit()
