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
