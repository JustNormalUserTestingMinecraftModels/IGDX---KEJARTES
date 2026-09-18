@tool
class_name SkinSlot
extends Button

## One roster card in the skin popup (SkinSlot.tscn): the student's current
## splash in a tall SkinFrame, their name in capitals underneath. The popup
## listens to `pressed` to open this student's skin column.

## Roster name of the student shown, "" before show_student().
var student_name: String = ""


## Shows `student` (a GameState.approved_students dict) in the skin they
## wear now.
func show_student(student: Dictionary) -> void:
	student_name = str(student.get("name", ""))
	(get_node(^"Name") as Label).text = student_name.to_upper()
	var path := StudentSkins.splash_for(student)
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Frame") as SkinFrame).show_art(tex, StudentSkins.bust_center(student_name))
