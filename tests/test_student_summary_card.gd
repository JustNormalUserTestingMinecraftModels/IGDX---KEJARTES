@tool
extends McpTestSuite

## The Card+Margin chrome that SchoolDay's day-summary card,
## DailyDecayOverview's decay card and EventStudentSelectDialog's picker
## card each built by hand before laying out their own content.
##
## This is a smaller extraction than the plan originally sketched (which
## assumed a shared Portrait/NameLabel/SubtitleLabel/Rows shape). Reading
## all three builders in full found none of them has a portrait, and their
## immediate content differs in *node type*, not just numbers:
##   - SchoolDay's Margin child is a VBoxContainer (name+chip, two
##     StudentStatRows, then a separate pill-badges row).
##   - DailyDecayOverview's is a VBoxContainer too, but shaped differently
##     (name+badge header, an extra reason label, two StudentStatRows).
##   - EventStudentSelectDialog's is an HBoxContainer (a checkbox beside a
##     details column) holding three *differently-shaped* stat rows
##     (label+bar+value+delta -- the 5-node row Task 15 deliberately left
##     out of StudentStatRow) and card-level self_modulate tinting for the
##     tired/specialty states.
## Forcing one rigid content contract onto three incompatible shapes would
## mean either fabricating unused nodes or quietly changing what a player
## sees, so this scene shares only the chrome genuinely common to all
## three -- the Card surface and its margins -- and each screen still
## builds its own content as a child of Margin, exactly as before.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "student_summary_card"


const SCENE_PATH := "res://Scenes/SchoolSimulation/StudentSummaryCard.tscn"
const SCHOOL_DAY_PATH := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const DECAY_PATH := "res://Scripts/SchoolSimulation/DailyDecayOverview.gd"
const EVENT_SELECT_PATH := "res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd"


func _make() -> StudentSummaryCard:
	var card: StudentSummaryCard = load(SCENE_PATH).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func test_scene_exists_and_carries_its_margin() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var card := _make()
	assert_not_null(card.get_node_or_null("Margin"), "missing node: Margin")
	assert_eq(card.theme_type_variation, &"Card")


func test_margin_knobs_default_to_the_two_screens_that_share_them() -> void:
	var card := _make()
	assert_eq(card.margin_left, 20)
	assert_eq(card.margin_top, 16)
	assert_eq(card.margin_right, 20)
	assert_eq(card.margin_bottom, 16)


func test_overriding_margin_knobs_reaches_the_node() -> void:
	var card := _make()
	card.margin_left = 24
	card.margin_top = 14
	card.margin_right = 24
	card.margin_bottom = 12
	var margin := card.get_node("Margin") as MarginContainer
	assert_eq(margin.get_theme_constant("margin_left"), 24)
	assert_eq(margin.get_theme_constant("margin_top"), 14)
	assert_eq(margin.get_theme_constant("margin_right"), 24)
	assert_eq(margin.get_theme_constant("margin_bottom"), 12)


func test_set_background_texture_swaps_the_card_surface() -> void:
	var card := _make()
	var tex := PlaceholderTexture2D.new()
	card.set_background_texture(tex)
	assert_true(card.has_theme_stylebox_override("panel"))
	card.set_background_texture(null)
	assert_false(card.has_theme_stylebox_override("panel"))
	assert_eq(card.theme_type_variation, &"Card")


func test_content_goes_under_margin() -> void:
	var card := _make()
	var label := Label.new()
	card.margin.add_child(label)
	assert_eq(label.get_parent(), card.margin)


func test_all_three_screens_use_the_shared_card_chrome() -> void:
	for path in [SCHOOL_DAY_PATH, DECAY_PATH, EVENT_SELECT_PATH]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "StudentSummaryCard", "%s should use the shared card chrome" % path)
		assert_false(src.contains("PanelContainer.new("),
			"%s still builds a card by hand" % path)
