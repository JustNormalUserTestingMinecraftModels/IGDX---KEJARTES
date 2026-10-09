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


const MENARI_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
const CHART_PATH := "res://Resources/Minigames/Charts/SeniTari.tres"


func test_the_random_pattern_spawner_is_gone() -> void:
	var src := FileAccess.get_file_as_string(MENARI_PATH)
	for gone: String in ["rhythm_patterns", "next_spawn_time", "_spawn_rhythm_beat",
			"active_pattern_index", "pattern_step_index", "note_speed = 220.0",
			"note_speed = 270.0", "note_speed = 320.0"]:
		assert_false(src.contains(gone), "LombaMenari still carries " + gone)


func test_notes_spawn_off_the_song_position_and_the_chart() -> void:
	var src := FileAccess.get_file_as_string(MENARI_PATH)
	assert_true(src.contains("AudioDirector.get_minigame_bgm_position()"), "reads the live song")
	assert_true(src.contains("DanceSync.events_due("), "walks the chart cursor")
	assert_true(src.contains("DanceSync.note_speed_for("), "speed comes from the bpm")
	assert_true(src.contains("@export var chart: DanceChart"), "the chart is an inspector slot")


func test_grades_differ_by_score_target_only() -> void:
	var src := FileAccess.get_file_as_string(MENARI_PATH)
	for target: String in ["target_score = 1500", "target_score = 2000", "target_score = 2500"]:
		assert_true(src.contains(target), "the score target stays: " + target)
	assert_true(src.contains("MISS_LIMIT_BY_DIFFICULTY: Dictionary = { 1: 10, 2: 8, 3: 6 }"),
		"owner kept the per-grade miss limit (2026-10-09)")


func test_the_shipped_chart_is_valid() -> void:
	var chart := load(CHART_PATH) as DanceChart
	assert_true(chart != null, "the chart loads as a DanceChart")
	assert_true(chart.is_valid(), "and is sorted, typed and has a tempo")
	assert_true(chart.events.size() > 0, "and has arrows")


func test_the_importer_turns_detected_beats_into_a_valid_chart() -> void:
	var json := '{"bpm": 120.0, "first_beat_offset": 0.5, "song_length": 90.0, "beats": [0, 1, 2, 3, 4]}'
	var chart := BuildDanceChart.chart_from_json(json)
	assert_eq(chart.bpm, 120.0)
	assert_eq(chart.first_beat_offset, 0.5)
	assert_eq(chart.events.size(), 5, "one arrow per detected beat")
	assert_true(chart.is_valid(), "sorted, round-robin types")
