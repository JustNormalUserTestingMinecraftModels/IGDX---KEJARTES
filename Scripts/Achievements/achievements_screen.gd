extends Control

## The Achievements screen, opened from the Lobby's trophy button (spec:
## docs/superpowers/specs/2026-09-17-achievements-design.md). It lists every
## AchievementCatalog entry as an AchievementRow in catalog order, claims
## on Klaim, and returns to the Lobby from the back arrow or Android back.

const AchievementsScript := preload("res://Scripts/Achievements/Achievements.gd")
const LOBBY := "res://Scenes/Lobby/loby.tscn"

## The card template, one instance per achievement.
@export var row_scene: PackedScene = preload("res://Scenes/Achievements/AchievementRow.tscn")
## The celebration shown after a successful claim.
@export var claim_popup_scene: PackedScene = preload("res://Scenes/Achievements/AchievementClaimPopup.tscn")

@onready var list: VBoxContainer = %List
@onready var back_button: TextureButton = %BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	for entry in AchievementCatalog.ENTRIES:
		var row := row_scene.instantiate()
		list.add_child(row)
		row.setup(entry, Achievements.state_of(entry.id))
		row.claim_pressed.connect(_on_claim_pressed.bind(row))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _on_claim_pressed(id: String, row: Control) -> void:
	if not Achievements.claim(id):
		return
	AudioDirector.play_sfx(&"tap")
	row.set_state(AchievementsScript.STATE_CLAIMED)
	Juice.pop_in(row)
	var popup := claim_popup_scene.instantiate()
	add_child(popup)
	popup.open(AchievementCatalog.get_entry(id))


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene(LOBBY, Transition.Style.WIPE)
