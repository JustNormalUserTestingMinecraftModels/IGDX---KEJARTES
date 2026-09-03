@tool
extends Control

## @tool note: mirrors Scripts/MainMenu/main_menu.gd's established pattern
## (see that script's header for the full placeholder-instance
## explanation). Without @tool this script becomes a placeholder instance
## when the MCP test suite instantiates this scene from inside the editor
## process, which breaks traversal-based checks like
## test_scene_has_no_theme_overrides the moment they reach this node.
##
## Gating: _setup_top_bar_buttons() / _setup_level_select_ui() build and
## wire the static UI (buttons, modal) and must run in both a human's
## editor session and the test suite's instantiation, exactly like
## MainMenu's button wiring. Everything below the
## Engine.is_editor_hint() guard -- reading GameState to decide which
## branch of the cutscene to show, refreshing GameState-derived button
## text, and kicking off the first CG/dialogue reveal -- is a genuine
## runtime-only side effect and must never fire just because a human
## opened this scene in the editor, or because the test suite
## instantiated it. _input() is left unguarded: per Splashscreen's
## established note, Control nodes edited in the editor never receive
## real game input events, so there is nothing to gate there.

@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel
@onready var dialogue_box: Control = $DialogueBox
@onready var bg_cutscene: TextureRect = $BgCutScene
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var _tokens: DesignTokens = DesignTokens.load_default()

## Typewriter speed, tunable in the inspector without touching code.
@export var typewriter_chars_per_second: float = 45.0

var cg_data = [
	{
		"image": preload("res://Assets/Images/CG/cg0.jpg"),
		"text": "Fiuh, setelah sekian lama aku mendaftar di sekolah ini. Akhirnya saya resmi diakui untuk mengajar disini!"
	},
	{
		"image": preload("res://Assets/Images/CG/cg1.jpg"),
		"text": "Formulir pengajuan yang diterima dan ditandatangani resmi dari guru yang akan menjadi karakter kita ini"
	},
	{
		"image": preload("res://Assets/Images/CG/cg2.jpg"),
		"text": "Karakter kita ini senang atau bangga besar."
	},
	{
		"image": preload("res://Assets/Images/CG/cg3.jpg"),
		"text": "Lokasi halaman depan Akademi, yang akan menjadi latar kita nanti untuk mengajar."
	},
	{
		"image": preload("res://Assets/Images/CG/cg4.jpg"),
		"text": "Pemandangan kelas dari pojok kanan atas, memperlihatkan seluruh isi kelas yang kosong dan yang akan diajar oleh sang guru."
	}
]

var cg_index := 0
var is_transitioning := false
var _reveal_tween: Tween

# Level Selection UI elements
var level_select_overlay: Control
var is_showing_level_select := false
var btn_skip: Button
var btn_debug_toggle: Button

func _ready():
	fade_overlay.color.a = 0.0
	_setup_top_bar_buttons()
	_setup_level_select_ui()

	if Engine.is_editor_hint():
		return

	_update_debug_button_text()

	if GameState.is_exam_intro_cutscene:
		_setup_exam_cutscene()
	elif GameState.is_game_over_cutscene:
		_setup_game_over_cutscene()
	else:
		# Show level selection BEFORE playing intro cutscene if unlocked or in debug mode
		if GameState.is_game_beaten or GameState.debug_level_select_enabled:
			show_level_select_modal()
		else:
			GameState.set_grade(7)
			show_current()

## The pre-exam beat, between the Tes Besar notice and the stat check.
##
## Deliberately short -- four lines -- and deliberately neutral: the
## player does not yet know whether they passed, and this cutscene must
## not hint either way.
##
## The CG images are the intro's, standing in until dedicated exam art
## lands. Swapping them is a four-line change here and nothing else.
func _setup_exam_cutscene() -> void:
	if btn_debug_toggle: btn_debug_toggle.visible = false
	if btn_skip: btn_skip.visible = false

	cg_data = [
		{
			"image": preload("res://Assets/Images/CG/cg3.jpg"),
			"text": "[PLACEHOLDER] Pagi itu halaman sekolah terasa berbeda. Semua murid berjalan pelan menuju aula, membawa pensil dan harapan masing-masing."
		},
		{
			"image": preload("res://Assets/Images/CG/cg4.jpg"),
			"text": "[PLACEHOLDER] Aku berdiri di depan pintu aula, menghitung lagi wajah-wajah yang sudah kubimbing selama satu tahun ajaran ini."
		},
		{
			"image": preload("res://Assets/Images/CG/cg2.jpg"),
			"text": "[PLACEHOLDER] 'Bu, Pak... kami sudah siap,' kata salah satu dari mereka. Suaranya bergetar, tapi matanya tidak."
		},
		{
			"image": preload("res://Assets/Images/CG/cg0.jpg"),
			"text": "[PLACEHOLDER] Bel berbunyi. Tes Besar Sekolah dimulai. Sekarang giliran mereka yang berjuang, dan giliranku untuk percaya."
		}
	]
	cg_index = 0
	show_current()

func _setup_game_over_cutscene() -> void:
	if btn_debug_toggle: btn_debug_toggle.visible = false
	if btn_skip: btn_skip.visible = false
	if bg_cutscene:
		bg_cutscene.modulate = Color.WHITE.darkened(0.55)

	cg_data = [
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Kepala Sekolah menggelengkan kepalanya melihat hasil evaluasi akhir... 'Maaf, murid-muridmu belum memenuhi standar kelulusan.'"
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Aku tertunduk lesu di ruangannya. Semua usaha keras membimbing mereka selama satu semester ini terasa sirna..."
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Melihat ruang kelas yang kosong, aku teringat kembali wajah-wajah penuh harapan dari murid-muridku."
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Aku merasa bersalah. Aku telah gagal membuktikan diriku sebagai guru pembimbing yang baik bagi mereka."
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Tapi, aku tidak boleh menyerah begitu saja! Aku harus kembali mengajar mereka dengan segenap kemampuanku kali ini!"
		}
	]
	cg_index = 0
	show_current()

func _setup_top_bar_buttons() -> void:
	# Top HBox for Skip & Debug controls
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(30, 40)
	top_bar.size = Vector2(1020, _tokens.touch_target_min + 20)
	add_child(top_bar)

	# Debug level select toggle button. Text is a static placeholder here
	# -- reading GameState.debug_level_select_enabled happens later, in
	# _update_debug_button_text(), which only runs at real runtime (see
	# the Engine.is_editor_hint() guard in _ready()).
	btn_debug_toggle = Button.new()
	btn_debug_toggle.theme_type_variation = &"SecondaryButton"
	btn_debug_toggle.text = "🐛 Debug Level Select"
	btn_debug_toggle.custom_minimum_size = Vector2(420, _tokens.touch_target_min)
	# _update_debug_button_text() swaps this in for a longer runtime string
	# ("...: ON (Pilih Kelas)"). Without clip_text, a Button's minimum size
	# grows to fit whatever text it currently holds, so that longer string
	# pushed this button past 420px wide, widening the whole top_bar HBox
	# past the 1080px screen and shoving Skip Intro off the right edge
	# entirely -- clip_text pins it back to custom_minimum_size and
	# ellipsizes instead.
	btn_debug_toggle.clip_text = true
	btn_debug_toggle.pressed.connect(_on_debug_toggle_pressed)
	top_bar.add_child(btn_debug_toggle)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Skip cutscene button
	btn_skip = Button.new()
	btn_skip.theme_type_variation = &"DangerButton"
	btn_skip.text = "⏩ Skip Intro"
	btn_skip.custom_minimum_size = Vector2(260, _tokens.touch_target_min)
	btn_skip.clip_text = true
	btn_skip.pressed.connect(_on_skip_pressed)
	top_bar.add_child(btn_skip)

func _update_debug_button_text() -> void:
	if btn_debug_toggle:
		var mode_str = "ON (Pilih Kelas)" if GameState.debug_level_select_enabled else "OFF (Normal)"
		btn_debug_toggle.text = "🐛 Debug Level Select: " + mode_str

func _setup_level_select_ui() -> void:
	# Overlay container
	level_select_overlay = Control.new()
	level_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_select_overlay.visible = false
	add_child(level_select_overlay)

	# Dark dim backdrop, using the same scrim the rest of the game uses
	# for modal overlays.
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = _tokens.scrim_color()
	level_select_overlay.add_child(dim)

	# Centered Modal Panel
	var panel = PanelContainer.new()
	panel.theme_type_variation = &"Card"
	panel.custom_minimum_size = Vector2(900, 1100)
	panel.position = Vector2(90, 360)
	level_select_overlay.add_child(panel)

	var margin = MarginContainer.new()
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	# Header Title
	var title = Label.new()
	title.text = "🎓 PILIH TINGKAT KELAS 🎓"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"H1Label"
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Pilih tingkat jenjang kelas yang ingin kamu bimbing:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.theme_type_variation = &"CaptionLabel"
	vbox.add_child(subtitle)

	# Debug Badge
	var debug_badge = Label.new()
	debug_badge.text = "🔧 [MODE DEBUG: LEVEL SELECT AKTIF]"
	debug_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_badge.theme_type_variation = &"MicroLabel"
	# self_modulate tints the already-themed text; it is a Control
	# property, not a theme override, and reads its color from the
	# token palette rather than a hardcoded literal.
	debug_badge.self_modulate = _tokens.cat_akademis
	vbox.add_child(debug_badge)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Buttons Container
	var btn_vbox = VBoxContainer.new()
	vbox.add_child(btn_vbox)

	# Grade 7 Button
	_create_grade_button(btn_vbox, 7, "🏫 KELAS 7 (Tingkat Pertama)", "Awal Tahun Ajaran • Minggu 1 • Dasar Pembimbingan", &"PrimaryButton")

	# Grade 8 Button
	_create_grade_button(btn_vbox, 8, "🏫 KELAS 8 (Tingkat Menengah)", "Tahun Ajaran Ke-2 • Minggu 17 • Tantangan Meningkat", &"SecondaryButton")

	# Grade 9 Button
	_create_grade_button(btn_vbox, 9, "🎓 KELAS 9 (Tingkat Akhir)", "Ujian Kelulusan Utama • Minggu 33 • Evaluasi Final", &"DangerButton")

func _create_grade_button(parent: VBoxContainer, grade_num: int, title_text: String, desc_text: String, variation: StringName) -> void:
	var btn = Button.new()
	btn.theme_type_variation = variation
	btn.custom_minimum_size = Vector2(0, 140)
	btn.text = title_text + "\n" + desc_text
	btn.pressed.connect(func(): _on_grade_selected(grade_num))
	parent.add_child(btn)

func _on_debug_toggle_pressed() -> void:
	GameState.debug_level_select_enabled = not GameState.debug_level_select_enabled
	GameSettings.save_settings()
	_update_debug_button_text()
	print("Debug Level Select toggled: ", GameState.debug_level_select_enabled)
	if GameState.debug_level_select_enabled and not is_showing_level_select:
		show_level_select_modal()

## Shared with go_to_gameplay(): both exits from this scene fade to black
## the same way before the scene change.
func _fade_to_black(duration: float = 0.8) -> void:
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, duration)
	await tween.finished

## Skip bails straight to Lobby, unlike finishing the cutscene normally
## (go_to_gameplay, below), which must route through StudentCard so a
## fresh game gets a real approved_students roster instead of leaving it
## empty. This button is never shown during the game-over/retry cutscene
## (_setup_game_over_cutscene hides it, see _ready), so there is no
## GameState.is_game_over_cutscene reset to reconcile here -- it is
## always false while Skip Intro exists on screen.
func _on_skip_pressed() -> void:
	# Transition.change_scene() already plays "whoosh" on the scene change;
	# adding another here would stack with the _input handler's "tap" and
	# UIPolish's game-wide auto-tap (three cues, not the "two is fine" the
	# project's convention allows -- see student_card.gd's
	# _on_belajar_pressed note).
	print("Skip Cutscene pressed")
	await _fade_to_black()
	GameState.next_scene = "res://Scenes/Lobby/loby.tscn"
	get_tree().change_scene_to_file("res://Scenes/Loading/loading.tscn")

func show_level_select_modal() -> void:
	is_showing_level_select = true
	level_select_overlay.visible = true
	var tween = create_tween()
	level_select_overlay.modulate.a = 0.0
	tween.tween_property(level_select_overlay, "modulate:a", 1.0, 0.3)

func _on_grade_selected(grade_num: int) -> void:
	AudioDirector.play_sfx(&"select")
	print("Grade selected before cutscene: ", grade_num)
	GameState.set_grade(grade_num)

	is_showing_level_select = false
	var tween = create_tween()
	tween.tween_property(level_select_overlay, "modulate:a", 0.0, 0.25)
	await tween.finished
	level_select_overlay.visible = false

	show_current()

## Deliberately slower than transition_to_next()'s panel-to-panel
## crossfade (which uses _tokens.dur_normal) -- this is the very first
## beat of a reveal sequence (fresh game, after grade select, or the
## loss-retry cutscene), and it should read as a breath before the
## scene commits to its opening image, not a routine page-turn.
const _ENTRANCE_HOLD_SEC := 0.4
const _ENTRANCE_FADE_SEC := 1.0

func show_current():
	if GameState.is_exam_intro_cutscene:
		AudioDirector.play_bgm(&"exam_cutscene")
	elif GameState.is_game_over_cutscene:
		AudioDirector.play_bgm(&"result_lose")
	else:
		AudioDirector.play_bgm(&"introcutscene")
	is_transitioning = true
	bg_cutscene.texture = cg_data[cg_index]["image"]
	bg_cutscene.modulate.a = 0.0
	await get_tree().create_timer(_ENTRANCE_HOLD_SEC).timeout
	_reveal(cg_data[cg_index]["text"])
	var tw := create_tween()
	tw.tween_property(bg_cutscene, "modulate:a", 1.0, _ENTRANCE_FADE_SEC) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	is_transitioning = false

## Typewriter reveal via visible_ratio rather than character-slicing, so
## any BBCode in the dialogue text renders correctly instead of being
## sliced mid-tag.
func _reveal(text: String) -> void:
	dialogue_label.text = text
	dialogue_label.visible_ratio = 0.0
	var chars := float(dialogue_label.get_total_character_count())
	var duration := chars / typewriter_chars_per_second
	var tw := dialogue_label.create_tween()
	tw.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
	_reveal_tween = tw

func _input(event):
	if is_transitioning or is_showing_level_select:
		return

	var tapped = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true

	if not tapped:
		return

	AudioDirector.play_sfx(&"tap")
	_on_tap()

## Visual-novel contract: tapping mid-reveal completes the current line
## instantly. It does not advance -- that requires a second, separate tap.
func _on_tap() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid() \
			and dialogue_label.visible_ratio < 1.0:
		_reveal_tween.kill()
		dialogue_label.visible_ratio = 1.0
		return
	advance()

func advance():
	cg_index += 1
	if cg_index >= cg_data.size():
		go_to_gameplay()
	else:
		transition_to_next()

## Cross-fades the CG image instead of hard-cutting it: fade BgCutScene
## out, swap the texture, fade it back in.
func transition_to_next():
	is_transitioning = true

	var tween_out = create_tween()
	tween_out.tween_property(bg_cutscene, "modulate:a", 0.0, _tokens.dur_normal)
	await tween_out.finished

	bg_cutscene.texture = cg_data[cg_index]["image"]
	_reveal(cg_data[cg_index]["text"])

	var tween_in = create_tween()
	tween_in.tween_property(bg_cutscene, "modulate:a", 1.0, _tokens.dur_normal)
	await tween_in.finished

	is_transitioning = false

## Where the cutscene lets out depends on which branch played:
##   exam      -> the stat check
##   game-over -> the run result (the run is already decided; the lose
##                cutscene IS the lose screen)
##   intro     -> the roster approval screen, as before
func _next_scene_path() -> String:
	if GameState.is_exam_intro_cutscene:
		GameState.is_exam_intro_cutscene = false
		return "res://Scenes/EndGame/SemesterEnd.tscn"
	if GameState.is_game_over_cutscene:
		GameState.is_game_over_cutscene = false
		GameState.run_failed = true
		return "res://Scenes/EndGame/RunResult.tscn"
	return "res://Scenes/StudentCard/student_card.tscn"

func go_to_gameplay():
	await _fade_to_black()

	# The reset logic below reads GameState.is_game_over_cutscene, so it
	# must run before _next_scene_path() flips that flag back off.
	if GameState.is_game_over_cutscene:
		var grade_num = GameState.current_grade
		# A semester loss always sends the player back through StudentCard:
		# grade 7 clears the roster outright and needs a real re-approval
		# (see the branch below); grade 8/9 keeps the roster but still uses
		# this screen as the review-the-roster checkpoint before retrying --
		# previously_approved_ids pre-checks the same students, so it reads
		# as a confirm, not a redo.

		# Reset schedules and week
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false

		if grade_num == 7:
			# Grade 7 full restart: clear selection so they select again
			GameState.lobby_tutorial_completed = false
			GameState.approved_students.clear()
			GameState.grade7_student_ids.clear()

			var AturJadwalScript = load("res://Scripts/AturJadwal/atur_jadwal.gd")
			if AturJadwalScript and "tutorial_phase1_done" in AturJadwalScript:
				AturJadwalScript.tutorial_phase1_done = false
				AturJadwalScript.tutorial_phase3_done = false
			var LobbyScript = load("res://Scripts/Lobby/loby.gd")
			if LobbyScript and "tutorial_shown" in LobbyScript:
				LobbyScript.tutorial_shown = false
		else:
			# Grade 8 or 9 restart: restore academic stats back to base_akademis
			GameState.lobby_tutorial_completed = true
			for student in GameState.approved_students:
				student["kepribadian1"] = 80.0
				student["kepribadian2"] = 80.0
				if student.has("base_akademis1"):
					student["akademis1"] = student["base_akademis1"]
				if student.has("base_akademis2"):
					student["akademis2"] = student["base_akademis2"]
				if student.has("base_akademis3"):
					student["akademis3"] = student["base_akademis3"]

	GameState.next_scene = _next_scene_path()
	get_tree().change_scene_to_file("res://Scenes/Loading/loading.tscn")
