extends CanvasLayer

# --- Cheat State Variables ---
var cheat_auto_win: bool = false
var cheat_auto_lose: bool = false
var cheat_force_outcome: String = "" # "", "win", "lose"

# --- Touch Gesture State ---
var _touch_taps: int = 0
var _last_touch_time: float = 0.0
const GESTURE_TIMEOUT: float = 2.0
const GESTURE_TAPS_REQUIRED: int = 5

# --- UI References ---
var debug_ui_root: Control
var toggle_btn: Button
var main_panel: PanelContainer
var log_text_label: Label
var log_scroll: ScrollContainer

# --- Active Standalone Minigame ---
var active_minigame: Node = null
var minigame_canvas: CanvasLayer = null

# --- Tab Panels ---
var panels: Dictionary = {}
var tab_buttons: Dictionary = {}

# --- Default Students Data (copied from student_card.gd for quick approval cheat) ---
const DEFAULT_STUDENTS = [
	{
		"id": 1,
		"name": "Marcel",
		"portrait": "res://Assets/Images/MuridPotrait/Marcel.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid1.jpg",
		"kepribadian1": 60.0,   # Mood
		"kepribadian2": 55.0,   # Energy
		"akademis1": 28.0,      # Akademis (Specialty)
		"akademis2": 48.0,      # Seni Budaya
		"akademis3": 38.0,      # Olahraga
		"target_akademis1": 52.0,
		"target_akademis2": 60.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 40.0,
		"hobby_category": "Akademis",
		"personality": "Tekun",
		"quirk": "Kutu Buku",
		"persona": "Persona Tekun",
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki"
	},
	{
		"id": 2,
		"name": "Doni",
		"portrait": "res://Assets/Images/MuridPotrait/Doni.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid2.jpg",
		"kepribadian1": 55.0,   # Mood
		"kepribadian2": 55.0,   # Energy
		"akademis1": 38.0,      # Akademis
		"akademis2": 22.0,      # Seni Budaya
		"akademis3": 33.0,      # Olahraga (Specialty)
		"target_akademis1": 50.0,
		"target_akademis2": 40.0,
		"target_akademis3": 51.0,
		"target_kepribadian1": 40.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Olahraga",
		"personality": "Aktif",
		"quirk": "Semangat Juang",
		"persona": "Persona Aktif",
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki"
	},
	{
		"id": 3,
		"name": "Andi",
		"portrait": "res://Assets/Images/MuridPotrait/Andi.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid3.jpg",
		"kepribadian1": 60.0,   # Mood
		"kepribadian2": 60.0,   # Energy
		"akademis1": 48.0,      # Akademis
		"akademis2": 55.0,      # Seni Budaya (Specialty)
		"akademis3": 32.0,      # Olahraga
		"target_akademis1": 60.0,
		"target_akademis2": 64.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 60.0,
		"target_kepribadian2": 55.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Penasaran",
		"persona": "Persona Kreatif",
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki"
	},
	{
		"id": 4,
		"name": "Citra",
		"portrait": "res://Assets/Images/MuridPotrait/Citra.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid4.jpg",
		"kepribadian1": 35.0,   # Mood
		"kepribadian2": 60.0,   # Energy
		"akademis1": 28.0,      # Akademis
		"akademis2": 25.0,      # Seni Budaya
		"akademis3": 15.0,      # Olahraga (Specialty)
		"target_akademis1": 40.0,
		"target_akademis2": 43.0,
		"target_akademis3": 39.0,
		"target_kepribadian1": 35.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "Olahraga",
		"personality": "Seni Dalam Kesunyian",
		"quirk": "Penyendiri",
		"persona": "Persona Pendiam",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	}
]

func _ready() -> void:
	# Ensure the debug manager runs always, even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128 # Above everything (Transition is 100)
	
	# Construct programmatic UI
	_build_ui()
	log_message("Debug System Initialized. Press '~' or F1, or tap top-right 5x to toggle.")

func _input(event: InputEvent) -> void:
	# 1. Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F1:
			toggle_overlay()
			get_viewport().set_input_as_handled()
			return
			
	# 2. Mobile touch gesture (5 taps in top-right region)
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	   (event is InputEventScreenTouch and event.pressed):
		var pos = event.position
		var viewport_size = get_viewport().get_visible_rect().size
		if pos.x > viewport_size.x - 200 and pos.y < 200:
			var now = Time.get_ticks_msec() / 1000.0
			if now - _last_touch_time > GESTURE_TIMEOUT:
				_touch_taps = 1
			else:
				_touch_taps += 1
			_last_touch_time = now
			
			if _touch_taps >= GESTURE_TAPS_REQUIRED:
				_touch_taps = 0
				toggle_overlay()
				get_viewport().set_input_as_handled()

func toggle_overlay() -> void:
	if not debug_ui_root:
		return
	debug_ui_root.visible = not debug_ui_root.visible
	if debug_ui_root.visible:
		# Update values inside panels on open
		_refresh_ui_fields()
		log_message("Debug Menu opened.")
	else:
		log_message("Debug Menu closed.")

func log_message(msg: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var formatted = "[%s] %s\n" % [timestamp, msg]
	print("🐛 [DEBUG_TOOL]: ", msg)
	if log_text_label:
		log_text_label.text += formatted
		# Auto-scroll to bottom
		call_deferred("_scroll_log_to_bottom")

func _scroll_log_to_bottom() -> void:
	if log_scroll:
		log_scroll.scroll_vertical = 999999

# --- UI Builder ---
func _build_ui() -> void:
	# Root container
	debug_ui_root = Control.new()
	debug_ui_root.name = "DebugOverlayContainer"
	debug_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_ui_root.visible = false
	add_child(debug_ui_root)
	
	# Semi-transparent dark background
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.06, 0.1, 0.92)
	debug_ui_root.add_child(backdrop)
	
	# Mini Toggle Button (Floating visual helper, always visible unless closed)
	toggle_btn = Button.new()
	toggle_btn.text = "🔧 DBG"
	toggle_btn.custom_minimum_size = Vector2(160, 80)
	toggle_btn.position = Vector2(30, 30)
	toggle_btn.add_theme_font_size_override("font_size", 21)
	toggle_btn.pressed.connect(toggle_overlay)
	
	var style_toggle = StyleBoxFlat.new()
	style_toggle.bg_color = Color(0.2, 0.35, 0.5, 0.7)
	style_toggle.corner_radius_top_left = 12
	style_toggle.corner_radius_top_right = 12
	style_toggle.corner_radius_bottom_left = 12
	style_toggle.corner_radius_bottom_right = 12
	style_toggle.border_width_left = 2
	style_toggle.border_width_top = 2
	style_toggle.border_width_right = 2
	style_toggle.border_width_bottom = 2
	style_toggle.border_color = Color(1.0, 1.0, 1.0, 0.5)
	toggle_btn.add_theme_stylebox_override("normal", style_toggle)
	toggle_btn.add_theme_stylebox_override("hover", style_toggle)
	toggle_btn.add_theme_stylebox_override("focus", style_toggle)
	add_child(toggle_btn)
	
	# Main Panel Centered Margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 140)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	debug_ui_root.add_child(margin)
	
	# Outer VBox Layout
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 25)
	margin.add_child(outer_vbox)
	
	# Header HBox
	var header = HBoxContainer.new()
	outer_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "🔧 PLAYTESTING DEBUG TOOLS 🔧"
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = " ❌ Close "
	close_btn.custom_minimum_size = Vector2(180, 75)
	close_btn.add_theme_font_size_override("font_size", 23)
	close_btn.pressed.connect(toggle_overlay)
	header.add_child(close_btn)
	
	# Horizontal Tab Bar
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(tabs_hbox)
	
	var tab_names = ["General", "Students", "Minigames", "Scenes", "Logs"]
	for tab in tab_names:
		var btn = Button.new()
		btn.text = tab
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func(): _switch_tab(tab))
		tabs_hbox.add_child(btn)
		tab_buttons[tab] = btn
	
	# Panels Content Area (Stacked inside a VBox)
	var content_area = PanelContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_area)
	
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.08, 0.1, 0.15, 0.98)
	content_style.border_width_left = 3
	content_style.border_width_top = 3
	content_style.border_width_right = 3
	content_style.border_width_bottom = 3
	content_style.border_color = Color(0.2, 0.45, 0.75)
	content_style.corner_radius_top_left = 16
	content_style.corner_radius_top_right = 16
	content_style.corner_radius_bottom_left = 16
	content_style.corner_radius_bottom_right = 16
	content_area.add_theme_stylebox_override("panel", content_style)
	
	# Build individual panels
	_build_general_panel(content_area)
	_build_students_panel(content_area)
	_build_minigames_panel(content_area)
	_build_scenes_panel(content_area)
	_build_logs_panel(content_area)
	
	# Default tab selection
	_switch_tab("General")

func _switch_tab(tab_name: String) -> void:
	for tab in panels:
		panels[tab].visible = (tab == tab_name)
		
	# Highlight active button
	for tab in tab_buttons:
		var btn = tab_buttons[tab] as Button
		var style = StyleBoxFlat.new()
		if tab == tab_name:
			style.bg_color = Color(0.2, 0.5, 0.9)
		else:
			style.bg_color = Color(0.12, 0.16, 0.24)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_stylebox_override("pressed", style)
		
	log_message("Switched to tab: " + tab_name)
	_refresh_ui_fields()

# --- General Cheat Tab Panel ---
var _lbl_week: Label
var _lbl_money: Label
var _lbl_speed: Label
var _btn_tutorial_lobby: Button
var _btn_tutorial_minigames: Button

func _build_general_panel(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	panels["General"] = scroll
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_top", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.add_theme_constant_override("margin_bottom", 30)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 35)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)

	# Row 0: One-click playtest state (most-used action, so it goes first)
	var btn_seed = Button.new()
	btn_seed.text = " ⚡ Seed Playtest State "
	btn_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seed.custom_minimum_size = Vector2(0, 95)
	btn_seed.add_theme_font_size_override("font_size", 23)
	btn_seed.pressed.connect(_seed_playtest_state)
	vbox.add_child(btn_seed)

	var sep_seed = HSeparator.new()
	vbox.add_child(sep_seed)

	# Row 1: Week tracking & Grade
	var grp_week = VBoxContainer.new()
	grp_week.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_week)
	
	var row_week_info = HBoxContainer.new()
	grp_week.add_child(row_week_info)
	
	var lbl_w_title = Label.new()
	lbl_w_title.text = "Minggu & Kelas Progression: "
	lbl_w_title.add_theme_font_size_override("font_size", 26)
	row_week_info.add_child(lbl_w_title)
	
	_lbl_week = Label.new()
	_lbl_week.text = "Minggu 1 (Grade 7)"
	_lbl_week.add_theme_font_size_override("font_size", 26)
	_lbl_week.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	row_week_info.add_child(_lbl_week)
	
	# Week buttons Grid (2x2 layout to prevent horizontal clipping)
	var grid_week_btns = GridContainer.new()
	grid_week_btns.columns = 2
	grid_week_btns.add_theme_constant_override("h_separation", 15)
	grid_week_btns.add_theme_constant_override("v_separation", 15)
	grid_week_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_week.add_child(grid_week_btns)
	
	var btn_w_minus = Button.new()
	btn_w_minus.text = " ➖ Minggu -1 "
	btn_w_minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_w_minus.custom_minimum_size = Vector2(0, 80)
	btn_w_minus.add_theme_font_size_override("font_size", 21)
	btn_w_minus.pressed.connect(func(): _modify_week(-1))
	grid_week_btns.add_child(btn_w_minus)
	
	var btn_w_plus = Button.new()
	btn_w_plus.text = " ➕ Minggu +1 "
	btn_w_plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_w_plus.custom_minimum_size = Vector2(0, 80)
	btn_w_plus.add_theme_font_size_override("font_size", 21)
	btn_w_plus.pressed.connect(func(): _modify_week(1))
	grid_week_btns.add_child(btn_w_plus)
	
	var btn_w_8 = Button.new()
	btn_w_8.text = " Set Minggu 8 "
	btn_w_8.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_w_8.custom_minimum_size = Vector2(0, 80)
	btn_w_8.add_theme_font_size_override("font_size", 21)
	btn_w_8.pressed.connect(func(): _set_week(8))
	grid_week_btns.add_child(btn_w_8)
	
	var btn_w_16 = Button.new()
	btn_w_16.text = " Set Minggu 16 "
	btn_w_16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_w_16.custom_minimum_size = Vector2(0, 80)
	btn_w_16.add_theme_font_size_override("font_size", 21)
	btn_w_16.pressed.connect(func(): _set_week(16))
	grid_week_btns.add_child(btn_w_16)
	
	# Class Grade selectors Grid (2x2 layout)
	var grid_grade_btns = GridContainer.new()
	grid_grade_btns.columns = 2
	grid_grade_btns.add_theme_constant_override("h_separation", 15)
	grid_grade_btns.add_theme_constant_override("v_separation", 15)
	grid_grade_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_week.add_child(grid_grade_btns)
	
	var btn_g7 = Button.new()
	btn_g7.text = " Set Kelas 7 (Wk 1) "
	btn_g7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_g7.custom_minimum_size = Vector2(0, 80)
	btn_g7.add_theme_font_size_override("font_size", 20)
	btn_g7.pressed.connect(func(): _set_grade(7))
	grid_grade_btns.add_child(btn_g7)
	
	var btn_g8 = Button.new()
	btn_g8.text = " Set Kelas 8 (Wk 17) "
	btn_g8.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_g8.custom_minimum_size = Vector2(0, 80)
	btn_g8.add_theme_font_size_override("font_size", 20)
	btn_g8.pressed.connect(func(): _set_grade(8))
	grid_grade_btns.add_child(btn_g8)
	
	var btn_g9 = Button.new()
	btn_g9.text = " Set Kelas 9 (Wk 33) "
	btn_g9.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_g9.custom_minimum_size = Vector2(0, 80)
	btn_g9.add_theme_font_size_override("font_size", 20)
	btn_g9.pressed.connect(func(): _set_grade(9))
	grid_grade_btns.add_child(btn_g9)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Row 2: Economy Cheat (Money)
	var grp_money = VBoxContainer.new()
	grp_money.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_money)
	
	var row_money_info = HBoxContainer.new()
	grp_money.add_child(row_money_info)
	
	var lbl_m_title = Label.new()
	lbl_m_title.text = "Uang Pemain (G): "
	lbl_m_title.add_theme_font_size_override("font_size", 26)
	row_money_info.add_child(lbl_m_title)
	
	_lbl_money = Label.new()
	_lbl_money.text = "0G"
	_lbl_money.add_theme_font_size_override("font_size", 26)
	_lbl_money.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	row_money_info.add_child(_lbl_money)
	
	# Money buttons Grid (2x2 layout)
	var grid_money_btns = GridContainer.new()
	grid_money_btns.columns = 2
	grid_money_btns.add_theme_constant_override("h_separation", 15)
	grid_money_btns.add_theme_constant_override("v_separation", 15)
	grid_money_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_money.add_child(grid_money_btns)
	
	var btn_m_100 = Button.new()
	btn_m_100.text = " 💰 +100G "
	btn_m_100.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_m_100.custom_minimum_size = Vector2(0, 80)
	btn_m_100.add_theme_font_size_override("font_size", 21)
	btn_m_100.pressed.connect(func(): _modify_money(100))
	grid_money_btns.add_child(btn_m_100)
	
	var btn_m_1000 = Button.new()
	btn_m_1000.text = " 💎 +1000G "
	btn_m_1000.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_m_1000.custom_minimum_size = Vector2(0, 80)
	btn_m_1000.add_theme_font_size_override("font_size", 21)
	btn_m_1000.pressed.connect(func(): _modify_money(1000))
	grid_money_btns.add_child(btn_m_1000)
	
	var btn_m_minus = Button.new()
	btn_m_minus.text = " 💸 -100G "
	btn_m_minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_m_minus.custom_minimum_size = Vector2(0, 80)
	btn_m_minus.add_theme_font_size_override("font_size", 21)
	btn_m_minus.pressed.connect(func(): _modify_money(-100))
	grid_money_btns.add_child(btn_m_minus)
	
	var btn_m_0 = Button.new()
	btn_m_0.text = " Reset 0G "
	btn_m_0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_m_0.custom_minimum_size = Vector2(0, 80)
	btn_m_0.add_theme_font_size_override("font_size", 21)
	btn_m_0.pressed.connect(func(): _set_money(0))
	grid_money_btns.add_child(btn_m_0)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Row 3: Game Speed Hacks (Time Scale)
	var grp_speed = VBoxContainer.new()
	grp_speed.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_speed)
	
	var row_speed_info = HBoxContainer.new()
	grp_speed.add_child(row_speed_info)
	
	var lbl_s_title = Label.new()
	lbl_s_title.text = "Kecepatan Game (Time Scale): "
	lbl_s_title.add_theme_font_size_override("font_size", 26)
	row_speed_info.add_child(lbl_s_title)
	
	_lbl_speed = Label.new()
	_lbl_speed.text = "1.0x (Normal)"
	_lbl_speed.add_theme_font_size_override("font_size", 26)
	_lbl_speed.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	row_speed_info.add_child(_lbl_speed)
	
	# Speed buttons Grid (2x2 layout)
	var grid_speed_btns = GridContainer.new()
	grid_speed_btns.columns = 2
	grid_speed_btns.add_theme_constant_override("h_separation", 15)
	grid_speed_btns.add_theme_constant_override("v_separation", 15)
	grid_speed_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_speed.add_child(grid_speed_btns)
	
	var btn_s1 = Button.new()
	btn_s1.text = " 1.0x (Normal) "
	btn_s1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_s1.custom_minimum_size = Vector2(0, 80)
	btn_s1.add_theme_font_size_override("font_size", 21)
	btn_s1.pressed.connect(func(): _set_time_scale(1.0))
	grid_speed_btns.add_child(btn_s1)
	
	var btn_s2 = Button.new()
	btn_s2.text = " 2.0x (Cepat) "
	btn_s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_s2.custom_minimum_size = Vector2(0, 80)
	btn_s2.add_theme_font_size_override("font_size", 21)
	btn_s2.pressed.connect(func(): _set_time_scale(2.0))
	grid_speed_btns.add_child(btn_s2)
	
	var btn_s5 = Button.new()
	btn_s5.text = " 5.0x (Sangat Cepat) "
	btn_s5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_s5.custom_minimum_size = Vector2(0, 80)
	btn_s5.add_theme_font_size_override("font_size", 21)
	btn_s5.pressed.connect(func(): _set_time_scale(5.0))
	grid_speed_btns.add_child(btn_s5)
	
	var btn_s10 = Button.new()
	btn_s10.text = " 10.0x (Turbo Skip) "
	btn_s10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_s10.custom_minimum_size = Vector2(0, 80)
	btn_s10.add_theme_font_size_override("font_size", 21)
	btn_s10.pressed.connect(func(): _set_time_scale(10.0))
	grid_speed_btns.add_child(btn_s10)
	
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)
	
	# Row 4: Tutorial Toggles
	var grp_tutorial = VBoxContainer.new()
	grp_tutorial.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_tutorial)
	
	var lbl_tut_title = Label.new()
	lbl_tut_title.text = "Bypass Tutorial / Pengaturan:"
	lbl_tut_title.add_theme_font_size_override("font_size", 26)
	grp_tutorial.add_child(lbl_tut_title)
	
	# Tutorial buttons VBox (each button gets full width)
	var v_tut_btns = VBoxContainer.new()
	v_tut_btns.add_theme_constant_override("separation", 15)
	v_tut_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_tutorial.add_child(v_tut_btns)
	
	_btn_tutorial_lobby = Button.new()
	_btn_tutorial_lobby.text = "Bypass Tutorial Lobby: OFF"
	_btn_tutorial_lobby.custom_minimum_size = Vector2(0, 85)
	_btn_tutorial_lobby.add_theme_font_size_override("font_size", 21)
	_btn_tutorial_lobby.pressed.connect(_toggle_lobby_tutorial)
	v_tut_btns.add_child(_btn_tutorial_lobby)
	
	_btn_tutorial_minigames = Button.new()
	_btn_tutorial_minigames.text = "Tutorial Minigames: ON"
	_btn_tutorial_minigames.custom_minimum_size = Vector2(0, 85)
	_btn_tutorial_minigames.add_theme_font_size_override("font_size", 21)
	_btn_tutorial_minigames.pressed.connect(_toggle_minigames_tutorial)
	v_tut_btns.add_child(_btn_tutorial_minigames)

func _modify_week(delta: int) -> void:
	GameState.minggu_ke = clampi(GameState.minggu_ke + delta, 1, GameState.max_minggu)
	log_message("Week modified to: %d" % GameState.minggu_ke)
	_refresh_ui_fields()

func _set_week(week: int) -> void:
	GameState.minggu_ke = clampi(week, 1, GameState.max_minggu)
	log_message("Week set to: %d" % GameState.minggu_ke)
	_refresh_ui_fields()

func _set_grade(grade_num: int) -> void:
	if GameState.has_method("set_grade"):
		GameState.set_grade(grade_num)
	else:
		GameState.current_grade = clampi(grade_num, 7, 9)
		GameState.minggu_ke = 1
	log_message("Grade set to: Kelas %d (Week %d)" % [GameState.current_grade, GameState.minggu_ke])
	_refresh_ui_fields()

func _modify_money(delta: int) -> void:
	GameState.player_money = max(0, GameState.player_money + delta)
	log_message("Player money modified by %d. Current: %dG" % [delta, GameState.player_money])
	# Notify lobby scene to update display immediately
	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.has_method("_update_money_display"):
		cur_scene._update_money_display()
	_refresh_ui_fields()

func _set_money(amount: int) -> void:
	GameState.player_money = max(0, amount)
	log_message("Player money set to: %dG" % GameState.player_money)
	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.has_method("_update_money_display"):
		cur_scene._update_money_display()
	_refresh_ui_fields()

## One call to reach a mid-game state: roster approved, money stocked,
## inventory full, lobby tutorial bypassed. Exists so verifying a screen
## costs one click instead of playing the game up to that screen.
func _seed_playtest_state() -> void:
	_auto_approve_students()
	_set_money(999999)
	GameState.seed_playtest_inventory(5)
	GameState.lobby_tutorial_completed = true

	log_message("Seeded playtest state: roster, 999999G, full inventory, tutorial bypassed.")
	_refresh_ui_fields()

func _set_time_scale(scale: float) -> void:
	Engine.time_scale = scale
	log_message("Game Time Scale set to: %.1fx" % scale)
	_refresh_ui_fields()

func _toggle_lobby_tutorial() -> void:
	GameState.lobby_tutorial_completed = not GameState.lobby_tutorial_completed
	log_message("Lobby Tutorial completed flag toggled to: " + str(GameState.lobby_tutorial_completed))
	_refresh_ui_fields()

func _toggle_minigames_tutorial() -> void:
	if "GameSettings" in get_node_or_null("/root"):
		var settings = get_node("/root/GameSettings")
		if "minigame_tutorial_enabled" in settings:
			settings.minigame_tutorial_enabled = not settings.minigame_tutorial_enabled
			if settings.has_method("save_settings"):
				settings.save_settings()
			log_message("Minigame tutorial enabled: " + str(settings.minigame_tutorial_enabled))
	_refresh_ui_fields()

func _refresh_ui_fields() -> void:
	if _lbl_week:
		_lbl_week.text = "Minggu %d (Grade %d)" % [GameState.minggu_ke, GameState.current_grade]
	if _lbl_money:
		_lbl_money.text = str(GameState.player_money) + "G"
	if _lbl_speed:
		_lbl_speed.text = "%.1fx" % Engine.time_scale
		if Engine.time_scale == 1.0:
			_lbl_speed.text += " (Normal)"
		elif Engine.time_scale > 1.0:
			_lbl_speed.text += " (Cepat)"
	if _btn_tutorial_lobby:
		_btn_tutorial_lobby.text = "Bypass Tutorial Lobby: " + ("ON (Bypassed)" if GameState.lobby_tutorial_completed else "OFF (Normal)")
	if _btn_tutorial_minigames:
		var active = true
		if "GameSettings" in get_node_or_null("/root"):
			active = get_node("/root/GameSettings").minigame_tutorial_enabled
		_btn_tutorial_minigames.text = "Tutorial Minigames: " + ("ON" if active else "OFF (Skipped)")
		
	_rebuild_student_stat_editor()

# --- Students Stat Modifier Panel ---
var students_vbox_container: VBoxContainer

func _build_students_panel(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	panels["Students"] = scroll
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_top", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.add_theme_constant_override("margin_bottom", 30)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)
	
	students_vbox_container = VBoxContainer.new()
	students_vbox_container.add_theme_constant_override("separation", 35)
	students_vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(students_vbox_container)

func _rebuild_student_stat_editor() -> void:
	if not students_vbox_container:
		return
		
	# Clear previous contents
	for child in students_vbox_container.get_children():
		child.queue_free()
		
	var active_students = GameState.approved_students
	
	if active_students.is_empty():
		# Display warning and quick auto-approve option
		var lbl_warn = Label.new()
		lbl_warn.text = "⚠️ Belum ada murid yang terpilih di GameState.\nSilakan masuk ke layar pilih murid, atau gunakan jalan pintas di bawah ini:"
		lbl_warn.add_theme_font_size_override("font_size", 23)
		lbl_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		students_vbox_container.add_child(lbl_warn)
		
		var btn_approve_default = Button.new()
		btn_approve_default.text = "⚡ Instantly Approve 4 Default Students ⚡"
		btn_approve_default.custom_minimum_size = Vector2(0, 100)
		btn_approve_default.add_theme_font_size_override("font_size", 23)
		btn_approve_default.pressed.connect(_auto_approve_students)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.48, 0.28)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		btn_approve_default.add_theme_stylebox_override("normal", style)
		btn_approve_default.add_theme_stylebox_override("hover", style)
		btn_approve_default.add_theme_stylebox_override("focus", style)
		
		students_vbox_container.add_child(btn_approve_default)
		return
		
	# Build student cards
	for student_idx in range(active_students.size()):
		var s_data = active_students[student_idx]
		var s_name = s_data.get("name", "Unknown")
		var s_quirk = s_data.get("quirk", "None")
		var s_persona = s_data.get("persona", "None")
		var s_id = s_data.get("id", 0)
		
		# Student Panel Box
		var s_panel = PanelContainer.new()
		students_vbox_container.add_child(s_panel)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.24, 0.95)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.3, 0.5, 0.8)
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		s_panel.add_theme_stylebox_override("panel", style)
		
		var s_margin = MarginContainer.new()
		s_margin.add_theme_constant_override("margin_left", 24)
		s_margin.add_theme_constant_override("margin_top", 20)
		s_margin.add_theme_constant_override("margin_right", 24)
		s_margin.add_theme_constant_override("margin_bottom", 20)
		s_panel.add_child(s_margin)
		
		var s_vbox = VBoxContainer.new()
		s_vbox.add_theme_constant_override("separation", 20)
		s_margin.add_child(s_vbox)
		
		# Student Info Header (Stacked vertically to prevent horizontal clipping)
		var lbl_name = Label.new()
		lbl_name.text = "👤 %s (ID: %d)" % [s_name, s_id]
		lbl_name.add_theme_font_size_override("font_size", 27)
		lbl_name.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		s_vbox.add_child(lbl_name)
		
		var lbl_traits = Label.new()
		lbl_traits.text = "⚡ Quirk: %s | 🌟 Persona: %s" % [s_quirk, s_persona.replace("Persona ", "")]
		lbl_traits.add_theme_font_size_override("font_size", 20)
		lbl_traits.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		lbl_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_vbox.add_child(lbl_traits)
		
		var sep_header = HSeparator.new()
		s_vbox.add_child(sep_header)
		
		# Stats layout: Stacked vertically (Label above buttons row) to prevent clipping
		var stats_keys = [
			{"key": "akademis1", "label": "Akademis", "color": Color(0.4, 0.65, 1.0)},
			{"key": "akademis2", "label": "Seni Budaya", "color": Color(0.3, 0.9, 0.5)},
			{"key": "akademis3", "label": "Olahraga", "color": Color(1.0, 0.4, 0.4)},
			{"key": "kepribadian2", "label": "Energy ⚡", "color": Color(1.0, 0.85, 0.3)},
			{"key": "kepribadian1", "label": "Mood 😊", "color": Color(1.0, 0.5, 0.85)}
		]
		
		for stat_info in stats_keys:
			var key = stat_info["key"]
			var s_lbl = stat_info["label"]
			var s_color = stat_info["color"]
			var val = float(s_data.get(key, 50.0))
			
			var stat_vbox = VBoxContainer.new()
			stat_vbox.add_theme_constant_override("separation", 10)
			s_vbox.add_child(stat_vbox)
			
			# Line 1: Label of stat name and current value
			var row_lbl = Label.new()
			row_lbl.text = "• %s: %d / 100" % [s_lbl, int(val)]
			row_lbl.add_theme_font_size_override("font_size", 21)
			row_lbl.add_theme_color_override("font_color", s_color)
			stat_vbox.add_child(row_lbl)
			
			# Line 2: HBox containing the 4 buttons (Expanded to fill available space equally)
			var row_btns = HBoxContainer.new()
			row_btns.add_theme_constant_override("separation", 10)
			row_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stat_vbox.add_child(row_btns)
			
			var btn_minus = Button.new()
			btn_minus.text = "-10"
			btn_minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_minus.custom_minimum_size = Vector2(0, 75)
			btn_minus.add_theme_font_size_override("font_size", 20)
			btn_minus.pressed.connect(func(): _modify_student_stat(s_name, key, -10.0))
			row_btns.add_child(btn_minus)
			
			var btn_plus = Button.new()
			btn_plus.text = "+10"
			btn_plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_plus.custom_minimum_size = Vector2(0, 75)
			btn_plus.add_theme_font_size_override("font_size", 20)
			btn_plus.pressed.connect(func(): _modify_student_stat(s_name, key, 10.0))
			row_btns.add_child(btn_plus)
			
			var btn_zero = Button.new()
			if key == "kepribadian2" or key == "kepribadian1":
				btn_zero.text = "Set 5" # Sickness boundary
			else:
				btn_zero.text = "Set 0"
			btn_zero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_zero.custom_minimum_size = Vector2(0, 75)
			btn_zero.add_theme_font_size_override("font_size", 20)
			btn_zero.pressed.connect(func(): _set_student_stat(s_name, key, 5.0 if (key == "kepribadian2" or key == "kepribadian1") else 0.0))
			row_btns.add_child(btn_zero)
			
			var btn_max = Button.new()
			btn_max.text = "Set 100"
			btn_max.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_max.custom_minimum_size = Vector2(0, 75)
			btn_max.add_theme_font_size_override("font_size", 20)
			btn_max.pressed.connect(func(): _set_student_stat(s_name, key, 100.0))
			row_btns.add_child(btn_max)

func _auto_approve_students() -> void:
	GameState.returned_from_student_card = true
	GameState.approved_students.clear()
	for s in DEFAULT_STUDENTS:
		GameState.approved_students.append(s.duplicate())
		
	GameState.selected_student = GameState.approved_students[0]
	log_message("Approved default students list (Marcel, Doni, Andi, Citra).")
	
	# If in Lobby, reload seat portraits
	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.has_method("_setup_students"):
		cur_scene._setup_students()
	
	_refresh_ui_fields()

func _modify_student_stat(student_name: String, key: String, delta: float) -> void:
	# 1. Update GameState dictionary list
	for s in GameState.approved_students:
		if s.get("name", "") == student_name:
			var cur = float(s.get(key, 50.0))
			s[key] = clampf(cur + delta, 0.0, 100.0)
			log_message("Modified dictionary stat %s of %s by %.0f. Current: %.0f" % [key, student_name, delta, s[key]])
			break
			
	# 2. If simulation is running, modify active StudentData objects
	var cur_scene = get_tree().current_scene
	if cur_scene and "student_manager" in cur_scene and cur_scene.student_manager:
		var manager = cur_scene.student_manager as StudentManager
		for s in manager.students:
			if s.student_name == student_name:
				var val = _get_student_resource_value(s, key)
				_set_student_resource_value(s, key, clampf(val + delta, 0.0, 100.0))
				log_message("Modified active StudentData stat %s of %s by %.0f. Current: %.0f" % [key, student_name, delta, _get_student_resource_value(s, key)])
				break
				
		if cur_scene.has_method("_render_embedded_student_status"):
			cur_scene._render_embedded_student_status()
			
	_refresh_ui_fields()

func _set_student_stat(student_name: String, key: String, target_val: float) -> void:
	# 1. Update GameState dictionary list
	for s in GameState.approved_students:
		if s.get("name", "") == student_name:
			s[key] = target_val
			log_message("Set dictionary stat %s of %s to %.0f" % [key, student_name, target_val])
			break
			
	# 2. If simulation is running, modify active StudentData objects
	var cur_scene = get_tree().current_scene
	if cur_scene and "student_manager" in cur_scene and cur_scene.student_manager:
		var manager = cur_scene.student_manager as StudentManager
		for s in manager.students:
			if s.student_name == student_name:
				_set_student_resource_value(s, key, target_val)
				log_message("Set active StudentData stat %s of %s to %.0f" % [key, student_name, target_val])
				break
				
		if cur_scene.has_method("_render_embedded_student_status"):
			cur_scene._render_embedded_student_status()
			
	_refresh_ui_fields()

func _get_student_resource_value(s: StudentData, key: String) -> float:
	match key:
		"akademis1": return s.akademis
		"akademis2": return s.seni_budaya
		"akademis3": return s.olahraga
		"kepribadian2": return s.energy
		"kepribadian1": return s.mood
	return 50.0

func _set_student_resource_value(s: StudentData, key: String, val: float) -> void:
	match key:
		"akademis1": s.akademis = val
		"akademis2": s.seni_budaya = val
		"akademis3": s.olahraga = val
		"kepribadian2": s.energy = val
		"kepribadian1": s.mood = val

# --- Minigames & Standalone Testing Panel ---
var _btn_autowin: Button
var _btn_autolose: Button

func _build_minigames_panel(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	panels["Minigames"] = scroll
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_top", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.add_theme_constant_override("margin_bottom", 30)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 35)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)
	
	# Section 1: Minigame skip cheats (Auto Win / Auto Lose)
	var grp_cheats = VBoxContainer.new()
	grp_cheats.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_cheats)
	
	var lbl_cheat_title = Label.new()
	lbl_cheat_title.text = "Minigame Cheat Outcomes (Simulasi):"
	lbl_cheat_title.add_theme_font_size_override("font_size", 26)
	grp_cheats.add_child(lbl_cheat_title)
	
	# Cheats Buttons Grid (2 columns)
	var grid_cheat_btns = GridContainer.new()
	grid_cheat_btns.columns = 2
	grid_cheat_btns.add_theme_constant_override("h_separation", 15)
	grid_cheat_btns.add_theme_constant_override("v_separation", 15)
	grid_cheat_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_cheats.add_child(grid_cheat_btns)
	
	_btn_autowin = Button.new()
	_btn_autowin.text = "Auto-Win Minigames: OFF"
	_btn_autowin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_autowin.custom_minimum_size = Vector2(0, 85)
	_btn_autowin.add_theme_font_size_override("font_size", 21)
	_btn_autowin.pressed.connect(func(): _toggle_minigame_cheat("win"))
	grid_cheat_btns.add_child(_btn_autowin)
	
	_btn_autolose = Button.new()
	_btn_autolose.text = "Auto-Lose Minigames: OFF"
	_btn_autolose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_autolose.custom_minimum_size = Vector2(0, 85)
	_btn_autolose.add_theme_font_size_override("font_size", 21)
	_btn_autolose.pressed.connect(func(): _toggle_minigame_cheat("lose"))
	grid_cheat_btns.add_child(_btn_autolose)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Section 2: Standalone Minigame Launcher
	var grp_launcher = VBoxContainer.new()
	grp_launcher.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_launcher)
	
	var lbl_launcher_title = Label.new()
	lbl_launcher_title.text = "Luncurkan Minigame Mandiri (Standalone):"
	lbl_launcher_title.add_theme_font_size_override("font_size", 26)
	grp_launcher.add_child(lbl_launcher_title)
	
	var minigames_list = [
		{"name": "Menjodohkan", "path": "res://Scenes/Minigames/Akademis/AnswerCard.tscn"}, # Use main scene tscn if AnswerCard is just component, let's use the ones verified before
		{"name": "Menjodohkan (Akademis)", "path": "res://Scenes/Minigames/Akademis/Menjodohkan.tscn"},
		{"name": "Variabel Matematika", "path": "res://Scenes/Minigames/Akademis/Variabel.tscn"},
		{"name": "Pilihan Ganda (Akademis)", "path": "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"},
		{"name": "Sandi Password (Akademis)", "path": "res://Scenes/Minigames/Akademis/Password.tscn"},
		{"name": "Main Bola (Olahraga)", "path": "res://Scenes/Minigames/Olahraga/MainBola.tscn"},
		{"name": "Badminton (Olahraga)", "path": "res://Scenes/Minigames/Olahraga/Badminton.tscn"},
		{"name": "Buat Batik (Seni)", "path": "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"},
		{"name": "Lomba Menari (Seni)", "path": "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"}
	]
	
	# 2 Columns for standalone launcher, with large touch areas
	var grid_m = GridContainer.new()
	grid_m.columns = 2
	grid_m.add_theme_constant_override("h_separation", 15)
	grid_m.add_theme_constant_override("v_separation", 15)
	grid_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_launcher.add_child(grid_m)
	
	for mg in minigames_list:
		var btn_m = Button.new()
		btn_m.text = " ▶ " + mg["name"]
		btn_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_m.custom_minimum_size = Vector2(0, 90)
		btn_m.add_theme_font_size_override("font_size", 20)
		btn_m.pressed.connect(func(): _launch_minigame_standalone(mg["path"]))
		grid_m.add_child(btn_m)
		
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Section 3: Event Spawning Cheat
	var grp_events = VBoxContainer.new()
	grp_events.add_theme_constant_override("separation", 15)
	vbox.add_child(grp_events)
	
	var lbl_evt_title = Label.new()
	lbl_evt_title.text = "Luncurkan Event Harian Sekolah (Saat Simulasi):"
	lbl_evt_title.add_theme_font_size_override("font_size", 26)
	grp_events.add_child(lbl_evt_title)
	
	var events_list = [
		{"name": "Les Akademis", "id": 0},
		{"name": "Latihan Olahraga", "id": 1},
		{"name": "Workshop Seni", "id": 2},
		{"name": "Nasi Kotak (Global)", "id": 3},
		{"name": "Kehujanan (Global)", "id": 4}
	]
	
	# Event buttons Grid (2 columns)
	var grid_evts = GridContainer.new()
	grid_evts.columns = 2
	grid_evts.add_theme_constant_override("h_separation", 15)
	grid_evts.add_theme_constant_override("v_separation", 15)
	grid_evts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grp_events.add_child(grid_evts)
	
	for evt in events_list:
		var btn_e = Button.new()
		btn_e.text = " 🔔 " + evt["name"]
		btn_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_e.custom_minimum_size = Vector2(0, 85)
		btn_e.add_theme_font_size_override("font_size", 20)
		btn_e.pressed.connect(func(): _trigger_simulation_event(evt["id"]))
		grid_evts.add_child(btn_e)

func _toggle_minigame_cheat(outcome: String) -> void:
	if outcome == "win":
		cheat_auto_win = not cheat_auto_win
		if cheat_auto_win:
			cheat_auto_lose = false
	elif outcome == "lose":
		cheat_auto_lose = not cheat_auto_lose
		if cheat_auto_lose:
			cheat_auto_win = false
			
	if cheat_auto_win: cheat_force_outcome = "win"
	elif cheat_auto_lose: cheat_force_outcome = "lose"
	else: cheat_force_outcome = ""
	
	log_message("Minigame outcome cheats updated. Win: %s | Lose: %s" % [cheat_auto_win, cheat_auto_lose])
	
	if _btn_autowin:
		_btn_autowin.text = "Auto-Win Minigames: " + ("ON" if cheat_auto_win else "OFF")
	if _btn_autolose:
		_btn_autolose.text = "Auto-Lose Minigames: " + ("ON" if cheat_auto_lose else "OFF")

func _launch_minigame_standalone(scene_path: String) -> void:
	if active_minigame:
		log_message("Error: Ada minigame lain yang sedang berjalan!")
		return
		
	log_message("Loading standalone minigame: " + scene_path)
	
	minigame_canvas = CanvasLayer.new()
	minigame_canvas.layer = 125 # Just below debug menu (128)
	add_child(minigame_canvas)
	
	var m_scene = load(scene_path)
	if not m_scene:
		log_message("Error: Gagal memuat scene file: " + scene_path)
		minigame_canvas.queue_free()
		minigame_canvas = null
		return
		
	active_minigame = m_scene.instantiate()
	minigame_canvas.add_child(active_minigame)
	active_minigame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if active_minigame.has_signal("minigame_won"):
		active_minigame.minigame_won.connect(func(): _on_standalone_minigame_finished(true))
	if active_minigame.has_signal("minigame_lost"):
		active_minigame.minigame_lost.connect(func(): _on_standalone_minigame_finished(false))
		
	if active_minigame.has_method("start_minigame"):
		active_minigame.start_minigame(1, 30.0)
	if active_minigame.has_method("activate_minigame"):
		active_minigame.activate_minigame()
		
	toggle_overlay()

func _on_standalone_minigame_finished(won: bool) -> void:
	log_message("Standalone minigame completed. Result: " + ("MENANG (WIN)" if won else "KALAH (LOSE)"))
	
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null
		
	if minigame_canvas:
		minigame_canvas.queue_free()
		minigame_canvas = null
		
	toggle_overlay()

func _trigger_simulation_event(event_id: int) -> void:
	var cur_scene = get_tree().current_scene
	if cur_scene and (cur_scene.name == "SchoolDay" or cur_scene.has_method("_trigger_random_event")):
		log_message("Forcing simulation event roll: %d" % event_id)
		toggle_overlay()
		if cur_scene.has_method("force_event"):
			cur_scene.force_event(event_id)
		else:
			log_message("Error: force_event() helper not yet injected in SchoolDay.gd.")
	else:
		log_message("⚠️ Error: Trigger event hanya bisa dipanggil saat berada di scene SchoolDay (Simulasi Hari Sekolah).")

# --- Scene Teleporter Tab Panel ---
func _build_scenes_panel(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	panels["Scenes"] = scroll
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_top", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.add_theme_constant_override("margin_bottom", 30)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)
	
	var lbl_title = Label.new()
	lbl_title.text = "Teleportasi Scene Langsung (Scene Switcher):"
	lbl_title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(lbl_title)
	
	var scenes_list = [
		{"name": "Menu Utama (MainMenu)", "path": "res://Scenes/MainMenu/main_menu.tscn"},
		{"name": "Lobi Kelas (Lobby)", "path": "res://Scenes/Lobby/loby.tscn"},
		{"name": "Pilih Murid (StudentCard)", "path": "res://Scenes/StudentCard/student_card.tscn"},
		{"name": "Atur Jadwal (AturJadwal)", "path": "res://Scenes/AturJadwal/atur_jadwal.tscn"},
		{"name": "Simulasi Hari (SchoolDay)", "path": "res://Scenes/SchoolSimulation/SchoolDay.tscn"},
		{"name": "Evaluasi Semester (SemesterEnd)", "path": "res://Scenes/EndGame/SemesterEnd.tscn"},
		{"name": "Splash Screen", "path": "res://Scenes/Splashscreen/Splashscreen.tscn"}
	]
	
	for sc in scenes_list:
		var btn = Button.new()
		btn.text = " 🚀 Teleport ke: " + sc["name"]
		btn.custom_minimum_size = Vector2(0, 95)
		btn.add_theme_font_size_override("font_size", 21)
		btn.pressed.connect(func(): _teleport_to_scene(sc["path"]))
		vbox.add_child(btn)

func _teleport_to_scene(path: String) -> void:
	log_message("Teleporting to scene: " + path)
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null
	if minigame_canvas:
		minigame_canvas.queue_free()
		minigame_canvas = null
		
	_set_time_scale(1.0)
	toggle_overlay()
	
	if "Transition" in get_node_or_null("/root"):
		var transition_node = get_node("/root/Transition")
		if transition_node.has_method("change_scene"):
			transition_node.change_scene(path)
			return
			
	get_tree().change_scene_to_file(path)

# --- Logs/Console Panel ---
func _build_logs_panel(parent: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(vbox)
	panels["Logs"] = vbox
	
	var header_bar = HBoxContainer.new()
	header_bar.add_theme_constant_override("separation", 20)
	vbox.add_child(header_bar)
	
	var lbl_title = Label.new()
	lbl_title.text = " Log Aktivitas & print() Output:"
	lbl_title.add_theme_font_size_override("font_size", 26)
	header_bar.add_child(lbl_title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)
	
	var clear_btn = Button.new()
	clear_btn.text = " Clear Logs "
	clear_btn.custom_minimum_size = Vector2(180, 75)
	clear_btn.add_theme_font_size_override("font_size", 20)
	clear_btn.pressed.connect(func(): if log_text_label: log_text_label.text = "")
	header_bar.add_child(clear_btn)
	
	# Scroll area for log text
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(log_scroll)
	
	var log_panel = PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	log_panel.add_theme_stylebox_override("panel", style)
	
	log_text_label = Label.new()
	log_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text_label.add_theme_font_size_override("font_size", 18)
	log_text_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	log_text_label.add_theme_constant_override("line_spacing", 6)
	log_text_label.text = ""
	log_panel.add_child(log_text_label)
