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
## are scene nodes above the title, not built here. play_in() and
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
## The root MarginContainer's own margin_* constants are zeroed in the
## .tscn (layout-only overrides): the baked theme gives every
## MarginContainer the screen margin (48px a side, ThemeFactory.gd) by
## default, and with no override the root silently added 96px to the
## panel's width and height on top of Frame's own size -- 1036px on a
## 1080px screen for StudentCard's shipped numbers (fix round 2, F3). The
## inner `Frame/Margin` needs no such override: _apply_geometry() already
## sets its margin_* explicitly every time, which masks the theme default
## even at content_margin == 0.

## What the pill reads: the step number, then how many steps there are.
const STEP_PILL_FORMAT := "Langkah %d / %d"

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
var _step_tween: Tween


func _ready() -> void:
	layout.add_theme_constant_override("separation", vbox_separation)
	title_label.theme_type_variation = title_variation
	body_label.theme_type_variation = body_variation
	prompt_label.theme_type_variation = prompt_variation
	_apply_prompt_tint()
	_apply_mode()
	_apply_geometry()


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


## Shows the badge `mode` asks for: the pill (only when show_step() was
## given a count above one) or the name plate.
func _apply_mode() -> void:
	step_pill.visible = mode == Mode.STEP and _pill_wanted
	name_plate.visible = mode == Mode.HEADMASTER


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
	Juice.pop_in(self)


## The exit: the card shrinks and fades. Returns the tween so a caller can
## await its `finished` before freeing the card or moving on. In the editor
## nothing animates and the tween it returns is already done.
func play_out() -> Tween:
	if Engine.is_editor_hint():
		var done := create_tween()
		done.tween_interval(0.0)
		return done
	return AnimUtils.popup_spring_out(self, self)


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
