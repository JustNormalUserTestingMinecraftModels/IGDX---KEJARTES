# Sprite rigs, dialog restyle, day-cycle phases and the shop hub

**Date:** 2026-09-07
**Branch:** `Textures`
**Status:** approved, ready for planning

Five independent changes, grouped because they land together and share one
source of new art. Each is self-contained; they can be implemented and
verified in any order.

| # | Area | New art | Touches |
|---|---|---|---|
| 1 | Goalie two-state + breathing | `kiper_idle`, `kiper_jump` | `MainBola` |
| 2 | Layered dancer rig | `dance_body_*`, `dance_head` | `LombaMenari` |
| 3 | Event dialog restyle | 4 new SVG icons | `EventStudentSelectDialog` |
| 4 | Three-pose day cycle | — | `BookClockWidget`, `SchoolDay` |
| 5 | Shop hub | 2 new SVG icons | new scenes, `loby`, `koprasi` |

Source art is in the Windows `Downloads` folder, per this project's usual
asset drop. All eight sprites are 1280×1280 RGBA.

---

## 1. Goalie: two states with idle breathing

### Problem

`MainBola` carries four goalie textures (`KiperIdle`, `KiperLeft`,
`KiperRight`, `Fail`), all opaque `.jpg` — the keeper renders as a white
rectangle over the pitch. `goalie_fail_texture` is declared at
`MainBola.gd:13` and never read anywhere in the file: dead since it was
written.

### Design

Import `kiper_idle.png` and `kiper_jump.png` into
`Assets/Images/Textures/`. Both carry real alpha.

`MainBola.gd` export changes:

- **remove** `goalie_left_texture`, `goalie_right_texture`,
  `goalie_fail_texture`
- **repoint** `goalie_idle_texture` → `kiper_idle.png`
- **add** `goalie_jump_texture` → `kiper_jump.png`
- **add** `jump_faces_right: bool = true`
- **add** `center_block_uses_jump: bool = false`
- **add** `breath_scale_amount: float`, `breath_rate: float`

Dive direction becomes `goalie_gfx.flip_h` rather than a texture swap.
At `MainBola.gd:537-538`:

```gdscript
# was: goalie_gfx.texture = goalie_left_texture if dive_dir < 0 else goalie_right_texture
if dive_dir == 0 and not center_block_uses_jump:
    goalie_gfx.texture = goalie_idle_texture
    goalie_gfx.flip_h  = false
else:
    goalie_gfx.texture = goalie_jump_texture
    goalie_gfx.flip_h  = (dive_dir < 0) == jump_faces_right
```

**Assumption, deliberately made cheap to reverse:** `kiper_jump` reads as
a dive toward screen-right (head and gloves lead up-and-right, feet
trail lower-left). If it reads backwards in game, `jump_faces_right` is
a single Inspector toggle. Do not hardcode the direction.

A centre block holds the idle pose — the keeper does not move on
`dive_dir == 0`, so he should not be mid-air. `center_block_uses_jump`
exists for the opposite opinion.

Idle breathing follows the shape already proven at `LombaMenari.gd:247`:
a sine on `goalie_gfx.scale` driven from `_process`, suspended while
`is_resolving` is true, and rewound to `Vector2.ONE` when a shot starts.

**Pivot at bottom-centre**, not centre: `goalie_gfx.pivot_offset =
Vector2(size.x * 0.5, size.y)`. Scaling a standing character about its
middle lifts its feet off the goal line.

`_apply_layout` writes `goalie_gfx.size` on every resize, so
`pivot_offset` must be recomputed there (`MainBola.gd:329-332`), not
once in `_ready`.

Both sprites share a 1280×1280 canvas and the rect uses
`STRETCH_KEEP_ASPECT_CENTERED`, so the character's scale stays
consistent between poses for free. The jump sprite's content spans
almost the full canvas (alpha bbox 47→1258) against the idle's
338→942, so the keeper visibly expands into the dive. That is correct
and wanted.

Collision geometry is untouched: gameplay does not change.

---

## 2. Dancer: layered head and body rig

### Head placement, solved

The head offset was derived, not eyeballed. Compositing `dance_head`
over `dance_body_idle` at a candidate offset and minimising total
per-pixel difference against `dance_mockup` converges on:

**offset = (+2, +28) px on the 1280 canvas.**

Stored as a resolution-independent ratio so it survives any rect size:

```gdscript
@export var head_offset_ratio := Vector2(2.0 / 1280.0, 28.0 / 1280.0)
```

All three body poses place the neck within a few pixels of the same
spot (alpha bboxes: idle `y 340`, side `y 329`, up `y 329`; necks
visually coincident), so one offset serves every pose. If a future pose
disagrees, the ratio is per-rig, not per-pose — revisit then, not now.

### Design

New `Scenes/Minigames/SeniBudaya/DancerRig.tscn` with
`Scripts/Minigames/SeniBudaya/DancerRig.gd` (`@tool`, so the composite
previews in the editor viewport):

```
DancerRig (Control)
├── Body (TextureRect)   swaps texture, flips
└── Head (TextureRect)   constant texture, never flips
```

Both children draw into the same rect with
`STRETCH_KEEP_ASPECT_CENTERED`. Because the source images share one
canvas they align at zero offset; `head_offset_ratio` is then applied
against the *drawn* square size, which is `min(rect.x, rect.y)`, not
the rect itself.

Public API:

- `set_pose(pose: Pose, flipped: bool)` where `Pose = { IDLE, SIDE, UP }`
- `set_failed(on: bool)` — applies the miss tint
- textures as `@export`s so the art swap stays an Inspector change

Direction mapping stays in `LombaMenari.gd`, which already owns the
swipe-type constants:

| Swipe | Pose | `flipped` |
|---|---|---|
| `RIGHT` | `SIDE` | false |
| `LEFT` | `SIDE` | **true** |
| `TOP_RIGHT` | `UP` | false |
| `TOP_LEFT` | `UP` | **true** |
| — | `IDLE` | false |

**The head never flips.** Decided explicitly: her face and hairclip stay
fixed while the body mirrors. The back hair lives in the body sprite and
is near enough symmetric that the mirrored silhouette still reads.

### Miss

No fail sprite exists in the new set. A miss is the **idle pose, tinted
red**, plus the shake-and-droop tween already written at
`_play_dancer_fail_motion` (scale 0.85, rotate −8°, hold 0.9s, recover).
`dancer_fail_texture` is removed.

### Node type change

`$CharacterDisplay` changes from `TextureRect` to a `DancerRig`
instance. A node's type cannot be changed in place — this is
delete-and-recreate through the editor (`node_manage`), never a
hand-edit of the `.tscn` while the editor is attached.

`LombaMenari.gd`'s `@onready var character_display: TextureRect` becomes
`DancerRig`, and every `character_display.texture = X` assignment becomes
a `set_pose` call.

### Ratchet

Removing the `_create_flat_texture` fallback and the `dancer_label`
carrying `"🕺 IDLE"` / `"💔 MISSED!"` clears both runtime visual
construction *and* emoji-as-iconography. `test_viewport_editability.gd`
`BASELINE` for `LombaMenari.gd` drops from **5**.

---

## 3. `EventStudentSelectDialog`: DaySummary chrome, preview kept

### Problem

Every student card is assembled at runtime in `_create_card()` out of
raw `HBoxContainer` / `VBoxContainer` / `CheckBox` / `Label` / `StatBar`
nodes — 11 entries in the editability `BASELINE`, the highest of any
file in the list. Eleven emoji do icon duty (📢 📈 📉 😴 🌟 📚 ⚽ 🎨 ⚡ 😊,
plus 🕺 in the sibling minigame). Selection is a stock Godot `CheckBox`
scaled 2.4×, which matches nothing else in the game.

### Design

New `Scenes/SchoolSimulation/EventStudentCard.tscn`, assembled from the
DaySummary components that already exist rather than from new ones:

```
EventStudentCard (Button, toggle_mode = true)
├── CardArt     TextureRect  ← Assets/Images/DaySummary/card_bg.png
├── Avatar      DaySummaryAvatar.tscn
├── EnergyBar   ProgressBar + DaySummaryNeedsBar.gd  (icon · word · chevron)
├── MoodBar     ditto
├── StatRow1..3 DaySummaryStatRow.tscn
└── SelectBadge TextureRect  ← new icon_check.svg, visible when pressed
```

The card root being a `toggle_mode` Button does three things at once: it
deletes the scaled `CheckBox`, it makes the whole 992×410 card the tap
target (a real gain on a 1080-wide portrait phone), and it lets the
selected state come from the button's own `pressed` stylebox instead of
a bespoke `self_modulate` tint.

New `ThemeFactory` variation `EventSelectCard` supplies `normal` and
`pressed` styleboxes. Adding it means a rebake
(`Scripts/Design/BakeTheme.gd`); if the editor is attached, drive it
through a transient `@tool` `McpTestSuite` rather than File > Run.

### The preview survives

`DaySummaryStatRow.set_stat(stat_key, delta, target, current)` already
computes and animates exactly the "current → previewed" travel this
dialog needs. Toggling a card calls it with the event's `stat_boost` on
the event's category row, and drives the two needs bars the same way.
The `45 ➔ 60 (+15)` readout stays.

Uninvolved stat rows show current values statically, which is the
"shows the current stat the student have" half of the request.

### Buttons

`SelectAllButton` / `CancelButton` / `ConfirmButton` keep
`SecondaryButton` / `DangerButton` / `PrimaryButton` — those genuinely
are the variations the rest of the game uses (`grep` across `Scenes/`:
Danger 13, Success 12, Primary 11, Secondary 9). What changes:

- the `button_select_all_texture` / `_cancel_` / `_confirm_` exports and
  their runtime `StyleBoxTexture` overrides are removed. That path is
  what lets these three drift out of theme.
- emoji leave the labels
- one shared 96px minimum height

### Icon replacements

Existing, reused: `icon_akademis.png`, `icon_olahraga.png`,
`icon_seni.png` (`Assets/Images/DaySummary/`), `stat_energy.png`,
`stat_mood.png` (`Assets/Images/StudentCard/`).

New, to author under `Assets/Images/UI/Placeholders/`: `icon_benefit`,
`icon_cost`, `icon_tired`, `icon_specialty`, `icon_check`.

**All new SVGs must draw glyphs as stroked paths, never `<text>`.**
Godot rasterises SVG through ThorVG, which silently drops text
elements. `tests/test_end_cutscene.gd` guards the same trap for the
end-cutscene stamps; the new icons need the same discipline.

### Ratchet

`BASELINE` for `EventStudentSelectDialog.gd` drops from **11**.

---

## 4. `BookClockWidget`: three poses, two transitions

### Problem

The sky sweeps continuously 0 → −180° across the day, and the event
fires at `randf_range(0.5, 0.8)` (`SchoolDay.gd:355`) — a random point
between midday and late afternoon. The requirement is a fixed rhythm:
dawn, one transition, midday *where the event happens*, one transition,
evening.

```
   DAWN ──transition 1──▶ MIDDAY ──transition 2──▶ EVENING
    0°                     −90°     │               −180°
                                    └─ event rolls here
```

### Design

Three named poses replace the single sweep, as exports on
`BookClockWidget.gd`:

```gdscript
@export var dawn_rotation_degrees:    float = 0.0
@export var midday_rotation_degrees:  float = -90.0
@export var evening_rotation_degrees: float = -180.0
```

These defaults reproduce today's geometry exactly: the existing
`start_rotation_degrees = 0.0` / `total_rotation_degrees = -180.0` put
midday at −90° already. Nothing moves on screen until the transition
timing changes.

New API:

- `enum Phase { DAWN, MIDDAY, EVENING }`
- `set_phase(phase)` — snaps, no tween
- `transition_to(phase) -> Tween` — animates, **returns the Tween** so
  `SchoolDay` can `await` it

`set_progress()` stays, remapped piecewise through the midday pose, so
every existing caller and test keeps working. `start_rotation_degrees`
and `total_rotation_degrees` are removed; the three pose exports
supersede them.

### `SchoolDay.gd`

```gdscript
## The school day's event always lands at midday -- the BookClock's
## middle pose -- rather than at a random point in the afternoon.
const EVENT_TRIGGER_PCT := 50.0
```

replaces `var trigger_pct = randf_range(0.5, 0.8) * 100.0` at line 355.
The existing two-phase structure at lines 353-395 already brackets
`_roll_event`; it stops being random and starts driving
`transition_to(MIDDAY)` then `transition_to(EVENING)`. The day progress
bar and the embedded decay bars keep their current pacing relationship
with the clock.

### Motion

Transition easing and duration are **not** guessed here. After the
mechanism lands, run the `motion-lab` skill against `transition_to` and
patch back the preset the user picks. That is the whole reason
`transition_to` returns its Tween rather than hiding it.

---

## 5. Shop hub

### Design

```
Lobby ──▶ ShopHub ──┬── "Makanan & Barang" ──▶ koprasi.tscn  (existing shop)
             ▲      └── "Kosmetik" ─────────▶ CosmeticShop.tscn
             └─ both back buttons return here, not to Lobby
```

New scenes under `Scenes/Koperasi/`:

- `ShopHub.tscn` + `Scripts/Koperasi/shop_hub.gd`
- `ShopHubTile.tscn` — the reusable icon+label tile
- `CosmeticShop.tscn` + `Scripts/Koperasi/cosmetic_shop.gd`

### Background

`mockup_shop.png`'s backdrop is a stock photo of a real minimarket and
is not in the repo; the actual Koperasi screen is a flat illustration.
The hub blurs **the real screen**, not the mockup's photo.

`Scripts/Shaders/blur.gdshader` already exists, is already used by
`koprasi.tscn`, is screen-space (`hint_screen_texture`) and already
carries both uniforms this needs:

```glsl
uniform float lod      : hint_range(0.0, 5.0) = 0.0;  // blur strength
uniform float darkness : hint_range(0.0, 1.0) = 0.3;  // dim, so white text reads
```

So the hub is an `Illustration4.jpg` TextureRect with a full-rect
shader'd ColorRect over it. **No new image asset, and nothing built at
runtime** — the material is assigned in the `.tscn`, which satisfies the
authoring rule.

### Tiles

Two `ShopHubTile` instances, mirroring the mockup's centred pair: a
white icon above a label, on a `Button` with a new `ShopHubTile` theme
variation.

Labels are **Indonesian** — "Makanan & Barang" and "Kosmetik" — per the
project convention, overriding the mockup's English.

New icons under `Assets/Images/Shop/UI/`: `icon_shop_items.svg`
(drink + burger) and `icon_shop_cosmetics.svg` (t-shirt), white,
transparent, **paths not `<text>`** (see §3).

### Cosmetic shop

Blurred background, a back button, and one centred "Segera Hadir"
caption. The request was "empty with a back button only"; a wholly blank
screen reads as a bug, so the caption is a deliberate small addition —
trivially removable if unwanted.

### Navigation edits

- `Scripts/Lobby/loby.gd:788` — `koprasi.tscn` → `ShopHub.tscn`
- `Scripts/Koperasi/koprasi.gd:102` — `loby.tscn` → `ShopHub.tscn`
- `DebugManager`'s Scenes tab gains a ShopHub teleport, so the hub is
  reachable without walking the lobby

---

## Testing

New suites:

- `tests/test_shop_hub.gd` — tiles exist, both routes resolve, labels
  are Indonesian, background carries the blur material
- `tests/test_dancer_rig.gd` — pose/flip mapping table above, head
  never flips, head offset ratio applied against the drawn square

Extended:

- `test_main_bola_layout.gd` — two textures not four, `flip_h` dive
  direction, breathing pivot at bottom-centre
- `test_day_summary.gd` — `EventStudentCard` reuses the DaySummary parts
- BookClock coverage — three poses, `transition_to` returns a Tween,
  `set_progress` still maps through midday
- `test_viewport_editability.gd` — `BASELINE` **lowered** for
  `MainBola.gd` (2), `LombaMenari.gd` (5) and
  `EventStudentSelectDialog.gd` (11). Lowered only, never raised.

Suites are `@tool`, extend `McpTestSuite`, and contain no `await` — the
runner calls tests without awaiting, and a coroutine aborts silently and
reports zero assertions.

Full `test_run` green before anything is pushed.

## Out of scope

- Cosmetic shop contents. The scene is a stub by request.
- Layered face rigs for the four non-Citra students (separate debt).
- `Balance.gd` — collaborator-owned, read-only.
- Goalie/dancer *gameplay* tuning. This is an art and presentation pass;
  dive distances, note timing and scoring are untouched.
