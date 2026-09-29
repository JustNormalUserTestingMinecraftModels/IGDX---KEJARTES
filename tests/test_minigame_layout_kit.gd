@tool
extends McpTestSuite

## The minigame mobile-layout kit (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 3):
## its icons, theme variations, tray, hint pill, how-to rows and resources.
## Each piece is pinned by the task that adds it. Must be @tool, and no
## test here may be a coroutine.

const ICON_DIR := "res://Assets/Images/UI/Icons/"
## Every placeholder pictogram the layout kit points at.
const KIT_ICONS: Array[String] = ["pause", "timer", "swipe_up", "howto_tap",
	"howto_swipe", "howto_drag", "howto_read", "howto_timer", "howto_target"]


func suite_name() -> String:
	return "minigame_layout_kit"


func test_every_kit_icon_exists() -> void:
	for icon: String in KIT_ICONS:
		var path := ICON_DIR + icon + ".svg"
		assert_true(ResourceLoader.exists(path), path + " is a kit icon")


func test_every_kit_icon_is_listed_in_the_readme() -> void:
	var readme := FileAccess.get_file_as_string(ICON_DIR + "README.md")
	for icon: String in KIT_ICONS:
		assert_contains(readme, "`" + icon + ".svg`", icon + " has a README row")


const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## variation -> the base type it must extend.
const LAYOUT_VARIATIONS := {
	"MinigameProgressBar": "ProgressBar",
	"MinigameProgressLabel": "Label",
	"MinigameTrayPanel": "Panel",
	"MinigameHintLabel": "Label",
	"MinigameHintPillPanel": "Panel",
	"MinigameHowToLabel": "Label",
}


func _theme() -> Theme:
	return ThemeFactory.build(DesignTokens.load_default())


func test_layout_variations_exist_with_their_base() -> void:
	var theme := _theme()
	for name: String in LAYOUT_VARIATIONS:
		assert_eq(String(theme.get_type_variation_base(name)), LAYOUT_VARIATIONS[name],
			name + " extends " + LAYOUT_VARIATIONS[name])


func test_hints_and_how_to_lines_use_the_body_face_at_36() -> void:
	var theme := _theme()
	var tokens := DesignTokens.load_default()
	for name: String in ["MinigameHintLabel", "MinigameHowToLabel"]:
		assert_eq(theme.get_font_size("font_size", name), tokens.font_title, name + " is 36")
		# get_font_list, not has_font: has_font is also true with a default font.
		assert_false(theme.get_font_list(name).has("font"), name + " keeps the body face")


func test_the_progress_label_is_display_face_at_the_dense_rung() -> void:
	var theme := _theme()
	var tokens := DesignTokens.load_default()
	assert_eq(theme.get_font_size("font_size", "MinigameProgressLabel"), tokens.font_body_size)
	assert_eq(theme.get_font("font", "MinigameProgressLabel"), tokens.font_display)


func test_the_tray_plank_bleeds_past_its_rect() -> void:
	var box := _theme().get_stylebox("panel", "MinigameTrayPanel") as StyleBoxFlat
	assert_true(box != null, "the tray plank is a StyleBoxFlat")
	if box == null:
		return
	assert_true(box.expand_margin_bottom > 0.0 and box.expand_margin_left > 0.0,
		"the plank draws past the safe area to the screen edges")
	assert_eq(box.corner_radius_bottom_left, 0, "square bottom corners")


func test_the_hud_icon_button_is_lipped() -> void:
	var box := _theme().get_stylebox("normal", "MinigameHudIconButton")
	assert_true(LippedBox.is_lipped(box), "the pause/timer chrome is a lipped face")


const TRAY := "res://Scenes/Minigames/UI/MinigameTray.tscn"
const PILL := "res://Scenes/Minigames/UI/MinigameHintPill.tscn"


func _tray_with(children: int) -> MinigameTray:
	var tray := (load(TRAY) as PackedScene).instantiate() as MinigameTray
	for i in children:
		var c := Control.new()
		c.custom_minimum_size = Vector2(0, 100)
		tray.add_child(c)
	tray.hint_text = "Ketuk jawaban yang benar"
	tray.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# A VBox frame sizes the tray (full width, content height), so the test
	# never calls set_size on a node whose anchors are unequal.
	var frame := VBoxContainer.new()
	frame.size = Vector2(984, 1000)
	frame.theme = load(THEME_PATH)
	frame.add_child(tray)
	Engine.get_main_loop().root.add_child(frame)
	track(frame)
	frame.notification(Container.NOTIFICATION_SORT_CHILDREN)
	tray.sort_now()
	return tray


func test_the_tray_stacks_host_content_above_its_hint() -> void:
	var tray := _tray_with(2)
	var hint := tray.get_node("HintLabel") as Control
	var first := tray.get_child(tray.get_child_count() - 2) as Control
	var second := tray.get_child(tray.get_child_count() - 1) as Control
	assert_true(first.position.y < second.position.y, "host children stack in order")
	assert_true(second.position.y + second.size.y <= hint.position.y, "the hint is last")
	assert_true(hint.has_meta(MinigameTray.HINT_META), "the hint is tray chrome, not host content")


func test_the_tray_is_as_tall_as_its_content() -> void:
	var one := _tray_with(1).get_combined_minimum_size().y
	var two := _tray_with(2).get_combined_minimum_size().y
	var probe := MinigameTray.new()
	var sep := probe.separation
	probe.free()
	assert_true(is_equal_approx(two - one, 100.0 + sep),
		"each host row adds its height plus one separation")


## Regression: an autowrapping Label measured before it has a width reports
## one character per line, which blew the tray's minimum height up to ~1200px.
## The hint is a one-line caption that ellipsises instead.
func test_a_long_hint_never_makes_the_tray_tall() -> void:
	var tray := _tray_with(1)
	tray.set_hint("Ketuk jawaban yang benar. ".repeat(8))
	var hint := tray.get_node("HintLabel") as Label
	assert_eq(hint.autowrap_mode, TextServer.AUTOWRAP_OFF, "the hint does not wrap")
	assert_true(tray.get_combined_minimum_size().y < 300.0,
		"one 100px row plus a long hint stays short (was %s)" % tray.get_combined_minimum_size().y)


func test_tray_settle_fades_the_hint_but_never_hides_it() -> void:
	var tray := _tray_with(1)
	tray.set_hint("Ketuk jawaban yang benar")
	var hint := tray.get_node("HintLabel") as Label
	assert_eq(hint.text, "Ketuk jawaban yang benar")
	tray.settle()
	assert_true(is_equal_approx(hint.modulate.a, MinigameTray.SETTLED_ALPHA))
	tray.set_hint("Urutan salah!")
	assert_true(is_equal_approx(hint.modulate.a, 1.0), "a new hint comes back at full strength")


func test_the_pill_ignores_taps_and_shows_its_icon() -> void:
	var pill := (load(PILL) as PackedScene).instantiate() as MinigameHintPill
	pill.icon_texture = load(ICON_DIR + "swipe_up.svg")
	Engine.get_main_loop().root.add_child(pill)
	track(pill)
	assert_eq(pill.mouse_filter, Control.MOUSE_FILTER_IGNORE, "gestures pass through")
	assert_true((pill.get_node("%Icon") as TextureRect).visible, "an icon shows when set")
	pill.set_hint("Geser ke atas untuk menendang")
	assert_eq((pill.get_node("%HintLabel") as Label).text, "Geser ke atas untuk menendang")
	pill.settle()
	assert_true(is_equal_approx((pill.get_node("%HintLabel") as Label).modulate.a,
		MinigameHintPill.SETTLED_ALPHA))


const HOW_TO_DIR := "res://Resources/Minigames/HowTo/"
const GAMES: Array[String] = ["PilihanGanda", "Password", "Variabel", "Menjodohkan",
	"BuatBatik", "MainBola", "Badminton", "LombaMenari"]
## The banned pictograph ranges (style guide, "No emoji or dingbats").
const BANNED := [[0x2300, 0x23FF], [0x2600, 0x27BF], [0x2B00, 0x2BFF],
	[0x1F000, 0x1FAFF], [0xFE0F, 0xFE0F]]


func _has_banned(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		for r in BANNED:
			if c >= r[0] and c <= r[1]:
				return true
	return false


func test_every_game_has_a_how_to_card_of_two_or_three_steps() -> void:
	for game: String in GAMES:
		var how := load(HOW_TO_DIR + game + ".tres") as MinigameHowTo
		assert_true(how != null, game + " has a MinigameHowTo")
		if how == null:
			continue
		assert_true(how.title != "", game + " has a title")
		assert_true(how.steps.size() >= 2 and how.steps.size() <= 3, game + ": 2-3 steps")
		for step in how.steps:
			assert_true(step.icon != null, game + ": every step has a picture")
			assert_false(step.text.to_lower().contains("lorem"), game + ": no placeholder text")
			assert_false(_has_banned(step.text + how.title), game + ": no emoji")


func test_a_step_row_shows_its_picture_and_line() -> void:
	var row := (load("res://Scenes/Minigames/UI/HowToStepRow.tscn") as PackedScene).instantiate()
	row.icon_texture = load(ICON_DIR + "howto_tap.svg")
	row.step_text = "Ketuk jawaban yang benar."
	Engine.get_main_loop().root.add_child(row)
	track(row)
	assert_eq((row.get_node("%Icon") as TextureRect).texture, row.icon_texture)
	var text := row.get_node("%Text") as Label
	assert_eq(text.text, "Ketuk jawaban yang benar.")
	assert_eq(text.theme_type_variation, &"MinigameHowToLabel")


const TUTORIAL := "res://Scenes/Minigames/UI/MinigameTutorial.tscn"


func test_the_card_fills_one_row_per_step_and_the_title() -> void:
	var card := (load(TUTORIAL) as PackedScene).instantiate() as MinigameTutorial
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.setup(load(HOW_TO_DIR + "PilihanGanda.tres"))
	assert_eq((card.get_node("%GameTitle") as Label).text, "Pilihan Ganda")
	assert_eq(card.get_node("%Steps").get_child_count(), 3, "one HowToStepRow per step")


func test_only_mulai_finishes_the_card() -> void:
	var card := (load(TUTORIAL) as PackedScene).instantiate() as MinigameTutorial
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var fired := [false]
	card.tutorial_finished.connect(func() -> void: fired[0] = true)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	(card.get_node("Scrim") as Control).gui_input.emit(tap)
	assert_false(fired[0], "a tap on the scrim does nothing")
	(card.get_node("%Mulai") as Button).pressed.emit()
	assert_true(fired[0], "Mulai starts the game")


func test_mulai_is_the_mint_main_action() -> void:
	var src := FileAccess.get_file_as_string(TUTORIAL)
	assert_contains(src, "theme_type_variation = &\"PrimaryButtonM\"")
	assert_contains(src, "text = \"Mulai\"")


func test_jeda_and_keluar_wear_their_roles() -> void:
	var pause_scene := "res://Scenes/Minigames/UI/PauseMenu.tscn"
	var quit_scene := "res://Scenes/Minigames/UI/QuitConfirmDialog.tscn"
	var pause_src := FileAccess.get_file_as_string(pause_scene)
	assert_contains(pause_src, "title_text = \"JEDA\"")
	assert_false(pause_src.contains("Game diberhentikan"), "no error-sounding title")
	var quit_src := FileAccess.get_file_as_string(quit_scene)
	assert_contains(quit_src, "title_text = \"KELUAR?\"")
	# scene, unique node, its text, its role variation.
	for row in [
			[pause_scene, "%BtnResume", "Lanjutkan", &"PrimaryButtonM"],
			[pause_scene, "%BtnSettings", "Pengaturan", &"SecondaryButtonM"],
			[pause_scene, "%BtnQuit", "Keluar", &"DangerButtonM"],
			[quit_scene, "%NoButton", "Tidak, lanjut main", &"PrimaryButtonM"],
			[quit_scene, "%YesButton", "Ya, keluar", &"DangerButtonM"]]:
		var root := (load(row[0]) as PackedScene).instantiate()
		track(root)
		var button := root.get_node_or_null(row[1]) as Button
		assert_true(button != null, "%s has %s" % [row[0], row[1]])
		if button == null:
			continue
		assert_eq(button.text, row[2], "%s text" % row[1])
		assert_eq(button.theme_type_variation, row[3], "%s wears its role" % row[1])
