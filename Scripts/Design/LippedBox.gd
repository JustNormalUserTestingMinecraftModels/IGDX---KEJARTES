@tool
class_name LippedBox
extends RefCounted

## Builds the depth look -- a face on a solid darker lip, with a soft gloss
## along its top -- out of Godot's own StyleBoxFlat (2026-09-28 UI depth
## pass; docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md).
##
## Native rather than a custom StyleBox script, on purpose: the project theme
## is loaded at startup before the SceneTree exists, and any script running
## then makes the attached debugger log "SceneTree::get_singleton() is null"
## on every debug run. So the lip is the box's drop shadow -- solid, one
## pixel soft, offset down by the lip height into the strip that a negative
## expand_margin_bottom frees under the face -- and the gloss is a light top
## border blended into the face.
##
## Held (pressed), the face moves down by the lip height onto the lip and the
## lip is not drawn. The readers below recover the lip from those same
## fields, so tests and PressFeel need no metadata.

## Height of the soft gloss along the face's top edge, px.
const GLOSS_WIDTH := 14
## The lip's edge softness, px. 1 keeps it a crisp slab.
const LIP_SOFTNESS := 1


## A lipped face: `face` on a `lip_height` px `lip`, with corners of
## `radius`. `gloss` is how much lighter than the face the top highlight
## starts (0 draws none -- panels); `pressed` builds the held state.
## Padding is the caller's: see set_vertical_padding().
static func make(face: Color, lip: Color, lip_height: int, radius: int,
		gloss: float, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	if gloss > 0.0:
		sb.border_width_top = GLOSS_WIDTH
		sb.border_color = face.lightened(gloss)
		sb.border_blend = true
	sb.shadow_color = lip
	set_lip(sb, lip_height, pressed)
	return sb


## Carve a `lip_height` px lip under `sb`'s face, resting or held. Does not
## touch the padding -- see relip() to keep it.
static func set_lip(sb: StyleBoxFlat, lip_height: int, pressed: bool) -> void:
	var lip := float(maxi(lip_height, 0))
	sb.expand_margin_top = -lip if pressed else 0.0
	sb.expand_margin_bottom = 0.0 if pressed else -lip
	var shows := lip > 0.0 and not pressed
	sb.shadow_size = LIP_SOFTNESS if shows else 0
	sb.shadow_offset = Vector2(0.0, lip) if shows else Vector2.ZERO


## The lip height `sb` was built with, resting or held.
static func lip_height_of(sb: StyleBoxFlat) -> int:
	return roundi(-minf(sb.expand_margin_top, sb.expand_margin_bottom))


## True for a held (pressed) lipped face.
static func is_pressed(sb: StyleBoxFlat) -> bool:
	return sb.expand_margin_top < 0.0


## True when `box` is a lipped face: a StyleBoxFlat with a lip carved out.
static func is_lipped(box: StyleBox) -> bool:
	var sb := box as StyleBoxFlat
	return sb != null and lip_height_of(sb) > 0


## Split `pad_v` between top and bottom so the label centres on the face,
## keeping the sum -- and so the button's height -- unchanged. At rest the
## label rises by half the lip; held, it drops by the same, moving with the
## face.
static func set_vertical_padding(sb: StyleBoxFlat, pad_v: int) -> void:
	var shift := mini(floori(lip_height_of(sb) / 2.0), pad_v)
	var lift := -shift if is_pressed(sb) else shift
	sb.content_margin_top = pad_v - lift
	sb.content_margin_bottom = pad_v + lift


## Give `sb` a new lip height, keeping its padding and its state -- the
## scrapbook tiles' thicker lip.
static func relip(sb: StyleBoxFlat, lip_height: int) -> void:
	var pad := roundi((sb.content_margin_top + sb.content_margin_bottom) / 2.0)
	set_lip(sb, lip_height, is_pressed(sb))
	set_vertical_padding(sb, pad)
