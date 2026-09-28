@tool
extends McpTestSuite

## LippedStyleBox (2026-09-28 UI depth pass): a face on a solid darker lip,
## with a white gloss band. layout() is the geometry _draw() and these tests
## share; set_vertical_padding() keeps a button's height while centring its
## label on the face; and the box must survive a save/load, since the baked
## theme stores it as a script-backed sub-resource.
##
## Must be @tool; no test here may be a coroutine.

const ROUND_TRIP_PATH := "user://test_lipped_stylebox_roundtrip.tres"


func suite_name() -> String:
	return "lipped_stylebox"


func _box(lip: int) -> LippedStyleBox:
	var sb := LippedStyleBox.new()
	sb.lip_height = lip
	return sb


func test_the_face_sits_above_a_lip_of_the_same_size() -> void:
	var parts := _box(8).layout(Rect2(0, 0, 200, 100))
	assert_eq(parts["face"], Rect2(0, 0, 200, 92), "the face is the rect minus the lip")
	assert_eq(parts["lip"], Rect2(0, 8, 200, 92), "the lip is the face moved down by lip_height")
	assert_true(parts["show_lip"], "a resting box shows its lip")


func test_pressed_drops_the_face_onto_the_lip() -> void:
	var sb := _box(8)
	sb.pressed = true
	var parts := sb.layout(Rect2(0, 0, 200, 100))
	assert_eq(parts["face"], Rect2(0, 8, 200, 92), "the face drops by lip_height")
	assert_false(parts["show_lip"], "and the lip is hidden under it")


func test_the_gloss_covers_the_top_third_inset() -> void:
	var gloss: Rect2 = _box(8).layout(Rect2(0, 0, 200, 100))["gloss"]
	assert_eq(gloss.position, Vector2(LippedStyleBox.GLOSS_INSET_X, LippedStyleBox.GLOSS_INSET_TOP),
		"inset from the face's top-left")
	assert_eq(gloss.size.x, 200.0 - 2 * LippedStyleBox.GLOSS_INSET_X, "inset on both sides")
	assert_true(absf(gloss.size.y - 92.0 * LippedStyleBox.GLOSS_HEIGHT_RATIO) < 0.01,
		"a third of the face tall")


func test_the_gloss_follows_the_face_when_pressed() -> void:
	var sb := _box(8)
	sb.pressed = true
	var gloss: Rect2 = sb.layout(Rect2(0, 0, 200, 100))["gloss"]
	assert_eq(gloss.position.y, 8.0 + LippedStyleBox.GLOSS_INSET_TOP, "the gloss sinks with the face")


func test_vertical_padding_keeps_the_height_and_centres_on_the_face() -> void:
	var rest := _box(8)
	rest.set_vertical_padding(24)
	assert_eq(rest.content_margin_top + rest.content_margin_bottom, 48.0, "height unchanged")
	assert_eq(rest.content_margin_top, 20.0, "the label is lifted by half the lip")
	var held := _box(8)
	held.pressed = true
	held.set_vertical_padding(24)
	assert_eq(held.content_margin_top, 28.0, "held: the label drops with the face")
	assert_eq(held.content_margin_top - rest.content_margin_top, 8.0, "by exactly the lip")


func test_vertical_padding_never_goes_negative() -> void:
	var sb := _box(8)
	sb.set_vertical_padding(0)
	assert_eq(sb.content_margin_top, 0.0, "an icon-only button keeps a zero top margin")
	assert_eq(sb.content_margin_bottom, 0.0, "and a zero bottom margin")


func test_repad_keeps_the_padding_after_the_lip_changes() -> void:
	var sb := _box(8)
	sb.set_vertical_padding(24)
	sb.lip_height = 10
	sb.repad()
	assert_eq(sb.content_margin_top, 19.0, "re-centred on the taller lip")
	assert_eq(sb.content_margin_top + sb.content_margin_bottom, 48.0, "same height")


func test_a_zero_lip_is_a_flat_face() -> void:
	var parts := _box(0).layout(Rect2(0, 0, 200, 100))
	assert_eq(parts["face"], Rect2(0, 0, 200, 100), "the face fills the rect")
	assert_false(parts["show_lip"], "and no lip is drawn")


func test_it_survives_a_save_and_load() -> void:
	var sb := _box(9)
	sb.bg_color = Color("2EC99A")
	sb.lip_color = Color("178A68")
	sb.corner_radius = 20
	sb.gloss_strength = 0.4
	sb.pressed = true
	sb.set_vertical_padding(24)
	assert_eq(ResourceSaver.save(sb, ROUND_TRIP_PATH), OK, "saves")
	var back := ResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LippedStyleBox
	assert_true(back != null, "loads back as a LippedStyleBox")
	if back == null:
		return
	assert_eq(back.bg_color, Color("2EC99A"), "face colour")
	assert_eq(back.lip_color, Color("178A68"), "lip colour")
	assert_eq(back.lip_height, 9, "lip height")
	assert_eq(back.corner_radius, 20, "radius")
	assert_true(absf(back.gloss_strength - 0.4) < 0.001, "gloss")
	assert_true(back.pressed, "pressed state")
	assert_eq(back.content_margin_top, 28.0, "margins travel with it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP_PATH))
