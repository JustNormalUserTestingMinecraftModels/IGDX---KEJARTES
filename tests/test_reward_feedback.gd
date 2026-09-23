@tool
extends McpTestSuite

func suite_name() -> String:
	return "reward_feedback"

func test_every_recipe_sound_id_resolves() -> void:
	for moment in RewardFeedback.RECIPES:
		var sfx: StringName = RewardFeedback.RECIPES[moment].get("sfx", &"")
		if sfx == &"":
			continue  # badge_reveal owns no sound here (EndCutscene plays it)
		assert_true(AudioDirector.has_sfx(sfx),
			"%s -> %s must resolve to a real stream" % [moment, sfx])

func test_play_is_null_safe_without_an_anchor() -> void:
	RewardFeedback.play(&"week_cleared")  # no anchor, must not throw
	assert_true(true, "play() without an anchor did not throw")

func test_unknown_moment_is_a_no_op() -> void:
	RewardFeedback.play(&"not_a_real_moment")
	assert_true(true, "unknown moment did not throw")

func test_star_earned_escalates_to_celebration_on_the_third_star() -> void:
	assert_eq(RewardFeedback.moment_tier(&"star_earned", {"step": 1}),
		RewardFeedback.TIER_POP, "star 1 is a Pop")
	assert_eq(RewardFeedback.moment_tier(&"star_earned", {"step": 3}),
		RewardFeedback.TIER_CELEBRATION, "star 3 is a Celebration")

func test_badge_reveal_tier_follows_the_band() -> void:
	assert_eq(RewardFeedback.moment_tier(&"badge_reveal", {"band": "Amazing"}),
		RewardFeedback.TIER_CELEBRATION, "an Amazing badge is a Celebration")
	assert_eq(RewardFeedback.moment_tier(&"badge_reveal", {"band": "Disaster"}),
		RewardFeedback.TIER_POP, "a Disaster badge is a muted Pop")


func test_debug_feedback_tab_covers_every_recipe() -> void:
	var src := FileAccess.open("res://Scripts/Debug/DebugManager.gd", FileAccess.READ).get_as_text()
	assert_true(src.contains('"Feedback"'), "DebugManager registers a Feedback tab")
	assert_true(src.contains("_build_feedback_panel"), "DebugManager builds the feedback panel")
	assert_true(src.contains("RewardFeedback.RECIPES"),
		"the feedback panel enumerates RewardFeedback.RECIPES (one button per moment)")
	assert_true(src.contains("Haptics.show_indicator"),
		"the feedback panel toggles the clean-record haptic indicator")
