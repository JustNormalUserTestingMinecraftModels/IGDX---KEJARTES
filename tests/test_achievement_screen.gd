@tool
extends McpTestSuite

## The Achievements screen, its card template, the Lobby's trophy button and
## the theme variations behind them (spec:
## docs/superpowers/specs/2026-09-17-achievements-design.md).

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const SCREEN := "res://Scenes/Achievements/achievements.tscn"
const ROW := "res://Scenes/Achievements/AchievementRow.tscn"
const LOBBY := "res://Scenes/Lobby/loby.tscn"


func suite_name() -> String:
	return "achievement_screen"


func _theme() -> Theme:
	return ThemeFactory.build(DesignTokens.load_default())


func test_factory_builds_every_variation() -> void:
	var theme := _theme()
	assert_eq(theme.get_type_variation_base("AchievementCard"), &"PanelContainer")
	assert_eq(theme.get_type_variation_base("AchievementCardClaimed"), &"PanelContainer")
	assert_eq(theme.get_type_variation_base("AchievementTitleLabel"), &"Label")
	assert_eq(theme.get_type_variation_base("AchievementDescLabel"), &"Label")
	assert_eq(theme.get_type_variation_base("AchievementClaimButton"), &"Button")
	assert_eq(theme.get_type_variation_base("AchievementToastPanel"), &"Panel")
	assert_eq(theme.get_type_variation_base("AchievementToastTitleLabel"), &"Label")
	var card := theme.get_stylebox("panel", "AchievementCard") as StyleBoxFlat
	assert_eq(card.bg_color, Color.WHITE)
	var claimed := theme.get_stylebox("panel", "AchievementCardClaimed") as StyleBoxTexture
	assert_true(claimed != null and claimed.texture != null, "claimed card is the gradient art")
	var pill := theme.get_stylebox("normal", "AchievementClaimButton") as StyleBoxFlat
	assert_eq(pill.bg_color, Color("B2C73B"))
	assert_eq(pill.border_color, Color("8D8A2F"))


func test_screen_contract() -> void:
	var root := (load(SCREEN) as PackedScene).instantiate() as Control
	track(root)
	assert_true(root.get_node_or_null("Background") is TextureRect)
	assert_true(root.get_node_or_null("Safe") is SafeAreaMargin)
	assert_true(root.get_node_or_null("Safe/UI/Ribbon") is TextureRect)
	assert_true(root.get_node_or_null("Safe/UI/Scroll/Margin/List") is VBoxContainer)
	var back := root.get_node_or_null("Safe/UI/BackButton") as TextureButton
	assert_true(back != null)
	if back:
		assert_eq(back.anchor_top, 1.0, "the back arrow sits on the bottom edge")
	var scroll := root.get_node("Safe/UI/Scroll") as ScrollContainer
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)


func test_row_states() -> void:
	var row := (load(ROW) as PackedScene).instantiate()
	track(row)
	# Out of the tree @onready has not run; resolve the nodes by hand.
	row.icon = row.get_node("%Icon")
	row.title_label = row.get_node("%Title")
	row.desc_label = row.get_node("%Desc")
	row.content = row.get_node("%Content")
	row.claim_button = row.get_node("%ClaimButton")
	var entry := AchievementCatalog.get_entry("total_50")
	row.setup(entry, ACHIEVEMENTS.STATE_LOCKED)
	assert_eq(row.title_label.text, "Pembimbing Legendaris")
	assert_true(row.desc_label.text.contains("Hadiah:"), "prize line shows")
	assert_false(row.claim_button.visible)
	assert_eq(row.theme_type_variation, &"AchievementCard")
	assert_ne(row.icon.modulate, Color.WHITE, "locked is dimmed")
	row.set_state(ACHIEVEMENTS.STATE_UNLOCKED)
	assert_true(row.claim_button.visible)
	assert_eq(row.icon.modulate, Color.WHITE)
	row.set_state(ACHIEVEMENTS.STATE_CLAIMED)
	assert_false(row.claim_button.visible)
	assert_eq(row.theme_type_variation, &"AchievementCardClaimed")


func test_lobby_has_the_trophy_button() -> void:
	var lobby := (load(LOBBY) as PackedScene).instantiate()
	track(lobby)
	var btn := lobby.get_node_or_null("Safe/UI/BottomBar/AchievementButton") as TextureButton
	assert_true(btn != null, "AchievementButton under BottomBar")
	if btn:
		assert_eq(btn.texture_normal.resource_path, "res://Assets/Images/Achievements/achievement_button.png")
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("res://Scenes/Achievements/achievements.tscn"))
