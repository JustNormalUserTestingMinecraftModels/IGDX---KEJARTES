@tool
class_name ChatBubble
extends Control

## Pak Herman's speech bubble in the Koperasi (Stage/ChatBubble in
## koprasi.tscn: a Body PanelContainer > Text RichTextLabel, plus a Tail
## TextureRect pointing down at Herman). A tiny FSM: say()/say_for_item()
## pick a line from DialogueCatalog, tween the bubble in from Herman's
## direction, hold it, then tween it back into him. say_sticky() pins a
## line (SOLD_OUT) until clear_sticky(). Per-event SAY_COOLDOWN debounces
## tap-spam -- different events are not coupled to each other.
##
## @tool because tests instantiate this script directly with a bare
## ChatBubble.new(). Every child lookup goes through get_node_or_null() so
## a bubble built without the authored Body/Text/Tail children (or with a
## hand-built minimal tree, as in tests/test_koperasi_chat_bubble.gd)
## degrades instead of crashing on a hard $Path lookup.
##
## The one-time hide (scale/modulate) and the linger timer are skipped
## while this node is part of the scene *currently open for editing* --
## gated on is_part_of_edited_scene(), not just is_editor_hint(), because
## test_run also executes inside the editor and still needs the real
## behaviour. Saving koprasi.tscn from the editor must never bake the
## shrunk/hidden pose into the file.
##
## _play()/_hide() each kill any tween still running from a previous call
## before starting their own (ADD then REMOVE within one frame, or a say()
## mid-hide, must not leave two tweens fighting over scale/modulate/
## position -- spec "Different events still interrupt normally"). The
## surviving tween's finish callback also checks it is still `_tween`
## before touching state, so even a callback that slips through a kill()
## race can never flip state on behalf of a superseded animation.
##
## set_herman_ap() hands in Stage/Herman/HermanAP so state_changed can swap
## Herman between his "talk" (SHOWING/LINGERING, including a sticky line)
## and "idle" animations. Reaching IDLE (and not sticky) also arms a
## randomised idle-chatter Timer (IDLE_MIN_S..IDLE_MAX_S) that speaks an
## IDLE line on timeout if the bubble is still idle, not sticky, and
## idle_chatter_enabled is true -- koprasi.gd resets it on Cart activity,
## and Task 5's tray wires idle_chatter_enabled to its collapsed state.

signal state_changed(state: int)

enum State { IDLE, SHOWING, LINGERING, HIDING }

const SAY_COOLDOWN := 0.12
const LINGER_S := 2.2
const FADE_IN_S := 0.32
const FADE_OUT_S := 0.28
## Bubble -> Herman, in px. The shrunk/hidden pose sits this far toward
## him from rest_position, so the bubble reads as retracting into him
## instead of fading in place.
const HERMAN_ANCHOR_OFFSET := Vector2(60.0, 40.0)
const SHRUNK_SCALE := Vector2(0.2, 0.2)
## Idle-chatter timer range, randomised each time it (re)arms.
const IDLE_MIN_S := 8.0
const IDLE_MAX_S := 14.0

## Where the bubble rests while SHOWING/LINGERING, in the parent's frame.
## Defaults to the node's authored position in koprasi.tscn (36, 23). This
## default is NOT read from the node -- it is a duplicated literal, so it
## must be kept in sync by hand if the bubble is ever repositioned in the
## scene; a mismatch would make it rest somewhere other than where it was
## placed. If you move the node, update this value too.
@export var rest_position: Vector2 = Vector2(36.0, 23.0)

## Task 5 sets this false while the basket tray is collapsed, so an idle
## Herman doesn't heckle an empty room. Checked by the idle timer's timeout
## handler, not by reset_idle_timer(): a disabled timer still counts down
## and, on timeout, simply declines to speak (_on_idle_timeout returns
## without saying a line or rearming) -- chatter is muted, not paused. It
## resumes only once koprasi.gd flips this back true AND calls
## reset_idle_timer() (on tray expand), which arms a fresh
## IDLE_MIN_S..IDLE_MAX_S window; re-enabling alone does not make it speak.
var idle_chatter_enabled: bool = true

var _state: int = State.IDLE
var _sticky: bool = false
## event (StringName) -> Time.get_ticks_msec() of the last accepted say()
## for that event, for the per-event cooldown.
var _last_say_time: Dictionary = {}
var _linger_timer: Timer
## Fires an ambient IDLE line after IDLE_MIN_S..IDLE_MAX_S of silence.
## Armed on reaching IDLE (when not sticky) and by reset_idle_timer(),
## which koprasi.gd calls on every Cart change.
var _idle_timer: Timer
## Stage/Herman/HermanAP, handed in by koprasi.gd via set_herman_ap(). Left
## null in tests that don't care about the animation side of the FSM --
## every use is guarded.
var _herman_ap: AnimationPlayer
## The Tween currently animating this bubble in or out, if any. Compared by
## reference in the finish callbacks so a killed/superseded tween's own
## callback (should one ever still fire) is a no-op instead of touching
## state on the new animation's behalf.
var _tween: Tween

@onready var _label: RichTextLabel = get_node_or_null("Body/Text") as RichTextLabel
@onready var _tail: Control = get_node_or_null("Tail") as Control


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return

	if _tail:
		# Pivot toward the tail's tip (its bottom, centred on its width) so
		# the bubble shrinks/grows into Herman rather than from its own
		# centre or a hardcoded corner. Set after the editor guard above --
		# assigning it before that return mutated the node whenever
		# koprasi.tscn was merely opened in the editor, baking pivot_offset
		# into the scene on the next save.
		pivot_offset = _tail.position + Vector2(_tail.size.x * 0.5, _tail.size.y)

	_linger_timer = Timer.new()
	_linger_timer.one_shot = true
	add_child(_linger_timer)
	_linger_timer.timeout.connect(_on_linger_timeout)

	_idle_timer = Timer.new()
	_idle_timer.one_shot = true
	add_child(_idle_timer)
	_idle_timer.timeout.connect(_on_idle_timeout)

	scale = SHRUNK_SCALE
	modulate.a = 0.0


func get_state() -> int:
	return _state


## Hand in Stage/Herman/HermanAP so state_changed can drive its idle/talk
## animations. Syncs Herman to the bubble's current state immediately, so
## call order relative to the first say() doesn't matter.
func set_herman_ap(ap: AnimationPlayer) -> void:
	_herman_ap = ap
	_update_herman_animation(_state)


## Re-arms the idle-chatter timer for another IDLE_MIN_S..IDLE_MAX_S window.
## koprasi.gd calls this on every Cart change so activity keeps pushing the
## next ambient line out; a no-op while sticky (a sticky line, e.g.
## SOLD_OUT, must not be undercut by an idle line the moment it clears) or
## before _ready() has built the timer (editor-edited-scene bubbles never
## get one).
func reset_idle_timer() -> void:
	if _idle_timer and not _sticky:
		_idle_timer.start(randf_range(IDLE_MIN_S, IDLE_MAX_S))


func _on_idle_timeout() -> void:
	if not idle_chatter_enabled:
		return
	if _state == State.IDLE and not _sticky:
		say(&"IDLE")


## Swaps Herman between "talk" (bubble SHOWING/LINGERING, including a
## sticky line) and "idle" (otherwise). Guarded against the edited-scene
## case for consistency with the rest of the file, though in practice
## _herman_ap is only ever populated by real gameplay/tests, never by the
## editor poking an edited scene.
func _update_herman_animation(s: int) -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	if not _herman_ap:
		return
	var anim_name := "talk" if s == State.SHOWING or s == State.LINGERING else "idle"
	if _herman_ap.has_animation(anim_name) and _herman_ap.current_animation != anim_name:
		_herman_ap.play(anim_name)


## Speak a line from DialogueCatalog.LINES[event]. Ignored while sticky, or
## within SAY_COOLDOWN of the previous accepted say() of the same event.
func say(event: StringName) -> void:
	_say_gated(event, func(): return DialogueCatalog.pick(event))


## Like say(), but for &"ADD"/&"REMOVE" where `item_name` may have its own
## DialogueCatalog.ITEM_LINES pool (falls back to the generic pool).
func say_for_item(event: StringName, item_name: String) -> void:
	_say_gated(event, func(): return DialogueCatalog.pick_for_item(event, item_name))


## Shared cooldown/sticky gate for say() and say_for_item(). `resolve_text`
## is only called once the gate passes -- it must stay lazy (a Callable, not
## an already-picked String), or a blocked call would still burn a pick()
## from DialogueCatalog's anti-repetition state for a line nobody sees.
func _say_gated(event: StringName, resolve_text: Callable) -> void:
	if _sticky or not _pass_cooldown(event):
		return
	var text: String = resolve_text.call()
	if text.is_empty():
		return
	_play(text)


## Pin `text` until clear_sticky(). Bypasses the cooldown and every later
## say()/say_for_item() is ignored until cleared. Idempotent: calling this
## again with the text already showing does nothing -- no re-tween, per the
## tap-spam safeguard spec ("same text, no re-tween").
func say_sticky(text: String) -> void:
	if _sticky and _label and _label.text == text:
		return
	_sticky = true
	if _linger_timer:
		_linger_timer.stop()
	_play(text)


## Release a sticky line and retract the bubble.
func clear_sticky() -> void:
	_sticky = false
	_hide()


func _pass_cooldown(event: StringName) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = _last_say_time.get(event, -1000000)
	if float(now - last) / 1000.0 < SAY_COOLDOWN:
		return false
	_last_say_time[event] = now
	return true


func _play(text: String) -> void:
	if _label:
		_label.text = text
	_set_state(State.SHOWING)

	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return

	if _linger_timer:
		_linger_timer.stop()
	_kill_tween()

	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween = tw
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, FADE_IN_S)
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN_S)
	tw.tween_property(self, "position", rest_position, FADE_IN_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_shown.bind(tw))


## `tw` is the Tween that finished; if a newer say()/say_sticky()/_hide()
## has since killed and replaced `_tween`, this is a superseded callback
## and must not touch state (finding: a stray callback flipping LINGERING
## back to IDLE, or arming the linger timer, behind a fresher animation).
func _on_shown(tw: Tween) -> void:
	if tw != _tween:
		return
	_set_state(State.LINGERING)
	if _sticky:
		return
	if _linger_timer:
		_linger_timer.start(LINGER_S)


func _on_linger_timeout() -> void:
	if _sticky:
		return
	_hide()


func _hide() -> void:
	_set_state(State.HIDING)

	if Engine.is_editor_hint() and is_part_of_edited_scene():
		_set_state(State.IDLE)
		return

	if _linger_timer:
		_linger_timer.stop()
	_kill_tween()

	var end_pos := rest_position + HERMAN_ANCHOR_OFFSET
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween = tw
	tw.set_parallel(true)
	tw.tween_property(self, "scale", SHRUNK_SCALE, FADE_OUT_S)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT_S)
	tw.tween_property(self, "position", end_pos, FADE_OUT_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_hidden.bind(tw))


## See _on_shown()'s note -- same staleness guard.
func _on_hidden(tw: Tween) -> void:
	if tw != _tween:
		return
	_set_state(State.IDLE)


## Stop and invalidate the in-flight tween, if any, before starting a new
## one. Godot's Tween.kill() prevents any of its remaining steps (including
## a queued tween_callback) from ever running; _on_shown()/_on_hidden()'s
## own `tw != _tween` check is the second, belt-and-braces layer.
func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _set_state(s: int) -> void:
	if _state == s:
		return
	_state = s
	state_changed.emit(s)
	_update_herman_animation(s)
	if s == State.IDLE and not _sticky:
		reset_idle_timer()
