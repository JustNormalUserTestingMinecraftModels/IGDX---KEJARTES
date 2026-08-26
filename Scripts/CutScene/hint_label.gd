@tool
extends Label

## @tool note: this script is now attached to CutScene's HintLabel
## ("Ketuk untuk melanjutkan"). The MCP test suite instantiates
## cut_scene.tscn from inside the editor process (see cut_scene.gd's
## header note for the full placeholder-instance explanation); without
## @tool this script would become a placeholder there and never run
## _ready(), which is harmless by itself but inconsistent with the rest
## of the scene's established pattern. The bob animation is a genuine
## runtime-only side effect -- it must never start just because a human
## opened the scene in the editor, or because a test instantiated it --
## so it is gated behind Engine.is_editor_hint(), exactly like the entry
## animations in main_menu.gd and splashscreen.gd.

var start_y: float

func _ready():
	if Engine.is_editor_hint():
		return
	start_y = position.y
	animate_bob()

func animate_bob():
	var tween = create_tween()
	tween.set_loops()  # ulang terus tanpa henti
	tween.tween_property(self, "position:y", start_y - 10, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", start_y + 10, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
