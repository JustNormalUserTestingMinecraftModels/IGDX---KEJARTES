@tool
extends McpTestSuite

## AchievementTile.tscn / .gd (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 2):
## the 2-column grid tile that replaces AchievementRow. Drives real state
## through the live Achievements autoload (debug_unlock/claim/relock) so
## setup()/refresh() read the same path the game does, and always restores
## the touched id back to locked in teardown.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const TILE := "res://Scenes/Achievements/AchievementTile.tscn"

## An id with no prize, for the "neutral chip" / plain states.
const PLAIN_ID := "three_star_akademis"
## An id with a non-empty prize, for the "amber chip" case.
const PRIZE_ID := "total_25"
## A numeric-progress id, for the progress-bar assertion.
const PROGRESS_ID := "total_10"

var _touched_ids: Array[String] = []


func suite_name() -> String:
	return "achievement_tile"


func teardown() -> void:
	for id in _touched_ids:
		_achievements().relock(id)
	_touched_ids.clear()


func _achievements() -> Node:
	return Engine.get_main_loop().root.get_node("Achievements")


func _new_tile() -> AchievementTile:
	var tile: AchievementTile = (load(TILE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(tile)
	track(tile)
	return tile


func test_setup_shows_title_and_icon() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.title_label.text, "Cap-cip-cup kembang kuncup!")
	assert_eq(tile.achievement_id, PLAIN_ID)


func test_prize_chip_empty_is_neutral_dash() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.prize_label.text, "—")
	assert_eq(tile.prize_chip.theme_type_variation, &"AchievementPrizeChip")


func test_prize_chip_non_empty_is_amber() -> void:
	var tile := _new_tile()
	var entry := AchievementCatalog.get_entry(PRIZE_ID)
	tile.setup(entry)
	assert_eq(tile.prize_label.text, entry.prize)
	assert_eq(tile.prize_chip.theme_type_variation, &"AchievementPrizeChipAmber")


func test_locked_state_dims_tile_and_shows_lock() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(tile.lock_icon.visible)
	assert_false(tile.baru_badge.visible)
	assert_false(tile.check_badge.visible)
	assert_true(absf(tile.modulate.a - tile.locked_modulate.a) < 0.01)


func test_unlocked_state_shows_baru_badge() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_false(tile.lock_icon.visible)
	assert_true(tile.baru_badge.visible)
	assert_false(tile.check_badge.visible)
	assert_true(absf(tile.modulate.a - 1.0) < 0.01, "not dimmed once unlocked")


func test_claimed_state_shows_check_badge() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_false(tile.lock_icon.visible)
	assert_false(tile.baru_badge.visible)
	assert_true(tile.check_badge.visible)


func test_progress_bar_reflects_progress_of() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PROGRESS_ID))
	var expected: float = _achievements().progress_of(PROGRESS_ID) * 100.0
	assert_true(absf(tile.progress_bar.value - expected) < 0.01)


func test_refresh_picks_up_a_new_state_without_setup() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(tile.lock_icon.visible)
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	tile.refresh()
	assert_false(tile.lock_icon.visible)
	assert_true(tile.baru_badge.visible)


func test_matches_filter_truth_table() -> void:
	var locked_tile := _new_tile()
	locked_tile.setup(AchievementCatalog.get_entry(PLAIN_ID))

	_touched_ids.append(PRIZE_ID)
	_achievements().debug_unlock(PRIZE_ID)
	var unlocked_tile := _new_tile()
	unlocked_tile.setup(AchievementCatalog.get_entry(PRIZE_ID))

	_touched_ids.append("grade_7")
	_achievements().debug_unlock("grade_7")
	_achievements().claim("grade_7")
	var claimed_tile := _new_tile()
	claimed_tile.setup(AchievementCatalog.get_entry("grade_7"))

	for tile in [locked_tile, unlocked_tile, claimed_tile]:
		assert_true(tile.matches_filter(AchievementTile.Filter.SEMUA))

	assert_true(locked_tile.matches_filter(AchievementTile.Filter.BELUM_DIBUKA))
	assert_false(unlocked_tile.matches_filter(AchievementTile.Filter.BELUM_DIBUKA))
	assert_false(claimed_tile.matches_filter(AchievementTile.Filter.BELUM_DIBUKA))

	assert_false(locked_tile.matches_filter(AchievementTile.Filter.SUDAH_DIBUKA))
	assert_true(unlocked_tile.matches_filter(AchievementTile.Filter.SUDAH_DIBUKA))
	assert_true(claimed_tile.matches_filter(AchievementTile.Filter.SUDAH_DIBUKA))

	assert_false(locked_tile.matches_filter(AchievementTile.Filter.BELUM_DIAMBIL))
	assert_true(unlocked_tile.matches_filter(AchievementTile.Filter.BELUM_DIAMBIL))
	assert_false(claimed_tile.matches_filter(AchievementTile.Filter.BELUM_DIAMBIL))


func test_tile_pressed_emits_the_achievement_id() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	var got := []
	tile.tile_pressed.connect(func(id): got.append(id))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	tile._gui_input(event)
	assert_eq(got, [PLAIN_ID])


func test_scene_has_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_false(src.contains("theme_override_"), "no theme_override_* in AchievementTile.tscn")


func test_every_label_uses_a_theme_type_variation() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	var lines := src.split("\n")
	var i := 0
	while i < lines.size():
		if lines[i].begins_with('[node name=') and 'type="Label"' in lines[i]:
			var found := false
			var j := i + 1
			while j < lines.size() and not lines[j].begins_with("[node") and not lines[j].begins_with("["):
				if lines[j].begins_with("theme_type_variation"):
					found = true
				j += 1
			assert_true(found, "Label node at line %d has no theme_type_variation" % i)
		i += 1
