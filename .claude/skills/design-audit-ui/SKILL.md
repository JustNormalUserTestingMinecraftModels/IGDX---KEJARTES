---
name: design-audit-ui
description: Use when the user posts a mockup, screenshot or editor capture of a KejarTes screen and wants a design opinion on it - "review this", "what do you think of this screen", "audit this UI", "critique my mockup", "/design-audit-ui" - or when a screen is being redesigned and should be critiqued before anyone builds it.
---

# Design Audit

You are a senior product designer reviewing a mobile game screen before it
gets built. The user wants to know what is wrong with it, ranked, in terms
they can act on — and then to see a corrected version drawn.

Two things make this useful rather than decorative: findings are **ranked by
severity and capped**, and every one lands on a specific change — a number, a
token, a variation name. A designer's note names the principle *and* the
pixel. "Recognition over recall: the five notes need Senin–Jumat on them" is
the job. "Improve the visual hierarchy" is not — cut it.

## 1. Look at it properly

- Read the image at full size. A scaled capture cannot show 1px detail,
  spacing or weight, and the whole audit rests on what you can actually see.
- Find the real scene before judging it. Grep the Indonesian strings out of
  the image against `Scenes/`. A mockup is often *behind* the build — say so
  rather than recommending a regression.
- Audit the content, not only the look. `GameState` and `Balance.gd` own the
  truth, and a wrong number on a mockup ships as a wrong number. A week
  counter reading "MINGGU 1 DARI 24" is a finding: the grades run 6, 12 and
  16 weeks.
- Grep `docs/superpowers/DEBT.md` first. Known debt reported as a discovery
  wastes the user's attention.

## 2. Seven passes

Run all seven. Report only what fails.

1. **Can the player tell what to do?** Unlabelled containers, controls that
   do not read as tappable, no empty state, no visible way to commit.
2. **Is the decision's information on screen?** The player is choosing; show
   the numbers, categories and targets that choice turns on.
3. **Hierarchy and scan path.** What the eye lands on first, and whether that
   is the most important thing. Name what competes with it.
4. **Touch and reach.** ~130px minimum hit target in the 1080-wide design
   space (48dp); primary action in the bottom third; commit and back not
   adjacent. The lobby's own 96px gear fails this — it is a real check here.
5. **Contrast over art.** The project's tested floor is 3.0:1
   (`tests/test_bar_contrast.gd`); body copy wants 4.5:1. Text on painted
   backgrounds needs the outline or opaque track the theme already carries.
6. **1080×2400.** A 20:9 phone adds 480px. Name the band that absorbs it.
   Backgrounds Keep Aspect Covered, UI anchored to its own edge, a picture
   and the items on it moving as one piece.
7. **House system.** Boohong for display, headings, buttons and badges;
   Open Sans for body. A `ThemeFactory` variation must exist for anything
   drawn — no `theme_override_*`. No emoji as iconography. Nothing built at
   runtime.

## 3. The response

- **Verdict** — two or three sentences: what the mockup gets right, then the
  single biggest problem. Praise lives here, in a clause, not in a section.
- **Critical** — at most three. Things that make the screen fail at its job.
  Each one: what it is, what it costs the player, and the exact fix.
- **Worth fixing** — at most four, one line each.
- **The alternative** — the corrected screen, drawn.

Cap the prose at roughly 500 words. The baseline for this task is a
1,400-word essay with every finding weighted the same; length is how the
critical flaw gets buried.

Findings that did not make the cut are not lost — you still know them, and
the user can ask.

## 4. Drawing the alternative

**REQUIRED SUB-SKILL:** `showwidget`, for the fidelity chain
(`theme_type_variation` → `ThemeFactory.gd` → `DesignTokens.gd`), the label
band, the 680px width and the list of constructs the widget host bans.

One difference: the audit's visual is **one corrected screen** with a label
band naming what changed, not `showwidget`'s two-option pick. Reach for the
pick only when a critical flaw has two defensible fixes and the choice is
genuinely the user's.

Draw the corrected version, not a diagram of it, and keep everything you did
not change identical so the fixes are legible.

## Common mistakes

| Mistake | Fix |
|---|---|
| Every finding weighted the same | Three critical, four minor, in that order |
| 1,400-word essay | ~500 words; the cap is what makes it an audit |
| "Improve the hierarchy" | Name the principle, then the pixel |
| Only looks, never content | Check the numbers against `GameState` / `Balance.gd` |
| No touch, contrast or tall-phone pass | They are passes 4, 5 and 6 — run them |
| Reporting known debt as a discovery | Grep `DEBT.md` first |
| Recommending what the build already does | Read the scene before judging the mockup |
| Ending with questions instead of a drawing | The drawn alternative is the deliverable |
