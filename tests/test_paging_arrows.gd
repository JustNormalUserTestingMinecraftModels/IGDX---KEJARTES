@tool
extends McpTestSuite

## UI depth pass Phase 3: every paging arrow is the Button's own icon from
## the Icons/ set -- left is chevron_left, right is chevron_right -- so the
## glyph is content that sinks with the lipped face when pressed, instead
## of a rotated child picture that stayed put.
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
	assert_true(b.icon != null and b.icon.resource_path == want,
		"%s: %s must wear %s" % [label, path, want])
	assert_eq(b.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER, label + ": the chevron is centred")
	for child in b.get_children():
		assert_false(child is TextureRect, label + ": " + path + " still draws a child picture")


func test_every_paging_arrow_wears_its_chevron() -> void:
	for scene_path in ARROWS:
		var scene := (load(scene_path) as PackedScene).instantiate()
		track(scene)
		_check(scene, ARROWS[scene_path][0], LEFT, scene_path)
		_check(scene, ARROWS[scene_path][1], RIGHT, scene_path)
