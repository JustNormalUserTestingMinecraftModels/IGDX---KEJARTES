@tool
extends Control

## @tool note: same pattern established by MainMenu (Scripts/MainMenu/MainMenu.gd)
## and required here for the same empirical reason -- a plain (non-@tool)
## script attached to a node instantiated while the Godot *editor* process
## is not playing the game (e.g. an MCP test_run, which runs inside the
## editor) gets replaced by a placeholder script instance, so the signal
## wiring this screen depends on (sliders driving AudioDirector, the
## toggle writing GameSettings) would never actually run under test.
##
## Unlike MainMenu, nearly everything _ready() does here -- reading the
## current bus volumes, reading the current tutorial flag, wiring the
## sliders/toggle/frame -- is exactly what a human editing this
## scene in the editor, or the test suite instantiating it, should also
## see happen: there is no gameplay-only side effect to gate behind
## Engine.is_editor_hint() other than the entry animation (Juice) and the
## SFX blip on drag, which are harmless no-ops/silent in the editor but
## are still gated below for consistency with the rest of the project.

@onready var _master: HSlider = %MasterSlider
@onready var _bgm: HSlider = %BgmSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _tutorial: CheckButton = %TutorialRow.toggle
@onready var _skip_dialog: CheckButton = %SkipDialogRow.toggle
@onready var _hd_graphics: CheckButton = %HdGraphicsRow.toggle
@onready var _battery_saver: CheckButton = %BatterySaverRow.toggle
@onready var _look_layer: CheckButton = %LookLayerRow.toggle
@onready var _ambient: CheckButton = %AmbientRow.toggle
@onready var _haptics: CheckButton = %HapticsRow.toggle
@onready var _reduce_motion: CheckButton = %ReduceMotionRow.toggle
@onready var _frame: NotebookFrame = %Frame
@onready var _reset_button: Button = %ResetProgressButton
@onready var _reset_popup: ResetProgressPopup = %ResetProgressPopup

## The SUARA tab: the three volume sliders.
const TAB_SUARA := 0
## The MAIN tab: the gameplay and display switches.
const TAB_MAIN := 1

## Where Back goes unless the opener says otherwise, and the one opening whose
## music this screen starts itself.
const MAIN_MENU_SCENE := "res://Scenes/MainMenu/MainMenu.tscn"

## Where Reset Progres lands: the splash, a fuller fresh start than a cold
## launch (which boots straight to MainMenu). Its tap routes on to MainMenu.
const SPLASH_SCENE := "res://Scenes/Splashscreen/Splashscreen.tscn"
## The reset's fade, seconds: longer than an ordinary scene change, so the
## wipe reads as a deliberate "resetting" beat (collaborator's spec,
## 2026-10-01-reset-progress-setting-design.md).
const RESET_FADE_SECONDS := 1.3

## The screen Back returns to. MainMenu by default; the Lobby's Settings gear
## sets it to the Lobby before opening this screen. _ready() copies it into
## _destination and resets it at once, so a Back that Transition drops cannot
## lose it and a later visit never inherits it.
static var return_scene: String = MAIN_MENU_SCENE

## Where this visit's Back goes: return_scene as it stood when the screen
## opened. Never cleared, so a Back that Transition drops (tapped while the
## arrival wipe is still retracting) is retried to the same place.
var _destination: String = MAIN_MENU_SCENE


func _ready() -> void:
	_destination = return_scene
	return_scene = MAIN_MENU_SCENE
	_master.value = AudioDirector.get_bus_volume(&"Master")
	_bgm.value = AudioDirector.get_bus_volume(&"BGM")
	_sfx.value = AudioDirector.get_bus_volume(&"SFX")
	_tutorial.button_pressed = GameSettings.minigame_tutorial_enabled
	_skip_dialog.button_pressed = GameSettings.skip_event_dialogue
	_hd_graphics.button_pressed = GameSettings.hd_graphics_enabled
	_battery_saver.button_pressed = GameSettings.battery_saver_enabled
	_look_layer.button_pressed = GameSettings.look_layer_enabled
	_ambient.button_pressed = GameSettings.ambient_effects_enabled
	_haptics.button_pressed = GameSettings.haptics_enabled
	_reduce_motion.button_pressed = GameSettings.reduce_motion

	_master.value_changed.connect(_on_volume_changed.bind(&"Master"))
	_bgm.value_changed.connect(_on_volume_changed.bind(&"BGM"))
	_sfx.value_changed.connect(_on_volume_changed.bind(&"SFX"))
	_tutorial.toggled.connect(_on_tutorial_toggled)
	_skip_dialog.toggled.connect(_on_skip_dialog_toggled)
	_hd_graphics.toggled.connect(_on_hd_graphics_toggled)
	_battery_saver.toggled.connect(_on_battery_saver_toggled)
	_look_layer.toggled.connect(_on_look_layer_toggled)
	_ambient.toggled.connect(_on_ambient_toggled)
	_haptics.toggled.connect(_on_haptics_toggled)
	_reduce_motion.toggled.connect(_on_reduce_motion_toggled)
	_frame.close_pressed.connect(_on_back_pressed)
	_frame.tab_selected.connect(show_tab)
	_reset_button.pressed.connect(_reset_popup.open)
	_reset_popup.reset_confirmed.connect(_on_reset_confirmed)
	# Skip while the editor is baking this into the edited scene: show_tab
	# would hide GameplayCard/DisplayCard and that `visible = false` would be
	# saved into Settings.tscn. Tests stand this up as a plain instance, not
	# the edited scene, so they still see it run.
	if not (Engine.is_editor_hint() and is_part_of_edited_scene()):
		show_tab(_frame.active_tab)

	if Engine.is_editor_hint():
		# Being edited in the editor, or instantiated by a test running
		# inside the editor process -- never play audio or kick off the
		# entry animation from here.
		return

	Juice.stagger_in(_collect_entry_nodes())
	# Opened from the Lobby, its music keeps playing.
	if _destination == MAIN_MENU_SCENE:
		AudioDirector.play_bgm(&"titlescreen")


## Show tab `index`'s sections: SUARA holds AudioCard, MAIN the gameplay,
## display and data cards. Also keeps _frame.active_tab in step, which only refreshes
## the tab strip's look (its setter never emits tab_selected, so this never
## loops back through the connection above). Public so the tests can switch
## tabs without a press.
func show_tab(index: int) -> void:
	%AudioCard.visible = index == TAB_SUARA
	%GameplayCard.visible = index == TAB_MAIN
	%DisplayCard.visible = index == TAB_MAIN
	%DataCard.visible = index == TAB_MAIN
	_frame.active_tab = index


## What pops in on entry: the frame, whole.
func _collect_entry_nodes() -> Array:
	return [_frame]


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
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Lewati Dialog Minigame" (formerly the Lobby's Shorten button): skips the
## EventDialogue line before each minigame. Saved like the tutorial switch.
func _on_skip_dialog_toggled(pressed: bool) -> void:
	GameSettings.skip_event_dialogue = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Grafis HD": antialiasing (MSAA) and every bloom. On by default; off is
## the switch for a phone that struggles. Setting the property emits
## hd_graphics_changed, which LookLayer and the glow pieces follow at once.
## Saved.
func _on_hd_graphics_toggled(pressed: bool) -> void:
	GameSettings.hd_graphics_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Hemat Baterai": caps the frame rate at 30 so the phone stays cooler. Off
## by default. Setting the property applies the cap at once. Saved.
func _on_battery_saver_toggled(pressed: bool) -> void:
	GameSettings.battery_saver_enabled = pressed
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


## "Efek Suasana": the ambient kit -- colour moods, soft light, drifting
## particles and glints. On by default. Setting the property emits
## ambient_effects_changed, which every kit piece follows at once. Saved.
func _on_ambient_toggled(pressed: bool) -> void:
	GameSettings.ambient_effects_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Getaran (Haptic)": drives phone vibration on reward moments. Saved.
func _on_haptics_toggled(pressed: bool) -> void:
	GameSettings.haptics_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Kurangi Gerakan": drops screenshake and screen confetti (sound and haptic
## still fire) for players who dislike motion. Saved.
func _on_reduce_motion_toggled(pressed: bool) -> void:
	GameSettings.reduce_motion = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()


## "Reset Progres", after the popup's Ya, Reset: wipes the run, the save and
## achievement progress (GameState.forget_session(); settings are kept), then
## fades to the splash. A press while a scene change is running would see its
## change_scene dropped by Transition, leaving a wiped run on this screen, so
## it is ignored before anything is wiped.
func _on_reset_confirmed() -> void:
	if Transition.is_busy():
		return
	GameState.forget_session()
	Transition.change_scene(SPLASH_SCENE, Transition.Style.FADE, RESET_FADE_SECONDS)


## Android delivers the hardware/gesture back press as a notification, not as
## ui_cancel, so an _input handler never sees it. With the reset popup open it
## only closes the popup; otherwise it is routed to the same function the
## frame's close calls, so both do exactly the same thing.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _reset_popup != null and _reset_popup.visible:
		_reset_popup.close()
	else:
		_on_back_pressed()


## Leaves for _destination. A press while a scene change is still running
## (this screen's own arrival wipe) would be dropped by Transition, so it is
## ignored here without the cancel cue; _destination is kept for the next one.
func _on_back_pressed() -> void:
	if Transition.is_busy():
		return
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"cancel")
	Transition.change_scene(_destination, Transition.Style.FADE)
