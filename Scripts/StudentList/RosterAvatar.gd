@tool
class_name RosterAvatar
extends Button

## One student's slot in the StudentList roster strip: their portrait
## inside a ring tinted green when that student's week is scheduled and
## red when it is not. Four of these sit above the carousel so the
## roster's progress reads without paging through every card, which is
## the problem this screen had -- it asks "who still needs a schedule?"
## and answered it one student at a time.
##
## @tool so the Inspector and the MCP test suite both see applied state
## rather than only authored defaults; every setter guards on
## is_node_ready(), matching StickyNote.gd's established pattern. The
## button itself is the GhostButton variation, which draws nothing at
## rest so the baked ring art can be the button. Ring art is white and
## tinted via self_modulate from tokens.

## The student's portrait, drawn inside the ring.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			$Portrait.texture = value

## True once this student's week is scheduled. Tints the ring
## state_success; false tints it state_danger.
@export var is_scheduled: bool = false:
	set(value):
		is_scheduled = value
		if is_node_ready():
			_apply_state()

## True for the student the carousel is currently showing. The current
## avatar sits at full opacity, the rest at inactive_alpha.
@export var is_current: bool = false:
	set(value):
		is_current = value
		if is_node_ready():
			_apply_state()

## Opacity for avatars that are not the current card. Low enough to
## recede, high enough that the ring's state colour still reads.
@export_range(0.3, 1.0, 0.05) var inactive_alpha: float = 0.55


func _ready() -> void:
	$Portrait.texture = portrait_texture
	_apply_state()


func _apply_state() -> void:
	var tokens := DesignTokens.load_default()
	$Ring.self_modulate = tokens.state_success if is_scheduled else tokens.state_danger
	modulate.a = 1.0 if is_current else inactive_alpha
