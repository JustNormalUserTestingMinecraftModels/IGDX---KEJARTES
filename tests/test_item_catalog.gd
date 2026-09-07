@tool
extends McpTestSuite

## The shop/inventory item catalog: skill-boost fields exist and are wired
## through ItemDatabase, and every item has its own non-empty description.

func suite_name() -> String:
	return "item_catalog"

func test_item_data_has_skill_boost_fields() -> void:
	var d := ItemData.new()
	assert_true("akademis_boost" in d, "ItemData needs akademis_boost")
	assert_true("seni_budaya_boost" in d, "ItemData needs seni_budaya_boost")
	assert_true("olahraga_boost" in d, "ItemData needs olahraga_boost")
	assert_equal(0, d.akademis_boost, "skill boosts default to 0")

func test_catalog_skill_values_are_registered() -> void:
	assert_equal(8, ItemDatabase.get_item("Raket").olahraga_boost)
	assert_equal(6, ItemDatabase.get_item("Bank Soal").akademis_boost)
	assert_equal(4, ItemDatabase.get_item("Komik").seni_budaya_boost)
	assert_equal(0, ItemDatabase.get_item("Mie Instan").akademis_boost)

func test_every_item_has_a_unique_nonempty_description() -> void:
	var items := ItemDatabase.get_all_items()
	assert_true(items.size() >= 9, "catalog has all base items")
	var seen := {}
	for it in items:
		assert_true(it.description.strip_edges() != "",
			"description missing for: " + it.item_name)
		assert_false(seen.has(it.description),
			"duplicate description: " + it.description)
		seen[it.description] = true
