# Clean Code, Phase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land PR1 (clean-code rulebook + a ratchet scan enforced in the editor suite and in CI), PR2 (file renames) and PR3 (stat-key rename) from `docs/superpowers/specs/2026-09-26-clean-code-design.md`, each merged only after the test → independent review → fix loop comes back clean.

**Architecture:** One pure-text scanner, `ci/clean_code_scan.gd`, measures the tree; its frozen baselines live in a generated `ci/clean_code_baseline.gd` and its reviewed exceptions in a hand-written `ci/clean_code_allowed.gd`. `tests/test_clean_code.gd` (editor) and `ci/project_check.gd` (headless CI) both run it; `ci/clean_code_dump.gd` regenerates the baselines. PR2 and PR3 are mechanical, script-driven rewrites whose correctness the scan's must-be-zero rules then prove.

**Tech Stack:** Godot 4.6.2 (GDScript), the godot-ai MCP editor bridge (`test_run`, `script_patch`, `session_manage`), Python 3 (one-off rewrite scripts, run from a scratch folder), Git Bash / PowerShell 5.1 on Windows, GitHub Actions (`project-check.yml`, unchanged).

## Global Constraints

- Behaviour does not change anywhere in this work. Every step is a refactor.
- `Scripts/Balance.gd` is collaborator-owned: never edit it; it is exempt from every scan rule.
- Tests: every suite is `@tool`; no test may be a coroutine (no `await`).
- Never hand-edit a `.tscn`, and never run a rewrite script, while an editor has that checkout open (CLAUDE.md 4b). Scripts that rewrite files run with the worktree's editor **closed**.
- Never touch the user's main checkout or its editor. Verification runs in a second editor on the PR's worktree, with `session_id` on every godot-ai call; never `session_activate`.
- Commits: Conventional Commits with a scope; write the message to a file and `git commit -F <file>`; end every message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `CLAUDE.md` stays at or under **23,000 characters** (`python -c "print(len(open('CLAUDE.md',encoding='utf-8').read()))"`).
- Historical docs keep old names: `docs/superpowers/specs/`, `plans/`, `handover/`, `mockups/`, `baseline/` and `docs/superpowers/CHANGELOG.md`'s existing entries are never rewritten (new entries are added at the top).
- A **new** script starts at zero clean-code debt: typed, no bare numbers, no function over 50 code lines. (`ci/` and `tests/` are exempt from the metrics, but write them clean anyway.)
- Game-facing identifiers and UI text are Indonesian; engine/system code and comments are English.
- After any game run or full `test_run`: revert `Assets/Audio/default_bus_layout.tres`, and any `.import` or theme-bake rewrite you did not intend, **after** the editor has exited.
- Leave the untracked `addons/godot_ai/utils/update_activation_runner.gd(.uid)` alone (the plugin's own file).
- Scan definitions are the spec's section 2. Clarifications this plan adds: (1) inside a function body, a line starting `const` is a named constant and its numbers are not "bare"; (2) instead of printing a dictionary literal to paste, a shrink failure names `ci/clean_code_dump.gd`, which regenerates the whole baseline file exactly; (3) the dump tool may run while the worktree's editor is open, because it writes only `ci/clean_code_baseline.gd` and PR1 does no `scene_save` — follow it with E4; (4) the spec's "Today" counts were measured roughly; the exact PR1 numbers are in Task 3 Step 4.

## Names used throughout

- `<main>` = `C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project`
- `<wt>` = the current PR's worktree: PR1 `<main>\.claude\worktrees\clean-code` (branch `chore/clean-code-rules`, already exists, holds the spec), PR2 `<main>\.claude\worktrees\clean-code-renames`, PR3 `<main>\.claude\worktrees\clean-code-stat-keys`.
- `<exe>` = `C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe` (the outer `.exe` is a **folder**).
- `<console>` = `C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
- `<scratch>` = the executing session's scratchpad directory (never inside the repo).
- `<sid>` = the godot-ai `session_id` of the editor whose `project_path` is `<wt>`.

Run headless Godot from **PowerShell** (Git Bash rewrites `res://` arguments):
`& "<console>" --headless --path "<wt>" <args>`

## File structure (PR1)

| File | Responsibility |
|---|---|
| `ci/clean_code_scan.gd` (new) | The scanner: parsing primitives, the five ratcheted measurements, the six must-be-zero finders, comparisons, baseline formatting. Pure `FileAccess`/`DirAccess`/`RegEx`. |
| `ci/clean_code_allowed.gd` (new) | Hand-written, commented permanent exceptions, per measurement. |
| `ci/clean_code_baseline.gd` (new, generated) | Frozen counts. Written only by the dump tool. |
| `ci/clean_code_dump.gd` (new) | `extends SceneTree`; `--script` tool that rewrites the baseline and prints a summary. |
| `tests/test_clean_code.gd` (new) | Fixture tests pinning the scanner's definitions + grow/tight ratchet tests. |
| `ci/project_check.gd` (modify) | Runs the scan in CI: growth and must-be-zero → FAIL lines; shrink → `WARNING:` lines. |
| `tests/test_project_check.gd` (modify) | Pins that `project_check` runs the scan and only warns on a shrink. |
| `ci/selftest_project_check.sh` (modify) | Fixtures moved to the project root; each fail case must print its own pattern; a planted scan-violation case. |
| `docs/superpowers/design/clean-code.md` (new) | The rulebook. |
| `CLAUDE.md`, `style-guide.md`, `authoring-guide.md`, `DEBT.md`, `CHANGELOG.md` (modify) | Pointer + budget moves + debt + history. |

---

## Procedures (referenced by the tasks)

### Procedure E — the worktree's own editor

- [ ] **E1. Seed the import cache** (PowerShell) so the editor boots without a full reimport:

```powershell
$main = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project"
$wt = "<wt>"
New-Item -ItemType Directory -Force "$wt\.godot" | Out-Null
foreach ($d in "imported", "shader_cache") { Copy-Item -Recurse -Force "$main\.godot\$d" "$wt\.godot\" }
foreach ($f in "uid_cache.bin", "global_script_class_cache.cfg", "scene_groups_cache.cfg") { Copy-Item -Force "$main\.godot\$f" "$wt\.godot\" }
```

- [ ] **E2. Launch it detached** (it must not be a child of any task):

```powershell
$wt = "<wt>"
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e"; CurrentDirectory = $wt }
```
Expected: `ReturnValue 0` and a `ProcessId`.

- [ ] **E3. Find `<sid>`:** `session_manage(op="list")` until a session whose `project_path` is `<wt>` reports ready. Pass `session_id=<sid>` on **every** godot-ai call from now on; confirm by the suite count or `edited_scene` that the right editor answered.
- [ ] **E4. After any `.gd` written from outside the editor** (Write/Edit/Python/dump tool): do a no-op `script_patch` on that file (replace one line with itself) before `test_run`. If it reports `reloaded: false` on a `class_name`/`@tool` script, restart the editor (E5 then E2).
- [ ] **E5. Stop it:** `editor_manage(op="quit", session_id=<sid>)`. If that times out (it does after a full run), stop only this worktree's Godot:

```powershell
$wt = "<wt>"
Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Where-Object { $_.CommandLine -like ('*--path "' + $wt + '"*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```
- [ ] **E6. Clean the noise** once it has exited: `git -C "<wt>" status --short`; `git -C "<wt>" checkout -- Assets/Audio/default_bus_layout.tres` and any other file you did not intend to change.

A **full** `test_run` drops the bridge: take it once per PR (Procedure R), then E5 + E2 before any further editor work.

### Procedure R — the review loop (run once per PR, repeat until clean)

- [ ] **R1. Targeted tests:** `test_run(suite=<name>, session_id=<sid>)` for each suite the task lists. All must pass.
- [ ] **R2. CI check locally** (editor may stay open):

```powershell
& "<console>" --headless --path "<wt>" res://ci/project_check.tscn
```
Expected: `PROJECT CHECK: checked N files, 0 failures`, no `PROJECT CHECK FAIL:` lines, exit code 0 (`$LASTEXITCODE`). Then E6.
- [ ] **R3. Full suite:** `test_run(session_id=<sid>)` with no suite. Record `suite_count`, `total`, `passed`, `failed` and the commit (`git -C "<wt>" rev-parse --short HEAD`). Any failure: re-run that suite alone before believing it (theme-bake ordering, CLAUDE.md "Testing"). Then E5, E6, E2.
- [ ] **R4. Independent review.** Dispatch a **fresh** `general-purpose` agent (not the one that wrote the code) with this prompt, filled in:

```text
You are an independent reviewer for <PR name> of the KejarTes clean-code pass.
Read-only: do not modify files, run no state-changing git commands, and do not
use godot-ai tools. Worktree: <wt> (use `git -C <wt> ...`).
Read: CLAUDE.md; docs/superpowers/specs/2026-09-26-clean-code-design.md
(sections <list>); docs/superpowers/design/clean-code.md; and
docs/superpowers/plans/2026-09-26-clean-code-phase1.md, tasks <list>.
The change: `git -C <wt> diff origin/Textures...HEAD` (also `--stat -M`).
Test evidence (commit <sha>): <R1 results>; <R2 output>; <R3 counts>;
`git status --short` = <output>.
Findings from earlier rounds, to re-check: <none | list>.
Review the OUTPUT: behaviour unchanged; the spec's rules followed; every
ci/clean_code_baseline.gd change only lowers a number or removes an entry
(PR2: keys renamed, totals equal); nothing outside this PR's allow-list
(<allow-list>); no stray changes (theme bake, Assets/Audio/default_bus_layout.tres,
unrelated .import files).
Review the PROCESS: rewrite scripts ran with the editor closed (<evidence>);
the tests ran on HEAD; historical docs (docs/superpowers/specs|plans|handover|
mockups|baseline, and CHANGELOG.md's old entries) are unchanged; git status
is clean.
Verify every claim with a command. Output: findings, each BLOCKING or
NON-BLOCKING, with evidence and a concrete fix; end with exactly one line:
APPROVE or CHANGES REQUIRED.
```
- [ ] **R5. Fix and repeat.** Fix every BLOCKING finding (and cheap NON-BLOCKING ones), commit, and run R1–R4 again with a **new** reviewer that gets the previous findings. **Safety valve:** if the same finding survives 3 rounds, or it is the user's judgment call, stop and ask the user.
- [ ] **R6. Done** = R3 green on HEAD and the latest reviewer says APPROVE. Go to Procedure S.

### Procedure S — ship with a hold

- [ ] **S1.** Check the `hold` label exists: `gh label list --search hold`. If it does not, stop and ask the user (creating a repo label is theirs to approve).
- [ ] **S2.** Invoke the `ship-pr` skill from `<wt>`. When it runs `gh pr create`, add `--label hold`, so auto-merge waits for the user. Right after creating the PR: `mcp__ccd_pr__get_status`; if unbound, `bind_pr` with its URL, then `set_monitor(auto_fix=true)` — before ship-pr's stamps.
- [ ] **S3.** Send the user the ready-to-paste collaborator note from the task, and say: "Remove the `hold` label when you have told them; the PR then merges itself."
- [ ] **S4.** When the app reports the merge, confirm: `gh pr view <n> --json state,mergedAt`. Stop the PR's editor (E5). For the PR2 and PR3 worktrees only: `git -C "<wt>" status --porcelain` must be empty and the branch merged, then `git -C "<main>" worktree remove --force "<wt>"`; if Windows' path limit leaves the folder behind ("Filename too long"), delete it with `cmd /c rmdir /s /q "\\?\<wt>"`. Never remove `.claude/worktrees/clean-code`: it is the executing session's working directory. After Task 11, tell the user it can be removed.

---

# PR1 — rules and ratchet (branch `chore/clean-code-rules`, worktree `.claude/worktrees/clean-code`)

### Task 1: Scanner parsing primitives

**Files:**
- Create: `ci/clean_code_scan.gd`, `ci/clean_code_allowed.gd`, `ci/clean_code_baseline.gd` (stub)
- Test: `tests/test_clean_code.gd`

**Interfaces:**
- Produces (all `static`, on the script preloaded as `Scan := preload("res://ci/clean_code_scan.gd")`):
  - `strip_strings_and_comments(line: String) -> String` — string contents blanked to spaces (length preserved), trailing `#` comment cut.
  - `function_name(line: String) -> String` — name of a column-0 `func`/`static func`, else `""`.
  - `parse_functions(src: String) -> Array[Dictionary]` — each `{"name": String, "line": int, "signature": String, "body": Array}` (`body` = raw lines).
  - `code_lines(body: Array) -> PackedStringArray` — stripped body lines that are neither blank nor comment-only.
  - `is_trivial_number(text: String) -> bool`, `bare_number_count(body: Array) -> int`.
  - `untyped_parameter_count(signature: String) -> int`, `untyped_count(src: String, functions: Array[Dictionary]) -> int`.
  - Constants `BASELINE`, `ALLOWED` (preloads), `LONG_FUNCTION_LINES = 50`, `LARGE_SCRIPT_LINES = 1000`, `DUPLICATE_MIN_LINES = 5`.

- [ ] **Step 1: Bring up the worktree editor.** Run Procedure E (E1–E3) for `<wt>` = `<main>\.claude\worktrees\clean-code`. Then check the tree: `git -C "<wt>" status --short` (clean apart from the plugin's untracked runner) and `git -C "<wt>" branch --show-current` = `chore/clean-code-rules`.

- [ ] **Step 2: Write the failing tests.** Create `tests/test_clean_code.gd`:

```gdscript
@tool
extends McpTestSuite

## The clean-code ratchet, in the editor suite. ci/clean_code_scan.gd does the
## measuring -- CI's ci/project_check.gd runs the same scan -- and this suite
## pins the scanner's definitions with small fixtures, then holds every
## measurement to ci/clean_code_baseline.gd in both directions: a count may
## not grow, and a count that shrank must be lowered in the same commit
## (regenerate with ci/clean_code_dump.gd). The rules and why:
## docs/superpowers/design/clean-code.md.
##
## The whole-project scan runs once, in suite_setup(), so the ratchet tests
## share one pass. Fixtures never spell an old file name or a legacy stat key
## literally -- they are built by concatenation -- because the scan reads
## tests/ and the clean-code renames rewrite those words.
##
## Must be @tool, and no test here may be a coroutine.

## The scanner under test.
const Scan := preload("res://ci/clean_code_scan.gd")

## The whole-project report, computed once per run in suite_setup().
var _report: Dictionary = {}


## The runner's name for this suite.
func suite_name() -> String:
	return "clean_code"


## One full scan for every ratchet test in this run.
func suite_setup(_ctx: Dictionary) -> void:
	_report = Scan.full_report()


func test_strip_blanks_strings_and_cuts_comments() -> void:
	assert_eq(Scan.strip_strings_and_comments('x = "a#b" # c'), 'x = "   " ')
	assert_eq(Scan.strip_strings_and_comments('s = "a\\"b"'), 's = "    "',
		"an escaped quote stays inside the string")
	assert_eq(Scan.strip_strings_and_comments("\tvar n := 4"), "\tvar n := 4",
		"a line with no string or comment comes back unchanged")


func test_parse_finds_column0_functions_and_skips_lambdas() -> void:
	var src := "\n".join(PackedStringArray([
		"extends Node",
		"func a() -> void:",
		"\tvar f := func(x): return x",
		"\tpass",
		"static func b(x: int) -> int:",
		"\treturn x",
	]))
	var names := PackedStringArray()
	for fn in Scan.parse_functions(src):
		names.append(fn["name"])
	assert_eq(",".join(names), "a,b", "the lambda belongs to a()'s body")


func test_parse_handles_a_multiline_signature() -> void:
	var src := "\n".join(PackedStringArray([
		"func long_sig(a: int,",
		"\t\tb: String = \"x:y\",",
		"\t\tc = {\"k\": 1}) -> void:",
		"\tprint(a)",
	]))
	var fns := Scan.parse_functions(src)
	assert_eq(fns.size(), 1)
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 1, "one body line")
	assert_eq(Scan.untyped_parameter_count(fns[0]["signature"]), 1,
		"only c is untyped; colons inside strings and dict defaults do not count")


func test_a_one_line_function_has_one_body_line() -> void:
	var fns := Scan.parse_functions("func f() -> int: return 3")
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 1)


func test_an_unclosed_paren_ends_the_signature_at_end_of_file() -> void:
	var fns := Scan.parse_functions("func broken(:\n\tpass")
	assert_eq(fns.size(), 1, "parsed, not crashed")
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 0)


func test_a_class_level_const_table_is_not_a_function_body() -> void:
	var src := "\n".join(PackedStringArray([
		"func a() -> void:",
		"\tpass",
		"const TABLE := {",
		"\t\"x\": 42,",
		"}",
	]))
	assert_eq(Scan.bare_number_count(Scan.parse_functions(src)[0]["body"]), 0)


func test_code_lines_skip_blanks_and_comments() -> void:
	assert_eq(Scan.code_lines(["\tpass", "", "\t# note", "\t## doc", "\tx = 1 # trailing"]).size(), 2)


func test_bare_numbers_skip_trivial_values_strings_identifiers_consts_and_comments() -> void:
	var body := [
		"\tvar a := 0",
		"\tvar b := 1.0",
		"\tvar c := 42",
		"\tvar d := Vector2(3, 0.5)",
		"\tvar e := \"99\"",
		"\tvar f := node2",
		"\tconst LIMIT := 7",
		"\tvar g := -1 # 100",
	]
	assert_eq(Scan.bare_number_count(body), 2, "only 42 and 3 are bare")
	assert_true(Scan.is_trivial_number("2.0"))
	assert_false(Scan.is_trivial_number("0x10"))


func test_untyped_counts_vars_signatures_and_parameters() -> void:
	var src := "\n".join(PackedStringArray([
		"var a = 1",
		"var b: int = 1",
		"var c := 1",
		"@onready var d = $X",
		"@export_range(0, 10) var e := 5",
		"func f(x, y: int):",
		"\tvar g = 2",
		"\tvar h := 2",
		"\tfor i in 3:",
		"\t\tpass",
	]))
	assert_eq(Scan.untyped_count(src, Scan.parse_functions(src)), 5,
		"a, d and g; f's missing -> ; f's untyped x")
```

Create the two support files the scanner preloads. `ci/clean_code_allowed.gd`:

```gdscript
@tool
extends RefCounted

## Reviewed, permanent exceptions to the clean-code ratchet, keyed per
## measurement (docs/superpowers/design/clean-code.md). Unlike
## ci/clean_code_baseline.gd this file is written by hand, and every entry
## says why it is allowed. A file listed under a measurement is left out of
## that measurement entirely.

## Files exempt from the long-function measurement.
const LONG_FUNCTIONS: PackedStringArray = [
	# ThemeFactory's _build_* functions are declarative style tables, not
	# logic, and CLAUDE.md requires every new theme variation to live there.
	"res://Scripts/Design/ThemeFactory.gd",
]

## Files exempt from the large-script measurement.
const LARGE_SCRIPTS: PackedStringArray = [
	# Same reason: every new theme variation is added to ThemeFactory.gd.
	"res://Scripts/Design/ThemeFactory.gd",
]

## Files exempt from the bare-number measurement.
const BARE_NUMBERS: PackedStringArray = [
	# A style table is made of numbers (margins, radii, sizes).
	"res://Scripts/Design/ThemeFactory.gd",
]

## "source: literal" pairs the literal-path rule accepts although the path
## does not exist.
const UNRESOLVED_PATHS: PackedStringArray = [
	# Optional drop-in art: BaseMinigame checks ResourceLoader.exists() and
	# draws a procedural pause button while the PNG is absent.
	"res://Scripts/Minigames/UI/BaseMinigame.gd: res://Assets/Images/pause_button.png",
]
```

Before saving, confirm the last entry's literal: `git -C "<wt>" grep -n "pause_button.png" -- Scripts/Minigames/UI/BaseMinigame.gd` must show `"res://Assets/Images/pause_button.png"` next to a `ResourceLoader.exists` guard.

`ci/clean_code_baseline.gd` (stub; Task 3 regenerates it):

```gdscript
@tool
extends RefCounted

## Stub. Task 3 replaces this file with ci/clean_code_dump.gd's output.

const LONG_FUNCTIONS: Dictionary = {}
const UNTYPED: Dictionary = {}
const BARE_NUMBERS: Dictionary = {}
const DUPLICATE_GROUPS: Array[String] = []
const LARGE_SCRIPTS: Dictionary = {}
const BAD_SCRIPT_NAMES: Array[String] = []
const CLASS_NAME_MISMATCHES: Array[String] = []
const BAD_ASSET_NAMES: Array[String] = []
const MISSPELLED_NAMES: Array[String] = []
const UNRESOLVED_PATHS: Array[String] = []
const LEGACY_STAT_KEYS: Dictionary = {}
```

- [ ] **Step 3: Run the tests to see them fail.** `filesystem_manage(op="scan", session_id=<sid>)`, then `test_run(suite="clean_code", session_id=<sid>)`. Expected: the suite fails to load (`res://ci/clean_code_scan.gd` does not exist yet).

- [ ] **Step 4: Write the primitives.** Create `ci/clean_code_scan.gd`:

```gdscript
@tool
extends RefCounted

## The clean-code ratchet's scanner: source-text measurements of the project,
## shared by tests/test_clean_code.gd (the editor suite), ci/project_check.gd
## (headless CI, every pull request and every push to Textures) and
## ci/clean_code_dump.gd (which regenerates the baselines).
##
## It reads files with FileAccess and DirAccess only -- no autoloads, no
## class_name lookups, no scenes -- so it also runs under
## `godot --headless --script`. What it measures and why:
## docs/superpowers/design/clean-code.md. The exact definitions:
## docs/superpowers/specs/2026-09-26-clean-code-design.md, section 2.
##
## @tool so the editor suite can call its static functions.

## The generated baselines every measurement is compared against.
const BASELINE := preload("res://ci/clean_code_baseline.gd")
## Reviewed, permanent exceptions, keyed per measurement.
const ALLOWED := preload("res://ci/clean_code_allowed.gd")

## A function body with more code lines than this is "long".
const LONG_FUNCTION_LINES := 50
## A script with more lines than this is "large".
const LARGE_SCRIPT_LINES := 1000
## A duplicated body needs at least this many code lines to count.
const DUPLICATE_MIN_LINES := 5
## Numbers whose meaning is obvious inline.
const TRIVIAL_NUMBERS: Array[float] = [0.0, 1.0, 2.0, 0.5]
## Brackets that nest, for signature and parameter parsing.
const OPENERS: PackedStringArray = ["(", "[", "{"]
## Their closing partners.
const CLOSERS: PackedStringArray = [")", "]", "}"]

## A numeric literal not glued to an identifier: decimal, float, hex, binary.
const NUMBER_PATTERN := "(?<![A-Za-z0-9_.])(0x[0-9A-Fa-f_]+|0b[01_]+|[0-9][0-9_]*(?:\\.[0-9_]*)?(?:[eE][+-]?[0-9]+)?|\\.[0-9][0-9_]*(?:[eE][+-]?[0-9]+)?)(?![A-Za-z0-9_])"
## A var declaration (after annotations); group 1 is everything after its name.
const VAR_PATTERN := "^\\s*(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?var\\s+\\w+(.*)$"

## Compiled RegEx objects, built once per process.
static var _regex_cache: Dictionary = {}


## A compiled RegEx for `pattern`.
static func _regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		var re := RegEx.new()
		re.compile(pattern)
		_regex_cache[pattern] = re
	return _regex_cache[pattern]


## `line` with every string literal's contents blanked to spaces -- the quotes
## stay, so lengths and positions are preserved -- and any trailing `#`
## comment cut off. Handles both quote kinds and backslash escapes; a string
## that does not close on this line is blanked to the end of the line.
static func strip_strings_and_comments(line: String) -> String:
	if not (line.contains("\"") or line.contains("'") or line.contains("#")):
		return line
	var out := ""
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "#":
			break
		if c == "\"" or c == "'":
			out += c
			i += 1
			while i < n and line[i] != c:
				if line[i] == "\\" and i + 1 < n:
					out += "  "
					i += 2
				else:
					out += " "
					i += 1
			if i < n:
				out += c
				i += 1
			continue
		out += c
		i += 1
	return out


## The name of the function a column-0 `func` or `static func` line starts,
## or "" for any other line (lambdas and inner-class methods are indented).
static func function_name(line: String) -> String:
	var rest := line.trim_prefix("static ")
	if not rest.begins_with("func "):
		return ""
	rest = rest.substr(5).strip_edges(true, false)
	var paren := rest.find("(")
	if paren <= 0:
		return ""
	return rest.substr(0, paren).strip_edges()


## The column-0 functions in `src`, in order. The signature runs from `func`
## to the `:` that closes it at bracket depth 0 (an unclosed bracket ends it
## at end of file); the body runs from there to the next column-0 line that is
## not blank and not a comment. Entries: `name`, `line` (1-based), `signature`
## (strings blanked, comments cut) and `body` (raw lines, starting with any
## code a one-line function puts after its colon).
static func parse_functions(src: String) -> Array[Dictionary]:
	var lines := src.split("\n")
	var out: Array[Dictionary] = []
	var i := 0
	while i < lines.size():
		var name := function_name(lines[i])
		if name.is_empty():
			i += 1
			continue
		var start := i
		var signature := ""
		var body: Array = []
		var depth := 0
		var seen_paren := false
		var closed := false
		while i < lines.size() and not closed:
			var raw: String = lines[i]
			var code := strip_strings_and_comments(raw)
			for k in code.length():
				var c := code[k]
				if OPENERS.has(c):
					depth += 1
					seen_paren = seen_paren or c == "("
				elif CLOSERS.has(c):
					depth -= 1
				elif c == ":" and depth == 0 and seen_paren:
					signature += code.substr(0, k + 1)
					var tail := raw.substr(k + 1).strip_edges()
					if not tail.is_empty() and not tail.begins_with("#"):
						body.append(tail)
					closed = true
					break
			if not closed:
				signature += code + " "
			i += 1
		while i < lines.size():
			var line: String = lines[i]
			if not line.is_empty() and not line.begins_with("\t") \
					and not line.begins_with(" ") and not line.begins_with("#"):
				break
			body.append(line)
			i += 1
		out.append({"name": name, "line": start + 1, "signature": signature, "body": body})
	return out


## `body`'s lines, stripped, without the blank and comment-only ones.
static func code_lines(body: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in body:
		var line := String(raw).strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			out.append(line)
	return out


## True for a literal whose meaning is obvious inline: 0, 1, 2 or 0.5 in any
## spelling (a minus sign is not part of the literal).
static func is_trivial_number(text: String) -> bool:
	var plain := text.replace("_", "")
	return plain.is_valid_float() and TRIVIAL_NUMBERS.has(float(plain))


## Bare numeric literals in `body`: strings and comments do not count, nor do
## digits inside identifiers (`Vector2`, `node2`), trivial values, or a local
## `const` line, which names its number.
static func bare_number_count(body: Array) -> int:
	var re := _regex(NUMBER_PATTERN)
	var n := 0
	for raw in body:
		var code := strip_strings_and_comments(String(raw)).strip_edges()
		if code.is_empty() or code.begins_with("const "):
			continue
		for m in re.search_all(code):
			if not is_trivial_number(m.get_string(1)):
				n += 1
	return n


## How many parameters in `signature` have no `: Type` before their default.
## A `:=` default counts as typed; colons and commas inside brackets belong
## to default values.
static func untyped_parameter_count(signature: String) -> int:
	var open := signature.find("(")
	if open == -1:
		return 0
	var untyped := 0
	var depth := 0
	var param := ""
	for i in range(open + 1, signature.length()):
		var c := signature[i]
		if OPENERS.has(c):
			depth += 1
		elif CLOSERS.has(c):
			if depth == 0:
				untyped += _untyped_param(param)
				break
			depth -= 1
		elif depth == 0 and c == ",":
			untyped += _untyped_param(param)
			param = ""
		elif depth == 0:
			param += c
	return untyped


## 1 when a parameter's depth-0 text names no type before its default.
static func _untyped_param(param: String) -> int:
	var text := param.strip_edges()
	if text.is_empty():
		return 0
	return 0 if text.split("=")[0].contains(":") else 1


## Untyped declarations in one script: `var`s with neither `: Type` nor `:=`,
## function signatures without `->`, and parameters without `: Type`.
static func untyped_count(src: String, functions: Array[Dictionary]) -> int:
	var re := _regex(VAR_PATTERN)
	var n := 0
	for raw in src.split("\n"):
		var m := re.search(strip_strings_and_comments(raw))
		if m != null and not m.get_string(1).strip_edges().begins_with(":"):
			n += 1
	for fn in functions:
		var signature: String = fn["signature"]
		if not signature.contains("->"):
			n += 1
		n += untyped_parameter_count(signature)
	return n
```

`full_report()` does not exist yet, so `suite_setup` would fail. Add it now as a placeholder-free minimal version that Task 2 replaces (append to the scanner):

```gdscript
## The whole-project report. Task 1: empty; Task 2 fills in every measurement.
static func full_report() -> Dictionary:
	return {}
```

- [ ] **Step 5: Run the tests to see them pass.** E4 (no-op `script_patch` on `ci/clean_code_scan.gd` and `tests/test_clean_code.gd`), then `test_run(suite="clean_code", session_id=<sid>)`. Expected: all 9 tests PASS.

- [ ] **Step 6: Commit.**

```text
feat(ci): clean-code scanner parsing primitives

Function-range parsing (column-0 funcs, multi-line signatures, lambdas in
the body), string/comment stripping, code-line, bare-number and
untyped-declaration counting, pinned by fixture tests.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```
`git -C "<wt>" add ci/clean_code_scan.gd ci/clean_code_allowed.gd ci/clean_code_baseline.gd tests/test_clean_code.gd` (plus the `.uid` sidecars Godot created for them), then `git -C "<wt>" commit -F <scratch>/msg.txt`.

---

### Task 2: Project measurements, must-be-zero finders and comparisons

**Files:**
- Modify: `ci/clean_code_scan.gd`
- Test: `tests/test_clean_code.gd`

**Interfaces:**
- Consumes: Task 1's primitives.
- Produces (`static`): `production_scripts() -> Array[String]`; `measure_scripts() -> Dictionary` with keys `long_functions` (`{"res://path::func": int}`), `untyped` / `bare_numbers` (`{path: int}`), `duplicate_groups` (`Array[String]`, each `"a::f | b::g"` sorted), `large_scripts` (`{path: int}`); finders `bad_script_names()`, `class_name_mismatches()`, `bad_asset_names()`, `misspelled_names()`, `unresolved_paths()` (all `-> Array[String]`), `legacy_stat_keys() -> Dictionary`; pure rules `is_pascal_case(base)`, `is_safe_asset_name(name)`, `has_misspelled_stem(name)`, `legacy_key_count(text) -> int`, `path_literals(text) -> Array[String]`, `literal_target(literal) -> String`; comparisons `compare_counts`, `compare_large`, `compare_groups`, `compare_lists` (each `-> Dictionary` with `"grown"`/`"shrunk"` `PackedStringArray`); `full_report() -> Dictionary` (the five measurements + `bad_script_names`, `class_name_mismatches`, `bad_asset_names`, `misspelled_names`, `unresolved_paths`, `legacy_stat_keys`).

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_clean_code.gd`:

```gdscript
func test_pascal_case_rule() -> void:
	assert_true(Scan.is_pascal_case("Lobby"))
	assert_true(Scan.is_pascal_case("ShopHubTile"))
	assert_true(Scan.is_pascal_case("A1"))
	assert_false(Scan.is_pascal_case("shop_hub_tile"))
	assert_false(Scan.is_pascal_case("Andi_Table"))


func test_asset_name_rule() -> void:
	assert_true(Scan.is_safe_asset_name("kanan_atas.png"))
	assert_true(Scan.is_safe_asset_name("OpenSans-Bold.ttf"))
	assert_false(Scan.is_safe_asset_name("kanan" + " atas.png"), "a space")
	assert_false(Scan.is_safe_asset_name("pngwing.com (9)" + ".png"), "brackets")
	assert_false(Scan.is_safe_asset_name("a\u2014b.png"), "an em dash")


func test_misspelled_stem_rule() -> void:
	assert_true(Scan.has_misspelled_stem("lo" + "by.gd"))
	assert_true(Scan.has_misspelled_stem("KOP" + "RASI.tscn"), "any case")
	assert_true(Scan.has_misspelled_stem("MuridPo" + "trait"))
	assert_false(Scan.has_misspelled_stem("Lobby.gd"))
	assert_false(Scan.has_misspelled_stem("Koperasi.tscn"))
	assert_false(Scan.has_misspelled_stem("MuridPortrait"))


func test_legacy_key_count_is_case_insensitive_and_sees_inside_identifiers() -> void:
	var sample := "x[\"akad" + "emis2\"] + Kepri" + "badian1 + target_akad" + "emis3"
	assert_eq(Scan.legacy_key_count(sample), 3)
	assert_eq(Scan.legacy_key_count("akademis + seni_budaya + mood"), 0,
		"the real names are not legacy")


func test_path_literals_and_their_targets() -> void:
	assert_eq(",".join(PackedStringArray(Scan.path_literals(
		"A=\"*res://Scenes/A.tscn\"\nb = load('res://b.png')"))),
		"res://Scenes/A.tscn,res://b.png", "the autoload star is stripped")
	assert_eq(Scan.literal_target("res://Scenes/A.tscn"), "res://Scenes/A.tscn")
	assert_eq(Scan.literal_target("res://Assets/Images/Achievements/Icons/"),
		"res://Assets/Images/Achievements/Icons", "a folder literal")
	assert_eq(Scan.literal_target("res://Assets/Images/MuridPortrait/%s.png"),
		"res://Assets/Images/MuridPortrait", "a formatted literal is judged by its folder")
	assert_eq(Scan.literal_target("res://{0}.tscn"), "res://")


func test_compare_counts_both_directions() -> void:
	var result := Scan.compare_counts({"a": 3, "b": 2}, {"a": 4, "c": 1})
	assert_eq(",".join(result["grown"]), "a: baseline 3, now 4,c: baseline 0, now 1")
	assert_eq(",".join(result["shrunk"]), "b: baseline 2, now 0")


func test_compare_large_only_tightens_below_the_bar() -> void:
	assert_true(Scan.compare_large({"x": 1200}, {"x": 1150})["shrunk"].is_empty(),
		"a smaller large script needs no baseline change")
	assert_false(Scan.compare_large({"x": 1200}, {"x": 1201})["grown"].is_empty())
	assert_false(Scan.compare_large({"x": 1200}, {})["shrunk"].is_empty(),
		"dropping to the bar or below removes it from the list")
	assert_false(Scan.compare_large({}, {"y": 1001})["grown"].is_empty())


func test_compare_groups_accepts_a_shrinking_group() -> void:
	var base: Array[String] = ["a::f | b::f | c::f"]
	var smaller: Array[String] = ["a::f | b::f"]
	var result := Scan.compare_groups(base, smaller)
	assert_true(result["grown"].is_empty(), "a subset of a baselined group is not new")
	assert_eq(result["shrunk"].size(), 1, "the old three-way group must be lowered")
	var fresh: Array[String] = ["a::f | d::f"]
	assert_eq(Scan.compare_groups(base, fresh)["grown"].size(), 1)


func test_compare_lists_both_directions() -> void:
	var result := Scan.compare_lists(["x", "y"] as Array[String], ["y", "z"] as Array[String])
	assert_eq(",".join(result["grown"]), "z")
	assert_eq(",".join(result["shrunk"]), "x")


func test_the_full_report_has_every_measurement() -> void:
	for key in ["long_functions", "untyped", "bare_numbers", "duplicate_groups",
			"large_scripts", "bad_script_names", "class_name_mismatches",
			"bad_asset_names", "misspelled_names", "unresolved_paths", "legacy_stat_keys"]:
		assert_true(_report.has(key), "full_report() lacks %s" % key)
	assert_true(_report["untyped"].size() > 0, "the scan found the project's scripts")
```

- [ ] **Step 2: Run to see them fail.** E4 on `tests/test_clean_code.gd`; `test_run(suite="clean_code", session_id=<sid>)`. Expected: the new tests FAIL (functions not found / report empty).

- [ ] **Step 3: Implement.** In `ci/clean_code_scan.gd`, delete the Task 1 `full_report()` stub and append:

```gdscript
## Where the per-function and per-script metrics look.
const SCRIPTS_ROOT := "res://Scripts"
## Scripts no rule reads. Balance.gd belongs to a collaborator (CLAUDE.md).
const EXEMPT_SCRIPTS: PackedStringArray = ["res://Scripts/Balance.gd"]
## Folders whose .gd and .tscn files must be PascalCase, and whose scripts,
## scenes and resources are searched for res:// literals.
const PASCAL_ROOTS: PackedStringArray = ["res://Scripts", "res://Scenes"]
## Folders whose file and folder names may not carry a misspelled stem.
const SPELLING_ROOTS: PackedStringArray = ["res://Scripts", "res://Scenes", "res://Assets", "res://tests"]
## Misspelled stems, matched lowercase. Split so this file never matches.
const MISSPELLED_STEMS: PackedStringArray = ["lo" + "by", "kop" + "rasi", "pot" + "rait"]
## Folders whose text is searched for the legacy stat keys.
const LEGACY_ROOTS: PackedStringArray = ["res://Scripts", "res://Scenes", "res://tests"]
## The text files those searches read.
const TEXT_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
## The legacy stat keys, any case, inside any identifier or string. Split so
## this file never matches.
const LEGACY_PATTERN := "(?i)(akad" + "emis[123]|kepri" + "badian[12])"
## A PascalCase base name.
const PASCAL_PATTERN := "^[A-Z][A-Za-z0-9]*$"
## An asset name made only of safe characters.
const SAFE_ASSET_PATTERN := "^[A-Za-z0-9_.\\-]+$"
## A quoted res:// literal; group 1 drops an autoload's leading `*`.
const PATH_LITERAL_PATTERN := "[\"']\\*?(res://[^\"'\\n]*)[\"']"
## A class_name declaration; group 1 is the name.
const CLASS_NAME_PATTERN := "(?m)^class_name\\s+(\\w+)"


## True when the walk must not enter `dir`: a dot-folder, a folder holding a
## .gdignore, or a nested project (a folder with its own project.godot, such
## as -REFERENCE-/prototype). The same folders the editor ignores.
static func _skip_dir(dir: String) -> bool:
	if dir == "res://":
		return false
	if dir.get_file().begins_with("."):
		return true
	return FileAccess.file_exists(dir.path_join(".gdignore")) \
			or FileAccess.file_exists(dir.path_join("project.godot"))


## Every path under `root`, sorted: files, plus folders when `include_dirs`.
static func _walk(root: String, include_dirs: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		if _skip_dir(dir):
			continue
		if include_dirs and dir != root:
			out.append(dir)
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			out.append(dir.path_join(file))
	out.sort()
	return out


## The scripts the metrics read: every .gd under Scripts/ except the exempt.
static func production_scripts() -> Array[String]:
	var out: Array[String] = []
	for path in _walk(SCRIPTS_ROOT, false):
		if path.get_extension() == "gd" and not EXEMPT_SCRIPTS.has(path):
			out.append(path)
	return out


## One pass over every production script. Keys: "long_functions"
## {"path::function": code lines}, "untyped" {path: n}, "bare_numbers"
## {path: n}, "duplicate_groups" (sorted "a::f | b::g" strings) and
## "large_scripts" {path: lines}. Zero counts are left out, and each
## measurement skips the files ALLOWED exempts from it.
static func measure_scripts() -> Dictionary:
	var long_functions := {}
	var untyped := {}
	var bare_numbers := {}
	var large_scripts := {}
	var bodies := {}
	for path in production_scripts():
		var src := FileAccess.get_file_as_string(path)
		var functions := parse_functions(src)
		var line_total := src.trim_suffix("\n").split("\n").size()
		if line_total > LARGE_SCRIPT_LINES and not ALLOWED.LARGE_SCRIPTS.has(path):
			large_scripts[path] = line_total
		var untyped_here := untyped_count(src, functions)
		if untyped_here > 0:
			untyped[path] = untyped_here
		var numbers_here := 0
		for fn in functions:
			var key := "%s::%s" % [path, fn["name"]]
			var code := code_lines(fn["body"])
			if code.size() > LONG_FUNCTION_LINES and not ALLOWED.LONG_FUNCTIONS.has(path):
				long_functions[key] = code.size()
			if not ALLOWED.BARE_NUMBERS.has(path):
				numbers_here += bare_number_count(fn["body"])
			if code.size() >= DUPLICATE_MIN_LINES:
				var text := "\n".join(code)
				if not bodies.has(text):
					bodies[text] = []
				bodies[text].append(key)
		if numbers_here > 0:
			bare_numbers[path] = numbers_here
	return {
		"long_functions": long_functions,
		"untyped": untyped,
		"bare_numbers": bare_numbers,
		"duplicate_groups": duplicate_groups(bodies),
		"large_scripts": large_scripts,
	}


## The bodies found in two or more files, each as its sorted members joined
## by " | ".
static func duplicate_groups(bodies: Dictionary) -> Array[String]:
	var groups: Array[String] = []
	for text in bodies:
		var members: Array = bodies[text]
		var files := {}
		for member in members:
			files[String(member).get_slice("::", 0)] = true
		if files.size() >= 2:
			members.sort()
			groups.append(" | ".join(PackedStringArray(members)))
	groups.sort()
	return groups


## True for a PascalCase base name such as "Lobby" or "ShopHubTile".
static func is_pascal_case(base: String) -> bool:
	return _regex(PASCAL_PATTERN).search(base) != null


## True when an asset name uses only A-Z a-z 0-9 _ - and .
static func is_safe_asset_name(name: String) -> bool:
	return _regex(SAFE_ASSET_PATTERN).search(name) != null


## True when a file or folder name carries a misspelled stem, in any case.
static func has_misspelled_stem(name: String) -> bool:
	var lower := name.to_lower()
	for stem in MISSPELLED_STEMS:
		if lower.contains(stem):
			return true
	return false


## How many legacy stat keys `text` holds.
static func legacy_key_count(text: String) -> int:
	return _regex(LEGACY_PATTERN).search_all(text).size()


## Every quoted res:// literal in `text`, without an autoload's leading `*`.
static func path_literals(text: String) -> Array[String]:
	var out: Array[String] = []
	for m in _regex(PATH_LITERAL_PATTERN).search_all(text):
		out.append(m.get_string(1))
	return out


## The path a literal must resolve to. A formatted literal (holding `%` or
## `{`) is judged by its static prefix: the folder up to the last `/` before
## the first `%` or `{`. A trailing `/` is dropped.
static func literal_target(literal: String) -> String:
	var cut := literal.length()
	for marker in ["%", "{"]:
		var at := literal.find(marker)
		if at != -1:
			cut = mini(cut, at)
	var target := literal
	if cut < literal.length():
		target = literal.substr(0, literal.rfind("/", cut) + 1)
	target = target.trim_suffix("/")
	return "res://" if target == "res:/" else target


## .gd and .tscn files under Scripts/ and Scenes/ whose base name is not
## PascalCase.
static func bad_script_names() -> Array[String]:
	var out: Array[String] = []
	for root in PASCAL_ROOTS:
		for path in _walk(root, false):
			var ext := path.get_extension()
			if (ext == "gd" or ext == "tscn") and not is_pascal_case(path.get_file().get_basename()):
				out.append(path)
	out.sort()
	return out


## Production scripts whose file is not named after their class_name.
static func class_name_mismatches() -> Array[String]:
	var out: Array[String] = []
	for path in production_scripts():
		var m := _regex(CLASS_NAME_PATTERN).search(FileAccess.get_file_as_string(path))
		if m != null and m.get_string(1) != path.get_file().get_basename():
			out.append("%s (class_name %s)" % [path, m.get_string(1)])
	return out


## Files and folders under Assets/ whose name holds an unsafe character
## (.import and .uid sidecars follow their asset and are not listed).
static func bad_asset_names() -> Array[String]:
	var out: Array[String] = []
	for path in _walk("res://Assets", true):
		var name := path.get_file()
		if name.ends_with(".import") or name.ends_with(".uid"):
			continue
		if not is_safe_asset_name(name):
			out.append(path)
	return out


## Files and folders whose name carries a misspelled stem.
static func misspelled_names() -> Array[String]:
	var out: Array[String] = []
	for root in SPELLING_ROOTS:
		for path in _walk(root, true):
			if has_misspelled_stem(path.get_file()):
				out.append(path)
	out.sort()
	return out


## The files searched for res:// literals: project.godot plus every script,
## scene and resource under Scripts/ and Scenes/.
static func literal_sources() -> Array[String]:
	var out: Array[String] = ["res://project.godot"]
	for root in PASCAL_ROOTS:
		for path in _walk(root, false):
			if TEXT_EXTENSIONS.has(path.get_extension()) and not EXEMPT_SCRIPTS.has(path):
				out.append(path)
	return out


## "source: literal" for every res:// literal naming nothing that exists with
## that exact case. The editor's filesystem ignores case on Windows; Android
## and Linux CI do not, so the check compares against DirAccess's listing.
static func unresolved_paths() -> Array[String]:
	var existing := {}
	for path in _walk("res://", true):
		existing[path] = true
	var found := {}
	for source in literal_sources():
		for literal in path_literals(FileAccess.get_file_as_string(source)):
			var target := literal_target(literal)
			var entry := "%s: %s" % [source, literal]
			if target != "res://" and not existing.has(target) \
					and not ALLOWED.UNRESOLVED_PATHS.has(entry):
				found[entry] = true
	var out: Array[String] = []
	out.assign(found.keys())
	out.sort()
	return out


## {path: count} of legacy stat keys in scripts, scenes, resources and tests.
static func legacy_stat_keys() -> Dictionary:
	var out := {}
	for root in LEGACY_ROOTS:
		for path in _walk(root, false):
			if not TEXT_EXTENSIONS.has(path.get_extension()) or EXEMPT_SCRIPTS.has(path):
				continue
			var n := legacy_key_count(FileAccess.get_file_as_string(path))
			if n > 0:
				out[path] = n
	return out


## Everything the ratchet measures, in one report.
static func full_report() -> Dictionary:
	var report := measure_scripts()
	report["bad_script_names"] = bad_script_names()
	report["class_name_mismatches"] = class_name_mismatches()
	report["bad_asset_names"] = bad_asset_names()
	report["misspelled_names"] = misspelled_names()
	report["unresolved_paths"] = unresolved_paths()
	report["legacy_stat_keys"] = legacy_stat_keys()
	return report


## Ratchet comparison of two {key: count} maps; a missing key counts as 0.
## "grown" and "shrunk" hold "key: baseline N, now M" lines, sorted.
static func compare_counts(baseline: Dictionary, current: Dictionary) -> Dictionary:
	var grown := PackedStringArray()
	var shrunk := PackedStringArray()
	for key in current:
		var was := int(baseline.get(key, 0))
		var now := int(current[key])
		if now > was:
			grown.append("%s: baseline %d, now %d" % [key, was, now])
	for key in baseline:
		var was := int(baseline[key])
		var now := int(current.get(key, 0))
		if now < was:
			shrunk.append("%s: baseline %d, now %d" % [key, was, now])
	grown.sort()
	shrunk.sort()
	return {"grown": grown, "shrunk": shrunk}


## Large-script comparison: a listed script may not pass its baseline, no
## other script may appear, and a listed script only needs removing once it
## is at or under LARGE_SCRIPT_LINES -- not on every line removed.
static func compare_large(baseline: Dictionary, current: Dictionary) -> Dictionary:
	var grown := PackedStringArray()
	var shrunk := PackedStringArray()
	for key in current:
		if not baseline.has(key) or int(current[key]) > int(baseline[key]):
			grown.append("%s: baseline %d, now %d" % [key, int(baseline.get(key, 0)), int(current[key])])
	for key in baseline:
		if not current.has(key):
			shrunk.append("%s: now %d lines or fewer -- remove it" % [key, LARGE_SCRIPT_LINES])
	grown.sort()
	shrunk.sort()
	return {"grown": grown, "shrunk": shrunk}


## Duplicate-group comparison: a current group is new unless its members are
## a subset of one baselined group; a baselined group not present exactly
## has shrunk and must be lowered.
static func compare_groups(baseline: Array, current: Array) -> Dictionary:
	var grown := PackedStringArray()
	var shrunk := PackedStringArray()
	for group in current:
		var members := String(group).split(" | ")
		var covered := false
		for old in baseline:
			var old_members := String(old).split(" | ")
			var all_in := true
			for member in members:
				if not old_members.has(member):
					all_in = false
					break
			if all_in:
				covered = true
				break
		if not covered:
			grown.append(String(group))
	for old in baseline:
		if not current.has(old):
			shrunk.append(String(old))
	grown.sort()
	shrunk.sort()
	return {"grown": grown, "shrunk": shrunk}


## Must-be-zero comparison: offenders not in the baseline list are new;
## listed offenders that are gone must be removed from the list.
static func compare_lists(baseline: Array, current: Array) -> Dictionary:
	var grown := PackedStringArray()
	var shrunk := PackedStringArray()
	for entry in current:
		if not baseline.has(entry):
			grown.append(String(entry))
	for entry in baseline:
		if not current.has(entry):
			shrunk.append(String(entry))
	grown.sort()
	shrunk.sort()
	return {"grown": grown, "shrunk": shrunk}
```

- [ ] **Step 4: Run to see them pass.** E4 on both files; `test_run(suite="clean_code", session_id=<sid>)`. Expected: all tests PASS. If `suite_setup` takes more than ~5 s, note the time for the reviewer (a full run must stay under the bridge's 20 s blocking limit).

- [ ] **Step 5: Commit** (`feat(ci): clean-code measurements, must-be-zero finders and comparisons`, same trailer), files `ci/clean_code_scan.gd tests/test_clean_code.gd`.

---

### Task 3: Baselines, dump tool and ratchet tests

**Files:**
- Modify: `ci/clean_code_scan.gd`
- Create: `ci/clean_code_dump.gd`
- Regenerate: `ci/clean_code_baseline.gd`
- Test: `tests/test_clean_code.gd`

**Interfaces:**
- Consumes: `full_report()`, the four `compare_*` functions.
- Produces: `MEASUREMENTS: Array[Dictionary]` (each `{"key", "const", "kind", "doc"}`), `baseline_for(measurement) -> Variant`, `compare(measurement, baseline, current) -> Dictionary`, `compare_all(report) -> Dictionary` (`"failures"`, `"warnings"`: `PackedStringArray`), `format_baseline(report) -> String`, `summary(report) -> String`. Task 4's `project_check.gd` calls `compare_all(full_report())`.

- [ ] **Step 1: Write the failing ratchet tests.** Append to `tests/test_clean_code.gd`:

```gdscript
func test_every_measurement_has_a_baseline_constant() -> void:
	var constants: Dictionary = Scan.BASELINE.get_script_constant_map()
	for measurement in Scan.MEASUREMENTS:
		assert_true(constants.has(measurement["const"]),
			"ci/clean_code_baseline.gd lacks %s" % measurement["const"])


## The MEASUREMENTS entry for report key `key`.
func _measurement(key: String) -> Dictionary:
	for measurement in Scan.MEASUREMENTS:
		if measurement["key"] == key:
			return measurement
	return {}


## Fails when `key`'s measurement grew past its baseline.
func _assert_not_grown(key: String) -> void:
	var measurement := _measurement(key)
	var result := Scan.compare(measurement, Scan.baseline_for(measurement), _report[key])
	assert_true(result["grown"].is_empty(),
		"clean-code %s grew -- fix the code; see docs/superpowers/design/clean-code.md:\n%s"
			% [key, "\n".join(result["grown"])])


## Fails when `key`'s measurement shrank and its baseline was not lowered.
func _assert_baseline_tight(key: String) -> void:
	var measurement := _measurement(key)
	var result := Scan.compare(measurement, Scan.baseline_for(measurement), _report[key])
	assert_true(result["shrunk"].is_empty(),
		("clean-code %s shrank -- lock it in this commit: run ci/clean_code_dump.gd "
			+ "and check the baseline diff only lowers numbers:\n%s")
			% [key, "\n".join(result["shrunk"])])


func test_long_functions_did_not_grow() -> void:
	_assert_not_grown("long_functions")

func test_long_functions_baseline_is_tight() -> void:
	_assert_baseline_tight("long_functions")

func test_untyped_did_not_grow() -> void:
	_assert_not_grown("untyped")

func test_untyped_baseline_is_tight() -> void:
	_assert_baseline_tight("untyped")

func test_bare_numbers_did_not_grow() -> void:
	_assert_not_grown("bare_numbers")

func test_bare_numbers_baseline_is_tight() -> void:
	_assert_baseline_tight("bare_numbers")

func test_duplicate_groups_did_not_grow() -> void:
	_assert_not_grown("duplicate_groups")

func test_duplicate_groups_baseline_is_tight() -> void:
	_assert_baseline_tight("duplicate_groups")

func test_large_scripts_did_not_grow() -> void:
	_assert_not_grown("large_scripts")

func test_large_scripts_baseline_is_tight() -> void:
	_assert_baseline_tight("large_scripts")

func test_no_new_bad_script_names() -> void:
	_assert_not_grown("bad_script_names")

func test_bad_script_names_baseline_is_tight() -> void:
	_assert_baseline_tight("bad_script_names")

func test_no_new_class_name_mismatches() -> void:
	_assert_not_grown("class_name_mismatches")

func test_class_name_mismatches_baseline_is_tight() -> void:
	_assert_baseline_tight("class_name_mismatches")

func test_no_new_bad_asset_names() -> void:
	_assert_not_grown("bad_asset_names")

func test_bad_asset_names_baseline_is_tight() -> void:
	_assert_baseline_tight("bad_asset_names")

func test_no_new_misspelled_names() -> void:
	_assert_not_grown("misspelled_names")

func test_misspelled_names_baseline_is_tight() -> void:
	_assert_baseline_tight("misspelled_names")

func test_no_new_unresolved_paths() -> void:
	_assert_not_grown("unresolved_paths")

func test_unresolved_paths_baseline_is_tight() -> void:
	_assert_baseline_tight("unresolved_paths")

func test_no_new_legacy_stat_keys() -> void:
	_assert_not_grown("legacy_stat_keys")

func test_legacy_stat_keys_baseline_is_tight() -> void:
	_assert_baseline_tight("legacy_stat_keys")
```

- [ ] **Step 2: Run to see them fail.** E4; `test_run(suite="clean_code", session_id=<sid>)`. Expected: FAIL (`MEASUREMENTS` not found).

- [ ] **Step 3: Implement.** Append to `ci/clean_code_scan.gd`:

```gdscript
## Each measurement: its report key, its baseline constant, how it ratchets
## ("counts", "large", "groups" or "list") and the doc line the dump writes.
const MEASUREMENTS: Array[Dictionary] = [
	{"key": "long_functions", "const": "LONG_FUNCTIONS", "kind": "counts",
		"doc": "Functions over 50 code lines: \"path::function\" -> code lines."},
	{"key": "untyped", "const": "UNTYPED", "kind": "counts",
		"doc": "Untyped vars, signatures without ->, untyped parameters, per script."},
	{"key": "bare_numbers", "const": "BARE_NUMBERS", "kind": "counts",
		"doc": "Bare numeric literals in function bodies, per script."},
	{"key": "duplicate_groups", "const": "DUPLICATE_GROUPS", "kind": "groups",
		"doc": "Function bodies (5+ code lines) identical in two or more files."},
	{"key": "large_scripts", "const": "LARGE_SCRIPTS", "kind": "large",
		"doc": "Scripts over 1,000 lines -> their line count."},
	{"key": "bad_script_names", "const": "BAD_SCRIPT_NAMES", "kind": "list",
		"doc": "Must reach zero: .gd/.tscn names that are not PascalCase."},
	{"key": "class_name_mismatches", "const": "CLASS_NAME_MISMATCHES", "kind": "list",
		"doc": "Must reach zero: scripts not named after their class_name."},
	{"key": "bad_asset_names", "const": "BAD_ASSET_NAMES", "kind": "list",
		"doc": "Must reach zero: asset names with characters outside A-Z a-z 0-9 _ - ."},
	{"key": "misspelled_names", "const": "MISSPELLED_NAMES", "kind": "list",
		"doc": "Must reach zero: file and folder names with a misspelled stem."},
	{"key": "unresolved_paths", "const": "UNRESOLVED_PATHS", "kind": "list",
		"doc": "Must stay zero: res:// literals naming nothing with that exact case."},
	{"key": "legacy_stat_keys", "const": "LEGACY_STAT_KEYS", "kind": "counts",
		"doc": "Must reach zero: legacy stat keys per file."},
]


## `measurement`'s value in ci/clean_code_baseline.gd.
static func baseline_for(measurement: Dictionary) -> Variant:
	return BASELINE.get_script_constant_map()[measurement["const"]]


## {"grown", "shrunk"} for one measurement, dispatched on its kind.
static func compare(measurement: Dictionary, baseline: Variant, current: Variant) -> Dictionary:
	var kind: String = measurement["kind"]
	if kind == "counts":
		return compare_counts(baseline, current)
	if kind == "large":
		return compare_large(baseline, current)
	if kind == "groups":
		return compare_groups(baseline, current)
	return compare_lists(baseline, current)


## Every measurement against its baseline. Growth is a failure; a shrink is
## only a warning here, because CI cannot lower a baseline and a red check
## for an improvement would block every later PR. The editor suite fails on
## a shrink instead (tests/test_clean_code.gd).
static func compare_all(report: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	for measurement in MEASUREMENTS:
		var result := compare(measurement, baseline_for(measurement), report[measurement["key"]])
		for line in result["grown"]:
			failures.append("clean-code %s grew: %s -- see docs/superpowers/design/clean-code.md"
				% [measurement["key"], line])
		for line in result["shrunk"]:
			warnings.append("clean-code %s shrank: %s -- lower it with ci/clean_code_dump.gd"
				% [measurement["key"], line])
	return {"failures": failures, "warnings": warnings}


## The full text of ci/clean_code_baseline.gd for `report`.
static func format_baseline(report: Dictionary) -> String:
	var lines := PackedStringArray([
		"@tool",
		"extends RefCounted",
		"",
		"## GENERATED by ci/clean_code_dump.gd: the clean-code ratchet's baselines",
		"## (docs/superpowers/design/clean-code.md). Every number here may only go",
		"## DOWN. Never raise one by hand: fix the code, or add a reviewed, permanent",
		"## exception to ci/clean_code_allowed.gd. Regenerate after an improvement:",
		"##     <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd",
	])
	for measurement in MEASUREMENTS:
		lines.append("")
		lines.append("## " + String(measurement["doc"]))
		var value: Variant = report[measurement["key"]]
		if value is Dictionary:
			lines.append("const %s: Dictionary = {" % measurement["const"])
			var keys: Array = value.keys()
			keys.sort()
			for key in keys:
				lines.append("\t\"%s\": %d," % [String(key).json_escape(), int(value[key])])
			lines.append("}")
		else:
			lines.append("const %s: Array[String] = [" % measurement["const"])
			for entry in value:
				lines.append("\t\"%s\"," % String(entry).json_escape())
			lines.append("]")
	return "\n".join(lines) + "\n"


## One line per measurement: its entry count and the sum of its counts.
static func summary(report: Dictionary) -> String:
	var lines := PackedStringArray()
	for measurement in MEASUREMENTS:
		var value: Variant = report[measurement["key"]]
		var total := 0
		if value is Dictionary:
			for key in value:
				total += int(value[key])
		else:
			total = value.size()
		lines.append("%s: %d entries, total %d" % [measurement["key"], value.size(), total])
	return "\n".join(lines)
```

Create `ci/clean_code_dump.gd`:

```gdscript
extends SceneTree

## Regenerates ci/clean_code_baseline.gd from the current tree, then prints a
## per-measurement summary. Run it after an improvement lowers a count (the
## editor suite's *_baseline_is_tight tests say when), and review the diff:
## every number may only go down.
##
##     <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd
##
## Pure file I/O through ci/clean_code_scan.gd; it needs no autoloads, which
## --script mode does not register anyway.

## The scanner that measures the tree.
const Scan := preload("res://ci/clean_code_scan.gd")
## The file this tool rewrites.
const OUT_PATH := "res://ci/clean_code_baseline.gd"


func _init() -> void:
	var report: Dictionary = Scan.full_report()
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("clean_code_dump: cannot write %s: %s"
			% [OUT_PATH, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	file.store_string(Scan.format_baseline(report))
	file.close()
	print(Scan.summary(report))
	print("clean_code_dump: wrote ", OUT_PATH)
	quit(0)
```

- [ ] **Step 4: Generate the real baseline.** PowerShell:

```powershell
& "<console>" --headless --path "<wt>" --script res://ci/clean_code_dump.gd
```
Expected output ends with `clean_code_dump: wrote res://ci/clean_code_baseline.gd`, and the summary matches a Python port of this scanner run on the same tree (2026-09-26): `long_functions` 46 entries (4 of them over 100); `untyped` 44 entries, total 1,588; `bare_numbers` 95 entries, total 2,120; `duplicate_groups` 22; `large_scripts` 5 (ThemeFactory allowed); `misspelled_names` 21; `bad_script_names` 33 (19 scripts, 13 scenes and `Scripts/Inventory/item_database.tscn`); `class_name_mismatches` 2; `bad_asset_names` 17 (the spaced/bracketed/em-dash names, including `Shop/rak 1.jpg`); `unresolved_paths` 0; `legacy_stat_keys` 48 entries, total 1,182. (The spec's rougher "Today" figures — ~106 long functions, ~1,620 untyped — counted raw lines and the 37 multi-line signatures; these are the exact definitions.) Save the whole summary to `<scratch>/pr1_summary.txt`. Commits that landed on `Textures` since 2026-09-26 may move a count by a few; a count off by more than ~10% means a scanner bug: stop and investigate — never hand-edit the baseline.

- [ ] **Step 5: Run the ratchet.** E4 on `ci/clean_code_scan.gd`, `ci/clean_code_baseline.gd`, `tests/test_clean_code.gd`; `test_run(suite="clean_code", session_id=<sid>)`. Expected: all tests PASS. Record the suite's duration.

- [ ] **Step 6: Prove the ratchet bites (then undo).** Append `\nfunc zz_probe(a):\n\tpass\n` to `Scripts/TutorialArrow.gd`, E4, run the suite: `test_untyped_did_not_grow` must FAIL naming `res://Scripts/TutorialArrow.gd`. Then `git -C "<wt>" checkout -- Scripts/TutorialArrow.gd`, E4, re-run: PASS.

- [ ] **Step 7: Commit** (`feat(ci): clean-code baselines, dump tool and ratchet tests`), files `ci/clean_code_scan.gd ci/clean_code_dump.gd ci/clean_code_baseline.gd tests/test_clean_code.gd` + `.uid` sidecars.

---

### Task 4: Run the scan in CI

**Files:**
- Modify: `ci/project_check.gd`, `tests/test_project_check.gd`, `ci/selftest_project_check.sh`

**Interfaces:**
- Consumes: `compare_all(full_report())` from Task 3.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_project_check.gd`:

```gdscript
func test_the_check_runs_the_clean_code_scan_and_only_warns_on_a_shrink() -> void:
	var src := FileAccess.get_file_as_string("res://ci/project_check.gd")
	assert_true(src.contains("CleanCodeScan.compare_all(CleanCodeScan.full_report())"),
		"project_check runs the clean-code scan")
	assert_true(src.contains("failures.append_array(clean_code[\"failures\"])"),
		"growth and must-be-zero violations fail CI")
	assert_true(src.contains("print(\"WARNING: \", warning)"),
		"a shrink is only a warning in CI")
```
Run `test_run(suite="project_check", session_id=<sid>)` after E4: FAIL.

- [ ] **Step 2: Implement.** In `ci/project_check.gd`, add after the header doc block's last paragraph (before `## File extensions the check loads.`) this doc paragraph, and the const:

```gdscript
## It also runs the clean-code scan (ci/clean_code_scan.gd,
## docs/superpowers/design/clean-code.md): a measurement that grew, or a
## must-be-zero rule with a new offender, is a failure; a measurement that
## shrank is printed as a `WARNING:` line, which the workflow copies to the
## step summary without failing -- CI cannot lower a baseline, and a red
## check for an improvement would block every later PR.

## The clean-code ratchet's scanner.
const CleanCodeScan := preload("res://ci/clean_code_scan.gd")
```
(The first paragraph belongs in the file's leading `##` header block: append it there, after the `Design: docs/superpowers/specs/2026-09-11-pr-automation-design.md.` line, joined by a `##` blank line.)

Replace `_ready()` with:

```gdscript
## Runs the whole check when this scene is the game's main scene.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var files := collect_files("res://")
	var failures := PackedStringArray()
	for path in files:
		failures.append_array(check_file(path))
	var clean_code := CleanCodeScan.compare_all(CleanCodeScan.full_report())
	failures.append_array(clean_code["failures"])
	print("PROJECT CHECK: checked %d files, %d failures" % [files.size(), failures.size()])
	for failure in failures:
		print("PROJECT CHECK FAIL: ", failure)
	for warning in clean_code["warnings"]:
		print("WARNING: ", warning)
	get_tree().quit(1 if not failures.is_empty() else 0)
```

- [ ] **Step 3: Update the selftest.** In `ci/selftest_project_check.sh`, replace the `run_check()` function and the three planted cases (from `# run_check <pass|fail> <description>` through the autoload case's `rm "$PROJECT/zz_selftest_autoload.gd"`) with:

```bash
# run_check <pass|fail> <description> [pattern]: runs the check the way the
# workflow does. A fail case must also print `pattern`, so it fails for the
# reason it tests rather than for an unrelated one.
run_check() {
  "$GODOT" --headless --path "$GODOT_PROJECT" res://ci/project_check.tscn > "$WORK/check.log" 2>&1
  local status=$? errors verdict=pass
  errors=$(grep -cE '^(ERROR|SCRIPT ERROR):' "$WORK/check.log")
  if (( status != 0 || errors > 0 )); then verdict=fail; fi
  if [[ "$verdict" == "fail" && -n "${3:-}" ]] && ! grep -qF -- "$3" "$WORK/check.log"; then
    verdict="fail without \"$3\""
  fi
  if [[ "$verdict" == "$1" ]]; then
    echo "ok   - $2 ($verdict: exit $status, $errors error lines)"
  else
    echo "FAIL - $2: expected $1, got $verdict (exit $status, $errors error lines)"
    grep -E '^(PROJECT CHECK|ERROR|SCRIPT ERROR|WARNING)' "$WORK/check.log" | head -20
    failures=$((failures + 1))
  fi
}

run_check pass "the clean tree passes"

# The broken fixtures live at the project root: outside every folder the
# clean-code scan reads, while collect_files("res://") still loads them.
printf 'extends Node\nfunc broken(:\n\tpass\n' > "$PROJECT/zz_selftest_broken.gd"
run_check fail "a script that does not parse fails" "res://zz_selftest_broken.gd:"
rm "$PROJECT/zz_selftest_broken.gd"

cat > "$PROJECT/zz_selftest_missing.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://Assets/zz_does_not_exist.png" id="1_missing"]

[node name="Missing" type="Sprite2D"]
texture = ExtResource("1_missing")
EOF
run_check fail "a scene pointing at a missing texture fails" "missing dependency"
rm "$PROJECT/zz_selftest_missing.tscn"

printf 'extends Node\nfunc _ready() -> void:\n\tpush_error("selftest: autoload failed on boot")\n' \
  > "$PROJECT/zz_selftest_autoload.gd"
sed -i 's/^\[autoload\]$/[autoload]\n\nZzSelftest="*res:\/\/zz_selftest_autoload.gd"/' "$PROJECT/project.godot"
run_check fail "an autoload that errors on boot fails" "selftest: autoload failed on boot"
cp "$WORK/project.godot.clean" "$PROJECT/project.godot"
rm "$PROJECT/zz_selftest_autoload.gd"

printf 'extends Node\n## Selftest.\nfunc untyped(value):\n\tpass\n' > "$PROJECT/Scripts/ZzSelftestUntyped.gd"
run_check fail "untyped code fails the clean-code scan" "clean-code untyped grew"
rm "$PROJECT/Scripts/ZzSelftestUntyped.gd"
```
Also update the file's opening comment: "…then plants one breakage at a time -- a script that does not parse, a scene pointing at a missing texture, an autoload that errors on boot, a script that adds clean-code debt -- and requires each to FAIL for its own reason."

The parse fixture's pattern is the failure line's path prefix, not a message, because Godot may report a broken script as `script has errors` or `failed to load`; either names the planted file.

- [ ] **Step 4: Verify.** E4 on `ci/project_check.gd` and `tests/test_project_check.gd`; `test_run(suite="project_check", session_id=<sid>)` → PASS. Then R2's headless project check → `0 failures` (and a count of any `WARNING:` lines: expect none). Then run the selftest in the background (it copies and imports the whole tree; allow 10 minutes), from Git Bash:

```bash
bash ci/selftest_project_check.sh "/c/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe"
```
Expected: five `ok   -` lines and `0 failure(s)`. E6 afterwards.

- [ ] **Step 5: Commit** (`feat(ci): project_check runs the clean-code scan`), files `ci/project_check.gd tests/test_project_check.gd ci/selftest_project_check.sh`.

---

### Task 5: The rulebook and the docs

**Files:**
- Create: `docs/superpowers/design/clean-code.md`
- Modify: `CLAUDE.md`, `docs/superpowers/design/style-guide.md`, `docs/superpowers/design/authoring-guide.md`, `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Write the rulebook.** Create `docs/superpowers/design/clean-code.md` with exactly this content:

````markdown
# Clean code in KejarTes

How this project applies Codacy's clean-code principles
([What is clean code](https://blog.codacy.com/what-is-clean-code)) to
GDScript and Godot 4.6. Why each rule is shaped the way it is:
`docs/superpowers/specs/2026-09-26-clean-code-design.md`. The language
baseline is Godot's own
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
and [static typing guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html).

**⚙ = enforced** by the clean-code ratchet: `ci/clean_code_scan.gd`, run by
`tests/test_clean_code.gd` in the editor suite and by `ci/project_check.gd`
on every pull request and every push to `Textures`. The rest is review
guidance.

## The ratchet in one minute

- Today's debt is frozen in `ci/clean_code_baseline.gd` (generated). A count
  may only go **down**.
- **"grew"** means your change added debt. Fix the code: split the function,
  name the number, add the type. A reviewed, permanent exception goes in
  `ci/clean_code_allowed.gd`, with a comment saying why.
- **"shrank"** means you improved something. Lock it in, in the same commit:

      <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd

  then check that `git diff ci/clean_code_baseline.gd` only lowers numbers or
  removes entries. (The editor suite fails on an un-locked shrink; CI only
  prints a `WARNING:`.)
- A **new** script has no baseline, so it is clean from its first commit.
- Never raise a baseline number by hand.
- **`Textures` went red on the ratchet** (a hand-merged change): whoever landed
  it fixes it; failing that, the next session to run `ship-pr` fixes it as
  its first commit — for a shrink, run the dump tool; for a growth, fix the
  code (or add a commented `ci/clean_code_allowed.gd` entry) and tell the
  user.

## 1. Names say what a thing is ⚙

- Casing: `snake_case` functions and variables, `PascalCase` classes and
  node names, `CONSTANT_CASE` constants and enum values.
- Signals are past-tense events: `week_finished`, `item_bought`. Booleans
  read as questions: `is_locked`, `has_item`, `can_afford`.
- No numbered stand-ins (`value2`) and no `data`, `tmp`, `obj`, `x2`.
- Game words in Indonesian, engine and system code in English; match the
  file you are in.

```gdscript
# Before
var d = GameState.approved_students[i]
signal done
var check := true

# After
var student: Dictionary = GameState.approved_students[index]
signal week_finished
var is_locked := true
```

**File names ⚙:**

| What | Rule | Example |
|---|---|---|
| `.gd`, `.tscn` | PascalCase | `Lobby.gd`, `Lobby.tscn` |
| Script with `class_name X` | named `X.gd` | `TutorialStepData.gd` |
| A scene and its own root script | share one name | `StudentCard.tscn` + `StudentCard.gd` |
| A script shared by several scenes | named for its class | `StudentFace.gd` drives `AndiFace.tscn`, … |
| Assets | only `A–Z a–z 0–9 _ - .`; new art in `snake_case` | `kanan_atas.png` |
| Tests | `tests/test_<topic>.gd` (the runner needs it) | `tests/test_lobby.gd` |

**Every `res://` literal must match the file's exact case ⚙.** Windows
ignores case, so a wrong-case path works in the editor and breaks on Android
and in Linux CI. A formatted path (`"res://Assets/Images/X/%s.png"`) is
checked by its folder.

## 2. No magic numbers ⚙

A number that means something gets a name.

```gdscript
# Before
if student.energy <= 5:
	_force_izin(student)

# After
## Energy at or below this forces "Izin", a forced Istirahat day.
const IZIN_ENERGY_THRESHOLD := 5.0

if student.energy <= IZIN_ENERGY_THRESHOLD:
	_force_izin(student)
```

- Logic constants → a `const` block at the top of the script that owns the
  behaviour (like `RunGrade.gd`'s `WEIGHT_*`). A local `const` inside a
  function also names its number.
- Anything a designer tunes → an `@export` with a `##` line.
- Layout numbers (positions, sizes, margins) → the `.tscn`, not code (the
  authoring guide's "no visual is built at runtime").
- Simulation tuning → `Scripts/Balance.gd`, which a collaborator owns:
  propose the change, never edit it.
- Fine inline: `0`, `1`, `2`, `-1`, `0.5`.

## 3. One job per function ⚙

A function does one thing, and its name says which. Engine callbacks read
like a table of contents:

```gdscript
func _ready() -> void:
	_bind_nodes()
	_apply_visual_exports()
	_populate_roster()
	_start_tutorial_if_needed()
```

Over **50** code lines is a warning sign; over **100** is debt. The ratchet
tracks every function over 50 by name. Split with "extract function": move a
step into its own function named for what it does, change no logic.

## 4. Flat, not nested

Guard clauses and early `return` instead of if-pyramids; `match` for a
switch on an enum or a string.

```gdscript
# Before
func _on_buy_pressed(item: ItemData) -> void:
	if item != null:
		if GameState.player_money >= item.price:
			_buy(item)

# After
func _on_buy_pressed(item: ItemData) -> void:
	if item == null or GameState.player_money < item.price:
		return
	_buy(item)
```

**Repeat an awaiting step with a loop, never recursion.** A coroutine that
calls itself never unwinds; SchoolDay's `_run_day()` overflowed the stack
this way on 2026-08-30.

```gdscript
# Before
func _run_day() -> void:
	await _simulate(current_day)
	current_day += 1
	_run_day()

# After
func _run_week() -> void:
	for day in DAYS_PER_WEEK:
		await _simulate(day)
```

## 5. Don't repeat yourself — the Godot way ⚙

Pick the tool by what repeats:

| Repeats | Becomes | Examples here |
|---|---|---|
| Behaviour **with** visuals | one component scene, instanced where needed (composition first) | `TutorialPanel.tscn`, `StatBar`, `RosterCard` |
| Behaviour **without** visuals | a `class_name` base class, or a static helper | `BaseMinigame`, `Juice`, `AnimUtils` |
| A cross-cutting service | an autoload — and never re-implement one | `UIPolish` already juices every Button |

The ratchet lists every function body (5+ code lines) that is identical in
two or more files; a new one fails.

## 6. Engine logic: signals up, calls down

A child **announces** with a signal and never reaches into its parent; a
parent **calls** its children.

```gdscript
# The row (child): announces, never reaches up.
signal picked(student_id: int)

func _on_pressed() -> void:
	picked.emit(student_id)

# The screen (parent): listens, and calls down.
func _add_row(student: Dictionary) -> void:
	var row: RosterCard = ROW_SCENE.instantiate()
	row.picked.connect(_on_row_picked)
	rows.add_child(row)
	row.setup(student)
```

- Never `get_parent().get_parent()._refresh()`, and never
  `get_node("/root/Lobby/...")` from another screen.
- Take node references once, at the top:
  `@onready var roster: VBoxContainer = %Roster`. Give every node a script
  touches a unique name (`%`), so moving it in the scene does not break the
  script.
- Autoloads are services and state, not a shortcut between screens.
  `GameState` is the only source of truth; do not keep copies of it that go
  stale.

## 7. Type everything ⚙

```gdscript
var count := 0                                  # obviously an int
var students: Array[StudentData] = []
@onready var title: Label = %Title

func gain_for(student: StudentData, category: String) -> float:
	var entry: Dictionary = table[category]     # Variant on the right: name the type
	return float(entry["gain"])
```

Typed GDScript is checked when the script loads (a typo fails at once, not
mid-game), runs faster, and completes better in the editor. Use `:=` only
when the right-hand side's type is obvious. The ratchet counts untyped
`var`s, functions without `->` and untyped parameters. When the count reaches
zero, Godot's own `untyped_declaration` warning gets turned on.

## 8. Comments explain why

- Every script has a `##` file header and every `@export` a `##` line
  (enforced by `tests/test_script_documentation.gd`; the authoring guide's
  "The documentation standard").
- Say *why* — the trap, the constraint, the reason for an odd choice. Do not
  restate what the code says.
- No commented-out code: git remembers it.

## 9. Fail loudly

- A real problem → `push_error()` / `push_warning()`; a programmer mistake
  → `assert()` (stripped from release builds).
- A missing node that means the scene is broken is an error, not a silent
  skip:

```gdscript
var bar := card.get_node_or_null("Mood") as StatBar
if bar == null:
	push_error("StudentCard: the Mood bar is missing from the card scene")
	return
```

- No leftover `print("DEBUG` outside `Scripts/Debug/`
  (`tests/test_project_hygiene.gd`).

## 10. Leave it cleaner (the Boy Scout rule)

A function you touch ends no longer, and no less typed, than you found it.
Name the bare numbers in it while you are there. The ratchet then makes the
improvement permanent.

## What is exempt

- `Scripts/Balance.gd` (collaborator-owned), `addons/`, `-REFERENCE-/`,
  `ci/` — from everything.
- `tests/` — only the legacy-stat-key and misspelled-name rules apply; long
  fixture data is fine, and test files keep their `test_*.gd` names.
- Permanent, reviewed exceptions: `ci/clean_code_allowed.gd`.

Formatting is not ratcheted: match the file (tabs; the GDScript style
guide's spacing).
````

- [ ] **Step 2: Move three passages out of `CLAUDE.md`** (it is 24,149 characters; the budget is 23,000). Use the Edit tool with these exact strings.

(a) In `CLAUDE.md`, replace the whole paragraph that begins `**Illustration plates wear one of two materials.** Cutouts take` and ends `Lobby's \`World\` CanvasLayer, and UI stays on layer 0, out of the glow.` with:

```markdown
**Illustration plates wear one of two materials** (cutout or backdrop,
pinned by `tests/test_illustration_ao.gd`); which, the Lobby's lighting and
live tuning: `style-guide.md`, "Illustration materials".
```
and paste the removed paragraph, unchanged, into `docs/superpowers/design/style-guide.md` as a new section inserted immediately before `## Swapping fonts`:

```markdown
## Illustration materials

<the removed paragraph, verbatim>
```

(b) In item **4**, replace the sentence run that begins `Gotchas: \`anchors_preset\` is inert (set the four anchors),` and ends `so draw from a child (authoring guide, Pattern C).` with:

```markdown
Node gotchas (anchors, z-order, `layout_mode`): authoring guide, "Editor and
game recipes".
```
and add the removed text to `docs/superpowers/design/authoring-guide.md`'s `## Editor and game recipes`, after the "Clicking, when you must." paragraph, as:

```markdown
**MCP node gotchas.** <the removed text, verbatim, starting at "`anchors_preset` is inert">
```

(c) Replace the paragraph that begins `That tab also carries **🎭 Gladi Resik Akhir Kelas**: one-click rehearsals of` and ends `clears the roster on its way out.` with:

```markdown
That tab also carries **🎭 Gladi Resik Akhir Kelas**, end-of-grade
rehearsals: authoring guide, "Editor and game recipes".
```
and add the removed paragraph to the same authoring-guide section, after the gotchas, prefixed `**End-of-grade rehearsals.** The debug overlay's Scenes tab carries` in place of `That tab also carries`.

- [ ] **Step 3: Add the pointer and the in-flight note to `CLAUDE.md`.** In `## Conventions`, insert before `- **No emoji as UI iconography.**`:

```markdown
- **Clean code:** `docs/superpowers/design/clean-code.md`. `tests/test_clean_code.gd`
  and CI's `project_check` ratchet it: counts only go down; lock in a gain
  with `ci/clean_code_dump.gd`.
```
Replace `Nothing in flight (parked passes are in \`docs/superpowers/DEBT.md\`).` with:

```markdown
Clean-code pass (`docs/superpowers/specs/2026-09-26-clean-code-design.md`):
PR2 file renames, then PR3 stat keys.
```

- [ ] **Step 4: Check the budget.** `python -c "print(len(open('CLAUDE.md',encoding='utf-8').read()))"` from `<wt>` must print a number ≤ 23,000. If it is over, shorten only the lines this task added (never a live rule) until it fits.

- [ ] **Step 5: Record the remaining debt.** In `docs/superpowers/DEBT.md`, add under `## Deferred and pending` the entry below, filling each `<N>` from `<scratch>/pr1_summary.txt` (in order: the `untyped` total, the `bare_numbers` total, the `long_functions` entries, the `large_scripts` entries, the `duplicate_groups` entries):

```markdown
**Clean-code ratchet debt** (`ci/clean_code_baseline.gd`, 2026-09-26): <N>
untyped declarations, <N> bare numbers, <N> functions over 50 code lines,
<N> large scripts, <N> duplicate groups. Phase 2 (PR4 one `TutorialGuide`,
PR5 the other duplicates) and Phase 3 (splitting long functions) of
`docs/superpowers/specs/2026-09-26-clean-code-design.md` are planned; the
rest shrinks as code is touched (`clean-code.md` rule 10). Decomposing
`SchoolDay.gd` into components is its own project.
```

- [ ] **Step 6: Changelog.** Add at the top of `docs/superpowers/CHANGELOG.md` (below the intro, above `## 2026-09-25`):

```markdown
## 2026-09-26 — Clean-code rules and ratchet (PR1 of the clean-code pass)

- **Rulebook:** `docs/superpowers/design/clean-code.md` translates Codacy's
  clean-code principles to GDScript and Godot. Spec:
  `docs/superpowers/specs/2026-09-26-clean-code-design.md`.
- **Ratchet:** `ci/clean_code_scan.gd` measures long functions, untyped
  declarations, bare numbers, duplicate bodies and large scripts, plus six
  must-be-zero rules (file names, class_name/file match, asset names,
  misspellings, exact-case `res://` literals, legacy stat keys). Frozen in
  the generated `ci/clean_code_baseline.gd`; exceptions in
  `ci/clean_code_allowed.gd`. `tests/test_clean_code.gd` fails on growth and
  on an un-locked shrink; `ci/project_check.gd` fails CI on growth and only
  warns on a shrink.
- **Selftest:** `ci/selftest_project_check.sh`'s broken fixtures moved to the
  project root and each fail case must print its own reason.
- **CLAUDE.md** back under budget: the illustration-materials paragraph moved
  to `style-guide.md`; the MCP node gotchas and the end-of-grade rehearsal
  note to the authoring guide.
```

- [ ] **Step 7: Commit** (`docs(clean-code): rulebook, CLAUDE.md pointer and budget, debt and changelog`), files `docs/superpowers/design/clean-code.md CLAUDE.md docs/superpowers/design/style-guide.md docs/superpowers/design/authoring-guide.md docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md docs/superpowers/plans/2026-09-26-clean-code-phase1.md`.

---

### Task 6: PR1 — verify, review, ship

- [ ] **Step 1:** Procedure R with targeted suites `clean_code`, `project_check`, `project_hygiene`, `script_documentation`, `viewport_editability`. Spec sections for the reviewer: 1, 2, 6. Tasks: 1–6. PR1 allow-list: the files in "File structure (PR1)" plus this plan and the spec, and the `.uid` sidecars of the new scripts.
- [ ] **Step 2:** Update `CLAUDE.md`'s `## Testing` count line (`160 suites, 2340 tests (2026-09-26)`) to R3's numbers, re-check the budget (Task 5 Step 4), commit `docs: suite count after the clean-code ratchet`, and re-run R1 for `clean_code` only.
- [ ] **Step 3:** Procedure S. Collaborator note for S3:

```text
Heads-up: PR "<title>" adds a clean-code ratchet (rules in
docs/superpowers/design/clean-code.md). From now on GitHub's project-check
fails a PR that adds a function over 50 lines, a bare number, an untyped
variable, a duplicated function body, a snake_case script/scene name, a
misspelled file name or a res:// path with the wrong case. Improvements only
print a WARNING in CI. Balance.gd is exempt. Next up: a PR that renames
files (loby -> Lobby, koprasi -> Koperasi, snake_case -> PascalCase); please
close Godot before pulling it.
```

---

# PR2 — file renames (branch `chore/clean-code-renames`, worktree `.claude/worktrees/clean-code-renames`)

Starts only after PR1 has merged into `Textures`.

### Task 7: Scripted renames, deletions and reference rewrite

**Files:**
- Create (outside the repo): `<scratch>/pr2_rename.py`
- Move/delete: the spec's section 3 list (encoded in the script below)
- Modify: every live text file that names a moved file; `CLAUDE.md`; `docs/superpowers/DEBT.md`

- [ ] **Step 1: Create the worktree.** From PowerShell: `git -C "<main>" fetch -q origin`, then `git -C "<main>" worktree add -b chore/clean-code-renames "<main>\.claude\worktrees\clean-code-renames" origin/Textures`. Confirm `git -C "<wt>" log --oneline -1` is the PR1 merge or later, and that `ci/clean_code_scan.gd` exists. Run Procedure E1 only (seed the cache); **do not launch the editor yet**.

- [ ] **Step 2: Save the pre-rename summary** (editor closed):

```powershell
& "<console>" --headless --path "<wt>" --script res://ci/clean_code_dump.gd > "<scratch>\pr2_before.txt"
git -C "<wt>" diff --stat -- ci/clean_code_baseline.gd
git -C "<wt>" checkout -- ci/clean_code_baseline.gd
```
If the `diff --stat` line printed anything, the baseline on `Textures` is stale (a hand merge changed a count): stop, and fix that first in its own commit — for a shrink regenerate it, for a growth see the rulebook's "`Textures` went red" bullet. Otherwise the checkout just undoes the dump's identical rewrite.

- [ ] **Step 3: Write the script.** Create `<scratch>/pr2_rename.py`:

```python
#!/usr/bin/env python3
"""Clean-code PR2: file renames, junk deletions and reference rewrites.

Run with the PR2 worktree's Godot editor CLOSED:
    python pr2_rename.py check  <state.json> <worktree>
    python pr2_rename.py apply  <state.json> <worktree>
    (then: <console> --headless --path <worktree> --import, then the dump tool)
    python pr2_rename.py verify <state.json> <worktree>

check  -- preconditions only; changes nothing.
apply  -- git mv / git rm, rewrites references in live text files, and saves
          each moved file's uid and .import settings to <state.json>.
verify -- after the reimport: every uid survived, every .import differs only
          in path-derived lines, and no old name is left in live text.
"""
import json
import os
import re
import subprocess
import sys

RENAMES = [
    ("Scripts/Lobby/loby.gd", "Scripts/Lobby/Lobby.gd"),
    ("Scenes/Lobby/loby.tscn", "Scenes/Lobby/Lobby.tscn"),
    ("Scripts/Koperasi/koprasi.gd", "Scripts/Koperasi/Koperasi.gd"),
    ("Scenes/Koperasi/koprasi.tscn", "Scenes/Koperasi/Koperasi.tscn"),
    ("Scripts/Koperasi/rakbarang_1.gd", "Scripts/Koperasi/KoperasiStage.gd"),
    ("Scripts/Achievements/achievements_screen.gd", "Scripts/Achievements/AchievementsScreen.gd"),
    ("Scenes/Achievements/achievements.tscn", "Scenes/Achievements/AchievementsScreen.tscn"),
    ("Scripts/AturJadwal/atur_jadwal.gd", "Scripts/AturJadwal/AturJadwal.gd"),
    ("Scenes/AturJadwal/atur_jadwal.tscn", "Scenes/AturJadwal/AturJadwal.tscn"),
    ("Scripts/StudentCard/student_card.gd", "Scripts/StudentCard/StudentCard.gd"),
    ("Scenes/StudentCard/student_card.tscn", "Scenes/StudentCard/StudentCard.tscn"),
    ("Scripts/StudentList/student_list.gd", "Scripts/StudentList/StudentList.gd"),
    ("Scenes/StudentList/student_list.tscn", "Scenes/StudentList/StudentList.tscn"),
    ("Scripts/ReportCard/report_card.gd", "Scripts/ReportCard/ReportCard.gd"),
    ("Scenes/ReportCard/report_card.tscn", "Scenes/ReportCard/ReportCard.tscn"),
    ("Scripts/LevelSelect/level_select.gd", "Scripts/LevelSelect/LevelSelect.gd"),
    ("Scenes/LevelSelect/level_select.tscn", "Scenes/LevelSelect/LevelSelect.tscn"),
    ("Scripts/MainMenu/main_menu.gd", "Scripts/MainMenu/MainMenu.gd"),
    ("Scenes/MainMenu/main_menu.tscn", "Scenes/MainMenu/MainMenu.tscn"),
    ("Scripts/CutScene/cut_scene.gd", "Scripts/CutScene/CutScene.gd"),
    ("Scenes/CutScene/cut_scene.tscn", "Scenes/CutScene/CutScene.tscn"),
    ("Scripts/CutScene/hint_label.gd", "Scripts/CutScene/HintLabel.gd"),
    ("Scripts/Koperasi/cosmetic_shop.gd", "Scripts/Koperasi/CosmeticShop.gd"),
    ("Scripts/Koperasi/shop_hub.gd", "Scripts/Koperasi/ShopHub.gd"),
    ("Scripts/Koperasi/shop_hub_tile.gd", "Scripts/Koperasi/ShopHubTile.gd"),
    ("Scripts/StudentCard/tutorial_step.gd", "Scripts/StudentCard/TutorialStepData.gd"),
    ("Scenes/Audio/audio_director.tscn", "Scenes/Audio/AudioDirector.tscn"),
    ("Scripts/Inventory/inventory.gd", "Scripts/Inventory/Inventory.gd"),
    ("Scenes/Inventory/inventory.tscn", "Scenes/Inventory/Inventory.tscn"),
    ("Scripts/Transition/transition.gd", "Scripts/Transition/Transition.gd"),
    ("Scenes/Transition/transition.tscn", "Scenes/Transition/Transition.tscn"),
    ("Scripts/Splashscreen/splashscreen.gd", "Scripts/Splashscreen/Splashscreen.gd"),
    ("Assets/Audio/BGM/loby_song1.mp3", "Assets/Audio/BGM/lobby_song1.mp3"),
    ("Assets/Audio/BGM/loby_song2.mp3", "Assets/Audio/BGM/lobby_song2.mp3"),
    ("Assets/Audio/BGM/loby_song3.mp3", "Assets/Audio/BGM/lobby_song3.mp3"),
    ("Assets/Audio/BGM/loby_song4.mp3", "Assets/Audio/BGM/lobby_song4.mp3"),
    ("Assets/Images/UI/loby.png", "Assets/Images/UI/lobby.png"),
    ("Assets/Images/UI/loby_no_tables.png", "Assets/Images/UI/lobby_no_tables.png"),
    ("Assets/Images/MuridPotrait/Meja/kanan atas.png", "Assets/Images/MuridPotrait/Meja/kanan_atas.png"),
    ("Assets/Images/MuridPotrait/Meja/kanan bawah.png", "Assets/Images/MuridPotrait/Meja/kanan_bawah.png"),
    ("Assets/Images/MuridPotrait/Meja/kiri atas.png", "Assets/Images/MuridPotrait/Meja/kiri_atas.png"),
    ("Assets/Images/MuridPotrait/Meja/kiri bawah.png", "Assets/Images/MuridPotrait/Meja/kiri_bawah.png"),
    ("Assets/Images/Shop/ItemRak/bank soal.png", "Assets/Images/Shop/ItemRak/bank_soal.png"),
    ("Assets/Images/Shop/ItemRak/lompat tali.png", "Assets/Images/Shop/ItemRak/lompat_tali.png"),
    ("Assets/Images/Shop/ItemRak/pop es.png", "Assets/Images/Shop/ItemRak/pop_es.png"),
    ("Assets/Images/UI/pngwing.com (3).png", "Assets/Images/UI/stamp_original.png"),
]
# Applied after RENAMES, so the Meja files above move with their folder.
FOLDER_RENAMES = [("Assets/Images/MuridPotrait", "Assets/Images/MuridPortrait")]
DELETIONS = [
    "Scripts/Inventory/item_database.tscn",
    "Assets/Images/Shop/pngwing.com (2).png",
    "Assets/Images/Shop/pngwing.com (6).png",
    "Assets/Images/UI/pngwing.com (2).png",
    "Assets/Images/UI/pngwing.com (4).png",
    "Assets/Images/UI/pngwing.com (5).png",
    "Assets/Images/UI/Desain tanpa judul.png",
    "Assets/Images/UI/Screenshot 2026-08-02 104848.png",
    "Assets/Images/UI/\u2014Pngtree\u2014book icon vector_4358423.png",
    "Assets/Images/UI/Placeholders/Loby.png",
    "Assets/Images/Shop/rak 1.jpg",
    "Assets/Images/Shop/rak2.jpg",
]
# Words replaced everywhere in live text: the folder name, and mentions of the
# BGM and backdrop files without their extension.
STEMS = [("MuridPotrait", "MuridPortrait"), ("loby_song", "lobby_song"),
         ("loby_no_tables", "lobby_no_tables")]
TEXT_EXTS = {".gd", ".tscn", ".tres", ".godot", ".gdshader", ".md", ".cfg",
             ".sh", ".json", ".txt"}
# A reference that would keep a deletion alive lives in one of these.
CODE_EXTS = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".json"}
SKIP_PREFIXES = ("-REFERENCE-/", "addons/", ".github/", "docs/superpowers/specs/",
                 "docs/superpowers/plans/", "docs/superpowers/handover/",
                 "docs/superpowers/mockups/", "docs/superpowers/baseline/")
# Balance.gd is collaborator-owned: its comments naming old files are
# proposed to its owner, never rewritten here. The baseline is generated: it
# names the junk files, and Step 7's dump rewrites it from the renamed tree.
SKIP_FILES = {"docs/superpowers/CHANGELOG.md", "Scripts/Balance.gd",
              "ci/clean_code_baseline.gd"}
PATH_DERIVED = ("path", "source_file=", "dest_files=")
IDENT = "A-Za-z0-9_"


def git(*args):
    return subprocess.run(["git", "-c", "core.quotepath=false", *args], check=True,
                          capture_output=True, text=True, encoding="utf-8").stdout


def tracked():
    return [p for p in git("ls-files", "-z").split("\0") if p]


def read(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8")


def write(path, text):
    with open(path, "wb") as f:
        f.write(text.encode("utf-8"))


def live_text_files(exts=TEXT_EXTS):
    out = []
    for p in tracked():
        if p.startswith(SKIP_PREFIXES) or p in SKIP_FILES:
            continue
        if os.path.splitext(p)[1] in exts and os.path.isfile(p):
            out.append(p)
    return out


def texts(exts=TEXT_EXTS):
    out = {}
    for p in live_text_files(exts):
        try:
            out[p] = read(p)
        except UnicodeDecodeError:
            pass
    return out


def uid_of(path):
    """The uid Godot keeps for `path`: .uid sidecar, .import [remap], or scene header."""
    if os.path.exists(path + ".uid"):
        return read(path + ".uid").strip()
    if os.path.exists(path + ".import"):
        m = re.search(r'^uid="(uid://[a-z0-9]+)"', read(path + ".import"), re.M)
        return m.group(1) if m else None
    if path.endswith((".tscn", ".tres")):
        m = re.search(r'uid="(uid://[a-z0-9]+)"', read(path).split("\n", 1)[0])
        return m.group(1) if m else None
    return None


def import_settings(path):
    """The .import text without the lines that derive from the file's path."""
    if not os.path.exists(path + ".import"):
        return None
    return "\n".join(l for l in read(path + ".import").split("\n")
                     if not l.startswith(PATH_DERIVED))


def final_path(p):
    for old, new in RENAMES:
        if p == old:
            p = new
            break
    for old, new in FOLDER_RENAMES:
        if p.startswith(old + "/"):
            p = new + p[len(old):]
    return p


def moved_files():
    """(old, new) for every tracked file the renames move, sidecars excluded."""
    pairs = []
    for p in tracked():
        if p.endswith((".import", ".uid")):
            continue
        q = final_path(p)
        if q != p:
            pairs.append((p, q))
    return pairs


def word_rx(word):
    return re.compile(rf"(?<![{IDENT}]){re.escape(word)}(?![{IDENT}])")


def replacements():
    """(regex, replacement), most specific first: full paths, base names, stems."""
    pairs = [(word_rx(old), new) for old, new in RENAMES]
    for old, new in RENAMES:
        ob, nb = os.path.basename(old), os.path.basename(new)
        if ob != nb:
            pairs.append((word_rx(ob), nb))
    pairs += [(re.compile(re.escape(old)), new) for old, new in STEMS]
    return pairs


def leftover_patterns():
    words = {os.path.basename(old) for old, _ in RENAMES}
    words |= {os.path.basename(v) for v in DELETIONS}
    pats = [(w, word_rx(w)) for w in sorted(words)]
    pats += [(old, re.compile(re.escape(old))) for old, _ in STEMS]
    return pats


def check():
    problems = []
    if git("status", "--porcelain", "--untracked-files=no").strip():
        problems.append("the worktree has uncommitted changes")
    files = set(tracked())
    for old, new in RENAMES:
        if old not in files:
            problems.append(f"missing: {old}")
        if new in files and old.lower() != new.lower():
            problems.append(f"target exists: {new}")
        base = os.path.basename(old)
        same = [f for f in files if os.path.basename(f) == base and not f.startswith(SKIP_PREFIXES)]
        if len(same) != 1:
            problems.append(f"base name {base} is not unique: {same}")
    for old, _ in FOLDER_RENAMES:
        if not any(f.startswith(old + "/") for f in files):
            problems.append(f"missing folder: {old}")
    code = texts(CODE_EXTS)
    for victim in DELETIONS:
        if victim not in files:
            problems.append(f"missing deletion target: {victim}")
            continue
        needles = [victim] + ([uid_of(victim)] if uid_of(victim) else [])
        for p, t in code.items():
            if p in (victim, victim + ".import"):
                continue
            for n in needles:
                if n in t:
                    problems.append(f"{victim} is still referenced by {p} ({n})")
    for p in problems:
        print("PROBLEM:", p)
    print(f"{len(RENAMES)} renames, {len(FOLDER_RENAMES)} folder rename, "
          f"{len(DELETIONS)} deletions, {len(moved_files())} files move")
    return not problems


def git_mv(old, new):
    if old.lower() == new.lower():
        git("mv", old, new + ".case_tmp")
        git("mv", new + ".case_tmp", new)
    else:
        git("mv", old, new)


def apply(state_path):
    if not check():
        sys.exit("check failed; nothing changed")
    state = {new: {"old": old, "uid": uid_of(old), "import": import_settings(old)}
             for old, new in moved_files()}
    for victim in DELETIONS:
        git("rm", "-q", victim)
        if os.path.exists(victim + ".import"):
            git("rm", "-q", victim + ".import")
    for old, new in RENAMES:
        git_mv(old, new)
        for side in (".uid", ".import"):
            if os.path.exists(old + side):
                git_mv(old + side, new + side)
    for old, new in FOLDER_RENAMES:
        git_mv(old, new)
    pairs = replacements()
    changed = 0
    for p, text in texts().items():
        new_text = text
        for rx, rep in pairs:
            new_text = rx.sub(lambda m, rep=rep: rep, new_text)
        if new_text != text:
            write(p, new_text)
            changed += 1
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=1, ensure_ascii=False)
    print(f"moved {len(state)} files, deleted {len(DELETIONS)}, rewrote {changed} text files")


def verify(state_path):
    with open(state_path, encoding="utf-8") as f:
        state = json.load(f)
    problems = []
    for new, info in state.items():
        if not os.path.exists(new):
            problems.append(f"missing after rename: {new}")
            continue
        if info["old"].lower() != new.lower() and os.path.exists(info["old"]):
            problems.append(f"old path still on disk: {info['old']}")
        if uid_of(new) != info["uid"]:
            problems.append(f"uid changed for {new}: {info['uid']} -> {uid_of(new)}")
        if info["import"] is not None and import_settings(new) != info["import"]:
            problems.append(f".import settings changed for {new}")
    for p, text in texts().items():
        for word, rx in leftover_patterns():
            if rx.search(text):
                problems.append(f"{p} still mentions {word}")
    for p in problems:
        print("PROBLEM:", p)
    print("verify:", "OK" if not problems else f"{len(problems)} problem(s)")
    return not problems


if __name__ == "__main__":
    mode, state_file = sys.argv[1], os.path.abspath(sys.argv[2])
    os.chdir(sys.argv[3])
    ok = {"check": lambda: check(), "apply": lambda: apply(state_file) or True,
          "verify": lambda: verify(state_file)}[mode]()
    sys.exit(0 if ok else 1)
```

- [ ] **Step 4: Dry run.** Confirm no Godot process has `<wt>` open (PowerShell: `Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Where-Object { $_.CommandLine -like "*clean-code-renames*" }` prints nothing). `python "<scratch>/pr2_rename.py" check "<scratch>/pr2_state.json" "<wt>"`. Expected: no `PROBLEM:` lines; `46 renames, 1 folder rename, 12 deletions, <N> files move` (N ≈ 46 + the MuridPotrait folder's files). A `PROBLEM` means `Textures` changed since the spec: update the lists (and tell the reviewer), never force past it.

- [ ] **Step 5: Hand-edit what must not be rewritten mechanically** (before `apply`, so the script leaves these lines alone):
  - `CLAUDE.md` `## Conventions`: replace
    ```markdown
    - File naming is inconsistent (`loby.gd`, `koprasi.gd` are misspelled but
      load-bearing — do not "fix" them).
    ```
    with
    ```markdown
    - **File names:** PascalCase `.gd`/`.tscn`; assets `A–Z a–z 0–9 _ - .`
      only (`clean-code.md` rule 1).
    ```
  - `docs/superpowers/DEBT.md`, the "Koperasi leftovers after the 2026-09-17 counter revamp" entry: delete the sentence about `rak 1.jpg`/`rak2.jpg` and change `Delete the two JPGs, the variation and that test together, then rebake.` to `Delete the variation and that test together, then rebake.`
  - `docs/superpowers/DEBT.md`, the entry headed `**The remaining \`pngwing.com\` stock files want replacing (2026-09-22).**`: replace the whole entry (through `Replace them with authored art before any release.`) with:
    ```markdown
    **Stock art still to replace (2026-09-22).** `pngwing.com (1).png` went
    with the back-button pass, which was a licensing tidy-up as well as a
    visual one: the filename was verbatim from a free-PNG aggregator, the
    project records no licence for it, and most of that catalogue is
    non-commercial. The clean-code renames deleted the unused copies and
    renamed the last live one to `Assets/Images/UI/stamp_original.png` (the
    approval stamp at `StudentCard.tscn:14`); it is still that unlicensed
    stock image. Replace it with authored art before any release.
    ```
  - Four tests guard against junk files the script deletes. Once a file is gone, any reference to it already fails `project_check`'s missing-dependency check and the exact-case path rule, so the guards go (they would otherwise keep naming deleted files):
    - `tests/test_koperasi_tray.gd`: delete the two-line assertion `assert_false(shop.contains("pngwing.com (6).png") or tray.contains("pngwing.com (6).png"),` / `"the black basket silhouette should no longer be referenced")`.
    - `tests/test_lobby.gd`: delete the whole `test_the_off_palette_chip_art_is_gone()` function (its only assertion names `Desain tanpa judul.png`) and one of the two blank lines around it.
    - `tests/test_koperasi_shop_layout.gd`: in `test_the_old_landing_is_gone()`, change `["KEBUTUHAN SEKOLAH", "ShopShelfButton", "Illustration4.jpg", "rak2.jpg"]` to `["KEBUTUHAN SEKOLAH", "ShopShelfButton", "Illustration4.jpg"]`.
    - `tests/test_atur_jadwal.gd`: change the comment `## The warning dialog shipped on a stock placeholder ("pngwing.com (2).png").` to `## The warning dialog shipped on a stock placeholder image.`
  - Commit these edits first (`docs: drop the misspelling rule and the junk-file guards ahead of the renames`), so `check` sees a clean tree.

- [ ] **Step 6: Apply.** `python "<scratch>/pr2_rename.py" apply "<scratch>/pr2_state.json" "<wt>"`. Expected: `moved <N> files, deleted 12, rewrote <M> text files`. Then `git -C "<wt>" status --short | head -50` shows `R` renames, `D` deletions, `M` rewrites.

- [ ] **Step 7: Reimport, then regenerate the baseline** (editor still closed):

```powershell
& "<console>" --headless --path "<wt>" --import
& "<console>" --headless --path "<wt>" --script res://ci/clean_code_dump.gd > "<scratch>\pr2_after.txt"
```

- [ ] **Step 8: Verify.** `python "<scratch>/pr2_rename.py" verify "<scratch>/pr2_state.json" "<wt>"` → `verify: OK`. Fix each `PROBLEM` by hand (a live doc mention the patterns could not rewrite, e.g. a sentence) and re-run until OK. Then compare the summaries: in `<scratch>\pr2_after.txt` versus `pr2_before.txt`, `long_functions`, `untyped`, `bare_numbers`, `duplicate_groups`, `large_scripts` and `legacy_stat_keys` must show the **same** entry counts and totals; `bad_script_names`, `class_name_mismatches`, `bad_asset_names`, `misspelled_names` and `unresolved_paths` must be `0 entries`. Then `git -C "<wt>" status --short -- '*.import'` must list only moved/deleted assets' `.import` files: revert any other (`git checkout -- <path>`). Finally, read the two negative source-scan assertions the rewrite touched, `tests/test_inventory.gd` (`assert_false(src.contains("Koperasi.tscn"), …)`) and `tests/test_exam_progress.gd` (`assert_false(src.contains("CutScene.tscn"), …)`): each must now name the renamed file, so it still tests that the screen does not route there.

- [ ] **Step 9: Commit.** First: `CLAUDE.md` ≤ 23,000 characters (`python -c "print(len(open(r'<wt>\CLAUDE.md',encoding='utf-8').read()))"`); and `git -C "<wt>" status --short` shows nothing outside this task's renames, deletions and rewrites — revert `Assets/Audio/default_bus_layout.tres`, `Assets/Theme/kejartes_theme.tres` or any other stray rewrite with `git checkout --`. Then `git -C "<wt>" add -A -- . ':!addons/godot_ai/utils/update_activation_runner.gd' ':!addons/godot_ai/utils/update_activation_runner.gd.uid'` and `git -C "<wt>" commit -F <scratch>/msg.txt` (`refactor: PascalCase scripts and scenes, fix misspelled and junk file names`). After committing, `git -C "<wt>" -c core.quotepath=false diff -M --stat --diff-filter=AD HEAD~1 -- . ":(exclude)*.import"` must list only 12 deletions: every other file is a rename or an edit. Expected quirk: `UI/Placeholders/Loby.png` is byte-identical to `UI/loby.png`, so git pairs `Placeholders/Loby.png` with `lobby.png` as the rename and lists `Assets/Images/UI/loby.png` as the deletion — the count is what matters. (`.import` files are excluded because a small one, like `loby_song1.mp3.import`, changes too much on reimport for git to pair it as a rename; Step 8's `verify` already proved each changed only in path-derived lines.) Body: the spec's section 3 summary and "Renames only: every moved file keeps its uid; references rewritten by path, base name and folder stem."

### Task 8: PR2 — changelog, verify, review, ship

- [ ] **Step 1: Changelog** entry at the top of `docs/superpowers/CHANGELOG.md`:

```markdown
## 2026-09-26 — File names tidied (PR2 of the clean-code pass)

- 19 snake_case scripts and 13 scenes renamed to PascalCase, among them the
  misspelled `loby` → `Lobby` and `koprasi` → `Koperasi`; `rakbarang_1.gd` →
  `KoperasiStage.gd`, `tutorial_step.gd` → `TutorialStepData.gd` (its
  `class_name`). The main scene is now `Scenes/MainMenu/MainMenu.tscn`.
- Assets: `MuridPotrait/` → `MuridPortrait/`; `loby_song1–4.mp3`,
  `loby.png`, `loby_no_tables.png` → `lobby…`; spaces → underscores;
  `pngwing.com (3).png` → `stamp_original.png`. Twelve unreferenced junk
  files deleted (recoverable from git).
- Every uid kept; the scan's name, spelling and exact-case path rules are
  now empty and stay that way.
```
Commit (`docs: changelog for the file renames`).

- [ ] **Step 2:** Launch the editor (E2, E3). E4 is not needed (fresh boot). Procedure R with targeted suites `clean_code`, `project_check`, `project_hygiene`, `viewport_editability`, `boot_screens`, `main_menu`, `transition`, `lobby`, `koperasi`, `inventory`, `atur_jadwal`, `student_card`, `student_list`, `report_card`, `level_select`, `cutscene`, `audio_director`, `shop_hub`, `student_skins`, `achievement_screen` (a suite's name is its `suite_name()`; check with `git grep -A1 "func suite_name" tests/test_<x>.gd`). Before R3, open `Scenes/MainMenu/MainMenu.tscn` in the editor (some suites want the main scene open) and `logs_read(source="editor", session_id=<sid>)` must show no missing-resource errors. Reviewer: spec sections 2, 3, 6; tasks 7–8. PR2 allow-list: the spec's section 3 "What PR2 may contain" list, plus the four obsolete junk-file guards removed in Task 7 Step 5.
- [ ] **Step 3:** Procedure S. Collaborator note:

```text
Heads-up: PR "<title>" renames files: loby -> Lobby, koprasi -> Koperasi,
MuridPotrait -> MuridPortrait, and every snake_case script/scene to
PascalCase (main scene: Scenes/MainMenu/MainMenu.tscn). Every uid is kept.
Before pulling it: close Godot WITHOUT saving, pull, then reopen, and run
`git status` -- an editor left open re-saves old-name files. If you have an
open branch, merge Textures into it; git follows the renames, but check any
new res:// path you added still resolves (CI's project-check now fails on a
path with the wrong case). Balance.gd was not touched; its comments on lines 7
and 59 still say atur_jadwal.gd -- could you change them to AturJadwal.gd?
```

---

# PR3 — stat-key rename (branch `chore/clean-code-stat-keys`, worktree `.claude/worktrees/clean-code-stat-keys`)

Starts only after PR2 has merged into `Textures`.

### Task 9: Hand edits that a mechanical rename would garble

**Files:**
- Modify: `Scripts/GameState.gd`, `Scripts/UI/StatInfo.gd`, `Scripts/Inventory/ApplyStudentRow.gd`, `Scripts/Debug/DebugManager.gd`, `tests/test_use_item_on_students.gd`, `tests/test_report_card.gd`

- [ ] **Step 1: Create the worktree** (as Task 7 Step 1, branch `chore/clean-code-stat-keys`, path `<main>\.claude\worktrees\clean-code-stat-keys`), then E1 only — editor stays closed until Task 10 Step 5.

- [ ] **Step 2: Edit comments and code whose words the token table would garble.** With the Edit tool (exact strings):

`Scripts/GameState.gd` header — replace
```gdscript
## The trap: `approved_students` holds Array[Dictionary] whose keys are the
## UI's names -- `akademis1/2/3` are academic/seni/olahraga, and
## `kepribadian1/2` are mood/energy. StudentData, used inside the
## simulation, has real field names instead. convert_to_student_data_array()
## bridges in and StudentManager.write_back_to_gamestate() bridges out. The
## two namings do not line up, and that mismatch is the most common source
## of bugs here.
```
with
```gdscript
## The roster: `approved_students` holds Array[Dictionary] whose stat keys
## (`akademis`, `seni_budaya`, `olahraga`, `mood`, `energy`) are the same
## names as StudentData's fields. convert_to_student_data_array() bridges in
## and StudentManager.write_back_to_gamestate() bridges out.
```

`Scripts/GameState.gd`, `use_item()`'s doc — replace
```gdscript
## so that is what gets written. Writes the CANONICAL roster keys the
## simulation reads: kepribadian1 (mood), kepribadian2 (energy),
## akademis1/2/3 (the three skills) — never the dead "mood"/"energy" keys.
```
with
```gdscript
## so that is what gets written: the roster keys `mood`, `energy`,
## `akademis`, `seni_budaya` and `olahraga`, the names StudentData uses.
```

`Scripts/UI/StatInfo.gd` — replace
```gdscript
## Naming trap, and the reason `data_key` exists: the bar node is called
## "Akademis2" but the GameState dictionary key is "akademis2" and it holds
## seni_budaya. Never index a student dictionary with a bar name.
```
with
```gdscript
## Why `data_key` exists: a bar node is named in PascalCase (`SeniBudaya`),
## its GameState dictionary key in snake_case (`seni_budaya`). Never index a
## student dictionary with a bar name.
```

`Scripts/Inventory/ApplyStudentRow.gd` — the translation table is about to become an identity map, so delete it. Replace
```gdscript
## Logical boost name -> the roster Dictionary key it writes. Fixed mapping:
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy (the project's canonical keys).
const KEY := {
	"akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
	"mood": "kepribadian1", "energy": "kepribadian2",
}

## kepribadian2 (energy) at or below this forces "Izin" -- such a student
```
with
```gdscript
## Energy at or below this forces "Izin" -- such a student
```
and replace `		var cur := float(student.get(KEY[key], 0.0))` with `		var cur := float(student.get(key, 0.0))` (a boost name is now the roster key). Then `git grep -n -w KEY -- Scripts/Inventory/ApplyStudentRow.gd` must print nothing.

`Scripts/Debug/DebugManager.gd` — replace
```gdscript
func _get_student_resource_value(s: StudentData, key: String) -> float:
	match key:
		"akademis1": return s.akademis
		"akademis2": return s.seni_budaya
		"akademis3": return s.olahraga
		"kepribadian2": return s.energy
		"kepribadian1": return s.mood
	return 50.0

func _set_student_resource_value(s: StudentData, key: String, val: float) -> void:
	match key:
		"akademis1": s.akademis = val
		"akademis2": s.seni_budaya = val
		"akademis3": s.olahraga = val
		"kepribadian2": s.energy = val
		"kepribadian1": s.mood = val
```
with
```gdscript
## The StudentData stat fields the stat editor reads and writes; each is also
## the roster Dictionary key of the same name.
const STAT_FIELDS: PackedStringArray = ["akademis", "seni_budaya", "olahraga", "mood", "energy"]

func _get_student_resource_value(s: StudentData, key: String) -> float:
	return float(s.get(key)) if STAT_FIELDS.has(key) else 50.0

func _set_student_resource_value(s: StudentData, key: String, val: float) -> void:
	if STAT_FIELDS.has(key):
		s.set(key, val)
```

`tests/test_use_item_on_students.gd` — replace
```gdscript
	assert_eq(GameState.approved_students[0]["kepribadian1"], 60.0, "mood -> kepribadian1")
	assert_eq(GameState.approved_students[0]["kepribadian2"], 55.0, "energy -> kepribadian2")
	assert_eq(GameState.approved_students[0]["akademis1"], 46.0, "akademis -> akademis1")
	assert_false(GameState.approved_students[0].has("mood"), "no dead mood key written")
```
with
```gdscript
	assert_eq(GameState.approved_students[0]["mood"], 60.0, "mood lands on the mood key")
	assert_eq(GameState.approved_students[0]["energy"], 55.0, "energy lands on the energy key")
	assert_eq(GameState.approved_students[0]["akademis"], 46.0, "akademis lands on the akademis key")
```

`tests/test_report_card.gd` — replace
```gdscript
	for dead in ["\"Nama\"", "\"Profil\"", "\"Kepribadian\",", "\"Akademis\","]:
```
with
```gdscript
	# "Akademis" is not a dead name any more: since the stat-key rename it is
	# the academic stat bar's node.
	for dead in ["\"Nama\"", "\"Profil\"", "\"Kepribadian\","]:
```

- [ ] **Step 3: Commit** (`refactor(stats): rewrite the naming-trap docs and drop the key translation tables`) — the tree still uses the old keys elsewhere, so no tests are run on this intermediate commit; Task 10 finishes the rename before any test run.

### Task 10: Token rename, garble sweep, docs

**Files:**
- Create (outside the repo): `<scratch>/pr3_stat_keys.py`
- Modify: every `.gd`/`.tscn`/`.tres` under `Scripts/`, `Scenes/`, `tests/` holding a legacy key; `CLAUDE.md`; `docs/superpowers/design/authoring-guide.md`; `.claude/skills/gamecode/SKILL.md`; `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Write the script.** Create `<scratch>/pr3_stat_keys.py`:

```python
#!/usr/bin/env python3
"""Clean-code PR3: rename the legacy stat keys to StudentData's field names.

Run with the PR3 worktree's Godot editor CLOSED:
    python pr3_stat_keys.py check <worktree>   # counts per file + sibling-name collisions
    python pr3_stat_keys.py apply <worktree>   # exact tokens, longest first, one pass
A duplicate dictionary key is not checked here: GDScript rejects one at parse
time, so the headless project_check (Procedure R2) catches it.
"""
import collections
import re
import subprocess
import sys

PAIRS = [
    ("akademis1", "akademis"), ("akademis2", "seni_budaya"), ("akademis3", "olahraga"),
    ("kepribadian1", "mood"), ("kepribadian2", "energy"),
    ("Akademis1", "Akademis"), ("Akademis2", "SeniBudaya"), ("Akademis3", "Olahraga"),
    ("Kepribadian1", "Mood"), ("Kepribadian2", "Energy"),
    ("target_akademis1", "target_akademis"), ("target_akademis2", "target_seni_budaya"),
    ("target_akademis3", "target_olahraga"),
    ("target_kepribadian1", "target_mood"), ("target_kepribadian2", "target_energy"),
    ("base_akademis1", "base_akademis"), ("base_akademis2", "base_seni_budaya"),
    ("base_akademis3", "base_olahraga"),
    ("roster_base_akademis1", "roster_base_akademis"),
    ("roster_base_akademis2", "roster_base_seni_budaya"),
    ("roster_base_akademis3", "roster_base_olahraga"),
    ("IconAkademis1", "IconAkademis"), ("IconAkademis2", "IconSeniBudaya"),
    ("IconAkademis3", "IconOlahraga"),
    ("IconKepribadian1", "IconMood"), ("IconKepribadian2", "IconEnergy"),
]
ROOTS = ["Scripts", "Scenes", "tests"]
EXTS = (".gd", ".tscn", ".tres")
EXEMPT = {"Scripts/Balance.gd"}
MAP = dict(PAIRS)
# Longest first: at any position the longest token wins, in a single pass.
RX = re.compile("|".join(re.escape(old) for old, _ in sorted(PAIRS, key=lambda p: -len(p[0]))))
LEFTOVER = re.compile(r"(?i)(akademis[123]|kepribadian[12])")


def files():
    out = subprocess.run(["git", "-c", "core.quotepath=false", "ls-files", "-z", *ROOTS],
                         check=True, capture_output=True, text=True, encoding="utf-8").stdout
    return [p for p in out.split("\0") if p.endswith(EXTS) and p not in EXEMPT]


def read(p):
    with open(p, "rb") as f:
        return f.read().decode("utf-8")


def convert(text):
    return RX.sub(lambda m: MAP[m.group(0)], text)


def sibling_collisions(text):
    seen = collections.Counter()
    for line in text.split("\n"):
        if line.startswith("[node "):
            name = re.search(r'name="([^"]+)"', line).group(1)
            parent = re.search(r'parent="([^"]*)"', line)
            seen[(parent.group(1) if parent else None, name)] += 1
    return [k for k, n in seen.items() if n > 1]


def main(mode):
    total, touched, problems = 0, 0, []
    for p in files():
        text = read(p)
        hits = len(RX.findall(text))
        if not hits:
            continue
        new_text = convert(text)
        if LEFTOVER.search(new_text):
            problems.append(f"{p}: a legacy key survives conversion")
        if p.endswith(".tscn"):
            before = set(sibling_collisions(text))
            for key in sibling_collisions(new_text):
                if key not in before:
                    problems.append(f"{p}: two siblings named {key[1]} under {key[0]}")
        total += hits
        touched += 1
        print(f"{hits:5d}  {p}")
        if mode == "apply" and not problems:
            with open(p, "wb") as f:
                f.write(new_text.encode("utf-8"))
    for msg in problems:
        print("PROBLEM:", msg)
    print(f"{total} occurrences in {touched} files ({mode})")
    return not problems


if __name__ == "__main__":
    import os
    os.chdir(sys.argv[2])
    sys.exit(0 if main(sys.argv[1]) else 1)
```
(`apply` stops writing at the first problem; run `check` first so there are none.)

- [ ] **Step 2: Dry run.** Editor closed (PowerShell check as in Task 7 Step 4, for `clean-code-stat-keys`). `python "<scratch>/pr3_stat_keys.py" check "<wt>"` → no `PROBLEM:`; about 1,180 occurrences in about 48 files (Task 9 already removed a few).

- [ ] **Step 3: Apply.** First save every comment line that names a legacy key, for review after the rename: `git -C "<wt>" grep -n -i -E "^\s*#.*(akademis[123]|kepribadian[12])" -- Scripts Scenes tests > "<scratch>/pr3_comments.txt"` (about 70 lines). Then `python "<scratch>/pr3_stat_keys.py" apply "<wt>"`. Then the leftovers must be zero: `git -C "<wt>" grep -n -i -E "akademis[123]|kepribadian[12]" -- Scripts Scenes tests` prints nothing.

- [ ] **Step 4: Garble sweep.** Open every line listed in `<scratch>/pr3_comments.txt` (same file and line number after the rename) and reword it so it reads right with the new names — e.g. `StatFlags.gd`'s "mood is mood", and comments in `DayVerdict.gd`, `StudentChatterCatalog.gd` and `tests/test_day_summary.gd` that still describe a "naming trap" CLAUDE.md no longer documents. Then run each of these and fix every hit by hand (the code is already right):

```bash
git grep -n -E "(akademis|seni_budaya|olahraga|mood|energy)/[0-9]" -- Scripts Scenes tests
git grep -n -i -E "\b(mood|energy|akademis|seni_budaya|olahraga) \((mood|energy|akademis|seni|seni budaya|seni_budaya|olahraga|academic)\)" -- Scripts Scenes tests
git grep -n -P "\b(akademis|seni_budaya|olahraga|mood|energy)\s*(=|->|→)\s*\1\b" -- Scripts Scenes tests
```
e.g. `energy (energy) at or below` → `energy at or below`; `"mood -> mood"` messages → say what is checked.

Then check by hand every dictionary keyed by capitalised stat names, because `Akademis`, `SeniBudaya` and `Olahraga` are also schedule-category names: `git grep -n -E '"(Akademis|SeniBudaya|Olahraga|Mood|Energy)"\s*:' -- Scripts`. For each hit (e.g. `StudentCardView.gd`'s rect, icon and value tables, `StatInfo.gd`'s bar table), confirm the dictionary holds each key once and that no code looks the same key up in a category table (e.g. `StudentCardView.gd`'s `"Akademis": "Akademis"` display-name table) expecting a bar, or the reverse.

- [ ] **Step 5: Live docs.** With the Edit tool:
  - `CLAUDE.md`, `### The two student representations`: replace
    ```markdown
    - `GameState.approved_students` — **`Array[Dictionary]`**, the cross-screen
      source of truth. Keys are the UI's names: `akademis1/2/3` (academic, seni,
      olahraga), `kepribadian1/2` (**mood, energy**), `name`, `id`, `quirk`,
      `persona`, `hobby_category`, `portrait`, `splash`.
    - `StudentData` — a `Resource` with real fields (`akademis`, `seni_budaya`,
      `olahraga`, `mood`, `energy`) and all the gameplay math. Used only inside
      the simulation.

    Bridge: `GameState.convert_to_student_data_array()` in, and
    `StudentManager.write_back_to_gamestate()` out. **The naming does not line up
    between the two** (`akademis2` = seni_budaya, `kepribadian1` = mood) — this is
    the single most common source of bugs here. Note `hobby_category` "Akademik"
    ```
    with
    ```markdown
    - `GameState.approved_students` — **`Array[Dictionary]`**, the cross-screen
      source of truth. Stat keys match `StudentData`'s fields (`akademis`,
      `seni_budaya`, `olahraga`, `mood`, `energy`), plus `name`, `id`, `quirk`,
      `persona`, `hobby_category`, `portrait`, `splash`.
    - `StudentData` — a `Resource` with those same stat fields and all the
      gameplay math. Used only inside the simulation.

    Bridge: `GameState.convert_to_student_data_array()` in, and
    `StudentManager.write_back_to_gamestate()` out. Note `hobby_category` "Akademik"
    ```
    and restore the `## Current work` line to `Nothing in flight (parked passes are in \`docs/superpowers/DEBT.md\`).` (the DEBT entry records Phases 2–3).
  - `docs/superpowers/design/authoring-guide.md`, the GameState worked example: replace
    ```markdown
    ## The trap: `approved_students` holds Array[Dictionary] whose keys are the
    ## UI's names -- `akademis1/2/3` are academic/seni/olahraga, and
    ## `kepribadian1/2` are mood/energy. StudentData, used inside the simulation,
    ## has real field names instead. That mismatch is the most common source of
    ## bugs here.
    ```
    with
    ```markdown
    ## The roster: `approved_students` holds Array[Dictionary] whose stat keys
    ## (`akademis`, `seni_budaya`, `olahraga`, `mood`, `energy`) are the same
    ## names as StudentData's fields.
    ```
  - `.claude/skills/gamecode/SKILL.md`: replace
    ```markdown
       State (name both sides across the `approved_students` ↔ `StudentData`
       bridge, e.g. `kepribadian1` (mood)), Files, and how Kelas 7/8/9 differ.
    ```
    with
    ```markdown
       State (name the `approved_students` / `StudentData` fields it touches;
       they share one set of names), Files, and how Kelas 7/8/9 differ.
    ```
  - Then `git -C "<wt>" grep -n -i -E "akademis[123]|kepribadian[12]" -- CLAUDE.md docs/superpowers/design docs/superpowers/DEBT.md .claude/skills Assets` must print nothing; fix any hit the same way.
  - Budget check: `CLAUDE.md` ≤ 23,000 characters.

- [ ] **Step 6: Regenerate the baseline** (editor closed): `& "<console>" --headless --path "<wt>" --script res://ci/clean_code_dump.gd`. Expected: `legacy_stat_keys: 0 entries`. `git -C "<wt>" diff ci/clean_code_baseline.gd` may only lower numbers or remove entries (DebugManager's and ApplyStudentRow's counts can drop); any increase is a bug in Task 9's edits — fix the code, never the baseline.

- [ ] **Step 7: Changelog** at the top of `docs/superpowers/CHANGELOG.md`:

```markdown
## 2026-09-26 — One vocabulary for student stats (PR3 of the clean-code pass)

- The roster dictionaries' `akademis1/2/3` and `kepribadian1/2` became
  `akademis`, `seni_budaya`, `olahraga`, `mood` and `energy` — the same names
  as `StudentData`'s fields — with their `target_`, `base_` and
  `roster_base_` forms, and the stat-bar nodes (`Akademis`, `SeniBudaya`,
  `Olahraga`, `Mood`, `Energy`, `Icon…`) in StudentCard, ReportCard and
  AturJadwal. About 1,180 occurrences in 48 files.
- The translation tables in `ApplyStudentRow.gd` and `DebugManager.gd` are
  gone; CLAUDE.md's "the naming does not line up" warning with them.
- No save migration: the roster is never written to disk.
```

- [ ] **Step 8: Commit** (`refactor(stats): rename the legacy stat keys to StudentData's field names`). First `git -C "<wt>" status --short` must show only this task's files — revert any stray rewrite with `git checkout --` — then `git -C "<wt>" add -A` with the same two plugin-file exclusions as Task 7 Step 9.

### Task 11: PR3 — verify, review, ship

- [ ] **Step 1:** Launch the editor (E2, E3). Open `Scenes/StudentCard/StudentCard.tscn`, `Scenes/ReportCard/ReportCard.tscn` and `Scenes/AturJadwal/AturJadwal.tscn` in turn (`scene_open`, **no** `scene_save`); `logs_read(source="editor", session_id=<sid>)` must show no missing-node or parse errors. Then open `Scenes/MainMenu/MainMenu.tscn`.
- [ ] **Step 2:** Procedure R with targeted suites: every suite whose file the Task 10 `check` output listed under `tests/`, plus `clean_code`, `debug_manager`, `project_check`. Reviewer: spec sections 2, 4, 6; tasks 9–11. PR3 allow-list: the token rename in `Scripts/`, `Scenes/`, `tests/`; Task 9's hand edits; the live-doc edits; the baseline (lowered only); the changelog.
- [ ] **Step 3:** Procedure S. Collaborator note:

```text
Heads-up: PR "<title>" renames the student stat keys: akademis1/2/3 ->
akademis / seni_budaya / olahraga and kepribadian1/2 -> mood / energy
(also target_, base_, roster_base_ forms and the stat-bar node names
Akademis/SeniBudaya/Olahraga/Mood/Energy). It touches GameState, StudentData
and DebugManager. Close Godot before pulling. Any new code using the old keys
now fails CI's project-check.
```
- [ ] **Step 4:** After the merge (S4), tell the user Phase 1 is done and offer to write the Phase 2 plan (PR4 `TutorialGuide`, PR5 duplicates) per the spec's section 5.
