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
		"res://Scripts/SchoolSimulation/SchoolDay.gd": "simulation",
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
	for id in ["swipe", "stamp", "unstamp"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"student_card must play sfx: " + id)
	# popup_open/popup_close now live in the shared popup scenes student_card
	# instantiates (StatDetailPopup.gd, TraitDetailPopup.gd), not in
	# student_card.gd itself.
	var stat_popup_src := _source("res://Scripts/UI/StatDetailPopup.gd")
	var trait_popup_src := _source("res://Scripts/UI/TraitDetailPopup.gd")
	for id in ["popup_open", "popup_close"]:
		assert_true(stat_popup_src.contains('play_sfx(&"%s")' % id),
			"StatDetailPopup must play sfx: " + id)
		assert_true(trait_popup_src.contains('play_sfx(&"%s")' % id),
			"TraitDetailPopup must play sfx: " + id)


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
		"popup_close", "select", "error", "reward", "tally", "sparkle",
		"specialty_match",
		"pill_tap", "pill_popup_open", "pill_popup_close", "pane_swipe",
		"star_earn_1", "star_earn_2", "star_earn_3", "result_fanfare",
		"score_tick", "combo_up",
		]
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


func test_day_summary_popup_has_sfx() -> void:
	var src := _source("res://Scripts/SchoolSimulation/DaySummaryPopup.gd")
	for id in ["popup_open", "success", "fail"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"DaySummaryPopup must play sfx: " + id)


func test_daily_decay_overview_has_sfx() -> void:
	var src := _source("res://Scripts/SchoolSimulation/DailyDecayOverview.gd")
	for id in ["popup_open", "popup_close"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"DailyDecayOverview must play sfx: " + id)


func test_result_checkup_has_sfx() -> void:
	var src := _source("res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_true(src.contains('play_sfx(&"popup_open")'),
		"ResultCheckup must play sfx: popup_open")
	assert_true(src.contains('play_sfx(&"confirm")'),
		"ResultCheckup must play sfx: confirm")


func test_semester_end_has_sfx() -> void:
	var src := _source("res://Scripts/EndGame/SemesterEnd.gd")
	assert_true(src.contains('play_sfx(&"reward")'),
		"SemesterEnd must play sfx: reward")
	assert_true(src.contains('play_sfx(&"success" if passed else &"fail")'),
		"SemesterEnd must play a pass/fail verdict sfx per card")


# ======================================================================
# Double-fire guard: prove an sfx id is not just PRESENT, but fires ONCE
# per player action. The other tests in this file only assert an id
# appears in a script's source; that is silent about a function that
# plays two cues back to back on the same execution path -- exactly how
# both of this pass's double-fire bugs (StudentCard swipe, DaySummaryPopup
# day verdict) got through review.
# ======================================================================

## Reviewed exceptions: a function that plays two sfx cues with no
## await between them, where that is a deliberate "two is fine" combo
## (see student_card.gd's _on_belajar_pressed note) rather than a bug.
## Keyed "res://path.gd:func_name". Every entry must be justified here.
const _DOUBLE_FIRE_ALLOWLIST := {
	# select (choosing an activity) + popup_close (the sheet closing as a
	# direct result of that choice) -- two cues, not three, and the close
	# is a consequence of the same tap, matching the project's existing
	# "two is fine" convention.
	"res://Scripts/AturJadwal/atur_jadwal.gd:_on_activity_selected": "select + popup_close from the same tap, reviewed",
	# error (this day is locked) + popup_open (the warning explaining why)
	# -- explicitly required together by this fix wave's popup-open pass.
	"res://Scripts/AturJadwal/atur_jadwal.gd:_on_day_pressed": "error + popup_open, both required by spec R2",
	# _show_peringatan()'s popup_open + this function's own "fail" --
	# opening the warning dialog and rejecting the action it warns about
	# are one player action, pre-existing before this pass.
	"res://Scripts/AturJadwal/atur_jadwal.gd:_show_combined_warning": "popup_open (via _show_peringatan) + fail, reviewed",
	"res://Scripts/AturJadwal/atur_jadwal.gd:_show_incomplete_schedule_warning": "popup_open (via _show_peringatan) + fail, reviewed",
	# _update_money_display()'s conditional "coin" (only when the balance
	# actually rose) + this function's own "reward" chime -- the coin bump
	# and the claim confirmation are one player action, pre-existing.
	"res://Scripts/Lobby/loby.gd:_on_claim_pressed": "coin (via _update_money_display) + reward, reviewed",
}


func test_no_function_double_fires_sfx_without_await() -> void:
	var offenders: Array[String] = []
	_scan_for_double_sfx("res://Scripts", offenders)
	assert_true(offenders.is_empty(),
		"function(s) may play two sfx cues on one path with no await between: "
			+ ", ".join(offenders))


func _scan_for_double_sfx(path: String, offenders: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_for_double_sfx(full, offenders)
		elif name.ends_with(".gd"):
			_check_file_for_double_sfx(full, offenders)
		name = dir.get_next()
	dir.list_dir_end()


## Splits `path` into top-level function bodies, notes which functions
## directly call play_sfx( anywhere in their body, then walks each
## function looking for two "sfx events" -- a direct play_sfx( call, or a
## bare call to another local function that itself directly plays an sfx
## -- with no "await" and no intervening branch-exclusion between them.
## Two kinds of line are excluded from ever counting as an event:
##   - lines inside an anonymous `func(...):` body (a signal callback,
##     tween_callback, etc.) -- those run later, not on this execution
##     path, so they cannot stack with an event that already happened;
## and two kinds of line make a preceding event NOT count against a
## later one ("exclusion"):
##   - an elif/else at or above the first event's indent (the two events
##     are in mutually exclusive branches of the same if-chain);
##   - a `return` (or `return <expr>`) at or above the first event's
##     indent (an early-return guard clause: nothing after it in that
##     branch runs, so a later event in the function is unreachable from
##     this one).
func _check_file_for_double_sfx(path: String, offenders: Array[String]) -> void:
	var src := _source(path)
	if src == "":
		return
	var lines := src.split("\n")

	# 1. Slice into top-level functions (func at column 0).
	var func_starts: Array = []  # [{name, start}]
	for i in lines.size():
		var line: String = lines[i]
		if line.begins_with("func "):
			var name_part := line.substr(5)
			var paren := name_part.find("(")
			var fname := name_part.substr(0, paren) if paren >= 0 else name_part
			func_starts.append({"name": fname, "start": i})

	# 2. Which functions directly call play_sfx( anywhere in their body.
	var direct_players := {}
	for idx in func_starts.size():
		var start: int = func_starts[idx]["start"]
		var end: int = func_starts[idx + 1]["start"] if idx + 1 < func_starts.size() else lines.size()
		for j in range(start, end):
			if lines[j].contains("play_sfx("):
				direct_players[func_starts[idx]["name"]] = true
				break

	# 3. Scan each function for two sfx-equivalent events with no await
	#    and no branch exclusion between them.
	for idx in func_starts.size():
		var fname: String = func_starts[idx]["name"]
		var key := path + ":" + fname
		if _DOUBLE_FIRE_ALLOWLIST.has(key):
			continue
		var start: int = func_starts[idx]["start"]
		var end: int = func_starts[idx + 1]["start"] if idx + 1 < func_starts.size() else lines.size()

		var events: Array = []  # [{line, indent}]
		var lambda_stack: Array[int] = []
		for j in range(start, end):
			var line: String = lines[j]
			var stripped_for_lambda := line.strip_edges()
			if stripped_for_lambda != "":
				var cur_indent := _indent_of(line)
				while not lambda_stack.is_empty() and cur_indent <= lambda_stack[lambda_stack.size() - 1]:
					lambda_stack.remove_at(lambda_stack.size() - 1)

			var inside_lambda := not lambda_stack.is_empty()
			if not inside_lambda:
				var is_event := line.contains("play_sfx(")
				if not is_event:
					for other_name in direct_players.keys():
						if other_name != fname and line.contains(str(other_name) + "("):
							is_event = true
							break
				if is_event:
					events.append({"line": j, "indent": _indent_of(line)})

			# An anonymous function body ("func(...):" not at column 0, i.e.
			# not this file's own top-level function declarations) runs
			# later, not inline -- everything more indented than this line
			# is out of scope for event detection until we dedent back out.
			if line.contains("func(") and not line.begins_with("func "):
				lambda_stack.append(_indent_of(line))

		for e in range(1, events.size()):
			var prev: Dictionary = events[e - 1]
			var cur: Dictionary = events[e]
			var has_await := false
			var has_exclusion := false
			for j in range(int(prev["line"]) + 1, int(cur["line"])):
				var stripped: String = lines[j].strip_edges()
				if stripped.contains("await"):
					has_await = true
				var is_branch_split := stripped.begins_with("elif ") \
					or stripped.begins_with("elif(") \
					or stripped == "else:" \
					or stripped.begins_with("else:") \
					or stripped.begins_with("else ")
				var is_early_return := stripped == "return" or stripped.begins_with("return ") \
					or stripped.begins_with("return(")
				if (is_branch_split or is_early_return) and _indent_of(lines[j]) <= int(prev["indent"]):
					has_exclusion = true
			if not has_await and not has_exclusion:
				offenders.append("%s:%s (lines %d,%d)" % [
					path, fname, int(prev["line"]) + 1, int(cur["line"]) + 1])
				break  # one report per function is enough


func test_title_intro_result_screens_start_their_bgm() -> void:
	var expected := {
		"res://Scripts/Splashscreen/splashscreen.gd": 'play_bgm(&"titlescreen")',
		"res://Scripts/MainMenu/main_menu.gd": 'play_bgm(&"titlescreen")',
		"res://Scripts/UI/Settings.gd": 'play_bgm(&"titlescreen")',
	}
	for path in expected:
		assert_true(_source(path).contains(expected[path]),
			"%s must call AudioDirector.%s" % [path, expected[path]])
	var cutscene_src := _source("res://Scripts/CutScene/cut_scene.gd")
	assert_true(cutscene_src.contains('play_bgm(&"introcutscene")'),
		"cut_scene.gd must play the intro track")
	assert_true(cutscene_src.contains('play_bgm(&"result_lose")'),
		"cut_scene.gd must play result_lose for the game-over retry cutscene")
	var semester_src := _source("res://Scripts/EndGame/SemesterEnd.gd")
	assert_true(semester_src.contains('play_bgm(&"result_win")'),
		"SemesterEnd.gd must play result_win on a pass")
	assert_true(semester_src.contains('play_bgm(&"result_lose")'),
		"SemesterEnd.gd must play result_lose on a fail")


func _indent_of(line: String) -> int:
	var count := 0
	for c in line:
		if c == "\t" or c == " ":
			count += 1
		else:
			break
	return count


func test_school_day_pauses_and_resumes_around_minigames() -> void:
	var src := _source("res://Scripts/SchoolSimulation/SchoolDay.gd")
	for needle in ["AudioDirector.pause_bgm()", "AudioDirector.play_minigame_bgm(",
			"AudioDirector.stop_minigame_bgm()", "AudioDirector.resume_bgm()"]:
		assert_true(src.contains(needle),
			"SchoolDay.gd must call: " + needle)


func test_lobby_family_screens_use_the_playlist_not_plain_play_bgm() -> void:
	for path in [
		"res://Scripts/Lobby/loby.gd",
		"res://Scripts/StudentCard/student_card.gd",
		"res://Scripts/StudentList/student_list.gd",
		"res://Scripts/AturJadwal/atur_jadwal.gd",
	]:
		var src := _source(path)
		assert_true(src.contains('play_bgm_playlist(&"lobby")'),
			path + " must start the lobby playlist")
		assert_true(not src.contains('play_bgm(&"lobby")'),
			path + " must not use the retired single-track lobby call")


## The six cues the 2026-09-04 minigame reward pass added. Each currently
## aliases an existing stream; the ids are the contract, the files are not.
const REWARD_SFX_IDS := [
	&"star_earn_1", &"star_earn_2", &"star_earn_3",
	&"result_fanfare", &"score_tick", &"combo_up",
]


func test_every_reward_cue_resolves_to_a_real_stream() -> void:
	for id in REWARD_SFX_IDS:
		assert_true(AudioDirector.has_sfx(id), "%s resolves to a stream" % id)
