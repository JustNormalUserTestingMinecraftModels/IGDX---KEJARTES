extends Control

@onready var play_button: Button = $PlayButton
@onready var setting_button: Button = $SettingButton
@onready var quit_button: Button = $QuitButton

func _ready():
	print("MainMenu _ready called")
	play_button.pressed.connect(_on_play_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	print("MainMenu _on_play_pressed triggered!")
	Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn")

func _on_setting_pressed():
	print("Buka Setting - belum diimplementasi")

func _on_quit_pressed():
	get_tree().quit()
