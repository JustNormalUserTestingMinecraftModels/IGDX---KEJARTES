@tool
extends McpTestSuite

## See tests/test_main_menu.gd for the established rationale behind the
## @tool marker on this suite and the _collect_overrides implementation
## below (the brief's original draft called
## get_theme_font_size_override_list()/get_theme_color_override_list()/
## get_theme_stylebox_override_list(), none of which exist on Godot 4.6's
## Control class -- fixed the same way test_main_menu.gd was).

func suite_name() -> String:
	return "settings"

const _MIXER_BUSES := ["Master", "BGM", "SFX"]

var _screen: Control
var _saved_bus_state: Array[Dictionary] = []

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const LayoutFrame := preload("res://tests/layout_frame.gd")
## Each section card: its heading, then its rows in order.
const _SECTIONS := {
	"AudioCard": ["SUARA", ["MasterRow", "BgmRow", "SfxRow"]],
	"GameplayCard": ["PERMAINAN", ["TutorialRow", "SkipDialogRow"]],
	"DisplayCard": ["TAMPILAN", ["HdGraphicsRow", "BatterySaverRow", "LookLayerRow", "AmbientRow", "ReduceMotionRow", "HapticsRow"]],
	"DataCard": ["DATA", ["ResetProgressButton"]],
}
## The KREDIT card under its heading, top to bottom: [node, variation, text].
## A "Gap" row is a plain spacer Control: GapN parts sections (_CREDIT_SECTION_GAP),
## GapPairN parts the music pairs (_CREDIT_PAIR_GAP).
## Spacer heights: the airy layout the owner picked on 2026-10-03.
const _CREDIT_SECTION_GAP := 24.0
const _CREDIT_PAIR_GAP := 12.0
## Between griseyo's handle and their list of tracks: the same entry, so tighter.
const _CREDIT_LIST_GAP := 8.0
const _CREDIT_ROWS := [
	["GameTitle", "CreditTitleLabel", "KEJARTES"],
	["Gap1", "", ""],
	["RoleProgrammer", "CreditRoleLabel", "PROGRAMMER & UI DESIGNER"],
	["NameEleazar", "CreditNameLabel", "Eleazar Evan Putra"],
	["NameHosea", "CreditNameLabel", "Hosea Juan Kurniawan"],
	["NamePanji", "CreditNameLabel", "I Made Panji Putra"],
	["Gap2", "", ""],
	["RoleIllustrator", "CreditRoleLabel", "CHARACTER DESIGN & ILLUSTRATOR"],
	["NameAbdullah", "CreditNameLabel", "Abdullah A'asiq Satria"],
	["Gap3", "", ""],
	["RoleBackground", "CreditRoleLabel", "BACKGROUND ARTIST & MULTIMEDIA"],
	["NameAlbertus", "CreditNameLabel", "Albertus Akmel Bintang Prasetya"],
	["Gap4", "", ""],
	["RoleMusic", "CreditRoleLabel", "MUSIC"],
	["ArtistFiikuri", "CreditNameLabel", "fiikuri"],
	["TrackFiikuri", "CreditMusicLabel", "\"Epic Nusantara\" \u00b7 Title Screen"],
	["GapPair1", "", ""],
	["ArtistSounova", "CreditNameLabel", "sounovamusic"],
	["TrackSounova", "CreditMusicLabel", "\"Nusantara Calling\" \u00b7 Win Results"],
	["GapPair2", "", ""],
	["ArtistExtenz", "CreditNameLabel", "extenz"],
	["TrackExtenz", "CreditMusicLabel", "Game Over Music \u00b7 Lose Results"],
	["GapPair4", "", ""],
	["ArtistJulius", "CreditNameLabel", "JuliusH"],
	["TrackJulius", "CreditMusicLabel", "Intro Theme \u00b7 Opening Cutscene"],
	["Gap5", "", ""],
	["RoleThanks", "CreditRoleLabel", "SPECIAL THANKS"],
	["NameYosua", "CreditNameLabel", "Yosua Coyo Wagito"],
	["YosuaHandle", "CreditDetailLabel", "griseyo on Spotify"],
	["GapPair3", "", ""],
	["YosuaMusic", "CreditMusicLabel", "for the music of\nLobby (3 songs) \u00b7 School Day\nAcademic Minigames (3 songs) \u00b7 Sports Minigames\nBatik Making \u00b7 Dance Contest"],
]
## Each switch row's words.
const _ROW_LABELS := {
	"TutorialRow": "Tutorial Minigame", "SkipDialogRow": "Lewati Dialog Minigame",
	"LookLayerRow": "Efek Visual", "AmbientRow": "Efek Suasana",
	"ReduceMotionRow": "Kurangi Gerakan", "HapticsRow": "Getaran (Haptic)",
	"HdGraphicsRow": "Grafis HD", "BatterySaverRow": "Hemat Baterai",
}
## Each switch row's GameSettings property.
const _ROW_SETTINGS := {
	"TutorialRow": "minigame_tutorial_enabled", "SkipDialogRow": "skip_event_dialogue",
	"LookLayerRow": "look_layer_enabled", "AmbientRow": "ambient_effects_enabled",
	"ReduceMotionRow": "reduce_motion", "HapticsRow": "haptics_enabled",
	"HdGraphicsRow": "hd_graphics_enabled", "BatterySaverRow": "battery_saver_enabled",
}
const _ROW_SCRIPT := "res://Scripts/UI/SettingsToggleRow.gd"


func setup() -> void:
	# test_moving_a_slider_changes_the_bus_volume drives AudioServer through
	# the real AudioDirector autoload, not a disposable instance -- the same
	# class of leak already fixed in test_audio_director.gd. Snapshot here,
	# restore in teardown, for the same reason: AudioServer buses are
	# process-global, and a leftover slider value gets written into the
	# committed Assets/Audio/default_bus_layout.tres.
	_saved_bus_state.clear()
	for bus in _MIXER_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			_saved_bus_state.append({
				"idx": idx,
				"db": AudioServer.get_bus_volume_db(idx),
				"mute": AudioServer.is_bus_mute(idx),
			})

	var scene: PackedScene = load("res://Scenes/UI/Settings.tscn")
	_screen = scene.instantiate()
	_screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null

	for state in _saved_bus_state:
		AudioServer.set_bus_volume_db(state["idx"], state["db"])
		AudioServer.set_bus_mute(state["idx"], state["mute"])
	_saved_bus_state.clear()


## The switch inside the SettingsToggleRow named `row_name`, or null.
func _toggle(row_name: String) -> CheckButton:
	var row := _screen.find_child(row_name, true, false)
	return (row.get_node_or_null("Toggle") as CheckButton) if row != null else null


func test_scene_loads() -> void:
	assert_true(_screen != null, "Settings.tscn must exist and instantiate")


func test_has_a_slider_for_each_audio_bus() -> void:
	for name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(name, true, false)
		assert_true(s != null, "missing slider: " + name)
		assert_true(s is Slider, name + " must be a Slider")


func test_moving_a_slider_changes_the_bus_volume() -> void:
	# No frame-wait needed: Range.value's setter emits value_changed
	# synchronously when the value actually changes, and the MCP test
	# runner's suite.call() doesn't await coroutine test methods anyway
	# (an `await` here would silently truncate the test to 0 assertions).
	var slider := _screen.find_child("SfxSlider", true, false) as Slider
	slider.value = 0.3
	assert_true(absf((AudioDirector.get_bus_volume(&"SFX")) - (0.3)) <= 0.02, "the slider must drive the bus")


func test_the_frame_close_is_the_way_back() -> void:
	var frame := _screen.get_node("SafeArea/Frame") as NotebookFrame
	assert_true(frame.show_close, "the round close is the way back")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd"),
		"_frame.close_pressed.connect(_on_back_pressed)")


func test_the_tabs_are_suara_main_and_kredit() -> void:
	var frame := _screen.get_node("SafeArea/Frame") as NotebookFrame
	assert_eq(Array(frame.tabs), ["SUARA", "MAIN", "CREDITS"])
	assert_eq(frame.title_text, "PENGATURAN")


func test_each_tab_shows_its_sections() -> void:
	_screen.show_tab(0)
	assert_true(_screen.get_node("%AudioCard").visible, "SUARA shows the sliders")
	assert_false(_screen.get_node("%GameplayCard").visible)
	assert_false(_screen.get_node("%DisplayCard").visible)
	_screen.show_tab(1)
	assert_false(_screen.get_node("%AudioCard").visible)
	assert_true(_screen.get_node("%GameplayCard").visible, "MAIN shows the switches")
	assert_true(_screen.get_node("%DisplayCard").visible)
	assert_true(_screen.get_node("%DataCard").visible, "MAIN shows Reset Progres too")
	_screen.show_tab(0)
	assert_false(_screen.get_node("%DataCard").visible, "SUARA hides it")
	assert_false(_screen.get_node("%CreditsCard").visible, "SUARA hides the credits")
	_screen.show_tab(2)
	assert_true(_screen.get_node("%CreditsCard").visible, "KREDIT shows the credits")
	assert_false(_screen.get_node("%AudioCard").visible)
	assert_false(_screen.get_node("%GameplayCard").visible)
	_screen.show_tab(0)


## show_tab keeps the frame's own active_tab export in step, so the tab strip's
## gold highlight follows a programmatic switch, not only a press. The frame's
## active_tab setter only refreshes the strip's look and never emits
## tab_selected, so this cannot loop back through the connection in _ready.
func test_show_tab_keeps_the_frame_active_tab_in_step() -> void:
	var frame := _screen.get_node("SafeArea/Frame") as NotebookFrame
	_screen.show_tab(1)
	assert_eq(frame.active_tab, 1, "show_tab(1) moves the frame's active_tab too")
	_screen.show_tab(0)
	assert_eq(frame.active_tab, 0)


## _ready() must not bake a hidden card into the scene when the editor is
## saving the edited Settings.tscn itself: is_part_of_edited_scene() is false
## for a plain runtime/test instance, so it still runs show_tab here.
func test_ready_skips_show_tab_only_for_the_edited_scene() -> void:
	assert_contains(FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd"),
		"Engine.is_editor_hint() and is_part_of_edited_scene()",
		"_ready guards show_tab so saving the edited scene never bakes a hidden card")
	assert_true(_screen.get_node("%GameplayCard").visible or _screen.get_node("%AudioCard").visible,
		"a plain instance (not the edited scene) still runs show_tab on ready")


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_labels_are_indonesian() -> void:
	var frame := _screen.get_node("SafeArea/Frame") as NotebookFrame
	assert_eq(frame.title_text, "PENGATURAN", "title must be Indonesian")


func test_bgm_slider_gives_audible_feedback() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	assert_true(src.contains('&"BGM"') and src.contains('play_sfx(&"pop")'),
		"dragging the Musik slider must preview a sound, like the SFX slider does")


func test_haptics_and_reduce_motion_persist() -> void:
	GameSettings.haptics_enabled = false
	GameSettings.reduce_motion = true
	GameSettings.save_settings()
	GameSettings.haptics_enabled = true
	GameSettings.reduce_motion = false
	GameSettings.load_settings()
	assert_false(GameSettings.haptics_enabled, "haptics_enabled round-trips through save/load")
	assert_true(GameSettings.reduce_motion, "reduce_motion round-trips through save/load")
	# restore defaults so other tests are unaffected
	GameSettings.haptics_enabled = true
	GameSettings.reduce_motion = false
	GameSettings.save_settings()


func test_settings_screen_exposes_haptics_and_motion() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	assert_true(src.contains("GameSettings.haptics_enabled ="),
		"Settings must write haptics_enabled from its toggle")
	assert_true(src.contains("GameSettings.reduce_motion ="),
		"Settings must write reduce_motion from its toggle")

## Efek Suasana (ambient kit, 2026-09-26) is on until the player says
## otherwise: a fresh GameSettings, before any load, holds true.
func test_ambient_effects_default_on() -> void:
	var fresh: Node = (load("res://Scripts/GameSettings.gd") as GDScript).new()
	assert_true(fresh.get("ambient_effects_enabled"), "Efek Suasana defaults to on")
	fresh.free()


## Grafis HD (2026-09-30 mobile performance pass) is on until the player
## turns it off: a fresh GameSettings, before any load, holds true, so nobody
## loses the antialiasing or the bloom without asking.
func test_hd_graphics_default_on() -> void:
	var fresh: Node = (load("res://Scripts/GameSettings.gd") as GDScript).new()
	assert_true(fresh.get("hd_graphics_enabled"), "Grafis HD defaults to on")
	fresh.free()


func test_hd_graphics_persist_and_announce() -> void:
	var heard: Array = []
	var on_hd := func(enabled: bool) -> void: heard.append(enabled)
	GameSettings.hd_graphics_changed.connect(on_hd)
	GameSettings.hd_graphics_enabled = false
	GameSettings.hd_graphics_enabled = false
	GameSettings.save_settings()
	GameSettings.hd_graphics_changed.disconnect(on_hd)
	GameSettings.hd_graphics_enabled = true
	GameSettings.load_settings()
	assert_false(GameSettings.hd_graphics_enabled, "hd_graphics_enabled round-trips through save/load")
	assert_eq(heard, [false], "one emit per real flip, none for a repeat")
	GameSettings.hd_graphics_enabled = true
	GameSettings.save_settings()


func test_ambient_effects_persist() -> void:
	GameSettings.ambient_effects_enabled = false
	GameSettings.save_settings()
	GameSettings.ambient_effects_enabled = true
	GameSettings.load_settings()
	assert_false(GameSettings.ambient_effects_enabled,
		"ambient_effects_enabled round-trips through save/load")
	GameSettings.ambient_effects_enabled = true
	GameSettings.save_settings()


## The kit follows both switches by signal. Each flip emits once, and setting
## the value it already holds emits nothing.
func test_the_kit_switches_announce_their_flips() -> void:
	var heard: Array = []
	var on_ambient := func(_enabled: bool) -> void: heard.append("ambient")
	var on_motion := func(_still: bool) -> void: heard.append("motion")
	GameSettings.ambient_effects_changed.connect(on_ambient)
	GameSettings.reduce_motion_changed.connect(on_motion)
	GameSettings.ambient_effects_enabled = false
	GameSettings.ambient_effects_enabled = false
	GameSettings.reduce_motion = true
	GameSettings.ambient_effects_changed.disconnect(on_ambient)
	GameSettings.reduce_motion_changed.disconnect(on_motion)
	GameSettings.ambient_effects_enabled = true
	GameSettings.reduce_motion = false
	assert_eq(heard, ["ambient", "motion"], "one emit per real flip, none for a repeat")


func test_backdrop_is_the_blurred_lobby() -> void:
	var bg := _screen.get_node_or_null("Background") as TextureRect
	assert_true(bg != null and bg.texture != null, "Settings needs its Background")
	if bg == null or bg.texture == null:
		return
	assert_eq(bg.texture.resource_path, "res://Assets/Images/UI/blur_background.png",
		"Settings sits on the blurred Lobby, like its siblings")


## The title now lives on the frame's stitched sticker, not a separate card.
func test_header_is_a_title_card() -> void:
	var frame := _screen.get_node_or_null("SafeArea/Frame") as NotebookFrame
	assert_true(frame != null, "Settings needs SafeArea/Frame")
	if frame == null:
		return
	assert_eq(frame.title_text, "PENGATURAN", "the sticker carries the title")
	assert_true(frame.get_node_or_null("Header") == null,
		"there is no separate header card any more")


## Kembali is gone: the frame's round close sits on its own top-right corner,
## authored once in NotebookFrame.tscn rather than per screen.
func test_back_button_sits_at_the_bottom() -> void:
	var frame := _screen.get_node_or_null("SafeArea/Frame") as NotebookFrame
	assert_true(frame != null, "Settings needs SafeArea/Frame")
	if frame == null:
		return
	assert_true(frame.show_close, "the close corner is shown")
	assert_true(_screen.find_child("BackButton", true, false) == null,
		"Kembali is gone; the frame's close is the only way back")


## The scroll is the frame's own host content -- its sole child, laid into
## the frame's content_rect() below the sticker and tabs.
func test_sections_scroll_under_the_header() -> void:
	var scroll := _screen.get_node_or_null("SafeArea/Frame/Scroll") as ScrollContainer
	assert_true(scroll != null, "Settings needs SafeArea/Frame/Scroll")
	if scroll == null:
		return
	assert_eq(scroll.size_flags_vertical, Control.SIZE_EXPAND_FILL, "the scroll takes the rest")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"it never scrolls sideways")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"it scrolls by drag with no unthemed scrollbar")
	assert_true(scroll.get_node_or_null("Pad/Sections") != null, "the cards sit in Pad/Sections")


## Four titled sections, in order, each a plain VBoxContainer -- the page
## and its well are the surface now, so the old Card chrome is gone -- each
## holding its rows in order with one SettingsDivider between neighbours.
func test_settings_are_grouped_into_four_titled_cards() -> void:
	var sections := _screen.find_child("Sections", true, false)
	assert_true(sections != null, "Settings needs its Sections column")
	if sections == null:
		return
	var names: Array = []
	for card in sections.get_children():
		names.append(String(card.name))
	# CreditsCard closes the column; test_credits_read_top_to_bottom owns it.
	assert_eq(names, _SECTIONS.keys() + ["CreditsCard"], "the sections, in order")
	for card_name in _SECTIONS:
		var vbox := sections.get_node_or_null("%s/Margin/VBox" % card_name)
		assert_true(vbox != null, card_name + " needs Margin/VBox")
		if vbox == null:
			continue
		var card := sections.get_node(card_name)
		assert_true(card is VBoxContainer, card_name + " is a plain VBoxContainer")
		assert_eq((card as Control).theme_type_variation, &"",
			card_name + " carries no Card chrome")
		var heading := vbox.get_child(0) as Label
		assert_true(heading != null and heading.theme_type_variation == &"CardSectionLabel",
			card_name + " opens with a CardSectionLabel")
		if heading != null:
			assert_eq(heading.text, _SECTIONS[card_name][0], card_name + " heading")
		var rows: Array = []
		for i in range(1, vbox.get_child_count()):
			var child := vbox.get_child(i)
			if child is HSeparator:
				assert_eq((child as HSeparator).theme_type_variation, &"SettingsDivider",
					card_name + " rules are SettingsDividers")
			else:
				rows.append(String(child.name))
		assert_eq(rows, _SECTIONS[card_name][1], card_name + " rows, in order")
		assert_eq(vbox.get_child_count(), 2 * rows.size(),
			card_name + ": heading, rows, and one rule between each pair")


func test_every_switch_row_is_the_template_labelled_in_indonesian() -> void:
	for row_name in _ROW_LABELS:
		var row := _screen.find_child(row_name, true, false)
		assert_true(row != null, "Settings needs " + row_name)
		if row == null:
			continue
		assert_eq((row.get_script() as Script).resource_path, _ROW_SCRIPT,
			row_name + " is a SettingsToggleRow")
		assert_eq((row.get_node("Label") as Label).text, _ROW_LABELS[row_name],
			row_name + " is labelled in Indonesian")
		var toggle := _toggle(row_name)
		assert_true(toggle != null, row_name + " needs its Toggle")
		if toggle == null:
			continue
		assert_eq(toggle.theme_type_variation, &"SettingsSwitch",
			row_name + " wears the brand switch")
		assert_eq(row.toggle, toggle, row_name + ".toggle is its switch")


func test_every_slider_wears_the_brand_slider() -> void:
	for slider_name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(slider_name, true, false) as HSlider
		assert_true(s != null and s.theme_type_variation == &"SettingsSlider",
			slider_name + " is a SettingsSlider")


## The entry stagger pops the frame in whole now: the title, tabs and
## sections are its own chrome and content, not staggered piece by piece.
func test_entry_stagger_runs_top_to_bottom() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	assert_true(src.contains("Juice.stagger_in(_collect_entry_nodes())"),
		"_ready staggers the entry nodes")
	var nodes: Array = _screen.call("_collect_entry_nodes")
	var names: Array = []
	for n in nodes:
		names.append(String((n as Node).name))
	assert_eq(names, ["Frame"], "the frame pops in whole")


## Every switch opens on its setting and writes it back. It is restored
## through the switch itself, so any setting it saved is saved back too.
func test_every_switch_opens_on_and_writes_its_setting() -> void:
	for row_name in _ROW_SETTINGS:
		var key: String = _ROW_SETTINGS[row_name]
		var toggle := _toggle(row_name)
		assert_true(toggle != null, row_name + " needs its Toggle")
		if toggle == null:
			continue
		var original: bool = GameSettings.get(key)
		assert_eq(toggle.button_pressed, original, row_name + " opens on " + key)
		toggle.button_pressed = not original
		assert_eq(GameSettings.get(key), not original, row_name + " writes " + key)
		toggle.button_pressed = original


## At 1080x1920 each tab's sections fit above the scroll's bottom edge: 9:16
## never scrolls, on SUARA or on MAIN. Settings.gd is @tool, so its _ready()
## already ran show_tab(0) when the screen entered the tree; switching tabs
## here re-settles the Containers, since a hidden-then-shown card sorts a
## frame late.
func test_every_card_fits_the_design_screen_without_scrolling() -> void:
	var stand := track(LayoutFrame.stand_up("res://Scenes/UI/Settings.tscn",
		Vector2(1080, 1920))) as Control
	var root := stand.get_child(0)
	var scroll := stand.find_child("Scroll", true, false) as Control
	assert_true(scroll != null, "Settings needs Scroll")
	if scroll == null:
		return

	root.call("show_tab", 0)
	LayoutFrame.settle(root)
	var audio := stand.find_child("AudioCard", true, false) as Control
	assert_true(audio != null, "Settings needs AudioCard")
	if audio != null:
		assert_true(audio.get_global_rect().end.y <= scroll.get_global_rect().end.y,
			"SUARA ends at %d, below the scroll's %d" % [
				audio.get_global_rect().end.y, scroll.get_global_rect().end.y])

	root.call("show_tab", 1)
	LayoutFrame.settle(root)
	# DataCard is MAIN's last section, so it is the one that could spill.
	var data := stand.find_child("DataCard", true, false) as Control
	assert_true(data != null, "Settings needs DataCard")
	if data != null:
		assert_true(data.get_global_rect().end.y <= scroll.get_global_rect().end.y,
			"DATA ends at %d, below the scroll's %d" % [
				data.get_global_rect().end.y, scroll.get_global_rect().end.y])

	root.call("show_tab", 2)
	var credits := stand.find_child("CreditsCard", true, false) as Control
	assert_true(credits != null, "Settings needs CreditsCard")
	if credits != null:
		# A wrapping Label in this headless frame measures a letter per line,
		# so measure unwrapped: every credit line must fit the card's width on
		# one line anyway, and then the column's height is the real one.
		for label in credits.find_children("*", "Label", true, false):
			(label as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		LayoutFrame.settle(root)
		for label in credits.find_children("*", "Label", true, false):
			assert_true((label as Label).get_minimum_size().x <= scroll.size.x,
				"%s fits on one line" % label.name)
		# The card's settled rect keeps its wrapped height, so measure where its
		# unwrapped column would end.
		var end_y := credits.global_position.y + credits.get_combined_minimum_size().y
		assert_true(end_y <= scroll.get_global_rect().end.y,
			"CREDITS ends at %d, below the scroll's %d" % [end_y, scroll.get_global_rect().end.y])


## Reset Progres (2026-10-01): a tomato DangerButton opening the confirm popup,
## which the scene instances hidden (static chrome lives in the .tscn).
func test_reset_progres_is_a_red_button_that_asks_first() -> void:
	var button := _screen.get_node("%ResetProgressButton") as Button
	assert_eq(button.text, "Reset Progres")
	assert_eq(button.theme_type_variation, &"DangerButton", "a full wipe is a danger action")
	var popup := _screen.get_node("%ResetProgressPopup") as ResetProgressPopup
	assert_true(popup != null, "Settings.tscn instances the popup")
	assert_false(popup.visible, "hidden until asked")
	button.pressed.emit()
	assert_true(popup.visible, "the button opens the confirm, never wipes at once")
	popup.close()


## Android back with the popup open closes only the popup: Settings stays.
## (A second back would leave the screen, which a test must not trigger.)
func test_back_with_the_popup_open_closes_only_the_popup() -> void:
	var popup := _screen.get_node("%ResetProgressPopup") as ResetProgressPopup
	popup.open()
	_screen.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(popup.visible, "back closes the popup")
	assert_true(is_instance_valid(_screen) and _screen.is_inside_tree(), "and Settings stays")
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	var note: String = src.get_slice("func _notification(", 1).get_slice("
func ", 0)
	assert_true(note.find("_reset_popup.visible") < note.find("_on_back_pressed()"),
		"the popup is checked before Back leaves")


func test_battery_saver_default_off() -> void:
	var fresh: Node = (load("res://Scripts/GameSettings.gd") as GDScript).new()
	assert_false(fresh.get("battery_saver_enabled"), "Hemat Baterai defaults to off")
	fresh.free()


func test_battery_saver_caps_fps_persists_and_announces() -> void:
	var original_fps := Engine.max_fps
	var heard: Array = []
	var on_flip := func(enabled: bool) -> void: heard.append(enabled)
	GameSettings.battery_saver_changed.connect(on_flip)
	GameSettings.battery_saver_enabled = true
	GameSettings.battery_saver_enabled = true
	assert_eq(Engine.max_fps, GameSettings.BATTERY_SAVER_FPS, "on caps at 30")
	GameSettings.save_settings()
	GameSettings.battery_saver_changed.disconnect(on_flip)
	GameSettings.battery_saver_enabled = false
	assert_eq(Engine.max_fps, GameSettings.normal_fps(), "off returns to the project cap")
	GameSettings.load_settings()
	assert_true(GameSettings.battery_saver_enabled, "round-trips through save/load")
	assert_eq(heard, [true], "one emit per real flip")
	GameSettings.battery_saver_enabled = false
	GameSettings.save_settings()
	Engine.max_fps = original_fps


## The KREDIT tab reads like film credits (spec 2026-10-03-credits-tab):
## a CardSectionLabel heading, then every row of _CREDIT_ROWS in order,
## centred and wrapping, in its variation and words.
func test_credits_read_top_to_bottom() -> void:
	var vbox := _screen.get_node("%CreditsCard/Margin/VBox")
	var heading := vbox.get_child(0) as Label
	assert_eq(heading.theme_type_variation, &"CardSectionLabel")
	assert_eq(heading.text, "CREDITS")
	assert_eq(vbox.get_child_count(), _CREDIT_ROWS.size() + 1,
		"the heading plus exactly the credit rows")
	for i in _CREDIT_ROWS.size():
		var row: Array = _CREDIT_ROWS[i]
		var node := vbox.get_child(i + 1)
		assert_eq(String(node.name), row[0], "row %d is %s" % [i, row[0]])
		if String(row[0]).begins_with("Gap"):
			assert_true(node is Control and not node is Label, row[0] + " is a spacer")
			var gap := _CREDIT_SECTION_GAP
			if String(row[0]).begins_with("GapPair"):
				gap = _CREDIT_LIST_GAP if row[0] == "GapPair3" else _CREDIT_PAIR_GAP
			assert_eq((node as Control).custom_minimum_size.y, gap, row[0] + " height")
			continue
		assert_eq((node as Control).theme_type_variation, StringName(row[1]), row[0] + " variation")
		if node is Label:
			var label := node as Label
			assert_eq(label.text, row[2], row[0] + " text")
			assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, row[0] + " is centred")
			assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, row[0] + " wraps")
