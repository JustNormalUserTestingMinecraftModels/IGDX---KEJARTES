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
