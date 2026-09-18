@tool
extends McpTestSuite

## AchievementDetailSheet.tscn / .gd (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 3):
## the tap-to-expand modal opened from an AchievementTile. Drives real state
## through the live Achievements autoload (debug_unlock/claim/relock) so
## open_for() reads the same path the game does, and always restores the
## touched id back to locked in teardown.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const SHEET := "res://Scenes/Achievements/AchievementDetailSheet.tscn"
const SHEET_SRC := "res://Scripts/Achievements/AchievementDetailSheet.gd"

## A locked id with no prize.
const PLAIN_ID := "three_star_akademis"
## A numeric-progress id, for the fraction text assertion.
const PROGRESS_ID := "total_10"

var _touched_ids: Array[String] = []


func suite_name() -> String:
	return "achievement_detail_sheet"


func teardown() -> void:
	for id in _touched_ids:
		_achievements().relock(id)
	_touched_ids.clear()


func _achievements() -> Node:
	return Engine.get_main_loop().root.get_node("Achievements")


func _new_sheet() -> AchievementDetailSheet:
	var sheet: AchievementDetailSheet = (load(SHEET) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(sheet)
	track(sheet)
	return sheet


func test_locked_shows_lock_and_hides_claim_and_claimed() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.get_node("%LockIcon").visible)
	assert_false(sheet.get_node("%ClaimButton").visible)
	assert_false(sheet.get_node("%ClaimedLabel").visible)
	assert_true(sheet.visible)


func test_unlocked_shows_claim_and_hides_lock_and_claimed() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.get_node("%ClaimButton").visible)
	assert_false(sheet.get_node("%LockIcon").visible)
	assert_false(sheet.get_node("%ClaimedLabel").visible)


func test_claimed_shows_caption_and_hides_claim_and_lock() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.get_node("%ClaimedLabel").visible)
	assert_false(sheet.get_node("%ClaimButton").visible)
	assert_false(sheet.get_node("%LockIcon").visible)


func test_fraction_text_matches_progress_fraction_of() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PROGRESS_ID)
	var frac: Vector2i = _achievements().progress_fraction_of(PROGRESS_ID)
	var label := sheet.get_node("%ProgressLabel") as Label
	assert_true(label.visible)
	assert_eq(label.text, "%d / %d" % [frac.x, frac.y])


func test_fraction_text_hidden_for_one_shot_kind() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_false(sheet.get_node("%ProgressLabel").visible)


func test_close_hides_and_emits_closed() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	var closed_count := [0]
	sheet.closed.connect(func(): closed_count[0] += 1)
	sheet.close()
	assert_false(sheet.visible)
	assert_eq(closed_count[0], 1)


func test_close_when_already_closed_does_not_emit_again() -> void:
	var sheet := _new_sheet()
	var closed_count := [0]
	sheet.closed.connect(func(): closed_count[0] += 1)
	sheet.close()
	assert_eq(closed_count[0], 0)


func test_claim_button_emits_claim_requested_for_unlocked_entry() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	(sheet.get_node("%ClaimButton") as Button).pressed.emit()
	assert_eq(got, [PLAIN_ID])
	# The sheet itself never calls Achievements.claim -- that is the host
	# screen's job (see the script header). State stays UNLOCKED here.
	assert_eq(_achievements().state_of(PLAIN_ID), ACHIEVEMENTS.STATE_UNLOCKED)


func test_no_theme_overrides_and_scrim_variation_present() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_false(src.contains("theme_override_"), "no theme_override_* in AchievementDetailSheet.tscn")
	assert_true(src.contains('theme_type_variation = &"Scrim"'), "Scrim variation must be present")
