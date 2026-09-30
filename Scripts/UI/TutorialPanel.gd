@tool
class_name TutorialPanel
extends MarginContainer

## The onboarding coach-mark: a head badge, title, a separator, body text,
## another separator, and a blinking prompt on a NotebookFrame dialog (no
## tabs, four rings, no well, no close -- the flow is forced, so there is no
## way out but the prompt's own tap). StudentCard's per-step tutorial and
## SchoolDay's end-of-week tutorial both build this shape via show_step()
## -- their shipped numbers differ in several places (see the exports
## below), so those numbers are knobs instead of a single hardcoded look.
##
## The head badge is one of two authored nodes, chosen by `mode`: the step
## pill ("Langkah 2 / 5", shown by show_step() for a multi-step flow) or the
## speaker's name plate (shown by show_beat(), the headmaster's beat). Both
## are scene nodes above the title, not built here. The frame's sticker
## follows the mode too (step_sticker_text, beat_sticker_text): a beat is a
## story, and must not wear the tutorial's label. play_in() and
## play_out() are the card's entrance and exit springs; a caller that
## positions the card runs them after it has placed it.
##
## Each caller places this MarginContainer itself (fit `free`); it wraps
## a Frame child rather than a Frame of its own so its root stays a plain
## Control the callers can position and scale directly. SchoolDay's
## dimming Scrim overlay is NOT part of this scene: it is the panel's
## parent in the real hierarchy, not a sibling inside it, so it stays
## owned by the caller.
##
## The screens that spotlight a control (AturJadwal, StudentList, Lobby) share
## a handful of static helpers from here instead of each carrying its own
## copy. mount() puts the card into the spotlight overlay; cut_hole() cuts the
## hole; place_step() seats the card and the tutorial arrow for a step --
## against the half of the screen opposite the spotlit control, so the arrow
## has room and never lies across the card; and answer_wrong_tap() is what a
## forced step does with a tap on the wrong control, which used to be nothing
## at all. rect_in() and spot_in() turn controls into the rectangles those
## work from.

## What the pill reads: the step number, then how many steps there are.
const STEP_PILL_FORMAT := "Langkah %d / %d"

## What the prompt says when a step gives it no line of its own, and what every
## tap-to-continue card in the game says (the headmaster's beat, each screen's
## empty card, the unhighlighted steps): one line, so two cards in a row never
## ask for the same tap two ways.
const DEFAULT_PROMPT := "KETUK DI MANA SAJA UNTUK LANJUT"
## The tutorial arrow's script, for the geometry placement() shares with it.
const ArrowScript := preload("res://Scripts/TutorialArrow.gd")
## How far the spotlight hole stands off the control it frames, in pixels.
const SPOT_PADDING := 12.0
## The share of its own alpha a control keeps while a wrong tap dims it.
const DIM_ALPHA := 0.4
## Meta on a control a wrong tap has dimmed: the modulate it had before, which
## the dim returns to. Kept so a second wrong tap in mid-dim restores the real
## colour, not the dimmed one.
const DIM_ORIGIN_META := &"tutorial_dim_origin"
## Meta on the control a wrong tap shook, for as long as that answer plays, so
## a second tap cannot start another shake from the first one's offset.
const ANSWERING_META := &"tutorial_answering"

## Which badge heads the card.
enum Mode {
	## The step pill heads the card: a tutorial step.
	STEP,
	## The speaker's name plate heads the card: a headmaster beat.
	HEADMASTER,
}

## Which badge heads the card: STEP shows the "Langkah n / N" pill (when
## show_step() was given a count above one), HEADMASTER shows the speaker's
## name plate. show_step() and show_beat() set this themselves.
@export var mode: Mode = Mode.STEP:
	set(value):
		mode = value
		if is_inside_tree():
			_apply_mode()

## The title on the frame's sticker while a tutorial step heads the card
## (mode STEP). The scene authors the same word on the Frame, so the sticker
## reads right before the first show_step().
@export var step_sticker_text: String = "TUTORIAL":
	set(value):
		step_sticker_text = value
		if is_inside_tree():
			_apply_mode()

## The title on the frame's sticker while the headmaster's beat heads the card
## (mode HEADMASTER). A promotion's congratulation is a story beat, not a
## lesson, so its card must not wear the tutorial's label.
@export var beat_sticker_text: String = "PENGUMUMAN":
	set(value):
		beat_sticker_text = value
		if is_inside_tree():
			_apply_mode()

## Panel width as a fraction of the viewport width, before max_width clamps
## it. StudentCard ships 0.92; SchoolDay ships 0.85.
@export var width_fraction: float = 0.92:
	set(value):
		width_fraction = value
		if is_inside_tree():
			_apply_geometry()

## Hard cap on panel width in pixels. StudentCard ships 1000; SchoolDay 900.
@export var max_width: float = 1000.0:
	set(value):
		max_width = value
		if is_inside_tree():
			_apply_geometry()

## Uniform margin (all four sides) between the Card surface and its
## content. StudentCard has none (0); SchoolDay wraps its content in 30px.
@export var content_margin: int = 0:
	set(value):
		content_margin = value
		if is_inside_tree():
			_apply_geometry()

## VBoxContainer separation between title/separator/body/separator/prompt.
## StudentCard ships 10; SchoolDay ships 20.
@export var vbox_separation: int = 10:
	set(value):
		vbox_separation = value
		if is_inside_tree():
			layout.add_theme_constant_override("separation", value)

## Theme variation for the title label. StudentCard uses H1Label;
## SchoolDay uses the smaller H2Label.
@export var title_variation: StringName = &"H1Label":
	set(value):
		title_variation = value
		if is_inside_tree():
			title_label.theme_type_variation = value

## Theme variation for the body label. StudentCard uses TitleLabel;
## SchoolDay sets none (plain default Label styling).
@export var body_variation: StringName = &"TitleLabel":
	set(value):
		body_variation = value
		if is_inside_tree():
			body_label.theme_type_variation = value

## How much narrower the body label is than the panel's own outer width,
## on top of the frame's horizontal content_padding (subtracted separately
## in _apply_geometry() so the two insets never double up) -- the room its
## autowrap keeps clear of the frame's rings and cover. StudentCard ships
## 60; SchoolDay (wider content margin already eating into the width)
## ships 100.
@export var body_width_offset: float = 60.0:
	set(value):
		body_width_offset = value
		if is_inside_tree():
			_apply_geometry()

## Theme variation for the prompt label. StudentCard uses TitleLabel;
## SchoolDay uses the quieter CaptionLabel.
@export var prompt_variation: StringName = &"TitleLabel":
	set(value):
		prompt_variation = value
		if is_inside_tree():
			prompt_label.theme_type_variation = value

## When true, tints the prompt label with the design tokens' success
## color. Only SchoolDay's end-of-week tutorial does this.
@export var prompt_success_tint: bool = false:
	set(value):
		prompt_success_tint = value
		if is_inside_tree():
			_apply_prompt_tint()

@onready var frame: NotebookFrame = $Frame
@onready var margin: MarginContainer = $Frame/Margin
@onready var layout: VBoxContainer = $Frame/Margin/Layout
@onready var title_label: Label = $Frame/Margin/Layout/TitleLabel
@onready var body_label: Label = $Frame/Margin/Layout/BodyLabel
@onready var prompt_label: Label = $Frame/Margin/Layout/PromptLabel
@onready var step_pill: PanelContainer = $Frame/Margin/Layout/StepPill
@onready var step_label: Label = $Frame/Margin/Layout/StepPill/StepLabel
@onready var name_plate: PanelContainer = $Frame/Margin/Layout/NamePlate
@onready var speaker_label: Label = $Frame/Margin/Layout/NamePlate/Row/SpeakerLabel

## Whether the pill shows while mode is STEP: show_step() hides it for a
## flow of one step or none. True until then, so the authored pill shows.
var _pill_wanted := true
## True once a step or beat has filled the card; only later ones animate.
var _content_shown := false
## The step-change fade of the badge, title and body, while it plays.
var _step_tween: Tween
## The entrance spring play_in() started, while it plays. play_out() kills it.
var _entrance_tween: Tween


func _ready() -> void:
	layout.add_theme_constant_override("separation", vbox_separation)
	title_label.theme_type_variation = title_variation
	body_label.theme_type_variation = body_variation
	prompt_label.theme_type_variation = prompt_variation
	_apply_prompt_tint()
	_apply_mode()
	_apply_geometry()
	_let_taps_through(self)


## The card never takes a tap, anywhere on it: a step advances by the caller's
## own click catcher, or by the real control the step points at, and the card
## sits over such a control often enough (a splash, a card stack) that a
## catching card would make that tap do nothing. Every Control in the card
## ignores the mouse. The scene authors that on the Frame and its Margin; the
## NotebookFrame's own chrome (its Cover passes taps to the frame, its hidden
## tabs and close button are buttons) is an instance's children, which a scene
## cannot override, so it is done here, in the editor too.
func _let_taps_through(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_let_taps_through(child)


## body_label's forced minimum width must leave room for BOTH insets: the
## frame's own horizontal content_padding (which shrinks the content_rect()
## the label actually sits in) and body_width_offset (the extra autowrap
## slack a caller wants beyond that). Only subtracting body_width_offset,
## as before the frame wrap, left the label wider than the frame's content
## area and forced the whole panel past the screen edge (fix round 1, F2).
func _apply_geometry() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_width: float = min(viewport_size.x * width_fraction, max_width)
	custom_minimum_size = Vector2(panel_width, 0)
	margin.add_theme_constant_override("margin_left", content_margin)
	margin.add_theme_constant_override("margin_top", content_margin)
	margin.add_theme_constant_override("margin_right", content_margin)
	margin.add_theme_constant_override("margin_bottom", content_margin)
	var pad: Vector4i = frame.content_padding
	var body_width: float = panel_width - body_width_offset - float(pad.x + pad.z)
	body_label.custom_minimum_size = Vector2(body_width, 0)


func _apply_prompt_tint() -> void:
	prompt_label.self_modulate = Juice.tokens().state_success if prompt_success_tint else Color.WHITE


## Shows the badge `mode` asks for, the pill (only when show_step() was given
## a count above one) or the name plate, and titles the frame's sticker to
## match. The sticker is only written when it changes: each write re-sorts the
## frame, and show_step() lands here on every step.
func _apply_mode() -> void:
	step_pill.visible = mode == Mode.STEP and _pill_wanted
	name_plate.visible = mode == Mode.HEADMASTER
	var sticker := step_sticker_text if mode == Mode.STEP else beat_sticker_text
	if frame.title_text != sticker:
		frame.title_text = sticker


## Fills all three labels for one tutorial step and shows the step pill.
## Callers that need to branch on the prompt text (StudentCard's
## per-target-button hints) compute that string first and pass it in here.
## `step` is 1-based; a `step_count` of one or less (the default) hides the
## pill, so a caller with one step, or one that predates the pill, shows
## none. Switches the card back to STEP mode, so a panel that just showed a
## beat can go on to teach.
func show_step(title: String, body: String, prompt: String, step: int = 0,
		step_count: int = 0) -> void:
	_set_texts(title, body, prompt)
	_pill_wanted = step_count > 1
	if _pill_wanted:
		step_label.text = STEP_PILL_FORMAT % [step, step_count]
	mode = Mode.STEP
	_play_step_change()


## Fills all three labels for one line of a headmaster beat and shows the
## name plate reading `speaker`. Switches the card to HEADMASTER mode.
func show_beat(speaker: String, title: String, body: String, prompt: String) -> void:
	_set_texts(title, body, prompt)
	speaker_label.text = speaker
	mode = Mode.HEADMASTER
	_play_step_change()


func _set_texts(title: String, body: String, prompt: String) -> void:
	title_label.text = title
	body_label.text = body
	prompt_label.text = prompt


## The entrance: the card springs up from a little under full size with a
## settling overshoot while it fades in (Juice.pop_in). Place the card
## first; the spring grows from its centre. Does nothing in the editor.
func play_in() -> void:
	if Engine.is_editor_hint():
		return
	_entrance_tween = Juice.pop_in(self)


## The exit: the card shrinks and fades. Returns the tween so a caller can
## await its `finished` before freeing the card or moving on. It first stops
## the entrance and the step change, so a tap that comes while either is still
## playing is not undone by it: the entrance would otherwise go on to fade
## the card back in over its own exit. In the editor nothing animates and the
## tween it returns is already done.
func play_out() -> Tween:
	_stop_entering()
	if Engine.is_editor_hint():
		var done := create_tween()
		done.tween_interval(0.0)
		return done
	return AnimUtils.popup_spring_out(self, self)


## Kills the entrance and the step-change fade, whichever is still running.
func _stop_entering() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	if _step_tween != null and _step_tween.is_valid():
		_step_tween.kill()


## The step change: the badge, title and body fade in one after another
## while the card stays put. Skipped for the card's first fill (play_in()
## is that entrance) and in the editor. The prompt is left alone on
## purpose: its alpha belongs to the caller's blink tween.
func _play_step_change() -> void:
	var first := not _content_shown
	_content_shown = true
	if first or Engine.is_editor_hint() or not is_inside_tree():
		return
	if _step_tween != null and _step_tween.is_valid():
		_step_tween.kill()
	_step_tween = create_tween().set_parallel(true)
	var gap: float = Juice.tokens().stagger_step
	var fade: float = Juice.tokens().dur_normal
	var badge: Control = step_pill if mode == Mode.STEP else name_plate
	var index := 0
	for node: CanvasItem in [badge, title_label, body_label]:
		node.modulate.a = 0.0
		var reveal := _step_tween.tween_property(node, "modulate:a", 1.0, fade)
		reveal.set_ease(Tween.EASE_OUT).set_delay(float(index) * gap)
		index += 1


## A control's rectangle in the coordinate space of `space`, a Control with no
## scale or rotation of its own -- a screen's spotlight overlay.
static func rect_in(node: Control, space: Control) -> Rect2:
	return Rect2(node.global_position - space.global_position, node.size)


## The spot a step highlights, in `space`'s coordinates: the rectangle that
## holds every control in `targets`, grown by `padding` (the spotlight hole
## stands that far off the control). A control's four corners go through its
## own transform, so a tilted or scaled one is framed whole. Anything that is
## not a live Control is skipped; an empty Rect2 means nothing is highlighted.
static func spot_in(targets: Array, space: Control, padding: float = SPOT_PADDING) -> Rect2:
	var spot := Rect2()
	var found := false
	for target: Variant in targets:
		if not is_instance_valid(target) or not (target is Control):
			continue
		var control := target as Control
		var corners: Array[Vector2] = [Vector2.ZERO, Vector2(control.size.x, 0.0),
				Vector2(0.0, control.size.y), control.size]
		for corner: Vector2 in corners:
			var point := control.get_global_transform() * corner - space.global_position
			spot = spot.expand(point) if found else Rect2(point, Vector2.ZERO)
			found = true
	return spot.grow(padding) if found else spot


## Cuts the spotlight hole around `controls` in `overlay`'s shader: hole_pos
## and hole_size, in the overlay's own space, `padding` off the controls.
## Returns false, touching nothing, when `controls` holds no live Control or
## the overlay has no spotlight material, so the caller can clear the hole.
static func cut_hole(overlay: Control, controls: Array, padding: float = SPOT_PADDING) -> bool:
	var hole := spot_in(controls, overlay, padding)
	var spotlight := overlay.material as ShaderMaterial
	if not hole.has_area() or spotlight == null:
		return false
	spotlight.set_shader_parameter("hole_pos", hole.position)
	spotlight.set_shader_parameter("hole_size", hole.size)
	return true


## Instances the coach-mark `scene` into `overlay`, just under `before` (the
## overlay's click catcher, so a tap still reaches it), and empties it: with
## no step yet, show_step() keeps the scene's sample pill ("Langkah 1 / 3")
## hidden until the first real step writes its own. Returns the card.
static func mount(scene: PackedScene, overlay: Control, before: Control) -> TutorialPanel:
	var panel: TutorialPanel = scene.instantiate()
	panel.name = "TutorialPanel"
	overlay.add_child(panel)
	overlay.move_child(panel, before.get_index())
	panel.show_step("", "", DEFAULT_PROMPT)
	return panel


## Where the card's top-left corner goes, in the space `bounds` and `spot`
## share (`bounds` is the screen's Safe/UI, so the card keeps to the safe
## area). The card is centred across `bounds` and sits against the half of it
## opposite `spot`: the bottom when the spot's centre is in the top half, the
## top otherwise. That leaves the tutorial arrow room beside the spot -- and
## when the spot is so big that the arrow would then have nowhere to go but
## across the card (a whole card stack, a splash), the card takes the other
## half instead. A step with no spot (an empty Rect2) centres the card.
static func placement(bounds: Rect2, panel_size: Vector2, spot: Rect2, arrow_size: Vector2) -> Vector2:
	var centred := bounds.position + (bounds.size - panel_size) / 2.0
	if not spot.has_area():
		return centred
	var top := Vector2(centred.x, bounds.position.y)
	var bottom := Vector2(centred.x, bounds.end.y - panel_size.y)
	var spot_above_middle := spot.get_center().y < bounds.get_center().y
	var sides: Array[Vector2] = [top, bottom]
	if spot_above_middle:
		sides = [bottom, top]
	for side: Vector2 in sides:
		var fit: Dictionary = ArrowScript.fit(spot, bounds, arrow_size, Rect2(side, panel_size))
		if fit["clear"]:
			return side
	return sides[0]


## Puts one spotlit step's card and arrow where they belong, for the screens
## that dim everything but a spot. Waits a frame so the card is as big as its
## new text makes it, then places it inside `bounds_node` (the screen's Safe/UI)
## and points `arrow` at the spot `targets` make, clear of the card. `overlay`
## is the spotlight's own Control, the space the card and arrow are children
## of. A step with no targets centres the card and hides the arrow.
static func place_step(panel: TutorialPanel, bounds_node: Control, overlay: Control,
		targets: Array, arrow: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	panel.reset_size()
	await panel.get_tree().process_frame
	if not is_instance_valid(panel) or not is_instance_valid(bounds_node):
		return
	var bounds := rect_in(bounds_node, overlay)
	var spot := spot_in(targets, overlay)
	var arrow_size := Vector2.ZERO
	if is_instance_valid(arrow):
		arrow_size = arrow.arrow_size
	panel.position = placement(bounds, panel.size, spot, arrow_size)
	panel.pivot_offset = panel.size / 2.0
	if not is_instance_valid(arrow):
		return
	arrow.visible = spot.has_area()
	if arrow.visible:
		arrow.position = arrow.point_at(spot, bounds, Rect2(panel.position, panel.size))


## What a forced step does with a tap on the wrong control: the error cue, the
## control the step wants shakes, and `others` -- the controls the tap could
## have meant, by default the target's sibling buttons -- dim for a moment.
## The card stays up and says nothing; the motion says "not that one, this
## one." A second tap while the answer still plays only repeats the cue.
static func answer_wrong_tap(target: Control, others: Array = []) -> void:
	AudioDirector.play_sfx(&"error")
	if not is_instance_valid(target) or target.has_meta(ANSWERING_META):
		return
	target.set_meta(ANSWERING_META, true)
	Juice.shake(target)
	var dimmed: Array = others if not others.is_empty() else sibling_buttons(target)
	dim_others(dimmed, target)
	var release := target.create_tween()
	release.tween_interval(dim_seconds())
	release.tween_callback(target.remove_meta.bind(ANSWERING_META))


## `target`'s siblings that are visible buttons: the controls a tap aimed at
## `target` could most likely have landed on instead.
static func sibling_buttons(target: Control) -> Array[Control]:
	var out: Array[Control] = []
	var parent := target.get_parent()
	if parent == null:
		return out
	for child: Node in parent.get_children():
		if child is BaseButton and child != target and (child as Control).visible:
			out.append(child as Control)
	return out


## How long one dim lasts, from the first fade to the colour back: the fade in,
## the hold and the fade out.
static func dim_seconds() -> float:
	var tokens := Juice.tokens()
	return tokens.dur_fast + tokens.dur_slow + tokens.dur_normal


## Dims each control in `others` to DIM_ALPHA of its own alpha, holds it, and
## fades it back to the modulate it had. `spare` (the control the step wants)
## and anything that is not a live CanvasItem are skipped.
static func dim_others(others: Array, spare: Control = null) -> void:
	var tokens := Juice.tokens()
	for other: Variant in others:
		if not is_instance_valid(other) or other == spare or not (other is CanvasItem):
			continue
		var node := other as CanvasItem
		var origin: Color = node.get_meta(DIM_ORIGIN_META, node.modulate)
		node.set_meta(DIM_ORIGIN_META, origin)
		var dimmed := origin
		dimmed.a = origin.a * DIM_ALPHA
		var tween := node.create_tween()
		tween.tween_property(node, "modulate", dimmed, tokens.dur_fast)
		tween.tween_interval(tokens.dur_slow)
		tween.tween_property(node, "modulate", origin, tokens.dur_normal)
		tween.tween_callback(node.remove_meta.bind(DIM_ORIGIN_META))
