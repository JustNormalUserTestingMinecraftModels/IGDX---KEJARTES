@tool
extends GPUParticles2D
class_name RewardParticles

## A one-shot congratulation burst (2026-09-03 spec section 3.3), shared
## by the per-stat RewardBurst and the screen-wide CelebrationConfetti --
## the two scenes differ only in their authored emitter settings, never
## in code.
##
## Fire-and-forget: fire() restarts the emitter and frees the node once
## the burst has run out, so a caller never has to track it. Nothing here
## builds a material or a texture; both are authored in the .tscn.

## Small safety margin added on top of the explosiveness-scaled tail
## (see fire()) before the node frees itself -- covers a little extra
## slop under the emitter's own randomness, not the tail itself.
const CLEANUP_GRACE := 0.5

## Whether firing also plays the sparkle cue. Turned off for the second
## and later bursts of one gesture, so a card with three gaining rows
## does not play the same sound three times in 160 ms.
@export var plays_sfx: bool = true


## Restart the burst after `delay` seconds and free this node when it is
## spent. Safe to call on a node that is already emitting -- restart()
## rewinds rather than stacking. A coroutine, so never call it from a
## test: the MCP runner does not await.
func fire(delay: float = 0.0) -> void:
	if Engine.is_editor_hint():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	restart()
	emitting = true
	# A nested emitter (RewardBurst's PlusBurst) rides the same gesture.
	# Fired directly rather than awaited: this node frees itself when
	# spent, and a child cannot outlive it anyway.
	for child in get_children():
		if child is GPUParticles2D:
			child.restart()
			child.emitting = true
	if plays_sfx:
		AudioDirector.play_sfx(&"sparkle")
	await get_tree().create_timer(lifetime * (2.0 - explosiveness) + CLEANUP_GRACE).timeout
	if is_inside_tree():
		queue_free()
