@tool
extends RefCounted

## SchoolDay's own picture on layer 0 -- the sky, the book clock, the weather
## and the day's stamp and fireworks -- faded out while a hosted screen lit
## the Lobby way is up (2026-09-30 minigame lobby-light pass). Such a screen
## (EventDialogue, every minigame) keeps its art on a `World` CanvasLayer at
## -1 under its own WorldEnvironment, which draws BELOW SchoolDay's layer 0,
## so the picture has to step aside for it to show.
##
## Counted: two hosted screens that overlap each cover once and uncover once,
## and the picture only comes back when the last one closes. Each node's own
## alpha is remembered (the motes sit at 0.45), never assumed to be 1.

## The picture's nodes, as paths from SchoolDay's root.
const DAY_PICTURE: Array[NodePath] = [^"Background", ^"BookClockWidget", ^"Rain",
	^"Motes", ^"DayStamp", ^"WeekFireworks"]
## Seconds the picture takes to fade around a minigame, matching the
## minigame's own 0.4 s fade so the two cross.
const FADE := 0.4

## How many hosted screens are covering the day right now.
var covers: int = 0
## The screen whose picture this covers.
var _host: Node
## Each picture node's own alpha while covered, put back by uncover().
var _alpha: Dictionary = {}


## `host` is the SchoolDay the DAY_PICTURE paths are read from.
func _init(host: Node) -> void:
	_host = host


## Fades the picture out, remembering each node's alpha. With a `tween` the
## fade runs alongside the caller's own; with null it is instant.
func cover(tween: Tween) -> void:
	covers += 1
	if covers > 1:
		return
	for path in DAY_PICTURE:
		var item := _host.get_node_or_null(path) as CanvasItem
		if item == null:
			continue
		_alpha[item] = item.modulate.a
		_fade(item, 0.0, tween)


## Brings the picture back to the saved alphas, the same way. Only the last
## open cover does; an uncover with nothing covered does nothing.
func uncover(tween: Tween) -> void:
	if covers == 0:
		return
	covers -= 1
	if covers > 0:
		return
	for item in _alpha:
		if is_instance_valid(item):
			_fade(item as CanvasItem, _alpha[item], tween)
	_alpha.clear()


## Sets `item`'s alpha at once, or tweens it alongside `tween`.
func _fade(item: CanvasItem, alpha: float, tween: Tween) -> void:
	if tween == null:
		item.modulate.a = alpha
	else:
		tween.tween_property(item, "modulate:a", alpha, FADE)
