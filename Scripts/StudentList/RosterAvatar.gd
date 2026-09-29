@tool
class_name RosterAvatar
extends Button

## One student's slot in the StudentList roster strip: their portrait
## inside a ring tinted green when that student's week is scheduled and
## red when it is not. Four of these sit above the carousel so the
## roster's progress reads without paging through every card, which is
## the problem this screen had -- it asks "who still needs a schedule?"
## and answered it one student at a time.
##
## The current student's avatar reads unmistakably: it grows, lifts a
## few px, and wears a sunflower glow ring (Highlight) plus a
## brand-primary border (Border); the rest shrink and dim. Switching
## is_current bounces into the new state with an overshoot settle
## rather than hard-setting it (2026-09-28 muridmu-rostercard spec
## §4.2), so the eye follows a swipe up to the strip.
##
## @tool so the Inspector and the MCP test suite both see applied state
## rather than only authored defaults; every setter guards on
## is_node_ready(), matching StickyNote.gd's established pattern. The
## button itself is the GhostButton variation, which draws nothing at
## rest so the baked ring art can be the button. Ring art is white and
## tinted via self_modulate from tokens. Scale/lift animate the Button
## itself rather than a visual child: Control.scale is part of the
## transform Godot hit-tests against, so it shrinks the real tap region
## along with the visual, not just the look -- at INACTIVE_SCALE (0.82)
## the 150px avatar's effective hit region is 123px, still comfortably
## above tokens.touch_target_min (96px). get_combined_minimum_size()
## alone (unaffected by `scale`) does NOT prove this on its own; the
## touch-target test multiplies it by `scale` to check the real number.

## Visual scale for every avatar that is not the current one.
const INACTIVE_SCALE := 0.82
## Visual scale for the current avatar. The spec says "~1.4"; review found
## that scale (even a first-round reduction to 1.3) put the ring's scaled
## top past HeaderLabel's bottom and/or its scaled bottom past
## CardContainer's top or the nav arrows -- the strip's natural position
## sits close enough to both neighbours that the ring is always the
## binding constraint. 1.25, the floor the review allows, paired with
## tight ring padding and StudentList.tscn's RosterStrip/CardContainer
## repositioned for headroom, clears the whole stack (title, ring, card,
## arrows) with room to spare (test_active_avatar_ring_clears_the_-
## title_and_the_card does the arithmetic for both screen sizes) while
## staying clearly dominant.
const ACTIVE_SCALE := 1.25
## How far the current avatar lifts upward, in px.
const ACTIVE_LIFT_PX := 4.0
## Overshoot-settle duration for an is_current change (spec §4.2).
const BOUNCE_SECONDS := 0.42

## The student's portrait, drawn inside the ring.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			$Portrait.texture = value

## True once this student's week is scheduled. Tints the ring
## state_success; false tints it state_danger.
@export var is_scheduled: bool = false:
	set(value):
		is_scheduled = value
		if is_node_ready():
			_apply_schedule_tint()

## True for the student the carousel is currently showing. The current
## avatar grows to ACTIVE_SCALE, lifts, and rings gold/brand; the rest
## sit at INACTIVE_SCALE/inactive_alpha. Bounces into place unless the
## change lands before _ready(), in the editor, or under
## GameSettings.reduce_motion, all of which snap straight to target.
@export var is_current: bool = false:
	set(value):
		is_current = value
		if is_node_ready():
			_apply_current_state(true)

## Opacity for avatars that are not the current card. Low enough to
## recede, high enough that the ring's state colour still reads.
@export_range(0.3, 1.0, 0.05) var inactive_alpha: float = 0.55

var _bounce_tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0
	$Portrait.texture = portrait_texture
	_apply_schedule_tint()
	_apply_current_state(false)


func _exit_tree() -> void:
	if _bounce_tween != null:
		_bounce_tween.kill()


func _apply_schedule_tint() -> void:
	var tokens := DesignTokens.load_default()
	$Ring.self_modulate = tokens.state_success if is_scheduled else tokens.state_danger


## Drives the grow/lift/glow/border read for is_current. `animate` false
## snaps straight to the target -- the initial _ready() apply, the
## editor, and GameSettings.reduce_motion all take that path; everything
## else bounces with TRANS_BACK's natural overshoot.
func _apply_current_state(animate: bool) -> void:
	var tokens := DesignTokens.load_default()
	var target_scale: float = ACTIVE_SCALE if is_current else INACTIVE_SCALE
	var target_lift: float = -ACTIVE_LIFT_PX if is_current else 0.0
	var target_alpha: float = 1.0 if is_current else inactive_alpha
	var ring_alpha: float = 1.0 if is_current else 0.0
	$Highlight.self_modulate = tokens.accent_sunflower
	$Border.self_modulate = tokens.brand_primary

	if _bounce_tween != null:
		_bounce_tween.kill()
		_bounce_tween = null

	if not animate or Engine.is_editor_hint() or GameSettings.reduce_motion:
		scale = Vector2(target_scale, target_scale)
		position.y = target_lift
		modulate.a = target_alpha
		$Highlight.modulate.a = ring_alpha
		$Border.modulate.a = ring_alpha
		return

	_bounce_tween = create_tween().set_parallel(true)
	_bounce_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), BOUNCE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "position:y", target_lift, BOUNCE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "modulate:a", target_alpha, BOUNCE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property($Highlight, "modulate:a", ring_alpha, BOUNCE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property($Border, "modulate:a", ring_alpha, BOUNCE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
