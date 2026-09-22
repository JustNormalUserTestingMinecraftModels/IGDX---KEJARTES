@tool
class_name AchievementTile
extends PanelContainer

## One tile in the Achievements screen's 2-column grid (AchievementTile.tscn),
## replacing the old single-column AchievementRow. The screen fills it with
## setup(entry) and listens for tile_pressed to open the detail sheet (Task
## 3). refresh() re-reads live state/progress from the Achievements autoload
## so the screen can call it on Achievements.state_changed without redoing
## setup(). @tool so the test runner can drive it directly; it has no
## side effects of its own (the "BARU" pop-in dict is session-scoped data,
## not a scene mutation).
##
## Sizing: the root's size_flags_horizontal = 3 (EXPAND_FILL) so the parent
## GridContainer splits its width evenly between the two columns. Its
## custom_minimum_size.x (420) must fit two columns plus List's h_separation
## (24) inside Scroll's List width: Scroll is Safe/UI width (1080) minus its
## offset_left/right (84 + 83 = 167) = 913, minus Margin's 24px each side
## (48) = 865, so each column gets (865 - 24) / 2 = 420.5px — 420 fits with
## room to spare.

## Filter values matches_filter() understands (mirrors the plan's filter
## OptionButton, Task 5's screen wires the options to these).
enum Filter { SEMUA, BELUM_DIBUKA, SUDAH_DIBUKA, BELUM_DIAMBIL }

signal tile_pressed(id: String)

const AchievementsScript := preload("res://Scripts/Achievements/Achievements.gd")

## Tap-vs-scroll gesture threshold, in px: a release further than this from
## its matching press is a drag-scroll (26 tiles fill a ScrollContainer), not
## a tap, so it must not open the detail sheet. Mirrors the 20px guard
## Scripts/Inventory/InventorySlot.gd already uses for the same problem.
const TAP_MOVE_THRESHOLD := 16.0

## Tint applied to the ICON ONLY while the achievement is locked.
## Deliberately not on the tile root: fading the root took a locked title
## to 1.78:1 against its own card (measured live, 2026-09-22), under the
## 3.0 floor tests/test_bar_contrast.gd pins and far under the 4.5 body
## copy wants. Locked now reads from the greyed icon, the lock overlay on
## it, and the absent corner badge -- none of which is text.
@export var locked_icon_modulate: Color = Color(0.62, 0.62, 0.62, 1.0)

@onready var icon: TextureRect = %Icon
@onready var lock_icon: TextureRect = %LockIcon
@onready var title_label: Label = %Title
@onready var prize_chip: PanelContainer = %PrizeChip
@onready var prize_label: Label = %PrizeLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var baru_badge: PanelContainer = %BaruBadge
@onready var check_badge: TextureRect = %CheckBadge

var achievement_id: String = ""

## Global position of the press that started the current gesture, used by
## _gui_input to tell a tap from a drag-scroll on release.
var _press_pos: Vector2 = Vector2.ZERO

## Session-scoped: ids whose "BARU" pip has already played its pop_in this
## session, so re-entering the screen (or a state_changed refresh) does not
## replay the animation on every redraw. Static so it survives across tile
## instances (the grid recreates tiles each time the screen opens).
static var _baru_shown: Dictionary = {}


## Emits tile_pressed only on a clean tap: press then release with less than
## TAP_MOVE_THRESHOLD px of movement between them. A release on PRESS opened
## the detail sheet under every drag-scroll starting on a tile; this mirrors
## InventorySlot._on_gui_input's release+distance guard.
##
## Mouse-only by design: project.godot sets emulate_touch_from_mouse=true and
## emulate_mouse_from_touch defaults on, so every real tap already arrives as
## BOTH an InputEventScreenTouch (local `position`) and an emulated
## InputEventMouseButton (`global_position`). Handling both used to write
## _press_pos from two different coordinate spaces and only worked by luck of
## event ordering. Touch input reaches this via that emulation, so handling
## only the mouse path (and comparing global_position on both press and
## release) covers touch too without a double-fire risk.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.global_position
		elif _press_pos.distance_to(event.global_position) < TAP_MOVE_THRESHOLD:
			tile_pressed.emit(achievement_id)


## Fills the tile from catalog entry `entry` and the Achievements autoload's
## current state/progress for it.
func setup(entry: Dictionary) -> void:
	achievement_id = entry.id
	icon.texture = load(AchievementCatalog.icon_path(entry.id))
	title_label.text = entry.title
	_apply_prize(entry)
	refresh()


## Re-reads state and progress from the Achievements autoload for the id
## already set by setup(). Call this from the screen on
## Achievements.state_changed instead of calling setup() again.
func refresh() -> void:
	if achievement_id == "":
		return
	var achievements := _achievements()
	var state: int = achievements.state_of(achievement_id) if achievements != null \
		else AchievementsScript.STATE_LOCKED
	var progress: float = achievements.progress_of(achievement_id) if achievements != null \
		else 0.0
	_apply_state(state, progress)


func matches_filter(filter: int) -> bool:
	var achievements := _achievements()
	var state: int = achievements.state_of(achievement_id) if achievements != null \
		else AchievementsScript.STATE_LOCKED
	match filter:
		Filter.SEMUA:
			return true
		Filter.BELUM_DIBUKA:
			return state == AchievementsScript.STATE_LOCKED
		Filter.SUDAH_DIBUKA:
			return state == AchievementsScript.STATE_UNLOCKED or state == AchievementsScript.STATE_CLAIMED
		Filter.BELUM_DIAMBIL:
			return state == AchievementsScript.STATE_UNLOCKED
	return true


## Shows the prize chip only when the entry has one. Twenty of the 26
## catalogue entries set prize to "", and a chip reading "—" on 77% of the
## grid teaches nothing while costing the 38px the enlarged icon needs.
func _apply_prize(entry: Dictionary) -> void:
	var prize := String(entry.get("prize", ""))
	prize_chip.visible = prize != ""
	if not prize_chip.visible:
		return
	prize_label.text = prize
	prize_chip.theme_type_variation = &"AchievementPrizeChipAmber"
	prize_label.theme_type_variation = &"AchievementPrizeChipLabelAmber"


func _apply_state(state: int, progress: float) -> void:
	progress_bar.value = progress * 100.0

	var locked := state == AchievementsScript.STATE_LOCKED
	icon.modulate = locked_icon_modulate if locked else Color.WHITE
	lock_icon.visible = locked
	if locked:
		_baru_shown.erase(achievement_id)

	var unlocked := state == AchievementsScript.STATE_UNLOCKED
	baru_badge.visible = unlocked
	check_badge.visible = state == AchievementsScript.STATE_CLAIMED

	if unlocked and not _baru_shown.has(achievement_id):
		_baru_shown[achievement_id] = true
		if not Engine.is_editor_hint() and Engine.get_main_loop() != null:
			Juice.pop_in(baru_badge)


func _achievements() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Achievements")
