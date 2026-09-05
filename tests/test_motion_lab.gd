@tool
extends McpTestSuite

## Motion Lab's skill assets (2026-09-05).
##
## editor.html cannot be instantiated by the Godot runner, so these are
## source scans in the house style (see test_cutscene.gd). They guard the
## contract the SKILL.md workflow depends on: the substitution markers exist,
## every transition the token format can name is offered by the grid, and the
## page loads nothing across the network -- an external <script>, <link> or
## fetch() would be silently blocked by the Artifact CSP and the page would
## fail with no visible error.
##
## Suite is @tool and no test is a coroutine.

const _EDITOR := "res://.claude/skills/motion-lab/assets/editor.html"
const _TABLE := "res://.claude/skills/motion-lab/assets/godot-easing.json"

const _TRANSITIONS := ["LINEAR", "SINE", "QUINT", "QUART", "QUAD", "EXPO",
	"ELASTIC", "CUBIC", "CIRC", "BOUNCE", "BACK", "SPRING"]
const _EASES := ["IN", "OUT", "IN_OUT", "OUT_IN"]


func suite_name() -> String:
	return "motion_lab"


func _editor_source() -> String:
	return FileAccess.get_file_as_string(_EDITOR)


func test_skill_assets_exist() -> void:
	assert_true(FileAccess.file_exists(_EDITOR), _EDITOR + " exists")
	assert_true(FileAccess.file_exists(_TABLE), _TABLE + " exists")


func test_template_markers_are_present_and_unique() -> void:
	var src := _editor_source()
	for marker in ["/*__GODOT_EASING_TABLE__*/", "/*__MOTION_LAB_TARGET__*/"]:
		assert_eq(src.count(marker), 1,
			marker + " appears exactly once -- the skill substitutes on it")


func test_grid_offers_every_transition_and_ease() -> void:
	var src := _editor_source()
	for t in _TRANSITIONS:
		assert_contains(src, "\"%s\"" % t, "grid offers TRANS_" + t)
	for e in _EASES:
		assert_contains(src, "\"%s\"" % e, "grid offers EASE_" + e)


## Deliberately does NOT ban the substring "http" outright: an inline SVG's
## xmlns="http://www.w3.org/2000/svg" is a declaration, not a fetch, and
## banning it would push the page away from inline SVG for no benefit.
func test_page_loads_nothing_across_the_network() -> void:
	var src := _editor_source()
	for forbidden in ["<script src", "<link ", "@import", "fetch(",
			"XMLHttpRequest", "src=\"http", "href=\"http", "url(http"]:
		assert_false(src.contains(forbidden),
			"page must be fully self-contained, found: " + forbidden)


## The publish wrapper supplies its own document skeleton tags; a page
## carrying its own would be nested inside the wrapper's body. "<head>" is
## checked with its closing bracket/space so it does not false-positive on
## the page's own legitimate <header> element.
func test_page_omits_the_document_skeleton() -> void:
	var src := _editor_source()
	for tag in ["<!doctype", "<!DOCTYPE", "<html", "<head>", "<head ", "<body"]:
		assert_false(src.contains(tag),
			"Artifact supplies the skeleton, page must not include " + tag)


func test_page_declares_a_title_and_a_light_and_dark_palette() -> void:
	var src := _editor_source()
	assert_contains(src, "<title>", "page names itself for the browser tab")
	assert_contains(src, ":root", "palette is defined on bare :root")
	assert_contains(src, "prefers-color-scheme: dark", "dark theme is handled")
	assert_contains(src, "[data-theme=\"dark\"]", "explicit dark choice wins")
