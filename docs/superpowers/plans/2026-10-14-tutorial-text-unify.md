# Plan: unify tutorial text styling (eye-friendly + consistent)

Date: 2026-10-14. Branch: `fix/tutorial-visuals`. Target: `Textures`.

## Problem

The five tutorial surfaces don't look alike. Only StudentCard's first-run flow
wears the new Nota Guru look (`TutorialPanel.nota_style = true`, set in
`Scripts/StudentCard/FirstRunTutorial.gd:78`). Lobby, StudentList, AturJadwal
and SchoolDay keep the old panel: title `H1Label` (Boohong 64px, outlined) over
body `TitleLabel` (Boohong 36px) — a decorative display font set as whole
reading paragraphs, with the prompt in that same 36px so the call-to-action
doesn't separate from the lesson. SchoolDay's end-of-week block is ~90 words of
it (`Scripts/SchoolSimulation/SchoolDay.gd:75`).

Owner's calls (this session):
- Title keeps the fat, playful Boohong look — bold, with a lip (outline), but
  smaller than the 64px it is now.
- Body reads in Open Sans (the body face), looser line spacing.
- Prompt quieter: smaller, secondary colour.
- One look on every tutorial screen.

## Constraints (from CLAUDE.md — do not break)

- **No `theme_override_*`.** Weight/lip comes from a `ThemeFactory` variation +
  the Boohong font file and `outline_size`, never CSS-style overrides. Only
  layout-only constant overrides (`separation`, `margin_*`, `line_spacing`) are
  allowed on a node.
- After editing `ThemeFactory.gd` / tokens, **rebake**: run
  `Scripts/Design/BakeTheme.gd` (File > Run, Ctrl+Shift+X), which writes
  `Assets/Theme/kejartes_theme.tres`. Restart the editor after script edits
  before any `scene_save` (stale-buffer hazard, CLAUDE.md 4b).
- Sizes come from existing tokens (`font_h1/h2/title/body_size` in
  `DesignTokens.gd`: 64/48/36/28). Do **not** add new tokens unless a size
  genuinely has no match; prefer the nearest token.
- `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` pins which variations get
  the Boohong display face. Any new display variation must be added there (and
  to `ThemeFactory`) together or the suite fails.
- Suites run **inside the editor** via the Godot AI MCP `test_run`, not headless.

## Step 1 — define one tutorial type ladder in ThemeFactory

In `Scripts/Design/ThemeFactory.gd` `_build_labels()` specs array (~line 2031),
add/confirm these variations. Reuse `TutorialNoteLabel` (already exists, Open
Sans, `font_title` 36, no outline) as the body.

| Variation | Face | Size token | Outline | Colour |
|---|---|---|---|---|
| `TutorialTitleLabel` (new) | Boohong (display) | `font_h2` = 48 | yes, the baked lip | `text_primary` |
| `TutorialNoteLabel` (exists) | Open Sans (body) | `font_title` = 36 | no | `text_primary` |
| `TutorialPromptLabel` (new) | Open Sans (body) | `font_body_size` = 28 | no | `text_secondary` |

- The spec row's `heading` flag = true for `TutorialTitleLabel` (gets the
  display face); false for the two body ones. The `outlined` flag true for the
  title so it gets the lip — match how `H1Label` gets its outline (see the
  `outline_size` / `font_outline_color` pattern already in the file, e.g. the
  `ObjectiveTitleLabel` lines ~79).
- Add `TutorialTitleLabel` and `TutorialPromptLabel` to `DISPLAY_ROSTER`'s
  exclusion handling: `TutorialTitleLabel` IS display (goes in the roster);
  `TutorialPromptLabel` is NOT (body face) — confirm it's treated like the
  other body variations so `test_display_font_roster` stays green.

## Step 2 — make that ladder the only look (delete the old branch)

In `Scripts/UI/TutorialPanel.gd`:
- Remove the `nota_style` switch and the `title_variation` / `body_variation` /
  `prompt_variation` exports (lines ~167, ~207, ~215, ~233) and the
  `_apply_variations()` fork (~337). The panel always applies:
  title = `TutorialTitleLabel`, body = `TutorialNoteLabel`,
  prompt = `TutorialPromptLabel`.
- Delete the `NOTA_TITLE_VARIATION` / `NOTA_BODY_VARIATION` consts if nothing
  else reads them (grep first).
- `Scenes/UI/TutorialPanel.tscn`: set the three labels' `theme_type_variation`
  to the new names. BodyLabel's negative `custom_minimum_size`
  `Vector2(-170.16, 0)` (line ~90) → a deliberate positive wrap width (match
  the card's inner width; measure in editor). Keep `autowrap_mode = 3`.
- `Scripts/StudentCard/FirstRunTutorial.gd:78-79`: drop the `nota_style`/
  per-`first_run` branch — the look is now uniform. Keep the per-step
  `expression` (Pak Kepsek face) wiring; that's independent of the text style.

Do scene edits first, script edits second; restart editor between scene_save
and script_patch (CLAUDE.md 4b).

## Step 3 — break up the long SchoolDay text

`Scripts/SchoolSimulation/SchoolDay.gd` `end_tutorial_text` (~line 75) is one
long block. Split into 2–3 short steps (≤25 words each) via `show_step()` calls,
or keep one card but trim wording. Owner approved splitting (this session).
Re-read the Indonesian so each card reads naturally (KBBI). This changes tap
count — note it in the PR.

## Step 4 — verify

1. Rebake theme (`BakeTheme.gd`), restart editor.
2. Targeted `test_run`: `test_theme_factory`, `test_tutorial_panel`,
   `test_student_card`, `test_lobby`, `test_student_list`, `test_atur_jadwal`,
   `test_school_day`. Fix the source-scan asserts that name old variations
   (`H1Label`/`TitleLabel` as tutorial labels, `nota_style`). Add a scan that no
   tutorial scene references the removed variations.
3. After green, one full `test_run` (budget one editor restart; check
   `git status` for the theme/bus-layout rebake side effects, CLAUDE.md Testing).
4. Full-size screenshots of all five screens (seed via Debug F1 → Seed Playtest
   State, then teleport; AturJadwal/StudentList/SchoolDay need a pass through
   Atur Jadwal first). Send to owner — a small capture is not proof.

## Out of scope for this plan (separate, from earlier this session)

- Launch-bypass fix (already done on this branch, uncommitted:
  `DebugManager._apply_playtest_defaults` no longer forces
  `tutorials_bypassed`/`lobby_tutorial_completed`; tests
  `test_debug_manager`/`test_bugfix_audio_debug` flipped). Commit alongside or
  separately.
- Wiring `TutorialIdle` onto AturJadwal and SchoolDay (they lack the idle
  nudge). Optional; do only if asked — it's more work (AturJadwal builds its
  overlay at runtime).

## Reference

- Spec: `docs/superpowers/specs/2026-10-07-tutorial-visual-overhaul-design.md`
- DEBT.md "Tutorial art" (placeholder art, drop-replaceable).
- Tokens: `Scripts/Design/DesignTokens.gd` (font_h1 64 / h2 48 / title 36 /
  body_size 28 / caption 22).
