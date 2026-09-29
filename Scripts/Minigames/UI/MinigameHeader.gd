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
##
## Mobile layout (spec 2026-09-29 minigame mobile layout, 3.1): a progress
## row under the strip (set_progress), a drained timer ring (set_time), and
## pause/timer pictures as ButtonGlyph children rather than Button.icon,
## because a lipped button's content margins squeeze an icon. A hidden
## timer keeps its 96px slot so the score pill stays centred.

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
## Whether the centre score pill shows (BuatBatik has no score).
@export var show_score: bool = true:
	set(value):
		show_score = value
		_apply_exports()
## Whether the progress row under the strip shows.
@export var show_progress: bool = true:
	set(value):
		show_progress = value
		_apply_exports()
## Draw the progress bar as max_value cells (BuatBatik's four steps).
@export var segmented: bool = false
## The last seconds in which the timer ring turns state_danger (ours; spec 6).
@export_range(0.0, 30.0, 0.5) var danger_seconds: float = 5.0

@onready var _pause_button: Button = %PauseButton
@onready var _timer_button: Button = %TimerButton
@onready var _score_hud: MinigameScoreHUD = %ScoreHud
@onready var _pause_glyph: TextureRect = %PauseGlyph
@onready var _timer_glyph: TextureRect = %TimerGlyph
@onready var _ring: TimerRing = %Ring
@onready var _progress_row: Control = %ProgressRow
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_label: Label = %ProgressLabel
@onready var _ticks: ProgressTicks = %Ticks


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


## Fill the progress bar to value/max_value and write its label verbatim
## ("Soal 3/10"). In the running game the fill tweens (Juice.fill_bar); in
## the editor it is written straight, so tests read it back at once.
func set_progress(value: int, max_value: int, label: String) -> void:
	_progress_bar.max_value = maxf(1.0, float(max_value))
	_progress_label.text = label
	_ticks.segments = max_value if segmented else 0
	if Engine.is_editor_hint():
		_progress_bar.value = float(value)
	else:
		Juice.fill_bar(_progress_bar, float(value))


## Drain the timer ring to left/total, red inside danger_seconds.
func set_time(left: float, total: float) -> void:
	_ring.fraction = 0.0 if total <= 0.0 else left / total
	_ring.danger = left <= danger_seconds


## Enable or disable the pause button (the game disables it once it ends).
func set_pause_enabled(enabled: bool) -> void:
	_pause_button.disabled = not enabled


## True when the scene carries every node this script drives. A missing one
## means MinigameHeader.tscn is broken, so it is an error, not a silent skip.
func _has_required_nodes() -> bool:
	var nodes: Array[Node] = [_pause_button, _timer_button, _score_hud, _pause_glyph,
			_timer_glyph, _ring, _progress_row, _progress_bar, _progress_label, _ticks]
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
	_score_hud.visible = show_score
	_progress_row.visible = show_progress
	_pause_glyph.texture = pause_icon
	_timer_glyph.texture = timer_icon
