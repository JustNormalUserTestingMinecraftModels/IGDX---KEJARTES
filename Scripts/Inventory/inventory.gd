extends Control
## The Inventory screen. Every owned item is a tappable grid tile; tapping one
## opens ItemDetailSheet, whose "Pakai ke Siswa" button opens ApplyItemScreen.
## This script never builds visuals at runtime -- tiles, the sheet and the
## apply screen are all PackedScene templates, and the chrome is authored in
## the .tscn with theme variations.

## One grid tile.
@export var slot_scene: PackedScene = preload("res://Scenes/Inventory/InventorySlot.tscn")
## Bottom sheet shown when a tile is tapped.
@export var detail_sheet_scene: PackedScene = preload("res://Scenes/Inventory/ItemDetailSheet.tscn")
## Full-screen "apply to students" modal opened from the sheet.
@export var apply_screen_scene: PackedScene = preload("res://Scenes/Inventory/ApplyItemScreen.tscn")
## Seconds the "stack habis" toast stays fully visible.
@export var toast_hold: float = 1.1

@onready var _coin_label: Label = $MainColumn/Header/Row/CoinDisplay/CoinLabel
@onready var _back_button: Button = $MainColumn/Header/Row/BackButton
@onready var _grid: GridContainer = $MainColumn/GridArea/Scroll/Grid
@onready var _empty_label: Label = $MainColumn/GridArea/Scroll/Grid/EmptyStateLabel
@onready var _toast: Label = $ToastLabel
@onready var _chips: Array = [
	$MainColumn/FilterRow/Scroll/Chips/CatSemua,
	$MainColumn/FilterRow/Scroll/Chips/CatBuku,
	$MainColumn/FilterRow/Scroll/Chips/CatOlahraga,
	$MainColumn/FilterRow/Scroll/Chips/CatMakanan,
]

var current_category: String = "Semua"
var _sheet: ItemDetailSheet = null
var _apply_screen: ApplyItemScreen = null

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	for chip in _chips:
		chip.pressed.connect(_on_chip_pressed.bind(chip.text))
	_chips[0].button_pressed = true
	_toast.visible = false
	_coin_label.text = "%d" % GameState.player_money
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_populate_grid()

func _on_money_changed(_amount: int) -> void:
	_coin_label.text = "%d" % GameState.player_money

func _on_inventory_changed() -> void:
	if is_inside_tree():
		_populate_grid()

func _populate_grid() -> void:
	for child in _grid.get_children():
		if child == _empty_label:
			continue
		_grid.remove_child(child)
		child.queue_free()
	_empty_label.visible = false

	var idx := 0
	for item_name in GameState.inventory:
		var qty: int = GameState.inventory[item_name]
		var data: ItemData = ItemDatabase.get_item(item_name)
		if data == null:
			continue
		if current_category != "Semua" and data.category != current_category:
			continue
		var slot: InventorySlot = slot_scene.instantiate()
		_grid.add_child(slot)
		slot.setup(data, qty)
		slot.slot_pressed.connect(_on_slot_pressed)
		AnimUtils.staggered_entrance(slot, idx * 0.06)
		idx += 1

	if idx == 0:
		_empty_label.text = "Inventory kosong" if current_category == "Semua" \
			else "Tidak ada item \"%s\"" % current_category
		_empty_label.visible = true

func _on_chip_pressed(category: String) -> void:
	if current_category == category:
		return
	current_category = category
	AudioDirector.play_sfx(&"tap")
	_populate_grid()

func _on_slot_pressed(slot: InventorySlot) -> void:
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
	_open_detail_sheet(slot.item)

func _open_detail_sheet(item: ItemData) -> void:
	_sheet = detail_sheet_scene.instantiate()
	add_child(_sheet)
	_sheet.setup(item, GameState.get_inventory_quantity(item.item_name))
	_sheet.apply_requested.connect(_open_apply_screen)
	_sheet.dismissed.connect(func(): _sheet = null)

func _open_apply_screen(item: ItemData) -> void:
	if _apply_screen != null:
		return
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
	_apply_screen = apply_screen_scene.instantiate()
	add_child(_apply_screen)
	_apply_screen.setup(item)
	_apply_screen.applied.connect(_on_items_applied.bind(item))
	_apply_screen.cancelled.connect(func(): _apply_screen = null)

func _on_items_applied(_results: Array, item: ItemData) -> void:
	_apply_screen = null
	AudioDirector.play_sfx(&"whoosh")
	var remaining := GameState.get_inventory_quantity(item.item_name)
	_populate_grid()
	if remaining > 0:
		for slot in _grid.get_children():
			if slot is InventorySlot and slot.item == item:
				slot.bounce_badge()
	else:
		_show_toast("%s habis" % item.item_name)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.15)
	t.tween_interval(toast_hold)
	t.tween_property(_toast, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): _toast.visible = false)

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	# The sheet and the apply screen each handle the back request and free
	# themselves; only fall through to leaving the screen when neither is up.
	if _sheet != null or _apply_screen != null:
		return
	_on_back_pressed()

func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"whoosh")
	await get_tree().create_timer(0.15).timeout
	Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)
