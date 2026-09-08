@tool
extends Button
class_name EventStudentCard

## One selectable student on the event dialog, wearing DaySummary's
## chrome.
##
## The whole card is the toggle. That deletes the 2.4x-scaled Godot
## CheckBox this screen used to carry -- which matched nothing else in
## the game -- and turns a 992x410 card into the tap target, which
## matters on a 1080-wide portrait phone. The selected look comes from
## the EventSelectCard theme variation's pressed stylebox rather than a
## bespoke StyleBoxFlat.
##
## Every part here is a DaySummary component reused as-is: the avatar,
## the two needs bars, the three stat rows. The one thing this adds over
## a DaySummary row is set_preview(), which shows what accepting the
## event would do to the student before the player commits.

## Fired when the player toggles this card. `selected` is the new state.
signal selection_changed(selected: bool)

## Stat keys in the order the three rows are laid out, matching
## DaySummaryStudentRow so both cards read the same way.
const STAT_ORDER: Array[String] = ["akademis", "seni_budaya", "olahraga"]

## Each stat's target field on StudentData. Copied from
## DaySummaryStudentRow, naming trap and all: target_akademis2 is the
## SENI target and target_akademis3 the OLAHRAGA one.
const TARGET_FOR := {
	"akademis": "target_akademis1",
	"seni_budaya": "target_akademis2",
	"olahraga": "target_akademis3",
}

## Which stat key each schedule category previews against.
const STAT_KEY_FOR_CATEGORY := {
	"Akademis": "akademis",
	"SeniBudaya": "seni_budaya",
	"Olahraga": "olahraga",
}

@onready var avatar: DaySummaryAvatar = $Avatar
@onready var name_label: Label = $NameLabel
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var mood_bar: ProgressBar = $MoodBar
@onready var select_badge: TextureRect = $SelectBadge
@onready var tired_badge: TextureRect = $TiredBadge
@onready var specialty_badge: TextureRect = $SpecialtyBadge

var _student: StudentData = null
var _category: String = "Akademis"


func _ready() -> void:
	toggled.connect(_on_toggled)
	if select_badge:
		select_badge.visible = false


## Writes the student's CURRENT stats onto the card, with no preview.
## Call set_preview() afterwards to layer a proposed change over it.
func setup(student: StudentData, category: String) -> void:
	_student = student
	_category = category
	if student == null:
		return

	name_label.text = student.student_name
	avatar.set_student(student)
	energy_bar.set_need("energy", student.energy)
	mood_bar.set_need("mood", student.mood)

	# The two state badges the old dialog said with emoji. A tired
	# student cannot be sent at all; a specialty match spends less
	# energy, which the preview then shows in the numbers.
	var is_tired: bool = student.is_tired()
	var is_specialty: bool = (student.specialty_category == category)
	tired_badge.visible = is_tired
	specialty_badge.visible = is_specialty and not is_tired

	set_selectable(not is_tired)
	_write_stat_rows(0.0)


## Layers a proposed change over the current values: the event's own
## stat row travels to what it would become, and both needs bars follow.
## Pass zeroes to rewind to the plain current-value view.
func set_preview(stat_delta: float, energy_delta: float, mood_delta: float) -> void:
	if _student == null:
		return
	_write_stat_rows(stat_delta)
	energy_bar.set_need("energy", clampf(_student.energy + energy_delta, 0.0, 100.0))
	mood_bar.set_need("mood", clampf(_student.mood + mood_delta, 0.0, 100.0))


## The student this card stands for, so the dialog can read their
## efficiency multiplier without reaching into the card's internals.
func student() -> StudentData:
	return _student


## True when the player has this student marked to take part.
func is_selected() -> bool:
	return button_pressed


## A tired student cannot be sent; the card refuses the tap and drops
## any selection it was already carrying. Also dims the whole card and
## desaturates the avatar so unavailability reads at a glance instead of
## the player tapping it and wondering why nothing happens.
func set_selectable(on: bool) -> void:
	disabled = not on
	if not on:
		button_pressed = false
	modulate.a = 1.0 if on else 0.55
	if avatar:
		avatar.modulate = Color.WHITE if on else Color(0.7, 0.7, 0.75, 1.0)


## Writes all three stat tracks. Only the event's own category previews
## a change -- the other two show where the student stands today, which
## is the whole point of matching DaySummary here.
func _write_stat_rows(event_stat_delta: float) -> void:
	if _student == null:
		return
	var preview_key: String = STAT_KEY_FOR_CATEGORY.get(_category, "akademis")
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		var row := get_node_or_null("StatRow%d" % (i + 1))
		if row == null:
			continue
		var target := float(_student.get(TARGET_FOR[key]))
		var current := float(_student.get(key))
		var delta: float = event_stat_delta if key == preview_key else 0.0
		row.set_stat(key, delta, target, current)


func _on_toggled(pressed: bool) -> void:
	if select_badge:
		select_badge.visible = pressed
	selection_changed.emit(pressed)
