@tool
extends Control

## Weekly Results: the end-of-week report, rebuilt to
## docs/superpowers/mockups/mockup_weeklyresults.png (2026-09-14
## weekly-results spec). A red ribbon; one DaySummaryStudentRow per student,
## read one week wide; the week's Wirausaha coins; how many minigames were
## won and lost; and two buttons -- Logs (the week's history, in a
## WeekLogsPopup) and Selanjutnya (back to SchoolDay, then the Lobby).
##
## Everything visual is an authored scene. This script only fills the
## labels, instances the cards and the Logs sheet, and runs the entrance.
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect is
## gated on Engine.is_editor_hint(); signal wiring deliberately is not.

signal checkup_closed

# ── Copy ─────────────────────────────────────────────────────────────
@export_group("Copy")
## Prefix of the minigames-won line; the count follows it.
@export var event_won_prefix: String = "EVENT BERHASIL : "
## Prefix of the minigames-lost line; the count follows it.
@export var event_lost_prefix: String = "EVENT GAGAL : "
## The Logs button's label.
@export var logs_button_text: String = "Logs"
## The Selanjutnya button's label.
@export var next_button_text: String = "Selanjutnya"

# ── Wiring ───────────────────────────────────────────────────────────
@export_group("Wiring")
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene
## The Logs sheet, WeekLogsPopup.tscn, instanced on each Logs tap.
@export var logs_popup_scene: PackedScene

const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/PaperConfetti.tscn"

@onready var title_banner: TextureRect = $Margin/Layout/TitleBanner
@onready var cards_scroll: ScrollContainer = $Margin/Layout/CardsScroll
@onready var cards_list: VBoxContainer = $Margin/Layout/CardsScroll/CardsList
@onready var money_label: Label = $Margin/Layout/Summary/Lines/CoinRow/MoneyLabel
@onready var event_won_label: Label = $Margin/Layout/Summary/Lines/EventWonLabel
@onready var event_lost_label: Label = $Margin/Layout/Summary/Lines/EventLostLabel
@onready var logs_button: Button = $Margin/Layout/Buttons/LogsButton
@onready var next_button: Button = $Margin/Layout/Buttons/NextButton

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

## This week's history, handed to each Logs sheet.
var _history: Array = []
## The Wirausaha payout the money line counts up to.
var _week_earnings: int = 0
## Latched on the first Logs open: the rows' stamp-and-shake entrance plays
## once, so reopening the sheet never re-fires the stamp cue.
var _logs_seen: bool = false
## The open Logs sheet, or null.
var _logs_popup: Control = null


func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can exercise
	# it; everything below the guard is a real side effect.
	logs_button.pressed.connect(open_logs)
	next_button.pressed.connect(_on_next_pressed)
	cards_scroll.gui_input.connect(_on_scroll_gui_input)
	logs_button.text = logs_button_text
	next_button.text = next_button_text
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	for b in [logs_button, next_button]:
		b.modulate.a = 0.0
		b.disabled = true


## Fill the screen for the week `student_manager` just simulated.
## `week_earnings` is the Wirausaha payout SchoolDay made just before opening
## this screen -- it has already left GameState.pending_earnings, so it is
## handed over rather than re-read.
func initialize_checkup(student_manager: StudentManager, week_earnings: int = 0) -> void:
	var recap: Dictionary = WeekRecap.compute(student_manager)
	_week_earnings = week_earnings
	money_label.text = format_earnings(week_earnings)
	event_won_label.text = event_won_prefix + str(recap["minigames_won"])
	event_lost_label.text = event_lost_prefix + str(recap["minigames_lost"])

	for child in cards_list.get_children():
		child.queue_free()
	_history = []
	if student_manager == null:
		return

	var cards: Array = []
	for student in student_manager.students:
		var card := student_card_scene.instantiate() as DaySummaryStudentRow
		cards_list.add_child(card)
		# Set up only once the card is in the tree: its @onready nodes are
		# null until then. Same order DaySummaryPopup.setup_summary uses.
		card.setup_week_row(student)
		_set_mouse_filter_pass(card)
		cards.append(card)

	_history = student_manager.minigame_history.duplicate()
	_play_entrance(cards)


## "+1.000" for a week that earned, "0" for one that did not.
static func format_earnings(value: int) -> String:
	return ("+" if value > 0 else "") + WeekRecap.format_money(value)


## Open the Logs sheet over the screen. One at a time; the rows' entrance
## plays on the first open only.
func open_logs() -> void:
	if is_instance_valid(_logs_popup):
		return
	var popup := logs_popup_scene.instantiate() as WeekLogsPopup
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.set_history(_history)
	popup.closed.connect(func(): _logs_popup = null)
	_logs_popup = popup
	popup.open(not _logs_seen)
	_logs_seen = true


func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control:
		if not node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)


func _play_entrance(cards: Array) -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return

	var t := Juice.tokens()
	var fader := create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	Juice.pop_in(title_banner)
	await get_tree().create_timer(t.dur_fast).timeout

	# Cards land one at a time, each card's five gauges moving on the beat
	# that card ARRIVES on -- the nightly popup's own cadence, one week long.
	Juice.stagger_in(cards)
	for i in cards.size():
		cards[i].play_week_gain(float(i) * t.stagger_step)

	# The coins count up and the two tallies pop once the cards are down.
	var cards_down := float(cards.size()) * t.stagger_step + t.dur_normal
	Juice.count_up_formatted(money_label, 0.0, float(_week_earnings),
		func(v: float) -> String: return format_earnings(int(round(v))), cards_down)
	Juice.pop_in(event_won_label, cards_down)
	Juice.pop_in(event_lost_label, cards_down + t.stagger_step)

	# One celebration for the whole week, landing just behind the last
	# card's own burst -- and only if the week went somewhere. A flat or
	# losing week gets the report without the party.
	var week_gained := false
	for card in cards:
		if card.gained_ground():
			week_gained = true
			break
	if week_gained:
		AudioDirector.play_sfx(&"reward")
		var celebration_scene: PackedScene = load(_CELEBRATION_SCENE)
		var celebration := celebration_scene.instantiate() as RewardParticles
		celebration.position = get_node("Celebration").position
		add_child(celebration)
		celebration.fire(float(cards.size()) * t.stagger_step)

	await get_tree().create_timer(cards_down + t.dur_slow).timeout

	for b in [logs_button, next_button]:
		var tw := create_tween()
		tw.tween_property(b, "modulate:a", 1.0, t.dur_fast)
		b.disabled = false


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_scroll = true
			drag_start_y = event.global_position.y
			initial_scroll_v = cards_scroll.scroll_vertical
		else:
			is_dragging_scroll = false
	elif event is InputEventMouseMotion and is_dragging_scroll:
		var delta_y = event.global_position.y - drag_start_y
		cards_scroll.scroll_vertical = int(initial_scroll_v - delta_y)


func _on_next_pressed() -> void:
	# One exit only: the fade-out below takes dur_normal, and a second tap on
	# Selanjutnya -- or a tap on Logs -- during it must not fire again.
	next_button.disabled = true
	logs_button.disabled = true
	AudioDirector.play_sfx(&"confirm")
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
	await fade_out.finished
	checkup_closed.emit()
