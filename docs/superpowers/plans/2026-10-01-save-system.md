# Save system and "Lanjutkan" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The run autosaves at every hub-screen visit and after every day's result. Tapping the title with a save present asks "Mau melanjutkan permainan sebelumnya?", and the player can resume exactly where they left off or wipe the run and start over.

**Architecture:** A new static `SaveGame` script owns one versioned `ConfigFile` (`user://savegame.cfg`). Pure `write_state`/`read_state` functions copy an explicit `SAVE_KEYS` list of `GameState` fields, plus a `[week]` section while SchoolDay is mid-week. A completeness test pins `SAVE_KEYS`, as it already pins `EndGameRehearsal.SNAPSHOT_KEYS`. `Transition.change_scene` saves around hub screens, and SchoolDay saves after each day summary. A `ContinuePopup` instanced in `MainMenu.tscn` resumes to SchoolDay, the Lobby or StudentCard. The old inventory-only save is retired, and its legacy file's items carry into the next new game once.

**Tech Stack:** Godot 4.6, GDScript, `ConfigFile`, the Godot AI MCP bridge (`test_run`, `script_patch`, `scene_manage`, `scene_open`, `batch_execute`, `node_*`, `scene_save`, `project_run`, `game_manage`, `editor_screenshot`, `logs_read`).

**Spec:** `docs/superpowers/specs/2026-10-01-save-system-design.md`

## Global Constraints

- Tests run **only** inside the editor through MCP `test_run(suite=...)`. Suites are `@tool`, and **no test may `await`**. Scripts the runner instantiates are `@tool`, with runtime side effects gated behind `Engine.is_editor_hint()`.
- **Nothing in a test may touch `user://`.** Every disk function in `SaveGame` returns early under `Engine.is_editor_hint()`. Tests exercise the pure `ConfigFile` functions only.
- Edit `.gd` files through `script_patch`. A file written from outside the editor needs a no-op `script_patch` before `test_run`. A new `class_name` (`SaveGame`, `ContinuePopup`) needs `filesystem_manage(op="scan")`, and `project_manage(op="stop")` before the next `project_run`.
- **Never hand-edit a `.tscn` while the editor is attached.** Create and edit scenes with the MCP scene and node tools.
- **Scene work before script work, inside each task.** After patching any `.gd`, restart the editor before the next `scene_save`. After every `scene_save`, run `git diff HEAD -- '*.gd'` and revert any script you did not mean to change.
- `Balance.gd` is not ours: do not touch it.
- No `theme_override_*` beyond layout constants (`separation`, `margin_*`), and no visual built at runtime. Every script has a `##` header and a `##` line on every `@export`.
- Player-facing text is Indonesian and exactly: `Mau melanjutkan permainan sebelumnya?`, `Ya, lanjutkan`, `Permainan baru`, `Yakin? Progres lama akan hilang.`, `Ya, mulai baru`, `Batal`, plus the summary line `Kelas N · Minggu W/M[ · Hari]`.
- Mint (`PrimaryButton`) is the main action. No emoji.
- Commits: Conventional Commits with a scope, each ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Work in a worktree on `feat/save-system` off `Textures` (`superpowers:using-git-worktrees`). The spec and this plan are **untracked** in the main checkout. Copy both in and commit them with Task 1.
- **Ordering with the per-student lose-rule plan** (`docs/superpowers/plans/2026-10-01-per-student-lose-rule.md`): the two plans are independent. If that branch has merged first, `git merge Textures` before starting. Neither adds a GameState field the other must save.
- **RunStats may change under you.** `docs/superpowers/plans/2026-09-29-run-result-four-stats-and-selesai-crash.md` edits RunStats' fields. `RunStats.to_dict()` below is generic over its property list for exactly that reason. Do not hard-code field names.
- After any full `test_run`, check `git status`, and `git checkout --` `Assets/Theme/kejartes_theme.tres` and `Assets/Audio/default_bus_layout.tres` if they changed.
- Finish with the `ship-pr` skill.

## File map

| File | Responsibility |
|---|---|
| `Scripts/Save/SaveGame.gd` (new) | The file: keys, pure write/read, summary, resume routing, disk wrappers, checkpoints, legacy inventory |
| `Scripts/EndGame/RunStats.gd` | `to_dict()` / `from_dict()` |
| `Scripts/GameState.gd` | `pending_week_resume`; `reset_run()`; `forget_session()` = `reset_run()` + save delete + achievements; the old inventory save removed; `_notification` → `SaveGame.save_if_at_hub` |
| `Scripts/Transition/Transition.gd` | `SaveGame.checkpoint(from, to)` in place of `save_inventory()` |
| `Scripts/SchoolSimulation/StudentManager.gd` | `to_save_dict()` / `restore_from_save()` |
| `Scripts/SchoolSimulation/SchoolDay.gd` | Daily save after the summary; `resume_simulation()`; `_ready()` picks resume |
| `Scripts/EndGame/RunResult.gd` | Save on a StudentCard exit, delete on a MainMenu exit |
| `Scenes/MainMenu/ContinuePopup.tscn` + `Scripts/MainMenu/ContinuePopup.gd` (new) | The two-page dialog |
| `Scenes/MainMenu/MainMenu.tscn`, `Scripts/MainMenu/MainMenu.gd` | Instance the popup; route the tap |
| `tests/test_save_game.gd` (new) | Core tests |
| `tests/test_inventory_persistence.gd`, `test_bugfix_nav.gd`, `test_dapatkan_uang.gd`, `test_student_card.gd`, `test_end_game_rehearsal.gd`, `test_popup_frames.gd`, `test_stat_check`-style suites below | Retargeted pins |
| `CLAUDE.md`, `docs/superpowers/CHANGELOG.md` | Persistence rule rewritten |

---

### Task 1: SaveGame core and RunStats round trip

**Files:**
- Create: `Scripts/Save/SaveGame.gd`
- Modify: `Scripts/EndGame/RunStats.gd` (header line "NOT because it is ever saved"; add two methods)
- Modify: `Scripts/GameState.gd` (add `pending_week_resume` next to `run_failed`)
- Modify: `tests/test_end_game_rehearsal.gd` (`_DELIBERATELY_UNSNAPSHOTTED` gains `pending_week_resume`)
- Create: `tests/test_save_game.gd`

**Interfaces:**
- Produces (all `static` on `class_name SaveGame`):
  - consts `VERSION: int = 1`, `SAVE_PATH`, `TMP_PATH`, `BAD_PATH`, `LEGACY_INVENTORY_PATH`, `LOBBY_SCENE`, `SCHOOL_DAY_SCENE`, `STUDENT_CARD_SCENE`, `HUB_SCENES: Array`, `SAVE_KEYS: Array`, `EXCLUDED: Dictionary`, `DAY_NAMES: Array`
  - `write_state(cfg: ConfigFile, week: Dictionary = {}) -> void`
  - `is_usable(cfg: ConfigFile) -> bool`
  - `read_state(cfg: ConfigFile) -> bool`
  - `week_from(cfg: ConfigFile) -> Dictionary`
  - `resume_scene(week: Dictionary, roster_approved: bool) -> String`
  - `summary_for(cfg: ConfigFile) -> String`
  - `has_save() -> bool`, `save(week: Dictionary = {}) -> void`, `load_save() -> bool`, `summary() -> String`, `delete_save() -> void`
  - `checkpoint(from_path: String, to_path: String) -> void`, `save_if_at_hub(current_path: String) -> void`
  - `take_legacy_inventory() -> Dictionary`, `merge_legacy_inventory() -> void`
- Produces: `RunStats.to_dict() -> Dictionary`, `RunStats.from_dict(d: Dictionary) -> void`, `GameState.pending_week_resume: Dictionary`

- [ ] **Step 0: Branch.** Create the worktree and branch `feat/save-system` off `Textures`, and copy the spec and plan in. Open the worktree's project in the editor, with `Scenes/MainMenu/MainMenu.tscn` open.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_save_game.gd`:

```gdscript
@tool
extends McpTestSuite

## SaveGame (2026-10-01 save system): the pure ConfigFile half -- what is
## written, what comes back, how a resume is routed and summarised. Nothing
## here touches user://: the disk wrappers no-op in the editor and are only
## source-scanned.
##
## Must be @tool; no coroutine tests (the runner does not await).

const _SCRIPT := "res://Scripts/Save/SaveGame.gd"

var _snap: Dictionary


func suite_name() -> String:
	return "save_game"


func setup() -> void:
	_snap = EndGameRehearsal.snapshot()


func teardown() -> void:
	EndGameRehearsal.restore(_snap)


## A run worth saving: every awkward shape the file must carry.
func _seed_run() -> void:
	GameState.current_grade = 8
	GameState.minggu_ke = 3
	GameState.approved_students = [
		{"id": 1, "name": "Marcel", "akademis": 61.5, "target_akademis": 72.0},
		{"id": 4, "name": "Citra", "akademis": 40.0, "target_akademis": 72.0},
	]
	GameState.returned_from_student_card = true
	GameState.day_schedules = {1: {"Senin": {"category": "Akademis", "mood_cost": 3, "energy_cost": 5}}}
	GameState.shop_stock.assign(["Buku Tulis", "Jus Jeruk"])
	GameState.shop_sold.assign(["Jus Jeruk"])
	GameState.inventory = {"Buku Tulis": 2}
	GameState.player_money = 12345
	GameState.pending_earnings = {4: 300}
	GameState.headmaster_beats_seen = {8: true}
	GameState.run_stats.reset()
	GameState.run_stats.record_minigame(true, 6.0)
	GameState.run_stats.record_event_student(4)


func test_every_saved_field_round_trips() -> void:
	_seed_run()
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg)
	var expected := {}
	for key in SaveGame.SAVE_KEYS:
		expected[key] = GameState.get(key)
	var won := GameState.run_stats.minigames_won

	GameState.reset_run()
	assert_true(SaveGame.read_state(cfg), "a fresh file reads")
	for key in SaveGame.SAVE_KEYS:
		assert_eq(var_to_str(GameState.get(key)), var_to_str(expected[key]), key + " round-trips")
	assert_eq(GameState.max_minggu, GameState.weeks_for_grade(8),
		"current_grade is restored through its setter, so max_minggu follows")
	assert_eq(GameState.run_stats.minigames_won, won, "run_stats round-trips")
	assert_true(GameState.day_schedules.has(1), "int roster ids stay int keys")
	assert_eq(GameState.shop_stock.get_typed_builtin(), TYPE_STRING, "typed arrays stay typed")


func test_every_game_state_field_is_saved_or_deliberately_excluded() -> void:
	var missing: Array[String] = []
	for prop in GameState.get_script().get_script_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = prop.name
		if name.begins_with("_") or name == "run_stats":
			continue
		if SaveGame.SAVE_KEYS.has(name) or SaveGame.EXCLUDED.has(name):
			continue
		missing.append(name)
	assert_eq(missing.size(), 0,
		"GameState fields neither saved nor excluded: " + ", ".join(missing))
	for key in SaveGame.SAVE_KEYS:
		assert_false(SaveGame.EXCLUDED.has(key), key + " is both saved and excluded")


func test_run_stats_round_trips_through_a_dictionary() -> void:
	var a := RunStats.new()
	a.record_minigame(true, 4.0)
	a.record_minigame(false, -2.0)
	a.record_event_student(3)
	var b := RunStats.new()
	b.from_dict(a.to_dict())
	assert_eq(var_to_str(b.to_dict()), var_to_str(a.to_dict()), "every tally survives")
	b.from_dict({"no_such_tally": 9})
	assert_eq(b.minigames_won, 0, "from_dict resets first and ignores unknown keys")


func test_the_week_section_round_trips_and_a_plain_save_drops_it() -> void:
	_seed_run()
	var week := {"resume_day": 3, "minigames_played": 1, "events_triggered": 0,
		"max_events": 2, "max_minigames": 3,
		"manager": {"students": [{"id": 1, "akademis": 64.0}], "minigame_history": [],
			"daily_stat_log": {"Senin": []}}}
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg, week)
	assert_eq(var_to_str(SaveGame.week_from(cfg)), var_to_str(week), "the week comes back whole")
	SaveGame.write_state(cfg)
	assert_true(SaveGame.week_from(cfg).is_empty(), "a save without a week clears the old one")


func test_resume_routes_by_week_then_roster() -> void:
	assert_eq(SaveGame.resume_scene({"resume_day": 2}, true), SaveGame.SCHOOL_DAY_SCENE)
	assert_eq(SaveGame.resume_scene({}, true), SaveGame.LOBBY_SCENE)
	assert_eq(SaveGame.resume_scene({}, false), SaveGame.STUDENT_CARD_SCENE)


func test_the_summary_names_grade_week_and_day() -> void:
	_seed_run()
	var cfg := ConfigFile.new()
	SaveGame.write_state(cfg)
	assert_eq(SaveGame.summary_for(cfg), "Kelas 8 · Minggu 3/%d" % GameState.weeks_for_grade(8))
	SaveGame.write_state(cfg, {"resume_day": 3})
	assert_true(SaveGame.summary_for(cfg).ends_with(" · Kamis"), "day 3 resumes on Kamis")
	SaveGame.write_state(cfg, {"resume_day": 5})
	assert_true(SaveGame.summary_for(cfg).ends_with(" · Akhir Pekan"),
		"after Jumat only the weekly report is left")


func test_an_unusable_file_is_refused_without_touching_state() -> void:
	_seed_run()
	var newer := ConfigFile.new()
	newer.set_value("meta", "version", SaveGame.VERSION + 1)
	newer.set_value("state", "player_money", 1)
	assert_false(SaveGame.is_usable(newer), "a newer version is refused")
	assert_false(SaveGame.read_state(newer))
	assert_eq(GameState.player_money, 12345, "and nothing was applied")
	assert_false(SaveGame.is_usable(ConfigFile.new()), "a file with no version is refused")


func test_disk_functions_are_editor_gated_and_atomic() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for fn in ["has_save", "save", "load_save", "summary", "delete_save", "take_legacy_inventory"]:
		var body: String = src.get_slice("static func %s(" % fn, 1).get_slice("\nstatic func ", 0)
		assert_true(body.contains("Engine.is_editor_hint()"), fn + " must no-op in the editor")
	var save_body: String = src.get_slice("static func save(", 1).get_slice("\nstatic func ", 0)
	assert_true(save_body.contains("TMP_PATH") and save_body.contains("rename_absolute"),
		"save writes a temp file and renames it over the real one")
	assert_true(save_body.contains("approved_students.is_empty()"),
		"a run with no roster has nothing to continue and writes nothing")


func test_checkpoints_fire_only_around_hub_screens() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var body: String = src.get_slice("static func checkpoint(", 1).get_slice("\nstatic func ", 0)
	assert_true(body.contains("HUB_SCENES.has(from_path)") and body.contains("HUB_SCENES.has(to_path)"))
	assert_true(SaveGame.HUB_SCENES.has(SaveGame.LOBBY_SCENE))
	assert_true(SaveGame.HUB_SCENES.has("res://Scenes/AturJadwal/AturJadwal.tscn"),
		"leaving AturJadwal for SchoolDay saves the planned week")
	assert_false(SaveGame.HUB_SCENES.has(SaveGame.SCHOOL_DAY_SCENE),
		"SchoolDay saves itself, after each day's result, never mid-day")
	for path in SaveGame.HUB_SCENES:
		assert_true(ResourceLoader.exists(path), path + " exists")
```

In `tests/test_end_game_rehearsal.gd`, add this entry to `_DELIBERATELY_UNSNAPSHOTTED`:

```gdscript
	"pending_week_resume": "transient hand-off from SaveGame.load_save() to SchoolDay._ready(); empty outside that one frame",
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `test_run(suite="save_game")`
Expected: FAIL. The suite reports broken because `SaveGame` and `GameState.reset_run` don't exist yet.

- [ ] **Step 3: Implement**

`Scripts/GameState.gd`: directly after `var run_failed: bool = false` (line 111), add:

```gdscript

## A saved week in progress, handed from SaveGame.load_save() to
## SchoolDay._ready(), which resumes it and empties this. Never saved itself.
var pending_week_resume: Dictionary = {}
```

Add a `reset_run()` that takes over `forget_session()`'s body. Rewrite `forget_session()` (lines 486-521) as:

```gdscript
## Return every run field to its declared default: what "Permainan baru"
## wipes. Leaves achievements, settings and the persisted progress flags
## (is_game_beaten, debug_level_select_enabled -- GameSettings writes them)
## alone, and touches no file.
func reset_run() -> void:
	next_scene = "res://Scenes/MainMenu/MainMenu.tscn"
	returned_from_student_card = false
	approved_students = []
	selected_student = {}
	selected_day = ""
	day_schedules = {}
	minigame_gain_this_week = {}
	reset_shop_week()
	minggu_ke = 1
	lobby_tutorial_completed = false
	tutorials_bypassed = false
	seen_minigame_how_to = {}
	headmaster_beats_seen = {}
	current_grade = 7
	max_minggu = get_max_weeks()
	grade7_student_ids = []
	grade8_student_ids = []
	run_failed = false
	pending_week_resume = {}
	equipped_skins = {}
	skin_unlock_overrides = {}
	player_money = 0
	pending_earnings = {}
	ad_debt = 0
	inventory.clear()
	daily_login_day = 1
	last_claim_date = ""
	run_stats.reset()
	inventory_changed.emit()


## Debug: reset_run(), delete the save file, and wipe achievement progress.
func forget_session() -> void:
	reset_run()
	SaveGame.delete_save()
	Achievements.reset()
```

Leave `save_inventory`/`load_inventory` in place for now; Task 2 removes them.

`Scripts/EndGame/RunStats.gd`: change the header line "Session-scoped, like everything else on GameState: this is a Resource for the typed fields and the Inspector, NOT because it is ever saved." to "Saved with the run through to_dict()/from_dict() (SaveGame); a Resource for the typed fields and the Inspector, never written with ResourceSaver." Then add before `reset()`:

```gdscript
## Every tally as {name: value}, for SaveGame. Walks the property list, so a
## tally added or removed later is saved without touching this.
func to_dict() -> Dictionary:
	var d := {}
	for prop in get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value = get(prop.name)
		d[prop.name] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return d


## Inverse of to_dict(): resets, then copies back every key this build still
## has. Unknown keys (a tally since removed) are ignored; typed arrays come
## back through assign() so they keep their type.
func from_dict(d: Dictionary) -> void:
	reset()
	for prop in get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not d.has(prop.name):
			continue
		var current = get(prop.name)
		if current is Array:
			var typed: Array = current.duplicate()
			typed.assign(d[prop.name])
			set(prop.name, typed)
		else:
			set(prop.name, d[prop.name])
```

Create `Scripts/Save/SaveGame.gd`:

```gdscript
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
		var value = GameState.get(key)
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
	var v = cfg.get_value("meta", "version")
	return typeof(v) == TYPE_INT and v >= 1 and v <= VERSION


## Applies `cfg` to GameState. Returns false, changing nothing, for an
## unusable file. Emits GameState.inventory_changed.
static func read_state(cfg: ConfigFile) -> bool:
	if not is_usable(cfg):
		return false
	GameState.current_grade = int(cfg.get_value("state", "current_grade", 7))
	for key in SAVE_KEYS:
		if key == "current_grade" or not cfg.has_section_key("state", key):
			continue
		var value = cfg.get_value("state", key)
		var current = GameState.get(key)
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
		int(cfg.get_value("meta", "grade", 7)),
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


## Writes the run to disk, atomically. Writes nothing when no roster is
## approved: there is nothing to continue (and Forget Session's hop to the
## menu must not re-save the wiped state). No-op in the editor.
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
	if FileAccess.file_exists(SAVE_PATH):
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
```

Then run `filesystem_manage(op="scan")`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `test_run(suite="save_game")`, `test_run(suite="end_game_rehearsal")`, `test_run(suite="inventory_persistence")`, `test_run(suite="script_documentation")`
Expected:
- `save_game`, `end_game_rehearsal` and `script_documentation` PASS.
- `inventory_persistence`: `test_forget_session_resets_run_state_but_keeps_progress_flags` FAILS. It scans `forget_session`'s body for the fields and for `clear_inventory_save()`. Retarget it now:
  - scan `func reset_run` for the field list and the two "must NOT wipe" checks
  - scan `func forget_session` for `reset_run()`, `SaveGame.delete_save()` and `Achievements.reset()`

  Re-run until it passes.

If the round trip fails on a specific key, the message names it. Fix the read path, not the test. A `Variant` mismatch is usually a typed array that needs `assign()`.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-10-01-save-system-design.md docs/superpowers/plans/2026-10-01-save-system.md Scripts/Save/SaveGame.gd Scripts/Save/SaveGame.gd.uid Scripts/EndGame/RunStats.gd Scripts/GameState.gd tests/test_save_game.gd tests/test_end_game_rehearsal.gd tests/test_inventory_persistence.gd
git commit -m "feat(save): versioned run save file with a pinned key list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Hub checkpoints replace the inventory-only save

**Files:**
- Modify: `Scripts/Transition/Transition.gd:200-201`
- Modify: `Scripts/GameState.gd` (remove `INVENTORY_SAVE_PATH`, `_write_inventory_to`, `_read_inventory_from`, `save_inventory`, `load_inventory`, `clear_inventory_save`; `_ready`; `_notification`; the comments that call fields "session-scoped / never saved")
- Modify: `Scripts/EndGame/RunResult.gd:268` (after `_apply_progression()`)
- Test: `tests/test_inventory_persistence.gd`, `tests/test_bugfix_nav.gd:170-175`, `tests/test_dapatkan_uang.gd:65-74`, `tests/test_student_card.gd:607-617`, `tests/test_save_game.gd`

**Interfaces:**
- Consumes: `SaveGame.checkpoint`, `SaveGame.save_if_at_hub`, `SaveGame.save`, `SaveGame.delete_save` (Task 1)

- [ ] **Step 1: Write the failing tests**

Replace `tests/test_inventory_persistence.gd`'s `test_write_then_read_round_trips`, `test_read_from_empty_config_leaves_inventory_empty`, `test_read_coerces_types`, `test_save_inventory_is_gated_in_editor_context` and `test_transition_flushes_inventory_on_scene_change` with:

```gdscript
## 2026-10-01: the inventory travels in SaveGame's file with the rest of the
## run; the old inventory-only save is gone.
func test_the_inventory_only_save_is_retired() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	for gone in ["func save_inventory", "func load_inventory", "func clear_inventory_save",
			"func _write_inventory_to", "func _read_inventory_from", "INVENTORY_SAVE_PATH"]:
		assert_false(src.contains(gone), gone + " was removed")
	assert_true(SaveGame.SAVE_KEYS.has("inventory"), "the inventory is part of the run save")


func test_transition_checkpoints_around_hub_screens() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Transition/Transition.gd")
	assert_true(src.contains("SaveGame.checkpoint("), "change_scene saves around hubs")
	assert_false(src.contains("save_inventory"), "the old flush is gone")
```

In `tests/test_bugfix_nav.gd`, change `test_inventory_is_flushed_on_close_and_background()` so the third assertion is
`assert_contains(body, "SaveGame.save_if_at_hub(", "through the run save, on a hub screen only")`. Keep the `ConfigFile` assertion with the message "the file format lives in SaveGame".

In `tests/test_dapatkan_uang.gd` `test_ad_debt_is_a_session_counter()`, replace the last two lines (the `_write_inventory_to` slice) with:
```gdscript
	assert_true(SaveGame.SAVE_KEYS.has("ad_debt"),
		"ad_debt is saved with player_money: a resumed run still owes its ads")
```
Rename the test to `test_ad_debt_is_a_run_counter_saved_with_the_money`. Its `forget_session` slice becomes `reset_run`.

In `tests/test_student_card.gd`, replace `test_seen_beats_are_never_written_to_disk()` with:
```gdscript
## Since 2026-10-01 the run is saved, beats included: a resumed run must not
## replay a promotion's congratulation.
func test_seen_beats_travel_with_the_run_save() -> void:
	assert_true(SaveGame.SAVE_KEYS.has("headmaster_beats_seen"))
	for path: String in ["res://Scripts/GameSettings.gd", "res://Scripts/Achievements/Achievements.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("headmaster_beats_seen"),
			path + " is not where the run lives")
```

Append to `tests/test_save_game.gd`:
```gdscript
func test_run_result_saves_a_continuing_run_and_deletes_an_ended_one() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	var body: String = src.get_slice("var destination := _apply_progression()", 1) \
		.get_slice("var tween", 0)
	assert_true(body.contains("SaveGame.save()"), "a run going on to StudentCard is saved")
	assert_true(body.contains("SaveGame.delete_save()"), "a run ending at the menu is deleted")
	assert_true(body.contains("ROSTER_SCENE"), "and the branch is on the destination")


func test_boot_no_longer_loads_anything() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	assert_false(ready.contains("load"), "the save loads only when the player picks Lanjutkan")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `test_run(suite="inventory_persistence")`, `test_run(suite="save_game")`
Expected: FAIL. The old functions are still present, and Transition and RunResult don't call SaveGame yet.

- [ ] **Step 3: Implement**

`Scripts/Transition/Transition.gd`: replace
```gdscript
	if not Engine.is_editor_hint():
		GameState.save_inventory()
```
with
```gdscript
	# The run's hub checkpoint (SaveGame): leaving or entering a hub screen
	# saves. SaveGame's disk calls no-op in the editor themselves.
	var current := get_tree().current_scene
	SaveGame.checkpoint(current.scene_file_path if current else "", path)
```

`Scripts/GameState.gd`:
- Delete `INVENTORY_SAVE_PATH`, `_write_inventory_to`, `_read_inventory_from`, `save_inventory`, `load_inventory` and `clear_inventory_save` with their doc comments (lines 328-371).
- `_ready()` keeps only `print("GameState siap")`.
- Replace `_notification` and its doc comment with:
```gdscript
## Saves when the window closes or the app goes to the background on a hub
## screen, where no scene change is coming to checkpoint it: a phone may kill
## a backgrounded app without warning. Mid-week and in the end-of-grade
## chain the last checkpoint stands (SaveGame.save_if_at_hub).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		var current := get_tree().current_scene if is_inside_tree() else null
		SaveGame.save_if_at_hub(current.scene_file_path if current else "")
```
- Update the stale "session-scoped / no save / CLAUDE.md: no new persistence" phrases. `grep -n "ession-scoped\|no new persistence\|never saved\|not saved\|no save" Scripts/GameState.gd` lists them. On fields now in `SaveGame.SAVE_KEYS`, reword to "Saved with the run (SaveGame)."

`Scripts/EndGame/RunResult.gd`, directly after `var destination := _apply_progression()`:
```gdscript
	# The save follows the run: a run going on (next grade, or a retry) is
	# saved at its new StudentCard start; a run that ended is deleted.
	if destination == ROSTER_SCENE:
		SaveGame.save()
	else:
		SaveGame.delete_save()
```

- [ ] **Step 4: Run the tests to see them pass**

Run, one at a time: `inventory_persistence`, `save_game`, `bugfix_nav`, `dapatkan_uang`, `student_card`, `run_result`, `economy_state`
Expected: all PASS. If any other suite still names a removed function, `grep -rn "save_inventory\|load_inventory\|clear_inventory_save\|_write_inventory_to" tests Scripts` finds it. Retarget it the same way.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Transition/Transition.gd Scripts/GameState.gd Scripts/EndGame/RunResult.gd tests/
git commit -m "feat(save): checkpoint the run around hub screens, retire inventory.cfg

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: SchoolDay saves each day's result and resumes the week

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` (after `write_back_to_gamestate`)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:202-226` (`_ready`), `:274-293` (`start_simulation`; add `resume_simulation` after it), `:440-441` (after `await _show_day_summary(day_name)`)
- Test: `tests/test_save_game.gd`

**Interfaces:**
- Consumes: `SaveGame.save(week)`, `GameState.pending_week_resume` (Task 1)
- Produces:
  - `StudentManager.SAVED_STAT_KEYS: Array`
  - `StudentManager.to_save_dict() -> Dictionary` with keys `students`, `minigame_history`, `daily_stat_log`
  - `StudentManager.restore_from_save(d: Dictionary) -> void`
  - `SchoolDay._week_snapshot(resume_day: int) -> Dictionary` with keys `resume_day`, `minigames_played`, `events_triggered`, `max_events`, `max_minigames`, `manager`
  - `SchoolDay.resume_simulation(week: Dictionary) -> void`

- [ ] **Step 1: Write the failing tests** (append to `tests/test_save_game.gd`)

```gdscript
## The week in progress: StudentManager's live and week-start stats, and the
## history the weekly report reads, survive a save.
func test_student_manager_round_trips_a_week_in_progress() -> void:
	GameState.approved_students = [
		{"id": 1, "name": "Marcel", "akademis": 50.0, "seni_budaya": 50.0, "olahraga": 50.0,
			"energy": 80.0, "mood": 80.0, "hobby_category": "Olahraga"},
	]
	var a := StudentManager.new()
	track(a)
	a.initialize_from_gamestate()
	a.students[0].akademis = 58.5
	a.students[0].energy = 61.0
	a.log_stat_change("Senin", "Marcel", "akademis", 8.5, "activity")
	a.record_event_result("Senin", "Hujan", ["Marcel"], "basah")
	var saved := a.to_save_dict()

	var b := StudentManager.new()
	track(b)
	b.restore_from_save(saved)
	assert_eq(b.students.size(), 1)
	assert_eq(b.students[0].akademis, 58.5, "the live stat comes back")
	assert_eq(b.students[0].energy, 61.0)
	assert_eq(b.students[0].initial_akademis, 50.0, "the week-start stat too, for the report's deltas")
	assert_eq(b.minigame_history.size(), 1, "the week's history comes back")
	assert_eq((b.daily_stat_log["Senin"] as Array).size(), 1, "and the day log")


func test_school_day_saves_after_each_days_result() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	var summary_at := src.find("await _show_day_summary(day_name)")
	var save_at := src.find("SaveGame.save(_week_snapshot(current_day + 1))")
	var click_at := src.find("await _await_click_to_continue()")
	assert_true(save_at > summary_at and save_at < click_at,
		"the daily save sits right after the day's result is shown")


func test_school_day_resumes_a_saved_week() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	var ready: String = src.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	assert_true(ready.contains("GameState.pending_week_resume"), "_ready looks for a saved week")
	assert_true(ready.contains("resume_simulation("), "and resumes it")
	var resume: String = src.get_slice("func resume_simulation(", 1).get_slice("\nfunc ", 0)
	assert_true(resume.contains("restore_from_save("), "the roster comes from the save")
	assert_false(resume.contains("minigame_gain_this_week.clear()"),
		"a resumed week keeps its minigame-gain budget, unlike a fresh one")
	assert_true(resume.contains("_run_day()"), "and the day loop runs from resume_day")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `test_run(suite="save_game")`
Expected: FAIL. `to_save_dict` and `restore_from_save` are not found, and the scans miss.

- [ ] **Step 3: Implement**

`Scripts/SchoolSimulation/StudentManager.gd`, after `write_back_to_gamestate()`:

```gdscript
## The StudentData fields SchoolDay's daily save carries, by student id:
## the live stats and the week-start ones the weekly report diffs against.
const SAVED_STAT_KEYS := [
	"akademis", "seni_budaya", "olahraga", "energy", "mood",
	"initial_akademis", "initial_seni_budaya", "initial_olahraga",
	"initial_energy", "initial_mood",
]


## The week so far, for SaveGame: each student's SAVED_STAT_KEYS by id, and
## the history and day log the weekly report reads. Plain data only.
func to_save_dict() -> Dictionary:
	var rows := []
	for s in students:
		var row := {"id": s.id}
		for k in SAVED_STAT_KEYS:
			row[k] = s.get(k)
		rows.append(row)
	return {
		"students": rows,
		"minigame_history": minigame_history.duplicate(true),
		"daily_stat_log": daily_stat_log.duplicate(true),
	}


## Inverse of to_save_dict(): rebuilds the roster from GameState (portraits,
## targets, quirks), then lays the saved stats over it by id, and restores
## the week's history. GameState itself is not written until the week ends.
func restore_from_save(d: Dictionary) -> void:
	initialize_from_gamestate()
	var by_id := {}
	for row in d.get("students", []):
		by_id[int(row.get("id", 0))] = row
	for s in students:
		var row: Dictionary = by_id.get(s.id, {})
		for k in SAVED_STAT_KEYS:
			if row.has(k):
				s.set(k, float(row[k]))
	minigame_history.assign(d.get("minigame_history", []))
	daily_stat_log = (d.get("daily_stat_log", {}) as Dictionary).duplicate(true)
```

`Scripts/SchoolSimulation/SchoolDay.gd`:
1. At the end of `_ready()`, replace the bare `start_simulation()` with:
```gdscript
	# Lanjutkan into a week in progress (SaveGame): resume it on its next
	# day instead of rolling a fresh week. The hand-off is one-shot.
	if not GameState.pending_week_resume.is_empty():
		var week: Dictionary = GameState.pending_week_resume
		GameState.pending_week_resume = {}
		resume_simulation(week)
	else:
		start_simulation()
```
2. After `start_simulation()`, add:
```gdscript
## Picks a saved week up on its next day (SaveGame's daily checkpoint):
## restores the week's quotas, the roster's live stats and the history, and
## keeps GameState.minigame_gain_this_week as saved -- a fresh week clears
## it, a resumed one must not. resume_day == DAYS.size() runs straight to
## the weekly report.
func resume_simulation(week: Dictionary) -> void:
	if is_running:
		return
	is_running = true
	is_skipped = false
	current_day = clampi(int(week.get("resume_day", 0)), 0, DAYS.size())
	minigames_played_this_week = int(week.get("minigames_played", 0))
	events_triggered_this_week = int(week.get("events_triggered", 0))
	max_events_this_week = int(week.get("max_events", 1))
	max_minigames_this_week = int(week.get("max_minigames", Balance.MINIGAME_MAKS_MINGGU_MIN))
	student_manager = StudentManager.new()
	student_manager.restore_from_save(week.get("manager", {}))
	if skip_button:
		skip_button.show()
	AudioDirector.play_ambience(&"classroom_1")
	_run_day()


## The week so far, for SaveGame.save(): the day to resume on, the week's
## quotas, and StudentManager's state.
func _week_snapshot(resume_day: int) -> Dictionary:
	return {
		"resume_day": resume_day,
		"minigames_played": minigames_played_this_week,
		"events_triggered": events_triggered_this_week,
		"max_events": max_events_this_week,
		"max_minigames": max_minigames_this_week,
		"manager": student_manager.to_save_dict(),
	}
```
3. In `_run_single_day()`, directly after `await _show_day_summary(day_name)`:
```gdscript
	# The daily-result checkpoint (SaveGame): the day is decided and shown,
	# so a quit from here on resumes on the next day.
	SaveGame.save(_week_snapshot(current_day + 1))
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `test_run(suite="save_game")`, then `test_run(suite="school_day")` (and any suite named `*school_day*`/`*student_manager*`: `ls tests | grep -i "school\|student_manager"`).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_save_game.gd
git commit -m "feat(save): save each day's result and resume a week on its next day

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: ContinuePopup on the title screen

**Files:**
- Create: `Scenes/MainMenu/ContinuePopup.tscn`, `Scripts/MainMenu/ContinuePopup.gd`
- Modify: `Scenes/MainMenu/MainMenu.tscn` (instance the popup as the last child of the root)
- Modify: `Scripts/MainMenu/MainMenu.gd` (`_start_game`, new `_begin_new_game`, `_continue_game`)
- Test: `tests/test_continue_popup.gd` (new), `tests/test_popup_frames.gd` (`POPUPS` row)

**Interfaces:**
- Consumes: `SaveGame.has_save()`, `SaveGame.summary()`, `SaveGame.load_save()`, `SaveGame.resume_scene()`, `SaveGame.delete_save()`, `SaveGame.merge_legacy_inventory()`, `GameState.reset_run()`, `GameState.pending_week_resume`
- Produces: `class_name ContinuePopup`, which extends `CanvasLayer`, with:
  - signals `continue_chosen`, `new_game_chosen`, `dismissed`
  - `open(summary_text: String) -> void`, `close() -> void`, `show_confirm(on: bool) -> void`

- [ ] **Step 1: Scene first.** Restart the editor first if any `.gd` was patched since the last restart.

Create `Scenes/MainMenu/ContinuePopup.tscn` with the MCP scene tools (`scene_manage` create, then one `batch_execute`), copying `Scenes/UI/StatDetailPopup.tscn`'s frame scaffold.

```
ContinuePopup            CanvasLayer   layer 100, visible false
└ Scrim                  ColorRect     anchors full rect, color (0,0,0,0.55), mouse_filter STOP
  └ Safe                 MarginContainer  full rect, script res://Scripts/UI/SafeAreaMargin.gd, mouse_filter IGNORE
    └ Center             CenterContainer  mouse_filter IGNORE
      └ Frame            instance res://Scenes/UI/NotebookFrame.tscn
                         custom_minimum_size (900, 0), title_text "LANJUTKAN", ring_count 4, show_well false
        └ Layout         VBoxContainer
          ├ Ask          VBoxContainer   separation 32
          │ ├ Question   Label  H2Label  "Mau melanjutkan permainan sebelumnya?"  autowrap WORD_SMART, h-align center
          │ ├ Summary    Label  CaptionLabel "Kelas 7 · Minggu 1/4"  h-align center
          │ └ Buttons    HBoxContainer   separation 24, alignment center
          │   ├ NewButton       Button SecondaryButton "Permainan baru"
          │   └ ContinueButton  Button PrimaryButton   "Ya, lanjutkan"
          └ Confirm      VBoxContainer   separation 32, visible false
            ├ Warning    Label  H2Label  "Yakin? Progres lama akan hilang."  autowrap WORD_SMART, h-align center
            └ Buttons    HBoxContainer   separation 24, alignment center
              ├ CancelButton    Button SecondaryButton "Batal"
              └ ConfirmButton   Button PrimaryButton   "Ya, mulai baru"
```

`scene_save`. Then `scene_open("res://Scenes/MainMenu/MainMenu.tscn")` and instance `ContinuePopup.tscn` as the **last** child of the root `MainMenu`, named `ContinuePopup`. `scene_save`, then `git diff HEAD -- '*.gd'` should be empty. Restart the editor before scripts.

- [ ] **Step 2: Write the failing tests**

Add a row to `tests/test_popup_frames.gd`'s `POPUPS`:
```gdscript
	"res://Scenes/MainMenu/ContinuePopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
```

Create `tests/test_continue_popup.gd`:

```gdscript
@tool
extends McpTestSuite

## ContinuePopup (2026-10-01 save system): the title screen's "carry on or
## start over" dialog. Structure and wiring are checked on a bare
## instantiate(); the routing is a source scan of MainMenu (a live tap would
## change scene). No coroutine tests.

const _SCENE := "res://Scenes/MainMenu/ContinuePopup.tscn"
const _ASK := "Scrim/Safe/Center/Frame/Layout/Ask"
const _CONFIRM := "Scrim/Safe/Center/Frame/Layout/Confirm"


func suite_name() -> String:
	return "continue_popup"


func _popup() -> ContinuePopup:
	var p: ContinuePopup = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func test_the_ask_page_says_exactly_what_was_asked() -> void:
	var p := _popup()
	assert_eq((p.get_node(_ASK + "/Question") as Label).text, "Mau melanjutkan permainan sebelumnya?")
	var cont := p.get_node(_ASK + "/Buttons/ContinueButton") as Button
	var new_game := p.get_node(_ASK + "/Buttons/NewButton") as Button
	assert_eq(cont.text, "Ya, lanjutkan")
	assert_eq(cont.theme_type_variation, &"PrimaryButton", "continuing is the main (mint) action")
	assert_eq(new_game.text, "Permainan baru")
	assert_eq(new_game.theme_type_variation, &"SecondaryButton")
	assert_eq((p.get_node(_ASK + "/Summary") as Label).theme_type_variation, &"CaptionLabel",
		"the summary is in the body face, which carries the '·'")
	Engine.get_main_loop().root.remove_child(p)


func test_the_confirm_page_guards_the_wipe() -> void:
	var p := _popup()
	assert_false((p.get_node(_CONFIRM) as Control).visible, "the confirm page starts hidden")
	assert_eq((p.get_node(_CONFIRM + "/Warning") as Label).text, "Yakin? Progres lama akan hilang.")
	assert_eq((p.get_node(_CONFIRM + "/Buttons/ConfirmButton") as Button).text, "Ya, mulai baru")
	assert_eq((p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button).text, "Batal")
	Engine.get_main_loop().root.remove_child(p)


func test_permainan_baru_flips_to_confirm_and_batal_flips_back() -> void:
	var p := _popup()
	(p.get_node(_ASK + "/Buttons/NewButton") as Button).pressed.emit()
	assert_true((p.get_node(_CONFIRM) as Control).visible, "Permainan baru asks first")
	assert_false((p.get_node(_ASK) as Control).visible)
	(p.get_node(_CONFIRM + "/Buttons/CancelButton") as Button).pressed.emit()
	assert_true((p.get_node(_ASK) as Control).visible, "Batal steps back")
	Engine.get_main_loop().root.remove_child(p)


func test_the_two_choices_emit_their_signals() -> void:
	var p := _popup()
	var got := []
	p.continue_chosen.connect(func(): got.append("continue"))
	p.new_game_chosen.connect(func(): got.append("new"))
	(p.get_node(_ASK + "/Buttons/ContinueButton") as Button).pressed.emit()
	(p.get_node(_CONFIRM + "/Buttons/ConfirmButton") as Button).pressed.emit()
	assert_eq(got, ["continue", "new"])
	Engine.get_main_loop().root.remove_child(p)


func test_the_display_face_lines_use_only_glyphs_it_has() -> void:
	var p := _popup()
	var display: Font = DesignTokens.load_default().font_display
	for path in [_ASK + "/Question", _CONFIRM + "/Warning"]:
		var text := (p.get_node(path) as Label).text
		for i in text.length():
			assert_true(display.has_char(text.unicode_at(i)),
				"'%s' in '%s' is not in the display face" % [String.chr(text.unicode_at(i)), text])
	Engine.get_main_loop().root.remove_child(p)


func test_main_menu_asks_only_when_a_save_exists() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	var start: String = src.get_slice("func _start_game()", 1).get_slice("\nfunc ", 0)
	assert_true(start.contains("SaveGame.has_save()"), "the tap checks for a save")
	assert_true(start.contains("_continue_popup.open("), "and opens the popup when there is one")
	assert_true(start.contains("_begin_new_game()"), "otherwise today's new-game path runs")
	var fresh: String = src.get_slice("func _begin_new_game()", 1).get_slice("\nfunc ", 0)
	for needle in ["GameState.reset_run()", "SaveGame.delete_save()", "SaveGame.merge_legacy_inventory()"]:
		assert_true(fresh.contains(needle), "a new game runs " + needle)
	var cont: String = src.get_slice("func _continue_game()", 1).get_slice("\nfunc ", 0)
	assert_true(cont.contains("SaveGame.load_save()"), "Lanjutkan loads the save")
	assert_true(cont.contains("SaveGame.resume_scene(GameState.pending_week_resume, GameState.returned_from_student_card)"),
		"and lands where resume_scene says")
	var menu: Node = load("res://Scenes/MainMenu/MainMenu.tscn").instantiate()
	track(menu)
	assert_true(menu.get_node_or_null("ContinuePopup") is ContinuePopup,
		"MainMenu.tscn instances the popup")
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `test_run(suite="continue_popup")`, `test_run(suite="popup_frames")`
Expected: FAIL. There is no `ContinuePopup` class or script, and the MainMenu scans miss.

- [ ] **Step 4: Implement**

Create `Scripts/MainMenu/ContinuePopup.gd` and attach it to the scene's root (`script_attach`):

```gdscript
@tool
class_name ContinuePopup
extends CanvasLayer

## The title screen's "carry on or start over" dialog (2026-10-01 save
## system). Two pages in one NotebookFrame: Ask (Lanjutkan / Permainan baru)
## and Confirm (Ya, mulai baru / Batal). It decides nothing itself: MainMenu
## listens to continue_chosen / new_game_chosen and routes.

## Ya, lanjutkan.
signal continue_chosen
## Ya, mulai baru, after the confirm page.
signal new_game_chosen
## Closed from the Ask page without choosing (Android back).
signal dismissed

@onready var _ask: Control = $Scrim/Safe/Center/Frame/Layout/Ask
@onready var _confirm: Control = $Scrim/Safe/Center/Frame/Layout/Confirm
@onready var _summary: Label = $Scrim/Safe/Center/Frame/Layout/Ask/Summary
@onready var _frame: Control = $Scrim/Safe/Center/Frame


func _ready() -> void:
	# Pure wiring, ungated, so the suite can press the buttons.
	$Scrim/Safe/Center/Frame/Layout/Ask/Buttons/ContinueButton.pressed.connect(
		func() -> void: continue_chosen.emit())
	$Scrim/Safe/Center/Frame/Layout/Ask/Buttons/NewButton.pressed.connect(
		func() -> void: show_confirm(true))
	$Scrim/Safe/Center/Frame/Layout/Confirm/Buttons/CancelButton.pressed.connect(
		func() -> void: show_confirm(false))
	$Scrim/Safe/Center/Frame/Layout/Confirm/Buttons/ConfirmButton.pressed.connect(
		func() -> void: new_game_chosen.emit())


## Shows the dialog on its Ask page with the save's summary line.
func open(summary_text: String) -> void:
	_summary.text = summary_text
	show_confirm(false)
	visible = true
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_open")
	Juice.pop_in(_frame)


## Hides the dialog.
func close() -> void:
	visible = false


## Swaps between the Ask page (false) and the Confirm page (true).
func show_confirm(on: bool) -> void:
	_ask.visible = not on
	_confirm.visible = on


## Android back: Confirm steps back to Ask; Ask closes.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not visible:
		return
	if _confirm.visible:
		show_confirm(false)
	else:
		close()
		dismissed.emit()
```

`Scripts/MainMenu/MainMenu.gd`:
1. Add with the other `@onready`s:
```gdscript
@onready var _continue_popup: ContinuePopup = $ContinuePopup
```
2. In `_ready()`, next to the existing button wiring (above the editor guard):
```gdscript
	_continue_popup.continue_chosen.connect(_continue_game)
	_continue_popup.new_game_chosen.connect(_begin_new_game)
	_continue_popup.dismissed.connect(func() -> void: _started = false)
```
3. Replace `_start_game()` and add two functions after it:
```gdscript
## A tap on the title: with a save on disk, ask whether to carry on;
## otherwise start a new game as before.
func _start_game() -> void:
	_started = true
	AudioDirector.play_sfx(&"confirm")
	if SaveGame.has_save():
		_continue_popup.open(SaveGame.summary())
	else:
		_begin_new_game()


## Permainan baru (or a first tap with no save): wipe the run -- not the
## achievements or settings -- delete the save, carry any pre-2026-10-01
## inventory over once, then the Level Select (while
## GameState.is_level_select_enabled()) or the intro, which starts Kelas 7.
func _begin_new_game() -> void:
	_continue_popup.close()
	GameState.reset_run()
	SaveGame.delete_save()
	SaveGame.merge_legacy_inventory()
	var target := "res://Scenes/LevelSelect/LevelSelect.tscn" \
		if GameState.is_level_select_enabled() \
		else "res://Scenes/CutScene/CutScene.tscn"
	Transition.change_scene(target, Transition.Style.WIPE, _INTRO_WIPE_SEC)


## Ya, lanjutkan: load the save and land where it left off. A save that
## vanished or went bad since the popup opened falls back to a new game.
func _continue_game() -> void:
	_continue_popup.close()
	if not SaveGame.load_save():
		_begin_new_game()
		return
	Transition.change_scene(
		SaveGame.resume_scene(GameState.pending_week_resume, GameState.returned_from_student_card),
		Transition.Style.WIPE, _INTRO_WIPE_SEC)
```
4. In `_unhandled_input`, also return early when `_continue_popup.visible`, so a tap on the popup's scrim never re-fires the title.

If `test_the_display_face_lines_use_only_glyphs_it_has` fails on `?` or `,`, switch that Label's variation in the scene to `EventBodyLabel` (body face) through the editor, and update the test's path list. Do not change the copy.

- [ ] **Step 5: Run the tests to see them pass**

Run, one at a time: `continue_popup`, `popup_frames`, `main_menu` (if `tests/test_main_menu.gd` exists), `viewport_editability`, `tall_screen_layout`, `script_documentation`, `theme_factory`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scenes/MainMenu/ Scripts/MainMenu/ tests/test_continue_popup.gd tests/test_popup_frames.gd
git commit -m "feat(main-menu): ask to continue the saved run or start a new game

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Live verification

No new code unless a check fails. A failure goes back to the task that owns it, under `superpowers:systematic-debugging`.

- [ ] **Step 1: The daily resume.** `project_stop` if running, then `filesystem_manage(op="scan")`, then `project_run`.
  1. Debug overlay → General → **⚡ Seed Playtest State**. Go to AturJadwal, fill the week, and press Mulai.
  2. Play SchoolDay until **Rabu's** day summary is dismissed.
  3. `project_manage(op="stop")`, then `project_run` again.
  4. Tap the title. The popup should read "Kelas 7 · Minggu 1/4 · Kamis". Take a **full-size** `editor_screenshot` and send it to the user.
  5. Tap **Ya, lanjutkan**. SchoolDay should open on **Kamis**. Let it run to the weekly report, which must list Senin–Jumat in its history (`game_manage get_ui_elements`, scoped to the report's root, `max_depth` 3).
- [ ] **Step 2: The hub checkpoint.** From the Lobby after that week, buy one item in Koperasi and return to the Lobby. Stop, relaunch and continue. The Lobby should open with the item in the Inventory and the money spent.
- [ ] **Step 3: New game.** Stop, relaunch, then choose Permainan baru → Ya, mulai baru. LevelSelect (or CutScene) opens. The Inventory is empty, and the Achievements screen still shows earlier progress.
- [ ] **Step 4: A bad save.** Stop. Overwrite `user://savegame.cfg` with the text `garbage`. The path is in `logs_read(source="game")`'s `OS.get_user_data_dir()` line, or under `%APPDATA%/Godot/app_userdata/<project>/`. Relaunch and tap the title. The game should start a new game with no popup, `savegame.bad.cfg` should exist, and the warning should be in `logs_read(source="game")`.
- [ ] **Step 5:** `logs_read(source="editor")` and `logs_read(source="game")` should show no errors from SaveGame, ContinuePopup or SchoolDay.

---

### Task 6: Docs, full run, ship

**Files:** `CLAUDE.md`, `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: CLAUDE.md.** Replace the paragraph beginning "Persistence is minimal and deliberate:" with:

```markdown
**Persistence:** the run saves to one file, `user://savegame.cfg`, owned by
`SaveGame` (`Scripts/Save/SaveGame.gd`; spec
`docs/superpowers/specs/2026-10-01-save-system-design.md`). It saves around
hub screens (`Transition` → `SaveGame.checkpoint`), on pause/quit on a hub,
after every SchoolDay day's result, and at RunResult's exit to StudentCard;
RunResult's exit to MainMenu deletes it. The title screen's ContinuePopup
resumes it or wipes the run (`GameState.reset_run()`). **Every GameState
field is in `SaveGame.SAVE_KEYS` or `EXCLUDED`** (`tests/test_save_game.gd`
fails otherwise): a new field picks one. Achievements
(`user://achievements.cfg`) and settings stay their own files. Debug >
General > **🧹 Forget Session** wipes the run, the save and achievements.
```

Also update the Loop paragraph: "**MainMenu (boot)** →" becomes "**MainMenu (boot; with a save, ContinuePopup)** →". Keep the file under 23,000 characters (`wc -c CLAUDE.md`).

- [ ] **Step 2: CHANGELOG.** Add a top entry, `## 2026-10-01 — Save system and Lanjutkan`, of four to six lines covering:
  - what is saved, and when
  - the popup
  - the inventory.cfg retirement and its carry-over
  - the two completeness ratchets
- [ ] **Step 3: Full suite.** Run `test_run()`. Expected: all PASS. Then `git status`, and `git checkout --` the theme and bus layout files if they changed. Budget one editor restart for this.
- [ ] **Step 4: Commit and ship.**

```bash
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git commit -m "docs(save): the run now persists; record the save rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then invoke the `ship-pr` skill.
