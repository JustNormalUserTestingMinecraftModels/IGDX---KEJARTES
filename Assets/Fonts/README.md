# Fonts

- `Catfiles.otf` — display face (headings, buttons, big numbers)
- `OpenSans-Medium.ttf` — body face (everything else)

Open Sans is licensed under Apache License 2.0. Catfiles' license has not been
verified — no license file for either `Catfiles.otf` or `OpenSans-Medium.ttf`
has been added to this repo yet; confirm and add before shipping.

## Swapping in your own fonts

1. Drop your `.ttf` / `.otf` into this folder.
2. Open `Assets/Theme/design_tokens.tres` in the inspector.
3. Under **Typography**, drag your file onto `Font Display` and/or `Font Body`.
4. Open `Scripts/Design/BakeTheme.gd` and run File > Run (Ctrl+Shift+X).

No code changes are required. The whole game re-renders in the new face.

## Roles (2026-09-05)

- `Catfiles.otf` — the **display** face. Headings, titles, buttons, badges,
  and stat numerals. Wired as `DesignTokens.font_display`.
- `OpenSans-Medium.ttf` — the **body** face. Everything else, including every
  untagged Label. Wired as `DesignTokens.font_body`, which `ThemeFactory` sets
  as the theme's `default_font`.
- `Milker.otf`, `Baloo2-Variable.ttf`, `Nunito-Variable.ttf` — no longer
  referenced by the theme. Kept in the repo, unused.

The other 43 Open Sans weights are imported but unused. Reach for one only
through a new `DesignTokens` slot, never a `theme_override_fonts/` entry.

Which variations take which face is pinned by `DISPLAY_ROSTER` in
`tests/test_theme_factory.gd`. Change the roster and the factory together.
