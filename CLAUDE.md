# KejarTes — Project Guide

Godot **4.6** mobile game (portrait 1080×1920, `mobile` renderer, d3d12).
Indonesian-language school-management sim. Main scene:
`Scenes/MainMenu/main_menu.tscn` (since the 2026-08-31 boot change).

## The game

You play a teacher. You approve a roster of students, assign each of them a
daily activity for the school week, then watch the week simulate. Stats move,
minigames and random events fire, and at week's end you get a report. Clear
two-thirds of the roster's academic targets — `run_stars() >= 2.0` of 3.0 —
before the grade's final week to pass. It is a roster-wide fraction, not a
per-student gate: three students clearing everything while a fourth clears
nothing is 9 of 12 = 2.25 stars, and passes.

**Grades scale the whole game** (`GameState.current_grade`, 7–9):

| Grade | Weeks | Target uplift over base | Minigame win stat | Loss penalty |
|---|---|---|---|---|
| 7 | 6 | +15 | 10 | −3 |
| 8 | 12 | +34 | 8 | −4 |
| 9 | 16 | +40 | 6 | −5 |

**Loop:** **MainMenu (boot)** → CutScene → StudentCard (approve roster) →
**Lobby (hub)** → AturJadwal (assign week) → StudentList → SchoolDay
(simulate 5 days) → ResultCheckup → back to Lobby. On the final week of a
grade, SchoolDay instead runs the end-of-grade sequence: **TesNotice →
ExamProgress → StatCheck → EndCutscene → RunResult → MainMenu.** Splashscreen and Loading still
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

`-REFERENCE-/prototype/` is the original prototype, kept for reference only —
not built, not imported. `koprasi&inventory` was a second programmer's separate
project; that project's spec
(`docs/superpowers/specs/2026-08-27-koperasi-inventory-integration-design.md`)
documents exactly which of its art is finished (copy byte-identical) versus
placeholder chrome (restyle onto our theme).

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
the Godot AI MCP `test_run` tool. 64 suites, 940 tests, all green
(2026-09-05).

Hard constraints, learned the hard way:

1. **The suite must be `@tool`** or the runner reports it abstract/broken.
2. **No test may be a coroutine.** The runner does `suite.call(name)` without
   awaiting — an `await` silently aborts the test mid-way, and it reports as
   "0 assertions".
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
needs a pass through Atur Jadwal first.

The overlay's **Scenes** tab also carries **🎭 Gladi Resik Akhir Kelas** —
three one-click rehearsals of the whole end-of-grade sequence (TesNotice →
ExamProgress → StatCheck → RunResult) with a fixed roster:
*Semua Lulus* (win path), *Semua Gagal* (lose path), and *Campur*, which
ladders 3/2/1/0 cleared targets across the four students so one pass of
StatCheck lights the meter 3, 2, 1 and 0 shares in turn (6 of 12 = 1.5
stars, a loss). Arming
one snapshots the run first; **↩ Pulihkan Run Sebelum Gladi Resik** puts it
back, which matters because RunResult's progression otherwise advances the
grade and clears the roster on its way out. The logic is in
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
serve a **stale** autoload otherwise. Scan first, or you will debug a phantom.

**A scan is not always enough.** When the `.gd` was edited from *outside*
the editor — any plain file write, including one from a subagent — the
editor can keep serving the old bytecode through a scan. A **no-op
`script_patch` on that same file** forces the reload — add and remove a
blank line. It logs a benign
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

**Tuning how something animates** goes through the `motion-lab` skill
(`.claude/skills/motion-lab/SKILL.md`), not edit-run-watch. It resolves the
element's current `Tween` preset, opens an in-browser easing editor whose
preview is sampled straight from the engine, and patches back a one-line
token you paste — faster than guessing a duration and replaying the scene.

## Outstanding debt & placeholders

Live, unfinished items. Delete an entry when it is resolved — do not mark it
done and leave it here.

**Audio placeholders.** Several `AudioDirector` cue ids alias existing streams
rather than having their own: `sfx_specialty_match` → `sfx_reward`; `tally` and
`sparkle` → existing SFX files; `star_earn_1/2/3`, `result_fanfare`,
`score_tick`, `combo_up` → `pop.ogg` / `reward.ogg`; and the BGM ids
`exam_notice`, `exam_cutscene`, `run_result` → existing tracks.

**Art placeholders.** The three particle sprites
(`Assets/Images/Particles/particle_*.png`) are crude flat geometry. The seven
minigame result icons and the report icons
(`Assets/Images/UI/Placeholders/icon_*.svg`) are flat white placeholder
geometry — real transparent SVGs, but not final art. The exam and win cutscene
backdrops reuse the intro's CG images.

**End cutscene art.** `EndCutscene`'s win backdrop is `cg2.jpg` standing in for
final art, and both badges (`stamp_lulus.svg`, `stamp_gagal.svg`) are generated
placeholder stamps. All four are `@export`s on `EndCutscene.tscn`, so swapping
them is an Inspector change. Note the badge words are drawn as stroked **paths**,
not SVG `<text>`: Godot rasterises SVG through ThorVG, which drops text elements
on import — `tests/test_end_cutscene.gd` guards that with a pixel check.

**Copy placeholders.** Every cutscene line in the exam and win branches is
marked `[PLACEHOLDER]`.

**Pending a balance pass.** `RunGrade`'s scoring weights — especially
`MONEY_FULL_MARKS` — are estimates. `LombaMenari.best_combo` is tracked but not
yet fed into the star rubric.

**Deferred: the AturJadwal shelf.** It ships as two `ColorRect`s rather than the
intended `ShelfEdge` theme variation. A new `@export` on `DesignTokens` is
invisible to a running editor, so this needs an editor restart plus a manual
rebake. The exact diff to re-apply is in the STATUS block of
`docs/superpowers/plans/2026-09-01-atur-jadwal-mockup.md`.

**Ratchet debt.** `tests/test_viewport_editability.gd`'s `BASELINE` still lists
real unconverted runtime UI construction across roughly 20 files. The
2026-08-31 pass converted every shared-across-screens case but did not survey
every remaining file. The list and what each would need is in the authoring
guide's "Known gaps" section.

No outstanding *bugs* as of 2026-08-31 — the 2026-08-30 stability sweep closed
the previous three. See `docs/superpowers/CHANGELOG.md`.

## Current work

Branch `Textures` (this is also the main branch).

The 2026-09-04 end-game rebuild replaced the whole tail of the flow
described above. **TesNotice → ExamProgress → StatCheck → EndCutscene →
RunResult → MainMenu** is now accurate. `WinScreen.tscn`/`.gd`, CutScene's
exam and game-over branches, and the `SemesterEnd` carousel with its
`ResultStatRow` template were all deleted outright; Plan C still
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

The 2026-09-05 pass added `EndCutscene` between StatCheck and RunResult —
one scene for both outcomes rather than a WinScreen/LoseScreen pair,
dressed from `GameState.run_failed`. It opens under an opaque white
overlay (finishing StatCheck's fade, which is why that hand-off bypasses
`Transition`), fades it out over a full-bleed backdrop, slams a
LULUS/GAGAL badge into the top-left with the same gesture RunResult uses
for its letter, then reveals a `Lanjut` button — the only way forward,
disabled until the badge lands. Backdrops, badges, BGM ids and all three
pacing durations are `@export`s on the scene.

Everything completed before this is in `docs/superpowers/CHANGELOG.md`.

## Maintaining this file

This file is injected into every session before the user speaks. Everything in
it costs context on every single run, so it earns its place or it moves.

- A **completed pass** gets an entry in `docs/superpowers/CHANGELOG.md`, newest
  first — not a paragraph here.
- A fact that **changes how you work on the project** goes in the topical
  section it governs, not in `## Current work`.
- An **unfinished placeholder or deferred item** goes in `## Outstanding debt &
  placeholders`, and is deleted when resolved.
- `## Current work` holds **only what is in flight right now**. When it lands,
  it moves to the changelog.
- Soft budget: keep this file under **20,000 characters**. It was 27,547 on
  2026-09-05, of which 39% was completed-pass narrative.

Rationale and the full restructure record:
`docs/superpowers/specs/2026-09-05-project-guide-restructure-and-memory-seeding-design.md`.

## Conventions

- Game-facing identifiers and all UI text are **Indonesian**; engine and systems code
  is English. Match whatever the surrounding file does.
- File naming is inconsistent (`loby.gd`, `koprasi.gd` are misspelled but
  load-bearing — do not "fix" them).
- Commits: Conventional Commits with a scope, e.g.
  `fix(lobby): wire the dead ReportStudent button`.
- Tunable gameplay numbers belong in a named `const` block or an `@export`,
  not inline. See `StudentManager.gd`'s `WIRAUSAHA_*` block.
- **`Balance.gd` values are owned by a collaborator, not by us.** Read them
  freely; never change them. If a task appears to need a different value, say
  so and propose it rather than editing. On merge, take their version of that
  file.
- **No emoji as UI iconography.** Use real transparent SVG textures instead —
  explicitly banned during the 2026-09-02 end-of-grade pass after report icons
  briefly used emoji glyphs.
