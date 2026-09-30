# KejarTes — outstanding debt & placeholders

Live, unfinished items: placeholder art, audio and copy, deferred passes and
known bugs. They moved here from `CLAUDE.md` on 2026-09-14 so they stop costing
context in every session. This file is **not** loaded into sessions, so grep it
for a screen or asset before you change one. Constraints that bind any change
to these assets stay in `CLAUDE.md` under `## Visual system`, because the
`claude-review` bot reads only that file. Section names below (`## Conventions`)
refer to `CLAUDE.md`.

New debt goes here, not in `CLAUDE.md`. Delete an entry when it is resolved —
do not mark it done and leave it here.

**Group placeholders, do not list them.** A dozen entries each saying "X is
generated `System.Drawing` art, drop-replaceable" is one entry with a path
list. Keep the prose only for the ones carrying a real constraint.

Every entry was checked against the source on 2026-09-14 (`c8e5153`). Where
that check changed a claim, the old wording is in `CHANGELOG.md`'s entry for
the day.

## Placeholder art

**Generated placeholder art.** Produced with PowerShell + `System.Drawing`, not
hand-authored. All are transparent PNG/SVG, drop-replaceable at the same path
with no code change: the five generated `Assets/Images/UI/Nav/` icons
(now unreferenced -- see the UI depth pass entry below; **not**
`UI/Nav/return_button.png`, which is authored art delivered
2026-09-22 — do not regenerate that one over the top of it),
three `Particles/particle_*.png`, the minigame
result + report icons and `icon_benefit`/`icon_cost`/`icon_tired`/`icon_check`
(`UI/Placeholders/`), `icon_shop_items`/`icon_shop_cosmetics` (`Shop/UI/`), the
event-popup set (`icon_event.svg`, `bg_event_dialog.png`),
`shadow_ellipse.png`, `bg_inventory_blur.png`,
`Minigames/SeniBudaya/note_arrow.png` (Lomba Menari's note, recoloured white
and turned to point right from `UI/Placeholders/arrow.png` with Pillow; a
replacement must point **right**, keep a white fill for the lane tint and a
dark outline, and `tests/test_lomba_menari_arrow.gd` checks all three),
four `icon_filter_*.svg`
(white on purpose: `FilterChipButton` inks its icons `brand_primary`, so a
replacement must stay a white glyph, or that tint comes out of `ThemeFactory`
with it; `test_light_ground_text.gd` holds them at 3:1 on both chip states),
`EndCutscene`'s two badges, the
eight `BarFill/fill_*` motif tiles, the 2026-09-10 cream-pass assets
(`Assets/Images/UI/BarFill/track_ghost.png`, `icon_ghost_koin.png`, `icon_ghost_sabit.png`;
`penjadwalan_card_bg.png` was part of this pass too, but Phase 2 left it
unreferenced -- see the UI depth pass entry below),
the 2026-09-24 SchoolDay liveliness set (the sky's `Assets/Images/SchoolDay/Sky/`
sun, moon, star field and rain streak -- its clouds are now the artist's final `Sky/cloud_layer.png`, 2026-09-30; the avatar rings in
`SchoolDay/Avatar/`; the weekday motif tiles in `SchoolDay/Motifs/`; the event
band's `caution_tape.svg`; and `night_windows.png`, generated from
`transition_foreground.png` -- regenerate it if that painting changes),
the 2026-09-24 picker icons (`Assets/Images/UI/Picker/arrow_down.svg`, `pip_coin.svg`, `badge_check.svg`; hand-drawn vectors in the
token colours, sized to draw at 1:1),
the 2026-09-28 Settings controls (`Assets/Images/UI/Settings/switch_on.svg`,
`switch_off.svg`, 112x64, and `slider_grabber.svg`, 56x56; hand-drawn
vectors in the token colours, reaching the theme through `DesignTokens`),
the 2026-09-11 Koperasi rework set: `Assets/Images/Shop/UI/icon_keranjang.svg`,
`icon_keranjang_kosong.svg`, `tray_dots.png` (this last must
stay 26x26 -- it is a tiling texture and `tests/test_koperasi_tray.gd` asserts
those exact dimensions; in Godot 4 the repeat comes from the node's
`texture_repeat`, not a texture import flag), and the 2026-09-10 StudentList
Part 3 set: `UI/Placeholders/icon_wirausaha.svg`
(completed the six-category placeholder set; now UNREFERENCED -- its last
caller, Dapatkan Uang's tip, moved onto `UI/Icons/cat_wirausaha.svg` in UI
depth pass Phase 3), `UI/Placeholders/stamp_sudah.svg` /
`stamp_belum.svg` (status-badge rubber-stamp rings), and
`UI/StudentList/photo_corner.png` / `roster_avatar_frame.png` / `catatan_rule.png`
(portrait tape, the avatar state ring, the teacher's-note rule — the last two
drawn white so `self_modulate` tints them from tokens), and
`UI/StudentList/page_dot.png` (a filled dot -- tinting the hollow ring above
it reads as invisible on a phone), and the 2026-09-14 EventDialogue set in
`Assets/Images/EventDialogue/`: `hujan_background.png` (the school tinted
dusk-blue with seeded rain streaks) and `calendar_badge.png`, and the weekly
report's title, now a themed brown plate reading HASIL MINGGUAN (`ResultCheckup.tscn` `TitlePlate`, 2026-09-29); an artist's brown
ribbon with those words can replace the plate node, and the 2026-09-18 Koperasi stock-pip set:
`Assets/Images/Shop/UI/pip_filled.svg` / `pip_hollow.svg` (a plain filled
dot and a matching ring, coloured from `koperasi_tag_fill`/`koperasi_tray_rule`
to stay warm and shop-consistent -- drop-replaceable at the same path), and the
2026-09-24 AturJadwal washi tape, `Assets/Images/AturJadwal/washi_tape.svg`
(hand-written SVG, not generated: a white striped strip with zigzag ends,
drawn white because `DayStickyNote` tints it by `self_modulate`, so a
replacement must stay light-on-transparent; keep it 246x40, the size it
displays at, or `test_texture_mipmaps` will want mipmaps on it), and the
2026-09-28 daily-login streak flame, `Assets/Images/UI/DailyLogin/streak_flame.svg`
(hand-written two-tone paths, 64x64, no `<text>`; the panel scales it
0.8-1.3x by streak day and tints it `currency_gold` on day 7, so a
replacement should stay warm and light enough for that tint to read), and
the 2026-09-28 daily-login reveal's chest, which has no art at all yet:
`DailyRewardReveal`'s `chest_base_texture` / `chest_lid_texture` are empty and
`use_chest_sprite` stays off until both exist, so the claim moment ships on the
gift fallback (Box crops the day-1 slot's gift out of `day1.png`, Lid hidden).
Drawing them means setting the three exports on the reveal's root in
`DailyRewardReveal.tscn`; the Lid's hinge pivot is already authored, and the
2026-09-27 Lobby scrapbook HUD set in `Assets/Images/UI/LobbyHud/`
(`book_cover.png`, `book_page.png`, `coin_plate.png`, `progress_plate.png`,
`chevron_grip.png`, `icon_plus.svg`) standing in for the book/page/plate/grip
art in `docs/superpowers/specs/2026-09-27-lobby-scrapbook-hud-design.md` § 6,
drop-replaceable at the same paths, within the plate insets below. Every PNG's 9-slice
margins are whole pixels: `book_cover.png` 96x96, margins L24 R24 T24 B40
(the bottom margin carries its lip band); `book_page.png` 96x96, margins L18
R18 T18 B18; `coin_plate.png` 120x64, margins L20 R20 T18 B26;
`progress_plate.png` 160x64, margins L20 R20 T18 B26; `chevron_grip.png`
96x48, margins L26 R26 T8 B8 (a full pill, so the top/bottom margins are only
a small buffer, not the cap radius). Since 2026-09-30 `book_cover.png` is a
light wood (#D9AA83) while `chevron_grip.png` stays dark brown, because the
grip's glyph is the shared gold chevron; real grip art must keep the gold
chevron readable. Since the 2026-09-29 layout grid pass
the progress tag's contents sit 6 px from `progress_plate`'s left and right
edges and 8 px from its top, and the coin box's icon and `+` sit 12 px from
`coin_plate`'s sides, so a replacement plate's visible rim must stay inside
those insets, or the tag and coin box need re-laying out. Still pending, waiting on real art: the
dashed washi rim and tape, and JADWAL!'s washi flutter (deferred by the plan's
Q4 -- `StyleBoxFlat` cannot draw dashes), the 16 UI icons in
`Assets/Images/UI/Icons/` (placeholders for the owner's chunky set; rules in
that folder's README, pinned by `test_ui_icons`), and the notebook frame's
`spiral_ring.png`, `paper_rule.png` and `sticker_stitch.png`
(`Assets/Images/UI/Notebook/README.md`).
(Checked 2026-09-14: `Particles/` also holds four more placeholder
`particle_*.png`: coin, glow, plus and spark. The event-popup set outlived the
popup: `icon_event.svg` is used by the week-recap rows and RunResult, and
`bg_event_dialog.png` by `EventStudentSelectDialog`.)

**Lobby book drag (2026-09-29).** A vertical drag that starts on the coin plate
(now in the book's step) does not drag the book: `DisplayUang` ignores the
mouse and `LobbyHud` only listens on the `raised_block` and `shelf`
`gui_input`. The `+` still taps. Fix by letting the plate pass its drag to the
HUD, if the owner notices.

**Achievements polish (2026-09-18).** `AchievementTile`'s lock overlay is a
placeholder `Assets/Images/UI/Placeholders/icon_lock.svg` (plain padlock
glyph, drop-replaceable at the same path); the CLAIMED check badge reuses
the existing `icon_check.svg` from the same folder, no new asset needed.

**Other art gaps.** `Assets/Images/EndGame/ujian_sekolah.png` (TesNotice's
Kelas 7-8 title) was keyed out of a black-background JPG -- brightness to
alpha, colour un-premultiplied, cropped -- not exported transparent; swap in a
real transparent export at the same path when one exists.
`EndCutscene`'s lose backdrop is `cg_lose.jpg` standing in for final art
(`WinStage`'s `lose_backdrop` `@export`, so an Inspector swap). `InventorySlot`'s high-count
`Shine` overlay is a plain white `ColorRect` with no texture.

**Level Select (2026-09-25).** The envelope is the artist's flat
`Amplop coklat.png`, cut into body, flap, flap back and seal by
`tools/split_amplop.py`; the envelope's inside (under the flap) and the flap's
back are painted in by that script, and the seal is lifted off with a 2 px
paint-out. Separate layers from the artist would replace all four at the same
paths (and the script's traced polygons would retire). Still placeholder: the
white `pupil_head.svg`, `week_cell.svg` and `gauge_pill.svg` in
`Assets/Images/LevelSelect/`, tinted from tokens. The envelopes wear no
illustration grade; adding one means the census in `tests/test_illustration_ao.gd` and a rim along the
flap's crease to judge.

**Ambient kit art (2026-09-26).** `AmbientParticles`' `DAUN` preset and
`paper_flutter.gdshader`'s `h_frames` uniform wait on the artist's leaf and
petal sheets: `Assets/Images/Particles/particle_leaf_sheet.png` and
`particle_petal_sheet.png`, 512x128, four 128x128 frames in one row, real
colour, an 8 px empty border inside every frame, tip up, straight (not
premultiplied) alpha, no drop shadow. Optional white-on-transparent redraws
`particle_dust.png` / `particle_sparkle.png` (128x128) would replace
`particle_glow` / `particle_spark` in the DEBU and KILAU presets only. The
Sway shader stays deferred until separated plant/paper/curtain art exists
for it to move.

**Minigame layout icons (2026-09-29).** Hand-written placeholder SVGs in
`Assets/Images/UI/Icons/`, to be replaced by the owner's icon set at the same
paths with no code change: `pause.svg` (`MinigameHeader`'s `pause_icon`;
`timer.svg` is unused since the timer shows its seconds, 2026-09-30),
`swipe_up.svg` (MainBola's hint pill) and the six
how-to step pictures `howto_tap`, `howto_swipe`, `howto_drag`, `howto_read`,
`howto_timer`, `howto_target` (the CARA MAIN card, via
`Resources/Minigames/HowTo/*.tres`). A replacement follows
`Assets/Images/UI/Icons/README.md`'s rules; `tests/test_minigame_layout_kit.gd`
checks only that each file exists.

**Tutorial name-plate glyph (2026-10-01).** `Assets/Images/UI/Icons/school.svg`
is a hand-written placeholder (256x256, light fill and dark outline, per that
folder's README), drop-replaceable by the owner's school icon at the same
path with no code change. `TutorialPanel`'s `NamePlate/Row/Icon` shows it at
40x40 beside the speaker's name; `test_ui_icons` and `test_tutorial_panel`
pin it.

**MURIDMU RosterCard week planner (2026-09-29, Task 1 groundwork).** Four
hand-written SVGs in `Assets/Images/UI/StudentList/`, drop-replaceable at the
same paths, wired into `RosterCard.tscn` as of Task 3 (`Paper/WeekHeader/Band`,
`Paper/WeekHeader/Icon`, `Paper/PortraitFrame/Clip`, `Paper/CatatanGuru/Pencil`; the band is
squashed to 900x64 there, so a replacement should keep its torn edges
legible at about half height): `torn_band.svg` (900x120, the WeekHeader band, drawn
white for `self_modulate` `surface_sunken` tinting, same recipe as
`washi_tape.svg`), `paperclip.svg` and `pencil.svg` (decorative props at the
photo and catatan gutter, light-fill/dark-outline like the `UI/Icons/` set
but not scanned by `tests/test_ui_icons.gd`, whose `NAMES` list is fixed to
that folder), and `icon_calendar.svg` (256x256, the week header's calendar
glyph, drawn to `UI/Icons/README.md`'s rules). All four are still pinned by
`tests/test_student_list.gd::test_part_three_art_exists_and_loads`.
`icon_add.svg` and `sticky_empty_frame.svg` (from the same groundwork) are
wired as of Task 2: `StickyNote.gd`'s `scheduled` export shows them on
`Icon`/`EmptyFrame` for an unplanned day. `sticky_empty_frame.svg` is
**not** 9-sliced -- its dashed border is fixed path geometry sized to
StickyNote's actual 172x200 instance rect (`RosterCard.tscn`'s offsets), so
`EmptyFrame` is a plain `TextureRect` (`STRETCH_KEEP_ASPECT_CENTERED`) that
renders it near enough 1:1; a 9-slice would stretch or tile the dashes.

## Asset notes

**`paper.png` cannot be a full-bleed card surface.** It is 1080x1920 but
opaque only across rows 262..1578 and columns 47..1033, its bottom-right
corner is cut away to a transparent wedge, and its body is flat pure white
(about 98% of its opaque pixels are exactly 255,255,255, measured 2026-09-14)
-- there is no paper texture in it to preserve. So a card stretching it paints across only the
middle two thirds of its own rect, with a diagonal hole near the bottom, and
any band laid out against the full rect lands on the desk behind. Cropping
does not fix this: the wedge is interior, not margin. StudentList's
RosterCard therefore carries a `Sheet` Panel on the `Card` variation instead
-- an opaque themed surface that fills the node and brings its own stylebox
shadow. Prefer that for any new card; reach for `paper.png` only where the
cut corner is the point. Measure the alpha before laying out on any
soft-edged texture.

**MURIDMU RosterCard leftovers (2026-09-29).** `paperclip.svg` and
`pencil.svg` have no README rules. `RosterAvatar`'s overshoot is hand-rolled,
and the one-card `NudgeLoop` gate is backed only by a source scan. Stack
clearances are tight (8.5 / 8.5 / 10 px at 1080x1920). Flick velocity is
untested (needs an injectable clock). GhostCard is nearly invisible at the
mandated peek pose and `SunkenPanel` has no border. `_init_carousel_state`'s
`stagger_in` pops card roots the deck also owns (pre-existing).

**Stray layer in the day-transition sky (2026-09-10).**
`Assets/Images/SchoolDay/transition_background.png` has a bluish night street
scene pasted into its bottom-left corner (texture space roughly x 0..375,
y 1833..2047) that should be erased at source. It sits outside the texture's
inscribed circle — `BookClockWidget.gd`'s `_fit_layers()` makes the visible
radius exactly `1024 / sky_cover_margin` regardless of pivot or screen size,
and the artifact sits at radius ~1041, so any `sky_cover_margin` at or above
1.0 keeps it off screen. Do not "fix" it by lowering that margin.
(Re-measured 2026-09-14: about x 0..372, y 1838..2047; `sky_cover_margin` is
1.02.)

## Audio and copy

**Audio placeholders.** Mostly resolved by the 2026-09-21 Drive sound pack,
which gave real streams to `sparkle`, `star_earn_1/2/3`, `result_fanfare`,
`coin` and `event_announce`. Still aliasing existing streams:
`specialty_match`, `tally`, `score_tick`, `combo_up`, and the BGM ids
`exam_notice` and `run_result`. `specialty_match`'s alias is set only in
`AudioDirector.tscn`; the script default is null.

**Reward-feedback shopping list (2026-09-23).** The `RewardFeedback`
orchestrator reuses existing streams via pitch, layering (`play_chord`) and the
tier system, but three genuinely new sounds would lift the warmth. Drop each at
its slot path (swappable, no code change); until then the slot aliases an
existing stream:
- a warm kids "yay"/cheer — the Celebration `play_chord` partner
- a soft chord "ta-da" — the Celebration base
- a dry chalk/paper tick — the Tick tier's character

**`badge_reveal_stream()` is defined but never called (found 2026-09-23).**
`AudioDirector.badge_reveal_stream(band)` maps the five grade bands to their
`sfx_badge_reveal_*` slots, but no screen ever plays it — the EndCutscene badge
reveal has only its BGM and (since 2026-09-23) `RewardFeedback`'s physical
channels (haptic/shake/confetti), not the band cue. Wiring it needs an
AudioDirector path that plays a stream by value (the badge ids are not in
`_resolve_sfx`), so it was left out of the reward-feedback pass.

**`classroomAmbient3.ogg` is corrupt at source (2026-09-21).** The Drive pack's
third classroom bed is a 4 KB stub whose Vorbis identification header declares
**zero channels**; the file on Drive is the same 4022 bytes, so it did not
break in transit. Godot loads it without failing, but logs
`Error parsing header packet 0: -133` (`OV_EBADHEADER`), and `project-check`
fails the build on any `ERROR:` line. The file and its `amb_classroom_3` slot
are out of the tree until the collaborator re-exports it. `classroom_1` and
`classroom_2` are fine and cover the need. Worth checking the source export
settings rather than just re-uploading — a zero-channel header suggests the
encode itself failed.

**Unused pack cues (2026-09-21).** The pack shipped 49 files; these have
`AudioDirector` slots but no call site yet, because the screens that would
fire them were not otherwise being touched: `times_up`, `timer_tick`,
`back_tap`, `item_applied`, `apply`, `tutorial_popup`,
`achievement_prize`, `achievement_success`, the `sfx_achievement` family,
the `badge_reveal_*` tier (and its `badge_reveal_stream()` accessor), and the
ambience beds `classroom_2/3`, `schoolyard_1/2`, `writing` and `thunderstorm`
— only `classroom_1` is played, by SchoolDay. Wiring each is a one-line
`play_sfx`/`play_ambience` at the right moment; finding that moment is the
work.

**Copy placeholders.** Every `desc` string in `ItemDatabase.DEFAULT_ITEMS`
(shown verbatim in `ItemDetailSheet`) is placeholder copy, marked by one
blanket `[PLACEHOLDER]` comment above the table rather than one by one. Every `line` in
`EventDialogueCatalog.ENTRIES` (2026-09-14) is a draft, unmarked because it
shows in-game.

## Theme override debt (2026-09-21)

The project's hard rule is **never add a `theme_override_*`** — use a
`ThemeFactory` type variation instead. Audited on 2026-09-21. Two separate
findings, and the second is the one that matters:

**`.tscn` properties: clean where it counts.** 66 non-layout overrides
(`font_sizes`, `styles`, `colors`) existed in scene files, and **every one is
inside `Scenes/Minigames/**`**, in the minigames' inner play art, which
had no polish pass (CLAUDE.md). The 2026-09-29 minigame layout cleared
Menjodohkan, MainBola and PauseMenu and halved BuatBatik, and the
2026-09-30 minigame hierarchy pass cleared `QuestionCard`, `AnswerCard`,
`KalkulatorKey` and BuatBatik's four tool boxes: 28 remain, in `AnswerRow` 7,
`QuestionRow` 9, `BuatBatik` 2 (the tooltip's two font sizes) and the debug
launcher `MinigameMenu` 10.
Outside the minigames there are zero. Every remaining
`theme_override_constants` outside the minigames is `separation`, `margin_*`,
`v_separation` or `h_separation` — the documented layout-only exception — plus
two `line_spacing`.

**Runtime calls: 57 real violations, in `.gd` not `.tscn`.** A grep for the
scene-file property name misses these entirely, which is why they had not been
counted before. `add_theme_font_override` / `add_theme_font_size_override` /
`add_theme_color_override` / `add_theme_stylebox_override`, outside the
minigames, the debug overlay and `ThemeFactory` itself (which is allowed to):

| File | Calls |
|---|---|
| `Scripts/Inventory/ItemDetailSheet.gd` | 10 |
| `Scripts/SchoolSimulation/DailyDecayOverview.gd` | 9 |
| `Scripts/Pengaturan.gd` | 7 |
| `Scripts/Inventory/InventorySlot.gd` | 5 |
| `Scripts/Inventory/ApplyStudentRow.gd` | 5 |
| `Scripts/AturJadwal/AturJadwal.gd` | 5 |
| `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` | 3 |
| `Scripts/Inventory/ApplyItemScreen.gd` | 3 |
| `Scripts/AnimUtils.gd` | 3 |
| `Scripts/SchoolSimulation/StudentStatRow.gd` | 2 |
| `Scripts/Inventory/Inventory.gd` | 2 |
| `Scripts/SchoolSimulation/StudentSummaryCard.gd` | 1 |
| `Scripts/SchoolSimulation/SchoolDay.gd` | 1 |
| `Scripts/SchoolSimulation/ResultCheckup.gd` | 1 |

Inventory is the worst cluster (25 across five files).

**Why none were fixed on 2026-09-21.** The two the tray/audio branch touched
(`SchoolDay.gd:564`, `ResultCheckup.gd:167`) are both
`add_theme_font_override("font", font)` applying an `@export`ed font to a
control. Replacing them with a variation means deleting that `@export` knob —
a design decision about those screens, not a mechanical cleanup, and one with
no cheap way to verify beyond a screenshot. `Pengaturan.gd` is worse: it
builds its whole UI at runtime (also a "no visual is built at runtime"
violation), so its 7 calls cannot move to a variation until the sheet is
authored as a `.tscn`.

Work this as one pass per cluster, starting with Inventory, not as a
by-the-way fix inside an unrelated branch.

## Known bugs and gaps

**No vibration on the phone build (2026-09-30).** `Haptics.buzz()` calls
`Input.vibrate_handheld()`, which does nothing on Android unless the export
preset grants the Vibrate permission. `export_presets.cfg` is gitignored, so
the setting lives only on the machine that builds the APK and nothing in the
repo can pin it. Whoever exports: Project > Export > Android > Permissions >
tick **Vibrate**, then re-export. Not confirmed on a device; if the phone
still stays silent with the permission on, the 8 ms and 20 ms tiers
(`RewardFeedback.HAPTIC_MS`, `PressFeel.PRESS_TICK_MS`) are the next suspect,
since many motors cannot render a pulse that short.

**Unsimulated item boosts die on quit (moved from CLAUDE.md, 2026-09-30).**
Item boosts land on `approved_students`, which is not persisted, so a boost applied and not simulated before quit is lost.
It follows from the session-scoped-run rule; fixing it means persisting the roster, which needs the owner's go-ahead.

**Ambient kit gaps (2026-09-27).** `hdr_2d` is the clean way to bloom only
the lights without also blooming the near-white paper and sky; it is a
project-wide rendering change `test_look_layer` pins off today. Measured
2026-09-28: MainMenu's sky sits at ~0.89 luminance and its sun core at
~0.88, the desk screens' wood at ~0.84 everywhere; sweeping the
Environment glow's threshold 0.6-0.9, intensity 1-4 and strength 1-1.5
either bloomed nothing visible or bloomed the background as much as the
light (+0.04 to +0.11 at the strong end, fog). So MainMenu, LevelSelect,
StudentCard, StudentList and ReportCard ship without bloom. The shops' hub,
the cosmetic shop, Koperasi and the end-game screens carry the Lobby's own bloom since
2026-09-29 (an `AmbientGlow` at `lobby_environment.tres`'s values); the
earlier "+0.0000 at every threshold" readings on them were an artefact: an
Environment glow does not render in an offscreen `SubViewport` at all, so
measure it in the running game. The minigames and EventDialogue took the
same `AmbientGlow` on 2026-09-30, once their art moved into a `World` room
(style guide, "Bloom off the Lobby"). Measured at the same time, the desk lamp
`LightPool` is capped at 0.12 (its measured knee) and still only adds
+0.011 mean brightness; `hdr_2d` would also let it go brighter. Also
outstanding: light wrap on the shared cutout illustration materials; the
kit not yet extended to Inventory or Achievements. Kalkulator has no backdrop of
its own (it draws over SchoolDay's), so it takes no light and no bloom.
Each minigame's `Calm` grade costs a full-screen copy every frame, and its
`Glow` the Environment's own glow pass (the Efek Visual layer keeps the
bloom shader opt-in for an unknown performance floor); nobody has measured
frame time on a low-end phone yet, the timed minigames first.

**Bug-sweep leftovers (2026-09-30).** Found by the 2026-09-30 scan and left
on purpose: (1) "Ulangi Kelas 8/9" keeps the failed attempt's skill gains,
mood and energy (RunResult's retry branch resets week, schedules and shop but
not the roster), so a retry starts part-way to its targets; a design call for
the owner, not a bug fix. (2) `DebugManager._teleport_to_scene`'s
`"Transition" in get_node_or_null("/root")` is always false, so debug
teleports skip the wipe and the inventory flush; every recipe relies on the
instant change today. (3) `Scenes/Minigames/UI/MinigameMenu.tscn` is an
unrouted dev harness that hosts a minigame over its own layer-0 menu, which
now covers the minigame's `World` room; adapt it (hide its backdrop while a
game runs) before routing anything to it.

**Mood and Energy wear two different tints (found 2026-09-27).** The
student card's own Mood/Energy bars use the `Mood`/`Energy` categories
`DesignTokens.gd` gave them on 2026-09-09, but `StatInfo.token_category` still
maps them to `Istirahat`/`Libur`, and the stat-detail popup
(`StatDetailPopup.configure`) and the cards' `_get_bar_color`
(`StudentCard.gd`, `ReportCard.gd`) tint through it — the rest/holiday mapping
DesignTokens' own note calls wrong. `tests/test_stat_info.gd` and
`tests/test_stat_detail_popup.gd` pin today's mapping; change both with it.

**SchoolDay's dev Skip mid-day decays today twice (found 2026-09-25).**
`skip_to_results()` (key O, `DayScreen/SkipButton`) starts at `current_day`,
which `_run_single_day` has already decayed and rolled, so a skip pressed
during a day's event or minigame runs that day's decay and roll again. The
minigame win screen's LOBBY steps past today first
(`SchoolDay._leave_week_after_today`); the key and the button do not.

**`Textures` is red: five Inventory tests look up moved nodes (2026-09-16).**
`feat(inventory): mobile redesign` (`431cc5d`) restructured
`Scenes/Inventory/Inventory.tscn` without updating two suites, so a full
`test_run` on a clean `Textures` fails five tests and blocks every PR's merge
gate. `tests/test_inventory.gd:94,107` want
`MainColumn/Header/Row/BackButton`, which is now
`MainColumn/Header/HeaderCol/Row/BackButton` — a path fix.
`tests/test_light_ground_text.gd:201` wants `MainColumn/FilterRow/Scroll/Chips`,
which is now `MainColumn/FilterRow/SegBar/Tabs`, and its children are
`TabSemua`/`TabBuku`/`TabOlahraga`/`TabMakanan` carrying a child `Ico`
`TextureRect` rather than a Button `icon`, so that test needs rewriting, not
repointing — it measures the icon's contrast and must now read the child node.
`:244` and `:373-390` follow the item sheet's own moved nodes. Belongs to
whoever owns the redesign.

**Koperasi leftovers after the 2026-09-17 counter revamp.** `Illustration4.jpg`
stays: ShopHub and CosmeticShop blur it. The
`ShopShelfButton` ThemeFactory variation is unused since the "KEBUTUHAN
SEKOLAH" sign went, but
`tests/test_lobby_style_buttons.gd:test_the_shelf_button_keeps_its_body_font_label`
still pins it. Delete the variation and that test together, then rebake.

**Koperasi top-band promo gaps (2026-09-28 koperasi-top-band-promo, found on
review).** The bottom-right shelf slot's price tag sits partly behind Pak
Herman -- pre-existing, but a promo landing on that slot now also hides its
struck list price and badge behind him; wants a layout fix (move the slot,
or Pak Herman, or the tag's anchor). Once the week's promo item sells out,
PromoBoard keeps advertising it -- there is no "HABIS" (sold out) state for
the board to fall back to. On a 20:9 phone the top band (Signboard,
PromoBoard) rides the Stage down with it, per `test_koperasi_on_a_tall_phone`,
leaving plain wall above the band rather than the band reaching for the top
edge. The KAS KELAS balance now lives only in BasketTray's footer pill,
which slides off-screen with the rest of the tray when the player collapses
it -- the old ledge coin it replaced was always visible, collapsed or not.
The handoff spec accepted this; revisit if playtesting disagrees.

**Saving RosterCard.tscn in the editor moves its sticky notes (2026-09-14).**
`Scripts/StudentList/StickyNote.gd` is `@tool`, and its `_ready()` calls
`_apply_pin()`, which writes `offset_top = pin_slot * PIN_STEP`. In the editor
every note drops to its pin height, and a `scene_save` bakes that into the
scene: all five notes went from `offset_top 0 / offset_bottom 200` to
`20 / 220`. The lobby-style-buttons pass changed the badges by text instead.
The fix is to gate `_apply_pin()` on `not Engine.is_editor_hint()`, then check
StudentList still pins each note at runtime.

**Emoji as iconography on the stat popup.** `Scripts/UI/StatDetailPopup.gd`
falls back to `info["glyph"]` from `StatInfo`, and those glyphs are emoji, which
the ban in `## Conventions` forbids. The trait popup was fixed the same way on
2026-09-09 — real textures plus a display-font heading; this wants the same.
Every current caller passes artwork, so the fallback never shows today; it is
one of the two reviewed exceptions in `tests/test_ui_text_glyphs.gd`'s
`ALLOWED`, and fixing it means removing that entry too.

**Boohong draws some punctuation as quote marks, and lacks more (found
2026-09-15).** `Assets/Fonts/Boohong.otf`'s cmap sends `‹`, `›` and `‚` to its
apostrophe glyph and `«`/`»` to its double quote. The font claims them, so
system fallback never runs: Inventory's "‹ Kembali" shipped as "' KEMBALI" on
desktop and Android alike, until the chevron became a texture — now the shared
`UI/Nav/return_button.png` on all twelve back controls. It has no
`•`, `…`, `—`, `←` or `→` at all; those fall back to whatever system font the
device picks. Buttons, titles and headings wear Boohong, so keep such
characters out of their text, and draw an arrow or chevron as a real texture.

**Stock art still to replace (2026-09-22).** `pngwing.com (1).png` went
with the back-button pass, which was a licensing tidy-up as well as a
visual one: the filename was verbatim from a free-PNG aggregator, the
project records no licence for it, and most of that catalogue is
non-commercial. The clean-code renames deleted the unused copies and
renamed the last live one to `Assets/Images/UI/stamp_original.png` (the
approval stamp at `StudentCard.tscn:14`); it is still that unlicensed
stock image. Replace it with authored art before any release.

**Minigame question art is background-sized (2026-09-21).** `monas.png` is
1080x1920 and `borobudur.png` 1920x1920 -- portrait and square assets standing
in as question illustrations. `QuestionCard`'s 620px slot centres them with
`stretch_mode` KEEP_ASPECT_CENTERED so neither distorts (monas renders
349x620), but a cropped landscape export at the same paths would fill the slot
properly rather than leaving air either side. Drop-replaceable at the same
paths.

**Faint placeholder icons on the minigame result card and HUD (2026-09-11).**
Left as they are by decision, for the art pass; the labels beside them were
fixed. Against the 3:1 non-text floor: on `ResultStatPanel`, white
`icon_skor.svg` 1.30:1, `icon_mood` 1.28, `icon_energy` 1.69, and the stat
row's icon 1.29 (`icon_poin`, the fallback every minigame gets today), 2.43
(`icon_akademis`) or 1.62 (`icon_seni`); white `icon_kombo.svg` on the HUD's
white combo chip, 1.02. The same files sit on other light grounds (stat popup,
item sheet, RunResult rows, week-recap pills), so recolouring the art would
help everywhere but the HUD's dark pill; a multiply tint muddies coloured art.
(Checked 2026-09-14: only `icon_skor` and `icon_kombo` are drawn white;
`icon_mood`, `icon_energy` and `icon_poin` are yellow, orange and gold.)

**`DailyDecayOverview`'s photo swap can never run (found 2026-09-15, by
reading the source; not run).** `_apply_visual_exports()` looks up a
`Background` Panel, but the scene's scrim is `BackgroundDim` -- the same
mismatch `EventStudentSelectDialog` had until 2026-09-15. Nothing sets its
`background_texture` today, so nothing looks wrong, but setting that export
would silently do nothing. Fix it the way the picker was fixed: an authored
`Background` TextureRect that the script toggles against the Scrim. That also
retires the `TextureRect.new()` among the file's six `viewport_editability`
BASELINE counts.

**Loose ends from the event-cards pass (2026-09-12).**
`EventStudentCard.set_preview()` never passes `preview_stat()`'s
`capped` argument, so the event picker's gain preview has no MAKS cap where
`ApplyStudentRow.set_preview()`'s does. And `test_bar_contrast.gd`,
`test_light_ground_text.gd` and `test_event_warning.gd` each carry their own
copy of the WCAG contrast/luminance helper; wants one shared test utility.
(Checked 2026-09-14: a fourth copy sits in `test_run_result.gd`.)

**`BarFill/README.md` overstates its tests (found 2026-09-14).** The README
says both of its rules are checked, but `tests/test_bar_contrast.gd` checks
only the luminance floor; nothing tests the tile-period rule.
`tests/test_ghost_track.gd` does cover `track_ghost.png`. Add the period test,
or correct the README.

**SchoolDay is not in the tall-screen suite, and has no safe area (2026-09-24).**
The liveliness spec's "Mobile layout" section asks for the header (calendar
and day banner) to sit inside `SafeAreaMargin -> UI`, and for SchoolDay and
EventWarning to be pinned at 1080x2400 by `tests/test_tall_screen_layout.gd`.
Neither is done: the header is still top-anchored at a fixed offset inside
BookClockWidget. The layout is anchored (the day stack spans the screen with
spacers, and the notice is full-rect and centred), but no test proves it on
a 20:9 phone.

**Opening BookClockWidget.tscn hangs the editor (moved from CLAUDE.md, 2026-09-15).**
`scene_open` on `Scenes/SchoolSimulation/BookClockWidget.tscn` hangs the
editor — the call times out, the MCP transport write-pauses, the plugin
disconnects, and the editor needs a restart. Cause unconfirmed; verify that
widget via `project_run` instead, which exercises it fine.

## Deferred and pending

- **Texture memory follow-ons (2026-09-30).** Rule and numbers:
  `tests/test_texture_memory.gd`.
  - **Not checked on a phone.** The compressed art was judged on desktop
    (BPTC); a phone gets ASTC 4x4 from the same import. Look at the desk
    plates and the backdrops on a device before a release.
  - **The character art is most of what is left**: the 24 student portraits,
    splashes and outfits (below, "The student art is lossless for now") and
    the twelve 1280x1280 face bases, drawn at about 400 px. All six bases
    load in the Lobby whatever the roster is. Halving the base art, or
    loading only the roster's faces, is the next saving.
  - **The download size was not measured.** A compressed texture is stored
    at its video-memory size (about 1 byte per pixel), where a lossless one
    is stored packed, so the APK probably grows. No export preset exists on
    the dev PC to build one; compare a build before and after.
  - **A phone build cannot unpack ASTC** (the decoder ships in the editor
    only), so `Image.decompress()` fails there. `TraySlot` carries its crops
    baked for that reason; any new runtime pixel read of large art needs the
    same, or the art in `ALLOWED`.
  - **About 100 MB in the Lobby is not art**: probably render targets, MSAA,
    fonts and the theme. Not investigated.

- **Minigame hierarchy follow-ons (2026-09-30).** Spec:
  `docs/superpowers/specs/2026-09-30-minigame-hierarchy-design.md`.
  - **Stray key outline in the calculator art (artist).**
    `Assets/Images/UI/Kalkulator/kalkulator_base.png` paints a lighter
    rounded-rect outline at its top left (about 0.051-0.275 x 0.293-0.468 of
    the art). Key 1 now covers most of it; a sliver at its left edge shows.
    Remove it in the art, then `Kalkulator.KEYPAD_LEFT` can relax.
  - **The mentor has not seen the plaque or the x1.618 ladder** (spec §9):
    shipped on the owner's call.
  - **The how-to card, JEDA and KELUAR? overlays** keep the house 36 px
    lines; they were out of this pass's scope.

- **Minigame mobile layout follow-ons (2026-09-29).** Spec:
  `docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md`.
  - **Three decisions still want the mentor's eye (spec §9).** PR #155 was
    merged on 2026-09-30 on the owner's call, with its `hold` label waived: the overlays use `NotebookFrame`, not Part 1's Bingkai
    Kayu; the answer buttons stay cream, not brand-filled with a gold edge;
    BuatBatik's wood title plank is dropped (the title lives on the CARA MAIN
    card).
  - **Part 2 coordination:** `ScorePill` → ×badge inside `MinigameScoreHUD`;
    Phase 8 re-scoped to key feel + LCD styling. This layout owns the
    Password, Variabel and Kalkulator layouts, and the strip has no slot for
    a `ComboMeter`. Tell Part 2's author before Phase 8 starts.
  - **Hint pill copy.** LombaMenari's pill keeps "UPS! Sisa N" after the
    player recovers (restore "Geser searah panah" on the next good hit; the
    two-line text also grows the pill). BuatBatik's hint settles after every
    correct drop, not only the first (guard it to the first), and can go
    stale after the final drop. BuatBatik's floating label says "Urutan
    Salah!" while its hint says "Urutan salah!".
  - **Built differently from the spec (§4), to look at.** LombaMenari's
    floating grade word still reads "UPS! Sisa N" (`_show_hit_feedback`) as
    well as the pill, where the spec moved it. Menjodohkan's SOAL wheel keeps
    its paging arrows in the top half, out of thumb reach, and has no pair
    chips; the spec called it read-only with chips under it.
  - **Header and kit loose ends.** `BaseMinigame.header()` is looked up
    every `_process` frame and twice in each of win/lose/abandon (cache
    it). `TimerRing` redraws on unchanged values; overlapping `fill_bar`
    tweens are not killed. The
    tray and the pill duplicate `set_hint`/`settle`; the pill's label has no
    width cap, and an empty pill still shows. The result popup's game name
    comes from a `String`/`StringName` ternary in `BaseMinigame`
    (`how_to.title if how_to != null else name`).
  - **Dead or stale code left by the move.** `progress_label` in
    PilihanGanda (kept for `test_minigame_art`'s scan), Password and
    Variabel; Menjodohkan's unread `submit_btn_active_style`,
    `correct_color`, `wrong_color`, and its `button_lock_texture` (null by
    default), which no longer tints red while a match is being cancelled;
    PilihanGanda's stale `soal_card` comment about the Soal N/M badge;
    the wrong-answer wiggle now shakes `soal_card` and may leave a panel
    override behind.
  - **Unverified live:** JEDA/KELUAR? spring-in at 1080x2400, BuatBatik's
    drag ghost and tooltip over the tray, Menjodohkan's no-picture question
    at 2400, and Variabel's run (Password was run).
  - **Tests that only scan source:** PauseMenu's buttons, the countdown's
    order in `activate_minigame` (the test pins its indent), the BuatBatik
    hint order, and LombaMenari's `show_hint(miss_text(` call. Nothing pins
    the pill's text or that Badminton and LombaMenari hide the timer, only
    PilihanGanda's tray is checked against the thumb line, and nothing
    stands a tray up bottom-anchored.

**UI depth pass, leftovers (2026-09-28, Phase 3 2026-09-29).** All three
phases have shipped (`docs/superpowers/CHANGELOG.md`); these are what they
left behind. Spec: `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md`.

- **Art no scene or script uses any more**, not yet deleted. Grepped by
  path and by uid against `Scenes/`, `Scripts/` and `tests/` on 2026-09-29:
  - Phase 2 (callers moved onto `NotebookFrame`):
    `Assets/Images/UI/notice.png`, `Assets/Images/UI/penjadwalan_card_bg.png`.
  - Phase 3 (callers moved onto `UI/Icons/`): the five Lobby tile icons
    `UI/Nav/icon_cta_student.png`, `icon_cta_jadwal.png`,
    `icon_nav_koperasi.png`, `icon_nav_inventory.png`, `icon_nav_rapor.png`
    (named only in `test_lobby_tile_icons`'s `RETIRED` list, which asserts
    the Lobby no longer points at them); `UI/icon_exit.svg`;
    `UI/Nav/icon_chevron_left.png` / `icon_chevron_right.png`; and
    `UI/Placeholders/icon_wirausaha.svg`.
  - Phase 3, game-unreferenced only: `AturJadwal/icon_istirahat_placeholder.png`
    and `icon_wirausaha_placeholder.png`. No scene or game script uses them,
    but their generator `Scripts/Design/GenerateStickyNoteIcons.gd` writes
    them and `tests/test_sticky_note_assets.gd` checks they exist, so
    deleting them means trimming both (the generator's third output,
    `icon_libur_nasional_placeholder.png`, is still the holiday icon).
  - Keep `UI/Nav/return_button.png` (every Back) and
    `UI/Placeholders/arrow.png` (`TutorialArrow.gd`, `test_texture_mipmaps`).
- **`setting.png` has no `Icons/` counterpart yet.** MainMenu's
  `SettingButton` and the Lobby rail's gear still wear
  `Assets/Images/UI/setting.png`; the rail's four icons were left as finished
  art on purpose, so a gear in the chunky set is the owner's call.
- **Three screens still build their tutorial panel at runtime**, not from
  `Scenes/UI/TutorialPanel.tscn`, so Phase 2 did not move them into the
  frame: `Scripts/AturJadwal/AturJadwal.gd`, `Scripts/Lobby/Lobby.gd` and
  `Scripts/StudentList/StudentList.gd` each build their own
  `_tutorial_panel: PanelContainer` in code (a follow-up; Phase 3 did not
  take it).
- **Review minors, deferred:**
  - Nothing pins `NotebookFrame`'s Chrome/Close control to a 96px touch
    target (a geometry test would catch a future regression). (Phase 2)
  - The Peringatan label/buttons test is now a sibling-order check only,
    weaker than the old overlap check it replaced. (Phase 2)
  - The "becomes" arrow `→` (DailyDecayOverview's `80 → 75`,
    ApplyItemScreen's `×3 → ×2`) is not in any bundled Open Sans file, so
    it draws from the system fallback font. A body font that carries it, or
    a small arrow texture, would keep it in one typeface. (Phase 3)
  - `RosterCard.SPECIALTY_ICONS` and `StudentList.CATEGORY_ICONS` are one
    table written twice; `test_student_list` keeps them equal. Sharing one
    const would retire that test's job. (Phase 3)
  - `test_ui_text_glyphs`' comment stripper ignores escaped and single
    quotes, so a glyph after a `#` inside such a string would be missed.
    (Phase 3)
- **Dapatkan Uang is a dev-mode stub** (2026-09-28, Loby Final Polish
  Phase 2). Every option pays at once and the toast wears DEV MODE; no ad
  SDK is wired. Debug builds only: a release build keeps the Lobby's `+`
  disabled (`DapatkanUang.is_available()`). Before one is: the child-directed ad-policy gate (COPPA,
  GDPR-K, ad-content ratings; the audience likely includes minors). The
  SDK's reward callback then calls `DapatkanUang._pay()`, and
  `is_dev_mode` goes false. The six amounts (+150 / +450 / +900 for 4 ads /
  +2000 for 8) await the Balance owner's sign-off:
  `docs/superpowers/specs/2026-09-27-earn-money-balance-proposal.md`.
- **Scrapbook HUD review leftovers** (2026-09-28, Phase 1 reviews in
  `.superpowers/sdd/2026-09-27-loby-final-polish/`). On a phone that
  reports a bottom inset, the hidden HUD's 48 px chevron peek sits inside
  the system gesture strip: a design call, since lifting it would show
  JADWAL again. `lobby_hud` measures the peek against the editor window,
  not a 1080x1920 `SubViewport`. The landing squash (`AnimUtils.squash_bounce`,
  1.18/0.85) is far stronger than the spec's ~1.04/0.97; tune it with
  `motion-lab`. The entrance and the star sparkle mostly play under the
  `Transition` wipe.

- **`AnimUtils._active_tweens` never forgets freed nodes** (2026-09-28).
  Each helper call registers its tween keyed by the node and never erases
  the key, so the daily-login reveal leaves 20-30 dead keys per claim (one
  per fanned coin and star, which are freed when the reveal ends). Small,
  but it grows for the whole session; erase the key when the tween
  finishes, in `Scripts/AnimUtils.gd`, which every screen shares.

- **Clean-code ratchet debt** (`ci/clean_code_baseline.gd`, 2026-09-26): 1588
  untyped declarations, 2120 bare numbers, 46 functions over 50 code lines,
  5 large scripts, 22 duplicate groups. Phase 2 (PR4 one `TutorialGuide`,
  PR5 the other duplicates) and Phase 3 (splitting long functions) of
  `docs/superpowers/specs/2026-09-26-clean-code-design.md` are planned; the
  rest shrinks as code is touched (`clean-code.md` rule 10). Decomposing
  `SchoolDay.gd` into components is its own project.
- **The project check runs Godot with no timeout** (2026-09-27).
  `.github/workflows/project-check.yml` starts the check with a bare
  `"$GODOT" --headless --path . res://ci/project_check.tscn > check.log 2>&1`
  and prints `check.log` only after Godot exits. If `ci/project_check.gd`
  itself stops compiling, the scene runs with no script until the job's
  15-minute timeout, and the log is never shown. Fix it in a separate PR,
  since a workflow change cannot auto-merge (`CLAUDE.md`, "Pull requests"):
  `timeout 600 "$GODOT" --headless --path . res://ci/project_check.tscn > check.log 2>&1`.
- **Premium-look leftovers (2026-09-22, PRs 2-6).** The programme in
  `.superpowers/gamecode/premium-look/` shipped items 1-10 and 12; item 11
  (the Lobby's black bands at 20:9) was cut by the brief and landed on
  2026-09-30 as desk-wood planks. What was
  deliberately left:
  - **SchoolDay has no parallax.** Its two bands (SkyBackground,
    SchoolForeground) live inside BookClockWidget, whose root already runs
    BookClockWidget.gd, so the driver cannot be added beside them the way it
    was for Classroom and Stage -- it would have to fold into that script.
    Its sky already rotates, so it is the least flat of the three dioramas.
  - **Koperasi gets no entrance animation**, and this one is a trap rather
    than a gap. `ShelfItem.set_dimmed` writes `_button.modulate.a` to signal
    affordability, and `Juice.pop_in` tweens that same property to 1.0, so an
    entrance would un-dim every item the player cannot afford. Herman's
    `scale` likewise belongs to HermanAP. `tests/test_motion_adoption.gd`
    asserts the shelf stays untouched.
  - **The face rigs' eye layers are ungraded.** The illustration grade is on
    each face's `Base`; `Pupil` already carries `eye_mask.gdshader` and a
    CanvasItem has one material slot. It is a few hundred pixels of iris and
    reads fine, but a CanvasGroup pass would close it.
  - **The student art is lossless for now (2026-09-29).** The 24 portraits,
    default splashes and day outfits were the only VRAM-compressed art; they
    showed block artifacts, so they went to high-quality VRAM (#142) and then
    lossless. That is about 4x their texture memory (a 1080x1920 splash with
    mipmaps is ~11 MB instead of ~2.7 MB). If phone memory becomes a
    problem, move them back to `compress/mode=2` with
    `compress/high_quality=true`, flip `test_student_art_is_lossless` and
    the outfit import test in `tests/test_student_skins.gd`, and drop their
    `STUDENT_ART` rows from `tests/test_texture_memory.gd`. Measured
    2026-09-30 with them compressed: the Lobby 210 MB instead of 238, Skin
    Select 242 instead of 303; on desktop (BPTC) a splash compared at
    46 dB PSNR against its source.
  - **Android export: why the APK lacks the bus layout is unknown (2026-09-30).**
    A phone build booted without the BGM and SFX buses. `AudioDirector.ensure_bus()`
    now covers it, but the preset that builds the APK lives on another machine
    (`export_presets.cfg` is gitignored and absent here): check its resource
    filter carries `Assets/Audio/default_bus_layout.tres`.
  - **ETC2 is on but nothing is built for Android yet.** There is no
    `export_presets.cfg`. `import_etc2_astc` is enabled so the committed
    `.import` files stay deterministic across machines; it costs import time
    on a desktop that never samples those variants.

- **Mipmap follow-ups (2026-09-22, premium-look PR 1).** 29 measured
  downscale offenders now generate mipmaps and the canvas filter samples them
  (`tests/test_texture_mipmaps.gd` holds the list and the reasoning). Three
  things were deliberately left:
  - The Lobby face rigs' **eye layers** (`*_sclera`, `*_pupil`, `*_eyelashes`,
    `*_eyelid`, `*_eyebrows`, 30 files) minify at the same 3.2-3.5x as the
    `*_base.png` that did get a chain, and they animate. Left out to keep the
    change reviewable; add them the same way if blinking shimmers.
  - `UI/lobby_no_tables.png` is 768x1376 drawn full-screen — **upscaled 1.41x**,
    the largest surface on the highest-traffic screen. No code fix exists;
    this one needs a bigger source from the artist. Same for
    `Shop/UI/bg_inventory_blur.png` (1.41x up) and `UI/BG.jpg` (1.47x up,
    CutScene).
  - **Source resizes** would beat mipmaps for the static UI offenders and cut
    VRAM, but five textures are shared across 2-12 scenes at different drawn
    sizes (`return_button.png` in 12, `uang.png` in 4, `star.png` in 6), so
    any resize has to satisfy the largest call site. Not attempted.

  Note `detect_3d/compress_to=1` is set on all 402 texture imports: any
  texture that ever touches a 3D material gets silently re-imported as VRAM
  with mipmaps. Nothing in the game is 3D today.

- **Skins (2026-09-18).** No way to earn or buy a skin yet: every shipped
  skin starts unlocked (`StudentSkins.UNLOCKED_BY_DEFAULT`) and only the debug
  toggle locks them; the Cosmetic Shop stub is the likely home. Worn skins
  are session-scoped like the roster (not saved). The artist's
  `<Name>Skin1(itemonly).png` clothes-only images (kosmetik.zip) are not
  imported -- probably future shop icons. The flat Skin1 portraits are baked,
  not drawn: re-run `Scripts/Skins/BakeSkinPortraits.gd` (headless, see its
  header) when a skin's face base changes; Marcel's glasses bake with a
  flat grey lens instead of `glasses_lens.gdshader`'s tint. In a windowed
  desktop run `SafeAreaMargin` clamps the monitor's safe area to a large
  bottom inset, so the skin card (like the Lobby's bottom bar) sits high;
  on a phone it is centred.

- **Koperasi polish leftovers (2026-09-18).** `ShopMessageWarning` and
  `ShopMessageDanger` (`ThemeFactory.gd`) are unused by `Koperasi.gd` after
  the final polish pass -- nothing in the shop currently shows a warning or
  danger message panel. A
  purchase flight already airborne when the player collapses the tray still
  lands at the tray's EXPANDED position (cosmetic only -- the unit still
  reaches the cart correctly). Herman's `talk` head-bob animation has not
  been tuned against the final counter art.

- **`Achievements.RESET_ON_LAUNCH` is on** (debug, 2026-09-17): every launch
  wipes achievement progress and claimed prizes. Turn it off before release.

- **Achievements polish (2026-09-18).** The debug Prestasi tab's "Buka
  semua" loops `Achievements.debug_unlock(id)` over all 26 catalog entries,
  firing 26 separate `state_changed` signals (one per unlock) instead of a
  single batched emit. Fine today -- every listener's redraw is cheap -- but
  batch it (e.g. a `_suppress_signal` flag plus one `state_changed.emit()`
  after the loop) if it ever becomes a perf problem.

- **Achievements notice badge (2026-09-22).** The claimable badge is the
  user's `notice_icon.png` -- a red circled "!", which is the error idiom
  everywhere else in this game. It ships as drawn; if it reads as an alarm
  rather than a reward, recolour it to `state_warning` amber at the same
  path, no code change needed.

- **Achievements header (2026-09-22).** The status pill truncates
  ("25 HADIAH BELUM DIAMBIL" is clipped by the filter button at 1080 wide),
  and `%FilterButton` (96px) and the pill (64px) are both under the ~130px
  touch floor. Found in the 2026-09-22 design audit and deliberately left
  out of that pass's scope.

- **SkinSelect is an overlay, not a scene (2026-09-22).** The brief asked
  for a scene; it stayed a full-screen Lobby overlay because only an overlay
  can blur the *live* lobby through `shop_hub_blur_material.tres` -- a
  `Transition.change_scene` would need a baked backdrop like
  `bg_achievements_blur.jpg` and would stop showing the room the student is
  standing in. Revisit only if the Lobby stops being the sole entry point.

- **SkinSelect's skin names are derived (2026-09-22).**
  `SkinSelect.skin_label` turns `default` into "Seragam Sekolah" and `skin1`
  into "Seragam 1". Real names belong in `StudentSkins.SKINS` once there is
  more than one extra skin per character.

- **SkinSelect's flick detection doesn't decay stale motion (2026-09-23).**
  `_release_velocity` keeps whatever the last motion sample was, so a fast
  drag that stops and is held before release still reads as a flick. Zero it
  when more than ~80ms have passed since the last motion sample.

- **SkinSelect's Lock icon stays crisp on a blurred neighbour card
  (2026-09-23).** It's a sibling of Art rather than a child inside the
  blurred/dimmed material, so a locked, unfocused card's lock reads sharp
  against its blurred splash. Reads as a label rather than part of the
  illustration, which is acceptable for now.

- **SkinSelect's stretch features are deferred (2026-09-29,
  skin-select-polish).** The collaborator's handoff spec's "Baru!" badge,
  peek-on-select, turntable idle and locked-skin treatment all stayed out
  of the pass pending the owner's sign-off (plan
  `docs/superpowers/plans/2026-09-29-skin-select-polish.md`, Revision:
  "Stretch features stay out").

- **SkinSelect's back button departs from the handoff (2026-09-29,
  skin-select-polish).** The screen keeps the shared red `TextureButton`
  back arrow every screen uses instead of the handoff's one-off round cream
  button -- a back control that looks different on one screen reads as a
  different action. Recorded as a departure in the pass's plan and PR, not
  a bug to fix.

- **SkinSelect's name dividers and tape sit at a fixed x (2026-09-29,
  skin-select-polish).** `NameDividerLeft`/`NameDividerRight` and the
  tray's washi tape are placed to fit "Seragam Sekolah"-length names. Real
  skin names (`SkinSelect's skin names are derived`, above) do not exist
  yet, but a name much longer than that would overlap the dividers once
  they land. Put `SkinName` and its two dividers in a centred
  `HBoxContainer` when `StudentSkins.SKINS` grows real names.

- **`test_audio_coverage`'s double-fire scanner is a substring match, not a
  word boundary (2026-09-29).** It reads `tile.set_open(i == index)` inside
  `SkinSelect.select_student` as a call to that same file's own `open()`,
  because its check is `body.contains(other_func_name + "(")` and
  `"open("` is a substring of `"set_open("`. `select_student` was added to
  `_DOUBLE_FIRE_ALLOWLIST` rather than fixing the scanner. The real fix is
  a word-boundary check (e.g. the match must not be preceded by an
  identifier character) in `tests/test_audio_coverage.gd`; it is its own
  PR, not part of skin-select-polish.

- **skin_card_focus.gdshader's blur cost is unmeasured on low-end Android
  (2026-09-23).** 48 taps per pixel on a full-size card, and mid-slide both
  the centred and the neighbour card are on the blurred path at once. If it
  drops frames while dragging, precompute the per-tap offsets/weights (they
  depend only on `i`, not on `sigma_texels`) or blur a downsampled copy.

- **The Lobby look's full-screen additive passes are unmeasured on low-end
  Android (2026-09-28).** The Lobby look adds full-screen additive passes
  (SunShafts' atan/pow shader, the grade) to the shops, the exam notices and
  seven minigames, including timed ones (Badminton, LombaMenari); unmeasured
  on a low-end phone.

- **Achievement prizes not built.** Pembimbing Profesional's "Skin Thea"
  shows as *segera hadir* because there is no skin system (CosmeticShop is a
  stub). Masa Depan yang Indah's Level Selection was already unlocked by
  beating the game, and there is no settings button to reset achievement
  progress (only Debug > Forget Session).

**Pending a balance pass.** `RunGrade`'s scoring weights (especially
`MONEY_FULL_MARKS`) are estimates; `LombaMenari.best_combo` is tracked but not
fed into the star rubric; the item skill-boost values in
`ItemDatabase.DEFAULT_ITEMS` (3–8) are untested against
`tests/test_balance_pacing.gd`. `RunGrade.LETTER_BANDS`' five rank
floors (S 90 / A 75 / B 60 / C 45) are estimates set when the scheme collapsed
from ten +/- bands on 2026-09-10, never played against a real run.
`MainBola`'s per-grade tables (8/10/10 shots, 4–6/6–8/6–8 goal targets,
2026-09-14) assume a player lands about 70% of shots; never playtested.

**Pending: the badge rank scene (RunResult) polish.** Designed and planned in
`docs/superpowers/specs/2026-09-26-badge-rank-scene-polish-design.md`
(PR #86, re-checked against Textures on 2026-09-28); nothing built yet. It
supersedes Plan C (`plans/2026-09-04-endgame-c-run-result.md`), which is
marked SUPERSEDED and must not be executed.

**Cosmetic shop is a stub.** `Scenes/Koperasi/CosmeticShop.tscn` is a blurred
backdrop, a "Segera Hadir" line and a back button. The shop hub's second tile
has to lead somewhere; nothing behind it is designed.

**Dead scene.** `Scenes/EndGame/WinScreen.tscn` is orphaned scaffolding — root
unscripted, nothing references it. The real win screen is `WinStage.tscn`,
which EndCutscene shows and RunResult keeps blurred behind its report. Safe to
delete. (Checked 2026-09-14: one commit deleted it and a later one brought it
back; the unmerged cleanup on `feat/asset-refresh-ui-pass`, `32b6f9a`, deletes
it again along with 177 other unused files.)

**The picker's "+N" ignores quirks (2026-09-24).** `ActivityPreview.skill_gain`
and the cost arrows follow Balance and the specialty only. The simulation also
applies Kutu Buku, Penasaran (+1 gain, +10% cost) and Seni Dalam Kesunyian, so
for those students the number on a tile is off by that bonus. This is the
preview's documented "stable estimate" contract, which the old chips shared.
Mirror the quirk terms, or build the numbers from a `StudentData`.

**RewardFeedback bursts start at a Control anchor's top-left (2026-09-24).**
`_play_particles` places a burst only for a `Node2D` anchor. A Control anchor
(AchievementToast, ApplyStudentRow, the Lobby money label, ...) gets it at
(0, 0). AturJadwal's two moments opt in to centring with a `centred` recipe
key. Centring every Control anchor is the general fix, but it moves bursts on
screens nobody has looked at, so check each caller first.

**The old Penjadwalan row's leftovers (2026-09-10, widened 2026-09-24).** The
2026-09-24 picker rebuild replaced `ActivityRow` and every `Preview*`
variation with `ActivityTile` and `Picker*`. That left these read by nothing:
the tokens `preview_row_fill`, `preview_row_border`, `preview_row_separator`,
`preview_row_pressed_fill`, `preview_row_shadow_*` and `preview_pill_shadow_*`
(`preview_pill_fill` still feeds the StatBar light track), plus
`BarFill/track_ghost.png` and `BarFill/icon_ghost_koin.png` (`icon_ghost_sabit.png`
is now Libur's tile watermark). `test_cream_panel_tokens` and `test_ghost_track`
still pin the token values and the assets. Removing the tokens needs a full
editor restart (Resource `@export`s); remove them, the assets and those checks
together, or give them a consumer.

**The green day card art is retired (2026-09-19).**
`Assets/Images/DaySummary/card_bg.png` and `card_bg_uncropped.png` are drawn
by nothing since every `DaySummaryStudentRow` took PR #53's cream
`IdCardPanel` frame; only `test_day_summary`'s asset list still loads
`card_bg.png`. Kept so the green card is a drop-in if it ever returns.
Delete both (and that asset-list line) once that is off the table.

**Deferred: the AturJadwal shelf.** Ships as two `ColorRect`s rather than a
`ShelfEdge` variation. Needs an editor restart plus a manual rebake (a new
`@export` on `DesignTokens` is invisible to a running editor). The exact diff
is the Task 2 section of `docs/superpowers/plans/2026-09-01-atur-jadwal-mockup.md`,
which its STATUS block points to.

**Art: a few eye-rim pixels stay see-through on Doni and Marcel.** Their
bases keep some anti-aliased cut-out rim pixels that no layer placement
covers (Doni 5, Marcel 10). The counts are frozen as a budget in
`tests/test_face_rig_roster.gd`, and only new art removes them.

**Ratchet debt.** `tests/test_viewport_editability.gd`'s `BASELINE` still lists
real unconverted runtime UI construction across roughly 20 files. The list, and
what each would need, is in the authoring guide's "Known gaps" section.
(Checked 2026-09-14: 23 entries, 22 of them nonzero, 131 constructions in all.)

**ExamProgress shows only the middle of cg_ujian (2026-09-14).** The art is
1920x1920, but `Backdrop` is 1296 wide and pans 216 px, so the outer 312 px on
each side never show. Showing it all means a 1920-wide `Backdrop` and
`pan_pixels = -840` (a faster pan over the same 4 s), plus the 1296 in
`tests/test_exam_progress.gd`'s width test.

**Deferred: tall phones, Phases 2 and 3 (2026-09-15).** Phase 1 made the
Lobby, Koperasi, StudentCard and StudentList fill a 1080×2400 screen (spec
`docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`; its
Appendix A maps every screen). Still laid out for exactly 1080×1920:
Phase 2's AturJadwal, CutScene, Rapor and Inventory (Inventory's glyph
fix merged as `fd3bba7`), and
Phase 3's StatCheck, EndCutscene, the
ResultCheckup confetti and MainBola (ExamProgress left this list on
2026-09-20: its backdrop is anchored to all four edges and its status strip
to the real screen bottom). The Lobby's classroom stays a centred
1080×1920 picture, so a tall phone shows black bands above and below it;
filling them wants taller classroom art. Badminton's court `Background` now
covers (`Keep Aspect Covered`), so tall-phone rule 1 holds for the art. **Open
check, unverified on a device:** on a 20:9 phone (1080×2400) cover scales the
1080×1920 court art 1.25× and crops about 135 px per side, so the painted
sidelines land near x≈77 and x≈1002. `Badminton.gd` `_ready()` places the walls,
goals, puck and paddles from `get_viewport_rect()` (side walls at x=8 and
width−8, goals and top/bottom walls at the screen edges), so the physics follow
the viewport, not fixed design pixels, and the puck bounces at the screen edge,
outside the painted lines. Whether that reads as misaligned has not been
looked at: the editor's embedded run is locked to 9:16 and never shows 20:9.

**Ghost-preview bars land only on the item apply screen (2026-09-16).** The
`ApplyItemScreen` student cards (`ApplyStudentRow`) show, while a student is
picked, a two-tone "ghost" bar: the underlying `DaySummaryStudentRow` bar goes
to the boosted target but translucent (`set_preview`'s ghost pass), and a solid
"current" overlay is laid on top so the gap between them reads as the pending
gain. The overlay (`_build_overlays`) is a `duplicate()` of the bar with its
children stripped and its `background` stylebox replaced by a see-through copy
that keeps the same fill margins (`_transparent_bg`, so skill tracks — which
inset their fill — still line up), parented INTO the bar at child index 0 so it
draws over the bar's fill but under the bar's own icon/word/chevron children.
On apply, `play_apply_rise` fills each overlay from current up into the target.
`_clear_overlays` tears them down on deselect. The **event student picker** in
SchoolSimulation (`EventStudentSelectDialog` + `EventStudentCard`, which hosts
the same `DaySummaryStudentRow`) still uses the plain `preview_stat`/
`preview_need` fill and no ghost. To match, port `ApplyStudentRow`'s ghost
helpers (`_build_overlays`, `_transparent_bg`, `_clear_overlays`,
`play_apply_rise`, `_capture_bar_current`, `_visible_bars`) onto
`EventStudentCard`, or lift them into a shared mixin both cards call. Out of
scope for the inventory pass; pick up in its own session. (Note: a per-instance
`fill_*.png` pattern on these bars was tried and reverted — the tiles render as
a broken white fill on the `DaySummary` bar variations; a real pattern needs
the bars restyled, not a stylebox override.)
