# Loby Final Polish — Implementation Plan

> **Revision (2026-09-28): clean-code pass, rebased on Textures `b2890588`.**
> The original (2026-09-27, `origin/LobyFinalpolish` `ae688498`) predates the
> clean-code standard (`docs/superpowers/design/clean-code.md`), the
> 2026-09-26 file renames and the 2026-09-28 daily-login extraction. What
> changed:
>
> 1. **Names.** `loby.gd` / `loby.tscn` are now `Scripts/Lobby/Lobby.gd` /
>    `Scenes/Lobby/Lobby.tscn`. `main_menu.tscn` is now `MainMenu.tscn`. The
>    new `LobyHud/` folder and `test_loby_hud.gd` would fail the ⚙
>    misspelled-stem rule, so they are `LobbyHud/` and `test_lobby_hud.gd`.
>    Suite names are `suite_name()` values, not file names:
>    `theme_factory`, `lobby_hud`, `dapatkan_uang`.
> 2. **Lobby.gd's size is handled by its structure.** It is 993 lines,
>    and 1,000 is the large-script limit. New Task 0 pays debt first
>    (993 → ≈964). Every new behaviour lives in a new `@tool` component:
>    - `LobbyProgressHeader`
>    - `LobbyHud`
>    - `NotifBadge`
>    - `IdleFade`
>    - `DapatkanUang`
>
>    Lobby.gd only calls down to them. It ends at ≈973 lines, 20 fewer
>    than today. Each task states its expected line count and baseline
>    diff.
> 3. **The daily-login extraction.** The daily-login popup is now
>    `DailyLoginPanel` on `%DailyReward`. The daily badge asks it through a
>    new public `is_claimable()` and never reads GameState itself.
>    `DailyLoginPanel.wallet_anchor` is a NodePath to
>    `../Safe/UI/BottomBar/DisplayUang`. It must be re-pointed when the
>    coin box moves, and it gets a test pin.
> 4. **Factual fixes in the old plan:**
>    - `brand_primary_*` is **brown** (`7A4A2B`), not green, and
>      `LobbyCtaButton` is brown too.
>    - `SuccessButton` has been brown since the 2026-09-14
>      lobby-style-buttons pass, so the green `+` needs its own `PlusButton`
>      variation.
>    - The tokens have no "accent ramps". Colours are proposed from
>      existing tokens, and the human confirms them (Q3).
> 5. **Every button variation gets the display font**
>    (`_add_button_variation`). The old Task 1 forgot `DISPLAY_ROSTER` for
>    the button variations, and `theme_factory` would have failed.
> 6. **Order.** Placeholder art moved from old Task 9 to Task 1, because
>    ThemeFactory `load()`s it. Old Tasks 1–2 are now one variation task
>    with one rebake, using the real `theme_rebake` suite (there is no
>    transient suite).
> 7. **Missing work added:**
>    - The `Student` CTA shares JADWAL's slot during the tutorial.
>    - HUD swipe and motion stay off while the tutorial runs; the
>      spotlight measures scaled tiles.
>    - The hint toast.
>    - The lobby entrance stagger and the JADWAL breathe (spec §4).
>    - `JUDUL` collides with the new header (Q1).
>    - Chatter `tap_blockers`.
>    - Every test that pins today's HUD: `lobby`, `lobby_layout`,
>      `tall_screen_layout`, `lobby_style_buttons` and `student_chatter`.
> 8. **Dead-code checks:**
>    - `Juice.shake` is a *horizontal* position shake, so the rotational
>      badge wiggle is NotifBadge's own looped tween.
>    - `AchievementToast` only takes achievement ids, so Dapatkan Uang
>      carries its own toast node.
>    - `icon_chevron_up.png` exists and is reused.
>    - `ObjectiveHint` already formats the same star data for AturJadwal
>      (see Q2).
> 9. **Clean code.** Every snippet is typed and has no magic numbers. The
>    autoload-inference guard from `origin/Textures` (#98, not yet in the
>    local HEAD) applies: `var x: T = GameState.f()`, never `:=`. Steps are
>    tagged **[editor]** or **[code]**, and every task ends with
>    `test_run(suite="clean_code")`.
> 10. **Build branch.** Build on a fresh branch from current `Textures`,
>     for example `feat/lobby-scrapbook-hud`, and carry the spec, the
>     mockups and this plan in its first commit. `LobyFinalpolish` is
>     docs-only and behind `Textures`. Superseding PR #87 is the human's
>     call.

> ## ⛔ STOP — CONFIRM BEFORE YOU BUILD
> This plan is a handoff. Before Task 0, ask the user (the KejarTes owner):
>
> > "I've picked up the Loby Final Polish plan (revised 2026-09-28 for the
> > clean-code rules). Before I build: **is this design final?** I also need
> > answers to Q1–Q8 below. Where you have no preference, I'll use the
> > defaults the plan lists."
>
> Only proceed once they confirm. If they want changes, revise the spec and
> this plan first, then re-confirm.

## Questions for the human (defaults in brackets, used if they say "go")

- **Q1 — JUDUL.** The centred "KELAS" title (`%JUDUL`, 381–704 × 40–140)
  overlaps the new top-left header (48–564 × 48–216). The mockup has no
  JUDUL. *[Retire JUDUL. The header's grade badge says "KELAS 7". Its
  pins in `lobby`, `lobby_layout` and `tall_screen_layout` move to the
  header.]*
- **Q2 — Star denominator.** The spec shows stars over the run total
  (`2.0 / 3.0`, bar full at 3.0). AturJadwal's objective strip shows the
  same number over the *pass line* (`1.5 / 2`, bar full = passes,
  `ObjectiveHint`). The two screens would disagree. *[Follow the spec:
  `%.1f / %.1f` over `Balance.STARS_TOTAL`.]*
- **Q3 — Colours.** No accent ramps exist. The proposed fills (light /
  dark):
  - JADWAL: `state_success` / `state_success.darkened(0.25)`
  - Koperasi: `koperasi_tag_fill` / `koperasi_tag_border` (the shop's
    own green)
  - Inventory: `cat_akademis_on_dark` / `cat_akademis`. This is the
    Akademis blue, so it may read as "Akademis".
  - Rapor: `state_warning` / `cat_libur`
  - Grade badge: `cat_olahraga_on_dark`
  - Cream text on the amber `F5A623` is about 2:1. *[Rapor text uses
    `text_primary`, dark brown.]*

  Or add dedicated `lobby_nav_*` tokens (a new token `@export` needs a
  full editor restart).
- **Q4 — Dashed washi rim and tape.** `StyleBoxFlat` cannot draw dashes.
  *[Ship solid rims with a thick bottom lip now. The dashed rim, the tape
  and the JADWAL "washi flutter" wait for art and are logged in DEBT.]*
- **Q5 — Rail on swipe.** "As one piece" moving down would leave the
  mid-screen rail visible. *[The book slides down to its chevron peek and
  the rail slides off to the right, in the same tween. Both distances are
  `@export`s.]*
- **Q6 — Owed-ad action.** The spec's table has "owed ad watched →
  `ad_debt -= 1`", but the panel has no button for it. *[A
  `%TontonUtang` button, "Tonton iklan tertunda (N)", shown only while
  `ad_debt > 0`.]*
- **Q7 — Lobby-only look.** `style-guide.md` says every framed action
  button copies "the Lobby's look" (brown). The Lobby will stop wearing
  it. *[Scrapbook variations are a Lobby-only exception. Document it in
  `style-guide.md` and in `test_lobby_style_buttons.gd`'s header. The
  other screens stay brown.]*
- **Q8 — Star-gain sparkle trigger.** Stars change during SchoolDay, not
  in the Lobby. *[The header remembers the last count it drew this
  session in a `static var`. On Lobby entry the bar slides from there and
  sparkles only on a rise. Nothing is persisted.]*

**Goal:** Restyle the Lobby's bottom UI into a "scrapbook" HUD, then add
Phase 2's "Dapatkan Uang" earn-money panel with a dev-mode ad stub.
Phase 1:
- a stepped book holding JADWAL! and three colour-coded nav tiles
- a grade/week/star header
- a coin plate with a green `+`
- a right-edge icon rail with notification badges
- a bouncy swipe-away HUD
- an idle fade

**Architecture:**
- **Visuals.** Every visual is a `ThemeFactory` type variation, or
  placeholder art behind a variation, placed as nodes in
  `Scenes/Lobby/Lobby.tscn`. Never a `theme_override_*` (except
  `separation`/`margin_*`), and nothing is built at runtime.
- **Behaviour.** Each piece of behaviour is a `@tool` component script on
  the subtree it drives. The component's `_ready` is gated behind
  `Engine.is_editor_hint()`, and its writers are called only by the
  non-`@tool` `Lobby.gd` or by suites on a Lobby they instance
  themselves. Signals go up and calls go down.
- **Motion.** `Scripts/Design/Juice.gd` and `Scripts/AnimUtils.gd`, plus
  tweens owned by the components. Everything honours
  `GameSettings.reduce_motion`.
- **State.** Read from `GameState` and `Achievements`. The only new state
  is session-scoped `GameState.ad_debt`.

**Tech stack:** Godot 4.6, GDScript, the `godot-ai` editor bridge, and
`McpTestSuite` suites run with `test_run(suite=<suite_name()>)`.

**Spec:** `docs/superpowers/specs/2026-09-27-lobby-scrapbook-hud-design.md`,
with mockups in `docs/superpowers/specs/assets/lobby-scrapbook-hud/`
(`stepped_lobby.png` is the target). Read both. Where this plan and the
spec disagree, the revision notes above say why.

## Global Constraints

**House rules (CLAUDE.md):**
- **No `theme_override_*`** except the layout-only `separation` / `margin_*`.
  A new look is a `ThemeFactory` variation plus a rebake.
- **No visual built at runtime.** Static chrome is nodes in the `.tscn`, and
  a repeated piece is a `PackedScene` (`NotifBadge.tscn`). The
  `viewport_editability` ratchet has `Lobby.gd` at 8. New scripts
  construct **zero** of its `VISUAL_TYPES`.
- **`##` docs:** a file header on every script and a `##` line on every
  `@export` (`script_documentation`).
- **The four utility icon buttons are fixed art** (spec §1 and §8):
  `DailyLogin`, `SettingsButton`, `AchievementButton` and
  `SkinSwitchButton`. `texture_normal` and `stretch_mode` stay untouched.
  They may move, gain `custom_minimum_size` for the rail, and gain badges.
- **UI text is Indonesian** and systems code is English. **No emoji
  icons.** The `+` and the chevron are real textures.
- **Boohong** (the display face) has no `·` or `—` (measured 2026-09-24,
  `ObjectiveHint.gd`). Any copy containing `—` or `…` goes in a
  **body-font** label.
- **`Balance.gd` is read-only.** The reward amounts are our named `const`s
  in `DapatkanUang.gd`, marked as Balance proposals (Task 12).
- **No persistence.** `ad_debt` and the header's last-shown stars are
  session-only.
- **Tall phones:** the header is Top Left, the coin plate Top Right,
  `BookHud` Bottom Wide, and `IconRail` anchored bottom-right so it rides
  with the book. Pinned by `tall_screen_layout` and `lobby_layout`.
- **Tutorial targets:** `Student`, `Jadwal`, `Inventory`, `Koperasi` and
  `ReportStudent` stay unique names. `Lobby._show_step` finds them with
  `%Name` wherever they sit.

**Clean code (`docs/superpowers/design/clean-code.md`; ⚙ = the ratchet,
`test_run(suite="clean_code")`):**
- **No type inference from an autoload** (`tests/test_project_hygiene.gd`, PRs #97/#98, 2026-09-28): never `var x := GameState.…` or `:=` on any autoload call (ItemDatabase, GameSettings, …); declare the type, e.g. `var money: int = GameState.player_money`. A cold editor restart once left such results untyped, which makes `:=` a parse error.
- **Type everything ⚙.**
  - Every `var` either takes an obvious `:=` or has a declared type.
  - Every function has `->` and typed parameters.
  - Loop variables over untyped arrays are typed:
    `for header: Control in [...]`.
  - A value from an autoload always declares its type:
    `var stars: float = GameState.run_stars()`, never `:=`
    (`project_hygiene`, #98).
- **No magic numbers ⚙:**
  - logic numbers → a `##`-documented `const` at the top of the owning
    script
  - designer-tuned numbers → an `@export` with a `##` line
  - positions and sizes → the `.tscn`
  - fine inline: `0`, `1`, `2`, `-1` and `0.5`
- **One job per function ⚙.** No new function over 50 code lines. Engine
  callbacks read like a table of contents.
- **Flat.** Guard clauses and an early `return`; `match` for enum or string
  switches.
- **No duplicated bodies ⚙** (5+ lines in two files). Reuse
  `Juice`/`AnimUtils`, and never copy `_animate_button_click_bounce` or
  `_setup_button_juice`.
- **Signals up, calls down.** A component never reaches into
  `get_parent()`. Lobby.gd connects siblings (the `+` to the panel).
- **Node references** are taken once as `@onready var x: T = %UniqueName`.
  Every node a script touches is a unique name.
- **Fail loudly.** A missing wired node is a `push_error` naming the scene
  and node, and a programmer mistake is an `assert`. There is no
  `print("DEBUG`.
- **No commented-out code**, and comments explain *why*.
- **Boy Scout:** a Lobby.gd function you touch ends no longer and no less
  typed, with its bare numbers named.
- **Ratchet green, and lock in a shrink in the same commit.** When
  `clean_code` reports **shrank**, run:

      "C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd

  Check that `git diff ci/clean_code_baseline.gd` only lowers or removes
  entries. Then no-op `script_patch` the baseline so the open editor
  re-reads it, and re-run `clean_code`. No `--rekey` is expected: no
  function with a baseline key is renamed or moved.
  **Lobby.gd must stay ≤ 1,000 lines**; this plan keeps it under 980.

**Editor discipline (CLAUDE.md "Working efficiently", plus memory):**
- **[editor] steps** are the controller's: `scene_open`, `node_create`,
  `node_set_property`, `batch_execute` (`create_node` / `set_property` /
  `delete_node`), `reparent_node`, `scene_save`, `test_run`, screenshots.
  **[code] steps** are plain file edits a subagent can do, but a subagent
  never touches the bridge.
- **Never hand-edit `Lobby.tscn`** while the editor is attached.
  `move_node` only reorders; to change a node's parent use `reparent_node`
  (it keeps local offsets, so re-set anchors and offsets afterwards).
  After every `scene_save`:
  - diff the scene: `@tool` state can bake in, and so can the StickyNote
    and DancerRig offsets
  - run `git diff HEAD -- '*.gd'` for scripts you did not edit
- **Scene work first, script work second.** Brand-new `.gd` files may be
  written before the scene step, because no editor tab holds them yet.
  Edits to *existing* scripts (`Lobby.gd`, `DailyLoginPanel.gd`,
  `GameState.gd`, `ThemeFactory.gd`, tests) come after the `scene_save`.
  After patching one, restart the editor before the next `scene_save`.
- **After an outside edit:** rescan, then no-op `script_patch` each edited
  `.gd` before `test_run`. Normalise to LF before `script_patch`.
- **Rebake** by running `test_run(suite="theme_rebake")` **alone**, with an
  editor restart before and after (the cached theme merges stale styles by
  id, and `scene_save` writes them back). Prove parse first with
  `--headless --check-only` if reload error 43 persists. A new
  `DesignTokens` `@export`, or a changed default, needs a **full** restart.
  Diff `kejartes_theme.tres` before every commit.
- **Test runs.** Prefer a targeted `test_run(suite=...)`. A full run drops
  the bridge, so budget one restart per full run. Open
  `Scenes/MainMenu/MainMenu.tscn` before trusting a `scene_warning`. After
  a full run, `git checkout --` any unintended `kejartes_theme.tres` or
  `default_bus_layout.tres` churn.
- **Check before every commit.** Run `git branch --show-current` (another
  session can switch the shared checkout). Write commit messages to a file
  and use `git commit -F` (PS 5.1 splits `-m` here-strings). Use
  Conventional Commits with a scope.

---

## File Structure

| File | Change | Task |
|---|---|---|
| `Scripts/Lobby/Lobby.gd` | debt paid; calls down to components (993 → ≈973) | 0, 3, 5, 6, 10 |
| `Assets/Images/UI/LobbyHud/*.png`, `icon_plus.svg` | **new** placeholder art | 1 |
| `Scripts/Design/ThemeFactory.gd` | new `_build_lobby_hud()` | 2 |
| `tests/test_theme_factory.gd`, `tests/test_lobby_style_buttons.gd` | `expected` / `DISPLAY_ROSTER` / exception doc | 2 |
| `Scripts/Lobby/LobbyProgressHeader.gd` | **new** component on `%ProgressHeader` | 3 |
| `Scripts/Lobby/LobbyHud.gd` | **new** component on `%Hud` (swipe, motion, chip, badges) | 4–6 |
| `Scripts/Lobby/NotifBadge.gd` + `Scenes/Lobby/NotifBadge.tscn` | **new** badge template | 6 |
| `Scripts/UI/IdleFade.gd` | **new** generic idle-fade component | 7 |
| `Scripts/Lobby/DailyLoginPanel.gd` | `is_claimable()` (+5 lines) | 6 |
| `Scenes/Lobby/Lobby.tscn` | header, coin plate, `Hud/BookHud` + `IconRail`, badges, `IdleFade`, `DapatkanUang` | 3–7, 10 |
| `tests/test_lobby_hud.gd` | **new** suite `lobby_hud` | 3–7 |
| `tests/test_lobby.gd`, `test_lobby_layout.gd`, `test_tall_screen_layout.gd`, `test_student_chatter.gd` | pins moved to the new HUD | 3–6 |
| `Scripts/GameState.gd` | `ad_debt` (+4 lines) | 9 |
| `Scripts/Lobby/DapatkanUang.gd` + `Scenes/Lobby/DapatkanUang.tscn` | **new** panel | 10–11 |
| `tests/test_dapatkan_uang.gd` | **new** suite `dapatkan_uang` | 9–11 |
| `docs/superpowers/specs/2026-09-27-earn-money-balance-proposal.md` | **new** | 12 |
| `docs/superpowers/{CHANGELOG,DEBT}.md`, `CLAUDE.md`, `design/style-guide.md` | docs | 8, 13 |

Every suite is `@tool` and extends `McpTestSuite`, with no coroutine
tests. A suite that instances `Lobby.tscn` builds it **once** in
`suite_setup` and frees it in `suite_teardown`, never per test (the
message-queue overflow). It assigns `kejartes_theme.tres` before any size
check. It saves and restores every `GameState` / `GameSettings` field it
writes.

**Target node tree** (Tasks 3–7). Rects are measured from
`stepped_lobby.png` on the 1080×1920 design screen and are starting
values: Task 8's screenshot pass may nudge them, and the pins follow what
is authored.

```
TutorialOverlay (Lobby.gd)
├─ World …                                   (unchanged)
├─ Safe (SafeAreaMargin) / UI
│  ├─ ProgressHeader  Panel ProgressPlate  Top Left   (48,48 516×168)  [LobbyProgressHeader]
│  │  ├─ GradeBadge PanelContainer GradeBadge → GradeCaption (GradeBadgeLabel "KELAS"), %GradeNumber (GradeBadgeNumber)
│  │  ├─ %WeekLabel  Label WeekLabel
│  │  ├─ %StarBar    ProgressBar StarProgressBar  + %TipSparkle CPUParticles2D (one_shot, particle_star.png)
│  │  ├─ StarIcon    TextureRect (DaySummary/Verdict/star_on.svg)
│  │  └─ %StarNum    Label StarNumLabel
│  ├─ %DisplayUang   Panel CoinPlate  Top Right  (772,48 260×112)  — CoinIcon, Label (CoinLabel), %PlusUang Button PlusButton 96×96 (icon_plus.svg)
│  ├─ %Hud           Control Full Rect, mouse IGNORE  [LobbyHud]
│  │  ├─ %BookHud    Control Bottom Wide, mouse IGNORE  (was BottomBar)
│  │  │  ├─ %RaisedBlock Panel BookCoverPanel, mouse PASS (48,1400 612×216)
│  │  │  │  └─ %RaisedPage Panel BookPagePanel
│  │  │  │     ├─ %Jadwal  Button BookHeroButton "JADWAL!" + Subtitle Label CaptionLabel "Atur kegiatan minggu ini"
│  │  │  │     ├─ %Student Button BookHeroButton "STUDENT"   (same rect as Jadwal; tutorial phase 1)
│  │  │  │     └─ %RosterChip PanelContainer RosterChip → %RosterChipLabel CaptionLabel ("6 murid"), inset clear of the block's right edge
│  │  │  ├─ %ChevronGrip Button ChevronGripButton 280×96 → %ChevronGlyph TextureRect (DaySummary/icon_chevron_up.png, mouse IGNORE)
│  │  │  └─ %Shelf Panel BookCoverPanel, mouse PASS (48,1600 984×272) → ShelfPage Panel BookPagePanel → HBoxContainer
│  │  │     ├─ %Koperasi      Button NavTileKoperasi  rotation ≈ −1.5°
│  │  │     ├─ %Inventory     Button NavTileInventory rotation ≈ +1° → %InventoryBadge (NotifBadge.tscn)
│  │  │     └─ %ReportStudent Button NavTileRapor     rotation ≈ −1°  (text "RAPOR")
│  │  ├─ %IconRail  VBoxContainer anchored bottom-right (936,1040 96×456), separation 24
│  │  │  ├─ %DailyLogin (min 96×96) → %DailyBadge   (NotifBadge.tscn)
│  │  │  ├─ %SettingsButton
│  │  │  ├─ %AchievementButton (min 96×96) → %AchievementBadge (NotifBadge.tscn, shows_count = false)
│  │  │  └─ %SkinSwitchButton
│  │  └─ %HudHint  Label CaptionLabel "Ketuk dua kali untuk buka HUD."  hidden
│  └─ (JUDUL removed — Q1)
├─ ChatBubble …
├─ DailyReward (DailyLoginPanel)   wallet_anchor → ../Safe/UI/DisplayUang
├─ %DapatkanUang (DapatkanUang.tscn, hidden)            (Task 10)
├─ ColorRect / ClickArea …        (tutorial spotlight, unchanged)
├─ Chatter …
├─ IdleFade (IdleFade.gd) → IdleTimer (Timer)           (Task 7)
└─ WorldEnvironment
```

---

# PHASE 1 — Lobby restyle, HUD, animations (pure UI)

## Task 0: Make room in Lobby.gd (Boy Scout, pays debt)

The work is a pure refactor with no behaviour change. It makes room
before anything is added.

**Files:** Modify `Scripts/Lobby/Lobby.gd`. Test with the existing suites.

- [ ] **Step 1 [code]:** Remove the four stray blank or whitespace-only
  lines inside `_ready` (today L132–136; keep one blank line).
- [ ] **Step 2 [code]:** Remove the dead `is BaseButton` branches.
  - **Why they are dead:** `%Student` is a `Button` in `Lobby.tscn`, and
    `test_lobby` casts it `as Button`.
  - **What to change:** in `_ready`'s two branches (L192–195, L220–223),
    replace `if student_button is BaseButton: … else: …mouse_filter…`
    with `student_button.disabled = false` / `= true`.
  - **Leave `_show_step` untouched**, so no Boy Scout duty there.
- [ ] **Step 3 [code]:** Remove the dead `ClickArea` branch.
  - **Why it is dead:** `ClickArea` is a `Button`, so
    `click_area.has_signal("pressed")` is always true.
  - **What to change:** replace L238–244 with the guarded
    `click_area.pressed.connect(_next_step)`, then delete the now-unused
    `_on_click_area_gui_input` (L833–839).
  - **Effect:** this also removes a `DUPLICATE_GROUPS` pair with
    AturJadwal.
- [ ] **Step 4 [code]:** Extract the two identical 10-line nav-connection
  blocks (L197–206, L227–236) into one function, called from both
  branches. No test pins these lines; the pinned `settings_button…` and
  `skin_switch_button…` lines stay as they are.

```gdscript
## Wires every HUD destination button. Called once from _ready's branch,
## so no is_connected guard is needed (the scene holds no connections).
func _connect_hud_buttons() -> void:
	student_button.pressed.connect(_on_student_pressed)
	jadwal_button.pressed.connect(_on_jadwal_pressed)
	koperasi_button.pressed.connect(_on_koperasi_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	report_student_button.pressed.connect(_on_report_student_pressed)
```

- [ ] **Step 5 [code], Boy Scout in the touched `_ready`:**
  - `func _ready() -> void:`
  - `var viewport_size: Vector2 = get_viewport_rect().size`
  - type the onreads it uses: `student_button`, `jadwal_button`,
    `koperasi_button`, `report_student_button`, `inventory_button: Button`,
    `click_area: Button`
  - name its only bare number:

```gdscript
## The front row's idle bob starts this far (a fraction of idle_bob_period)
## behind the back row's, so the two containers never move in lockstep.
const FRONT_ROW_BOB_PHASE := 0.25
```

- [ ] **Step 6 [editor]:**
  - rescan, then no-op `script_patch` `Lobby.gd`
  - `test_run` for each of `lobby`, `lobby_skins`, `shorten`,
    `student_chatter`, `audio_coverage`, `daily_login_panel`, all PASS
  - `test_run(suite="clean_code")` → **shrank**
  - run the dump, check the diff, no-op `script_patch` the baseline, and
    re-run `clean_code`: PASS
- [ ] **Step 7:** Commit:
  `refactor(lobby): drop dead branches and extract the HUD button wiring`.

**Lobby.gd after:** ≈964 lines.
**Expected baseline diff:**
- `Lobby.gd::_ready` 95 → ≈68
- `UNTYPED` `Lobby.gd` 112 → ≈104
- `BARE_NUMBERS` `Lobby.gd` 44 → 43
- the `AturJadwal…::_on_click_area_gui_input | Lobby…::_on_click_area_gui_input`
  group removed

## Task 1: Placeholder art

The HUD's art arrives before any variation `load()`s it.

**Files:** Create `Assets/Images/UI/LobbyHud/` with:
- `book_cover.png` — brown board, 9-slice, lip at the bottom
- `book_page.png` — cream ruled page
- `coin_plate.png` and `progress_plate.png` — cream paper plates with a
  chunky lip
- `chevron_grip.png` — brown pill tab with a light grip bar
- `icon_plus.svg` — a white `+`, transparent

Every file is transparent outside its shape, and file names are
snake_case.

- [ ] **Step 1 [code]:** Generate the PNGs with a `.ps1` script in the
  scratchpad (`Add-Type -AssemblyName System.Drawing`; any C# in a `.cs`
  file, per the shell-guard memory). Write the SVG as text.
  - Size each PNG so its 9-slice margins are whole pixels, and record the
    margins in the DEBT entry.
  - No bridge calls in this step.
- [ ] **Step 2 [editor]:** Run `filesystem_manage(op="scan")` and confirm
  the `.import` files exist.
- [ ] **Step 3 [code]:** Add one grouped entry under DEBT.md
  "## Placeholder art":
  - the `LobbyHud/` set, drop-replaceable at the same paths with no code
    change
  - each file's size and 9-slice margins
  - the pending dashed washi rim, tape and JADWAL flutter (Q4)
- [ ] **Step 4 [editor]:** `test_run(suite="clean_code")` (asset names and
  misspelled stems): PASS.
- [ ] **Step 5:** Commit: `chore(lobby): placeholder scrapbook HUD art`.

**Lobby.gd after:** ≈964. **Baseline:** none.

## Task 2: Scrapbook theme variations (one rebake)

**Files:**
- Modify `Scripts/Design/ThemeFactory.gd`: a new
  `static func _build_lobby_hud(theme: Theme, tokens: DesignTokens) -> void`
  called from `build()` after `_build_settings`.
- Modify `tests/test_theme_factory.gd` and
  `tests/test_lobby_style_buttons.gd`.

ThemeFactory is exempt from the long-function, large-script and
bare-number counts. It is **not** exempt from the untyped count, so type
everything, and still name its numbers (see below).

**Produces:**

| Variation | Base | Look (Q3 colours) | Display font? |
|---|---|---|---|
| `BookHeroButton` | Button | `_add_button_variation` with the hero green, `font_h1`, `icon_max_width` `btn_icon_l`, thick bottom lip | yes |
| `NavTileKoperasi` / `NavTileInventory` / `NavTileRapor` | Button | the same helper with each tile's colours, stacked icon (`icon_max_width` `btn_icon_m`), thick lip; Rapor text `text_primary` | yes |
| `PlusButton` | Button | green, never gold (`state_success`), square | yes |
| `ChevronGripButton` | Button | `StyleBoxTexture` over `chevron_grip.png`, every state; no text, no font | no |
| `BookCoverPanel` / `BookPagePanel` | Panel | `StyleBoxTexture` over `book_cover.png` / `book_page.png` | — |
| `CoinPlate` / `ProgressPlate` | Panel | `StyleBoxTexture` over the plate PNGs | — |
| `GradeBadge` | PanelContainer | flat, grade-badge fill, `radius_md` | — |
| `GradeBadgeLabel` / `GradeBadgeNumber` | Label | `font_caption` / `font_h1`, `text_on_brand` | yes |
| `WeekLabel` | Label | `font_title`, `text_primary` | yes |
| `StarProgressBar` | ProgressBar | `surface_sunken` pill track, `state_success` pill fill | — |
| `StarNumLabel` | Label | `font_caption`, `state_success.darkened(0.25)` | yes |
| `NotifBadge` | Panel | `state_danger` pill, `outline_card` rim | — |
| `NotifBadgeLabel` | Label | `font_caption`, `text_on_brand` | yes |
| `RosterChip` | PanelContainer | `surface_card` pill, `brand_primary` rim | — |

- [ ] **Step 1 [code]:** Write the failing tests.
  - In `test_theme_factory.gd`, add every name above to `expected` in
    `test_every_declared_variation_exists`.
  - Append a dated comment block to `DISPLAY_ROSTER` with the eight
    display names.
  - Add a behavioural test. It uses the suite's `_theme`/`_tokens`, so no
    source scan and no nonexistent `_read` helper:

```gdscript
## 2026-09-27 scrapbook HUD: the + is green, never gold (spec §3.2), and
## JADWAL is the greenest element (spec §4).
func test_scrapbook_plus_and_hero_are_green() -> void:
	var plus := _theme.get_stylebox("normal", "PlusButton") as StyleBoxFlat
	assert_true(plus != null, "PlusButton/normal is a flat box")
	if plus == null:
		return
	assert_eq(plus.bg_color, _tokens.state_success, "the + wears the success green")
	assert_ne(plus.bg_color, _tokens.currency_gold, "a gold + would read as an IAP button")
	var hero := _theme.get_stylebox("normal", "BookHeroButton") as StyleBoxFlat
	assert_true(hero != null and hero.bg_color == _tokens.state_success,
		"JADWAL wears the hero green")
```

- [ ] **Step 2 [editor]:** `test_run(suite="theme_factory")` → FAIL on the
  missing names.
- [ ] **Step 3 [code]:** Implement `_build_lobby_hud`.
  - **Art paths.** Name them with `const` paths at the top of the file,
    following the `_RESULT_CARD_ART` precedent:

```gdscript
## Scrapbook HUD art (2026-09-27 spec §6). Placeholders until final art
## lands at the same paths (docs/superpowers/DEBT.md).
const _LOBBY_HUD_ART := "res://Assets/Images/UI/LobbyHud/"
## The scrapbook tiles' chunky 3D lip: bottom border width, px.
const LOBBY_HUD_LIP := 10
## The book and plate art's 9-slice margin, px (the art's own corners).
const LOBBY_HUD_ART_MARGIN := 40
```

  - **Buttons.** Build them with the existing `_add_button_variation`.
    Then one small helper,
    `_thicken_lip(theme: Theme, name: String, lip: int) -> void`, sets
    `border_width_bottom` on the five states. Do not copy
    `_add_lobby_button`.
  - **Labels.** Set `font_display` guarded by `if tokens.font_display != null`,
    as every label builder does.
  - **Docs.** Each variation gets a `#` line saying what it is for.
- [ ] **Step 4 [code]:** Update `tests/test_lobby_style_buttons.gd`'s
  header (Q7). The scrapbook variations (`BookHeroButton`, `NavTile*`,
  `PlusButton`) are the Lobby-only exception and are deliberately absent
  from `LOBBY_LOOK`. `LobbyCtaButton` and `LobbyNavTile` stay built and
  pinned: `Password.tscn`, `Variabel.tscn` and `test_kalkulator` still
  use them.
- [ ] **Step 5 [editor]:** Rebake.
  1. Restart the editor.
  2. `test_run(suite="theme_rebake")` **alone**.
  3. Restart again.
  4. Run `theme_factory` and `lobby_style_buttons`: PASS.
  5. `git diff --stat Assets/Theme/kejartes_theme.tres` shows only
     additions.
  6. Run `clean_code`: PASS (ThemeFactory stays fully typed).
- [ ] **Step 6:** Commit:
  `feat(lobby): scrapbook HUD theme variations`.

**Lobby.gd after:** ≈964. **Baseline:** none.

## Task 3: Progress header and coin plate (top chrome)

**Files:**
- Create `Scripts/Lobby/LobbyProgressHeader.gd`.
- Modify `Scenes/Lobby/Lobby.tscn`, then `Scripts/Lobby/Lobby.gd`.
- Create the `tests/test_lobby_hud.gd` suite (`lobby_hud`).
- Modify `tests/test_lobby.gd`, `test_lobby_layout.gd` and
  `test_tall_screen_layout.gd`.

**Interfaces:**
- **Consumes:**
  - `GameState.current_grade`, `minggu_ke`, `max_minggu`
  - `GameState.run_stars()`, `Balance.STARS_TOTAL`
- **Produces:**
  - `LobbyProgressHeader.refresh() -> void`
  - `%PlusUang` (wired in Task 10; until then it is a disabled button,
    **not** routed anywhere fake)

- [ ] **Step 1 [code]:** Write the component, a new file (so there is no
  editor tab yet):

```gdscript
@tool
class_name LobbyProgressHeader
extends Panel

## The Lobby's top-left progress plate (2026-09-27 scrapbook HUD spec §3.1):
## the grade badge, "Minggu N / total" and the run's star bar toward
## Balance.STARS_TOTAL. Reads GameState only when the Lobby calls refresh()
## down; announces nothing. @tool so the lobby_hud suite can call refresh()
## on a Lobby it instances. It has no _ready side effects, so an editor
## save never bakes a drawn state into Lobby.tscn.

## The week line: the week, then the grade's length.
const WEEK_FORMAT := "Minggu %d / %d"
## The star line: the run's stars over the total, as the spec's "2.0 / 3.0".
const STAR_FORMAT := "%.1f / %.1f"

## Seconds the star bar takes to slide to a new count.
@export var fill_seconds: float = 0.6

## The count this session last drew. Session memory, not persistence: the
## bar slides from here on the next Lobby entry and sparkles on a rise (Q8).
static var _last_shown_stars: float = 0.0

@onready var grade_number: Label = %GradeNumber
@onready var week_label: Label = %WeekLabel
@onready var star_bar: ProgressBar = %StarBar
@onready var star_label: Label = %StarNum
@onready var tip_sparkle: CPUParticles2D = %TipSparkle


## Draws the grade, the week and the stars from GameState.
func refresh() -> void:
	grade_number.text = str(GameState.current_grade)
	week_label.text = WEEK_FORMAT % [GameState.minggu_ke, GameState.max_minggu]
	var stars: float = GameState.run_stars()
	star_label.text = STAR_FORMAT % [stars, Balance.STARS_TOTAL]
	_slide_bar(_last_shown_stars, stars)
	_last_shown_stars = stars


## Slides the bar from `from_stars` to `to_stars`; a rise sparkles at the
## new tip. Under reduce_motion it simply lands.
func _slide_bar(from_stars: float, to_stars: float) -> void:
	star_bar.max_value = Balance.STARS_TOTAL
	star_bar.value = from_stars
	if GameSettings.reduce_motion or is_equal_approx(from_stars, to_stars):
		star_bar.value = to_stars
		return
	Juice.fill_bar(star_bar, to_stars, fill_seconds)
	if to_stars > from_stars:
		_sparkle_at(to_stars)


## Moves the one-shot sparkle to where the bar will end, and fires it.
func _sparkle_at(stars: float) -> void:
	var tip_x: float = star_bar.size.x * stars / Balance.STARS_TOTAL
	tip_sparkle.position = Vector2(star_bar.position.x + tip_x, tip_sparkle.position.y)
	tip_sparkle.restart()
```

- [ ] **Step 2 [code]:** Write the failing suite.
  - **File:** `tests/test_lobby_hud.gd`, `@tool`, `##` header,
    `suite_name()` returns `"lobby_hud"`.
  - **Fixture:** one Lobby per suite, following
    `test_daily_login_panel.gd`'s `suite_setup` / `suite_teardown`, with
    `theme = load("res://Assets/Theme/kejartes_theme.tres")` set before
    `add_child`.
  - **setup / teardown:** save and restore `GameState.current_grade`,
    `max_minggu`, `minggu_ke`, `approved_students`, `player_money`,
    `inventory`, and `GameSettings.reduce_motion`.

```gdscript
func test_header_draws_grade_week_and_stars() -> void:
	var header := _lobby.get_node_or_null("%ProgressHeader") as LobbyProgressHeader
	assert_true(header != null, "Safe/UI needs a LobbyProgressHeader named ProgressHeader")
	if header == null:
		return
	GameSettings.reduce_motion = true
	GameState.current_grade = 8
	GameState.minggu_ke = 3
	GameState.approved_students = []
	header.refresh()
	assert_eq((header.get_node("%GradeNumber") as Label).text, "8")
	assert_eq((header.get_node("%WeekLabel") as Label).text,
		LobbyProgressHeader.WEEK_FORMAT % [3, GameState.max_minggu])
	assert_eq((header.get_node("%StarBar") as ProgressBar).value, 0.0,
		"an empty roster has no stars")


func test_header_and_coin_plate_wear_the_scrapbook_plates() -> void:
	var header := _lobby.get_node_or_null("%ProgressHeader") as Panel
	var coin := _lobby.get_node_or_null("%DisplayUang") as Panel
	assert_true(header != null and header.theme_type_variation == &"ProgressPlate")
	assert_true(coin != null and coin.theme_type_variation == &"CoinPlate")
	var plus := _lobby.get_node_or_null("%PlusUang") as Button
	assert_true(plus != null and plus.theme_type_variation == &"PlusButton",
		"the coin plate carries the green +")


func test_the_reward_coin_still_flies_to_the_wallet() -> void:
	var panel := _lobby.get_node("DailyReward") as DailyLoginPanel
	assert_eq(panel.wallet_anchor, _lobby.get_node("%DisplayUang"),
		"wallet_anchor must follow DisplayUang out of BottomBar")
```

- [ ] **Step 3 [editor]:** `test_run(suite="lobby_hud")` → FAIL.
- [ ] **Step 4 [editor], scene first:** `scene_open` `Lobby.tscn`.
  - **ProgressHeader.** Under `Safe/UI`, create `ProgressHeader` (Panel,
    `ProgressPlate`, `layout_mode = 1`, Top Left, 48,48 516×168 relative
    to UI) and its children from the node tree above. Attach
    `LobbyProgressHeader.gd`. The `TipSparkle` is a `CPUParticles2D`
    (one_shot, `particle_star.png`, not a GPU material, so the
    disable-z scan does not apply).
  - **DisplayUang.** `reparent_node` it `BottomBar` → `Safe/UI`, set it
    Top Right, then re-set its offsets to 772,48 260×112. Retheme it
    `CoinPlate`. Add `%PlusUang` (Button, `PlusButton`, 96×96, icon
    `icon_plus.svg`, `disabled = true` until Task 10).
  - **wallet_anchor.** Re-set `DailyReward.wallet_anchor` to
    `%DisplayUang` (the NodePath becomes `../Safe/UI/DisplayUang`).
  - **JUDUL.** Delete `JUDUL` (Q1).
  - `scene_save`, then diff the `.tscn` and `git diff HEAD -- '*.gd'`.
- [ ] **Step 5 [code]:** Lobby.gd, after the scene save. Add
  `@onready var progress_header: LobbyProgressHeader = %ProgressHeader`,
  and call `progress_header.refresh()` right after
  `GameState.initialize_grade_targets()` (+2 lines). This is **not** in
  the header's own `_ready`: children are ready before the Lobby, and the
  targets would not be initialised yet.
- [ ] **Step 6 [code]:** Move the pins.
  - **`test_lobby.gd`:**
    - `test_scene_instantiates` checks `%ProgressHeader` instead of
      `%JUDUL`.
    - `test_labels_use_theme_variations` drops JUDUL.
    - `test_the_money_chip_is_a_themed_panel_with_a_coin_icon` expects
      `CoinPlate` and height 112.
    - `test_interactive_controls_meet_the_minimum_touch_target` adds
      `%PlusUang`.
  - **`test_lobby_layout.gd`:** `DESIGN_RECTS` swaps `JUDUL` for
    `ProgressHeader` (48,48,516,168) and moves `DisplayUang` to
    (772,48,260,112). `test_hud_does_not_sit_on_the_front_row_faces`
    adds `ProgressHeader`. Heads are at y≈389±110, and the header ends at
    216.
  - **`test_tall_screen_layout.gd`:** at 2400 the header and coin plate
    stay on top: `_assert_placed(%ProgressHeader, Rect2(48,48,516,168))`,
    replacing the JUDUL line. `DisplayUang` leaves the "rides in
    BottomBar" list and gets `_assert_under_safe_area`.
- [ ] **Step 7 [editor]:**
  1. Restart, then no-op `script_patch` the edited `.gd` files.
  2. `test_run` for each of `lobby_hud`, `lobby`, `lobby_layout`,
     `tall_screen_layout`, `daily_login_panel`, `script_documentation`,
     `viewport_editability`, `project_hygiene`, `clean_code`: all PASS.
     Run the dump if `clean_code` reports shrank.
- [ ] **Step 8:** Commit:
  `feat(lobby): grade/week/star header and coin plate with green plus`.

**Lobby.gd after:** ≈966. **Baseline:** none expected. The new script
starts at zero. `_ready` +1 code line stays under its entry.

## Task 4: Stepped book housing and icon rail (scene only)

**Files:** Modify `Scenes/Lobby/Lobby.tscn`, `tests/test_lobby.gd`,
`test_lobby_layout.gd`, `test_tall_screen_layout.gd` and
`test_lobby_hud.gd`. Modify comments only in `Lobby.gd`.

**Produces:** the `Hud` / `BookHud` / `RaisedBlock` / `Shelf` /
`ChevronGrip` / `IconRail` / `HudHint` tree above, with the nav buttons
restyled in place and keeping their unique names.

**Why no template for the three tiles:** each is a distinct pinned
unique name and a tutorial target, with no per-call count. The rule's
"repeated rows" does not apply. The badges (Task 6) are the template.

- [ ] **Step 1 [code]:** Failing tests in `test_lobby_hud.gd`:

```gdscript
const _BOOK_PARTS: Array[String] = ["Hud", "BookHud", "RaisedBlock", "RaisedPage",
	"Shelf", "ChevronGrip", "ChevronGlyph", "IconRail", "HudHint", "RosterChip"]


func test_the_stepped_book_is_built() -> void:
	for part: String in _BOOK_PARTS:
		assert_true(_lobby.get_node_or_null("%" + part) != null, "missing %" + part)
	var jadwal := _lobby.get_node("%Jadwal") as Button
	assert_eq(jadwal.theme_type_variation, &"BookHeroButton")
	assert_true((_lobby.get_node("%RaisedPage") as Node).is_ancestor_of(jadwal),
		"JADWAL sits on the raised page")
	var tiles: Dictionary = {"Koperasi": &"NavTileKoperasi",
		"Inventory": &"NavTileInventory", "ReportStudent": &"NavTileRapor"}
	for tile_name: String in tiles:
		var tile := _lobby.get_node("%" + tile_name) as Button
		assert_eq(tile.theme_type_variation, tiles[tile_name], tile_name)
		assert_true((_lobby.get_node("%Shelf") as Node).is_ancestor_of(tile),
			tile_name + " sits on the shelf")


func test_the_fixed_icons_moved_with_their_art() -> void:
	var rail := _lobby.get_node("%IconRail") as Node
	var art: Dictionary = {
		"DailyLogin": "res://Assets/Images/UI/icon_daily_login.png",
		"SettingsButton": "res://Assets/Images/UI/setting.png",
		"AchievementButton": "res://Assets/Images/Achievements/achievement_button.png",
		"SkinSwitchButton": "res://Assets/Images/UI/skin_switch.png",
	}
	for icon_name: String in art:
		var icon := _lobby.get_node("%" + icon_name) as TextureButton
		assert_eq(icon.get_parent(), rail, icon_name + " rides in the rail")
		assert_eq(icon.texture_normal.resource_path, art[icon_name],
			icon_name + "'s art is fixed (spec §1)")
```

- [ ] **Step 2 [editor]:** `test_run(suite="lobby_hud")` → FAIL.
- [ ] **Step 3 [editor], scene:** `scene_open` `Lobby.tscn`.
  1. Rename `BottomBar` → `BookHud`; it stays Bottom Wide with mouse
     IGNORE.
  2. Create `Hud` (Control, Full Rect, mouse IGNORE) under `Safe/UI` and
     `reparent_node` `BookHud` into it.
  3. Build `RaisedBlock` / `RaisedPage` / `Shelf` / `ShelfPage` +
     HBoxContainer (`separation` only) and `ChevronGrip` + `ChevronGlyph`
     (pivot centred).
  4. `reparent_node` `Jadwal` and `Student` into `RaisedPage`, giving them
     one shared rect and `BookHeroButton`. Add the Subtitle label under
     `Jadwal`.
  5. Add `RosterChip`, **inset so it clears the block's right edge** (the
     mockup clipped it).
  6. Reparent `Koperasi` / `Inventory` / `ReportStudent` into the shelf
     HBox, with their `NavTile*` variations, the text "RAPOR", and a small
     `rotation`.
  7. Create `IconRail`, anchored bottom-right at 936,1040 96×456, and
     reparent the four icon buttons in the mockup's order. Give
     `DailyLogin` and `AchievementButton` `custom_minimum_size`
     `Vector2(96, 96)`, as the other two already have.
  8. Add `HudHint`, hidden.
  9. Every `reparent_node`: re-set anchors and offsets and fix the order
     with `move_node`, then `scene_save`. Diff the scene: no stray
     `[node … parent=".../<Instance>"]` blocks, no baked `@tool` state.
- [ ] **Step 4 [code]:** Lobby.gd comments only. The comments at L58–59
  and L657–661 still say `Safe/UI/BottomBar`. Change them to
  `Safe/UI/Hud/BookHud`, with the same line count.
- [ ] **Step 5 [code]:** Move the pins.
  - **`test_lobby.gd`:** `test_nav_buttons_use_lobby_nav_tile_or_cta_button_variation`
    becomes a scrapbook check: `Student` and `Jadwal` →
    `BookHeroButton`, and each tile → its `NavTile*`.
  - **`test_lobby_layout.gd`:**
    - `DESIGN_RECTS` gets the new rects for `Student` and `Jadwal`, the
      three tiles, `ChevronGrip`, `IconRail` and the rail icons.
    - Keep `test_nav_tiles_share_one_height_and_one_baseline`.
    - Keep the rim and front-row-faces checks, and add `IconRail` to the
      faces list. Its top 1040 is well below y 499.
  - **`test_tall_screen_layout.gd`:**
    - `test_lobby_hud_is_pinned_inside_the_safe_area`:
      `Safe/UI/Hud/BookHud` is Bottom Wide and IGNORE, and each HUD node
      is under `BookHud` or `IconRail` (`is_ancestor_of`, not direct
      parent).
    - `test_lobby_on_a_tall_phone`: `Jadwal`, `ReportStudent` and
      `DailyLogin` move down by 480 from their new design rects.
- [ ] **Step 6 [editor]:**
  1. Restart, then no-op `script_patch`.
  2. Run `lobby_hud`, `lobby`, `lobby_layout`, `tall_screen_layout`,
     `student_chatter`, `clean_code`: PASS.
  3. **One full-size screenshot:**
     - seed with Debug → General → ⚡ Seed Playtest State
     - teleport to the Lobby
     - freeze with `Engine.time_scale = 0.02` inside the same
       `game_eval`

     Compare against `stepped_lobby.png`. If a rect moves, update
     `DESIGN_RECTS` to match what is authored.
- [ ] **Step 7:** Commit: `feat(lobby): stepped book HUD housing and icon rail`.

**Lobby.gd after:** ≈966 (comments only). **Baseline:** none.

## Task 5: LobbyHud — swipe, motion, roster chip

**Files:** Create `Scripts/Lobby/LobbyHud.gd`. Modify `Lobby.tscn`
(attach), `Lobby.gd`, `tests/test_lobby_hud.gd` and
`tests/test_student_chatter.gd`.

**Interfaces:**
- **Consumes:**
  - `Juice.stagger_in`
  - `AnimUtils.squash_bounce`, `AnimUtils.message_pop`
  - `GameState.approved_students`, `GameSettings.reduce_motion`
- **Produces (`class_name LobbyHud`):**
  - `activate(with_entrance: bool)`
  - `set_open(open: bool)`, `is_open: bool`
  - `refresh(is_daily_claimable: bool)`: the roster chip now, badges in
    Task 6
  - `tap_blockers() -> Array[Control]`

**Tutorial rule:** the HUD starts inactive, with no swipe, entrance or
breathe. The spotlight (`_highlight_multiple`) measures the targets' global
transforms, so a tile mid-`pop_in` would get a shrunken hole. Lobby.gd
calls `activate(true)` from the returning-player branch and
`activate(false)` from `_end_tutorial()`.

- [ ] **Step 1 [code]:** Write the component, a new file. Skeleton, every
  function ≤ 50 lines:

```gdscript
@tool
class_name LobbyHud
extends Control

## The Lobby's bottom HUD (2026-09-27 scrapbook HUD spec §4): the stepped
## book (JADWAL on the raised block, three tiles on the shelf) and the icon
## rail. It swipes away as a whole: the book slides down to its chevron
## peek and the rail slides off the right edge in the same tween (Q5); the
## chevron, a vertical drag on the book, or a double tap anywhere brings
## it back. It also plays the entrance, JADWAL's breathe and the
## roster-count chip. It stays inactive until the Lobby calls activate(),
## so the tutorial's spotlight never measures a moving target. Calls come
## down from Lobby.gd; nothing here reaches up. @tool so the lobby_hud
## suite can drive it: _ready only wires signals ungated, and every
## writer runs from the non-@tool Lobby or a suite's own instance.

## The chip's line: the approved roster's size.
const ROSTER_CHIP_FORMAT := "%d murid"
## The chevron's turn when the book is hidden, degrees.
const CHEVRON_HIDDEN_DEGREES := 180.0

@export_group("Swipe")
## Seconds the book and rail take to slide (TRANS_BACK overshoot, "Feel A").
@export var slide_seconds: float = 0.45
## Book height, px, left showing when hidden: the chevron grip's peek.
@export var peek_pixels: float = 96.0
## How far, px, the rail slides right to leave the screen.
@export var rail_slide_pixels: float = 180.0
## Vertical drag, px, on the book that counts as a swipe.
@export var swipe_threshold_pixels: float = 80.0
## Seconds the chevron's turn trails the book, to sell the hinge.
@export var chevron_delay_seconds: float = 0.08
@export_group("Idle")
## Seconds between two bobs of the peeking chevron while hidden.
@export var peek_bob_interval_seconds: float = 3.0
## Height, px, of the peeking chevron's bob.
@export var peek_bob_pixels: float = 8.0
## One JADWAL breathe (in and out), seconds (spec §4: ~1.8 s).
@export var breathe_period_seconds: float = 1.8
## RaisedPage's scale at the top of a breath. The page, not the button:
## UIPolish's press and the Lobby's hover already tween the button's scale.
@export var breathe_scale: float = 1.03
## Seconds the "Ketuk dua kali" hint stays up after a hide.
@export var hint_seconds: float = 1.5
@export_group("")

var is_open: bool = true
var is_active: bool = false
var _book_open_y: float
var _rail_open_x: float
var _drag_start_y: float = NAN
var _slide: Tween
var _peek_bob: Tween
var _breathe: Tween

@onready var book_hud: Control = %BookHud
@onready var raised_block: Control = %RaisedBlock
@onready var raised_page: Control = %RaisedPage
@onready var shelf: Control = %Shelf
@onready var icon_rail: Control = %IconRail
@onready var chevron_grip: Button = %ChevronGrip
@onready var chevron_glyph: Control = %ChevronGlyph
@onready var roster_chip: Control = %RosterChip
@onready var roster_chip_label: Label = %RosterChipLabel
@onready var hint: Label = %HudHint


## Pure signal wiring, ungated so the suite can exercise it.
func _ready() -> void:
	chevron_grip.pressed.connect(_on_chevron_pressed)
	raised_block.gui_input.connect(_on_book_gui_input)
	shelf.gui_input.connect(_on_book_gui_input)


## Turns the swipe on and remembers the open rest positions; the entrance
## (tiles drop in, staggered) plays only when asked, then JADWAL breathes.
func activate(with_entrance: bool) -> void: ...

## Slides the book and rail away (false) or back (true).
func set_open(open: bool) -> void: ...

## The roster chip, hidden with an empty roster. Task 6 adds the badges.
func refresh(is_daily_claimable: bool) -> void: ...

## What the chatter must not treat as a tap on a face.
func tap_blockers() -> Array[Control]:
	return [raised_block, shelf, chevron_grip, icon_rail]
```

  - **`set_open`:**
    - Kill `_slide`. Tween `book_hud.position:y` to `_book_open_y` or
      `_book_open_y + book_hud.size.y - peek_pixels`, and
      `icon_rail.position:x` to `_rail_open_x` or
      `_rail_open_x + rail_slide_pixels`. Use one parallel tween,
      `TRANS_BACK` / `EASE_OUT`.
    - Tween `chevron_glyph.rotation_degrees` after
      `chevron_delay_seconds`.
    - On landing open, call `AnimUtils.squash_bounce(book_hud)`. On
      landing hidden, `_show_hint()`
      (`AnimUtils.message_pop(hint, hint_seconds)`) and start the peek
      bob.
    - Under `reduce_motion`, set the end values and skip the tweens. That
      is also the path the suite tests.
  - **`_input(event)`:** returns while `is_open or not is_active`, and
    reopens on `_is_double_tap(event)`. `_input`, like `LobbyChatter`,
    sees the tap before any GUI node can stop it, and never marks it
    handled.
  - **`_on_book_gui_input`:** records `_drag_start_y` on press, and on a
    drag or motion past `swipe_threshold_pixels` calls
    `set_open(travel < 0.0)`. Guard with `if not is_active: return`.
  - Tune the exact curve with the `motion-lab` skill on a live preview.
    Keep the `@export` defaults above unless the human picks others.
- [ ] **Step 2 [code]:** Failing tests. `set_open` under reduce_motion
  snaps, so the test needs no await.

```gdscript
func test_the_hud_hides_to_its_peek_and_comes_back() -> void:
	var hud := _lobby.get_node("%Hud") as LobbyHud
	GameSettings.reduce_motion = true
	hud.activate(false)
	var book := hud.get_node("%BookHud") as Control
	var open_y: float = book.position.y
	hud.set_open(false)
	assert_false(hud.is_open)
	assert_eq(book.position.y, open_y + book.size.y - hud.peek_pixels,
		"hidden leaves only the chevron's peek")
	hud.set_open(true)
	assert_eq(book.position.y, open_y, "open returns to the authored rest")


func test_the_hud_waits_for_the_tutorial() -> void:
	var fresh := track(LobbyHud.new()) as LobbyHud
	assert_false(fresh.is_active, "a HUD starts inactive")
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")
	assert_true(src.contains("hud.activate(true)"), "returning players get the entrance")
	assert_true(src.contains("hud.activate(false)"), "the tutorial's end turns the swipe on")


func test_the_roster_chip_counts_the_class() -> void:
	var hud := _lobby.get_node("%Hud") as LobbyHud
	GameState.approved_students = [{"name": "Andi"}, {"name": "Citra"}]
	hud.refresh(false)
	assert_eq((hud.get_node("%RosterChipLabel") as Label).text,
		LobbyHud.ROSTER_CHIP_FORMAT % 2)
	GameState.approved_students = []
	hud.refresh(false)
	assert_false((hud.get_node("%RosterChip") as Control).visible,
		"no chip before a roster exists")
```

- [ ] **Step 3 [editor]:** `lobby_hud` → FAIL. Then `scene_open`, attach
  `LobbyHud.gd` to `%Hud`, `scene_save`, and diff. No `@tool` state is
  baked: `position`, `rotation` and `visible` on the HUD nodes are
  unchanged.
- [ ] **Step 4 [code]:** Lobby.gd, after the save:
  - `@onready var hud: LobbyHud = %Hud` (+1)
  - `hud.activate(true)` in the returning-player branch (+1)
  - `hud.activate(false)` in `_end_tutorial()` (+1). Boy Scout: it becomes
    `func _end_tutorial() -> void:`.
  - Replace the 4-line `chatter.tap_blockers = [...]` with (−2):

```gdscript
		chatter.tap_blockers = [progress_header, get_node("%DisplayUang")] \
			+ hud.tap_blockers()
```

  `test_student_chatter`'s pin `chatter.tap_blockers = [` still matches.
  Extend it: assert the source contains `hud.tap_blockers()`.
- [ ] **Step 5 [editor]:**
  1. Restart, then no-op `script_patch`.
  2. Run `lobby_hud`, `lobby`, `student_chatter`, `script_documentation`,
     `viewport_editability`, `project_hygiene`, `clean_code` (it reports
     shrank for UNTYPED and `_ready`, so run the dump): PASS.
  3. `project_run`, seed, open the Lobby. Swipe down on the book and check
     the chevron peek, the bob and the hint. Double-tap: it springs back
     with a squash. By eye, the tiles drop in on entry and JADWAL
     breathes.
- [ ] **Step 6:** Commit:
  `feat(lobby): bouncy swipe-away HUD with entrance, breathe and peek bob`.

**Lobby.gd after:** ≈967.
**Expected baseline diff:**
- `UNTYPED` `Lobby.gd` −1 (≈103)
- `Lobby.gd::_ready` −1 (≈67)

## Task 6: Notification badges

**Files:**
- Create `Scripts/Lobby/NotifBadge.gd` and `Scenes/Lobby/NotifBadge.tscn`.
- Modify `Scripts/Lobby/LobbyHud.gd`, `Scripts/Lobby/DailyLoginPanel.gd`,
  `Lobby.tscn`, `Lobby.gd`, `tests/test_lobby_hud.gd` and
  `tests/test_daily_login_panel.gd`.

**Interfaces:**
- **Consumes:**
  - `DailyLoginPanel.is_claimable()` (new)
  - `Achievements.total_unclaimed_count()`, `Achievements.state_changed`
  - `GameState.inventory`, `GameState.inventory_changed`
- **Produces:**
  - `NotifBadge.set_count(count: int)`
  - `LobbyHud.refresh(is_daily_claimable)` now also sets the three
    badges

Why a rotational wiggle of its own: `Juice.shake` is a horizontal position
shake, and `AnimUtils.wobble` snaps the scale to 0.7 on each call, so
neither can loop.

- [ ] **Step 1 [code]:** `NotifBadge.gd`, a new file:

```gdscript
@tool
class_name NotifBadge
extends Panel

## A red notification pill (2026-09-27 scrapbook HUD spec §5), instanced
## from NotifBadge.tscn onto a rail icon or a nav tile. Hidden at zero.
## When it turns on it springs in, then gives a gentle rotational wiggle
## every wiggle_interval_seconds, starting wiggle_delay_seconds late so
## badges never wiggle in unison. Calls come down from LobbyHud. @tool so
## the lobby_hud suite can call set_count(); nothing runs in _ready.

## What a badge shows when it marks rather than counts (the achievement "!").
const MARK_TEXT := "!"
## The largest count drawn as a number; above it the badge reads OVERFLOW_TEXT.
const MAX_SHOWN := 9
## A count above MAX_SHOWN.
const OVERFLOW_TEXT := "9+"

## Show the count; off shows MARK_TEXT instead.
@export var shows_count: bool = true
## Seconds before this badge's first wiggle: offset each instance.
@export var wiggle_delay_seconds: float = 0.0
## Seconds between two wiggles.
@export var wiggle_interval_seconds: float = 2.4
## Peak tilt of a wiggle, degrees.
@export var wiggle_degrees: float = 8.0

var _wiggle: Tween

@onready var count_label: Label = %Count


## Shows `count` (hidden at zero or below); springs in when it turns on.
func set_count(count: int) -> void:
	var was_visible: bool = visible
	visible = count > 0
	if not visible:
		_stop_wiggle()
		return
	count_label.text = _text_for(count)
	if not was_visible:
		_arrive()
```

  - `_text_for` uses `match`/guard clauses, not nesting.
  - `_arrive` calls `AnimUtils.popup_spring_in(self)` and `_start_wiggle()`.
    Under reduce_motion it places the badge at rest and skips both.
  - `_start_wiggle` builds a looped tween: `tween_interval` for the delay,
    then the interval, then `rotation_degrees` to −deg, +deg, 0. Pivot
    centred via `Juice.set_pivot_center`. It warns and returns if
    `wiggle_interval_seconds <= 0` (a zero-length loop never ends; the
    DailyLoginPanel precedent).
  - `_stop_wiggle`.
- [ ] **Step 2 [code]:** DailyLoginPanel, the one public addition (+5
  lines):

```gdscript
## True while the day refresh() last drew is still unclaimed: the Lobby's
## daily-gift badge asks this rather than reading GameState itself.
func is_claimable() -> bool:
	return not _today.is_empty() and not _is_claimed_today(_today)
```

- [ ] **Step 3 [code]:** LobbyHud.
  - `refresh()` sets `%DailyBadge.set_count(1 if is_daily_claimable else 0)`,
    `%AchievementBadge.set_count(Achievements.total_unclaimed_count())`
    and `%InventoryBadge.set_count(_inventory_count())`.
  - `_inventory_count() -> int` sums
    `for quantity: int in GameState.inventory.values()`.
  - In `_ready`, **after** the ungated wiring, add
    `if Engine.is_editor_hint(): return`, then connect
    `Achievements.state_changed` and `GameState.inventory_changed` to a
    `_refresh_counts()` that leaves the daily badge alone. These are
    autoload side effects, so they are gated.
- [ ] **Step 4 [code]:** Failing tests.
  - **`lobby_hud`:**
    - `set_count(0)` hides; `set_count(3)` shows "3"; `set_count(12)`
      shows `OVERFLOW_TEXT`; `shows_count = false` shows `MARK_TEXT`.
      Use reduce_motion, and a bare instanced `NotifBadge.tscn` fixture.
    - `refresh(true)` shows `%DailyBadge`.
    - A seeded `GameState.inventory` shows its sum on `%InventoryBadge`.
    - The three badge instances carry distinct `wiggle_delay_seconds`.
  - **`daily_login_panel`:** on the Lobby fixture's panel,
    `refresh(_TODAY)` with `last_claim_date = _YESTERDAY` →
    `is_claimable()`. With `last_claim_date = _TODAY` → not.
- [ ] **Step 5 [editor]:** `lobby_hud` and `daily_login_panel` → FAIL.
- [ ] **Step 6 [editor], scene:**
  1. Create `Scenes/Lobby/NotifBadge.tscn`: root Panel `NotifBadge` with
     `NotifBadge.gd`, child `%Count` Label `NotifBadgeLabel` (centred,
     mouse IGNORE), root mouse IGNORE, hidden, top-right anchored. Save.
  2. In `Lobby.tscn`, instance it as `%DailyBadge` under `DailyLogin`,
     `%AchievementBadge` under `AchievementButton` (`shows_count = false`)
     and `%InventoryBadge` under `Inventory`. Give each its own
     `wiggle_delay_seconds` (0.0 / 0.8 / 1.6) **on the instance root**;
     children's overrides are dropped on save.
  3. `scene_save`, then diff.
- [ ] **Step 7 [code]:** Lobby.gd. `hud.refresh(daily_reward.is_claimable())`
  at the end of `_setup_daily_login()`, and in `_on_daily_reward_claimed`
  so the badge clears on claim (+2).
- [ ] **Step 8 [editor]:**
  1. Restart, then no-op `script_patch`.
  2. Run `lobby_hud`, `daily_login_panel`, `lobby`, `viewport_editability`,
     `script_documentation`, `project_hygiene`, `clean_code`: PASS.
  3. `project_run` with a fresh day: the gift badge pops and wiggles, the
     rail badges are offset, and the badge clears on claim.
- [ ] **Step 9:** Commit:
  `feat(lobby): notification badges wired to real state`.

**Lobby.gd after:** ≈969. **Baseline:** none. The new scripts start at
zero, and DailyLoginPanel stays clean.

## Task 7: Idle fade for the header and coin plate

**Files:** Create `Scripts/UI/IdleFade.gd` (generic, reusable). Modify
`Lobby.tscn` and `tests/test_lobby_hud.gd`. **Lobby.gd is untouched.**

- [ ] **Step 1 [code]:** The component, a new file:

```gdscript
@tool
class_name IdleFade
extends Node

## Fades `targets` to faded_alpha after idle_seconds with no input, and
## snaps them back on the next touch, click or key (2026-09-27 scrapbook
## HUD spec §3, "Idle fade"). The Lobby uses it for its header and coin
## plate; nothing else fades. It reads input in _input and never marks it
## handled, so every tap still reaches its target. The timer is the
## authored IdleTimer child, not built here. @tool so the lobby_hud suite
## can instance it; _ready's timer start is gated.

## What fades: the Lobby wires its header and coin plate here.
@export var targets: Array[CanvasItem] = []
## Seconds without input before the fade (spec: ~8 s).
@export var idle_seconds: float = 8.0
## Alpha the targets rest at while idle (spec: ~55 %).
@export var faded_alpha: float = 0.55
## Seconds the fade out takes.
@export var fade_seconds: float = 0.6
## Seconds the snap back takes.
@export var restore_seconds: float = 0.12

var _fade: Tween

@onready var idle_timer: Timer = $IdleTimer
```

  - `_ready` connects `idle_timer.timeout → fade_out` ungated, then
    `if Engine.is_editor_hint(): return`, then sets
    `idle_timer.wait_time`, `one_shot` and starts it.
  - `_input(event)` on a pressed touch, click or key calls `restore()`
    and restarts the timer.
  - Public `fade_out()` / `restore()` tween each valid target's
    `modulate:a`, killing any previous `_fade`. If a target is null they
    `push_error("IdleFade: a target is not wired in <scene>")`.
- [ ] **Step 2 [code]:** Failing tests in `lobby_hud`. On the Lobby
  fixture's `IdleFade`:
  - `targets` holds exactly `%ProgressHeader` and `%DisplayUang`
    (**not** the HUD or the diorama)
  - `idle_seconds == 8.0` and `faded_alpha == 0.55`
  - under reduce_motion, `fade_out()` then `restore()` leaves alpha 1.0

  `fade_out` / `restore` honour reduce_motion by setting the values
  directly.
- [ ] **Step 3 [editor]:** `lobby_hud` → FAIL. Scene: add `IdleFade`
  (Node, script) with an `IdleTimer` child (Timer) at the Lobby root, and
  set `targets` via `node_set_property`. `scene_save`, then diff: the
  `.tscn` must show `targets = [NodePath(…), NodePath(…)]` under
  `node_paths`. **If the bridge cannot set a `Array[CanvasItem]` of nodes**,
  change the export to two typed exports, `header: CanvasItem` and
  `wallet: CanvasItem`, rather than NodePaths resolved at runtime.
- [ ] **Step 4 [editor]:** Run `lobby_hud`, `script_documentation`,
  `viewport_editability`, `clean_code`: PASS. `project_run`: after 8 s
  idle the two plates dim and one tap restores them.
- [ ] **Step 5:** Commit: `feat(lobby): idle fade for the header and coin plate`.

**Lobby.gd after:** ≈969. **Baseline:** none.

## Task 8: Phase-1 docs, milestone run, ship

- [ ] **Step 1 [code]:** Docs.
  - **CHANGELOG.md:** a new top entry "Lobby scrapbook HUD (Phase 1)".
    Cover what shipped, Lobby.gd 993 → ≈969, and the Q1–Q8 answers.
  - **DEBT.md:** the Task 1 art entry exists. Add any dashed-rim or washi
    art still pending (Q4).
  - **`design/style-guide.md`:** the Q7 exception line under **Buttons**,
    plus the new plate/badge variations.
  - **CLAUDE.md:**
    - `## Testing` suite count → 162 suites with the new test total (from
      the run below, today's date)
    - the Lobby-hub line in `## The game`: only if its wording no longer
      holds
    - stay under the 23,000-character budget
- [ ] **Step 2 [editor]:**
  1. Open `Scenes/MainMenu/MainMenu.tscn` and take **one full `test_run`**
     (budget a restart after it; a full run drops the bridge).
  2. `git status`: keep the intended `kejartes_theme.tres` bake and
     `git checkout --` any `default_bus_layout.tres` churn.
  3. Fix real breakage and re-run the affected suites alone.
- [ ] **Step 3 [editor]:** `project_run`, seed, and take one full-size
  Lobby screenshot on a frozen frame. Sanity-check it against
  `stepped_lobby.png`. Check the tall layout with `tall_screen_layout`,
  not by eye (the embedded run is locked to 9:16).
- [ ] **Step 4:** Finish Phase 1 with the **`ship-pr`** skill. It runs the
  full suite and the review, opens the PR and stamps the tested commit.
  Bind the PR right after `gh pr create`.

---

# PHASE 2 — Dapatkan Uang panel + dev-mode ad stub

## Task 9: `ad_debt` session field

**Files:** Modify `Scripts/GameState.gd` (641 → ≈645). Create
`tests/test_dapatkan_uang.gd` (suite `dapatkan_uang`).

- [ ] **Step 1 [code]:** The failing suite. `@tool`, `##` header,
  `suite_name()` → `"dapatkan_uang"`. This is a source scan, because
  calling `forget_session()` in the editor would wipe achievement
  progress:

```gdscript
const _GAME_STATE := "res://Scripts/GameState.gd"


func test_ad_debt_is_a_session_counter() -> void:
	var src := FileAccess.get_file_as_string(_GAME_STATE)
	assert_true(src.contains("var ad_debt: int = 0"), "ad_debt is a typed int, 0 at start")
	var forget: String = src.get_slice("func forget_session()", 1).get_slice("\nfunc ", 0)
	assert_true(forget.contains("ad_debt = 0"), "Forget Session clears it")
	var saver: String = src.get_slice("func _write_inventory_to(", 1).get_slice("\nfunc ", 0)
	assert_false(saver.contains("ad_debt"), "ad_debt never reaches disk")
```

- [ ] **Step 2 [editor]:** `test_run(suite="dapatkan_uang")` → FAIL.
- [ ] **Step 3 [code]:** Implement. After `pending_earnings`, add:

```gdscript
## Ads owed from Dapatkan Uang's "ambil dulu" cash-ins; one watched owed
## ad pays one back. Session-scoped like money -- never saved.
var ad_debt: int = 0
```

  and `ad_debt = 0` in `forget_session()` beside `pending_earnings = {}`.
- [ ] **Step 4 [editor]:** Rescan, then no-op `script_patch`. Run
  `dapatkan_uang`, `project_hygiene`, `clean_code`: PASS. GameState stays
  at UNTYPED 9 and BARE 21.
- [ ] **Step 5:** Commit: `feat(gamestate): session-scoped ad_debt counter`.

## Task 10: The Dapatkan Uang panel scene and its wiring

**Files:**
- Create `Scripts/Lobby/DapatkanUang.gd` and `Scenes/Lobby/DapatkanUang.tscn`.
- Modify `Lobby.tscn`, `Lobby.gd`, `tests/test_dapatkan_uang.gd` and
  `tests/test_lobby.gd`.

**Interfaces:**
- **Produces (`class_name DapatkanUang`):**
  - `signal paid(amount: int, previous_money: int)`
  - `open()`, `close()`
  - `@export var is_dev_mode: bool = true`
- **Scene:** every node is authored.
  - a full-rect root, hidden, holding a `Scrim`
  - the book: `BookCoverPanel` / `BookPagePanel`
  - three sections:
    - **"Tonton iklan, dapat sekarang"**: `%IklanSingkat`, `%VideoPenuh`
    - **"Ambil dulu, tonton nanti"**: `%AmbilDulu4`, `%AmbilDulu8`, and
      `%TontonUtang` per Q6
    - **"Cara gratis"**: a `Card` tip, body font, the spec's Wirausaha
      copy
  - `%Tutup`
  - `%Toast` (PanelContainer `AchievementToastPanel`) holding a body-font
    `%ToastLabel` and a `%DevModeTag` (`NotifBadge` panel +
    `NotifBadgeLabel` "DEV MODE")
- **Lobby:** the `+` opens it, and its `paid` rolls the wallet through the
  handler the daily claim uses. That handler is renamed
  `_on_daily_reward_claimed` → `_on_wallet_paid`, since it now serves both.

- [ ] **Step 1 [code]:** Failing tests in `dapatkan_uang`. Use one
  instance of `DapatkanUang.tscn` in `suite_setup`, and save/restore
  `GameState.player_money` and `ad_debt`.
  - The scene holds `IklanSingkat`, `VideoPenuh`, `AmbilDulu4`,
    `AmbilDulu8`, `TontonUtang`, `Tutup`, `Toast`, `DevModeTag`.
  - `open()` shows it, and `close()` under reduce_motion hides it.
  - A Lobby source scan: `plus_button.pressed.connect(earn_panel.open)`
    and `earn_panel.paid.connect(_on_wallet_paid)`.
  - `test_lobby.gd`: `test_daily_reward_is_a_daily_login_panel`'s pin
    becomes `claimed.connect(_on_wallet_paid)`.
- [ ] **Step 2 [editor]:** `dapatkan_uang` → FAIL.
- [ ] **Step 3 [code]:** Write `DapatkanUang.gd`, a new file.
  - `##` header: signals up (`paid`), calls down (`open` / `close`). Like
    DailyLoginPanel, it owns its own GameState writes. `@tool` for the
    suite, with the `_ready` wiring ungated and nothing else.
  - `open()` plays `AudioDirector.play_sfx(&"popup_open")` and
    `AnimUtils.popup_spring_in(book)`.
  - `close()` plays `&"popup_close"` and
    `AnimUtils.popup_spring_out(book, scrim, hide)`.
  - `%DevModeTag.visible = is_dev_mode`. `%TontonUtang` is visible only
    while `GameState.ad_debt > 0`.
  - The payout handlers are Task 11. Here, the buttons connect to stubs
    that `push_warning("DapatkanUang: payouts land in Task 11")`, and
    Task 11 replaces them. No `pass`-bodied fakes.
- [ ] **Step 4 [editor], scene:**
  1. Build `DapatkanUang.tscn` from the variations above. Every text is
     Indonesian from the spec §7, and any `—`/`…` copy is in body-font
     labels. `scene_save`.
  2. In `Lobby.tscn`, instance it as `%DapatkanUang` right **after**
     `DailyReward`, so it draws over the HUD and the blur, and hide it.
     Set `%PlusUang.disabled = false`. `scene_save`, then diff.
- [ ] **Step 5 [code]:** Lobby.gd, after the save:
  - `@onready var earn_panel: DapatkanUang = %DapatkanUang` and
    `@onready var plus_button: Button = %PlusUang` (+2)
  - two lines appended to `_connect_hud_buttons()` (+2):
    `plus_button.pressed.connect(earn_panel.open)` and
    `earn_panel.paid.connect(_on_wallet_paid)`
  - rename `_on_daily_reward_claimed` → `_on_wallet_paid`, including its
    connect line. Update its `##` line: "A payout landed (the daily claim
    or Dapatkan Uang): roll the wallet up from the old balance."

  The chatter gate is unchanged. The panel's `Scrim` stops taps, and
  `student_chatter` pins `_chatter_allowed`'s exact expression.
- [ ] **Step 6 [editor]:**
  1. Restart, then no-op `script_patch`.
  2. Run `dapatkan_uang`, `lobby`, `lobby_hud`, `audio_coverage`
     (`popup_open`/`popup_close` are known ids; no double-fire, because
     UIPolish already plays `tap`), `viewport_editability`,
     `script_documentation`, `project_hygiene`, `clean_code`: PASS.
- [ ] **Step 7:** Commit: `feat(lobby): Dapatkan Uang panel opened from the coin plus`.

**Lobby.gd after:** ≈973. **Baseline:** none. `_connect_hud_buttons` is
7 lines.

## Task 11: Dev-mode payouts and toasts

**Files:** Modify `Scripts/Lobby/DapatkanUang.gd` and
`tests/test_dapatkan_uang.gd`.

- [ ] **Step 1 [code]:** Failing behavioural tests. The handlers are
  called directly. Count `paid` emissions with a typed lambda; the
  toast's text is read from `%ToastLabel`:

```gdscript
func test_a_short_ad_pays_now() -> void:
	GameState.player_money = 100
	var payouts: Array[int] = []
	var record := func(amount: int, _previous: int) -> void: payouts.append(amount)
	_panel.paid.connect(record)
	_panel._on_short_ad_pressed()
	_panel.paid.disconnect(record)
	assert_eq(GameState.player_money, 100 + DapatkanUang.SHORT_AD_REWARD)
	assert_eq(payouts.size(), 1, "paid announces it once")
	assert_eq(payouts[0], DapatkanUang.SHORT_AD_REWARD)
	assert_eq((_panel.get_node("%ToastLabel") as Label).text,
		DapatkanUang.AD_TOAST_FORMAT % DapatkanUang.SHORT_AD_REWARD)


func test_a_cash_in_pays_now_and_owes_ads() -> void:
	GameState.player_money = 0
	GameState.ad_debt = 0
	_panel._on_cash_in_pressed(DapatkanUang.CASH_IN_LARGE, DapatkanUang.CASH_IN_LARGE_ADS)
	assert_eq(GameState.player_money, DapatkanUang.CASH_IN_LARGE)
	assert_eq(GameState.ad_debt, DapatkanUang.CASH_IN_LARGE_ADS)


func test_watching_an_owed_ad_pays_one_back_and_never_goes_negative() -> void:
	GameState.ad_debt = 1
	_panel._on_owed_ad_pressed()
	assert_eq(GameState.ad_debt, 0)
	_panel._on_owed_ad_pressed()
	assert_eq(GameState.ad_debt, 0, "no debt, nothing to watch")
```

  plus `test_the_dev_mode_tag_follows_is_dev_mode`.
- [ ] **Step 2 [editor]:** `dapatkan_uang` → FAIL.
- [ ] **Step 3 [code]:** Implement.
  - Replace the Task 10 stubs.
  - Put the amounts in one named block. The spec's values are unchanged;
    they are **proposals**, not `Balance.gd` values:

```gdscript
## Reward amounts (2026-09-27 spec §7). Balance proposals for the
## Balance.gd owner (docs/superpowers/specs/2026-09-27-earn-money-balance-
## proposal.md); ours until accepted, never written into Balance.gd.
const SHORT_AD_REWARD := 150
const FULL_AD_REWARD := 450
const CASH_IN_SMALL := 900
const CASH_IN_SMALL_ADS := 4
const CASH_IN_LARGE := 2000
const CASH_IN_LARGE_ADS := 8

## Toast copy (spec §7's table). Body font: "—" and "…" are not in Boohong.
const AD_TOAST_FORMAT := "Sukses! Mentransfer +%d koin ke kas kelas…"
const CASH_IN_TOAST_FORMAT := "Sukses! +%d koin — %d iklan menunggu"
const OWED_AD_TOAST := "Sukses menonton iklan!"
## The owed-ad button's label; %d is GameState.ad_debt (Q6).
const OWED_AD_BUTTON_FORMAT := "Tonton iklan tertunda (%d)"
```

  - `@export var toast_seconds: float = 2.0`, with a `##` line.
  - The single payout writer, so there is one place that emits:

```gdscript
## Pays `amount` into the class fund and announces it for the Lobby's
## wallet roll. Dev mode pays at once; a real ad SDK would call this from
## its reward callback instead, and nothing else would change.
func _pay(amount: int) -> void:
	var previous_money: int = GameState.player_money
	GameState.player_money += amount
	paid.emit(amount, previous_money)
```

  - `_on_short_ad_pressed`, `_on_full_ad_pressed`,
    `_on_cash_in_pressed(amount: int, ads: int)` (bound in `_ready`) and
    `_on_owed_ad_pressed` (a guard clause at `ad_debt <= 0`). Each is ≤ 10
    lines.
  - `_show_toast(text)` uses `AnimUtils.message_pop(toast, toast_seconds)`.
  - `_refresh_owed_ad()`.
  - Do **not** call `Achievements.record_money` from a dev stub.
- [ ] **Step 4 [editor]:**
  1. Restart, then no-op `script_patch`.
  2. Run `dapatkan_uang`, `lobby`, `script_documentation`,
     `project_hygiene`, `audio_coverage`, `clean_code`: PASS.
  3. `project_run`, seed: `+` → panel → each option. Check the money
     roll, the toast with DEV MODE, `ad_debt` rising and falling, and the
     owed-ad button appearing and disappearing.
- [ ] **Step 5:** Commit: `feat(lobby): dev-mode earn-money payouts and toasts`.

**Lobby.gd after:** ≈973. **Baseline:** none.

## Task 12: Balance proposal and ad-policy note

- [ ] **Step 1 [code]:** Write
  `docs/superpowers/specs/2026-09-27-earn-money-balance-proposal.md`.
  - **Amounts:** +150 / +450 / +900 (4 ads) / +2000 (8 ads).
  - **Rationale:**
    - Wirausaha earns 120–320 G/day/student
      (`Balance.WIRAUSAHA_UANG_MIN/MAX`).
    - Items cost 400–1500 G (`ItemDatabase.gd`).
    - The daily-login week totals 1500 G (`DailyLoginPanel.REWARD_CURVE`).
  - **Options for the Balance.gd owner:** accept the values and move them
    into `Balance.gd` (then DapatkanUang reads `Balance`), or adjust
    them.
  - **Deferred gate:** the COPPA / GDPR-K / ad-content-rating check
    before any real ad SDK.
- [ ] **Step 2:** Commit:
  `docs(lobby): earn-money reward proposal for the Balance owner`.

## Task 13: Phase-2 docs, final run, ship

- [ ] **Step 1 [code]:** Docs.
  - **CHANGELOG.md:** "Dapatkan Uang (Phase 2)". Cover the panel, the
    dev-mode stub, `ad_debt`, and Lobby.gd ≈973.
  - **DEBT.md, "Deferred and pending":**
    - the dev-mode stub still awaits an ad SDK behind the policy gate
    - the amounts await the Balance owner's sign-off
  - **CLAUDE.md:**
    - `## Testing` → 163 suites and the new test total, with the date
    - one clause in `## The game`'s loop line: the Lobby's coin `+` opens
      Dapatkan Uang. Only if it fits the budget.
- [ ] **Step 2 [editor]:**
  1. Open `Scenes/MainMenu/MainMenu.tscn` and take one full `test_run`
     (restart after).
  2. Check `git status` and discard unintended churn.
  3. Run `clean_code` alone: PASS, no un-locked shrink.
- [ ] **Step 3 [editor]:** `project_run`, then walk the coin `+` → panel →
  each option end to end.
- [ ] **Step 4:** Finish with **`ship-pr`**, binding the PR right after
  `gh pr create`.

---

## Self-review (revised)

- **Spec coverage:**
  - §3: header (T3), coin plate and green `+` (T2, T3), rail (T4), idle
    fade (T7)
  - §4: stepped book (T4); swipe, squash, peek bob, hint, chevron
    hinge, entrance stagger and JADWAL breathe (T5); colour tiles (T2,
    T4, Q3)
  - §5: badges, pop and offset wiggle (T6); star-bar sparkle-fill (T3,
    Q8)
  - §6: variations and art (T1, T2); DEBT (T1, T8)
  - §7: panel (T10), dev stub, toasts and `ad_debt` (T9, T11), Balance
    and policy (T12)
  - Deferred, logged in DEBT: washi flutter and dashed rims (Q4); the
    optional coin flip and chat-bubble squash (spec "optional garnish").
- **Lobby.gd budget:**
  - 993 → T0 964 → T3 966 → T5 967 → T6 969 → T10 973.
  - Never above today's count, and no new function over 50 lines.
  - Every new behaviour lives in `LobbyProgressHeader`, `LobbyHud`,
    `NotifBadge`, `IdleFade` or `DapatkanUang`.
- **Ratchet:**
  - Only T0 and T5 lower Lobby.gd's entries; the dump runs in the same
    commit.
  - No re-key: nothing with a baseline key moves.
  - New scripts start at zero.
- **Consistent names:**
  - variations: `BookHeroButton`, `NavTile*`, `PlusButton`,
    `ChevronGripButton`, `BookCoverPanel`, `BookPagePanel`, `CoinPlate`,
    `ProgressPlate`, `GradeBadge*`, `WeekLabel`, `StarProgressBar`,
    `StarNumLabel`, `NotifBadge*`, `RosterChip`
  - nodes: `%ProgressHeader`, `%DisplayUang`/`%PlusUang`, `%Hud`,
    `%BookHud`, `%RaisedBlock`, `%RaisedPage`, `%Shelf`, `%ChevronGrip`,
    `%IconRail`, `%*Badge`, `%DapatkanUang`
  - methods: `refresh`, `activate`, `set_open`, `tap_blockers`,
    `set_count`, `is_claimable`, `fade_out`/`restore`, `open`/`close`,
    `_pay`, `_on_wallet_paid`
