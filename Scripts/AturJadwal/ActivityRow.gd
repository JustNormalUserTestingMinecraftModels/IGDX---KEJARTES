@tool
class_name ActivityRow
extends Button

## One row of the Penjadwalan popup: an icon, a pill of preview numbers,
## and the category name. The whole row is the Button -- the player taps
## anywhere on it to assign that activity to the selected day.
##
## The three skill rows also carry a StatBar showing progress toward the
## student's target; Wirausaha and Libur have no target, so their pill
## holds only chips.

## One of: Akademis, SeniBudaya, Olahraga, Wirausaha, Istirahat.
## Drives both the preview arithmetic and the StatBar's tint -- without the
## sync below, every row's bar would keep the scene's default tint.
@export var category: String = "Akademis":
	set(value):
		category = value
		if is_inside_tree():
			var bar := get_node_or_null("Pill/StatBar") as StatBar
			if bar:
				bar.category = value

## The Indonesian label the player reads. Deliberately separate from
## `category`: the UI says "Atletik" where the code says "Olahraga".
@export var display_name: String = "Akademik":
	set(value):
		display_name = value
		if is_inside_tree():
			var label := get_node_or_null("NameLabel") as Label
			if label:
				label.text = value

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			var icon := get_node_or_null("IconBox/Icon") as TextureRect
			if icon:
				icon.texture = value

## Icons for the inline chips, keyed by the "icon" field ActivityPreview
## returns. Assigned in the scene so the paths live in one place.
@export var energy_icon: Texture2D
@export var mood_icon: Texture2D
@export var money_icon: Texture2D


func _ready() -> void:
	var label := get_node_or_null("NameLabel") as Label
	if label:
		label.text = display_name
	var icon := get_node_or_null("IconBox/Icon") as TextureRect
	if icon:
		icon.texture = icon_texture
	var bar := get_node_or_null("Pill/StatBar") as StatBar
	if bar:
		bar.category = category


func _icon_for(key: String) -> Texture2D:
	match key:
		"energy": return energy_icon
		"mood": return mood_icon
		"money": return money_icon
		_: return null


## Repopulate this row for the given student. `progress_percent` drives the
## StatBar fill on skill rows and is ignored on Wirausaha/Libur, which have
## no target to progress toward.
func refresh(student: Dictionary, grade: int, progress_percent: float) -> void:
	var chips := get_node_or_null("Pill/Chips")
	if chips == null:
		return

	# Clear first: refresh is called every time the popup opens, and
	# appending without clearing stacks stale chips behind the live ones.
	for child in chips.get_children():
		child.queue_free()
		chips.remove_child(child)

	for chip in ActivityPreview.chips_for(category, student, grade):
		var tex := _icon_for(chip["icon"])
		if tex != null:
			var chip_icon := TextureRect.new()
			chip_icon.texture = tex
			chip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip_icon.custom_minimum_size = Vector2(48, 48)
			chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chips.add_child(chip_icon)
		var chip_label := Label.new()
		chip_label.theme_type_variation = &"PreviewChipLabel"
		chip_label.text = chip["text"]
		chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(chip_label)

	var bar := get_node_or_null("Pill/StatBar") as StatBar
	if bar:
		# Only the three skill rows carry a bar; the others left it out.
		bar.set_stat(progress_percent)
