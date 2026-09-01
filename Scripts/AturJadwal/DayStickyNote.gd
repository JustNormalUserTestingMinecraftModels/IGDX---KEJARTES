@tool
class_name DayStickyNote
extends Control

## One sticky note in AturJadwal's day row. Five instances sit under
## atur_jadwal.tscn's BGHari (named Senin..Jumat); atur_jadwal.gd drives each
## one every time the selected student or their schedule changes, calling
## exactly one of show_empty() / show_scheduled() / show_holiday().
##
## The note is three stacked lines on a tinted paper (day / pembelajaran name
## / one-word flavour), a category icon peeking from behind the top-right
## corner, and a soft drop shadow. A national-holiday day is locked gold with
## a padlock glyph. When a day newly becomes scheduled -- or its category
## changes -- the note plays a squash-pop and the icon slides into view.
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
## the ActivityRow instances in atur_jadwal.tscn (asserted by both suites).
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

@onready var _paper: TextureButton = $Paper
@onready var _day_label: Label = $Paper/DayLabel
@onready var _subject_label: Label = $Paper/SubjectLabel
@onready var _flavor_label: Label = $Paper/FlavorLabel
@onready var _lock: Label = $Paper/Lock
@onready var _back_icon: TextureRect = $BackIcon

var _tokens: DesignTokens
var _state := ""       # "" | "empty" | "scheduled" | "holiday"
var _category := ""


func _ready() -> void:
	_tokens = DesignTokens.load_default()
	pivot_offset = size / 2.0
	if _paper:
		_paper.set_meta(Juice.NO_AUTO_JUICE, true)
		if not _paper.pressed.is_connected(_on_paper_pressed):
			_paper.pressed.connect(_on_paper_pressed)
	# Default look until atur_jadwal.gd calls a state method.
	if _state == "":
		show_empty()


func _on_paper_pressed() -> void:
	pressed.emit()


func set_day_name(day_name: String) -> void:
	if _day_label:
		_day_label.text = day_name.to_upper()


func show_empty() -> void:
	_apply(_get_tokens().surface_sunken, false, false)
	_state = "empty"
	_category = ""


func show_scheduled(category: String) -> void:
	var changed := _state != "scheduled" or _category != category
	_subject_label.text = DISPLAY_NAMES.get(category, category)
	_flavor_label.text = FLAVOR_WORDS.get(category, "")
	_back_icon.texture = _get_icon(category)
	_apply(_get_tokens().category_color(category), true, false)
	_state = "scheduled"
	_category = category
	if changed:
		play_assign_pop()


func show_holiday(title: String) -> void:
	var changed := _state != "holiday"
	_subject_label.text = title
	_flavor_label.text = _HOLIDAY_FLAVOR
	_back_icon.texture = holiday_icon
	_apply(_get_tokens().category_color("Libur"), true, true)
	_state = "holiday"
	_category = ""
	if changed:
		play_assign_pop()


## Sets the paper tint and the visibility of the subject line, flavour line,
## back icon and lock glyph in one place.
func _apply(tint: Color, show_extras: bool, show_lock: bool) -> void:
	if _paper:
		_paper.self_modulate = tint
	if _subject_label:
		_subject_label.visible = show_extras
	if _flavor_label:
		_flavor_label.visible = show_extras
	if _back_icon:
		_back_icon.visible = show_extras
	if _lock:
		_lock.visible = show_lock


func _get_tokens() -> DesignTokens:
	if _tokens == null:
		_tokens = DesignTokens.load_default()
	return _tokens


func _get_icon(category: String) -> Texture2D:
	return category_icons.get(category, null)


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
		var rest := _back_icon.position
		_back_icon.position = rest + Vector2(10, -12)
		_back_icon.modulate.a = 0.0
		var reveal := create_tween().set_parallel(true)
		reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(_back_icon, "position", rest, t.dur_normal)
		reveal.tween_property(_back_icon, "modulate:a", 1.0, t.dur_normal)
