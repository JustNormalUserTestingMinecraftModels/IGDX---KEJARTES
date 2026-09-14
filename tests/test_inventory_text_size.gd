@tool
extends McpTestSuite

## The Inventory item sheet and the item-application screen read at a
## comfortable size (2026-09-14; spec
## docs/superpowers/specs/2026-09-14-exam-cg-and-inventory-text-design.md).
## On the 1080-wide canvas 36 px is about 12 sp, the floor for comfortable
## secondary text on a phone. Every Label, and every Button with text, is
## resolved through the baked theme the way Godot resolves it: a node
## override, then the variation and its base chain, then the class, then the
## theme default. Scenes are instantiated but never added to the tree, so no
## _ready runs; sub-scenes the screens spawn at runtime are listed directly.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _SCENES := [
	"res://Scenes/Inventory/inventory.tscn",
	"res://Scenes/Inventory/InventorySlot.tscn",
	"res://Scenes/Inventory/ItemDetailSheet.tscn",
	"res://Scenes/Inventory/ApplyItemScreen.tscn",
	"res://Scenes/Inventory/ApplyStudentRow.tscn",
]
const _FLOOR_PX := 36

## Reviewed exceptions: shared components whose size belongs to other screens
## too. Variation -> the smallest size it may have here.
const ALLOWED := {
	# The shared DaySummary card's need words (also DaySummaryPopup,
	# EventStudentCard, ResultCheckup, WeekHistoryRow).
	"DaySummaryNeedsLabel": 30,
	# The empty-grid hint, shared with ResultCheckup.
	"EmptyStateLabel": 32,
}

## The 18 and 22 px styles this pass moved these screens off.
const _RETIRED := ["CaptionLabel", "MicroLabel", "ResultDeltaLabel"]

var _theme: Theme


func suite_name() -> String:
	return "inventory_text_size"


func suite_setup(_ctx: Dictionary) -> void:
	_theme = load(_THEME_PATH)


func test_no_text_on_the_item_screens_is_below_the_floor() -> void:
	for path in _SCENES:
		var root: Node = load(path).instantiate()
		for node in _text_nodes(root):
			var variation := String(node.theme_type_variation)
			var px := _font_size(node)
			var floor_px: int = ALLOWED.get(variation, _FLOOR_PX)
			assert_true(px >= floor_px, "%s: %s (%s) resolves to %d px, under %d"
				% [path.get_file(), root.get_path_to(node),
				variation if variation != "" else node.get_class(), px, floor_px])
		root.free()


func test_no_text_here_wears_a_retired_small_style() -> void:
	for path in _SCENES:
		var root: Node = load(path).instantiate()
		for node in _text_nodes(root):
			assert_false(_RETIRED.has(String(node.theme_type_variation)),
				"%s: %s still wears %s"
				% [path.get_file(), root.get_path_to(node), node.theme_type_variation])
		root.free()


func _text_nodes(root: Node) -> Array:
	var out := []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label or (n is Button and (n as Button).text != ""):
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _font_size(node: Control) -> int:
	if node.has_theme_font_size_override("font_size"):
		return node.get_theme_font_size("font_size")
	var t := String(node.theme_type_variation)
	while t != "":
		if _theme.has_font_size("font_size", t):
			return _theme.get_font_size("font_size", t)
		t = String(_theme.get_type_variation_base(t))
	var cls := "Button" if node is Button else "Label"
	if _theme.has_font_size("font_size", cls):
		return _theme.get_font_size("font_size", cls)
	return _theme.default_font_size
