@tool
extends Control

## @tool note: mirrors Scripts/MainMenu/MainMenu.gd's established pattern
## (see that script's header for the full placeholder-instance
## explanation). Without @tool this script becomes a placeholder instance
## when the MCP test suite instantiates this scene from inside the editor
## process, which breaks traversal-based checks like
## test_scene_has_no_theme_overrides the moment they reach this node.
##
## Grade picking lives on the Level Select (Scenes/LevelSelect), which
## MainMenu routes through first while GameState.is_level_select_enabled();
## this scene only defaults to Kelas 7 when it did not. The "PILIH TINGKAT
## KELAS" modal this scene used to build at runtime is gone (2026-09-25).
##
## Gating: _setup_top_bar_buttons() builds and wires the top-bar buttons
## and must run in both a human's editor session and the test suite's
## instantiation, exactly like MainMenu's button wiring. Everything below the
## Engine.is_editor_hint() guard -- reading GameState to decide which
## branch of the cutscene to show, refreshing GameState-derived button
## text, and kicking off the first CG/dialogue reveal -- is a genuine
## runtime-only side effect and must never fire just because a human
## opened this scene in the editor, or because the test suite
## instantiated it. _input() is left unguarded: per Splashscreen's
## established note, Control nodes edited in the editor never receive
## real game input events, so there is nothing to gate there.

@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel
@onready var dialogue_box: Control = $DialogueBox
## The dark tone the intro fades up from and, if a CG ever went transparent,
## would show behind it -- the theme's warm overlay ink, not a placeholder
## image. Set from the token in _ready so it tracks the design system.
@onready var backdrop: ColorRect = $Backdrop
@onready var bg_cutscene: TextureRect = $BgCutScene
## The incoming CG for a cross-dissolve: it fades in over BgCutScene so the
## swap never dips to the bare Backdrop (which itself sits behind BgCutScene
## so the entrance reveal is the academy backdrop, never the gray window).
@onready var cg_overlay: TextureRect = $CgOverlay
@onready var fade_overlay: ColorRect = $FadeOverlay
## The advance chevron in the note's bottom-right corner; _pulse_chevron()
## breathes it so the player reads the box as waiting on a tap (2026-09-30 VN
## pass, replacing the old "Ketuk untuk melanjutkan" caption).
@onready var chevron: TextureRect = $DialogueBox/Chevron
@onready var _tokens: DesignTokens = DesignTokens.load_default()

## Typewriter speed, tunable in the inspector without touching code.
@export var typewriter_chars_per_second: float = 45.0

var cg_data = [
	{
		"image": preload("res://Assets/Images/CG/cg0.jpg"),
		"text": "Fiuh, setelah sekian lama aku mendaftar di sekolah ini. Akhirnya saya resmi diakui untuk mengajar disini!"
	},
	{
		"image": preload("res://Assets/Images/CG/cg1.jpg"),
		"text": "Dengan hati berdebar, aku membuka amplop itu perlahan..."
	},
	{
		"image": preload("res://Assets/Images/CG/cg2.jpg"),
		"text": "Surat penerimaannya sudah ditandatangani dan resmi. Namaku benar-benar tercantum sebagai guru di sini."
	},
	{
		"image": preload("res://Assets/Images/CG/cg3.jpg"),
		"text": "Rasanya seperti mimpi. Semua kerja kerasku selama ini akhirnya terbayar!"
	},
	{
		"image": preload("res://Assets/Images/CG/cg4.jpg"),
		"text": "Dan inilah Akademi tempatku mengabdi mulai sekarang. Megah sekali... Baiklah, saatnya mulai bekerja!"
	}
]

var cg_index := 0
var is_transitioning := false
var _reveal_tween: Tween

## Where the Debug Level Select toggle sends the player once switched on.
const _LEVEL_SELECT_SCENE := "res://Scenes/LevelSelect/LevelSelect.tscn"

var btn_skip: Button
var btn_debug_toggle: Button
## True once a scene change has been asked for. Separate from
## is_transitioning, which also covers the CG fades, so the Debug toggle
## still leaves mid-fade but never fires a second change_scene.
var _exiting := false

func _ready():
	fade_overlay.color.a = 0.0
	backdrop.color = _tokens.surface_overlay
	_setup_top_bar_buttons()

	if Engine.is_editor_hint():
		return

	_update_debug_button_text()
	_pulse_chevron()

	# With the picker on, the grade was chosen on the Level Select already.
	if not GameState.is_level_select_enabled():
		GameState.set_grade(7)
	show_current()

func _setup_top_bar_buttons() -> void:
	# Top HBox for Skip & Debug controls
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(30, 40)
	top_bar.size = Vector2(1020, _tokens.touch_target_min + 20)
	add_child(top_bar)

	# The "Debug Level Select" toggle is gone from the player-facing intro
	# (2026-09-30): it was developer chrome, and devs still reach the grade
	# picker from the Debug overlay's Scenes tab ("Pilih Kelas (LevelSelect)").
	# btn_debug_toggle stays null; _update_debug_button_text() and
	# _on_debug_toggle_pressed() are null-guarded / unwired accordingly.

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Skip cutscene button
	btn_skip = Button.new()
	# Skipping a cutscene discards nothing, so it is a quiet opt-out rather
	# than a warning. It wore DangerButton until the 2026-09-10 pass.
	btn_skip.theme_type_variation = &"SecondaryButton"
	# Lean and mobile-friendly: a short Indonesian label in a compact pill,
	# tucked top-right, rather than the wide "Skip Intro" (2026-09-30).
	btn_skip.text = "Lewati"
	# No clip_text: with the debug toggle gone the HBox can't overflow, so the
	# pill simply sizes to the word (min width keeps a comfortable tap target).
	btn_skip.custom_minimum_size = Vector2(200, _tokens.touch_target_min)
	btn_skip.pressed.connect(_on_skip_pressed)
	top_bar.add_child(btn_skip)

func _update_debug_button_text() -> void:
	if btn_debug_toggle:
		var mode_str = "ON (Pilih Kelas)" if GameState.debug_level_select_enabled else "OFF (Normal)"
		btn_debug_toggle.text = "Debug Level Select: " + mode_str

## Switched on, the toggle goes back to the Level Select to pick a grade
## before the intro, as the old in-scene modal used to pop up.
func _on_debug_toggle_pressed() -> void:
	GameState.debug_level_select_enabled = not GameState.debug_level_select_enabled
	GameSettings.save_settings()
	_update_debug_button_text()
	print("Debug Level Select toggled: ", GameState.debug_level_select_enabled)
	if GameState.debug_level_select_enabled and not _exiting and not Transition.is_busy():
		_exiting = true
		is_transitioning = true
		Transition.change_scene(_LEVEL_SELECT_SCENE, Transition.Style.WIPE)

## Skip must route through StudentCard exactly like finishing the cutscene
## normally does (go_to_gameplay, below) -- this scene is only ever reached
## fresh from MainMenu (see MainMenu.gd; nothing else routes here), so
## GameState.approved_students is always empty at this point. Routing
## straight to Lobby used to leave it that way, which every downstream
## screen (AturJadwal, StudentList, StudentManager's own week simulation)
## silently read as "nobody to schedule" and covered for with its own
## placeholder roster instead of surfacing the problem -- the same bug
## go_to_gameplay() had before it was fixed to always delegate to
## _next_scene_path(). Skip Intro is a normal, always-visible button (not
## a debug affordance), so a real player hitting it hit this every time.
func _on_skip_pressed() -> void:
	# Transition.change_scene() already plays "whoosh" on the scene change;
	# adding another here would stack with the _input handler's "tap" and
	# UIPolish's game-wide auto-tap (three cues, not the "two is fine" the
	# project's convention allows -- see StudentCard.gd's
	# _on_belajar_pressed note).
	print("Skip Cutscene pressed")
	# No _fade_to_black() here: Transition's wipe is the transition now,
	# and fading to black first just stacked a second one in front of it.
	# is_transitioning is still raised by hand because _fade_to_black()
	# used to do it, and _input() reads it to ignore taps mid-exit. Not while
	# the arrival wipe is still out: Transition would refuse the change after
	# the flags latched, and Skip would be dead (bug sweep 2026-09-30).
	if Transition.is_busy():
		return
	is_transitioning = true
	_exiting = true
	Transition.change_scene(_next_scene_path(), Transition.Style.WIPE)


## Deliberately slower than transition_to_next()'s panel-to-panel
## crossfade (which uses _tokens.dur_normal) -- this is the very first
## beat of a reveal sequence (fresh game, after grade select, or the
## loss-retry cutscene), and it should read as a breath before the
## scene commits to its opening image, not a routine page-turn.
## The advance chevron's breathing pulse: its dimmest alpha and the seconds
## each half of the loop takes.
const _CHEVRON_PULSE_MIN_ALPHA := 0.35
const _CHEVRON_PULSE_SEC := 0.6

const _ENTRANCE_HOLD_SEC := 0.4
const _ENTRANCE_FADE_SEC := 1.0

func show_current():
	AudioDirector.play_bgm(&"introcutscene")
	is_transitioning = true
	bg_cutscene.texture = cg_data[cg_index]["image"]
	bg_cutscene.modulate.a = 0.0
	await get_tree().create_timer(_ENTRANCE_HOLD_SEC).timeout
	_reveal(cg_data[cg_index]["text"])
	var tw := create_tween()
	tw.tween_property(bg_cutscene, "modulate:a", 1.0, _ENTRANCE_FADE_SEC) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	is_transitioning = false

## Typewriter reveal via visible_ratio rather than character-slicing, so
## any BBCode in the dialogue text renders correctly instead of being
## sliced mid-tag.
func _reveal(text: String) -> void:
	dialogue_label.text = text
	dialogue_label.visible_ratio = 0.0
	var chars := float(dialogue_label.get_total_character_count())
	var duration := chars / typewriter_chars_per_second
	var tw := dialogue_label.create_tween()
	tw.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
	_reveal_tween = tw

## Gently breathes the advance chevron (runtime only, a looping tween) so the
## note reads as waiting on a tap now that the "Ketuk untuk melanjutkan" caption
## is gone (2026-09-30 VN pass).
func _pulse_chevron() -> void:
	if not is_instance_valid(chevron):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(chevron, "modulate:a", _CHEVRON_PULSE_MIN_ALPHA,
		_CHEVRON_PULSE_SEC).set_trans(Tween.TRANS_SINE)
	tween.tween_property(chevron, "modulate:a", 1.0,
		_CHEVRON_PULSE_SEC).set_trans(Tween.TRANS_SINE)


func _input(event):
	if is_transitioning:
		return
	var tapped = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true

	if not tapped:
		return

	AudioDirector.play_sfx(&"tap")
	_on_tap()

## Visual-novel contract: tapping mid-reveal completes the current line
## instantly. It does not advance -- that requires a second, separate tap.
func _on_tap() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid() \
			and dialogue_label.visible_ratio < 1.0:
		_reveal_tween.kill()
		dialogue_label.visible_ratio = 1.0
		return
	advance()

func advance():
	cg_index += 1
	if cg_index >= cg_data.size():
		go_to_gameplay()
	else:
		transition_to_next()

## True cross-dissolve between CGs: the incoming image fades in on CgOverlay
## while the current one holds on BgCutScene, then becomes the base layer.
## The old code faded BgCutScene down to alpha 0 and back with nothing behind
## it, so every advance dipped through the bare backdrop; this never does.
func transition_to_next():
	is_transitioning = true

	cg_overlay.texture = cg_data[cg_index]["image"]
	cg_overlay.modulate.a = 0.0
	_reveal(cg_data[cg_index]["text"])

	var tween_in = create_tween()
	tween_in.tween_property(cg_overlay, "modulate:a", 1.0, _tokens.dur_normal)
	await tween_in.finished

	# Promote the overlay to the base layer and clear it for next time. The
	# base swap and the overlay clear happen together, so no frame shows a gap.
	bg_cutscene.texture = cg_overlay.texture
	cg_overlay.modulate.a = 0.0

	is_transitioning = false

## The intro lands on the roster approval screen, as before. (The exam
## branch that once lived here was deleted with the exam-intro beat.)
func _next_scene_path() -> String:
	return "res://Scenes/StudentCard/StudentCard.tscn"

## Both exits from this scene (here and _on_skip_pressed) now hand off to
## Transition rather than hopping through Scenes/Loading. These were the
## last two raw change_scene_to_file() calls in the project, and the only
## navigation a player could reach that did not wipe like every other
## screen change -- which is what made the loading screen read as
## unfinished. Going through Transition also picks up the inventory flush
## and the one-frame wait that the raw call silently skipped.
func go_to_gameplay():
	# See _on_skip_pressed() for why the black fade is gone.
	is_transitioning = true
	_exiting = true
	Transition.change_scene(_next_scene_path(), Transition.Style.WIPE)
