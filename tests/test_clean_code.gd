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
