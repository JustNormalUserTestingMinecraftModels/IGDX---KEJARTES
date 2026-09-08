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
