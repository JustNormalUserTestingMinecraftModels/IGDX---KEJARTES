extends Control

## The Achievements screen, opened from the Lobby's trophy button (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md). It lists
## every AchievementCatalog entry as an AchievementTile in a 2-column grid
## (%List), with a header status pill + filter above it and a single
## AchievementDetailSheet overlay reused for every tile tap. Claims run
## through the sheet's claim_requested signal; the screen still owns the
## Achievements.claim() call + AchievementClaimPopup celebration, exactly as
## it did for the old AchievementRow. Returns to the Lobby from the back
## arrow or Android back, except while the detail sheet is open, where back
## closes the sheet instead (mirrors Scripts/Inventory/inventory.gd's guard).

const AchievementsScript := preload("res://Scripts/Achievements/Achievements.gd")
const LOBBY := "res://Scenes/Lobby/loby.tscn"

## The card template, one instance per achievement.
@export var tile_scene: PackedScene = preload("res://Scenes/Achievements/AchievementTile.tscn")
## The celebration shown after a successful claim.
@export var claim_popup_scene: PackedScene = preload("res://Scenes/Achievements/AchievementClaimPopup.tscn")

@onready var list: GridContainer = %List
@onready var back_button: TextureButton = %BackButton
@onready var status_pill: AchievementStatusPill = %StatusPill
@onready var filter_button: OptionButton = %FilterButton
@onready var detail_sheet: AchievementDetailSheet = %DetailSheet

var _tiles: Array[AchievementTile] = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	filter_button.item_selected.connect(_on_filter_selected)
	status_pill.jump_requested.connect(_on_jump_requested)
	detail_sheet.claim_requested.connect(_on_claim_requested)
	for entry in AchievementCatalog.ENTRIES:
		var tile: AchievementTile = tile_scene.instantiate()
		list.add_child(tile)
		tile.setup(entry)
		tile.tile_pressed.connect(_on_tile_pressed)
		_tiles.append(tile)
	var achievements := _achievements()
	if achievements != null and not achievements.state_changed.is_connected(_on_state_changed):
		achievements.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	var achievements := _achievements()
	if achievements != null and achievements.state_changed.is_connected(_on_state_changed):
		achievements.state_changed.disconnect(_on_state_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if detail_sheet.visible:
			detail_sheet.close()
			return
		_on_back_pressed()


func _on_tile_pressed(id: String) -> void:
	detail_sheet.open_for(id)


func _on_claim_requested(id: String) -> void:
	if not Achievements.claim(id):
		return
	AudioDirector.play_sfx(&"tap")
	var popup := claim_popup_scene.instantiate()
	add_child(popup)
	popup.open(AchievementCatalog.get_entry(id))


func _on_state_changed() -> void:
	for tile in _tiles:
		tile.refresh()


func _on_filter_selected(index: int) -> void:
	for tile in _tiles:
		tile.visible = tile.matches_filter(index)


func _on_jump_requested() -> void:
	var achievements := _achievements()
	if achievements == null:
		return
	var id := achievements.first_unclaimed_id()
	if id == "":
		return
	for tile in _tiles:
		if tile.achievement_id == id:
			var scroll := list.get_parent().get_parent() as ScrollContainer
			if scroll != null:
				scroll.ensure_control_visible(tile)
			Juice.shake(tile, 6.0)
			break


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene(LOBBY, Transition.Style.WIPE)


func _achievements() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Achievements")
