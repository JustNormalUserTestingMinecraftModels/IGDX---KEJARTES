@tool
extends Node

## Headless CI check: loads every script, scene and resource in the project and
## verifies that each dependency exists, so a pull request that breaks a script
## or points a scene at a missing file fails on GitHub. Run it as the main scene:
##
##     godot --headless --path . res://ci/project_check.tscn
##
## Prints `PROJECT CHECK: checked N files, M failures` plus one
## `PROJECT CHECK FAIL:` line per failure, then quits with exit code 1 on any
## failure. Every autoload boots first, so an autoload that errors on boot shows
## up as an ERROR line, which the workflow also fails on.
##
## @tool so tests/test_project_check.gd can call the static helpers from the
## editor, where _ready() does nothing. It lives in res://ci/, outside the
## Scripts/Scenes/tests roots the hygiene suites scan, because printing is its
## whole job. Design: docs/superpowers/specs/2026-09-11-pr-automation-design.md.
##
## It also runs the clean-code scan (ci/clean_code_scan.gd,
## docs/superpowers/design/clean-code.md): a measurement that grew, or a
## must-be-zero rule with a new offender, is a failure; a measurement that
## shrank is printed as a `WARNING:` line, which the workflow copies to the
## step summary without failing -- CI cannot lower a baseline, and a red
## check for an improvement would block every later PR.
##
## The scanner is loaded at run time, never preloaded: it preloads the
## generated ci/clean_code_baseline.gd, and a baseline that does not parse (a
## hand-merged conflict) would otherwise stop this script compiling, leaving
## Godot running the scene with no script until the job times out, log unseen.

## The clean-code ratchet's scanner.
const CLEAN_CODE_SCAN_PATH := "res://ci/clean_code_scan.gd"
## The generated baselines the scanner preloads.
const CLEAN_CODE_BASELINE_PATH := "res://ci/clean_code_baseline.gd"
## The failure reported when either of those does not compile.
const SCAN_LOAD_FAILURE := "clean-code scan did not load: ci/clean_code_baseline.gd or ci/clean_code_scan.gd has a parse error -- never hand-merge the baseline; take one side and run ci/clean_code_dump.gd"

## File extensions the check loads. Textures, audio and fonts are covered
## through the scenes and resources that depend on them.
const CHECKED_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]


## Runs the whole check when this scene is the game's main scene.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# quit() takes effect at the end of the frame and the last call sets the
	# exit code, so if a script error stops this function part-way, Godot
	# still exits -- with 1 -- instead of running until the job times out.
	get_tree().quit(1)
	var files := collect_files("res://")
	var failures := PackedStringArray()
	for path in files:
		failures.append_array(check_file(path))
	var clean_code := run_clean_code_scan()
	failures.append_array(clean_code["failures"])
	print("PROJECT CHECK: checked %d files, %d failures" % [files.size(), failures.size()])
	for failure in failures:
		print("PROJECT CHECK FAIL: ", failure)
	for warning in clean_code["warnings"]:
		print("WARNING: ", warning)
	get_tree().quit(1 if not failures.is_empty() else 0)


## The clean-code scan's {"failures", "warnings"}. A scanner or baseline that
## does not compile is one failure, SCAN_LOAD_FAILURE.
static func run_clean_code_scan() -> Dictionary:
	var scan := load_clean_code_scan()
	if scan == null:
		return {"failures": PackedStringArray([SCAN_LOAD_FAILURE]), "warnings": PackedStringArray()}
	return scan.call("compare_all", scan.call("full_report"))


## The clean-code scanner, loaded now, or null when it or the baseline it
## preloads does not compile. load() hands back a script that failed to parse
## rather than null, so each is also asked whether it can be used.
static func load_clean_code_scan() -> Script:
	for path in [CLEAN_CODE_BASELINE_PATH, CLEAN_CODE_SCAN_PATH]:
		var loaded := load(path) as Script
		if loaded == null or not loaded.can_instantiate():
			return null
	return load(CLEAN_CODE_SCAN_PATH) as Script


## True when the walk must not enter `dir_path`: a dot-folder (.godot, .github,
## .claude), a folder holding a .gdignore, or a nested Godot project -- a
## folder holding its own project.godot, such as -REFERENCE-/prototype. The
## editor ignores the last two as well.
static func should_skip_dir(dir_path: String) -> bool:
	if dir_path == "res://":
		return false
	if dir_path.get_file().begins_with("."):
		return true
	return FileAccess.file_exists(dir_path.path_join(".gdignore")) \
			or FileAccess.file_exists(dir_path.path_join("project.godot"))


## Every file under `root` whose extension is in CHECKED_EXTENSIONS, skipping
## the folders should_skip_dir() rejects.
static func collect_files(root: String) -> PackedStringArray:
	var files := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		if should_skip_dir(dir):
			continue
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() in CHECKED_EXTENSIONS:
				files.append(dir.path_join(file))
	return files


## True when one ResourceLoader.get_dependencies() entry resolves. An entry is
## either a plain path or `uid://<id>::::<fallback path>`; a uid the project
## does not know falls back to the recorded path, as the loader itself does.
static func dependency_exists(dependency: String) -> bool:
	var sections := dependency.split("::")
	var first := sections[0]
	if not first.begins_with("uid://"):
		return ResourceLoader.exists(first)
	var id := ResourceUID.text_to_id(first)
	if ResourceUID.has_id(id) and ResourceLoader.exists(ResourceUID.get_id_path(id)):
		return true
	var fallback := sections[sections.size() - 1] if sections.size() >= 3 else ""
	return not fallback.is_empty() and ResourceLoader.exists(fallback)


## The failures for one file, empty when it passes. Scenes and resources must
## have every dependency on disk and must load; scripts must load and compile.
## load() alone is not enough for a scene: Godot logs a missing texture and
## returns the scene anyway.
static func check_file(path: String) -> PackedStringArray:
	var failures := PackedStringArray()
	if path.get_extension() != "gd":
		for dependency in ResourceLoader.get_dependencies(path):
			if not dependency_exists(dependency):
				failures.append("%s: missing dependency %s" % [path, dependency])
	var resource := ResourceLoader.load(path)
	if resource == null:
		failures.append("%s: failed to load" % path)
		return failures
	var script := resource as Script
	if script != null and not script.can_instantiate() and not script.is_abstract():
		failures.append("%s: script has errors" % path)
	return failures
