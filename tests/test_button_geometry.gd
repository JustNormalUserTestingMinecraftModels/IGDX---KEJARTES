@tool
extends McpTestSuite

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
	"EventSelectCard":
		"reads as a card, not a button -- radius_lg",
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
