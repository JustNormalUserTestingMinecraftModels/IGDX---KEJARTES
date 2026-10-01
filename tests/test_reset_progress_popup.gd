@tool
extends McpTestSuite

## ResetProgressPopup (2026-10-01): Settings' "Reset Progres" confirm.
## Structure and wiring are checked on a bare instantiate(); what the confirm
## does is a source scan of Settings.gd, since a live confirm would wipe the
## run and change scene. No coroutine tests.

const _SCENE := "res://Scenes/UI/ResetProgressPopup.tscn"
const _CONFIRM := "Scrim/Safe/Center/Frame/Layout/Confirm"


func suite_name() -> String:
	return "reset_progress_popup"


func _popup() -> ResetProgressPopup:
	var p: ResetProgressPopup = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func test_the_popup_asks_exactly_what_was_agreed() -> void:
	var p := _popup()
	assert_eq((p.get_node("Scrim/Safe/Center/Frame") as NotebookFrame).title_text, "RESET PROGRES")
	assert_eq((p.get_node(_CONFIRM + "/Warning") as Label).text, "Apakah Anda yakin?")
	var body := p.get_node(_CONFIRM + "/Body") as Label
	assert_eq(body.text, "Semua progres akan dihapus dan tidak bisa dikembalikan.")
	assert_eq(body.theme_type_variation, &"CaptionLabel", "the consequence is a calm caption")
	Engine.get_main_loop().root.remove_child(p)


## Tomato is danger (owner's pick A): a full wipe is the most destructive
## action in the game. ContinuePopup's mint "Ya, mulai baru" is the exception,
## not the rule to copy.
func test_the_wipe_is_red_and_batal_is_neutral() -> void:
	var p := _popup()
	var confirm := p.get_node(_CONFIRM + "/Buttons/ConfirmButton") as Button
	var cancel := p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button
	assert_eq(confirm.text, "Ya, Reset")
	assert_eq(confirm.theme_type_variation, &"DangerButton")
	assert_eq(cancel.text, "Batal")
	assert_eq(cancel.theme_type_variation, &"SecondaryButton")
	Engine.get_main_loop().root.remove_child(p)


func test_it_starts_hidden_and_opens_and_closes() -> void:
	var p := _popup()
	assert_false(p.visible, "the popup starts hidden")
	p.open()
	assert_true(p.visible, "open() shows it")
	(p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button).pressed.emit()
	assert_false(p.visible, "Batal closes it")
	Engine.get_main_loop().root.remove_child(p)


func test_ya_reset_emits_and_batal_does_not() -> void:
	var p := _popup()
	var got := [0]
	p.reset_confirmed.connect(func() -> void: got[0] += 1)
	p.open()
	(p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button).pressed.emit()
	assert_eq(got[0], 0, "Batal never confirms")
	(p.get_node(_CONFIRM + "/Buttons/ConfirmButton") as Button).pressed.emit()
	assert_eq(got[0], 1, "Ya, Reset confirms once")
	Engine.get_main_loop().root.remove_child(p)


func test_the_display_face_lines_use_only_glyphs_it_has() -> void:
	var p := _popup()
	var display: Font = DesignTokens.load_default().font_display
	var lines := [(p.get_node(_CONFIRM + "/Warning") as Label).text,
		(p.get_node("Scrim/Safe/Center/Frame") as NotebookFrame).title_text]
	for text: String in lines:
		for i in text.length():
			assert_true(display.has_char(text.unicode_at(i)),
				"'%s' in '%s' is not in the display face" % [String.chr(text.unicode_at(i)), text])
	Engine.get_main_loop().root.remove_child(p)


## Same pop-in order as ContinuePopup: hidden, laid out, then popped about a
## centred pivot that follows every resize.
func test_the_card_pops_in_after_layout() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/ResetProgressPopup.gd")
	var open: String = src.get_slice("func open(", 1).get_slice("\nfunc ", 0)
	var hidden := open.find("_frame.modulate.a = 0.0")
	var waited := open.find("await get_tree().process_frame")
	assert_true(hidden != -1 and waited > hidden, "the card is hidden before the layout wait")
	assert_true(open.find("Juice.pop_in(_frame)") > waited, "pop_in waits for the layout")
	assert_true(open.contains("if not visible"), "and skips a popup closed meanwhile")
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	assert_true(ready.contains("_frame.resized.connect(_center_pivot)"),
		"_ready keeps the pivot centred through every resize")


## The confirm wipes everything through the one call that does it all, then
## fades (not the default wipe) to the splash at the spec's longer duration.
## Transition.is_busy() is checked before the wipe: a dropped change_scene
## after it would strand a wiped run on the Settings screen.
func test_settings_wipes_then_fades_to_the_splash() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	var body: String = src.get_slice("func _on_reset_confirmed()", 1).get_slice("\nfunc ", 0)
	var busy := body.find("if Transition.is_busy():")
	var wipe := body.find("GameState.forget_session()")
	var go := body.find("Transition.change_scene(SPLASH_SCENE, Transition.Style.FADE, RESET_FADE_SECONDS)")
	assert_true(busy != -1 and wipe > busy, "a busy Transition is checked before anything is wiped")
	assert_true(go > wipe, "the fade to the splash follows the wipe")
	assert_true(src.contains("const SPLASH_SCENE := \"res://Scenes/Splashscreen/Splashscreen.tscn\""),
		"the reset lands on the splash")
	assert_true(src.contains("const RESET_FADE_SECONDS := 1.3"), "on the spec's longer fade")
	assert_true(ResourceLoader.exists("res://Scenes/Splashscreen/Splashscreen.tscn"))
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	assert_true(ready.contains("_reset_popup.reset_confirmed.connect(_on_reset_confirmed)"),
		"the popup's confirm is wired ungated")
