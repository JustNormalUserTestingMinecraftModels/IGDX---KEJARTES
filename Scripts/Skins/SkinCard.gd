@tool
class_name SkinCard
extends Control

## One skin in SkinSelect's carousel (SkinCard.tscn; mockup
## skinselection_mockup.png, spec
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md). The
## centred card is crisp and full colour; the ones either side are dimmed
## and blurred so the middle one reads as the selection.
##
## The card is the splash's own 1080x1920 canvas. SkinSelect poses it every
## frame the carousel moves (set_pose): position, scale, and a focus from 0
## (the neighbour slot: dimmed, blurred) to 1 (centred: crisp). The blur is
## skin_card_focus.gdshader on Art's local-to-scene material, so it blurs
## this card's own splash, not the screen behind it.
##
## @tool so the test runner can drive it; it has no side effects of its own.

## Drag speed (px/s) past which a flick picks the next card on its own,
## whatever distance it covered. Mirrors BasketTray's own flick threshold so
## the two drag gestures in the game settle the same way.
const FLICK_SPEED := 600.0
## Fraction of one card's pitch a slow drag must cross to commit to the next
## card. 0.5 is the midpoint: past it the carousel moves on, short of it it
## springs back.
const COMMIT_RATIO := 0.5

## The skin id shown, "" before show_skin().
var skin_id: String = ""

## The focus set_pose last applied, 0 (neighbour) to 1 (centred).
var focus: float = 1.0


## Where a released drag settles. `travel` is how far the track has moved
## (negative is leftwards, towards a higher index) and `velocity` is the
## release speed in px/s, same sign convention. `pitch` is one card's width
## plus the track's separation. Static and tree-free so it can be tested
## without a frame -- the same shape as BasketTray.classify_drag.
static func settle_index(current: int, travel: float, velocity: float,
		pitch: float, count: int) -> int:
	var step := 0
	if absf(velocity) >= FLICK_SPEED:
		step = 1 if velocity < 0.0 else -1
	elif absf(travel) >= pitch * COMMIT_RATIO:
		step = 1 if travel < 0.0 else -1
	return clampi(current + step, 0, maxi(count - 1, 0))


## Shows skin `id` of `who`. `locked` draws the lock overlay; the card is
## still shown, because a player should see what they have not earned.
func show_skin(who: String, id: String, locked: bool) -> void:
	skin_id = id
	var path := StudentSkins.layer_path(who, id, "splash")
	var art := get_node(^"Art") as TextureRect
	art.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Lock") as Control).visible = locked


## Places and styles the card for one frame of the carousel. `origin` and
## `card_scale` are in the carousel's design pixels. `focus` runs from 0 (the
## neighbour slot) to 1 (centred). `side_brightness` and `side_blur_px` are
## the neighbour slot's look, and the blur is in SCREEN pixels, converted to
## texels here because the texture is drawn at `card_scale`.
func set_pose(origin: Vector2, card_scale: float, focus_amount: float,
		side_brightness: float, side_blur_px: float) -> void:
	focus = clampf(focus_amount, 0.0, 1.0)
	position = origin
	scale = Vector2(card_scale, card_scale)
	var mat := (get_node(^"Art") as TextureRect).material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(&"brightness", lerpf(side_brightness, 1.0, focus))
	mat.set_shader_parameter(&"sigma_texels",
		(1.0 - focus) * side_blur_px / maxf(card_scale, 0.01))
