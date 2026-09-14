@tool
class_name EventDialogueCatalog
extends RefCounted

## Every EventDialogue line, speaker and backdrop (2026-09-14 event-dialogue
## spec), keyed by random-event key or by minigame scene file name. Pure data
## and small helpers: SchoolDay picks the entry and the featured student, and
## EventDialogue dresses itself from them.
##
## The lines are drafts for the owner's writer (CLAUDE.md, copy
## placeholders). `{nama}` becomes the featured student's name.

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


## The speaker's texture path: the featured student's splash for
## SPEAKER_STUDENT, the fixed art otherwise, "" for none.
static func splash_path_for(e: Dictionary, featured: StudentData) -> String:
	var speaker: String = e.get("speaker", "")
	if speaker == SPEAKER_STUDENT:
		return "" if featured == null else featured.splash_path
	return speaker
