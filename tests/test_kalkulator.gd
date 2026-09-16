@tool
extends McpTestSuite

## Scan and live checks for the 2026-09-16 calculator skin on the two
## number-entry Akademis minigames. Mostly source-text and asset-existence
## checks in the style of tests/test_minigame_art.gd, plus two live
## instantiation tests -- KalkulatorKey.tscn and Kalkulator.tscn have no
## autoload dependencies, so they can be built in-process.
##
## Must be @tool or the runner reports the class abstract/broken, and no
## test here may be a coroutine -- the runner calls suite.call(name)
## without awaiting.
## See docs/superpowers/specs/2026-09-16-kalkulator-akademis-design.md.

func suite_name() -> String:
	return "kalkulator"

const KEY_SCENE := "res://Scenes/Minigames/Akademis/KalkulatorKey.tscn"
const KEY_SCRIPT := "res://Scripts/Minigames/Akademis/KalkulatorKey.gd"
const CAP_TEXTURE := "res://Assets/Images/UI/Kalkulator/kalkulator_button.png"


func test_key_cap_texture_imports_as_texture2d() -> void:
	assert_true(ResourceLoader.exists(CAP_TEXTURE), "missing art: " + CAP_TEXTURE)
	assert_true(load(CAP_TEXTURE) as Texture2D != null,
		CAP_TEXTURE + " did not import as a Texture2D")


func test_key_scene_wires_the_cap_texture() -> void:
	var src := FileAccess.get_file_as_string(KEY_SCENE)
	assert_true(src.contains(CAP_TEXTURE), "KalkulatorKey.tscn must draw the cap art")


## The brief asked for "darkened and squished", so the press must move both
## scale and modulate. A scale-only tween is the generic UIPolish press and
## would not read as a key going down onto its skirt.
func test_key_press_squishes_and_darkens() -> void:
	var src := FileAccess.get_file_as_string(KEY_SCRIPT)
	assert_true(src.contains("button_down"), "the key animates on button_down")
	assert_true(src.contains("\"scale\""), "the press tweens scale (the squish)")
	assert_true(src.contains("\"modulate\""), "the press tweens modulate (the darken)")
	assert_true(src.contains("NO_AUTO_JUICE"),
		"the key opts out of UIPolish so there is only one press animation")


## User amendment 2026-09-16: key digits use the heading font, in white.
## DisplayLabel is on test_theme_factory's DISPLAY_ROSTER, so it is Boohong.
func test_key_digit_is_the_heading_font_in_white() -> void:
	var src := FileAccess.get_file_as_string(KEY_SCENE)
	assert_true(src.contains("theme_type_variation = &\"DisplayLabel\""),
		"the digit uses the heading face")
	assert_true(src.contains("theme_override_colors/font_color = Color(1, 1, 1, 1)"),
		"the digit is white")


## Instances `path` into the live tree and registers it for the runner to
## free after the test. The suite is a RefCounted, so it has no add_child of
## its own. Returned untyped: the scene's script members (key_text,
## show_zero_key) are not visible to the analyzer through a Node type.
func _live(path: String):
	var node = (load(path) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(node)
	track(node)
	return node


func test_a_key_renders_its_digit_and_reports_it() -> void:
	var key = _live(KEY_SCENE)
	key.key_text = "7"
	var seen: Array[String] = []
	key.key_pressed.connect(func(t: String): seen.append(t))
	var digit := key.get_node("Visual/Digit") as Label
	assert_eq(digit.text, "7", "the key shows the digit it is configured with")
	key.emit_signal("pressed")
	assert_eq(seen, ["7"] as Array[String], "a press reports its own digit")
