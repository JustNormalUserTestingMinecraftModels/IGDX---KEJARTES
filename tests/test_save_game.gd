@tool
extends McpTestSuite

## SaveGame (2026-10-01 save system): the pure ConfigFile half -- what is
## written, what comes back, how a resume is routed and summarised. Nothing
## here touches user://: the disk wrappers no-op in the editor and are only
## source-scanned.
##
## Must be @tool; no coroutine tests (the runner does not await).

const _SCRIPT := "res://Scripts/Save/SaveGame.gd"

var _snap: Dictionary


func suite_name() -> String:
	return "save_game"


func setup() -> void:
	_snap = EndGameRehearsal.snapshot()


func teardown() -> void:
	EndGameRehearsal.restore(_snap)


## A run worth saving: every awkward shape the file must carry.
func _seed_run() -> void:
	GameState.current_grade = 8
	GameState.minggu_ke = 3
	GameState.approved_students = [
		{"id": 1, "name": "Marcel", "akademis": 61.5, "target_akademis": 72.0},
		{"id": 4, "name": "Citra", "akademis": 40.0, "target_akademis": 72.0},
	]
	GameState.returned_from_student_card = true
	GameState.day_schedules = {1: {"Senin": {"category": "Akademis", "mood_cost": 3, "energy_cost": 5}}}
	GameState.shop_stock.assign(["Buku Tulis", "Jus Jeruk"])
	GameState.shop_sold.assign(["Jus Jeruk"])
	GameState.inventory = {"Buku Tulis": 2}
	GameState.player_money = 12345
	GameState.pending_earnings = {4: 300}
	GameState.headmaster_beats_seen = {8: true}
	GameState.run_stats.reset()
	GameState.run_stats.record_minigame(true, 6.0)
	GameState.run_stats.record_event_student(4)


func test_every_saved_field_round_trips() -> void:
	_seed_run()
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg)
	# Snapshot as text, not by reference: reset_run() empties `inventory` in
	# place, which would empty an aliased "expected" copy along with it.
	var expected := {}
	for key in SaveGame.SAVE_KEYS:
		expected[key] = var_to_str(GameState.get(key))
	var won := GameState.run_stats.minigames_won

	# Through the file's text form, as a real save is: this is what proves int
	# roster ids and typed arrays survive the serializer, not just memory.
	var back := ConfigFile.new()
	assert_eq(back.parse(cfg.encode_to_text()), OK, "the save survives its text form")

	GameState.reset_run()
	assert_true(SaveGame.read_state(back), "a fresh file reads")
	for key in SaveGame.SAVE_KEYS:
		assert_eq(var_to_str(GameState.get(key)), expected[key], key + " round-trips")
	assert_eq(GameState.max_minggu, GameState.weeks_for_grade(8),
		"current_grade is restored through its setter, so max_minggu follows")
	assert_eq(GameState.run_stats.minigames_won, won, "run_stats round-trips")
	assert_true(GameState.day_schedules.has(1), "int roster ids stay int keys")
	assert_eq(GameState.shop_stock.get_typed_builtin(), TYPE_STRING, "typed arrays stay typed")


func test_every_game_state_field_is_saved_or_deliberately_excluded() -> void:
	var missing: Array[String] = []
	for prop in GameState.get_script().get_script_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = prop.name
		if name.begins_with("_") or name == "run_stats":
			continue
		if SaveGame.SAVE_KEYS.has(name) or SaveGame.EXCLUDED.has(name):
			continue
		missing.append(name)
	assert_eq(missing.size(), 0,
		"GameState fields neither saved nor excluded: " + ", ".join(missing))
	for key in SaveGame.SAVE_KEYS:
		assert_false(SaveGame.EXCLUDED.has(key), key + " is both saved and excluded")


func test_run_stats_round_trips_through_a_dictionary() -> void:
	var a := RunStats.new()
	a.record_minigame(true, 4.0)
	a.record_minigame(false, -2.0)
	a.record_event_student(3)
	var b := RunStats.new()
	b.from_dict(a.to_dict())
	assert_eq(var_to_str(b.to_dict()), var_to_str(a.to_dict()), "every tally survives")
	b.from_dict({"no_such_tally": 9})
	assert_eq(b.minigames_won, 0, "from_dict resets first and ignores unknown keys")


func test_the_week_section_round_trips_and_a_plain_save_drops_it() -> void:
	_seed_run()
	var week := {"resume_day": 3, "minigames_played": 1, "events_triggered": 0,
		"max_events": 2, "max_minigames": 3,
		"manager": {"students": [{"id": 1, "akademis": 64.0}], "minigame_history": [],
			"daily_stat_log": {"Senin": []}}}
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg, week)
	assert_eq(var_to_str(SaveGame.week_from(cfg)), var_to_str(week), "the week comes back whole")
	SaveGame.write_state(cfg)
	assert_true(SaveGame.week_from(cfg).is_empty(), "a save without a week clears the old one")


func test_resume_routes_by_week_then_roster() -> void:
	assert_eq(SaveGame.resume_scene({"resume_day": 2}, true), SaveGame.SCHOOL_DAY_SCENE)
	assert_eq(SaveGame.resume_scene({}, true), SaveGame.LOBBY_SCENE)
	assert_eq(SaveGame.resume_scene({}, false), SaveGame.STUDENT_CARD_SCENE)


func test_the_summary_names_grade_week_and_day() -> void:
	_seed_run()
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg)
	assert_eq(SaveGame.summary_for(cfg), "Kelas 8 · Minggu 3/%d" % GameState.weeks_for_grade(8))
	SaveGame.write_state(cfg, {"resume_day": 3})
	assert_true(SaveGame.summary_for(cfg).ends_with(" · Kamis"), "day 3 resumes on Kamis")
	SaveGame.write_state(cfg, {"resume_day": 5})
	assert_true(SaveGame.summary_for(cfg).ends_with(" · Akhir Pekan"),
		"after Jumat only the weekly report is left")


func test_an_unusable_file_is_refused_without_touching_state() -> void:
	_seed_run()
	var newer := ConfigFile.new()
	newer.set_value("meta", "version", SaveGame.VERSION + 1)
	newer.set_value("state", "player_money", 1)
	assert_false(SaveGame.is_usable(newer), "a newer version is refused")
	assert_false(SaveGame.read_state(newer))
	assert_eq(GameState.player_money, 12345, "and nothing was applied")
	assert_false(SaveGame.is_usable(ConfigFile.new()), "a file with no version is refused")


func test_disk_functions_are_editor_gated_and_atomic() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for fn in ["has_save", "save", "load_save", "summary", "delete_save", "take_legacy_inventory"]:
		var body: String = src.get_slice("static func %s(" % fn, 1).get_slice("\nstatic func ", 0)
		assert_true(body.contains("Engine.is_editor_hint()"), fn + " must no-op in the editor")
	var save_body: String = src.get_slice("static func save(", 1).get_slice("\nstatic func ", 0)
	assert_true(save_body.contains("TMP_PATH") and save_body.contains("rename_absolute"),
		"save writes a temp file and renames it over the real one")
	assert_true(save_body.contains("approved_students.is_empty()"),
		"a run with no roster has nothing to continue and writes nothing")


func test_checkpoints_fire_only_around_hub_screens() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var body: String = src.get_slice("static func checkpoint(", 1).get_slice("\nstatic func ", 0)
	assert_true(body.contains("HUB_SCENES.has(from_path)") and body.contains("HUB_SCENES.has(to_path)"))
	assert_true(SaveGame.HUB_SCENES.has(SaveGame.LOBBY_SCENE))
	assert_true(SaveGame.HUB_SCENES.has("res://Scenes/AturJadwal/AturJadwal.tscn"),
		"leaving AturJadwal for SchoolDay saves the planned week")
	assert_false(SaveGame.HUB_SCENES.has(SaveGame.SCHOOL_DAY_SCENE),
		"SchoolDay saves itself, after each day's result, never mid-day")
	for path in SaveGame.HUB_SCENES:
		assert_true(ResourceLoader.exists(path), path + " exists")
