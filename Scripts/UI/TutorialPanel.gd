@tool
class_name TutorialPanel
extends MarginContainer

## The onboarding coach-mark: title, a separator, body text, another
## separator, and a blinking prompt on a NotebookFrame dialog (no tabs,
## four rings, no well, no close -- the flow is forced, so there is no way
## out but the prompt's own tap). StudentCard's per-step tutorial and
## SchoolDay's end-of-week tutorial both build this shape via show_step()
## -- their shipped numbers differ in several places (see the exports
## below), so those numbers are knobs instead of a single hardcoded look.
## Each caller places this MarginContainer itself (fit `free`); it wraps
## a Frame child rather than a Frame of its own so its root stays a plain
## Control the callers can position and scale directly. SchoolDay's
## dimming Scrim overlay is NOT part of this scene: it is the panel's
## parent in the real hierarchy, not a sibling inside it, so it stays
## owned by the caller.

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


func _ready() -> void:
	layout.add_theme_constant_override("separation", vbox_separation)
	title_label.theme_type_variation = title_variation
	body_label.theme_type_variation = body_variation
	prompt_label.theme_type_variation = prompt_variation
	_apply_prompt_tint()
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


## Fills all three labels for one tutorial step. Callers that need to
## branch on the prompt text (StudentCard's per-target-button hints)
## compute that string first and pass it in here.
func show_step(title: String, body: String, prompt: String) -> void:
	title_label.text = title
	body_label.text = body
	prompt_label.text = prompt
