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

const _CONFIRM_FMT := ">>>  Pakai ke %d Siswa!  <<<"
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
@onready var _summary_chips := {
	"akademis": $Margin/Card/Margin/VBox/EffectSummary/ChipAkademis,
	"seni_budaya": $Margin/Card/Margin/VBox/EffectSummary/ChipSeni,
	"olahraga": $Margin/Card/Margin/VBox/EffectSummary/ChipOlahraga,
	"mood": $Margin/Card/Margin/VBox/EffectSummary/ChipMood,
	"energy": $Margin/Card/Margin/VBox/EffectSummary/ChipEnergi,
}
@onready var _select_all_button: Button = $Margin/Card/Margin/VBox/Actions/SecondaryRow/SelectAllButton
@onready var _cancel_button: Button = $Margin/Card/Margin/VBox/Actions/SecondaryRow/CancelButton
@onready var _confirm_button: Button = $Margin/Card/Margin/VBox/Actions/ConfirmButton

var _item: ItemData = null
var _rows: Array = []
var _drag := false
var _drag_y := 0.0
var _drag_v0 := 0
var _committing := false
var _confirm_idle: Tween = null

func _ready() -> void:
	_select_all_button.text = "Pilih Semua"
	_cancel_button.text = "Batal"
	_confirm_button.text = _CONFIRM_FMT % 0
	($Margin/Card/Margin/VBox/TitleLabel as Label).text = "Pakai ke Siapa?"
	if Engine.is_editor_hint():
		return
	var pill := StyleBoxFlat.new()
	pill.bg_color = DesignTokens.load_default().surface_sunken
	pill.set_corner_radius_all(22)
	pill.content_margin_left = 20
	pill.content_margin_right = 20
	pill.content_margin_top = 4
	pill.content_margin_bottom = 6
	_recap_count.add_theme_stylebox_override("normal", pill)
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
	_style_summary_chips(p_item)

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

## Fill the "Menambah" strip: one coloured pill per boosted stat, the rest
## hidden. Each pill's colour is the stat's accent -- a per-instance stylebox,
## the accepted per-call-dynamic exception.
func _style_summary_chips(it: ItemData) -> void:
	var tokens := DesignTokens.load_default()
	var to_cat := {"akademis": "Akademis", "seni_budaya": "SeniBudaya",
		"olahraga": "Olahraga", "mood": "Istirahat", "energy": "Libur"}
	var boosts := _boosts_of(it)
	for key in _summary_chips:
		var chip: Label = _summary_chips[key]
		var amount: int = int(boosts.get(key, 0))
		chip.visible = amount != 0
		if amount == 0:
			continue
		chip.text = "%s +%d" % [_LABELS[key], amount]
		chip.add_theme_color_override("font_color", tokens.surface_card)
		var pill := StyleBoxFlat.new()
		pill.bg_color = tokens.category_color(to_cat.get(key, ""))
		pill.set_corner_radius_all(16)
		pill.content_margin_left = 16
		pill.content_margin_right = 16
		pill.content_margin_top = 4
		pill.content_margin_bottom = 4
		chip.add_theme_stylebox_override("normal", pill)

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
	# Each pick will spend one item, so show the stock dropping live.
	if n > 0:
		_recap_count.text = "Sisa ×%d → ×%d" % [owned, maxi(owned - n, 0)]
	else:
		_recap_count.text = "Sisa ×%d" % owned
	# Out of stock for more picks: grey the unpicked students so it is clear
	# you cannot add another.
	var at_cap := n >= owned
	for row in _rows:
		row.apply_cap(at_cap)
	_update_confirm_idle()


## Keep a slow breathing glow on the confirm CTA while it is usable, and stop
## it (resetting the tint) whenever nothing is picked, so a greyed-out button
## never pulses.
func _update_confirm_idle() -> void:
	if Engine.is_editor_hint():
		return
	if _confirm_button.disabled:
		if _confirm_idle != null:
			_confirm_idle.kill()
			_confirm_idle = null
		_confirm_button.self_modulate = Color.WHITE
	elif _confirm_idle == null or not _confirm_idle.is_valid():
		_confirm_idle = _confirm_button.create_tween().set_loops()
		_confirm_idle.tween_property(_confirm_button, "self_modulate",
			Color(1.15, 1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
		_confirm_idle.tween_property(_confirm_button, "self_modulate",
			Color(1, 1, 1), 0.8).set_trans(Tween.TRANS_SINE)

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
	await _pop_out()
	applied.emit(res["results"])
	queue_free()


## Close with a little pop: the card scales up, then shrinks away as the
## whole screen fades.
func _pop_out() -> void:
	var target := $Margin/Card as Control
	target.pivot_offset = target.size * 0.5
	var tw := create_tween()
	tw.tween_property(target, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(target, "scale", Vector2(0.7, 0.7), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	await tw.finished

func _play_payoff(results: Array) -> void:
	var all_gained := true
	var tier := 0
	for r in results:
		var row = _row_for(int(r["student_id"]))
		var lines := _gain_lines(r)
		if lines == "":
			all_gained = false
		if row != null:
			row.play_apply_rise()
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
		# Give the bar's rise time to read before the next student's.
		await get_tree().create_timer(maxf(payoff_stagger, 0.45)).timeout
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
