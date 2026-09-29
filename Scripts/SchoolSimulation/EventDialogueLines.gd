@tool
class_name EventDialogueLines
extends RefCounted

## Every variation of every EventDialogue and MinigameWinScreen line
## (2026-09-29 dialogue-variations spec): at least five per speaker per pool,
## in each speaker's own voice, in KBBI-checked Indonesian. Pure data;
## EventDialogueCatalog picks from it and falls back to an entry's own `line`
## when a pool is missing. The lines are drafts for the owner's writer.
##
## Rules every line keeps (tests/test_event_dialogue_lines.gd): ASCII only,
## no chat spellings (nggak, udah, aja...), students say "Pak" and never
## {nama}, CHOICE lines end in "?", event lines <= 120 characters, win lines
## fit two lines of the win bubble.

## event key -> {student name -> lines}. The featured student speaks.
const STUDENT_LINES := {}

## event key -> lines, for the NPC-voiced entries and the Hujan narrator.
## {nama} is the featured student.
const NPC_LINES := {
	"nasi_kotak": [
		"Kudengar {nama} dan teman-temannya sedang bekerja keras, semoga ini dapat menyemangati mereka!",
		"Permisi, Pak Guru. Saya bawakan nasi kotak untuk {nama} dan teman-temannya. Semoga belajarnya makin semangat!",
		"Maaf mengganggu, Pak. Saya khawatir {nama} lupa makan siang lagi, jadi saya masak agak banyak untuk satu kelas.",
		"Pak Guru, tolong pastikan {nama} menghabiskan sayurnya. Lauknya ayam goreng kesukaan anak-anak.",
		"Masih hangat, Pak! Silakan dibagikan kepada {nama} dan kawan-kawannya. Bapak juga ambil satu, ya.",
	],
	"hujan": [
		"Hujan deras sejak pagi membuat jalanan licin. Beberapa murid basah kuyup dan terpeleset di jalan menuju sekolah.",
		"Sejak subuh, gerimis berubah menjadi hujan lebat. Jalan licin, dan seragam banyak murid basah kuyup.",
		"Langit gelap dan hujan tidak kunjung reda. Murid-murid duduk menggigil dengan sepatu basah, lesu sepanjang pagi.",
		"Genangan air ada di mana-mana. Ada murid yang terpeleset di gerbang, dan suasana kelas ikut muram.",
		"Payung tidak banyak membantu melawan angin kencang. Murid-murid tiba kelelahan, dan semangat mereka ikut surut.",
	],
	"latihan_olahraga": [
		"Lapangan sedang kosong sore ini. Bagaimana kalau {nama} dan yang lain ikut latihan tambahan bersamaku?",
		"Pak, sore ini saya melatih lari dan lompat jauh. Boleh {nama} dan yang lain ikut bergabung?",
		"Stamina anak-anak masih kurang, Pak. Bapak izinkan {nama} dan kawan-kawan lari sepuluh putaran sore ini?",
		"Disiplin dibangun dari latihan, Pak. Kalau {nama} dan yang lain siap berkeringat, saya tunggu di lapangan. Setuju?",
		"Pertandingan melawan sekolah lain sudah dekat, Pak. Bisakah {nama} dan yang lain berlatih sepulang sekolah?",
	],
	"workshop_seni": [
		"Sanggar seni sedang mengadakan lokakarya batik dan tari daerah. Boleh {nama} dan teman-temannya ikut bergabung?",
		"Canting dan malam sudah saya siapkan di sanggar, Pak. Tangan kotor sedikit tidak apa-apa. {nama} boleh ikut membatik?",
		"Penari sanggar kami kurang beberapa orang, Pak. Bapak mau meminjamkan {nama} dan teman-temannya sore ini?",
		"Saya yakin {nama} punya bakat seni yang belum terlihat, Pak. Bagaimana kalau kita asah di lokakarya sanggar?",
		"Setiap peserta lokakarya boleh membawa pulang kain batiknya sendiri, Pak. Mau saya daftarkan {nama} dan kawan-kawan?",
	],
	"MainBola": [
		"Ayo latihan adu penalti! Tendang bolanya sekuat tenaga dan jangan sampai ditangkap kiper!",
		"Kuda-kuda yang kokoh, lalu tendang dengan keras! Kiper ini tidak akan memberi ampun.",
		"Baris yang rapi! Satu per satu maju ke titik penalti. Yang meleset, lari satu putaran.",
		"Fokus! Lihat sudut gawang, bukan kipernya. Tendangan yang ragu-ragu pasti tertangkap.",
		"Siap semuanya? Ini bukan main-main. Arahkan bola ke pojok bawah, jangan beri kiper kesempatan!",
	],
}

## student name -> {category -> lines}: their thanks on the win screen.
const WIN_STUDENT_LINES := {}

## category -> lines: the subject teacher's thanks on the win screen
## ("Olahraga" is Guru Penjas, "SeniBudaya" is Guru Seni Budaya).
const WIN_TEACHER_LINES := {
	"Olahraga": [
		"Kerja bagus! Latihannya berhasil.",
		"Lumayan. Besok kita latihan lebih pagi!",
		"Tidak buruk. Lari satu putaran lagi!",
		"Disiplin kalian terbayar. Pertahankan!",
		"Itu baru kerja tim! Bubar, jalan!",
	],
	"SeniBudaya": [
		"Indah sekali! Terima kasih sudah membimbing mereka.",
		"Lihat karya mereka, Pak. Cantik, bukan?",
		"Hebat! Saya bangga sekali pada mereka.",
		"Bakat mereka mulai bersinar, Pak!",
		"Sanggar kita punya bintang baru!",
	],
}
