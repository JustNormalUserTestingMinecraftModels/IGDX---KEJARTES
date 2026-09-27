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

## The triple-quote delimiters, tried before a single quote character.
const MULTILINE_QUOTES: PackedStringArray = ["\"\"\"", "'''"]

## A numeric literal not glued to an identifier: decimal, float, hex, binary.
const NUMBER_PATTERN := "(?<![A-Za-z0-9_.])(0x[0-9A-Fa-f_]+|0b[01_]+|[0-9][0-9_]*(?:\\.[0-9_]*)?(?:[eE][+-]?[0-9]+)?|\\.[0-9][0-9_]*(?:[eE][+-]?[0-9]+)?)(?![A-Za-z0-9_])"
## A var declaration, matched on a trimmed line whose leading annotations are
## already stripped; group 1 is everything after its name.
const VAR_PATTERN := "^(?:static\\s+)?var\\s+\\w+(.*)$"
## A `func` or `static func` line, matched once its leading annotations are
## stripped; group 1 is the function's name. Any whitespace separates the
## keywords (`func<TAB>name(`, `static  func`). The name is anything up to
## whitespace or `(` -- RegEx's `\w` is ASCII-only, and GDScript allows a
## non-ASCII name -- while a `func(` or `func (` lambda has no name to match.
const FUNC_PATTERN := "^(?:static\\s+)?func\\s+([^\\s(]+)\\s*\\("

## Compiled RegEx objects, built once per process.
static var _regex_cache: Dictionary = {}


## A compiled RegEx for `pattern`.
static func _regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		var re := RegEx.new()
		re.compile(pattern)
		_regex_cache[pattern] = re
	return _regex_cache[pattern]


## `line`, read on its own, with every string literal's contents blanked to
## spaces -- the quotes stay, so lengths and positions are preserved -- and
## any trailing `#` comment cut off. Handles both quote kinds and backslash
## escapes; a string that does not close on this line is blanked to the end
## of the line. A caller reading consecutive lines uses scan_code instead.
static func strip_strings_and_comments(line: String) -> String:
	return scan_code(line, "")["code"]


## One line lexed from inside `quote`: the delimiter of a string still open
## from the line before, or "". Returns "code" -- the line with every
## string's contents blanked to spaces (quotes kept, so lengths and positions
## are preserved) and any trailing `#` comment cut off -- and "quote", the
## delimiter of a string still open at the end of the line, or "". Any string
## can run onto the next line in GDScript 4: a `"""` or `'''` one, and a
## one-quote one through a raw newline or a `\`-newline escape.
static func scan_code(line: String, quote: String) -> Dictionary:
	if quote.is_empty() and not (line.contains("\"") or line.contains("'") or line.contains("#")):
		return {"code": line, "quote": ""}
	var out := ""
	var open := quote
	var i := 0
	var n := line.length()
	while i < n:
		if not open.is_empty():
			var close := _closing_quote(line, i, open)
			if close == -1:
				out += " ".repeat(n - i)
				break
			out += " ".repeat(close - i) + open
			i = close + open.length()
			open = ""
			continue
		var c := line[i]
		if c == "#":
			break
		if c == "\"" or c == "'":
			open = _opening_quote(line, i)
			out += open
			i += open.length()
			continue
		out += c
		i += 1
	return {"code": out, "quote": open}


## The delimiter of the string that opens at `line[at]`: a multi-line quote
## when three quotes stand there, else the single quote character.
static func _opening_quote(line: String, at: int) -> String:
	for delimiter in MULTILINE_QUOTES:
		if line.substr(at, delimiter.length()) == delimiter:
			return delimiter
	return line[at]


## Where `delimiter` next closes a string in `line`, searching from `from`
## and skipping backslash escapes, or -1 when it does not close on this line.
static func _closing_quote(line: String, from: int, delimiter: String) -> int:
	var i := from
	while i < line.length():
		if line[i] == "\\":
			i += 2
			continue
		if line.substr(i, delimiter.length()) == delimiter:
			return i
		i += 1
	return -1


## `depth` after the brackets in `code` (a scan_code result), never below 0.
static func _depth_after(code: String, depth: int) -> int:
	var d := depth
	for c in code:
		if OPENERS.has(c):
			d += 1
		elif CLOSERS.has(c):
			d = maxi(d - 1, 0)
	return d


## For each of `lines`, true when it continues the statement before it: it
## starts inside a string still open, inside an open bracket, or after a line
## that ended in a `\` continuation. GDScript ignores the indentation of such a
## line, so a column-0 continuation neither starts a function nor ends one.
static func continuation_flags(lines: PackedStringArray) -> Array[bool]:
	var flags: Array[bool] = []
	var quote := ""
	var depth := 0
	var joined := false
	for line in lines:
		flags.append(not quote.is_empty() or depth > 0 or joined)
		var scanned := scan_code(line, quote)
		var code: String = scanned["code"]
		quote = scanned["quote"]
		depth = _depth_after(code, depth)
		joined = quote.is_empty() and code.strip_edges(false, true).ends_with("\\")
	return flags


## The name of the function a column-0 `func` or `static func` line starts,
## or "" for any other line (lambdas and inner-class methods are indented).
## A column-0 line may lead with one or more annotations (`@rpc`,
## `@warning_ignore("x")`, ...) before the `func`; those are stripped first.
static func function_name(line: String) -> String:
	var code := _strip_leading_annotations(strip_strings_and_comments(line))
	var m := _regex(FUNC_PATTERN).search(code)
	return "" if m == null else m.get_string(1)


## `line` with any leading annotations removed, each an `@name` token
## optionally followed immediately by a balanced `(...)` argument list and
## the whitespace after it -- so a `func`, `var` or `class_name` keyword they
## precede on the same line is seen. A line with no leading `@` is returned
## unchanged. Pass it code whose strings are blanked, so a bracket inside an
## annotation's string argument cannot unbalance it.
static func _strip_leading_annotations(line: String) -> String:
	var rest := line
	while rest.begins_with("@"):
		var i := 1
		while i < rest.length() and rest[i] != " " and rest[i] != "\t" and rest[i] != "(":
			i += 1
		if i < rest.length() and rest[i] == "(":
			var depth := 1
			i += 1
			while i < rest.length() and depth > 0:
				if rest[i] == "(":
					depth += 1
				elif rest[i] == ")":
					depth -= 1
				i += 1
		rest = rest.substr(i).strip_edges(true, false)
	return rest


## The column-0 functions in `src`, in order, skipping any column-0 line that
## continues a statement (continuation_flags) -- such as the text of a
## multi-line string. The signature is read by _read_signature; the body runs
## from its end to the next column-0 line that is not blank, not a comment and
## not a continuation. Entries: `name`, `line` (1-based), `signature` (strings
## blanked, comments cut, leading annotations dropped) and `body` (raw lines,
## starting with any code a one-line function puts after its colon; empty for
## a body-less declaration such as an `@abstract` method).
static func parse_functions(src: String) -> Array[Dictionary]:
	var lines := src.replace("\r\n", "\n").split("\n")
	var continued := continuation_flags(lines)
	var out: Array[Dictionary] = []
	var i := 0
	while i < lines.size():
		var name := "" if continued[i] else function_name(lines[i])
		if name.is_empty():
			i += 1
			continue
		var head := _read_signature(lines, i)
		var body: Array = head["body"]
		var end: int = head["end"]
		if not head["bodyless"]:
			end = _read_body(lines, continued, end, body)
		out.append({"name": name, "line": i + 1, "signature": head["signature"], "body": body})
		i = end
	return out


## The signature that starts at `lines[start]`. It runs to the `:` that closes
## it at bracket depth 0; an unclosed bracket or string runs it to end of
## file. A line that ends outside any string, with its brackets closed, no
## `:` and no `\` continuation, ends it with no body at all -- a body-less
## declaration such as an `@abstract` method. Keys: "signature" (strings
## blanked, comments cut, leading annotations dropped), "body" (any code a
## one-line function puts after its colon), "end" (the index of the line
## after the signature) and "bodyless".
static func _read_signature(lines: PackedStringArray, start: int) -> Dictionary:
	var signature := ""
	var body: Array = []
	var depth := 0
	var seen_paren := false
	var quote := ""
	var i := start
	while i < lines.size():
		var raw: String = lines[i]
		var scanned := scan_code(raw, quote)
		var code: String = scanned["code"]
		quote = scanned["quote"]
		i += 1
		for k in code.length():
			var c := code[k]
			if OPENERS.has(c):
				depth += 1
				seen_paren = seen_paren or c == "("
			elif CLOSERS.has(c):
				depth -= 1
			elif c == ":" and depth == 0 and seen_paren:
				var tail := raw.substr(k + 1).strip_edges()
				if not tail.is_empty() and not tail.begins_with("#"):
					body.append(tail)
				return _signature_entry(signature + code.substr(0, k + 1), body, i, false)
		signature += code + " "
		if quote.is_empty() and depth == 0 and seen_paren \
				and not code.strip_edges(false, true).ends_with("\\"):
			return _signature_entry(signature, body, i, true)
	return _signature_entry(signature, body, i, false)


## _read_signature's result, with the signature's leading annotations dropped
## so a same-line `@rpc("x") func f(a)` is measured by f's own parameters.
static func _signature_entry(signature: String, body: Array, end: int, bodyless: bool) -> Dictionary:
	return {
		"signature": _strip_leading_annotations(signature.strip_edges()),
		"body": body,
		"end": end,
		"bodyless": bodyless,
	}


## Appends `lines` to `body` from `start` up to the next column-0 line that is
## not blank, not a comment and not a continuation (`continued`, from
## continuation_flags), and returns that line's index.
static func _read_body(lines: PackedStringArray, continued: Array[bool], start: int, body: Array) -> int:
	var i := start
	while i < lines.size():
		var line: String = lines[i]
		if not continued[i] and not line.is_empty() and not line.begins_with("\t") \
				and not line.begins_with(" ") and not line.begins_with("#"):
			break
		body.append(line)
		i += 1
	return i


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


## Bare numeric literals in `body`: strings (multi-line ones too) and comments
## do not count, nor do digits inside identifiers (`Vector2`, `node2`),
## trivial values, or a local `const` -- one line, or a table whose brackets
## run over several -- which names its numbers.
static func bare_number_count(body: Array) -> int:
	var re := _regex(NUMBER_PATTERN)
	var n := 0
	var quote := ""
	var const_depth := 0
	for raw in body:
		var scanned := scan_code(String(raw), quote)
		quote = scanned["quote"]
		var code := String(scanned["code"]).strip_edges()
		if const_depth > 0 or code.begins_with("const "):
			const_depth = _depth_after(code, const_depth)
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


## What follows the parameter list in `signature`: the text after the `)`
## that closes its first `(` at depth 0, or "" when it never closes. A `->`
## inside a lambda default (`cb := func() -> int: ...`) is not in it.
static func _return_part(signature: String) -> String:
	var open := signature.find("(")
	if open == -1:
		return ""
	var depth := 0
	for i in range(open, signature.length()):
		var c := signature[i]
		if OPENERS.has(c):
			depth += 1
		elif CLOSERS.has(c):
			depth -= 1
			if depth == 0:
				return signature.substr(i + 1)
	return ""


## Untyped declarations in one script: `var`s with neither `: Type` nor `:=`
## (behind any annotations, and not inside a string), function signatures
## without `->` after their parameter list, and parameters without `: Type`.
static func untyped_count(src: String, functions: Array[Dictionary]) -> int:
	var re := _regex(VAR_PATTERN)
	var n := 0
	var quote := ""
	for raw in src.split("\n"):
		var scanned := scan_code(raw, quote)
		quote = scanned["quote"]
		var code := _strip_leading_annotations(String(scanned["code"]).strip_edges())
		var m := re.search(code)
		if m != null and not m.get_string(1).strip_edges().begins_with(":"):
			n += 1
	for fn in functions:
		var signature: String = fn["signature"]
		if not _return_part(signature).contains("->"):
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
## A quoted res:// literal; group 1 drops an autoload's leading `*`. A
## backslash ends the path, so a literal inside an escaped quote
## (`"load(\"res://a.gd\")"`) is read without it.
const PATH_LITERAL_PATTERN := "[\"']\\*?(res://[^\"'\\\\\\n]*)\\\\?[\"']"
## A class_name declaration, behind any annotations (`@abstract class_name X`);
## group 1 is the name.
const CLASS_NAME_PATTERN := "(?m)^(?:@\\w+(?:\\([^)\\n]*\\))?\\s+)*class_name\\s+(\\w+)"


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
		var src := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
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


## The class_name `src` declares, or "" when it declares none.
static func declared_class_name(src: String) -> String:
	var m := _regex(CLASS_NAME_PATTERN).search(src)
	return "" if m == null else m.get_string(1)


## Production scripts whose file is not named after their class_name.
static func class_name_mismatches() -> Array[String]:
	var out: Array[String] = []
	for path in production_scripts():
		var declared := declared_class_name(FileAccess.get_file_as_string(path))
		if not declared.is_empty() and declared != path.get_file().get_basename():
			out.append("%s (class_name %s)" % [path, declared])
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
			shrunk.append("%s: now %d lines or fewer, or moved or renamed" % [key, LARGE_SCRIPT_LINES])
	grown.sort()
	shrunk.sort()
	return {"grown": grown, "shrunk": shrunk}


## Duplicate-group comparison: a current group is new unless its members are
## a subset of one baselined group that no other current group already
## covers -- a baselined group split in two means one new duplicated body. A
## baselined group not present exactly has shrunk and must be lowered.
static func compare_groups(baseline: Array, current: Array) -> Dictionary:
	var grown := PackedStringArray()
	var shrunk := PackedStringArray()
	var claimed := {}
	for group in current:
		var covering := _covering_group(String(group), baseline)
		if covering.is_empty() or claimed.has(covering):
			grown.append(String(group))
		else:
			claimed[covering] = true
	for old in baseline:
		if not current.has(old):
			shrunk.append(String(old))
	grown.sort()
	shrunk.sort()
	return {"grown": grown, "shrunk": shrunk}


## The baselined group whose members include every member of `group`, or ""
## when none does. A function has one body, so at most one group can.
static func _covering_group(group: String, baseline: Array) -> String:
	var members := group.split(" | ")
	for old in baseline:
		var old_members := String(old).split(" | ")
		var all_in := true
		for member in members:
			if not old_members.has(member):
				all_in = false
				break
		if all_in:
			return String(old)
	return ""


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


## Every constant in ci/clean_code_baseline.gd, by name. BASELINE is a class
## reference to the analyzer, so it is read through a Script-typed variable.
static func baseline_constants() -> Dictionary:
	var script: Script = BASELINE
	return script.get_script_constant_map()


## `measurement`'s value in ci/clean_code_baseline.gd.
static func baseline_for(measurement: Dictionary) -> Variant:
	return baseline_constants()[measurement["const"]]


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


## Every measurement against its baseline: `constants` ({const name: value},
## as baseline_constants() returns), or ci/clean_code_baseline.gd's when it is
## empty. Growth is a failure; a shrink is only a warning here, because CI
## cannot lower a baseline and a red check for an improvement would block
## every later PR. The editor suite fails on a shrink instead
## (tests/test_clean_code.gd), and ci/clean_code_dump.gd refuses to write a
## growth unless told to re-key. A measurement whose const the baseline lacks
## is compared with an empty baseline: every entry it has grew.
static func compare_all(report: Dictionary, constants: Dictionary = {}) -> Dictionary:
	var baselines := constants if not constants.is_empty() else baseline_constants()
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	for measurement in MEASUREMENTS:
		var baseline: Variant = _baseline_or_empty(baselines, measurement)
		var result := compare(measurement, baseline, report[measurement["key"]])
		for line in result["grown"]:
			failures.append("clean-code %s grew: %s -- see docs/superpowers/design/clean-code.md"
				% [measurement["key"], line])
		for line in result["shrunk"]:
			warnings.append("clean-code %s shrank: %s -- lower it with ci/clean_code_dump.gd"
				% [measurement["key"], line])
	return {"failures": failures, "warnings": warnings}


## `measurement`'s value in `baselines`, or an empty value of its kind when
## the baseline lacks its const (a new measurement, or a merge that dropped
## a block), so every current entry reports as grown instead of erroring.
static func _baseline_or_empty(baselines: Dictionary, measurement: Dictionary) -> Variant:
	if baselines.has(measurement["const"]):
		return baselines[measurement["const"]]
	var kind: String = measurement["kind"]
	if kind == "counts" or kind == "large":
		return {}
	return []


## The full text of ci/clean_code_baseline.gd for `report`.
static func format_baseline(report: Dictionary) -> String:
	var lines := PackedStringArray([
		"@tool",
		"extends RefCounted",
		"",
		"## GENERATED by ci/clean_code_dump.gd: the clean-code ratchet's baselines",
		"## (docs/superpowers/design/clean-code.md). Every number here may only go",
		"## DOWN. Never edit this file by hand, and never hand-merge a conflict in",
		"## it: take one side whole, then run the dump. A growth is fixed in the",
		"## code (reviewed exceptions: ci/clean_code_allowed.gd's four lists only).",
		"## After an improvement, regenerate with the command below. If any entry",
		"## would be added or raised, it writes nothing at all: it prints each one",
		"## as a `RAISED (review):` line and exits 1.",
		"##     <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd",
		"## After a move, rename or split, re-key: it writes every entry and prints",
		"## the RAISED lines as warnings -- the same numbers under new keys:",
		"##     <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd -- --rekey",
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
