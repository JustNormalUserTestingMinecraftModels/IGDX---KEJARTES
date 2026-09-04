@tool
class_name StarMeter
extends HBoxContainer

## The run's 3-star meter: three TextureProgressBars wearing icon_star.svg,
## filled left to right so a value of 1.75 reads as one full star, one
## three-quarter star, one empty. Continuous by design -- every cleared
## stat adds one equal share, and StatCheck animates the meter to the
## running total after each one.

## Seconds a meter step takes. Short: it follows a bar that already popped.
@export var step_seconds: float = 0.35

@onready var _stars: Array[TextureProgressBar] = [$Star1, $Star2, $Star3]


## Render `stars` (0.0-3.0) instantly. Star i shows clamp(stars - i, 0, 1).
func set_stars(stars: float) -> void:
	for i in range(_stars.size()):
		_stars[i].value = clampf(stars - float(i), 0.0, 1.0) * 100.0


## Tween to `stars`. Each star bar is tweened separately so a value that
## crosses a star boundary fills the first star fully before the next
## starts -- the meter reads as stars lighting one at a time.
func animate_to(stars: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for i in range(_stars.size()):
		var target := clampf(stars - float(i), 0.0, 1.0) * 100.0
		tw.tween_property(_stars[i], "value", target, step_seconds)
