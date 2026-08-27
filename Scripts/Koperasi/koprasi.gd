extends Control

@onready var rak1_button = $TextureRect/Rak1
@onready var rak1_panel = $Rak1
@onready var rak1_back_button = $Rak1/BackButton

# UI elements — will be created in _ready
var coin_label: Label
var coin_container: HBoxContainer
var message_label: Label
var beli_button: Button

func _ready():
	var tokens := DesignTokens.load_default()
	rak1_panel.hide()

	if rak1_button and not rak1_button.pressed.is_connected(_on_rak1_pressed):
		rak1_button.pressed.connect(_on_rak1_pressed)

	if rak1_back_button and not rak1_back_button.pressed.is_connected(_on_back_pressed):
		rak1_back_button.pressed.connect(_on_back_pressed)

	_setup_coin_display(tokens)
	_setup_message_label()
	_setup_main_buttons(tokens)
	_setup_beli_button()

	_update_coin_display()

	# Signal-driven coin updates
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)

func _setup_beli_button():
	# Find the existing BELI button in Rak1
	beli_button = rak1_panel.get_node_or_null("TextureButton")
	if beli_button and not beli_button.pressed.is_connected(_on_beli_pressed):
		beli_button.pressed.connect(_on_beli_pressed)

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if rak1_panel and rak1_panel.visible:
			_on_back_pressed()

func _setup_coin_display(tokens: DesignTokens):
	# Container for coin icon + label at the top of the screen
	coin_container = HBoxContainer.new()
	coin_container.position = Vector2(20, 20)
	coin_container.add_theme_constant_override("separation", 10)

	# Coin icon
	var coin_icon = TextureRect.new()
	var coin_texture = load("res://Assets/Images/Shop/Koin.png")
	if coin_texture:
		coin_icon.texture = coin_texture
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(60, 60)
	coin_container.add_child(coin_icon)

	# Coin label
	coin_label = Label.new()
	coin_label.add_theme_font_size_override("font_size", 40)
	coin_label.add_theme_color_override("font_color", tokens.currency_gold)
	coin_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	coin_label.add_theme_constant_override("shadow_offset_x", 2)
	coin_label.add_theme_constant_override("shadow_offset_y", 2)
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_container.add_child(coin_label)

	add_child(coin_container)
	# Move to front so it's always visible
	coin_container.z_index = 10

func _setup_message_label():
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 36)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Responsive: use viewport width and vertical center offset
	var vp_size = get_viewport_rect().size
	message_label.size = Vector2(vp_size.x, 80)
	message_label.position = Vector2(0, vp_size.y * 0.47)
	message_label.z_index = 20
	message_label.text = ""
	add_child(message_label)

func _setup_main_buttons(tokens: DesignTokens):
	# ─── Style & Idle Pulse for "School Supplies" (Rak1) Button ───
	if rak1_button:
		rak1_button.pivot_offset = rak1_button.size / 2

		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = tokens.brand_primary
		style_normal.corner_radius_top_left = tokens.radius_md
		style_normal.corner_radius_top_right = tokens.radius_md
		style_normal.corner_radius_bottom_left = tokens.radius_md
		style_normal.corner_radius_bottom_right = tokens.radius_md
		style_normal.border_width_left = 3
		style_normal.border_width_top = 3
		style_normal.border_width_right = 3
		style_normal.border_width_bottom = 5
		style_normal.border_color = tokens.outline_card
		style_normal.shadow_size = 6
		style_normal.shadow_offset = Vector2(0, 4)
		style_normal.shadow_color = Color(tokens.shadow_color.r, tokens.shadow_color.g, tokens.shadow_color.b, 0.45)
		style_normal.content_margin_left = 20
		style_normal.content_margin_right = 20
		style_normal.content_margin_top = 10
		style_normal.content_margin_bottom = 10
		rak1_button.add_theme_stylebox_override("normal", style_normal)

		var style_hover: StyleBoxFlat = style_normal.duplicate()
		style_hover.bg_color = tokens.brand_primary.lightened(0.15)
		style_hover.border_color = tokens.outline_card
		rak1_button.add_theme_stylebox_override("hover", style_hover)

		var style_pressed: StyleBoxFlat = style_normal.duplicate()
		style_pressed.bg_color = tokens.brand_primary.darkened(0.2)
		style_pressed.border_width_bottom = 2
		style_pressed.shadow_offset = Vector2(0, 1)
		rak1_button.add_theme_stylebox_override("pressed", style_pressed)

		rak1_button.add_theme_color_override("font_color", tokens.text_on_brand)
		rak1_button.add_theme_color_override("font_hover_color", tokens.currency_gold)
		rak1_button.add_theme_color_override("font_pressed_color", tokens.text_on_brand)
		rak1_button.add_theme_color_override("font_shadow_color", Color(tokens.shadow_color.r, tokens.shadow_color.g, tokens.shadow_color.b, 0.75))
		rak1_button.add_theme_constant_override("shadow_offset_x", 2)
		rak1_button.add_theme_constant_override("shadow_offset_y", 2)

		AnimUtils.idle_pulse(rak1_button)

	# Ensure BackButton pivot is centered
	if rak1_back_button:
		rak1_back_button.pivot_offset = rak1_back_button.size / 2

func _on_rak1_pressed():
	var tokens := DesignTokens.load_default()
	AnimUtils.squash_bounce(rak1_button, 4.0)
	AudioDirector.play_sfx(&"tap")

	if rak1_panel.has_method("setup_random_items"):
		rak1_panel.setup_random_items()

	rak1_panel.visible = true
	rak1_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	rak1_panel.pivot_offset = rak1_panel.size * 0.5
	rak1_panel.scale = Vector2(0.9, 0.9)

	AudioDirector.play_sfx(&"popup_open")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(rak1_panel, "modulate:a", 1.0, tokens.dur_fast)
	tween.tween_property(rak1_panel, "scale", Vector2.ONE, tokens.dur_fast) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_back_pressed():
	var tokens := DesignTokens.load_default()
	AnimUtils.back_bounce(rak1_back_button)
	AudioDirector.play_sfx(&"whoosh")

	# Clear cart and basket visuals
	Cart.clear()
	if rak1_panel.has_method("clear_basket_visuals"):
		rak1_panel.clear_basket_visuals()

	AudioDirector.play_sfx(&"popup_close")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(rak1_panel, "modulate:a", 0.0, tokens.dur_fast)
	tween.tween_property(rak1_panel, "scale", Vector2(0.9, 0.9), tokens.dur_fast) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish_back_close)

func _finish_back_close():
	rak1_panel.hide()
	rak1_panel.scale = Vector2(1.0, 1.0)
	rak1_panel.modulate.a = 1.0
	Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)

func _on_money_changed(new_amount: int):
	_update_coin_display()

func _update_coin_display():
	if coin_label:
		coin_label.text = "%d" % GameState.player_money
		AnimUtils.coin_pulse(coin_container)

func _on_beli_pressed():
	AnimUtils.squash_bounce(beli_button)

	var tokens := DesignTokens.load_default()

	if Cart.is_empty():
		AudioDirector.play_sfx(&"error")
		_show_message("Keranjang kosong! 🛒", tokens.state_warning)
		return

	var total = Cart.get_total()
	if GameState.player_money < total:
		AudioDirector.play_sfx(&"error")
		_show_message("Koin tidak cukup! 🪙", tokens.state_danger)
		return

	# Deduct money
	GameState.player_money -= total

	# Transfer items to inventory
	for item_name in Cart.cart:
		var quantity = Cart.cart[item_name]["quantity"]
		GameState.add_to_inventory(item_name, quantity)

	# Clear cart and visuals
	Cart.clear()
	var rak1_script = rak1_panel as Control
	if rak1_script.has_method("clear_basket_visuals"):
		rak1_script.clear_basket_visuals()

	AudioDirector.play_sfx(&"coin")
	_show_message("✨ Pembelian berhasil! ✨", tokens.state_success)

func _show_message(text: String, color: Color = Color.WHITE):
	if not message_label:
		return
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	AnimUtils.message_pop(message_label)
