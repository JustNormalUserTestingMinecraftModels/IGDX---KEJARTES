@tool
extends McpTestSuite

## The achievement tracker (spec: docs/superpowers/specs/2026-09-17-achievements-design.md):
## the catalog, every unlock rule, claiming, prize multipliers and the save
## round-trip. Each test builds a fresh, out-of-tree Achievements instance, so
## no autoload state and no user:// file is touched.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")


func suite_name() -> String:
	return "achievements"


func _fresh() -> Node:
	var a: Node = ACHIEVEMENTS.new()
	track(a)
	return a


func _ids() -> Array:
	var out := []
	for e in AchievementCatalog.ENTRIES:
		out.append(e.id)
	return out


func test_catalog_has_26_unique_entries_with_icons() -> void:
	var ids := _ids()
	assert_eq(ids.size(), 26)
	var seen := {}
	for id in ids:
		assert_false(seen.has(id), "duplicate id " + id)
		seen[id] = true
		assert_true(ResourceLoader.exists(AchievementCatalog.icon_path(id)), "icon for " + id)


func test_user_renames_are_applied() -> void:
	assert_eq(AchievementCatalog.get_entry("total_50").title, "Pembimbing Legendaris")
	assert_eq(AchievementCatalog.get_entry("streak_4").title, "Calon Sarjana S3")
	assert_eq(AchievementCatalog.get_entry("money_6x").title, "Kita kaya!")
	assert_eq(AchievementCatalog.get_entry("money_4x").title, "Belajar Menabung")
	assert_eq(AchievementCatalog.get_entry("streak_6").title, "Calon Asisten Einstein")


func test_everything_starts_locked() -> void:
	var a := _fresh()
	for id in _ids():
		assert_eq(a.state_of(id), ACHIEVEMENTS.STATE_LOCKED, id)


func test_three_star_unlocks_only_its_category() -> void:
	var a := _fresh()
	a.record_minigame("SeniBudaya", "Buat Batik", true, 3, -1.0)
	assert_eq(a.state_of("three_star_seni"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("three_star_akademis"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_minigame("Olahraga", "Main Bola", true, 2, -1.0)
	assert_eq(a.state_of("three_star_olahraga"), ACHIEVEMENTS.STATE_LOCKED)


func test_streak_resets_on_a_non_perfect_result_but_keeps_its_unlock() -> void:
	var a := _fresh()
	a.record_minigame("Akademis", "Variabel Matematika", true, 3, -1.0)
	a.record_minigame("Akademis", "Variabel Matematika", true, 3, -1.0)
	assert_eq(a.state_of("streak_2"), ACHIEVEMENTS.STATE_UNLOCKED)
	a.record_minigame("Akademis", "Variabel Matematika", true, 2, -1.0)
	assert_eq(a.current_streak, 0)
	for i in 3:
		a.record_minigame("Akademis", "Variabel Matematika", true, 3, -1.0)
	assert_eq(a.state_of("streak_4"), ACHIEVEMENTS.STATE_LOCKED, "3 in a row is not 4")
	a.record_minigame("Akademis", "Variabel Matematika", false, 0, -1.0)
	assert_eq(a.current_streak, 0, "a loss breaks the streak")
	assert_eq(a.state_of("streak_2"), ACHIEVEMENTS.STATE_UNLOCKED)


func test_play_all_needs_every_distinct_game() -> void:
	var a := _fresh()
	a.record_minigame("Olahraga", "Main Bola", false, 0, -1.0)
	a.record_minigame("Olahraga", "Main Bola", true, 1, -1.0)
	assert_eq(a.state_of("play_all_olahraga"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_minigame("Olahraga", "Badminton", false, 0, -1.0)
	assert_eq(a.state_of("play_all_olahraga"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(ACHIEVEMENTS.PLAY_ALL_REQUIRED["Akademis"].size(), 4)


func test_total_minigames_thresholds() -> void:
	var a := _fresh()
	for i in 14:
		a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	assert_eq(a.state_of("total_10"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("total_15"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	assert_eq(a.state_of("total_15"), ACHIEVEMENTS.STATE_UNLOCKED)


func test_fast_wins_need_a_win_with_half_the_time_left() -> void:
	var a := _fresh()
	a.record_minigame("Akademis", "Menjodohkan", true, 2, 0.49)
	a.record_minigame("Akademis", "Menjodohkan", false, 0, 0.9)
	a.record_minigame("Olahraga", "Badminton", true, 3, -1.0)
	assert_eq(a.fast_wins, 0)
	a.record_minigame("Akademis", "Menjodohkan", true, 2, 0.5)
	assert_eq(a.state_of("fast_1"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(AchievementCatalog.get_entry("fast_12").target, 12)


func test_money_thresholds_use_the_base() -> void:
	var a := _fresh()
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 4 - 1)
	assert_eq(a.state_of("money_2x"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("money_4x"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_money(0)
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 8)
	assert_eq(a.state_of("money_8x"), ACHIEVEMENTS.STATE_UNLOCKED)


func test_grades() -> void:
	var a := _fresh()
	a.record_grade_passed(8)
	assert_eq(a.state_of("grade_8"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)


func test_unlock_signal_fires_once() -> void:
	var a := _fresh()
	var got := []
	a.unlocked.connect(func(id): got.append(id))
	a.record_grade_passed(7)
	a.record_grade_passed(7)
	assert_eq(got, ["grade_7"])


func test_claim_only_after_unlock_and_only_once() -> void:
	var a := _fresh()
	assert_false(a.claim("grade_9"), "locked cannot be claimed")
	a.record_grade_passed(9)
	assert_true(a.claim("grade_9"))
	assert_eq(a.state_of("grade_9"), ACHIEVEMENTS.STATE_CLAIMED)
	assert_false(a.claim("grade_9"), "already claimed")


func test_prizes_apply_only_when_claimed_and_stack() -> void:
	var a := _fresh()
	for i in 50:
		a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 8)
	assert_eq(a.effect_multiplier("wirausaha"), 1.0, "unlocked is not claimed")
	a.claim("total_25")
	assert_true(absf(a.effect_multiplier("wirausaha") - 1.05) < 0.0001)
	a.claim("money_8x")
	assert_true(absf(a.effect_multiplier("wirausaha") - 1.10) < 0.0001)
	a.claim("total_50")
	assert_true(absf(a.effect_multiplier("shop_price") - 0.90) < 0.0001)
	a.claim("total_15")
	assert_eq(a.effect_multiplier("minigame_stat"), 1.0, "the Thea skin prize has no effect")


func test_save_round_trip() -> void:
	var a := _fresh()
	a.record_minigame("Olahraga", "Main Bola", true, 3, 0.8)
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 2)
	a.claim("three_star_olahraga")
	var cfg := ConfigFile.new()
	a.write_to(cfg)
	var b := _fresh()
	b.read_from(cfg)
	assert_eq(b.minigames_played, 1)
	assert_eq(b.fast_wins, 1)
	assert_eq(b.best_streak, 1)
	assert_eq(b.state_of("three_star_olahraga"), ACHIEVEMENTS.STATE_CLAIMED)
	assert_eq(b.state_of("money_2x"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_true("Main Bola" in b.played_names.get("Olahraga", []))


func test_reset_clears_everything() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	a.reset()
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)
	assert_eq(a.minigames_played, 0)


func test_static_multiplier_is_neutral_without_claims() -> void:
	# The editor's own autoload instance never loads a save (editor-hint gate).
	assert_eq(ACHIEVEMENTS.multiplier("shop_price"), 1.0)
