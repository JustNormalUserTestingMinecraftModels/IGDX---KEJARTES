@tool
extends RefCounted

## Test helper, not a suite: reads a saved scene's nodes from its PackedScene
## state without instancing it, so placement tests stay cheap on a full run
## (instancing per test floods the deferred-call queue). Used by
## test_ambient_kit.gd and test_lobby_look.gd.
##
## Every entry is {path, type, instance, props}: `path` relative to the root
## ("." for the root itself), `instance` the instanced scene's path or "",
## `props` only the properties the file sets.


## Every node of `scene_path` in file (= tree) order.
static func of(scene_path: String) -> Array[Dictionary]:
	var state := (load(scene_path) as PackedScene).get_state()
	var out: Array[Dictionary] = []
	for i in state.get_node_count():
		var inst := state.get_node_instance(i)
		var props := {}
		for j in state.get_node_property_count(i):
			props[str(state.get_node_property_name(i, j))] = state.get_node_property_value(i, j)
		out.append({
			"path": str(state.get_node_path(i)).trim_prefix("./"),
			"type": str(state.get_node_type(i)),
			"instance": inst.resource_path if inst != null else "",
			"props": props,
		})
	return out


## The entry at `path`, or {} when the scene has no such node.
static func entry(census: Array[Dictionary], path: String) -> Dictionary:
	for e in census:
		if e["path"] == path:
			return e
	return {}


## A property the file sets on `entry`, or `fallback` when it leaves it default.
static func prop(entry: Dictionary, name: String, fallback: Variant = null) -> Variant:
	return (entry.get("props", {}) as Dictionary).get(name, fallback)


## Direct children of `parent` ("." for the root), in draw order.
static func children_of(census: Array[Dictionary], parent: String) -> Array[String]:
	var out: Array[String] = []
	for e in census:
		var p: String = e["path"]
		if p == ".":
			continue
		var dad := "." if not p.contains("/") else p.get_base_dir()
		if dad == parent:
			out.append(p.get_file())
	return out
