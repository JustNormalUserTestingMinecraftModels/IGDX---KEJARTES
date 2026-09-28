@tool
extends McpTestSuite

## UI depth pass Phase 3: the two activity categories that have no stat of
## their own -- Istirahat (rest) and Wirausaha (earning) -- show their own
## icons from the Icons/ set wherever a screen names them, instead of the
## energy bar's glyph, the coin, or generated placeholder PNGs.
##
## Must be @tool; no test here may be a coroutine.

const REST := "res://Assets/Images/UI/Icons/cat_istirahat.svg"
const EARN := "res://Assets/Images/UI/Icons/cat_wirausaha.svg"


func suite_name() -> String:
	return "category_icons"


func test_the_sources_name_the_category_icons() -> void:
	for path in ["res://Scripts/StudentList/RosterCard.gd", "res://Scripts/AturJadwal/DayStickyNote.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, REST, path + " shows Istirahat's own icon")
		assert_contains(src, EARN, path + " shows Wirausaha's own icon")


func test_the_earn_money_tip_shows_the_wirausaha_icon() -> void:
	var panel := (load("res://Scenes/Lobby/DapatkanUang.tscn") as PackedScene).instantiate()
	track(panel)
	var icon := panel.find_child("TipIcon", true, false) as TextureRect
	assert_true(icon != null and icon.texture != null, "the tip has an icon")
	if icon != null and icon.texture != null:
		assert_eq(icon.texture.resource_path, EARN)
