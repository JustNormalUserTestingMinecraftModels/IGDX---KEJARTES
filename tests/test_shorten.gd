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
