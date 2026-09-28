@tool
class_name MinigameHeader
extends Control

## Shared minigame top HUD strip (spec 2026-09-28 minigame-polish-part-1, 4.2):
## a pause icon-button (left), the shared score readout (centre) and a timer
## icon-button (right). The centre is an instance of MinigameScoreHUD.tscn --
## "extend rather than fork" -- so the score's pop, burst and combo chip stay
## in one component. Chrome comes from the MinigameHudIconButton variation;
## icons arrive through these root @exports because an instance's children
## drop their overrides on save.
##
## Affects: only its own children. Presentational: the owning minigame
## connects `pause_pressed` and calls setup() / set_score() down; this never
## reaches up. The timer button is display-only for now: it has no signal,
## and only show_timer and timer_icon drive it. @tool so the strip previews
## in the editor.

## Emitted when the player presses the pause icon-button.
signal pause_pressed

## Whether the right-hand timer icon-button is shown.
@export var show_timer: bool = true:
	set(value):
		show_timer = value
		_apply_exports()
## Pause button icon: a transparent SVG, never an emoji.
@export var pause_icon: Texture2D:
	set(value):
		pause_icon = value
		_apply_exports()
## Timer button icon: a transparent SVG, never an emoji.
@export var timer_icon: Texture2D:
	set(value):
		timer_icon = value
		_apply_exports()

@onready var _pause_button: Button = %PauseButton
@onready var _timer_button: Button = %TimerButton
@onready var _score_hud: MinigameScoreHUD = %ScoreHud


func _ready() -> void:
	if not _has_required_nodes():
		return
	_connect_pause_button()
	if Engine.is_editor_hint():
		return
	_apply_exports()


## Install the score readout's icon and target (MinigameScoreHUD.setup).
func setup(score_icon: Texture2D, target: int) -> void:
	_score_hud.setup(score_icon, target)


## Show the current score; a rise pops the readout (MinigameScoreHUD.set_score).
func set_score(value: int) -> void:
	_score_hud.set_score(value)


## Show or hide the combo chip (MinigameScoreHUD.set_combo).
func set_combo(value: int) -> void:
	_score_hud.set_combo(value)


## Write the score verbatim, for a two-sided score like Badminton's "7 - 6".
func set_label_text(text: String) -> void:
	_score_hud.set_label_text(text)


## True when the scene carries every node this script drives. A missing one
## means MinigameHeader.tscn is broken, so it is an error, not a silent skip.
func _has_required_nodes() -> bool:
	if _pause_button != null and _timer_button != null and _score_hud != null:
		return true
	push_error("MinigameHeader: PauseButton, TimerButton or ScoreHud is missing its unique name in MinigameHeader.tscn")
	return false


## Pure signal wiring, so it stays ungated and tests can press the button.
func _connect_pause_button() -> void:
	if _pause_button.pressed.is_connected(_on_pause_button_pressed):
		return
	_pause_button.pressed.connect(_on_pause_button_pressed)


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()


## Push the root @exports down onto the buttons. The setters call this while
## a scene is still loading, before the children exist -- hence the guard.
func _apply_exports() -> void:
	if not is_node_ready() or not _has_required_nodes():
		return
	_timer_button.visible = show_timer
	_timer_button.icon = timer_icon
	_pause_button.icon = pause_icon
