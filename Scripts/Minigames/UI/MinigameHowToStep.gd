class_name MinigameHowToStep
extends Resource

## One step of a minigame's CARA MAIN card (spec 2026-09-29 minigame mobile
## layout, 3.4): a picture and one short Indonesian line.

## The step's picture, from Assets/Images/UI/Icons/howto_*.svg.
@export var icon: Texture2D
## One short line, Indonesian, no emoji.
@export_multiline var text: String = ""
