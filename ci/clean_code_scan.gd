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
