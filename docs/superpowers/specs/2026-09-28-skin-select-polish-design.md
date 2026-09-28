# Skin Select Polish — Design & Implementation Plan (handoff)

**Date:** 2026-09-28
**Branch:** `skin-selection-polish` (off `Textures`)
**Status:** Handoff. Design approved by the mentor via interactive mockup; not
yet built. This document is the full brief for another team's Claude to execute.
**Interactive mockup:** the approved look & feel is an animated HTML prototype
(scrapbook tray, class-only rail, 3D buttons, SFX). Rebuild the *feel*, not the
literal HTML — the real screen is Godot with the project Theme.

---

## Why

The current skin picker (`Scenes/Skins/SkinSelect.tscn`,
`Scripts/Skins/SkinSelect.gd`) works but reads as unpolished:

1. **It shows all six characters** even though the player's class is only 2–4
   students. The mentor's note: "why is everyone there?" It feels like a crowd,
   not *your* class.
2. **Flat chrome.** Plain white tray, plain red `TERAPKAN`, plain rail squares.
   No unifying style, no "schooly" character, weak feedback.
3. **Buttons are flat.** No depth, no press feedback beyond the auto-juice.

The rework makes the screen **mirror the roster**, dresses it in the game's
existing **scrapbook / paper-and-tape** visual world (as used in the Lobby HUD
and Settings), gives every button **chunky 3D depth**, and adds **sound + motion
feedback**.

---

## Scope decisions (locked by the mentor)

### 1. Class-only rail — the screen reads the roster

**This reverses a documented decision.** Today `SkinSelect.open()` takes no
argument and fills the rail from `StudentSkins.NAMES` (all six), on purpose:
`equipped_skins` is keyed by *name*, so a skin survives the grade change that
clears the roster. See the header comment at `SkinSelect.gd` `open()` and
`StudentTile.gd`.

**New behavior:** the rail shows **only the students in the current roster** —
`GameState.approved_students`, whose size is `2 / 3 / 4` for grade `7 / 8 / 9`
(the canonical source is `StudentCard.max_approve_for(grade)`; do not hardcode
2/3/4). No "other students," no extra tab.

**Accepted consequence:** a character *not* in this grade's class cannot be
re-dressed from this screen, and you cannot pre-dress a future student. They
keep whatever skin they last wore (persistence is unchanged — still per-name in
`GameState.equipped_skins`). The mentor accepted this trade for a focused,
"this is my class" screen.

**Empty roster guard:** if `approved_students` is empty (reachable via debug /
before any approval), fall back to showing `StudentSkins.NAMES` so the screen is
never blank. Keep this cheap; it is a safety net, not a feature.

### 2. Scrapbook / notebook visual language

Match the paper-and-tape world already shipped elsewhere. Concretely:

- The bottom **tray** is a paper sheet with faint horizontal rule lines and two
  **tape strips** at its top corners (decorative nodes in the `.tscn`, not
  runtime-drawn).
- **Rail tiles** read as **taped photo cards**: cream card stock, a small tape
  tab, a handwritten-style caption with the student's name.
- The **skin name** ("Seragam Sekolah") uses the display font, centered, with
  paper-divider dots either side.
- A short **"Kelasmu · N murid"** section header sits above the rail
  (`font_display`, brand-brown), with a faint handwritten hint ("ketuk untuk
  pilih").

Use `ThemeFactory` type variations for every styled node (see Constraints).
Reuse `paper.png` **only** where its cut corner is the point, and respect its
opaque region (`docs/superpowers/DEBT.md`, and the `paper-png-opaque-region`
note) — measure alpha before laying content on it.

### 3. Centered rail

The rail is **center-aligned**, not left-packed. With 2–3 cards this removes the
dead space on the right that made the old rail look unfinished. (`HBoxContainer`
with `alignment = 1`, or an equivalent centered container.)

### 4. Chunky 3D buttons

Every button gets **layered drop-shadow depth** and a **press-sink**:

- `TERAPKAN`: success-**green** (not the current alarm-red — red = danger
  elsewhere in the game), a solid bottom "lip" shadow plus a soft cast shadow,
  and a small "PAKAI!" tag accent. Sinks ~4px on press.
- **Back** button: circular, cream, same lip+cast shadow, sinks on press.
- The depth is a `StyleBoxFlat` with an offset shadow (or a two-layer stylebox)
  in a new `ThemeFactory` variation — **not** a `theme_override`. Press-sink is
  a `Juice.press`/`release` (already auto-wired by `UIPolish` for `Button`s;
  `TextureButton` back button may need an explicit hook).

### 5. Sound

Wire `AudioDirector.play_sfx(&"...")` cues (the screen already plays `&"tap"` on
open — match that registry; pick existing cue names, add new ones to the
`AudioDirector` registry only if none fit, and propose rather than invent):

- **Card select** — soft paper "tap" when a rail tile is chosen.
- **Skin snap** — a light "tick" each time the carousel settles on a new skin
  (fire on `_skin_index` change in `select_skin` / settle, **not** every drag
  frame).
- **Apply** — a rising confirm chime on `TERAPKAN`.

Respect `GameSettings` mute/volume through `AudioDirector` (do not play directly).

---

## Optional / stretch features (NOT in core scope — get user sign-off first)

Presented to the mentor; the mentor did not commit to these. Leave out of the
first PR unless the user asks. Listed best-value-first:

1. **"Baru!" badge** on a skin the student has never worn — a taped ribbon that
   clears once applied. Needs a tiny "seen skins" set (session-scoped; do **not**
   add persistence without being asked — see CLAUDE.md).
2. **Peek-on-select** — the student does a small hop/turn as they slide onto the
   stage when you tap a rail card.
3. **Turntable idle** — the centered student breathes / occasional blink so the
   stage feels alive at rest.
4. **Locked-skin treatment** — locked skins show a taped "?" + padlock and a
   hint; `GameState.is_skin_unlocked` already exists. (Only meaningful once
   skins are actually earnable.)

---

## What stays exactly as-is (do not rebuild)

- **The carousel physics.** `_scroll`, `card_pose`, drag/velocity/overscroll,
  `_slide_to`, `SkinCard.settle_index` — this is good motion. The rework changes
  the **cards and chrome around it**, not the slide engine.
- **The pending/commit model.** Sliding records a pending choice; `TERAPKAN`
  commits every pending character at once; back discards. Keep it. (With a
  class-only rail the pending set is naturally just the roster.)
- **Persistence.** Still `GameState.equipped_skins`, keyed by name, session-
  scoped. No new persistence.
- **Overlay-not-scene.** Still instanced by `Lobby.gd` over the blurred Lobby.
- **`splash_for_day` / skin resolution** through `StudentSkins`.

---

## Implementation plan (ordered, TDD)

Work in the editor via the Godot AI MCP (`scene_open` → node ops → `scene_save`),
**scene work before script work** (see CLAUDE.md save hazards). Normalize edited
`.gd` files to LF and edit via `script_patch`. Run **targeted**
`test_run(suite=...)`, budget one editor restart per full run.

**Task 1 — Roster-aware rail (behavioral core).**
- Change `SkinSelect.open()` (or add `open(roster)`) to build the rail from
  `GameState.approved_students` names, falling back to `StudentSkins.NAMES` when
  empty. Drive visible tile count from `approved_students.size()` (hide the
  authored `Tile1–6` beyond the count, the way `Dots` already hides extras).
- Map each visible tile → a roster name; `select_student(index)` indexes the
  visible roster, not `NAMES`.
- Update the header comments in `SkinSelect.gd` and `StudentTile.gd` that claim
  "all six, never the roster" — they will now be wrong.
- **Tests:** extend `tests/test_skin_select*.gd` (or the existing skin suite —
  grep `tests/` for the current coverage) — assert rail count follows
  `max_approve_for(grade)` for 7/8/9, and the empty-roster fallback. Follow the
  source-scan pattern where live instantiation isn't possible.

**Task 2 — Centered rail + "Kelasmu · N" header.**
- `alignment = 1` on the rail container (or centered wrapper).
- Add the section-header nodes (label + hint) as authored `.tscn` nodes with
  `ThemeFactory` variations. Set `N` at runtime from the roster size (per-call
  dynamic text is allowed; document it).

**Task 3 — Scrapbook tray + taped cards (visual).**
- Restyle the tray as paper with rule lines + corner tape (authored nodes).
- Restyle `StudentTile` / `SkinCard` frames as taped photo cards via new
  `ThemeFactory` variations (`SkinPhotoCard`, tape accent, caption label). No
  `theme_override_*`. Rebake the theme (`Scripts/Design/BakeTheme.gd`,
  Ctrl+Shift+X) after adding variations.
- Respect `paper.png` opaque region if used.

**Task 4 — 3D buttons.**
- New `ThemeFactory` variations for the green `TERAPKAN` (`SkinApplyButton`) and
  the circular back button with layered lip + cast shadow styleboxes. Rebake.
- Ensure press-sink: `Button` gets it from `UIPolish`; wire `Juice.press/release`
  on the `TextureButton` back button if needed.
- **Tests:** `tests/test_theme_factory.gd` pins variations — add the new ones to
  both `ThemeFactory.gd` and the test roster together (the suite fails otherwise).

**Task 5 — SFX.**
- Fire `AudioDirector.play_sfx` on: card select (`select_student`), skin settle
  (`select_skin` / `_end_drag` on `_skin_index` change), and `apply()`.
- Use existing cue names where they fit; propose additions to the `AudioDirector`
  registry rather than inventing silently.
- **Tests:** source-scan that the calls exist at the three sites.

**Task 6 — Full regression + theme rebake check.**
- Run the whole suite once (expect the `theme_rebake` + `default_bus_layout`
  writes noted in CLAUDE.md; `git checkout --` whichever you didn't intend).
- Screenshot the screen at full size on grade 7 (2 students), 8 (3), 9 (4) to
  confirm centering and that no benched student appears.

---

## Constraints (from CLAUDE.md — do not violate)

- **No `theme_override_*`.** Only `ThemeFactory` type variations (add new ones +
  rebake). Layout-only constant overrides (`separation`, `margin_*`) are the
  sole exception.
- **No runtime-built visuals.** Static chrome = authored `.tscn` nodes; repeated
  rows = `PackedScene` templates; the only runtime-built thing here remains the
  per-character carousel cards (already an `ALLOWED` dynamic exception) and
  per-call dynamic **text** (the "N murid" count).
- **Every screen fills any phone** — re-anchor to edges inside
  `SafeAreaMargin → UI`; test at 1080×2400.
- **Docs on every `##` header and `@export`** (`tests/test_script_documentation.gd`).
- **Do not edit `Balance.gd`.** Not relevant here, but any new tunable of ours
  goes in a named `const`/`@export`, never inline.
- **No emoji as UI iconography** — real transparent SVG textures.
- Indonesian for all UI text and game-facing identifiers; English for systems.

## Definition of done

- Rail shows exactly the roster (2/3/4 by grade), centered, empty-roster
  fallback safe.
- Scrapbook tray + taped cards + 3D green `TERAPKAN` + 3D back button, all via
  `ThemeFactory`, theme rebaked.
- Three SFX cues wired through `AudioDirector`.
- Carousel physics, pending/commit, persistence, overlay model all unchanged.
- Full suite green (mind the theme-rebake ordering caveat); finish with the
  `ship-pr` skill.
