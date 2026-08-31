@tool
extends McpTestSuite

## NOTE on test technique: the brief's original draft used
## `await Engine.get_main_loop().process_frame` (twice) in
## test_buttons_meet_the_minimum_touch_target to let VBoxContainer finish
## sizing PlayButton/SettingButton/QuitButton before reading `.size.y`.
## Per test_ui_components.gd's and test_juice.gd's established finding,
## the MCP test runner's `_run_one_test` calls `suite.call(method_name)`
## without awaiting it, so a coroutine test returns control at its first
## `await` before any post-await assertion runs, and is scored as
## "0 assertions" (a false pass, not a real one).
##
## Unlike test_ui_components.gd's case (_ready() side effects, which run
## synchronously inside add_child() and just needed the await deleted),
## this measurement is different: `.size` reflects the result of
## VBoxContainer's *sort pass*, which Container schedules via
## `queue_sort()` -> a deferred call flushed from the message queue, not
## something add_child() executes inline. Deleting the await outright and
## reading `.size` immediately measured 0x0 in a manual check.
##
## Fix: measure `get_combined_minimum_size().y` instead of `.size.y`.
## These buttons carry no SIZE_EXPAND flag, so a VBoxContainer always
## gives each of them exactly its combined minimum size on the cross
## axis — the sort pass can only ever settle them there. The minimum
## size itself is computed on demand from the theme (stylebox content
## margins + font metrics) with no dependency on any pending sort or
## frame, so it is safe to read synchronously right after add_child().
## This keeps the test's intent (buttons must be tappable) while making
## it correct under the runner's synchronous call convention.

func suite_name() -> String:
	return "main_menu"

var _menu: Control


## NOTE on theme cascade: a *played* game's root Window automatically
## resolves the project's "gui/theme/custom" setting through ThemeDB as
## the ultimate theme fallback, which is why PrimaryButton/SecondaryButton
## etc. render correctly at runtime. Empirically, that population never
## happens for `Engine.get_main_loop().root` while running *inside the
## editor* (this suite's context) -- ThemeDB's project theme is only
## loaded when the game actually starts playing. Diagnosed by printing
## the resolved stylebox for a button explicitly typed "PrimaryButton":
## it came back with content_margin 6/6 and font_size 14, i.e. Godot's
## built-in engine-default Button metrics, not this project's baked
## theme at all. Without a fix, every size/stylebox-dependent assertion
## in this suite would silently measure the wrong theme.
## Fix: explicitly assign the baked theme to the scene root so this
## subtree's cascade resolves through it directly, independent of
## ThemeDB. This mirrors what the project setting does automatically at
## real runtime; it does not change what is being asserted.
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

## The mockup's cap height implies font size 100, but Milker sets
## "PENGATURAN" 755 px wide at 100 against a 624 px inner box. This asserts
## the compromise (80) actually holds, so a future copy or size change cannot
## silently clip the longest label. Inner box = the button's 670 px width
## minus the art's 3 px border each side minus 20 px content margin each side.
const _BUTTON_WIDTH := 670.0


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


func test_scene_has_no_theme_overrides() -> void:
	# The whole point of centralization: this scene must be styled
	# entirely by the project theme.
	var offenders: Array[String] = []
	_collect_overrides(_menu, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


## NOTE on API correctness: the brief's original draft called
## `get_theme_font_size_override_list()` / `get_theme_color_override_list()`
## / `get_theme_stylebox_override_list()` on a Control. None of the three
## exist on Godot 4.6's Control class (confirmed against the live editor's
## ClassDB via api_manage — Control declares 174 methods total, none named
## `get_theme_*_override_list`; what it does have is per-name checks:
## `has_theme_color_override(name)`, `has_theme_font_size_override(name)`,
## `has_theme_stylebox_override(name)`, etc.). Calling the nonexistent
## methods aborted the whole suite with a script error rather than failing
## individual assertions.
##
## Fixed by walking `get_property_list()` for the three override
## categories the original check cared about (colors, font_sizes, styles
## — constants/fonts/icons are deliberately excluded, matching the
## original intent: SafeAreaMargin legitimately sets constant overrides
## for its margins, and that must not trip this test) and asking the
## matching `has_theme_*_override()` whether that specific item was
## actually set on this node instance.
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


func test_all_three_buttons_exist_and_are_wired() -> void:
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as BaseButton
		assert_true(b != null, "missing button: " + name)
		assert_true(b.pressed.get_connections().size() > 0,
			name + " must have a pressed handler")


func test_buttons_use_theme_variations_not_default_styling() -> void:
	# All three menu buttons now share one variation: the mockup draws them
	# identically, with no primary/secondary distinction.
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as Button
		assert_eq(b.theme_type_variation, &"MainMenuButton",
			name + " must use the MainMenuButton variation")


func test_buttons_meet_the_minimum_touch_target() -> void:
	# See header note: measured via combined minimum size, not `.size`,
	# so this assertion is correct without any frame wait.
	var tokens := DesignTokens.load_default()
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as Control
		var h := b.get_combined_minimum_size().y
		assert_true(h >= float(tokens.touch_target_min),
			"%s has minimum height %d px, below the %d px minimum"
				% [name, int(h), tokens.touch_target_min])


func test_button_labels_are_indonesian() -> void:
	# The rest of the game is Indonesian; PLAY/SETTING/QUIT were leftovers.
	var play := _menu.find_child("PlayButton", true, false) as Button
	assert_eq(play.text, "MULAI", "play button")
	var setting := _menu.find_child("SettingButton", true, false) as Button
	assert_eq(setting.text, "PENGATURAN", "setting button")
	var quit := _menu.find_child("QuitButton", true, false) as Button
	assert_eq(quit.text, "KELUAR", "quit button")


func test_layout_uses_containers_not_absolute_offsets() -> void:
	# The three buttons must be spaced by the container's separation
	# constant, not by three hand-placed rects.
	var play := _menu.find_child("PlayButton", true, false) as Control
	var parent := play.get_parent()
	assert_true(parent is BoxContainer,
		"buttons must be laid out by a container, not pixel offsets")


func test_every_label_fits_inside_the_button_at_the_baked_font_size() -> void:
	var theme: Theme = load(_THEME_PATH)
	var font := theme.get_font("font", "MainMenuButton")
	var font_size := theme.get_font_size("font_size", "MainMenuButton")
	assert_true(font != null, "MainMenuButton must have a font")

	# Inner width is derived live from the baked stylebox's own content
	# margins (owned by ThemeFactory._build_main_menu_button), not a
	# hardcoded copy of them -- so a future margin change is caught here
	# instead of silently letting the real button clip its label.
	var sb := theme.get_stylebox("normal", "MainMenuButton")
	var inner_width := _BUTTON_WIDTH - 2.0 * 3.0 - sb.content_margin_left - sb.content_margin_right

	for label in ["MULAI", "PENGATURAN", "KELUAR"]:
		var w := font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		assert_true(w <= inner_width,
			"%s renders %d px wide, over the %d px inner box"
				% [label, int(w), int(inner_width)])


## Measured from docs/superpowers/mockups/main-menu.png; see
## docs/superpowers/specs/2026-08-31-main-menu-mockup.md for the probe trail.
## The mockup's own button pitch drifts (gaps of 69 and 64 px); 66 is the
## normalisation that lands the column's bottom edge on the measured 1626.
const _BUTTON_HEIGHT := 126
const _BUTTON_SEPARATION := 66
const _COLUMN_HEIGHT := 3 * _BUTTON_HEIGHT + 2 * _BUTTON_SEPARATION  # 510
const _LOGO_TOP_OFFSET := 68.0


func test_background_uses_the_titlescreen_art() -> void:
	var bg := _menu.find_child("Background", true, false) as TextureRect
	assert_true(bg != null, "Background node must exist")
	if bg == null:
		return
	assert_eq(bg.texture.resource_path,
		"res://Assets/Images/UI/titlescreen_background.png",
		"background art")


func test_logo_sits_at_the_measured_offset() -> void:
	var logo := _menu.find_child("Logo", true, false) as TextureRect
	assert_true(logo != null, "Logo node must exist")
	if logo == null:
		return
	assert_eq(logo.texture.resource_path, "res://Assets/Images/UI/logo.png",
		"logo art")
	# Correlating logo.png against the mockup put the optimum at scale 1.0,
	# offset (0, 68) with a sharp 1-px minimum.
	assert_eq(logo.offset_top, _LOGO_TOP_OFFSET, "logo top offset")
	assert_eq(logo.offset_bottom, _LOGO_TOP_OFFSET + 1080.0,
		"logo must be drawn at its native 1080 px height, unscaled")


func test_button_column_matches_the_mockup_rect() -> void:
	var col := _menu.find_child("ButtonColumn", true, false) as VBoxContainer
	assert_true(col != null, "ButtonColumn must exist and be a VBoxContainer")
	if col == null:
		return

	# Horizontally centred, 670 wide.
	assert_eq(col.anchor_left, 0.5, "column left anchor")
	assert_eq(col.anchor_right, 0.5, "column right anchor")
	assert_eq(col.offset_right - col.offset_left, _BUTTON_WIDTH,
		"column width")

	# Pinned to the bottom of the safe area, 510 tall.
	assert_eq(col.anchor_top, 1.0, "column top anchor")
	assert_eq(col.anchor_bottom, 1.0, "column bottom anchor")
	# Bottom inset derives from the mockup's measured column bottom (y=1626)
	# against the full 1920-tall viewport, minus DesignTokens' live
	# screen_margin -- NOT a hardcoded literal, so a future screen_margin
	# change is caught here instead of silently drifting off the mockup.
	var margin := float(DesignTokens.load_default().screen_margin)
	assert_eq(col.offset_bottom, -(1920.0 - 1626.0 - margin), "column bottom inset")
	assert_eq(col.offset_bottom - col.offset_top, float(_COLUMN_HEIGHT),
		"column height")

	assert_eq(col.get_theme_constant("separation"), _BUTTON_SEPARATION,
		"button separation")


func test_each_button_is_the_measured_height_and_uses_the_menu_variation() -> void:
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as Button
		assert_eq(b.custom_minimum_size.y, float(_BUTTON_HEIGHT),
			name + " height")
		assert_eq(b.theme_type_variation, &"MainMenuButton",
			name + " must use the MainMenuButton variation")


func test_the_subtitle_is_gone() -> void:
	# The mockup shows only the logo and three buttons -- everything from
	# the old spacer-ratio layout must be gone, not just the subtitle.
	for name in ["SubtitleLabel", "TitleLabel", "Layout", "TitleSpacer", "MidSpacer", "BottomSpacer"]:
		assert_true(_menu.find_child(name, true, false) == null,
			name + " must be removed")
