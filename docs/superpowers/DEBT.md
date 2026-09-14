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
with no code change: the five `Assets/Images/UI/Nav/` icons,
three `Particles/particle_*.png`, the minigame
result + report icons and `icon_benefit`/`icon_cost`/`icon_tired`/`icon_check`
(`UI/Placeholders/`), `icon_shop_items`/`icon_shop_cosmetics` (`Shop/UI/`), the
event-popup set (`icon_event.svg`, `bg_event_dialog.png`),
`shadow_ellipse.png`, `bg_inventory_blur.png`, four `icon_filter_*.svg`,
`EndCutscene`'s two badges, the eight `BarFill/fill_*` motif tiles, the
2026-09-10 cream-pass assets (`penjadwalan_card_bg.png`,
`Assets/Images/UI/BarFill/track_ghost.png`, `icon_ghost_koin.png`, `icon_ghost_sabit.png`),
the 2026-09-11 Koperasi rework set: `Assets/Images/Shop/UI/icon_keranjang.svg`,
`icon_keranjang_kosong.svg`, `tray_dots.png` (this last must
stay 26x26 -- it is a tiling texture and `tests/test_koperasi_tray.gd` asserts
those exact dimensions; in Godot 4 the repeat comes from the node's
`texture_repeat`, not a texture import flag), and the 2026-09-10 StudentList
Part 3 set: `UI/Placeholders/icon_wirausaha.svg`
(completed the six-category placeholder set; now UNREFERENCED -- StudentList's
category and specialty glyphs use the team's authored `StudentCard/stat_*`
art instead, so this is kept only as the one wirausaha glyph in the
placeholder family), `UI/Placeholders/stamp_sudah.svg` /
`stamp_belum.svg` (status-badge rubber-stamp rings), and
`UI/StudentList/photo_corner.png` / `roster_avatar_frame.png` / `catatan_rule.png`
(portrait tape, the avatar state ring, the teacher's-note rule — the last two
drawn white so `self_modulate` tints them from tokens), and
`UI/StudentList/page_dot.png` (a filled dot -- tinting the hollow ring above
it reads as invisible on a phone), and the 2026-09-14 EventDialogue set in
`Assets/Images/EventDialogue/`: `splash_gurusenibudaya.png` (a flat
silhouette for the Seni Budaya teacher, on the same 1080x1920 frame as every
splash), `hujan_background.png` (the school tinted dusk-blue with seeded rain
streaks) and `calendar_badge.png`, and the 2026-09-14 Weekly Results ribbon,
`Assets/Images/DaySummary/title_weekly_results.png` (cut out of the mockup
and given `title_daily_results.png`'s alpha -- drop-replaceable at the same
path).
(Checked 2026-09-14: `Particles/` also holds four more placeholder
`particle_*.png`: coin, glow, plus and spark. The event-popup set outlived the
popup: `icon_event.svg` is used by the week-recap rows and RunResult, and
`bg_event_dialog.png` by `EventStudentSelectDialog`.)

**Other art gaps.** `Assets/Images/EndGame/ujian_sekolah.png` (TesNotice's
Kelas 7-8 title) was keyed out of a black-background JPG -- brightness to
alpha, colour un-premultiplied, cropped -- not exported transparent; swap in a
real transparent export at the same path when one exists.
`EndCutscene`'s lose backdrop is `cg_lose.jpg` standing in for final art
(`WinStage`'s `lose_backdrop` `@export`, so an Inspector swap). `InventorySlot`'s high-count
`Shine` overlay is a plain white `ColorRect` with no texture.

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

**Audio placeholders.** These `AudioDirector` cue ids alias existing streams:
`specialty_match`, `tally`, `sparkle`, `star_earn_1/2/3`, `result_fanfare`,
`score_tick`, `combo_up`, and the BGM ids `exam_notice` and `run_result`.
`specialty_match`'s alias is set only in `audio_director.tscn`; the script
default is null. `event_announce` plays its own `event_announce.ogg`, but that
file is a byte-identical copy of `reward.ogg`. `ApplyItemScreen`'s payoff likewise reuses
existing cues rather than a dedicated `sfx_item_apply`.

**Copy placeholders.** Every `desc` string in `ItemDatabase.DEFAULT_ITEMS`
(shown verbatim in `ItemDetailSheet`) is placeholder copy, marked by one
blanket `[PLACEHOLDER]` comment above the table rather than one by one. Every `line` in
`EventDialogueCatalog.ENTRIES` (2026-09-14) is a draft, unmarked because it
shows in-game.

## Known bugs and gaps

**Koperasi's first shelf button is 27 px wider than authored (2026-09-14).**
`Rak1` in `Scenes/Koperasi/koprasi.tscn` is laid out 442 px wide
(offsets 303..745), but "KEBUTUHAN SEKOLAH" at its 40 px
`theme_override_font_sizes` override needs 469 px with `ShopShelfButton`'s
20 px side margins. A Button grows to its minimum size, so it renders 27 px
past its box. That predates the lobby-style-buttons pass, which keeps the
body-font label so it gets no worse (the display face would need 495 px). Fix
it by widening the node, trimming the margins, or replacing the override with
a smaller size step.

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

**TesNotice's card collapses (2026-09-11).** `NoticeCard` is a
`NinePatchRect`, not a Container, so the anchored `Content` never sizes it. It
shrinks to its 96px patch minimum and every line floats on the dark scrim; it
has shipped like this since the screen was built (2026-09-02). Measured live,
glyphs hidden: `BodyLabel`'s cream `ResultBodyLabel` reads there (6.9:1 at
worst; dark ink would fall to 1.1:1), but `Kicker` "PENGUMUMAN" is 1.8:1 and
`GradeLabel` "Kelas 7" 1.4:1. (Since 2026-09-12 the title is per-grade logo
art -- `ujian_sekolah.png` for Kelas 7-8, `ujian_nasional.png` for Kelas 9 --
so the old text title's margin overrun is gone.)
`notice.png` is a megaphone icon, not a card surface.
Either rebuild the card as a `Card` panel (text goes dark on cream, the
megaphone becomes an icon) or commit to text over the scrim (the two dark
labels go cream).

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

**Loose ends from the event-cards pass (2026-09-12).**
`EventStudentSelectDialog._apply_visual_exports()` looks up a `Background`
node but the scene's is `BackgroundDim`, so `background_texture` never swaps
in -- the one `viewport_editability` BASELINE count for that file is this
dead `TextureRect.new()`. The authoring guide's "Known gaps"
still lists `EventStudentSelectDialog.gd (11)`; the baseline is now 1.
SchoolDay's `_add_pill()` schedule-pill builder uses 📚/⚽/🎨 as internal
markers in label text before stripping them -- emoji in source, and
brittle. `EventStudentCard.set_preview()` never passes `preview_stat()`'s
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

**SchoolDay's playful textures never load (found 2026-09-14).**
`SchoolDay.gd`'s `_get_playful_texture()` builds
`res://Assets/Images/UI/Placeholders/*.png` paths, but the stat icons there
(`icon_akademis`, `icon_seni`, `icon_olahraga`, `icon_istirahat`, `icon_mood`,
`icon_energy`) exist only as `.svg`. Its `ResourceLoader.exists` check then
fails, so it returns nothing unless the `energy_icon_texture` /
`mood_icon_texture` exports are set.

## Deferred and pending

**Pending a balance pass.** `RunGrade`'s scoring weights (especially
`MONEY_FULL_MARKS`) are estimates; `LombaMenari.best_combo` is tracked but not
fed into the star rubric; the item skill-boost values in
`ItemDatabase.DEFAULT_ITEMS` (3–8) are untested against
`tests/test_balance_pacing.gd`. `RunGrade.LETTER_BANDS`' five rank
floors (S 90 / A 75 / B 60 / C 45) are estimates set when the scheme collapsed
from ten +/- bands on 2026-09-10, never played against a real run.
`MainBola`'s per-grade tables (8/10/10 shots, 4–6/6–8/6–8 goal targets,
2026-09-14) assume a player lands about 70% of shots; never playtested.

**Deferred: Plan C's RunResult redesign** (parked; no RunResult commit since
2026-09-11). Plan C's RunResult redesign,
`docs/superpowers/plans/2026-09-04-endgame-c-run-result.md` — but that pass
already replaced RunResult's grade letter with five rank badges and fixed its
win backdrop, so re-read the plan against the current screen before acting.

**Cosmetic shop is a stub.** `Scenes/Koperasi/CosmeticShop.tscn` is a blurred
backdrop, a "Segera Hadir" line and a back button. The shop hub's second tile
has to lead somewhere; nothing behind it is designed.

**Dead scene.** `Scenes/EndGame/WinScreen.tscn` is orphaned scaffolding — root
unscripted, nothing references it. The real win screen is `WinStage.tscn`,
which EndCutscene shows and RunResult keeps blurred behind its report. Safe to
delete. (Checked 2026-09-14: one commit deleted it and a later one brought it
back; the unmerged cleanup on `feat/asset-refresh-ui-pass`, `32b6f9a`, deletes
it again along with 177 other unused files.)

**Three orphaned tokens (2026-09-10).** `preview_row_shadow_color`, `_size` and
`_offset` are read by no variation since `PreviewRow` lost its shadow. Remove
them deliberately, or give them a consumer.

**Deferred: the AturJadwal shelf.** Ships as two `ColorRect`s rather than a
`ShelfEdge` variation. Needs an editor restart plus a manual rebake (a new
`@export` on `DesignTokens` is invisible to a running editor). The exact diff
is the Task 2 section of `docs/superpowers/plans/2026-09-01-atur-jadwal-mockup.md`,
which its STATUS block points to.

**Deferred: blinking on the layered faces.** Every face rig's `Eyelid` layer
and `StudentFace.blink()` are wired and tested, but `idle_blink_enabled`
defaults **false** — held back deliberately. A real pass wants a half-lid frame
(the art has none) or an alpha/scale ease rather than the current hard cut.

**Bug: Citra's eye rims show the lobby through.** `CitraFace.tscn`'s `Sclera`
sits at canvas y=578, where 114 of `citra_base.png`'s eye cut-out pixels are
covered by no layer (alpha down to 0.24) -- a faint line along the top of each
eye. y=579 (and `Eyelid` 579) covers them all and matches `Citra.png` better;
the fix also means updating `tests/test_student_face.gd`'s `_GEOMETRY`. The
other rigs keep a few anti-aliased rim pixels no placement covers (Doni 5,
Marcel 10), frozen as a budget in `tests/test_face_rig_roster.gd`; only new
art removes them.

**Ratchet debt.** `tests/test_viewport_editability.gd`'s `BASELINE` still lists
real unconverted runtime UI construction across roughly 20 files. The list, and
what each would need, is in the authoring guide's "Known gaps" section.
(Checked 2026-09-14: 23 entries, 22 of them nonzero, 131 constructions in all.)

**ExamProgress shows only the middle of cg_ujian (2026-09-14).** The art is
1920x1920, but `Backdrop` is 1296 wide and pans 216 px, so the outer 312 px on
each side never show. Showing it all means a 1920-wide `Backdrop` and
`pan_pixels = -840` (a faster pan over the same 4 s), plus the 1296 in
`tests/test_exam_progress.gd`'s width test.

**The inventory grid is wider than the screen (found 2026-09-14).** Measured
live, `inventory.tscn`'s `MainColumn/GridArea/Scroll` is 1107 px wide and
starts at x -13.5 on the 1080 canvas, holding three 358 px slots. The outer
slot columns are clipped by about 14 px on each side.
