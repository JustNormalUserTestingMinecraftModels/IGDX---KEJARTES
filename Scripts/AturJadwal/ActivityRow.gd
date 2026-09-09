@tool
class_name ActivityRow
extends Button

## One row of the Penjadwalan popup: a cream slab carrying the category
## icon on its left, a recessed track to its right holding the preview
## numbers, and the category name overlapping the bottom edge. The whole
## row is the Button -- the player taps anywhere on it to assign that
## activity to the selected day.
##
## Rows with a target (the three skills) draw a StatBar inside that track.
## Wirausaha and Libur have no target, so their track is the ghost
## variation: same silhouette, alpha-ramped, holding chips rather than a
## bar. Before 2026-09-10 the row was a bordered brown slab with a darker
## pill inset into it; the cream pass collapsed that to one surface.

## One of: Akademis, SeniBudaya, Olahraga, Wirausaha, Istirahat.
## Drives both the preview arithmetic and the StatBar's tint -- without the
## sync below, every row's bar would keep the scene's default tint.
@export var category: String = "Akademis":
	set(value):
		category = value
		if is_inside_tree():
			var bar := get_node_or_null("Container/Pill/StatBar") as StatBar
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

## The category icon on Container/Icon, left of the row.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			var icon := get_node_or_null("Container/Icon") as TextureRect
			if icon:
				icon.texture = value

## Icons for the inline chips, keyed by the "icon" field ActivityPreview
## returns. Assigned in the scene so the paths live in one place.
@export var energy_icon: Texture2D
## Same as energy_icon, for the mood-cost chip.
@export var mood_icon: Texture2D
## Same as energy_icon, for the Wirausaha earnings chip.
@export var money_icon: Texture2D

## The ghosted motif at the solid right end of the ghost track, on the two
## rows that have no gauge. Null on skill rows, which draw a bar in that
## space instead. Assigned per row in atur_jadwal.tscn -- it lives on this
## root rather than on Container/Pill/Watermark because overrides only
## serialise on an instanced scene's root.
@export var watermark_texture: Texture2D:
	set(value):
		watermark_texture = value
		if is_inside_tree():
			var mark := get_node_or_null("Container/Pill/Watermark") as TextureRect
			if mark:
				mark.texture = value
				mark.visible = value != null

## True for the three rows with a target to progress toward (Akademis,
## SeniBudaya, Olahraga). Those get a StatBar inside a drawn track. The
## other two -- Wirausaha and Istirahat -- have no target, so they take
## the ghost track instead: the same silhouette used as a container for
## their cost/gain chips rather than as a meter. Until 2026-09-10 they
## used PreviewPillFlat and sat on bare surface, which collapsed once the
## row went cream. One flag because the two always move together; there
## is no row with a bar but no track.
@export var is_skill_row: bool = true


func _ready() -> void:
	# Ungated by Engine.is_editor_hint deliberately: pure signal wiring, so
	# the suite can exercise the press without instantiating the popup.
	button_down.connect(_on_row_pressed)
	button_up.connect(_on_row_released)

	var label := get_node_or_null("NameLabel") as Label
	if label:
		label.text = display_name
	var icon := get_node_or_null("Container/Icon") as TextureRect
	if icon:
		icon.texture = icon_texture
	var pill := get_node_or_null("Container/Pill") as PanelContainer
	var bar := get_node_or_null("Container/Pill/StatBar") as StatBar
	var mark := get_node_or_null("Container/Pill/Watermark") as TextureRect
	if is_skill_row:
		if bar:
			bar.category = category
		# A skill row draws its bar in that space; a motif behind it would
		# just be noise under the fill.
		if mark:
			mark.visible = false
	else:
		if pill:
			pill.theme_type_variation = &"PreviewTrackGhost"
		if bar:
			bar.get_parent().remove_child(bar)
			bar.free()
		if mark:
			mark.texture = watermark_texture
			mark.visible = watermark_texture != null
		# Skill rows right-align their chips against the bar's fill. A ghost
		# row has no fill and puts the motif at that end instead, so its
		# chips read from the left or the two would collide.
		var chips := get_node_or_null("Container/Pill/Chips") as HBoxContainer
		if chips:
			chips.alignment = BoxContainer.ALIGNMENT_BEGIN


## Panel has no pressed state of its own, so the row's Button drives it.
## Swapping the variation rather than tweening a colour keeps the change
## in the theme, where the rest of the row's styling already lives.
func _on_row_pressed() -> void:
	var container := get_node_or_null("Container") as Panel
	if container:
		container.theme_type_variation = &"PreviewRowPressed"


## Paired with _on_row_pressed. Without this the row stays sunken after
## the first tap.
func _on_row_released() -> void:
	var container := get_node_or_null("Container") as Panel
	if container:
		container.theme_type_variation = &"PreviewRow"


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
	var chips := get_node_or_null("Container/Pill/Chips")
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

	var bar := get_node_or_null("Container/Pill/StatBar") as StatBar
	if bar:
		# Only the three skill rows carry a bar; the others left it out.
		bar.set_stat(progress_percent)

	var badge := get_node_or_null("Container/SpecialtyBadge") as TextureRect
	if badge:
		badge.visible = ActivityPreview.is_specialty(category, student)
