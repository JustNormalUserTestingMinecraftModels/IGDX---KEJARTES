@tool
extends Control
class_name WeekLogsPopup

## Weekly Results' Logs sheet (2026-09-14 weekly-results spec): the week's
## minigames and random events as WeekHistoryRows, over a scrim.
## ResultCheckup instances it when Logs is tapped; it frees itself once it
## closes. Every node is authored in WeekLogsPopup.tscn; the script only
## fills the rows, opens, and closes.
##
## @tool so the editor's test runner can build it. Real side effects --
## audio and tweens -- are gated on Engine.is_editor_hint(); signal wiring is
## not.

## Emitted once, when the sheet closes for any reason.
signal closed

## The history row template, WeekHistoryRow.tscn.
@export var history_row_scene: PackedScene
## The sheet's heading.
@export var title_text: String = "LOGS"
## The close button's label.
@export var close_text: String = "Tutup"
## Shown instead of rows when the week logged nothing.
@export var empty_text: String = "Tidak ada minigame yang dimainkan minggu ini."

@onready var scrim: Panel = $Scrim
@onready var card: PanelContainer = $Center/Card
@onready var title_label: Label = $Center/Card/Content/TitleLabel
@onready var rows: VBoxContainer = $Center/Card/Content/Scroll/Rows
@onready var empty_label: Label = $Center/Card/Content/Scroll/Rows/EmptyLabel
@onready var close_button: Button = $Center/Card/Content/CloseButton

## The instanced rows, in history order.
var _rows: Array = []
var _is_closed := false


func _ready() -> void:
	close_button.pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_gui_input)
	title_label.text = title_text
	close_button.text = close_text
	empty_label.text = empty_text


## One row per history entry, events included; the empty line when there
## are none. Replaces whatever the sheet held before.
func set_history(entries: Array) -> void:
	for child in rows.get_children():
		if child != empty_label:
			rows.remove_child(child)
			child.queue_free()
	_rows.clear()
	empty_label.visible = entries.is_empty()
	for entry in entries:
		var row := history_row_scene.instantiate() as WeekHistoryRow
		rows.add_child(row)
		row.set_entry(entry)
		_rows.append(row)


## How many history rows the sheet holds.
func row_count() -> int:
	return _rows.size()


## Show the sheet. The scrim ignores input until the pop-in is done (the
## popup-dismiss rule), so the tap that opened it can never also close it.
## `animate_rows` plays the rows' stamp-and-shake entrance; ResultCheckup
## passes true on the first open only.
func open(animate_rows: bool = true) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	AudioDirector.play_sfx(&"popup_open")
	Juice.pop_in(card)
	var t := Juice.tokens()
	var arm := create_tween()
	arm.tween_interval(t.dur_normal)
	arm.tween_callback(func(): scrim.mouse_filter = Control.MOUSE_FILTER_STOP)
	if animate_rows and not _rows.is_empty():
		# The rows' entrance rides the same tween, a beat after popup_open, so
		# the two cues land as two gestures (tests/test_audio_coverage.gd's
		# double-fire guard). A tween dies with the sheet; an awaited
		# SceneTree timer would resume on a freed sheet if Tutup is tapped
		# during the pop-in.
		arm.tween_callback(_play_rows_entrance)


## Close the sheet and hand control back. Safe to call twice.
func close() -> void:
	if _is_closed:
		return
	_is_closed = true
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_close")
	closed.emit()
	queue_free()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close()


## Rows stagger in; a win stamps into place, a loss shakes, an event does
## neither.
func _play_rows_entrance() -> void:
	Juice.stagger_in(_rows)
	for row in _rows:
		if not is_instance_valid(row) or row.is_event():
			continue
		if row.is_win():
			AudioDirector.play_sfx(&"stamp")
		else:
			Juice.shake(row)
