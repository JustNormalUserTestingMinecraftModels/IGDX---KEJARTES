@tool
extends McpTestSuite

## Source-level audit: every screen must reach AudioDirector.
##
## These tests read .gd files as text on purpose. Driving each screen
## headlessly to assert "a sound played" would need a fake AudioServer
## and would break every time a scene's layout shifts; the requirement
## here is simply that the call sites exist and use ids AudioDirector
## actually knows about.

func suite_name() -> String:
	return "audio_coverage"


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


func test_every_screen_starts_its_bgm() -> void:
	var expected := {
		"res://Scripts/MainMenu/main_menu.gd": "menu",
		"res://Scripts/UI/Settings.gd": "menu",
		"res://Scripts/Lobby/loby.gd": "lobby",
		"res://Scripts/StudentCard/student_card.gd": "lobby",
		"res://Scripts/StudentList/student_list.gd": "lobby",
		"res://Scripts/AturJadwal/atur_jadwal.gd": "lobby",
		"res://Scripts/SchoolSimulation/SchoolDay.gd": "simulation",
		"res://Scripts/EndGame/SemesterEnd.gd": "result",
	}
	for path in expected:
		var want := 'play_bgm(&"%s"' % expected[path]
		assert_true(_source(path).contains(want),
			"%s must call AudioDirector.%s)" % [path, want])


func test_no_screen_loads_an_audio_file_directly() -> void:
	# The swappability requirement: streams reach the game only through
	# AudioDirector's export slots, never a hard-coded path in a screen.
	var dir := DirAccess.open("res://Scripts")
	assert_true(dir != null, "Scripts/ must be readable")
	var offenders: Array[String] = []
	_scan_for_audio_loads("res://Scripts", offenders)
	assert_true(offenders.is_empty(),
		"scripts must not load audio directly: " + ", ".join(offenders))


func _scan_for_audio_loads(path: String, offenders: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_for_audio_loads(full, offenders)
		elif name.ends_with(".gd") and not full.ends_with("AudioDirector.gd"):
			var src := _source(full)
			for line in src.split("\n"):
				var has_load := line.contains("preload(") or line.contains("load(")
				if has_load and (line.contains(".ogg") or line.contains(".wav")):
					offenders.append(full)
					break
		name = dir.get_next()
	dir.list_dir_end()


func test_student_card_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/StudentCard/student_card.gd")
	for id in ["swipe", "stamp", "unstamp", "popup_open", "popup_close"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"student_card must play sfx: " + id)


func test_lobby_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/Lobby/loby.gd")
	for id in ["reward", "popup_open"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"loby must play sfx: " + id)


func test_student_list_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/StudentList/student_list.gd")
	assert_true(src.contains('play_sfx(&"select")'),
		"student_list must play sfx: select")


func test_atur_jadwal_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/AturJadwal/atur_jadwal.gd")
	for id in ["select", "popup_open", "popup_close", "error"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"atur_jadwal must play sfx: " + id)


func test_school_day_has_sfx_at_all() -> void:
	var src := _source("res://Scripts/SchoolSimulation/SchoolDay.gd")
	for id in ["popup_open", "reward"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"SchoolDay must play sfx: " + id)


func test_cutscene_grade_selection_has_sfx() -> void:
	var src := _source("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains('play_sfx(&"select")'),
		"cut_scene must play sfx on grade selection")


func test_every_play_sfx_id_in_the_project_is_known() -> void:
	# Guards against typos: a misspelled id is silently dropped by
	# _resolve_sfx's fallback, so it would never surface at runtime.
	var known := ["tap", "confirm", "cancel", "success", "fail", "coin",
		"whoosh", "pop", "swipe", "stamp", "unstamp", "popup_open",
		"popup_close", "select", "error", "reward"]
	var bad: Array[String] = []
	_scan_for_sfx_ids("res://Scripts", known, bad)
	assert_true(bad.is_empty(),
		"unknown sfx ids used: " + ", ".join(bad))


func _scan_for_sfx_ids(path: String, known: Array, bad: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_for_sfx_ids(full, known, bad)
		elif name.ends_with(".gd"):
			var regex := RegEx.new()
			regex.compile('play_sfx\\(&"([a-z_]+)"')
			for m in regex.search_all(_source(full)):
				var id := m.get_string(1)
				if not known.has(id) and not bad.has(id):
					bad.append("%s in %s" % [id, full])
		name = dir.get_next()
	dir.list_dir_end()
