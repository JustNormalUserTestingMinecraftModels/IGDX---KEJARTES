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
const STUDENT_LINES := {
	"les_akademis": {
		"Marcel": [
			"Sekolah membuka les tambahan sepulang sekolah. Aku mau ikut, boleh kan?",
			"Catatan pecahanku masih bolong di beberapa halaman. Boleh aku ikut les sore ini, Pak?",
			"Bab berikutnya sudah kubaca, Pak. Boleh aku ikut les untuk menanyakan bagian yang sulit?",
			"Perpustakaan tutup pukul tiga. Daripada langsung pulang, bolehkah aku ikut les, Pak?",
			"Les sore ini pas dengan jadwal belajarku, Pak. Apakah Bapak mengizinkan aku ikut?",
		],
		"Doni": [
			"Teman-teman sekelas ikut les tambahan semua! Masa aku ketinggalan? Boleh aku ikut, Pak?",
			"Ulangan kemarin aku kalah telak! Kali ini aku mau berlatih di les tambahan. Boleh, Pak?",
			"Otak juga perlu dilatih kayak otot, kan? Boleh aku ikut les tambahan sore ini, Pak?",
			"Soal pecahan itu belum bisa kukalahkan! Boleh aku ikut les supaya menang, Pak?",
			"Semangatku masih penuh walau sudah sore! Bagaimana, Pak, boleh aku ikut les?",
		],
		"Andi": [
			"Pak, kenapa namanya les 'tambahan'? Apa yang ditambah? Boleh aku ikut supaya tahu?",
			"Kalau di les nanti ada soal yang tidak ada di buku, seru dong! Boleh aku ikut, Pak?",
			"Pertanyaanku di kelas tadi belum habis. Boleh kubawa semuanya ke les sore ini, Pak?",
			"Bagaimana kalau les ini kuanggap petualangan mencari harta karun? Boleh aku ikut, Pak?",
			"Katanya guru les suka memberi teka-teki angka. Benar, Pak? Kalau begitu, boleh aku ikut?",
		],
		"Citra": [
			"...Les sore biasanya sepi, kan? Aku suka belajar kalau tenang. Boleh ikut, Pak?",
			"...Aku duduk di belakang saja. Boleh aku ikut les tambahan, Pak?",
			"...Ada soal yang tidak berani kutanyakan di kelas. Boleh aku bawa ke les nanti, Pak?",
			"...Aku lebih suka belajar sendiri. Tapi soal pecahan ini butuh penjelasan. Boleh aku ikut, Pak?",
			"...Kalau ada soal latihan untuk dibawa pulang, aku mau. Boleh aku ikut les, Pak?",
		],
		"Shinta": [
			"Kalau aku ikut les, pekerjaan rumahku dikurangi, ya? Eh, serius, Pak, boleh aku ikut?",
			"Les sore ada camilannya, kan, Pak? Kalau ada, aku mau ikut. Boleh?",
			"Materinya sih sudah kukuasai, Pak. Tapi siapa tahu gurunya butuh asisten. Boleh aku ikut?",
			"Daripada tidur siang di rumah, lebih baik tidur di kelas les, kan? Bercanda! Boleh, Pak?",
			"Aku ikut les, Bapak traktir es teh. Adil, kan? Ya sudah, gratis saja. Boleh ikut, Pak?",
		],
		"Thea": [
			"Nilai ulanganku kurang dua poin dari sempurna, Pak. Boleh aku ikut les untuk mengejarnya?",
			"Soal cerita kemarin kuulang tiga kali, tapi masih ada yang salah. Boleh aku ikut les, Pak?",
			"Tanganku pegal menyalin rumus, tapi aku belum puas. Boleh aku ikut les sore ini, Pak?",
			"Sekali lagi saja, Pak. Boleh aku mengulang materi tadi di les sampai benar-benar paham?",
			"Aku sudah menyiapkan buku latihan baru khusus untuk les. Bapak mengizinkan aku ikut, kan?",
		],
	},
	"Menjodohkan": {
		"Marcel": [
			"Tenang, Pak. Materi ini sudah kucatat semalam. Kita jodohkan satu per satu.",
			"Kartu jawaban kubaca dulu semuanya, Pak. Setelah itu baru kucari soalnya.",
			"Jawaban kartu ini ada di halaman dua belas buku catatanku. Aku masih ingat, Pak.",
			"Waktunya memang sempit, tapi kalau teliti, tidak ada kartu yang salah pasang.",
			"Kartu yang paling mudah kita pasangkan dulu, Pak. Yang sulit belakangan saja.",
		],
		"Doni": [
			"Kartu soal dan jawabannya tercampur semua! Bantu aku menjodohkannya sebelum waktunya habis.",
			"Balapan melawan jam, Pak! Setiap detik berharga, aku enggak boleh kalah!",
			"Satu pasang, satu poin! Ayo, Pak, kita kumpulkan skor sebanyak-banyaknya!",
			"Salah pasang? Coba lagi! Aku enggak kenal kata menyerah, Pak!",
			"Anggap saja kartu ini lawan tanding! Pasangannya pasti kutemukan, Pak!",
		],
		"Andi": [
			"Pak, kenapa kartunya bisa tercampur begini? Jangan-jangan ada yang sengaja mengacaknya!",
			"Kalau kartu-kartu ini bisa bicara, pasti mereka sedang mencari pasangannya, ya, Pak?",
			"Kartu soal ini kuanggap kunci, jawabannya gemboknya. Ayo cari yang pas, Pak!",
			"Aku penasaran, kartu mana yang paling sulit dicari pasangannya? Ayo kita cari tahu, Pak!",
			"Wah, ada kartu tentang wayang! Nanti ceritakan asal-usulnya, ya, Pak?",
		],
		"Citra": [
			"...Biar aku yang memasangkan. Lebih cepat kalau sendiri.",
			"...Waktunya sempit. Tapi aku tidak panik, Pak.",
			"...Jangan terlalu ramai, ya. Aku butuh tenang untuk mencocokkan kartunya.",
			"...Satu sudah berpasangan. Masih banyak lagi, tapi aku bisa.",
			"Pak... kalau aku salah pasang, jangan ditertawakan, ya?",
		],
		"Shinta": [
			"Kartunya tercampur? Bukan aku yang mengacaknya, kok, Pak. Bercanda!",
			"Kalau aku selesai duluan, sisa waktunya boleh kupakai untuk tidur, ya, Pak? Bercanda!",
			"Aku pasangkan semuanya, tapi nanti pulang lebih cepat, ya, Pak? Setuju?",
			"Kartu ini jawabannya... ah, gampang. Sudah, Pak, kartu berikutnya!",
			"Tenang, Pak. Aku justru paling cepat kalau waktunya sudah hampir habis.",
		],
		"Thea": [
			"Semua pasangan harus benar, Pak. Satu salah saja, aku ulang dari awal.",
			"Kalau ada satu yang ragu, aku tandai dulu, Pak. Nanti kuperiksa lagi sebelum waktunya habis.",
			"Kartunya harus berjajar rapi dulu, Pak. Aku susah berpikir kalau berantakan.",
			"Waktunya sempit, tapi aku tidak mau asal pasang. Rapi dan benar, dua-duanya!",
			"Mataku sampai perih menghafal pasangan soal semalam. Sekarang saatnya membuktikan, Pak!",
		],
	},
	"Variabel": {
		"Marcel": [
			"Ini persamaan sederhana, Pak. Cari dulu nilai satu benda, sisanya akan menyusul.",
			"Aku sudah membaca bab aljabar sampai habis. Soal seperti ini tidak asing lagi.",
			"Izinkan aku menyalin soalnya ke buku catatan dulu, Pak. Aku lebih teliti kalau ditulis.",
			"Buku ditambah buku sama dengan delapan. Jadi, satu buku bernilai empat, Pak.",
			"Setiap jawaban harus kita masukkan kembali ke persamaan awal. Begitu cara yang benar.",
		],
		"Doni": [
			"Soal ini menantangku! Oke, benda-benda ini lawanku hari ini!",
			"Hitung-hitungan bukan keahlianku, tapi aku enggak takut! Ayo, Pak, serang!",
			"Pensil sama dengan tiga? Ya! Satu benda tumbang, tinggal sisanya!",
			"Siapa cepat, dia menang! Aku tebak duluan, Pak, penghapusnya lima!",
			"Kepalaku panas, tapi pantang mundur! Satu benda lagi, Pak!",
		],
		"Andi": [
			"Ada teka-teki angka di kartu ini. Kira-kira berapa nilai tiap bendanya, ya?",
			"Pak, kenapa soalnya pakai pensil dan penggaris? Mirip kode rahasia mata-mata!",
			"Kalau nilai bukunya diganti, apa nilai benda yang lain ikut berubah, ya?",
			"Aku bayangkan tiap benda ini menyimpan angka rahasia. Tinggal kita intip, Pak!",
			"Wah, ini seperti memecahkan sandi! Ayo, Pak, kita buka satu per satu.",
		],
		"Citra": [
			"...Biar aku hitung di kertas dulu. Diam-diam saja.",
			"...Rautannya dua. Aku cukup yakin.",
			"...Kelasnya ramai sekali. Boleh aku kerjakan sambil menunduk saja, Pak?",
			"...Aku suka soal begini. Tidak perlu bicara, cukup berpikir.",
			"Pak... nilai jangkanya sudah kutemukan. Tapi jangan bilang siapa-siapa dulu, ya.",
		],
		"Shinta": [
			"Tiap benda nilainya seratus. Selesai! Bercanda, Pak, aku hitung sungguhan, deh.",
			"Gampang, Pak. Bukunya enam, pulpennya dua. Sekarang aku boleh ke kantin, kan?",
			"Kalau aku bisa memecahkan semuanya, istirahatnya ditambah, ya, Pak? Tawaran bagus, kan?",
			"Siapa sih yang menulis soal ini? Tulisannya miring semua. Tapi, oke, aku kerjakan.",
			"Santai saja, Pak. Teka-teki begini biasa kukerjakan sambil makan camilan.",
		],
		"Thea": [
			"Sudah kuhitung dua kali, Pak. Tapi biar pasti, aku hitung sekali lagi.",
			"Aku berlatih soal seperti ini tiap malam. Sekarang pasti bisa!",
			"Kalau nilai satu benda meleset, semuanya ikut salah. Aku mau teliti sampai akhir.",
			"Coretanku sudah penuh satu halaman, Pak. Sedikit lagi jawabannya kutemukan!",
			"Hasilnya harus pas, bukan kira-kira. Ayo, Pak, kita periksa bersama!",
		],
	},
	"PilihanGanda": {
		"Marcel": [
			"Kuis dadakan pun tidak masalah, Pak. Materinya sudah kuulang tadi malam.",
			"Semua pilihan kubaca dulu sebelum menjawab. Jawaban yang tergesa-gesa sering keliru.",
			"Aku akan menandai jawabanku dengan rapi, lalu memeriksanya sekali lagi dari atas, Pak.",
			"Soal kedua ini pernah muncul di buku latihanku. Aku masih ingat jawabannya, Pak.",
			"Boleh aku pinjam pensil cadangan, Pak? Ujung pensilku patah karena terlalu bersemangat mencatat.",
		],
		"Doni": [
			"Kuis dadakan? Oke, anggap saja ini pertandingan. Aku enggak mau kalah!",
			"Tiga soal, tiga babak! Babak pertama, aku menang!",
			"A, B, C, atau D? Aku pilih yang paling berani! Eh, maksudku yang paling benar!",
			"Waktu tinggal sedikit? Justru di sini aku paling semangat, Pak!",
			"Nilai sempurna atau tidak sama sekali! Ayo, Pak, dukung aku dari pinggir lapangan!",
		],
		"Andi": [
			"Kuis dadakan? Kenapa selalu mendadak, Pak? Biar kami kaget, ya?",
			"Kalau semua pilihannya kelihatan benar, bagaimana cara memilihnya, ya?",
			"Aku bayangkan tiap pilihan itu pintu. Cuma satu yang ada hadiahnya!",
			"Pak, benarkah pilihan yang paling panjang biasanya jawaban yang benar? Aku penasaran.",
			"Wah, soal ini ada gambarnya! Aku jadi pengin tahu siapa yang membuatnya.",
		],
		"Citra": [
			"...Aku kerjakan sendiri saja. Lebih tenang begitu.",
			"...Jawabanku sudah kulingkari. Aku tidak mau menyontek, kok.",
			"Pak... soal sejarah begini aku suka. Dulu sering kubaca sendirian di perpustakaan.",
			"...Soal kedua agak sulit. Tapi aku tidak akan menyerah.",
			"Pak... boleh aku duduk di dekat jendela? Aku lebih tenang di sana.",
		],
		"Shinta": [
			"Kuis dadakan? Tenang, Pak, jawabannya pasti C. Bercanda!",
			"Tiga soal? Sedikit sekali. Tambah dua lagi pun aku sanggup, Pak.",
			"Pak, kalau nilaiku sempurna, kuis berikutnya aku bebas, ya? Tawaran menarik, kan?",
			"Aku jawab sambil santai, ya. Otakku bekerja paling baik kalau tidak tegang.",
			"Soal pertama selesai, soal kedua selesai... eh, sudah habis? Cepat sekali.",
		],
		"Thea": [
			"Kuis dadakan! Tiga soal pilihan ganda. Aku pasti bisa!",
			"Soal nomor dua kubaca ulang tiga kali. Aku tidak mau salah paham.",
			"Jawabanku sudah terisi, tapi biar kuperiksa sekali lagi, Pak.",
			"Semuanya harus benar. Dua dari tiga belum cukup buatku.",
			"Jariku pegal karena menulis latihan semalaman. Tapi rasanya siap sekali!",
		],
	},
	"Password": {
		"Marcel": [
			"Kita jumlahkan angkanya dengan teliti, Pak. Satu salah hitung, lemarinya tetap terkunci.",
			"Buku-buku pelajaran kita ada di dalam lemari itu. Aku harus membukanya, Pak.",
			"Aku biasa menghitung di kertas coretan dulu. Tolong tunggu sebentar, Pak.",
			"Penjumlahan bersusun sudah kupelajari sejak kelas dua. Ini pasti bisa.",
			"Satuan dulu, baru puluhan. Jangan lupa angka yang disimpan, Pak.",
		],
		"Doni": [
			"Lemari ini menantangku, Pak! Siapa yang menang, aku atau gemboknya?",
			"Bola voli kita dikunci di lemari itu! Hitungannya harus benar, Pak!",
			"Satu soal salah? Enggak apa-apa, soal berikutnya pasti kurebut!",
			"Hitung cepat, buka cepat! Aku mau mencetak rekor membuka lemari tercepat!",
			"Hore! Angka pertama benar! Tinggal sisanya, Pak, ayo semangat!",
		],
		"Andi": [
			"Pak, kenapa lemarinya dikunci pakai hitungan? Isinya pasti rahasia besar!",
			"Kalau hitungannya salah, apa lemarinya bakal marah, Pak?",
			"Lemari ini seperti peti harta bajak laut, ya, Pak? Kuncinya hitungan yang benar!",
			"Siapa sih yang pertama kali menciptakan kunci angka? Aku penasaran.",
			"Kalau jawabannya angka ganjil, apa lemarinya terbuka lebih lebar, Pak? Ayo kita coba!",
		],
		"Citra": [
			"...Biar aku yang menghitung. Aku lebih teliti kalau tidak ditonton.",
			"...Jumlahnya dua puluh tujuh. Coba masukkan, Pak.",
			"...Lemarinya terkunci. Tapi angka tidak pernah bohong.",
			"...Jangan terburu-buru. Salah sekali, kesempatannya hilang.",
			"Pak... jawabannya sudah kutulis di kertas. Bapak saja yang memasukkan, ya.",
		],
		"Shinta": [
			"Lemari kelas cuma terbuka kalau hitungannya benar. Ayo kita hitung bersama!",
			"Bagaimana kalau lemarinya kita ketuk saja, Pak? Siapa tahu dibukakan. Bercanda!",
			"Kalau lemarinya terbuka, camilan di dalamnya boleh kuambil satu, ya, Pak?",
			"Hitungannya sudah beres, Pak. Aku cuma pura-pura bingung supaya seru.",
			"Santai, santai. Angka sekecil ini sih bisa kuhitung sambil menguap.",
		],
		"Thea": [
			"Aku hitung sekali lagi, Pak. Jangan sampai lemarinya terkunci gara-gara aku.",
			"Latihan menjumlah tiap pagi akhirnya berguna juga, Pak!",
			"Satu digit salah, semuanya sia-sia. Aku mau periksa angka demi angka.",
			"Coretan hitunganku sudah rapi. Tinggal masukkan kodenya, Pak!",
			"Ada penjumlahan, ada pengurangan juga. Aku sudah melatih dua-duanya, Pak!",
		],
	},
}

## event key -> lines, for the NPC-voiced entries and the Hujan narrator.
## {nama} is the featured student.
const NPC_LINES := {
	"nasi_kotak": [
		"Kudengar {nama} dan teman-temannya sedang bekerja keras, semoga ini dapat menyemangati mereka!",
		"Permisi, Pak Guru. Saya bawakan nasi kotak untuk {nama} dan teman-temannya. Semoga belajarnya makin semangat!",
		"Maaf mengganggu, Pak. Saya khawatir {nama} lupa makan siang lagi, jadi saya memasak agak banyak untuk satu kelas.",
		"Pak Guru, tolong pastikan {nama} menghabiskan sayurnya. Lauknya ayam goreng kesukaan anak-anak.",
		"Masih hangat, Pak! Silakan dibagikan kepada {nama} dan kawan-kawannya. Bapak juga ambil satu, ya.",
	],
	"hujan": [
		"Hujan deras sejak pagi membuat jalanan licin. Beberapa murid basah kuyup dan terpeleset di jalan menuju sekolah.",
		"Sejak subuh hujan tak berhenti. Murid-murid datang dengan sepatu berlumpur, dan pelajaran pertama terasa berat.",
		"Langit gelap dan hujan tidak kunjung reda. Murid-murid duduk menggigil dengan baju lembap dan lesu sepanjang pagi.",
		"Air menggenang di mana-mana. Ada murid yang terpeleset di gerbang, dan suasana kelas ikut muram.",
		"Angin kencang membuat payung tak banyak berguna. Murid-murid tiba kelelahan, dan semangat mereka surut.",
	],
	"latihan_olahraga": [
		"Lapangan sedang kosong sore ini. Bagaimana kalau {nama} dan yang lain ikut latihan tambahan bersamaku?",
		"Pak, sore ini saya mengadakan latihan lari dan lompat jauh. Boleh {nama} dan yang lain ikut?",
		"Stamina anak-anak masih kurang, Pak. Apakah Bapak mengizinkan {nama} dan kawan-kawan lari sepuluh putaran sore ini?",
		"Disiplin dibangun dari latihan, Pak. Kalau {nama} dan yang lain siap berkeringat, saya tunggu di lapangan. Setuju?",
		"Pertandingan melawan sekolah lain sudah dekat, Pak. Bisakah {nama} dan yang lain berlatih sepulang sekolah?",
	],
	"workshop_seni": [
		"Sanggar seni sedang mengadakan lokakarya batik dan tari daerah. Boleh {nama} dan teman-temannya ikut bergabung?",
		"Canting dan malam sudah saya siapkan, Pak. Sedikit kotor tidak apa-apa. Boleh {nama} dan teman-temannya ikut membatik?",
		"Penari sanggar kami kurang beberapa orang, Pak. Bapak mau meminjamkan {nama} dan teman-temannya sore ini?",
		"Saya yakin {nama} punya bakat seni yang belum terlihat, Pak. Bagaimana kalau kita asah di lokakarya sanggar?",
		"Setiap peserta lokakarya boleh membawa pulang kain batiknya sendiri, Pak. Mau saya daftarkan {nama} dan kawan-kawan?",
	],
	"MainBola": [
		"Ayo latihan adu penalti! Tendang bolanya sekuat tenaga dan jangan sampai ditangkap kiper!",
		"Kuda-kuda yang kokoh, lalu tendang dengan keras! Kiper ini tidak akan memberi ampun.",
		"Baris yang rapi! Satu per satu maju ke titik penalti. Yang meleset, lari satu putaran.",
		"Fokus! Lihat sudut gawang, bukan kipernya. Tendangan yang ragu-ragu pasti tertangkap.",
		"Semua siap? Ambil ancang-ancang, tarik napas, lalu lepaskan tendangan terbaik kalian!",
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
		"Disiplin mereka terbayar, Pak. Pertahankan!",
		"Itu baru namanya latihan, Pak!",
	],
	"SeniBudaya": [
		"Indah sekali! Terima kasih sudah membimbing mereka.",
		"Lihat karya mereka, Pak. Cantik, bukan?",
		"Hebat! Saya bangga sekali pada mereka.",
		"Bakat mereka mulai bersinar, Pak!",
		"Besok karya mereka saya pajang di sanggar!",
	],
}
