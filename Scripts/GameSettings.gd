extends Node

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
