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
## The fade in flight, owned here so the next cover or uncover can finish it
## first (a dev skip mid fade-in would otherwise see the fade-out win).
var _tween: Tween
## Whether the current cover or uncover fades (true) or snaps (false).
var _fading: bool = false
## A node hidden wholesale (not faded) for as long as the picture is covered:
## SchoolDay's day_screen under an event dialogue, whose featured splash sits on
## a World CanvasLayer at -1 and would otherwise show the avatar strip over it
## (2026-09-30). Its visibility and process mode are remembered here and put
## back by the matching uncover().
var _extra: CanvasItem
var _extra_visible: bool = false
var _extra_process: int = Node.PROCESS_MODE_INHERIT


## `host` is the SchoolDay the DAY_PICTURE paths are read from.
func _init(host: Node) -> void:
	_host = host


## Fades the picture out over FADE (alongside the minigame's own fade) when
## `fade`, else at once, remembering each node's alpha.
func cover(fade: bool, extra: CanvasItem = null) -> void:
	covers += 1
	if covers > 1:
		return
	_settle(fade)
	for path in DAY_PICTURE:
		var item := _host.get_node_or_null(path) as CanvasItem
		if item == null:
			continue
		_alpha[item] = item.modulate.a
		_fade(item, 0.0)
	if extra != null:
		_extra = extra
		_extra_visible = extra.visible
		_extra_process = extra.process_mode
		extra.hide()
		extra.process_mode = Node.PROCESS_MODE_DISABLED


## Brings the picture back to the saved alphas, the same way. Only the last
## open cover does; an uncover with nothing covered does nothing.
func uncover(fade: bool) -> void:
	if covers == 0:
		return
	covers -= 1
	if covers > 0:
		return
	_settle(fade)
	for item in _alpha:
		if is_instance_valid(item):
			_fade(item as CanvasItem, _alpha[item])
	_alpha.clear()
	if _extra != null and is_instance_valid(_extra):
		_extra.visible = _extra_visible
		_extra.process_mode = _extra_process
	_extra = null


## Runs any fade still in flight to its end, so what follows starts from its
## final alphas, then sets up the next call's fade.
func _settle(fade: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.custom_step(FADE)
		_tween.kill()
	_tween = null
	_fading = fade


## Sets `item`'s alpha at once, or tweens it over FADE.
func _fade(item: CanvasItem, alpha: float) -> void:
	if not _fading:
		item.modulate.a = alpha
		return
	if _tween == null:
		_tween = _host.create_tween().set_parallel(true)
	_tween.tween_property(item, "modulate:a", alpha, FADE)
