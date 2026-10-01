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
## The shared census helper: reads a saved scene's nodes without instancing it.
const Census := preload("res://tests/scene_census.gd")
## The soft-AO shadow component the speaker splash carries as its first child.
const _SPLASH_SHADOW_SCENE := "res://Scenes/UI/SplashShadow.tscn"


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
	assert_eq(s.splash.material.resource_path, "res://Scripts/Shaders/illustration_grade_splash.tres")
	var tail := s.get_node("Root/Bubble/Tail") as TextureRect
	assert_eq(tail.texture.resource_path, "res://Assets/Images/Shop/UI/chat_bubble_tail.svg")
	assert_true(not tail.flip_h and tail.flip_v, "the tail points up-right at the speaker")
	assert_eq(s.star_row.get_child_count(), 3)
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinScreen.gd")
	assert_false(src.contains(".new("), "the screen is fully authored")
	var scene := FileAccess.get_file_as_string(_SCREEN)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in MinigameWinScreen.tscn")


## The speaker casts the soft ambient-occlusion shade (2026-10-01), the same
## SplashShadow the event dialogue uses. The component's own root carries the
## look (behind its parent, Full Rect, mipmapped filter, the soft AO material),
## so the instance here must not override it, and configure() points it at
## whoever speaks with `shadow.follow(splash)`.
func test_the_speaker_casts_a_soft_ao_shadow() -> void:
	var c := Census.of(_SCREEN)
	var shadow := Census.entry(c, "Root/Splash/Shadow")
	assert_eq(shadow.get("instance"), _SPLASH_SHADOW_SCENE, "the shadow is a SplashShadow")
	var kids := Census.children_of(c, "Root/Splash")
	assert_eq(kids.size(), 1, "the splash has just its shadow")
	assert_eq(kids[0] if kids.size() > 0 else "", "Shadow", "first child, so it draws behind the art")
	for key in ["show_behind_parent", "texture_filter", "material", "anchor_right", "anchor_bottom"]:
		assert_false((shadow.get("props", {}) as Dictionary).has(key),
			"the instance leaves the component's " + key + " alone")
	var comp := Census.entry(Census.of(_SPLASH_SHADOW_SCENE), ".")
	assert_eq(Census.prop(comp, "show_behind_parent", false), true, "it draws behind the speaker")
	assert_eq(float(Census.prop(comp, "anchor_right", 0.0)), 1.0, "Full Rect: right")
	assert_eq(float(Census.prop(comp, "anchor_bottom", 0.0)), 1.0, "Full Rect: bottom")
	assert_eq(int(Census.prop(comp, "texture_filter", 0)), CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"the shader's textureLod reads mips")
	assert_eq((Census.prop(comp, "material") as Material).resource_path,
		"res://Scripts/Shaders/soft_ao_shadow_material.tres", "the soft AO material")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinScreen.gd")
	var start := src.find("
func configure(")
	var body := src.substr(start, src.find("
func ", start + 1) - start)
	assert_true(start != -1 and body.contains("shadow.follow(splash)"), "configure() points the shadow at the speaker")
	assert_true(body.find("shadow.follow(splash)") > body.find("splash.texture ="),
		"and does it after the splash texture changes")


## Only the speaker blooms (2026-10-01): GlowCopy (a fresh copy of the whole
## viewport, because the Blur before it already read the screen) and Glow (a
## ScreenGlow at threshold 0.85, intensity 0.4) sit right after Splash, and
## Bubble and Card come after Glow so the UI never blooms.
func test_the_splash_blooms_and_the_ui_does_not() -> void:
	var c := Census.of(_SCREEN)
	var kids := Census.children_of(c, "Root")
	for want in ["Splash", "GlowCopy", "Glow", "Bubble", "Card"]:
		assert_true(kids.has(want), "Root has " + want)
	assert_eq(kids.find("GlowCopy") - kids.find("Splash"), 1, "GlowCopy sits right after Splash")
	assert_eq(kids.find("Glow") - kids.find("GlowCopy"), 1, "Glow sits right after GlowCopy")
	assert_true(kids.find("Bubble") > kids.find("Glow"), "the bubble draws over the bloom")
	assert_true(kids.find("Card") > kids.find("Glow"), "the card draws over the bloom")
	var copy := Census.entry(c, "Root/GlowCopy")
	assert_eq(copy.get("type"), "BackBufferCopy", "GlowCopy is a BackBufferCopy")
	assert_eq(int(Census.prop(copy, "copy_mode", 1)), BackBufferCopy.COPY_MODE_VIEWPORT,
		"it copies the whole viewport")
	var glow := Census.entry(c, "Root/Glow")
	assert_eq(glow.get("instance"), "res://Scenes/Look/ScreenGlow.tscn", "Glow is a ScreenGlow")
	assert_eq(float(Census.prop(glow, "threshold", 0.7)), 0.85, "the bloom's threshold")
	assert_eq(float(Census.prop(glow, "intensity", 0.6)), 0.4, "the bloom's intensity")


## Measured off minigamewinscreen_mockup.jpeg (spec section 3): every piece
## hangs off the bottom edge.
func test_every_piece_hangs_off_the_bottom_edge() -> void:
	var s := _screen()
	var want := {
		"Root/Splash": Vector4(20, -1933, -72, -176),
		"Root/Bubble": Vector4(50, -1038, -50, -878),
		"Root/Card": Vector4(0, -828, 0, 0),
	}
	for path in want:
		var c := s.get_node(path) as Control
		assert_eq(Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom), Vector4(0, 1, 1, 1), path)
		assert_eq(Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom), want[path], path)


## Two uppercase lines of MinigameWinLine plus the bubble's vertical margins
## fit (2026-09-29 dialogue-variations spec). The bubble grows upward: its
## bottom stays 50 px above the card and the Tail rides its top edge.
func test_the_bubble_holds_two_wrapped_lines() -> void:
	var theme := _baked()
	var font := theme.get_font("font", "MinigameWinLine")
	var size := theme.get_font_size("font_size", "MinigameWinLine")
	var box := theme.get_stylebox("panel", "MinigameWinBubble")
	var need := font.get_height(size) * 2.0 + box.content_margin_top + box.content_margin_bottom
	var s := _screen()
	var line := s.get_node("Root/Bubble/Panel/Line") as Label
	assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the line wraps")
	assert_eq(s.bubble.offset_bottom, -878.0, "the bottom stays put")
	var have := s.bubble.offset_bottom - s.bubble.offset_top
	assert_true(have >= need, "bubble is %d px tall, two lines need %d" % [have, need])
	assert_eq(line.text, "Terima kasih, Pak!", "the authored default matches WIN_LINE_STUDENT")


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
	for n in [s.blur, s.glow, s.card, s.splash, s.bubble, s.skill_chip.icon_box, s.energy_chip.icon_box, s.lobby_button, s.lanjut_button]:
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
