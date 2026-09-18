@tool
class_name SkinSelectPopup
extends Control

## The Lobby's skin picker (SkinSelectPopup.tscn; mockups
## skinselect_mockup.png and skinselectoption_mockup.png). A blurred screen,
## a card of up to four roster students in their current skin, and SETUJU.
## Tapping a student opens OptionLayer: a second blur over the card (a
## BackBufferCopy gives it a fresh screen copy, card included) and a
## scrollable column of that student's skins, lined up over the tapped card.
## Picking an unlocked skin equips it at once (GameState.equip_skin) and
## closes the column; a tap on the blur closes it unchanged. SETUJU or back
## closes the popup, emits `closed` and frees it.
##
## Opened by loby.gd with open(GameState.approved_students). @tool so the
## test runner can drive it; the fades are skipped in the editor.

signal closed

## One tile per skin in the option column, instanced per open: the count
## depends on the student tapped, so it is per-call dynamic content.
@export var tile_scene: PackedScene = preload("res://Scenes/Skins/SkinOptionTile.tscn")
## Seconds the popup takes to fade in or out.
@export var fade_time: float = 0.2

const MAX_SLOTS := 4

var _students: Array = []
var _open_slot: int = -1
var _closing: bool = false


func _ready() -> void:
	for i in MAX_SLOTS:
		var slot := _slot(i)
		if not slot.pressed.is_connected(open_column):
			slot.pressed.connect(open_column.bind(i))
	var setuju := get_node(^"Safe/UI/Card/Setuju") as Button
	if not setuju.pressed.is_connected(close):
		setuju.pressed.connect(close)
	var blur2 := get_node(^"Safe/UI/OptionLayer/Blur2") as Control
	if not blur2.gui_input.is_connected(_on_blur2_input):
		blur2.gui_input.connect(_on_blur2_input)


## Fills the card from `students` (roster dicts, first four) and fades in.
func open(students: Array) -> void:
	_students = students.slice(0, MAX_SLOTS)
	for i in MAX_SLOTS:
		var slot := _slot(i)
		slot.visible = i < _students.size()
		if slot.visible:
			slot.show_student(_students[i])
	close_column()
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	AudioDirector.play_sfx(&"tap")


## Shows slot `index`'s skins in the option column over that slot.
func open_column(index: int) -> void:
	if index < 0 or index >= _students.size():
		return
	_open_slot = index
	var student_name := str(_students[index].get("name", ""))
	var list := get_node(^"Safe/UI/OptionLayer/Column/Scroll/List")
	for old in list.get_children():
		list.remove_child(old)
		old.queue_free()
	for id in StudentSkins.skins_for(student_name):
		var tile := tile_scene.instantiate() as SkinOptionTile
		list.add_child(tile)
		tile.show_skin(student_name, id, not GameState.is_skin_unlocked(student_name, id))
		tile.pressed.connect(_on_tile_pressed.bind(id))
	var column := get_node(^"Safe/UI/OptionLayer/Column") as Control
	var slot := _slot(index)
	if slot.is_inside_tree() and column.is_inside_tree():
		column.global_position.x = slot.global_position.x + (slot.size.x - column.size.x) * 0.5
	(get_node(^"Safe/UI/OptionLayer") as Control).show()


func close_column() -> void:
	_open_slot = -1
	(get_node(^"Safe/UI/OptionLayer") as Control).hide()


## Fades out, emits `closed` and frees the popup. Idempotent.
func close() -> void:
	if _closing:
		return
	_closing = true
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_time)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _open_slot >= 0:
		close_column()
	else:
		close()


func _on_tile_pressed(id: String) -> void:
	if _open_slot < 0:
		return
	var student: Dictionary = _students[_open_slot]
	if GameState.equip_skin(str(student.get("name", "")), id):
		_slot(_open_slot).show_student(student)
		close_column()


func _on_blur2_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		close_column()


func _slot(i: int) -> SkinSlot:
	return get_node("Safe/UI/Card/Slots/Slot%d" % (i + 1)) as SkinSlot
