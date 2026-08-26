extends Control

var already_clicked = false

func _input(event):
	if already_clicked:
		return
	if event is InputEventScreenTouch and event.pressed:
		go_to_loading()
	elif event is InputEventMouseButton and event.pressed:
		go_to_loading()

func go_to_loading():
	already_clicked = true
	GameState.next_scene = "res://Scene/main_menu.tscn"
	Transition.change_scene("res://Scene/loading.tscn")
