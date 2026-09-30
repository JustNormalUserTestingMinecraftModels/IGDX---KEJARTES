@tool
class_name MinigameHeader
extends Control

## Shared minigame top strip, one row (spec 2026-09-30 minigame hierarchy,
## 5.1): a pause icon-button (left), the plaque (centre) and a timer ring that
## shows the whole seconds left (right). The plaque is an instance of
## MinigameScoreHUD.tscn -- "extend rather than fork" -- carrying the score
## line and, under it, the progress bar with its caption. Chrome comes from the
## MinigameHudIconButton, MinigameHudPill and MinigameTimerLabel variations;
## the pause picture arrives through a root @export because an instance's
## children drop their overrides on save.
##
## Affects: only its own children. Presentational: the owning minigame
## connects `pause_pressed` and calls setup() / set_score() / set_progress() /
## set_time() down; this never reaches up. The timer is display-only: it has
## no signal and ignores taps. A hidden timer keeps its 96px slot so the
## plaque stays centred. @tool so the strip previews in the editor.

## Emitted when the player presses the pause icon-button.
signal pause_pressed

## Whether the right-hand timer shows.
@export var show_timer: bool = true:
	set(value):
		show_timer = value
		_apply_exports()
## Pause button icon: a transparent SVG, never an emoji.
@export var pause_icon: Texture2D:
	set(value):
		pause_icon = value
		_apply_exports()
## Whether the plaque's score line shows (BuatBatik keeps no score).
@export var show_score: bool = true:
	set(value):
		show_score = value
		_apply_exports()
## Whether the plaque's progress line shows.
@export var show_progress: bool = true:
	set(value):
		show_progress = value
		_apply_exports()
## The last seconds in which the timer ring turns state_danger (ours; spec 6).
@export_range(0.0, 30.0, 0.5) var danger_seconds: float = 5.0

@onready var _pause_button: Button = %PauseButton
@onready var _timer_button: Button = %TimerButton
@onready var _score_hud: MinigameScoreHUD = %ScoreHud
@onready var _pause_glyph: TextureRect = %PauseGlyph
@onready var _ring: TimerRing = %Ring
@onready var _timer_label: Label = %TimerLabel


func _ready() -> void:
	if not _has_required_nodes():
		return
	_connect_pause_button()
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


## Fill the plaque's progress bar to value/max_value and write its caption
## verbatim ("Soal 3/10"); see MinigameScoreHUD.set_progress.
func set_progress(value: int, max_value: int, label: String) -> void:
	_score_hud.set_progress(value, max_value, label)


## Drain the timer ring to left/total, red inside danger_seconds, and show the
## whole seconds left, rounded up so "1" shows until the time is out.
func set_time(left: float, total: float) -> void:
	_ring.fraction = 0.0 if total <= 0.0 else left / total
	_ring.danger = left <= danger_seconds
	_timer_label.text = str(ceili(maxf(0.0, left)))


## Enable or disable the pause button (the game disables it once it ends).
func set_pause_enabled(enabled: bool) -> void:
	_pause_button.disabled = not enabled


## True when the scene carries every node this script drives. A missing one
## means MinigameHeader.tscn is broken, so it is an error, not a silent skip.
func _has_required_nodes() -> bool:
	var nodes: Array[Node] = [_pause_button, _timer_button, _score_hud, _pause_glyph,
			_ring, _timer_label]
	if not nodes.has(null):
		return true
	push_error("MinigameHeader: a unique-name node is missing in MinigameHeader.tscn")
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
	_score_hud.set_value_row_visible(show_score)
	_score_hud.set_progress_visible(show_progress)
	_score_hud.visible = show_score or show_progress
	_pause_glyph.texture = pause_icon
