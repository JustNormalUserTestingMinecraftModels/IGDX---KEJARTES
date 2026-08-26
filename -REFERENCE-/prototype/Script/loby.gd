extends Control

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea
@onready var student_button = $Student
@onready var jadwal_button = $Jadwal
@onready var koperasi_button = $Koperasi
@onready var report_student_button = $ReportStudent
@onready var inventory_button = $Inventory

@onready var money_label = $DisplayUang/Label
@onready var daily_login_btn = $DailyLogin
@onready var daily_reward = $DailyLogin/DailyReward
@onready var claim_button = $DailyLogin/DailyReward/ButtonClaim
@onready var day_nodes = {
	1: $DailyLogin/DailyReward/Day1,
	2: $DailyLogin/DailyReward/Day2,
	3: $DailyLogin/DailyReward/Day3,
	4: $DailyLogin/DailyReward/Day4,
	5: $DailyLogin/DailyReward/Day5,
	6: $DailyLogin/DailyReward/Day6,
	7: $DailyLogin/DailyReward/Day7,
}

const DAILY_REWARD := 10

var steps := []
var current_step := 0
var blur_overlay: ColorRect
var reward_popup_open := false

func _ready():
	var mat := color_rect.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", color_rect.size)
	color_rect.resized.connect(_update_rect_size)

	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if GameState.returned_from_student_card:
		student_button.visible = false
		jadwal_button.visible = true
		
		steps = [
			{ "node": $ColorRect/Step3, "target": null },
			{ "node": $ColorRect/Step4, "target": inventory_button },
			{ "node": $ColorRect/Step5, "target": report_student_button },
			{ "node": $ColorRect/Step6, "target": koperasi_button },
			{ "node": $ColorRect/Step7, "target": jadwal_button },
		]
	else:
		student_button.visible = true
		jadwal_button.visible = false

		if student_button is BaseButton:
			student_button.disabled = true
		else:
			student_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		steps = [
			{ "node": $ColorRect/Step1, "target": null },
			{ "node": $ColorRect/Step2, "target": student_button },
		]

	if not student_button.pressed.is_connected(_on_student_pressed):
		student_button.pressed.connect(_on_student_pressed)
	if not jadwal_button.pressed.is_connected(_on_jadwal_pressed):
		jadwal_button.pressed.connect(_on_jadwal_pressed)

	if click_area.has_signal("pressed"):
		if not click_area.pressed.is_connected(_next_step):
			click_area.pressed.connect(_next_step)
	else:
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		if not click_area.gui_input.is_connected(_on_click_area_gui_input):
			click_area.gui_input.connect(_on_click_area_gui_input)

	_show_step(0)
	_create_blur_overlay()
	_setup_daily_login()

func _create_blur_overlay():
	blur_overlay = ColorRect.new()
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.color = Color(0, 0, 0, 0)
	var shader = load("res://Script/blur.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lod", 0.0)
	mat.set_shader_parameter("darkness", 0.0)
	blur_overlay.material = mat
	blur_overlay.visible = false
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blur_overlay)
	# Place blur_overlay just before DailyLogin so it renders on top of other UI but behind the popup
	move_child(blur_overlay, daily_login_btn.get_index())
	# Connect click on blur overlay to close popup
	blur_overlay.gui_input.connect(_on_blur_overlay_input)

func _setup_daily_login():
	# Hide the reward panel initially
	if daily_reward:
		daily_reward.visible = false
	_update_money_display()
	_check_daily_login_reset()
	_update_daily_login_visual()
	if claim_button and not claim_button.pressed.is_connected(_on_claim_pressed):
		claim_button.pressed.connect(_on_claim_pressed)
	if daily_login_btn and not daily_login_btn.pressed.is_connected(_on_daily_login_pressed):
		daily_login_btn.pressed.connect(_on_daily_login_pressed)

func _update_money_display():
	if money_label:
		money_label.text = str(GameState.player_money) + "G"

func _check_daily_login_reset():
	var today = Time.get_date_string_from_system()
	if GameState.last_claim_date == "" or GameState.last_claim_date == today:
		return
	var today_unix = Time.get_unix_time_from_datetime_string(today + " 00:00:00")
	var last_claim_unix = Time.get_unix_time_from_datetime_string(GameState.last_claim_date + " 00:00:00")
	if today_unix - last_claim_unix > 86400:
		# lewat lebih dari 1 hari tanpa klaim, streak reset ke Day1
		GameState.daily_login_day = 1

func _update_daily_login_visual():
	var today = Time.get_date_string_from_system()
	var already_claimed_today = GameState.last_claim_date == today

	for day_num in day_nodes.keys():
		var node = day_nodes[day_num]
		if not node:
			continue
		if day_num < GameState.daily_login_day:
			node.modulate = Color(0.5, 0.5, 0.5, 1.0)
		elif day_num == GameState.daily_login_day:
			node.modulate = Color(0.5, 0.5, 0.5, 1.0) if already_claimed_today else Color(1.0, 1.0, 0.6, 1.0)
		else:
			node.modulate = Color(1, 1, 1, 0.5)

	if claim_button and claim_button is BaseButton:
		claim_button.disabled = already_claimed_today

func _on_daily_login_pressed():
	if reward_popup_open:
		return
	_show_daily_reward()

func _show_daily_reward():
	if not daily_reward:
		return
	reward_popup_open = true

	# Show and animate blur overlay
	blur_overlay.visible = true
	var blur_mat = blur_overlay.material as ShaderMaterial
	blur_mat.set_shader_parameter("lod", 0.0)
	blur_mat.set_shader_parameter("darkness", 0.0)

	# Show and animate popup
	daily_reward.visible = true
	daily_reward.modulate = Color(1, 1, 1, 0)
	daily_reward.scale = Vector2(0.8, 0.8)
	daily_reward.pivot_offset = daily_reward.size / 2.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(daily_reward, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(daily_reward, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_set_blur_lod, 0.0, 3.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_blur_darkness, 0.0, 0.3, 0.25).set_ease(Tween.EASE_OUT)

func _hide_daily_reward():
	if not daily_reward:
		return
	reward_popup_open = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(daily_reward, "modulate", Color(1, 1, 1, 0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(daily_reward, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_lod, 3.0, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_darkness, 0.3, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): daily_reward.visible = false; blur_overlay.visible = false)

func _on_blur_overlay_input(event: InputEvent):
	if not reward_popup_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_daily_reward()
	elif event is InputEventScreenTouch and event.pressed:
		_hide_daily_reward()

func _set_blur_lod(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("lod", value)

func _set_blur_darkness(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("darkness", value)

func _on_claim_pressed():
	var today = Time.get_date_string_from_system()
	if GameState.last_claim_date == today:
		return

	GameState.player_money += DAILY_REWARD
	GameState.last_claim_date = today

	_update_money_display()
	_update_daily_login_visual()

	GameState.daily_login_day += 1
	if GameState.daily_login_day > 7:
		GameState.daily_login_day = 1

func _on_student_pressed():
	print("Tombol Student ditekan, pindah ke student_card")
	Transition.change_scene("res://Scene/student_card.tscn")

func _on_jadwal_pressed():
	print("Tombol Jadwal ditekan, pindah ke atur_jadwal")
	Transition.change_scene("res://Scene/atur_jadwal.tscn")

func _on_click_area_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_step()
	elif event is InputEventScreenTouch and event.pressed:
		_next_step()

func _update_rect_size():
	var mat := color_rect.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", color_rect.size)

func _next_step():
	current_step += 1
	if current_step >= steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int):
	for i in range(1, 8):
		var step_node = color_rect.get_node_or_null("Step" + str(i))
		if step_node:
			step_node.hide()

	steps[index]["node"].show()

	var target = steps[index]["target"]
	if target != null:
		_highlight(target)
	else:
		_clear_highlight()

	if not GameState.returned_from_student_card and index == steps.size() - 1:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if click_area is BaseButton:
			click_area.disabled = true

		if student_button is BaseButton:
			student_button.disabled = false
		else:
			student_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		if click_area is BaseButton:
			click_area.disabled = false
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP

		if student_button is BaseButton:
			student_button.disabled = true
		else:
			student_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _highlight(control: Control, padding: float = 8.0):
	var mat := color_rect.material as ShaderMaterial
	var local_pos = control.global_position - color_rect.global_position - Vector2(padding, padding)
	var size_with_padding = control.size + Vector2(padding, padding) * 2
	mat.set_shader_parameter("hole_pos", local_pos)
	mat.set_shader_parameter("hole_size", size_with_padding)

func _clear_highlight():
	var mat := color_rect.material as ShaderMaterial
	mat.set_shader_parameter("hole_size", Vector2.ZERO)

func _end_tutorial():
	color_rect.hide()
