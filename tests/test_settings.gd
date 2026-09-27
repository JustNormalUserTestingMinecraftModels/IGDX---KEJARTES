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

const _MIXER_BUSES := ["Master", "BGM", "SFX"]

var _screen: Control
var _saved_bus_state: Array[Dictionary] = []

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const LayoutFrame := preload("res://tests/layout_frame.gd")


func setup() -> void:
	# test_moving_a_slider_changes_the_bus_volume drives AudioServer through
	# the real AudioDirector autoload, not a disposable instance -- the same
	# class of leak already fixed in test_audio_director.gd. Snapshot here,
	# restore in teardown, for the same reason: AudioServer buses are
	# process-global, and a leftover slider value gets written into the
	# committed Assets/Audio/default_bus_layout.tres.
	_saved_bus_state.clear()
	for bus in _MIXER_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			_saved_bus_state.append({
				"idx": idx,
				"db": AudioServer.get_bus_volume_db(idx),
				"mute": AudioServer.is_bus_mute(idx),
			})

	var scene: PackedScene = load("res://Scenes/UI/Settings.tscn")
	_screen = scene.instantiate()
	_screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null

	for state in _saved_bus_state:
		AudioServer.set_bus_volume_db(state["idx"], state["db"])
		AudioServer.set_bus_mute(state["idx"], state["mute"])
	_saved_bus_state.clear()


func test_scene_loads() -> void:
	assert_true(_screen != null, "Settings.tscn must exist and instantiate")


func test_has_a_slider_for_each_audio_bus() -> void:
	for name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(name, true, false)
		assert_true(s != null, "missing slider: " + name)
		assert_true(s is Slider, name + " must be a Slider")


func test_moving_a_slider_changes_the_bus_volume() -> void:
	# No frame-wait needed: Range.value's setter emits value_changed
	# synchronously when the value actually changes, and the MCP test
	# runner's suite.call() doesn't await coroutine test methods anyway
	# (an `await` here would silently truncate the test to 0 assertions).
	var slider := _screen.find_child("SfxSlider", true, false) as Slider
	slider.value = 0.3
	assert_true(absf((AudioDirector.get_bus_volume(&"SFX")) - (0.3)) <= 0.02, "the slider must drive the bus")


func test_tutorial_toggle_reflects_and_writes_game_settings() -> void:
	# Same reasoning: BaseButton.button_pressed's setter emits `toggled`
	# synchronously, so no frame-wait is needed or safe to await here.
	var toggle := _screen.find_child("TutorialToggle", true, false) as CheckButton
	assert_true(toggle != null, "the minigame tutorial toggle must exist")
	var original := GameSettings.minigame_tutorial_enabled
	toggle.button_pressed = not original
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


func test_bgm_slider_gives_audible_feedback() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	assert_true(src.contains('&"BGM"') and src.contains('play_sfx(&"pop")'),
		"dragging the Musik slider must preview a sound, like the SFX slider does")


func test_haptics_and_reduce_motion_persist() -> void:
	GameSettings.haptics_enabled = false
	GameSettings.reduce_motion = true
	GameSettings.save_settings()
	GameSettings.haptics_enabled = true
	GameSettings.reduce_motion = false
	GameSettings.load_settings()
	assert_false(GameSettings.haptics_enabled, "haptics_enabled round-trips through save/load")
	assert_true(GameSettings.reduce_motion, "reduce_motion round-trips through save/load")
	# restore defaults so other tests are unaffected
	GameSettings.haptics_enabled = true
	GameSettings.reduce_motion = false
	GameSettings.save_settings()


func test_settings_screen_exposes_haptics_and_motion() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	assert_true(src.contains("GameSettings.haptics_enabled ="),
		"Settings must write haptics_enabled from its toggle")
	assert_true(src.contains("GameSettings.reduce_motion ="),
		"Settings must write reduce_motion from its toggle")

## Efek Suasana (ambient kit, 2026-09-26) is on until the player says
## otherwise: a fresh GameSettings, before any load, holds true.
func test_ambient_effects_default_on() -> void:
	var fresh: Node = (load("res://Scripts/GameSettings.gd") as GDScript).new()
	assert_true(fresh.get("ambient_effects_enabled"), "Efek Suasana defaults to on")
	fresh.free()


func test_ambient_effects_persist() -> void:
	GameSettings.ambient_effects_enabled = false
	GameSettings.save_settings()
	GameSettings.ambient_effects_enabled = true
	GameSettings.load_settings()
	assert_false(GameSettings.ambient_effects_enabled,
		"ambient_effects_enabled round-trips through save/load")
	GameSettings.ambient_effects_enabled = true
	GameSettings.save_settings()


## The kit follows both switches by signal. Each flip emits once, and setting
## the value it already holds emits nothing.
func test_the_kit_switches_announce_their_flips() -> void:
	var heard: Array = []
	var on_ambient := func(_enabled: bool) -> void: heard.append("ambient")
	var on_motion := func(_still: bool) -> void: heard.append("motion")
	GameSettings.ambient_effects_changed.connect(on_ambient)
	GameSettings.reduce_motion_changed.connect(on_motion)
	GameSettings.ambient_effects_enabled = false
	GameSettings.ambient_effects_enabled = false
	GameSettings.reduce_motion = true
	GameSettings.ambient_effects_changed.disconnect(on_ambient)
	GameSettings.reduce_motion_changed.disconnect(on_motion)
	GameSettings.ambient_effects_enabled = true
	GameSettings.reduce_motion = false
	assert_eq(heard, ["ambient", "motion"], "one emit per real flip, none for a repeat")


func test_ambient_toggle_reflects_and_writes_game_settings() -> void:
	var toggle := _screen.find_child("AmbientToggle", true, false) as CheckButton
	assert_true(toggle != null, "Efek Suasana needs its toggle")
	if toggle == null:
		return
	assert_eq(toggle.button_pressed, GameSettings.ambient_effects_enabled,
		"the toggle opens on the current value")
	var original := GameSettings.ambient_effects_enabled
	toggle.button_pressed = not original
	assert_eq(GameSettings.ambient_effects_enabled, not original,
		"the toggle must write through to GameSettings")
	GameSettings.ambient_effects_enabled = original


## Efek Suasana sits right after Efek Visual, labelled in Indonesian.
func test_ambient_card_sits_after_the_look_layer_card() -> void:
	var layout := _screen.find_child("Layout", true, false)
	var look := layout.get_node_or_null("LookLayerCard")
	var ambient := layout.get_node_or_null("AmbientCard")
	assert_true(ambient != null, "Settings needs an AmbientCard")
	if look == null or ambient == null:
		return
	assert_eq(ambient.get_index(), look.get_index() + 1,
		"Efek Suasana sits right after Efek Visual")
	var label := ambient.find_child("AmbientLabel", true, false) as Label
	assert_eq(label.text, "Efek Suasana", "the card is labelled in Indonesian")


## Every card and the back button still fit a 1080x1920 screen.
func test_every_row_fits_the_design_screen() -> void:
	var frame := track(LayoutFrame.stand_up("res://Scenes/UI/Settings.tscn",
		Vector2(1080, 1920))) as Control
	var back := frame.find_child("BackButton", true, false) as Control
	assert_true(back != null, "Settings needs its BackButton")
	if back == null:
		return
	assert_true(back.get_global_rect().end.y <= frame.get_global_rect().end.y,
		"the back button must end inside the screen, not below it")
