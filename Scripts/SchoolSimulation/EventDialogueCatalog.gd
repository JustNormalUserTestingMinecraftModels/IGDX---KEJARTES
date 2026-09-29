@tool
class_name EventDialogueCatalog
extends RefCounted

## Every EventDialogue line, speaker and backdrop (2026-09-14 event-dialogue
## spec), keyed by random-event key or by minigame scene file name. Pure data
## and small helpers: SchoolDay picks the entry and the featured student, and
## EventDialogue dresses itself from them.
##
## The lines' variations live in EventDialogueLines (2026-09-29 spec); each
## entry's own "line" is the fallback. {nama} becomes the featured student's name.

## Tap twice to close; no buttons.
const MODE_TAP := "tap"
## Tolak / Terima; taps only finish the line.
const MODE_CHOICE := "choice"

## A `speaker` meaning "the featured student's own splash art".
const SPEAKER_STUDENT := "student"

const ART_DIR := "res://Assets/Images/EventDialogue/"
const DEFAULT_BACKGROUND := ART_DIR + "sekolah_background.jpg"
const HUJAN_BACKGROUND := ART_DIR + "hujan_background.png"
const SPLASH_MOM := ART_DIR + "splash_mom.png"
const SPLASH_GURU_PENJAS := ART_DIR + "splash_gurupenjas.png"
const SPLASH_GURU_SENI := ART_DIR + "splash_gurusenibudaya.png"
const CALENDAR_BADGE := ART_DIR + "calendar_badge.png"

## Stands in for {nama} when there is no roster (debug only).
const NAME_FALLBACK := "murid-murid"

## Chance a won SeniBudaya or Olahraga minigame is thanked by that subject's
## teacher rather than a student (2026-09-25 win-screen spec).
const WIN_TEACHER_CHANCE := 0.5
## What a student says on the win screen when they have no pool of their own
## (EventDialogueLines.WIN_STUDENT_LINES), and the scene's authored default.
const WIN_LINE_STUDENT := "Terima kasih, Pak!"
## The longest an event line may be, in characters: today's longest (Hujan,
## about 113) fits the dialogue box with room to spare.
const MAX_EVENT_LINE_CHARS := 120

## The teacher who may thank the player for each category's win.
const WIN_TEACHER := {"SeniBudaya": SPLASH_GURU_SENI, "Olahraga": SPLASH_GURU_PENJAS}

## The line last drawn from each pool, keyed per pool (pick_line: the event key,
## plus the student's name for a student's own pool; win_line_for: the category
## with the student's name or the teacher's splash), so the next draw skips it.
static var _last_line: Dictionary = {}

## mode: MODE_TAP or MODE_CHOICE. speaker: "" for none, SPEAKER_STUDENT, or a
## texture path. category: the specialty the featured student is picked from
## ("" = anyone). background: a texture path. blur: blur the backdrop.
const ENTRIES := {
	"nasi_kotak": {
		"mode": MODE_TAP, "speaker": SPLASH_MOM, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kudengar {nama} dan teman-temannya sedang bekerja keras, semoga ini dapat menyemangati mereka!",
	},
	"hujan": {
		"mode": MODE_TAP, "speaker": "", "category": "",
		"background": HUJAN_BACKGROUND, "blur": false,
		"line": "Hujan deras sejak pagi membuat jalanan licin. Beberapa murid basah kuyup dan terpeleset di jalan menuju sekolah.",
	},
	"les_akademis": {
		"mode": MODE_CHOICE, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Sekolah membuka les tambahan sepulang sekolah. Aku mau ikut, boleh kan?",
	},
	"latihan_olahraga": {
		"mode": MODE_CHOICE, "speaker": SPLASH_GURU_PENJAS, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Lapangan sedang kosong sore ini. Bagaimana kalau {nama} dan yang lain ikut latihan tambahan bersamaku?",
	},
	"workshop_seni": {
		"mode": MODE_CHOICE, "speaker": SPLASH_GURU_SENI, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Sanggar seni sedang mengadakan workshop batik dan tari daerah. Ajak {nama} dan teman-temannya bergabung, ya!",
	},
	"MainBola": {
		"mode": MODE_TAP, "speaker": SPLASH_GURU_PENJAS, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Ayo latihan adu penalti! Tendang bolanya sekuat tenaga dan jangan sampai ditangkap kiper!",
	},
	"Badminton": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Olahraga",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Raketku sudah siap dari tadi. Ayo tanding badminton, siapa takut?",
	},
	"Menjodohkan": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kartu soal dan jawabannya tercampur semua! Bantu aku menjodohkannya sebelum waktunya habis.",
	},
	"Variabel": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Ada teka-teki angka di papan tulis. Kira-kira berapa nilai tiap simbolnya, ya?",
	},
	"PilihanGanda": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kuis dadakan! Tiga soal pilihan ganda. Aku pasti bisa!",
	},
	"Password": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Lemari kelas cuma terbuka kalau hitungannya benar. Ayo kita hitung bersama!",
	},
	"BuatBatik": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "SeniBudaya",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kain, canting, dan pewarna sudah siap. Aku mau membatik, tapi urutannya harus benar!",
	},
	"LombaMenari": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "SeniBudaya",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Lomba menari sebentar lagi dimulai! Ikuti iramanya dan jangan sampai salah langkah.",
	},
}


## TAP entries the Lobby's Shorten switch never skips: the parent's lunch and
## the rain are scenes in their own right, not minigame intros (2026-09-14
## shorten-dialog spec).
const SHORTEN_KEEPS := ["nasi_kotak", "hujan"]


## True when Shorten skips this entry's dialogue: a TAP entry (there is no
## choice to make) that is not in SHORTEN_KEEPS. An unknown key is never
## skipped.
static func shorten_skips(key: String) -> bool:
	return entry(key).get("mode", "") == MODE_TAP and not SHORTEN_KEEPS.has(key)


## True when `key` has a dialogue. SchoolDay skips the screen otherwise.
static func has_entry(key: String) -> bool:
	return ENTRIES.has(key)


## The entry for `key`, or an empty Dictionary.
static func entry(key: String) -> Dictionary:
	return ENTRIES.get(key, {})


## The catalog key for a minigame scene: its file name, no extension.
static func minigame_key(scene_path: String) -> String:
	return scene_path.get_file().get_basename()


## A random roster student whose specialty is `category`. Any roster student
## when nobody matches or `category` is empty; null for an empty roster.
static func pick_featured(students: Array, category: String) -> StudentData:
	if students.is_empty():
		return null
	var pool: Array = []
	if category != "":
		for s in students:
			if s is StudentData and s.specialty_category == category:
				pool.append(s)
	if pool.is_empty():
		pool = students
	return pool[randi() % pool.size()]


## `line` with {nama} replaced by the featured student's name.
static func fill_line(line: String, featured: StudentData) -> String:
	var who: String = NAME_FALLBACK if featured == null else featured.student_name
	return line.replace("{nama}", who)


## Every line `key`'s speaker may say: the NPC or narrator pool for a
## non-student speaker, the featured student's own pool otherwise, and the
## entry's single `line` when there is no pool. [] for an unknown key.
static func pool_for(key: String, featured: StudentData) -> Array:
	var e: Dictionary = entry(key)
	if e.is_empty():
		return []
	var fallback: Array = [e.get("line", "")]
	if e.get("speaker", "") != SPEAKER_STUDENT:
		return EventDialogueLines.NPC_LINES.get(key, fallback)
	if featured == null:
		return fallback
	var by_student: Dictionary = EventDialogueLines.STUDENT_LINES.get(key, {})
	return by_student.get(featured.student_name, fallback)


## A random line of `pool` other than `last`; a one-line pool repeats, and an
## empty one gives "".
static func draw(pool: Array, last: String) -> String:
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return str(pool[0])
	var fresh: Array = pool.filter(func(l: Variant) -> bool: return str(l) != last)
	if fresh.is_empty():
		fresh = pool
	return str(fresh[randi() % fresh.size()])


## The line EventDialogue shows for `key`: drawn from pool_for without
## repeating the last one, with {nama} filled in.
static func pick_line(key: String, featured: StudentData) -> String:
	var memo: String = key
	if featured != null and entry(key).get("speaker", "") == SPEAKER_STUDENT:
		memo = key + "|" + featured.student_name
	var line: String = draw(pool_for(key, featured), str(_last_line.get(memo, "")))
	_last_line[memo] = line
	return fill_line(line, featured)


## Every thanks the win screen's speaker may say: the category's teacher pool
## when `speaker_path` is that teacher (WIN_TEACHER), the featured student's
## pool for `category` otherwise, and [WIN_LINE_STUDENT] when there is none.
static func win_pool_for(speaker_path: String, category: String, featured: StudentData) -> Array:
	var fallback: Array = [WIN_LINE_STUDENT]
	if speaker_path != "" and speaker_path == WIN_TEACHER.get(category, ""):
		return EventDialogueLines.WIN_TEACHER_LINES.get(category, fallback)
	if featured == null:
		return fallback
	var by_category: Dictionary = EventDialogueLines.WIN_STUDENT_LINES.get(featured.student_name, {})
	return by_category.get(category, fallback)


## The win screen's line: drawn from win_pool_for without repeating the last
## one for the same speaker and category.
static func win_line_for(speaker_path: String, category: String, featured: StudentData) -> String:
	var is_teacher: bool = speaker_path != "" and speaker_path == WIN_TEACHER.get(category, "")
	var memo: String = "win|%s|%s" % [category, speaker_path]
	if not is_teacher and featured != null:
		memo = "win|%s|%s" % [category, featured.student_name]
	var line: String = draw(win_pool_for(speaker_path, category, featured), str(_last_line.get(memo, "")))
	_last_line[memo] = line
	return line


## The featured student's splash on `day_name`: the day outfit on Kamis and
## Jumat (StudentSkins.DAY_OUTFITS) when they wear no skin, their own
## (equipped) look otherwise, "" for nobody.
static func student_splash(featured: StudentData, day_name: String) -> String:
	if featured == null:
		return ""
	return StudentSkins.splash_for_day(featured.student_name, featured.splash_path, day_name)


## The speaker's texture path: the featured student's splash (dressed for
## `day_name`) for SPEAKER_STUDENT, the fixed art otherwise, "" for none.
static func splash_path_for(e: Dictionary, featured: StudentData, day_name: String = "") -> String:
	var speaker: String = e.get("speaker", "")
	if speaker == SPEAKER_STUDENT:
		return student_splash(featured, day_name)
	return speaker


## Who thanks the player on the win screen. Akademis: the featured student.
## SeniBudaya / Olahraga: the subject's teacher when `roll` (0-1) falls under
## WIN_TEACHER_CHANCE or nobody is featured, else the featured student.
static func win_speaker_path(category: String, featured: StudentData, day_name: String, roll: float) -> String:
	var teacher: String = WIN_TEACHER.get(category, "")
	if teacher != "" and (featured == null or roll < WIN_TEACHER_CHANCE):
		return teacher
	return student_splash(featured, day_name)
