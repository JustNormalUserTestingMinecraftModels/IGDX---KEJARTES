@tool
extends PanelContainer

## A koperasi price tag: a green coin pill showing an item's price, which
## wipes left-to-right to dark green and swaps its label to "Beli" when the
## player buys. Three states -- rest, pressed, and unaffordable.
##
## The tag is the press target for buying, which gives the item's flight
## into the basket an explicit trigger.

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

var _price: int = 0

func _ready() -> void:
	clip_contents = true
	if is_instance_valid(_wipe):
		_wipe.color = Color("#2F5A0D")
		_wipe.size.x = 0.0
	_ignore_mouse_so_taps_reach_the_button_beneath()

## PanelContainer (and its Row/Coin/Value children) default to
## MOUSE_FILTER_STOP, which swallows taps landing on the pill instead of
## letting them reach the shelf TextureButton it sits on top of -- the most
## likely place a player aims. Set in code rather than the scene since this
## needs to apply without editing PriceTag.tscn.
func _ignore_mouse_so_taps_reach_the_button_beneath() -> void:
	if is_instance_valid(self):
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := get_node_or_null("Row")
	if is_instance_valid(row):
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := get_node_or_null("Row/Coin")
	if is_instance_valid(coin):
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var value := get_node_or_null("Row/Value")
	if is_instance_valid(value):
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Sets the displayed price and returns the tag to its rest state.
func set_price(value: int) -> void:
	_price = value
	_ensure_nodes()
	_value.text = str(value)
	_value.scale = Vector2.ONE
	theme_type_variation = &"PriceTag"
	if is_instance_valid(_wipe):
		_wipe.size.x = 0.0

## Reads the label. Exists so tests can assert without knowing node paths.
func get_label_text() -> String:
	_ensure_nodes()
	return _value.text

## Greys the tag out when the player cannot afford the item. The price
## stays visible -- the player should always know what something costs.
func set_affordable(can_afford: bool) -> void:
	_ensure_nodes()
	theme_type_variation = &"PriceTag" if can_afford else &"PriceTagDisabled"

## Runs the buy transition: dark green wipes left to right, then the price
## swaps to "Beli" with a scale pop. The label text changes synchronously
## so callers and tests can rely on it immediately.
func play_buy() -> void:
	_ensure_nodes()
	_value.text = BELI_TEXT
	theme_type_variation = &"PriceTagPressed"
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
## instantiate the scene without adding it to the tree.
func _ensure_nodes() -> void:
	if not is_instance_valid(_value):
		_value = get_node_or_null("Row/Value")
	if not is_instance_valid(_wipe):
		_wipe = get_node_or_null("WipeHost/Wipe")
