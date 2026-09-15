@tool
class_name ItemDetailSheet
extends Control
## Bottom sheet: one owned item's icon, name, category chip, description and a
## plain-language breakdown of every stat bar it moves. Emits apply_requested
## when the player commits to the apply flow, dismissed when they back out.
## The five EfekRow instances are authored in the scene; setup() fills and
## shows/hides them. The header sits in a category-coloured band overlaid with
## a per-type pattern tile (stripes/dots/weave); each effect is a card in its
## own stat accent with a solid icon tile and a "+N" chip. All those colours
## are per-instance styleboxes built at runtime, since they depend on the item
## and its stats -- the accepted per-call-dynamic exception. Builds no visual
## nodes at runtime.

signal apply_requested(item: ItemData)
signal dismissed

## Fixed on-screen size for the item icon in the sheet's coloured header band.
@export var icon_size: Vector2 = Vector2(176, 176)

## Delay between each visible effect row's pop-in entrance.
const EFEK_STAGGER_STEP := 0.07

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
	"akademis":    "res://Assets/Images/StudentCard/stat_akademis.png",
	"seni_budaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"olahraga":    "res://Assets/Images/StudentCard/stat_olahraga.png",
	"mood":        "res://Assets/Images/StudentCard/stat_mood.png",
	"energy":      "res://Assets/Images/StudentCard/stat_energy.png",
}

## Header-band pattern tiles, one per shape ("stripes"/"dots"/"weave"),
## built once and shared.
static var _pattern_tex: Dictionary = {}

## Map inventory categories to schedule categories for DesignTokens lookup.
const _INV_TO_SCHEDULE := {
	"Buku": "Akademis",
	"Olahraga": "Olahraga",
	"Makanan": "Libur",
}

## Map stat keys to schedule categories that carry a DesignTokens accent, so
## each effect card gets a distinct colour (mood borrows Istirahat's purple,
## energy borrows Libur's amber -- the accents those needs already use).
const _STAT_TO_CATEGORY := {
	"akademis": "Akademis",
	"seni_budaya": "SeniBudaya",
	"olahraga": "Olahraga",
	"mood": "Istirahat",
	"energy": "Libur",
}

## Item category -> the header band's pattern shape.
const _CAT_TO_PATTERN := {
	"Buku": "stripes",
	"Olahraga": "dots",
	"Makanan": "weave",
}

@onready var _scrim: ColorRect = $Scrim
@onready var _sheet: PanelContainer = $Sheet
@onready var _header_band: PanelContainer = $Sheet/Margin/VBox/HeaderBand
@onready var _stripes: TextureRect = $Sheet/Margin/VBox/HeaderBand/HeaderInner/Stripes
@onready var _icon: TextureRect = $Sheet/Margin/VBox/HeaderBand/HeaderInner/TopRow/Icon
@onready var _name_label: Label = $Sheet/Margin/VBox/HeaderBand/HeaderInner/TopRow/TitleCol/NameLabel
@onready var _category_chip: Label = $Sheet/Margin/VBox/HeaderBand/HeaderInner/TopRow/TitleCol/CategoryChip
@onready var _desc_header: Label = $Sheet/Margin/VBox/DescHeader
@onready var _desc_label: Label = $Sheet/Margin/VBox/DescLabel
@onready var _efek_header: Label = $Sheet/Margin/VBox/EfekHeader
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
var _band_style: StyleBoxFlat = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_scrim.color = DesignTokens.load_default().scrim_color()
	if not _scrim.gui_input.is_connected(_on_scrim_input):
		_scrim.gui_input.connect(_on_scrim_input)
	if not _apply_button.pressed.is_connected(_on_apply):
		_apply_button.pressed.connect(_on_apply)
	_icon.custom_minimum_size = icon_size
	_start_apply_idle()


## A slow breathing glow on the apply CTA so it feels alive and inviting.
## Rides on self_modulate, so it never fights the press/release scale juice.
func _start_apply_idle() -> void:
	var t := _apply_button.create_tween().set_loops()
	t.tween_property(_apply_button, "self_modulate", Color(1.15, 1.15, 1.15), 0.85).set_trans(Tween.TRANS_SINE)
	t.tween_property(_apply_button, "self_modulate", Color(1, 1, 1), 0.85).set_trans(Tween.TRANS_SINE)

func setup(item: ItemData, _owned_qty: int) -> void:
	_item = item
	if _icon:
		_icon.texture = item.icon
	if _name_label:
		_name_label.text = item.item_name
	if _desc_label:
		_desc_label.text = item.description if item.description.strip_edges() != "" else "Tidak ada deskripsi."

	var tokens := DesignTokens.load_default()
	var sched: String = _INV_TO_SCHEDULE.get(item.category, "")
	var accent: Color = tokens.category_color(sched) if sched else tokens.text_secondary
	_style_header_band(accent, item.category)
	_style_category_chip(item.category, tokens)
	if _desc_header:
		_desc_header.add_theme_color_override("font_color", accent)
	if _efek_header:
		_efek_header.add_theme_color_override("font_color", accent)

	var boosts := {
		"akademis": item.akademis_boost, "seni_budaya": item.seni_budaya_boost,
		"olahraga": item.olahraga_boost, "mood": item.mood_boost, "energy": item.energy_boost,
	}
	var visible_rows: Array[Control] = []
	for key in _rows:
		var row: Control = _rows[key]
		var amount: int = int(boosts[key])
		row.visible = amount != 0
		if not row.visible:
			continue
		_style_efek_row(row, key, amount, tokens)
		visible_rows.append(row)

	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_open")
		AnimUtils.popup_spring_in(_sheet)
		AnimUtils.wobble(_icon)
		_stagger_efek_rows(visible_rows)

## Paint the header band in the item's category colour, lay the per-type
## pattern tile over it, and switch the item name to light ink so it reads on
## the colour. The band stylebox is per-instance (its colour is the item's
## category) -- the accepted per-call-dynamic exception.
func _style_header_band(accent: Color, category: String) -> void:
	if _band_style == null:
		_band_style = StyleBoxFlat.new()
		_band_style.set_corner_radius_all(18)
		_header_band.add_theme_stylebox_override("panel", _band_style)
	_band_style.bg_color = accent
	if _stripes:
		_stripes.texture = _build_pattern(_CAT_TO_PATTERN.get(category, "stripes"))
	if _name_label:
		_name_label.add_theme_color_override("font_color", DesignTokens.load_default().surface_card)


## The little type pill under the item name: a translucent-white capsule with
## light text, sitting on the coloured band.
func _style_category_chip(category: String, tokens: DesignTokens) -> void:
	if _category_chip == null:
		return
	_category_chip.text = category
	_category_chip.add_theme_color_override("font_color", tokens.surface_card)
	var pill := StyleBoxFlat.new()
	var bg := tokens.surface_card
	bg.a = 0.26
	pill.bg_color = bg
	pill.set_corner_radius_all(22)
	pill.content_margin_left = 20
	pill.content_margin_right = 20
	pill.content_margin_top = 2
	pill.content_margin_bottom = 4
	_category_chip.add_theme_stylebox_override("normal", pill)


## Turn one effect row into a coloured card: a solid icon tile, a faint tinted
## background with a bold left accent, and a filled "+N" chip -- all in the
## stat's own accent so the five effects read as distinct. Per-instance
## styleboxes, the accepted per-call-dynamic exception.
func _style_efek_row(row: Control, key: String, amount: int, tokens: DesignTokens) -> void:
	var stat_cat: String = _STAT_TO_CATEGORY.get(key, "")
	var color: Color = tokens.category_color(stat_cat) if stat_cat else tokens.text_secondary

	var icon_node := row.get_node("Card/Inner/IconTile/NeedIcon") as TextureRect
	icon_node.texture = load(_NEED_ICONS[key])
	icon_node.modulate = tokens.surface_card

	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = color
	tile_style.set_corner_radius_all(14)
	(row.get_node("Card/Inner/IconTile") as PanelContainer).add_theme_stylebox_override("panel", tile_style)

	var card_style := StyleBoxFlat.new()
	var tint := color
	tint.a = 0.13
	card_style.bg_color = tint
	card_style.set_corner_radius_all(14)
	card_style.border_width_left = 6
	card_style.border_color = color
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	(row.get_node("Card") as PanelContainer).add_theme_stylebox_override("panel", card_style)

	var vlabel := row.get_node("Card/Inner/ValueLabel") as Label
	vlabel.text = "+%d" % amount
	vlabel.add_theme_color_override("font_color", tokens.surface_card)
	var chip := StyleBoxFlat.new()
	chip.bg_color = color
	chip.set_corner_radius_all(12)
	chip.content_margin_left = 16
	chip.content_margin_right = 16
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	vlabel.add_theme_stylebox_override("normal", chip)

	(row.get_node("Card/Inner/ExplainLabel") as Label).text = EXPLAIN[key]


## A 24px tile of faint white marks, its shape chosen per item type. Colour is
## always white (the band under it supplies the hue), so each shape is built
## once and shared.
static func _build_pattern(kind: String) -> ImageTexture:
	if _pattern_tex.has(kind):
		return _pattern_tex[kind]
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var mark := Color(1, 1, 1, 0.12)
	for y in s:
		for x in s:
			var on := false
			match kind:
				"dots":
					var dx := x % 12 - 6
					var dy := y % 12 - 6
					on = dx * dx + dy * dy <= 6
				"weave":
					on = (x + y) % 12 < 3 or (x - y + s) % 12 < 3
				_:
					on = (x + y) % 12 < 6
			if on:
				img.set_pixel(x, y, mark)
	var tex := ImageTexture.create_from_image(img)
	_pattern_tex[kind] = tex
	return tex


func _stagger_efek_rows(rows: Array[Control]) -> void:
	for i in rows.size():
		var row := rows[i]
		row.modulate.a = 0.0
		row.position.x = 40.0
		var tw := row.create_tween()
		tw.tween_interval(float(i) * EFEK_STAGGER_STEP + 0.2)
		tw.tween_property(row, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(row, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
