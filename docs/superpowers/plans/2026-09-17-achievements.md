# Achievements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 26 persistent achievements, each with a Lobby screen, Klaim prizes and an unlock banner.

**Architecture:** A data catalog (`AchievementCatalog`) plus a `@tool` autoload
(`Achievements`) that owns counters, unlocks, claims, saving and prize
multipliers. Game code reports events into it (SchoolDay, RunResult,
GameState.money_changed), and prize hooks read `Achievements.multiplier()`. The
UI is two authored scenes (the screen and its row template) and an autoload
toast scene.

**Tech Stack:** Godot 4.6 GDScript, McpTestSuite through the godot-ai bridge
(session `achievements@0cb6`, the worktree editor).

## Global Constraints

- Never edit `Balance.gd`; new numbers go in named consts.
- No `theme_override_*`: new looks are ThemeFactory variations, then rebake.
- No runtime visual construction: chrome lives in `.tscn`, rows come from a PackedScene.
- Every script has a `##` header and a `##` line on every `@export`.
- Test suites are `@tool`, no coroutine tests, and override `suite_name()`.
- UI text is Indonesian. No emoji.
- Code blocks headed `<!-- file: path -->` are the complete file contents.

---

### Task 1: Catalog + Achievements autoload (rules, claims, multipliers, save)

**Files:**
- Create: `Scripts/Achievements/AchievementCatalog.gd`, `Scripts/Achievements/Achievements.gd`
- Modify: `project.godot` (autoload `Achievements`, via `autoload_manage`)
- Test: `tests/test_achievements.gd`

**Interfaces (produced):**
- `AchievementCatalog.ENTRIES: Array` of `{id, title, desc, kind, target, effect, prize}`
- `AchievementCatalog.get_entry(id) -> Dictionary`, `icon_path(id) -> String`, `description_of(entry) -> String`
- Autoload `Achievements`: `signal unlocked(id: String)`, `signal claimed(id: String)`;
  `record_minigame(category: String, game_name: String, won: bool, stars: int, time_left_ratio: float)`,
  `record_money(amount: int)`, `record_grade_passed(grade: int)`, `claim(id) -> bool`,
  `state_of(id) -> int` (`STATE_LOCKED`/`STATE_UNLOCKED`/`STATE_CLAIMED`),
  `effect_multiplier(effect) -> float`, `reset()`, `write_to(cfg)`/`read_from(cfg)`,
  static `multiplier(effect) -> float`.
- Effects: `"minigame_stat"`, `"wirausaha"`, `"shop_price"`, `"minigame_time"`.

- [ ] Step 1: Write `tests/test_achievements.gd` (below).
- [ ] Step 2: `Run: test_run(suite="achievements")`. Expected: broken (scripts missing).
- [ ] Step 3: Write both scripts, register the autoload, scan.
- [ ] Step 4: `Run: test_run(suite="achievements")`. Expected: all pass.
- [ ] Step 5: Commit `feat(achievements): catalog, tracker and prize multipliers`.

<!-- file: tests/test_achievements.gd -->
```gdscript
@tool
extends McpTestSuite

## The achievement tracker (spec: docs/superpowers/specs/2026-09-17-achievements-design.md):
## the catalog, every unlock rule, claiming, prize multipliers and the save
## round-trip. Each test builds a fresh, out-of-tree Achievements instance, so
## no autoload state and no user:// file is touched.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")


func suite_name() -> String:
	return "achievements"


func _fresh() -> Node:
	var a: Node = ACHIEVEMENTS.new()
	track(a)
	return a


func _ids() -> Array:
	var out := []
	for e in AchievementCatalog.ENTRIES:
		out.append(e.id)
	return out


func test_catalog_has_26_unique_entries_with_icons() -> void:
	var ids := _ids()
	assert_eq(ids.size(), 26)
	var seen := {}
	for id in ids:
		assert_false(seen.has(id), "duplicate id " + id)
		seen[id] = true
		assert_true(ResourceLoader.exists(AchievementCatalog.icon_path(id)), "icon for " + id)


func test_user_renames_are_applied() -> void:
	assert_eq(AchievementCatalog.get_entry("total_50").title, "Pembimbing Legendaris")
	assert_eq(AchievementCatalog.get_entry("streak_4").title, "Calon Sarjana S3")
	assert_eq(AchievementCatalog.get_entry("money_6x").title, "Kita kaya!")
	assert_eq(AchievementCatalog.get_entry("money_4x").title, "Belajar Menabung")
	assert_eq(AchievementCatalog.get_entry("streak_6").title, "Calon Asisten Einstein")


func test_everything_starts_locked() -> void:
	var a := _fresh()
	for id in _ids():
		assert_eq(a.state_of(id), ACHIEVEMENTS.STATE_LOCKED, id)


func test_three_star_unlocks_only_its_category() -> void:
	var a := _fresh()
	a.record_minigame("SeniBudaya", "Buat Batik", true, 3, -1.0)
	assert_eq(a.state_of("three_star_seni"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("three_star_akademis"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_minigame("Olahraga", "Main Bola", true, 2, -1.0)
	assert_eq(a.state_of("three_star_olahraga"), ACHIEVEMENTS.STATE_LOCKED)


func test_streak_resets_on_a_non_perfect_result_but_keeps_its_unlock() -> void:
	var a := _fresh()
	a.record_minigame("Akademis", "Variabel Matematika", true, 3, -1.0)
	a.record_minigame("Akademis", "Variabel Matematika", true, 3, -1.0)
	assert_eq(a.state_of("streak_2"), ACHIEVEMENTS.STATE_UNLOCKED)
	a.record_minigame("Akademis", "Variabel Matematika", true, 2, -1.0)
	assert_eq(a.current_streak, 0)
	for i in 3:
		a.record_minigame("Akademis", "Variabel Matematika", true, 3, -1.0)
	assert_eq(a.state_of("streak_4"), ACHIEVEMENTS.STATE_LOCKED, "3 in a row is not 4")
	a.record_minigame("Akademis", "Variabel Matematika", false, 0, -1.0)
	assert_eq(a.current_streak, 0, "a loss breaks the streak")
	assert_eq(a.state_of("streak_2"), ACHIEVEMENTS.STATE_UNLOCKED)


func test_play_all_needs_every_distinct_game() -> void:
	var a := _fresh()
	a.record_minigame("Olahraga", "Main Bola", false, 0, -1.0)
	a.record_minigame("Olahraga", "Main Bola", true, 1, -1.0)
	assert_eq(a.state_of("play_all_olahraga"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_minigame("Olahraga", "Badminton", false, 0, -1.0)
	assert_eq(a.state_of("play_all_olahraga"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(ACHIEVEMENTS.PLAY_ALL_REQUIRED["Akademis"].size(), 4)


func test_total_minigames_thresholds() -> void:
	var a := _fresh()
	for i in 14:
		a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	assert_eq(a.state_of("total_10"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("total_15"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	assert_eq(a.state_of("total_15"), ACHIEVEMENTS.STATE_UNLOCKED)


func test_fast_wins_need_a_win_with_half_the_time_left() -> void:
	var a := _fresh()
	a.record_minigame("Akademis", "Menjodohkan", true, 2, 0.49)
	a.record_minigame("Akademis", "Menjodohkan", false, 0, 0.9)
	a.record_minigame("Olahraga", "Badminton", true, 3, -1.0)
	assert_eq(a.fast_wins, 0)
	a.record_minigame("Akademis", "Menjodohkan", true, 2, 0.5)
	assert_eq(a.state_of("fast_1"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(AchievementCatalog.get_entry("fast_12").target, 12)


func test_money_thresholds_use_the_base() -> void:
	var a := _fresh()
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 4 - 1)
	assert_eq(a.state_of("money_2x"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("money_4x"), ACHIEVEMENTS.STATE_LOCKED)
	a.record_money(0)
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 8)
	assert_eq(a.state_of("money_8x"), ACHIEVEMENTS.STATE_UNLOCKED)


func test_grades() -> void:
	var a := _fresh()
	a.record_grade_passed(8)
	assert_eq(a.state_of("grade_8"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)


func test_unlock_signal_fires_once() -> void:
	var a := _fresh()
	var got := []
	a.unlocked.connect(func(id): got.append(id))
	a.record_grade_passed(7)
	a.record_grade_passed(7)
	assert_eq(got, ["grade_7"])


func test_claim_only_after_unlock_and_only_once() -> void:
	var a := _fresh()
	assert_false(a.claim("grade_9"), "locked cannot be claimed")
	a.record_grade_passed(9)
	assert_true(a.claim("grade_9"))
	assert_eq(a.state_of("grade_9"), ACHIEVEMENTS.STATE_CLAIMED)
	assert_false(a.claim("grade_9"), "already claimed")


func test_prizes_apply_only_when_claimed_and_stack() -> void:
	var a := _fresh()
	for i in 50:
		a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 8)
	assert_eq(a.effect_multiplier("wirausaha"), 1.0, "unlocked is not claimed")
	a.claim("total_25")
	assert_almost_eq(a.effect_multiplier("wirausaha"), 1.05, 0.0001)
	a.claim("money_8x")
	assert_almost_eq(a.effect_multiplier("wirausaha"), 1.10, 0.0001)
	a.claim("total_50")
	assert_almost_eq(a.effect_multiplier("shop_price"), 0.90, 0.0001)
	a.claim("total_15")
	assert_eq(a.effect_multiplier("minigame_stat"), 1.0, "the Thea skin prize has no effect")


func test_save_round_trip() -> void:
	var a := _fresh()
	a.record_minigame("Olahraga", "Main Bola", true, 3, 0.8)
	a.record_money(ACHIEVEMENTS.MONEY_BASE * 2)
	a.claim("three_star_olahraga")
	var cfg := ConfigFile.new()
	a.write_to(cfg)
	var b := _fresh()
	b.read_from(cfg)
	assert_eq(b.minigames_played, 1)
	assert_eq(b.fast_wins, 1)
	assert_eq(b.best_streak, 1)
	assert_eq(b.state_of("three_star_olahraga"), ACHIEVEMENTS.STATE_CLAIMED)
	assert_eq(b.state_of("money_2x"), ACHIEVEMENTS.STATE_UNLOCKED)
	assert_true("Main Bola" in b.played_names.get("Olahraga", []))


func test_reset_clears_everything() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	a.reset()
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)
	assert_eq(a.minigames_played, 0)


func test_static_multiplier_is_neutral_without_claims() -> void:
	# The editor's own autoload instance never loads a save (editor-hint gate).
	assert_eq(ACHIEVEMENTS.multiplier("shop_price"), 1.0)
```

<!-- file: Scripts/Achievements/AchievementCatalog.gd -->
```gdscript
@tool
class_name AchievementCatalog
extends RefCounted

## Every achievement in the game, as data (spec:
## docs/superpowers/specs/2026-09-17-achievements-design.md).
##
## Each entry: `id` (also its icon file name), `title` and `desc` (player
## text), `kind` + `target` (the rule Achievements.gd checks), `effect` (the
## prize multiplier it turns on once claimed, or "") and `prize` (player text
## for the prize, or ""). Pure data -- the counters live in Achievements.gd.

const ICON_DIR := "res://Assets/Images/Achievements/Icons/"

const KIND_THREE_STAR := "three_star"   ## target: category
const KIND_STREAK := "streak"           ## target: perfect results in a row
const KIND_PLAY_ALL := "play_all"       ## target: category
const KIND_TOTAL := "total"             ## target: minigames played
const KIND_MONEY := "money"             ## target: multiple of MONEY_BASE held
const KIND_GRADE := "grade"             ## target: grade passed
const KIND_FAST := "fast"               ## target: fast wins

const ENTRIES := [
	{"id": "three_star_akademis", "title": "Cap-cip-cup kembang kuncup!", "desc": "Selesaikan satu minigame Akademis dengan skor sempurna.", "kind": KIND_THREE_STAR, "target": "Akademis", "effect": "", "prize": ""},
	{"id": "three_star_seni", "title": "Kunci kemenangan adalah Budaya!", "desc": "Selesaikan satu minigame Seni Budaya dengan skor sempurna.", "kind": KIND_THREE_STAR, "target": "SeniBudaya", "effect": "", "prize": ""},
	{"id": "three_star_olahraga", "title": "Turunan Ronaldio atau Rudie?!", "desc": "Selesaikan satu minigame Olahraga dengan skor sempurna.", "kind": KIND_THREE_STAR, "target": "Olahraga", "effect": "", "prize": ""},
	{"id": "streak_2", "title": "Calon Pembimbing Handal", "desc": "Menangkan minigame apa pun dengan skor sempurna 2 kali berturut-turut.", "kind": KIND_STREAK, "target": 2, "effect": "", "prize": ""},
	{"id": "streak_4", "title": "Calon Sarjana S3", "desc": "Menangkan minigame apa pun dengan skor sempurna 4 kali berturut-turut.", "kind": KIND_STREAK, "target": 4, "effect": "", "prize": ""},
	{"id": "streak_6", "title": "Calon Asisten Einstein", "desc": "Menangkan minigame apa pun dengan skor sempurna 6 kali berturut-turut.", "kind": KIND_STREAK, "target": 6, "effect": "minigame_stat", "prize": "Poin stat murid dari minigame +5%"},
	{"id": "play_all_akademis", "title": "Buku adalah jendela dunia!", "desc": "Temukan dan mainkan seluruh jenis minigame Akademis.", "kind": KIND_PLAY_ALL, "target": "Akademis", "effect": "", "prize": ""},
	{"id": "play_all_seni", "title": "Kebudayaan Lokal yang Arif!", "desc": "Temukan dan mainkan seluruh jenis minigame Seni Budaya.", "kind": KIND_PLAY_ALL, "target": "SeniBudaya", "effect": "", "prize": ""},
	{"id": "play_all_olahraga", "title": "Satu, dua, satu dan dua!", "desc": "Temukan dan mainkan seluruh jenis minigame Olahraga.", "kind": KIND_PLAY_ALL, "target": "Olahraga", "effect": "", "prize": ""},
	{"id": "total_5", "title": "Pembimbing Awam", "desc": "Mainkan total 5 minigame.", "kind": KIND_TOTAL, "target": 5, "effect": "", "prize": ""},
	{"id": "total_10", "title": "Pembimbing Serba-bisa", "desc": "Mainkan total 10 minigame.", "kind": KIND_TOTAL, "target": 10, "effect": "", "prize": ""},
	{"id": "total_15", "title": "Pembimbing Profesional", "desc": "Mainkan total 15 minigame.", "kind": KIND_TOTAL, "target": 15, "effect": "", "prize": "Skin Thea (segera hadir)"},
	{"id": "total_25", "title": "Pembimbing Sepuh", "desc": "Mainkan total 25 minigame.", "kind": KIND_TOTAL, "target": 25, "effect": "wirausaha", "prize": "Hasil Wirausaha +5%"},
	{"id": "total_50", "title": "Pembimbing Legendaris", "desc": "Mainkan total 50 minigame.", "kind": KIND_TOTAL, "target": 50, "effect": "shop_price", "prize": "Harga item di Koperasi -10%"},
	{"id": "money_2x", "title": "Sedikit demi sedikit . . .", "desc": "Kumpulkan uang sebanyak 2.000.", "kind": KIND_MONEY, "target": 2, "effect": "", "prize": ""},
	{"id": "money_4x", "title": "Belajar Menabung", "desc": "Kumpulkan uang sebanyak 4.000.", "kind": KIND_MONEY, "target": 4, "effect": "", "prize": ""},
	{"id": "money_6x", "title": "Kita kaya!", "desc": "Kumpulkan uang sebanyak 6.000.", "kind": KIND_MONEY, "target": 6, "effect": "", "prize": ""},
	{"id": "money_8x", "title": "Seorang CEO yang menyamar . . .", "desc": "Kumpulkan uang sebanyak 8.000.", "kind": KIND_MONEY, "target": 8, "effect": "wirausaha", "prize": "Hasil Wirausaha +5%"},
	{"id": "grade_7", "title": "Sudah bukan pemula lagi nih!", "desc": "Selesaikan kelas 7 dan naik ke kelas 8.", "kind": KIND_GRADE, "target": 7, "effect": "", "prize": ""},
	{"id": "grade_8", "title": "Semangat dari Seorang Pembimbing . . .", "desc": "Selesaikan kelas 8 dan naik ke kelas 9.", "kind": KIND_GRADE, "target": 8, "effect": "", "prize": ""},
	{"id": "grade_9", "title": "Masa Depan yang Indah . . .", "desc": "Tamatkan game dengan memenangkan kelas 9.", "kind": KIND_GRADE, "target": 9, "effect": "", "prize": ""},
	{"id": "fast_1", "title": "Sat-set!", "desc": "Menangkan 1 minigame dengan waktu sesingkat-singkatnya.", "kind": KIND_FAST, "target": 1, "effect": "", "prize": ""},
	{"id": "fast_3", "title": "Pembimbing RB26 Turbo", "desc": "Menangkan 3 minigame dengan waktu sesingkat-singkatnya.", "kind": KIND_FAST, "target": 3, "effect": "", "prize": ""},
	{"id": "fast_6", "title": "Blitzkrieg di Banjarsari", "desc": "Menangkan 6 minigame dengan waktu sesingkat-singkatnya.", "kind": KIND_FAST, "target": 6, "effect": "", "prize": ""},
	{"id": "fast_9", "title": "Hilang dalam 60 detik", "desc": "Menangkan 9 minigame dengan waktu sesingkat-singkatnya.", "kind": KIND_FAST, "target": 9, "effect": "", "prize": ""},
	{"id": "fast_12", "title": "Panggil aku Bejo \"The Flash\"", "desc": "Menangkan 12 minigame dengan waktu sesingkat-singkatnya.", "kind": KIND_FAST, "target": 12, "effect": "minigame_time", "prize": "Waktu minigame +5%"},
]


## The entry for `id`, or an empty Dictionary when there is none.
static func get_entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if e.id == id:
			return e
	return {}


## The icon texture path for `id`.
static func icon_path(id: String) -> String:
	return ICON_DIR + id + ".png"


## The card's body text: the requirement, plus the prize line when it has one.
static func description_of(entry: Dictionary) -> String:
	if String(entry.get("prize", "")) == "":
		return entry.desc
	return "%s\nHadiah: %s" % [entry.desc, entry.prize]
```

<!-- file: Scripts/Achievements/Achievements.gd -->
```gdscript
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
```

### Task 2: Report game events and apply prizes

**Files:**
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd` (`start_minigame`, `_show_result_overlay`, new vars)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (`_play_minigame` real path, `_pay_out_wirausaha`)
- Modify: `Scripts/SchoolSimulation/StudentData.gd` (`apply_minigame_result`)
- Modify: `Scripts/Inventory/Cart.gd` (`price_of`, `total_of`), `Scripts/Koperasi/rakbarang_1.gd` (display and affordability)
- Modify: `Scripts/EndGame/RunResult.gd` (`_apply_progression` pass branch)
- Modify: `Scripts/GameState.gd` `forget_session()` → `Achievements.reset()`
- Test: add source scans to `tests/test_achievements.gd`

- [ ] Step 1: Append the tests below. Run them: they fail.
- [ ] Step 2: Make the edits. Each edit adds a `const AchievementsScript := preload("res://Scripts/Achievements/Achievements.gd")` and calls `AchievementsScript.multiplier("<effect>")`, or calls the autoload directly from node scripts (SchoolDay, RunResult, GameState).
  - BaseMinigame: `var last_result_stars: int = 0`, `var last_time_left_ratio: float = -1.0`. In `_show_result_overlay`, after `stars` is computed: `last_result_stars = stars` and `last_time_left_ratio = clampf(game_time_left / max_game_time, 0.0, 1.0) if has_time_limit and max_game_time > 0.0 else -1.0`. In `start_minigame`: `if time_limit > 0: time_limit *= AchievementsScript.multiplier("minigame_time")`.
  - SchoolDay: after `student_manager.record_minigame_result(...)` on the real path, read `last_result_stars`/`last_time_left_ratio` off `current_minigame` and call `Achievements.record_minigame(category, game_name, won, stars, ratio)`. In `_pay_out_wirausaha`, after summing: `total = roundi(total * Achievements.effect_multiplier("wirausaha"))`.
  - StudentData: right after the won/lost block, `if won and stat_change > 0: stat_change = roundf(stat_change * AchievementsScript.multiplier("minigame_stat"))`.
  - Cart: `static func price_of(item) -> int: return roundi(item.price * AchievementsScript.multiplier("shop_price"))`, and `total_of` uses `price_of`.
  - rakbarang_1: `tag.set_price(Cart.price_of(item))`, with affordability and dimming against `Cart.price_of(item_data_list[i])`.
  - RunResult: first line of the non-failed path, `Achievements.record_grade_passed(GameState.current_grade)`.
  - GameState.forget_session: `Achievements.reset()`.
- [ ] Step 3: Run `achievements` plus the suites covering these files (`koperasi*`, `student_data*`, `run_result*`, `school_day*`, `minigame*`). Expected: pass.
- [ ] Step 4: Commit `feat(achievements): report minigames, money and grades; apply claimed prizes`.

```gdscript
func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_school_day_reports_real_minigames_only() -> void:
	var src := _src("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("Achievements.record_minigame(category, game_name, won"), "real path reports")
	var cheat_block := src.substr(src.find("Debug Cheat Interception"), 700)
	assert_false(cheat_block.contains("record_minigame("), "the cheat must not count")
	assert_true(src.contains("Achievements.effect_multiplier(\"wirausaha\")"))


func test_base_minigame_exposes_result_and_scales_time() -> void:
	var src := _src("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_true(src.contains("last_result_stars = stars"))
	assert_true(src.contains("last_time_left_ratio"))
	assert_true(src.contains("multiplier(\"minigame_time\")"))


func test_prize_hooks_are_wired() -> void:
	assert_true(_src("res://Scripts/SchoolSimulation/StudentData.gd").contains("multiplier(\"minigame_stat\")"))
	assert_true(_src("res://Scripts/Inventory/Cart.gd").contains("multiplier(\"shop_price\")"))
	assert_true(_src("res://Scripts/Koperasi/rakbarang_1.gd").contains("Cart.price_of("))
	assert_true(_src("res://Scripts/EndGame/RunResult.gd").contains("Achievements.record_grade_passed(GameState.current_grade)"))
	assert_true(_src("res://Scripts/GameState.gd").contains("Achievements.reset()"))
```

### Task 3: Theme variations

**Files:** Modify `Scripts/Design/ThemeFactory.gd` (new `_build_achievements`), `tests/test_theme_factory.gd` (DISPLAY_ROSTER). Rebake. Test: `tests/test_achievement_screen.gd` (new).

Variations: `AchievementCard` (PanelContainer, white StyleBoxFlat, radius 24,
content margins 25/30/25/28); `AchievementCardClaimed` (PanelContainer,
StyleBoxTexture `card_claimed.png`, texture margins 48, expand margins 24, same
content margins); `AchievementTitleLabel` (display font, 44, black);
`AchievementDescLabel` (body, 29, black); `AchievementClaimButton` (display
font, 29, white text, fill #B2C73B, border #8D8A2F width 6, pill radius);
`AchievementToastPanel` (white, bottom radius 24); `AchievementToastTitleLabel`
(display, 48, black). The four display ones join DISPLAY_ROSTER.

- [ ] Step 1: Write the theme tests (in the Task 4 suite file). Run: fail.
- [ ] Step 2: Implement, rebake, then run `achievement_screen` and `theme_factory`. Expected: pass.
- [ ] Step 3: Commit `feat(theme): achievement card, claim button and toast variations`.

### Task 4: Achievements screen, row template, Lobby button

**Files:** Create `Scenes/Achievements/achievements.tscn`, `Scenes/Achievements/AchievementRow.tscn`, `Scripts/Achievements/achievements_screen.gd`, `Scripts/Achievements/AchievementRow.gd`. Modify `Scenes/Lobby/loby.tscn` (through the editor: `AchievementButton` TextureButton in `Safe/UI/BottomBar`, 400–496 × 0–96, `achievement_button.png`, ignore_texture_size, stretch keep-aspect-centered), `Scripts/Lobby/loby.gd` (unique ref, juice list, `pressed` → `Transition.change_scene("res://Scenes/Achievements/achievements.tscn", Transition.Style.WIPE)`). Test: `tests/test_achievement_screen.gd`, plus a new case in `tests/test_tall_screen_layout.gd`.

Screen tree: `Achievements` (Control, full rect) → `Background` (full rect,
covered, `bg_achievements_blur.jpg`) → `Safe` (SafeAreaMargin) → `UI` →
`Ribbon` (top-centre, 863×290, y 40), `Scroll` (full rect, insets 108/350/107/260,
no horizontal scroll) → `%List` (VBox, separation 60), and `%BackButton`
(bottom-left, 68..228 × -225..-80, `back_arrow.png`). Row tree:
`AchievementRow` (PanelContainer `AchievementCard`, min 865×306) → `HBox`
(separation 24) → `%Icon` (258×239, keep aspect) and `Content` (VBox, expand) →
`%Title`, `Rule` (ColorRect black, min height 9), `%Desc` (autowrap),
`ClaimRow` (HBox aligned end) → `%ClaimButton` (202×64, "Klaim").

- [ ] Step 1: Write the suite (scene contract, row states through `set_state`, lobby button, theme variations). Run: fail.
- [ ] Step 2: Write the scenes and scripts. Run `achievement_screen` and `tall_screen_layout`. Expected: pass.
- [ ] Step 3: Commit `feat(achievements): the Achievements screen and its Lobby button`.

### Task 5: Unlock toast

**Files:** Create `Scenes/Achievements/AchievementToast.tscn`, `Scripts/Achievements/AchievementToast.gd`. Register the autoload `AchievementToast`. Test: `tests/test_achievement_toast.gd`.

It is a CanvasLayer (layer 120, process always). `Banner` is a Panel
(`AchievementToastPanel`) anchored top-centre, 672×155, hidden at y -155.
Inside it are `Icon` (20,10)-(134,130) and `Title` (`AchievementToastTitleLabel`,
x 170-650, vertically centred). The `enqueue(id)` queue shows one banner at a
time: slide in 0.35s (back-out), hold 2.2s, slide out 0.3s. All timings are
`@export`s.

- [ ] Step 1: Write the suite (scene contract; enqueue while busy only queues; the autoload is registered). Run: fail.
- [ ] Step 2: Implement it. Run the suite: pass.
- [ ] Step 3: Commit `feat(achievements): unlock banner`.

### Task 6: Verify in game, docs, full suite

- [ ] Run the game in the worktree editor. Seed, teleport to Lobby, open Achievements. Use `game_eval` to unlock and claim a few, then screenshot the screen and a toast at full size.
- [ ] Update CLAUDE.md (autoload table, persistence line), CHANGELOG, and DEBT (Thea skin prize).
- [ ] Full `test_run`. Revert unintended `default_bus_layout.tres` and `.import` rewrites.
- [ ] Commit.
