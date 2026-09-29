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


## The white screen-wide CelebrationConfetti was retired on 2026-09-25: the
## Celebration tier keeps its sound, haptic and shake, but throws no particles.
func test_celebration_throws_no_white_confetti() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Feedback/RewardFeedback.gd")
	assert_false(src.contains("CelebrationConfetti.tscn"), "no route to the retired confetti")
	assert_false(ResourceLoader.exists("res://Scenes/SchoolSimulation/CelebrationConfetti.tscn"),
		"the retired confetti's scene is deleted")
	assert_true(src.contains("return  # Tick and Celebration have no particles"),
		"only the Pop tier bursts")


## A queued cue holds its anchor across QUEUE_GAP waits. The day
## summary and report rows queue theirs, and tapping past the card before the
## queue drains frees those rows: handing a freed row to _play_now's typed
## `anchor: Node` parameter broke the game (2026-09-28, after a minigame win).
func test_a_freed_anchor_is_stale() -> void:
	var row := Node.new()
	assert_false(RewardFeedback.is_stale_anchor(row), "a live anchor is not stale")
	row.free()
	assert_true(RewardFeedback.is_stale_anchor(row), "a freed anchor is stale")
	assert_false(RewardFeedback.is_stale_anchor(null), "no anchor at all is not stale")


func test_the_cue_queue_drops_cues_whose_anchor_was_freed() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Feedback/RewardFeedback.gd")
	var pump := src.substr(src.find("func _pump_cue_queue"))
	pump = pump.substr(0, pump.find("\nfunc ", 1))
	assert_true(pump.contains("is_stale_anchor(item[\"anchor\"])"),
		"_pump_cue_queue checks each cue's anchor before _play_now")
	assert_true(pump.find("is_stale_anchor") < pump.find("_play_now("),
		"the check comes before the call it guards")
