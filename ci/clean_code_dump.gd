extends SceneTree

## Regenerates ci/clean_code_baseline.gd from the current tree, then prints a
## per-measurement summary. Two modes:
##
## Lower (the default) -- after an improvement (the editor suite's
## *_baseline_is_tight tests say when). It compares the tree with the current
## baseline exactly as CI does (compare_all's "grew" lines), and if any entry
## would be added or raised it prints each as `RAISED (review): <line>` and
## exits 1 WITHOUT writing, so new debt cannot ride in beside an improvement.
##
##     <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd
##
## Re-key (`-- --rekey`) -- after moving, renaming or splitting a script or a
## function, which re-keys its entries. It writes the full report and prints
## the same RAISED lines as warnings, for review: a move or rename shows the
## same numbers under new keys, and a split's pieces are each smaller than
## the original.
##
##     <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd -- --rekey
##
## Never hand-merge a conflict in the baseline: take one side whole, then run
## this. Pure file I/O through ci/clean_code_scan.gd, which is loaded at run
## time, so a baseline or allowed list that does not parse is a message and
## exit 1 rather than a script that fails to compile. Any failure exits 1
## without writing -- a script error part-way included, since the first
## thing this does is set exit code 1. It needs no autoloads, which --script
## mode does not register anyway.

## The scanner that measures the tree.
const SCAN_PATH := "res://ci/clean_code_scan.gd"
## The file this tool rewrites.
const OUT_PATH := "res://ci/clean_code_baseline.gd"
## The user argument (after `--`) that lets the dump write entries that were
## added or raised.
const REKEY_ARG := "--rekey"
## The prefix of every line the dump would add or raise.
const RAISED_PREFIX := "RAISED (review): "
## Printed when the scanner, or a file it preloads, does not compile. Each of
## the three has its own fix.
const LOAD_FAILURE := "clean_code_dump: ci/clean_code_scan.gd did not load -- one of three files has a parse error: ci/clean_code_allowed.gd (hand-written: fix its syntax), ci/clean_code_baseline.gd (generated: take one side whole with git checkout --ours or --theirs, then run this again) or ci/clean_code_scan.gd (fix it)."
## Printed, with the reason, when the scan came back incomplete: a script
## error in the scanner hands back an empty value instead of stopping.
const INCOMPLETE := "clean_code_dump: nothing written -- the scan came back incomplete (%s). Fix the SCRIPT ERROR above, then run this again."
## Printed, with the count, when the default mode refuses to write.
const REFUSED := "clean_code_dump: nothing written -- %d entries would be added or raised. Fix the code; after a move, rename or split, run it with -- --rekey and review the RAISED lines."
## Printed, with the count, when re-key mode writes added or raised entries.
const REKEYED := "clean_code_dump: re-keyed -- %d entries added or raised; check the diff shows the same numbers under new keys."


## Measures the tree, checks the result is whole, and writes the baseline
## unless that would add or raise an entry outside re-key mode.
func _init() -> void:
	# quit() takes effect at the end of the frame and the last call sets the
	# exit code, so if a script error stops this function part-way, Godot
	# still exits with 1. Only a finished write calls quit(0).
	quit(1)
	var scan := load(SCAN_PATH) as Script
	if scan == null or not scan.can_instantiate():
		printerr(LOAD_FAILURE)
		return
	var report: Variant = scan.call("full_report")
	var compared := checked_compare(scan, report)
	if compared.has("error"):
		printerr(INCOMPLETE % compared["error"])
		return
	var raised: PackedStringArray = compared["failures"]
	for line in raised:
		print(RAISED_PREFIX, line)
	var rekey := OS.get_cmdline_user_args().has(REKEY_ARG)
	if not raised.is_empty() and not rekey:
		printerr(REFUSED % raised.size())
		return
	# Build the text before opening the file: opening truncates it, and a
	# script error inside format_baseline hands back null instead of stopping.
	var text: Variant = scan.call("format_baseline", report)
	if text is not String or (text as String).is_empty():
		printerr(INCOMPLETE % "format_baseline returned no text")
		return
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("clean_code_dump: cannot write %s: %s"
			% [OUT_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(text)
	file.close()
	print(scan.call("summary", report))
	if not raised.is_empty():
		print(REKEYED % raised.size())
	print("clean_code_dump: wrote ", OUT_PATH)
	quit(0)


## `scan`'s compare_all for `report` against the current baseline -- its
## "failures" are every entry the report would add or raise -- or {"error":
## reason} when the report lacks a measurement or the result lacks
## "failures". A script error inside the scanner returns an empty value
## rather than stopping the dump, so both are checked before anything is
## written.
static func checked_compare(scan: Script, report: Variant) -> Dictionary:
	if report is not Dictionary:
		return {"error": "full_report returned no report"}
	var measurements: Array = scan.get_script_constant_map()["MEASUREMENTS"]
	for measurement: Dictionary in measurements:
		if not (report as Dictionary).has(measurement["key"]):
			return {"error": "the report lacks %s" % measurement["key"]}
	var result: Variant = scan.call("compare_all", report, scan.call("baseline_constants"))
	if result is not Dictionary or not (result as Dictionary).has("failures"):
		return {"error": "compare_all returned no \"failures\""}
	return result
