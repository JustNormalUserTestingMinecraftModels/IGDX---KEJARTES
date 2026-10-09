@tool
extends McpTestSuite

## TutorialIdle (2026-10-07 tutorial overhaul, spec section 3e): the resting
## loops on the active step's cues and the one escalation nudge after
## idle_nudge_seconds of no input. Touch-first: it fires on a timer or a tap,
## never on pointer-enter. tick() is the clock _process drives, so the timing
## is testable here without a frame. Must be @tool; no test may be a coroutine.

const SCRIPT_PATH := "res://Scripts/UI/TutorialIdle.gd"


func suite_name() -> String:
	return "tutorial_idle"


func test_idle_defaults_and_touch_only() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("idle_nudge_seconds: float = 2.5"), "default 2.5s")
	assert_false(src.to_lower().contains("mouse_entered"), "no hover triggers (touch-first)")
	assert_true(src.contains("func reset(") and src.contains("func pause("),
		"reset() and pause() required")


func test_nudges_once_after_the_idle_time() -> void:
	var idle := _idle()
	var target := Control.new()
	idle.add_child(target)
	var counter := [0]
	idle.nudged.connect(func() -> void: counter[0] += 1)
	idle.start(target)
	idle.tick(idle.idle_nudge_seconds - 0.1)
	assert_eq(counter[0], 0, "no nudge before the idle time")
	idle.tick(0.2)
	assert_eq(counter[0], 1, "one nudge once it passes")
	idle.tick(10.0)
	assert_eq(counter[0], 1, "capped at one level: no endless escalation")


func test_a_tap_resets_and_a_pause_holds() -> void:
	var idle := _idle()
	var target := Control.new()
	idle.add_child(target)
	var counter := [0]
	idle.nudged.connect(func() -> void: counter[0] += 1)
	idle.start(target)
	idle.tick(idle.idle_nudge_seconds - 0.1)
	idle.reset()
	idle.tick(idle.idle_nudge_seconds - 0.1)
	assert_eq(counter[0], 0, "a tap restarts the countdown")
	idle.pause()
	idle.tick(10.0)
	assert_eq(counter[0], 0, "a pop-up, comic or beat holds the nudge")
	idle.resume()
	idle.tick(idle.idle_nudge_seconds + 0.1)
	assert_eq(counter[0], 1, "and the countdown starts over when it closes")


func _idle() -> TutorialIdle:
	var idle := TutorialIdle.new()
	Engine.get_main_loop().root.add_child(idle)
	track(idle)
	return idle
