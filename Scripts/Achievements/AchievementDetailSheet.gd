@tool
class_name AchievementDetailSheet
extends Control

## The modal detail sheet opened when an AchievementTile is tapped (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 3,
## "Tap-to-expand"). Meant to be instanced ONCE into achievements.tscn and
## hidden until open_for() is called (Task 5's job).
##
## Shows the full-size icon, title, desc, an amber prize chip when the entry
## carries a prize, and a StateRow holding the numeric progress fraction
## ("2 / 3", from Achievements.progress_fraction_of) beside one state glyph:
## the lock (STATE_LOCKED), the notice icon (STATE_UNLOCKED) or the check
## (STATE_CLAIMED).
##
## Rebuilt 2026-09-22. The card used to be anchored 0.3-0.78 vertically, so
## it was 922px tall at 1080x1920 and 1152px at 1080x2400 for about 350px of
## content; it is now centred with GROW_DIRECTION_BOTH so it is exactly as
## tall as its content at any phone height. The stack moved from a 12px
## separation to space_lg (44).
##
## The fraction text is hidden for one-shot kinds (three_star/play_all/grade,
## whose target is always 1) -- "1 / 1" reads like a bug report, not
## progress, so those kinds show nothing there instead.
##
## Claim path: there is no Klaim button any more (2026-09-22). Opening this
## sheet on an achievement whose prize is waiting IS the claim -- see
## _emit_claim_if_unlocked. The sheet still does NOT call Achievements.claim
## itself: it emits claim_requested(id) and leaves the claim() call and the
## celebration popup to the host screen, which is what
## achievements_screen.gd's _on_claim_requested already did for the button.
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
@onready var _prize_chip: PanelContainer = %PrizeChip
@onready var _prize_chip_label: Label = %PrizeChipLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _state_icon: TextureRect = %StateIcon
@onready var _back_button: TextureButton = %BackButton

## The three state glyphs StateRow shows, one per Achievements state. The
## notice icon is the same asset the tile's corner badge wears, so a player
## who tapped a marked tile sees the same mark inside.
const _LOCK_ICON := preload("res://Assets/Images/UI/Placeholders/icon_lock.svg")
const _NOTICE_ICON := preload("res://Assets/Images/Achievements/notice_icon.png")
const _CHECK_ICON := preload("res://Assets/Images/UI/Placeholders/icon_check.svg")

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



## Shows the sheet filled with catalog entry `id`'s current state/progress.
func open_for(id: String) -> void:
	achievement_id = id
	_refresh_content()
	visible = true
	_open = true
	var achievements := _achievements()
	if achievements != null and not achievements.state_changed.is_connected(_refresh_content):
		achievements.state_changed.connect(_refresh_content)
	call_deferred("_emit_claim_if_unlocked")


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
	# entry.desc, NOT description_of(): that helper appended
	# "\nHadiah: <prize>" and the sheet then repeated the same string in a
	# label underneath it. The prize lives only in the chip now.
	_desc_label.text = entry.desc

	var prize := String(entry.get("prize", ""))
	_prize_chip.visible = prize != ""
	_prize_chip_label.text = prize

	_progress_label.visible = not (entry.kind in _ONE_SHOT_KINDS)
	if _progress_label.visible and achievements != null:
		var frac: Vector2i = achievements.progress_fraction_of(achievement_id)
		_progress_label.text = "%d / %d" % [frac.x, frac.y]

	match state:
		AchievementsScript.STATE_UNLOCKED:
			_state_icon.texture = _NOTICE_ICON
		AchievementsScript.STATE_CLAIMED:
			_state_icon.texture = _CHECK_ICON
		_:
			_state_icon.texture = _LOCK_ICON


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _on_back_pressed() -> void:
	close()


## Claiming has no button any more: opening this sheet on an achievement
## whose prize is still waiting IS the claim, and the tile's notice badge is
## what told the player the prize was there.
##
## Deferred from open_for() so the sheet is visible and laid out before the
## host screen's celebration popup lands on top of it. The sheet still does
## not call Achievements.claim itself -- it emits and lets
## achievements_screen.gd's _on_claim_requested do the claim, the sfx and
## the popup, exactly as the old button did. Achievements.claim() returns
## false for any state that cannot be claimed, so re-opening a sheet that is
## mid-claim cannot double-claim.
func _emit_claim_if_unlocked() -> void:
	if not _open or achievement_id == "":
		return
	var achievements := _achievements()
	if achievements == null:
		return
	if achievements.state_of(achievement_id) != AchievementsScript.STATE_UNLOCKED:
		return
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
