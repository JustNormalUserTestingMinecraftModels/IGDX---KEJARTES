@tool
class_name EventStudentCard
extends StudentCardButton

## One selectable student on the event dialog: the real DaySummary card
## (DaySummaryStudentRow, the Card child) inside StudentCardButton's toggle.
## The card shows where the student stands now; selecting it layers the
## event's effect on top (2026-09-12 event-cards spec, section 1.4).

## Fired when the player toggles this card. `selected` is the new state.
signal selection_changed(selected: bool)

## Which stat key each schedule category previews against.
const STAT_KEY_FOR_CATEGORY := {
	"Akademis": "akademis",
	"SeniBudaya": "seni_budaya",
	"Olahraga": "olahraga",
}

## Shown when the student is too tired to be sent.
@onready var tired_badge: TextureRect = get_node_or_null("Card/TiredBadge") as TextureRect
## Shown when the event's category is the student's specialty.
@onready var specialty_badge: TextureRect = get_node_or_null("Card/SpecialtyBadge") as TextureRect

var _student: StudentData = null
var _category: String = "Akademis"


## Writes the student's CURRENT stats onto the card, with no preview. Call
## after the card is in the tree: the card's parts are only ready then.
func setup(student: StudentData, category: String) -> void:
	_student = student
	_category = category
	if student == null:
		return
	card.setup_current_row(student)
	var is_tired: bool = student.is_tired()
	tired_badge.visible = is_tired
	specialty_badge.visible = student.specialty_category == category and not is_tired
	set_selectable(not is_tired)


## Layers the event's effect over the current values: its own category's
## stat row and both needs bars. Pass zeroes to rewind to the standing view.
func set_preview(stat_delta: float, energy_delta: float, mood_delta: float) -> void:
	if _student == null:
		return
	card.preview_stat(STAT_KEY_FOR_CATEGORY.get(_category, "akademis"), stat_delta)
	card.preview_need("energy", energy_delta)
	card.preview_need("mood", mood_delta)


## The student this card stands for, so the dialog can read their efficiency
## multiplier without reaching into the card's internals.
func student() -> StudentData:
	return _student


func _selection_toggled(pressed: bool) -> void:
	selection_changed.emit(pressed)
