@tool
extends McpTestSuiteCompat

## Guards the button geometry system introduced 2026-09-08.
##
## Before that pass every button variation used radius_pill (999), which
## Godot clamps to half the box height -- so the project's 15 authored
## button heights rendered as 15 different corner radii between 31 and
## 145 px from one nominal style. These tests exist so that cannot
## silently return.

func suite_name() -> String:
	return "button_geometry"

var _tokens: DesignTokens
var _theme: Theme


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


## Variations that are Button-based but deliberately do NOT use
## radius_button. Every entry needs a reason -- an unreasoned entry is
## how the old inconsistency justified itself.
const RADIUS_EXEMPT := {
	"MainMenuButton":
		"StyleBoxTexture -- the gold gloss is painted, so the corner lives in menu_button.png",
	"TraitPill":
		"chip, StyleBoxTexture, stays fully round so it reads as a label not a control",
	"QuirkBadge":
		"chip -- stays radius_pill by design",
	"PersonaBadge":
		"chip -- stays radius_pill by design",
	"SpecialtyBadge":
		"chip -- stays radius_pill by design, like QuirkBadge and PersonaBadge",
	"SpecialtyBadgeS":
		"the compact S step of a chip -- inherits radius_pill from its base",
	"PersonaBadgeS":
		"the compact S step of a chip -- inherits radius_pill from its base",
	"QuirkBadgeS":
		"the compact S step of a chip -- inherits radius_pill from its base",
	"SpecialtyBadgeM":
		"the M step of a chip -- inherits radius_pill from its base",
	"PersonaBadgeM":
		"the M step of a chip -- inherits radius_pill from its base",
	"QuirkBadgeM":
		"the M step of a chip -- inherits radius_pill from its base",
	"EventSelectCard":
		"reads as a card, not a button -- radius_lg",
	"CardArrowButton":
		"fixed 120x120 square, so radius_pill yields an exact circle -- no height-dependent-radius risk",
	"GhostButton":
		"wash sits over the daily-login panel's baked capsule art (day1.png) -- radius_pill so the corner tracks the button's own height and always matches the art's rounded ends, deliberately height-dependent",
}


## Collect every type whose variation base is Button.
func _button_variations() -> Array:
	var out := []
	for name in _theme.get_type_list():
		if _theme.get_type_variation_base(name) == &"Button":
			out.append(name)
	return out


func test_every_button_variation_uses_one_fixed_radius() -> void:
	var checked := 0
	for name in _button_variations():
		if RADIUS_EXEMPT.has(name):
			continue
		# ShopHubTile's normal is StyleBoxEmpty by design; its washes
		# carry the shape, so fall through to hover.
		var sb := _theme.get_stylebox("normal", name) as StyleBoxFlat
		if sb == null:
			sb = _theme.get_stylebox("hover", name) as StyleBoxFlat
		if sb == null:
			continue
		checked += 1
		assert_eq(sb.corner_radius_top_left, _tokens.radius_button,
			"%s must use radius_button (%d), got %d"
				% [name, _tokens.radius_button, sb.corner_radius_top_left])
	assert_true(checked >= 8,
		"expected to check at least 8 button variations, checked %d -- "
		% checked + "the collector is probably not finding them")


func test_exempt_variations_still_exist() -> void:
	# An exemption for a variation that no longer exists is dead weight
	# that hides the next real one.
	var all := _theme.get_type_list()
	for name in RADIUS_EXEMPT:
		assert_true(all.has(name),
			"%s is exempt from the radius rule but no longer exists" % name)


## Godot type variations do not compose -- "PrimaryButton, but L" is not
## expressible -- so each role that has a non-S call site needs its own
## sibling. These seven cover the heights actually authored in the
## project; combinations nothing uses are deliberately not generated.
const SIZE_STEPS := {
	"PrimaryButton": "s", "SecondaryButton": "s",
	"DangerButton": "s", "SuccessButton": "s",
	"PrimaryButtonM": "m", "SecondaryButtonM": "m", "DangerButtonM": "m",
	"PrimaryButtonL": "l", "SecondaryButtonL": "l",
	"DangerButtonL": "l", "SuccessButtonL": "l",
}


func test_every_size_step_variation_exists() -> void:
	var all := _theme.get_type_list()
	for name in SIZE_STEPS:
		assert_true(all.has(name), "theme must declare type: " + name)


func test_size_steps_carry_the_right_font_size() -> void:
	var expected := {
		"s": _tokens.font_title,
		"m": _tokens.font_h2,
		"l": _tokens.font_h1,
	}
	for name in SIZE_STEPS:
		var step: String = SIZE_STEPS[name]
		assert_eq(_theme.get_font_size("font_size", name), expected[step],
			"%s is the %s step and must use font size %d"
				% [name, step.to_upper(), expected[step]])


## The identity that makes the size scale self-enforcing.
##
## If a button's natural minimum height equals its step, a scene author
## sets no height at all and cannot land between steps. This asserts the
## identity rather than the padding numbers, so a font change fails here
## loudly instead of letting every button in the game drift a few pixels.
func test_natural_height_matches_the_size_step() -> void:
	var targets := {
		"PrimaryButton": _tokens.btn_h_s,
		"SecondaryButton": _tokens.btn_h_s,
		"DangerButton": _tokens.btn_h_s,
		"SuccessButton": _tokens.btn_h_s,
		"PrimaryButtonM": _tokens.btn_h_m,
		"SecondaryButtonM": _tokens.btn_h_m,
		"DangerButtonM": _tokens.btn_h_m,
		"PrimaryButtonL": _tokens.btn_h_l,
		"SecondaryButtonL": _tokens.btn_h_l,
		"DangerButtonL": _tokens.btn_h_l,
		"SuccessButtonL": _tokens.btn_h_l,
	}
	for name in targets:
		var sb := _theme.get_stylebox("normal", name) as StyleBoxFlat
		var font := _theme.get_font("font", name)
		var fsize := _theme.get_font_size("font_size", name)
		var natural: float = sb.get_minimum_size().y + font.get_height(fsize)
		assert_true(abs(natural - targets[name]) <= 1.0,
			"%s natural height is %f but its step is %d -- re-solve btn_pad_v"
				% [name, natural, targets[name]])


## Every themed button in every scene must be authored at a size step.
##
## Fifteen ad-hoc heights is what accumulates when a scale is written
## down but not enforced -- 63, 80, 90, 94, 96, 116, 120, 135, 140, 144,
## 148, 160, 178, 267, 290 was the state on 2026-09-08. Without this the
## same drift starts again immediately.
##
## ALLOWED is for reviewed, commented exceptions and follows the same
## shape as test_viewport_editability.gd's dict. An entry needs a reason.
const HEIGHT_ALLOWED := {
	# "Scenes/Foo/bar.tscn::SomeButton": "why this one is off-step",
}

const SCENE_GLOB := "res://Scenes"


func _scene_files(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scene_files(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


## Checks one finished node's accumulated state against the S/M/L steps and
## appends a formatted offender line to `out` if it fails.
##
## Height priority mirrors what Godot actually renders: for an anchored
## Control, offset_top/offset_bottom determine the real on-screen size, so
## an explicit offset delta wins over custom_minimum_size, which is only a
## floor. This matters concretely for loby.tscn's "Student"/"Jadwal" CTAs,
## which carry custom_minimum_size = Vector2(0, 96) *and* an offset delta
## of 290 -- the button actually renders at 290, not 96, and a parser that
## let custom_minimum_size win would hide that real offender.
func _check_node(path: String, name: String, parent: String, variation: String,
		top: float, bottom: float, min_h: float, steps: Array,
		button_variations: Array, out: Array) -> void:
	var is_button := variation == "Button" or button_variations.has(variation)
	if not is_button or name == "":
		return
	var height := -1.0
	if top != INF and bottom != INF:
		height = bottom - top
	elif min_h > 0.0:
		height = min_h
	if height <= 0.0:
		return
	var full_name := name
	if parent != "" and parent != ".":
		full_name = parent + "/" + name
	var key := "%s::%s" % [path.replace("res://", ""), full_name]
	if HEIGHT_ALLOWED.has(key):
		return
	if not steps.has(int(round(height))):
		out.append("%s = %d" % [key, int(round(height))])


## Walks one scene's source text and returns its offending button lines.
##
## Node property blocks are parsed order-independently -- a node's
## properties (offsets, custom_minimum_size, theme_type_variation) can
## appear in any order across the project's .tscn files, so state is
## accumulated per node and only judged when the block ends (the next
## "[...]" section header, or end of file), rather than judged inline as
## each property line is read.
func _offenders_in_scene(path: String, src: String, steps: Array,
		button_variations: Array) -> Array:
	var out := []
	var node_name := ""
	var node_parent := ""
	var node_variation := ""
	var top := INF
	var bottom := INF
	var min_size_h := -1.0

	var lines := src.split("\n")
	for i in range(lines.size() + 1):
		var at_end := i >= lines.size()
		var line := "" if at_end else lines[i]
		if at_end or line.begins_with("["):
			_check_node(path, node_name, node_parent, node_variation,
					top, bottom, min_size_h, steps, button_variations, out)
			node_name = ""
			node_parent = ""
			node_variation = ""
			top = INF
			bottom = INF
			min_size_h = -1.0
			if line.begins_with("[node "):
				if line.contains("name=\""):
					node_name = line.get_slice("name=\"", 1).get_slice("\"", 0)
				if line.contains("parent=\""):
					node_parent = line.get_slice("parent=\"", 1).get_slice("\"", 0)
			continue
		if node_name == "":
			continue
		if line.begins_with("offset_top = "):
			top = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_bottom = "):
			bottom = float(line.get_slice("= ", 1))
		elif line.begins_with("custom_minimum_size = Vector2("):
			var inner := line.get_slice("Vector2(", 1).get_slice(")", 0)
			min_size_h = float(inner.get_slice(",", 1).strip_edges())
		elif line.begins_with("theme_type_variation = &\""):
			node_variation = line.get_slice("&\"", 1).get_slice("\"", 0)
	return out


## The size scale applies to exactly the variations that use radius_button.
##
## A variation listed in RADIUS_EXEMPT (plus ShopHubTile, exempt for the
## same StyleBoxEmpty reason but tracked separately because its `normal`
## stylebox opts out of the radius check by falling through rather than by
## being named there) has already declared itself off the fixed-corner
## button shape -- TraitPill/QuirkBadge/PersonaBadge are chips, EventSelectCard
## is a card, MainMenuButton's corner is painted into menu_button.png, and
## ShopHubTile is a 520px panel-less destination tile with an empty `normal`
## stylebox, so it is neither radius- nor height-scaled. Being Button-based
## in the theme graph does not make any of these a button on the S/M/L scale,
## so the widened detector (any theme_type_variation, not just the literal
## "Button") must not start flagging their authored heights (TraitPill at
## h=70/103/99, ShopHubTile at h=520, EventSelectCard at h=410) as if they
## were off-step buttons. This is one rule -- "opts out of radius_button" --
## expressed in the height check too, not a second, independently-grown
## exception list.
func test_no_button_is_authored_off_step() -> void:
	var steps := [_tokens.btn_h_s, _tokens.btn_h_m, _tokens.btn_h_l]
	var button_variations := []
	for name in _button_variations():
		if RADIUS_EXEMPT.has(name) or name == "ShopHubTile":
			continue
		button_variations.append(name)
	var scenes := []
	_scene_files(SCENE_GLOB, scenes)
	assert_true(scenes.size() > 20,
		"expected to find many scenes, found %d" % scenes.size())

	var offenders := []
	for path in scenes:
		# Minigames are out of the design system by standing policy.
		if path.contains("/Minigames/"):
			continue
		var src := FileAccess.get_file_as_string(path)
		if src == "":
			continue
		offenders.append_array(_offenders_in_scene(path, src, steps, button_variations))

	assert_eq(offenders.size(), 0,
		"buttons authored off the S/M/L scale:\n  " + "\n  ".join(offenders))


## MainMenuButton is exempt from the radius rule because its corner is
## painted, not generated -- but "exempt" must not mean "unchecked". This
## asserts it points at the asset that carries the right corner, so the
## exemption cannot quietly become a way of keeping the old shape.
func test_main_menu_button_uses_the_split_asset() -> void:
	var sb := _theme.get_stylebox("normal", "MainMenuButton") as StyleBoxTexture
	assert_not_null(sb, "MainMenuButton/normal must be a StyleBoxTexture")
	assert_true(sb.texture != null, "MainMenuButton has no texture")
	assert_true(str(sb.texture.resource_path).ends_with("menu_button.png"),
		"MainMenuButton must use menu_button.png, not %s -- trait_button.png "
		% str(sb.texture.resource_path)
		+ "is the round chip art and must stay round")


## The student card's page arrows. A reviewed exception to the fixed-radius
## rule: at a fixed 120x120 square, radius_pill yields an exact circle, and
## because the size is fixed there is no height-dependent-radius risk.
func test_card_arrow_button_is_a_circle() -> void:
	var sb := _theme.get_stylebox("normal", "CardArrowButton") as StyleBoxFlat
	assert_not_null(sb, "CardArrowButton/normal must be a StyleBoxFlat")
	assert_eq(sb.corner_radius_top_left, _tokens.radius_pill,
		"CardArrowButton is a fixed square, so radius_pill makes it a circle")
	assert_eq(sb.bg_color, _tokens.brand_primary, "arrow fill")
	assert_eq(sb.border_color, _tokens.outline_card, "arrow rim")
