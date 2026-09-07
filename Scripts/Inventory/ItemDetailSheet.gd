@tool
class_name ItemDetailSheet
extends Control
## Bottom sheet: one owned item's icon, name, category chip, description and a
## plain-language breakdown of every stat bar it moves. Emits apply_requested
## when the player commits to the apply flow, dismissed when they back out.
## Builds nothing at runtime -- the five EfekRow instances are authored in the
## scene; setup() only fills and shows/hides them.

signal apply_requested(item: ItemData)
signal dismissed

## Fixed on-screen size for the item icon in the sheet's top row.
@export var icon_size: Vector2 = Vector2(140, 140)

## Plain-Indonesian, one line per bar, shown after the "+N". Fixed game copy,
## not a tuning knob -- hence a const, not an @export.
const EXPLAIN := {
	"akademis":    "Nilai akademik. Salah satu dari tiga target kelulusan kelas.",
	"seni_budaya": "Nilai seni & budaya. Salah satu target kelulusan kelas.",
	"olahraga":    "Nilai olahraga. Salah satu target kelulusan kelas.",
	"mood":        "Semangat siswa. Mood rendah menurunkan hasil belajar mingguan.",
	"energy":      "Tenaga harian. Energi 5 ke bawah memaksa siswa Izin -- istirahat paksa, tanpa belajar.",
}

const _NEED_ICONS := {
	"akademis":    "res://Assets/Images/UI/Placeholders/icon_akademis.svg",
	"seni_budaya": "res://Assets/Images/UI/Placeholders/icon_seni.svg",
	"olahraga":    "res://Assets/Images/UI/Placeholders/icon_olahraga.svg",
	"mood":        "res://Assets/Images/UI/Placeholders/icon_mood.svg",
	"energy":      "res://Assets/Images/UI/Placeholders/icon_energy.svg",
}

@onready var _scrim: ColorRect = $Scrim
@onready var _sheet: PanelContainer = $Sheet
@onready var _icon: TextureRect = $Sheet/Margin/VBox/TopRow/Icon
@onready var _name_label: Label = $Sheet/Margin/VBox/TopRow/TitleCol/NameLabel
@onready var _category_chip: Control = $Sheet/Margin/VBox/TopRow/TitleCol/CategoryChip
@onready var _desc_label: Label = $Sheet/Margin/VBox/DescLabel
@onready var _apply_button: Button = $Sheet/Margin/VBox/ApplyButton
@onready var _rows := {
	"akademis":    $Sheet/Margin/VBox/EfekList/RowAkademis,
	"seni_budaya": $Sheet/Margin/VBox/EfekList/RowSeni,
	"olahraga":    $Sheet/Margin/VBox/EfekList/RowOlahraga,
	"mood":        $Sheet/Margin/VBox/EfekList/RowMood,
	"energy":      $Sheet/Margin/VBox/EfekList/RowEnergy,
}

var _item: ItemData = null
var _dismissing := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_scrim.color = DesignTokens.load_default().scrim_color()
	if not _scrim.gui_input.is_connected(_on_scrim_input):
		_scrim.gui_input.connect(_on_scrim_input)
	if not _apply_button.pressed.is_connected(_on_apply):
		_apply_button.pressed.connect(_on_apply)
	_icon.custom_minimum_size = icon_size

func setup(item: ItemData, _owned_qty: int) -> void:
	_item = item
	if _icon:
		_icon.texture = item.icon
	if _name_label:
		_name_label.text = item.item_name
	var chip_lbl := _category_chip.get_node_or_null("Text") as Label
	if chip_lbl:
		chip_lbl.text = " %s " % item.category
	if _desc_label:
		_desc_label.text = item.description if item.description.strip_edges() != "" else "Tidak ada deskripsi."

	var boosts := {
		"akademis": item.akademis_boost, "seni_budaya": item.seni_budaya_boost,
		"olahraga": item.olahraga_boost, "mood": item.mood_boost, "energy": item.energy_boost,
	}
	for key in _rows:
		var row: Control = _rows[key]
		var amount: int = int(boosts[key])
		row.visible = amount != 0
		if not row.visible:
			continue
		(row.get_node("NeedIcon") as TextureRect).texture = load(_NEED_ICONS[key])
		(row.get_node("ValueLabel") as Label).text = "+%d" % amount
		(row.get_node("ExplainLabel") as Label).text = EXPLAIN[key]

	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_open")
		AnimUtils.popup_spring_in(_sheet)
		AnimUtils.wobble(_icon)

func _on_apply() -> void:
	if _item == null:
		return
	_apply_button.disabled = true
	AudioDirector.play_sfx(&"confirm")
	apply_requested.emit(_item)

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _sheet.get_global_rect().has_point(event.global_position):
			_dismiss()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_dismiss()

func _dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	AudioDirector.play_sfx(&"popup_close")
	if Engine.is_editor_hint():
		dismissed.emit()
		queue_free()
		return
	AnimUtils.popup_spring_out(_sheet, _scrim, func():
		dismissed.emit()
		queue_free())
