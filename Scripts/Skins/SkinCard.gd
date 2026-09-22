@tool
class_name SkinCard
extends Control

## One skin in SkinSelect's carousel (SkinCard.tscn; mockup
## skinselection_mockup.png, spec
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md). The
## centred card is crisp and full colour; the ones either side are dimmed
## and blurred so the middle one reads as the selection.
##
## The card is 752x1337, not 1080x1920: the tray's top edge is at y=1337, so
## a full-screen splash would lose its bottom 583px -- the shoes and the
## skirt hem, on the one screen whose job is showing an outfit. Scaled to
## the band's height the figure is 752 wide and wholly visible, which also
## leaves 328px for the neighbouring card to peek into.
##
## @tool so the test runner can drive it; it has no side effects of its own.

## The blur worn by every card except the centred one. A preloaded resource
## swapped onto Art, never built at runtime.
const BLUR_MATERIAL := preload("res://Scenes/Skins/skin_option_blur_material.tres")

## Drag speed (px/s) past which a flick picks the next card on its own,
## whatever distance it covered. Mirrors BasketTray's own flick threshold so
## the two drag gestures in the game settle the same way.
const FLICK_SPEED := 600.0
## Fraction of one card's pitch a slow drag must cross to commit to the next
## card. 0.5 is the midpoint: past it the carousel moves on, short of it it
## springs back.
const COMMIT_RATIO := 0.5

## Tint on a card that is not the centred one.
@export var unselected_modulate: Color = Color(0.55, 0.55, 0.62, 1.0)

## The skin id shown, "" before show_skin().
var skin_id: String = ""


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


## Crisp and full colour when centred, dimmed and blurred otherwise.
func set_selected(sel: bool) -> void:
	var art := get_node(^"Art") as TextureRect
	art.modulate = Color.WHITE if sel else unselected_modulate
	art.material = null if sel else BLUR_MATERIAL
