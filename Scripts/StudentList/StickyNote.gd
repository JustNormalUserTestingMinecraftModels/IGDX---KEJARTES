@tool
class_name StickyNote
extends TextureRect

## One sticky-note day/activity chip on a StudentList card. Extracted
## from ~20 near-identical inline subtrees (4 students x 5 days) so a
## designer can retune the note's look in one place. Tinted per
## schedule category via DesignTokens.category_color(), applied to
## self_modulate (not modulate) so the tint never bleeds into the
## child labels' own theme-driven font colors.
##
## The tint is washed toward white before it is applied. self_modulate
## *multiplies* the paper texture, so a full-strength category color --
## or text_secondary, which an unscheduled "-" day resolves to -- drives
## the note dark enough that the dark-brown label text sitting on top of
## it stops being legible on a phone. TINT_WASH keeps the category
## readable as a hue while leaving the note light enough to write on.
##
## MURIDMU RosterCard Task 2 (2026-09-29) adds the note's two skins --
## `scheduled` swaps between the filled category-tinted look and a
## kraft "plan me" empty state (dashed EmptyFrame, "+" icon, muted "Atur"
## label) -- plus a static washi Tape strip and an authored tilt
## (`tilt_degrees`, applied to the root's rotation; RosterCard.tscn's
## StickyNotesContainer is a plain Control, not a layout Container, so the
## rotation is never fought and reset by a parent's own layout pass).
## `set_inviting()` drives the empty note's looped "tap me" glow; Task 3
## (per-day tilts on the card) and Task 4 (wiring `scheduled` from the
## week's real schedule) build on this from the outside -- neither is done
## here.

## How far each category color is pulled toward white before it is
## multiplied into the paper. 0.0 is the raw token (illegible), 1.0 is
## plain white paper with no category read at all.
const TINT_WASH := 0.42

## The washi Tape strip's rest translucency (spec 3.1: "~0.55"), applied to
## its self_modulate alpha in _ready() rather than authored in the .tscn so
## the one tunable number lives in code with everything else here.
const TAPE_ALPHA := 0.55

## The empty note's label text, replacing `activity` while `scheduled` is
## false regardless of what a previous week's category left behind.
const EMPTY_LABEL_TEXT := "Atur"

## Idle "tap me" glow for an unplanned day (spec 4.2): EmptyFrame's
## self_modulate breathes from its kraft rest tone toward accent_sunflower
## and back, in sympathy with a small scale pulse on the "+" icon, one full
## breath every GLOW_PERIOD_SECONDS. Two independent looped Tweens (one per
## animated node) rather than one parallel/chain Tween, so their timing
## never depends on Tween's parallel-then-chain ordering -- both start in
## the same frame, run the same two-phase sine schedule, and stay in sync.
const GLOW_PERIOD_SECONDS := 1.9

## How far EmptyFrame's rest tint travels toward accent_sunflower at the
## glow's peak. 0.0 is no glow, 1.0 is solid sunflower.
const GLOW_TINT_PEAK := 0.55

## The "+" icon's scale at the glow's peak, sympathetic to the frame's tint.
const GLOW_ICON_SCALE_PEAK := 1.12

## Shown uppercased on DayLabel (e.g. "Senin" -> "SENIN").
@export var day_name: String = "Senin":
	set(value):
		day_name = value
		if is_node_ready():
			$DayLabel.text = value.to_upper()

## The schedule category for this day -- shown on ActivityLabel while
## `scheduled` is true, and used to tint the note via
## DesignTokens.category_color(). Ignored by the label while `scheduled` is
## false, so callers do not have to sequence the two exports against each
## other -- see _apply_tint().
@export var activity: String = "-":
	set(value):
		activity = value
		if is_node_ready():
			if scheduled:
				$ActivityLabel.text = value
			_apply_tint()

## How far apart the three pin heights sit, in pixels. The note is 200
## tall inside a 240 band, so slots 0/1/2 land at +0/+20/+40 and the
## whole spread stays inside the strip -- it can never reach the trait
## chips above or the teacher's note below.
const PIN_STEP := 20.0

## Which of the three heights this note hangs at: 0 up, 1 middle, 2
## down. The five days on a card are dealt different slots so the strip
## reads as hand-pinned rather than machine-aligned. The dealing is
## deterministic per student and day (see _setup_students in
## StudentList.gd) -- a note must not jump to a new height every time
## the player swipes back to that card.
@export_range(0, 2) var pin_slot: int = 1:
	set(value):
		pin_slot = clampi(value, 0, 2)
		if is_node_ready():
			_apply_pin()

## The schedule category's glyph, shown on Icon while `scheduled` is true.
## Set from StudentList.gd per the day's scheduled category so every day in
## the week strip reads at a glance. Ignored while `scheduled` is false --
## see icon_texture's setter and empty_icon below.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready() and scheduled:
			$Icon.texture = value

## Whether this day already has an assigned activity. true (the default)
## keeps the note's long-standing filled, category-tinted look; false
## swaps to the kraft "plan me" empty state: EmptyFrame becomes visible,
## Icon shows empty_icon's "+" glyph, and ActivityLabel shows
## EMPTY_LABEL_TEXT ("Atur") in the muted StickyNoteEmptyLabel look,
## whatever `activity`/`icon_texture` currently hold. StudentList.gd does
## not set this yet -- that wiring is Task 4's (day_schedules -> is_day_set
## -> scheduled). Flipping back to true also kills any glow left running
## from set_inviting(), since a scheduled week is calm (spec 4.2).
@export var scheduled: bool = true:
	set(value):
		scheduled = value
		if is_node_ready():
			_apply_state()
			if scheduled:
				_stop_glow()

## The empty-note "+" glyph (Assets/Images/UI/StudentList/icon_add.svg,
## drop-replaceable), shown on Icon while `scheduled` is false. An @export
## with a preloaded default, same rationale as AturJadwal's DayStickyNote
## category_icons/holiday_icon: a designer can override it per instance in
## the Inspector once real art lands.
@export var empty_icon: Texture2D = preload("res://Assets/Images/UI/StudentList/icon_add.svg"):
	set(value):
		empty_icon = value
		if is_node_ready() and not scheduled:
			$Icon.texture = value

## The note's authored tilt in degrees, applied to the whole root's
## rotation about its own centre (see the file header on why rotation
## holds under StickyNotesContainer). 0 is upright; RosterCard.tscn's five
## per-day angles land here via Task 3, not this task.
@export_range(-15.0, 15.0, 0.1) var tilt_degrees: float = 0.0:
	set(value):
		tilt_degrees = value
		if is_node_ready():
			_apply_tilt()

var _glow_tween: Tween
var _glow_icon_tween: Tween
var _inviting := false


## Wash this day's category color toward white and multiply it into the
## paper, or -- while `scheduled` is false -- flatten straight to the kraft
## surface_sunken tone (spec: "the empty note is kraft surface_sunken with
## text_secondary ink"; the wash exists only for the category-hue path).
## Reads `scheduled` directly rather than being folded into _apply_state()
## so activity's setter can call it alone without re-touching the icon/label.
func _apply_tint() -> void:
	var tokens: DesignTokens = DesignTokens.load_default()
	if scheduled:
		var raw: Color = tokens.category_color(activity)
		self_modulate = raw.lerp(Color.WHITE, TINT_WASH)
	else:
		self_modulate = tokens.surface_sunken


## Swaps EmptyFrame's visibility and the Icon/ActivityLabel content between
## the filled and empty skins, then retints via _apply_tint(). The single
## place the `scheduled` setter and _ready() both call, so they cannot drift.
func _apply_state() -> void:
	$EmptyFrame.visible = not scheduled
	if scheduled:
		$Icon.texture = icon_texture
		$ActivityLabel.text = activity
		$ActivityLabel.theme_type_variation = &""
	else:
		$Icon.texture = empty_icon
		$ActivityLabel.text = EMPTY_LABEL_TEXT
		$ActivityLabel.theme_type_variation = &"StickyNoteEmptyLabel"
	_apply_tint()


## Drop the note to its pin height.
##
## Writes offset_top/bottom rather than `position` so the note keeps its
## authored height: Juice.pop_in animates scale and alpha only, so this
## offset survives the card's stagger-in untouched.
func _apply_pin() -> void:
	var drop := pin_slot * PIN_STEP
	offset_top = drop
	offset_bottom = drop + custom_minimum_size.y


## Rotates the whole note about its own centre to tilt_degrees. StickyNote
## is a plain TextureRect inside a plain Control (StickyNotesContainer),
## sized directly by authored offsets rather than a layout Container, so
## `size` is already correct here in _ready() and the rotation is never
## reset by a later layout pass.
func _apply_tilt() -> void:
	pivot_offset = size / 2.0
	rotation_degrees = tilt_degrees


func _ready() -> void:
	$Tape.self_modulate.a = TAPE_ALPHA
	$DayLabel.text = day_name.to_upper()
	_apply_pin()
	_apply_tilt()
	_apply_state()


func _exit_tree() -> void:
	_stop_glow()


## Starts or stops the empty note's "tap me" glow (see set_inviting doc for
## the public contract). Internal: split from set_inviting() so the guard
## clauses read as one block.
func _start_glow() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if GameSettings.reduce_motion:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		return
	var tokens: DesignTokens = DesignTokens.load_default()
	var frame_node: TextureRect = $EmptyFrame
	var icon_node: TextureRect = $Icon
	frame_node.pivot_offset = frame_node.size / 2.0
	icon_node.pivot_offset = icon_node.size / 2.0
	var rest_tint: Color = frame_node.self_modulate
	var peak_tint: Color = rest_tint.lerp(tokens.accent_sunflower, GLOW_TINT_PEAK)
	var half: float = GLOW_PERIOD_SECONDS / 2.0

	_glow_tween = create_tween().set_loops()
	_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(frame_node, "self_modulate", peak_tint, half)
	_glow_tween.tween_property(frame_node, "self_modulate", rest_tint, half)

	_glow_icon_tween = create_tween().set_loops()
	_glow_icon_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_icon_tween.tween_property(icon_node, "scale", Vector2.ONE * GLOW_ICON_SCALE_PEAK, half)
	_glow_icon_tween.tween_property(icon_node, "scale", Vector2.ONE, half)


## Kills both glow Tweens (frame tint + icon pulse) and settles their nodes
## back to rest. Safe to call whether or not a glow is running.
func _stop_glow() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
	if _glow_icon_tween != null and _glow_icon_tween.is_valid():
		_glow_icon_tween.kill()
	_glow_icon_tween = null
	var icon_node := get_node_or_null("Icon") as TextureRect
	if icon_node != null:
		icon_node.scale = Vector2.ONE
	var frame_node := get_node_or_null("EmptyFrame") as TextureRect
	if frame_node != null:
		frame_node.self_modulate = DesignTokens.load_default().surface_sunken


## Starts (on == true) or stops (on == false) the empty note's looped "tap
## me" glow: EmptyFrame's self_modulate breathes toward accent_sunflower and
## back while the "+" icon pulses in sympathy (spec 4.2). Callers (Task 3's
## per-card idle-loop policy) own WHEN this runs -- e.g. only the front
## card's empty notes, paused during a swipe or popup -- this method only
## owns HOW. No-op in the editor and skipped entirely under
## GameSettings.reduce_motion; killed in _exit_tree so nothing leaks across
## a card swipe. Flipping `scheduled` to true also stops it, since a filled
## note never glows.
func set_inviting(on: bool) -> void:
	_inviting = on
	if on:
		_start_glow()
	else:
		_stop_glow()


## Whether the empty-note glow is the caller's last-requested state. Not the
## same as "a Tween is currently running" -- under reduce_motion or in the
## editor, set_inviting(true) records the request but starts nothing.
func is_inviting() -> bool:
	return _inviting
