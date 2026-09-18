@tool
extends McpTestSuite

## AchievementStatusPill.tscn / .gd (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 4):
## the header's morphing IDLE/WAITING pill. Drives real state through the
## live Achievements autoload (debug_unlock/claim/relock) so refresh() reads
## the same path the game does, and always restores the touched id back to
## locked in teardown.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const PILL := "res://Scenes/Achievements/AchievementStatusPill.tscn"

## A locked id with no prize, used purely to flip unlocked/claimed state.
const PLAIN_ID := "three_star_akademis"

var _touched_ids: Array[String] = []


func suite_name() -> String:
	return "achievement_status_pill"


func teardown() -> void:
	for id in _touched_ids:
		_achievements().relock(id)
	_touched_ids.clear()


func _achievements() -> Node:
	return Engine.get_main_loop().root.get_node("Achievements")


func _new_pill() -> AchievementStatusPill:
	var pill: AchievementStatusPill = (load(PILL) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	track(pill)
	return pill


func test_idle_state_with_no_unclaimed() -> void:
	var achievements := _achievements()
	var pill := _new_pill()
	pill.refresh(false)
	assert_false(pill.is_waiting())
	assert_true(pill.idle_state.visible)
	assert_false(pill.waiting_state.visible)
	var claimed: int = achievements.total_claimed_count()
	var total: int = achievements.total_count()
	assert_eq(pill.idle_label.text, "%d / %d dibuka" % [claimed, total])
	var expected_filled := int(round(float(claimed) / float(total) * AchievementStatusPill.DASH_SEGMENT_COUNT))
	var filled := 0
	for seg in pill.dash_bar.get_children():
		if seg.theme_type_variation == &"AchievementDashSegmentFilled":
			filled += 1
	assert_eq(filled, expected_filled)


func test_waiting_state_after_debug_unlock() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var pill := _new_pill()
	pill.refresh(false)
	assert_true(pill.is_waiting())
	assert_true(pill.waiting_state.visible)
	assert_false(pill.idle_state.visible)
	assert_eq(pill.waiting_label.text, "1 hadiah belum diambil")
	assert_true(pill.coin_icon.visible)


func test_returns_to_idle_after_claim() -> void:
	_touched_ids.append(PLAIN_ID)
	var achievements := _achievements()
	var claimed_before: int = achievements.total_claimed_count()
	achievements.debug_unlock(PLAIN_ID)
	achievements.claim(PLAIN_ID)
	var pill := _new_pill()
	pill.refresh(false)
	assert_false(pill.is_waiting())
	assert_true(pill.idle_state.visible)
	var total: int = achievements.total_count()
	assert_eq(pill.idle_label.text, "%d / %d dibuka" % [claimed_before + 1, total])


func test_jump_requested_emits_only_while_waiting() -> void:
	var pill := _new_pill()
	pill.refresh(false)
	var jumps := [0]
	pill.jump_requested.connect(func(): jumps[0] += 1)

	# Idle: tapping must not emit.
	assert_false(pill.is_waiting())
	pill.pressed.emit()
	assert_eq(jumps[0], 0)

	# Waiting: tapping must emit.
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	pill.refresh(false)
	assert_true(pill.is_waiting())
	pill.pressed.emit()
	assert_eq(jumps[0], 1)


func test_refresh_false_applies_state_without_creating_a_tween() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var pill := _new_pill()
	pill.refresh(false)
	assert_true(pill.is_waiting())
	assert_false(pill.is_morphing(), "refresh(false) must not start a morph tween")
	assert_eq(pill.scale, Vector2.ONE)


func test_scene_has_no_theme_overrides() -> void:
	# The project rule: styling flows from the theme, never from per-node
	# overrides. Layout-only constants (separation, margin_*) are exempt.
	var src := FileAccess.get_file_as_string(PILL)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in AchievementStatusPill.tscn: " + line)
