@tool
extends Node

## @tool note: GameSettings is a script-only autoload
## (`GameSettings="*res://Scripts/GameSettings.gd"` in project.godot, not a
## scene), so it is instantiated by the editor process itself at startup —
## including when an MCP test suite runs inside that same editor process.
## Without @tool, that instance is a placeholder (same failure mode
## documented in Scripts/MainMenu/MainMenu.gd and Scripts/Audio/
## AudioDirector.gd for scene-attached scripts): every property access,
## including plain `minigame_tutorial_enabled` reads/writes, throws
## "Invalid access to property or key ... on a base object of type
## 'Node (GameSettings.gd)'". Confirmed empirically while wiring
## Settings.gd's TutorialToggle to this autoload -- test_settings.gd's
## setup() aborted every single test with exactly that error until this
## was added.
##
## This script's own state (minigame_tutorial_enabled) is safe to read and
## write in editor/test context -- no editor-hint gate needed for that part.
## But load_settings()/save_settings() also touch GameState.is_game_beaten
## and GameState.debug_level_select_enabled, and GameState.gd is NOT @tool,
## so GameState remains a placeholder instance in editor/test context.
## Accessing it there throws "Invalid assignment of property or key
## 'is_game_beaten' ... on a base object of type 'Node (GameState.gd)'" --
## this actually happened at editor boot once GameSettings gained @tool,
## since _ready() -> load_settings() now runs for real in that context.
## The GameState.* lines are gated below; everything else in this file
## runs the same way in both contexts.

var minigame_tutorial_enabled: bool = true
## Shorten (Lobby panel, 2026-09-14): true skips the EventDialogue line before
## each minigame. Saved beside the tutorial switch.
var skip_event_dialogue: bool = false
## Reward haptics (2026-09-23): true lets Haptics.buzz() drive the phone's
## vibration motor. Off = a silent no-op on every platform. Saved beside the
## other switches.
var haptics_enabled: bool = true
## Reward motion (2026-09-23): true tells RewardFeedback to skip screenshake
## and screen confetti (sound and haptic still fire), for players who dislike
## motion. Saved beside the other switches. Since the ambient kit (2026-09-26)
## it also freezes every kit piece, which follows the flip through
## reduce_motion_changed instead of polling.
var reduce_motion: bool = false:
	set(value):
		if reduce_motion == value:
			return
		reduce_motion = value
		reduce_motion_changed.emit(value)

## Emitted when reduce_motion flips.
signal reduce_motion_changed(still: bool)

## Ambient kit (docs/superpowers/specs/2026-09-26-ambient-kit-design.md):
## whether the colour moods, light pools, drifting particles and glints show
## at all. DEFAULT ON, unlike look_layer_enabled: each piece is cheap (at most
## 40 CPU particles, a few quads), and "Efek Suasana" in Settings turns it off
## for a slow phone.
var ambient_effects_enabled: bool = true:
	set(value):
		if ambient_effects_enabled == value:
			return
		ambient_effects_enabled = value
		ambient_effects_changed.emit(value)

## Emitted when ambient_effects_enabled flips.
signal ambient_effects_changed(enabled: bool)

## Grafis HD (2026-09-30 mobile performance pass): the two things a slow phone
## pays most for on every screen. On, the game antialiases 2D (MSAA) and
## blooms; off, it does neither: LookLayer drops the viewport's MSAA and its
## own bloom, and every ScreenGlow and AmbientGlow switches off (AmbientKit.
## wants_bloom). DEFAULT ON, so nobody loses either without asking; the
## vignette and grain stay with look_layer_enabled, the rest of the ambient
## kit with ambient_effects_enabled.
var hd_graphics_enabled: bool = true:
	set(value):
		if hd_graphics_enabled == value:
			return
		hd_graphics_enabled = value
		hd_graphics_changed.emit(value)

## Emitted when hd_graphics_enabled flips.
signal hd_graphics_changed(enabled: bool)

## Premium-look pass (2026-09-22): whether the global look layer -- the
## vignette and film grain LookLayer draws over every screen -- is on.
##
## DEFAULT OFF and opt-in. The hardware floor for this game is not known, and
## the grain is a per-pixel term evaluated over the whole screen every frame,
## so it is the one thing in that pass expensive enough to want a switch.
## LookLayer listens to look_layer_changed so a flip takes effect at once
## rather than on the next scene load.
var look_layer_enabled: bool = false:
	set(value):
		if look_layer_enabled == value:
			return
		look_layer_enabled = value
		look_layer_changed.emit(value)

## Emitted when look_layer_enabled flips, so the autoload can react without
## polling the setting every frame.
signal look_layer_changed(enabled: bool)


const SAVE_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	# Load whatever is already on disk first so that skipping the
	# "progres" section below (editor/test context) doesn't truncate
	# away previously-saved progres values -- a fresh ConfigFile with
	# only "pengaturan" set would otherwise overwrite the whole file.
	config.load(SAVE_PATH)
	config.set_value("pengaturan", "minigame_tutorial", minigame_tutorial_enabled)
	config.set_value("pengaturan", "skip_dialog", skip_event_dialogue)
	config.set_value("pengaturan", "look_layer", look_layer_enabled)
	config.set_value("pengaturan", "hd_graphics", hd_graphics_enabled)
	config.set_value("pengaturan", "ambient_effects", ambient_effects_enabled)
	config.set_value("pengaturan", "haptics", haptics_enabled)
	config.set_value("pengaturan", "reduce_motion", reduce_motion)
	if not Engine.is_editor_hint():
		config.set_value("progres", "is_game_beaten", GameState.is_game_beaten)
		config.set_value("progres", "debug_level_select", GameState.debug_level_select_enabled)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		minigame_tutorial_enabled = config.get_value("pengaturan", "minigame_tutorial", true)
		skip_event_dialogue = config.get_value("pengaturan", "skip_dialog", false)
		look_layer_enabled = config.get_value("pengaturan", "look_layer", false)
		hd_graphics_enabled = config.get_value("pengaturan", "hd_graphics", true)
		ambient_effects_enabled = config.get_value("pengaturan", "ambient_effects", true)
		haptics_enabled = config.get_value("pengaturan", "haptics", true)
		reduce_motion = config.get_value("pengaturan", "reduce_motion", false)
		if not Engine.is_editor_hint():
			GameState.is_game_beaten = config.get_value("progres", "is_game_beaten", false)
			GameState.debug_level_select_enabled = config.get_value("progres", "debug_level_select", true)
