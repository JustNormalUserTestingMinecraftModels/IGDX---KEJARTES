@tool
class_name StatCheckCard
extends Control

## One student's page in the stat check -- the mockup_statcheck card: a
## purple bio panel (name, profil lines), the portrait, and three
## StatCheckRows. Instanced from StatCheckCard.tscn once per student by
## StatCheck, which is a reviewed per-call-dynamic exception to the
## no-runtime-construction rule (tests/test_viewport_editability.gd ALLOWED).
##
## The mockup also shows "Tanggal Lahir"; StudentData carries no birthday,
## so the card shows Nama and whatever lines `profil` already holds
## ("Agama: …" / "Jenis Kelamin: …") and nothing invented.

@onready var nama: Label = $Paper/Header/BioPanel/Bio/Nama
@onready var profil: Label = $Paper/Header/BioPanel/Bio/Profil
@onready var portrait: TextureRect = $Paper/Header/Portrait
@onready var row_akademis: StatCheckRow = $Paper/Rows/Akademis
@onready var row_seni: StatCheckRow = $Paper/Rows/Seni
@onready var row_olahraga: StatCheckRow = $Paper/Rows/Olahraga


## Fill the card from a StudentData and arm its three rows. Nothing
## animates here -- StatCheck plays each row's fill() in turn.
func bind(student: StudentData) -> void:
	nama.text = student.student_name
	profil.text = student.profil
	portrait.texture = student.avatar_texture
	row_akademis.set_result(student.akademis, student.target_akademis1)
	row_seni.set_result(student.seni_budaya, student.target_akademis2)
	row_olahraga.set_result(student.olahraga, student.target_akademis3)


## The three rows in the order the check plays them: akademis, seni
## budaya, olahraga -- the brief's order.
func rows() -> Array:
	return [row_akademis, row_seni, row_olahraga]
