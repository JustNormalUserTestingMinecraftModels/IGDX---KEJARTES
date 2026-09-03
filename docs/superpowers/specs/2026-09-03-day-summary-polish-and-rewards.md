# Day Summary & Weekly Result — Card Fix, Needs Labels, Reward Particles, SFX

**Date:** 2026-09-03
**Status:** specified, not yet implemented
**Reference image:** the two-card mockup supplied in-chat (`ref.jpeg`) — two
`DaySummaryStudentRow` cards, brown and cream, each showing avatar / name /
two labelled needs bars / three stat rows.

## 1. Why

Three separate complaints, one screen family (`DaySummaryPopup` nightly,
`ResultCheckup` weekly — both render the *same*
`Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`):

1. **`StatRow1-3` render wrong.** The `Value` label is mis-anchored and lands
   on top of the `Track`, so "+12/65" prints over the coloured bar instead of
   beside it. The three rows are also unevenly pitched inside the card
   (97 / 100 px steps).
2. **Energy and mood read as two anonymous capsules.** The reference gives
   each one an icon and a word ("Lelah", "Senang"). The project already ships
   `Assets/Images/UI/Placeholders/icon_energy.svg` and `icon_mood.svg`.
3. **Nothing celebrates.** A student who grew today gets a bar that slides and
   nothing else. Both screens should reward progress with particles and sound.

## 2. Scope

In scope: `DaySummaryStatRow`, `DaySummaryStudentRow`, `DaySummaryPopup`,
`ResultCheckup`, `AudioDirector` slots, `ThemeFactory` variations, new
particle-sprite placeholder art.

Out of scope: minigames, the debug overlay, `RunResult` / `WinScreen` (the
2026-09-02 end-of-grade work), any change to how deltas are *computed*.

## 3. Requirements

### 3.1 Stat row geometry (bug fix)

`DaySummaryStatRow.tscn`'s `Value` label must occupy the right-hand
`VALUE_WIDTH` (200 px) of the row and nothing else:

    anchors_preset 6 (right-centre), offset_left = -200, offset_right = 0

The current `-321 / -121` pair pushes it 121 px left of the row's right edge,
straight over the `Track` (which ends at `-200`). The script's `VALUE_WIDTH`
constant is already correct and is the single source of truth; the scene must
agree with it.

`DaySummaryStudentRow.tscn` must pitch its three stat rows evenly at 97 px:
tops at 57 / 154 / 251, bottoms at 153 / 250 / 347.

### 3.2 Needs icon and label — ON the existing bars

Energy and mood already have one `ProgressBar` each on the card (`EnergyBar`,
`MoodBar`). They gain an icon and an Indonesian tier word **inside that same
bar**. Nothing new is stacked above or below them: a second bar-shaped node per
need would read as a redundant duplicate of the bar beside it, which is
explicitly ruled out. The bar keeps its fill, its geometry and its existing
`DaySummaryEnergyBar` / `DaySummaryMoodBar` variation.

So the deliverable is not a new template scene. It is:

- two authored children — `Icon` (`TextureRect`) and `Word` (`Label`) — added
  inside `EnergyBar` and `MoodBar` in `DaySummaryStudentRow.tscn`, and
- a script `Scripts/SchoolSimulation/DaySummaryNeedsBar.gd`
  (`extends ProgressBar`, `class_name DaySummaryNeedsBar`) attached to both,
  which sets the bar's value and dresses those two children from one call.

The existing right-aligned `DeltaLabel` child stays exactly as it is — it is
already the weekly signed number — and the new `Word` is left-aligned beside the
icon, so the two never collide.

Tier words, Indonesian, thresholds on the 0–100 value:

| Need   | 0–33     | 34–66   | 67–100   |
|--------|----------|---------|----------|
| energy | `Lelah`  | `Cukup` | `Bugar`  |
| mood   | `Sedih`  | `Biasa` | `Senang` |

Icons: `res://Assets/Images/UI/Placeholders/icon_energy.svg` and
`icon_mood.svg`, matched by the need key `"energy"` / `"mood"`.

The word is the same on the nightly and weekly cards. The week's signed number
is not appended to it — `DeltaLabel`, which the weekly path already shows and
the nightly path already hides, remains the only place that number appears.

Styling adds exactly one baked variation, `DaySummaryNeedsLabel`, for the word:
white text with the card's dark rim, one step down from `DaySummaryStat` so a
long word fits inside the bar. **No new `DesignTokens` `@export`**, so the
rebake does not need an editor restart (CLAUDE.md's documented hazard), and **no
new panel stylebox**, because there is no new panel.

### 3.3 Reward particles

Placeholder sprites, generated as transparent PNGs by an `EditorScript` in the
established `Scripts/Design/GenerateStickyNoteIcons.gd` mould, written to
`res://Assets/Images/Particles/`:

- `particle_star.png` — 4-point sparkle star, 128²
- `particle_confetti.png` — rounded rectangle chip, 128²
- `particle_ring.png` — soft hollow ring, 128²

They are placeholders by contract: the visual team replaces the PNGs in place,
so **the file names are load-bearing**. Emoji are banned as iconography here,
as they are project-wide.

Two scenes, both `GPUParticles2D`, both one-shot, both authored in `.tscn`
(never built at runtime — the project's second visual rule):

- `Scenes/SchoolSimulation/RewardBurst.tscn` — a small per-card burst of stars
  fired at a stat row that gained. Emits ~14 particles, ~0.7 s, upward cone.
- `Scenes/SchoolSimulation/CelebrationConfetti.tscn` — a wide screen-top
  confetti fall for `ResultCheckup`. Emits ~90 particles over ~2.4 s.

Firing rules:

- Nightly (`DaySummaryStudentRow.play_gain`): one `RewardBurst` per stat row
  whose delta is `> 0`, on that row's own beat.
- Weekly (`ResultCheckup`): the same per-row bursts, **plus** one
  `CelebrationConfetti` for the whole screen, fired once after the cards have
  landed, and only if at least one student gained ground over the week.

### 3.4 Audio

Two new `AudioDirector` slots, following the project's placeholder-alias
convention (a new id pointing at an existing file until real art lands):

| id        | placeholder file      | plays when |
|-----------|-----------------------|------------|
| `tally`   | `SFX/pop.ogg`         | a stat row's chevron pops in on a gain |
| `sparkle` | `SFX/reward.ogg`      | a `RewardBurst` or `CelebrationConfetti` fires |

Existing ids stay where they are; nothing is re-pointed.

## 4. Non-goals / accepted deviations

- The needs bar shows a *tier word*, not a number. The precise value is already
  carried by the bar's own fill, and the week's delta by `DeltaLabel`.
- Particle art is deliberately crude — no Python/ImageMagick on this machine,
  same constraint `GenerateStickyNoteIcons.gd` documents.
- The two new SFX alias existing files; a real-audio pass is deferred.
- `particle_ring.png` is generated but not wired into either emitter in this
  pass. It is a spare for the visual team to swap in, and the plan tests only
  that it exists and is transparent.

## STATUS (2026-09-03, implementation complete)

Built via subagent-driven-development on branch `day-summary-polish-and-rewards`,
with the Godot MCP bridge held by the controller session throughout — the
same split the 2026-09-02 end-of-grade-sequence pass used: implementer
subagents wrote scripts and tests, the controller built every `.tscn`
mutation and ran every `test_run`. All 9 plan tasks landed; whole-project
suite is 683/683 across 51 suites at completion of Task 8.

Deviations from the plan's literal text, all judgment calls made during
execution (see `.superpowers/sdd/2026-09-03-day-summary-polish-and-rewards/progress.md`
for the full ruling log, deleted after merge):

- **§3.2 redesigned mid-flight.** The plan's first draft put the needs
  icon+word in a new sibling `DaySummaryNeedsPill` chip stacked above each
  bar. The user caught this as a duplicate bar-shape and the design was
  corrected before implementation: `DaySummaryNeedsBar.gd` (extends
  `ProgressBar`) puts an `Icon` and `Word` child *inside* the existing
  `EnergyBar`/`MoodBar`, adding no new node and no new panel stylebox. The
  spec's §3.2 above reflects the corrected design, not the original.
- **§3.4 SFX wiring.** Rather than assigning `sfx_tally`/`sfx_sparkle` in
  the `audio_director.tscn` inspector, both use `@export ... = preload(...)`
  script defaults, matching the precedent the 2026-09-02 pass already set
  for `bgm_exam_notice`/`bgm_exam_cutscene`/`bgm_run_result` in the same
  file. Same result, no scene edit.
- `tests/test_audio_coverage.gd`'s `test_every_play_sfx_id_in_the_project_is_known`
  carries its own hardcoded id allowlist, independent of AudioDirector.gd;
  it needed `tally`/`sparkle` added or the suite regressed. Not anticipated
  by the plan; fixed in the same commit as the SFX slots.
- Two GDScript authoring hazards surfaced repeatedly and are worth carrying
  into any future work here: `load(path).instantiate()` chained in one
  expression fails static type inference (write it as two statements,
  `var s: PackedScene = load(path)` then `s.instantiate()` — bit both test
  code and, once, `DaySummaryStatRow._play_burst`), and `McpTestSuite`
  extends `RefCounted`, not `Node` — a test that needs a live scene in the
  tree must parent it with `Engine.get_main_loop().root.add_child(x)`.
- The theme rebake hit a resource-cache staleness this session: after
  `ResourceSaver.save()`-ing a new `Theme` to a path already cached from
  earlier `test_run` calls, `load()` kept returning the stale cached
  instance. Fixed with `theme.take_over_path(path)` before the save — worth
  keeping in the transient rebake-suite template for next time.

Placeholders shipped as designed, per §4: the three particle PNGs, and the
`tally`/`sparkle` SFX aliases.
