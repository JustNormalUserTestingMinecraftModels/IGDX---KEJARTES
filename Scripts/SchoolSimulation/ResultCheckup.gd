@tool
extends Control

## Weekly Results: the end-of-week report, rebuilt to
## docs/superpowers/mockups/mockup_weeklyresults.png (2026-09-14
## weekly-results spec). A red ribbon; one DaySummaryStudentRow per student,
## read one week wide; the week's Wirausaha coins; how many minigames were
## won and lost; and two buttons -- Logs (the week's history, in a
## WeekLogsPopup) and Selanjutnya (back to SchoolDay, then the Lobby).
##
## Everything visual is an authored scene. This script fills the labels,
## instances the cards and the Logs sheet, and plays the reveal
## (2026-09-14 weekly-report-reveal spec): one reward at a time -- each
## card lands, its three stats count and pop in turn, the three summary
## lines follow, and a tap anywhere lands the lot at once. The rhythm is
## worked out by WeekReportReveal and paced by the Reveal exports.
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

# ── Reveal ───────────────────────────────────────────────────────────
@export_group("Reveal")
## Seconds between a card popping in and its first stat row starting.
@export var card_lead_seconds: float = 0.35
## Seconds a gaining stat row, or a non-zero summary line, takes to count.
@export var count_seconds: float = 0.35
## Pause after a gaining row pops before the next row starts.
@export var row_gap_seconds: float = 0.08
## Seconds a row that did not gain takes to settle: short, and silent.
@export var quiet_row_seconds: float = 0.15
## Pause after a card's last row before the next card lands.
@export var card_gap_seconds: float = 0.15
## Pause between one summary line and the next.
@export var line_gap_seconds: float = 0.12
## Pause after the last summary line before the confetti and the buttons.
@export var finale_gap_seconds: float = 0.2
## How much higher each pop sounds than the one before (1.0 = normal).
@export var pitch_step: float = 0.06
## The highest a pop climbs, however many gains the week has.
@export var pitch_max: float = 1.6

const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/PaperConfetti.tscn"

@onready var title_banner: TextureRect = $Margin/Layout/TitleBanner
@onready var cards_scroll: ScrollContainer = $Margin/Layout/CardsScroll
@onready var cards_list: VBoxContainer = $Margin/Layout/CardsScroll/CardsList
@onready var coin_row: HBoxContainer = $Margin/Layout/Summary/Lines/CoinRow
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
## Latched on the first Logs open: the rows' stamp-and-shake entrance plays
## once, so reopening the sheet never re-fires the stamp cue.
var _logs_seen: bool = false
## The open Logs sheet, or null.
var _logs_popup: Control = null
## The cards this report shows, top to bottom.
var _cards: Array = []
## The values the summary lines count to, top to bottom: coins, won, lost.
var _line_values: Array = [0, 0, 0]
## True while the reveal plays; a tap only skips while it is.
var _revealing: bool = false
## The reveal's one timeline tween, held so a skip can kill it.
var _reveal_tween: Tween = null
## The screen's own in-flight pops, counts and scrolls, held so a skip can
## stop them rather than let them write over the landing.
var _reveal_tweens: Array[Tween] = []


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
	money_label.text = format_earnings(week_earnings)
	event_won_label.text = event_won_prefix + str(recap["minigames_won"])
	event_lost_label.text = event_lost_prefix + str(recap["minigames_lost"])
	_line_values = [week_earnings, int(recap["minigames_won"]), int(recap["minigames_lost"])]

	for child in cards_list.get_children():
		child.queue_free()
	_history = []
	if student_manager == null:
		_cards = []
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
	_cards = cards
	_play_entrance()


## "+1.000" for a week that earned, "0" for one that did not.
static func format_earnings(value: int) -> String:
	return ("+" if value > 0 else "") + WeekRecap.format_money(value)


## The pitch of a report's `index`-th pop: one `step` higher per pop, never
## past `ceiling`. Restarts each week, because each report is a new screen.
static func pop_pitch(index: int, step: float, ceiling: float) -> float:
	return minf(1.0 + float(index) * step, ceiling)


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


## The entrance: the screen fades in on the backdrop alone, the ribbon pops,
## then the timeline plays -- one parallel tween of delayed callbacks, so a
## skip is a single kill().
func _play_entrance() -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return
	_prepare_reveal()
	var t := Juice.tokens()
	var fader := create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished
	if not is_inside_tree():
		return
	_track(Juice.pop_in(title_banner))
	_revealing = true
	_reveal_tween = create_tween().set_parallel(true)
	for step in _build_steps(t.dur_fast):
		_reveal_tween.tween_callback(_run_step.bind(step)).set_delay(float(step["at"]))


## The reveal's opening frame: the backdrop alone. The ribbon, every card
## and every summary line wait transparent (modulate, so nothing reflows as
## they arrive); each card is rewound to Monday and each line reads 0. Not
## editor-gated: it only writes state, so the suite can check it.
func _prepare_reveal() -> void:
	title_banner.modulate.a = 0.0
	for card in _cards:
		card.modulate.a = 0.0
		card.rewind_week()
	for i in _line_values.size():
		_line_node(i).modulate.a = 0.0
		_line_label(i).text = _line_text(i, 0.0)


## This week's reveal as a timeline: every card's three stat deltas and the
## three summary values, paced by the Reveal exports, starting at `start`.
func _build_steps(start: float = 0.0) -> Array:
	var rows: Array = []
	for card in _cards:
		var deltas: Array = []
		for row in card.stat_rows:
			deltas.append(row.shown_delta())
		rows.append(deltas)
	return WeekReportReveal.build(rows, _line_values, {
		"start": start,
		"card_lead": card_lead_seconds,
		"count": count_seconds,
		"row_gap": row_gap_seconds,
		"quiet_row": quiet_row_seconds,
		"card_gap": card_gap_seconds,
		"line_gap": line_gap_seconds,
		"finale_gap": finale_gap_seconds,
	})


## One beat of the timeline. An if/elif chain rather than a match: the
## audio suite's double-fire scan reads elif as "these branches exclude each
## other", and a match's arms as one straight path.
func _run_step(step: Dictionary) -> void:
	var kind: StringName = step["kind"]
	if kind == WeekReportReveal.CARD:
		_land_card(int(step["card"]))
	elif kind == WeekReportReveal.ROW_COUNT:
		_cards[int(step["card"])].stat_rows[int(step["row"])].play_count(float(step["seconds"]))
	elif kind == WeekReportReveal.ROW_POP:
		_cards[int(step["card"])].stat_rows[int(step["row"])].land_pop(
			pop_pitch(int(step["pop_index"]), pitch_step, pitch_max))
	elif kind == WeekReportReveal.LINE:
		_show_line(int(step["row"]), float(step["seconds"]))
	elif kind == WeekReportReveal.LINE_POP:
		_pop_line(int(step["row"]), pop_pitch(int(step["pop_index"]), pitch_step, pitch_max))
	elif kind == WeekReportReveal.FINALE:
		_finale(false)


## A card's arrival: it pops in, its needs bars travel, and the list
## scrolls just far enough to show all of it (two cards fit on screen).
func _land_card(i: int) -> void:
	var card: Control = _cards[i]
	_track(Juice.pop_in(card))
	card.play_needs_week()
	var target := WeekReportReveal.scroll_to_show(card.position.y,
		card.position.y + card.size.y, cards_scroll.size.y,
		float(cards_scroll.scroll_vertical))
	if int(target) != cards_scroll.scroll_vertical:
		var tw := create_tween()
		tw.tween_property(cards_scroll, "scroll_vertical", int(target),
			Juice.tokens().dur_normal).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_track(tw)


## The summary line that pops in, top to bottom: the coin row, then the
## two event tallies.
func _line_node(i: int) -> Control:
	return [coin_row, event_won_label, event_lost_label][i]


## The label a summary line counts on.
func _line_label(i: int) -> Label:
	return [money_label, event_won_label, event_lost_label][i]


## How a summary line reads at value `v`.
func _line_text(i: int, v: float) -> String:
	var n := int(round(v))
	if i == 0:
		return format_earnings(n)
	elif i == 1:
		return event_won_prefix + str(n)
	return event_lost_prefix + str(n)


## A summary line's turn: it pops in and counts from 0 over `seconds`. A
## zero line (seconds 0) has nothing to count and arrives reading 0.
func _show_line(i: int, seconds: float) -> void:
	_track(Juice.pop_in(_line_node(i)))
	if seconds > 0.0:
		_track(Juice.count_up_formatted(_line_label(i), 0.0, float(_line_values[i]),
			func(v: float) -> String: return _line_text(i, v), 0.0, seconds))


## A non-zero summary line lands: the number punches about its own text,
## with the coin cue for the money line and the pop cue for the tallies,
## both at the report's climbing pitch.
func _pop_line(i: int, pitch: float) -> void:
	var label := _line_label(i)
	Juice.punch(label, Juice.text_center(label))
	if i == 0:
		AudioDirector.play_sfx(&"coin", pitch)
	else:
		AudioDirector.play_sfx(&"pop", pitch)


## Hold one of the screen's own reveal tweens so a skip can stop it.
func _track(tw: Tween) -> void:
	if tw != null:
		_reveal_tweens.append(tw)


## Land the whole reveal at once: the timeline stops, every card and line
## shows its final values, and the finale plays. Killing is safe here --
## unlike StatCheck's rush, nothing awaits this tween.
func skip_reveal() -> void:
	if not _revealing:
		return
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	_land_all()
	_finale(true)


## Every card and summary line fully shown on its final value: the skip's
## landing. Not editor-gated: it only writes state.
func _land_all() -> void:
	for tw in _reveal_tweens:
		if tw.is_valid():
			tw.kill()
	_reveal_tweens.clear()
	title_banner.modulate.a = 1.0
	title_banner.scale = Vector2.ONE
	for card in _cards:
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.land_week()
	for i in _line_values.size():
		var node := _line_node(i)
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
		var label := _line_label(i)
		label.scale = Vector2.ONE
		label.text = _line_text(i, float(_line_values[i]))


## The end of the reveal, played or skipped: the paper confetti and the
## reward cue when a card gained ground, then the buttons. A skipped flat
## week still gets one tally, so the tap lands on a sound. A flat or losing
## week gets the report without the party.
func _finale(skipped: bool) -> void:
	_revealing = false
	var week_gained := false
	for card in _cards:
		if card.gained_ground():
			week_gained = true
			break
	if week_gained:
		AudioDirector.play_sfx(&"reward")
		var celebration_scene: PackedScene = load(_CELEBRATION_SCENE)
		var celebration := celebration_scene.instantiate() as RewardParticles
		celebration.position = get_node("Celebration").position
		add_child(celebration)
		celebration.fire()
	elif skipped:
		AudioDirector.play_sfx(&"tally")
	var t := Juice.tokens()
	for b in [logs_button, next_button]:
		var tw := create_tween()
		tw.tween_property(b, "modulate:a", 1.0, t.dur_fast)
		b.disabled = false


## A tap anywhere skips the reveal to its end. _input(), like StatCheck's,
## because the full-screen scroll and cards would otherwise claim the tap
## first. It acts only while the reveal plays, so Logs, Selanjutnya and the
## drag-scroll behave normally afterwards. The tap is not marked handled,
## also like StatCheck's: the debug overlay's own tap gesture must still
## see it.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _revealing:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		skip_reveal()


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
