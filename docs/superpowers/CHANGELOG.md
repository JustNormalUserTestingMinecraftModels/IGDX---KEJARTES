# KejarTes — change log

Completed work, newest first. This file is **not** loaded into Claude Code
sessions; `CLAUDE.md` is. Anything here is history — read it on demand when you
need to know why something is the way it is.

Facts that still govern how you work on the project belong in `CLAUDE.md`, not
here. Unfinished placeholders and
deferred items belong in `docs/superpowers/DEBT.md`. See `CLAUDE.md`'s `## Maintaining this file`.

## 2026-09-21 — Minigame type ladder

A `/design-audit-ui` pass over Menjodohkan, the Shop, Variabel, Password,
PilihanGanda, BuatBatik, Badminton and Achievements. Shop and Achievements came
back clean and were left alone — both already ran `ThemeFactory` variations.
The six minigames carried **25 hand-written text sizes** between them (14, 16,
18, 26, 30, 32, 36, 40, 44, 48, 60, 70, 80, 90), of which only five were token
rungs.

**φ was already in the tokens.** The ask was to re-space the type scale at
×1.618. Doing that to `DesignTokens.gd` would give 28/45/73/118, change every
screen in the game on rebake, and overflow Boohong's tracking on a 1080px
canvas. It was not needed: `font_title` 36 → `font_h1` 64 →
`font_display_size` 96 runs 1.78 then 1.50, a geometric mean of **1.63** — φ
within rounding, already baked, and already used by `MinigameScoreHUD`. So the
change was subtractive: seven new variations, three rungs, nothing else.

**The shared card was the lever.** `QuestionCard.tscn` (and its sibling
`AnswerCard.tscn`) were already instanced by Password, Variabel and
Menjodohkan. PilihanGanda joined them, so fixing the cards' typography once
fixed four screens. Both cards grew 850×480/430 → 850×960 with a 620px image
slot, sized off the real art: `monas.png` is 1080×1920 and `borobudur.png`
1920×1920, so a short wide slot would have letterboxed them to a narrow column.

**PilihanGanda's layout had two real bugs**, both cured by the move. The image
sat *above* the progress counter, which sat above the question — so "Dari
gambar di atas…" pointed at a picture with the score wedged between. And the
script toggled the image's `visible` inside a centre-aligned `VBoxContainer`,
so the whole stack re-centred between questions and the choice buttons moved
under the player's thumb mid-game. The counter became the card's "Soal N/M"
badge, which is what `SoalFit` was built around.

**Contrast, measured.** Four inks could not reach the 4.5:1 body floor on any
ground: Menjodohkan's two wheel headers and both cards' borders, at relative
luminance 0.27 (orange) and 0.21 (blue) — 3.3:1 and 4.0:1 against *pure white*,
falling toward 1.5:1 on the cards they sat on. They became `brand_primary`
(7.2:1) and `cat_akademis` (5.1:1), keeping the warm/cool split. BuatBatik's
two layer labels shipped at **16px**, 57% of the body floor, one of them the
only feedback telling the player they stacked the layers wrong.

**Also retired:** three `🔒` emoji locks (CLAUDE.md bans emoji iconography —
they became `icon_lock.svg`), BuatBatik's `⚠` glyph (neither house font carries
it), two copies of a four-branch 90/80/70/60 if-chain plus a third literal
(all three now call `SoalFit`, which measures how text actually wraps),
PilihanGanda's 100px choice rows (→ 130, the ~48dp touch floor), and
Badminton's `ScoreHUD` at a raw (390, 40) offset (→ top-centre anchored).

`SoalFit`'s `FALLBACK_BOX` was corrected from 699×333 to 802×268 — it had been
describing a 715×345 card that grew to 850×480 some time before this pass.

Four existing pins moved with the architecture rather than being deleted:
`minigame_art`'s `H2Label` assertion, its display-font and wood-table ink
tests, and `theme_factory`'s `DISPLAY_ROSTER`. New suite:
`tests/test_minigame_typography.gd` (18 tests).

## 2026-09-19 — Weekly Results mockup pass

Spec `docs/superpowers/specs/2026-09-19-weekly-results-mockup-design.md`, plan
`docs/superpowers/plans/2026-09-19-weekly-results-mockup.md`.

- ResultCheckup opens under the red WEEKLY RESULTS ribbon
  (`title_weekly_results.png`, orphaned since the 2026-09-16 revert, now
  `TitleRibbon`); the EVALUASI MINGGUAN SISWA title and subtitle, and their
  exports, are gone.
- `WeekRecapBanner` is a butter-yellow panel (`recap_banner_fill`) of three
  near-white tiles (`recap_tile_fill`), left to right money, minigames, events;
  each `WeekRecapPill` now stacks its icon over its number in a `Column`. The
  Poin tile and the MINGGU/grade line are removed (`WeekRecap.compute` still
  returns `net_skill_delta`). Minigames wear `ResultCheckup/icon_minigame.png`
  (the soccer ball), events `icon_event.png` (the checklist notebook); money
  keeps `icon_uang.svg`. All three numbers are `text_primary` with a white rim.
- Logs wears the new `ResultLogsButton` (`result_logs_fill` `E0574B`, the
  ribbon's red lightened); Selanjutnya keeps the brown `ResultButton`.
- Every `DaySummaryStudentRow` takes PR #53's (`feat/weekly-results-polish`)
  cream `IdCardPanel` card with the brown striped `RecapMastheadPanel` name
  band, so the weekly and daily cards match and SchoolDay and the event picker
  follow; the card is 992×486 (was 410) and `StudentCardButton`'s design size
  follows. PR #53's masthead, stars row and popup changes were not taken, so
  that PR is superseded.
- Every result star is `Assets/Images/UI/star.png` (the artist's star padded
  to 360×360): StatCheck's meter (`nine_patch_stretch` into its 180 px
  cells), the event student card, and `ResultStar`'s filled and empty
  defaults. `popup_star_color` defaults to white so the art keeps its gold.
  `icon_star.svg`, `icon_bintang.svg` and `icon_bintang_kosong.svg` are
  deleted.
## 2026-09-19 — Lobby student chatter and blinking

Spec `docs/superpowers/specs/2026-09-19-student-chatter-design.md`, plan
`docs/superpowers/plans/2026-09-19-student-chatter.md`.

- Tap a seated student and they say a line in a chat bubble that pops out of
  their own seat; after 20–50 s without a tap, a random student (never the
  previous idle speaker) talks on their own. One bubble, one speaker: taps
  are ignored while it shows and for 0.5 s after, so spam leaves the line
  untouched. Muted during the tutorial, the daily reward and the skin picker.
- Lines (`StudentChatterCatalog`): 8 per personality and 8 per quirk, so 16
  per student, plus 6 each for `LELAH` (energy ≤ 30), `BETE` (mood ≤ 30) and
  `SENANG` (mood ≥ 75), drawn 40% of the time while a state applies.
  `StudentChatterPicker` shuffle-bags each pool per student: nothing repeats
  until the pool is spent.
- `StudentChatBubble.tscn` (`StudentChatBubble` / `StudentChatText`
  variations) lands its tail tip on the seat's `ChatAnchor`, mirrors the tail
  for left-hand seats, clamps inside the visible screen and pops in/out from
  that tip. It is a root child right after `Safe`: under `Classroom` the
  KELAS title drew over it.
- Tunables: `LobbyChatter.idle_min_s`/`idle_max_s`/`tap_cooldown_s`,
  `StudentChatBubble.linger_s`, `StudentChatterCatalog.STATE_CHANCE` and the
  mood/energy thresholds; the four `ChatAnchor` positions in `loby.tscn`.
- The face rigs blink: idle blinking is on, each rig rolls its own 5–10 s
  wait, and the `Eyelid` layer fades in 0.05 s, holds 0.08 s and fades out.
  The DEBT entry that held blinking back is gone.

## 2026-09-18 — Skin system

Spec `docs/superpowers/specs/2026-09-18-skin-system-design.md`, plan
`docs/superpowers/plans/2026-09-18-skin-system.md`.

- Each of the six students has a `default` and a `skin1` look
  (`Scripts/Skins/StudentSkins.gd`, paths by convention under
  `Assets/Images/Skins/<Name>/`). `GameState.equipped_skins` /
  `skin_unlock_overrides` hold the session's choice; `equip_skin` refuses a
  locked skin. Skins are keyed by name and survive grade changes.
- Splash, flat portrait, lobby face-rig base and desk hands all resolve
  through `StudentSkins`; AturJadwal, StudentCard, StudentList, the Lobby and
  the `StudentData` bridge (DaySummary, EventDialogue, StatCheck) show the
  worn skin. WinStage / WinLineup / RunResult keep their own art.
- Lobby `SkinSwitchButton` opens `SkinSelectPopup`: blurred Lobby, up to four
  roster cards (`SkinSlot`, masked `SkinFrame`), SETUJU; tapping a card opens
  a scrollable column of `SkinOptionTile`s over it with a second, lighter
  blur (`BackBufferCopy` + `skin_option_blur_material.tres`). Locked tiles are
  darkened and disabled. Closing re-seats the Lobby.
- The flat Skin1 portraits were baked from the face rigs by
  `Scripts/Skins/BakeSkinPortraits.gd` (default bakes match the shipped
  portraits to <0.011 mean difference, except Shinta at 0.031: her shipped
  portrait is a darker grade than her rig art).
- Debug › General › **🎨 Kunci/Buka Semua Skin** locks every non-default skin.
- The Lobby's breathing tween is now bound to the node it animates, so
  re-seating no longer leaves a looping tween on a freed face rig.

## 2026-09-18 — Achievements polish

Plan `docs/superpowers/specs/2026-09-18-achievements-polish-plan.md`.

Whole-branch review fixes on top of the grid/pill/sheet rework:

- `AchievementTile._gui_input` now emits `tile_pressed` on release (within a
  small move threshold of its press), not on press, and the root's
  `mouse_filter` moved from STOP to PASS so the parent `ScrollContainer`
  still receives a drag that starts on a tile -- previously every
  drag-scroll on the 26-tile grid opened the detail sheet.
- The status pill's tap-to-jump now switches the filter back to "Semua"
  before scrolling when the first unclaimed achievement is hidden by the
  active filter, deferring the actual scroll a frame so the grid has
  re-laid out.
- Android back now closes an open `AchievementClaimPopup` before the detail
  sheet underneath it, then the sheet, then leaves the screen.
- `AchievementStatusPill` re-centres its pivot on `resized` (and again
  before its morph/breathe tweens start), instead of only once in `_ready`
  before layout has run -- fixes a scale-pop from the corner.
- `Achievements.total_unclaimed_gold()` renamed to `total_unclaimed_count()`
  throughout, matching what it actually returns.
- `Achievements.relock(id)` is now a no-op (no save, no signal) for an
  unrecognised id.
- New thin `AchievementTileBar` `ThemeFactory` variation for the tile's
  progress bar -- the shared `StatBar` variation's min height was winning
  over the tile's 4px override, rendering the bar ~36px tall.

Deliberate decisions carried from the plan: the waiting pill counts
"hadiah" (unclaimed rewards) rather than a G amount, because the catalog's
prizes are effect labels, not currency; there is no tier ladder
(Perunggu/Perak/Emas has no art); `icon_outline.gdshader` also got a fix on
this branch, to clear a CI project-check shader ERROR unrelated to the
polish work itself.

## 2026-09-18 — Koperasi polish pass, plus a tap-spam guard

Plan `.superpowers/sdd/2026-09-17-koperasi-polish-plan/`, spec
`docs/superpowers/specs/2026-09-17-koperasi-polish-design.md`.

Five polish passes on the Koperasi shop, closed out with a three-layer
tap-spam safeguard and a final whole-branch review:

- ShelfItem items get a soft plank shadow, a per-item idle bob, a lift +
  gold rim glow on purchase, and an affordability dim that now survives a
  shelf-debounce lock/unlock cycle correctly (a slot that goes unaffordable
  mid-flight no longer snaps back to full opacity when it unlocks).
- Herman's speech bubble (`ChatBubble.gd`) drives a small state machine off
  `DialogueCatalog` lines, with a per-event cooldown and randomised idle
  chatter that mutes (not pauses) while the basket tray is collapsed and
  re-arms on expand.
- The basket tray's crate handle, back button and idle chatter all follow
  the tray's expanded/collapsed state through one shared tween per gesture.
- Stock pips (`PipRow`, `pip_filled.svg` / `pip_hollow.svg`) show
  remaining/total copies per shelf slot; `GameState.SHOP_MAX_COPIES` went
  2 → 3 to make pairs-and-triples possible.
- Tap-spam guard: `ShelfItem._locked` debounces a single slot,
  `Cart.MAX_ADDS_PER_FRAME` caps same-frame adds across the whole cart, and
  `ChatBubble`'s per-event `SAY_COOLDOWN` stops repeat dialogue. `Cart.add_item()`
  now returns whether the unit actually landed, and `rakbarang_1.gd` calls it
  *before* committing the shelf slot / tray hold / flight tween, undoing them
  on a dropped add instead of spawning a flight for a unit the cart never
  received. The taken-slot check in `_on_barang_pressed` also now runs before
  the shelf-debounce lock, so a dead tap on an already-sold slot always
  reaches Herman instead of sometimes being swallowed by the lock.

Deliberate deviations from the plan/spec: the back button's expanded-state
gap is 18px, not the spec's 12px (`tests/test_tall_screen_layout.gd` pins
the real `BackButton` rect); the crate at `scale = 0.35` renders ~112px
against the 128px tray emblem (tracked in `docs/superpowers/DEBT.md`,
not yet reconciled to a matching size).

## 2026-09-17 — Achievement claim celebration, Lobby Settings

Plan `docs/superpowers/plans/2026-09-17-achievement-claim-celebration.md`, spec
`docs/superpowers/specs/2026-09-17-achievement-claim-celebration-design.md`.

- **Klaim** opens `AchievementClaimPopup`: the screen blurs (shared shop-hub
  blur), "SELAMAT, ANDA MENDAPATKAN", the icon large over
  `achievement_glow.gdshader` (additive, counter-rotating flickering rays and
  a pulsing core), the title, paper confetti, and tap-anywhere to close.
- Every achievement icon wears `icon_outline_material.tres`, a shader that
  shrinks the art and rings its alpha in white.
- Debug: `Achievements.RESET_ON_LAUNCH` wipes progress on every launch.
- The Lobby's Shorten button and `ShortenPanel` are gone. A Settings gear
  (`setting.png`) opens the existing Settings screen, which gained a "Lewati
  Dialog Minigame" toggle and returns to wherever it was opened from.

## 2026-09-17 — Koperasi revamp: Pak Herman's counter

Plan `docs/superpowers/plans/2026-09-17-koperasi-shop-revamp.md`, spec
`docs/superpowers/specs/2026-09-17-koperasi-shop-revamp-design.md`.

Koperasi opens on a three-layer counter (background, Pak Herman, glass case)
pinned to the bottom edge, with a flat wall strip above on tall phones. Six
shelf slots sit on the mockup's circles. The weekly roll draws from a bag of
every item twice, so pairs turn up (~71% of weeks) and each copy sells once.
`rakbarang_1.gd` tracks which slot emptied (`reconcile_taken`), leaving `Cart`
and the basket tray unchanged. A placeholder speech bubble uses the new
`ShopChatBubble` variation. The coin HUD moved onto the counter ledge inside
the Stage, because a bottom-anchored HUD in `Safe` rode the editor run's
768 px safe-area inset onto Herman's forehead. The "KEBUTUHAN SEKOLAH"
landing and its pop-up are gone.

## 2026-09-17 — Achievements

Plan `docs/superpowers/plans/2026-09-17-achievements.md`, spec
`docs/superpowers/specs/2026-09-17-achievements-design.md`.

- 26 achievements from the design PDF (`AchievementCatalog.gd`), tracked by the
  `Achievements` autoload and saved to `user://achievements.cfg`, the one save
  added on the user's request. The renames the user asked for are applied.
- Reported from SchoolDay (real plays only: stars and time left now kept on
  `BaseMinigame`), RunResult (grade passed) and `GameState.money_changed`.
- Klaim turns a prize on: minigame stat +5%, Wirausaha +5% twice, shop -10%
  (`Cart.price_of`) and minigame time +5%.
- Lobby trophy button, the `achievements.tscn` screen (row template
  `AchievementRow.tscn`) and the `AchievementToast` unlock banner autoload.
  Ribbon and back arrow are cut from `Achievement mockup.psd`; the claimed
  card is a baked 9-slice. Drive icon file names were wrong for the
  play-all, three-star and speed sets, so they were matched by colour against
  the artist's board.

## 2026-09-16 — Papan tulis, Rapor's fill and the Belajar button

Plan `docs/superpowers/plans/2026-09-16-papantulis-rapor-belajar.md`, spec
`docs/superpowers/specs/2026-09-16-papantulis-rapor-belajar-design.md`. Phase 2
of the 2026-09-15 tall-phone pass, for the two screens the user asked for.

- **AturJadwal's board** is `papantulis.png`, the same art as `whiteboard.png`
  with its shelf 493 px higher in the frame, so 1570 px of board hangs below it
  instead of 1077. `BGHari` stops being a full-rect node that stretched 1.25×
  on a 20:9 phone (sliding the baked shelf from y 766 to 957, doubling the
  `ShelfFace`/`ShelfEdge` `ColorRect`s) and becomes a fixed 1080×1920 picture
  unit at offsets `(0, 493, 1080, 2413)`. 493 = 766 − 273 puts the art's baked
  shelf exactly on the `ColorRect`s, and the 1:1 draw is what keeps them
  coincident — any scale slides the bands out and thickens the dark edge. The
  five sticky notes lost 493 from their offsets and ride the board as one
  piece. A new `BoardFill` `ColorRect` (`#E0E0E0`, the art's bottom-centre
  tone) runs from y 843 to the screen bottom behind the board, so a 21:9 phone
  at 2520 is covered too. Verified in the running game at 1080×2400.
  `whiteboard.png` is now unreferenced.
- **Rapor** was StudentCard before the tall-phone pass: a root inset by
  70/254/−77/−352 with every child carrying a negative offset that cancelled it
  back out, so a 1080×2400 screen showed 480 px of empty grey below the desk.
  The inset is gone, `Backdrop` is Full Rect and Keep Aspect Covered, the six
  papers are Center-anchored at ±540/±960, and the page arrows and page label
  moved into a `Safe`/`UI`/`BottomBar` group copied from StudentCard's. The
  five moved nodes carry `unique_name_in_owner`, so `report_card.gd` reads
  `%NextButtonKanan` and friends and no longer depends on where they sit.
- **StudentCard's BELAJAR button** had two compounding faults. Phase 1 pushed
  every child's offsets by the root's old (70, 254) inset and left this one in
  position mode, putting its rest rect at y 1994 — 74 px below a 1080×1920
  screen. It is now Center-anchored with the paper, like `StampApprove`.
  `_transition_page` then tweened it to exactly that stale rect, undoing the
  shift that had just placed it beside Aprove/Batal; that tween is gone, and
  the reveal belongs to `_shift_approve_for_belajar` alone. Removing it exposed
  a third fault underneath: `_transition_page` parks the incoming card a full
  screen-width off to the side and calls `_update_nav_buttons` — and so the
  shift — while it is still parked, so the target landed at x 1640 on a
  1080×2400 phone. The shift now reads the card's `original_position` meta, the
  same settled value `_transition_page` tweens it to.

**Still open on these screens.** AturJadwal's wall backdrop, top band and
`StartWeek` are the rest of Phase 2 and untouched, so a tall phone shows board
below `StartWeek`. Rapor's `KEMBALI` button still covers its "Rapor Murid"
title; both nodes kept their current screen rects here, because every fix for
it is a judgement about the screen's composition rather than a consequence of
this restructure. It stays filed in the Phase 1 spec's out-of-scope list.

## 2026-09-16 — Kalkulator for Variabel and Password

Plan `docs/superpowers/plans/2026-09-16-kalkulator-akademis.md`, spec
`docs/superpowers/specs/2026-09-16-kalkulator-akademis-design.md`.

- **Variabel** and **Password** now sit on `meja_background.png` (like
  Menjodohkan), show the question on Menjodohkan's `QuestionCard.tscn`, take
  input from a drawn calculator, and submit through **Hapus** / **Kirim**
  (`LobbyCtaButton`). Password's `background_texture` export had been painting
  `lapanganBadminton.jpg` over the desk at runtime.
- The calculator is shared: `Kalkulator.tscn` (an `AspectRatioContainer` at the
  body art's ratio, a green LCD label, a 3x3 key grid and a `show_zero_key`
  row that Variabel hides) instancing ten `KalkulatorKey.tscn`. A key squishes
  toward its bottom edge and darkens while held, opts out of `UIPolish`, and
  shows its digit in the heading face, white.
- Question text is fitted by measurement (`SoalFit.gd`), not a size ladder: the
  planned ladder clipped Variabel's last line on the first playtest. It
  refits on `resized`, since the first question is set before layout.
- Both numpads were built with `Button.new()`; they are authored nodes now.
  `viewport_editability` BASELINE: Password 4 → gone, Variabel 4 → 1 (the
  `+20s` popup).
- Textures arrived at 7458x10265 and 1716x1620 and are stored downscaled in
  `Assets/Images/UI/Kalkulator/` (1080x1487, 360x340).

## 2026-09-15 — Weekly shop and minigame polish

Plan `docs/superpowers/plans/2026-09-15-weekly-shop-minigame-polish.md`, spec
`docs/superpowers/specs/2026-09-15-weekly-shop-minigame-polish-design.md`.

- **Koperasi** rolls its four items once per week (`GameState.shop_stock_for_week()`,
  keyed by grade and `minggu_ke`) instead of on every visit. Each item sells
  once a week: it leaves the shelf when it goes into the basket, comes back if
  it is held out or the player backs out, and stays gone after Beli
  (`GameState.shop_sold`). Session-scoped, like the rest of GameState.
- **LombaMenari**'s hit window is 170 px (BAGUS) and 70 px (SEMPURNA), up from
  120/45, and a note is only missed once it leaves the whole window -- it used
  to be dropped 80 px past centre, so late hits were impossible. Feedback is
  UPS!/BAGUS!/SEMPURNA!; the dancer draws behind the hit zone.
- **Win screen**: WinStage puts the painting on a white `PhotoFrame` print
  (new ThemeFactory variation); RunResult opens on the same framed picture.
- **MainBola**: an off-target shot ends in the keeper's hands, and the target
  box respawns somewhere new (x and height) after every goal.

## 2026-09-16 — Weekly Results: tabs out, Logs and Selanjutnya in

Plan `docs/superpowers/plans/2026-09-16-weekly-results-hybrid.md`, spec
`docs/superpowers/specs/2026-09-16-weekly-results-hybrid-design.md`.

Immediately after the revert below, the screen keeps its banner, pills,
header and student cards but loses the SISWA / RIWAYAT tabs and gains the
rebuild's two-button row: **Logs** and **Selanjutnya**.

The week's history is not dropped — it moves. `initialize_checkup` keeps a
duplicate of `minigame_history`, and `open_logs` hands it to `WeekLogsPopup`.
That sheet has existed and been covered by `week_logs_popup` all along: the
2026-09-14 rebuild borrowed a popup that was already orphaned, the revert
re-orphaned it, and this borrows it back.

**What went.** `TabBar`, `HistoryPane` and the `PaneStack` that held them;
`StudentsPane` now sits directly under `ScrollContainer`. In the script: the
`Pane` enum, `PANE_SLIDE_DISTANCE`, `show_pane`, `_transition_panes`,
`_sync_tab_buttons`, `_update_tab_counts`, `_play_history_entrance`, and the
four vars behind them.

**What came back.** The `Buttons` row — `ResultButton`, 160 tall, separation
120, both `size_flags_horizontal = 3` so the row splits equally, because the
display face sets SELANJUTNYA in capitals and needs about 435 px. Plus
`logs_popup_scene`, `open_logs`, `_history`, `_logs_seen` and `_logs_popup`,
lifted unchanged.

**The entrance's finale** now fades in both buttons and enables each only
once it is visible — the rebuild's own rule, so a tap meant for something
else cannot land on a freshly-enabled button. `_on_close_pressed` disables
both before its fade, so a second tap during the exit can neither re-fire nor
open Logs.

**Retired one commit after being restored:** the `WeekTabButton` variation
(with a rebake) and the `pane_swipe` cue with its `.ogg`. Both existed only
for the tabs. The three pill/banner variations and the three pill cues stay,
because the pills stay.

**Debt resolved.** `ResultButton` and `WeekLogsPopup` both have call sites
again, so two of the three orphans the revert recorded are gone from
`DEBT.md`. `title_weekly_results.png` is still orphaned and still kept.

**Tests.** The six tab and pane tests — default tab, pane visibility, the
two scroll-memory tests, the history latch, and the two transition tests —
are deleted with the feature rather than adapted: there is nothing left to
assert. Five replace them, covering the sheet's wiring, both labels, the
`ResultButton` variation, the no-second-sheet rule and the first-open latch,
plus a scan that the tab machinery is really gone.
`viewport_editability`'s entry for this screen stays at 1: it was earned by
building history rows and is now earned by instancing the sheet, checked by
removing the entry and reading what the suite asked for rather than assuming.

Suite: 114 suites, 1632/1637 — the same totals as the revert below, because
the six deleted tests were replaced one for one. The five failures are
`inventory` (2) and `light_ground_text` (3), pre-existing on `Textures` from
PR #48.

## 2026-09-16 — Weekly Results reverted to the 2026-09-03 report

Plan `docs/superpowers/plans/2026-09-16-revert-weekly-results.md`, spec
`docs/superpowers/specs/2026-09-16-revert-weekly-results-design.md`.

The end-of-week screen goes back to the design that stood before 2026-09-14:
`EVALUASI MINGGUAN SISWA`, the SISWA / RIWAYAT tabs with their slide-and-fade,
the pinned `WeekRecapBanner` with its tappable pills and info popup, the
RIWAYAT pane of `WeekHistoryRow`s, `CoinShower`, and `Selesai Evaluasi`. Out
go the red ribbon, the coins / EVENT BERHASIL / EVENT GAGAL lines, the Logs
and Selanjutnya buttons, and `WeekReportReveal`'s one-reward-at-a-time
playback with tap-to-skip.

**The confetti was never part of the redesign**, which is why this was a
revert and not a rebuild. `PaperConfetti.tscn` landed on 2026-09-12 in
`c346f62`, two days *before* the rebuild in `27ce108`, and the 2026-09-03
screen already instances it from the same `_CELEBRATION_SCENE` constant, at
the same `Celebration` position, behind the same "did any card gain ground"
gate. Nothing was ported; the scene and `paper_flutter.gdshader` are
untouched. The old call passes the cards' stagger as a delay, so the burst
lands just behind the last card's own fill again.

**Three things were deliberately kept.**

- `initialize_checkup(manager, week_earnings)`. SchoolDay pays the Wirausaha
  total out — which empties `GameState.pending_earnings` — before it opens
  the screen, so `WeekRecap._sum_pending_earnings` reads 0 by then and the
  banner's money pill would show nothing the player earned. `DebugManager`'s
  📊 Laporan Mingguan also calls the two-argument form. A non-zero argument
  overwrites `money_earned`; a caller that has not paid out yet omits it and
  keeps WeekRecap's own read. Two doc comments that still claimed the screen
  runs *before* the payout were corrected rather than reverted.
- `Juice.punch` / `text_center` / the paced count, and `play_sfx`'s optional
  pitch. Both landed under weekly-reveal commits but are general utilities on
  shared autoloads with their own coverage.
- `DaySummaryStudentRow` and `DaySummaryStatRow`. Today's card is a superset
  of the API the old screen drives, so it needed no change at all;
  `rewind_week`, `play_needs_week`, `land_week` and `play_count` are simply
  unused by this screen now.

**Why it was done per file.** The redesign is eight commits — `27ce108`,
`6043538`, `e7fc308`, `205e3eb`, `feebf96`, `4911165`, `dc5c4d7`, `c9c8ef9` —
but they are interleaved in history with the face rigs, lobby buttons, exam
CG, the inventory redesign and the mobile perf pass, so no range revert was
available. Files only the redesign touched (`ResultCheckup.tscn`, its script
and suite; `WeekRecap.gd` and its suite) were restored wholesale from
`27ce108^` / `e7fc308^`. The twenty files `e7fc308` deleted came back from
`e7fc308^`. `ThemeFactory.gd` and `AudioDirector.gd` were patched by hand,
because `12461f1`, `6c9f873`, `d33c62f`, `fd3bba7`, `63eff34` and `85a2c3f`
have edited them since; the restored code sits alongside that work.
`kejartes_theme.tres` was regenerated by `BakeTheme.gd` and verified by
content, never hand-merged.

**Caught on the way.** Two files the plan had not listed still carried the
new layout: `test_school_day`'s touch-target map named
`Margin/Layout/Buttons/LogsButton`, and `viewport_editability`'s `BASELINE`
had lost this screen's entry. Both were put back to what `27ce108` changed
them from — the ratchet entry restored to the `1` the 2026-09-03 screen
legitimately had, not raised. `ResultButton` was kept despite losing its
only call site, because `lobby_style_buttons` asserts it; that, the ribbon
art and the re-orphaned `WeekLogsPopup` are recorded in `DEBT.md`.

Suite: 114 suites, 1632/1637. The five failures are `inventory` (2) and
`light_ground_text` (3), pre-existing on `Textures` from PR #48's inventory
redesign — they survive a clean editor restart and full rescan and are
unrelated to this branch.
## 2026-09-16 — `/gamecode`'s review gate moves from the design to the plan

The Brief is gone. Brainstorm, branch, spec and plan now all run unattended,
and the single pre-code gate is a **Plan Summary** (§4) — the user reviews a
concrete plan instead of a design sketch, still before any code is written.
"Ship it?" is unchanged.

§4 is a contract, not a hint: 200 words or fewer, the user's language,
repo-relative paths, one line per task, and a **required** `Paling perlu
dilihat` line naming the single guess most likely to be wrong — usually an
invented tuning number — with its cheaper alternative and what changing it
costs now versus after the tests are written.

The cap and the contract came out of testing. Three agents told only to "give
a quick and clear summary" all stopped correctly, but wrote 400, 380 and 330
words; one pasted absolute Windows paths, and the language drifted between
English and Indonesian across reps. Against the written §4 the same three
scenarios produced 167, 158 and 160 words, all Indonesian, all repo-relative,
each with a real `Paling perlu dilihat`. The element worth keeping was one all
three invented on their own: naming the number they had guessed.

`/gamecode-instant` follows the gate. It is still "`/gamecode` minus the wait",
so its Receipt collapsed into the same §4 message, sent and never awaited —
the two files now differ by one pause.

## 2026-09-16 — `/gamecode-instant`, the unattended variant of `/gamecode`

`.claude/skills/gamecode-instant/SKILL.md`. Same pipeline as `/gamecode`, with
the design gate removed: the Brief becomes a Receipt that is sent and never
awaited, so brainstorm → spec → plan → build runs in one turn.

It delegates to `/gamecode` rather than restating it, and overrides only the
gates. Written against a baseline: three agents given the idea without the
skill all correctly refused to wait for approval, but produced five different
stop lists across three runs — `Balance.gd`, refactors, red suites, new
persistence, pinned test baselines, a dirty tree, force-killing Godot. An
unattended run would have parked on a different thing each time.

So the skill's core is a **closed list of five stops** (ship, `Balance.gd`,
new persistence, a pinned invariant, someone else's uncommitted work) beside a
table of nine things that look like stops and are not. Re-run with the skill,
all three reps converged on exactly that list and on the same worktree call.

"Ship it?" survives, because pushing hands the branch to `ci/auto_merge.sh`
unattended; `--ship` in the invocation is that permission given in advance.
A harness permission prompt still pauses a run — an allowlist question, named
in the skill so it is not re-litigated mid-run.

## 2026-09-15 — Tall phones, Phase 1: Lobby, Koperasi, StudentCard, StudentList

Plan `docs/superpowers/plans/2026-09-15-tall-phone-layout-phase-1.md`, spec
`docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`.

A 20:9 phone runs the game at 1080×2400, and these four screens were laid out
for exactly 1080×1920. Their fixed backgrounds left a bare gray band, and the
Lobby's classroom slid down while the seats stayed put, so the students sat
at the wrong desks. The editor never showed it, because its embedded run is
locked to 9:16. Each screen now follows four rules:

- the background fills;
- the UI is re-anchored to its edge, without moving, inside a
  `SafeAreaMargin`;
- a picture keeps its items.

At 1080×1920 nothing moved.

- **Lobby.** `Classroom` holds the background, desks, seats and hands,
  Center-anchored at 1080×1920 over a black `Backdrop`. The title and
  button block sit in `Safe/UI`. `loby.gd` uses unique names, and the
  reward blur is inserted at `DailyReward`'s index.
- **Koperasi.** The room covers. The shelf view moves as one piece pinned
  to the bottom, so the tray reaches the edge. The coins sit in the safe
  area.
- **StudentCard.** The root's 70/254 inset is gone. The papers and stamp
  are centred, and the page row pins to the bottom.
- **StudentList.** The cards are centred. The header and strip sit on top,
  and the nav row at the bottom.
- **Tests.** New `tests/layout_frame.gd` settles Containers in the same
  frame, and new suite `tall_screen_layout` checks each screen at
  1080×2400 and 1080×1920. Placement asserts compare authored rects, because
  the editor's font metrics grow some controls past theirs. `lobby_layout`
  and `student_card_layout` now stand their screens up the same way.
  `SafeAreaMargin` now warns only on a device.
- **Desktop preview:** works. A 360×800 window override gives the embedded
  run a 1080×2400 viewport; set it back to 640 afterwards.
- **Caught on the way.** Moving an instanced scene with `reparent_node`
  re-owned its internals, and the save duplicated StudentList's avatar
  `Portrait`/`Ring` nodes; they were removed by text (authoring guide,
  "Tall phones"). A `"%RosterStrip/Avatar%d" %` lookup read `%R` as a format
  character; it is now `%%` and guarded by a scan. Two failures already on
  `Textures` were fixed in their own commits: `viewport_editability`'s stale
  `ItemDetailSheet` baseline entry, and `atur_jadwal.tscn`'s splash_marcel
  UID left behind by `c3149e0`. `Textures`' `6cac82b` fixed the same two in
  parallel; the merge kept one copy of each.

Suite: 111 suites, 1603 tests, green.

## 2026-09-15 — Two dead backdrops: the minigame quit dim and the event-picker photo

Both came from a read-only audit and were confirmed in the running game before
anything changed.

- **`QuitConfirmDialog` dimmed one pixel.** Its `Backdrop` is a full-rect
  TextureRect holding a 1x1 white fill tinted by `quit_dialog_bg_color` (or an
  artist's PNG), but it used `STRETCH_KEEP`, which draws a texture at its own
  size. Framebuffer samples outside the card did not change when the dialog
  opened; only (0,0) darkened. It now uses `STRETCH_SCALE`, as the hand-built
  dialog did before the 2026-08-31 extraction, and every sample drops to about
  25%. Suite `minigame_overlays`.
- **`EventStudentSelectDialog`'s photo never showed.** The scene has always
  set `background_texture` to `bg_event_dialog.png`, but
  `_apply_visual_exports()` looked up a `Background` node when the scrim is
  named `BackgroundDim`, so the Scrim always stayed. The photo now has an
  authored `Background` TextureRect (index 0, full rect, SCALE), and the
  script only chooses between it and the Scrim. The visible change is the
  16 px frame around the card, which now shows the pale photo instead of the
  dimmed day. That removed the file's last runtime `TextureRect.new()`, so its
  `viewport_editability` BASELINE entry and its line in the authoring guide's
  "Known gaps" are gone. The node holds no texture in the .tscn (the export
  fills it at runtime), so the editor still previews the Scrim. Suite
  `event_polish`, which also gained a general check that every node path the
  script names exists in its scene.

## 2026-09-15 — Debug: Laporan Mingguan preview

Plan `docs/superpowers/plans/2026-09-15-debug-weekly-report.md`, spec
`docs/superpowers/specs/2026-09-15-debug-weekly-report-design.md`.

The debug overlay's Scenes tab has a new button, **📊 Laporan Mingguan
(ResultCheckup)**. It opens the weekly report over the current screen,
filled with a fixed sample week, so the reveal can be watched in one click
instead of played for a week.

- **`WeekReportRehearsal`** (new, `Scripts/Debug/`) is a pure jig. It puts a
  ladder of skill gains onto a throwaway `StudentManager`: all three up; two
  up and one down; one up; flat. Energy falls 12 and mood rises 6, and the
  history holds three minigames (2 won, 1 lost) and one event. It hands back
  1.500 coins. Suite `week_report_rehearsal`.
- **`DebugManager._open_week_report_preview()`** approves the default roster
  only when none is approved, then builds the manager from `GameState`
  before the sample moves anything. It hosts `ResultCheckup` on its own
  `CanvasLayer` (124) under the current scene, and frees the manager once
  the report has read it. `checkup_closed` frees the layer.
- **The run is not touched:** the sample lives on the manager's `StudentData`
  copies. Checked live: money, week and the stored stats were unchanged.
- `EndGameRehearsal`'s debug-only ratchet now covers both jigs.
- Touch-feedback ripples (`TouchFeedbackManager`, layer 125) draw above the
  preview. That is by design; they were the only thing seen above it.

## 2026-09-14 — Lobby: Citra's eye whites plug their cut-outs

`CitraFace.tscn`'s Sclera sat 1 px high, at (427, 578). `citra_base.png`
has transparent eye cut-outs, and at that height 114 of their pixels were
covered by no layer, some at a combined alpha of 0.24. The Lobby background
showed through as a faint line along the top rim of each eye. Sclera now
sits at (427, 579), and the same solve moves Eyelid from (419, 578) to
(419, 579).

- **How it was solved.** Holes are the base's alpha < 128 regions that do not
  touch the image border. The sclera goes where its alpha best overlaps
  them (IoU), and that position is unique. At 579 the resting face leaves
  none of them see-through. The Sclera alone leaves two anti-aliased rim
  pixels at (438–439, 581), and the lashes cover those. A composite of the
  layers also matches the flat `Citra.png` better: mean abs error 5.70
  against 6.14 over the eye region.
- **Pinned.** `tests/test_student_face.gd` adds
  `test_no_eye_cut_out_is_left_see_through`, which counts 114 open pixels at
  the old position and 0 now. Citra's rig predates the roster suite, so
  that suite's matching check never covered her.
- **Left alone.** The same solve would move Eyebrows 1 px right and Pupil
  1 px up. That is cosmetic, so both stay where they are.
  `citra_eye_mask.tres`'s saved `mask_uv_offset` still reflects the old
  Sclera; `StudentFace` recomputes it on `_ready`.

## 2026-09-14 — Weekly report: one reward at a time

Plan `docs/superpowers/plans/2026-09-14-weekly-report-reveal.md`, spec
`docs/superpowers/specs/2026-09-14-weekly-report-reveal-design.md`.

ResultCheckup now opens on the backdrop alone and plays the week back one
reward at a time. Each card pops in, its needs bars travel, and the list
scrolls to it. Then its three stats count one after another, and each gain
punches its number and fires the `RewardBurst` from it. The coins, EVENT
BERHASIL and EVENT GAGAL lines follow in order, each popping when it lands,
and last come the confetti and the buttons. Every pop sounds one
`pitch_step` higher than the one before. A tap anywhere during the reveal
lands everything at once.

- **`WeekReportReveal`** (new) works out the whole timeline as data, before
  anything moves. `ResultCheckup` plays it through one parallel tween of
  delayed callbacks, so a skip is one `kill()`. Suite `week_report_reveal`.
- **The card's week API.** `DaySummaryStatRow` has `rewind`, `play_count`,
  `land_pop`, `land` and `shown_delta`. `DaySummaryStudentRow` has
  `rewind_week`, `play_needs_week` and `land_week`. Landing stops every
  tween the reveal started on the card, so a skip never leaves a number
  still counting over its final value. `play_gain` and the nightly popup are
  untouched.
- **Shared API.** `Juice.punch` and `Juice.text_center` are new;
  `count_up_formatted` takes a duration; `pop_in` and `count_up_formatted`
  return their tweens. `AudioDirector.play_sfx` takes an optional pitch.
- **Only gains pop.** A row that did not go up settles on a short, silent
  beat, and a zero summary line arrives reading 0. This is the game's
  standing no-gain-no-celebration rule.
- The pacing is a Reveal group of `@export`s on `ResultCheckup`. With the
  defaults, four gaining Kelas 9 students take about 9 s.

## 2026-09-14 — Lobby: layered faces for the whole roster

Plan `docs/superpowers/plans/2026-09-14-student-face-rigs.md`, spec
`docs/superpowers/specs/2026-09-14-student-face-rigs-design.md`.

Andi, Doni, Marcel, Shinta and Thea now get a `StudentFace` rig in the
Lobby diorama, like Citra's: `Scenes/Lobby/<Name>Face.tscn`, each with its
own `<name>_eye_mask.tres`, and `loby.tscn`'s `face_rigs` lists all six. The
art is in `Assets/Images/MuridPotrait/<Name>/<name>_<layer>.png`.

The layers came from the artist's Drive numbered 1-6 (7 for Marcel's
glasses) with no offsets, so every placement was solved against the
student's flat `MuridPotrait/<Name>.png` by a scratch Python solver. The
solver is not committed; `tests/test_face_rig_roster.gd` freezes its output.

- **Sclera and Eyelid** are pinned where they plug the base's eye cut-outs,
  and never nudged: a 1 px nudge opens a rim of cut-out and the lobby shows
  through.
- **Pupil, lashes and brows** are placed by evidence: the pixels a layer
  changes must agree with the portrait, inside a window near the eyes.
  Plain colour matching had put a black brow anywhere in Shinta's black hair
  and Doni's lashes on his chin.

Worth remembering:

- **The Drive numbers were not the stated order.** File 4 is the closed
  eyelid and 5 the lashes for all five students, and 2/3 are pupil/sclera for
  everyone but Andi. The names on disk follow the art.
- **Shinta's portrait is a darker grade** (about 25 per channel) of her base,
  and she shows one eye. Her matching ran through a per-channel recolour.
- **Marcel's glasses lens is additive** in his portrait (an alpha mix greys
  his eyes), while the frame is opaque. The new
  `Scripts/Shaders/glasses_lens.gdshader` uses `blend_premul_alpha`: the lens
  emits alpha 0 and adds light, the frame emits alpha 1. Its `lens_gain` of
  1.173 was fitted over cheek seen through the lens and lives in
  `marcel_glasses_lens.tres`. His lashes, tinted by the lens, were found by
  where they darken the face rather than by colour.
- **Citra's committed rig bleeds at the eye rims** (DEBT.md). It was found
  here and handed off as its own task rather than changed on this branch.

## 2026-09-14 — Lobby-style buttons everywhere but StudentCard

Plan `docs/superpowers/plans/2026-09-14-lobby-style-buttons.md`, spec
`docs/superpowers/specs/2026-09-14-lobby-style-buttons-design.md`.

Every framed action button now wears the Lobby's STUDENT / JADWAL look:

- the `brand_primary_light` fill with the `brand_primary_dark` bevel;
- the cream `outline_card` rim;
- cream display text.

A new `ThemeFactory._add_lobby_button()` is the one recipe for
`PrimaryButton`, `SecondaryButton`, `DangerButton`, `SuccessButton` (and
their generated M/L steps), `LobbyCtaButton`, `LobbyNavTile`,
`MainMenuButton`, `ShopShelfButton` and `ResultButton`.

The main menu's icon buttons, the shelf button and Weekly Results' buttons
keep their own padding and text sizes.

The shelf button also keeps its body-font label. Code review found that the
display face would have stretched Koperasi's `Rak1` 53 px past its 442 px
box. It already overflows by 27 px, which is now listed in `DEBT.md`. The main menu's painted
`menu_button.png` is retired and deleted, and the Weekly Results cream art no
longer drives its buttons.

**Two exceptions keep their look through new variations:**

- StudentCard's eight cream buttons (the six Batal and the two page arrows)
  use `StudentCardSecondaryButtonL`.
- StudentList's BELUM/SUDAH badges use `RosterStatusBelum` and
  `RosterStatusSudah`.

**Unchanged:** frameless, toggle, card and chip buttons.

**Retired rule:** `confirm_pair_semantics`' "one filled, one quiet" pair
rule. The pairs keep their `PrimaryButton` / `SecondaryButton` names, so a
later pass can split them again.

**Found while here:** an editor save of `RosterCard.tscn` bakes a 20 px drop
into its five StickyNotes, because `StickyNote.gd` is `@tool` and its
`_apply_pin()` writes offsets in `_ready()`. The badge change was applied by
text instead, and the trap is listed in `DEBT.md`.

## 2026-09-14 — Exam art and readable inventory text

ExamProgress now shows the user's `cg_ujian.png` (1920x1920, from their Google
Drive) behind the fill, in place of the `cg_test.jpg` placeholder, which is
deleted. The pan is unchanged: 216 px over the 4 s fill, across the middle
1296 of the art's 1920 columns.

The Inventory item sheet and the item-application screen had thirteen texts (five
kinds of label) at 18 or 22 px, about 6-7 sp on a phone. They now use existing variations: the item
description, each effect's explanation, the effect summary and "Sisa ×N" are
`EventBodyLabel` (36 px, dark ink), and each effect's "+N" is `H2Label` (48 px,
display face, dark ink). The Brief had offered the student cards' 52 px
`DaySummaryStat` for "+N", but that style is white with a dark rim, made for
the cards' dark tracks, so it would not read on the sheet's near-white Card.
The effect value column's minimum width went from 80 to 104 px: at 48 px a
"+10" is 83 px wide, which pushed its row's explanation out of line, items
grant up to +35, and the widest two-digit value ("+44") is 101 px.
No token changed and nothing was rebaked. The new suite `inventory_text_size`
holds every text on these screens at 36 px or more, with two reviewed shared
exceptions (the 30 px need words, the 32 px empty-state hint). Checked at full
size with Bank Soal, the longest description: the sheet's content ends at
y 1527 of 1852, so it needed no scrolling.

## 2026-09-14 — Weekly Results: the week-end screen rebuilt to the mockup

Plan `docs/superpowers/plans/2026-09-14-weekly-results.md`, spec
`docs/superpowers/specs/2026-09-14-weekly-results-design.md`, mockup
`docs/superpowers/mockups/mockup_weeklyresults.png`.

ResultCheckup now matches the Weekly Results mockup:

- A red WEEKLY RESULTS ribbon, then one DaySummary card per student in week
  mode.
- The week's coins, then two lines: EVENT BERHASIL and EVENT GAGAL, the
  minigames won and lost. Random events cannot fail, so they appear only in
  Logs.
- Two cream buttons in the new `ResultButton` style. **Logs** opens the new
  `WeekLogsPopup` with the week's history rows; **Selanjutnya** closes the
  screen.

`ResultButton` is a new textured variation over the card's own
`card_bg.png`. The ribbon is a placeholder, cut from the mockup and given
the daily ribbon's alpha.

**Two deliberate departures from the mockup,** found in the live check:

- The two buttons split the row equally, 436 px each, instead of the
  mockup's 368. The display face renders SELANJUTNYA in capitals, which
  needs about 435 px, so a fixed 368 left the row lopsided.
- The card list scrolls with its scrollbar hidden, since the mockup shows
  none.

The project's display font sets the labels in capitals ("LOGS"), and the
card keeps its existing look (the BUGAR/SENANG needs words), as agreed in
the Brief.

**Fixed while here:**

- SchoolDay paid out the Wirausaha earnings, which empties
  `pending_earnings`, before it opened the screen, so the old banner's money
  pill always read 0. SchoolDay now passes the paid total to
  `initialize_checkup()`.
- `test_result_checkup`'s set-up-in-the-tree test always passed: it searched
  for a container name the script no longer had. It now checks that both
  calls exist.

**Retired:**

- `WeekRecapBanner`, `WeekRecapPill`, `WeekRecapPillInfoPopup`,
  `CoinShower.tscn` and the SISWA/RIWAYAT tabs.
- The `RecapBannerPanel`, `RecapPillPanel`, `RecapPillValueLabel` and
  `WeekTabButton` variations.
- The `pill_tap`, `pill_popup_open`, `pill_popup_close` and `pane_swipe`
  cues, with their dedicated `.ogg` copies.
- `WeekRecap`'s `net_skill_delta`, `format_skill_delta` and money read.

## 2026-09-14 — Close Godot before every pull

The laptop pulled 831929b, which retired `EventAnnouncement` and deleted
`AnnouncementBurst.tscn`, `AnnouncementBurst.gd` and `particle_burst.png`,
while Godot had `AnnouncementBurst.tscn` open. The editor wrote its stale tabs
back. It recreated the deleted scene as an untracked file pointing at the two
deleted files, which logged 5 "File not found" errors on every load. Worse, it
silently saved `ApplyStudentRow.tscn` without its script: the pull made
`ApplyStudentRow.gd` extend the new `StudentCardButton` class, which the stale
editor had not registered. It also rewrote `project.godot`'s `main_scene` to a
uid and added sky-layer offsets to `BookClockWidget.tscn`, both harmless. The
laptop was repaired by restoring the damaged files and deleting the recreated
scene. The PC was checked the same day and never had the damage, because
831929b was authored there. The rule is now `CLAUDE.md`'s third 4b save hazard.

## 2026-09-14 — Project guide audit: the debt list leaves CLAUDE.md

`CLAUDE.md` had grown from 24,644 characters after the 2026-09-10 audit to
33,665. Of the 9,021 added, 6,101 were feature passes appending to
`## Outstanding debt & placeholders`. The debt list now lives in
`docs/superpowers/DEBT.md`, which sessions read on demand. The constraints
that were riding inside it came up into `CLAUDE.md`'s `## Visual system`,
because the `claude-review` bot reads only that file: the BarFill rules, the
1080x1080 Penjadwalan card, the badge SVG paths, `tray_dots.png`'s 26x26, and
leaving `sky_cover_margin` alone. `## Current work` held Plan C, untouched
since 2026-09-11, so Plan C moved to DEBT.md too. The result is 22,982
characters. The soft budget rises from 20,000 to 23,000, because two audits
could not reach 20,000 without deleting live rules. The rationale for this
file's structure is still
`docs/superpowers/specs/2026-09-05-project-guide-restructure-and-memory-seeding-design.md`.

Every moved entry was checked against the source first. That check found:

- `penjadwalan_card_bg.png` has one hardcoded `region_rect` (the Peringatan
  dialog), not two.
- `tests/test_bar_contrast.gd` checks only the BarFill luminance floor.
  `Assets/Images/UI/BarFill/README.md` says it checks both rules; the
  tile-period rule has no test (new DEBT entry).
- `exam_cutscene` no longer exists. `event_announce` plays its own file, a
  byte-identical copy of `reward.ogg`, rather than an alias.
- The exam and win cutscene lines the copy entry covered are gone, and the
  item descriptions carry one blanket `[PLACEHOLDER]` comment, not one each.
- The lose backdrop's `@export` lives on `WinStage`.
- The AturJadwal shelf diff is in the plan's Task 2 section, not its STATUS
  block.
- `paper.png` is about 98% pure white, not 96%. `Particles/` holds seven
  placeholders, not three. Only two of the five "faint" icons are white. A
  fourth WCAG helper sits in `test_run_result.gd`. `BASELINE` has 23 entries.
- New debt: `SchoolDay`'s playful textures never load (`.png` paths, `.svg`
  files), and `WinScreen.tscn`, deleted in `0dc9fa9`, came back in `7cc8a07`.

The audit also adds a rule to `## Working efficiently here`: "The main
checkout is shared too". This audit's own `git switch -c` in the shared main
checkout, taken on a `git status` reading ten minutes old, moved a live
session off `feat/shorten-dialog`. That session's next six commits landed on
the audit branch, and its spec and plan left the disk. It moved them back
onto its own branch before shipping (PR #32), and the audit went on in a
worktree.

Text moved out of `CLAUDE.md` verbatim:

- The Loading screen was deleted on 2026-09-10: the shared `Transition` wipe
  covers the scene-load gap, so the intermediate screen was dead weight.
- Every script's documentation (a `##` file header, a `##` line on every
  `@export`) is a hard rule now (`tests/test_script_documentation.gd`) — the
  2026-08-31 21-task sweep closed that ratchet.
- A scaled-down capture cannot show 1px detail, spacing or weight, and signing
  off a visual change from one is how the 2026-09-10 cream pass shipped a
  half-finished layout.
- Do **scene work first, script work second**; after any `scene_save` check
  `git diff HEAD -- '*.gd'` for files you were not editing; and once you have
  patched a script, restart the editor before the next `scene_save` — a
  force-kill is safe once scenes are saved, and the relaunch reloads every tab
  from disk (2026-09-10: skipping it reverted `BuatBatik.gd`).
- **A full `test_run` drops the bridge.** Observed four times on 2026-09-10,
  each immediately after a full run and never after a targeted one. The first
  explanation was memory pressure — the machine had ~1 GB free of 16 GB — but
  the fourth drop happened with **8.9 GB free**, which rules that out. What is
  left is duration: a full run is 15-20s of near-continuous main-thread work,
  and the plugin's transport does not survive it (the `test_run` docs warn
  that a single test blocking for 20s+ can drop the session).
- Soft budget: **20,000 characters**. History: 27,547 on 2026-09-05 (39%
  completed-pass narrative), 30,936 on 2026-09-10, 24,000 after that day's
  audit. The 2026-09-10 pass could not reach 20k without deleting live
  operational rules — if it must come down further, the honest lever is
  moving `## Outstanding debt` to its own file, not thinning the rules.

- That tab also carries **🎭 Gladi Resik Akhir Kelas** — one-click rehearsals of
  the whole end-of-grade sequence with a fixed roster: *Semua Lulus*, *Semua
  Gagal*, and *Campur*, which ladders 3/2/1/0 cleared targets so one pass of
  StatCheck lights the meter 3, 2, 1 and 0 shares in turn (6 of 12 = 1.5 stars, a
  loss).
- Logic lives in `Scripts/Debug/EndGameRehearsal.gd`, tested in
  `tests/test_end_game_rehearsal.gd`; `DebugManager.gd` only holds the buttons.
- `Scripts/AnimUtils.gd` — came in with the ported shop/inventory
  (`squash_bounce`, `popup_spring_in/out`, `coin_pulse`, `create_floating_text`,
  …).
- Same for a **new** `@export`. This is why the theme rebake has no headless
  path.
- Hard constraints, learned the hard way:
- Rationale and the full restructure record:
  `docs/superpowers/specs/2026-09-05-project-guide-restructure-and-memory-seeding-design.md`.

Wording the source check replaced, verbatim:

- **`paper.png` cannot be a full-bleed card surface.** It is 1080x1920 but
  opaque only across rows 262..1578 and columns 47..1033, its bottom-right
  corner is cut away to a transparent wedge, and its body is flat pure white
  (96% of sampled opaque pixels are exactly 255,255,255) -- there is no paper
  texture in it to preserve.
- The `fill_*` tiles and `track_ghost.png` — rules in
  `Assets/Images/UI/BarFill/README.md`, enforced by `tests/test_bar_contrast.gd`
  and `tests/test_ghost_track.gd`.
- `penjadwalan_card_bg.png` must stay exactly 1080x1080; two call sites address
  it with hardcoded `region_rect`s.
- These `AudioDirector` cue ids alias existing streams: `sfx_specialty_match`,
  `tally`, `sparkle`, `star_earn_1/2/3`, `result_fanfare`, `score_tick`,
  `combo_up`, `sfx_event_announce`, and the BGM ids `exam_notice`,
  `exam_cutscene`, `run_result`.
- **Copy placeholders.** Every cutscene line in the exam and win branches, and
  every `desc` string in `ItemDatabase.DEFAULT_ITEMS` (shown verbatim in
  `ItemDetailSheet`), is marked `[PLACEHOLDER]`.
- `EndCutscene`'s lose backdrop is `cg_lose.jpg` standing in for final art (an
  `@export`, so an Inspector swap).
- The exact diff is in the STATUS block of
  `docs/superpowers/plans/2026-09-01-atur-jadwal-mockup.md`.

## 2026-09-14 — Shorten: skip the minigame dialogue from the Lobby

A tiny **Shorten** button on the Lobby's money row, between the daily-login
icon and the coins, opens a panel with **Jangan Skip Dialog** and **Skip
Dialog**. With Skip Dialog on, the eight minigames go straight from the
EventWarning into play, with no character line in between.

What Shorten skips is one catalog rule: `EventDialogueCatalog.shorten_skips()`
is true for TAP entries except `SHORTEN_KEEPS` (Nasi Kotak and Hujan). Today
that is exactly the eight minigames. The three Tolak / Terima events keep
their dialogue, because the choice lives there. SchoolDay's
`_show_event_dialogue()` returns early, before instancing anything.

The setting is `GameSettings.skip_event_dialogue`, off by default. It is saved
next to the minigame-tutorial switch as `[pengaturan] skip_dialog` in
`user://settings.cfg`; the owner approved that persistence in the Brief.

The panel (`Scenes/Lobby/ShortenPanel.tscn`) names the current mode. Its
options are a Primary/Secondary pair, per the confirm-pair rule. It saves only
outside the editor, so tests never write the real settings file. Its scrim
follows the popup-dismiss rule: it starts ignoring input and only closes on a
tap once the panel has opened. The button is the smallest button step
(96 px, the touch minimum). It sits under the reward popup and the tutorial
overlay in draw order, so neither leaves it tappable.

A new `var` on the GameSettings autoload is invisible to a running editor until
it restarts. Hot reload does not give the live autoload instance the new
member, which is the same limit CLAUDE.md records for a new `@export`.

Spec: `docs/superpowers/specs/2026-09-14-shorten-dialog-design.md`. Plan:
`docs/superpowers/plans/2026-09-14-shorten-dialog.md`. Tests:
`tests/test_shorten.gd`.

## 2026-09-14 — EventDialogue: a line before every minigame and event

Every mid-day interruption now has a character speak first. After the sliding
EventWarning, `EventDialogue.tscn` shows one line over a blurred picture of
the school, laid out like `mockup_eventdialogue.png`: a calendar badge
("Minggu x/y") and day banner on top, a full-frame splash in the middle, and a
white rounded box with the typed line at the bottom.

Two modes, chosen per entry in `EventDialogueCatalog`:

- **TAP** — the eight minigames, *Kejutan Nasi Kotak Orang Tua* and *Hujan
  Deras & Jalanan Licin*. No buttons. It always takes two taps: the first
  finishes the line and shows "Ketuk sekali lagi untuk lanjut", the second
  closes.
- **CHOICE** — *Les Tambahan Akademis*, *Latihan Olahraga Ekstra*, *Workshop
  Sanggar Seni*. Tolak / Terima appear once the line is shown. Terima opens
  EventStudentSelectDialog as before. Tolak skips the event before the picker
  exists: nothing is applied or recorded, and it still counts toward the
  week's event limit.

Speakers: `splash_mom` for Nasi Kotak, `splash_gurupenjas` for Latihan
Olahraga and MainBola, and a placeholder `splash_gurusenibudaya` for Workshop
Seni. The other minigames and Les are voiced by a random roster student whose
specialty matches the subject, or by anyone if nobody's does. Hujan has no
speaker; its unblurred `hujan_background` (also a placeholder) is the scene.
`{nama}` in a line becomes the featured student's name. All 13 lines are
drafts.

SchoolDay's event table now exists once, in `_run_event()`. `force_event()`
used to carry a full second copy of it.

Only a left mouse press counts as a tap. `project.godot` emulates touch from
mouse, and Godot emulates mouse from touch, so counting `ScreenTouch` as well
would close a TAP dialogue on its first tap.

Theme: a `font_body_bold` token (Open Sans Bold) and five variations:
`EventDialoguePanel`, `EventDialogueText`, `DayBannerPanel`, `DayBannerLabel`
and `CalendarLabel`.

Spec: `docs/superpowers/specs/2026-09-14-event-dialogue-design.md`. Plan:
`docs/superpowers/plans/2026-09-14-event-dialogue.md`. Tests:
`tests/test_event_dialogue.gd`.

## 2026-09-14 — MainBola: every goal target is reachable

Kelas 9 MainBola games could not be won. Every game gave eight shots and
refunded none, while `start_minigame()` rolled Kelas 9's goal target as 8, 9
or 10 (Kelas 8's as 6–8): two Kelas 9 games in three asked for more goals
than there were shots, and the third needed eight from eight.

`MainBola.gd` now carries two per-difficulty tables, `ATTEMPTS_BY_DIFFICULTY`
(8 / 10 / 10 shots) and `TARGET_RANGE_BY_DIFFICULTY` (4–6 / 6–8 / 6–8 goals),
read through the static `attempts_for()`, `target_range_for()` and
`roll_target()`. The highest target always leaves two shots to miss, as
Kelas 7's six-from-eight already did. The star ratio counts shots taken from
the shots the game started with (`max_attempts`), not from a fixed eight.

Two facts shaped the numbers. The clock binds too: SchoolDay gives the game
30 s × `Balance.MINIGAME_WAKTU_SKALA_*` (30 / 24 / 18 s), the clock runs while
a shot resolves, and a shot costs about a second at least -- so twelve shots
at Kelas 9 would only have moved the wall from the shot count to the clock.
And a shot aimed at the target box always scores, because the keeper dives
away from it; what `GOALIE_SPEED_INCREASE` actually speeds up is the box. So
Kelas 9 is harder than Kelas 8 through its faster box and shorter clock, not
a higher target. The numbers assume a player lands about 70% of shots and
have not been playtested (`CLAUDE.md`, "Pending a balance pass").

`tests/test_main_bola_targets.gd` holds the rule: at every difficulty the
highest target never exceeds the shots and leaves two spare, and 60 real
`start_minigame()` starts per difficulty never break it.

## 2026-09-14 — `/gamecode` skill

Added `.claude/skills/gamecode/SKILL.md`, one command that takes a game
feature from idea to code without the user naming the skill sequence:
`superpowers:brainstorming`, then one short Brief in game terms (place in the
loop, rules, `GameState`/`StudentData` fields with both bridge names, grade
scaling, files, decisions with bold defaults, branch), then on the user's yes
branch → spec → `writing-plans` → `executing-plans` with no further stops,
and a single "Ship it?" before `ship-pr`. The skill only overrides the
sub-skills' gates, all listed in its table: section-by-section design
approval, the spec-review wait, the execution-mode question,
subagent-driven execution (the Godot bridge takes one client) and the
finishing menu.

Built test-first per `superpowers:writing-skills` on three features (a
quirk, a Koperasi item, a Piket duty). Without the skill, even with the whole
sequence typed out, summaries ran 350–500 words in a different shape each
time and two of three runs finished on the three-option merge menu. With it,
every Brief had the same shape at about 300 words and every run ended on
"Ship it?". Two refactor rounds fixed: the branch now exists before the spec
is committed; *this checkout* vs *worktree* is decided by
`git status --porcelain --untracked-files=no` plus the editor's unsaved tabs
(plain `--porcelain` tripped on untracked files); a new suite must override
`suite_name()` (the base returns `"unnamed"`); a red step the plan predicts is
not a stop; and a premise the code contradicts becomes a Decision with the
user's own ask in bold.

## 2026-09-12 — Event cards, the sliding warning, and EventAnnouncement's retirement

Plan `docs/superpowers/plans/2026-09-12-event-cards-and-slide-warning.md`,
spec `docs/superpowers/specs/2026-09-12-event-cards-and-slide-warning-design.md`.
The event picker (`EventStudentSelectDialog`) and the item-preview list
(`ApplyItemScreen`) now show the real DaySummary card
(`DaySummaryStudentRow`) instead of their own ad hoc rows, wrapped in a new
`StudentCardButton` (`Scripts/UI/StudentCardButton.gd`) that owns the card's
rect and toggles it as a selectable button. The card itself gained a
"current stats" mode on `DaySummaryStatRow` (`set_standing`,
`format_standing`) so it can show `current/target` (no sign, no chevron)
instead of DaySummary's own gain preview — DaySummary and ResultCheckup keep
their existing `setup_row`/`setup_week_row` paths untouched. A card that
cannot be picked dims the hosted card rather than the wrapper, whose alpha
the list's own entrance animation owns, and the item screen's LELAH chip
sits on the avatar's lower-left.

`EventAnnouncement` is retired. Both the minigame banner and the mid-day
random-event popup now go through a single sliding mustard `EventWarning`:
a full-bleed panel, `eventwarning_icon.png` (a cropped Drive icon) centred,
and a caption with a navy outline. Deleted along with it: the popup's scene
and script, `AnnouncementBurst.tscn`/`.gd` and the particle burst it fired,
`HazardStripeShader.gdshader`, and the three placeholders only it used
(`icon_event_warning.png`, `icon_event_announce.png`, `bg_event_announce.png`,
plus `particle_burst.png`). `sfx_event_announce` now docs itself against
`EventWarning`; `ThemeFactory.gd`'s and `StudentSummaryCard.gd`'s header
comments no longer name the dead scene.

## 2026-09-12 — Paper confetti on the week-end checkup

Plan `docs/superpowers/plans/2026-09-12-paper-confetti.md`. ResultCheckup's
celebration is now `PaperConfetti.tscn`: two cannons at the bottom corners
fire red, yellow and blue sheets up and inward, and they spin and flutter
down. `Scripts/Shaders/paper_flutter.gdshader` fakes the 3D flip by
squashing each quad on its own x axis by a per-particle cosine, and shades
the back face. Air drag set below gravity makes the pieces hang instead of
dropping. The week-gained gate and its timing are unchanged.
`CelebrationConfetti.tscn` is untouched and still serves ApplyItemScreen.

**The live check changed two planned values.** Turbulence (influence
0.08–0.16) blends velocity toward the noise field every frame and held the
whole arc below y 1300, so it is off. And a 2D `ParticleProcessMaterial`
ignores `angle` and `angular_velocity` unless `particle_flag_disable_z` is
set, so every piece stood upright until that flag went on. That is also true
of the older `CelebrationConfetti`, whose white chips have never spun. Both
values are pinned by tests.

**Two verification traps.** At `Engine.time_scale = 0` every
`GPUParticles2D` is invisible, so particle screenshots need 0.02. And
deleting a property line from a `.tscn` does not reset it in the editor's
cache: an in-place reload applies only the properties written in the file,
so the editor kept `turbulence_enabled = true` while a fresh game load
correctly read false.

On screens wider than 9:16 the right cannon lands short of the edge. That
was accepted, not fixed. At 1.2 s a few pieces reach the top edge, a little
above the spec's "upper third". Lower `initial_velocity` if that reads as
too much.

## 2026-09-11 — Koperasi rework, Part 2

Plan `docs/superpowers/plans/2026-09-11-koperasi-part-2.md`, from the Part 2
handover. 11 commits, full suite 1339/1339 across 92 suites, verified in the
running game.

**Two decisions, taken with the user.** The basket tray is **docked**: always
visible at the bottom of the shelf screen. Bought items fly from the shelf
into it and stand on its plank at their own heights. That changes where the
flight lands, which the handover had fenced off. The split-arc tweens, the
tumble, the landing bounce and floating text, and hold-to-return keep their
behaviour. And there is **one Beli, in the tray**: the loose BELI button and
the "Harga++" label are gone, and the tray's footer carries the total and the
button.

**BasketTray.** `Scenes/Koperasi/BasketTray.tscn` and `@tool class_name
BasketTray`. The root is a bare anchor and `Body` carries the geometry
(Pattern C). `Body` holds:
- the cream sheet, the dot grid and a hint
- the plank and the items
- an empty state
- the basket emblem with a unit count
- a footer reading "Total: 2.400 koin" beside a `PrimaryButtonM` Beli

Slots are placed by hand rather than by a container, so layout is synchronous
and tests assert real positions. Feet sit on the plank line, the row is
centred, and it shrinks evenly when it would overflow (`item_gap`,
`item_scale`). `hold_for_landing()` keeps a bought unit hidden until its flight
arrives, and the flight now targets that item's own slot. `Cart.total_of()` is
the one sum behind both the cart and the tray.

**TraySlot.** One item standing in the tray: its art at the item's display
height, with width from the art's own aspect, a soft shadow, and a ×N badge.
Holding it for 0.35s returns one, a tap wobbles it, and right-click returns one
at once. The gesture rule is a pure static, `classify_release()`, so it is
tested without waiting. The art is cropped to its opaque pixels (see the
findings below).

**Tokens and variations.** Eight colours moved into a "Koperasi" group on
`DesignTokens`: `koperasi_tag_*` for the three tag states, `koperasi_tray_fill`
and `koperasi_tray_rule`. `_add_koperasi_variations` reads them, and the price
tag's wipe reads `koperasi_tag_pressed_fill`. New variations `TrayBadge`,
`TrayBadgeLabel` (display face, so it is on `DISPLAY_ROSTER`) and `TrayPlank`.

**Rim glow.** Each shelf item carries a `Glow` node behind it: the shared
radial `Assets/Images/Shop/UI/item_glow.tres`, tinted `currency_gold`.
`ShelfItem.lift()` swells and fades it in with the lift, and returns its
`Tween`.

**Part 1's minors.** The price tag now lets taps through by scene: `mouse_filter`
is authored on `PriceTag.tscn`, and the runtime pass is gone. Saving the tag
through the editor also records the wipe's rest state, which its `@tool`
`_ready()` sets on load. The SVG scan now rejects `<tspan>` and `<use>` as well
as `<text>`, over both tray icons.

**Deleted.** The modal basket chrome in `koprasi.tscn` went: `Rak1/Keranjang`,
`BlurLayer`, `PopupLayer`, the loose BELI and "Harga++". So did
`ReturSlot.tscn`/`.gd`, `icon_retur.svg`, and `tests/test_rakbarang_blur_layer.gd`
(4 tests, whose subject is gone by design). `rakbarang_1.gd` shrank to glue, and
its `test_viewport_editability.gd` `BASELINE` entry went **2 → 1**.

**Tests.** New suite `tests/test_basket_tray.gd`, 28 tests;
`tests/test_koperasi_tray.gd` went from 26 to 32.

**Not held: the mentor screenshot review.** The user chose to ship without
waiting for it.

**Three findings from this pass, worth remembering:**

- Item art carries transparent padding. A slot bottom-aligned on the plank
  still left the art floating above it, with its badge adrift. `TraySlot`
  crops each texture to `Image.get_used_rect()` with an `AtlasTexture`, cached
  per texture. Measure the alpha before laying out on any item art.
- A theme rebake run beside scene operations corrupted the bake. After a
  rebake, the editor reloads its cached theme in place, matching sub-resources
  by id, so stale properties merge in. A later `scene_save` then writes that
  theme back: `TrayPlank` picked up another stylebox's 16px content margins.
  Rebake alone, restart the editor before any `scene_save`, and diff the bake
  before every commit.
- `class_name` `@tool` scripts (`ThemeFactory`, `TraySlot`, `BasketTray`)
  refused hot reload with error 43 even when valid. A headless
  `--check-only --script` run proves the file parses; then restart the editor.

## 2026-09-11 — Koperasi rework

12 commits, full suite 1309/1309 green, verified in the running game.

**Price tags.** Green coin pills carrying a rupiah coin disc. On purchase a
dark green wipe crosses the pill left-to-right over 0.18s and the price swaps
to "Beli" with a scale pop at 0.23s. Unaffordable items grey out but still
show their price. New variations `PriceTag`, `PriceTagPressed`,
`PriceTagDisabled`.

**Basket.** The black basket silhouette (a stock pngwing PNG) is replaced by a
drawn slatted market basket. Shelf items gained a soft shadow, an idle bob at
a per-item random phase, a lift on press, and a dim when unaffordable.

**Return popup.** Became a warm cream tray: a Sheet Panel on a new
`BasketTray` theme variation, a tiling dot-grid surface, and a warm wash over
the existing blur rather than a neutral dim. Its runtime-built rows moved into
`ReturSlot.tscn`, lowering `rakbarang_1.gd`'s entry in
`tests/test_viewport_editability.gd`'s `BASELINE` from 7 to 2 and removing
every `add_theme_*` call from that file.

**Emoji.** Six removed from the shop scripts; the guarding test now scans by
Unicode codepoint range rather than a list of known glyphs.

**New suite.** `tests/test_koperasi_tray.gd`, 26 tests.

**Three findings from this pass, worth remembering:**

- A test passed before the thing it tested existed: `Theme.get_stylebox()`
  falls back to the base type's stylebox rather than returning null, and this
  project's cream Panel box is itself a warm light `StyleBoxFlat`, so a
  tray-colour assertion passed vacuously. Reading a stylebox in a test now
  requires a `has_stylebox` guard first.
- A wrong autoload property (`GameState.money`; the real one is
  `player_money`) crashed the shop on entry while every test passed, because
  they were source-text scans. There is now a test that resolves every
  `GameState.<name>` reference in the shop scripts against the live autoload.
- The price pill swallowed taps: a `PanelContainer` defaults to
  `MOUSE_FILTER_STOP`, and the tag sits on top of the shelf's `TextureButton`,
  so tapping the pill bought nothing. Caught by review, not by tests.

## 2026-09-11 — Pull requests open, check, review and merge themselves

Every PR had been opened and merged by hand, and the repo had no CI. Now:

- **`project-check`** runs on GitHub for every PR: headless Godot 4.6.2
  imports the project and loads every script, scene and resource, checking
  that each dependency exists. A scene pointing at a missing texture needs
  that explicit check, because Godot logs the error and loads the scene
  anyway. The walk skips nested projects the way the editor does; a naive one
  reports 62 false failures in `-REFERENCE-/prototype`.
- **`claude-review`** is a cloud Claude review with a `pass`/`block` verdict.
  It stays skipped until the repo owner adds a key.
- **The `ship-pr` skill** runs the full suite and a local review, pushes,
  opens the PR and stamps the tested commit.
- **`ci/auto_merge.sh`** merges `brineoutxd`'s PRs into `Textures` when every
  gate is green on a commit that already contains `Textures`, flags PRs whose
  base moved on, and re-points stacked PRs.

Spec: `docs/superpowers/specs/2026-09-11-pr-automation-design.md`. Plan:
`docs/superpowers/plans/2026-09-11-pr-automation.md`.

Live test, 2026-09-11: a stamped PR merged itself; this entry's own PR waited
while unstamped, was skipped while labelled `hold`, and was flagged out of
date when the first PR landed, then merged itself once re-tested.

## 2026-09-11 — Delta rows, badge and Inventory values readable; the delta rows show at all

`ResultDeltaLabel` bakes white so `self_modulate` can colour-code it, and all
four of its users sit on light grounds:
- the minigame result card's delta rows, bright green and red on
  `ResultStatPanel`: 1.13:1 and 2.54:1
- the card's category badge name, untinted white on its white chip: 1.02:1
- the item detail sheet's "+N" effect values, untinted white on its `Card`:
  1.02:1
- the apply-item row's preview, "(+5)" in `state_success` on its `Card`:
  3.26:1. Until a row is first toggled, its "--" is untinted white too.

The fix, chosen over darker tints and over a variation per outcome, keeps the
tint (it is the colour code) and lets the outline carry the text:
`ResultDeltaLabel`'s 4px outline went from cream `text_outline_color` to
`text_primary`. `self_modulate` multiplies the outline too, but a dark rim
stays dark under any tint. The white base is unchanged, so
`test_result_delta_label_bakes_white_so_self_modulate_survives` still holds.
Measured live in a 1080×1920 `SubViewport` (phone resolution), glyphs hidden
and shown: the rim reads at 9–14:1 (p90) on every label, while the fills stay
bright, so the letters read as coloured or white with a dark edge.

**The delta rows never showed.** `_configure_delta_label()` zeroed each row's
`modulate.a`, but `play()` fades only `DeltaPanel` back in, so the panel
revealed empty. The live pass found it by measuring zero drawn pixels under
the rows. The per-row zeroing is gone, and
`test_configure_leaves_the_delta_rows_to_their_panels_fade` holds it. No
minigame sets `last_*_delta` or `minigame_category` yet, so no player has seen
the rows or the badge either way.

`tests/test_light_ground_text.gd` now also measures the badge, the delta rows
(as a gain and as a loss) and both Inventory rows, in every state they can be
left in. A label passes on its fill, or on an outline at least 4px thick, each
measured under its tint.

The faint placeholder icons were left alone by decision; CLAUDE.md's
outstanding debt keeps their numbers.

## 2026-09-11 — Minigame result and HUD labels readable; TesNotice's real bug found

Three minigame labels still wore `ResultBodyLabel` on light surfaces. That
variation is 22px cream `text_on_brand`, made for a dark ground:
- `MinigameResultPopup`'s `NameLabel`, on the card (`popup_bg.svg`, #F5F2EB):
  1.04:1
- its `ScorePrefixLabel` ("Skor:"), on `ResultStatPanel`: 1.21:1
- `MinigameScoreHUD`'s `ComboLabel` ("x3"), on its `ResultBadgePanel` chip:
  1.05:1

Two new variations fix them, both `text_primary` at the caption size the labels
already used: `ResultCardBodyLabel` for the popup's two and
`ScoreHudComboLabel` for the combo count. They measure 12.98:1, 11.19:1 and
14.28:1. The HUD's `TargetLabel` keeps `ResultBodyLabel`: it sits on the dark
translucent `ScoreHudPanel`, where cream holds 3.4:1 even over white art, and
dark ink would fall to 1.3:1 over dark art.

`tests/test_light_ground_text.gd` resolves each label the way the game draws it
(the baked theme, in the tree) and measures it against the stylebox behind it:
- the three at WCAG AA (4.5:1)
- `TargetLabel` at 3:1 over both extremes of art
- every variation declared by the bake

**TesNotice was deliberately left alone.** The brief put its `BodyLabel` on
the tan `notice.png` card at ~1.7:1. Live, the card isn't there. `NoticeCard`
is a `NinePatchRect`, which does not size to the anchored `Content`. It
collapses to its 96px patch minimum, and the text floats on the dark scrim.
Measured with the glyphs hidden, the cream body reads (6.9:1 at worst); dark
ink would have dropped it to 1.1:1. The labels that do fail there are `Kicker`
(1.8:1) and `GradeLabel` (1.4:1). CLAUDE.md's outstanding debt now describes
it, with both ways out.

Also:
- The stale "Unreadable RunResult row names" debt entry is gone; the entry
  below resolved it.
- Saving `MinigameScoreHUD.tscn` through the editor wrote
  `grow_horizontal/vertical = 2` on its `Panel`. `anchors_preset = 15`
  already applies both at load, so nothing moves.
- Live verification found the rest of the result card has the same problem
  through other routes. The delta rows, the category badge's name and several
  placeholder icons measure 1.0–2.6:1. They're logged in CLAUDE.md's
  outstanding debt, not fixed.

## 2026-09-11 — RunResult's row names readable

The six row names on RunResult ("Minigame selesai" … "Murid ikut event") wore
`ResultBodyLabel`: 22px cream `text_on_brand`, made for a dark ground, on the
near-white `Card`. That measures 1.05:1, and the names barely showed.

`RunResultRow.tscn`'s `NameLabel` now wears a new `RunResultNameLabel`:
`text_primary` in the body face at `font_body_size + 8` (36px), the phone step
`EventBodyLabel` and `CatatanLabel` already use. It measures 14.28:1. A runtime
A/B on the live screen compared 28px and 36px; 28 was legible but small beside
the 72px icons and 48px values.

`ResultBodyLabel` itself is unchanged: the minigame score HUD's `TargetLabel`
sits on a dark translucent pill and needs the cream. Its four other users are
also on light grounds; that is logged in CLAUDE.md's outstanding debt.

Three tests in `tests/test_run_result.gd` resolve a row the way the game draws
it (the baked theme, in the tree):
- the name contrasts with its card at WCAG AA (4.5:1) or better
- it is at least the body size
- its variation is one the bake declares. The plain-Label fallback is dark
  body text, so the first two cannot see a missing variation.

Verified live through the `lulus` rehearsal: all six rows at 36px and 14.28:1
with no overrides; the widest name takes 352px of a 579px slot.

## 2026-09-11 — StatCheck on StudentCard's paper; one win stage for EndCutscene and RunResult

Spec `docs/superpowers/specs/2026-09-11-statcheck-paper-and-shared-win-stage-design.md`,
plan `docs/superpowers/plans/2026-09-11-statcheck-paper-and-shared-win-stage.md`.

**StatCheck.** Each student's page is now StudentCard's own paper: `card_bg.png`
with its `PaperShadow`, authored at native 1080×1920 inside `StatCheckCard.tscn`
and scaled 0.757, so the 1321px sheet fills the 1000px card.
- The photo sits in the frame printed on the paper.
- The name sits alone on the printed brown plate, in the new `PlateNameLabel`
  (Boohong 96, cream).
- The three rows use the `StudentCard/stat_*.png` icons at StudentCard's
  proportions (128px icon, 68px bar).
- The bio lines are gone.

Two tests guard the layout:
- `card_bg.png`'s paper covers only x 52..1045, y 238..1558 of the texture. One
  test maps that sheet through the paper's transform and fails if it leaves the
  card or underfills it.
- Another re-measures every roster name against the plate at the real font
  size.

**RunResult.** EndCutscene's painting, letterbox bars and posed roster moved
into `Scenes/EndGame/WinStage.tscn` (`WinStage.gd`). EndCutscene and RunResult
both instance it and dress it with the same line.

RunResult used to cover the screen with the painting alone, cropped to
1440×1920 with no students, so the blur hand-off jumped. Now its first frame is
EndCutscene's last. Both verdicts were checked live through the rehearsal:
- win: stage scale 0.703125 at y 240, with four students
- loss: full-screen `cg_lose.jpg`

The letterbox put RunResult's dark title on the navy bar, so the title moved to
`ResultHeroLabel`. WinStage's root is a bare anchor that sizes its children in
`dress()`, following the authoring guide's rule for instanced roots.

## 2026-09-10 — LombaMenari note camera

Friday Night Funkin's note camera for the dance minigame. A successful arrow
leans the camera the way it points — RIGHT right, LEFT left, TOP_LEFT up-left,
TOP_RIGHT up-right — holds the lean, then eases home; a miss, wrong swipe or
early swipe sends it home at once. The stage (Background and dancer) slides
opposite the lean, as the world does under a panning camera. The notes, hit
zone and score HUD hold still, as FNF's HUD camera does, so the target never
moves under a swiping thumb.

The logic is `Scripts/Minigames/SeniBudaya/DanceCamera.gd`, a `@tool`
`RefCounted` tested by behaviour in `tests/test_dance_camera.gd`; LombaMenari
only wires it. The follow is frame-rate independent (`1 - e^(-speed·delta)`),
not FNF's frame-counted lerp. Knobs sit on LombaMenari's root under *Motion -
Camera Follow*: `camera_look_distance` 30 px (negative flips it),
`camera_follow_speed` 4.0, `camera_hold_duration` 0.6 s — first guesses, not
playtested. `_handle_swipe()`'s direction table became the shared
`ARROW_DIRECTIONS` const, so the swipe and the camera cannot disagree.

The camera needs the Background to overscan the screen, or a lean bares a
strip of nothing at the edge. A test fails if any edge the stage slides away
from has less than one lean of spare art.

## 2026-09-10 — StudentList: roster strip and card relayout (Warm UI, Part 3)

Spec `docs/superpowers/specs/2026-09-10-studentlist-part-3-design.md`, plan
`docs/superpowers/plans/2026-09-10-studentlist-part-3.md`. The last
TutorialPanel-hosting screen without a dedicated design pass.

**Why.** StudentList is the scheduling hub — AturJadwal routes here, you tap a
student's paper card, it sends you back to AturJadwal to set their week. Four
problems: (1) no roster-wide progress — you saw one student's `BELUM`/`SUDAH`
state at a time and the page dots carried none, so finding the unscheduled
student cost up to four taps; (2) ~330px of dead paper below a lopsided 3+2
sticky-note grid; (3) nav arrows were literal `<` `>` pinned to the vertical
centre of a 1920-tall screen; (4) `hobby_category` / `personality` / `quirk`
were in the data and reached nothing on screen.

**RosterCard extraction.** The four near-identical ~130-line `Murid1..4` card
subtrees (~600 lines of `student_list.tscn`) became one `RosterCard.tscn` +
`@tool class_name RosterCard` script, instanced four times. The instance names
stay `Murid1..4` — `tests/test_student_list.gd` resolves `CardContainer/Murid%d`
and the tutorial's step 1 targets `CardContainer` — so both contracts held with
every pre-existing test still green. Six `@export`s on the root
(`student_name`, `portrait_texture`, `specialty`, `persona`, `quirk`,
`is_scheduled`) plus `static compose_catatan(persona, quirk)`: five persona
openers × six quirk observations, thirty teacher's-notes from eleven strings,
authored Indonesian in a `const` block.

**Screen.** A `whiteboard.png` papan plaque behind `DAFTAR MURID`; a
`RosterStrip` of four `RosterAvatar` slots above the carousel, each a portrait
in a ring `self_modulate`-tinted `state_success` / `state_danger` by that
student's scheduled state, tap to jump; nav row (arrows + page dots) dropped to
y1730 where a thumb rests; `CardContainer` at x70–1010 / y310–1700.

**Card interior.** Six bands: name + status stamp, framed portrait with
photo-corner tape, a trait-chip row, the week as five sticky notes in one row
(`SEN SEL RAB KAM JUM`, each with its schedule-category glyph), and the catatan
guru filling the former dead band on a tiling rule.

**Theme.** No new component and no `TraitChip` variation — `QuirkBadge` and
`PersonaBadge` already ship as pill trait chips and a Godot `Button` has a
native `icon`, so a chip is a themed `Button`. One new variation,
`SpecialtyBadge` (neutral `surface_sunken` pill — the category colour rides on
the chip's icon), built from existing tokens, added to `DISPLAY_ROSTER` and
`test_button_geometry`'s `RADIUS_EXEMPT`, and the theme rebaked. `RosterAvatar`
uses the existing `GhostButton` variation. The trait row is 96 tall, not the
spec's 90, so the chip Buttons clear `touch_target_min`.

**Page dots.** Moved from a runtime `Label.new()` with a bullet glyph to a
`PageDot.tscn` template, lowering `test_viewport_editability`'s `BASELINE` for
`student_list.gd` from **8 to 7**. `_update_page_indicators()` now tints the
current dot gold and the rest by scheduled state, so roster progress reads in
two places.

**Tutorial.** Three steps to four — a new "Status Jadwal" step at index 1
spotlights `RosterStrip`. The plan's "no new machinery" held for the spotlight
target but not for the tutorial's `current_step` / `index` special-casing:
inserting at 1 shifted Navigasi Card 1→2 and Pilih Murid 2→3, so `_switch_card`,
`_on_card_pressed` and `_show_step`'s per-step branches were remapped.

**Art.** Six generated placeholders (see CLAUDE.md's grouped list):
`icon_wirausaha.svg` — a genuine gap, `StickyNote` tinted for Wirausaha but had
no glyph — plus the two status stamps, photo-corner tape, the avatar state ring
and the catatan rule.

**Late fixes from the live pass.** Status badge text shortened to `BELUM` /
`SUDAH` (the stamp ring carries the phrase) with `clip_text`; nav-arrow
placeholder rotated sideways; nav arrows resized to the 128px `btn_h_m` step;
`test_confirm_pair_semantics` repointed at `RosterCard.tscn` after the badges
moved there.

## 2026-09-10 — Minigame, sky and paper fixes

Six independent fixes. Spec:
`docs/superpowers/specs/2026-09-10-minigame-sky-and-paper-fixes-design.md`. Plan:
`docs/superpowers/plans/2026-09-10-minigame-sky-and-paper-fixes.md`.

**Badminton shuttle.** Twice the size, hit circle included (`puck_radius_frac`
0.08), stood upright, and the cork now leads the flight: a racket hit turns it
180°, a serve snaps it toward the receiver. The growth bug was the hit punch
reading the sprite's live scale as its rest — a hit every 0.22 s against a
0.52 s punch ratcheted it up. The shuttle's look moved into
`ShuttlecockSprite.gd`, which remembers its authored pose and is tested by
behaviour with `Tween.custom_step()`; the racket squash had the same flaw and
got the same fix.

**MainBola goalie.** `_setup_layout()` measured `get_viewport_rect()`, a 2×2
stub inside the editor, so the whole scene was laid out in a 2×2 box and the
goalie was rewritten on every layout. It now measures the root's `size`; the
goalie's scene position is the truth, left alone in the editor and mapped onto
the real screen in game by `design_to_screen()`. `goalie_depth_frac` is
retired, and the scene is re-saved in design space.

**BuatBatik pictures.** The tool slots are shuffled, then pictures were dealt
by slot index. Each tool now authors its own `ToolTextureRect` (anchors mode,
so its anchors are actually saved), so the picture travels with the tool; the
emoji `IconLabel`s are gone and the ratchet dropped 8 → 7.

**The day's sky.** A full turn, dawn 60 → evening −300, from the darkest frame
back round to it, easing out — QUAD/OUT over 1.64 s per phase, tuned in Motion
Lab, so a school day now takes 3.28 s on screen (was 4.0 s); smoothstep off.

**Paper shadows.** `Scenes/UI/PaperShadow.tscn` inside each of the twelve
StudentCard/ReportCard papers, drawn behind it, so a thrown paper takes its
shadow along. The template is two nodes: an instance root under a plain
`Control` is saved with a `layout_mode = 0` override that zeroes its rect on
load, so the root is a bare anchor and a `Silhouette` child draws. The two
static stack shadows are deleted.

**LombaMenari backdrop.** `budaya_background.jpg` replaces `Gawang.jpg`,
MainBola's football goal, and covers taller screens instead of stretching.

**On the way.** Three editor traps, now in the authoring guide and CLAUDE.md:
instance roots losing their rect, position-mode Controls not saving anchors,
and `script_patch` matching bytes exactly on CRLF files. A scene save also
reverted `BuatBatik.gd` from a stale script tab (rule 4b) before it was
re-applied. Suite: 91 suites, 1258 tests, green.

## 2026-09-10 — Delete the Loading screen

`Scenes/Loading/loading.tscn` and `Scripts/Loading/loading.gd` are gone. The
earlier transition pass had already routed CutScene and Splashscreen straight
through the shared `Transition` wipe, and that wipe covers the scene-load gap on
its own — the intermediate screen (a placeholder with a progress bar) added a
second scene change for no benefit. A short-lived follow-up had re-wired
CutScene → Loading → StudentCard through the wipe; this reverts that too, so
both CutScene exits are a single `Transition.change_scene(_next_scene_path(),
WIPE)` again.

`tests/test_boot_screens.gd` drops its Loading half and now covers Splashscreen
only. `GameState.next_scene` is left in place — an unused one-line `String` with
a sensible MainMenu default, kept against a future scene heavy enough to want a
real threaded-load screen.

## 2026-09-10 — Asset refresh and UI pass

Six independent changes driven by a batch of new art. Spec:
`docs/superpowers/specs/2026-09-10-asset-refresh-and-ui-pass-design.md`. Plan:
`docs/superpowers/plans/2026-09-10-asset-refresh-and-ui-pass.md`.

**Asset intake.** 18 files in. Four were downscaled on the way: the project
imports at `compress/mode=0`, so a source's pixel dimensions are its VRAM cost,
and the seven daily-login panels at their native 7281x3231 would have been
94 MB each — 658 MB. They ship at 1600x710. The sky went 3998² to 2048², the
coin 1484x1192 to 256x206, the rank badges 1521x1471 to 512x495. Transparent
PNGs were resized with alpha premultiplied and unpremultiplied; a straight
LANCZOS resize on RGBA drags the RGB under fully-transparent pixels into the
edges and fringes every rounded corner.

**Two new theme variations.** `CutsceneDialogue` (RichTextLabel, body face,
title size) and `GhostButton` (draws nothing at rest so baked art can be the
button). Both built only from existing tokens, so no `DesignTokens` export was
added and no editor restart was needed. `GhostButton` keeps `radius_pill` and
is registered in `test_button_geometry`'s `RADIUS_EXEMPT`, because its one call
site overlays a capsule baked into the daily-login art — the project's fixed
20px radius undershoots it.

**Intro cutscene.** The dialogue box was a `TextureRect` wearing
`cutscene_dialogue.png`, 1080 tall from y=940 — 100px of it hung off the bottom
of a 1920-tall screen. Now a `Panel` on the `Card` variation, inside the screen,
sized to its text, with the copy stepping from 28 to 36. CG 2 and CG 4 replaced
in place; `cut_scene.gd` preloads by path, so no code changed.

**The sky sweeps once across the day.** `midday_rotation_degrees` is gone: the
arc is one lerp between dawn and evening, and `SchoolDay` sweeps it once across
both phases instead of resting the sky at a midday pose while the event popup
is up. Total travel is unchanged. Accepted consequence: the event is
player-blocking, so a slow player sees the sky reach evening early and hold.

**Soft shadows.** `report_card.tscn`'s paper stack gets the same soft-shadow
sibling `student_card.tscn` and `DayStickyNote` already use. The two Akademis
minigames' cards shipped a 0.12-alpha 4px shadow that was invisible; deepened
to 0.22/12/(0,6), and PilihanGanda's three choice-button styleboxes to
0.25/12/(0,6). Those three already carried deliberate colour-coded fills —
saturated green for correct, crimson for wrong — so only the shadow moved.

**Lobby money chip and daily login.** `DisplayUang` was a 1920x1080
pink/magenta landscape PNG with a label on top, and the only reason the chip
was 332x187 instead of the 332x96 the layout wanted. Now a `Panel` on `Card` at
332x96, bottom-aligned with `DailyLogin`, holding the shared coin and a
`CoinLabel`; Koperasi and Inventory read the same coin. Daily login moved onto
the new panel art, which bakes the whole seven-slot calendar with slot N lit —
so the seven overlay tiles, their fourteen labels and the per-tile tint loop
are all gone, and the day is a single texture swap.

**RunResult.** Ten `+`/`-` bands collapse to five ranks (S 90 / A 75 / B 60 /
C 45 / D) with badge art; `GradeLetter` is replaced by a `GradeBadge`
`TextureRect` fed by five Inspector-assigned textures. The win backdrop was a
wiring bug, not a redesign: `RunResult.gd` has always documented its backdrop
as "the SAME image EndCutscene shows" but pointed at `cg_win.jpg` (735x865)
while EndCutscene had moved to `win_background.png` (1536x2048). Blur lod,
darkness and stretch already matched.

**Placeholders and debt this pass left behind.** The new sky art has a stray
night-street layer in its bottom-left corner that should be erased at source
(it sits outside the visible area — see `CLAUDE.md`). The five rank thresholds
are estimates awaiting the balance pass. `EndGameRehearsal.gd`'s comment
still points at a spec describing the retired ten-band scheme, and
`Assets/Images/CG/cg_win.jpg` is now orphaned. On RunResult the row *name*
labels read faintly against the white rows — pre-existing, not touched here.
The daily-login header reads "Daily Login" in English against the project's
Indonesian-UI rule, at the user's explicit request.

Suite went 1170 to 1198 tests across 84 to 86 suites, green throughout.

**Merging `Textures` back in (2026-09-10).** Three files conflicted.
`kejartes_theme.tres` is generated — resolved by taking either side and
rebaking, which a full `test_run` does in-process. `CLAUDE.md` took the
collaborator's audit, with this branch's two facts re-applied (the
`BookClockWidget.tscn` `scene_open` hang, the stray layer in the
day-transition sky) and their now-stale `DisplayUang` off-palette entry
dropped, since the money-chip rebuild removed the last reference to that
texture.

Three breakages git could not see, all fixed here:

- `test_cream_panel_tokens` and `test_ghost_track` call `assert_not_null()`,
  which this branch's addon update deleted. They now extend
  `McpTestSuiteCompat` like the project's other 22 such suites.
- `test_the_lobby_claim_stays_a_success` asserted the claim button is a
  `SuccessButton`. The daily-login rebuild moved the gold "claim me" pill
  into the panel art, so the button is deliberately chrome-less
  `GhostButton`. The test now checks the rule the colour split actually
  protects — the claim is never an ordinary confirm or a destructive
  action — and is renamed to say so.
- `default_bus_layout.tres` arrived with the BGM bus muted
  (`volume_db = inf_neg`), swept into `6367a31` by an editor boot rather
  than intended. Reverted to the unmuted value.

Merged suite: 1225 tests across 89 suites, green.

## 2026-09-10 — Cream panel language (Warm UI, Part 2)

The mentor's second review: the AturJadwal card's olive green is drab, and each
activity row nests four surfaces so the eye has nowhere to land. Spec:
`docs/superpowers/specs/2026-09-10-cream-panel-language-design.md`. Plan:
`docs/superpowers/plans/2026-09-10-cream-panel-language.md`.

**The green was never a token.** `design_tokens.tres` was already cream
(`surface_page #FBF1E3`). The olive came from one texture,
`penjadwalan_card_bg.png`, used twice in `atur_jadwal.tscn` at two different
`region_rect`s — as the activity card and as the PERINGATAN dialog's panel. So
one in-place replacement fixed both surfaces the mentor pointed at, without
touching either call site.

Recolouring it by luminance turned the body flat grey: the olive's problem is
its yellow-green *hue*, not its brightness. Rotating hue to 35 in HSV and
desaturating kept every bit of the original structure — body `#EEE1CE`,
highlights `#FFF1DD`, and the bottom rim surviving as a warm `#776C5D`.

**The clutter was in the tokens.** `preview_row_fill` `#6B4B33` → `#FFFDF8` and
`preview_pill_fill` `#4A3728` → `#E6DAC6`, plus `PreviewRow` losing its 3px
stroke and hard drop shadow. Rows are now divided by a hairline between them
rather than a box around each. The mockup's 220px row pitch survives exactly:
the `VBoxContainer`'s separation dropped 40 → 16 because the gap is paid on both
sides of each hairline, and 180 + 16 + 8 + 16 = 220. The hairline counts as 8,
its *combined minimum size* — the editor reports a laid-out `size.y` of 4 for
the same node, which is the misleading number.

**Wirausaha and Libur needed their own answer.** They have no target stat and so
no gauge; on the old dark slab an empty row read fine, but the review gate
confirmed they collapse into near-empty strips on cream. They now take the
gauge's silhouette as a container: a stretched `StyleBoxTexture` whose alpha
ramps 0.18 → 1.0 left to right, with the category motif watermarked at the solid
end. Stretch, not tile — the `BarFill` fills tile, but a horizontal alpha ramp
sawtooths back to transparent at every repeat if tiled.

**Press state needed a script.** `Panel` has no pressed state, so `ActivityRow`
swaps its container's variation on `button_down`/`button_up`. The wiring is
deliberately ungated by `Engine.is_editor_hint()` — pure signal connection, no
side effects — so the suite can emit both signals and assert the variation
actually changes in both directions.

**Red and green now mean something.** Every confirm was a green/red pair
regardless of what was being confirmed. `DangerButton` is now reserved for
actions that discard something and `SuccessButton` for something earned;
ordinary confirms take `PrimaryButton` + `SecondaryButton`. Three exclusions
were found by reading the button text rather than trusting the plan's file
list — and the first would have been a real regression:

- **StudentList's green/red are status badges, not actions.** They read BELUM /
  SUDAH TERJADWALKAN. The colour *is* the information; recolouring them would
  have destroyed it.
- **The lobby's CLAIM is earned, not confirmed**, which is what `SuccessButton`
  is for.
- **QuitConfirmDialog was already correct** — `DangerButton` + `SecondaryButton`
  on a genuinely destructive action.

**Tests that pinned the old design were rewritten, not deleted.**
`test_preview_row_is_a_bordered_panel` became
`test_preview_row_is_an_unstroked_cream_panel`; the row-pitch test now asserts
the composed pitch rather than a bare constant that no longer describes the
spacing; `test_theme_factory`'s shadow test narrowed to the pill, which still
consumes its tokens.

**Placeholders left behind**, all recorded in `CLAUDE.md`: the recoloured
`penjadwalan_card_bg.png`, `track_ghost.png`, and the two motifs
`icon_ghost_koin.png` / `icon_ghost_sabit.png` — all generated with PowerShell +
`System.Drawing`, all drop-replaceable. `preview_row_shadow_color`, `_size` and
`_offset` are now read by no variation.

Suite: 1133 tests across 85 suites.

## 2026-09-09 — Warm UI system, Part 1

The palette, button geometry, bar contrast and lobby layout pass. Spec:
`docs/superpowers/specs/2026-09-08-warm-ui-system-design.md`. Plan:
`docs/superpowers/plans/2026-09-08-warm-ui-system-part-1.md`.

**Palette.** `brand_primary` moved from `#2e5bff` to `#7A4A2B`, with 35 token
values re-tinted warm and 16 new exports added. Every scene wipe in the game is
now chocolate rather than blue, because `Transition`'s cover colour is
`brand_primary` — a large visible change that no test covers.

**Button geometry.** `_pill()` became `_button_box()` and takes an explicit
radius. Before this, every button used `radius_pill = 999`, which Godot clamps to
half the box height — so the project's 15 authored heights rendered as 15
different corner radii between 31 and 145 px from one nominal style. Now one
fixed 20px radius, with chips and cards opting out explicitly.

**Height comes from the theme now.** `btn_pad_v_s/m/l` were solved by measuring
Boohong in-engine: `get_height()` returns exactly the font size, and
`StyleBoxFlat.get_minimum_size()` excludes the border, so `2*pad + font_height`
lands a button exactly on its size step. A scene sets no height at all. Twenty-nine
buttons across twelve scenes were moved onto the scale, and a ratchet test keeps
them there. Three of those heights were ones the plan's own survey missed.

**Bar contrast.** A WCAG floor of 3.0:1 now guards every fill against its track.
It immediately caught four light-track accents below the floor, which were
deepened rather than the floor being lowered. It exists because the DaySummary
energy bar had been shipping at 1.36:1 — invisible, not merely dim — and Olahraga
at 2.55:1, both green for months because nothing measured them.

**Lobby.** `LobbyNavButton` retired for `LobbyNavTile` and `LobbyCtaButton`. The
money display and daily-login button moved off the two front-row students' heads,
which they had been centred on. `DailyReward` was re-anchored to the scene root
first: its size was a multiple of `DailyLogin`'s via `anchor_right = 5.994`, so
resizing that button would have dragged the seven-day panel with it.

**Suite:** 82 suites, 1099 tests, 1098 passing. The one failure is a pre-existing
`project_hygiene` UID issue in scenes this pass never touched, recorded as the
baseline before work started.

**Recovered along the way:** the working tree had `assert_not_null` deleted from
`addons/godot_ai/testing/test_suite.gd`, which was breaking 21 suites and hiding
374 tests. Restored, with the removal saved as a patch.


## 2026-09-09 — StatCheck: tap anywhere to rush a student's reveal

Plan (Part B): `docs/superpowers/plans/2026-09-09-win-screen-lineup-and-statcheck-rush.md`.

`StatCheck` — the end-of-grade screen where one card per student slides in,
its three stat bars fill in turn, cleared stats light a share of the 3-star
meter, then the card slides out — is now tappable. A touch anywhere rushes
**the current student only**; the next student still animates at full speed
and needs its own tap. This reverses a recorded decision: the screen's file
header used to read "Deliberately NOT tap-driven: the check is a reveal the
player watches," and was rewritten rather than deleted so the reversal reads
as intentional rather than an oversight.

The mechanism is a speed-scale, never a kill. `Tween.kill()` does not emit
`finished`, and `_run_check()` awaits its tweens in sequence — killing one
would leave that await pending forever and strand the screen mid-card. A
rush instead calls `set_speed_scale()` on whichever tween is currently live
(`StatCheckRow.rush()`, `StarMeter.rush()`, and `StatCheck._hold()`'s own
tween), so it still completes and emits within a frame, running `cleared`,
the full-bar pop, the `filled` signal and the star credit through their
normal path rather than a special-cased shortcut. `StatCheckRow` carries a
source-scan test asserting the file contains no `.kill()` at all, precisely
to stop a future "simplification" from reintroducing it.

Both `hold_seconds` pauses (the entry beat and the trailing one before slide-
out) became `tween_interval()` tweens rather than `SceneTreeTimer`s, since a
timer cannot be sped up and a timer-based hold would swallow the tap for its
full duration. The trailing hold and the slide-out deliberately keep playing
at full length after a first tap — rushing is meant to reach the numbers
sooner, not hide them — so a second tap is needed to rush those too.

A `_rushed` flag on `StatCheckRow`, separate from the speed-scale call,
makes the rush stick to rows that have not started their tween yet: `rush()`
sets the flag even with nothing in flight, and `fill()` honors it the moment
it creates a tween. The first cut of this only sped up whichever tween
happened to be live at the instant of the tap, so a row that hadn't started
yet filled at full speed with its tally cue already suppressed — an audible
desync between the star meter and the sound. Only one `tally` cue now plays
per rushed student no matter how many stats cleared; three inside one frame
would overlap into a click.

The tap itself is taken in `_input()`, not `_unhandled_input()`: the
screen's `Scrim` and the card's `Paper` are `Panel`s at Godot's default
`MOUSE_FILTER_STOP`, which consume pointer events and mark them handled
before `_unhandled_input()` would ever see them, so the handler silently
never fired until this was caught. Follows the precedent already set in
`Scripts/CutScene/cut_scene.gd`'s tap-anywhere input.

Suite: `stat_check` green at 34 tests.

## 2026-09-09 — Win screen: roster lineup, letterbox, ground shadows

Spec: `docs/superpowers/specs/2026-09-09-win-screen-lineup-design.md`; plan:
`docs/superpowers/plans/2026-09-09-win-screen-lineup-and-statcheck-rush.md`.

`EndCutscene`'s win branch is rebuilt around new 1536×2048 art
(`Assets/Images/CG/Win/win_background.png`) instead of reusing the intro's CG.
`_fit_stage()` letterboxes the painting into the 1080×1920 screen by the
smaller of the two axis ratios, so the whole 3:4 image survives — 240px bars
top and bottom, filled by a new `BarFill` `ColorRect` whose `bar_color`
export defaults to `surface_overlay`'s literal value (a copy, not a live
token reference, so a future palette change has to touch both). `BtnNext`
("Lanjut") moved into the bottom bar, clear of the art. The lose branch is
untouched — same `cg_lose.jpg`, same GAGAL stamp, same slam timing.

The run's own approved roster stands on the new backdrop, posed from splash
art rather than the flat portraits used elsewhere. New
`Scripts/EndGame/WinLineup.gd` (`class_name WinLineup`, plain static
functions over Dictionaries — same shape as the debug overlay's end-of-grade
rehearsal jig, and tested behaviourally for the same reason) owns the
composition: three hand-arranged slot maps for 2/3/4-student rosters (grades
7/8/9), Doni pinned to the front slot whenever he's approved with everyone
else filling in `approved_students` order, and per-character foot anchors
measured from each splash's alpha at threshold 128. `EndCutscene._dress_lineup()`
only sets texture/size/position on eight authored `Student{1-4}` /
`Shadow{1-4}` nodes — nothing is constructed. Splash art is six typed
`Texture2D` exports rather than one Dictionary: a Dictionary's nested values
can't be wired as Resources through the editor's property API, so the paths
stayed strings and the textures never loaded.

Every figure gets a soft ground shadow (`shadow_ellipse.png`, tinted and
scaled per student from the measured foot span) drawn on a `Shadows` layer
that renders entirely before the `Students` layer, so no one's shadow lands
on another figure. A late fix caught a z-order bug the tests couldn't see:
`WinLineup.assign()` returned the front student first, and `_dress_lineup()`
maps array index onto sibling order, where the first child draws behind its
siblings — so Doni, who must read closest to camera, would have rendered
behind everyone. `assign()` now returns back-to-front, matching
`slots_for()`, so index-to-sibling is correct by construction; found by
compositing offline against the reference art, not by a test, so a test now
pins the draw order.

The win path shows no LULUS badge — the chalkboard art already reads
"Selamat Kelulusan," so a stamp over it would be redundant and would cover
the art. `win_badge` stays wired to `stamp_lulus.svg` but is never slammed
in on the win path.

Suite: 1133 tests across 80 suites, all green.

## 2026-09-07 — Inventory: mobile layout rebuild, item-apply flow, persistence

Spec/plan: `docs/superpowers/specs/2026-09-07-inventory-mobile-layout-and-item-apply.md`,
`docs/superpowers/plans/2026-09-07-inventory-mobile-layout-and-item-apply.md`.

Rebuilt the Inventory screen as a 3-zone portrait layout — Header (`&"Card"`,
with a visible **‹ Kembali** button + coin pill) / a horizontal
`FilterChipButton` chip row (icon + text, all four sharing one
`Scenes/Inventory/inventory_filter_group.tres` `ButtonGroup`) / a 3-column tile
grid + an authored `ToastLabel`. The vertical sidebar, `DetailPanel`,
`UsePopup` and every per-node `StyleBoxFlat` are gone; the rewritten
`Scripts/Inventory/inventory.gd` builds **zero** runtime visuals, so its
`tests/test_viewport_editability.gd` `BASELINE` entry (was 4) was removed. New
`FilterChipButton` `ThemeFactory` variation; theme rebaked.

Tapping a tile opens `Scenes/Inventory/ItemDetailSheet.tscn` (bottom sheet:
icon / name / category chip / description + an "Efek" block — a `+N` row and a
fixed plain-Indonesian explainer per affected bar, five authored `EfekRow`
instances). Its "Pakai ke Siswa" button opens `ApplyItemScreen.tscn`
(`ApplyStudentRow` template per approved student, `StatBarRow` sub-template,
multi-select with a live `65 ➔ 90 (+25)` preview on every affected `StatBar`,
"Pilih Semua", `Pakai (N Siswa)`), then a staged payoff: per-student
`RewardBurst` + `AnimUtils.create_floating_text` + rising `star_earn_1/2/3`,
one screen-wide `CelebrationConfetti` + `sparkle` when every pick gained,
`result_fanfare` to close.

**Items are now functional.** `ItemData` gained `akademis_boost` /
`seni_budaya_boost` / `olahraga_boost`. `GameState.use_item()` had a real bug —
it wrote dead dict keys `"mood"` / `"energy"` instead of the canonical
`kepribadian1` / `kepribadian2` / `akademis1/2/3`, so item use never reached a
simulation — now fixed and given the three skill boosts. New
`GameState.use_item_on_students(item, ids)`: an all-or-nothing batch that
pre-checks both the owned stock and that every id exists in `approved_students`.

**Persistence** — the project's first on-disk save, deliberately minimal:
**only `GameState.inventory`** → `user://inventory.cfg` (`ConfigFile`, flushed
at the top of every `Transition.change_scene`, loaded in `GameState._ready`);
`save_inventory` / `load_inventory` / `clear_inventory_save` all no-op under
`Engine.is_editor_hint()`. `GameState.forget_session()` resets in-memory
run-state (keeping the persisted `is_game_beaten` / `debug_level_select_enabled`
flags) and is wired to a new **🧹 Forget Session** button in DebugManager's
General tab. Item boosts land on `approved_students`, which is *not* persisted,
so a boost applied and not simulated before quit is lost and a fresh run
inherits the previous run's stock — see `CLAUDE.md`'s persistence note.

Six new test suites (`item_catalog`, `use_item_on_students`,
`inventory_persistence`, `item_detail_sheet`, `apply_student_row`,
`apply_item_screen`), +25 tests. Built via subagent-driven development — the
controller held the Godot MCP bridge (implementers wrote `.gd`; the controller
authored every `.tscn` and ran every `test_run`); one editor restart cleared a
stale `ItemDatabase` autoload after the first task. The opus whole-branch review
returned four Important modal-lifecycle-guard findings (double back-handling,
double-tap opening two apply screens, a back press during the payoff `await`
hitting a freed node, a persistence test that deleted the real save) — all
fixed and scoped-re-reviewed clean.

## 2026-09-07 — Sprite rigs, event dialog, day phases and the shop hub

Five independent presentation passes landing one art drop. Spec:
`docs/superpowers/specs/2026-09-07-sprite-rig-and-shop-hub-design.md`;
plan: `docs/superpowers/plans/2026-09-07-sprite-rigs-and-shop-hub.md`.

**Goalie (`MainBola`).** Four opaque `.jpg` goalie textures collapse to
two alpha PNGs, so the keeper stopped rendering as a white box over the
pitch. Dive direction is `flip_h` on the single `kiper_jump` sprite
rather than a left/right texture pair; which way that art faces is the
`jump_faces_right` export, not a constant. `goalie_fail_texture` went
with them — it was declared and never read. Added idle breathing: a sine
on the sprite's scale pivoted at the FEET (scaling a standing figure
about its middle lifts it off the goal line), suspended and rewound
while a dive resolves.

**Dancer (`LombaMenari`).** Six flat pose textures became a two-layer
`DancerRig`: a body swapping between three poses and mirroring for the
left-hand arrows, and a head that does neither, so her face and hairclip
stay fixed. The head offset was solved, not eyeballed — compositing
`dance_head` over `dance_body_idle` and minimising per-pixel difference
against `dance_mockup.png` converges on **(+2, +28)** on the sprites'
1280 canvas, stored as a ratio so it survives any rect size. All three
body poses put the neck within a few pixels of the same spot, so one
offset serves every pose. A miss has no drawn pose, so it is the idle
body tinted red plus the shake-and-droop already written.

**Event dialog.** Per-student cards come from `EventStudentCard.tscn`,
assembled from the DaySummary components that already existed, instead
of being built from raw containers at runtime — the script went from
~470 lines to 272 and its editability baseline from 11 to 1. The whole
992×410 card is now the toggle, replacing a 2.4×-scaled Godot CheckBox
that matched nothing else in the game. Eleven emoji became SVG icons
(four new, five reusing icons the project already had). The per-button
`StyleBoxTexture` override path is gone. The on-check stat preview,
including the specialty energy discount, is unchanged.

**Day cycle.** The sky's single continuous sweep became three named
poses — dawn, midday, evening — and two transitions. `set_progress` maps
piecewise through midday, so progress 0.5 lands on it by definition
rather than by arithmetic, which is what lets midday be retuned alone.
The day's event stopped rolling at a random 50–80% of the afternoon and
lands on the midday pose. `transition_to` returns its Tween so
`SchoolDay` can await it and the easing has one place to be tuned.
Defaults reproduce the old geometry exactly: only the timing changed.

**Shop hub.** The Lobby's shop button lands on a new `ShopHub` with two
tiles rather than dropping into the Koperasi; both shops' back buttons
return there. `CosmeticShop` is a deliberate stub. The backdrop reuses
the existing screen-space blur shader over the Koperasi's own artwork,
so the screen needs no new image asset — the mockup's blurred
minimarket photo is not in the repo and would have been the only
photograph in an illustrated game. Tiles are labelled in Indonesian,
overriding the mockup's English.

**A bug this pass introduced and then caught.** `kejartes_theme.tres`
was reverted by the editor before the event-card commit, so it shipped
without the `EventSelectCard` variation while every test stayed green:
`test_theme_factory` only ever called `ThemeFactory.build()` fresh and
never read the file the game actually loads. `test_baked_theme_matches_what_the_factory_builds`
now compares the two, reading the baked file with `CACHE_MODE_IGNORE`
because the editor holds the old copy in memory.

**Two editor hazards worth knowing** (both cost real time here):

- The editor keeps `.gd` files open in script-editor tabs, and
  `scene_save` flushes those stale buffers over your edits — the same
  cache hazard `CLAUDE.md` documents for `.tscn`, but for scripts. Do
  scene work first and script work second within a task, and check
  `git diff` on already-committed scripts after any `scene_save`.
- Godot only serialises property overrides on an instanced scene's own
  ROOT. Setting properties on the instance's children silently loses
  them on save; give the sub-scene `@export`s instead (this is why
  `ShopHubTile` carries `icon_texture` and `caption_text`).

Suite: 1034 tests across 69 suites, all green.

## 2026-09-06 — Lobby: layered student faces, gaze and blink rig

Reworked the lobby diorama's student sprite from a single flat portrait
TextureRect into a six-layer rig, starting with Citra. New
`Scenes/Lobby/CitraFace.tscn` (script `Scripts/Lobby/StudentFace.gd`,
`class_name StudentFace`) stacks, back to front: Base, Sclera, Pupil,
Eyelashes, Eyelid, Eyebrows. `loby.gd` now instances a rig into a roster
slot when the student has one — matched by the rig's own `student_name`,
read off the PackedScene's saved state — copies the flat portrait's rect
onto it and breathes it identically, so the diorama layout is unchanged.
Students with no rig keep the flat portrait; `face_rigs` is an `@export`
array so adding a character is dropping their `.tscn` in.

The art arrived as six separately-cropped PNGs with no canvas offsets, so
every layer position was solved rather than eyeballed: each crop was
template-matched back onto the flattened `Citra.png` (eyelashes and eyebrows
both matched at 100% of sampled pixels), and Sclera/Eyelid were pinned
exactly by the transparent eye cut-outs in `citra_base.png`, which each
plugs to the pixel with a unique solution. `tests/test_student_face.gd`
freezes that solve in `_GEOMETRY`.

Two things worth remembering. `citra_eyebrows.png` was delivered as
`citra_eyelashes_closed.png` and first wired as the lower half of a blink;
it is the eyebrows, always visible, and topmost because the base has hair
(not brows) underneath. And the pupil is drawn to fill the eye white
exactly — a strict all-pixels check gave a travel envelope of roughly ±7px
before the iris spilled onto skin — so gaze motion instead clips the Pupil
layer to the Sclera's alpha through the new
`Scripts/Shaders/eye_mask.gdshader`, letting it travel freely. The material
(`Scenes/Lobby/citra_eye_mask.tres`) is `resource_local_to_scene` so four
seats do not share one set of uniforms.

Idle gaze is on: ease-out saccades to a point in a ±20×±7 canvas-pixel
ellipse, 1.4–4.2s holds, per-instance RNG so seats never sync. Idle blink is
wired but off — see `CLAUDE.md`'s outstanding-debt entry.

## 2026-09-05 — Typography: swap the display face to Boohong

Repointed `DesignTokens.font_display` from `Catfiles.otf` to `Boohong.otf`
(Khurasan) and rebaked the theme. Landed in two steps same-day: the request
named the font only as "boohoong," and at that point neither new drop
(`Brocats.otf`, `Catcut.otf`) matched that name in its embedded font-name
table, so `Brocats.otf` went in as a placeholder pending clarification; the
correctly-named `Boohong.otf` was dropped in shortly after and the token was
repointed to it. No classification changes either time: the heading/body
split fixed in the Catfiles pass below is a single design-token indirection,
so every `ThemeFactory` type variation that already took `font_display`
(headings, titles, buttons, badges, stat numerals) picked up each new face
with no other edits. Updated `tests/test_fonts_present.gd`'s hardcoded
path/messages, `Assets/Fonts/README.md`, and `CLAUDE.md`'s typography line
to match. `Brocats.otf`, `Catfiles.otf`, and `Catcut.otf` all stay in the
repo unused, alongside Milker/Baloo2/Nunito.

## 2026-09-05 — Typography: Catfiles heads, Open Sans Medium body

Imported `Catfiles.otf` and the Open Sans family (none had `.import`
sidecars) and pointed `DesignTokens.font_display` / `font_body` at
Catfiles and OpenSans-Medium. Both slots had pointed at `Milker.otf`, so
the head/body split existed in code and was invisible on screen.

Fixed the classification bug behind that: `ThemeFactory._build_labels`
applied the display font inside the `outlined` branch, so `H2Label` and
`TitleLabel` — headings that are not outlined — silently took the body
face. Added an explicit `heading` column and promoted `H2Label`,
`TitleLabel`, `CardSectionLabel` and `ResultHeroLabel`.

The plan's own test for this, `test_body_labels_do_not_take_the_display_font()`,
turned out to be broken: it asserted `theme.get_font("font", name) == null`,
but `Theme.get_font()` always falls back to the theme's `default_font` when a
type has no explicit override, so the assertion could never be null and never
actually failed regardless of whether the bug was present. Diagnosed live
against the running editor and fixed by switching to
`not theme.get_font_list(name).has("font")`, which checks for an explicit
per-type override with no fallback chain. `ThemeFactory.gd` itself was
correct throughout; only the test assertion was wrong (`4c71a8c` then the
one-line fix in `967eed4`).

`BarLabel` (130 scene uses) stays on the body face deliberately: it is
stat-bar chrome, not a heading.

No scene edits were needed — a grep proved zero `theme_override_fonts/`
entries in any shipped `.tscn`, so the whole font family resolves through
the theme. The 70 `theme_override_font_sizes/` entries are sizes, in
minigames and koperasi/inventory, and were untouched.

The visual audit (Task 5) found and fixed two real overflows, everything
else surveyed — Lobby, AturJadwal, SchoolDay's event dialog and result
recap, StatCheck, EndCutscene, RunResult, TesNotice, MainMenu's splash —
rendered cleanly. Only the first of the two is actually caused by
Catfiles' wider glyphs; the second (the CutScene grade-select modal) was
already overflowing under the old placeholder font — measuring actual
advance widths showed Catfiles is narrower than the placeholder for every
string in that modal, so the audit surfaced a pre-existing bug there
rather than causing a new one:

1. `student_card.tscn`'s `PilihMurid` label (a `DisplayLabel`, text "Pilih
   Muridmu") sits on a free-floating Control outside any container. Its
   unwrapped runtime width (825px, measured live) ignored its authored
   635px box and ran 74px past the 1080px screen edge. Fixed by widening
   and repositioning the box (`offset_left` 329→90, `offset_right`
   964→990).
2. `cut_scene.gd`'s debug-only grade-select modal (built at runtime,
   styled via `theme_type_variation`) grew past its 900px panel width
   because its title `Label` had no `autowrap_mode` (unlike `subtitle`
   right below it, which already wraps) and its three grade `Button`s had
   no `clip_text` (unlike `btn_skip`/`btn_debug_toggle` earlier in the
   same file, which already guard against this exact failure mode with an
   explanatory comment). Fixed by extending both of the file's own
   existing patterns to the two spots that hadn't needed them before. One
   accepted residual: two of the three buttons still lose the tail of
   their second (description) line to `clip_text`, since a plain `Button`
   can't wrap multi-line text independently per line — a pre-existing
   tight fit that Catfiles narrowed further, not something this pass
   created outright. A proper fix (splitting each button into separate
   title/description child Labels) was left as a follow-up rather than
   expanding scope. (`060c8f9`)

Noted in passing, not changed: ten minigame scripts (`Menjodohkan.gd`,
`Password.gd`, `PilihanGanda.gd`, `Variabel.gd`, `Badminton.gd`,
`MainBola.gd`, `BuatBatik.gd`, `LombaMenari.gd`, `MinigameTutorial.gd`,
`PauseMenu.gd`) declare `@export var font: Font = null` and call
`add_theme_font_override` behind `if font:`. No `.tscn` assigns the
export, so the calls are inert — minigames are out of scope for the
design system.

`tests/test_fonts_present.gd` (new) guards import + glyph coverage;
`tests/test_theme_factory.gd` gained `DISPLAY_ROSTER`, asserted in both
directions. Suite count: 64→65 suites, 949→959 tests.

## 2026-09-05 — Motion Lab skill

Added `.claude/skills/motion-lab/`, an in-browser easing editor for this
project's Tween motion, built on branch `worktree-motion-lab`. Spec:
`docs/superpowers/specs/2026-09-05-motion-lab-skill-design.md`; plan:
`docs/superpowers/plans/2026-09-05-motion-lab-skill.md`. The user names an
element and scene; the skill resolves what animates it, publishes a checked-in
HTML editor (`assets/editor.html`) as an Artifact with a preset grid, an
oscilloscope-style curve graph, a ball-plus-stand-in preview and tuning
controls, then patches the user's returned one-line token
(`KJT-MOTION v1 | TRANS/EASE | 0.320s | travel 0.90 | property | element@scene`)
into the real call site. The page previews only native Godot `Tween` presets —
never a bezier/`Curve` alternative — so nothing separates what the browser
shows from what the engine plays: `tests/test_easing_table.gd` bakes all 48
transition × ease combinations from `Tween.interpolate_value()` itself into
`assets/godot-easing.json` (256 samples each, ~97 KB) and re-verifies the
table against the live engine on every run, catching a future Godot upgrade
that changes a curve. One real engine quirk surfaced this way: `TRANS_EXPO`'s
`IN` and `OUT_IN` legs settle at 0.999-something rather than exactly 1.0 (`OUT`
and `IN_OUT` do land on exactly 1.0) — genuine, not a sampling bug, so that one
family gets a looser end-of-curve tolerance in the test rather than the other
47 combinations losing precision.

The intensity slider means two different things depending on the transition:
for the seven families whose curve can steepen (`LINEAR` through `EXPO`) it
walks that ladder; for the five whose shape Godot fixes (`BACK`, `ELASTIC`,
`BOUNCE`, `SPRING`, `CIRC`) it scales how far the property travels instead —
labelled on screen so the two behaviours are never ambiguous. Duration snaps
to this project's real `design_tokens.tres` values (`dur_instant/fast/normal/
slow`). `SKILL.md`'s guard rail stops before patching a helper shared across
screens (`Juice.press`, `Juice.pop_in`, `AnimUtils.squash_bounce`, and 30-odd
others) and asks whether to retune it globally or add a per-call parameter,
rather than silently restyling every consumer.

The end-to-end rehearsal (Task 6) ran the whole pipeline against a real
target — the `Lanjut` button's reveal in `EndCutscene.tscn`, which turned out
to run through the shared `Juice.pop_in` (12 call sites), correctly tripping
the guard rail rather than patching a change through — and turned up two real
bugs neither the source-scan tests nor a screenshot caught: `navigator.
clipboard.writeText()` throws `NotAllowedError` when the document lacks focus
(a real state a user can hit, not just a test artifact) with no visible
feedback, fixed with a select-the-text fallback; and a fixed-size `<canvas>`
was overflowing its CSS Grid track at narrow widths — grid items default to
`min-width: auto`, so an intrinsically-sized child can force the track wider
than the viewport — fixed with `min-width: 0` on the grid items. Both were
found by driving the actual rendered page (DOM queries, a forced clipboard
rejection, real width measurements) rather than trusting the source scans
alone. Suite count: 45→64 suites, 568→940 tests.

## 2026-09-04 — Grade-progression balance and difficulty

The 2026-09-04 grade-progression difficulty pass is complete, built on branch
`minigame-reward-feedback`. Spec:
`docs/superpowers/specs/2026-09-04-grade-progression-balance-and-difficulty.md`;
plan: `docs/superpowers/plans/2026-09-04-grade-progression-balance-and-difficulty.md`.
It retuned grade 7 to need tactical subject-rotation instead of one lucky week
(via a new per-student weekly minigame-points cap —
`Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7/8/9` = 14/12/10 — rather
than touching grade-7 study rates), ramped grade 8/9 targets
(`TARGET_KENAIKAN_KELAS_8` 30→34, `_KELAS_9` 40→**40 shipped**, see the spec's
Status block for why the 50 estimate moved), amplified quirk/specialty
coefficients ~1.4×, ramped the Skip button's loss chance per grade
(`SKIP_PELUANG_KALAH_KELAS_7/8/9` 0.4/0.5/0.6), added `GameState.
reset_roster_for_new_grade()` — a 20%-head-start roster reset shared by real
grade progression *and* the debug grade-jump buttons, which previously left
skill stats carried over — and closed a minigame-farming exploit
(`SchoolDay._roll_event()`/`skip_to_results()` now roll a randomized 1-3
weekly minigame allowance and a 35% chance the category is picked uniformly
rather than by schedule, without touching how often minigames/events appear
at all). AturJadwal got new specialty-match feedback: a gold particle burst
(`SpecialtyMatchBurst.tscn`) plus the `specialty_match` SFX cue on the sticky
note when a day is scheduled onto a student's specialty subject, and a ★
badge on the Penjadwalan picker row beforehand. A new headless suite,
`tests/test_balance_pacing.gd`, runs a scripted greedy simulation against the
real simulation functions and is the tuning/regression harness for these
numbers going forward. Built via subagent-driven development with the
controller holding the Godot MCP bridge throughout; one fix round needed a
human editor restart to clear a stale-bytecode reload (`Balance.gd` served an
old field value across every MCP-available recovery lever) — not a code
defect, just a one-off editor quirk worth knowing about if a future session
hits `GDScript reload failed with error code 43` on a repeatedly-patched
file. Placeholder outstanding: `sfx_specialty_match` aliases the existing
`sfx_reward` stream, same convention as this project's other recent cues.

## 2026-09-04 — Minigame reward feedback

The 2026-09-04 minigame reward pass is complete. Plan:
`docs/superpowers/plans/2026-09-04-minigame-reward-feedback.md`. It fixed the
one-star bug — `_calculate_stars()` read `max_score`, which only the four
Akademis quizzes declare, so every win in MainBola, LombaMenari, Badminton
and BuatBatik was hard-capped at one star — by replacing it with an
overridable per-game `get_star_ratio()` mastery metric (shot accuracy, note
accuracy, rally margin, mistake-free sequence) and a two-star floor for an
unrated win. It then moved the result card's chrome off runtime
`StyleBox`es onto seven new `ThemeFactory` variations, replaced every emoji
glyph with a transparent SVG, gave the star reveal an escalating pop with
per-star bursts and three rising audio cues, gated confetti on a
three-star finish, and replaced the ad-hoc `ScoreLabel`s with the shared
`MinigameScoreHUD` template. Placeholders outstanding: the six new
`AudioDirector` cue ids (`star_earn_1/2/3`, `result_fanfare`, `score_tick`,
`combo_up`) all alias `pop.ogg` / `reward.ogg`, the seven new icon SVGs are
flat white placeholder geometry, and `LombaMenari.best_combo` is tracked
but not yet fed into the rubric, pending a real balance pass.

## 2026-09-04 — The star win rule

The win rule moved with the StatCheck rework: `GameState.check_semester_passed()` is now
`run_stars() >= Balance.STAR_WIN_THRESHOLD` (2.0 of 3.0) — two-thirds of
all academic targets cleared anywhere on the roster, no longer
all-or-nothing, so one weak student no longer loses the run.

## 2026-09-03 — Daily Results polish and rewards

The 2026-09-03 Daily Results polish pass is complete. Spec:
`docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md`. It
fixed the `DaySummaryStatRow` value-label overlap bug (a mis-anchored
`Value` node printed "+12/65" over its own coloured track), re-pitched the
card's three stat rows to an even 97 px, and gave the energy/mood bars an
icon and an Indonesian tier word (`Lelah`/`Cukup`/`Bugar`,
`Sedih`/`Biasa`/`Senang`) carried *inside* the existing `EnergyBar`/
`MoodBar` nodes (`DaySummaryNeedsBar.gd`) rather than a redundant sibling
chip — the spec's own §3.2 was revised mid-brainstorm once that
duplication was caught. It also added reward particles: a per-stat-row
star burst (`RewardBurst.tscn`) fired off a gaining chevron, and a
screen-wide confetti fall (`CelebrationConfetti.tscn`) on `ResultCheckup`,
both gated on `DaySummaryStudentRow.gained_ground()` so a flat or losing
day/week stays quiet. Two new `AudioDirector` cues, `tally` and `sparkle`,
alias existing SFX files as placeholders. Same build discipline as the
2026-09-02 pass — see that entry below for the controller/subagent MCP
split, which this pass also used throughout (its SDD ledger was deleted
after merge). Placeholders outstanding: the three particle sprites
(`Assets/Images/Particles/particle_*.png`, crude flat geometry) and the
two aliased SFX streams.

## 2026-09-02 — End-of-grade sequence

The 2026-09-02 end-of-grade sequence is complete. Spec:
`docs/superpowers/specs/2026-09-02-end-of-grade-sequence.md`; plan:
`docs/superpowers/plans/2026-09-02-end-of-grade-sequence.md`. It added the
Tes Besar notice, the cutscene's third (exam) branch, a per-grade `RunStats`
tally on GameState (`RunStats.gd`), the `RunGrade` A+/…/C-/D scorer
(`RunGrade.gd`), a cutscene-styled WinScreen, the `RunResultRow` template,
and the RunResult report screen — which now owns grade progression, moved
off SemesterEnd (`SemesterEnd.gd::_on_restart_pressed()` no longer advances
the grade). SemesterEnd was also restyled: the flat near-black background is
now the blurred-classroom backdrop, and its page dots are authored `.tscn`
nodes (`PageDotLabel` theme variation) instead of runtime-built `Label`s.
Report icons are real transparent SVG textures
(`Assets/Images/UI/Placeholders/icon_*.svg`), never emoji glyphs — the
project explicitly banned emoji as UI iconography during this pass.
Placeholders still outstanding: every cutscene line in the exam and win
branches is marked `[PLACEHOLDER]`, the exam/win backdrops reuse the intro's
CG images, the three new BGM ids (`exam_notice`, `exam_cutscene`,
`run_result`) alias existing tracks, and `RunGrade`'s scoring weights
(especially `MONEY_FULL_MARKS`) are estimates pending a real-run balance
pass. Built via subagent-driven-development with the Godot MCP bridge held
by the controller session throughout (implementer subagents write
scripts/tests/assets; the controller builds every `.tscn` and runs every
`test_run`) — its SDD ledger held the fix-loop history but was deleted
after merge.

## 2026-09-02 — AturJadwal warning frame and StatBar polish

**Plan:** `docs/superpowers/plans/2026-09-02-atur-jadwal-warning-and-statbar-polish.md`

The 2026-09-02 AturJadwal polish pass is complete. Spec:
`docs/superpowers/specs/2026-09-02-atur-jadwal-warning-and-statbar-polish.md`.
It reframed the PERINGATAN dialog onto `penjadwalan_card_bg.png` as a
nine-patch, and rebuilt how every `StatBar` in the game is coloured: the
category colour is now baked into a per-category fill stylebox rather than
applied with `self_modulate`, because `self_modulate` multiplies the whole
node and made a bar at value 0 render as a solid capsule that looked 100%
full. It also fixed `StatBar` building a second `ValueLabel` on top of the
one authored in the scene — AturJadwal had five such bars, ReportCard about
thirty. Read that spec's "Two hazards worth remembering" before touching
`StatBar.gd`.

## 2026-09-01 — Art pass and screen restyle

The 2026-09-01 art pass is complete except for one deferred item. Spec:
`docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`; five plans
in `docs/superpowers/plans/2026-09-01-*.md`, each carrying a STATUS block with
its deviations. It landed the six-student splash batch (all four rosters
rewired, Daily Results avatars recropped, and the avatar flipped to
splash-first as `DaySummaryAvatar.gd` had asked), the blurred-classroom
backdrop on DaySummary / ResultCheckup / AturJadwal, ReportCard/StudentCard
render parity, AturJadwal's mockup top band with the stat pills lifted out of
the splash button, and the intro cutscene's new dialogue panel.

## 2026-08-31 — Main menu mockup rebuild

**Plan:** `docs/superpowers/plans/2026-08-31-main-menu-mockup-match.md`

The main menu was rebuilt on 2026-08-31 to match
`docs/superpowers/mockups/main-menu.png` measurement-for-measurement and is
now the boot scene — see
`docs/superpowers/specs/2026-08-31-main-menu-mockup.md` for the probe trail
and the documented deviations (66 px button separation, font size 80 rather
than the mockup-implied 100 so "PENGATURAN" fits, gold button art rather than
the mockup's grey, and an ungraded background).

## 2026-08-30 — Project stability sweep

**Spec:** `docs/superpowers/specs/2026-08-30-project-stability-sweep-findings.md`

The 2026-08-30 stability sweep
(`docs/superpowers/plans/2026-08-30-project-stability-sweep.md`) is complete.

Not a bug, but tracked debt: `tests/test_viewport_editability.gd`'s
`BASELINE` still lists real unconverted runtime UI construction across
~20 files — the 2026-08-31 21-task pass converted every shared-across-screens
case but did not survey every remaining file. See the authoring guide's
"Known gaps" section for the list and what each would need.

1. **The `test_audio_director` coroutine test** (old #1) — fixed. Both offending
   tests are non-coroutine now, and the suite snapshots/restores the global
   AudioServer bus state in `setup`/`teardown`, so a run can no longer dirty
   `Assets/Audio/default_bus_layout.tres`. If you see that file modified with no
   audio work done, it is a *new* leak, not this one.
2. **`test_audio_coverage` double-SFX** (old #2) — did not reproduce on
   2026-08-30; that suite passes. The entry was stale.
3. **Stale `ext_resource` UIDs** (old #3) — fixed. All 14 across 5 scenes now
   point at their real assets, and
   `tests/test_project_hygiene.gd::test_every_scene_ext_resource_uid_resolves_to_its_own_asset`
   fails the build if a new one appears.
