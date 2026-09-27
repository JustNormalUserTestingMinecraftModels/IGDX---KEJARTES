@tool
class_name StatInfo
extends RefCounted

## The one table describing the five bars a student card shows.
##
## Read by Scenes/UI/StatDetailPopup.tscn to fill its header, its bar tint and
## its description, and by ReportCard.gd / StudentCard.gd to colour the bars
## on the card itself. Before this existed both screens carried their own copy
## of the same if/elif chain.
##
## Affects: presentation only. Nothing here writes GameState.
##
## Why `data_key` exists: a bar node is named in PascalCase (`SeniBudaya`),
## its GameState dictionary key in snake_case (`seni_budaya`). Never index a
## student dictionary with a bar name.

## bar name -> everything the UI needs to render that bar.
##
## `token_category` is a DesignTokens category key, not a schedule category.
## Mood and Energy are needs rather than skills, so they borrow the two
## accents no skill uses -- Istirahat (violet) for Mood, Libur (amber) for
## Energy -- which keeps all five bars mutually distinguishable while every
## colour still comes from one token set.
const BARS: Dictionary = {
	"Mood": {
		"display_name": "Mood",
		"category_label": "NEEDS",
		"glyph": "😊",
		"token_category": "Istirahat",
		"data_key": "mood",
		"description": "Mood mempengaruhi tingkat kemauan murid belajar. Jika mood rendah, murid akan stress dan performanya menurun!",
	},
	"Energy": {
		"display_name": "Energy",
		"category_label": "NEEDS",
		"glyph": "⚡",
		"token_category": "Libur",
		"data_key": "energy",
		"description": "Energy digunakan untuk melakukan aktivitas. Pastikan energy cukup sebelum memberikan tugas berat!",
	},
	"Akademis": {
		"display_name": "Akademis",
		"category_label": "STATS",
		"glyph": "📚",
		"token_category": "Akademis",
		"data_key": "akademis",
		"description": "Menunjukkan tingkat kemampuan murid dalam memahami pelajaran akademis dan teoritis.",
	},
	"SeniBudaya": {
		"display_name": "Seni Budaya",
		"category_label": "STATS",
		"glyph": "🎨",
		"token_category": "SeniBudaya",
		"data_key": "seni_budaya",
		"description": "Menunjukkan tingkat kemampuan murid dalam menciptakan dan memahami karya kesenian.",
	},
	"Olahraga": {
		"display_name": "Olahraga",
		"category_label": "STATS",
		"glyph": "⚽",
		"token_category": "Olahraga",
		"data_key": "olahraga",
		"description": "Menunjukkan tingkat kemampuan fisik dan kebugaran tubuh murid dalam bidang olahraga.",
	},
}


## Everything known about one bar, or {} when the name is not one of the five.
## Callers pass a node name straight through, so an unknown name must degrade
## rather than crash the screen.
static func get_bar(bar_name: String) -> Dictionary:
	return BARS.get(bar_name, {})


## The DesignTokens category key for a bar, or "" when unknown.
## Affects: the bar's tint via DesignTokens.category_color().
static func token_category(bar_name: String) -> String:
	var entry: Dictionary = BARS.get(bar_name, {})
	return entry.get("token_category", "")


## Read this bar's current value out of a GameState student dictionary.
## Affects: nothing -- read-only. Returns 0.0 for an unknown bar or a student
## dictionary missing the key.
static func value_of(bar_name: String, s_data: Dictionary) -> float:
	var entry: Dictionary = BARS.get(bar_name, {})
	if entry.is_empty():
		return 0.0
	return float(s_data.get(entry["data_key"], 0.0))
