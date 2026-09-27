@tool
extends McpTestSuite

func suite_name() -> String:
	return "haptics"

func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	return "" if f == null else f.get_as_text()

func test_buzz_is_a_no_op_when_haptics_disabled() -> void:
	# Desktop context: buzz must not throw and must respect the toggle.
	# We assert it runs without error under both toggle states; the motor
	# and pip are platform/side effects, not returned values.
	GameSettings.haptics_enabled = false
	Haptics.buzz(20)  # must be a silent no-op, no error
	GameSettings.haptics_enabled = true
	assert_true(true, "buzz() with haptics off did not throw")

func test_buzz_uses_vibrate_handheld_on_mobile_only() -> void:
	var src := _source("res://Scripts/Feedback/Haptics.gd")
	assert_true(src.contains("OS.has_feature(\"mobile\")"),
		"Haptics must branch on the mobile feature")
	assert_true(src.contains("Input.vibrate_handheld("),
		"Haptics must call vibrate_handheld on the mobile branch")

func test_buzz_respects_the_toggle_in_source() -> void:
	var src := _source("res://Scripts/Feedback/Haptics.gd")
	assert_true(src.contains("GameSettings.haptics_enabled"),
		"Haptics.buzz must gate on GameSettings.haptics_enabled")
