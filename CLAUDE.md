# KejarTes — Project Guide

Godot **4.6** mobile game (portrait 1080×1920, `mobile` renderer, d3d12).
Indonesian-language school-management sim. Main scene:
`Scenes/MainMenu/main_menu.tscn` (since the 2026-08-31 boot change).

## The game

You play a teacher. You approve a roster of students, assign each of them a
daily activity for the school week, then watch the week simulate. Stats move,
minigames and random events fire, and at week's end you get a report. Clear
every student's three academic targets before the grade's final week to pass.

**Grades scale the whole game** (`GameState.current_grade`, 7–9):

| Grade | Weeks | Target uplift over base | Minigame win stat | Loss penalty |
|---|---|---|---|---|
| 7 | 6 | +15 | 10 | −3 |
| 8 | 12 | +30 | 8 | −4 |
| 9 | 16 | +40 | 6 | −5 |

**Loop:** **MainMenu (boot)** → CutScene → StudentCard (approve roster) →
**Lobby (hub)** → AturJadwal (assign week) → StudentList → SchoolDay
(simulate 5 days) → ResultCheckup → back to Lobby. On the final week of a
grade, SchoolDay instead runs the end-of-grade sequence: **TesNotice →
ExamProgress → StatCheck → RunResult → MainMenu.** Splashscreen and Loading still
exist and are still tested, but since 2026-08-31 they are no longer reached
at boot.

**Lobby hub buttons** → StudentCard, AturJadwal, Koperasi (shop), Inventory,
ReportCard.

### Stats & activities

Every student has three skills (`akademis`, `seni_budaya`, `olahraga`) and two
needs (`energy`, `mood`), all 0–100. Five schedule categories:

- `Akademis` / `SeniBudaya` / `Olahraga` — gain that skill, cost energy+mood.
- `Istirahat` — recover energy+mood, no skill gain.
- `Wirausaha` — no skill gain; earns money at a higher mood/energy cost.
  Accrues into `GameState.pending_earnings`, paid out at week end.

Costs are scaled by `get_category_efficiency_multiplier()`: 0.6× for the
student's specialty, 0.85× for `Seimbang`, 1.20× otherwise. A student at
energy ≤ 5 auto-takes "Izin" (forced Istirahat).

**Personalities** (`Aktif`/`Tekun`/`Kreatif`/`Santai`/`Seni Dalam Kesunyian`)
drive daily decay rates. **Quirks** (`Kutu Buku`, `Penyendiri`, `Semangat
Juang`, `Penasaran`, `Biang Onar`, `Pekerja Keras`) modify gains and costs.
Every quirk coefficient is an `@export` on `StudentData.gd` — tune in the
Inspector, don't hardcode.

## Architecture

### Autoloads (`project.godot`)

| Autoload | Role |
|---|---|
| `GameState` | **The source of truth.** Roster, schedules, week, grade, money, inventory. |
| `Transition` | Scene changes with WIPE/FADE/IRIS styles. |
| `GameSettings` | Persisted settings (`user://`). |
| `AudioDirector` | SFX/BGM registry and bus volumes. |
| `UIPolish` | Auto-juices every Button on scene load. |
| `TouchFeedbackManager` | Touch ripple effects. |
| `DebugManager` | In-game debug overlay (5-tap gesture). Week/grade/money/stat editors, scene teleport, minigame launcher, cheats. |
| `ItemDatabase`, `Cart` | Shop item catalog and cart. |
| `_mcp_game_helper` | Godot AI MCP runtime hook. |

### The two student representations — know which you're holding

- `GameState.approved_students` — **`Array[Dictionary]`**, the cross-screen
  source of truth. Keys are the UI's names: `akademis1/2/3` (academic, seni,
  olahraga), `kepribadian1/2` (**mood, energy**), `name`, `id`, `quirk`,
  `persona`, `hobby_category`, `portrait`, `splash`.
- `StudentData` — a `Resource` with real fields (`akademis`, `seni_budaya`,
  `olahraga`, `mood`, `energy`) and all the gameplay math. Used only inside
  the simulation.

Bridge: `GameState.convert_to_student_data_array()` in, and
`StudentManager.write_back_to_gamestate()` out. **The naming does not line up
between the two** (`akademis2` = seni_budaya, `kepribadian1` = mood) — this is
the single most common source of bugs here. Note `hobby_category` "Akademik"
maps to specialty "Akademis"; schedules also normalize `Akademik`→`Akademis`
and `DayOff`→`Istirahat`.

No save system. Everything is session-scoped by design — do not add
persistence to `GameState` without being asked.

## Visual system — read this before touching any UI

Everything flows from `Assets/Theme/design_tokens.tres` (a `DesignTokens`
resource). To change a color/radius/font globally: edit that resource, then
**rebake** by running `Scripts/Design/BakeTheme.gd` via File > Run
(Ctrl+Shift+X), which writes `Assets/Theme/kejartes_theme.tres`.

**The rule: never add a `theme_override_*`.** Use a `ThemeFactory` type
variation instead (`PrimaryButton`, `SecondaryButton`, `DangerButton`,
`SuccessButton`, `LobbyNavButton`, `Card`, `SunkenPanel`, `Scrim`,
`DisplayLabel`, `H1Label`, `H2Label`, `TitleLabel`, `CaptionLabel`,
`MicroLabel`, `BarLabel`, `StatBar`, …). If none fits, add a new variation in
`ThemeFactory.gd` and rebake. Only accepted exception: layout-only constant
overrides (`separation`, `margin_*`).

Full detail: `docs/superpowers/design/style-guide.md`.

**The second rule: no visual is built at runtime.** Static chrome is a node in
the `.tscn`; repeated rows are a `PackedScene` template; responsive geometry
is a `@tool` script driven by documented `@export` knobs. Every script's
documentation (a `##` file header, a `##` line on every `@export`) is a hard
rule now (`tests/test_script_documentation.gd`) — the 2026-08-31 21-task
sweep closed that ratchet. Runtime visual construction is still a ratchet
(`tests/test_viewport_editability.gd`): a `BASELINE` dict of real remaining
debt, frozen and only ever lowered, plus an `ALLOWED` dict of reviewed,
commented, permanent exceptions (per-call-dynamic content, or a conditional
texture-vs-procedural swap) — see the authoring guide's "Known gaps" section.

Full detail: `docs/superpowers/design/authoring-guide.md`.

**Two animation APIs, both live:**
- `Scripts/Design/Juice.gd` — the project's own (`press`, `release`, `pop_in`,
  `stagger_in`, `count_up`, `fill_bar`, `shake`). Buttons get press/release
  wired automatically by `UIPolish`; opt out with
  `node.set_meta(Juice.NO_AUTO_JUICE, true)`.
- `Scripts/AnimUtils.gd` — came in with the ported shop/inventory
  (`squash_bounce`, `popup_spring_in/out`, `coin_pulse`, `create_floating_text`,
  …). It is a plain static-function script, **not** an autoload.

Minigames (`Scenes/Minigames/**`) and the debug overlay
(`Scripts/Debug/DebugManager.gd`) are explicitly **out of scope** for the
design system — minigames inherit the Theme but had no polish pass, and the
overlay is a programmatic developer tool that styles itself directly.

## Testing

Suites live in `tests/test_*.gd`, extend `McpTestSuite`
(`addons/godot_ai/testing/test_suite.gd`), and run **inside the editor** via
the Godot AI MCP `test_run` tool. 45 suites, 568 tests, all green
(2026-09-01).

Hard constraints, learned the hard way:

1. **The suite must be `@tool`** or the runner reports it abstract/broken.
2. **No test may be a coroutine.** The runner does `suite.call(name)` without
   awaiting — an `await` silently aborts the test mid-way, and it reports as
   "0 assertions". (See Known Issues.)
3. Scripts the runner instantiates live must be `@tool` too, with real side
   effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
   Pure signal wiring stays ungated so tests can exercise it.
4. Some suites assume the **main scene is open** in the editor; `test_run`
   returns a `scene_warning` when it isn't, naming the scene it wants. Open
   `Scenes/MainMenu/main_menu.tscn` before trusting a failure.

Many tests are **source-text scans** (`src.contains(...)`) rather than
behavioral, because a lot of the UI can't be instantiated headlessly. Follow
that pattern where it's established.

## Godot MCP

The `godot-ai` MCP server drives the live editor: `test_run`, `scene_open`,
`scene_get_hierarchy`, `node_*`, `script_patch`, `project_run`,
`editor_screenshot`, `logs_read`. Prefer these over shelling out.

If a session fails to attach with *"A different Godot AI backend is already
running"*, stray `godot-ai.exe` processes are holding the port. Kill them
(leave `Godot_v*.exe` alone) and retry:

```bash
tasklist | grep -i godot-ai
```

`logs_read(source="editor")` catches parse errors that never reach the game
log; `source="game"` misses boot-time failures entirely.

## Working efficiently here

Verification, not implementation, dominates the cost of a session in this
project. Five rules, in order of how much they save:

**1. Never play the game to reach a state — seed it.** The debug overlay
(`F1`, or 5 taps in the top-right corner) has **⚡ Seed Playtest State** at the
top of its General tab: roster approved, 999999G, full inventory, lobby
tutorial bypassed. Combine it with the overlay's **Scenes** tab, which
teleports directly to MainMenu / Lobby / StudentCard / AturJadwal / SchoolDay
/ SemesterEnd / Splashscreen. Seed, teleport, screenshot once. The seed covers
roster, money, inventory and the lobby tutorial flag — it does **not** fill
`day_schedules`, so anything schedule-driven (SchoolDay, AturJadwal) still
needs a pass through Atur Jadwal first. Driving the shop purchase flow by
simulated clicks to reach the same state took roughly forty-five calls and
failed twice before working.

The overlay's **Scenes** tab also carries **🎭 Gladi Resik Akhir Kelas** —
three one-click rehearsals of the whole end-of-grade sequence (TesNotice →
ExamProgress → StatCheck → RunResult) with a fixed roster:
*Semua Lulus* (win path), *Semua Gagal* (lose path), and *Campur*, which
ladders 3/2/1/0 cleared targets across the four students so one pass of
StatCheck lights the meter 3, 2, 1 and 0 shares in turn (6 of 12 = 1.5
stars, a loss). Arming
one snapshots the run first; **↩ Pulihkan Run Sebelum Gladi Resik** puts it
back, which matters because RunResult's progression otherwise advances the
grade and clears the roster on its way out. These replaced the bare
"Teleport ke: Evaluasi Semester" button, which landed on an empty carousel
whenever no roster was approved. The logic is in
`Scripts/Debug/EndGameRehearsal.gd` (plain static functions, tested
behaviourally in `tests/test_end_game_rehearsal.gd`); `DebugManager.gd`
only holds the buttons.

When you do have to click, note two quirks. Send a `motion` event to the
target before the `button` press — Godot will not route a click without the
hover state first, and a bare press/release pair silently does nothing.
And rescale coordinates: `global_rect` values are in the project's
1080-wide design space, while input events take window pixels. Derive the
factor instead of hardcoding one — `editor_screenshot` reports the window's
real size as `original_width`/`original_height`, so
`window_x = global_x * original_width / 1080`. Read the target's
`global_rect` rather than eyeballing a screenshot.

**2. Scope every `get_ui_elements` call.** Called bare it serialises the whole
tree — the debug overlay alone returns 58 verbose nodes. Always pass
`root_path` and a shallow `max_depth`:

    game_manage(op="get_ui_elements",
                params={"root_path": "/root/Inventory/MainLayout", "max_depth": 3})

Note the runtime path quirk: autoloads answer to `/root/<Name>` (e.g.
`/root/DebugManager`) but the reply echoes paths relative to the current
scene (`/Inventory/../DebugManager`). Bare `/root` returns nothing.

**3. Prefer `test_run` over screenshots.** The whole suite — 568 tests, 45
suites — returns a compact JSON summary in about two seconds. One screenshot
costs more tokens than the entire run. Reach for a screenshot only to judge
something genuinely visual (layout, spacing, color); use `test_run` for
anything about behaviour or wiring. Many suites here are deliberately
source-text scans (`src.contains(...)`) precisely because they are cheap and
do not need the scene instantiated.

**4. Never hand-edit a `.tscn` while the editor is attached.** It caches
every scene, its in-memory copy wins, and the next `scene_save` silently
overwrites your text edit — `scan`, `reimport` and even
`scene_open(force_reload=true)` all fail to evict it. Go through the editor:
`scene_open` → `node_create` / `node_set_property` / `node_manage` →
`scene_save`. `batch_execute` takes the plugin command names (`create_node`,
`set_property`, `move_node`, `delete_node`) and does a whole node in one
call. Gotchas: `anchors_preset` is inert (set the four anchors), numbers must
be unquoted (`1`, not `"1.0"`), `node_create` appends last so z-order needs
`move_node`, and a node's *type* can only be changed by delete-and-recreate.
The same cache bites `class_name` scripts: a **new `@export` on a Resource is
invisible until the editor restarts**, which is why the theme rebake
(`Scripts/Design/BakeTheme.gd`, File > Run) has no headless path.

**5. Rescan after editing a `.gd`, before running tests.** `test_run` will
serve a **stale** autoload otherwise. Three tests once failed with
"Nonexistent function 'seed_playtest_inventory'" while that function sat
committed on disk; one `filesystem_manage(op="scan")` turned the same run into
20/20. Scan first, or you will debug a phantom.

**A scan is not always enough.** When the `.gd` was edited from *outside*
the editor — any plain file write, including one from a subagent — the
editor can keep serving the old bytecode through a scan. On 2026-09-02 both
`ThemeFactory.gd` and `StatBar.gd` did exactly that: their brand-new tests
failed, and a new `@export` was invisible to `node_set_property`
("Property 'pop_on_change' not found on StatBar"), all while the correct
source sat on disk. A **no-op `script_patch` on that same file** forces the
reload — add and remove a blank line. It logs a benign
`GDScript reload failed with error code 43` and then works. Cheapest
reliable fix: make edits through `script_patch` in the first place.

There is no MCP entry point for an `EditorScript` such as
`Scripts/Design/BakeTheme.gd`, so the theme rebake normally needs
File > Run by hand. It can be driven headlessly instead by writing a
transient `@tool` `McpTestSuite` into `res://tests/` whose single test does
the `ThemeFactory.build()` + `ResourceSaver.save()`, running it with
`test_run`, then deleting it.

One smaller habit: grep before reading — the two largest scripts here
exceed 1,500 lines, so read the range you need, not the file.

**The Godot MCP bridge is single-client.** Only one client can hold the
backend at a time. If you delegate to subagents, they cannot run the editor:
a subagent that connects displaces your session and gets nothing itself, and
both then see "A different Godot AI backend is already running". Recovery is
`taskkill` on the stray `godot-ai.exe` processes, leaving `Godot_v*.exe`
alone. So: subagents write code, you run the editor and hand them the results.

None of this trades away test coverage. Coverage is the quality floor; the
savings come from cheaper verification loops, not from fewer tests.

## Known issues (as of 2026-08-31)

None outstanding. The 2026-08-30 stability sweep closed all three of the
previous entries; see `docs/superpowers/specs/2026-08-30-project-stability-sweep-findings.md`
for what each turned out to be.

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

## Current work

Branch `Textures` (this is also the main branch).

The 2026-09-04 end-game rebuild replaced the whole tail of the flow
described above. **TesNotice → ExamProgress → StatCheck → RunResult →
MainMenu** is now accurate. `WinScreen.tscn`/`.gd`, CutScene's exam and
game-over branches, and the `SemesterEnd` carousel with its
`ResultStatRow` template were all deleted outright — Plan B reinstates
a WinScreen/LoseScreen pair between StatCheck and RunResult, and Plan C
redesigns RunResult.

`ExamProgress` is a pacing beat after TesNotice ("Tes sedang
berlangsung" plus a timed fill bar); it pans its backdrop 216 px during
the fill, which is why that node is authored 1296 wide rather than 1080.
Plan A (`docs/superpowers/plans/2026-09-04-endgame-a-statcheck.md`) then
replaced the exam-intro cutscene beat and the SemesterEnd carousel with
`StatCheck` — an automated one-student-at-a-time reveal: the card slides
in from the right, its bars fill akademis → seni → olahraga, a bar that
reaches its target pops (squash-bounce plus a `RewardBurst`), and every
cleared stat lights `1/(roster×3)` of a shared 3-star `StarMeter`. It
ends in a white fade.

The win rule moved with it: `GameState.check_semester_passed()` is now
`run_stars() >= Balance.STAR_WIN_THRESHOLD` (2.0 of 3.0) — two-thirds of
all academic targets cleared anywhere on the roster, no longer
all-or-nothing, so one weak student no longer loses the run.

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

The main menu was rebuilt on 2026-08-31 to match
`docs/superpowers/mockups/main-menu.png` measurement-for-measurement and is
now the boot scene — see
`docs/superpowers/specs/2026-08-31-main-menu-mockup.md` for the probe trail
and the documented deviations (66 px button separation, font size 80 rather
than the mockup-implied 100 so "PENGATURAN" fits, gold button art rather than
the mockup's grey, and an ungraded background).

The 2026-08-30 stability sweep
(`docs/superpowers/plans/2026-08-30-project-stability-sweep.md`) is complete.

The 2026-09-01 art pass is complete except for one deferred item. Spec:
`docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`; five plans
in `docs/superpowers/plans/2026-09-01-*.md`, each carrying a STATUS block with
its deviations. It landed the six-student splash batch (all four rosters
rewired, Daily Results avatars recropped, and the avatar flipped to
splash-first as `DaySummaryAvatar.gd` had asked), the blurred-classroom
backdrop on DaySummary / ResultCheckup / AturJadwal, ReportCard/StudentCard
render parity, AturJadwal's mockup top band with the stat pills lifted out of
the splash button, and the intro cutscene's new dialogue panel.

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

**Deferred:** AturJadwal's shelf ships as two `ColorRect`s rather than the
intended `ShelfEdge` theme variation — a new `@export` on `DesignTokens` is
invisible to a running editor, so it needs a restart plus a manual rebake. See
the STATUS block in `2026-09-01-atur-jadwal-mockup.md` for the exact diff to
re-apply.

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
`test_run`) — see that plan's SDD ledger
(`.superpowers/sdd/2026-09-02-end-of-grade-sequence/progress.md`, deleted
after merge) for the fix-loop history if anything here needs revisiting.

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
split, which this pass also used throughout
(`.superpowers/sdd/2026-09-03-day-summary-polish-and-rewards/progress.md`,
deleted after merge). Placeholders outstanding: the three particle sprites
(`Assets/Images/Particles/particle_*.png`, crude flat geometry) and the
two aliased SFX streams.

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

`-REFERENCE-/prototype/` is the original prototype, kept for reference only —
not built, not imported. `koprasi&inventory` was a second programmer's separate
project; the spec's Asset Policy documents exactly which of its art is
finished (copy byte-identical) versus placeholder chrome (restyle onto our
theme).

## Conventions

- Game-facing identifiers and all UI text are **Indonesian**; engine and systems code
  is English. Match whatever the surrounding file does.
- File naming is inconsistent (`loby.gd`, `koprasi.gd` are misspelled but
  load-bearing — do not "fix" them).
- Commits: Conventional Commits with a scope, e.g.
  `fix(lobby): wire the dead ReportStudent button`.
- Tunable gameplay numbers belong in a named `const` block or an `@export`,
  not inline. See `StudentManager.gd`'s `WIRAUSAHA_*` block.
