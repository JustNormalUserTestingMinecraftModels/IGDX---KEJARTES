extends Control

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var game_container: Control = $GameContainer

# ── Minigame scenes ────────────────────────────────────────────────────────────
@export var menjodohkan_scene: PackedScene
@export var variabel_scene: PackedScene
@export var pilihan_ganda_scene: PackedScene
@export var password_scene: PackedScene
@export var main_bola_scene: PackedScene
@export var badminton_scene: PackedScene
@export var buat_batik_scene: PackedScene
@export var lomba_menari_scene: PackedScene
@export var school_day_scene: PackedScene

var current_minigame: Node = null
var school_day_instance: Node = null

func _ready() -> void:
	if menu_container:
		menu_container.get_node("BtnMenjodohkan").pressed.connect(_load_game.bind(menjodohkan_scene))
		menu_container.get_node("BtnVariabel").pressed.connect(_load_game.bind(variabel_scene))
		menu_container.get_node("BtnPilihanGanda").pressed.connect(_load_game.bind(pilihan_ganda_scene))
		menu_container.get_node("BtnPassword").pressed.connect(_load_game.bind(password_scene))
		menu_container.get_node("BtnMainBola").pressed.connect(_load_game.bind(main_bola_scene))
		menu_container.get_node("BtnBadminton").pressed.connect(_load_game.bind(badminton_scene))
		menu_container.get_node("BtnBuatBatik").pressed.connect(_load_game.bind(buat_batik_scene))
		menu_container.get_node("BtnLombaMenari").pressed.connect(_load_game.bind(lomba_menari_scene))
		menu_container.get_node("BtnSchoolDay").pressed.connect(_start_school_day_simulation)

func _start_school_day_simulation() -> void:
	if school_day_scene == null:
		print("SchoolDay scene not assigned!")
		return

	# Disable buttons during transition
	_set_menu_buttons_disabled(true)

	# Fade out menu
	var tween = create_tween()
	tween.tween_property(menu_container, "modulate:a", 0.0, 0.4)
	await tween.finished
	menu_container.hide()

	# Instantiate SchoolDay scene
	school_day_instance = school_day_scene.instantiate()
	school_day_instance.modulate.a = 0.0
	game_container.add_child(school_day_instance)
	
	# Force the instance to fill the parent container (required when added dynamically)
	school_day_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Pass all scene references
	school_day_instance.setup_scenes(
		menjodohkan_scene, variabel_scene,
		pilihan_ganda_scene, password_scene,
		main_bola_scene, badminton_scene,
		buat_batik_scene, lomba_menari_scene
	)

	# Connect back signal
	school_day_instance.simulation_finished.connect(_on_school_day_finished)

	# Fade in and start
	var game_tween = create_tween()
	game_tween.tween_property(school_day_instance, "modulate:a", 1.0, 0.4)
	await game_tween.finished

	school_day_instance.start_simulation()

func _on_school_day_finished() -> void:
	if school_day_instance:
		school_day_instance.queue_free()
		school_day_instance = null

	for child in game_container.get_children():
		child.queue_free()

	# Fade menu back in
	menu_container.modulate.a = 0.0
	menu_container.show()
	_set_menu_buttons_disabled(false)
	var tween = create_tween()
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.4)

func _load_game(game_scene: PackedScene) -> void:
	if game_scene == null:
		print("Scene not assigned!")
		return
		
	# Disable menu buttons to prevent double-clicks
	_set_menu_buttons_disabled(true)
		
	# Fade out menu container
	var tween = create_tween()
	tween.tween_property(menu_container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		if menu_container:
			menu_container.hide()
			
		current_minigame = game_scene.instantiate()
		current_minigame.modulate.a = 0.0 # Start fully transparent
		game_container.add_child(current_minigame)
		
		# Force it to fill the parent container (required when added dynamically)
		current_minigame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Connect signals
		if current_minigame.has_signal("minigame_won"):
			print("Connecting minigame_won for: ", current_minigame.name)
			current_minigame.minigame_won.connect(_on_game_won)
		if current_minigame.has_signal("minigame_lost"):
			print("Connecting minigame_lost for: ", current_minigame.name)
			current_minigame.minigame_lost.connect(_on_game_lost)
			
		# Start the minigame with specific time limit per game type
		if current_minigame.has_method("start_minigame"):
			var duration: float
			if game_scene == menjodohkan_scene:
				duration = 10.0
			elif game_scene == main_bola_scene:
				duration = 60.0
			else:
				duration = 30.0
			current_minigame.start_minigame(1, duration)

			
		# Fade in the minigame
		var game_tween = create_tween()
		game_tween.tween_property(current_minigame, "modulate:a", 1.0, 0.4)
		game_tween.tween_callback(func():
			if current_minigame and current_minigame.has_method("activate_minigame"):
				current_minigame.activate_minigame()
		)
	)

func _on_game_won() -> void:
	print("Menu detected WIN! Calling _close_game()")
	_close_game()

func _on_game_lost() -> void:
	print("Menu detected LOSS! Calling _close_game()")
	_close_game()

func _close_game() -> void:
	print("Executing _close_game(). current_minigame is: ", current_minigame)
	if current_minigame:
		# Fade out current minigame before deleting
		var tween = create_tween()
		tween.tween_property(current_minigame, "modulate:a", 0.0, 0.4)
		tween.tween_callback(_cleanup_and_fade_in_menu)
	else:
		_cleanup_and_fade_in_menu()

func _cleanup_and_fade_in_menu() -> void:
	if current_minigame:
		print("Queueing free on: ", current_minigame.name)
		current_minigame.queue_free()
		current_minigame = null
		
	# Fallback: clean up anything else in game_container
	if game_container:
		for child in game_container.get_children():
			print("Fallback queue_free on stray child: ", child.name)
			child.queue_free()
			
	if menu_container:
		print("Fading in menu_container")
		menu_container.modulate.a = 0.0
		menu_container.show()
		
		# Re-enable menu interactions
		_set_menu_buttons_disabled(false)
			
		var tween = create_tween()
		tween.tween_property(menu_container, "modulate:a", 1.0, 0.4)

func _set_menu_buttons_disabled(disabled: bool) -> void:
	if not menu_container:
		return
	menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
	for child in menu_container.get_children():
		if child is Button:
			child.disabled = disabled
