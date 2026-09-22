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
@onready var _skip_dialog: CheckButton = %SkipDialogToggle
@onready var _look_layer: CheckButton = %LookLayerToggle
@onready var _back: Button = %BackButton

## The screen Back returns to. MainMenu by default; the Lobby's Settings gear
## sets it to the Lobby before opening this screen, and Back resets it.
static var return_scene: String = "res://Scenes/MainMenu/main_menu.tscn"


func _ready() -> void:
	_master.value = AudioDirector.get_bus_volume(&"Master")
	_bgm.value = AudioDirector.get_bus_volume(&"BGM")
	_sfx.value = AudioDirector.get_bus_volume(&"SFX")
	_tutorial.button_pressed = GameSettings.minigame_tutorial_enabled
	_skip_dialog.button_pressed = GameSettings.skip_event_dialogue
	_look_layer.button_pressed = GameSettings.look_layer_enabled

	_master.value_changed.connect(_on_volume_changed.bind(&"Master"))
	_bgm.value_changed.connect(_on_volume_changed.bind(&"BGM"))
	_sfx.value_changed.connect(_on_volume_changed.bind(&"SFX"))
	_tutorial.toggled.connect(_on_tutorial_toggled)
	_skip_dialog.toggled.connect(_on_skip_dialog_toggled)
	_look_layer.toggled.connect(_on_look_layer_toggled)
	_back.pressed.connect(_on_back_pressed)

	if Engine.is_editor_hint():
		# Being edited in the editor, or instantiated by a test running
		# inside the editor process -- never play audio or kick off the
		# entry animation from here.
		return

	Juice.stagger_in(_collect_rows())
	# Opened from the Lobby, its music keeps playing.
	if return_scene == "res://Scenes/MainMenu/main_menu.tscn":
		AudioDirector.play_bgm(&"titlescreen")


func _collect_rows() -> Array:
	var rows: Array = []
	for child in %Layout.get_children():
		rows.append(child)
	return rows


func _on_volume_changed(value: float, bus: StringName) -> void:
	AudioDirector.set_bus_volume(bus, value)
	if Engine.is_editor_hint():
		return
	# Immediate audible feedback while dragging. The SFX slider previews
	# with a tap; the Musik slider needs its own cue because the music bed
	# is often too sustained to hear a small change against — `pop` is
	# short and routed through the SFX bus, so it stays audible while the
	# BGM bus itself is being dragged toward zero.
	if bus == &"SFX":
		AudioDirector.play_sfx(&"tap")
	elif bus == &"BGM":
		AudioDirector.play_sfx(&"pop")


func _on_tutorial_toggled(pressed: bool) -> void:
	GameSettings.minigame_tutorial_enabled = pressed
	GameSettings.save_settings()


## "Lewati Dialog Minigame" (formerly the Lobby's Shorten button): skips the
## EventDialogue line before each minigame. Saved like the tutorial switch.
func _on_skip_dialog_toggled(pressed: bool) -> void:
	GameSettings.skip_event_dialogue = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Efek Visual": the global vignette and film grain the LookLayer autoload
## draws over every screen. Off by default -- the grain is a per-pixel term
## over the whole screen every frame and the hardware floor is unknown, so it
## is opt-in. Setting the property emits look_layer_changed, which LookLayer
## is listening to, so the layer fades in without leaving this screen.
func _on_look_layer_toggled(pressed: bool) -> void:
	GameSettings.look_layer_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## Android delivers the hardware/gesture back press as a notification, not as
## ui_cancel, so an _input handler never sees it. Routed to the same function
## the on-screen back button calls, so both do exactly the same thing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _on_back_pressed() -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"cancel")
	var destination := return_scene
	return_scene = "res://Scenes/MainMenu/main_menu.tscn"
	Transition.change_scene(destination,
		Transition.Style.FADE)
