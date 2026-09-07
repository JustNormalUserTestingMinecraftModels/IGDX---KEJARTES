---
name: motion-lab
description: Use when tuning how a UI element or asset animates in this Godot project - easing, transition curve, duration, overshoot. Opens an in-browser easing editor with a live preview, then patches the chosen Tween preset into the named call site. Trigger on "tune the animation", "change the easing", "make it bouncier", "adjust the transition", or a named node plus a request about how it moves.
---

# Motion Lab

An in-browser easing editor for this project's Godot Tween motion. The user
names an element and a scene; this skill finds what animates it, opens a
tuning page in the browser, and patches the chosen preset back into the real
call site. Everything the page previews is a native Godot `Tween` preset —
`set_trans()` / `set_ease()` / a duration — so there is no gap between what
the page shows and what the engine plays.

Full design rationale: `docs/superpowers/specs/2026-09-05-motion-lab-skill-design.md`.
Build plan and task history: `docs/superpowers/plans/2026-09-05-motion-lab-skill.md`.

## 1. Resolve the target

The user names a node and a scene, e.g. "the Lanjut button's reveal in
EndCutscene". Steps:

1. `grep -n "<node name>" Scenes/**/<scene>.tscn` to confirm the node exists
   and find its path within the scene tree.
2. Read the scene's attached script (the `.tscn`'s `[node]` block for the
   scene root names it, or `script_manage`/`node_get_properties` if easier).
3. `grep -n "<node>\|Juice\.\|AnimUtils\.\|create_tween" <script>` to find
   what animates it.

Report the file, the line, and the current transition, ease, duration and
travel **before** publishing anything. If several tweens touch the node, list
every candidate with its line number and ask which one — never guess which
tween the user means.

## 2. Check the guard rail

If the animation comes from a helper shared across screens, patching it in
place would silently restyle every element in the game that uses it, not just
the one the user asked about. Stop and offer the choice explicitly — do not
pick one unilaterally:

- **retune globally**, accepting every consumer changes, or
- **add a parameter** to the helper, defaulted to the current value, so only
  the named element moves.

The shared helpers to watch for:

- `Scripts/Design/Juice.gd` — `Juice.press`, `Juice.release`, `Juice.pop_in`,
  `Juice.fade_in`, `Juice.stagger_in`, `Juice.shake` (also `count_up`,
  `count_up_formatted`, `fill_bar`, `set_pivot_center`, none of which carry
  their own easing).
- `Scripts/AnimUtils.gd` — all 25 of its static functions, notably
  `AnimUtils.squash_bounce`, `AnimUtils.spring_pop_in`,
  `AnimUtils.spring_pop_out`, `AnimUtils.popup_spring_in`,
  `AnimUtils.popup_spring_out`, `AnimUtils.back_bounce`, `AnimUtils.wobble`.

A tween written directly in the target's own script (a `create_tween()` call
that belongs to that scene alone) is not shared — no need to stop for those.

### 2b. Targets with no animation yet

If nothing currently animates the node, this is authoring, not tuning — say so,
then proceed. The result must still be a `Juice.*` helper call or a documented
tween in the scene's own script, never a `theme_override_*`
(`CLAUDE.md`, "Visual system"), and the tuned numbers land in a named `const`
block or an `@export`, never inline (`CLAUDE.md`, "Conventions"). Publish the
lab with the property the user wants animated and sensible defaults
(`QUAD`/`OUT`, `dur_normal` = 0.32s).

## 3. Publish the lab

Read `assets/editor.html` and apply both substitutions:

| Marker (with its default expression) | Replaced with |
|---|---|
| `const EASING = /*__GODOT_EASING_TABLE__*/ null;` | the entire contents of `assets/godot-easing.json`, verbatim |
| `const TARGET = /*__MOTION_LAB_TARGET__*/ { ... };` | a flat JSON object literal: `{element, scene, property, trans, ease, duration, travel}` from the resolved target |

Both substitutions replace the marker text together with the default
expression that follows it on the same line — the marker alone is not a valid
splice point. `property` is one of `"scale" | "fade" | "slide" | "fill"`,
matching whichever CSS-visible property the resolved tween actually animates
(a `scale` tween → `"scale"`; `modulate:a` → `"fade"`; `position`/`offset_*` →
`"slide"`; a `Range.value` fill (`Juice.fill_bar`, a progress bar) →
`"fill"`).

Write the substituted HTML to the session scratchpad, then publish it with the
Artifact tool: title **Motion Lab**, favicon `🎢`, and a `description` naming
the element being tuned (e.g. "Tuning the Lanjut button's reveal in
EndCutscene"). To keep one URL across sessions rather than accumulating a new
artifact each time: first run `action: "list"` and look for an existing
*Motion Lab* artifact; if one exists, publish with its `url` (read it first,
per the Artifact tool's update flow) rather than omitting `url`. Only create a
fresh artifact when none exists yet. Hand the user the link.

## 4. Parse the token

The page's Copy button produces a line shaped like:

```
KJT-MOTION v1 | BACK/OUT | 0.320s | travel 0.90 | scale | Lanjut@EndCutscene.tscn
```

Split on `|` and trim whitespace from each of the six fields. Refuse the token,
stating the reason, when any of these hold — a refused token is never
partially applied:

- the first field is not exactly `KJT-MOTION v1` (a different version number
  means this skill's parser and the page that produced it have drifted; do
  not guess at compatibility);
- there are not exactly six fields;
- the `TRANS/EASE` field does not name one of Godot's 12 transitions or 4
  eases (see the list in `tests/test_easing_table.gd`'s `_TRANSITIONS`/`_EASES`
  constants);
- the trailing `element@scene` field does not match the target currently under
  discussion — this catches a stale token pasted from an earlier round being
  applied to the wrong element.

The user may paste several tokens at once (one per line); parse and apply each
independently.

## 5. Patch

At the resolved call site, rewrite the transition, ease and duration:

- `set_trans(Tween.TRANS_<name>)` and `set_ease(Tween.EASE_<name>)` from the
  token's `TRANS/EASE` field.
- The duration: if it equals one of `design_tokens.tres`'s Motion group values
  (`dur_instant` 0.08, `dur_fast` 0.18, `dur_normal` 0.32, `dur_slow` 0.55),
  emit `Juice.tokens().dur_<name>` rather than a bare float, matching how the
  rest of the codebase references these durations. Otherwise put the number in
  a named `const` on the scene's script, or an `@export` if the scene already
  exposes its other tuning knobs that way (follow the pattern the surrounding
  script already uses).
- The travel value, if the call site has an explicit starting value to change
  (e.g. a spring-in's starting scale) — otherwise it only informed the
  preview's stand-in and has nothing to patch.

Use `script_patch` for the edit (never a plain file write — Godot's editor
cache serves stale bytecode for scripts edited outside it; see `CLAUDE.md`,
"Working efficiently here", rule 5). Then run `test_run()` for the whole suite
— not just whatever suite covers the target scene, since a shared-helper
change (§2) can affect other suites — and report the result.

## 6. Maintenance

`assets/godot-easing.json` is ground truth sampled from Godot's own
`Tween.interpolate_value()`, owned by `tests/test_easing_table.gd`. If a future
Godot upgrade changes an easing curve, that suite's
`test_checked_in_table_matches_the_engine` will fail, naming exactly which
curve drifted and by how much. To rebake deliberately: delete
`assets/godot-easing.json` and run `test_run(suite="easing_table")` twice —
once to regenerate it (the test fails on purpose, reporting "generated —
re-run"), once to confirm the fresh table matches itself.
