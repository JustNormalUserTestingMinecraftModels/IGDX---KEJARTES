@tool
extends McpTestSuite

## Keeps the pull-request automation's moving parts naming the same things:
## the merge gate (ci/auto_merge.sh), the workflows that produce the check runs
## it requires, and the ship-pr skill that posts the stamps it requires. A
## rename that misses one file would leave every PR waiting, silently.
##
## Source-text scans, as elsewhere in this project: the engine never loads
## these files. This suite must be @tool, and no test may be a coroutine.

## The merge gate.
const GATE := "res://ci/auto_merge.sh"
## The headless check workflow.
const CHECK_WORKFLOW := "res://.github/workflows/project-check.yml"
## The cloud review workflow.
const REVIEW_WORKFLOW := "res://.github/workflows/claude-review.yml"
## The workflow that runs the gate.
const MERGE_WORKFLOW := "res://.github/workflows/auto-merge.yml"


## The runner's name for this suite.
func suite_name() -> String:
	return "pr_automation"


## The text of `path`; fails the test when the file is missing.
func _read(path: String) -> String:
	assert_true(FileAccess.file_exists(path), path + " must exist")
	return FileAccess.get_file_as_string(path)


func test_the_gate_requires_check_runs_the_workflows_produce() -> void:
	var gate := _read(GATE)
	assert_true(gate.contains("CHECK_RUN=\"project-check\""), "gate requires project-check")
	assert_true(gate.contains("REVIEW_RUN=\"claude-review\""), "gate requires claude-review")
	assert_true(_read(CHECK_WORKFLOW).contains("name: project-check"), "project-check job")
	assert_true(_read(REVIEW_WORKFLOW).contains("name: claude-review"), "claude-review job")


func test_auto_merge_wakes_on_both_check_workflows_by_name() -> void:
	assert_true(_read(CHECK_WORKFLOW).contains("\nname: Project check\n"), "Project check")
	assert_true(_read(REVIEW_WORKFLOW).contains("\nname: Claude review\n"), "Claude review")
	assert_true(_read(MERGE_WORKFLOW).contains("workflows: [Project check, Claude review]"),
		"auto-merge.yml's workflow_run must list both workflows")


func test_the_workflow_runs_the_check_scene() -> void:
	assert_true(_read(CHECK_WORKFLOW).contains("res://ci/project_check.tscn"),
		"project-check.yml must run the check scene")
	assert_true(FileAccess.file_exists("res://ci/project_check.tscn"), "the scene exists")


func test_ci_runs_the_godot_minor_version_the_project_targets() -> void:
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	var target := features[0]
	assert_true(_read(CHECK_WORKFLOW).contains("GODOT_VERSION: " + target + "."),
		"project-check.yml must pin a Godot " + target + ".x build")


func test_every_action_is_pinned_to_a_commit() -> void:
	# The `uses:` key itself, not any line containing the text: `statuses:`
	# in a permissions block contains it too.
	var uses_key := RegEx.create_from_string("^\\s*(-\\s+)?uses:")
	var pinned := RegEx.create_from_string("uses: [\\w.-]+/[\\w.-]+@[0-9a-f]{40}(\\s|$)")
	var workflows: Array[String] = [CHECK_WORKFLOW, REVIEW_WORKFLOW, MERGE_WORKFLOW]
	var offenders := PackedStringArray()
	for path in workflows:
		for line in _read(path).split("\n"):
			if uses_key.search(line) != null and pinned.search(line) == null:
				offenders.append(path.get_file() + ": " + line.strip_edges())
	assert_eq(offenders, PackedStringArray(),
		"every uses: must name a 40-character commit; unpinned: %s" % [offenders])
