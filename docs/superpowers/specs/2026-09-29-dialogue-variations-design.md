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
> *Menjodohkan:* "Tenang, Pak. Rumus-rumus ini sudah kucatat semalam. Kita jodohkan satu per satu."
> *Win, Olahraga:* "Ternyata olahraga juga ada rumusnya, Pak!"

**Doni** (Aktif, Semangat Juang; Olahraga). Loud short bursts with
exclamation marks. Everything is a competition, and he never gives up.
> *PilihanGanda:* "Kuis dadakan? Oke, anggap saja ini pertandingan. Aku enggak mau kalah!"
> *Win, Akademis:* "Hore! Otakku ikut berkeringat, Pak!"

**Andi** (Kreatif, Penasaran; SeniBudaya). Asks "kenapa" and "kalau..." and
turns tasks into imaginative play.
> *BuatBatik:* "Pak, kenapa malamnya harus dipanaskan dulu? Ayo kita coba, biar tahu!"
> *Win, SeniBudaya:* "Pak, lain kali boleh aku coba motif yang lebih aneh?"

**Citra** (Pendiam / Seni Dalam Kesunyian, Penyendiri; Olahraga). Few words
that open with `...`. She is soft, likes quiet and keeps her pride
understated.
> *Badminton:* "...Aku lebih suka main tanpa penonton. Tapi aku siap, Pak."
> *Win, Olahraga:* "...Aku senang. Terima kasih sudah percaya, Pak."

**Shinta** (Santai, Biang Onar; Akademis). Laid-back and cheeky. She jokes
and then retracts it ("Bercanda!"), bargains, and is secretly capable.
> *PilihanGanda:* "Kuis dadakan? Tenang, Pak, jawabannya pasti C. Bercanda!"
> *Win, Akademis:* "Tuh kan, Pak, santai saja juga bisa menang!"

**Thea** (Kreatif, Pekerja Keras; SeniBudaya). A diligent perfectionist. She
mentions practice, sore hands and "sekali lagi".
> *LombaMenari:* "Gerakan ini sudah kulatih sampai kakiku pegal. Ayo, Pak, kita tunjukkan!"
> *Win, SeniBudaya:* "Latihan berhari-hari akhirnya terbayar, Pak!"

### NPCs and narrator

**Guru Penjas** (`latihan_olahraga`, `MainBola`, Olahraga wins). Stern
goatee and hands on hips: a drill coach. He speaks in short commands, is
serious about discipline, and praises dryly, often with an extra lap attached.
He talks to the player as a colleague.
> *latihan_olahraga:* "Lapangan kosong sore ini, Pak. Kalau {nama} dan yang lain mau latihan tambahan, saya tunggu di sana. Bagaimana?"
> *MainBola:* "Kuda-kuda yang kokoh, lalu tendang sekuat tenaga! Kiper ini tidak akan memberi ampun."
> *Win:* "Lumayan. Besok kita tambah dua putaran lari, ya!"

**Guru Seni Budaya** (`workshop_seni`, SeniBudaya wins). A woman (per the
new art): apron, smirk, hand on hip. She is a warm, hands-on craftswoman,
a little playful and proud of the kids' work.
> *workshop_seni:* "Pak, sanggar sedang membuka lokakarya batik dan tari daerah. Bagaimana kalau {nama} dan teman-temannya ikut?"

English loanwords that KBBI lacks are replaced by KBBI's own term, for
example *workshop* becomes *lokakarya*.
> *Win:* "Lihat karya mereka, Pak. Cantik sekali, bukan?"

**Mom** (`nasi_kotak`). {nama}'s mother: polite and warm to "Pak Guru",
uses *saya*, and fusses over the kids eating well.
> "Permisi, Pak Guru. Ini ada nasi kotak untuk {nama} dan teman-temannya. Semoga belajarnya makin semangat!"

**Hujan narrator** (no speaker). Neutral, descriptive, fully standard.
> "Hujan turun sejak subuh. Jalan menuju sekolah licin, dan beberapa murid tiba dengan seragam basah kuyup."

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
