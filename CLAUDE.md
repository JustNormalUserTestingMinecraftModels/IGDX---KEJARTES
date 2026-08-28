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

**Loop:** Splashscreen → Loading → MainMenu → CutScene → StudentCard (approve
roster) → **Lobby (hub)** → AturJadwal (assign week) → StudentList → SchoolDay
(simulate 5 days) → ResultCheckup → back to Lobby, or SemesterEnd on the final
week.

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

**Two animation APIs, both live:**
- `Scripts/Design/Juice.gd` — the project's own (`press`, `release`, `pop_in`,
  `stagger_in`, `count_up`, `fill_bar`, `shake`). Buttons get press/release
  wired automatically by `UIPolish`; opt out with
  `node.set_meta(Juice.NO_AUTO_JUICE, true)`.
- `Scripts/AnimUtils.gd` — came in with the ported shop/inventory
  (`squash_bounce`, `popup_spring_in/out`, `coin_pulse`, `create_floating_text`,
  …). It is a plain static-function script, **not** an autoload.

Minigames (`Scenes/Minigames/**`) are explicitly **out of scope** for the
design system — they inherit the Theme but had no polish pass.

## Testing

Suites live in `tests/test_*.gd`, extend `McpTestSuite`
(`addons/godot_ai/testing/test_suite.gd`), and run **inside the editor** via
the Godot AI MCP `test_run` tool. 22 suites, 281 tests.

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
/ SemesterEnd / Splashscreen. Seed, teleport, screenshot once. Driving the
shop purchase flow by simulated clicks to reach the same state took roughly
forty-five calls and failed twice before working.

When you do have to click, note two quirks. Send a `motion` event to the
target before the `button` press — Godot will not route a click without the
hover state first, and a bare press/release pair silently does nothing.
And rescale coordinates: the design space is 1080x1922 but the window is
smaller, so window coords are roughly `global * 0.354`. Read the target's
`global_rect` rather than eyeballing a screenshot.

**2. Scope every `get_ui_elements` call.** Called bare it serialises the whole
tree — the debug overlay alone returns 58 verbose nodes. Always pass
`root_path` and a shallow `max_depth`:

    game_manage(op="get_ui_elements",
                params={"root_path": "/root/Inventory/MainLayout", "max_depth": 3})

Note the runtime path quirk: autoloads answer to `/root/<Name>` (e.g.
`/root/DebugManager`) but the reply echoes paths relative to the current
scene (`/Inventory/../DebugManager`). Bare `/root` returns nothing.

**3. Prefer `test_run` over screenshots.** The whole suite — 281 tests, 22
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

Two smaller habits: grep before reading (several scripts here exceed 1,500
lines — read the range you need, not the file), and read `logs_read(source="editor")`
for parse errors, since boot-time failures never reach the game log.

**The Godot MCP bridge is single-client.** Only one client can hold the
backend at a time. If you delegate to subagents, they cannot run the editor:
a subagent that connects displaces your session and gets nothing itself, and
both then see "A different Godot AI backend is already running". Recovery is
`taskkill` on the stray `godot-ai.exe` processes, leaving `Godot_v*.exe`
alone. So: subagents write code, you run the editor and hand them the results.

None of this trades away test coverage. Coverage is the quality floor; the
savings come from cheaper verification loops, not from fewer tests.

## Known issues (as of 2026-08-28)

1. **`tests/test_audio_director.gd:108` `test_volumes_persist_across_a_fresh_director`
   is a coroutine** — it `await`s, so the runner abandons it before the
   restore on line 122 runs. Two consequences: it always reports "0
   assertions" as a failure, **and it leaves `Assets/Audio/default_bus_layout.tres`
   dirty** (BGM at 0.42 linear = −7.535 dB). If you see that file modified
   with no audio work done, this test did it — `git checkout` it.
2. **`test_audio_coverage.gd` double-SFX failure** — six functions fire two
   cues on one path with no `await` between: `inventory.gd` `_on_use_pressed`,
   `_on_popup_cancel_pressed`, `_on_popup_ok_pressed`; `koprasi.gd`
   `_on_rak1_pressed`, `_on_back_pressed`; `SchoolDay.gd` `_on_week_complete`.
   All are in the ported shop/inventory code and the Wirausaha payout — real,
   introduced by the current branch.
3. Stale `ext_resource` UIDs in `student_list.tscn` and `loading.tscn` log
   warnings; Godot falls back to text paths and loads fine. Documented in
   `docs/superpowers/baseline/known-errors.md` — not a regression.

## Current work

Branch `feat/koperasi-inventory-integration` (main branch is `Textures`).

Spec: `docs/superpowers/specs/2026-08-27-koperasi-inventory-integration-design.md`
Plan: `docs/superpowers/plans/2026-08-27-koperasi-inventory-integration.md`
(17 tasks; **the checkboxes are never ticked — git log is the real record**).

Tasks 1–16 are committed. **Task 17** (wire the ReportCard lobby button) has
its code and test written but uncommitted, and still needs plan Step 4 (full
suite — done, see Known Issues) and Step 5 (manual pass in the running app).

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
