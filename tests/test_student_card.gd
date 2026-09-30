@tool
extends McpTestSuite

## StudentCard is the heaviest screen in the project (2297-line scene,
## 512 theme overrides, 2051-line script). The first two tests here are
## the *behavioral contract net*: they were written and confirmed GREEN
## against the completely unmodified scene/script, before any migration
## work started, so that every later slice has something real to break.
##
## Technique notes carried over from Tasks 9/10/11:
##  * This suite must itself be @tool or the runner reports the class as
##    abstract/broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper below is copied verbatim from
##    tests/test_main_menu.gd, which walks get_property_list() and
##    cross-checks the per-name has_theme_*_override() APIs.
##  * ThemeDB's project-theme fallback does not populate for a scene
##    instantiated under the editor's own root, so the baked theme is
##    assigned explicitly before the scene enters the tree.

const _SCENE_PATH := "res://Scenes/StudentCard/StudentCard.tscn"
const _SCRIPT_PATH := "res://Scripts/StudentCard/StudentCard.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _BEAT_PATH := "res://Scripts/StudentCard/HeadmasterBeat.gd"
const _GAME_STATE_PATH := "res://Scripts/GameState.gd"
const _PANEL_SCENE := "res://Scenes/UI/TutorialPanel.tscn"
## The card's layout column, where the name plate sits above the title.
const _LAYOUT := "Frame/Margin/Layout/"


func suite_name() -> String:
	return "student_card"


var _card: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_card = scene.instantiate()
	_card.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_card)
	track(_card)


func teardown() -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null


# ------------------------------------------------ behavioral contract net

func test_approved_students_contract_is_intact() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for symbol in ["GameState.approved_students", "GameState.selected_student",
			"GameState.returned_from_student_card"]:
		assert_true(src.contains(symbol),
			"the selection contract must still write: " + symbol)


func test_still_routes_to_the_lobby() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/Lobby/Lobby.tscn"),
		"student_card must still route to the lobby")


func test_debug_tutorial_bypass_skips_the_student_card_tutorial() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("if GameState.tutorials_bypassed:"),
		"the debug menu's master tutorial-bypass flag must skip this screen's tutorial too")
	assert_true(src.contains("tutorial_active = false\n\t\tcolor_rect.hide()"),
		"bypassing must disable interaction gating and hide the overlay, same as a finished tutorial does"
	)


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_card != null, "scene must instantiate")
	assert_true(_card.is_inside_tree(), "scene must enter the tree cleanly")
	for i in range(1, 7):
		assert_true(_card.get_node_or_null("KertasMurid%d" % i) != null,
			"missing student page KertasMurid%d" % i)


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_card, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	# These buttons are absolutely positioned (no container sort pending),
	# so their rect comes straight from the scene's offsets and is readable
	# without a frame wait. `scale` matters: the page arrows are drawn from
	# a 520px icon shrunk by a scale factor.
	var tokens := DesignTokens.load_default()
	var paths := [
		"KertasMurid1/Aprove", "KertasMurid1/Batal",
		"KertasMurid1/KutuBuku", "KertasMurid1/KutuBuku2",
		"BelajarButton", "%NextButtonKanan", "%NextButtonKiri",
	]
	for p in paths:
		var b := _card.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h: float = maxf(b.size.y * b.scale.y,
			b.get_combined_minimum_size().y * b.scale.y)
		var w: float = maxf(b.size.x * b.scale.x,
			b.get_combined_minimum_size().x * b.scale.x)
		assert_true(minf(h, w) >= float(tokens.touch_target_min),
			"%s is %dx%d px, below the %d px minimum touch target"
				% [p, int(w), int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

## The Mood and Energy bars were authored as "Istirahat" and "Libur" and so
## wore the rest and holiday accents, which held only while a category was
## nothing but a colour. Once each category gained its own motif they needed
## their own identity, or mood would have been stamped with the rest motif
## and energy the holiday one.
##
## Which is which is settled by StudentCardView._STAT_ICONS, where Mood
## pairs with stat_mood.png and Energy with stat_energy.png -- and by
## build_stat_bars(), which maps them straight through. populate() used to
## set the two crossed over; that contradiction was deleted rather than
## pinned here.
func test_stat_bars_are_statbars_with_a_category() -> void:
	var expected := {
		"Mood": "Mood",
		"Energy": "Energy",
		"Akademis": "Akademis",
		"SeniBudaya": "SeniBudaya",
		"Olahraga": "Olahraga",
	}
	for i in range(1, 7):
		for bar_name in expected.keys():
			var bar := _card.get_node_or_null("KertasMurid%d/%s" % [i, bar_name])
			assert_true(bar is StatBar,
				"KertasMurid%d/%s must be a StatBar" % [i, bar_name])
			assert_eq(bar.category, expected[bar_name],
				"KertasMurid%d/%s category" % [i, bar_name])


## These buttons are on the L size step (160px tall), which uses font_h1 (64px)
## rather than the standard font_title (36px), so their variation names carry the L suffix.
func test_action_buttons_use_theme_variations() -> void:
	var expected := {
		# Approving a student is an ordinary confirm and cancelling it
		# discards nothing, so the 2026-09-10 pass moved this pair off
		# green/red. SuccessButton is now reserved for something earned
		# (the lobby's CLAIM) and DangerButton for something discarded
		# (quitting a minigame mid-run).
		"KertasMurid1/Aprove": &"PrimaryButtonL",
		# StudentCard keeps the cream secondary it had before the 2026-09-14
		# lobby-style-buttons pass turned every other SecondaryButton brown.
		"KertasMurid1/Batal": &"StudentCardSecondaryButtonL",
		"KertasMurid1/KutuBuku": &"TraitPill",
		"KertasMurid1/KutuBuku2": &"TraitPill",
		"BelajarButton": &"PrimaryButtonL",
	}
	for p in expected.keys():
		var b := _card.get_node_or_null(p) as Button
		assert_true(b != null, "missing button: " + p)
		assert_eq(b.theme_type_variation, expected[p], p + " variation")


func test_motion_and_audio_feedback_are_wired() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.stagger_in"),
		"student pages must stagger in on entry")
	# The stat and trait detail popups' pop-in reveal now lives in the shared
	# scenes they were extracted into (StatDetailPopup.gd / TraitDetailPopup.gd),
	# not in StudentCard.gd itself -- that's the point of the extraction.
	var stat_popup_src := FileAccess.get_file_as_string("res://Scripts/UI/StatDetailPopup.gd")
	var trait_popup_src := FileAccess.get_file_as_string("res://Scripts/UI/TraitDetailPopup.gd")
	assert_true(stat_popup_src.contains("Juice.pop_in"),
		"the stat detail popup must pop in")
	assert_true(trait_popup_src.contains("Juice.pop_in"),
		"the trait detail popup must pop in")
	assert_true(src.contains("AudioDirector.play_sfx(&\"stamp\")"),
		"approve must play the stamp sfx")
	assert_true(src.contains("AudioDirector.play_sfx(&\"unstamp\")"),
		"reject must play the unstamp sfx")


# ------------------------------------------------------ StudentCardView

## _transition_page captures belajar_orig_pos before the page changes, which
## for a still-hidden button is its authored rect. It then calls
## _update_nav_buttons -> _shift_approve_for_belajar, which tweens the button
## to the correct spot beside Aprove/Batal -- and used to follow that with a
## second tween back to the stale belajar_orig_pos, undoing it. The swipe that
## first revealed BELAJAR therefore flew it off the bottom of the screen.
## The reveal belongs to _shift_approve_for_belajar alone, which parks the
## button off-screen right and slides it in on every page change
## (_reset_all_approve_positions clears approve_shifted first).
func test_page_transition_leaves_the_belajar_slide_to_the_shift() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var start := src.find("func _transition_page")
	assert_true(start != -1, "_transition_page is gone")
	if start == -1:
		return
	var body := src.substr(start)
	var stop := body.find("func _update_nav_buttons")
	assert_true(stop != -1, "_update_nav_buttons must follow _transition_page")
	if stop == -1:
		return
	body = body.substr(0, stop)
	assert_false(body.contains("tween_in.tween_property(belajar_button"),
		"_transition_page must not tween belajar_button back to the position " +
		"it captured before the page changed -- that undoes the shift")
	assert_true(body.contains("tween_out.tween_property(belajar_button"),
		"the button must still be thrown off with the old card")


## _transition_page parks the incoming card a full screen-width off to the
## side and only then tweens it home -- and it calls _update_nav_buttons, and
## so _shift_approve_for_belajar, while the card is still parked there. A
## target computed from the card's live position therefore lands BELAJAR a
## screen-width out (measured at 1640 on a 1080x2400 phone, against Batal's
## 30). The settled position is the original_position meta, which
## _transition_page itself already trusts as the tween's destination.
func test_the_belajar_shift_reads_the_cards_settled_position() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var start := src.find("func _shift_approve_for_belajar")
	assert_true(start != -1, "_shift_approve_for_belajar is gone")
	if start == -1:
		return
	var body := src.substr(start)
	var stop := body.find("func _reset_approve_position")
	assert_true(stop != -1, "_reset_approve_position must follow the shift")
	if stop == -1:
		return
	body = body.substr(0, stop)
	assert_true(body.contains("original_position"),
		"the shift must place BELAJAR from the card's settled " +
		"original_position meta, not from its mid-animation position")
	assert_false(body.contains("var kertas_pos = active_kertas.position"),
		"active_kertas.position is the parked position during a page change")


func test_student_card_view_class_exists() -> void:
	assert_true(ResourceLoader.exists("res://Scripts/StudentCard/StudentCardView.gd"),
		"the shared card view must exist")

func test_quirk_descriptions_are_available_from_the_view() -> void:
	assert_true(StudentCardView.quirk_description("Kutu Buku") != "",
		"Kutu Buku must have a description")
	assert_true(StudentCardView.quirk_description("TidakAda") == "",
		"an unknown quirk yields an empty description, not an error")

func test_persona_descriptions_are_available_from_the_view() -> void:
	assert_true(StudentCardView.persona_description("Persona Tekun") != "",
		"Persona Tekun must have a description")

func test_student_card_delegates_to_the_view() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/StudentCard.gd")
	assert_true(src.contains("StudentCardView."),
		"student_card must consume the shared view, not duplicate it")

func test_tutorial_target_node_paths_are_unchanged() -> void:
	## The tutorial steps target node paths by string. The extraction must
	## not move any of them.
	var scene := (load("res://Scenes/StudentCard/StudentCard.tscn") as PackedScene).instantiate()
	for path in ["KertasMurid1/Mood", "KertasMurid1/KutuBuku"]:
		assert_true(scene.get_node_or_null(path) != null,
			"tutorial target must still resolve: " + path)
	scene.free()


# ------------------------------------------------ the tutorial's one counter

## StudentCard used to write the coach-mark's labels itself, with its own
## "(n/N) " title prefix, and never called TutorialPanel.show_step(). When the
## panel grew a "Langkah n / N" pill, the scene's sample pill ("Langkah 1 / 3")
## therefore showed above every step of the grade-7 tutorial. Now every step
## goes through show_step() with its number and count, and the pill is this
## screen's only counter.
func test_show_step_hands_its_number_and_count_to_the_panels_pill() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_source(src, "_show_step")
	assert_false(body.is_empty(), "_show_step was found")
	assert_contains(body,
		"_tutorial_panel.show_step(step.title, step.text, prompt, index + 1, tutorial_steps.size())",
		"every step goes through the panel with its 1-based number and the step count")


func test_the_title_no_longer_carries_its_own_counter() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("(%d/%d)"),
		"the panel's pill counts the steps; a title prefix would count them twice")
	assert_false(src.contains("_tutorial_title_label"),
		"the title is written by show_step(), not by a label this screen holds")
	assert_false(src.contains("_tutorial_body_label"),
		"the body is written by show_step(), not by a label this screen holds")


func test_a_fresh_tutorial_panel_shows_no_sample_pill() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_source(src, "_build_tutorial_panel")
	assert_false(body.is_empty(), "_build_tutorial_panel was found")
	var added := body.find("color_rect.add_child(_tutorial_panel)")
	var emptied := body.find('_tutorial_panel.show_step("", "",')
	assert_true(added != -1, "the panel joins the tree here")
	assert_true(emptied > added,
		"once in the tree, an empty show_step() hides the scene's authored sample pill")


## StudentCard builds its own card (it does not go through TutorialPanel.mount), so it
## says the same thing mount() does: transparent until a step or the beat fades it in,
## or an empty card shows at the overlay's corner for a frame before it is placed.
func test_the_card_starts_unseen_before_it_joins_the_tree() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_source(src, "_build_tutorial_panel")
	var hidden := body.find("_tutorial_panel.modulate.a = 0.0")
	var added := body.find("color_rect.add_child(_tutorial_panel)")
	assert_true(hidden != -1, "_build_tutorial_panel makes the card transparent")
	assert_true(hidden < added, "and does it before the card is in the tree")


# ----------------------------------------------------------------- helper

## The source of `func_name` in `src`: from its `func` line up to the next
## column-0 `func`, or the end of the file.
func _function_source(src: String, func_name: String) -> String:
	var start := src.find("\nfunc %s(" % func_name)
	if start == -1:
		return ""
	var stop := src.find("\nfunc ", start + 1)
	return src.substr(start) if stop == -1 else src.substr(start, stop - start)


## Copied verbatim from tests/test_main_menu.gd. Godot 4.6's Control has
## no get_theme_*_override_list(); this walks get_property_list() and asks
## the per-name has_theme_*_override() APIs instead. Constants/fonts/icons
## are deliberately excluded, matching the reference test.
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


# ------------------------------------------------ the arrow's size and side

## StudentCard clamped its arrow with a hard-coded 320px picture, so the
## smaller arrow still kept 320px away from every edge. The arrow now sizes
## itself from its own arrow_size and stands its tip beside the hole, inside
## the overlay and off the card. This screen still places its card itself
## (from step 7 on it is centred down the screen), so the arrow is told the
## rectangle that rule gives, not left to land on it.
func test_the_arrow_is_placed_from_its_own_size_not_a_hard_coded_clamp() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_source(src, "_highlight_multiple")
	assert_false(body.is_empty(), "_highlight_multiple was found")
	assert_true(body.contains("_tutorial_arrow.point_at(Rect2(local_pos, size_with_padding),"),
		"the arrow points at the padded hole")
	assert_true(body.contains("Rect2(Vector2.ZERO, color_rect.size)"), "within the overlay")
	assert_false(src.contains("320.0"), "no hard-coded 320px arrow is left")
	assert_false(src.contains("var W =") or src.contains("var H ="),
		"no local arrow width and height either")


func test_the_arrow_keeps_off_the_card_this_screen_places() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(_function_source(src, "_highlight_multiple").contains("_tutorial_card_rect())"),
		"the arrow is handed the card's rectangle to avoid")
	var rect := _function_source(src, "_tutorial_card_rect")
	assert_false(rect.is_empty(), "_tutorial_card_rect was found")
	assert_true(rect.contains("get_combined_minimum_size()")
			and rect.contains("_tutorial_card_position(card_size)"),
		"it is the placement rule applied to the size the card fits its text to")
	assert_true(_function_source(src, "_position_tutorial_panel").contains(
			"_tutorial_panel.position = _tutorial_card_position(_tutorial_panel.size)"),
		"the card itself is placed by that same rule, so the two cannot drift apart")
	assert_true(_function_source(src, "_tutorial_card_position").contains("current_step >= 7"),
		"and the rule still centres the card down the screen from step 7 on")


# ----------------------------------------- the headmaster's beat (grades 8, 9)

## The grade-8 and grade-9 congratulation used to be tutorial steps, tutorial-
## gated, each line wearing a "Kepala Sekolah:" prefix in its body. It is its own
## beat now (HeadmasterBeat), so none of it is left in the tutorial steps, and
## what is left of those grades is the one real instruction.
func test_the_congratulation_is_gone_from_the_tutorial_steps() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var steps := _function_source(src, "_populate_default_tutorial_steps")
	assert_false(steps.is_empty(), "_populate_default_tutorial_steps was found")
	for gone: String in ["Selamat Datang di Kelas", "Selamat atas keberhasilanmu",
			"Tantangan Baru", "Persiapan Ujian Akhir", "Luar biasa", "Kepala Sekolah"]:
		assert_false(steps.contains(gone), "the tutorial steps still carry: " + gone)
	assert_false(src.contains("Narator"), "no speaker prefix is left anywhere in StudentCard")
	assert_false(src.contains("Kepala Sekolah:"), "and no headmaster prefix either")
	assert_contains(steps, "HeadmasterBeat.PICK_STEPS",
		"grades 8 and 9 keep their one instruction step")


func test_the_pick_step_is_one_unprefixed_instruction_per_promotion() -> void:
	var picks: Dictionary = HeadmasterBeat.PICK_STEPS
	var grades: Array = picks.keys()
	grades.sort()
	assert_eq(grades, [8, 9], "Kelas 8 and Kelas 9 each pick new students")
	for grade: int in grades:
		var step: Array = picks[grade]
		assert_eq(step.size(), 4, "title, text, target and prompt, as grade 7's table")
		assert_true(String(step[0]).begins_with("Pilih"), "Kelas %d's step is the pick" % grade)
		assert_false(String(step[1]).begins_with("Narator"), "no speaker prefix on Kelas %d" % grade)
		assert_eq(step[2], "", "it spotlights nothing")
		assert_eq(step[3], "", "and takes the default prompt")


func test_the_beat_holds_the_two_cards_of_each_promotion_with_no_speaker_prefix() -> void:
	var beats: Dictionary = HeadmasterBeat.HEADMASTER_BEATS
	var grades: Array = beats.keys()
	grades.sort()
	assert_eq(grades, [8, 9], "a beat for each grade entered by promotion, none for Kelas 7")
	for grade: int in grades:
		var lines: Array = beats[grade]
		assert_eq(lines.size(), 2, "Kelas %d's beat is a congratulation and a challenge" % grade)
		for line: Dictionary in lines:
			assert_true(String(line["title"]).length() > 0 and String(line["body"]).length() > 0,
				"Kelas %d has an empty card" % grade)
			for field: String in ["title", "body"]:
				assert_false(String(line[field]).contains("Kepala Sekolah"),
					"the name plate names the speaker, not the %s" % field)
				assert_false(String(line[field]).contains("Narator"))
	assert_eq(HeadmasterBeat.SPEAKER, "Pak Kepala Sekolah", "the name plate's line")
	assert_eq(beats[8][0]["title"], "Selamat, naik ke Kelas 8!")
	assert_eq(beats[8][1]["title"], "Tantangan baru")
	assert_eq(beats[9][0]["title"], "Naik ke Kelas 9!")
	assert_eq(beats[9][1]["title"], "Persiapan ujian akhir")


func test_a_beat_is_due_once_per_promotion() -> void:
	assert_true(HeadmasterBeat.is_due(8, {}), "Kelas 8 has a beat, unseen")
	assert_true(HeadmasterBeat.is_due(9, {}), "and so does Kelas 9")
	assert_false(HeadmasterBeat.is_due(7, {}), "nobody is promoted into Kelas 7")
	assert_false(HeadmasterBeat.is_due(8, {8: true}), "a seen grade does not play again (a retry)")
	assert_true(HeadmasterBeat.is_due(9, {8: true}), "seeing Kelas 8's does not spend Kelas 9's")
	assert_false(HeadmasterBeat.is_due(10, {}), "there is no Kelas 10")


## The seat the test hands a beat: the real one is StudentCard's coroutine.
func _seat_nothing() -> void:
	pass


func _beat_panel() -> TutorialPanel:
	var panel: TutorialPanel = (load(_PANEL_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(panel)
	track(panel)
	return panel


func test_the_beat_plays_its_cards_on_the_name_plate_one_tap_at_a_time() -> void:
	var panel := _beat_panel()
	var seen := {}
	var beat := HeadmasterBeat.new()
	beat.start(panel, 8, Callable(self, "_seat_nothing"), seen)
	var lines: Array = HeadmasterBeat.HEADMASTER_BEATS[8]
	assert_true(beat.is_playing(), "taps belong to the beat from start")
	assert_eq(panel.mode, TutorialPanel.Mode.HEADMASTER, "the card wears the name plate")
	assert_eq((panel.get_node(_LAYOUT + "NamePlate/Row/SpeakerLabel") as Label).text, "Pak Kepala Sekolah")
	assert_eq((panel.get_node(_LAYOUT + "TitleLabel") as Label).text, lines[0]["title"])
	assert_eq((panel.get_node(_LAYOUT + "BodyLabel") as Label).text, lines[0]["body"])
	assert_eq((panel.get_node(_LAYOUT + "PromptLabel") as Label).text, HeadmasterBeat.PROMPT)
	assert_false((panel.get_node(_LAYOUT + "StepPill") as Control).visible, "a beat counts no steps")
	assert_eq(panel.modulate.a, 0.0, "the card stays unseen until it is seated and springs in")
	beat.advance()
	assert_eq((panel.get_node(_LAYOUT + "TitleLabel") as Label).text, lines[1]["title"],
		"a tap puts the next card on the same panel")
	assert_true(beat.is_playing())
	beat.advance()
	assert_false(seen.has(8), "the grade is marked seen when the card has left, not before")
	assert_true(beat.is_playing(), "and taps stay the beat's while the last card leaves")
	beat.advance()
	assert_eq((panel.get_node(_LAYOUT + "TitleLabel") as Label).text, lines[1]["title"],
		"a tap while the last card leaves changes nothing")


func test_the_beat_marks_its_grade_seen_then_hands_on() -> void:
	var src := FileAccess.get_file_as_string(_BEAT_PATH)
	var advance := _function_source(src, "advance")
	assert_false(advance.is_empty(), "advance was found")
	var left := advance.find("await _panel.play_out().finished")
	var marked := advance.find("_seen[_grade] = true")
	var done := advance.find("finished.emit()")
	assert_true(left != -1 and marked > left and done > marked,
		"the card leaves, then the grade is marked, then the tutorial is told to go on")


func test_the_beat_never_asks_the_tutorial_toggle() -> void:
	var beat_src := FileAccess.get_file_as_string(_BEAT_PATH)
	assert_false(beat_src.contains("tutorials_bypassed"),
		"the beat is a story every promotion earns, tutorials on or off")
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var trigger := _function_source(src, "_maybe_play_headmaster_beat")
	assert_false(trigger.is_empty(), "_maybe_play_headmaster_beat was found")
	assert_false(trigger.contains("tutorials_bypassed"), "the trigger does not read the toggle")
	assert_contains(trigger, "HeadmasterBeat.is_due(grade, GameState.headmaster_beats_seen)",
		"it reads only the grade and what has been seen")
	assert_eq(src.count("GameState.tutorials_bypassed"), 1,
		"one place reads the toggle: the tutorial's own start")
	assert_contains(_function_source(src, "_begin_tutorial"), "GameState.tutorials_bypassed")


func test_the_beat_comes_first_then_the_tutorial_follows_it() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var on_ready := _function_source(src, "_ready")
	var beat_at := on_ready.find("_maybe_play_headmaster_beat()")
	var tutorial_at := on_ready.find("_begin_tutorial()")
	assert_true(beat_at != -1 and tutorial_at > beat_at,
		"_ready tries the beat first and begins the tutorial only when there is none")
	var trigger := _function_source(src, "_maybe_play_headmaster_beat")
	assert_contains(trigger, "_beat.finished.connect(_begin_tutorial)",
		"when the beat ends the tutorial (or its bypass) begins")
	assert_contains(trigger, "_clear_highlight()", "the beat has no spotlight hole and no arrow")


func test_a_tap_on_the_overlay_belongs_to_the_beat_while_it_plays() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var step := _function_source(src, "_next_step")
	var routed := step.find("_beat.advance()")
	var stepped := step.find("current_step += 1")
	assert_true(routed != -1 and stepped > routed,
		"_next_step hands the tap to the beat before it counts a tutorial step")
	assert_contains(step, "_beat.is_playing()")


func test_the_beat_card_is_centred_down_the_screen() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var where := _function_source(src, "_tutorial_card_position")
	assert_contains(where, "_beat.is_playing()", "the beat's card is centred, with no arrow to make room for")
	assert_contains(where, "current_step >= 7", "and the tutorial's own rule is still there")


# ------------------------------------------ the beat's flag lives on GameState

func test_seen_beats_are_a_session_dictionary_on_game_state() -> void:
	var value: Variant = GameState.headmaster_beats_seen
	assert_true(value is Dictionary, "headmaster_beats_seen is a Dictionary, grade -> true")
	var src := FileAccess.get_file_as_string(_GAME_STATE_PATH)
	assert_contains(src, "var headmaster_beats_seen: Dictionary = {}")


func test_forgetting_the_session_and_starting_a_run_forget_the_seen_beats() -> void:
	var src := FileAccess.get_file_as_string(_GAME_STATE_PATH)
	var forget := _function_source(src, "forget_session")
	assert_false(forget.is_empty(), "forget_session was found")
	assert_contains(forget, "headmaster_beats_seen = {}", "forget_session clears it")
	var run := _function_source(src, "set_grade")
	assert_false(run.is_empty(), "set_grade was found")
	assert_contains(run, "headmaster_beats_seen = {}",
		"set_grade starts a run (new game, level select, a beaten game's restart), so it clears it")


func test_set_grade_clears_the_seen_beats() -> void:
	var saved_grade: int = GameState.current_grade
	var saved_week: int = GameState.minggu_ke
	var saved_seen: Dictionary = GameState.headmaster_beats_seen
	GameState.headmaster_beats_seen = {8: true}
	GameState.set_grade(saved_grade)
	assert_true(GameState.headmaster_beats_seen.is_empty(), "a new run plays its promotions' beats again")
	GameState.headmaster_beats_seen = saved_seen
	GameState.minggu_ke = saved_week


func test_a_retry_of_the_same_grade_does_not_replay_the_beat() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	var progression := _function_source(src, "_apply_progression")
	assert_false(progression.is_empty(), "_apply_progression was found")
	assert_false(progression.contains("headmaster_beats_seen"),
		"a retry (or a promotion) leaves the seen beats alone: once per promotion, per session")
	assert_contains(progression, "GameState.set_grade(FIRST_GRADE)",
		"only a beaten game's restart goes through set_grade, which clears them")


func test_seen_beats_are_never_written_to_disk() -> void:
	var src := FileAccess.get_file_as_string(_GAME_STATE_PATH)
	for func_name: String in ["_write_inventory_to", "_read_inventory_from", "save_inventory",
			"load_inventory", "clear_inventory_save"]:
		var body := _function_source(src, func_name)
		assert_false(body.is_empty(), func_name + " was found")
		assert_false(body.contains("headmaster_beats_seen"), func_name + " must not touch the beats")
	for path: String in ["res://Scripts/GameSettings.gd", "res://Scripts/Achievements/Achievements.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("headmaster_beats_seen"),
			path + " persists; the beats are session-scoped")
