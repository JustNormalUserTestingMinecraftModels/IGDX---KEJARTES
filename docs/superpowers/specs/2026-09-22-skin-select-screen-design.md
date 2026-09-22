# SkinSelect: a full-screen skin picker — design

**Date:** 2026-09-22
**Branch:** `feat/achievements-layout-pass` (same batch as the achievements pass)
**Source:** `skinselection_mockup.png` (1080x1920, so its pixels are design-space
coordinates), plus the design audit run on it the same day.

Replaces `SkinSelectPopup` — a card of up to four roster students with a
second blurred layer for the skin column — with one full-screen surface: the
student's splash in a horizontal carousel of their skins, a rail of all six
characters underneath, and one commit button.

---

## 1. The one premise the code contradicts

The brief says "instead of a pop up it now blur the background and opened
this scene". A real `Transition.change_scene` cannot blur the Lobby: the live
pixels are gone by the time the new scene loads. The project's two answers to
that are visible side by side today — Achievements ships a *baked*
`bg_achievements_blur.jpg`, while `SkinSelectPopup` blurs the **live** screen
through `Scenes/Koperasi/shop_hub_blur_material.tres` on a full-rect
`ColorRect`.

So SkinSelect stays a **full-screen overlay instantiated by `loby.gd`**, not a
scene change. That keeps the blur showing the actual lobby — the student the
player is dressing is standing in it — which a baked image cannot do. What
changes is everything the brief actually describes: it stops looking like a
card popup and becomes the full-bleed layout in the mockup.

The name follows the brief: `SkinSelectPopup` is renamed `SkinSelect`
throughout.

---

## 2. Measured off the mockup

| Element | Rect (design px) |
|---|---|
| Title, centred caps with outline | y 94–175 |
| Tray panel, `surface_card` `#FFFDF8` | y 1337–1920, full width |
| Six squares | 150 x 150, y 1431–1581, x 35…1049, pitch ~173 |
| Back arrow | x 40–240, y ~1690–1845 |
| Commit button | 493 x 133, x 505–998, y 1710–1843 |
| Splash band left above the tray | 1080 x 1337 |

## 3. What the audit changed, and what it did not

Kept as drawn: the blurred backdrop, the outlined title, the six-square rail,
the peeking dimmed neighbour skin, the back arrow's corner, the commit
button's size and position.

Changed:

1. **The splash fits the band instead of filling the screen.** The art is
   full-body 1080x1920 and the visible band is 1080x1337, so the mockup loses
   the bottom 583px — shoes and skirt hem included, on the one screen whose
   job is showing an outfit. Scaled to 1337 tall the figure is **752 wide**,
   fully visible, with 328px left for the neighbour to peek into.
2. **The open student's square is marked.** Six identical squares with the
   name 1300px away at the top is not enough. The open one takes a distinct
   theme variation: `outline_card` `#FFF6E8` fill and a 6px `brand_primary`
   `#7A4A2B` ring. It does **not** grow — the audit's drawn version raised it
   to 170px, which thrashes the rail's layout on every switch for no
   legibility the ring does not already buy.
3. **Selected and equipped stop looking the same.** Every student has exactly
   two skins (`StudentSkins.SKINS`) and both are unlocked
   (`UNLOCKED_BY_DEFAULT`), so centring one and pressing the button changed
   nothing on screen. A skin-name label and a "SEDANG DIPAKAI" chip sit under
   the rail; the chip keys off the *committed* `GameState.equipped_skin`, so
   it vanishes the moment the carousel moves and returns when TERAPKAN lands.
   That is what makes the button's effect visible.
4. **"APPLY" becomes "TERAPKAN"** — all UI text is Indonesian (CLAUDE.md
   Conventions; the popup this replaces says SETUJU, Koperasi says BELI).
5. **The button is `PrimaryButton` brown, not `#D21919`.** That red is not in
   the palette and sits next to `state_danger` `#C0392B`, so a commit button
   drawn in it reads as a pair with the red back arrow 500px to its left.
6. **Two page dots under the carousel**, one per skin. With two skins the
   peeking neighbour carries it; with a third it would not, and dots cost
   nothing now.
7. **A locked skin has a state.** `GameState.is_skin_unlocked` exists and the
   debug overlay can lock every skin, and the mockup had nowhere to say so.
   A locked card gets the lock overlay and the chip area reads TERKUNCI.

---

## 4. Logic

### The two selections

```
_student_index   -> which of StudentSkins.NAMES the rail has open
_pending         -> Dictionary, student name -> skin id not yet committed
```

`_pending_id(name)` returns `_pending.get(name, GameState.equipped_skin(name))`,
so an untouched student always reads as whatever they are wearing.

- **Sliding the carousel** writes `_pending[name] = id`. Nothing is equipped.
- **Tapping a rail square** switches `_student_index`, rebuilds the carousel
  for that student and jumps it to their `_pending_id` without animating.
- **TERAPKAN** loops `_pending` and calls `GameState.equip_skin(name, id)` for
  each, then closes. `equip_skin` already returns false for a locked or
  unknown skin and no-ops when re-equipping the worn one, so the loop needs no
  guard of its own.
- **Back** (arrow, `ui_cancel`, or Android back) closes without applying.
  `_pending` dies with the node.

Accumulating `_pending` across students is what makes one commit button serve
six characters: dress everyone, press once.

### The carousel

A `Track` HBoxContainer of `SkinCard`s inside a clipping `Viewport`-less
`Control`, moved by `Track.position.x`. One card per id in
`StudentSkins.skins_for(name)`.

Drag handling mirrors `BasketTray`'s, rotated 90 degrees — the same
flick-speed-or-halfway rule, so the two gestures in the game feel the same:

```
FLICK_SPEED   = 600.0   px/s past which the flick decides on its own
COMMIT_RATIO  = 0.5     fraction of one card's pitch a slow drag must cross
```

On release the track tweens to `-index * pitch`, where
`pitch = card_width + separation`. `TRANS_CUBIC` / `EASE_OUT`, 0.28s — the
same shape as every other settle in the project.

Card appearance is a two-state swap, not a gradient:

| | selected | not selected |
|---|---|---|
| `modulate` | `Color.WHITE` | `unselected_modulate`, default `Color(0.55, 0.55, 0.62, 1.0)` |
| `material` | `null` | `skin_option_blur_material.tres` |

`Scenes/Skins/skin_option_blur_material.tres` already exists and is already
the blur the old option column used. Assigning a preloaded material is not
runtime visual construction — nothing is built, a reference is swapped.

### The six squares

`StudentSkins.NAMES` — all six characters, not `GameState.approved_students`.
`equipped_skins` is keyed by **name**, not roster id, precisely so a skin
follows a character across grades, so dressing a character who is not in this
run's roster is coherent: the skin is waiting when they are approved.

Each square shows the student's face cropped out of their *pending* splash,
through the existing `SkinFrame` (an opaque rounded `Mask` with
`clip_children` and a fill-less `Border` drawn on top). `SkinFrame.show_art`
takes a texture and `StudentSkins.bust_center(name)`, and
`visible_source_height` zooms it — 520 source pixels for a head-and-shoulders
crop in a 150px box.

No new `StudentSkins` API is needed. `layer_path(name, id, "splash")` is
already public and already returns the base splash for `"default"`, which is
exactly what both the carousel and the rail want.

---

## 5. State

Nothing crosses the `approved_students` ↔ `StudentData` bridge — this screen
never touches a student's stats.

- **`GameState.equipped_skins`** — `Dictionary`, student **name** → skin id.
  Absent means `StudentSkins.DEFAULT_ID`. Session-scoped, **not persisted**,
  and this pass does not change that. Written only through
  `GameState.equip_skin`, which emits `skin_changed(student_name)`.
- **`GameState.skin_unlock_overrides`** — `"Name:skin_id"` → bool, written
  only by the debug overlay's `set_all_skins_locked`. Read here through
  `GameState.is_skin_unlocked`.
- **The roster dicts** (`approved_students`, keys `akademis1/2/3`,
  `kepribadian1` = mood, `kepribadian2` = energy) are **not read by this
  screen at all** — that is the change from `SkinSelectPopup`, which took an
  `Array` of them in `open()`. `SkinSelect.open()` takes no argument.
- `loby.gd` reseats its students on `closed` so the diorama picks up the new
  `face_base_for` / `hand_for` layers; unchanged.

## 6. Kelas 7 / 8 / 9

Nothing here varies by grade. The six characters and their skin lists are the
same in every grade, `equipped_skins` is keyed by name so a skin survives the
grade change that clears the roster, and no skin is gated on
`GameState.current_grade`.

## 7. Files

**Renamed**
- `Scenes/Skins/SkinSelectPopup.tscn` → `Scenes/Skins/SkinSelect.tscn`
- `Scripts/Skins/SkinSelectPopup.gd` → `Scripts/Skins/SkinSelect.gd`
  (`class_name SkinSelectPopup` → `SkinSelect`)
- `tests/test_skin_select_popup.gd` → `tests/test_skin_select.gd`
  (`suite_name()` → `"skin_select"`)

**Added**
- `Scenes/Skins/SkinCard.tscn`, `Scripts/Skins/SkinCard.gd`
- `Scenes/Skins/StudentTile.tscn`, `Scripts/Skins/StudentTile.gd`

**Deleted** — both lose their only caller with the option column
- `Scenes/Skins/SkinSlot.tscn`, `Scripts/Skins/SkinSlot.gd`
- `Scenes/Skins/SkinOptionTile.tscn`, `Scripts/Skins/SkinOptionTile.gd`

**Changed**
- `Scripts/Lobby/loby.gd` — the preload path, and `_skin_popup_open` →
  `_skin_select_open`
- `Scripts/Design/ThemeFactory.gd` — five variations:
  `SkinStudentTile`, `SkinStudentTileActive`, `SkinNameLabel`,
  `SkinWornChip`, `SkinWornChipLabel`
- `tests/test_lobby_skins.gd` — the popup's class and node names

**Unchanged and reused**
- `Scenes/Skins/SkinFrame.tscn` / `Scripts/Skins/SkinFrame.gd` — the rail's
  face crop
- `Scenes/Skins/skin_option_blur_material.tres` — the unselected cards' blur
- `Scenes/Koperasi/shop_hub_blur_material.tres` — the backdrop blur
- `Scripts/Skins/StudentSkins.gd` — `layer_path` already does everything the
  new screen needs

## 8. Not doing

- Making it a real scene via `Transition.change_scene` (section 1).
- Growing the open rail square to 170px (section 3, item 2).
- Any change to how skins are earned. There is still no way to unlock one —
  `docs/superpowers/DEBT.md` already records that, and the Cosmetic Shop stub
  is its likely home.
- Persisting `equipped_skins`. CLAUDE.md: do not add persistence unasked.
