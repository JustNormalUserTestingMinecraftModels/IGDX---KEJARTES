# StudentCard architecture map (research only, no code changed)

## Top 5 surprises for someone who only read the .tscn + a screenshot

1. **The five stat "icons" and the (i) badges next to each pill do not exist
   in the .tscn at all.** They are built entirely at runtime in
   `StudentCardView.build_icon_clusters()` (`Scripts/StudentCard/StudentCardView.gd:189-230`)
   as siblings named `IconAkademis1`, `IconKepribadian1`, etc. A `.tscn`-only
   read would miss this class of visible element completely.
2. **The bio panel (Nama/Jenis Kelamin/Tanggal Lahir) is also 100% runtime-built** —
   a `VBoxContainer` named `BioPanel` created and repopulated on every
   `populate()` call (`StudentCardView.build_bio_panel()`, lines 243-278). Its
   surrounding rounded-purple frame is *painted into `card_bg.png`*, not a
   node — only the six lines of text are live nodes.
3. **The pill "tracks" (rounded dark bars behind each ProgressBar fill) are
   painted into `card_bg.png` too**, sampled and confirmed dark gray (~RGB
   43-59) rectangles at exactly the `PILL_RECTS` coordinates. The
   `ProgressBar`/`StatBar` nodes only supply the *fill*, positioned over the
   painted track by pixel-perfect offsets computed from `PILL_RECTS`.
4. **`Aprove` and `Batal` are not simple show/hide siblings** — they are two
   separately-positioned Buttons (`offset_top` 1560 vs 1622, an 80px vertical
   stagger baked into the scene) whose *visibility* is toggled in
   `_show_stamp_if_approved()`/`_on_approve_pressed()`/`_on_batal_pressed()`
   in `student_card.gd`. Batal additionally has grade-7-specific logic that
   keeps it hidden entirely for `GameState.grade7_student_ids` students even
   when approved (line 730-733) — a third state beyond simple swap.
5. **Every ProgressBar in the .tscn still carries its own `Label` (stat name)
   and `ValueLabel` (numeric readout) children as scene data** (e.g.
   `KertasMurid1/Akademis1/Label` = "AKADEMIS", `ValueLabel` = "65/65"). These
   are *removed at runtime* by `build_stat_bars()` (lines 154-158) — the
   "no text on pills" design is a runtime deletion, not something baked into
   the scene. A design revision that edits the `.tscn` alone to remove them
   would be redundant with (and potentially conflict with) that runtime code.

---

## A. Painted vs. Node vs. Built-at-runtime

| Element | Category | Evidence |
|---|---|---|
| Card background chrome (paper texture, bio panel frame, pill tracks, decorative borders) | **PAINTED** into `card_bg.png` | Sampled pixels confirm distinct painted regions at `BIO_PANEL_RECT` and `PILL_RECTS` coordinates (see section C). `KertasMurid1` node itself is a `TextureRect` with `texture = ExtResource("8_hodfn")` (student_card.tscn:1204), 1080×1920, i.e. the full card art. |
| Portrait (`TextureRect` child of each `KertasMurid`) | **NODE** | `student_card.tscn:1206-1216`, populated by `StudentCardView.populate()` line 72-76 (`card.get_node_or_null("TextureRect")`). |
| Bio panel text (Nama/Jenis Kelamin/Tanggal Lahir headings+values) | **BUILT AT RUNTIME** | `StudentCardView.build_bio_panel()`, `.gd:243-278`, creates a `VBoxContainer` "BioPanel" + 6 `Label`s each call. Not present anywhere in the `.tscn` (confirmed absent from the KertasMurid1 node dump). |
| Bio panel frame/border | **PAINTED** | Part of `card_bg.png`; only text is a node/runtime, per pixel sample in section C. |
| Five stat pill tracks (dark bar behind each fill) | **PAINTED** | `card_bg.png`, confirmed by pixel sampling at `PILL_RECTS` — dark ~RGB(43-59) rectangles. |
| Five stat pill fills (`Akademis1/2/3`, `Kepribadian1/2`) | **NODE** (ProgressBar / StatBar subclass) | `student_card.tscn:1254-1406` (declared as `ProgressBar` with `script = ExtResource("statbar")`), repositioned/restyled at runtime by `StudentCardView.build_stat_bars()` (`.gd:125-164`) using `PILL_RECTS`. |
| Stat name Label / ValueLabel on each bar | **NODE in .tscn, deleted at runtime** | Declared in `.tscn` (e.g. `KertasMurid1/Akademis1/Label` text="AKADEMIS", `.../ValueLabel` text="65/65"), removed by `build_stat_bars()` lines 154-158 (`bar.remove_child(stale); stale.queue_free()`). |
| Five stat icons + (i) info badges | **BUILT AT RUNTIME** | `StudentCardView.build_icon_clusters()`, `.gd:189-230`. Creates `TextureRect` named `Icon<BarName>` + child `TextureRect` "InfoBadge", loading `Assets/Images/StudentCard/stat_*.png` and `icon_info.png`. Not in `.tscn`. |
| `KutuBuku` / `KutuBuku2` trait pills | **NODE** | `student_card.tscn:1226-1252`, type `Button`, styled at runtime (`_style_trait_badge`, `.gd:281-303` sets text/variation/wiggle) but the node itself lives in the scene. |
| `SifatPasifLabel` ("Sifat Pasif:" heading) | **NODE** | `student_card.tscn:1217-1224`, static Label, not touched by `StudentCardView`. |
| `PageLabel` | **NODE**, text set at runtime | `student_card.tscn:1504-1510` (scene-root child, empty by default), text set in `student_card.gd:_update_page_label()` line 716-717 (`"1/6"` etc.). |
| `Aprove` / `Batal` buttons | **NODE** | `student_card.tscn:1408-1425`, per-card, visibility toggled by `student_card.gd`. |
| `NextButtonKanan` / `NextButtonKiri` | **NODE** | `student_card.tscn:1427-1447`, scene-root. |
| `BelajarButton`, `PilihMurid`, `ColorRect`/`ClickArea` (tutorial scrim), `StampApprove` | **NODE** | `student_card.tscn:1449-1503`, scene-root children. |
| `Backdrop` | **NODE** | `student_card.tscn:38-48`, scene-root `TextureRect`. |

---

## B. Constants measured from the artwork

| Constant | Value | Measured against | Pinning test | Assertion quoted |
|---|---|---|---|---|
| `PILL_RECTS` (StudentCardView.gd:112-118) | `Akademis1: Rect2(284,763,211,67)`, `Akademis2: Rect2(284,888,211,67)`, `Akademis3: Rect2(284,1014,211,67)`, `Kepribadian1: Rect2(716,762,211,67)`, `Kepribadian2: Rect2(717,888,211,67)` | Painted pill tracks in `card_bg.png` at native 1080×1920 | `tests/test_student_card_layout.gd::test_pill_rects_match_the_painted_tracks` (line 109-114) | `assert_eq(StudentCardView.PILL_RECTS[bar_name], _EXPECTED_PILLS[bar_name], "PILL_RECTS[%s] must sit on the painted track" % bar_name)` |
| `BIO_PANEL_RECT` (StudentCardView.gd:235) | `Rect2(120, 300, 489, 367)` | Painted purple bio panel interior in `card_bg.png` | `tests/test_student_card_layout.gd::test_bio_panel_sits_inside_the_painted_panel` (line 227-246) | `assert_true(src.contains("const BIO_PANEL_RECT := Rect2(120, 300, 489, 367)"), "BIO_PANEL_RECT must match the painted panel's measured interior")` |
| `_BIO_PADDING` | `32.0` | Inset from `BIO_PANEL_RECT` so text doesn't crowd the rounded border | Same test above (checks the four offset lines derive from `BIO_PANEL_RECT ± _BIO_PADDING`) | — |
| `_ICON_SIZE` | `128.0` | Icon cluster square size (not directly art-measured; chosen to clear touch-target minimum) | `tests/test_student_card_layout.gd::test_icon_clusters_exist_and_meet_the_touch_target` (line 166-183) | `assert_true(icon_size >= float(tokens.touch_target_min), "icon cluster is %d px, below the %d px minimum")` — this pins a *minimum*, not the exact 128 value. |
| `_ICON_GAP` | `24.0` | Gap between icon's right edge and pill's left edge | No dedicated test found — UNKNOWN whether any test pins this exact value beyond the icon-cluster existence test above. |
| `_BADGE_SIZE` | `56.0` | Size of the (i) badge overlapping the icon's bottom-right corner | No dedicated numeric-value test found; only existence/asset tests apply. |
| Card size (1080×1920, 1:1 with `card_bg.png`) | width=1080, height=1920 | `card_bg.png` native resolution | `tests/test_student_card_layout.gd::test_card_background_is_the_full_design_size` (line 28-31) and `test_every_card_is_exactly_the_texture_size` (line 76-86) | `assert_eq(tex.get_width(), 1080, "card_bg must be 1080 wide")`; `assert_eq(card.size.x, 1080.0, ...)` |
| Trait pill geometry (`KutuBuku`/`KutuBuku2` anchors/offsets) | `student_card.tscn`: `anchor_top=0.7473958` (KutuBuku), `0.7864583` (KutuBuku2), `offset_top=-35.0`, `offset_bottom=35.0` (70px tall pills) | Not measured from `card_bg.png` directly — tuned by trial to fit between `SifatPasifLabel` (bottom 1395) and `Aprove` (top 1560), per the 2026-09-08 clipping-fix commentary in the test file | `tests/test_student_card_layout.gd::test_every_trait_pill_shares_one_geometry` (line 347-365) and `test_trait_pills_sit_above_approve` (line 377-386) and `test_trait_pills_do_not_overlap_neighbors` (line 394-414) | `assert_true(src.contains("anchor_top = 0.7473958"), "Expected KutuBuku pill anchored at ~0.7474 after the clipping fix")` |
| `PageLabel` position | `offset_top = 1248.0` (student_card.tscn:1507) | Not art-measured; pinned only to prevent recurrence of a stray-text overlap bug | `tests/test_student_card_layout.gd::test_page_label_has_no_stray_text` (line 421-424) | `assert_true(src.contains('offset_top = 1248.0'), "PageLabel moved unexpectedly")` |

No other art-measured geometric constant (e.g. icon-cluster exact offset numbers) has a numeric pinning test beyond the touch-target-minimum check on `_ICON_SIZE`.

---

## C. What `card_bg.png` actually contains

**Pixel dimensions:** 1080 × 1920 (confirmed via `System.Drawing.Image` load — matches the `test_card_background_is_the_full_design_size` assertions).

Sampling with PowerShell + `System.Drawing.Bitmap.GetPixel`:

- **Bio panel** (`BIO_PANEL_RECT = Rect2(120, 300, 489, 367)`, i.e. roughly x:120-609, y:300-667): sampled pixels are opaque (`A=255`) lavender/pink tones, RGB roughly in the (150-215, 140-250, 180-241) range, distinctly different from the surrounding card paper — this is the painted rounded bio panel. Approx painted rect: **x≈120-609, y≈300-667** (489×367), matching `BIO_PANEL_RECT` exactly since that constant is defined as the measured interior.
- **Akademis1 pill track** (`Rect2(284,763,211,67)`, x:284-495, y:763-830): edge pixel (284,763) is a light greenish tone (211,247,228) — likely the track's rounded-cap highlight/edge — while interior samples (337-443, y:763-814) are dark gray, RGB ≈ (43-59,43-59,43-59). This matches a painted dark pill "trough" with a lighter rim, consistent with a track meant to have a colored fill laid over it.
- **Kepribadian1 pill track** (`Rect2(716,762,211,67)`, x:716-927, y:762-829): same pattern — light edge (211,247,228) at the origin corner, dark gray interior (43-59 range) elsewhere. Confirms both left-column (Akademis) and right-column (Kepribadian) pill tracks are painted with the same dark-track/light-rim style.
- Other chrome (paper texture, borders, arrow-shaped decorations) was not individually mapped — sampling was scoped to the two constant-cited regions per the task's guidance ("use the constants from (B) to know where to look"). UNKNOWN: exact rect for any other painted decorative element (e.g. corner flourishes) — would need a full visual pass (screenshot/zoom) to catalog, which was out of scope given the two known constants.

---

## D. Runtime construction inventory (BASELINE = 5 in `test_viewport_editability.gd:84`)

All five `.new()` call sites in `Scripts/StudentCard/StudentCardView.gd`:

1. **`TextureRect.new()` — the stat icon cluster** (`.gd:197`, inside `build_icon_clusters`). Named `Icon<BarName>` (e.g. `IconAkademis1`), one per stat, only created if not already present (`get_node_or_null` guard, line 195-196). **PER-CALL DYNAMIC in the sense that it's data-driven (which texture, which position) per student/bar, but the *set* of 5 icon nodes and their positions are actually static across all students** (same `_STAT_ICONS` mapping and `PILL_RECTS` positions every call) — **could plausibly move into the `.tscn` as static per-card nodes**, with only the texture path being genuinely per-student-invariant (it's per-*bar*, not per-student, since every student shows all 5 stat icons).
2. **`TextureRect.new()` — the (i) info badge** (`.gd:201`, child of the icon cluster, inside `build_icon_clusters`). Same reasoning as above — `icon_info.png` is the same untinted asset for every badge on every card. **Could move into `.tscn`** as static chrome.
3. **`VBoxContainer.new()` — the `BioPanel` container** (`.gd:246`, inside `build_bio_panel`). The container itself is structurally static (same position, same layout) across all students. **Could move into `.tscn`.**
4. **`Label.new()` — bio row heading** (`.gd:268`, inside `build_bio_panel`'s loop over 3 rows). Text is static per row ("Nama:", "Jenis Kelamin:", "Tanggal Lahir:") — **could move into `.tscn`** as 3 static Labels; only `BioValue` needs to stay dynamic.
5. **`Label.new()` — bio row value** (`.gd:274`, same loop). This one is **genuinely PER-CALL DYNAMIC** — it holds `s_data.get("name"/"jenis_kelamin"/"tanggal_lahir")`, which differs per student and per card-repopulate (the same `KertasMurid1` node is reused across all 6 students as the player pages through, per `populate()` being called fresh each time `_populate_ui_from_data()` runs — see `student_card.gd`). This one **must stay code**, or at minimum stay a bound `@export`/reference that code writes into.

**Summary:** of the 5 sites, 4 build structurally-static chrome that differs only in texture path or is fully static (icon cluster texture container, info badge, BioPanel container, bio headings) and could in principle move into the `.tscn`; only the bio **value** labels are truly per-call dynamic content that must remain code-driven.

---

## E. Blast radius — tests that would break on a layout change

From `tests/test_student_card_layout.gd`:

- `test_card_background_is_the_full_design_size` — breaks if `card_bg.png` dimensions change from 1080×1920.
- `test_every_card_is_exactly_the_texture_size` — breaks if any `KertasMurid1..6` in either `student_card.tscn` or `report_card.tscn` stops being exactly 1080×1920.
- `test_cards_use_the_new_background` — breaks if `card_bg.png` reference is removed, or if `paper_placeholder.jpg` is reintroduced.
- `test_pill_rects_match_the_painted_tracks` — breaks if `StudentCardView.PILL_RECTS` values change (pins exact `Rect2` per bar).
- `test_bars_carry_no_text_children` — breaks if a `val_lbl.text = "%d / %d"` pattern reappears, or if `StatPill` variation stops being applied.
- `test_switching_variation_at_runtime_rederives_the_tint` — behavioral; breaks if `StatBar.variation` setter stops re-deriving `self_modulate` from category.
- `test_icon_clusters_exist_and_meet_the_touch_target` — breaks if `build_icon_clusters` is removed/renamed, if `_ICON_SIZE` drops below `tokens.touch_target_min`, or if any of the 5 `_STAT_ICONS` entries is missing.
- `test_the_pill_no_longer_takes_input` — breaks if `bar.mouse_filter = Control.MOUSE_FILTER_IGNORE` line is removed, or `icon_magnify` reappears.
- `test_bio_panel_renders_the_three_rows` — breaks if `build_bio_panel` is removed or any of the 3 headings ("Nama:", "Jenis Kelamin:", "Tanggal Lahir:") is dropped.
- `test_bio_panel_sits_inside_the_painted_panel` — breaks if `BIO_PANEL_RECT` constant value changes, if the four `offset_*` lines stop deriving from it, or if `populate()` stops calling `build_bio_panel`.
- `test_superseded_labels_are_removed_from_the_scenes` — breaks if any `.tscn` (`student_card.tscn` or `report_card.tscn`) re-adds a `Label` node named `Nama`/`Profil`/`Kepribadian`/`Akademis` directly under any `KertasMurid<N>`.
- `test_every_card_has_the_sifat_pasif_heading` — breaks if `SifatPasifLabel` node is removed/renamed from any card in either scene.
- `test_info_badge_draws_its_asset_untinted` — breaks if `badge.modulate` is set anywhere in `StudentCardView.gd`.
- `test_trait_buttons_use_the_trait_pill_variation` — breaks if `TraitPill` variation stops being used, or if "QUIRK: "/"PERSONA: " prefixes are reintroduced.
- `test_trait_values_are_unchanged` — breaks if any of the 6 quirk display strings changes in `student_card.gd` (gameplay-coupled, not display-only — see StudentData.gd string branching).
- `test_every_trait_pill_shares_one_geometry` — **exact per-property tolerance check** on `KutuBuku`/`KutuBuku2` anchor/offset values, separately pinned for `student_card.tscn` vs `report_card.tscn` (different geometry by design, each internally uniform across 6 cards). This is the single most layout-change-fragile test in the suite.
- `test_trait_pills_sit_above_approve` — breaks if the exact anchor strings `"anchor_top = 0.7473958"` / `"0.7864583"` are not found verbatim in `student_card.tscn`, or if old superseded anchors (`0.786`, `0.7`) reappear.
- `test_trait_pills_do_not_overlap_neighbors` — behavioral geometry check: instantiates the scene and asserts `KutuBuku`/`KutuBuku2`/`SifatPasifLabel`/`Aprove` rects don't intersect, per card, for all 6 cards.
- `test_page_label_has_no_stray_text` — breaks if `PageLabel`'s `offset_top = 1248.0` changes.

From `tests/test_student_card.gd`:

- `test_approved_students_contract_is_intact` — source-scan; breaks if `GameState.approved_students`/`selected_student`/`returned_from_student_card` symbols are removed from `student_card.gd`.
- `test_still_routes_to_the_lobby` — breaks if the `res://Scenes/Lobby/loby.tscn` route string is removed.
- `test_debug_tutorial_bypass_skips_the_student_card_tutorial` — breaks if the `GameState.tutorials_bypassed` gate or its exact `tutorial_active = false\n\t\tcolor_rect.hide()` sequence changes.
- `test_scene_instantiates` — breaks if any `KertasMurid1..6` node is missing.
- `test_scene_has_no_theme_overrides` — breaks if any `theme_override_*` property is set anywhere in the scene tree (walks all children recursively) — **this would catch any layout-only fix that sneaks in a `theme_override_*` instead of a `ThemeFactory` variation**.
- `test_no_hardcoded_colors_remain_in_the_script` — breaks if a `Color(...)` literal appears anywhere in `student_card.gd`.
- `test_interactive_controls_meet_the_minimum_touch_target` — breaks if `Aprove`, `Batal`, `KutuBuku`, `KutuBuku2`, `BelajarButton`, `NextButtonKanan`, `NextButtonKiri` on `KertasMurid1` shrink below the design tokens' touch-target minimum, accounting for `scale`.
- `test_stat_bars_are_statbars_with_a_category` — breaks if any of the 5 stat bars, on any of the 6 cards, stops being a `StatBar` with the expected `category` string.
- `test_action_buttons_use_theme_variations` — breaks if `Aprove`/`Batal`/`KutuBuku`/`KutuBuku2`/`BelajarButton` on `KertasMurid1` don't carry the exact expected `theme_type_variation` (`SuccessButtonL`, `DangerButtonL`, `TraitPill`, `TraitPill`, `PrimaryButtonL`).
- `test_motion_and_audio_feedback_are_wired` — breaks if `Juice.stagger_in` disappears from `student_card.gd`, or if the stat/trait popup scripts stop calling `Juice.pop_in`, or if the approve/reject SFX cue names change.
- `test_student_card_view_class_exists`, `test_quirk_descriptions_are_available_from_the_view`, `test_persona_descriptions_are_available_from_the_view`, `test_student_card_delegates_to_the_view` — breaks if `StudentCardView.gd` is removed or `student_card.gd` stops calling into it.
- `test_tutorial_target_node_paths_are_unchanged` — breaks if `KertasMurid1/Kepribadian1` or `KertasMurid1/KutuBuku` node paths change (tutorial addresses nodes by string path).

**Practical note for the coming redesign:** any change to icon-cluster geometry, bio-panel geometry, pill-rect geometry, trait-pill anchors, or the `Aprove`/`Batal` node layout will need companion edits to the corresponding constants in *both* `StudentCardView.gd` **and** the pinning tests above (they are deliberately synchronized, not derived from each other at test time in most cases — e.g. `_EXPECTED_PILLS` in the test file is a literal copy of `PILL_RECTS`, not a cross-reference).

---

## F. The three specific claims checked

### F1. Do `Aprove` and `Batal` occupy the same slot with swapped visibility?

**Partially true, with an extra wrinkle.** They are two separate `Button` nodes at *slightly offset but nearly-identical* positions:

- `Aprove`: `offset_left=260.0, offset_top=1560.0, offset_right=780.0, offset_bottom=1720.0` (`student_card.tscn:1408-1416`)
- `Batal`: `visible=false` by default, `offset_left=259.0, offset_top=1622.0, offset_right=749.0, offset_bottom=1782.0` (`student_card.tscn:1417-1425`)

So they're offset by ~62px vertically and ~1-31px horizontally — not pixel-identical like the lobby's Student/Jadwal swap, but close enough to read as "the same slot" visually (design commentary in the test file's trait-pill-geometry section explicitly calls Aprove's top "1560" the reference point pills must clear).

The show/hide logic lives in three places in `student_card.gd`:
- `_show_stamp_if_approved(index)` (lines 719-739): if `approved[index]` is true, hides `Aprove`, shows `Batal` — **unless** the student's id is in `GameState.grade7_student_ids`, in which case `Batal` stays hidden too (lines 730-733) — a third state where neither button shows once approved, for grade-7 students specifically.
- `_on_approve_pressed(page_index)` (line 1284+) and `_on_batal_pressed(page_index)` (line 1317+) toggle them directly on click.
- `_reset_approve_position`/`_shift_approve_for_belajar`/`_reset_all_approve_positions` (lines 789-878) additionally *reposition* whichever of the two is visible when the `BelajarButton` needs to slide in next to it, sliding the reference button left by `(ref_size.x + gap) / 2.0`.

So: **yes**, it's the same show/hide-swap pattern as lobby's Student/Jadwal, but (a) the two buttons aren't at pixel-identical rects, (b) there's a grade-7 special case that hides both, and (c) both buttons get dynamically repositioned to make room for `BelajarButton` once the approval limit is reached.

### F2. `PageLabel` and the two trait pills — rects and overlap

Resolved rects for `KertasMurid1` (card offset is `(-70, -254)` relative to scene root per `student_card.tscn:1200-1201`, but all figures below are **card-local**, matching how `PILL_RECTS`/`BIO_PANEL_RECT` are documented and how the tests compute overlap):

- `PageLabel` (scene-root child, not per-card): `offset_left=302.0, offset_top=1248.0, offset_right=561.0, offset_bottom=1332.0` → rect **(302, 1248) to (561, 1332)**, size 259×84. This is a scene-root node, not a `KertasMurid` child, so its screen position doesn't shift between pages — it's positioned to sit over whichever card is currently visible.
- `KutuBuku` (card-local, `KertasMurid1`): `anchor_top/bottom=0.7473958`, `offset_top=-35.0, offset_bottom=35.0`, `offset_left=-421.0, offset_right=421.0`, anchor_left/right=0.5. Card height 1920 → anchor_top resolves to `0.7473958 * 1920 = 1435.0`; rect center y = 1435, so rect is **y: 1400 to 1470**. Anchor_left/right=0.5 on card width 1080 → center x=540; rect x: `540-421=119` to `540+421=961`. So **KutuBuku rect ≈ (119, 1400) to (961, 1470)**, size 842×70.
- `KutuBuku2`: `anchor_top/bottom=0.7864583` → `0.7864583*1920=1510.0`; offset_top/bottom=-35/35 → **y: 1475 to 1545**. offset_left=-417, offset_right=420 → x: `540-417=123` to `540+420=960`. So **KutuBuku2 rect ≈ (123, 1475) to (960, 1545)**, size 837×70.
- `SifatPasifLabel`: `offset_left=119.0, offset_top=1330.0, offset_right=500.0, offset_bottom=1395.0` → rect **(119,1330) to (500,1395)**.
- `Aprove`: rect **(260,1560) to (780,1720)** (from F1).

**Overlap check:**
- `PageLabel` (y:1248-1332) vs `KutuBuku` (y:1400-1470): no y-overlap (1332 < 1400) → **no overlap**.
- `PageLabel` vs `KutuBuku2` (y:1475-1545): no y-overlap → **no overlap**.
- `KutuBuku` (y:1400-1470) vs `SifatPasifLabel` (y:1330-1395): no y-overlap (1395 < 1400, 5px gap) → **no overlap**, consistent with the test suite's documented "5px gaps around each" design note.
- `KutuBuku` (y:1400-1470) vs `KutuBuku2` (y:1475-1545): no y-overlap (1470 < 1475, 5px gap) → **no overlap**.
- `KutuBuku2` (y:1475-1545) vs `Aprove` (y:1560-1720): no y-overlap (1545 < 1560, 15px gap) → **no overlap**, matching the "15px clear of Aprove" note in the test file's comment block.

All of this matches `test_trait_pills_do_not_overlap_neighbors`'s live-instantiated assertions and the historical commentary in `test_student_card_layout.gd` lines 304-330 — **no overlaps currently exist among PageLabel, the two trait pills, SifatPasifLabel, or Aprove**, contrary to what a design spec written from an old screenshot (showing the "376" stray-text bug, since fixed 2026-09-08) might assume.

### F3. Nav arrows — asset, rotation, shared asset

Confirmed:
- Both `NextButtonKanan` and `NextButtonKiri` use **the identical texture asset**: `res://Assets/Images/UI/pngwing.com (1).png` (`ExtResource("4_vdd03")`, declared once at `student_card.tscn:12`, referenced at lines 1435 and 1446).
- `NextButtonKanan` (line 1427-1436): `rotation = -3.1272264` (radians) ≈ **-179.17°**, i.e. the icon is flipped almost exactly 180° from its native orientation. `scale = Vector2(0.175, 0.175)`.
- `NextButtonKiri` (line 1438-1447, `visible = false` by default): **no `rotation` property present** → rotation is the Godot default `0.0`, i.e. drawn in the asset's native orientation. Same `scale = Vector2(0.175, 0.175)`.

So the single arrow asset points one direction natively; `NextButtonKiri` uses it as-is, and `NextButtonKanan` is rotated ~180° to point the opposite way. Both share one file — there is no separate "right-pointing" and "left-pointing" art asset.

---

## UNKNOWN / needs follow-up

- Exact painted-chrome rects for card decorations *other than* the bio panel and the two sampled pill tracks (corner flourishes, paper texture edges, etc.) — not catalogued; would need a broader pixel/zoom pass across `card_bg.png`.
- Whether any test pins the exact numeric values of `_ICON_GAP` (24.0) or `_BADGE_SIZE` (56.0) beyond the touch-target-minimum check on `_ICON_SIZE` — none found in either test file.
- Whether `report_card.tscn`'s per-card node structure (icons, bio panel, etc.) mirrors `student_card.tscn`'s runtime-built elements, or whether `report_card.gd` has its own equivalent construction path — out of scope per the task's file list (only `student_card.gd`/`.tscn` and `StudentCardView.gd` were specified), not investigated.
