# Lobby Rail Labels — Design

**Date:** 2026-09-29
**Screen:** `Scenes/Lobby/Lobby.tscn`
**Status:** Approved by the owner (style B, words below).
**Builds on:** `2026-09-29-lobby-layout-grid-design.md`.

## What

Each of the four icon-rail buttons gets a short word under it on a small cream
pill, as in the owner's reference lobbies (a labelled button reads faster than
a bare icon):

| Button | Pill node (unique name) | Word |
|---|---|---|
| `DailyLogin` | `DailyLoginLabel` | Hadiah |
| `SettingsButton` | `SettingsLabel` | Setelan |
| `AchievementButton` | `AchievementLabel` | Prestasi |
| `SkinSwitchButton` | `SkinSwitchLabel` | Kostum |

## How

- **No new theme work.** Each pill is a `PanelContainer` with the existing
  `RosterChip` variation (the cream "4 murid" chip beside JADWAL!), holding a
  `Label` named `Text` with the existing `CaptionLabel` variation, centred.
  Pills and labels ignore the mouse.
- **The buttons stay the rail's direct children** (four suites pin it), so each
  pill is a **child of its button**, hanging below it (layout mode 0, local
  rect x −18…114, y 98…142: 132×44, centred under the 96 px icon, 2 px below).
  Measured under the baked theme on 2026-09-29, the widest word ("Prestasi")
  needs a 131×43 pill, so all four share 132×44.
- **The rail moves** so the pills' right edges line up with the coin box and
  the 48 px margin (x 1032), and the last pill ends 24 px above the coin box:
  - `IconRail` offsets: `offset_left −114`, `offset_right −18`,
    `offset_top −1062`, `offset_bottom −498`, which gives the rect
    918, 810, 96, 564 on the design screen.
  - `separation` goes from 24 to 60 (2 px gap, 44 px pill, 14 px to the next
    icon), a layout constant, which the rules allow.
  - The buttons sit at y 810, 966, 1122 and 1278. The pills sit at y 908, 1064,
    1220 and 1376–1420, all at x 900–1032.
- The swipe is unchanged: the rail slides 180 px right, which carries every pill
  fully off screen (pill left edge 900 + 180 = 1080).

## Tests

- `test_lobby_layout` `DESIGN_RECTS`: `IconRail` becomes 918,810,96,564, and
  the four buttons become x 918 at y 810, 966, 1122 and 1278.
- `test_tall_screen_layout`: `DailyLogin` becomes 918,1290,96,96 at 1080×2400.
- New:
  - Each pill is a child of its button and uses `RosterChip` / `CaptionLabel`
    with its word.
  - Its authored rect fits its minimum size.
  - Its design-screen rect ends at x ≤ 1032.
  - The lowest pill ends at least 24 px above the coin box.
  - Hidden, every pill's drawn rect lies at or past the screen's right edge.
