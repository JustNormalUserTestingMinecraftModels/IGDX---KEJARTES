# Motion Lab — an in-browser easing editor as a project skill — design

**Date:** 2026-09-05
**Status:** Approved

## Problem

Tuning motion in this project is a blind loop. There are 294 `set_trans` /
`set_ease` call sites across `Scripts/`, spread over 8 transition families
(`TRANS_QUAD` 109, `TRANS_BACK` 67, `TRANS_SINE` 34, `TRANS_CUBIC` 27,
`TRANS_SPRING` 10, `TRANS_LINEAR` 6, `TRANS_ELASTIC` 1, `TRANS_BOUNCE` 1), and
the only way to judge a change is to edit a number, run the game, reach the
screen, and watch. Godot's own editor has no scrubbable easing preview for
tween code — its curve editor is for `Curve` resources and animation tracks,
neither of which this project uses for UI motion.

The result is that motion is picked from memory rather than seen. `TRANS_QUAD`
dominating the codebase 2:1 over everything else is the symptom: it is the
default anyone reaches for without a way to compare.

There is no built-in animation editor inside Claude Code. There is the Artifact
tool, which publishes an interactive HTML page to a private URL — enough to
build the missing editor and drive it from a skill.

## Design

A project skill, `.claude/skills/motion-lab/`, holding a checked-in HTML editor.
Invoking it publishes that editor as an Artifact, the user tunes in the browser,
pastes one line back, and Claude patches the Godot call site.

```
.claude/skills/motion-lab/
  SKILL.md                    the workflow
  assets/editor.html          the editor page (checked in, not regenerated)
  assets/godot-easing.json    curve data sampled from Godot itself
```

### Decisions taken during brainstorming

| Question | Decision | Rejected |
|---|---|---|
| What lands in Godot | **Native `Tween` presets** — `set_trans`/`set_ease` + duration | Baked `Curve` .tres with a new sampling helper; a hybrid of both |
| How a target is named | **User names the node in a `.tscn`**, Claude resolves its animation | Editing named motions in `Juice.gd`; browsing a live scene over MCP |
| Browser → Claude | **Copy a one-line token, paste into chat** | Artifact database write-back; artifact-asks-Claude |
| Preview contents | **Ball on the curve + a stand-in doing the real property** | Ball alone; a grid comparing many presets at once |
| Intensity slider | **Walks the strength ladder, or scales travel** | Travel only; duration only |
| Skill scope | **Project skill, KejarTes-aware** | Global generic skill; global skill plus repo config |

Native presets are the load-bearing choice. Because the output is a
`(transition, ease, duration)` triple and nothing else, what the browser previews
is arithmetically identical to what the engine plays — there is no approximation
step between the editor and the game, and no second motion path to maintain
alongside the `Tween` one every existing script uses.

### Workflow

1. **The user names a target** — e.g. *"the `Lanjut` button in
   `EndCutscene.tscn`"*.
2. **Claude resolves it.** Grep the `.tscn` for that node, read its attached
   script, and locate what animates it: a `Juice.*` call, an `AnimUtils.*` call,
   or a raw `create_tween()` chain. Report the file, the line, and the current
   transition / ease / duration / travel before opening anything.
3. **Claude publishes the lab.** Inject a `TARGET` block into `editor.html`
   (element name, scene, animated property, current values), publish, hand over
   the URL.
4. **The user tunes and pastes the token.**
5. **Claude patches that call site**, runs the suite, reports.

### Guard rail: shared helpers

If step 2 resolves to a helper shared across screens — `Juice.press`,
`Juice.pop_in`, `AnimUtils.squash_bounce` — patching it in place silently
restyles every element in the game that uses it. Claude stops and offers the
choice explicitly:

- **retune globally**, accepting that every consumer changes, or
- **add a per-call parameter** with the existing value as its default, so only
  the named element moves.

Neither is chosen unilaterally.

### Targets with no animation yet

If the named node has no animation at all, this is authoring rather than tuning.
The house rules still hold: the result is a `Juice.*` helper or a documented
tween in the scene's own script, never a `theme_override_*`, and the tuned
numbers land in a named `const` block or an `@export` rather than inline
(`CLAUDE.md`, Conventions).

## The editor page

One HTML file, everything inline, no external scripts. Published as an Artifact,
so it is private by default and reachable at a stable URL.

| Region | Contents |
|---|---|
| **Preset grid** | All 12 transitions × 4 eases, the current pick lit |
| **Curve graph** | Time → progress plot with a playhead. The band above 1.0 and below 0.0 is drawn explicitly so `BACK`, `ELASTIC` and `SPRING` read honestly instead of clipping |
| **Preview** | A ball travelling top→right along the curve, beside a stand-in element performing the real property change |
| **Controls** | Intensity, Duration, Travel, Replay, Loop |
| **Token bar** | The one-liner, monospace, with a Copy button |

### The preview

Two things run off the same clock, restarting together on every parameter change:

- **The ball** — travels top→right, position driven by the curve. It reads the
  curve's *shape*: where it hangs, where it snaps, whether it overshoots.
- **The stand-in** — a mock of the actual element performing the actual property
  change. Which one is shown follows the resolved target: `scale` (pop /
  squash), `modulate:a` (fade), `position` (slide), or `value` (bar fill). It
  answers whether the curve feels right on a *button*, which the ball cannot.

### The intensity slider

Godot exposes no overshoot constant on `Tween`, so a single slider has to mean
two different things depending on the family:

- **Smooth families** (`LINEAR`, `SINE`, `QUAD`, `CUBIC`, `QUART`, `QUINT`,
  `EXPO`) — the slider walks that ladder in order. Each step is a strictly
  steeper curve, which is the same sensation as dragging a bezier handle
  outward, while every stop remains a real Godot preset.
- **Fixed-shape families** (`BACK`, `ELASTIC`, `BOUNCE`, `SPRING`, `CIRC`) —
  the shape cannot change, so the slider scales **travel** instead: the distance
  the property covers, e.g. a pop starting from 0.90 versus 0.80.

The graph redraws live in both modes. The slider's current meaning is labelled
on screen, so the two behaviours are never ambiguous.

### Duration

A slider from 0.02 s to 2.0 s with snap ticks at this project's own motion
tokens, read from `Assets/Theme/design_tokens.tres` at authoring time:
`dur_instant` 0.08, `dur_fast` 0.18, `dur_normal` 0.32, and the remaining
`dur_*` values in that resource. Snapping is a nudge, not a constraint — any
value in range is selectable, but landing on a token is one pixel of magnetism
away, because a duration that matches a token can be emitted as
`Juice.tokens().dur_fast` rather than a bare float.

### The token

```
KJT-MOTION v1 | BACK/OUT | 0.320s | travel 0.90 | scale | Lanjut@EndCutscene.tscn
```

Pipe-separated, human-readable, and it echoes the target back. Claude refuses a
token whose target does not match the element under discussion, which makes
pasting a stale token from an earlier round a caught error rather than a silent
misapply. Several tokens may be pasted at once.

The `v1` is a format version. A token from a future version the skill does not
recognise is refused rather than parsed optimistically.

## Fidelity: driven by Godot's own numbers

The page does not re-implement Penner easing in JavaScript. A test samples
Godot's static `Tween.interpolate_value()` for all 48 transition × ease
combinations at 256 points across `t ∈ [0, 1]` and writes
`assets/godot-easing.json`; the page reads that table and interpolates linearly
between samples.

This removes the largest failure mode in a tool of this kind — a preview that
looks right in the browser and plays differently in the engine — by deleting the
second implementation entirely. 48 × 256 floats is roughly 60 KB inline, far
inside the Artifact size budget.

Generating the table needs the editor attached, since `test_run` is the only
route to live engine calls. This follows the documented pattern for headless
`EditorScript` work in `CLAUDE.md` ("Working efficiently here", rule 5): a
`@tool` `McpTestSuite` does the work and `test_run` executes it.

## Testing

`tests/test_easing_table.gd` — permanent, not transient. It re-samples
`Tween.interpolate_value()` for all 48 combinations and asserts the checked-in
`godot-easing.json` still matches within `1e-5`. A Godot upgrade that changes an
easing curve then fails loudly here, rather than silently desyncing every future
preview.

The suite is `@tool` and contains no coroutine, per the two hard constraints in
`CLAUDE.md`.

The skill's own files live under `.claude/skills/`, outside `Scripts/`, so they
are untouched by `tests/test_script_documentation.gd` and
`tests/test_viewport_editability.gd`. Any GDScript this skill later *writes* into
`Scripts/` is ordinary project code and is bound by both ratchets as usual.

## Session-to-session reuse

Artifacts published to the same file path share a URL only within one session.
Across sessions, `SKILL.md` instructs Claude to list the user's artifacts, find
the one titled *Motion Lab*, and republish to that URL — so the lab keeps one
address instead of accumulating a new one per invocation.

## Out of scope

- **Free bezier handles and baked `Curve` resources.** Rejected in favour of
  native presets; revisit only if a real animation cannot be expressed by any of
  the 48 combinations.
- **Live preview inside the Godot editor.** The MCP bridge is single-client and
  screenshots are expensive; the browser page is cheaper and scrubbable.
- **Automated browser → Claude write-back.** Token paste only.
- **Retuning the whole codebase.** The skill tunes named targets. Sweeping all
  294 call sites is a separate exercise that would need its own spec.

## Risks

| Risk | Mitigation |
|---|---|
| `Tween.interpolate_value()` is not callable as a static method in 4.6 | Verified during implementation before anything depends on it. Fallback: an instanced `Tween` sampled through `tween_method`, or a `SceneTreeTimer`-free direct call, decided at that point |
| The editor page grows unmaintainable | It is checked in and edited like source, not regenerated per invocation. Sections are separated and the file is expected to stay under ~700 lines |
| A resolved call site is ambiguous (several tweens on one node) | Claude reports every candidate with its line number and asks which one, rather than guessing |
