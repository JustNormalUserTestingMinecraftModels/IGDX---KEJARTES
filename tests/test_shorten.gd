@tool
extends McpTestSuite

## Shorten (2026-09-14 shorten-dialog spec): the GameSettings switch, which
## dialogues it skips, SchoolDay's early return, the Lobby button and its panel.

const _GAME_SETTINGS := "res://Scripts/GameSettings.gd"
const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const _LOBBY_SCENE := "res://Scenes/Lobby/loby.tscn"
const _LOBBY_SCRIPT := "res://Scripts/Lobby/loby.gd"
const _PANEL_SCENE := "res://Scenes/Lobby/ShortenPanel.tscn"
const _PANEL_SCRIPT := "res://Scripts/Lobby/ShortenPanel.gd"
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


# ── the panel ────────────────────────────────────────────────────────────────

## Instantiated with the baked theme under the editor root, tracked for
## cleanup. Untyped: typed as Control, GDScript rejects the script members.
func _panel():
	var p = (load(_PANEL_SCENE) as PackedScene).instantiate()
	p.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func test_the_panel_offers_the_two_options_as_written() -> void:
	var p = _panel()
	assert_eq((p.get_node("Center/Card/Content/TitleLabel") as Label).text, "Shorten")
	assert_eq(p.skip_button.text, "Skip Dialog")
	assert_eq(p.keep_button.text, "Jangan Skip Dialog")
	assert_eq(p.skip_button.theme_type_variation, &"PrimaryButton", "an ordinary choice: one filled")
	assert_eq(p.keep_button.theme_type_variation, &"SecondaryButton", "and one quiet")


func test_skip_dialog_turns_shorten_on_and_closes() -> void:
	GameSettings.skip_event_dialogue = false
	var p = _panel()
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	p.skip_button.pressed.emit()
	assert_true(GameSettings.skip_event_dialogue, "Skip Dialog turns Shorten on")
	assert_true(closed[0], "and closes the panel")


func test_jangan_skip_dialog_turns_shorten_off_and_closes() -> void:
	GameSettings.skip_event_dialogue = true
	var p = _panel()
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	p.keep_button.pressed.emit()
	assert_false(GameSettings.skip_event_dialogue, "Jangan Skip Dialog turns Shorten off")
	assert_true(closed[0], "and closes the panel")


func test_the_status_line_follows_the_setting() -> void:
	GameSettings.skip_event_dialogue = true
	var p = _panel()
	assert_eq(p.status_label.text, "Sekarang: dialog minigame dilewati.")
	GameSettings.skip_event_dialogue = false
	p.refresh()
	assert_eq(p.status_label.text, "Sekarang: dialog minigame ditampilkan.")


func test_the_scrim_waits_for_the_open_then_closes_unchanged() -> void:
	GameSettings.skip_event_dialogue = true
	var p = _panel()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"popup-dismiss rule: the opening tap must not also close it")
	p.open()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_STOP, "after the open, the dim closes")
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	p._on_scrim_gui_input(tap)
	assert_true(closed[0], "tapping the dim closes the panel")
	assert_true(GameSettings.skip_event_dialogue, "without changing the setting")


func test_the_panel_is_authored_and_never_saves_from_the_editor() -> void:
	var src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_false(src.contains(".new("), "the panel is fully authored")
	assert_contains(src, "if not Engine.is_editor_hint():\n\t\tGameSettings.save_settings()",
		"tests must never write the real settings file")
	var scene := FileAccess.get_file_as_string(_PANEL_SCENE)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in ShortenPanel.tscn")


# ── the Lobby button ─────────────────────────────────────────────────────────

## The source block of one node, from its header to the next section.
func _node_block(src: String, node_name: String) -> String:
	var start := src.find('[node name="%s" ' % node_name)
	if start == -1:
		return ""
	var end := src.find("\n[", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


## Since the 2026-09-15 tall-phone pass the money row rides in
## Safe/UI/BottomBar, so the button is checked against its row-mates there
## rather than by screen offsets.
func test_the_shorten_button_sits_on_the_money_row() -> void:
	var lobby := (load(_LOBBY_SCENE) as PackedScene).instantiate() as Control
	track(lobby)
	var btn := lobby.get_node_or_null("%ShortenButton") as Button
	var login := lobby.get_node_or_null("%DailyLogin") as Control
	var chip := lobby.get_node_or_null("%DisplayUang") as Control
	assert_true(btn != null and login != null and chip != null,
		"ShortenButton, DailyLogin and DisplayUang must be unique names")
	if btn == null or login == null or chip == null:
		return
	assert_eq(btn.theme_type_variation, &"SecondaryButton")
	assert_eq(btn.text, "Shorten")
	assert_eq(btn.get_parent(), chip.get_parent(), "it rides in the same bar as the money chip")
	assert_eq(btn.offset_top, chip.offset_top, "on the money row")
	assert_eq(btn.offset_bottom, chip.offset_bottom, "on the money row")
	assert_true(btn.offset_left > login.offset_right and btn.offset_right < chip.offset_left,
		"between the daily-login icon (..%f) and the money chip (%f..), got %f..%f"
			% [login.offset_right, chip.offset_left, btn.offset_left, btn.offset_right])


## loby.gd's _create_blur_overlay() inserts the reward popup's blur at
## DailyReward's child index, so every node serialized before DailyReward --
## the Classroom and the whole Safe HUD, ShortenButton and DailyLogin
## included -- ends up under it. (Until the 2026-09-15 tall-phone pass the
## insertion point was DailyLogin's index, while the HUD nodes were direct
## children of the root; a 2026-09-14 review had found ShortenButton sharp
## and tappable over the open popup.)
func test_the_popups_draw_over_the_shorten_button() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCENE)
	var btn := src.find('[node name="ShortenButton" ')
	assert_true(btn != -1, "ShortenButton exists")
	assert_true(btn < src.find('[node name="DailyReward" '),
		"the reward popup's blur, inserted at DailyReward's index, must cover it")
	assert_true(btn < src.find('[node name="ColorRect" '), "the tutorial overlay covers it")
	assert_contains(FileAccess.get_file_as_string(_LOBBY_SCRIPT),
		"move_child(blur_overlay, daily_reward.get_index())",
		"if the blur's insertion point moves, re-check which HUD nodes it covers")


func test_the_shorten_button_opens_the_panel() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	assert_contains(src, 'const SHORTEN_PANEL_SCENE := preload("res://Scenes/Lobby/ShortenPanel.tscn")')
	var wire := src.find("shorten_button.pressed.connect(_on_shorten_pressed)")
	var gate := src.find("if GameState.lobby_tutorial_completed or GameState.minggu_ke > 1:")
	assert_true(wire != -1 and wire < gate, "wired once, before the tutorial split")
	var body := _body(src, "_on_shorten_pressed")
	assert_contains(body, "SHORTEN_PANEL_SCENE.instantiate()")
	assert_contains(body, "add_child(panel)")
	assert_contains(body, "panel.open()")
