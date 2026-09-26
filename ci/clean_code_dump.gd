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
## time, so a baseline that does not parse is a message and exit 1 rather
## than a script that fails to compile. It needs no autoloads, which --script
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
## Printed when the scanner or the baseline it preloads does not compile.
const LOAD_FAILURE := "clean_code_dump: ci/clean_code_scan.gd did not load. If ci/clean_code_baseline.gd has conflict markers or a parse error, take one side whole (git checkout --ours or --theirs), then run this again."
## Printed, with the count, when the default mode refuses to write.
const REFUSED := "clean_code_dump: nothing written -- %d entries would be added or raised. Fix the code; after a move, rename or split, run it with -- --rekey and review the RAISED lines."
## Printed, with the count, when re-key mode writes added or raised entries.
const REKEYED := "clean_code_dump: re-keyed -- %d entries added or raised; check the diff shows the same numbers under new keys."


func _init() -> void:
	var scan := load(SCAN_PATH) as Script
	if scan == null or not scan.can_instantiate():
		printerr(LOAD_FAILURE)
		quit(1)
		return
	var report: Dictionary = scan.call("full_report")
	var raised := raised_lines(scan, report)
	for line in raised:
		print(RAISED_PREFIX, line)
	var rekey := OS.get_cmdline_user_args().has(REKEY_ARG)
	if not raised.is_empty() and not rekey:
		printerr(REFUSED % raised.size())
		quit(1)
		return
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("clean_code_dump: cannot write %s: %s"
			% [OUT_PATH, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	file.store_string(scan.call("format_baseline", report))
	file.close()
	print(scan.call("summary", report))
	if not raised.is_empty():
		print(REKEYED % raised.size())
	print("clean_code_dump: wrote ", OUT_PATH)
	quit(0)


## Every entry `report` would add to or raise in the current baseline: the
## "grew" lines CI would fail on, from `scan`'s compare_all.
static func raised_lines(scan: Script, report: Dictionary) -> PackedStringArray:
	var result: Dictionary = scan.call("compare_all", report, scan.call("baseline_constants"))
	return result["failures"]
