# Fonts

- `Boohong.otf` — display face (headings, buttons, big numbers)
- `OpenSans-Medium.ttf` — body face (everything else)

Open Sans is licensed under Apache License 2.0. Boohong's license has not been
verified — its embedded metadata names Khurasan as the foundry and points to
`https://khurasanstudio.com/license/`, but no license file for either
`Boohong.otf` or `OpenSans-Medium.ttf` has been added to this repo yet;
confirm and add before shipping.

## Swapping in your own fonts

1. Drop your `.ttf` / `.otf` into this folder.
2. Open `Assets/Theme/design_tokens.tres` in the inspector.
3. Under **Typography**, drag your file onto `Font Display` and/or `Font Body`.
4. Open `Scripts/Design/BakeTheme.gd` and run File > Run (Ctrl+Shift+X).

No code changes are required. The whole game re-renders in the new face.

## Roles (2026-09-05)

- `Boohong.otf` — the **display** face. Headings, titles, buttons, badges,
  and stat numerals. Wired as `DesignTokens.font_display`.
- `OpenSans-Medium.ttf` — the **body** face. Everything else, including every
  untagged Label. Wired as `DesignTokens.font_body`, which `ThemeFactory` sets
  as the theme's `default_font`.
Those two are the only fonts here. The retired faces (`Brocats.otf`,
`Catfiles.otf`, `Catcut.otf`, `Milker.otf`, `Baloo2-Variable.ttf`,
`Nunito-Variable.ttf`) and the other 35 Open Sans weights were deleted as
unused on 2026-09-11; `git log --diff-filter=D -- Assets/Fonts` finds the
commit to restore one from. Wire a restored face through a new `DesignTokens`
slot, never a `theme_override_fonts/` entry.

Which variations take which face is pinned by `DISPLAY_ROSTER` in
`tests/test_theme_factory.gd`. Change the roster and the factory together.
