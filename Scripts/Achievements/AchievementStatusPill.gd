@tool
class_name AchievementStatusPill
extends Button

## The Achievements screen header's morphing status pill (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 4,
## "Header — one morphing pill + filter button"). Two states are authored
## as sibling nodes in AchievementStatusPill.tscn (no runtime construction):
##
## - IDLE (no unclaimed prize): cream background, "%d / %d dibuka" text plus
##   a 24-segment dash bar. The catalog has 26 entries but the bar is
##   authored with 24 segments (a round number that still reads cleanly at
##   pill width) — filled count is `round(claimed / total * 24)`, so the
##   bar is an approximate visual, not a 1:1 tally of entries.
## - WAITING (`Achievements.total_unclaimed_count() > 0`): green background,
##   coin icon, "%d hadiah belum diambil" text, and a slow breathe loop.
##
## refresh() reads Achievements' live counters and morphs between the two
## states with one crossfade + scale-pop Tween (~250 ms); the breathe loop
## is a separate looping Tween that only runs while WAITING. Tap emits
## jump_requested, but only in WAITING (Task 5 wires it to scroll the grid
## to Achievements.first_unclaimed_id()).
##
## @tool so tests can instance and drive this directly; _ready() connects
## to the live Achievements autoload's state_changed signal but touches no
## scene state when the node is part of the currently-edited scene.

## Segments in the IDLE dash bar (authored in the .tscn, not built here).
const DASH_SEGMENT_COUNT := 24
## Morph crossfade + scale-pop duration.
const MORPH_DURATION := 0.25
## Breathe loop half-cycle duration (1.0 -> 1.03 -> 1.0 is two halves).
const BREATHE_DURATION := 1.6
const BREATHE_SCALE := 1.03
const MORPH_POP_SCALE := 1.08

## Emitted on tap while in the WAITING state only. Task 5 connects this to
## scroll the grid to the first unclaimed achievement.
signal jump_requested

@onready var idle_state: PanelContainer = %IdleState
@onready var waiting_state: PanelContainer = %WaitingState
@onready var idle_label: Label = %IdleLabel
@onready var waiting_label: Label = %WaitingLabel
@onready var coin_icon: TextureRect = %CoinIcon
@onready var dash_bar: HBoxContainer = %DashBar

var _initialized: bool = false
var _is_waiting: bool = false
var _last_claimed: int = 0
var _last_total: int = 0
var _last_waiting_count: int = 0
var _morph_tween: Tween
var _breathe_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	set_meta(Juice.NO_AUTO_JUICE, true)
	Juice.set_pivot_center(self)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	var achievements := _achievements()
	if achievements != null and not achievements.state_changed.is_connected(_on_state_changed):
		achievements.state_changed.connect(_on_state_changed)
	refresh(false)


func _exit_tree() -> void:
	var achievements := _achievements()
	if achievements != null and achievements.state_changed.is_connected(_on_state_changed):
		achievements.state_changed.disconnect(_on_state_changed)


## The pill's size is 0 in _ready (layout hasn't run yet), so the initial
## set_pivot_center there can pop from the corner. Re-centre whenever the
## node's size actually settles, so a later resize (e.g. the label's first
## text assignment changing the pill's width) keeps the pivot correct too.
func _on_resized() -> void:
	Juice.set_pivot_center(self)


func _on_state_changed() -> void:
	refresh(true)


func _on_pressed() -> void:
	if _is_waiting:
		jump_requested.emit()


## True while the pill is showing the WAITING (unclaimed-prize) state.
func is_waiting() -> bool:
	return _is_waiting


## True while a morph tween is actively running. Exposed so tests can
## confirm refresh(false) never starts one.
func is_morphing() -> bool:
	return _morph_tween != null and _morph_tween.is_valid()


## Re-reads Achievements' counters and applies the matching state.
## `animate` false snaps content and state instantly (used by _ready's
## first call, and by callers that want a deterministic redraw with no
## tween in flight).
func refresh(animate: bool = true) -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	var achievements := _achievements()
	var claimed: int = achievements.total_claimed_count() if achievements != null else 0
	var total: int = achievements.total_count() if achievements != null else 0
	var waiting_count: int = achievements.total_unclaimed_count() if achievements != null else 0
	var waiting := waiting_count > 0
	var do_animate := animate and _initialized

	_apply_idle_content(claimed, total, do_animate)
	_apply_waiting_content(waiting_count, do_animate)
	_apply_state(waiting, do_animate)

	_last_claimed = claimed
	_last_total = total
	_last_waiting_count = waiting_count
	_initialized = true


func _apply_idle_content(claimed: int, total: int, animate: bool) -> void:
	_update_dash_bar(claimed, total)
	if animate and claimed != _last_claimed:
		Juice.count_up_formatted(idle_label, float(_last_claimed), float(claimed),
			func(v: float) -> String: return "%d / %d dibuka" % [int(round(v)), total])
	else:
		idle_label.text = "%d / %d dibuka" % [claimed, total]


func _apply_waiting_content(count: int, animate: bool) -> void:
	if animate and count != _last_waiting_count:
		Juice.count_up_formatted(waiting_label, float(_last_waiting_count), float(count),
			func(v: float) -> String: return "%d hadiah belum diambil" % int(round(v)))
	else:
		waiting_label.text = "%d hadiah belum diambil" % count


func _update_dash_bar(claimed: int, total: int) -> void:
	var filled := 0
	if total > 0:
		filled = int(round(float(claimed) / float(total) * DASH_SEGMENT_COUNT))
	filled = clampi(filled, 0, DASH_SEGMENT_COUNT)
	var i := 0
	for seg in dash_bar.get_children():
		seg.theme_type_variation = &"AchievementDashSegmentFilled" if i < filled \
			else &"AchievementDashSegmentEmpty"
		i += 1


func _apply_state(waiting: bool, animate: bool) -> void:
	if not animate:
		_kill_morph()
		_kill_breathe()
		idle_state.visible = not waiting
		waiting_state.visible = waiting
		idle_state.modulate.a = 1.0
		waiting_state.modulate.a = 1.0
		scale = Vector2.ONE
		_is_waiting = waiting
		if waiting:
			_start_breathe()
		return

	if waiting == _is_waiting:
		return

	_kill_morph()
	_kill_breathe()
	Juice.set_pivot_center(self)
	scale = Vector2.ONE

	var showing := waiting_state if waiting else idle_state
	var hiding := idle_state if waiting else waiting_state
	showing.modulate.a = 0.0
	showing.visible = true
	hiding.visible = true

	_morph_tween = create_tween()
	_morph_tween.set_parallel(true)
	_morph_tween.tween_property(showing, "modulate:a", 1.0, MORPH_DURATION)
	_morph_tween.tween_property(hiding, "modulate:a", 0.0, MORPH_DURATION)
	_morph_tween.tween_property(self, "scale", Vector2(MORPH_POP_SCALE, MORPH_POP_SCALE), MORPH_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE)
	_morph_tween.chain().tween_property(self, "scale", Vector2.ONE, MORPH_DURATION / 2.0) \
		.set_trans(Tween.TRANS_SINE)
	_morph_tween.finished.connect(_on_morph_finished.bind(hiding, waiting))


func _on_morph_finished(hiding: Control, waiting: bool) -> void:
	hiding.visible = false
	hiding.modulate.a = 1.0
	_is_waiting = waiting
	if waiting:
		_start_breathe()


func _start_breathe() -> void:
	Juice.set_pivot_center(self)
	_kill_breathe()
	_breathe_tween = create_tween()
	_breathe_tween.set_loops()
	_breathe_tween.set_trans(Tween.TRANS_SINE)
	_breathe_tween.tween_property(self, "scale", Vector2(BREATHE_SCALE, BREATHE_SCALE), BREATHE_DURATION)
	_breathe_tween.tween_property(self, "scale", Vector2.ONE, BREATHE_DURATION)


func _kill_breathe() -> void:
	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()
	_breathe_tween = null
	scale = Vector2.ONE


func _kill_morph() -> void:
	if _morph_tween != null and _morph_tween.is_valid():
		_morph_tween.kill()
	_morph_tween = null


func _achievements() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Achievements")
