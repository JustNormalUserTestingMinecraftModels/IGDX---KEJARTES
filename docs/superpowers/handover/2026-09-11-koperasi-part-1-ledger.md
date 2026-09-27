# Koperasi rework Part 1 — execution ledger (preserved)

Copied verbatim from `.superpowers/sdd/2026-09-11-koperasi-rework/progress.md`
on 2026-09-11. That directory is git-ignored scratch, so this is the only
surviving record of the twenty rulings made during Part 1 and the reasoning
behind each. Read it with `2026-09-11-koperasi-part-2-handover.md`.

---

# SDD ledger — plan: docs/superpowers/plans/2026-09-11-koperasi-rework.md

Spec: docs/superpowers/specs/2026-09-11-koperasi-rework-design.md (read, binding authority)
Branch: feat/koperasi-rework (base 8b513b3)

## Pre-flight scan

### Cross-task interface rows

| A → B | A produces | B consumes | Finding |
|---|---|---|---|
| T1 → T9 | icon_keranjang.svg | Keranjang/KeranjangDepan texture | clean |
| T2 → T3 | PriceTag/Pressed/Disabled variations | theme_type_variation on the pill | clean |
| T2 → T9 | BasketTray variation | ReturPanel theme_type_variation | clean |
| T3 → T4 | set_price/play_buy/set_affordable/get_label_text | all four call sites | clean |
| T4 → T5 | _price_tags, _refresh_affordability, _on_barang_pressed | T5 extends all three | clean — sequential edits to the same functions, no overlap in lines |
| T5 → T8 | ShelfItem's runtime TextureRect shadow | viewport_editability ratchet | CONFLICT — see Ruling 5 |
| T6 → T8 | icon_retur.svg | ReturButton icon | clean |
| T6 → T9 | icon_keranjang_kosong.svg | EmptyState TextureRect | clean |
| T7 → T9 | tray_dots.png | Dots TextureRect | clean |
| T8 → T9 | retur_empty_state declared + resolved | EmptyState node created | clean — T8 guards every use with is_instance_valid, so T8 is green before T9 exists |

### Per-task self-agreement rows

| Task | Tests vs code it specifies | Finding |
|---|---|---|
| T1 | asserts file exists + no `<text>` | CONFLICT — assert_not_null, see Ruling 3 |
| T2 | asserts 4 variations + colour relations | clean once Ruling 3 applied |
| T3 | asserts label text in 3 states | clean once Ruling 3 applied; play_buy sets text synchronously so no await needed — verified against the no-coroutine constraint |
| T4 | source-text scans only | clean |
| T5 | @export doc scan + phase scan | clean once Ruling 3 applied |
| T6 | emoji absence | CONFLICT — see Ruling 4 |
| T7 | tile exists + 26x26 | clean once Ruling 3 applied |
| T8 | slot binds name+quantity | clean once Ruling 3 applied |
| T9 | .tscn source scan | clean once Ruling 3 applied |

## Rulings

Ruling 1 (no worktree) — The Godot editor is attached to THIS working tree and holds the MCP bridge; moving to a worktree detaches it and the plan cannot run. Branch isolation on feat/koperasi-rework (main is Textures) satisfies the intent. Cost if wrong: work lands on a feature branch rather than a worktree — nothing destructive, trivially reworked.

Ruling 2 (bridge is controller-only) — CLAUDE.md: the godot-ai bridge is single-client; a subagent that connects displaces this session and gets nothing itself. Implementers author files only; the controller runs every test_run / scene_open / scene_save / project_run / filesystem_manage and hands results back. Cost if wrong: none to the code — it only shifts turns from subagents to the controller.

Ruling 3 (test base class) — The plan's suite header says `extends "res://addons/godot_ai/testing/test_suite.gd"` while its tests call `assert_not_null`, which exists ONLY on McpTestSuiteCompat (tests/mcp_test_suite_compat.gd:20), not on McpTestSuite. Every task's tests would fail to run. Ruling: the suite extends `McpTestSuiteCompat`. 30 of the existing suites already do. Cost if wrong: suite fails to load, caught on the first test_run.

Ruling 4 (emoji escape) — The plan's Task 6 test uses `"\u{1F6D2}"`, which is not valid GDScript string-escape syntax. Ruling: build the glyphs with `char(0x1F6D2)` and `char(0x21A9)`. Cost if wrong: parse error, caught on the first test_run.

Ruling 5 (ShelfItem's runtime shadow vs "no visual is built at runtime") — Task 5 constructs a shadow TextureRect in code, which the Global Constraints ban. The spec requires a per-item shadow on a shelf whose items are randomised at runtime by ItemDatabase.get_random_items, so the shadow cannot be static scene chrome. Ruling: permitted, and routed to viewport_editability's ALLOWED dict (per-call-dynamic content) rather than BASELINE, which is exactly what ALLOWED documents. Cost if wrong: the reviewer flags it and the shadow moves into the shelf .tscn as four static nodes — contained, one task's rework.

Ruling 6 (TDD gate runs through the controller) — Red-green cannot happen inside one subagent when only the controller can run tests. Ruling: subagent writes the test; controller runs test_run and confirms RED; controller resumes the same subagent to implement; controller runs test_run and confirms GREEN. Preserves the plan's discipline under Ruling 2. Cost if wrong: extra controller turns, no code impact.

## Progress

Ruling 7 (suite naming) — The plan calls `test_run(suite="test_koperasi_tray")` in every task, but the runner registers suites WITHOUT the `test_` prefix (91 discovered: 'koperasi', 'ghost_track', ...). Ruling: all test_run calls use `suite="koperasi_tray"`. Cost if wrong: INVALID_PARAMS on every run, caught immediately.

Ruling 8 (missing suite_name) — The plan's suite skeleton omits the `func suite_name() -> String` override that every one of the 91 existing suites declares. Without it the suite registers as 'unnamed' and cannot be targeted by test_run. Ruling: the suite declares `suite_name()` returning "koperasi_tray", placed after the ## doc block. Cost if wrong: suite unreachable, caught immediately.

Ruling 9 (no subagent resumption) — SendMessage is disabled in this session, so the skill's "rounds 1-3 resume the original implementer" is unavailable. Ruling: every continuation and every fix round is a FRESH dispatch carrying the brief path, the report-file path, and the findings; the report file is the persistent memory, exactly as the skill's fallback prescribes. Cost if wrong: more cold-start dispatches, higher token cost, no code impact.

Ruling 10 (null guards must return) — Confirmed empirically on the first RED run: `assert_not_null(f, ...)` records a failure but does NOT halt the test, so the following `f.get_as_text()` crashed with "Cannot call method 'get_as_text' on a null value" and the real assertion never ran. The plan repeats this `FileAccess.open` + `assert_not_null` + immediate use shape in Tasks 1, 2, 3, 5, 6, 8 and 9. Ruling: every null guard in this suite is followed by `if f == null: return`, so a missing file reports its own assertion instead of an unrelated crash. Cost if wrong: none — it only changes how a failing test reports.

Task 1: RED verified (2/2 failing for the right reason, commit 8b513b3 + uncommitted test)
Task 1: complete (commits 8b513b3..f375ee7, review clean — spec OK, 0 critical/important)
Task 1: minor (deferred): text-element scan checks `<text` only, not `<tspan`/`<use>` — theoretical, SVG is static and hand-verified
Task 1: minor (deferred): no pixel check that the clip-path'd slats render — project convention favours source scans
Task 1: reviewer's "cannot verify SVG imports" resolved by controller — icon_keranjang.svg.import was generated by the editor scan and ResourceLoader.exists() returned true in a passing test
Ruling 11 (vacuous BasketTray test) — Caught on Task 2's RED run: `test_basket_tray_has_no_black` PASSED with 3 assertions before BasketTray existed. Theme.get_stylebox() falls back to the base type's stylebox rather than returning null, and this project's cream Panel stylebox is itself a warm light StyleBoxFlat, so both colour assertions passed against the fallback — the test would pass whether or not the variation exists. Ruling: the test must assert `theme.has_stylebox("panel", "BasketTray")` and return early if absent, before reading the box. Cost if wrong: none — it only removes a false green. Note the same fallback hazard applies to any future test that reads a stylebox without a has_stylebox guard.
Task 2: BLOCKED on editor restart. ThemeFactory.gd edit is correct and parses (editor log shows no parse error; call wired at line 518 inside _build_panels, definition at 523). But `class_name ThemeFactory` is cached by the running editor: no-op script_patch returned reloaded=false/parse_error, filesystem scan did not evict it, and theme_rebake therefore re-baked from the STALE class — koperasi_tray still 3 red. CLAUDE.md documents this trap. Controller will not force-kill the editor: it had RosterCard.tscn open at session start and may hold unsaved user work. Asked the user to restart. Proceeding with Tasks 6 and 7, which need no editor.
Task 6: complete (commit a85d4cc) — 3 emoji removed and verified by diff, 2 glyph SVGs added, test green (6 assertions)
Task 7: complete (commit a85d4cc) — tray_dots.png 26x26, loads as Texture2D, test green (4 assertions)
Note: Tasks 6+7 were batched into one dispatch and one commit (same-shape asset work, per the skill's batching rule). Commit also carries Task 2's ThemeFactory builder, still red pending the editor restart.
Note: reverted a 915-line churn diff on Assets/Theme/kejartes_theme.tres produced by rebaking from the stale class — it would have committed a wrong bake.
Ruling 12 (unguarded scene loads crash with 0 assertions) — Task 3's RED run showed three tests aborting with "Attempt to call function 'instantiate' in base 'null instance'" and assertion_count 0. `load()` returns null for a missing resource and the plan calls `.instantiate()` straight off it. A 0-assertion abort is the exact failure mode CLAUDE.md warns reads as a silently broken test. Ruling: every test that loads a PackedScene assigns it first, asserts non-null, and returns early before instantiating. Applies to Task 3's three tag tests and Task 8's test_retur_slot_binds_name_and_quantity, which has the same shape. Cost if wrong: none — it only changes how a failing test reports.
Task 3: script half complete (commit c5cd3f8) — PriceTag.gd authored, 23 doc lines, all 4 @exports documented, no add_theme_*, no await. Five tests authored and cleanly red ("PriceTag.tscn missing", 1 assertion each). Scene half BLOCKED on editor restart.

BLOCKED — every remaining task now waits on the editor restart:
  T2  stale class_name ThemeFactory cache; needs restart then rebake
  T3  scene half: scene_save would flush stale script buffers over patched .gd files
  T4  depends on T3's scene
  T5  depends on T4
  T8  scene work (ReturSlot.tscn)
  T9  scene work (koprasi.tscn)
Nothing further can proceed without the restart. 5 of 12 suite tests green.
Ruling 13 (theme test read a cached resource) — After the editor restart the bake on disk DID contain PriceTag/BasketTray (8 matches in kejartes_theme.tres) yet the tests still reported "variation PriceTag has no panel stylebox". Cause: the plan's `_baked_theme()` helper uses a plain `load(THEME_PATH)`, which returns the editor's in-memory copy held since startup, not the freshly baked file. This project already documents the trap at tests/test_theme_factory.gd:363-368. Ruling: `_baked_theme()` uses `ResourceLoader.load(THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)`, matching the established pattern. NOTE: this means my earlier Ruling-2 diagnosis (blaming the class_name cache and asking for a restart) was WRONG -- the restart was not needed for this. Cost if wrong: none; it only makes the test read the real file.
Task 2: complete (commit f02bbd0, green) — 4 variations registered and baked
Task 3: complete (commit HEAD, 13/13 green) — PriceTag.gd + PriceTag.tscn
Ruling 14 (wipe stomped by container) — I built PriceTag.tscn with Wipe as a direct child of the PanelContainer root. Godot containers call fit_child_in_rect on every direct child each sort, overwriting size; play_buy() changes the Label text, which changes Row's minimum size and queues a sort, so the tweened wipe width would snap to full instantly. The tests could not see it -- they only assert label text. Ruling: Wipe moved under a plain Control (WipeHost), script re-pointed at WipeHost/Wipe and sized from the host, and a structural test added that fails if the wipe ever returns to being a container child. Cost if wrong: none; the structure is strictly safer.
Note: the fix dispatch I wrote introduced a parse error of my own (`var wipe := tag.get_node_or_null(...)` cannot infer from an untyped receiver), which broke the whole suite until corrected to plain `=`.
Ruling 15 (emoji test too narrow) — Review of Task 6 found a 4th emoji; a full range scan found THREE remaining in koprasi.gd: the coin at :238 and two sparkles at :256. My Task 6 test only checked two specific glyphs, so it passed while the file it audits still carried three. The project convention is a blanket ban on emoji as UI iconography. Ruling: remove all three, and broaden the test from two literal glyphs to a Unicode-range scan so it cannot pass with any emoji present. Cost if wrong: touches two Indonesian strings the brief did not enumerate -- the words are preserved, only the glyphs go.
Ruling 16 (repeat is a node property, not an import flag) — The reviewer raised Task 7's unset "Repeat" import flag as Important. The premise is wrong: tray_dots.png.import has no repeat param at all, because in Godot 4 texture repeat moved to CanvasItem.texture_repeat on the node; it was an import flag in Godot 3 only. My brief's Step 4 was wrong. Ruling: finding dismissed as written, but the underlying concern is real and carried into Task 9 as a hard requirement -- the Dots TextureRect must set texture_repeat = 2 and stretch_mode = 1 (tile), or the tile silently will not repeat. Cost if wrong: if I am wrong about the Godot 4 behaviour the tile renders once instead of tiling, visible immediately on the tray.
Task 4: complete (16/16 green; koperasi 12, script_documentation 2, viewport_editability 2, rakbarang_blur_layer 4 all green)
Task 6/7 review fixes applied: Row separation added; 3 more emoji removed; emoji test broadened to a codepoint-range scan.
Review verdict on T2/T3/T6/T7: spec OK on 2,3,6; T7's "repeat import flag" finding dismissed per Ruling 16 (wrong premise, carried into T9 instead). No Critical. Minors resolved rather than deferred.
Task 5: complete (19/19 green, viewport_editability still 2/2). Implementer corrected a real defect in my dispatch: I told it to clear _shelf_items alongside _price_tags.clear() AFTER the loop, which would have wiped the list the loop had just filled. It moved the clear before the loop and flagged it.
Task 8: complete (22/22 green). Ratchet turned 7 -> 2 for rakbarang_1.gd and all add_theme_* calls are gone from that file. Net debt paydown, not debt added.
Ruling 17 (Task 9 scene approach, two deviations from the plan) — Inspecting koprasi.tscn before editing showed the plan's two instructions were unsafe:
  (a) The plan says give ReturPanel the BasketTray variation, and delete-and-recreate it if it is not a Panel. It is a TextureRect with NO texture set (it draws nothing today). Retyping it would mean re-parenting ScrollContainer and BackButton and re-deriving their layout. Ruling: instead add a `Sheet` Panel child carrying the BasketTray variation, the exact pattern CLAUDE.md documents for StudentList's RosterCard. No retype, no re-parenting.
  (b) The plan says set BlurRect.color to the warm wash. BlurRect carries the blur ShaderMaterial and no explicit color (so, white). Setting its colour to 10%-alpha brown would multiply the shader output down to ~10% opacity and effectively destroy the blur. Ruling: leave BlurRect alone and add a separate WarmWash ColorRect above it in the same CanvasLayer.
Also confirmed: the black basket art is KeranjangDepan.texture_normal (pngwing.com (6).png), not Keranjang.texture -- Keranjang has no texture at all. The swap goes on KeranjangDepan.
Cost if wrong: (a) the tray surface draws at the wrong z-order or rect, visible immediately on screen; (b) the backdrop reads too warm or too flat, a one-number change.
Ruling 18 (GameState.money does not exist) — Task 9's in-game verification crashed at boot: "Invalid access to property or key 'money' on a base object of type 'Node (GameState.gd)'". My Task 4 brief specified `GameState.money`; the real property is `player_money` (Scripts/GameState.gd:154, backed by _player_money), which koprasi.gd already uses correctly. Both new call sites in rakbarang_1.gd (lines 156 and 158) are wrong. NO source-scan test could catch this -- Task 4's tests only assert that the strings "set_affordable(" and "_refresh_affordability" appear. Ruling: fix both call sites to player_money, and add a behavioural guard that the shop script never references a GameState property that does not exist. Cost if wrong: the shop scene crashes on entry, which is exactly what happened -- this bug would have shipped past a fully green suite.
Task 9: complete (commit 22f4d45, 24/24 green + in-game verification). Screenshot evidence: coin HUD 1000, three affordable items show green coin pills, the unaffordable racket dimmed with a grey pill still showing its price, woven basket replaces the black silhouette.
Ruling 19 (ReturButton off the S/M/L scale) — Full suite: 1306 pass, 1 fail. button_geometry rejects ReturSlot.tscn::ReturButton at height 55; the legal steps are btn_h_s 96 / btn_h_m 128 / btn_h_l 160, and SecondaryButton is the "s" step. The 55 came from my Task 8 brief, which copied it from the old runtime-built button -- moving that button into a scene is what exposed it to the ratchet. Ruling: set ReturButton custom_minimum_size height to 96 to match its variation's step. Cost if wrong: the retur button is 41px taller than the old one; it sits in a 380px-tall slot so there is room.
Note: the bridge dropped immediately after the full test_run, exactly as CLAUDE.md documents. Awaiting editor restart to apply the one-line scene fix.

## Final whole-branch review (opus) — findings

Critical 1: ShelfItem helpers accumulate. setup_random_items runs in _ready AND on every _on_rak1_pressed; _ensure_price_tag is idempotent but the ShelfItem creation is not, so each reopen adds another bobber per button with a different _base_y. Shelf drifts, node count grows unbounded.
Important 2: the price pill swallows taps. PanelContainer defaults to MOUSE_FILTER_STOP and the tag is a child of the TextureButton, so a tap ON the pill buys nothing. The spec says the tag IS the press target; nothing wires it.
Important 3: lift() is stomped by ShelfItem._process -- both write _button.position.y and _process runs after the tween each frame, so the lift never shows.
Important 4: spec section 1 tray layout largely unimplemented -- bottom-aligned items at their own heights, the Total + PrimaryButton "Beli" row, and the tray peeking at the bottom rather than opening centred. My plan's Task 9 never specified these. A real plan-vs-spec gap, not an implementation failure.
Important 5: no tests for the empty state or total calculation, both named in the spec's Testing section.
Minor 6: weak tests -- bob test matches the word "phase" in a doc comment; @export doc test passes vacuously with zero exports; the Beli test exercises the un-parented early-return path so both tweens are uncovered; the green/darker test lacks the has_stylebox guard Ruling 11 mandates.
Minor 7: _add_koperasi_variations ignores its tokens parameter; all colours inline.
Known: Ruling 19's ReturButton 55 -> 96 still unapplied (the one red test).

Verified clean by the reviewer: the arc-into-basket flight is untouched and its BasketArea target still resolves; nothing dangling in rakbarang_1.gd; ratchet moved the right way; no add_theme_* added; Balance.gd untouched; emoji gone.

## Close-out
Fix wave verified: koperasi_tray 26/26, button_geometry 8/8, full suite 1309/1309 across 92 suites.
Scoped re-review: all six findings ADDRESSED, no new breakage.
In-game: tapping a price pill now buys (was dead) -- item flies to basket, tag swaps to Beli, total updates.
Ruling 20 (tray layout gap parked) — The final review's Important #4 is real: the spec's tray LAYOUT (bottom-aligned items at their own heights, a Total + Beli row, the tray peeking rather than opening centred) is unimplemented, because my Task 9 never specified it. This is a plan-vs-spec gap I introduced, not an implementation failure. Ruling: park it and ship the rest. The delivered work is coherent and independently valuable, nothing downstream depends on the missing layout, and the layout is exactly the kind of change the user's mentor reviews from screenshots -- rushing it at the end of a long session would waste that review. Recorded in the PR's "Known gap" section so it cannot be lost. Cost if wrong: the mentor sees a tray that is warm but still grid-shaped, and asks for the layout pass anyway -- one extra round trip, no rework of what shipped.
Pushed: origin/feat/koperasi-rework. PR #15 opened against Textures.
