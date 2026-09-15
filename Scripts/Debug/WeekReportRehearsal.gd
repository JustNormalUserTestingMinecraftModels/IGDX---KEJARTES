@tool
class_name WeekReportRehearsal
extends RefCounted

## Debug-only jig for the weekly report (ResultCheckup). It puts a fixed
## sample week onto a throwaway StudentManager, so the report's reveal can
## be watched in one click from the debug overlay's Scenes tab instead of
## played for a school week (2026-09-15 debug-weekly-report spec).
##
## Nothing in the shipped game calls this file: DebugManager is its only
## caller, and tests/test_debug_manager.gd enforces that. It writes only to
## the manager it is handed, never to GameState. Plain static functions and
## consts, no nodes, so tests/test_week_report_rehearsal.gd can check it
## behaviourally.

## The report scene the preview opens.
const REPORT_SCENE := "res://Scenes/SchoolSimulation/ResultCheckup.tscn"

## The three skills in the card's top-to-bottom order. These are
## StudentData's own field names, so the akademis2/3 naming trap does not
## apply here.
const SKILLS := ["akademis", "seni_budaya", "olahraga"]

## Each roster slot's week, one delta per SKILLS entry. It is a ladder, so
## one press shows every beat of the reveal: all three up; two up and one
## down; one up; flat. Slots past the end repeat the last entry.
const SAMPLE_SKILL_DELTAS := [
	[12.0, 8.0, 5.0],
	[9.0, -3.0, 6.0],
	[0.0, 7.0, 0.0],
	[0.0, 0.0, 0.0],
]

## The week's energy movement, the same for everyone, so the energy bar
## travels and shows its chevron.
const SAMPLE_ENERGY_DELTA := -12.0
## The week's mood movement, the same for everyone.
const SAMPLE_MOOD_DELTA := 6.0

## The Wirausaha coins the sample week paid out.
const SAMPLE_EARNINGS := 1500

## The week's minigames and one event, in the shapes
## StudentManager.record_minigame_result / record_event_result append. Two
## minigames won and one lost (EVENT BERHASIL 2, EVENT GAGAL 1), plus a
## random event that counts in neither line but shows in Logs.
const SAMPLE_HISTORY := [
	{"day": "Senin", "category": "Akademis", "game_name": "Pilihan Ganda",
		"won": true, "score": 4, "max_score": 5, "results": []},
	{"day": "Selasa", "category": "Olahraga", "game_name": "Badminton",
		"won": false, "score": 1, "max_score": 5, "results": []},
	{"day": "Rabu", "category": "Event", "game_name": "Nasi Kotak",
		"won": true, "details": "Semua murid makan siang bersama.",
		"affected_students": []},
	{"day": "Kamis", "category": "SeniBudaya", "game_name": "Buat Batik",
		"won": true, "score": 5, "max_score": 5, "results": []},
]


## Puts the sample week onto `manager`. Each student's skills and needs move
## by their slot's deltas, measured from the Monday snapshot the manager
## took when it converted the roster, and the minigame history becomes
## SAMPLE_HISTORY. Returns the coins to hand to
## ResultCheckup.initialize_checkup(). Every stat is clamped to 0..100, as
## the simulation clamps.
static func apply_sample_week(manager: StudentManager) -> int:
	for i in manager.students.size():
		var deltas: Array = SAMPLE_SKILL_DELTAS[mini(i, SAMPLE_SKILL_DELTAS.size() - 1)]
		var s: StudentData = manager.students[i]
		for k in SKILLS.size():
			var key: String = SKILLS[k]
			s.set(key, clampf(float(s.get(key)) + float(deltas[k]), 0.0, 100.0))
		s.energy = clampf(s.energy + SAMPLE_ENERGY_DELTA, 0.0, 100.0)
		s.mood = clampf(s.mood + SAMPLE_MOOD_DELTA, 0.0, 100.0)
	manager.minigame_history.assign(SAMPLE_HISTORY.duplicate(true))
	return SAMPLE_EARNINGS
