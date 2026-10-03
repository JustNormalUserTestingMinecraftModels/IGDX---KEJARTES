# Credits tab: movie-style layout with per-track music credits

**Date:** 2026-10-03. **Status:** approved in brainstorming (mockup
`credits-layout-v2`, option C plus griseyo combined).

## Goal

Replace the KREDIT tab's flat name/role list with centred, film-style credits
that also credit every music track, and fold griseyo's special thanks and their
music into one entry.

## Content (top to bottom, all centred)

1. **KEJARTES** (game title, red) and `oleh 1 MINUS TEAM` under it.
2. Team, one role heading then its names:
   - PROGRAMMER & DESAINER UI: Eleazar Evan Putra, Hosea Juan Kurniawan, I Made Panji Putra
   - DESAIN KARAKTER & ILUSTRATOR: Abdullah A'asiq Satria
   - SENIMAN LATAR & MULTIMEDIA: Albertus Akmel Bintang Prasetyo
3. **MUSIK** (other artists), name then `"track" · where it plays`:
   - fiikuri: "Epic Nusantara" · Layar Judul
   - sounovamusic: "Nusantara Calling" · Hasil Menang
   - extenz: Musik Kalah · Hasil Kalah
4. A divider, then **TERIMA KASIH KHUSUS**: Yosua Coyo Wagito, `griseyo di
   Spotify`, then `atas musik untuk` and the list: Lobi (3 lagu) · Hari Sekolah
   · Minigame Akademis (3 lagu) · Minigame Olahraga · Membatik · Lomba Menari.

The intro cutscene music has no known artist and is left out for now (owner,
2026-10-03).

## Build

- **Static nodes only** (rule 2): every line is a Label in `Settings.tscn`
  under the existing `CreditsCard/Margin/VBox`, which keeps its
  `CardSectionLabel` "KREDIT" heading (pinned by `test_settings`). Labels are
  centred (`horizontal_alignment`) and autowrap.
- **Two new ThemeFactory variations** (rule 1, no overrides), both on the
  display face, so both join `DISPLAY_ROSTER`:
  - `CreditTitleLabel`: the KEJARTES line, `font_h2`, `accent_tomato_lip`.
  - `CreditRoleLabel`: role headings, `font_caption`, `accent_tomato_lip`
    (the darker red, for small-text contrast on cream).
  Names use `BodyLabel`; track lines and `oleh…` use `CaptionLabel`; the divider
  is a `SettingsDivider`. Rebake after the factory edit.
- **Data:** `Assets/Audio/BGM/CREDITS.md` records griseyo as the artist of
  every 2026-10-03 track and of `minigame_senibudaya_menari.mp3`.

## Tests

`test_settings`: `_SECTIONS["CreditsCard"]` lists the new child order, and a new
test pins each label's text and variation. `test_theme_factory`: the roster
gains the two variations.

## Out of scope

Sound-effect credits; the intro cutscene artist.
