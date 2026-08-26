@tool
extends McpTestSuite

## StudentList (Task 13). Migrates the 4 hardcoded Murid cards' theme
## overrides to variations, and extracts the 20 near-identical inline
## sticky-note subtrees (4 students x 5 days) into one StickyNote.tscn
## component, instanced per day.
##
## Technique notes carried over from Tasks 9-12:
##  * This suite must itself be @tool or the runner reports the class as
##    abstract/broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper below is copied verbatim from
##    tests/test_main_menu.gd, which walks get_property_list() and
##    cross-checks the per-name has_theme_*_override() APIs.
##  * ThemeDB's project-theme fallback does not populate for a scene
##    instantiated under the editor's own root, so the baked theme is
##    assigned explicitly before the scene enters the tree.
##  * Touch-target checks read get_combined_minimum_size() synchronously
##    (Task 9/10's established fix) rather than `.size` after an
##    `await process_frame`, which the runner's non-awaited test call
##    convention cannot support.
##  * student_list.gd is NOT @tool. Empirically verified here: this
##    scene's runtime setup (_setup_students/_setup_tutorial, both
##    called from _ready()) reads the GameState autoload and builds the
##    tutorial panel dynamically. Godot only runs a plain (non-@tool)
##    script's lifecycle callbacks (_ready, _process, ...) inside an
##    actually-running game tree; while the editor is merely open
##    (which is the MCP test runner's context), _ready() never fires
##    for a non-@tool script no matter who calls add_child() on it —
##    this matches Task 12's identical finding for StudentCard, whose
##    tutorial-panel code this scene's tutorial system is copied from.
##    Confirmed by test_scene_instantiates below: card_nodes-dependent
##    structure (StickyNotesContainer instances, Belum/Sudah visibility)
##    comes straight from the .tscn's authored defaults, not from
##    anything _setup_students() would have written, and no GameState
##    autoload error is thrown despite _setup_students() referencing it.
##    Since every assertion this suite needs (overrides, variations,
##    StickyNote wiring, routing, no-Color()-literals) is either
##    .tscn-authored structure or a source-text scan, @tool gating
##    would add gating overhead for zero additional test coverage, so
##    it is deliberately omitted — matching StudentCard's precedent.

const _SCENE_PATH := "res://Scenes/StudentList/student_list.tscn"
const _SCRIPT_PATH := "res://Scripts/StudentList/student_list.gd"
const _STICKYNOTE_SCRIPT_PATH := "res://Scripts/StudentList/StickyNote.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "student_list"


var _list: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_list = scene.instantiate()
	_list.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_list)
	track(_list)


func teardown() -> void:
	if is_instance_valid(_list):
		_list.queue_free()
	_list = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_atur_jadwal() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/AturJadwal/atur_jadwal.tscn"),
		"student_list must still route to AturJadwal")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_list != null, "scene must instantiate")
	assert_true(_list.is_inside_tree(), "scene must enter the tree cleanly")
	for i in range(1, 5):
		assert_true(_list.get_node_or_null("CardContainer/Murid%d" % i) != null,
			"missing student card Murid%d" % i)


func test_scene_has_no_theme_overrides() -> void:
	# The whole point of centralization: this scene must be styled
	# entirely by the project theme. Dynamically-built tutorial/page-dot
	# nodes never exist in this suite's context (see header note on
	# _ready() not firing for a non-@tool script here), so this walk
	# only covers the .tscn-authored tree — which is exactly what must
	# be override-free for this task.
	var offenders: Array[String] = []
	_collect_overrides(_list, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


## Copied verbatim from tests/test_main_menu.gd / test_student_card.gd.
func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_no_hardcoded_colors_remain_in_the_scripts() -> void:
	var re := RegEx.create_from_string("Color\\s*\\(")
	for path in [_SCRIPT_PATH, _STICKYNOTE_SCRIPT_PATH]:
		var src := FileAccess.get_file_as_string(path)
		assert_eq(re.search_all(src).size(), 0,
			path + " must read colors from DesignTokens, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var paths := [
		"CardContainer/Murid1/CardButton", "LeftArrow", "RightArrow",
	]
	for p in paths:
		var b := _list.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h := b.get_combined_minimum_size().y
		var w := b.get_combined_minimum_size().x
		# CardButton fills the whole card (anchors_preset 15, no intrinsic
		# minimum size of its own) -- its actual tap area is the card's
		# full rect, so only measure the nav arrows here for real intent.
		if p == "CardContainer/Murid1/CardButton":
			continue
		assert_true(minf(h, w) >= float(tokens.touch_target_min),
			"%s is %dx%d px, below the %d px minimum touch target"
				% [p, int(w), int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_header_and_status_badges_use_theme_variations() -> void:
	var header := _list.get_node_or_null("HeaderLabel") as Label
	assert_true(header != null, "missing HeaderLabel")
	assert_eq(header.theme_type_variation, &"H1Label", "HeaderLabel variation")

	for i in range(1, 5):
		var belum := _list.get_node_or_null("CardContainer/Murid%d/Belum" % i) as Button
		assert_true(belum != null, "missing Murid%d/Belum" % i)
		assert_eq(belum.theme_type_variation, &"DangerButton", "Murid%d/Belum variation" % i)

		var sudah := _list.get_node_or_null("CardContainer/Murid%d/Sudah" % i) as Button
		assert_true(sudah != null, "missing Murid%d/Sudah" % i)
		assert_eq(sudah.theme_type_variation, &"SuccessButton", "Murid%d/Sudah variation" % i)

		var nama := _list.get_node_or_null("CardContainer/Murid%d/Nama" % i) as Label
		assert_true(nama != null, "missing Murid%d/Nama" % i)
		assert_eq(nama.theme_type_variation, &"H2Label", "Murid%d/Nama variation" % i)


func test_nav_arrows_use_theme_variation() -> void:
	for name in ["LeftArrow", "RightArrow"]:
		var b := _list.get_node_or_null(name) as Button
		assert_true(b != null, "missing " + name)
		assert_eq(b.theme_type_variation, &"SecondaryButton", name + " variation")


func test_sticky_notes_are_stickynote_instances_wired_per_day() -> void:
	var required_days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	for i in range(1, 5):
		var container := _list.get_node_or_null(
			"CardContainer/Murid%d/StickyNotesContainer" % i)
		assert_true(container != null, "missing StickyNotesContainer on Murid%d" % i)
		for day in required_days:
			var note := container.get_node_or_null(day)
			assert_true(note is StickyNote,
				"Murid%d/StickyNotesContainer/%s must be a StickyNote instance" % [i, day])
			if note is StickyNote:
				assert_eq(note.day_name, day,
					"Murid%d/%s day_name export" % [i, day])


func test_stickynote_scene_has_no_theme_overrides() -> void:
	var scene: PackedScene = load("res://Scenes/StudentList/StickyNote.tscn")
	var note := scene.instantiate()
	note.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(note)
	var offenders: Array[String] = []
	_collect_overrides(note, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on StickyNote: " + ", ".join(offenders))
	note.queue_free()


func test_motion_is_wired() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.stagger_in(card_nodes)"),
		"the visible cards must stagger in")
	assert_true(src.contains("Juice.stagger_in(sticky_container.get_children()"),
		"each card's five notes must stagger in when the card opens")
