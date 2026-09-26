@tool
extends McpTestSuite

## Guards ci/project_check.gd, the headless check every pull request runs on
## GitHub: which folders its walk enters, which files it returns, and how it
## resolves ResourceLoader dependency entries. The check itself only runs as a
## game; these tests call its static helpers from the editor.
##
## This suite must be @tool or the runner reports the class abstract/broken,
## and no test here may be a coroutine -- the runner calls suite.call(name)
## without awaiting.

## The script under test.
const CHECK := preload("res://ci/project_check.gd")
## A scene that exists, has a uid and loads cleanly.
const MAIN_SCENE := "res://Scenes/MainMenu/main_menu.tscn"
## A path that exists nowhere.
const MISSING := "res://Assets/does_not_exist.png"


## The runner's name for this suite.
func suite_name() -> String:
	return "project_check"


func test_the_walk_enters_the_root_and_ordinary_folders() -> void:
	assert_false(CHECK.should_skip_dir("res://"), "res://")
	assert_false(CHECK.should_skip_dir("res://Scripts"), "res://Scripts")


func test_the_walk_skips_dot_folders() -> void:
	assert_true(CHECK.should_skip_dir("res://.godot"), "res://.godot")
	assert_true(CHECK.should_skip_dir("res://.github"), "res://.github")


func test_the_walk_skips_gdignored_folders() -> void:
	assert_true(FileAccess.file_exists("res://docs/.gdignore"),
		"fixture: docs/ carries a .gdignore")
	assert_true(CHECK.should_skip_dir("res://docs"), "res://docs")


func test_the_walk_skips_nested_godot_projects() -> void:
	assert_true(FileAccess.file_exists("res://-REFERENCE-/prototype/project.godot"),
		"fixture: the prototype is a project of its own")
	assert_true(CHECK.should_skip_dir("res://-REFERENCE-/prototype"), "the prototype")


func test_collect_files_returns_scripts_scenes_and_resources_only() -> void:
	var files: PackedStringArray = CHECK.collect_files("res://")
	assert_true(files.has(MAIN_SCENE), MAIN_SCENE)
	assert_true(files.has("res://ci/project_check.gd"), "the check itself")
	assert_true(files.has("res://Assets/Theme/kejartes_theme.tres"), "the baked theme")
	var offenders := PackedStringArray()
	for path in files:
		var wrong_type := not (path.get_extension() in CHECK.CHECKED_EXTENSIONS)
		var ignored_folder := path.begins_with("res://-REFERENCE-/") \
				or path.begins_with("res://.godot/") or path.begins_with("res://docs/")
		if wrong_type or ignored_folder:
			offenders.append(path)
	assert_eq(offenders, PackedStringArray(), "files the walk must not return")


func test_a_plain_path_dependency_resolves_only_when_the_file_exists() -> void:
	assert_true(CHECK.dependency_exists(MAIN_SCENE), MAIN_SCENE)
	assert_false(CHECK.dependency_exists(MISSING), MISSING)


func test_a_known_uid_resolves_even_with_a_stale_fallback_path() -> void:
	var uid_text := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(MAIN_SCENE))
	assert_true(uid_text.begins_with("uid://"), "fixture: the main scene has a uid")
	assert_true(CHECK.dependency_exists(uid_text + "::::" + MISSING), uid_text)


func test_an_unknown_uid_falls_back_to_its_recorded_path() -> void:
	assert_true(CHECK.dependency_exists("uid://nonexistentuid::::" + MAIN_SCENE),
		"unknown uid, real path")
	assert_false(CHECK.dependency_exists("uid://nonexistentuid::::" + MISSING),
		"unknown uid, missing path")


func test_check_file_passes_a_healthy_scene() -> void:
	assert_eq(CHECK.check_file(MAIN_SCENE), PackedStringArray(), MAIN_SCENE)


func test_the_check_scene_runs_the_check_script() -> void:
	var scene := FileAccess.get_file_as_string("res://ci/project_check.tscn")
	assert_true(scene.contains("path=\"res://ci/project_check.gd\""),
		"project_check.tscn must attach ci/project_check.gd")


func test_the_check_runs_the_clean_code_scan_and_only_warns_on_a_shrink() -> void:
	var src := FileAccess.get_file_as_string("res://ci/project_check.gd")
	assert_true(src.contains("var clean_code := run_clean_code_scan()"),
		"_ready runs the clean-code scan")
	assert_true(src.contains("scan.call(\"compare_all\", scan.call(\"full_report\"))"),
		"the scan compares the whole report with the baseline")
	assert_true(src.contains("failures.append_array(clean_code[\"failures\"])"),
		"growth and must-be-zero violations fail CI")
	assert_true(src.contains("print(\"WARNING: \", warning)"),
		"a shrink is only a warning in CI")


## A baseline that does not parse must be a reported failure, never a check
## script that fails to compile and leaves Godot running until the job times
## out: the scanner is loaded at run time, and _ready quits with 1 first.
func test_a_broken_baseline_cannot_hang_the_check() -> void:
	var src := FileAccess.get_file_as_string("res://ci/project_check.gd")
	assert_false(src.contains("preload(\"res://ci/clean_code_scan.gd\")"),
		"the scanner is not preloaded")
	var early_quit := src.find("get_tree().quit(1)\n")
	assert_true(early_quit != -1 and early_quit < src.find("collect_files(\"res://\")\n"),
		"_ready quits with 1 before any work, so a script error still exits")
	assert_true(CHECK.SCAN_LOAD_FAILURE.contains("ci/clean_code_dump.gd"),
		"the load failure says how to recover")
	assert_true(CHECK.load_clean_code_scan() != null,
		"today's scanner and baseline load")
