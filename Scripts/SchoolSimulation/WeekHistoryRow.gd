@tool
extends PanelContainer
class_name WeekHistoryRow

## One line of the week's RIWAYAT: a minigame that was played or an event
## that fired (2026-09-03 spec section 5).
##
## Replaces ResultCheckup._create_history_item(), which built the same
## row node-by-node at runtime -- debt that
## tests/test_viewport_editability.gd ratchets against.
##
## Three lines, because the old one-line row threw information away: the
## breadcrumb (day and category), the title (name and outcome badge), and
## the detail line naming WHO it happened to and WHAT it did. That third
## line is recorded by StudentManager today and shown nowhere.
##
## @tool so the editor's test runner can instantiate and inspect it.

## The history category marking an entry as an event rather than a played
## minigame. Mirrors WeekRecap.EVENT_CATEGORY.
const EVENT_CATEGORY := "Event"

## Separator between the participants and the details on the third line.
const DETAIL_JOIN := "  ·  "

@onready var icon: TextureRect = $Body/Icon
@onready var breadcrumb: Label = $Body/Lines/Breadcrumb
@onready var name_label: Label = $Body/Lines/TitleRow/NameLabel
@onready var badge: PanelContainer = $Body/Lines/TitleRow/Badge
@onready var detail_label: Label = $Body/Lines/DetailLabel

# ── Visual - Icons ───────────────────────────────────────────────────
@export_group("Visual - Icons")
## Leading icon for a minigame that was won.
@export var icon_won: Texture2D = null
## Leading icon for a minigame that was lost.
@export var icon_lost: Texture2D = null
## Leading icon for a random event.
@export var icon_event: Texture2D = null


## Render one StudentManager history entry. Tolerant of a partial entry:
## anything missing simply does not render, rather than printing a
## confident blank.
func set_entry(entry: Dictionary) -> void:
	var t := Juice.tokens()
	var category: String = entry.get("category", "")
	var is_event: bool = category == EVENT_CATEGORY
	var won: bool = entry.get("won", false)

	breadcrumb.text = "%s · %s" % [entry.get("day", ""), category]
	name_label.text = entry.get("game_name", "")

	if icon:
		icon.texture = icon_event if is_event else (
			icon_won if won else icon_lost)

	var badge_text := " EVENT "
	var badge_tint := t.brand_primary
	if not is_event:
		badge_text = " BERHASIL " if won else " GAGAL "
		badge_tint = t.state_success if won else t.state_danger
	badge.self_modulate = badge_tint
	(badge.get_node("Text") as Label).text = badge_text

	var detail := _build_detail(entry)
	detail_label.text = detail
	# Hidden rather than blanked: an empty label still claims its line
	# height and leaves the row looking broken.
	detail_label.visible = detail != ""


## "Budi, Doni  ·  3/5" or "Ani, Cici  ·  Semua siswa kehilangan 5
## energi" -- whichever parts this entry actually carries.
func _build_detail(entry: Dictionary) -> String:
	var parts: Array[String] = []

	var who := _participants(entry)
	if who != "":
		parts.append(who)

	var details: String = entry.get("details", "")
	if details != "":
		parts.append(details)

	if entry.has("max_score") and int(entry.get("max_score", 0)) > 0:
		parts.append("%d/%d" % [int(entry.get("score", 0)),
			int(entry.get("max_score", 0))])

	return DETAIL_JOIN.join(parts)


## The names this entry touched. Events record them directly as
## affected_students; minigames carry a results array of per-student
## dictionaries instead.
func _participants(entry: Dictionary) -> String:
	var names: Array[String] = []
	for who in entry.get("affected_students", []):
		names.append(str(who))
	if names.is_empty():
		for res in entry.get("results", []):
			if res is Dictionary and res.has("student_name"):
				names.append(str(res["student_name"]))
	return ", ".join(names)
