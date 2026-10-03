# Credits Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> (inline: the Godot bridge is single-client, so subagents cannot drive it).

**Goal:** Rebuild the KREDIT tab as centred film-style credits with per-track
music credits (spec `specs/2026-10-03-credits-tab-design.md`).

**Architecture:** Two new ThemeFactory label variations, rebaked; static Label
nodes in `Settings.tscn` under `CreditsCard/Margin/VBox`; tests pin order,
text and variations.

**Tech Stack:** Godot 4.6, GDScript, godot-ai MCP.

## Global Constraints

- No `theme_override_*` except layout constants; no runtime-built visuals.
- Indonesian UI text exactly as in the spec.
- Rebake, then restart the editor before any `scene_save` (memory:
  rebake-alone-never-beside-scene-ops); diff the bake.

---

### Task 1: Theme variations

**Files:** `Scripts/Design/ThemeFactory.gd`, `tests/test_theme_factory.gd`,
`Assets/Theme/kejartes_theme.tres` (rebaked).

- [ ] Add `"CreditTitleLabel"` and `"CreditRoleLabel"` to `DISPLAY_ROSTER`.
- [ ] Run `test_run(suite="theme_factory")`: expect FAIL (types missing).
- [ ] In ThemeFactory's label block, add both variations of `Label` with the
  display font: Title `font_h2`, Role `font_caption`, both `accent_tomato_lip`.
- [ ] Rebake (`test_run(suite="theme_rebake")`), restart the editor, re-run
  `theme_factory`: PASS. Commit.

### Task 2: Credits nodes + data

**Files:** `Scenes/UI/Settings.tscn`, `tests/test_settings.gd`,
`Assets/Audio/BGM/CREDITS.md`.

- [ ] Update `_SECTIONS["CreditsCard"]` to the new child order and add
  `test_credits_read_top_to_bottom` pinning `[name, variation, text]` per row.
- [ ] Run `settings`: expect FAIL.
- [ ] Delete `Credit1..6` and `Rule1..5`; create the rows in the spec's order
  (centred, autowrap); `scene_save`; restore slider values if the save baked
  live volumes.
- [ ] Record griseyo in CREDITS.md. Run `settings`, then the full suite. Commit.
