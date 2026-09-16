@tool
extends Control

## The end-of-week report: a pinned WeekRecapBanner over one scrolling
## list of DaySummaryStudentRows, each read a week wide, with Logs and
## Selanjutnya beneath it. Built to the 2026-09-03 spec; the SISWA /
## RIWAYAT tabs it shipped with were retired on 2026-09-16, and the
## week's history moved into the Logs sheet (WeekLogsPopup).
##
## Everything visual is an authored scene. This script only decides
## WHICH deltas a card shows (DaySummaryStudentRow.setup_week_row), when
## the entrance's five stages fire, and what the Logs sheet is handed.
## Stages 1-3 belong to the banner; stages 4-5 are here, because this is
## what owns the cards.
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect
## is gated on Engine.is_editor_hint(); signal wiring deliberately is
## not.
##
## Every surface is a theme variation and every accent is a DesignToken;
## this script builds no StyleBoxFlat and holds no Color literal.

signal checkup_closed

# ── Visual - Background Overlay ───────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the report. When set it replaces the panel.
@export var background_texture: Texture2D = null

# ── Visual - Header & Typography ──────────────────────────────────────
@export_group("Visual - Header & Typography")
## Main header title.
@export var header_title_text: String = "EVALUASI MINGGUAN SISWA"
## Main header subtitle, under header_title_text.
@export var header_subtitle_text: String = "Perkembangan statistik & riwayat kegiatan selama satu minggu"
## Optional font override applied across the screen's labels. Null keeps
## the theme's default font.
@export var font: Font = null

# ── Visual - Buttons ─────────────────────────────────────────────────
@export_group("Visual - Buttons")
## The Logs button's label.
@export var logs_button_text: String = "Logs"
## The Selanjutnya button's label.
@export var next_button_text: String = "Selanjutnya"

# ── Wiring ───────────────────────────────────────────────────────────
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene
## The Logs sheet, WeekLogsPopup.tscn, instanced on each Logs tap.
@export var logs_popup_scene: PackedScene

const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/PaperConfetti.tscn"

@onready var title_label: Label = $Margin/VBox/HeaderPanel/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/HeaderPanel/SubtitleLabel
@onready var banner: WeekRecapBanner = $Margin/VBox/Banner
@onready var scroll_container: ScrollContainer = $Margin/VBox/ScrollContainer
@onready var students_pane: VBoxContainer = $Margin/VBox/ScrollContainer/StudentsPane
@onready var logs_button: Button = $Margin/VBox/Buttons/LogsButton
@onready var next_button: Button = $Margin/VBox/Buttons/NextButton

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


func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can
	# exercise it; everything below the guard is a real side effect.
	logs_button.pressed.connect(open_logs)
	next_button.pressed.connect(_on_close_pressed)
	logs_button.text = logs_button_text
	next_button.text = next_button_text
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	_apply_visual_exports()
	for b in [logs_button, next_button]:
		b.modulate.a = 0.0
		b.disabled = true


## `week_earnings` is the Wirausaha payout SchoolDay made just before opening
## this screen. Paying it out empties GameState.pending_earnings, which is
## what WeekRecap._sum_pending_earnings reads, so by now that read is 0 and
## the banner's money pill would show nothing the player earned. The paid
## total is handed over instead (2026-09-14, kept across the 2026-09-16
## revert). A caller that has not paid out yet -- the debug rehearsal --
## omits it and keeps WeekRecap's own read.
func initialize_checkup(student_manager: StudentManager, week_earnings: int = 0) -> void:
	_apply_visual_exports()

	var recap: Dictionary = WeekRecap.compute(student_manager)
	if week_earnings != 0:
		recap["money_earned"] = week_earnings
	banner.set_recap(recap)

	for child in students_pane.get_children():
		child.queue_free()
	_history = []

	if student_manager == null:
		return

	var cards: Array = []
	for student in student_manager.students:
		var card := student_card_scene.instantiate() as DaySummaryStudentRow
		students_pane.add_child(card)
		# Set up only once the card is in the tree: its @onready nodes
		# are null until then. Same order DaySummaryPopup.setup_summary
		# uses.
		card.setup_week_row(student)
		_set_mouse_filter_pass(card)
		cards.append(card)

	_history = student_manager.minigame_history.duplicate()
	_play_entrance_animations(cards)


## Open the week's history as a sheet. Refuses to stack a second one, so a
## double tap on Logs is harmless; the rows' entrance plays on the first
## open only.
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


func _apply_visual_exports() -> void:
	# The themed panel is the default backdrop; an art-supplied photo
	# replaces it outright. Guarded on `is Panel` so a second call cannot
	# stack another TextureRect.
	var bg = get_node_or_null("Background")
	if bg is Panel and background_texture:
		var tex_rect = TextureRect.new()
		tex_rect.name = "Background"
		tex_rect.texture = background_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.queue_free()
		add_child(tex_rect)
		move_child(tex_rect, 0)

	if title_label:
		title_label.text = header_title_text
		if font: title_label.add_theme_font_override("font", font)

	if subtitle_label:
		subtitle_label.text = header_subtitle_text
		if font: subtitle_label.add_theme_font_override("font", font)

	if font:
		for b in [logs_button, next_button]:
			if b:
				b.add_theme_font_override("font", font)


func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control:
		if not node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)


func _play_entrance_animations(cards: Array = []) -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return

	var t := Juice.tokens()
	modulate.a = 0.0
	var fader = create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	# Stages 1-3 belong to the banner: slide, four pill count-ups, and
	# the gated coin shower.
	banner.play_entrance()
	await get_tree().create_timer(t.dur_normal).timeout

	# Stage 4. Cards land one at a time, each card's five gauges moving
	# on the beat that card ARRIVES on -- the nightly popup's own
	# cadence, one week long.
	Juice.stagger_in(cards)
	for i in cards.size():
		cards[i].play_week_gain(float(i) * t.stagger_step)

	# Stage 5. One celebration for the whole week, landing just behind
	# the last card's own burst -- and only if the week went somewhere. A
	# flat or losing week gets the report without the party.
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

	await get_tree().create_timer(t.dur_slow).timeout

	for b in [logs_button, next_button]:
		var button_tween := create_tween()
		button_tween.tween_property(b, "modulate:a", 1.0, t.dur_fast)
		# Enabled only once shown, like the rebuild's own finale: a button
		# enabled while still invisible can take a tap meant for something
		# else.
		button_tween.tween_callback(func(): b.disabled = false)
	banner.start_idle_bounce()


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_scroll = true
			drag_start_y = event.global_position.y
			initial_scroll_v = scroll_container.scroll_vertical
		else:
			is_dragging_scroll = false
	elif event is InputEventMouseMotion and is_dragging_scroll:
		var delta_y = event.global_position.y - drag_start_y
		scroll_container.scroll_vertical = int(initial_scroll_v - delta_y)


func _on_close_pressed() -> void:
	# One exit only: the fade-out below takes dur_normal, and a second tap
	# on Selanjutnya -- or a tap on Logs -- during it must not fire again.
	next_button.disabled = true
	logs_button.disabled = true
	banner.stop_idle_bounce()
	AudioDirector.play_sfx(&"confirm")
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
	await fade_out.finished
	checkup_closed.emit()
