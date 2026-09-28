@tool
class_name StudentTile
extends Button

## One of the six squares in SkinSelect's rail (StudentTile.tscn; mockup
## skinselection_mockup.png, spec
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md). It shows
## a character's face, cropped out of the splash of whichever skin they are
## pending, and marks whether the rail has that character open.
##
## Six tiles are authored in the rail, but SkinSelect shows only the current
## roster: it hides the rest rather than freeing them, since the rail is
## never built at runtime. GameState.equipped_skins is still keyed by NAME,
## not roster id, so a character's skin survives while their tile is hidden.
##
## The crop is the existing SkinFrame with its own border switched off --
## the box here is this Button's stylebox, and two borders on the same 150px
## square read as a smudge.
##
## A washi-tape tab and a name caption (Task 3 of
## docs/superpowers/plans/2026-09-29-skin-select-polish.md) turn the crop
## into a taped photo card; show_student sets the caption to `who`.
##
## @tool so the test runner can drive it; it has no side effects of its own.

## The character shown, "" before show_student().
var student_name: String = ""

## Cached node lookups. A plain var, not @onready alone: SkinSelect.open()
## can call show_student() on a freshly instantiated tile before it has ever
## entered the tree, when _ready (and @onready) has not run yet -- _ensure_nodes()
## re-resolves both from the scene the way PriceTag.gd's own _ensure_nodes()
## does.
var _frame: SkinFrame
@onready var _caption: Label = %Caption

## Node paths already reported missing, so a torn-up tile logs push_error
## once per path instead of on every show_student() call.
var _reported_missing_nodes: Dictionary = {}


## Shows `who`'s face out of skin `skin_id`'s splash and the caption under
## it. An unknown student or skin clears the crop rather than erroring --
## layer_path returns "".
func show_student(who: String, skin_id: String) -> void:
	_ensure_nodes()
	student_name = who
	var path := StudentSkins.layer_path(who, skin_id, "splash")
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	if _frame != null:
		_frame.show_art(tex, StudentSkins.bust_center(who))
	if _caption != null:
		_caption.text = who


## Resolves Frame and Caption when show_student runs before _ready -- see
## the doc on _frame/_caption above. A still-missing node gets a push_error,
## once per node name.
func _ensure_nodes() -> void:
	if not is_instance_valid(_frame):
		_frame = get_node_or_null(^"Frame") as SkinFrame
		if not is_instance_valid(_frame):
			_report_missing_node("Frame")
	if not is_instance_valid(_caption):
		_caption = get_node_or_null(^"%Caption") as Label
		if not is_instance_valid(_caption):
			_report_missing_node("Caption")


## push_error, once per node path -- see _ensure_nodes()'s doc.
func _report_missing_node(node_path: String) -> void:
	if _reported_missing_nodes.has(node_path):
		return
	_reported_missing_nodes[node_path] = true
	push_error("StudentTile: %s node missing" % node_path)


## Marks this tile as the one the rail has open. A stylebox swap, never a
## resize: growing the square would re-lay the whole rail out on every
## switch, and the ring already carries the state.
func set_open(open: bool) -> void:
	theme_type_variation = &"SkinStudentTileActive" if open else &"SkinStudentTile"
