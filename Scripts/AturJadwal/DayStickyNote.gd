@tool
class_name DayStickyNote
extends Control

## One sticky note in AturJadwal's day row. Five instances sit under
## atur_jadwal.tscn's BGHari (named Senin..Jumat); atur_jadwal.gd drives each
## one every time the selected student or their schedule changes, calling
## exactly one of show_empty() / show_scheduled() / show_holiday().
##
## The note is three stacked lines on cream paper (day / pembelajaran name
## / one-word flavour), a strip of washi tape across its top, a category icon
## peeking from behind the top-right corner, and a soft drop shadow. When a
## day newly becomes scheduled -- or its category changes -- the note plays a
## squash-pop and the icon slides into view.
##
## COLOUR LIVES ON THE TAPE, NOT THE PAPER (2026-09-24, AturJadwal visual
## polish, D1-D4). The paper used to be flooded with the category colour,
## which put dark text on saturated red/green/purple at failing contrast. Now
## the paper is always cream -- a vertical surface_card -> surface_page wash
## drawn by paper_gradient.gdshader -- and the category colour tints the
## WashiTape strip laid over the art's own adhesive band. An empty day has no
## tape and breathes gently with a "+ Atur" hint; a national holiday gets gold
## tape and the padlock.
##
## All colour comes from DesignTokens; there is no hardcoded colour literal
## here and no theme_override_*. This is a @tool script so the note previews in the
## editor, so every real side effect (tweens, audio) is gated behind
## Engine.is_editor_hint(); the pressed re-emit is pure wiring and stays
## ungated so tests can exercise it.

## Emitted when the inner Paper button is pressed. atur_jadwal.gd connects
## this exactly where it used to connect the old TextureButton's `pressed`.
signal pressed

## Code category -> the Indonesian word the player reads. Kept identical to
## the picker's ActivityTile instances in atur_jadwal.tscn (asserted by both
## suites).
const DISPLAY_NAMES := {
	"Akademis": "Akademik",
	"SeniBudaya": "Seni Budaya",
	"Olahraga": "Atletik",
	"Wirausaha": "Wirausaha",
	"Istirahat": "Libur",
}

## Code category -> a decorative one-word mood label on the note's third line.
const FLAVOR_WORDS := {
	"Akademis": "Fokus",
	"SeniBudaya": "Berkarya",
	"Olahraga": "Semangat",
	"Wirausaha": "Cuan",
	"Istirahat": "Santai",
}

const _HOLIDAY_FLAVOR := "Libur Nasional"

## Category key -> the icon that peeks from behind the note, shared by all
## five instances via this preloaded default. Akademis / SeniBudaya /
## Olahraga use the real stat_*.png; Wirausaha / Istirahat use generated
## placeholders. Still an @export so the visual team can override per
## instance in the Inspector once real art lands.
@export var category_icons: Dictionary = {
	"Akademis": preload("res://Assets/Images/StudentCard/stat_akademis.png"),
	"SeniBudaya": preload("res://Assets/Images/StudentCard/stat_senibudaya.png"),
	"Olahraga": preload("res://Assets/Images/StudentCard/stat_olahraga.png"),
	"Wirausaha": preload("res://Assets/Images/AturJadwal/icon_wirausaha_placeholder.png"),
	"Istirahat": preload("res://Assets/Images/AturJadwal/icon_istirahat_placeholder.png"),
}

## The peeking icon for a national-holiday note (a flag/calendar placeholder).
## An @export with a preloaded default, same rationale as category_icons.
@export var holiday_icon: Texture2D = preload("res://Assets/Images/AturJadwal/icon_libur_nasional_placeholder.png")

## Partikel yang muncul saat hari ini cocok dengan mapel favorit murid.
## @export agar tim visual bisa mengganti per instance di Inspector.
@export var specialty_match_burst_scene: PackedScene = preload("res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn")

## How far an empty note's paper swells at the top of its breath. Kept small
## on purpose: an invitation to tap, not an alarm. 1.0 switches it off.
@export_range(1.0, 1.1, 0.005) var empty_breath_scale: float = 1.03

## Seconds for one full breath (out and back) of an empty note.
@export_range(0.5, 6.0, 0.1) var empty_breath_seconds: float = 2.4

@onready var _paper: TextureButton = $Paper
@onready var _day_label: Label = $Paper/DayLabel
## The lines under the day name stack in Paper/Lines, a VBox, so a holiday
## title long enough to wrap pushes the flavour line down instead of
## printing over it.
@onready var _subject_label: Label = $Paper/Lines/SubjectLabel
@onready var _flavor_label: Label = $Paper/Lines/FlavorLabel
@onready var _lock: Label = $Paper/Lock
@onready var _back_icon: TextureRect = $BackIcon
@onready var _match_glow: TextureRect = $Paper/MatchGlow
@onready var _specialty_star: TextureRect = $Paper/SpecialtyStar
@onready var _tape: TextureRect = $Paper/WashiTape
@onready var _atur_hint: Label = $Paper/Lines/AturHint

var _tokens: DesignTokens
var _state := ""       # "" | "empty" | "scheduled" | "holiday"
var _category := ""
var _icon_rest := Vector2.INF
var _reveal: Tween
var _breath: Tween


func _ready() -> void:
	_tokens = DesignTokens.load_default()
	pivot_offset = size / 2.0
	if _paper:
		_paper.set_meta(Juice.NO_AUTO_JUICE, true)
		if not _paper.pressed.is_connected(_on_paper_pressed):
			_paper.pressed.connect(_on_paper_pressed)
		_apply_paper_gradient()
	# Default look until atur_jadwal.gd calls a state method.
	if _state == "":
		show_empty()


func _on_paper_pressed() -> void:
	pressed.emit()


func set_day_name(day_name: String) -> void:
	if _day_label:
		_day_label.text = day_name.to_upper()


## Paints the empty look: bare cream paper, no tape, the "+ Atur" hint, and a
## slow breath inviting the tap.
func show_empty() -> void:
	_apply(null, false, false)
	if _atur_hint:
		_atur_hint.visible = true
	_state = "empty"
	_category = ""
	_start_breath()


## Paints the scheduled look. This is a repaint only -- it never plays the
## assign-pop. atur_jadwal.gd::_on_activity_selected calls play_assign_pop()
## itself on the one note the player just assigned (Design decision #8).
func show_scheduled(category: String) -> void:
	if _subject_label:
		_subject_label.text = DISPLAY_NAMES.get(category, category)
	if _flavor_label:
		_flavor_label.text = FLAVOR_WORDS.get(category, "")
	if _back_icon:
		_back_icon.texture = _get_icon(category)
	_apply(_get_tokens().category_color(category), true, false)
	_stop_breath()
	_state = "scheduled"
	_category = category


## Paints the locked-holiday look. Repaint only, never pops -- see
## show_scheduled().
func show_holiday(title: String) -> void:
	if _subject_label:
		_subject_label.text = title
	if _flavor_label:
		_flavor_label.text = _HOLIDAY_FLAVOR
	if _back_icon:
		_back_icon.texture = holiday_icon
	_apply(_get_tokens().category_color("Libur"), true, true)
	_stop_breath()
	_state = "holiday"
	_category = ""


## Sets the tape colour (or hides the tape, for `tape_color == null`) and the
## visibility of the subject line, flavour line, back icon, lock glyph and
## "+ Atur" hint in one place. The paper itself is never tinted: it stays
## untinted cream under paper_gradient.gdshader in every state.
func _apply(tape_color: Variant, show_extras: bool, show_lock: bool) -> void:
	if _paper:
		_paper.self_modulate = Color.WHITE
	if _tape:
		_tape.visible = tape_color != null
		if tape_color != null:
			_tape.self_modulate = tape_color
	if _atur_hint:
		_atur_hint.visible = false
	if _subject_label:
		_subject_label.visible = show_extras
	if _flavor_label:
		_flavor_label.visible = show_extras
	if _back_icon:
		_back_icon.visible = show_extras
	if _lock:
		_lock.visible = show_lock
	# A repaint always clears the specialty-match decoration; play_specialty_match()
	# re-adds it for the one note the player just assigned.
	if _match_glow:
		_match_glow.visible = false
	if _specialty_star:
		_specialty_star.visible = false


func _get_tokens() -> DesignTokens:
	if _tokens == null:
		_tokens = DesignTokens.load_default()
	return _tokens


func _get_icon(category: String) -> Texture2D:
	return category_icons.get(category, null)


## Feeds the cream wash to paper_gradient.gdshader from the tokens: the
## lighter surface_card at the top, the warmer surface_page at the bottom.
## The material is shared by all five notes and every one writes the same two
## values, so the shared write is harmless.
func _apply_paper_gradient() -> void:
	var mat := _paper.material as ShaderMaterial
	if mat == null:
		return
	var t := _get_tokens()
	mat.set_shader_parameter("top_color", t.surface_card)
	mat.set_shader_parameter("bottom_color", t.surface_page)


## Starts the empty note's slow breath on the paper -- scale only, about the
## paper's centre, so it never fights play_assign_pop(), which animates the
## note's root. No-op in the editor, under Reduce Motion, or while already
## breathing.
func _start_breath() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or _paper == null:
		return
	if GameSettings.reduce_motion or empty_breath_scale <= 1.0:
		return
	if _breath and _breath.is_valid():
		return
	_paper.pivot_offset = _paper.size / 2.0
	var half := empty_breath_seconds / 2.0
	_breath = create_tween().set_loops()
	_breath.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_paper, "scale", Vector2.ONE * empty_breath_scale, half)
	_breath.tween_property(_paper, "scale", Vector2.ONE, half)


## Stops the breath and settles the paper back to rest, for a note that is no
## longer empty.
func _stop_breath() -> void:
	if _breath and _breath.is_valid():
		_breath.kill()
	_breath = null
	if _paper:
		_paper.scale = Vector2.ONE


## Squash-pop the whole note and float the back icon in. No-op in the editor.
func play_assign_pop() -> void:
	if Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	pivot_offset = size / 2.0
	var t := _get_tokens()
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2(1.12, 0.86), t.dur_fast * 0.6)
	pop.tween_property(self, "scale", Vector2(0.94, 1.06), t.dur_fast * 0.7)
	pop.tween_property(self, "scale", Vector2.ONE, t.dur_fast)
	if _back_icon:
		if _icon_rest == Vector2.INF:
			_icon_rest = _back_icon.position
		if _reveal and _reveal.is_valid():
			_reveal.kill()
		_back_icon.position = _icon_rest + Vector2(10, -12)
		_back_icon.modulate.a = 0.0
		_reveal = create_tween().set_parallel(true)
		_reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_reveal.tween_property(_back_icon, "position", _icon_rest, t.dur_normal)
		_reveal.tween_property(_back_icon, "modulate:a", 1.0, t.dur_normal)


## Plays the specialty-match reaction on top of the normal assign-pop: a gold
## particle burst from the note centre, a glow pulse, and a persistent star.
## No-op in the editor. atur_jadwal.gd calls this INSTEAD OF play_assign_pop()
## when the assigned activity is the selected student's specialty.
func play_specialty_match() -> void:
	play_assign_pop()
	if _specialty_star:
		_specialty_star.visible = true
	if _match_glow:
		_match_glow.visible = true
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if _match_glow:
		_match_glow.modulate.a = 0.0
		var t := _get_tokens()
		var glow_tw := create_tween()
		glow_tw.tween_property(_match_glow, "modulate:a", 0.55, t.dur_fast)
		glow_tw.tween_property(_match_glow, "modulate:a", 0.30, t.dur_normal)
	if specialty_match_burst_scene:
		var burst := specialty_match_burst_scene.instantiate()
		add_child(burst)
		burst.position = size / 2.0
		if burst.has_method("play"):
			burst.play()
