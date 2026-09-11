@tool
class_name StatCheckCard
extends Control

## One student's page in the stat check, drawn on StudentCard's own paper
## (2026-09-11): card_bg.png with its PaperShadow, the student's photo in
## the frame printed on it, the name alone on the printed brown plate, and
## three StatCheckRows wearing the stat_* icons the rest of the game uses.
## The page reads as the same sheet the player approved at the start of
## the grade.
##
## Paper is authored at the art's native 1080x1920 and scaled to fit the
## card (StatCheckCard.tscn), so every child sits at StudentCard's own
## measured coordinates and PaperShadow works unmodified.
##
## StudentCard also lists Jenis Kelamin and Tanggal Lahir under the name.
## This page deliberately shows the name only -- it is about the targets,
## not the student's file.
##
## Instanced from StatCheckCard.tscn once per student by StatCheck, which is
## a reviewed per-call-dynamic exception to the no-runtime-construction rule
## (tests/test_viewport_editability.gd ALLOWED).

@onready var name_label: Label = $Paper/Name
@onready var photo: TextureRect = $Paper/Photo
@onready var row_akademis: StatCheckRow = $Paper/Rows/Akademis
@onready var row_seni: StatCheckRow = $Paper/Rows/Seni
@onready var row_olahraga: StatCheckRow = $Paper/Rows/Olahraga


## Fill the page from a StudentData and arm its three rows. Nothing
## animates here -- StatCheck plays each row's fill() in turn.
func bind(student: StudentData) -> void:
	name_label.text = student.student_name
	photo.texture = student.avatar_texture
	row_akademis.set_result(student.akademis, student.target_akademis1)
	row_seni.set_result(student.seni_budaya, student.target_akademis2)
	row_olahraga.set_result(student.olahraga, student.target_akademis3)


## The three rows in the order the check plays them: akademis, seni
## budaya, olahraga -- the brief's order.
func rows() -> Array:
	return [row_akademis, row_seni, row_olahraga]
