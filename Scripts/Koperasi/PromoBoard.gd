@tool
extends Panel

## The Koperasi promo board (Koperasi.tscn: Stage/PromoBoard), advertising
## this week's discounted item. The board, its header and both labels are
## authored in the scene; this only fills the two labels from GameState on
## arrival, because the promo changes every week. Its badge is the tangerine
## PromoBadge the promo item's own price tag wears, so the two read as one
## offer (2026-09-28 Koperasi top-band spec, in the UI depth pass look).

@onready var _item_label: Label = %ItemLabel
@onready var _percent_badge: Label = %PercentBadge

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	refresh()

## Fills the labels from this week's promo; hides the board when there is
## none (an empty shelf).
func refresh() -> void:
	if _item_label == null or _percent_badge == null:
		push_error("PromoBoard: ItemLabel or PercentBadge is missing from Koperasi.tscn")
		return
	visible = GameState.shop_promo_item != ""
	_item_label.text = GameState.shop_promo_item
	_percent_badge.text = "-%d%%" % GameState.shop_promo_percent
