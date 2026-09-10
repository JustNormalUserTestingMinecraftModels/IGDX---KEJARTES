# KejarTes — Project Guide

Godot **4.6** mobile game, portrait 1080×1920, `mobile` renderer, Vulkan
(older plan docs say `d3d12` — that pin was removed 2026-09-07).
Indonesian-language school-management sim. Main scene:
`Scenes/MainMenu/main_menu.tscn`.

## The game

You play a teacher. Approve a roster, assign each student a daily activity for
the school week, then watch the week simulate: stats move, minigames and random
events fire, and a report lands at week's end. Clear two-thirds of the roster's
academic targets — `run_stars() >= 2.0` of 3.0 — before the grade's final week
to pass. It is a roster-wide fraction, not a per-student gate: three students
clearing everything while a fourth clears nothing is 9 of 12 = 2.25 stars, and
passes.

**Grades scale the whole game** (`GameState.current_grade`, 7–9):

| Grade | Weeks | Target uplift | Minigame win stat | Loss penalty |
|---|---|---|---|---|
| 7 | 6 | +15 | 10 | −3 |
| 8 | 12 | +34 | 8 | −4 |
| 9 | 16 | +40 | 6 | −5 |

**Loop:** **MainMenu (boot)** → CutScene → StudentCard (approve roster) →
**Lobby (hub)** → AturJadwal (assign week) → StudentList → SchoolDay (simulate
5 days) → ResultCheckup → Lobby. On a grade's final week SchoolDay instead runs
**TesNotice → ExamProgress → StatCheck → EndCutscene → RunResult → MainMenu**.
Splashscreen and Loading still exist and are tested but are no longer reached at
all: CutScene and Splashscreen went through `Transition` on 2026-09-10, so
nothing routes to Loading any more. **Lobby hub** → StudentCard, AturJadwal, ShopHub, Inventory, ReportCard;
**ShopHub** forks to Koperasi (items) or CosmeticShop (a stub), both returning
to the hub rather than the Lobby.

### Stats & activities

Every student has three skills (`akademis`, `seni_budaya`, `olahraga`) and two
needs (`energy`, `mood`), all 0–100. Five schedule categories:

- `Akademis` / `SeniBudaya` / `Olahraga` — gain that skill, cost energy+mood.
- `Istirahat` — recover energy+mood, no skill gain.
- `Wirausaha` — no skill gain; earns money at a higher mood/energy cost, accrued
  into `GameState.pending_earnings` and paid out at week end.

Costs scale by `get_category_efficiency_multiplier()`: 0.6× for the student's
specialty, 0.85× for `Seimbang`, 1.20× otherwise. A student at energy ≤ 5
auto-takes "Izin" (forced Istirahat).

**Personalities** (`Aktif`/`Tekun`/`Kreatif`/`Santai`/`Seni Dalam Kesunyian`)
drive daily decay rates; **quirks** (`Kutu Buku`, `Penyendiri`, `Semangat
Juang`, `Penasaran`, `Biang Onar`, `Pekerja Keras`) modify gains and costs.
Every coefficient is an `@export` on `StudentData.gd` — tune in the Inspector,
never hardcode.

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

Persistence is minimal and deliberate: **only `GameState.inventory`** reaches
disk (`user://inventory.cfg`, flushed at the top of every
`Transition.change_scene`, loaded in `GameState._ready`). Roster, money, week,
grade and schedules are session-scoped by design. **Do not add further
persistence without being asked.** Item boosts land on `approved_students`,
which is not persisted, so a boost applied and not simulated before quit is
lost. Debug > General > **🧹 Forget Session** wipes `GameState` and deletes the
save; the three `*_inventory` functions no-op under `Engine.is_editor_hint()`.

`-REFERENCE-/prototype/` is the original prototype — reference only, not built,
not imported.

## Visual system — read this before touching any UI

Everything flows from `Assets/Theme/design_tokens.tres` (a `DesignTokens`
resource). To change a color/radius/font globally: edit that resource, then
**rebake** by running `Scripts/Design/BakeTheme.gd` via File > Run
(Ctrl+Shift+X), which writes `Assets/Theme/kejartes_theme.tres`.

Two faces: **Boohong** (`font_display`) for headings, titles, buttons and
badges; **Open Sans Medium** (`font_body`) for everything else, as the
theme's `default_font`. Which variation gets which is pinned in both
directions by `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` — change
the roster and `ThemeFactory` together, or the suite fails.

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
the Godot AI MCP `test_run` tool. 91 suites, 1258 tests (2026-09-10).

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

5. **The suite cannot be run headless.** Proven on 2026-09-09: `--script`
   registers no autoloads, and running a *scene* makes `Engine.is_editor_hint()`
   false so every `@tool` guard fires its real side effects (~143 failures).
   The bridge is the only real way. Details in the changelog.

**A full `test_run` writes two tracked files.** The `theme_rebake` suite calls
`ResourceSaver.save()` in-process, so a full run rebakes
`Assets/Theme/kejartes_theme.tres` — in the editor that is usually what you
want (it picks up token edits), but it means a "clean" tree can go dirty just
from running tests. `AudioDirector` rewrites `default_bus_layout.tres` on boot.
Check `git status` after a full run and `git checkout --` whichever you did not
intend. Suite order matters too: a suite that reads the baked theme before
`theme_rebake` runs sees the *old* bake, so a single failing theme assertion in
a full run may just be ordering — re-run that suite alone before believing it.

Many tests are **source-text scans** (`src.contains(...)`) rather than
behavioral, because a lot of the UI can't be instantiated headlessly. Follow
that pattern where it's established. Note what that buys and what it does not:
a scan asserts the value you *set*, so it can confirm you changed what you
meant to and can never tell you that you changed the wrong things.

## Godot MCP

The `godot-ai` MCP server drives the live editor: `test_run`, `scene_open`,
`scene_get_hierarchy`, `node_*`, `script_patch`, `project_run`,
`editor_screenshot`, `logs_read`. Prefer these over shelling out.

If a session fails to attach with *"A different Godot AI backend is already
running"*, stray `godot-ai.exe` processes hold the port — `tasklist | grep -i
godot-ai`, kill those, leave `Godot_v*.exe` alone. If instead
`session_manage(op="list")` returns `count=0` while the server answers, the
*editor* dropped its side and only restarting the editor fixes it.

`logs_read(source="editor")` catches parse errors that never reach the game
log; `source="game"` misses boot-time failures entirely.

`scene_open` on `Scenes/SchoolSimulation/BookClockWidget.tscn` hangs the
editor — the call times out, the MCP transport write-pauses, the plugin
disconnects, and the editor needs a restart. Cause unconfirmed; verify that
widget via `project_run` instead, which exercises it fine.

## Working efficiently here

Verification, not implementation, dominates the cost of a session here.

**1. Never play the game to reach a state — seed it.** Debug overlay (`F1`, or
5 taps top-right) → General → **⚡ Seed Playtest State**: roster approved,
999999G, full inventory, lobby tutorial bypassed. Its **Scenes** tab teleports
to MainMenu / Lobby / StudentCard / AturJadwal / SchoolDay / SemesterEnd /
Splashscreen. Seed, teleport, screenshot once. The seed does **not** fill
`day_schedules`, so schedule-driven screens (SchoolDay, AturJadwal) still need
a pass through Atur Jadwal first.

That tab also carries **🎭 Gladi Resik Akhir Kelas** — one-click rehearsals of
the whole end-of-grade sequence with a fixed roster: *Semua Lulus*, *Semua
Gagal*, and *Campur*, which ladders 3/2/1/0 cleared targets so one pass of
StatCheck lights the meter 3, 2, 1 and 0 shares in turn (6 of 12 = 1.5 stars, a
loss). Arming one snapshots the run; **↩ Pulihkan Run Sebelum Gladi Resik**
restores it, which matters because RunResult otherwise advances the grade and
clears the roster on its way out. Logic lives in
`Scripts/Debug/EndGameRehearsal.gd`, tested in
`tests/test_end_game_rehearsal.gd`; `DebugManager.gd` only holds the buttons.

**Clicking, when you must.** Send a `motion` event to the target before the
`button` press — Godot will not route a click without the hover state first,
and a bare press/release pair silently does nothing. Rescale coordinates:
`global_rect` is in the 1080-wide design space while input events take window
pixels, and `editor_screenshot` reports the real size as `original_width`, so
`window_x = global_x * original_width / 1080`. Read the target's `global_rect`
rather than eyeballing a screenshot — and re-read it after any window resize.

**2. Scope every `get_ui_elements` call.** Bare, it serialises the whole tree
(the debug overlay alone is 58 verbose nodes). Always pass `root_path` and a
shallow `max_depth`:

    game_manage(op="get_ui_elements",
                params={"root_path": "/root/Inventory/MainLayout", "max_depth": 3})

Autoloads answer to `/root/<Name>` but the reply echoes scene-relative paths
(`/Inventory/../DebugManager`). Bare `/root` returns nothing.

**3. Prefer `test_run` over screenshots.** The whole suite returns compact JSON
in seconds; one screenshot costs more tokens than the entire run. Reach for a
screenshot only to judge something genuinely visual — and when you do, judge it
at full size. A scaled-down capture cannot show 1px detail, spacing or weight,
and signing off a visual change from one is how the 2026-09-10 cream pass
shipped a half-finished layout.

**4. Never hand-edit a `.tscn` while the editor is attached.** Its in-memory
copy wins and the next `scene_save` silently overwrites your text edit — `scan`,
`reimport` and even `scene_open(force_reload=true)` all fail to evict it. Go
through the editor: `scene_open` → `node_create` / `node_set_property` /
`node_manage` → `scene_save`. `batch_execute` takes the plugin command names
(`create_node`, `set_property`, `move_node`, `delete_node`) and does a whole
node in one call. Gotchas: `anchors_preset` is inert (set the four anchors),
numbers must be unquoted (`1`, not `"1.0"`), `node_create` appends last so
z-order needs `move_node`, and a node's *type* can only be changed by
delete-and-recreate. A `Control` created under a plain `Control` starts in
position mode, where anchors are **not saved** — set `layout_mode = 1` first;
and an instanced scene's root loses its rect on load under a plain `Control`,
so draw from a child (authoring guide, Pattern C).

**4b. Two save hazards that silently eat work.**

- *`scene_save` flushes stale script buffers.* The editor holds `.gd` files
  open in script tabs and writes every tab back on each scene save, over
  whatever you patched; `script_patch` does not protect you. Do **scene work
  first, script work second**; after any `scene_save` check
  `git diff HEAD -- '*.gd'` for files you were not editing; and once you have
  patched a script, restart the editor before the next `scene_save` — a
  force-kill is safe once scenes are saved, and the relaunch reloads every tab
  from disk (2026-09-10: skipping it reverted `BuatBatik.gd`).
- *Overrides serialise only on an instanced scene's ROOT.* Properties set on an
  instance's **children** report success and are dropped on save. Give the
  sub-scene `@export`s on its root instead — why `ShopHubTile` carries
  `icon_texture`/`caption_text` rather than the hub reaching into
  `Content/Icon`, and why `ActivityRow` carries `watermark_texture`.

**5. Rescan after editing a `.gd`, before running tests.** `test_run` serves a
**stale** autoload otherwise. A scan is not always enough: when the file was
edited from *outside* the editor (any plain write, including a subagent's), a
**no-op `script_patch` on that same file** forces the reload — it logs a benign
`GDScript reload failed with error code 43` and then works. Cheapest reliable
fix: make edits through `script_patch` in the first place. It matches bytes
exactly: on a CRLF file a multi-line anchor misses, so normalise the file to LF
first (git stores LF either way, `* text=auto eol=lf`).

**Editing a `class_name` script breaks the next game run.** After patching
`DesignTokens.gd` or similar, `project_run` fails with *Could not find script
for class* until you `project_manage(op="stop")`, `filesystem_manage(op="scan")`
and relaunch. Worse, a **changed default on a Resource `@export` needs a full
editor restart** — `load_default()` keeps serving the cached instance, so the
new value silently does not take effect and a test asserting it fails for no
visible reason. Same for a **new** `@export`. This is why the theme rebake has
no headless path.

**Rebaking without File > Run.** `Scripts/Design/BakeTheme.gd` is an
`EditorScript` with no MCP entry point. Write a transient `@tool`
`McpTestSuite` into `res://tests/` whose one test does `ThemeFactory.build()`
plus `ResourceSaver.save()`, run it with `test_run`, then delete it.

**The bridge is single-client.** Only one client holds the backend at a time. A
subagent that connects displaces your session and gets nothing itself, and both
then see "A different Godot AI backend is already running". Recovery is
`taskkill` on stray `godot-ai.exe` processes, leaving `Godot_v*.exe` alone. So:
subagents write code, you run the editor and hand them the results.

**A full `test_run` drops the bridge.** Observed four times on 2026-09-10, each
immediately after a full run and never after a targeted one. The first
explanation was memory pressure — the machine had ~1 GB free of 16 GB — but the
fourth drop happened with **8.9 GB free**, which rules that out. What is left is
duration: a full run is 15-20s of near-continuous main-thread work, and the
plugin's transport does not survive it (the `test_run` docs warn that a single
test blocking for 20s+ can drop the session).

So: **prefer targeted `test_run(suite=...)`** — milliseconds, never dropped.
Budget one editor restart for each full run you take, and take them at
milestones rather than between tasks. A full run's results are still valid when
the drop happens after the reply arrives; check `git status` afterwards, because
a full run also rewrites the two tracked files noted under `## Testing`.

One smaller habit: grep before reading — the two largest scripts here exceed
1,500 lines, so read the range you need, not the file.

**Tuning how something animates** goes through the `motion-lab` skill
(`.claude/skills/motion-lab/SKILL.md`), not edit-run-watch.

None of this trades away test coverage. Coverage is the quality floor; the
savings come from cheaper verification loops, not from fewer tests.

## Outstanding debt & placeholders

Live, unfinished items. Delete an entry when it is resolved — do not mark it
done and leave it here.

**Generated placeholder art.** Produced with PowerShell + `System.Drawing`, not
hand-authored. All are transparent PNG/SVG, drop-replaceable at the same path
with no code change: the five `Assets/Images/UI/Nav/` icons,
`Assets/Images/StudentCard/menu_button.png`, three `Particles/particle_*.png`, the minigame
result + report icons and `icon_benefit`/`icon_cost`/`icon_tired`/`icon_check`
(`UI/Placeholders/`), `icon_shop_items`/`icon_shop_cosmetics` (`Shop/UI/`), the
event-popup set (`icon_event_*`, `bg_event_*`, `particle_burst.png`),
`shadow_ellipse.png`, `bg_inventory_blur.png`, four `icon_filter_*.svg`,
`EndCutscene`'s two badges, the eight `BarFill/fill_*` motif tiles, and the
2026-09-10 cream-pass assets (`penjadwalan_card_bg.png`,
`Assets/Images/UI/BarFill/track_ghost.png`, `icon_ghost_koin.png`, `icon_ghost_sabit.png`).

Three carry constraints a replacement **must** honour:

- The `fill_*` tiles and `track_ghost.png` — rules in
  `Assets/Images/UI/BarFill/README.md`, enforced by `tests/test_bar_contrast.gd`
  and `tests/test_ghost_track.gd`.
- `penjadwalan_card_bg.png` must stay exactly 1080x1080; two call sites address
  it with hardcoded `region_rect`s.
- `EndCutscene`'s badge words are stroked **paths**, not SVG `<text>` — Godot
  rasterises SVG through ThorVG, which drops text elements on import.
  `tests/test_end_cutscene.gd` guards this with a pixel check.

**Stray layer in the day-transition sky (2026-09-10).**
`Assets/Images/SchoolDay/transition_background.png` has a bluish night street
scene pasted into its bottom-left corner (texture space roughly x 0..375,
y 1833..2047) that should be erased at source. It sits outside the texture's
inscribed circle — `BookClockWidget.gd`'s `_fit_layers()` makes the visible
radius exactly `1024 / sky_cover_margin` regardless of pivot or screen size,
and the artifact sits at radius ~1041, so any `sky_cover_margin` at or above
1.0 keeps it off screen. Do not "fix" it by lowering that margin.

**Audio placeholders.** These `AudioDirector` cue ids alias existing streams:
`sfx_specialty_match`, `tally`, `sparkle`, `star_earn_1/2/3`, `result_fanfare`,
`score_tick`, `combo_up`, `sfx_event_announce`, and the BGM ids `exam_notice`,
`exam_cutscene`, `run_result`. `ApplyItemScreen`'s payoff likewise reuses
existing cues rather than a dedicated `sfx_item_apply`.

**Copy placeholders.** Every cutscene line in the exam and win branches, and
every `desc` string in `ItemDatabase.DEFAULT_ITEMS` (shown verbatim in
`ItemDetailSheet`), is marked `[PLACEHOLDER]`.

**Other art gaps.** `EndCutscene`'s lose backdrop is `cg_lose.jpg` standing in
for final art (an `@export`, so an Inspector swap). `InventorySlot`'s high-count
`Shine` overlay is a plain white `ColorRect` with no texture.

**Emoji as iconography on the stat popup.** `Scripts/UI/StatDetailPopup.gd`
falls back to `info["glyph"]` from `StatInfo`, and those glyphs are emoji, which
the ban in `## Conventions` forbids. The trait popup was fixed the same way on
2026-09-09 — real textures plus a display-font heading; this wants the same.

**Pending a balance pass.** `RunGrade`'s scoring weights (especially
`MONEY_FULL_MARKS`) are estimates; `LombaMenari.best_combo` is tracked but not
fed into the star rubric; the item skill-boost values in
`ItemDatabase.DEFAULT_ITEMS` (3–8) are untested against
`tests/test_balance_pacing.gd`. `RunGrade.LETTER_BANDS`' five rank
floors (S 90 / A 75 / B 60 / C 45) are estimates set when the scheme collapsed
from ten +/- bands on 2026-09-10, never played against a real run.

**Cosmetic shop is a stub.** `Scenes/Koperasi/CosmeticShop.tscn` is a blurred
backdrop, a "Segera Hadir" line and a back button. The shop hub's second tile
has to lead somewhere; nothing behind it is designed.

**Dead scenes.** `Scenes/EndGame/WinScreen.tscn` is orphaned scaffolding — root
unscripted, nothing references it. The real win screen is `EndCutscene`'s win
branch. Safe to delete. `Scenes/Loading/loading.tscn` joined it on 2026-09-10 —
kept deliberately, unwired, against a future scene slow enough to need a real
threaded-load screen. Its script and `GameState.next_scene` are intact and
`tests/test_boot_screens.gd` still covers them, but no call site reaches it, so
nothing proves it still works in a running game.

**Three orphaned tokens (2026-09-10).** `preview_row_shadow_color`, `_size` and
`_offset` are read by no variation since `PreviewRow` lost its shadow. Remove
them deliberately, or give them a consumer.

**Deferred: the AturJadwal shelf.** Ships as two `ColorRect`s rather than a
`ShelfEdge` variation. Needs an editor restart plus a manual rebake (a new
`@export` on `DesignTokens` is invisible to a running editor). The exact diff is
in the STATUS block of
`docs/superpowers/plans/2026-09-01-atur-jadwal-mockup.md`.

**Deferred: blinking on the layered faces.** `CitraFace.tscn`'s `Eyelid` layer
and `StudentFace.blink()` are wired and tested, but `idle_blink_enabled`
defaults **false** — held back deliberately. A real pass wants a half-lid frame
(the art has none) or an alpha/scale ease rather than the current hard cut.

**Layered faces exist for Citra only.** The other four use the flat portrait.
Adding one means a new `<Name>Face.tscn` with that character's own solved layer
offsets, dropped into `loby.gd`'s `face_rigs`.

**Ratchet debt.** `tests/test_viewport_editability.gd`'s `BASELINE` still lists
real unconverted runtime UI construction across roughly 20 files. The list, and
what each would need, is in the authoring guide's "Known gaps" section.

## Current work

Branch `feat/asset-refresh-ui-pass`, off `Textures` (main), with `Textures`
merged back into it on 2026-09-10. The asset refresh and UI pass is complete
and pushed, not yet merged; the minigame, sky and paper fixes are committed on
top, not yet pushed. See `docs/superpowers/CHANGELOG.md`.

Open: Plan C's RunResult redesign,
`docs/superpowers/plans/2026-09-04-endgame-c-run-result.md` — but that pass
already replaced RunResult's grade letter with five rank badges and fixed its
win backdrop, so re-read the plan against the current screen before acting.

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
- **Group placeholders, do not list them.** A dozen entries each saying "X is
  generated `System.Drawing` art, drop-replaceable" is one entry with a path
  list. Keep the prose only for the ones carrying a real constraint.
- **Point at the README, do not restate it.** If a folder README or a
  spec already documents the rules for an asset, link it and keep one line.
- Soft budget: **20,000 characters**. History: 27,547 on 2026-09-05 (39%
  completed-pass narrative), 30,936 on 2026-09-10, 24,000 after that day's
  audit. The 2026-09-10 pass could not reach 20k without deleting live
  operational rules — if it must come down further, the honest lever is moving
  `## Outstanding debt` to its own file, not thinning the rules.

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
