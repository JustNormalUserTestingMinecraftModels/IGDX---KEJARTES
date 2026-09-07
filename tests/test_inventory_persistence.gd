@tool
extends McpTestSuite

## Inventory persistence: the pure serialise/deserialise pair round-trips,
## the disk path is is_editor_hint-gated (no file appears in test context),
## and forget_session()'s reset covers the run-state fields.

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

func test_write_then_read_round_trips() -> void:
	GameState.inventory = {"Komik": 3, "Raket": 1}
	var cfg := ConfigFile.new()
	GameState._write_inventory_to(cfg)
	GameState.inventory = {}
	GameState._read_inventory_from(cfg)
	assert_eq(GameState.inventory.get("Komik"), 3)
	assert_eq(GameState.inventory.get("Raket"), 1)

func test_read_from_empty_config_leaves_inventory_empty() -> void:
	GameState.inventory = {"stale": 9}
	GameState._read_inventory_from(ConfigFile.new())
	assert_true(GameState.inventory.is_empty())

func test_read_coerces_types() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("inventory", "items", {StringName("Komik"): 2.0})
	GameState._read_inventory_from(cfg)
	for k in GameState.inventory:
		assert_true(k is String)
		assert_true(typeof(GameState.inventory[k]) == TYPE_INT)
	assert_eq(GameState.inventory.get("Komik"), 2)

func test_save_inventory_is_gated_in_editor_context() -> void:
	# State-independent: save_inventory() must not CREATE (or remove) the
	# file in editor/test context, whatever was there before.
	var existed_before := FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH)
	GameState.inventory = {"Komik": 1}
	GameState.save_inventory()
	assert_eq(FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH), existed_before,
		"save_inventory must no-op on disk under Engine.is_editor_hint()")

func test_forget_session_resets_run_state_but_keeps_progress_flags() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var start := src.find("func forget_session")
	assert_gt(start, 0, "forget_session must exist")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	for field in ["inventory", "approved_students", "day_schedules", "pending_earnings",
			"minigame_gain_this_week", "player_money", "minggu_ke", "current_grade",
			"run_stats"]:
		assert_contains(body, field, "forget_session must reset " + field)
	assert_false(body.contains("is_game_beaten"),
		"forget_session must NOT wipe the persisted is_game_beaten flag")
	assert_false(body.contains("debug_level_select_enabled"),
		"forget_session must NOT wipe the persisted debug_level_select flag")
	assert_contains(body, "clear_inventory_save()", "forget_session drops the on-disk save")

func test_transition_flushes_inventory_on_scene_change() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Transition/transition.gd")
	assert_true(src.contains("GameState.save_inventory()"),
		"change_scene must flush the inventory save")
	assert_true(src.contains("is_editor_hint"),
		"the save call must be editor-gated")

func test_debug_manager_has_forget_session() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
	assert_true(src.contains("_forget_session"), "debug button handler present")
	assert_true(src.contains("GameState.forget_session()"), "handler calls forget_session")
	assert_true(src.contains("main_menu.tscn"), "handler returns to MainMenu")
