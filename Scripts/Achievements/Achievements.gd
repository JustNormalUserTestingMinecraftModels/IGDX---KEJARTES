@tool
extends Node

## The achievement tracker, as an autoload (spec:
## docs/superpowers/specs/2026-09-17-achievements-design.md).
##
## Game code reports what happened (record_minigame from SchoolDay,
## record_grade_passed from RunResult, record_money from
## GameState.money_changed). This node keeps the counters, unlocks whatever
## AchievementCatalog's rules now allow, emits `unlocked`, and saves to
## user://achievements.cfg. Claimed prizes are read back through
## multiplier(). Saving and loading are skipped in the editor (the test
## runner builds fresh instances), which is why this script is @tool.

signal unlocked(id: String)
signal claimed(id: String)

const SAVE_PATH := "user://achievements.cfg"

const STATE_LOCKED := 0
const STATE_UNLOCKED := 1
const STATE_CLAIMED := 2

## Money milestones are multiples of this. Starting money is 0, so the list's
## "N x starting money" needed a base of our own.
const MONEY_BASE := 1000
## A win counts as fast when at least this share of its time limit is left.
const FAST_WIN_TIME_LEFT_RATIO := 0.5
## Stars that make a result "perfect".
const PERFECT_STARS := 3
## Every minigame per category, by the names SchoolDay._scene_name() reports.
const PLAY_ALL_REQUIRED := {
	"Akademis": ["Menjodohkan", "Variabel Matematika", "Pilihan Ganda", "Sandi Matematika"],
	"SeniBudaya": ["Buat Batik", "Lomba Menari"],
	"Olahraga": ["Main Bola", "Badminton"],
}
## What each claimed prize adds to its multiplier.
const EFFECT_STEP := {
	"minigame_stat": 0.05,
	"wirausaha": 0.05,
	"shop_price": -0.10,
	"minigame_time": 0.05,
}

var minigames_played: int = 0
var current_streak: int = 0
var best_streak: int = 0
var fast_wins: int = 0
var highest_money: int = 0
## Category -> Array of minigame names played at least once.
var played_names: Dictionary = {}
## Categories with at least one perfect result.
var perfect_categories: Dictionary = {}
var passed_grades: Dictionary = {}
var unlocked_ids: Dictionary = {}
var claimed_ids: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	load_progress()
	GameState.money_changed.connect(record_money)


## The live autoload's multiplier for `effect`, or 1.0 when there is no
## autoload (static callers: Cart.total_of, StudentData, BaseMinigame).
static func multiplier(effect: String) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	var node := tree.root.get_node_or_null("Achievements")
	if node == null or not node.has_method("effect_multiplier"):
		return 1.0
	return node.effect_multiplier(effect)


## One minigame finished inside SchoolDay. `stars` is BaseMinigame's rating
## (0 on a loss); `time_left_ratio` is -1 for a game without a time limit.
func record_minigame(category: String, game_name: String, won: bool, stars: int, time_left_ratio: float) -> void:
	minigames_played += 1
	var names: Array = played_names.get(category, [])
	if not game_name in names:
		names.append(game_name)
	played_names[category] = names
	if won and stars >= PERFECT_STARS:
		current_streak += 1
		best_streak = maxi(best_streak, current_streak)
		perfect_categories[category] = true
	else:
		current_streak = 0
	if won and time_left_ratio >= FAST_WIN_TIME_LEFT_RATIO:
		fast_wins += 1
	_changed()


## The player's money moved to `amount`.
func record_money(amount: int) -> void:
	if amount <= highest_money:
		return
	highest_money = amount
	_changed()


## Grade `grade` was passed.
func record_grade_passed(grade: int) -> void:
	passed_grades[grade] = true
	_changed()


## Claims an unlocked achievement, turning its prize on. False if it is
## locked or already claimed.
func claim(id: String) -> bool:
	if state_of(id) != STATE_UNLOCKED:
		return false
	claimed_ids[id] = true
	_save()
	claimed.emit(id)
	return true


func state_of(id: String) -> int:
	if claimed_ids.has(id):
		return STATE_CLAIMED
	if unlocked_ids.has(id):
		return STATE_UNLOCKED
	return STATE_LOCKED


## 1.0 plus every claimed prize's step for `effect`.
func effect_multiplier(effect: String) -> float:
	var m := 1.0
	for e in AchievementCatalog.ENTRIES:
		if e.effect == effect and claimed_ids.has(e.id):
			m += float(EFFECT_STEP.get(effect, 0.0))
	return m


## Forgets all progress, including the save file (Debug > Forget Session).
func reset() -> void:
	minigames_played = 0
	current_streak = 0
	best_streak = 0
	fast_wins = 0
	highest_money = 0
	played_names = {}
	perfect_categories = {}
	passed_grades = {}
	unlocked_ids = {}
	claimed_ids = {}
	if not Engine.is_editor_hint() and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _is_met(e: Dictionary) -> bool:
	match e.kind:
		AchievementCatalog.KIND_THREE_STAR:
			return perfect_categories.has(e.target)
		AchievementCatalog.KIND_STREAK:
			return best_streak >= int(e.target)
		AchievementCatalog.KIND_PLAY_ALL:
			var names: Array = played_names.get(e.target, [])
			for n in PLAY_ALL_REQUIRED.get(e.target, []):
				if not n in names:
					return false
			return true
		AchievementCatalog.KIND_TOTAL:
			return minigames_played >= int(e.target)
		AchievementCatalog.KIND_MONEY:
			return highest_money >= int(e.target) * MONEY_BASE
		AchievementCatalog.KIND_GRADE:
			return passed_grades.has(int(e.target))
		AchievementCatalog.KIND_FAST:
			return fast_wins >= int(e.target)
	return false


func _changed() -> void:
	var fresh := []
	for e in AchievementCatalog.ENTRIES:
		if not unlocked_ids.has(e.id) and _is_met(e):
			unlocked_ids[e.id] = true
			fresh.append(e.id)
	_save()
	for id in fresh:
		unlocked.emit(id)


func write_to(cfg: ConfigFile) -> void:
	cfg.set_value("progres", "minigames_played", minigames_played)
	cfg.set_value("progres", "current_streak", current_streak)
	cfg.set_value("progres", "best_streak", best_streak)
	cfg.set_value("progres", "fast_wins", fast_wins)
	cfg.set_value("progres", "highest_money", highest_money)
	cfg.set_value("progres", "played_names", played_names)
	cfg.set_value("progres", "perfect_categories", perfect_categories.keys())
	cfg.set_value("progres", "passed_grades", passed_grades.keys())
	cfg.set_value("achievement", "unlocked", unlocked_ids.keys())
	cfg.set_value("achievement", "claimed", claimed_ids.keys())


func read_from(cfg: ConfigFile) -> void:
	minigames_played = int(cfg.get_value("progres", "minigames_played", 0))
	current_streak = int(cfg.get_value("progres", "current_streak", 0))
	best_streak = int(cfg.get_value("progres", "best_streak", 0))
	fast_wins = int(cfg.get_value("progres", "fast_wins", 0))
	highest_money = int(cfg.get_value("progres", "highest_money", 0))
	played_names = cfg.get_value("progres", "played_names", {})
	perfect_categories = _as_set(cfg.get_value("progres", "perfect_categories", []))
	passed_grades = _as_set(cfg.get_value("progres", "passed_grades", []))
	unlocked_ids = _as_set(cfg.get_value("achievement", "unlocked", []))
	claimed_ids = _as_set(cfg.get_value("achievement", "claimed", []))


func _as_set(keys: Array) -> Dictionary:
	var d := {}
	for k in keys:
		d[k] = true
	return d


func load_progress() -> void:
	if Engine.is_editor_hint():
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		read_from(cfg)


func _save() -> void:
	if Engine.is_editor_hint():
		return
	var cfg := ConfigFile.new()
	write_to(cfg)
	cfg.save(SAVE_PATH)
