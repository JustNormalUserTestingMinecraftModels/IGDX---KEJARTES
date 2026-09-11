# Koperasi rework — Part 2 handover

**For a team picking this up cold.** Part 1 shipped on 2026-09-11 as
PR #15 (`feat/koperasi-rework` → `Textures`). This document is what you
need to finish the job without repeating our mistakes.

Read alongside:

- **Spec (binding authority):** `docs/superpowers/specs/2026-09-11-koperasi-rework-design.md`
- **Part 1 plan:** `docs/superpowers/plans/2026-09-11-koperasi-rework.md`
- **Part 1 ledger, verbatim:** `docs/superpowers/handover/2026-09-11-koperasi-part-1-ledger.md`
  (every decision made and why, preserved here because the working copy
  lived in the git-ignored `.superpowers/` scratch directory)

---

## Where Part 1 got to

Full suite **1309/1309 green** across 92 suites, verified in the running
game, pushed, PR open, not merged.

**Delivered:**

- `PriceTag.tscn` / `PriceTag.gd` — a green coin pill showing the price.
  On purchase a dark green wipe crosses left-to-right over `dur_fast`
  (0.18s) and the label swaps to **Beli** with a scale pop starting at
  0.23s. Unaffordable items grey out via the `PriceTagDisabled`
  variation but keep showing their price.
- `ShelfItem.gd` — per-item shadow, idle bob at a random phase, lift on
  press, dim when unaffordable.
- `Assets/Images/Shop/UI/icon_keranjang.svg` — a drawn slatted market
  basket replacing the stock `pngwing.com (6).png` silhouette, on
  `KeranjangDepan.texture_normal`.
- Four theme variations: `PriceTag`, `PriceTagPressed`,
  `PriceTagDisabled`, `BasketTray`, in `ThemeFactory._add_koperasi_variations`.
- `ReturSlot.tscn` / `ReturSlot.gd` — the return-popup row as a
  PackedScene, replacing `_add_retur_entry`'s runtime construction.
- Tray dressing in `koprasi.tscn`: a `Sheet` Panel on `BasketTray`, a
  `Dots` tiling texture, a `WarmWash` ColorRect over the existing blur,
  and an `EmptyState` node.
- Six emoji removed from the shop scripts.
- `tests/test_koperasi_tray.gd` — 26 tests.

**Debt went down.** `rakbarang_1.gd`'s entry in
`tests/test_viewport_editability.gd` dropped **7 → 2**, and every
`add_theme_*` call is gone from that file. That ratchet is one-way:
never raise it.

**Untouched, and must stay untouched.** The pick-item → arc-into-basket
flight: `_spawn_falling_item`, `_on_item_landed`, `_on_item_icon_input`,
`_add_item_visual`, `clear_basket_visuals` in `rakbarang_1.gd`. The
mentor approved this behaviour explicitly. Re-point it at new nodes if
you must, but do not rewrite its semantics.

---

## Part 2 scope — what is actually left

### 1. The tray layout (the main job)

Part 1 delivered the tray's **surface** but not its **layout**. The
mentor picked layout option "L3 — basket tray", and the spec's section 1
describes it. Three pieces are missing:

- **Items bottom-aligned at their own heights, as physical objects.**
  `ReturSlot.tscn` is currently a fixed `300×380` cell with
  `alignment = 1` (centred), so items sit in a uniform grid — the exact
  thing L3 was chosen to avoid. They should stand on a shelf-plank rule
  at their natural heights, the way `BasketArea` already scatters landed
  items.
- **A `Total` + `Beli` row beneath the tray.** `Total` on the left, a
  single `PrimaryButton` reading `Beli` on the right. The Beli button is
  theme chrome — no new art. There is currently a `BELI` button
  (`Rak1/TextureButton`) sitting loose on the shelf; decide whether that
  becomes the tray's button or stays separate.
- **The tray peeks at the bottom** rather than opening as a centred
  panel. `ReturPanel`'s offsets in `koprasi.tscn` are unchanged from the
  old popup (`-134, -834` to `811, -204`, relative to `KeranjangDepan`).

Note that `_populate_retur_panel` currently fills a `GridContainer`
inside a `ScrollContainer`. A bottom-aligned physical layout probably
wants neither.

### 2. Rim glow on press

Spec section 4 calls for "lift plus rim glow on press". `ShelfItem.lift()`
does the lift; there is no glow.

### 3. Missing test coverage named by the spec

The spec's Testing section names a **total calculation** test that does
not exist. Empty-state coverage was added late in Part 1
(`test_shop_shows_a_scene_empty_state_not_a_built_label`) but only as a
source scan.

### 4. Deferred minors from Part 1

None of these block anything; triage them as you go.

- `_add_koperasi_variations` in `ThemeFactory.gd` ignores its `tokens`
  parameter — all seven colours and every radius are inline literals.
  This was deliberate (see Ruling: a new `@export` default on a Resource
  needs a full editor restart to take effect, which would have stranded
  a single sitting). **Promoting them to `DesignTokens` is a clean Part 2
  task** — just budget the restart.
- `PriceTag.gd` sets `MOUSE_FILTER_IGNORE` in `_ready()` rather than in
  the scene, because the MCP bridge was down when that fix landed. Moving
  it into `PriceTag.tscn` is tidier.
- The SVG `<text>` scan checks `<text` only, not `<tspan` or `<use>`.
- `ReturSlot.tscn` picked up a `uid=` addition on its Script
  ext_resource from an editor reimport — harmless.
- **Open visual question:** after an item lands, it sits in `BasketArea`
  *behind* `KeranjangDepan` (z_index 100), so the basket looks empty.
  This is pre-existing behaviour, but the new basket art may hide items
  more than the old silhouette did. Worth a look with the mentor.

---

## Decisions already made — do not re-litigate

The ledger has all twenty with full reasoning. These are the ones that
will bite you if you undo them:

| Decision | Why |
|---|---|
| `ShelfItem`'s shadow is built at runtime | The shelf is randomised at runtime by `ItemDatabase.get_random_items`, so it cannot be static chrome. Routed to `viewport_editability`'s `ALLOWED`, not `BASELINE`. |
| `ReturPanel` gets a `Sheet` Panel child, not a retype | It is a `TextureRect` with no texture. Retyping means re-parenting `ScrollContainer` and `BackButton`. Same pattern as StudentList's `RosterCard`. |
| `WarmWash` is a separate ColorRect, not a tint on `BlurRect` | `BlurRect` carries the blur ShaderMaterial; a 10%-alpha colour multiplies the shader output down and destroys the blur. |
| The wipe lives under `WipeHost`, a plain `Control` | Containers call `fit_child_in_rect` on direct children every sort, and `play_buy()` changes the label text, which queues a sort. As a direct child the tweened width was stomped instantly. `test_price_tag_wipe_node_resolves` guards this. |
| Tag colours are inline hex, not tokens | See deferred minors above. |
| `texture_repeat = 2` on the `Dots` node | In Godot 4 repeat is a `CanvasItem` property. It was an import flag in Godot 3 only; `tray_dots.png.import` has no repeat param at all. |

---

## Traps that cost us hours — read this before you start

These are environment behaviours, not opinions. Each one burned real time.

**1. `assert_not_null` does not halt the test.** It records a failure and
execution continues, so the next line crashes on the null and the real
assertion never reports. Always follow it with `if x == null: return`.

**2. `Theme.get_stylebox()` falls back to the base type's stylebox**
rather than returning null. This project's cream `Panel` box is itself a
warm light `StyleBoxFlat`, so a colour assertion on a variation that does
not exist **passes vacuously**. We shipped such a test and only caught it
because the red step was run properly. Always
`assert_true(theme.has_stylebox("panel", "<Variation>"))` first.

**3. A plain `load()` on the baked theme returns the editor's startup
copy**, not the freshly rebaked file. Use
`ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`. The
project documents this at `tests/test_theme_factory.gd:363`.

**4. Source-text scans cannot catch a wrong identifier.**
`GameState.money` does not exist (it is `player_money`) and it crashed
the shop on entry **while the entire suite was green**, because the tests
only asserted that certain strings appeared.
`test_shop_scripts_only_use_real_gamestate_members` now resolves every
`GameState.<name>` against the live autoload. Prefer that shape.

**5. `load(...).instantiate()` on a missing scene aborts with zero
assertions**, which reads as a broken test rather than a failing one.
Assign, assert non-null, return early, then instantiate.

**6. Suite names drop the `test_` prefix** — `test_run(suite="koperasi_tray")`,
not `"test_koperasi_tray"`. And **every suite must override
`suite_name()`** or it registers as `'unnamed'` and cannot be targeted.

**7. `var x := node.get_node_or_null(...)` is a parse error** when the
receiver is untyped — GDScript cannot infer. Use plain `=`.

**8. `\.` inside a normal string literal is an invalid escape.** Use a
raw string: `r"GameState\.(...)"`.

**9. A full `test_run` reliably drops the MCP bridge.** It happened twice
in one session, both times needing an editor restart. Prefer targeted
`test_run(suite=...)`; budget a restart for each full run and take them
at milestones.

**10. `batch_execute` parameter names are not what you would guess.**
`attach_script` takes `path` **and** `script_path`; `set_property` takes
`path` (not `node_path`); `create_node` takes `type` and `name` (not
`node_type`/`node_name`); `move_node` takes `index`; `reparent_node`
takes `new_parent`.

**11. Buttons must land on the S/M/L scale** — `btn_h_s` 96, `btn_h_m`
128, `btn_h_l` 160. `test_button_geometry` enforces it. Moving a
runtime-built button into a scene exposes its old off-scale height.

**12. Check `git diff HEAD -- '*.gd'` after every `scene_save`.** The
editor writes open script tabs back over whatever you patched. Do scene
work first, script work second.

---

## How to verify your work

Targeted first, full run at milestones:

```
test_run(suite="koperasi_tray")
test_run(suite="koperasi")
test_run(suite="viewport_editability")
test_run(suite="button_geometry")
test_run(suite="script_documentation")
```

Then in-game, which is where Part 1's real bugs surfaced:

```
project_run(mode="custom", scene="res://Scenes/Koperasi/koprasi.tscn")
```

Tap `KEBUTUHAN SEKOLAH` to open the shelf. Debug overlay is `F1` →
General → `+1000G` to make items affordable. **Tap directly on a price
pill**, not on the item art — that path was completely dead until review
caught it, and no test saw it.

Rescale coordinates: `global_rect` is in the 1080-wide design space while
input events take window pixels, so
`window_x = global_x * original_width / 1080`. Send a `motion` event
before the `button` press or Godot will not route the click.

---

## Suggested order

1. Promote the tag colours to `DesignTokens` — small, and it forces the
   editor restart early rather than mid-flow.
2. The `Total` + `Beli` row. Self-contained, and it gives the mentor
   something concrete to react to.
3. The bottom-aligned item layout. The biggest piece; screenshot it for
   the mentor before polishing.
4. The peeking tray position. Do this after 3, since it changes the rect
   the layout lives in.
5. Rim glow, then the remaining test coverage.

Get a screenshot review from the mentor after step 3. The layout is the
part they picked from a sketch, and it is the part most likely to need a
round trip.
