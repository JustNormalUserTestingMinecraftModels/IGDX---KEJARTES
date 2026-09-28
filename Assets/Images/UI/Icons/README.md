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
