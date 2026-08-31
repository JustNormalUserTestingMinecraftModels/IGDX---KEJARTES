@tool
extends McpTestSuite

## Repo-wide invariants that no single screen's suite owns.
##
## Both tests here derive truth from the engine or the filesystem rather than
## from a hand-maintained list, so they keep working as scenes and scripts are
## added. Neither instantiates anything, so both are cheap and neither needs
## the main scene open.
##
## This suite must be @tool or the runner reports the class abstract/broken,
## and no test here may be a coroutine -- the runner calls suite.call(name)
## without awaiting.

func suite_name() -> String:
	return "project_hygiene"


## Read a `key="value"` attribute out of a .tscn header line. Returns "" when
## the key is absent, which is normal: ext_resource lines written before UIDs
## existed carry only a path.
func _attr(line: String, key: String) -> String:
	var needle := key + "=\""
	var start := line.find(needle)
	if start == -1:
		return ""
	start += needle.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


## Every res:// file under `root` whose name ends with `suffix`.
func _all_files_under(root: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(suffix):
				out.append(dir.path_join(f))
	return out


func test_every_scene_ext_resource_uid_resolves_to_its_own_asset() -> void:
	# A wrong UID is only a warning -- Godot falls back to the text path and
	# the scene still loads -- but the warnings are per-load and they crowd out
	# real diagnostics. One wrong UID for paper.png had been copy-pasted into
	# three separate scenes before this test existed.
	var offenders: Array[String] = []
	for scene_path in _all_files_under("res://Scenes", ".tscn"):
		var text := FileAccess.get_file_as_string(scene_path)
		for line in text.split("\n"):
			if not line.begins_with("[ext_resource "):
				continue
			var uid_text := _attr(line, "uid")
			var res_path := _attr(line, "path")
			if uid_text == "" or res_path == "":
				continue
			var id := ResourceUID.text_to_id(uid_text)
			if id == -1 or not ResourceUID.has_id(id):
				offenders.append("%s: %s is not a known UID (%s)"
					% [scene_path, uid_text, res_path])
			elif ResourceUID.get_id_path(id) != res_path:
				offenders.append("%s: %s resolves to %s, but the line claims %s"
					% [scene_path, uid_text, ResourceUID.get_id_path(id), res_path])
	assert_eq(offenders.size(), 0,
		"every ext_resource UID must resolve to the asset on its own line; offenders: "
			+ ", ".join(offenders))


func test_no_debug_prints_survive_in_production_scripts() -> void:
	# Scripts/Debug/ is the in-game debug overlay -- printing is its job.
	# Everywhere else a DEBUG print is a leftover, and they are not harmless:
	# atur_jadwal.gd dumped the entire selected_student dictionary six times
	# per selection, crowding real diagnostics out of a finite log buffer.
	var offenders: Array[String] = []
	for script_path in _all_files_under("res://Scripts", ".gd"):
		if script_path.begins_with("res://Scripts/Debug/"):
			continue
		var text := FileAccess.get_file_as_string(script_path)
		var lines := text.split("\n")
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("print(\"DEBUG"):
				offenders.append("%s:%d" % [script_path, i + 1])
	assert_eq(offenders.size(), 0,
		"DEBUG prints must not ship outside Scripts/Debug/; offenders: "
			+ ", ".join(offenders))


## The boot scene moved off Splashscreen on 2026-08-31. Splashscreen.tscn and
## Loading.tscn still exist and are still covered by test_boot_screens.gd;
## they are simply no longer reached at startup. Pinned here because nothing
## else in the suite asserts run/main_scene, so a stray edit would go unseen.
func test_the_boot_scene_is_the_main_menu() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(main_scene, "res://Scenes/MainMenu/main_menu.tscn",
		"run/main_scene")
	assert_true(ResourceLoader.exists(main_scene),
		"the boot scene must actually exist")
