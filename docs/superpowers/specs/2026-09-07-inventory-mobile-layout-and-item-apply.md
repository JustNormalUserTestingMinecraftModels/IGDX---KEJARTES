# Inventory Mobile Layout & Item-Apply Flow — Design

**Date:** 2026-09-07
**Status:** Draft for review
**Branch target:** `Textures` (main)

## Problem

The Inventory screen (`Scenes/Inventory/inventory.tscn`, `Scripts/Inventory/inventory.gd`)
is the ported second-programmer `koperasi&inventory` screen. It has three problems:

1. **Layout is cramped and confusing on portrait mobile.** A 210 px vertical
   category sidebar eats a fifth of the 1080-wide design space; the item-detail
   `DetailPanel` and the `UsePopup` modal are separate stacked surfaces; the
   `.tscn` is wall-to-wall `theme_override_*` and raw-colour `StyleBoxFlat`
   subresources, so it does not match the rest of the game's theme-driven look.
2. **Items are not functional.** `Scripts/Inventory/inventory.gd::_on_use_pressed()`
   only opens the use popup when the player owns **2 or more** of an item; owning
   exactly one prints `"aksi dinonaktifkan (null)"` and does nothing. Worse,
   `GameState.use_item()` writes the target student's boost to dictionary keys
   `"mood"` / `"energy"`, but the canonical roster keys the simulation reads
   (`GameState.convert_to_student_data_array()`) are `kepribadian1` (mood) and
   `kepribadian2` (energy). The current effect writes keys nothing reads — so
   item use has never actually reached a simulation.
3. **The apply step gives almost no feedback or information.** A row of tiny
   hand-built `Button` cards with two 10 px `ProgressBar`s; no per-student
   preview of what the item will do, no explanation of what the affected bars
   mean, no payoff animation.

## Goals

- A clear, thumb-friendly, theme-driven Inventory layout with no surface
  competing for the same screen space.
- Items become fully functional for **Mood, Energy, and the three skills**
  (`akademis`, `seni_budaya`, `olahraga`), at any owned quantity including one.
- A dedicated "apply to students" flow modelled on the school-simulation event
  dialog (`Scripts/SchoolSimulation/EventStudentSelectDialog.gd`), with a live
  per-student stat preview, a plain-Indonesian explanation of every affected
  bar, and a satisfying multi-stage payoff (particles + SFX).
- All new UI obeys the project's two visual rules: no `theme_override_*` (use
  `ThemeFactory` variations), and no runtime visual construction (static chrome
  authored in `.tscn`, repeated rows as `PackedScene` templates, geometry in
  `@tool` scripts with documented `@export`s).

## Non-goals

- No persistence beyond `GameState.inventory` (see Section 7). Roster, money,
  week, grade and schedules stay session-scoped.
- No change to how items are **bought** (`koprasi.gd` / shop shelf) or to
  `Cart` — this pass is inventory-side only.
- No new balance tuning of `Balance.gd` or grade-progression numbers. New item
  skill-boost values start deliberately small and are flagged as balance-pending
  (see "Balance risk").
- Minigames and the debug overlay remain out of the design-system scope.

## Global constraints (copy verbatim into the plan)

- Godot **4.6**, portrait 1080×1920, `mobile` renderer.
- Game-facing identifiers and all UI text are **Indonesian**; systems code is
  English.
- **No `theme_override_*`** anywhere except layout-only constant overrides
  (`separation`, `margin_*`). Use `ThemeFactory` type variations; add a new
  variation to `Scripts/Design/ThemeFactory.gd` and rebake
  (`Scripts/Design/BakeTheme.gd`, File > Run, or the transient-test headless
  path) if none fits.
- **No runtime visual construction.** Static chrome is a node in the `.tscn`;
  repeated rows are a `PackedScene` template; responsive geometry is a `@tool`
  script driven by documented `@export`s.
- Every script carries a `##` file header; every `@export` carries a `##` line
  (`tests/test_script_documentation.gd`).
- `tests/test_viewport_editability.gd` holds a frozen `BASELINE` of tolerated
  runtime-construction sites; `Scripts/Inventory/inventory.gd` is currently at
  **4**. The ratchet only ever lowers — this pass must lower it, never raise it.
- Test suites are `@tool`, extend `McpTestSuite`, contain no coroutine tests,
  and run in-editor via the Godot AI MCP `test_run`.
- SFX go through `AudioDirector.play_sfx(&"cue")`. Colours come from
  `DesignTokens.load_default()`, never `Color(...)` literals in scripts.
- Scene navigation uses `Transition.change_scene(path, Transition.Style.*)`.

---

## Architecture overview

Three zones, each self-contained:

```
Inventory (Control, root)
├─ Background (TextureRect, bg_inventory.png)
└─ MainColumn (VBoxContainer)
   ├─ Header        (PanelContainer, panel_header.png)  — back · title · coins
   ├─ FilterRow     (PanelContainer → ScrollContainer → HBoxContainer)  — category chips
   └─ GridArea      (MarginContainer → ScrollContainer → GridContainer cols=3)
                     — InventorySlot tiles + EmptyStateLabel

  (instanced on demand, above the grid, as children of the root:)
   ItemDetailSheet   — bottom sheet, one item's detail + "Efek" block
   ApplyItemScreen   — full-screen modal, pick students + preview + confirm + payoff
```

Data flow:

```
tap tile ──► inventory.gd._on_slot_pressed(slot)
          ──► open ItemDetailSheet(item)            [grid stays visible behind scrim]
ItemDetailSheet "Pakai ke Siswa" ──► apply_requested(item)
          ──► inventory.gd opens ApplyItemScreen(item)
ApplyItemScreen confirm ──► GameState.use_item_on_students(item, ids)
          ──► {"applied": true, "results": [ {student_id,name,deltas...}, ... ]}
          ──► ApplyItemScreen plays payoff, emits applied(results)
          ──► inventory.gd closes screen, bounces the tile badge / removes empty tile
```

`GameState.inventory_changed` still drives the grid rebuild, exactly as today.

---

## Section 1 — Screen 1: Inventory grid (`inventory.tscn` re-authored, `inventory.gd` rewritten)

### 1.1 Layout (authored nodes)

| Node | Type | Key props |
|---|---|---|
| `Inventory` | `Control` | full-rect, `theme = kejartes_theme.tres` |
| `Background` | `TextureRect` | full-rect, `bg_inventory.png`, `expand_mode = 1` |
| `MainColumn` | `VBoxContainer` | full-rect, `separation` override only |
| `MainColumn/Header` | `PanelContainer` | `custom_minimum_size = (0, 120)`, `panel` stylebox = a `StyleBoxTexture` on `panel_header.png` **authored as a scene subresource** (texture styleboxes are art, not a `theme_override` colour — allowed, same as today) |
| `Header/Row` | `HBoxContainer` | `separation` override only |
| `Header/Row/BackButton` | `TextureButton` | `return.png`, 80×80 |
| `Header/Row/TitleLabel` | `Label` | `theme_type_variation = &"DisplayLabel"`, text `"INVENTORY"` |
| `Header/Row/Spacer` | `Control` | `size_flags_horizontal = 3` |
| `Header/Row/CoinDisplay` | `HBoxContainer` | icon `Koin.png` 50×50 + `CoinLabel` (`&"CoinLabel"` variation) |
| `MainColumn/FilterRow` | `PanelContainer` | `custom_minimum_size = (0, 96)`; `panel` = `&"SunkenPanel"`-style or a `StyleBoxTexture` on `panel_sidebar.png` reused horizontally — **pick `SunkenPanel` theme variation, no texture** to shed the sidebar art |
| `FilterRow/Scroll` | `ScrollContainer` | `vertical_scroll_mode = 0`, horizontal only |
| `FilterRow/Scroll/Chips` | `HBoxContainer` | `separation` override; four authored chip buttons |
| `.../Chips/CatSemua` … `CatMakanan` | `Button` | `theme_type_variation = &"FilterChipButton"` (**new variation, see 1.2**), `toggle_mode = true`, texts `Semua` / `Buku` / `Olahraga` / `Makanan`, all in a `ButtonGroup` |
| `MainColumn/GridArea` | `MarginContainer` | margins 24/24/24/12 (constant overrides, allowed) |
| `GridArea/Scroll` | `ScrollContainer` | `horizontal_scroll_mode = 0` |
| `GridArea/Scroll/Grid` | `GridContainer` | `columns = 3`, `h/v_separation` overrides |
| `Grid/EmptyStateLabel` | `Label` | `theme_type_variation = &"EmptyStateLabel"`, hidden by default, kept as a permanent child skipped during rebuild (unchanged behaviour) |

The `Sidebar`, `DetailPanel`, and `UsePopup` nodes and **every `SubResource
StyleBoxFlat`** in the current `.tscn` are deleted. The only `SubResource`
that survives is the header's `StyleBoxTexture` (art).

### 1.2 New theme variation: `FilterChipButton`

Add to `Scripts/Design/ThemeFactory.gd` and rebake. A pill toggle button:

- normal: `surface_overlay` bg, full corner radius (height/2 ≈ 24), 14/8 content
  margins, `text_secondary` font.
- pressed / `button_pressed`: `brand_primary.darkened(0.15)` bg, `text_on_brand`
  font, a 3 px `brand_primary` left border.
- hover: `brand_primary.darkened(0.35)`.
- `focus` = `StyleBoxEmpty`.

All values pulled from `DesignTokens`. This removes the per-frame
`_apply_category_style()` / `_style_all_category_buttons()` code in `inventory.gd`
entirely — the `ButtonGroup` + variation does it.

### 1.3 `inventory.gd` — rewritten controller

Responsibilities only: populate the grid, own the current category filter, open
and route the two sub-surfaces, and animate the tile badge on inventory change.
It builds **no** styleboxes and **no** labels/bars at runtime.

```gdscript
extends Control
## The Inventory screen. Shows every owned item as a tappable grid tile;
## tapping one opens ItemDetailSheet, whose "Pakai ke Siswa" button opens
## ApplyItemScreen. This script never builds visuals at runtime — tiles,
## the sheet and the apply screen are all PackedScene templates.

@export var slot_scene: PackedScene = preload("res://Scenes/Inventory/InventorySlot.tscn")
## Bottom sheet shown when a tile is tapped.
@export var detail_sheet_scene: PackedScene = preload("res://Scenes/Inventory/ItemDetailSheet.tscn")
## Full-screen "apply to students" modal opened from the sheet.
@export var apply_screen_scene: PackedScene = preload("res://Scenes/Inventory/ApplyItemScreen.tscn")

var current_category: String = "Semua"
var _sheet: ItemDetailSheet = null
var _apply_screen: ApplyItemScreen = null

# _ready(): wire back button, chip ButtonGroup.pressed, GameState.money_changed
#           + inventory_changed, coin label; then _populate_grid().
```

- `_populate_grid()` — clears non-`EmptyStateLabel` children, iterates
  `GameState.inventory`, category-filters, instances `slot_scene`, calls
  `slot.setup(item, qty)`, connects `slot_pressed`, staggers entrance
  (`AnimUtils.staggered_entrance`). Empty → `EmptyStateLabel` shown with
  Indonesian text (no emoji; text only — matches the emoji ban).
- `_on_chip_pressed(category)` — set `current_category`, `AudioDirector.play_sfx(&"tap")`,
  `_populate_grid()`. No manual button restyling.
- `_on_slot_pressed(slot)` — if a sheet is open for the same item, close it;
  else `_open_detail_sheet(slot.item)`.
- `_open_detail_sheet(item)` — instance `detail_sheet_scene`, `add_child`,
  `sheet.setup(item, GameState.get_inventory_quantity(item.item_name))`,
  connect `apply_requested` → `_open_apply_screen`, connect `dismissed` →
  free + clear `_sheet`. `AudioDirector.play_sfx(&"popup_open")`.
- `_open_apply_screen(item)` — free the sheet, instance `apply_screen_scene`,
  `add_child`, `screen.setup(item)`, connect `applied` → `_on_items_applied`,
  connect `cancelled` → free + clear. `AudioDirector.play_sfx(&"popup_open")`.
- `_on_items_applied(results: Array)` — free the apply screen
  (`AudioDirector.play_sfx(&"whoosh")`); `_populate_grid()` rebuilds from the
  now-reduced stack; after rebuild, find the tile for the used item (if any
  remain) and call `slot.bounce_badge()`; a fully-consumed item leaves no tile
  (rebuild handles it) — show a brief `"<item> habis"` toast
  (`_show_toast(text)`, see 1.4).
- `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` — close apply screen, else
  close sheet, else `_on_back_pressed()`.
- `_on_back_pressed()` — `AudioDirector.play_sfx(&"whoosh")`, await a short
  interval, `Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)`.

`_show_toast(text)` uses `AnimUtils.create_floating_text` (an existing static
helper — allowed, it is the project's standard transient-text call, already in
the `ALLOWED` set spirit for per-call dynamic content) OR a single authored
hidden `ToastLabel` node in the `.tscn` that fades in/out. **Choose the authored
`ToastLabel` node** to keep the runtime-construction count falling.

### 1.4 Runtime-construction ratchet

Removing the sidebar restyle, the `DetailPanel` population, the `UsePopup`
stylebox setup, the hand-built `StudentStrip` cards, and the floating-label
construction takes `inventory.gd` from 4 tolerated sites to **0**. Update
`tests/test_viewport_editability.gd`: delete the
`"res://Scripts/Inventory/inventory.gd": 4` line from `BASELINE`. The three new
scripts (`ItemDetailSheet.gd`, `ApplyItemScreen.gd`, `ApplyStudentRow.gd`) must
not appear in `BASELINE` — they are written clean.

### 1.5 `InventorySlot` — minor additions

`Scenes/Inventory/InventorySlot.tscn` / `Scripts/Inventory/InventorySlot.gd`
keep their current structure (icon, quantity label, category-tinted border pair
— an accepted per-instance exception). Add:

- `## Bounce the count badge after the owned quantity changed.`
  `func bounce_badge() -> void:` — `AnimUtils.qty_punch(quantity_label)` (existing helper).
- An authored `Shine` node (`TextureRect` or a `ColorRect` with a gradient
  `StyleBoxTexture`) as a child of the tile, hidden by default. A `@tool`
  `@export var shine_min_quantity: int = 5` gate: `setup()` sets
  `shine.visible = quantity >= shine_min_quantity` and, when visible, starts a
  looping left-to-right `position:x` tween (a `@tool` visual driven by a
  documented export — allowed). Purely decorative "you have a lot of these".

---

## Section 2 — Item detail bottom sheet (`ItemDetailSheet`, new)

**Files:** `Scenes/Inventory/ItemDetailSheet.tscn`, `Scripts/Inventory/ItemDetailSheet.gd` (`@tool`, `class_name ItemDetailSheet`).

### 2.1 Layout (authored)

```
ItemDetailSheet (Control, full-rect)
├─ Scrim (ColorRect, full-rect, color = DesignTokens.scrim_color() set in _ready)
└─ Sheet (PanelContainer, anchored bottom, &"Card" variation)
   └─ Margin (MarginContainer, margins ~32)
      └─ VBox (separation override)
         ├─ Grabber (ColorRect, 48×5, centered — the "drag handle" affordance)
         ├─ TopRow (HBoxContainer)
         │  ├─ Icon (TextureRect, 140×140)
         │  └─ TitleCol (VBoxContainer)
         │     ├─ NameLabel (&"TitleLabel")
         │     └─ CategoryChip (instance of DaySummaryBadge.tscn)
         ├─ DescLabel (&"CaptionLabel", autowrap)
         ├─ EfekHeader (Label, &"CardSectionLabel", text "Efek")
         ├─ EfekList (VBoxContainer)
         │  ├─ RowAkademis  (EfekRow template, hidden unless boost != 0)
         │  ├─ RowSeni      (EfekRow template)
         │  ├─ RowOlahraga  (EfekRow template)
         │  ├─ RowMood      (EfekRow template)
         │  └─ RowEnergy    (EfekRow template)
         └─ ApplyButton (&"PrimaryButton", text "Pakai ke Siswa")
```

`EfekRow` is a small **authored sub-scene**
(`Scenes/Inventory/EfekRow.tscn`, no script needed, or a 15-line `@tool`
script): `[NeedIcon TextureRect] [ValueLabel &"ResultDeltaLabel" "+25"] [ExplainLabel &"MicroLabel" autowrap]`.
Five instances live in the sheet `.tscn`; `setup()` fills and shows/hides them.
No row is built at runtime.

### 2.2 Script

```gdscript
@tool
class_name ItemDetailSheet
extends Control
## Bottom sheet: one owned item's icon, name, description and a plain-language
## breakdown of every stat bar it moves. Emits apply_requested when the player
## commits to the apply flow, dismissed when they back out. Builds nothing at
## runtime — the five EfekRow instances are authored in the scene.

signal apply_requested(item: ItemData)
signal dismissed

## Fixed pixel size for the item icon in the sheet's top row.
@export var icon_size: Vector2 = Vector2(140, 140)

## Plain-Indonesian, one line each, shown next to the "+N" for that bar.
## Constants, not @export — copy is fixed game text, not a tuning knob.
const EXPLAIN := {
    "akademis":    "Nilai akademik. Salah satu dari tiga target kelulusan kelas.",
    "seni_budaya": "Nilai seni & budaya. Salah satu target kelulusan kelas.",
    "olahraga":    "Nilai olahraga. Salah satu target kelulusan kelas.",
    "mood":        "Semangat siswa. Mood rendah menurunkan hasil belajar mingguan.",
    "energy":      "Tenaga harian. Energi 5 ke bawah memaksa siswa Izin — istirahat paksa, tanpa belajar.",
}

func setup(item: ItemData, owned_qty: int) -> void
# fills icon, name, DaySummaryBadge chip text = item.category, DescLabel,
# then per bar: show RowX iff the matching boost field != 0, set ValueLabel
# "+%d" % boost, ExplainLabel = EXPLAIN[key]. Animate in: popup_spring_in on
# Sheet, wobble on Icon, count_up on each visible ValueLabel.
```

- `_ready()` — set `Scrim.color = DesignTokens.load_default().scrim_color()`;
  connect `Scrim.gui_input` → dismiss on click outside `Sheet`; connect
  `ApplyButton.pressed` → `_on_apply`; slide/spring the sheet up from
  `position.y = size.y`.
- `_on_apply()` — `AudioDirector.play_sfx(&"confirm")`, `apply_requested.emit(item)`.
- Dismiss path — `AudioDirector.play_sfx(&"popup_close")`, spring down, then
  `dismissed.emit()`.
- Animations use `Juice` (`popup_spring_in`/`_out` are in `AnimUtils`;
  `count_up` is in `Juice`) with token durations.

---

## Section 3 — Apply-to-students screen (`ApplyItemScreen` + `ApplyStudentRow`, new)

**Files:** `Scenes/Inventory/ApplyItemScreen.tscn`, `Scripts/Inventory/ApplyItemScreen.gd`
(`@tool`, `class_name ApplyItemScreen`); `Scenes/Inventory/ApplyStudentRow.tscn`,
`Scripts/Inventory/ApplyStudentRow.gd` (`@tool`, `class_name ApplyStudentRow`).

UX modelled on `EventStudentSelectDialog` — multi-select, per-student preview,
select-all, count in the confirm label — but every card, bar and chip is an
authored node or a `PackedScene` template, and nothing builds a `StyleBoxFlat`.

### 3.1 `ApplyItemScreen` layout (authored)

```
ApplyItemScreen (Control, full-rect)
├─ Background (Panel, &"Scrim" variation)  — or a blurred-classroom TextureRect
│                                             matching DaySummary if cheap
└─ Margin (MarginContainer)
   └─ Card (PanelContainer, &"Card")
      └─ Margin (MarginContainer)
         └─ VBox
            ├─ TitleLabel (&"H1Label", text "Pakai ke Siapa?")
            ├─ RecapStrip (HBoxContainer)
            │  ├─ RecapIcon (TextureRect 96×96)
            │  ├─ RecapName (&"TitleLabel")
            │  └─ RecapCount (&"CaptionLabel", text "Sisa ×N")
            ├─ EffectSummary (Label, &"CaptionLabel", autowrap)
            │        e.g. "Menambah: Akademis +6, Mood +10, Energi +5 per siswa."
            ├─ Scroll (ScrollContainer, drag-to-scroll like EventStudentSelectDialog)
            │  └─ Rows (VBoxContainer)  — ApplyStudentRow instances added here
            └─ Actions (VBoxContainer)
               ├─ SecondaryRow (HBoxContainer)
               │  ├─ SelectAllButton (&"SecondaryButton", text "Pilih Semua")
               │  └─ CancelButton (&"SecondaryButton", text "Batal")
               └─ ConfirmButton (&"SuccessButton", text "Pakai (%d Siswa)")
```

Row instances ARE added at runtime, but that is instancing a `PackedScene`
template, which the rules explicitly allow ("repeated rows are a `PackedScene`
template"). The prohibited thing — building the row's visuals node-by-node — is
what `EventStudentSelectDialog._create_card()` does and what this replaces.

### 3.2 `ApplyStudentRow` (template)

```
ApplyStudentRow (PanelContainer, &"Card")
└─ Margin (MarginContainer)
   └─ HBox
      ├─ Check (CheckBox, scaled up ~2×, focus none)
      ├─ Portrait (TextureRect, 120×120, from student "portrait" path)
      ├─ Col (VBoxContainer, expand)
      │  ├─ HeaderRow (HBoxContainer)
      │  │  ├─ NameLabel (&"H2Label")
      │  │  └─ BadgeSlot (HBoxContainer)  — holds DaySummaryBadge instances
      │  ├─ BarRowAkademis  (StatBarRow template, hidden unless item touches it)
      │  ├─ BarRowSeni      (StatBarRow template)
      │  ├─ BarRowOlahraga  (StatBarRow template)
      │  ├─ BarRowMood      (StatBarRow template)
      │  └─ BarRowEnergy    (StatBarRow template)
```

`StatBarRow` is one more tiny authored sub-scene
(`Scenes/Inventory/StatBarRow.tscn`): `[NameLabel &"TitleLabel"] [StatBar
(category-tinted)] [ValueLabel &"TitleLabel" "65/100"] [DeltaLabel
&"ResultDeltaLabel" "--"]`. Reused here (5 instances per row) and nowhere else
yet — that's fine.

```gdscript
@tool
class_name ApplyStudentRow
extends PanelContainer
## One selectable student in ApplyItemScreen: portrait, name, tired/maxed
## badges, and up to five StatBar rows (only the bars the item moves are
## shown). Selecting the row previews the post-apply values on those bars.
## Every bar row is an authored StatBarRow instance — nothing is built here.

signal selection_changed

## Which roster dict keys map to which visible bar row. Fixed mapping —
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy (the project's canonical keys).
const KEY := {
    "akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
    "mood": "kepribadian1", "energy": "kepribadian2",
}

var student: Dictionary          # one entry from GameState.approved_students
var _boosts: Dictionary          # {"akademis": 6, "mood": 10, ...} nonzero only

func setup(p_student: Dictionary, boosts: Dictionary) -> void
# store; fill portrait + name; show a "😴 LELAH" badge (DaySummaryBadge, text
# only per emoji ban -> "LELAH") and disable Check when kepribadian2 <= 5;
# for each boost key, show the matching BarRow, set its StatBar.value to the
# current stat, ValueLabel "cur/100", DeltaLabel "--". Hidden rows stay hidden.

func set_preview(active: bool) -> void
# active: for each shown bar, target = clamp(cur + boost, 0, 100);
#   Juice.fill_bar(bar, target); ValueLabel "cur ➔ target";
#   DeltaLabel "(+N)" tinted state_success (or "MAKS" tinted text_secondary
#   if already 100); pop the DeltaLabel (Juice). Lift the card (scale 1.02).
# inactive: bars back to cur, labels reset, card back to scale 1.

func is_selected() -> bool   # Check.button_pressed and not Check.disabled
func selected_student_id() -> int
```

`Check.toggled` → `set_preview(pressed)` + `selection_changed.emit()`.

### 3.3 `ApplyItemScreen` script

```gdscript
@tool
class_name ApplyItemScreen
extends Control
## Full-screen "apply this item to which students" step. Multi-select with a
## live per-student preview, then a staged payoff (RewardBurst per student,
## screen-wide CelebrationConfetti if every pick gained, rising SFX). Emits
## applied(results) after GameState.use_item_on_students, or cancelled.

signal applied(results: Array)     # the Array from use_item_on_students
signal cancelled

@export var student_row_scene: PackedScene = preload("res://Scenes/Inventory/ApplyStudentRow.tscn")
@export var reward_burst_scene: PackedScene = preload("res://Scenes/SchoolSimulation/RewardBurst.tscn")
@export var confetti_scene: PackedScene = preload("res://Scenes/SchoolSimulation/CelebrationConfetti.tscn")
## Seconds between one student's payoff and the next.
@export var payoff_stagger: float = 0.18

var item: ItemData
var _rows: Array[ApplyStudentRow] = []

func setup(p_item: ItemData) -> void
# item = p_item; fill RecapIcon/Name/Count; EffectSummary from _boosts_of(item);
# clear Rows; for each GameState.approved_students entry instance
# student_row_scene, add to Rows, row.setup(student, _boosts_of(item)),
# connect selection_changed -> _refresh_confirm; Juice.stagger_in(_rows).

func _boosts_of(it: ItemData) -> Dictionary
# {"akademis": it.akademis_boost, "seni_budaya": it.seni_budaya_boost,
#  "olahraga": it.olahraga_boost, "mood": it.mood_boost, "energy": it.energy_boost}
# with zero-valued keys removed.
```

- `_refresh_confirm()` — count selected rows; `ConfirmButton.text = "Pakai (%d Siswa)" % n`;
  `ConfirmButton.disabled = n == 0 or n > GameState.get_inventory_quantity(item.item_name)`.
  If picks exceed the owned stack, also show a caption warning
  `"Item tidak cukup untuk semua pilihan."`.
- `SelectAllButton.pressed` — toggle all non-disabled rows to the majority-off
  state (same logic as `EventStudentSelectDialog._on_select_all_pressed`),
  `AudioDirector.play_sfx(&"select")`.
- `CancelButton.pressed` / back — `AudioDirector.play_sfx(&"cancel")`,
  `cancelled.emit()`.
- `ConfirmButton.pressed` → `_commit()`:

```
func _commit():
    var ids := selected ids from _rows
    var res := GameState.use_item_on_students(item, ids)
    if not res["applied"]:
        AudioDirector.play_sfx(&"error"); return
    ConfirmButton.disabled = true; SelectAllButton.disabled = true
    await _play_payoff(res["results"])
    applied.emit(res["results"])
```

- `_play_payoff(results)` — for each result, in order:
  - find its `ApplyStudentRow`; spawn `reward_burst_scene` centred on the row
    (add as child of the row or the screen at the row's global centre);
  - `AnimUtils.create_floating_text` above the row with the gained lines, e.g.
    `"Akademis +6\nMood +10"` (only nonzero deltas), tinted `state_success`;
  - play a rising cue: cycle `&"star_earn_1"` → `&"star_earn_2"` →
    `&"star_earn_3"` (index clamped) — reuses existing cues, **no new
    `AudioDirector` slot**;
  - `await get_tree().create_timer(payoff_stagger).timeout`.
  - After the loop: if **every** result has at least one positive delta, spawn
    one `confetti_scene` as a screen child and `AudioDirector.play_sfx(&"sparkle")`;
    then `AudioDirector.play_sfx(&"result_fanfare")`.
- `_ready()` — `AudioDirector.play_sfx(&"popup_open")`, fade in, wire buttons,
  drag-scroll on `Scroll` (lift the handler from `EventStudentSelectDialog`).

### 3.4 Audio — no new cues

Reused existing `AudioDirector` cues: `popup_open`, `popup_close`, `whoosh`,
`tap`, `select`, `confirm`, `cancel`, `error`, `star_earn_1/2/3`,
`result_fanfare`, `sparkle`. If a dedicated identity is wanted later, add one
`sfx_item_apply` slot aliasing `res://Assets/Audio/SFX/reward.ogg` per the
project's placeholder convention — out of scope for this pass.

---

## Section 4 — Items become functional (`ItemData`, `ItemDatabase`, `GameState`)

### 4.1 `ItemData.gd` — new skill-boost fields

```gdscript
@export_group("Skill Boost")
## Added to the target student's akademis (akademis1) when the item is used,
## multiplied by nothing — one application per selected student. Clamped [0,100].
@export var akademis_boost: int = 0
## Same, for seni_budaya (akademis2).
@export var seni_budaya_boost: int = 0
## Same, for olahraga (akademis3).
@export var olahraga_boost: int = 0
```

(The existing `@export_group("Stats Boost")` `mood_boost` / `energy_boost` stay.)

### 4.2 `ItemDatabase.gd` — catalog values + `register()` signature

`register()` gains three params after `energy_boost`:
`akademis_boost := 0, seni_budaya_boost := 0, olahraga_boost := 0`, assigned to
the new `ItemData` fields in both the "update existing" and "create new"
branches (mirror the `mood_boost` handling). `_init_database()` reads
`info.get("akademis", 0)` etc. and passes them.

New per-entry values in `DEFAULT_ITEMS` (small, balance-pending — see risk):

| Item | category | akademis | seni_budaya | olahraga | mood | energy |
|---|---|---|---|---|---|---|
| Bank Soal | Buku | **6** | 0 | 0 | 10 | 5 |
| Komik | Buku | 0 | **4** | 0 | 25 | 5 |
| LKS | Buku | **5** | 0 | 0 | 5 | 5 |
| Lompat Tali | Olahraga | 0 | 0 | **6** | 20 | 15 |
| Raket | Olahraga | 0 | 0 | **8** | 30 | 20 |
| Cilok | Makanan | 0 | 0 | 0 | 15 | 20 |
| Mie Instan | Makanan | 0 | 0 | 0 | 20 | 35 |
| Pop Ice | Makanan | 0 | 0 | 0 | 25 | 15 |
| Susu Kotak | Makanan | 0 | **3** | 0 | 10 | 30 |

Rationale: Buku boosts academics/arts, Olahraga gear boosts sport, Makanan stays
pure need-recovery. Values are ~⅓ of a good single-day study gain so an item is
a useful nudge, not a target-skip. Copy this table verbatim into the plan.

### 4.2a Per-item placeholder descriptions

Every entry in `DEFAULT_ITEMS` already carries a `desc` string; this pass keeps
**one distinct, non-empty Indonesian one-liner per item**, shown verbatim in
`ItemDetailSheet`'s `DescLabel`. Where an existing line is thin, replace it with
a fuller placeholder (prefix the array comment for the block with
`# [PLACEHOLDER] item flavour copy — pending a writing pass`). Target copy — one
sentence, flavour only, no numbers (the "+N" lives in the Efek block):

| Item | `desc` (placeholder) |
|---|---|
| Bank Soal | "Bundel soal-soal ujian tahun lalu; latihan paling ampuh sebelum tes." |
| Komik | "Komik favorit yang bikin lupa waktu — hiburan cepat saat penat." |
| LKS | "Lembar Kerja Siswa untuk mengasah materi pelan-pelan di rumah." |
| Lompat Tali | "Tali lompat warna-warni; pemanasan seru yang bikin badan segar." |
| Raket | "Raket bulu tangkis pinjaman kakak kelas, masih enak dipakai tanding." |
| Cilok | "Cilok kenyal berbumbu kacang, jajanan wajib jam istirahat." |
| Mie Instan | "Semangkuk mie instan hangat — pengganjal perut andalan anak kos." |
| Pop Ice | "Es blender manis warna cerah yang langsung menaikkan mood." |
| Susu Kotak | "Susu kotak dingin, katanya bikin fokus pas jam pelajaran pagi." |

These strings are flagged placeholder alongside the project's other pending copy
(cutscene lines, aliased SFX); a later writing pass may revise them without
touching this feature.

### 4.3 `GameState.use_item()` — fix keys, add skills

Current bug: reads/writes `"mood"` / `"energy"`. Change to the canonical roster
keys and add the three skills:

```gdscript
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary:
    var refused := {"applied": false, "mood_delta": 0.0, "energy_delta": 0.0,
        "akademis_delta": 0.0, "seni_delta": 0.0, "olahraga_delta": 0.0}
    # ... same null / quantity / stock / target-lookup guards ...

    var fields := [
        ["kepribadian1", item.mood_boost,        "mood_delta"],
        ["kepribadian2", item.energy_boost,      "energy_delta"],
        ["akademis1",    item.akademis_boost,    "akademis_delta"],
        ["akademis2",    item.seni_budaya_boost, "seni_delta"],
        ["akademis3",    item.olahraga_boost,    "olahraga_delta"],
    ]
    var out := {"applied": true}
    for f in fields:
        var before: float = float(target.get(f[0], 0.0))
        var after := clampf(before + f[1] * quantity, 0.0, STAT_MAX)
        target[f[0]] = after
        out[f[2]] = after - before

    remove_from_inventory(item.item_name, quantity)
    run_stats.record_item_use(quantity)
    return out
```

Keep the `quantity` param (still used by any single-student caller / tests) even
though the new UI always passes 1.

### 4.4 `GameState.use_item_on_students()` — new batch method

```gdscript
## Applies one copy of `item` to each student id in `student_ids` (one
## application each — quantity is fixed at 1 per student). All-or-nothing: if
## the stack cannot cover every id, nothing is applied and "applied" is false.
## Returns {"applied": bool, "results": Array} where each result is
## {"student_id": int, "name": String, "mood_delta": float, "energy_delta": float,
##  "akademis_delta": float, "seni_delta": float, "olahraga_delta": float}.
func use_item_on_students(item: ItemData, student_ids: Array) -> Dictionary:
    if item == null or student_ids.is_empty():
        return {"applied": false, "results": []}
    if get_inventory_quantity(item.item_name) < student_ids.size():
        return {"applied": false, "results": []}
    var results: Array = []
    for sid in student_ids:
        var name := ""
        for s in approved_students:
            if s.get("id", -1) == sid: name = str(s.get("name", "")); break
        var r := use_item(item, sid, 1)   # consumes 1 from the stack each call
        if r["applied"]:
            r["student_id"] = sid
            r["name"] = name
            results.append(r)
    return {"applied": not results.is_empty(), "results": results}
```

`inventory_changed` fires once per `use_item` call (via `remove_from_inventory`);
the grid rebuild on the final signal is harmless and matches today's behaviour.

---

## Section 5 — Feedback layering summary (all five, transient only)

1. **Grid tile:** staggered pop-in (existing); press/scale via `UIPolish`
   (existing); looping shine sweep on stacks ≥ `shine_min_quantity`;
   `bounce_badge()` when a count changes after an apply.
2. **Bottom sheet:** `popup_spring_in`, icon `wobble`, `count_up` on each
   visible "+N".
3. **Apply screen, on select:** card lift (scale 1.02), `Juice.fill_bar` on
   every affected `StatBar` to the previewed value, `DeltaLabel` pop, live
   `65 ➔ 90 (+25)` / `MAKS` text.
4. **Confirm payoff:** per-student `RewardBurst` + floating gained-stat text +
   rising `star_earn_1/2/3` cue, `payoff_stagger` apart; then screen-wide
   `CelebrationConfetti` + `sparkle` iff every pick gained; `result_fanfare` to
   close; return to grid; used tile's badge bounces; emptied tile is gone after
   rebuild; `"<item> habis"` fades in/out on the authored `ToastLabel`.
5. **Empty / refused states:** `EmptyStateLabel` (text only) when the grid or a
   filter is empty; `&"error"` cue + caption when confirm is pressed with no
   selection or an over-stack selection.

---

## Section 6 — Testing

New suites (all `@tool`, no coroutine tests, `src.contains(...)` scans where the
scene can't be exercised headlessly — the established pattern here):

- **`tests/test_use_item_on_students.gd`**
  - `use_item` writes `kepribadian1`/`kepribadian2` (not `"mood"`/`"energy"`):
    build a fake `approved_students` entry, a fake `ItemData` with
    `mood_boost=10, energy_boost=10, akademis_boost=6`, stock the inventory,
    call `use_item`, assert `entry["kepribadian1"]`, `entry["kepribadian2"]`,
    `entry["akademis1"]` moved and the returned deltas match.
  - clamp at 100; refuse when stock < quantity; refuse on null item.
  - `use_item_on_students` all-or-nothing: 2 in stock, 3 ids → `applied=false`,
    inventory unchanged.
  - `use_item_on_students` happy path: 3 in stock, 3 ids → `applied=true`,
    `results.size()==3`, each has `student_id`/`name`/five deltas, stock now 0.
  - snapshot & restore `GameState.inventory` and `GameState.approved_students`
    in `setup`/`teardown` (follow `test_balance_pacing.gd`'s snapshot pattern).
- **`tests/test_item_detail_sheet.gd`** — scene instantiates; has nodes
  `Scrim`, `Sheet`, `EfekList`, `ApplyButton`; script has no `theme_override`
  string and no `Color(0.`; `EXPLAIN` has all five keys; `setup()` hides a row
  whose boost is 0 (instantiate, call `setup` with a mood-only item, assert
  `RowAkademis.visible == false`, `RowMood.visible == true`).
- **`tests/test_apply_item_screen.gd`** — scene instantiates; has
  `Rows`, `ConfirmButton`, `SelectAllButton`, `RecapIcon`; script routes
  through `GameState.use_item_on_students(`; references `RewardBurst.tscn` and
  `CelebrationConfetti.tscn`; confirm label format string `"Pakai (%d Siswa)"`
  present; no `theme_override` / `Color(0.` in the script; drag-scroll handler
  present.
- **`tests/test_apply_student_row.gd`** — scene instantiates; `KEY` maps the
  five logical names to `akademis1/2/3`,`kepribadian1/2`; `setup()` shows only
  boosted bars; `set_preview(true)` raises a `StatBar.value` and
  `set_preview(false)` restores it; tired student (`kepribadian2 <= 5`) disables
  `Check`.

Edits to existing suites:

- **`tests/test_inventory.gd`** — replace sidebar-era assertions:
  - scene has `FilterRow` and four chip buttons, has **no** node named `Sidebar`,
    `DetailPanel`, or `UsePopup`.
  - `.tscn` raw text contains no `theme_override_styles/` on a `StyleBoxFlat`
    subresource (allow the header `StyleBoxTexture`), and no `Color(0.` literals.
  - script references `detail_sheet_scene` and `apply_screen_scene`.
  - script has **no** `_apply_category_style` / `_style_all_category_buttons` /
    `_build_student_strip` / `_open_use_popup` / `_spawn_floating_stat_pops`.
  - keep: back → `loby.tscn`, `Transition.Style.`, `AudioDirector.play_sfx`,
    no `GameState.player_mood`/`player_energy`, item icons preserved,
    ported art still referenced.
- **`tests/test_viewport_editability.gd`** — remove the
  `"res://Scripts/Inventory/inventory.gd": 4` `BASELINE` entry; confirm the run
  stays green (the three new scripts introduce no tolerated sites).
- **`tests/test_script_documentation.gd`** — no code change; every new script
  gets a `##` header and every new `@export` a `##` line so this stays green.
- If a catalog/`ItemData` suite exists, add an assertion that `ItemData` has
  `akademis_boost`, `seni_budaya_boost`, `olahraga_boost` and that
  `ItemDatabase.get_item("Raket").olahraga_boost == 8`. Otherwise fold that
  into `test_use_item_on_students.gd`.
- **Descriptions:** in the same suite, assert every `ItemDatabase.get_all_items()`
  entry has a non-empty `description` and that all descriptions are unique
  (`desc` set size == item count).

---

## Section 7 — Inventory persistence + debug session reset

This is the project's **first** on-disk save. `CLAUDE.md` currently says "No
save system … do not add persistence to `GameState` without being asked" — this
pass was explicitly asked for. Keep the footprint minimal and update that
`CLAUDE.md` paragraph when the feature lands (note: only `GameState.inventory`
persists; everything else stays session-scoped).

### 7.1 Decisions

- **Persist `GameState.inventory` only** (item_name → quantity). Money, roster,
  week, grade, schedules stay session-scoped.
- **Known limitation, call it out in code + `CLAUDE.md`:** item boosts land on
  `approved_students`, which is **not** persisted. Using an item, then quitting
  before the week simulates, loses that boost on relaunch. Acceptable for this
  pass; a full run-state save is a separate future spec.
- **Write on scene transitions**, not per change.
- **Debug "Forget Session"** wipes in-memory `GameState` to boot defaults,
  deletes the save file, and returns to MainMenu.

### 7.2 `GameState.gd` — persistence API

Separate file from `settings.cfg` so the debug wipe is a single-file delete:

```gdscript
const INVENTORY_SAVE_PATH := "user://inventory.cfg"

## Serialize `inventory` into `cfg` (pure — no disk, no gate). Split out so a
## headless test can round-trip it without hitting the is_editor_hint guard.
func _write_inventory_to(cfg: ConfigFile) -> void:
    cfg.set_value("inventory", "items", inventory.duplicate())

## Inverse of _write_inventory_to. Missing section -> leaves `inventory` empty.
func _read_inventory_from(cfg: ConfigFile) -> void:
    var raw: Dictionary = cfg.get_value("inventory", "items", {})
    inventory.clear()
    for k in raw:
        inventory[String(k)] = int(raw[k])

## Persist the current inventory. No-op in editor/test context (GameState is
## not @tool; a placeholder instance must not touch user://).
func save_inventory() -> void:
    if Engine.is_editor_hint():
        return
    var cfg := ConfigFile.new()
    _write_inventory_to(cfg)
    cfg.save(INVENTORY_SAVE_PATH)

## Load the persisted inventory at boot. Emits inventory_changed so any
## already-built screen rebuilds.
func load_inventory() -> void:
    if Engine.is_editor_hint():
        return
    var cfg := ConfigFile.new()
    if cfg.load(INVENTORY_SAVE_PATH) == OK:
        _read_inventory_from(cfg)
        inventory_changed.emit()

## Delete the on-disk inventory save, if present.
func clear_inventory_save() -> void:
    if FileAccess.file_exists(INVENTORY_SAVE_PATH):
        DirAccess.remove_absolute(INVENTORY_SAVE_PATH)

## Debug: return the whole autoload to a fresh-boot state and drop the save.
## Enumerates every runtime field GameState initializes at declaration — the
## plan author greps GameState.gd for the full list; the fields known today:
##   inventory.clear(); approved_students.clear(); day_schedules.clear()
##   pending_earnings.clear(); player_money = 0; current_week = 1
##   current_grade = 7; run_stats = RunStats.new()  (or its reset())
## then clear_inventory_save(); emit money_changed(0) and inventory_changed.
func forget_session() -> void
```

- `_ready()` — after the existing `print("GameState siap")`, call
  `load_inventory()`.

### 7.3 `Transition.transition.gd` — save hook

In `change_scene()`, immediately after `_busy = true`:

```gdscript
if not Engine.is_editor_hint():
    GameState.save_inventory()
```

One line, before `_cover_in`. Every navigation flushes the current stack; the
only lost-write window is a hard crash mid-scene, which the "on transitions"
choice accepts.

### 7.4 `DebugManager.gd` — Forget Session button

In `_build_general_panel()`, directly after the seed button + its `HSeparator`
(so it sits second, next to the other one-click action), a runtime `Button`
(the overlay builds its own UI — out of design-system scope, unchanged here):

```gdscript
var btn_forget := Button.new()
btn_forget.text = " 🧹 Forget Session (hapus save, ke MainMenu) "
btn_forget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
btn_forget.custom_minimum_size = Vector2(0, 95)
btn_forget.add_theme_font_size_override("font_size", 23)
btn_forget.pressed.connect(_forget_session)
vbox.add_child(btn_forget)
vbox.add_child(HSeparator.new())

func _forget_session() -> void:
    GameState.forget_session()
    _toggle_overlay(false)   # use whatever the overlay's own hide path is
    Transition.change_scene("res://Scenes/MainMenu/main_menu.tscn", Transition.Style.FADE)
```

### 7.5 Tests — `tests/test_inventory_persistence.gd` (new, `@tool`, no coroutine)

- `_write_inventory_to` / `_read_inventory_from` round-trip: set
  `GameState.inventory = {"Komik": 3, "Raket": 1}`, write to a fresh
  `ConfigFile`, clear, read back, assert equal. Snapshot/restore
  `GameState.inventory` in `setup`/`teardown`.
- `_read_inventory_from` on an empty `ConfigFile` leaves `inventory` empty.
- `_read_inventory_from` coerces types: values come back as `int`, keys as
  `String`.
- `forget_session()` empties `inventory` and `approved_students` and resets
  `player_money` to 0 (pure in-memory — safe in test context).
- `save_inventory()` / `load_inventory()` are `is_editor_hint`-gated: call
  `save_inventory()` in the suite and assert **no** file appears at
  `INVENTORY_SAVE_PATH` (proves the guard holds; the real disk path is
  exercised only in a running game).
- `Transition.transition.gd` source contains `GameState.save_inventory()` and
  the `is_editor_hint` guard (source scan).
- `DebugManager.gd` source contains `_forget_session` and
  `GameState.forget_session()` (source scan).

## Balance risk

Item skill-boosts are a new route to a grade's three academic targets, and the
2026-09-04 grade-progression pass is sensitive (per-student weekly minigame
point caps, ramped targets). Mitigations in this design:

- Values are ~⅓ of a good single-day study gain and only three items grant a
  skill boost above +5 (Raket +8, Lompat Tali/Bank Soal +6).
- Items are finite (bought with money that competes with other shop use) and
  each apply consumes one per student.
- `tests/test_balance_pacing.gd` runs a greedy simulation against the real
  functions; after this lands, a follow-up run of that harness with items in the
  greedy policy is the check for whether the table needs trimming. That tuning
  pass is **out of scope here** — this spec ships the mechanism and conservative
  starting numbers, same as prior passes shipped placeholder audio.

## File manifest

| Action | Path | Responsibility |
|---|---|---|
| Rewrite | `Scenes/Inventory/inventory.tscn` | 3-zone portrait layout, theme-driven, no `StyleBoxFlat` overrides, authored `ToastLabel` |
| Rewrite | `Scripts/Inventory/inventory.gd` | grid populate + filter + route to sheet/apply screen + badge bounce; zero runtime visual construction |
| Modify | `Scripts/Inventory/InventorySlot.gd` / `.tscn` | `bounce_badge()`, authored `Shine` node + `shine_min_quantity` export |
| Create | `Scenes/Inventory/EfekRow.tscn` | icon · +N · explainer, one line |
| Create | `Scenes/Inventory/ItemDetailSheet.tscn` + `Scripts/Inventory/ItemDetailSheet.gd` | bottom sheet: item detail + Efek block |
| Create | `Scenes/Inventory/StatBarRow.tscn` | name · StatBar · value · delta |
| Create | `Scenes/Inventory/ApplyStudentRow.tscn` + `Scripts/Inventory/ApplyStudentRow.gd` | one selectable student card with preview |
| Create | `Scenes/Inventory/ApplyItemScreen.tscn` + `Scripts/Inventory/ApplyItemScreen.gd` | full-screen apply modal + staged payoff |
| Modify | `Scripts/Design/ThemeFactory.gd` | new `FilterChipButton` variation; rebake theme |
| Modify | `Scripts/Inventory/ItemData.gd` | `akademis_boost` / `seni_budaya_boost` / `olahraga_boost` |
| Modify | `Scripts/Inventory/ItemDatabase.gd` | `register()` signature + `DEFAULT_ITEMS` skill values |
| Modify | `Scripts/GameState.gd` | fix `use_item` keys + add skills; add `use_item_on_students()` |
| Create | `tests/test_use_item_on_students.gd` | `use_item` key fix + batch method |
| Create | `tests/test_item_detail_sheet.gd` | sheet structure + Efek row show/hide |
| Create | `tests/test_apply_item_screen.gd` | apply screen structure + routing |
| Create | `tests/test_apply_student_row.gd` | row mapping + preview |
| Modify | `tests/test_inventory.gd` | new-layout assertions, drop sidebar-era ones |
| Modify | `tests/test_viewport_editability.gd` | drop `inventory.gd` BASELINE entry |
| Modify | `Scripts/GameState.gd` | `save_inventory` / `load_inventory` / `clear_inventory_save` / `forget_session` + pure `_write/_read_inventory_from`; `load_inventory()` in `_ready` |
| Modify | `Scripts/Transition/transition.gd` | `GameState.save_inventory()` on every `change_scene`, editor-gated |
| Modify | `Scripts/Debug/DebugManager.gd` | "Forget Session" button in the General tab → `forget_session()` + reload MainMenu |
| Create | `tests/test_inventory_persistence.gd` | round-trip, gate, `forget_session`, source scans |
| Update | `CLAUDE.md` | revise the "No save system" paragraph — inventory now persists to `user://inventory.cfg`; nothing else does |
