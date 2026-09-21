@tool
extends McpTestSuite

## The Android hardware/gesture back button must do what the screen's own
## back button does.
##
## Godot delivers that press as NOTIFICATION_WM_GO_BACK_REQUEST, not as
## ui_cancel, so an _input handler never sees it. Six screens answered it
## before 2026-09-21; seven with a working on-screen back button did not,
## and because application/config/quit_on_go_back defaults to TRUE a back
## press on any of those quit the game outright -- taking the run with it,
## since roster, money, week and schedules are all session-scoped and none
## of them reach disk.
##
## Source scans, like test_audio_coverage: these screens cannot be
## instantiated headlessly, and the runner has no way to post a window
## notification. What this buys: every screen HAS a handler, and it routes
## to that screen's own back path rather than to a second path that will
## drift from it. What it does NOT buy: that the handler fires at the right
## moment on a real device. Only pressing it on a phone shows that.
##
## No test here is a coroutine.

func suite_name() -> String:
	return "device_back_button"


## Screen script -> the function its device back press must reach. The names
## differ between screens (atur_jadwal's is _on_back_button_pressed, not
## _on_back_pressed) -- this map was read off the source, not assumed.
const SCREENS := {
	"res://Scripts/AturJadwal/atur_jadwal.gd": "_on_back_button_pressed",
	"res://Scripts/Koperasi/shop_hub.gd": "_on_back_pressed",
	"res://Scripts/Koperasi/cosmetic_shop.gd": "_on_back_pressed",
	"res://Scripts/ReportCard/report_card.gd": "_on_back_pressed",
	"res://Scripts/UI/Settings.gd": "_on_back_pressed",
	"res://Scripts/SchoolSimulation/SchoolDay.gd": "_on_back_pressed",
	"res://Scripts/Pengaturan.gd": "_on_back_pressed",
	# Already handled before this pass; included so a future edit cannot
	# quietly drop one of them either.
	"res://Scripts/Koperasi/koprasi.gd": "_on_back_pressed",
	"res://Scripts/Inventory/inventory.gd": "_on_back_pressed",
	"res://Scripts/Achievements/achievements_screen.gd": "_on_back_pressed",
}


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


func test_every_screen_answers_the_go_back_notification() -> void:
	for path in SCREENS:
		assert_true(_source(path).contains("NOTIFICATION_WM_GO_BACK_REQUEST"),
			"%s must answer the device back button" % path)


## "Works the same as the return button" is the literal requirement: the
## notification must reach the same function the on-screen button calls, so
## the animation, the cue and the destination cannot drift apart.
func test_the_notification_routes_to_the_screens_own_back_handler() -> void:
	for path in SCREENS:
		var src := _source(path)
		var handler: String = SCREENS[path]
		var at := src.find("NOTIFICATION_WM_GO_BACK_REQUEST")
		assert_true(at >= 0, "%s must answer the back button" % path)
		if at < 0:
			continue
		# Within the notification block, not merely somewhere in the file --
		# the on-screen button calls the same handler, so a whole-file
		# search would pass on a screen with no wiring at all.
		var after := src.substr(at, 400)
		assert_true(after.contains(handler + "("),
			"%s's back notification must call %s()" % [path, handler])


## Each screen must define exactly one _notification. A second one silently
## replaces the first, so a screen that already had one (atur_jadwal's
## EXIT_TREE cleanup, report_card's FOCUS_IN refresh) needs a new branch
## rather than a new function.
func test_no_screen_declares_two_notification_functions() -> void:
	for path in SCREENS:
		var src := _source(path)
		var count := src.count("func _notification(")
		assert_eq(count, 1,
			"%s must declare exactly one _notification (found %d)" % [path, count])


## Without this, a screen that forgets a handler does not merely do nothing --
## it ends the run.
func test_the_game_no_longer_quits_on_a_back_press() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back", true),
		"quit_on_go_back must be false so a stray back press cannot end a run")


## Never an instant exit from a minigame: a mis-swipe must not forfeit a
## round, and BaseMinigame already owns a quit confirmation for exactly this.
func test_a_minigame_back_press_opens_the_pause_menu() -> void:
	var src := _source("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_true(src.contains("NOTIFICATION_WM_GO_BACK_REQUEST"),
		"a minigame must answer the back button")
	var at := src.find("NOTIFICATION_WM_GO_BACK_REQUEST")
	if at < 0:
		return
	var after := src.substr(at, 400)
	assert_true(after.contains("_on_pause_button_pressed("),
		"a minigame's back press must open the pause menu")
	assert_false(after.contains("change_scene("),
		"a minigame's back press must not leave outright")
