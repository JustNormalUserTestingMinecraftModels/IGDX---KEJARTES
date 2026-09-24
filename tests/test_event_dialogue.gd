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


# ── the screen ───────────────────────────────────────────────────────────────

## Instantiated with the baked theme under the editor root, tracked for
## cleanup -- the same helper shape as test_school_day.gd's _instantiate().
## Untyped on purpose: typed as Control, GDScript rejects d.tap() and the
## other script members at compile time.
func _dialogue(key: String, featured: StudentData = null):
	var d = (load(_SCENE) as PackedScene).instantiate()
	d.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(d)
	track(d)
	d.open(EventDialogueCatalog.entry(key), featured, 2, 6, "Senin")
	return d


func test_a_tap_dialogue_takes_two_taps() -> void:
	var d = _dialogue("nasi_kotak")
	var got: Array = []
	d.closed.connect(func(accepted: bool): got.append(accepted))
	assert_true(d.line_label.visible_ratio < 1.0, "the line starts unrevealed")
	d.tap()
	assert_eq(got, [], "the first tap never closes")
	assert_eq(d.line_label.visible_ratio, 1.0, "the first tap finishes the line")
	assert_true(d.armed and d.hint.visible, "and shows the hint")
	d.tap()
	assert_eq(got, [true], "the second tap closes")


func test_a_finished_line_still_takes_two_taps() -> void:
	var d = _dialogue("hujan")
	var got: Array = []
	d.closed.connect(func(accepted: bool): got.append(accepted))
	d.line_label.visible_ratio = 1.0
	d.tap()
	assert_eq(got, [], "a first tap on a finished line only arms")
	d.tap()
	assert_eq(got, [true])


func test_a_tap_dialogue_has_no_buttons() -> void:
	var d = _dialogue("MainBola")
	d.tap()
	assert_false(d.choices.visible, "TAP entries never show Tolak / Terima")


func test_a_choice_dialogue_ignores_taps() -> void:
	var d = _dialogue("les_akademis")
	var got: Array = []
	d.closed.connect(func(accepted: bool): got.append(accepted))
	assert_false(d.choices.visible, "buttons wait for the line")
	d.tap()
	assert_true(d.choices.visible, "a tap finishes the line and shows the buttons")
	d.tap()
	d.tap()
	assert_eq(got, [], "taps never close a CHOICE dialogue")
	assert_false(d.hint.visible, "the tap hint is for TAP dialogues")


func test_terima_accepts_and_tolak_declines() -> void:
	var yes = _dialogue("workshop_seni")
	var got_yes: Array = []
	yes.closed.connect(func(accepted: bool): got_yes.append(accepted))
	yes.tap()
	yes.terima_button.pressed.emit()
	assert_eq(got_yes, [true])
	var no = _dialogue("latihan_olahraga")
	var got_no: Array = []
	no.closed.connect(func(accepted: bool): got_no.append(accepted))
	no.tap()
	no.tolak_button.pressed.emit()
	assert_eq(got_no, [false])


func test_open_dresses_the_screen() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	var d = _dialogue("BuatBatik", thea)
	assert_eq(d.splash.texture.resource_path, _THEA_SPLASH, "the student's own splash")
	assert_true(d.splash.visible and d.blur.visible)
	assert_eq(d.background.texture.resource_path, EventDialogueCatalog.DEFAULT_BACKGROUND)
	assert_eq(d.week_label.text, "2/6")
	assert_eq(d.day_label.text, "Senin")


func test_nama_reaches_the_screen() -> void:
	var d = _dialogue("nasi_kotak", _student("Thea", "SeniBudaya"))
	assert_true(d.line_label.text.contains("Kudengar Thea"), d.line_label.text)
	assert_eq(d.splash.texture.resource_path, EventDialogueCatalog.SPLASH_MOM)


func test_hujan_hides_the_splash_and_the_blur() -> void:
	var d = _dialogue("hujan", _student("Thea", "SeniBudaya", _THEA_SPLASH))
	assert_false(d.splash.visible, "rain has no speaker")
	assert_false(d.blur.visible, "and a sharp backdrop")
	assert_eq(d.background.texture.resource_path, EventDialogueCatalog.HUJAN_BACKGROUND)


func test_only_a_left_press_counts_as_a_tap() -> void:
	var d = _dialogue("nasi_kotak")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	assert_true(d.is_tap(press))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	assert_false(d.is_tap(release), "a release is not a tap")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_false(d.is_tap(right))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_false(d.is_tap(touch), "a touch also arrives as a click; counting both doubles every tap")


func test_the_scene_is_authored_and_themed() -> void:
	var d = _dialogue("nasi_kotak")
	var want := {
		"DialogueBox": &"EventDialoguePanel", "DialogueBox/Content/Line": &"EventDialogueText",
		"DialogueBox/Content/Hint": &"CaptionLabel",
		"DialogueBox/Content/Choices/TolakButton": &"SecondaryButton",
		"DialogueBox/Content/Choices/TerimaButton": &"PrimaryButton",
		"Header/DayBanner": &"DayBannerPanel", "Header/DayBanner/DayLabel": &"DayBannerLabel",
		"Header/Calendar/Text/MingguLabel": &"CalendarLabel", "Header/Calendar/Text/WeekLabel": &"DayBannerLabel",
	}
	for path in want:
		var n := d.get_node_or_null(path) as Control
		assert_true(n != null, "missing node " + path)
		if n != null:
			assert_eq(n.theme_type_variation, want[path], path)
	assert_eq(d.mouse_filter, Control.MOUSE_FILTER_STOP, "the root takes the taps")
	for path in ["Background", "Blur", "Splash", "Header", "DialogueBox", "DialogueBox/Content/Line"]:
		assert_eq((d.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			path + " must let taps through to the root")
	assert_eq((d.get_node("Blur") as ColorRect).material.resource_path,
		"res://Scenes/SchoolSimulation/event_dialogue_blur_material.tres")
	assert_eq((d.get_node("Header/Calendar") as TextureRect).texture.resource_path,
		EventDialogueCatalog.CALENDAR_BADGE)
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/EventDialogue.gd")
	assert_false(src.contains(".new("), "the screen is fully authored")
	var scene := FileAccess.get_file_as_string(_SCENE)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in EventDialogue.tscn")


# ── theme ────────────────────────────────────────────────────────────────────

const _VARIATIONS := {
	"EventDialoguePanel": &"PanelContainer", "EventDialogueText": &"RichTextLabel",
	"DayBannerPanel": &"PanelContainer", "DayBannerLabel": &"Label", "CalendarLabel": &"Label",
}


func test_the_bold_token_is_open_sans_bold() -> void:
	var t := DesignTokens.load_default()
	assert_true(t.font_body_bold != null, "font_body_bold is set")
	if t.font_body_bold != null:
		assert_eq(t.font_body_bold.resource_path, "res://Assets/Fonts/OpenSans-Bold.ttf")


func test_factory_builds_the_dialogue_variations() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	for v in _VARIATIONS:
		assert_eq(theme.get_type_variation_base(v), _VARIATIONS[v], v + " base type")
	assert_eq(theme.get_font("normal_font", "EventDialogueText"), t.font_body_bold)
	assert_eq(theme.get_color("default_color", "EventDialogueText"), t.text_primary)
	assert_eq(theme.get_font("font", "DayBannerLabel"), t.font_body_bold)
	assert_eq(theme.get_font("font", "CalendarLabel"), t.font_body_bold)
	var card := theme.get_stylebox("panel", "EventDialoguePanel") as StyleBoxFlat
	assert_true(card != null, "the card is a flat box")
	if card != null:
		assert_eq(card.bg_color, t.surface_card)
		assert_eq(card.corner_radius_top_left, ThemeFactory.EVENT_DIALOGUE_RADIUS)
	var pill := theme.get_stylebox("panel", "DayBannerPanel") as StyleBoxFlat
	assert_true(pill != null, "the banner is a flat box")
	if pill != null:
		assert_eq(pill.border_color, t.brand_primary_dark)
		assert_eq(pill.border_width_left, ThemeFactory.DAY_BANNER_OUTLINE)


func test_the_bake_declares_the_dialogue_variations() -> void:
	var baked := ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for v in _VARIATIONS:
		assert_true(baked.get_type_list().has(v), v + " must be in the baked theme -- rebake")


# ── SchoolDay wiring (source scans) ──────────────────────────────────────────

func _body(src: String, fn: String) -> String:
	var start := src.find("\nfunc %s(" % fn)
	if start == -1:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


func test_the_dialogue_scene_is_lazy_loaded() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_contains(src, "@export var event_dialogue_scene: PackedScene")
	assert_contains(src, 'load("res://Scenes/SchoolSimulation/EventDialogue.tscn")')


func test_minigames_hear_their_line_between_warning_and_play() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_roll_event")
	for pair in [["KEGIATAN AKADEMIS!", "Akademis"], ["KEGIATAN OLAHRAGA!", "Olahraga"], ["KEGIATAN SENI BUDAYA!", "SeniBudaya"]]:
		# The call's opening only: since 2026-09-24 it also passes the event's
		# category and mode.
		var warn := body.find('_show_event_warning("%s"' % pair[0])
		var talk := body.find("_show_event_dialogue(minigame_dialogue_key(scene))", warn)
		var play := body.find('_play_minigame(scene, "%s")' % pair[1], warn)
		assert_true(warn != -1 and talk > warn and play > talk,
			pair[1] + ": warning, then dialogue, then minigame")


func test_every_minigame_scene_school_day_loads_has_a_line() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	for path in _MINIGAME_SCENES:
		assert_true(src.contains(path), "SchoolDay no longer loads " + path)
		assert_true(EventDialogueCatalog.has_entry(EventDialogueCatalog.minigame_key(path)), path)


## Code review, 2026-09-14: _roll_event used to read scene.resource_path for
## the dialogue key before _play_minigame's null guard, so a minigame scene
## that failed to load crashed the day instead of being skipped.
func test_a_minigame_scene_that_failed_to_load_has_no_dialogue_key() -> void:
	var school_day = load(_SCHOOL_DAY)
	assert_eq(school_day.minigame_dialogue_key(null), "",
		"a null scene must reach _play_minigame's own guard, not crash on .resource_path")
	assert_eq(school_day.minigame_dialogue_key(load(_MINIGAME_SCENES[1])), "Variabel")


func test_global_events_speak_before_they_apply() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_run_event")
	for trio in [["Kejutan Nasi Kotak Orang Tua!", "nasi_kotak", "EVENT_NASI_KOTAK_ENERGI"],
			["Hujan Deras & Jalanan Licin!", "hujan", "EVENT_HUJAN_ENERGI"]]:
		var warn := body.find('_show_event_warning("%s"' % trio[0])
		var talk := body.find('_show_event_dialogue("%s")' % trio[1], warn)
		var apply := body.find(trio[2], warn)
		assert_true(warn != -1 and talk > warn and apply > talk, trio[1] + ": warning, dialogue, effect")


func test_pick_students_events_pass_their_key() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_run_event")
	for key in _CHOICE_KEYS:
		assert_contains(body, '"%s"' % key)


func test_tolak_returns_before_the_picker() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_handle_interactive_event")
	var warn := body.find("await _show_event_warning(title")
	var ask := body.find("_show_event_dialogue(dialogue_key)")
	var bail := body.find("return", ask)
	var picker := body.find("dialog_scene.instantiate()")
	assert_true(warn != -1 and ask > warn and bail > ask and picker > bail,
		"warning, dialogue, and a declined dialogue returns before the picker exists")


func test_the_event_list_exists_once() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_eq(src.count('"Les Tambahan Akademis"'), 1, "one copy of the event table")
	assert_contains(_body(src, "_trigger_random_event"), "_run_event(randi() % 5, day_name)")
	assert_contains(_body(src, "force_event"), "_run_event(event_id, day_name)")
