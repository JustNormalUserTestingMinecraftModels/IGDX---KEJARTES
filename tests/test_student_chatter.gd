@tool
extends McpTestSuite

## Student chatter in the Lobby (2026-09-19 spec): the line catalog and its
## shuffle-bag picker, the StudentChatBubble's placement/flip/FSM, the
## LobbyChatter's spam guard, idle timer and gate, and loby.tscn's wiring.
## @tool, and no test here is a coroutine: tweens are started but never
## awaited, so only synchronous state (text, position, pivot, busy) is read.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _TOKENS_PATH := "res://Assets/Theme/design_tokens.tres"


func suite_name() -> String:
	return "student_chatter"


# ----- Theme -----

## The bake on disk, bypassing the resource cache: a rebake earlier in the
## same editor session would otherwise be invisible to load().
func _baked_theme() -> Theme:
	return ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme


func test_bubble_variation_is_a_card_panel() -> void:
	var theme := _baked_theme()
	var tokens := load(_TOKENS_PATH) as DesignTokens
	assert_eq(theme.get_type_variation_base("StudentChatBubble"), &"PanelContainer")
	var box := theme.get_stylebox("panel", "StudentChatBubble") as StyleBoxFlat
	assert_true(box != null, "StudentChatBubble has a flat panel")
	if box:
		assert_eq(box.bg_color, tokens.surface_card)


func test_text_variation_is_bold_body_title_size() -> void:
	var theme := _baked_theme()
	var tokens := load(_TOKENS_PATH) as DesignTokens
	assert_eq(theme.get_type_variation_base("StudentChatText"), &"Label")
	assert_eq(theme.get_font("font", "StudentChatText"), tokens.font_body_bold)
	assert_eq(theme.get_font_size("font_size", "StudentChatText"), tokens.font_title)
	assert_eq(theme.get_color("font_color", "StudentChatText"), tokens.text_primary)
