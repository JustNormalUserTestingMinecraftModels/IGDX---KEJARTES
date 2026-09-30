@tool
extends McpTestSuite

## The Amplop Coklat level select (spec:
## docs/superpowers/specs/2026-09-25-amplop-level-select-design.md): a fan
## of three brown envelopes, one per grade, a briefing card for the centred
## one, and an open-envelope confirmation that sets the grade and wipes into
## the intro cutscene.
##
## Must be @tool, and no test here may be a coroutine.

const LS := preload("res://Scripts/LevelSelect/LevelSelect.gd")
const STUDENT_CARD := preload("res://Scripts/StudentCard/StudentCard.gd")

const LayoutFrame := preload("res://tests/layout_frame.gd")

const _SCRIPT_PATH := "res://Scripts/LevelSelect/LevelSelect.gd"
const _SCENE_PATH := "res://Scenes/LevelSelect/LevelSelect.tscn"
const _CONFIRM_SCRIPT := "res://Scripts/LevelSelect/OpenAmplopConfirm.gd"

## The screen, stood up once at the design size for the whole suite: per-test
## instancing floods the editor with deferred layout work (see
## test_school_day.gd's fixture note). suite_teardown frees it.
var _frame: Control
var _screen: Control


func suite_name() -> String:
	return "level_select"


func suite_setup(_ctx: Dictionary) -> void:
	_frame = LayoutFrame.stand_up(_SCENE_PATH, Vector2(1080, 1920))
	_screen = _frame.get_child(0) as Control


func suite_teardown() -> void:
	if is_instance_valid(_frame):
		_frame.get_parent().remove_child(_frame)
		_frame.free()
	_frame = null
	_screen = null


## Put the fan back on `index` without animating, as a test's starting point.
func _center(index: int) -> void:
	_screen._selected = index
	_screen._render_brief()
	_screen._layout_cards(false)


# ── Data ─────────────────────────────────────────────────────────────────────

## Weeks and target come from GameState (WEEKS_BY_GRADE 4/6/8,
## TARGET_UPLIFT_BY_GRADE 15/22/26), never hardcoded literals.
func test_weeks_and_target_come_from_their_owners() -> void:
	assert_eq(LS.weeks_for(7), GameState.WEEKS_BY_GRADE[7], "wk7")
	assert_eq(LS.weeks_for(8), GameState.WEEKS_BY_GRADE[8], "wk8")
	assert_eq(LS.weeks_for(9), GameState.WEEKS_BY_GRADE[9], "wk9")
	assert_eq(LS.target_for(7), int(GameState.TARGET_UPLIFT_BY_GRADE[7]), "t7")
	assert_eq(LS.target_for(8), int(GameState.TARGET_UPLIFT_BY_GRADE[8]), "t8")
	assert_eq(LS.target_for(9), int(GameState.TARGET_UPLIFT_BY_GRADE[9]), "t9")


## Every grade has a difficulty word, a gauge fill, a tag and a brief line.
func test_difficulty_map_covers_all_grades() -> void:
	for g in LS.GRADES:
		assert_true(LS.DIFFICULTY_WORD.has(g), "word for %d" % g)
		assert_true(LS.DIFFICULTY_FILL.has(g), "fill for %d" % g)
		assert_true(LS.TAG_TEXT.has(g), "tag for %d" % g)
		assert_true(LS.BRIEF_FLAVOR.has(g), "brief flavour for %d" % g)
	assert_eq(LS.DIFFICULTY_WORD[7], "santai", "kelas 7 is santai")
	assert_eq(LS.DIFFICULTY_WORD[8], "menantang", "kelas 8 is menantang")
	assert_eq(LS.DIFFICULTY_WORD[9], "susah", "kelas 9 is susah")


## The screen must not re-type balance numbers as literals.
func test_source_reads_balance_constants() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.weeks_for_grade"), "reads weeks from GameState")
	assert_true(src.contains("GameState.target_uplift_for_grade"), "reads target from GameState")


## The pupil count is the roster StudentCard really approves, not a copy.
func test_roster_size_is_student_cards_own_count() -> void:
	for g in LS.GRADES:
		assert_eq(LS.roster_size_for(g), STUDENT_CARD.max_approve_for(g),
			"kelas %d roster matches StudentCard" % g)
	assert_eq([LS.roster_size_for(7), LS.roster_size_for(8), LS.roster_size_for(9)],
		[2, 3, 4], "2/3/4 pupils by grade")
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCard.gd")
	assert_true(src.contains("MAX_APPROVE = max_approve_for("),
		"StudentCard reads its own count from the shared function")


# ── AmplopCard ───────────────────────────────────────────────────────────────

const CARD := preload("res://Scripts/LevelSelect/AmplopCard.gd")
const _CARD_SCENE := "res://Scenes/LevelSelect/AmplopCard.tscn"


## A card stood up under the editor root, freed after the test.
func _card() -> Control:
	var card := (load(_CARD_SCENE) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


## Data-drive knobs live on the CARD ROOT as @exports (child overrides drop on save).
func test_amplop_card_exposes_root_exports() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/AmplopCard.gd")
	for prop in ["grade", "tab_text", "envelope_texture", "flap_texture",
			"seal_texture", "interactive"]:
		assert_true(src.contains("@export var %s" % prop), "exports %s" % prop)
	assert_true(src.contains("signal picked"), "has picked signal")


## The card scene instances cleanly, carries its script and draws the
## envelope art from Assets/Images/LevelSelect.
func test_amplop_card_scene_instantiates() -> void:
	var card := _card()
	assert_true(card.get_script() == CARD, "carries AmplopCard.gd")
	for n in ["Bob/Body", "Bob/Flap", "Bob/Seal", "Bob/Tab", "Bob/Pupils", "HitButton"]:
		assert_true(card.get_node_or_null(n) != null, "has " + n)
	var body := card.get_node("Bob/Body") as TextureRect
	assert_true(body.texture != null
		and body.texture.resource_path.begins_with("res://Assets/Images/LevelSelect/"),
		"the body wears the level-select envelope art")


## The tab shows tab_text, and the pupils stay hidden until the envelope opens.
func test_amplop_card_applies_its_exports() -> void:
	var card := _card()
	card.tab_text = "Kelas 9"
	assert_eq((card.get_node("Bob/Tab") as Button).text, "Kelas 9", "tab text applied")
	assert_false((card.get_node("Bob/Pupils") as Control).visible,
		"pupils hide until open()")
	card.interactive = false
	assert_eq((card.get_node("HitButton") as Control).mouse_filter,
		Control.MOUSE_FILTER_IGNORE, "a non-interactive card ignores taps")


## open() shows exactly `portraits.size()` pupils and reseal() hides them again.
func test_amplop_card_open_shows_the_roster_and_reseals() -> void:
	var card := _card()
	var tex := load("res://Assets/Images/MuridPortrait/Andi.png") as Texture2D
	var tw: Tween = card.open([tex, tex, tex])
	tw.kill()
	var pupils := card.get_node("Bob/Pupils") as Control
	assert_true(pupils.visible, "open() shows the pupils")
	var shown := 0
	for p in pupils.get_children():
		if (p as Control).visible:
			shown += 1
	assert_eq(shown, 3, "three pupils for a three-pupil roster")
	card.reseal()
	assert_false(pupils.visible, "reseal() hides them")
	assert_eq((card.get_node("Bob/Seal") as Control).scale, Vector2.ONE, "the seal is back")
	assert_eq((card.get_node("Bob/Flap") as Control).scale, Vector2.ONE, "the flap is closed")


# ── The screen ───────────────────────────────────────────────────────────────

## The screen has exactly three AmplopCards, one per grade.
func test_screen_has_three_cards_one_per_grade() -> void:
	var found: Array = []
	for c in _screen._stack.get_children():
		if c.get_script() == CARD:
			found.append(c.grade)
	found.sort()
	assert_eq(found, [7, 8, 9], "three cards for 7/8/9")


## No theme_override_* in any level-select scene, bar the layout-only
## constants CLAUDE.md allows.
func test_scenes_have_no_theme_overrides() -> void:
	var allowed := ["separation", "h_separation", "v_separation",
		"margin_left", "margin_top", "margin_right", "margin_bottom"]
	for path in [_SCENE_PATH, _CARD_SCENE, "res://Scenes/LevelSelect/OpenAmplopConfirm.tscn",
			"res://Scenes/LevelSelect/PupilPeek.tscn"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.begins_with("theme_override_"):
				continue
			var key := line.get_slice("=", 0).strip_edges()
			assert_true(key.begins_with("theme_override_constants/")
				and allowed.has(key.get_slice("/", 1)), "%s carries %s" % [path, key])


## Selecting each grade shows its word, weeks, pupil heads, tag and gauge.
func test_brief_reflects_selected_grade() -> void:
	for i in range(LS.GRADES.size()):
		var g: int = LS.GRADES[i]
		_center(i)
		assert_eq(_screen._brief_title.text, "Kelas %d" % g, "title for %d" % g)
		assert_eq(_screen._diff_label.text, LS.DIFFICULTY_WORD[g], "word for %d" % g)
		assert_eq(_screen._tag.text, LS.TAG_TEXT[g], "tag for %d" % g)
		assert_eq(_screen._week_grid_filled(), LS.weeks_for(g), "weeks painted for %d" % g)
		assert_eq(_screen._weeks_value.text, "%d minggu" % LS.weeks_for(g), "weeks text")
		var heads := 0
		for h in _screen._pupils_box.get_children():
			if (h as Control).visible:
				heads += 1
		assert_eq(heads, LS.roster_size_for(g), "one head per pupil in %d" % g)
		assert_true(is_equal_approx(_screen._diff_bar.value, LS.DIFFICULTY_FILL[g]),
			"gauge fill for %d" % g)
	_center(0)


## The week grid has a cell for every week of the longest grade.
func test_week_grid_holds_the_longest_grade() -> void:
	var longest := 0
	for g in LS.GRADES:
		longest = maxi(longest, LS.weeks_for(g))
	assert_true(_screen._week_grid.get_child_count() >= longest,
		"%d cells for a %d-week grade" % [_screen._week_grid.get_child_count(), longest])


## The raw target never reaches the screen: the brief line carries counts and
## the difficulty word only.
func test_brief_line_has_the_word_not_the_target() -> void:
	for g in LS.GRADES:
		var line: String = _screen._brief_line(g)
		assert_true(line.contains(LS.DIFFICULTY_WORD[g]), "kelas %d line names its word" % g)
		assert_false(line.contains(str(LS.target_for(g))), "kelas %d line hides its target" % g)


# ── Navigation ───────────────────────────────────────────────────────────────

## Selection clamps to 0..2 and drives the brief.
func test_select_clamps_and_renders() -> void:
	_center(0)
	_screen._select(5)
	assert_eq(_screen._selected, 2, "clamps high to 9")
	assert_eq(_screen._diff_label.text, "susah", "the brief follows")
	_screen._select(-3)
	assert_eq(_screen._selected, 0, "clamps low to 7")
	_center(0)


## The centred card sits at the fan's middle, in front in draw and input
## order; the others tilt away from it; the edge arrows disable at the ends.
func test_fan_centres_the_selected_card() -> void:
	_center(1)
	var cards: Array = _screen._cards
	var stack: Control = _screen._stack
	assert_true(is_equal_approx(cards[1].position.x, stack.size.x * 0.5), "Kelas 8 centred")
	assert_true(cards[0].rotation < 0.0 and cards[2].rotation > 0.0, "the sides tilt away")
	assert_true(cards[1].get_index() > cards[0].get_index()
		and cards[1].get_index() > cards[2].get_index(), "the centre card is in front")
	assert_true(is_equal_approx(cards[1].scale.x, _screen.card_scale), "the centre is card_scale")
	assert_true(cards[0].scale.x < cards[1].scale.x, "the sides sit back")
	assert_false(_screen._prev.disabled or _screen._next.disabled, "both arrows lead somewhere")
	_center(0)
	assert_true(_screen._prev.disabled, "nothing before Kelas 7")


## The envelopes are drawn larger than the 400x526 template, the opened one
## at the same size as the centred one, and the centred envelope (tab and a
## full hop included) still clears the header.
func test_envelopes_are_enlarged_and_clear_the_header() -> void:
	_center(0)
	assert_gt(_screen.card_scale, 1.0, "the fan is scaled up")
	# Read through the global transform: a scale set on the card itself
	# passes a direct read here, then the CenterContainer resets it on sort.
	var shown: Control = _screen._confirm.card
	shown.get_parent().notification(Container.NOTIFICATION_SORT_CHILDREN)
	assert_true(is_equal_approx(shown.get_global_transform().get_scale().x, _screen.card_scale),
		"the opened envelope matches the fan, after its container sorts")
	var authored: float = _screen.card_scale
	_screen.card_scale = 1.35
	assert_true(is_equal_approx(shown.get_global_transform().get_scale().x, 1.35),
		"retuning card_scale resizes the opened envelope too")
	_screen.card_scale = authored
	var card: Control = _screen._cards[0]
	var tab_top: float = card.get_global_transform().origin.y \
		- (card.bob_rest_y * -1.0 + 84.0 + LS.HOP_RISE) * _screen.card_scale
	var header_bottom: float = (_screen.get_node("Safe/UI/Header") as Control).get_global_rect().end.y
	assert_true(tab_top > header_bottom,
		"hop peak %.0f clears the header's %.0f" % [tab_top, header_bottom])


## All three input paths are wired, with the shuffle-and-bounce overshoot.
func test_all_nav_inputs_present() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("InputEventScreenTouch"), "swipe wired")
	assert_true(src.contains("card.picked.connect(_on_card_picked)"), "tap wired")
	assert_true(src.contains("_prev.pressed.connect(_on_prev)")
		and src.contains("_next.pressed.connect(_on_next)"), "arrows wired")
	assert_true(src.contains("Tween.TRANS_BACK"), "shuffle-bounce uses TRANS_BACK overshoot")


## The idle bob loops on each card's Bob pivot, never the posed root.
func test_idle_motion_present() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("func _start_idle("), "has idle starter")
	assert_true(src.contains("set_loops()"), "idle loops")
	assert_true(src.contains("card.bob"), "idle drives the Bob pivot")


## The fan's geometry knobs must stay @exports, or a designer's live tuning
## silently stops taking effect. A light guard; the real acceptance of the
## fan's look is visual. Walks the property list rather than matching
## "@export var <name>" in the source, so a knob that becomes @export_range
## (or any other export variant) still passes.
func test_fan_geometry_knobs_are_still_exported() -> void:
	var script := load(_SCRIPT_PATH) as Script
	var by_name := {}
	for prop in script.get_script_property_list():
		by_name[prop["name"]] = prop
	for knob in ["fan_step_x", "fan_drop_y", "fan_step_degrees", "side_scale"]:
		assert_true(by_name.has(knob), "has property %s" % knob)
		if not by_name.has(knob):
			continue
		var usage: int = by_name[knob]["usage"]
		assert_true(usage & PROPERTY_USAGE_EDITOR != 0, "exports %s" % knob)


# ── Confirmation ─────────────────────────────────────────────────────────────

func test_confirm_exposes_present_and_signals() -> void:
	var src := FileAccess.get_file_as_string(_CONFIRM_SCRIPT)
	assert_true(src.contains("func present("), "has present()")
	assert_true(src.contains("signal accepted"), "has accepted signal")
	assert_true(src.contains("signal cancelled"), "has cancelled signal")


## The letter became the notebook dialog frame (2026-09-28, UI depth pass
## Phase 2, Task 6): the kicker label is gone, its title now the frame's
## stitched sticker, and its round close is wired as Batal.
func test_the_letter_is_the_notebook_dialog() -> void:
	var confirm := (load("res://Scenes/LevelSelect/OpenAmplopConfirm.tscn") as PackedScene).instantiate()
	track(confirm)
	var letter := confirm.get_node_or_null("Letter") as NotebookFrame
	assert_true(letter != null, "the letter is a NotebookFrame")
	if letter != null:
		assert_eq(letter.title_text, "SURAT TUGAS", "the kicker became the sticker")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/LevelSelect/OpenAmplopConfirm.gd"),
		"_letter.close_pressed.connect(_on_close_pressed)")


## The confirm starts hidden, and a hidden Container never lays out its
## children, so the wrapping Body sat 1px wide and asked for ~3500px of
## height. NotebookFrame grows to its content's minimum and never shrinks
## back, so the first amplop opened onto a blank, screen-tall page with the
## letter off the top. A minimum width keeps Body's wrap sane before its
## first layout.
func test_the_letter_body_has_a_wrap_width_before_its_first_layout() -> void:
	var confirm := (load("res://Scenes/LevelSelect/OpenAmplopConfirm.tscn") as PackedScene).instantiate()
	track(confirm)
	var body := confirm.get_node("Letter/VBox/Body") as Label
	assert_true(body.custom_minimum_size.x >= 600.0,
		"Body needs a minimum width, or the hidden letter grows off screen")


## present() shows the grade, its pupils and the letter over a scrim that
## takes every tap; dismiss() reseals and hides.
func test_confirm_presents_and_dismisses() -> void:
	var confirm: Control = _screen._confirm
	assert_false(confirm.visible, "hidden until a grade is opened")
	var tex := load("res://Assets/Images/MuridPortrait/Citra.png") as Texture2D
	var tw: Tween = confirm.present(9, [tex, tex, tex, tex], _screen._brief_line(9))
	tw.kill()
	assert_true(confirm.visible, "present() shows it")
	assert_eq(confirm._title.text, "Mulai Kelas 9?", "the letter names the grade")
	assert_eq(confirm.card.tab_text, "Kelas 9", "the envelope is Kelas 9's")
	var shown := 0
	for p in confirm.card.get_node("Bob/Pupils").get_children():
		if (p as Control).visible:
			shown += 1
	assert_eq(shown, 4, "Kelas 9's four pupils peek out")
	assert_eq((confirm.get_node("Scrim") as Control).mouse_filter, Control.MOUSE_FILTER_STOP,
		"the scrim takes taps meant for the fan")
	confirm.dismiss()
	assert_false(confirm.visible, "dismiss() hides it")
	assert_false((confirm.card.get_node("Bob/Pupils") as Control).visible, "and reseals")


## The envelope zooms toward the player on its own tween, running beside
## card.open()'s seal/flap/pupil tween rather than after it (a tw.parallel()
## after card.open() would only join its last, pupil, step), and rests back
## at the fan's scale once dismissed.
func test_confirm_zooms_the_envelope_open_and_rests_on_dismiss() -> void:
	var src := FileAccess.get_file_as_string(_CONFIRM_SCRIPT)
	assert_true(src.contains("open_scale_target"), "exports open_scale_target")
	assert_true(src.contains("open_zoom_sec"), "exports open_zoom_sec")
	assert_true(src.contains('tween_property(envelope, "scale"'),
		"tweens the envelope's own scale")
	var confirm: Control = _screen._confirm
	var tex := load("res://Assets/Images/MuridPortrait/Andi.png") as Texture2D
	var tw: Tween = confirm.present(7, [tex, tex], _screen._brief_line(7))
	tw.kill()
	assert_true(confirm._zoom != null and confirm._zoom.is_valid(),
		"the zoom runs on its own tween, started alongside the open")
	confirm.dismiss()
	assert_true(is_equal_approx(confirm.envelope.scale.x, _screen.card_scale),
		"dismiss() rests the envelope back at the fan's card_scale")


## Accepting sets the grade via GameState and hands off once, to the intro.
func test_accept_sets_grade_and_transitions() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.set_grade(grade)"), "sets grade")
	assert_eq(src.count("Transition.change_scene("), 1, "a single hand-off")
	assert_true(src.contains("Transition.change_scene(NEXT_SCENE, Transition.Style.WIPE)"),
		"wipes like MainMenu's start did")
	assert_eq(LS.NEXT_SCENE, "res://Scenes/CutScene/CutScene.tscn", "into the intro")


# ── Shadows ──────────────────────────────────────────────────────────────────

## Every amplop card casts a soft drop shadow behind its Body art via the
## shared PaperShadow template (mirrors test_paper_shadow.gd's
## test_the_flat_elements_now_cast_a_shadow). The confirm's Letter became the
## notebook dialog frame (2026-09-28, UI depth pass Phase 2, Task 6): its own
## Chrome art gives it the lift the old Card variation's StyleBoxFlat shadow
## used to -- specifically Chrome/Cover, the lipped hardcover panel that sits
## proud of the page on every side. test_the_letter_is_the_notebook_dialog
## already covers the frame's identity (title_text, the close wiring); this
## half instead proves the lift claim this comment makes.
func test_amplop_card_casts_a_shadow_and_the_confirm_letter_is_the_notebook_dialog() -> void:
	var card := _card()
	var body := card.get_node("Bob/Body") as TextureRect
	var shadow := body.get_node_or_null("Shadow") as Control
	assert_true(shadow != null, "Bob/Body has no Shadow")
	if shadow == null:
		return
	assert_eq(shadow.scene_file_path, "res://Scenes/UI/PaperShadow.tscn",
		"the shadow must be the shared PaperShadow template, not a hand-copy")
	assert_eq(shadow.get_index(), 0, "the shadow should be Body's first child")
	assert_true(shadow.show_behind_parent, "the shadow must draw behind Body")
	assert_eq(shadow.get("shadow_texture"), body.texture,
		"the shadow must use Body's own envelope texture")
	var confirm := (load("res://Scenes/LevelSelect/OpenAmplopConfirm.tscn") as PackedScene) \
		.instantiate()
	track(confirm)
	var letter := confirm.get_node_or_null("Letter") as NotebookFrame
	assert_true(letter != null, "OpenAmplopConfirm's Letter is now a NotebookFrame")
	if letter == null:
		return
	assert_eq(letter.ring_count, 4, "a dialog's four rings, same as any other")
	var cover := letter.get_node_or_null("Chrome/Cover")
	assert_true(cover != null,
		"Chrome/Cover is the lipped hardcover that gives the letter its lift")


## Re-texturing the card (envelope_texture) must re-texture its shadow too,
## or a skinned envelope casts the default art's silhouette.
func test_amplop_card_shadow_follows_envelope_texture() -> void:
	var card := _card()
	var body := card.get_node("Bob/Body") as TextureRect
	var shadow := body.get_node_or_null("Shadow") as Control
	assert_true(shadow != null, "Bob/Body has no Shadow")
	if shadow == null:
		return
	var flap_tex := load("res://Assets/Images/LevelSelect/amplop_flap.png") as Texture2D
	card.envelope_texture = flap_tex
	assert_eq(body.texture, flap_tex, "Body wears the new texture")
	assert_eq(shadow.get("shadow_texture"), flap_tex,
		"the shadow follows Body's new envelope texture")


# ── Flow ─────────────────────────────────────────────────────────────────────

## MainMenu routes through the level select exactly when the picker is on.
func test_main_menu_routes_through_the_level_select() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	assert_true(src.contains('"res://Scenes/LevelSelect/LevelSelect.tscn"'),
		"MainMenu knows the level select")
	assert_true(src.contains("GameState.is_level_select_enabled()"),
		"and asks GameState whether to go there")


## CutScene's runtime-built picker is gone; it defaults to Kelas 7 only when
## no grade was picked upstream. Its Debug toggle left for the Debug overlay's
## General tab (Scripts/Debug/DebugLevelSelectToggle.gd), so the intro no longer
## names the picker's scene at all.
func test_cutscene_hands_grade_picking_to_the_level_select() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/CutScene.gd")
	for gone in ["PILIH TINGKAT KELAS", "_setup_level_select_ui", "level_select_overlay",
			"_create_grade_button", "show_level_select_modal"]:
		assert_false(src.contains(gone), "CutScene.gd must not mention " + gone)
	assert_true(src.contains("if not GameState.is_level_select_enabled():"),
		"CutScene defaults the grade only when the picker is off")
	assert_false(src.contains('"res://Scenes/LevelSelect/LevelSelect.tscn"'),
		"the Debug toggle that routed to the level select moved to the Debug overlay")
