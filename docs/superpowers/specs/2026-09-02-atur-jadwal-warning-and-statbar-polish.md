# AturJadwal Warning Frame & BGStat Bar Polish — What Shipped

**Date:** 2026-09-02
**Branch:** `sticky-note-polish`
**Plan:** `docs/superpowers/plans/2026-09-02-atur-jadwal-warning-and-statbar-polish.md`
**Commits:** `9394147..c392e2e` (6, plus the prep commit `2efca8d`)

## The request

Two things, in the user's words: replace the PERINGATAN dialog's "weird
looking" placeholder texture with `penjadwalan_card_bg.png`, and make the
five BGStat progress bars "more lively … more like a professional but it
stay and has a cute layouting, so the player's eye is comfortable", keeping
the icons beside them because those are final art.

## What shipped

**The warning dialog.** `Peringatan/TextureRect` is now a `NinePatchRect`
drawing `penjadwalan_card_bg.png`. The art is a 658×1013 rounded card with a
~20 px corner radius sitting inside a 1080×1080 canvas, so the node needs a
`region_rect` of `Rect2(211, 34, 658, 1013)` as well as 32 px patch margins:
without the crop the card renders small inside transparent padding, without
the margins its corners smear into the 740×428 frame. The node keeps its
name, so `atur_jadwal.gd`'s six `$Peringatan/TextureRect/...` lookups still
resolve.

The swap made the dialog's own text unreadable — `BarLabel` is a white glyph
with a dark rim, meant for text on a saturated progress fill, and the new
card is light cream — so the label moved to `TitleLabel`. Its
`offset_bottom` also dropped from 400 to 268, because the last line of the
warning had been rendering underneath the YA/TIDAK buttons.

**The stat bars.** Three separate things, in the order they were found:

1. `StatBar._sync_label()` built a `ValueLabel` unconditionally, but
   AturJadwal authors five and ReportCard about thirty. Every one of those
   bars was rendering two overlapping labels, with the authored one frozen
   at its design-time "0%" underneath the live one. It now adopts an
   authored child instead.
2. The `StatBar` theme track gained the project's sticker chrome — white
   rim, soft drop shadow, and a `content_margin` inset so a rail of track
   stays visible at 100%. All from existing `DesignTokens` values; no new
   export, so no editor restart.
3. **The one that mattered most.** `StatBar` tinted via `self_modulate`,
   which multiplies the *whole* node — so the sunken track and the new white
   rim took the category colour too, and a bar at value 0 rendered as a
   solid capsule that looked 100% full. `ThemeFactory` now emits one
   `StatBar` variation per category with the colour baked into the fill
   stylebox (the same approach it already used for the DaySummary tracks),
   and `_apply_tint` selects the variation and leaves `self_modulate` white.

**Motion.** A bar whose value moves gives a scale-only squash-bounce
(`AnimUtils.squash_bounce`, opt-in via a new `pop_on_change` export, off by
default so SemesterEnd and ReportCard are unaffected). The five rows stagger
in with their icons when the displayed student changes. The icons never
move: `_stagger_stat_rows` animates opacity and scale only, and a test
forbids it from writing any `offset_*` or `position`.

## Deviations from the plan

Every one of these is a decision recorded in the execution ledger at
`.superpowers/sdd/2026-09-02-atur-jadwal-warning-and-statbar-polish/progress.md`.

- **`region_rect` added** (Ruling T1-a). The plan assumed a thick decorative
  border and did not know about the art's transparent padding.
- **Label variation and geometry changed** (Ruling T1-b). Consequences of the
  texture swap, so they belong to that task rather than a follow-up.
- **`AnimUtils.squash_bounce` instead of `Juice.pop_in`** (Ruling PF-2).
  `pop_in` sets `modulate.a = 0.0` and tweens it back, which would blink the
  bar *and its value label* transparent on every change — a flash, not a pop.
- **The stagger is gated on the student id actually changing** (Ruling PF-3).
  `_update_student_display()` runs on every activity assignment, so the
  plan's unconditional placement would have re-faded the whole panel on
  every tap.
- **Task 3b added** (Ruling T3-b) — the per-category variations. Without it
  the plan's rail and rim work was invisible and the bars still read as
  solid blocks, which was the user's actual complaint.
- **A Task 4 fix round** — the stagger and the per-bar pop both animated
  `scale` on the same five nodes with independently-tracked tweens. `set_stat`
  gained an optional `pop` flag so the stagger owns the motion on a switch
  and the pop owns it on an edit.
- **No git worktree** (Ruling PF-0). The Godot editor is bound to this
  project directory and every scene, rebake and test operation runs through
  it.
- **Finding abandoned** (Ruling T3-d): clearing the dead `self_modulate`
  lines from `student_card.tscn` and `report_card.tscn`. See the hazard below.

## Two hazards worth remembering

**A `@tool` script can rewrite authored scene data on save.** Opening
`report_card.tscn` in the editor and saving it persisted `_sync_label`'s
output into the file: all 30 `ValueLabel`s gained `visible = false`, their
authored text "65/65" became "60", and their alignment flipped from right to
centre. The scene's own `uid` changed too. The file was reverted and
`_sync_label` now manages a label only when `show_value_label` is true, and
never overwrites author-owned properties on an adopted label.
`Engine.is_editor_hint()` is *not* the right guard here — this project's test
suites run inside the editor, so that flag is true during tests and the gate
would disable the behaviour under test.

**A scan does not always reload a `.gd`.** When a script is edited from
outside the editor, `filesystem_manage(op="scan")` can leave the old
bytecode loaded: new tests fail spuriously and a new `@export` is invisible
to `node_set_property`. A no-op `script_patch` on the same file forces the
reload. Both hazards are now written up in `CLAUDE.md`.

**The on-change squash-pop is tight against the icon column.** The pop peaks
at scale `(1.18, 0.85)` about a centred pivot, and the bars are 324px wide
(`offset_left` 649 to `offset_right` 973), so the horizontal peak grows
±29.2px per side. `IconAkademis1` ends at x=611, leaving a 38px gap to the
bar's left edge — the pop clears the icon by only about 8.8px, for roughly
0.07s. That's fine today, but it's a real constraint: widening the bars or
moving the icon grid closer needs to keep this clearance in mind, or the pop
will visibly overlap the icon.

## Verification

Full suite: **604 passed, 1 failed**. The single failure is
`project_hygiene::test_every_scene_ext_resource_uid_resolves_to_its_own_asset`,
which failed identically before this work started — every offending
`.gd.uid` on disk matches the UID its scene references, so the repo is
correct and the editor's UID cache is stale (Ruling PF-6). It needs an editor
restart, not a code change. `test_viewport_editability` is 2/2 with its
`BASELINE` untouched.

Beyond the suite, the result was checked in a **live game build**, reading
the real nodes rather than trusting a screenshot:

- **AturJadwal** — five bars, exactly one `Label` each, correct per-category
  variation, white `self_modulate`, live values (54/80/72/55/60 percent).
- **StudentCard** — all 30 pills keep `variation = StatPill` and their
  category `self_modulate`, confirming the `StatPill` path was not broken.
- **ReportCard** — authored `ValueLabel`s intact: visible, "65/65",
  right-aligned.

## Known deferred items

- `show_value_label` true → false → true does not round-trip: `_sync_label`'s
  early return no longer hides an existing label. Latent — no caller toggles
  the flag at runtime; it is fixed at scene-authoring time.
- The `ReportCard` and `StudentCard` editor previews still show the old
  solid-capsule-at-zero rendering until the editor is restarted, because the
  editor holds a cached `Theme` instance. Runtime is correct.
