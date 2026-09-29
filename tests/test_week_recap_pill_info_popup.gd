@tool
extends McpTestSuiteCompat

## WeekRecapPillInfoPopup: the explainer a player gets by tapping a
## headline pill on ResultCheckup's week recap banner. Structurally a
## smaller sibling of Scenes/UI/StatDetailPopup.tscn -- same scrim+card
## shell, same tap-anywhere-to-close, no bar/value line since a pill has
## no 0-100 value to visualize.
##
## Must be @tool; no test here may be a coroutine, so nothing calls
## open() or close() -- only configure() and the signal/node contract.

func suite_name() -> String:
	return "week_recap_pill_info_popup"


const SCENE_PATH := "res://Scenes/UI/WeekRecapPillInfoPopup.tscn"


func _make() -> WeekRecapPillInfoPopup:
	var scene: PackedScene = load(SCENE_PATH)
	var popup: WeekRecapPillInfoPopup = scene.instantiate()
	Engine.get_main_loop().root.add_child(popup)
	track(popup)
	return popup


func test_scene_exists_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	assert_not_null(_make())


func test_scene_supplies_every_node_the_script_binds() -> void:
	var popup := _make()
	for path in ["Scrim", "Scrim/Safe/Center/Frame", "Scrim/Safe/Center/Frame/Layout/Header",
			"Scrim/Safe/Center/Frame/Layout/Header/IconRect",
			"Scrim/Safe/Center/Frame/Layout/Header/TitleLabel",
			"Scrim/Safe/Center/Frame/Layout/BodyLabel"]:
		assert_not_null(popup.get_node_or_null(path), "missing node: %s" % path)


func test_configure_fills_every_label_and_icon() -> void:
	var popup := _make()
	var tex := PlaceholderTexture2D.new()
	popup.configure(tex, "Uang", "Total penghasilan Wirausaha yang terkumpul minggu ini.")
	assert_eq(popup.title_label.text, "Uang", "title is written")
	assert_eq(popup.body_label.text,
		"Total penghasilan Wirausaha yang terkumpul minggu ini.",
		"body is written")
	assert_eq(popup.icon_rect.texture, tex, "icon is written")


func test_scene_carries_no_theme_override() -> void:
	var src := FileAccess.get_file_as_string(SCENE_PATH)
	assert_false(src.contains("theme_override_styles"),
		"no stylebox override on the popup")


func test_script_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/UI/WeekRecapPillInfoPopup.gd")
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned")


func test_the_card_is_the_notebook_dialog() -> void:
	var popup := (load(SCENE_PATH) as PackedScene).instantiate()
	track(popup)
	var frame := popup.get_node_or_null("Scrim/Safe/Center/Frame") as NotebookFrame
	assert_true(frame != null, "the popup's box is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "INFO", "its sticker names the popup")
		assert_true(frame.show_close, "the frame's round close replaces the typed one")


func test_the_frame_close_closes() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/WeekRecapPillInfoPopup.gd")
	assert_contains(src, "card.close_pressed.connect(close)", "the frame's close runs close()")
	assert_false(src.contains("close_button"), "the old button is gone")
