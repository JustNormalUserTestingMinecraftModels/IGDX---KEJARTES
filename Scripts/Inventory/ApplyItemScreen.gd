@tool
class_name ApplyItemScreen
extends Control
## Full-screen "apply this item to which students" step. Multi-select with a
## live per-student StatBar preview, then a staged payoff: a RewardBurst and
## floating gained-stat text per student with a rising cue, then one
## screen-wide CelebrationConfetti if every pick gained. Emits applied(results)
## (the Array from GameState.use_item_on_students) or cancelled. Student rows
## are ApplyStudentRow PackedScene instances -- no runtime chrome here.

signal applied(results: Array)
signal cancelled

## One selectable student card.
@export var student_row_scene: PackedScene = preload("res://Scenes/Inventory/ApplyStudentRow.tscn")
## Per-student star burst fired on confirm.
@export var reward_burst_scene: PackedScene = preload("res://Scenes/SchoolSimulation/RewardBurst.tscn")
## Screen-wide fall, only when every pick gained.
@export var confetti_scene: PackedScene = preload("res://Scenes/SchoolSimulation/CelebrationConfetti.tscn")
## Seconds between one student's payoff and the next.
@export var payoff_stagger: float = 0.18

const _CONFIRM_FMT := "Pakai (%d Siswa)"
const _LABELS := {"akademis": "Akademis", "seni_budaya": "Seni", "olahraga": "Olahraga",
	"mood": "Mood", "energy": "Energi"}
const _DELTA_LABELS := [
	["akademis_delta", "Akademis"], ["seni_delta", "Seni"], ["olahraga_delta", "Olahraga"],
	["mood_delta", "Mood"], ["energy_delta", "Energi"],
]

@onready var _rows_box: VBoxContainer = $Margin/Card/Margin/VBox/Scroll/Rows
@onready var _scroll: ScrollContainer = $Margin/Card/Margin/VBox/Scroll
@onready var _recap_icon: TextureRect = $Margin/Card/Margin/VBox/RecapStrip/RecapIcon
@onready var _recap_name: Label = $Margin/Card/Margin/VBox/RecapStrip/RecapName
@onready var _recap_count: Label = $Margin/Card/Margin/VBox/RecapStrip/RecapCount
@onready var _effect_summary: Label = $Margin/Card/Margin/VBox/EffectSummary
@onready var _select_all_button: Button = $Margin/Card/Margin/VBox/Actions/SecondaryRow/SelectAllButton
@onready var _cancel_button: Button = $Margin/Card/Margin/VBox/Actions/SecondaryRow/CancelButton
@onready var _confirm_button: Button = $Margin/Card/Margin/VBox/Actions/ConfirmButton

var _item: ItemData = null
var _rows: Array = []
var _drag := false
var _drag_y := 0.0
var _drag_v0 := 0
var _committing := false

func _ready() -> void:
	_select_all_button.text = "Pilih Semua"
	_cancel_button.text = "Batal"
	_confirm_button.text = _CONFIRM_FMT % 0
	($Margin/Card/Margin/VBox/TitleLabel as Label).text = "Pakai ke Siapa?"
	if Engine.is_editor_hint():
		return
	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	_select_all_button.pressed.connect(_on_select_all)
	_cancel_button.pressed.connect(_on_cancel)
	_confirm_button.pressed.connect(_on_confirm)
	_scroll.gui_input.connect(_on_scroll_input)

func setup(p_item: ItemData) -> void:
	_item = p_item
	_recap_icon.texture = p_item.icon
	_recap_name.text = p_item.item_name
	_recap_count.text = "Sisa ×%d" % GameState.get_inventory_quantity(p_item.item_name)
	_effect_summary.text = _summary_text(p_item)

	for c in _rows_box.get_children():
		c.queue_free()
	_rows.clear()
	var boosts := _boosts_of(p_item)
	for student in GameState.approved_students:
		var row = student_row_scene.instantiate()
		_rows_box.add_child(row)
		row.setup(student, boosts)
		row.selection_changed.connect(_refresh_confirm)
		_rows.append(row)
	if not Engine.is_editor_hint():
		Juice.stagger_in(_rows)
	_refresh_confirm()

func _boosts_of(it: ItemData) -> Dictionary:
	var raw := {"akademis": it.akademis_boost, "seni_budaya": it.seni_budaya_boost,
		"olahraga": it.olahraga_boost, "mood": it.mood_boost, "energy": it.energy_boost}
	var out := {}
	for k in raw:
		if int(raw[k]) != 0:
			out[k] = int(raw[k])
	return out

func _summary_text(it: ItemData) -> String:
	var b := _boosts_of(it)
	var parts: Array[String] = []
	for k in b:
		parts.append("%s +%d" % [_LABELS[k], b[k]])
	return "Menambah: %s per siswa." % ", ".join(parts)

func _selected_ids() -> Array:
	var ids: Array = []
	for row in _rows:
		if row.is_selected():
			ids.append(row.selected_student_id())
	return ids

func _refresh_confirm() -> void:
	var n := _selected_ids().size()
	var owned := GameState.get_inventory_quantity(_item.item_name) if _item != null else 0
	_confirm_button.text = _CONFIRM_FMT % n
	_confirm_button.disabled = n == 0 or n > owned

func _on_select_all() -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"select")
	var any_off := false
	for row in _rows:
		if row.can_select() and not row.is_selected():
			any_off = true
			break
	for row in _rows:
		if row.can_select():
			row.set_selected(any_off)
	_refresh_confirm()

func _on_cancel() -> void:
	if _committing:
		return
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"cancel")
	cancelled.emit()
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _committing:
		_on_cancel()

func _on_confirm() -> void:
	var ids := _selected_ids()
	var res: Dictionary = GameState.use_item_on_students(_item, ids)
	if not res["applied"]:
		AudioDirector.play_sfx(&"error")
		return
	_committing = true
	_confirm_button.disabled = true
	_select_all_button.disabled = true
	await _play_payoff(res["results"])
	applied.emit(res["results"])
	queue_free()

func _play_payoff(results: Array) -> void:
	var all_gained := true
	var tier := 0
	for r in results:
		var row = _row_for(int(r["student_id"]))
		var lines := _gain_lines(r)
		if lines == "":
			all_gained = false
		if row != null:
			var burst = reward_burst_scene.instantiate()
			burst.plays_sfx = false
			row.add_child(burst)
			burst.position = row.size * 0.5
			burst.fire()
			if lines != "":
				AnimUtils.create_floating_text(self, lines,
					row.global_position + row.size * 0.5,
					DesignTokens.load_default().state_success)
		AudioDirector.play_sfx([&"star_earn_1", &"star_earn_2", &"star_earn_3"][mini(tier, 2)])
		tier += 1
		await get_tree().create_timer(payoff_stagger).timeout
	if all_gained and not results.is_empty():
		var confetti = confetti_scene.instantiate()
		add_child(confetti)
		confetti.fire()
	AudioDirector.play_sfx(&"result_fanfare")

func _gain_lines(r: Dictionary) -> String:
	var parts: Array[String] = []
	for pair in _DELTA_LABELS:
		if float(r.get(pair[0], 0.0)) > 0.0:
			parts.append("%s +%d" % [pair[1], int(r[pair[0]])])
	return "\n".join(parts)

func _row_for(sid: int):
	for row in _rows:
		if row.selected_student_id() == sid:
			return row
	return null

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		_drag_y = event.global_position.y
		_drag_v0 = _scroll.scroll_vertical
	elif event is InputEventMouseMotion and _drag:
		_scroll.scroll_vertical = int(_drag_v0 - (event.global_position.y - _drag_y))
