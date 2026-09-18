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

## Tint applied to the whole tile when its achievement is still locked.
@export var locked_modulate: Color = Color(1.0, 1.0, 1.0, 0.55)

@onready var icon: TextureRect = %Icon
@onready var lock_icon: TextureRect = %LockIcon
@onready var title_label: Label = %Title
@onready var prize_chip: PanelContainer = %PrizeChip
@onready var prize_label: Label = %PrizeLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var baru_badge: PanelContainer = %BaruBadge
@onready var check_badge: TextureRect = %CheckBadge

var achievement_id: String = ""

## Session-scoped: ids whose "BARU" pip has already played its pop_in this
## session, so re-entering the screen (or a state_changed refresh) does not
## replay the animation on every redraw. Static so it survives across tile
## instances (the grid recreates tiles each time the screen opens).
static var _baru_shown: Dictionary = {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
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


func _apply_prize(entry: Dictionary) -> void:
	var prize := String(entry.get("prize", ""))
	if prize == "":
		prize_label.text = "—"
		prize_chip.theme_type_variation = &"AchievementPrizeChip"
		prize_label.theme_type_variation = &"AchievementPrizeChipLabel"
	else:
		prize_label.text = prize
		prize_chip.theme_type_variation = &"AchievementPrizeChipAmber"
		prize_label.theme_type_variation = &"AchievementPrizeChipLabelAmber"


func _apply_state(state: int, progress: float) -> void:
	progress_bar.value = progress * 100.0

	var locked := state == AchievementsScript.STATE_LOCKED
	modulate = locked_modulate if locked else Color.WHITE
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
