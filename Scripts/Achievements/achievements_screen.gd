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
## The currently-open claim celebration popup, if any. Tracked so Android
## back can close it first, before the detail sheet underneath it.
var _open_claim_popup: Node = null


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


## Android back: claim popup first (it has no back handling of its own),
## then the detail sheet underneath it, then leave the screen. A popup that
## is already fading out (a second fast back before `closed` fires) is
## invisible to the player, so it counts as gone and back falls through to
## the sheet instead of re-closing it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_open_claim_popup) and not _open_claim_popup._closing:
			_open_claim_popup.close()
			return
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
	_open_claim_popup = popup
	popup.closed.connect(_on_claim_popup_closed)
	popup.open(AchievementCatalog.get_entry(id))


func _on_claim_popup_closed() -> void:
	_open_claim_popup = null


func _on_state_changed() -> void:
	for tile in _tiles:
		tile.refresh()
	_on_filter_selected(filter_button.selected)


func _on_filter_selected(index: int) -> void:
	for tile in _tiles:
		tile.visible = tile.matches_filter(index)


## Status pill tap in the WAITING state. If the target tile is hidden by the
## active filter (e.g. "Belum dibuka" selected while the first unclaimed
## tile is elsewhere), the scroll would silently do nothing -- so reset the
## filter to "Semua" first. The grid only re-lays out one frame after
## visibility changes, so the actual scroll+shake is deferred to
## _scroll_to_tile_deferred() rather than awaited here, keeping this
## function callable synchronously from a test.
func _on_jump_requested() -> void:
	var achievements := _achievements()
	if achievements == null:
		return
	var id: String = achievements.first_unclaimed_id()
	if id == "":
		return
	var tile: AchievementTile = null
	for t in _tiles:
		if t.achievement_id == id:
			tile = t
			break
	if tile == null:
		return
	if not tile.visible:
		filter_button.select(0)
		_on_filter_selected(0)
	call_deferred("_scroll_to_tile_deferred", tile)


## Deferred half of _on_jump_requested(): runs a frame after any filter
## reset so the grid has already re-laid out the now-visible tile.
func _scroll_to_tile_deferred(tile: AchievementTile) -> void:
	var scroll := list.get_parent().get_parent() as ScrollContainer
	if scroll != null:
		scroll.ensure_control_visible(tile)
	Juice.shake(tile, 6.0)


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene(LOBBY, Transition.Style.WIPE)


func _achievements() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Achievements")
