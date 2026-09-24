@tool
class_name StatBar
extends ProgressBar

## An animated, category-tinted stat bar. Replaces the ad-hoc
## ProgressBar + ValueLabel pairs currently duplicated across
## AturJadwal, StatCheck, and StudentCard.

## One of: Akademis, Olahraga, SeniBudaya, Istirahat, Libur.
## Anything else falls back to text_secondary — never invisible.
@export var category: String = "Akademis":
	set(value):
		category = value
		_apply_tint()

## Which theme variation family this bar wears. The student card's
## redesigned pills use "StatPill", whose track is painted into the card
## art; every other screen keeps the shared "StatBar" family (which further
## resolves to a per-category sibling in _apply_tint()). StudentCardView
## flips this at runtime, after the bar has already gone through _ready()
## with the default family -- so the setter re-derives BOTH
## theme_type_variation and self_modulate together via _apply_tint(),
## instead of poking theme_type_variation alone. Without that, a runtime
## switch to StatPill left self_modulate stuck at the white the StatBar
## family had already force-set, and StatPill's fill (no baked colour,
## StyleBoxEmpty background) depends entirely on self_modulate to show its
## category colour -- the pill rendered white.
@export var variation: StringName = &"StatBar":
	set(value):
		variation = value
		if is_inside_tree():
			_apply_tint()

## When true, overlays a centered "value_format % value" Label on top of
## the fill -- most callers leave this off and show the number in a
## separate InfoLabel/StudentStatRow instead.
## Set this at scene-authoring time; it is not meant to be toggled at
## runtime. Flipping it true shows the label, but flipping it back false
## does NOT hide a label already shown -- _sync_label() bails out early
## whenever this is false, on purpose, so this @tool script never touches
## (and can't stomp) a ValueLabel that ReportCard/StudentCard authored by
## hand. Do not "fix" that early return; see _sync_label()'s doc.
@export var show_value_label: bool = false:
	set(value):
		show_value_label = value
		_sync_label()

## printf format for the value label. Use "%d%%" for a percentage.
@export var value_format: String = "%d"

## When true, an animated set_stat() also gives the bar a short squash-pop
## so a change is visible even when the fill barely moves. Off by default:
## StatCheck and ReportCard show settled numbers, not live edits.
@export var pop_on_change: bool = false

## When true, the ValueLabel rides the end of the fill as a pill instead of
## sitting where it was authored, and a child named "Gloss", if the scene
## authors one, is stretched along the top of the fill. Both follow every
## value change, so they track Juice.fill_bar's sweep frame by frame.
## AturJadwal's embossed bars (2026-09-24 visual polish, D5/D6). Never moves
## anything inside the editor, where a scene save would bake the result.
@export var value_rides_fill: bool = false

## How far the Gloss line is inset from each end of the fill, in pixels, so
## it stops short of the fill's rounded caps.
@export_range(0.0, 40.0, 1.0) var gloss_inset: float = 14.0

var _label: Label
## True when _label was found already authored in the scene (adopted)
## rather than created by this script. Adopted labels keep their authored
## styling -- see _sync_label().
var _label_adopted: bool = false


func _ready() -> void:
	# theme_type_variation is set inside _apply_tint() below, for both
	# families -- setting it here too would just be overwritten immediately
	# and risks the two disagreeing if the logic ever diverges.
	show_percentage = false
	min_value = 0.0
	max_value = 100.0
	_apply_tint()
	_sync_label()
	if not value_changed.is_connected(_on_value_moved):
		value_changed.connect(_on_value_moved)
	if not resized.is_connected(_on_resized_for_followers):
		resized.connect(_on_resized_for_followers)
	_on_value_moved(value)


func _on_value_moved(_v: float) -> void:
	if Engine.is_editor_hint() or not value_rides_fill:
		return
	layout_fill_followers()


func _on_resized_for_followers() -> void:
	_on_value_moved(value)


## Where the fill currently ends, in this bar's local x. Mirrors how
## ProgressBar draws a begin-to-end fill: the fill stylebox's own minimum
## width, plus the ratio of what is left of the bar, rounded; nothing at all
## at zero.
func fill_end_x() -> float:
	var fg := get_theme_stylebox("fill")
	var fg_min := fg.get_minimum_size().x if fg != null else 0.0
	var ratio := clampf(get_as_ratio(), 0.0, 1.0)
	var p := roundf(ratio * (size.x - fg_min))
	return p + fg_min if p > 0.0 else 0.0


## Puts the value pill on the end of the fill and stretches the Gloss line
## along it. Public and ungated so a suite can drive it inside the editor;
## the signal path above is what keeps it out of an editor session.
func layout_fill_followers() -> void:
	var end := fill_end_x()
	if _label != null:
		var pill := _label.get_combined_minimum_size()
		_label.size = pill
		_label.position = Vector2(
			clampf(end - pill.x / 2.0, 0.0, maxf(0.0, size.x - pill.x)),
			(size.y - pill.y) / 2.0)
	var gloss := get_node_or_null("Gloss") as Control
	if gloss != null:
		var width := end - gloss_inset * 2.0
		gloss.visible = width > 0.0
		gloss.position.x = gloss_inset
		gloss.size.x = maxf(0.0, width)


## Category -> the per-category "StatBar" theme variation baked in
## ThemeFactory._build_progress. Includes DesignTokens.category_color()'s
## own aliases ("Akademik", "Seni Budaya") so a caller using either spelling
## on a StatBar-family bar resolves to the real colour instead of silently
## falling back to the neutral "StatBar" look. An unlisted category still
## falls back to plain "StatBar" (white fill, no self_modulate tint) rather
## than going invisible.
const _STAT_BAR_VARIATIONS := {
	"Akademis": &"StatBarAkademis",
	"Akademik": &"StatBarAkademis",
	"SeniBudaya": &"StatBarSeniBudaya",
	"Seni Budaya": &"StatBarSeniBudaya",
	"Olahraga": &"StatBarOlahraga",
	"Istirahat": &"StatBarIstirahat",
	"Libur": &"StatBarLibur",
	"Wirausaha": &"StatBarWirausaha",
	# Needs, not schedule categories. Added 2026-09-09 -- the student card's
	# two Kepribadian bars used to be authored as "Istirahat" and "Libur"
	# and so wore the rest and holiday accents outright.
	"Mood": &"StatBarMood",
	"Energy": &"StatBarEnergy",
	"Energi": &"StatBarEnergy",
}

## The same mapping for the student card's pill family. Kept as its own
## table rather than derived by string-swapping "StatBar" for "StatPill":
## an unrecognised category has to fall back to a variation that actually
## exists in the theme, and a derived name would silently produce one that
## does not.
const _STAT_PILL_VARIATIONS := {
	"Akademis": &"StatPillAkademis",
	"Akademik": &"StatPillAkademis",
	"SeniBudaya": &"StatPillSeniBudaya",
	"Seni Budaya": &"StatPillSeniBudaya",
	"Olahraga": &"StatPillOlahraga",
	"Istirahat": &"StatPillIstirahat",
	"Libur": &"StatPillLibur",
	"Wirausaha": &"StatPillWirausaha",
	"Mood": &"StatPillMood",
	"Energy": &"StatPillEnergy",
	"Energi": &"StatPillEnergy",
}

## The light-track family, used where a bar sits on a cream surface rather
## than the dark chrome the rest of the game's bars assume. Only the three
## schedule skills appear: Wirausaha and Libur have no target and so no
## bar. Added 2026-09-10 for AturJadwal's preview rows.
const _STAT_BAR_LIGHT_VARIATIONS := {
	"Akademis": &"StatBarAkademisLight",
	"Akademik": &"StatBarAkademisLight",
	"SeniBudaya": &"StatBarSeniBudayaLight",
	"Seni Budaya": &"StatBarSeniBudayaLight",
	"Olahraga": &"StatBarOlahragaLight",
}

## The embossed family AturJadwal's five bars wear (2026-09-24 visual
## polish, D5): an inset-shaded track under a StatBarFrame panel. Only the
## five categories that screen shows; mood and energy wear Istirahat and
## Libur there, as they always have.
const _STAT_BAR_INSET_VARIATIONS := {
	"Akademis": &"StatBarInsetAkademis",
	"Akademik": &"StatBarInsetAkademis",
	"SeniBudaya": &"StatBarInsetSeniBudaya",
	"Seni Budaya": &"StatBarInsetSeniBudaya",
	"Olahraga": &"StatBarInsetOlahraga",
	"Istirahat": &"StatBarInsetIstirahat",
	"Libur": &"StatBarInsetLibur",
}


func _apply_tint() -> void:
	if variation == &"StatBar":
		# self_modulate tints the WHOLE node -- on the "StatBar" family that
		# also multiplies the track's surface_sunken ground and white rim,
		# so a value-0 bar rendered as a solid category-coloured capsule
		# instead of an empty track. The category colour is baked into the
		# fill stylebox instead (see ThemeFactory._build_progress), so the
		# node itself must stay untinted here.
		self_modulate = Color.WHITE
		var target: StringName = _STAT_BAR_VARIATIONS.get(category, &"StatBar")
		if is_inside_tree():
			theme_type_variation = target
		return
	# StatPill (StudentCard) now works exactly like the StatBar family
	# above: the category picks a sibling variation whose FILL stylebox
	# has the colour baked in, and the node itself stays untinted.
	#
	# It used to set self_modulate to the on-dark accent instead, which was
	# safe only while StatPill's background was a StyleBoxEmpty and the
	# track was painted into card_bg.png. When the painted chips were
	# deleted and StatPill grew a real track, self_modulate -- which
	# multiplies everything the node draws, not just the fill -- started
	# tinting that track too, so each pill's "empty" half took on its own
	# category's hue.
	# The light-track family, for bars on a cream surface (AturJadwal's
	# preview rows). Same shape as the two branches above: the category
	# picks a sibling whose fill has the deep cat_* colour baked in, and
	# the node stays untinted.
	if variation == &"StatBarLight":
		var light: StringName = _STAT_BAR_LIGHT_VARIATIONS.get(category, &"StatBar")
		if is_inside_tree():
			theme_type_variation = light
		return

	if variation == &"StatBarInset":
		self_modulate = Color.WHITE
		var inset: StringName = _STAT_BAR_INSET_VARIATIONS.get(category, &"StatBar")
		if is_inside_tree():
			theme_type_variation = inset
		return

	self_modulate = Color.WHITE
	if variation == &"StatPill":
		var pill: StringName = _STAT_PILL_VARIATIONS.get(category, &"StatPill")
		if is_inside_tree():
			theme_type_variation = pill
		return

	# Any other family: theme_type_variation just selects it verbatim -- it
	# never encodes a category the way the two branches above do.
	if is_inside_tree():
		theme_type_variation = variation


## Only ever touches a ValueLabel when show_value_label is true. This
## script is @tool, so _ready() (and therefore this function) runs at EDIT
## time too, not just in-game. ReportCard and StudentCard leave
## show_value_label at its default false while authoring their own
## ValueLabel children with meaningful text/alignment that those screens
## drive themselves -- opening and saving one of those scenes used to run
## this function, adopt the authored label, and overwrite its visible/
## text/alignment, silently persisting the stomp into the .tscn. Bailing
## out before even looking the child up when show_value_label is false is
## what protects that authored data.
func _sync_label() -> void:
	if not is_inside_tree():
		return
	if not show_value_label:
		return
	if _label == null:
		# The scene may already author a ValueLabel (every AturJadwal bar
		# does). Adopt it -- building a second one leaves the authored
		# label frozen at its design-time text underneath the live one.
		_label = get_node_or_null("ValueLabel") as Label
		if _label != null:
			_label_adopted = true
	if _label == null:
		_label = Label.new()
		_label.name = "ValueLabel"
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_label)
	_label.visible = true
	if not _label_adopted:
		# A label WE created has no authored styling to protect -- give it
		# the full set of defaults. An adopted label keeps whatever the
		# scene author set for these three; AturJadwal's authored
		# ValueLabels already carry theme_type_variation = &"BarLabel" and
		# centered alignment directly in the .tscn, so this is a no-op for
		# them, not a behaviour change.
		_label.theme_type_variation = &"BarLabel"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = value_format % int(round(value))


## Set the bar's value, optionally animating the fill and the label
## count-up together. Input is clamped: decay math upstream can overshoot.
## `pop` lets a caller suppress the squash-pop for this call even when
## pop_on_change is on -- on a student switch the caller drives all five
## bars through AturJadwal._stagger_stat_rows() instead, and popping here
## too would start a second, independently-tracked tween on the same
## `scale` property and the two would jitter against each other. The
## stagger owns the motion on a switch; the pop owns it on an edit.
func set_stat(new_value: float, animate: bool = true, pop: bool = true) -> void:
	var target := clampf(new_value, min_value, max_value)
	if animate:
		var previous := value
		Juice.fill_bar(self, target)
		if _label != null:
			Juice.count_up(_label, previous, target, value_format)
		if pop_on_change and pop and not is_equal_approx(previous, target):
			# AnimUtils.squash_bounce, not Juice.pop_in: pop_in sets
			# modulate.a to 0 and tweens it back, which would blink the bar
			# and its value label transparent on every change -- a flash,
			# not a pop. squash_bounce is scale-only.
			AnimUtils.squash_bounce(self)
	else:
		value = target
		if _label != null:
			_label.text = value_format % int(round(target))
