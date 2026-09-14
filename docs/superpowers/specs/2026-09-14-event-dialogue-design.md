# EventDialogue — design

2026-09-14. Approved through the `/gamecode` Brief; every decision took its
bold default. Mockup: `mockup_eventdialogue.png` (Drive `mockups/`, copy in
the owner's Downloads).

## What the player gets

Before every minigame and every random event, a character steps in with one
line written for that event, over a blurred picture of the school. The three
events where the player picks students ask **Tolak / Terima** first.

## Where it sits

```
SchoolDay, midday roll
 ├ Minigame                 → EventWarning → [EventDialogue · tap twice] → minigame
 ├ Nasi Kotak / Hujan       → EventWarning → [EventDialogue · tap twice] → effect
 └ Les / Latihan / Workshop → EventWarning → [EventDialogue · Tolak | Terima]
                               Terima → EventStudentSelectDialog
                               Tolak  → event skipped
```

The midday roll itself (`_roll_event`, `_todays_roll_weights`) is unchanged.

## Rules

1. **Two modes.**
   - **TAP**: the 8 minigames, *Kejutan Nasi Kotak Orang Tua* and *Hujan Deras
     & Jalanan Licin*. No buttons. It always takes exactly two taps. The
     first tap finishes the typewriter line if it is still typing, and shows
     the hint *"Ketuk sekali lagi untuk lanjut"*. The second tap closes the
     dialogue. A first tap on a line that already finished typing only shows
     the hint.
   - **CHOICE**: *Les Tambahan Akademis*, *Latihan Olahraga Ekstra*, *Workshop
     Sanggar Seni*. A tap finishes the line; taps never close it. **Tolak**
     and **Terima** appear once the line is fully shown.
     - **Terima** opens `EventStudentSelectDialog` exactly as today.
     - **Tolak** skips the event. Nothing is applied and nothing is recorded,
       but it still counts toward the week's event limit. This is what the
       picker's own "Tidak / Lewati" already does; that button stays.
2. **The featured student.** Each dialogue features one roster student.
   - For the minigames other than MainBola, and for *Les Tambahan Akademis*
     (category Akademis), it is a random roster student whose
     `specialty_category` matches the category. If nobody matches, it is any
     roster student. That student's `splash_path` is the splash.
   - For entries with a fixed speaker (parent, teachers, rain), the featured
     student is any roster student. The speaker art does not change.
   - `{nama}` in a line becomes the featured student's `student_name`.
   - On an empty roster (debug only), `{nama}` becomes "murid-murid" and the
     splash is hidden.
3. **Art per entry.** Every entry has a splash (a fixed texture, the featured
   student, or none) and a background. The default background is the
   **blurred** `sekolah_background`. *Hujan* uses `hujan_background`,
   **unblurred**, with no splash.
4. **Header.** A calendar badge shows "Minggu" over
   `GameState.minggu_ke` / `GameState.get_max_weeks()`, next to a day banner
   with the day's name. SchoolDay passes the day name in. This follows the
   mockup.
5. **Skip mode shows no dialogue.** `skip_to_results()` never builds UI. The
   debug overlay's *Trigger Event* buttons do show it, because `force_event()`
   runs the same event code (see *SchoolDay changes*).
6. **Grades.** Same in every grade.

## The catalog: 13 entries

Event keys: `les_akademis`, `latihan_olahraga`, `workshop_seni`, `nasi_kotak`,
`hujan`. Minigame keys are the scene names `_scene_name()` already returns:
`Menjodohkan`, `Variabel`, `PilihanGanda`, `Password`, `MainBola`,
`Badminton`, `BuatBatik`, `LombaMenari`.

These lines are drafts. The owner's writer may rewrite them, and they are
listed under CLAUDE.md's copy placeholders.

| Key | Mode | Speaker | Line |
|---|---|---|---|
| `nasi_kotak` | TAP | `splash_mom` | Kudengar {nama} dan teman-temannya sedang bekerja keras, semoga ini dapat menyemangati mereka! |
| `hujan` | TAP | — (bg `hujan_background`, no blur) | Hujan deras sejak pagi membuat jalanan licin. Beberapa murid basah kuyup dan terpeleset di jalan menuju sekolah. |
| `les_akademis` | CHOICE | student · Akademis | Sekolah membuka les tambahan sepulang sekolah. Aku mau ikut, boleh kan? |
| `latihan_olahraga` | CHOICE | `splash_gurupenjas` | Lapangan sedang kosong sore ini. Bagaimana kalau {nama} dan yang lain ikut latihan tambahan bersamaku? |
| `workshop_seni` | CHOICE | `splash_gurusenibudaya` | Sanggar seni sedang mengadakan workshop batik dan tari daerah. Ajak {nama} dan teman-temannya bergabung, ya! |
| `MainBola` | TAP | `splash_gurupenjas` | Ayo latihan adu penalti! Tendang bolanya sekuat tenaga dan jangan sampai ditangkap kiper! |
| `Badminton` | TAP | student · Olahraga | Raketku sudah siap dari tadi. Ayo tanding badminton, siapa takut? |
| `Menjodohkan` | TAP | student · Akademis | Kartu soal dan jawabannya tercampur semua! Bantu aku menjodohkannya sebelum waktunya habis. |
| `Variabel` | TAP | student · Akademis | Ada teka-teki angka di papan tulis. Kira-kira berapa nilai tiap simbolnya, ya? |
| `PilihanGanda` | TAP | student · Akademis | Kuis dadakan! Tiga soal pilihan ganda. Aku pasti bisa! |
| `Password` | TAP | student · Akademis | Lemari kelas cuma terbuka kalau hitungannya benar. Ayo kita hitung bersama! |
| `BuatBatik` | TAP | student · SeniBudaya | Kain, canting, dan pewarna sudah siap. Aku mau membatik, tapi urutannya harus benar! |
| `LombaMenari` | TAP | student · SeniBudaya | Lomba menari sebentar lagi dimulai! Ikuti iramanya dan jangan sampai salah langkah. |

An unknown key has no entry. SchoolDay then skips the dialogue and carries on,
so a new minigame without a line never blocks the day.

## The screen: `EventDialogue.tscn`

Every node is static in the scene. The script only sets textures, text and
visibility. From back to front:

- `Background`: TextureRect, full rect, covers the screen. Defaults to
  `sekolah_background.jpg`.
- `Blur`: ColorRect, full rect, with its own ShaderMaterial on
  `Scripts/Shaders/blur.gdshader`. It is shown only for blurred entries. Its
  tint is lighter than ShopHub's, because the mockup keeps the school bright.
- `Splash`: TextureRect, bottom-centred, keeps its aspect, and sits behind the
  box as in the mockup.
- `Header`: the calendar badge (texture plus two labels) and the day banner
  (a pill panel plus a label).
- `DialogueBox`: a white rounded panel near the bottom. Inside it:
  - `Line`: RichTextLabel, typewriter by `visible_ratio`, the same technique
    as `cut_scene.gd`.
  - `Hint`: shown once a TAP dialogue is armed.
  - `Choices`: `Tolak` (SecondaryButton) and `Terima` (PrimaryButton). Hidden
    in TAP mode.

**Motion and sound.** The box pops in through `Juice`. `popup_open` plays on
show and `tap` plays on each screen tap. The buttons get their press and
release juice from `UIPolish`.

**API.** `signal closed(accepted: bool)` and
`open(entry, featured, week, max_weeks, day_name)`. A TAP dialogue always
closes with `accepted = true`.

## Theme

- **New token.** `font_body_bold` (`Assets/Fonts/OpenSans-Bold.ttf`) on
  `DesignTokens`, set in `design_tokens.tres`. The mockup's text is Open Sans
  Bold, and no token carries a bold face today.
- **New ThemeFactory variations.**
  - `EventDialoguePanel`: white card, large radius.
  - `EventDialogueText`: RichTextLabel, bold body face, above title size.
  - `DayBannerPanel`: white pill with a brown outline.
  - `DayBannerLabel`: bold body face.
  - `CalendarLabel`: bold body face, for the calendar's two lines.
- Rebake `kejartes_theme.tres`. None of these use the display font, so
  `DISPLAY_ROSTER` in `test_theme_factory.gd` does not change. Its reverse
  check, that no variation outside the roster gets `font_display`, covers
  the new ones automatically. The variations join
  `test_every_declared_variation_exists`.

## SchoolDay changes

- New `@export var event_dialogue_scene: PackedScene`, lazy-loaded like the
  other scenes.
- New `_show_event_dialogue(key, category := "") -> bool`. It instantiates the
  dialogue, picks the featured student from `student_manager.students`,
  awaits `closed`, frees the dialogue and returns `accepted`. With no catalog
  entry, it returns `true` straight away.
- **Minigame branch.** After the warning, it awaits the dialogue for
  `_scene_name(scene)` before `_play_minigame`.
- **Nasi Kotak and Hujan.** After the warning, they await the dialogue before
  the effect applies.
- **`_handle_interactive_event`.** It gains a `dialogue_key` argument. After
  the warning, a declined dialogue returns before the picker is instantiated.
- **One copy of the event list.** Today `force_event()` duplicates
  `_trigger_random_event()`'s whole `match`. Both become thin callers of one
  `_run_event(event_id, day_name)`, so the dialogue hooks live in one place.

## Assets: `Assets/Images/EventDialogue/`

| File | Source |
|---|---|
| `sekolah_background.jpg` | Owner's Downloads (1080×1920, 853 KB) |
| `splash_mom.png` | Drive `splash/ortu_splash.png` (294 KB) |
| `splash_gurupenjas.png` | Drive `splash/gurupenjas_splash.png` (274 KB) |
| `splash_gurusenibudaya.png` | Generated placeholder; not in the Drive |
| `hujan_background.png` | Generated placeholder, 1080×1920; not in the Drive |
| `calendar_badge.png` | Generated placeholder; the repo has no calendar art |
| `event_dialogue_blur_material.tres` | New ShaderMaterial on the existing blur shader |

The placeholders are drop-replaceable at the same paths. They join
CLAUDE.md's generated-art list.

## Tests

`tests/test_event_dialogue.gd` is a new suite, `suite_name()` =
`"event_dialogue"`, @tool, with no coroutines. It covers:

- **Catalog.** All 13 keys, including one for every minigame scene SchoolDay
  loads.
- **Modes and art.** Each entry's mode and art as tabled above, and every art
  path loads.
- **Featured student.** It matches the specialty, falls back to any roster
  student, and returns null on an empty roster. `{nama}` filling works.
- **TAP dialogue.** A tap mid-line arms without closing; the next tap closes
  with `true`; a first tap on a finished line only arms.
- **CHOICE dialogue.** Taps never close it; the buttons stay hidden until the
  line is shown; Terima closes with `true` and Tolak with `false`.
- **SchoolDay wiring**, by source scan:
  - the dialogue sits between the warning and the minigame or effect;
  - a decline returns before the picker is instantiated;
  - `force_event` and `_trigger_random_event` both go through `_run_event`.

The existing `school_day`, `theme_factory`, `theme_rebake`,
`viewport_editability` and `script_documentation` suites must stay green. The
last task runs the full suite.

## Not doing

- Name tags.
- Multi-line conversations.
- Removing the picker's Lewati button.
- Dialogue during Skip.
- Per-event `.tres` resources: a const catalog is 13 entries in one file,
  like `ItemDatabase`.
- Reusing the CutScene screen, which is a scene change, not an overlay.
