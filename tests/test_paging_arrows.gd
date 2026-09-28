@tool
extends McpTestSuite

## UI depth pass Phase 3, fix round 1: every paging arrow draws its chevron
## as a child `Arrow` TextureRect, inset 24px on every side, unrotated --
## left is chevron_left, right is chevron_right. The Button's own `icon` is
## unused: SecondaryButtonL / StudentCardSecondaryButtonL / CardArrowButton
## all carry content_margins that shrink the icon content box to ~32px, far
## smaller than the chevron glyph reads well at, so the child picture is
## sized independently of the size step's padding instead. It does not sink
## with the lipped face on press, unlike a real Button `icon` would.
##
## Must be @tool; no test here may be a coroutine.

const LEFT := "res://Assets/Images/UI/Icons/chevron_left.svg"
const RIGHT := "res://Assets/Images/UI/Icons/chevron_right.svg"
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


func test_every_paging_arrow_wears_its_chevron() -> void:
	for scene_path in ARROWS:
		var scene := (load(scene_path) as PackedScene).instantiate()
		track(scene)
		_check(scene, ARROWS[scene_path][0], LEFT, scene_path)
		_check(scene, ARROWS[scene_path][1], RIGHT, scene_path)
