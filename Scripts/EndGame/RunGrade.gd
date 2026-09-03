class_name RunGrade
extends RefCounted

## Turns a finished run into a 0-100 score and a letter grade.
##
## Pure static math over a RunStats plus the roster's target tally -- no
## nodes, no GameState reads, so it is cheap to test directly. RunResult
## is the only caller.
##
## A failed run is always "D", regardless of score: the letter is the
## player's reward for winning well, not a consolation for losing.

## Weights, summing to 100. Targets dominate on purpose -- clearing every
## student's three targets is the actual win condition; the rest is style.
const WEIGHT_TARGETS := 55.0
const WEIGHT_MINIGAMES := 20.0
const WEIGHT_MONEY := 15.0
const WEIGHT_EVENTS := 10.0

## Wirausaha rupiah that earns full marks on the money component.
const MONEY_FULL_MARKS := 20000

## Score floors for each letter, highest first. Read top-down.
const LETTER_BANDS := [
	[95.0, "A+"], [88.0, "A"], [80.0, "A-"],
	[72.0, "B+"], [64.0, "B"], [56.0, "B-"],
	[48.0, "C+"], [40.0, "C"],
]
const LETTER_FLOOR := "C-"
const LETTER_FAILED := "D"


static func score(stats: RunStats, targets_cleared: int, targets_total: int,
		roster_size: int) -> float:
	if stats == null:
		return 0.0

	var target_part := 0.0
	if targets_total > 0:
		target_part = WEIGHT_TARGETS * clampf(
			float(targets_cleared) / float(targets_total), 0.0, 1.0)

	var minigame_part := WEIGHT_MINIGAMES * clampf(
		stats.minigame_win_rate(), 0.0, 1.0)

	var money_part := WEIGHT_MONEY * clampf(
		float(stats.wirausaha_money) / float(MONEY_FULL_MARKS), 0.0, 1.0)

	var event_part := 0.0
	if roster_size > 0:
		event_part = WEIGHT_EVENTS * clampf(
			float(stats.event_student_count()) / float(roster_size), 0.0, 1.0)

	return clampf(target_part + minigame_part + money_part + event_part,
		0.0, 100.0)


static func letter(run_score: float, passed: bool) -> String:
	if not passed:
		return LETTER_FAILED
	for band in LETTER_BANDS:
		if run_score >= float(band[0]):
			return String(band[1])
	return LETTER_FLOOR


static func is_top_grade(letter_text: String) -> bool:
	return letter_text.begins_with("A")
