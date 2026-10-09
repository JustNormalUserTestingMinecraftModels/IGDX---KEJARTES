@tool
extends EditorScript

## Dev-only: turns tools/dance_chart/beats.json (written by detect_beats.py)
## into Resources/Minigames/Charts/SeniTari.tres. Run with File > Run
## (Ctrl+Shift+X) in the editor, then hand-tune the arrows in the Inspector.
## Arrow types default to a round-robin that never puts two at once.

## Where detect_beats.py writes its output.
const JSON_PATH := "res://tools/dance_chart/beats.json"
## Where the game reads the chart (LombaMenari.chart).
const CHART_PATH := "res://Resources/Minigames/Charts/SeniTari.tres"
## The default arrow order: left, top-left, top-right, right.
const ROUND_ROBIN := [0, 2, 3, 1]


func _run() -> void:
	var chart := chart_from_json(FileAccess.get_file_as_string(JSON_PATH))
	var err := ResourceSaver.save(chart, CHART_PATH)
	print("BuildDanceChart: wrote %s (%d arrows, %.1f bpm), error %d"
			% [CHART_PATH, chart.events.size(), chart.bpm, err])


## A chart from detect_beats.py's JSON: its tempo and offset, and one arrow on
## each detected beat index, types round-robin.
static func chart_from_json(text: String) -> DanceChart:
	var data: Dictionary = JSON.parse_string(text)
	var chart := DanceChart.new()
	chart.bpm = float(data.get("bpm", chart.bpm))
	chart.first_beat_offset = float(data.get("first_beat_offset", 0.0))
	chart.song_length = float(data.get("song_length", 0.0))
	var events: Array[Dictionary] = []
	var beats: Array = data.get("beats", [])
	for i in beats.size():
		events.append({"beat": float(beats[i]), "type": ROUND_ROBIN[i % ROUND_ROBIN.size()]})
	chart.events = events
	return chart
