@tool
extends McpTestSuite

## Report card: a read-only student card viewer over approved_students.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "report_card"

const _SCENE_PATH := "res://Scenes/ReportCard/ReportCard.tscn"
const _SCRIPT_PATH := "res://Scripts/ReportCard/ReportCard.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "ReportCard.tscn must exist")
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "ReportCard.tscn must instantiate")
	scene.free()

func test_has_no_approve_buttons() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("Aprove", true, false) == null,
		"the report card is a viewer -- no approve button")
	scene.free()

func test_has_no_stamp() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("StampApprove", true, false) == null,
		"the report card is a viewer -- no approval stamp")
	scene.free()

func test_has_no_belajar_button() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("BelajarButton", true, false) == null,
		"the report card is a viewer -- no belajar button")
	scene.free()

func test_script_has_no_approval_logic() -> void:
	var src := _source()
	for symbol in ["_on_approve_pressed", "MAX_APPROVE", "_shift_approve_for_belajar", "_show_stamp_if_approved"]:
		assert_false(src.contains(symbol),
			"approval logic must not survive the derivation: " + symbol)

func test_script_has_no_tutorial() -> void:
	var src := _source()
	assert_false(src.contains("tutorial_steps"),
		"the report card has no tutorial")

func test_keeps_pagination_and_swipe() -> void:
	var src := _source()
	assert_true(src.contains("_transition_page"), "pagination is kept")
	assert_true(src.contains("_evaluate_swipe"), "swipe navigation is kept")

func test_pages_come_from_approved_students() -> void:
	assert_true(_source().contains("GameState.approved_students"),
		"the viewer reads the live roster, not the six-entry candidate list")

func test_delegates_rendering_to_the_shared_view() -> void:
	assert_true(_source().contains("StudentCardView."),
		"rendering is shared with student_card, not forked")

func test_back_button_returns_to_lobby() -> void:
	assert_true(_source().contains("res://Scenes/Lobby/Lobby.tscn"),
		"back must return to the lobby")

func test_back_button_node_exists_and_is_wired() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	var btn := scene.find_child("BackButton", true, false)
	assert_true(btn != null, "the report card must have a real, tappable back button")
	assert_true(btn is BaseButton, "the back control must be a button")
	scene.free()


## ReportCard's stagger table drifted from StudentCard's: it named four
## nodes that test_student_card_layout asserts must not exist, and omitted
## the bio panel and all five icon clusters, so those never animated in.
## The two screens render the same card, so the table must be the same.
func test_stagger_table_matches_the_student_card() -> void:
	var report := FileAccess.get_file_as_string(
		"res://Scripts/ReportCard/ReportCard.gd")
	for row_name in ["BioPanel", "IconAkademis", "IconSeniBudaya",
			"IconOlahraga", "IconMood", "IconEnergy"]:
		assert_true(report.contains('"%s"' % row_name),
			"CARD_ROW_ORDER is missing %s" % row_name)
	# "Akademis" is not a dead name any more: since the stat-key rename it is
	# the academic stat bar's node.
	for dead in ["\"Nama\"", "\"Profil\"", "\"Kepribadian\","]:
		assert_false(report.contains(dead),
			"CARD_ROW_ORDER still names the removed node %s" % dead)


## Without the pre-hide, the incoming page's rows ride the card's own
## modulate up to fully visible, then get yanked back to invisible when
## _stagger_in_card's pop_in() takes over. StudentCard calls this before
## the fade-in tween, not after (StudentCard.gd:667).
func test_rows_are_hidden_before_they_stagger_in() -> void:
	var report := FileAccess.get_file_as_string(
		"res://Scripts/ReportCard/ReportCard.gd")
	assert_true(report.contains("func _hide_card_rows("),
		"ReportCard.gd has no _hide_card_rows")
	var hide_at := report.find("_hide_card_rows(new_index)")
	var tween_at := report.find("var tween_in = create_tween()")
	assert_true(hide_at != -1, "_hide_card_rows is never called on transition")
	assert_true(tween_at != -1, "the page transition tween is gone")
	assert_true(hide_at < tween_at,
		"the pre-hide must run BEFORE the card's fade-in tween")


## The screen is a read-only report; nothing on it can be chosen, so the
## copied "Pilih Muridmu" header was wrong. Indonesian, per project
## convention.
func test_header_reads_as_a_report_not_a_chooser() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	# The header moved into Safe/UI on 2026-09-16 with the tall-phone pass and
	# is reached by its unique name, which is stable wherever it sits.
	var header := scene.get_node_or_null("%PilihMurid") as Label
	assert_true(header != null, "PilihMurid header label is missing")
	assert_eq(header.text, "Rapor Murid",
		"header still carries StudentCard's chooser copy")
	scene.free()


## ReportCard has no tutorial (test_script_has_no_tutorial), so the copied
## spotlight ColorRect and its full-rect ClickArea button were dead weight
## sitting over the whole card stack.
func test_tutorial_scrim_is_gone() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.get_node_or_null("ColorRect") == null,
		"the vestigial tutorial ColorRect is still in the scene")
	scene.free()


## The papers' soft shadow is no longer one static node behind the stack: each
## paper carries its own PaperShadow.tscn so it flies with the paper. That
## contract lives in tests/test_paper_shadow.gd (2026-09-10).


const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _DESIGN_WIDTH := 1080.0


## The back button shares the title's row. On 2026-09-15 it hid the title's
## first two letters ("POR MURID"): a copied rect put the title's ink under
## the button. This measures the drawn text, outline included, in the UI
## node's own space, so a wider font, a longer title or a bigger button fails
## here rather than on a phone. Rescued from the amazing-kalam worktree, it
## caught the "R" still under the button on 2026-09-28: the button renders at
## its 124 px theme minimum, not the 96 px its offsets then said.
func test_title_ink_clears_the_back_button() -> void:
	var host := Control.new()
	Engine.get_main_loop().root.add_child(host)
	track(host)
	host.size = Vector2(_DESIGN_WIDTH, 1920)
	var inst := (load(_SCENE_PATH) as PackedScene).instantiate() as Control
	# A Control under the editor root inherits the editor theme otherwise.
	inst.theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	host.add_child(inst)
	var title := inst.get_node("%PilihMurid") as Label
	var back := inst.get_node("%BackButton") as Control
	var safe := inst.get_node("Safe") as MarginContainer
	var ui_width := _DESIGN_WIDTH - safe.get_theme_constant("margin_left") \
		- safe.get_theme_constant("margin_right")

	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var outline := title.get_theme_constant("outline_size")
	var text_w := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var sb := title.get_theme_stylebox("normal")
	var t := title.get_rect()
	var box_left := t.position.x + sb.get_margin(SIDE_LEFT)
	var box_w := t.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
	var text_x := box_left
	if title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		text_x += (box_w - text_w) / 2.0
	elif title.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		text_x += box_w - text_w
	var ink_left := text_x - outline
	var ink_right := text_x + text_w + outline
	var back_end := back.get_rect().end.x

	assert_true(ink_left >= back_end,
		"the title's ink starts at x=%.1f, under the back button (ends at x=%.1f)"
			% [ink_left, back_end])
	assert_true(text_w <= box_w and ink_right <= ui_width,
		"the title does not fit: %.0fpx of text in a %.0fpx box, ink ends at x=%.1f of %.0f"
			% [text_w, box_w, ink_right, ui_width])
