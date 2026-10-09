@tool
class_name TutorialComic
extends Control

## The Grade-7 cold-open (2026-10-07 tutorial overhaul, spec
## docs/superpowers/specs/2026-10-07-tutorial-visual-overhaul-design.md
## section 4, beat 1): a full-screen dim with one centred comic plate that
## states the goal, then the stakes, one plate per tap. StudentCard plays it
## before the stat spotlights and waits for `finished`.
##
## Everything on screen is authored in Scenes/UI/TutorialComic.tscn -- scrim,
## plate, illustration, line, three target marks, the tap prompt and the skip
## -- and only filled and shown here. The beats are data (default_panels()):
## an illustration, a line of BBCode, and the target marks to show (true is a
## cleared target, false a missed one; none hides the row).
##
## A tap anywhere: the first fills a line still typing, the next turns the
## plate. The skip (the owner asked for one, 2026-10-09) ends the comic at
## once. Lines type out like the Nota Guru's (TutorialPanel.TYPE_INTERVAL) and
## show whole when Settings' Lewati Dialog is on.

## Emitted once, when the last plate is tapped past or the comic is skipped.
signal finished

## The tap prompt's blink: the alpha it dips to, and seconds for each half.
const BLINK_LOW_ALPHA := 0.25
const BLINK_HALF_PERIOD := 0.65

## Plate 1's illustration: the class Pak Guru will guide (placeholder art).
@export var plate_class: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/comic/plate_kelas.svg")
## Plate 2's illustration: a happy student who passes (placeholder art).
@export var plate_happy: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/comic/plate_senang.svg")
## Plate 3's illustration: a worried student whose targets fail (placeholder art).
@export var plate_worried: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/comic/plate_waspada.svg")
## The mark for a cleared target (placeholder art).
@export var mark_cleared: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/mark_check.svg")
## The mark for a missed target (placeholder art).
@export var mark_missed: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/mark_cross.svg")

@onready var illustration: TextureRect = %Illustration
@onready var line: RichTextLabel = %Line
@onready var marks: HBoxContainer = %Marks
@onready var prompt: Label = %Prompt
@onready var skip_button: Button = %Skip

var _panels: Array[Dictionary] = []
var _index := 0
var _type_tween: Tween
var _blink_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	skip_button.pressed.connect(_finish)


## The spec's three cold-open beats, verbatim (KBBI; owner-approved copy).
## The pass rule is GameState.MIN_TARGETS_PER_STUDENT, so the plate cannot
## drift from the verdict.
func default_panels() -> Array[Dictionary]:
	var danger := Juice.tokens().state_danger.to_html(false)
	return [
		{"art": plate_class,
			"line": "Selamat datang, Pak Guru! Ini kelas yang akan kamu bimbing.",
			"marks": []},
		{"art": plate_happy,
			"line": "Tiap murid punya [b]3 target[/b]. Capai minimal [b]%d[/b], dia lulus." \
					% GameState.MIN_TARGETS_PER_STUDENT,
			"marks": [true, true, false]},
		{"art": plate_worried,
			"line": "[color=#%s]Hati-hati:[/color] satu murid saja gagal, [color=#%s]satu kelas kena nilai D.[/color]" \
					% [danger, danger],
			"marks": [true, false, false]},
	]


## Shows `panels` one per tap (default_panels() when empty), then emits
## `finished` and hides.
func play(panels: Array[Dictionary] = []) -> void:
	_panels = panels if not panels.is_empty() else default_panels()
	_index = 0
	visible = true
	_show_panel()
	_start_blink()
	if not Engine.is_editor_hint():
		Juice.pop_in(%Plate)


func _gui_input(event: InputEvent) -> void:
	var press := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not press:
		return
	accept_event()
	advance()


## A tap: fill a typing line, else turn to the next plate, else finish.
func advance() -> void:
	if _panels.is_empty():
		return
	if is_typing():
		_stop_typing()
		line.visible_ratio = 1.0
		return
	_index += 1
	if _index >= _panels.size():
		_finish()
		return
	_show_panel()


## True while the current plate's line is still typing out.
func is_typing() -> bool:
	return _type_tween != null and _type_tween.is_valid() and _type_tween.is_running()


func _show_panel() -> void:
	var panel: Dictionary = _panels[_index]
	illustration.texture = panel.get("art", null)
	line.text = panel.get("line", "")
	var shown: Array = panel.get("marks", [])
	marks.visible = not shown.is_empty()
	for i in marks.get_child_count():
		var mark := marks.get_child(i) as TextureRect
		mark.visible = i < shown.size()
		if mark.visible:
			mark.texture = mark_cleared if shown[i] else mark_missed
	_type_line()


func _type_line() -> void:
	_stop_typing()
	line.visible_ratio = 1.0
	if GameSettings.skip_event_dialogue or Engine.is_editor_hint() or not is_inside_tree():
		return
	var count := line.get_total_character_count()
	line.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(line, "visible_ratio", 1.0, float(count) * TutorialPanel.TYPE_INTERVAL)


func _stop_typing() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null


func _start_blink() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(prompt, "modulate:a", BLINK_LOW_ALPHA, BLINK_HALF_PERIOD) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(prompt, "modulate:a", 1.0, BLINK_HALF_PERIOD) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _finish() -> void:
	if not visible:
		return
	_stop_typing()
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	visible = false
	finished.emit()
