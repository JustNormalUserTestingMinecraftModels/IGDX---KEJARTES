@tool
extends McpTestSuiteCompat

## The stat-detail modal, now a scene rather than 168 lines of construction
## duplicated between ReportCard.gd and StudentCard.gd.
##
## These tests instantiate the scene (cheap -- it is a dozen nodes) and check
## the node contract the two callers rely on, plus the source-level guarantee
## that neither caller rebuilt its own copy.
##
## Must be @tool; no test here may be a coroutine, so nothing calls open().

func suite_name() -> String:
	return "stat_detail_popup"


const SCENE_PATH := "res://Scenes/UI/StatDetailPopup.tscn"

## A student dictionary shaped like GameState.approved_students entries.
const SAMPLE := {
	"mood": 61.0, "energy": 42.0,
	"akademis": 10.0, "seni_budaya": 20.0, "olahraga": 30.0,
}


## The scene is added to the tree so its @onready vars resolve, matching
## the established pattern in tests/test_day_summary.gd. StatDetailPopup is
## a CanvasLayer (no .theme property of its own); none of the assertions
## here depend on resolved visual styling, so the theme fallback is not
## needed the way the Control-rooted row scenes need it.
func _make() -> StatDetailPopup:
	var scene: PackedScene = load(SCENE_PATH)
	var popup: StatDetailPopup = scene.instantiate()
	Engine.get_main_loop().root.add_child(popup)
	track(popup)
	return popup


func test_scene_exists_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	assert_not_null(_make())


func test_scene_supplies_every_node_the_script_binds() -> void:
	# The whole point of the extraction: these nodes live in the .tscn where a
	# human can select them, not in an _ready() that builds them.
	var popup := _make()
	for path in ["Scrim", "Scrim/Safe/Center/Frame", "Scrim/Safe/Center/Frame/Layout/Header",
			"Scrim/Safe/Center/Frame/Layout/Header/Row/IconRect",
			"Scrim/Safe/Center/Frame/Layout/Header/Row/Titles/CategoryLabel",
			"Scrim/Safe/Center/Frame/Layout/Header/Row/Titles/NameLabel",
			"Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/ValueLabel",
			"Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/Bar",
			"Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/DescriptionLabel"]:
		assert_not_null(popup.get_node_or_null(path), "missing node: %s" % path)


func test_configure_fills_the_header_and_body_from_stat_info() -> void:
	var popup := _make()
	popup.configure("SeniBudaya", SAMPLE, null)
	assert_eq(popup.get_node("Scrim/Safe/Center/Frame/Layout/Header/Row/Titles/CategoryLabel").text, "STATS")
	assert_eq(popup.get_node("Scrim/Safe/Center/Frame/Layout/Header/Row/Titles/NameLabel").text, "Seni Budaya")
	assert_contains(
		popup.get_node("Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/ValueLabel").text, "20")
	assert_contains(
		popup.get_node("Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/DescriptionLabel").text, "kesenian")


func test_configure_tints_the_bar_with_the_right_category() -> void:
	# configure() must tint through StatInfo.token_category, never the bar
	# name: Mood's token is Istirahat, so a bar-name tint shows up here.
	# Getting this wrong paints the bar the wrong colour and is invisible in a
	# source diff.
	var popup := _make()
	popup.configure("Mood", SAMPLE, null)
	var bar: StatBar = popup.get_node("Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/Bar")
	assert_eq(bar.category, "Istirahat")
	assert_eq(bar.value, 61.0)
	var seni := _make()
	seni.configure("SeniBudaya", SAMPLE, null)
	var seni_bar: StatBar = seni.get_node("Scrim/Safe/Center/Frame/Layout/Body/BodyLayout/Bar")
	assert_eq(seni_bar.category, "SeniBudaya", "not the academic accent")
	assert_eq(seni_bar.value, 20.0)


func test_configure_falls_back_to_the_glyph_when_no_icon_texture() -> void:
	var popup := _make()
	popup.configure("Mood", SAMPLE, null)
	var icon_rect: TextureRect = popup.get_node("Scrim/Safe/Center/Frame/Layout/Header/Row/IconRect")
	var glyph: Label = popup.get_node("Scrim/Safe/Center/Frame/Layout/Header/Row/GlyphLabel")
	assert_false(icon_rect.visible, "icon rect should hide when there is no texture")
	assert_true(glyph.visible, "glyph label should show when there is no texture")
	assert_eq(glyph.text, "😊")


func test_configure_on_an_unknown_bar_does_not_crash() -> void:
	var popup := _make()
	popup.configure("Nonsense", SAMPLE, null)
	assert_eq(popup.get_node("Scrim/Safe/Center/Frame/Layout/Header/Row/Titles/NameLabel").text, "")


func test_scene_has_no_theme_overrides() -> void:
	# Project rule: styling comes from ThemeFactory variations, never from
	# theme_override_* on a node. theme_override_constants/* (layout-only
	# values like separation/margins) is the one accepted exception.
	var offenders: Array[String] = []
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for line in text.split("\n"):
		if line.begins_with("theme_override_") and not line.begins_with("theme_override_constants/"):
			offenders.append(line)
	assert_true(offenders.is_empty(), "theme overrides in the scene file:\n" + "\n".join(offenders))


func test_report_card_no_longer_builds_the_popup_itself() -> void:
	# Not checked here: "TraitPopupPanel" -- both this popup and the
	# still-unconverted trait popup (Task 7) used that same node name, so the
	# string legitimately survives in the file until Task 7 also lands.
	var src := FileAccess.get_file_as_string("res://Scripts/ReportCard/ReportCard.gd")
	assert_false(src.contains("StatBar.new("),
		"ReportCard.gd still builds the stat popup's bar by hand")
	assert_contains(src, "StatDetailPopup",
		"ReportCard.gd should instantiate the extracted scene")
	assert_false(src.contains("const BAR_CATEGORY"),
		"BAR_CATEGORY moved to StatInfo.token_category()")


func test_student_card_no_longer_builds_the_popup_itself() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/StudentCard.gd")
	assert_contains(src, "StatDetailPopup",
		"StudentCard.gd should instantiate the extracted scene")
	assert_false(src.contains("const BAR_CATEGORY"),
		"BAR_CATEGORY moved to StatInfo.token_category()")


func test_the_two_screens_share_one_popup_implementation() -> void:
	# The regression this whole task exists to prevent: the two screens each
	# carried a verbatim copy of the same 168-line builder, and they had
	# already drifted. Neither may build a StatBar for a popup again.
	for path in ["res://Scripts/ReportCard/ReportCard.gd",
			"res://Scripts/StudentCard/StudentCard.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("StatBar.new("),
			"%s builds a StatBar in code -- use StatDetailPopup" % path)


func test_the_card_is_the_notebook_dialog() -> void:
	var popup := (load(SCENE_PATH) as PackedScene).instantiate()
	track(popup)
	var frame := popup.get_node_or_null("Scrim/Safe/Center/Frame") as NotebookFrame
	assert_true(frame != null, "the popup's box is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "STATISTIK", "its sticker names the popup")
		assert_true(frame.show_close, "the frame's round close replaces the typed one")


func test_the_frame_close_closes() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/StatDetailPopup.gd")
	assert_contains(src, "card.close_pressed.connect(close)", "the frame's close runs close()")
	assert_false(src.contains("close_button"), "the old button is gone")
