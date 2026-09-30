@tool
extends Button

## The Debug overlay's switch for the saved "Debug Level Select" flag,
## GameState.debug_level_select_enabled (persisted by GameSettings). It is the
## only control that flips it: the cutscene's own top-bar toggle went with the
## 2026-09-30 VN pass, and the overlay's Scenes tab only teleports to the
## Level Select. ON (the default) makes a new game pick its grade on the Level
## Select; OFF makes the intro force Kelas 7 (GameState.is_level_select_enabled()).
##
## DebugManager adds one instance to the General tab, beside the tutorial
## switches: `v_tut_btns.add_child(preload(...).new())`. The button keeps its
## own label in step -- on every press, and whenever it becomes visible again --
## so DebugManager's refresh needs no line for it.
##
## @tool so the editor test suite can instantiate and press it; nothing runs
## on its own in the editor, it only reads and writes the GameState flag.

## Minimum button height, matching the overlay's other tutorial switches.
const _MIN_HEIGHT := 85.0
## Label font size, matching the overlay's other tutorial switches.
const _FONT_SIZE := 21
## Label stem; the state follows it.
const _LABEL := "Debug Level Select: "
## State words shown after the label stem.
const _ON_TEXT := "ON (Pilih Kelas)"
const _OFF_TEXT := "OFF (Normal)"


func _init() -> void:
	custom_minimum_size = Vector2(0.0, _MIN_HEIGHT)
	add_theme_font_size_override("font_size", _FONT_SIZE)


func _ready() -> void:
	visibility_changed.connect(refresh_text)
	refresh_text()


## A press flips the flag, like the tutorial switches beside it.
func _pressed() -> void:
	toggle()


## Flips GameState.debug_level_select_enabled, saves it the way the cutscene's
## old button did (GameSettings.save_settings), and refreshes the label.
func toggle() -> void:
	GameState.debug_level_select_enabled = not GameState.debug_level_select_enabled
	GameSettings.save_settings()
	refresh_text()


## Shows the flag's current state on the button.
func refresh_text() -> void:
	text = _LABEL + (_ON_TEXT if GameState.debug_level_select_enabled else _OFF_TEXT)
