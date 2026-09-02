@tool
extends McpTestSuite

## AturJadwal is the weekly-scheduling screen: pick a day (Senin-Jumat) per
## student, assign a category (Akademis/Olahraga/SeniBudaya/Istirahat), then
## START WEEK routes to SchoolDay. Contract that must never change:
## GameState.day_schedules[student_id][day_name] = {category, mood_cost,
## energy_cost} -- SchoolDay (not yet migrated) reads this shape directly.
##
## Technique notes carried over from Tasks 9-14 (see test_student_card.gd /
## test_main_menu.gd for the fuller writeup):
##  * This suite must itself be @tool.
##  * The runner calls suite.call(name) WITHOUT awaiting -- no coroutine tests.
##  * _collect_overrides is copied verbatim from test_main_menu.gd.
##  * Per Task 12's finding (student_card.gd, not @tool): _ready() does NOT
##    run when this suite instantiates a non-@tool Control under the editor's
##    own root. Structural/contract checks below therefore use
##    get_node_or_null() against the scene-declared tree and source-text
##    scanning, never runtime state that only _ready() would populate.

const _SCENE_PATH := "res://Scenes/AturJadwal/atur_jadwal.tscn"
const _SCRIPT_PATH := "res://Scripts/AturJadwal/atur_jadwal.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "atur_jadwal"


var _screen: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_screen = scene.instantiate()
	_screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_lobby_studentlist_and_schoolday() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"back button must still route to the Lobby")
	assert_true(src.contains("res://Scenes/StudentList/student_list.tscn"),
		"selecting a student must still route to StudentList")
	assert_true(src.contains("res://Scenes/SchoolSimulation/SchoolDay.tscn"),
		"starting the week must still route to SchoolDay")


func test_day_schedules_still_written_in_the_same_shape() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.day_schedules"),
		"must still write GameState.day_schedules")
	for key in ["\"category\"", "\"mood_cost\"", "\"energy_cost\""]:
		assert_true(src.contains(key),
			"day_schedules entries must still carry " + key)


func test_debug_tutorial_bypass_skips_the_atur_jadwal_tutorial() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("if GameState.tutorials_bypassed or tutorial_phase3_done:"),
		"the debug menu's master tutorial-bypass flag must skip this screen's tutorial too")


func test_stat_bar_gd_is_deleted_and_unreferenced() -> void:
	assert_false(FileAccess.file_exists("res://Scripts/AturJadwal/stat_bar.gd"),
		"Scripts/AturJadwal/stat_bar.gd must be deleted")
	var tscn := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(tscn.contains("stat_bar.gd"),
		"the scene must no longer reference the deleted stat_bar.gd")
	var gd := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(gd.contains("stat_bar.gd"),
		"the script must no longer reference the deleted stat_bar.gd")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_screen != null, "scene must instantiate")
	assert_true(_screen.is_inside_tree(), "scene must enter the tree cleanly")
	for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
		assert_true(_screen.get_node_or_null("BGHari/" + day) != null,
			"missing day button: " + day)
	assert_true(_screen.get_node_or_null("Peringatan") != null, "missing Peringatan")
	assert_true(_screen.get_node_or_null("Penjadwalan") != null, "missing Penjadwalan")


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var paths := [
		"BGHari/Senin", "BGHari/Selasa", "BGHari/Rabu", "BGHari/Kamis", "BGHari/Jumat",
		"StartWeek", "BackButton",
		"Peringatan/TextureRect/ButtonYes", "Peringatan/TextureRect/ButtonNo",
		"Penjadwalan/TextureRect/Rows/RowAkademik", "Penjadwalan/TextureRect/Rows/RowSeniBudaya",
		"Penjadwalan/TextureRect/Rows/RowAtletik", "Penjadwalan/TextureRect/Rows/RowWirausaha",
		"Penjadwalan/TextureRect/Rows/RowLibur", "Penjadwalan/TextureRect/PopupBack",
	]
	for p in paths:
		var b := _screen.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		if b == null:
			continue
		var h: float = maxf(b.size.y * b.scale.y, b.get_combined_minimum_size().y * b.scale.y)
		var w: float = maxf(b.size.x * b.scale.x, b.get_combined_minimum_size().x * b.scale.x)
		assert_true(minf(h, w) >= float(tokens.touch_target_min),
			"%s is %dx%d px, below the %d px minimum touch target"
				% [p, int(w), int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

## The day-note tint now lives in the DayStickyNote template, not this
## screen's script. The screen just calls show_empty/show_scheduled/
## show_holiday; the template maps category -> DesignTokens.category_color().
func test_day_notes_are_daystickynote_instances_tinted_via_category_color() -> void:
	for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
		var note := _screen.get_node_or_null("BGHari/" + day)
		assert_true(note is DayStickyNote, day + " must be a DayStickyNote instance")
	var tmpl := FileAccess.get_file_as_string("res://Scripts/AturJadwal/DayStickyNote.gd")
	assert_true(tmpl.contains("category_color"),
		"the template must tint via DesignTokens.category_color()")


## The popup's five picks are ActivityRows now: icon, preview pill, name.
func test_popup_has_five_activity_rows() -> void:
	var root := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows")
	assert_true(root != null, "the popup must hold its rows in a Rows container")
	var found := {}
	for child in root.get_children():
		if child is ActivityRow:
			found[child.category] = child
	for category in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
		assert_true(found.has(category),
			"the popup must offer an ActivityRow for " + category)
	assert_eq(found.size(), 5, "exactly five activity rows, no more")


## The three skill rows keep their progress-toward-target bar; the other two
## have no target, so they must not carry one.
func test_only_skill_rows_carry_a_stat_bar() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	for child in root.get_children():
		if not (child is ActivityRow):
			continue
		var bar := child.get_node_or_null("Container/Pill/StatBar")
		var is_skill: bool = child.category in ["Akademis", "SeniBudaya", "Olahraga"]
		if is_skill:
			assert_true(bar != null, child.category + " must keep its StatBar")
		else:
			assert_true(bar == null, child.category + " has no target, so no StatBar")


## The UI says "Atletik" where the code says "Olahraga". Keeping the two
## apart is what lets the label change without breaking every category match.
func test_display_names_are_indonesian_and_decoupled_from_category_keys() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	var expected := {
		"Akademis": "Akademik",
		"SeniBudaya": "Seni Budaya",
		"Olahraga": "Atletik",
		"Wirausaha": "Wirausaha",
		"Istirahat": "Libur",
	}
	for child in root.get_children():
		if child is ActivityRow:
			assert_eq(child.display_name, expected[child.category],
				child.category + " must display as " + expected[child.category])


func test_popup_still_has_a_back_button() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack")
	assert_true(back != null, "the popup needs its own back control")
	assert_true(back is BaseButton, "the back control must be tappable")


func test_bg_stat_bars_are_statbars() -> void:
	var expected := {
		"BGStat/Akademis1": "Akademis",
		"BGStat/Akademis2": "SeniBudaya",
		"BGStat/Akademis3": "Olahraga",
		"BGStat/Kepribadian1": "Istirahat",
		"BGStat/Kepribadian2": "Libur",
	}
	for p in expected.keys():
		var bar := _screen.get_node_or_null(p)
		assert_true(bar is StatBar, "%s must be a StatBar" % p)
		if bar is StatBar:
			assert_eq(bar.category, expected[p], "%s category" % p)


## The five stat bars used to live inside the splash-art TextureButton, so
## tapping a progress pill fell through to the button and navigated away to
## StudentList. They must be siblings, not descendants.
func test_stat_pills_are_not_inside_the_splash_button() -> void:
	var splash := _screen.get_node_or_null("TextureButton")
	assert_true(splash != null, "the splash TextureButton is gone")
	assert_true(splash.get_node_or_null("BGStat") == null,
		"BGStat is still a child of the splash button")
	assert_true(_screen.get_node_or_null("BGStat") != null,
		"BGStat is not at the root")


## The mockup's top band: blurred classroom from y=0 to the shelf at 766,
## then the wooden divider to 843, then the untouched whiteboard.
##
## 2026-09-01, hand-tuned: the splash art's box grew tall enough to spill
## over the sticky-note row beneath the shelf. Rather than re-clip the
## TextureButton, the z-order puts BGHari (whiteboard) IN FRONT of the
## splash -- whiteboard.png is transparent above y~766 (letting the splash
## show through there) and opaque below it, so the whiteboard's own alpha
## channel masks off whatever the splash draws past the shelf line. Order
## is therefore Backdrop -> splash -> whiteboard -> shelf, not the
## whiteboard-first order the original mockup-match pass used.
func test_top_band_matches_the_mockup() -> void:
	var backdrop := _screen.get_node_or_null("Backdrop") as TextureRect
	assert_true(backdrop != null, "Backdrop TextureRect is missing")
	assert_true(backdrop.texture != null, "Backdrop has no texture")
	assert_eq(backdrop.texture.resource_path,
		"res://Assets/Images/UI/blur_background.png",
		"Backdrop is not drawing blur_background.png")
	assert_eq(backdrop.offset_bottom, 766.0,
		"the backdrop band ends at the shelf line")

	# The shelf's two measured bands: #B37D4D face 766-817, #77573A edge
	# 817-843. Drawn as ColorRects rather than a themed Panel -- see the
	# plan's status note; converting them to a ShelfEdge variation needs an
	# editor restart to pick up the new DesignTokens properties.
	var face := _screen.get_node_or_null("ShelfFace") as ColorRect
	assert_true(face != null, "ShelfFace is missing")
	assert_eq(face.offset_top, 766.0, "shelf face starts at the backdrop's end")
	assert_eq(face.offset_bottom, 817.0, "shelf face is 51px tall")

	var edge := _screen.get_node_or_null("ShelfEdge") as ColorRect
	assert_true(edge != null, "ShelfEdge is missing")
	assert_eq(edge.offset_top, 817.0, "shelf edge follows the face")
	assert_eq(edge.offset_bottom, 843.0, "shelf edge is 26px tall")

	var whiteboard := _screen.get_node_or_null("BGHari")
	assert_true(whiteboard != null, "BGHari is gone")
	var splash := _screen.get_node_or_null("TextureButton")
	assert_true(splash != null, "TextureButton (the splash) is gone")

	assert_true(backdrop.get_index() < splash.get_index(),
		"the splash must draw over the backdrop")
	assert_true(splash.get_index() < whiteboard.get_index(),
		"the whiteboard must draw over the splash, so its own opaque " +
		"region masks the figure below the shelf line instead of letting " +
		"it spill over the sticky notes")
	assert_true(whiteboard.get_index() < face.get_index(),
		"the shelf must draw over the whiteboard")


## Hand-tuned in the editor on 2026-09-01 (overrides the plan's original
## 0,0,431,766 -- a uniform scale of the source art's own aspect). Pins
## whatever the designer last set rather than a derived value, since
## there is no longer a single formula driving this rect.
func test_splash_is_sized_to_the_mockup_window() -> void:
	var splash := _screen.get_node_or_null("TextureButton") as Control
	assert_true(splash != null, "the splash TextureButton is gone")
	assert_eq(splash.offset_left, -76.0, "splash left")
	assert_eq(splash.offset_top, 45.0, "splash top")
	assert_eq(splash.offset_right, 624.0, "splash right")
	assert_true(absf(splash.offset_bottom - 1289.0835) <= 0.01,
		"splash bottom")


## The whiteboard art itself is still out of scope for the restyle and must
## survive untouched. The five sticky notes were polished on 2026-09-01
## (docs/superpowers/plans/2026-09-01-atur-jadwal-sticky-note-polish.md):
## each is now a DayStickyNote whose Paper still draws stickynotes.png.
func test_the_whiteboard_is_unchanged_and_notes_are_stickynotes() -> void:
	var board := _screen.get_node_or_null("BGHari") as TextureRect
	assert_true(board != null, "BGHari is gone")
	assert_eq(board.texture.resource_path, "res://Assets/Images/UI/whiteboard.png",
		"the whiteboard texture changed")
	for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
		var note := _screen.get_node_or_null("BGHari/%s" % day) as DayStickyNote
		assert_true(note != null, "sticky note %s is gone or was reparented" % day)
		var paper := note.get_node_or_null("Paper") as TextureButton
		assert_true(paper != null and paper.texture_normal != null
			and paper.texture_normal.resource_path == "res://Assets/Images/UI/stickynotes.png",
			"%s Paper must still draw stickynotes.png" % day)


## Uniform 126px pitch from y=129. The mockup's own pitch drifts (129,
## 126, 127, 117) because the art was hand-placed; a uniform pitch is
## within 5px of it everywhere and is what a container can express.
func test_stat_rows_sit_on_the_mockup_grid() -> void:
	var expected := {
		"Akademis1": 112.0,
		"Akademis2": 238.0,
		"Akademis3": 364.0,
		"Kepribadian2": 490.0,
		"Kepribadian1": 616.0,
	}
	for bar_name in expected:
		var bar := _screen.get_node_or_null("BGStat/%s" % bar_name) as Control
		assert_true(bar != null, "BGStat/%s is missing" % bar_name)
		assert_eq(bar.offset_top, expected[bar_name], "%s row top" % bar_name)
		assert_eq(bar.offset_bottom, expected[bar_name] + 70.0,
			"%s row height must be the mockup's 70px" % bar_name)
		assert_eq(bar.offset_left, 680.0, "%s pill left" % bar_name)
		assert_eq(bar.offset_right, 1004.0, "%s pill right" % bar_name)


## kepribadian1 is MOOD and kepribadian2 is ENERGY, but the mockup's
## fourth row is the lightning glyph and its fifth is the smiley. The
## visual order is therefore swapped from the node numbering -- getting it
## backwards puts the lightning bolt on the mood bar.
func test_each_row_carries_its_mockup_icon() -> void:
	var expected := {
		"IconAkademis1": "res://Assets/Images/StudentCard/stat_akademis.png",
		"IconAkademis2": "res://Assets/Images/StudentCard/stat_senibudaya.png",
		"IconAkademis3": "res://Assets/Images/StudentCard/stat_olahraga.png",
		"IconKepribadian2": "res://Assets/Images/StudentCard/stat_energy.png",
		"IconKepribadian1": "res://Assets/Images/StudentCard/stat_mood.png",
	}
	for icon_name in expected:
		var icon := _screen.get_node_or_null(
			"BGStat/%s" % icon_name) as TextureRect
		assert_true(icon != null, "BGStat/%s is missing" % icon_name)
		assert_true(icon.texture != null, "%s has no texture" % icon_name)
		assert_eq(icon.texture.resource_path, expected[icon_name],
			"%s is drawing the wrong glyph" % icon_name)

	var pairs := {
		"IconAkademis1": "Akademis1",
		"IconAkademis2": "Akademis2",
		"IconAkademis3": "Akademis3",
		"IconKepribadian2": "Kepribadian2",
		"IconKepribadian1": "Kepribadian1",
	}
	for icon_name in pairs:
		var icon := _screen.get_node_or_null("BGStat/%s" % icon_name) as Control
		var bar := _screen.get_node_or_null(
			"BGStat/%s" % pairs[icon_name]) as Control
		var icon_mid := (icon.offset_top + icon.offset_bottom) / 2.0
		var bar_mid := (bar.offset_top + bar.offset_bottom) / 2.0
		assert_true(absf(icon_mid - bar_mid) <= 1.0,
			"%s is not centred on %s" % [icon_name, pairs[icon_name]])


func test_peringatan_pops_in_over_a_scrim_with_shake_and_fail_sfx() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.pop_in(peringatan)"),
		"Peringatan must enter with Juice.pop_in")
	assert_true(src.contains("&\"Scrim\""),
		"the warning backdrop must be a Scrim-variation panel")
	assert_true(src.contains("Juice.shake(peringatan)"),
		"an incomplete-schedule attempt must shake the warning dialog")
	assert_true(src.contains("AudioDirector.play_sfx(&\"fail\")"),
		"an incomplete-schedule attempt must play the fail sfx")


## CLAUDE.md flags atur_jadwal.gd as holding its own copies of numbers that
## also live in Balance.gd. A shadow constant means the tester edits Balance,
## reruns, and the screen does not move -- the exact failure Balance.gd exists
## to prevent.
func test_no_shadow_balance_constants_remain() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for shadowed in [
		"BASE_GAIN", "HOBBY_BONUS_GAIN",
		"MOOD_LOSS_MIN", "MOOD_LOSS_MAX",
		"ENERGY_LOSS_MIN", "ENERGY_LOSS_MAX",
		"DAYOFF_GAIN_MIN", "DAYOFF_GAIN_MAX",
		"WIRAUSAHA_MOOD_MIN", "WIRAUSAHA_MOOD_MAX",
		"WIRAUSAHA_ENERGY_MIN", "WIRAUSAHA_ENERGY_MAX",
	]:
		assert_true(not src.contains("const " + shadowed),
			"atur_jadwal.gd must not redeclare " + shadowed + "; read Balance.gd via ActivityPreview")


## The projected-gain readout was grade-blind: it hardcoded grade 7's numbers,
## so grades 8 and 9 previewed gains their students would never get.
func test_pending_gain_is_grade_aware() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("ActivityPreview.skill_gain"),
		"_compute_pending_gain must delegate to ActivityPreview so it follows the grade")


## The card art is a 1080x1080 texture whose visible card occupies only
## x 211-868, y 34-1046. Rendered into a square 1394x1394 TextureRect, that
## content lands at local x 272-1120, y 44-1350 -- and on screen at x 115-964,
## y 202-1508, which is the mockup's card position (115-964, 203-1507).
const _CARD_LEFT := 272.0
const _CARD_RIGHT := 1120.0
const _CARD_TOP := 44.0
const _CARD_BOTTOM := 1350.0
const _ROW_HEIGHT := 180.0


func test_rows_are_inset_within_the_card_content() -> void:
	var rows := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows") as Control
	assert_true(rows != null, "Rows must exist")
	assert_eq(rows.offset_left, 375.0, "rows are inset 12.1% from the card's left edge")
	assert_eq(rows.offset_right, 1024.0, "rows are inset 11.3% from the card's right edge")
	assert_eq(rows.offset_top, 102.0, "the first row starts 4.4% down the card")
	assert_true(rows.offset_left > _CARD_LEFT and rows.offset_right < _CARD_RIGHT,
		"the row block must sit inside the card art, not over its transparent padding")
	assert_true(rows.offset_top > _CARD_TOP,
		"the row block must start below the card's top edge, not over its transparent padding")


func test_row_separation_matches_the_mockup_pitch() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	assert_eq(rows.get_theme_constant("separation"), 40,
		"a 180px row plus 40px separation reproduces the mockup's 220px pitch")


func test_back_arrow_sits_inside_the_card() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack") as Control
	assert_true(back != null, "PopupBack must exist")
	assert_eq(back.offset_left, 329.0, "back arrow x, 6.7% in from the card's left")
	assert_eq(back.offset_top, 1170.0, "back arrow y, its art centred 92.3% down the card")
	assert_true(back.offset_left >= _CARD_LEFT,
		"the back arrow must not hang off the card's left padding")
	assert_true(back.offset_bottom <= _CARD_BOTTOM,
		"the back arrow must stay above the card's bottom edge")


## 102 + 5*180 + 4*40 = 1162, which must clear the card's bottom edge with room
## for the arrow beneath. If a later change alters row height or separation,
## this is the test that catches the stack overflowing the card.
func test_the_row_stack_fits_inside_the_card() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	var row_count := 0
	var row_height := 0.0
	for child in rows.get_children():
		if child is ActivityRow:
			row_count += 1
			row_height = (child as ActivityRow).custom_minimum_size.y
	assert_eq(row_height, _ROW_HEIGHT, "each row is the mockup's 180px tall")
	var sep: int = rows.get_theme_constant("separation")
	var stack_bottom: float = rows.offset_top + row_count * row_height + (row_count - 1) * sep
	assert_true(stack_bottom <= _CARD_BOTTOM,
		"the row stack ends at %d, past the card's bottom at %d" % [int(stack_bottom), int(_CARD_BOTTOM)])


## The mockup's card spans 78.7% of the 1080px screen width (x 115-964). Rendering
## the card texture into too small a rect makes a correct layout look cramped at
## every level, because every child inherits the shortfall.
func test_card_is_rendered_at_the_mockup_scale() -> void:
	var card := _screen.get_node_or_null("Penjadwalan/TextureRect") as TextureRect
	assert_true(card != null, "the popup's card TextureRect must exist")
	var w: float = card.offset_right - card.offset_left
	var h: float = card.offset_bottom - card.offset_top
	assert_eq(w, h, "the card rect must stay square so the 1080x1080 art is not stretched")
	assert_eq(w, 1394.0, "the card rect is 1394px so its content renders 850px wide")
	# Mockup card centre is 105px above screen centre, not centred.
	var centre_y: float = (card.offset_top + card.offset_bottom) / 2.0
	assert_eq(centre_y, -105.0, "the card sits 105px above screen centre, as in the mockup")


# ----------------------------------------------------------------- helper

## _update_day_button_colors() must route each day to the DayStickyNote
## template, never poke a child Label directly (the old bare-button code did
## `btn.get_child(0) as Label`).
func test_update_day_colors_uses_the_template_api() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("get_child(0) as Label"),
		"the old per-button Label poke must be gone")
	assert_true(src.contains("show_scheduled("), "must call DayStickyNote.show_scheduled()")
	assert_true(src.contains("show_holiday("), "must call DayStickyNote.show_holiday()")
	assert_true(src.contains("show_empty("), "must call DayStickyNote.show_empty()")


## The day-note squash-pop must fire only on a real player assignment, which
## is _on_activity_selected -- not from _update_day_button_colors (a repaint).
## Design decision #8 of the sticky-note-polish plan.
func test_assign_pop_is_driven_from_on_activity_selected() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_assign_pop()"),
		"atur_jadwal.gd must drive the day-note pop itself")
	var idx := src.find("func _on_activity_selected")
	assert_true(idx != -1, "_on_activity_selected must exist")
	var next := src.find("\nfunc ", idx + 1)
	var body := src.substr(idx, next - idx if next != -1 else src.length() - idx)
	assert_true(body.contains("play_assign_pop()"),
		"the pop must be called from inside _on_activity_selected")


## The warning dialog shipped on a stock placeholder ("pngwing.com (2).png").
## It now wears the same finished card art as the Penjadwalan panel. The art
## is square (1080x1080) and the frame is 740x428, so it must be a
## NinePatchRect -- a TextureRect would smear the painted corners.
func test_peringatan_frame_is_a_ninepatch_of_the_card_art() -> void:
	var frame := _screen.get_node_or_null("Peringatan/TextureRect")
	assert_true(frame != null, "Peringatan/TextureRect is missing")
	if frame == null:
		return
	assert_true(frame is NinePatchRect,
		"the warning frame must be a NinePatchRect, got %s" % frame.get_class())
	if frame is NinePatchRect:
		assert_true(frame.texture != null, "the warning frame has no texture")
		assert_eq(frame.texture.resource_path,
			"res://Assets/Images/UI/penjadwalan_card_bg.png",
			"the warning frame must draw the finished card art")
		# The 1080x1080 source has transparent padding around the painted
		# card -- the actual card is the 658x1013 rect at (211,34). Without
		# this crop the card would float small inside a mostly-transparent
		# frame instead of filling it.
		assert_eq(frame.region_rect, Rect2(211, 34, 658, 1013),
			"the warning frame must crop to the card art, not the full padded canvas")
		for side in ["left", "top", "right", "bottom"]:
			assert_true(frame.get("patch_margin_" + side) > 0,
				"patch_margin_%s must be set or the corners still stretch" % side)

	# The dialog's three children must survive the retype -- atur_jadwal.gd
	# reaches them by path in six places.
	for child_name in ["Label", "ButtonYes", "ButtonNo"]:
		assert_true(_screen.get_node_or_null(
			"Peringatan/TextureRect/%s" % child_name) != null,
			"%s was lost when the frame was retyped" % child_name)


## Nothing in the warning dialog may still reference the stock placeholder.
func test_no_pngwing_placeholder_remains_in_the_warning_dialog() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/AturJadwal/atur_jadwal.tscn")
	var peringatan_start := src.find("[node name=\"Peringatan\"")
	assert_true(peringatan_start != -1, "Peringatan node block not found")
	var peringatan_end := src.find("[node name=\"Penjadwalan\"", peringatan_start)
	var block := src.substr(peringatan_start, peringatan_end - peringatan_start)
	assert_true(not block.contains("3_a6kja"),
		"the Peringatan block still draws the pngwing placeholder")


## The warning label used to be BarLabel (white glyph + dark rim), designed
## for text sitting on a saturated progress-bar fill. The card art is now a
## light cream gradient, so white-on-cream was near-unreadable -- it must be
## TitleLabel (dark text_primary, no outline) instead. Separately, the label
## used to stretch down to offset_bottom 400, which put its last line under
## the YA / TIDAK buttons at offset_top 284; it must end at or above wherever
## the buttons currently start, not at a hardcoded 268, so a deliberate
## reposition of either node doesn't false-fail this test while an actual
## regression (label growing back down over the buttons) still does.
func test_peringatan_label_reads_against_the_light_card() -> void:
	var label := _screen.get_node_or_null("Peringatan/TextureRect/Label") as Label
	assert_true(label != null, "Peringatan/TextureRect/Label is missing")
	var button_yes := _screen.get_node_or_null("Peringatan/TextureRect/ButtonYes") as Control
	assert_true(button_yes != null, "Peringatan/TextureRect/ButtonYes is missing")
	if label == null or button_yes == null:
		return
	assert_eq(label.get_theme_type_variation(), &"TitleLabel",
		"the warning label must be TitleLabel (dark text) to read against the light card art")
	assert_true(label.offset_bottom <= button_yes.offset_top,
		"the warning label must not extend down past where the buttons start, or its last line renders under them")


## Copied verbatim from tests/test_main_menu.gd.
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


## StatBar used to build its own ValueLabel unconditionally, doubling up
## with the one authored in the scene: two overlapping labels, and the
## authored one frozen at "0%" forever. It must adopt instead.
func test_each_stat_bar_has_exactly_one_value_label() -> void:
	var bar_names := ["Akademis1", "Akademis2", "Akademis3",
		"Kepribadian1", "Kepribadian2"]
	for bar_name in bar_names:
		var bar := _screen.get_node_or_null("BGStat/%s" % bar_name) as StatBar
		assert_true(bar != null, "BGStat/%s is not a StatBar" % bar_name)
		if bar == null:
			continue
		var labels := 0
		for child in bar.get_children():
			if child is Label:
				labels += 1
		assert_eq(labels, 1,
			"%s must carry exactly one Label, found %d" % [bar_name, labels])


## BarLabel (white glyph + dark rim) is the only variation that reads over
## both the pale track and a saturated category fill.
func test_stat_bar_value_labels_use_the_bar_label_variation() -> void:
	var bar_names := ["Akademis1", "Akademis2", "Akademis3",
		"Kepribadian1", "Kepribadian2"]
	for bar_name in bar_names:
		var label := _screen.get_node_or_null(
			"BGStat/%s/ValueLabel" % bar_name) as Label
		assert_true(label != null, "%s/ValueLabel is missing" % bar_name)
		if label != null:
			assert_eq(String(label.theme_type_variation), "BarLabel",
				"%s/ValueLabel must use BarLabel" % bar_name)

	var src := FileAccess.get_file_as_string("res://Scripts/UI/StatBar.gd")
	assert_true(src.contains("get_node_or_null(\"ValueLabel\")"),
		"StatBar must adopt an authored ValueLabel rather than build a second one")


## A schedule edit must be visible on the bar it moved, and switching
## students must bring the five rows in as a stagger rather than a snap.
func test_stat_bars_are_animated_on_change_and_on_student_switch() -> void:
	var bar_names := ["Akademis1", "Akademis2", "Akademis3",
		"Kepribadian1", "Kepribadian2"]
	for bar_name in bar_names:
		var bar := _screen.get_node_or_null("BGStat/%s" % bar_name) as StatBar
		assert_true(bar != null, "BGStat/%s is not a StatBar" % bar_name)
		if bar != null:
			assert_true(bar.pop_on_change,
				"%s must pop when its value moves" % bar_name)

	var bar_src := FileAccess.get_file_as_string("res://Scripts/UI/StatBar.gd")
	assert_true(bar_src.contains("pop_on_change"),
		"StatBar must expose pop_on_change")
	# Juice.pop_in zeroes modulate.a and tweens it back, so a regression that
	# swapped AnimUtils.squash_bounce back to Juice.pop_in here would blink
	# the bar and its label transparent on every value change -- pin the
	# choice so that regression fails a test instead of only failing on-screen.
	assert_true(bar_src.contains("AnimUtils.squash_bounce"),
		"StatBar's pop must use AnimUtils.squash_bounce (scale-only)")
	var pop_start := bar_src.find("func set_stat")
	assert_true(pop_start != -1, "StatBar.set_stat is missing")
	# Match the CALL form, with its paren: the code comment beside the pop
	# names Juice.pop_in to explain why it is not used, and a bare substring
	# scan would fail on that comment.
	assert_true(not bar_src.substr(pop_start).contains("Juice.pop_in("),
		"StatBar.set_stat must not call Juice.pop_in -- it zeroes modulate.a and would flash the bar")

	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.stagger_in"),
		"the stagger must go through Juice.stagger_in")
	# _update_student_display() runs on every activity assignment (see the
	# schedule-assignment path around line 948), so a call to
	# _stagger_stat_rows() must be gated behind a guard variable rather than
	# unconditional -- otherwise every tap would re-fade the whole stat
	# panel and fight the per-bar pop. Assert the guard exists so that
	# gating cannot be silently dropped; contains("_stagger_stat_rows")
	# alone would still pass even if the function were never called.
	assert_true(src.contains("_stagger_stat_rows"),
		"the screen must stagger its stat rows in")
	assert_true(src.contains("_last_staggered_student_id"),
		"the stagger must be gated by a last-staggered-student guard, not called unconditionally")


## The stagger animates opacity and scale only. The icons are final art on
## a measured grid -- their offsets must not be touched.
func test_the_stagger_does_not_move_the_final_icons() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var start := src.find("func _stagger_stat_rows")
	assert_true(start != -1, "_stagger_stat_rows is missing")
	# Slice to the real extent of the function (up to the next "func "),
	# not a fixed character count -- a fixed slice can overrun the body and
	# scan unrelated code below it, producing a false failure.
	var next_func := src.find("\nfunc ", start + 1)
	var body := src.substr(start, next_func - start if next_func != -1 else -1)
	for forbidden in ["offset_left", "offset_top", "offset_right",
			"offset_bottom", "position"]:
		assert_true(not body.contains(forbidden),
			"_stagger_stat_rows must not write %s -- the icon grid is final"
			% forbidden)

	# The mockup's visual top-to-bottom order is the reverse of the node
	# numbering here: Kepribadian2 (energy, lightning) sits above
	# Kepribadian1 (mood, smiley). Pin the order so a future edit can't
	# silently swap them and make the stagger run out of order down the screen.
	var kp2_index := body.find("Kepribadian2")
	var kp1_index := body.find("Kepribadian1")
	assert_true(kp2_index != -1 and kp1_index != -1,
		"_stagger_stat_rows must reference both Kepribadian1 and Kepribadian2")
	assert_true(kp2_index < kp1_index,
		"Kepribadian2 (energy) must be staggered in before Kepribadian1 (mood) to match the mockup's visual order")


## The five bars used to tint via self_modulate, which multiplies the WHOLE
## node -- track and rim included -- so a bar at value 0 rendered as a
## solid category-coloured capsule instead of an empty one. Each bar must
## now resolve to its category's own theme variation (whose fill stylebox
## bakes the colour in, see ThemeFactory._build_progress) and leave the
## node itself untinted.
func test_bg_stat_bars_use_their_category_variation_and_stay_untinted() -> void:
	var expected := {
		"BGStat/Akademis1": &"StatBarAkademis",
		"BGStat/Akademis2": &"StatBarSeniBudaya",
		"BGStat/Akademis3": &"StatBarOlahraga",
		"BGStat/Kepribadian1": &"StatBarIstirahat",
		"BGStat/Kepribadian2": &"StatBarLibur",
	}
	for p in expected.keys():
		var bar := _screen.get_node_or_null(p) as StatBar
		assert_true(bar != null, "%s must be a StatBar" % p)
		if bar == null:
			continue
		assert_eq(bar.theme_type_variation, expected[p],
			"%s must wear its category's theme variation" % p)
		assert_eq(bar.self_modulate, Color.WHITE,
			"%s must not tint the whole node -- the fill stylebox carries the colour" % p)
