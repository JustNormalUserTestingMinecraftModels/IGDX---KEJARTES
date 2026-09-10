@tool
class_name RosterCard
extends TextureRect

## One student's paper card in the StudentList carousel. Extracted from
## four near-identical ~130-line inline subtrees (Murid1..4, about 600
## lines of student_list.tscn) so the card is authored once -- the same
## move already made for StickyNote.
##
## Instanced four times under the names Murid1..4. Those names are
## load-bearing: tests/test_student_list.gd resolves CardContainer/Murid%d
## and the tutorial's first step targets CardContainer.
##
## @tool so the Inspector and the MCP test suite see applied state, with
## every setter guarded on is_node_ready() -- StickyNote.gd's pattern.
## Every tunable is an @export on THIS root, never a property set on an
## instance's child: overrides serialise only on an instanced scene's
## root, so a value poked into a child reports success and is dropped on
## save. student_list.gd still pokes some children by name (Nama, Belum,
## Sudah, StickyNotesContainer, CardButton) -- those stay direct children.

## Shown on the Nama label.
@export var student_name: String = "":
	set(value):
		student_name = value
		if is_node_ready():
			$Nama.text = value

## The student's portrait, drawn in the taped frame.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			$PortraitFrame/Portrait.texture = value

## The student's hobby_category. Drives the specialty chip's label and
## icon; see SPECIALTY_ICONS.
@export var specialty: String = "":
	set(value):
		specialty = value
		if is_node_ready():
			_apply_specialty()

## The student's personality. Drives the persona chip and the catatan
## guru's opening line.
@export var persona: String = "":
	set(value):
		persona = value
		if is_node_ready():
			_apply_traits()

## The student's quirk. Drives the quirk chip and the catatan guru's
## closing observation.
@export var quirk: String = "":
	set(value):
		quirk = value
		if is_node_ready():
			_apply_traits()

## True once this student's week is scheduled. Swaps the Sudah stamp in
## for the Belum stamp.
@export var is_scheduled: bool = false:
	set(value):
		is_scheduled = value
		if is_node_ready():
			_apply_scheduled()


## Category icon per specialty, keyed by every spelling the data uses --
## hobby_category ships "Akademik" where the schedule normalises to
## "Akademis", and both must resolve.
##
## The team's authored art, matching the same categories on the day
## notes -- see CATEGORY_ICONS in student_list.gd. Both maps point at
## the StudentCard stat_* set so a student's specialty chip, their day
## notes and their stat rows all carry the one symbol per subject.
const SPECIALTY_ICONS := {
	"Akademis": "res://Assets/Images/StudentCard/stat_akademis.png",
	"Akademik": "res://Assets/Images/StudentCard/stat_akademis.png",
	"SeniBudaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"Seni Budaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"Olahraga": "res://Assets/Images/StudentCard/stat_olahraga.png",
	"Istirahat": "res://Assets/Images/StudentCard/stat_energy.png",
	"Wirausaha": "res://Assets/Images/UI/uang.png",
	"Libur": "res://Assets/Images/StudentCard/stat_mood.png",
}

## Opening line of the catatan guru, keyed by personality. First-draft
## Indonesian copy -- tunable here rather than buried in logic, per the
## project's tunables convention.
const CATATAN_PERSONA := {
	"Aktif": "Energinya tumpah ke mana-mana.",
	"Tekun": "Duduk paling depan, catatannya rapi.",
	"Kreatif": "Selalu punya cara sendiri.",
	"Santai": "Santai, tapi jangan diremehkan.",
	"Seni Dalam Kesunyian": "Paling tenang di kelas.",
}

## Closing observation of the catatan guru, keyed by quirk.
const CATATAN_QUIRK := {
	"Kutu Buku": "Perpustakaan sudah seperti rumah kedua.",
	"Penyendiri": "Lebih nyaman kerja sendiri daripada berkelompok.",
	"Semangat Juang": "Tidak pernah menyerah walau tertinggal.",
	"Penasaran": "Pertanyaannya sering di luar dugaan.",
	"Biang Onar": "Perlu diawasi kalau jam kosong.",
	"Pekerja Keras": "Pulang paling akhir, hampir tiap hari.",
}

## Shown when neither the persona nor the quirk resolves, so the strip is
## never blank.
const CATATAN_FALLBACK := "Belum ada catatan untuk murid ini."


## Five openers x six observations gives thirty notes from eleven
## strings. Static so it is unit-testable without instancing the scene.
static func compose_catatan(persona_name: String, quirk_name: String) -> String:
	var parts: Array[String] = []
	if CATATAN_PERSONA.has(persona_name):
		parts.append(CATATAN_PERSONA[persona_name])
	if CATATAN_QUIRK.has(quirk_name):
		parts.append(CATATAN_QUIRK[quirk_name])
	if parts.is_empty():
		return CATATAN_FALLBACK
	return " ".join(parts)


func _ready() -> void:
	$Nama.text = student_name
	$PortraitFrame/Portrait.texture = portrait_texture
	_apply_specialty()
	_apply_traits()
	_apply_scheduled()


## Glyph plus word. The chips sit on the compact SpecialtyBadgeS /
## PersonaBadgeS / QuirkBadgeS step -- font_caption over space_xs/space_md
## rather than font_title over btn_pad_v_s/space_lg -- which is what makes
## three labelled pills fit the card's 880px trait row. At the full size
## they overflowed it and clipped every label ("Akademis" -> "AKA").
func _apply_specialty() -> void:
	var chip: Button = $TraitRow/SpecialtyChip
	chip.text = specialty
	chip.tooltip_text = specialty
	if SPECIALTY_ICONS.has(specialty):
		chip.icon = load(SPECIALTY_ICONS[specialty])
	else:
		chip.icon = null


func _apply_traits() -> void:
	$TraitRow/PersonaChip.text = persona
	$TraitRow/QuirkChip.text = quirk
	$CatatanGuru/CatatanLabel.text = compose_catatan(persona, quirk)


func _apply_scheduled() -> void:
	$Belum.visible = not is_scheduled
	$Sudah.visible = is_scheduled
