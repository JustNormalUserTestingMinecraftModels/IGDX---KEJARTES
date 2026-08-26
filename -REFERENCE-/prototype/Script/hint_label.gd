extends Label

var start_y: float

func _ready():
	start_y = position.y
	animate_bob()

func animate_bob():
	var tween = create_tween()
	tween.set_loops()  # ulang terus tanpa henti
	tween.tween_property(self, "position:y", start_y - 10, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", start_y + 10, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
