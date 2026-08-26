@tool
extends Control

## @tool note: same pattern established by MainMenu (Scripts/MainMenu/main_menu.gd)
## and required here for the same empirical reason -- a plain (non-@tool)
## script attached to a node instantiated while the Godot *editor* process
## is not playing the game (e.g. an MCP test_run, which runs inside the
## editor) gets replaced by a placeholder script instance, so the signal
## wiring this screen depends on (sliders driving AudioDirector, the
## toggle writing GameSettings) would never actually run under test.
##
## Unlike MainMenu, nearly everything _ready() does here -- reading the
## current bus volumes, reading the current tutorial flag, wiring the
## sliders/toggle/back button -- is exactly what a human editing this
## scene in the editor, or the test suite instantiating it, should also
## see happen: there is no gameplay-only side effect to gate behind
## Engine.is_editor_hint() other than the entry animation (Juice) and the
## SFX blip on drag, which are harmless no-ops/silent in the editor but
## are still gated below for consistency with the rest of the project.

@onready var _master: HSlider = %MasterSlider
@onready var _bgm: HSlider = %BgmSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _tutorial: CheckButton = %TutorialToggle
@onready var _back: Button = %BackButton


func _ready() -> void:
	_master.value = AudioDirector.get_bus_volume(&"Master")
	_bgm.value = AudioDirector.get_bus_volume(&"BGM")
	_sfx.value = AudioDirector.get_bus_volume(&"SFX")
	_tutorial.button_pressed = GameSettings.minigame_tutorial_enabled

	_master.value_changed.connect(_on_volume_changed.bind(&"Master"))
	_bgm.value_changed.connect(_on_volume_changed.bind(&"BGM"))
	_sfx.value_changed.connect(_on_volume_changed.bind(&"SFX"))
	_tutorial.toggled.connect(_on_tutorial_toggled)
	_back.pressed.connect(_on_back_pressed)

	if Engine.is_editor_hint():
		# Being edited in the editor, or instantiated by a test running
		# inside the editor process -- never play audio or kick off the
		# entry animation from here.
		return

	Juice.stagger_in(_collect_rows())


func _collect_rows() -> Array:
	var rows: Array = []
	for child in %Layout.get_children():
		rows.append(child)
	return rows


func _on_volume_changed(value: float, bus: StringName) -> void:
	AudioDirector.set_bus_volume(bus, value)
	# Immediate audible feedback while dragging the SFX slider.
	if bus == &"SFX" and not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"tap")


func _on_tutorial_toggled(pressed: bool) -> void:
	GameSettings.minigame_tutorial_enabled = pressed
	GameSettings.save_settings()


func _on_back_pressed() -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"cancel")
	Transition.change_scene("res://Scenes/MainMenu/main_menu.tscn",
		Transition.Style.FADE)
