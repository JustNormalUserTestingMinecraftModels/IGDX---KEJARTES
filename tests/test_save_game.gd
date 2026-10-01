@tool
extends McpTestSuite

## SaveGame (2026-10-01 save system): the pure ConfigFile half -- what is
## written, what comes back, how a resume is routed and summarised. Nothing
## here touches user://: the disk wrappers no-op in the editor and are only
## source-scanned.
##
## Must be @tool; no coroutine tests (the runner does not await).

const _SCRIPT := "res://Scripts/Save/SaveGame.gd"
const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const _ATUR_JADWAL := "res://Scripts/AturJadwal/AturJadwal.gd"
const _STUDENT_LIST := "res://Scripts/StudentList/StudentList.gd"
## Fields reset_run() resets that EndGameRehearsal.snapshot() leaves out;
## setup() stashes them so a test that wipes the run puts them back.
const _UNSNAPSHOTTED := ["next_scene", "selected_day", "daily_login_day",
	"last_claim_date", "seen_minigame_how_to", "pending_week_resume"]

var _snap: Dictionary
var _extra: Dictionary
var _flags: Dictionary


func suite_name() -> String:
	return "save_game"


func setup() -> void:
	_snap = EndGameRehearsal.snapshot()
	_extra = {}
	for key in _UNSNAPSHOTTED:
		var value: Variant = GameState.get(key)
		_extra[key] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	_flags = SaveGame.tutorial_flags()


func teardown() -> void:
	EndGameRehearsal.restore(_snap)
	for key in _extra:
		GameState.set(key, _extra[key])
	SaveGame.restore_tutorial_flags(_flags)


## A run worth saving: every SAVE_KEYS field off its default, in every
## awkward shape the file must carry (int keys, typed arrays, float values).
func _seed_run() -> void:
	GameState.current_grade = 8
	GameState.minggu_ke = 3
	GameState.approved_students = [
		{"id": 1, "name": "Marcel", "akademis": 61.5, "target_akademis": 72.0},
		{"id": 4, "name": "Citra", "akademis": 40.0, "target_akademis": 72.0},
	]
	GameState.returned_from_student_card = true
	GameState.day_schedules = {1: {"Senin": {"category": "Akademis", "mood_cost": 3, "energy_cost": 5}}}
	GameState.minigame_gain_this_week = {1: 6.5, 4: 2.0}
	GameState.shop_week_key = "8-3"
	GameState.shop_stock.assign(["Buku Tulis", "Jus Jeruk"])
	GameState.shop_sold.assign(["Jus Jeruk"])
	GameState.shop_promo_item = "Buku Tulis"
	GameState.shop_promo_percent = 20
	GameState.lobby_tutorial_completed = true
	GameState.tutorials_bypassed = true
	GameState.seen_minigame_how_to = {"res://Resources/Minigames/HowTo/menjodohkan.tres": true}
	GameState.headmaster_beats_seen = {8: true}
	GameState.grade7_student_ids = [1, 4]
	GameState.grade8_student_ids = [4]
	GameState.equipped_skins = {"Marcel": "skin1"}
	GameState.skin_unlock_overrides = {"Citra:skin1": false}
	GameState.inventory = {"Buku Tulis": 2}
	GameState.player_money = 12345
	GameState.pending_earnings = {4: 300}
	GameState.ad_debt = 3
	GameState.daily_login_day = 4
	GameState.last_claim_date = "2026-10-01"
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
	var won: int = GameState.run_stats.minigames_won

	# Through the file's text form, as a real save is: this is what proves int
	# roster ids and typed arrays survive the serializer, not just memory.
	var back := ConfigFile.new()
	assert_eq(back.parse(cfg.encode_to_text()), OK, "the save survives its text form")

	GameState.reset_run()
	# The positive control: were a field seeded at its default, the restore
	# check below would pass even if write_state or read_state skipped it.
	for key in SaveGame.SAVE_KEYS:
		assert_ne(var_to_str(GameState.get(key)), expected[key], key + " was seeded off its default")
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


## The first-run tutorial flags are static vars, which every launch resets, so
## the save carries them: without that, a resumed run replayed AturJadwal's
## and StudentList's walkthroughs after every relaunch. A new run (reset_run)
## clears them. Through the file's text form, as a real save is.
func test_the_tutorial_flags_ride_the_save_and_a_new_run_clears_them() -> void:
	_seed_run()
	SaveGame.set_tutorial_flag(_ATUR_JADWAL, "tutorial_phase1_done", true)
	SaveGame.set_tutorial_flag(_ATUR_JADWAL, "tutorial_phase3_done", false)
	SaveGame.set_tutorial_flag(_STUDENT_LIST, "tutorial_shown", true)
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg)
	var back := ConfigFile.new()
	assert_eq(back.parse(cfg.encode_to_text()), OK, "the flags survive the text form")

	GameState.reset_run()
	var atur := load(_ATUR_JADWAL) as GDScript
	var list := load(_STUDENT_LIST) as GDScript
	assert_eq(atur.get("tutorial_phase1_done"), false, "a new run replays the scheduling tutorial")
	assert_eq(list.get("tutorial_shown"), false, "and the roster walkthrough")
	assert_true(SaveGame.read_state(back), "the file reads")
	assert_eq(atur.get("tutorial_phase1_done"), true, "a resumed run remembers what already played")
	assert_eq(atur.get("tutorial_phase3_done"), false, "and what has not")
	assert_eq(list.get("tutorial_shown"), true)


## Every static var named for a tutorial is in SaveGame.TUTORIAL_FLAGS: the
## GameState ratchet above cannot see a screen's static, which is how these
## three were once left out of the save.
func test_every_tutorial_static_rides_the_save() -> void:
	var re := RegEx.create_from_string("(?m)^static var (\\w*tutorial\\w*)")
	var found := 0
	for path in _scripts_under("res://Scripts"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			var flags: Array = SaveGame.TUTORIAL_FLAGS.get(path, [])
			assert_true(flags.has(m.get_string(1)),
				"%s's static %s must be in SaveGame.TUTORIAL_FLAGS" % [path, m.get_string(1)])
	assert_true(found >= 3, "the scan finds the three known flags")


## Every .gd file under `dir`, recursively.
func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out


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


## A version-valid file with one wrong-typed value is refused whole, before
## anything is applied. It used to raise mid-read with current_grade and
## minggu_ke already applied, and then the new game it fell through to deleted
## the file instead of quarantining it.
func test_a_wrong_typed_value_is_refused_before_anything_is_applied() -> void:
	_seed_run()
	var good := ConfigFile.new()
	SaveGame.write_state(good)
	GameState.current_grade = 9
	GameState.minggu_ke = 2
	for bad in [["shop_stock", 5], ["day_schedules", 3], ["player_money", "banyak"],
			["shop_sold", [1, 2]], ["run_stats", 4], ["tutorial_flags", "ya"]]:
		var cfg := ConfigFile.new()
		assert_eq(cfg.parse(good.encode_to_text()), OK)
		cfg.set_value("state", bad[0], bad[1])
		assert_false(SaveGame.is_usable(cfg), "%s = %s is refused" % [bad[0], var_to_str(bad[1])])
		assert_false(SaveGame.read_state(cfg))
		assert_eq(GameState.current_grade, 9, "nothing applied for a bad %s" % bad[0])
		assert_eq(GameState.minggu_ke, 2, "nothing applied for a bad %s" % bad[0])
	var close := ConfigFile.new()
	assert_eq(close.parse(good.encode_to_text()), OK)
	close.set_value("state", "player_money", 12345.0)
	assert_true(SaveGame.read_state(close), "a float where an int lives still reads")
	assert_eq(typeof(GameState.player_money), TYPE_INT, "as the field's own type")
	assert_eq(GameState.player_money, 12345)


func test_disk_functions_are_editor_gated_and_atomic() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for fn in ["has_save", "save", "load_save", "summary", "delete_save", "read_legacy_inventory"]:
		var body: String = src.get_slice("static func %s(" % fn, 1).get_slice("\nstatic func ", 0)
		assert_true(body.contains("Engine.is_editor_hint()"), fn + " must no-op in the editor")
	var save_body: String = src.get_slice("static func save(", 1).get_slice("\nstatic func ", 0)
	assert_true(save_body.contains("TMP_PATH") and save_body.contains("rename_absolute"),
		"save writes a temp file and renames it over the real one")
	assert_true(save_body.contains("approved_students.is_empty()"),
		"a run with no roster has nothing to continue and writes nothing")


## An unusable file -- unparseable, newer, or wrong-typed, all is_usable() --
## is moved to BAD_PATH for debugging, not deleted.
func test_an_unusable_save_is_quarantined() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var usable: String = src.get_slice("static func _load_usable(", 1).get_slice("\nstatic func ", 0)
	var check := usable.find("is_usable(cfg)")
	var moved := usable.find("rename_absolute(SAVE_PATH, BAD_PATH)")
	assert_true(check != -1 and moved > check, "a file is_usable() refuses is moved aside")


## A save whose renames both failed lives only in TMP_PATH. has_save() used to
## miss it, and the new game the tap then fell through to deleted it.
func test_a_run_left_in_the_temp_file_is_recovered() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var usable: String = src.get_slice("static func _load_usable(", 1).get_slice("\nstatic func ", 0)
	assert_true(usable.contains("if not FileAccess.file_exists(SAVE_PATH):\n\t\treturn _recover_temp()"),
		"with no save in place, the temp file is tried")
	var recover: String = src.get_slice("static func _recover_temp(", 1).get_slice("\nstatic func ", 0)
	assert_true(recover.contains("not is_usable(cfg)"), "only a usable temp file is recovered")
	assert_true(recover.contains("rename_absolute(TMP_PATH, SAVE_PATH)"), "it is moved into place")
	assert_true(recover.contains("return cfg"), "and read even if that move fails again")


## The legacy inventory file goes only once a run carrying its items is on
## disk. Deleted as it was read, a quit before the first save (the intro, the
## roster pick) lost the pre-update purchases for good.
func test_the_legacy_inventory_outlives_a_quit_before_the_first_save() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var read: String = src.get_slice("static func read_legacy_inventory(", 1).get_slice("\nstatic func ", 0)
	assert_true(read.contains("cfg.load(LEGACY_INVENTORY_PATH)"), "the reader was found")
	assert_false(read.contains("remove_absolute"), "reading leaves the file in place")
	var save_body: String = src.get_slice("static func save(", 1).get_slice("\nstatic func ", 0)
	assert_true(save_body.contains("(error %d)\" % err)\n\t\treturn\n"
			+ "\tdelete_legacy_inventory()"),
		"save() drops the file only past the failed-rename return, with the run in place")
	var drop: String = src.get_slice("static func delete_legacy_inventory(", 1).get_slice("\nstatic func ", 0)
	assert_true(drop.contains("if FileAccess.file_exists(LEGACY_INVENTORY_PATH):\n"
			+ "\t\tDirAccess.remove_absolute(LEGACY_INVENTORY_PATH)"),
		"delete_legacy_inventory() removes the legacy file")


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


## Which branch saves matters: swapped, every won grade would delete the save
## and every Kelas 7 loss would re-save a dead run.
func test_run_result_saves_a_continuing_run_and_deletes_an_ended_one() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	var body: String = src.get_slice("var destination := _apply_progression()", 1) \
		.get_slice("var tween", 0)
	assert_true(body.contains("if destination == ROSTER_SCENE:\n\t\tSaveGame.save()\n"
			+ "\telse:\n\t\tSaveGame.delete_save()"),
		"a run going on to StudentCard is saved; a run ending at the menu is deleted")


## Boot touches no save: it loads only when the player picks Lanjutkan. The
## slice stops at _ready's first blank line, short of the next function's doc.
func test_boot_no_longer_loads_anything() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_true(src.contains("func _ready()"), "GameState._ready was found")
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\n\n", 0)
	assert_false(ready.contains("SaveGame"), "the save loads only when the player picks Lanjutkan")


## The week in progress: StudentManager's live and week-start stats, and the
## history the weekly report reads, survive a save -- through the file's text
## form, as the real [week] section does (typed arrays inside the history).
func test_student_manager_round_trips_a_week_in_progress() -> void:
	GameState.approved_students = [
		{"id": 1, "name": "Marcel", "akademis": 50.0, "seni_budaya": 50.0, "olahraga": 50.0,
			"energy": 80.0, "mood": 80.0, "hobby_category": "Olahraga"},
	]
	var a := StudentManager.new()
	track(a)
	a.initialize_from_gamestate()
	a.students[0].akademis = 58.5
	a.students[0].energy = 61.0
	a.log_stat_change("Senin", "Marcel", "akademis", 8.5, "activity")
	a.record_event_result("Senin", "Hujan", ["Marcel"], "basah")
	var cfg := ConfigFile.new()
	cfg.set_value("week", "manager", a.to_save_dict())
	var back := ConfigFile.new()
	assert_eq(back.parse(cfg.encode_to_text()), OK, "the week survives its text form")

	var b := StudentManager.new()
	track(b)
	b.restore_from_save(back.get_value("week", "manager"))
	assert_eq(b.students.size(), 1)
	assert_eq(b.students[0].akademis, 58.5, "the live stat comes back")
	assert_eq(b.students[0].energy, 61.0)
	assert_eq(b.students[0].initial_akademis, 50.0, "the week-start stat too, for the report's deltas")
	assert_eq(b.minigame_history.size(), 1, "the week's history comes back")
	assert_eq(var_to_str(b.minigame_history), var_to_str(a.minigame_history), "entry for entry")
	assert_eq((b.daily_stat_log["Senin"] as Array).size(), 1, "and the day log")


## The daily save sits after the day's result, and only while the week is
## not skipped: a skip tapped over the summary has finished the week, and a
## save then would resume a finished week and replay its payout and report.
func test_school_day_saves_after_each_days_result() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	var summary_at := src.find("await _show_day_summary(day_name)")
	var save_at := src.find("SaveGame.save(_week_snapshot(current_day + 1))")
	var click_at := src.find("await _await_click_to_continue()")
	assert_true(save_at > summary_at and save_at < click_at,
		"the daily save sits right after the day's result is shown")
	assert_true(src.contains("if not is_skipped:\n\t\tSaveGame.save(_week_snapshot(current_day + 1))"),
		"and never once a skip has finished the week")


## The hand-off is one-shot: left set, every later week's SchoolDay would
## resume the old week (wrong day, stale quotas).
func test_school_day_resumes_a_saved_week() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	assert_true(ready.contains("GameState.pending_week_resume"), "_ready looks for a saved week")
	var taken := ready.find("var week")
	var cleared := ready.find("GameState.pending_week_resume = {}")
	var resumed := ready.find("resume_simulation(")
	assert_true(taken != -1 and cleared > taken and resumed > cleared,
		"_ready takes the week, empties the hand-off, then resumes it")
	var resume: String = src.get_slice("func resume_simulation(", 1).get_slice("\nfunc ", 0)
	assert_true(resume.contains("restore_from_save("), "the roster comes from the save")
	assert_false(resume.contains("minigame_gain_this_week.clear()"),
		"a resumed week keeps its minigame-gain budget, unlike a fresh one")
	assert_true(resume.contains("_run_day()"), "and the day loop runs from resume_day")


## A resume at resume_day 5 runs no day, so the week's closing screen sets the
## calendar badge and the banner's fill itself: the badge read "Minggu" with no
## number, and the cream "Akhir Pekan" sat nearly invisible on the default
## white fill. The fill is Jumat's, as the last school day leaves it.
func test_the_weeks_end_names_the_week_even_after_a_resume() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	var done: String = src.get_slice("func _on_week_complete()", 1).get_slice("\nfunc ", 0)
	var week_at := done.find("\"set_week\", GameState.minggu_ke, GameState.get_max_weeks()")
	var style_at := done.find("\"set_day_style\", Juice.tokens().category_color("
		+ "DAY_CATEGORIES[DAYS.size() - 1]), DAYS.size() - 1)")
	var banner_at := done.find("\"set_banner\", \"Akhir Pekan\"")
	assert_true(week_at != -1 and week_at < banner_at,
		"the badge is set before the closing banner is written")
	assert_true(style_at != -1 and style_at < banner_at,
		"and so is Jumat's fill, so the banner's text reads")
