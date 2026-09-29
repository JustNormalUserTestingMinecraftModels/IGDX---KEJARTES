@tool
extends McpTestSuite

## UI depth pass Phase 3, fix round 1: every paging arrow draws its chevron
## as a child `Arrow` TextureRect, inset 24px on every side, unrotated --
## left is chevron_left, right is chevron_right. The Button's own `icon` is
## unused: SecondaryButtonL / StudentCardSecondaryButtonL / CardArrowButton
## all carry content_margins that shrink the icon content box to ~32px, far
## smaller than the chevron glyph reads well at, so the child picture is
## sized independently of the size step's padding instead. ButtonGlyph.gd
## makes the child behave like an icon: it sinks with the lipped face while
## held and dims while its button is disabled.
##
## Must be @tool; no test here may be a coroutine.

const LEFT := "res://Assets/Images/UI/Icons/chevron_left.svg"
const RIGHT := "res://Assets/Images/UI/Icons/chevron_right.svg"
## The script that makes a child picture follow its button.
const GLYPH := "res://Scripts/UI/ButtonGlyph.gd"
## How far each Arrow sits inside its button on every side, px.
const INSET := 24.0
## The baked theme, so the lipped faces are the real ones.
const THEME := "res://Assets/Theme/kejartes_theme.tres"
## scene -> [left arrow path, right arrow path].
const ARROWS := {
	"res://Scenes/LevelSelect/LevelSelect.tscn": ["Safe/UI/Stack/PrevArrow", "Safe/UI/Stack/NextArrow"],
	"res://Scenes/StudentCard/StudentCard.tscn": ["%NextButtonKiri", "%NextButtonKanan"],
	"res://Scenes/StudentList/StudentList.tscn": ["%LeftArrow", "%RightArrow"],
	"res://Scenes/ReportCard/ReportCard.tscn": ["Safe/UI/BottomBar/NextButtonKiri", "Safe/UI/BottomBar/NextButtonKanan"],
}


func suite_name() -> String:
	return "paging_arrows"


func _check(scene: Node, path: String, want: String, label: String) -> void:
	var b := scene.get_node_or_null(path) as Button
	assert_true(b != null, label + ": missing " + path)
	if b == null:
		return
	assert_true(b.icon == null, label + ": " + path + " must not wear its own icon")
	var arrow := b.get_node_or_null("Arrow") as TextureRect
	assert_true(arrow != null, label + ": " + path + " is missing its Arrow child")
	if arrow == null:
		return
	assert_true(arrow.texture != null and arrow.texture.resource_path == want,
		"%s: %s/Arrow must wear %s" % [label, path, want])
	assert_eq(arrow.rotation, 0.0, label + ": " + path + "/Arrow must not be rotated")
	assert_eq(arrow.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		label + ": " + path + "/Arrow must not eat the button's input")
	# The fix for the ~15 px chevrons: a full-rect child, inset, scaled to fit.
	assert_eq([arrow.anchor_left, arrow.anchor_top, arrow.anchor_right, arrow.anchor_bottom],
		[0.0, 0.0, 1.0, 1.0], label + ": " + path + "/Arrow must fill its button")
	assert_eq([arrow.offset_left, arrow.offset_top, arrow.offset_right, arrow.offset_bottom],
		[INSET, INSET, -INSET, -INSET], label + ": " + path + "/Arrow must sit 24 px in")
	assert_eq(arrow.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, label + ": " + path + "/Arrow expand_mode")
	assert_eq(arrow.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		label + ": " + path + "/Arrow stretch_mode")
	var script := arrow.get_script() as Script
	assert_true(script != null and script.resource_path == GLYPH,
		label + ": " + path + "/Arrow must follow its button (ButtonGlyph.gd)")


func test_every_paging_arrow_wears_its_chevron() -> void:
	for scene_path in ARROWS:
		var scene := (load(scene_path) as PackedScene).instantiate()
		track(scene)
		_check(scene, ARROWS[scene_path][0], LEFT, scene_path)
		_check(scene, ARROWS[scene_path][1], RIGHT, scene_path)


## Held, the chevron drops by exactly as much as the button's label would;
## let go, it returns; disabled, it dims.
func test_the_chevron_sinks_and_dims_with_its_button() -> void:
	var button := Button.new()
	button.theme = load(THEME)
	button.theme_type_variation = &"SecondaryButtonL"
	button.toggle_mode = true
	var arrow := TextureRect.new()
	arrow.set_script(load(GLYPH))
	arrow.offset_top = INSET
	arrow.offset_bottom = -INSET
	button.add_child(arrow)
	# In the tree, so the button resolves its theme's styleboxes.
	Engine.get_main_loop().root.add_child(button)
	track(button)
	arrow._rest_top = INSET
	arrow._rest_bottom = -INSET
	var drop: float = arrow.label_drop(button)
	assert_true(drop > 0.0, "a lipped SecondaryButtonL's label drops when held (got %s)" % drop)
	button.button_pressed = true
	arrow.follow()
	assert_eq(arrow.offset_top, INSET + drop, "held: the chevron sinks with the face")
	assert_eq(arrow.offset_bottom, -INSET + drop, "held: the whole picture moves, not just its top")
	button.button_pressed = false
	arrow.follow()
	assert_eq(arrow.offset_top, INSET, "let go: back to its authored inset")
	button.disabled = true
	arrow.follow()
	# Color channels are 32-bit floats, so compare the alpha approximately.
	assert_true(is_equal_approx(snappedf(arrow.self_modulate.a, 0.001), snappedf(arrow.disabled_alpha, 0.001)),
		"disabled: the chevron dims to disabled_alpha (got %s)" % arrow.self_modulate.a)
	button.disabled = false
	arrow.follow()
	assert_eq(arrow.self_modulate.a, 1.0, "enabled again: full strength")
