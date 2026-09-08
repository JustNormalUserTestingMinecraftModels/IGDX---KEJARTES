@tool
extends McpTestSuite

## 2026-09-08 clarity fix: a tired EventStudentCard was already disabled
## and unselectable, but read identically to a fresh, sendable card --
## nothing visually marked it as unavailable. set_selectable(false) now
## also dims the whole card (modulate.a) and desaturates the avatar so
## "you cannot pick this student" is visible at a glance, not just
## discoverable by tapping and getting no response.

const CARD := preload("res://Scenes/SchoolSimulation/EventStudentCard.tscn")

func suite_name() -> String:
	return "event_student_card_tired"


func _make_student(tired: bool) -> StudentData:
	var s := StudentData.new()
	s.student_name = "Test"
	s.energy = 3.0 if tired else 80.0
	s.mood = 60.0
	return s


func test_tired_card_is_greyed_out() -> void:
	var card := CARD.instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.setup(_make_student(true), "Akademis")
	assert_true(absf(card.modulate.a - 0.55) <= 0.01,
		"Tired card should be visibly dimmed")


func test_fresh_card_full_opacity() -> void:
	var card := CARD.instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.setup(_make_student(false), "Akademis")
	assert_eq(card.modulate.a, 1.0,
		"A sendable card must render at full opacity")
