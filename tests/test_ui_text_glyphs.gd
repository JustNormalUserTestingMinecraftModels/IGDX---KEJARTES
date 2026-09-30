@tool
extends McpTestSuite

## "No emoji as UI iconography" (CLAUDE.md), kept by a test (UI depth pass
## Phase 3, plan decision P6). A pictograph or dingbat typed into UI text
## renders in whatever emoji font the phone has, at the wrong weight and
## colour; the Icons/ set is the picture channel. Scans every .tscn and .gd
## under Scenes/ and Scripts/, minigames included since their mobile layout
## pass (2026-09-29), except the debug overlay (outside the design system),
## skipping comments. Typography stays allowed: the Arrows block (12 → 9)
## and ×.
##
## Must be @tool; no test here may be a coroutine.

## Banned code-point ranges: misc technical (fast-forward and skip marks),
## misc symbols and dingbats (bolts, sparkles, heavy arrows), misc symbols
## and arrows extended, the emoji planes, and the emoji-presentation
## selector.
const BANNED := [[0x2300, 0x23FF], [0x2600, 0x27BF], [0x2B00, 0x2BFF],
	[0x1F000, 0x1FAFF], [0xFE0F, 0xFE0F]]
## Folders outside the design system.
const SKIP_DIRS := ["res://Scripts/Debug"]
## Reviewed exceptions: file -> substrings a line may carry.
const ALLOWED := {
	# The stat glyph is the no-icon fallback StatDetailPopup shows when a
	# screen passes no artwork; every current caller passes one.
	"res://Scripts/UI/StatInfo.gd": ["\"glyph\":"],
	# The minigame test launcher's School Day button: debug-only launcher,
	# not player-facing.
	"res://Scenes/Minigames/UI/MinigameMenu.tscn": ["Simulasi Minggu Sekolah"],
}


func suite_name() -> String:
	return "ui_text_glyphs"


## `line` without a trailing GDScript comment: the first `#` outside a
## double-quoted string ends the code.
func _code_of(line: String) -> String:
	var in_str := false
	for i in line.length():
		var c := line[i]
		if c == "\"":
			in_str = not in_str
		elif c == "#" and not in_str:
			return line.substr(0, i)
	return line


func _banned(text: String) -> String:
	for i in text.length():
		var cp := text.unicode_at(i)
		for r in BANNED:
			if cp >= r[0] and cp <= r[1]:
				return text[i]
	return ""


func _allowed(path: String, line: String) -> bool:
	for needle in ALLOWED.get(path, []):
		if line.contains(needle):
			return true
	return false


## Files read by the last test run; the test checks it so an empty or moved
## tree cannot pass by scanning nothing.
var _scanned := 0


func _scan(dir_path: String, hits: Array[String]) -> void:
	if dir_path in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub), hits)
	for file in dir.get_files():
		if not (file.ends_with(".tscn") or file.ends_with(".gd")):
			continue
		_scanned += 1
		var path := dir_path.path_join(file)
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := _code_of(line) if file.ends_with(".gd") else line
			var hit := _banned(code)
			if hit != "" and not _allowed(path, line):
				hits.append("%s:%d %s" % [path, n, hit])


func test_no_ui_text_carries_an_emoji_or_dingbat() -> void:
	var hits: Array[String] = []
	_scanned = 0
	_scan("res://Scenes", hits)
	_scan("res://Scripts", hits)
	assert_true(_scanned > 100, "the scan read the tree (%d files)" % _scanned)
	assert_eq(hits.size(), 0, "glyphs in UI text:\n" + "\n".join(hits))
