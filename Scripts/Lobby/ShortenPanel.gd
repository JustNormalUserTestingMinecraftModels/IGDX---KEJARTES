@tool
extends Control

## The Lobby's Shorten panel (2026-09-14 shorten-dialog spec). Two options
## set GameSettings.skip_event_dialogue: Skip Dialog skips the line before
## each minigame, Jangan Skip Dialog keeps it. Tapping the dim background
## closes the panel unchanged. Every node is authored in ShortenPanel.tscn;
## the script only wires it, fills the status line and closes.

## Emitted once, when the panel closes for any reason.
signal closed

## Status line when the minigame lines are shown.
@export var status_shown_text: String = "Sekarang: dialog minigame ditampilkan."
## Status line when Shorten skips them.
@export var status_skipped_text: String = "Sekarang: dialog minigame dilewati."

@onready var scrim: Panel = $Scrim
@onready var card: PanelContainer = $Center/Card
@onready var status_label: Label = $Center/Card/Content/StatusLabel
@onready var skip_button: Button = $Center/Card/Content/SkipButton
@onready var keep_button: Button = $Center/Card/Content/KeepButton

var _is_closed := false


func _ready() -> void:
	skip_button.pressed.connect(pick.bind(true))
	keep_button.pressed.connect(pick.bind(false))
	scrim.gui_input.connect(_on_scrim_gui_input)
	refresh()


## Show the panel. The scrim starts at MOUSE_FILTER_IGNORE (the popup-dismiss
## rule) and only starts catching taps once the pop-in is done, so the tap
## that opened the panel can never also close it.
func open() -> void:
	refresh()
	if Engine.is_editor_hint() or not is_inside_tree():
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	AudioDirector.play_sfx(&"popup_open")
	Juice.pop_in(card)
	var arm := create_tween()
	arm.tween_interval(Juice.tokens().dur_normal)
	arm.tween_callback(func(): scrim.mouse_filter = Control.MOUSE_FILTER_STOP)


## Write the status line from the current setting.
func refresh() -> void:
	status_label.text = status_skipped_text if GameSettings.skip_event_dialogue else status_shown_text


## Turn Shorten on (true) or off (false), save it, and close.
func pick(skip: bool) -> void:
	GameSettings.skip_event_dialogue = skip
	if not Engine.is_editor_hint():
		GameSettings.save_settings()
	_close()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	if _is_closed:
		return
	_is_closed = true
	closed.emit()
	queue_free()
