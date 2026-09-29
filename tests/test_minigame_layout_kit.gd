@tool
extends McpTestSuite

## The minigame mobile-layout kit (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 3):
## its icons, theme variations, tray, hint pill, how-to rows and resources.
## Each piece is pinned by the task that adds it. Must be @tool, and no
## test here may be a coroutine.

const ICON_DIR := "res://Assets/Images/UI/Icons/"
## Every placeholder pictogram the layout kit points at.
const KIT_ICONS: Array[String] = ["pause", "timer", "swipe_up", "howto_tap",
	"howto_swipe", "howto_drag", "howto_read", "howto_timer", "howto_target"]


func suite_name() -> String:
	return "minigame_layout_kit"


func test_every_kit_icon_exists() -> void:
	for icon: String in KIT_ICONS:
		var path := ICON_DIR + icon + ".svg"
		assert_true(ResourceLoader.exists(path), path + " is a kit icon")


func test_every_kit_icon_is_listed_in_the_readme() -> void:
	var readme := FileAccess.get_file_as_string(ICON_DIR + "README.md")
	for icon: String in KIT_ICONS:
		assert_contains(readme, "`" + icon + ".svg`", icon + " has a README row")
