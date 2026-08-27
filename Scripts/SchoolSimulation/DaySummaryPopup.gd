extends Control
class_name DaySummaryPopup

## The end-of-day recap. A Scrim behind a Card, one DaySummaryStudentRow
## per student who moved, and a tap-anywhere dismiss.
##
## Styling comes entirely from the theme now: the dim layer is a
## &"Scrim" Panel and the card is a &"Card" PanelContainer, so this
## script no longer builds a StyleBoxFlat or owns any color.

signal summary_dismissed

@export var student_row_scene: PackedScene

@onready var dim_overlay: Panel = $DimOverlay
@onready var card_panel: PanelContainer = $DimOverlay/MarginContainer/CardPanel
@onready var title_label: Label = $DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var rows_container: VBoxContainer = $DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/RowsContainer
@onready var hint_label: Label = $DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/HintLabel

var is_dismissable: bool = false

## Which core stats have a matching per-student target on StudentData.
const _TARGET_FOR := {
	"akademis": "target_akademis1",
	"seni_budaya": "target_akademis2",
	"olahraga": "target_akademis3",
}


## `build_rows` exists because SchoolDay drives this popup in a second
## mode: it reparents its own live StudentScroll into RowsContainer and
## therefore wants the summary data (for the title and the audio verdict)
## without the popup also instantiating a duplicate set of rows.
func setup_summary(
	day_name: String,
	summary_data: Array,
	students: Array[StudentData],
	build_rows: bool = true
) -> void:
	title_label.text = "%s - Rangkuman Hari" % day_name.to_upper()
	AudioDirector.play_sfx(&"popup_open")

	# Clear old rows
	for child in rows_container.get_children():
		child.queue_free()

	# Populate rows
	var rows: Array = []
	if build_rows:
		for entry in summary_data:
			var s_name = entry.get("student_name", "")
			var changes = entry.get("changes", [])
			if changes.is_empty():
				continue

			var student: StudentData = null
			for s in students:
				if s.student_name == s_name:
					student = s
					break

			var row_inst = student_row_scene.instantiate()
			rows_container.add_child(row_inst)
			row_inst.setup_row(s_name, changes, student)
			rows.append(row_inst)

	# Animate in
	dim_overlay.self_modulate.a = 0.0
	card_panel.modulate.a = 0.0
	card_panel.scale = Vector2(0.85, 0.85)

	# Set pivot dynamically for scale bounce
	var vp_size = get_viewport_rect().size
	card_panel.pivot_offset = Vector2((vp_size.x - 72) / 2.0, (vp_size.y - 96) / 2.0)

	var t := Juice.tokens()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(dim_overlay, "self_modulate:a", 1.0, t.dur_normal)
	tw.tween_property(card_panel, "modulate:a", 1.0, t.dur_fast)
	tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), t.dur_normal) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	# The rows land one after another once the card itself has settled.
	Juice.stagger_in(rows)

	is_dismissable = true

	# The verdict cue lands after the popup's entrance has visibly settled,
	# rather than layering on top of popup_open in the same frame.
	_play_day_verdict_sfx(summary_data, students)


## One sound per day, chosen from what actually happened:
##   success -- at least one core stat gained AND now sits at or above
##              that student's target for it (the "above target" case the
##              design asks for),
##   fail    -- otherwise, if anything at all went down.
## A day where nothing crossed a target and nothing was lost stays silent
## rather than being congratulated for standing still.
func _play_day_verdict_sfx(summary_data: Array, students: Array[StudentData]) -> void:
	var gained_above_target := false
	var had_loss := false

	for entry in summary_data:
		var s_name = entry.get("student_name", "")
		var student: StudentData = null
		for s in students:
			if s.student_name == s_name:
				student = s
				break
		for ch in entry.get("changes", []):
			var delta := float(ch.get("delta", 0.0))
			var stat_key := String(ch.get("stat_key", ""))
			if delta < 0.0:
				if _TARGET_FOR.has(stat_key):
					had_loss = true
				continue
			if delta <= 0.0 or student == null:
				continue
			if not _TARGET_FOR.has(stat_key):
				continue
			if float(student.get(stat_key)) >= float(student.get(_TARGET_FOR[stat_key])):
				gained_above_target = true

	if gained_above_target:
		AudioDirector.play_sfx(&"success")
	elif had_loss:
		AudioDirector.play_sfx(&"fail")


func _input(event: InputEvent) -> void:
	if not is_dismissable:
		return
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)
	var is_key = (event is InputEventKey and event.pressed and event.keycode != KEY_O)

	if is_click or is_touch or is_key:
		is_dismissable = false
		dismiss()


func dismiss() -> void:
	var t := Juice.tokens()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card_panel, "modulate:a", 0.0, t.dur_fast)
	tw.tween_property(dim_overlay, "self_modulate:a", 0.0, t.dur_normal)
	await tw.finished
	summary_dismissed.emit()
	queue_free()
