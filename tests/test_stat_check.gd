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
	assert_true(src.contains("if _fill_tween == null:"),
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


## A rush must SPEED UP the live tween, never kill it. Tween.kill() does
## not emit finished, so killing the tween StatCheck is awaiting would hang
## the sequence forever -- the screen would sit on a half-filled bar with
## no way forward. This is a source scan because the alternative is a
## coroutine, and no test here may await.
func test_row_rush_speeds_the_tween_rather_than_killing_it() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func rush() -> void:"), "a row can be rushed")
	assert_true(src.contains("set_speed_scale("),
		"the rush speed-scales the live tween")
	assert_false(src.contains(".kill()"),
		"it must never kill the tween -- kill() does not emit finished, " +
		"so the pending await would never resume")


func test_row_keeps_its_fill_tween_so_it_can_be_rushed() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("_fill_tween"),
		"the fill tween is held on the row, not a local")
	assert_true(src.contains("const RUSH_SPEED"),
		"the rush multiplier is a named const, not an inline literal")


## rush() must be safe before anything is in flight -- a tap during the
## card's slide-in reaches it with no fill tween yet. It should leave the
## row exactly as set_result() armed it, not quietly complete the fill.
func test_rushing_an_idle_row_leaves_it_armed_but_unmoved() -> void:
	var row = load(_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	row.set_result(45.0, 60.0)
	row.rush()
	assert_true(is_equal_approx(row.get_node("Bar").value, 0.0),
		"rushing before fill() started does not move the bar")
	assert_true(is_equal_approx(row.target_ratio, 75.0), "the armed ratio survives")
	assert_false(row.cleared, "and the row is not marked cleared")
	Engine.get_main_loop().root.remove_child(row)


## The bug this guards: rush() used to only speed-scale a LIVE _fill_tween,
## so a tap landing before fill() had ever run on this row -- e.g. row 1 or
## 2 while row 0 is still filling -- hit the null guard, no-op'd, and was
## silently dropped. The row then played its full-length fill anyway. A
## rush must stick so a not-yet-started fill begins already rushed.
func test_rushing_a_row_before_its_fill_starts_still_rushes_it() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("var _rushed: bool = false"),
		"the row remembers a rush across the gap before fill() exists")
	var rush_at := src.find("func rush() -> void:")
	var set_flag_at := src.find("_rushed = true", rush_at)
	var speed_scale_at := src.find("_fill_tween.set_speed_scale(RUSH_SPEED)", rush_at)
	assert_true(rush_at != -1 and set_flag_at != -1 and speed_scale_at != -1,
		"rush() both sets the flag and speed-scales a live tween")
	assert_true(set_flag_at < speed_scale_at,
		"the flag is set first, so it survives even when the live-tween "
		+ "branch below it does not apply")
	var fill_at := src.find("func fill() -> void:")
	var null_check_at := src.find("if _fill_tween == null:", fill_at)
	var rushed_check_at := src.find("if _rushed:", fill_at)
	assert_true(fill_at != -1 and null_check_at != -1 and rushed_check_at != -1,
		"fill() consults the flag right after creating its own tween")
	assert_true(null_check_at < rushed_check_at,
		"the dead-node guard runs first, so a freed row is never speed-scaled")


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


const _CARD_SCRIPT := "res://Scripts/EndGame/StatCheckCard.gd"
const _PAPER_ART := "res://Assets/Images/StudentCard/card_bg.png"
const _SHADOW_SCENE := "res://Scenes/UI/PaperShadow.tscn"
const _ICON_DIR := "res://Assets/Images/StudentCard/"

## card_bg.png is 1080x1920 but paper only across this rect (alpha > 200,
## measured 2026-09-11); everything outside is transparent. The card must be
## filled by the SHEET, not by the texture's empty margin.
const _SHEET := Rect2(52, 238, 994, 1321)
## The frame printed on card_bg.png -- StudentCard's own PortraitFrame rect.
const _PHOTO_RECT := Rect2(136, 294, 283, 376)
## The six students the game ships. Kept here rather than read from
## student_card.gd, whose roster is a script variable, not a constant.
const _ROSTER := ["Marcel", "Doni", "Andi", "Citra", "Shinta", "Thea"]
## The art StudentCard, StudentList and AturJadwal already use for the
## three skills -- not the placeholder SVGs the page shipped with.
const _STAT_ICONS := {
	"Akademis": "stat_akademis.png",
	"SeniBudaya": "stat_senibudaya.png",
	"Olahraga": "stat_olahraga.png",
}


func test_card_is_studentcards_paper() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var paper = card.get_node_or_null("Paper")
	assert_true(paper is TextureRect, "the page is a TextureRect, not a themed panel")
	assert_eq(String(paper.texture.resource_path), _PAPER_ART,
		"the same paper StudentCard draws")
	var shadow = card.get_node_or_null("Paper/PaperShadow")
	assert_true(shadow != null, "the paper casts StudentCard's shadow")
	assert_eq(shadow.scene_file_path, _SHADOW_SCENE,
		"instanced from PaperShadow.tscn, not rebuilt")
	assert_true(card.get_node_or_null("Paper/Header") == null,
		"the old bio-panel header is gone")


## Mapped through the paper's own offsets and scale, the measured sheet must
## sit inside the 760x1000 card and fill its height -- lay out against the
## alpha, not the texture rect (CLAUDE.md's paper.png lesson).
func test_the_paper_sheet_fills_the_card() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var paper: TextureRect = card.get_node("Paper")
	assert_true(is_equal_approx(paper.scale.x, paper.scale.y),
		"the paper is scaled uniformly, so the art is not distorted")
	var origin := Vector2(paper.offset_left, paper.offset_top)
	var top_left := origin + _SHEET.position * paper.scale
	var bottom_right := origin + _SHEET.end * paper.scale
	var card_size: Vector2 = card.custom_minimum_size
	assert_true(top_left.x >= -1.0 and top_left.y >= -1.0,
		"the sheet's top-left %s stays inside the card" % top_left)
	assert_true(bottom_right.x <= card_size.x + 1.0 and bottom_right.y <= card_size.y + 1.0,
		"the sheet's bottom-right %s stays inside %s" % [bottom_right, card_size])
	assert_true(bottom_right.y - top_left.y >= card_size.y - 2.0,
		"and the sheet fills the card's height")


func test_the_photo_and_name_sit_on_the_printed_frame_and_plate() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	for n in ["Photo", "PortraitFrame"]:
		var r: TextureRect = card.get_node_or_null("Paper/" + n)
		assert_true(r != null, n + " exists")
		var rect := Rect2(r.offset_left, r.offset_top,
			r.offset_right - r.offset_left, r.offset_bottom - r.offset_top)
		assert_eq(rect, _PHOTO_RECT, n + " covers the printed photo frame")
	assert_eq(String(card.get_node("Paper/PortraitFrame").texture.resource_path),
		"res://Assets/Images/StudentCard/portrait_frame.png", "StudentCard's frame art")
	var name_label: Label = card.get_node_or_null("Paper/Name")
	assert_true(name_label != null, "a Name label")
	var plate: Rect2 = StudentCardView.BIO_PANEL_RECT
	var name_rect := Rect2(name_label.offset_left, name_label.offset_top,
		name_label.offset_right - name_label.offset_left,
		name_label.offset_bottom - name_label.offset_top)
	assert_true(plate.encloses(name_rect), "Name %s sits on the plate %s" % [name_rect, plate])
	assert_eq(String(name_label.theme_type_variation), "PlateNameLabel",
		"cream display text for the brown plate")
	for n in ["Akademis", "Seni", "Olahraga"]:
		assert_true(card.get_node_or_null("Paper/Rows/" + n) is StatCheckRow,
			"%s row is a StatCheckRow" % n)


## "Put only the student name": nothing from the bio file but the name.
func test_the_name_is_the_only_text_on_the_page() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var labels: Array = card.find_children("*", "Label", true, false)
	assert_eq(labels.size(), 1, "one Label on the page: %s" % str(labels))
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	assert_false(src.contains("profil"),
		"StatCheckCard never shows the Agama / Jenis Kelamin lines")


func test_card_bind_fills_name_and_photo_and_arms_three_rows() -> void:
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var photo: Texture2D = load("res://Assets/Images/MuridPotrait/Murid3.jpg")
	var s := StudentData.new()
	s.student_name = "Citra"
	s.avatar_texture = photo
	s.akademis = 70.0
	s.target_akademis1 = 60.0
	s.seni_budaya = 30.0
	s.target_akademis2 = 60.0
	s.olahraga = 60.0
	s.target_akademis3 = 60.0
	card.bind(s)
	assert_eq(card.get_node("Paper/Name").text, "Citra", "the name lands on the plate")
	assert_true(card.get_node("Paper/Photo").texture == photo, "the photo lands in the frame")
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
		assert_eq(String(r.icon.resource_path), _ICON_DIR + _STAT_ICONS[r.category],
			"%s wears the game's own stat icon" % r.category)
	Engine.get_main_loop().root.remove_child(card)


## Every roster name has to fit the plate at the label's real font and size.
## The widest, MARCEL, measured ~413px in Boohong at 96 against a 457px slot
## on 2026-09-11 -- close enough that a size bump would clip it on screen
## while every structural test stayed green.
func test_every_roster_name_fits_on_the_plate() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var font: Font = theme.get_font("font", "PlateNameLabel")
	var size: int = theme.get_font_size("font_size", "PlateNameLabel")
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var label: Label = card.get_node("Paper/Name")
	var slot := label.offset_right - label.offset_left
	for student_name in _ROSTER:
		var text: String = student_name.to_upper() if label.uppercase else student_name
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		assert_true(width <= slot,
			"%s is %.0fpx at %dpx; the plate's Name slot is %.0fpx" % [text, width, size, slot])


## StudentCard's proportions: a 128px icon beside a 68px-tall bar.
func test_row_matches_studentcards_proportions() -> void:
	var row = load(_ROW_SCENE).instantiate()
	track(row)
	var icon: TextureRect = row.get_node("Icon")
	assert_eq(icon.custom_minimum_size, Vector2(128, 128), "a 128px icon, like StudentCard's")
	assert_eq(String(icon.texture.resource_path), _ICON_DIR + "stat_akademis.png",
		"a bare row shows the real akademis art")
	assert_eq(row.get_node("Bar").custom_minimum_size.y, 68.0, "StudentCard's pill height")


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


func test_star_meter_can_be_rushed() -> void:
	var src := FileAccess.get_file_as_string(_METER_SCRIPT)
	assert_true(src.contains("func rush() -> void:"), "the meter can be rushed")
	assert_true(src.contains("set_speed_scale("), "by speed-scaling its tween")
	assert_true(src.contains("const RUSH_SPEED"), "with a named multiplier")


## rush() must be safe before animate_to() has ever run -- the first tap can
## land before any stat has cleared. It should leave the rendered value
## alone rather than snapping the meter somewhere.
func test_rushing_an_idle_meter_leaves_the_stars_where_they_are() -> void:
	var screen = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(screen)
	track(screen)
	var meter = screen.get_node("MarginContainer/Column/StarMeter")
	meter.set_stars(1.5)
	meter.rush()
	assert_true(is_equal_approx(meter.get_node("Star1").value, 100.0),
		"the first star stays full after an idle rush")
	assert_true(is_equal_approx(meter.get_node("Star2").value, 50.0),
		"the second stays half")
	Engine.get_main_loop().root.remove_child(screen)


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


func test_a_tap_rushes_the_current_student() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _input("),
		"the screen listens for a tap via _input, not _unhandled_input -- "
		+ "the full-screen Scrim Panel defaults to MOUSE_FILTER_STOP and would "
		+ "consume the event first")
	assert_false(src.contains("_unhandled_input"),
		"must never revert to _unhandled_input -- the covering Panels would "
		+ "swallow the event before it got there")
	assert_true(src.contains("InputEventScreenTouch"), "touch on device")
	assert_true(src.contains("InputEventMouseButton"), "and click in the editor")
	assert_true(src.contains("func _rush_current_student()"), "the rush entry point")


## The rush is scoped to one student: the flag resets as each card starts,
## so a tap on student 2 never carries into student 3.
func test_the_rush_flag_resets_per_student() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var loop_at := src.find("for student in students:")
	var reset_at := src.find("_rushing = false", loop_at)
	var slide_at := src.find("await _slide_in(card)", loop_at)
	assert_true(loop_at != -1 and reset_at != -1 and slide_at != -1,
		"the loop resets the rush flag")
	assert_true(reset_at < slide_at,
		"the flag clears before the card animates, so each student starts unrushed")


## The holds must be tweens, not SceneTreeTimers. A SceneTreeTimer cannot
## be sped up, so a timer-based hold would ignore the tap and stall the
## rush for its full duration.
func test_the_holds_are_tween_based_so_they_can_be_rushed() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _hold("), "holds go through one helper")
	assert_true(src.contains("tween_interval("), "which is a tween, not a timer")
	assert_false(src.contains("create_timer(hold_seconds)"),
		"no SceneTreeTimer hold survives -- it could not be rushed")


## The bug this guards: _hold() used to be sped up only via whatever tap
## landed on _live_tween at that instant, never by checking _rushing
## itself -- so the entry hold (between the slide-in and row 0's fill)
## always played at full length even though a tap had already set
## _rushing true. A tap must not leave the player waiting out that pause.
func test_the_entry_hold_is_rushed_by_a_tap() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var hold_at := src.find("func _hold(")
	var interval_at := src.find("tween_interval(", hold_at)
	var rushing_check_at := src.find("if _rushing:", hold_at)
	var speed_scale_at := src.find("tw.set_speed_scale(RUSH_SPEED)", hold_at)
	assert_true(hold_at != -1 and interval_at != -1 and rushing_check_at != -1
		and speed_scale_at != -1,
		"_hold() checks _rushing and speed-scales its own tween when it is set")
	assert_true(interval_at < rushing_check_at,
		"the check comes after the interval is armed")
	assert_true(rushing_check_at < speed_scale_at,
		"and immediately drives the speed-scale, before the await")


## Rushing must not fire three tally cues inside one frame; they would
## overlap into a click rather than reading as three clears.
func test_a_rushed_student_plays_one_tally_not_three() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("if not _rushing:"),
		"the per-row cue is suppressed while rushing")


## The trailing hold and the slide-out are deliberately NOT rushed by the
## first tap: the point is to reach the numbers sooner, not to hide them.
func test_the_first_tap_leaves_the_read_beat_intact() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var rows_at := src.find("for row in card.rows():")
	var clear_at := src.find("_rushing = false", rows_at)
	var slide_out_at := src.find("await _slide_out(card)", rows_at)
	assert_true(clear_at != -1 and slide_out_at != -1 and clear_at < slide_out_at,
		"the rush is stood down before the trailing hold, so it plays in full")


func test_the_header_no_longer_claims_the_screen_is_not_tap_driven() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_false(src.contains("Deliberately NOT tap-driven"),
		"the old decision is superseded")
	assert_true(src.contains("tap"),
		"and the header explains the tap that replaced it")
