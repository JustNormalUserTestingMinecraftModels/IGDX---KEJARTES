@tool
class_name ResultStar
extends Control

## One star in the end-of-minigame result card's three-star row.
##
## Instantiated three times (fixed, in Scenes/Minigames/UI/ResultStar.tscn's
## parent) by MinigameResultPopup.tscn. Before this scene existed,
## BaseMinigame._draw_star_polygon() drew a filled or outlined five-pointed
## star by hand on a throwaway Control every time the result card showed.
##
## Affects: nothing outside itself.
##
## @tool so the scene previews in the editor.

## Whether this star reads as earned. Read by tests and by the popup when
## counting how many stars to reveal.
var is_filled: bool = false

## Shipped art for an earned star, used when the caller passes no texture.
## Before 2026-09-04 both slots defaulted to null, so every minigame fell
## through to _draw()'s procedural polygon and the star row was the one part
## of the result card that never matched the rest of the game's art.
const DEFAULT_FILLED_TEXTURE := "res://Assets/Images/UI/Placeholders/icon_bintang.svg"
## Shipped art for an unearned star.
const DEFAULT_EMPTY_TEXTURE := "res://Assets/Images/UI/Placeholders/icon_bintang_kosong.svg"
## Scene fired at this star's centre when it lands earned.
const BURST_SCENE := "res://Scenes/Minigames/UI/StarBurst.tscn"
## Peak alpha the glow layer reaches on celebrate().
const GLOW_PEAK_ALPHA: float = 0.85
## Seconds the glow takes to bloom before settling back.
const GLOW_BLOOM_TIME: float = 0.18

@onready var icon: TextureRect = $Icon
@onready var glow: TextureRect = $Glow
@onready var burst_slot: Control = $BurstSlot


func _ready() -> void:
	icon.visible = icon.texture != null
	queue_redraw()


## Fill this star from the popup's star art/colour @exports.
##
## `filled_tex` / `empty_tex` are BaseMinigame's popup_star_texture /
## popup_star_empty_texture -- leave either null to fall back to the
## procedural five-pointed polygon _draw() draws below.
##
## Affects: this star's own icon and is_filled. Triggers a redraw.
func set_filled(filled: bool, filled_tex: Texture2D, empty_tex: Texture2D,
		filled_color: Color, empty_color: Color) -> void:
	is_filled = filled
	var tex: Texture2D = filled_tex if filled else empty_tex
	if tex == null:
		tex = load(DEFAULT_FILLED_TEXTURE if filled else DEFAULT_EMPTY_TEXTURE)
	icon.texture = tex
	icon.visible = tex != null
	icon.modulate = filled_color if filled else empty_color
	queue_redraw()


## Land this star: bloom the glow, fire a burst, play the matching rung of the
## three-cue ladder. `index` is 0-based, so the third star gets star_earn_3 --
## three rising cues read as a climb where three identical ones read as a list.
##
## Not a coroutine: play() drives it from its reveal loop, and a test must be
## able to call it. Fire-and-forget -- the burst frees itself.
##
## Affects: this star's Glow layer, and adds a self-freeing burst under
## BurstSlot.
func celebrate(index: int) -> void:
	if Engine.is_editor_hint() or not is_filled:
		return
	AudioDirector.play_sfx(StringName("star_earn_%d" % clampi(index + 1, 1, 3)))
	var burst: Node = load(BURST_SCENE).instantiate()
	burst_slot.add_child(burst)
	burst.plays_sfx = false
	burst.fire()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(glow, "modulate:a", GLOW_PEAK_ALPHA, GLOW_BLOOM_TIME)
	tw.tween_property(glow, "modulate:a", 0.35, GLOW_BLOOM_TIME * 2.0)


## The procedural five-pointed star, drawn only when no texture is set --
## ResultStar falls back to it automatically. Filled draws a solid polygon;
## unfilled draws only the outline.
func _draw() -> void:
	if icon.texture != null:
		return
	var pts := PackedVector2Array()
	var cx := size.x / 2.0
	var cy := size.y / 2.0
	var outer: float = minf(cx, cy) * 0.92
	var inner: float = outer * 0.42
	for i in range(10):
		var angle := deg_to_rad(i * 36.0 - 90.0)
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cx + r * cos(angle), cy + r * sin(angle)))
	var color := icon.modulate
	if is_filled:
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(PackedVector2Array(pts) + PackedVector2Array([pts[0]]), color, 3.0, true)
