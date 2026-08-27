@tool
extends Node

## @tool note: GameSettings is a script-only autoload
## (`GameSettings="*res://Scripts/GameSettings.gd"` in project.godot, not a
## scene), so it is instantiated by the editor process itself at startup —
## including when an MCP test suite runs inside that same editor process.
## Without @tool, that instance is a placeholder (same failure mode
## documented in Scripts/MainMenu/main_menu.gd and Scripts/Audio/
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
	if not Engine.is_editor_hint():
		config.set_value("progres", "is_game_beaten", GameState.is_game_beaten)
		config.set_value("progres", "debug_level_select", GameState.debug_level_select_enabled)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		minigame_tutorial_enabled = config.get_value("pengaturan", "minigame_tutorial", true)
		if not Engine.is_editor_hint():
			GameState.is_game_beaten = config.get_value("progres", "is_game_beaten", false)
			GameState.debug_level_select_enabled = config.get_value("progres", "debug_level_select", true)
