@tool
extends RefCounted

## Debug-only: clears the open scene out of the way of a standalone minigame
## launched from the debug overlay (DebugManager is its only caller), and puts
## it back afterwards.
##
## A minigame lit the Lobby way keeps its art on a `World` CanvasLayer at -1
## under its own WorldEnvironment. Launched over a scene, that art would sit
## below the scene's layer-0 picture, and the scene's own WorldEnvironment
## (first in the tree) would win over the minigame's. So hide() hides the
## scene's canvas and lifts its environments out of the tree. A HIDDEN
## CanvasLayer at -1 or below also switches a Canvas-mode glow off altogether
## (measured 2026-09-30: +0.0104 back the moment it moved up), so the scene's
## own `World` is parked at layer 0 while hidden.

## The was_layer a stashed CanvasItem carries: it has no layer to put back.
const NO_LAYER := -1000

## [node, was_visible, was_layer] for everything hide() hid.
var _visibility: Array = []
## [environment, parent, index] for every WorldEnvironment hide() lifted out.
var _environments: Array = []


## Hides `scene`'s canvas, parks its negative CanvasLayers at 0 and lifts its
## WorldEnvironments out of the tree. A null scene is a no-op.
func hide(scene: Node) -> void:
	if scene == null:
		return
	var items: Array[Node] = [scene]
	items.append_array(scene.find_children("*", "CanvasLayer", true, false))
	for item in items:
		if item is CanvasLayer:
			var canvas := item as CanvasLayer
			_visibility.append([canvas, canvas.visible, canvas.layer])
			canvas.visible = false
			canvas.layer = maxi(canvas.layer, 0)
		elif item is CanvasItem:
			_visibility.append([item, (item as CanvasItem).visible, NO_LAYER])
			(item as CanvasItem).visible = false
	for env in scene.find_children("*", "WorldEnvironment", true, false):
		var parent := env.get_parent()
		_environments.append([env, parent, env.get_index()])
		parent.remove_child(env)


## Undoes hide(). An environment whose scene went away meanwhile is freed
## rather than leaked.
func restore() -> void:
	for entry in _environments:
		var env: Node = entry[0]
		var parent: Node = entry[1]
		if is_instance_valid(parent):
			parent.add_child(env)
			parent.move_child(env, mini(entry[2], parent.get_child_count() - 1))
		else:
			env.free()
	for entry in _visibility:
		if not is_instance_valid(entry[0]):
			continue
		(entry[0] as Node).set("visible", entry[1])
		if entry[2] != NO_LAYER:
			(entry[0] as CanvasLayer).layer = entry[2]
	_environments.clear()
	_visibility.clear()
