extends Control

## Koperasi (the shop): Pak Herman's counter. The Stage (rakbarang_1.gd)
## owns the shelf, the flight into the basket and the basket tray; this file
## owns the back button, the coin HUD, the purchase-feedback message and
## Beli.
##
## _on_beli_pressed() deducts GameState.player_money, calls
## GameState.add_to_inventory() for each basket line and marks every unit
## sold for the week (GameState.mark_shop_sold(), once per unit).
##
## Pak Herman's chat bubble (Stage/ChatBubble, ChatBubble.gd) reacts to cart
## events and purchase outcomes -- WELCOME or a sticky SOLD_OUT line on
## arrival, ADD/REMOVE from Cart's granular signals, EMPTY/POOR on a failed
## Beli, THANKS on a successful one. Lines come from DialogueCatalog.

@onready var stage: Control = $Stage
@onready var back_button: TextureButton = $Stage/BackButton
# CoinHUD stands on the counter ledge, part of the Stage, since the
# 2026-09-17 revamp.
@onready var coin_hud: HBoxContainer = %CoinHUD
@onready var coin_label: Label = get_node("%CoinHUD/CoinLabel")
@onready var message_label: Label = $MessageLabel
@onready var bubble: ChatBubble = $Stage/ChatBubble

var beli_button: Button

func _ready():
	if back_button:
		back_button.pivot_offset = back_button.size / 2
		if not back_button.pressed.is_connected(_on_back_pressed):
			back_button.pressed.connect(_on_back_pressed)

	_setup_beli_button()
	_update_coin_display()

	# Signal-driven coin updates
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)

	if not Cart.item_added.is_connected(_on_cart_item_added):
		Cart.item_added.connect(_on_cart_item_added)
	if not Cart.item_removed.is_connected(_on_cart_item_removed):
		Cart.item_removed.connect(_on_cart_item_removed)

	# The Stage, a child, has already stocked the shelf in its own _ready.
	if bubble:
		if GameState.is_shop_sold_out():
			bubble.say_sticky(DialogueCatalog.LINES[&"SOLD_OUT"][0])
		else:
			bubble.say(&"WELCOME")

## Cart is an autoload that outlives this scene -- drop our connections so a
## re-entered Koperasi does not stack duplicate listeners on the same Cart.
func _exit_tree() -> void:
	if Cart.item_added.is_connected(_on_cart_item_added):
		Cart.item_added.disconnect(_on_cart_item_added)
	if Cart.item_removed.is_connected(_on_cart_item_removed):
		Cart.item_removed.disconnect(_on_cart_item_removed)

func _on_cart_item_added(item_name: String) -> void:
	if bubble:
		bubble.say_for_item(&"ADD", item_name)

func _on_cart_item_removed(item_name: String) -> void:
	if bubble:
		bubble.say_for_item(&"REMOVE", item_name)

func _setup_beli_button():
	# Beli lives in the basket tray's footer.
	var tray = stage.get_node_or_null("TrayDock/BasketTray")
	if tray == null:
		return
	beli_button = tray.get_beli_button()
	if not tray.buy_pressed.is_connected(_on_beli_pressed):
		tray.buy_pressed.connect(_on_beli_pressed)

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

## Leave without buying: the basket empties and the shop hub wipes in.
func _on_back_pressed():
	AnimUtils.back_bounce(back_button)
	Cart.clear()
	if stage.has_method("clear_basket_visuals"):
		stage.clear_basket_visuals()
	AudioDirector.play_sfx(&"popup_close")
	Transition.change_scene("res://Scenes/Koperasi/ShopHub.tscn", Transition.Style.WIPE)

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
		if bubble:
			bubble.say(&"EMPTY")
		return

	var total = Cart.get_total()
	if GameState.player_money < total:
		AudioDirector.play_sfx(&"error")
		if bubble:
			bubble.say(&"POOR")
		return

	# Deduct money
	GameState.player_money -= total

	# Transfer items to inventory. Each unit is sold for the rest of the week --
	# marked here, before the cart empties below, so the shelf keeps its slot empty.
	for item_name in Cart.cart:
		var quantity = Cart.cart[item_name]["quantity"]
		GameState.add_to_inventory(item_name, quantity)
		for _unit in range(quantity):
			GameState.mark_shop_sold(item_name)

	# Clear cart and visuals
	Cart.clear()
	if stage.has_method("clear_basket_visuals"):
		stage.clear_basket_visuals()

	AudioDirector.play_sfx(&"coin")
	_show_message("Pembelian berhasil!", &"ShopMessageSuccess")
	if bubble:
		bubble.say(&"THANKS")

## Show a purchase-feedback message. `variation` selects one of the
## semantic ShopMessage* ThemeFactory variations (Warning/Danger/Success)
## instead of overriding font_color with a token colour at runtime.
func _show_message(text: String, variation: StringName = &"ShopMessageSuccess"):
	if not message_label:
		return
	message_label.text = text
	message_label.theme_type_variation = variation
	AnimUtils.message_pop(message_label)
