@tool
extends McpTestSuite

## Inventory persistence: the pure serialise/deserialise pair round-trips,
## the disk path is is_editor_hint-gated (no file appears in test context),
## and forget_session() clears in-memory run state.

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
	if FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH):
		DirAccess.remove_absolute(GameState.INVENTORY_SAVE_PATH)

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
	cfg.set_value("inventory", "items", {"Komik": 2})
	GameState._read_inventory_from(cfg)
	for k in GameState.inventory:
		assert_true(k is String)
		assert_true(typeof(GameState.inventory[k]) == TYPE_INT)

func test_save_inventory_is_gated_in_editor_context() -> void:
	if FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH):
		DirAccess.remove_absolute(GameState.INVENTORY_SAVE_PATH)
	GameState.inventory = {"Komik": 1}
	GameState.save_inventory()
	assert_false(FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH),
		"save_inventory must no-op under Engine.is_editor_hint()")

func test_forget_session_clears_run_state() -> void:
	GameState.inventory = {"Komik": 1}
	GameState.approved_students = [{"id": 1, "name": "A"}]
	GameState.player_money = 5000
	GameState.forget_session()
	assert_true(GameState.inventory.is_empty())
	assert_true(GameState.approved_students.is_empty())
	assert_eq(GameState.player_money, 0)

func test_transition_flushes_inventory_on_scene_change() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Transition/transition.gd")
	assert_true(src.contains("GameState.save_inventory()"),
		"change_scene must flush the inventory save")
	assert_true(src.contains("is_editor_hint"),
		"the save call must be editor-gated")
