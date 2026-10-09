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
