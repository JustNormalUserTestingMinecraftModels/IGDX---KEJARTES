class_name RunGrade
extends RefCounted

## Turns a finished run into a 0-100 score and one of five ranks.
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

## Score floors for each rank, highest first. Read top-down.
##
## Five ranks, one per badge, since 2026-09-10 -- ten +/- bands could not
## be told apart on a badge that draws its own letter. Like
## MONEY_FULL_MARKS above, these floors are estimates awaiting the balance
## pass, not tuned numbers.
const LETTER_BANDS := [
	[90.0, "S"], [75.0, "A"], [60.0, "B"], [45.0, "C"],
]
const LETTER_FLOOR := "D"
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


## S and A both play the reward sting.
static func is_top_grade(letter_text: String) -> bool:
	return letter_text == "S" or letter_text == "A"
