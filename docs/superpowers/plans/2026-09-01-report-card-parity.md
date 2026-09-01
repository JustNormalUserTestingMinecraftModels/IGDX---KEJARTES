# ReportCard Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **STATUS — executed 2026-09-01. Tasks 1, 2 and 4 complete; Task 3 DROPPED as
> unachievable. Suite green (560/560, 45 suites).**
>
> **Task 3 is withdrawn.** Stripping the 30 baked `self_modulate` lines does
> not hold: `Scripts/UI/StatBar.gd` is `@tool` and its `_apply_tint()` runs
> ungated in `_ready()` (`StatBar.gd:44`), writing `self_modulate` from the
> category colour. The editor therefore re-serialises those lines on the next
> save of that scene, so the planned `test_no_scene_bakes_a_stat_bar_tint`
> would pass after a strip and fail after the next editor save — a flaky test
> pinning something the design system deliberately does. `student_card.tscn`
> has zero of them only because the editor has not re-saved it since the tint
> code landed, not because of any principled difference. The tints are correct
> at runtime either way. Left as-is, documented here.
>
> **Deviation, Task 1 Step 5:** the plan put `_hide_card_rows(new_index)` just
> above `_stagger_in_card(new_index)`, which is *after* the fade-in tween and
> defeats the purpose. It belongs immediately after `new_kertas.modulate.a =
> 0.0` and before the tween, mirroring `student_card.gd:667`. The test now
> asserts that ordering rather than mere presence.
>
> **Deviation, Task 2:** `assert_eq` on the offsets fails — the scene stores
> float32, so `-104.119995` widens to `-104.119995117188` and never equals the
> float64 literal. The test uses the project's `absf(...) <= 0.01` idiom
> instead. Note this also proved `student_card.tscn`'s card 1 was already
> correct; only ReportCard's had drifted.
>
> **Deviation, Task 4:** scene edits applied through the editor (spec §6.0),
> not as text.

**Goal:** Make ReportCard render identically to StudentCard, so the read-only report screen is the approval screen minus its approval chrome.

**Architecture:** The two screens already share every line of rendering logic — both call `StudentCardView.populate(...)`, and ReportCard already reads `GameState.approved_students` live, so it already shows current stats (spec §1.2). What diverges is the scene file, which is a stale hand-edited copy, and the screen controller's animation table. Four concrete defects are fixed: a `CARD_ROW_ORDER` naming four nodes that do not exist, a missing `_hide_card_rows`, card 1's trait pills floating ~240 px out of place, and 30 baked `self_modulate` colours the live tint has to fight.

**Tech Stack:** Godot 4.6, GDScript, `godot-ai` MCP (`filesystem_manage`, `test_run`).

**Spec:** `docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`

**Depends on:** nothing. This plan can run first, in parallel with the art batch.

## Global Constraints

- **Never hand-edit a `.tscn` as text.** The Godot editor caches every scene and its
  in-memory copy wins — a text edit is invisible to `load()` and is silently
  overwritten by the next `scene_save`. Neither `scan`, `reimport`, nor
  `scene_open(force_reload=true)` evicts the cache. Every scene change below states the
  intended **end state**; apply it as `scene_open` → `node_create` /
  `node_set_property` / `node_manage` → `scene_save`. See spec §6.0 for the
  gotchas (`anchors_preset` is inert; numbers must be passed unquoted;
  `node_create` appends last so use `node_manage(op="move")` for z-order).
- Godot **4.6**, portrait **1080×1920**, `mobile` renderer.
- **ReportCard must keep returning `null` for `find_child("Aprove")`, `find_child("StampApprove")` and `find_child("BelajarButton")` — recursively** — and must keep resolving `find_child("BackButton")`. Pinned by `tests/test_report_card.gd:23-39,69`. This is why ReportCard cannot simply instance `student_card.tscn` as a sub-scene.
- **`tests/test_student_card_layout.gd` runs most of its tests over BOTH scenes** (`_SCENES`, line 67). Any scene edit must keep both passing. Several of its tests do raw `src.contains('[node name="…" parent="KertasMurid%d"')` string matching on the `.tscn` text.
- **Never add a `theme_override_*`.** `tests/test_student_card.gd:84` scans both scenes.
- **No `Color(` literal in the screen scripts.** `test_no_hardcoded_colors_remain_in_the_script` uses the regex `Color\s*\(`.
- **Every script needs a `##` header** in its first 12 lines and a `##` line immediately above every `@export`, with no blank line between (`tests/test_script_documentation.gd`).
- **Rescan after editing any `.gd`, before running tests.**
- Tests must be `@tool`; **no test may be a coroutine**.
- Assertion helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_not_null`, `assert_gt`, `assert_has_key`, `assert_contains`, `assert_is_error`, `track()`. No `assert_lt` / `assert_null` / `assert_almost_eq`.
- UI text is Indonesian.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/ReportCard/report_card.gd` | Screen controller: paging, swipe, stagger | `CARD_ROW_ORDER` corrected, `_hide_card_rows` added |
| `Scenes/ReportCard/report_card.tscn` | The six card pages | card 1 trait pills fixed, 30 baked colours stripped, header copy fixed |
| `tests/test_report_card.gd` | Pins the screen's contract | three tests added |
| `tests/test_student_card_layout.gd` | Pins both scenes together | one test added |

---

## Task 1: Correct the stagger table

**Files:**
- Modify: `Scripts/ReportCard/report_card.gd:229-231` (`CARD_ROW_ORDER`), and add `_hide_card_rows` next to `_stagger_in_card` at `:237`
- Test: `tests/test_report_card.gd`

**Interfaces:**
- Consumes: `Juice.stagger_in(rows: Array)` and the node names `StudentCardView` creates at runtime — `BioPanel`, `IconAkademis1`, `IconAkademis2`, `IconAkademis3`, `IconKepribadian1`, `IconKepribadian2` (`StudentCardView.gd:189-278`).
- Produces: `const CARD_ROW_ORDER: Array[String]` and `func _hide_card_rows(index: int) -> void`, both matching `student_card.gd:744` and `:752` exactly.

ReportCard's table names four nodes — `Nama`, `Profil`, `Kepribadian`, `Akademis` — that `tests/test_student_card_layout.gd:224` asserts must **not** exist in either scene. `get_node_or_null` returns null for all four and they are silently skipped. Worse, the table omits `BioPanel` and all five `Icon*` clusters, so on ReportCard the bio panel and stat icons never animate in at all. ReportCard also has no `_hide_card_rows`, so the rows it *does* stagger start from their settled state rather than the invisible state `pop_in()` expects.

- [x] **Step 1: Write the failing test**

Append to `tests/test_report_card.gd`:

```gdscript
## ReportCard's stagger table drifted from StudentCard's: it named four
## nodes that test_student_card_layout asserts must not exist, and omitted
## the bio panel and all five icon clusters, so those never animated in.
## The two screens render the same card, so the table must be the same.
func test_stagger_table_matches_the_student_card() -> void:
	var report := FileAccess.get_file_as_string(
		"res://Scripts/ReportCard/report_card.gd")
	for row_name in ["BioPanel", "IconAkademis1", "IconAkademis2",
			"IconAkademis3", "IconKepribadian1", "IconKepribadian2"]:
		assert_true(report.contains('"%s"' % row_name),
			"CARD_ROW_ORDER is missing %s" % row_name)
	for dead in ["\"Nama\"", "\"Profil\"", "\"Kepribadian\",", "\"Akademis\","]:
		assert_false(report.contains(dead),
			"CARD_ROW_ORDER still names the removed node %s" % dead)


## Without the pre-hide, staggered rows start from their settled state and
## pop_in has nothing to animate from -- StudentCard calls this before
## every page transition (student_card.gd:667).
func test_rows_are_hidden_before_they_stagger_in() -> void:
	var report := FileAccess.get_file_as_string(
		"res://Scripts/ReportCard/report_card.gd")
	assert_true(report.contains("func _hide_card_rows("),
		"report_card.gd has no _hide_card_rows")
	assert_true(report.contains("_hide_card_rows("),
		"_hide_card_rows is never called")
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="report_card")
```

Expected: `test_stagger_table_matches_the_student_card` FAILS with `CARD_ROW_ORDER is missing BioPanel`.

- [x] **Step 3: Replace the table**

In `Scripts/ReportCard/report_card.gd`, replace lines 229-231 with:

```gdscript
const CARD_ROW_ORDER := ["BioPanel", "IconAkademis1", "Akademis1",
	"IconAkademis2", "Akademis2", "IconAkademis3", "Akademis3",
	"IconKepribadian1", "Kepribadian1", "IconKepribadian2", "Kepribadian2",
	"KutuBuku", "KutuBuku2"]
```

- [x] **Step 4: Add the pre-hide**

In the same file, insert this immediately **above** `func _stagger_in_card(index: int) -> void:` at line 237:

```gdscript
## Sets every row of the given page to the same invisible state pop_in()
## starts from, ahead of time -- without it the staggered rows animate
## from their settled state and the reveal reads as a flicker.
func _hide_card_rows(index: int) -> void:
	if index < 0 or index >= kertas_murid.size():
		return
	var kertas: Node = kertas_murid[index]
	for row_name in CARD_ROW_ORDER:
		var node = kertas.get_node_or_null(row_name)
		if node is Control:
			node.modulate.a = 0.0
			node.scale = Vector2(0.82, 0.82)


```

- [x] **Step 5: Call it from the page transition**

`report_card.gd:209` calls `_stagger_in_card(new_index)` inside `_transition_page`. StudentCard hides the rows earlier in the same function (`student_card.gd:667`), before the page becomes visible. Add the matching call immediately **above** line 209's `_stagger_in_card(new_index)`:

```gdscript
	# Hide the incoming page's rows before it is shown, or they would be
	# yanked back to invisible a moment later when _stagger_in_card's
	# pop_in tweens start. Mirrors student_card.gd:667.
	_hide_card_rows(new_index)
	_stagger_in_card(new_index)
```

- [x] **Step 6: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="report_card")
```

Expected: both new tests PASS, rest of the suite green.

- [x] **Step 7: Commit**

```bash
git add Scripts/ReportCard/report_card.gd tests/test_report_card.gd && git commit -m "fix(report-card): align the stagger table and pre-hide with StudentCard"
```

---

## Task 2: Put card 1's trait pills back where they belong

**Files:**
- Modify: `Scenes/ReportCard/report_card.tscn` — `KertasMurid1/KutuBuku` (around line 1143) and `KertasMurid1/KutuBuku2` (around line 1157)
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: no API. Card 1's two trait pills adopt the geometry every other card in both scenes already uses.

On ReportCard only, card 1's pills sit ~240 px too high and are 33 px too tall. Card 1 is the page the screen opens on, so this is the first thing the player sees.

Current (wrong) vs canonical (every other card, and all of `student_card.tscn`):

| Node | Property | ReportCard card 1 | Canonical |
|---|---|---|---|
| `KutuBuku` | `offset_top` | `-342.12` | `-104.119995` |
| `KutuBuku` | `offset_bottom` | `-205.12` | `-0.11999512` |
| `KutuBuku2` | `offset_left` | `-403.0` | `-417.0` |
| `KutuBuku2` | `offset_right` | `434.0` | `420.0` |
| `KutuBuku2` | `offset_top` | `-277.16016` | `-98.16016` |
| `KutuBuku2` | `offset_bottom` | `-140.16016` | `0.83984375` |

`offset_left`/`offset_right` on `KutuBuku` (`-421.0`/`421.0`) and both anchors on both nodes are already correct — leave them.

- [x] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
## Card 1's trait pills on ReportCard were hand-edited out of alignment --
## ~240px high and 33px tall of the shape every other card uses. Card 1 is
## the page both screens open on, so the drift is the first thing seen.
## Checked across both scenes and all six cards so it cannot recur.
func test_every_trait_pill_shares_one_geometry() -> void:
	for scene_path in _SCENES:
		var scene := load(scene_path) as PackedScene
		assert_not_null(scene, "%s failed to load" % scene_path)
		var inst := scene.instantiate()
		for i in range(1, 7):
			var quirk := inst.get_node_or_null(
				"KertasMurid%d/KutuBuku" % i) as Control
			assert_not_null(quirk, "%s KertasMurid%d/KutuBuku missing"
				% [scene_path, i])
			assert_eq(quirk.offset_top, -104.119995,
				"%s card %d quirk pill offset_top" % [scene_path, i])
			assert_eq(quirk.offset_bottom, -0.11999512,
				"%s card %d quirk pill offset_bottom" % [scene_path, i])

			var persona := inst.get_node_or_null(
				"KertasMurid%d/KutuBuku2" % i) as Control
			assert_not_null(persona, "%s KertasMurid%d/KutuBuku2 missing"
				% [scene_path, i])
			assert_eq(persona.offset_left, -417.0,
				"%s card %d persona pill offset_left" % [scene_path, i])
			assert_eq(persona.offset_right, 420.0,
				"%s card %d persona pill offset_right" % [scene_path, i])
			assert_eq(persona.offset_top, -98.16016,
				"%s card %d persona pill offset_top" % [scene_path, i])
			assert_eq(persona.offset_bottom, 0.83984375,
				"%s card %d persona pill offset_bottom" % [scene_path, i])
		inst.free()
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="student_card_layout")
```

Expected: FAIL with `res://Scenes/ReportCard/report_card.tscn card 1 quirk pill offset_top`, actual `-342.12`.

- [x] **Step 3: Fix the two node blocks**

In `Scenes/ReportCard/report_card.tscn`, in the `[node name="KutuBuku" type="Button" parent="KertasMurid1" …]` block, change:

```
offset_top = -104.119995
offset_bottom = -0.11999512
```

and in the `[node name="KutuBuku2" type="Button" parent="KertasMurid1" …]` block, change:

```
offset_left = -417.0
offset_top = -98.16016
offset_right = 420.0
offset_bottom = 0.83984375
```

Leave every other line in both blocks — `layout_mode`, `anchors_preset`, the four anchors, `theme_type_variation`, `text`, `unique_id` — untouched.

- [x] **Step 4: Run the test to verify it passes**

```
test_run(suite="student_card_layout")
```

Expected: PASS for both scenes, all six cards. `test_report_card` and `test_student_card` must stay green too.

- [x] **Step 5: Commit**

```bash
git add Scenes/ReportCard/report_card.tscn tests/test_student_card_layout.gd && git commit -m "fix(report-card): restore card 1's trait pill geometry"
```

---

## Task 3: Strip the baked stat-bar tints

**Files:**
- Modify: `Scenes/ReportCard/report_card.tscn` — 30 `self_modulate = Color(…)` lines
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: no API. The scene stops carrying serialised tint state; `StatBar._apply_tint()` becomes the only writer, as it already is on StudentCard.

`report_card.tscn` carries 30 `self_modulate = Color(...)` lines on its `ProgressBar` nodes; `student_card.tscn` carries **zero**. These are `StatBar._apply_tint()` results that the `@tool` script serialised back into the scene when it was last opened in the editor. They are stale-by-construction: change a category colour in `design_tokens.tres` and rebake, and the scene still holds the old value until someone reopens it. The runtime tint wins in play, but the editor viewport shows the stale colour, which is exactly the "what you see is what you get" property the authoring guide exists to protect.

- [x] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
## StatBar._apply_tint() is the single writer of a bar's tint. When the
## @tool script serialises its result back into the scene, that copy goes
## stale the moment a category colour changes in design_tokens.tres, and
## the editor viewport then lies about the colour. student_card.tscn
## carries none of these; report_card.tscn must not either.
func test_no_scene_bakes_a_stat_bar_tint() -> void:
	for scene_path in _SCENES:
		var src := FileAccess.get_file_as_string(scene_path)
		assert_false(src.contains("self_modulate = Color("),
			"%s bakes a self_modulate tint; StatBar owns that at runtime"
				% scene_path)
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="student_card_layout")
```

Expected: FAIL with `res://Scenes/ReportCard/report_card.tscn bakes a self_modulate tint`.

- [x] **Step 3: Delete the 30 lines**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && sed -i '/^self_modulate = Color(/d' Scenes/ReportCard/report_card.tscn && grep -c "self_modulate = Color" Scenes/ReportCard/report_card.tscn
```

Expected output: `0`.

The pattern is anchored to the start of the line, and every one of the 30 sits on its own line inside a `ProgressBar` node block, so nothing else matches.

- [x] **Step 4: Confirm the scene still parses and the cards still measure right**

```
filesystem_manage(op="scan")
test_run(suite="student_card_layout")
```

Expected: PASS — in particular `test_every_card_is_exactly_the_texture_size`, which instantiates both scenes and would error on a malformed file.

- [x] **Step 5: Run the neighbouring suites**

```
test_run(suite="report_card")
test_run(suite="student_card")
```

Expected: both green.

- [x] **Step 6: Commit**

```bash
git add Scenes/ReportCard/report_card.tscn tests/test_student_card_layout.gd && git commit -m "fix(report-card): drop the baked stat-bar tints and let StatBar own them"
```

---

## Task 4: Fix the header copy and drop the vestigial tutorial scrim

**Files:**
- Modify: `Scenes/ReportCard/report_card.tscn` — `PilihMurid` label text; delete the `ColorRect` and `ColorRect/ClickArea` node blocks
- Test: `tests/test_report_card.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: no API. `report_card.gd` never references `ColorRect` or `ClickArea` — verified by the grep in Step 3.

Two leftovers from the copy. The header still reads **"Pilih Muridmu"** ("Choose your student") on a screen where nothing can be chosen — it is a read-only report. And the scene carries the tutorial spotlight `ColorRect` with its `ShaderMaterial` plus a full-rect `ClickArea` `Button` on top of the cards; ReportCard has no tutorial, and `report_card.gd` has no `tutorial_steps` (pinned absent by `test_report_card.gd:47`). The `ClickArea` button is a full-screen invisible button sitting over the whole card stack.

- [x] **Step 1: Write the failing test**

Append to `tests/test_report_card.gd`:

```gdscript
## The screen is a read-only report; nothing on it can be chosen, so the
## copied "Pilih Muridmu" header was wrong. Indonesian, per project
## convention.
func test_header_reads_as_a_report_not_a_chooser() -> void:
	var scene := load(_SCENE_PATH) as PackedScene
	var inst := scene.instantiate()
	var header := inst.get_node_or_null("PilihMurid") as Label
	assert_not_null(header, "PilihMurid header label is missing")
	assert_eq(header.text, "Rapor Murid",
		"header still carries StudentCard's chooser copy")
	inst.free()


## ReportCard has no tutorial (test_script_has_no_tutorial), so the copied
## spotlight ColorRect and its full-rect ClickArea button were dead weight
## sitting over the whole card stack.
func test_tutorial_scrim_is_gone() -> void:
	var scene := load(_SCENE_PATH) as PackedScene
	var inst := scene.instantiate()
	assert_true(inst.get_node_or_null("ColorRect") == null,
		"the vestigial tutorial ColorRect is still in the scene")
	inst.free()
```

`_SCENE_PATH` already exists in that suite (`tests/test_report_card.gd:11`) — use it as-is, do not redeclare it.

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="report_card")
```

Expected: `test_header_reads_as_a_report_not_a_chooser` FAILS (actual `"Pilih Muridmu"`), and `test_tutorial_scrim_is_gone` FAILS.

- [x] **Step 3: Confirm nothing references the nodes about to be removed**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep -n "ColorRect\|ClickArea\|PilihMurid" Scripts/ReportCard/report_card.gd tests/test_report_card.gd
```

Expected: no hits in `report_card.gd`. If any appear, stop and reassess — the node is not vestigial after all.

- [x] **Step 4: Edit the scene**

In `Scenes/ReportCard/report_card.tscn`:

1. In the `[node name="PilihMurid" type="Label" parent="."]` block, change `text = "Pilih Muridmu"` to:

```
text = "Rapor Murid"
```

2. Delete the whole `[node name="ColorRect" type="ColorRect" parent="."]` block and the `[node name="ClickArea" type="Button" parent="ColorRect"]` block that follows it — from the `[node name="ColorRect"` line down to the last property line before the next `[node …]` header.

3. Delete the now-unused `[sub_resource type="ShaderMaterial" …]` block that the `ColorRect` referenced, and the `[ext_resource type="Shader" … spotlight.gdshader …]` line, **only if nothing else in the file references them**. Check first:

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep -n "spotlight\|ShaderMaterial" Scenes/ReportCard/report_card.tscn
```

4. Decrement `load_steps` on line 1 by the number of `ext_resource` + `sub_resource` blocks you removed.

- [x] **Step 5: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="report_card")
```

Expected: both new tests PASS and the whole suite is green — especially `test_scene_loads_and_instantiates`, which would catch a `load_steps` miscount.

- [x] **Step 6: Run the full suite**

```
test_run()
```

Expected: every suite green.

- [x] **Step 7: Commit**

```bash
git add Scenes/ReportCard/report_card.tscn tests/test_report_card.gd && git commit -m "fix(report-card): correct the header copy and drop the dead tutorial scrim"
```

---

## Verification

- [x] `test_run()` — every suite green.
- [x] Screenshot check: seed playtest state (`F1` → ⚡ Seed Playtest State), teleport to Lobby, open **Rapor Murid**. Confirm against StudentCard side by side:
  - card 1's two trait pills sit at the bottom of the card, same as cards 2-6;
  - the bio panel and the five stat icons animate in with the bars when paging;
  - stat bar colours match StudentCard's;
  - the header reads "Rapor Murid";
  - paging left/right and swipe still work.

## Out of scope

Extracting the `KertasMuridN` subtree into a shared `PackedScene` instanced six times per screen. It is the real fix for the duplication — 228 authored nodes across the two files — but `tests/test_student_card_layout.gd:224` and `:235` do raw `[node name="…" parent="KertasMurid%d"` string matching on the `.tscn` text and would both need rewriting as tree walks, and ReportCard's `find_child("Aprove") == null` contract means the shared scene cannot carry the approve chrome. Separate project.
