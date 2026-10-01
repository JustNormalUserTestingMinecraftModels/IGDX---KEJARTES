@tool
class_name SaveGame
extends RefCounted

## The run's one save file (2026-10-01; spec
## docs/superpowers/specs/2026-10-01-save-system-design.md).
##
## user://savegame.cfg is a ConfigFile with three sections: [meta] (version,
## and the grade/week/day the title popup summarises), [state] (one key per
## SAVE_KEYS field, plus run_stats and the screens' first-run tutorial flags,
## EXTRA_KEYS), and [week] (only while SchoolDay is mid-week). The pure
## functions over a ConfigFile carry every rule and are what tests call; the
## disk wrappers no-op under Engine.is_editor_hint() so a test never touches
## user://.
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
## The inventory-only save this file replaced. Every new game reads it; the
## first save() that carries its items deletes it.
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

## The [state] keys beyond SAVE_KEYS. Both hold dictionaries.
const EXTRA_KEYS := ["run_stats", "tutorial_flags"]

## The first-run tutorial flags, by the script that owns them as static vars.
## A static var resets on every launch, so the save carries them: without
## that, a resumed run replayed AturJadwal's and StudentList's walkthroughs
## after every relaunch. reset_tutorial_flags() clears them for a new run
## (GameState.reset_run) and a beaten game (RunResult). StudentList's flag once
## pointed at Lobby.gd, which has none, and a silent guard hid it.
##
## Deliberately an untyped Dictionary of plain Arrays. It was once typed
## `Dictionary[String, PackedStringArray]` over Array literals, and iterating it
## handed back empty flag names and then hard-crashed Godot 4.6.2 (signal 11)
## the moment a beaten game pressed Selesai.
const TUTORIAL_FLAGS := {
	"res://Scripts/AturJadwal/AturJadwal.gd": ["tutorial_phase1_done", "tutorial_phase3_done"],
	"res://Scripts/StudentList/StudentList.gd": ["tutorial_shown"],
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
	cfg.set_value("state", "tutorial_flags", tutorial_flags())
	for k in week:
		cfg.set_value("week", k, week[k])


## True for a file this build can read: it has a version, the version is not
## newer than VERSION, and every value fits its field (values_fit()).
static func is_usable(cfg: ConfigFile) -> bool:
	if not cfg.has_section_key("meta", "version"):
		return false
	var v: Variant = cfg.get_value("meta", "version")
	return typeof(v) == TYPE_INT and v >= 1 and v <= VERSION and values_fit(cfg)


## True when each [state] value has its GameState field's type (int and float
## interchangeable; a typed array's elements, its element type) and each
## EXTRA_KEYS value is a dictionary. Checked before anything is applied: a
## hand-edited `shop_stock=5` used to raise mid-read, leaving the run
## half-applied and the save deleted rather than quarantined.
static func values_fit(cfg: ConfigFile) -> bool:
	for key in SAVE_KEYS:
		if cfg.has_section_key("state", key) \
				and not _fits(cfg.get_value("state", key), GameState.get(key)):
			return false
	for key in EXTRA_KEYS:
		if cfg.has_section_key("state", key) and not cfg.get_value("state", key) is Dictionary:
			return false
	return true


## True when `value` can stand in for `current`, a GameState field's value.
static func _fits(value: Variant, current: Variant) -> bool:
	if current is int or current is float:
		return value is int or value is float
	if typeof(value) != typeof(current):
		return false
	if current is Array and (current as Array).is_typed():
		for item in value:
			if typeof(item) != (current as Array).get_typed_builtin():
				return false
	return true


## Applies `cfg` to GameState and the tutorial flags. Returns false, changing
## nothing, for an unusable file. Emits GameState.inventory_changed.
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
			typed.assign((value as Array).duplicate(true))
			GameState.set(key, typed)
		elif current is Dictionary:
			GameState.set(key, (value as Dictionary).duplicate(true))
		else:
			GameState.set(key, type_convert(value, typeof(current)))
	GameState.run_stats.from_dict(cfg.get_value("state", "run_stats", {}))
	restore_tutorial_flags(cfg.get_value("state", "tutorial_flags", {}))
	GameState.inventory_changed.emit()
	return true


## Every TUTORIAL_FLAGS static as it stands, path -> {flag: bool}: what
## write_state stores.
static func tutorial_flags() -> Dictionary:
	var out := {}
	for path in TUTORIAL_FLAGS:
		var script := load(path) as GDScript
		var flags := {}
		for flag in TUTORIAL_FLAGS[path]:
			flags[flag] = script != null and script.get(flag) == true
		out[path] = flags
	return out


## Sets every TUTORIAL_FLAGS static to its value in `saved` (tutorial_flags()'s
## shape); a flag `saved` lacks, or holds as a non-bool, goes back to false.
static func restore_tutorial_flags(saved: Dictionary) -> void:
	for path in TUTORIAL_FLAGS:
		var flags: Variant = saved.get(path, {})
		for flag in TUTORIAL_FLAGS[path]:
			var value: Variant = (flags as Dictionary).get(flag, false) if flags is Dictionary else false
			set_tutorial_flag(path, flag, value is bool and value)


## Puts every TUTORIAL_FLAGS static back to false, so the first-run tutorials
## play again.
static func reset_tutorial_flags() -> void:
	restore_tutorial_flags({})


## Sets the static bool `flag` on the script at `path`. The screens that own
## the flags have no class_name, so they are reached by path; a script or flag
## that is not there is an error, never a silent skip.
static func set_tutorial_flag(path: String, flag: String, on: bool) -> void:
	var script := load(path) as GDScript
	if script == null or not flag in script:
		push_error("SaveGame: no static %s on %s" % [flag, path])
		return
	script.set(flag, on)


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


## True when a usable save is on disk, including one a failed rename left in
## TMP_PATH. An unusable one is quarantined to BAD_PATH. Always false in the
## editor.
static func has_save() -> bool:
	if Engine.is_editor_hint():
		return false
	return _load_usable() != null


## Writes the run to TMP_PATH, then renames it over SAVE_PATH. Where the
## platform's rename overwrites (Android, Linux, macOS) that is atomic: a kill
## leaves the old save or the new one whole, never neither. Only when the
## rename refuses (a platform that will not overwrite) is the old file removed
## first and the rename retried once; a kill in that gap, or a second failed
## rename, leaves just the temp file, which _load_usable() recovers.
## Writes nothing when no roster is approved: there is nothing to continue
## (and Forget Session's hop to the menu must not re-save the wiped state).
## Once the run is in place, the legacy inventory file goes: its items were
## merged into this run when it began (merge_legacy_inventory), and deleting
## it any earlier lost them to a quit before the first save.
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
		return
	delete_legacy_inventory()


## Deletes the pre-2026-10-01 inventory-only save: once a run carrying its
## items is on disk (save()), or when every bit of progress is wiped
## (GameState.forget_session(), so a new game cannot merge it back). No-op in
## the editor.
static func delete_legacy_inventory() -> void:
	if Engine.is_editor_hint():
		return
	if FileAccess.file_exists(LEGACY_INVENTORY_PATH):
		DirAccess.remove_absolute(LEGACY_INVENTORY_PATH)


## Loads the save into GameState, and its week (if any) into
## GameState.pending_week_resume. False, changing nothing, when there is no
## usable save; _load_usable() has then quarantined an unusable one (a
## wrong-typed value included) to BAD_PATH. No-op in the editor.
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


## Reads the pre-2026-10-01 inventory-only save and returns its items (name
## -> count); empty when there is none. Read-only: save() deletes the file
## once a run carrying the items is on disk. No-op in the editor.
static func read_legacy_inventory() -> Dictionary:
	if Engine.is_editor_hint():
		return {}
	if not FileAccess.file_exists(LEGACY_INVENTORY_PATH):
		return {}
	var items := {}
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_INVENTORY_PATH) == OK:
		var raw: Variant = cfg.get_value("inventory", "items", {})
		if raw is Dictionary:
			for k in raw:
				if raw[k] is int or raw[k] is float:
					items[str(k)] = int(raw[k])
	return items


## Adds the legacy inventory to the new game's. Called by every new game the
## title screen starts, always after GameState.reset_run() has emptied the
## inventory, so a second new game (the first quit before its first save,
## which keeps the file) gets the items once, not twice.
static func merge_legacy_inventory() -> void:
	var legacy := read_legacy_inventory()
	if legacy.is_empty():
		return
	for item in legacy:
		GameState.inventory[item] = int(GameState.inventory.get(item, 0)) + int(legacy[item])
	GameState.inventory_changed.emit()


## The save on disk if it is usable; otherwise null, and an unusable file is
## moved to BAD_PATH so the next save starts clean. With no SAVE_PATH, a run
## a failed rename left in TMP_PATH is recovered instead.
static func _load_usable() -> ConfigFile:
	if not FileAccess.file_exists(SAVE_PATH):
		return _recover_temp()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and is_usable(cfg):
		return cfg
	if FileAccess.file_exists(BAD_PATH):
		DirAccess.remove_absolute(BAD_PATH)
	var err := DirAccess.rename_absolute(SAVE_PATH, BAD_PATH)
	if err == OK:
		push_warning("SaveGame: %s cannot be read by this build; moved to %s"
			% [SAVE_PATH, BAD_PATH])
	else:
		push_warning("SaveGame: %s cannot be read by this build, and could not be moved (error %d)"
			% [SAVE_PATH, err])
	return null


## save() leaves the run in TMP_PATH alone only when both its renames failed,
## or a kill fell between them; has_save() used to miss it, and the next new
## game deleted it. A usable temp file is moved into place and returned (read
## where it is if the move fails again); anything else there is a write cut
## short, and is removed. Null when there is nothing to recover.
static func _recover_temp() -> ConfigFile:
	if not FileAccess.file_exists(TMP_PATH):
		return null
	var cfg := ConfigFile.new()
	if cfg.load(TMP_PATH) != OK or not is_usable(cfg):
		DirAccess.remove_absolute(TMP_PATH)
		return null
	DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	return cfg
