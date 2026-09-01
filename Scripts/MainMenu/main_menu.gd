@tool
extends Control

## @tool note: this script must be usable both as a live gameplay screen
## and as something the MCP test suite can instantiate correctly.
##
## Empirically, a plain (non-@tool) script attached to a node instantiated
## programmatically while the Godot *editor* process is not playing the
## game (e.g. from an MCP test_run, which runs inside the editor) gets
## replaced by Godot with a placeholder script instance -- calling even
## ordinary Control methods on it then fails with "Attempt to call a
## method on a placeholder instance. Check if the script is in tool
## mode." That broke this suite's tests until this script was marked
## @tool: the button-wiring and no-theme-override traversal checks both
## need a real _ready() to have run.
##
## The risk that comes with @tool: a human simply opening this scene in
## the editor would now run this script for real, including _ready(). To
## keep that safe, every runtime-only side effect (audio, entry
## animation, the looping blink and logo float) is gated behind
## `Engine.is_editor_hint()`, which is true both when a human has the
## scene open in the editor AND when the MCP test suite instantiates it.
## Button wiring, which must run in both of those cases, sits above the
## guard. In an actual played game Engine.is_editor_hint() is false and
## the full entry sequence runs.

@onready var _logo: TextureRect = $Logo
@onready var _logo_shadow: TextureRect = $LogoShadow
@onready var _tap_prompt: Label = $SafeArea/Content/TapPrompt
@onready var _icon_bar: HBoxContainer = $SafeArea/Content/IconBar
@onready var _setting_button: Button = $SafeArea/Content/IconBar/SettingButton
@onready var _quit_button: Button = $SafeArea/Content/IconBar/QuitButton
@onready var _version: Label = $SafeArea/Content/VersionLabel

## Float amplitude (px) and half-period (s) for the drifting KEJARTES logo.
const _LOGO_FLOAT_AMPLITUDE := 12.0
const _LOGO_FLOAT_HALF_PERIOD := 2.2

var _started := false


func _ready() -> void:
	_setting_button.pressed.connect(_on_setting_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_version.text = "v" + str(ProjectSettings.get_setting(
		"application/config/version", "0.1"))

	if Engine.is_editor_hint():
		# Being edited in the editor, or instantiated by a test running
		# inside the editor process -- never play audio or kick off the
		# gameplay entry animation from here.
		return

	AudioDirector.play_bgm(&"titlescreen")
	_animate_entry()
	_blink_forever(_tap_prompt)
	_float_forever(_logo, _logo.position.y)
	_float_forever(_logo_shadow, _logo_shadow.position.y)


## Entry animation: the logo is static art, so this is just the icon
## buttons popping in after a short beat.
func _animate_entry() -> void:
	var items: Array = []
	for child in _icon_bar.get_children():
		items.append(child)
	await get_tree().create_timer(Juice.tokens().dur_normal).timeout
	Juice.stagger_in(items)


## The "ketuk di mana saja" prompt pulses its alpha forever. Mirrors the
## splash screen's hint-label loop (Scripts/Splashscreen/splashscreen.gd).
func _blink_forever(label: Label) -> void:
	var tw := label.create_tween().set_loops()
	tw.tween_property(label, "modulate:a", 0.3, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "modulate:a", 1.0, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)


## Slow vertical drift, ping-ponging around the node's resting Y. The
## logo and its offset drop-shadow each get their own so they move in
## lockstep.
func _float_forever(node: Control, base_y: float) -> void:
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base_y - _LOGO_FLOAT_AMPLITUDE,
		_LOGO_FLOAT_HALF_PERIOD)
	tw.tween_property(node, "position:y", base_y + _LOGO_FLOAT_AMPLITUDE,
		_LOGO_FLOAT_HALF_PERIOD)


## The wipe into the cutscene is deliberately slower than every other
## transition in the game (Transition.change_scene's other ~20 call
## sites all use the default duration) -- this is the one moment meant
## to feel unhurried, giving the player a beat before the story starts.
const _INTRO_WIPE_SEC := 1.1

## Tapping anywhere that a Button did not already consume starts the
## game. _unhandled_input (not _input) is deliberate: the gear and exit
## Buttons call accept_event() on their own presses, so those taps never
## reach here and cannot double-fire alongside their handlers.
func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventScreenTouch and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()


func _start_game() -> void:
	_started = true
	AudioDirector.play_sfx(&"confirm")
	Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn",
		Transition.Style.WIPE, _INTRO_WIPE_SEC)


func _on_setting_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/UI/Settings.tscn", Transition.Style.FADE)


func _on_quit_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	get_tree().quit()
