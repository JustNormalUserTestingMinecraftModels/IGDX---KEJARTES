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


## Android back walks the pages: Confirm steps back to Ask, Ask closes the
## popup and says so once (MainMenu re-arms the title on `dismissed`), and a
## closed popup ignores the press. open() only shows in the editor, so this
## leaves no coroutine behind.
func test_android_back_steps_back_then_closes() -> void:
	var p := _popup()
	var dismissals := [0]
	p.dismissed.connect(func() -> void: dismissals[0] += 1)
	p.open("Kelas 7 · Minggu 1/4")
	p.show_confirm(true)
	p.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true((p.get_node(_ASK) as Control).visible, "back on Confirm steps back to Ask")
	assert_false((p.get_node(_CONFIRM) as Control).visible)
	assert_true(p.visible, "and the popup stays open")
	assert_eq(dismissals[0], 0, "stepping back is not a dismissal")
	p.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(p.visible, "back on Ask closes it")
	assert_eq(dismissals[0], 1, "and says so once")
	p.close()
	p.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(dismissals[0], 1, "a closed popup ignores back")
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
	# reset_run() empties the inventory: merged before it, the legacy items
	# would be wiped the moment they arrived.
	var reset_at := fresh.find("GameState.reset_run()")
	assert_true(reset_at != -1 and reset_at < fresh.find("SaveGame.merge_legacy_inventory()"),
		"the legacy inventory merges after the wipe, not before")
	var cont: String = src.get_slice("func _continue_game()", 1).get_slice("\nfunc ", 0)
	assert_true(cont.contains("SaveGame.load_save()"), "Lanjutkan loads the save")
	assert_true(cont.contains("SaveGame.resume_scene(GameState.pending_week_resume, GameState.returned_from_student_card)"),
		"and lands where resume_scene says")
	var menu: Node = load("res://Scenes/MainMenu/MainMenu.tscn").instantiate()
	track(menu)
	assert_true(menu.get_node_or_null("ContinuePopup") is ContinuePopup,
		"MainMenu.tscn instances the popup")


## The title's tap latch: Android back on the Ask page must re-arm it, or the
## next tap hits `if _started` and the title is dead. And a tap that reaches
## _unhandled_input while the popup is open must never re-fire the title.
func test_the_title_re_arms_after_a_dismissal_and_ignores_taps_under_the_popup() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	assert_true(ready.contains("_continue_popup.dismissed.connect(func() -> void: _started = false)"),
		"a dismissal re-arms the title")
	var input: String = src.get_slice("func _unhandled_input(", 1).get_slice("\nfunc ", 0)
	assert_true(input.contains("or _continue_popup.visible:\n\t\treturn"),
		"no tap starts the game while the popup is open")


## A debug build bypasses the tutorials at launch (DebugManager's playtest
## defaults); a new game's reset_run() set them back, so one tap brought every
## tutorial back. The bypass is read before the wipe and put back after it.
func test_a_new_game_keeps_the_debug_tutorial_bypass() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	var fresh: String = src.get_slice("func _begin_new_game()", 1).get_slice("\nfunc ", 0)
	var read_at := fresh.find("var bypassed: bool = GameState.tutorials_bypassed")
	var reset_at := fresh.find("GameState.reset_run()")
	var kept_at := fresh.find("if bypassed:\n\t\tGameState.tutorials_bypassed = true\n"
		+ "\t\tGameState.lobby_tutorial_completed = true")
	assert_true(read_at != -1 and read_at < reset_at, "the bypass is read before the wipe")
	assert_true(kept_at > reset_at, "and both halves of it are put back after")


## The card pops in a frame after it is shown, once the CenterContainer has
## sized it: popped at once, its pivot came from the pre-layout size, and the
## first open of every launch zoomed in from below the screen.
func test_the_card_pops_in_after_layout() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/ContinuePopup.gd")
	var open: String = src.get_slice("func open(", 1).get_slice("\nfunc ", 0)
	var waited := open.find("await get_tree().process_frame")
	var popped := open.find("Juice.pop_in(_frame)")
	assert_true(waited != -1 and popped > waited, "pop_in waits a frame for the layout")
	assert_true(open.contains("if not visible"), "and skips a popup closed in that frame")
