# Achievements layout pass, plus two small screen fixes — design

**Date:** 2026-09-22
**Branch:** `feat/achievements-layout-pass`
**Sources:** `achievement_mockup.png`, `achievementpopup_mockup.png`,
`notice_icon.png`, `koperasi fix.png` (all in the user's Downloads folder),
plus the design audit run on 2026-09-22 against the live build.

Five changes, four of them in the Achievements screen and its detail popup,
one each in AturJadwal and Koperasi. They share a branch because they came in
as one request, not because they share code.

---

## 0. What the audit measured

Read live off the running build (`game_eval` sampling
`get_viewport().get_texture().get_image()`), because these numbers drive
several decisions below:

| Measured | Value |
|---|---|
| Grid column widths | left **420**, right **478** (should be equal) |
| Locked tile title contrast | **1.78:1** (project floor 3.0, body copy 4.5) |
| Unlocked tile title contrast | **5.29:1** |
| Tile / icon area | 420x260 tile, 72x72 icon — icon is 3% of the tile |
| Tile title size | `CaptionLabel`, 22px, on an 18/22/28/36/48/64/96 scale |
| Entries carrying a prize | **6 of 26** — the other 20 render a chip reading "—" |
| Detail sheet card height | 922px at 1080x1920, **1152px at 1080x2400**, for ~350px of content |

---

## 1. Grid symmetry -- `AchievementTile.tscn`

### The cause (corrected 2026-09-22, during execution)

This section first blamed `GridContainer` for not splitting leftover width
evenly and proposed replacing it with an `HBoxContainer` of two
`VBoxContainer`s filled round-robin. Building both containers side by side at
the grid's real measurements disproved that: a `GridContainer` with two
equal-minimum expanding columns splits 922 evenly, exactly as a
`BoxContainer` does.

The live screen's column minimums are `[420, 478]` -- the container is
distributing correctly, it is being handed unequal minimums. Exactly one tile
of 26 is responsible:

```
5 streak_6 min=478.0 lbl_min=366.0 text=Poin stat murid dari minigame +5%
```

`Content/PrizeChip/PrizeLabel` has autowrap off, and a `Label` with autowrap
off reports its **whole text width** as its minimum size. 366px, plus the
chip's two `space_md` (28) content margins and the `Card` stylebox's own
margins, is 478. `streak_6` is catalogue index 5 -- odd, so column 1 -- and
five of the six entries that carry a prize sit at odd indices; only
`total_25`, whose prize string is far shorter, is even. A content bug wearing
a layout bug's clothes.

### The fix

The `GridContainer` stays. `PrizeLabel` gets `autowrap_mode = 1`
(`AUTOWRAP_ARBITRARY`), which frees its minimum width, plus
`max_lines_visible = 1` and `text_overrun_behavior = 3`
(`OVERRUN_TRIM_ELLIPSIS`) so the freed wrap cannot become a second line and
reflow the tile. Verified live: every tile's minimum then reads 420 and both
columns come out equal.

`achievements_screen.gd` is not touched at all -- no round-robin
distribution, no `_relayout_columns`, no `%Scroll` rename. Filtering keeps
working exactly as it does today, because `GridContainer` already reflows
around hidden children.

## 2. The tile — `AchievementTile.tscn`, `AchievementTile.gd`, `ThemeFactory.gd`

The mockup enlarges the icon, runs the prize chip full width, and puts a
notice badge on the corner. The audit adds the title size and the contrast
failure. All of it lands in one rebuild of the tile.

### Geometry (design px, 1080-wide space)

| Node | Was | Becomes |
|---|---|---|
| root `custom_minimum_size` | 420 x 260 | **420 x 310** |
| `Content/IconSlot` | 72 x 72 | **132 x 132** |
| `Content/Title` | `CaptionLabel` 22px, band 58 | **`AchievementTileTitleLabel` 28px, band 80** |
| `Content/PrizeChip` | shrink-centre | **`size_flags_horizontal = 3`** (full width) |
| `Content/ProgressBar` | 4 | **6** |
| corner badge | `BaruBadge` (66x26 pill) | **`NoticeBadge`, 72x72 TextureRect** |
| `CheckBadge` | 32 x 32 | **48 x 48**, same corner slot |

Budget check. `Content` is a `VBoxContainer` with one `separation`, so the
worst case (an entry that has a prize, and so shows all four children) is
132 + 80 + 38 + 6 = 256 of content plus three gaps. At the current
`separation` of 8 that is **280**, leaving 30 inside a 310 tile for the
`Card` variation's own top and bottom content margins. The chip-less case —
20 of the 26 entries — is 132 + 80 + 6 + two gaps = **234**, and
`alignment = 1` centres it.

The icon keeps `icon_outline_material.tres` unchanged at `outline_width =
0.03`; at 132px that traces a ~4px white frame on its own, which is the
frame the mockup draws. No shader or material edit.

### The title

New `ThemeFactory` variation `AchievementTileTitleLabel`:
`font_body_size` (28), `text_primary` (`#3B2412`), `font_body` (Open Sans).
28 is the scale's body step — the audit's "30" was a guess and the token is
better. Because this variation takes `font_body`, not `font_display`, it does
**not** join `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`.

### The locked state — the contrast fix

`locked_modulate` currently puts `Color(1,1,1,0.55)` on the tile **root**, so
the card, the title and the icon all blend into the painted background.
Measured 1.78:1 for the title, against a 3.0 floor. The `@export` is
repurposed:

```
## Tint applied to the ICON ONLY while the achievement is locked. It is
## deliberately not on the tile root: fading the root took the title to
## 1.78:1 against its own card, under the 3.0 floor
## tests/test_bar_contrast.gd pins.
@export var locked_icon_modulate: Color = Color(0.62, 0.62, 0.62, 1.0)
```

The tile root's `modulate` stays `Color.WHITE` in every state. Locked is
carried by the greyed icon, the lock overlay already drawn on it, and the
absence of a corner badge. Title contrast becomes 5.29:1 — the same as an
unlocked tile.

### The prize chip

`AchievementCatalog.ENTRIES` sets `prize` on six entries only
(`streak_6`, `total_15`, `total_25`, `total_50`, `money_8x`, `fast_12`).
`_apply_prize()` stops rendering a placeholder and instead sets
`prize_chip.visible = prize != ""`. The neutral (`AchievementPrizeChip` /
`AchievementPrizeChipLabel`) variations lose their only caller; they stay in
`ThemeFactory` as the non-amber pair the popup's chip can fall back to
(section 3), so nothing is deleted.

With the chip full width, `PrizeLabel` keeps `text_overrun_behavior = 3` and
no autowrap, so the longest string ("Poin stat murid dari minigame +5%")
ellipsizes rather than reflowing the tile.

### The notice badge

`Assets/Images/Achievements/notice_icon.png` (256x256 RGBA, copied from the
user's Downloads folder). It replaces the green "BARU" pill in the same
top-right corner slot, drawn at 72x72. The slot is
`size_flags_horizontal = 8` (SHRINK_END) plus `size_flags_vertical = 0`
(SHRINK_BEGIN) on a direct child of the tile's root `PanelContainer`, which
`tests/test_achievement_tile.gd` already pins -- so the badge sits inside
the corner rather than overhanging it as the mockup's paste-up does.

Visibility is unchanged from `BaruBadge`: shown when
`state == STATE_UNLOCKED` (unlocked, prize not yet taken), hidden otherwise.
`CheckBadge` still shows on `STATE_CLAIMED`; the two are mutually exclusive.
`Juice.pop_in` still fires once per id per session via `_baru_shown`, renamed
`_notice_shown`.

The `AchievementBaruBadge` and `AchievementBaruBadgeLabel` variations lose
their only caller and are deleted from `ThemeFactory.gd`, with
`AchievementBaruBadgeLabel` removed from `DISPLAY_ROSTER` in
`tests/test_theme_factory.gd` in the same commit.

**Known reservation, recorded not acted on:** a red circled "!" is the error
idiom everywhere else in this game. It is the user's chosen asset and it
ships as given; if it later reads as an alarm rather than a reward, the
cheapest change is a recolour to `state_warning` amber at the same path.

---

## 3. The detail popup — `AchievementDetailSheet.tscn`, `AchievementDetailSheet.gd`

### Card sizing — the dead space

`Sheet` is anchored `0.08 / 0.3 / 0.92 / 0.78`, so its height is a fraction
of the screen: 922px at 1080x1920 and **1152px at 1080x2400**, for roughly
350px of content, centred by `alignment = 1`. The card gets emptier the
taller the phone.

It becomes a centred, content-sized card:

```
anchors     0.5 / 0.5 / 0.5 / 0.5
offsets     -432 / -60 / 432 / 60
grow_horizontal = 2, grow_vertical = 2   (GROW_DIRECTION_BOTH)
```

A `Control` clamps its size up to `get_combined_minimum_size()`, and with
`GROW_DIRECTION_BOTH` the extra is split evenly about the anchor — so the
card is exactly as tall as its content and stays centred at any phone height.
Width stays 864 (the same 0.08–0.92 band, expressed as offsets).

### Spacing — the user's note

The audit's corrected mock was read as too crowded. The stack uses the
project's own spacing tokens, with `space_lg` (44) between every element
rather than the current 12:

| Slot | Value |
|---|---|
| `Margin` left / right | 56 |
| `Margin` top | 40 |
| `Margin` bottom | 64 |
| `VBox` separation | **44** (`space_lg`) |
| `BackButton` | 96 x 96, left-aligned |
| `IconSlot` | **300 x 300** |
| `Title` | `H2Label` (48), autowrap, centred |
| `Desc` | `AchievementSheetBodyLabel` (28), autowrap, centred |
| `PrizeChip` | amber chip, shrink-centre, only when the entry has a prize |
| `StateRow` | `HBoxContainer`, separation 28, centred |

Resulting card height with a two-line desc and no prize:
40 + 96 + 44 + 300 + 44 + 58 + 44 + 80 + 44 + 72 + 64 = **886**. With a
prize chip it grows by 44 + 38 = 82, to 968. Both are shorter than today's
922-to-1152 card and none of it is dead space.

### Content changes

- **The prize stops printing twice.** `AchievementCatalog.description_of()`
  appends `"\nHadiah: <prize>"` to the desc, and `%PrizeLabel` then repeats
  the same string underneath — visible live on *Pembimbing Sepuh*. The sheet
  now sets `_desc_label.text = entry.desc` and puts the prize in the chip.
  `description_of()` has no other caller and is deleted along with whatever
  in `tests/test_achievements*.gd` covers it.
- **`%PrizeLabel` is deleted.** The chip replaces it.
- **`StateRow`** replaces `ActionArea`: `ProgressLabel` (`TitleLabel`, 36,
  `text_secondary`) beside a 72x72 `StateIcon` `TextureRect`. The icon is the
  lock (`STATE_LOCKED`), the notice icon (`STATE_UNLOCKED`) or the check
  (`STATE_CLAIMED`). The one-shot rule is unchanged: `ProgressLabel` stays
  hidden for `three_star` / `play_all` / `grade` kinds, whose target is
  always 1, and `StateRow` then centres the icon alone.
- **`%BackButton`** goes from 64x64 to 96x96 (touch target) and keeps its
  position as the VBox's first row.

### The claim button

`%ClaimButton`, `%LockIcon` and `%ClaimedLabel` are deleted. Claiming moves
to **opening the popup**: `open_for(id)` shows the sheet, and if the state is
`STATE_UNLOCKED` it then emits `claim_requested(id)` — deferred, so the sheet
is already visible and laid out when the celebration lands on top of it.

Nothing downstream changes. `achievements_screen.gd`'s
`_on_claim_requested` already does `Achievements.claim(id)` → `tap` sfx →
`AchievementClaimPopup`, and `Achievements.claim()` already returns false for
a state that cannot be claimed, so a double-open cannot double-claim.
`state_changed` then drives `_refresh_content`, which swaps `StateIcon` from
the notice icon to the check while the celebration is still up.

The `claim_requested` signal itself is kept — only the button goes.

The notice badge (section 2) is what tells the player a tile has a prize
waiting, which is the affordance the button used to be.

---

## 4. AturJadwal — white outline on the student splash

`Scenes/AturJadwal/atur_jadwal.tscn`'s root-level `TextureButton` is the
student splash and the way to open the student picker
(`_on_select_student_pressed`). It carries no affordance: it looks like
scenery.

`Scripts/Shaders/icon_outline.gdshader` already does exactly this job for the
achievement icons — it traces the art's own alpha, so the ring follows the
character's silhouette rather than the rect.

New resource `Assets/Images/SplashArtMurid/splash_outline_material.tres`:

```
shader              = res://Scripts/Shaders/icon_outline.gdshader
outline_color       = Color(1, 1, 1, 1)
outline_width       = 0.009
```

0.009 rather than the icon material's 0.03 because `outline_width` is a
fraction of the rect: the button's authored rect is 700 x 1244, so 0.009 is a
~6px stroke, and the shader's matching `shrink` pulls the art in by 1.8%
(about 12px over 700) to make room for it. At 0.03 the stroke would be 21px
and the character would visibly shrink.

The material goes on the `TextureButton` in the scene, so it applies to every
student: `_update_student_display()` only swaps `texture_normal`, and the
texture comes from `StudentSkins.splash_for(student)` so the worn skin is
outlined too.

No script change.

---

## 5. Koperasi — remove the crate handle

`koperasi fix.png` circles `Stage/CrateHandle`, the 320px crate
`TextureButton` that sits at the tray's top-right while the tray is expanded
and bottom-right while it is collapsed.

### What it currently does, and what replaces it

| CrateHandle's job | After |
|---|---|
| Toggle the tray | The drag already does this, in both directions |
| Carry the cart count badge | Dropped; the tray's own slots and footer carry it |
| Anchor `BackButton`'s two positions | `BackButton` keeps both positions, on its own tween |

The drag survives the removal. `BasketTray.gd` wires `gui_input` on `Body`,
not on the tray root, and `tray_offset_collapsed` is 190 against a Body that
runs 1360–1920 — so 370px of tray stays on screen and grabbable in the
collapsed state.

### Edits

`Scenes/Koperasi/koprasi.tscn`: delete `Stage/CrateHandle` and its three
children (`Art`, `AP`, `CountBadge`), and the `AnimationLibrary_crate`
sub-resource they use.

`Scripts/Koperasi/koprasi.gd`: delete `crate`, `crate_pos_expanded`,
`crate_pos_collapsed`, `_on_crate_pressed`, `_refresh_crate_badge` and their
call sites. `_on_tray_state_changed` keeps only the back-button half, moved
from the shared `_crate_tween` onto its own `_back_tween`.

`back_pos_collapsed` changes from `(24, 1363)` to **`(24, 1353)`**. Its 1363
was derived from the crate's collapsed top edge (1560 − 185 − 12); with no
crate it is derived from the collapsed **tray's** top edge instead:
1360 (Body's absolute top) + 190 (`tray_offset_collapsed`) − 185
(`BackButton`'s height) − 12 (the same gap) = 1353.
`back_pos_expanded` is unchanged.

### Tests that move with it

- `tests/test_koperasi_back_follows_tray.gd` — its crate-derived assertions
  (`test_collapsed_gap_against_crate_top_is_12px`,
  `test_back_button_animates_inside_the_shared_crate_tween`) are rewritten
  against the tray's collapsed top edge and `_back_tween`.
- `tests/test_koperasi_tray_retract.gd`, `tests/test_basket_tray.gd`,
  `tests/test_koperasi.gd` — drop crate references.

---

## State

Nothing here crosses the `approved_students` ↔ `StudentData` bridge, and
nothing new is persisted.

- **Achievements** read `Achievements` (the autoload) for
  `state_of` / `progress_of` / `progress_fraction_of` / `first_unclaimed_id`,
  and `AchievementCatalog.ENTRIES` for text. Claimed state persists to
  `user://achievements.cfg` exactly as it does today — and is still wiped on
  every launch while the debug `Achievements.RESET_ON_LAUNCH` flag is on
  (`docs/superpowers/DEBT.md`).
- **AturJadwal** reads `GameState.selected_student`, an
  `approved_students`-shaped `Dictionary` (`kepribadian1` is mood,
  `kepribadian2` is energy, `akademis2` is seni budaya). This change touches
  only its splash texture, which comes from `StudentSkins.splash_for()`, not
  from the dict's `splash` key.
- **Koperasi** reads `Cart` and `GameState.player_money`. Removing the crate
  removes a *listener* on `Cart.cart_changed`, never a writer.

## Kelas 7 / 8 / 9

None of these five changes vary by grade. For the record, and because the
question has to be answered rather than assumed:

- The Achievements catalogue is grade-independent except for the three
  `grade_7` / `grade_8` / `grade_9` entries, whose *unlock rule* reads
  `GameState.current_grade`. Nothing in the tile, the grid or the popup
  branches on grade, and this pass does not add such a branch.
- AturJadwal's splash and Koperasi's tray are the same in every grade.

## Files

**Changed**
- `Scenes/Achievements/AchievementTile.tscn` — geometry, notice badge
- `Scenes/Achievements/AchievementDetailSheet.tscn` — full relayout
- `Scripts/Achievements/AchievementTile.gd` — locked icon tint, chip, badge
- `Scripts/Achievements/AchievementDetailSheet.gd` — relayout, auto-claim
- `Scripts/Achievements/AchievementCatalog.gd` — delete `description_of()`
- `Scripts/Design/ThemeFactory.gd` — add two variations, delete two
- `Scenes/AturJadwal/atur_jadwal.tscn` — splash material
- `Scenes/Koperasi/koprasi.tscn` — delete `CrateHandle`
- `Scripts/Koperasi/koprasi.gd` — drop the crate, own tween for back

**Added**
- `Assets/Images/Achievements/notice_icon.png`
- `Assets/Images/SplashArtMurid/splash_outline_material.tres`

**Tests changed**
- `tests/test_achievement_tile.gd`, `tests/test_achievements_grid.gd`,
  `tests/test_achievement_detail_sheet.gd`, `tests/test_achievement_screen.gd`,
  `tests/test_achievements.gd`, `tests/test_theme_factory.gd`,
  `tests/test_atur_jadwal.gd`, `tests/test_koperasi_back_follows_tray.gd`,
  `tests/test_koperasi_tray_retract.gd`, `tests/test_basket_tray.gd`,
  `tests/test_koperasi.gd`

## Not doing

- Recolouring the notice icon. It ships as the user drew it.
- The clipped status pill and the 96px filter button (audit, "worth fixing").
  They are header problems, not layout-grid problems, and folding them in
  would widen a five-part branch to six.
- Any change to `Balance.gd`, which is a collaborator's file.
