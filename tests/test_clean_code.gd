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
## Fewer production scripts than this means the walk missed the project (it
## holds 166); a count of debt would not do, since debt is meant to reach zero.
const MIN_PRODUCTION_SCRIPTS := 100

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


func test_a_crlf_file_parses_like_an_lf_file() -> void:
	var fns := Scan.parse_functions("func a() -> void:\r\n\tx()\r\n\r\n\ty()\r\n")
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 2,
		"a CRLF blank line does not end the body")


func test_an_annotated_function_is_still_a_function() -> void:
	assert_eq(Scan.function_name("@warning_ignore(\"unused\") func f(a):"), "f")
	assert_eq(Scan.function_name("@rpc func g() -> void:"), "g")
	assert_eq(Scan.function_name("\tfunc lambda_like():"), "", "indented is not column-0")


## Any whitespace separates `static`, `func` and the name, as GDScript allows.
func test_a_tab_or_a_double_space_still_reads_as_a_function() -> void:
	assert_eq(Scan.function_name("func\tf(a):"), "f")
	assert_eq(Scan.function_name("static  func g():"), "g")
	assert_eq(Scan.function_name("static\tfunc h() -> void:"), "h")


## A same-line annotation's arguments are not the function's parameters.
func test_a_same_line_annotation_is_not_counted_as_parameters() -> void:
	var typed := "@warning_ignore(\"x\") func f(a: int) -> void:\n\tpass"
	assert_eq(Scan.untyped_count(typed, Scan.parse_functions(typed)), 0,
		"a fully typed function")
	var fns := Scan.parse_functions("@rpc(\"any_peer\") func g(a, b, c) -> void:\n\tpass")
	assert_eq(Scan.untyped_parameter_count(fns[0]["signature"]), 3, "g's own a, b and c")


## A body-less `@abstract` method ends at its own line instead of swallowing
## the next function, and an annotated class_name is still read.
func test_an_abstract_method_has_no_body() -> void:
	var src := "\n".join(PackedStringArray([
		"@abstract class_name QuizBase extends Node",
		"@abstract func _score() -> int",
		"func finish(result):",
		"\tprint(result)",
	]))
	var fns := Scan.parse_functions(src)
	var names := PackedStringArray()
	for fn in fns:
		names.append(fn["name"])
	assert_eq(",".join(names), "_score,finish")
	assert_eq(fns[0]["body"].size(), 0, "the abstract method has no body")
	assert_eq(Scan.code_lines(fns[1]["body"]).size(), 1)
	assert_eq(Scan.untyped_count(src, fns), 2, "finish's missing -> and its untyped result")
	assert_eq(Scan.declared_class_name(src), "QuizBase")
	assert_eq(Scan.declared_class_name("@tool\nextends Node\nclass_name Plain"), "Plain")
	assert_eq(Scan.declared_class_name("extends Node"), "")


## A column-0 line inside brackets still belongs to the function.
func test_a_column0_line_inside_brackets_does_not_end_the_body() -> void:
	var src := "\n".join(PackedStringArray([
		"func points() -> void:",
		"\tvar pts := [",
		"Vector2(10, 20),",
		"Vector2(300, 400),",
		"\t]",
		"\tprint(pts)",
	]))
	var fns := Scan.parse_functions(src)
	assert_eq(fns.size(), 1)
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 5, "every line is points()'s")
	assert_eq(Scan.bare_number_count(fns[0]["body"]), 4, "10, 20, 300 and 400")


## A column-0 line after a `\` continuation still belongs to the function.
func test_a_column0_continuation_line_does_not_end_the_body() -> void:
	var src := "\n".join(PackedStringArray([
		"func total() -> int:",
		"\tvar sum := 10 + \\",
		"20",
		"\treturn sum",
	]))
	var fns := Scan.parse_functions(src)
	assert_eq(fns.size(), 1)
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 3)
	assert_eq(Scan.bare_number_count(fns[0]["body"]), 2, "10 and 20")


## The column-0 text of a multi-line string still belongs to the function, and
## its numbers are string text, not bare numbers.
func test_a_column0_multiline_string_line_does_not_end_the_body() -> void:
	var src := "\n".join(PackedStringArray([
		"func banner() -> void:",
		"\tvar text := \"\"\"",
		"WELCOME 42",
		"\"\"\"",
		"\tprint(text, 7)",
	]))
	var fns := Scan.parse_functions(src)
	assert_eq(fns.size(), 1)
	assert_eq(Scan.code_lines(fns[0]["body"]).size(), 4)
	assert_eq(Scan.bare_number_count(fns[0]["body"]), 1, "only the 7")


## A `func` line inside a class-level multi-line string is text, not a function.
func test_a_func_inside_a_multiline_string_is_not_a_function() -> void:
	var src := "\n".join(PackedStringArray([
		"const TEMPLATE := '''",
		"func fake(a):",
		"\tvar b = a",
		"'''",
		"func real() -> void:",
		"\tpass",
	]))
	var fns := Scan.parse_functions(src)
	assert_eq(fns.size(), 1)
	assert_eq(fns[0]["name"], "real")
	assert_eq(Scan.untyped_count(src, fns), 0, "the template's untyped code is text")


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


## A local const table over several lines names its numbers too; counting
## resumes once its brackets close.
func test_a_multiline_local_const_table_names_its_numbers() -> void:
	var body := [
		"\tconst GAINS := {",
		"\t\t\"a\": 42,",
		"\t\t\"b\": 17,",
		"\t}",
		"\tfoo(GAINS, 9)",
	]
	assert_eq(Scan.bare_number_count(body), 1, "only the 9 after the table")


func test_untyped_counts_vars_signatures_and_parameters() -> void:
	var src := "\n".join(PackedStringArray([
		"var a = 1",
		"var b: int = 1",
		"var c := 1",
		"@onready var d = $X",
		"@export_range(0, 10) var e := 5",
		"@export_range(0.0, float(10)) var speed = 5.0",
		"func f(x, y: int):",
		"\tvar g = 2",
		"\tvar h := 2",
		"\tfor i in 3:",
		"\t\tpass",
	]))
	assert_eq(Scan.untyped_count(src, Scan.parse_functions(src)), 6,
		"a, d, speed (behind nested brackets) and g; f's missing -> ; f's untyped x")


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
	assert_false(Scan.is_safe_asset_name("a—b.png"), "an em dash")


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
	assert_eq(",".join(PackedStringArray(Scan.path_literals(
		"\tvar snippet := \"load(\\\"res://icon.svg\\\")\""))),
		"res://icon.svg", "an escaped quote ends the literal, without its backslash")
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


## An empty value for every measurement, keyed by `field` of MEASUREMENTS:
## "const" for a baseline, "key" for a report.
func _empty_measurements(field: String) -> Dictionary:
	var out := {}
	for measurement in Scan.MEASUREMENTS:
		var is_map: bool = measurement["kind"] == "counts" or measurement["kind"] == "large"
		out[measurement[field]] = {} if is_map else []
	return out


## compare_all -- what CI runs -- fails on a growth and only warns on a shrink.
func test_compare_all_fails_on_growth_and_only_warns_on_a_shrink() -> void:
	var constants := _empty_measurements("const")
	constants["UNTYPED"] = {"res://Scripts/A.gd": 2}
	var shrunk := _empty_measurements("key")
	shrunk["untyped"] = {"res://Scripts/A.gd": 1}
	var result := Scan.compare_all(shrunk, constants)
	assert_eq(result["failures"].size(), 0, "a shrink does not fail CI")
	assert_eq(result["warnings"].size(), 1, "a shrink is a warning")
	var grown := _empty_measurements("key")
	grown["untyped"] = {"res://Scripts/A.gd": 3}
	result = Scan.compare_all(grown, constants)
	assert_eq(result["failures"].size(), 1, "a growth fails CI")
	assert_eq(result["warnings"].size(), 0, "a growth is not a warning")


func test_the_full_report_has_every_measurement() -> void:
	for key in ["long_functions", "untyped", "bare_numbers", "duplicate_groups",
			"large_scripts", "bad_script_names", "class_name_mismatches",
			"bad_asset_names", "misspelled_names", "unresolved_paths", "legacy_stat_keys"]:
		assert_true(_report.has(key), "full_report() lacks %s" % key)
	assert_true(Scan.production_scripts().size() > MIN_PRODUCTION_SCRIPTS,
		"the scan found the project's scripts")


func test_every_measurement_has_a_baseline_constant() -> void:
	var constants: Dictionary = Scan.baseline_constants()
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
