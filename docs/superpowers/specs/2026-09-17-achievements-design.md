# Achievements — design

Agreed 2026-09-17 through `/gamecode`. Source list:
`Daftar_Achievement_dan_Requirement.pdf` plus the artist's board; icons from
the "Achievement" Drive folder; layout from `Achievement mockup.psd` and
`achievement_notif.png`.

## What the player gets

26 achievements, tracked across runs. A trophy button in the Lobby opens the
Achievements screen: a scrolling list of cards. A **locked** card is white and
dimmed with no button; an **unlocked** card is white with a green **Klaim**
button; a **claimed** card is the yellow-to-green gradient card. Claiming turns
the achievement's prize on. Whenever one unlocks, on any screen, a white banner
with its icon and title slides down from the top, holds, and slides back.

```
Lobby ──[trophy]──→ Achievements screen (Klaim → prize on)
SchoolDay minigame ends ─┐
RunResult: grade passed ─┼→ Achievements autoload ──unlocked──→ AchievementToast
GameState.money_changed ─┘
```

## The list

| id | Title | Requirement |
|---|---|---|
| three_star_akademis | Cap-cip-cup kembang kuncup! | 3-star an Akademis minigame |
| three_star_seni | Kunci kemenangan adalah Budaya! | 3-star a Seni Budaya minigame |
| three_star_olahraga | Turunan Ronaldio atau Rudie?! | 3-star an Olahraga minigame |
| streak_2 | Calon Pembimbing Handal | 2 perfect (3-star) results in a row |
| streak_4 | Calon Sarjana S3 | 4 in a row |
| streak_6 | Calon Asisten Einstein | 6 in a row — prize: minigame stat gain +5% |
| play_all_akademis | Buku adalah jendela dunia! | play all 4 Akademis minigames |
| play_all_seni | Kebudayaan Lokal yang Arif! | play both Seni Budaya minigames |
| play_all_olahraga | Satu, dua, satu dan dua! | play both Olahraga minigames |
| total_5 | Pembimbing Awam | play 5 minigames |
| total_10 | Pembimbing Serba-bisa | 10 |
| total_15 | Pembimbing Profesional | 15 — prize: Skin Thea (Segera hadir; no effect) |
| total_25 | Pembimbing Sepuh | 25 — prize: Wirausaha +5% |
| total_50 | Pembimbing Legendaris | 50 — prize: shop prices −10% |
| money_2x | Sedikit demi sedikit . . . | hold 2,000 money |
| money_4x | Belajar Menabung | hold 4,000 |
| money_6x | Kita kaya! | hold 6,000 |
| money_8x | Seorang CEO yang menyamar . . . | hold 8,000 — prize: Wirausaha +5% |
| grade_7 | Sudah bukan pemula lagi nih! | pass Kelas 7 |
| grade_8 | Semangat dari Seorang Pembimbing . . . | pass Kelas 8 |
| grade_9 | Masa Depan yang Indah . . . | pass Kelas 9 (beat the game) |
| fast_1 | Sat-set! | 1 fast win |
| fast_3 | Pembimbing RB26 Turbo | 3 fast wins |
| fast_6 | Blitzkrieg di Banjarsari | 6 fast wins |
| fast_9 | Hilang dalam 60 detik | 9 fast wins |
| fast_12 | Panggil aku Bejo "The Flash" | 12 fast wins — prize: minigame timer +5% |

Renames requested by the user are applied (Pembimbing Legendaris, Calon
Sarjana S3, Kita kaya!, Belajar Menabung); PDF typos fixed (Profesional,
Einstein).

## Rules

- **Counted plays:** only a minigame actually played inside SchoolDay. The
  debug launcher, the debug force-outcome cheat and Skip do not count.
- **Perfect** = `BaseMinigame` rated the result 3 stars. BaseMinigame now keeps
  that rating in `last_result_stars` and the time left in
  `last_time_left_ratio` when it shows its result card.
- **Streak:** a perfect result adds 1; any other result resets it to 0. The
  best streak is what unlocks, so a streak broken later keeps its unlock.
- **Fast win** = a win with `time_left / time_limit >= FAST_WIN_TIME_LEFT_RATIO`
  (0.5). Games with no time limit (Badminton, Lomba Menari) never count.
- **Play all types:** distinct minigame names played per category, against
  `PLAY_ALL_REQUIRED` (Akademis: Menjodohkan, Variabel, PilihanGanda, Password;
  SeniBudaya: BuatBatik, LombaMenari; Olahraga: MainBola, Badminton).
- **Money:** `GameState.player_money` at or above `MONEY_BASE` (1,000) × 2/4/6/8,
  checked on every `money_changed`. Starting money is 0, so the PDF's
  "N× starting money" had no number; the base is ours to tune.
- **Grades:** `RunResult._apply_progression()` reports a passed grade before
  advancing.
- **Claiming:** only an unlocked, unclaimed achievement can be claimed. Prizes
  apply only once claimed, and stack (both Wirausaha prizes = +10%).
- **Prize hooks** (none touch `Balance.gd`): minigame stat gain in
  `StudentData.apply_minigame_result` (wins only); Wirausaha payout in
  `SchoolDay._pay_out_wirausaha`; shop price in `Cart.total_of` and the
  shelf's displayed/affordable price; timer in `BaseMinigame.start_minigame`
  (only when a time limit exists).

## State

A new `@tool` autoload, `Achievements` (`Scripts/Achievements/Achievements.gd`),
holds `minigames_played`, `current_streak`, `best_streak`, `fast_wins`,
`played_names` (category → names), `unlocked` and `claimed`. It is saved to
`user://achievements.cfg` on every change and loaded in `_ready`, both skipped
under `Engine.is_editor_hint()`, following `GameSettings`. The user approved
this persistence. Debug **Forget Session** also clears it. The list itself is
data in `AchievementCatalog.gd`.

Consumers that cannot hold a node (static `Cart.total_of`, the `StudentData`
Resource) use `Achievements.gd`'s static `multiplier(kind)` helper, which
returns 1.0 when the autoload is absent.

## Screens

- `Scenes/Achievements/achievements.tscn`: full-rect blurred background, then
  `SafeAreaMargin` → `UI` → ribbon (top), a `ScrollContainer` list, and the
  white back arrow (bottom-left). Rows are `AchievementRow.tscn` instances.
- `AchievementRow.tscn`: a Panel (`AchievementCard` / `AchievementCardClaimed`
  variations), icon, title (`AchievementTitleLabel`), a black rule,
  description (`AchievementDescLabel`), and `Klaim` (`AchievementClaimButton`).
- `Scenes/Achievements/AchievementToast.tscn`: an autoload CanvasLayer
  (layer 120). It queues unlocks and shows one banner at a time.
- Lobby: `AchievementButton`, a 96×96 TextureButton in BottomBar's top row,
  at x 400–496.

## Not doing

Thea skin (no skin system; the card says "Segera hadir"). Level Selection is
already unlocked by beating the game. No progress bars on locked cards. No
settings reset button.

## Tests

`test_achievements` (new): the catalog, unlock rules, streak reset, fast wins,
money thresholds, claiming, multipliers, save round-trip.
`test_achievement_toast` (new): queueing, and the scene contract.
`test_tall_screen_layout`: the new screen's background and safe area.
