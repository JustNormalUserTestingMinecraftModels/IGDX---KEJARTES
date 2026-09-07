@tool
class_name ApplyStudentRow
extends PanelContainer
## One selectable student in ApplyItemScreen: portrait, name, a LELAH badge
## when too tired to benefit, and up to five authored StatBarRow instances --
## only the bars the item moves are shown. Selecting the row previews the
## post-apply values on those bars. Nothing is built here; setup() fills the
## authored template instances.

signal selection_changed

## Logical boost name -> the roster Dictionary key it writes. Fixed mapping:
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy (the project's canonical keys).
const KEY := {
	"akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
	"mood": "kepribadian1", "energy": "kepribadian2",
}

## kepribadian2 (energy) at or below this forces "Izin" -- such a student
## cannot take the item, so the row's checkbox is disabled.
@export var tired_energy_threshold: float = 5.0

const _BADGE := "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn"
const _BAR_TITLE := {
	"akademis": "Akademis", "seni_budaya": "Seni Budaya", "olahraga": "Olahraga",
	"mood": "Mood", "energy": "Energi",
}
const _BAR_CATEGORY := {
	"akademis": "Akademis", "seni_budaya": "SeniBudaya", "olahraga": "Olahraga",
	"mood": "Istirahat", "energy": "Libur",
}

@onready var _check: CheckBox = $Margin/HBox/Check
@onready var _portrait: TextureRect = $Margin/HBox/Portrait
@onready var _name_label: Label = $Margin/HBox/Col/HeaderRow/NameLabel
@onready var _badge_slot: HBoxContainer = $Margin/HBox/Col/HeaderRow/BadgeSlot
@onready var _bar_rows := {
	"akademis":    $Margin/HBox/Col/BarRowAkademis,
	"seni_budaya": $Margin/HBox/Col/BarRowSeni,
	"olahraga":    $Margin/HBox/Col/BarRowOlahraga,
	"mood":        $Margin/HBox/Col/BarRowMood,
	"energy":      $Margin/HBox/Col/BarRowEnergy,
}

var student: Dictionary = {}
var _boosts: Dictionary = {}

func _ready() -> void:
	if not _check.toggled.is_connected(_on_toggled):
		_check.toggled.connect(_on_toggled)

func setup(p_student: Dictionary, boosts: Dictionary) -> void:
	student = p_student
	_boosts = {}
	for k in boosts:
		if int(boosts[k]) != 0:
			_boosts[k] = int(boosts[k])

	_name_label.text = str(student.get("name", "?"))
	var port_path := str(student.get("portrait", ""))
	if port_path != "" and ResourceLoader.exists(port_path):
		_portrait.texture = load(port_path)

	var is_tired := float(student.get("kepribadian2", 100.0)) <= tired_energy_threshold
	_check.disabled = is_tired
	for c in _badge_slot.get_children():
		c.queue_free()
	if is_tired:
		_add_badge("LELAH", DesignTokens.load_default().state_danger)

	for key in _bar_rows:
		var row: Control = _bar_rows[key]
		row.visible = _boosts.has(key)
		if not row.visible:
			continue
		var cur := float(student.get(KEY[key], 0.0))
		(row.get_node("NameLabel") as Label).text = _BAR_TITLE[key]
		var bar: Range = row.get_node("Bar")
		bar.set("category", _BAR_CATEGORY[key])
		bar.value = cur
		(row.get_node("ValueLabel") as Label).text = "%d/100" % int(cur)
		(row.get_node("DeltaLabel") as Label).text = "--"

func set_preview(active: bool) -> void:
	var tok := DesignTokens.load_default()
	for key in _bar_rows:
		var row: Control = _bar_rows[key]
		if not row.visible:
			continue
		var cur := float(student.get(KEY[key], 0.0))
		var bar: Range = row.get_node("Bar")
		var val_lbl := row.get_node("ValueLabel") as Label
		var delta_lbl := row.get_node("DeltaLabel") as Label
		if active:
			var target: float = clampf(cur + _boosts[key], 0.0, 100.0)
			if Engine.is_editor_hint():
				bar.value = target
			else:
				Juice.fill_bar(bar, target)
			val_lbl.text = "%d ➜ %d" % [int(cur), int(target)]
			if target >= 100.0 and cur >= 100.0:
				delta_lbl.text = "MAKS"
				delta_lbl.self_modulate = tok.text_secondary
			else:
				delta_lbl.text = "(+%d)" % int(target - cur)
				delta_lbl.self_modulate = tok.state_success
			if not Engine.is_editor_hint():
				AnimUtils.squash_bounce(delta_lbl)
		else:
			if Engine.is_editor_hint():
				bar.value = cur
			else:
				Juice.fill_bar(bar, cur)
			val_lbl.text = "%d/100" % int(cur)
			delta_lbl.text = "--"
			delta_lbl.self_modulate = tok.text_secondary
	scale = Vector2(1.02, 1.02) if active else Vector2.ONE

func is_selected() -> bool:
	return _check.button_pressed and not _check.disabled

func can_select() -> bool:
	return not _check.disabled

func set_selected(on: bool) -> void:
	if not _check.disabled:
		_check.button_pressed = on

func selected_student_id() -> int:
	return int(student.get("id", -1))

func _on_toggled(pressed: bool) -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"select")
	set_preview(pressed)
	selection_changed.emit()

func _add_badge(text: String, tint: Color) -> void:
	var chip := (load(_BADGE) as PackedScene).instantiate()
	chip.self_modulate = tint
	var lbl := chip.get_node_or_null("Text") as Label
	if lbl:
		lbl.text = " %s " % text
	_badge_slot.add_child(chip)
