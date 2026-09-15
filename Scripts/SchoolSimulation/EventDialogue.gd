@tool
extends Control

## The per-event dialogue (2026-09-14 event-dialogue spec): one character
## line over a blurred school, between EventWarning and a minigame or random
## event. Two modes, both chosen by EventDialogueCatalog:
##
## - TAP: no buttons. Always two taps: the first finishes the line and shows
##   the hint, the second closes with accepted = true.
## - CHOICE: taps only finish the line; Tolak / Terima close it.
##
## Everything is authored in EventDialogue.tscn; open() only sets textures,
## text and visibility. SchoolDay awaits `closed`.

## Emitted once: true for Terima or a finished TAP dialogue, false for Tolak.
signal closed(accepted: bool)

## Typewriter speed in characters per second. Same default as the intro cutscene.
@export var typewriter_chars_per_second: float = 45.0

@onready var background: TextureRect = $Background
@onready var blur: ColorRect = $Blur
@onready var splash: TextureRect = $Splash
@onready var week_label: Label = $Header/Calendar/Text/WeekLabel
@onready var day_label: Label = $Header/DayBanner/DayLabel
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var line_label: RichTextLabel = $DialogueBox/Content/Line
@onready var hint: Label = $DialogueBox/Content/Hint
@onready var choices: HBoxContainer = $DialogueBox/Content/Choices
@onready var tolak_button: Button = $DialogueBox/Content/Choices/TolakButton
@onready var terima_button: Button = $DialogueBox/Content/Choices/TerimaButton

## EventDialogueCatalog.MODE_TAP or MODE_CHOICE, from the open entry.
var mode: String = EventDialogueCatalog.MODE_TAP
## True once a TAP dialogue's first tap has landed.
var armed: bool = false
var _reveal_tween: Tween
var _is_closed: bool = false


func _ready() -> void:
	tolak_button.pressed.connect(_close.bind(false))
	terima_button.pressed.connect(_close.bind(true))
	if Engine.is_editor_hint():
		return
	AudioDirector.play_sfx(&"popup_open")


## Dress the screen for one catalog entry. `featured` may be null (empty
## roster). At runtime the line types itself out; in the editor it waits at
## visible_ratio 0 for a tap, which is what the tests drive.
func open(e: Dictionary, featured: StudentData, week: int, max_weeks: int, day_name: String) -> void:
	mode = e.get("mode", EventDialogueCatalog.MODE_TAP)
	armed = false
	_is_closed = false
	var bg_path: String = e.get("background", EventDialogueCatalog.DEFAULT_BACKGROUND)
	background.texture = load(bg_path)
	blur.visible = e.get("blur", true)
	var splash_path: String = EventDialogueCatalog.splash_path_for(e, featured)
	splash.texture = load(splash_path) if splash_path != "" and ResourceLoader.exists(splash_path) else null
	splash.visible = splash.texture != null
	week_label.text = "%d/%d" % [week, max_weeks]
	day_label.text = day_name
	line_label.text = EventDialogueCatalog.fill_line(e.get("line", ""), featured)
	line_label.visible_ratio = 0.0
	hint.visible = false
	choices.visible = false
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	Juice.pop_in(dialogue_box)
	var chars := float(line_label.get_total_character_count())
	_reveal_tween = line_label.create_tween()
	_reveal_tween.tween_property(line_label, "visible_ratio", 1.0,
		chars / maxf(typewriter_chars_per_second, 1.0))
	_reveal_tween.finished.connect(_on_line_shown)


func _gui_input(event: InputEvent) -> void:
	if not is_tap(event):
		return
	accept_event()
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"tap")
	tap()


## True for the one event per tap this screen counts: a left mouse-button
## press. project.godot emulates touch from mouse and Godot emulates mouse
## from touch, so every tap also arrives as a ScreenTouch; counting both would
## close a TAP dialogue on its first tap. A ScreenTouch counts only when
## mouse-from-touch emulation is off.
static func is_tap(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	var st := event as InputEventScreenTouch
	if st != null:
		return st.pressed and not bool(ProjectSettings.get_setting(
			"input_devices/pointing/emulate_mouse_from_touch", true))
	return false


## One tap. TAP: finish the line and arm, or close once armed. CHOICE: finish
## the line; only the buttons close it.
func tap() -> void:
	if _is_closed:
		return
	if line_label.visible_ratio < 1.0:
		_finish_line()
	if mode == EventDialogueCatalog.MODE_CHOICE:
		return
	if not armed:
		armed = true
		hint.visible = true
		return
	_close(true)


func _finish_line() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	line_label.visible_ratio = 1.0
	_on_line_shown()


func _on_line_shown() -> void:
	if mode == EventDialogueCatalog.MODE_CHOICE:
		choices.visible = true


func _close(accepted: bool) -> void:
	if _is_closed:
		return
	_is_closed = true
	closed.emit(accepted)
