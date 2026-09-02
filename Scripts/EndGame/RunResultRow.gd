@tool
extends PanelContainer

## One row of the end-of-grade report: an icon, a name, and a number that
## counts up.
##
## A PackedScene template rather than a runtime-built HBox, per the
## authoring guide -- RunResult instantiates one of these per reported
## figure. The value deliberately renders as "0" until play_count_up()
## runs, so the screen never flashes its own punchline before the reveal
## reaches that row.

@onready var icon_rect: TextureRect = $Row/IconRect
@onready var name_label: Label = $Row/NameLabel
@onready var value_label: Label = $Row/ValueLabel

## Explicit and otherwise empty: without a user-defined _ready(), Godot
## has no compiled "_ready" method to call, and tests that instantiate
## this template without adding it to a live SceneTree (per this
## project's established @tool-scene test pattern) call _ready() directly
## to populate the @onready vars above -- that call needs a real method
## to land in.
func _ready() -> void:
	pass


## The number this row counts up to. Set through set_row().
var target_value: float = 0.0
## Appended to the counted number, e.g. "G" for rupiah. Set through set_row().
var value_suffix: String = ""


## The icon is a Texture2D, never a text glyph -- these rows sit on a Card
## surface and must render the same on every device and font fallback,
## which an emoji cannot promise. Passing null leaves the template's
## stand-in texture in place rather than blanking the slot.
func set_row(label_text: String, value: float, suffix: String = "",
		icon: Texture2D = null) -> void:
	name_label.text = label_text
	target_value = value
	value_suffix = suffix
	if icon != null:
		icon_rect.texture = icon
	value_label.text = "0" + value_suffix


## Counts the value up over `duration` seconds. Deviation from the brief:
## Juice.count_up(label, from, to, fmt) takes a printf-style format string,
## not a duration/suffix pair, and always animates over its own internal
## "dur_slow" token rather than a caller-supplied duration. Since this row
## needs both a caller-controlled duration and a suffix appended to the
## number, the tween is built directly here instead, formatting the label
## in a tween_method callback the same way Juice.count_up does internally.
func play_count_up(duration: float) -> void:
	var tw := value_label.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(
		func(v: float) -> void:
			value_label.text = str(int(round(v))) + value_suffix,
		0.0, target_value, duration)
	tw.tween_callback(func() -> void:
		value_label.text = str(int(round(target_value))) + value_suffix)
