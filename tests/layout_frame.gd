@tool
extends RefCounted

## Test helper, not a suite: stands a screen up at a given screen size inside
## the editor's tree and settles it in the same frame, so a test can read its
## real rects without awaiting (the MCP runner never awaits a test).
##
## A Container sorts its children one frame late; anchored children follow
## their parent at once. Verified 2026-09-15 with a throwaway probe: after
## Container.NOTIFICATION_SORT_CHILDREN was sent by hand, a Button two levels
## under a 48 px MarginContainer sat at its final rect in the same frame.
##
## Screen scripts that are not @tool (loby.gd, koprasi.gd, student_card.gd,
## student_list.gd) do not run their _ready here, so no screen side effects
## fire. Used by test_tall_screen_layout.gd, test_lobby_layout.gd and
## test_student_card_layout.gd.

const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


## Instances `scene_path` under a frame of `screen` size in the editor's root,
## with the baked theme, and settles its Containers. Returns the frame: the
## caller passes it to track() so the runner frees it, and reads the screen
## as frame.get_child(0).
static func stand_up(scene_path: String, screen: Vector2) -> Control:
	var frame := Control.new()
	frame.size = screen
	frame.theme = load(THEME_PATH)
	var root := (load(scene_path) as PackedScene).instantiate() as Control
	frame.add_child(root)
	Engine.get_main_loop().root.add_child(frame)
	settle(root)
	return frame


## Sends every Container under `node` its sort notification, parents first,
## so each child's rect is final now instead of next frame.
static func settle(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		settle(child)
