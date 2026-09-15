@tool
class_name WeekReportReveal
extends RefCounted

## The weekly report's reveal as a timeline, worked out before anything
## moves (2026-09-14 weekly-report-reveal spec). ResultCheckup hands it
## every card's three stat deltas and the three summary values, and gets
## back the ordered beats to play: when each card lands, when each row
## counts, when each number pops, when the summary lines follow and when
## the finale fires. Pure data -- no nodes and no tweens -- so the whole
## rhythm is testable without playing it (tests/test_week_report_reveal.gd).

## A card pops in, its needs bars travel, and the list scrolls to it.
const CARD := &"card"
## A stat row starts counting and filling.
const ROW_COUNT := &"row_count"
## A gaining row's number lands: punch, burst, climbing tally.
const ROW_POP := &"row_pop"
## A summary line pops in and starts counting.
const LINE := &"line"
## A non-zero summary line lands: punch and its cue.
const LINE_POP := &"line_pop"
## The confetti, when the week earned it, and the buttons.
const FINALE := &"finale"

## The pacing build() reads. ResultCheckup passes its Reveal exports under
## these keys; a key it leaves out falls back to the value here.
const DEFAULT_PACING := {
	"start": 0.0,
	"card_lead": 0.35,
	"count": 0.35,
	"row_gap": 0.08,
	"quiet_row": 0.15,
	"card_gap": 0.15,
	"line_gap": 0.12,
	"finale_gap": 0.2,
}


## `row_deltas`: one Array per card, its stat rows' deltas top to bottom.
## `line_values`: the summary lines' values top to bottom (coins, won, lost).
## Returns the steps in time order, each
## {at, kind, card, row, pop_index, seconds}: `row` is the stat row or the
## summary line, -1 where neither applies; `pop_index` counts pops from 0
## across stats and lines together, -1 on a non-pop; `seconds` is a count's
## length on ROW_COUNT and LINE, 0.0 on everything else.
##
## Only a gain pops. A row that did not go up settles on the short
## quiet_row beat, and a zero line arrives already reading 0: the game's
## standing rule that a flat result stays quiet.
static func build(row_deltas: Array, line_values: Array, pacing: Dictionary = {}) -> Array:
	var p: Dictionary = DEFAULT_PACING.duplicate()
	p.merge(pacing, true)
	var steps: Array = []
	var t: float = float(p["start"])
	var pops := 0
	for c in row_deltas.size():
		steps.append(_step(t, CARD, c, -1, -1, 0.0))
		t += float(p["card_lead"])
		var deltas: Array = row_deltas[c]
		for r in deltas.size():
			if float(deltas[r]) > 0.0:
				steps.append(_step(t, ROW_COUNT, c, r, -1, float(p["count"])))
				t += float(p["count"])
				steps.append(_step(t, ROW_POP, c, r, pops, 0.0))
				pops += 1
				t += float(p["row_gap"])
			else:
				steps.append(_step(t, ROW_COUNT, c, r, -1, float(p["quiet_row"])))
				t += float(p["quiet_row"])
		t += float(p["card_gap"])
	for i in line_values.size():
		if float(line_values[i]) != 0.0:
			steps.append(_step(t, LINE, -1, i, -1, float(p["count"])))
			t += float(p["count"])
			steps.append(_step(t, LINE_POP, -1, i, pops, 0.0))
			pops += 1
		else:
			steps.append(_step(t, LINE, -1, i, -1, 0.0))
		t += float(p["line_gap"])
	t += float(p["finale_gap"])
	steps.append(_step(t, FINALE, -1, -1, -1, 0.0))
	return steps


## The scroll offset that shows a card running top..bottom (in the list's
## own space) inside a view `view_height` tall, moving as little as it can
## from `current`: unchanged when the card is already fully shown, just far
## enough down to bring its bottom in when it hangs below, and up to its
## top when it starts above -- or when it is taller than the view.
static func scroll_to_show(top: float, bottom: float, view_height: float, current: float) -> float:
	if top < current:
		return maxf(top, 0.0)
	if bottom > current + view_height:
		return maxf(minf(top, bottom - view_height), 0.0)
	return current


static func _step(at: float, kind: StringName, card: int, row: int,
		pop_index: int, seconds: float) -> Dictionary:
	return {"at": at, "kind": kind, "card": card, "row": row,
		"pop_index": pop_index, "seconds": seconds}
