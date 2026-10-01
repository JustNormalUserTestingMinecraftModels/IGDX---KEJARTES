@tool
class_name SaveGame
extends RefCounted

## The run's one save file (2026-10-01; spec
## docs/superpowers/specs/2026-10-01-save-system-design.md).
##
## user://savegame.cfg is a ConfigFile with three sections: [meta] (version,
## and the grade/week/day the title popup summarises), [state] (one key per
## SAVE_KEYS field plus run_stats), and [week] (only while SchoolDay is
## mid-week). The pure functions over a ConfigFile carry every rule and are
## what tests call; the disk wrappers no-op under Engine.is_editor_hint() so
## a test never touches user://.
##
## Saved at: hub-screen visits (checkpoint(), from Transition), pause/quit on
## a hub screen (save_if_at_hub(), from GameState), each SchoolDay day's
## result, and RunResult's exit to StudentCard. Deleted on RunResult's exit
## to MainMenu and by Permainan baru / Forget Session.

## Bumped when the file's shape changes; a newer file is refused, not read.
const VERSION := 1
const SAVE_PATH := "user://savegame.cfg"
## Written first, then renamed over SAVE_PATH, so a kill mid-write leaves
## the previous save whole.
const TMP_PATH := "user://savegame.tmp"
## Where an unreadable save is moved, for debugging, so the game starts fresh.
const BAD_PATH := "user://savegame.bad.cfg"
## The inventory-only save this file replaced. Read once, then deleted.
const LEGACY_INVENTORY_PATH := "user://inventory.cfg"

const LOBBY_SCENE := "res://Scenes/Lobby/Lobby.tscn"
const SCHOOL_DAY_SCENE := "res://Scenes/SchoolSimulation/SchoolDay.tscn"
const STUDENT_CARD_SCENE := "res://Scenes/StudentCard/StudentCard.tscn"

## Screens between weeks, where GameState holds nothing half-done. Entering
## or leaving one saves; pausing on one saves.
const HUB_SCENES := [
	LOBBY_SCENE,
	"res://Scenes/AturJadwal/AturJadwal.tscn",
	"res://Scenes/Koperasi/ShopHub.tscn",
	"res://Scenes/Koperasi/Koperasi.tscn",
	"res://Scenes/Koperasi/CosmeticShop.tscn",
	"res://Scenes/Inventory/Inventory.tscn",
	"res://Scenes/ReportCard/ReportCard.tscn",
]

## The GameState fields a save carries. current_grade is read back first.
## test_save_game pins that every GameState field is here or in EXCLUDED.
const SAVE_KEYS := [
	"current_grade", "minggu_ke",
	"approved_students", "returned_from_student_card",
	"day_schedules", "minigame_gain_this_week",
	"shop_week_key", "shop_stock", "shop_sold", "shop_promo_item", "shop_promo_percent",
	"lobby_tutorial_completed", "tutorials_bypassed",
	"seen_minigame_how_to", "headmaster_beats_seen",
	"grade7_student_ids", "grade8_student_ids",
	"equipped_skins", "skin_unlock_overrides",
	"player_money", "inventory", "pending_earnings", "ad_debt",
	"daily_login_day", "last_claim_date",
]

## GameState fields deliberately left out, and why.
const EXCLUDED := {
	"next_scene": "navigation scratch, rewritten before every use",
	"selected_student": "screen-local selection",
	"selected_day": "screen-local selection",
	"run_failed": "StatCheck decides it fresh; never meaningful at a checkpoint",
	"max_minggu": "derived from current_grade by its setter",
	"is_game_beaten": "persisted by GameSettings in settings.cfg",
	"debug_level_select_enabled": "persisted by GameSettings in settings.cfg",
	"pending_week_resume": "the transient hand-off this file fills on load",
}

## The grade a file that records none means: where every run starts.
const DEFAULT_GRADE := 7

## SchoolDay.DAYS, for the summary line.
const DAY_NAMES := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
## A week whose five days have all run; only the weekly report is left.
const WEEK_DONE_LABEL := "Akhir Pekan"


## Writes the whole run into `cfg`, replacing what was there. `week` is
## SchoolDay's week-in-progress snapshot, or empty between weeks.
static func write_state(cfg: ConfigFile, week: Dictionary = {}) -> void:
	cfg.clear()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "grade", GameState.current_grade)
	cfg.set_value("meta", "week", GameState.minggu_ke)
	cfg.set_value("meta", "max_week", GameState.max_minggu)
	cfg.set_value("meta", "day", int(week.get("resume_day", -1)))
	for key in SAVE_KEYS:
		var value: Variant = GameState.get(key)
		cfg.set_value("state", key,
			value.duplicate(true) if (value is Array or value is Dictionary) else value)
	cfg.set_value("state", "run_stats", GameState.run_stats.to_dict())
	for k in week:
		cfg.set_value("week", k, week[k])


## True for a file this build can read: it has a version, and the version is
## not newer than VERSION.
static func is_usable(cfg: ConfigFile) -> bool:
	if not cfg.has_section_key("meta", "version"):
		return false
	var v: Variant = cfg.get_value("meta", "version")
	return typeof(v) == TYPE_INT and v >= 1 and v <= VERSION


## Applies `cfg` to GameState. Returns false, changing nothing, for an
## unusable file. Emits GameState.inventory_changed.
static func read_state(cfg: ConfigFile) -> bool:
	if not is_usable(cfg):
		return false
	GameState.current_grade = int(cfg.get_value("state", "current_grade", DEFAULT_GRADE))
	for key in SAVE_KEYS:
		if key == "current_grade" or not cfg.has_section_key("state", key):
			continue
		var value: Variant = cfg.get_value("state", key)
		var current: Variant = GameState.get(key)
		if current is Array:
			var typed: Array = current.duplicate()
			typed.assign(value)
			GameState.set(key, typed)
		elif current is Dictionary:
			GameState.set(key, (value as Dictionary).duplicate(true))
		else:
			GameState.set(key, value)
	GameState.run_stats.from_dict(cfg.get_value("state", "run_stats", {}))
	GameState.inventory_changed.emit()
	return true


## The [week] section as a dictionary, or empty between weeks.
static func week_from(cfg: ConfigFile) -> Dictionary:
	var week := {}
	if cfg.has_section("week"):
		for k in cfg.get_section_keys("week"):
			week[k] = cfg.get_value("week", k)
	return week


## Where Continue lands: back into the week if one is in progress, else the
## Lobby once a roster is approved, else StudentCard to pick one.
static func resume_scene(week: Dictionary, roster_approved: bool) -> String:
	if not week.is_empty():
		return SCHOOL_DAY_SCENE
	if roster_approved:
		return LOBBY_SCENE
	return STUDENT_CARD_SCENE


## "Kelas 8 · Minggu 3/6", plus " · Kamis" (the day a week resumes on) or
## " · Akhir Pekan" while a week is in progress. Set in the body face, which
## carries "·".
static func summary_for(cfg: ConfigFile) -> String:
	var text := "Kelas %d · Minggu %d/%d" % [
		int(cfg.get_value("meta", "grade", DEFAULT_GRADE)),
		int(cfg.get_value("meta", "week", 1)),
		int(cfg.get_value("meta", "max_week", 1))]
	var day := int(cfg.get_value("meta", "day", -1))
	if day >= DAY_NAMES.size():
		text += " · " + WEEK_DONE_LABEL
	elif day >= 0:
		text += " · " + DAY_NAMES[day]
	return text


## True when a usable save is on disk. An unusable one is quarantined to
## BAD_PATH. Always false in the editor.
static func has_save() -> bool:
	if Engine.is_editor_hint():
		return false
	return _load_usable() != null


## Writes the run to TMP_PATH, then renames it over SAVE_PATH. Where the
## platform's rename overwrites (Android, Linux, macOS) that is atomic: a kill
## leaves the old save or the new one whole, never neither. Only when the
## rename refuses (a platform that will not overwrite) is the old file removed
## first and the rename retried once; a kill in that gap leaves just the temp
## file.
## Writes nothing when no roster is approved: there is nothing to continue
## (and Forget Session's hop to the menu must not re-save the wiped state).
## No-op in the editor.
static func save(week: Dictionary = {}) -> void:
	if Engine.is_editor_hint():
		return
	if GameState.approved_students.is_empty():
		return
	var cfg := ConfigFile.new()
	write_state(cfg, week)
	var err := cfg.save(TMP_PATH)
	if err != OK:
		push_warning("SaveGame: could not write %s (error %d)" % [TMP_PATH, err])
		return
	err = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		DirAccess.remove_absolute(SAVE_PATH)
		err = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_warning("SaveGame: could not move the save into place (error %d)" % err)


## Loads the save into GameState, and its week (if any) into
## GameState.pending_week_resume. False, changing nothing, when there is no
## usable save. No-op in the editor.
static func load_save() -> bool:
	if Engine.is_editor_hint():
		return false
	var cfg := _load_usable()
	if cfg == null or not read_state(cfg):
		return false
	GameState.pending_week_resume = week_from(cfg)
	return true


## The title popup's summary of the save on disk, or "" when there is none.
static func summary() -> String:
	if Engine.is_editor_hint():
		return ""
	var cfg := _load_usable()
	return summary_for(cfg) if cfg != null else ""


## Removes the save (and any half-written temp). No-op in the editor.
static func delete_save() -> void:
	if Engine.is_editor_hint():
		return
	for path in [SAVE_PATH, TMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Transition's hook: saves when the scene being left or entered is a hub.
static func checkpoint(from_path: String, to_path: String) -> void:
	if HUB_SCENES.has(from_path) or HUB_SCENES.has(to_path):
		save()


## GameState's pause/quit hook: saves only when a hub screen is current.
static func save_if_at_hub(current_path: String) -> void:
	if HUB_SCENES.has(current_path):
		save()


## Reads the pre-2026-10-01 inventory-only save, deletes it, and returns its
## items (name -> count). Empty when there is none. No-op in the editor.
static func take_legacy_inventory() -> Dictionary:
	if Engine.is_editor_hint():
		return {}
	if not FileAccess.file_exists(LEGACY_INVENTORY_PATH):
		return {}
	var items := {}
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_INVENTORY_PATH) == OK:
		var raw: Dictionary = cfg.get_value("inventory", "items", {})
		for k in raw:
			items[String(k)] = int(raw[k])
	DirAccess.remove_absolute(LEGACY_INVENTORY_PATH)
	return items


## Adds the legacy inventory, once, to the new game's. Called by every new
## game the title screen starts.
static func merge_legacy_inventory() -> void:
	var legacy := take_legacy_inventory()
	if legacy.is_empty():
		return
	for item in legacy:
		GameState.inventory[item] = int(GameState.inventory.get(item, 0)) + int(legacy[item])
	GameState.inventory_changed.emit()


## The save on disk if it is usable; otherwise null, and an unreadable file
## is moved to BAD_PATH so the next save starts clean.
static func _load_usable() -> ConfigFile:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and is_usable(cfg):
		return cfg
	push_warning("SaveGame: %s is unreadable or from a newer build; moved to %s"
		% [SAVE_PATH, BAD_PATH])
	if FileAccess.file_exists(BAD_PATH):
		DirAccess.remove_absolute(BAD_PATH)
	DirAccess.rename_absolute(SAVE_PATH, BAD_PATH)
	return null
