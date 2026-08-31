@tool
extends McpTestSuite

## Ratchet on script documentation.
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
## Rules 3 and 4 of the standard -- per-function doc lines and section
## banners -- are review-time conventions, not tested here. A regex cannot
## tell a useful sentence from a restated function name, and a test that
## `## does the thing` would satisfy buys compliance instead of documentation.
##
## Both lists below shrink and never grow. A path that has been fixed but
## left in PENDING_HEADERS fails just as loudly as a new violation.
##
## Affects nothing at runtime -- source-text scan only, no scene needed.
## Must be @tool, and no test here may be a coroutine.

func suite_name() -> String:
	return "script_documentation"


## Scripts still lacking a file-header doc block, frozen 2026-08-31.
## Remove entries as they are documented. Never add one.
const PENDING_HEADERS: Array[String] = [
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd",
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd",
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd",
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd",
	"res://Scripts/Minigames/UI/BaseMinigame.gd",
	"res://Scripts/Minigames/UI/MinigameMenu.gd",
]

## script_path -> number of undocumented @export declarations, frozen
## 2026-08-31. Lower these as they are documented. Never raise one.
const PENDING_EXPORT_DOCS: Dictionary = {
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd": 30,
	"res://Scripts/Minigames/Akademis/Password.gd": 12,
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd": 15,
	"res://Scripts/Minigames/Akademis/Variabel.gd": 19,
	"res://Scripts/Minigames/Olahraga/Badminton.gd": 11,
	"res://Scripts/Minigames/Olahraga/MainBola.gd": 6,
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd": 22,
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd": 25,
	"res://Scripts/Minigames/UI/BaseMinigame.gd": 36,
	"res://Scripts/Minigames/UI/MinigameMenu.gd": 9,
	"res://Scripts/Minigames/UI/MinigameTutorial.gd": 10,
	"res://Scripts/Minigames/UI/PauseMenu.gd": 13,
}

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


## Render an Array[String] as a pasteable GDScript literal.
func _as_array_literal(name: String, items: Array[String]) -> String:
	var lines: Array[String] = ["const %s: Array[String] = [" % name]
	for s in items:
		lines.append("\t\"%s\"," % s)
	lines.append("]")
	return "\n".join(lines)


## Render a Dictionary as a pasteable GDScript literal.
func _as_dict_literal(name: String, d: Dictionary) -> String:
	var keys: Array = d.keys()
	keys.sort()
	var lines: Array[String] = ["const %s: Dictionary = {" % name]
	for k in keys:
		lines.append("\t\"%s\": %d," % [k, d[k]])
	lines.append("}")
	return "\n".join(lines)


func test_every_script_has_a_file_header_doc_block() -> void:
	var missing := _scan_headers()
	var unexpected: Array[String] = []
	for path in missing:
		if not PENDING_HEADERS.has(path):
			unexpected.append("  " + path)
	assert_true(unexpected.is_empty(),
		("These scripts have no `##` header block in their first %d lines. "
		% HEADER_SEARCH_LINES)
		+ "Say what the file is, who drives it, and what it affects.\n"
		+ "\n".join(unexpected))


func test_pending_header_list_is_not_stale() -> void:
	var missing := _scan_headers()
	var fixed: Array[String] = []
	for path in PENDING_HEADERS:
		if not missing.has(path):
			fixed.append("  " + path)
	assert_true(fixed.is_empty(),
		"These scripts are documented now -- drop them from PENDING_HEADERS "
		+ "in the same commit.\n"
		+ "\n".join(fixed)
		+ "\n\nCurrent scan, paste over PENDING_HEADERS:\n"
		+ _as_array_literal("PENDING_HEADERS", missing))


func test_no_script_gains_undocumented_exports() -> void:
	var current := _scan_exports()
	var grown: Array[String] = []
	for path in current:
		var allowed: int = int(PENDING_EXPORT_DOCS.get(path, 0))
		if int(current[path]) > allowed:
			grown.append("  %s: allowed %d, now %d" % [path, allowed, current[path]])
	grown.sort()
	assert_true(grown.is_empty(),
		"Every @export needs a `##` line above it -- Godot shows it as the "
		+ "Inspector tooltip.\n"
		+ "\n".join(grown))


func test_pending_export_doc_counts_are_not_stale() -> void:
	var current := _scan_exports()
	var shrunk: Array[String] = []
	for path in PENDING_EXPORT_DOCS:
		var now: int = int(current.get(path, 0))
		if now < int(PENDING_EXPORT_DOCS[path]):
			shrunk.append("  %s: allowed %d, now %d" % [path, PENDING_EXPORT_DOCS[path], now])
	shrunk.sort()
	assert_true(shrunk.is_empty(),
		"The ratchet turned -- lower these in PENDING_EXPORT_DOCS in the same "
		+ "commit.\n"
		+ "\n".join(shrunk)
		+ "\n\nCurrent scan, paste over PENDING_EXPORT_DOCS:\n"
		+ _as_dict_literal("PENDING_EXPORT_DOCS", current))
