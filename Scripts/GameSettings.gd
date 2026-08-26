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
## Unlike AudioDirector's scene-root guard, there is no editor-hint gate
## needed here: this script has no scene of its own to be "opened" in the
## editor, and its only side effect (_ready() calling load_settings(),
## reading user://settings.cfg) is a harmless read that a human editing
## any scene, or a test instantiating one, should see happen the same way
## real gameplay does.

var minigame_tutorial_enabled: bool = true


const SAVE_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("pengaturan", "minigame_tutorial", minigame_tutorial_enabled)
	config.set_value("progres", "is_game_beaten", GameState.is_game_beaten)
	config.set_value("progres", "debug_level_select", GameState.debug_level_select_enabled)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		minigame_tutorial_enabled = config.get_value("pengaturan", "minigame_tutorial", true)
		GameState.is_game_beaten = config.get_value("progres", "is_game_beaten", false)
		GameState.debug_level_select_enabled = config.get_value("progres", "debug_level_select", true)
