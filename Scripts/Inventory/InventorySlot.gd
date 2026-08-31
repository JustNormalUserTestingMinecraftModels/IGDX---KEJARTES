@tool
class_name InventorySlot
extends PanelContainer

## One item tile in the inventory grid.
##
## Instantiated by Scripts/Inventory/inventory.gd once per owned item. Before
## this scene existed, inventory.gd rebuilt eight nodes and two StyleBoxFlats
## per item on every category-filter change.
##
## The border colour is tinted per item category (Buku/Olahraga/Makanan),
## which is a genuinely per-instance value no baked ThemeFactory variation
## can express -- setup() still builds the normal/selected StyleBoxFlat pair
## the same way the shipped code did, once per slot rather than on every
## selection change. This mirrors the accepted exception already used for
## TraitPopupHeader and the quit dialog's card.
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

## Accent colour per item category, applied to the border. Exposed so a new
## category can be given a colour without editing code.
@export var category_colors: Dictionary = {}
## The border colour for a category not listed above.
@export var default_category_color: Color = Color(0.6, 0.6, 0.65)

@onready var icon: TextureRect = $Layout/Icon
@onready var quantity_label: Label = $Layout/QuantityRow/QuantityLabel

## The item this tile shows. Read by inventory.gd when the tile is tapped.
var item: ItemData = null

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _touch_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	gui_input.connect(_on_gui_input)


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
	var cat_color: Color = category_colors.get(p_item.category, default_category_color)

	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = tokens.surface_overlay
	_normal_style.set_corner_radius_all(12)
	_normal_style.border_width_left = 4
	_normal_style.border_width_top = 1
	_normal_style.border_width_right = 1
	_normal_style.border_width_bottom = 1
	_normal_style.border_color = cat_color.darkened(0.3)
	_normal_style.content_margin_left = 16
	_normal_style.content_margin_right = 16
	_normal_style.content_margin_top = 16
	_normal_style.content_margin_bottom = 14

	_selected_style = _normal_style.duplicate()
	_selected_style.bg_color = tokens.surface_overlay.lightened(0.15)
	_selected_style.border_width_top = 2
	_selected_style.border_width_right = 2
	_selected_style.border_width_bottom = 2
	_selected_style.border_color = cat_color

	add_theme_stylebox_override("panel", _normal_style)


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
		elif _touch_start_pos.distance_to(event.global_position) < 20.0:
			slot_pressed.emit(self)
