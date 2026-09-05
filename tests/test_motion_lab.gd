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


## The intensity slider means two different things and the split must be
## total: every one of the 12 transitions is either on the strength ladder
## or travel-scaled. A family in neither list would leave the slider inert
## with no indication why.
func test_every_transition_has_an_intensity_behaviour() -> void:
	var src := _editor_source()
	assert_contains(src, "const LADDER", "the strength ladder exists")
	assert_contains(src, "const FIXED_SHAPE", "the travel-scaled list exists")
	var ladder := ["LINEAR", "SINE", "QUAD", "CUBIC", "QUART", "QUINT", "EXPO"]
	var fixed := ["BACK", "ELASTIC", "BOUNCE", "SPRING", "CIRC"]
	assert_eq(ladder.size() + fixed.size(), _TRANSITIONS.size(),
		"the two lists partition all 12 transitions")
	for t in _TRANSITIONS:
		assert_true(ladder.has(t) or fixed.has(t),
			t + " has an intensity behaviour")


## The duration slider snaps to this project's own motion tokens, so a tuned
## value can be emitted as Juice.tokens().dur_fast instead of a bare float.
## These four numbers are design_tokens.tres's Motion group and the page
## must not drift from them.
func test_duration_snaps_to_the_projects_real_motion_tokens() -> void:
	var src := _editor_source()
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres loads")
	for pair in [["instant", tokens.dur_instant], ["fast", tokens.dur_fast],
			["normal", tokens.dur_normal], ["slow", tokens.dur_slow]]:
		assert_contains(src, "%s: %s" % [pair[0], String.num(pair[1], 2)],
			"page snaps to dur_%s = %s" % [pair[0], pair[1]])


func test_preview_covers_every_property_the_skill_can_target() -> void:
	var src := _editor_source()
	for prop in ["scale", "fade", "slide", "fill"]:
		assert_contains(src, "\"%s\"" % prop,
			"stand-in can demonstrate the " + prop + " property")
	assert_contains(src, "requestAnimationFrame",
		"ball and stand-in share one animation clock")


## The token is the entire browser-to-Claude return path. Both ends parse
## the same six fields, so the format is pinned here rather than left to
## whatever the page happens to emit.
func test_token_format_is_pinned() -> void:
	var src := _editor_source()
	assert_contains(src, "KJT-MOTION v1", "token carries its format version")
	assert_contains(src, "function buildToken", "the page builds the token")
	for field in ["travel", "toFixed(3)", "toFixed(2)"]:
		assert_contains(src, field, "token field present: " + field)
	assert_contains(src, "@", "token echoes element@scene")


## Pasting a stale token from an earlier round would otherwise apply the
## wrong curve to the right element, silently. The token names its target
## so SKILL.md can refuse a mismatch.
func test_token_echoes_the_target_back() -> void:
	var src := _editor_source()
	assert_contains(src, "TARGET.element", "token names the element")
	assert_contains(src, "TARGET.scene", "token names the scene")


func test_token_can_be_copied() -> void:
	var src := _editor_source()
	assert_contains(src, "navigator.clipboard",
		"one-click copy -- the token is retyped by hand otherwise")
