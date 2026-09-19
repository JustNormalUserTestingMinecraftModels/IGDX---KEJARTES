@tool
class_name StudentChatterCatalog
extends RefCounted

## Lines the Lobby's students say in their chat bubble (2026-09-19
## student-chatter spec). A student's trait pool is their personality's
## lines plus their quirk's; when their mood or energy is extreme,
## StudentChatterPicker sometimes draws from a STATE_LINES pool instead.
## Reads approved_students dictionaries only: kepribadian1 is MOOD and
## kepribadian2 is ENERGY (StudentData.mood / .energy across the bridge).
## Every line is <= MAX_LINE_CHARS and fits three lines of the bubble
## (tests/test_student_chatter.gd measures it with the real font).

const MAX_LINE_CHARS := 60
## Share of lines drawn from the state pool while a state applies.
const STATE_CHANCE := 0.4
## energy <= this reads as LELAH (and beats any mood state).
const LELAH_ENERGY_MAX := 30.0
## mood <= this reads as BETE.
const BETE_MOOD_MAX := 30.0
## mood >= this reads as SENANG.
const SENANG_MOOD_MIN := 75.0

const PERSONALITY_LINES := {
	"Aktif": [
		"Pak, istirahat nanti main bola yuk!",
		"Duduk terus bikin kaki gatel, Pak…",
		"Pak, boleh lari keliling lapangan dulu?",
		"Aku udah pemanasan dari tadi pagi!",
		"Pelajaran olahraga kapan lagi, Pak?",
		"Semangat, Pak! Hari ini pasti seru!",
		"Pak, aku kuat push-up lima puluh kali loh",
		"Diam itu capek, gerak itu segar!",
	],
	"Tekun": [
		"Pak, PR kemarin sudah aku kerjakan.",
		"Boleh minta soal latihan tambahan, Pak?",
		"Catatanku sudah rapi, Pak. Mau lihat?",
		"Sedikit demi sedikit, lama-lama bisa.",
		"Pak, besok ulangan bab berapa?",
		"Aku ulang materi tadi malam, Pak.",
		"Jadwal belajarku sudah kususun, Pak.",
		"Pelan-pelan asal paham, kan Pak?",
	],
	"Kreatif": [
		"Pak, aku punya ide gambar baru!",
		"Papan tulisnya boleh aku hias, Pak?",
		"Kalau meja ini jadi panggung, seru ya?",
		"Aku lagi bikin lagu, Pak. Mau dengar?",
		"Pak, warna langit hari ini bagus banget.",
		"Coretan di bukuku jadi karakter baru!",
		"Belajar sambil menggambar boleh, Pak?",
		"Inspirasi datang pas lagi bengong, Pak.",
	],
	"Santai": [
		"Santai aja, Pak. Masih lama kok.",
		"Pak, lima menit lagi ya… ngantuk.",
		"Hidup jangan dibawa tegang, Pak~",
		"Nanti juga beres sendiri, Pak.",
		"Pak, kantin buka jam berapa?",
		"Rebahan sebentar boleh kan, Pak?",
		"Tugasnya dikumpul besok aja ya, Pak?",
		"Pelan-pelan, yang penting sampai.",
	],
	"Seni Dalam Kesunyian": [
		"…Pak, kelasnya lagi tenang. Aku suka.",
		"Aku lebih fokus kalau sepi, Pak.",
		"Boleh aku gambar di pojok, Pak?",
		"…Hm? Oh, aku lagi dengar hujan.",
		"Pak, sunyi itu ada suaranya juga.",
		"Aku jarang ngomong, tapi aku dengar.",
		"Garis-garis kecil ini bikin aku tenang.",
		"…Makasih sudah nanya, Pak.",
	],
}

const QUIRK_LINES := {
	"Kutu Buku": [
		"Pak, perpustakaan buka jam berapa?",
		"Buku ini seru banget, Pak. Sudah baca?",
		"Aku pinjam tiga buku lagi minggu ini.",
		"Satu bab lagi… habis itu aku dengar, Pak.",
		"Kacamataku berembun kena uap teh, Pak.",
		"Ada buku referensi tambahan, Pak?",
		"Bau buku baru itu enak ya, Pak.",
		"Pak, catatan kaki itu bagian favoritku.",
	],
	"Penyendiri": [
		"Aku di sini aja ya, Pak.",
		"Kerja kelompok… harus ya, Pak?",
		"Rame banget hari ini… capek.",
		"Pak, aku boleh kerjain sendiri?",
		"Aku bukan sombong, cuma butuh waktu.",
		"Pojok kelas ini tempat favoritku.",
		"Istirahat nanti aku di perpus aja.",
		"Kalau berdua masih oke kok, Pak.",
	],
	"Semangat Juang": [
		"Aku nggak akan nyerah, Pak!",
		"Kalah kemarin? Hari ini balas!",
		"Pak, kasih aku tantangan paling susah!",
		"Jatuh sekali, bangun dua kali!",
		"Target minggu ini harus tembus, Pak!",
		"Capek itu tanda lagi berjuang, Pak.",
		"Siapa bilang aku nggak bisa? Lihat aja!",
		"Ayo, Pak! Kelas kita pasti lulus!",
	],
	"Penasaran": [
		"Pak, kenapa langit warnanya biru?",
		"Itu isinya apa, Pak? Boleh lihat?",
		"Pak, kalau semut jatuh, sakit nggak?",
		"Aku mau coba sendiri, biar tahu!",
		"Pak, dulu Bapak suka bolos nggak?",
		"Kok bisa begitu, Pak? Jelasin dong.",
		"Tombol ini fungsinya apa ya, Pak?",
		"Di ruang guru ada rahasia apa, Pak?",
	],
	"Biang Onar": [
		"Bukan aku, Pak! Sumpah bukan aku!",
		"Kapurnya hilang? Hehe, nggak tahu, Pak.",
		"Ada kecoak di laci, Pak! Eh, bercanda.",
		"Kalau bosan, kelas harus diramaikan!",
		"Pak, aku cuma pinjam, nanti dibalikin.",
		"Tenang, Pak. Kali ini aku anak baik.",
		"Ups… itu jatuh sendiri, Pak.",
		"Hukumannya bisa ditawar, Pak?",
	],
	"Pekerja Keras": [
		"Pak, ada tugas lagi? Aku siap.",
		"Sedikit lagi selesai, Pak!",
		"Aku lembur nyelesaiin proyekku, Pak.",
		"Kerja keras nggak pernah bohong.",
		"Pak, boleh bantu beresin kelas?",
		"Tanganku pegal, tapi hasilnya puas.",
		"Satu lagi, habis itu baru istirahat.",
		"Pak, aku mau hasil yang terbaik.",
	],
}

const STATE_LINES := {
	&"LELAH": [
		"Pak… aku ngantuk berat…",
		"Energiku tinggal sedikit, Pak.",
		"Boleh istirahat dulu, Pak? Lemes…",
		"Mataku berat banget, Pak…",
		"Kayaknya aku butuh tidur siang.",
		"Capek, Pak… jadwalnya padat banget.",
	],
	&"BETE": [
		"Lagi nggak mood, Pak…",
		"Hari ini rasanya suram, Pak.",
		"Pak, boleh jangan belajar dulu?",
		"Hmph. Lagi kesel aja.",
		"Semua kerasa berat hari ini…",
		"Pak, hiburan dong… bosen.",
	],
	&"SENANG": [
		"Hari ini aku senang banget, Pak!",
		"Pak, aku lagi semangat-semangatnya!",
		"Rasanya pengen nyanyi, Pak!",
		"Kelas ini paling seru deh, Pak.",
		"Makasih ya, Pak! Aku lagi happy.",
		"Mood-ku lagi bagus nih, Pak!",
	],
}

## Fallback for a student whose personality and quirk are both unknown.
const GENERIC_LINES := [
	"Pagi, Pak Guru!",
	"Pak, hari ini belajar apa?",
	"Aku siap belajar, Pak.",
	"Pak, kapan pulang?",
	"Hehe, halo Pak.",
	"Pak, kelas kita keren ya?",
]


## The student's personality key in PERSONALITY_LINES, or "" when unknown.
## Prefers `personality`; falls back to `persona` minus its "Persona "
## prefix, where Citra's "Pendiam" means "Seni Dalam Kesunyian".
static func personality_of(student: Dictionary) -> String:
	var p := str(student.get("personality", ""))
	if PERSONALITY_LINES.has(p):
		return p
	var persona := str(student.get("persona", "")).replace("Persona ", "").strip_edges()
	if persona == "Pendiam":
		return "Seni Dalam Kesunyian"
	return persona if PERSONALITY_LINES.has(persona) else ""


## LELAH / BETE / SENANG, or &"" for a student feeling ordinary. Energy
## (kepribadian2) is checked first: exhaustion is the more urgent read.
static func state_for(student: Dictionary) -> StringName:
	var mood := float(student.get("kepribadian1", 50))
	var energy := float(student.get("kepribadian2", 50))
	if energy <= LELAH_ENERGY_MAX:
		return &"LELAH"
	if mood <= BETE_MOOD_MAX:
		return &"BETE"
	if mood >= SENANG_MOOD_MIN:
		return &"SENANG"
	return &""


## Personality lines + quirk lines, or GENERIC_LINES when both are unknown.
static func trait_pool(student: Dictionary) -> Array:
	var pool: Array = []
	pool.append_array(PERSONALITY_LINES.get(personality_of(student), []))
	pool.append_array(QUIRK_LINES.get(str(student.get("quirk", "")), []))
	return pool if not pool.is_empty() else GENERIC_LINES
