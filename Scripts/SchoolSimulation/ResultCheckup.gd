@tool
extends Control

## The end-of-week report: a pinned WeekRecapBanner over two tabbed
## panes -- SISWA (one DaySummaryStudentRow per student, read one week
## wide) and RIWAYAT (the week's minigames and events as WeekHistoryRows)
## -- rebuilt to the 2026-09-03 spec.
##
## Everything visual is an authored scene. This script only decides
## WHICH deltas a card shows (DaySummaryStudentRow.setup_week_row), which
## pane is visible, and when the entrance's five stages fire. Stages 1-3
## belong to the banner; stages 4-5 are here, because this is what owns
## the cards.
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect
## is gated on Engine.is_editor_hint(); signal wiring deliberately is
## not.
##
## Every surface is a theme variation and every accent is a DesignToken;
## this script builds no StyleBoxFlat and holds no Color literal.

signal checkup_closed

## The two panes, in tab order. Indices into _panes and the argument
## show_pane takes.
enum Pane { SISWA = 0, RIWAYAT = 1 }

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

# ── Visual - Tabs ────────────────────────────────────────────────────
@export_group("Visual - Tabs")
## Label on the students tab. The live count is appended in brackets.
@export var tab_students_text: String = "SISWA"
## Label on the history tab. The live count is appended in brackets.
@export var tab_history_text: String = "RIWAYAT"

# ── Visual - Buttons ─────────────────────────────────────────────────
@export_group("Visual - Buttons")
## Art-supplied close-button texture. Null keeps the theme's button
## styling and shows close_button_text as a plain label instead.
@export var button_close_texture: Texture2D = null
## Label shown on the close button when button_close_texture is null.
@export var close_button_text: String = "Selesai Evaluasi"

# ── Wiring ───────────────────────────────────────────────────────────
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene
## The history row template, WeekHistoryRow.tscn.
@export var history_row_scene: PackedScene

const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/CelebrationConfetti.tscn"

@onready var title_label: Label = $Margin/VBox/HeaderPanel/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/HeaderPanel/SubtitleLabel
@onready var banner: WeekRecapBanner = $Margin/VBox/Banner
@onready var tab_siswa: Button = $Margin/VBox/TabBar/TabSiswa
@onready var tab_riwayat: Button = $Margin/VBox/TabBar/TabRiwayat
@onready var scroll_container: ScrollContainer = $Margin/VBox/ScrollContainer
@onready var students_pane: VBoxContainer = $Margin/VBox/ScrollContainer/PaneStack/StudentsPane
@onready var history_pane: VBoxContainer = $Margin/VBox/ScrollContainer/PaneStack/HistoryPane
@onready var history_empty_label: Label = $Margin/VBox/ScrollContainer/PaneStack/HistoryPane/EmptyLabel
@onready var btn_close: Button = $Margin/VBox/BtnClose

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

## The active tab, as a Pane value.
var _active_pane: int = Pane.SISWA
## Each pane's own last scroll offset, so switching back returns to the
## card you were reading rather than snapping to the top.
var _pane_scroll: Array[int] = [0, 0]
## Latched the first time RIWAYAT opens. Its rows stagger in once; every
## later switch is an instant show, so tabbing back and forth never
## re-fires the stamp cue.
var _history_animated: bool = false
## The instanced history rows, kept so the lazy first animation can reach
## them without re-walking the tree.
var _history_rows: Array = []


func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can
	# exercise it; everything below the guard is a real side effect.
	btn_close.pressed.connect(_on_close_pressed)
	tab_siswa.pressed.connect(show_pane.bind(Pane.SISWA))
	tab_riwayat.pressed.connect(show_pane.bind(Pane.RIWAYAT))
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)
	_sync_tab_buttons()
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	_apply_visual_exports()
	btn_close.modulate.a = 0.0
	btn_close.disabled = true


func initialize_checkup(student_manager: StudentManager) -> void:
	_apply_visual_exports()

	var recap: Dictionary = WeekRecap.compute(student_manager)
	banner.set_recap(recap)

	for child in students_pane.get_children():
		child.queue_free()
	for child in history_pane.get_children():
		if child != history_empty_label:
			child.queue_free()
	_history_rows.clear()

	if student_manager == null:
		_update_tab_counts(0, 0)
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

	var history: Array = student_manager.minigame_history
	history_empty_label.visible = history.is_empty()
	for entry in history:
		var row := history_row_scene.instantiate() as WeekHistoryRow
		history_pane.add_child(row)
		row.set_entry(entry)
		_set_mouse_filter_pass(row)
		_history_rows.append(row)

	_update_tab_counts(cards.size(), history.size())
	_play_entrance_animations(cards)


## Show one pane and hide the other, remembering where each was scrolled
## to. Safe to call with the already-active pane: it is a no-op and plays
## nothing, so a second tap on the live tab is silent.
func show_pane(pane: int) -> void:
	if pane == _active_pane and students_pane.visible != history_pane.visible:
		return
	if scroll_container:
		_pane_scroll[_active_pane] = scroll_container.scroll_vertical
	_active_pane = pane
	students_pane.visible = pane == Pane.SISWA
	history_pane.visible = pane == Pane.RIWAYAT
	if scroll_container:
		# Deliberately synchronous, not set_deferred. A deferred write is
		# the theoretically correct fix for the ScrollContainer's
		# scrollbar max_value being narrowly one layout pass stale right
		# after the visibility flip above -- but show_pane is called
		# directly by tests (suite.call(name), no frame processing
		# in-between, no coroutines allowed here per this file's own
		# testing constraints) and there is no supported way to flush a
		# deferred call inside that harness. A deferred write would
		# silently break both of this file's passing scroll-memory
		# tests with no way to re-cover them. The risk window this
		# leaves open is narrow: it only matters when the two panes'
		# content heights differ AND the read happens before the next
		# idle frame resyncs the scrollbar. Documented and accepted
		# rather than fixed, per 2026-09-03 review (Task 9 fix round).
		scroll_container.scroll_vertical = _pane_scroll[pane]
	_sync_tab_buttons()

	if Engine.is_editor_hint():
		_history_animated = _history_animated or pane == Pane.RIWAYAT
		return

	AudioDirector.play_sfx(&"select")
	if pane == Pane.RIWAYAT and not _history_animated:
		_history_animated = true
		_play_history_entrance()


## Keep the two toggle buttons agreeing with _active_pane. The pressed
## state is what the WeekTabButton variation styles, so no manual tint is
## needed here.
func _sync_tab_buttons() -> void:
	if tab_siswa:
		tab_siswa.button_pressed = _active_pane == Pane.SISWA
	if tab_riwayat:
		tab_riwayat.button_pressed = _active_pane == Pane.RIWAYAT


## "SISWA (4)" / "RIWAYAT (7)" -- so the player can see there is
## something worth tapping before tapping it.
func _update_tab_counts(student_count: int, history_count: int) -> void:
	if tab_siswa:
		tab_siswa.text = "%s (%d)" % [tab_students_text, student_count]
	if tab_riwayat:
		tab_riwayat.text = "%s (%d)" % [tab_history_text, history_count]


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

	if btn_close:
		btn_close.text = "" if button_close_texture else close_button_text
		if font: btn_close.add_theme_font_override("font", font)
		if button_close_texture:
			var sb = StyleBoxTexture.new()
			sb.texture = button_close_texture
			btn_close.add_theme_stylebox_override("normal", sb)
			btn_close.add_theme_stylebox_override("hover", sb)
			btn_close.add_theme_stylebox_override("pressed", sb)


func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control:
		if not node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)


## RIWAYAT's lazy first open: rows stagger in, a win stamping into place
## and a loss shaking. Latched by show_pane, so this runs at most once.
func _play_history_entrance() -> void:
	Juice.stagger_in(_history_rows)
	for i in _history_rows.size():
		var row: WeekHistoryRow = _history_rows[i]
		if row.is_event():
			continue  # events get neither the stamp nor the shake
		if row.is_win():
			AudioDirector.play_sfx(&"stamp")
		else:
			Juice.shake(row)


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

	var button_tween = create_tween()
	button_tween.tween_property(btn_close, "modulate:a", 1.0, t.dur_fast)
	btn_close.disabled = false


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
	AudioDirector.play_sfx(&"confirm")
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
	await fade_out.finished
	checkup_closed.emit()
