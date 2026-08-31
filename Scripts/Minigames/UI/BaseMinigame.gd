extends Control
class_name BaseMinigame

signal minigame_won
signal minigame_lost

var difficulty: int = 1
var timer: Timer
var is_game_active: bool = false
var has_time_limit: bool = false

# ─── Tutorial Settings (Inspector Editable) ─────────────────────────────────
@export_group("Tutorial")
@export var tutorial_title: String = ""
@export_multiline var tutorial_instructions: String = ""

# ─── Visual - Result Overlay (Win/Lose Condition Texts) ─────────────────────
@export_group("Visual - Result Overlay")
## Custom Win title text. Leave default or customize per minigame.
@export var win_title_text: String = "Kamu Berhasil! 🎉"
## Custom Lose title text.
@export var lose_title_text: String = "Belum Tepat, Coba Lagi Lain Kali!"
## Custom Win subtitle text.
@export var win_subtitle_text: String = ""
## Custom Lose subtitle text.
@export var lose_subtitle_text: String = "Jadikan semua kegagalan sebagai batu loncatan!"
## Color of the Win title label.
@export var win_title_color: Color = Color(0.2, 0.9, 0.4)
## Color of the Lose title label.
@export var lose_title_color: Color = Color(1.0, 0.65, 0.2)
## Color of the Win subtitle label.
@export var win_subtitle_color: Color = Color(0.95, 0.95, 0.95)
## Color of the Lose subtitle label.
@export var lose_subtitle_color: Color = Color(0.95, 0.95, 0.95)
## Font size for the Win/Lose title label.
@export var result_title_font_size: int = 72
## Font size for the Win/Lose subtitle label.
@export var result_subtitle_font_size: int = 36

# ── Visual - Achievement Popup Card ─────────────────────────────────────────
@export_group("Visual - Achievement Popup")
## Optional PNG for the card background. Leave empty to use procedural dark navy panel.
@export var popup_card_texture: Texture2D = null
@export var popup_card_color: Color = Color(0.06, 0.06, 0.14, 0.97)
@export var popup_border_color: Color = Color(0.85, 0.7, 0.2, 0.9)
@export var popup_dim_color: Color = Color(0, 0, 0, 0.75)

@export_group("Visual - Achievement Stars")
## Optional PNG for a filled (earned) star. Leave empty for procedural gold star.
@export var popup_star_texture: Texture2D = null
## Optional PNG for an empty (unearned) star outline. Leave empty for procedural gray star.
@export var popup_star_empty_texture: Texture2D = null
@export var popup_star_color: Color = Color(1.0, 0.85, 0.2)
@export var popup_star_empty_color: Color = Color(0.28, 0.28, 0.32)
@export var popup_star_size: Vector2 = Vector2(88, 88)

@export_group("Visual - Achievement Button")
## Optional PNG for the continue button. Leave empty for procedural amber button.
@export var popup_button_texture: Texture2D = null
@export var popup_button_color: Color = Color(0.88, 0.58, 0.08)
@export var popup_button_text: String = "Lanjutkan"

@export_group("Visual - Achievement Typography")
@export var popup_title_font: Font = null
@export var popup_body_font: Font = null
@export var popup_title_font_size: int = 68
@export var popup_score_font_size: int = 52
@export var popup_stat_font_size: int = 34
@export var popup_title_win_color: Color = Color(1.0, 0.88, 0.22)
@export var popup_title_lose_color: Color = Color(1.0, 0.65, 0.2)

## Optional custom background image for the result overlay.
# ─── Visual - Countdown Overlay ──────────────────────────────────────────────
@export_group("Visual - Countdown Overlay")
@export var countdown_font: Font = null
@export var countdown_font_size: int = 120
@export var countdown_font_color: Color = Color(1, 1, 1)
@export var countdown_outline_color: Color = Color.BLACK
@export var countdown_outline_size: int = 12
@export var countdown_steps_text: Array[String] = ["3", "2", "1", "Mulai!"]

# ─── Visual - Quit Dialog Overlay ───────────────────────────────────────────
@export_group("Visual - Quit Dialog Overlay")
@export var quit_dialog_message_text: String = "Apakah anda yakin?\nSeluruh progress minigame anda akan dianggap gagal!"
@export var quit_dialog_yes_button_text: String = "Iya"
@export var quit_dialog_no_button_text: String = "Tidak"
@export var quit_dialog_bg_texture: Texture2D = null
@export var quit_dialog_bg_color: Color = Color(0, 0, 0, 0.75)
@export var quit_dialog_card_texture: Texture2D = null
@export var quit_dialog_card_color: Color = Color(0.12, 0.14, 0.2, 0.95)
@export var quit_dialog_card_border_color: Color = Color(0.8, 0.3, 0.3, 0.8)
@export var quit_dialog_yes_button_texture: Texture2D = null
@export var quit_dialog_no_button_texture: Texture2D = null
@export var quit_dialog_font: Font = null
@export var quit_dialog_font_size: int = 46
@export var quit_dialog_font_color: Color = Color.WHITE

# ─── Visual - UI Controls ───────────────────────────────────────────────────
@export_group("Visual - UI Controls")
## Drag a PNG here to replace the in-game Pause (⏸) button icon.
@export var pause_button_texture: Texture2D = null

# ─── Custom Time Management ──────────────────────────────────────────────────
var max_game_time: float   = 30.0
var game_time_left: float  = 30.0
var visual_timer: Control  = null

# ─── [NEW FEATURE] Pause System ──────────────────────────────────────────────
var is_paused: bool = false
var pause_button: TextureButton = null
var pause_menu_instance: Node = null
var quit_dialog_instance: Node = null

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

	# Auto-start for direct scene testing (F6 / Play Scene)
	if get_tree().current_scene == self or get_parent() == get_tree().root:
		call_deferred("_auto_start_standalone")

func _auto_start_standalone() -> void:
	if not is_game_active:
		start_minigame(1, 40.0)
		activate_minigame()

var ui_layer: CanvasLayer = null

func _get_or_create_ui_layer() -> CanvasLayer:
	if ui_layer and is_instance_valid(ui_layer):
		return ui_layer
	ui_layer = CanvasLayer.new()
	ui_layer.name = "MinigameTopUILayer"
	ui_layer.layer = 100
	add_child(ui_layer)
	return ui_layer

func start_minigame(game_difficulty: int, time_limit: float = 30.0) -> void:
	difficulty = game_difficulty
	if time_limit > 0:
		max_game_time = time_limit
		game_time_left = time_limit
		has_time_limit = true
		_create_visual_timer()
	else:
		has_time_limit = false
	_create_pause_button()

func _create_pause_button() -> void:
	if pause_button:
		pause_button.queue_free()
		
	pause_button = TextureButton.new()
	pause_button.name = "PauseButton"
	
	# Load texture png if available
	var pause_path := "res://Assets/Images/pause_button.png"
	if ResourceLoader.exists(pause_path):
		var tex = load(pause_path)
		if tex and tex.get_width() > 0:
			pause_button.texture_normal = tex
			pause_button.ignore_texture_size = true
			pause_button.stretch_mode = TextureButton.STRETCH_SCALE
	
	pause_button.custom_minimum_size = Vector2(140, 140)
	
	# Top left anchor
	pause_button.anchor_left = 0.0
	pause_button.anchor_right = 0.0
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	pause_button.offset_left = 32.0
	pause_button.offset_top = 28.0
	pause_button.offset_right = 172.0
	pause_button.offset_bottom = 168.0
	
	pause_button.z_index = 100
	
	if pause_button_texture:
		var sb = StyleBoxTexture.new()
		sb.texture = pause_button_texture
		pause_button.add_theme_stylebox_override("normal", sb)
		pause_button.add_theme_stylebox_override("hover", sb)
		pause_button.add_theme_stylebox_override("pressed", sb)

	# Fallback procedural vector drawing if texture fails to render or load
	var draw_node = Control.new()
	draw_node.name = "FallbackDraw"
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(func():
		if pause_button_texture == null and (pause_button.texture_normal == null or not pause_button.texture_normal.get_width() > 0):
			var btn_size = draw_node.size
			var center = btn_size / 2.0
			var radius = min(btn_size.x, btn_size.y) / 2.0
			
			# Circular dark background
			draw_node.draw_circle(center, radius, Color(0.12, 0.15, 0.22, 0.95))
			draw_node.draw_arc(center, radius - 1, 0, TAU, 32, Color(0.8, 0.85, 0.9, 0.9), 6.0, true)
			
			# Pause bars (II)
			var bar_w = 14.0
			var bar_h = 56.0
			var gap = 14.0
			
			var bar1_rect = Rect2(center.x - gap/2.0 - bar_w, center.y - bar_h/2.0, bar_w, bar_h)
			var bar2_rect = Rect2(center.x + gap/2.0, center.y - bar_h/2.0, bar_w, bar_h)
			
			draw_node.draw_rect(bar1_rect, Color(0.95, 0.95, 0.95, 1.0))
			draw_node.draw_rect(bar2_rect, Color(0.95, 0.95, 0.95, 1.0))
	)
	pause_button.add_child(draw_node)
	
	pause_button.pressed.connect(_on_pause_button_pressed)
	_get_or_create_ui_layer().add_child(pause_button)

func _on_pause_button_pressed() -> void:
	if not is_game_active or is_paused:
		return
		
	_play_pause_button_boing_animation()

func _play_pause_button_boing_animation() -> void:
	if pause_button and is_instance_valid(pause_button):
		pause_button.pivot_offset = pause_button.size / 2.0
		
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		# Phase 1: Cute squash down (flat wide)
		tween.tween_property(pause_button, "scale", Vector2(1.25, 0.72), 0.07)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Phase 2: Stretch up boing (tall thin)
		tween.tween_property(pause_button, "scale", Vector2(0.78, 1.32), 0.12)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Phase 3: Bounce landing
		tween.tween_property(pause_button, "scale", Vector2(1.1, 0.88), 0.09)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		# Phase 4: Elastic return to original size
		tween.tween_property(pause_button, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			
		tween.tween_callback(func():
			pause_minigame()
		)
	else:
		pause_minigame()

# ─── [NEW FEATURE] Pause & Resume Logic ──────────────────────────────────────
func pause_minigame() -> void:
	is_paused = true
	if timer:
		timer.paused = true
		
	# Freeze physics & process loops on this minigame scene
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process_input(false)
	set_process_unhandled_input(false)
		
	var pause_scene = load("res://Scenes/Minigames/UI/PauseMenu.tscn")
	if pause_scene:
		pause_menu_instance = pause_scene.instantiate()
		pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		_get_or_create_ui_layer().add_child(pause_menu_instance)
		pause_menu_instance.z_index = 200
		
		if pause_menu_instance.has_signal("resume_pressed"):
			pause_menu_instance.resume_pressed.connect(_on_pause_resume)
		if pause_menu_instance.has_signal("settings_pressed"):
			pause_menu_instance.settings_pressed.connect(_on_pause_settings)
		if pause_menu_instance.has_signal("quit_pressed"):
			pause_menu_instance.quit_pressed.connect(_on_pause_quit)

func _on_pause_resume() -> void:
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	_start_resume_countdown()

# Virtual hooks — override in subclasses to pause/resume physics bodies around the countdown.
func _on_countdown_start() -> void:
	pass

func _on_countdown_end() -> void:
	pass

## The countdown overlay every minigame plays before the first input.
@export var countdown_scene: PackedScene = preload("res://Scenes/Minigames/UI/MinigameCountdown.tscn")

func _play_countdown() -> void:
	var overlay: MinigameCountdown = countdown_scene.instantiate()
	add_child(overlay)
	overlay.configure(countdown_steps_text, countdown_font, countdown_font_size,
		countdown_font_color, countdown_outline_color, countdown_outline_size)
	await overlay.play()

func _start_resume_countdown() -> void:
	# Restore process mode NOW so that await/timers inside this coroutine can run.
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process_input(false)
	set_process_unhandled_input(false)

	_on_countdown_start()
	await _play_countdown()
	
	# Countdown done — NOW unlock everything.
	_on_countdown_end()
	is_paused = false
	set_process_input(true)
	set_process_unhandled_input(true)
	if timer:
		timer.paused = false

func _on_pause_settings() -> void:
	var settings_overlay = preload("res://Scripts/Pengaturan.gd").new()
	_get_or_create_ui_layer().add_child(settings_overlay)
	await settings_overlay.back_pressed

func _on_pause_quit() -> void:
	if pause_menu_instance:
		pause_menu_instance.hide()
	_show_quit_confirmation()

## The "are you sure you want to quit" confirmation.
@export var quit_dialog_scene: PackedScene = preload("res://Scenes/Minigames/UI/QuitConfirmDialog.tscn")

func _show_quit_confirmation() -> void:
	if quit_dialog_instance:
		quit_dialog_instance.queue_free()

	var dialog: QuitConfirmDialog = quit_dialog_scene.instantiate()
	quit_dialog_instance = dialog
	add_child(dialog)
	dialog.configure(quit_dialog_message_text, quit_dialog_yes_button_text,
		quit_dialog_no_button_text, quit_dialog_bg_texture, quit_dialog_bg_color,
		quit_dialog_card_texture, quit_dialog_card_color, quit_dialog_card_border_color,
		quit_dialog_yes_button_texture, quit_dialog_no_button_texture,
		quit_dialog_font, quit_dialog_font_size, quit_dialog_font_color)

	dialog.confirmed.connect(func():
		quit_dialog_instance.queue_free()
		quit_dialog_instance = null
		if pause_menu_instance:
			pause_menu_instance.queue_free()
			pause_menu_instance = null
		is_paused = false
		abandon_game()
	)
	dialog.cancelled.connect(func():
		quit_dialog_instance.queue_free()
		quit_dialog_instance = null
		if pause_menu_instance:
			pause_menu_instance.show()
	)

func _create_visual_timer() -> void:
	if visual_timer:
		visual_timer.queue_free()
		
	visual_timer = Control.new()
	visual_timer.name = "VisualTimer"
	visual_timer.custom_minimum_size = Vector2(140, 140)
	visual_timer.z_index = 100
	_get_or_create_ui_layer().add_child(visual_timer)
	
	# Position in top-right corner
	visual_timer.anchor_left = 1.0
	visual_timer.anchor_right = 1.0
	visual_timer.anchor_top = 0.0
	visual_timer.anchor_bottom = 0.0
	visual_timer.offset_left = -172.0
	visual_timer.offset_top = 28.0
	visual_timer.offset_right = -32.0
	visual_timer.offset_bottom = 168.0
	visual_timer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	
	visual_timer.draw.connect(_on_visual_timer_draw)

func _process(delta: float) -> void:
	if is_game_active and has_time_limit and not is_paused:
		game_time_left -= delta
		if game_time_left <= 0.0:
			game_time_left = 0.0
			lose_game()
		if visual_timer:
			visual_timer.queue_redraw()

func apply_time_penalty(seconds: float) -> void:
	if not is_game_active or not has_time_limit or is_paused:
		return
	game_time_left -= seconds
	if game_time_left <= 0.0:
		game_time_left = 0.0
		lose_game()

func _get_active_tutorial_title() -> String:
	if tutorial_title != "":
		return tutorial_title
	var s_name = ""
	if get_script() and get_script().resource_path != "":
		s_name = get_script().resource_path.get_file().get_basename()
	if s_name == "" or s_name == "BaseMinigame":
		s_name = name
	match s_name:
		"PilihanGanda": return "🎓 Pilihan Ganda"
		"Menjodohkan": return "🔗 Menjodohkan"
		"Password": return "🔢 Password"
		"Variabel": return "🧮 Variabel"
		"MainBola": return "⚽ Tendangan Penalti"
		"Badminton": return "🏸 Badminton"
		"BuatBatik": return "🎨 Membuat Batik"
		"LombaMenari": return "💃 Lomba Menari"
		_: return "🎮 Tutorial Minigame"

func _get_active_tutorial_instructions() -> String:
	if tutorial_instructions != "":
		return tutorial_instructions
	var s_name = ""
	if get_script() and get_script().resource_path != "":
		s_name = get_script().resource_path.get_file().get_basename()
	if s_name == "" or s_name == "BaseMinigame":
		s_name = name
	match s_name:
		"PilihanGanda": return "Baca pertanyaan dengan teliti, lalu pilih satu jawaban yang paling benar dari pilihan yang tersedia.\n\nJawaban salah akan mengurangi waktu 3 detik!"
		"Menjodohkan": return "Geser kartu pertanyaan dan jawaban menggunakan tombol panah kiri/kanan.\n\nPasangkan pertanyaan dengan jawaban yang benar, lalu tekan tombol Kunci (🔒).\n\nSetelah semua pasangan terkunci, tekan tombol Kirim untuk menyelesaikan!"
		"Password": return "Selesaikan soal matematika (penjumlahan/pengurangan) yang ditampilkan di layar.\n\nGunakan keypad angka untuk memasukkan jawaban.\n\nJawaban benar akan lanjut ke soal berikutnya!"
		"Variabel": return "Temukan nilai variabel yang belum diketahui dari persamaan yang diberikan.\n\nMasukkan jawaban menggunakan numpad, lalu tekan tombol Kirim.\n\nSetiap jawaban benar akan menampilkan nilai variabel yang tersembunyi!"
		"MainBola": return "Geser jari ke arah gawang untuk menendang bola.\n\nArahkan tendangan ke kotak target yang bergerak di dalam gawang.\n\nCetak gol sebanyak-banyaknya sebelum kesempatan habis!"
		"Badminton": return "Geser jari di area bawah layar untuk menggerakkan pemukul.\n\nPantulkan shuttlecock melewati lawan untuk mencetak poin.\n\nRaih skor target lebih dulu untuk menang!"
		"BuatBatik": return "Seret alat-alat batik ke kanvas dalam urutan yang benar:\nPensil → Canting → Pewarna → Kompor\n\nTahan alat untuk melihat deskripsinya.\n\nUrutan salah akan mengurangi waktu!"
		"LombaMenari": return "Ketuk tombol panah yang sesuai saat not musik memasuki zona target di layar.\n\nTekan tepat waktu untuk mendapatkan skor lebih tinggi!\n\nRaih skor target sebelum waktu habis untuk menang!"
		_: return "Selesaikan minigame dengan baik!"

func activate_minigame() -> void:
	var active_title = _get_active_tutorial_title()
	var active_instructions = _get_active_tutorial_instructions()
	if active_title != "" and GameSettings.minigame_tutorial_enabled:
		var tut_scene = load("res://Scenes/Minigames/UI/MinigameTutorial.tscn")
		var tutorial = tut_scene.instantiate() if tut_scene else preload("res://Scripts/Minigames/UI/MinigameTutorial.gd").new()
		tutorial.setup(active_title, active_instructions)
		_get_or_create_ui_layer().add_child(tutorial)
		await tutorial.tutorial_finished
		await _play_countdown()
	is_game_active = true

var result_subtitle: String = ""

func win_game() -> void:
	is_game_active = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if pause_button:
		pause_button.disabled = true
		pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if timer:
		timer.stop()
	set_process_input(false)
	_show_result_overlay(true, result_subtitle)

func abandon_game() -> void:
	if not is_game_active:
		return
	is_game_active = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if pause_button:
		pause_button.disabled = true
		pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if timer:
		timer.stop()
	set_process_input(false)
	_show_result_overlay(false, result_subtitle)

func lose_game() -> void:
	if not is_game_active:
		return
	is_game_active = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if pause_button:
		pause_button.disabled = true
		pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if timer:
		timer.stop()
	set_process_input(false)
	
	# Trigger answer reveal on child minigame if implemented
	if has_method("reveal_answers"):
		await call("reveal_answers")
		await get_tree().create_timer(1.2).timeout
	else:
		# 1.2 seconds reveal delay before result pops up
		await get_tree().create_timer(1.2).timeout
		
	# Dynamic win threshold check based on difficulty (Grade 7 = 1, Grade 8 = 2, Grade 9 = 3)
	var win_threshold = get_target_win_score()
	var current_score: int = 0
	if "score" in self:
		current_score = self.score
		
	if current_score >= win_threshold:
		win_game()
	else:
		_show_result_overlay(false, result_subtitle)


func get_target_win_score() -> int:
	var base_target = 1
	if difficulty == 2:
		base_target = 2
	elif difficulty >= 3:
		# If a game has max_score (e.g. quiz is 3 or matching is 4), target fits.
		base_target = 3
	return base_target


func _do_win() -> void:
	print("BaseMinigame emitting minigame_won signal!")
	minigame_won.emit()
	if get_tree().current_scene == self or get_parent() == get_tree().root:
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()

func _do_lose() -> void:
	print("BaseMinigame emitting minigame_lost signal!")
	minigame_lost.emit()
	if get_tree().current_scene == self or get_parent() == get_tree().root:
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()

func _calculate_stars(score: int, max_score: int, is_win: bool) -> int:
	if not is_win:
		return 0
	if max_score <= 0:
		return 1  # Win with no score tracking = 1 star minimum
	var ratio = float(score) / float(max_score)
	if ratio >= 0.80:
		return 3
	elif ratio >= 0.50:
		return 2
	return 1

func _draw_star_polygon(parent: Control, size: Vector2, filled: bool) -> Control:
	# Returns a Control that draws a 5-pointed star via _draw()
	var star_ctrl = Control.new()
	star_ctrl.custom_minimum_size = size
	var star_color = popup_star_color if filled else popup_star_empty_color
	star_ctrl.draw.connect(func():
		var pts = PackedVector2Array()
		var cx = size.x / 2.0
		var cy = size.y / 2.0
		var outer = min(cx, cy) * 0.92
		var inner = outer * 0.42
		for i in range(10):
			var angle = deg_to_rad(i * 36.0 - 90.0)
			var r = outer if i % 2 == 0 else inner
			pts.append(Vector2(cx + r * cos(angle), cy + r * sin(angle)))
		if filled:
			star_ctrl.draw_colored_polygon(pts, star_color)
		else:
			# Draw outline only
			star_ctrl.draw_polyline(PackedVector2Array(pts) + PackedVector2Array([pts[0]]), star_color, 3.0, true)
	)
	return star_ctrl

func _show_result_overlay(is_win: bool, custom_subtitle: String = "") -> void:
	process_mode = Node.PROCESS_MODE_INHERIT

	# Gather score data from the child minigame
	var mg_score: int = -1
	var mg_max_score: int = -1
	if "score" in self:
		mg_score = self.score
	if "max_score" in self:
		mg_max_score = self.max_score

	# Gather stat deltas from last result if available
	# These are optionally set by individual minigames as: last_stat_delta, last_energy_delta, last_mood_delta
	var stat_delta: float = 0.0
	var energy_delta: float = 0.0
	var mood_delta: float = 0.0
	var mg_category: String = ""
	if "last_stat_delta" in self: stat_delta = self.last_stat_delta
	if "last_energy_delta" in self: energy_delta = self.last_energy_delta
	if "last_mood_delta" in self: mood_delta = self.last_mood_delta
	if "minigame_category" in self: mg_category = self.minigame_category

	var stars = _calculate_stars(mg_score, mg_max_score, is_win)

	# Friendly failure titles (kept from original)
	var fail_titles = [
		"Belum Tepat, Coba Lagi Lain Kali!",
		"Jangan Menyerah, Coba Lagi Lain Kali! 🔥",
		"Yuk! Terus Berlatih agar Berhasil! ✨",
		"Ingat dan Kamu Pasti Bisa! 🚀"
	]
	var fail_title = fail_titles[randi() % fail_titles.size()]
	var title_text = win_title_text if is_win else (lose_title_text if lose_title_text != "" else fail_title)

	# ── Canvas Layer (layer 999, covers everything) ───────────────────────────
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ResultCanvasLayer"
	canvas_layer.layer = 999
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)

	# ── Dim Overlay ───────────────────────────────────────────────────────────
	var dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(popup_dim_color.r, popup_dim_color.g, popup_dim_color.b, 0.0)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.add_child(dim)

	# ── Center Container ──────────────────────────────────────────────────────
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.add_child(center)

	# ── Achievement Card ──────────────────────────────────────────────────────
	var card = PanelContainer.new()
	var viewport_w = get_viewport_rect().size.x
	card.custom_minimum_size = Vector2(clampf(viewport_w * 0.78, 340, 820), 0)

	if popup_card_texture:
		var sb = StyleBoxTexture.new()
		sb.texture = popup_card_texture
		sb.content_margin_left = 32
		sb.content_margin_top = 28
		sb.content_margin_right = 32
		sb.content_margin_bottom = 28
		card.add_theme_stylebox_override("panel", sb)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = popup_card_color
		sb.border_color = popup_border_color
		sb.border_width_left = 4
		sb.border_width_top = 4
		sb.border_width_right = 4
		sb.border_width_bottom = 4
		sb.corner_radius_top_left = 22
		sb.corner_radius_top_right = 22
		sb.corner_radius_bottom_left = 22
		sb.corner_radius_bottom_right = 22
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 14
		sb.content_margin_left = 32
		sb.content_margin_top = 28
		sb.content_margin_right = 32
		sb.content_margin_bottom = 28
		card.add_theme_stylebox_override("panel", sb)

	card.modulate.a = 0.0
	card.scale = Vector2(0.75, 0.75)
	center.add_child(card)

	# ── Card Content VBox ─────────────────────────────────────────────────────
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", popup_title_font_size)
	title_lbl.add_theme_color_override("font_color", popup_title_win_color if is_win else popup_title_lose_color)
	title_lbl.add_theme_constant_override("outline_size", 8)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	if popup_title_font: title_lbl.add_theme_font_override("font", popup_title_font)
	title_lbl.modulate.a = 0.0
	vbox.add_child(title_lbl)

	# Stars Row
	var stars_hbox = HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(stars_hbox)

	var star_nodes: Array = []
	for i in range(3):
		var filled = (i < stars)
		var star_node: Control
		if filled and popup_star_texture:
			var tr = TextureRect.new()
			tr.texture = popup_star_texture
			tr.custom_minimum_size = popup_star_size
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star_node = tr
		elif not filled and popup_star_empty_texture:
			var tr = TextureRect.new()
			tr.texture = popup_star_empty_texture
			tr.custom_minimum_size = popup_star_size
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star_node = tr
		else:
			star_node = _draw_star_polygon(stars_hbox, popup_star_size, filled)
		star_node.modulate.a = 0.0
		star_node.scale = Vector2(0.3, 0.3)
		star_node.pivot_offset = popup_star_size / 2.0
		stars_hbox.add_child(star_node)
		star_nodes.append(star_node)

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Minigame name
	var game_name_text = _get_active_tutorial_title()
	var name_lbl = Label.new()
	name_lbl.text = game_name_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", popup_stat_font_size + 4)
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	if popup_body_font: name_lbl.add_theme_font_override("font", popup_body_font)
	name_lbl.modulate.a = 0.0
	vbox.add_child(name_lbl)

	# Score label (only shown when score data available)
	if mg_score >= 0 and mg_max_score > 0:
		var score_hbox = HBoxContainer.new()
		score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		score_hbox.add_theme_constant_override("separation", 8)
		var score_prefix = Label.new()
		score_prefix.text = "Skor:"
		score_prefix.add_theme_font_size_override("font_size", popup_score_font_size)
		score_prefix.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		if popup_body_font: score_prefix.add_theme_font_override("font", popup_body_font)
		score_hbox.add_child(score_prefix)
		var score_val = Label.new()
		score_val.text = "%d / %d" % [mg_score, mg_max_score]
		score_val.add_theme_font_size_override("font_size", popup_score_font_size)
		score_val.add_theme_color_override("font_color", popup_title_win_color if is_win else Color(0.8, 0.8, 0.8))
		score_val.add_theme_constant_override("outline_size", 5)
		score_val.add_theme_color_override("font_outline_color", Color.BLACK)
		if popup_body_font: score_val.add_theme_font_override("font", popup_body_font)
		score_hbox.add_child(score_val)
		score_hbox.modulate.a = 0.0
		vbox.add_child(score_hbox)

	# Category badge (if we know the category)
	if mg_category != "":
		var badge_colors = {
			"Akademis": Color(0.16, 0.27, 1.0),
			"SeniBudaya": Color(0.0, 0.6, 0.25),
			"Olahraga": Color(0.75, 0.1, 0.1)
		}
		var badge_icons = {"Akademis": "📚", "SeniBudaya": "🎨", "Olahraga": "⚽"}
		var badge_lbl = Label.new()
		badge_lbl.text = " %s %s " % [badge_icons.get(mg_category, "🎮"), mg_category]
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", popup_stat_font_size)
		badge_lbl.add_theme_color_override("font_color", Color.WHITE)
		if popup_body_font: badge_lbl.add_theme_font_override("font", popup_body_font)
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = badge_colors.get(mg_category, Color(0.3, 0.3, 0.4))
		badge_style.corner_radius_top_left = 10
		badge_style.corner_radius_top_right = 10
		badge_style.corner_radius_bottom_left = 10
		badge_style.corner_radius_bottom_right = 10
		badge_lbl.add_theme_stylebox_override("normal", badge_style)
		badge_lbl.modulate.a = 0.0
		vbox.add_child(badge_lbl)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Stat Deltas
	var stat_entries: Array[Dictionary] = []
	var stat_labels_map = {"Akademis": "Akademis 📚", "SeniBudaya": "Seni Budaya 🎨", "Olahraga": "Olahraga ⚽"}
	if stat_delta != 0.0 and mg_category != "":
		var label_text = stat_labels_map.get(mg_category, mg_category)
		stat_entries.append({"text": "%s%d %s" % ["+" if stat_delta > 0 else "", int(stat_delta), label_text], "positive": stat_delta > 0})
	if energy_delta != 0.0:
		stat_entries.append({"text": "%s%d Energy ⚡" % ["+" if energy_delta > 0 else "", int(energy_delta)], "positive": energy_delta > 0})
	if mood_delta != 0.0:
		stat_entries.append({"text": "%s%d Mood 😊" % ["+" if mood_delta > 0 else "", int(mood_delta)], "positive": mood_delta > 0})

	var delta_nodes: Array = []
	for entry in stat_entries:
		var dl = Label.new()
		dl.text = entry["text"]
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", popup_stat_font_size)
		dl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5) if entry["positive"] else Color(0.95, 0.35, 0.35))
		dl.add_theme_constant_override("outline_size", 4)
		dl.add_theme_color_override("font_outline_color", Color.BLACK)
		if popup_body_font: dl.add_theme_font_override("font", popup_body_font)
		dl.modulate.a = 0.0
		vbox.add_child(dl)
		delta_nodes.append(dl)

	# Continue Button
	var btn: BaseButton
	if popup_button_texture:
		var tb = TextureButton.new()
		tb.texture_normal = popup_button_texture
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.custom_minimum_size = Vector2(280, 90)
		btn = tb
	else:
		var b = Button.new()
		b.text = popup_button_text
		b.custom_minimum_size = Vector2(280, 90)
		b.add_theme_font_size_override("font_size", popup_stat_font_size + 4)
		b.add_theme_color_override("font_color", Color.WHITE)
		if popup_body_font: b.add_theme_font_override("font", popup_body_font)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = popup_button_color
		btn_style.corner_radius_top_left = 14
		btn_style.corner_radius_top_right = 14
		btn_style.corner_radius_bottom_left = 14
		btn_style.corner_radius_bottom_right = 14
		b.add_theme_stylebox_override("normal", btn_style)
		var btn_hover = btn_style.duplicate() as StyleBoxFlat
		btn_hover.bg_color = popup_button_color.lightened(0.18)
		b.add_theme_stylebox_override("hover", btn_hover)
		btn = b

	var btn_center = CenterContainer.new()
	btn_center.modulate.a = 0.0
	btn_center.add_child(btn)
	vbox.add_child(btn_center)

	# ── Animation sequence ────────────────────────────────────────────────────
	# 1. Dim overlay fades in
	var tw_dim = get_tree().create_tween()
	tw_dim.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_dim.tween_property(dim, "color", Color(popup_dim_color.r, popup_dim_color.g, popup_dim_color.b, popup_dim_color.a), 0.35)
	await tw_dim.finished

	# 2. Card bounces in
	var tw_card = get_tree().create_tween().set_parallel(true)
	tw_card.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_card.tween_property(card, "modulate:a", 1.0, 0.25)
	tw_card.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_card.finished

	# 3. Title fades in
	var tw_title = get_tree().create_tween()
	tw_title.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_title.tween_property(title_lbl, "modulate:a", 1.0, 0.2)
	await tw_title.finished

	# 4. Stars pop in one by one
	for star_node in star_nodes:
		var tw_star = get_tree().create_tween().set_parallel(true)
		tw_star.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_star.tween_property(star_node, "modulate:a", 1.0, 0.15)
		tw_star.tween_property(star_node, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw_star.finished
		var tw_settle = get_tree().create_tween()
		tw_settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_settle.tween_property(star_node, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await tw_settle.finished

	# 5. Score, badge, and deltas fade in sequentially
	var fade_nodes: Array = [name_lbl]
	# Add score hbox if it exists in vbox
	for child in vbox.get_children():
		if child is HBoxContainer and child != stars_hbox:
			fade_nodes.append(child)
			break
	# badge
	for child in vbox.get_children():
		if child is Label and child != title_lbl and child != name_lbl and child.get_theme_stylebox("normal") != null:
			fade_nodes.append(child)
			break
	fade_nodes.append_array(delta_nodes)
	fade_nodes.append(btn_center)

	for fn in fade_nodes:
		if is_instance_valid(fn):
			var tw_f = get_tree().create_tween()
			tw_f.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw_f.tween_property(fn, "modulate:a", 1.0, 0.18)
			await tw_f.finished
			await get_tree().create_timer(0.04).timeout

	# 6. Wait for player to press continue
	await btn.pressed

	# 7. Fade out everything
	var tw_out = get_tree().create_tween().set_parallel(true)
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.tween_property(card, "modulate:a", 0.0, 0.2)
	tw_out.tween_property(dim, "modulate:a", 0.0, 0.25)
	await tw_out.finished

	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()

	# 8. Emit win/lose signal
	if is_win:
		_do_win()
	else:
		_do_lose()


func _on_timer_timeout() -> void:
	lose_game()

func _on_visual_timer_draw() -> void:
	if not is_game_active or not visual_timer:
		return
		
	var center = visual_timer.size / 2
	var radius = min(visual_timer.size.x, visual_timer.size.y) / 2 - 2
	
	# 1. Draw base clock face
	visual_timer.draw_circle(center, radius, Color(0.95, 0.95, 0.95))
	visual_timer.draw_arc(center, radius, 0, TAU, 32, Color(0.12, 0.12, 0.12), 6.0, true)
	
	# 2. Draw elapsed blackout slice clockwise
	var elapsed = max_game_time - game_time_left
	if elapsed > 0.001 and max_game_time > 0:
		var angle_to = (elapsed / max_game_time) * 360.0
		_draw_circle_slice(center, radius - 1, 0, angle_to, Color(0.12, 0.12, 0.12))

func _draw_circle_slice(center: Vector2, radius: float, angle_from: float, angle_to: float, color: Color) -> void:
	var nb_points = 32
	var points = PackedVector2Array()
	points.append(center)
	
	for i in range(nb_points + 1):
		var angle_point = deg_to_rad(angle_from + i * (angle_to - angle_from) / nb_points - 90.0)
		points.append(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
		
	visual_timer.draw_polygon(points, PackedColorArray([color]))

func _flash_box_color(node: Control, flash_color: Color, duration: float = 0.45) -> void:
	if not node or not is_instance_valid(node):
		return
		
	var original_style = node.get_theme_stylebox("panel")
	if original_style and original_style is StyleBoxFlat:
		var flash_style: StyleBoxFlat = (original_style as StyleBoxFlat).duplicate()
		flash_style.bg_color = flash_color
		node.add_theme_stylebox_override("panel", flash_style)
		
		# Fade back to normal color smooth
		var tween = create_tween()
		tween.tween_property(flash_style, "bg_color", (original_style as StyleBoxFlat).bg_color, duration)
		tween.tween_callback(func():
			if is_instance_valid(node):
				node.add_theme_stylebox_override("panel", original_style)
		)

func _play_wiggle_animation(node: Control) -> void:
	if not node:
		return
	# Flash background box red on wrong answer
	_flash_box_color(node, Color(1.0, 0.75, 0.75), 0.45)

	var original_pos = node.position
	var tween = create_tween()
	var shake_offset = 8.0
	var duration = 0.05
	
	# Shake left and right rapidly
	tween.tween_property(node, "position:x", original_pos.x - shake_offset, duration)
	tween.tween_property(node, "position:x", original_pos.x + shake_offset, duration)
	tween.tween_property(node, "position:x", original_pos.x - shake_offset, duration)
	tween.tween_property(node, "position:x", original_pos.x + shake_offset, duration)
	tween.tween_property(node, "position:x", original_pos.x, duration)

func _play_jump_animation(node: Control) -> void:
	if not node or not is_instance_valid(node):
		return

	# Flash background box green on correct answer
	_flash_box_color(node, Color(0.75, 0.95, 0.78), 0.45)

	# Force update node pivot to exact center of node size
	node.pivot_offset = node.size / 2.0
	
	# Scale animation tween
	var tween = create_tween()
	
	# Phase 1: Pre-jump squash down (flatten wide)
	tween.tween_property(node, "scale", Vector2(1.18, 0.72), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 2: Stretch jump (tall & thin)
	tween.tween_property(node, "scale", Vector2(0.82, 1.35), 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 3: Landing bounce (squash wide again)
	tween.tween_property(node, "scale", Vector2(1.12, 0.85), 0.10)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Phase 4: Elastic return to standard scale (1.0, 1.0)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.12)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
