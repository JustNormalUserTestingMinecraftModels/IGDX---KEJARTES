@tool
class_name FirstRunTutorial
extends RefCounted

## Grade 7's first-run beats on StudentCard (2026-10-07 tutorial overhaul,
## spec docs/superpowers/specs/2026-10-07-tutorial-visual-overhaul-design.md
## section 4), as data and pure helpers -- StudentCard plays them on its
## overlay, the way HeadmasterBeat holds the promotion beats.
##
## After the comic cold-open (TutorialComic), one traveling note hops the real
## bars (Kenalan), hands off to a trait pop-up and comes back (Sifat), then
## gates on Approve (Mulai). The copy is the spec's, verbatim: ask the owner
## before changing it.

## Where each field sits in a beat.
const TITLE := 0
const LINE := 1
const TARGETS := 2
const PROMPT := 3
## Each beat: [title, line, targets, prompt]. "%s" in a line is the first
## student's name; targets are comma-separated StudentCard node paths.
const STEPS := [
	["Kenalan", "Ini Mood %s. Kalau bagus, dia belajar dengan semangat; kalau habis, gampang ngambek.",
		"KertasMurid1/Mood", ""],
	["Kenalan", "Ini Energi. Tiap kegiatan menguras energi. Kalau habis, %s terpaksa izin istirahat.",
		"KertasMurid1/Energy", ""],
	["Kenalan", "Dan ini tiga skill-nya: Akademis, Seni Budaya, Olahraga. Inilah yang kamu kejar biar dia lulus.",
		"KertasMurid1/Akademis,KertasMurid1/SeniBudaya,KertasMurid1/Olahraga", ""],
	["Sifat", "%s juga punya Quirk dan Persona, sifat khasnya. Coba ketuk salah satunya.",
		"KertasMurid1/KutuBuku,KertasMurid1/KutuBuku2", "KETUK SEBUAH SIFAT"],
	["Sifat", "Nah, begitu cara baca sifat murid. Sesuaikan jadwalnya, ya!", "", ""],
	["Mulai", "Mantap! Terima dulu %s dengan Approve, lalu kita mulai minggu pertama.",
		"KertasMurid1/Aprove", "KETUK APPROVE"],
]
## The Sifat beat: it waits for a tap on a trait badge, which hands off to the
## real TraitDetailPopup (the note tucks away while it is up).
const STEP_TRAITS := 3
## The Mulai beat: it waits for a tap on Approve, which ends the tutorial.
const STEP_APPROVE := 5
## The trait badges the Sifat beat waits for, under KertasMurid1.
const TRAIT_BADGES: Array[String] = ["KutuBuku", "KutuBuku2"]


## The beats with `student_name` written into every line that names a student.
static func steps_for(student_name: String) -> Array:
	var out: Array = []
	for entry: Array in STEPS:
		var line: String = entry[LINE]
		if line.contains("%s"):
			line = line % student_name
		out.append([entry[TITLE], line, entry[TARGETS], entry[PROMPT]])
	return out


## True for a beat that waits for a real control rather than a tap anywhere.
static func is_gated(index: int) -> bool:
	return index in [STEP_TRAITS, STEP_APPROVE]


## True when `event` is a press (a touch down, or any mouse button down).
static func is_press(event: InputEvent) -> bool:
	return (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)


## The trait badges under `card` (StudentCard's KertasMurid1) the Sifat beat
## waits for; empty when there is no card or none of them is a Button.
static func trait_badges(card: Node) -> Array[Button]:
	var out: Array[Button] = []
	if card == null:
		return out
	for badge_name: String in TRAIT_BADGES:
		var badge := card.get_node_or_null(badge_name) as Button
		if badge != null:
			out.append(badge)
	return out


## True when `at` (viewport coordinates) lands on any live control in `targets`.
static func hits(targets: Array[Control], at: Vector2) -> bool:
	for target: Control in targets:
		if is_instance_valid(target) and target.get_global_rect().has_point(at):
			return true
	return false
