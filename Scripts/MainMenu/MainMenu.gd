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

@onready var _logo: TextureRect = %Logo
@onready var _logo_shadow: TextureRect = %LogoShadow
@onready var _tap_prompt: Label = $SafeArea/Content/TapPrompt
@onready var _icon_bar: HBoxContainer = $SafeArea/Content/IconBar
@onready var _setting_button: Button = $SafeArea/Content/IconBar/SettingButton
@onready var _quit_button: Button = $SafeArea/Content/IconBar/QuitButton
@onready var _version: Label = $SafeArea/Content/VersionLabel
@onready var _continue_popup: ContinuePopup = $ContinuePopup

## Float amplitude (px) and half-period (s) for the drifting KEJARTES logo.
const _LOGO_FLOAT_AMPLITUDE := 12.0
const _LOGO_FLOAT_HALF_PERIOD := 2.2

var _started := false


func _ready() -> void:
	_setting_button.pressed.connect(_on_setting_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_continue_popup.continue_chosen.connect(_continue_game)
	_continue_popup.new_game_chosen.connect(_begin_new_game)
	_continue_popup.dismissed.connect(func() -> void: _started = false)

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
## splash screen's hint-label loop (Scripts/Splashscreen/Splashscreen.gd).
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


## The wipe out of the title (into the Level Select or the intro, or back
## into a saved run) is deliberately slower than every other transition in
## the game (Transition.change_scene's other ~20 call sites all use the
## default duration) -- this is the one moment meant to feel unhurried,
## giving the player a beat before the story starts.
const _INTRO_WIPE_SEC := 1.1

## Tapping anywhere that a Button did not already consume starts the
## game. _unhandled_input (not _input) is deliberate: the gear and exit
## Buttons call accept_event() on their own presses, so those taps never
## reach here and cannot double-fire alongside their handlers.
func _unhandled_input(event: InputEvent) -> void:
	# A tap during the intro wipe would latch _started while Transition
	# still refuses the change, leaving the title stuck (bug sweep 2026-09-30).
	# The popup's own scrim stops its taps, but a tap that reached here while
	# it is open must still never re-fire the title.
	if _started or Transition.is_busy() or _continue_popup.visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()


## A tap on the title: with a save on disk, ask whether to carry on;
## otherwise start a new game as before.
func _start_game() -> void:
	_started = true
	AudioDirector.play_sfx(&"confirm")
	if SaveGame.has_save():
		_continue_popup.open(SaveGame.summary())
	else:
		_begin_new_game()


## Permainan baru (or a first tap with no save): wipe the run -- not the
## achievements or settings -- delete the save, carry any pre-2026-10-01
## inventory over, then the Level Select (while
## GameState.is_level_select_enabled()) or the intro, which starts Kelas 7.
## The tutorial bypass outlives the wipe, paired as DebugManager's toggle
## pairs it: a debug build sets it at launch for every playtest
## (_apply_playtest_defaults), and a new game must not bring the tutorials back.
func _begin_new_game() -> void:
	_continue_popup.close()
	var bypassed: bool = GameState.tutorials_bypassed
	GameState.reset_run()
	if bypassed:
		GameState.tutorials_bypassed = true
		GameState.lobby_tutorial_completed = true
	SaveGame.delete_save()
	# Only after reset_run(), which empties the inventory the items land in.
	SaveGame.merge_legacy_inventory()
	var target := "res://Scenes/LevelSelect/LevelSelect.tscn" \
		if GameState.is_level_select_enabled() \
		else "res://Scenes/CutScene/CutScene.tscn"
	Transition.change_scene(target, Transition.Style.WIPE, _INTRO_WIPE_SEC)


## Ya, lanjutkan: load the save and land where it left off. A save that
## vanished or went bad since the popup opened falls back to a new game.
func _continue_game() -> void:
	_continue_popup.close()
	if not SaveGame.load_save():
		_begin_new_game()
		return
	Transition.change_scene(
		SaveGame.resume_scene(GameState.pending_week_resume, GameState.returned_from_student_card),
		Transition.Style.WIPE, _INTRO_WIPE_SEC)


func _on_setting_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/UI/Settings.tscn", Transition.Style.FADE)


func _on_quit_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	get_tree().quit()
