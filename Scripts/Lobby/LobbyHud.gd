@tool
class_name LobbyHud
extends Control

## The Lobby's bottom HUD (2026-09-27 scrapbook HUD spec §4): the stepped
## book (JADWAL on the raised block, three tiles on the shelf) and the icon
## rail. It swipes away as a whole: the book slides down to its chevron
## peek and the rail slides off the right edge in the same tween (Q5); the
## chevron, a vertical drag on the book, or a double tap anywhere brings
## it back. While hidden the book's buttons ignore input, so the peeking
## top of JADWAL cannot be pressed by a reopening tap. It also plays the
## entrance, JADWAL's breathe and the roster-count chip. It stays
## inactive until the Lobby calls activate(), so the tutorial's spotlight
## never measures a moving target. Calls come
## down from Lobby.gd; nothing here reaches up. @tool so the lobby_hud
## suite can drive it: _ready wires its own signals ungated and the
## autoload ones only in game, and every writer runs from the non-@tool
## Lobby or a suite's own instance. It also keeps the three notification
## badges (spec §5) in step with the gift, achievements and inventory.

## The chip's line: the approved roster's size.
const ROSTER_CHIP_FORMAT := "%d murid"
## The chevron's turn when the book is hidden, degrees.
const CHEVRON_HIDDEN_DEGREES := 180.0
## Seconds of one bob's rise, and again of its fall.
const PEEK_BOB_STEP_SECONDS := 0.18

@export_group("Swipe")
## Seconds the book and rail take to slide (TRANS_BACK overshoot, "Feel A").
@export var slide_seconds: float = 0.45
## Book height, px, left showing when hidden: the chevron grip's peek.
@export var peek_pixels: float = 96.0
## How far, px, the rail slides right to leave the screen.
@export var rail_slide_pixels: float = 180.0
## Vertical drag, px, on the book that counts as a swipe.
@export var swipe_threshold_pixels: float = 80.0
## Seconds the chevron's turn trails the book, to sell the hinge.
@export var chevron_delay_seconds: float = 0.08
@export_group("Idle")
## Seconds between two bobs of the peeking chevron while hidden.
@export var peek_bob_interval_seconds: float = 3.0
## Height, px, of the peeking chevron's bob.
@export var peek_bob_pixels: float = 8.0
## One JADWAL breathe (in and out), seconds (spec §4: ~1.8 s).
@export var breathe_period_seconds: float = 1.8
## RaisedPage's scale at the top of a breath. The page, not the button:
## UIPolish's press and the Lobby's hover already tween the button's scale.
@export var breathe_scale: float = 1.03
## Seconds the "Ketuk dua kali" hint stays up after a hide.
@export var hint_seconds: float = 1.5
@export_group("")

## False while the book and rail are swiped away.
var is_open: bool = true
## False until the Lobby calls activate(): no swipe, entrance or breathe.
var is_active: bool = false
## Asked before a double tap reopens the HUD; the Lobby answers false while
## a popup owns the screen. Unset, a double tap always may.
var can_reopen: Callable
var _book_open_y: float = 0.0
var _rail_open_x: float = 0.0
var _glyph_rest_y: float = 0.0
## Where a press on the book began, in its own frame; NAN when no drag.
var _drag_start_y: float = NAN
## True while the press in progress is a double tap's second half: the
## chevron's release then skips, because the first half already toggled.
var _press_is_second_tap: bool = false
var _slide: Tween
var _peek_bob: Tween
var _breathe: Tween
var _hint_timer: Tween

@onready var book_hud: Control = %BookHud
@onready var raised_block: Control = %RaisedBlock
@onready var raised_page: Control = %RaisedPage
@onready var shelf: Control = %Shelf
@onready var koperasi: Control = %Koperasi
@onready var inventory: Control = %Inventory
@onready var report_student: Control = %ReportStudent
@onready var icon_rail: Control = %IconRail
@onready var chevron_grip: Button = %ChevronGrip
@onready var chevron_glyph: Control = %ChevronGlyph
@onready var roster_chip: Control = %RosterChip
@onready var roster_chip_label: Label = %RosterChipLabel
@onready var hint: Label = %HudHint
@onready var daily_badge: NotifBadge = %DailyBadge
@onready var achievement_badge: NotifBadge = %AchievementBadge
@onready var inventory_badge: NotifBadge = %InventoryBadge


## Its own signals ungated so the suite can exercise them; the autoload
## ones are side effects, so only a running game connects them.
func _ready() -> void:
	chevron_grip.pressed.connect(_on_chevron_pressed)
	raised_block.gui_input.connect(_on_book_gui_input)
	shelf.gui_input.connect(_on_book_gui_input)
	if Engine.is_editor_hint():
		return
	Achievements.state_changed.connect(_refresh_counts)
	GameState.inventory_changed.connect(_refresh_counts)
	GameSettings.reduce_motion_changed.connect(_on_reduce_motion_changed)


## Turns the swipe on; the entrance (tiles drop in, staggered) plays only
## when asked, then JADWAL breathes. The open rest positions are read at
## each hide that does not interrupt a slide, once layout has settled.
func activate(with_entrance: bool) -> void:
	is_active = true
	if with_entrance and not GameSettings.reduce_motion:
		Juice.stagger_in([koperasi, inventory, report_student])
	_update_breathe()


## Slides the book and rail away (false) or back (true). Under
## reduce_motion it lands at once, which is also what the suite tests.
func set_open(open: bool) -> void:
	if open == is_open:
		return
	if not open and not _is_sliding():
		_book_open_y = book_hud.position.y
		_rail_open_x = icon_rail.position.x
	is_open = open
	_kill(_slide)
	_stop_peek_bob()
	_set_book_live(open)
	_update_breathe()
	if open:
		_hide_hint()
	var book_y: float = _book_open_y if open else _book_open_y + book_hud.size.y - peek_pixels
	var rail_x: float = _rail_open_x if open else _rail_open_x + rail_slide_pixels
	var chevron_degrees: float = 0.0 if open else CHEVRON_HIDDEN_DEGREES
	if not GameSettings.reduce_motion:
		_slide_to(book_y, rail_x, chevron_degrees)
		return
	book_hud.position.y = book_y
	icon_rail.position.x = rail_x
	chevron_glyph.rotation_degrees = chevron_degrees
	if not open:
		_show_hint()


## The roster chip (hidden with an empty roster) and the three badges.
## The Lobby passes whether today's gift is still unclaimed, because its
## DailyLoginPanel is the one that knows.
func refresh(is_daily_claimable: bool) -> void:
	var count: int = GameState.approved_students.size()
	roster_chip.visible = count > 0
	roster_chip_label.text = ROSTER_CHIP_FORMAT % count
	daily_badge.set_count(1 if is_daily_claimable else 0)
	_refresh_counts()


## What the chatter must not treat as a tap on a face.
func tap_blockers() -> Array[Control]:
	return [raised_block, shelf, chevron_grip, icon_rail]


## The badges that follow autoload state. The daily badge is left alone:
## only the Lobby's refresh() knows whether the gift is claimable.
func _refresh_counts() -> void:
	achievement_badge.set_count(Achievements.total_unclaimed_count())
	inventory_badge.set_count(_inventory_count())


## Every item in the bag, counted by quantity rather than by kind.
func _inventory_count() -> int:
	var total: int = 0
	for quantity: int in GameState.inventory.values():
		total += quantity
	return total


## A double tap anywhere reopens a hidden HUD. _input, like LobbyChatter,
## sees each press before any GUI node, and notes whether it is a double
## tap's second half for the chevron. Only a reopening tap is marked
## handled, so it cannot also press whatever it landed on.
func _input(event: InputEvent) -> void:
	if not is_active or not _is_press(event):
		return
	_press_is_second_tap = _is_double_tap(event)
	if is_open or not _press_is_second_tap or not _reopen_allowed():
		return
	set_open(true)
	get_viewport().set_input_as_handled()


func _reopen_allowed() -> bool:
	return not can_reopen.is_valid() or can_reopen.call()


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.is_pressed()
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


static func _is_double_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).double_tap
	var click := event as InputEventMouseButton
	return click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT


## One tap toggles. The second half of a double tap is skipped: its first
## half already toggled, and a second toggle would bounce the book.
func _on_chevron_pressed() -> void:
	if not is_active or _press_is_second_tap:
		return
	set_open(not is_open)


## Hidden, the book's buttons ignore input (the peek shows JADWAL's top);
## the chevron, a sibling of the book, stays live to bring it back.
func _set_book_live(live: bool) -> void:
	var behavior: Control.MouseBehaviorRecursive = Control.MOUSE_BEHAVIOR_INHERITED
	if not live:
		behavior = Control.MOUSE_BEHAVIOR_DISABLED
	for part: Control in [raised_page, koperasi, inventory, report_student]:
		part.mouse_behavior_recursive = behavior


## Settings or the debug overlay flipped reduce_motion: the loops follow.
func _on_reduce_motion_changed(_still: bool) -> void:
	_update_breathe()
	if is_active and not is_open:
		_start_peek_bob()


## A vertical drag on the book past swipe_threshold_pixels: down hides, up
## reopens. Only the book's own margins see it; its buttons keep their taps.
func _on_book_gui_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var pressed: bool = event.get("pressed")
		var at: Vector2 = event.get("position")
		_drag_start_y = at.y if pressed else NAN
		return
	var is_drag: bool = event is InputEventMouseMotion or event is InputEventScreenDrag
	if not is_drag or is_nan(_drag_start_y):
		return
	var now: Vector2 = event.get("position")
	var travel: float = now.y - _drag_start_y
	if absf(travel) < swipe_threshold_pixels:
		return
	_drag_start_y = NAN
	set_open(travel < 0.0)


## One parallel TRANS_BACK tween for book and rail; the chevron's turn
## trails by chevron_delay_seconds, and the landing fires once all settle.
func _slide_to(book_y: float, rail_x: float, chevron_degrees: float) -> void:
	_slide = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slide.tween_property(book_hud, "position:y", book_y, slide_seconds)
	_slide.tween_property(icon_rail, "position:x", rail_x, slide_seconds)
	_slide.tween_property(chevron_glyph, "rotation_degrees", chevron_degrees,
		slide_seconds).set_delay(chevron_delay_seconds)
	_slide.chain().tween_callback(_on_slide_landed)


## Open lands with a squash; hidden shows the hint and starts the bob.
func _on_slide_landed() -> void:
	if is_open:
		AnimUtils.squash_bounce(book_hud)
		return
	_show_hint()
	_start_peek_bob()


func _is_sliding() -> bool:
	return _slide != null and _slide.is_running()


## "Ketuk dua kali untuk buka HUD." for hint_seconds: popped, or simply
## shown and hidden under reduce_motion.
func _show_hint() -> void:
	_kill(_hint_timer)
	hint.show()
	if not GameSettings.reduce_motion:
		AnimUtils.message_pop(hint, hint_seconds)
		return
	hint.modulate.a = 1.0
	_hint_timer = create_tween()
	_hint_timer.tween_interval(hint_seconds)
	_hint_timer.tween_callback(hint.hide)


func _hide_hint() -> void:
	_kill(_hint_timer)
	hint.hide()


## While hidden, the peeking chevron rises and falls every
## peek_bob_interval_seconds. Off under reduce_motion; a zero interval
## would make the looped tween spin, so it is off then too.
func _start_peek_bob() -> void:
	_stop_peek_bob()
	if GameSettings.reduce_motion or peek_bob_interval_seconds <= 0.0:
		return
	_glyph_rest_y = chevron_glyph.position.y
	_peek_bob = create_tween().set_loops() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_peek_bob.tween_interval(peek_bob_interval_seconds)
	_peek_bob.tween_property(chevron_glyph, "position:y",
		_glyph_rest_y - peek_bob_pixels, PEEK_BOB_STEP_SECONDS)
	_peek_bob.tween_property(chevron_glyph, "position:y",
		_glyph_rest_y, PEEK_BOB_STEP_SECONDS)


## Stops the bob and puts the chevron back where it rests.
func _stop_peek_bob() -> void:
	if _peek_bob == null:
		return
	_kill(_peek_bob)
	_peek_bob = null
	chevron_glyph.position.y = _glyph_rest_y


## JADWAL's slow breathe on RaisedPage, looped, only while the HUD is
## active and open. Off under reduce_motion, and off for a zero period,
## which would make the looped tween spin. A stop leaves the page at rest.
func _update_breathe() -> void:
	_kill(_breathe)
	raised_page.scale = Vector2.ONE
	if not is_active or not is_open:
		return
	if GameSettings.reduce_motion or breathe_period_seconds <= 0.0:
		return
	Juice.set_pivot_center(raised_page)
	var half: float = breathe_period_seconds * 0.5
	_breathe = create_tween().set_loops() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe.tween_property(raised_page, "scale", Vector2.ONE * breathe_scale, half)
	_breathe.tween_property(raised_page, "scale", Vector2.ONE, half)


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
