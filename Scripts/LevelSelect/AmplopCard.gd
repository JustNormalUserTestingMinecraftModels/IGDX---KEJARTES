@tool
extends Control

## One amplop coklat in the level-select fan, and the opened envelope in its
## confirmation. A reusable PackedScene template: the screen instances it
## once per grade and feeds it through these root @exports (an instance's
## children do not keep overrides on save). Its four art layers are cut from
## the artist's flat "Amplop coklat.png" by tools/split_amplop.py, all the
## same size, so each fills Bob and they overlay exactly.
##
## Layers inside Bob, back to front: Pupils, Body, Flap, Seal, Tab. Bob is
## the idle-motion pivot, so the level select's bob and hop never fight the
## fan-pose tween that moves this root. open() folds the flap back, and at
## the fold's edge-on midpoint moves it behind the pupils and swaps in its
## plain inside face; the pupils then rise over the envelope's top edge.

## Emitted when the player taps this envelope.
signal picked(grade: int)

## A card that is not the centred grade sits back at this tint.
const UNFOCUSED_TINT := Color(0.85, 0.85, 0.85)
## Seconds the wax seal takes to pop off.
const SEAL_POP_SEC := 0.25
## Seconds the flap takes to fold all the way back.
const FLAP_FOLD_SEC := 0.45
## Seconds one pupil takes to rise, and the stagger between pupils.
const PEEK_SEC := 0.45
const PEEK_STAGGER_SEC := 0.08
## How far a pupil's face rises: its own height, so the face clears the top edge.
const PEEK_RISE := 110.0

## Which grade this envelope represents (7, 8 or 9).
@export var grade: int = 7
## Text on the peeking tab, e.g. "Kelas 7".
@export var tab_text: String = "Kelas 7":
	set(value):
		tab_text = value
		if is_node_ready():
			_tab.text = value
## Kraft envelope body art.
@export var envelope_texture: Texture2D:
	set(value):
		envelope_texture = value
		if is_node_ready():
			_body.texture = value
## The top flap art, folded back by open().
@export var flap_texture: Texture2D:
	set(value):
		flap_texture = value
		if is_node_ready():
			_flap.texture = value
## The flap's plain inside face, shown once the flap turns past edge-on.
@export var flap_back_texture: Texture2D
## The button-and-string seal art, popped off by open().
@export var seal_texture: Texture2D:
	set(value):
		seal_texture = value
		if is_node_ready():
			_seal.texture = value
## False for the confirmation's display copy: the card ignores taps.
@export var interactive: bool = true:
	set(value):
		interactive = value
		if is_node_ready():
			_apply_interactive()

## The idle-motion pivot the level select bobs and hops.
@onready var bob: Control = $Bob
@onready var _pupils: Control = $Bob/Pupils
@onready var _body: TextureRect = $Bob/Body
@onready var _flap: TextureRect = $Bob/Flap
@onready var _seal: TextureRect = $Bob/Seal
@onready var _tab: Button = $Bob/Tab
@onready var _button: Button = $HitButton

var _open_tween: Tween


func _ready() -> void:
	_button.pressed.connect(func() -> void: picked.emit(grade))
	_tab.text = tab_text
	if envelope_texture != null:
		_body.texture = envelope_texture
	if flap_texture != null:
		_flap.texture = flap_texture
	if seal_texture != null:
		_seal.texture = seal_texture
	_apply_interactive()


## Tint the card back when it is not the centred grade.
func set_focused(is_focused: bool) -> void:
	modulate = Color.WHITE if is_focused else UNFOCUSED_TINT


## Open the envelope: the seal pops, the flap folds back, and one pupil per
## texture in `portraits` rises out. Returns the tween so a caller can chain.
func open(portraits: Array) -> Tween:
	reseal()
	var peeks := _pupils.get_children()
	for i in range(peeks.size()):
		var peek = peeks[i]  # PupilPeek.gd; untyped for its own members
		peek.visible = i < portraits.size()
		if peek.visible:
			peek.portrait_texture = portraits[i]
			peek.head.modulate.a = 0.0
	_pupils.visible = true
	_open_tween = create_tween()
	_open_tween.tween_property(_seal, "scale", Vector2.ZERO, SEAL_POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_open_tween.parallel().tween_property(_tab, "modulate:a", 0.0, SEAL_POP_SEC)
	_open_tween.tween_property(_flap, "scale:y", 0.0, FLAP_FOLD_SEC * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_open_tween.tween_callback(func() -> void:
		bob.move_child(_flap, 0)
		if flap_back_texture != null:
			_flap.texture = flap_back_texture)
	_open_tween.tween_property(_flap, "scale:y", -1.0, FLAP_FOLD_SEC * 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(mini(portraits.size(), peeks.size())):
		var head: Control = peeks[i].head
		var delay := i * PEEK_STAGGER_SEC
		var rise := _open_tween.parallel() if i > 0 else _open_tween
		rise.tween_property(head, "position:y", -PEEK_RISE, PEEK_SEC) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_open_tween.parallel().tween_property(head, "modulate:a", 1.0, PEEK_SEC * 0.5) \
			.set_delay(delay)
	return _open_tween


## Close the envelope again at once: flap down, seal on, tab back, pupils in.
func reseal() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	# Back to just under the seal. Moving a child from before the seal
	# shifts the seal down one, hence the -1.
	var before_seal := _seal.get_index() - (1 if _flap.get_index() < _seal.get_index() else 0)
	bob.move_child(_flap, before_seal)
	_flap.texture = flap_texture
	_flap.scale = Vector2.ONE
	_seal.scale = Vector2.ONE
	_tab.modulate.a = 1.0
	for peek in _pupils.get_children():
		peek.head.position.y = 0.0
		peek.head.modulate.a = 1.0
	_pupils.visible = false


func _apply_interactive() -> void:
	_button.mouse_filter = Control.MOUSE_FILTER_STOP if interactive \
		else Control.MOUSE_FILTER_IGNORE
