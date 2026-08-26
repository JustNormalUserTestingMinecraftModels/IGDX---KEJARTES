extends Control

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea

static var tutorial_shown := false  # <-- penanda global, bertahan selama game berjalan

var default_students = [
	{
		"id": 1,
		"name": "Hamamiya",
		"portrait": "res://Asset/MuridPotrait/Murid1.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid1.jpg",
		"kepribadian1": 65.0,
		"kepribadian2": 30.0,
		"akademis1": 30.0,
		"akademis2": 50.0,
		"akademis3": 40.0,
		"target_akademis1": 50.0,
		"target_akademis2": 60.0,
		"target_akademis3": 55.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 40.0
	},
	{
		"id": 2,
		"name": "Mas Amba",
		"portrait": "res://Asset/MuridPotrait/Murid2.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid2.jpg",
		"kepribadian1": 30.0,
		"kepribadian2": 20.0,
		"akademis1": 40.0,
		"akademis2": 20.0,
		"akademis3": 35.0,
		"target_akademis1": 50.0,
		"target_akademis2": 30.0,
		"target_akademis3": 45.0,
		"target_kepribadian1": 40.0,
		"target_kepribadian2": 35.0
	},
	{
		"id": 3,
		"name": "Zeta",
		"portrait": "res://Asset/MuridPotrait/Murid3.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid3.jpg",
		"kepribadian1": 65.0,
		"kepribadian2": 65.0,
		"akademis1": 50.0,
		"akademis2": 65.0,
		"akademis3": 35.0,
		"target_akademis1": 60.0,
		"target_akademis2": 65.0,
		"target_akademis3": 55.0,
		"target_kepribadian1": 60.0,
		"target_kepribadian2": 55.0
	},
	{
		"id": 4,
		"name": "Bocchi",
		"portrait": "res://Asset/MuridPotrait/Murid4.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid4.jpg",
		"kepribadian1": 20.0,
		"kepribadian2": 60.0,
		"akademis1": 30.0,
		"akademis2": 20.0,
		"akademis3": 10.0,
		"target_akademis1": 40.0,
		"target_akademis2": 50.0,
		"target_akademis3": 30.0,
		"target_kepribadian1": 35.0,
		"target_kepribadian2": 45.0
	}
]

func _ready():
	_setup_tutorial()
	_setup_students()

func _setup_tutorial():
	if tutorial_shown:
		# Sudah pernah lihat tutorial, langsung sembunyikan overlay
		if color_rect:
			color_rect.hide()
		return

	if color_rect:
		color_rect.show()
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if click_area:
		if click_area.has_signal("pressed"):
			if not click_area.pressed.is_connected(_end_tutorial):
				click_area.pressed.connect(_end_tutorial)
		else:
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			if not click_area.gui_input.is_connected(_on_click_area_gui_input):
				click_area.gui_input.connect(_on_click_area_gui_input)

func _end_tutorial():
	tutorial_shown = true  # <-- tandai sudah selesai, tidak akan muncul lagi
	if color_rect:
		color_rect.hide()

func _on_click_area_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_tutorial()
	elif event is InputEventScreenTouch and event.pressed:
		_end_tutorial()

func _setup_students():
	var students = GameState.approved_students
	if students.is_empty():
		students = default_students

	var required_days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]

	for i in range(4):
		var node_name = "Murid" + str(i + 1)
		var murid_node = get_node_or_null(node_name)
		if not murid_node:
			continue

		if i < students.size():
			var student_data = students[i]
			murid_node.show()

			var portrait_path = student_data.get("portrait", "")
			if portrait_path != "" and ResourceLoader.exists(portrait_path):
				murid_node.texture = load(portrait_path)

			var nama_btn = murid_node.get_node_or_null("Nama")
			if nama_btn:
				nama_btn.text = student_data.get("name", "MURID " + str(i + 1))
				if not nama_btn.pressed.is_connected(_on_student_selected.bind(student_data)):
					nama_btn.pressed.connect(_on_student_selected.bind(student_data))

			# Check if all 5 days are scheduled for this student
			var student_id = student_data.get("id", null)
			var fully_scheduled := false
			if student_id != null and GameState.day_schedules.has(student_id):
				var schedules = GameState.day_schedules[student_id]
				fully_scheduled = true
				for day in required_days:
					if not schedules.has(day):
						fully_scheduled = false
						break

			var belum_btn = murid_node.get_node_or_null("Belum")
			var sudah_btn = murid_node.get_node_or_null("Sudah")
			if belum_btn:
				belum_btn.visible = not fully_scheduled
			if sudah_btn:
				sudah_btn.visible = fully_scheduled
		else:
			murid_node.hide()

func _on_student_selected(student: Dictionary):
	print("Murid dipilih: ", student.get("name", ""))
	GameState.selected_student = student
	Transition.change_scene("res://Scene/atur_jadwal.tscn")
