@tool
extends McpTestSuite

## StatInfo is the one table describing the five bars a student card shows.
## Before it existed, report_card.gd and student_card.gd each carried their
## own copy of the same if/elif chain, and the two had already drifted in
## whitespace. These tests pin the contract the popup scene reads.
##
## Affects nothing at runtime -- pure data assertions, no scene instantiated.
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "stat_info"


## The five bars a student card shows, in card order.
const EXPECTED_BARS: Array[String] = [
	"Kepribadian1", "Kepribadian2", "Akademis1", "Akademis2", "Akademis3",
]


func test_table_covers_exactly_the_five_card_bars() -> void:
	var keys: Array = StatInfo.BARS.keys()
	keys.sort()
	var expected: Array = EXPECTED_BARS.duplicate()
	expected.sort()
	assert_eq(keys, expected, "StatInfo.BARS must describe exactly the five bars")


func test_every_bar_carries_every_field() -> void:
	var required: Array[String] = [
		"display_name", "category_label", "glyph",
		"token_category", "data_key", "description",
	]
	for bar_name in StatInfo.BARS:
		var entry: Dictionary = StatInfo.BARS[bar_name]
		for field in required:
			assert_has_key(entry, field, "%s is missing %s" % [bar_name, field])
			assert_ne(entry[field], "", "%s.%s must not be empty" % [bar_name, field])


func test_needs_and_skills_are_labelled_apart() -> void:
	# Mood and Energy are needs; the three skills are stats. The popup header
	# prints this word, so a mix-up is visible to the player.
	assert_eq(StatInfo.BARS["Kepribadian1"]["category_label"], "NEEDS")
	assert_eq(StatInfo.BARS["Kepribadian2"]["category_label"], "NEEDS")
	assert_eq(StatInfo.BARS["Akademis1"]["category_label"], "STATS")
	assert_eq(StatInfo.BARS["Akademis2"]["category_label"], "STATS")
	assert_eq(StatInfo.BARS["Akademis3"]["category_label"], "STATS")


func test_token_categories_match_the_shipped_bar_colours() -> void:
	# Mood and Energy are not schedule categories, so they borrow the two
	# accents no skill uses: Istirahat (violet) for Mood, Libur (amber) for
	# Energy. This is the mapping report_card.gd::BAR_CATEGORY shipped with.
	assert_eq(StatInfo.token_category("Kepribadian1"), "Istirahat")
	assert_eq(StatInfo.token_category("Kepribadian2"), "Libur")
	assert_eq(StatInfo.token_category("Akademis1"), "Akademis")
	assert_eq(StatInfo.token_category("Akademis2"), "SeniBudaya")
	assert_eq(StatInfo.token_category("Akademis3"), "Olahraga")


func test_unknown_bar_degrades_instead_of_crashing() -> void:
	# Callers pass a bar name straight from a node name; a typo must not take
	# the screen down.
	assert_eq(StatInfo.get_bar("Nonsense"), {})
	assert_eq(StatInfo.token_category("Nonsense"), "")
	assert_eq(StatInfo.value_of("Nonsense", {}), 0.0)


func test_value_of_reads_the_gamestate_key_not_the_bar_name() -> void:
	# The bar is named "Akademis2" but the GameState dictionary key is
	# "akademis2" and it means seni_budaya. This mismatch is the single most
	# common source of bugs in this project -- pin it.
	var s_data := {
		"kepribadian1": 61.0, "kepribadian2": 42.0,
		"akademis1": 10.0, "akademis2": 20.0, "akademis3": 30.0,
	}
	assert_eq(StatInfo.value_of("Kepribadian1", s_data), 61.0)
	assert_eq(StatInfo.value_of("Kepribadian2", s_data), 42.0)
	assert_eq(StatInfo.value_of("Akademis2", s_data), 20.0)


func test_descriptions_are_indonesian_player_facing_copy() -> void:
	# UI text in this project is Indonesian. A description that slipped into
	# English would ship straight to the player.
	for bar_name in StatInfo.BARS:
		var desc: String = StatInfo.BARS[bar_name]["description"]
		assert_gt(desc.length(), 40, "%s description is too short to be real copy" % bar_name)
