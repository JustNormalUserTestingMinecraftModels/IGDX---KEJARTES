@tool
extends Control

## The grade picker: a fan of amplop coklat (brown envelopes), one per grade,
## that the player swipes through and opens like an assignment. It replaced
## CutScene's runtime-built "PILIH TINGKAT KELAS" modal. Presentation only:
## it sets GameState's grade and hands off, with no gameplay or balance change.
## Spec: docs/superpowers/specs/2026-09-25-amplop-level-select-design.md.
##
## Flow decisions (plan Task 0, resolved 2026-09-25):
## - Placement: MainMenu wipes here while the picker is on
##   (is_enabled(): the game is beaten, or the persisted Debug Level Select
##   toggle is on), else straight to CutScene. On accept this screen wipes
##   into CutScene, which then plays the intro as before.
## - Roster size: real, StudentCard's max_approve_for() (2/3/4); read, not copied.
## - Grade setter: GameState.set_grade() exists and is what CutScene used.
##
## @tool so the MCP test suite can stand the scene up; runtime-only side
## effects are gated behind Engine.is_editor_hint() in _ready().

const _STUDENT_CARD := preload("res://Scripts/StudentCard/student_card.gd")

## The three playable grades, left to right in the fan.
const GRADES: Array[int] = [7, 8, 9]

## Presentational difficulty word per grade, shown INSTEAD of the raw target
## number so the player weighs the challenge by feel. Honest because study
## days needed vs. days given tightens each grade (about 50%, 32%, 25% rest
## slack; per-day study points drop 3.0/2.5/2.0 while the target climbs).
## Rationale in the spec, section 4.
const DIFFICULTY_WORD := {7: "santai", 8: "menantang", 9: "susah"}

## Gauge fill fraction (0..1) matching DIFFICULTY_WORD. The colour climbs
## state_success, state_warning, state_danger with it (see _gauge_color).
const DIFFICULTY_FILL := {7: 0.50, 8: 0.68, 9: 0.75}

## The briefing card's tag pill per grade.
const TAG_TEXT := {7: "Ramah pemula", 8: "Menengah", 9: "Ujian akhir"}

## The surat tugas's closing sentence per grade, after the pupil and week
## counts. Never the raw target number -- the mystery is intentional.
const BRIEF_FLAVOR := {
	7: "Target paling ringan, cocok untuk memulai.",
	8: "Targetnya naik jauh; waktumu makin sempit.",
	9: "Target tertinggi, hampir tanpa jeda istirahat.",
}


## Weeks a grade runs -- the player's available time. Owned by Balance.gd.
static func weeks_for(grade: int) -> int:
	match grade:
		8: return Balance.JUMLAH_MINGGU_KELAS_8
		9: return Balance.JUMLAH_MINGGU_KELAS_9
		_: return Balance.JUMLAH_MINGGU_KELAS_7


## Points each subject must gain to clear a target. Owned by Balance.gd.
static func target_for(grade: int) -> int:
	match grade:
		8: return int(Balance.TARGET_KENAIKAN_KELAS_8)
		9: return int(Balance.TARGET_KENAIKAN_KELAS_9)
		_: return int(Balance.TARGET_KENAIKAN_KELAS_7)


## How many pupils the grade's roster holds -- StudentCard's own count.
static func roster_size_for(grade: int) -> int:
	return _STUDENT_CARD.max_approve_for(grade)
