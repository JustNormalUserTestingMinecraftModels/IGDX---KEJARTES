@tool
extends McpTestSuite

## Inventory persistence, since 2026-10-01: the inventory travels in SaveGame's
## file with the rest of the run (the old inventory-only save is gone, and
## Transition checkpoints around hub screens), and forget_session()'s reset
## covers the run-state fields.

func suite_name() -> String:
	return "inventory_persistence"

var _inv_backup: Dictionary
var _roster_backup: Array
var _money_backup: int

func setup() -> void:
	_inv_backup = GameState.inventory.duplicate(true)
	_roster_backup = GameState.approved_students.duplicate(true)
	_money_backup = GameState.player_money

func teardown() -> void:
	GameState.inventory = _inv_backup
	GameState.approved_students = _roster_backup
	GameState.player_money = _money_backup

## 2026-10-01: the inventory travels in SaveGame's file with the rest of the
## run; the old inventory-only save is gone.
func test_the_inventory_only_save_is_retired() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	for gone in ["func save_inventory", "func load_inventory", "func clear_inventory_save",
			"func _write_inventory_to", "func _read_inventory_from", "INVENTORY_SAVE_PATH"]:
		assert_false(src.contains(gone), gone + " was removed")
	assert_true(SaveGame.SAVE_KEYS.has("inventory"), "the inventory is part of the run save")


func test_forget_session_resets_run_state_but_keeps_progress_flags() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var start := src.find("func reset_run")
	assert_gt(start, 0, "reset_run must exist")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	for field in ["inventory", "approved_students", "day_schedules", "pending_earnings",
			"minigame_gain_this_week", "player_money", "minggu_ke", "current_grade",
			"run_stats"]:
		assert_contains(body, field, "reset_run must reset " + field)
	assert_false(body.contains("is_game_beaten"),
		"reset_run must NOT wipe the persisted is_game_beaten flag")
	assert_false(body.contains("debug_level_select_enabled"),
		"reset_run must NOT wipe the persisted debug_level_select flag")
	var forget_start := src.find("func forget_session")
	assert_gt(forget_start, 0, "forget_session must exist")
	var forget_body := src.substr(forget_start, src.find("\nfunc ", forget_start + 1) - forget_start)
	assert_contains(forget_body, "reset_run()", "forget_session resets the run")
	assert_contains(forget_body, "SaveGame.delete_save()", "forget_session drops the on-disk save")
	assert_contains(forget_body, "Achievements.reset()", "forget_session wipes achievement progress")
	# Reset Progres means everything: a surviving legacy inventory.cfg would
	# merge its items into the next new game, and the cart outlives the run.
	assert_contains(forget_body, "SaveGame.delete_legacy_inventory()",
		"forget_session drops the legacy inventory file")
	assert_contains(forget_body, "Cart.clear()", "forget_session empties the shop cart")

## The checkpoint must run before the scene changes: after it, `current` is
## the new scene (or null) and the hub test would read the wrong "from" path.
func test_transition_checkpoints_around_hub_screens() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Transition/Transition.gd")
	var checkpoint_at := src.find("SaveGame.checkpoint(")
	assert_true(checkpoint_at != -1, "change_scene saves around hubs")
	assert_true(checkpoint_at < src.find("change_scene_to_file("),
		"and does so while the scene being left is still current")
	assert_false(src.contains("save_inventory"), "the old flush is gone")


func test_debug_manager_has_forget_session() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
	assert_true(src.contains("_forget_session"), "debug button handler present")
	assert_true(src.contains("GameState.forget_session()"), "handler calls forget_session")
	assert_true(src.contains("MainMenu.tscn"), "handler returns to MainMenu")
