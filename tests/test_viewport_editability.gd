@tool
extends McpTestSuite

## Ratchet on runtime UI construction.
##
## The project's quality-of-life rule is that a human must be able to open a
## .tscn, see every sprite/panel/label, select it and change it. Anything a
## script builds with `SomeControl.new()` at runtime is invisible in the
## editor: it cannot be selected, moved, re-themed or previewed.
##
## This suite does not forbid runtime construction outright. It freezes the
## count per file (in BASELINE, still debt, or ALLOWED, a permanent
## documented exception -- see each constant's own comment) and fails if any
## file grows past its own count. When a conversion legitimately lowers a
## BASELINE file's count the second test fails and prints the exact literal
## to paste back in. That is the ratchet: it only turns one way.
##
## 2026-08-31's 21-task pass converted the extraction-worthy shared UI
## (popups, cards, rows, panels duplicated across 2-3 screens) but did not
## attempt every remaining file -- BASELINE still carries real, substantial,
## unconverted call sites (atur_jadwal.gd's 17, cut_scene.gd's 15,
## Pengaturan.gd's 12, MinigameTutorial.gd's 12, and others). This is
## deliberately still a ratchet, not a closed rule: see "Known gaps" in
## docs/superpowers/design/authoring-guide.md for the full remaining list
## and what each one would need.
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

## Per-file count of runtime visual construction still owed a conversion,
## frozen 2026-08-31 (last updated 2026-08-31 Task 21). Lower these as
## conversions land. Never raise one. See "Known gaps" in
## docs/superpowers/design/authoring-guide.md for what each one needs.
const BASELINE: Dictionary = {
	"res://Scripts/AturJadwal/atur_jadwal.gd": 17,
	"res://Scripts/CutScene/cut_scene.gd": 15,
	"res://Scripts/Inventory/inventory.gd": 4,
	"res://Scripts/Koperasi/rakbarang_1.gd": 7,
	"res://Scripts/Lobby/loby.gd": 8,
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd": 2,
	"res://Scripts/Minigames/Akademis/Password.gd": 4,
	"res://Scripts/Minigames/Akademis/Variabel.gd": 4,
	"res://Scripts/Minigames/Olahraga/Badminton.gd": 8,
	"res://Scripts/Minigames/Olahraga/MainBola.gd": 2,
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd": 8,
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd": 5,
	"res://Scripts/Minigames/UI/BaseMinigame.gd": 4,
	"res://Scripts/Minigames/UI/MinigameTutorial.gd": 12,
	"res://Scripts/Pengaturan.gd": 12,
	"res://Scripts/SchoolSimulation/BookClockWidget.gd": 0,
	"res://Scripts/SchoolSimulation/DailyDecayOverview.gd": 6,
	"res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd": 11,
	"res://Scripts/SchoolSimulation/ResultCheckup.gd": 1,
	"res://Scripts/SchoolSimulation/SchoolDay.gd": 9,
	"res://Scripts/StudentCard/StudentCardView.gd": 5,
	"res://Scripts/StudentCard/student_card.gd": 1,
	"res://Scripts/StudentList/student_list.gd": 8,
	"res://Scripts/TutorialArrow.gd": 1,
}

## Per-file count of runtime visual construction judged permanent, not
## debt -- each site builds content that is genuinely per-call dynamic
## (varies with game state, or is a conditional texture-vs-procedural
## swap already accepted elsewhere in the project, e.g. QuitConfirmDialog's
## card in Task 10), not authored layout a .tscn could hold instead.
## Reviewed 2026-08-31 Task 21. Same ratchet rules as BASELINE: never
## raise one, and lower it (or move the entry back to BASELINE) if a
## future edit makes the site static after all.
const ALLOWED: Dictionary = {
	# create_floating_text(): one-shot damage/reward-style popup text,
	# spawned at a caller-supplied position with caller-supplied text.
	"res://Scripts/AnimUtils.gd": 1,
	# _add_pill()'s chip icon+label: content and count vary per stat
	# category on every refresh() call (Wirausaha shows a money chip,
	# Istirahat shows none, etc).
	"res://Scripts/AturJadwal/ActivityRow.gd": 2,
	# _apply_visual_exports()'s icon TextureRect: only created when an
	# @export icon texture is actually supplied, in place of the emoji
	# fallback label -- the conditional texture-or-procedural swap.
	"res://Scripts/SchoolSimulation/EventAnnouncement.gd": 2,
	"res://Scripts/SchoolSimulation/EventWarning.gd": 2,
	# Answer buttons: text and shuffled order regenerate per question: not
	# fixed layout.
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd": 1,
	# _apply_visual_exports()'s overlay TextureRect: same conditional
	# texture-or-procedural swap as EventAnnouncement/EventWarning above.
	"res://Scripts/Minigames/UI/PauseMenu.gd": 1,
	# _sync_label()'s optional value-label overlay: created only when the
	# show_value_label export is toggled on for that particular bar
	# instance, not every StatBar has one.
	"res://Scripts/UI/StatBar.gd": 1,
	# _build_rows()'s six report rows: instanced from RunResultRow.tscn via
	# PackedScene.instantiate(), not a VISUAL_TYPES ".new(" call, so this
	# scan's regex does not actually count them (the entry is 0 for that
	# reason) -- registered anyway per the per-call-dynamic-content
	# exception: the row count is fixed, but every value is run-dependent,
	# and the template carries all the visual structure.
	"res://Scripts/EndGame/RunResult.gd": 0,
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
		var allowed: int = int(BASELINE.get(path, 0)) + int(ALLOWED.get(path, 0))
		if int(current[path]) > allowed:
			grown.append("  %s: allowed %d, now %d" % [path, allowed, current[path]])
	grown.sort()
	assert_true(grown.is_empty(),
		("These scripts build more visual nodes at runtime than BASELINE+ALLOWED "
		+ "permits. Author them in a .tscn instead -- see "
		+ "docs/superpowers/design/authoring-guide.md.\n"
		+ "\n".join(grown)))


func test_baseline_is_not_stale() -> void:
	var current := _scan()
	var shrunk: Array[String] = []
	for path in BASELINE:
		var now: int = int(current.get(path, 0))
		if now < int(BASELINE[path]):
			shrunk.append("  %s: baseline %d, now %d" % [path, BASELINE[path], now])
	for path in ALLOWED:
		var now: int = int(current.get(path, 0))
		if now < int(ALLOWED[path]):
			shrunk.append("  %s: allowed %d, now %d" % [path, ALLOWED[path], now])
	shrunk.sort()
	assert_true(shrunk.is_empty(),
		("The ratchet turned -- lower these in BASELINE/ALLOWED in the same "
		+ "commit, or the improvement can silently regress later.\n"
		+ "\n".join(shrunk)
		+ "\n\nCurrent scan, paste over BASELINE:\n"
		+ _as_literal(current)))
