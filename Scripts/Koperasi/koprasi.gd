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
## Beli, THANKS on a successful one, OUT_OF_STOCK on the Stage's
## shelf_dead_tap (a tap landing on a slot that just sold or emptied).
## Lines come from DialogueCatalog. The bubble also drives
## Stage/Herman/HermanAP's idle/talk animation and an idle-chatter timer --
## Cart.cart_changed resets that timer so any cart activity pushes the next
## ambient line back out.

@onready var stage: Control = $Stage
@onready var back_button: TextureButton = $Stage/BackButton
# CoinHUD stands on the counter ledge, part of the Stage, since the
# 2026-09-17 revamp.
@onready var coin_hud: HBoxContainer = %CoinHUD
@onready var coin_label: Label = get_node("%CoinHUD/CoinLabel")
@onready var message_label: Label = $MessageLabel
@onready var bubble: ChatBubble = $Stage/ChatBubble
@onready var herman_ap: AnimationPlayer = get_node_or_null("Stage/Herman/HermanAP") as AnimationPlayer
@onready var tray: BasketTray = get_node_or_null("Stage/TrayDock/BasketTray") as BasketTray
@onready var crate: TextureButton = get_node_or_null("Stage/CrateHandle") as TextureButton

## CrateHandle's authored position (top-left, Stage-local -- Stage itself is
## the one 1080x1920 piece that re-anchors as a whole on tall phones, so a
## fixed offset here is correct at any phone height) while the tray is
## EXPANDED. CrateHandle's own pivot is (0,0) (top-left), so this is also its
## on-screen top-left at any scale: it is set to Body/Emblem's authored rect
## top-left (24 (Body's left inset) + 876 (Emblem's own offset_left) = 900,
## 1360 (Body's absolute top, itself 117 (TrayDock) + 1243 (Emblem's parent
## Body offset_top)) - 64 (Emblem's offset_top) = 1296) -- see
## docs/superpowers/specs/2026-09-17-koperasi-polish-design.md section 3.
@export var crate_pos_expanded: Vector2 = Vector2(900.0, 1296.0)
## CrateHandle's position while the tray is COLLAPSED -- large (scale 1.0),
## bottom-right of the Stage with a 40px margin off both edges
## (1080-40-320=720, 1920-40-320=1560).
@export var crate_pos_collapsed: Vector2 = Vector2(720.0, 1560.0)

## BackButton's authored position (Stage-local) while the tray is EXPANDED --
## kept equal to BackButton's own authored offset_left/offset_top (24, 1157)
## in koprasi.tscn so nothing jumps on load; test_tall_screen_layout.gd pins
## that authored rect as "unchanged". The tray's own visible top (Body) sits
## at 1360 (117 TrayDock + 1243 Body offset_top, see crate_pos_expanded's own
## comment above), so BackButton's authored bottom edge (1157+185=1342)
## already sits a comfortable 18px above it.
@export var back_pos_expanded: Vector2 = Vector2(24.0, 1157.0)
## BackButton's position while the tray is COLLAPSED -- 12px above the
## collapsed crate handle's top edge. CrateHandle's own pivot is (0,0) and
## its COLLAPSED scale is 1.0 (see _on_tray_state_changed), so
## crate_pos_collapsed.y (1560) IS its on-screen top at that state:
## 1560 - 185 (BackButton's own height) - 12 (gap) = 1363. x matches
## back_pos_expanded.x -- the back button never moves sideways.
@export var back_pos_collapsed: Vector2 = Vector2(24.0, 1363.0)

var beli_button: Button
## The tween sliding/scaling the crate handle to match the tray's state;
## killed before a new one starts so two quick toggles never fight.
var _crate_tween: Tween

func _ready():
	if back_button:
		back_button.pivot_offset = back_button.size / 2
		if not back_button.pressed.is_connected(_on_back_pressed):
			back_button.pressed.connect(_on_back_pressed)
		# Place it at whichever position matches the tray's current state
		# (no animation) -- the tray always starts EXPANDED (no persistence,
		# spec section "Cross-cutting"), so this is back_pos_expanded unless
		# a future change starts the tray COLLAPSED.
		var tray_expanded := not is_instance_valid(tray) or tray.is_expanded()
		back_button.position = back_pos_expanded if tray_expanded else back_pos_collapsed

	_setup_beli_button()
	_update_coin_display()

	# Signal-driven coin updates
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)

	if not Cart.item_added.is_connected(_on_cart_item_added):
		Cart.item_added.connect(_on_cart_item_added)
	if not Cart.item_removed.is_connected(_on_cart_item_removed):
		Cart.item_removed.connect(_on_cart_item_removed)
	if not Cart.cart_changed.is_connected(_on_cart_changed):
		Cart.cart_changed.connect(_on_cart_changed)

	# rakbarang_1.gd declares no class_name, so `stage` is typed as plain
	# Control -- go through Signal(object, name) rather than a static
	# `stage.shelf_dead_tap` member access, which the parser would reject.
	if stage and stage.has_signal("shelf_dead_tap"):
		var dead_tap := Signal(stage, "shelf_dead_tap")
		if not dead_tap.is_connected(_on_shelf_dead_tap):
			dead_tap.connect(_on_shelf_dead_tap)

	if bubble and herman_ap:
		bubble.set_herman_ap(herman_ap)

	if is_instance_valid(tray) and not tray.state_changed.is_connected(_on_tray_state_changed):
		tray.state_changed.connect(_on_tray_state_changed)
	if is_instance_valid(crate) and not crate.pressed.is_connected(_on_crate_pressed):
		crate.pressed.connect(_on_crate_pressed)
	if is_instance_valid(crate):
		# CrateHandle is a 320px TextureButton positioned/scaled by our own
		# _crate_tween (pivot (0,0), see crate_pos_expanded/collapsed above)
		# and already gets press feedback from _on_crate_pressed's idle_bounce
		# stop + _on_tray_state_changed's tween. UIPolish auto-juices every
		# BaseButton it sees (Scripts/UI/UIPolish.gd): Juice.press/release
		# would recentre its pivot_offset and tween scale, which both breaks
		# the (0,0)-pivot math above and fights the crate's own tween. Opting
		# out here is honoured even though UIPolish wires its handlers at
		# node_added time (before this _ready runs) -- its _skip() re-checks
		# has_meta(Juice.NO_AUTO_JUICE) at press time, not wire time, so a
		# meta set anywhere in _ready still works.
		crate.set_meta(Juice.NO_AUTO_JUICE, true)
	_refresh_crate_badge()

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
	if Cart.cart_changed.is_connected(_on_cart_changed):
		Cart.cart_changed.disconnect(_on_cart_changed)
	if stage and stage.has_signal("shelf_dead_tap"):
		var dead_tap := Signal(stage, "shelf_dead_tap")
		if dead_tap.is_connected(_on_shelf_dead_tap):
			dead_tap.disconnect(_on_shelf_dead_tap)

## Any cart activity (add, remove, clear) pushes Pak Herman's idle-chatter
## timer back out, so he doesn't ramble mid-shopping, and refreshes the
## crate handle's own mirrored count badge (the header emblem's badge is
## hidden while collapsed, so the crate carries the count instead).
func _on_cart_changed() -> void:
	if bubble:
		bubble.reset_idle_timer()
	_refresh_crate_badge()

func _on_cart_item_added(item_name: String) -> void:
	if bubble:
		bubble.say_for_item(&"ADD", item_name)

func _on_cart_item_removed(item_name: String) -> void:
	if bubble:
		bubble.say_for_item(&"REMOVE", item_name)

## The Stage's shelf_dead_tap: a tap landed on a slot that already sold or
## is sitting in the basket. `item_name` is unused today (OUT_OF_STOCK has
## no per-item pool) but kept so a future per-item line needs no signal
## change.
func _on_shelf_dead_tap(_item_name: String) -> void:
	if bubble:
		bubble.say(&"OUT_OF_STOCK")

func _setup_beli_button():
	# Beli lives in the basket tray's footer.
	if not is_instance_valid(tray):
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

## The big crate icon: toggles the tray exactly like its header emblem does.
## Stops idle_bounce first -- _on_tray_state_changed() resumes the right
## animation (RESET or idle_bounce) for the new state right after. UIPolish
## already wires this TextureButton's own press/release Juice pulse, so no
## extra Juice.press()/release() call is added here (that would double it).
func _on_crate_pressed() -> void:
	if not is_instance_valid(tray):
		return
	if is_instance_valid(crate):
		var ap := crate.get_node_or_null("AP") as AnimationPlayer
		if ap and ap.current_animation == "idle_bounce":
			ap.stop()
	tray.toggle()

## Mirrors the crate handle's pose and idle animation to the tray's state,
## and mutes Pak Herman's idle chatter while the tray is tucked away (a
## collapsed tray means the player is busy browsing the shelf, not the cart).
func _on_tray_state_changed(state: int) -> void:
	if not is_instance_valid(crate):
		return
	var expanded: bool = state == BasketTray.ViewState.EXPANDED
	if is_instance_valid(_crate_tween) and _crate_tween.is_valid():
		_crate_tween.kill()
	_crate_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_crate_tween.set_parallel(true)
	_crate_tween.tween_property(crate, "scale",
		Vector2(0.35, 0.35) if expanded else Vector2.ONE, 0.28)
	_crate_tween.tween_property(crate, "position",
		crate_pos_expanded if expanded else crate_pos_collapsed, 0.28)
	# The back button rides down/up with the crate as one piece -- same
	# tween, same duration/trans/ease, same parallel() group (spec section 4
	# "Cross-cutting: one tween per user gesture").
	if back_button:
		_crate_tween.tween_property(back_button, "position",
			back_pos_expanded if expanded else back_pos_collapsed, 0.28)
	var ap := crate.get_node_or_null("AP") as AnimationPlayer
	if ap:
		ap.play("RESET" if expanded else "idle_bounce")
	if bubble:
		bubble.idle_chatter_enabled = expanded
		bubble.reset_idle_timer()
	_refresh_crate_badge()

## Mirrors Cart's item count onto CrateHandle/CountBadge (spec section 3):
## visible only while the tray is COLLAPSED and the count is non-zero -- the
## header emblem's own badge (BasketTray._emblem_badge) already handles the
## EXPANDED case and hides itself while collapsed.
func _refresh_crate_badge() -> void:
	if not is_instance_valid(crate):
		return
	var badge := crate.get_node_or_null("CountBadge")
	if badge == null:
		return
	var count: int = Cart.get_item_count()
	var label := badge.get_node_or_null("Count") as Label
	if label:
		label.text = str(count)
	var collapsed: bool = not (is_instance_valid(tray) and tray.is_expanded())
	badge.visible = collapsed and count > 0

## Show a purchase-feedback message. `variation` selects one of the
## semantic ShopMessage* ThemeFactory variations (Warning/Danger/Success)
## instead of overriding font_color with a token colour at runtime.
func _show_message(text: String, variation: StringName = &"ShopMessageSuccess"):
	if not message_label:
		return
	message_label.text = text
	message_label.theme_type_variation = variation
	AnimUtils.message_pop(message_label)
