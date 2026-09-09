# Warm UI System — Part 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

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
  the whole tree and will catch it. Use a `ThemeFactory` variation.
- **No `Color(...)` literal in `student_card.gd`** — `test_no_hardcoded_colors_remain_in_the_script`.
- Every script needs a `##` file header; every `@export` a `##` line.
- Game-facing UI text is **Indonesian**; systems code is English.
- **No emoji as UI iconography.**
- `Scripts/Balance.gd` is a collaborator's — never edit.
- **Rescan after editing a `.gd` before running tests**; a no-op `script_patch`
  forces a reload when the edit came from outside the editor.
- **Scene work first, script work second.** `scene_save` flushes stale `.gd`
  buffers; check `git diff HEAD -- '*.gd'` after every save.
- **The MCP bridge is single-client.** Subagents write code; the controller runs
  the editor and feeds results back.
- The editor hangs roughly once per task cycle (~1.5 GB). Recycle it with
  `Godot_v4.6.2-stable_win64.exe --path <proj> --editor`.

---

## Two independent halves

**Tasks 1–3 are cosmetic, cheap, and touch no constants or pinned geometry.**
They can ship alone and address everything the mentor actually reported.

**Tasks 4–8 are the architectural half.** They pay down tracked debt but require
the template extraction first and invert several source-scan tests. Stop after
Task 3 if the cost stops being worth it — the plan is deliberately cut here.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `Assets/Images/UI/Nav/icon_chevron_left.png` / `_right.png` | arrow glyphs | **Create** |
| `Assets/Images/UI/meja_background.png` | neutral oak backdrop | Replace in place |
| `Assets/Images/StudentCard/card_bg.png` | bio panel frame recolour only | Modify |
| `Scripts/Design/ThemeFactory.gd` | `CardArrowButton` variation | Modify |
| `Scenes/StudentCard/StudentCardPaper.tscn` | the one card template | **Create** |
| `Scenes/StudentCard/student_card.tscn` | six instances of the template | Modify |
| `Scripts/StudentCard/StudentCardView.gd` | shrink to data-binding only | Modify |
| `tests/test_student_card_layout.gd` | invert the builder-pinning scans | Modify |
| `tests/test_viewport_editability.gd` | lower `BASELINE` from 5 | Modify |

---

## Task 1: Chevron arrows

**Files:**
- Create: `Assets/Images/UI/Nav/icon_chevron_left.png`, `icon_chevron_right.png`
- Modify: `Scripts/Design/ThemeFactory.gd` (`CardArrowButton`)
- Modify: `Scenes/StudentCard/student_card.tscn` (`NextButtonKanan`, `NextButtonKiri`)
- Modify: `tests/test_button_geometry.gd`

**Interfaces:**
- Consumes: `tokens.radius_pill`, `brand_primary`, `outline_card`, `shadow_*`.
- Produces: theme type `CardArrowButton`.

- [ ] **Step 1: Write the failing test**

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

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="button_geometry")
```
Expected: FAIL — `CardArrowButton/normal must be a StyleBoxFlat` (the type does
not exist yet).

- [ ] **Step 3: Generate the two chevron assets**

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

- [ ] **Step 4: Build the variation**

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

- [ ] **Step 5: Wire the two buttons in the scene**

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

- [ ] **Step 6: Rebake, verify, commit**

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

**Files:**
- Modify: `Assets/Images/UI/meja_background.png` (replace in place)

**Interfaces:** none — the filename is unchanged so no reference moves.

- [ ] **Step 1: Measure the current backdrop**

```
mean luminance 130/255, ranges #E6A57D -> #884119
```
Confirm with a `System.Drawing` sample before replacing, so the improvement is
measured rather than asserted.

- [ ] **Step 2: Author the replacement**

1080×1920, pale oak, low saturation, **target mean luminance ~190**, gentle
grain, no strong vertical gradient. Keep the filename — nothing else changes.

The defect being fixed: the backdrop is more saturated than the mint `#D1F5E2`
card sitting on it, and the two hues are near-complementary, which is what makes
the card read dead.

- [ ] **Step 3: Verify and commit**

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

**Files:**
- Modify: `Assets/Images/StudentCard/card_bg.png`

**Interfaces:** **`BIO_PANEL_RECT` does not change.** Only the pixels inside the
existing frame change colour.

- [ ] **Step 1: Confirm the rect before touching the art**

`BIO_PANEL_RECT := Rect2(120, 300, 489, 367)` is the painted panel's measured
interior, pinned by `test_bio_panel_sits_inside_the_painted_panel`. Sample
`card_bg.png` around that rect to find the frame's exact painted bounds.

- [ ] **Step 2: Recolour the frame in place**

Replace the `#C6B6EE` → `#9C8FBB` lavender gradient with a warm surface from the
token palette — `surface_sunken` `#EFE0CB` with an `outline_card` `#FFF6E8` rim
reads correctly against the warm chrome and gives the runtime text far more
contrast than lavender did.

**Do not move, resize or restyle the frame's geometry.** Same rect, different
colour. Anything else invalidates `BIO_PANEL_RECT` and its pinning test.

- [ ] **Step 3: Check the text still reads**

The bio text uses the `BioLabel` variation. Against a cream panel its colour may
now need to be `text_primary` rather than whatever it was on lavender. Check in a
running build and adjust the *variation*, never a `theme_override_*`.

- [ ] **Step 4: Verify and commit**

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

## Task 4: Extract the card template

**Files:**
- Create: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scenes/StudentCard/student_card.tscn`

**Interfaces:**
- Produces: a `StudentCardPaper` scene instanced six times as `KertasMurid1`..`6`.

- [ ] **Step 1: Confirm the extraction is safe**

`student_card.gd` addresses card internals by string —
`"KertasMurid1/Kepribadian1"`, `"KertasMurid1/KutuBuku"` — and
`test_tutorial_target_node_paths_are_unchanged` pins exactly those. Those paths
resolve as *instance name + child name*, so instancing the template six times
with child names preserved leaves every string valid.

Verify by grepping every string path in `student_card.gd` and listing them, before
building anything.

- [ ] **Step 2: Build the template from KertasMurid1**

Through the editor, save `KertasMurid1`'s subtree as
`Scenes/StudentCard/StudentCardPaper.tscn`. **Every child name must be preserved
exactly** — `Kepribadian1`, `Kepribadian2`, `Akademis1`..`3`, `KutuBuku`,
`KutuBuku2`, `Aprove`, `Batal`, `SifatPasifLabel`, `TextureRect`.

- [ ] **Step 3: Replace all six copies with instances**

Keep the instance names `KertasMurid1`..`KertasMurid6`.

**Per-card differences must become instance overrides on the ROOT.** The project
rule is that overrides serialise only on an instanced scene's root — setting a
property on an instance's *child* reports success and is silently dropped on
save. If a per-card difference lives on a child (e.g. the portrait texture),
give the template root an `@export` for it and drive the child from there.

- [ ] **Step 4: Verify the six cards are still identical and complete**

```
test_run(suite="student_card")
test_run(suite="student_card_layout")
test_run()
```
`test_every_trait_pill_shares_one_geometry` and
`test_every_card_is_exactly_the_texture_size` are the two that will catch a
botched extraction. `test_trait_pills_do_not_overlap_neighbors` instantiates all
six.

Then run the tutorial in a real build — the string paths must resolve at
runtime, not just in a test.

- [ ] **Step 5: Commit**

```bash
git add Scenes/StudentCard/
git commit -m "refactor(studentcard): one card template instanced six times

1,400 lines of near-identical .tscn become one template. The tutorial
addresses cards by string path; those resolve as instance name plus
child name, so preserving child names keeps every path valid."
```

---

## Task 5: Move the icon clusters into the template

**Files:**
- Modify: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_icon_clusters`)
- Modify: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: Task 4's template.
- Removes: two `.new()` sites (`TextureRect` icon, `TextureRect` badge).

- [ ] **Step 1: Understand what must invert**

`test_icon_clusters_exist_and_meet_the_touch_target` and
`test_info_badge_draws_its_asset_untinted` are **source scans that pin the
builder**. Moving the nodes into the template makes the builder disappear, so
these tests must be rewritten to assert the *nodes* exist in the scene with the
right size and texture — a strictly stronger assertion than "a function exists".

Do not delete either test. Invert it.

- [ ] **Step 2: Add the ten nodes to the template**

Five `Icon<BarName>` `TextureRect`s, each with an `Info` badge child, at the
positions `build_icon_clusters` currently computes from `PILL_RECTS`,
`_ICON_SIZE` (128), `_ICON_GAP` (24) and `_BADGE_SIZE` (56).

The set of five and their positions are **identical for every student** — that
is what makes them static chrome rather than dynamic content.

- [ ] **Step 3: Reduce the builder to wiring**

`build_icon_clusters` keeps binding the tap `Callable` to each icon, but stops
creating nodes. If nothing remains but `get_node`, delete the function and move
the binding into `populate()`.

- [ ] **Step 4: Rewrite the two tests**

Assert against the scene: five `Icon*` nodes exist per card, each ≥
`tokens.touch_target_min`, each carrying its `_STAT_ICONS` texture, each with an
untinted `Info` child (`modulate == Color.WHITE`).

- [ ] **Step 5: Verify and commit**

```
test_run(suite="student_card_layout")
test_run(suite="viewport_editability")
test_run()
```

```bash
git add Scenes/StudentCard/ Scripts/StudentCard/StudentCardView.gd tests/
git commit -m "refactor(studentcard): icon clusters become template nodes

The five stat icons and their (i) badges did not exist in the scene at
all -- a screenshot showed them, the .tscn did not. Their set and
positions are identical for every student, so they are static chrome.
Their two pinning tests now assert the nodes rather than the builder."
```

---

## Task 6: Move the bio panel structure into the template

**Files:**
- Modify: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_bio_panel`)
- Modify: `tests/test_student_card_layout.gd`

**Interfaces:**
- Removes: three `.new()` sites (`VBoxContainer`, heading `Label`).
- **Keeps one:** the *value* labels stay dynamic.

- [ ] **Step 1: Split static from dynamic — this is the whole task**

Of `build_bio_panel`'s work:
- the `VBoxContainer`, its rect, and the three **headings** ("Nama:",
  "Jenis Kelamin:", "Tanggal Lahir:") are **static** — same on every card
- the three **values** (`name`, `jenis_kelamin`, `tanggal_lahir`) are **per
  student** and must stay code-driven

So the template gains a `BioPanel` VBox with three heading/value `Label` pairs;
`populate()` writes only the three value texts.

- [ ] **Step 2: Position the panel from the constant, once**

The template's `BioPanel` takes the rect `BIO_PANEL_RECT` currently computes
(`Rect2(120, 300, 489, 367)` inset by `_BIO_PADDING`). Author it once in the
scene rather than recomputing per call.

**Keep `BIO_PANEL_RECT` as a documented constant** even once the scene owns the
geometry — it records where the painted panel is, which is knowledge the art
depends on, and Task 3's repaint must agree with it.

- [ ] **Step 3: Invert the two pinning tests**

`test_bio_panel_renders_the_three_rows` currently asserts `build_bio_panel(`
exists and the three headings appear in the *script*. Rewrite it to assert the
three headings exist as `Label` nodes in the template.

`test_bio_panel_sits_inside_the_painted_panel` currently asserts four offset
lines derive from `BIO_PANEL_RECT` *in the script*. Rewrite it to assert the
scene's `BioPanel` rect sits inside `BIO_PANEL_RECT` — behavioural, and a
stronger check than the source scan it replaces.

- [ ] **Step 4: Verify and commit**

```
test_run(suite="student_card_layout")
test_run()
```
Then run a build and page through several students — the values must still change
per student. That is the one thing these tests do not prove.

```bash
git add Scenes/StudentCard/ Scripts/StudentCard/StudentCardView.gd tests/
git commit -m "refactor(studentcard): bio panel structure moves into the template

The container and the three headings are identical on every card; only
the three values are per-student. Structure becomes scene data, values
stay code. Both pinning tests now assert the scene rather than the
builder's source text."
```

---

## Task 7: Remove the dead bar labels

**Files:**
- Modify: `Scenes/StudentCard/StudentCardPaper.tscn`
- Modify: `Scripts/StudentCard/StudentCardView.gd` (`build_stat_bars`)

- [ ] **Step 1: Confirm they are genuinely dead**

Every `ProgressBar` in the scene still carries `Label` and `ValueLabel` children
which `build_stat_bars()` **deletes at runtime**. The scene stores nodes that
never render.

Verify by reading `build_stat_bars` and confirming the deletion is
unconditional — if any path keeps them, they are not dead and this task stops.

- [ ] **Step 2: Delete them from the template, and the deletion code with them**

One template edit removes them from all six cards. Then remove the runtime
deletion loop, which now has nothing to delete.

`test_bars_carry_no_text_children` already asserts no bar carries text — it
should keep passing, and now passes because the nodes are absent rather than
because they are destroyed on load.

- [ ] **Step 3: Verify and commit**

```
test_run(suite="student_card_layout")
test_run()
```

```bash
git add Scenes/StudentCard/ Scripts/StudentCard/StudentCardView.gd
git commit -m "refactor(studentcard): drop the bar labels the view deleted anyway

Every ProgressBar carried Label and ValueLabel children that
build_stat_bars destroyed on load. Removing them from the template
removes the deletion loop too."
```

---

## Task 8: Lower the ratchet

**Files:**
- Modify: `tests/test_viewport_editability.gd` (`BASELINE`)

- [ ] **Step 1: Count what actually remains**

```
grep -n "\.new()" Scripts/StudentCard/StudentCardView.gd
```
After Tasks 5–7, only the bio **value** labels should remain — expect **1**, or
0 if they became template nodes written by `populate()`.

- [ ] **Step 2: Lower `BASELINE` to the counted number**

`Scripts/StudentCard/StudentCardView.gd` is at **5**. Set it to what step 1
counted. **The ratchet only ever goes down** — if the number came out higher,
something regressed and this task stops rather than raising it.

- [ ] **Step 3: Verify and commit**

```
test_run(suite="viewport_editability")
test_run()
```

```bash
git add tests/test_viewport_editability.gd
git commit -m "test(ratchet): lower StudentCardView's runtime-construction baseline

Was 5. The icon clusters, info badges, bio container and bio headings
are all template nodes now; only the per-student values remain code."
```

---

## Self-Review

**Spec coverage.** Walked the rewritten Part 2. Arrows → Task 1. Backdrop →
Task 2. Bio readability → Task 3. Template extraction → Task 4. Runtime
construction (findings 6 and 9) → Tasks 5, 6, 8. Dead labels (finding 7) →
Task 7. Deliberately **not** covered, per the agreed scope: the portrait/identity
swap and single-column stats, both of which would require re-authoring the
painted tracks and re-measuring `PILL_RECTS`. Finding 8 (`Aprove`/`Batal`'s
messy swap) is recorded but not acted on — it is behavioural, not visual.

**Placeholders.** Three deliberate derive-at-implementation points, each with a
step that produces the value: the chevrons' rendered appearance (Task 1 step 3),
the repainted frame's exact painted bounds (Task 3 step 1), and the final
`.new()` count (Task 8 step 1). No invented numbers.

**Type consistency.** `CardArrowButton` is spelled identically in the test,
`_build_buttons`, `RADIUS_EXEMPT` and `DISPLAY_ROSTER`. `BIO_PANEL_RECT` and
`PILL_RECTS` keep their current values throughout — no task changes either.

**The known risk.** Tasks 5 and 6 invert four source-scan tests that currently
pin builder functions. That is the largest single cost in this plan and the most
likely place to lose coverage by accident. Each of those steps says explicitly:
invert the assertion, never delete the test.
