@tool
extends McpTestSuite

## Shorten (2026-09-14 shorten-dialog spec): the GameSettings switch, which
## dialogues it skips and SchoolDay's early return. Since 2026-09-17 the switch
## is the "Lewati Dialog Minigame" toggle on the Settings screen, which the
## Lobby's Settings gear opens; the Shorten button and its panel are gone.

const _GAME_SETTINGS := "res://Scripts/GameSettings.gd"
const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const _LOBBY_SCENE := "res://Scenes/Lobby/Lobby.tscn"
const _LOBBY_SCRIPT := "res://Scripts/Lobby/Lobby.gd"
const _SETTINGS_SCENE := "res://Scenes/UI/Settings.tscn"
const _SETTINGS_SCRIPT := "res://Scripts/UI/Settings.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _MINIGAME_KEYS := ["Menjodohkan", "Variabel", "PilihanGanda", "Password",
	"MainBola", "Badminton", "BuatBatik", "LombaMenari"]

var _saved_skip: bool


func suite_name() -> String:
	return "shorten"


func setup() -> void:
	_saved_skip = GameSettings.skip_event_dialogue


func teardown() -> void:
	GameSettings.skip_event_dialogue = _saved_skip


## The body of `fn` in `src`, up to the next top-level func.
func _body(src: String, fn: String) -> String:
	var start := src.find("\nfunc %s(" % fn)
	if start == -1:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


# ── the setting ──────────────────────────────────────────────────────────────

func test_the_setting_starts_off() -> void:
	var fresh = load(_GAME_SETTINGS).new()
	assert_false(fresh.skip_event_dialogue, "dialogues show until the player asks to skip")
	fresh.free()


func test_the_setting_is_saved_and_loaded_beside_the_tutorial_switch() -> void:
	var src := FileAccess.get_file_as_string(_GAME_SETTINGS)
	assert_contains(src, 'config.set_value("pengaturan", "skip_dialog", skip_event_dialogue)')
	assert_contains(src, 'skip_event_dialogue = config.get_value("pengaturan", "skip_dialog", false)')


# ── what Shorten skips ───────────────────────────────────────────────────────

func test_shorten_skips_exactly_the_eight_minigames() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		assert_eq(EventDialogueCatalog.shorten_skips(key), key in _MINIGAME_KEYS, key)


func test_shorten_keeps_the_parent_the_rain_and_every_choice() -> void:
	for key in ["nasi_kotak", "hujan", "les_akademis", "latihan_olahraga", "workshop_seni"]:
		assert_false(EventDialogueCatalog.shorten_skips(key), key + " keeps its dialogue")
	assert_false(EventDialogueCatalog.shorten_skips("NoSuchKey"), "an unknown key is not skipped")


func test_school_day_skips_before_it_builds_anything() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_show_event_dialogue")
	var skip := body.find("if GameSettings.skip_event_dialogue and EventDialogueCatalog.shorten_skips(key):")
	var build := body.find("dialogue_scene.instantiate()")
	assert_true(skip != -1 and build > skip, "Shorten returns before the dialogue is instanced")
	assert_contains(body.substr(skip, 120), "return true", "a skipped dialogue lets the minigame carry on")


# ── the Settings toggle ──────────────────────────────────────────────────────

## Settings, themed from the bake and in the editor root, tracked for cleanup.
func _settings() -> Control:
	var s := (load(_SETTINGS_SCENE) as PackedScene).instantiate() as Control
	s.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(s)
	track(s)
	return s


func test_settings_has_the_skip_dialog_toggle() -> void:
	var s := _settings()
	var row := s.find_child("SkipDialogRow", true, false)
	assert_true(row != null, "Settings carries the skip-dialog row")
	if row == null:
		return
	var toggle := row.get_node_or_null("Toggle") as CheckButton
	assert_true(toggle != null, "Settings carries the skip-dialog toggle")
	var label := row.get_node_or_null("Label") as Label
	assert_true(label != null and label.text == "Lewati Dialog Minigame")


func test_the_toggle_reflects_and_writes_the_setting() -> void:
	GameSettings.skip_event_dialogue = true
	var s := _settings()
	var row := s.find_child("SkipDialogRow", true, false)
	var toggle := (row.get_node_or_null("Toggle") as CheckButton) if row != null else null
	assert_true(toggle != null, "Settings carries the skip-dialog toggle")
	if toggle == null:
		return
	assert_true(toggle.button_pressed, "it opens showing the current setting")
	toggle.button_pressed = false
	assert_false(GameSettings.skip_event_dialogue, "turning it off shows the minigame lines again")
	toggle.button_pressed = true
	assert_true(GameSettings.skip_event_dialogue, "turning it on skips them")


# ── the Lobby ────────────────────────────────────────────────────────────────

func test_the_shorten_button_and_panel_are_gone() -> void:
	var scene := FileAccess.get_file_as_string(_LOBBY_SCENE)
	assert_false(scene.contains('[node name="ShortenButton" '), "no Shorten button in the Lobby")
	var src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	assert_false(src.contains("SHORTEN_PANEL_SCENE"), "the Lobby no longer opens a Shorten panel")
	assert_false(FileAccess.file_exists("res://Scenes/Lobby/ShortenPanel.tscn"), "ShortenPanel is deleted")


## The gear left the money row for the scrapbook HUD's icon rail
## (2026-09-27 spec §3): second, under the daily-login icon.
func test_the_settings_gear_rides_in_the_icon_rail() -> void:
	var lobby := (load(_LOBBY_SCENE) as PackedScene).instantiate() as Control
	track(lobby)
	var btn := lobby.get_node_or_null("%SettingsButton") as TextureButton
	var login := lobby.get_node_or_null("%DailyLogin") as Control
	var rail := lobby.get_node_or_null("%IconRail") as Control
	assert_true(btn != null and login != null and rail != null,
		"SettingsButton, DailyLogin and IconRail must be unique names")
	if btn == null or login == null or rail == null:
		return
	assert_eq(btn.texture_normal.resource_path, "res://Assets/Images/UI/setting.png")
	assert_eq(btn.get_parent(), rail, "it rides in the icon rail")
	assert_eq(login.get_parent(), rail, "beside the daily-login icon")
	assert_eq(btn.get_index(), login.get_index() + 1, "right under the daily-login icon")


## The reward popup's blur is inserted at DailyReward's index, so the gear
## must be serialized before DailyReward to sit under it.
func test_the_popups_draw_over_the_settings_gear() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCENE)
	var btn := src.find('[node name="SettingsButton" ')
	assert_true(btn != -1, "SettingsButton exists")
	assert_true(btn < src.find('[node name="DailyReward" '),
		"the reward popup's blur, inserted at DailyReward's index, must cover it")
	assert_true(btn < src.find('[node name="ColorRect" '), "the tutorial overlay covers it")


func test_the_gear_opens_settings_and_comes_back_to_the_lobby() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	var wire := src.find("settings_button.pressed.connect(_on_settings_pressed)")
	var gate := src.find("if GameState.lobby_tutorial_completed or GameState.minggu_ke > 1:")
	assert_true(wire != -1 and wire < gate, "wired once, before the tutorial split")
	var body := _body(src, "_on_settings_pressed")
	assert_contains(body, "SettingsScript.return_scene = ")
	assert_contains(body, "res://Scenes/UI/Settings.tscn")
	var settings_src := FileAccess.get_file_as_string(_SETTINGS_SCRIPT)
	assert_contains(settings_src, "static var return_scene")
	assert_contains(_body(settings_src, "_on_back_pressed"), "return_scene")
