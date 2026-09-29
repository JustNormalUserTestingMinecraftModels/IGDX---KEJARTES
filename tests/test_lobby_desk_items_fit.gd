@tool
extends McpTestSuite

## Every Lobby desk item (the Hand_<Name> nodes) stays inside its desk's
## width, in every skin's table art. An item wider than its desk hangs off both edges and reads as
## floating, which is how the 1.1-1.26x hand-tuned scales looked before
## 2026-09-29.
##
## Measured from the packed scene's SceneState, so the Lobby is never
## instanced. A Hand_* node draws its texture at native size
## (stretch_mode 3) centred in its box, then scales about pivot_offset; a
## desk is a full-classroom plate whose opaque bbox is the desk, clipped to
## the classroom since the front desks run off its sides.
##
## Must be @tool, and no test here may be a coroutine.

## The scene under test.
const SCENE := "res://Scenes/Lobby/Lobby.tscn"
## The 1080x1920 plate every desk and hand slot is laid out in.
const CLASSROOM := "World/Classroom"
## The classroom's width; a desk's span is clipped to it.
const CLASSROOM_WIDTH := 1080.0
## The desk plate each hand slot sits on.
const SLOT_DESK := {
	"StudentHandsContainer_Back/Slot1": "Meja_KiriAtas",
	"StudentHandsContainer_Back/Slot2": "Meja_KananAtas",
	"StudentHandsContainer_Front/Slot3": "Meja_KiriBawah",
	"StudentHandsContainer_Front/Slot4": "Meja_KananBawah",
}
## Four slots, each carrying one Hand_* node per character.
const EXPECTED_HANDS := 24
## Slack for the scene's float offsets, in pixels.
const TOLERANCE := 0.5

## Written properties per node, keyed by path under the scene root.
var _props: Dictionary


## The runner's name for this suite.
func suite_name() -> String:
	return "lobby_desk_items_fit"


## Reads the scene's node properties once for every test.
func suite_setup(_ctx: Dictionary) -> void:
	_props = read_scene_props(load(SCENE) as PackedScene)


## Every node's written properties, keyed by its path under the root.
static func read_scene_props(scene: PackedScene) -> Dictionary:
	var state := scene.get_state()
	var out := {}
	for i in state.get_node_count():
		var props := {}
		for j in state.get_node_property_count(i):
			props[state.get_node_property_name(i, j)] = state.get_node_property_value(i, j)
		out[String(state.get_node_path(i)).trim_prefix("./")] = props
	return out


## The x-range, in classroom pixels, a Hand_* node draws a texture
## `tex_width` px wide over. Slots are unanchored children of full-rect
## containers, whose own left offset is added in.
static func hand_span(container: Dictionary, slot: Dictionary, hand: Dictionary,
		tex_width: float) -> Vector2:
	var slot_left: float = float(container.get("offset_left", 0.0)) + float(slot.get("offset_left", 0.0))
	var slot_width: float = float(slot.get("offset_right", 0.0)) - slot_left
	var box_offset: float = hand.get("offset_left", 0.0)
	var box_left: float = slot_left + float(hand.get("anchor_left", 0.0)) * slot_width + box_offset
	var box_width: float = float(hand.get("offset_right", 0.0)) - box_offset
	var sx: float = (hand.get("scale", Vector2.ONE) as Vector2).x
	var px: float = (hand.get("pivot_offset", Vector2.ZERO) as Vector2).x
	var centre: float = box_left + px + (box_width / 2.0 - px) * sx
	var half: float = tex_width * absf(sx) / 2.0
	return Vector2(centre - half, centre + half)


## The widest desk art `student` can wear: the Lobby swaps each skin's
## table image onto the same node, at the same transform.
static func widest_hand_art(student: String) -> float:
	var widest := 0.0
	for id: String in StudentSkins.SKINS[student]:
		var tex := load(StudentSkins.layer_path(student, id, "hand")) as Texture2D
		widest = maxf(widest, tex.get_width())
	return widest


## The x-range of a desk plate's opaque pixels, through its scale and
## pivot, clipped to the classroom.
static func desk_span(desk: Dictionary) -> Vector2:
	var used: Rect2i = (desk["texture"] as Texture2D).get_image().get_used_rect()
	var sx: float = (desk.get("scale", Vector2.ONE) as Vector2).x
	var px: float = (desk.get("pivot_offset", Vector2.ZERO) as Vector2).x
	var ox: float = desk.get("offset_left", 0.0)
	var left: float = ox + px + (used.position.x - px) * sx
	var right: float = ox + px + (used.end.x - px) * sx
	return Vector2(maxf(left, 0.0), minf(right, CLASSROOM_WIDTH))


## One node's properties, by its path under the classroom.
func _node(path: String) -> Dictionary:
	return _props["%s/%s" % [CLASSROOM, path]]


func test_every_desk_item_fits_its_desk() -> void:
	var checked := 0
	for slot_path: String in SLOT_DESK:
		var desk: Vector2 = desk_span(_node(SLOT_DESK[slot_path]))
		var container: Dictionary = _node(slot_path.get_base_dir())
		var prefix := "%s/%s/Hand_" % [CLASSROOM, slot_path]
		for path: String in _props:
			if not path.begins_with(prefix):
				continue
			var art: float = widest_hand_art(path.trim_prefix(prefix))
			var span: Vector2 = hand_span(container, _node(slot_path), _props[path], art)
			assert_true(span.x >= desk.x - TOLERANCE and span.y <= desk.y + TOLERANCE,
				"%s draws x %.0f..%.0f, past its desk's %.0f..%.0f"
					% [path.get_file(), span.x, span.y, desk.x, desk.y])
			checked += 1
	assert_eq(checked, EXPECTED_HANDS, "every slot's Hand_* nodes were measured")


## Positive control: the measure flags the pre-fix Citra, 522 px at 1.1007x
## (575 px) on a 455 px desk.
func test_the_measure_catches_an_overscaled_item() -> void:
	var slot_path := "StudentHandsContainer_Back/Slot1"
	var hand: Dictionary = _node(slot_path + "/Hand_Citra").duplicate()
	hand["scale"] = Vector2(1.1007, 1.1007)
	var span: Vector2 = hand_span(_node(slot_path.get_base_dir()), _node(slot_path), hand,
		(hand["texture"] as Texture2D).get_width())
	var desk: Vector2 = desk_span(_node(SLOT_DESK[slot_path]))
	assert_gt(span.y - span.x, desk.y - desk.x, "the old Citra is wider than the desk")
