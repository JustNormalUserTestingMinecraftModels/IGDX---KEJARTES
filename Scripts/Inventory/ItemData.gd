class_name ItemData
extends Resource

## One catalog entry: a shop shelf item, a cart line, and an inventory
## stack all point at the same ItemData instance. ItemDatabase.gd builds
## the catalog these resources come from; Cart.gd and GameState.inventory
## hold references to them at runtime.

## The catalog key. Also used as the Dictionary key in
## GameState.inventory and Cart.cart -- rename an item and every save of
## it (there is none, but every live cart/inventory entry) loses the link.
@export var item_name: String
## Deducted from GameState.player_money on purchase; multiplied by
## quantity for Cart.get_total().
@export var price: int
## Shown on the shop shelf button and the inventory slot.
@export var icon: Texture2D
## Shown in the inventory item-detail popup. Not shown on the shelf.
@export var description: String
## Groups items for shop shelf placement and inventory filtering. Free
## text set per-entry in ItemDatabase.gd -- there is no enum.
@export var category: String
## Fixed on-screen size for the shop's falling/basket art and the
## inventory slot icon. Zero means "use the source button's own size" --
## see rakbarang_1.gd's get_item_effective_size().
@export var display_size: Vector2 = Vector2.ZERO
## Extra multiplier on top of display_size (or the button-size fallback)
## when an item's art needs to read larger or smaller than its peers.
@export var scale: float = 1.0

@export_group("Stats Boost")
## Added to the target student's mood when GameState.use_item() consumes
## one, scaled by quantity and clamped to [0, 100]. Most items leave this
## at 0 -- only consumables set it.
@export var mood_boost: int = 0
## Same as mood_boost, but for energy.
@export var energy_boost: int = 0
