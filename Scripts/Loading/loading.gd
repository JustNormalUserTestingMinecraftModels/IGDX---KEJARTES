extends Control

@onready var loading_bar: ProgressBar = $LoadingBar

func _ready():
	animate_loading()

func animate_loading():
	var tween = create_tween()
	tween.tween_property(loading_bar, "value", 100, 2.0)
	tween.finished.connect(_on_loading_finished)

func _on_loading_finished():
	get_tree().change_scene_to_file(GameState.next_scene)
