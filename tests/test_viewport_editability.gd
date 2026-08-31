@tool
extends McpTestSuite

## Ratchet on runtime UI construction.
##
## The project's quality-of-life rule is that a human must be able to open a
## .tscn, see every sprite/panel/label, select it and change it. Anything a
## script builds with `SomeControl.new()` at runtime is invisible in the
## editor: it cannot be selected, moved, re-themed or previewed.
##
## This suite does not forbid runtime construction outright -- roughly 340
## call sites predate the rule. It freezes the count per file and fails if
## any file grows. When a conversion legitimately lowers a file's count the
## second test fails and prints the exact literal to paste into BASELINE.
## That is the ratchet: it only turns one way.
##
## Affects nothing at runtime. This is a source-text scan in the same style
## as tests/test_project_hygiene.gd -- it instantiates nothing, needs no
## scene open, and costs a few milliseconds.
##
## Must be @tool or the runner reports the class abstract/broken, and no test
## here may be a coroutine -- the runner calls suite.call(name) without
## awaiting.

func suite_name() -> String:
	return "viewport_editability"


## Node types whose runtime construction hides a visual from the 2D viewport.
## Resource types (StyleBoxFlat, ShaderMaterial) are deliberately absent --
## they are covered by the theme rule in CLAUDE.md, not by this one.
const VISUAL_TYPES: Array[String] = [
	"Control", "Panel", "PanelContainer", "MarginContainer", "CenterContainer",
	"VBoxContainer", "HBoxContainer", "GridContainer", "ScrollContainer",
	"AspectRatioContainer", "HSeparator", "VSeparator", "HFlowContainer",
	"Label", "RichTextLabel", "Button", "TextureButton", "CheckBox",
	"TextureRect", "ColorRect", "NinePatchRect",
	"ProgressBar", "TextureProgressBar", "StatBar",
	"Sprite2D", "AnimatedSprite2D", "Line2D", "Polygon2D",
	"CPUParticles2D", "GPUParticles2D", "CanvasLayer",
]

## Files this rule deliberately does not cover. DebugManager is a
## programmatic developer overlay, already out of scope for the design system
## per CLAUDE.md.
const EXEMPT: Array[String] = [
	"res://Scripts/Debug/DebugManager.gd",
]

## Per-file count of runtime visual construction, frozen 2026-08-31.
## Lower these as conversions land. Never raise one.
const BASELINE: Dictionary = {
	"res://Scripts/AnimUtils.gd": 1,
	"res://Scripts/AturJadwal/ActivityRow.gd": 2,
	"res://Scripts/AturJadwal/atur_jadwal.gd": 17,
	"res://Scripts/CutScene/cut_scene.gd": 15,
	"res://Scripts/EndGame/SemesterEnd.gd": 1,
	"res://Scripts/Inventory/inventory.gd": 11,
	"res://Scripts/Koperasi/koprasi.gd": 4,
	"res://Scripts/Koperasi/rakbarang_1.gd": 12,
	"res://Scripts/Lobby/loby.gd": 8,
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd": 2,
	"res://Scripts/Minigames/Akademis/Password.gd": 4,
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd": 1,
	"res://Scripts/Minigames/Akademis/Variabel.gd": 4,
	"res://Scripts/Minigames/Olahraga/Badminton.gd": 8,
	"res://Scripts/Minigames/Olahraga/MainBola.gd": 2,
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd": 8,
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd": 5,
	"res://Scripts/Minigames/UI/BaseMinigame.gd": 39,
	"res://Scripts/Minigames/UI/MinigameTutorial.gd": 12,
	"res://Scripts/Minigames/UI/PauseMenu.gd": 1,
	"res://Scripts/Pengaturan.gd": 12,
	"res://Scripts/SchoolSimulation/BookClockWidget.gd": 3,
	"res://Scripts/SchoolSimulation/DailyDecayOverview.gd": 12,
	"res://Scripts/SchoolSimulation/EventAnnouncement.gd": 2,
	"res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd": 13,
	"res://Scripts/SchoolSimulation/EventWarning.gd": 2,
	"res://Scripts/SchoolSimulation/ResultCheckup.gd": 7,
	"res://Scripts/SchoolSimulation/SchoolDay.gd": 24,
	"res://Scripts/StudentCard/StudentCardView.gd": 5,
	"res://Scripts/StudentCard/student_card.gd": 8,
	"res://Scripts/StudentList/student_list.gd": 8,
	"res://Scripts/TutorialArrow.gd": 1,
	"res://Scripts/UI/StatBar.gd": 1,
}


## True when `c` could be part of a GDScript identifier.
func _is_ident_char(c: String) -> bool:
	if c == "_":
		return true
	if c >= "0" and c <= "9":
		return true
	var lower := c.to_lower()
	return lower >= "a" and lower <= "z"


## Count non-overlapping occurrences of `needle` in `hay` that are not
## preceded by an identifier character. Without that guard "Label.new("
## would also match inside "MyCustomLabel.new(".
func _occurrences(hay: String, needle: String) -> int:
	var n := 0
	var from := 0
	while true:
		var at := hay.find(needle, from)
		if at == -1:
			return n
		if at == 0 or not _is_ident_char(hay[at - 1]):
			n += 1
		from = at + needle.length()
	return n


## How many visual nodes this source text builds at runtime. Whole-line
## comments are skipped, so documenting a call site does not count as making
## one.
func _count_runtime_visuals(src: String) -> int:
	var total := 0
	for raw in src.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		for type_name in VISUAL_TYPES:
			total += _occurrences(line, type_name + ".new(")
	return total


## Every res:// path under `root` ending in `suffix`.
func _all_files_under(root: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(suffix):
				out.append(dir.path_join(f))
	return out


## { script_path: count } for every non-exempt script that builds at least
## one visual node at runtime.
func _scan() -> Dictionary:
	var out := {}
	for path in _all_files_under("res://Scripts", ".gd"):
		if EXEMPT.has(path):
			continue
		var n := _count_runtime_visuals(FileAccess.get_file_as_string(path))
		if n > 0:
			out[path] = n
	return out


## Render a scan result as a pasteable GDScript dictionary literal, so a
## failing run tells you exactly what to write.
func _as_literal(scan: Dictionary) -> String:
	var keys: Array = scan.keys()
	keys.sort()
	var lines: Array[String] = ["const BASELINE: Dictionary = {"]
	for k in keys:
		lines.append("\t\"%s\": %d," % [k, scan[k]])
	lines.append("}")
	return "\n".join(lines)


func test_no_script_builds_more_ui_at_runtime_than_its_baseline() -> void:
	var current := _scan()
	var grown: Array[String] = []
	for path in current:
		var allowed: int = int(BASELINE.get(path, 0))
		if int(current[path]) > allowed:
			grown.append("  %s: baseline %d, now %d" % [path, allowed, current[path]])
	grown.sort()
	assert_true(grown.is_empty(),
		("These scripts build more visual nodes at runtime than the baseline "
		+ "allows. Author them in a .tscn instead -- see "
		+ "docs/superpowers/design/authoring-guide.md.\n"
		+ "\n".join(grown)))


func test_baseline_is_not_stale() -> void:
	var current := _scan()
	var shrunk: Array[String] = []
	for path in BASELINE:
		var now: int = int(current.get(path, 0))
		if now < int(BASELINE[path]):
			shrunk.append("  %s: baseline %d, now %d" % [path, BASELINE[path], now])
	shrunk.sort()
	assert_true(shrunk.is_empty(),
		("The ratchet turned -- lower these in BASELINE in the same commit, or "
		+ "the improvement can silently regress later.\n"
		+ "\n".join(shrunk)
		+ "\n\nCurrent scan, paste over BASELINE:\n"
		+ _as_literal(current)))
