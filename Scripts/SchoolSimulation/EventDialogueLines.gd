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
			"Sekolah membuka les tambahan sepulang sekolah. Aku mau ikut, boleh, kan, Pak?",
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
			"...Kelas les biasanya sepi, ya? Aku suka belajar kalau tenang. Boleh ikut, Pak?",
			"...Aku duduk di belakang saja. Boleh aku ikut les tambahan, Pak?",
			"...Ada soal yang tidak berani kutanyakan di kelas. Di les, mungkin aku berani. Boleh ikut, Pak?",
			"...Aku lebih suka belajar sendiri. Tapi bab bangun ruang butuh penjelasan. Boleh aku ikut, Pak?",
			"...Aku mau soal latihan untuk dibawa pulang juga. Boleh aku ikut les, Pak?",
		],
		"Shinta": [
			"Pekerjaan rumahku dikurangi kalau aku ikut les, ya? Eh, serius, Pak, boleh aku ikut?",
			"Les sore ada camilannya, kan, Pak? Kalau ada, aku mau ikut. Boleh?",
			"Materinya sih sudah kukuasai, Pak. Tapi siapa tahu gurunya butuh asisten. Boleh aku ikut?",
			"Daripada tidur siang di rumah, lebih baik tidur di kelas les, kan? Bercanda! Boleh, Pak?",
			"Aku ikut les, Bapak traktir es teh. Adil, kan? Ya sudah, gratis saja. Boleh ikut, Pak?",
		],
		"Thea": [
			"Nilai ulanganku kurang dua poin dari sempurna, Pak. Boleh aku ikut les untuk mengejarnya?",
			"Soal cerita kemarin kuulang tiga kali, tapi masih ada yang salah. Boleh aku ikut les, Pak?",
			"Tanganku pegal menyalin rumus, tapi aku belum puas. Bolehkah aku berlatih lagi di les, Pak?",
			"Sekali lagi saja, Pak. Boleh aku mengulang materi tadi di les sampai benar-benar paham?",
			"Aku sudah menyiapkan buku latihan baru khusus untuk les. Boleh kupakai sore ini, Pak?",
		],
	},
	"Menjodohkan": {
		"Marcel": [
			"Tenang, Pak. Materi ini sudah kucatat semalam. Kita jodohkan satu per satu.",
			"Kartu jawaban kubaca dulu semuanya, Pak. Setelah itu baru kucari soalnya.",
			"Jawaban kartu ini ada di halaman dua belas buku catatanku. Aku masih ingat, Pak.",
			"Asal teliti, setiap kartu pasti mendapat pasangannya, Pak.",
			"Yang paling mudah kita pasangkan dulu, Pak. Yang sulit belakangan saja.",
		],
		"Doni": [
			"Kartu soal dan jawabannya tercampur semua! Bantu aku menjodohkannya sebelum waktunya habis.",
			"Balapan melawan jam, Pak! Setiap detik berharga, aku enggak boleh kalah!",
			"Satu pasang, satu poin! Ayo, Pak, kita kumpulkan skor sebanyak-banyaknya!",
			"Meleset satu? Enggak masalah! Aku enggak kenal kata menyerah, Pak!",
			"Anggap saja kartu ini lawan tanding! Pasangannya pasti kutemukan, Pak!",
		],
		"Andi": [
			"Pak, kenapa kartunya bisa berantakan begini? Jangan-jangan ada yang iseng!",
			"Kalau kartu-kartu ini bisa bicara, pasti mereka sedang mencari pasangannya, ya, Pak?",
			"Kartu soal ini kuanggap kunci, jawabannya gemboknya. Ayo cari yang pas, Pak!",
			"Aku penasaran, kartu mana yang paling sulit dicari pasangannya?",
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
			"Teman sebangkuku masih bingung di kartu pertama, Pak. Aku sudah hampir selesai!",
			"Aku pasangkan semuanya, tapi nanti pulang lebih cepat, ya, Pak? Setuju?",
			"Kartu ini jawabannya... ah, gampang. Sudah, Pak, kartu berikutnya!",
			"Santai saja, Pak. Aku justru paling cepat kalau waktunya sudah hampir habis.",
		],
		"Thea": [
			"Semua pasangan harus benar, Pak. Satu salah saja, aku ulang dari awal.",
			"Kalau ada yang kuragukan, aku tandai dulu, Pak. Nanti kuperiksa lagi di akhir.",
			"Kartunya terus berputar, Pak. Tidak apa-apa, aku sudah terbiasa tetap fokus.",
			"Aku tidak mau asal pasang, Pak. Cepat itu bagus, tapi tepat lebih penting!",
			"Mataku sampai perih menghafal soal pengetahuan umum. Sekarang saatnya membuktikan, Pak!",
		],
	},
	"Variabel": {
		"Marcel": [
			"Ini persamaan sederhana, Pak. Cari dulu nilai satu benda, sisanya akan menyusul.",
			"Aku sudah membaca bab aljabar sampai habis. Persamaan begini tidak asing lagi.",
			"Izinkan aku menyalin soalnya ke buku catatan dulu, Pak. Aku lebih teliti kalau ditulis.",
			"Kalau dua buku jumlahnya delapan, satu buku berapa? Itu dulu yang kucari, Pak.",
			"Setiap jawaban harus kita masukkan kembali ke persamaan awal. Begitu cara yang benar.",
		],
		"Doni": [
			"Ayo bertanding, benda-benda! Hari ini kalian lawanku!",
			"Berhitung bukan keahlianku, tapi aku enggak takut! Ayo, Pak, serang!",
			"Kalau pensilnya ketemu, satu benda tumbang! Tinggal sisanya, Pak!",
			"Siapa cepat, dia menang! Aku tebak lebih dulu, Pak, penghapusnya lima!",
			"Kepalaku panas, tapi pantang mundur! Tinggal sedikit lagi, Pak!",
		],
		"Andi": [
			"Ada teka-teki angka di kartu ini. Kira-kira berapa nilai tiap bendanya, ya?",
			"Pak, kenapa soalnya pakai pensil dan penggaris? Mirip kode rahasia mata-mata!",
			"Kalau nilai bukunya diganti, apa nilai benda yang lain ikut berubah, ya?",
			"Aku bayangkan penghapus ini lebih mahal daripada buku. Nanti kita cek, benar tidak, ya?",
			"Wah, jangka ditambah busur! Bisa jadi alat gambar ajaib, Pak!",
		],
		"Citra": [
			"...Biar aku hitung di kertas dulu. Diam-diam saja.",
			"...Aku mulai dari benda yang paling gampang ditebak. Tinggal dicek.",
			"...Kelasnya ramai sekali. Aku kerjakan pelan-pelan di mejaku saja, ya, Pak.",
			"...Aku suka soal begini. Tidak perlu bicara, cukup berpikir.",
			"Pak... nilai jangkanya sudah kutemukan. Tapi jangan bilang siapa-siapa dulu, ya.",
		],
		"Shinta": [
			"Tiap benda nilainya seratus. Selesai! Bercanda, Pak, aku hitung sungguhan, deh.",
			"Gampang, Pak. Cari benda yang berdiri sendiri dulu, sisanya ikut. Yang lain masih menghitung, ya?",
			"Semua kupecahkan asal istirahatnya ditambah, ya, Pak? Tawaran bagus, kan?",
			"Siapa sih yang menulis soal ini? Tulisannya miring semua. Tapi, oke, aku kerjakan.",
			"Santai saja, Pak. Teka-teki begini biasa kukerjakan sambil makan camilan.",
		],
		"Thea": [
			"Sudah kuhitung dua kali, Pak. Tapi biar pasti, aku hitung sekali lagi.",
			"Aku berlatih soal seperti ini tiap malam. Sekarang pasti bisa!",
			"Satu jawaban meleset, semuanya ikut salah. Aku mau teliti sampai akhir.",
			"Coretanku sudah penuh satu halaman, Pak. Jawabannya harus rapi sampai akhir!",
			"Hasilnya harus pas, bukan kira-kira. Ayo, Pak, kita periksa bersama!",
		],
	},
	"PilihanGanda": {
		"Marcel": [
			"Aku tidak khawatir, Pak. Materinya sudah kuulang tadi malam.",
			"Semua pilihan kubaca dulu sebelum menjawab. Jawaban yang tergesa-gesa sering keliru.",
			"Namaku kutulis dulu di pojok kertas, Pak. Baru setelah itu soalnya kukerjakan.",
			"Soal ini pernah muncul di buku latihanku. Aku masih ingat jawabannya, Pak.",
			"Boleh aku pinjam pensil cadangan, Pak? Ujung pensilku patah karena terlalu bersemangat mencatat.",
		],
		"Doni": [
			"Oke, anggap saja kuis ini pertandingan. Aku enggak mau kalah!",
			"Tiga soal, tiga babak! Babak pertama, aku menang!",
			"A, B, C, atau D? Aku pilih yang paling berani! Eh, maksudku yang paling benar!",
			"Waktu tinggal sedikit? Justru di sini aku paling semangat, Pak!",
			"Nilai sempurna atau tidak sama sekali! Ayo, Pak, dukung aku dari pinggir lapangan!",
		],
		"Andi": [
			"Kenapa kuisnya selalu mendadak, Pak? Biar kami kaget, ya?",
			"Kalau semua pilihannya kelihatan benar, bagaimana cara memilihnya, ya?",
			"Aku bayangkan tiap pilihan itu pintu. Cuma satu yang ada hadiahnya!",
			"Pak, benarkah pilihan yang paling panjang biasanya jawaban yang benar? Aku penasaran.",
			"Wah, soal ini ada gambarnya! Aku jadi pengin tahu siapa yang membuatnya.",
		],
		"Citra": [
			"...Tanganku dingin. Tapi jawabannya sudah ada di kepalaku.",
			"...Sudah kulingkari semua. Aku tidak mau menyontek, kok.",
			"...Soal tentang Indonesia, ya. Aku suka membaca atlas sendirian di perpustakaan.",
			"...Ada satu yang agak sulit. Tapi aku tidak akan menyerah.",
			"Pak... boleh aku duduk di dekat jendela? Aku lebih tenang di sana.",
		],
		"Shinta": [
			"Kuisnya gampang, Pak. Jawabannya pasti C semua. Bercanda!",
			"Tiga soal? Sedikit sekali. Tambah dua lagi pun aku sanggup, Pak.",
			"Pak, kalau nilaiku sempurna, kuis berikutnya aku bebas, ya? Tawaran menarik, kan?",
			"Aku jawab sambil santai, ya. Otakku bekerja paling baik kalau tidak tegang.",
			"Soal pertama selesai, soal kedua selesai... eh, sudah habis? Cepat sekali.",
		],
		"Thea": [
			"Kuis dadakan! Tiga soal pilihan ganda. Aku pasti bisa!",
			"Soal nomor dua kubaca ulang tiga kali. Aku tidak mau salah paham.",
			"Jawabanku sudah terisi, tapi biar kuperiksa sekali lagi, Pak.",
			"Dua dari tiga belum cukup buatku. Semuanya harus benar!",
			"Jariku pegal karena menulis latihan semalaman. Tapi rasanya siap sekali!",
		],
	},
	"Password": {
		"Marcel": [
			"Kita jumlahkan angkanya dengan teliti, Pak, seperti di buku latihan.",
			"Buku-buku pelajaran kita tersimpan di lemari kelas. Aku harus membukanya, Pak.",
			"Tolong tunggu sebentar, Pak. Aku tulis dulu hitungannya di buku catatan.",
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
			"Seperti peti harta bajak laut, ya, Pak? Kuncinya hitungan yang benar!",
			"Siapa sih yang pertama kali menciptakan kunci angka? Aku penasaran.",
			"Angka ganjil atau genap, ya, jawabannya? Aku tebak ganjil! Ayo kita coba, Pak!",
		],
		"Citra": [
			"...Biar aku yang menghitung. Aku lebih teliti kalau tidak ditonton.",
			"...Aku suka lemari ini. Tidak ada yang bisa membukanya dengan asal tebak.",
			"...Lemarinya terkunci. Tapi angka tidak pernah bohong.",
			"...Jangan terburu-buru. Salah sekali, kesempatannya hilang.",
			"Pak... jawabannya sudah kutulis di kertas. Bapak saja yang memasukkan, ya.",
		],
		"Shinta": [
			"Lemari kelas cuma terbuka kalau hitungannya benar. Ayo kita hitung bersama!",
			"Bagaimana kalau lemarinya kita ketuk saja, Pak? Siapa tahu dibukakan. Bercanda!",
			"Camilan di dalam lemari boleh kuambil satu kalau terbuka, ya, Pak?",
			"Hitungannya sudah beres, Pak. Aku cuma pura-pura bingung supaya seru.",
			"Santai, santai. Angka sekecil ini sih bisa kuhitung sambil menguap.",
		],
		"Thea": [
			"Aku hitung sekali lagi, Pak. Jangan sampai lemarinya terkunci gara-gara aku.",
			"Latihan menjumlah tiap pagi akhirnya berguna juga, Pak!",
			"Setiap digit kuperiksa satu per satu. Sia-sia kalau meleset sedikit saja.",
			"Coretan hitunganku sudah rapi, tidak ada angka yang tertukar, Pak!",
			"Ada penjumlahan, ada pengurangan juga. Keduanya sudah kulatih, Pak!",
		],
	},
	"Badminton": {
		"Marcel": [
			"Aturan bulu tangkis sudah kubaca, Pak. Siapa yang lebih dulu mencapai skor yang ditentukan, dialah pemenangnya.",
			"Menurut buku olahraga, genggaman raket jangan terlalu kaku. Akan kucoba, Pak.",
			"Arah kok akan kuperhitungkan dengan cermat supaya melewati raket lawan.",
			"Olahraga memang bukan keahlianku, Pak. Tapi aku akan bermain dengan sungguh-sungguh.",
			"Rekor laju kok tercepat lebih dari 400 kilometer per jam. Semoga lawanku tidak secepat itu.",
		],
		"Doni": [
			"Raketku sudah siap dari tadi. Ayo bertanding badminton, siapa takut?",
			"Lawan di seberang net, bersiaplah! Poin pertama milikku!",
			"Kebobolan satu poin? Aku balas dengan dua poin, Pak!",
			"Dari pagi aku menunggu saat ini! Lapangan bulu tangkis, aku datang!",
			"Pak, perhatikan pukulanku! Lawan pasti kewalahan!",
		],
		"Andi": [
			"Pak, kenapa bola bulu tangkis dibuat dari bulu? Supaya bisa terbang, ya?",
			"Kalau kok ini burung kecil, tugasku menerbangkannya ke sarang lawan!",
			"Aku penasaran, lawanku sudah berlatih berapa lama, ya, Pak?",
			"Bagaimana kalau raket ini kuanggap pedang kesatria? Lawanku jadi naganya!",
			"Wah, lapangannya hijau sekali, Pak! Garis putihnya mirip jalan di peta kota.",
		],
		"Citra": [
			"...Aku lebih suka main tanpa penonton. Tapi aku siap, Pak.",
			"...Raketnya ringan. Pas di tanganku.",
			"...Sudah pemanasan sejak tadi. Tidak usah khawatir, Pak.",
			"...Poin demi poin. Pelan-pelan saja.",
			"Pak... kalau aku menang, jangan diumumkan keras-keras, ya.",
		],
		"Shinta": [
			"Lawanku main pakai tangan kiri saja, ya, Pak? Bercanda! Ayo mulai.",
			"Badminton sambil duduk boleh, Pak? Enggak boleh, ya? Ya sudah, aku berdiri.",
			"Aku menang, besok bebas piket kelas, ya, Pak? Diam berarti setuju!",
			"Tenang, Pak. Raketnya cukup kugeser sedikit, koknya pasti kembali ke lawan.",
			"Kata orang aku malas berolahraga. Tunggu saja, siapa yang tertawa paling akhir.",
		],
		"Thea": [
			"Pergelangan tanganku masih pegal dari latihan kemarin, tapi aku tetap mau main, Pak.",
			"Pukulanku tadi pagi masih meleset. Boleh aku pemanasan sekali lagi, Pak?",
			"Setiap pukulan harus terarah. Aku tidak mau mengembalikan kok sembarangan.",
			"Seminggu ini aku berlatih memukul kok ke tembok setiap sore, Pak.",
			"Selisih skornya harus jauh, Pak. Menang tipis belum cukup buatku!",
		],
	},
	"BuatBatik": {
		"Marcel": [
			"Urutannya sudah kucatat, Pak: pensil, canting, pewarna, lalu kompor.",
			"Menurut buku sejarahku, setiap 2 Oktober kita memperingati Hari Batik Nasional.",
			"Kainnya masih polos, Pak. Sketsanya akan kubuat serapi halaman buku catatanku.",
			"Setiap alat ada keterangannya, Pak. Akan kubaca dulu sebelum kupakai.",
			"Kata buku prakaryaku, malam berguna menahan pewarna supaya motifnya tetap terang.",
		],
		"Doni": [
			"Membatik melawan waktu? Nah, ini baru pertandingan, Pak!",
			"Tanganku lebih terbiasa memegang bola daripada canting. Tapi aku enggak mau kalah!",
			"Empat alat, empat langkah! Satu per satu kutaklukkan, Pak!",
			"Hore, pelajaran seni! Keringat enggak keluar, tapi semangatku tetap menyala!",
			"Pewarna, tunggu giliranmu! Canting yang maju lebih dulu!",
		],
		"Andi": [
			"Pak, kenapa kompornya dipakai paling akhir? Ayo kita coba, biar tahu!",
			"Aku membayangkan motif naga bersayap di kain ini. Seru, kan, Pak?",
			"Malam itu lilin, ya, Pak? Berarti kain ini dihias seperti kue ulang tahun!",
			"Siapa, ya, orang pertama yang punya ide melukis kain dengan lilin? Aku penasaran.",
			"Alat-alatnya diacak! Seperti teka-teki, ya, Pak. Mana yang dipakai lebih dulu?",
		],
		"Citra": [
			"...Membatik tidak perlu banyak bicara. Itu yang kusuka.",
			"...Canting ini mungil. Harus hati-hati memakainya.",
			"...Pensil dulu, lalu canting. Sisanya aku ingat.",
			"...Boleh aku membatik di pojok, Pak? Aku lebih teliti kalau sendirian.",
			"Pak... bau malam yang dipanaskan itu menenangkan, ya.",
		],
		"Shinta": [
			"Batiknya kubuat abstrak saja, ya, Pak? Salah urutan pun tetap jadi seni. Bercanda!",
			"Boleh kainnya kubawa pulang, Pak? Lumayan untuk taplak meja di rumah.",
			"Aduh, pewarnanya pasti bikin tanganku kotor. Ya sudah, demi Bapak, aku lanjut.",
			"Kelihatannya repot, Pak, tapi aku pernah membantu Nenek membatik. Tenang saja.",
			"Kompor ini untuk memanaskan kain, bukan untuk merebus mi, kan? Sayang sekali.",
		],
		"Thea": [
			"Kain, canting, dan pewarna sudah siap. Aku mau membatik, tapi urutannya harus benar!",
			"Tanganku pegal karena membatik dengan canting semalaman, tapi motif ini harus sempurna.",
			"Batik pertamaku dulu luntur, Pak. Sejak itu aku berlatih setiap minggu.",
			"Pola ini sudah kugambar berulang-ulang di kertas. Hari ini sekali lagi, tapi di atas kain!",
			"Warnanya harus meresap sempurna, jadi kompornya jangan sampai terlupa, Pak.",
		],
	},
	"LombaMenari": {
		"Marcel": [
			"Asal-usul beberapa tari daerah sudah kubaca semalam, Pak. Sekarang tinggal praktiknya.",
			"Setiap panah akan kuperhatikan baik-baik sebelum aku menggeser jari, Pak.",
			"Menurut catatanku, ada empat arah: kiri, kanan, serong kiri atas, dan serong kanan atas.",
			"Aku menghitung ketukannya dalam hati, Pak. Satu, dua, tiga, empat.",
			"Baru kali ini aku ikut Festival Budaya, Pak. Semoga aku tidak mempermalukan kelas.",
		],
		"Doni": [
			"Lomba menari sebentar lagi dimulai! Ikuti iramanya dan jangan sampai salah langkah.",
			"Menari itu olahraga juga, kan, Pak? Keringatnya sama! Aku pasti juara!",
			"Satu lagu, satu kesempatan! Skorku harus paling tinggi, Pak!",
			"Sempurna terus! Enggak ada satu panah pun yang boleh lolos!",
			"Kakiku kaku kayak papan, Pak! Tapi pantang menyerah, aku tetap menari!",
		],
		"Andi": [
			"Pak, kenapa panahnya berwarna-warni? Jangan-jangan tiap warna punya gerakan sendiri!",
			"Kalau aku jadi burung merak di festival ini, ekorku pasti paling lebar!",
			"Aku penasaran, tarian mana di Nusantara yang iramanya paling cepat?",
			"Wah, halaman sekolah penuh tenda dan bendera kecil! Meriah sekali, Pak.",
			"Bagaimana kalau tiap gerakan kuberi nama? Yang ini 'Elang Menyapa'!",
		],
		"Citra": [
			"...Penontonnya banyak sekali. Aku lihat panahnya saja.",
			"...Menari di depan orang lebih sulit daripada lari keliling lapangan.",
			"...Jantungku berdebar. Tapi aku sudah janji akan tampil.",
			"...Kalau musiknya saja yang kudengar, rasanya seperti menari sendirian.",
			"Pak... jangan bersorak terlalu keras, ya. Nanti aku malah tidak fokus.",
		],
		"Shinta": [
			"Tukar peran, yuk, Pak. Bapak yang menari, aku yang bertepuk tangan. Bercanda!",
			"Penonton pasti terpukau. Entah karena gerakanku bagus, entah karena lucu.",
			"Satu syarat, Pak: setelah ini aku boleh duduk di bawah tenda sampai festival selesai.",
			"Panah ke kiri, geser ke kiri. Ke kanan, geser ke kanan. Apa susahnya?",
			"Aku jarang latihan, Pak, tapi kakiku selalu bisa menemukan iramanya sendiri.",
		],
		"Thea": [
			"Gerakan ini sudah kulatih sampai kakiku pegal. Ayo, Pak, kita tunjukkan!",
			"Bagus saja belum cukup, Pak. Aku mau setiap langkah sempurna!",
			"Tadi pagi gerakannya kulatih sekali lagi. Sekarang kakiku sudah hafal sendiri.",
			"Iramanya sudah kuhafal dari rekaman, Pak. Kudengarkan tiap malam sebelum tidur.",
			"Tanganku gemetar, Pak. Tapi latihan berminggu-minggu ini sayang kalau disia-siakan.",
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
		"Kuda-kuda yang kukuh, lalu tendang dengan keras! Kiper ini tidak akan memberi ampun.",
		"Baris yang rapi! Satu per satu maju ke titik penalti. Yang gagal, lari satu putaran.",
		"Fokus! Lihat sudut gawang, bukan kipernya. Tendangan yang ragu-ragu pasti tertangkap.",
		"Semua siap? Ambil ancang-ancang, tarik napas, lalu lepaskan tendangan terbaik kalian!",
	],
}

## student name -> {category -> lines}: their thanks on the win screen.
const WIN_STUDENT_LINES := {
	"Marcel": {
		"Akademis": [
			"Persiapan semalam tidak sia-sia, Pak.",
			"Catatanku terbukti berguna, Pak!",
			"Terima kasih atas bimbingannya, Pak.",
			"Semuanya sesuai dengan yang kubaca, Pak.",
			"Hasil hari ini akan kucatat di bukuku.",
		],
		"SeniBudaya": [
			"Seni pun bisa dipelajari dari buku, Pak.",
			"Karya kelas kita rapi sekali, Pak.",
			"Terima kasih sudah sabar mengajari kami.",
			"Halaman seni di catatanku bertambah, Pak.",
			"Ketelitian juga penting dalam seni, Pak.",
		],
		"Olahraga": [
			"Ternyata olahraga juga ada rumusnya, Pak!",
			"Aku sudah membaca strateginya, Pak.",
			"Sudutnya sudah kuhitung di buku, Pak!",
			"Menang berkat persiapan yang matang, Pak.",
			"Akan kutulis di jurnal harianku, Pak.",
		],
	},
	"Doni": {
		"Akademis": [
			"Hore! Otakku ikut berkeringat, Pak!",
			"Soal pun bisa kukalahkan, Pak!",
			"Skor kita paling tinggi, Pak! Menang!",
			"Aku sendiri kaget, Pak! Kita menang!",
			"Hebat! Terima kasih, Pak!",
		],
		"SeniBudaya": [
			"Juara seni juga kita rebut, Pak!",
			"Asyik! Ternyata seni juga seru, Pak!",
			"Lawan berikutnya mana, Pak? Aku siap!",
			"Terima kasih, Pak! Aku makin semangat!",
			"Siapa bilang aku cuma jago lari, Pak?",
		],
		"Olahraga": [
			"Menang telak! Ini memang bidangku, Pak!",
			"Hore! Juara, Pak! Juara!",
			"Keringatku terbayar lunas, Pak!",
			"Besok kita bertanding lagi, ya, Pak!",
			"Enggak ada lawan yang sanggup, Pak!",
		],
	},
	"Andi": {
		"Akademis": [
			"Pak, kenapa menang rasanya seru sekali?",
			"Kalau otakku lampu, sekarang terang, Pak!",
			"Besok ada teka-teki lagi, kan, Pak?",
			"Siapa sih yang membuat soal-soal ini, Pak?",
			"Seperti menemukan harta karun, Pak!",
		],
		"SeniBudaya": [
			"Pak, lain kali boleh lebih aneh lagi?",
			"Kenapa seni selalu bikin aku senang, ya?",
			"Kalau jadi pelangi, kita paling cerah!",
			"Terima kasih! Kepalaku penuh ide, Pak!",
			"Wah, karya kita seperti hidup, Pak!",
		],
		"Olahraga": [
			"Pak, kenapa menang bikin kakiku ringan?",
			"Kalau ini dongeng, kita pahlawannya, Pak!",
			"Bagaimana kalau kita rayakan, Pak?",
			"Wah, jantungku berdebar kayak genderang!",
			"Aku mau jadi atlet saja, Pak! Boleh?",
		],
	},
	"Citra": {
		"Akademis": [
			"...Syukurlah. Aku bisa fokus tadi.",
			"...Aku senang. Terima kasih.",
			"...Ternyata aku bisa juga, Pak.",
			"...Tidak usah dipuji keras-keras, Pak.",
			"...Kelas tenang, pikiranku juga tenang.",
		],
		"SeniBudaya": [
			"...Karya kecil. Tapi aku bangga, Pak.",
			"...Terima kasih. Hari ini menyenangkan.",
			"...Aku suka berkarya dengan tenang, Pak.",
			"...Hatiku hangat. Itu saja, Pak.",
			"...Boleh kucoba lagi kapan-kapan, Pak?",
		],
		"Olahraga": [
			"...Terima kasih sudah percaya, Pak.",
			"...Menang. Pelan-pelan, tapi menang.",
			"...Napasku habis. Tapi rasanya lega.",
			"...Aku tidak menyangka. Tapi aku senang.",
			"...Diam-diam aku bangga, Pak.",
		],
	},
	"Shinta": {
		"Akademis": [
			"Tuh kan, Pak, santai pun bisa menang!",
			"Hadiahnya libur sehari, kan, Pak?",
			"Aku cuma pakai setengah otak. Bercanda!",
			"Boleh tidur siang sekarang, Pak?",
			"Sudah kubilang, soalnya gampang, Pak.",
		],
		"SeniBudaya": [
			"Karya asal-asalan pun menang. Bercanda!",
			"Sambil menguap pun aku bisa, Pak!",
			"Menang, Pak! Traktir es teh, ya?",
			"Pajang karyaku di kelas, ya, Pak?",
			"Sekarang waktunya bersantai, Pak!",
		],
		"Olahraga": [
			"Siapa bilang aku malas? Nah, menang!",
			"Besok aku bebas piket, kan, Pak?",
			"Capek juga, Pak. Bercanda! Seru, kok.",
			"Santai, Pak. Menang itu memang gampang.",
			"Terima kasih, Pak! Boleh aku duduk dulu?",
		],
	},
	"Thea": {
		"Akademis": [
			"Belajar tiap malam ada hasilnya, Pak!",
			"Jariku pegal, tapi semua soal selesai!",
			"Lega sekali, Pak! Terima kasih!",
			"Besok aku mau berlatih sekali lagi, Pak.",
			"Hampir sempurna, Pak! Nanti kuperbaiki.",
		],
		"SeniBudaya": [
			"Latihan berhari-hari terbayar, Pak!",
			"Badanku pegal, tapi hasilnya indah, Pak!",
			"Sekali lagi, Pak? Biar lebih sempurna!",
			"Berkat Bapak, aku berani tampil!",
			"Akhirnya tidak ada yang meleset, Pak!",
		],
		"Olahraga": [
			"Latihan tiap sore tidak sia-sia, Pak!",
			"Lenganku pegal, tapi kita menang, Pak!",
			"Fokusku terjaga sampai akhir, Pak!",
			"Skornya bagus. Besok kuulang sekali lagi!",
			"Aku lega sekali. Terima kasih banyak!",
		],
	},
}

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
