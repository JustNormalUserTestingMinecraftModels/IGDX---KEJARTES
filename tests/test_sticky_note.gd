@tool
extends McpTestSuite

## StickyNote's two skins (MURIDMU RosterCard Task 2, 2026-09-29): the
## `scheduled` export swaps between the filled category-tinted look and a
## kraft "plan me" empty state, plus the static washi Tape strip, the
## authored `tilt_degrees` rotation, and the empty note's looped "tap me"
## glow (`set_inviting`).
##
## test_student_list.gd already pins StickyNote's structural contract
## (no theme_override_*, five instances named Senin..Jumat, children
## anchored to scale with the note). This suite is scoped to what Task 2
## adds on top of that.
##
## Must be @tool (the runner reports a non-@tool suite as abstract/broken)
## and no test here may be a coroutine (the runner calls `suite.call(name)`
## without awaiting).

const _SCENE := "res://Scenes/StudentList/StickyNote.tscn"
const _SCRIPT := "res://Scripts/StudentList/StickyNote.gd"

var _note: StickyNote


func suite_name() -> String:
	return "sticky_note"


func setup() -> void:
	_note = (load(_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(_note)
	track(_note)


# --------------------------------------------------------------- exports

func test_scheduled_and_tilt_degrees_are_exports() -> void:
	assert_true("scheduled" in _note, "StickyNote must expose a scheduled export")
	assert_true("tilt_degrees" in _note, "StickyNote must expose a tilt_degrees export")
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("@export var scheduled: bool"),
		"scheduled must be a typed bool export")
	assert_true(src.contains("@export_range(-15.0, 15.0"),
		"tilt_degrees must be a bounded, named-range export")


# ------------------------------------------------------------- empty skin

func test_unscheduled_shows_the_empty_frame_add_icon_and_atur_label() -> void:
	_note.scheduled = false
	var frame := _note.get_node_or_null("EmptyFrame") as TextureRect
	assert_true(frame != null, "missing EmptyFrame")
	assert_true(frame.visible, "EmptyFrame must show while scheduled is false")

	var icon := _note.get_node_or_null("Icon") as TextureRect
	assert_true(icon != null, "missing Icon")
	assert_eq(icon.texture, preload("res://Assets/Images/UI/StudentList/icon_add.svg"),
		"the empty note's icon must be the + glyph")

	var label := _note.get_node_or_null("ActivityLabel") as Label
	assert_true(label != null, "missing ActivityLabel")
	assert_eq(label.text, "Atur", "the empty note's label must read Atur")
	assert_eq(label.theme_type_variation, &"StickyNoteEmptyLabel",
		"the empty note's label must wear the muted StickyNoteEmptyLabel look")


## An unset activity/icon_texture must not leak onto the empty skin, and a
## LATER activity/icon_texture write while still unscheduled must not
## clobber the "Atur"/"+" look either -- callers should not have to
## sequence `scheduled` before `activity`/`icon_texture`.
func test_unscheduled_ignores_activity_and_icon_texture_regardless_of_order() -> void:
	_note.scheduled = false
	_note.activity = "Akademis"
	_note.icon_texture = preload("res://Assets/Images/UI/StudentList/icon_calendar.svg")
	var label := _note.get_node_or_null("ActivityLabel") as Label
	assert_eq(label.text, "Atur", "activity must not overwrite the empty label")
	var icon := _note.get_node_or_null("Icon") as TextureRect
	assert_eq(icon.texture, preload("res://Assets/Images/UI/StudentList/icon_add.svg"),
		"icon_texture must not overwrite the empty icon")


func test_unscheduled_paper_is_the_kraft_surface_sunken_tone() -> void:
	_note.scheduled = false
	assert_true(_note.self_modulate.is_equal_approx(DesignTokens.load_default().surface_sunken),
		"the empty note's paper must be the flat surface_sunken kraft tone")


## Regression: EmptyFrame's own self_modulate must be set the moment a note
## goes unscheduled, not only as a side effect of set_inviting()'s glow
## lifecycle. Every note except the current front card never gets a
## set_inviting() call (spec 4.2: only the front card's empty notes glow),
## so a fresh note here deliberately never calls it either -- if EmptyFrame's
## tint only happened inside _start_glow()/_stop_glow(), this note would be
## left rendering sticky_empty_frame.svg's raw white instead of kraft.
func test_unscheduled_frame_is_tinted_kraft_without_ever_inviting() -> void:
	_note.scheduled = false
	var frame := _note.get_node_or_null("EmptyFrame") as TextureRect
	assert_true(frame != null, "missing EmptyFrame")
	assert_true(frame.self_modulate.is_equal_approx(DesignTokens.load_default().surface_sunken),
		"EmptyFrame must be tinted surface_sunken as soon as scheduled goes false, "
		+ "even if set_inviting() is never called on this note")


# ------------------------------------------------------------ filled skin

func test_scheduled_hides_the_frame_and_keeps_the_category_tint_path() -> void:
	_note.scheduled = true
	_note.activity = "Akademis"
	var frame := _note.get_node_or_null("EmptyFrame") as TextureRect
	assert_false(frame.visible, "EmptyFrame must hide while scheduled is true")

	var label := _note.get_node_or_null("ActivityLabel") as Label
	assert_eq(label.text, "Akademis", "a filled note shows its activity name")
	assert_eq(label.theme_type_variation, &"",
		"a filled note's label must not wear the muted empty variation")

	var tokens := DesignTokens.load_default()
	var expected: Color = tokens.category_color("Akademis").lerp(Color.WHITE, _note.TINT_WASH)
	assert_true(_note.self_modulate.is_equal_approx(expected),
		"a filled note's paper must still be the washed category tint")


## Regression guard for the order dependency the empty-skin tests above
## check the other way: flipping BACK to scheduled after being empty must
## restore the filled look, not strand the note on "Atur"/"+".
func test_flipping_back_to_scheduled_restores_the_filled_look() -> void:
	_note.activity = "Olahraga"
	_note.icon_texture = preload("res://Assets/Images/UI/StudentList/icon_calendar.svg")
	_note.scheduled = false
	_note.scheduled = true
	var label := _note.get_node_or_null("ActivityLabel") as Label
	assert_eq(label.text, "Olahraga", "must restore the real activity text")
	var icon := _note.get_node_or_null("Icon") as TextureRect
	assert_eq(icon.texture, preload("res://Assets/Images/UI/StudentList/icon_calendar.svg"),
		"must restore the real icon_texture")


# ------------------------------------------------------------------ tape

func test_tape_exists_and_wears_the_washi_art() -> void:
	var tape := _note.get_node_or_null("Tape") as TextureRect
	assert_true(tape != null, "missing Tape")
	assert_eq(tape.texture, preload("res://Assets/Images/AturJadwal/washi_tape.svg"),
		"Tape must use the washi tape art")
	assert_true(tape.self_modulate.a > 0.0 and tape.self_modulate.a < 1.0,
		"Tape must be translucent, not fully opaque or invisible")


func test_tape_alpha_comes_from_a_named_const() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const TAPE_ALPHA"),
		"the tape's rest alpha must be a named constant, not inline")
	assert_true(src.contains("$Tape.self_modulate.a = TAPE_ALPHA"),
		"_ready must apply TAPE_ALPHA to Tape's self_modulate alpha")


# ------------------------------------------------------------------ tilt

func test_tilt_degrees_rotates_the_root_about_its_centre() -> void:
	_note.tilt_degrees = -2.5
	assert_true(is_equal_approx(_note.rotation_degrees, -2.5),
		"tilt_degrees must drive the root's rotation_degrees")
	assert_true(_note.pivot_offset.is_equal_approx(_note.size / 2.0),
		"the rotation must pivot about the note's own centre")


# ------------------------------------------------------------ empty glow

## Tween wiring is a source scan, not a live behavioral check (the same
## technique test_day_sticky_note.gd uses for AturJadwal's empty-note
## breath): a Tween needs a processing SceneTree to observe mid-loop, which
## the MCP test bridge does not guarantee frame-by-frame, and a
## non-coroutine test cannot await one anyway.
func test_set_inviting_is_gated_and_killed_on_exit() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func set_inviting"), "empty notes need a settable glow")
	assert_true(src.contains("GameSettings.reduce_motion"),
		"the glow must honour Reduce Motion")
	assert_true(src.contains("Engine.is_editor_hint()"),
		"the glow must not run in the editor")

	var start := src.find("func _start_glow")
	assert_true(start >= 0, "missing _start_glow")
	var start_next := src.find("\nfunc ", start + 1)
	var start_body := src.substr(start, start_next - start)
	assert_true(start_body.contains("GameSettings.reduce_motion"),
		"_start_glow must check Reduce Motion before creating a Tween")

	var exit_at := src.find("func _exit_tree")
	assert_true(exit_at >= 0, "missing _exit_tree")
	var exit_next := src.find("\nfunc ", exit_at + 1)
	assert_true(src.substr(exit_at, exit_next - exit_at).contains("_stop_glow()"),
		"_exit_tree must kill the glow Tweens so nothing leaks across a card swipe")


func test_set_inviting_true_flips_scheduled_back_stops_it() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var sched_at := src.find("@export var scheduled: bool")
	var sched_next := src.find("\nvar ", sched_at + 1)
	assert_true(src.substr(sched_at, sched_next - sched_at).contains("_stop_glow()"),
		"turning scheduled back on must stop any glow left running -- a filled note is calm")


func test_is_inviting_reflects_the_last_call() -> void:
	_note.scheduled = false
	_note.set_inviting(true)
	assert_true(_note.is_inviting(), "is_inviting must reflect a prior set_inviting(true)")
	_note.set_inviting(false)
	assert_false(_note.is_inviting(), "is_inviting must reflect a prior set_inviting(false)")


func test_scheduling_an_inviting_note_clears_is_inviting() -> void:
	_note.scheduled = false
	_note.set_inviting(true)
	assert_true(_note.is_inviting(), "precondition: the empty note is inviting")
	_note.scheduled = true
	assert_false(_note.is_inviting(),
		"a filled note is calm: is_inviting must not keep reporting a dead glow")


# --------------------------------------------------------------- hygiene

func test_no_hardcoded_color_literals() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"StickyNote.gd must read colors from DesignTokens, not Color() literals")


func test_new_exports_are_documented() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for anchor in ["@export var scheduled: bool", "@export var empty_icon: Texture2D",
			"@export_range(-15.0, 15.0"]:
		var at := src.find(anchor)
		assert_true(at >= 0, "missing export: " + anchor)
		var before := src.substr(0, at)
		var last_line_start := before.rfind("\n", before.length() - 2)
		var prev_line := before.substr(last_line_start + 1).strip_edges()
		assert_true(prev_line.begins_with("##"),
			anchor + " must carry a ## doc line immediately above it")
