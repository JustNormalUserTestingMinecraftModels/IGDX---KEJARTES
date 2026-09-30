@tool
class_name HeadmasterBeat
extends RefCounted

## The headmaster's congratulation on a promotion: a short run of cards on the
## shared TutorialPanel in its name-plate mode (Pak Kepala Sekolah speaks), one
## card per tap. It is a story beat every promotion earns, not a lesson, so it
## is not a tutorial step and never reads the tutorial toggle. StudentCard owns
## the overlay, the card and the tap; this owns the lines and their order, and
## the roster-pick instruction that follows them.
## Design: docs/superpowers/specs/2026-09-30-tutorial-unify-and-headmaster-beat-design.md,
## section 4.

## Emitted once the last card has left the screen.
signal finished

## The name plate on every card.
const SPEAKER := "Pak Kepala Sekolah"
## What a card's prompt says.
const PROMPT := "KETUK MANA SAJA UNTUK LANJUT"
## The congratulation on entering a grade, keyed by that grade (Kelas 7 has
## none: nobody is promoted into it). Each line is one card, its title and its
## body, played in order.
const HEADMASTER_BEATS := {
	8: [
		{"title": "Selamat, naik ke Kelas 8!", "body": "Kerja bagusmu membimbing murid-murid Kelas 7 membuahkan hasil. Namun perjuangan belum usai."},
		{"title": "Tantangan baru", "body": "Kurikulum Kelas 8 lebih menantang. Untuk menyeimbangkan kelas, kita kedatangan murid baru."},
	],
	9: [
		{"title": "Naik ke Kelas 9!", "body": "Murid-muridmu kini di jenjang akhir. Inilah tahun penentuan kelulusan mereka."},
		{"title": "Persiapan ujian akhir", "body": "Ujian nasional sudah dekat. Kita butuh satu murid lagi agar kelasmu genap empat."},
	],
}

## A promotion's one real instruction -- which new student to pick -- by grade:
## a tutorial step shaped like StudentCard's grade-7 table (title, text, target,
## prompt). It follows the beat, and shows only while tutorials are on.
const PICK_STEPS := {
	8: ["Pilih Murid Tambahan", "Silakan pilih 1 murid tambahan dari kartu yang tersedia untuk melengkapi kelasmu menjadi 3 murid. Murid lama tidak bisa diganti.", "", ""],
	9: ["Pilih Murid Terakhir", "Pilihlah murid terakhir dari kartu yang tersisa untuk melengkapi kelasmu menjadi 4 murid. Persiapkan mereka untuk kelulusan!", "", ""],
}

var _panel: TutorialPanel
var _place: Callable
var _lines: Array = []
var _grade := 0
var _seen: Dictionary = {}
var _index := 0
var _playing := false
var _entered := false


## True when `grade` has a congratulation that `seen` -- the grades whose beat
## has already played, GameState.headmaster_beats_seen -- does not hold yet.
static func is_due(grade: int, seen: Dictionary) -> bool:
	return HEADMASTER_BEATS.has(grade) and not seen.has(grade)


## True from start() until the last card has left: taps belong to the beat.
func is_playing() -> bool:
	return _playing


## Begins `grade`'s beat on `panel`. `place` is the caller's coroutine that
## seats the card after its text has changed size; the card is kept unseen
## until the first one is seated, then springs in. When the beat ends it marks
## `grade` in `seen` (GameState.headmaster_beats_seen) and emits `finished`.
func start(panel: TutorialPanel, grade: int, place: Callable, seen: Dictionary) -> void:
	_panel = panel
	_place = place
	_grade = grade
	_seen = seen
	_lines = HEADMASTER_BEATS[grade]
	_index = 0
	_playing = true
	_entered = false
	_panel.modulate.a = 0.0
	_show_line()


## A tap: the next card or, after the last, the card springs out and the beat
## ends. A tap while the last card is leaving does nothing.
func advance() -> void:
	if _index >= _lines.size():
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	await _panel.play_out().finished
	_playing = false
	_seen[_grade] = true
	finished.emit()


## Puts the current line on the card and seats it. The card springs in once,
## when the first line is seated; later lines change in place, as a tutorial
## step does.
func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_panel.show_beat(SPEAKER, line["title"], line["body"], PROMPT)
	await _place.call()
	if not _entered and is_instance_valid(_panel):
		_entered = true
		_panel.play_in()
