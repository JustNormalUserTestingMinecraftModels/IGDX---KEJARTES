# Loby Final Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> ## ⛔ STOP — CONFIRM BEFORE YOU BUILD
> This plan is a handoff from another session. **Before starting Task 1, ask the
> user (the KejarTes owner) exactly this and wait for an answer:**
>
> > "I've picked up the Loby Final Polish plan on branch `LobyFinalpolish`. Before
> > I build anything — **is this design final, or are there revisions you still
> > want?** If it's final I'll start Phase 1 task by task; if not, tell me what to
> > change and I'll fold it in first."
>
> Only proceed once they confirm it's final. If they want changes, revise the
> spec + this plan first, then re-confirm. Do not skip this gate.

**Goal:** Restyle the KejarTes lobby bottom UI into a cute "scrapbook" HUD — a
stepped book housing the JADWAL! + color-coded nav buttons, a grade/week header,
notification badges, a bouncy swipe-away HUD — then add a Phase-2 "Dapatkan Uang"
earn-money panel with a dev-mode ad stub.

**Architecture:** All visuals are `ThemeFactory` type variations + 9-patch PNG
art placed as nodes in `Scenes/Lobby/loby.tscn` — never `theme_override_*`, never
runtime construction (CLAUDE.md § Visual system). Motion uses the existing
`Scripts/Design/Juice.gd` and `Scripts/AnimUtils.gd`. State reads from `GameState`.

**Tech Stack:** Godot 4.6, GDScript, the `godot-ai` MCP editor bridge, `McpTestSuite`
source-scan tests run via `test_run`.

**Spec:** `docs/superpowers/specs/2026-09-27-lobby-scrapbook-hud-design.md` (read it
first, with the reference mockups in `specs/assets/lobby-scrapbook-hud/`). The plan
argues from the spec; read both.

## Global Constraints

- **Never add a `theme_override_*`.** Add a `ThemeFactory` variation and rebake. Only
  layout-only constant overrides (`separation`, `margin_*`) are allowed inline.
- **No visual built at runtime.** Static chrome = nodes in the `.tscn`; repeated tiles
  = a `PackedScene` template; the ratchet is `tests/test_viewport_editability.gd`.
- **Every script needs `##` docs** — a file header and a `##` on every `@export`
  (`tests/test_script_documentation.gd`).
- **The four utility icon buttons are fixed art.** `DailyLogin`, `SettingsButton`,
  `AchievementButton`, `SkinSwitchButton` — art untouched; they may only move and gain
  badges. (See the `lobby-icon-buttons-fixed-assets` memory.)
- **UI text is Indonesian; systems code is English.** Keep the misspelled load-bearing
  names (`loby.gd`).
- **`Balance.gd` is the collaborator's.** The reward amounts (+150/+450/+900/+2000) are
  proposals — do not edit `Balance.gd`; propose (Task 14).
- **The coin `+` is green, never gold** — money is in-game G, no IAP implied.
- **Do not add persistence.** `GameState.ad_debt` (Task 11) is session-scoped like
  money/roster.
- **Editor workflow** (CLAUDE.md § Working efficiently): scene edits go through the
  editor MCP (`scene_open` → `node_*`/`batch_execute` → `scene_save`), never hand-edit a
  `.tscn` while attached. Do scene work before script work. Normalise `.gd` to LF before
  `script_patch`. Rebake the theme via a transient `@tool` `McpTestSuite` that calls
  `ThemeFactory.build()` + `ResourceSaver.save()` (there is no MCP entry for
  `BakeTheme.gd`). Prefer targeted `test_run(suite=...)`; budget one editor restart per
  full run. Check `git status` after a full run (it rewrites `kejartes_theme.tres` and
  `default_bus_layout.tres`).
- **Commits:** Conventional Commits with a scope, e.g. `feat(lobby): …`. Finish each
  phase with the `ship-pr` skill.

---

## File Structure

- `Scripts/Design/ThemeFactory.gd` — add the new lobby variations (Tasks 1–2).
- `tests/test_theme_factory.gd` — extend coverage + `DISPLAY_ROSTER` (Tasks 1–2).
- `Scenes/Lobby/loby.tscn` — header, coin box, stepped book HUD, right rail (Tasks 3–8).
- `Scripts/Lobby/loby.gd` — wiring: state → header/badges, swipe, idle fade (Tasks 3–8).
- `tests/test_loby_hud.gd` — **new** source-scan suite for the HUD (Tasks 3–8).
- `Assets/Images/UI/LobyHud/` — **new** 9-patch placeholder art (Task 9).
- `Scripts/GameState.gd` — `ad_debt` field (Task 11).
- `Scenes/Lobby/DapatkanUang.tscn` + `Scripts/Lobby/DapatkanUang.gd` — **new** panel
  (Tasks 12–13).
- `tests/test_dapatkan_uang.gd` — **new** suite (Tasks 12–13).
- `docs/superpowers/DEBT.md` and the CLAUDE.md debt section — placeholder entries (Task 9).

Each suite extends `McpTestSuite`, is `@tool`, and has no coroutine tests (CLAUDE.md
§ Testing). Follow the established **source-text scan** pattern (`src.contains(...)`) —
most of this UI cannot be instantiated headlessly.

---

# PHASE 1 — Lobby restyle, HUD, animations (pure UI)

## Task 1: Book-hero + nav-tile theme variations

Replace the flat `LobbyCtaButton`/`LobbyNavTile` look with the scrapbook buttons:
one green hero (`BookHeroButton`) and three color-coded tiles. Colors come from
`design_tokens.tres` ramps — reuse the tokens `LobbyNavTile` already uses, plus the
accent tokens for blue/amber (find the nearest existing token; if none, add tokens to
`DesignTokens.gd` and rebake — a new `@export` needs a full editor restart).

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (near the existing lobby block, ~line 205)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Produces: theme type variations `BookHeroButton`, `NavTileKoperasi`,
  `NavTileInventory`, `NavTileRapor` — each a `Button` variation built via the existing
  `_add_button_variation(theme, tokens, name, fill_light, fill_dark, outline, text)`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_theme_factory.gd`:

```gdscript
func test_scrapbook_lobby_variations_exist() -> void:
    var src := _read("res://Scripts/Design/ThemeFactory.gd")
    for name in ["BookHeroButton", "NavTileKoperasi", "NavTileInventory", "NavTileRapor"]:
        assert_true(src.contains('"%s"' % name), "%s variation missing" % name)
```

(Use the suite's existing file-read helper; if none, `FileAccess.get_file_as_string`.)

- [ ] **Step 2: Run it, verify it fails** — `test_run(suite="test_theme_factory")`,
  expect the new test failing on the missing names.
- [ ] **Step 3: Implement** — in `ThemeFactory.gd`, after the `LobbyCtaButton` block,
  add the four variations. Model them on `LobbyNavTile`/`LobbyCtaButton` (lines 205–224).
  `BookHeroButton` = green like `LobbyCtaButton` (`brand_primary_light/dark`), horizontal
  icon, `font_h1`. Each `NavTile*` = stacked icon-over-label like `LobbyNavTile`, with its
  own fill: Koperasi green (`brand_primary_*`), Inventory + Rapor from the blue/amber
  accent tokens. Keep the dashed-border + bottom-lip look by adjusting the stylebox the
  helper builds (add a heavier bottom `border_width_bottom` for the 3D lip).
- [ ] **Step 4: Rebake + run** — run the transient rebake suite (Global Constraints),
  then `test_run(suite="test_theme_factory")`; expect PASS. If a new `DesignTokens`
  `@export` was added, restart the editor first.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(lobby): scrapbook book-hero and color-coded nav tile variations"`

## Task 2: Header plates, badge, and header labels

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Produces: `CoinPlate`, `ProgressPlate` (Panel variations, cream paper plate with lip),
  `GradeBadge`, `WeekLabel`, `StarNumLabel` (Label variations, `font_display`), `NotifBadge`
  (Panel variation, red pill).

- [ ] **Step 1: Failing test** — extend `test_theme_factory.gd`:

```gdscript
func test_header_and_badge_variations_exist() -> void:
    var src := _read("res://Scripts/Design/ThemeFactory.gd")
    for name in ["CoinPlate", "ProgressPlate", "GradeBadge", "WeekLabel", "StarNumLabel", "NotifBadge"]:
        assert_true(src.contains('"%s"' % name), "%s missing" % name)
```

- [ ] **Step 2: Run, verify fail** — `test_run(suite="test_theme_factory")`.
- [ ] **Step 3: Implement** — add the Panel variations modelled on `Card`
  (lines 474–475) with a cream fill + bottom-lip stylebox; add the Label variations
  modelled on the display-label block (~line 597), all using `font_display`. `NotifBadge`
  = a small red pill Panel.
- [ ] **Step 4: Update `DISPLAY_ROSTER`** — the display-font labels (`GradeBadge`,
  `WeekLabel`, `StarNumLabel`) must be added to `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd` or the suite fails (CLAUDE.md § Visual system). Rebake,
  then `test_run(suite="test_theme_factory")`; expect PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): header plate, label, and notif-badge variations"`

## Task 3: Grade/week progress header

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (add header under `Safe/UI`), `Scripts/Lobby/loby.gd`
- Test: `tests/test_loby_hud.gd` (new)

**Interfaces:**
- Consumes: `GameState.current_grade`, the week counter, `GameState.run_stars()`.
- Produces: `loby.gd` method `_refresh_header()` that fills the badge/week/star nodes.

- [ ] **Step 1: Create the suite + failing test** — new `tests/test_loby_hud.gd`
  (`@tool extends McpTestSuite`, `##` header):

```gdscript
func test_header_reads_gamestate() -> void:
    var src := _read("res://Scripts/Lobby/loby.gd")
    assert_true(src.contains("run_stars"), "header must read run_stars()")
    assert_true(src.contains("current_grade"), "header must read current_grade")
    var scene := _read("res://Scenes/Lobby/loby.tscn")
    assert_true(scene.contains("ProgressPlate"), "header plate not placed")
    assert_true(scene.contains("GradeBadge"), "grade badge not placed")
```

- [ ] **Step 2: Run, verify fail** — `test_run(suite="test_loby_hud")`.
- [ ] **Step 3: Implement (scene first)** — via the editor MCP: `scene_open` loby.tscn,
  add under `Safe/UI` a `ProgressPlate` Panel containing the `GradeBadge` label
  ("KELAS"/grade), a `WeekLabel` ("Minggu N / total"), and a `StatBar` + `StarNumLabel`
  for `run_stars()` of 3.0. Anchor top-left inside `SafeAreaMargin`. `scene_save`.
- [ ] **Step 4: Implement (script)** — restart the editor (Global Constraints), then
  `script_patch` `loby.gd`: add `_refresh_header()` reading `GameState.current_grade`, the
  week, and `run_stars()`, called from `_ready()` (gate side effects behind
  `if Engine.is_editor_hint(): return` per CLAUDE.md § Testing). Rescan, then
  `test_run(suite="test_loby_hud")`; expect PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): grade/week/stars progress header"`

## Task 4: Coin box + green plus button

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (`DisplayUang`), `Scripts/Lobby/loby.gd`
- Test: `tests/test_loby_hud.gd`

**Interfaces:**
- Produces: a `PlusUang` Button on the coin box; `loby.gd` connects its `pressed` to
  `_on_plus_uang()` (Phase 1: opens nothing yet — leave a documented stub that Task 12
  fills; do **not** route it to ShopHub as a fake).

- [ ] **Step 1: Failing test:**

```gdscript
func test_coin_box_has_green_plus() -> void:
    var scene := _read("res://Scenes/Lobby/loby.tscn")
    assert_true(scene.contains("PlusUang"), "plus button not placed")
    assert_true(scene.contains("CoinPlate"), "coin box not on CoinPlate")
    var src := _read("res://Scripts/Lobby/loby.gd")
    assert_true(src.contains("_on_plus_uang"), "plus handler missing")
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Scene** — retheme `DisplayUang` to `CoinPlate`; add a `PlusUang` Button
  (`SuccessButton`-style green) with the plus icon. `scene_save`.
- [ ] **Step 4: Script** — add `_on_plus_uang()` (Phase 1 body: `pass` with a `##` comment
  "Task 12 opens DapatkanUang.tscn here."); connect it. Rescan; `test_run` PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): coin plate with green plus button"`

## Task 5: Stepped book HUD housing + right rail

**Files:**
- Modify: `Scenes/Lobby/loby.tscn`, `Scripts/Lobby/loby.gd`
- Test: `tests/test_loby_hud.gd`

**Interfaces:**
- Produces: a `BookHud` Control containing `RaisedBlock` (JADWAL on `BookHeroButton`),
  `Shelf` (the three tiles), and `ChevronGrip` Button; a `IconRail` VBox holding the four
  fixed icon buttons (moved, art unchanged).

- [ ] **Step 1: Failing test:**

```gdscript
func test_stepped_book_hud_present() -> void:
    var scene := _read("res://Scenes/Lobby/loby.tscn")
    for n in ["BookHud", "RaisedBlock", "Shelf", "ChevronGrip", "IconRail"]:
        assert_true(scene.contains(n), "%s missing" % n)
    assert_true(scene.contains("BookHeroButton"), "JADWAL not on BookHeroButton")
    for t in ["NavTileKoperasi", "NavTileInventory", "NavTileRapor"]:
        assert_true(scene.contains(t), "%s not placed" % t)
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Scene** — build the stepped silhouette from the 9-patch art (Task 9 draft
  placeholders first, or grey boxes swapped later): `BookHud` anchored bottom, `RaisedBlock`
  (~62% width, left) holds the `BookHeroButton` JADWAL! with a `6 murid` chip and subtitle
  (**inset the chip so it clears the block's right edge** — the mockup clipped it), `Shelf`
  full-width below holds the three retitled tiles, `ChevronGrip` caps the block. Move the
  four icon buttons into `IconRail` on the right edge (do not alter their `texture_normal`).
  `scene_save`.
- [ ] **Step 4: Verify** — `test_run(suite="test_loby_hud")`; expect PASS. Screenshot once
  at full size (CLAUDE.md § Working efficiently) to sanity-check the silhouette.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): stepped book HUD housing and icon rail"`

## Task 6: Swipe-away HUD (chevron / drag) with bouncy motion

**Files:**
- Modify: `Scripts/Lobby/loby.gd`
- Test: `tests/test_loby_hud.gd`

**Interfaces:**
- Consumes: `Juice` (`press`/`release`), `AnimUtils.squash_bounce`.
- Produces: `loby.gd` methods `_toggle_hud(open: bool)`, `_hud_open: bool`; a `Tween`
  with `TRANS_BACK`/`EASE_OUT` sliding `BookHud` + `IconRail` together.

- [ ] **Step 1: Failing test:**

```gdscript
func test_hud_swipe_wired() -> void:
    var src := _read("res://Scripts/Lobby/loby.gd")
    assert_true(src.contains("_toggle_hud"), "toggle missing")
    assert_true(src.contains("TRANS_BACK"), "overshoot easing missing")
    assert_true(src.contains("squash_bounce"), "squash-on-land missing")
    assert_true(src.contains("double"), "double-tap reopen missing (double_click/tap)")
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — `_toggle_hud(open)` tweens `BookHud.position.y` (and the rail)
  with `Tween.TRANS_BACK`/`EASE_OUT` (bouncy overshoot, "Feel A"), rotates the chevron glyph
  180°, and on arrival calls `AnimUtils.squash_bounce(BookHud)`. Wire `ChevronGrip.pressed`
  and a vertical drag to toggle; wire a double-tap on the lobby background to reopen when
  hidden; add an idle bob on the peeking chevron while hidden. Use the `motion-lab` skill to
  dial the exact curve on a live preview.
- [ ] **Step 4: Verify** — rescan; `test_run(suite="test_loby_hud")` PASS. `project_run`
  and confirm the swipe/squash feel by eye.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): bouncy swipe-away HUD with squash and idle bob"`

## Task 7: Notification badges wired to real state

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (badges on `IconRail` items + Inventory tile),
  `Scripts/Lobby/loby.gd`
- Test: `tests/test_loby_hud.gd`

**Interfaces:**
- Consumes: the daily-reward "unclaimed" flag, the "achievement claimable" check, the
  inventory item count (find the existing accessors; the lobby already shows a `DailyReward`
  node and there is an `AchievementButton`).
- Produces: `_refresh_badges()` that shows/hides each `NotifBadge` and, when it turns on,
  plays `AnimUtils.popup_spring_in` + a periodic offset `Juice.shake` wiggle.

- [ ] **Step 1: Failing test:**

```gdscript
func test_badges_wired_to_state() -> void:
    var scene := _read("res://Scenes/Lobby/loby.tscn")
    assert_true(scene.contains("NotifBadge"), "badge nodes missing")
    var src := _read("res://Scripts/Lobby/loby.gd")
    assert_true(src.contains("_refresh_badges"), "badge refresh missing")
    assert_true(src.contains("popup_spring_in"), "badge pop-in missing")
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Scene** — add `NotifBadge` nodes (hidden by default) to the daily-gift and
  achievement icons and the Inventory tile. `scene_save`.
- [ ] **Step 4: Script** — `_refresh_badges()` sets each badge's visibility + count from
  real state, pops it in with `AnimUtils.popup_spring_in`, and starts an **offset** wiggle
  so they don't move in unison; hide at zero. Also add the header star-bar `Juice.fill_bar`
  + sparkle when stars change. Rescan; `test_run` PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): notification badges wired to state with pop and wiggle"`

## Task 8: Idle fade for header + coin box

**Files:**
- Modify: `Scripts/Lobby/loby.gd`
- Test: `tests/test_loby_hud.gd`

**Interfaces:**
- Produces: an idle timer (~8s) that eases header+coin `modulate:a` to ~0.55 and snaps back
  to 1.0 on any input.

- [ ] **Step 1: Failing test:**

```gdscript
func test_idle_fade_present() -> void:
    var src := _read("res://Scripts/Lobby/loby.gd")
    assert_true(src.contains("idle") and src.contains("modulate"), "idle fade missing")
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — a `Timer` (or accumulated `_process` delta) reset on
  `_input`/`_gui_input`; after ~8s tween header+coin `modulate.a` to 0.55; on input tween
  back to 1.0. Do not fade the HUD or the diorama.
- [ ] **Step 4: Verify** — rescan; `test_run` PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): idle fade for header and coin box"`

## Task 9: Placeholder art + debt entries

**Files:**
- Create: `Assets/Images/UI/LobyHud/` 9-patch PNGs (book cover/spine, page-edge, chevron
  grip, cream plate, notif badge) — transparent, drop-replaceable at fixed paths.
- Modify: `docs/superpowers/DEBT.md` and CLAUDE.md § Outstanding debt.

- [ ] **Step 1** — generate transparent placeholder 9-patches (the project uses
  PowerShell + `System.Drawing` for these; match that). Wire them into the Task-5 nodes,
  replacing any grey boxes.
- [ ] **Step 2** — add one grouped debt entry naming the `LobyHud/` set as generated
  placeholder art, drop-replaceable at the same path with no code change.
- [ ] **Step 3: Commit** — `git commit -am "chore(lobby): placeholder HUD 9-patch art and debt notes"`

## Task 10: Phase-1 milestone verification

- [ ] **Step 1** — open `Scenes/MainMenu/main_menu.tscn` (some suites need it), take one
  full `test_run`. Budget an editor restart after (a full run drops the bridge).
- [ ] **Step 2** — `git status`: `git checkout --` any unintended `kejartes_theme.tres` /
  `default_bus_layout.tres` churn (keep an intended rebake).
- [ ] **Step 3** — `project_run`, screenshot the lobby at full size, sanity-check against
  `specs/assets/lobby-scrapbook-hud/stepped_lobby.png`.
- [ ] **Step 4** — finish Phase 1 with the `ship-pr` skill (opens the PR from
  `LobyFinalpolish`).

---

# PHASE 2 — Dapatkan Uang panel + dev-mode ad stub

## Task 11: `ad_debt` session field

**Files:**
- Modify: `Scripts/GameState.gd`
- Test: `tests/test_dapatkan_uang.gd` (new)

**Interfaces:**
- Produces: `GameState.ad_debt: int` (defaults 0; reset in the same place
  `player_money`/`pending_earnings` reset, ~line 421). **Not persisted.**

- [ ] **Step 1: Failing test** (new suite `tests/test_dapatkan_uang.gd`):

```gdscript
func test_ad_debt_field_exists_and_resets() -> void:
    var src := _read("res://Scripts/GameState.gd")
    assert_true(src.contains("ad_debt"), "ad_debt field missing")
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — add `var ad_debt: int = 0` with a `##` doc line; reset it to
  0 wherever money/roster reset. Do **not** add it to any `save`/`load` path.
- [ ] **Step 4: Verify** — rescan; `test_run(suite="test_dapatkan_uang")` PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(gamestate): session-scoped ad_debt counter"`

## Task 12: Dapatkan Uang panel scene

**Files:**
- Create: `Scenes/Lobby/DapatkanUang.tscn`, `Scripts/Lobby/DapatkanUang.gd`
- Modify: `Scripts/Lobby/loby.gd` (`_on_plus_uang` opens it)
- Test: `tests/test_dapatkan_uang.gd`

**Interfaces:**
- Produces: a popup scene with the three sections from `earn_over_lobby.png` — two ad
  buttons, two cash-in buttons, a Wirausaha tip card, and a close button; over a `Scrim`.

- [ ] **Step 1: Failing test:**

```gdscript
func test_panel_scene_and_open_wired() -> void:
    var scene := _read("res://Scenes/Lobby/DapatkanUang.tscn")
    for n in ["IklanSingkat", "VideoPenuh", "AmbilDulu4", "AmbilDulu8", "TutupBtn"]:
        assert_true(scene.contains(n), "%s missing" % n)
    var loby := _read("res://Scripts/Lobby/loby.gd")
    assert_true(loby.contains("DapatkanUang"), "plus does not open panel")
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Scene** — build `DapatkanUang.tscn` (book-paper panel on a `Scrim`, styled
  with the scrapbook variations) with the five buttons + the tip card copy (Indonesian, from
  the spec). `scene_save`. Then update `loby.gd`'s `_on_plus_uang()` to instance/show it.
- [ ] **Step 4: Verify** — rescan; `test_run(suite="test_dapatkan_uang")` PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): Dapatkan Uang panel scene"`

## Task 13: Dev-mode payouts + toasts

**Files:**
- Modify: `Scripts/Lobby/DapatkanUang.gd`
- Test: `tests/test_dapatkan_uang.gd`

**Interfaces:**
- Consumes: `GameState.player_money`, `GameState.ad_debt`, the existing achievement-toast
  presenter (reuse its style; find the class that shows the unlock banner).
- Produces: handlers that, in dev mode, add money / adjust `ad_debt` and show a success
  toast with a `DEV MODE` tag — no ad SDK.

- [ ] **Step 1: Failing test:**

```gdscript
func test_devmode_payouts_and_toasts() -> void:
    var src := _read("res://Scripts/Lobby/DapatkanUang.gd")
    assert_true(src.contains("ad_debt"), "cash-in must touch ad_debt")
    assert_true(src.contains("kas kelas"), "success toast copy missing")
    assert_true(src.contains("DEV") , "dev-mode tag missing")
    # amounts (Balance proposals)
    for amt in ["150", "450", "900", "2000"]:
        assert_true(src.contains(amt), "reward amount %s missing" % amt)
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — wire each button per the spec's table: short `+150`, full
  `+450` → `player_money +=`, toast "Sukses! Mentransfer +N koin ke kas kelas…"; cash-in
  `+900`/`+2000` → money += and `ad_debt += 4`/`8`, toast "Sukses! +N koin — M iklan
  menunggu"; an owed-ad watch → `ad_debt -= 1`, toast "Sukses menonton iklan!". Show the
  red `DEV MODE` tag while stubbed. Put the amounts in a named `const` block (not inline),
  commented as Balance proposals.
- [ ] **Step 4: Verify** — rescan; `test_run(suite="test_dapatkan_uang")` PASS. `project_run`,
  open the panel, tap each option, confirm money + toast + `ad_debt`.
- [ ] **Step 5: Commit** — `git commit -am "feat(lobby): dev-mode earn-money payouts and toasts"`

## Task 14: Balance proposal + policy note

**Files:**
- Create: `docs/superpowers/specs/2026-09-27-earn-money-balance-proposal.md`

- [ ] **Step 1** — write a short doc proposing the reward amounts (+150/+450/+900/+2000)
  with the economy rationale (Wirausaha 120–320/day, items 400–1500) for the `Balance.gd`
  owner to accept/adjust. Note the deferred ad-SDK kids/ad-policy check (COPPA/GDPR-K).
- [ ] **Step 2: Commit** — `git commit -am "docs(lobby): earn-money reward amount proposal for Balance owner"`

## Task 15: Phase-2 milestone verification

- [ ] **Step 1** — full `test_run` (budget an editor restart), `git status` check.
- [ ] **Step 2** — `project_run`, exercise the coin `+` → panel → each option end to end.
- [ ] **Step 3** — finish with the `ship-pr` skill.

---

## Self-Review (author)

- **Spec coverage:** layout (T3–T5), stepped book housing (T5), color-coded nav (T1),
  header (T2–T3), coin box + green plus (T2, T4), fixed icons on rail (T5), swipe + squash
  + idle bob (T6), badges + sparkle-fill (T7), idle fade (T8), art/debt (T9), Dapatkan Uang
  panel (T12), dev-mode stub + toasts + ad_debt (T11, T13), amounts as Balance proposal
  (T14), ad-policy deferral (T14). All spec sections map to a task.
- **Placeholder scan:** no "TBD"/"handle edge cases"; each task names files, gives test
  code, and names the exact variations/nodes/methods.
- **Type consistency:** variation names (`BookHeroButton`, `NavTile*`, `CoinPlate`,
  `ProgressPlate`, `NotifBadge`), node names (`BookHud`, `RaisedBlock`, `Shelf`,
  `ChevronGrip`, `IconRail`, `PlusUang`, `DapatkanUang`), and methods (`_refresh_header`,
  `_on_plus_uang`, `_toggle_hud`, `_refresh_badges`) are used consistently across tasks.
