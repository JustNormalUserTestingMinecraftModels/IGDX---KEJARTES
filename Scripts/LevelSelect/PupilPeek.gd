@tool
extends Control

## One pupil peeking out of an opened amplop: a round crop of the student's
## portrait (AvatarDisc panel with clip_children). A PackedScene template;
## AmplopCard pre-places four and shows as many as the grade's roster.
##
## The root keeps the HBoxContainer slot; `head` is what rises, so the
## container's re-sort never snaps a mid-rise face back into place.

## The portrait drawn inside the disc (resolved through StudentSkins by the
## caller, so the worn skin shows).
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			$Head/Portrait.texture = value

## The disc that rises out of the envelope; its Portrait child is clipped to it.
@onready var head: Control = $Head


func _ready() -> void:
	$Head/Portrait.texture = portrait_texture
