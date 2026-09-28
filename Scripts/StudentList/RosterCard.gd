@tool
class_name RosterCard
extends TextureRect

## One student's paper card in the StudentList carousel. Extracted from
## four near-identical ~130-line inline subtrees (Murid1..4, about 600
## lines of StudentList.tscn) so the card is authored once -- the same
## move already made for StickyNote.
##
## Instanced four times under the names Murid1..4. Those names are
## load-bearing: tests/test_student_list.gd resolves CardContainer/Murid%d
## and the tutorial's first step targets CardContainer.
##
## @tool so the Inspector and the MCP test suite see applied state, with
## every setter guarded on is_node_ready() -- StickyNote.gd's pattern.
## Every tunable is an @export on THIS root, never a property set on an
## instance's child: overrides serialise only on an instanced scene's
## root, so a value poked into a child reports success and is dropped on
## save. StudentList.gd still pokes some children by path (Nama, Belum,
## Sudah, PortraitFrame/Portrait, StickyNotesContainer, CardButton) --
## those stay direct children at the paths it reads. This script reaches
## every node it touches by its %unique name instead.
##
## MURIDMU RosterCard Task 3 (2026-09-29) dresses the card as a weekly
## planner (spec 3.2-3.4): a torn "JADWAL MINGGU INI" WeekHeader with a
## calendar glyph, a "n/5 hari" count and a five-dot DayTally (TallyDot
## instances, filled by `days_scheduled`); per-day authored tilts on the
## five notes (their `tilt_degrees`, set in RosterCard.tscn); a Clip over
## the tilted PortraitFrame; a Pencil and a red MarginRule in the catatan.
## It also owns the card's motion: play_entry() (the spec 4 entry beats)
## and set_breathing() (the idle paper breath, spec 4.2).
##
## Why the breath animates `Paper` and not the card: the swipe deck moves
## the card ROOT, and two animations on one transform fight. Paper holds
## only the card's surface (the Sheet and the LiftShadow under it), not the
## bands above it, because StudentList.gd reaches those bands by their
## direct-child paths. The bands sit still while the sheet swells under
## them by at most ~1%, which reads as the paper lifting off the desk.

## The number of weekdays in a school week: the tally's dot count and the
## ceiling days_scheduled clamps to.
const WEEK_DAYS := 5

## The tally count label's text, "<scheduled>/<WEEK_DAYS> hari".
const TALLY_FORMAT := "%d/%d hari"

## play_entry()'s beat sheet (spec 4, "the entry beat"): seconds after the
## call at which each band lands. The card's own slide-in is 0.00s and
## belongs to the carousel, not to this script.
const ENTRY_NAME_AT := 0.25
## The portrait frame's squash-to-rest.
const ENTRY_PORTRAIT_AT := 0.30
## The first trait chip's pop; the rest follow ENTRY_TRAIT_STEP apart.
const ENTRY_TRAITS_AT := 0.45
## Gap between consecutive trait chips.
const ENTRY_TRAIT_STEP := 0.06
## The Belum/Sudah stamp's thunk.
const ENTRY_STAMP_AT := 0.70
## The first (Senin) note's rotate-overshoot; the rest follow
## ENTRY_NOTE_STEP apart, so Jumat lands at ~1.5s.
const ENTRY_NOTES_AT := 0.90
## Gap between consecutive notes' overshoots.
const ENTRY_NOTE_STEP := 0.15
## The first filled tally dot's pop; the rest follow ENTRY_TALLY_STEP apart.
const ENTRY_TALLY_AT := 1.80
## Gap between consecutive tally dot pops.
const ENTRY_TALLY_STEP := 0.08

## How far below its rest the name starts before it fades up, px.
const NAME_RISE_PX := 18.0
## The name's fade-up duration.
const NAME_FADE_SECONDS := 0.25

## A note swings past its authored tilt by this factor before settling
## ("start at 0, overshoot to angle x1.4, settle" -- spec 4).
const NOTE_OVERSHOOT := 1.4
## The swing from upright to the overshoot.
const NOTE_SWING_SECONDS := 0.14
## The settle from the overshoot back to the authored tilt.
const NOTE_SETTLE_SECONDS := 0.22

## The paper's idle breath (spec 4.2): one full breath in seconds.
const BREATH_PERIOD_SECONDS := 3.6
## Paper's scale at the top of a breath.
const BREATH_SCALE_PEAK := 1.012
## LiftShadow's modulate alpha at the top of a breath: the shadow deepens
## as the paper rises. Its tone is shadow_color, applied to self_modulate.
const BREATH_SHADOW_PEAK := 1.0

## Shown on the Nama label.
@export var student_name: String = "":
	set(value):
		student_name = value
		if is_node_ready():
			%Nama.text = value

## The student's portrait, drawn in the taped frame.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if is_node_ready():
			%Portrait.texture = value

## The student's hobby_category. Drives the specialty chip's label and
## icon; see SPECIALTY_ICONS.
@export var specialty: String = "":
	set(value):
		specialty = value
		if is_node_ready():
			_apply_specialty()

## The student's personality. Drives the persona chip and the catatan
## guru's opening line.
@export var persona: String = "":
	set(value):
		persona = value
		if is_node_ready():
			_apply_traits()

## The student's quirk. Drives the quirk chip and the catatan guru's
## closing observation.
@export var quirk: String = "":
	set(value):
		quirk = value
		if is_node_ready():
			_apply_traits()

## True once this student's week is scheduled. Swaps the Sudah stamp in
## for the Belum stamp.
@export var is_scheduled: bool = false:
	set(value):
		is_scheduled = value
		if is_node_ready():
			_apply_scheduled()

## How many of the week's five days this student has scheduled, clamped to
## 0..WEEK_DAYS. Fills the first that-many DayTally dots and writes the
## "n/5 hari" count beside them. StudentList sums the week's set days into
## it (Task 4); the dots only pop when play_entry() lands them.
@export_range(0, 5) var days_scheduled: int = 0:
	set(value):
		days_scheduled = clampi(value, 0, WEEK_DAYS)
		if is_node_ready():
			_apply_days_scheduled()


## Category icon per specialty, keyed by every spelling the data uses --
## hobby_category ships "Akademik" where the schedule normalises to
## "Akademis", and both must resolve.
##
## The team's authored art, matching the same categories on the day
## notes -- see CATEGORY_ICONS in StudentList.gd. Both maps point at
## the StudentCard stat_* set so a student's specialty chip, their day
## notes and their stat rows all carry the one symbol per subject.
const SPECIALTY_ICONS := {
	"Akademis": "res://Assets/Images/StudentCard/stat_akademis.png",
	"Akademik": "res://Assets/Images/StudentCard/stat_akademis.png",
	"SeniBudaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"Seni Budaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"Olahraga": "res://Assets/Images/StudentCard/stat_olahraga.png",
	"Istirahat": "res://Assets/Images/StudentCard/stat_energy.png",
	"Wirausaha": "res://Assets/Images/UI/uang.png",
	"Libur": "res://Assets/Images/StudentCard/stat_mood.png",
}

## Opening line of the catatan guru, keyed by personality. First-draft
## Indonesian copy -- tunable here rather than buried in logic, per the
## project's tunables convention.
const CATATAN_PERSONA := {
	"Aktif": "Energinya tumpah ke mana-mana.",
	"Tekun": "Duduk paling depan, catatannya rapi.",
	"Kreatif": "Selalu punya cara sendiri.",
	"Santai": "Santai, tapi jangan diremehkan.",
	"Seni Dalam Kesunyian": "Paling tenang di kelas.",
}

## Closing observation of the catatan guru, keyed by quirk.
const CATATAN_QUIRK := {
	"Kutu Buku": "Perpustakaan sudah seperti rumah kedua.",
	"Penyendiri": "Lebih nyaman kerja sendiri daripada berkelompok.",
	"Semangat Juang": "Tidak pernah menyerah walau tertinggal.",
	"Penasaran": "Pertanyaannya sering di luar dugaan.",
	"Biang Onar": "Perlu diawasi kalau jam kosong.",
	"Pekerja Keras": "Pulang paling akhir, hampir tiap hari.",
}

## Shown when neither the persona nor the quirk resolves, so the strip is
## never blank.
const CATATAN_FALLBACK := "Belum ada catatan untuk murid ini."

## The sequencer of play_entry()'s beats (callbacks at their delays).
var _entry_tween: Tween
## Every Tween a beat started, so a re-entry or a card leaving kills them.
var _entry_motion: Array[Tween] = []
## The looped paper breath, while one runs.
var _breath_tween: Tween
## The caller's last-requested breathing state (see is_breathing()).
var _breathing := false
## Nama's authored position, the rest its fade-up rises to.
var _nama_rest := Vector2.ZERO


## Five openers x six observations gives thirty notes from eleven
## strings. Static so it is unit-testable without instancing the scene.
static func compose_catatan(persona_name: String, quirk_name: String) -> String:
	var parts: Array[String] = []
	if CATATAN_PERSONA.has(persona_name):
		parts.append(CATATAN_PERSONA[persona_name])
	if CATATAN_QUIRK.has(quirk_name):
		parts.append(CATATAN_QUIRK[quirk_name])
	if parts.is_empty():
		return CATATAN_FALLBACK
	return " ".join(parts)


func _ready() -> void:
	%Nama.text = student_name
	%Portrait.texture = portrait_texture
	_nama_rest = (%Nama as Control).position
	_apply_specialty()
	_apply_traits()
	_apply_scheduled()
	_apply_days_scheduled()
	_apply_token_tints()


func _exit_tree() -> void:
	_kill_entry()
	_stop_breathing()


## Glyph plus word. The chips sit on the compact SpecialtyBadgeS /
## PersonaBadgeS / QuirkBadgeS step -- font_caption over space_xs/space_md
## rather than font_title over btn_pad_v_s/space_lg -- which is what makes
## three labelled pills fit the card's 880px trait row. At the full size
## they overflowed it and clipped every label ("Akademis" -> "AKA").
func _apply_specialty() -> void:
	var chip: Button = %SpecialtyChip
	chip.text = specialty
	chip.tooltip_text = specialty
	if SPECIALTY_ICONS.has(specialty):
		chip.icon = load(SPECIALTY_ICONS[specialty])
	else:
		chip.icon = null


func _apply_traits() -> void:
	%PersonaChip.text = persona
	%QuirkChip.text = quirk
	%CatatanLabel.text = compose_catatan(persona, quirk)


func _apply_scheduled() -> void:
	%Belum.visible = not is_scheduled
	%Sudah.visible = is_scheduled


## Fills the first days_scheduled dots, empties the rest, and writes the
## count beside them.
func _apply_days_scheduled() -> void:
	var label := _required("TallyLabel") as Label
	if label != null:
		label.text = TALLY_FORMAT % [days_scheduled, WEEK_DAYS]
	var index := 0
	for dot: TallyDot in get_tally_dots():
		dot.filled = index < days_scheduled
		index += 1


## The props drawn white for tinting take their tones from DesignTokens,
## never from a Color literal: the torn band's kraft, the catatan's red
## exercise-book margin rule, and the breathing shadow's ink.
func _apply_token_tints() -> void:
	var tokens: DesignTokens = DesignTokens.load_default()
	var band := _required("Band") as CanvasItem
	if band != null:
		band.self_modulate = tokens.surface_sunken
	var rule := _required("MarginRule") as ColorRect
	if rule != null:
		rule.color = tokens.accent_tomato
	var shadow := _required("LiftShadow") as CanvasItem
	if shadow != null:
		shadow.self_modulate = tokens.shadow_color


## The %-named node `unique` from this scene, or null after a push_error:
## every node a caller asks for is one RosterCard.tscn must have.
func _required(unique: String) -> Node:
	var node: Node = get_node_or_null("%" + unique)
	if node == null:
		push_error("RosterCard: %%%s is missing from RosterCard.tscn" % unique)
	return node


# ------------------------------------------------------------ public reach

## The five day notes (Senin..Jumat under StickyNotesContainer), in day
## order. Task 4 sets each one's `scheduled` from the week.
func get_notes() -> Array[StickyNote]:
	var notes: Array[StickyNote] = []
	var container := _required("StickyNotesContainer")
	if container == null:
		return notes
	for child: Node in container.get_children():
		if child is StickyNote:
			notes.append(child as StickyNote)
	return notes


## DayTally's five TallyDot instances, in day order.
func get_tally_dots() -> Array[TallyDot]:
	var dots: Array[TallyDot] = []
	var row := _required("DayTally")
	if row == null:
		return dots
	for child: Node in row.get_children():
		if child is TallyDot:
			dots.append(child as TallyDot)
	return dots


## Starts or stops the "tap me" glow on this card's EMPTY day notes only --
## a scheduled day is calm (spec 4.2). One call so StudentList can drive
## the front card's idle loops without walking its notes.
func set_inviting(on: bool) -> void:
	for note: StickyNote in get_notes():
		note.set_inviting(on and not note.scheduled)


# ------------------------------------------------------------- entry beats

## The card arriving alive (spec 4's beat table): Nama fades up, the
## portrait frame squashes to rest, the trait chips pop in one by one, the
## Belum/Sudah stamp thunks down (AnimUtils.popup_spring_in), each day note
## swings past its authored tilt and settles, and the filled tally dots
## pop. Timings are the ENTRY_* consts. The notes' own drop (scale/alpha)
## stays StudentList's pinned Juice.stagger_in; this only adds their
## rotate-overshoot on top.
##
## Safe to call again mid-entry: it kills the running beats and restages.
## No-op in the editor; under GameSettings.reduce_motion it skips every
## beat (the overshoots included) and just places the card at rest.
func play_entry() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	_kill_entry()
	if GameSettings.reduce_motion:
		_settle_at_rest()
		return
	_stage_for_entry()
	_entry_tween = create_tween().set_parallel(true)
	_entry_tween.tween_callback(_beat_name).set_delay(ENTRY_NAME_AT)
	_entry_tween.tween_callback(_beat_portrait).set_delay(ENTRY_PORTRAIT_AT)
	_entry_tween.tween_callback(_beat_stamp).set_delay(ENTRY_STAMP_AT)
	var dots: Array[TallyDot] = get_tally_dots()
	for i: int in range(mini(days_scheduled, dots.size())):
		var at: float = ENTRY_TALLY_AT + i * ENTRY_TALLY_STEP
		_entry_tween.tween_callback(_pop_dot.bind(dots[i])).set_delay(at)
	_queue_trait_pops()
	_queue_note_swings()


## Kills a running entry and places every band at rest -- for a card that
## leaves mid-entry (a swipe, a popup) and must not stay half-staged.
func stop_entry() -> void:
	_kill_entry()
	_settle_at_rest()


func _kill_entry() -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_entry_tween = null
	for tween: Tween in _entry_motion:
		if tween != null and tween.is_valid():
			tween.kill()
	_entry_motion.clear()


func _track(tween: Tween) -> void:
	if tween != null:
		_entry_motion.append(tween)


## Every band play_entry() moves, at its resting pose.
func _settle_at_rest() -> void:
	var nama := _required("Nama") as Control
	if nama != null:
		nama.modulate.a = 1.0
		nama.position = _nama_rest
	for stamp_name: String in ["Belum", "Sudah"]:
		var stamp := _required(stamp_name) as Control
		if stamp != null:
			stamp.modulate.a = 1.0
			stamp.scale = Vector2.ONE
			stamp.rotation_degrees = 0.0
	var frame := _required("PortraitFrame") as Control
	if frame != null:
		frame.scale = Vector2.ONE
	for chip: Control in _trait_chips():
		chip.modulate.a = 1.0
		chip.scale = Vector2.ONE
	for note: StickyNote in get_notes():
		note.rotation_degrees = note.tilt_degrees
	for dot: TallyDot in get_tally_dots():
		dot.scale = Vector2.ONE


## The pose each beat starts from: at rest, then the name lowered and
## hidden, the showing stamp hidden, and every note upright.
func _stage_for_entry() -> void:
	_settle_at_rest()
	var nama := _required("Nama") as Control
	if nama != null:
		nama.modulate.a = 0.0
		nama.position = _nama_rest + Vector2(0.0, NAME_RISE_PX)
	var stamp := _showing_stamp()
	if stamp != null:
		stamp.modulate.a = 0.0
	for note: StickyNote in get_notes():
		note.rotation_degrees = 0.0


func _showing_stamp() -> Control:
	return _required("Sudah" if is_scheduled else "Belum") as Control


func _trait_chips() -> Array[Control]:
	var chips: Array[Control] = []
	var row := _required("TraitRow")
	if row == null:
		return chips
	for child: Node in row.get_children():
		if child is Control:
			chips.append(child as Control)
	return chips


func _beat_name() -> void:
	var nama := _required("Nama") as Control
	if nama == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(nama, "modulate:a", 1.0, NAME_FADE_SECONDS)
	tween.tween_property(nama, "position", _nama_rest, NAME_FADE_SECONDS)
	_track(tween)


## A scale-only squash: squash_bounce is given no tilt, so the frame keeps
## its authored -1.5 degree rest rotation.
func _beat_portrait() -> void:
	var frame := _required("PortraitFrame") as Control
	if frame != null:
		_track(AnimUtils.squash_bounce(frame))


func _beat_stamp() -> void:
	var stamp := _showing_stamp()
	if stamp == null:
		return
	stamp.modulate.a = 1.0
	_track(AnimUtils.popup_spring_in(stamp))


func _pop_dot(dot: TallyDot) -> void:
	if is_instance_valid(dot):
		_track(dot.pop())


## Juice.pop_in hides each chip at once and grows it in after its delay,
## so the chips wait out the earlier beats invisible.
func _queue_trait_pops() -> void:
	var chips: Array[Control] = _trait_chips()
	for i: int in range(chips.size()):
		_track(Juice.pop_in(chips[i], ENTRY_TRAITS_AT + i * ENTRY_TRAIT_STEP))


## Each note, upright since _stage_for_entry(), swings past its authored
## tilt by NOTE_OVERSHOOT and settles back onto it.
func _queue_note_swings() -> void:
	var notes: Array[StickyNote] = get_notes()
	for i: int in range(notes.size()):
		var note: StickyNote = notes[i]
		var tween := create_tween()
		tween.tween_interval(ENTRY_NOTES_AT + i * ENTRY_NOTE_STEP)
		tween.tween_property(note, "rotation_degrees",
			note.tilt_degrees * NOTE_OVERSHOOT, NOTE_SWING_SECONDS) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(note, "rotation_degrees",
			note.tilt_degrees, NOTE_SETTLE_SECONDS) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_track(tween)


# ---------------------------------------------------------------- breathing

## Starts (on == true) or stops the paper's idle breath: the inner Paper
## (the card's surface, never the card root the swipe deck moves) scales
## 1 <-> BREATH_SCALE_PEAK while LiftShadow deepens under it, one breath
## every BREATH_PERIOD_SECONDS. For the FRONT card only; the caller pauses
## it during a swipe and while a popup or the tutorial is up. The looped
## Tween is stored here and killed on stop and in _exit_tree. No-op in the
## editor and under GameSettings.reduce_motion (the request is still
## recorded -- see is_breathing()).
func set_breathing(on: bool) -> void:
	_breathing = on
	if not on:
		_stop_breathing()
		return
	if _breath_tween != null and _breath_tween.is_valid():
		return
	_start_breathing()


## The caller's last-requested breathing state -- not the same as "a Tween
## is running", which it is not in the editor or under reduce_motion.
func is_breathing() -> bool:
	return _breathing


func _start_breathing() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if GameSettings.reduce_motion:
		return
	var paper := _required("Paper") as Control
	var shadow := _required("LiftShadow") as CanvasItem
	if paper == null or shadow == null:
		return
	paper.pivot_offset = paper.size / 2.0
	var half: float = BREATH_PERIOD_SECONDS / 2.0
	_breath_tween = create_tween().set_loops()
	_breath_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(paper, "scale", Vector2.ONE * BREATH_SCALE_PEAK, half)
	_breath_tween.parallel().tween_property(shadow, "modulate:a", BREATH_SHADOW_PEAK, half)
	_breath_tween.tween_property(paper, "scale", Vector2.ONE, half)
	_breath_tween.parallel().tween_property(shadow, "modulate:a", 0.0, half)


## Kills the breath and settles Paper and its shadow back to rest. Safe
## whether or not a breath is running, and during teardown.
func _stop_breathing() -> void:
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null
	var paper := get_node_or_null("%Paper") as Control
	if paper != null:
		paper.scale = Vector2.ONE
	var shadow := get_node_or_null("%LiftShadow") as CanvasItem
	if shadow != null:
		shadow.modulate.a = 0.0
