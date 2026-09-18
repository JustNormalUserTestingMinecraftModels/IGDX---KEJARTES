@tool
extends McpTestSuiteCompat

## Debug overlay's "Prestasi" tab (achievements-polish plan, Task 6).
## DebugManager.gd is not @tool, so the in-editor runner cannot instantiate
## it live -- these are source scans, the same technique test_debug_manager.gd
## uses for the rest of the overlay. Suite is @tool and no test is a
## coroutine, per the runner constraints documented there.

const _SCRIPT_PATH := "res://Scripts/Debug/DebugManager.gd"


func suite_name() -> String:
	return "debug_achievements_tab"


func _source() -> String:
	var f := FileAccess.open(_SCRIPT_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Slices out one top-level function's body: everything after its `func`
## line up to the next line that starts at column 0. Copied from
## test_debug_manager.gd's helper of the same name.
func _function_body(src: String, fname: String) -> String:
	var out := ""
	var inside := false
	for line in src.split("\n"):
		if line.begins_with("func " + fname + "("):
			inside = true
			continue
		if inside:
			if line.length() > 0 and not (line.begins_with("\t") or line.begins_with(" ")):
				break
			out += line + "\n"
	return out


func test_prestasi_tab_is_registered() -> void:
	var src := _source()
	assert_true(src.contains("\"Prestasi\""),
		"the tab bar's tab_names list must include a Prestasi tab")
	assert_true(src.contains("panels[\"Prestasi\"]"),
		"the achievements panel must register itself under the Prestasi tab key")


func test_build_ui_wires_the_achievements_panel() -> void:
	var body := _function_body(_source(), "_build_ui")
	assert_true(body.contains("_build_achievements_panel(content_area)"),
		"_build_ui must build the achievements panel into the tabbed content area")


func test_global_controls_are_present() -> void:
	var body := _function_body(_source(), "_build_achievements_panel")
	assert_true(body.contains("Buka semua"), "must have a 'Buka semua' button")
	assert_true(body.contains("Reset semua"), "must have a 'Reset semua' button")
	assert_true(body.contains("Buka acak"), "must have a 'Buka acak' button")
	assert_true(body.contains("dibuka") and body.contains("belum diambil"),
		"must have a live readout label mentioning opened/unclaimed counts")


func test_global_controls_call_the_achievements_api() -> void:
	var src := _source()
	assert_true(_function_body(src, "_debug_unlock_all_achievements").contains("Achievements.debug_unlock(entry.id)"),
		"Buka semua must call Achievements.debug_unlock for every catalog entry")
	assert_true(_function_body(src, "_debug_reset_all_achievements").contains("Achievements.reset_all()"),
		"Reset semua must call Achievements.reset_all()")
	assert_true(_function_body(src, "_debug_unlock_random_achievement").contains("Achievements.debug_unlock(id)"),
		"Buka acak must call Achievements.debug_unlock on a chosen locked id")


func test_row_buttons_are_present_and_wired() -> void:
	var body := _function_body(_source(), "_build_achievements_panel")
	assert_true(body.contains("\"Buka\""), "each row must have a Buka button")
	assert_true(body.contains("\"Klaim\""), "each row must have a Klaim button")
	assert_true(body.contains("\"Kunci lagi\""), "each row must have a Kunci lagi button")
	assert_true(body.contains("Achievements.debug_unlock(entry.id)"),
		"the row's Buka button must call Achievements.debug_unlock")
	assert_true(body.contains("Achievements.claim(entry.id)"),
		"the row's Klaim button must call Achievements.claim")
	assert_true(body.contains("Achievements.relock(entry.id)"),
		"the row's Kunci lagi button must call Achievements.relock")


func test_refresh_keeps_row_state_and_buttons_live() -> void:
	var body := _function_body(_source(), "_refresh_achievements_panel")
	assert_true(body.contains("Achievements.state_of(id)"),
		"refresh must read each row's live state from Achievements")
	assert_true(body.contains("btn_claim.disabled = state != Achievements.STATE_UNLOCKED"),
		"Klaim must be disabled unless the row is unlocked")
	assert_true(body.contains("btn_relock.disabled = state == Achievements.STATE_LOCKED"),
		"Kunci lagi must be disabled when the row is already locked")


func test_state_changed_signal_is_connected_and_disconnected() -> void:
	var ready_body := _function_body(_source(), "_build_ui")
	assert_true(ready_body.contains("Achievements.state_changed.connect(_refresh_achievements_panel)"),
		"the tab must subscribe to Achievements.state_changed so it updates live")
	assert_true(ready_body.contains("is_connected(_refresh_achievements_panel)"),
		"the connect must be guarded with is_connected")

	var exit_body := _function_body(_source(), "_exit_tree")
	assert_true(exit_body.contains("Achievements.state_changed.disconnect(_refresh_achievements_panel)"),
		"the overlay must disconnect from Achievements.state_changed when freed")


func test_switching_to_the_tab_refreshes_it() -> void:
	var body := _function_body(_source(), "_refresh_ui_fields")
	assert_true(body.contains("_refresh_achievements_panel()"),
		"_refresh_ui_fields (called by _switch_tab) must also refresh the Prestasi tab")


func test_function_body_slicer_stops_at_the_next_function() -> void:
	var src := "func a():\n\tvar x = 1\nfunc b():\n\tvar y = 2\n"
	var body := _function_body(src, "a")
	assert_true(body.contains("var x = 1"), "slicer must capture the target body")
	assert_false(body.contains("var y = 2"), "slicer must stop at the next top-level func")
