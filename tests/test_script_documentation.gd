@tool
extends McpTestSuite

## Hard rule on script documentation.
##
## Two mechanically checkable halves of the documentation standard in
## docs/superpowers/design/authoring-guide.md:
##
##   1. Every script opens with a `##` block saying what it is and what it
##      affects.
##   2. Every `@export` carries a `##` line immediately above it. Godot
##      surfaces that text as the Inspector tooltip, so this rule is the one
##      that pays out directly in the editor.
##
## This was a ratchet (PENDING_HEADERS/PENDING_EXPORT_DOCS allowlists) until
## the 2026-08-31 21-task documentation sweep emptied both. It is a plain
## rule now: every non-exempt script must satisfy both halves outright, no
## allowlist to check against.
##
## Rules 3 and 4 of the standard -- per-function doc lines and section
## banners -- are review-time conventions, not tested here. A regex cannot
## tell a useful sentence from a restated function name, and a test that
## `## does the thing` would satisfy buys compliance instead of documentation.
##
## Affects nothing at runtime -- source-text scan only, no scene needed.
## Must be @tool, and no test here may be a coroutine.

func suite_name() -> String:
	return "script_documentation"


## Same exemption as the editability ratchet: a programmatic developer
## overlay, out of scope for the design system per CLAUDE.md.
const EXEMPT: Array[String] = [
	"res://Scripts/Debug/DebugManager.gd",
]

## How far into a file the header block may start. Leaves room for `@tool`,
## `class_name`, `extends` and a blank line.
const HEADER_SEARCH_LINES: int = 12


## Every res:// path under `root` ending in `suffix`.
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


## Every non-exempt gameplay script, sorted for stable failure messages.
func _all_scripts() -> Array[String]:
	var out: Array[String] = []
	for p in _all_files_under("res://Scripts", ".gd"):
		if not EXEMPT.has(p):
			out.append(p)
	out.sort()
	return out


## True when the first HEADER_SEARCH_LINES lines contain a `##` doc line.
func _has_file_header(src: String) -> bool:
	var lines := src.split("\n")
	var limit: int = mini(HEADER_SEARCH_LINES, lines.size())
	for i in range(limit):
		if lines[i].strip_edges().begins_with("##"):
			return true
	return false


## Count `@export` declarations with no `##` line directly above them.
## An `@export_group`/`@export_subgroup`/`@export_category` banner is not a
## declaration and is skipped; a blank line or a plain `#` comment between the
## doc and the export breaks the association, which matches how Godot itself
## attaches Inspector tooltips.
func _undocumented_exports(src: String) -> int:
	var lines := src.split("\n")
	var n := 0
	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if not line.begins_with("@export"):
			continue
		if line.begins_with("@export_group") \
			or line.begins_with("@export_subgroup") \
			or line.begins_with("@export_category"):
			continue
		var documented := false
		var j := i - 1
		# Walk back over a multi-line `##` block; stop at anything else.
		while j >= 0 and lines[j].strip_edges().begins_with("##"):
			documented = true
			j -= 1
		if not documented:
			n += 1
	return n


## script_path -> undocumented-export count, for files with at least one.
func _scan_exports() -> Dictionary:
	var out := {}
	for path in _all_scripts():
		var n := _undocumented_exports(FileAccess.get_file_as_string(path))
		if n > 0:
			out[path] = n
	return out


## Scripts with no file-header doc block.
func _scan_headers() -> Array[String]:
	var out: Array[String] = []
	for path in _all_scripts():
		if not _has_file_header(FileAccess.get_file_as_string(path)):
			out.append(path)
	return out


func test_every_script_has_a_file_header_doc_block() -> void:
	var missing := _scan_headers()
	assert_true(missing.is_empty(),
		("These scripts have no `##` header block in their first %d lines. "
		% HEADER_SEARCH_LINES)
		+ "Say what the file is, who drives it, and what it affects.\n  "
		+ "\n  ".join(missing))


func test_every_export_has_an_inspector_doc_comment() -> void:
	var current := _scan_exports()
	var offenders: Array[String] = []
	for path in current:
		offenders.append("  %s: %d undocumented" % [path, current[path]])
	offenders.sort()
	assert_true(offenders.is_empty(),
		"Every @export needs a `##` line above it -- Godot shows it as the "
		+ "Inspector tooltip.\n"
		+ "\n".join(offenders))
