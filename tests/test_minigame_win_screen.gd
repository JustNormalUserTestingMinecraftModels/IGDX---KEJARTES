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
