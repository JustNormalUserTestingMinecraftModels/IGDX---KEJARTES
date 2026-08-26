extends Node

# Menyimpan scene tujuan setelah loading selesai
var next_scene: String = "res://Scene/main_menu.tscn"

# State flag ketika kembali dari student_card
var returned_from_student_card: bool = false
var approved_students: Array = []
var selected_student: Dictionary = {}
var selected_day: String = ""
var day_schedules: Dictionary = {}

var player_money : int = 0
var daily_login_day : int = 1
var last_claim_date : String = ""

func _ready():
	print("GameState siap")
