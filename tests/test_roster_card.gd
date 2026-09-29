@tool
extends McpTestSuite

## RosterCard's weekly-planner dressing (MURIDMU RosterCard Task 3,
## 2026-09-29): the torn "JADWAL MINGGU INI" WeekHeader with its calendar
## glyph, "n/5 hari" count and five-dot DayTally (`days_scheduled`); the
## five notes' authored tilts; the paperclip over the tilted portrait; the
## catatan's pencil and red margin rule; the inner Paper the idle breath
## animates; and the entry/breath motion API (play_entry, set_breathing).
##
## Behavioural where it can be: RosterCard and TallyDot are @tool, so their
## _ready fires when this suite adds them to the editor root and the
## assertions read applied state. The motion itself cannot run here --
## play_entry() and set_breathing() are deliberately no-ops in the editor --
## so those tests pin the no-op, the settle-at-rest path, and (by source
## scan) the named timing constants and the reduce_motion guard.
##
## test_student_list.gd keeps the card's older structural pins (Nama,
## Belum/Sudah, the Senin..Jumat StickyNote instances, the band order).
##
## Must be @tool (the runner reports a non-@tool suite as abstract/broken)
## and no test here may be a coroutine (the runner calls `suite.call(name)`
## without awaiting).

const _CARD_SCENE := "res://Scenes/StudentList/RosterCard.tscn"
const _CARD_SCRIPT := "res://Scripts/StudentList/RosterCard.gd"
const _DOT_SCENE := "res://Scenes/StudentList/TallyDot.tscn"
const _DOT_SCRIPT := "res://Scripts/StudentList/TallyDot.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _ART := "res://Assets/Images/UI/StudentList/"

## Per-day authored tilts (spec 3.1), degrees.
const _TILTS := {
	"Senin": -2.5, "Selasa": 1.5, "Rabu": -1.5, "Kamis": 2.0, "Jumat": -1.0,
}

## Rotation comparisons go through radians and back; this is plenty.
const _DEG_EPSILON := 0.01

var _card: RosterCard


func suite_name() -> String:
	return "roster_card"


func setup() -> void:
	_card = (load(_CARD_SCENE) as PackedScene).instantiate()
	_card.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_card)
	track(_card)


func _dots() -> Array[TallyDot]:
	return _card.get_tally_dots()


# ------------------------------------------------------------ days tally

func test_days_scheduled_is_an_export_that_clamps_to_the_week() -> void:
	assert_true("days_scheduled" in _card, "RosterCard must expose days_scheduled")
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	assert_true(src.contains("@export_range(0, 5) var days_scheduled: int"),
		"days_scheduled must be a bounded int export")
	_card.days_scheduled = 7
	assert_eq(_card.days_scheduled, 5, "above the week clamps to 5")
	_card.days_scheduled = -2
	assert_eq(_card.days_scheduled, 0, "below zero clamps to 0")


func test_three_days_fill_exactly_the_first_three_dots() -> void:
	_card.days_scheduled = 3
	var dots := _dots()
	assert_eq(dots.size(), 5, "the tally has five dots")
	for i: int in range(dots.size()):
		assert_eq(dots[i].filled, i < 3, "dot %d filled state for 3/5" % (i + 1))
	var label := _card.get_node_or_null("Paper/WeekHeader/TallyLabel") as Label
	assert_true(label != null, "missing WeekHeader/TallyLabel")
	if label != null:
		assert_eq(label.text, "3/5 hari", "the count reads n/5 hari")
		assert_eq(label.theme_type_variation, &"WeekTallyLabel", "TallyLabel variation")


func test_an_unscheduled_card_reads_zero_of_five() -> void:
	assert_eq(_card.days_scheduled, 0, "a fresh card has no days scheduled")
	for dot: TallyDot in _dots():
		assert_false(dot.filled, "no dot is filled at 0/5")
	var label := _card.get_node_or_null("Paper/WeekHeader/TallyLabel") as Label
	assert_true(label != null and label.text == "0/5 hari", "the count reads 0/5 hari")


func test_day_tally_is_five_authored_tally_dot_instances() -> void:
	var row := _card.get_node_or_null("Paper/WeekHeader/DayTally") as HBoxContainer
	assert_true(row != null, "missing WeekHeader/DayTally (an HBoxContainer)")
	if row == null:
		return
	assert_eq(row.get_child_count(), 5, "DayTally holds exactly five dots")
	for child: Node in row.get_children():
		assert_true(child is TallyDot, "%s must be a TallyDot" % child.name)
		assert_eq(child.scene_file_path, _DOT_SCENE,
			"%s must be an instance of the TallyDot template" % child.name)
		# Authored, not built at runtime: owned by the card scene.
		assert_eq(child.owner, _card, "%s must be authored in RosterCard.tscn" % child.name)


# ------------------------------------------------------------ week header

func test_week_header_carries_band_title_and_calendar() -> void:
	var header := _card.get_node_or_null("Paper/WeekHeader") as Control
	assert_true(header != null, "missing WeekHeader")
	var band := _card.get_node_or_null("Paper/WeekHeader/Band") as TextureRect
	assert_true(band != null, "missing WeekHeader/Band")
	if band != null:
		assert_eq(band.texture, load(_ART + "torn_band.svg"), "Band wears torn_band.svg")
		assert_true(absf(band.rotation_degrees - -1.0) < _DEG_EPSILON,
			"the band hangs at -1 degree, got %f" % band.rotation_degrees)
		assert_eq(band.self_modulate, DesignTokens.load_default().surface_sunken,
			"the white band is tinted kraft surface_sunken")
	var title := _card.get_node_or_null("Paper/WeekHeader/Title") as Label
	assert_true(title != null, "missing WeekHeader/Title")
	if title != null:
		assert_eq(title.text, "JADWAL MINGGU INI", "the band's title")
		assert_eq(title.theme_type_variation, &"CardSectionLabel", "Title variation")
	var icon := _card.get_node_or_null("Paper/WeekHeader/Icon") as TextureRect
	assert_true(icon != null, "missing WeekHeader/Icon")
	if icon != null:
		assert_eq(icon.texture, load(_ART + "icon_calendar.svg"), "the calendar glyph")
		assert_true(title != null and icon.offset_right <= title.offset_left,
			"the calendar sits to the left of the title")


## The header takes its room from the week strip's top, never from the card:
## it must sit between the trait chips and the notes, and clear the tape
## that pokes above a top-slot note.
func test_week_header_sits_between_the_traits_and_the_taped_notes() -> void:
	var header := _card.get_node("Paper/WeekHeader") as Control
	var traits := _card.get_node("Paper/TraitRow") as Control
	var strip := _card.get_node("Paper/StickyNotesContainer") as Control
	assert_true(header.offset_top >= traits.offset_bottom,
		"WeekHeader must start below TraitRow")
	var tape := _card.get_node("Paper/StickyNotesContainer/Senin/Tape") as Control
	var tape_top: float = strip.offset_top + tape.offset_top
	assert_true(header.offset_bottom <= tape_top,
		"WeekHeader (bottom %f) must clear a top-slot note's tape (top %f)"
			% [header.offset_bottom, tape_top])


# ------------------------------------------------------------- the notes

func test_the_five_notes_carry_their_authored_tilts() -> void:
	for day: String in _TILTS:
		var note := _card.get_node_or_null("Paper/StickyNotesContainer/" + day) as StickyNote
		assert_true(note != null, "missing note " + day)
		if note == null:
			continue
		assert_eq(note.tilt_degrees, float(_TILTS[day]), day + " tilt_degrees")
		assert_true(absf(note.rotation_degrees - float(_TILTS[day])) < _DEG_EPSILON,
			"%s must be rotated to its tilt, got %f" % [day, note.rotation_degrees])


func test_set_inviting_asks_only_the_empty_notes() -> void:
	var notes: Array[StickyNote] = _card.get_notes()
	assert_eq(notes.size(), 5, "get_notes returns the five day notes")
	for i: int in range(notes.size()):
		notes[i].scheduled = i % 2 == 0
	_card.set_inviting(true)
	for note: StickyNote in notes:
		assert_eq(note.is_inviting(), not note.scheduled,
			"%s invites only when empty" % note.name)
	_card.set_inviting(false)
	for note: StickyNote in notes:
		assert_false(note.is_inviting(), "%s stops inviting" % note.name)


## MURIDMU Task 4 fix: StudentList is not @tool, so the editor gives it a
## placeholder instance a test cannot call into -- the week-scheduling half
## of Task 4's work moved here, onto RosterCard, which is @tool and real.
func test_apply_week_sets_each_notes_scheduled_and_the_tally() -> void:
	_card.apply_week({
		"Senin": {"category": "Akademis"},
		"Rabu": {"category": "Olahraga"},
	})
	assert_eq(_card.days_scheduled, 2, "two of five days are set")
	var expected := {"Senin": true, "Selasa": false, "Rabu": true, "Kamis": false, "Jumat": false}
	for day: String in expected:
		var note := _card.get_node("Paper/StickyNotesContainer/" + day) as StickyNote
		assert_eq(note.scheduled, expected[day], "%s.scheduled mismatch" % day)


## apply_week() must actively clear a day, not just skip ones that ARE set --
## otherwise a card reused for a different student keeps its predecessor's
## week.
func test_apply_week_with_nothing_set_clears_every_note() -> void:
	_card.apply_week({"Senin": {"category": "Akademis"}})
	_card.apply_week({})
	assert_eq(_card.days_scheduled, 0, "nothing is scheduled")
	for note: StickyNote in _card.get_notes():
		assert_false(note.scheduled, "%s must clear when the week has nothing" % note.name)


# ------------------------------------------------------------ the portrait

func test_the_portrait_frame_is_taped_down_at_minus_one_and_a_half() -> void:
	var frame := _card.get_node_or_null("Paper/PortraitFrame") as Control
	assert_true(frame != null, "missing PortraitFrame")
	if frame == null:
		return
	assert_true(absf(frame.rotation_degrees - -1.5) < _DEG_EPSILON,
		"PortraitFrame must rest at -1.5 degrees, got %f" % frame.rotation_degrees)
	assert_eq(frame.pivot_offset, frame.size / 2.0, "the tilt pivots on the frame's centre")


func test_a_paperclip_sits_over_the_portrait() -> void:
	var clip := _card.get_node_or_null("Paper/PortraitFrame/Clip") as TextureRect
	assert_true(clip != null, "missing PortraitFrame/Clip")
	if clip == null:
		return
	assert_eq(clip.texture, load(_ART + "paperclip.svg"), "Clip wears paperclip.svg")
	var portrait := _card.get_node("Paper/PortraitFrame/Portrait") as Control
	assert_true(clip.get_index() > portrait.get_index(), "the clip draws over the portrait")
	assert_true(clip.offset_top < 0.0 and clip.offset_bottom > 0.0,
		"the clip straddles the frame's top edge")
	assert_eq(clip.anchor_left, 0.5, "the clip is pinned top-centre")
	assert_true(absf(clip.rotation_degrees - 8.0) < _DEG_EPSILON,
		"the clip hangs at ~8 degrees, got %f" % clip.rotation_degrees)


# ------------------------------------------------------------- the catatan

func test_the_catatan_has_a_pencil_and_a_tomato_margin_rule() -> void:
	var pencil := _card.get_node_or_null("Paper/CatatanGuru/Pencil") as TextureRect
	assert_true(pencil != null, "missing CatatanGuru/Pencil")
	if pencil != null:
		assert_eq(pencil.texture, load(_ART + "pencil.svg"), "Pencil wears pencil.svg")
	var rule := _card.get_node_or_null("Paper/CatatanGuru/MarginRule") as ColorRect
	assert_true(rule != null, "missing CatatanGuru/MarginRule (a ColorRect)")
	if rule == null:
		return
	assert_eq(rule.color, DesignTokens.load_default().accent_tomato,
		"the margin rule is accent_tomato, read from the tokens")
	assert_eq(rule.anchor_bottom, 1.0, "the rule runs the note's full height")
	var label := _card.get_node("Paper/CatatanGuru/CatatanLabel") as Control
	assert_true(rule.offset_right <= label.offset_left,
		"the note's text starts right of the margin rule")
	if pencil != null:
		assert_true(pencil.offset_right <= rule.offset_left,
			"the pencil lies in the gutter, left of the margin rule")


# -------------------------------------------------------- paper & breathing

## The whole visible card is on Paper, so the breath swells the paper and
## everything printed on it as one piece. Only CardButton -- an invisible
## hit area -- stays on the root, drawn last so it takes every tap.
func test_paper_holds_every_band_and_only_the_tap_target_stays_outside() -> void:
	assert_eq(_card.get_child_count(), 2, "the card root holds Paper and CardButton only")
	var button := _card.get_node_or_null("CardButton") as Button
	assert_true(button != null and button.get_index() == 1,
		"CardButton is a direct child drawn over Paper")
	for band: String in ["Sheet", "Belum", "Sudah", "Nama", "PortraitFrame", "TraitRow",
			"WeekHeader", "StickyNotesContainer", "CatatanGuru"]:
		assert_true(_card.get_node_or_null("Paper/" + band) != null,
			band + " must ride on Paper so it breathes with the sheet")


func test_paper_holds_the_surface_and_draws_first() -> void:
	var paper := _card.get_node_or_null("Paper") as Control
	assert_true(paper != null, "missing Paper")
	if paper == null:
		return
	assert_eq(paper.get_index(), 0, "Paper draws behind every band")
	assert_eq(paper.anchor_right, 1.0, "Paper spans the card's width")
	assert_eq(paper.anchor_bottom, 1.0, "Paper spans the card's height")
	var sheet := paper.get_node_or_null("Sheet") as Panel
	var shadow := paper.get_node_or_null("LiftShadow") as Panel
	assert_true(sheet != null and shadow != null, "Paper holds Sheet and LiftShadow")
	if sheet != null and shadow != null:
		assert_true(shadow.get_index() < sheet.get_index(), "the lift shadow sits under the sheet")
		assert_eq(shadow.modulate.a, 0.0, "the lift shadow is invisible at rest")
		assert_eq(shadow.self_modulate, DesignTokens.load_default().shadow_color,
			"the lift shadow's ink is shadow_color")


func test_breathing_is_recorded_but_idle_in_the_editor_and_never_moves_the_root() -> void:
	_card.set_breathing(true)
	assert_true(_card.is_breathing(), "the request is recorded")
	assert_eq(_card.scale, Vector2.ONE, "the card root never breathes")
	assert_eq((_card.get_node("Paper") as Control).scale, Vector2.ONE,
		"no breath runs in the editor")
	_card.set_breathing(false)
	assert_false(_card.is_breathing(), "the stop is recorded")
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	assert_true(src.contains('tween_property(paper, "scale"'), "the breath scales Paper")
	assert_false(src.contains("tween_property(self"), "no tween animates the card root")


## _exit_tree pauses the breath; a card put back in the tree (the deck may
## reparent it) must still be asked to breathe.
func test_breathing_request_survives_leaving_and_rejoining_the_tree() -> void:
	_card.set_breathing(true)
	var parent := _card.get_parent()
	parent.remove_child(_card)
	parent.add_child(_card)
	assert_true(_card.is_breathing(), "the request outlives a trip out of the tree")
	assert_eq((_card.get_node("Paper") as Control).scale, Vector2.ONE,
		"leaving the tree settles the paper")
	_card.set_breathing(false)
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	var entering := src.get_slice("func _enter_tree() -> void:", 1).get_slice("
func ", 0)
	assert_true(entering.contains("if _breathing:") and entering.contains("_start_breathing"),
		"_enter_tree must resume a standing breath request")


## set_front() is StudentList's one call for "this is the front card now":
## breathing and each empty note's glow together, so StudentList need not
## drive them separately (MURIDMU Task 4 fix).
func test_set_front_true_starts_breathing_and_invites_only_empty_notes() -> void:
	_card.apply_week({"Senin": {"category": "Akademis"}})
	_card.set_front(true)
	assert_true(_card.is_breathing(), "set_front(true) must start breathing")
	for note: StickyNote in _card.get_notes():
		assert_eq(note.is_inviting(), not note.scheduled,
			"%s invites only when empty" % note.name)
	_card.set_front(false)


func test_set_front_false_stops_breathing_and_every_notes_glow() -> void:
	_card.apply_week({})
	_card.set_front(true)
	_card.set_front(false)
	assert_false(_card.is_breathing(), "set_front(false) must stop breathing")
	for note: StickyNote in _card.get_notes():
		assert_false(note.is_inviting(), "%s must stop inviting" % note.name)


## set_idle() is the RosterDeck drag's pause/resume (MURIDMU Task 6): the
## same idle loops as set_front, but a card that springs back never
## re-arrives, so it must not replay the entry.
func test_set_idle_pauses_and_resumes_without_replaying_the_entry() -> void:
	_card.apply_week({"Senin": {"category": "Akademis"}})
	_card.set_idle(true)
	assert_true(_card.is_breathing(), "set_idle(true) resumes the breath")
	for note: StickyNote in _card.get_notes():
		assert_eq(note.is_inviting(), not note.scheduled, "%s invites only when empty" % note.name)
	_card.set_idle(false)
	assert_false(_card.is_breathing(), "set_idle(false) pauses the breath")
	for note: StickyNote in _card.get_notes():
		assert_false(note.is_inviting(), "%s pauses its glow" % note.name)
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	var body := src.get_slice("func set_idle(on: bool) -> void:", 1).get_slice("\n\n", 0)
	assert_false(body.contains("play_entry"), "a spring-back must not replay the entry")


## play_entry() itself is a no-op in the editor (see the test below), so
## this only pins that set_front(true) is wired to call it.
func test_set_front_true_is_wired_to_play_entry() -> void:
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	var body := src.get_slice("func set_front(on: bool) -> void:", 1)
	assert_true(body.contains("play_entry()"), "set_front(true) must play the entry beats")


func test_play_entry_is_a_no_op_in_the_editor() -> void:
	_card.play_entry()
	var nama := _card.get_node("Paper/Nama") as Control
	assert_eq(nama.modulate.a, 1.0, "Nama is untouched in the editor")
	for note: StickyNote in _card.get_notes():
		assert_true(absf(note.rotation_degrees - note.tilt_degrees) < _DEG_EPSILON,
			"%s keeps its tilt in the editor" % note.name)


func test_stop_entry_settles_every_band_at_rest() -> void:
	var nama := _card.get_node("Paper/Nama") as Control
	var rest := nama.position
	nama.modulate.a = 0.0
	nama.position = rest + Vector2(0.0, 30.0)
	var notes: Array[StickyNote] = _card.get_notes()
	for note: StickyNote in notes:
		note.rotation_degrees = 0.0
	var belum := _card.get_node("Paper/Belum") as Control
	belum.scale = Vector2(0.5, 0.5)
	_card.stop_entry()
	assert_eq(nama.modulate.a, 1.0, "Nama is visible at rest")
	assert_eq(nama.position, rest, "Nama is back at its authored position")
	assert_eq(belum.scale, Vector2.ONE, "the stamp is back at unit scale")
	for note: StickyNote in notes:
		assert_true(absf(note.rotation_degrees - note.tilt_degrees) < _DEG_EPSILON,
			"%s settles on its authored tilt" % note.name)


## The pose every beat starts from: Nama lowered by NAME_RISE_PX and
## hidden, the showing stamp hidden, every note upright. stop_entry() must
## put all of it back.
func test_staging_sets_the_entry_pose_and_stop_entry_restores_rest() -> void:
	var nama := _card.get_node("Paper/Nama") as Control
	var rest := nama.position
	var belum := _card.get_node("Paper/Belum") as Control
	_card._stage_for_entry()
	assert_eq(nama.modulate.a, 0.0, "Nama starts hidden")
	assert_eq(nama.position, rest + Vector2(0.0, RosterCard.NAME_RISE_PX),
		"Nama starts NAME_RISE_PX below its rest")
	assert_eq(belum.modulate.a, 0.0, "the showing (Belum) stamp starts hidden")
	for note: StickyNote in _card.get_notes():
		assert_eq(note.rotation_degrees, 0.0, "%s starts upright" % note.name)
	_card.stop_entry()
	assert_eq(nama.modulate.a, 1.0, "Nama is back")
	assert_eq(nama.position, rest, "Nama is back at rest")
	assert_eq(belum.modulate.a, 1.0, "the stamp is back")
	for note: StickyNote in _card.get_notes():
		assert_true(absf(note.rotation_degrees - note.tilt_degrees) < _DEG_EPSILON,
			"%s is back on its tilt" % note.name)


## Before _ready there is no recorded rest, so stop_entry() must not snap
## Nama to the origin.
func test_stop_entry_before_ready_leaves_the_card_alone() -> void:
	var early := (load(_CARD_SCENE) as PackedScene).instantiate() as RosterCard
	track(early)
	var nama := early.get_node("Paper/Nama") as Control
	var authored := nama.position
	early.stop_entry()
	assert_eq(nama.position, authored, "Nama keeps its authored position")
	assert_ne(nama.position, Vector2.ZERO, "and is not snapped to the origin")


## The catatan box shrank for the week header. Every persona x quirk note
## the card can compose must still fit it, measured with the baked theme's
## real font rather than a guessed character count.
func test_every_catatan_fits_its_box() -> void:
	var label := _card.get_node("Paper/CatatanGuru/CatatanLabel") as Label
	var spacing := float(label.get_theme_constant("line_spacing"))
	var line_step := float(label.get_line_height()) + spacing
	var fit := int(floor((label.size.y + spacing) / line_step))
	assert_gt(fit, 1, "the box must hold at least two lines (%s tall)" % label.size.y)
	var personas: Array = RosterCard.CATATAN_PERSONA.keys()
	personas.append("")
	var quirks: Array = RosterCard.CATATAN_QUIRK.keys()
	quirks.append("")
	for persona: String in personas:
		for quirk: String in quirks:
			label.text = RosterCard.compose_catatan(persona, quirk)
			assert_true(label.get_line_count() <= fit,
				"'%s' + '%s' wraps to %d lines; the %dx%d box fits %d"
					% [persona, quirk, label.get_line_count(),
						int(label.size.x), int(label.size.y), fit])


## Timings, angles and scales are named, the overshoot honours
## reduce_motion, the stamp thunk reuses AnimUtils, and every tween dies
## with the card.
func test_the_motion_is_named_guarded_and_cleaned_up() -> void:
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	for const_name: String in ["ENTRY_NAME_AT", "ENTRY_PORTRAIT_AT", "ENTRY_TRAITS_AT",
			"ENTRY_STAMP_AT", "ENTRY_NOTES_AT", "ENTRY_TALLY_AT", "NOTE_OVERSHOOT"]:
		assert_true(src.contains("const %s := " % const_name), const_name + " must be a named const")
	assert_true(src.contains("const BREATH_PERIOD_SECONDS := 3.6"), "a ~3.6 s breath")
	assert_true(src.contains("const BREATH_SCALE_PEAK := 1.012"), "a 1.012 peak scale")
	assert_true(src.contains("AnimUtils.popup_spring_in("), "the stamp thunk reuses AnimUtils")
	var entry := src.get_slice("func play_entry() -> void:", 1).get_slice("\nfunc ", 0)
	assert_true(entry.contains("GameSettings.reduce_motion"),
		"play_entry must skip its overshoots under reduce_motion")
	var breath := src.get_slice("func _start_breathing() -> void:", 1).get_slice("\nfunc ", 0)
	assert_true(breath.contains("GameSettings.reduce_motion"),
		"the breath must not run under reduce_motion")
	var leaving := src.get_slice("func _exit_tree() -> void:", 1).get_slice("\nfunc ", 0)
	assert_true(leaving.contains("_kill_entry()") and leaving.contains("_stop_breathing()"),
		"_exit_tree must kill the entry beats and the breath")


# ------------------------------------------------------------ taps & look

## Every prop added here is decoration: a tap anywhere on it must fall
## through to CardButton, which routes to AturJadwal.
func test_the_new_props_never_swallow_a_card_tap() -> void:
	var paths := [
		"Paper", "Paper/LiftShadow", "Paper/WeekHeader", "Paper/WeekHeader/Band",
		"Paper/WeekHeader/Icon", "Paper/WeekHeader/DayTally", "Paper/PortraitFrame/Clip",
		"Paper/CatatanGuru/Pencil", "Paper/CatatanGuru/MarginRule",
	]
	for p: String in paths:
		var c := _card.get_node_or_null(p) as Control
		assert_true(c != null, "missing " + p)
		if c != null:
			assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, p + " must ignore the mouse")
	for dot: TallyDot in _dots():
		assert_eq(dot.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s must ignore the mouse" % dot.name)


func test_the_card_scene_has_no_theme_overrides_beyond_layout() -> void:
	var src := FileAccess.get_file_as_string(_CARD_SCENE)
	for line: String in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		assert_true(line.begins_with("theme_override_constants/separation"),
			"only layout constant overrides are allowed, found: " + line)


# ---------------------------------------------------------------- TallyDot

func test_tally_dot_swaps_between_its_two_variations() -> void:
	var dot := (load(_DOT_SCENE) as PackedScene).instantiate() as TallyDot
	Engine.get_main_loop().root.add_child(dot)
	track(dot)
	assert_false(dot.filled, "a dot starts empty")
	assert_eq(dot.theme_type_variation, &"TallyDotEmpty", "an empty dot is the ringed kraft pill")
	dot.filled = true
	assert_eq(dot.theme_type_variation, &"TallyDotFilled", "a filled dot is the mint pill")
	dot.filled = false
	assert_eq(dot.theme_type_variation, &"TallyDotEmpty", "and back")
	assert_eq(dot.pop(), null, "pop() plays nothing in the editor")


func test_tally_dot_is_a_documented_filled_export_without_colours() -> void:
	var src := FileAccess.get_file_as_string(_DOT_SCRIPT)
	assert_true(src.contains("@export var filled: bool"), "filled is a typed bool export")
	assert_true(src.contains("func pop() -> Tween:"), "pop() returns its Tween")
	assert_true(src.contains("AnimUtils.coin_pulse("), "pop() is the coin-pulse bounce")
	var re := RegEx.create_from_string("Color\\s*\\(")
	for path: String in [_DOT_SCRIPT, _CARD_SCRIPT]:
		assert_eq(re.search_all(FileAccess.get_file_as_string(path)).size(), 0,
			path + " must read colours from DesignTokens, not Color() literals")


# --------------------------------------------------- reopening on a student
#
# initial_card_index() resolves StudentList's carousel starting position
# (MURIDMU Task 4). It is pure and static, and lives here rather than on
# StudentList.gd only because StudentList is not @tool -- the editor gives
# a non-@tool script a placeholder instance a test cannot call into, while
# RosterCard (this class, @tool, a class_name) already is (see
# compose_catatan() above, called the same way).

func test_initial_card_index_matches_the_selected_students_id() -> void:
	var roster: Array = [{"id": 1}, {"id": 2}, {"id": 3}]
	assert_eq(RosterCard.initial_card_index(roster, {"id": 3}), 2,
		"the third student's id must resolve to index 2")


func test_initial_card_index_defaults_to_zero_when_unset() -> void:
	var roster: Array = [{"id": 1}, {"id": 2}, {"id": 3}]
	assert_eq(RosterCard.initial_card_index(roster, {}), 0,
		"an empty selection defaults to the first card")


func test_initial_card_index_defaults_to_zero_when_unknown() -> void:
	var roster: Array = [{"id": 1}, {"id": 2}, {"id": 3}]
	assert_eq(RosterCard.initial_card_index(roster, {"id": 999}), 0,
		"an id nobody in the roster carries defaults to the first card")
