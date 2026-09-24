@tool
extends McpTestSuite

## The daily result's reward layer (2026-09-24 SchoolDay liveliness pass,
## mockup section 3): DayVerdict's star rule, tally and Bintang Hari Ini, and
## the popup nodes that show them.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.

const POPUP_SCENE := "res://Scenes/SchoolSimulation/DaySummaryPopup.tscn"


func suite_name() -> String:
	return "day_verdict"


func _student(name: String, akademis: float, target: float) -> StudentData:
	var s := StudentData.new()
	s.student_name = name
	s.akademis = akademis
	s.target_akademis1 = target
	s.seni_budaya = 10.0
	s.target_akademis2 = 90.0
	s.olahraga = 10.0
	s.target_akademis3 = 90.0
	return s


func _entry(name: String, changes: Array) -> Dictionary:
	var out: Array = []
	for c in changes:
		out.append({"stat_key": c[0], "delta": c[1], "source": "activity"})
	return {"student_name": name, "changes": out}


func test_the_star_rule() -> void:
	assert_eq(DayVerdict.star_count(2, 5.0, false), 4, "two targets, nobody down")
	assert_eq(DayVerdict.star_count(3, 5.0, true), 3, "targets crossed but someone fell")
	assert_eq(DayVerdict.star_count(1, -4.0, true), 3, "one target crossed")
	assert_eq(DayVerdict.star_count(0, 6.0, false), 2, "a net gain, no target")
	assert_eq(DayVerdict.star_count(0, 0.0, false), 2, "a flat day is not a hard day")
	assert_eq(DayVerdict.star_count(0, -3.0, true), 1, "net losses and no target")


func test_a_target_counts_only_when_crossed_today() -> void:
	var s := _student("Uji", 66.0, 65.0)
	assert_true(DayVerdict.crossed_today(s, "akademis", 3.0), "63 -> 66 crosses 65")
	assert_false(DayVerdict.crossed_today(s, "akademis", 0.5), "65.5 -> 66 was already over")
	s.akademis = 60.0
	assert_false(DayVerdict.crossed_today(s, "akademis", 3.0), "57 -> 60 is still short")
	assert_false(DayVerdict.crossed_today(s, "energy", 3.0), "energy has no target")


func test_compute_builds_the_tally_and_the_star_of_the_day() -> void:
	var marcel := _student("Marcel", 66.0, 65.0)
	var sari := _student("Sari", 40.0, 65.0)
	var summary := [
		_entry("Marcel", [["akademis", 6.0], ["energy", -12.0]]),
		_entry("Sari", [["akademis", 3.0], ["mood", -8.0]]),
	]
	var v := DayVerdict.compute(summary, [marcel, sari], 220)
	assert_eq(v["total_gain"], 9, "the skill gains add up; energy and mood do not count")
	assert_eq(v["targets_crossed"], 1, "Marcel crossed his target today")
	assert_eq(v["stars"], 3, "one target crossed")
	assert_eq(v["headline"], "Hari produktif!", "the three-star headline")
	assert_eq(v["subline"], "", "only a hard day gets the encouragement")
	assert_eq(v["money"], 220, "Wirausaha's takings pass through")
	assert_eq(v["star_name"], "Marcel", "the biggest gainer is the star")
	assert_eq(v["star_gain"], 6, "with his gain")
	assert_eq(v["star_skill"], "Akademis", "in his best skill")


func test_a_hard_day_scores_one_star_and_encourages() -> void:
	var s := _student("Uji", 40.0, 65.0)
	var v := DayVerdict.compute([_entry("Uji", [["akademis", -4.0]])], [s], 0)
	assert_eq(v["stars"], 1, "net losses, no target")
	assert_eq(v["subline"], DayVerdict.HARD_DAY_LINE, "Besok lebih baik!")
	assert_eq(v["star_name"], "", "nobody gained, so no star of the day")


func test_the_popup_carries_the_reward_layer() -> void:
	var popup := (load(POPUP_SCENE) as PackedScene).instantiate()
	for path in ["DimOverlay/Content/Reward", "DimOverlay/Content/Reward/Rows/Header/Face",
			"DimOverlay/Content/Reward/Rows/Header/Words/Headline",
			"DimOverlay/Content/Reward/Rows/Header/Words/Stars",
			"DimOverlay/Content/Reward/Rows/Tally/GainCell/Col/Value",
			"DimOverlay/Content/Reward/Rows/Tally/TargetCell/Col/Value",
			"DimOverlay/Content/Reward/Rows/Tally/MoneyCell/Col/Value",
			"DimOverlay/Content/Reward/Rows/StarOfDay/Row/Words/Line"]:
		assert_true(popup.get_node_or_null(path) != null, "the popup authors " + path)
	var content := popup.get_node("DimOverlay/Content")
	assert_true(content.get_node("TitleBanner").get_index() < content.get_node("Reward").get_index()
		and content.get_node("Reward").get_index() < content.get_node("RowsScroll").get_index(),
		"the verdict sits between the banner and the student rows")
	assert_eq(popup.get_node("DimOverlay/Content/Reward/Rows/Header/Words/Stars").get_child_count(), 4,
		"a 1-4 star rating")
	assert_eq((popup.get("teacher_faces") as Array).size(), 4, "four teacher expressions")
	assert_true(popup.get("star_on_texture") != null and popup.get("star_off_texture") != null,
		"lit and unlit star art")
	var stack: Array[Node] = [popup.get_node("DimOverlay/Content/Reward")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			assert_false(String((n as Control).theme_type_variation) == "Card",
				"the reward layer must not wear the Card variation")
		stack.append_array(n.get_children())
	popup.free()


## Every word the layer draws must exist in its face: the display face for
## the headline and the numbers, the body face for the rest.
func test_the_reward_text_is_covered_by_its_faces() -> void:
	var t := DesignTokens.load_default()
	var display: Font = t.font_display
	var body: Font = t.font_body_bold if t.font_body_bold != null else t.font_body
	var display_texts: Array[String] = ["+-0123456789"]
	for h in DayVerdict.HEADLINES:
		display_texts.append(h)
	for text in display_texts:
		for i in text.length():
			assert_true(display.has_char(text.unicode_at(i)),
				"'%s' in '%s' is not in the display face" % [text[i], text])
	for text in ["Bintang Hari Ini", "Marcel — +18 Seni Budaya", DayVerdict.HARD_DAY_LINE,
			"total naik", "target tercapai", "uang"]:
		for i in text.length():
			assert_true(body.has_char(text.unicode_at(i)),
				"'%s' in '%s' is not in the body face" % [text[i], text])


func test_school_day_hands_the_popup_todays_money() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("_money_at_day_start = _pending_total()"), "the day's opening total")
	assert_true(src.contains("_pending_total() - _money_at_day_start"), "today's takings reach the popup")
	var popup_src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/DaySummaryPopup.gd")
	assert_true(popup_src.contains("verdict = DayVerdict.compute(summary_data, students, money_today)"),
		"the popup computes its verdict from the same summary as its rows")
	assert_true(popup_src.contains("GameSettings.reduce_motion"), "the reveal honours reduce_motion")
