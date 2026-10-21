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
## gates on Approve (Mulai). One nudge line per beat (Voice B, spec 2026-10-16,
## owner-approved 2026-10-18), KBBI-standard: ask the owner
## before changing it.

## Where each field sits in a beat.
const TITLE := 0
const LINE := 1
const TARGETS := 2
const PROMPT := 3
## Each beat: [title, line, targets, prompt]. "%s" in a line is the first
## student's name; targets are comma-separated StudentCard node paths.
const STEPS := [
	["Kenalan", "Mood bagus membuat %s semangat belajar; kalau habis, dia mudah merajuk.",
		"KertasMurid1/Mood", ""],
	["Kenalan", "Kalau energinya habis, %s terpaksa izin istirahat.",
		"KertasMurid1/Energy", ""],
	["Kenalan", "Tiga kemampuan inilah yang harus kamu kejar agar dia lulus.",
		"KertasMurid1/Akademis,KertasMurid1/SeniBudaya,KertasMurid1/Olahraga", ""],
	["Sifat", "Ketuk salah satu sifat %s untuk mengenal wataknya.",
		"KertasMurid1/KutuBuku,KertasMurid1/KutuBuku2", "KETUK SEBUAH SIFAT"],
	["Sifat", "Begitulah cara membaca sifat murid. Sesuaikan jadwalnya!", "", ""],
	["Mulai", "Terima %s dengan APPROVE, lalu kita mulai minggu pertama.",
		"KertasMurid1/Aprove", "KETUK APPROVE"],
]
## Pak Kepsek's face for each beat in STEPS, index for index
## (TutorialPanel.Face): warm for the stat tour, stern for the trait
## rule he wants obeyed, proud once the player has done it.
const EXPRESSIONS := [
	TutorialPanel.Face.SENANG, TutorialPanel.Face.SENANG,
	TutorialPanel.Face.SERIUS, TutorialPanel.Face.SERIUS,
	TutorialPanel.Face.BANGGA, TutorialPanel.Face.BANGGA,
]
## The grade whose first run these beats teach; grades 8 and 9 get the
## promotion beats (HeadmasterBeat) and the pick TUGAS instead.
const GRADE := 7
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


## Pak Kepsek's face for beat `index`; SENANG past the end of the table.
static func expression_for(index: int) -> TutorialPanel.Face:
	if index < 0 or index >= EXPRESSIONS.size():
		return TutorialPanel.Face.SENANG
	return EXPRESSIONS[index]


## Dresses `panel` for StudentCard's step `index` in `grade`: grade 7's first
## run wears the beat's face; grade 8/9's lone pick a stern face. The Nota
## Guru look itself is every card's since 2026-10-18.
static func dress(panel: TutorialPanel, index: int, grade: int) -> void:
	var first_run := grade == GRADE
	panel.expression = expression_for(index) if first_run else TutorialPanel.Face.SERIUS


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
