@tool
extends PanelContainer

## A koperasi price tag: a green coin pill showing an item's price, which
## wipes left-to-right to dark green and swaps its label to "Beli" when the
## player buys. Three states -- rest, pressed, and unaffordable.
##
## The tag is the press target for buying, which gives the item's flight
## into the basket an explicit trigger.
##
## The week's promo item wears extra dress inside the same Row: set_promo()
## shows the struck list price ahead of the (already-discounted) value from
## set_price(), plus a "-N%" badge after it. clear_promo() drops both.

## Word shown in place of the price once the player commits to buying.
const BELI_TEXT := "Beli"

## How long the dark green wipe takes to cross the pill, in seconds.
## Matches DesignTokens.dur_fast (0.18) so the tag agrees with the rest of
## the UI without depending on a token that would need an editor restart.
@export var wipe_duration: float = 0.18

## Delay before the label pops, in seconds. Deliberately longer than
## wipe_duration so the pop lands after the wipe arrives rather than
## competing with it.
@export var label_delay: float = 0.23

## How long the label's scale pop takes, in seconds.
@export var pop_duration: float = 0.22

## Scale the label springs up from when it swaps to "Beli".
@export var pop_from_scale: float = 0.55

@onready var _wipe: ColorRect = $WipeHost/Wipe
@onready var _value: Label = $Row/Value
@onready var _old_price: Label = $Row/OldPrice
@onready var _badge: Label = $Row/PromoBadge

var _price: int = 0

## True once set_promo() has dressed the tag with a struck list price and a
## badge; false again after clear_promo(). set_price() does NOT clear this --
## KoperasiStage.gd calls set_price() every refresh regardless, then set_promo()
## or clear_promo() to say whether the item is still this week's promo, so a
## fresh price on the same promo item must not silently drop its dress.
var _is_promo: bool = false

## Node names already push_error'd missing by _ensure_nodes(), so a torn-up
## tag logs one error per node instead of one on every call -- mirrors
## BasketTray.gd's _reported_missing_footer_nodes.
var _reported_missing_nodes: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	if is_instance_valid(_wipe):
		_wipe.color = DesignTokens.load_default().koperasi_tag_pressed_fill
		_wipe.size.x = 0.0

## Sets the displayed price and returns the tag to its rest state. Also the
## tag's return to rest after play_buy(): if _is_promo is still set, the
## struck list price and badge that play_buy() hid come back with the price,
## so a re-dressed promo tag never gets stuck showing "Beli" alone.
func set_price(value: int) -> void:
	_price = value
	_ensure_nodes()
	_value.text = str(value)
	_value.scale = Vector2.ONE
	theme_type_variation = &"PriceTag"
	if is_instance_valid(_wipe):
		_wipe.size.x = 0.0
	if _is_promo:
		if is_instance_valid(_old_price):
			_old_price.visible = true
		if is_instance_valid(_badge):
			_badge.visible = true

## Reads the label. Exists so tests can assert without knowing node paths.
func get_label_text() -> String:
	_ensure_nodes()
	return _value.text

## True once the tag is dressed for the week's promo item.
func is_promo() -> bool:
	return _is_promo

## Reads the struck list-price label. Exists so tests can assert without
## knowing node paths.
func get_old_price_text() -> String:
	_ensure_nodes()
	return _old_price.text

## Reads the promo badge's "-N%" label. Exists so tests can assert without
## knowing node paths.
func get_badge_text() -> String:
	_ensure_nodes()
	return _badge.text

## Dresses the tag for the week's promo item: `list_price` (before the
## promo) appears struck alongside the already-discounted price set by
## set_price(), and a "-N%" badge names the cut. Does not touch set_price's
## own display -- callers set that first.
func set_promo(list_price: int, percent: int) -> void:
	_ensure_nodes()
	_is_promo = true
	if is_instance_valid(_old_price):
		_old_price.text = str(list_price)
		_old_price.visible = true
	if is_instance_valid(_badge):
		_badge.text = "-%d%%" % percent
		_badge.visible = true

## Drops the promo dress, returning the tag to a plain price.
func clear_promo() -> void:
	_ensure_nodes()
	_is_promo = false
	if is_instance_valid(_old_price):
		_old_price.visible = false
	if is_instance_valid(_badge):
		_badge.visible = false

## Greys the tag out when the player cannot afford the item. The price
## stays visible -- the player should always know what something costs.
func set_affordable(can_afford: bool) -> void:
	_ensure_nodes()
	theme_type_variation = &"PriceTag" if can_afford else &"PriceTagDisabled"

## Runs the buy transition: dark green wipes left to right, then the price
## swaps to "Beli" with a scale pop. The label text changes synchronously
## so callers and tests can rely on it immediately. Also hides the promo
## dress (struck list price, badge) if any is showing, so a promo tag never
## reads "~~1000~~ Beli -20%" mid-tap -- the word stands alone, like on any
## tag. Does not touch _is_promo: set_price() brings the dress back with the
## price once the tag returns to rest.
func play_buy() -> void:
	_ensure_nodes()
	_value.text = BELI_TEXT
	theme_type_variation = &"PriceTagPressed"
	if is_instance_valid(_old_price):
		_old_price.visible = false
	if is_instance_valid(_badge):
		_badge.visible = false
	if not is_inside_tree():
		return

	if is_instance_valid(_wipe):
		var host := _wipe.get_parent() as Control
		_wipe.position = Vector2.ZERO
		_wipe.size = Vector2(0.0, host.size.y if host != null else size.y)
		var wipe_tween := create_tween()
		wipe_tween.tween_property(_wipe, "size:x", host.size.x if host != null else size.x, wipe_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	_value.pivot_offset = _value.size / 2.0
	_value.scale = Vector2(pop_from_scale, pop_from_scale)
	var pop := create_tween()
	pop.tween_interval(label_delay)
	pop.tween_property(_value, "scale", Vector2.ONE, pop_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Resolves @onready nodes when the tag is used before _ready -- tests
## instantiate the scene without adding it to the tree. A still-missing
## OldPrice or PromoBadge gets a push_error, once per node name, so a
## torn-up tag fails loudly instead of on every call.
func _ensure_nodes() -> void:
	if not is_instance_valid(_value):
		_value = get_node_or_null("Row/Value")
	if not is_instance_valid(_wipe):
		_wipe = get_node_or_null("WipeHost/Wipe")
	if not is_instance_valid(_old_price):
		_old_price = get_node_or_null("Row/OldPrice")
		if not is_instance_valid(_old_price):
			_report_missing_node("Row/OldPrice")
	if not is_instance_valid(_badge):
		_badge = get_node_or_null("Row/PromoBadge")
		if not is_instance_valid(_badge):
			_report_missing_node("Row/PromoBadge")


## push_error, once per node path -- see _ensure_nodes()'s doc.
func _report_missing_node(node_path: String) -> void:
	if _reported_missing_nodes.has(node_path):
		return
	_reported_missing_nodes[node_path] = true
	push_error("PriceTag: %s node missing" % node_path)
