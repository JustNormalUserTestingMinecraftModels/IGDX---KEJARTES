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
(**not** `UI/Nav/return_button.png`, which is authored art delivered
2026-09-22 — do not regenerate that one over the top of it),
three `Particles/particle_*.png`, the minigame
result + report icons and `icon_benefit`/`icon_cost`/`icon_tired`/`icon_check`
(`UI/Placeholders/`), `icon_shop_items`/`icon_shop_cosmetics` (`Shop/UI/`), the
event-popup set (`icon_event.svg`, `bg_event_dialog.png`),
`shadow_ellipse.png`, `bg_inventory_blur.png`, four `icon_filter_*.svg`
(white on purpose: `FilterChipButton` inks its icons `brand_primary`, so a
replacement must stay a white glyph, or that tint comes out of `ThemeFactory`
with it; `test_light_ground_text.gd` holds them at 3:1 on both chip states),
`EndCutscene`'s two badges, the
eight `BarFill/fill_*` motif tiles, the 2026-09-10 cream-pass assets
(`penjadwalan_card_bg.png`,
`Assets/Images/UI/BarFill/track_ghost.png`, `icon_ghost_koin.png`, `icon_ghost_sabit.png`),
the 2026-09-24 picker icons (`Assets/Images/UI/Picker/arrow_up.svg`,
`arrow_down.svg`, `pip_coin.svg`, `badge_check.svg`; hand-drawn vectors in the
token colours, sized to draw at 1:1),
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
path), and the 2026-09-18 Koperasi stock-pip set:
`Assets/Images/Shop/UI/pip_filled.svg` / `pip_hollow.svg` (a plain filled
dot and a matching ring, coloured from `koperasi_tag_fill`/`koperasi_tray_rule`
to stay warm and shop-consistent -- drop-replaceable at the same path), and the
2026-09-24 AturJadwal washi tape, `Assets/Images/AturJadwal/washi_tape.svg`
(hand-written SVG, not generated: a white striped strip with zigzag ends,
drawn white because `DayStickyNote` tints it by `self_modulate`, so a
replacement must stay light-on-transparent; keep it 246x40, the size it
displays at, or `test_texture_mipmaps` will want mipmaps on it).
(Checked 2026-09-14: `Particles/` also holds four more placeholder
`particle_*.png`: coin, glow, plus and spark. The event-popup set outlived the
popup: `icon_event.svg` is used by the week-recap rows and RunResult, and
`bg_event_dialog.png` by `EventStudentSelectDialog`.)

**Achievements polish (2026-09-18).** `AchievementTile`'s lock overlay is a
placeholder `Assets/Images/UI/Placeholders/icon_lock.svg` (plain padlock
glyph, drop-replaceable at the same path); the CLAIMED check badge reuses
the existing `icon_check.svg` from the same folder, no new asset needed.

**Other art gaps.** `Assets/Images/EndGame/ujian_sekolah.png` (TesNotice's
Kelas 7-8 title) was keyed out of a black-background JPG -- brightness to
alpha, colour un-premultiplied, cropped -- not exported transparent; swap in a
real transparent export at the same path when one exists.
`DayStickyNote`'s holiday padlock (`Paper/Lock`) is still the emoji glyph
"🔒" in a `Label`, against the no-emoji-iconography rule; swap it for a
`TextureRect` wearing the existing `UI/Placeholders/icon_lock.svg` (a type
change, so delete and recreate, and move `test_day_sticky_note`'s `Lock`
assertions off `Label`).
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

**Audio placeholders.** Mostly resolved by the 2026-09-21 Drive sound pack,
which gave real streams to `sparkle`, `star_earn_1/2/3`, `result_fanfare`,
`coin` and `event_announce`. Still aliasing existing streams:
`specialty_match`, `tally`, `score_tick`, `combo_up`, and the BGM ids
`exam_notice` and `run_result`. `specialty_match`'s alias is set only in
`audio_director.tscn`; the script default is null.

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
`back_tap`, `item_applied`, `apply`, `tutorial_popup`, `daily_claim`,
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
(`font_sizes`, `styles`, `colors`) exist in scene files, and **every one is
inside `Scenes/Minigames/**`**, which CLAUDE.md declares out of scope for the
design system. Outside the minigames there are zero. Every remaining
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
| `Scripts/AturJadwal/atur_jadwal.gd` | 5 |
| `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` | 3 |
| `Scripts/Inventory/ApplyItemScreen.gd` | 3 |
| `Scripts/AnimUtils.gd` | 3 |
| `Scripts/SchoolSimulation/StudentStatRow.gd` | 2 |
| `Scripts/Inventory/inventory.gd` | 2 |
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

**`Textures` is red: five Inventory tests look up moved nodes (2026-09-16).**
`feat(inventory): mobile redesign` (`431cc5d`) restructured
`Scenes/Inventory/inventory.tscn` without updating two suites, so a full
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

**Koperasi leftovers after the 2026-09-17 counter revamp.** Nothing references
`Assets/Images/Shop/rak 1.jpg` or `Assets/Images/Shop/rak2.jpg` any more
(`Illustration4.jpg` stays: ShopHub and CosmeticShop blur it). The
`ShopShelfButton` ThemeFactory variation is unused since the "KEBUTUHAN
SEKOLAH" sign went, but
`tests/test_lobby_style_buttons.gd:test_the_shelf_button_keeps_its_body_font_label`
still pins it. Delete the two JPGs, the variation and that test together, then
rebake.

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

**Boohong draws some punctuation as quote marks, and lacks more (found
2026-09-15).** `Assets/Fonts/Boohong.otf`'s cmap sends `‹`, `›` and `‚` to its
apostrophe glyph and `«`/`»` to its double quote. The font claims them, so
system fallback never runs: Inventory's "‹ Kembali" shipped as "' KEMBALI" on
desktop and Android alike, until the chevron became a texture — now the shared
`UI/Nav/return_button.png` on all twelve back controls. It has no
`•`, `…`, `—`, `←` or `→` at all; those fall back to whatever system font the
device picks. Buttons, titles and headings wear Boohong, so keep such
characters out of their text, and draw an arrow or chevron as a real texture.
Still in display text: CutScene's grade picker (`cut_scene.gd`'s
`_create_grade_button`, which the file calls the first-boot picker every
player sees) titles its Primary/SecondaryButtons with 🏫/🎓 emoji over
"•"-separated subtitles -- emoji the ban in `## Conventions` forbids.
`LombaMenari`'s ←/→/↖/↗ are body text, but Open Sans has no `←` either, so
they ride system fallback too (minigames sit outside the design system).

**SchoolDay still puts emoji in display text (swept 2026-09-22).** CLAUDE.md's
`## Conventions` bans emoji as UI iconography and says to use real transparent
textures instead, so these want an art pass, not a deletion. The back-button
pass fixed two of them -- `SchoolDay.tscn:105`'s back arrow became the shared
`UI/Nav/return_button.png`, and `SchoolDay.gd`'s "Minggu selesai!" lost its
party popper -- and left the rest, because six strings is a real pass:

| Where | Glyph |
|---|---|
| `SchoolDay.gd:78` `end_tutorial_title` (an `@export` default) | graduation cap |
| `SchoolDay.gd:80` `end_tutorial_text` (an `@export` default) | dart, and an arrow twice |
| `SchoolDay.gd:437` -> `status_label` | check mark |
| `SchoolDay.gd:959` -> `status_label` | herb |
| `SchoolDay.tscn:95` `ClickToContinueLabel` | sparkles, arrow |
| `SchoolDay.tscn:113` `SkipButton` | next-track |

Two traps for whoever takes this. The first two are **`@export` defaults**, so
per CLAUDE.md a changed default needs a **full editor restart** before it takes
effect -- `load_default()` keeps serving the cached instance. And the
emoji at `SchoolDay.gd:537-538` and `:628-655` are **not** display text: they
are icon keys that `_add_pill()` strips at `:660-682` and swaps for a texture.
Leave those alone.

**The remaining `pngwing.com` stock files want replacing (2026-09-22).**
`pngwing.com (1).png` went with the back-button pass, which was a licensing
tidy-up as well as a visual one: the filename is verbatim from a free-PNG
aggregator, the project records no licence for it, and most of that catalogue
is non-commercial. Still in the tree: `(2).png` (pinned out of the Peringatan
dialog by `test_atur_jadwal.gd:641`), `(3).png` (live at
`student_card.tscn:14`) and `(6).png` (already replaced on Koperasi's basket
per `CHANGELOG.md:1461`). Replace them with authored art before any release.

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

**Opening BookClockWidget.tscn hangs the editor (moved from CLAUDE.md, 2026-09-15).**
`scene_open` on `Scenes/SchoolSimulation/BookClockWidget.tscn` hangs the
editor — the call times out, the MCP transport write-pauses, the plugin
disconnects, and the editor needs a restart. Cause unconfirmed; verify that
widget via `project_run` instead, which exercises it fine.

## Deferred and pending

- **Premium-look leftovers (2026-09-22, PRs 2-6).** The programme in
  `.superpowers/gamecode/premium-look/` shipped items 1-10 and 12; item 11
  (the Lobby's black bands at 20:9) was cut by the brief. What was
  deliberately left:
  - **TesNotice's NoticeCard gets no contact shadow.** It is a 512px
    NinePatchRect, and PaperShadow's Silhouette is a plain TextureRect, which
    would scale that texture instead of 9-slicing it. Needs a NinePatch
    silhouette variant.
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
  - **Item 12, VRAM compression, is built and reverted, not skipped.** The
    project holds 1182 MB of uncompressed RGBA8 texture data, 1069 MB of it
    Lossless. Compressing the 160 textures at 512x512 or larger cuts 975 MB
    to 244 MB and every suite still passes individually -- but a FULL
    `test_run` then never completes: the editor climbs to ~2 GB, stops
    responding and has to be killed. Reverting the 160 `.import` files and
    keeping only the project setting brought the full run back at 2123/2123
    in 9 s, so the compression is the cause, and disabling ETC2 alone did not
    help. To redo it: `compress/mode=2` on every texture .import whose source
    is >= 512x512, EXCLUDING `Assets/Images/UI/BarFill/**` and
    `Shop/UI/tray_dots.png` (their sharpness is asserted) and every `.svg`
    (test_end_cutscene pixel-checks the badges). The 195 smaller textures
    should stay lossless regardless: block artifacts show on small crisp UI
    and the saving is minor. Land it only together with a way to run the
    suite -- coverage is the quality floor.
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
  - `UI/loby_no_tables.png` is 768x1376 drawn full-screen — **upscaled 1.41x**,
    the largest surface on the highest-traffic screen. No code fix exists;
    this one needs a bigger source from the artist. Same for
    `Shop/UI/bg_inventory_blur.png` (1.41x up) and `UI/BG.jpg` (1.47x up,
    CutScene and Settings).
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
  `ShopMessageDanger` (`ThemeFactory.gd`) are unused by `koprasi.gd` after
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

- **skin_card_focus.gdshader's blur cost is unmeasured on low-end Android
  (2026-09-23).** 48 taps per pixel on a full-size card, and mid-slide both
  the centred and the neighbour card are on the blurred path at once. If it
  drops frames while dragging, precompute the per-tap offsets/weights (they
  depend only on `i`, not on `sigma_texels`) or blur a downsampled copy.

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
filling them wants taller classroom art.

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
