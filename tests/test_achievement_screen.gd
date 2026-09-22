@tool
extends McpTestSuite

## The Achievements screen, its card template, the Lobby's trophy button and
## the theme variations behind them (spec:
## docs/superpowers/specs/2026-09-17-achievements-design.md).

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const SCREEN := "res://Scenes/Achievements/achievements.tscn"
const TILE := "res://Scenes/Achievements/AchievementTile.tscn"
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
	assert_true(root.get_node_or_null("Safe/UI/Header/StatusPill") is AchievementStatusPill)
	assert_true(root.get_node_or_null("Safe/UI/Header/FilterButton") is OptionButton)
	assert_true(root.get_node_or_null("Safe/UI/Scroll/Margin/List") is GridContainer)
	var grid := root.get_node("Safe/UI/Scroll/Margin/List") as GridContainer
	assert_eq(grid.columns, 2)
	assert_true(root.get_node_or_null("DetailSheet") is AchievementDetailSheet)
	var back := root.get_node_or_null("Safe/UI/BackButton") as TextureButton
	assert_true(back != null)
	if back:
		assert_eq(back.anchor_top, 1.0, "the back arrow sits on the bottom edge")
	var scroll := root.get_node("Safe/UI/Scroll") as ScrollContainer
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)


func test_filter_button_has_four_options_in_order() -> void:
	var root := (load(SCREEN) as PackedScene).instantiate() as Control
	track(root)
	var filter := root.get_node("Safe/UI/Header/FilterButton") as OptionButton
	assert_eq(filter.item_count, 4)
	assert_eq(filter.get_item_text(0), "Semua")
	assert_eq(filter.get_item_text(1), "Belum dibuka")
	assert_eq(filter.get_item_text(2), "Sudah dibuka")
	assert_eq(filter.get_item_text(3), "Belum diambil")
	assert_eq(filter.selected, 0)
	assert_eq(filter.theme_type_variation, &"SecondaryButton")


func test_tile_states() -> void:
	var tile := (load(TILE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(tile)
	track(tile)
	var entry := AchievementCatalog.get_entry("total_50")
	tile.setup(entry)
	assert_eq(tile.title_label.text, "Pembimbing Legendaris")
	assert_eq(tile.achievement_id, "total_50")
	# Real state comes from the live Achievements autoload; refresh() should
	# not throw regardless of that id's current state.
	tile.refresh()


func test_screen_wires_tile_and_sheet_signals() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Achievements/achievements_screen.gd")
	assert_true(src.contains("tile.tile_pressed.connect(_on_tile_pressed)"))
	assert_true(src.contains("detail_sheet.open_for(id)"))
	assert_true(src.contains("detail_sheet.claim_requested.connect(_on_claim_requested)"))
	assert_true(src.contains("Achievements.claim(id)"))
	assert_true(src.contains("achievements.state_changed.connect(_on_state_changed)"))
	assert_true(src.contains("status_pill.jump_requested.connect(_on_jump_requested)"))
	assert_true(src.contains("ensure_control_visible(tile)"))
	assert_true(src.contains("Juice.shake(tile"))
	assert_true(src.contains("if detail_sheet.visible:"), "back-guard: sheet swallows Android back while open")


## Task 4: Android back must close an open claim popup before the sheet
## underneath it, since AchievementClaimPopup has no back handling of its
## own. Source-scanned because the popup can't be instantiated headlessly
## with the full claim flow.
func test_back_guard_closes_claim_popup_before_sheet() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Achievements/achievements_screen.gd")
	assert_true(src.contains("_open_claim_popup"), "screen must track the open claim popup")
	var notif_idx := src.find("func _notification(")
	assert_true(notif_idx != -1)
	var popup_idx := src.find("_open_claim_popup", notif_idx)
	var sheet_idx := src.find("detail_sheet.visible", notif_idx)
	assert_true(popup_idx != -1 and sheet_idx != -1 and popup_idx < sheet_idx,
		"_notification must check the claim popup before the detail sheet")


## Task 2: a jump from the status pill must reset the filter to "Semua"
## before scrolling when the target tile is hidden by the active filter,
## and defer the actual scroll so the grid has re-laid out first.
func test_jump_requested_resets_filter_before_scrolling() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Achievements/achievements_screen.gd")
	var jump_idx := src.find("func _on_jump_requested(")
	assert_true(jump_idx != -1)
	var next_func_idx := src.find("\nfunc ", jump_idx + 1)
	var body := src.substr(jump_idx, next_func_idx - jump_idx)
	assert_true(body.contains("filter_button.select(0)"), "must reset the filter to Semua (index 0)")
	assert_true(body.contains("_on_filter_selected(0)"), "must re-apply the reset filter")
	assert_true(body.contains("call_deferred(\"_scroll_to_tile_deferred\""),
		"the scroll must be deferred a frame so the grid has re-laid out")


func test_lobby_has_the_trophy_button() -> void:
	var lobby := (load(LOBBY) as PackedScene).instantiate()
	track(lobby)
	var btn := lobby.get_node_or_null("Safe/UI/BottomBar/AchievementButton") as TextureButton
	assert_true(btn != null, "AchievementButton under BottomBar")
	if btn:
		assert_eq(btn.texture_normal.resource_path, "res://Assets/Images/Achievements/achievement_button.png")
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("res://Scenes/Achievements/achievements.tscn"))


const OUTLINE_MATERIAL := "res://Assets/Images/Achievements/icon_outline_material.tres"


func test_outline_material_is_white() -> void:
	var mat := load(OUTLINE_MATERIAL) as ShaderMaterial
	assert_true(mat != null and mat.shader != null)
	assert_true(mat.shader.code.contains("outline_width"))
	assert_eq(mat.get_shader_parameter("outline_color"), Color.WHITE)
	assert_gt(float(mat.get_shader_parameter("outline_width")), 0.0)


func test_card_and_banner_icons_wear_the_outline() -> void:
	for pair in [[TILE, "Content/IconSlot/Icon"], ["res://Scenes/Achievements/AchievementToast.tscn", "Banner/Icon"]]:
		var root := (load(pair[0]) as PackedScene).instantiate()
		track(root)
		var icon := root.get_node(pair[1]) as TextureRect
		assert_true(icon.material != null and icon.material.resource_path == OUTLINE_MATERIAL,
			"%s's icon must use the shared outline material" % pair[0])


func test_trophy_sits_after_the_settings_gear() -> void:
	var lobby := (load(LOBBY) as PackedScene).instantiate()
	track(lobby)
	var btn := lobby.get_node("Safe/UI/BottomBar/AchievementButton") as Control
	assert_eq(btn.offset_left, 240.0)
	assert_eq(btn.offset_right, 336.0)
