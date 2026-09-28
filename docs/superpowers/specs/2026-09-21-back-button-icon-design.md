# One back arrow everywhere — design

2026-09-21 · branch `feat/editor-tunable-polish`

> replace all return/back button icon with the new return_button in /downloads

Twelve controls across nine scenes take the player back. They draw **four
different pictures** between them, and one of them draws no picture at all — it
draws the emoji `🔙`, which `CLAUDE.md`'s `## Conventions` explicitly bans. This
spec makes all twelve draw one authored texture.

---

## 0. Ownership — read this before you start

This branch carries **two specs** that touch the same two files.

| File | This spec owns | The other spec owns |
|---|---|---|
| `Scenes/SchoolSimulation/SchoolDay.tscn` | **`DayScreen/BackButton` only** — the node block at `:99`, its `text` at `:105`, and the `icon`/`ext_resource` lines that follow | everything else, incl. `DayScreen`'s re-anchor |
| `Scripts/SchoolSimulation/SchoolDay.gd` | **nothing** | everything, incl. `:1327`'s `"Minggu selesai! 🎉"` emoji fix |
| `docs/superpowers/DEBT.md` — the emoji paragraph `:240-254` and the new grouped emoji entry | **all of it** | nothing |

The other spec is
`docs/superpowers/specs/2026-09-21-editor-tunable-polish-design.md`. Do not
reach outside the boundary above in either direction. `SchoolDay.tscn` is
authored by hand-free editor ops only (`CLAUDE.md` rule 4), so if both specs
are in flight at once, **one of them opens that scene at a time** and the
second re-reads it after the first saves.

**Emoji bookkeeping is this spec's, all of it.** Both specs were editing
`DEBT.md:248-252`; that was removed from the other one. So the `🎉` fix at
`SchoolDay.gd:1327` is made in **code** by the other spec and recorded as
**resolved** in `DEBT.md` by this one (§7). Neither writes the other's half.

**One more cross-spec fact.** After the controller's ruling deleted its "rung
3" contingency, the other spec needs **no theme rebake**. This spec does (§4).
So `Assets/Theme/kejartes_theme.tres` is rebaked **once, by this spec's work**,
and the other spec must not rebake beside it. Per MEMORY *rebake-alone-never-
beside-scene-ops*: rebake in its own step, restart the editor, then diff the
bake before committing — stylebox ids renumber.

---

## 1. What the player sees today

Four pictures, plus an emoji:

| Asset | Size | Colour | Look |
|---|---|---|---|
| `Assets/Images/Achievements/back_arrow.png` | 160×145 | `#FFFFFF` | flat white curved arrow |
| `Assets/Images/Shop/return.png` | 512×512 | `#FFFFFF` | the same silhouette, different alpha bbox, so it draws at a different apparent size |
| `Assets/Images/UI/Placeholders/icon_back.svg` | 16×36 | `#FFFFFF` stroke | a `<` chevron, not an arrow |
| `Assets/Images/UI/pngwing.com (1).png` | 512×512 | pure `#FF0000` | stock clip-art straight arrow |
| — | — | — | SchoolDay's `🔙` glyph |

`Scripts/Design/ThemeFactory.gd:626-629` already records the pure-red clip-art
as a known wart — that pass replaced it on StudentCard's page arrows and left
AturJadwal's back button behind. This finishes the job.

## 2. The change

One texture, `return_button.png`, on all twelve. The user's decision, asked and
answered:

- every control that already draws a back arrow **swaps its texture**;
- SchoolDay's banned emoji is **replaced by the texture**;
- the six plain `Button`s get the texture as their **`icon`** and **keep their
  "Kembali" label** — with one screen excepted below.

Explicitly **not** chosen: converting everything to an icon-only button. The
Indonesian word-label stays on the screens that carry it.

**The one exception, also decided by the user:** `report_card.tscn`'s button
goes **icon-only**. Its box is 260 px and the label needs at least 277 px
beside any icon at all, so the word never fitted; dropping it additionally
closes a live 190 px overlap with the screen's title that `DEBT.md:445-449`
has had parked. Full working in §6.2.

### The asset ships as authored

Measured: 512×512, 8-bit RGBA, true alpha; alpha bbox 498×444 at x 7–504,
y 13–456; stroke `#B92A2A`; interior `#FFFFFF`, fully opaque.

It is a white-filled arrow with a red outline, not a hollow one. That is **not
a regression**: `Shop/return.png` and `Achievements/back_arrow.png` are already
flat white arrows of the same silhouette, so the new asset only *adds* a red
outline, which gives definition the current flat-white arrows lack. On
AturJadwal it replaces an obvious pure-red clip-art arrow and is a clear win.
The controller composited it over all three real backgrounds at each button's
true on-screen size before ruling this. **Do not recolour, re-fill or
regenerate the art.**

**One note for the user, not a blocker:** `#B92A2A` sits in no `DesignTokens`
slot. Nearest are `cat_olahraga` `#E03A18` and `brand_primary` `#7A4A2B`. This
is authored art and therefore the artist's call; it is recorded here so nobody
later "discovers" it as a bug.

---

## 3. Asset import

### 3.1 The canonical path

```
res://Assets/Images/UI/Nav/return_button.png
```

Recon's recommendation, **confirmed**. Three reasons:

- The asset is used by nine different scenes, so it cannot live in a screen
  folder (`Achievements/`, `Shop/`).
- `Assets/Images/UI/Nav/` is the established bucket for shared navigation
  glyphs (`icon_chevron_left/right`, `icon_cta_*`, `icon_nav_*`).
- `UI/Placeholders/` is explicitly the *placeholder* bucket
  (`docs/superpowers/DEBT.md:24-49`). This is authored art and must not go
  there.

Keeping the artist's filename preserves the project's "drop-replaceable at the
same path" contract.

`DEBT.md:25-27` currently declares "the five `Assets/Images/UI/Nav/` icons"
generated placeholder art. **Add one clause to that entry** saying
`return_button.png` is authored, not part of the generated set, so a future
reader does not treat it as regenerable.

### 3.2 The `.import` file

Nothing is hand-authored. Drop the PNG at the path above, run
`filesystem_manage(op="scan")`, and Godot writes
`return_button.png.import`. Commit the PNG **and** the `.import` together.

Diffed against both siblings — `Assets/Images/UI/Nav/icon_chevron_left.png.import`
and `Assets/Images/Achievements/back_arrow.png.import` are **byte-identical in
their `[params]` block**, which is the project's stock lossless UI-texture
profile:

```
importer="texture"
type="CompressedTexture2D"
[params]
compress/mode=0              # lossless, NOT VRAM-compressed
compress/high_quality=false
mipmaps/generate=false
process/fix_alpha_border=true
process/premult_alpha=false
process/size_limit=0
detect_3d/compress_to=1
```

Those are the defaults for a PNG in this project, so the only requirement is
**let the editor generate it, then verify the four lines above**. There is no
`svg/scale` block (SVG-only). No param needs changing.

**Verification step:** after the scan, diff the generated `[params]` against
`icon_chevron_left.png.import`. They must match. A mismatch means the editor
picked up a stale per-file override and the asset will ship VRAM-compressed —
visible as a fringe on the red stroke.

### 3.3 The `uid` question

A new file gets a **fresh, editor-generated `uid`** on import. Nobody may
invent one.

The consequence for the `ext_resource` lines is that they **cannot be written
by hand ahead of the scan**. The order is fixed:

1. drop the PNG, scan, let Godot mint the uid;
2. then open each scene in the editor and set the property, which makes the
   editor write the `ext_resource` line **with the correct `uid=` itself**.

Two details the implementer will hit:

- The tree is **inconsistent** about `uid=` on `ext_resource` lines.
  `achievements.tscn:3-9` and `AchievementDetailSheet.tscn:3-6` carry
  **no `uid=` at all**; `atur_jadwal.tscn`, `koprasi.tscn`, `inventory.tscn`
  and the rest carry it. Both forms load. **Do not normalise the file** — let
  the editor write whatever it writes for the new line and leave the
  neighbouring lines alone, so the diff stays one line per scene.
- Per MEMORY *fix-stale-ext-resource-uid-by-editor-resave*: if a `uid=` ever
  disagrees with the `.import`, the fix is `scene_open` + `scene_save`, not a
  hand edit.

`Scenes/UI/Settings.tscn` is the one scene whose header also changes: it is
`[gd_scene load_steps=3 format=3]` with three `ext_resource`s and gains a
fourth. The editor recomputes `load_steps`; do not touch it.

---

## 4. Icon sizing on a text `Button` — where the override ban bites

A 512×512 `icon` on a `Button` renders **at 512 px** unless something caps it.
That would blow every one of the six buttons apart. So something must cap it,
and `CLAUDE.md`'s rule decides what.

> **The rule: never add a `theme_override_*`.** Use a `ThemeFactory` type
> variation instead. … Only accepted exception: layout-only constant overrides
> (`separation`, `margin_*`).

There are exactly two levers, and only one is right.

| Lever | Legal? | Verdict |
|---|---|---|
| `expand_icon = true` (a plain node property) | legal — not a `theme_override_*` | **Wrong.** It scales the icon to the space left *after* the label, so the arrow's size would change with the word: bigger on ShopHub's 480 px box than on Rapor's 260 px one. `ThemeFactory.gd:576-579` documents exactly this trap ("Capping here rather than with `expand_icon` keeps the glyph a fixed size beside the word instead of stretching with whatever the label happens to be"). |
| `icon_max_width` theme constant on the variation | legal — the sanctioned route | **Right.** Precedents at `ThemeFactory.gd:579, 589, 597, 605, 633`. |

### 4.1 Can the existing variations carry it?

Yes. `SecondaryButton`, `PrimaryButton` and `PrimaryButtonM` all already exist
as baked types; this **adds constants to types that already exist**. No new
variation is needed, and none should be added.

But the three need **three separate entries**, not one inherited entry.
`_add_size_step` at `ThemeFactory.gd:766-777` does:

```gdscript
theme.add_type(name)
theme.set_type_variation(name, "Button")
```

— the base type is `Button`, **not** the parent variation. Confirmed in the
bake: `kejartes_theme.tres:4772` reads `PrimaryButtonM/base_type = &"Button"`.
So a constant set on `PrimaryButton` does **not** reach `PrimaryButtonM`.

### 4.2 The values

Derived from `DesignTokens.gd`, not picked by eye:

| Token | Value |
|---|---|
| `space_xs` | 8 |
| `space_sm` | 16 |
| `space_md` | 28 |
| `btn_icon_s` | 48 |
| `btn_pad_v_s` | 30 |
| `btn_pad_v_m` | 40 |
| `font_title` | 36 |
| `font_h2` | 48 |

The base step's height solves `2 × btn_pad_v_s (30) + font_title (36) = 96` —
which is also `touch_target_min`. An `icon_max_width` **above 36** makes the
icon the tallest content and pushes the button past 96 px. So the cap is
exactly the font line: **36**. The M step solves
`2 × btn_pad_v_m (40) + font_h2 (48) = 128`, so its cap is **48**.

`h_separation` needs setting too. The bake has **no `constants/` block on any
of the three variations, and no `Button/constants/h_separation` at all**
(`kejartes_theme.tres:4369-4374`), so Godot's built-in **4 px** gap applies —
far too tight beside a 36 px glyph. `space_sm` (16) is the project's small gap
and is what `LobbyNavTile` uses at a comparable scale.

Add to `Scripts/Design/ThemeFactory.gd`, inside `_build_buttons`, after the
size-step loop (currently ending at `:645`). Every `##` doc line is a hard
rule here (`tests/test_script_documentation.gd`), so the comment ships with it:

```gdscript
# The back arrow beside "Kembali", on every screen that has one. Capped
# rather than expand_icon'd so the glyph is a fixed size next to the word
# instead of stretching with whatever the label happens to be -- the same
# reason the badge chips cap theirs. 36 is the display font's line at the
# S step, so the button keeps its 96px height (2*btn_pad_v_s + font_title),
# which is also touch_target_min; a larger cap would make the icon the
# tallest content and grow the button.
for base in ["PrimaryButton", "SecondaryButton"]:
    theme.set_constant("icon_max_width", base, tokens.space_md + tokens.space_xs)  # 36
    theme.set_constant("h_separation", base, tokens.space_sm)                      # 16
# _add_size_step sets base_type to Button, not to the parent variation, so
# the M step needs its own entry. It is 128px tall (2*btn_pad_v_m +
# font_h2), which carries a 48px arrow.
theme.set_constant("icon_max_width", "PrimaryButtonM", tokens.btn_icon_s)          # 48
theme.set_constant("h_separation", "PrimaryButtonM", tokens.space_sm)              # 16
```

### 4.3 Rebake

Required. Run `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X),
which rewrites `Assets/Theme/kejartes_theme.tres`.

Expect exactly six new lines:

```
PrimaryButton/constants/h_separation = 16
PrimaryButton/constants/icon_max_width = 36
PrimaryButtonM/constants/h_separation = 16
PrimaryButtonM/constants/icon_max_width = 48
SecondaryButton/constants/h_separation = 16
SecondaryButton/constants/icon_max_width = 36
```

Per `CLAUDE.md` rule 4b and MEMORY: **scene work first, script work second**,
then patch `ThemeFactory.gd`, then **restart the editor**, then rebake, then
`git diff` the bake. Do not rebake in the same editor session as a
`scene_save`.

### 4.4 `DISPLAY_ROSTER` does **not** change

`tests/test_theme_factory.gd:328-348`'s `DISPLAY_ROSTER` pins **which typeface
each variation wears**, and its paired stray check (`:445-452`) walks
`get_type_list()` looking for types that got the display font but are not on
the roster. We add **constants**, set no font, and create **no new type** — all
three variations already exist and `PrimaryButton`/`SecondaryButton` are
already on the roster. **No roster edit is needed.** (`PrimaryButtonM` is not
on the roster today and must not be added; it inherits nothing from this
change.)

### 4.5 `icon_alignment` and `vertical_icon_alignment`

- Godot's `Button.icon_alignment` default is `HORIZONTAL_ALIGNMENT_LEFT` (0),
  which is what the arrow wants — it leads the word.
- **Set `icon_alignment = 0` explicitly on the five buttons that gain an icon**
  (ShopHub, CosmeticShop, ReportCard, Settings, RunResult, SchoolDay), so the
  intent survives a future `alignment` edit.
- **Leave Inventory's absent.** The property is not in `inventory.tscn` today
  and `tests/test_inventory.gd:99` asserts it resolves to LEFT; keeping it
  absent keeps that assertion true without touching the line.
- `vertical_icon_alignment` stays default (CENTER). Do **not** copy
  `loby.tscn`'s `vertical_icon_alignment = 0` — that is for its stacked tiles.

### 4.6 What the arrow actually measures on screen

`icon_max_width` caps the **texture canvas**, and the canvas is 512×512 with
the art inset. At a 36 px cap the drawn arrow is `498/512 × 36 = 35.0` px wide
and `444/512 × 36 = 31.2` px tall; at 48 it is 46.7 × 41.6. That is
proportionate beside a 36 px / 48 px cap-height label. Worth knowing before
anyone reports the arrow as "too small" — the fix would be a tighter crop of
the source art, not a larger cap, because a larger cap changes button height.

---

## 5. The twelve controls

Content margins for the base step are `space_lg` = 44 px horizontal,
`btn_pad_v_s` = 30 px vertical (`ThemeFactory.gd:828-831`).

`<NEW>` = the `ext_resource` id the editor mints for
`res://Assets/Images/UI/Nav/return_button.png` in that scene.

| # | Scene : line | Node path | Type | Property | Before | After | Sizing change |
|---|---|---|---|---|---|---|---|
| 1 | `Scenes/Achievements/achievements.tscn:129` | `Safe/UI/BackButton` | `TextureButton` | `texture_normal` | `ExtResource("5_back")` → `Achievements/back_arrow.png` | `ExtResource("<NEW>")` | **none** — see §5.1 |
| 2 | `Scenes/Achievements/AchievementDetailSheet.tscn:53` | `Sheet/Margin/VBox/BackButton` | `TextureButton` | `texture_normal` | `ExtResource("2_back")` → `Achievements/back_arrow.png` | `ExtResource("<NEW>")` | none — 64×64 box, `stretch_mode = 5` |
| 3 | `Scenes/AturJadwal/atur_jadwal.tscn:356` | `BackButton` | `TextureButton` | `texture_normal` | `ExtResource("11_left_arrow")` → `UI/pngwing.com (1).png` | `ExtResource("<NEW>")` | **none — do not touch the 100×100 rect**, see §5.2 |
| 4 | `Scenes/AturJadwal/atur_jadwal.tscn:548` | `Penjadwalan/TextureRect/PopupBack` | `TextureButton` | `texture_normal` | `ExtResource("10_return")` → `Shop/return.png` | `ExtResource("<NEW>")` | **none — offsets are frozen**, see §5.2 |
| 5 | `Scenes/Koperasi/koprasi.tscn:895` | `Stage/BackButton` | `TextureButton` | `texture_normal` | `ExtResource("5_46s2e")` → `Shop/return.png` | `ExtResource("<NEW>")` | **none — rect and node type are both pinned**, see §5.3 |
| 6 | `Scenes/Inventory/inventory.tscn:54` | `MainColumn/Header/HeaderCol/Row/BackButton` | `Button` | `icon` | `ExtResource("4_o4jeo")` → `UI/Placeholders/icon_back.svg` | `ExtResource("<NEW>")` | none authored; min width 277 → ~309, see §6.1 |
| 7 | `Scenes/Koperasi/ShopHub.tscn:60` | `BackButton` | `Button` | `icon` | *(absent)* | `ExtResource("<NEW>")` + `icon_alignment = 0` | none — fixed 480×96 |
| 8 | `Scenes/Koperasi/CosmeticShop.tscn:47` | `BackButton` | `Button` | `icon` | *(absent)* | `ExtResource("<NEW>")` + `icon_alignment = 0` | none — fixed 480×96 |
| 9 | `Scenes/ReportCard/report_card.tscn:1552` | `Safe/UI/BackButton` (`%BackButton`) | `Button` | `icon`, **`text`**, **`offset_right`** | `text = "Kembali"`, no icon, `offset_right = 302.0` | `text = ""`, `icon = ExtResource("<NEW>")`, `icon_alignment = 0`, **`offset_right = 138.0`** | **260×96 → 96×96, icon-only.** Plus `PilihMurid.offset_left` 112 → 154. See §6.2 |
| 10 | `Scenes/UI/Settings.tscn:165` | `SafeArea/Layout/BackButton` | `Button` | `icon` | *(absent)* | `ExtResource("<NEW>")` + `icon_alignment = 0` | none — VBox child, fills width |
| 11 | `Scenes/EndGame/RunResult.tscn:91` | `MarginContainer/Column/BtnSelesai` | `Button` | `icon` | *(absent)* | `ExtResource("<NEW>")` + `icon_alignment = 0` | none — `custom_minimum_size (0,128)`, 48 px cap fits |
| 12 | `Scenes/SchoolSimulation/SchoolDay.tscn:99` | `DayScreen/BackButton` | `Button` | `text` (`:105`) **and** `icon` | `text = "🔙 Kembali ke Menu"`, no icon | `text = "Kembali ke Menu"`, `icon = ExtResource("<NEW>")`, `icon_alignment = 0` | none — `size_flags_horizontal = 3`, stretches |

No `custom_minimum_size` changes anywhere. No `expand_icon` anywhere. Site 9 is
the only rect that moves, and it moves **inward** (§6.2).

### 5.1 Site 1 — accept the centred render, do not resize the rect

`achievements.tscn:129`'s box is **160×145** with `stretch_mode = 5`
(KEEP_ASPECT_CENTERED). `back_arrow.png` is exactly 160×145 and fills it. The
new square source renders **145×145 centred**, leaving 7.5 px of empty button
either side.

**Decision: leave the rect alone.** The empty margin is inside the button and
invisible; narrowing `offset_right` to 213 would shrink a touch target for no
visual gain and put a geometry diff in a scene nothing else in this change
touches. `tests/test_achievement_screen.gd:52-55` only asserts
`anchor_top == 1.0`, so either choice is test-safe — this picks the one with
the smaller diff.

### 5.2 Sites 3 and 4 — two frozen geometries in one scene

- **Site 3's rect is a touch-target floor.**
  `tests/test_atur_jadwal.gd:111-131` includes `"BackButton"` and asserts
  `minf(h, w) >= tokens.touch_target_min` (96). The button is exactly
  **100×100** — 4 px of slack. **Do not shrink it.**
- **Site 4's offsets are pinned literally.**
  `tests/test_atur_jadwal.gd:533-541`:
  ```gdscript
  assert_eq(back.offset_left, 329.0, "back arrow x, 6.7% in from the card's left")
  assert_eq(back.offset_top, 1170.0, "back arrow y, its art centred 92.3% down the card")
  ```
  Texture swap only.

Site 4 uses `stretch_mode = 0` (SCALE) on a square 178×178 box. `return.png`'s
alpha bbox is 512×379 and the new one is 498×444, so **the drawn arrow gets
~17% taller and ~3% narrower in the same box**. Cosmetic, not a layout change,
and that assertion's doc comment ("its art centred 92.3% down the card")
describes the box, which does not move.

`tests/test_atur_jadwal.gd:641`'s `test_no_pngwing_placeholder_remains_in_the_warning_dialog`
scans only the **`Peringatan`** node block for id `3_a6kja` — a different
pngwing file (`(2).png`) on a different node. Unaffected.

### 5.3 Site 5 — the node type is pinned by a source-text scan

`tests/test_koperasi_back_follows_tray.gd:106` and `:122` both search
`koprasi.tscn`'s **raw text** for the literal:

```gdscript
_node_block(scene_src, "[node name=\"BackButton\" type=\"TextureButton\" parent=\"Stage\"")
```

`type="TextureButton"` is part of that literal, so the node's **type** is
pinned. It stays a `TextureButton` under this design, so the suite stays green —
but this is the one place a type change would fail loudly, and it is worth
knowing that the guard exists.

`:125` also pins `offset_left`/`offset_top` against `koprasi.gd`'s
`back_pos_expanded` (24, 1157). `koprasi.gd` tweens that node's **position**
only, never its size, so a texture swap is inert. Likewise
`Scripts/Koperasi/koprasi.gd:186`'s `AnimUtils.back_bounce(back_button)` and
`Scripts/AturJadwal/atur_jadwal.gd:173`'s `_setup_portrait_juice(back_button)`
both take a `Control` — neither reads the texture.

### 5.4 `ignore_texture_size` — verified on all five

A 512×512 `texture_normal` sets a `TextureButton`'s minimum size to 512 unless
`ignore_texture_size = true`. **All five already carry it** (verified in
source: `achievements.tscn:141`, `AchievementDetailSheet.tscn:59`,
`atur_jadwal.tscn:367` and `:555`, `koprasi.tscn:902`). Nothing to add — but
§10.4's test 3 pins this so a future edit cannot drop it and silently blow a
layout apart.

---

## 6. Per-button room check

`icon_max_width = 36` + `h_separation = 16` adds **52 px** of content width to
a base-step button; the M step adds `48 + 16 = 64`.

| # | Button | Box today | Content after | Verdict |
|---|---|---|---|---|
| 6 | Inventory | measured live: `Row` **1024×96**, `BackButton` **277×96** at x=0, `CoinPill` **79×50** at x=945 | min width 277 → ~309 | **Abundant room — 668 px of free space in the row.** See §6.1 |
| 7 | ShopHub | fixed **480×96** anchored block | 44 + 36 + 16 + ~170 + 44 = **310** | ample — 170 px of slack |
| 8 | CosmeticShop | identical **480×96** | **310** | ample |
| 9 | ReportCard | fixed **260×96**, `PrimaryButton` | **≥310** in a 260 px box | **The label cannot fit beside any icon. Goes icon-only — see §6.2.** |
| 10 | Settings | `VBoxContainer Layout` child, no explicit size, fills width | grows by 52 | ample. Note the label is uppercase `"KEMBALI"` |
| 11 | RunResult | `custom_minimum_size (0,128)` in a VBox inside a 64 px MarginContainer → ~952 px wide; `"Kembali ke Menu"` at `font_h2` 48 ≈ 380 px | 44 + 48 + 16 + 380 + 44 = **532** | ample; the 48 px arrow fits the 128 px height |
| 12 | SchoolDay | `size_flags_horizontal = 3` in VBox `DayScreen`, authored `visible = false` | stretches | ample |

### 6.1 Inventory — abundant room, and `DEBT.md:430-441` is wrong

The dispatch flagged Inventory as known-tight and asked for a decision: cap its
icon smaller, or make the header fix a prerequisite. **Neither is needed.**
Measured live in the editor, 2026-09-21:

| Node | Rect | Flags |
|---|---|---|
| `HeaderCol/Row` | **1024 × 96** at (0, 0) | — |
| `Row/BackButton` | **277 × 96** at **x = 0** | `size_flags_horizontal = 0` (SHRINK_BEGIN) |
| `Row/CoinPill` | **79 × 50** at **x = 945** | `size_flags_horizontal = 8` (SHRINK_END) |
| `HeaderCol/TitleLabel` | 1024 × 96 at **y = 114** | a separate row *below* `Row` |

**There are 668 px of free space** between the back button's right edge (277)
and the coin pill's left edge (945), inside a 1024-wide row. The 277 px is the
button's *minimum* for "Kembali" plus the 16×36 chevron at `SecondaryButton`;
the 36 px arrow takes it to ~309, leaving ~636 px still free. Inventory has
abundant room. **Swap it at the same 36 px cap as everything else.**

#### Why the DEBT entry says otherwise

`DEBT.md:430-441` measures the header as **one row**:

> `BackButton` 277 + `TitleLabel` "INVENTORY" 582 + `CoinDisplay` 181, three
> 20 px gaps and the `Card`'s two 28 px margins make 1156 px, so the column
> sits at x −38 and every row clips

That measurement is dated **2026-09-15**. The mobile redesign `431cc5d`
restructured the scene afterwards — `DEBT.md:202-209` records the resulting
node-path break (`MainColumn/Header/Row/…` → `MainColumn/Header/HeaderCol/Row/…`)
on **2026-09-16**. The live read above confirms the consequence: `TitleLabel`
sits at **y = 114**, on its own line below `Row`, so the three widths no longer
**sum**. The header's minimum width is `max(Row, TitleLabel)`, not
`Row + TitleLabel`.

The scene as it stands:

```
MainColumn (VBox)
  Header (PanelContainer, Card, custom_minimum_size (0,196))
    HeaderCol (VBoxContainer, separation 18)
      Row (HBoxContainer, separation 20)
        BackButton   Button, SecondaryButton, SHRINK_BEGIN
        Spacer       Control, EXPAND
        CoinPill     PanelContainer, SHRINK_END
      TitleLabel     Label, DisplayLabel, "INVENTORY"
```

`TitleLabel` is a **sibling of `Row` inside a VBoxContainer**. Arithmetic,
matching the measured rects:

| | today | after |
|---|---|---|
| `Row` min width (`BackButton` + 20 + `Spacer` 0 + 20 + `CoinPill`) | 277 + 40 + 181 = **498** | 309 + 40 + 181 = **530** |
| `TitleLabel` min width ("INVENTORY", `DisplayLabel`, `font_display_size` 96) | **~582** | **~582** (unchanged) |
| `HeaderCol` min = max of the two | **582** | **582** |

**The icon changes the header's minimum width by exactly zero.** `Row` is 52 px
narrower than the title even after the change, and the title is untouched.
There is nothing to cap down and nothing to fix first.

#### It holds at any balance

`CoinPill` is the one element in the row that grows with game state, so the
gap is checked at the worst case rather than at the authored `text = "0"`.

The pill is `CoinIcon` (`custom_minimum_size` 50×50) + `separation` 8 +
`CoinLabel`, and it measured **79 px** with a one-digit label — so a digit is
**~21 px** and the pill's own stylebox contributes ~0. At six digits
(999999G, the seed's balance and the most the game shows):

| | width |
|---|---|
| `BackButton` with the 36 px arrow | 277 + 20 = **~297** |
| `CoinPill` at six digits | 50 + 8 + ~126 = **~184**, starting at 1024 − 184 = **x ≈ 840** |
| gap between them | **~543 px** |

Even at a pessimistic 30 px per digit the gap is ~489 px. **The conclusion
holds at every balance**, because the button and the pill shrink from opposite
ends of a fixed 1024 px row — they cannot meet.

#### This branch deletes the DEBT entry

`DEBT.md:430-441` is not merely stale. It claims a 1156 px header in a 1080 px
screen; the real figure is `TitleLabel`'s ~582 plus the `Card`'s two 28 px
margins = **638**. It is **wrong by roughly 600 px**, and as written it would
send the next reader hunting an overflow that does not exist and blaming a
button that has 543 px of room. Per `CLAUDE.md` ("an entry is deleted once
resolved, not marked done"), **delete it outright** rather than rewriting it.
The measured numbers live here, in §6.1, which is where a spec's evidence
belongs.

§10.2 pins the relationship with two tests, so the structure cannot silently
regress once the entry is gone.

### 6.2 ReportCard goes icon-only, and that closes `DEBT.md:445-449`

**Decided by the user.** Rapor's back control is the arrow alone, no "Kembali".
Every other screen keeps its label per the earlier decision. This is the
specified behaviour, not an option.

#### The label could never have fitted

Site 9's box is **fixed at 260×96** (`offset_left 42`, `offset_right 302`) at
`PrimaryButton`. Inventory supplies the hard number: **"Kembali" plus a 16 px
chevron already needs 277 px** at `SecondaryButton`, which carries the same
`space_lg` 44 px horizontal padding and the same `font_title` 36 label. So the
label would not have fitted in 260 px beside **any** icon — not the 36 px
arrow, not the 16 px chevron it replaces, not a 1 px one. The ~310 px figure
for the arrow is the margin of failure, not the cause of it.

#### It also removes a live 190 px overlap

Rapor renders a real bug today. Measured:

| Node | x range | Note |
|---|---|---|
| `Safe/UI/PilihMurid` "Rapor Murid", `DisplayLabel` | **112 → 1012** | no `horizontal_alignment`, so it defaults to **0 = LEFT** — the text starts at 112 |
| `Safe/UI/BackButton`, `PrimaryButton` | **42 → 302** | absolutely positioned |

They overlap by **190 px**, and an editor capture confirms the title renders as
"…OR MURID" with the button covering "Rap". This is exactly the parked
`DEBT.md:445-449` "Rapor waits for the separate `KEMBALI` overlap fix".

#### The geometry, and why 96 px alone is not enough

An icon-only button wants to be square and must clear `touch_target_min` = 96.
`offset_left` is **pinned** by `tests/test_tall_screen_layout.gd:510-511`
(`Vector2(90, 82)`, which is 42 in `Safe`-local coordinates plus the
`SafeAreaMargin`'s 48 px inset), so the button can only shrink from the right:

```
offset_right = 42 + 96 = 138        → a 96 × 96 icon-only button
```

That cuts the overlap from 190 px to **26 px** — it does **not** reach zero,
because 138 > `PilihMurid`'s 112. Closing the entry therefore needs one more
move, and the cheapest that respects every pin is to nudge the title right:

```
PilihMurid.offset_left  112 → 154   (offset_right stays 1012)
```

| | before | after |
|---|---|---|
| `BackButton` | 42 → **302** | 42 → **138** (96 × 96) |
| `PilihMurid` | **112** → 1012 | **154** → 1012 |
| Overlap | **190 px** | **0 px**, with 16 px (`space_sm`) of clearance |

`PilihMurid`'s rect narrows from 900 to **858** px. "Rapor Murid" at
`DisplayLabel` (`font_display_size` 96) measures roughly 735 px, so it keeps
~123 px of slack and does not clip — it does not clip at 900 today either.

**This closes `DEBT.md:445-449`.** Per `CLAUDE.md` ("an entry is deleted once
resolved, not marked done"), delete that entry. It is also named in
`DEBT.md:436`'s deferred tall-phone list ("Rapor waits for the separate
`KEMBALI` overlap fix, which edits that scene") — that clause goes too, since
the thing it waits for has happened.

#### Cost

One assertion moves, in `tests/test_tall_screen_layout.gd:508-509`:

```gdscript
assert_eq(_authored_rect(rapor.get_node("%PilihMurid") as Control).position,
    Vector2(160, 82), "PilihMurid")     →     Vector2(202, 82)
```

(154 + 48 = 202; the y is unchanged.) `%BackButton`'s own pin at `:510-511`
stays `Vector2(90, 82)` — `offset_left` and `offset_top` do not move, only
`offset_right`. `tests/test_report_card.gd:68-74` checks only that a
`BaseButton` named `BackButton` exists and asserts nothing about `text`, so it
stays green.

---

## 7. The emoji ban

> **No emoji as UI iconography.** Use real transparent SVG textures instead —
> explicitly banned during the 2026-09-02 end-of-grade pass after report icons
> briefly used emoji glyphs. — `CLAUDE.md`, `## Conventions`

**This spec owns all emoji `DEBT.md` bookkeeping for this branch.** The
header/firework spec was editing the same `:248-252` paragraph; that was
removed from it, so `DEBT.md`'s emoji prose has exactly one author here (§0).

### In scope — fixed by this spec

`Scenes/SchoolSimulation/SchoolDay.tscn:105`

```
text = "🔙 Kembali ke Menu"     →     text = "Kembali ke Menu"
```

plus the `icon`. This clears the violation named by `DEBT.md:248-249`.

There is a second reason beyond the ban: `DEBT.md:240-247` records that Boohong
(the face every button label wears) has no `←` or `→` and mis-maps `‹`/`›` to
its apostrophe glyph, which is why Inventory's "‹ Kembali" once shipped as
"' KEMBALI". `🔙` is not in Boohong either — it rides whatever system font the
device picks, so **nobody has ever seen the same glyph on two devices**. An
icon is the documented answer.

### The rest of the sweep — recorded, not fixed

Two violations on this branch are resolved between the two specs, and
everything else becomes one grouped `DEBT.md` entry that this spec writes.

**Resolved on this branch — list as done, not outstanding:**

| Where | Glyph | By |
|---|---|---|
| `Scenes/SchoolSimulation/SchoolDay.tscn:105` | 🔙 | **this spec** |
| `Scripts/SchoolSimulation/SchoolDay.gd:1327` `"Minggu selesai! 🎉"` | 🎉 | **the other spec**, in code (§0) |

**Still outstanding in `SchoolDay` display text** (verified line by line;
`SchoolDay.gd` is the other spec's file, so none of these is fixed here):

| Where | Glyph | String |
|---|---|---|
| `SchoolDay.gd:78` | 🎓 | `end_tutorial_title` — `"Selamat Menyelesaikan Minggu Pertama! 🎓"` |
| `SchoolDay.gd:80` | 🎯 ➔ | `end_tutorial_text` — `"… Atur Jadwal ➔ Simulasi Hari Sekolah ➔ …"`, `"🎯 Misi Utamamu:"` |
| `SchoolDay.gd:437` | ✓ | `status_label.text = day_name + " selesai! ✓"` |
| `SchoolDay.gd:959` | 🌿 | `"Hari Libur Nasional: %s 🌿"` |
| `SchoolDay.tscn:95` | ✨ ➔ | `"✨ Klik di mana saja untuk melanjutkan ➔"` |
| `SchoolDay.tscn:113` | ⏭ | `"⏭ Skip (Tekan O)"` |

`SchoolDay.gd:537-538` and `:628-655` carry emoji too, but they are **icon
keys** that `_add_pill` (`:664-682`) strips before display — not display text,
and correctly out of the sweep.

### Elsewhere — out of scope for this branch

The full sweep of every `.tscn` (excluding `.claude/worktrees/`,
`-REFERENCE-/`, `.godot/`) found these still in a `text =` property. **None are
touched by this spec**:

| Scene : line | Glyph | `text` |
|---|---|---|
| `SchoolSimulation/DailyDecayOverview.tscn:61` | 🌅 | `"🌅 Aktivitas & Evaluasi Harian"` |
| `SchoolSimulation/DailyDecayOverview.tscn:95` | ➔ | `"Lanjutkan Hari ➔"` |
| `SchoolSimulation/DaySummaryBadge.tscn:9` | ✨ | `"✨ BONUS EVENT +15"` |
| `AturJadwal/DayStickyNote.tscn:106` | 🔒 | `"🔒"` |
| `UI/StatDetailPopup.tscn:66`, `TraitDetailPopup.tscn:60`, `WeekRecapPillInfoPopup.tscn:48` | ✕ | `"✕"` |
| `Minigames/Akademis/Menjodohkan.tscn:107,126,151,162,207,226` | ◀ ▶ 🔒 ✨ | various |
| `Minigames/Olahraga/MainBola.tscn:157` | ↑ | `"↑ Swipe Up to Shoot"` |
| `Minigames/UI/MinigameMenu.tscn:120` | 🏫 | `"🏫 Simulasi Minggu Sekolah"` |

Plus two in **script**, already logged: `Scripts/UI/StatDetailPopup.gd`'s
`info["glyph"]` (`DEBT.md:235-238`) and `Scripts/CutScene/cut_scene.gd`'s
`_create_grade_button` 🏫/🎓 (`DEBT.md:249-253`).

Two notes on that list:

- The six `Scenes/Minigames/**` rows sit **outside the design system's scope**
  per `CLAUDE.md` and are not debt at all.
- The `✕` close glyphs are arguably typography rather than iconography, but
  `DEBT.md:243-247`'s instruction ("keep such characters out of their text, and
  draw an arrow or chevron as an SVG icon") points the same way.

**Why none of the `SchoolDay` survivors is fixed here**, although the branch
has both files open: every one of them needs **new authored art** — a sparkle,
a right-arrow, a skip glyph, a check, a leaf, a mortarboard, a target. That is
art commissioning, not a texture swap, and it is a different kind of work from
the one this branch signed up for. Recording them precisely is the deliverable.

### The `DEBT.md` rewrite this spec owns

`DEBT.md:240-254` is one paragraph. Three edits, all in it:

1. **`:244`** — "until the chevron became `icon_back.svg`" now names a deleted
   asset (§8). Re-point it at the shared `UI/Nav/return_button.png`. The
   historical fact stays true; only the asset name changes.
2. **`:248-249`** — delete the SchoolDay `BackButton` / `🔙` clause. Resolved.
3. **`:249-252`** — keep the CutScene `🏫`/`🎓` clause; still open.

Then **add one grouped entry** below it — grouped, not one per glyph, per
`CLAUDE.md`'s instruction for `DEBT.md`:

> **Emoji still used as iconography (swept 2026-09-21).** The ban in
> `## Conventions` is still broken in display text in three places.
> **SchoolDay** — `SchoolDay.gd:78` 🎓, `:80` 🎯 and two ➔, `:437` ✓, `:959` 🌿;
> `SchoolDay.tscn:95` ✨ ➔ and `:113` ⏭. (`:105`'s 🔙 and `:1327`'s 🎉 were
> fixed on 2026-09-21.) **Other screens** — `DailyDecayOverview.tscn:61` 🌅
> and `:95` ➔, `DaySummaryBadge.tscn:9` ✨, `DayStickyNote.tscn:106` 🔒, and
> the `✕` on `StatDetailPopup` / `TraitDetailPopup` /
> `WeekRecapPillInfoPopup`. Each needs a real transparent texture, which is
> art work rather than a swap — that is why they were left when the back
> arrows were unified. `Scenes/Minigames/**` is outside the design system's
> scope and is not counted here. The pill glyphs at `SchoolDay.gd:537-538`
> and `:628-655` are icon *keys* stripped by `_add_pill` (`:664-682`), not
> display text.

---

## 8. The four superseded assets

All four become unreferenced. Grep evidence, excluding `.claude/worktrees/`,
`-REFERENCE-/`, `.godot/`, `docs/` and `.superpowers/` (prose mentions in old
plans and changelogs are not references):

| Asset | Live references **today** | After | Action |
|---|---|---|---|
| `Assets/Images/Achievements/back_arrow.png` | `achievements.tscn:7`, `AchievementDetailSheet.tscn:4` — **only these two** | **unreferenced** | delete, with its `.import` |
| `Assets/Images/Shop/return.png` | `atur_jadwal.tscn:10`, `koprasi.tscn:7` — **only these two** | **unreferenced** | delete, with its `.import` |
| `Assets/Images/UI/pngwing.com (1).png` | `atur_jadwal.tscn:11` — **only this one** | **unreferenced** | delete, with its `.import` |
| `Assets/Images/UI/Placeholders/icon_back.svg` | `inventory.tscn:6` — **only this one** | **unreferenced** | delete, with its `.import`, **after** `tests/test_inventory.gd` is rewritten (§10.1) |

Two near-misses that the grep flushed out and that must **not** be deleted:

- `Assets/Images/UI/pngwing.com (3).png` is a **different file**, still live at
  `student_card.tscn:14`. Only `(1)` goes. (`(2)` and `(6)` are likewise other
  files; `docs/superpowers/specs/2026-09-09-studentcard-architecture-map.md:187`
  says StudentCard once used `(1)`, but that was before the `CardArrowButton`
  pass and is no longer true.)
- `Assets/Images/UI/Nav/icon_chevron_left.png` is **not** a back button — it is
  Rapor's page-turn arrow (`report_card.tscn:1508-1519`, `CardArrowButton`).
  Leave it.

**Deletion mechanics.** Delete the source **and** its `.import` in the **same
commit**, and only **after** every scene has stopped referencing it — otherwise
the editor recreates the `.import` on its next scan, and the uid embedded in a
still-referencing `.tscn` (e.g. `uid://fuwhxl8ethbp` for `return.png`) breaks
the scene load. Order: scenes first, delete second.

**`DEBT.md` edits that ship with this branch.** Five, and two of them are
deletions — per `CLAUDE.md`, a resolved entry is removed, not marked done:

| Lines | Edit | Why |
|---|---|---|
| `:25-27` | **add** a clause: `return_button.png` is authored art, not part of the generated `UI/Nav/` set | §3.1 — that entry currently declares everything in `UI/Nav/` regenerable |
| `:35` | **remove** the `icon_back.svg` clause | the asset is deleted |
| `:244` | **re-point** "until the chevron became `icon_back.svg`" at `UI/Nav/return_button.png` | §7 — it names a deleted asset |
| `:248-249` | **remove** the SchoolDay `🔙` clause; keep `:249-252`'s CutScene clause | §7 — that violation is fixed |
| `:430-441` | **delete outright** | §6.1 — wrong by ~600 px, not merely stale |
| `:436` | **remove** the "Rapor waits for the separate `KEMBALI` overlap fix" clause from the deferred tall-phone list | §6.2 — it no longer waits |
| `:445-449` | **delete** the parked Rapor `KEMBALI` overlap entry | §6.2 — the overlap goes 190 px → 0 |

Two new entries are added in the same pass: the grouped emoji entry written out
in §7, and one line proposing the remaining `pngwing.com` stock files be
replaced (§8, *Licensing*).

Five of these are **deletions**. That is the point: `CLAUDE.md` says a resolved
entry is removed, not marked done, and this branch resolves four separate
things that `DEBT.md` currently carries as open.

### Licensing

`pngwing.com (1).png` is a **stock-clipart filename**, verbatim from a
free-PNG aggregator. Removing it is a genuine licensing tidy-up as well as a
visual one: the project has no recorded licence for it, and PngWing's terms are
non-commercial for most of its catalogue. Its siblings `(2)`, `(3)` and `(6)`
remain in the tree — `(6)` was already replaced on Koperasi's basket per
`CHANGELOG.md:1461`, and `(2)` per `test_atur_jadwal.gd:641`. **Worth a
separate `DEBT.md` line proposing the remaining stock files be replaced**, but
out of scope here.

---

## 9. Audio

`Assets/Audio/SFX/BackButtonTap.ogg` is **registered but never played**, and
this change neither adds nor removes that.

- `Scripts/Audio/AudioDirector.gd:122-124` declares
  `@export var sfx_back_tap` preloading it;
- `:372` maps `&"back_tap"` to it;
- `tests/test_audio_director.gd:594` lists `&"back_tap"` in the cue roster.

Those three are the **only** occurrences in the tree. Nothing calls
`play_sfx(&"back_tap")`, which `DEBT.md:131-141` already records under "Unused
pack cues (2026-09-21)".

**What every back control actually plays today** is the generic tap, auto-wired
by `UIPolish` for *every* `BaseButton` in the scene tree
(`Scripts/UI/UIPolish.gd:3,99` → `AudioDirector.play_sfx(&"tap")`). Because
`UIPolish` keys on `BaseButton`, it covers `Button` and `TextureButton`
identically.

**Consequence: none.** No node type changes under this design, so `UIPolish`'s
auto-juice and auto-SFX survive untouched on all twelve. Nothing can be dropped
because nothing screen-specific is wired.

Wiring the dedicated cue is **one line in each `_on_back_pressed`** and would
be cheap while these files are open — but it is a behaviour change the user did
not ask for, and it belongs to the DEBT entry that tracks all 12 unused cues.
**Out of scope unless asked.**

---

## 10. Tests

### 10.1 The one hard blocker — `tests/test_inventory.gd:92-101`

```gdscript
func test_back_button_draws_its_chevron_as_an_svg_icon() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var back := s.get_node("MainColumn/Header/HeaderCol/Row/BackButton") as Button
	assert_not_null(back.icon, "the back chevron must be a texture on the button")
	if back.icon != null:
		assert_true(back.icon.resource_path.ends_with(".svg"),          # <- :97
			"the chevron must be an SVG texture, not %s" % back.icon.resource_path)
	assert_eq(back.icon_alignment, HORIZONTAL_ALIGNMENT_LEFT,
		"the chevron leads the word; centred, the text would draw over it")
	s.free()
```

The new asset is a **PNG**, so `:97` fails. **Rewrite the assertion. Do not
convert the PNG to SVG to dodge it** — the format is incidental to the test's
real point, which its own doc comment states: the glyph must be a *texture*,
not a Boohong character.

The replacement, renamed so the name stops asserting a format:

```gdscript
## Boohong, the face every button label wears, has no single guillemet: its
## cmap sends "‹" (and "›", "‚") to its apostrophe glyph and "«"/"»" to its
## double quote. "‹ Kembali" therefore shipped as "' KEMBALI", on desktop and
## Android alike (2026-09-15). The arrow is a texture beside the word, never a
## character. The format is not the point -- it was an .svg chevron until
## 2026-09-21 and is now the shared return_button.png -- so this pins that it
## is a real asset, not which extension it wears.
func test_back_button_draws_its_arrow_as_a_texture_icon() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var back := s.get_node("MainColumn/Header/HeaderCol/Row/BackButton") as Button
	assert_not_null(back.icon, "the back arrow must be a texture on the button")
	if back.icon != null:
		assert_true(back.icon.resource_path.begins_with("res://Assets/Images/"),
			"the arrow must be a real asset, not %s" % back.icon.resource_path)
	assert_eq(back.icon_alignment, HORIZONTAL_ALIGNMENT_LEFT,
		"the arrow leads the word; centred, the text would draw over it")
	s.free()
```

The exact-path assertion deliberately lives in the new cross-screen suite
(§10.4) instead, so there is one place to edit if the asset ever moves.

`tests/test_inventory.gd:105-124`'s
`test_back_button_text_draws_no_character_as_a_quote_mark` resolves the
variation's font from the bake and walks `back.text` glyph by glyph.
`"Kembali"` is unchanged, so it stays green.

### 10.2 New test — Inventory's header structure (§6.1)

Add to `tests/test_inventory.gd`. The relationship is now measured, not
inferred, so the test pins the measured truth:

```gdscript
## Measured live 2026-09-21: HeaderCol is two rows, not one. Row (back
## button, spacer, coin pill) is 1024x96 at y 0 with BackButton 277 wide at
## x 0 and CoinPill 79 wide at x 945 -- 668px of free space between them --
## and TitleLabel is a separate row at y 114. So the header's minimum width
## is max(Row, TitleLabel), NOT the sum DEBT.md measured on 2026-09-15
## before 431cc5d split them, which is why the back arrow could grow the row
## by 32px and cost the header nothing. If a later change puts the title back
## in the row, the widths start summing again and this goes red before the
## screen clips.
func test_the_header_title_sits_on_its_own_row() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var col := s.get_node("MainColumn/Header/HeaderCol") as Control
	var row := col.get_node("Row") as Control
	var title := col.get_node("TitleLabel") as Control
	assert_true(title.get_parent() == col,
		"TitleLabel must be HeaderCol's own child, not a Row sibling")
	assert_true(row.get_combined_minimum_size().x <= title.get_combined_minimum_size().x,
		"the back/coin row (%d px) must stay narrower than the title (%d px)"
			% [int(row.get_combined_minimum_size().x),
				int(title.get_combined_minimum_size().x)])
	s.free()


## The back button and the coin pill share Row from opposite ends
## (SHRINK_BEGIN / SHRINK_END). Measured 2026-09-21 they leave 668px between
## them; the 36px arrow spends about 32 of it. This is the margin that makes
## Inventory safe to swap, so it is worth a number rather than a shrug.
func test_the_back_button_and_the_coin_pill_do_not_meet() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var row := s.get_node("MainColumn/Header/HeaderCol/Row") as Control
	var back := row.get_node("BackButton") as Control
	var pill := row.get_node("CoinPill") as Control
	var gap: float = row.get_combined_minimum_size().x \
		- back.get_combined_minimum_size().x \
		- pill.get_combined_minimum_size().x
	assert_true(gap >= 0.0,
		"the header row's fixed ends overlap by %d px" % int(-gap))
	s.free()
```

Both are ordinary synchronous tests — no `await`, and each frees its scene.

### 10.3 Suites that stay green — verified, listed so nobody re-derives them

| Suite : line | What it asserts | Why it survives |
|---|---|---|
| `test_achievement_screen.gd:52-55` | `Safe/UI/BackButton` is a `TextureButton` with `anchor_top == 1.0` | type and anchors unchanged |
| `test_atur_jadwal.gd:111-131` | `BackButton` and `PopupBack` ≥ 96 px | rects untouched (§5.2) |
| `test_atur_jadwal.gd:193-197` | `PopupBack` exists and `is BaseButton` | unchanged |
| `test_atur_jadwal.gd:533-541` | `PopupBack.offset_left == 329`, `offset_top == 1170` | frozen (§5.2) |
| `test_atur_jadwal.gd:641-650` | the `Peringatan` block drops id `3_a6kja` | different node, different pngwing file |
| `test_atur_jadwal.gd:97` / `test_settings.gd:97` | no `theme_override_*` in the scene | we add none — the cap is a variation constant |
| `test_koperasi_back_follows_tray.gd:106,122-129` | `koprasi.tscn` text carries `type="TextureButton"`; offsets equal `back_pos_expanded` | type and rect unchanged (§5.3) |
| `test_koperasi_shop_layout.gd:85` | `"BackButton"` in the Stage roster | unchanged |
| `test_report_card.gd:68-74` | a `BaseButton` named `BackButton` exists | type and node name unchanged; asserts nothing about `text` or width, so §6.2 is safe |
| `test_settings.gd:90-94` | `BackButton` exists and `pressed` has a connection | signal wiring untouched |
| `test_shop_hub.gd:143-150` | `CosmeticShop.tscn` has a `BackButton` | unchanged |
| `test_school_day.gd:229-234` | `DayScreen/BackButton` ≥ 96 px | 36 px cap keeps height at 96 |
| `test_run_result.gd` | the RunResult **row template** only | nothing pins `BtnSelesai` |
| `test_theme_factory.gd:328-348,441-452` | `DISPLAY_ROSTER` fonts + strays | constants only, no new type (§4.4) |
| `test_viewport_editability.gd` | BASELINE / ALLOWED | no runtime construction added or removed; all twelve are `.tscn` nodes already |
| `test_light_ground_text.gd:203-206` | Inventory's **filter-tab** icon contrast | a different node; the back button is not contrast-tested anywhere |

**The one assertion that must change** is
`tests/test_tall_screen_layout.gd:508-509`'s `%PilihMurid` position,
`Vector2(160, 82)` → `Vector2(202, 82)`, for the title nudge in §6.2. Nothing
else in that suite moves.

`test_theme_rebake` and `test_script_documentation` both run against the
`ThemeFactory` change and must be re-run — the second because the new block
carries comments.

### 10.4 New suite — `tests/test_back_controls.gd`

The point of this branch is that there is **one** back picture. Nothing in the
tree asserts that today, and without it the fourth divergent asset will arrive
the same way the first three did. One suite, cross-screen, pinning the
invariant rather than any one screen's geometry.

`@tool`, extends `McpTestSuite`, **no `await` anywhere** — the runner calls
each test without awaiting, and a coroutine silently aborts and reports zero
assertions. Every instantiated scene is `free()`d in the same test.

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

## The one canonical back/return glyph. Twelve controls across nine scenes
## draw it; before 2026-09-21 they drew four different pictures between them
## (a 160x145 white arrow, the same arrow at 512x512 with a different alpha
## bbox, a 16x36 chevron, and a pure-#FF0000 stock clipart arrow) plus one
## emoji. This suite is what stops a fifth arriving.
const CANON := "res://Assets/Images/UI/Nav/return_button.png"

## Retired 2026-09-21. No scene may reference any of these again.
const SUPERSEDED := [
	"res://Assets/Images/Achievements/back_arrow.png",
	"res://Assets/Images/Shop/return.png",
	"res://Assets/Images/UI/Placeholders/icon_back.svg",
	"res://Assets/Images/UI/pngwing.com (1).png",
]

## scene -> { node path : property }. texture_normal for the five
## TextureButtons, icon for the six Buttons -- five of which keep their
## "Kembali" label beside it, while Rapor's 260px box takes the arrow alone.
const ROSTER := { ... }   # all twelve rows from §5
```

Five tests:

1. **`test_every_back_control_draws_the_canonical_texture`** — walk `ROSTER`,
   instantiate each scene, read the named property, assert its
   `resource_path == CANON`. Report the offender's path in the message.
2. **`test_no_scene_still_references_a_superseded_back_asset`** — a source-text
   scan (`FileAccess.get_file_as_string`) of the nine `.tscn` files for each
   `SUPERSEDED` path. Catches a leftover `ext_resource` that no node uses,
   which test 1 cannot see.
3. **`test_the_texture_buttons_ignore_their_texture_size`** — for each
   `TextureButton` in `ROSTER`, `assert_true(btn.ignore_texture_size)`. A
   512×512 source without it sets a 512 px minimum size and silently destroys
   the layout (§5.4).
4. **`test_the_icon_cap_keeps_each_step_at_its_authored_height`** — load the
   baked theme with `ResourceLoader.CACHE_MODE_IGNORE` (the pattern
   `test_inventory.gd:108` already uses) and assert
   `get_constant("icon_max_width", "PrimaryButton") == 36`, same for
   `SecondaryButton`, and `== 48` for `PrimaryButtonM`; plus
   `h_separation == 16` on all three. Message explains the arithmetic
   (`2*btn_pad_v_s + font_title = 96`) so a future editor knows why 36 and not
   40.
5. **`test_no_back_control_labels_itself_with_an_emoji`** — for each `Button`
   in `ROSTER`, walk `text` and assert no codepoint falls in the emoji or
   dingbat blocks (`0x2190-0x2BFF`, `0xFE00-0xFE0F`, `0x1F000-0x1FAFF`).
   Pins the `CLAUDE.md` ban at the place it was most recently broken.

**Instantiation note.** All nine scenes are already instantiated by an existing
suite (`test_inventory`, `test_report_card`, `test_settings`, `test_school_day`,
`test_atur_jadwal`, `test_koperasi_shop_layout`, `test_shop_hub`,
`test_achievement_screen`), so none is known to hang. If any one turns out to be
expensive, downgrade **that row only** to the source-text form of test 2 — do
not drop the row.

### 10.5 Suites to re-run (targeted, never a full run mid-task)

```
test_inventory            test_achievement_screen    test_achievement_detail_sheet
test_atur_jadwal          test_koperasi_back_follows_tray
test_koperasi_shop_layout test_shop_hub              test_report_card
test_settings             test_school_day            test_run_result
test_tall_screen_layout   test_theme_factory         test_theme_rebake
test_script_documentation test_back_controls (new)
```

Per `CLAUDE.md`: a full `test_run` drops the bridge and costs an editor
restart. Take one at the milestone, not between tasks — and check `git status`
afterwards, because a full run rebakes `kejartes_theme.tres` and `AudioDirector`
rewrites `default_bus_layout.tres`.

---

## 11. Tall phones

`CLAUDE.md`'s third rule: every screen fills any phone, and
`tests/test_tall_screen_layout.gd` pins it.

**Exactly one rect changes, and it moves inward, away from every edge.**
Specifically:

- `:258-260` pins Koperasi's `Stage/BackButton` at `Rect2(24, 1157, 185, 185)`
  — texture swap only, rect untouched. ✅
- `:220-223` lists `"BackButton"` in the Koperasi Stage children roster — the
  node stays. ✅
- `:471` `_assert_under_safe_area(rapor.get_node_or_null("%BackButton"))` — §6.2
  shrinks `offset_right` 302 → 138 and leaves `offset_left`/`offset_top` alone,
  so the button moves *further* inside the safe area. ✅
- `:510-511` `assert_eq(..., Vector2(90, 82))` for `%BackButton` — pins
  position, which does not move. ✅
- `:508-509` `assert_eq(..., Vector2(160, 82))` for `%PilihMurid` — **changes to
  `Vector2(202, 82)`** (§6.2). The title moves 42 px right and its
  `offset_right` stays 1012, so it moves away from the left edge and no closer
  to the right one. ⚠️ the one edit.
- The other five text buttons whose *content* grows are either fixed-rect
  (ShopHub, CosmeticShop) or container-stretched (Settings, RunResult,
  SchoolDay fill their parent's width), so none grows toward an edge.
  Inventory is `SHRINK_BEGIN` inside a row with 668 px of measured free space
  (§6.1), so it grows into slack.

**One cross-spec note, now closed.** The other spec's work on SchoolDay's
bottom inset (the 2400-tall case shrinking 144 → 115.2 px, which would have
moved `DayScreen/BackButton` toward the Android gesture bar) was resolved by
keeping `offset_bottom` at `-144.0`. So the icon added here gains no
gesture-bar exposure. Nothing further needed — but if that decision is reopened,
this button is one of the nodes affected.

---

## 12. State, and Kelas 7 / 8 / 9

**Tidak berbeda per kelas.** Stated explicitly rather than omitted.

This change writes two node properties and one string. It reads nothing from
`GameState` — not `current_grade`, not `minggu_ke`, not `approved_students` —
and nothing it touches is grade-scaled. The same arrow, at the same size, on
the same twelve controls, in Kelas 7, 8 and 9.

It follows that the `approved_students` ↔ `StudentData` naming trap
(`akademis2` = seni_budaya, `kepribadian1` = mood) does not apply, and that
nothing new reaches disk: the only persisted state is `GameState.inventory` and
achievement progress, neither of which this touches.

`Scenes/SchoolSimulation/SchoolDay.tscn`'s `BackButton` is authored
`visible = false` and shown by `SchoolDay.gd:1337` at week's end
(`:216` and `:1526` hide it). That visibility logic is untouched, and it is the
other spec's half of that file in any case (§0).

---

## 13. Diagram — one text `Button`, before and after

`Scenes/Koperasi/ShopHub.tscn:60`, `BackButton`, `SecondaryButton`. Fixed
anchored box, **480 × 96**. Content margins 44 px horizontal / 30 px vertical
(`ThemeFactory.gd:828-831`: `space_lg` = 44, `btn_pad_v_s` = 30). "Kembali" in
Boohong at `font_title` 36 measures ≈ 170 px.

**BEFORE** — content 170 px, centred in 480:

```
  x=0                                                               x=480
   ┌───────────────────────────────────────────────────────────────┐  y=0
   │                                                               │
   │ ←44 pad→                                             ←44 pad→ │
   │                     ┌─────────────────┐                       │  y=30
   │                     │    Kembali      │ 36px cap height       │
   │                     └─────────────────┘                       │  y=66
   │                     ↑       170       ↑                       │
   │                   x=155             x=325                     │
   └───────────────────────────────────────────────────────────────┘  y=96
                          ( 480 - 170 ) / 2 = 155
```

**AFTER** — icon 36 + gap 16 + label 170 = **222 px**, centred in the same 480:

```
  x=0                                                               x=480
   ┌───────────────────────────────────────────────────────────────┐  y=0
   │                                                               │
   │ ←44 pad→                                             ←44 pad→ │
   │              ┌────┐ 16  ┌─────────────────┐                   │  y=30
   │              │ ◀─ │◄───►│    Kembali      │ 36px cap height   │
   │              └────┘     └─────────────────┘                   │  y=66
   │              ↑ 36 ↑     ↑       170       ↑                   │
   │           x=129 x=165  x=181           x=351                  │
   └───────────────────────────────────────────────────────────────┘  y=96
                          ( 480 - 222 ) / 2 = 129
     icon_max_width = 36   h_separation = 16   icon_alignment = LEFT (0)
     button height unchanged: 30 + max(36 icon, 36 text) + 30 = 96
```

The icon box is 36 × 36 (the source canvas is square); the **drawn** arrow
inside it is 35.0 × 31.2, because the art's alpha bbox is 498 × 444 within a
512 × 512 canvas (§4.6).

`custom_minimum_size` is `(0, 96)` and the content minimum is now
`44 + 222 + 44 = 310` — still 170 px inside the authored 480, so the box does
not grow and nothing beside it moves.

---

## 14. Order of work

`CLAUDE.md` rules 4 and 4b decide this, and getting it wrong silently eats
work.

1. **Asset in.** Drop `return_button.png` at `Assets/Images/UI/Nav/`, then
   `filesystem_manage(op="scan")`. Verify the generated `.import` `[params]`
   against `icon_chevron_left.png.import` (§3.2).
2. **Scene work, all of it, through the editor** (`scene_open` →
   `node_set_property` → `scene_save`). Nine scenes, twelve controls (§5).
   Never hand-edit a `.tscn` while the editor is attached.
3. **`git diff HEAD -- '*.gd'`** — a `scene_save` flushes every open script
   tab over whatever is on disk. Check for files you were not editing.
4. **Script work:** patch `Scripts/Design/ThemeFactory.gd` (§4.2) via
   `script_patch`. Normalise to LF first if needed.
5. **Restart the editor.** Required after a script patch, before the next save
   or bake.
6. **Rebake** `Scripts/Design/BakeTheme.gd` via File > Run, **alone** — not
   beside any scene op. `git diff Assets/Theme/kejartes_theme.tres` and confirm
   only the six expected lines plus renumbered stylebox ids.
7. **Tests:** rewrite `test_inventory.gd:92-101` (§10.1), add its two header
   tests (§10.2), move `test_tall_screen_layout.gd:508-509` to
   `Vector2(202, 82)` (§6.2), write `tests/test_back_controls.gd` (§10.4).
   Targeted `test_run` per suite (§10.5).
8. **Delete the four superseded assets and their `.import`s**, in one commit,
   only once step 2 has landed (§8).
9. **`DEBT.md` edits** — the seven-row table in §8: five deletions
   (`:35`, `:248-249`, `:430-441`, `:436`'s clause, `:445-449`), two
   corrections (`:25-27`, `:244`), plus the grouped emoji entry written out in
   §7 and the pngwing licensing line.
10. **Screenshots, full size**, of Koperasi and AturJadwal — the two photo
    backgrounds. Not to re-litigate the asset (§2), but because sites 4 and 5
    change the drawn arrow's aspect by ~17% and nobody has seen that yet.

---

## 15. Open questions

**None.** Every question this spec raised has been answered:

- **Inventory** — measured live: 668 px of free space, ~543 px even at
  999999G. Swaps at the same 36 px cap as everything else, and
  `DEBT.md:430-441` is deleted (§6.1).
- **ReportCard** — the user decided icon-only. The two-part geometry takes the
  `PilihMurid` overlap 190 px → 0, and `DEBT.md:445-449` is deleted (§6.2).
- **Emoji bookkeeping** — this spec owns all of it (§0, §7).

One thing to **look at** at task time, which is a judgement rather than a
question: the drawn arrow's aspect at sites 4 and 5. The 512×512 source has a
498×444 alpha bbox against `return.png`'s 512×379, so the arrow renders ~17%
taller and ~3% narrower in the same box. Cosmetic, not a layout change, but
nobody has seen it — hence the full-size screenshots in §14 step 10.
