@tool
class_name NeedGauge
extends RefCounted

## AturJadwal's weak-stat signals (2026-09-28), fed from StatFlags over the
## projected numbers the bars show, so assigning a day can clear a signal as
## the player watches.
##
## A NEED (mood, energy) under the tiredness line wears its bar's "lelah"
## chip, which bobs gently. The single most-needed SKILL -- the one StatFlags
## flags "perlu" -- is shown instead of named: its bar gets a GapTail (a faded
## copy of that bar's own patterned fill, StatGapGhost*) over the stretch
## still to go and a pulsing TargetDot on the target end, and the NeedCallout
## bubble by the portrait says "Aku butuh <mapel>!". At most one skill is
## gauged at a time.
##
## Every node here is authored in AturJadwal.tscn; this only shows, hides,
## tints and animates them. The tail and dot are seated by
## StatBar._layout_need_gauge() from the bar's live width, never from an
## authored x. Loops are off in the editor and under Reduce Motion.

# -- Chip nudge ---------------------------------------------------------------
## How far a "lelah" chip bobs up at the top of its nudge, in px.
const FLAG_NUDGE_PX := 6.0
## Seconds for one full nudge, up and back.
const FLAG_NUDGE_SECONDS := 1.6

# -- Target dot pulse ---------------------------------------------------------
## The TargetDot's scale at the top of its pulse.
const DOT_PULSE_SCALE := 1.25
## Seconds for one full pulse, out and back.
const DOT_PULSE_SECONDS := 1.2

## How strongly the GapTail's ghost of the fill shows. Half: clearly visible
## on the dark track and plainly the same bar, yet a step quieter than the
## real fill, so the two never read as one (compared live at 0.35, 0.55 and
## against a flat tint, 2026-09-28). This is the value the game uses; the
## scene's authored alpha on each GapTail is only the editor preview.
const TAIL_ALPHA := 0.5

## The callout's line; %s is the subject's display word.
const CALLOUT_FORMAT := "Aku butuh %s!"

## Skill key -> the schedule category it grows: ObjectiveHint's own table,
## so the strip and the callout always name the same subject.
const SKILL_CATEGORY := ObjectiveHint.SKILL_CATEGORY

## Chip Label -> its running nudge tween.
var _nudges: Dictionary = {}
## The running TargetDot pulse, or null.
var _pulse: Tween = null
## The dot that pulse drives, so stopping it can restore the dot's scale.
var _pulse_dot: Control = null
## The skill key currently gauged, or "".
var _gauged := ""


## The single entry point. `flags` is StatFlags.flags_for(projected); `bars`
## maps each stat key to its StatBar (a missing or null bar is skipped).
func update(screen: Control, flags: Dictionary, bars: Dictionary, tokens: DesignTokens) -> void:
	_update_need_chips(screen, flags, bars)
	var skill := ""
	for key: String in SKILL_CATEGORY:
		if flags.get(key, "") == StatFlags.PERLU:
			skill = key
	_update_gap_markers(screen, skill, bars, tokens)
	_update_callout(screen, skill, tokens)


## Shows each need's "lelah" chip. A skill's own Flag chip stays hidden: the
## gap marker and the callout say it instead.
func _update_need_chips(screen: Control, flags: Dictionary, bars: Dictionary) -> void:
	for key: String in bars:
		var bar: Control = bars[key]
		if bar == null:
			continue
		var flag := bar.get_node_or_null("Flag") as Label
		if flag == null:
			continue
		var word: String = flags.get(key, "")
		var tired := word == StatFlags.LELAH
		var was_visible := flag.visible
		flag.visible = tired
		if not tired:
			_stop_nudge(flag)
			continue
		flag.text = word
		flag.theme_type_variation = &"StatFlagLelah"
		if not was_visible:
			_start_nudge(screen, flag)


## Shows the GapTail and TargetDot on `skill`'s bar alone, and hides them on
## the other skill bars. The tail's colour is its StatGapGhost* variation's;
## this only fades it. The dot is tinted to the skill's category.
func _update_gap_markers(screen: Control, skill: String, bars: Dictionary, tokens: DesignTokens) -> void:
	for key: String in SKILL_CATEGORY:
		var bar := bars.get(key, null) as StatBar
		if bar == null:
			continue
		var tail := bar.get_node_or_null("GapTail") as Control
		var dot := bar.get_node_or_null("TargetDot") as Control
		var on := key == skill
		if tail != null:
			tail.visible = on
			tail.self_modulate.a = TAIL_ALPHA
		if dot != null:
			dot.visible = on
			dot.self_modulate = tokens.category_color(SKILL_CATEGORY[key])
		if not on:
			continue
		bar.layout_fill_followers()
		if key != _gauged:
			_start_pulse(screen, dot)
	if skill == "":
		_stop_pulse()
	_gauged = skill


## Fills and shows the portrait's NeedCallout for `skill`, or hides it.
func _update_callout(screen: Control, skill: String, tokens: DesignTokens) -> void:
	var callout := screen.get_node_or_null("NeedCallout") as Control
	if callout == null:
		return
	callout.visible = skill != ""
	if skill == "":
		return
	var category: String = SKILL_CATEGORY[skill]
	var text := callout.get_node_or_null("Row/Text") as Label
	if text != null:
		text.text = CALLOUT_FORMAT % DayStickyNote.DISPLAY_NAMES.get(category, category)
	var icon := callout.get_node_or_null("Row/Icon") as TextureRect
	var bar_icon := screen.get_node_or_null("BGStat/Icon" + category) as TextureRect
	if icon != null and bar_icon != null:
		icon.texture = bar_icon.texture


## The chip's gentle nudge: a slow bob up and back, so a flag reads as a
## prompt without shouting.
func _start_nudge(screen: Control, flag: Label) -> void:
	if Engine.is_editor_hint() or GameSettings.reduce_motion:
		return
	_stop_nudge(flag)
	var rest_y := flag.position.y
	flag.set_meta(&"nudge_rest_y", rest_y)
	var tw := screen.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(flag, "position:y", rest_y - FLAG_NUDGE_PX, FLAG_NUDGE_SECONDS / 2.0)
	tw.tween_property(flag, "position:y", rest_y, FLAG_NUDGE_SECONDS / 2.0)
	_nudges[flag] = tw


func _stop_nudge(flag: Label) -> void:
	var tw: Tween = _nudges.get(flag, null)
	if tw != null and tw.is_valid():
		tw.kill()
	_nudges.erase(flag)
	if flag.has_meta(&"nudge_rest_y"):
		flag.position.y = flag.get_meta(&"nudge_rest_y")


## The dot's gentle grow-and-shrink, about its own centre (StatBar sets the
## pivot when it seats the dot).
func _start_pulse(screen: Control, dot: Control) -> void:
	_stop_pulse()
	if dot == null or Engine.is_editor_hint() or GameSettings.reduce_motion:
		return
	var tw := screen.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(dot, "scale", Vector2.ONE * DOT_PULSE_SCALE, DOT_PULSE_SECONDS / 2.0)
	tw.tween_property(dot, "scale", Vector2.ONE, DOT_PULSE_SECONDS / 2.0)
	_pulse = tw
	_pulse_dot = dot


## Stops the pulse and puts its dot back to rest size.
func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	if is_instance_valid(_pulse_dot):
		_pulse_dot.scale = Vector2.ONE
	_pulse = null
	_pulse_dot = null
