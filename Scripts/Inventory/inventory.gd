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

@onready var _coin_label: Label = $MainColumn/Header/HeaderCol/Row/CoinPill/CoinDisplay/CoinLabel
@onready var _back_button: Button = $MainColumn/Header/HeaderCol/Row/BackButton
@onready var _coin_pill: PanelContainer = $MainColumn/Header/HeaderCol/Row/CoinPill
@onready var _grid: GridContainer = $MainColumn/GridArea/Scroll/Grid
@onready var _grid_scroll: ScrollContainer = $MainColumn/GridArea/Scroll
@onready var _empty_label: Label = $MainColumn/GridArea/Scroll/Grid/EmptyStateLabel
@onready var _toast: Label = $ToastLabel
@onready var _thumb: PanelContainer = $MainColumn/FilterRow/SegBar/Thumb
@onready var _tabs: Array = [
	$MainColumn/FilterRow/SegBar/Tabs/TabSemua,
	$MainColumn/FilterRow/SegBar/Tabs/TabBuku,
	$MainColumn/FilterRow/SegBar/Tabs/TabOlahraga,
	$MainColumn/FilterRow/SegBar/Tabs/TabMakanan,
]

## The four filter categories, in tab order. The index drives both the
## selector thumb and the left/right swipe paging.
const CATEGORIES := ["Semua", "Buku", "Olahraga", "Makanan"]
## Category -> schedule accent, for the selector thumb's colour.
const _CAT_TO_SCHEDULE := {"Buku": "Akademis", "Olahraga": "Olahraga", "Makanan": "Libur"}
## Minimum horizontal travel (window px) before a drag counts as a swipe, and
## how much more horizontal than vertical it must be.
const _SWIPE_MIN_PX := 40.0
const _SWIPE_AXIS_RATIO := 1.2

var current_category: String = "Semua"
var _current_index: int = 0
var _thumb_style: StyleBoxFlat = null
var _drag_active := false
var _drag_start := Vector2.ZERO
var _swapping := false
var _sheet: ItemDetailSheet = null
var _apply_screen: ApplyItemScreen = null

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	for i in _tabs.size():
		_tabs[i].pressed.connect(_on_tab_pressed.bind(i))
	_toast.visible = false
	_coin_label.text = "%d" % GameState.player_money
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_populate_grid()
	_update_tab_visuals()
	var tokens := DesignTokens.load_default()
	var sep_color := tokens.text_secondary
	sep_color.a = 0.28
	for sep in $MainColumn/FilterRow/SegBar/Tabs.get_children():
		if sep is ColorRect:
			sep.color = sep_color
	# Soft gold pill behind the coin counter.
	var pill := StyleBoxFlat.new()
	var pill_bg := tokens.currency_gold
	pill_bg.a = 0.18
	pill.bg_color = pill_bg
	pill.set_corner_radius_all(28)
	pill.content_margin_left = 20
	pill.content_margin_right = 20
	pill.content_margin_top = 8
	pill.content_margin_bottom = 8
	_coin_pill.add_theme_stylebox_override("panel", pill)
	# Tab rects are only known after the first container layout.
	_tabs[0].resized.connect(_snap_thumb)
	call_deferred("_snap_thumb")

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

func _on_tab_pressed(index: int) -> void:
	if _swapping or index == _current_index:
		return
	_go_to_category(index, signi(index - _current_index))


## A horizontal drag anywhere on the screen pages between categories; a
## vertical drag is left to the grid's ScrollContainer.
func _input(event: InputEvent) -> void:
	if _sheet != null or _apply_screen != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_start = event.position
		elif _drag_active:
			_drag_active = false
			_try_swipe(event.position - _drag_start)


func _try_swipe(delta: Vector2) -> void:
	if _swapping:
		return
	if absf(delta.x) < _SWIPE_MIN_PX or absf(delta.x) < absf(delta.y) * _SWIPE_AXIS_RATIO:
		return
	var dir := 1 if delta.x < 0.0 else -1
	var target := _current_index + dir
	if target < 0 or target >= CATEGORIES.size():
		return
	_go_to_category(target, dir)


## Switch to CATEGORIES[index]; `dir` (+1 next, -1 previous) drives which way
## the grid slides so the motion matches the swipe.
func _go_to_category(index: int, dir: int) -> void:
	_current_index = index
	current_category = CATEGORIES[index]
	AudioDirector.play_sfx(&"tap")
	_move_thumb(index, true)
	_update_tab_visuals()
	_animate_grid_swap(dir)


func _snap_thumb() -> void:
	_move_thumb(_current_index, false)


## Slide the selector thumb onto tab `index`, recolouring it to that
## category's accent. The stylebox is per-instance (its colour is the
## category), the same documented exception the slot uses.
func _move_thumb(index: int, animate: bool) -> void:
	var tab: Control = _tabs[index]
	if _thumb_style == null:
		_thumb_style = StyleBoxFlat.new()
		_thumb_style.set_corner_radius_all(16)
		_thumb.add_theme_stylebox_override("panel", _thumb_style)
	var tokens := DesignTokens.load_default()
	var sched: String = _CAT_TO_SCHEDULE.get(CATEGORIES[index], "")
	_thumb_style.bg_color = tokens.category_color(sched) if sched else tokens.brand_primary
	var inset := Vector2(4, 8)
	var target_pos: Vector2 = tab.position + inset
	var target_size: Vector2 = tab.size - inset * 2.0
	if animate:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_thumb, "position", target_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_thumb, "size", target_size, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_thumb.position = target_pos
		_thumb.size = target_size


func _update_tab_visuals() -> void:
	var tokens := DesignTokens.load_default()
	for i in _tabs.size():
		var ico := _tabs[i].get_node("Ico") as TextureRect
		ico.modulate = tokens.surface_card if i == _current_index else tokens.text_secondary


## Slide the current grid out in the swipe direction, repopulate for the new
## category, then slide the fresh grid in from the opposite edge.
func _animate_grid_swap(dir: int) -> void:
	_swapping = true
	var w: float = _grid_scroll.size.x
	if w <= 0.0:
		w = 1080.0
	var tw := create_tween()
	tw.tween_property(_grid, "modulate:a", 0.0, 0.12)
	tw.parallel().tween_property(_grid, "position:x", float(-w * dir), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_populate_grid()
		_grid_scroll.scroll_vertical = 0
		_grid.position.x = float(w * dir))
	tw.tween_property(_grid, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_grid, "position:x", 0.0, 0.2) \
		.from(float(w * dir)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _swapping = false)

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
