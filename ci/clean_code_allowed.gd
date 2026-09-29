@tool
extends RefCounted

## Reviewed, permanent exceptions to the clean-code ratchet, keyed per
## measurement (docs/superpowers/design/clean-code.md). Unlike
## ci/clean_code_baseline.gd this file is written by hand, and every entry
## says why it is allowed. A file listed under a measurement is left out of
## that measurement entirely.

## Files exempt from the long-function measurement.
const LONG_FUNCTIONS: PackedStringArray = [
	# ThemeFactory's _build_* functions are declarative style tables, not
	# logic, and CLAUDE.md requires every new theme variation to live there.
	"res://Scripts/Design/ThemeFactory.gd",
]

## Files exempt from the large-script measurement.
const LARGE_SCRIPTS: PackedStringArray = [
	# Same reason: every new theme variation is added to ThemeFactory.gd.
	"res://Scripts/Design/ThemeFactory.gd",
]

## Files exempt from the bare-number measurement.
const BARE_NUMBERS: PackedStringArray = [
	# A style table is made of numbers (margins, radii, sizes).
	"res://Scripts/Design/ThemeFactory.gd",
]

## "source: literal" pairs the literal-path rule accepts although the path
## does not exist.
const UNRESOLVED_PATHS: PackedStringArray = []
