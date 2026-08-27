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
## @tool: test_all_three_buttons_exist_and_are_wired failed outright
## (no real _ready() ever ran to connect the buttons) and
## test_scene_has_no_theme_overrides aborted the whole run mid-traversal
## the moment it reached the placeholder-backed root node.
##
## The risk that comes with @tool (per the project's established pattern
## from Tasks 5/6): a human simply opening this scene in the editor would
## now run this script for real, including _ready(). To keep that safe,
## every runtime-only side effect (audio, entry animation) is gated
## behind `Engine.is_editor_hint()`, which is true both when a human has
## the scene open in the editor AND when the MCP test suite instantiates
## it (both execute inside the editor process) -- so button wiring, which
## must run in both of those cases, sits above the guard, while
## BGM/animation, which must never fire outside a real play session, sits
## below it. In an actual played game (`project_run` or a device build),
## Engine.is_editor_hint() is false and the full entry sequence runs.

@onready var _title: Label = $SafeArea/Layout/TitleLabel
@onready var _subtitle: Label = $SafeArea/Layout/SubtitleLabel
@onready var _buttons: VBoxContainer = $SafeArea/Layout/ButtonColumn
@onready var _play_button: Button = $SafeArea/Layout/ButtonColumn/PlayButton
@onready var _setting_button: Button = $SafeArea/Layout/ButtonColumn/SettingButton
@onready var _quit_button: Button = $SafeArea/Layout/ButtonColumn/QuitButton
@onready var _version: Label = $SafeArea/Layout/VersionLabel


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
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


func _animate_entry() -> void:
	Juice.pop_in(_title)
	Juice.fade_in(_subtitle, Juice.tokens().dur_fast)
	# Buttons cascade in after the title lands.
	var delay := Juice.tokens().dur_normal
	var items: Array = []
	for child in _buttons.get_children():
		items.append(child)
	await get_tree().create_timer(delay).timeout
	Juice.stagger_in(items)


func _on_play_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn")


func _on_setting_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/UI/Settings.tscn", Transition.Style.FADE)


func _on_quit_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	get_tree().quit()
