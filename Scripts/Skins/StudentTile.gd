@tool
class_name StudentTile
extends Button

## One of the six squares in SkinSelect's rail (StudentTile.tscn; mockup
## skinselection_mockup.png, spec
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md). It shows
## a character's face, cropped out of the splash of whichever skin they are
## pending, and marks whether the rail has that character open.
##
## All six characters get a tile, not just the approved roster:
## GameState.equipped_skins is keyed by NAME, not roster id, so a skin
## follows a character across the grade change that clears the roster.
##
## The crop is the existing SkinFrame with its own border switched off --
## the box here is this Button's stylebox, and two borders on the same 150px
## square read as a smudge.
##
## @tool so the test runner can drive it; it has no side effects of its own.

## The character shown, "" before show_student().
var student_name: String = ""


## Shows `who`'s face out of skin `skin_id`'s splash. An unknown student or
## skin clears the crop rather than erroring -- layer_path returns "".
func show_student(who: String, skin_id: String) -> void:
	student_name = who
	var path := StudentSkins.layer_path(who, skin_id, "splash")
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Frame") as SkinFrame).show_art(tex, StudentSkins.bust_center(who))


## Marks this tile as the one the rail has open. A stylebox swap, never a
## resize: growing the square would re-lay the whole rail out on every
## switch, and the ring already carries the state.
func set_open(open: bool) -> void:
	theme_type_variation = &"SkinStudentTileActive" if open else &"SkinStudentTile"
