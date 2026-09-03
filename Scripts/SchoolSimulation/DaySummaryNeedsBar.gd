@tool
extends ProgressBar
class_name DaySummaryNeedsBar

## The Daily Results card's energy or mood bar, now carrying an icon and
## an Indonesian tier word ("Lelah", "Senang") INSIDE itself. See the
## 2026-09-03 spec, section 3.2.
##
## Deliberately not a separate chip node: the card already has one bar per
## need, and a second bar-shaped element stacked beside it would read as a
## redundant duplicate. The bar keeps its fill -- that fill IS the precise
## reading the word summarises -- and its DaySummaryEnergyBar /
## DaySummaryMoodBar variation.
##
## The pre-existing DeltaLabel child is untouched: it is right-aligned and
## carries the week's signed number, while Word is left-aligned beside the
## icon, so the two never collide.

## Tier words per need, low to high, matched to TIER_CUTS. Indonesian,
## like every other game-facing string.
const TIER_WORDS := {
	"energy": ["Lelah", "Cukup", "Bugar"],
	"mood": ["Sedih", "Biasa", "Senang"],
}

## Upper bounds (inclusive) of the first two tiers, on the 0-100 scale.
## Anything above the second cut takes the top word.
const TIER_CUTS := [33.0, 66.0]

## Which icon each need wears. Reuses StudentCard's own energy/mood
## icons rather than the placeholder SVGs, so this card and StudentCard
## read as the same need with the same glyph.
const ICON_FOR := {
	"energy": "res://Assets/Images/StudentCard/stat_energy.png",
	"mood": "res://Assets/Images/StudentCard/stat_mood.png",
}

@onready var icon: TextureRect = $Icon
@onready var word_label: Label = $Word


## The tier word for a need at a value. An unrecognised need returns ""
## rather than guessing -- a fabricated mood on the card would read as
## real data.
static func word_for(need_key: String, value: float) -> String:
	if not TIER_WORDS.has(need_key):
		return ""
	var words: Array = TIER_WORDS[need_key]
	for i in TIER_CUTS.size():
		if value <= float(TIER_CUTS[i]):
			return String(words[i])
	return String(words[words.size() - 1])


## Set the bar's value and dress its icon and word from one call. The
## card's two needs bars are written through this and nothing else, so the
## fill and the word can never disagree.
func set_need(need_key: String, need_value: float) -> void:
	value = need_value
	if ICON_FOR.has(need_key):
		icon.texture = load(ICON_FOR[need_key])
	word_label.text = word_for(need_key, need_value)
