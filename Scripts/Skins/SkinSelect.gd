@tool
class_name SkinSelect
extends Control

## The Lobby's skin picker (SkinSelect.tscn; mockup skinselection_mockup.png,
## spec docs/superpowers/specs/2026-09-22-skin-select-screen-design.md).
## A full-screen surface over a blurred Lobby: the open character's splash in
## a horizontal carousel of their skins, a rail of all six characters
## underneath, and one TERAPKAN button.
##
## It stays an OVERLAY the Lobby instantiates, not a scene of its own, even
## though the brief asked for a scene. A Transition.change_scene cannot blur
## the Lobby -- the live pixels are gone by the time the new scene loads, and
## the project's other answer to that (Achievements' baked
## bg_achievements_blur.jpg) cannot show the room the student is standing in.
## Blur here is shop_hub_blur_material.tres over the live screen.
##
## Sliding the carousel records a PENDING choice per character; nothing is
## equipped until TERAPKAN, which commits every pending character at once.
## That is what lets one button dress all six in a single visit. Back
## discards. The "sedang dipakai" chip keys off the COMMITTED skin, not the
## centred one, so it disappears the moment the carousel moves and returns
## when TERAPKAN lands -- with two skins per character and both unlocked,
## that is the only on-screen proof the button did anything.
##
## The carousel is posed, not laid out (spec
## docs/superpowers/specs/2026-09-23-skin-select-slide-design.md): one float,
## _scroll, says which card is centred (fractionally mid-drag), and
## card_pose() turns each card's distance from it into a position, scale
## and focus. That is what puts the neighbour on screen at the mockup's
## size, and what fades its dimming and blur with the finger instead of
## snapping them on selection.
##
## Opened by loby.gd with open(). @tool so the test runner can drive it; the
## fades are skipped in the editor.

signal closed

## One card per skin of the open character, instanced per open: the count
## depends on who the rail has open, so it is per-call dynamic content.
@export var card_scene: PackedScene = preload("res://Scenes/Skins/SkinCard.tscn")
## Seconds the screen takes to fade in or out.
@export var fade_time: float = 0.2
## Seconds the carousel takes to settle on a card after a drag or a tap.
@export var slide_time: float = 0.28
## Top-left of the centred card, in design pixels. Fitted to
## skinselection_mockup.png.
@export var center_origin: Vector2 = Vector2(85, 153)
## Scale of the centred card's 1080x1920 splash.
@export var center_scale: float = 0.818
## Top-left of the card one step to the right. The left neighbour mirrors it
## around the centred card's middle.
@export var side_origin: Vector2 = Vector2(676, 370)
## Scale of a neighbouring card.
@export var side_scale: float = 0.658
## Brightness multiplier on a neighbouring card; 1.0 leaves it untouched.
@export_range(0.0, 1.0) var side_brightness: float = 0.71
## Gaussian blur sigma on a neighbouring card, in screen pixels.
@export var side_blur_px: float = 4.0
## How far a drag may pull past the first or last card, in cards.
@export var overscroll: float = 0.35

## Width of the splash canvas every card is drawn at before scaling.
const CARD_W := 1080.0

@onready var _carousel: Control = %Carousel
@onready var _track: Control = %Track
@onready var _title: Label = %Title
@onready var _dots: HBoxContainer = %Dots
@onready var _rail: HBoxContainer = %Rail
@onready var _skin_name: Label = %SkinName
@onready var _worn_chip: PanelContainer = %WornChip
@onready var _back_button: TextureButton = %BackButton
@onready var _terapkan: Button = %Terapkan

## Index into StudentSkins.NAMES -- which character the rail has open.
var _student_index: int = 0
## Index into the open character's skins_for() list -- the centred card.
var _skin_index: int = 0
## Character name -> skin id chosen but not yet committed. A character with
## no entry here reads as whatever they are already wearing.
var _pending: Dictionary = {}
var _closing: bool = false

## The tween settling the carousel; killed before a new one starts so two
## quick drags never fight over Track.position.x.
var _slide_tween: Tween
## True while a finger is dragging the carousel.
var _dragging: bool = false
## Which card is centred, in card units; fractional while dragging or
## settling. Every card's pose derives from it.
var _scroll: float = 0.0
## The open character's cards in skin order. Track's child order is draw
## order instead, which _layout_cards keeps nearest-last.
var _cards: Array[SkinCard] = []
## _scroll and the press's global x when the current drag began, so travel
## is measured against the press rather than the last motion event.
var _drag_start_scroll: float = 0.0
var _drag_start_x: float = 0.0
## The most recent drag sample and its time, for the release velocity.
var _last_x: float = 0.0
var _last_ms: int = 0
## Release speed in px/s, positive rightwards.
var _release_velocity: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	for i in _rail.get_child_count():
		var tile := _rail.get_child(i) as StudentTile
		if tile != null and not tile.pressed.is_connected(select_student):
			tile.pressed.connect(select_student.bind(i))
	if not _back_button.pressed.is_connected(go_back):
		_back_button.pressed.connect(go_back)
	if not _terapkan.pressed.is_connected(apply):
		_terapkan.pressed.connect(apply)
	if not _carousel.gui_input.is_connected(_on_carousel_input):
		_carousel.gui_input.connect(_on_carousel_input)
	if not _carousel.resized.is_connected(_on_carousel_resized):
		_carousel.resized.connect(_on_carousel_resized)


## Fills the rail from StudentSkins.NAMES, opens the first character and
## fades in. Takes no argument: this screen never reads the roster, because
## equipped_skins is keyed by NAME and a skin follows a character across the
## grade change that clears the roster.
func open() -> void:
	_pending.clear()
	for i in StudentSkins.NAMES.size():
		var tile := _rail.get_child(i) as StudentTile
		if tile != null:
			tile.show_student(StudentSkins.NAMES[i], pending_id(StudentSkins.NAMES[i]))
	select_student(0)
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	AudioDirector.play_sfx(&"tap")


## The character the rail currently has open.
func current_student() -> String:
	return StudentSkins.NAMES[_student_index]


## The skin `who` will be wearing after TERAPKAN -- their pending choice if
## they have one, else whatever they are wearing now.
func pending_id(who: String) -> String:
	return str(_pending.get(who, GameState.equipped_skin(who)))


## Opens character `index`'s skins, keeping every other character's pending
## choice. Jumps the carousel rather than animating -- every card under it
## has just been replaced, so a slide would animate the wrong art.
func select_student(index: int) -> void:
	if index < 0 or index >= StudentSkins.NAMES.size():
		return
	_student_index = index
	for i in StudentSkins.NAMES.size():
		var tile := _rail.get_child(i) as StudentTile
		if tile != null:
			tile.set_open(i == index)
	_rebuild_carousel()


## Centres card `index` of the open character and records it as pending.
## Nothing is equipped here: TERAPKAN commits, which is what lets one button
## serve all six characters in one visit.
func select_skin(index: int) -> void:
	var ids := StudentSkins.skins_for(current_student())
	if index < 0 or index >= ids.size():
		return
	_skin_index = index
	_pending[current_student()] = ids[index]
	_slide_to(index, true)
	# _refresh_dots too, not just on a rebuild: sliding moves _skin_index,
	# and without this the lit dot stayed on whichever card was centred when
	# the character was opened.
	_refresh_dots(ids.size())
	_refresh_tray()


## Commits every pending choice and closes.
func apply() -> void:
	apply_without_closing()
	close()


## The half of apply() that does not close, so a test can watch the worn
## chip flip without the node freeing itself out from under it.
##
## equip_skin already returns false for a locked or unknown skin and no-ops
## when re-equipping the worn one, so this loop needs no guard of its own.
func apply_without_closing() -> void:
	for who in _pending:
		GameState.equip_skin(str(who), str(_pending[who]))
	_pending.clear()
	for i in StudentSkins.NAMES.size():
		var tile := _rail.get_child(i) as StudentTile
		if tile != null:
			tile.show_student(StudentSkins.NAMES[i], pending_id(StudentSkins.NAMES[i]))
	_refresh_tray()


## Fades out, emits `closed` and frees the screen. Idempotent. Pending
## choices die with the node -- back is how you discard them.
func close() -> void:
	if _closing:
		return
	_closing = true
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_time)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())


## One step back. There is no second layer to close any more -- the old
## popup's skin column is gone -- so this is just close().
func go_back() -> void:
	close()


## The player-facing name of a skin id. One place to hang real names when
## the catalogue grows past "default" and "skin1".
static func skin_label(id: String) -> String:
	if id == StudentSkins.DEFAULT_ID:
		return "Seragam Sekolah"
	return "Seragam %s" % id.trim_prefix("skin")


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	go_back()


## Android's back button arrives as a notification, not ui_cancel -- the
## same route inventory.gd and the achievement sheets use.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


## Rebuilds the carousel for the open character. The cards are the one piece
## of this screen built at runtime: their count depends on who is open, so
## they cannot be authored as nodes the way the rail's six tiles are.
func _rebuild_carousel() -> void:
	for old in _track.get_children():
		_track.remove_child(old)
		old.queue_free()
	_cards.clear()
	var who := current_student()
	var ids := StudentSkins.skins_for(who)
	var worn := pending_id(who)
	_skin_index = maxi(ids.find(worn), 0)
	for id in ids:
		var card: SkinCard = card_scene.instantiate()
		_track.add_child(card)
		card.show_skin(who, id, not GameState.is_skin_unlocked(who, id))
		_cards.append(card)
	_slide_to(_skin_index, false)
	_refresh_dots(ids.size())
	_refresh_tray()


## Centre-to-centre distance between the centred slot and its neighbour, in
## design pixels: how far a finger travels to move one card. Derived from
## the two slots so moving either keeps the drag in step.
func pitch_px() -> float:
	return (side_origin.x + CARD_W * side_scale * 0.5) \
		- (center_origin.x + CARD_W * center_scale * 0.5)


## The pose of a card `t` cards from the centre (negative is left): top-left
## position, scale and focus. Linear in |t| up to one card, then it keeps
## sliding at the same pitch with the neighbour's scale and no focus.
## center_origin/side_origin's design x is measured on a 1080-wide carousel
## (skinselection_mockup.png); a wider one -- stretch aspect="expand" widens
## the canvas on a tablet, foldable or desktop window -- gets the result
## re-centred by half the extra width, so it stays centred on its own width
## instead of hugging the left edge.
func card_pose(t: float) -> Dictionary:
	var d := minf(absf(t), 1.0)
	var s := lerpf(center_scale, side_scale, d)
	var cx := center_origin.x + CARD_W * center_scale * 0.5 + pitch_px() * t
	var top := lerpf(center_origin.y, side_origin.y, d)
	var offset_x := 0.0
	if _carousel != null and _carousel.size.x > 0.0:
		offset_x = (_carousel.size.x - CARD_W) * 0.5
	return {"position": Vector2(cx - CARD_W * s * 0.5 + offset_x, top), "scale": s, "focus": 1.0 - d}


## Which card is centred, fractionally mid-drag.
func scroll() -> float:
	return _scroll


## The open character's card for skin `index`, or null.
func card_for(index: int) -> SkinCard:
	return _cards[index] if index >= 0 and index < _cards.size() else null


func _set_scroll(value: float) -> void:
	_scroll = value
	_layout_cards()


## Poses every card from _scroll and keeps the nearest one drawn last, so a
## neighbour never covers the centred card.
func _layout_cards() -> void:
	for i in _cards.size():
		var pose := card_pose(float(i) - _scroll)
		_cards[i].set_pose(pose.position, pose.scale, pose.focus,
			side_brightness, side_blur_px)
	var order: Array[SkinCard] = _cards.duplicate()
	order.sort_custom(func(a: SkinCard, b: SkinCard) -> bool:
		return absf(float(_cards.find(a)) - _scroll) > absf(float(_cards.find(b)) - _scroll))
	for k in order.size():
		_track.move_child(order[k], k)


## Moves _scroll to card `index`. Animated, it eases over slide_time and the
## cards' focus eases with it.
func _slide_to(index: int, animated: bool) -> void:
	if _cards.is_empty():
		return
	if is_instance_valid(_slide_tween) and _slide_tween.is_valid():
		_slide_tween.kill()
	if not animated or Engine.is_editor_hint() or not is_inside_tree():
		_set_scroll(float(index))
		return
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_scroll, _scroll, float(index), slide_time)


## Shows one dot per skin and marks the centred one. The dots are authored
## nodes, not built here: the extras are hidden rather than created.
func _refresh_dots(count: int) -> void:
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as Panel
		if dot == null:
			continue
		dot.visible = i < count
		dot.theme_type_variation = &"SkinDotOn" if i == _skin_index else &"SkinDotOff"


## The title, the skin's name and the worn chip.
##
## The chip keys off GameState.equipped_skin -- the COMMITTED skin -- not
## the centred card, so it goes out the moment the carousel moves and comes
## back when TERAPKAN lands. A locked skin has no chip and says TERKUNCI in
## the name's place instead.
func _refresh_tray() -> void:
	var who := current_student()
	var id := pending_id(who)
	_title.text = who.to_upper()
	var unlocked := GameState.is_skin_unlocked(who, id)
	_skin_name.text = skin_label(id) if unlocked else "TERKUNCI"
	_worn_chip.visible = unlocked and id == GameState.equipped_skin(who)


## Drag-to-slide, mirroring BasketTray's gesture rotated 90 degrees: the
## track follows the finger, and SkinCard.settle_index decides where the
## release lands from the travel and the release speed.
func _on_carousel_input(event: InputEvent) -> void:
	if _cards.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.global_position.x)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging:
		_update_drag(event.global_position.x)


func _begin_drag(at_x: float) -> void:
	if is_instance_valid(_slide_tween) and _slide_tween.is_valid():
		_slide_tween.kill()
	_dragging = true
	_drag_start_scroll = _scroll
	_drag_start_x = at_x
	_last_x = at_x
	_last_ms = Time.get_ticks_msec()
	_release_velocity = 0.0


## The cards follow the finger one pitch per card, up to `overscroll` past
## either end.
func _update_drag(at_x: float) -> void:
	var raw := _drag_start_scroll - (at_x - _drag_start_x) / pitch_px()
	_set_scroll(clampf(raw, -overscroll, float(_cards.size() - 1) + overscroll))
	var now := Time.get_ticks_msec()
	var dt := float(now - _last_ms) / 1000.0
	if dt > 0.0:
		_release_velocity = (at_x - _last_x) / dt
	_last_x = at_x
	_last_ms = now


## Re-poses every card when the carousel's own size changes. A window resize
## (tablet, foldable, desktop) can widen or narrow the canvas under
## stretch/aspect="expand", and card_pose's re-centring reads _carousel.size.x
## fresh each call, but nothing else re-triggers _layout_cards on its own.
func _on_carousel_resized() -> void:
	if not _cards.is_empty():
		_layout_cards()


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	select_skin(SkinCard.settle_index(_skin_index, _last_x - _drag_start_x,
		_release_velocity, pitch_px(), _cards.size()))
