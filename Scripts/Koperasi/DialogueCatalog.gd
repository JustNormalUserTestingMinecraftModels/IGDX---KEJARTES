@tool
class_name DialogueCatalog
extends RefCounted

## Static line pool for Pak Herman in the Koperasi. Voice: warung banter
## between two adults on school grounds, addressing the male teacher as
## `Pak` / `Pak Guru`. Anti-repetition avoids the exact same line twice
## in a row per event (and, cheaply, per item for ITEM_LINES).
##
## Every catalog pool is non-empty and every line is <= 60 characters
## (bubble length guard, `tests/test_koperasi_chat_bubble.gd`).
##
## Lines are copied verbatim from
## docs/superpowers/specs/2026-09-17-koperasi-polish-design.md, section
## "2. Contextual dialogue bubble" -- that spec is authoritative for copy.
## Every ITEM_LINES key is checked against ItemDatabase.get_all_items() by
## the same suite, so a renamed item loses its quips loudly, not silently.

## event (StringName) -> pool of lines for that event. See koprasi.gd and
## ChatBubble.gd for who fires which event.
const LINES := {
	# Scene entry
	&"WELCOME": [
		"Selamat datang, Pak Guru~ mau beli apa?",
		"Eh, Pak Guru! mari-mari, dipilih dulu",
		"Wih kebetulan lagi sepi, liat-liat dulu aja",
		"Mari Pak, Bapak baru buka nih~",
		"Wih, langganan Bapak! masuk masuk~",
		"Nyari apa hari ini? bilang aja santai",
		"Habis ngajar ya Pak? capek pasti…",
		"Silakan Pak Guru, Bapak siap layani~",
		"Bapak lagi baik hati loh, mumpung~",
	],

	# Item added to cart (generic)
	&"ADD": [
		"Pilihan bagus, Pak~",
		"Mantaap! Bapak bungkus ya",
		"Ada lagi yang mau~?",
		"Wih selera guru emang beda…",
		"Sip, satu masuk keranjang!",
		"Oke oke, dicatet ya~",
		"Nah gitu dong, jangan cuma nengok",
		"Bapak setuju sama pilihannya!",
		"Tuh kan, akhirnya milih juga~",
		"Bagus~ yang lain nyusul kan?",
		"Wih, mata Pak jeli ya!",
	],

	# Item removed from cart (hold-to-return)
	&"REMOVE": [
		"Loh… yakin dikembalikan?",
		"Yah dibalikin, padahal bagus loh~",
		"Oke oke, taruh lagi… Bapak nggak marah kok",
		"Nggak jadi ya? ya udaah~",
		"Ganti pikiran? wajar wajar…",
		"Loh kok balik? baru juga masuk!",
		"Hemat ya Pak? boleh boleh~",
		"Sabar… Bapak sabar aja",
		"Ya udah, taruh baik-baik ya",
		"Nunggu gajian dulu? Bapak paham kok…",
	],

	# Tapped an item that is now sold out this week
	&"OUT_OF_STOCK": [
		"Yah itu habis, minggu depan ya…",
		"Telat Pak! udah diambil orang tuh",
		"Kosong yang itu~ coba yang sebelah",
		"Ludes dari tadi pagi loh…",
		"Rezekinya orang lain, Pak~",
		"Habis! Bapak juga heran, laku banget",
	],

	# Purchase succeeded
	&"THANKS": [
		"Terima kasih Pak Guru~!",
		"Semoga bermanfaat buat kelasnya ya!",
		"Mengajar yang semangat yaa~",
		"Nanti balik lagi ya, Bapak tunggu…",
		"Alhamdulillah, laris~",
		"Duitnya Bapak simpen dulu ya!",
		"Hati-hati ke kelas Pak~",
		"Nah gini dong, langganan sejati!",
		"Rejeki nggak ke mana~ makasih ya",
	],

	# Beli pressed with empty cart
	&"EMPTY": [
		"Loh keranjangnya masih kosong, Pak…",
		"Belum ada yang dipilih, Bapak jual apa?",
		"Mau bayar apa? angin??",
		"Kosong melompong~ milih dulu dong",
		"Loh beli apa? Bapak bingung nih…",
		"Nol koma nol! ayo pilih dulu",
	],

	# Beli pressed but not enough coins
	&"POOR": [
		"Waduh koinnya kurang… nunggu tunjangan dulu?",
		"Belum cukup nih~ kurangi satu?",
		"Duitnya belum sampai, Bapak nggak kasih utang!",
		"Tunjangan belum cair ya Pak?",
		"Bapak bukan bank sekolah loh~",
		"Kurang dikit… tapi tetep kurang",
		"Balik lagi kalo dompet udah gemuk yaa~",
		"Sabar~ gaji guru bulan depan lagi kan",
	],

	# Sticky, whole week
	&"SOLD_OUT": [
		"Stok habis~ datang lagi minggu depan ya",
		"Ludes semua Pak… minggu depan ya",
		"Toko kosong~ Bapak juga mau pulang nih",
	],

	# Idle chatter
	&"IDLE": [
		"Kok diem aja? Bapak tungguin loh…",
		"Milih yang mana~? Bapak bantu?",
		"Beli sini lebih murah daripada Indomaret depan~",
		"Kelasnya rame ya hari ini?",
		"Yang mahal belum tentu enak~ yang murah juga",
		"Bapak dulu hampir jadi guru loh!",
		"Dagangan Bapak nggak gigit kok~",
		"Woi, bangun woi!!",
		"Haloo? bumi memanggil Pak~",
		"Bapak udah keriput nungguin nih…",
		"Ini toko, bukan ruang guru ya~",
		"Murid Pak nakal ya? sabar sabar…",
		"Ngelamun mulu, nanti kesambet loh~",
		"Bapak juga mau pulang nih…",
		"Kalo bingung, tutup mata aja terus tunjuk~",
		"Jam segini belum balik? rajin banget!",
		"Rapotnya udah kelar belum sih~?",
		"Bapak nggak bayar listrik buat Pak diem loh",
		"Anginnya masuk gratis, barangnya nggak~",
		"Guru lain udah pada bayar loh~",
		"Kopi dulu Pak? eh… nggak jual",
		"Sekolah lagi ngirit ya? Bapak juga…",
	],
}

## Item-specific quips, keyed by ItemData.item_name. Fallback to ADD lines
## when an item has no entry -- add sparingly, one or two per item is
## enough to feel authored. Every key here must be a real
## ItemDatabase.get_all_items() name.
const ITEM_LINES := {
	"Bank Soal": [
		"Wih Pak, ngasih tes dadakan ya?",
		"Murid pasti panik liat ini~",
		"Bocoran? bukan bukan, latihan doang…",
		"Isinya soal tahun lalu, aman kok!",
	],
	"Komik": [
		"Loh, Pak Guru baca komik juga?",
		"Buat hadiah murid rajin ya~",
		"Jangan dibaca pas ngajar Pak…",
		"Bapak juga koleksi loh, diem-diem~",
	],
	"LKS": [
		"PR wajib nih, murid ngeluh pasti…",
		"Klasik~ LKS emang nggak pernah mati",
		"Bapak dulu benci ini, sekarang jualin",
		"Isinya banyak, murid pusing, Pak senang~",
	],
	"Lompat Tali": [
		"Buat olahraga pagi ya Pak?",
		"Awas keseleo~ Bapak nggak nanggung",
		"Anak sekarang mah males gerak, cocok ini!",
		"Warna-warni, biar semangat lompatnya~",
	],
	"Raket": [
		"Wih, mau tanding sama guru lain?",
		"Pinjeman kakak kelas nih, masih enak kok",
		"Awas senarnya putus, Pak…",
		"Buat pelajaran olahraga? sip banget~",
	],
	"Cilok": [
		"Jajan wajib jam istirahat nih~",
		"Bumbunya nendang! Bapak jamin",
		"Kenyel kenyel~ ati-ati keselek ya",
		"Murid Pak juga suka nih, sogokan halus?",
	],
	"Mie Instan": [
		"Sarapan guru, klasik~",
		"Ngoreksi tugas sambil ngemil ini enak Pak",
		"3 menit doang, cocok buat jam kosong",
		"Awas darah tinggi Pak, jangan tiap hari…",
	],
	"Pop Ice": [
		"Panas-panas gini emang paling enak~",
		"Warnanya norak, rasanya lumayan!",
		"Buat nyogok murid biar diem, ampuh nih",
		"Manisnya nendang, awas gula darah Pak…",
	],
	"Susu Kotak": [
		"Biar fokus pas jam pelajaran pagi~",
		"Tinggi, pinter, kata iklan sih…",
		"Dingin, seger, pas buat siang bolong!",
		"Bapak juga minum ini, biar awet muda~",
	],
}

## Per-event index of the line last returned by pick(), so a re-roll can
## avoid repeating it.
static var _last_index: Dictionary = {}
## Per-item-name index of the line last returned by pick_for_item()'s
## ITEM_LINES branch, same purpose as _last_index.
static var _last_item_index: Dictionary = {}

## A line for `event`, never the same as the previous pick for that same
## event when the pool has more than one line. "" when the pool is empty
## or unknown.
static func pick(event: StringName) -> String:
	var pool: Array = LINES.get(event, [])
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return pool[0]
	var last: int = _last_index.get(event, -1)
	var idx: int = randi() % pool.size()
	if idx == last:
		idx = (idx + 1) % pool.size()
	_last_index[event] = idx
	return pool[idx]

## Like pick(), but for &"ADD" on an item with its own ITEM_LINES pool --
## falls back to pick(event) for every other event, and for an ADD on an
## item with no quips of its own.
static func pick_for_item(event: StringName, item_name: String) -> String:
	if event == &"ADD" and ITEM_LINES.has(item_name):
		var pool: Array = ITEM_LINES[item_name]
		if pool.is_empty():
			return pick(event)
		if pool.size() == 1:
			return pool[0]
		var last: int = _last_item_index.get(item_name, -1)
		var idx: int = randi() % pool.size()
		if idx == last:
			idx = (idx + 1) % pool.size()
		_last_item_index[item_name] = idx
		return pool[idx]
	return pick(event)
