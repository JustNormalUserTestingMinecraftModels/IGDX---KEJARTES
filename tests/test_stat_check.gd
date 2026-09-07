@tool
extends McpTestSuite

## StatCheck (Plan A, 2026-09-04): the automated one-by-one stat check that
## replaced the SemesterEnd card carousel. The sequence itself is a chain
## of coroutines (slides, fills, a white fade), so nothing here plays it --
## these are structural checks on bare instantiate()s plus source scans for
## the wiring, per the runner's no-coroutine rule documented in
## test_lobby.gd. StatCheckRow's non-animated path IS exercised live.

const _ROW_SCENE := "res://Scenes/EndGame/StatCheckRow.tscn"
const _ROW_SCRIPT := "res://Scripts/EndGame/StatCheckRow.gd"
const _STAR_ICON := "res://Assets/Images/UI/Placeholders/icon_star.svg"


func suite_name() -> String:
	return "stat_check"


# ────────────────────────────────────────────────────────────── StatCheckRow

func test_row_scene_loads_and_holds_an_icon_and_a_stat_bar() -> void:
	var row = load(_ROW_SCENE).instantiate()
	track(row)
	assert_true(row is StatCheckRow, "the row wears StatCheckRow.gd")
	assert_true(row.get_node_or_null("Icon") is TextureRect, "Icon node")
	assert_true(row.get_node_or_null("Bar") is StatBar, "Bar is a StatBar")


func test_row_ratio_is_value_over_target_capped_at_100() -> void:
	assert_true(is_equal_approx(StatCheckRow.ratio(30.0, 60.0), 50.0), "half")
	assert_true(is_equal_approx(StatCheckRow.ratio(60.0, 60.0), 100.0), "met")
	assert_true(is_equal_approx(StatCheckRow.ratio(90.0, 60.0), 100.0), "capped")
	assert_true(is_equal_approx(StatCheckRow.ratio(10.0, 0.0), 0.0),
		"a zero target reads as empty, never a divide by zero")


## The meter and the win/lose routing must tell the same story. ratio()
## reaching 100 is what makes a row `cleared`; GameState.target_cleared()
## is what decides the run. They disagreed on a zero target -- the verdict
## counted it cleared while the bar filled to 0% -- so a roster whose
## targets were never initialized could show an empty star meter and still
## route to the win screen.
func test_the_bar_and_the_verdict_agree_on_what_cleared_means() -> void:
	for pair in [[30.0, 60.0], [60.0, 60.0], [90.0, 60.0], [10.0, 0.0],
			[0.0, 0.0], [0.0, 60.0]]:
		var value: float = pair[0]
		var target: float = pair[1]
		assert_eq(is_equal_approx(StatCheckRow.ratio(value, target), 100.0),
			GameState.target_cleared(value, target),
			"value %s vs target %s: a full bar and a cleared target must be "
			% [value, target] + "the same condition")


func test_row_set_result_arms_the_target_without_animating() -> void:
	var row = load(_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	row.set_result(45.0, 60.0)
	assert_true(is_equal_approx(row.get_node("Bar").value, 0.0),
		"set_result leaves the bar empty -- fill() is what moves it")
	assert_true(is_equal_approx(row.target_ratio, 75.0), "the ratio is armed")
	assert_false(row.cleared, "not cleared until a full fill has played")
	Engine.get_main_loop().root.remove_child(row)


## The row's `icon` export has no default, so _ready() used to assign null
## over whatever Icon was authored with in StatCheckRow.tscn. Latent today
## (all three card rows set it), but it silently inverts the project's
## "authored in the .tscn" rule for anyone who instances the row bare.
func test_a_bare_row_keeps_the_icon_authored_in_its_scene() -> void:
	var row = load(_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	assert_true(row.get_node("Icon").texture != null,
		"_ready() must not blank the authored Icon texture")
	Engine.get_main_loop().root.remove_child(row)


func test_row_fill_is_a_coroutine_that_pops_only_at_full() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func fill() -> void:"), "fill() exists")
	assert_true(src.contains("Juice.fill_bar(bar, target_ratio, fill_seconds)"),
		"fill() drives Juice.fill_bar over fill_seconds")
	assert_true(src.contains("if tween == null:"),
		"a null tween is refused -- Juice.fill_bar returns null for a dead "
		+ "node, and awaiting .finished on that is a null deref")
	assert_true(src.contains("if target_ratio >= 100.0:"),
		"the pop is gated on a full bar")
	assert_true(src.contains("filled.emit(cleared)"),
		"fill() reports whether the stat cleared")


func test_row_pop_is_squash_burst_and_sfx() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("AnimUtils.squash_bounce(bar)"), "squash the bar")
	assert_true(src.contains("res://Scenes/SchoolSimulation/RewardBurst.tscn"),
		"instance the authored RewardBurst -- never build particles at runtime")
	assert_true(src.contains("AudioDirector.play_sfx(&\"pop\")"), "the pop cue")


func test_star_placeholder_exists_and_loads_as_a_texture() -> void:
	assert_true(ResourceLoader.exists(_STAR_ICON), "icon_star.svg exists")
	var tex = load(_STAR_ICON)
	assert_true(tex is Texture2D, "it imports as a Texture2D")


## TextureProgressBar draws texture_progress at its NATIVE pixel size and
## does not stretch it to custom_minimum_size. The star cells are 180x180,
## so a 100x100 import would park the art in the top-left corner of each
## cell with 80 px of dead gap between stars. The size lives in the .import
## (svg/scale), which is exactly the kind of step a code review misses --
## so assert the imported result, not the setting.
func test_the_star_texture_is_imported_large_enough_to_fill_its_cell() -> void:
	var tex: Texture2D = load(_STAR_ICON)
	assert_true(tex.get_width() >= 180 and tex.get_height() >= 180,
		"icon_star.svg imports at %dx%d; the 180x180 star cells need at "
		% [tex.get_width(), tex.get_height()]
		+ "least 180 -- raise svg/scale in the .import and reimport")


# ────────────────────────────────────────────────────────────── StatCheckCard

const _CARD_SCENE := "res://Scenes/EndGame/StatCheckCard.tscn"
const _SCENE := "res://Scenes/EndGame/StatCheck.tscn"
const _SCRIPT := "res://Scripts/EndGame/StatCheck.gd"
const _METER_SCRIPT := "res://Scripts/EndGame/StarMeter.gd"


func test_card_scene_has_the_mockup_parts() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	assert_true(card.get_node_or_null("Paper") is Panel, "the paper backing")
	assert_true(card.get_node_or_null("Paper/Header/BioPanel/Bio/Nama") is Label, "Nama")
	assert_true(card.get_node_or_null("Paper/Header/BioPanel/Bio/Profil") is Label, "Profil lines")
	assert_true(card.get_node_or_null("Paper/Header/Portrait") is TextureRect, "Portrait")
	for n in ["Akademis", "Seni", "Olahraga"]:
		assert_true(card.get_node_or_null("Paper/Rows/" + n) is StatCheckRow,
			"%s row is a StatCheckRow" % n)


func test_card_bind_fills_name_profil_portrait_and_arms_three_rows() -> void:
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var s := StudentData.new()
	s.student_name = "Citra"
	s.profil = "Agama: Katolik\nJenis Kelamin: Perempuan"
	s.akademis = 70.0
	s.target_akademis1 = 60.0
	s.seni_budaya = 30.0
	s.target_akademis2 = 60.0
	s.olahraga = 60.0
	s.target_akademis3 = 60.0
	card.bind(s)
	assert_eq(card.get_node("Paper/Header/BioPanel/Bio/Nama").text, "Citra", "name")
	assert_true(card.get_node("Paper/Header/BioPanel/Bio/Profil").text.contains("Jenis Kelamin"),
		"profil lines are shown verbatim")
	var rows: Array = card.rows()
	assert_eq(rows.size(), 3, "three rows, akademis/seni/olahraga")
	assert_true(is_equal_approx(rows[0].target_ratio, 100.0), "akademis 70/60 caps at 100")
	assert_true(is_equal_approx(rows[1].target_ratio, 50.0), "seni 30/60 is half")
	assert_true(is_equal_approx(rows[2].target_ratio, 100.0), "olahraga 60/60 is full")
	Engine.get_main_loop().root.remove_child(card)


func test_card_rows_carry_the_right_categories_and_icons() -> void:
	# rows() reads @onready vars, so the card must be in the tree first.
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var rows: Array = card.rows()
	assert_eq(rows[0].category, "Akademis", "row 0 is Akademis")
	assert_eq(rows[1].category, "SeniBudaya", "row 1 is SeniBudaya")
	assert_eq(rows[2].category, "Olahraga", "row 2 is Olahraga")
	for r in rows:
		assert_true(r.icon != null, "every row has an icon texture")
	Engine.get_main_loop().root.remove_child(card)


# ───────────────────────────────────────────────────────────────── StarMeter

func test_star_meter_maps_a_float_onto_three_star_bars() -> void:
	var screen = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(screen)
	track(screen)
	var meter = screen.get_node("MarginContainer/Column/StarMeter")
	assert_true(meter is StarMeter, "StarMeter script")
	meter.set_stars(1.75)
	assert_true(is_equal_approx(meter.get_node("Star1").value, 100.0), "star 1 full")
	assert_true(is_equal_approx(meter.get_node("Star2").value, 75.0), "star 2 three-quarters")
	assert_true(is_equal_approx(meter.get_node("Star3").value, 0.0), "star 3 empty")
	meter.set_stars(3.0)
	assert_true(is_equal_approx(meter.get_node("Star3").value, 100.0), "3.0 fills the last star")
	meter.set_stars(0.0)
	assert_true(is_equal_approx(meter.get_node("Star1").value, 0.0), "0.0 empties the first")
	Engine.get_main_loop().root.remove_child(screen)


func test_star_meter_bars_use_the_placeholder_star() -> void:
	var screen = load(_SCENE).instantiate()
	track(screen)
	for n in ["Star1", "Star2", "Star3"]:
		var bar = screen.get_node("MarginContainer/Column/StarMeter/" + n)
		assert_true(bar is TextureProgressBar, "%s is a TextureProgressBar" % n)
		assert_true(String(bar.texture_progress.resource_path).ends_with("icon_star.svg"),
			"%s fills with icon_star.svg" % n)
		assert_eq(bar.fill_mode, TextureProgressBar.FILL_LEFT_TO_RIGHT,
			"%s fills left to right" % n)


# ───────────────────────────────────────────────────────────────── StatCheck

func test_scene_loads_with_its_chrome() -> void:
	var screen = load(_SCENE).instantiate()
	track(screen)
	assert_true(screen.get_node_or_null("Backdrop") is TextureRect, "Backdrop")
	assert_true(screen.get_node_or_null("Scrim") is Panel, "Scrim")
	assert_true(screen.get_node_or_null("MarginContainer/Column/CardSlot") is Control,
		"CardSlot, where each student's card is instanced")
	assert_true(screen.get_node_or_null("MarginContainer/Column/StarMeter") is StarMeter,
		"StarMeter")
	var white = screen.get_node_or_null("WhiteFade")
	assert_true(white is ColorRect, "the white fade overlay")
	assert_true(is_equal_approx(white.color.a, 1.0) and white.modulate.a == 0.0,
		"WhiteFade is opaque white, fully transparent via modulate until the end")


func test_star_share_is_one_over_total_stats_scaled_to_three() -> void:
	assert_true(is_equal_approx(StatCheck.star_share(12), 0.25), "4 students: 0.25 per stat")
	assert_true(is_equal_approx(StatCheck.star_share(6), 0.5), "2 students: 0.5 per stat")
	assert_true(is_equal_approx(StatCheck.star_share(0), 0.0), "no stats: nothing to share")


func test_the_sequence_slides_fills_in_order_and_awaits_each_beat() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _run_check() -> void:"), "the sequence coroutine")
	var slide_at := src.find("await _slide_in(card)")
	var fill_at := src.find("await row.fill()")
	var slide_out_at := src.find("await _slide_out(card)")
	assert_true(slide_at != -1 and fill_at != -1 and slide_out_at != -1,
		"slide in, fill, slide out are all awaited")
	assert_true(slide_at < fill_at and fill_at < slide_out_at,
		"a card slides in, its rows fill, then it slides out -- in that order")
	assert_true(src.contains("for row in card.rows():"),
		"rows fill in card order: akademis, seni budaya, olahraga")


func test_every_cleared_stat_adds_one_share_to_the_meter() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("_stars += star_share(_total_stats)"),
		"a cleared stat adds exactly one share")
	assert_true(src.contains("star_meter.animate_to(_stars)"),
		"the meter animates to the running total after each clear")
	assert_true(src.contains("if row.cleared:"),
		"only a cleared row moves the meter -- a partial fill adds nothing")


func test_it_ends_on_a_white_fade_then_hands_off_by_verdict() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("tween_property(white_fade, \"modulate:a\", 1.0, white_fade_seconds)"),
		"the white overlay fades in over white_fade_seconds")
	assert_true(src.contains("GameState.run_failed = not GameState.check_semester_passed()"),
		"the verdict is written to GameState before leaving")
	assert_true(src.contains("NEXT_SCENE_WIN if not GameState.run_failed else NEXT_SCENE_LOSE"),
		"win and lose have separate destinations")
	assert_true(src.contains("get_tree().change_scene_to_file("),
		"the hand-off bypasses Transition, whose cover is brand blue and would flash over the white")
	assert_false(src.contains("Transition.change_scene"),
		"no Transition wipe on the way out")


func test_it_keeps_the_exam_bgm_and_never_reads_the_cutscene_flag() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("play_bgm(&\"exam_notice\")"),
		"continuity with TesNotice/ExamProgress; result BGM belongs to Plan B's screens")
	assert_false(src.contains("is_exam_intro_cutscene"), "the flag is gone")


func test_hand_off_targets_the_end_cutscene_for_both_verdicts() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const NEXT_SCENE_WIN := \"res://Scenes/EndGame/EndCutscene.tscn\""),
		"a win lands on the end cutscene")
	assert_true(src.contains("const NEXT_SCENE_LOSE := \"res://Scenes/EndGame/EndCutscene.tscn\""),
		"so does a loss -- one scene dresses itself from GameState.run_failed")
	assert_true(ResourceLoader.exists("res://Scenes/EndGame/EndCutscene.tscn"),
		"the destination exists")
