@tool
extends McpTestSuite

## StatCheck (Plan A, 2026-09-04): the automated one-by-one stat check that
## replaced the SemesterEnd card carousel. The sequence itself is a chain
## of coroutines (slides, fills, a white fade), so nothing here plays it --
## these are structural checks on bare instantiate()s plus source scans for
## the wiring, per the runner's no-coroutine rule documented in
## test_lobby.gd. StatCheckRow's non-animated path IS exercised live.

const _ROW_SCENE := "res://Scenes/EndGame/StatCheckRow.tscn"
const _ROW_SCRIPT := "res://Scripts/EndGame/StatCheckRow.gd"
const _STAR_ICON := "res://Assets/Images/UI/Placeholders/icon_star.svg"


func suite_name() -> String:
	return "stat_check"


# ────────────────────────────────────────────────────────────── StatCheckRow

func test_row_scene_loads_and_holds_an_icon_and_a_stat_bar() -> void:
	var row = load(_ROW_SCENE).instantiate()
	track(row)
	assert_true(row is StatCheckRow, "the row wears StatCheckRow.gd")
	assert_true(row.get_node_or_null("Icon") is TextureRect, "Icon node")
	assert_true(row.get_node_or_null("Bar") is StatBar, "Bar is a StatBar")


func test_row_ratio_is_value_over_target_capped_at_100() -> void:
	assert_true(is_equal_approx(StatCheckRow.ratio(30.0, 60.0), 50.0), "half")
	assert_true(is_equal_approx(StatCheckRow.ratio(60.0, 60.0), 100.0), "met")
	assert_true(is_equal_approx(StatCheckRow.ratio(90.0, 60.0), 100.0), "capped")
	assert_true(is_equal_approx(StatCheckRow.ratio(10.0, 0.0), 0.0),
		"a zero target reads as empty, never a divide by zero")


func test_row_set_result_arms_the_target_without_animating() -> void:
	var row = load(_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	row.set_result(45.0, 60.0)
	assert_true(is_equal_approx(row.get_node("Bar").value, 0.0),
		"set_result leaves the bar empty -- fill() is what moves it")
	assert_true(is_equal_approx(row.target_ratio, 75.0), "the ratio is armed")
	assert_false(row.cleared, "not cleared until a full fill has played")
	Engine.get_main_loop().root.remove_child(row)


func test_row_fill_is_a_coroutine_that_pops_only_at_full() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func fill() -> void:"), "fill() exists")
	assert_true(src.contains("await Juice.fill_bar(bar, target_ratio, fill_seconds).finished"),
		"fill() awaits Juice.fill_bar over fill_seconds")
	assert_true(src.contains("if target_ratio >= 100.0:"),
		"the pop is gated on a full bar")
	assert_true(src.contains("filled.emit(cleared)"),
		"fill() reports whether the stat cleared")


func test_row_pop_is_squash_burst_and_sfx() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("AnimUtils.squash_bounce(bar)"), "squash the bar")
	assert_true(src.contains("res://Scenes/SchoolSimulation/RewardBurst.tscn"),
		"instance the authored RewardBurst -- never build particles at runtime")
	assert_true(src.contains("AudioDirector.play_sfx(&\"pop\")"), "the pop cue")


func test_star_placeholder_exists_and_loads_as_a_texture() -> void:
	assert_true(ResourceLoader.exists(_STAR_ICON), "icon_star.svg exists")
	var tex = load(_STAR_ICON)
	assert_true(tex is Texture2D, "it imports as a Texture2D")
