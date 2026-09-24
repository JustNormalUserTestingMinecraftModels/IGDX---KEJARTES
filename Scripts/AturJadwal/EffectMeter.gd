@tool
class_name EffectMeter
extends HBoxContainer

## A row of up to three pips saying how big one effect is, in the picker's
## arrow language (2026-09-24 visual polish, D11/D12): green up-arrows for a
## gain, red down-arrows for a cost, gold coins for Wirausaha's earnings.
## More pips, bigger effect. ActivityPreview decides the count from Balance;
## this only draws it.
##
## The three pips are authored nodes in EffectMeter.tscn, never built here,
## so the count only toggles visibility -- the picker adds nothing to the
## test_viewport_editability ratchet. Arrows are textures because none of
## our fonts carries the arrow glyphs.

## What a meter is counting, which picks its pip texture.
enum Kind { GAIN, COST, COIN }

## The green up-arrow a gain draws.
@export var up_texture: Texture2D
## The red down-arrow a cost draws.
@export var down_texture: Texture2D
## The gold coin Wirausaha's earnings draw.
@export var coin_texture: Texture2D
## Size of each pip. Set per instance on this root, where an instanced
## scene's overrides serialise.
@export var pip_size: Vector2 = Vector2(32, 32):
	set(value):
		pip_size = value
		if is_inside_tree():
			_apply_size()


func _ready() -> void:
	_apply_size()


func _apply_size() -> void:
	for pip in get_children():
		if pip is Control:
			(pip as Control).custom_minimum_size = pip_size


## Show `count` pips of `kind`. A count past the three authored pips is
## clamped; 0 hides the meter's pips entirely.
func show_effect(count: int, kind: Kind) -> void:
	var tex: Texture2D = up_texture
	match kind:
		Kind.COST: tex = down_texture
		Kind.COIN: tex = coin_texture
	var i := 0
	for pip in get_children():
		if pip is TextureRect:
			(pip as TextureRect).texture = tex
			(pip as TextureRect).visible = i < count
			i += 1


## How many pips are showing now. For tests.
func shown_count() -> int:
	var n := 0
	for pip in get_children():
		if pip is TextureRect and (pip as TextureRect).visible:
			n += 1
	return n
