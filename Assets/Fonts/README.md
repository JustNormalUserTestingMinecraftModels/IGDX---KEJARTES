# Fonts

- `Baloo2-Variable.ttf` — display face (headings, buttons, big numbers)
- `Nunito-Variable.ttf` — body face (everything else)

Both are SIL Open Font License 1.1 — each with its own upstream copyright
holder, so each keeps its own license file: `Baloo2-OFL.txt`, `Nunito-OFL.txt`.

## Swapping in your own fonts

1. Drop your `.ttf` / `.otf` into this folder.
2. Open `Assets/Theme/design_tokens.tres` in the inspector.
3. Under **Typography**, drag your file onto `Font Display` and/or `Font Body`.
4. Open `Scripts/Design/BakeTheme.gd` and run File > Run (Ctrl+Shift+X).

No code changes are required. The whole game re-renders in the new face.
