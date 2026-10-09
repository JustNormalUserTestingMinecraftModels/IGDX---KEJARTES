@tool
extends McpTestSuite

## Lomba Menari beat-sync (spec 2026-10-09): the chart's beat->time map, the
## note speed derived from the song, and the per-frame cursor (normal advance,
## the countdown skip-ahead, nothing due, loop wrap). Pure helpers, so no scene.

func suite_name() -> String:
	return "lomba_menari_sync"


func test_beat_to_time_is_exact() -> void:
	assert_eq(DanceSync.beat_to_time(0.0, 120.0, 0.25), 0.25)
	assert_eq(DanceSync.beat_to_time(4.0, 120.0, 0.25), 2.25)
	assert_eq(DanceSync.beat_to_time(1.5, 60.0, 0.0), 1.5)


func test_note_speed_lands_notes_on_the_beat() -> void:
	# 2 beats of lead at 120 bpm is one second of flight.
	assert_eq(DanceSync.note_speed_for(600.0, 120.0, 2.0), 600.0)
	assert_eq(DanceSync.note_speed_for(600.0, 60.0, 2.0), 300.0)


func test_events_due_advances_and_waits() -> void:
	var events := [{"beat": 2.0, "type": 0}, {"beat": 3.0, "type": 1}]
	# 60 bpm, offset 0, 1 s of travel: beat 2 spawns at 1.0 s.
	var early := DanceSync.events_due(events, 0, 0.9, 1.0, 60.0, 0.0)
	assert_eq((early["due"] as Array).size(), 0, "nothing due before its spawn time")
	assert_eq(early["cursor"], 0)
	var on_time := DanceSync.events_due(events, 0, 1.05, 1.0, 60.0, 0.0)
	assert_eq((on_time["due"] as Array).size(), 1, "beat 2 spawns")
	assert_eq(on_time["cursor"], 1)


func test_events_long_past_are_skipped_not_dumped() -> void:
	# The countdown ran 5 s of music: both beats' spawn times are long gone.
	var events := [{"beat": 2.0, "type": 0}, {"beat": 3.0, "type": 1}, {"beat": 9.0, "type": 2}]
	var result := DanceSync.events_due(events, 0, 5.0, 1.0, 60.0, 0.0)
	assert_eq((result["due"] as Array).size(), 0, "stale beats are skipped")
	assert_eq(result["cursor"], 2, "the cursor waits on the first live beat")


func test_a_drop_in_song_position_is_a_loop() -> void:
	assert_true(DanceSync.wrapped(95.0, 0.2), "the track looped")
	assert_false(DanceSync.wrapped(10.0, 10.016), "a normal frame")
	assert_false(DanceSync.wrapped(10.0, 9.9), "a tiny jitter is not a loop")


func test_chart_validity() -> void:
	var chart := DanceChart.new()
	chart.bpm = 100.0
	chart.events = [{"beat": 1.0, "type": 0}, {"beat": 2.0, "type": 3}]
	assert_true(chart.is_valid(), "sorted events, known types, bpm > 0")
	chart.events = [{"beat": 2.0, "type": 0}, {"beat": 1.0, "type": 0}]
	assert_false(chart.is_valid(), "unsorted is invalid")
	chart.events = [{"beat": 1.0, "type": 9}]
	assert_false(chart.is_valid(), "an unknown type is invalid")
	chart.events = []
	chart.bpm = 0.0
	assert_false(chart.is_valid(), "bpm must be positive")
