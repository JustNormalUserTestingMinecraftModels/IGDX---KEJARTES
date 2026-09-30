@tool
class_name AmbientKit
extends RefCounted

## The ambient kit's shared plumbing (spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md). Every kit piece --
## MoodTint, LightPool, AmbientParticles, AmbientGlow, DeskAmbience -- asks
## GameSettings the same two questions, must hear the answers change without
## polling, and must fill its parent however an editor save left its root.
## This is the one place that does those three things, so the pieces cannot
## drift apart on them. Static only; nothing to instance.


## True while the player has Efek Suasana on.
static func is_enabled() -> bool:
	return GameSettings.ambient_effects_enabled


## True while the kit must hold still: Kurangi Gerakan is on.
static func is_still() -> bool:
	return GameSettings.reduce_motion


## True while a bloom may run: Efek Suasana on and Grafis HD on. ScreenGlow
## and AmbientGlow ask this instead of is_enabled(), so Grafis HD off takes
## every per-screen bloom out without touching the rest of the kit.
static func wants_bloom() -> bool:
	return GameSettings.ambient_effects_enabled and GameSettings.hd_graphics_enabled


## Calls `apply` now, and again whenever any of the three switches flips. `apply` must be a
## method of the calling node, never a lambda: a bound method's connections
## are dropped when its node is freed (pinned by test_ambient_kit), a
## lambda's are not.
static func follow_settings(apply: Callable) -> void:
	GameSettings.ambient_effects_changed.connect(apply.unbind(1))
	GameSettings.reduce_motion_changed.connect(apply.unbind(1))
	GameSettings.hd_graphics_changed.connect(apply.unbind(1))
	apply.call()


## Re-anchors `node` to fill its parent. An instanced scene's root under a
## plain Control is saved with `layout_mode = 0` and reloads zero-sized at the
## parent's top-left (authoring guide, "Two ways the editor silently drops a
## Control's rect"), so every kit root restores Full Rect itself in _ready.
static func fill_parent(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
