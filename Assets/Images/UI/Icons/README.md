# UI icons

One file per job, at a fixed path. Scenes point at these paths, so a
replacement drops in with no code change. The current files are
placeholders (2026-09-28, UI depth pass) waiting for the owner's chunky set.

A replacement must:

- keep its file name (SVG, or PNG at the same base name — update the
  scene reference if the extension changes);
- have a transparent background;
- be at least 256 px (SVG imports at its viewBox size);
- read on both the cream panels and the brown boards: a light fill and a
  dark outline, like the placeholders;
- show one subject, roughly centred.

`tests/test_ui_icons.gd` checks the size, the transparent corner and the
light-fill-plus-dark-outline rule.

## Where each icon is used

Checked 2026-09-29 (UI depth pass, Phase 3). A new caller adds its row.

| File | Job | Used by | Pinned by |
|---|---|---|---|
| `nav_students.svg` | Roster | Lobby's `Student` tile (`RaisedPage`) | `test_lobby_tile_icons` |
| `nav_jadwal.svg` | Schedule | Lobby's `Jadwal` tile (`RaisedPage`) | `test_lobby_tile_icons` |
| `nav_koperasi.png` (owner art) | Shop | Lobby's `Koperasi` tile (`ShelfPage`) | `test_lobby_tile_icons` |
| `nav_inventory.png` (owner art) | Inventory | Lobby's `Inventory` tile (`ShelfPage`) | `test_lobby_tile_icons` |
| `nav_rapor.png` (owner art) | Report card | Lobby's `ReportStudent` tile (`ShelfPage`) | `test_lobby_tile_icons` |
| `chevron_left.svg` | Previous page | the `Arrow` child of LevelSelect's `PrevArrow`, StudentCard's `NextButtonKiri`, StudentList's `LeftArrow`, ReportCard's `NextButtonKiri` | `test_paging_arrows` |
| `chevron_right.svg` | Next page | the `Arrow` child of LevelSelect's `NextArrow`, StudentCard's `NextButtonKanan`, StudentList's `RightArrow`, ReportCard's `NextButtonKanan` | `test_paging_arrows` |
| `exit.png` (owner art) | Quit the game | MainMenu's `QuitButton` | `test_main_menu` |
| `close.svg` | Close a popup | `NotebookFrame`'s `Chrome/Close` | — |
| `cat_istirahat.svg` | Istirahat (rest) | `RosterCard.SPECIALTY_ICONS`, `StudentList.CATEGORY_ICONS`, `DayStickyNote.category_icons` | `test_category_icons`, `test_student_list` |
| `cat_wirausaha.svg` | Wirausaha (earning) | the same three maps, and Dapatkan Uang's `TipIcon` | `test_category_icons`, `test_student_list` |
| `home.svg`, `info.svg`, `music.svg`, `sound.svg`, `vibrate.svg` | — | nothing yet | `test_ui_icons` only |

Not here on purpose: Back keeps `UI/Nav/return_button.png` (one arrow for
every Back, `test_back_controls`), and the four Lobby rail icons
(`setting.png`, `achievement_button.png`, `icon_daily_login.png`,
`skin_switch.png`) are finished art. `setting.png` (MainMenu's and the
Lobby's gear) has no `Icons/` counterpart yet.
