# Skin system — design

2026-09-18 · branch `feat/skin-system` · mockups `skinselect_mockup.png`,
`skinselectoption_mockup.png` (Drive folder `189_EO_tboNQZAjIH9DaNjqaLFtEA7MrP`)

## What the player gets

Each student can wear an optional skin. A new **skin_switch** button in the
Lobby opens a popup (background blurred) showing the approved roster (up to
four) as tall rounded-rect cards of their current splash, names underneath,
and a **SETUJU** button. Tapping a card opens a scrollable column over that
card listing every skin of that student as square bust-ups; the rest of the
popup blurs. Locked skins are darkened and cannot be picked. Picking an
unlocked skin equips it at once: the card, and every screen that shows the
student, switches to the new art. The end-of-grade result screens
(`WinStage`, `WinLineup`, `RunResult`) keep their own art — a skin-aware end
result is a separate upcoming feature.

## Art

Delivered in `kosmetik.zip`, one `Skin1` per student (Andi, Citra, Doni,
Marcel, Shinta, Thea). Every file is a drop-in replacement at the same size as
the art it replaces:

| Delivered | Size | Replaces | Imported to |
|---|---|---|---|
| `<Name>_Skin1.png` | 1080×1920 | `SplashArtMurid/splash_<name>.png` | `Assets/Images/Skins/<Name>/splash_<name>_skin1.png` |
| `table/<name>_base_skin1.png` | 1280×1280 | face-rig `Base` layer `MuridPotrait/<Name>/<name>_base.png` | `Assets/Images/Skins/<Name>/<name>_base_skin1.png` |
| `table/<name>_table_skin1.png` | e.g. 518×239 | desk hands `MuridPotrait/TanganItems/<Name>_Table.png` | `Assets/Images/Skins/<Name>/<name>_table_skin1.png` |
| — (baked) | 1280×1280 | flat portrait `MuridPotrait/<Name>.png` | `Assets/Images/Skins/<Name>/<name>_portrait_skin1.png` |

No flat portrait was delivered. The flat portrait is the face rig flattened
(base + eyes at rest), so it is **baked once** by rendering the student's
face-rig scene with the Skin1 base into a 1280×1280 SubViewport and saving the
PNG; the PNGs are committed. The bake is a one-off step, not runtime code.

`<Name>Skin1(itemonly).png` (clothes only) is not used here — it reads as a
future Cosmetic Shop icon. The `skin_switch.png` icon (540×540) goes to
`Assets/Images/UI/skin_switch.png`.

## Logic

**Catalog — `Scripts/Skins/StudentSkins.gd`** (`class_name StudentSkins`,
static, no autoload). `const CATALOG: Dictionary` keyed by student name, each a
list of skin entries in display order. Entry 0 is always `"default"` and points
at today's assets; `"skin1"` points at the imported set:

```
{ "id": "skin1", "title": "Skin 1", "unlocked_by_default": true,
  "splash": ..., "portrait": ..., "face_base": ..., "hand": ...,
  "bust_center": Vector2(x, y) }   # head centre in splash px, for cropping
```

Static API (pure; state is passed in or read from `GameState`):

- `skins_for(name) -> Array` — the entries, `[]` for an unknown name.
- `entry(name, id) -> Dictionary` — `{}` when missing.
- `splash_for(student: Dictionary) -> String`, `portrait_for(student) -> String`
  — the equipped skin's path, falling back to the dict's own `"splash"` /
  `"portrait"` for `default`, an unknown name, or a missing entry.
- `face_base_for(name) -> String`, `hand_for(name) -> String` — equipped
  skin's layer, or `""` meaning "keep the scene's own texture".

**State — `GameState`** (session-scoped, like the roster; not saved — CLAUDE.md
forbids new persistence without being asked):

- `var equipped_skins: Dictionary = {}` — student name → skin id; absent =
  `"default"`.
- `var skin_unlock_overrides: Dictionary = {}` — `"Name:id"` → bool; absent =
  the catalog's `unlocked_by_default`. Only the debug overlay writes it.
- `signal skin_changed(student_name: String)`.
- `equipped_skin(name) -> String`, `is_skin_unlocked(name, id) -> bool`,
  `equip_skin(name, id) -> bool` (false and no change when the skin is locked
  or unknown; emits `skin_changed` on success).
- `forget_session()` clears both dictionaries.

Keyed by **name**, not roster `id`: ids are per-roster, names are the stable
identity of the six characters, and a skin should follow the character across
grades.

### The bridge

`approved_students` dicts keep their base `"splash"` / `"portrait"` keys
untouched — the equipped skin is looked up, never written into the dict, so
the end-result screens and anything that wants the base art still have it.
Across the bridge, `GameState.student_data_from_dict()` sets
`StudentData.splash_path = StudentSkins.splash_for(dict)` and
`avatar_texture = load(StudentSkins.portrait_for(dict))`. Nothing on the
`StudentData` side (`akademis`, `mood` = `kepribadian1`, `energy` =
`kepribadian2`, …) changes, and no new `StudentData` field is added.

### Where the skin shows

Every reader that turns a student into a picture goes through the resolver:

| Site | Art | Change |
|---|---|---|
| `GameState.student_data_from_dict` | splash, portrait | resolver (feeds DaySummaryAvatar, EventDialogue, StatCheckCard) |
| `loby.gd` roster seats | portrait fallback, face-rig `Base`, desk hands | resolver; `StudentFace.set_base_texture()`; hand node texture |
| `atur_jadwal.gd` student button (`:630`) | splash / portrait | resolver |
| `StudentCardView.gd` (`:74`) | portrait | resolver |
| `student_list.gd` (`:263`, `:382`) | portrait | resolver |
| `WinStage` / `WinLineup` / `RunResult` | own win art | **unchanged** |

`StatCheckCard` is part of the end-of-grade sequence but reads
`avatar_texture`, so it follows the skin; only the result screens are
excluded.

The Lobby re-applies its seats (face base + hands) when the popup closes, so
the diorama shows the new skin without leaving the screen.

## UI

All static chrome is in `.tscn`; repeated rows are PackedScene templates; no
`theme_override_*` — new ThemeFactory variations instead.

- **`Scenes/Skins/SkinFrame.tscn`** (`SkinFrame.gd`, `@tool`) — the masked
  art piece reused twice: a `Panel` (`SkinFrameMask`, rounded white fill) with
  `clip_children = CLIP_CHILDREN_ONLY` holding a `TextureRect` `Art`, and a
  `Panel` `Border` (`SkinFrameBorder`, brown outline) on top. `show_art(tex,
  bust_center)` scales and offsets `Art` so the source window of
  `@export var visible_source_height` px, with `bust_center` placed at
  `@export var face_y_ratio` of the frame's height, covers the frame. Layout
  only; no nodes created.
- **`Scenes/Skins/SkinSlot.tscn`** — a `Button` (flat) with a tall `SkinFrame`
  and a name `Label` (`H2Label`-sized display face). Emits `pressed`.
- **`Scenes/Skins/SkinOptionTile.tscn`** — a square `SkinFrame` in a `Button`;
  `set_locked(bool)` sets `modulate` to `@export var locked_tint` (dark) and
  disables the button.
- **`Scenes/Skins/SkinSelectPopup.tscn`** (`SkinSelectPopup.gd`, `@tool`):

```
SkinSelectPopup (Control, full rect)
├─ Blur            ColorRect, shop_hub_blur_material (blurs the Lobby)
└─ Safe (SafeAreaMargin) → UI
   ├─ Card         Panel "Card", centred, ~980×885 (mockup 51,459 → 1029,1343)
   │  ├─ Slots     HBoxContainer: SkinSlot ×4 (hidden past the roster size)
   │  └─ Setuju    Button "SETUJU", PrimaryButton
   └─ OptionLayer  Control, full rect, hidden
      ├─ BackBufferCopy (viewport)   fresh screen copy for the second blur
      ├─ Blur2     ColorRect, same material; tap = close the column
      └─ Column    Panel "SkinOptionColumn" (white, brown outline), x = tapped slot
         └─ Scroll ScrollContainer (vertical) → List VBoxContainer → SkinOptionTile…
```

  The option tiles are per-call dynamic content (one per catalog entry of the
  tapped student): instanced from the `SkinOptionTile` template into `List`,
  recorded in the viewport-editability `ALLOWED` list with a comment.

**Flow.** Lobby `SkinSwitchButton` → `Transition`-free overlay: instance the
popup over the Lobby (same pattern as the Achievements claim popup), fill the
slots from `approved_students` in roster order. Tap slot *i* → `OptionLayer`
shows, `Column` moves to slot *i*'s x, tiles listed and scrolled so the
equipped one is visible. Tap an unlocked tile → `GameState.equip_skin()`,
slot *i* redraws, column closes. Tap a locked tile → `Juice.shake`, nothing
else. Tap the blurred area → column closes. **SETUJU** (or Android back) →
popup closes, emits `closed`, frees itself; the Lobby re-applies seats.

**Lobby button.** `Safe/UI/BottomBar/SkinSwitchButton`, a `TextureButton`
96×96 at `offset_left = 360` beside `AchievementButton` (the row is DailyLogin
0, Settings 120, Achievements 240), `skin_switch.png`, `stretch_mode = 5`.
Disabled while the roster is empty.

**New ThemeFactory variations:** `SkinFrameMask` (Panel, white fill, radius
≈ 90 for tall / scales with height), `SkinFrameBorder` (Panel, no fill, 10 px
brown border, same radius), `SkinOptionColumn` (Panel, white fill, 10 px brown
border, radius ≈ 60). The popup card reuses `Card`; the name label reuses an
existing display-face variation. Colours come from existing tokens (the
mockup brown is the primary button's brown). Rebake.

## Kelas 7 / 8 / 9

No difference. Skins are cosmetic and keyed by name, so an equipped skin
carries across grades within the session; `reset_roster_for_new_grade()`
does not touch `equipped_skins`.

## Debug

DebugManager › General: **🎨 Kunci/Buka Semua Skin** toggles every non-default
skin's override between locked and unlocked, so the darkened state can be seen
while every shipped skin is unlocked by default.

## Testing

- `tests/test_student_skins.gd` (`suite_name() = "student_skins"`): every
  catalog path exists; entry 0 is `default` and matches today's assets; each
  of the six has `skin1`; resolver fallbacks (unknown name, default, missing
  key); `equip_skin` refuses locked/unknown and emits `skin_changed` on
  success; `forget_session` clears; `student_data_from_dict` uses the skin;
  the base dict keys are never mutated.
- `tests/test_skin_select_popup.gd` (`"skin_select_popup"`): scene structure
  (Blur material, four slots, `Setuju` is `PrimaryButton`, OptionLayer has a
  BackBufferCopy before `Blur2`), `open()` hides slots past the roster, slot
  press shows the column with one tile per skin, a locked tile is darkened and
  disabled, picking a tile equips and closes the column.
- `tests/test_skin_frame.gd` (`"skin_frame"`): `show_art` geometry covers the
  frame and places `bust_center` at `face_y_ratio`.
- Lobby: `SkinSwitchButton` exists with the icon, the seats pick up
  `face_base_for` / `hand_for` (source scan + behaviour where instantiable).
- Source scans: each consumer in the table above calls `StudentSkins`;
  `WinStage.gd` / `WinLineup.gd` do not.
- Existing ratchets: script documentation, viewport editability (ALLOWED entry
  for the tile list), tall-screen layout for the popup.

## Not doing

- Persistence of equipped skins (session-scoped; ask to add).
- Buying/unlocking skins in the Cosmetic Shop (stub stays a stub).
- Skins on the end-result screens.
- The rejected approach: writing the equipped skin's paths into the
  `approved_students` dict. It is fewer call-site edits, but it destroys the
  base art the end result needs and would have to be undone on every
  unequip and grade reset.
