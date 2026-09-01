@tool
extends McpTestSuite

## NOTE on the runner's two quirks this suite works around (unchanged
## from the pre-2026-09-01 layout):
##
## 1. No test may be a coroutine. The MCP runner calls
##    `suite.call(method_name)` without awaiting, so a test that hits an
##    `await` returns early and is scored as "0 assertions" (a false
##    pass). Anything that would need a frame wait (e.g. reading a
##    Container's post-sort `.size`) is instead measured via
##    `get_combined_minimum_size()`, which is computed on demand from the
##    theme with no dependency on a pending sort or frame.
##
## 2. A played game's root Window resolves the project theme through
##    ThemeDB automatically; that population never happens for the
##    editor's root while a suite runs inside the editor. So `setup()`
##    assigns the baked theme to the scene root explicitly -- mirroring
##    what the project setting does at real runtime, without changing
##    what is asserted.
##
## 2026-09-01: the three stacked MULAI / PENGATURAN / KELUAR buttons were
## replaced by a minimal layout -- MULAI is now a blinking "ketuk di mana
## saja" prompt and a tap anywhere starts the game; PENGATURAN and KELUAR
## are icon-only buttons (still the yellow MainMenuButton art) in a
## bottom IconBar. See Scripts/MainMenu/main_menu.gd.

func suite_name() -> String:
	return "main_menu"

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _SCRIPT_PATH := "res://Scripts/MainMenu/main_menu.gd"
const _LOGO_TOP_OFFSET := 68.0

var _menu: Control


func setup() -> void:
	var scene: PackedScene = load("res://Scenes/MainMenu/main_menu.tscn")
	_menu = scene.instantiate()
	_menu.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_menu)
	track(_menu)


func teardown() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _script_source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)


func _icon_button(name: String) -> Button:
	return _menu.find_child(name, true, false) as Button


# --- Centralised styling -----------------------------------------------------

func test_scene_has_no_theme_overrides() -> void:
	# Constants are deliberately excluded: SafeAreaMargin sets margin
	# constants and IconBar sets a separation constant, both allowed.
	var offenders: Array[String] = []
	_collect_overrides(_menu, offenders)
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


func test_content_is_wrapped_in_a_safe_area() -> void:
	var safe := _menu.find_child("SafeArea", true, false)
	assert_true(safe != null, "top-level content must sit inside a SafeAreaMargin")
	assert_true(safe is SafeAreaMargin, "must be a SafeAreaMargin")


# --- MULAI is now a tap-anywhere prompt ------------------------------------

func test_play_button_is_gone() -> void:
	assert_true(_menu.find_child("PlayButton", true, false) == null,
		"the MULAI Button must be removed -- MULAI is now a text prompt")


func test_tap_prompt_exists_and_is_indonesian() -> void:
	var prompt := _menu.find_child("TapPrompt", true, false) as Label
	assert_true(prompt != null, "TapPrompt label must exist")
	if prompt == null:
		return
	assert_true(prompt.text.strip_edges() != "", "TapPrompt must have text")
	assert_true(prompt.text.to_lower().contains("ketuk"),
		"TapPrompt copy must be Indonesian (contains 'ketuk')")
	assert_true(prompt.theme_type_variation != &"",
		"TapPrompt must be styled by a theme variation, not overrides")


func test_tap_prompt_blinks() -> void:
	var src := _script_source()
	assert_true(src.contains("_blink_forever"),
		"main_menu.gd must pulse the tap prompt")
	assert_true(src.contains('"modulate:a"'),
		"the blink must tween the prompt's alpha")


func test_nothing_full_screen_swallows_the_tap() -> void:
	# _unhandled_input only fires if no Control consumed the click first.
	# The root and the full-rect Background must therefore not hit-test,
	# or "tap anywhere to start" silently stops working.
	assert_eq(_menu.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the MainMenu root must not intercept taps")
	var bg := _menu.find_child("Background", true, false) as Control
	if bg != null:
		assert_eq(bg.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"the Background must not intercept taps")


func test_a_tap_anywhere_starts_the_game() -> void:
	var src := _script_source()
	# _unhandled_input (not _input) so the icon buttons' own presses,
	# which they accept_event(), never double-fire the start.
	assert_true(src.contains("func _unhandled_input("),
		"main_menu.gd must listen for a tap anywhere via _unhandled_input")
	assert_true(src.contains("func _start_game("),
		"main_menu.gd must have a _start_game entry point")
	assert_true(src.contains('"res://Scenes/CutScene/cut_scene.tscn"'),
		"a tap must transition into the cutscene")
	assert_true(src.contains("Transition.Style.WIPE"),
		"the intro transition must be the slow wipe")


# --- PENGATURAN / KELUAR are icon-only yellow buttons ---------------------

func test_icon_bar_is_a_horizontal_container() -> void:
	var bar := _menu.find_child("IconBar", true, false)
	assert_true(bar is HBoxContainer,
		"the two icon buttons must be laid out by an HBoxContainer")


func test_icon_buttons_exist_and_are_wired() -> void:
	for name in ["SettingButton", "QuitButton"]:
		var b := _icon_button(name)
		assert_true(b != null, "missing button: " + name)
		if b == null:
			continue
		assert_true(b.pressed.get_connections().size() > 0,
			name + " must have a pressed handler")
		assert_true(b.get_parent() is HBoxContainer,
			name + " must sit in the IconBar")


func test_icon_buttons_keep_the_yellow_menu_art() -> void:
	for name in ["SettingButton", "QuitButton"]:
		var b := _icon_button(name)
		if b == null:
			continue
		assert_eq(b.theme_type_variation, &"MainMenuButton",
			name + " must keep the MainMenuButton (yellow box) variation")


func test_icon_buttons_show_an_icon_and_no_text() -> void:
	for name in ["SettingButton", "QuitButton"]:
		var b := _icon_button(name)
		if b == null:
			continue
		assert_true(b.icon != null, name + " must have an icon")
		assert_eq(b.text, "", name + " must be icon-only (no label)")
		assert_true(b.expand_icon, name + " icon must scale to the button")


func test_icon_button_art_paths() -> void:
	var gear := _icon_button("SettingButton")
	if gear != null and gear.icon != null:
		assert_eq(gear.icon.resource_path, "res://Assets/Images/UI/setting.png",
			"gear icon art")
	var exit := _icon_button("QuitButton")
	if exit != null and exit.icon != null:
		assert_eq(exit.icon.resource_path, "res://Assets/Images/UI/icon_exit.svg",
			"exit icon art")


func test_icon_buttons_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	for name in ["SettingButton", "QuitButton"]:
		var b := _icon_button(name)
		if b == null:
			continue
		assert_true(b.custom_minimum_size.x >= float(tokens.touch_target_min),
			"%s width %d px is below the %d px minimum"
				% [name, int(b.custom_minimum_size.x), tokens.touch_target_min])
		assert_true(b.custom_minimum_size.y >= float(tokens.touch_target_min),
			"%s height %d px is below the %d px minimum"
				% [name, int(b.custom_minimum_size.y), tokens.touch_target_min])


# --- Background + floating logo ------------------------------------------

func test_background_uses_the_titlescreen_art() -> void:
	var bg := _menu.find_child("Background", true, false) as TextureRect
	assert_true(bg != null, "Background node must exist")
	if bg == null:
		return
	assert_eq(bg.texture.resource_path,
		"res://Assets/Images/UI/titlescreen_background.png", "background art")


func test_logo_sits_at_the_measured_offset() -> void:
	var logo := _menu.find_child("Logo", true, false) as TextureRect
	assert_true(logo != null, "Logo node must exist")
	if logo == null:
		return
	assert_eq(logo.texture.resource_path, "res://Assets/Images/UI/logo.png",
		"logo art")
	assert_eq(logo.offset_top, _LOGO_TOP_OFFSET, "logo top offset")
	assert_eq(logo.offset_bottom, _LOGO_TOP_OFFSET + 1080.0,
		"logo must be drawn at its native 1080 px height, unscaled")


func test_logo_floats_slowly() -> void:
	var src := _script_source()
	assert_true(src.contains("_float_forever"),
		"main_menu.gd must drift the logo")
	assert_true(src.contains('"position:y"'),
		"the float must animate the logo's Y position")


func test_logo_has_a_drop_shadow_behind_it() -> void:
	var logo := _menu.find_child("Logo", true, false) as TextureRect
	var shadow := _menu.find_child("LogoShadow", true, false) as TextureRect
	assert_true(shadow != null, "LogoShadow node must exist")
	if shadow == null or logo == null:
		return
	assert_eq(shadow.texture.resource_path, logo.texture.resource_path,
		"the shadow must be the same art as the logo")
	# Drawn first => rendered behind the real logo.
	assert_true(shadow.get_index() < logo.get_index(),
		"LogoShadow must be ordered before Logo so it renders behind it")
	assert_true(shadow.modulate.a < 1.0 and shadow.modulate.v < 0.5,
		"the shadow must be a darkened, semi-transparent copy")
	# Offset from the logo so the shadow actually reads.
	assert_true(shadow.offset_top != logo.offset_top
			or shadow.offset_left != logo.offset_left,
		"the shadow must be offset from the logo")


# --- The old stacked layout is fully gone ------------------------------

func test_old_layout_nodes_are_removed() -> void:
	for name in ["ButtonColumn", "Layout", "TitleSpacer", "MidSpacer",
			"BottomSpacer", "SubtitleLabel", "TitleLabel"]:
		assert_true(_menu.find_child(name, true, false) == null,
			name + " must be removed")
