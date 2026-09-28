@tool
extends Object
class_name Haptics

## Reward haptics (2026-09-23). A thin, platform-branched vibration wrapper —
## nothing in the project vibrated before this. On a phone, buzz() drives the
## motor; on desktop (where vibrate_handheld is a no-op) it flashes the
## HapticIndicator pip so the effect is reviewable on PC. All static: no node,
## no autoload. Every call is a silent no-op when GameSettings.haptics_enabled
## is false.

## Tier labels shown on the desktop pip. Keyed by duration for a readable name.
const _TIER_NAME := { 8: "Tick", 20: "Pop", 50: "Celebration" }

## Desktop clean-record switch. False hides the pip (for trailer capture)
## while sound, particles and shake keep running. Ignored on mobile.
static var show_indicator: bool = true

## The live desktop pip, created lazily on first desktop buzz.
static var _indicator: HapticIndicator = null

static func is_mobile() -> bool:
	return OS.has_feature("mobile")

## Buzz for `duration_ms`. Motor on mobile, pip on desktop, no-op when off.
static func buzz(duration_ms: int) -> void:
	if not GameSettings.haptics_enabled:
		return
	if is_mobile():
		Input.vibrate_handheld(duration_ms)
		return
	# Desktop: no motor exists. Show the review pip instead.
	if not show_indicator:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or Engine.is_editor_hint():
		return
	if _indicator == null or not is_instance_valid(_indicator):
		_indicator = preload("res://Scenes/Feedback/HapticIndicator.tscn").instantiate()
		tree.root.add_child(_indicator)
	var name: String = _TIER_NAME.get(duration_ms, str(duration_ms) + "ms")
	_indicator.flash("HAPTIC · %s · %dms" % [name, duration_ms])
