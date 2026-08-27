extends Control

# ─── Theme Colors (used for dynamic elements only) ───
## Populated from DesignTokens in _ready(); see _setup_dynamic_colors().
var SLOT_BG: Color
var SLOT_SELECTED_BG: Color
var ACCENT: Color
var GOLD: Color
var TEXT_WHITE: Color
var TEXT_GRAY: Color
var TEXT_DIM: Color
var SHADOW_COLOR: Color

var CATEGORY_COLORS: Dictionary = {}
var DEFAULT_CATEGORY_COLOR: Color

# ─── Scene References ───
@onready var coin_label: Label = $MainLayout/Header/HeaderContent/CoinDisplay/CoinLabel
@onready var back_button: TextureButton = $MainLayout/Header/HeaderContent/BackButton
@onready var grid: GridContainer = $MainLayout/Body/GridMargin/ScrollContainer/GridContainer
@onready var detail_panel: PanelContainer = $MainLayout/DetailPanel
@onready var detail_icon: TextureRect = $MainLayout/DetailPanel/DetailContent/DetailIcon
@onready var detail_name_label: Label = $MainLayout/DetailPanel/DetailContent/DetailInfo/DetailName
@onready var detail_desc_label: Label = $MainLayout/DetailPanel/DetailContent/DetailInfo/DetailDesc
@onready var use_button: Button = $MainLayout/DetailPanel/DetailContent/UseButton
@onready var category_list_container: VBoxContainer = $MainLayout/Body/Sidebar/CategoryList

# ─── Use Popup References ───
@onready var use_popup: ColorRect = $UsePopup
@onready var popup_item_icon: TextureRect = $UsePopup/CenterContainer/PopupPanel/VBox/ItemPreviewContainer/ItemSlot/ItemIcon
@onready var popup_item_badge: Label = $UsePopup/CenterContainer/PopupPanel/VBox/ItemPreviewContainer/ItemSlot/ItemBadge
@onready var popup_item_name: Label = $UsePopup/CenterContainer/PopupPanel/VBox/ItemNameLabel
@onready var popup_qty_label: Label = $UsePopup/CenterContainer/PopupPanel/VBox/StepperHBox/QtyPanel/QtyLabel
@onready var popup_minus_btn: Button = $UsePopup/CenterContainer/PopupPanel/VBox/StepperHBox/MinusButton
@onready var popup_plus_btn: Button = $UsePopup/CenterContainer/PopupPanel/VBox/StepperHBox/PlusButton
@onready var popup_cancel_btn: Button = $UsePopup/CenterContainer/PopupPanel/VBox/ButtonsHBox/CancelButton
@onready var popup_ok_btn: Button = $UsePopup/CenterContainer/PopupPanel/VBox/ButtonsHBox/OkButton

# ─── State ───
var selected_item: ItemData = null
var selected_slot: PanelContainer = null
var current_category: String = "Semua"
var category_buttons: Dictionary = {}
var slot_styles: Dictionary = {}   # slot -> {"normal": StyleBox, "selected": StyleBox}

var current_use_qty: int = 1
var max_use_qty: int = 1

# ═══════════════════════════════════════════
#  LIFECYCLE
# ═══════════════════════════════════════════

func _ready():
	var tokens := DesignTokens.load_default()
	_setup_dynamic_colors(tokens)

	_apply_png_panel_overrides()

	# Dynamically discover category buttons
	category_buttons.clear()
	for child in category_list_container.get_children():
		if child is Button:
			category_buttons[child.text] = child
			if not child.pressed.is_connected(_on_category_pressed):
				child.pressed.connect(_on_category_pressed.bind(child.text))

	# Connect main signals
	back_button.pressed.connect(_on_back_pressed)
	use_button.pressed.connect(_on_use_pressed)

	# Connect popup signals
	popup_minus_btn.pressed.connect(_on_minus_pressed)
	popup_plus_btn.pressed.connect(_on_plus_pressed)
	popup_cancel_btn.pressed.connect(_on_popup_cancel_pressed)
	popup_ok_btn.pressed.connect(_on_popup_ok_pressed)

	use_popup.hide()

	# Apply initial styles
	_style_all_category_buttons()
	coin_label.text = "%d" % GameState.player_money

	# Signal-driven updates
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)

	# Populate the grid
	_populate_grid()

func _setup_dynamic_colors(tokens: DesignTokens) -> void:
	SLOT_BG = tokens.surface_overlay
	SLOT_SELECTED_BG = tokens.surface_overlay.lightened(0.15)
	ACCENT = tokens.brand_primary
	GOLD = tokens.currency_gold
	TEXT_WHITE = tokens.text_on_brand
	TEXT_GRAY = tokens.text_secondary
	TEXT_DIM = tokens.text_disabled
	SHADOW_COLOR = Color(tokens.shadow_color.r, tokens.shadow_color.g, tokens.shadow_color.b, 0.85)

	CATEGORY_COLORS = {
		"Buku": tokens.brand_primary,
		"Olahraga": tokens.cat_libur,
		"Makanan": tokens.cat_olahraga,
	}
	DEFAULT_CATEGORY_COLOR = tokens.text_secondary

func _apply_png_panel_overrides():
	var header = $MainLayout/Header as PanelContainer
	var header_tex = load("res://Assets/Images/Shop/UI/panel_header.png")
	if header and header_tex:
		var sb = StyleBoxTexture.new()
		sb.texture = header_tex
		sb.texture_margin_left = 32
		sb.texture_margin_right = 32
		sb.texture_margin_bottom = 32
		header.add_theme_stylebox_override("panel", sb)

	var sidebar = $MainLayout/Body/Sidebar as PanelContainer
	var sidebar_tex = load("res://Assets/Images/Shop/UI/panel_sidebar.png")
	if sidebar and sidebar_tex:
		var sb = StyleBoxTexture.new()
		sb.texture = sidebar_tex
		sb.texture_margin_left = 32
		sb.texture_margin_right = 32
		sb.texture_margin_top = 32
		sidebar.add_theme_stylebox_override("panel", sb)

	var detail_panel_node = $MainLayout/DetailPanel as PanelContainer
	var detail_tex = load("res://Assets/Images/Shop/UI/panel_detail.png")
	if detail_panel_node and detail_tex:
		var sb = StyleBoxTexture.new()
		sb.texture = detail_tex
		sb.texture_margin_left = 32
		sb.texture_margin_right = 32
		sb.texture_margin_top = 40
		detail_panel_node.add_theme_stylebox_override("panel", sb)

	var popup_panel = $UsePopup/CenterContainer/PopupPanel as PanelContainer
	var popup_tex = load("res://Assets/Images/Shop/UI/panel_popup.png")
	if popup_panel and popup_tex:
		var sb = StyleBoxTexture.new()
		sb.texture = popup_tex
		sb.texture_margin_left = 48
		sb.texture_margin_right = 48
		sb.texture_margin_top = 48
		sb.texture_margin_bottom = 48
		popup_panel.add_theme_stylebox_override("panel", sb)

# ═══════════════════════════════════════════
#  SIGNAL HANDLERS
# ═══════════════════════════════════════════

func _on_money_changed(_new_amount: int):
	coin_label.text = "%d" % GameState.player_money

func _on_inventory_changed():
	# Refresh grid if an item was used
	if is_inside_tree():
		_populate_grid()

# ═══════════════════════════════════════════
#  CATEGORY BUTTON STYLING
# ═══════════════════════════════════════════

func _style_all_category_buttons():
	for cat in category_buttons:
		_apply_category_style(category_buttons[cat], cat == current_category)

func _apply_category_style(btn: Button, is_selected: bool):
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	if is_selected:
		normal.bg_color = ACCENT.darkened(0.2)
		normal.border_width_left = 4
		normal.border_color = ACCENT
	else:
		normal.bg_color = SLOT_BG

	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	if is_selected:
		btn.add_theme_color_override("font_color", TEXT_WHITE)
	else:
		btn.add_theme_color_override("font_color", TEXT_GRAY)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = ACCENT.darkened(0.4) if not is_selected else ACCENT.darkened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_s: StyleBoxFlat = normal.duplicate()
	pressed_s.bg_color = ACCENT.darkened(0.3)
	btn.add_theme_stylebox_override("pressed", pressed_s)

	btn.add_theme_color_override("font_hover_color", TEXT_WHITE)
	btn.add_theme_color_override("font_pressed_color", TEXT_WHITE)

# ═══════════════════════════════════════════
#  GRID POPULATION
# ═══════════════════════════════════════════

func _populate_grid():
	# Clear previous slots
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	slot_styles.clear()
	selected_item = null
	selected_slot = null
	detail_panel.hide()
	use_popup.hide()

	var has_items := false
	var slot_index := 0

	for item_name in GameState.inventory:
		var quantity: int = GameState.inventory[item_name]
		var item_data: ItemData = ItemDatabase.get_item(item_name)
		if item_data == null:
			continue

		# Category filter
		if current_category != "Semua" and item_data.category != current_category:
			continue

		has_items = true
		_create_item_slot(item_data, quantity, slot_index)
		slot_index += 1

	if not has_items:
		_show_empty_message()

func _create_item_slot(item: ItemData, quantity: int, slot_index: int = 0):
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(240, 280)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	# Border color based on category
	var cat_color: Color = CATEGORY_COLORS.get(item.category, DEFAULT_CATEGORY_COLOR)

	# ── Normal style ──
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = SLOT_BG
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.border_width_left = 4
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = cat_color.darkened(0.3)

	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 10
	slot.add_theme_stylebox_override("panel", normal_style)

	# ── Selected style (stored for later) ──
	var selected_style: StyleBoxFlat = normal_style.duplicate()
	selected_style.bg_color = SLOT_SELECTED_BG
	selected_style.border_width_left = 4
	selected_style.border_width_top = 2
	selected_style.border_width_right = 2
	selected_style.border_width_bottom = 2
	selected_style.border_color = cat_color

	slot_styles[slot] = {"normal": normal_style, "selected": selected_style}

	# ── Content ──
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)

	# Item icon
	var icon = TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(180, 210)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	# Quantity badge row (right-aligned)
	var qty_hbox = HBoxContainer.new()
	qty_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(qty_hbox)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_hbox.add_child(spacer)

	var qty_label = Label.new()
	qty_label.text = "×%d" % quantity
	qty_label.add_theme_font_size_override("font_size", 32)
	qty_label.add_theme_color_override("font_color", GOLD)
	qty_label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	qty_label.add_theme_constant_override("shadow_offset_x", 1)
	qty_label.add_theme_constant_override("shadow_offset_y", 1)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_hbox.add_child(qty_label)

	# Input
	slot.gui_input.connect(_on_slot_input.bind(slot, item))

	grid.add_child(slot)

	# Staggered entrance animation
	AnimUtils.staggered_entrance(slot, slot_index * 0.06)

func _show_empty_message():
	var label = Label.new()
	if current_category == "Semua":
		label.text = "📦 Inventory kosong"
	else:
		label.text = "🔍 Tidak ada item \"%s\"" % current_category
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)

	AnimUtils.fade_in(label)

# ═══════════════════════════════════════════
#  INTERACTION
# ═══════════════════════════════════════════

var _touch_start_pos: Vector2 = Vector2.ZERO

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if use_popup and use_popup.visible:
			_on_popup_cancel_pressed()
		elif detail_panel and detail_panel.visible:
			_deselect_slot()
		else:
			_on_back_pressed()

func _on_slot_input(event: InputEvent, slot: PanelContainer, item: ItemData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_pos = event.global_position
		else:
			# Clean tap vs scroll detection for touchscreens
			if _touch_start_pos.distance_to(event.global_position) < 20.0:
				if selected_slot == slot:
					_deselect_slot()
				else:
					_select_slot(slot, item)

func _select_slot(slot: PanelContainer, item: ItemData):
	# Deselect previous
	if selected_slot != null and slot_styles.has(selected_slot):
		selected_slot.add_theme_stylebox_override("panel", slot_styles[selected_slot]["normal"])
		AnimUtils.deselect_shrink(selected_slot)

	# Highlight new with bounce
	selected_slot = slot
	selected_item = item
	slot.add_theme_stylebox_override("panel", slot_styles[slot]["selected"])
	AnimUtils.slot_bounce(slot)
	AudioDirector.play_sfx(&"tap")

	# Update detail panel with description + stats
	detail_icon.texture = item.icon
	detail_name_label.text = item.item_name

	var desc_text = item.description if item.description != "" else "Tidak ada deskripsi."
	var stats_parts: Array[String] = []
	if item.mood_boost != 0:
		stats_parts.append("😊 Mood: %+d" % item.mood_boost)
	if item.energy_boost != 0:
		stats_parts.append("⚡ Energi: %+d" % item.energy_boost)

	if not stats_parts.is_empty():
		desc_text += "\n" + " | ".join(stats_parts)

	detail_desc_label.text = desc_text
	AnimUtils.detail_slide_in(detail_panel)
	AnimUtils.wobble(detail_icon)

func _deselect_slot():
	if selected_slot != null and slot_styles.has(selected_slot):
		selected_slot.add_theme_stylebox_override("panel", slot_styles[selected_slot]["normal"])
		AnimUtils.deselect_shrink(selected_slot)
	selected_slot = null
	selected_item = null
	if detail_panel.visible:
		AnimUtils.detail_slide_out(detail_panel)
	use_popup.hide()

func _on_category_pressed(category: String):
	if current_category == category:
		return
	current_category = category
	AudioDirector.play_sfx(&"tap")

	# Animate category buttons smoothly
	for cat_name in category_buttons:
		var btn = category_buttons[cat_name] as Control
		btn.scale = Vector2.ONE
		btn.position.x = 0.0
		AnimUtils._center_pivot(btn)

		if cat_name == category:
			# Subtle horizontal punch
			var cat_tween = btn.create_tween().set_parallel(true)
			btn.scale.x = 0.92
			btn.position.x = 6.0
			cat_tween.tween_property(btn, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			cat_tween.tween_property(btn, "position:x", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_style_all_category_buttons()
	_populate_grid()

func _on_back_pressed():
	AnimUtils.back_bounce(back_button)
	AudioDirector.play_sfx(&"whoosh")
	await back_button.create_tween().tween_interval(0.2).finished
	Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)

# ═══════════════════════════════════════════
#  USE ACTION & POPUP LOGIC
# ═══════════════════════════════════════════

func _on_use_pressed():
	if selected_item == null:
		return

	AnimUtils.squash_bounce(use_button)
	AudioDirector.play_sfx(&"tap")

	var owned_qty = GameState.get_inventory_quantity(selected_item.item_name)
	if owned_qty > 1:
		_open_use_popup(selected_item, owned_qty)
	elif owned_qty == 1:
		# Single item use (action disabled / set to null for now)
		print("Gunakan 1 × %s — aksi dinonaktifkan (null)" % selected_item.item_name)

func _open_use_popup(item: ItemData, max_qty: int):
	current_use_qty = 1
	max_use_qty = max_qty

	popup_item_icon.texture = item.icon
	popup_item_badge.text = "×%d" % max_qty
	popup_item_name.text = item.item_name

	_update_popup_qty_display()

	# Fade in the overlay
	use_popup.modulate.a = 0.0
	use_popup.show()
	var overlay_tween = create_tween()
	overlay_tween.tween_property(use_popup, "modulate:a", 1.0, 0.15)

	# Spring pop-in for the panel
	var panel = $UsePopup/CenterContainer/PopupPanel as Control
	if panel:
		AnimUtils.popup_spring_in(panel)

	# Wobble the popup icon
	AnimUtils.wobble(popup_item_icon)

func _close_popup_animated():
	var panel = $UsePopup/CenterContainer/PopupPanel as Control
	if panel:
		AnimUtils.popup_spring_out(panel, use_popup, use_popup.hide)
	else:
		use_popup.hide()

func _update_popup_qty_display():
	popup_qty_label.text = "%d" % current_use_qty
	popup_minus_btn.disabled = (current_use_qty <= 1)
	popup_plus_btn.disabled = (current_use_qty >= max_use_qty)

func _on_minus_pressed():
	if current_use_qty > 1:
		current_use_qty -= 1
		_update_popup_qty_display()
		AnimUtils.qty_punch(popup_qty_label)
		AnimUtils.stepper_bounce(popup_minus_btn, -1.0)
		AudioDirector.play_sfx(&"tap")

func _on_plus_pressed():
	if current_use_qty < max_use_qty:
		current_use_qty += 1
		_update_popup_qty_display()
		AnimUtils.qty_punch(popup_qty_label)
		AnimUtils.stepper_bounce(popup_plus_btn, 1.0)
		AudioDirector.play_sfx(&"tap")

func _on_popup_cancel_pressed():
	_close_popup_animated()
	AudioDirector.play_sfx(&"tap")

func _on_popup_ok_pressed() -> void:
	# Task 10 replaces this with the student picker. Until then, target the
	# first approved student so the screen is runnable end to end.
	if GameState.approved_students.is_empty():
		return
	var student_id: int = GameState.approved_students[0].get("id", -1)
	var result := GameState.use_item(selected_item, student_id, current_use_qty)
	if not result["applied"]:
		AudioDirector.play_sfx(&"error")
		return
	_spawn_floating_stat_pops(selected_item, current_use_qty)
	_close_popup_animated()

# ═══════════════════════════════════════════
#  FLOATING STAT POPS
# ═══════════════════════════════════════════

func _spawn_floating_stat_pops(item: ItemData, qty: int):
	var vp_size = get_viewport_rect().size
	var center_screen = Vector2(vp_size.x / 2, vp_size.y * 0.73)

	if item.mood_boost != 0:
		_create_stat_float_label(
			"😊 Mood %+d" % (item.mood_boost * qty),
			center_screen + Vector2(-120, 0),
			GOLD
		)
	if item.energy_boost != 0:
		_create_stat_float_label(
			"⚡ Energi %+d" % (item.energy_boost * qty),
			center_screen + Vector2(120, 0),
			ACCENT
		)

func _create_stat_float_label(text: String, at_pos: Vector2, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = at_pos
	label.z_index = 250
	label.pivot_offset = Vector2(100, 20)
	add_child(label)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", at_pos.y - 120.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(label.queue_free)
