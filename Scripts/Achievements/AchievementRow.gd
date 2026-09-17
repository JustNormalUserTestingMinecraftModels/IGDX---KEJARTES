@tool
extends PanelContainer

## One card on the Achievements screen (AchievementRow.tscn), in one of three
## looks: locked (white, dimmed, no button), unlocked (white with Klaim) and
## claimed (the AchievementCardClaimed gradient, no button). The screen
## fills it with setup() and listens for claim_pressed. @tool so the test
## runner can drive set_state() on an instance; it has no side effects.

signal claim_pressed(id: String)

const AchievementsScript := preload("res://Scripts/Achievements/Achievements.gd")

## Tint for a locked achievement's icon.
@export var locked_icon_modulate: Color = Color(0.35, 0.35, 0.35, 1.0)
## Tint for a locked achievement's words.
@export var locked_text_modulate: Color = Color(1.0, 1.0, 1.0, 0.55)

@onready var icon: TextureRect = %Icon
@onready var title_label: Label = %Title
@onready var desc_label: Label = %Desc
@onready var content: Control = %Content
@onready var claim_button: Button = %ClaimButton

var achievement_id: String = ""


func _ready() -> void:
	claim_button.pressed.connect(func() -> void: claim_pressed.emit(achievement_id))


## Shows catalog entry `entry` in state `state` (an Achievements.STATE_*).
func setup(entry: Dictionary, state: int) -> void:
	achievement_id = entry.id
	icon.texture = load(AchievementCatalog.icon_path(entry.id))
	title_label.text = entry.title
	desc_label.text = AchievementCatalog.description_of(entry)
	set_state(state)


## Switches the card's look to `state` (an Achievements.STATE_*).
func set_state(state: int) -> void:
	theme_type_variation = &"AchievementCardClaimed" \
		if state == AchievementsScript.STATE_CLAIMED else &"AchievementCard"
	claim_button.visible = state == AchievementsScript.STATE_UNLOCKED
	var locked := state == AchievementsScript.STATE_LOCKED
	icon.modulate = locked_icon_modulate if locked else Color.WHITE
	content.modulate = locked_text_modulate if locked else Color.WHITE
