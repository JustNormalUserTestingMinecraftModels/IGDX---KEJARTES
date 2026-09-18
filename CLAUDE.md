# KejarTes — Project Guide

Godot **4.6** mobile game, portrait 1080×1920, `mobile` renderer, Vulkan.
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
Every mid-day minigame and random event opens with the sliding EventWarning,
then an EventDialogue line (`EventDialogueCatalog`); the three pick-students
events ask Tolak / Terima there, before their picker. Settings' **Lewati Dialog
Minigame** toggle (`GameSettings.skip_event_dialogue`, saved; the Lobby's gear
opens Settings) skips the minigame lines;
Nasi Kotak, Hujan and the choice events keep theirs.
Splashscreen still exists and is tested but nothing routes to it (the game
boots straight to MainMenu, which loads in one hop). There is no Loading
screen: the shared `Transition` wipe covers the scene-load gap.
All navigation is a single `Transition.change_scene(target, …)`. **Lobby
hub** → StudentCard, AturJadwal, ShopHub, Inventory, ReportCard;
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
Their coefficients are `static var`s in `Balance.gd` (`DECAY_*`, `SIFAT_*`),
read-only for us.

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
| `Achievements`, `AchievementToast` | Achievement tracker (saved), prize multipliers, unlock banner. |
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
and `DayOff`→`Istirahat`. Student art goes through `StudentSkins`
(`splash_for`/`portrait_for`/`face_base_for`/`hand_for`), never the dict's
`splash`/`portrait` keys, so the worn skin (`GameState.equipped_skins`) shows.

Persistence is minimal and deliberate: **only `GameState.inventory`** reaches
disk (`user://inventory.cfg`, flushed at the top of every
`Transition.change_scene`, loaded in `GameState._ready`), plus achievement
progress (`user://achievements.cfg`, saved by `Achievements` on every change,
but wiped on every launch while the debug `Achievements.RESET_ON_LAUNCH` is on). Roster, money, week,
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
`SuccessButton`, `LobbyCtaButton`, `Card`, `SunkenPanel`, `Scrim`,
`DisplayLabel`, `H1Label`, `H2Label`, `TitleLabel`, `CaptionLabel`,
`MicroLabel`, `BarLabel`, `StatBar`, …). If none fits, add a new variation in
`ThemeFactory.gd` and rebake. Only accepted exception: layout-only constant
overrides (`separation`, `margin_*`).

Full detail: `docs/superpowers/design/style-guide.md`.

**The second rule: no visual is built at runtime.** Static chrome is a node in
the `.tscn`; repeated rows are a `PackedScene` template; responsive geometry
is a `@tool` script driven by documented `@export` knobs. Every script's
documentation (a `##` file header, a `##` line on every `@export`) is a hard
rule (`tests/test_script_documentation.gd`). Runtime visual construction is
still a ratchet (`tests/test_viewport_editability.gd`): a `BASELINE` dict of
real remaining debt, frozen and only ever lowered, plus an `ALLOWED` dict of
reviewed, commented, permanent exceptions (per-call-dynamic content, or a
conditional texture-vs-procedural swap) — see the authoring guide's "Known
gaps" section.

Full detail: `docs/superpowers/design/authoring-guide.md`.

**The third rule: every screen fills any phone.** A 20:9 phone runs the game
at 1080×2400 (`aspect="expand"`); the editor's embedded run is locked to
9:16 and never shows it. Backgrounds are Full Rect + Keep Aspect Covered; UI
is re-anchored to its edge inside `SafeAreaMargin` → `UI`; a picture and its
items move as one piece. Pinned by `tests/test_tall_screen_layout.gd`; how-to
in the authoring guide's "Tall phones".

**Cards.** Build a new card on a `Sheet` Panel with the `Card` variation
(StudentList's `RosterCard`). Use `paper.png` only where its cut corner is
the point: it is opaque over only the middle of its rect (numbers in
`docs/superpowers/DEBT.md`). Measure the
alpha before laying out on any soft-edged texture.

**Asset constraints.** Placeholder art is drop-replaceable at the same path
(inventory in `docs/superpowers/DEBT.md`), but a replacement **must** honour:

- `fill_*` tiles and `track_ghost.png`: the rules in
  `Assets/Images/UI/BarFill/README.md`. `tests/test_bar_contrast.gd` checks
  the luminance floor, `tests/test_ghost_track.gd` the ghost track; nothing
  tests the tile period.
- `penjadwalan_card_bg.png` stays exactly 1080x1080: `atur_jadwal.tscn`'s
  Peringatan dialog crops it with a hardcoded `region_rect` that
  `tests/test_atur_jadwal.gd` pins.
- `EndCutscene`'s badge words are stroked **paths**, not SVG `<text>`, which
  ThorVG drops on import; `tests/test_end_cutscene.gd` pixel-checks them.
- `tray_dots.png` stays 26x26 (`tests/test_koperasi_tray.gd`); it tiles via
  the node's `texture_repeat`, not an import flag.
- `transition_background.png` has a stray layer that any `sky_cover_margin`
  at or above 1.0 keeps off screen. Do not "fix" it by lowering that margin.

**Two animation APIs, both live:**
- `Scripts/Design/Juice.gd` — the project's own (`press`, `release`, `pop_in`,
  `stagger_in`, `count_up`, `fill_bar`, `shake`). Buttons get press/release
  wired automatically by `UIPolish`; opt out with
  `node.set_meta(Juice.NO_AUTO_JUICE, true)`.
- `Scripts/AnimUtils.gd` (`squash_bounce`, `popup_spring_in/out`,
  `coin_pulse`, `create_floating_text`, …). It is a plain
  static-function script, **not** an autoload.

Minigames (`Scenes/Minigames/**`) and the debug overlay
(`Scripts/Debug/DebugManager.gd`) are explicitly **out of scope** for the
design system — minigames inherit the Theme but had no polish pass, and the
overlay is a programmatic developer tool that styles itself directly.

## Testing

Suites live in `tests/test_*.gd`, extend `McpTestSuite`
(`addons/godot_ai/testing/test_suite.gd`), and run **inside the editor** via
the Godot AI MCP `test_run` tool. 136 suites, 1919 tests (2026-09-18).

Hard constraints:

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
   The bridge is the only real way. Details in commit `39a1b9b`'s message.

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

## Pull requests

**Finish a branch with the `ship-pr` skill** (`.claude/skills/ship-pr/SKILL.md`;
design in `docs/superpowers/specs/2026-09-11-pr-automation-design.md`): it runs
the full suite and a local review, opens the PR and stamps the tested commit.
`ci/auto_merge.sh` then merges **only `brineoutxd`'s PRs into `Textures`**,
and only when every gate is green on a commit that already contains
`Textures`. Label a PR `hold`, or leave it a draft, to stop it; anyone can
still merge by hand, and must for a PR that changes `.github/workflows/`
(GitHub's workflow token cannot merge those). A stamp belongs to one commit:
never post one for a commit the suite did not run on.

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

## Working efficiently here

Verification, not implementation, dominates the cost of a session here.

**1. Never play the game to reach a state — seed it.** Debug overlay (`F1`, or
5 taps top-right) → General → **⚡ Seed Playtest State**: roster approved,
999999G, full inventory, lobby tutorial bypassed. Its **Scenes** tab teleports
to MainMenu / Lobby / StudentCard / AturJadwal / SchoolDay / SemesterEnd /
Splashscreen. Seed, teleport, screenshot once. The seed does **not** fill
`day_schedules`, so schedule-driven screens (SchoolDay, AturJadwal) still need
a pass through Atur Jadwal first. The weekly report needs neither: the Scenes
tab's **📊 Laporan Mingguan** opens ResultCheckup over the current screen with
a fixed sample week, leaving the run untouched.

That tab also carries **🎭 Gladi Resik Akhir Kelas**: one-click rehearsals of
the end-of-grade sequence with a fixed roster (*Semua Lulus*, *Semua Gagal*,
and *Campur*, which ladders 3/2/1/0 cleared targets for 1.5 stars, a loss).
Arming one snapshots the run; **↩ Pulihkan Run Sebelum Gladi Resik**
restores it, which matters because RunResult otherwise advances the grade and
clears the roster on its way out.

**2. Scope every `get_ui_elements` call.** Bare, it serialises the whole tree
(the debug overlay alone is 58 verbose nodes). Always pass `root_path` and a
shallow `max_depth`:

    game_manage(op="get_ui_elements",
                params={"root_path": "/root/Inventory/MainColumn", "max_depth": 3})

Autoloads answer to `/root/<Name>` but the reply echoes scene-relative paths
(`/Inventory/../DebugManager`). Bare `/root` returns nothing.

**3. Prefer `test_run` over screenshots.** The whole suite returns compact JSON
in seconds; one screenshot costs more tokens than the entire run. Reach for a
screenshot only to judge something genuinely visual — and when you do, judge it
at full size. A scaled-down capture cannot show 1px detail, spacing or weight.

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

**4b. Three save hazards that silently eat work.**

- *`scene_save` flushes stale script buffers.* The editor holds `.gd` files
  open in script tabs and writes every tab back on each scene save, over
  whatever you patched; `script_patch` does not protect you. Do **scene work
  first, script work second**; after any `scene_save` check
  `git diff HEAD -- '*.gd'` for files you were not editing; and once you have
  patched a script, restart the editor before the next `scene_save` — a
  force-kill is safe once scenes are saved, and the relaunch reloads every tab
  from disk.
- *Overrides serialise only on an instanced scene's ROOT.* Properties set on an
  instance's **children** report success and are dropped on save. Give the
  sub-scene `@export`s on its root instead — why `ShopHubTile` carries
  `icon_texture`/`caption_text` rather than the hub reaching into
  `Content/Icon`, and why `ActivityRow` carries `watermark_texture`.
- *An editor left open across a pull writes its stale tabs back.* Close Godot
  **without saving** before every pull, or any checkout or merge that rewrites
  tracked files, then fully restart it (a new Resource `@export` needs one; see
  below). Left open, it can recreate a scene the pull deleted, or save an open
  scene without a script whose new base class it has not registered.

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
visible reason. Same for a **new** `@export`.

**The bridge is single-client.** Only one client holds the backend at a time. A
subagent that connects displaces your session and gets nothing itself, and both
then see "A different Godot AI backend is already running" (recovery is under
`## Godot MCP`). So: subagents write code, you run the editor and hand them the
results.

**The main checkout is shared too.** Several sessions often work in it at once:
never `git switch` or `git checkout` there on an old reading. Re-check
`git status` and `git reflog -1` in the same command, or put a second task in a
worktree.

**A full `test_run` drops the bridge.** A full run is 15-20s of
near-continuous main-thread work, and the plugin's transport does not survive
it (the `test_run` docs warn that a single test blocking for 20s+ can drop the
session). It is not memory pressure; that was ruled out.

So: **prefer targeted `test_run(suite=...)`** — milliseconds, never dropped.
Budget one editor restart for each full run you take, and take them at
milestones rather than between tasks. A full run's results are still valid when
the drop happens after the reply arrives.

One smaller habit: grep before reading — the two largest scripts here exceed
1,500 lines, so read the range you need, not the file.

None of this trades away test coverage. Coverage is the quality floor; the
savings come from cheaper verification loops, not from fewer tests.

## Outstanding debt & placeholders

Placeholders, deferred passes and known bugs live in `docs/superpowers/DEBT.md`;
grep it before changing a screen or asset. New debt goes there,
and an entry is deleted once resolved, not marked done. Constraints on future changes stay here, under `## Visual system`.

## Current work

Nothing recorded. Plan C's RunResult redesign is parked in
`docs/superpowers/DEBT.md`.

## Maintaining this file

This file is injected into every session before the user speaks. Everything in
it costs context on every single run, so it earns its place or it moves.

- A **completed pass** gets an entry in `docs/superpowers/CHANGELOG.md`, newest
  first — not a paragraph here.
- A fact that **changes how you work on the project** goes in the topical
  section it governs, not in `## Current work`. Keep the rule; the story of
  how it was learned goes in the changelog.
- An **unfinished placeholder or deferred item** goes in
  `docs/superpowers/DEBT.md` (grouped, not one entry per asset), and is deleted
  when resolved. Only a constraint it imposes on future changes comes up into
  this file.
- `## Current work` holds **only what is in flight right now**. When it lands,
  it moves to the changelog.
- **Point at the README, do not restate it.** If a folder README or a
  spec already documents the rules for an asset, link it and keep one line.
- Soft budget: **23,000 characters**, about the floor once history and debt
  are out. A pass that would exceed it moves
  something out first; it does not thin the live rules.

## Conventions

- Game-facing identifiers and all UI text are **Indonesian**; engine and systems code
  is English. Match whatever the surrounding file does.
- File naming is inconsistent (`loby.gd`, `koprasi.gd` are misspelled but
  load-bearing — do not "fix" them).
- Commits: Conventional Commits with a scope, e.g.
  `fix(lobby): wire the dead ReportStudent button`.
- **`Balance.gd` values are owned by a collaborator, not by us.** It holds
  most of the simulation's tuning: read it freely, never edit it, propose
  changes instead, and on merge take their version. A **new** tunable number
  of ours goes in a named `const` block or an `@export` in the script that
  owns the behaviour, never inline — like `RunGrade.gd`'s `WEIGHT_*` block.
- **No emoji as UI iconography.** Use real transparent SVG textures instead —
  explicitly banned during the 2026-09-02 end-of-grade pass after report icons
  briefly used emoji glyphs.
