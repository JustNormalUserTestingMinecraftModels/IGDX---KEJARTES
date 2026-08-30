class_name Juice
extends RefCounted

## The motion vocabulary. Every animation in the game goes through here
## so timing and easing stay consistent, and so a designer can retune
## the whole game's feel from design_tokens.tres.
##
## All methods are no-ops on freed or null nodes — scene changes free
## nodes mid-tween constantly and that must never produce an error.

## Set this meta on a Button to exclude it from UIPolish auto-juicing.
const NO_AUTO_JUICE := &"no_auto_juice"

static var _tokens: DesignTokens


static func tokens() -> DesignTokens:
	if _tokens == null:
		_tokens = DesignTokens.load_default()
	return _tokens


static func _alive(node: Object) -> bool:
	return node != null and is_instance_valid(node)


## Scale tweens grow from pivot_offset. Without centering, a button
## visibly slides down-right as it scales instead of pulsing in place.
static func set_pivot_center(node: Control) -> void:
	if not _alive(node):
		return
	node.pivot_offset = node.size * 0.5


static func press(node: Control) -> void:
	if not _alive(node):
		return
	var t := tokens()
	set_pivot_center(node)
	var tw := node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale",
		Vector2(t.press_scale, t.press_scale), t.dur_instant)


static func release(node: Control) -> void:
	if not _alive(node):
		return
	var t := tokens()
	set_pivot_center(node)
	var tw := node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, t.dur_fast)


static func pop_in(node: Control, delay: float = 0.0) -> void:
	if not _alive(node):
		return
	var t := tokens()
	set_pivot_center(node)
	node.scale = Vector2(0.82, 0.82)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, t.dur_normal) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)
	tw.tween_property(node, "modulate:a", 1.0, t.dur_fast) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)


static func fade_in(node: CanvasItem, delay: float = 0.0) -> void:
	if not _alive(node):
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, tokens().dur_normal) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)


## Reveal a list one item at a time. `step` defaults to tokens.stagger_step.
static func stagger_in(nodes: Array, step: float = -1.0) -> void:
	var t := tokens()
	var gap := t.stagger_step if step < 0.0 else step
	var i := 0
	for node in nodes:
		if node is Control and _alive(node):
			pop_in(node, float(i) * gap)
			i += 1


## Animate a number rolling up to its new value. Always lands exactly on
## `to` — the final tween_callback guarantees it, because float easing
## alone would leave "86" where the design says "87".
static func count_up(label: Label, from: float, to: float, fmt: String = "%d") -> void:
	if not _alive(label):
		return
	var t := tokens()
	var holder := {"v": from}
	label.text = fmt % int(round(from))
	var tw := label.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(
		func(v: float) -> void:
			if _alive(label):
				label.text = fmt % int(round(v)),
		from, to, t.dur_slow)
	tw.tween_callback(func() -> void:
		if _alive(label):
			label.text = fmt % int(round(to)))


## Animate a bar to `to`. `duration` defaults to tokens.dur_slow; pass an
## explicit one only when the fill has to stay in lockstep with something
## else that is paced by gameplay rather than by the motion tokens (the
## school day's progress bar runs beside a clock widget over a fixed
## in-fiction day length, for example). `delay` holds the bar still
## before it starts, mirroring pop_in's, so a row or stack of bars can be
## staggered without a hand-rolled timer. Returns the tween so callers
## can await it.
static func fill_bar(bar: Range, to: float, duration: float = -1.0,
		delay: float = 0.0) -> Tween:
	if not _alive(bar):
		return null
	var tw := bar.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(bar, "value", to,
		tokens().dur_slow if duration < 0.0 else duration).set_delay(delay)
	return tw


## Horizontal shake for rejection/error feedback. Returns the node to
## its exact starting position so repeated shakes never drift it.
static func shake(node: Control, strength: float = 12.0) -> void:
	if not _alive(node):
		return
	var t := tokens()
	var origin := node.position
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	var step := t.dur_normal / 6.0
	for i in range(3):
		var s := strength * (1.0 - float(i) / 3.0)
		tw.tween_property(node, "position", origin + Vector2(s, 0), step)
		tw.tween_property(node, "position", origin - Vector2(s, 0), step)
	tw.tween_property(node, "position", origin, step)
