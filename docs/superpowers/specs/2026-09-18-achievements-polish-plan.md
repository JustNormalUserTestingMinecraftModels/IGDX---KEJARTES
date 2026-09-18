# Achievements screen polish + debug hook

Handoff spec for the achievements screen rework. Bounded scope: relayout
`Scenes/Achievements/achievements.tscn`, add prize-forward feedback, wire
a debug panel to exercise the (already-working) unlock toast.

Author: brainstormed 2026-09-18 with hoseagimbil. Approved direction: **A+D
hybrid** (2-col grid tiles with progress bars, tap to expand for detail +
Klaim button), **one morphing header pill**, **no tier ladder**
(Perunggu/Perak/Emas has no art and would add placeholder debt).

## Current state — read first

- `Scenes/Achievements/achievements.tscn` — single-column VBox of
  `AchievementRow.tscn` cards, no filter, no header stats.
- `Scripts/Achievements/achievements_screen.gd` — instantiates one row per
  `AchievementCatalog.ENTRIES` entry in catalog order.
- `Scripts/Achievements/AchievementCatalog.gd` — 26 entries. Each already
  carries `prize: String` (some empty, some like `"Hasil Wirausaha +5%"`).
  **No schema change needed for prize text.**
- `Scripts/Achievements/Achievements.gd` — tracks `unlocked`/`claimed`
  state, emits `unlocked(id)` signal on unlock, persists to
  `user://achievements.cfg`. `state_of(id)` returns `STATE_LOCKED`,
  `STATE_UNLOCKED`, or `STATE_CLAIMED`.
- `Scripts/Achievements/AchievementToast.gd` — autoload, already listens to
  `Achievements.unlocked` and slides a banner from the top. Works today,
  just not visible in debug.
- Assets available: `achievement_button.png`, `back_arrow.png`,
  `bg_achievements_blur.jpg`, `card_claimed.png`, `ribbon_achievements.png`,
  per-achievement icons in `Assets/Images/Achievements/Icons/`. **No tier
  or coin/medal art.** No new placeholder art in this pass — the coin icon
  for the header pill reuses an existing money icon from the shop (grep
  `Assets/Images/Shop/` or `Assets/Images/UI/` for `coin`/`money`; if none
  fits, a simple `€`-shaped SVG placeholder goes in
  `Assets/Images/Achievements/coin_stack.png` and gets logged in
  `docs/superpowers/DEBT.md`).

## Design

### Grid layout (replaces VBox of rows)

- `%List` becomes a `GridContainer` with `columns = 2`, or a
  `VBoxContainer` of paired HBox rows if `GridContainer` won't wrap the way
  we need under `SafeAreaMargin`. Prefer `GridContainer`.
- New template `Scenes/Achievements/AchievementTile.tscn` replaces
  `AchievementRow.tscn` (keep the old file around until suite passes, then
  delete). Root is a `PanelContainer` with the `Card` type variation from
  `ThemeFactory`. Fixed square-ish aspect (`custom_minimum_size` set on
  the tile so both columns line up).
- Tile contents:
  - Icon (`TextureRect`, ~72×72, top-center).
  - Title (`Label`, `CaptionLabel` variation, 2-line ellipsis, center).
  - **Prize chip** (small `PanelContainer` under title). Reads
    `entry.prize`; when empty, shows a subtle "—" so the row height
    stays consistent. Chip colored by tier of the effect — plain (no
    effect) = neutral; effect present (money/stat/time bonus) = amber.
  - Progress bar (thin, 4 px). For entries with numeric `target`
    (`streak`, `total`, `money`, `fast`), read current progress from
    `Achievements.gd` — add a `progress_of(id) -> float` helper (0.0-1.0)
    that returns 1.0 for one-shot kinds. For one-shot kinds
    (`three_star`, `play_all`, `grade`) the bar is either 0 or 100%.
  - State badges (top-right corner):
    - `STATE_UNLOCKED` (unclaimed): green "BARU" pip + `Juice.pop_in` on
      first show that session.
    - `STATE_CLAIMED`: check icon.
    - `STATE_LOCKED`: 55% modulate, small lock overlay on the icon.

### Tap-to-expand

- Tile press → open a small modal sheet (`Scenes/Achievements/AchievementDetailSheet.tscn`,
  new). Reuses `Scrim` variation for the dim backdrop. Content: full-size
  icon, title, `desc`, prize line, progress fraction (`"2 / 3"` for
  streak-style kinds), and **Klaim** button when state is `STATE_UNLOCKED`.
  Klaim wires to the same `Achievements.claim` path the current row uses.
- Sheet close: tap scrim, back arrow, or Android back.
- Locked tiles still open the sheet (players want to see what they're
  chasing) but show a lock icon in place of the Klaim button.

### Header — one morphing pill + filter button

Above the grid, replacing the current empty space under the ribbon:

- **Left: morphing status pill** (`Scenes/Achievements/AchievementStatusPill.tscn`,
  new). Two states, `Tween`-crossfaded on modulate + scale (~250 ms,
  `Juice`-friendly easing):
  - **Idle** (no unclaimed prize): cream background, text
    `"%d / %d dibuka" % [claimed_count, total_count]`, tiny 24-segment
    dash bar underneath (filled dashes = claimed).
  - **Waiting** (`Achievements.total_unclaimed_count() > 0` — new helper,
    sums `entry.prize` where it parses as money; text prizes still count
    as "unclaimed" but don't add to the number): green background, coin
    icon on the left, text `"%d G belum diambil" % gold`, and a slow
    breathe loop (`Tween` scale 1.0 ↔ 1.03, 1.6 s, `TRANS_SINE`,
    `LOOP_YOYO`) via `Juice`.
  - Tap in waiting state → scroll `%List` to the first `STATE_UNLOCKED`
    tile and flash it with `Juice.shake` (small amplitude).
  - Number changes use `Juice.count_up`.
- **Right: filter button** (`OptionButton`, `SecondaryButton` variation).
  Options: `Semua`, `Belum dibuka`, `Sudah dibuka`, `Belum diambil`. On
  change, hides tiles that don't match. No persistence — resets to
  `Semua` on scene enter.

### Debug tab — `🏆 Prestasi`

Add a new tab to `Scripts/Debug/DebugManager.gd`'s overlay, alongside
General/Scenes/etc. Programmatic UI is fine here (existing overlay is
already programmatic and exempt from the design-system rule).

- Global controls at top:
  - **Buka semua** — loops `Achievements.unlock(id)` for every catalog
    entry. Queues 26 toasts through the existing `AchievementToast`
    autoload; good stress test.
  - **Reset semua** — `Achievements.reset_all()` (new helper: wipes
    `unlocked`/`claimed`, deletes `user://achievements.cfg`, emits a
    signal so open screens can refresh).
  - **Buka acak** — picks one locked entry, unlocks it. Useful for
    seeing the toast without opening every one.
  - Live readout: `"%d / %d dibuka · %d belum diambil"`.
- Scrollable list, one row per catalog entry:
  - Icon (16×16) + short title + state badge (locked/unlocked/claimed).
  - Buttons per row: **Buka** (calls `Achievements.unlock(id)` — fires
    toast), **Klaim** (calls `Achievements.claim(id)`, only enabled when
    unlocked), **Kunci lagi** (resets just that one to locked; new
    `Achievements.relock(id)` helper).

### Achievements.gd — new API surface

Add to `Scripts/Achievements/Achievements.gd`:

```
func progress_of(id: String) -> float          # 0.0..1.0
func total_claimed_count() -> int
func total_count() -> int                      # convenience
func total_unclaimed_count() -> int             # sum of numeric prizes on unlocked-but-not-claimed
func first_unclaimed_id() -> String            # "" if none
func reset_all() -> void                       # debug/dev use
func relock(id: String) -> void                # debug/dev use
signal state_changed                           # emitted on any unlock/claim/reset
```

`state_changed` lets the header pill and grid tiles update live without
polling. Existing `unlocked(id)` signal stays for the toast.

Prize-string parsing for `total_unclaimed_count()`: the current catalog
prizes are effect labels (`"Hasil Wirausaha +5%"`), **not** gold values.
The header pill's "belum diambil" concept only applies once achievements
grant actual G on claim. For this pass: the helper returns the **count of
unclaimed unlocked achievements**, and the pill's waiting-state text
reads `"%d hadiah belum diambil"` instead of a G amount. Cleaner scope,
no data model change. Revisit when/if gold rewards get added to
`ENTRIES`.

## Files touched

New:
- `Scenes/Achievements/AchievementTile.tscn`
- `Scenes/Achievements/AchievementDetailSheet.tscn`
- `Scenes/Achievements/AchievementStatusPill.tscn`
- `Scripts/Achievements/AchievementTile.gd`
- `Scripts/Achievements/AchievementDetailSheet.gd`
- `Scripts/Achievements/AchievementStatusPill.gd`
- `tests/test_achievements_grid.gd` (source-text scans for grid columns,
  prize chip presence, filter options, morphing pill states)
- `tests/test_debug_achievements_tab.gd` (scans DebugManager for the new
  tab and its buttons)

Modified:
- `Scenes/Achievements/achievements.tscn` — VBox → GridContainer, add
  header HBox with status pill + filter button.
- `Scripts/Achievements/achievements_screen.gd` — instantiate tiles into
  the grid, wire filter, wire status pill, connect
  `Achievements.state_changed`.
- `Scripts/Achievements/Achievements.gd` — new helpers listed above,
  `state_changed` signal.
- `Scripts/Debug/DebugManager.gd` — new Prestasi tab.

Deleted (after tests pass):
- `Scenes/Achievements/AchievementRow.tscn`
- `Scripts/Achievements/AchievementRow.gd`
- old row test if any.

## Implementation order (branch: `feat/achievements-polish`)

1. **`Achievements.gd` helpers + signal.** Small, unblocks everything
   else. Add tests for `progress_of`, `first_unclaimed_id`,
   `state_changed` fires on unlock/claim/reset.
2. **`AchievementTile.tscn` + `.gd`.** Build the tile in isolation.
   Wire `setup(entry, state, progress)`, prize chip, state badges. Test
   with source-text scans.
3. **`AchievementDetailSheet.tscn` + `.gd`.** Modal sheet + Klaim button.
4. **`AchievementStatusPill.tscn` + `.gd`.** Two states, morph tween,
   breathe loop, tap-to-scroll callback.
5. **Rewire `achievements.tscn`.** GridContainer, header HBox, filter
   button. Delete old row files. Update `achievements_screen.gd`.
6. **Debug tab.** New Prestasi tab in `DebugManager.gd`.
7. **Full `test_run`.** Fix any regressions. Manual check via
   `project_run` + debug tab: Buka acak, watch toast, open screen,
   confirm pill morphs to waiting state, filter, claim, watch pill snap
   back.

## Constraints — do not violate

- **No `theme_override_*`.** Every visual style comes from a
  `ThemeFactory` variation. If a new one is needed
  (`AchievementTile`, `AchievementPrizeChip`, `AchievementStatusPill`)
  add it in `Scripts/Design/ThemeFactory.gd` and rebake via
  `Scripts/Design/BakeTheme.gd` (File > Run).
- **No runtime visual construction** in the screen or tile scripts.
  Static chrome in `.tscn`, repeated items instantiated from
  `PackedScene`. Runtime debt is ratcheted by
  `tests/test_viewport_editability.gd`.
- **`@tool` on every new script**, side effects gated behind
  `if Engine.is_editor_hint(): return`. Every `## file header` and
  `## line on every @export` (pinned by
  `tests/test_script_documentation.gd`).
- **No `theme_override_*`** and **no emoji as UI iconography**. The
  debug tab is exempt from the design-system rule but should still avoid
  emoji in any user-facing label — it's fine internally.
- Backgrounds Full Rect + Keep Aspect Covered, UI re-anchored inside
  `SafeAreaMargin`. Suite `tests/test_tall_screen_layout.gd` will pin.
- New coin icon: try to reuse existing shop money iconography before
  adding a placeholder. If placeholder is needed, log it in
  `docs/superpowers/DEBT.md` under a new "Achievements polish" entry.

## Out of scope

- Adding actual G-value prizes to `ENTRIES` (revisit separately).
- Tier ladder (Perunggu/Perak/Emas) — no art, would be placeholder debt.
- Reworking the toast itself — it already works.
- Persistence changes.
- Reordering catalog entries.

## Ship

Use the `ship-pr` skill. This spec doc is merged first on
`feat/achievements-polish-plan` (draft PR for team visibility) then the
implementation lands on `feat/achievements-polish` as its own PR.
