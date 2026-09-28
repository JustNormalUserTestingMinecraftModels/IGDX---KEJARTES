# Level Selection Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

> **Revision (2026-09-28): clean-code pass.** Brought in line with
> `docs/superpowers/design/clean-code.md` and checked against the code as it
> is on `level-selection-polish`:
> - Global Constraints gained a **Clean code** block, and a **Baseline debt**
>   section says exactly which lines carry this plan's files' ratchet debt and
>   why no task has to pay it (with the fix and expected baseline diff for
>   whoever does touch `AmplopCard.open()`).
> - Every step is tagged **[editor]** (needs the live editor through the
>   godot-ai bridge; the controller does it) or **[code]** (plain file edits
>   a subagent can do). The steps inside Tasks A, B and D are reordered so the
>   scene work comes first and the script and test work second (CLAUDE.md 4b).
>   Task numbers are unchanged.
> - Task B's `play_open()` / `dismiss()` change is now a written, typed
>   snippet: named `@export`s, its own `_zoom` tween, and a remembered rest
>   scale (the confirm never knew `card_scale`; `LevelSelect` pushes it down).
>   Its `$Letter/Margin/VBox/...` paths become `%UniqueName`s.
> - Each code task's test step also runs `clean_code` (and
>   `script_documentation` where an `@export` is added). Task E runs the dump
>   tool if a count shrank and checks the baseline diff.
> - Fixes where the plan disagreed with the codebase:
>   - `test_run(suite=...)` takes the suite's `suite_name()`, not the file
>     name: `level_select`, `paper_shadow`, `tall_screen_layout`,
>     `clean_code`. `"test_level_select"` matches nothing.
>   - Buttons: Accept is `PrimaryButton` and Cancel is `SecondaryButton`
>     (there is no `DangerButton`). Their `Buttons` HBox is already 128px
>     tall, so they already clear the 96–112px target.
>   - `Title` is already `H2Label`, so the next step up is `H1Label`.
>     `Body` has no variation.
>   - `Letter` is a `Card` **Panel** (a StyleBoxFlat that already casts the
>     token drop shadow). It has no texture, so a `PaperShadow` has nothing to
>     cast. D2 is now a decision for the human.
>   - The amplop shadow moves from "backmost child of `Bob`" to the first
>     child of `Bob/Body`, named `Shadow`. That is the project's
>     contact-shadow convention, and `open()` does `bob.move_child(_flap, 0)`
>     meaning "behind the pupils", which a new index-0 node in `Bob` would
>     silently break.
>   - `PaperShadow` has 20 instances today, not 13.
>   - No Debug > Scenes teleport exists for LevelSelect. Route: MainMenu, then
>     tap (`GameState.debug_level_select_enabled` defaults to true).
>   - Moving the `Tab` changes the `84.0` tab height that
>     `test_envelopes_are_enlarged_and_clear_the_header` and the `HitButton`
>     rect hardcode.
>   - Growing `Letter` means moving `Buttons` too: they are siblings on fixed
>     offsets.
>   - `Confirm` is not under `Safe` (SafeAreaMargin). It is a full-rect last
>     child, and `test_tall_screen_layout` pins it that way.
>   - `open_scale_target = 1.9` overflows the top of the screen at the
>     `Envelope`'s current anchor. Task B, Step 7 checks it.

**Goal:** Polish the shipped amplop coklat level select — de-crowd the fan, make
"Buka Map Ini" zoom the chosen envelope up onto a large thumb-friendly confirm,
add soft drop shadows — and write a week-length rebalance **proposal** for the
`Balance.gd` owner (no balance edit here).

**Architecture:** Presentation-only changes to the existing
`Scenes/LevelSelect/*` scenes and `Scripts/LevelSelect/*` scripts, plus one
markdown proposal. Reuses the existing `PaperShadow` component. No new runtime
visual construction; no `theme_override_*`; no `Balance.gd` diff.

**Tech Stack:** Godot 4.6, GDScript, `ThemeFactory` variations, Tweens,
`Scenes/UI/PaperShadow.tscn`, the `godot-ai` MCP bridge (scene/node/test tools),
`McpTestSuite` source-scan tests.

**Spec:** [`docs/superpowers/specs/2026-09-28-level-selection-polish-design.md`](../specs/2026-09-28-level-selection-polish-design.md)

**Reference screenshots (mentor review):** the two captures in the branch's PR
description — (1) the fan at rest showing the sliced side tabs, (2) the opened
confirm showing the small envelope + small surat tugas. Land Part A and B by eye
against these, and send the human a before/after.

## Global Constraints

Copied from the spec, CLAUDE.md and `clean-code.md`. Every task implicitly
includes these.

- **No `theme_override_*`.** Use `ThemeFactory` type variations; add one +
  rebake (`Scripts/Design/BakeTheme.gd` via Ctrl+Shift+X) if none fits.
  Layout-only constant overrides (`separation`, `margin_*`) are the only
  exception (`custom_minimum_size` is a plain property, not an override).
  A new variation drawn in Boohong must also join `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd`. Rebake on its own, restart, and diff the bake
  before committing (never beside scene ops).
- **No visual built at runtime.** Static chrome = `.tscn` nodes; responsive
  geometry = `@tool` script with documented `@export` knobs.
  `test_viewport_editability.gd` is a one-way ratchet — do not add to `BASELINE`.
- **Every script `@tool`**, `##` file header, `##` on every `@export`
  (`test_script_documentation.gd`).
- **`@export`s on the instance ROOT, never children** — child overrides drop on
  save (CLAUDE.md 4b). The `PaperShadow` knobs live on its instance root.
- **`Balance.gd` is read-only for us.** Weeks/target are read, never re-typed.
  Task C writes a proposal, not a `Balance.gd` edit.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` → `node_create`/`node_set_property`/`batch_execute` →
  `scene_save`. **Scene work first, script work second** — test files count as
  script work (an open script tab is written back on every `scene_save`).
  After every `scene_save`, `git diff HEAD -- '*.gd'` must show nothing you did
  not edit, and `git diff` of the saved scene must show only your change (the
  `@tool` fan re-bakes the cards' `offset_*`/`rotation`/`scale` into
  `LevelSelect.tscn` whenever it is saved; that bake is expected noise, a
  `fan_*` line is not). After patching a `.gd`, restart the editor before the
  next `scene_save`.
- **Step tags.** **[editor]** = needs the live editor through the godot-ai
  bridge (`scene_open`, `node_*`, `batch_execute`, `scene_save`, `test_run`,
  `editor_screenshot`, `project_run`, `script_patch`). The controller session
  does these; the bridge is single-client, so a subagent must never connect.
  **[code]** = plain file edits, reading, or git, which a subagent can do. A
  `.gd` a subagent wrote from outside the editor is stale in the editor until
  the controller does a **no-op `script_patch`** on it (a `scan` is not
  enough), before any `test_run`.
- **Verify visuals with the human.** A small editor screenshot is not proof a
  design change is done — capture at full size and send before/after; the human
  checks against reference before it's "done".
- **Indonesian** game-facing text; English systems code. **Conventional
  Commits** with scope, e.g. `feat(level-select): de-crowd the amplop fan`.
  Commit at the end of every task.

### Clean code (`docs/superpowers/design/clean-code.md`; ⚙ = ratcheted)

- **Type everything ⚙.** Every `var` gets `: Type` or an obvious `:=`. Every
  function gets `->` (including `-> void`), and every parameter a type. A
  Variant right-hand side (`peeks[i]`, `dict[key]`) is named with `: Type`.
- **No magic numbers ⚙.** Only `0`, `1`, `2`, `-1` and `0.5` may appear bare in
  a function body. Put a logic value in a named `const` block at the top of the
  script that owns it, with a `##` line. Put a designer-tuned value (a knob the
  spec calls tunable: fan geometry, `open_scale_target`, `open_zoom_sec`) in an
  `@export` with a `##` line. Put layout numbers (sizes, offsets, margins,
  shadow offset/alpha/blur) in the `.tscn`, never in code. Keep values
  identical when you move them.
- **One job per function ⚙,** ≤ 50 code lines. Extract a named step rather
  than growing `play_open()`/`dismiss()`. No duplicated 5+-line body across
  files ⚙. Reuse a helper (`set_envelope_scale`) instead of re-typing it.
- **Flat, not nested:** guard clauses and early `return`; `match` for a switch.
- **Signals up, calls down.** The confirm announces `accepted`/`cancelled` and
  never reaches into `LevelSelect`. `LevelSelect` calls down
  (`_confirm.set_envelope_scale(card_scale)`), which is why the confirm
  remembers the rest scale it was given instead of reading `card_scale`.
- **Node refs once, via `@onready ... = %UniqueName`,** for every node a
  script touches, so restructuring the scene cannot break the script.
- **Fail loudly:** a missing required node is a `push_error` (or the engine's
  own `@onready` error), never a silent `get_node_or_null` skip.
- **No commented-out code**; comments say *why*.
- **Boy Scout rule:** any function a task touches ends no longer and no less
  typed than it started, with its bare numbers named.
- **The ratchet stays green.** Every code task runs
  `test_run(suite="clean_code")` beside its own suite. "grew" → fix the code
  (never raise the baseline). "shrank" → lock it in, in the same commit:

      & "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd

  (PowerShell, from the project root). Check that `git diff
  ci/clean_code_baseline.gd` only lowers or removes. Then do a no-op
  `script_patch` of `ci/clean_code_baseline.gd` so the editor serves the new
  baseline, and re-run `clean_code`. An un-locked shrink fails the editor
  suite.

### Baseline debt in the files this plan touches

The scan counts bare numbers only inside function bodies (not class-level
`const`/`@export` lines, not property `set:` blocks), and untyped `var`s
anywhere.

| File | Baseline | Where | Touched here? |
|---|---|---|---|
| `Scripts/LevelSelect/LevelSelect.gd` | 6 bare numbers | the `8:` / `9:` match arms of `weeks_for()` (L78–79), `target_for()` (L86–87), `_gauge_color()` (L234–235) | **No.** Task A changes only class-level `@export` defaults, which the scan does not read. No payoff owed. Expected baseline diff: none. |
| `Scripts/LevelSelect/AmplopCard.gd` | 1 untyped | `var peek = peeks[i]` in `open()` (L106) | **No**, with the shadow as a child of `Bob/Body` (Task D). No payoff owed. |
| `Scripts/LevelSelect/OpenAmplopConfirm.gd` | none | — | Task B adds code; it must stay at zero. |

If an executor does touch `AmplopCard.open()` for any reason, the Boy Scout
rule makes the untyped `peek` theirs to pay. Add
`const _PUPIL_PEEK := preload("res://Scripts/LevelSelect/PupilPeek.gd")` to the
const block, write `var peek: _PUPIL_PEEK = peeks[i]`, and drop the "untyped for
its own members" comment. Then `clean_code` reports "shrank". Run the dump and
expect exactly one baseline change: the `"res://Scripts/LevelSelect/AmplopCard.gd": 1`
line leaves `UNTYPED`.

---

## Task 0: Orient (no code)

**Files:** none — read only.

- [ ] **Step 1 [code]:** Read the spec above end-to-end, and
      `docs/superpowers/design/clean-code.md`.
- [ ] **Step 2 [editor]:** Open `Scenes/LevelSelect/LevelSelect.tscn` in the editor
      (`scene_open`). It is the main-flow screen reached from MainMenu while
      `GameState.is_level_select_enabled()`. Take a full-size `editor_screenshot`
      of the fan at rest — this is your Part A "before".
- [ ] **Step 3 [code]:** Read `Scripts/LevelSelect/LevelSelect.gd`,
      `Scripts/LevelSelect/AmplopCard.gd`, `Scripts/LevelSelect/OpenAmplopConfirm.gd`,
      and note:
      - the fan `@export` knobs (`fan_step_x` etc.);
      - how the confirm's `set_envelope_scale` / `play_open` / `dismiss` /
        `_rest_letter` work;
      - `AmplopCard.open()`'s `bob.move_child(_flap, 0)` (index 0 = behind the
        Pupils);
      - the variations in `OpenAmplopConfirm.tscn` today: Accept
        `PrimaryButton`, Cancel `SecondaryButton`, Letter `Card`, Title
        `H2Label`, Kicker `MicroLabel`, Body none.
- [ ] **Step 4 [code]:** Read `Scripts/UI/PaperShadow.gd` and the text of
      `Scenes/UI/PaperShadow.tscn`. The shape is two nodes: a root anchor with
      `show_behind_parent`, and `Silhouette`. You will instance it in Task D.
      Note the `match_source()` helper and `follow_parent_rect`. Also read the
      conventions `tests/test_paper_shadow.gd` pins: the shadow is its
      element's first child, the `shadow_texture` is the element's own
      texture, and a contact shadow is named `Shadow`.
- [ ] No commit (no file changes).

---

## Task A: De-crowd the amplop fan

**Files:**
- Edit: `Scripts/LevelSelect/LevelSelect.gd` (fan `@export` defaults only)
- Possibly edit: `Scenes/LevelSelect/AmplopCard.tscn` (Tab node offset, only if
  the centre tab still collides with the seal)
- Test: `tests/test_level_select.gd`

**Interfaces:** unchanged — same `@export` knobs, new default values. The layout
is driven by `_layout_cards()`, which already re-poses from these knobs in the
editor, so new defaults preview live. No function body changes, so no
clean-code debt moves.

Order: editor/scene work (Steps 1–3), then test and script work (Steps 4–5).

- [ ] **Step 1 [editor]:** In the inspector on the open `LevelSelect.tscn` root,
      move the fan knobs toward: `fan_step_x` ≈ 210–230, `fan_drop_y` ≈ 48,
      `fan_step_degrees` ≈ 10–12. Tune live against the Task 0 "before"
      screenshot until each side envelope reads as a whole tilted card and no
      tab edge is sliced by another body. Also check the `PrevArrow`/`NextArrow`
      at the Stack's edges stay readable. **Write the chosen numbers down and
      do not save `LevelSelect.tscn`:** the values belong in the script's
      defaults, not as scene overrides.
- [ ] **Step 2 [editor]:** If the centre "KELAS N" tab still overlaps the wax
      seal, nudge the `Tab` node's authored offset in `AmplopCard.tscn` through
      `scene_open` → `node_set_property` → `scene_save`, on the template, not
      per instance. A layout-only change. If the tab's height above `Bob`
      changes from 84px (`offset_top = -84`), also note:
      - the `HitButton`'s `offset_top = -610` (526 + 84) must still cover the
        tab. Move it in the same save.
      - `test_envelopes_are_enlarged_and_clear_the_header` hardcodes `84.0`
        (`tests/test_level_select.gd` ~L277). Step 4 updates it.
- [ ] **Step 3 [editor]:** Close `LevelSelect.tscn` **without saving**, or
      revert the knobs first. Then check `git diff` shows no
      `Scenes/LevelSelect/LevelSelect.tscn` change, and `git diff HEAD -- '*.gd'`
      is empty.
- [ ] **Step 4 [code]:** In `tests/test_level_select.gd` add a source-scan
      test asserting the script still exposes `fan_step_x`, `fan_drop_y`,
      `fan_step_degrees`, `side_scale` (guards against a knob being deleted).
      This is a light guard; the real acceptance is visual. If Step 2 moved the
      tab, update the `84.0` in
      `test_envelopes_are_enlarged_and_clear_the_header` to the new height. A
      better option is to read it from the card
      (`-(card.get_node("Bob/Tab") as Control).offset_top`), so it cannot go
      stale again. Keep the suite `@tool` and the test non-coroutine.
- [ ] **Step 5 [code]:** Persist the Step 1 numbers as the `@export`
      **defaults** in `LevelSelect.gd`. Change only the literal after `=` on
      `fan_step_x`, `fan_drop_y` and `fan_step_degrees` (class-level, typed
      `float`, `##`-documented already). Keep each setter block as it is. No
      value goes inline in `_layout_cards()`. Use `script_patch` if the
      controller does it. If a subagent does it, the controller follows with a
      no-op `script_patch`.
- [ ] **Step 6 [editor]:** Restart the editor (a patched script must not meet a
      later `scene_save`), reopen `LevelSelect.tscn`, full-size
      `editor_screenshot` "after". Send before/after to the human. Adjust on
      feedback. Any re-tune repeats Steps 1 and 5, never a scene save of the
      knobs.
- [ ] **Step 7 [editor]:** `test_run(suite="level_select")` and
      `test_run(suite="clean_code")`. Both green; `clean_code` reports no
      "grew" and no "shrank" (nothing in a function body changed).
- [ ] **Step 8 [code]:** Commit: `fix(level-select): de-crowd the amplop fan so side tabs read whole`.

---

## Task B: Zoom-in open + large mobile confirm

**Files:**
- Edit: `Scenes/LevelSelect/OpenAmplopConfirm.tscn` (bigger letter + buttons,
  unique names)
- Edit: `Scripts/LevelSelect/OpenAmplopConfirm.gd` (zoom `@export`s, open zoom,
  dismiss reset, `%` node refs)
- Possibly edit: `Scripts/Design/ThemeFactory.gd` (+ rebake) — only if no
  existing label variation fits
- Test: `tests/test_level_select.gd`

**Interfaces:**
- Produces on `OpenAmplopConfirm`: `@export var open_scale_target: float = 1.9`,
  `@export var open_zoom_sec: float = 0.35`.
- `play_open()` scales `envelope` from its rest scale (the `card_scale` that
  `LevelSelect` last passed to `set_envelope_scale()`) up to
  `open_scale_target`. It runs on its own `_zoom` tween, started beside the
  seal/flap/pupil tween, so the two run in parallel. `dismiss()` kills `_zoom`
  and puts the rest scale back. It uses its own tween because `card.open()`
  builds the returned tween, and a `tw.parallel()` added after it would join
  only its last (pupil) step.

Order: scene work (Steps 1–2), then test and script work (Steps 3–4), then
verification.

- [ ] **Step 1 [editor] (scene):** In `OpenAmplopConfirm.tscn`, through the
      bridge:
      - Enlarge `Letter` (a `Card` Panel, centre-anchored, today 800×240 at
        offsets −400/−30/400/210). Use its offsets/`custom_minimum_size` and
        more `Margin` padding (`theme_override_constants/margin_*`, allowed).
      - Move `Buttons` down by the same amount. They are a sibling on fixed
        offsets (250→378), not inside the Letter.
      - Promote `Title` from `H2Label` to `H1Label`, and give `Body` a larger
        existing body variation (check `ThemeFactory.gd`; e.g.
        `ResultBodyLabel`), with no `theme_override_*`. If none fits, add one
        in `ThemeFactory.gd` using token values only (no bare numbers), rebake
        **on its own**, restart, and diff the bake. A Boohong one joins
        `DISPLAY_ROSTER`.
      - `Accept` (Terima Tugas, `PrimaryButton`) and `Cancel` (Batal,
        `SecondaryButton`) keep their variations. The HBox is already 128px
        tall and they fill it, so they already clear the ≈ 96–112px tap
        target. Only set `custom_minimum_size.y` if a restructure shrinks
        them below it.
      - Tick **unique name** (`unique_name_in_owner`) on `Envelope`, `Card`,
        `Letter`, `Title`, `Body`, `Accept`, `Cancel`, so Step 4's script
        survives this restructure. `Card` is an instance ROOT, so its flag
        serialises.
      - `scene_save`. Then `git diff HEAD -- '*.gd'` is empty and the scene diff
        is only these changes.
- [ ] **Step 2 [editor]:** Check the enlarged confirm fits on a 20:9 phone
      (1080×2400) and at 1080×1920. `Confirm` itself is **not** under
      `Safe`/SafeAreaMargin. It is a full-rect overlay and the last child of
      `LevelSelect`, and `test_level_select_on_a_tall_phone` /
      `..._at_the_design_size` pin that. Leave it that way. If Letter+Buttons
      overflow, re-anchor them to the bottom edge inside a SafeAreaMargin
      *within* the confirm (see `test_tall_screen_layout.gd` and the authoring
      guide's "Tall phones"), and save.
- [ ] **Step 3 [code] (test):** In `tests/test_level_select.gd`:
      - Source-scan `OpenAmplopConfirm.gd` for `open_scale_target`,
        `open_zoom_sec` and `tween_property(envelope, "scale"`.
      - Behaviourally: `confirm.present(...)`, kill the returned tween, assert
        `confirm._zoom != null and confirm._zoom.is_valid()`. Then
        `confirm.dismiss()` and assert
        `is_equal_approx(confirm.envelope.scale.x, _screen.card_scale)`.
      Failing now. No `await` in a test.
- [ ] **Step 4 [code] (script):** In `OpenAmplopConfirm.gd`, values unchanged,
      everything typed, nothing bare:

      ```gdscript
      ## Final scale of the opened envelope: it surges from the fan's
      ## card_scale up to this, as if flying toward the player.
      @export var open_scale_target: float = 1.9
      ## Seconds the opened envelope takes to zoom up to open_scale_target.
      @export var open_zoom_sec: float = 0.35

      ## The envelope that opens: an AmplopCard shown for display (not interactive).
      @onready var card: Control = %Card
      ## The CenterContainer holding it. Size goes here, never on the card: a
      ## Container resets its children's scale every time it lays them out.
      @onready var envelope: Control = %Envelope
      @onready var _letter: Control = %Letter
      @onready var _title: Label = %Title
      @onready var _body: Label = %Body
      @onready var _accept: Button = %Accept
      @onready var _cancel: Button = %Cancel

      ## The envelope's resting scale: the fan's card_scale, pushed down by
      ## LevelSelect through set_envelope_scale(). Each open zooms from here and
      ## dismiss() returns to it; the confirm never reads LevelSelect.
      var _envelope_rest_scale := 1.0
      var _zoom: Tween


      ## Draw the envelope `rest_scale` times its template size, grown about its
      ## bottom-centre (the card's anchor, at the container's centre) so it rises
      ## away from the letter below instead of into it.
      func set_envelope_scale(rest_scale: float) -> void:
      	_envelope_rest_scale = rest_scale
      	envelope.pivot_offset = envelope.size * 0.5
      	envelope.scale = Vector2.ONE * rest_scale


      ## The open sequence: the envelope zooms toward the player while its own
      ## open() runs, then the letter rises in.
      func play_open(portraits: Array) -> Tween:
      	_rest_letter()
      	_zoom_envelope()
      	var home := _letter.position.y
      	# ...the existing body, unchanged...


      ## Reseal the envelope and hide, ready for the next present().
      func dismiss() -> void:
      	card.reseal()
      	_rest_letter()
      	_rest_envelope()
      	visible = false


      ## The zoom runs on its own tween so it starts with the seal, flap and
      ## pupils rather than after them; TRANS_BACK gives the "flies at you" snap.
      func _zoom_envelope() -> void:
      	_rest_envelope()
      	_zoom = create_tween()
      	_zoom.tween_property(envelope, "scale", Vector2.ONE * open_scale_target, open_zoom_sec) \
      		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


      ## Back to the fan's size, so a re-open replays the zoom from card_scale.
      func _rest_envelope() -> void:
      	if _zoom != null and _zoom.is_valid():
      		_zoom.kill()
      	set_envelope_scale(_envelope_rest_scale)
      ```

      `play_open()` grows by one line and `dismiss()` by one. Both stay far
      under 50. `set_envelope_scale`'s one-letter parameter `s` is renamed while
      touched (Boy Scout). `LevelSelect.gd` needs no change: it already calls
      `_confirm.set_envelope_scale(card_scale)` in `_ready()` and from
      `card_scale`'s setter.
- [ ] **Step 5 [editor]:** No-op `script_patch` on `OpenAmplopConfirm.gd` (and
      `tests/test_level_select.gd`) if a subagent wrote them. Then
      `test_run(suite="level_select")`, `test_run(suite="tall_screen_layout")`,
      `test_run(suite="script_documentation")` and `test_run(suite="clean_code")`.
      All green. `clean_code` shows no entry for `OpenAmplopConfirm.gd`. If a
      variation was added: `test_run(suite="theme_factory")` too.
- [ ] **Step 6 [editor]:** Restart the editor. Then run the game to the level
      select: MainMenu, then tap
      (`GameState.debug_level_select_enabled` defaults to true, so MainMenu
      wipes into LevelSelect; there is no Debug > Scenes entry for it). Tap
      Buka Map Ini and confirm three things: the envelope surges toward the
      player, the buttons are thumb-sized, and Batal → a second open replays
      the zoom from the fan scale. Take a full-size screenshot for the human.
- [ ] **Step 7 [editor]:** Check the zoom stays on screen. At the current
      anchors the card's bottom sits at y≈880 on a 1920 canvas, and the card
      plus tab is 610px of template height. At 1.9 that reaches ≈279px above
      the top edge, and the rising pupils go higher still. About 1.36 fits
      without moving anything. If it overflows, **ask the human**: lower
      `open_scale_target` (it is an `@export`, tune it and persist the new
      default like Task A's Step 5), or re-anchor `Envelope` lower and let the
      Letter overlap it (scene work: restart first, since Step 4 patched a
      script). Do not paper over it with an inline number.
- [ ] **Step 8 [code]:** Commit:
      `feat(level-select): zoom the opened amplop up onto a large mobile confirm`.

---

## Task C: Week-length rebalance PROPOSAL (docs only)

**Files:**
- Create: `docs/superpowers/specs/2026-09-28-week-length-rebalance-proposal.md`

**Do NOT edit `Balance.gd`.** This is a proposal for its owner. No code, so no
clean-code step.

- [ ] **Step 1 [code]:** Write the proposal doc containing:
      - the current weeks/target/rest-slack table;
      - the proposed 0.75× cut for Grades 8 and 9 (12→9 wk / +34→+26;
        16→12 wk / +40→+30; Grade 7 untouched);
      - the slack math showing felt difficulty is held;
      - an explicit statement that the edit is the collaborator's to make.

      Note that the level-select screen reads both numbers from `Balance.gd`
      (`LevelSelect.weeks_for()` / `target_for()`), so it updates for free
      once accepted.
- [ ] **Step 2 [code]:** Confirm `git diff` shows **no** change to `Scripts/Balance.gd`.
- [ ] **Step 3 [code]:** Commit: `docs(balance): propose shorter Grade 8/9 week lengths`.

---

## Task D: Drop shadows on the amplop cards + confirm

**Files:**
- Edit: `Scenes/LevelSelect/AmplopCard.tscn` (`PaperShadow` as `Bob/Body/Shadow`)
- Possibly edit: `Scenes/LevelSelect/OpenAmplopConfirm.tscn` and
  `Scripts/Design/ThemeFactory.gd` (D2, only on the human's say-so)
- Test: `tests/test_level_select.gd`

No script change in the default path, so no clean-code debt moves. Order:
scene work (Steps 1–2), then the test (Step 3).

- [ ] **Step 1 [editor] (scene, AmplopCard):** Instance
      `Scenes/UI/PaperShadow.tscn` as the **first child of `Bob/Body`**, named
      `Shadow`. `show_behind_parent` is already on the template, so it draws
      under the body. Not as a new child of `Bob`: `AmplopCard.open()` moves
      the flap to `Bob` index 0 to put it "behind the pupils", so a new index-0
      node there would change what that means. This placement is also the
      convention `test_paper_shadow` pins (`<element>/Shadow`, first child,
      `shadow_texture` = the element's own texture). On the instance ROOT set:
      - `shadow_texture` = `amplop_body.png`, the `Body` art.
      - `shadow_size` = 400×526, or `follow_parent_rect = true`.
      - `shadow_stretch_mode` = `STRETCH_SCALE`, matching `Body`, which has no
        `stretch_mode` of its own.
      - `shadow_offset` scaled for the template's size, smaller than the
        1080px default's 14,18.
      - `shadow_alpha` ≈ 0.33 and `blur` in 2–4.

      These are layout values and live in the `.tscn` only. `scene_save`, then
      the diff checks. Every fan envelope and the confirm's envelope inherit it
      (same template), and it rides `Bob`'s idle hop.
- [ ] **Step 2 [editor] (confirm letter, D2 — ask first):** `Letter` is a
      `Card` Panel. It has no texture for a `PaperShadow` to cast, and the
      `Card` StyleBoxFlat already draws the token drop shadow
      (`shadow_size` 12, `shadow_offset` (0,6), `shadow_color` α 0.30). Show
      the human the Task B screenshot and ask whether that lift is enough.
      - **Enough** (default): no change.
      - **Wants more:** add a `ThemeFactory` variation (e.g. `LetterCard`: `Card`
        with `tokens.shadow_size * 2` / `tokens.shadow_offset * 2`, like
        `PickerSheet`; token values only, no bare numbers), rebake on its own,
        restart, set it on `Letter` through the bridge, save.

      Never a `theme_override_*`, and never a `PaperShadow` with a borrowed
      texture that does not match the Card's rounded rect.
- [ ] **Step 3 [code] (test):** In `tests/test_level_select.gd`, mirroring
      `test_the_flat_elements_now_cast_a_shadow`, instance
      `AmplopCard.tscn`. Assert that `Bob/Body/Shadow` exists, has
      `scene_file_path == "res://Scenes/UI/PaperShadow.tscn"`,
      `get_index() == 0` and `show_behind_parent`, and that its
      `shadow_texture` is `Body`'s texture. For the confirm, assert `Letter`'s
      variation is `Card`, or the new one if Step 2 added it.
- [ ] **Step 4 [editor]:** Full-size screenshot of the fan and the open confirm.
      Confirm each shadow matches its element's shape, offset down-right, and
      stays subtle. Send to the human.
- [ ] **Step 5 [editor]:** No-op `script_patch` on the test file if a subagent
      wrote it. Then `test_run(suite="level_select")`,
      `test_run(suite="paper_shadow")` (must stay green; the 20 existing
      instances are untouched, and this one has its own knobs) and
      `test_run(suite="clean_code")`. If Step 2 added a variation:
      `theme_factory` too.
- [ ] **Step 6 [code]:** Commit: `feat(level-select): soft drop shadows on the amplop cards`.

---

## Task E: Finish

- [ ] **Step 1 [editor]:** Targeted re-run of `level_select`, `paper_shadow`,
      `tall_screen_layout`, `script_documentation`, `viewport_editability` and
      `clean_code` (plus `theme_factory` if a variation was added). If a full
      `test_run` is taken, budget one editor restart after (CLAUDE.md), and
      `git checkout --` any incidental `kejartes_theme.tres` /
      `default_bus_layout.tres` rewrite you did not intend.
- [ ] **Step 2 [code]:** If `clean_code` reported **shrank**, run the dump tool
      (Global Constraints, Clean code). Then have the controller do a no-op
      `script_patch` of `ci/clean_code_baseline.gd` and re-run `clean_code`
      [editor]. `git diff ci/clean_code_baseline.gd` must only lower numbers
      or remove entries. Expected for this plan as written: **no baseline
      diff**. If someone paid the optional `AmplopCard.open()` debt, the
      diff is the removal of `"res://Scripts/LevelSelect/AmplopCard.gd": 1`
      from `UNTYPED`, and that alone. If it reported **grew**, fix the code;
      never raise the baseline.
- [ ] **Step 3 [code]:** `git status` clean except intended files; **no `Balance.gd`
      diff**.
- [ ] **Step 4 [editor]:** Ship with the `ship-pr` skill (runs the full suite + local
      review, opens the PR, stamps the tested commit).

## Notes for the picking-up worker

- The bridge is single-client: run the editor yourself; if you delegate
  **[code]** steps to a subagent, do not let it connect to the editor, and
  no-op `script_patch` every `.gd` it wrote before the next `test_run`.
- Parts A/B/D are independent enough to do in any order, but do **scene edits
  before script and test edits within a task** and restart the editor between
  a script patch and the next `scene_save`.
- Part C touches no game code — safe to do first to get it out of the way.
