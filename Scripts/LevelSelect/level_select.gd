@tool
extends Control

## The grade picker: a fan of amplop coklat (brown envelopes), one per grade,
## that the player swipes through and opens like an assignment. It replaced
## CutScene's runtime-built "PILIH TINGKAT KELAS" modal. Presentation only:
## it sets GameState's grade and hands off, with no gameplay or balance change.
## Spec: docs/superpowers/specs/2026-09-25-amplop-level-select-design.md.
##
## Flow decisions (plan Task 0, resolved 2026-09-25):
## - Placement: MainMenu wipes here while GameState.is_level_select_enabled()
##   (the game is beaten, or the persisted Debug Level Select toggle is on),
##   else straight to CutScene. On accept this screen wipes into CutScene,
##   which plays the intro as before. CutScene's Debug toggle, switched on,
##   comes back here.
## - Roster size: real, StudentCard's max_approve_for() (2/3/4); read, not copied.
## - Grade setter: GameState.set_grade(), the call CutScene's modal made.
##
## Three redundant ways to change grade: swipe across the fan, tap a side
## envelope, or the arrows. Tapping the centred envelope or Buka Map Ini
## opens the confirmation. The fan is laid out by _layout_cards() from the
## @export knobs below, in the editor too, since the cards' instanced roots
## are bare anchors a plain Control would not place.
##
## @tool so the MCP test suite can stand the scene up; runtime-only side
## effects are gated behind Engine.is_editor_hint() in _ready().

const _STUDENT_CARD := preload("res://Scripts/StudentCard/student_card.gd")
const _AMPLOP_CARD := preload("res://Scripts/LevelSelect/AmplopCard.gd")

## Where accepting an assignment goes: the intro, as MainMenu's tap did.
const NEXT_SCENE := "res://Scenes/CutScene/cut_scene.tscn"
## A roster name's default portrait; StudentSkins swaps in the worn skin's.
const PORTRAIT_PATH := "res://Assets/Images/MuridPotrait/%s.png"

## Seconds of the shuffle-and-bounce as the fan re-clusters.
const SHUFFLE_SEC := 0.5
## Idle bob: how far each envelope rises and the seconds each way.
const BOB_RISE := 10.0
const BOB_HALF_SEC := 1.3
## Stagger between the three envelopes' bobs, so they never move in step.
const BOB_STAGGER_SEC := 0.45
## The centred envelope's attention-hop after each bob: height, then a
## smaller rebound, in seconds per leg.
const HOP_RISE := 44.0
const HOP_REBOUND := 16.0
const HOP_LEG_SEC := 0.16

## The three playable grades, left to right in the fan.
const GRADES: Array[int] = [7, 8, 9]

## Presentational difficulty word per grade, shown INSTEAD of the raw target
## number so the player weighs the challenge by feel. Honest because study
## days needed vs. days given tightens each grade (about 50%, 32%, 25% rest
## slack; per-day study points drop 3.0/2.5/2.0 while the target climbs).
## Rationale in the spec, section 4.
const DIFFICULTY_WORD := {7: "santai", 8: "menantang", 9: "susah"}

## Gauge fill fraction (0..1) matching DIFFICULTY_WORD. The colour climbs
## state_success, state_warning, state_danger with it (see _gauge_color).
const DIFFICULTY_FILL := {7: 0.50, 8: 0.68, 9: 0.75}

## The briefing card's tag pill per grade.
const TAG_TEXT := {7: "Ramah pemula", 8: "Menengah", 9: "Ujian akhir"}

## The surat tugas's closing sentence per grade, after the pupil and week
## counts. Never the raw target number -- the mystery is intentional.
const BRIEF_FLAVOR := {
	7: "Target paling ringan, cocok untuk memulai.",
	8: "Targetnya naik jauh; waktumu makin sempit.",
	9: "Target tertinggi, hampir tanpa jeda istirahat.",
}


## Weeks a grade runs -- the player's available time. Owned by Balance.gd.
static func weeks_for(grade: int) -> int:
	match grade:
		8: return Balance.JUMLAH_MINGGU_KELAS_8
		9: return Balance.JUMLAH_MINGGU_KELAS_9
		_: return Balance.JUMLAH_MINGGU_KELAS_7


## Points each subject must gain to clear a target. Owned by Balance.gd.
static func target_for(grade: int) -> int:
	match grade:
		8: return int(Balance.TARGET_KENAIKAN_KELAS_8)
		9: return int(Balance.TARGET_KENAIKAN_KELAS_9)
		_: return int(Balance.TARGET_KENAIKAN_KELAS_7)


## How many pupils the grade's roster holds -- StudentCard's own count.
static func roster_size_for(grade: int) -> int:
	return _STUDENT_CARD.max_approve_for(grade)


## Horizontal distance between neighbouring envelopes in the fan.
@export var fan_step_x: float = 130.0:
	set(value):
		fan_step_x = value
		_layout_cards(false)
## How far each step out from the centre drops an envelope.
@export var fan_drop_y: float = 34.0:
	set(value):
		fan_drop_y = value
		_layout_cards(false)
## Rotation per step out from the centre, in degrees.
@export var fan_step_degrees: float = 8.0:
	set(value):
		fan_step_degrees = value
		_layout_cards(false)
## Scale of the envelopes either side of the centred one.
@export var side_scale: float = 0.86:
	set(value):
		side_scale = value
		_layout_cards(false)
## Gap between the centred envelope's bottom edge and the Stack's.
@export var fan_bottom_margin: float = 60.0:
	set(value):
		fan_bottom_margin = value
		_layout_cards(false)
## Shortest horizontal drag, in pixels, that counts as a swipe.
@export var swipe_min_px: float = 80.0

@onready var _tokens: DesignTokens = DesignTokens.load_default()
@onready var _stack: Control = $Safe/UI/Stack
@onready var _prev: Button = $Safe/UI/Stack/PrevArrow
@onready var _next: Button = $Safe/UI/Stack/NextArrow
@onready var _brief_title: Label = %BriefTitle
@onready var _tag: Button = %Tag
@onready var _pupils_box: Control = %Pupils
@onready var _pupils_value: Label = %PupilsValue
@onready var _week_grid: Control = %WeekGrid
@onready var _weeks_value: Label = %WeeksValue
@onready var _diff_bar: TextureProgressBar = %DiffBar
@onready var _diff_label: Label = %DiffLabel
@onready var _open_button: Button = %OpenButton
@onready var _confirm: Control = $Confirm

## The three AmplopCards in grade order, gathered from the Stack in _ready.
var _cards: Array[Control] = []
## Index into GRADES of the centred envelope.
var _selected := 0
var _fan_tween: Tween
var _idle_tweens: Array[Tween] = []
## Where the current touch went down, or null outside the fan.
var _swipe_from: Variant = null
## Set when a release finished a swipe, so the card tap it lands on is ignored.
var _swiped := false
var _committed := false


func _ready() -> void:
	for child in _stack.get_children():
		if child.get_script() == _AMPLOP_CARD:
			_cards.append(child)
	_cards.sort_custom(func(a: Control, b: Control) -> bool: return a.grade < b.grade)
	for card in _cards:
		card.picked.connect(_on_card_picked)
	_prev.pressed.connect(_on_prev)
	_next.pressed.connect(_on_next)
	_open_button.pressed.connect(_open_confirm)
	_confirm.accepted.connect(_on_accept)
	_confirm.cancelled.connect(_on_cancel)
	_stack.resized.connect(func() -> void: _layout_cards(false))
	_tint_icons()

	if not Engine.is_editor_hint():
		var start := GRADES.find(GameState.current_grade)
		if start >= 0:
			_selected = start
	_render_brief()
	_layout_cards(false)
	if Engine.is_editor_hint():
		return
	_start_idle()


# ── Briefing card ────────────────────────────────────────────────────────────

## The grade currently centred in the fan.
func _selected_grade() -> int:
	return GRADES[_selected]


## Repaint the briefing card for the centred grade: pupil heads, week grid,
## difficulty gauge and word, and which arrows still lead anywhere.
func _render_brief() -> void:
	var g := _selected_grade()
	_brief_title.text = "Kelas %d" % g
	_tag.text = TAG_TEXT[g]
	var n := roster_size_for(g)
	var heads := _pupils_box.get_children()
	for i in range(heads.size()):
		heads[i].visible = i < n
	_pupils_value.text = "%d murid" % n
	var w := weeks_for(g)
	var cells := _week_grid.get_children()
	for i in range(cells.size()):
		cells[i].self_modulate = _week_filled_color() if i < w else _week_empty_color()
	_weeks_value.text = "%d minggu" % w
	_diff_bar.value = DIFFICULTY_FILL[g]
	_diff_bar.tint_progress = _gauge_color(g)
	_diff_label.text = DIFFICULTY_WORD[g]
	_prev.disabled = _selected == 0
	_next.disabled = _selected == GRADES.size() - 1


## Test hook: how many week cells are painted as weeks of the grade.
func _week_grid_filled() -> int:
	var n := 0
	for c in _week_grid.get_children():
		if (c as CanvasItem).self_modulate == _week_filled_color():
			n += 1
	return n


## The gauge colour climbs with the difficulty word.
func _gauge_color(grade: int) -> Color:
	match grade:
		8: return _tokens.state_warning
		9: return _tokens.state_danger
		_: return _tokens.state_success


func _week_filled_color() -> Color:
	return _tokens.brand_primary


func _week_empty_color() -> Color:
	return _tokens.text_disabled


## The white icon art takes its ink from tokens, like RosterAvatar's ring.
func _tint_icons() -> void:
	for head in _pupils_box.get_children():
		(head as CanvasItem).self_modulate = _tokens.text_primary
	_diff_bar.tint_under = _tokens.text_disabled


## The surat tugas's line: counts, the difficulty word, never the target.
func _brief_line(grade: int) -> String:
	return "%d murid, %d minggu, tingkat %s. %s" % [
		roster_size_for(grade), weeks_for(grade), DIFFICULTY_WORD[grade],
		BRIEF_FLAVOR[grade]]


# ── The fan ──────────────────────────────────────────────────────────────────

## Centre the envelope at `index` into GRADES (clamped), repaint the brief,
## and shuffle the fan into its new pose.
func _select(index: int) -> void:
	var clamped := clampi(index, 0, GRADES.size() - 1)
	if clamped == _selected:
		return
	_selected = clamped
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"card_flip")
	_render_brief()
	_layout_cards(true)
	if not Engine.is_editor_hint():
		_start_idle()


## Pose every envelope relative to the centred one. Animated, each springs
## to its pose with a TRANS_BACK overshoot (shuffle-and-bounce); otherwise it
## snaps. The centred card moves to the front of the draw AND input order --
## Controls take taps by tree order, not z_index.
func _layout_cards(animate: bool) -> void:
	if not is_node_ready() or _cards.is_empty():
		return
	var origin := Vector2(_stack.size.x * 0.5, _stack.size.y - fan_bottom_margin)
	var by_depth := _cards.duplicate()
	by_depth.sort_custom(func(a: Control, b: Control) -> bool:
		return absi(_cards.find(a) - _selected) > absi(_cards.find(b) - _selected))
	for i in range(by_depth.size()):
		_stack.move_child(by_depth[i], i)
	if _fan_tween != null and _fan_tween.is_valid():
		_fan_tween.kill()
	if animate:
		_fan_tween = create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(_cards.size()):
		var card := _cards[i]
		var d := i - _selected
		var pos := origin + Vector2(d * fan_step_x, absi(d) * fan_drop_y)
		var rot := deg_to_rad(d * fan_step_degrees)
		var scl := Vector2.ONE if d == 0 else Vector2(side_scale, side_scale)
		card.set_focused(d == 0)
		if animate:
			_fan_tween.tween_property(card, "position", pos, SHUFFLE_SEC)
			_fan_tween.tween_property(card, "rotation", rot, SHUFFLE_SEC)
			_fan_tween.tween_property(card, "scale", scl, SHUFFLE_SEC)
		else:
			card.position = pos
			card.rotation = rot
			card.scale = scl


## Every envelope bobs gently, out of step; the centred one also hops after
## each bob so the screen reads as touchable. Drives each card's Bob pivot,
## never its root, so it cannot fight the fan pose. Restarted per selection.
func _start_idle() -> void:
	for tw in _idle_tweens:
		tw.kill()
	_idle_tweens.clear()
	for i in range(_cards.size()):
		var card := _cards[i]
		var bob: Control = card.bob
		var rest: float = card.bob_rest_y
		bob.position.y = rest
		var tw := bob.create_tween().set_loops()
		tw.tween_interval(i * BOB_STAGGER_SEC)
		tw.tween_property(bob, "position:y", rest - BOB_RISE, BOB_HALF_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bob, "position:y", rest, BOB_HALF_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if i == _selected:
			tw.tween_property(bob, "position:y", rest - HOP_RISE, HOP_LEG_SEC) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(bob, "position:y", rest, HOP_LEG_SEC) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(bob, "position:y", rest - HOP_REBOUND, HOP_LEG_SEC) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(bob, "position:y", rest, HOP_LEG_SEC) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_idle_tweens.append(tw)


# ── Input ────────────────────────────────────────────────────────────────────

func _on_card_picked(grade: int) -> void:
	if _swiped:
		_swiped = false
		return
	var idx := GRADES.find(grade)
	if idx == _selected:
		_open_confirm()
	else:
		_select(idx)


func _on_prev() -> void:
	_select(_selected - 1)


func _on_next() -> void:
	_select(_selected + 1)


## A horizontal swipe across the fan steps one grade. Touch only: with both
## emulation settings on, every press also arrives as a mouse event, and a
## desktop click arrives as a touch, so this sees each gesture exactly once.
## _input (not gui_input) because the envelopes' HitButtons take the press.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _confirm.visible:
		return
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return
	if touch.pressed:
		_swiped = false
		var inside := _stack.get_global_rect().has_point(touch.position)
		_swipe_from = touch.position if inside else null
		return
	if _swipe_from == null:
		return
	var delta: Vector2 = touch.position - _swipe_from
	_swipe_from = null
	if absf(delta.x) >= swipe_min_px and absf(delta.x) > absf(delta.y):
		_swiped = true
		_select(_selected + (1 if delta.x < 0.0 else -1))


# ── Confirm and commit ───────────────────────────────────────────────────────

## Open the centred grade's envelope as the confirmation.
func _open_confirm() -> void:
	if _confirm.visible or _committed:
		return
	var g := _selected_grade()
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"pop")
	_confirm.present(g, _portraits_for(roster_size_for(g)), _brief_line(g))


## The first `n` of the cast, each in their worn skin. In the editor
## GameState (not @tool) holds no skins, so the default portraits stand in.
func _portraits_for(n: int) -> Array:
	var out: Array = []
	for student_name in StudentSkins.NAMES.slice(0, n):
		var student := {"name": student_name, "portrait": PORTRAIT_PATH % student_name}
		var path: String = student["portrait"] if Engine.is_editor_hint() \
			else StudentSkins.portrait_for(student)
		out.append(load(path))
	return out


func _on_cancel() -> void:
	AudioDirector.play_sfx(&"cancel")
	_confirm.dismiss()


## The player took the assignment: set the grade, then wipe into the intro.
func _on_accept(grade: int) -> void:
	if _committed:
		return
	_committed = true
	AudioDirector.play_sfx(&"confirm")
	GameState.set_grade(grade)
	Transition.change_scene(NEXT_SCENE, Transition.Style.WIPE)
