# Level Selection Polish — Design

**Status:** Handoff spec. Not built. For a teammate's Claude to pick up on the
`level-selection-polish` branch.
**Date:** 2026-09-28
**Screen:** the amplop coklat grade picker
(`Scenes/LevelSelect/LevelSelect.tscn`, `Scripts/LevelSelect/*`).
**Shipped base:** the amplop level select already exists on `Textures`
(spec `2026-09-25-amplop-level-select-design.md`). This is a **polish pass** on
top of it — presentation only, plus one *balance proposal* that is not ours to
merge.

## Why

A mentor review of the live screen flagged four things that make it read as
unfinished:

1. **Fan crowding ("clipping there and there").** The neighbouring envelopes sit
   almost entirely behind the centre one; only their tabs jut out and get
   visually bisected by the centre body's edge. The centre "KELAS 8" tab also
   crowds the wax seal/pins. There is **no `clip_contents` in the scene** — this
   is z-overlap crowding, not a rect-clip bug, so it is fixed by fan geometry,
   not by unclipping anything.
2. **The "Buka map ini" moment is too small.** Tapping open reuses the fan's
   `card_scale` (1.2) for the opened envelope and shows a small surat-tugas card.
   It should feel like the chosen amplop **flies toward the player** (scales up),
   landing on a **large, thumb-friendly** "Yakin?" confirm with big
   Batal / Terima Tugas buttons.
3. **No drop shadows.** The envelopes and the confirm card sit flat on the wood
   backdrop. The project already has a first-class soft-shadow component
   (`Scenes/UI/PaperShadow.tscn`); the screen simply does not use it.
4. **12- and 16-week grades feel too long.** Grade 8 (12 wk) and Grade 9 (16 wk)
   drag. Shortening them is a **balance** change and `Balance.gd` is
   collaborator-owned — so this pass ships a **proposal doc**, not an edit.

## Scope

| Part | What | Who owns it |
|---|---|---|
| A | Fix fan crowding via `@export` fan geometry | ours (presentation) |
| B | Zoom-in opened envelope + large mobile confirm | ours (presentation) |
| C | Week-length rebalance | **proposal only** — `Balance.gd` collaborator decides |
| D | `PaperShadow` on the amplop cards + confirm letter | ours (presentation) |

Out of scope: any gameplay/flow change, the briefing card's data (weeks/target
still read from `Balance.gd`), the swipe/arrow selection logic.

## Global constraints (from CLAUDE.md — every part obeys these)

- **No `theme_override_*`.** Use `ThemeFactory` type variations; add one +
  rebake if none fits. Layout-only constant overrides (`separation`, `margin_*`,
  `custom_minimum_size`) are the only exception.
- **No visual built at runtime.** Static chrome = nodes in the `.tscn`;
  responsive geometry = a `@tool` script with documented `@export` knobs. The
  `test_viewport_editability.gd` ratchet is one-way.
- **Every script `@tool`**, `##` file header, `##` on every `@export`
  (`test_script_documentation.gd`).
- **`@export`s live on an instanced scene's ROOT**, never its children — child
  overrides are silently dropped on save (CLAUDE.md 4b). This is why the amplop
  is fed through `AmplopCard`'s root `@export`s today, and why the shadow knobs
  must live on the `PaperShadow` instance root.
- **Weeks/target are READ from `Balance.gd`**, never re-typed. `Balance.gd` is
  read-only for us.
- **Never hand-edit a `.tscn` while the editor is attached** — go through
  `scene_open` → `node_create`/`node_set_property`/`batch_execute` → `scene_save`.
  After patching a `.gd`, `filesystem_manage(op="scan")` before `test_run`.
  Scene work first, script work second (CLAUDE.md 4b).
- **Indonesian** for game-facing text; English for systems code.

---

## Part A — Fan crowding

The fan is laid out by `LevelSelect._layout_cards()` from these root `@export`
knobs (current defaults): `fan_step_x = 150`, `fan_drop_y = 34`,
`fan_step_degrees = 8`, `side_scale = 0.86`, `card_scale = 1.2`. The
`AmplopCard` template is 400×526; at `card_scale = 1.2` the centre card is
~480px wide, so a 150px step leaves neighbours ~69% occluded — their tabs poke
out of dead centre and read as slivers.

**Fix — spread the fan so each side envelope reads as a whole, tilted card whose
tab is not sliced by the centre body:**

- Raise `fan_step_x` to ≈ 210–230 so neighbours clear the centre body's edge.
- Increase `fan_drop_y` (≈ 34 → ≈ 48) and `fan_step_degrees` (≈ 8 → ≈ 10–12)
  so the side cards splay down-and-out like a hand of cards, tucking their
  bodies behind the centre instead of hiding under it.
- Verify the centre tab clears the seal/pins; if it still collides, nudge the
  `Tab` node's authored offset in `AmplopCard.tscn` (a layout-only change on the
  template root's child anchor — but note the `@export` rule: the tab is part of
  the template chrome, edited on the template, not per-instance).

These are **default-value changes to existing `@export`s** plus at most one
authored offset in the template. No new nodes, no runtime construction.

**Verification is visual.** The builder must open the scene in the editor,
`editor_screenshot` at full size, and land the numbers by eye against the two
mentor screenshots (kept in the plan). Send a before/after to the human before
calling it done — the project rule is that a small screenshot is not evidence a
design change is finished; the human checks against reference.

**Acceptance:** at rest, all three grade tabs are fully legible; no tab edge is
bisected by another envelope's body; the centre "KELAS N" tab does not overlap
the wax seal. Side envelopes read as recognizable tilted cards, not slivers.

---

## Part B — Zoom-in open + large mobile confirm

Owned by `Scripts/LevelSelect/OpenAmplopConfirm.gd` and its scene
(`OpenAmplopConfirm.tscn`, nested in `LevelSelect.tscn` as `$Confirm`).

Today `present()` fades the scrim in and `play_open()` runs the seal-pop /
flap-fold / pupil-peek at a fixed `set_envelope_scale(card_scale)` (1.2). There
is no zoom.

**B1 — the envelope flies toward the player.** Add a scale-up to the open:

- New documented root `@export`s on `OpenAmplopConfirm`:
  `open_scale_target: float = 1.9` (final scale of the opened envelope) and
  `open_zoom_sec: float = 0.35` (duration).
- In `play_open()` (or a new step chained into its tween), animate
  `envelope.scale` from the current `card_scale` up to `open_scale_target`
  with `TRANS_BACK` / `EASE_OUT` — the "flies toward you" feel — **in parallel**
  with the existing seal/flap/pupil tweens so the ritual reads as one motion.
- Keep growing the envelope about its bottom-centre pivot as `set_envelope_scale`
  already does, so it rises away from the letter, not into it.
- On `dismiss()`, reset `envelope.scale` back to `card_scale` so a re-open starts
  clean (mirror the existing `_rest_letter()` reset).

**B2 — the surat tugas becomes a large, thumb-friendly confirm.** In
`OpenAmplopConfirm.tscn`:

- Enlarge the `$Letter` card: bigger `custom_minimum_size`, more `Margin`
  padding, larger title/body via `ThemeFactory` label variations (e.g.
  `H2Label` / body) — **not** `theme_override_*`.
- Make `$Buttons/Accept` (Terima Tugas) and `$Buttons/Cancel` (Batal)
  thumb-sized: raise `custom_minimum_size.y` to a comfortable tap target
  (≈ 96–112px on the 1080-wide canvas), keep the existing `DangerButton` /
  `PrimaryButton` (or `SuccessButton`) variations they use — check what they use
  today and keep the semantic mapping (Terima = affirmative, Batal = cancel).
- Confirm the layout still fits inside `SafeAreaMargin` on a 20:9 tall phone
  (1080×2400) — the confirm is an overlay, so re-anchor to bottom if needed
  (see CLAUDE.md "tall phones" / `test_tall_screen_layout.gd`).

**Acceptance:** tapping Buka Map Ini makes the chosen envelope visibly surge
larger toward the player, then presents a confirm whose buttons are easily
tappable one-handed. Cancel returns to the fan cleanly; a second open replays
the zoom from the fan scale.

---

## Part C — Week-length rebalance (PROPOSAL ONLY)

**We do not edit `Balance.gd`.** This part's deliverable is a written proposal
for the `Balance.gd` owner, `docs/superpowers/specs/2026-09-28-week-length-rebalance-proposal.md`
(the plan's Task C creates it). It must NOT change
`JUMLAH_MINGGU_KELAS_*` or `TARGET_KENAIKAN_KELAS_*`.

Weeks and target uplift are a **pair** that together decide whether a grade is
fair or impossible. The design doc's rest-slack math:

| Grade | Weeks | Days (×5) | Study-days needed | Rest slack |
|---|---|---|---|---|
| 7 | 6 | 30 | ~15 | ~50% (santai) |
| 8 | 12 | 60 | ~41 | ~32% (menantang) |
| 9 | 16 | 80 | ~60 | ~25% (susah) |

Chopping weeks without lowering targets would drive Grade 9's slack negative —
**unwinnable**. So the proposal shortens weeks *and* targets by the same factor,
holding felt difficulty constant while cutting playtime:

| Grade | Weeks now → proposed | Target now → proposed | Factor | Rest slack |
|---|---|---|---|---|
| 7 | 6 (unchanged) | +15 (unchanged) | — | ~50% |
| 8 | 12 → **9** | +34 → **+26** | 0.75× | ~32% (held) |
| 9 | 16 → **12** | +40 → **+30** | 0.75× | ~25% (held) |

Rationale to include in the proposal doc: 25% less grind per long grade, same
challenge curve, still winnable by `run_stars() >= 2.0` under normal play.
Because the level-select screen already **reads** both numbers from `Balance.gd`,
the moment the owner accepts and edits `Balance.gd`, the picker's week grid and
brief update with zero screen changes.

**Acceptance:** the proposal doc exists, states the numbers and the slack math,
and explicitly defers the edit to the collaborator. No `Balance.gd` diff on this
branch.

---

## Part D — Drop shadows

Reuse `Scenes/UI/PaperShadow.tscn` (`Scripts/UI/PaperShadow.gd`) — the project's
soft contact-shadow component. It casts the parent's **alpha silhouette**, offset
down-right for the game's upper-left light, via a shared soft-shadow shader.
Every knob lives on the instance ROOT (children's overrides are dropped on save).

**D1 — shadow under each amplop.** In `AmplopCard.tscn`:

- Instance `PaperShadow` as the **backmost child inside `$Bob`**, before `Body`
  in draw order, so all three fan envelopes AND the opened confirm envelope (same
  template) inherit it.
- Set `shadow_texture` to the kraft `Body` art so the cast shape is the
  envelope, not a blob. Set `shadow_size` to the template's 400×526 (or
  `follow_parent_rect` if simpler), `shadow_stretch_mode` to match `Body`.
- Tune `shadow_offset` (≈ 14,18 default is fine at template scale — scale it down
  since the amplop is smaller than the 1080px card the defaults were baked for)
  and `shadow_alpha` ≈ 0.33. Keep `blur` in the 2–4 texel band the shader header
  asks for.
- Because the shadow lives inside `Bob`, it lifts with the centre card's idle
  hop — the shadow naturally deepens/separates as the card rises. That is
  desirable; no extra work.

**D2 — shadow under the surat tugas.** Add a `PaperShadow` (or the same pattern)
behind `$Letter` in `OpenAmplopConfirm.tscn` so the confirm card lifts off the
scrim.

**Acceptance:** each envelope and the confirm card cast a soft shadow matching
its own shape, offset down-right, subtle (reads as a shadow, not a second dark
copy). Pinned by a source-scan assertion (Part-D test).

---

## Testing

All via the `godot-ai` MCP `test_run` inside the editor (never headless).

- **`test_level_select.gd`** — extend with source-scan assertions:
  - Part A: the new fan-geometry defaults are present (or unchanged knobs still
    read from the same `@export`s — assert the script still exposes them).
  - Part B: `OpenAmplopConfirm.gd` exposes `open_scale_target` / `open_zoom_sec`
    and the open tween scales `envelope`.
  - Part D: `AmplopCard.tscn` / `OpenAmplopConfirm.tscn` instance `PaperShadow`.
- **`test_paper_shadow.gd`** — must stay green; do not disturb the 13 existing
  instances' baked values (the shadow added here is a 14th instance with its own
  knobs, not a change to the shared defaults).
- **`test_tall_screen_layout.gd`** — the enlarged confirm must still fit a
  20:9 phone.
- Part C is docs-only — no test.

Run targeted suites (`test_run(suite=...)`), not the full run, per CLAUDE.md's
cost guidance; budget one editor restart if a full run is taken at the end.

## Files touched

- `Scripts/LevelSelect/LevelSelect.gd` — fan `@export` defaults (A).
- `Scenes/LevelSelect/LevelSelect.tscn` — possibly the fan / confirm nesting.
- `Scenes/LevelSelect/AmplopCard.tscn` — `PaperShadow` child, tab offset (A, D).
- `Scripts/LevelSelect/OpenAmplopConfirm.gd` — zoom `@export`s + open tween (B).
- `Scenes/LevelSelect/OpenAmplopConfirm.tscn` — bigger letter/buttons, shadow
  (B, D).
- `tests/test_level_select.gd` — new source-scan assertions.
- `docs/superpowers/specs/2026-09-28-week-length-rebalance-proposal.md` — new (C).

Nothing in `Balance.gd`. Nothing in the shared `PaperShadow` defaults.
