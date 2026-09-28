@tool
extends McpTestSuite

## LippedBox (2026-09-28 UI depth pass): the lipped look built from a native
## StyleBoxFlat -- the lip is its drop shadow in a strip freed by a negative
## expand_margin_bottom, held drops the face with expand_margin_top, and the
## gloss is a blended top border. The last test guards the reason it is
## native: no script may ride into the baked theme, or every debug run logs
## a SceneTree error at startup.
##
## Must be @tool; no test here may be a coroutine.

const FACE := Color("2EC99A")
const LIP := Color("178A68")


func suite_name() -> String:
	return "lipped_box"


func test_a_resting_face_sits_on_its_lip() -> void:
	var sb := LippedBox.make(FACE, LIP, 8, 20, 0.35)
	assert_eq(sb.bg_color, FACE, "the face")
	assert_eq(sb.shadow_color, LIP, "the lip is the shadow's colour")
	assert_eq(sb.expand_margin_bottom, -8.0, "the face ends 8 px above the bottom")
	assert_eq(sb.expand_margin_top, 0.0, "and starts at the top")
	assert_eq(sb.shadow_offset, Vector2(0, 8), "the lip fills the freed strip")
	assert_eq(sb.shadow_size, LippedBox.LIP_SOFTNESS, "as a crisp slab")
	assert_eq(sb.corner_radius_top_left, 20, "house corners")
	assert_eq(LippedBox.lip_height_of(sb), 8, "the lip reads back")
	assert_false(LippedBox.is_pressed(sb), "resting")
	assert_true(LippedBox.is_lipped(sb), "lipped")


func test_held_drops_the_face_onto_the_lip() -> void:
	var sb := LippedBox.make(FACE, LIP, 8, 20, 0.35, true)
	assert_eq(sb.expand_margin_top, -8.0, "the face drops by the lip")
	assert_eq(sb.expand_margin_bottom, 0.0, "down to the bottom")
	assert_eq(sb.shadow_size, 0, "and no lip is drawn")
	assert_eq(sb.shadow_color, LIP, "the lip colour still reads back")
	assert_eq(LippedBox.lip_height_of(sb), 8, "so does its height")
	assert_true(LippedBox.is_pressed(sb), "held")


func test_the_gloss_is_a_blended_top_border() -> void:
	var sb := LippedBox.make(FACE, LIP, 8, 20, 0.35)
	assert_eq(sb.border_width_top, LippedBox.GLOSS_WIDTH, "a band along the top")
	assert_eq(sb.border_width_bottom, 0, "no other border")
	assert_eq(sb.border_color, FACE.lightened(0.35), "lighter than the face")
	assert_true(sb.border_blend, "fading into it")
	var flat := LippedBox.make(FACE, LIP, 8, 20, 0.0)
	assert_eq(flat.border_width_top, 0, "0 gloss draws none")


func test_vertical_padding_keeps_the_height_and_centres_on_the_face() -> void:
	var rest := LippedBox.make(FACE, LIP, 8, 20, 0.35)
	LippedBox.set_vertical_padding(rest, 24)
	assert_eq(rest.content_margin_top + rest.content_margin_bottom, 48.0, "height unchanged")
	assert_eq(rest.content_margin_top, 20.0, "the label rises by half the lip")
	var held := LippedBox.make(FACE, LIP, 8, 20, 0.35, true)
	LippedBox.set_vertical_padding(held, 24)
	assert_eq(held.content_margin_top, 28.0, "held: the label drops with the face")
	assert_eq(held.content_margin_top - rest.content_margin_top, 8.0, "by exactly the lip")


func test_vertical_padding_never_goes_negative() -> void:
	var sb := LippedBox.make(FACE, LIP, 7, 20, 0.35)
	LippedBox.set_vertical_padding(sb, 2)
	assert_eq(sb.content_margin_top, 0.0, "clamped to the padding")
	assert_eq(sb.content_margin_bottom, 4.0, "the sum still holds")
	LippedBox.set_vertical_padding(sb, 0)
	assert_eq(sb.content_margin_top, 0.0, "an icon-only button keeps zero")
	assert_eq(sb.content_margin_bottom, 0.0, "top and bottom")


func test_relip_keeps_the_padding_and_the_state() -> void:
	var sb := LippedBox.make(FACE, LIP, 8, 20, 0.35)
	LippedBox.set_vertical_padding(sb, 24)
	LippedBox.relip(sb, 10)
	assert_eq(LippedBox.lip_height_of(sb), 10, "the new lip")
	assert_eq(sb.content_margin_top, 19.0, "re-centred on it")
	assert_eq(sb.content_margin_top + sb.content_margin_bottom, 48.0, "same height")
	var held := LippedBox.make(FACE, LIP, 8, 20, 0.35, true)
	LippedBox.relip(held, 10)
	assert_true(LippedBox.is_pressed(held), "a held box stays held")


func test_a_zero_lip_is_a_flat_face() -> void:
	var sb := LippedBox.make(FACE, LIP, 0, 20, 0.35)
	assert_eq(sb.shadow_size, 0, "no lip drawn")
	assert_false(LippedBox.is_lipped(sb), "not lipped")


func test_other_boxes_are_not_lipped() -> void:
	assert_false(LippedBox.is_lipped(StyleBoxEmpty.new()), "an empty box")
	assert_false(LippedBox.is_lipped(StyleBoxFlat.new()), "a plain flat box")
	assert_false(LippedBox.is_lipped(null), "no box")


func test_no_script_rides_into_the_theme() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	for name in ["PrimaryButton", "BookHeroButton", "StudentCardSecondaryButtonL"]:
		for state in ["normal", "pressed", "disabled"]:
			var sb := theme.get_stylebox(state, name)
			assert_true(sb is StyleBoxFlat and sb.get_script() == null,
				"%s/%s is a native StyleBoxFlat" % [name, state])
