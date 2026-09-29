class_name MinigameHowTo
extends Resource

## A minigame's CARA MAIN card content (spec 2026-09-29 minigame mobile
## layout, 3.4). One .tres per game in Resources/Minigames/HowTo/, named
## after the game's script; BaseMinigame.how_to points at it. Replaces the
## old tutorial_title / tutorial_instructions strings and their emoji
## fallback table.

## The game's name, shown as the card's heading.
@export var title: String = ""
## Two or three steps, top to bottom.
@export var steps: Array[MinigameHowToStep] = []
