# Seni Tari Beat-Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lomba Menari's arrows land on the beat of its track, from a committed beat chart, and the track fades in and out a little longer than other minigames'.

**Architecture:** A `DanceChart` resource holds bpm, first-beat offset and an explicit event list. A pure, static `DanceSync` helper turns chart + live song position into "events to spawn this frame". `LombaMenari` drives a chart cursor against `AudioDirector.get_minigame_bgm_position()` (or its own clock when no track plays) instead of the randomised `rhythm_patterns` timer, with note speed derived from the bpm. The real chart is produced offline by the team (dev-only tools ship with it); a placeholder chart keeps the game running until then.

**Tech Stack:** Godot 4.6 GDScript, `@tool` editor-bridge suites (`McpTestSuite`), an `EditorScript` importer, a dev-only Python (`librosa`) detector.

**Spec:** `docs/superpowers/specs/2026-10-09-seni-tari-beat-sync-design.md`.

## Global Constraints

- Owner decisions (2026-10-09): per-grade miss limit **stays 10 / 8 / 6** (`MISS_LIMIT_BY_DIFFICULTY`); grade difficulty otherwise comes from `target_score` only (7: 1500, 8: 2000, 9: 2500). All grades play the identical chart.
- No change to the swipe/grade/hit-window model (`grade_for_distance`, `bagus_window_px`, `sempurna_window_px`), the dancer rig, the FNF camera, or the idle breathing. `time_elapsed` **stays**: it drives the breathing motion, and `tests/test_bugfix_minigames.gd` pins it after the pause guard. Only spawning moves off it.
- No runtime beat detection; no new persistence. The chart is a committed resource.
- **Deviation from spec section 5 (forced):** `SchoolDay.gd` is at its clean-code line ceiling (1628), so the longer menari fade is a per-track default inside `AudioDirector` (`MINIGAME_BGM_FADE_BY_ID`), and the optional `fade` argument is still added to `play_minigame_bgm` for callers. SchoolDay is untouched.
- **Not on this machine:** the revised track (`seniTariRevisi.mpeg`) and any audio tooling. The track swap (spec section 5) and the real chart (section 7) are the team's steps; this plan ships the code, the tools and a placeholder chart, and logs both in `docs/superpowers/DEBT.md`.
- Every script: a `##` file header and a `##` line on every `@export` (`tests/test_script_documentation.gd`); new tunables are named `const`s (clean-code bare numbers). Tests are `@tool`, never coroutines, run via `test_run`.
- Commits: Conventional Commits with scope `menari` / `audio`.

---

## File Structure

- Create `Scripts/Minigames/SeniBudaya/DanceChart.gd` -- the resource (`class_name DanceChart`).
- Create `Scripts/Minigames/SeniBudaya/DanceSync.gd` -- pure static timing helpers (`class_name DanceSync`).
- Create `Resources/Minigames/Charts/SeniTari.tres` -- the placeholder chart.
- Modify `Scripts/Minigames/SeniBudaya/LombaMenari.gd` -- chart cursor replaces `rhythm_patterns`.
- Modify `Scripts/Audio/AudioDirector.gd` -- `get_minigame_bgm_position()`, `is_minigame_bgm_playing()`, per-id fade.
- Create `Scripts/Design/BuildDanceChart.gd` -- `EditorScript` JSON -> `.tres` importer.
- Create `tools/dance_chart/detect_beats.py` + `tools/dance_chart/README.md` -- dev-only detector.
- Tests: create `tests/test_lomba_menari_sync.gd`; extend `tests/test_audio_director.gd`.
- `docs/superpowers/DEBT.md` -- the owed chart and track.

---

### Task 1: DanceChart resource and DanceSync timing helpers

**Files:**
- Create: `Scripts/Minigames/SeniBudaya/DanceChart.gd`, `Scripts/Minigames/SeniBudaya/DanceSync.gd`
- Test: `tests/test_lomba_menari_sync.gd` (new)

**Interfaces:**
- Produces: `DanceChart` with `@export var bpm: float`, `first_beat_offset: float`, `song_length: float`, `events: Array[Dictionary]` (`{"beat": float, "type": int}`), and `func is_valid() -> bool`.
- Produces: `DanceSync.beat_to_time(beat: float, bpm: float, offset: float) -> float`, `DanceSync.note_speed_for(spawn_distance: float, bpm: float, lead_beats: float) -> float`, `DanceSync.events_due(events: Array, cursor: int, song_pos: float, travel: float, bpm: float, offset: float) -> Dictionary` returning `{"due": Array, "cursor": int}`, `DanceSync.wrapped(prev_pos: float, song_pos: float) -> bool`, `const STALE_SECONDS := 0.15`, `const WRAP_DROP_SECONDS := 0.5`.

- [ ] **Step 1: Write the failing tests** -- `tests/test_lomba_menari_sync.gd`:

```gdscript
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
```

- [ ] **Step 2: Run to verify it fails** -- `test_run(suite="lomba_menari_sync")` after `filesystem_manage(op="scan")`. Expected: the suite fails to load (`DanceSync` / `DanceChart` undefined).

- [ ] **Step 3: Implement** -- `Scripts/Minigames/SeniBudaya/DanceChart.gd`:

```gdscript
@tool
class_name DanceChart
extends Resource

## Lomba Menari's beat chart (spec 2026-10-09 section 7): the song's tempo, where
## beat 0 falls, and an explicit list of arrows, each on a (possibly fractional)
## beat. All grades play the same chart. Generated offline by
## Scripts/Design/BuildDanceChart.gd from tools/dance_chart/, then hand-tuned.

## How many arrow directions there are (LombaMenari.NoteType's size).
const NOTE_TYPE_COUNT := 4

## Song tempo in beats per minute; drives the note speed and the beat->time map.
@export var bpm: float = 100.0
## Seconds from the start of the track to beat 0.
@export var first_beat_offset: float = 0.0
## Track length in seconds; for validation only (the track loops on its own).
@export var song_length: float = 0.0
## The arrows: each {"beat": float, "type": int}, sorted by beat; `type` is a
## LombaMenari.NoteType value.
@export var events: Array[Dictionary] = []


## True when bpm is positive, events are sorted by beat, and every type is a
## known arrow.
func is_valid() -> bool:
	if bpm <= 0.0:
		return false
	var last := -INF
	for event: Dictionary in events:
		var beat: float = event.get("beat", -1.0)
		var type: int = event.get("type", -1)
		if beat < last or type < 0 or type >= NOTE_TYPE_COUNT:
			return false
		last = beat
	return true
```

`Scripts/Minigames/SeniBudaya/DanceSync.gd`:

```gdscript
@tool
class_name DanceSync
extends RefCounted

## Pure timing for Lomba Menari's beat-synced arrows (spec 2026-10-09 section 4).
## A note must land on its beat, so it spawns `travel` seconds early; the cursor
## walks the chart against the song's live position. Static and side-effect
## free, so tests drive it without a scene.

## A due event whose spawn time passed more than this many seconds ago is
## skipped, not spawned late: beats that elapsed under the 3-2-1 countdown or a
## pause are dropped instead of dumped on screen as instant misses.
const STALE_SECONDS := 0.15
## A song position this many seconds below the last frame's is a loop, not jitter.
const WRAP_DROP_SECONDS := 0.5
## Seconds in a minute, for the bpm conversions.
const SECONDS_PER_MINUTE := 60.0


## Song-time of `beat`: the offset plus that many beat periods.
static func beat_to_time(beat: float, bpm: float, offset: float) -> float:
	return offset + beat * SECONDS_PER_MINUTE / bpm


## The speed that carries a note `spawn_distance` pixels in `lead_beats` beats.
static func note_speed_for(spawn_distance: float, bpm: float, lead_beats: float) -> float:
	return spawn_distance / (lead_beats * SECONDS_PER_MINUTE / bpm)


## The events to spawn at `song_pos` and the new cursor: every event from
## `cursor` whose spawn time (its beat time minus `travel`) has come, less the
## stale ones, which are passed over.
static func events_due(events: Array, cursor: int, song_pos: float, travel: float,
		bpm: float, offset: float) -> Dictionary:
	var due: Array = []
	var at := cursor
	while at < events.size():
		var spawn_at := beat_to_time(events[at]["beat"], bpm, offset) - travel
		if spawn_at > song_pos:
			break
		if song_pos - spawn_at <= STALE_SECONDS:
			due.append(events[at])
		at += 1
	return {"due": due, "cursor": at}


## True when the song position fell back by more than WRAP_DROP_SECONDS: the
## track looped, so the chart starts over.
static func wrapped(prev_pos: float, song_pos: float) -> bool:
	return song_pos < prev_pos - WRAP_DROP_SECONDS
```

- [ ] **Step 4: Run to verify it passes** -- `filesystem_manage(op="scan")`, then `test_run(suite="lomba_menari_sync")`, `test_run(suite="script_documentation")`, `test_run(suite="clean_code")`. Expected: all PASS.

- [ ] **Step 5: Commit** -- `git add Scripts/Minigames/SeniBudaya/DanceChart.gd* Scripts/Minigames/SeniBudaya/DanceSync.gd* tests/test_lomba_menari_sync.gd* && git commit -m "feat(menari): DanceChart resource and DanceSync timing helpers"`

---

### Task 2: AudioDirector -- live position and the menari fade

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (`play_minigame_bgm`, `stop_minigame_bgm`, new methods near them)
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Produces: `AudioDirector.get_minigame_bgm_position() -> float` (latency-corrected, 0.0 when silent), `AudioDirector.is_minigame_bgm_playing() -> bool`, `play_minigame_bgm(id: StringName, fade: float = -1.0)`, `const MINIGAME_BGM_FADE_BY_ID := {&"minigame_senibudaya_menari": 1.0}`. `stop_minigame_bgm(fade := -1.0)` keeps its signature and falls back to the playing id's fade.

- [ ] **Step 1: Write the failing tests** -- append to `tests/test_audio_director.gd`:

```gdscript
## Seni Tari beat-sync (2026-10-09): the spawner reads the minigame track's live
## position, and the menari track fades longer than the 0.4 s others keep.
func test_minigame_bgm_position_api() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Audio/AudioDirector.gd")
	assert_true(src.contains("func get_minigame_bgm_position() -> float:"))
	assert_true(src.contains("AudioServer.get_time_since_last_mix()")
			and src.contains("AudioServer.get_output_latency()"),
		"the position is corrected for output latency")
	assert_true(src.contains("func is_minigame_bgm_playing() -> bool:"))
	assert_true(src.contains("func play_minigame_bgm(id: StringName, fade: float = -1.0) -> void:"))


func test_menari_fades_longer_and_others_keep_theirs() -> void:
	assert_true(AudioDirector.MINIGAME_BGM_FADE_BY_ID[&"minigame_senibudaya_menari"]
			> _director.minigame_bgm_fade, "the menari track fades longer")
	assert_false(AudioDirector.MINIGAME_BGM_FADE_BY_ID.has(&"minigame_olahraga"),
		"other tracks keep minigame_bgm_fade")
	assert_eq(_director._fade_for(&"minigame_olahraga", -1.0), _director.minigame_bgm_fade)
	assert_eq(_director._fade_for(&"minigame_senibudaya_menari", 0.2), 0.2,
		"an explicit fade wins")
```

(`_director` is the suite's existing instanced AudioDirector; check its setup at the top of the file.)

- [ ] **Step 2: Run to verify it fails** -- `test_run(suite="audio_director")`. Expected: FAIL (methods/const absent).

- [ ] **Step 3: Implement** in `AudioDirector.gd`: add beside `minigame_bgm_fade`

```gdscript
## Per-track fades, in seconds, that override minigame_bgm_fade. The revised Seni
## Tari track starts and stops over a longer swell (spec 2026-10-09 section 5);
## every other minigame keeps minigame_bgm_fade.
const MINIGAME_BGM_FADE_BY_ID := {&"minigame_senibudaya_menari": 1.0}
```

change `play_minigame_bgm(id: StringName)` to `play_minigame_bgm(id: StringName, fade: float = -1.0)` and both of its `tween_property(_bgm_minigame, "volume_db", 0.0, minigame_bgm_fade)` calls to `..., _fade_for(id, fade))`; in `stop_minigame_bgm` replace `var duration := minigame_bgm_fade if fade < 0.0 else fade` with `var duration := _fade_for(_bgm_minigame_id, fade)`; and add

```gdscript
## The fade for track `id`: an explicit `fade` (>= 0), else the track's own
## (MINIGAME_BGM_FADE_BY_ID), else minigame_bgm_fade.
func _fade_for(id: StringName, fade: float) -> float:
	if fade >= 0.0:
		return fade
	return MINIGAME_BGM_FADE_BY_ID.get(id, minigame_bgm_fade)


## The live playback position of the minigame track, in seconds, corrected for
## output latency so on-beat spawns line up with what the player hears. 0.0 when
## nothing plays. Read every frame by LombaMenari.
func get_minigame_bgm_position() -> float:
	if not _bgm_minigame.playing:
		return 0.0
	return _bgm_minigame.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## True while the minigame track plays (LombaMenari falls back to its own clock
## when it does not, e.g. launched from the debug overlay without SchoolDay).
func is_minigame_bgm_playing() -> bool:
	return _bgm_minigame.playing
```

- [ ] **Step 4: Run to verify it passes** -- `test_run(suite="audio_director")`, `test_run(suite="audio_coverage")`, `test_run(suite="clean_code")`. Expected: PASS.

- [ ] **Step 5: Commit** -- `git commit -m "feat(audio): minigame track position and a longer menari fade"`

---

### Task 3: LombaMenari spawns from the chart

**Files:**
- Modify: `Scripts/Minigames/SeniBudaya/LombaMenari.gd`
- Create: `Resources/Minigames/Charts/SeniTari.tres` (placeholder chart)
- Test: `tests/test_lomba_menari_sync.gd`

**Interfaces:**
- Consumes: `DanceChart`, `DanceSync.*` (Task 1), `AudioDirector.get_minigame_bgm_position()`, `is_minigame_bgm_playing()` (Task 2).
- Produces: `@export var chart: DanceChart`, `@export var lead_beats: float = 2.0`, `func _song_position(delta: float) -> float`, `func _spawn_due_beats(song_pos: float) -> void`.

- [ ] **Step 1: Write the failing tests** -- append to `tests/test_lomba_menari_sync.gd`:

```gdscript
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
```

- [ ] **Step 2: Run to verify it fails** -- `test_run(suite="lomba_menari_sync")`. Expected: the four new tests FAIL.

- [ ] **Step 3: Implement.**

(a) Create the placeholder chart through the editor (`resource_manage(op="create", params={"type": "DanceChart", "resource_path": "res://Resources/Minigames/Charts/SeniTari.tres", ...})`) or as a text `.tres` while the editor is closed: `bpm = 100.0`, `first_beat_offset = 0.0`, `song_length = 0.0`, and 64 events, one per beat from beat 2, types round-robin `0,2,3,1` (never two at once). It is a stand-in: its beats do not match any track.

(b) In `LombaMenari.gd`: delete `next_spawn_time`, `rhythm_patterns`, `active_pattern_index`, `pattern_step_index`, `_spawn_rhythm_beat()` and the three `note_speed = ...` lines in `start_minigame()` (keep the three `target_score` lines). Update the file header ("Notes spawn per rhythm_patterns" -> "Notes spawn on the beat of the track, from `chart`"). Add:

```gdscript
@export_group("Beat Sync")
## The beat chart the arrows follow (Resources/Minigames/Charts/SeniTari.tres).
## Every grade plays the same chart; only target_score differs.
@export var chart: DanceChart = preload("res://Resources/Minigames/Charts/SeniTari.tres")
## How many beats a note is on screen before it lands; note speed follows from
## the chart's bpm, so a faster song moves notes faster and they still land on
## the beat.
@export_range(0.5, 8.0, 0.25) var lead_beats: float = 2.0

## Where the chart cursor stands: the next event not yet spawned or skipped.
var _chart_cursor: int = 0
## Last frame's song position, to catch the track looping.
var _last_song_pos: float = 0.0
## The song clock used when no track plays (a standalone or debug launch).
var _own_clock: float = 0.0
```

In `start_minigame()` after the score targets: `_chart_cursor = 0`, `_last_song_pos = 0.0`, `_own_clock = 0.0`, and `note_speed = DanceSync.note_speed_for(_spawn_distance(), chart.bpm, lead_beats)`. Factor the existing `max(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.55` in `_spawn_single_note` into:

```gdscript
## How far off the hit zone's centre a note spawns, in pixels.
const SPAWN_DISTANCE_RATIO := 0.55

func _spawn_distance() -> float:
	var view := get_viewport_rect().size
	return maxf(view.x, view.y) * SPAWN_DISTANCE_RATIO
```

and use it there. In `_process`, replace the two spawn lines (`if time_elapsed >= next_spawn_time: _spawn_rhythm_beat()`) with `_spawn_due_beats(_song_position(delta))`, keeping `time_elapsed += delta` above it. Add:

```gdscript
## The song's position now: the minigame track's latency-corrected position, or
## this run's own clock when no track plays.
func _song_position(delta: float) -> float:
	_own_clock += delta
	if AudioDirector.is_minigame_bgm_playing():
		return AudioDirector.get_minigame_bgm_position()
	return _own_clock


## Spawns every chart event whose arrow must leave now to land on its beat. A
## loop of the track restarts the chart; beats that went by under the countdown
## or a pause are skipped (DanceSync.STALE_SECONDS).
func _spawn_due_beats(song_pos: float) -> void:
	if chart == null or chart.events.is_empty():
		return
	if DanceSync.wrapped(_last_song_pos, song_pos):
		_chart_cursor = 0
	_last_song_pos = song_pos
	var travel := _spawn_distance() / note_speed
	var step := DanceSync.events_due(chart.events, _chart_cursor, song_pos, travel,
			chart.bpm, chart.first_beat_offset)
	_chart_cursor = step["cursor"]
	for event: Dictionary in step["due"]:
		_spawn_single_note(event["type"])
```

- [ ] **Step 4: Run to verify it passes** -- `filesystem_manage(op="scan")`; `test_run` for `lomba_menari_sync`, `lomba_menari_timing`, `lomba_menari_misses`, `lomba_menari_arrow`, `minigame_star_rubric`, `dance_camera`, `bugfix_minigames`, `clean_code`, `script_documentation`. Expected: PASS. Then play it once: Debug overlay -> Minigames -> Lomba Menari; arrows arrive at an even pulse (placeholder 100 bpm, not yet the song's beat).

- [ ] **Step 5: Commit** -- `git commit -m "feat(menari): spawn arrows from the beat chart, not random patterns"`

---

### Task 4: The offline chart tools and the debt entry

**Files:**
- Create: `tools/dance_chart/detect_beats.py`, `tools/dance_chart/README.md`, `Scripts/Design/BuildDanceChart.gd`
- Modify: `docs/superpowers/DEBT.md`
- Test: `tests/test_lomba_menari_sync.gd`

**Interfaces:**
- Consumes: `DanceChart` (Task 1).
- Produces: `BuildDanceChart.chart_from_json(text: String) -> DanceChart` (static, testable), and the `_run()` that writes `SeniTari.tres` from `res://tools/dance_chart/beats.json`.

- [ ] **Step 1: Write the failing test** -- append:

```gdscript
func test_the_importer_turns_detected_beats_into_a_valid_chart() -> void:
	var json := '{"bpm": 120.0, "first_beat_offset": 0.5, "song_length": 90.0, "beats": [0, 1, 2, 3, 4]}'
	var chart := BuildDanceChart.chart_from_json(json)
	assert_eq(chart.bpm, 120.0)
	assert_eq(chart.first_beat_offset, 0.5)
	assert_eq(chart.events.size(), 5, "one arrow per detected beat")
	assert_true(chart.is_valid(), "sorted, round-robin types")
```

- [ ] **Step 2: Run to verify it fails** -- `test_run(suite="lomba_menari_sync")`. Expected: load failure (`BuildDanceChart` undefined).

- [ ] **Step 3: Implement.** `Scripts/Design/BuildDanceChart.gd`:

```gdscript
@tool
class_name BuildDanceChart
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
	chart.bpm = float(data.get("bpm", 100.0))
	chart.first_beat_offset = float(data.get("first_beat_offset", 0.0))
	chart.song_length = float(data.get("song_length", 0.0))
	var events: Array[Dictionary] = []
	var beats: Array = data.get("beats", [])
	for i in beats.size():
		events.append({"beat": float(beats[i]), "type": ROUND_ROBIN[i % ROUND_ROBIN.size()]})
	chart.events = events
	return chart
```

`tools/dance_chart/detect_beats.py` (dev-only; needs `pip install librosa`):

```python
"""Detect the Seni Tari track's tempo and beats for BuildDanceChart.gd.

Usage: python tools/dance_chart/detect_beats.py Assets/Audio/BGM/minigame_senibudaya_menari.mp3
Writes tools/dance_chart/beats.json: {bpm, first_beat_offset, song_length, beats}
where beats are beat indices (0, 1, 2, ...) relative to the first beat.
"""
import json
import pathlib
import sys

import librosa

path = sys.argv[1]
y, sr = librosa.load(path, sr=None, mono=True)
tempo, frames = librosa.beat.beat_track(y=y, sr=sr)
times = librosa.frames_to_time(frames, sr=sr)
bpm = float(tempo)
offset = float(times[0]) if len(times) else 0.0
period = 60.0 / bpm
beats = [round((t - offset) / period, 2) for t in times]
out = {"bpm": bpm, "first_beat_offset": offset,
       "song_length": float(librosa.get_duration(y=y, sr=sr)), "beats": beats}
target = pathlib.Path(__file__).with_name("beats.json")
target.write_text(json.dumps(out, indent=1))
print(f"{target}: {bpm:.1f} bpm, offset {offset:.3f}s, {len(beats)} beats")
```

`tools/dance_chart/README.md`: the three steps of spec section 7 (detect -> File > Run `BuildDanceChart.gd` -> hand-tune in the Inspector), the manual fallback (set `bpm`/`first_beat_offset` by ear, author `events` directly), and that `.import`'s `bpm`/`bar_beats` should be set to match.

`docs/superpowers/DEBT.md`, under "Audio and copy": one entry -- *Lomba Menari beat chart is a placeholder*: `SeniTari.tres` is 64 even arrows at 100 bpm; the revised track (`seniTariRevisi.mpeg`) has not been swapped into `bgm_minigame_senibudaya_menari`, and its chart must be generated and hand-tuned on a machine with audio tooling (`tools/dance_chart/README.md`). Until then the arrows keep an even pulse, not the song's beat.

- [ ] **Step 4: Run to verify it passes** -- scan; `test_run(suite="lomba_menari_sync")`, `script_documentation`, `clean_code`, `project_hygiene`. Expected: PASS.

- [ ] **Step 5: Commit** -- `git commit -m "feat(menari): offline beat-chart tools and the owed-chart debt entry"`

---

## Self-review

- **Spec coverage:** section 4 sync model -> Tasks 1+3 (latency-corrected position Task 2; countdown skip-ahead and pauses via `STALE_SECONDS`; loop via `wrapped`). Section 5 fades -> Task 2 (per-id default; SchoolDay unchanged, see Global Constraints); the track swap -> owed (Task 4 DEBT). Section 6 -> Task 2. Section 7 resource, importer, detector -> Tasks 1 and 4; the real chart -> owed. Section 8 -> Task 3 tests. Section 9 tests -> Tasks 1-4; kept suites run in Task 3 step 4.
- **Types:** `DanceSync.events_due(...) -> {"due", "cursor"}` used identically in Tasks 1 and 3; `chart_from_json` returns `DanceChart` (Task 1).
