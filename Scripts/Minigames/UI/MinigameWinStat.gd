@tool
class_name MinigameWinStat
extends HBoxContainer

## One stat on the minigame win screen (MinigameWinStat.tscn; 2026-09-25
## spec): the stat's icon with the gold chevron over its corner on a gain, and
## the signed number beside it. set_stat() fills it; reveal() pops the icon in
## first and then counts the number up from zero. The win screen holds two,
## the skill and energy.

@onready var icon_box: Control = $IconBox
@onready var icon: TextureRect = $IconBox/Icon
@onready var chevron: TextureRect = $IconBox/Chevron
@onready var value: Label = $Value

## The delta set_stat() last wrote: what reveal() counts up to.
var _delta: float = 0.0


## "+8" / "-5" / "+0": the sign always shows, the number is rounded.
static func format_delta(d: float) -> String:
	var n := int(round(d))
	return ("+%d" % n) if n >= 0 else ("%d" % n)


## Show `tex` and `delta` at rest. The chevron shows only on a gain.
func set_stat(tex: Texture2D, delta: float) -> void:
	_delta = delta
	icon.texture = tex
	chevron.visible = DaySummaryStatRow.shows_chevron(delta)
	value.text = format_delta(delta)


## The chip's turn in the reveal: the icon (with its chevron) pops in, then
## the number counts 0 -> delta over `count_time`. Returns when it lands.
func reveal(count_time: float) -> void:
	value.modulate.a = 1.0
	var pop := Juice.pop_in(icon_box)
	if pop != null:
		await pop.finished
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"tally")
	var count := Juice.count_up_formatted(value, 0.0, _delta, format_delta, 0.0, count_time)
	if count != null:
		await count.finished
