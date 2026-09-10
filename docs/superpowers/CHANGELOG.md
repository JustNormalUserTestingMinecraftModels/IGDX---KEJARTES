# KejarTes — change log

Completed work, newest first. This file is **not** loaded into Claude Code
sessions; `CLAUDE.md` is. Anything here is history — read it on demand when you
need to know why something is the way it is.

Facts that still govern how you work on the project belong in `CLAUDE.md`, not
here. Unfinished placeholders belong in its `## Outstanding debt & placeholders`
section. See `CLAUDE.md`'s `## Maintaining this file`.

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
