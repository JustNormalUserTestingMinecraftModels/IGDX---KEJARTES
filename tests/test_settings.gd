@tool
extends McpTestSuite

## See tests/test_main_menu.gd for the established rationale behind the
## @tool marker on this suite and the _collect_overrides implementation
## below (the brief's original draft called
## get_theme_font_size_override_list()/get_theme_color_override_list()/
## get_theme_stylebox_override_list(), none of which exist on Godot 4.6's
## Control class -- fixed the same way test_main_menu.gd was).

func suite_name() -> String:
	return "settings"

var _screen: Control

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func setup() -> void:
	var scene: PackedScene = load("res://Scenes/UI/Settings.tscn")
	_screen = scene.instantiate()
	_screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func test_scene_loads() -> void:
	assert_true(_screen != null, "Settings.tscn must exist and instantiate")


func test_has_a_slider_for_each_audio_bus() -> void:
	for name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(name, true, false)
		assert_true(s != null, "missing slider: " + name)
		assert_true(s is Slider, name + " must be a Slider")


func test_moving_a_slider_changes_the_bus_volume() -> void:
	var slider := _screen.find_child("SfxSlider", true, false) as Slider
	slider.value = 0.3
	await Engine.get_main_loop().process_frame
	assert_true(absf((AudioDirector.get_bus_volume(&"SFX")) - (0.3)) <= 0.02, "the slider must drive the bus")


func test_tutorial_toggle_reflects_and_writes_game_settings() -> void:
	var toggle := _screen.find_child("TutorialToggle", true, false) as CheckButton
	assert_true(toggle != null, "the minigame tutorial toggle must exist")
	var original := GameSettings.minigame_tutorial_enabled
	toggle.button_pressed = not original
	await Engine.get_main_loop().process_frame
	assert_eq(GameSettings.minigame_tutorial_enabled, not original,
		"the toggle must write through to GameSettings")
	GameSettings.minigame_tutorial_enabled = original


func test_back_button_exists_and_is_wired() -> void:
	var back := _screen.find_child("BackButton", true, false) as BaseButton
	assert_true(back != null, "settings must be escapable")
	assert_true(back.pressed.get_connections().size() > 0,
		"back button must be wired")


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_labels_are_indonesian() -> void:
	var title := _screen.find_child("TitleLabel", true, false) as Label
	assert_eq(title.text, "PENGATURAN", "title must be Indonesian")
