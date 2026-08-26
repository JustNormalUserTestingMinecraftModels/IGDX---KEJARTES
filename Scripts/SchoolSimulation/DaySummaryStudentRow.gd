extends PanelContainer
class_name DaySummaryStudentRow

## One student's line in the end-of-day summary: avatar, name, an optional
## status badge, and one tinted pill per stat that moved today.
##
## All styling now comes from the theme -- the row itself is a &"Card",
## the avatar frame a &"SunkenPanel", the name a &"TitleLabel", and every
## chip is the shared DaySummaryPill/Badge scene tinted from DesignTokens.
## Nothing here builds a StyleBox any more.

@onready var avatar_rect: TextureRect = %AvatarTexture
@onready var name_label: Label = %NameLabel
@onready var badge_container: HBoxContainer = %BadgeContainer
@onready var pills_container: HFlowContainer = %PillsContainer

@export_group("Typography")
@export var font: Font = null

const _STAT_NAMES := {
	"akademis": "Akademis",
	"seni_budaya": "Seni",
	"olahraga": "Olahraga",
	"energy": "Energy",
	"mood": "Mood",
}


func setup_row(student_name: String, changes: Array, student: StudentData) -> void:
	name_label.text = student_name
	if font:
		name_label.add_theme_font_override("font", font)
	if student and student.avatar_texture:
		avatar_rect.texture = student.avatar_texture

	var tokens := Juice.tokens()

	# Setup badges
	for child in badge_container.get_children():
		child.queue_free()

	var event_delta_sum = 0
	for ch in changes:
		if ch.get("source") == "event":
			event_delta_sum += int(ch.get("delta"))

	if student and student.energy <= 20.0:
		_add_name_row_badge("⚠️ KELELAHAN", tokens.state_danger)
	elif event_delta_sum > 0:
		_add_name_row_badge("✨ BONUS EVENT +%d" % event_delta_sum, tokens.currency_gold)

	# Setup pills
	for child in pills_container.get_children():
		child.queue_free()

	var chips: Array = []
	for ch in changes:
		var sk = ch.get("stat_key", "")
		var delta = ch.get("delta", 0.0)
		var source = ch.get("source", "")
		if delta == 0.0:
			continue

		var sign_str = "+" if delta > 0 else ""
		var suffix = ""
		if delta < 0:
			suffix = " ↓"
		elif delta > 0 and (sk == "energy" or sk == "mood"):
			suffix = " ↑"

		var name_str = _STAT_NAMES.get(sk, sk)
		# Build a printf template rather than a finished string, so the
		# number itself can be rolled up by Juice.count_up. "%%d" survives
		# this first substitution as a literal "%d" for the count-up.
		var pill_fmt := "%s%%d %s%s" % [sign_str, name_str, suffix]
		chips.append(_add_pill(pill_fmt, float(delta),
			_get_summary_pill_color(sk, delta, source)))

	# The chips arrive one after another, then their numbers roll up.
	Juice.stagger_in(chips)


func _add_name_row_badge(text: String, tint: Color) -> PanelContainer:
	var chip := _make_chip(
		"res://Scenes/SchoolSimulation/DaySummaryBadge.tscn", tint)
	(chip.get_node("Text") as Label).text = text
	badge_container.add_child(chip)
	return chip


## Adds one stat pill whose number counts up from zero to `delta`, so a
## +6 reads as motion rather than as a static label.
func _add_pill(fmt: String, delta: float, tint: Color) -> PanelContainer:
	var chip := _make_chip(
		"res://Scenes/SchoolSimulation/DaySummaryPill.tscn", tint)
	pills_container.add_child(chip)
	Juice.count_up(chip.get_node("Text") as Label, 0.0, delta, fmt)
	return chip


## Badge and pill chips are theme-driven: the scene supplies the
## SunkenPanel geometry and the BarLabel text style, and the only per-chip
## variable left is the tint. `self_modulate` is used rather than
## `modulate` deliberately -- it tints the panel's own stylebox without
## bleeding into the child Label, which is the same trick StatBar uses to
## category-tint a shared white fill.
func _make_chip(scene_path: String, tint: Color) -> PanelContainer:
	var chip := load(scene_path).instantiate() as PanelContainer
	chip.self_modulate = tint
	if font:
		(chip.get_node("Text") as Label).add_theme_font_override("font", font)
	return chip


func _get_summary_pill_color(stat_key: String, delta: float, source: String) -> Color:
	var tokens := Juice.tokens()
	if source == "minigame_win":
		return tokens.currency_gold
	if source == "event":
		return tokens.cat_istirahat
	if delta > 0:
		match stat_key:
			"akademis": return tokens.cat_akademis
			"seni_budaya": return tokens.cat_senibudaya
			"olahraga": return tokens.cat_olahraga
			"energy", "mood": return tokens.state_success
	else:
		match stat_key:
			"energy": return tokens.state_danger
			"mood": return tokens.state_warning
	return tokens.text_secondary
