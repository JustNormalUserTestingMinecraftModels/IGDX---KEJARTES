class_name StudentSkins
extends RefCounted

## The skin catalog: which skins each of the six characters has, and where
## each skin's four art layers live. Static -- the equipped skin and lock
## state are GameState's (equipped_skin / is_skin_unlocked).
##
## Paths follow a convention instead of a table, so adding "skin2" for a
## student is: drop four PNGs in Assets/Images/Skins/<Name>/ and append the id
## to SKINS. test_student_skins checks every resulting path exists.
##
## Every screen that turns a student into a picture asks this script
## (splash_for / portrait_for / face_base_for / hand_for) instead of reading
## the roster dict's "splash" / "portrait" keys, which always keep the base
## art. The end-of-grade result screens (WinStage, WinLineup, RunResult) use
## their own win art and do not ask.

## The id of each student's original look. Always first, never locked.
const DEFAULT_ID := "default"
## The four art layers a skin replaces.
const LAYERS: Array[String] = ["splash", "portrait", "face_base", "hand"]
## Skin ids per student, in display order.
const SKINS: Dictionary = {
	"Andi": ["default", "skin1"],
	"Citra": ["default", "skin1"],
	"Doni": ["default", "skin1"],
	"Marcel": ["default", "skin1"],
	"Shinta": ["default", "skin1"],
	"Thea": ["default", "skin1"],
}
## The six characters, in SKINS order.
const NAMES: Array[String] = ["Andi", "Citra", "Doni", "Marcel", "Shinta", "Thea"]
## Whether a non-default skin starts unlocked. Every shipped skin does until
## there is a way to earn one; the debug overlay can lock them all.
const UNLOCKED_BY_DEFAULT := true
## Head centre in splash pixels (1080x1920 canvas), for the bust crops.
## A skin shares its student's registration, so one point per student.
const BUST_CENTERS: Dictionary = {
	"Andi": Vector2(500, 340),
	"Citra": Vector2(540, 360),
	"Doni": Vector2(500, 380),
	"Marcel": Vector2(500, 380),
	"Shinta": Vector2(460, 400),
	"Thea": Vector2(520, 340),
}
## Bust centre for a name not in BUST_CENTERS: upper middle of the canvas.
const FALLBACK_BUST_CENTER := Vector2(540, 380)


static func skins_for(student_name: String) -> Array[String]:
	var out: Array[String] = []
	for id in SKINS.get(student_name, []):
		out.append(String(id))
	return out


static func has_skin(student_name: String, id: String) -> bool:
	return skins_for(student_name).has(id)


## The res:// path of one layer of one skin, or "" when the student, skin or
## layer is unknown.
static func layer_path(student_name: String, id: String, layer: String) -> String:
	if not has_skin(student_name, id) or not LAYERS.has(layer):
		return ""
	var lower := student_name.to_lower()
	if id == DEFAULT_ID:
		match layer:
			"splash": return "res://Assets/Images/SplashArtMurid/splash_%s.png" % lower
			"portrait": return "res://Assets/Images/MuridPotrait/%s.png" % student_name
			"face_base": return "res://Assets/Images/MuridPotrait/%s/%s_base.png" % [student_name, lower]
			"hand": return "res://Assets/Images/MuridPotrait/TanganItems/%s_Table.png" % student_name
	var folder := "res://Assets/Images/Skins/%s/" % student_name
	match layer:
		"splash": return folder + "splash_%s_%s.png" % [lower, id]
		"portrait": return folder + "%s_portrait_%s.png" % [lower, id]
		"face_base": return folder + "%s_base_%s.png" % [lower, id]
		"hand": return folder + "%s_table_%s.png" % [lower, id]
	return ""


## The splash to show for a roster dict: the equipped skin's, else the
## dict's own "splash".
static func splash_for(student: Dictionary) -> String:
	return _resolve(student, "splash")


## The flat portrait to show for a roster dict: the equipped skin's, else the
## dict's own "portrait".
static func portrait_for(student: Dictionary) -> String:
	return _resolve(student, "portrait")


## The equipped skin's face-rig Base layer, or "" to keep the rig's own.
static func face_base_for(student_name: String) -> String:
	return _equipped_layer(student_name, "face_base")


## The equipped skin's desk-hands art, or "" to keep the scene's own.
static func hand_for(student_name: String) -> String:
	return _equipped_layer(student_name, "hand")


static func bust_center(student_name: String) -> Vector2:
	return BUST_CENTERS.get(student_name, FALLBACK_BUST_CENTER)


static func _resolve(student: Dictionary, layer: String) -> String:
	var path := _equipped_layer(str(student.get("name", "")), layer)
	return path if path != "" else str(student.get(layer, ""))


static func _equipped_layer(student_name: String, layer: String) -> String:
	var id: String = GameState.equipped_skin(student_name)
	if id == DEFAULT_ID:
		return ""
	return layer_path(student_name, id, layer)
