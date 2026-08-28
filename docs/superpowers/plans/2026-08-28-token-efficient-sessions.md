# Token-Efficient Coding Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the token cost of a typical verification session in this project by roughly 80%, by removing the two workflows that measurably dominate it, without weakening test coverage or code quality.

**Architecture:** Two interventions, both small. (1) A one-call debug seed that puts the game into a mid-game playable state — roster approved, money stocked, inventory full, tutorial bypassed — so verifying any screen no longer requires driving the shop purchase flow by simulated clicks. (2) A `CLAUDE.md` section that fixes the MCP tool-call discipline (scoped `get_ui_elements`, `test_run` over screenshots, grep-before-read), so the savings survive into future sessions instead of being rediscovered each time.

**Tech Stack:** Godot 4.6 (GDScript), the `godot-ai` MCP editor bridge, the in-editor `McpTestSuite` runner.

**Spec:** No separate design doc. This plan is written directly from the user's request ("Pareto 80/20 token efficiency without sacrificing code quality") plus measured evidence from the 2026-08-28 session, quantified below.

## The 80/20 Analysis

Measured from the 2026-08-28 session, which is representative (one small UI change, verified end to end):

| Rank | Token sink | Observed cost | Root cause |
|---|---|---|---|
| 1 | Manual click-through verification | ~60 tool calls (`input_mouse` pairs + `editor_screenshot`); each screenshot ≈1–2k tokens. Reaching "inventory containing items" took ~45 round trips and failed twice before succeeding. | No way to reach a mid-game state except by playing to it. |
| 2 | `get_ui_elements` full-tree dumps | Called 6×; the DebugManager dump alone returned 58 verbose JSON elements (~8–10k tokens each call). | Called without `root_path`/`max_depth`, so it serialises the whole tree. |
| 3 | Broad file reads and `find` dumps | One `find` returned 75.8 KB (truncated to disk); several 1,500-line scripts read in full. | Partly already solved — `CLAUDE.md` exists and gives the architecture map. |

**The 20% we are building:** fixes for #1 and #2. Together they account for the large majority of the waste, and #1 alone collapses a ~45-call sequence into ~3.

**Deliberately NOT doing** (the long tail — high effort, low marginal saving):
- Custom MCP tooling or a screenshot-diffing / visual-regression harness.
- A headless CI test runner (the in-editor runner is already fast and compact: 278 tests in ~2.3 s).
- Splitting the large scripts (`student_card.gd` 1651 lines, `SchoolDay.gd` 1508). Real, but a refactor of that size costs far more than it saves and risks the tutorial's string-based node paths.
- Any change to test coverage. Coverage is the quality floor; efficiency comes from cheaper *verification loops*, never from fewer tests.

## Global Constraints

- Godot **4.6**. Project is mobile/portrait; main scene `res://Scenes/Splashscreen/Splashscreen.tscn`.
- Test suites live in `tests/test_*.gd`, extend `McpTestSuite`, and **must be `@tool`**.
- **No test may be a coroutine.** The runner calls `suite.call(name)` without awaiting; an `await` silently aborts the test and it reports "0 assertions".
- Autoloads are only visible to the in-editor test runner if the autoload script is `@tool`. `GameState.gd` and `ItemDatabase.gd` already are. `DebugManager.gd` is **not**, and this plan does not change that (see Task 2 rationale).
- Never add a `theme_override_*` carrying color/font/stylebox information (layout-only constants excepted). Not exercised by this plan, but it binds any UI touched.
- Commits use Conventional Commits with a scope, e.g. `feat(debug): ...`.
- Game-facing UI text is Indonesian; code and comments are English.

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/GameState.gd` | Owns session state, including `inventory`. Gains the pure state-seeding function — testable because this autoload is already `@tool`. | Modify |
| `tests/test_economy_state.gd` | The economy/inventory suite. Gains coverage for the new seeding function. | Modify |
| `Scripts/Debug/DebugManager.gd` | The playtest overlay. Gains one button + one handler that composes existing helpers with the new `GameState` call. | Modify |
| `CLAUDE.md` | The always-loaded project guide. Gains the workflow section so the discipline persists across sessions. | Modify |

**Why the seeding logic goes on `GameState`, not `DebugManager`:** `DebugManager.gd` is not `@tool`, so nothing in it is reachable from the in-editor test runner. Making a 1,263-line UI script `@tool` would cause its `_ready()` → `_build_ui()` to run whenever a human merely opens a scene, requiring an `Engine.is_editor_hint()` gate for no benefit. Putting the state mutation on the already-`@tool` `GameState` makes the logic genuinely unit-tested, and leaves `DebugManager` holding only untested UI wiring — consistent with the rest of that file, which has no test coverage today.

---

# Task 1: `GameState.seed_playtest_inventory()`

**Files:**
- Modify: `Scripts/GameState.gd` (add after `get_inventory_quantity`, around line 115)
- Test: `tests/test_economy_state.gd` (append)

**Interfaces:**
- Consumes: `ItemDatabase.get_all_items() -> Array[ItemData]`; `GameState.inventory: Dictionary`; `GameState.inventory_changed` signal (no arguments).
- Produces: `GameState.seed_playtest_inventory(quantity: int = 2) -> void`. Task 2 calls this.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_economy_state.gd`:

```gdscript
func test_seed_playtest_inventory_stocks_every_item() -> void:
	GameState.inventory.clear()
	GameState.seed_playtest_inventory(2)
	for item_name in _EXPECTED_ITEMS:
		assert_eq(GameState.get_inventory_quantity(item_name), 2,
			"seed must stock: " + item_name)
	GameState.inventory.clear()

func test_seed_playtest_inventory_replaces_rather_than_stacks() -> void:
	GameState.inventory.clear()
	GameState.seed_playtest_inventory(2)
	GameState.seed_playtest_inventory(3)
	assert_eq(GameState.get_inventory_quantity("Komik"), 3,
		"a second seed replaces the quantity instead of adding to it")
	assert_eq(GameState.inventory.size(), _EXPECTED_ITEMS.size(),
		"seeding twice must not duplicate entries")
	GameState.inventory.clear()

func test_seed_playtest_inventory_emits_changed_once() -> void:
	GameState.inventory.clear()
	var seen := []
	var cb := func(): seen.append(1)
	GameState.inventory_changed.connect(cb)
	GameState.seed_playtest_inventory(1)
	GameState.inventory_changed.disconnect(cb)
	assert_eq(seen.size(), 1,
		"one seed must emit inventory_changed exactly once, not once per item")
	GameState.inventory.clear()
```

The third test is the one that matters for cost: building the seed out of repeated `add_to_inventory()` calls would fire the signal nine times and make every listening screen rebuild its grid nine times.

- [ ] **Step 2: Run the tests and confirm they fail**

Run the `economy_state` suite via the MCP tool:

```
test_run(suite="economy_state")
```

Expected: 3 failures naming `seed_playtest_inventory` as an invalid/nonexistent method.

- [ ] **Step 3: Implement it in `Scripts/GameState.gd`**

Insert directly after `get_inventory_quantity()`:

```gdscript
## Debug/playtest helper: stock one entry per known item so a session can
## exercise the inventory screen without driving the shop purchase flow.
##
## Replaces the inventory rather than adding to it, so repeated calls are
## idempotent, and emits inventory_changed once at the end rather than once
## per item -- listening screens rebuild their grid on that signal.
func seed_playtest_inventory(quantity: int = 2) -> void:
	inventory.clear()
	if quantity > 0:
		for item in ItemDatabase.get_all_items():
			inventory[item.item_name] = quantity
	inventory_changed.emit()
```

- [ ] **Step 4: Run the tests and confirm they pass**

```
test_run(suite="economy_state")
```

Expected: all PASS.

- [ ] **Step 5: Run the full suite to confirm no regression**

```
test_run()
```

Expected: 280 passed, 1 failed. The single expected failure is the known-broken
`audio_director / test_volumes_persist_across_a_fresh_director` (it is a coroutine, so
the runner abandons it — see `CLAUDE.md` Known Issues). Any *other* failure is a real
regression from this task.

- [ ] **Step 6: Commit**

```bash
git add Scripts/GameState.gd tests/test_economy_state.gd
git commit -m "feat(debug): add one-call playtest inventory seeding to GameState"
```

---

# Task 2: The "Seed Playtest State" debug button

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd` (handler beside `_set_money`, around line 628; button in `_build_general_panel`, around line 344)

**Interfaces:**
- Consumes: `GameState.seed_playtest_inventory(quantity)` from Task 1; the existing `DebugManager._auto_approve_students()`, `_refresh_ui_fields()`, and `log_message(msg)`.
- Produces: `DebugManager._seed_playtest_state()`, reachable from the overlay's General tab. Nothing else consumes it in code — it is a human/agent entry point.

No unit test: `DebugManager.gd` is not `@tool`, so the in-editor runner cannot instantiate it, and the file has no existing coverage. The deliverable is verified by launching the game once (Step 4) — which is itself the cheap path this task exists to create.

- [ ] **Step 1: Add the handler**

In `Scripts/Debug/DebugManager.gd`, insert immediately after the `_set_money()` function (it ends with `_refresh_ui_fields()`, just before `func _set_time_scale`):

```gdscript
## One call to reach a mid-game state: roster approved, money stocked,
## inventory full, lobby tutorial bypassed. Exists so verifying a screen
## costs one click instead of playing the game up to that screen.
func _seed_playtest_state() -> void:
	_auto_approve_students()
	GameState.player_money = 999999
	GameState.seed_playtest_inventory(5)
	GameState.lobby_tutorial_completed = true

	log_message("Seeded playtest state: roster, 999999G, full inventory, tutorial bypassed.")

	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.has_method("_update_money_display"):
		cur_scene._update_money_display()
	_refresh_ui_fields()
```

`_auto_approve_students()` already refreshes the roster and re-seats lobby portraits; the trailing `_refresh_ui_fields()` is what repaints the money label and the tutorial-toggle caption after this function changes them.

- [ ] **Step 2: Add the button at the top of the General panel**

In `_build_general_panel()`, find this exact anchor:

```gdscript
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 35)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)
	
	# Row 1: Week tracking & Grade
```

Insert between `margin_container.add_child(vbox)` and the `# Row 1` comment:

```gdscript
	# Row 0: One-click playtest state (most-used action, so it goes first)
	var btn_seed = Button.new()
	btn_seed.text = " ⚡ Seed Playtest State "
	btn_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seed.custom_minimum_size = Vector2(0, 95)
	btn_seed.add_theme_font_size_override("font_size", 30)
	btn_seed.pressed.connect(_seed_playtest_state)
	vbox.add_child(btn_seed)

	var sep_seed = HSeparator.new()
	vbox.add_child(sep_seed)
	
```

Sizing and font match the surrounding buttons in this panel (`custom_minimum_size = Vector2(0, 80..95)`, `font_size` 28–30), so it inherits the overlay's existing look.

- [ ] **Step 3: Launch the game**

```
project_run(mode="main")
```

- [ ] **Step 4: Verify the button in one pass**

Press `F1` (the debug overlay's keyboard shortcut — far cheaper than the 5-tap corner gesture), click the new button, then take **one** screenshot.

```
game_manage(op="input_key", params={"key": "F1", "pressed": true})
```

Then click the seed button, then:

```
editor_screenshot(source="game")
```

Confirm in that single screenshot:
1. The money label reads `999999G`.
2. The tutorial toggle reads `Bypass Tutorial Lobby: ON (Bypassed)` — this proves `_refresh_ui_fields()` picked up the direct write to `lobby_tutorial_completed`.

Then switch to the **Scenes** tab, teleport to the Lobby, and open Inventory. It should show a full grid with `×5` badges, with no shop visit. That whole check is a handful of calls — the sequence it replaces took ~45.

- [ ] **Step 5: Stop the game and restore the editor scene**

```
project_manage(op="stop")
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
```

Leaving the main scene open matters: `test_run` warns (`scene_warning`) and some suites report phantom failures when a different scene is edited.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Debug/DebugManager.gd
git commit -m "feat(debug): add one-click Seed Playtest State button"
```

---

# Task 3: Record the workflow in `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` (new section immediately after the existing `## Godot MCP` section, before `## Known issues`)

**Interfaces:**
- Consumes: the seed button from Task 2 (the section tells future sessions to use it).
- Produces: nothing in code. This is the part that makes the savings recur instead of being rediscovered.

- [ ] **Step 1: Insert the section**

In `CLAUDE.md`, immediately before the line `## Known issues (as of 2026-08-28)`, insert:

```markdown
## Working efficiently here

Verification, not implementation, dominates the cost of a session in this
project. Three rules, in order of how much they save:

**1. Never play the game to reach a state — seed it.** The debug overlay
(`F1`, or 5 taps in the top-right corner) has **⚡ Seed Playtest State** at the
top of its General tab: roster approved, 999999G, full inventory, lobby
tutorial bypassed. Combine it with the overlay's **Scenes** tab, which
teleports directly to MainMenu / Lobby / StudentCard / AturJadwal / SchoolDay
/ SemesterEnd / Splashscreen. Seed, teleport, screenshot once — three calls.
Driving the shop purchase flow by simulated clicks to reach the same state
took roughly forty-five, and is flaky because coordinates must be rescaled
from the 1080×1920 design space to the actual window.

**2. Scope every `get_ui_elements` call.** Called bare it serialises the whole
tree — the debug overlay alone returns 58 verbose nodes. Always pass
`root_path` and a shallow `max_depth`:

    game_manage(op="get_ui_elements",
                params={"root_path": "/root/Inventory/MainLayout", "max_depth": 3})

Note the runtime path quirk: autoloads answer to `/root/<Name>` (e.g.
`/root/DebugManager`) but the reply echoes paths relative to the current
scene (`/Inventory/../DebugManager`). Bare `/root` returns nothing.

**3. Prefer `test_run` over screenshots.** The whole suite — 281 tests, 22
suites — returns a compact JSON summary in about two seconds. One screenshot
costs more tokens than the entire run. Reach for a screenshot only to judge
something genuinely visual (layout, spacing, color); use `test_run` for
anything about behaviour or wiring. Many suites here are deliberately
source-text scans (`src.contains(...)`) precisely because they are cheap and
do not need the scene instantiated.

Two smaller habits: grep before reading (several scripts here exceed 1,500
lines — read the range you need, not the file), and read `logs_read(source="editor")`
for parse errors, since boot-time failures never reach the game log.

None of this trades away test coverage. Coverage is the quality floor; the
savings come from cheaper verification loops, not from fewer tests.
```

- [ ] **Step 2: Update the stale test count in the Testing section**

The `## Testing` section currently reads `22 suites, 278 tests.` Task 1 added
three tests. Change that sentence to:

```markdown
(`addons/godot_ai/testing/test_suite.gd`), and run **inside the editor** via
the Godot AI MCP `test_run` tool. 22 suites, 281 tests.
```

- [ ] **Step 3: Verify the document is coherent**

Re-read the two edited regions. Confirm the new section sits between `## Godot MCP`
and `## Known issues`, that the test count matches what `test_run()` actually
reported in Task 1 Step 5, and that no heading level was broken.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record the token-efficient verification workflow"
```

---

## Self-Review

**Coverage of the stated goal.** The 80/20 table names three sinks; Tasks 1–2
remove #1, Task 3 rule 2 removes #2, Task 3's closing paragraph addresses #3
(already partly handled by `CLAUDE.md` existing). The "not doing" list is
explicit so the long tail is a recorded decision rather than an omission.

**Placeholders.** None. Every code step carries the literal text to insert;
every run step carries the exact call and expected result.

**Type and name consistency.** `seed_playtest_inventory(quantity: int = 2) -> void`
is defined in Task 1 Step 3 and called with that name in Task 1's tests and in
Task 2 Step 1. `_seed_playtest_state()` is defined in Task 2 Step 1 and bound in
Step 2. `_auto_approve_students()`, `_refresh_ui_fields()`, `log_message()`,
`ItemDatabase.get_all_items()`, `GameState.inventory_changed` (no arguments),
`GameState.lobby_tutorial_completed`, and `GameState.player_money` were each
verified against the current source before being referenced here.

**Known risk.** Task 1 Step 5's expected count (280 pass / 1 fail) assumes the
suite is at 278 total before this plan runs and that the one pre-existing
failure is still the `audio_director` coroutine. If the branch has moved,
re-baseline with `test_run()` before starting rather than treating a different
number as a regression.
