extends Control

## Koperasi (the shop) hub: the rak1 shelf toggle, the coin HUD and the
## purchase-feedback message.
##
## The actual shelf/cart/checkout logic lives on rakbarang_1.gd (the Rak1
## panel this screen shows/hides); this file only owns the entry button,
## the money display (kept in sync via GameState.money_changed) and
## routing back to the Lobby. It writes nothing to GameState directly --
## _on_beli_pressed() deducts GameState.player_money and calls
## GameState.add_to_inventory() on behalf of the Cart autoload's contents.

@onready var rak1_button = $TextureRect/Rak1
@onready var rak1_panel = $Rak1
@onready var rak1_back_button = $Rak1/BackButton
@onready var coin_hud: HBoxContainer = $CoinHUD
@onready var coin_label: Label = $CoinHUD/CoinLabel
@onready var message_label: Label = $MessageLabel

var beli_button: Button

func _ready():
	rak1_panel.hide()

	if rak1_button and not rak1_button.pressed.is_connected(_on_rak1_pressed):
		rak1_button.pressed.connect(_on_rak1_pressed)

	if rak1_back_button and not rak1_back_button.pressed.is_connected(_on_back_pressed):
		rak1_back_button.pressed.connect(_on_back_pressed)

	_setup_main_buttons()
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

## Idle-pulse the shelf button and centre both buttons' pivots. Styling
## (colours, border, shadow) now lives in the ShopShelfButton ThemeFactory
## variation set on rak1_button in the scene.
func _setup_main_buttons():
	if rak1_button:
		rak1_button.pivot_offset = rak1_button.size / 2
		AnimUtils.idle_pulse(rak1_button)

	if rak1_back_button:
		rak1_back_button.pivot_offset = rak1_back_button.size / 2

func _on_rak1_pressed():
	var tokens := DesignTokens.load_default()
	AnimUtils.squash_bounce(rak1_button, 4.0)

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
		AnimUtils.coin_pulse(coin_hud)

func _on_beli_pressed():
	AnimUtils.squash_bounce(beli_button)

	if Cart.is_empty():
		AudioDirector.play_sfx(&"error")
		_show_message("Keranjang kosong! 🛒", &"ShopMessageWarning")
		return

	var total = Cart.get_total()
	if GameState.player_money < total:
		AudioDirector.play_sfx(&"error")
		_show_message("Koin tidak cukup! 🪙", &"ShopMessageDanger")
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
	_show_message("✨ Pembelian berhasil! ✨", &"ShopMessageSuccess")

## Show a purchase-feedback message. `variation` selects one of the
## semantic ShopMessage* ThemeFactory variations (Warning/Danger/Success)
## instead of overriding font_color with a token colour at runtime.
func _show_message(text: String, variation: StringName = &"ShopMessageSuccess"):
	if not message_label:
		return
	message_label.text = text
	message_label.theme_type_variation = variation
	AnimUtils.message_pop(message_label)
