@tool
extends McpTestSuite

## Pins the 2026-09-30 minigame hierarchy pass (spec
## docs/superpowers/specs/2026-09-30-minigame-hierarchy-design.md): the x1.618
## minigame type ladder, the one-row plaque, the 48 px edge and 72 px tray gap,
## cards sized to their controls, and bugs B1-B6. Scenes whose scripts are not
## @tool are stood up with LayoutFrame and read for their authored layout only.
## Must be @tool; no test here may be a coroutine (the runner never awaits).

const LayoutFrame := preload("res://tests/layout_frame.gd")
const SoalFit := preload("res://Scripts/Minigames/Akademis/SoalFit.gd")
const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## The house screen margin every minigame's SafeAreaMargin applies.
const EDGE := 48.0
## Field content to the tray's top (spec 4).
const TRAY_GAP := 72.0


func suite_name() -> String:
	return "minigame_hierarchy"


func _stand(path: String, screen: Vector2) -> Node:
	return (track(LayoutFrame.stand_up(path, screen)) as Control).get_child(0)


# ---------------------------------------------------------------- ladder

func test_the_ladder_steps_by_the_golden_ratio() -> void:
	assert_eq(MinigameType.LADDER, [28, 45, 73, 118], "the four rungs")
	for i in range(1, MinigameType.LADDER.size()):
		var r := float(MinigameType.LADDER[i]) / float(MinigameType.LADDER[i - 1])
		assert_true(r >= 1.60 and r <= 1.64, "rung %d steps x%.3f" % [i, r])


## Every text role in spec 3, with its rung.
func _role_sizes() -> Dictionary:
	return {
		"MinigameQuestionLabel": MinigameType.T3, "MinigameHudValue": MinigameType.T3,
		"MinigameKeyLabel": MinigameType.T3, "MinigameLcdLabel": MinigameType.T4,
		"MinigameChoiceButton": MinigameType.T2, "MinigameChoiceButtonCorrect": MinigameType.T2,
		"MinigameChoiceButtonWrong": MinigameType.T2, "MinigameCtaButton": MinigameType.T2,
		"MinigameSecondaryButton": MinigameType.T2, "MinigameTimerLabel": MinigameType.T2,
		"MinigameToolNameLabel": MinigameType.T2, "MinigameHintLabel": MinigameType.T1,
		"MinigameTargetLabel": MinigameType.T1, "MinigameProgressLabel": MinigameType.T1,
		"MinigamePlankLabel": MinigameType.T1, "MinigameBadgeLabel": MinigameType.T1,
	}


func test_every_role_is_baked_on_its_rung() -> void:
	var theme := load(THEME_PATH) as Theme
	var sizes := _role_sizes()
	for name: String in sizes:
		assert_true(theme.has_font_size("font_size", name), name + " carries a size")
		assert_eq(theme.get_font_size("font_size", name), sizes[name], name + " rung")


func test_the_state_flashes_keep_their_colour_when_disabled() -> void:
	var theme := load(THEME_PATH) as Theme
	for name in ["MinigameChoiceButtonCorrect", "MinigameChoiceButtonWrong"]:
		var rest := theme.get_stylebox("normal", name) as StyleBoxFlat
		var off := theme.get_stylebox("disabled", name) as StyleBoxFlat
		assert_true(rest != null and off != null, name + " has flat boxes")
		if rest == null or off == null:
			continue
		assert_true(rest.bg_color.is_equal_approx(off.bg_color),
			name + ": an answered (disabled) button still shows the flash")


func test_the_new_panels_exist() -> void:
	var theme := load(THEME_PATH) as Theme
	for name in ["MinigameAnswerCard", "MinigameCardLock", "MinigameBadgePanel",
			"MinigameToolCard", "MinigameToolRing"]:
		assert_true(theme.has_stylebox("panel", name), name + " is baked")


# ----------------------------------------------------------------- plaque

const HEADER := "res://Scenes/Minigames/UI/MinigameHeader.tscn"


func _header() -> MinigameHeader:
	return _stand(HEADER, Vector2(1080, 1920)) as MinigameHeader


func test_the_header_is_one_row_with_the_bar_inside_the_plaque() -> void:
	var header := _header()
	assert_true(header.get_node_or_null("Stack") == null, "no second row")
	var hud := header.get_node("%ScoreHud") as MinigameScoreHUD
	assert_true(hud.get_node_or_null("Panel/Stack/ProgressLine/ProgressBar") != null,
		"the progress bar lives in the plaque")
	assert_eq((hud.get_node("Panel") as Control).theme_type_variation, &"MinigameHudPill")


func test_the_plaque_fits_the_strip() -> void:
	var header := _header()
	var plaque := (header.get_node("%ScoreHud") as Control).get_node("Panel") as Control
	assert_true(header.get_global_rect().grow(0.5).encloses(plaque.get_global_rect()),
		"the plaque %s stays inside the one-row strip %s"
			% [plaque.get_global_rect(), header.get_global_rect()])


func test_the_timer_shows_whole_seconds_rounded_up() -> void:
	var header := _header()
	header.set_time(17.2, 30.0)
	assert_eq((header.get_node("%TimerLabel") as Label).text, "18")


func test_short_counts_draw_segments_and_long_ones_a_bar() -> void:
	var header := _header()
	var hud := header.get_node("%ScoreHud") as MinigameScoreHUD
	header.set_progress(1, 4, "Langkah 2/4")
	assert_eq(hud.ticks.segments, 4, "four steps, four cells")
	header.set_progress(3, 12, "Soal 4/12")
	assert_eq(hud.ticks.segments, 0, "past SEGMENT_MAX the bar is continuous")
	assert_eq(hud.progress_label.text, "Soal 4/12")


func test_hiding_the_score_keeps_the_bar() -> void:
	var header := _header()
	header.show_score = false
	var hud := header.get_node("%ScoreHud") as MinigameScoreHUD
	assert_false((hud.get_node("Panel/Stack/Row") as Control).visible, "score line hidden")
	assert_true(hud.progress_bar.is_visible_in_tree(), "the bar still shows")


# ------------------------------------------------------------------ cards

const QUESTION_CARD := "res://Scenes/Minigames/Akademis/QuestionCard.tscn"
const ANSWER_CARD := "res://Scenes/Minigames/Akademis/AnswerCard.tscn"


func test_the_cards_wear_the_kit_not_hand_made_boxes() -> void:
	for path in [QUESTION_CARD, ANSWER_CARD]:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("theme_override_styles"), path + " has no stylebox override")
		assert_false(src.contains("StyleBoxFlat"), path + " authors no box")
	var q := FileAccess.get_file_as_string(QUESTION_CARD)
	for v in ["MinigameCard", "MinigameCardInner", "MinigameBadgePanel", "MinigameCardLock"]:
		assert_true(q.contains('&"%s"' % v), "QuestionCard wears " + v)
	var a := FileAccess.get_file_as_string(ANSWER_CARD)
	for v in ["MinigameAnswerCard", "MinigameCardLock"]:
		assert_true(a.contains('&"%s"' % v), "AnswerCard wears " + v)


# ------------------------------------------------------ edge, PilihanGanda

const PILIHAN := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"


func test_pilihan_ganda_keeps_one_edge_and_the_tray_gap() -> void:
	for screen: Vector2 in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var root := _stand(PILIHAN, screen)
		var card := (root.get_node("%SoalCard") as Control).get_global_rect()
		var tray := (root.get_node("%MinigameTray") as Control).get_global_rect()
		var grid := (root.get_node("%ChoicesGrid") as Control).get_global_rect()
		assert_true(absf(card.position.x - EDGE) <= 1.0, "card starts at the edge %s" % card)
		assert_true(absf(screen.x - card.end.x - EDGE) <= 1.0, "card ends at the edge %s" % card)
		assert_true(absf(grid.position.x - EDGE) <= 1.0, "answers start at the edge %s" % grid)
		assert_true(absf(tray.position.y - card.end.y - TRAY_GAP) <= 1.0,
			"72 px between the card and the tray at %s (card %s, tray %s)" % [screen, card, tray])


func test_a_short_question_fits_at_the_hero_rung() -> void:
	var label := Label.new()
	label.theme = load(THEME_PATH)
	label.theme_type_variation = &"MinigameQuestionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(912, 400)
	track(label)
	assert_eq(SoalFit.font_size(label, null,
		"Apa nama ibu kota negara Indonesia saat ini?", MinigameType.T3, MinigameType.T2),
		MinigameType.T3, "B1: a laid-out card fits the question at 73")


func test_pilihan_ganda_refits_once_laid_out_and_styles_through_the_theme() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_true(src.contains("resized.connect(_refit_question)"),
		"B1: the question refits after layout, not against a pre-layout size")
	assert_false(src.contains("add_theme_stylebox_override"), "B2: no stylebox overrides")
	for v in ["MinigameChoiceButtonCorrect", "MinigameChoiceButtonWrong"]:
		assert_true(src.contains(v), "the flash is the %s variation" % v)
	assert_false(FileAccess.get_file_as_string(PILIHAN).contains("StyleBoxFlat"),
		"B2: the blue boxes are gone")


# ------------------------------------------------------------- calculator

const KALK := "res://Scenes/Minigames/Akademis/Kalkulator.tscn"
const KalkScript := preload("res://Scripts/Minigames/Akademis/Kalkulator.gd")


func _kalk(zero: bool) -> Control:
	var k := _stand(KALK, Vector2(860, 1184)) as Control
	k.set("show_zero_key", zero)
	LayoutFrame.settle(k)
	return k


## `r` as fractions of `body`'s rect.
func _frac(r: Rect2, body: Rect2) -> Rect2:
	return Rect2((r.position - body.position) / body.size, r.size / body.size)


func test_the_keypad_is_centred_on_the_painted_face() -> void:
	var k := _kalk(true)
	var body := (k.get_node("Body") as Control).get_global_rect()
	var keys := (k.get_node("Body/KeyGrid") as Control).get_global_rect().merge(
		(k.get_node("Body/ZeroRow") as Control).get_global_rect())
	var f := _frac(keys, body)
	var face: Rect2 = KalkScript.FACE_RECT
	assert_true(absf(f.get_center().x - face.get_center().x) <= 0.01,
		"B3: keys centred on the face (%.4f vs %.4f)" % [f.get_center().x, face.get_center().x])
	assert_true(face.encloses(f), "B3: the keys %s stay on the face %s" % [f, face])
	var glass: Rect2 = KalkScript.GLASS_RECT
	var lcd := _frac((k.get_node("Body/Layar") as Control).get_global_rect(), body)
	assert_true(glass.grow(0.002).encloses(lcd), "B3: the display %s stays on the glass" % lcd)


func test_without_zero_the_grid_takes_its_row() -> void:
	var k := _kalk(false)
	var body := (k.get_node("Body") as Control).get_global_rect()
	var grid := _frac((k.get_node("Body/KeyGrid") as Control).get_global_rect(), body)
	assert_true(absf(grid.end.y - KalkScript.KEYPAD_BOTTOM) <= 0.005,
		"Variabel's three rows reach the keypad's bottom (%.4f)" % grid.end.y)


func test_the_card_follows_the_calculator_width() -> void:
	var k := _kalk(true)
	var card := Control.new()
	track(card)
	k.call("follow_width", card)
	assert_eq(card.custom_minimum_size.x, (k.get_node("Body") as Control).size.x)


func test_the_calculator_games_use_the_minigame_buttons_and_ladder() -> void:
	for game in ["Password", "Variabel"]:
		var scene := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/%s.tscn" % game)
		assert_true(scene.contains('&"MinigameCtaButton"'), game + ": Kirim is the minigame CTA")
		assert_true(scene.contains('&"MinigameSecondaryButton"'), game + ": Hapus is brown")
		var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/%s.gd" % game)
		assert_true(src.contains("follow_width("), game + ": the card follows the calculator")
		assert_true(src.contains("MinigameType.T2"), game + ": fits never drop below T2")


# ------------------------------------------------------------ Menjodohkan

const MJ := "res://Scenes/Minigames/Akademis/Menjodohkan.tscn"
const MJ_GD := "res://Scripts/Minigames/Akademis/Menjodohkan.gd"


func test_menjodohkan_arrows_ride_the_edge_lanes_beside_the_cards() -> void:
	var root := _stand(MJ, Vector2(1080, 1920))
	for path in ["Safe/Column/TopCarousel/BtnPrevQ",
			"Safe/Column/MinigameTray/BottomCarousel/BtnPrevA"]:
		var b := root.get_node(path) as Button
		assert_eq(b.theme_type_variation, &"WoodNavArrow", path)
		assert_true(absf(b.get_global_rect().position.x - EDGE) <= 1.0,
			path + " at the edge: %s" % b.get_global_rect())
	for plank in ["Safe/Column/TopCarousel/SoalPlank",
			"Safe/Column/MinigameTray/BottomCarousel/JawabanPlank"]:
		assert_eq((root.get_node(plank) as Control).theme_type_variation, &"MinigamePlankPanel")
	# The script is not @tool, so read its export default from source: the
	# cards fill the space between the arrow lanes, 28 clear of each.
	var lanes := 1080.0 - 2.0 * (EDGE + 96.0 + 28.0)
	assert_true(FileAccess.get_file_as_string(MJ_GD).contains(
		"@export var card_width: float = %.1f" % lanes), "card_width is %.1f" % lanes)


func test_menjodohkan_drops_its_dead_style_exports() -> void:
	var src := FileAccess.get_file_as_string(MJ_GD)
	for gone in ["nav_btn_style", "submit_btn_active_style", "submit_btn_disabled_style",
			"correct_color", "wrong_color"]:
		assert_false(src.contains(gone), "B6: %s is gone" % gone)
	assert_true(src.contains("MinigameType.T3") and src.contains("MinigameType.T2"),
		"tile text fits T3 down to T2")


# -------------------------------------------------------------- BuatBatik

const BATIK := "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"


func test_batik_tools_are_cream_named_and_ringed() -> void:
	var root := _stand(BATIK, Vector2(1080, 1920))
	var names := ["Pensil", "Canting", "Pewarna", "Kompor"]
	for i in 4:
		var slot := root.get_node("Safe/Column/MinigameTray/ToolsContainer/Tool%d" % i)
		assert_eq((slot.get_node("Bg") as Control).theme_type_variation, &"MinigameToolCard")
		var label := slot.get_node_or_null("NameLabel") as Label
		assert_true(label != null, "Tool%d has a NameLabel" % i)
		if label == null:
			continue
		assert_eq(label.theme_type_variation, &"MinigameToolNameLabel")
		assert_eq(label.text, names[i], "B4: Tool%d shows its name" % i)
		assert_eq((slot.get_node("Ring") as Control).theme_type_variation, &"MinigameToolRing")
	assert_false(FileAccess.get_file_as_string(BATIK).contains(
		"Color(0.2, 0.5019608, 0.8509804, 1)"), "B2: no blue rim")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/SeniBudaya/BuatBatik.gd")
	assert_true(src.contains('tool0_display_name: String = "Pensil"'), "Indonesian name")
	assert_true(src.contains("_ring_next_tool("), "the ring follows the next step")


# -------------------------------------------------------------- Badminton

const BADMINTON := "res://Scenes/Minigames/Olahraga/Badminton.tscn"
## The painted bottom baseline's last row in lapanganBadminton.jpg (1080x1920),
## measured 2026-09-30.
const COURT_BASELINE_ROW := 1794.0


func test_the_court_baseline_clears_the_hint_pill() -> void:
	for screen: Vector2 in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var root := _stand(BADMINTON, screen)
		var bg := root.get_node("Background") as TextureRect
		var r := bg.get_global_rect()
		var tex := bg.texture.get_size()
		var s := maxf(r.size.x / tex.x, r.size.y / tex.y)
		var baseline := r.position.y + (r.size.y - tex.y * s) / 2.0 + COURT_BASELINE_ROW * s
		var pill := (root.get_node("%MinigameHintPill") as Control).get_global_rect()
		assert_true(baseline <= pill.position.y - 16.0,
			"B5: baseline %.0f vs pill top %.0f at %s" % [baseline, pill.position.y, screen])
		var surround := bg.get_node_or_null("Surround") as Control
		assert_true(surround != null and surround.show_behind_parent
			and surround.get_global_rect().end.y >= screen.y,
			"the uncovered strip is filled to the screen bottom")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Olahraga/Badminton.gd")
	assert_true(src.contains('"Capai %d poin"'), "one score: the bar names the goal")
