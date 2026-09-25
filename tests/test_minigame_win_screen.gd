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
