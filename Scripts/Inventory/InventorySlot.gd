@tool
class_name InventorySlot
extends PanelContainer

## One item tile in the inventory grid.
##
## Instantiated by Scripts/Inventory/inventory.gd once per owned item. Before
## this scene existed, inventory.gd rebuilt eight nodes and two StyleBoxFlats
## per item on every category-filter change.
##
## The card is a bright paper surface topped by a full-strength category band
## (Buku/Olahraga/Makanan), with a soft offset shadow so the tile sits up off
## the page. The band fill and the card border are the item's category colour
## -- a genuinely per-instance value no baked ThemeFactory variation can
## express, so setup() builds the band + normal + selected StyleBoxFlats once
## per slot rather than on every selection change. This mirrors the accepted
## exception already used for TraitPopupHeader and the quit dialog's card.
##
## Affects: nothing outside itself. Emits `slot_pressed` on a clean tap (not
## a scroll) and lets the screen decide what that means; never touches
## GameState or the Cart directly.
##
## @tool so the scene previews in the editor.

## Emitted when the player taps this tile with a clean, non-scrolling touch
## (release within 20px of the press position -- the same gesture guard the
## shipped screen-level handler used). Carries this slot so the screen can
## track/restyle the current selection without a separate lookup.
signal slot_pressed(slot: InventorySlot)

## Minimum owned quantity before the idle shine overlay pulses on this tile.
@export var shine_min_quantity: int = 5

## Map inventory categories to schedule categories for DesignTokens lookup.
const _INV_TO_SCHEDULE := {
	"Buku": "Akademis",
	"Olahraga": "Olahraga",
	"Makanan": "Libur",
}

## Alpha of the bright category glow at the centre, fading to transparent.
const _GLOW_CENTER_ALPHA := 0.5

@onready var icon: TextureRect = $Layout/Body/BodyCol/IconStack/Icon
@onready var _icon_stack: PanelContainer = $Layout/Body/BodyCol/IconStack
@onready var _glow: TextureRect = $Layout/Body/BodyCol/IconStack/Glow
@onready var _band: PanelContainer = $Layout/Band
@onready var _category_chip: Label = $Layout/Band/CategoryChip
@onready var quantity_label: Label = $Layout/Body/BodyCol/QuantityRow/QuantityLabel
@onready var _shine: ColorRect = $Shine

## The item this tile shows. Read by inventory.gd when the tile is tapped.
var item: ItemData = null

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _band_style: StyleBoxFlat
var _touch_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	# The IconStack only exists to stack the glow behind the icon -- it must
	# not paint a panel of its own.
	_icon_stack.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Keep the icon's diagonal tilt pivoting about its own centre as the tile
	# resizes with the grid column width.
	icon.resized.connect(func(): icon.pivot_offset = icon.size * 0.5)
	icon.pivot_offset = icon.size * 0.5


## Fill the tile from one owned item and build its category-tinted styles.
##
## Affects: this tile's icon, quantity text, `item`, and its normal/selected
## styleboxes (rebuilt, since the category can differ from the last item this
## tile showed if the screen re-uses tiles). Leaves the tile in its normal
## (unselected) state.
func setup(p_item: ItemData, quantity: int) -> void:
	item = p_item
	icon.texture = p_item.icon
	quantity_label.text = "×%d" % quantity

	var tokens := DesignTokens.load_default()

	# The band carries the category name in full-strength colour; the card
	# below it is a bright paper surface, so the whole tile reads light rather
	# than the old dark-brown box. Both styleboxes are per-instance because
	# their colour is the item's category -- the documented exception this
	# tile already relied on.
	var schedule_cat: String = _INV_TO_SCHEDULE.get(p_item.category, "")
	var band_color: Color = tokens.category_color(schedule_cat) if schedule_cat else tokens.text_secondary
	if _category_chip:
		_category_chip.text = p_item.category
		_category_chip.add_theme_color_override("font_color", tokens.surface_card)

	var glow_color: Color = tokens.category_color_on_dark(schedule_cat) if schedule_cat else band_color
	if _glow:
		_glow.texture = _build_glow(glow_color)

	_band_style = StyleBoxFlat.new()
	_band_style.bg_color = band_color
	_band_style.corner_radius_top_left = 14
	_band_style.corner_radius_top_right = 14
	_band_style.content_margin_top = 10
	_band_style.content_margin_bottom = 10
	_band_style.content_margin_left = 12
	_band_style.content_margin_right = 12
	if _band:
		_band.add_theme_stylebox_override("panel", _band_style)

	var shadow := tokens.text_primary
	shadow.a = 0.22

	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = tokens.surface_card
	_normal_style.set_corner_radius_all(16)
	_normal_style.set_border_width_all(2)
	_normal_style.border_color = band_color
	_normal_style.shadow_color = shadow
	_normal_style.shadow_size = 6
	_normal_style.shadow_offset = Vector2(0, 3)

	_selected_style = _normal_style.duplicate()
	_selected_style.bg_color = tokens.surface_card.darkened(0.04)
	_selected_style.set_border_width_all(4)

	add_theme_stylebox_override("panel", _normal_style)

	if _shine:
		_shine.visible = quantity >= shine_min_quantity
		if _shine.visible and not Engine.is_editor_hint():
			_start_shine()


## A soft radial "bright spot" tinted by the item's category, drawn behind the
## icon so the tile pops the way the sticker mock did. The gradient is
## per-instance (its colour is the category), so it is built here rather than
## authored -- the same per-call-dynamic exception the styleboxes use.
func _build_glow(color: Color) -> GradientTexture2D:
	var center := color
	center.a = _GLOW_CENTER_ALPHA
	var edge := color
	edge.a = 0.0
	var gradient := Gradient.new()
	gradient.set_color(0, center)
	gradient.set_color(1, edge)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


## Loop a soft alpha pulse on the tile's Shine overlay -- a purely
## decorative "you own a lot of these" cue, gated by shine_min_quantity.
## InventorySlot's root is a PanelContainer (children are forced to fill),
## so this pulses alpha rather than sweeping a highlight across.
func _start_shine() -> void:
	_shine.modulate.a = 0.0
	var t := create_tween().set_loops()
	t.tween_property(_shine, "modulate:a", 0.22, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_shine, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_interval(1.6)


## Bounce the quantity badge after the owned count changed.
func bounce_badge() -> void:
	AnimUtils.qty_punch(quantity_label)


## Swap between the resting and selected look. Both styles are already
## built (in setup()); this only swaps which one is applied.
##
## Affects: this tile's stylebox override only.
func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)


## Tap-vs-scroll gesture detection, same 20px threshold the shipped
## screen-level handler used, now scoped to this one tile instead of a
## dictionary keyed by node.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_pos = event.global_position
			if not Engine.is_editor_hint():
				Juice.press(self)
		else:
			if not Engine.is_editor_hint():
				Juice.release(self)
			if _touch_start_pos.distance_to(event.global_position) < 20.0:
				slot_pressed.emit(self)
