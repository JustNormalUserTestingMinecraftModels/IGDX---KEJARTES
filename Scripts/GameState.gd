@tool
extends Node

## The source of truth for a run.
##
## An autoload. Everything the player does between the main menu and the
## semester end lands here: the approved roster, the week's schedules, the
## current week and grade, money, and the inventory. The run is saved by
## SaveGame (SaveGame.SAVE_KEYS lists the fields it carries, EXCLUDED the
## ones it leaves out); this script holds the state and does no file I/O.
##
## Written by: StudentCard.gd (approves the roster into
## `approved_students`), AturJadwal.gd (fills `day_schedules`),
## StudentManager.write_back_to_gamestate() (pushes simulated stats back
## after each day), Koperasi.gd and Cart (`player_money`, `inventory`), and
## DebugManager (every field, on purpose -- that is what the debug overlay
## is for).
##
## Read by: every screen.
##
## The roster: `approved_students` holds Array[Dictionary] whose stat keys
## (`akademis`, `seni_budaya`, `olahraga`, `mood`, `energy`) are the same
## names as StudentData's fields. convert_to_student_data_array() bridges in
## and StudentManager.write_back_to_gamestate() bridges out.

# Scene navigation
var next_scene: String = "res://Scenes/MainMenu/MainMenu.tscn"

# Student selection state (from student_card)
var returned_from_student_card: bool = false
var approved_students: Array = []  # Array of Dictionary (reference format)
var selected_student: Dictionary = {}
var selected_day: String = ""

# Jadwal storage: day_schedules[student_id][day_name] = {category, mood_cost, energy_cost}
var day_schedules: Dictionary = {}

## Per-week tally of skill points each student has gained from minigame WINS,
## student_id -> float. Enforces Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_*.
## Cleared at week start (SchoolDay.start_simulation) and on grade change
## (reset_roster_for_new_grade). Saved with the run (SaveGame).
var minigame_gain_this_week: Dictionary = {}

## How many items the Koperasi shelf shows -- one per Barang* slot on
## Koperasi.tscn's Stage.
const SHOP_SHELF_SIZE: int = 6
## The most copies of one item a week's shelf can hold.
const SHOP_MAX_COPIES: int = 3
## The week the Koperasi shelf was rolled for, as shop_week_key_for(); ""
## until the first visit. Saved with the run (SaveGame).
var shop_week_key: String = ""
## Item names on the Koperasi shelf this week, in slot order. An item can
## fill up to SHOP_MAX_COPIES slots.
var shop_stock: Array[String] = []
## Item names bought this week, one entry per unit. An item sells once per
## copy on the shelf.
var shop_sold: Array[String] = []

## The discount steps a weekly promo can roll, in percent. Ours to tune
## (Balance.gd is a collaborator's); one is picked per (grade, week).
const PROMO_DISCOUNTS: Array[int] = [15, 20, 25, 30]
## Percent to fraction.
const PERCENT_SCALE: float = 100.0

## This week's promo item -- one name from shop_stock -- and its discount in
## percent. Both derived from the (grade, week) key in shop_stock_for_week();
## "" and 0 before a shelf is rolled or when the shelf is empty.
var shop_promo_item: String = ""
var shop_promo_percent: int = 0

# Week tracking
var minggu_ke: int = 1
var max_minggu: int = WEEKS_BY_GRADE[7]
var lobby_tutorial_completed: bool = false
## Debug-menu master switch: true skips every tutorial in the game (lobby,
## atur jadwal, student card, student list, school day, minigames), not just
## the lobby one. Saved with the run (SaveGame).
var tutorials_bypassed: bool = false
## MinigameHowTo resource paths whose CARA MAIN card has shown this run.
## Saved with the run (SaveGame).
var seen_minigame_how_to: Dictionary = {}
## The grades whose headmaster's beat has played this run, grade -> true.
## HeadmasterBeat marks Kelas 8 or 9 when its congratulation ends, so the beat
## plays once per promotion and a retry of the same grade does not replay it.
## Cleared by forget_session() and by set_grade() (a new run starts there).
## Saved with the run (SaveGame), so a resumed run does not replay a beat.
var headmaster_beats_seen: Dictionary = {}
var current_grade: int = 7:
	set(val):
		current_grade = clampi(val, 7, 9)
		max_minggu = get_max_weeks()
var is_game_beaten: bool = false
var debug_level_select_enabled: bool = true

## True when a new game picks its grade on the Level Select (the amplop
## fan) before the intro: once the game is beaten, or while the persisted
## Debug Level Select toggle is on. MainMenu routes on it, and CutScene
## defaults to Kelas 7 when it is false.
func is_level_select_enabled() -> bool:
	return is_game_beaten or debug_level_select_enabled

var grade7_student_ids: Array = []
var grade8_student_ids: Array = []

## Per-grade tally consumed by the run-result screen. Never null; reset by
## set_grade() and by the grade-advance path in RunResult.
var run_stats: RunStats = RunStats.new()

## True once the stat check has decided the run was lost. Read by
## RunResult to force a D grade without re-running the evaluation.
var run_failed: bool = false

## A saved week in progress, handed from SaveGame.load_save() to
## SchoolDay._ready(), which resumes it and empties this. Never saved itself.
var pending_week_resume: Dictionary = {}

## Emitted when a student's worn skin changes (equip_skin, or a debug lock
## that strips it).
signal skin_changed(student_name: String)
## Student name -> skin id they wear. Absent means StudentSkins.DEFAULT_ID.
## Keyed by name, not roster id, so a skin follows the character across
## grades. Saved with the run (SaveGame).
var equipped_skins: Dictionary = {}
## "Name:skin_id" -> unlocked. Absent means StudentSkins.UNLOCKED_BY_DEFAULT.
## Only the debug overlay writes it (set_all_skins_locked).
var skin_unlock_overrides: Dictionary = {}


func equipped_skin(student_name: String) -> String:
	return equipped_skins.get(student_name, StudentSkins.DEFAULT_ID)


func is_skin_unlocked(student_name: String, id: String) -> bool:
	if not StudentSkins.has_skin(student_name, id):
		return false
	if id == StudentSkins.DEFAULT_ID:
		return true
	return skin_unlock_overrides.get("%s:%s" % [student_name, id], StudentSkins.UNLOCKED_BY_DEFAULT)


## Wears skin `id` on `student_name`. False, and nothing changes, when the
## skin is unknown or locked. Re-equipping the worn skin succeeds silently.
func equip_skin(student_name: String, id: String) -> bool:
	if not is_skin_unlocked(student_name, id):
		return false
	if equipped_skin(student_name) == id:
		return true
	if id == StudentSkins.DEFAULT_ID:
		equipped_skins.erase(student_name)
	else:
		equipped_skins[student_name] = id
	skin_changed.emit(student_name)
	return true


## Debug: lock (or unlock) every non-default skin. Locking strips a worn skin
## back to default, so nothing shows art the player could not pick.
func set_all_skins_locked(locked: bool) -> void:
	for n in StudentSkins.NAMES:
		for id in StudentSkins.skins_for(n):
			if id == StudentSkins.DEFAULT_ID:
				continue
			skin_unlock_overrides["%s:%s" % [n, id]] = not locked
			if locked and equipped_skin(n) == id:
				equip_skin(n, StudentSkins.DEFAULT_ID)


## True when set_all_skins_locked(true) is in force.
func all_skins_locked() -> bool:
	for key in skin_unlock_overrides:
		if skin_unlock_overrides[key] == false:
			return true
	return false

## How many school weeks each grade runs (2026-09-29: Kelas 7/8/9 = 4/6/8).
## Ours, not Balance.gd's: that file is collaborator-owned. Its
## JUMLAH_MINGGU_KELAS_* (6/12/16) and TARGET_KENAIKAN_KELAS_* (15/34/40) are
## no longer read by anything -- the weeks and the targets they were paired
## with move together, so both live here.
const WEEKS_BY_GRADE := {7: 4, 8: 6, 9: 8}

## Points every skill must gain over its base to clear each grade, sized for
## WEEKS_BY_GRADE. Kelas 8 and 9 were 34 and 40 for 12 and 16 weeks; on 6 and
## 8 weeks those were unwinnable (a well-played roster never cleared), and
## 22 / 26 put the clear at week 5 of 6 and week 7 of 8, as tight as before.
## Kelas 7 keeps 15 and clears at week 2 of 4. tests/test_balance_pacing.gd
## simulates it.
const TARGET_UPLIFT_BY_GRADE := {7: 15.0, 8: 22.0, 9: 26.0}


## The weeks `grade` runs; a grade outside 7-9 counts as Kelas 7.
static func weeks_for_grade(grade: int) -> int:
	return WEEKS_BY_GRADE.get(grade, WEEKS_BY_GRADE[7])


## The points every skill must gain to clear `grade`; a grade outside 7-9
## counts as Kelas 7.
static func target_uplift_for_grade(grade: int) -> float:
	return TARGET_UPLIFT_BY_GRADE.get(grade, TARGET_UPLIFT_BY_GRADE[7])


func get_max_weeks() -> int:
	return weeks_for_grade(current_grade)

func get_grade_from_week() -> int:
	return current_grade

func get_grade_name() -> String:
	return "Kelas " + str(current_grade)

func set_grade(grade_num: int) -> void:
	var previous_grade: int = current_grade
	current_grade = grade_num
	minggu_ke = 1
	run_stats.reset()
	run_failed = false
	headmaster_beats_seen = {}
	reset_shop_week()
	if current_grade != previous_grade:
		reset_roster_for_new_grade()  # no-op when the roster is empty
	print("GameState grade set to: Kelas ", current_grade, " (Minggu ", minggu_ke, ", Max Minggu ", max_minggu, ")")

## Rebases every roster student's three skill stats for a new grade: keep
## Balance.KENAIKAN_KELAS_HEAD_START_FRAKSI of the gains made above roster
## base, snap mood/energy to 80, and drop the cached base_* skill keys so
## initialize_grade_targets() recomputes targets from the new baseline.
##
## Called by RunResult._apply_progression() on a real grade advance and by
## set_grade() on a debug grade-jump, so both paths behave identically.
## A no-op when approved_students is empty.
func reset_roster_for_new_grade() -> void:
	if approved_students.is_empty():
		return
	var frac: float = Balance.KENAIKAN_KELAS_HEAD_START_FRAKSI
	var skill_keys := [
		["akademis", "roster_base_akademis"],
		["seni_budaya", "roster_base_seni_budaya"],
		["olahraga", "roster_base_olahraga"],
	]
	for student in approved_students:
		for pair in skill_keys:
			var cur: float = float(student.get(pair[0], 50.0))
			if not student.has(pair[1]):
				student[pair[1]] = cur
			var rbase: float = float(student[pair[1]])
			student[pair[0]] = rbase + frac * maxf(0.0, cur - rbase)
		student["mood"] = 80.0
		student["energy"] = 80.0
		student.erase("base_akademis")
		student.erase("base_seni_budaya")
		student.erase("base_olahraga")
	minigame_gain_this_week.clear()

func initialize_grade_targets() -> void:
	for student in approved_students:
		if not student.has("base_akademis"):
			student["base_akademis"] = student.get("akademis", 50.0)
		if not student.has("base_seni_budaya"):
			student["base_seni_budaya"] = student.get("seni_budaya", 50.0)
		if not student.has("base_olahraga"):
			student["base_olahraga"] = student.get("olahraga", 50.0)
			
		var base_akademis = student["base_akademis"]
		var base_seni_budaya = student["base_seni_budaya"]
		var base_olahraga = student["base_olahraga"]
		
		var uplift := target_uplift_for_grade(current_grade)
		student["target_akademis"] = clampf(base_akademis + uplift, 0.0, 100.0)
		student["target_seni_budaya"] = clampf(base_seni_budaya + uplift, 0.0, 100.0)
		student["target_olahraga"] = clampf(base_olahraga + uplift, 0.0, 100.0)
		print("Initialized targets for student: ", student.get("name", ""), " to [", student["target_akademis"], ", ", student["target_seni_budaya"], ", ", student["target_olahraga"], "]")



# Currency
signal money_changed(new_amount: int)
signal inventory_changed

var _player_money: int = 0

var player_money: int:
	get: return _player_money
	set(value):
		_player_money = value
		money_changed.emit(value)

## Inventory: item_name -> quantity. Saved with the run (SaveGame).
var inventory: Dictionary = {}  ## Tracks item quantities by name

## Wirausaha earnings accrued this week, student_id -> rupiah. Emptied by
## SchoolDay at week end, when the total is paid into player_money.
var pending_earnings: Dictionary = {}
## Ads owed from Dapatkan Uang's "ambil dulu" cash-ins; one watched owed
## ad pays one back. Saved with the run (SaveGame), like money.
var ad_debt: int = 0


func add_to_inventory(item_name: String, quantity: int) -> void:
	inventory[item_name] = inventory.get(item_name, 0) + quantity
	inventory_changed.emit()


func remove_from_inventory(item_name: String, quantity: int = 1) -> bool:
	if not inventory.has(item_name):
		return false
	inventory[item_name] -= quantity
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	inventory_changed.emit()
	return true


func get_inventory_quantity(item_name: String) -> int:
	return inventory.get(item_name, 0)


## Debug/playtest helper: stock one entry per known item so a session can
## exercise the inventory screen without driving the shop purchase flow.
##
## Replaces the inventory rather than adding to it, so repeated calls are
## idempotent, and emits inventory_changed once at the end rather than once
## per item -- listening screens rebuild their grid on that signal.
func seed_playtest_inventory(quantity: int = 2) -> void:
	inventory.clear()
	if quantity > 0:
		for item in ItemDatabase.get_all_items():
			inventory[item.item_name] = quantity
	inventory_changed.emit()


## Forget the stocked week, so the next shop_stock_for_week() rolls a fresh
## shelf with nothing sold and no promo. Every run restart calls this: it
## resets minggu_ke to 1, and without it a retried grade -- or Kelas 7 after
## a loss or after beating the game -- would land on the last run's key.
func reset_shop_week() -> void:
	shop_week_key = ""
	shop_stock = []
	shop_sold = []
	shop_promo_item = ""
	shop_promo_percent = 0


## The key a week's Koperasi shelf is stored under. The grade is part of it
## because a new grade restarts minggu_ke at 1.
static func shop_week_key_for(grade: int, week: int) -> String:
	return "%d-%d" % [grade, week]


## A shelf of `size` names drawn from a bag holding every name
## `max_copies` times, in slot order. Pure, apart from the global RNG
## that shuffle() uses.
static func roll_shop_stock(names: Array[String], size: int, max_copies: int) -> Array[String]:
	var bag: Array[String] = []
	for item_name in names:
		for _copy in range(max_copies):
			bag.append(item_name)
	bag.shuffle()
	var stock: Array[String] = []
	for i in range(mini(size, bag.size())):
		stock.append(bag[i])
	return stock


## This week's promo item: one of the DISTINCT names on `stock`, picked by a
## hash of the (grade, week) key -- not the global RNG, which roll_shop_stock's
## shuffle() advances. Distinct, so a pair on the shelf still advertises one
## item. Sorted before indexing so the pick depends only on which names are on
## the shelf, never on roll_shop_stock's unseeded shuffle() order -- the same
## stock shuffled two different ways must name the same promo item. "" for an
## empty shelf. Pure.
static func promo_item_for(stock: Array[String], grade: int, week: int) -> String:
	var names: Array[String] = []
	for item_name: String in stock:
		if not names.has(item_name):
			names.append(item_name)
	if names.is_empty():
		return ""
	names.sort()
	return names[posmod(hash("promo:" + shop_week_key_for(grade, week)), names.size())]


## This week's discount, one of PROMO_DISCOUNTS, from a differently salted
## hash so the item and the percentage roll independently. Pure.
static func promo_percent_for(grade: int, week: int) -> int:
	var at: int = posmod(hash("pct:" + shop_week_key_for(grade, week)), PROMO_DISCOUNTS.size())
	return PROMO_DISCOUNTS[at]


## Price multiplier for `item_name` under a promo on `promo_item` at `percent`:
## below 1.0 only for the promo item. Pure.
static func promo_multiplier(item_name: String, promo_item: String, percent: int) -> float:
	if item_name == "" or item_name != promo_item:
		return 1.0
	return 1.0 - percent / PERCENT_SCALE


## This week's promo multiplier for `item_name`. Cart.price_of reads it, so the
## shelf tag, the running total and the Beli check all agree.
func shop_promo_multiplier(item_name: String) -> float:
	return promo_multiplier(item_name, shop_promo_item, shop_promo_percent)


## This week's Koperasi shelf. The first call in a (grade, week) rolls
## SHOP_SHELF_SIZE items from ItemDatabase (roll_shop_stock, so a pair can
## turn up) and clears shop_sold; every later call that week returns the
## same items in the same order.
func shop_stock_for_week() -> Array[String]:
	var key := shop_week_key_for(current_grade, minggu_ke)
	if key != shop_week_key:
		shop_week_key = key
		shop_sold = []
		var names: Array[String] = []
		for item in ItemDatabase.get_all_items():
			names.append(item.item_name)
		shop_stock = roll_shop_stock(names, SHOP_SHELF_SIZE, SHOP_MAX_COPIES)
		shop_promo_item = promo_item_for(shop_stock, current_grade, minggu_ke)
		# No item, no percent -- shop_promo_item's own doc promises "" and 0
		# together on an empty shelf; only roll a discount when there is a
		# promo item to hang it on.
		shop_promo_percent = promo_percent_for(current_grade, minggu_ke) if shop_promo_item != "" else 0
	return shop_stock.duplicate()


## Record one unit of `item_name` bought this week. Capped at the copies on
## the shelf (at least one, so an unstocked name still sells once).
func mark_shop_sold(item_name: String) -> void:
	if shop_sold.count(item_name) < maxi(1, shop_stock.count(item_name)):
		shop_sold.append(item_name)


## True when `item_name` was bought this week.
func is_shop_sold(item_name: String) -> bool:
	return shop_sold.has(item_name)


## True once every copy on this week's shelf has been bought. False before
## the shelf is first rolled.
func is_shop_sold_out() -> bool:
	if shop_stock.is_empty():
		return false
	for item_name in shop_stock:
		if shop_sold.count(item_name) < shop_stock.count(item_name):
			return false
	return true


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


## Stat ceiling shared with StudentData's mood/energy range.
const STAT_MAX := 100.0

## Applies an item's boosts to ONE student in approved_students.
##
## The teammate's build had a single global player_mood/player_energy;
## this project tracks both per student, so the caller must say who. The
## approved_students dictionaries are the cross-screen source of truth,
## so that is what gets written: the roster keys `mood`, `energy`,
## `akademis`, `seni_budaya` and `olahraga`, the names StudentData uses.
##
## Returns {"applied": bool, "mood_delta","energy_delta","akademis_delta",
## "seni_delta","olahraga_delta": float} — five deltas, each the amount that
## actually landed after clamping, which is what the inventory's floating
## stat-pop labels display.
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary:
	var refused := {"applied": false, "mood_delta": 0.0, "energy_delta": 0.0,
		"akademis_delta": 0.0, "seni_delta": 0.0, "olahraga_delta": 0.0}
	if item == null or quantity <= 0:
		return refused
	if get_inventory_quantity(item.item_name) < quantity:
		return refused

	var target: Dictionary = {}
	for student in approved_students:
		if student.get("id", -1) == student_id:
			target = student
			break
	if target.is_empty():
		return refused

	var fields := [
		["mood",        item.mood_boost,        "mood_delta"],
		["energy",      item.energy_boost,      "energy_delta"],
		["akademis",    item.akademis_boost,    "akademis_delta"],
		["seni_budaya", item.seni_budaya_boost, "seni_delta"],
		["olahraga",    item.olahraga_boost,    "olahraga_delta"],
	]
	var out := {"applied": true}
	for f in fields:
		var before: float = float(target.get(f[0], 0.0))
		var after := clampf(before + float(f[1]) * quantity, 0.0, STAT_MAX)
		target[f[0]] = after
		out[f[2]] = after - before

	remove_from_inventory(item.item_name, quantity)
	run_stats.record_item_use(quantity)
	return out


## Applies one copy of `item` to each id in `student_ids` (one application
## each; quantity is fixed at 1 per student). All-or-nothing: if the stack
## cannot cover every id, nothing is applied and "applied" is false. The stock
## and id-existence pre-checks below make a partial application unreachable, so
## `applied` mirrors `not results.is_empty()`.
## Returns {"applied": bool, "results": Array} where each result is
## {"student_id": int, "name": String, "mood_delta","energy_delta",
##  "akademis_delta","seni_delta","olahraga_delta": float}.
func use_item_on_students(item: ItemData, student_ids: Array) -> Dictionary:
	if item == null or student_ids.is_empty():
		return {"applied": false, "results": []}
	if get_inventory_quantity(item.item_name) < student_ids.size():
		return {"applied": false, "results": []}
	for sid in student_ids:
		var found := false
		for s in approved_students:
			if s.get("id", -1) == sid:
				found = true
				break
		if not found:
			return {"applied": false, "results": []}
	var results: Array = []
	for sid in student_ids:
		var sname := ""
		for s in approved_students:
			if s.get("id", -1) == sid:
				sname = str(s.get("name", ""))
				break
		var r := use_item(item, sid, 1)
		if r["applied"]:
			r.erase("applied")
			r["student_id"] = sid
			r["name"] = sname
			results.append(r)
	return {"applied": not results.is_empty(), "results": results}

var daily_login_day: int = 1
var last_claim_date: String = ""

func _ready():
	print("GameState siap")

## Saves when the window closes or the app goes to the background on a hub
## screen, where no scene change is coming to checkpoint it: a phone may kill
## a backgrounded app without warning. Mid-week and in the end-of-grade
## chain the last checkpoint stands (SaveGame.save_if_at_hub).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		var current := get_tree().current_scene if is_inside_tree() else null
		SaveGame.save_if_at_hub(current.scene_file_path if current else "")

# --- Converter: Dictionary → StudentData (for simulation) ---
## One roster entry as a simulation StudentData. The single conversion rule:
## convert_to_student_data_array() and the item screen's student cards both
## go through here, so a student can never be converted two different ways.
func student_data_from_dict(dict: Dictionary) -> StudentData:
	var sd = StudentData.new()
	sd.id = dict.get("id", 0)
	sd.student_name = dict.get("name", "")
	sd.akademis = dict.get("akademis", 50.0)
	sd.seni_budaya = dict.get("seni_budaya", 50.0)
	sd.olahraga = dict.get("olahraga", 50.0)
	sd.mood = dict.get("mood", 80.0)
	sd.energy = dict.get("energy", 80.0)

	# 0.0, not 50.0: count_targets_cleared() reads the same three keys
	# with a 0.0 default, and the two sides of the bridge must agree on
	# what an uninitialized target looks like. See target_cleared().
	sd.target_akademis = dict.get("target_akademis", 0.0)
	sd.target_seni_budaya = dict.get("target_seni_budaya", 0.0)
	sd.target_olahraga = dict.get("target_olahraga", 0.0)
	sd.target_mood = dict.get("target_mood", 50.0)
	sd.target_energy = dict.get("target_energy", 50.0)
	sd.quirk = dict.get("quirk", "")
	sd.persona = dict.get("persona", "")
	sd.personality = dict.get("personality", "Santai")
	sd.profil = dict.get("profil", "")
	sd.splash_path = StudentSkins.splash_for(dict)

	var port_path := StudentSkins.portrait_for(dict)
	if port_path != "" and ResourceLoader.exists(port_path):
		sd.avatar_texture = load(port_path)

	# Map hobby_category: "Akademik" → "Akademis"
	var hobby = dict.get("hobby_category", "")
	sd.specialty_category = "Akademis" if hobby == "Akademik" else hobby
	sd.record_initial_stats()
	return sd


func convert_to_student_data_array() -> Array[StudentData]:
	var result: Array[StudentData] = []
	for dict in approved_students:
		result.append(student_data_from_dict(dict))
	return result

# Get jadwal for a day across all approved students
func get_jadwal_for_day(day_name: String) -> Dictionary:
	# Returns {category_name: count} for weighted minigame selection
	var counts = {"Akademis": 0, "Olahraga": 0, "SeniBudaya": 0, "Istirahat": 0, "Wirausaha": 0}
	for student in approved_students:
		var sid = student.get("id", null)
		if sid != null and day_schedules.has(sid):
			var cat = day_schedules[sid].get(day_name, {}).get("category", "")
			# Normalize: "Akademis" → "Akademis", "Istirahat" → "Istirahat"
			if cat == "Akademis": cat = "Akademis"
			elif cat == "Istirahat": cat = "Istirahat"
			if counts.has(cat):
				counts[cat] += 1
	return counts

## The run's star meter, 0.0 to Balance.STARS_TOTAL: every academic target
## cleared anywhere on the roster earns an equal share of the three stars.
## Continuous on purpose -- StatCheck's meter fills star by star as the
## check plays, and 7 of 12 must read as 1.75, not "1".
func run_stars() -> float:
	var counted: Array = count_targets_cleared()
	var total := int(counted[1])
	if total <= 0:
		return 0.0
	return Balance.STARS_TOTAL * float(counted[0]) / float(total)


## Win rule since Plan A: the star meter at or above
## Balance.STAR_WIN_THRESHOLD. Replaces "every student clears all three
## targets" -- one weak student on a strong roster no longer loses the run.
## An empty roster still passes, as it always did, so a debug teleport with
## nothing approved never reads as a loss.
func check_semester_passed() -> bool:
	if approved_students.is_empty():
		return true
	return run_stars() >= Balance.STAR_WIN_THRESHOLD


## Counts how many of the roster's three-per-student academic targets have
## been cleared, as [cleared, total]. RunGrade's dominant scoring
## component -- kept here rather than in RunResult because it reads the
## approved_students dictionaries, which are this file's own concern.
func count_targets_cleared() -> Array:
	var cleared := 0
	var total := 0
	for student in approved_students:
		var pairs := [
			["akademis", "target_akademis"],
			["seni_budaya", "target_seni_budaya"],
			["olahraga", "target_olahraga"],
		]
		for pair in pairs:
			total += 1
			if target_cleared(float(student.get(pair[0], 0.0)),
					float(student.get(pair[1], 0.0))):
				cleared += 1
	return [cleared, total]


## The one predicate for "this stat cleared its target", shared by the
## verdict (count_targets_cleared, and so run_stars and
## check_semester_passed) and by the reveal (StatCheckRow.ratio, which
## reaches 100 on exactly this condition).
##
## A target of zero or less is NOT cleared. Targets are only ever zero when
## initialize_grade_targets() never ran, which is a data bug -- and the two
## sides used to disagree about it: this function's `value >= target` read a
## missing target as cleared while the bar filled to 0%, so a malformed
## roster could show an empty star meter and still route to the win screen.
## Failing an uninitialized target keeps the meter and the verdict telling
## the same story.
static func target_cleared(value: float, target: float) -> bool:
	if target <= 0.0:
		return false
	return value >= target
