# KejarTes — change log

Completed work, newest first. This file is **not** loaded into Claude Code
sessions; `CLAUDE.md` is. Anything here is history — read it on demand when you
need to know why something is the way it is.

Facts that still govern how you work on the project belong in `CLAUDE.md`, not
here. Unfinished placeholders belong in its `## Outstanding debt & placeholders`
section. See `CLAUDE.md`'s `## Maintaining this file`.

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
