# Inventory Mobile Layout & Item-Apply Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Inventory screen as a clear portrait-mobile layout with a bottom-sheet item detail and a full-screen "apply to students" flow (live stat preview + particle/SFX payoff), make every item functional for Mood/Energy/skills, and persist the inventory to disk with a debug session-reset.

**Architecture:** Screen 1 (`inventory.tscn`/`inventory.gd`) is a 3-zone theme-driven layout that instances two sub-surfaces on demand: `ItemDetailSheet` (bottom sheet, item info + "Efek" block) and `ApplyItemScreen` (multi-select students, per-student `StatBar` preview, staged `RewardBurst`/`CelebrationConfetti` payoff). `GameState.use_item()` is fixed to write the canonical roster keys and gains skill boosts; `use_item_on_students()` is a new all-or-nothing batch. `GameState.inventory` persists to `user://inventory.cfg`, flushed on every scene transition; `DebugManager` gets a "Forget Session" button.

**Tech Stack:** Godot 4.6 (GDScript, `mobile` renderer), Godot AI MCP for editor/tests, `McpTestSuite` test suites, `DesignTokens`/`ThemeFactory` theme system, `Juice`/`AnimUtils` animation helpers, `AudioDirector` SFX.

**Spec:** `docs/superpowers/specs/2026-09-07-inventory-mobile-layout-and-item-apply.md`

## Global Constraints

- Godot **4.6**, portrait **1080×1920**, `mobile` renderer.
- All UI text and game-facing identifiers are **Indonesian**; systems code is English. Match the surrounding file.
- **No `theme_override_*`** except layout-only constants (`separation`, `margin_*`). Use `ThemeFactory` type variations; add one + rebake if none fits.
- **No runtime visual construction.** Static chrome authored in `.tscn`; repeated rows are `PackedScene` templates; responsive geometry is a `@tool` script with documented `@export`s. Instancing a template at runtime is allowed; building a widget's nodes/styleboxes in code is not.
- Every script has a `##` file header; every `@export` has a `##` line (`tests/test_script_documentation.gd`).
- `tests/test_viewport_editability.gd` `BASELINE` only ever lowers. New scripts must not appear in it.
- Test suites: `@tool`, extend `McpTestSuite`, **no coroutine tests** (`await` silently aborts), scripts the runner instantiates live are `@tool` with editor-hint-gated `_ready` side effects. Run in-editor via MCP `test_run`.
- No emoji as UI iconography. Existing emoji in strings elsewhere is not our concern, but new labels use text or real SVG textures.
- Colours from `DesignTokens.load_default()`, never `Color(...)` literals in scripts.
- Navigation via `Transition.change_scene(path, Transition.Style.*)`.
- **MCP bridge is single-client.** The controller session holds the editor; subagents write code/text only. After editing a `.gd` from outside the editor, `filesystem_manage(op="scan")`; if a new `@export`/function still reads stale, a no-op `script_patch` (add+remove a blank line) forces the reload. Build every `.tscn` through the editor (`scene_open` → `node_create`/`node_set_property`/`batch_execute` → `scene_save`), never hand-edit while attached.
- `anchors_preset` is inert via MCP — set the four anchor_* values. Numbers unquoted. `node_create` appends last; fix z-order with `move_node`.

---

## File Structure

**New scripts**
- `Scripts/Inventory/ItemDetailSheet.gd` — `@tool class_name ItemDetailSheet`. Bottom sheet: fills item icon/name/category-chip/description and shows/hides five authored `EfekRow` instances; emits `apply_requested(item)` / `dismissed`. No runtime node building.
- `Scripts/Inventory/ApplyStudentRow.gd` — `@tool class_name ApplyStudentRow`. One selectable student card: portrait, name, tired/maxed badge, up to five authored `StatBarRow` instances; `set_preview(active)` animates the affected bars; emits `selection_changed`.
- `Scripts/Inventory/ApplyItemScreen.gd` — `@tool class_name ApplyItemScreen`. Full-screen apply modal: instances `ApplyStudentRow` per approved student, gates the confirm button, calls `GameState.use_item_on_students`, plays the staged payoff, emits `applied(results)` / `cancelled`.

**New scenes**
- `Scenes/Inventory/EfekRow.tscn` — `[NeedIcon TextureRect][ValueLabel &"ResultDeltaLabel"][ExplainLabel &"MicroLabel"]`. No script (plain `HBoxContainer` root).
- `Scenes/Inventory/StatBarRow.tscn` — `[NameLabel &"TitleLabel"][StatBar][ValueLabel &"TitleLabel"][DeltaLabel &"ResultDeltaLabel"]`. No script (`HBoxContainer` root).
- `Scenes/Inventory/ItemDetailSheet.tscn` — `Scrim` + bottom-anchored `Sheet` (`&"Card"`), five `EfekRow` instances in `EfekList`, `ApplyButton &"PrimaryButton"`. Script `ItemDetailSheet.gd`.
- `Scenes/Inventory/ApplyStudentRow.tscn` — `&"Card"` root, `Check` + `Portrait` + name/badges + five `StatBarRow` instances. Script `ApplyStudentRow.gd`.
- `Scenes/Inventory/ApplyItemScreen.tscn` — `&"Scrim"` background + `Card` with recap strip, `EffectSummary`, `Scroll`→`Rows`, `SelectAllButton`/`CancelButton`/`ConfirmButton`. Script `ApplyItemScreen.gd`.

**Rewritten**
- `Scenes/Inventory/inventory.tscn` — 3-zone portrait layout (Header / FilterRow chips / GridArea), authored `ToastLabel`, no `StyleBoxFlat` subresources (header `StyleBoxTexture` survives).
- `Scripts/Inventory/inventory.gd` — grid populate + category filter + route to sheet/apply screen + badge bounce + toast. Zero runtime visual construction.

**Modified**
- `Scripts/Inventory/ItemData.gd` — `@export_group("Skill Boost")` with `akademis_boost` / `seni_budaya_boost` / `olahraga_boost`.
- `Scripts/Inventory/ItemDatabase.gd` — `register()` gains three params; `DEFAULT_ITEMS` gets skill values + fuller placeholder `desc`.
- `Scripts/Inventory/InventorySlot.gd` / `.tscn` — `bounce_badge()`, authored `Shine` node + `shine_min_quantity` export.
- `Scripts/GameState.gd` — fix `use_item` keys + skills; `use_item_on_students()`; `save_inventory`/`load_inventory`/`clear_inventory_save`/`forget_session` + pure `_write/_read_inventory_from`; `load_inventory()` in `_ready`.
- `Scripts/Transition/transition.gd` — editor-gated `GameState.save_inventory()` at the top of `change_scene`.
- `Scripts/Debug/DebugManager.gd` — "Forget Session" button in `_build_general_panel`.
- `Scripts/Design/ThemeFactory.gd` — `FilterChipButton` variation; theme rebaked.
- `tests/test_inventory.gd` — new-layout assertions, drop sidebar-era ones.
- `tests/test_inventory_slot.gd` — badge bounce + shine.
- `tests/test_viewport_editability.gd` — drop the `inventory.gd` `BASELINE` entry.
- `CLAUDE.md` — revise the "No save system" paragraph.

**New tests**
- `tests/test_item_catalog.gd`, `tests/test_use_item_on_students.gd`, `tests/test_inventory_persistence.gd`, `tests/test_item_detail_sheet.gd`, `tests/test_apply_student_row.gd`, `tests/test_apply_item_screen.gd`.

---

## Task 1: `ItemData` skill fields + catalog values + descriptions

**Files:**
- Modify: `Scripts/Inventory/ItemData.gd`
- Modify: `Scripts/Inventory/ItemDatabase.gd:119-155` (`register`), `Scripts/Inventory/ItemDatabase.gd:14-104` (`DEFAULT_ITEMS`), `Scripts/Inventory/ItemDatabase.gd:110-117` (`_init_database`)
- Test: `tests/test_item_catalog.gd` (create)

**Interfaces:**
- Produces: `ItemData.akademis_boost: int`, `ItemData.seni_budaya_boost: int`, `ItemData.olahraga_boost: int` (default 0). `ItemDatabase.register(name, price, icon, description, category, display_size, mood_boost, energy_boost, akademis_boost := 0, seni_budaya_boost := 0, olahraga_boost := 0)`. Catalog values per the table below.

- [ ] **Step 1: Write the failing test**

Create `tests/test_item_catalog.gd`:

```gdscript
@tool
extends McpTestSuite

## The shop/inventory item catalog: skill-boost fields exist and are wired
## through ItemDatabase, and every item has its own non-empty description.

func suite_name() -> String:
    return "item_catalog"

func test_item_data_has_skill_boost_fields() -> void:
    var d := ItemData.new()
    assert_true("akademis_boost" in d, "ItemData needs akademis_boost")
    assert_true("seni_budaya_boost" in d, "ItemData needs seni_budaya_boost")
    assert_true("olahraga_boost" in d, "ItemData needs olahraga_boost")
    assert_equal(0, d.akademis_boost, "skill boosts default to 0")

func test_catalog_skill_values_are_registered() -> void:
    assert_equal(8, ItemDatabase.get_item("Raket").olahraga_boost)
    assert_equal(6, ItemDatabase.get_item("Bank Soal").akademis_boost)
    assert_equal(4, ItemDatabase.get_item("Komik").seni_budaya_boost)
    assert_equal(0, ItemDatabase.get_item("Mie Instan").akademis_boost)

func test_every_item_has_a_unique_nonempty_description() -> void:
    var items := ItemDatabase.get_all_items()
    assert_true(items.size() >= 9, "catalog has all base items")
    var seen := {}
    for it in items:
        assert_true(it.description.strip_edges() != "",
            "description missing for: " + it.item_name)
        assert_false(seen.has(it.description),
            "duplicate description: " + it.description)
        seen[it.description] = true
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")`, then `test_run(suite="item_catalog")`.
Expected: FAIL — `akademis_boost` not in `ItemData`; `Raket.olahraga_boost` errors/0.

- [ ] **Step 3: Add the `ItemData` fields**

Append to `Scripts/Inventory/ItemData.gd` after `energy_boost`:

```gdscript
@export_group("Skill Boost")
## Added to the target student's akademis (roster key akademis1) when the
## item is used, times quantity, clamped [0, 100]. Only Buku items set this.
@export var akademis_boost: int = 0
## Same, for seni_budaya (roster key akademis2).
@export var seni_budaya_boost: int = 0
## Same, for olahraga (roster key akademis3).
@export var olahraga_boost: int = 0
```

- [ ] **Step 4: Widen `register()` and `_init_database()`**

In `Scripts/Inventory/ItemDatabase.gd`, `register()` signature — add after `energy_boost: int = 0`:

```gdscript
    akademis_boost: int = 0,
    seni_budaya_boost: int = 0,
    olahraga_boost: int = 0
```

In the "update existing" branch, mirror the `mood_boost` pattern:

```gdscript
        if akademis_boost != 0:
            existing.akademis_boost = akademis_boost
        if seni_budaya_boost != 0:
            existing.seni_budaya_boost = seni_budaya_boost
        if olahraga_boost != 0:
            existing.olahraga_boost = olahraga_boost
```

In the "create new" branch, after `data.energy_boost = energy_boost`:

```gdscript
    data.akademis_boost = akademis_boost
    data.seni_budaya_boost = seni_budaya_boost
    data.olahraga_boost = olahraga_boost
```

In `_init_database()`, after `var energy = info.get("energy", 0)`:

```gdscript
        var akademis = info.get("akademis", 0)
        var seni = info.get("seni_budaya", 0)
        var olahraga = info.get("olahraga", 0)
```

and pass them as the last three args to `register(...)`.

- [ ] **Step 5: Update `DEFAULT_ITEMS`**

Prefix the array with a comment: `# [PLACEHOLDER] item flavour copy + skill values pending a balance/writing pass`.
For each entry, set `desc` and add skill keys per this table (keys absent = 0):

| name | desc | akademis | seni_budaya | olahraga |
|---|---|---|---|---|
| Bank Soal | `"Bundel soal-soal ujian tahun lalu; latihan paling ampuh sebelum tes."` | 6 | – | – |
| Komik | `"Komik favorit yang bikin lupa waktu — hiburan cepat saat penat."` | – | 4 | – |
| LKS | `"Lembar Kerja Siswa untuk mengasah materi pelan-pelan di rumah."` | 5 | – | – |
| Lompat Tali | `"Tali lompat warna-warni; pemanasan seru yang bikin badan segar."` | – | – | 6 |
| Raket | `"Raket bulu tangkis pinjaman kakak kelas, masih enak dipakai tanding."` | – | – | 8 |
| Cilok | `"Cilok kenyal berbumbu kacang, jajanan wajib jam istirahat."` | – | – | – |
| Mie Instan | `"Semangkuk mie instan hangat — pengganjal perut andalan anak kos."` | – | – | – |
| Pop Ice | `"Es blender manis warna cerah yang langsung menaikkan mood."` | – | – | – |
| Susu Kotak | `"Susu kotak dingin, katanya bikin fokus pas jam pelajaran pagi."` | – | 3 | – |

Leave each entry's existing `mood` / `energy` values untouched.

- [ ] **Step 6: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="item_catalog")`.
Expected: PASS (3 tests). If `Raket.olahraga_boost` still reads 0 after a scan, do a no-op `script_patch` on `ItemDatabase.gd` and re-run.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Inventory/ItemData.gd Scripts/Inventory/ItemDatabase.gd tests/test_item_catalog.gd tests/test_item_catalog.gd.uid
git commit -m "feat(inventory): add item skill-boost fields and per-item descriptions"
```

---

## Task 2: `GameState.use_item` key fix + skills, and `use_item_on_students`

**Files:**
- Modify: `Scripts/GameState.gd:222-251` (`use_item`), add `use_item_on_students` after it
- Test: `tests/test_use_item_on_students.gd` (create)

**Interfaces:**
- Consumes: `ItemData.{mood_boost,energy_boost,akademis_boost,seni_budaya_boost,olahraga_boost}` (Task 1).
- Produces:
  - `GameState.use_item(item, student_id, quantity := 1) -> Dictionary` now returns `{"applied": bool, "mood_delta","energy_delta","akademis_delta","seni_delta","olahraga_delta": float}` and writes roster keys `kepribadian1` (mood), `kepribadian2` (energy), `akademis1/2/3` (skills).
  - `GameState.use_item_on_students(item: ItemData, student_ids: Array) -> Dictionary` → `{"applied": bool, "results": Array}`, each result `{"student_id": int, "name": String, "mood_delta","energy_delta","akademis_delta","seni_delta","olahraga_delta": float}`. All-or-nothing: refuses if `get_inventory_quantity(item.item_name) < student_ids.size()`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_use_item_on_students.gd`:

```gdscript
@tool
extends McpTestSuite

## GameState.use_item writes the canonical roster keys (kepribadian1/2,
## akademis1/2/3), not the dead "mood"/"energy" keys; use_item_on_students
## is all-or-nothing across a list of students.

func suite_name() -> String:
    return "use_item_on_students"

var _inv_backup: Dictionary
var _roster_backup: Array

func setup() -> void:
    _inv_backup = GameState.inventory.duplicate(true)
    _roster_backup = GameState.approved_students.duplicate(true)
    GameState.inventory = {"TestItem": 3}
    GameState.approved_students = [
        {"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": 50.0,
         "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0},
        {"id": 2, "name": "B", "kepribadian1": 95.0, "kepribadian2": 50.0,
         "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0},
    ]

func teardown() -> void:
    GameState.inventory = _inv_backup
    GameState.approved_students = _roster_backup

func _item(mood := 10, energy := 5, ak := 6) -> ItemData:
    var d := ItemData.new()
    d.item_name = "TestItem"
    d.mood_boost = mood
    d.energy_boost = energy
    d.akademis_boost = ak
    return d

func test_use_item_writes_canonical_keys() -> void:
    var r := GameState.use_item(_item(), 1, 1)
    assert_true(r["applied"])
    assert_equal(60.0, GameState.approved_students[0]["kepribadian1"], "mood -> kepribadian1")
    assert_equal(55.0, GameState.approved_students[0]["kepribadian2"], "energy -> kepribadian2")
    assert_equal(46.0, GameState.approved_students[0]["akademis1"], "akademis -> akademis1")
    assert_false(GameState.approved_students[0].has("mood"), "no dead mood key written")
    assert_equal(10.0, r["mood_delta"])
    assert_equal(6.0, r["akademis_delta"])

func test_use_item_clamps_at_100() -> void:
    var r := GameState.use_item(_item(10, 5, 6), 2, 1)  # student B mood 95 -> 100
    assert_equal(100.0, GameState.approved_students[1]["kepribadian1"])
    assert_equal(5.0, r["mood_delta"], "delta reflects the clamp")

func test_batch_all_or_nothing_refuses_when_short() -> void:
    GameState.inventory = {"TestItem": 2}
    var r := GameState.use_item_on_students(_item(), [1, 2, 1])
    assert_false(r["applied"])
    assert_equal(2, GameState.inventory["TestItem"], "stock untouched on refusal")

func test_batch_happy_path_consumes_and_reports() -> void:
    var r := GameState.use_item_on_students(_item(), [1, 2])
    assert_true(r["applied"])
    assert_equal(2, r["results"].size())
    assert_true(r["results"][0].has("student_id") and r["results"][0].has("name"))
    assert_true(r["results"][0].has("akademis_delta"))
    assert_equal(1, GameState.inventory["TestItem"], "2 of 3 consumed")

func test_batch_refuses_null_and_empty() -> void:
    assert_false(GameState.use_item_on_students(null, [1])["applied"])
    assert_false(GameState.use_item_on_students(_item(), [])["applied"])
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="use_item_on_students")`.
Expected: FAIL — `kepribadian1` unchanged (old code wrote `"mood"`); `use_item_on_students` missing.

- [ ] **Step 3: Rewrite `use_item`**

Replace the body of `GameState.use_item` (keep the doc comment, update it to mention skills + canonical keys):

```gdscript
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary:
    var refused := {"applied": false, "mood_delta": 0.0, "energy_delta": 0.0,
        "akademis_delta": 0.0, "seni_delta": 0.0, "olahraga_delta": 0.0}
    if item == null or quantity <= 0:
        return refused
    if get_inventory_quantity(item.item_name) < quantity:
        return refused

    var target: Dictionary = {}
    for student in approved_students:
        if student.get("id", -1) == student_id:
            target = student
            break
    if target.is_empty():
        return refused

    var fields := [
        ["kepribadian1", item.mood_boost,        "mood_delta"],
        ["kepribadian2", item.energy_boost,      "energy_delta"],
        ["akademis1",    item.akademis_boost,    "akademis_delta"],
        ["akademis2",    item.seni_budaya_boost, "seni_delta"],
        ["akademis3",    item.olahraga_boost,    "olahraga_delta"],
    ]
    var out := {"applied": true}
    for f in fields:
        var before: float = float(target.get(f[0], 0.0))
        var after := clampf(before + float(f[1]) * quantity, 0.0, STAT_MAX)
        target[f[0]] = after
        out[f[2]] = after - before

    remove_from_inventory(item.item_name, quantity)
    run_stats.record_item_use(quantity)
    return out
```

- [ ] **Step 4: Add `use_item_on_students`**

Immediately after `use_item`:

```gdscript
## Applies one copy of `item` to each id in `student_ids` (one application
## each; quantity is fixed at 1 per student). All-or-nothing: if the stack
## cannot cover every id, nothing is applied and "applied" is false.
## Returns {"applied": bool, "results": Array} where each result is
## {"student_id": int, "name": String, "mood_delta","energy_delta",
##  "akademis_delta","seni_delta","olahraga_delta": float}.
func use_item_on_students(item: ItemData, student_ids: Array) -> Dictionary:
    if item == null or student_ids.is_empty():
        return {"applied": false, "results": []}
    if get_inventory_quantity(item.item_name) < student_ids.size():
        return {"applied": false, "results": []}
    var results: Array = []
    for sid in student_ids:
        var sname := ""
        for s in approved_students:
            if s.get("id", -1) == sid:
                sname = str(s.get("name", ""))
                break
        var r := use_item(item, sid, 1)
        if r["applied"]:
            r["student_id"] = sid
            r["name"] = sname
            results.append(r)
    return {"applied": not results.is_empty(), "results": results}
```

- [ ] **Step 5: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="use_item_on_students")` (expect 6 PASS), then `test_run(suite="inventory")` to confirm the old suite still parses (it will fail assertions that Task 12 rewrites — note which, do not fix here; if it *errors* rather than fails, stop and investigate).

- [ ] **Step 6: Commit**

```bash
git add Scripts/GameState.gd tests/test_use_item_on_students.gd tests/test_use_item_on_students.gd.uid
git commit -m "fix(inventory): use_item writes canonical roster keys; add use_item_on_students batch"
```

---

## Task 3: `GameState` inventory persistence + `forget_session`

**Files:**
- Modify: `Scripts/GameState.gd` — add persistence block near the inventory helpers (`~:176-206`); call `load_inventory()` at the end of `_ready()` (`~:256-257`)
- Test: `tests/test_inventory_persistence.gd` (create)

**Interfaces:**
- Produces: `GameState.INVENTORY_SAVE_PATH: String`; `_write_inventory_to(cfg: ConfigFile)`, `_read_inventory_from(cfg: ConfigFile)` (pure), `save_inventory()`, `load_inventory()`, `clear_inventory_save()`, `forget_session()`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_inventory_persistence.gd`:

```gdscript
@tool
extends McpTestSuite

## Inventory persistence: the pure serialise/deserialise pair round-trips,
## the disk path is is_editor_hint-gated (no file appears in test context),
## and forget_session() clears in-memory run state.

func suite_name() -> String:
    return "inventory_persistence"

var _inv_backup: Dictionary
var _roster_backup: Array
var _money_backup: int

func setup() -> void:
    _inv_backup = GameState.inventory.duplicate(true)
    _roster_backup = GameState.approved_students.duplicate(true)
    _money_backup = GameState.player_money

func teardown() -> void:
    GameState.inventory = _inv_backup
    GameState.approved_students = _roster_backup
    GameState.player_money = _money_backup
    if FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH):
        DirAccess.remove_absolute(GameState.INVENTORY_SAVE_PATH)

func test_write_then_read_round_trips() -> void:
    GameState.inventory = {"Komik": 3, "Raket": 1}
    var cfg := ConfigFile.new()
    GameState._write_inventory_to(cfg)
    GameState.inventory = {}
    GameState._read_inventory_from(cfg)
    assert_equal(3, GameState.inventory.get("Komik"))
    assert_equal(1, GameState.inventory.get("Raket"))

func test_read_from_empty_config_leaves_inventory_empty() -> void:
    GameState.inventory = {"stale": 9}
    GameState._read_inventory_from(ConfigFile.new())
    assert_true(GameState.inventory.is_empty())

func test_read_coerces_types() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("inventory", "items", {"Komik": 2})
    GameState._read_inventory_from(cfg)
    for k in GameState.inventory:
        assert_true(k is String)
        assert_true(typeof(GameState.inventory[k]) == TYPE_INT)

func test_save_inventory_is_gated_in_editor_context() -> void:
    if FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH):
        DirAccess.remove_absolute(GameState.INVENTORY_SAVE_PATH)
    GameState.inventory = {"Komik": 1}
    GameState.save_inventory()
    assert_false(FileAccess.file_exists(GameState.INVENTORY_SAVE_PATH),
        "save_inventory must no-op under Engine.is_editor_hint()")

func test_forget_session_clears_run_state() -> void:
    GameState.inventory = {"Komik": 1}
    GameState.approved_students = [{"id": 1, "name": "A"}]
    GameState.player_money = 5000
    GameState.forget_session()
    assert_true(GameState.inventory.is_empty())
    assert_true(GameState.approved_students.is_empty())
    assert_equal(0, GameState.player_money)
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_persistence")`.
Expected: FAIL — `INVENTORY_SAVE_PATH` / `_write_inventory_to` / `forget_session` missing.

- [ ] **Step 3: Add the persistence block**

In `Scripts/GameState.gd`, after `seed_playtest_inventory()` (near line 206):

```gdscript
const INVENTORY_SAVE_PATH := "user://inventory.cfg"

## Serialize `inventory` into `cfg` (pure -- no disk, no editor gate). Split
## out so a headless test can round-trip it without the is_editor_hint guard.
func _write_inventory_to(cfg: ConfigFile) -> void:
    cfg.set_value("inventory", "items", inventory.duplicate())

## Inverse of _write_inventory_to. A missing section leaves `inventory` empty.
## Coerces keys to String and values to int.
func _read_inventory_from(cfg: ConfigFile) -> void:
    var raw: Dictionary = cfg.get_value("inventory", "items", {})
    inventory.clear()
    for k in raw:
        inventory[String(k)] = int(raw[k])

## Persist the current inventory. No-op in editor/test context: GameState is
## not @tool, so a placeholder instance must never touch user://.
func save_inventory() -> void:
    if Engine.is_editor_hint():
        return
    var cfg := ConfigFile.new()
    _write_inventory_to(cfg)
    cfg.save(INVENTORY_SAVE_PATH)

## Load the persisted inventory at boot. Emits inventory_changed so any
## already-built screen rebuilds.
func load_inventory() -> void:
    if Engine.is_editor_hint():
        return
    var cfg := ConfigFile.new()
    if cfg.load(INVENTORY_SAVE_PATH) == OK:
        _read_inventory_from(cfg)
        inventory_changed.emit()

## Delete the on-disk inventory save, if present.
func clear_inventory_save() -> void:
    if FileAccess.file_exists(INVENTORY_SAVE_PATH):
        DirAccess.remove_absolute(INVENTORY_SAVE_PATH)

## Debug: return the whole autoload to a fresh-boot state and drop the save.
## Lists every runtime field GameState initializes at declaration -- if a
## field is added to GameState later, add it here too.
func forget_session() -> void:
    inventory.clear()
    approved_students.clear()
    day_schedules.clear()
    pending_earnings.clear()
    player_money = 0
    current_week = 1
    current_grade = 7
    if run_stats and run_stats.has_method("reset"):
        run_stats.reset()
    clear_inventory_save()
    inventory_changed.emit()
```

Before writing `forget_session`, grep `Scripts/GameState.gd` for every `var`
declared with an initializer at file scope (`grep -nE '^var [a-z_]+' Scripts/GameState.gd`)
and reset each run-state field (skip constants, signals, and the `_player_money`
backing var — `player_money = 0` covers it via the setter). Names used above
(`day_schedules`, `current_week`, `current_grade`, `run_stats`) must be verified
against the actual file; adjust to the real identifiers.

- [ ] **Step 4: Call `load_inventory()` at boot**

In `_ready()`, after `print("GameState siap")`:

```gdscript
    load_inventory()
```

- [ ] **Step 5: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_persistence")` (expect 5 PASS). Then `test_run(suite="use_item_on_students")` and `test_run(suite="item_catalog")` to confirm no regression in the same file.

- [ ] **Step 6: Commit**

```bash
git add Scripts/GameState.gd tests/test_inventory_persistence.gd tests/test_inventory_persistence.gd.uid
git commit -m "feat(inventory): persist inventory to user://inventory.cfg; add forget_session"
```

---

## Task 4: `Transition` save hook

**Files:**
- Modify: `Scripts/Transition/transition.gd:49-55` (`change_scene`, right after `_busy = true`)
- Test: `tests/test_inventory_persistence.gd` (add a source-scan test)

**Interfaces:**
- Consumes: `GameState.save_inventory()` (Task 3).

- [ ] **Step 1: Add the failing test**

Append to `tests/test_inventory_persistence.gd`:

```gdscript
func test_transition_flushes_inventory_on_scene_change() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/Transition/transition.gd")
    assert_true(src.contains("GameState.save_inventory()"),
        "change_scene must flush the inventory save")
    assert_true(src.contains("is_editor_hint"),
        "the save call must be editor-gated")
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_persistence")`.
Expected: the new test FAILs.

- [ ] **Step 3: Add the hook**

In `Scripts/Transition/transition.gd`, in `change_scene`, immediately after `_busy = true`:

```gdscript
    if not Engine.is_editor_hint():
        GameState.save_inventory()
```

- [ ] **Step 4: Run test to verify it passes**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_persistence")` (expect 6 PASS). Also `test_run(suite="transition")` if such a suite exists — confirm still green.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Transition/transition.gd tests/test_inventory_persistence.gd
git commit -m "feat(inventory): flush inventory save on every scene transition"
```

---

## Task 5: `DebugManager` "Forget Session" button

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd:373-383` (`_build_general_panel`, after the seed button + its separator), add `_forget_session()` near `_seed_playtest_state` (`~:672`)
- Test: `tests/test_inventory_persistence.gd` (source scan)

**Interfaces:**
- Consumes: `GameState.forget_session()` (Task 3), `Transition.change_scene`.

- [ ] **Step 1: Add the failing test**

Append to `tests/test_inventory_persistence.gd`:

```gdscript
func test_debug_manager_has_forget_session() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
    assert_true(src.contains("_forget_session"), "debug button handler present")
    assert_true(src.contains("GameState.forget_session()"), "handler calls forget_session")
    assert_true(src.contains("main_menu.tscn"), "handler returns to MainMenu")
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_persistence")`. New test FAILs.

- [ ] **Step 3: Add the button + handler**

In `_build_general_panel()`, after `vbox.add_child(sep_seed)`:

```gdscript
    var btn_forget := Button.new()
    btn_forget.text = " 🧹 Forget Session (hapus save, ke MainMenu) "
    btn_forget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn_forget.custom_minimum_size = Vector2(0, 95)
    btn_forget.add_theme_font_size_override("font_size", 23)
    btn_forget.pressed.connect(_forget_session)
    vbox.add_child(btn_forget)
    vbox.add_child(HSeparator.new())
```

Add the handler next to `_seed_playtest_state()`:

```gdscript
## Debug: wipe in-memory GameState + the inventory save, then boot fresh.
func _forget_session() -> void:
    GameState.forget_session()
    _close_overlay()  # match the name the overlay actually uses to hide itself
    Transition.change_scene("res://Scenes/MainMenu/main_menu.tscn", Transition.Style.FADE)
```

Grep `DebugManager.gd` for how the overlay hides after `_seed_playtest_state`
(e.g. `_toggle_overlay`, `visible = false`, `_hide`) and use that exact call.

- [ ] **Step 4: Run test to verify it passes**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_persistence")` (expect 7 PASS). Then `test_run(suite="debug_manager")` if present.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/DebugManager.gd tests/test_inventory_persistence.gd
git commit -m "feat(debug): add Forget Session button to the General tab"
```

---

## Task 6: `FilterChipButton` theme variation + rebake

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add a `_build_filter_chip_button()` + register `&"FilterChipButton"`, following the nearest existing button variation, e.g. `WeekTabButton`)
- Modify (generated): `Assets/Theme/kejartes_theme.tres` (via rebake)
- Test: `tests/test_theme_factory.gd` if it exists, else `tests/test_inventory.gd` (Task 12) covers usage

**Interfaces:**
- Produces: theme type variation `&"FilterChipButton"` — a pill toggle `Button` styling: `surface_overlay` normal bg / `brand_primary.darkened(0.15)` + `text_on_brand` when `button_pressed`, full corner radius, `StyleBoxEmpty` focus. All values from `DesignTokens`.

- [ ] **Step 1: Write/extend the failing test**

If `tests/test_theme_factory.gd` exists, add:

```gdscript
func test_filter_chip_button_variation_is_baked() -> void:
    var theme: Theme = load("res://Assets/Theme/kejartes_theme.tres")
    assert_true(theme.has_stylebox("normal", &"FilterChipButton"),
        "FilterChipButton must be baked into the theme")
    assert_true(theme.has_stylebox("pressed", &"FilterChipButton"))
```

If no such suite exists, create `tests/test_theme_factory.gd` (`@tool`, `suite_name() -> "theme_factory"`) with that one test plus `test_scene_loads`-style guard.

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="theme_factory")`. FAIL — variation not baked.

- [ ] **Step 3: Add the variation to `ThemeFactory.gd`**

Find how `WeekTabButton` (or the closest toggle-ish button) is built and registered. Add a sibling:

```gdscript
## Pill toggle used for the inventory category filter row. Resting = sunken
## surface + secondary text; pressed/active = brand fill + on-brand text with
## a brand left border. Focus outline suppressed (touch UI).
static func _build_filter_chip_button(t: Theme, tok: DesignTokens) -> void:
    var radius := 24
    var normal := StyleBoxFlat.new()
    normal.bg_color = tok.surface_overlay
    normal.set_corner_radius_all(radius)
    normal.content_margin_left = 20
    normal.content_margin_right = 20
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10

    var pressed := normal.duplicate()
    pressed.bg_color = tok.brand_primary.darkened(0.15)
    pressed.border_width_left = 3
    pressed.border_color = tok.brand_primary

    var hover := normal.duplicate()
    hover.bg_color = tok.brand_primary.darkened(0.35)

    t.set_stylebox("normal", &"FilterChipButton", normal)
    t.set_stylebox("hover", &"FilterChipButton", hover)
    t.set_stylebox("pressed", &"FilterChipButton", pressed)
    t.set_stylebox("focus", &"FilterChipButton", StyleBoxEmpty.new())
    t.set_color("font_color", &"FilterChipButton", tok.text_secondary)
    t.set_color("font_pressed_color", &"FilterChipButton", tok.text_on_brand)
    t.set_color("font_hover_color", &"FilterChipButton", tok.text_on_brand)
    t.set_type_variation(&"FilterChipButton", &"Button")
```

Call `_build_filter_chip_button(theme, tokens)` from the same place the other
button variations are invoked in `build()`. Match the real `ThemeFactory` API —
the method names/param shapes above are indicative; conform to the file.

- [ ] **Step 4: Rebake the theme (headless)**

The rebake has no MCP entry point. Controller writes a transient `@tool`
`McpTestSuite` to `res://tests/test__rebake_tmp.gd` whose single test does:

```gdscript
@tool
extends McpTestSuite
func suite_name() -> String: return "rebake_tmp"
func test_rebake() -> void:
    var theme := ThemeFactory.build()  # match the real entry point
    var err := ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
    assert_equal(OK, err, "theme rebake saved")
```

`filesystem_manage(op="scan")` → `test_run(suite="rebake_tmp")` → confirm PASS →
delete `res://tests/test__rebake_tmp.gd` and its `.uid` → `filesystem_manage(op="scan")`.
(This mirrors the CLAUDE.md "transient test suite" rebake path.)

- [ ] **Step 5: Run test to verify it passes**

Controller: `test_run(suite="theme_factory")` → PASS. Then `test_run()` (full)
and confirm the suite count/greens are unchanged except the new suite.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd tests/test_theme_factory.gd.uid
git commit -m "feat(theme): add FilterChipButton variation for the inventory filter row"
```

---

## Task 7: `EfekRow` and `StatBarRow` template scenes

**Files:**
- Create: `Scenes/Inventory/EfekRow.tscn`
- Create: `Scenes/Inventory/StatBarRow.tscn`
- Test: `tests/test_item_detail_sheet.gd` (create now, one instantiation test; grows in Task 8)

**Interfaces:**
- Produces:
  - `EfekRow.tscn` — root `HBoxContainer` named `EfekRow`; children `NeedIcon: TextureRect` (64×64), `ValueLabel: Label` (`theme_type_variation = &"ResultDeltaLabel"`), `ExplainLabel: Label` (`&"MicroLabel"`, `autowrap_mode = 3`, `size_flags_horizontal = 3`).
  - `StatBarRow.tscn` — root `HBoxContainer` named `StatBarRow`; children `NameLabel: Label` (`&"TitleLabel"`, min width 220), `Bar: StatBar` (`size_flags_horizontal = 3`, min height 48), `ValueLabel: Label` (`&"TitleLabel"`, min width 150, right align), `DeltaLabel: Label` (`&"ResultDeltaLabel"`, min width 110, right align, text `"--"`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_item_detail_sheet.gd`:

```gdscript
@tool
extends McpTestSuite

## ItemDetailSheet + its EfekRow template.

func suite_name() -> String:
    return "item_detail_sheet"

func test_efek_row_template_instantiates_with_expected_nodes() -> void:
    var path := "res://Scenes/Inventory/EfekRow.tscn"
    assert_true(ResourceLoader.exists(path), "EfekRow.tscn must exist")
    var row := (load(path) as PackedScene).instantiate()
    assert_true(row.get_node_or_null("NeedIcon") != null)
    assert_true(row.get_node_or_null("ValueLabel") != null)
    assert_true(row.get_node_or_null("ExplainLabel") != null)
    row.free()

func test_stat_bar_row_template_instantiates_with_expected_nodes() -> void:
    var path := "res://Scenes/Inventory/StatBarRow.tscn"
    assert_true(ResourceLoader.exists(path), "StatBarRow.tscn must exist")
    var row := (load(path) as PackedScene).instantiate()
    for n in ["NameLabel", "Bar", "ValueLabel", "DeltaLabel"]:
        assert_true(row.get_node_or_null(n) != null, "missing " + n)
    row.free()
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="item_detail_sheet")`. FAIL — scenes absent.

- [ ] **Step 3: Build `EfekRow.tscn`**

Controller, through the editor: `scene_manage(op="new")` or `scene_open` a blank,
create root `HBoxContainer` "EfekRow" carrying `theme = kejartes_theme.tres`,
`separation` constant override ~16; add `NeedIcon` (`TextureRect`,
`custom_minimum_size = (64, 64)`, `expand_mode = 1`, `stretch_mode = 6`),
`ValueLabel` (`Label`, `theme_type_variation = &"ResultDeltaLabel"`, text `"+0"`),
`ExplainLabel` (`Label`, `theme_type_variation = &"MicroLabel"`,
`autowrap_mode = 3`, `size_flags_horizontal = 3`). `scene_save` to
`res://Scenes/Inventory/EfekRow.tscn`.

- [ ] **Step 4: Build `StatBarRow.tscn`**

Same flow: root `HBoxContainer` "StatBarRow" (theme attached, `separation` ~12);
`NameLabel` (`&"TitleLabel"`, `custom_minimum_size = (220, 0)`); `Bar`
(type `StatBar` — `node_create` with `type: "StatBar"`; if the custom type is
unavailable via MCP, create a `ProgressBar` then change type by
delete-and-recreate once `StatBar` resolves; `size_flags_horizontal = 3`,
`custom_minimum_size = (0, 48)`); `ValueLabel` (`&"TitleLabel"`,
`custom_minimum_size = (150, 0)`, `horizontal_alignment = 2`); `DeltaLabel`
(`&"ResultDeltaLabel"`, `custom_minimum_size = (110, 0)`,
`horizontal_alignment = 2`, text `"--"`). `scene_save` to
`res://Scenes/Inventory/StatBarRow.tscn`.

- [ ] **Step 5: Run tests to verify they pass**

Controller: `test_run(suite="item_detail_sheet")` — 2 PASS.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Inventory/EfekRow.tscn Scenes/Inventory/StatBarRow.tscn tests/test_item_detail_sheet.gd tests/test_item_detail_sheet.gd.uid
git commit -m "feat(inventory): add EfekRow and StatBarRow template scenes"
```

---

## Task 8: `ItemDetailSheet` — scene + script

**Files:**
- Create: `Scripts/Inventory/ItemDetailSheet.gd`
- Create: `Scenes/Inventory/ItemDetailSheet.tscn`
- Test: `tests/test_item_detail_sheet.gd` (extend)

**Interfaces:**
- Consumes: `EfekRow.tscn` (Task 7), `ItemData` skill fields (Task 1), `DaySummaryBadge.tscn`, `DesignTokens`, `AudioDirector`, `Juice`/`AnimUtils`.
- Produces: `class_name ItemDetailSheet`; `signal apply_requested(item: ItemData)`, `signal dismissed`; `func setup(item: ItemData, owned_qty: int) -> void`. Scene root `Control` named `ItemDetailSheet` with `Scrim`, `Sheet`, `EfekList` (5 named `EfekRow` instances `RowAkademis/RowSeni/RowOlahraga/RowMood/RowEnergy`), `ApplyButton`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_item_detail_sheet.gd`:

```gdscript
const _SHEET := "res://Scenes/Inventory/ItemDetailSheet.tscn"
const _SHEET_SRC := "res://Scripts/Inventory/ItemDetailSheet.gd"

func _src() -> String:
    return FileAccess.get_file_as_string(_SHEET_SRC)

func test_sheet_instantiates_with_structure() -> void:
    var s := (load(_SHEET) as PackedScene).instantiate()
    for n in ["Scrim", "Sheet", "EfekList", "Sheet/Margin/VBox/ApplyButton"]:
        assert_true(s.find_child(n.get_file(), true, false) != null or s.get_node_or_null(n) != null,
            "missing " + n)
    s.free()

func test_sheet_has_five_named_efek_rows() -> void:
    var s := (load(_SHEET) as PackedScene).instantiate()
    for n in ["RowAkademis", "RowSeni", "RowOlahraga", "RowMood", "RowEnergy"]:
        assert_true(s.find_child(n, true, false) != null, "missing " + n)
    s.free()

func test_sheet_script_is_clean() -> void:
    var src := _src()
    assert_false(src.contains("theme_override"), "no theme_override in script")
    assert_false(src.contains("Color(0."), "no raw Color literals")
    assert_true(src.contains("DesignTokens.load_default()"), "scrim colour from tokens")
    for k in ["akademis", "seni_budaya", "olahraga", "mood", "energy"]:
        assert_true(src.contains('"%s"' % k), "EXPLAIN missing key " + k)

func test_setup_hides_rows_with_no_boost() -> void:
    var s := (load(_SHEET) as PackedScene).instantiate()
    add_child_autofree(s) if has_method("add_child_autofree") else s._set(&"_x", 0)
    var item := ItemData.new()
    item.item_name = "X"
    item.mood_boost = 10   # only mood
    s.setup(item, 2)
    assert_false(s.find_child("RowAkademis", true, false).visible)
    assert_true(s.find_child("RowMood", true, false).visible)
    s.free()
```

(If `add_child_autofree` is not in `McpTestSuite`, add the sheet under the scene
tree via `get_tree().root.add_child(s)` then `s.queue_free()` at the end — match
the pattern other suites here use for live instances.)

- [ ] **Step 2: Run tests to verify they fail**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="item_detail_sheet")`. New tests FAIL.

- [ ] **Step 3: Write `ItemDetailSheet.gd`**

```gdscript
@tool
class_name ItemDetailSheet
extends Control
## Bottom sheet: one owned item's icon, name, category chip, description and a
## plain-language breakdown of every stat bar it moves. Emits apply_requested
## when the player commits to the apply flow, dismissed when they back out.
## Builds nothing at runtime -- the five EfekRow instances are authored in the
## scene; setup() only fills and shows/hides them.

signal apply_requested(item: ItemData)
signal dismissed

## Fixed on-screen size for the item icon in the sheet's top row.
@export var icon_size: Vector2 = Vector2(140, 140)

## Plain-Indonesian, one line per bar, shown after the "+N". Fixed game copy,
## not a tuning knob -- hence a const, not an @export.
const EXPLAIN := {
    "akademis":    "Nilai akademik. Salah satu dari tiga target kelulusan kelas.",
    "seni_budaya": "Nilai seni & budaya. Salah satu target kelulusan kelas.",
    "olahraga":    "Nilai olahraga. Salah satu target kelulusan kelas.",
    "mood":        "Semangat siswa. Mood rendah menurunkan hasil belajar mingguan.",
    "energy":      "Tenaga harian. Energi 5 ke bawah memaksa siswa Izin -- istirahat paksa, tanpa belajar.",
}

const _NEED_ICONS := {
    "akademis":    "res://Assets/Images/UI/Placeholders/icon_akademis.svg",
    "seni_budaya": "res://Assets/Images/UI/Placeholders/icon_seni.svg",
    "olahraga":    "res://Assets/Images/UI/Placeholders/icon_olahraga.svg",
    "mood":        "res://Assets/Images/UI/Placeholders/icon_mood.svg",
    "energy":      "res://Assets/Images/UI/Placeholders/icon_energy.svg",
}

@onready var _scrim: ColorRect = $Scrim
@onready var _sheet: PanelContainer = $Sheet
@onready var _icon: TextureRect = $Sheet/Margin/VBox/TopRow/Icon
@onready var _name_label: Label = $Sheet/Margin/VBox/TopRow/TitleCol/NameLabel
@onready var _category_chip: Control = $Sheet/Margin/VBox/TopRow/TitleCol/CategoryChip
@onready var _desc_label: Label = $Sheet/Margin/VBox/DescLabel
@onready var _apply_button: Button = $Sheet/Margin/VBox/ApplyButton
@onready var _rows := {
    "akademis":    $Sheet/Margin/VBox/EfekList/RowAkademis,
    "seni_budaya": $Sheet/Margin/VBox/EfekList/RowSeni,
    "olahraga":    $Sheet/Margin/VBox/EfekList/RowOlahraga,
    "mood":        $Sheet/Margin/VBox/EfekList/RowMood,
    "energy":      $Sheet/Margin/VBox/EfekList/RowEnergy,
}

var _item: ItemData = null

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    _scrim.color = DesignTokens.load_default().scrim_color()
    _scrim.gui_input.connect(_on_scrim_input)
    _apply_button.pressed.connect(_on_apply)
    _icon.custom_minimum_size = icon_size
    # start off-screen, spring up in setup()
    _sheet.position.y = _sheet.size.y

func setup(item: ItemData, owned_qty: int) -> void:
    _item = item
    _icon.texture = item.icon
    _name_label.text = item.item_name
    var chip_lbl := _category_chip.get_node_or_null("Text") as Label
    if chip_lbl:
        chip_lbl.text = " %s " % item.category
    _desc_label.text = item.description if item.description.strip_edges() != "" \
        else "Tidak ada deskripsi."

    var boosts := {
        "akademis": item.akademis_boost, "seni_budaya": item.seni_budaya_boost,
        "olahraga": item.olahraga_boost, "mood": item.mood_boost,
        "energy": item.energy_boost,
    }
    for key in _rows:
        var row: Control = _rows[key]
        var amount: int = boosts[key]
        row.visible = amount != 0
        if not row.visible:
            continue
        (row.get_node("NeedIcon") as TextureRect).texture = load(_NEED_ICONS[key])
        (row.get_node("ValueLabel") as Label).text = "+%d" % amount
        (row.get_node("ExplainLabel") as Label).text = EXPLAIN[key]

    if not Engine.is_editor_hint():
        AudioDirector.play_sfx(&"popup_open")
        AnimUtils.popup_spring_in(_sheet)
        AnimUtils.wobble(_icon)
        for key in _rows:
            if _rows[key].visible:
                Juice.count_up(_rows[key].get_node("ValueLabel"), boosts[key])

func _on_apply() -> void:
    if _item == null:
        return
    AudioDirector.play_sfx(&"confirm")
    apply_requested.emit(_item)

func _on_scrim_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if not _sheet.get_global_rect().has_point(event.global_position):
            _dismiss()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _dismiss()

func _dismiss() -> void:
    AudioDirector.play_sfx(&"popup_close")
    if not Engine.is_editor_hint():
        AnimUtils.popup_spring_out(_sheet)
        await get_tree().create_timer(0.2).timeout
    dismissed.emit()
    queue_free()
```

Confirm the real names: `AnimUtils.popup_spring_in` / `popup_spring_out` /
`wobble`, `Juice.count_up`, `DesignTokens.scrim_color()`, and the
`DaySummaryBadge` inner label node name (`Text`). Adjust to the actual API;
`_dismiss()` uses one `await` but this is production code, not a test, so that
is fine.

Confirm the five `icon_*.svg` placeholder paths exist under
`Assets/Images/UI/Placeholders/` (the end-of-grade pass added `icon_*.svg`
there). If a specific name is missing, reuse the closest existing one and note
it as a placeholder in the `const` comment.

- [ ] **Step 4: Build `ItemDetailSheet.tscn`**

Through the editor. Root `Control` "ItemDetailSheet", full-rect anchors, `theme = kejartes_theme.tres`, `script = ItemDetailSheet.gd`.
- `Scrim`: `ColorRect`, full-rect, `color = (0,0,0,0.6)` placeholder (script overwrites from tokens), `mouse_filter = 0`.
- `Sheet`: `PanelContainer`, `theme_type_variation = &"Card"`, anchors bottom (`anchor_top = 1.0, anchor_bottom = 1.0, anchor_left = 0, anchor_right = 1.0`), `grow_vertical = 0` (grows up), `offset_top = -900` (tune later).
  - `Margin`: `MarginContainer`, margins 32.
    - `VBox`: `VBoxContainer`, `separation` ~20.
      - `Grabber`: `ColorRect`, `custom_minimum_size = (48, 5)`, `size_flags_horizontal = 4` (centre).
      - `TopRow`: `HBoxContainer`, `separation` 20.
        - `Icon`: `TextureRect`, `custom_minimum_size = (140,140)`, `expand_mode = 1`, `stretch_mode = 6`.
        - `TitleCol`: `VBoxContainer`, `size_flags_horizontal = 3`.
          - `NameLabel`: `Label`, `&"TitleLabel"`.
          - `CategoryChip`: instance `res://Scenes/SchoolSimulation/DaySummaryBadge.tscn`.
      - `DescLabel`: `Label`, `&"CaptionLabel"`, `autowrap_mode = 3`.
      - `EfekHeader`: `Label`, `&"CardSectionLabel"`, text `"Efek"`.
      - `EfekList`: `VBoxContainer`, `separation` ~12. Instance `EfekRow.tscn` five times, rename to `RowAkademis`, `RowSeni`, `RowOlahraga`, `RowMood`, `RowEnergy`.
      - `ApplyButton`: `Button`, `theme_type_variation = &"PrimaryButton"`, text `"Pakai ke Siswa"`, `custom_minimum_size = (0, 90)`.
`scene_save` to `res://Scenes/Inventory/ItemDetailSheet.tscn`.

- [ ] **Step 5: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="item_detail_sheet")` (expect 6 PASS). If `setup()`'s new `@export`/nodes read stale, no-op `script_patch` on `ItemDetailSheet.gd` and re-run.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Inventory/ItemDetailSheet.gd Scripts/Inventory/ItemDetailSheet.gd.uid Scenes/Inventory/ItemDetailSheet.tscn tests/test_item_detail_sheet.gd
git commit -m "feat(inventory): add ItemDetailSheet bottom sheet with per-bar Efek breakdown"
```

---

## Task 9: `ApplyStudentRow` — template scene + script

**Files:**
- Create: `Scripts/Inventory/ApplyStudentRow.gd`
- Create: `Scenes/Inventory/ApplyStudentRow.tscn`
- Test: `tests/test_apply_student_row.gd` (create)

**Interfaces:**
- Consumes: `StatBarRow.tscn` (Task 7), `DaySummaryBadge.tscn`, `Juice`, `DesignTokens`.
- Produces: `class_name ApplyStudentRow`; `signal selection_changed`; `const KEY := {"akademis":"akademis1","seni_budaya":"akademis2","olahraga":"akademis3","mood":"kepribadian1","energy":"kepribadian2"}`; `func setup(p_student: Dictionary, boosts: Dictionary) -> void`; `func set_preview(active: bool) -> void`; `func is_selected() -> bool`; `func selected_student_id() -> int`. Scene root `PanelContainer` "ApplyStudentRow" with `Check: CheckBox`, `Portrait: TextureRect`, `NameLabel`, `BadgeSlot`, and five named `StatBarRow` instances `BarRowAkademis/BarRowSeni/BarRowOlahraga/BarRowMood/BarRowEnergy`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_apply_student_row.gd`:

```gdscript
@tool
extends McpTestSuite

## ApplyStudentRow: logical-name -> roster-key mapping, bar show/hide by boost,
## preview raises then restores a bar, tired student can't be selected.

func suite_name() -> String:
    return "apply_student_row"

const _ROW := "res://Scenes/Inventory/ApplyStudentRow.tscn"

func _make() -> ApplyStudentRow:
    return (load(_ROW) as PackedScene).instantiate()

func test_key_map_targets_canonical_roster_keys() -> void:
    assert_equal("akademis1", ApplyStudentRow.KEY["akademis"])
    assert_equal("akademis2", ApplyStudentRow.KEY["seni_budaya"])
    assert_equal("akademis3", ApplyStudentRow.KEY["olahraga"])
    assert_equal("kepribadian1", ApplyStudentRow.KEY["mood"])
    assert_equal("kepribadian2", ApplyStudentRow.KEY["energy"])

func test_setup_shows_only_boosted_bars() -> void:
    var row := _make()
    get_tree().root.add_child(row)
    row.setup({"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": 50.0,
        "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0}, {"mood": 10})
    assert_true(row.find_child("BarRowMood", true, false).visible)
    assert_false(row.find_child("BarRowAkademis", true, false).visible)
    row.queue_free()

func test_preview_raises_and_restores_bar() -> void:
    var row := _make()
    get_tree().root.add_child(row)
    row.setup({"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": 50.0,
        "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0}, {"mood": 20})
    var bar := row.find_child("BarRowMood", true, false).get_node("Bar")
    var base_val: float = bar.value
    row.set_preview(true)
    assert_true(bar.value > base_val or bar.get(&"_target") == 70.0)
    row.set_preview(false)
    row.queue_free()

func test_tired_student_cannot_be_selected() -> void:
    var row := _make()
    get_tree().root.add_child(row)
    row.setup({"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": 4.0,
        "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0}, {"mood": 10})
    assert_true(row.find_child("Check", true, false).disabled)
    assert_false(row.is_selected())
    row.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="apply_student_row")`. FAIL — scene/script absent.

- [ ] **Step 3: Write `ApplyStudentRow.gd`**

```gdscript
@tool
class_name ApplyStudentRow
extends PanelContainer
## One selectable student in ApplyItemScreen: portrait, name, a LELAH badge
## when too tired to benefit, and up to five authored StatBarRow instances --
## only the bars the item moves are shown. Selecting the row previews the
## post-apply values on those bars. Nothing is built here; setup() fills the
## authored template instances.

signal selection_changed

## Logical boost name -> the roster Dictionary key it writes. Fixed mapping:
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy.
const KEY := {
    "akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
    "mood": "kepribadian1", "energy": "kepribadian2",
}

## kepribadian2 (energy) at or below this forces "Izin" -- such a student
## can't take the item.
@export var tired_energy_threshold: float = 5.0

@onready var _check: CheckBox = $Margin/HBox/Check
@onready var _portrait: TextureRect = $Margin/HBox/Portrait
@onready var _name_label: Label = $Margin/HBox/Col/HeaderRow/NameLabel
@onready var _badge_slot: HBoxContainer = $Margin/HBox/Col/HeaderRow/BadgeSlot
@onready var _bar_rows := {
    "akademis":    $Margin/HBox/Col/BarRowAkademis,
    "seni_budaya": $Margin/HBox/Col/BarRowSeni,
    "olahraga":    $Margin/HBox/Col/BarRowOlahraga,
    "mood":        $Margin/HBox/Col/BarRowMood,
    "energy":      $Margin/HBox/Col/BarRowEnergy,
}

const _BADGE := "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn"
const _BAR_TITLE := {
    "akademis": "Akademis", "seni_budaya": "Seni Budaya", "olahraga": "Olahraga",
    "mood": "Mood", "energy": "Energi",
}
const _BAR_CATEGORY := {
    "akademis": "Akademis", "seni_budaya": "SeniBudaya", "olahraga": "Olahraga",
    "mood": "Istirahat", "energy": "Libur",
}

var student: Dictionary = {}
var _boosts: Dictionary = {}

func _ready() -> void:
    if not _check.toggled.is_connected(_on_toggled):
        _check.toggled.connect(_on_toggled)

func setup(p_student: Dictionary, boosts: Dictionary) -> void:
    student = p_student
    _boosts = {}
    for k in boosts:
        if int(boosts[k]) != 0:
            _boosts[k] = int(boosts[k])

    _name_label.text = str(student.get("name", "?"))
    var port_path := str(student.get("portrait", ""))
    if port_path != "" and ResourceLoader.exists(port_path):
        _portrait.texture = load(port_path)

    var is_tired := float(student.get("kepribadian2", 100.0)) <= tired_energy_threshold
    _check.disabled = is_tired
    for c in _badge_slot.get_children():
        c.queue_free()
    if is_tired:
        _add_badge("LELAH", DesignTokens.load_default().state_danger)

    for key in _bar_rows:
        var row: Control = _bar_rows[key]
        row.visible = _boosts.has(key)
        if not row.visible:
            continue
        var cur := float(student.get(KEY[key], 0.0))
        (row.get_node("NameLabel") as Label).text = _BAR_TITLE[key]
        var bar := row.get_node("Bar")
        bar.set(&"category", _BAR_CATEGORY[key])
        bar.value = cur
        (row.get_node("ValueLabel") as Label).text = "%d/100" % int(cur)
        (row.get_node("DeltaLabel") as Label).text = "--"

func set_preview(active: bool) -> void:
    var tok := DesignTokens.load_default()
    for key in _bar_rows:
        var row: Control = _bar_rows[key]
        if not row.visible:
            continue
        var cur := float(student.get(KEY[key], 0.0))
        var bar := row.get_node("Bar")
        var val_lbl := row.get_node("ValueLabel") as Label
        var delta_lbl := row.get_node("DeltaLabel") as Label
        if active:
            var target: float = clampf(cur + _boosts[key], 0.0, 100.0)
            if not Engine.is_editor_hint():
                Juice.fill_bar(bar, target)
            else:
                bar.value = target
            val_lbl.text = "%d ➔ %d" % [int(cur), int(target)]
            if target >= 100.0 and cur >= 100.0:
                delta_lbl.text = "MAKS"
                delta_lbl.self_modulate = tok.text_secondary
            else:
                delta_lbl.text = "(+%d)" % int(target - cur)
                delta_lbl.self_modulate = tok.state_success
            if not Engine.is_editor_hint():
                Juice.pop(delta_lbl)
        else:
            if not Engine.is_editor_hint():
                Juice.fill_bar(bar, cur)
            else:
                bar.value = cur
            val_lbl.text = "%d/100" % int(cur)
            delta_lbl.text = "--"
            delta_lbl.self_modulate = tok.text_secondary
    scale = Vector2(1.02, 1.02) if active else Vector2.ONE

func is_selected() -> bool:
    return _check.button_pressed and not _check.disabled

func selected_student_id() -> int:
    return int(student.get("id", -1))

func _on_toggled(pressed: bool) -> void:
    set_preview(pressed)
    selection_changed.emit()

func _add_badge(text: String, tint: Color) -> void:
    var chip := (load(_BADGE) as PackedScene).instantiate()
    chip.self_modulate = tint
    var lbl := chip.get_node_or_null("Text") as Label
    if lbl:
        lbl.text = " %s " % text
    _badge_slot.add_child(chip)
```

Verify `Juice.fill_bar` / `Juice.pop` names against the real `Juice.gd`
(alternatives: `Juice.count_up`, `AnimUtils.squash_bounce`). Verify `StatBar`
exposes a settable `category` and `value`. Verify the `DaySummaryBadge` inner
label is `Text`.

`_add_badge` instances a `PackedScene` (allowed) and sets two properties — it
does not build the badge's visuals. Keep it.

- [ ] **Step 4: Build `ApplyStudentRow.tscn`**

Through the editor. Root `PanelContainer` "ApplyStudentRow", `theme` attached,
`theme_type_variation = &"Card"`, `script = ApplyStudentRow.gd`,
`size_flags_horizontal = 3`.
- `Margin`: `MarginContainer`, margins ~20/16/20/16.
  - `HBox`: `HBoxContainer`, `separation` ~20.
    - `Check`: `CheckBox`, `focus_mode = 0`, `custom_minimum_size = (110,110)`, `scale = (2, 2)`, `pivot_offset = (55, 55)`.
    - `Portrait`: `TextureRect`, `custom_minimum_size = (120,120)`, `expand_mode = 1`, `stretch_mode = 6`.
    - `Col`: `VBoxContainer`, `size_flags_horizontal = 3`, `separation` ~8.
      - `HeaderRow`: `HBoxContainer`, `separation` ~12.
        - `NameLabel`: `Label`, `&"H2Label"`.
        - `BadgeSlot`: `HBoxContainer`, `separation` ~8.
      - Instance `StatBarRow.tscn` five times → `BarRowAkademis`, `BarRowSeni`, `BarRowOlahraga`, `BarRowMood`, `BarRowEnergy`.
`scene_save` to `res://Scenes/Inventory/ApplyStudentRow.tscn`.

- [ ] **Step 5: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="apply_student_row")` (expect 4 PASS). No-op `script_patch` + rescan if `KEY`/methods read stale.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Inventory/ApplyStudentRow.gd Scripts/Inventory/ApplyStudentRow.gd.uid Scenes/Inventory/ApplyStudentRow.tscn tests/test_apply_student_row.gd tests/test_apply_student_row.gd.uid
git commit -m "feat(inventory): add ApplyStudentRow card with live per-bar preview"
```

---

## Task 10: `ApplyItemScreen` — scene + script + payoff

**Files:**
- Create: `Scripts/Inventory/ApplyItemScreen.gd`
- Create: `Scenes/Inventory/ApplyItemScreen.tscn`
- Test: `tests/test_apply_item_screen.gd` (create)

**Interfaces:**
- Consumes: `ApplyStudentRow.tscn` (Task 9), `GameState.use_item_on_students` (Task 2), `RewardBurst.tscn`, `CelebrationConfetti.tscn`, `AnimUtils.create_floating_text`, `Juice.stagger_in`, `AudioDirector`.
- Produces: `class_name ApplyItemScreen`; `signal applied(results: Array)`, `signal cancelled`; `func setup(p_item: ItemData) -> void`. Scene root `Control` "ApplyItemScreen" with `Background`, `Rows: VBoxContainer`, `RecapIcon/RecapName/RecapCount`, `EffectSummary`, `SelectAllButton/CancelButton/ConfirmButton`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_apply_item_screen.gd`:

```gdscript
@tool
extends McpTestSuite

## ApplyItemScreen: structure, routing through GameState.use_item_on_students,
## particle scene references, confirm-label format, no runtime chrome.

func suite_name() -> String:
    return "apply_item_screen"

const _SCENE := "res://Scenes/Inventory/ApplyItemScreen.tscn"
const _SRC := "res://Scripts/Inventory/ApplyItemScreen.gd"

func _src() -> String:
    return FileAccess.get_file_as_string(_SRC)

func test_scene_instantiates_with_structure() -> void:
    var s := (load(_SCENE) as PackedScene).instantiate()
    for n in ["Rows", "ConfirmButton", "SelectAllButton", "CancelButton",
              "RecapIcon", "RecapName", "EffectSummary"]:
        assert_true(s.find_child(n, true, false) != null, "missing " + n)
    s.free()

func test_routes_through_batch_api() -> void:
    assert_true(_src().contains("GameState.use_item_on_students("),
        "confirm must route through the batch API")

func test_references_payoff_particles() -> void:
    var src := _src()
    assert_true(src.contains("RewardBurst.tscn"))
    assert_true(src.contains("CelebrationConfetti.tscn"))

func test_confirm_label_is_formatted() -> void:
    assert_true(_src().contains("Pakai (%d Siswa)"),
        "confirm label shows the selected count")

func test_script_is_clean() -> void:
    var src := _src()
    assert_false(src.contains("theme_override"), "no theme_override in script")
    assert_false(src.contains("Color(0."), "no raw Color literals")
    assert_true(src.contains("student_row_scene"), "rows come from a PackedScene")

func test_emits_applied_and_cancelled() -> void:
    var s := (load(_SCENE) as PackedScene).instantiate()
    assert_true(s.has_signal("applied") and s.has_signal("cancelled"))
    s.free()
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="apply_item_screen")`. FAIL.

- [ ] **Step 3: Write `ApplyItemScreen.gd`**

```gdscript
@tool
class_name ApplyItemScreen
extends Control
## Full-screen "apply this item to which students" step. Multi-select with a
## live per-student StatBar preview, then a staged payoff: a RewardBurst and
## floating gained-stat text per student with a rising cue, then one
## screen-wide CelebrationConfetti if every pick gained. Emits applied(results)
## (the Array from GameState.use_item_on_students) or cancelled. Student rows
## are ApplyStudentRow PackedScene instances -- no runtime chrome here.

signal applied(results: Array)
signal cancelled

## One selectable student card.
@export var student_row_scene: PackedScene = preload("res://Scenes/Inventory/ApplyStudentRow.tscn")
## Per-student star burst fired on confirm.
@export var reward_burst_scene: PackedScene = preload("res://Scenes/SchoolSimulation/RewardBurst.tscn")
## Screen-wide fall, only when every pick gained.
@export var confetti_scene: PackedScene = preload("res://Scenes/SchoolSimulation/CelebrationConfetti.tscn")
## Seconds between one student's payoff and the next.
@export var payoff_stagger: float = 0.18

@onready var _rows_box: VBoxContainer = $Margin/Card/Margin/VBox/Scroll/Rows
@onready var _scroll: ScrollContainer = $Margin/Card/Margin/VBox/Scroll
@onready var _recap_icon: TextureRect = $Margin/Card/Margin/VBox/RecapStrip/RecapIcon
@onready var _recap_name: Label = $Margin/Card/Margin/VBox/RecapStrip/RecapName
@onready var _recap_count: Label = $Margin/Card/Margin/VBox/RecapStrip/RecapCount
@onready var _effect_summary: Label = $Margin/Card/Margin/VBox/EffectSummary
@onready var _select_all_button: Button = $Margin/Card/Margin/VBox/Actions/SecondaryRow/SelectAllButton
@onready var _cancel_button: Button = $Margin/Card/Margin/VBox/Actions/SecondaryRow/CancelButton
@onready var _confirm_button: Button = $Margin/Card/Margin/VBox/Actions/ConfirmButton

const _CONFIRM_FMT := "Pakai (%d Siswa)"
const _LABELS := {"akademis": "Akademis", "seni_budaya": "Seni", "olahraga": "Olahraga",
    "mood": "Mood", "energy": "Energi"}

var _item: ItemData = null
var _rows: Array = []

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    AudioDirector.play_sfx(&"popup_open")
    modulate.a = 0.0
    create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
    _select_all_button.pressed.connect(_on_select_all)
    _cancel_button.pressed.connect(_on_cancel)
    _confirm_button.pressed.connect(_on_confirm)
    _scroll.gui_input.connect(_on_scroll_input)

func setup(p_item: ItemData) -> void:
    _item = p_item
    _recap_icon.texture = p_item.icon
    _recap_name.text = p_item.item_name
    _recap_count.text = "Sisa ×%d" % GameState.get_inventory_quantity(p_item.item_name)
    _effect_summary.text = _summary_text(p_item)

    for c in _rows_box.get_children():
        c.queue_free()
    _rows.clear()
    var boosts := _boosts_of(p_item)
    for student in GameState.approved_students:
        var row: ApplyStudentRow = student_row_scene.instantiate()
        _rows_box.add_child(row)
        row.setup(student, boosts)
        row.selection_changed.connect(_refresh_confirm)
        _rows.append(row)
    if not Engine.is_editor_hint():
        Juice.stagger_in(_rows)
    _refresh_confirm()

func _boosts_of(it: ItemData) -> Dictionary:
    var raw := {"akademis": it.akademis_boost, "seni_budaya": it.seni_budaya_boost,
        "olahraga": it.olahraga_boost, "mood": it.mood_boost, "energy": it.energy_boost}
    var out := {}
    for k in raw:
        if int(raw[k]) != 0:
            out[k] = int(raw[k])
    return out

func _summary_text(it: ItemData) -> String:
    var parts: Array[String] = []
    for k in _boosts_of(it):
        parts.append("%s +%d" % [_LABELS[k], _boosts_of(it)[k]])
    return "Menambah: %s per siswa." % ", ".join(parts)

func _selected_ids() -> Array:
    var ids: Array = []
    for row in _rows:
        if row.is_selected():
            ids.append(row.selected_student_id())
    return ids

func _refresh_confirm() -> void:
    var n := _selected_ids().size()
    var owned := GameState.get_inventory_quantity(_item.item_name) if _item else 0
    _confirm_button.text = _CONFIRM_FMT % n
    _confirm_button.disabled = n == 0 or n > owned

func _on_select_all() -> void:
    AudioDirector.play_sfx(&"select")
    var any_off := false
    for row in _rows:
        if not row._check.disabled and not row._check.button_pressed:
            any_off = true
            break
    for row in _rows:
        if not row._check.disabled:
            row._check.button_pressed = any_off
    _refresh_confirm()

func _on_cancel() -> void:
    AudioDirector.play_sfx(&"cancel")
    cancelled.emit()
    queue_free()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _on_cancel()

func _on_confirm() -> void:
    var ids := _selected_ids()
    var res: Dictionary = GameState.use_item_on_students(_item, ids)
    if not res["applied"]:
        AudioDirector.play_sfx(&"error")
        return
    _confirm_button.disabled = true
    _select_all_button.disabled = true
    await _play_payoff(res["results"])
    applied.emit(res["results"])
    queue_free()

func _play_payoff(results: Array) -> void:
    var all_gained := true
    var tier := 0
    for r in results:
        var row := _row_for(r["student_id"])
        if row:
            var burst := reward_burst_scene.instantiate()
            row.add_child(burst)
            var lines := _gain_lines(r)
            if lines != "":
                AnimUtils.create_floating_text(self, lines,
                    row.global_position + row.size * 0.5,
                    DesignTokens.load_default().state_success)
            else:
                all_gained = false
        var cue := [&"star_earn_1", &"star_earn_2", &"star_earn_3"][mini(tier, 2)]
        AudioDirector.play_sfx(cue)
        tier += 1
        await get_tree().create_timer(payoff_stagger).timeout
    if all_gained and not results.is_empty():
        add_child(confetti_scene.instantiate())
        AudioDirector.play_sfx(&"sparkle")
    AudioDirector.play_sfx(&"result_fanfare")

func _gain_lines(r: Dictionary) -> String:
    var parts: Array[String] = []
    for pair in [["akademis_delta", "Akademis"], ["seni_delta", "Seni"],
        ["olahraga_delta", "Olahraga"], ["mood_delta", "Mood"], ["energy_delta", "Energi"]]:
        if float(r.get(pair[0], 0.0)) > 0.0:
            parts.append("%s +%d" % [pair[1], int(r[pair[0]])])
    return "\n".join(parts)

func _row_for(sid: int) -> ApplyStudentRow:
    for row in _rows:
        if row.selected_student_id() == sid:
            return row
    return null

func _on_scroll_input(event: InputEvent) -> void:
    # drag-to-scroll, lifted from EventStudentSelectDialog._on_scroll_gui_input
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        set_meta("_drag", event.pressed)
        set_meta("_dy", event.global_position.y)
        set_meta("_v0", _scroll.scroll_vertical)
    elif event is InputEventMouseMotion and get_meta("_drag", false):
        _scroll.scroll_vertical = int(get_meta("_v0") - (event.global_position.y - get_meta("_dy")))
```

Verify: `AnimUtils.create_floating_text` signature (parent, text, pos, color) —
adjust arg order to the real one; `Juice.stagger_in` exists and takes an Array;
`RewardBurst`/`CelebrationConfetti` roots are self-freeing one-shots (they are,
per the 2026-09-03 pass) — if not, `queue_free` them after a timer. Reaching
into `row._check` from `_on_select_all` is ugly; if `ApplyStudentRow` gets a
`set_selected(bool)` / `can_select()` helper during Task 9 review, use that
instead.

- [ ] **Step 4: Build `ApplyItemScreen.tscn`**

Through the editor. Root `Control` "ApplyItemScreen", full-rect, `theme` attached, `script` attached.
- `Background`: `Panel`, full-rect, `theme_type_variation = &"Scrim"`.
- `Margin`: `MarginContainer`, margins ~40.
  - `Card`: `PanelContainer`, `&"Card"`.
    - `Margin`: `MarginContainer`, margins ~28.
      - `VBox`: `VBoxContainer`, `separation` ~18.
        - `TitleLabel`: `Label`, `&"H1Label"`, text `"Pakai ke Siapa?"`.
        - `RecapStrip`: `HBoxContainer`, `separation` ~16. `RecapIcon` (`TextureRect` 96×96, `expand_mode=1`,`stretch_mode=6`), `RecapName` (`&"TitleLabel"`), `RecapCount` (`&"CaptionLabel"`).
        - `EffectSummary`: `Label`, `&"CaptionLabel"`, `autowrap_mode = 3`.
        - `Scroll`: `ScrollContainer`, `size_flags_vertical = 3`, `horizontal_scroll_mode = 0`.
          - `Rows`: `VBoxContainer`, `size_flags_horizontal = 3`, `separation` ~14.
        - `Actions`: `VBoxContainer`, `separation` ~14.
          - `SecondaryRow`: `HBoxContainer`, `separation` ~18. `SelectAllButton` (`&"SecondaryButton"`, `"Pilih Semua"`), `CancelButton` (`&"SecondaryButton"`, `"Batal"`).
          - `ConfirmButton`: `Button`, `&"SuccessButton"`, text `"Pakai (0 Siswa)"`, `custom_minimum_size = (0, 90)`.
`scene_save` to `res://Scenes/Inventory/ApplyItemScreen.tscn`.

- [ ] **Step 5: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="apply_item_screen")` (expect 6 PASS). No-op `script_patch` + rescan if needed.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Inventory/ApplyItemScreen.gd Scripts/Inventory/ApplyItemScreen.gd.uid Scenes/Inventory/ApplyItemScreen.tscn tests/test_apply_item_screen.gd tests/test_apply_item_screen.gd.uid
git commit -m "feat(inventory): add ApplyItemScreen with multi-select preview and staged payoff"
```

---

## Task 11: `InventorySlot` — badge bounce + shine

**Files:**
- Modify: `Scripts/Inventory/InventorySlot.gd`
- Modify: `Scenes/Inventory/InventorySlot.tscn` (add a `Shine` child)
- Test: `tests/test_inventory_slot.gd` (extend)

**Interfaces:**
- Produces: `InventorySlot.bounce_badge() -> void`; `@export var shine_min_quantity: int = 5`; `setup()` toggles `Shine.visible` by quantity.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_inventory_slot.gd`:

```gdscript
func test_slot_has_bounce_badge_and_shine_gate() -> void:
    var slot := (load("res://Scenes/Inventory/InventorySlot.tscn") as PackedScene).instantiate()
    assert_true(slot.has_method("bounce_badge"), "bounce_badge() present")
    assert_true("shine_min_quantity" in slot, "shine_min_quantity export present")
    assert_true(slot.get_node_or_null("Shine") != null, "authored Shine node present")
    slot.free()

func test_shine_hidden_below_threshold() -> void:
    var slot := (load("res://Scenes/Inventory/InventorySlot.tscn") as PackedScene).instantiate()
    get_tree().root.add_child(slot)
    slot.shine_min_quantity = 5
    slot.setup(ItemDatabase.get_item("Komik"), 2)
    assert_false(slot.get_node("Shine").visible)
    slot.setup(ItemDatabase.get_item("Komik"), 9)
    assert_true(slot.get_node("Shine").visible)
    slot.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_slot")`. New tests FAIL.

- [ ] **Step 3: Add the `Shine` node**

Through the editor: open `res://Scenes/Inventory/InventorySlot.tscn`, add a
`TextureRect` child `Shine` of the tile root (or of `$Layout`), `visible = false`,
`mouse_filter = 2` (ignore), `modulate = (1,1,1,0.25)`, stretched across the
tile. A placeholder texture is fine (reuse an existing soft-gradient asset, or a
`ColorRect` with a `Gradient`-backed `StyleBoxTexture` if simpler); note it
placeholder in the script comment. `move_node` so it draws above the icon.
`scene_save`.

- [ ] **Step 4: Extend `InventorySlot.gd`**

```gdscript
## Minimum owned quantity before the idle shine sweep runs on this tile.
@export var shine_min_quantity: int = 5

@onready var _shine: Control = $Shine
```

In `setup()`, after `quantity_label.text = ...`:

```gdscript
    _shine.visible = quantity >= shine_min_quantity
    if _shine.visible and not Engine.is_editor_hint():
        _start_shine()
```

Add:

```gdscript
## Loop a soft highlight left-to-right across the tile. Purely decorative
## "you have a lot of these" -- a @tool visual driven by shine_min_quantity.
func _start_shine() -> void:
    var w := size.x if size.x > 0 else custom_minimum_size.x
    _shine.position.x = -w
    var t := create_tween().set_loops()
    t.tween_property(_shine, "position:x", w, 1.4).set_trans(Tween.TRANS_SINE)
    t.tween_interval(2.5)

## Bounce the count badge after the owned quantity changed.
func bounce_badge() -> void:
    AnimUtils.qty_punch(quantity_label)
```

Verify `AnimUtils.qty_punch` exists (it is used by the current `inventory.gd`).
Keep the `@onready var _shine` null-safe if the scene is instantiated without
the node in some old test — it now always has it, so a plain `@onready` is fine.

- [ ] **Step 5: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory_slot")` (all PASS). No-op `script_patch` if the `@export` reads stale.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Inventory/InventorySlot.gd Scenes/Inventory/InventorySlot.tscn tests/test_inventory_slot.gd
git commit -m "feat(inventory): InventorySlot badge bounce and high-count shine sweep"
```

---

## Task 12: Re-author `inventory.tscn` and rewrite `inventory.gd`

**Files:**
- Rewrite: `Scenes/Inventory/inventory.tscn`
- Rewrite: `Scripts/Inventory/inventory.gd`
- Modify: `tests/test_inventory.gd`
- Modify: `tests/test_viewport_editability.gd:67` (delete the `inventory.gd` `BASELINE` line)
- Test: `tests/test_inventory.gd`, `tests/test_viewport_editability.gd`

**Interfaces:**
- Consumes: `InventorySlot.tscn` (Task 11), `ItemDetailSheet.tscn` (Task 8), `ApplyItemScreen.tscn` (Task 10), `FilterChipButton` variation (Task 6), `GameState.inventory_changed` / `money_changed` / `use_item_on_students`.
- Produces: the shipped Inventory screen. Node names other code/tests rely on: `MainColumn/Header`, `FilterRow`, four chip buttons in a `ButtonGroup`, `GridArea/Scroll/Grid`, `Grid/EmptyStateLabel`, `ToastLabel`.

- [ ] **Step 1: Rewrite the test suite (failing)**

Replace `tests/test_inventory.gd` body. Keep the still-true guards; swap the sidebar-era ones:

```gdscript
@tool
extends McpTestSuite

## Inventory screen: 3-zone portrait layout, theme-driven (no StyleBoxFlat
## overrides), routes to ItemDetailSheet + ApplyItemScreen. Suite is @tool,
## no coroutine tests.

func suite_name() -> String:
    return "inventory"

const _SCENE := "res://Scenes/Inventory/inventory.tscn"
const _SCRIPT := "res://Scripts/Inventory/inventory.gd"

func _src() -> String:
    return FileAccess.get_file_as_string(_SCRIPT)

func _raw() -> String:
    return FileAccess.get_file_as_string(_SCENE)

func test_scene_loads_and_instantiates() -> void:
    var s := (load(_SCENE) as PackedScene).instantiate()
    assert_true(s != null)
    s.free()

func test_three_zone_layout_present() -> void:
    var s := (load(_SCENE) as PackedScene).instantiate()
    assert_true(s.find_child("Header", true, false) != null)
    assert_true(s.find_child("FilterRow", true, false) != null)
    assert_true(s.find_child("Grid", true, false) != null)
    assert_true(s.find_child("ToastLabel", true, false) != null)
    s.free()

func test_sidebar_and_old_modals_are_gone() -> void:
    var s := (load(_SCENE) as PackedScene).instantiate()
    assert_true(s.find_child("Sidebar", true, false) == null, "no vertical sidebar")
    assert_true(s.find_child("DetailPanel", true, false) == null)
    assert_true(s.find_child("UsePopup", true, false) == null)
    s.free()

func test_four_category_chips_in_a_button_group() -> void:
    var s := (load(_SCENE) as PackedScene).instantiate()
    var chips := 0
    for n in ["CatSemua", "CatBuku", "CatOlahraga", "CatMakanan"]:
        var b := s.find_child(n, true, false)
        assert_true(b != null and b is Button, "missing chip " + n)
        if b:
            chips += 1
            assert_true(b.button_group != null, n + " must share a ButtonGroup")
    assert_equal(4, chips)
    s.free()

func test_scene_has_no_styleboxflat_overrides() -> void:
    var raw := _raw()
    assert_false(raw.contains('theme_override_styles/panel = SubResource("StyleBoxFlat'),
        "chrome comes from the theme, not per-node StyleBoxFlat overrides")
    assert_false(raw.contains("Color(0."), "no raw colour literals in the scene")

func test_script_has_no_runtime_chrome() -> void:
    var src := _src()
    for gone in ["_apply_category_style", "_style_all_category_buttons",
                 "_build_student_strip", "_open_use_popup", "_spawn_floating_stat_pops",
                 "_apply_png_panel_overrides"]:
        assert_false(src.contains(gone), "removed: " + gone)
    assert_false(src.contains("theme_override"), "no theme_override in script")
    assert_false(src.contains("Color(0."), "colours from DesignTokens only")

func test_script_routes_to_sheet_and_apply_screen() -> void:
    var src := _src()
    assert_true(src.contains("detail_sheet_scene"))
    assert_true(src.contains("apply_screen_scene"))
    assert_true(src.contains("ItemDetailSheet.tscn"))
    assert_true(src.contains("ApplyItemScreen.tscn"))

func test_back_returns_to_lobby_with_a_transition_style() -> void:
    var src := _src()
    assert_true(src.contains("res://Scenes/Lobby/loby.tscn"))
    assert_true(src.contains("Transition.Style."))
    assert_false(src.contains("koprasi.tscn"))

func test_uses_audio_director() -> void:
    assert_true(_src().contains("AudioDirector.play_sfx"))
    assert_false(_src().contains("SfxManager"))

func test_item_icons_preserved() -> void:
    for item_name in ["Komik", "Raket", "Mie Instan"]:
        assert_true(ItemDatabase.get_item(item_name).icon != null)

func test_no_global_player_stat_refs() -> void:
    var src := _src()
    assert_false(src.contains("GameState.player_mood"))
    assert_false(src.contains("GameState.player_energy"))
```

- [ ] **Step 2: Run to verify it fails**

Controller: `filesystem_manage(op="scan")` → `test_run(suite="inventory")`. FAIL across the new assertions.

- [ ] **Step 3: Rewrite `inventory.gd`**

```gdscript
extends Control
## The Inventory screen. Every owned item is a tappable grid tile; tapping one
## opens ItemDetailSheet, whose "Pakai ke Siswa" button opens ApplyItemScreen.
## This script never builds visuals at runtime -- tiles, the sheet and the
## apply screen are all PackedScene templates, and the chrome is authored in
## the .tscn with theme variations.

## One grid tile.
@export var slot_scene: PackedScene = preload("res://Scenes/Inventory/InventorySlot.tscn")
## Bottom sheet shown when a tile is tapped.
@export var detail_sheet_scene: PackedScene = preload("res://Scenes/Inventory/ItemDetailSheet.tscn")
## Full-screen "apply to students" modal opened from the sheet.
@export var apply_screen_scene: PackedScene = preload("res://Scenes/Inventory/ApplyItemScreen.tscn")
## Seconds the "stack habis" toast stays fully visible.
@export var toast_hold: float = 1.1

@onready var _coin_label: Label = $MainColumn/Header/Row/CoinDisplay/CoinLabel
@onready var _back_button: TextureButton = $MainColumn/Header/Row/BackButton
@onready var _grid: GridContainer = $MainColumn/GridArea/Scroll/Grid
@onready var _empty_label: Label = $MainColumn/GridArea/Scroll/Grid/EmptyStateLabel
@onready var _toast: Label = $ToastLabel
@onready var _chips: Array = [
    $MainColumn/FilterRow/Scroll/Chips/CatSemua,
    $MainColumn/FilterRow/Scroll/Chips/CatBuku,
    $MainColumn/FilterRow/Scroll/Chips/CatOlahraga,
    $MainColumn/FilterRow/Scroll/Chips/CatMakanan,
]

var current_category: String = "Semua"
var _sheet: ItemDetailSheet = null
var _apply_screen: ApplyItemScreen = null

func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    for chip in _chips:
        chip.pressed.connect(_on_chip_pressed.bind(chip.text))
    _chips[0].button_pressed = true
    _toast.visible = false
    _coin_label.text = "%d" % GameState.player_money
    if not GameState.money_changed.is_connected(_on_money_changed):
        GameState.money_changed.connect(_on_money_changed)
    if not GameState.inventory_changed.is_connected(_on_inventory_changed):
        GameState.inventory_changed.connect(_on_inventory_changed)
    _populate_grid()

func _on_money_changed(_amount: int) -> void:
    _coin_label.text = "%d" % GameState.player_money

func _on_inventory_changed() -> void:
    if is_inside_tree():
        _populate_grid()

func _populate_grid() -> void:
    for child in _grid.get_children():
        if child == _empty_label:
            continue
        _grid.remove_child(child)
        child.queue_free()
    _empty_label.visible = false

    var idx := 0
    for item_name in GameState.inventory:
        var qty: int = GameState.inventory[item_name]
        var data: ItemData = ItemDatabase.get_item(item_name)
        if data == null:
            continue
        if current_category != "Semua" and data.category != current_category:
            continue
        var slot: InventorySlot = slot_scene.instantiate()
        _grid.add_child(slot)
        slot.setup(data, qty)
        slot.slot_pressed.connect(_on_slot_pressed)
        AnimUtils.staggered_entrance(slot, idx * 0.06)
        idx += 1

    if idx == 0:
        _empty_label.text = "Inventory kosong" if current_category == "Semua" \
            else "Tidak ada item \"%s\"" % current_category
        _empty_label.visible = true

func _on_chip_pressed(category: String) -> void:
    if current_category == category:
        return
    current_category = category
    AudioDirector.play_sfx(&"tap")
    _populate_grid()

func _on_slot_pressed(slot: InventorySlot) -> void:
    if _sheet != null:
        _sheet.queue_free()
        _sheet = null
    _open_detail_sheet(slot.item)

func _open_detail_sheet(item: ItemData) -> void:
    _sheet = detail_sheet_scene.instantiate()
    add_child(_sheet)
    _sheet.setup(item, GameState.get_inventory_quantity(item.item_name))
    _sheet.apply_requested.connect(_open_apply_screen)
    _sheet.dismissed.connect(func(): _sheet = null)

func _open_apply_screen(item: ItemData) -> void:
    if _sheet != null:
        _sheet.queue_free()
        _sheet = null
    _apply_screen = apply_screen_scene.instantiate()
    add_child(_apply_screen)
    _apply_screen.setup(item)
    _apply_screen.applied.connect(_on_items_applied.bind(item))
    _apply_screen.cancelled.connect(func(): _apply_screen = null)

func _on_items_applied(results: Array, item: ItemData) -> void:
    _apply_screen = null
    AudioDirector.play_sfx(&"whoosh")
    var remaining := GameState.get_inventory_quantity(item.item_name)
    _populate_grid()
    if remaining > 0:
        for slot in _grid.get_children():
            if slot is InventorySlot and slot.item == item:
                slot.bounce_badge()
    else:
        _show_toast("%s habis" % item.item_name)

func _show_toast(text: String) -> void:
    _toast.text = text
    _toast.visible = true
    _toast.modulate.a = 0.0
    var t := create_tween()
    t.tween_property(_toast, "modulate:a", 1.0, 0.15)
    t.tween_interval(toast_hold)
    t.tween_property(_toast, "modulate:a", 0.0, 0.3)
    t.tween_callback(func(): _toast.visible = false)

func _notification(what: int) -> void:
    if what != NOTIFICATION_WM_GO_BACK_REQUEST:
        return
    if _apply_screen != null:
        _apply_screen.queue_free()
        _apply_screen = null
    elif _sheet != null:
        _sheet.queue_free()
        _sheet = null
    else:
        _on_back_pressed()

func _on_back_pressed() -> void:
    AudioDirector.play_sfx(&"whoosh")
    await get_tree().create_timer(0.15).timeout
    Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)
```

Verify `AnimUtils.staggered_entrance` still exists with that signature (the
current script uses it). `_on_back_pressed` has one `await` — production code,
fine.

- [ ] **Step 4: Re-author `inventory.tscn`**

Through the editor. Rebuild to the layout in Section 1.1 of the spec / the File
Structure above. Practical order with `batch_execute`:
1. `scene_open` the existing scene; delete `MainLayout` wholesale (and every
   `SubResource` goes with it) but keep root `Inventory` + `Background`.
2. Recreate root script link (already set).
3. Build `MainColumn` (`VBoxContainer`, full-rect anchors 0/0/1/1).
4. `Header` (`PanelContainer`, `custom_minimum_size = (0,120)`): keep a
   `StyleBoxTexture` on `panel_header.png` as a scene subresource (art, allowed)
   — recreate it. Child `Row` (`HBoxContainer`) → `BackButton` (`TextureButton`,
   `return.png`, 80×80), `TitleLabel` (`Label`, `&"DisplayLabel"`, `"INVENTORY"`),
   `Spacer` (`Control`, `size_flags_horizontal = 3`), `CoinDisplay`
   (`HBoxContainer`) → `CoinIcon` (`TextureRect`, `Koin.png`, 50×50),
   `CoinLabel` (`Label`, `&"CoinLabel"`, `"0"`).
5. `FilterRow` (`PanelContainer`, `&"SunkenPanel"`, `custom_minimum_size = (0,96)`)
   → `Scroll` (`ScrollContainer`, `vertical_scroll_mode = 0`) → `Chips`
   (`HBoxContainer`, `separation` ~12) → four `Button`s `CatSemua` / `CatBuku` /
   `CatOlahraga` / `CatMakanan`, each `theme_type_variation = &"FilterChipButton"`,
   `toggle_mode = true`, texts `Semua` / `Buku` / `Olahraga` / `Makanan`. Create
   one `ButtonGroup` sub-resource and set `button_group` on all four.
6. `GridArea` (`MarginContainer`, margins 24/24/24/12, `size_flags_vertical = 3`)
   → `Scroll` (`ScrollContainer`, `horizontal_scroll_mode = 0`) → `Grid`
   (`GridContainer`, `columns = 3`, `h/v_separation` ~16) → `EmptyStateLabel`
   (`Label`, `&"EmptyStateLabel"`, `visible = false`, `horizontal_alignment = 1`,
   `size_flags_horizontal = 3`).
7. `ToastLabel` as a child of root `Inventory` (not `MainColumn`): `Label`,
   `&"CaptionLabel"` or `&"H2Label"`, centered near bottom
   (`anchor_top = 0.85`, centered), `visible = false`.
`scene_save`.

- [ ] **Step 5: Lower the ratchet**

Edit `tests/test_viewport_editability.gd`: delete the line
`"res://Scripts/Inventory/inventory.gd": 4,` from `BASELINE`. Do not touch other
entries.

- [ ] **Step 6: Run tests to verify they pass**

Controller: `filesystem_manage(op="scan")` →
- `test_run(suite="inventory")` — all PASS.
- `test_run(suite="viewport_editability")` — still green (the three new scripts
  introduce no tolerated sites; if one trips the scan, fix the script to not
  construct visuals rather than add a `BASELINE` entry).

- [ ] **Step 7: Commit**

```bash
git add Scenes/Inventory/inventory.tscn Scripts/Inventory/inventory.gd tests/test_inventory.gd tests/test_viewport_editability.gd
git commit -m "feat(inventory): rebuild screen as 3-zone portrait layout routing to sheet + apply flow"
```

---

## Task 13: `CLAUDE.md` update + full-suite verification

**Files:**
- Modify: `CLAUDE.md` (the "No save system" paragraph under Architecture; add a "Current work" entry)
- Test: full `test_run()`

**Interfaces:** none.

- [ ] **Step 1: Update the persistence note**

In `CLAUDE.md`, replace:

> No save system. Everything is session-scoped by design — do not add
> persistence to `GameState` without being asked.

with:

> Persistence is minimal and deliberate: **only `GameState.inventory`** is
> written to disk (`user://inventory.cfg`, flushed at the top of every
> `Transition.change_scene`, loaded in `GameState._ready`). Everything else —
> roster, money, week, grade, schedules — is session-scoped by design. Item
> boosts land on `approved_students`, which is **not** persisted, so a boost
> applied and not simulated before quit is lost. Do not add further persistence
> without being asked. Debug > General > **🧹 Forget Session** wipes in-memory
> `GameState` and deletes the save.

- [ ] **Step 2: Add a Current work entry**

Under "## Current work", add a dated paragraph summarising: inventory screen
rebuilt to a 3-zone portrait layout; `ItemDetailSheet` + `ApplyItemScreen` +
`ApplyStudentRow` added; `use_item` fixed to write `kepribadian1/2` + `akademis1/2/3`
and given skill boosts; `use_item_on_students` batch; inventory persistence +
`forget_session`; `FilterChipButton` variation. Reference this plan and the spec.
Note placeholders still outstanding: the five `EfekRow` need icons, the
`InventorySlot` `Shine` texture, `ApplyItemScreen` reuses `star_earn_*` /
`result_fanfare` / `sparkle` (no dedicated cue), and the item skill-boost table
is balance-pending against `test_balance_pacing.gd`.

- [ ] **Step 3: Full suite**

Controller: `filesystem_manage(op="scan")`, ensure `Scenes/MainMenu/main_menu.tscn`
is open (some suites need it), then `test_run()` (no filter).
Expected: every suite green. Prior baseline was 45 suites / 568 tests; this pass
adds `item_catalog`, `use_item_on_students`, `inventory_persistence`,
`item_detail_sheet`, `apply_student_row`, `apply_item_screen`, and possibly
`theme_factory` — so ~51–52 suites, all passing. Investigate any red before
proceeding (per `systematic-debugging`); do not paper over with skips.

- [ ] **Step 4: Manual smoke (optional but recommended)**

Controller: `project_run`, open Debug (`F1`) → ⚡ Seed Playtest State → Scenes →
Lobby → Inventory. Tap a tile (sheet slides up, Efek rows show only the item's
bars), Pakai ke Siswa (apply screen, select two students, bars preview
`45 ➔ 65`), Pakai (2 Siswa) (per-student burst + floating text + confetti if
both gained), land back on the grid with the badge ticked down. Then Debug → 🧹
Forget Session → confirm it boots to MainMenu with an empty roster/inventory.
`editor_screenshot` once for the record.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record inventory rebuild, item-apply flow, and inventory persistence"
```

---

## Self-Review

**Spec coverage:**
- §1 layout rebuild → Task 12 (+ Task 6 chip variation, Task 11 slot).
- §2 `ItemDetailSheet` + Efek block + explanations → Task 8 (+ Task 7 `EfekRow`).
- §3 `ApplyItemScreen` + `ApplyStudentRow` + `StatBarRow` + payoff → Tasks 7, 9, 10.
- §4 `ItemData`/`ItemDatabase`/`use_item`/`use_item_on_students` → Tasks 1, 2.
- §4.2a per-item placeholder descriptions → Task 1 Step 5 + `test_item_catalog`.
- §5 feedback layering → Tasks 8 (sheet juice), 9 (select preview), 10 (payoff), 11 (tile shine/badge), 12 (toast/empty).
- §6 testing → every task ships its suite; ratchet lowered in Task 12; `test_script_documentation` satisfied by `##` headers/exports in Tasks 8–12.
- §7 persistence + debug reset → Tasks 3, 4, 5; `CLAUDE.md` in Task 13.
- Balance risk → noted in Task 1 Step 5 comment and Task 13 Step 2.

**Placeholder scan:** No "TBD"/"handle errors"/"similar to". Every code step has
real code. Names flagged "verify against the real API" are explicit callouts,
not gaps — the surrounding code is complete and the fallback is named.

**Type consistency:** `use_item` return keys (`mood_delta`, `energy_delta`,
`akademis_delta`, `seni_delta`, `olahraga_delta`) are identical in Task 2's
implementation, Task 2's tests, Task 9's `ApplyStudentRow` (reads via
`_gain_lines` in Task 10), and Task 10's `_gain_lines`. `use_item_on_students`
result shape (`student_id`, `name`, + five deltas) matches between Task 2 and
Task 10's `_row_for` / `_play_payoff`. `KEY` mapping (`akademis1/2/3`,
`kepribadian1/2`) is identical in the spec, Task 9's `const KEY`, and Task 2's
`fields` array. Node names (`Rows`, `ConfirmButton`, `Grid`, `FilterRow`,
`ToastLabel`, `EfekList`, five `RowX`/`BarRowX`) match between each scene-build
step and its test. `FilterChipButton` spelled consistently in Tasks 6 and 12.
