@tool
extends McpTestSuite

## EventDialogue (2026-09-14 event-dialogue spec): the catalog's 13 entries,
## the screen's two tap rules, its theme variations, and SchoolDay's wiring.

const _SCENE := "res://Scenes/SchoolSimulation/EventDialogue.tscn"
const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _EVENT_KEYS := ["les_akademis", "latihan_olahraga", "workshop_seni", "nasi_kotak", "hujan"]
const _CHOICE_KEYS := ["les_akademis", "latihan_olahraga", "workshop_seni"]
const _MINIGAME_SCENES := [
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn",
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
	"res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Olahraga/MainBola.tscn",
	"res://Scenes/Minigames/Olahraga/Badminton.tscn",
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn",
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
]
const _THEA_SPLASH := "res://Assets/Images/SplashArtMurid/splash_thea.png"


func suite_name() -> String:
	return "event_dialogue"


func _student(n: String, specialty: String, splash: String = "") -> StudentData:
	var s := StudentData.new()
	s.student_name = n
	s.specialty_category = specialty
	s.splash_path = splash
	return s


# ── catalog ──────────────────────────────────────────────────────────────────

func test_every_event_and_minigame_has_an_entry() -> void:
	for key in _EVENT_KEYS:
		assert_true(EventDialogueCatalog.has_entry(key), "no dialogue for " + key)
	for path in _MINIGAME_SCENES:
		var key: String = EventDialogueCatalog.minigame_key(path)
		assert_true(EventDialogueCatalog.has_entry(key), "no dialogue for " + key)
	assert_eq(EventDialogueCatalog.ENTRIES.size(), 13, "exactly the spec's 13 entries")


func test_minigame_keys_are_scene_file_names() -> void:
	assert_eq(EventDialogueCatalog.minigame_key("res://Scenes/Minigames/Akademis/Variabel.tscn"), "Variabel")
	assert_false(EventDialogueCatalog.has_entry("Variabel Matematika"), "not _scene_name()'s display text")


func test_only_the_three_pick_students_events_ask() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		var want: String = EventDialogueCatalog.MODE_CHOICE if key in _CHOICE_KEYS else EventDialogueCatalog.MODE_TAP
		assert_eq(EventDialogueCatalog.entry(key)["mode"], want, key + " mode")


func test_fixed_speakers_match_the_brief() -> void:
	assert_eq(EventDialogueCatalog.entry("nasi_kotak")["speaker"], EventDialogueCatalog.SPLASH_MOM)
	assert_eq(EventDialogueCatalog.entry("latihan_olahraga")["speaker"], EventDialogueCatalog.SPLASH_GURU_PENJAS)
	assert_eq(EventDialogueCatalog.entry("MainBola")["speaker"], EventDialogueCatalog.SPLASH_GURU_PENJAS)
	assert_eq(EventDialogueCatalog.entry("workshop_seni")["speaker"], EventDialogueCatalog.SPLASH_GURU_SENI)
	assert_eq(EventDialogueCatalog.entry("hujan")["speaker"], "", "rain has no speaker")


func test_students_speak_for_their_own_subject() -> void:
	var want := {
		"les_akademis": "Akademis", "Menjodohkan": "Akademis", "Variabel": "Akademis",
		"PilihanGanda": "Akademis", "Password": "Akademis", "Badminton": "Olahraga",
		"BuatBatik": "SeniBudaya", "LombaMenari": "SeniBudaya",
	}
	for key in want:
		var e: Dictionary = EventDialogueCatalog.entry(key)
		assert_eq(e["speaker"], EventDialogueCatalog.SPEAKER_STUDENT, key + " is voiced by a student")
		assert_eq(e["category"], want[key], key + " picks from its own subject")


func test_hujan_is_its_own_unblurred_background() -> void:
	var rain: Dictionary = EventDialogueCatalog.entry("hujan")
	assert_eq(rain["background"], EventDialogueCatalog.HUJAN_BACKGROUND)
	assert_false(rain["blur"], "the rain is the scene, so it stays sharp")
	for key in EventDialogueCatalog.ENTRIES:
		if key == "hujan":
			continue
		var e: Dictionary = EventDialogueCatalog.entry(key)
		assert_eq(e["background"], EventDialogueCatalog.DEFAULT_BACKGROUND, key + " sits on the school")
		assert_true(e["blur"], key + " blurs the school")


func test_every_art_path_loads() -> void:
	for p in [EventDialogueCatalog.DEFAULT_BACKGROUND, EventDialogueCatalog.HUJAN_BACKGROUND,
			EventDialogueCatalog.SPLASH_MOM, EventDialogueCatalog.SPLASH_GURU_PENJAS,
			EventDialogueCatalog.SPLASH_GURU_SENI, EventDialogueCatalog.CALENDAR_BADGE]:
		assert_true(ResourceLoader.exists(p), "missing art: " + p)
		assert_true(load(p) is Texture2D, p + " is not a texture")


func test_lines_are_written_and_emoji_free() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		var line: String = EventDialogueCatalog.entry(key)["line"]
		assert_true(line.length() > 20, key + " has a real line")
		var clean := true
		for i in line.length():
			if line.unicode_at(i) >= 0x2000:
				clean = false
		assert_true(clean, key + " line carries a symbol or emoji")


func test_featured_student_shares_the_subject() -> void:
	var roster := [_student("Marcel", "Akademis"), _student("Doni", "Olahraga"), _student("Andi", "SeniBudaya")]
	for i in 8:
		assert_eq(EventDialogueCatalog.pick_featured(roster, "Olahraga").student_name, "Doni")


func test_featured_student_falls_back_to_anyone() -> void:
	var roster := [_student("Marcel", "Akademis")]
	assert_eq(EventDialogueCatalog.pick_featured(roster, "SeniBudaya").student_name, "Marcel")
	assert_eq(EventDialogueCatalog.pick_featured(roster, "").student_name, "Marcel")


func test_an_empty_roster_features_nobody() -> void:
	assert_eq(EventDialogueCatalog.pick_featured([], "Akademis"), null)
	assert_eq(EventDialogueCatalog.fill_line("Halo {nama}!", null), "Halo murid-murid!")


func test_nama_becomes_the_featured_name() -> void:
	var thea := _student("Thea", "SeniBudaya")
	assert_eq(EventDialogueCatalog.fill_line("Kudengar {nama} dan teman-temannya", thea),
		"Kudengar Thea dan teman-temannya")


func test_student_speakers_wear_their_own_splash() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("BuatBatik"), thea), _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("nasi_kotak"), thea), EventDialogueCatalog.SPLASH_MOM)
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("hujan"), thea), "")
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("BuatBatik"), null), "")
