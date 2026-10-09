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
