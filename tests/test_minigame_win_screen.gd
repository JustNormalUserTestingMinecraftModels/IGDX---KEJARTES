@tool
extends McpTestSuite

## The minigame win screen (spec:
## docs/superpowers/specs/2026-09-25-minigame-win-screen-design.md): its theme,
## its stat rows, its authored scene, its bottom-hung layout on a tall phone,
## its reveal order and its two exits.
##
## Must be @tool, and no test here may be a coroutine.

## The baked theme every screen in the game wears.
const _THEME := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "minigame_win_screen"


func _baked() -> Theme:
	return ResourceLoader.load(_THEME, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme


# ── theme ────────────────────────────────────────────────────────────────────

func test_the_bake_carries_the_four_variations() -> void:
	var theme := _baked()
	var want := {
		"MinigameWinCard": &"PanelContainer", "MinigameWinBubble": &"PanelContainer",
		"MinigameWinLine": &"Label", "MinigameWinStatLabel": &"Label",
	}
	for v in want:
		assert_eq(theme.get_type_variation_base(v), want[v], v + " must be baked on " + want[v])


func test_the_card_is_the_mockup_cream_with_a_square_bottom() -> void:
	var tokens := DesignTokens.load_default()
	var card := _baked().get_stylebox("panel", "MinigameWinCard") as StyleBoxFlat
	assert_true(card != null, "MinigameWinCard is a flat box")
	if card == null:
		return
	assert_eq(card.bg_color, tokens.minigame_win_card)
	assert_eq(card.corner_radius_top_left, tokens.minigame_win_card_radius)
	assert_eq(card.corner_radius_top_right, tokens.minigame_win_card_radius)
	assert_eq(card.corner_radius_bottom_left, 0, "the card meets the screen's bottom edge")
	assert_eq(card.corner_radius_bottom_right, 0)


## chat_bubble_tail.svg is filled #FFFDF8; the bubble must be the same white.
func test_the_bubble_is_the_tail_s_white() -> void:
	var bubble := _baked().get_stylebox("panel", "MinigameWinBubble") as StyleBoxFlat
	assert_true(bubble != null)
	if bubble != null:
		assert_eq(bubble.bg_color, DesignTokens.load_default().surface_card)
		assert_eq(bubble.bg_color, Color("FFFDF8"), "the tail svg's own fill")


func test_the_stat_numbers_are_white_with_the_day_summary_rim() -> void:
	var tokens := DesignTokens.load_default()
	var theme := _baked()
	assert_eq(theme.get_font_size("font_size", "MinigameWinStatLabel"), tokens.minigame_win_stat_size)
	assert_eq(theme.get_color("font_color", "MinigameWinStatLabel"), Color.WHITE)
	assert_eq(theme.get_color("font_outline_color", "MinigameWinStatLabel"), tokens.day_glyph_outline)
	assert_eq(theme.get_constant("outline_size", "MinigameWinStatLabel"), tokens.text_outline_size)


# ── the stat row ─────────────────────────────────────────────────────────────

const _STAT := "res://Scenes/Minigames/UI/MinigameWinStat.tscn"
const _ENERGY_ICON := "res://Assets/Images/StudentCard/stat_energy.png"


func _chip() -> MinigameWinStat:
	var c := (load(_STAT) as PackedScene).instantiate() as MinigameWinStat
	c.theme = load(_THEME)
	Engine.get_main_loop().root.add_child(c)
	track(c)
	return c


func test_a_delta_carries_its_sign() -> void:
	assert_eq(MinigameWinStat.format_delta(8.0), "+8")
	assert_eq(MinigameWinStat.format_delta(7.6), "+8", "rounded, not truncated")
	assert_eq(MinigameWinStat.format_delta(-5.0), "-5")
	assert_eq(MinigameWinStat.format_delta(0.0), "+0")


## The chevron art points up and has no down variant (DaySummaryStatRow's rule).
func test_the_chevron_shows_only_on_a_gain() -> void:
	var c := _chip()
	c.set_stat(load(_ENERGY_ICON), -5.0)
	assert_false(c.chevron.visible, "an energy cost gets no up arrow")
	assert_eq(c.value.text, "-5")
	c.set_stat(DaySummaryStatRow.ICON_FOR["akademis"], 8.0)
	assert_true(c.chevron.visible, "a skill gain gets the gold chevron")
	assert_eq(c.icon.texture, DaySummaryStatRow.ICON_FOR["akademis"])
	assert_eq(c.value.text, "+8")


func test_the_row_is_authored() -> void:
	var c := _chip()
	assert_eq(c.value.theme_type_variation, &"MinigameWinStatLabel")
	assert_eq(c.chevron.texture.resource_path, "res://Assets/Images/DaySummary/icon_chevron_up.png")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinStat.gd")
	assert_false(src.contains(".new("), "the row is authored, never built")


# ── the screen ───────────────────────────────────────────────────────────────

const _SCREEN := "res://Scenes/Minigames/UI/MinigameWinScreen.tscn"
const _CITRA := "res://Assets/Images/SplashArtMurid/splash_citra.png"


func _screen() -> MinigameWinScreen:
	var s := (load(_SCREEN) as PackedScene).instantiate() as MinigameWinScreen
	Engine.get_main_loop().root.add_child(s)
	s.root.theme = load(_THEME)
	track(s)
	return s


func _filled(s: MinigameWinScreen) -> int:
	var n := 0
	for star in s.star_row.get_children():
		if (star as ResultStar).is_filled:
			n += 1
	return n


func test_configure_fills_the_screen() -> void:
	var s := _screen()
	s.configure(2, _CITRA, "Terima kasih, Guru!", "Akademis", {"stat_delta": 8.0, "energy_delta": -5.0})
	assert_eq(s.splash.texture.resource_path, _CITRA)
	assert_true(s.splash.visible)
	assert_eq(s.line_label.text, "Terima kasih, Guru!")
	assert_true(s.line_label.uppercase, "the mockup's line is in capitals")
	assert_eq(_filled(s), 2, "two of the three stars are earned")
	assert_eq(s.skill_chip.icon.texture, DaySummaryStatRow.ICON_FOR["akademis"])
	assert_eq(s.skill_chip.value.text, "+8")
	assert_eq(s.energy_chip.icon.texture, MinigameWinScreen.ENERGY_ICON)
	assert_eq(s.energy_chip.value.text, "-5")


func test_each_category_wears_its_skill_icon() -> void:
	var s := _screen()
	for cat in MinigameWinScreen.SKILL_KEY:
		s.configure(3, "", "x", cat, {"stat_delta": 6.0, "energy_delta": -7.0})
		assert_eq(s.skill_chip.icon.texture, DaySummaryStatRow.ICON_FOR[MinigameWinScreen.SKILL_KEY[cat]], cat)


func test_a_zero_stat_hides_its_chip_and_nothing_hides_the_row() -> void:
	var s := _screen()
	s.configure(3, "", "x", "Olahraga", {"stat_delta": 0.0, "energy_delta": -7.0})
	assert_false(s.skill_chip.visible, "a capped week gains nothing: no '+0' chip")
	assert_true(s.energy_chip.visible)
	assert_true(s.stat_row.visible)
	s.configure(3, "", "x", "Olahraga", {})
	assert_false(s.stat_row.visible, "standalone play reports nothing, so no stat row")


func test_no_speaker_hides_the_splash() -> void:
	var s := _screen()
	s.configure(1, "", "x", "Akademis", {})
	assert_false(s.splash.visible)
	assert_eq(_filled(s), 1)


func test_the_screen_is_authored_and_themed() -> void:
	var s := _screen()
	assert_eq(s.layer, 999, "above every minigame layer, like the result popup")
	assert_eq(s.process_mode, Node.PROCESS_MODE_ALWAYS)
	var want := {
		"Root/Card": &"MinigameWinCard", "Root/Bubble/Panel": &"MinigameWinBubble",
		"Root/Bubble/Panel/Line": &"MinigameWinLine",
		"Root/Card/Layout/ButtonRow/LobbyButton": &"SecondaryButtonL",
		"Root/Card/Layout/ButtonRow/LanjutButton": &"PrimaryButtonL",
	}
	for path in want:
		var n := s.get_node_or_null(path) as Control
		assert_true(n != null, "missing " + path)
		if n != null:
			assert_eq(n.theme_type_variation, want[path], path)
	assert_eq(s.lobby_button.text, "LOBBY")
	assert_eq(s.lanjut_button.text, "LANJUT")
	assert_eq(s.root.mouse_filter, Control.MOUSE_FILTER_STOP, "nothing reaches the minigame")
	for path in ["Root/Blur", "Root/Splash", "Root/Bubble"]:
		assert_eq((s.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, path)
	assert_eq(s.blur.material.resource_path, "res://Scenes/SchoolSimulation/event_dialogue_blur_material.tres")
	assert_eq(s.splash.material.resource_path, "res://Scripts/Shaders/illustration_grade_cutout.tres")
	var tail := s.get_node("Root/Bubble/Tail") as TextureRect
	assert_eq(tail.texture.resource_path, "res://Assets/Images/Shop/UI/chat_bubble_tail.svg")
	assert_true(tail.flip_h and tail.flip_v, "the tail points up-left at the speaker")
	assert_eq(s.star_row.get_child_count(), 3)
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinScreen.gd")
	assert_false(src.contains(".new("), "the screen is fully authored")
	var scene := FileAccess.get_file_as_string(_SCREEN)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in MinigameWinScreen.tscn")


## Measured off minigamewinscreen_mockup.jpeg (spec section 3): every piece
## hangs off the bottom edge.
func test_every_piece_hangs_off_the_bottom_edge() -> void:
	var s := _screen()
	var want := {
		"Root/Splash": Vector4(20, -1933, -72, -176),
		"Root/Bubble": Vector4(50, -1022, -50, -878),
		"Root/Card": Vector4(0, -828, 0, 0),
	}
	for path in want:
		var c := s.get_node(path) as Control
		assert_eq(Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom), Vector4(0, 1, 1, 1), path)
		assert_eq(Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom), want[path], path)


## On a 20:9 phone the whole composition keeps its distance from the bottom
## edge; only the blurred minigame above it grows. Root is moved into a frame
## of each size (layout_frame stands up Control-rooted scenes only).
func test_on_a_tall_phone_the_composition_rides_the_bottom_edge() -> void:
	for screen in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var s := _screen()
		var frame := Control.new()
		frame.size = screen
		frame.theme = load(_THEME)
		s.remove_child(s.root)
		frame.add_child(s.root)
		Engine.get_main_loop().root.add_child(frame)
		track(frame)
		preload("res://tests/layout_frame.gd").settle(s.root)
		assert_eq(s.card.get_global_rect().end.y, screen.y, "card meets the bottom at %s" % screen)
		assert_eq(s.card.get_global_rect().position.y, screen.y - 828, "card height at %s" % screen)
		assert_eq(s.bubble.get_global_rect().end.y, screen.y - 878, "bubble at %s" % screen)
		assert_eq(s.splash.get_global_rect().end.y, screen.y - 176, "splash at %s" % screen)


# ── the reveal and the exits ─────────────────────────────────────────────────

func test_the_reveal_runs_in_the_asked_order() -> void:
	assert_eq(MinigameWinScreen.REVEAL_ORDER,
		[&"card", &"splash", &"bubble", &"stats", &"stars", &"buttons"] as Array[StringName],
		"box, then speaker, then line; stats; stars; buttons (owner's order, 2026-09-25)")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinScreen.gd")
	assert_true(src.contains("for step in REVEAL_ORDER"), "play() walks the order, it does not restate it")


## Every piece play() reveals starts hidden, so nothing flashes on before its
## turn; the buttons are dead until the last step arms them.
func test_before_the_reveal_everything_waits() -> void:
	var s := _screen()
	s.configure(3, _CITRA, "x", "Akademis", {"stat_delta": 8.0, "energy_delta": -5.0})
	s.hide_for_reveal()
	for n in [s.blur, s.card, s.splash, s.bubble, s.skill_chip.icon_box, s.energy_chip.icon_box, s.lobby_button, s.lanjut_button]:
		assert_eq(n.modulate.a, 0.0, "%s waits for its turn" % n.name)
	for star in s.star_row.get_children():
		assert_eq(star.modulate.a, 0.0, "%s waits for its turn" % star.name)


func test_the_buttons_answer_only_once_armed() -> void:
	var s := _screen()
	s.configure(3, "", "x", "Akademis", {})
	var got: Array = []
	s.exited.connect(func(c: StringName): got.append(c))
	s.lanjut_button.pressed.emit()
	assert_eq(got, [], "a press mid-reveal is ignored")
	s.arm_buttons()
	s.lobby_button.pressed.emit()
	s.lanjut_button.pressed.emit()
	assert_eq(got, [&"lobby"], "the first armed press answers, once")
