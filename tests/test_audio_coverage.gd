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
