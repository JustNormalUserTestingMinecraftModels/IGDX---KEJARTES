# Koperasi, Inventory, Wirausaha & Report Card — Integration Design

**Date:** 2026-08-27
**Status:** Approved, pending implementation plan

## Problem

Three lobby buttons in `Scenes/Lobby/loby.tscn` — `$Koperasi`, `$Inventory`,
and `$ReportStudent` — are styled, tutorial-targeted, and completely inert.
None of them has a `pressed` connection in `Scripts/Lobby/loby.gd`.

A second programmer has since built a working shop and inventory in a separate
Godot project, `koprasi&inventory`. That project cannot be merged wholesale: it
carries forked duplicates of autoloads this project already owns, its UI does
not match this project's visual language, and its item-effect model assumes a
single global player rather than this project's per-student roster.

Separately, the shop has no economy behind it. Items cost 400–1500 while the
only money source in the game is the daily login reward of +10 (`loby.gd:640`).

## Goals

1. `$Koperasi` and `$Inventory` open working screens that look and feel like
   the rest of this project.
2. Items affect a chosen student, not a global player stat.
3. A new "Wirausaha" schedule activity generates money, paid out weekly, so the
   shop is reachable through normal play.
4. `$ReportStudent` opens a read-only student card viewer with live stats.

## Non-Goals

- Persistence. This project has no save system; `user://` is used only for
  audio and theme settings. Money and inventory stay session-scoped, exactly
  like `approved_students` and `day_schedules` already are.
- Rebalancing the existing academic progression. Wirausaha is additive.
- Reworking `student_card.gd` beyond the extraction described in section 5.

## Asset Policy

The item icons and background/panel art in `koprasi&inventory` are **finished
art, not placeholders**. They are copied byte-identical and never re-authored:

- `Asset/ItemRak/*.png` — every item icon
- `Asset/UI/bg_inventory.png`
- `Asset/UI/panel_header.png`, `panel_sidebar.png`, `panel_detail.png`,
  `panel_popup.png`
- `Asset/rak 1.jpg`, `Asset/rak2.jpg`
- `Asset/Koin.png`, `Asset/return.png`

Only these four are treated as placeholder chrome and replaced by this
project's theme: `btn_normal.png`, `btn_pressed.png`, `slot_normal.png`,
`slot_selected.png`.

---

## 1. State Merge

### Autoloads NOT imported

`GameState`, `SceneManager`, `GameSetting`, `transition`, and `SfxManager` from
the teammate project are discarded. Their `GameState` is a stale fork of this
project's; the other four duplicate autoloads that already exist here
(`Transition`, `AudioDirector`, `GameSettings`).

### Autoloads added

| Autoload | Source | Change |
|---|---|---|
| `Cart` | `Script/AutoLoad/Cart.gd` | Copied as-is. No dependencies beyond `ItemData`. |
| `ItemDatabase` | `Script/AutoLoad/ItemDatabase.gd` | Copied; `icon_path` entries repointed to `res://Assets/Images/Shop/ItemRak/`. |

`ItemData` becomes a `class_name` resource at `Scripts/Inventory/ItemData.gd`.
No name collision exists in this project.

### Changes to `Scripts/GameState.gd`

- `player_money` becomes a property with a backing var and a setter that emits
  a new `money_changed(new_amount: int)` signal. Existing readers and writers
  (`loby.gd:492`, `loby.gd:638-640`, `DebugManager.gd:613-653`) keep working
  unchanged.
- Add `inventory: Dictionary` (item_name → quantity), an `inventory_changed`
  signal, and `add_to_inventory()` / `remove_from_inventory()` /
  `get_inventory_quantity()`, ported from the teammate's `GameState`.
- Add `pending_earnings: Dictionary` (student_id → int) for Wirausaha accrual
  (section 4).

### Deliberately dropped

The teammate's `player_mood`, `player_energy`, `max_mood`, `max_energy`, and
`use_item(item, quantity)` operate on a single global player. This project
tracks mood and energy per student on `StudentData`. They are replaced by:

```gdscript
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary
```

which writes into the matching dictionary in `approved_students` — this
project's cross-screen source of truth — clamping to that student's caps and
returning the applied deltas for the floating stat-pop animation.

### SFX remapping

Every `SfxManager.*` call is rewritten to `AudioDirector.play_sfx()` using ids
already in the registry (`Scripts/Audio/AudioDirector.gd:134-148`):

| Teammate call | Replacement |
|---|---|
| `play_tap()` | `play_sfx(&"tap")` |
| `play_navigate()` | `play_sfx(&"whoosh")` |
| `play_buy()` | `play_sfx(&"coin")` |
| `play_error()` | `play_sfx(&"error")` |

---

## 2. Scene Port and Restyle

### File layout

| Destination | Source |
|---|---|
| `Scenes/Koperasi/koprasi.tscn` | `Scene/koprasi.tscn` |
| `Scenes/Inventory/inventory.tscn` | `Scene/inventory.tscn` |
| `Scripts/Koperasi/koprasi.gd` | `Script/koprasi.gd` |
| `Scripts/Inventory/inventory.gd` | `Script/inventory.gd` |
| `Scripts/Inventory/ItemData.gd` | `Script/ItemData.gd` |
| `Assets/Images/Shop/**` | `Asset/**` (per Asset Policy) |

`Script/AnimUtils.gd` is not imported; its effects are reproduced with this
project's `Scripts/Design/Juice.gd` and `UIPolish`.

### Restyle

- Delete the `StyleBoxTexture` resources built on `btn_normal`, `btn_pressed`,
  `slot_normal`, `slot_selected`. Buttons and item slots inherit
  `Assets/Theme/kejartes_theme.tres`, so press states, corner radii, and touch
  feedback match the lobby.
- Re-source the hardcoded `StyleBoxFlat` colors (`Color(0.08, 0.1, 0.22)`,
  `Color(0.25, 0.55, 1)`, and siblings) from `DesignTokens`.
- Apply `TouchFeedbackManager` and `UIPolish` to every button.
- Apply `Scripts/UI/SafeAreaMargin.gd` to both scene roots.

### Transitions

- `Transition.change_scene(path)` calls gain explicit `Style` and duration
  arguments so navigation feels identical to lobby ↔ student_card.
- The inventory `UsePopup` is currently an opaque full-screen `ColorRect`. It
  is rebuilt on the modal pattern `student_card.gd` uses: a
  `DesignTokens.scrim_color()` scrim, fade plus scale in and out at the token
  `dur_fast`, and tap-outside-to-dismiss.
- The koperasi `Rak1` panel gets the same treatment.

### Navigation

The shop and the inventory are **independent siblings**, both reached only from
the lobby:

- `$Koperasi` → `koprasi.tscn` → back → lobby
- `$Inventory` → `inventory.tscn` → back → lobby

Specifically:

- Delete the `Inventory` button node from `koprasi.tscn` and remove
  `_on_inventory_pressed()` and its connection from `koprasi.gd:254-257`.
  Reflow the header so the remaining controls do not leave a gap.
- Change `inventory.gd:504` — the back button currently returns to
  `koprasi.tscn` — to return to the lobby.

Consequence, accepted: after buying, the player must back out to the lobby and
enter the inventory to see the purchase. The shop's existing purchase
confirmation message (`koprasi.gd:314`) carries the feedback. If playtest shows
this is tedious, the fix is a richer post-purchase toast in the shop, not
re-adding the cross-link.

### Lobby wiring

In `Scripts/Lobby/loby.gd`, connect `koperasi_button` and `inventory_button`
(already declared at lines 25 and 27) to new handlers, following the existing
`is_connected` guard pattern used by `_on_student_pressed`.

---

## 3. Item Use Targets a Student

The use popup gains a horizontal student strip above the quantity stepper,
listing the students in `GameState.approved_students` with portrait, name, and
live mood/energy bars. The bar builder is reused from
`Scripts/SchoolSimulation/ResultCheckup.gd`.

Flow: pick student → set quantity → confirm. Confirm stays disabled until a
student is selected. On confirm, `mood_boost` and `energy_boost` × quantity are
applied to that student through `GameState.use_item()`, and the teammate's
floating stat-pop animation (`inventory.gd:590-607`) plays with the returned
deltas.

---

## 4. Wirausaha

A fifth schedule activity. Assigned students earn money instead of stats, at a
mood and energy cost, and the money is paid out at the end of the week.

### Enumeration sites

Every place the four existing categories are listed:

- `Scripts/Design/DesignTokens.gd` — new `cat_wirausaha` color export plus a
  `category_color()` case; re-bake the theme via `Scripts/Design/BakeTheme.gd`.
- `Scenes/AturJadwal/atur_jadwal.tscn` — a fifth button under `Olahraga` in
  `Penjadwalan/TextureRect`, matching the existing four.
- `Scripts/AturJadwal/atur_jadwal.gd:909-914` — connect
  `_on_activity_selected.bind("Wirausaha")`; the mood/energy cost branch in
  `_on_activity_selected` gains a Wirausaha case.
- `Scripts/SchoolSimulation/SchoolDay.gd:138` — add to `DAY_CATEGORIES`.
- `Scripts/SchoolSimulation/SchoolDay.gd:531-580` — a money pill instead of a
  stat pill in `_build_pill_badges_for_student`.
- `Scripts/GameState.gd:122` — add to the counts dictionary in
  `get_jadwal_for_day`.

### Daily accrual

In `StudentManager.apply_daily_decay_all`, a Wirausaha day:

- grants no `akademis` / `seni_budaya` / `olahraga` gain,
- costs mood and energy at a rate above a normal activity day,
- accrues `GameState.pending_earnings[student_id] += earnings`, where earnings
  is a random amount scaled by that student's energy at the time, so a tired
  student earns less.

### Weekly payout

At `SchoolDay._on_week_complete()`, sum `pending_earnings` across all students,
add the total to `GameState.player_money`, clear the dictionary, and show the
total as a line in the week summary.

### Tunables

Earning range, mood cost, energy cost, and the energy-scaling curve all live in
a single `const` block at the top of `StudentManager.gd`.

---

## 5. Report Card

`Scenes/ReportCard/report_card.tscn` and `Scripts/ReportCard/report_card.gd`,
derived from `student_card` **by deletion, not rewrite**.

Kept: the paper cards, the swipe and pagination tweens, the stat bars, the
quirk and persona description popups.

Removed: the `Aprove` buttons, `StampApprove`, `BelajarButton`, `MAX_APPROVE`
gating, the approve-shift layout logic (`_shift_approve_for_belajar`,
`_reset_approve_position`), and the tutorial system.

Pages come from `GameState.approved_students` only — 2 to 4 pages depending on
grade — not the six-entry `student_data_list`.

"Live" means the viewer reads `approved_students` at `_ready()` and reflects
whatever the most recent school day wrote, and it connects to the relevant
state-change signals so an open card updates rather than showing a snapshot.

### Shared extraction

`Scripts/StudentCard/student_card.gd` is 1916 lines. Rather than fork it, the
card-rendering logic — populating one `KertasMurid` from a student dictionary,
building the stat bars, and the quirk/persona popups — is extracted into
`Scripts/StudentCard/StudentCardView.gd`, consumed by both screens. Node paths
are preserved so `student_card`'s tutorial step targets keep resolving; this is
verified explicitly.

Nothing else in `student_card.gd` is touched.

---

## Testing

Unit tests in `tests/`:

- `GameState` money setter emits `money_changed`; inventory add/remove/query.
- `use_item` applies deltas to the correct student and clamps at caps.
- Wirausaha accrues per day and pays out once at week end.
- `StudentCardView` renders a card from a student dictionary.

Scene wiring — all three lobby buttons, both back paths, the use popup, and the
Wirausaha schedule button — is verified by launching the app.

## Known Risks

1. **Wirausaha balance.** The earning and cost numbers are new game design and
   will need playtesting. They are isolated in one const block for that reason.
2. **Popup density.** The `Penjadwalan` popup gets visually tighter with five
   buttons instead of four.
3. **Tutorial fragility.** `student_card.gd`'s tutorial steps target node paths
   by string. The `StudentCardView` extraction must not move them.
4. **No persistence.** Purchased items and earned money are lost on quit, which
   is consistent with the rest of the game but will feel worse for an economy
   than it does for schedules.
