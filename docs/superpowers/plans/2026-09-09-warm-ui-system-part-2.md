# Warm UI System — Part 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Revision (2026-09-28): clean-code pass; status audit.** Checked against
> `Textures` as of `b2890588` and `docs/superpowers/design/clean-code.md`.
>
> **Status, per task**
> - **Task 1 — DONE**, `36ec72c9` (2026-09-09): `icon_chevron_left/right.png`
>   exist in `Assets/Images/UI/Nav/`, `CardArrowButton` is built in
>   `ThemeFactory.gd:1336`, `test_card_arrow_button_is_a_circle` is in
>   `tests/test_button_geometry.gd:336`, `CardArrowButton` is in
>   `DISPLAY_ROSTER`. **Later superseded on StudentCard only:** `5a43b6eb`
>   (2026-09-10) put StudentCard's `NextButtonKiri`/`Kanan` back on
>   `StudentCardSecondaryButtonL` (160×128) with a rotated
>   `UI/Placeholders/arrow.png` child, to match StudentList.
>   `CardArrowButton` and the chevrons now live on ReportCard. Not to redo.
> - **Task 2 — DONE, then deliberately reverted.** `470215c3` (2026-09-09)
>   neutralised `meja_background.png` to pale oak at mean luminance 190.1;
>   `594a9b61` (same day) restored the wood grain "requested directly". Not
>   to redo (see the question at the end of this note).
> - **Task 3 — DONE**, `1918f42b` (2026-09-09), by a different route than
>   written: the panel was repainted warm **dark** (cream text at 6.9–10.5:1)
>   rather than cream, so `BioLabel`/`BioValue` needed no change. The same
>   day `01741ea6` swapped the portrait and the panel, so `BIO_PANEL_RECT` is
>   now `Rect2(452, 300, 489, 367)`, not `Rect2(120, …)`.
> - **Tasks 4–8 — TODO, never started.** `StudentCardView.gd` still builds 5
>   visual nodes (`TextureRect.new()` ×2, `VBoxContainer.new()`,
>   `Label.new()` ×2) and sits at `BASELINE` 5 in
>   `tests/test_viewport_editability.gd:82`. Rewritten below against today's
>   code.
>
> **What changed in this revision**
> - Global Constraints: file names corrected, the obsolete "editor hangs every
>   cycle" note replaced by CLAUDE.md's current restart guidance, and a
>   **Clean code** block added.
> - Every TODO step is tagged **[editor]** (the controller, through the
>   godot-ai bridge) or **[code]** (a subagent), scene work before script
>   work inside every task; each task starts with an editor restart when the
>   previous one patched a script (CLAUDE.md 4b).
> - `test_run(suite=...)` names are real `suite_name()`s: `student_card`,
>   `student_card_layout`, `report_card`, `paper_shadow`,
>   `tall_screen_layout`, `lobby_style_buttons`, `viewport_editability`,
>   `clean_code`, `script_documentation`, `stat_check`.
> - Task 8 is now the close-out (docs, full run, ship-pr). The ratchet is
>   lowered **in the task that shrinks it** (5 → 3 in Task 5, entry deleted
>   in Task 6), because `test_baseline_is_not_stale` fails the moment a count
>   drops and the old plan would have left the suite red for three commits.
> - Task 7 grew to cover the bars' geometry: `build_stat_bars` overwrites
>   every bar's offsets from `PILL_RECTS` at runtime, so the positions the
>   `.tscn` shows are dead (the comment in
>   `test_trait_pills_do_not_overlap_neighbors` says so). The template now
>   holds the real rects.
>
> **Plan-vs-code conflicts fixed**
> 1. `student_card.tscn` / `student_card.gd` are `Scenes/StudentCard/StudentCard.tscn`
>    / `Scripts/StudentCard/StudentCard.gd` since the 2026-09-26 PascalCase rename.
> 2. The card children `Kepribadian1/2` and `Akademis1..3` are now `Mood`,
>    `Energy`, `Akademis`, `SeniBudaya`, `Olahraga` (2026-09-26 key rename).
>    The legacy-stat-key ratchet (baseline empty) forbids the old names
>    anywhere, including a new template.
> 3. **ReportCard carries the same six cards** and calls
>    `StudentCardView.populate` too. Once the view stops building the icons
>    and the bio panel, a ReportCard not on the template would lose them, so
>    Task 4 converts **both** scenes.
> 4. ReportCard must contain no `Aprove` (`test_report_card.gd`'s
>    `test_has_no_approve_buttons`, a recursive `find_child`). So the template
>    holds the common card, and `Aprove`/`Batal` stay StudentCard's own
>    children, added under each instance. That also keeps
>    `test_lobby_style_buttons`'s counts (8 `StudentCardSecondaryButtonL`,
>    7 `PrimaryButtonL` in `StudentCard.tscn`) true.
> 5. The six cards differ only in the portrait placeholder texture and the
>    root's `visible`, measured by diffing every card block in both scenes.
>    The portrait is overwritten by `populate()` at runtime, and a property
>    set on an instance's child would be dropped on save anyway. So the
>    template carries one placeholder and no per-card export is needed.
> 6. The badge is `InfoBadge` drawing `icon_info_red.png`, not an untinted
>    amber `Info`; the icons are `StudentCard/stat_*.png`.
> 7. Task 6 no longer "keeps one" `.new()`: the three bio values are
>    template nodes too, so the count reaches 0 and the `BASELINE` entry is
>    deleted.
> 8. Several `student_card_layout` tests scan the `.tscn` text for
>    `[node name="…" parent="KertasMurid%d"`, and `test_cards_use_the_new_background`
>    looks for `card_bg.png` in each scene. Instancing breaks all of them,
>    so Task 4 converts them to checks on the instantiated scene (the
>    template itself, or a card instanced from it).
> 9. `populate()`'s `KutuBuku`/`KutuBuku2` `is Label` branches are dead: both
>    nodes are Buttons (pinned by `test_action_buttons_use_theme_variations`).
>    `build_stat_bars` still deletes an `InfoIcon` that no longer exists.
>    Both are removed as Boy Scout work.
> 10. `StudentCard.gd` is at its `LARGE_SCRIPTS` cap (1451) and **is not
>    edited by any task**. Instance names `KertasMurid1..6` and every child
>    name it reaches (`Aprove`, `Batal`, `BioPanel`, `Icon*`, the bars) are
>    kept, so it needs no change. The same goes for `ReportCard.gd`.
>
> **Question for the human:** Task 2's oak backdrop was reverted at your
> request (`594a9b61`). This revision treats the wood grain as final. Say so
> if the neutral backdrop should come back.

**Goal:** Fix the StudentCard screen's three real cosmetic defects (red arrows,
over-saturated backdrop, unreadable bio panel), then pay down its runtime-UI-
construction debt by moving the static parts into a card template — lowering
`test_viewport_editability.gd`'s `BASELINE` for `StudentCardView.gd` from 5.

**Architecture:** `card_bg.png` is a painted 1080×1920 illustration. It paints the
bio panel's frame and all five stat-pill tracks; `StudentCardView.gd` positions
live nodes onto that art using constants measured from it. **Nothing in this plan
moves any painted element**, so `PILL_RECTS`, `BIO_PANEL_RECT` and the icon
geometry all keep their current values. Only colours change in the art, and only
node *ownership* changes in the scene.

*(2026-09-28)* The second half makes one template,
`Scenes/StudentCard/StudentCardPaper.tscn`, and instances it six times in
**both** `StudentCard.tscn` and `ReportCard.tscn`. The static chrome the view
builds or repositions at runtime (the icon clusters, the bio panel, the bar
rects) moves into that template, and `StudentCardView` shrinks to writing
per-student values and binding taps. `StudentCardView`'s public entry point
`populate(card, student, on_bar_input, on_badge_hover_enter,
on_badge_hover_exit, on_badge_pressed)` keeps its signature, so neither
screen script changes.

**Tech Stack:** Godot 4.6, GDScript, the `godot-ai` MCP bridge, `McpTestSuite`.

**Spec:** `docs/superpowers/specs/2026-09-08-warm-ui-system-design.md` (Part 2,
rewritten 2026-09-09)
**Architecture map:** `docs/superpowers/specs/2026-09-09-studentcard-architecture-map.md`

## Global Constraints

- **Godot 4.6**, portrait 1080×1920. `card_bg.png` is exactly 1080×1920 and each
  `KertasMurid` card is sized to it 1:1 — `test_card_background_is_the_full_design_size`
  and `test_every_card_is_exactly_the_texture_size` both pin that. **Do not
  change either dimension.**
- **Every test suite is `@tool extends McpTestSuite`** with a `suite_name()`.
- **No test may be a coroutine** — a single `await` silently aborts it.
- **Never add a `theme_override_*`** — `test_scene_has_no_theme_overrides` walks
  the whole tree and will catch it. Use a `ThemeFactory` variation. The one
  accepted exception is a layout constant: `BioPanel`'s
  `theme_override_constants/separation = 4` moves into the template as is.
- **No `Color(...)` literal in `Scripts/StudentCard/StudentCard.gd`** —
  `test_no_hardcoded_colors_remain_in_the_script`. Keep `StudentCardView.gd`
  free of them too.
- Every script needs a `##` file header; every `@export` a `##` line
  (`script_documentation`).
- Game-facing UI text is **Indonesian**; systems code is English.
- **No emoji as UI iconography.**
- `Scripts/Balance.gd` is a collaborator's — never edit.
- **Never hand-edit a `.tscn` the editor has loaded.** Scene changes go
  `scene_open` → `node_create`/`node_set_property`/`node_manage` or
  `batch_execute` (`create_node`, `set_property`, `move_node` — with an
  `index`, or the whole batch rolls back — `delete_node`) → `scene_save`.
  `move_node` only reorders siblings; it never reparents.
- **Overrides serialise only on an instanced scene's ROOT.** A property set on
  an instance's *child* reports success and is dropped on save. Adding a
  **new** child under an instance is a different operation and does
  serialise. Grep the saved file to prove it.
- **Scene work first, script work second.** `scene_save` flushes stale `.gd`
  buffers: after every save run `git diff HEAD -- '*.gd'` and restore anything
  you did not edit. Once any `.gd` has been patched, **restart the editor
  before the next `scene_save`**. Every task below starts with that restart.
  Relaunch with
  `C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`
  (the outer `.exe` is a directory), detached via `Win32_Process Create`.
- **Diff every scene after every save.** `StatBar.gd` is `@tool`, and the
  editor bakes @tool state into the file. Only intended lines may change.
- **Rescan after editing a `.gd` before running tests.** A subagent's edit comes
  from outside the editor, so do a no-op `script_patch` on each edited file.
- **The MCP bridge is single-client.** Subagents write code; the controller runs
  the editor and feeds results back.
- **Prefer targeted `test_run(suite=...)`.** A full run drops the bridge.
  Budget one editor restart per full run, and take full runs only at
  Task 8.
- **Shared checkout.** Run in a worktree, or check `git branch --show-current`
  and `git status` in the same command before every commit. Write commit
  messages to a file and `git commit -F` (PowerShell 5.1 splits `-m`
  here-strings at embedded quotes).
- **`StudentCard.gd` (1451 lines, `LARGE_SCRIPTS`) and `ReportCard.gd` are
  not edited.** If a step seems to need either, stop: it means a node or path
  name changed that must not.

### Clean code (`docs/superpowers/design/clean-code.md`)
- **No type inference from an autoload** (`tests/test_project_hygiene.gd`, PRs #97/#98, 2026-09-28): never `var x := GameState.…` or `:=` on any autoload call; declare the type, e.g. `var money: int = GameState.player_money`.

- **Typed.** Every new `var`, parameter and return is typed; `:=` only where
  the right-hand side's type is obvious. `get_node_or_null(...) as Label`,
  never a bare Variant.
- **Named numbers.** No new bare number in a function body. Layout numbers
  (positions, sizes, the badge's pivot) go in the **`.tscn`**; logic numbers
  go in a `##`-documented `const` at the top of `StudentCardView.gd`; `0`,
  `1`, `2`, `-1`, `0.5` are fine inline.
- **One job per function, ≤ 50 code lines**, named for that job. When a
  function stops building, rename it (`build_*` → `wire_*`/`fill_*`).
- **Guard clauses** and early `return`/`continue`, not nested ifs.
- **No duplicated 5+-line bodies**, in or across files.
- **Signals up, calls down.** The view keeps receiving the screen's
  Callables. It never reaches up into `StudentCard`/`ReportCard`.
- **`%UniqueName`.** Every template node the view writes that this plan adds
  (`Icon*`, the three bio values) gets `unique_name_in_owner`, and the view
  looks it up as `%Name` from the card root. The template root owns its
  nodes, so `%` resolves per card. Script-owned references use
  `@onready var x: T = %X`.
- **Fail loudly.** A template node the view expects and cannot find is a
  broken scene: `push_error("StudentCardView: …")` and skip it. Never
  create it as a fallback.
- **No commented-out code**; comments say why.
- **Boy Scout.** A function you touch ends no longer and no less typed than
  you found it, with its bare numbers named.
- **Ratchet green, every code task.** Run `test_run(suite="clean_code")`.
  When a count shrinks, lock it in **in the same commit**:
  - clean-code: `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd`,
    then a no-op `script_patch` of `ci/clean_code_baseline.gd`, then re-run
    `clean_code`. `StudentCardView.gd`'s debt is per script (`UNTYPED` 13,
    `BARE_NUMBERS` 37; no `LONG_FUNCTIONS` or duplicate-group entries). So
    renaming functions needs **no** `-- --rekey`, and the diff must only
    lower those two `StudentCardView.gd` lines.
  - viewport editability: lower `BASELINE` in
    `tests/test_viewport_editability.gd` by hand, only ever down, and delete
    an entry that reaches 0.

---

## Two independent halves

**Tasks 1–3 are cosmetic, cheap, and touch no constants or pinned geometry.**
They can ship alone and address everything the mentor actually reported.
*(2026-09-28: all three shipped on 2026-09-09; see the status note.)*

**Tasks 4–8 are the architectural half.** They pay down tracked debt but require
the template extraction first and invert several source-scan tests. Stop after
Task 3 if the cost stops being worth it — the plan is deliberately cut here.
*(2026-09-28: Task 4 alone is a complete, shippable step, since it adds no new
debt. Tasks 5–7 each ship on their own after it.)*

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `Assets/Images/UI/Nav/icon_chevron_left.png` / `_right.png` | arrow glyphs | ~~Create~~ done (Task 1) |
| `Assets/Images/UI/meja_background.png` | neutral oak backdrop | ~~Replace~~ done, then reverted (Task 2) |
| `Assets/Images/StudentCard/card_bg.png` | bio panel frame recolour only | ~~Modify~~ done (Task 3) |
| `Scripts/Design/ThemeFactory.gd` | `CardArrowButton` variation | ~~Modify~~ done (Task 1) |
| `Scenes/StudentCard/StudentCardPaper.tscn` | the one card template (no script) | **Create** (Task 4), extend (5–7) |
| `Scenes/StudentCard/StudentCard.tscn` | six template instances + per-instance `Aprove`/`Batal` | Modify (Task 4) |
| `Scenes/ReportCard/ReportCard.tscn` | six template instances | Modify (Task 4) |
| `Scripts/StudentCard/StudentCardView.gd` | shrink to value-writing and tap-binding | Modify (5–7) |
| `tests/test_student_card_layout.gd` | scene-text scans → instantiated checks; builder scans → node checks | Modify (4–7) |
| `tests/test_student_card.gd` | a doc comment naming `_STAT_ICONS` / `build_stat_bars` | Modify (5, 7) |
| `tests/test_viewport_editability.gd` | `BASELINE` 5 → 3 → entry deleted | Modify (5, 6) |
| `ci/clean_code_baseline.gd` | regenerated by the dump, only lower | Regenerate (5–7) |
| `docs/superpowers/CHANGELOG.md`, `DEBT.md`, `design/authoring-guide.md`, `CLAUDE.md` | close-out | Modify (Task 8) |

---

## Task 1: Chevron arrows

> **Status: DONE** — `36ec72c9` (2026-09-09). Superseded on StudentCard by
> `5a43b6eb` (2026-09-10); `CardArrowButton` + chevrons now serve ReportCard.
> Left as history.

**Files:**
- Create: `Assets/Images/UI/Nav/icon_chevron_left.png`, `icon_chevron_right.png`
- Modify: `Scripts/Design/ThemeFactory.gd` (`CardArrowButton`)
- Modify: `Scenes/StudentCard/student_card.tscn` (`NextButtonKanan`, `NextButtonKiri`)
- Modify: `tests/test_button_geometry.gd`

**Interfaces:**
- Consumes: `tokens.radius_pill`, `brand_primary`, `outline_card`, `shadow_*`.
- Produces: theme type `CardArrowButton`.

- [x] **Step 1: Write the failing test**

Append to `tests/test_button_geometry.gd`:

```gdscript
## The card's page arrows. A reviewed exception to the fixed-radius rule:
## at a fixed 120x120 square, radius_pill yields an exact circle, and
## because the size is fixed there is no height-dependent-radius risk.
func test_card_arrow_button_is_a_circle() -> void:
	var sb := _theme.get_stylebox("normal", "CardArrowButton") as StyleBoxFlat
	assert_not_null(sb, "CardArrowButton/normal must be a StyleBoxFlat")
	assert_eq(sb.corner_radius_top_left, _tokens.radius_pill,
		"CardArrowButton is a fixed square, so radius_pill makes it a circle")
	assert_eq(sb.bg_color, _tokens.brand_primary, "arrow fill")
	assert_eq(sb.border_color, _tokens.outline_card, "arrow rim")
```

Add `"CardArrowButton"` to `RADIUS_EXEMPT` with the reason above, so the
one-radius test does not flag it.

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="button_geometry")
```
Expected: FAIL — `CardArrowButton/normal must be a StyleBoxFlat` (the type does
not exist yet).

- [x] **Step 3: Generate the two chevron assets**

Two 256×256 transparent PNGs in `Assets/Images/UI/Nav/`, drawn in
`text_on_brand` `#FFF6E8`, using PowerShell + `System.Drawing` (this project's
established method — see `.superpowers/sdd/.../generate-assets.ps1` from Part 1).
A thick chevron stroke, ~28px wide, inside a centred 180×180 safe area.

**Author left and right as SEPARATE files.** Today both arrows share
`pngwing.com (1).png` with `NextButtonKanan` carrying `rotation = -3.1272264`
to flip it. Two assets retires that rotation hack.

**Render them on the brand colour and look at them before accepting.** In Part 1
two of five generated icons were geometrically correct and still read wrong; a
coordinate spec is not a guarantee of a readable silhouette.

- [x] **Step 4: Build the variation**

In `ThemeFactory._build_buttons`:

```gdscript
	# The student card's page arrows. Fixed 120x120, so radius_pill yields a
	# circle rather than a height-dependent capsule -- the one place that
	# radius is still correct on a Button. Replaces two rotated copies of a
	# pure-#FF0000 asset that had no palette relationship to anything.
	_add_button_variation(theme, tokens, "CardArrowButton",
		tokens.brand_primary, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand,
		tokens.radius_pill)
	theme.set_constant("icon_max_width", "CardArrowButton", tokens.btn_icon_m)
```

Add `"CardArrowButton"` to `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`.

- [x] **Step 5: Wire the two buttons in the scene**

Through the editor (`scene_open` → `node_set_property` → `scene_save`), on both
`NextButtonKanan` and `NextButtonKiri`:
- `theme_type_variation` → `CardArrowButton`
- `icon` → the matching chevron
- `rotation` → `0` (retires the -3.1272264 hack)
- `scale` → `Vector2(1, 1)` (retires the 0.175 hack)
- geometry → 120×120, keeping each arrow's existing centre

`test_interactive_controls_meet_the_minimum_touch_target` accounts for `scale`,
so removing the 0.175 scale while sizing the box to 120 keeps it passing —
verify rather than assume.

- [x] **Step 6: Rebake, verify, commit**

```
test_run(suite="theme_rebake")
test_run(suite="button_geometry")
test_run(suite="student_card")
test_run()
```

```bash
git add Assets/Images/UI/Nav/ Scripts/Design/ThemeFactory.gd Scenes/StudentCard/student_card.tscn tests/ Assets/Theme/kejartes_theme.tres
git commit -m "feat(studentcard): replace the red arrows with palette chevrons

Both arrows shared one asset whose every opaque pixel was pure #FF0000,
with one of them rotated -179.17 degrees to point the other way. Two
proper chevrons on a CardArrowButton retire both the colour and the
rotation hack."
```

---

## Task 2: Neutral oak backdrop

> **Status: DONE, then reverted** — `470215c3` (2026-09-09, mean luminance
> 129.8 → 190.1), reverted by `594a9b61` (same day) on the user's request.
> Left as history; not to redo without the human's say-so.

**Files:**
- Modify: `Assets/Images/UI/meja_background.png` (replace in place)

**Interfaces:** none — the filename is unchanged so no reference moves.

- [x] **Step 1: Measure the current backdrop**

```
mean luminance 130/255, ranges #E6A57D -> #884119
```
Confirm with a `System.Drawing` sample before replacing, so the improvement is
measured rather than asserted.

- [x] **Step 2: Author the replacement**

1080×1920, pale oak, low saturation, **target mean luminance ~190**, gentle
grain, no strong vertical gradient. Keep the filename — nothing else changes.

The defect being fixed: the backdrop is more saturated than the mint `#D1F5E2`
card sitting on it, and the two hues are near-complementary, which is what makes
the card read dead.

- [x] **Step 3: Verify and commit**

```
filesystem_manage(op="scan")
test_run()
```
Then run the game to StudentCard and look at it — this one is only judgeable by
eye.

```bash
git add Assets/Images/UI/meja_background.png
git commit -m "feat(studentcard): neutralise the backdrop so the card reads

The wood ran #E6A57D to #884119 at mean luminance 130/255, under a mint
card -- more saturated than its own content, and near-complementary to
it. Replaced with pale oak at ~190."
```

---

## Task 3: Repaint the bio panel frame

> **Status: DONE** — `1918f42b` (2026-09-09): recoloured warm dark by a
> luminance-mapped colour mask (179,689 pixels, geometry untouched), so the
> existing cream `BioLabel`/`BioValue` text reads at 6.9–10.5:1 with no
> variation change. `01741ea6` then moved the panel right:
> `BIO_PANEL_RECT = Rect2(452, 300, 489, 367)`. Left as history.

**Files:**
- Modify: `Assets/Images/StudentCard/card_bg.png`

**Interfaces:** **`BIO_PANEL_RECT` does not change.** Only the pixels inside the
existing frame change colour.

- [x] **Step 1: Confirm the rect before touching the art**

`BIO_PANEL_RECT := Rect2(120, 300, 489, 367)` is the painted panel's measured
interior, pinned by `test_bio_panel_sits_inside_the_painted_panel`. Sample
`card_bg.png` around that rect to find the frame's exact painted bounds.

- [x] **Step 2: Recolour the frame in place**

Replace the `#C6B6EE` → `#9C8FBB` lavender gradient with a warm surface from the
token palette — `surface_sunken` `#EFE0CB` with an `outline_card` `#FFF6E8` rim
reads correctly against the warm chrome and gives the runtime text far more
contrast than lavender did.

**Do not move, resize or restyle the frame's geometry.** Same rect, different
colour. Anything else invalidates `BIO_PANEL_RECT` and its pinning test.

- [x] **Step 3: Check the text still reads**

The bio text uses the `BioLabel` variation. Against a cream panel its colour may
now need to be `text_primary` rather than whatever it was on lavender. Check in a
running build and adjust the *variation*, never a `theme_override_*`.

- [x] **Step 4: Verify and commit**

```
filesystem_manage(op="scan")
test_run(suite="student_card_layout")
test_run()
```

```bash
git add Assets/Images/StudentCard/card_bg.png Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(studentcard): repaint the bio panel warm

The identity text was always real, per-student data -- what made it hard
to read was the lavender gradient painted behind it. Same rect, so
BIO_PANEL_RECT and its pinning test are untouched."
```

> **Tasks 1–3 close everything the mentor reported. Stop here if the
> architectural half is not worth its cost today.**

---

## Task 4: Extract the card template (both screens)

**Files:**
- Create: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scenes/StudentCard/StudentCard.tscn`, `Scenes/ReportCard/ReportCard.tscn`
- Modify: `tests/test_student_card_layout.gd`

**Interfaces:**
- Produces: `StudentCardPaper.tscn`, a script-less `TextureRect` root named
  `StudentCardPaper` (texture `card_bg.png`, 1080×1920). It is instanced as
  `KertasMurid1`..`6` in both scenes.
- Keeps: every path `StudentCard.gd`, `ReportCard.gd` and the tutorial
  reach by string. An instance's name plus the child's name resolves exactly
  as a plain child did.

- [ ] **Step 1 [code]: Inventory the paths and the card, before building anything**

Grep every string path into a card, in both screen scripts and the tests:

```
grep -n "KertasMurid\|get_node_or_null(\"" Scripts/StudentCard/StudentCard.gd Scripts/ReportCard/ReportCard.gd Scripts/StudentCard/StudentCardView.gd
```

Expected child names reached today: `Mood`, `Energy`, `Akademis`,
`SeniBudaya`, `Olahraga`, `KutuBuku`, `KutuBuku2`, `Aprove`, `Batal`,
`TextureRect`, `MinatValue`, plus the runtime-built `BioPanel` and `Icon*`
(`CARD_ROW_ORDER` in both screens). The two `KertasMurid1/PopupCanvas/TraitOverlay/TraitPopupPanel`
tutorial targets resolve to nothing **today, before any change**. Nothing
named `PopupCanvas` exists anywhere. Not this plan's to fix; Task 8 records
it in DEBT.

The card, as measured on 2026-09-28 (every card block of both scenes diffed
against `StudentCard.tscn`'s `KertasMurid1`):

| Child, in order | Type | Notes |
|---|---|---|
| `PaperShadow` | instance of `Scenes/UI/PaperShadow.tscn` | `layout_mode = 0`; must stay child 0 (`paper_shadow`) |
| `TextureRect` | TextureRect | the portrait: 136,294 → 419,670, `expand_mode 1`, `stretch_mode 6`; placeholder `MuridPortrait/Murid1.jpg` |
| `SifatPasifLabel` | Label | `CardSectionLabel`, "Sifat Pasif:" |
| `KutuBuku`, `KutuBuku2` | Button | `TraitPill`, geometry pinned by `_TRAIT_PILL_GEOMETRY` |
| `Mood`, `Energy`, `Akademis`, `SeniBudaya`, `Olahraga` | ProgressBar + `StatBar.gd` | each with `ValueLabel` and `Label` children (Task 7 removes them) |
| `MinatLabel`, `MinatValue` | Label | `CardSectionLabel` "Minat:" / `H2Label` |
| `PortraitFrame` | TextureRect | `portrait_frame.png`, same rect as the portrait, after it |
| `Aprove`, `Batal` | Button | **StudentCard only** — not in the template |

The only per-card differences are the portrait placeholder (overwritten by
`populate()`) and the root's `visible`. Copy every other property verbatim
from `StudentCard.tscn`'s `KertasMurid1`.

- [ ] **Step 2 [editor]: Build `StudentCardPaper.tscn`**

Create the scene with a `TextureRect` root named `StudentCardPaper`
(`texture = card_bg.png`, offsets 0,0 → 1080,1920). Add the children in
Step 1's order, minus `Aprove`/`Batal`, with one `batch_execute` of
`create_node`/`set_property`. Read each value off `KertasMurid1` with
`node_get_properties` rather than retyping it. `PaperShadow` is an instance,
not a copy. `scene_save`.

*Fallback, if the editor build proves impractical:* a **[code]** subagent
writes the new file as text **before the editor has ever opened it**. The
stale-copy hazard applies only to scenes the editor holds, and a brand-new
file has none. Take its blocks from `KertasMurid1`, re-parented to `"."`,
with fresh `ext_resource` ids. The controller then runs
`filesystem_manage(op="scan")`, `scene_open`, `scene_save` once, so the
editor writes the uids. Never do this for `StudentCard.tscn` or
`ReportCard.tscn`.

Verify: the saved template contains no `akademis1`-style names (the
`clean_code` legacy-key rule applies to `.tscn` files).

- [ ] **Step 3 [editor]: Replace StudentCard's six cards with instances**

`scene_open("res://Scenes/StudentCard/StudentCard.tscn")`. Today's root order
is `World`, `KertasMurid6` … `KertasMurid1`, `BelajarButton`, … (card 1 last,
drawn on top). Keep it:

1. Delete `KertasMurid1`..`6`.
2. Instance the template six times as `KertasMurid6`..`KertasMurid1` and
   `move_node` each into its old slot (indices 1..6, with an explicit `index`).
3. Root overrides on each instance, as today: `layout_mode = 1`,
   `anchors_preset = 8`, all four anchors `0.5`, offsets
   `-540, -960, 540, 960`, `grow_horizontal = 2`, `grow_vertical = 2`;
   `visible = false` on 2, 3, 4 and 6 (1 and 5 are saved visible today;
   `_show_page()` sets visibility at runtime).
4. Under **each** instance, add `Aprove` and `Batal` as new children with
   `KertasMurid1`'s values: `layout_mode 0`, offsets `260, 1600, 780, 1760`;
   `Aprove` `PrimaryButtonL` "APPROVE"; `Batal` `visible = false`,
   `StudentCardSecondaryButtonL` "BATAL". They append after the template's
   children. Nothing they overlap draws later, so z-order is unchanged.
5. `scene_save`. Then prove the adds serialised:
   `grep -c 'name="Aprove" type="Button" parent="KertasMurid' Scenes/StudentCard/StudentCard.tscn`
   → `6`, and the same for `Batal`. Check `git diff HEAD -- '*.gd'` is empty.

- [ ] **Step 4 [editor]: Replace ReportCard's six cards with instances**

Same as Step 3 on `Scenes/ReportCard/ReportCard.tscn`, without `Aprove`/`Batal`
and without the `grow_*` overrides (ReportCard's cards have none today).
`scene_save`, then the same `.gd` diff check. Both scene files should shrink
by roughly 1,300 lines each.

- [ ] **Step 5 [editor]: Restart the editor**

This task's scripts are about to change, and the next task's scene work
must not flush stale buffers. Restart now so both scenes reload from disk.

- [ ] **Step 6 [code]: Convert the scene-text tests**

In `tests/test_student_card_layout.gd` add, near `_SCENES`:

```gdscript
## The one card template both screens instance six times.
const _PAPER := "res://Scenes/StudentCard/StudentCardPaper.tscn"


## Every page on both screens is an instance of the one template, so one
## template edit reaches all twelve. ReportCard is a viewer and carries no
## approval buttons (test_report_card pins that recursively), so Aprove and
## Batal are StudentCard's own per-instance children, never template nodes.
func test_every_card_is_an_instance_of_the_paper_template() -> void:
	var paper := (load(_PAPER) as PackedScene).instantiate()
	track(paper)
	assert_true(paper.get_node_or_null("Aprove") == null,
		"Aprove belongs to StudentCard, not to the shared template")
	for scene_path: String in _SCENES:
		var inst := (load(scene_path) as PackedScene).instantiate()
		track(inst)
		for i in range(1, 7):
			var card := inst.get_node_or_null("KertasMurid%d" % i)
			assert_true(card != null, "%s missing KertasMurid%d" % [scene_path, i])
			if card == null:
				continue
			assert_eq(card.scene_file_path, _PAPER,
				"%s KertasMurid%d must instance the template, not copy it"
					% [scene_path, i])
```

Convert these tests, which look for per-card node lines in the scene text.
Each keeps its name, its `##` doc (reworded) and its intent:

- `test_cards_use_the_new_background`: the **template's** source contains
  `Assets/Images/StudentCard/card_bg.png`. Neither screen nor the template
  contains `paper_placeholder.jpg`.
- `test_every_card_has_the_sifat_pasif_heading` and the scan half of
  `test_every_card_shows_the_students_specialty`: instantiate each scene
  and assert `KertasMurid%d/SifatPasifLabel`, `MinatLabel` and `MinatValue`
  are `Label`s. The `build_minat_row` half is unchanged.
- `test_superseded_labels_are_removed_from_the_scenes`: after the change it
  would pass vacuously. Instantiate instead, and assert that no card on
  either scene has a `Label` child named `Nama`, `Profil`, `Kepribadian` or
  `Akademis` (`card.get_node_or_null(name) is Label` is false).

Do not touch the instantiation-based tests. `test_every_card_is_exactly_the_texture_size`,
`test_every_trait_pill_shares_one_geometry`, `test_the_lower_card_stack_stays_on_the_paper`
and `test_trait_pills_do_not_overlap_neighbors` are the ones that catch a
botched extraction.

- [ ] **Step 7 [editor]: Reload and verify**

No-op `script_patch` on `tests/test_student_card_layout.gd`, then:

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
test_run(suite="paper_shadow")
test_run(suite="tall_screen_layout")
test_run(suite="lobby_style_buttons")
test_run(suite="viewport_editability")
test_run(suite="clean_code")
```

All green. `viewport_editability` and `clean_code` should be unchanged, since
no `.gd` outside `tests/` moved. `lobby_style_buttons` still counts 8 and 7
because `Aprove`/`Batal` stayed in `StudentCard.tscn`.

Then run a real build: seed (Debug → General → **⚡ Seed Playtest State**),
teleport to StudentCard, and page through all six students. Every bar,
icon, bio row and pill must still fill per student, and the tutorial steps
that target `KertasMurid1/Mood` / `KutuBuku` / `Aprove` must highlight. Open
Rapor from the Lobby and page through it. Take one screenshot of each
screen.

- [ ] **Step 8 [code]: Commit**

```
git add Scenes/StudentCard/ Scenes/ReportCard/ReportCard.tscn tests/test_student_card_layout.gd
```
Message (via `git commit -F`):

```
refactor(studentcard): one card template, instanced on both screens

StudentCard and ReportCard each carried six hand-copied KertasMurid
cards, identical but for a portrait placeholder populate() overwrites.
Both now instance StudentCardPaper.tscn. Aprove and Batal stay
StudentCard's own per-instance children, because ReportCard is a viewer.
Instance names and child names are unchanged, so every string path
still resolves. The scene-text scans now check the instantiated nodes.
```

---

## Task 5: Move the icon clusters into the template

**Files:**
- Modify: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_icon_clusters` → `wire_icon_clusters`, `populate`)
- Modify: `tests/test_student_card_layout.gd`, `tests/test_student_card.gd` (doc comment), `tests/test_viewport_editability.gd`
- Regenerate: `ci/clean_code_baseline.gd`

**Interfaces:**
- Consumes: Task 4's template.
- Removes: two `.new()` sites (`TextureRect` icon, `TextureRect` badge). `BASELINE` 5 → 3.
- `populate()`'s signature is unchanged.

- [ ] **Step 1 [editor]: Restart the editor** if anything was patched since the last restart.

- [ ] **Step 2 [editor]: Add the ten nodes to the template**

After `PortraitFrame`, add five `TextureRect`s `IconAkademis`, `IconSeniBudaya`,
`IconOlahraga`, `IconMood`, `IconEnergy`, each with `unique_name_in_owner = true`,
`layout_mode 0`, `expand_mode = 1` (ignore size), `stretch_mode = 5` (keep
aspect centred), `mouse_filter = 0` (stop), `mouse_default_cursor_shape = 2`
(pointing hand). The texture is `res://Assets/Images/StudentCard/stat_<x>.png`.
Rects are today's runtime values: 128 px square, 24 px left of its pill,
vertically centred on it:

| Node | texture | left | top | right | bottom |
|---|---|---|---|---|---|
| `IconAkademis` | `stat_akademis.png` | 132 | 732.5 | 260 | 860.5 |
| `IconSeniBudaya` | `stat_senibudaya.png` | 132 | 857.5 | 260 | 985.5 |
| `IconOlahraga` | `stat_olahraga.png` | 132 | 983.5 | 260 | 1111.5 |
| `IconMood` | `stat_mood.png` | 564 | 731.5 | 692 | 859.5 |
| `IconEnergy` | `stat_energy.png` | 565 | 857.5 | 693 | 985.5 |

Under each, a `TextureRect` `InfoBadge`: texture `icon_info_red.png`,
`expand_mode 1`, `stretch_mode 5`, `mouse_filter 2` (ignore), all four
anchors `1.0`, offsets `-56, -56, 0, 0`, `pivot_offset = Vector2(28, 28)`.
Leave `modulate` white: the red is the file, never a tint. Set
`editor_description` on the first `InfoBadge` to say why (red not amber;
a separate file because a modulate muddies the art).

These are static chrome: the same five icons, at the same positions, on
every card. The icons stay siblings of the bars. The tutorial addresses the
bars by path, so nothing may be re-parented under them.

`scene_save`. Diff: only the template changed; `git diff HEAD -- '*.gd'` empty.

- [ ] **Step 3 [code]: Convert the two builder-pinning tests**

In `tests/test_student_card_layout.gd`, replace the body of
`test_icon_clusters_exist_and_meet_the_touch_target`. It now asserts the
nodes, which is stronger than "a function exists". Keep the name and
reword the `##` doc: the "source scan, because `_ready()` never runs"
reasoning no longer applies.

```gdscript
## Icon<stat> -> its art. The same five on every card: static chrome.
const _ICON_ART := {
	"Akademis": "stat_akademis.png", "SeniBudaya": "stat_senibudaya.png",
	"Olahraga": "stat_olahraga.png", "Mood": "stat_mood.png",
	"Energy": "stat_energy.png",
}
## An icon's edge, its gap to its pill's left edge, and the (i) badge's edge.
const _ICON_SIZE := 128.0
const _ICON_GAP := 24.0
const _BADGE_SIZE := 56.0


func test_icon_clusters_exist_and_meet_the_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	assert_true(_ICON_SIZE >= float(tokens.touch_target_min),
		"an icon is the only tap target for its stat's info")
	var paper := (load(_PAPER) as PackedScene).instantiate() as Control
	track(paper)
	for bar_name: String in _ICON_ART:
		var icon := paper.get_node_or_null("Icon" + bar_name) as TextureRect
		assert_true(icon != null, "the template needs Icon" + bar_name)
		if icon == null:
			continue
		var pill: Rect2 = StudentCardView.PILL_RECTS[bar_name]
		var want := Rect2(pill.position.x - _ICON_GAP - _ICON_SIZE,
			pill.get_center().y - _ICON_SIZE * 0.5, _ICON_SIZE, _ICON_SIZE)
		assert_true(icon.get_rect().is_equal_approx(want),
			"Icon%s is %s, expected %s beside its pill" % [bar_name, icon.get_rect(), want])
		assert_eq(icon.texture.resource_path, _ART + _ICON_ART[bar_name],
			"Icon%s art" % bar_name)
		assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_STOP,
			"Icon%s carries the tap the pill gave up" % bar_name)
```

`test_info_badge_draws_its_asset_untinted` becomes a node check. For each
icon, `InfoBadge` exists, draws `_ART + "icon_info_red.png"`, has
`modulate == Color.WHITE` and `self_modulate == Color.WHITE`, has
`mouse_filter == MOUSE_FILTER_IGNORE`, and has a `_BADGE_SIZE` square rect.
Keep its `##` reason (a modulate muddies the art) and add a line saying the
red is the file itself.

If a tree-less `get_rect()` reads zero size here, add the paper to the tree
the way `test_the_lower_card_stack_stays_on_the_paper` does
(`Engine.get_main_loop().root.add_child(paper)` + `track`).

In `tests/test_student_card.gd`, update the doc comment above
`test_stat_bars_are_statbars_with_a_category`: it names
`StudentCardView._STAT_ICONS`, which this step deletes. The pairing is now
the template's `IconMood`/`IconEnergy` textures.

- [ ] **Step 4 [code]: Reduce the builder to wiring**

In `Scripts/StudentCard/StudentCardView.gd`:

- Delete `_CARD_ART`, `_ICON_SIZE`, `_ICON_GAP`, `_BADGE_SIZE`, `_BADGE_ART`
  and `_STAT_ICONS`. The scene holds those values now, and the tests pin
  them. Move `_BADGE_ART`'s "red rather than amber" reasoning into
  `wire_icon_clusters`'s doc (and the `editor_description` from Step 2).
- Replace `build_icon_clusters` with:

```gdscript
## Meta key holding the Callable an icon's gui_input is bound to, so the
## next page's populate() can swap it for its own student.
const _TAP_META := &"cluster_gui_callable"
## Meta key marking a badge whose endless pulse has already started.
const _PULSE_META := &"badge_pulse_started"


## Binds each stat icon's tap to the caller, for this student. The icons,
## their red (i) badges and all their geometry are StudentCardPaper nodes;
## only the bound student changes per call. The badge breathes because it
## is the icon's only "press me" cue, and a touch screen never hovers.
static func wire_icon_clusters(kertas: Control, student: Dictionary,
		on_bar_input: Callable) -> void:
	for bar_name: String in PILL_RECTS:
		var icon := kertas.get_node_or_null("%Icon" + bar_name) as TextureRect
		if icon == null:
			push_error("StudentCardView: %s has no Icon%s -- not a StudentCardPaper?"
				% [kertas.name, bar_name])
			continue
		_bind_icon_tap(icon, on_bar_input.bind(kertas, bar_name, student))
		var badge := icon.get_node_or_null("InfoBadge") as Control
		if badge == null:
			push_error("StudentCardView: Icon%s has no InfoBadge" % bar_name)
			continue
		_start_badge_pulse(badge)


## Swaps the icon's gui_input binding for `callable`. populate() runs on
## every page turn, so the previous student's binding goes first.
static func _bind_icon_tap(icon: TextureRect, callable: Callable) -> void:
	if icon.has_meta(_TAP_META):
		icon.gui_input.disconnect(icon.get_meta(_TAP_META))
	icon.gui_input.connect(callable)
	icon.set_meta(_TAP_META, callable)
```

- `_start_badge_pulse`: drop the `pivot_offset` line (the scene sets it), and
  open with a once-only guard. Both screens re-run `populate()` on the same
  cards, and a second tween would stack:

```gdscript
	if badge.has_meta(_PULSE_META):
		return
	badge.set_meta(_PULSE_META, true)
```

- `populate()` (Boy Scout, since it is touched):
  - call `wire_icon_clusters(card, student, on_bar_input)` where it called
    `build_icon_clusters`;
  - delete the two dead `is Label` blocks for `KutuBuku`/`KutuBuku2`. Both
    are Buttons, so neither ever ran. `_style_trait_badge` sets their text;
  - type the remaining locals
    (`var portrait := card.get_node_or_null("TextureRect") as TextureRect`,
    `var portrait_path: String = StudentSkins.portrait_for(student)`,
    `var akademis_bar := card.get_node_or_null("Akademis") as ProgressBar`, …);
  - `if card == null:` → `push_error("StudentCardView.populate: no card")`
    then `return`.
  Leave the three pre-set bar `.value` lines in place. Removing them would
  make those bars animate from 0 on first show, which is a behaviour change
  and out of scope. `populate()` must end shorter than it started.

- `tests/test_viewport_editability.gd`: `"res://Scripts/StudentCard/StudentCardView.gd": 5`
  → `3`, and update the `BASELINE` doc's "last updated" line.

- [ ] **Step 5 [editor]: Reload and verify**

No-op `script_patch` on `StudentCardView.gd` and each edited test file, then:

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
test_run(suite="viewport_editability")
test_run(suite="script_documentation")
test_run(suite="clean_code")
```

`clean_code` is expected to fail with **"shrank"** on `StudentCardView.gd`.

- [ ] **Step 6 [code]: Lock in the clean-code shrink**

```
"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd
```

Expected `git diff ci/clean_code_baseline.gd`: only `StudentCardView.gd`'s
lines move. `UNTYPED` goes 13 → about 5 (three dead untyped vars deleted,
five typed; the five left are in `build_stat_bars`, `_style_trait_badge`
and `_start_button_wiggle`). `BARE_NUMBERS` 37 → a little lower. The
dump's figures win, but neither may rise. If it prints `RAISED (review):`,
fix the code, never the baseline. **[editor]:** no-op `script_patch` on
`ci/clean_code_baseline.gd`, then `test_run(suite="clean_code")` → green.

Then run a real build: seed, open StudentCard, and tap each of the five
icons on two different students. The popup must name that student's stat,
which proves the rebinding. All five badges must pulse at one rate, not
double speed after a page turn.

- [ ] **Step 7 [code]: Commit**

```
git add Scenes/StudentCard/StudentCardPaper.tscn Scripts/StudentCard/StudentCardView.gd tests/ ci/clean_code_baseline.gd
```
Message:

```
refactor(studentcard): icon clusters become template nodes

The five stat icons and their red (i) badges did not exist in any
scene -- a screenshot showed them, the .tscn did not. Their set and
positions are identical for every student, so they are static chrome
in StudentCardPaper now; the view only binds each tap to its student.
viewport_editability BASELINE for StudentCardView 5 -> 3.
```

---

## Task 6: Move the bio panel into the template

**Files:**
- Modify: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_bio_panel` → `fill_bio_panel`)
- Modify: `tests/test_student_card_layout.gd`, `tests/test_viewport_editability.gd`
- Regenerate: `ci/clean_code_baseline.gd`

**Interfaces:**
- Removes: the last three `.new()` sites (`VBoxContainer`, `Label` heading,
  `Label` value). `BASELINE` 3 → 0, so the entry is **deleted**.
- **Keeps `BIO_PANEL_RECT`** (`Rect2(452, 300, 489, 367)`) as a documented
  constant. It records where the painted panel is, and `tests/test_stat_check.gd:267`
  reads it.

- [ ] **Step 1 [editor]: Restart the editor** (Task 5 patched scripts).

- [ ] **Step 2 [editor]: Add `BioPanel` to the template**

After the `Icon*` nodes, add a `VBoxContainer` named `BioPanel` (name kept:
both screens' `CARD_ROW_ORDER` stagger it in). Give it `layout_mode 0`,
offsets `484, 332, 909, 635` (`BIO_PANEL_RECT` inset 32 on every side),
`mouse_filter 2`, and `theme_override_constants/separation = 4` (a layout
constant, the one accepted override). Its six children, in order, are all
`Label`s with `mouse_filter 2`:

| Node | variation | text | unique |
|---|---|---|---|
| `NamaLabel` | `BioLabel` | `Nama:` | no |
| `NamaValue` | `BioValue` | *(empty)* | yes |
| `JenisKelaminLabel` | `BioLabel` | `Jenis Kelamin:` | no |
| `JenisKelaminValue` | `BioValue` | *(empty)* | yes |
| `TanggalLahirLabel` | `BioLabel` | `Tanggal Lahir:` | no |
| `TanggalLahirValue` | `BioValue` | *(empty)* | yes |

`scene_save`; diff check as before.

- [ ] **Step 3 [code]: Convert the two bio tests**

`test_bio_panel_renders_the_three_rows` asserts the scene, not the builder.
Instantiate `_PAPER` (in the tree, `track`ed). `BioPanel` is a
`VBoxContainer`, and each heading is a `BioLabel` `Label` with its text.
Then call `StudentCardView.fill_bio_panel(paper, {"name": "Marcel",
"jenis_kelamin": "Laki-laki", "tanggal_lahir": "12 Mei 2012"})` and
assert the three `BioValue` labels show those strings. That is the
per-student behaviour the source scan never proved.

```gdscript
## The bio rows' inset from the painted panel's rounded border.
const _BIO_PADDING := 32.0
## Heading node -> the words it shows. Static on every card.
const _BIO_HEADINGS := {
	"NamaLabel": "Nama:",
	"JenisKelaminLabel": "Jenis Kelamin:",
	"TanggalLahirLabel": "Tanggal Lahir:",
}
```

`test_bio_panel_sits_inside_the_painted_panel` becomes geometric. Keep the
`BIO_PANEL_RECT == Rect2(452, 300, 489, 367)` assertion. Then, for every
card on both `_SCENES` (instantiated, in the tree, sized 1080×1920), assert
that `KertasMurid%d/BioPanel`'s `get_rect()` `is_equal_approx`
`StudentCardView.BIO_PANEL_RECT.grow(-_BIO_PADDING)`. That is behavioural,
and stronger than the four offset lines it replaces.

- [ ] **Step 4 [code]: Replace the builder with a filler**

In `StudentCardView.gd`, delete `build_bio_panel` and `_BIO_PADDING`, and
add:

```gdscript
## Bio value node -> the roster key it shows. The panel, its geometry and
## the three headings are StudentCardPaper nodes; only these are per student.
const _BIO_VALUES := {
	"%NamaValue": "name",
	"%JenisKelaminValue": "jenis_kelamin",
	"%TanggalLahirValue": "tanggal_lahir",
}


## Writes the student's three identity values into the painted panel.
static func fill_bio_panel(kertas: Control, student: Dictionary) -> void:
	for node_path: String in _BIO_VALUES:
		var value := kertas.get_node_or_null(node_path) as Label
		if value == null:
			push_error("StudentCardView: %s has no %s" % [kertas.name, node_path])
			continue
		value.text = str(student.get(_BIO_VALUES[node_path], ""))
```

`populate()` calls `fill_bio_panel(card, student)` in place of
`build_bio_panel`. Update `BIO_PANEL_RECT`'s doc: the scene now places the
panel, and the constant is the measurement the art and `StatCheck` depend
on.

`tests/test_viewport_editability.gd`: **delete** the `StudentCardView.gd`
line from `BASELINE` (count 0; the pasteable literal the test prints omits
zero files).

- [ ] **Step 5 [editor]: Reload and verify**

No-op `script_patch` on each edited `.gd`, then:

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
test_run(suite="stat_check")
test_run(suite="viewport_editability")
test_run(suite="clean_code")
```

- [ ] **Step 6 [code]: Lock in the shrink**

Run the dump (command above). Expected diff: `StudentCardView.gd`'s
`BARE_NUMBERS` drops by at least 1 (the `separation` `4`); nothing else
moves. **[editor]:** no-op `script_patch` of the baseline, then `clean_code`
green.

Then run a build and page through several students on StudentCard **and**
Rapor. The three values must change per student, which is the one thing
these tests do not prove on a real screen.

- [ ] **Step 7 [code]: Commit**

```
git add Scenes/StudentCard/StudentCardPaper.tscn Scripts/StudentCard/StudentCardView.gd tests/ ci/clean_code_baseline.gd
```
Message:

```
refactor(studentcard): bio panel moves into the template

The container, its geometry and the three headings are identical on
every card; only the three values are per student. Structure is scene
data now and the view writes three strings. StudentCardView builds no
visual nodes at runtime, so its viewport_editability entry is gone.
```

---

## Task 7: The bars: author their real geometry, drop the dead labels

**Files:**
- Modify: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_stat_bars` → `fill_stat_bars`)
- Modify: `tests/test_student_card_layout.gd`, `tests/test_student_card.gd` (doc comment)
- Regenerate: `ci/clean_code_baseline.gd`

- [ ] **Step 1 [code]: Confirm what is dead**

Read `build_stat_bars`. It unconditionally removes each bar's `Label`,
`ValueLabel` and `InfoIcon` children. `InfoIcon` no longer exists in any
scene. It also unconditionally rewrites each bar's anchors and four offsets
from `PILL_RECTS`, and sets `show_percentage = false`,
`mouse_filter = IGNORE` and `variation = &"StatPill"`. So the scene stores
children that never render and positions that are never used: the editor
shows the bars where the player never sees them. If any path keeps any of
this, this task stops.

- [ ] **Step 2 [editor]: Restart, then fix the template's bars**

Restart the editor (Task 6 patched scripts). In `StudentCardPaper.tscn`:

- Delete the `Label` and `ValueLabel` children of all five bars.
- On each bar, set `layout_mode 0`, anchors `0`, and offsets equal to its
  `PILL_RECTS` rect: `Akademis` 284,763 → 495,830; `SeniBudaya` 284,888 →
  495,955; `Olahraga` 284,1014 → 495,1081; `Mood` 716,762 → 927,829;
  `Energy` 717,888 → 928,955. Also set `show_percentage = false`,
  `mouse_filter = 2`, and the `StatBar` export `variation = &"StatPill"`.
  `category` stays as is.

`scene_save`. `StatBar.gd` is `@tool`, so review the diff for baked
`theme_type_variation`/`self_modulate` lines. A resolved
`StatPill<Category>` variation is expected. Anything else is not.

- [ ] **Step 3 [code]: Tests**

In `tests/test_student_card_layout.gd`:

- `test_bars_carry_no_text_children` keeps its name. It asserts, on the
  instantiated template, that each of the five bars is a `StatBar` with
  `variation == &"StatPill"` and that no child is a `Label`. Keep the
  negative source scan for `val_lbl.text`.
- `test_the_pill_no_longer_takes_input` checks each template bar's
  `mouse_filter == MOUSE_FILTER_IGNORE`. Keep the `icon_magnify` negative
  scan.
- Add `test_the_pills_are_authored_on_their_painted_tracks`: each template
  bar's `get_rect()` `is_equal_approx` `_EXPECTED_PILLS[bar_name]`.
- `test_trait_pills_do_not_overlap_neighbors`: the authored rect is now the
  drawn rect. `_resolved_rect` reads `get_rect()` for every node, and the
  comment block explaining the `PILL_RECTS` special case goes. Keep
  `test_pill_rects_match_the_painted_tracks` as is: `PILL_RECTS` stays as
  the documented measurement.

In `tests/test_student_card.gd`, update the doc comment's
`build_stat_bars()` mention to `fill_stat_bars()` / `_STAT_KEYS`.

- [ ] **Step 4 [code]: Replace the builder with a filler**

```gdscript
## Bar node -> the roster key it shows, straight through: the Mood bar
## shows mood and the Energy bar energy.
const _STAT_KEYS := {
	"Akademis": "akademis",
	"SeniBudaya": "seni_budaya",
	"Olahraga": "olahraga",
	"Mood": "mood",
	"Energy": "energy",
}


## Writes each stat into its pill. The pills' geometry, their look and
## their inertness are StudentCardPaper properties; the icon beside each
## one carries the tap.
static func fill_stat_bars(kertas: Control, student: Dictionary) -> void:
	for bar_name: String in _STAT_KEYS:
		var bar := kertas.get_node_or_null(bar_name) as StatBar
		if bar == null:
			push_error("StudentCardView: %s has no StatBar %s" % [kertas.name, bar_name])
			continue
		bar.set_stat(float(student.get(_STAT_KEYS[bar_name], 0)))
```

Delete `build_stat_bars`, and call `fill_stat_bars(card, student)` from
`populate()`. The unused `_on_bar_input` parameter goes with it. Keep
`PILL_RECTS` and its doc, reworded: the template's bar rects and icon
positions are measured from it, and the tests pin both against it.
Update the `populate()` comment that points at `build_stat_bars()`.

- [ ] **Step 5 [editor]: Reload and verify**

```
test_run(suite="student_card_layout")
test_run(suite="student_card")
test_run(suite="report_card")
test_run(suite="viewport_editability")
test_run(suite="clean_code")
```

- [ ] **Step 6 [code]: Lock in the shrink**

Dump. Expected diff: `StudentCardView.gd`'s `UNTYPED` −2 (`bar`, `stale`
are gone), to about 3; `BARE_NUMBERS` unchanged or lower. Nothing else
moves. **[editor]:** no-op `script_patch` of the baseline; `clean_code`
green. Build check: the pills sit on their painted tracks and fill per
student on both screens. Open the template in the editor and check the
bars now show on the tracks.

- [ ] **Step 7 [code]: Commit**

```
git add Scenes/StudentCard/StudentCardPaper.tscn Scripts/StudentCard/StudentCardView.gd tests/ ci/clean_code_baseline.gd
```
Message:

```
refactor(studentcard): the pills live where they are drawn

Every bar carried Label and ValueLabel children that build_stat_bars
destroyed on load, and sat at a position it overwrote from PILL_RECTS,
so the editor showed the pills where the player never saw them. The
template now holds the real rects, the StatPill look and the inert mouse
filter; the view only writes values.
```

---

## Task 8: Close out

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`,
  `docs/superpowers/design/authoring-guide.md`, `CLAUDE.md`

- [ ] **Step 1 [code]: Count what remains**

```
grep -n "\.new()" Scripts/StudentCard/StudentCardView.gd
```
Expect no visual-type hits. `viewport_editability` no longer lists the file.
If anything remains, a step above regressed. Stop, and never raise the
number.

- [ ] **Step 2 [code]: Docs**

- `docs/superpowers/CHANGELOG.md`, newest first: one entry, "Student card
  template (Warm UI, Part 2, second half)". Cover the template on both
  screens, the icons, bio panel and bar geometry as scene data, the ratchet
  (StudentCardView 5 → gone), the inverted tests, and the dead code removed
  (`KutuBuku` Label branches, `InfoIcon`).
- `docs/superpowers/design/authoring-guide.md`, "Known gaps": remove
  `StudentCardView.gd` from the list of remaining files.
- `docs/superpowers/DEBT.md`, under "Known bugs and gaps": the StudentCard
  tutorial's two "Efek Quirk"/"Efek Persona" steps target
  `KertasMurid1/PopupCanvas/TraitOverlay/TraitPopupPanel`, which names no
  node, so those steps highlight nothing. The fix lives in `StudentCard.gd`,
  which is at its `LARGE_SCRIPTS` cap, so it has to come out of an
  extraction. Delete any DEBT line this plan resolved.
- `CLAUDE.md`: update the "N suites, M tests (date)" line from Step 3's full
  run. No new suite is added, only tests, so N stays 161.

- [ ] **Step 3 [editor]: Full run**

Restart the editor, open `Scenes/MainMenu/MainMenu.tscn`, then `test_run()`.
Budget the restart the bridge drop costs. All green. Afterwards run
`git status`: `checkout --` any unintended `kejartes_theme.tres` rebake or
`default_bus_layout.tres` rewrite.

- [ ] **Step 4 [code]: Commit, then ship**

```
git add docs/ CLAUDE.md
```
Message: `docs(studentcard): record the card template pass`. Then finish the
branch with the `ship-pr` skill. It runs the full suite and a local review,
opens the PR and stamps the tested commit. Bind the PR right after
`gh pr create`.

---

## Self-Review

**Spec coverage.** Walked the rewritten Part 2. Arrows → Task 1. Backdrop →
Task 2. Bio readability → Task 3. Template extraction → Task 4. Runtime
construction (findings 6 and 9) → Tasks 5, 6, 8. Dead labels (finding 7) →
Task 7. Deliberately **not** covered, per the agreed scope: the portrait/identity
swap and single-column stats, both of which would require re-authoring the
painted tracks and re-measuring `PILL_RECTS`. Finding 8 (`Aprove`/`Batal`'s
messy swap) is recorded but not acted on — it is behavioural, not visual.
*(2026-09-28: the portrait/identity swap shipped anyway, in `01741ea6`.
Runtime construction is now Tasks 5 and 6, each lowering its own share.
Task 7 also covers the dead bar geometry. Task 8 is the close-out.)*

**Placeholders.** Three deliberate derive-at-implementation points, each with a
step that produces the value: the chevrons' rendered appearance (Task 1 step 3),
the repainted frame's exact painted bounds (Task 3 step 1), and the final
`.new()` count (Task 8 step 1). No invented numbers.
*(2026-09-28: the icon, badge, bio and bar rects are now given as numbers,
derived from today's `PILL_RECTS`, `BIO_PANEL_RECT` and the view's
`_ICON_*`/`_BADGE_*`/`_BIO_PADDING` constants. The clean-code baseline's
exact new figures come from the dump.)*

**Type consistency.** `CardArrowButton` is spelled identically in the test,
`_build_buttons`, `RADIUS_EXEMPT` and `DISPLAY_ROSTER`. `BIO_PANEL_RECT` and
`PILL_RECTS` keep their current values throughout — no task changes either.
*(2026-09-28: `StudentCardPaper`, `wire_icon_clusters`, `fill_bio_panel`,
`fill_stat_bars`, `_STAT_KEYS`, `_BIO_VALUES`, `_TAP_META`, `_PULSE_META`,
`%NamaValue`/`%JenisKelaminValue`/`%TanggalLahirValue` and
`Icon<Bar>`/`InfoBadge` are spelled the same in every step and snippet.
`populate()`'s signature is unchanged.)*

**The known risk.** Tasks 5 and 6 invert four source-scan tests that currently
pin builder functions. That is the largest single cost in this plan and the most
likely place to lose coverage by accident. Each of those steps says explicitly:
invert the assertion, never delete the test.
*(2026-09-28: add Task 4's scene-text scans and Task 7's two bar scans, nine
in all. Each keeps its name and gains a behavioural assertion. The second
risk is the extraction itself, on two scenes: Task 4 converts both, and it
checks that the per-instance `Aprove`/`Batal` actually serialised before
anything else builds on the template.)*
