@tool
extends McpTestSuite

## ContinuePopup (2026-10-01 save system): the title screen's "carry on or
## start over" dialog. Structure and wiring are checked on a bare
## instantiate(); the routing is a source scan of MainMenu (a live tap would
## change scene). No coroutine tests.

const _SCENE := "res://Scenes/MainMenu/ContinuePopup.tscn"
const _ASK := "Scrim/Safe/Center/Frame/Layout/Ask"
const _CONFIRM := "Scrim/Safe/Center/Frame/Layout/Confirm"


func suite_name() -> String:
	return "continue_popup"


func _popup() -> ContinuePopup:
	var p: ContinuePopup = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func test_the_ask_page_says_exactly_what_was_asked() -> void:
	var p := _popup()
	assert_eq((p.get_node(_ASK + "/Question") as Label).text, "Mau melanjutkan permainan sebelumnya?")
	var cont := p.get_node(_ASK + "/Buttons/ContinueButton") as Button
	var new_game := p.get_node(_ASK + "/Buttons/NewButton") as Button
	assert_eq(cont.text, "Ya, lanjutkan")
	assert_eq(cont.theme_type_variation, &"PrimaryButton", "continuing is the main (mint) action")
	assert_eq(new_game.text, "Permainan baru")
	assert_eq(new_game.theme_type_variation, &"SecondaryButton")
	assert_eq((p.get_node(_ASK + "/Summary") as Label).theme_type_variation, &"CaptionLabel",
		"the summary is in the body face, which carries the '·'")
	Engine.get_main_loop().root.remove_child(p)


func test_the_confirm_page_guards_the_wipe() -> void:
	var p := _popup()
	assert_false((p.get_node(_CONFIRM) as Control).visible, "the confirm page starts hidden")
	assert_eq((p.get_node(_CONFIRM + "/Warning") as Label).text, "Yakin? Progres lama akan hilang.")
	assert_eq((p.get_node(_CONFIRM + "/Buttons/ConfirmButton") as Button).text, "Ya, mulai baru")
	assert_eq((p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button).text, "Batal")
	Engine.get_main_loop().root.remove_child(p)


func test_permainan_baru_flips_to_confirm_and_batal_flips_back() -> void:
	var p := _popup()
	(p.get_node(_ASK + "/Buttons/NewButton") as Button).pressed.emit()
	assert_true((p.get_node(_CONFIRM) as Control).visible, "Permainan baru asks first")
	assert_false((p.get_node(_ASK) as Control).visible)
	(p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button).pressed.emit()
	assert_true((p.get_node(_ASK) as Control).visible, "Batal steps back")
	Engine.get_main_loop().root.remove_child(p)


func test_the_two_choices_emit_their_signals() -> void:
	var p := _popup()
	var got := []
	p.continue_chosen.connect(func(): got.append("continue"))
	p.new_game_chosen.connect(func(): got.append("new"))
	(p.get_node(_ASK + "/Buttons/ContinueButton") as Button).pressed.emit()
	(p.get_node(_CONFIRM + "/Buttons/ConfirmButton") as Button).pressed.emit()
	assert_eq(got, ["continue", "new"])
	Engine.get_main_loop().root.remove_child(p)


func test_the_display_face_lines_use_only_glyphs_it_has() -> void:
	var p := _popup()
	var display: Font = DesignTokens.load_default().font_display
	for path in [_ASK + "/Question", _CONFIRM + "/Warning"]:
		var text := (p.get_node(path) as Label).text
		for i in text.length():
			assert_true(display.has_char(text.unicode_at(i)),
				"'%s' in '%s' is not in the display face" % [String.chr(text.unicode_at(i)), text])
	Engine.get_main_loop().root.remove_child(p)


func test_main_menu_asks_only_when_a_save_exists() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	var start: String = src.get_slice("func _start_game()", 1).get_slice("\nfunc ", 0)
	assert_true(start.contains("SaveGame.has_save()"), "the tap checks for a save")
	assert_true(start.contains("_continue_popup.open("), "and opens the popup when there is one")
	assert_true(start.contains("_begin_new_game()"), "otherwise today's new-game path runs")
	var fresh: String = src.get_slice("func _begin_new_game()", 1).get_slice("\nfunc ", 0)
	for needle in ["GameState.reset_run()", "SaveGame.delete_save()", "SaveGame.merge_legacy_inventory()"]:
		assert_true(fresh.contains(needle), "a new game runs " + needle)
	var cont: String = src.get_slice("func _continue_game()", 1).get_slice("\nfunc ", 0)
	assert_true(cont.contains("SaveGame.load_save()"), "Lanjutkan loads the save")
	assert_true(cont.contains("SaveGame.resume_scene(GameState.pending_week_resume, GameState.returned_from_student_card)"),
		"and lands where resume_scene says")
	var menu: Node = load("res://Scenes/MainMenu/MainMenu.tscn").instantiate()
	track(menu)
	assert_true(menu.get_node_or_null("ContinuePopup") is ContinuePopup,
		"MainMenu.tscn instances the popup")
