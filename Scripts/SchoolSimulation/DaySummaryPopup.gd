extends Control
class_name DaySummaryPopup

## The end-of-day recap. A Scrim (&"Scrim" Panel) behind a Content
## VBoxContainer holding a TitleBanner (art, not text) and a RowsScroll ->
## RowsContainer of DaySummaryStudentRow instances -- one per student who
## moved -- built directly by this popup, plus a tap-anywhere dismiss.
##
## Styling comes entirely from the theme now: this script builds no
## StyleBoxFlat and owns no color of its own.
##
## Since the 2026-09-24 SchoolDay liveliness pass a reward layer sits between
## the banner and the rows: the teacher's verdict (a face, a headline and a
## 1-4 star rating), the day's tally (total naik / target tercapai / uang) and
## its Bintang Hari Ini. DayVerdict computes all of it from the same summary
## the rows are built from; this only shows it.

signal summary_dismissed

## Template instantiated once per student who moved that day, into
## rows_container -- normally DaySummaryStudentRow.tscn.
@export var student_row_scene: PackedScene
## The teacher's four expressions, rough (1 star) to outstanding (4 stars).
## Placeholder art, drop-in replaceable (docs/superpowers/DEBT.md).
@export var teacher_faces: Array[Texture2D] = []
## A lit rating star.
@export var star_on_texture: Texture2D
## An unlit rating star.
@export var star_off_texture: Texture2D

@onready var dim_overlay: Panel = $DimOverlay
@onready var content: VBoxContainer = $DimOverlay/Content
@onready var rows_container: VBoxContainer = $DimOverlay/Content/RowsScroll/RowsContainer
@onready var reward: Control = $DimOverlay/Content/Reward
@onready var _face: TextureRect = $DimOverlay/Content/Reward/Rows/Header/Face
@onready var _headline: Label = $DimOverlay/Content/Reward/Rows/Header/Words/Headline
@onready var _subline: Label = $DimOverlay/Content/Reward/Rows/Header/Words/Subline
@onready var _stars: Control = $DimOverlay/Content/Reward/Rows/Header/Words/Stars
@onready var _gain_value: Label = $DimOverlay/Content/Reward/Rows/Tally/GainCell/Col/Value
@onready var _target_value: Label = $DimOverlay/Content/Reward/Rows/Tally/TargetCell/Col/Value
@onready var _money_value: Label = $DimOverlay/Content/Reward/Rows/Tally/MoneyCell/Col/Value
@onready var _star_of_day: Control = $DimOverlay/Content/Reward/Rows/StarOfDay
@onready var _star_line: Label = $DimOverlay/Content/Reward/Rows/StarOfDay/Row/Words/Line

## The verdict setup_summary() computed, for tests and callers.
var verdict: Dictionary = {}

var is_dismissable: bool = false

## Which core stats have a matching per-student target on StudentData.
const _TARGET_FOR := {
	"akademis": "target_akademis1",
	"seni_budaya": "target_akademis2",
	"olahraga": "target_akademis3",
}


func setup_summary(
	summary_data: Array,
	students: Array[StudentData],
	money_today: int = 0
) -> void:
	AudioDirector.play_sfx(&"popup_open")
	verdict = DayVerdict.compute(summary_data, students, money_today)
	_show_verdict(verdict)

	# Clear old rows
	for child in rows_container.get_children():
		child.queue_free()

	# Populate rows
	var rows: Array = []
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
	content.modulate.a = 0.0
	content.scale = Vector2(0.85, 0.85)

	# Set pivot dynamically for scale bounce
	content.pivot_offset = get_viewport_rect().size / 2.0

	var t := Juice.tokens()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(dim_overlay, "self_modulate:a", 1.0, t.dur_normal)
	tw.tween_property(content, "modulate:a", 1.0, t.dur_fast)
	tw.tween_property(content, "scale", Vector2(1.0, 1.0), t.dur_normal) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	_reveal_verdict(verdict)

	# The rows land one after another once the card itself has settled.
	Juice.stagger_in(rows)

	# Each card's tracks start growing on the beat that card ARRIVES on --
	# the same offset stagger_in uses, so fill and entrance share a rhythm
	# rather than the whole stack's motion firing at once. The fill runs
	# dur_slow against the entrance's dur_normal, so it outlasts the card's
	# fade and the tail is read clearly even though the two overlap.
	var gain_step := Juice.tokens().stagger_step
	for i in rows.size():
		rows[i].play_gain(float(i) * gain_step)

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


## Writes the verdict into the reward layer: face, headline, the rating's
## lit and unlit stars, the tally and the Bintang Hari Ini line (hidden on a
## day nobody gained). Numbers start at zero; _reveal_verdict counts them up.
func _show_verdict(v: Dictionary) -> void:
	var stars: int = v.get("stars", 1)
	if _face and teacher_faces.size() >= 4:
		_face.texture = teacher_faces[clampi(stars, 1, 4) - 1]
	if _headline:
		_headline.text = v.get("headline", "")
	if _subline:
		_subline.text = v.get("subline", "")
		_subline.visible = _subline.text != ""
	if _stars:
		for i in _stars.get_child_count():
			var star := _stars.get_child(i) as TextureRect
			if star:
				star.texture = star_on_texture if i < stars else star_off_texture
	var money: int = v.get("money", 0)
	if _money_value:
		# "-" rather than "0": no Wirausaha today, not a loss.
		_money_value.text = "+%d" % money if money > 0 else "-"
	if _star_of_day:
		_star_of_day.visible = String(v.get("star_name", "")) != ""
	if _star_line:
		_star_line.text = "%s — +%d %s" % [v.get("star_name", ""), v.get("star_gain", 0),
			v.get("star_skill", "")]


## The verdict's entrance: the lit stars land one by one with the star
## chime, and the tally counts up. Under reduce_motion the numbers simply
## appear.
func _reveal_verdict(v: Dictionary) -> void:
	var gain: int = v.get("total_gain", 0)
	var crossed: int = v.get("targets_crossed", 0)
	if GameSettings.reduce_motion:
		_gain_value.text = "+%d" % gain
		_target_value.text = "%d" % crossed
		return
	Juice.count_up(_gain_value, 0.0, float(gain), "+%d")
	Juice.count_up(_target_value, 0.0, float(crossed), "%d")
	var lit: int = mini(v.get("stars", 1), _stars.get_child_count())
	var gap: float = Juice.tokens().stagger_step * 2.0
	# A tween the popup owns, so a fast dismiss takes the pending chimes
	# down with it instead of firing them at freed stars.
	var chimes := create_tween()
	for i in lit:
		var star := _stars.get_child(i) as Control
		Juice.pop_in(star, float(i) * gap)
		chimes.tween_callback(RewardFeedback.play.bind(&"star_earned", star, {"step": i + 1}))
		chimes.tween_interval(gap)


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
	tw.tween_property(content, "modulate:a", 0.0, t.dur_fast)
	tw.tween_property(dim_overlay, "self_modulate:a", 0.0, t.dur_normal)
	await tw.finished
	summary_dismissed.emit()
	queue_free()
