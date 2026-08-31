@tool
extends McpTestSuite

## The countdown and the quit confirmation are shared by all eight minigames.
## Both used to be built node-by-node inside BaseMinigame, so neither could be
## opened, seen or restyled in the editor.
##
## Every @export BaseMinigame already had for them is preserved and forwarded
## through configure(), so an artist's Inspector workflow is unchanged.
##
## Must be @tool; no test here may be a coroutine, so nothing calls play().

func suite_name() -> String:
	return "minigame_overlays"


const COUNTDOWN_PATH := "res://Scenes/Minigames/UI/MinigameCountdown.tscn"
const QUIT_PATH := "res://Scenes/Minigames/UI/QuitConfirmDialog.tscn"


## Both overlays are CanvasLayers with no .theme property; nothing here
## depends on resolved visual styling, so unlike the Control-rooted row
## scenes elsewhere in this project, add_child + track is enough.
func _make(scene_path: String) -> Node:
	var node: Node = load(scene_path).instantiate()
	Engine.get_main_loop().root.add_child(node)
	track(node)
	return node


func test_both_overlays_exist_as_scenes() -> void:
	assert_true(ResourceLoader.exists(COUNTDOWN_PATH), "%s is missing" % COUNTDOWN_PATH)
	assert_true(ResourceLoader.exists(QUIT_PATH), "%s is missing" % QUIT_PATH)


func test_countdown_scene_carries_its_label() -> void:
	var node := _make(COUNTDOWN_PATH)
	var label := node.get_node_or_null("Center/CountLabel") as Label
	assert_not_null(label, "MinigameCountdown needs a Center/CountLabel node")


func test_quit_dialog_scene_carries_its_message_and_buttons() -> void:
	var node := _make(QUIT_PATH)
	for path in ["Backdrop", "Center/Card/Margin/Layout/MessageLabel",
			"Center/Card/Margin/Layout/Buttons/YesButton",
			"Center/Card/Margin/Layout/Buttons/NoButton"]:
		assert_not_null(node.get_node_or_null(path), "missing node: %s" % path)


func test_quit_dialog_configure_applies_the_exported_copy() -> void:
	var node := _make(QUIT_PATH)
	node.configure("Yakin?", "Iya", "Tidak", null, Color.BLACK, null,
		Color.WHITE, Color.RED, null, null, null, 46, Color.WHITE)
	assert_eq(node.get_node("Center/Card/Margin/Layout/MessageLabel").text, "Yakin?")
	assert_eq(node.get_node("Center/Card/Margin/Layout/Buttons/YesButton").text, "Iya")
	assert_eq(node.get_node("Center/Card/Margin/Layout/Buttons/NoButton").text, "Tidak")


func test_quit_dialog_emits_confirmed_and_cancelled() -> void:
	var node := _make(QUIT_PATH)
	assert_true(node.has_signal("confirmed"), "QuitConfirmDialog needs a confirmed signal")
	assert_true(node.has_signal("cancelled"), "QuitConfirmDialog needs a cancelled signal")


## The text of one top-level function's body, from its `func name(` line up
## to (but not including) the next top-level `func` line. Used to scope a
## scan to one function instead of the whole file, since other functions in
## this same file (e.g. the result overlay, extracted in a later task)
## legitimately still build nodes by hand.
func _function_body(src: String, func_signature_prefix: String) -> String:
	var start := src.find(func_signature_prefix)
	assert_gt(start, 0, "could not find function starting with: %s" % func_signature_prefix)
	var next_func := src.find("\nfunc ", start + 1)
	return src.substr(start, (next_func if next_func != -1 else src.length()) - start)


func test_base_minigame_no_longer_builds_either_overlay() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "MinigameCountdown", "BaseMinigame should instantiate the scene")
	assert_contains(src, "QuitConfirmDialog", "BaseMinigame should instantiate the scene")

	var countdown_body := _function_body(src, "func _play_countdown()")
	assert_false(countdown_body.contains(".new("),
		"_play_countdown still builds the overlay by hand")

	var quit_body := _function_body(src, "func _show_quit_confirmation()")
	assert_false(quit_body.contains(".new("),
		"_show_quit_confirmation still builds the dialog by hand")

	assert_false(src.contains("func _play_button_boing"),
		"_play_button_boing is dead now that QuitConfirmDialog owns its own copy")


func test_every_shipped_export_survived() -> void:
	# The refactor must not quietly drop an Inspector slot an artist uses.
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	for export_name in ["countdown_font", "countdown_font_size", "countdown_font_color",
			"countdown_outline_color", "countdown_outline_size",
			"countdown_steps_text", "quit_dialog_message_text",
			"quit_dialog_yes_button_text", "quit_dialog_no_button_text",
			"quit_dialog_bg_texture", "quit_dialog_bg_color",
			"quit_dialog_card_texture", "quit_dialog_card_color",
			"quit_dialog_card_border_color", "quit_dialog_yes_button_texture",
			"quit_dialog_no_button_texture", "quit_dialog_font",
			"quit_dialog_font_size", "quit_dialog_font_color"]:
		assert_contains(src, export_name, "export %s disappeared in the refactor" % export_name)
