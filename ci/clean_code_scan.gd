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


## The whole-project report. Task 1: empty; Task 2 fills in every measurement.
static func full_report() -> Dictionary:
	return {}
