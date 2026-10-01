@tool
extends McpTestSuite

## Regression tests for the 2026-09-30 navigation bug pass: taps landing
## while Transition is still busy, the inventory flush on quit, the Koperasi
## basket, the Achievements back press and the Kelas 8 retry locks.
##
## Transition.change_scene() drops every call made while a scene change runs,
## and the incoming scene takes taps during its own cover-out. Where a screen
## can be exercised without a real scene change, these tests hold
## Transition's `_busy` flag up, call the screen's handler and restore the
## flag before asserting, so a failure can never leave the editor's
## Transition stuck. A handler is never called with Transition idle: in the
## editor that would change the editor's own scene. The rest are source
## scans, the project's pattern for screens that cannot run in the editor.
##
## Must be @tool, and no test here may be a coroutine.

## The screen under the Lobby's gear and the menu's.
const SETTINGS_SCENE := "res://Scenes/UI/Settings.tscn"
## Its script, for source scans.
const SETTINGS_SCRIPT := "res://Scripts/UI/Settings.gd"
## The same script, for its static return_scene.
const SettingsScript := preload("res://Scripts/UI/Settings.gd")
## Where the Lobby's gear asks Settings to return.
const LOBBY_SCENE := "res://Scenes/Lobby/Lobby.tscn"
## Settings' default Back destination.
const MAIN_MENU_SCENE := "res://Scenes/MainMenu/MainMenu.tscn"
## The end-of-grade notice that could hard-lock.
const TES_NOTICE_SCRIPT := "res://Scripts/EndGame/TesNotice.gd"
## The autoload that owns the inventory save.
const GAME_STATE_SCRIPT := "res://Scripts/GameState.gd"
## The Koperasi shelf layer that adopts whatever Cart holds.
const KOPERASI_STAGE_SCRIPT := "res://Scripts/Koperasi/KoperasiStage.gd"
## The screen that hosts the achievement detail sheet and claim popup.
const ACHIEVEMENTS_SCREEN_SCRIPT := "res://Scripts/Achievements/AchievementsScreen.gd"
## The screen that owns grade progression and retries. Loaded at call time,
## not preloaded (test_run_result.gd's pattern): an editor still holding a
## copy without unlock_retry_picks then fails those tests alone, instead of
## failing this whole suite's compile.
const RUN_RESULT_SCRIPT := "res://Scripts/EndGame/RunResult.gd"
## Stand-in roster ids for the retry-lock tests.
const SAMPLE_GRADE7_IDS := [11, 12]
## The same roster plus its Kelas 8 addition.
const SAMPLE_GRADE8_IDS := [11, 12, 13]

## GameState's two lock lists as they stood before each test.
var _grade7_backup: Array = []
## See _grade7_backup.
var _grade8_backup: Array = []
## Settings.return_scene as it stood before each test.
var _return_scene_backup: String = ""


## The runner's name for this suite.
func suite_name() -> String:
	return "bugfix_nav"


## Snapshots the process-global state these tests touch.
func setup() -> void:
	_grade7_backup = GameState.grade7_student_ids.duplicate()
	_grade8_backup = GameState.grade8_student_ids.duplicate()
	_return_scene_backup = SettingsScript.return_scene


## Restores what setup() saved.
func teardown() -> void:
	GameState.grade7_student_ids = _grade7_backup
	GameState.grade8_student_ids = _grade8_backup
	SettingsScript.return_scene = _return_scene_backup


## The Transition autoload.
func _transition() -> Node:
	return Engine.get_main_loop().root.get_node("Transition")


## The source of the function `fn` in `src`, up to the next column-0 func.
func _body(src: String, fn: String) -> String:
	var start := src.find("\nfunc %s(" % fn)
	if start == -1:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


## A Settings screen opened as the Lobby's gear opens it: return_scene set to
## the Lobby first, then the scene entering the tree (which runs _ready).
func _open_settings_from_lobby() -> Control:
	SettingsScript.return_scene = LOBBY_SCENE
	var screen: Control = load(SETTINGS_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(screen)
	return screen


# -- Transition ---------------------------------------------------------------

func test_is_busy_reports_the_scene_change_guard() -> void:
	var t := _transition()
	var was: bool = t._busy
	t._busy = true
	var while_busy: bool = t.is_busy()
	t._busy = false
	var while_idle: bool = t.is_busy()
	t._busy = was
	assert_true(while_busy, "is_busy() is true while a change is running")
	assert_false(while_idle, "and false once it is done")


# -- Settings: findings 2 and 32 ----------------------------------------------

func test_settings_takes_its_destination_on_arrival() -> void:
	var screen := _open_settings_from_lobby()
	var destination: String = screen._destination
	var static_after: String = SettingsScript.return_scene
	screen.free()
	assert_eq(destination, LOBBY_SCENE, "the Lobby's gear still returns to the Lobby")
	assert_eq(static_after, MAIN_MENU_SCENE,
		"the static is reset on arrival, so a later menu visit cannot inherit the Lobby")


func test_a_back_dropped_mid_wipe_keeps_the_lobby() -> void:
	var screen := _open_settings_from_lobby()
	var t := _transition()
	var was: bool = t._busy
	t._busy = true
	screen._on_back_pressed()
	t._busy = was
	var destination: String = screen._destination
	screen.free()
	assert_eq(destination, LOBBY_SCENE,
		"a Back Transition drops must leave the next Back still going to the Lobby")


func test_settings_back_waits_for_transition_before_leaving() -> void:
	var body := _body(FileAccess.get_file_as_string(SETTINGS_SCRIPT), "_on_back_pressed")
	var guard := body.find("Transition.is_busy()")
	var leave := body.find("Transition.change_scene(_destination")
	assert_true(guard != -1 and leave != -1 and guard < leave,
		"Back checks Transition before leaving, and leaves for the copied destination")
	assert_false(body.contains("return_scene ="), "Back never rewrites the static")


# -- TesNotice: findings 17 and 30 --------------------------------------------

func test_a_lanjut_tap_during_the_arrival_wipe_does_not_latch() -> void:
	var notice: Control = load(TES_NOTICE_SCRIPT).new()
	var t := _transition()
	var was: bool = t._busy
	t._busy = true
	notice._advance()
	t._busy = was
	var latched: bool = notice._advancing
	notice.free()
	assert_false(latched,
		"a dropped change must not latch _advancing, or the notice never leaves")


func test_tes_notice_checks_transition_before_latching() -> void:
	var body := _body(FileAccess.get_file_as_string(TES_NOTICE_SCRIPT), "_advance")
	var guard := body.find("Transition.is_busy()")
	var latch := body.find("_advancing = true")
	assert_true(guard != -1 and latch != -1 and guard < latch,
		"the busy check comes before the one-shot latch")


# -- GameState: finding 18 ----------------------------------------------------

func test_inventory_is_flushed_on_close_and_background() -> void:
	var body := _body(FileAccess.get_file_as_string(GAME_STATE_SCRIPT), "_notification")
	assert_contains(body, "NOTIFICATION_WM_CLOSE_REQUEST", "a window close flushes")
	assert_contains(body, "NOTIFICATION_APPLICATION_PAUSED", "going to the background flushes")
	assert_contains(body, "SaveGame.save_if_at_hub(", "through the run save, on a hub screen only")
	assert_false(body.contains("ConfigFile"), "the file format lives in SaveGame")


# -- Koperasi: finding 19 -----------------------------------------------------

func test_every_koperasi_visit_starts_with_an_empty_basket() -> void:
	var body := _body(FileAccess.get_file_as_string(KOPERASI_STAGE_SCRIPT), "_ready")
	var clear := body.find("Cart.clear()")
	var shelf := body.find("setup_shelf()")
	assert_true(clear != -1 and shelf != -1 and clear < shelf,
		"the Stage empties Cart before it stocks the shelf from it")


# -- Achievements: finding 20 -------------------------------------------------

func test_one_back_closes_only_the_claim_popup() -> void:
	var src := FileAccess.get_file_as_string(ACHIEVEMENTS_SCREEN_SCRIPT)
	assert_contains(_body(src, "_notification"), "_close_claim_popup_only()",
		"the popup branch goes through the one-layer close")
	var helper := _body(src, "_close_claim_popup_only")
	var seen := helper.find("detail_sheet.visible")
	var close := helper.find("_open_claim_popup.close()")
	var reopen := helper.find("call_deferred(\"open_for\"")
	assert_true(seen != -1 and close != -1 and seen < close,
		"whether the sheet was open is read before anything closes")
	assert_true(reopen > close, "the sheet the same press closed is re-opened afterwards")


# -- RunResult: finding 33 ----------------------------------------------------

## RunResult's retry helper, run for `grade` through a dynamic call.
func _unlock_retry_picks(grade: int) -> void:
	(load(RUN_RESULT_SCRIPT) as GDScript).call("unlock_retry_picks", grade)


## RunResult's constant `const_name`, or null when it has none.
func _run_result_const(const_name: String) -> Variant:
	return (load(RUN_RESULT_SCRIPT) as GDScript).get_script_constant_map().get(const_name)


func test_a_kelas_8_retry_unlocks_its_own_pick_only() -> void:
	GameState.grade7_student_ids = SAMPLE_GRADE7_IDS.duplicate()
	GameState.grade8_student_ids = SAMPLE_GRADE8_IDS.duplicate()
	_unlock_retry_picks(_run_result_const("OWN_PICKS_LOCKED_GRADE"))
	assert_true(GameState.grade8_student_ids.is_empty(),
		"the Kelas 8 pick can be swapped on a Kelas 8 retry")
	assert_eq(GameState.grade7_student_ids, SAMPLE_GRADE7_IDS, "the Kelas 7 locks stay")


func test_a_kelas_9_retry_keeps_the_kelas_8_locks() -> void:
	GameState.grade8_student_ids = SAMPLE_GRADE8_IDS.duplicate()
	_unlock_retry_picks(_run_result_const("FINAL_GRADE"))
	assert_eq(GameState.grade8_student_ids, SAMPLE_GRADE8_IDS,
		"Kelas 8's picks stay locked through a Kelas 9 retry")


func test_the_retry_branch_unlocks_the_grade_picks() -> void:
	var body := _body(FileAccess.get_file_as_string(RUN_RESULT_SCRIPT), "_apply_progression")
	assert_contains(body, "unlock_retry_picks(GameState.current_grade)",
		"the grade 8/9 retry re-opens that grade's own pick")
