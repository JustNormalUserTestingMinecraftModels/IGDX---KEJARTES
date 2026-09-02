@tool
class_name StatBar
extends ProgressBar

## An animated, category-tinted stat bar. Replaces the ad-hoc
## ProgressBar + ValueLabel pairs currently duplicated across
## AturJadwal, SemesterEnd, and StudentCard.

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
## SemesterEnd and ReportCard show settled numbers, not live edits.
@export var pop_on_change: bool = false

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
	# Any other family (StatPill on StudentCard): its track is either
	# painted into the scene art or an empty stylebox, so theme_type_variation
	# just selects the family here -- it never encodes a category the way the
	# StatBar branch above does.
	if is_inside_tree():
		theme_type_variation = variation
	# StatPill (StudentCard): background is a StyleBoxEmpty, so tinting the
	# whole node only colours the fill -- self_modulate is correct there.
	# Keep that path exactly as it was.
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	self_modulate = tokens.category_color(category)


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
