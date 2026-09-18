@tool
class_name AchievementDetailSheet
extends Control

## The modal detail sheet opened when an AchievementTile is tapped (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 3,
## "Tap-to-expand"). Meant to be instanced ONCE into achievements.tscn and
## hidden until open_for() is called (Task 5's job).
##
## Shows the full-size icon, title, desc, prize line and the numeric
## progress fraction ("2 / 3", from Achievements.progress_fraction_of), plus
## an action area that is exactly one of: a Klaim button (STATE_UNLOCKED), a
## lock icon (STATE_LOCKED) or a "Sudah diambil" caption (STATE_CLAIMED).
##
## The fraction text is hidden for one-shot kinds (three_star/play_all/grade,
## whose target is always 1) -- "1 / 1" reads like a bug report, not
## progress, so those kinds show nothing there instead.
##
## Claim path: this sheet does NOT call Achievements.claim itself. It emits
## claim_requested(id) and leaves the actual claim() call + claim-popup
## celebration to the host screen, exactly mirroring how
## achievements_screen.gd's _on_claim_pressed already drives AchievementRow
## today (claim -> sfx -> popup). Task 5 wires this with one line:
##   sheet.claim_requested.connect(_on_claim_pressed_from_sheet)
## where that handler does the same Achievements.claim(id) + popup the row's
## handler does, then calls sheet.close() (or lets state_changed refresh it).
##
## Closes on scrim tap, the back arrow, or Android back (only while open, and
## it does not let the request fall through to the screen's own back
## handling -- see achievements_screen.gd Task 5, which must skip its
## back-to-lobby handling while this sheet is open, the same way
## Scripts/Inventory/inventory.gd skips its back handling while its
## ItemDetailSheet is up).

signal closed
signal claim_requested(id: String)

const AchievementsScript := preload("res://Scripts/Achievements/Achievements.gd")

## One-shot achievement kinds whose target is always 1 -- the fraction text
## is hidden for these rather than showing a meaningless "1 / 1" / "0 / 1".
const _ONE_SHOT_KINDS := [
	AchievementCatalog.KIND_THREE_STAR,
	AchievementCatalog.KIND_PLAY_ALL,
	AchievementCatalog.KIND_GRADE,
]

@onready var _scrim: Panel = %Scrim
@onready var _sheet: PanelContainer = %Sheet
@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %Title
@onready var _desc_label: Label = %Desc
@onready var _prize_label: Label = %PrizeLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _claim_button: Button = %ClaimButton
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _claimed_label: Label = %ClaimedLabel
@onready var _back_button: TextureButton = %BackButton

var achievement_id: String = ""
var _open: bool = false


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	visible = false
	if not _scrim.gui_input.is_connected(_on_scrim_input):
		_scrim.gui_input.connect(_on_scrim_input)
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if not _claim_button.pressed.is_connected(_on_claim_pressed):
		_claim_button.pressed.connect(_on_claim_pressed)


## Shows the sheet filled with catalog entry `id`'s current state/progress.
func open_for(id: String) -> void:
	achievement_id = id
	_refresh_content()
	visible = true
	_open = true
	var achievements := _achievements()
	if achievements != null and not achievements.state_changed.is_connected(_refresh_content):
		achievements.state_changed.connect(_refresh_content)


## Hides the sheet and emits `closed`. Safe to call when already closed.
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	var achievements := _achievements()
	if achievements != null and achievements.state_changed.is_connected(_refresh_content):
		achievements.state_changed.disconnect(_refresh_content)
	closed.emit()


func _refresh_content() -> void:
	if achievement_id == "":
		return
	var entry := AchievementCatalog.get_entry(achievement_id)
	if entry.is_empty():
		return
	var achievements := _achievements()
	var state: int = achievements.state_of(achievement_id) if achievements != null \
		else AchievementsScript.STATE_LOCKED

	_icon.texture = load(AchievementCatalog.icon_path(achievement_id))
	_title_label.text = entry.title
	_desc_label.text = AchievementCatalog.description_of(entry)

	var prize := String(entry.get("prize", ""))
	_prize_label.text = prize if prize != "" else "—"

	_progress_label.visible = not (entry.kind in _ONE_SHOT_KINDS)
	if _progress_label.visible and achievements != null:
		var frac: Vector2i = achievements.progress_fraction_of(achievement_id)
		_progress_label.text = "%d / %d" % [frac.x, frac.y]

	_claim_button.visible = state == AchievementsScript.STATE_UNLOCKED
	_lock_icon.visible = state == AchievementsScript.STATE_LOCKED
	_claimed_label.visible = state == AchievementsScript.STATE_CLAIMED


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _on_back_pressed() -> void:
	close()


func _on_claim_pressed() -> void:
	claim_requested.emit(achievement_id)


## Notifications reach every node in the tree, so this alone does not stop
## the host screen's own WM_GO_BACK_REQUEST handler from also firing --
## Task 5's achievements_screen.gd must check whether this sheet is open
## (mirroring Scripts/Inventory/inventory.gd's `_sheet != null` guard)
## before acting on its own back request.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _open:
		close()


func _exit_tree() -> void:
	var achievements := _achievements()
	if achievements != null and achievements.state_changed.is_connected(_refresh_content):
		achievements.state_changed.disconnect(_refresh_content)


func _achievements() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Achievements")
