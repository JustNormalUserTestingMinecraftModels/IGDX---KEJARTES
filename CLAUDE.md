# KejarTes — Project Guide

Godot **4.6** mobile game (portrait 1080×1920, `mobile` renderer, d3d12).
Indonesian-language school-management sim. Main scene:
`Scenes/Splashscreen/Splashscreen.tscn`.

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
(simulate 5 days) → ResultCheckup → back to Lobby, or SemesterEnd on the final
week. Splashscreen and Loading still exist and are still tested, but since
2026-08-31 they are no longer reached at boot.

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
the Godot AI MCP `test_run` tool. 29 suites, 425 tests, all green.

Hard constraints, learned the hard way:

1. **The suite must be `@tool`** or the runner reports it abstract/broken.
2. **No test may be a coroutine.** The runner does `suite.call(name)` without
   awaiting — an `await` silently aborts the test mid-way, and it reports as
   "0 assertions". (See Known Issues.)
3. Scripts the runner instantiates live must be `@tool` too, with real side
   effects in `_ready()` gated behind `if Engine.is_editor_hint(): return`.
   Pure signal wiring stays ungated so tests can exercise it.
4. Some suites assume the **main scene is open** in the editor; `test_run`
   returns a `scene_warning` when it isn't. Open
   `Scenes/Splashscreen/Splashscreen.tscn` before trusting a failure.

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
project. Four rules, in order of how much they save:

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

**3. Prefer `test_run` over screenshots.** The whole suite — 425 tests, 29
suites — returns a compact JSON summary in about two seconds. One screenshot
costs more tokens than the entire run. Reach for a screenshot only to judge
something genuinely visual (layout, spacing, color); use `test_run` for
anything about behaviour or wiring. Many suites here are deliberately
source-text scans (`src.contains(...)`) precisely because they are cheap and
do not need the scene instantiated.

**4. Rescan after editing a `.gd`, before running tests.** `test_run` will
serve a **stale** autoload otherwise. Three tests once failed with
"Nonexistent function 'seed_playtest_inventory'" while that function sat
committed on disk; one `filesystem_manage(op="scan")` turned the same run into
20/20. Scan first, or you will debug a phantom.

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

The main menu was rebuilt on 2026-08-31 to match
`docs/superpowers/mockups/main-menu.png` measurement-for-measurement and is
now the boot scene — see
`docs/superpowers/specs/2026-08-31-main-menu-mockup.md` for the probe trail
and the two documented deviations (uniform 66 px button separation, and font
size 80 rather than the mockup-implied 100 so "PENGATURAN" fits).

The 2026-08-30 stability sweep
(`docs/superpowers/plans/2026-08-30-project-stability-sweep.md`) is complete.

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
