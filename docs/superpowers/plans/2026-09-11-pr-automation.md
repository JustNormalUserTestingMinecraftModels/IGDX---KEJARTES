# Pull-request automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pull requests open, check, review and merge without a person at the keyboard: a headless Godot check and a cloud Claude review on GitHub, a local ship procedure that stamps tested commits, and a merge gate that merges `brineoutxd`'s PRs into `Textures` when every gate is green.

**Architecture:** A `@tool` GDScript scene (`ci/project_check.tscn`) runs headless on GitHub and loads every script, scene and resource. A pure bash function (`gate_decision` in `ci/auto_merge.sh`) holds the merge rules; a thin `gh` layer around it reads check runs, commit statuses and the compare API, and a workflow runs it on every relevant event. A Claude Code project skill (`ship-pr`) runs the editor suite and a local review, then stamps the tested commit with two commit statuses the gate requires.

**Tech Stack:** GitHub Actions (`ubuntu-latest`), Godot 4.6.2 headless, bash + `gh` (its built-in `--jq`; there is no standalone `jq` on the dev machine), GDScript `McpTestSuite`, `anthropics/claude-code-action` v1, a Claude Code project skill.

**Spec:** `docs/superpowers/specs/2026-09-11-pr-automation-design.md`.

## Global Constraints

- Godot **4.6.2-stable** everywhere. Linux build `Godot_v4.6.2-stable_linux.x86_64.zip`, SHA-512 `b6e4d5a716085e9649905be2afe77f723f97853544fb33392ce3d32594c730a95d9eb4d1042ed51508904c9e1d996bd36b7c7a2bf4f93f5b1885e98d81b792e7` (from the release's `SHA512-SUMS.txt`).
- Actions are pinned to commits: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`, `anthropics/claude-code-action@0a8d3c9443bbff909ab973b6a17a340b913f229f # v1`.
- Names that must match across every file: check runs `project-check` and `claude-review`; commit statuses `kejartes/editor-tests`, `kejartes/local-review`, `kejartes/up-to-date`; label `hold`; workflows `Project check`, `Claude review`, `Auto-merge`.
- The gate merges only PRs authored by `brineoutxd` into `Textures`, as a merge commit (`gh pr merge --merge`), and never deletes a branch.
- Cloud review model `claude-opus-5`, `--max-turns 40`.
- GDScript: every new `.gd` is `@tool`, has a `##` file header and a `##` line on every function and constant; never infer a type from a `Variant` with `:=` (this project treats `inference_on_variant` as an error); no test is a coroutine; `assert_contains` accepts only `String` and `Array`, so test a `PackedStringArray` with `.has()`.
- Commit each new script's `.gd.uid` sidecar; the repo tracks them (487 today).
- Commits: Conventional Commits with a scope, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Work only in the worktree `.claude/worktrees/pr-automation` (branch `feat/pr-automation`). Never edit the main checkout and never kill the user's editor.

## Verification environment

- **Editor.** GDScript suites run in a *second* Godot editor opened on the worktree (Task 1, Step 1). Pass `session_id` on every godot-ai call and never call `session_activate`: other sessions share the server. Only the controller session touches the editor; a subagent writes files and the controller runs `test_run` and reports back.
- **Stray writes.** The worktree editor's boot and any game run rewrite `Assets/Audio/default_bus_layout.tres`; a full `test_run` also rebakes `Assets/Theme/kejartes_theme.tres`. Before every commit run `git -C "$WT" status --short` and `git -C "$WT" checkout -- <file>` for either one you did not mean to change.
- **Shell.** Git Bash. Paths handed to Godot must be Windows-style (`C:/...`) and the shell must not rewrite `res://` arguments, so set `export MSYS2_ARG_CONV_EXCL="*"` before calling Godot.
- **Binaries.** Editor: `C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe`. Headless runs: the `_console.exe` beside it. The outer `Godot_v4.6.2-stable_win64.exe` is a **directory**.
- **Shorthands used below:** `MAIN=C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project`, `WT=$MAIN/.claude/worktrees/pr-automation`, `GODOT_CONSOLE=C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`, `WT_SESSION` = the worktree editor's godot-ai session id.

## File structure

| File | Responsibility |
|---|---|
| `ci/project_check.gd` | Walks `res://`, loads every script/scene/resource, checks every dependency exists, prints the result, exits 1 on a failure. Static helpers for tests. |
| `ci/project_check.tscn` | Bare `Node` running the check, so it runs as a main scene with every autoload booted. |
| `ci/selftest_project_check.sh` | Local end-to-end proof: the clean tree passes; a parse error, a missing texture and a failing autoload each fail. |
| `ci/auto_merge.sh` | The merge gate: `gate_decision` (pure) plus the `gh` layer and `main`. `DRY_RUN=1` prints instead of acting. |
| `ci/test_auto_merge.sh` | Unit tests for `gate_decision`. No network. |
| `.github/workflows/project-check.yml` | Runs the gate's unit tests and the headless check on every PR and on pushes to `Textures`. |
| `.github/workflows/claude-review.yml` | Cloud review with a `pass`/`block` verdict; skipped without a key. |
| `.github/workflows/auto-merge.yml` | Decides when to run `ci/auto_merge.sh` and with which permissions. |
| `.claude/skills/ship-pr/SKILL.md` | The local finish-a-branch procedure that posts the two stamps. |
| `tests/test_project_check.gd` | Suite for the check's static helpers and its scene. |
| `tests/test_pr_automation.gd` | Keeps the gate, the workflows and the skill naming the same things. |
| `CLAUDE.md`, `docs/superpowers/CHANGELOG.md` | A `## Pull requests` section, the suite count, `## Current work`, and the changelog entry. |

---

### Task 1: Headless project check

**Files:**
- Create: `ci/project_check.gd`, `ci/project_check.tscn` (through the editor), `ci/selftest_project_check.sh`
- Test: `tests/test_project_check.gd`
- Generated, commit them: `ci/project_check.gd.uid`, `tests/test_project_check.gd.uid`

**Interfaces:**
- Consumes: nothing.
- Produces: `res://ci/project_check.tscn`, run as the main scene. Static functions on `res://ci/project_check.gd`: `should_skip_dir(dir_path: String) -> bool`, `collect_files(root: String) -> PackedStringArray`, `dependency_exists(dependency: String) -> bool`, `check_file(path: String) -> PackedStringArray`; constant `CHECKED_EXTENSIONS: PackedStringArray`. Output lines `PROJECT CHECK: checked N files, M failures` and `PROJECT CHECK FAIL: <path>: <reason>`; exit code 1 on any failure. The workflow (Task 3) calls `res://ci/project_check.tscn` by that path.

- [ ] **Step 1: Open a second editor on the worktree**

Seed the worktree's import cache from the main checkout so it boots without a reimport (skip `.godot/editor/`, so no tabs are restored), then launch it with `run_in_background: true`:

```bash
MAIN="C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
WT="$MAIN/.claude/worktrees/pr-automation"
mkdir -p "$WT/.godot"
for p in imported shader_cache uid_cache.bin global_script_class_cache.cfg scene_groups_cache.cfg; do
  cp -r "$MAIN/.godot/$p" "$WT/.godot/"
done
"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --path "$WT" -e
```

Poll `session_manage(op="list")` until a session whose `project_path` is the worktree appears (about a minute). Record its `session_id` as `WT_SESSION`. Do not activate it.

- [ ] **Step 2: Write the failing suite**

Create `tests/test_project_check.gd`:

```gdscript
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
```

- [ ] **Step 3: Run it and watch it fail**

Call `filesystem_manage(op="scan", session_id=WT_SESSION)`, then `test_run(suite="project_check", session_id=WT_SESSION)`.
Expected: FAIL. The suite cannot load because `res://ci/project_check.gd` does not exist (reported as a broken or abstract suite, or a preload error).

- [ ] **Step 4: Write the check**

Create `ci/project_check.gd`:

```gdscript
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

## File extensions the check loads. Textures, audio and fonts are covered
## through the scenes and resources that depend on them.
const CHECKED_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]


## Runs the whole check when this scene is the game's main scene.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var files := collect_files("res://")
	var failures := PackedStringArray()
	for path in files:
		failures.append_array(check_file(path))
	print("PROJECT CHECK: checked %d files, %d failures" % [files.size(), failures.size()])
	for failure in failures:
		print("PROJECT CHECK FAIL: ", failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


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
```

- [ ] **Step 5: Register the script and create the scene through the editor**

1. `filesystem_manage(op="scan", session_id=WT_SESSION)`. The editor writes `ci/project_check.gd.uid` and `tests/test_project_check.gd.uid`.
2. `scene_manage(op="create", params={"path": "res://ci/project_check.tscn", "root_type": "Node", "root_name": "ProjectCheck"}, session_id=WT_SESSION)`
3. `script_attach(path="/ProjectCheck", script_path="res://ci/project_check.gd", session_id=WT_SESSION)`
4. `scene_save(session_id=WT_SESSION)`

Check: `git -C "$WT" status --short` lists `ci/project_check.gd`, `ci/project_check.gd.uid`, `ci/project_check.tscn`, `tests/test_project_check.gd`, `tests/test_project_check.gd.uid`. `ci/project_check.tscn` contains `path="res://ci/project_check.gd"`.

- [ ] **Step 6: Run the suite and watch it pass**

`test_run(suite="project_check", session_id=WT_SESSION)`
Expected: PASS, 10 tests, 0 failures. If it serves a stale script, make a no-op `script_patch` on `ci/project_check.gd` (CLAUDE.md, "Rescan after editing a `.gd`") and run it again.

- [ ] **Step 7: Write the end-to-end self-test**

Create `ci/selftest_project_check.sh`:

```bash
#!/usr/bin/env bash
# End-to-end self-test for the headless project check (ci/project_check.gd).
# Copies the working tree (tracked and new files, not ignored ones) to a temp
# folder, imports it, requires the check to PASS on the clean copy, then plants
# one breakage at a time -- a script that does not parse, a scene pointing at a
# missing texture, an autoload that errors on boot -- and requires each to FAIL.
# Local only: CI runs the check itself, not this.
#
#     bash ci/selftest_project_check.sh <path-to-godot-console-binary>
set -uo pipefail

GODOT="${1:?usage: selftest_project_check.sh <path-to-godot-binary>}"
ROOT="$(git rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export MSYS2_ARG_CONV_EXCL="*"   # Git Bash: hand res:// paths to Godot untouched
PROJECT="$WORK/p"
GODOT_PROJECT="$PROJECT"
if command -v cygpath > /dev/null; then GODOT_PROJECT="$(cygpath -m "$PROJECT")"; fi
failures=0

# The working tree, under its own user:// folder so the check never touches a
# developer's save data, freshly imported.
mkdir -p "$PROJECT"
( cd "$ROOT" && git ls-files -z --cached --others --exclude-standard \
    | tar --null --ignore-failed-read -cf - -T - ) | tar -xf - -C "$PROJECT"
sed -i 's/^config\/name="\(.*\)"/config\/name="\1-selftest"/' "$PROJECT/project.godot"
cp "$PROJECT/project.godot" "$WORK/project.godot.clean"
"$GODOT" --headless --path "$GODOT_PROJECT" --import > "$WORK/import.log" 2>&1

# run_check <pass|fail> <description>: runs the check the way the workflow does.
run_check() {
  "$GODOT" --headless --path "$GODOT_PROJECT" res://ci/project_check.tscn > "$WORK/check.log" 2>&1
  local status=$? errors verdict=pass
  errors=$(grep -cE '^(ERROR|SCRIPT ERROR):' "$WORK/check.log")
  if (( status != 0 || errors > 0 )); then verdict=fail; fi
  if [[ "$verdict" == "$1" ]]; then
    echo "ok   - $2 ($verdict: exit $status, $errors error lines)"
  else
    echo "FAIL - $2: expected $1, got $verdict (exit $status, $errors error lines)"
    grep -E '^(PROJECT CHECK|ERROR|SCRIPT ERROR)' "$WORK/check.log" | head -20
    failures=$((failures + 1))
  fi
}

run_check pass "the clean tree passes"

printf 'extends Node\nfunc broken(:\n\tpass\n' > "$PROJECT/Scripts/zz_selftest_broken.gd"
run_check fail "a script that does not parse fails"
rm "$PROJECT/Scripts/zz_selftest_broken.gd"

cat > "$PROJECT/Scenes/zz_selftest_missing.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://Assets/zz_does_not_exist.png" id="1_missing"]

[node name="Missing" type="Sprite2D"]
texture = ExtResource("1_missing")
EOF
run_check fail "a scene pointing at a missing texture fails"
rm "$PROJECT/Scenes/zz_selftest_missing.tscn"

printf 'extends Node\nfunc _ready() -> void:\n\tpush_error("selftest: autoload failed on boot")\n' \
  > "$PROJECT/zz_selftest_autoload.gd"
sed -i 's/^\[autoload\]$/[autoload]\n\nZzSelftest="*res:\/\/zz_selftest_autoload.gd"/' "$PROJECT/project.godot"
run_check fail "an autoload that errors on boot fails"
cp "$WORK/project.godot.clean" "$PROJECT/project.godot"
rm "$PROJECT/zz_selftest_autoload.gd"

echo "$failures failure(s)"
exit $(( failures > 0 ))
```

- [ ] **Step 8: Run the self-test**

```bash
export MSYS2_ARG_CONV_EXCL="*"
cd "$WT" && bash ci/selftest_project_check.sh "C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe"
```

Expected, in about a minute:

```
ok   - the clean tree passes (pass: exit 0, 0 error lines)
ok   - a script that does not parse fails (fail: ...)
ok   - a scene pointing at a missing texture fails (fail: ...)
ok   - an autoload that errors on boot fails (fail: ...)
0 failure(s)
```

If the clean tree fails, read the printed `PROJECT CHECK FAIL` and `ERROR` lines. The probe on 2026-09-11 found 0 of either on this tree, so a failure here is new and must be fixed, not suppressed.

- [ ] **Step 9: Commit**

```bash
cd "$WT"
git status --short          # revert Assets/Audio/default_bus_layout.tres if it changed
git add ci/project_check.gd ci/project_check.gd.uid ci/project_check.tscn \
        ci/selftest_project_check.sh tests/test_project_check.gd tests/test_project_check.gd.uid
git commit -m "feat(ci): add a headless check that loads every script and scene" \
           -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: The merge gate

**Files:**
- Create: `ci/auto_merge.sh`
- Test: `ci/test_auto_merge.sh`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `bash ci/auto_merge.sh` (reads `GH_TOKEN`/`GH_REPO` in CI, the git remote locally; honours `DRY_RUN=1`, `CLOUD_REVIEW=on|off`, `CLOSED_PR_HEAD`, `CLOSED_PR_BASE`, `AUTO_MERGE_AUTHOR`, `AUTO_MERGE_BASE`). Pure function `gate_decision key=value...`, printing exactly one of `merge`, `outdated`, `wait: <reasons>`, `skip: <reason>`, and returning 2 on an unknown key. Constants the other tasks name: `CHECK_RUN="project-check"`, `REVIEW_RUN="claude-review"`, `TESTS_STAMP="kejartes/editor-tests"`, `REVIEW_STAMP="kejartes/local-review"`, `OUTDATED_STAMP="kejartes/up-to-date"`, `HOLD_LABEL="hold"`.

- [ ] **Step 1: Write the failing tests**

Create `ci/test_auto_merge.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for gate_decision() in ci/auto_merge.sh. Pure: no network, no gh.
#
#     bash ci/test_auto_merge.sh
set -euo pipefail
# shellcheck source=ci/auto_merge.sh
source "$(dirname "${BASH_SOURCE[0]}")/auto_merge.sh"

failures=0
# A PR every gate would merge; each case overrides only what it is about.
GREEN=(author=brineoutxd base=Textures draft=false hold=false
       project_check=success editor_tests=success local_review=success
       cloud_review=off claude_review=missing behind_by=0 mergeable=MERGEABLE)

# expect <wanted prefix> <what the case proves> [key=value overrides...]
expect() {
  local want="$1" what="$2" got
  shift 2
  got="$(gate_decision "${GREEN[@]}" "$@")"
  if [[ "$got" == "$want"* ]]; then
    echo "ok   - $what"
  else
    echo "FAIL - $what: got '$got', want '$want...'"
    failures=$((failures + 1))
  fi
}

expect "merge"          "every gate green merges"
expect "skip: author"   "another author's PR is never merged" author=JustNormalUserTestingMinecraftModels
expect "skip: base"     "a PR stacked on another branch is not merged" base=feat/koperasi-rework
expect "skip: draft"    "a draft is not merged" draft=true
expect "skip: labelled" "a PR labelled hold is not merged" hold=true
expect "wait:"          "a failed project check blocks" project_check=failure
expect "wait:"          "a project check still running blocks" project_check=pending
expect "wait:"          "a missing editor-tests stamp blocks" editor_tests=missing
expect "wait:"          "a failed editor-tests stamp blocks" editor_tests=failure
expect "wait:"          "a missing local-review stamp blocks" local_review=missing
expect "merge"          "without a key the cloud review is not required" cloud_review=off claude_review=missing
expect "wait:"          "with a key a missing cloud review blocks" cloud_review=on claude_review=missing
expect "wait:"          "with a key a blocking cloud review blocks" cloud_review=on claude_review=failure
expect "merge"          "with a key a passing cloud review merges" cloud_review=on claude_review=success
expect "outdated"       "a green PR behind Textures is flagged, not merged" behind_by=3
expect "wait:"          "behind Textures with another gate red waits" behind_by=3 editor_tests=missing
expect "wait:"          "an unknown distance from Textures waits" behind_by=
expect "wait:"          "a conflict blocks" mergeable=CONFLICTING
expect "wait:"          "mergeability not computed yet blocks" mergeable=UNKNOWN

if gate_decision "${GREEN[@]}" bogus=1 > /dev/null 2>&1; then
  echo "FAIL - an unknown key is rejected"
  failures=$((failures + 1))
else
  echo "ok   - an unknown key is rejected"
fi

echo "$failures failure(s)"
exit $(( failures > 0 ))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `cd "$WT" && bash ci/test_auto_merge.sh`
Expected: FAIL at once with `ci/auto_merge.sh: No such file or directory`.

- [ ] **Step 3: Write the gate's rules**

Create `ci/auto_merge.sh` with the rules only (the `gh` layer comes in Step 5):

```bash
#!/usr/bin/env bash
# The merge gate for pull requests
# (docs/superpowers/specs/2026-09-11-pr-automation-design.md).
#
# .github/workflows/auto-merge.yml runs it on every relevant event. Locally,
# DRY_RUN=1 prints each decision and every command it would run, and changes
# nothing:
#
#     DRY_RUN=1 bash ci/auto_merge.sh
#
# gate_decision() is pure and unit-tested by ci/test_auto_merge.sh. Everything
# that talks to GitHub goes through gh, using gh's own --jq.
set -euo pipefail

AUTO_MERGE_AUTHOR="${AUTO_MERGE_AUTHOR:-brineoutxd}"
AUTO_MERGE_BASE="${AUTO_MERGE_BASE:-Textures}"
HOLD_LABEL="hold"
CHECK_RUN="project-check"
REVIEW_RUN="claude-review"
TESTS_STAMP="kejartes/editor-tests"
REVIEW_STAMP="kejartes/local-review"
OUTDATED_STAMP="kejartes/up-to-date"

# gate_decision key=value...  prints exactly one line:
#   merge            every gate is green
#   outdated         every gate is green, but the base has moved on
#   wait: <reasons>  a PR this gate merges, but a gate is not green yet
#   skip: <reason>   not a PR this gate merges
# Keys: author base draft hold project_check editor_tests local_review
# cloud_review(on|off) claude_review behind_by mergeable. A missing key counts
# as not green. Returns 2 on an unknown key.
gate_decision() {
  local author="" base="" draft="" hold="" project_check="" editor_tests=""
  local local_review="" cloud_review="off" claude_review="" behind_by="" mergeable="" kv
  for kv in "$@"; do
    case "$kv" in
      author=*)        author="${kv#*=}" ;;
      base=*)          base="${kv#*=}" ;;
      draft=*)         draft="${kv#*=}" ;;
      hold=*)          hold="${kv#*=}" ;;
      project_check=*) project_check="${kv#*=}" ;;
      editor_tests=*)  editor_tests="${kv#*=}" ;;
      local_review=*)  local_review="${kv#*=}" ;;
      cloud_review=*)  cloud_review="${kv#*=}" ;;
      claude_review=*) claude_review="${kv#*=}" ;;
      behind_by=*)     behind_by="${kv#*=}" ;;
      mergeable=*)     mergeable="${kv#*=}" ;;
      *) echo "gate_decision: unknown argument '$kv'" >&2; return 2 ;;
    esac
  done

  if [[ "$author" != "$AUTO_MERGE_AUTHOR" ]]; then echo "skip: author is ${author:-unknown}"; return 0; fi
  if [[ "$base" != "$AUTO_MERGE_BASE" ]]; then echo "skip: base is ${base:-unknown}"; return 0; fi
  if [[ "$draft" == "true" ]]; then echo "skip: draft"; return 0; fi
  if [[ "$hold" == "true" ]]; then echo "skip: labelled $HOLD_LABEL"; return 0; fi

  local reasons=()
  [[ "$project_check" == "success" ]] || reasons+=("$CHECK_RUN is ${project_check:-missing}")
  [[ "$editor_tests" == "success" ]] || reasons+=("$TESTS_STAMP is ${editor_tests:-missing}")
  [[ "$local_review" == "success" ]] || reasons+=("$REVIEW_STAMP is ${local_review:-missing}")
  if [[ "$cloud_review" == "on" && "$claude_review" != "success" ]]; then
    reasons+=("$REVIEW_RUN is ${claude_review:-missing}")
  fi
  [[ "$mergeable" == "MERGEABLE" ]] || reasons+=("mergeable is ${mergeable:-unknown}")
  if [[ ! "$behind_by" =~ ^[0-9]+$ ]]; then
    reasons+=("distance from $AUTO_MERGE_BASE is unknown")
  elif (( behind_by > 0 && ${#reasons[@]} > 0 )); then
    reasons+=("behind $AUTO_MERGE_BASE by $behind_by")
  fi

  if (( ${#reasons[@]} > 0 )); then
    local joined
    joined="$(printf '%s; ' "${reasons[@]}")"
    echo "wait: ${joined%; }"
    return 0
  fi
  if (( behind_by > 0 )); then echo "outdated"; return 0; fi
  echo "merge"
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd "$WT" && bash ci/test_auto_merge.sh`
Expected: 20 `ok` lines, then `0 failure(s)`, exit code 0.

- [ ] **Step 5: Add the `gh` layer and `main`**

Append to `ci/auto_merge.sh`:

```bash
# Runs a command that changes GitHub, or only prints it under DRY_RUN=1.
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "DRY_RUN: $*"; else "$@"; fi
}

# The conclusion of the newest check run named $2 on commit $1:
# success, failure, skipped, ... ; "pending" while it runs; "missing" if none.
check_conclusion() {
  gh api "repos/{owner}/{repo}/commits/$1/check-runs?check_name=$2" \
    --jq '.check_runs | sort_by(.id) | last | if . == null then "missing" else (.conclusion // "pending") end' \
    < /dev/null
}

# The state of the commit status named $2 on commit $1, or "missing".
status_state() {
  gh api "repos/{owner}/{repo}/commits/$1/status" \
    --jq "[.statuses[] | select(.context == \"$2\") | .state] | first // \"missing\"" \
    < /dev/null
}

# How many commits the base has that commit $1 lacks.
commits_behind() {
  gh api "repos/{owner}/{repo}/compare/$AUTO_MERGE_BASE...$1" --jq '.behind_by' < /dev/null
}

# Re-points this author's open PRs based on branch $1 at branch $2.
retarget_children() {
  local from="$1" to="$2" child
  for child in $(gh pr list --state open --base "$from" --author "$AUTO_MERGE_AUTHOR" \
                   --json number --jq '.[].number' < /dev/null); do
    run gh pr edit "$child" --base "$to" < /dev/null
    echo "#$child: re-pointed from $from to $to"
  done
}

main() {
  # A person merged a PR: its stacked children follow its base.
  if [[ -n "${CLOSED_PR_HEAD:-}" && -n "${CLOSED_PR_BASE:-}" ]]; then
    retarget_children "$CLOSED_PR_HEAD" "$CLOSED_PR_BASE"
  fi

  local number author base head sha draft hold mergeable decision
  while IFS=$'\t' read -r number author base head sha draft hold mergeable <&3; do
    decision="$(gate_decision author="$author" base="$base" draft="$draft" hold="$hold")"
    if [[ "$decision" == skip:* ]]; then
      echo "#$number: $decision"
      continue
    fi
    decision="$(gate_decision author="$author" base="$base" draft="$draft" hold="$hold" \
      project_check="$(check_conclusion "$sha" "$CHECK_RUN")" \
      editor_tests="$(status_state "$sha" "$TESTS_STAMP")" \
      local_review="$(status_state "$sha" "$REVIEW_STAMP")" \
      cloud_review="${CLOUD_REVIEW:-off}" \
      claude_review="$(check_conclusion "$sha" "$REVIEW_RUN")" \
      behind_by="$(commits_behind "$sha")" \
      mergeable="$mergeable")"
    echo "#$number: $decision"
    case "$decision" in
      merge)
        if run gh pr merge "$number" --merge --match-head-commit "$sha" < /dev/null; then
          retarget_children "$head" "$base"
        else
          echo "#$number: merge refused; will retry on the next event"
        fi
        ;;
      outdated)
        if [[ "$(status_state "$sha" "$OUTDATED_STAMP")" != "failure" ]]; then
          run gh api --silent -X POST "repos/{owner}/{repo}/statuses/$sha" \
            -f state=failure -f context="$OUTDATED_STAMP" \
            -f description="$AUTO_MERGE_BASE moved - merge it in and re-run the suite" < /dev/null
        fi
        ;;
    esac
  done 3< <(gh pr list --state open --limit 100 \
      --json number,author,baseRefName,headRefName,headRefOid,isDraft,labels,mergeable \
      --jq ".[] | [.number, .author.login, .baseRefName, .headRefName, .headRefOid, .isDraft, ([.labels[].name] | index(\"$HOLD_LABEL\") != null), .mergeable] | @tsv")
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

- [ ] **Step 6: Re-run the unit tests**

Run: `cd "$WT" && bash ci/test_auto_merge.sh`
Expected: still 20 `ok`, `0 failure(s)`. Sourcing must not run `main`.

- [ ] **Step 7: Dry-run against the real repo**

Run: `cd "$WT" && DRY_RUN=1 bash ci/auto_merge.sh`
Expected, with today's two open PRs (newest first):

```
#18: skip: base is feat/koperasi-rework
#15: skip: author is JustNormalUserTestingMinecraftModels
```

Any PR opened since then must print a `skip:` or `wait:` line naming its real reason, and no `DRY_RUN: gh pr merge` line unless that PR truly has every stamp. Nothing on GitHub changes.

- [ ] **Step 8: Commit**

```bash
cd "$WT"
git add ci/auto_merge.sh ci/test_auto_merge.sh
git commit -m "feat(ci): add the merge gate and its unit tests" \
           -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The three workflows

**Files:**
- Create: `.github/workflows/project-check.yml`, `.github/workflows/claude-review.yml`, `.github/workflows/auto-merge.yml`
- Test: `tests/test_pr_automation.gd` (+ its generated `.gd.uid`)

**Interfaces:**
- Consumes: `res://ci/project_check.tscn` (Task 1); `ci/test_auto_merge.sh`, `ci/auto_merge.sh` and its constants (Task 2).
- Produces: check runs named `project-check` and `claude-review` on each PR's head commit; workflows named `Project check`, `Claude review`, `Auto-merge`. Task 4 adds one test to `tests/test_pr_automation.gd`, whose `_read(path: String) -> String` helper it reuses.

- [ ] **Step 1: Write the failing consistency suite**

Create `tests/test_pr_automation.gd`:

```gdscript
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
	var pinned := RegEx.create_from_string("uses: [\\w.-]+/[\\w.-]+@[0-9a-f]{40}(\\s|$)")
	var workflows: Array[String] = [CHECK_WORKFLOW, REVIEW_WORKFLOW, MERGE_WORKFLOW]
	var offenders := PackedStringArray()
	for path in workflows:
		for line in _read(path).split("\n"):
			if line.contains("uses:") and pinned.search(line) == null:
				offenders.append(path.get_file() + ": " + line.strip_edges())
	assert_eq(offenders, PackedStringArray(), "every uses: must name a 40-character commit")
```

- [ ] **Step 2: Run it and watch it fail**

`filesystem_manage(op="scan", session_id=WT_SESSION)`, then `test_run(suite="pr_automation", session_id=WT_SESSION)`.
Expected: FAIL. The workflows do not exist yet (`... must exist`).

- [ ] **Step 3: Write `.github/workflows/project-check.yml`**

```yaml
# The headless Godot check every pull request must pass
# (docs/superpowers/specs/2026-09-11-pr-automation-design.md). The job's name,
# project-check, is the check-run name ci/auto_merge.sh requires.

name: Project check

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  push:
    branches: [Textures]
  workflow_dispatch:

concurrency:
  group: project-check-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  # Must match the editor the team uses; tests/test_pr_automation.gd checks
  # it against project.godot's feature version.
  GODOT_VERSION: 4.6.2-stable
  GODOT_ZIP: Godot_v4.6.2-stable_linux.x86_64.zip
  # From the release's SHA512-SUMS.txt.
  GODOT_SHA512: b6e4d5a716085e9649905be2afe77f723f97853544fb33392ce3d32594c730a95d9eb4d1042ed51508904c9e1d996bd36b7c7a2bf4f93f5b1885e98d81b792e7

jobs:
  project-check:
    name: project-check
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Merge-gate unit tests
        run: bash ci/test_auto_merge.sh

      - name: Install Godot
        run: |
          curl -fsSL -o "$RUNNER_TEMP/$GODOT_ZIP" \
            "https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/$GODOT_ZIP"
          echo "$GODOT_SHA512  $RUNNER_TEMP/$GODOT_ZIP" | sha512sum --check --strict -
          unzip -q "$RUNNER_TEMP/$GODOT_ZIP" -d "$RUNNER_TEMP/godot"
          chmod +x "$RUNNER_TEMP/godot/${GODOT_ZIP%.zip}"
          echo "GODOT=$RUNNER_TEMP/godot/${GODOT_ZIP%.zip}" >> "$GITHUB_ENV"

      - name: Import the project
        # A first import logs ERROR lines for textures the theme loads before
        # they are imported. That is ordering noise; only a crash fails here.
        run: |
          if ! "$GODOT" --headless --path . --import > import.log 2>&1; then
            tail -50 import.log
            exit 1
          fi

      - name: Load every script, scene and resource
        run: |
          set +e
          "$GODOT" --headless --path . res://ci/project_check.tscn > check.log 2>&1
          status=$?
          set -e
          cat check.log
          if grep -E '^WARNING:' check.log > warnings.txt; then
            { echo '### Godot warnings'; echo '```'; cat warnings.txt; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
          fi
          if grep -qE '^(ERROR|SCRIPT ERROR):' check.log; then
            echo "::error::Godot logged errors while loading the project; see the log above."
            exit 1
          fi
          exit "$status"
```

- [ ] **Step 4: Write `.github/workflows/claude-review.yml`**

```yaml
# A cloud Claude review of every non-draft pull request, whoever opened it
# (docs/superpowers/specs/2026-09-11-pr-automation-design.md). Dormant until
# the repo owner adds CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY as a
# repository secret: without one, claude-review is skipped, not failed. Its
# name is the check-run name ci/auto_merge.sh requires once a key exists.

name: Claude review

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

concurrency:
  group: claude-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  detect:
    runs-on: ubuntu-latest
    outputs:
      configured: ${{ steps.key.outputs.configured }}
    steps:
      - id: key
        env:
          HAS_KEY: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN != '' || secrets.ANTHROPIC_API_KEY != '' }}
        run: echo "configured=$HAS_KEY" >> "$GITHUB_OUTPUT"

  claude-review:
    name: claude-review
    needs: detect
    if: needs.detect.outputs.configured == 'true' && !github.event.pull_request.draft
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 1

      - name: Review
        id: review
        uses: anthropics/claude-code-action@0a8d3c9443bbff909ab973b6a17a340b913f229f # v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ github.token }}
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            Review this pull request. The PR branch is checked out in the working
            directory, and `gh pr diff ${{ github.event.pull_request.number }}` shows the change.

            Read CLAUDE.md first and judge the change against its rules and against
            correctness: bugs, broken references between scenes, scripts and
            resources, and anything that contradicts a constraint CLAUDE.md states.
            The project's editor test suite cannot run here; do not ask for it.

            Post an inline comment (mcp__github_inline_comment__create_inline_comment)
            only for a real problem, on the line it concerns, saying what is wrong
            and why. No praise, and no style points the project does not enforce.

            Then return your verdict. Use "block" only for a defect that must be
            fixed before this merges, and list each one in "blocking". Otherwise
            return "pass" with an empty list.
          claude_args: |
            --model claude-opus-5
            --max-turns 40
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr diff:*),Bash(gh pr view:*),Bash(gh pr comment:*)"
            --json-schema '{"type":"object","properties":{"verdict":{"type":"string","enum":["pass","block"]},"blocking":{"type":"array","items":{"type":"string"}}},"required":["verdict","blocking"],"additionalProperties":false}'

      - name: Enforce the verdict
        env:
          OUTPUT: ${{ steps.review.outputs.structured_output }}
        run: |
          verdict=$(printf '%s' "$OUTPUT" | jq -r '.verdict // empty' 2>/dev/null || true)
          echo "Claude review verdict: ${verdict:-none}"
          if [ "$verdict" != "pass" ]; then
            printf '%s' "$OUTPUT" | jq -r '.blocking[]? | "::error::" + .' 2>/dev/null || true
            exit 1
          fi
```

- [ ] **Step 5: Write `.github/workflows/auto-merge.yml`**

```yaml
# Merges brineoutxd's pull requests into Textures once every gate is green,
# flags PRs whose base moved on, and re-points stacked PRs after a merge. The
# rules live in ci/auto_merge.sh
# (docs/superpowers/specs/2026-09-11-pr-automation-design.md); this file only
# decides when to run it and with which permissions.

name: Auto-merge

on:
  workflow_run:
    workflows: [Project check, Claude review]
    types: [completed]
  status:
  pull_request:
    types: [closed, labeled, unlabeled, ready_for_review]
  push:
    branches: [Textures]
  schedule:
    - cron: "*/30 * * * *"
  workflow_dispatch:

concurrency:
  group: auto-merge
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write
  statuses: write
  checks: read

jobs:
  auto-merge:
    name: auto-merge
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      # Always the rules on Textures, never a pull request's copy of them.
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          ref: Textures

      - name: Evaluate open pull requests
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          CLOUD_REVIEW: ${{ (secrets.CLAUDE_CODE_OAUTH_TOKEN != '' || secrets.ANTHROPIC_API_KEY != '') && 'on' || 'off' }}
          CLOSED_PR_HEAD: ${{ github.event.action == 'closed' && github.event.pull_request.merged && github.event.pull_request.head.ref || '' }}
          CLOSED_PR_BASE: ${{ github.event.action == 'closed' && github.event.pull_request.merged && github.event.pull_request.base.ref || '' }}
        run: |
          # Until the setup PR lands, Textures has no gate to run.
          if [ ! -f ci/auto_merge.sh ]; then
            echo "::notice::ci/auto_merge.sh is not on Textures yet; nothing to do."
            exit 0
          fi
          bash ci/auto_merge.sh
```

- [ ] **Step 6: Run the suite and watch it pass**

`filesystem_manage(op="scan", session_id=WT_SESSION)`, then `test_run(suite="pr_automation", session_id=WT_SESSION)`.
Expected: PASS, 5 tests. (`.github/` is a dot-folder the editor does not index; the suite reads the files directly, which works.)

There is no YAML parser on this machine (Python has no PyYAML), so GitHub validates the syntax when the setup PR is pushed (Task 5, Step 7).

- [ ] **Step 7: Commit**

```bash
cd "$WT"
git status --short          # revert Assets/Audio/default_bus_layout.tres if it changed
git add .github/workflows/project-check.yml .github/workflows/claude-review.yml \
        .github/workflows/auto-merge.yml tests/test_pr_automation.gd tests/test_pr_automation.gd.uid
git commit -m "feat(ci): add the project-check, claude-review and auto-merge workflows" \
           -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: The ship-pr skill

**Files:**
- Create: `.claude/skills/ship-pr/SKILL.md`
- Modify: `tests/test_pr_automation.gd` (one constant, one test)

**Interfaces:**
- Consumes: the stamp names `kejartes/editor-tests` and `kejartes/local-review` (Task 2's `TESTS_STAMP`, `REVIEW_STAMP`); `_read(path: String) -> String` and `GATE` in `tests/test_pr_automation.gd` (Task 3).
- Produces: the `ship-pr` project skill that Task 5 and Task 6 run.

- [ ] **Step 1: Add the failing test**

In `tests/test_pr_automation.gd`, after the `MERGE_WORKFLOW` constant, add:

```gdscript
## The local finish-a-branch procedure.
const SKILL := "res://.claude/skills/ship-pr/SKILL.md"
```

and at the end of the file, add:

```gdscript
func test_the_skill_posts_exactly_the_stamps_the_gate_requires() -> void:
	var gate := _read(GATE)
	var skill := _read(SKILL)
	var stamps: Array[String] = ["kejartes/editor-tests", "kejartes/local-review"]
	for stamp in stamps:
		assert_true(gate.contains("\"" + stamp + "\""), "auto_merge.sh requires " + stamp)
		assert_true(skill.contains("context=" + stamp), "SKILL.md posts " + stamp)
```

- [ ] **Step 2: Run it and watch it fail**

`test_run(suite="pr_automation", session_id=WT_SESSION)`
Expected: FAIL with `res://.claude/skills/ship-pr/SKILL.md must exist`; the other 5 tests still pass.

- [ ] **Step 3: Write the skill**

Create `.claude/skills/ship-pr/SKILL.md`:

````markdown
---
name: ship-pr
description: Use when a branch's work is finished and should become a pull request that merges itself - "ship it", "open the PR", "send this for merge" - and again whenever the app wakes this session about that PR (a red check, a merge conflict, a review comment, or "Textures moved"). Runs the full editor suite and a local Claude review, pushes, opens the PR, and stamps the tested commit so GitHub's merge gate can merge it.
---

# Ship a PR

The local half of the pull-request automation. GitHub checks the PR
(`project-check`), reviews it (`claude-review`, once the owner adds a key) and
merges it (`ci/auto_merge.sh`), but only when this procedure has stamped the
exact commit it tested.

Design: `docs/superpowers/specs/2026-09-11-pr-automation-design.md`.

The gate merges only PRs authored by `brineoutxd` into `Textures`. Anyone can
run this skill; other people's PRs simply wait for a person to merge them.

## 1. Preflight

Stop and report, rather than continue, if any of these fails:

- `git branch --show-current` prints a branch, and it is not `Textures`.
- `git status --porcelain` prints nothing.
- `git fetch origin` succeeds.

## 2. Bring in the latest Textures

Run `git merge origin/Textures`. Resolve conflicts like this:

- `docs/superpowers/CHANGELOG.md`: keep both sides' entries, newest first.
- `Assets/Theme/kejartes_theme.tres`: never merge it by hand. Take either
  side, then rebake (CLAUDE.md → "Rebaking without File > Run") and check the
  bake by its content.
- `Scripts/Balance.gd`: take the collaborator's version (CLAUDE.md →
  Conventions).
- Anything else: resolve it properly, and say what you did in the PR.

## 3. Run the full editor suite

Run `test_run` with no `suite`, in the editor that has **this checkout** open:

- **The main checkout:** the bridge's usual editor.
- **A worktree** under `.claude/worktrees/<name>`: it needs its own editor.
  Copy `imported/`, `shader_cache/`, `uid_cache.bin`,
  `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main
  checkout's `.godot/` into the worktree's, launch
  `<Godot editor exe> --path <worktree> -e` in the background, find its session
  with `session_manage(op="list")`, and pass that `session_id` to every call.
  Never call `session_activate`, and never kill every Godot process.

A full run can drop the bridge (CLAUDE.md → Working efficiently here); its
results still count once they have arrived. Afterwards run `git status` and
`git checkout --` `Assets/Audio/default_bus_layout.tres` or
`Assets/Theme/kejartes_theme.tres` if the run changed them and you did not
mean it to.

Fix genuine failures this branch caused, then run the suite again. If a
failure has nothing to do with the branch, stop, report it and do not stamp.
Note the totals as `<passed>/<total>`.

## 4. Review the branch locally

Invoke the `code-review` skill at effort `high` on this branch. Weigh each
finding (superpowers:receiving-code-review): fix the real ones and note why you
rejected the rest. If you changed any code, commit it and go back to step 3.

## 5. Push and open the PR

```bash
git push -u origin HEAD
gh pr view --json number,url || gh pr create --base Textures --title "<type(scope): summary>" --body-file <file>
```

For stacked work, use the parent branch as `--base`. The body says what
changed, the suite totals, and the review summary: findings fixed, findings
rejected and why.

## 6. Stamp the tested commit

Only when steps 3 and 4 passed on this exact commit:

```bash
if [ -n "$(git status --porcelain)" ] || [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]; then
  echo "STOP: HEAD is not the clean, pushed commit that was tested"
else
  SHA=$(git rev-parse HEAD)
  gh api --silent -X POST "repos/{owner}/{repo}/statuses/$SHA" \
    -f state=success -f context=kejartes/editor-tests -f description="<passed>/<total> passed"
  gh api --silent -X POST "repos/{owner}/{repo}/statuses/$SHA" \
    -f state=success -f context=kejartes/local-review -f description="<n> findings fixed, 0 open"
fi
```

Never stamp a commit the suite did not run on. A new commit needs new stamps.

## 7. Let the app watch the PR

If the Claude desktop app's PR tools are available, the app bound the PR when
you ran `gh pr create` or pushed. Call `mcp__ccd_pr__set_monitor` with the
PR's url and `auto_fix: true` (the user approves it), so this session is woken
on a red check, a merge conflict or a review comment.

## 8. When the app wakes you

- **`project-check` failed:** read the log (`gh run view --log-failed`), fix,
  then go to step 2.
- **`claude-review` blocked:** read its inline comments. Fix what is real,
  answer what is not, then go to step 2.
- **A merge conflict, or `kejartes/up-to-date` failed:** go to step 2.
- **A comment from a person:** address it; if code changed, go to step 2.

## Stopping a merge

Label the PR `hold`, or mark it as a draft. Anyone can still merge by hand.
````

- [ ] **Step 4: Run the suite and watch it pass**

`test_run(suite="pr_automation", session_id=WT_SESSION)`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
cd "$WT"
git status --short          # revert Assets/Audio/default_bus_layout.tres if it changed
git add .claude/skills/ship-pr/SKILL.md tests/test_pr_automation.gd
git commit -m "feat(ci): add the ship-pr skill that stamps tested commits" \
           -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Documentation, the full suite, and the setup PR

**Files:**
- Modify: `CLAUDE.md` (a new `## Pull requests` section, the `## Testing` count, `## Current work`), `docs/superpowers/CHANGELOG.md` (a new top entry)

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces: the pushed branch and the setup PR, labelled `hold`, which the user merges by hand.

- [ ] **Step 1: Add the `## Pull requests` section to `CLAUDE.md`**

Insert this section immediately before the line `## Godot MCP`:

```markdown
## Pull requests

PRs open, check, review and merge through automation
(`docs/superpowers/specs/2026-09-11-pr-automation-design.md`). **Finish a
branch with the `ship-pr` skill** (`.claude/skills/ship-pr/SKILL.md`): it runs
the full suite and a local review, opens the PR, and stamps the tested commit
with `kejartes/editor-tests` and `kejartes/local-review`. GitHub adds
`project-check` (headless Godot 4.6.2 loading every file) on every PR, and
`claude-review` once the owner adds a key. `ci/auto_merge.sh` then merges
**only `brineoutxd`'s PRs into `Textures`**, and only when every gate is green
on a commit that already contains `Textures`. Label a PR `hold`, or leave it a
draft, to stop it; anyone can still merge by hand. A stamp belongs to one
commit: never post one for a commit the suite did not run on.
```

- [ ] **Step 2: Point `## Current work` at this branch**

In `CLAUDE.md`, replace this paragraph (that branch landed in PRs #13 and #14):

```markdown
Branch `feat/asset-refresh-ui-pass`, off `Textures` (main), with `Textures`
merged back into it on 2026-09-10. The asset refresh and UI pass is complete
and pushed, not yet merged; the StudentList Warm UI Part 3 pass, and the
minigame, sky and paper fixes, are committed on top. See
`docs/superpowers/CHANGELOG.md`.
```

with:

```markdown
Branch `feat/pr-automation`: the pull-request automation. Once its setup PR is
merged by hand, the live test in
`docs/superpowers/plans/2026-09-11-pr-automation.md` (Task 6) still has to run.
```

Leave the `Open: Plan C's RunResult redesign` paragraph as it is.

- [ ] **Step 3: Add the changelog entry**

In `docs/superpowers/CHANGELOG.md`, insert this entry immediately before the line `## 2026-09-11 — Delta rows, badge and Inventory values readable; the delta rows show at all`:

```markdown
## 2026-09-11 — Pull requests open, check, review and merge themselves

Every PR had been opened and merged by hand, and the repo had no CI. Now:

- **`project-check`** runs on GitHub for every PR: headless Godot 4.6.2
  imports the project and loads every script, scene and resource, checking
  that each dependency exists. A scene pointing at a missing texture needs
  that explicit check, because Godot logs the error and loads the scene
  anyway. The walk skips nested projects the way the editor does; a naive one
  reports 62 false failures in `-REFERENCE-/prototype`.
- **`claude-review`** is a cloud Claude review with a `pass`/`block` verdict.
  It stays skipped until the repo owner adds a key.
- **The `ship-pr` skill** runs the full suite and a local review, pushes,
  opens the PR and stamps the tested commit.
- **`ci/auto_merge.sh`** merges `brineoutxd`'s PRs into `Textures` when every
  gate is green on a commit that already contains `Textures`, flags PRs whose
  base moved on, and re-points stacked PRs.

Spec: `docs/superpowers/specs/2026-09-11-pr-automation-design.md`. Plan:
`docs/superpowers/plans/2026-09-11-pr-automation.md`.

```

- [ ] **Step 4: Run the full suite in the worktree editor**

`test_run(session_id=WT_SESSION)` with no `suite`.
Expected: every suite passes, including `project_check` (10) and `pr_automation` (6). If a failure touches the theme, re-run that suite alone before believing it (CLAUDE.md → Testing, suite order). If the bridge drops after the reply arrives, the results still count.

Then, in `CLAUDE.md`'s `## Testing`, replace `94 suites, 1323 tests (2026-09-11)` with the run's reported suite and test counts, keeping the date.

Then run `git -C "$WT" status --short`. `Assets/Theme/kejartes_theme.tres` must be unchanged (nothing here touches the theme); if it or `Assets/Audio/default_bus_layout.tres` changed, `git -C "$WT" checkout --` it.

- [ ] **Step 5: Commit the documentation**

```bash
cd "$WT"
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git commit -m "docs(ci): document the pull-request automation" \
           -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Create the `hold` label and ship the setup PR**

Create the label if it does not exist:

```bash
gh label list --search hold --json name --jq '.[].name' | grep -qx hold \
  || gh label create hold --color B60205 --description "Auto-merge skips this PR"
```

Then run the `ship-pr` skill on this branch. Its step 3 runs the full suite again, on the final commit this time. In its step 5, open the PR with:

```bash
gh pr create --base Textures --label hold \
  --title "feat(ci): automate pull requests: check, review and merge" --body-file <file>
```

The body summarises the spec, lists the owner's one optional step (a `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` repository secret), and states that this PR must be merged by hand.

- [ ] **Step 7: Confirm GitHub accepted all three workflows**

```bash
gh pr checks <setup PR number> --watch
```

Expected: `project-check` passes, and `claude-review` shows as skipped. Then `gh run list --workflow auto-merge.yml --limit 1` shows the run the `hold` label triggered, and its log contains `ci/auto_merge.sh is not on Textures yet`. If GitHub reports "Invalid workflow file" for any of the three, fix the YAML, push, re-stamp (skill step 6) and check again.

If `project-check` fails on Linux, read the log. Fix a real error; never widen the error filter to hide one.

- [ ] **Step 8: Hand over to the user, then stop**

Tell the user:

- the setup PR's link, and that it must be **merged by hand once** (merge commit), because GitHub only runs event-driven workflows from the default branch;
- the owner's optional step: add a repository secret named `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, on a paid Claude plan) or `ANTHROPIC_API_KEY`, under Settings → Secrets and variables → Actions; until then the cloud review is skipped and does not block merges;
- that Task 6, the live test, runs after the merge.

Quit the worktree editor: `editor_manage(op="quit", session_id=WT_SESSION)`.

---

### Task 6: Live test, after the setup PR is merged

**Files:**
- Modify: `CLAUDE.md` (`## Current work`), `docs/superpowers/CHANGELOG.md` (the entry from Task 5)

**Interfaces:**
- Consumes: the merged automation on `Textures`.
- Produces: proof that the gate merges, waits, holds and flags as specified, recorded in the changelog.

- [ ] **Step 1: Confirm the automation is live**

```bash
gh api "repos/{owner}/{repo}/contents/ci/auto_merge.sh?ref=Textures" --jq .name
gh workflow run auto-merge.yml && sleep 5 && gh run watch "$(gh run list --workflow auto-merge.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Expected: `auto_merge.sh`, then a successful run whose log has one `skip:` or `wait:` line per open PR.

- [ ] **Step 2: Open PR B first, unstamped, to prove the gate waits**

In a fresh worktree off `origin/Textures` (`git worktree add -b test/pr-automation-b .claude/worktrees/pr-live-b origin/Textures`), add the changelog line below to the end of the Task 5 entry, commit it, push it, and open the PR **without** stamps:

```markdown
Live test: PR A merged itself once stamped; this entry's own PR waited while
unstamped, held while labelled `hold`, was flagged out of date when PR A
landed, then merged itself once re-tested.
```

After `project-check` finishes, the auto-merge log must show `#<B>: wait: kejartes/editor-tests is missing; kejartes/local-review is missing`. Then label it: `gh pr edit <B> --add-label hold`. The next run must show `#<B>: skip: labelled hold`.

- [ ] **Step 3: Ship PR A through the skill and watch it merge itself**

In a second fresh worktree off `origin/Textures` (`git worktree add -b test/pr-automation-a .claude/worktrees/pr-live-a origin/Textures`), make the change that closes this work in `CLAUDE.md`'s `## Current work`: remove the paragraph that begins ``Branch `feat/pr-automation` ``. Run the `ship-pr` skill end to end, with a second editor on that worktree for its step 3.

Expected, within a few minutes of the stamps: `gh pr view <A> --json state,mergedBy --jq '.state + " by " + .mergedBy.login'` prints `MERGED by github-actions` (or the app's bot name). If the owner has added a key by now, `claude-review` must also have passed on A; otherwise it shows as skipped.

- [ ] **Step 4: Make PR B out of date and watch the flag**

PR A's merge moved `Textures`, so PR B is now behind. Run the skill's steps 3 to 6 on B's **current** commit (full suite, review, stamps), but do not merge `Textures` in yet. Then `gh pr edit <B> --remove-label hold`.

Expected: the auto-merge log shows `#<B>: outdated`; `gh pr checks <B>` lists `kejartes/up-to-date` as failed. If this session holds B's PR binding, `mcp__ccd_pr__get_status` must list that status among the failing checks. That shows the app's Auto-fix sees commit statuses (the spec's rollout step 4). If it does not list it, add to the skill's step 8 a line telling a resumed session to read `gh pr checks` first, and record that in the changelog.

- [ ] **Step 5: Bring B up to date and watch it merge**

Run the skill from its step 2 on B: merge `origin/Textures`, run the full suite, review, push, and stamp the new commit.
Expected: `gh pr view <B> --json state` prints `MERGED`.

- [ ] **Step 6: Clean up**

```bash
cd "$MAIN"
git worktree remove .claude/worktrees/pr-live-a
git worktree remove .claude/worktrees/pr-live-b
git worktree remove .claude/worktrees/pr-automation
```

Quit any worktree editor you started with `editor_manage(op="quit", session_id=<its id>)`. Leave the user's own editor alone. Report to the user what merged, what waited, and anything that differed from the expectations above.
