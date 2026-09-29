# Dialogue variations: event dialogue and win screen

2026-09-29. Extends the 2026-09-14 event-dialogue spec and the 2026-09-25
minigame-win-screen spec.

## Goal

Every line spoken on the EventDialogue screen and the MinigameWinScreen comes
from a pool of **at least five** variations, written for the speaker's own
personality and role, in natural Indonesian whose every word is in KBBI.
Today each entry has one line and every student thanks the player with the
same `"Terima kasih, Guru!"`.

The same change replaces the placeholder Guru Seni Budaya splash with the
real art (`GuruSBK.png`, from the owner's Downloads folder).

## Scope and volume

| Pool | Keyed by | Count |
|---|---|---|
| Student event lines | 8 student-voiced events × 6 students | 48 pools, 240 lines |
| Student win lines | 6 students × 3 categories | 18 pools, 90 lines |
| NPC event lines | `nasi_kotak`, `latihan_olahraga`, `workshop_seni`, `MainBola` | 4 pools, 20 lines |
| Narrator | `hujan` | 1 pool, 5 lines |
| Teacher win lines | Guru Penjas, Guru Seni Budaya | 2 pools, 10 lines |

About 365 lines. The student-voiced events are `les_akademis`, `Badminton`,
`Menjodohkan`, `Variabel`, `PilihanGanda`, `Password`, `BuatBatik` and
`LombaMenari`.

**Every student gets a pool for every event, not only their specialty's.**
The roster can be partial (grade 7 defaults to Marcel and Doni), and
`pick_featured` then falls back to anyone, so Doni can be the voice of
BuatBatik. Off-specialty lines react through the student's own lens.

The win lines are per category (Akademis, SeniBudaya, Olahraga), because the
win screen knows the category but a per-minigame split would double the
writing for little gain.

Each existing single line becomes one of its pool's five, so nothing written
is lost.

## Language rules

These apply to every line, and the tests enforce what they can.

1. **Every word has a KBBI entry.** Spoken-register words that KBBI marks
   *cak.* (cakapan) are allowed: *enggak, capek, banget, gampang, bikin,
   pengin, kayak, bareng, keren, jago*. Particles KBBI lists are allowed:
   *kok, dong, sih, deh, nih, yuk, ya*.
2. **Use KBBI's spelling, not the chat spelling.** Write *enggak*, not
   *nggak/gak*; *sudah*, not *udah*; *saja*, not *aja*; *pengin*, not
   *pengen*; *terima kasih*, not *makasih*; *bagaimana*, not *gimana*;
   *asyik*, not *asik*.
3. **No non-KBBI colloquial verb forms**, such as the nasal-prefix plus *-in*
   forms (*ngerjain, nyelesaiin, bikinin*). Use *mengerjakan, menyelesaikan*.
4. **Students call the player "Pak"**, matching the Lobby chatter.
   NPCs, as colleagues or a parent, say "Pak" or "Pak Guru".
5. **ASCII only.** An ellipsis is `...`, never `…`, and there are no emoji.
   The existing test rejects code points at or above U+2000.
6. **Students never say `{nama}`**, since they would be naming themselves.
   NPC and narrator lines may use it.
7. **Every line of a CHOICE entry ends in `?`**, so Tolak / Terima always
   answers a question. The current `workshop_seni` line ends in "ya!" and is
   rephrased.
8. **Length.** Event lines are at most `MAX_EVENT_LINE_CHARS = 120` (today's
   longest is about 113). Win lines must fit two lines of the win bubble (see
   the win bubble section below).
9. **The narrator never contradicts play.** All `hujan` variations describe the
   consequence the event applies: wet, slipping, arriving worn out.

NPCs speak as adults: mostly standard language, without teen particles.

## Voice sheets

### Students

**Marcel** (Tekun, Kutu Buku; Akademis). Polite and orderly, in full
sentences with few particles. He talks about notes and books, and about
having studied it already.
> *Menjodohkan:* "Tenang, Pak. Materi ini sudah kucatat semalam. Kita jodohkan satu per satu."
> *Win, Olahraga:* "Ternyata olahraga juga ada rumusnya, Pak!"

**Doni** (Aktif, Semangat Juang; Olahraga). Loud short bursts with
exclamation marks. Everything is a competition, and he never gives up.
> *PilihanGanda:* "Oke, anggap saja kuis ini pertandingan. Aku enggak mau kalah!"
> *Win, Akademis:* "Hore! Otakku ikut berkeringat, Pak!"

**Andi** (Kreatif, Penasaran; SeniBudaya). Asks "kenapa" and "kalau..." and
turns tasks into imaginative play.
> *BuatBatik:* "Pak, kenapa kompornya dipakai paling akhir? Ayo kita coba, biar tahu!"
> *Win, SeniBudaya:* "Pak, lain kali boleh lebih aneh lagi?"

**Citra** (Pendiam / Seni Dalam Kesunyian, Penyendiri; Olahraga). Few words
that open with `...`. She is soft, likes quiet and keeps her pride
understated.
> *Badminton:* "...Aku lebih suka main tanpa penonton. Tapi aku siap, Pak."
> *Win, Olahraga:* "...Terima kasih sudah percaya, Pak."

**Shinta** (Santai, Biang Onar; Akademis). Laid-back and cheeky. She jokes
and then retracts it ("Bercanda!"), bargains, and is secretly capable.
> *PilihanGanda:* "Kuisnya gampang, Pak. Jawabannya pasti C semua. Bercanda!"
> *Win, Akademis:* "Tuh kan, Pak, santai pun bisa menang!"

**Thea** (Kreatif, Pekerja Keras; SeniBudaya). A diligent perfectionist. She
mentions practice, sore hands and "sekali lagi".
> *LombaMenari:* "Gerakan ini sudah kulatih sampai kakiku pegal. Ayo, Pak, kita tunjukkan!"
> *Win, SeniBudaya:* "Latihan berhari-hari terbayar, Pak!"

### NPCs and narrator

**Guru Penjas** (`latihan_olahraga`, `MainBola`, Olahraga wins). Stern
goatee and hands on hips: a drill coach. He speaks in short commands, is
serious about discipline, and praises dryly, often with an extra lap attached.
He talks to the player as a colleague.
> *latihan_olahraga:* "Lapangan sedang kosong sore ini. Bagaimana kalau {nama} dan yang lain ikut latihan tambahan bersamaku?"
> *MainBola:* "Kuda-kuda yang kukuh, lalu tendang dengan keras! Kiper ini tidak akan memberi ampun."
> *Win:* "Lumayan. Besok kita latihan lebih pagi!"

**Guru Seni Budaya** (`workshop_seni`, SeniBudaya wins). A woman (per the
new art): apron, smirk, hand on hip. She is a warm, hands-on craftswoman,
a little playful and proud of the kids' work.
> *workshop_seni:* "Sanggar seni sedang mengadakan lokakarya batik dan tari daerah. Boleh {nama} dan teman-temannya ikut bergabung?"

English loanwords that KBBI lacks are replaced by KBBI's own term, for
example *workshop* becomes *lokakarya*.
> *Win:* "Lihat karya mereka, Pak. Cantik, bukan?"

**Mom** (`nasi_kotak`). {nama}'s mother: polite and warm to "Pak Guru",
uses *saya*, and fusses over the kids eating well.
> "Permisi, Pak Guru. Saya bawakan nasi kotak untuk {nama} dan teman-temannya. Semoga belajarnya makin semangat!"

**Hujan narrator** (no speaker). Neutral, descriptive, fully standard.
> "Hujan deras sejak pagi membuat jalanan licin. Beberapa murid basah kuyup dan terpeleset di jalan menuju sekolah."

## Architecture

### `Scripts/SchoolSimulation/EventDialogueLines.gd` (new)

A `@tool`, `class_name EventDialogueLines`, `extends RefCounted` file of pure
`const` data, following `StudentChatterCatalog`. It has a `##` header naming
this spec, and states that the lines are drafts for the owner's writer.

- `STUDENT_LINES: Dictionary`: `event_key -> {student_name -> Array[String]}`
- `NPC_LINES: Dictionary`: `event_key -> Array[String]` (includes `hujan`)
- `WIN_STUDENT_LINES: Dictionary`: `student_name -> {category -> Array[String]}`
- `WIN_TEACHER_LINES: Dictionary`: `category -> Array[String]`, keyed
  `"Olahraga"` (Guru Penjas) and `"SeniBudaya"` (Guru Seni Budaya), the same
  keys as `EventDialogueCatalog.WIN_TEACHER`. The file references no other
  script, so there is no cyclic `class_name` const reference.

Student keys are `StudentData.student_name` values: Marcel, Doni, Andi,
Citra, Shinta, Thea.

### `EventDialogueCatalog` changes

- The `line` key stays on every entry, as the **fallback**. It is used when
  a pool is missing, for example a new minigame or a student name outside the
  six.
- `const MAX_EVENT_LINE_CHARS := 120`
- `static func pool_for(key: String, featured: StudentData) -> Array`. This
  is pure and returns the first that applies:
  1. `NPC_LINES[key]`, when the entry's speaker is not `SPEAKER_STUDENT`.
  2. `STUDENT_LINES[key][featured.student_name]`, for a student speaker.
  3. `[entry(key).line]`, the fallback.

  Returns `[]` for an unknown key.
- `static func pick_line(key: String, featured: StudentData) -> String`
  draws a random line from `pool_for` that is not the previous line drawn for
  that key (a static `_last_line` Dictionary; a one-line pool repeats), then
  returns it through `fill_line`.
- `static func win_pool_for(speaker_path: String, category: String, featured: StudentData) -> Array`
  returns `WIN_TEACHER_LINES[category]` when `speaker_path` is that
  category's teacher (`WIN_TEACHER[category]`), else `WIN_STUDENT_LINES[featured.student_name][category]`, else
  `[WIN_LINE_STUDENT]`.
- `win_line_for(speaker_path, category, featured) -> String` draws from
  `win_pool_for` with the same no-repeat rule.
- `WIN_LINE_STUDENT` becomes `"Terima kasih, Pak!"`. `WIN_LINES` is deleted,
  since `WIN_TEACHER_LINES` replaces it. Each current teacher line is kept as
  one of five in its pool.

### Call sites

- `SchoolDay._show_event_dialogue`: after `pick_featured`, set
  `e = e.duplicate()` and `e["line"] = EventDialogueCatalog.pick_line(key, featured)`
  before `dialogue.open(...)`. `EventDialogue.open()` is unchanged: it still
  runs `fill_line` on `e.line`, which is a no-op on an already-filled line.
- `SchoolDay._win_context`: `win_line_for(speaker, category, featured)`.
- `BaseMinigame`'s default of `WIN_LINE_STUDENT` stays as it is.

### Win bubble

The bubble fits one uppercase line of about 26 characters: `MinigameWinLine`
is Boohong at `font_h2` 48 px, the inner width is 980 − 2 × `space_xl` =
836 px, and the height is 144 px. In `MinigameWinScreen.tscn` (edited through
the editor, not by hand):

- `Root/Bubble/Panel/Line`: `autowrap_mode = AUTOWRAP_WORD_SMART`. This is a
  node property, not a theme override.
- `Root/Bubble`: raise its height so two lines plus the panel's margins fit.
  It grows **upward**: its bottom stays at −878, only 50 px above the card
  (−828), and the Tail is anchored to its top-left, so the Tail rides along.
  Judge the overlap on the speaker at full size on a 1080×1920 and a
  1080×2400 capture. Keep `test_tall_screen_layout` green.
- No theme change and no rebake.

### Guru Seni Budaya art

`C:\Users\user\Downloads\GuruSBK.png` (1080×1920, transparent, same canvas
and framing as `splash_gurupenjas.png`) is copied over
`Assets/Images/EventDialogue/splash_gurusenibudaya.png`. Its `.import` and
UID are unchanged, and no code changes. The DEBT.md placeholder entry is
deleted. It is checked live on the `workshop_seni` dialogue and on a
SeniBudaya win with the teacher speaking. `WinCompleteSeniBudaya.png` (a
star badge, not a teacher) is out of scope.

## Tests

`tests/test_event_dialogue_lines.gd` (new, `@tool`, no coroutines):

- **Coverage:**
  - Every student-voiced event has a pool for all six students.
  - Every NPC event and `hujan` has a pool.
  - Every student has all three win categories.
  - Both teachers have win pools.
  - Every pool has at least 5 lines and no duplicates.
- **Language:**
  - Every line is ASCII.
  - No line contains a banned form, matched as a whole word, case-insensitive:
    `nggak, gak, ga, udah, dah, aja, pengen, makasih, gimana, workshop,
    ngerjain, nyelesaiin, bikinin, asik, gue, lu`.
  - No student line contains `{nama}`.
- **Choice entries:** every line in a pool of a `MODE_CHOICE` entry ends in `?`.
- **Length:**
  - Event lines are at most `MAX_EVENT_LINE_CHARS`.
  - Each win line, uppercased, is measured with the baked theme's
    `MinigameWinLine` font and size via `get_multiline_string_size` at the
    bubble's inner width, and wraps to at most two lines.

`tests/test_event_dialogue.gd` updates:

- `test_each_speaker_has_its_own_thanks` asserts pool membership instead of
  one fixed string.
- New behaviour tests:
  - `pool_for` falls back to the entry line for an unknown student and for a
    null featured student.
  - `pick_line` never returns the same line twice in a row for a pool of 5.
  - `win_pool_for` picks the category's pool.
  - A teacher speaker gets the teacher pool.

## KBBI verification

The banned-forms test catches known chat spellings, but it cannot prove a
word is in KBBI. After the lines are written:

1. Extract every distinct word across all pools.
2. Flag every casual, regional, borrowed or uncertain word, including every
   particle and every *cak.* candidate.
3. Look each flagged word up on KBBI Daring (kbbi.kemdikbud.go.id) in the
   browser, and replace any word without an entry.
4. Record the checked list, with each word's KBBI label, in this spec's
   appendix.

## Docs

- A CHANGELOG entry.
- Delete the DEBT.md Guru Seni Budaya placeholder entry.
- In CLAUDE.md's loop paragraph, name `EventDialogueLines` next to
  `EventDialogueCatalog`.

## Out of scope

- The Lobby's `StudentChatterCatalog` (its *nggak/aja* spellings stay).
- `WinCompleteSeniBudaya.png`.
- Mood- or state-dependent lines.
- Naming the teachers.
- Any persistence.

## Appendix: KBBI check (2026-09-29)

### Method

1013 distinct words were extracted from all 365 lines. About 275 casual, borrowed, affixed, reduplicated or "-in"-ending words were flagged and looked up. Sources: the official KBBI Daring (kbbi.kemendikdasmen.go.id, KBBI VI), which rate-limits anonymous lookups, so only words a to d and "tuh" were checked there; and mirrors of an older KBBI edition (kbbi.co.id for the lookup pass, typoonline.com/kbbi for the controller's spot checks). Words checked only on a mirror may carry KBBI VI labels that differ.

### Rulings

- Words KBBI lists as non-standard variants of a standard form (tapi for tetapi, dulu for dahulu, meleset under peleset, seru, poin (cak.)) stay in student speech: they are KBBI entries and natural for teens. Adults (the NPC lines: Mom, Guru Penjas, Guru Seni Budaya, the hujan narrator; and the win-screen teacher lines) use standard forms only. Only words missing from KBBI, or used in a sense KBBI does not give, are replaced.
- kokoh became kukuh in the Guru Penjas line (KBBI: kokoh is a variant of kukuh).
- Bare "tanding" used as a verb became "bertanding" in two student lines (KBBI: tanding is a noun meaning "lawan"; the verb is bertanding). The noun phrase "lawan tanding" is unchanged.
- "Hitung-hitungan bukan keahlianku" became "Berhitung bukan keahlianku" (KBBI lists hitung-hitungan only as "banyak perhitungan", not arithmetic).
- "pewarnanya pasti bikin tangan belepotan" became "... bikin tanganku kotor" (belepotan is not a KBBI headword; only berlepotan).
- "duluan" became "lebih dulu" in three lines (no KBBI entry).
- Guru Penjas 'meleset' -> 'gagal' (adults use standard forms).

### Flagged words

Columns: word | found? | KBBI label | sense fits our line? | source and note.

#### Particles and interjections

| Word | Found | Label | Sense fits | Source / note |
|---|---|---|---|---|
| ah | yes | p cak | yes | OFF |
| aduh | yes | p | yes | OFF |
| ayo | yes | p | yes | OFF |
| dong | yes | p cak | yes | MIR |
| deh | yes | p Jk (dialek Jakarta) | yes | OFF and MIR. Not cak., but the entry exists; used once (Shinta, "aku hitung sungguhan, deh") |
| eh | yes | p | yes | MIR |
| hore | yes | p | yes | MIR |
| kan | yes | kp (kependekan dari "bukan") | yes | MIR; entry exists as kependekan, used as a tag question |
| kok (and koknya) | yes | kok1 n (shuttlecock); kok2 p cak | yes, both | MIR; `kok` is the shuttlecock in badminton lines, the particle elsewhere |
| nah | yes | p | yes | MIR |
| pun | yes | p | yes | MIR |
| sih | yes | p cak | yes | MIR |
| tuh | yes | p cak | yes | OFF ("itu (dengan penegasan)"); MIR has no page for it |
| wah | yes | p | yes | MIR |
| ya | yes | p | yes | MIR |
| yuk | yes | p | yes | MIR |
| tak | yes | adv | yes | MIR |
| tapi | variant | "? tetapi" (non-baku) | n/a | MIR. kept for students (variant/cak. listed in KBBI) |

#### Casual, cak. candidates, loanwords

| Word | Found | Label | Sense fits | Source / note |
|---|---|---|---|---|
| enggak | yes | adv cak (tidak) | yes | MIR |
| capek | yes | a cak (capai) | yes | OFF |
| gampang | yes | a (baku) | yes | MIR |
| bikin | yes | v cak (buat) | yes | OFF |
| bilang (kubilang) | yes | v cak (berkata) | yes | OFF |
| kayak | yes | p cak (seperti) | yes | MIR |
| jago | yes | n (juara; kampiun) | yes | MIR |
| oke | yes | cak (p setuju; v setuju) | yes | MIR |
| cuma | yes | adv (hanya) | yes | OFF |
| bakal | yes | adv (akan) | yes | OFF |
| masa | yes | adv (ketidakpercayaan, retoris) | yes ("Masa aku ketinggalan?") | MIR |
| traktir | yes | v | yes | MIR |
| balapan | yes | n (lomba adu kecepatan); the v sense "berbalapan" is cak | yes (noun sense) | OFF |
| dadakan | yes | n / adv (tiba-tiba) | yes | OFF |
| mendadak | yes | via root `dadak` | yes | OFF |
| belepotan | variant | OFF: "belepotan -> berlepotan" | n/a | OFF. replaced (tangan belepotan -> tanganku kotor) |
| kebobolan | yes | v ki (tertembus pertahanan karena lengah) | yes | MIR via root `bobol` |
| asal-asalan | yes | a (sembarangan) | yes | OFF |
| kapan-kapan | yes | n cak (sewaktu-waktu) | yes | MIR |
| iseng | yes | a | yes (sense 3, suka mengganggu) | MIR |
| kompak | yes | a | yes | MIR |
| lumayan | yes | a | yes | MIR |
| pegal | yes | a | yes | MIR |
| repot | yes | a | yes | MIR |
| seru | partly | a "bengis; sengit; hebat" | **no** (we mean "fun") | MIR. kept for students (variant/cak. listed in KBBI) |
| asyik | yes | a (baku; "asik" is tidak baku) | yes | OFF |
| gratis | yes | a | yes | MIR |
| dulu | variant | "? dahulu" (non-baku) | n/a | MIR. kept for students (variant/cak. listed in KBBI) |
| duluan | **no** | none | n/a | MIR 404. replaced with "lebih dulu" |
| sembarangan | yes | a | yes | MIR via root `sembarang` |
| sungguhan | yes | n cak (yang sebenarnya) | yes | MIR via root `sungguh` |
| kewalahan | yes | v | yes | MIR via root `walah` |
| ketinggalan | yes | v (tertinggal; terbelakang) | yes | MIR via root `tinggal` |
| kelelahan | yes | a / v | yes | MIR via root `lelah` |
| santai, bersantai | yes | a; v | yes | OFF |
| camilan | yes | n (baku; "cemilan" is tidak baku) | yes | OFF |
| menyontek | yes | v under sontek2 (mengutip; menjiplak). Baku: "contek -> sontek" | yes | OFF and MIR |
| permisi | yes | n | yes | MIR |
| piket | yes | n / v | yes | MIR |
| les | yes | n cak / v cak | yes | MIR |
| kuis | yes | n (ujian singkat) | yes | MIR |
| lokakarya | yes | n | yes | MIR |
| hafal, menghafal | yes | v | yes | MIR |
| lembap | yes | a (baku) | yes | MIR |
| napas | yes | n (baku) | yes | MIR |
| kesatria | yes | n | yes | MIR |
| praktik (praktiknya) | yes | n | yes | MIR |
| mi, teh, es | yes | n | yes | MIR |
| kuyup | yes | a (basah) | yes ("basah kuyup") | MIR |
| sebangku | yes | regular se- + bangku | yes | MIR root `bangku` (no separate entry; productive se-) |
| muram, luntur, lesu | yes | a | yes | MIR |
| kaget | yes | a (baku) | yes | MIR |
| bohong | yes | a (baku; "boong" is tidak baku) | yes | OFF |
| bingung | yes | a | yes | OFF |
| silakan | yes | v (baku spelling) | yes | MIR via root `sila` |
| izinkan, mengizinkan | yes | v (baku spelling with z) | yes | MIR via root `izin` |
| ide, kode, digit, net, tim | yes | n | yes | OFF and MIR |
| skor | yes | n (jumlah angka kemenangan) | yes | MIR |
| kiper, penalti, voli, badminton, raket | yes | n | yes | OFF and MIR |
| motif, rekor, stamina, festival, fokus | yes | n | yes | MIR |
| disiplin, asisten, atlet, aljabar, abstrak, atlas, jurnal, materi, strategi | yes | n | yes | OFF and MIR (abstrak sense 3, "karya seni abstrak", fits "Batiknya kubuat abstrak") |
| kilometer | yes | n | yes | MIR |
| sketsa, prakarya, rekaman | yes | n | yes | MIR |
| poin | yes | n cak "titik" only | **no** (we mean a game point) | MIR. kept for students (variant/cak. listed in KBBI) |
| kokoh | variant | "? kukuh" | n/a | MIR. replaced with kukuh |
| meleset | variant | "? peleset" (baku verb memeleset) | n/a | MIR. kept for students (variant/cak. listed in KBBI) |
| hitung-hitungan | partial | v cak "banyak perhitungan" | **no** (we mean arithmetic) | MIR. replaced with berhitung |
| tanding (bare) | partial | n "yang seimbang"; the verb is bertanding | verb use: no | MIR. replaced with bertanding ("lawan tanding" is a noun and stays) |

#### Every word ending in -in

| Word | Found | Label | Note |
|---|---|---|---|
| angin | yes | n | MIR |
| bermain, main | yes | v (main sense 2 is cak) | OFF |
| bikin | yes | v cak | OFF (see above) |
| dingin | yes | a | OFF |
| disiplin | yes | n | OFF |
| kain, kainnya | yes | n | MIR |
| kemarin | yes | n | MIR |
| lain | yes | a | MIR |
| licin | yes | a | MIR |
| lilin | yes | n | MIR (sense 1, "bahan untuk membatik", matches) |
| makin | yes | adv | MIR |
| menyalin | yes | v | MIR |
| mungkin | yes | adv | MIR |
| pengin | yes | v cak (ingin) | MIR |
| poin | see above | n cak titik | kept for students (variant/cak. listed in KBBI) |
| yakin | yes | a | MIR |

No colloquial -in verbs (bantuin, ajarin, ...) exist in the list.

#### Other affixed, borrowed or unusual words

| Word | Found | Label / note | Source |
|---|---|---|---|
| menjumlah | yes | v (menghitung; menambah) | MIR |
| menjumlahkan | yes | v | MIR |
| mengajari | yes | v (mengajar kepada) | MIR |
| menyemangati | yes | v (memberi semangat) | MIR |
| mempermalukan | yes | v | MIR |
| memperingati | yes | v (mengadakan kegiatan untuk mengenangkan), listed under `ingat` | MIR |
| punya | yes | v (memiliki) | MIR |
| kenapa | yes | pron cak | MIR |
| malah | yes | adv (bahkan; justru) | MIR |
| justru | yes | adv | MIR |
| sepulang | yes | v | MIR |
| semalaman | yes | n | MIR |
| sekelas, sekuat, secepat, serapi, sekecil | yes | regular se- + root | MIR roots `kelas`, `kuat`, `cepat`, `rapi`, `kecil` |
| menyerah | yes | v | MIR |
| sanggar | yes | n (tempat kegiatan seni) | MIR |
| sayang | yes | a / v | MIR |
| pas | yes | a cak (tepat; cocok) | MIR |
| tiap | yes | a | MIR |
| lolos | yes | v | MIR |
| kunjung | yes | a "lekas; pernah", used in "tidak kunjung reda" | MIR |
| usah | yes | v (tak / tidak usah) | MIR |
| ajaib | yes | a (ganjil; mengherankan) | OFF |
| pekerjaan, bimbingannya, ketelitian, kesukaan, coretan, genggaman, rekaman | yes | n | OFF and MIR via roots |
| pewarna, penghapus, penggaris, rautan, pergelangan, perhitungan | yes | n | MIR via roots |
| pulpen, taplak, gembok, canting, wayang, tenda, merak, elang, busur, jangka, pojok, serong, telak, sanggup, selisih, pantang, genderang | yes | n / a / v | OFF and MIR |
| tandai | yes | menandai v (memberi tanda) | MIR via root `tanda` |
| kutaklukkan | yes | menaklukkan v | MIR root `takluk` |
| ku- forms: kuambil, kuanggap, kubaca, kubawa, kuberi, kubuat, kucari, kucatat, kucoba, kudengar, kudengarkan, kugambar, kugeser, kuhafal, kuhitung, kukalahkan, kukerjakan, kukuasai, kulatih, kulingkari, kupecahkan, kupelajari, kuperbaiki, kuperhatikan, kuperhitungkan, kuperiksa, kuragukan, kurebut, kusuka, kutanyakan, kutemukan, kutulis, kuulang | yes | ku- + verb; every root confirmed (catat, baca, bawa, beri, cari, dengar, hafal, hitung, kalah, kuasa, lingkar, pecah, ajar, baik, hati, periksa, ragu, rebut, suka, tanya, temu, tulis, ulang, ...) | OFF and MIR roots |
| terpeleset, terpendam, tertukar, terkalahkan, terlupa, terbayar, terarah, bersusun, berpasangan, bersorak, bertepuk, menggigil, menggenang, menguap, menyapa, membatik, menerbangkan, memasangkan, menjodohkan, mengacak | yes | regular verbs found in their root pages | MIR (menjodohkan, mengacak: OFF) |

#### Reduplications

| Word | Found | Label / note | Source |
|---|---|---|---|
| alat-alat, benda-benda, buku-buku, kartu-kartu, kawan-kawan, murid-murid, soal-soal, teman-teman, anak-anak | plain plurals | regular reduplication; not separate entries (anak-anak and kartu-kartu are listed in places) | rule-based |
| ancang-ancang | yes | n (persiapan; gerakan permulaan) | OFF |
| apa-apa, siapa-siapa, mana-mana | yes | pron / n | OFF and MIR |
| asal-usul | yes | n (asal keturunan; riwayat) | OFF |
| baik-baik | yes | a / adv | OFF |
| benar-benar | yes | a / adv | OFF |
| berhari-hari, berminggu-minggu | yes | num | OFF, MIR |
| berulang-ulang | yes | v | MIR |
| berwarna-warni | yes | v | OFF |
| diam-diam | yes | adv | OFF |
| gara-gara | yes | n | MIR |
| hati-hati | yes | adv | MIR |
| jangan-jangan | yes | adv (barangkali) | MIR |
| kira-kira | yes | adv | MIR |
| keras-keras | regular | "keras" + reduplication | rule-based |
| kuda-kuda | yes | n, sense 3 "sikap siaga (bela diri)" fits | MIR |
| mata-mata | yes | n | MIR |
| pelan-pelan | yes | v cak (perlahan-lahan) | MIR |
| pura-pura | yes | adv | MIR |
| ragu-ragu | yes | a | MIR |
| sia-sia | yes | a | MIR |
| disia-siakan | yes | passive of `menyia-nyiakan` (v), listed under sia-sia | MIR |
| sungguh-sungguh | yes | adv / a | MIR |
| terburu-buru, tergesa-gesa | yes | v / a | MIR |
| hitung-hitungan | see above | replaced with berhitung | MIR |
| sebanyak-banyaknya | unverified | `sebanyak` is a listed num; the reduplicated superlative is regular but not separately found | MIR (root page only) |
| teka-teki | unverified | the mirror has no page for the hyphenated word (`teka` only says "? terka"); it is the standard KBBI entry behind "teka-teki silang", but the OFF check was locked by the daily limit | not verified |

### Unverified

teka-teki and sebanyak-banyaknya were not found on the mirror. Both are regular formations (teka-teki is a standard KBBI headword in KBBI V; sebanyak-banyaknya is the se-/-nya superlative of banyak). Recheck on KBBI Daring when convenient.
