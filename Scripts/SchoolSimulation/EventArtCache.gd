class_name EventArtCache
extends RefCounted

## Holds every texture today's event dialogues could show, so a dialogue opens
## from the resource cache instead of decoding 1080x1920 art from disk while the
## BookClock sky is on screen. That decode was the sky's freeze when an event
## fired (2026-10-23): ~200 ms on a desktop CPU, 2-4x that in a phone or web
## build. SchoolDay fills it while nothing moves -- day one under the boot
## transition, each next day behind the day-summary popup -- and swaps it each
## day, so only one day's art is held. The art list is
## EventDialogueCatalog.art_paths_for_day().

## Seconds to wait after the day-summary popup opens before loading, so the
## decode lands after its pop-in rather than during it.
const PREFETCH_DELAY := 0.6

var _held: Array[Resource] = []


## Loads and holds the event art for day `day_index` of `days` (a weekday name
## list) for `roster`, dropping the previous day's. Out-of-range days do nothing.
func prefetch_day(roster: Array, days: Array, day_index: int) -> void:
	if day_index < 0 or day_index >= days.size():
		return
	var next: Array[Resource] = []
	for path in EventDialogueCatalog.art_paths_for_day(roster, str(days[day_index])):
		if ResourceLoader.exists(path):
			next.append(load(path))
	_held = next


## prefetch_day(), PREFETCH_DELAY seconds from now on `tree`. Callers do not
## await it: the popup keeps waiting for its tap meanwhile.
func prefetch_day_later(tree: SceneTree, roster: Array, days: Array, day_index: int) -> void:
	await tree.create_timer(PREFETCH_DELAY).timeout
	prefetch_day(roster, days, day_index)


## The resource paths held now, for tests.
func held_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for r in _held:
		out.append(r.resource_path)
	return out
