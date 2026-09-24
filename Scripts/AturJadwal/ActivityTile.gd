@tool
class_name ActivityTile
extends Button

## One tile of the Penjadwalan picker (2026-09-24 visual polish, D9-D14),
## which replaced the old ActivityRow list. A cream tile with the
## category's icon as a large faded watermark behind crisp text: the name,
## then the effect in the picker's arrow language -- green up-arrows and
## the exact gain on a skill tile, coin pips and "Cuan" on Wirausaha, and
## red/green arrows for energy and mood on every tile.
##
## Tapping a tile only SELECTS it; atur_jadwal.gd assigns the day when the
## player confirms with Pilih. `selected` swaps the tile's panel to the
## gold-ringed variation and shows the check badge. The favourite gets a
## gold Favorit ribbon.
##
## Z-order matters: Watermark sits before Content in the tree, so the text
## always draws above the icon, never under it.

## One of: Akademis, SeniBudaya, Olahraga, Wirausaha, Istirahat.
@export var category: String = "Akademis"

## The Indonesian label the player reads. Deliberately separate from
## `category`: the UI says "Atletik" where the code says "Olahraga".
@export var display_name: String = "Akademik":
	set(value):
		display_name = value
		if is_inside_tree():
			var label := get_node_or_null("Content/Lines/NameLabel") as Label
			if label:
				label.text = value

## The faded icon behind the text. Lives on this root rather than on
## Watermark because overrides only serialise on an instanced scene's root.
@export var watermark_texture: Texture2D:
	set(value):
		watermark_texture = value
		if is_inside_tree():
			var mark := get_node_or_null("Watermark") as TextureRect
			if mark:
				mark.texture = value

## How strongly the watermark shows through, 0-1. About 13% reads as a
## ghost behind the text on a full-colour icon; a pale motif needs more.
@export_range(0.0, 1.0, 0.01) var watermark_alpha: float = 0.13:
	set(value):
		watermark_alpha = value
		if is_inside_tree():
			var mark := get_node_or_null("Watermark") as CanvasItem
			if mark:
				mark.modulate.a = value

## True while this is the picker's current choice.
var selected := false:
	set(value):
		selected = value
		if is_inside_tree():
			_apply_selected()


func _ready() -> void:
	var label := get_node_or_null("Content/Lines/NameLabel") as Label
	if label:
		label.text = display_name
	var mark := get_node_or_null("Watermark") as TextureRect
	if mark:
		mark.texture = watermark_texture
		mark.modulate.a = watermark_alpha
	_apply_selected()


## Gold ring and check while selected, the plain tile otherwise.
func _apply_selected() -> void:
	var sheet := get_node_or_null("Sheet") as Panel
	if sheet:
		sheet.theme_type_variation = &"PickerTileSelected" if selected else &"PickerTile"
	var check := get_node_or_null("CheckBadge") as CanvasItem
	if check:
		check.visible = selected


## True when this tile is the student's favourite subject -- a skill tile
## matching their specialty. Wirausaha and Libur are never a favourite.
func is_favorit(student: Dictionary) -> bool:
	return ActivityPreview.is_skill(category) and ActivityPreview.is_specialty(category, student)


## Repopulate this tile for the given student and grade. Every count comes
## from ActivityPreview, which reads Balance.
func refresh(student: Dictionary, grade: int) -> void:
	var gain_row := get_node_or_null("Content/Lines/GainRow") as Control
	var gain_meter := get_node_or_null("Content/Lines/GainRow/GainMeter") as EffectMeter
	var gain_value := get_node_or_null("Content/Lines/GainRow/GainValue") as Label
	if ActivityPreview.is_skill(category):
		if gain_meter:
			gain_meter.show_effect(ActivityPreview.gain_arrows(category, student, grade),
				EffectMeter.Kind.GAIN)
		if gain_value:
			gain_value.text = "+%d" % int(ActivityPreview.skill_gain(category, student, grade))
		if gain_row:
			gain_row.visible = true
	elif category == "Wirausaha":
		if gain_meter:
			gain_meter.show_effect(ActivityPreview.earning_pips(), EffectMeter.Kind.COIN)
		if gain_value:
			gain_value.text = "Cuan"
		if gain_row:
			gain_row.visible = true
	elif gain_row:
		# Libur gains no skill and earns nothing; its energy and mood arrows
		# below are its whole effect.
		gain_row.visible = false

	_show_need("Energy", ActivityPreview.energy_delta(category, student),
		ActivityPreview.energy_arrows(category, student))
	_show_need("Mood", ActivityPreview.mood_delta(category, student),
		ActivityPreview.mood_arrows(category, student))

	var ribbon := get_node_or_null("FavoritRibbon") as CanvasItem
	if ribbon:
		ribbon.visible = is_favorit(student)


## One need's meter: green up for a recovery, red down for a cost.
func _show_need(which: String, delta: float, count: int) -> void:
	var meter := get_node_or_null("Content/Lines/NeedsRow/%sMeter" % which) as EffectMeter
	if meter == null:
		return
	var kind := EffectMeter.Kind.GAIN if delta > 0.0 else EffectMeter.Kind.COST
	meter.show_effect(count, kind)
