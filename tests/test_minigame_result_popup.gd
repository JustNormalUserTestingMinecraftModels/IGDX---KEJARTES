@tool
extends McpTestSuite

## The end-of-minigame result card: roughly 340 lines of runtime construction
## in BaseMinigame._show_result_overlay(), seen by every player after every
## one of the eight minigames, and impossible to open in the editor.
##
## The shipped version discovers its score row / category badge / stat delta
## labels at animation time by scanning vbox.get_children() for "the
## HBoxContainer that isn't the star row" and similar pattern matches, because
## they were only conditionally built in the first place. Now that every node
## is a fixed, named scene node, configure() addresses them directly and
## toggles .visible instead of building/finding them.
##
## Star rendering moves to its own tiny scene so the row is three real nodes
## instead of a loop building 0-3 Controls at runtime.
##
## Must be @tool; no test here may be a coroutine, so nothing calls play().

func suite_name() -> String:
	return "minigame_result_popup"


const POPUP_PATH := "res://Scenes/Minigames/UI/MinigameResultPopup.tscn"
const STAR_PATH := "res://Scenes/Minigames/UI/ResultStar.tscn"

## The style dictionary configure() takes, with neutral values covering every
## @export _show_result_overlay used to read from BaseMinigame.
const STYLE := {
	"popup_card_texture": null, "popup_card_color": Color.BLACK,
	"popup_border_color": Color.WHITE, "popup_dim_color": Color(0, 0, 0, 0.75),
	"popup_star_texture": null, "popup_star_empty_texture": null,
	"popup_star_color": Color.YELLOW, "popup_star_empty_color": Color.GRAY,
	"popup_star_size": Vector2(88, 88),
	"popup_button_texture": null, "popup_button_color": Color.ORANGE,
	"popup_button_text": "Lanjutkan",
	"popup_title_font": null, "popup_body_font": null,
	"popup_title_font_size": 68, "popup_score_font_size": 52, "popup_stat_font_size": 34,
	"popup_title_win_color": Color.YELLOW, "popup_title_lose_color": Color.ORANGE,
	"win_title_text": "Kamu Berhasil! 🎉",
	"lose_title_text": "Belum Tepat, Coba Lagi Lain Kali!",
}


## The scene is added to the tree so its @onready vars resolve.
func _make() -> Node:
	var node: Node = load(POPUP_PATH).instantiate()
	Engine.get_main_loop().root.add_child(node)
	track(node)
	return node


func test_both_scenes_exist() -> void:
	assert_true(ResourceLoader.exists(POPUP_PATH), "%s is missing" % POPUP_PATH)
	assert_true(ResourceLoader.exists(STAR_PATH), "%s is missing" % STAR_PATH)


func test_popup_scene_carries_every_node_the_script_binds() -> void:
	var node := _make()
	for path in ["Dim", "Dim/Center/Card/Layout/TitleLabel",
			"Dim/Center/Card/Layout/StarRow",
			"Dim/Center/Card/Layout/NameLabel",
			"Dim/Center/Card/Layout/ScoreRow/ScorePrefixLabel",
			"Dim/Center/Card/Layout/ScoreRow/ScoreValueLabel",
			"Dim/Center/Card/Layout/CategoryBadge",
			"Dim/Center/Card/Layout/StatDeltaLabel",
			"Dim/Center/Card/Layout/EnergyDeltaLabel",
			"Dim/Center/Card/Layout/MoodDeltaLabel",
			"Dim/Center/Card/Layout/ContinueButtonCenter/ContinueButton"]:
		assert_not_null(node.get_node_or_null(path), "missing node: %s" % path)


func test_win_and_lose_pick_different_titles() -> void:
	var win := _make()
	win.configure(true, 3, 5, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_eq(win.get_node("Dim/Center/Card/Layout/TitleLabel").text, STYLE["win_title_text"])
	var lose := _make()
	lose.configure(false, 0, 1, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_eq(lose.get_node("Dim/Center/Card/Layout/TitleLabel").text, STYLE["lose_title_text"])


func test_star_row_holds_three_fixed_star_instances() -> void:
	var node := _make()
	var row: Node = node.get_node("Dim/Center/Card/Layout/StarRow")
	assert_eq(row.get_child_count(), 3, "the result card always shows three stars")
	for star in row.get_children():
		assert_true(star is ResultStar, "StarRow children must be ResultStar instances")


func test_configure_fills_and_reveals_the_right_star_count() -> void:
	var node := _make()
	node.configure(true, 2, 4, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	var row: Node = node.get_node("Dim/Center/Card/Layout/StarRow")
	var filled := 0
	for star in row.get_children():
		if star.is_filled:
			filled += 1
	assert_eq(filled, 2)


func test_score_row_hides_when_no_score_data() -> void:
	# The shipped code only showed the score line when mg_score >= 0 and
	# mg_max_score > 0. max_score <= 0 means "this minigame doesn't track a
	# score" -- the row must stay hidden, not show "0 / 0" or similar.
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_false(node.get_node("Dim/Center/Card/Layout/ScoreRow").visible)


func test_score_row_shows_and_reads_score_over_max() -> void:
	var node := _make()
	node.configure(true, 3, 4, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	var row: Control = node.get_node("Dim/Center/Card/Layout/ScoreRow")
	assert_true(row.visible)
	var value_text: String = node.get_node("Dim/Center/Card/Layout/ScoreRow/ScoreValueLabel").text
	assert_contains(value_text, "4")
	assert_contains(value_text, "5")


func test_category_badge_hides_when_no_category() -> void:
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_false(node.get_node("Dim/Center/Card/Layout/CategoryBadge").visible)


func test_category_badge_shows_the_right_icon_and_colour() -> void:
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "Olahraga", 0.0, 0.0, 0.0, STYLE)
	var badge: Label = node.get_node("Dim/Center/Card/Layout/CategoryBadge")
	assert_true(badge.visible)
	assert_contains(badge.text, "Olahraga")
	assert_contains(badge.text, "⚽")


func test_each_delta_label_hides_independently_when_its_delta_is_zero() -> void:
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "Akademis", 5.0, 0.0, -3.0, STYLE)
	assert_true(node.get_node("Dim/Center/Card/Layout/StatDeltaLabel").visible)
	assert_false(node.get_node("Dim/Center/Card/Layout/EnergyDeltaLabel").visible,
		"energy delta is 0.0 -- its label must stay hidden")
	assert_true(node.get_node("Dim/Center/Card/Layout/MoodDeltaLabel").visible)
	assert_contains(node.get_node("Dim/Center/Card/Layout/StatDeltaLabel").text, "+5")
	assert_contains(node.get_node("Dim/Center/Card/Layout/MoodDeltaLabel").text, "-3")


func test_base_minigame_no_longer_builds_the_result_card() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "MinigameResultPopup", "BaseMinigame should instantiate the scene")
	assert_false(src.contains("func _draw_star_polygon"),
		"star drawing moved to ResultStar.gd")


func test_star_calculation_stayed_on_base_minigame() -> void:
	# _calculate_stars is game logic, not presentation. Moving it into the
	# popup would put a rule in a view.
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "func _calculate_stars")
