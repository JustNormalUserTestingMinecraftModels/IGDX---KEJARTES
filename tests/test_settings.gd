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
## Each section card: its heading, then its rows in order.
const _SECTIONS := {
	"AudioCard": ["SUARA", ["MasterRow", "BgmRow", "SfxRow"]],
	"GameplayCard": ["PERMAINAN", ["TutorialRow", "SkipDialogRow"]],
	"DisplayCard": ["TAMPILAN", ["LookLayerRow", "AmbientRow", "ReduceMotionRow", "HapticsRow"]],
}
## Each switch row's words.
const _ROW_LABELS := {
	"TutorialRow": "Tutorial Minigame", "SkipDialogRow": "Lewati Dialog Minigame",
	"LookLayerRow": "Efek Visual", "AmbientRow": "Efek Suasana",
	"ReduceMotionRow": "Kurangi Gerakan", "HapticsRow": "Getaran (Haptic)",
}
## Each switch row's GameSettings property.
const _ROW_SETTINGS := {
	"TutorialRow": "minigame_tutorial_enabled", "SkipDialogRow": "skip_event_dialogue",
	"LookLayerRow": "look_layer_enabled", "AmbientRow": "ambient_effects_enabled",
	"ReduceMotionRow": "reduce_motion", "HapticsRow": "haptics_enabled",
}
const _ROW_SCRIPT := "res://Scripts/UI/SettingsToggleRow.gd"


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


## The switch inside the SettingsToggleRow named `row_name`, or null.
func _toggle(row_name: String) -> CheckButton:
	var row := _screen.find_child(row_name, true, false)
	return (row.get_node_or_null("Toggle") as CheckButton) if row != null else null


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


func test_backdrop_is_the_blurred_lobby() -> void:
	var bg := _screen.get_node_or_null("Background") as TextureRect
	assert_true(bg != null and bg.texture != null, "Settings needs its Background")
	if bg == null or bg.texture == null:
		return
	assert_eq(bg.texture.resource_path, "res://Assets/Images/UI/blur_background.png",
		"Settings sits on the blurred Lobby, like its siblings")


## Inventory's header card, holding only the DisplayLabel title.
func test_header_is_a_title_card() -> void:
	var header := _screen.get_node_or_null("SafeArea/MainColumn/Header") as PanelContainer
	assert_true(header != null, "Settings needs SafeArea/MainColumn/Header")
	if header == null:
		return
	assert_eq(header.theme_type_variation, &"Card", "the header is a Card")
	var title := header.get_node_or_null("TitleLabel") as Label
	assert_true(title != null and title.theme_type_variation == &"DisplayLabel",
		"the header holds the DisplayLabel title")
	assert_eq(header.get_child_count(), 1, "the header holds the title and nothing else")


## Kembali sits at the bottom of the screen, centred under the cards, like
## ShopHub's: the last child of MainColumn, after the scroll.
func test_back_button_sits_at_the_bottom() -> void:
	var column := _screen.get_node_or_null("SafeArea/MainColumn")
	var back := _screen.get_node_or_null("SafeArea/MainColumn/BackButton") as Button
	assert_true(column != null and back != null, "Kembali is a child of MainColumn")
	if column == null or back == null:
		return
	assert_eq(back.get_index(), column.get_child_count() - 1, "Kembali is the column's last child")
	assert_eq(back.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "Kembali is centred")
	assert_eq(back.theme_type_variation, &"SecondaryButton", "Kembali is a SecondaryButton")
	assert_eq(back.text, "Kembali", "Kembali, as on ShopHub and Inventory")


func test_sections_scroll_under_the_header() -> void:
	var scroll := _screen.get_node_or_null("SafeArea/MainColumn/Scroll") as ScrollContainer
	assert_true(scroll != null, "Settings needs SafeArea/MainColumn/Scroll")
	if scroll == null:
		return
	assert_eq(scroll.size_flags_vertical, Control.SIZE_EXPAND_FILL, "the scroll takes the rest")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"it never scrolls sideways")
	assert_true(scroll.get_node_or_null("Pad/Sections") != null, "the cards sit in Pad/Sections")


## Three titled cards, in order, each holding its rows in order with one
## SettingsDivider between neighbours.
func test_settings_are_grouped_into_three_titled_cards() -> void:
	var sections := _screen.find_child("Sections", true, false)
	assert_true(sections != null, "Settings needs its Sections column")
	if sections == null:
		return
	var names: Array = []
	for card in sections.get_children():
		names.append(String(card.name))
	assert_eq(names, _SECTIONS.keys(), "the three cards, in order")
	for card_name in _SECTIONS:
		var vbox := sections.get_node_or_null("%s/Margin/VBox" % card_name)
		assert_true(vbox != null, card_name + " needs Margin/VBox")
		if vbox == null:
			continue
		assert_eq((sections.get_node(card_name) as Control).theme_type_variation, &"Card",
			card_name + " is a Card")
		var heading := vbox.get_child(0) as Label
		assert_true(heading != null and heading.theme_type_variation == &"CardSectionLabel",
			card_name + " opens with a CardSectionLabel")
		if heading != null:
			assert_eq(heading.text, _SECTIONS[card_name][0], card_name + " heading")
		var rows: Array = []
		for i in range(1, vbox.get_child_count()):
			var child := vbox.get_child(i)
			if child is HSeparator:
				assert_eq((child as HSeparator).theme_type_variation, &"SettingsDivider",
					card_name + " rules are SettingsDividers")
			else:
				rows.append(String(child.name))
		assert_eq(rows, _SECTIONS[card_name][1], card_name + " rows, in order")
		assert_eq(vbox.get_child_count(), 2 * rows.size(),
			card_name + ": heading, rows, and one rule between each pair")


func test_every_switch_row_is_the_template_labelled_in_indonesian() -> void:
	for row_name in _ROW_LABELS:
		var row := _screen.find_child(row_name, true, false)
		assert_true(row != null, "Settings needs " + row_name)
		if row == null:
			continue
		assert_eq((row.get_script() as Script).resource_path, _ROW_SCRIPT,
			row_name + " is a SettingsToggleRow")
		assert_eq((row.get_node("Label") as Label).text, _ROW_LABELS[row_name],
			row_name + " is labelled in Indonesian")
		assert_eq(_toggle(row_name).theme_type_variation, &"SettingsSwitch",
			row_name + " wears the brand switch")
		assert_eq(row.toggle, _toggle(row_name), row_name + ".toggle is its switch")


func test_every_slider_wears_the_brand_slider() -> void:
	for slider_name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(slider_name, true, false) as HSlider
		assert_true(s != null and s.theme_type_variation == &"SettingsSlider",
			slider_name + " is a SettingsSlider")


## Every switch opens on its setting and writes it back. It is restored
## through the switch itself, so any setting it saved is saved back too.
func test_every_switch_opens_on_and_writes_its_setting() -> void:
	for row_name in _ROW_SETTINGS:
		var key: String = _ROW_SETTINGS[row_name]
		var toggle := _toggle(row_name)
		assert_true(toggle != null, row_name + " needs its Toggle")
		if toggle == null:
			continue
		var original: bool = GameSettings.get(key)
		assert_eq(toggle.button_pressed, original, row_name + " opens on " + key)
		toggle.button_pressed = not original
		assert_eq(GameSettings.get(key), not original, row_name + " writes " + key)
		toggle.button_pressed = original


## At 1080x1920 all three cards fit above the scroll's bottom edge: 9:16
## never scrolls.
func test_every_card_fits_the_design_screen_without_scrolling() -> void:
	var frame := track(LayoutFrame.stand_up("res://Scenes/UI/Settings.tscn",
		Vector2(1080, 1920))) as Control
	var scroll := frame.find_child("Scroll", true, false) as Control
	var last := frame.find_child("DisplayCard", true, false) as Control
	assert_true(scroll != null and last != null, "Settings needs Scroll and DisplayCard")
	if scroll == null or last == null:
		return
	assert_true(last.get_global_rect().end.y <= scroll.get_global_rect().end.y,
		"TAMPILAN ends at %d, below the scroll's %d" % [
			last.get_global_rect().end.y, scroll.get_global_rect().end.y])
