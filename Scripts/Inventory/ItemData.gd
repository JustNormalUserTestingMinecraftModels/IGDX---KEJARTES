class_name ItemData
extends Resource

@export var item_name: String
@export var price: int
@export var icon: Texture2D
@export var description: String
@export var category: String
@export var display_size: Vector2 = Vector2.ZERO
@export var scale: float = 1.0

@export_group("Stats Boost")
@export var mood_boost: int = 0
@export var energy_boost: int = 0
