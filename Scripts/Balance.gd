@tool
## Balance.gd — semua angka yang menentukan murid lulus atau tidak.
##
## Cara pakai: ubah angkanya, simpan (Ctrl+S), lalu jalankan ulang game.
## Angka-angka simulasi utama (poin belajar, minigame, kepribadian,
## sifat pasif, event, Wirausaha) semuanya dibaca dari sini. Perkecualian:
## layar Atur Jadwal (atur_jadwal.gd) punya salinan sendiri untuk angka
## preview-nya — belum tersambung ke file ini.
##
## Biar cepat balik ke situasi yang mau diuji setelah restart:
## tekan F1 > "Seed Playtest State", lalu buka tab "Scenes" untuk
## langsung lompat ke layar yang kamu mau.
##
## Hati-hati: kalau salah ketik (misal "6.o" bukan "6.0") game tidak mau
## jalan. Errornya langsung kelihatan, tinggal perbaiki angkanya.
##
## Catatan buat programmer: di dalam kode, kategori "Libur" tersimpan
## dengan nama "Istirahat". Nama di file ini mengikuti tombol yang
## dilihat tester, bukan nama internalnya.
class_name Balance


## ═══════════════════════════════════════════════════════════
## SYARAT LULUS
## ═══════════════════════════════════════════════════════════

## Berapa poin yang harus dinaikkan murid di SEMUA mata pelajaran
## supaya lulus. Ditambahkan di atas nilai awal mereka — jadi makin
## besar angkanya, makin sulit kelasnya. Ini pengatur kesulitan
## paling berpengaruh di seluruh game.
static var TARGET_KENAIKAN_KELAS_7 := 15.0
static var TARGET_KENAIKAN_KELAS_8 := 34.0
static var TARGET_KENAIKAN_KELAS_9 := 40.0

## Bagian kenaikan skill di atas nilai awal roster yang DISIMPAN saat murid
## naik kelas. 0.20 = murid membawa 20% kemajuannya sebagai modal awal kelas
## berikutnya; sisanya di-reset. Dipakai GameState.reset_roster_for_new_grade().
static var KENAIKAN_KELAS_HEAD_START_FRAKSI := 0.20

## Berapa minggu satu kelas berlangsung — ini "waktu yang kamu punya"
## untuk mengejar target di atas. Menambah minggu = lebih gampang
## (lebih banyak kesempatan belajar); mengurangi = lebih sulit.
## Pasangan angka ini dengan TARGET_KENAIKAN di atas: keduanya bareng
## yang menentukan satu kelas terasa adil atau mustahil.
##
## Harus angka bulat (tanpa titik) — ini jumlah minggu, bukan persentase.
##
## Perlu diperhatikan: dua hari libur nasional terkunci di minggu 3
## (Hari Kemerdekaan RI) dan minggu 6 (Maulid Nabi Muhammad SAW) — lihat
## HOLIDAYS di atur_jadwal.gd. Keduanya TIDAK ikut bergeser kalau kamu
## mengubah angka di sini, karena itu tanggal kalender asli. Jadi kalau
## kelasnya kamu panjangkan, minggu-minggu tambahannya tidak ada liburnya.
static var JUMLAH_MINGGU_KELAS_7 := 6
static var JUMLAH_MINGGU_KELAS_8 := 12
static var JUMLAH_MINGGU_KELAS_9 := 16


## ═══════════════════════════════════════════════════════════
## HARI BELAJAR BIASA
## (saat kamu menjadwalkan Akademis, Seni Budaya, atau Olahraga)
## ═══════════════════════════════════════════════════════════

## Poin mata pelajaran yang didapat dari satu hari belajar.
static var BELAJAR_POIN_KELAS_7 := 3.0
static var BELAJAR_POIN_KELAS_8 := 2.5
static var BELAJAR_POIN_KELAS_9 := 2.0

## Poin tambahan kalau itu mata pelajaran favoritnya (sesuai hobi).
static var BELAJAR_BONUS_FAVORIT_KELAS_7 := 3.0
static var BELAJAR_BONUS_FAVORIT_KELAS_8 := 2.5
static var BELAJAR_BONUS_FAVORIT_KELAS_9 := 2.0

## Nilai cadangan, dipakai di satu jalur kode lama yang tidak
## membedakan kelas. Jarang terpakai — ubah yang di atas dulu.
static var BELAJAR_POIN_CADANGAN := 5.0
static var BELAJAR_BONUS_FAVORIT_CADANGAN := 3.0

## Energi yang terpakai untuk satu hari belajar. Game mengacak
## angka di antara kedua nilai ini, jadi tiap hari tidak persis sama.
static var BELAJAR_BIAYA_ENERGI_MIN := 15.0
static var BELAJAR_BIAYA_ENERGI_MAX := 20.0

## Mood yang terpakai untuk satu hari belajar, juga diacak.
static var BELAJAR_BIAYA_MOOD_MIN := 10.0
static var BELAJAR_BIAYA_MOOD_MAX := 15.0

## Pengali biaya di atas, tergantung mata pelajarannya.
## Di bawah 1.0 = lebih hemat. Di atas 1.0 = lebih melelahkan.
## 0.55 artinya mapel favorit cuma memakan 55% biaya.
static var BIAYA_KALAU_MAPEL_FAVORIT := 0.55
## Untuk murid "Seimbang", yang tidak punya mapel favorit.
static var BIAYA_KALAU_MURID_SEIMBANG := 0.85
## Mapel yang bukan favoritnya — 28% lebih melelahkan.
static var BIAYA_KALAU_BUKAN_FAVORIT := 1.28


## ═══════════════════════════════════════════════════════════
## HARI LIBUR
## ═══════════════════════════════════════════════════════════

## Energi yang pulih saat Libur, diacak di antara dua nilai ini.
static var LIBUR_ENERGI_PULIH_MIN := 20.0
static var LIBUR_ENERGI_PULIH_MAX := 30.0

## Mood yang pulih saat Libur.
static var LIBUR_MOOD_PULIH_MIN := 15.0
static var LIBUR_MOOD_PULIH_MAX := 25.0

## Kalau energi turun sampai angka ini atau lebih rendah, murid
## otomatis mengambil Izin — mengabaikan jadwal yang sudah kamu atur.
## Ini bisa kena hari BELAJAR yang dijadwalkan juga, bukan cuma Libur —
## ditaruh di sini karena sama-sama soal energi yang terlalu rendah.
static var IZIN_OTOMATIS_BATAS_ENERGI := 5.0

## Di bawah angka ini, murid ditandai "lelah" di layar. Berlaku tiap
## hari, bukan cuma pas Libur — ditaruh di sini karena alasan yang sama.
static var BATAS_KELELAHAN := 20.0


## ═══════════════════════════════════════════════════════════
## MINIGAME — menang dan kalah
## ═══════════════════════════════════════════════════════════

## Kalau minigame punya skor, poin dihitung: DASAR + (skor × SKALA).
## Jadi menang tipis dapat poin mendekati DASAR, menang telak
## mendekati DASAR + SKALA.
static var MINIGAME_MENANG_POIN_DASAR_KELAS_7 := 5.0
static var MINIGAME_MENANG_POIN_DASAR_KELAS_8 := 4.0
static var MINIGAME_MENANG_POIN_DASAR_KELAS_9 := 3.0
static var MINIGAME_MENANG_POIN_SKALA_KELAS_7 := 10.0
static var MINIGAME_MENANG_POIN_SKALA_KELAS_8 := 8.0
static var MINIGAME_MENANG_POIN_SKALA_KELAS_9 := 6.0

## Kalau minigame tidak punya skor (cuma menang/kalah), pakai ini.
static var MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_7 := 10.0
static var MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_8 := 8.0
static var MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_9 := 6.0

## Batas poin skill yang bisa didapat SATU murid dari MENANG minigame dalam
## satu minggu. Kekalahan TIDAK dibatasi. Menahan agar satu minggu penuh
## kemenangan minigame tidak langsung menuntaskan satu target.
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7 := 14.0
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8 := 12.0
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9 := 10.0

## Pengali durasi minigame per kelas (dulu angka mati di SchoolDay). Di bawah
## 1.0 = waktu lebih singkat. Tidak mengubah perilaku, hanya memindah angka.
static var MINIGAME_WAKTU_SKALA_KELAS_8 := 0.8
static var MINIGAME_WAKTU_SKALA_KELAS_9 := 0.6

## Saat sebuah hari memunculkan Minigame, sebesar peluang ini kategorinya
## diundi RATA (Akademis/Olahraga/Seni) tanpa melihat jadwal; sisanya ikut
## proporsi murid yang belajar. BUKAN peluang munculnya minigame — itu tetap.
static var MINIGAME_KATEGORI_ACAK_PELUANG := 0.35

## Berapa minigame paling banyak dalam satu minggu — diundi ulang tiap minggu
## di rentang ini (rata-rata ~2, seperti dulu, tapi tidak bisa dipastikan).
## Harus angka bulat (tanpa titik).
static var MINIGAME_MAKS_MINGGU_MIN := 1
static var MINIGAME_MAKS_MINGGU_MAX := 3

## Energi dan mood yang terpakai walaupun MENANG — main tetap capek.
static var MINIGAME_MENANG_ENERGI_KELAS_7 := -5.0
static var MINIGAME_MENANG_ENERGI_KELAS_8 := -7.0
static var MINIGAME_MENANG_ENERGI_KELAS_9 := -10.0
static var MINIGAME_MENANG_MOOD_KELAS_7 := -5.0
static var MINIGAME_MENANG_MOOD_KELAS_8 := -7.0
static var MINIGAME_MENANG_MOOD_KELAS_9 := -10.0

## Poin yang HILANG kalau kalah. Angka minus artinya nilainya turun.
static var MINIGAME_KALAH_POIN_KELAS_7 := -3.0
static var MINIGAME_KALAH_POIN_KELAS_8 := -4.0
static var MINIGAME_KALAH_POIN_KELAS_9 := -5.0

## Energi yang hilang saat kalah.
static var MINIGAME_KALAH_ENERGI_KELAS_7 := -10.0
static var MINIGAME_KALAH_ENERGI_KELAS_8 := -12.0
static var MINIGAME_KALAH_ENERGI_KELAS_9 := -15.0

## Mood yang hilang saat kelas kalah. Kalah terasa jauh lebih berat
## daripada lelah karena menang — angka ini sering jadi penyebab
## satu kelas terasa tidak adil.
static var MINIGAME_KALAH_MOOD_KELAS_7 := -15.0
static var MINIGAME_KALAH_MOOD_KELAS_8 := -18.0
static var MINIGAME_KALAH_MOOD_KELAS_9 := -20.0


## ═══════════════════════════════════════════════════════════
## KEPRIBADIAN — energi & mood yang habis dengan sendirinya
## ═══════════════════════════════════════════════════════════

## Tiap murid kehilangan sedikit energi dan mood setiap hari, sebelum
## kegiatan apa pun dihitung. Tiap kepribadian punya pola sendiri.
## Semua angka di bagian ini diacak antara MIN dan MAX.

## Aktif — Doni. Boros energi karena banyak bergerak.
static var DECAY_AKTIF_ENERGI_MIN := 6.0
static var DECAY_AKTIF_ENERGI_MAX := 8.0
static var DECAY_AKTIF_MOOD_MIN := 2.0
static var DECAY_AKTIF_MOOD_MAX := 4.0

## Tekun — Marcel. Boros mood karena fokus berpikir terus.
static var DECAY_TEKUN_ENERGI_MIN := 3.0
static var DECAY_TEKUN_ENERGI_MAX := 5.0
static var DECAY_TEKUN_MOOD_MIN := 6.0
static var DECAY_TEKUN_MOOD_MAX := 8.0

## Kreatif — Andi DAN Thea. Mengubah angka ini kena dua murid sekaligus.
static var DECAY_KREATIF_ENERGI_MIN := 5.0
static var DECAY_KREATIF_ENERGI_MAX := 7.0
static var DECAY_KREATIF_MOOD_MIN := 3.0
static var DECAY_KREATIF_MOOD_MAX := 5.0

## Seni Dalam Kesunyian — Citra.
static var DECAY_KESUNYIAN_ENERGI_MIN := 4.0
static var DECAY_KESUNYIAN_ENERGI_MAX := 6.0
static var DECAY_KESUNYIAN_MOOD_MIN := 4.0
static var DECAY_KESUNYIAN_MOOD_MAX := 6.0

## Santai — Shinta. Ini juga jadi nilai cadangan: dipakai kalau
## kepribadian murid tidak cocok dengan pilihan mana pun di atas.
static var DECAY_SANTAI_ENERGI_MIN := 4.0
static var DECAY_SANTAI_ENERGI_MAX := 6.0
static var DECAY_SANTAI_MOOD_MIN := 4.0
static var DECAY_SANTAI_MOOD_MAX := 6.0


## ═══════════════════════════════════════════════════════════
## SIFAT PASIF — keistimewaan tiap murid
## ═══════════════════════════════════════════════════════════

## ── Kutu Buku (Marcel) ──
## Poin Akademis tambahan di hari belajar.
static var SIFAT_KUTU_BUKU_BONUS_POIN := 1.5
## Akademis lebih hemat mood karena dia menikmatinya.
## 0.35 artinya 35% lebih hemat.
static var SIFAT_KUTU_BUKU_HEMAT_MOOD := 0.35
## Sebaliknya, Olahraga lebih boros mood. 0.20 artinya 20% lebih boros.
static var SIFAT_KUTU_BUKU_BOROS_MOOD_OLAHRAGA := 0.20

## ── Semangat Juang (Doni) ──
## Poin tambahan setiap kali kelas MENANG minigame.
static var SIFAT_SEMANGAT_BONUS_MENANG := 3.0
## Energi yang pulih saat Libur berkurang — terlalu gelisah untuk santai.
## 0.15 artinya 15% lebih sedikit.
static var SIFAT_SEMANGAT_LIBUR_KURANG := 0.15
## Kalau energinya di bawah angka ini, dia justru makin bersemangat.
static var SIFAT_SEMANGAT_BATAS_ENERGI_KRITIS := 30.0
## Seberapa besar biaya mood dipotong saat energinya kritis.
## 0.5 artinya jadi setengahnya.
static var SIFAT_SEMANGAT_POTONGAN_MOOD_KRITIS := 0.5

## ── Penasaran (Andi) ──
## Poin tambahan saat belajar mapel yang BUKAN favoritnya.
static var SIFAT_PENASARAN_BONUS_MAPEL_LAIN := 1.5
## Tapi semua hari belajar jadi lebih boros energi. 0.10 artinya 10%.
static var SIFAT_PENASARAN_BOROS_ENERGI := 0.10

## ── Penyendiri (Citra) ──
## Kalau ada sebanyak ini murid (atau lebih) belajar mapel yang sama
## di hari yang sama, Citra jadi terganggu.
static var SIFAT_PENYENDIRI_BATAS_KERAMAIAN := 3
## Tambahan biaya mood saat ramai. 0.05 artinya 5% lebih boros.
static var SIFAT_PENYENDIRI_BOROS_MOOD_RAMAI := 0.05
## Efek event ke mood-nya dikurangi 25% — senangnya kurang terasa,
## sedihnya lebih terasa.
static var SIFAT_PENYENDIRI_EVENT_MOOD := 0.25

## ── Biang Onar (Shinta) ──
## Menambah peluang event muncul tiap hari. Harus angka bulat (tanpa
## titik), karena dipakai langsung sebagai jumlah, bukan persentase.
static var SIFAT_BIANG_ONAR_PELUANG_EVENT := 10
## Dipakai untuk SEMUA event yang menimpanya, baik yang bagus maupun
## yang buruk — event bagus jadi 20% lebih bagus, event buruk 20% lebih
## buruk. Cuma satu angka karena kode simulasinya memang cuma membaca
## satu skala untuk kedua arah.
static var SIFAT_BIANG_ONAR_EVENT_BAGUS := 0.20

## ── Pekerja Keras (Thea) ──
## Hari belajar lebih hemat energi. 0.10 artinya 10% lebih hemat.
static var SIFAT_PEKERJA_HEMAT_ENERGI := 0.10
## Tapi lebih boros mood. 0.15 artinya 15% lebih boros.
static var SIFAT_PEKERJA_BOROS_MOOD := 0.15
## Bonus mood setiap kali kelas MENANG minigame.
static var SIFAT_PEKERJA_BONUS_MOOD_MENANG := 4.0

## ── Seni Dalam Kesunyian (Citra) ──
## Ini efek KEPRIBADIAN, bukan Sifat Pasif — tapi ditaruh di sini
## biar gampang dicari. Bonus poin kalau Citra belajar Seni Budaya
## SENDIRIAN (tidak ada murid lain di mapel itu hari yang sama).
## 0.10 artinya +10%.
##
## Perlu diperhatikan: mapel favorit Citra sebenarnya Olahraga, bukan
## Seni Budaya — jadi bonus ini jarang kepakai. Kalau terasa mubazir,
## ini penyebabnya.
static var SIFAT_CITRA_SENI_SENDIRI_BONUS := 0.10


## ═══════════════════════════════════════════════════════════
## WIRAUSAHA — hari cari uang
## ═══════════════════════════════════════════════════════════

## Uang yang didapat per hari Wirausaha, diacak antara dua nilai ini.
## Harus angka bulat (tanpa titik) — ini jumlah uang, bukan persentase.
static var WIRAUSAHA_UANG_MIN := 120
static var WIRAUSAHA_UANG_MAX := 320

## Hasilnya dikali sesuai sisa energi murid. Angka ini batas bawahnya:
## 0.35 artinya murid yang sudah kehabisan energi tetap dapat 35%.
static var WIRAUSAHA_BATAS_BAWAH_ENERGI := 0.35

## Mood dan energi ekstra yang terpakai di hari Wirausaha,
## di luar penurunan harian biasa.
static var WIRAUSAHA_BIAYA_MOOD := 6.0
static var WIRAUSAHA_BIAYA_ENERGI := 10.0


## ═══════════════════════════════════════════════════════════
## EVENT — kejadian acak saat simulasi hari
## ═══════════════════════════════════════════════════════════

## Event kegiatan Akademis: poin Akademis naik, energi terpakai.
static var EVENT_AKADEMIS_POIN := 15.0
static var EVENT_AKADEMIS_ENERGI := -15.0

## Event kegiatan Olahraga.
static var EVENT_OLAHRAGA_POIN := 15.0
static var EVENT_OLAHRAGA_MOOD := 10.0
static var EVENT_OLAHRAGA_ENERGI := -20.0

## Event kegiatan Seni Budaya.
static var EVENT_SENI_POIN := 15.0
static var EVENT_SENI_MOOD := 15.0
static var EVENT_SENI_ENERGI := -10.0

## "Kejutan Nasi Kotak Orang Tua" — event baik, semua murid kebagian.
static var EVENT_NASI_KOTAK_ENERGI := 20.0
static var EVENT_NASI_KOTAK_MOOD := 25.0

## "Hujan Deras & Jalanan Licin" — event buruk, semua murid kena.
static var EVENT_HUJAN_ENERGI := -15.0
static var EVENT_HUJAN_MOOD := -15.0


## ═══════════════════════════════════════════════════════════
## MODE SKIP
## ═══════════════════════════════════════════════════════════

## Peluang KALAH saat pemain menekan Skip (minigame tidak dimainkan, hasil
## diundi). Naik per kelas: skip makin berisiko di kelas atas, tapi tetap ada
## sebagai jalan aksesibilitas. 0.4 = menang 60% di kelas 7.
static var SKIP_PELUANG_KALAH_KELAS_7 := 0.4
static var SKIP_PELUANG_KALAH_KELAS_8 := 0.5
static var SKIP_PELUANG_KALAH_KELAS_9 := 0.6
