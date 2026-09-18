@tool
extends McpTestSuite

## Source/scene-text scans for the Achievements screen's Task 5 rewire (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, "Rewire
## achievements.tscn"). Complements tests/test_achievement_screen.gd's
## behavioural checks with scans of achievements.tscn and
## achievements_screen.gd text, since a full rewire this size is easiest to
## regress silently (wrong node path, wrong signal name) without a text
## anchor pinning it.

const SCREEN_SCENE := "res://Scenes/Achievements/achievements.tscn"
const SCREEN_SCRIPT := "res://Scripts/Achievements/achievements_screen.gd"


func suite_name() -> String:
	return "achievements_grid"


func _scene_src() -> String:
	return FileAccess.get_file_as_string(SCREEN_SCENE)


func _script_src() -> String:
	return FileAccess.get_file_as_string(SCREEN_SCRIPT)


func test_scene_has_grid_columns_two() -> void:
	var src := _scene_src()
	assert_true(src.contains('type="GridContainer"'), "%List is a GridContainer")
	assert_true(src.contains("columns = 2"))


func test_scene_has_status_pill_and_filter() -> void:
	var src := _scene_src()
	assert_true(src.contains('instance=ExtResource("6_pill")'), "header instances AchievementStatusPill")
	assert_true(src.contains('type="OptionButton"'))
	assert_true(src.contains('theme_type_variation = &"SecondaryButton"'))


func test_scene_filter_options_in_order() -> void:
	var src := _scene_src()
	var semua_idx := src.find('popup/item_0/text = "Semua"')
	var belum_dibuka_idx := src.find('popup/item_1/text = "Belum dibuka"')
	var sudah_dibuka_idx := src.find('popup/item_2/text = "Sudah dibuka"')
	var belum_diambil_idx := src.find('popup/item_3/text = "Belum diambil"')
	assert_true(semua_idx != -1 and belum_dibuka_idx != -1 and sudah_dibuka_idx != -1 \
		and belum_diambil_idx != -1, "all four filter labels present")
	assert_true(semua_idx < belum_dibuka_idx and belum_dibuka_idx < sudah_dibuka_idx \
		and sudah_dibuka_idx < belum_diambil_idx, "filter options are authored in order")


func test_scene_instances_detail_sheet_once() -> void:
	var src := _scene_src()
	var count := 0
	var search_from := 0
	while true:
		var idx := src.find('instance=ExtResource("7_sheet")', search_from)
		if idx == -1:
			break
		count += 1
		search_from = idx + 1
	assert_eq(count, 1, "AchievementDetailSheet is instanced exactly once, as an overlay")


func test_screen_script_wires_grid_and_sheet() -> void:
	var src := _script_src()
	assert_true(src.contains("tile.setup(entry)"), "one tile per catalog entry")
	assert_true(src.contains("tile.tile_pressed.connect(_on_tile_pressed)"))
	assert_true(src.contains("detail_sheet.open_for(id)"))
	assert_true(src.contains("_on_claim_requested"), "sheet's claim_requested routes to the existing claim flow")
	assert_true(src.contains("Achievements.claim(id)"))
	assert_true(src.contains("claim_popup_scene.instantiate()"), "claim flow still shows AchievementClaimPopup")
	assert_true(src.contains("_on_state_changed"))
	assert_true(src.contains("tile.refresh()"), "state_changed refreshes every tile")
	assert_true(src.contains("filter_button.item_selected.connect(_on_filter_selected)"))
	assert_true(src.contains("tile.matches_filter(index)"))
	assert_true(src.contains("status_pill.jump_requested.connect(_on_jump_requested)"))
	assert_true(src.contains("ensure_control_visible(tile)"))
	assert_true(src.contains("Juice.shake(tile"))


func test_screen_script_back_guard_does_not_leave_screen_while_sheet_open() -> void:
	var src := _script_src()
	var notif_idx := src.find("func _notification(")
	assert_true(notif_idx != -1)
	var body := src.substr(notif_idx)
	assert_true(body.contains("detail_sheet.visible"), "checks the sheet before acting on back")
	assert_true(body.contains("detail_sheet.close()"))
	# The sheet-open branch must return before reaching _on_back_pressed(),
	# so it does not also navigate to the Lobby.
	var sheet_branch_idx := body.find("if detail_sheet.visible:")
	var return_idx := body.find("return", sheet_branch_idx)
	var back_call_idx := body.find("_on_back_pressed()", sheet_branch_idx + 1)
	assert_true(sheet_branch_idx != -1 and return_idx != -1)
	assert_true(back_call_idx == -1 or return_idx < back_call_idx,
		"return happens before any later _on_back_pressed() call in this branch")


func test_old_achievement_row_is_gone() -> void:
	assert_false(FileAccess.file_exists("res://Scenes/Achievements/AchievementRow.tscn"))
	assert_false(FileAccess.file_exists("res://Scripts/Achievements/AchievementRow.gd"))
