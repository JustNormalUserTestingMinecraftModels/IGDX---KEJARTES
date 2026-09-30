extends WorldEnvironment

## A WorldEnvironment whose glow answers to the player's Grafis HD switch
## (GameSettings.hd_graphics_enabled): off, the glow is disabled; on, it is
## as authored.
##
## For a screen that owns a plain WorldEnvironment rather than an AmbientGlow,
## which today is the Lobby (Scenes/Lobby/lobby_environment.tres). AmbientGlow
## already follows the switch, together with Efek Suasana; the Lobby's glow
## never followed Efek Suasana and still does not.
##
## Not @tool: the editor must keep showing the glow as authored, and the
## Environment is a shared resource that a tool script would rewrite on disk.


func _ready() -> void:
	GameSettings.hd_graphics_changed.connect(_apply.unbind(1))
	_apply()


func _apply() -> void:
	if environment != null:
		environment.glow_enabled = GameSettings.hd_graphics_enabled
