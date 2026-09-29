# Dialogue Variations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every EventDialogue line and every MinigameWinScreen line is drawn
from a pool of at least five in-character variations in natural, KBBI-checked
Indonesian. The Guru Seni Budaya placeholder splash is replaced by the real
art.

**Architecture:**
- A new pure-data script, `EventDialogueLines.gd`, holds every pool.
- `EventDialogueCatalog` gains `pool_for` / `draw` / `pick_line` /
  `win_pool_for` and a three-argument `win_line_for`, which pick a line and
  fall back to the entry's existing single line.
- `SchoolDay` passes the picked line into the unchanged `EventDialogue.open()`.
- The win bubble grows upward to hold two wrapped lines.

**Tech Stack:** Godot 4.6 GDScript. Tests are `McpTestSuite` suites run in the
editor through the godot-ai MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-29-dialogue-variations-design.md`.
Read its "Language rules" and "Voice sheets" before any content task.

## Global Constraints

- Work only in the worktree
  `C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\dialogue-variations\`,
  on branch `feat/dialogue-variations`. Never edit the main checkout: another
  session has uncommitted SkinSelect work there. Subagents must be given this
  absolute path.
- Every pool has **at least 5** lines, with no duplicates inside a pool.
- **KBBI.** Every word must have a KBBI entry. Casual words KBBI marks
  *cak.* are allowed (enggak, capek, banget, gampang, bikin, pengin, kayak,
  bareng, keren, jago), as are the particles kok, dong, sih, deh, nih, yuk
  and ya.
- **Banned forms.** Never use nggak, gak, ga, udah, dah, aja, pengen,
  makasih, gimana, workshop, ngerjain, nyelesaiin, bikinin, asik, gue, lu,
  or any other nasal-prefix + `-in` verb.
- Students call the player "Pak". NPCs say "Pak" or "Pak Guru".
- **ASCII only.** Write `...`, never `…`. No emoji.
- Students never write `{nama}`. Every `nasi_kotak` line contains `{nama}`.
- Every line of a CHOICE entry (`les_akademis`, `latihan_olahraga`,
  `workshop_seni`) ends in `?`.
- Event lines are at most 120 characters (`MAX_EVENT_LINE_CHARS`). Win lines,
  uppercased, wrap to at most two lines of the win bubble.
- **Hujan.** The narrator describes the event's real cost: every student
  loses energy and mood. Say wet, slipping, tired or gloomy; never
  contradict it.
- **Editor hazards (CLAUDE.md 4b).**
  - Do all scene work (Task 2) before any script edit.
  - After a `.gd` is written from outside the editor, run a no-op
    `script_patch` on it before `test_run`.
  - Never `scene_save` after a script has been patched without restarting
    the editor first.
- **The bridge.** Pass `session_id` of the worktree editor on every godot-ai
  call, and never `session_activate` (memory:
  verify-worktree-changes-in-a-second-editor).
- **Commits** are Conventional with a scope. Write the message to a
  scratchpad file and run `git -C <worktree> commit -F <file>`. End every
  message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File map

| File | Change | Responsibility |
|---|---|---|
| `Assets/Images/EventDialogue/splash_gurusenibudaya.png` | Replace | Real Guru Seni Budaya art |
| `docs/superpowers/DEBT.md` | Modify | Drop the placeholder clause |
| `Scenes/Minigames/UI/MinigameWinScreen.tscn` | Modify (editor) | Two-line bubble, `"Terima kasih, Pak!"` default |
| `Scripts/SchoolSimulation/EventDialogueLines.gd` | Create | All line pools (pure `const` data) |
| `Scripts/SchoolSimulation/EventDialogueCatalog.gd` | Modify | Picking API, fallback, `WIN_LINE_STUDENT` |
| `Scripts/SchoolSimulation/SchoolDay.gd` | Modify | Pass the picked line and win line |
| `tests/test_event_dialogue.gd` | Modify | API behaviour and wiring |
| `tests/test_minigame_win_screen.gd` | Modify | Bubble geometry and wrapping |
| `tests/test_event_dialogue_lines.gd` | Create | Coverage, language, choice, length and fit for every pool |
| `docs/superpowers/specs/2026-09-29-dialogue-variations-design.md` | Modify | KBBI appendix |
| `docs/superpowers/CHANGELOG.md`, `CLAUDE.md` | Modify | Record the pass |

---

### Task 1: Worktree editor and the Guru Seni Budaya art

**Files:**
- Replace: `Assets/Images/EventDialogue/splash_gurusenibudaya.png`
- Modify: `docs/superpowers/DEBT.md:73-77`

**Interfaces:**
- Consumes: none.
- Produces: a running worktree editor with a known `session_id`, which every
  later task uses.

- [ ] **Step 1: Seed and launch the worktree editor**

Copy `imported/`, `shader_cache/`, `uid_cache.bin`,
`global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main
checkout's `.godot/` into the worktree's `.godot/`. Skip `.godot/editor/`.
Then launch the editor detached:

```powershell
$wt = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\dialogue-variations"
$exe = (Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Select-Object -First 1).ExecutablePath
Invoke-CimMethod Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e" }
```

If no Godot is running to borrow the path from, ask the user for the exe
path. Then call `session_manage(op="list")` until a session whose
`project_path` is the worktree shows `ready`, and record its `session_id`.

- [ ] **Step 2: Drop in the art**

```powershell
Copy-Item "C:\Users\user\Downloads\GuruSBK.png" "$wt\Assets\Images\EventDialogue\splash_gurusenibudaya.png" -Force
```

Then `filesystem_manage(op="scan", session_id=…)`. The `.import` file and
the UID must stay unchanged:

```powershell
git -C $wt status --short
```

Expected: only `M Assets/Images/EventDialogue/splash_gurusenibudaya.png`.
The `.png.import` may be rewritten; if so, check with `git diff` that its
`uid=` line is unchanged.

- [ ] **Step 3: Run the art test**

Run `test_run(suite="event_dialogue", session_id=…)`.
Expected: PASS, including `test_every_art_path_loads`
(`tests/test_event_dialogue.gd:92`, which loads `SPLASH_GURU_SENI`).

- [ ] **Step 4: Delete the DEBT placeholder clause**

In `docs/superpowers/DEBT.md`, change

```
the 2026-09-14 EventDialogue set in
`Assets/Images/EventDialogue/`: `splash_gurusenibudaya.png` (a flat
silhouette for the Seni Budaya teacher, on the same 1080x1920 frame as every
splash), `hujan_background.png` (the school tinted dusk-blue with seeded rain
streaks) and `calendar_badge.png`,
```

to

```
the 2026-09-14 EventDialogue set in
`Assets/Images/EventDialogue/`: `hujan_background.png` (the school tinted
dusk-blue with seeded rain streaks) and `calendar_badge.png`,
```

- [ ] **Step 5: Commit**

```
git -C $wt add Assets/Images/EventDialogue/splash_gurusenibudaya.png docs/superpowers/DEBT.md
git -C $wt commit -F <msg>
```

Message: `feat(event-dialogue): the real Guru Seni Budaya splash`.
Before staging, revert any `Assets/Audio/default_bus_layout.tres` rewrite
with `git -C $wt checkout -- Assets/Audio/default_bus_layout.tres`.

---

### Task 2: The win bubble holds two lines (scene work)

**Files:**
- Modify (through the editor only): `Scenes/Minigames/UI/MinigameWinScreen.tscn`,
  nodes `Root/Bubble` and `Root/Bubble/Panel/Line`
- Test: `tests/test_minigame_win_screen.gd`

**Interfaces:**
- Consumes: the Task 1 `session_id`.
- Produces: `Root/Bubble` with `offset_bottom = -878` and a new `offset_top`
  (call it `BUBBLE_TOP`), and `Line.autowrap_mode = 3`
  (`AUTOWRAP_WORD_SMART`). Task 4's fit test reads the bubble's width
  (980 px) from the scene.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_minigame_win_screen.gd`, after
`test_every_piece_hangs_off_the_bottom_edge`:

```gdscript
## Two uppercase lines of MinigameWinLine plus the bubble's vertical margins
## fit (2026-09-29 dialogue-variations spec). The bubble grows upward: its
## bottom stays 50 px above the card and the Tail rides its top edge.
func test_the_bubble_holds_two_wrapped_lines() -> void:
	var theme := _baked()
	var font := theme.get_font("font", "MinigameWinLine")
	var size := theme.get_font_size("font_size", "MinigameWinLine")
	var box := theme.get_stylebox("panel", "MinigameWinBubble")
	var need := font.get_height(size) * 2.0 + box.content_margin_top + box.content_margin_bottom
	var s := _screen()
	var line := s.get_node("Root/Bubble/Panel/Line") as Label
	assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the line wraps")
	assert_eq(s.bubble.offset_bottom, -878.0, "the bottom stays put")
	var have := s.bubble.offset_bottom - s.bubble.offset_top
	assert_true(have >= need, "bubble is %d px tall, two lines need %d" % [have, need])
	assert_eq(line.text, "Terima kasih, Pak!", "the authored default matches WIN_LINE_STUDENT")
```

- [ ] **Step 2: Run it and watch it fail**

Run `test_run(suite="minigame_win_screen", session_id=…)`.
Expected: FAIL on "the line wraps" and on the height. Note the reported
`need` in px and set `BUBBLE_TOP = -878 - ceil(need / 8) * 8`, rounding the
height up to the next multiple of 8.

- [ ] **Step 3: Edit the scene in the editor**

```
scene_open("res://Scenes/Minigames/UI/MinigameWinScreen.tscn", session_id=…)
node_set_property(path="Root/Bubble", property="offset_top", value=BUBBLE_TOP)
node_set_property(path="Root/Bubble/Panel/Line", property="autowrap_mode", value=3)
node_set_property(path="Root/Bubble/Panel/Line", property="text", value="Terima kasih, Pak!")
scene_save(session_id=…)
```

Then run `git -C $wt diff -- Scenes/Minigames/UI/MinigameWinScreen.tscn`.
Expected: exactly these three property changes, with no baked `@tool` state
or theme overrides (memory: stickynote-tool-script-bakes-offsets). Also run
`git -C $wt diff HEAD -- '*.gd'`, which must be empty.

- [ ] **Step 4: Update the pinned geometry**

In `test_every_piece_hangs_off_the_bottom_edge`, change
`"Root/Bubble": Vector4(50, -1022, -50, -878),` to
`"Root/Bubble": Vector4(50, BUBBLE_TOP, -50, -878),`, with the number filled in.

- [ ] **Step 5: Run to pass**

Run a no-op `script_patch` on `tests/test_minigame_win_screen.gd`, then
`test_run(suite="minigame_win_screen", session_id=…)` and
`test_run(suite="tall_screen_layout", session_id=…)`.
Expected: both PASS.

- [ ] **Step 6: Commit**

Message: `feat(win-screen): the bubble wraps to two lines`. Stage the `.tscn`
and the test.

---

### Task 3: The line-picking API

**Files:**
- Create: `Scripts/SchoolSimulation/EventDialogueLines.gd`
- Modify: `Scripts/SchoolSimulation/EventDialogueCatalog.gd` (lines 32-43 and
  183-196)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (`_show_event_dialogue`,
  around line 1569; `_win_context`, around line 1621)
- Test: `tests/test_event_dialogue.gd`

**Interfaces:**
- Consumes: none (Task 2 is scene-only).
- Produces:
  - `EventDialogueLines.STUDENT_LINES: Dictionary`
    (`event_key -> {student_name -> Array}`)
  - `EventDialogueLines.NPC_LINES: Dictionary` (`event_key -> Array`)
  - `EventDialogueLines.WIN_STUDENT_LINES: Dictionary`
    (`student_name -> {category -> Array}`)
  - `EventDialogueLines.WIN_TEACHER_LINES: Dictionary` (`category -> Array`)
  - `EventDialogueCatalog.MAX_EVENT_LINE_CHARS: int = 120`
  - `EventDialogueCatalog.WIN_LINE_STUDENT: String = "Terima kasih, Pak!"`
  - `EventDialogueCatalog.pool_for(key: String, featured: StudentData) -> Array`
  - `EventDialogueCatalog.draw(pool: Array, last: String) -> String`
  - `EventDialogueCatalog.pick_line(key: String, featured: StudentData) -> String`
  - `EventDialogueCatalog.win_pool_for(speaker_path: String, category: String, featured: StudentData) -> Array`
  - `EventDialogueCatalog.win_line_for(speaker_path: String, category: String, featured: StudentData) -> String`

- [ ] **Step 1: Write the failing tests**

In `tests/test_event_dialogue.gd`, replace `test_each_speaker_has_its_own_thanks`
(lines 555-560) with the block below, and add the wiring test at the end of
the file:

```gdscript
# ── line pools (2026-09-29 dialogue-variations spec) ─────────────────────────

func test_draw_never_repeats_the_last_line() -> void:
	var pool := ["a", "b", "c", "d", "e"]
	var last := ""
	for i in 60:
		var got := EventDialogueCatalog.draw(pool, last)
		assert_true(got in pool, "draws from the pool")
		assert_ne(got, last, "no line twice in a row")
		last = got


func test_draw_of_one_line_repeats_it_and_of_none_is_empty() -> void:
	assert_eq(EventDialogueCatalog.draw(["a"], "a"), "a")
	assert_eq(EventDialogueCatalog.draw([], ""), "")


func test_an_unknown_student_hears_the_entry_line() -> void:
	var fallback: String = EventDialogueCatalog.entry("Variabel")["line"]
	assert_eq(EventDialogueCatalog.pool_for("Variabel", _student("Zed", "Akademis")), [fallback])
	assert_eq(EventDialogueCatalog.pool_for("Variabel", null), [fallback])
	assert_eq(EventDialogueCatalog.pool_for("no_such_key", null), [])


func test_npc_and_narrator_entries_use_their_own_pool() -> void:
	for key in ["nasi_kotak", "hujan", "latihan_olahraga", "workshop_seni", "MainBola"]:
		var want: Array = EventDialogueLines.NPC_LINES.get(key, [EventDialogueCatalog.entry(key)["line"]])
		assert_eq(EventDialogueCatalog.pool_for(key, _student("Marcel", "Akademis")), want, key)


func test_a_student_speaks_from_their_own_pool() -> void:
	var marcel := _student("Marcel", "Akademis")
	var want: Array = EventDialogueLines.STUDENT_LINES.get("Variabel", {}).get("Marcel",
		[EventDialogueCatalog.entry("Variabel")["line"]])
	assert_eq(EventDialogueCatalog.pool_for("Variabel", marcel), want)


func test_pick_line_fills_the_name() -> void:
	var thea := _student("Thea", "SeniBudaya")
	for i in 10:
		assert_false(EventDialogueCatalog.pick_line("nasi_kotak", thea).contains("{nama}"))


func test_win_pools_follow_the_speaker_and_the_category() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	var fallback := [EventDialogueCatalog.WIN_LINE_STUDENT]
	assert_eq(EventDialogueCatalog.win_pool_for(EventDialogueCatalog.SPLASH_GURU_SENI, "SeniBudaya", thea),
		EventDialogueLines.WIN_TEACHER_LINES.get("SeniBudaya", fallback))
	assert_eq(EventDialogueCatalog.win_pool_for(EventDialogueCatalog.SPLASH_GURU_PENJAS, "Olahraga", thea),
		EventDialogueLines.WIN_TEACHER_LINES.get("Olahraga", fallback))
	assert_eq(EventDialogueCatalog.win_pool_for(_THEA_SPLASH, "Akademis", thea),
		EventDialogueLines.WIN_STUDENT_LINES.get("Thea", {}).get("Akademis", fallback))
	assert_eq(EventDialogueCatalog.win_pool_for(_THEA_SPLASH, "Akademis", _student("Zed", "Akademis")), fallback)
	assert_eq(EventDialogueCatalog.win_pool_for("", "Akademis", null), fallback)
	assert_eq(EventDialogueCatalog.WIN_LINE_STUDENT, "Terima kasih, Pak!")


func test_win_line_is_drawn_from_its_pool() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	var pool := EventDialogueCatalog.win_pool_for(_THEA_SPLASH, "SeniBudaya", thea)
	for i in 10:
		assert_true(EventDialogueCatalog.win_line_for(_THEA_SPLASH, "SeniBudaya", thea) in pool)
```

At the end of the file:

```gdscript
func test_school_day_hands_over_the_picked_lines() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_true(src.contains('e["line"] = EventDialogueCatalog.pick_line(key, featured)'),
		"the dialogue shows a drawn line")
	assert_true(src.contains("EventDialogueCatalog.win_line_for(speaker, category, featured)"),
		"the win screen draws for its speaker and category")
```

- [ ] **Step 2: Run and watch them fail**

Run a no-op `script_patch` on the test file, then
`test_run(suite="event_dialogue", session_id=…)`.
Expected: FAIL, with parse errors naming `EventDialogueLines`, `draw` and
`pool_for`.

- [ ] **Step 3: Create `EventDialogueLines.gd`**

```gdscript
@tool
class_name EventDialogueLines
extends RefCounted

## Every variation of every EventDialogue and MinigameWinScreen line
## (2026-09-29 dialogue-variations spec): at least five per speaker per pool,
## in each speaker's own voice, in KBBI-checked Indonesian. Pure data;
## EventDialogueCatalog picks from it and falls back to an entry's own `line`
## when a pool is missing. The lines are drafts for the owner's writer.
##
## Rules every line keeps (tests/test_event_dialogue_lines.gd): ASCII only,
## no chat spellings (nggak, udah, aja...), students say "Pak" and never
## {nama}, CHOICE lines end in "?", event lines <= 120 characters, win lines
## fit two lines of the win bubble.

## event key -> {student name -> lines}. The featured student speaks.
const STUDENT_LINES := {}

## event key -> lines, for the NPC-voiced entries and the Hujan narrator.
## {nama} is the featured student.
const NPC_LINES := {}

## student name -> {category -> lines}: their thanks on the win screen.
const WIN_STUDENT_LINES := {}

## category -> lines: the subject teacher's thanks on the win screen
## ("Olahraga" is Guru Penjas, "SeniBudaya" is Guru Seni Budaya).
const WIN_TEACHER_LINES := {}
```

- [ ] **Step 4: Change `EventDialogueCatalog.gd`**

Replace lines 35-41 (`WIN_LINE_STUDENT` and `WIN_LINES`) with:

```gdscript
## What a student says on the win screen when they have no pool of their own
## (EventDialogueLines.WIN_STUDENT_LINES), and the scene's authored default.
const WIN_LINE_STUDENT := "Terima kasih, Pak!"
## The longest an event line may be, in characters: today's longest (Hujan,
## about 113) fits the dialogue box with room to spare.
const MAX_EVENT_LINE_CHARS := 120

## The line last drawn for each pool, keyed like pick_line's and
## win_line_for's `memo` keys, so the next draw skips it.
static var _last_line: Dictionary = {}
```

Replace `win_line_for` (lines 194-196) with the following, and add the new
functions after `fill_line`:

```gdscript
## Every line `key`'s speaker may say: the NPC or narrator pool for a
## non-student speaker, the featured student's own pool otherwise, and the
## entry's single `line` when there is no pool. [] for an unknown key.
static func pool_for(key: String, featured: StudentData) -> Array:
	var e := entry(key)
	if e.is_empty():
		return []
	var fallback: Array = [e.get("line", "")]
	if e.get("speaker", "") != SPEAKER_STUDENT:
		return EventDialogueLines.NPC_LINES.get(key, fallback)
	if featured == null:
		return fallback
	var by_student: Dictionary = EventDialogueLines.STUDENT_LINES.get(key, {})
	return by_student.get(featured.student_name, fallback)


## A random line of `pool` other than `last`; a one-line pool repeats, and an
## empty one gives "".
static func draw(pool: Array, last: String) -> String:
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return str(pool[0])
	var fresh := pool.filter(func(l: Variant) -> bool: return str(l) != last)
	return str(fresh[randi() % fresh.size()])


## The line EventDialogue shows for `key`: drawn from pool_for without
## repeating the last one, with {nama} filled in.
static func pick_line(key: String, featured: StudentData) -> String:
	var line := draw(pool_for(key, featured), str(_last_line.get(key, "")))
	_last_line[key] = line
	return fill_line(line, featured)


## Every thanks the win screen's speaker may say: the category's teacher pool
## when `speaker_path` is that teacher (WIN_TEACHER), the featured student's
## pool for `category` otherwise, and [WIN_LINE_STUDENT] when there is none.
static func win_pool_for(speaker_path: String, category: String, featured: StudentData) -> Array:
	var fallback: Array = [WIN_LINE_STUDENT]
	if speaker_path != "" and speaker_path == WIN_TEACHER.get(category, ""):
		return EventDialogueLines.WIN_TEACHER_LINES.get(category, fallback)
	if featured == null:
		return fallback
	var by_category: Dictionary = EventDialogueLines.WIN_STUDENT_LINES.get(featured.student_name, {})
	return by_category.get(category, fallback)


## The win screen's line: drawn from win_pool_for without repeating the last
## one for the same speaker and category.
static func win_line_for(speaker_path: String, category: String, featured: StudentData) -> String:
	var memo := "win|%s|%s" % [speaker_path, category]
	var line := draw(win_pool_for(speaker_path, category, featured), str(_last_line.get(memo, "")))
	_last_line[memo] = line
	return line
```

Also update the header comment (lines 10-11) to:
`## The lines' variations live in EventDialogueLines (2026-09-29 spec); each
## entry's own "line" is the fallback. {nama} becomes the featured student's name.`

- [ ] **Step 5: Change `SchoolDay.gd`**

In `_show_event_dialogue`, change
`var e: Dictionary = EventDialogueCatalog.entry(key)` to
`var e: Dictionary = EventDialogueCatalog.entry(key).duplicate()`. Right
after `_last_featured = featured`, add:

```gdscript
	e["line"] = EventDialogueCatalog.pick_line(key, featured)
```

In `_win_context`, change `EventDialogueCatalog.win_line_for(speaker)` to
`EventDialogueCatalog.win_line_for(speaker, category, featured)`.

- [ ] **Step 6: Run to pass**

Run a no-op `script_patch` on each of the four `.gd` files. Then run
`test_run(suite="event_dialogue", …)`, `test_run(suite="minigame_win_screen", …)`,
`test_run(suite="minigame_single_result", …)`,
`test_run(suite="script_documentation", …)` and `test_run(suite="clean_code", …)`.
Expected: all PASS.

- [ ] **Step 7: Commit**

Message: `feat(event-dialogue): draw each line from a speaker's pool`.

---

### Task 4: The lines suite

**Files:**
- Create: `tests/test_event_dialogue_lines.gd`

**Interfaces:**
- Consumes: the four `EventDialogueLines` dictionaries,
  `EventDialogueCatalog.ENTRIES` / `MODE_CHOICE` / `SPEAKER_STUDENT` /
  `MAX_EVENT_LINE_CHARS`, and the Task 2 bubble (width 980 px).
- Produces: the suite `event_dialogue_lines`, which Tasks 5-8 turn green.

- [ ] **Step 1: Write the suite**

```gdscript
@tool
extends McpTestSuite

## Every EventDialogueLines pool (2026-09-29 dialogue-variations spec): who
## has one, how many lines it holds, the language rules each line keeps, and
## that a win line fits two lines of the win bubble.
##
## Must be @tool, and no test here may be a coroutine.

const _THEME := "res://Assets/Theme/kejartes_theme.tres"
const _WIN_SCREEN := "res://Scenes/Minigames/UI/MinigameWinScreen.tscn"
const _STUDENTS := ["Marcel", "Doni", "Andi", "Citra", "Shinta", "Thea"]
const _STUDENT_EVENTS := ["les_akademis", "Badminton", "Menjodohkan", "Variabel",
	"PilihanGanda", "Password", "BuatBatik", "LombaMenari"]
const _NPC_EVENTS := ["nasi_kotak", "hujan", "latihan_olahraga", "workshop_seni", "MainBola"]
const _CATEGORIES := ["Akademis", "SeniBudaya", "Olahraga"]
const _MIN_LINES := 5
## Chat spellings and loanwords KBBI does not list (spec, "Language rules").
const _BANNED := ["nggak", "gak", "ga", "udah", "dah", "aja", "pengen", "makasih",
	"gimana", "workshop", "ngerjain", "nyelesaiin", "bikinin", "asik", "gue", "lu"]


func suite_name() -> String:
	return "event_dialogue_lines"


func _assert_pool(pool: Variant, what: String) -> void:
	assert_true(pool is Array, what + " has a pool")
	if not pool is Array:
		return
	assert_true((pool as Array).size() >= _MIN_LINES, "%s has %d lines, needs %d" % [what, pool.size(), _MIN_LINES])
	var seen := {}
	for line in pool:
		assert_false(seen.has(line), what + " repeats: " + str(line))
		seen[line] = true


## [what, line, is_student, is_win] for every line in every pool.
func _every_line() -> Array:
	var out: Array = []
	for key in EventDialogueLines.STUDENT_LINES:
		for who in EventDialogueLines.STUDENT_LINES[key]:
			for l in EventDialogueLines.STUDENT_LINES[key][who]:
				out.append(["%s/%s" % [key, who], str(l), true, false])
	for key in EventDialogueLines.NPC_LINES:
		for l in EventDialogueLines.NPC_LINES[key]:
			out.append([key, str(l), false, false])
	for who in EventDialogueLines.WIN_STUDENT_LINES:
		for cat in EventDialogueLines.WIN_STUDENT_LINES[who]:
			for l in EventDialogueLines.WIN_STUDENT_LINES[who][cat]:
				out.append(["win/%s/%s" % [who, cat], str(l), true, true])
	for cat in EventDialogueLines.WIN_TEACHER_LINES:
		for l in EventDialogueLines.WIN_TEACHER_LINES[cat]:
			out.append(["win/guru/" + cat, str(l), false, true])
	return out


# ── coverage ─────────────────────────────────────────────────────────────────

func test_every_student_has_a_pool_for_every_event() -> void:
	for key in _STUDENT_EVENTS:
		for who in _STUDENTS:
			_assert_pool(EventDialogueLines.STUDENT_LINES.get(key, {}).get(who), "%s/%s" % [key, who])


func test_every_npc_event_and_the_narrator_have_a_pool() -> void:
	for key in _NPC_EVENTS:
		_assert_pool(EventDialogueLines.NPC_LINES.get(key), key)


func test_every_student_has_a_win_pool_per_category() -> void:
	for who in _STUDENTS:
		for cat in _CATEGORIES:
			_assert_pool(EventDialogueLines.WIN_STUDENT_LINES.get(who, {}).get(cat), "win/%s/%s" % [who, cat])


func test_both_teachers_have_a_win_pool() -> void:
	for cat in ["Olahraga", "SeniBudaya"]:
		_assert_pool(EventDialogueLines.WIN_TEACHER_LINES.get(cat), "win/guru/" + cat)


func test_pools_only_name_real_events() -> void:
	for key in EventDialogueLines.STUDENT_LINES:
		assert_eq(EventDialogueCatalog.entry(key).get("speaker", ""), EventDialogueCatalog.SPEAKER_STUDENT, key)
	for key in EventDialogueLines.NPC_LINES:
		assert_true(EventDialogueCatalog.has_entry(key), key)
		assert_ne(EventDialogueCatalog.entry(key).get("speaker", ""), EventDialogueCatalog.SPEAKER_STUDENT, key)


# ── language ─────────────────────────────────────────────────────────────────

func test_every_line_is_plain_ascii() -> void:
	for row in _every_line():
		var line: String = row[1]
		for i in line.length():
			if line.unicode_at(i) > 0x7E:
				assert_true(false, "%s: non-ASCII in %s" % [row[0], line])
				break


func test_no_line_uses_a_banned_form() -> void:
	var rx := RegEx.create_from_string("(?i)\\b(" + "|".join(_BANNED) + ")\\b")
	for row in _every_line():
		var hit := rx.search(row[1])
		assert_true(hit == null, "%s: '%s' in %s" % [row[0], hit.get_string() if hit else "", row[1]])


func test_students_never_name_themselves_and_mom_always_names_the_child() -> void:
	for row in _every_line():
		if row[2]:
			assert_false(str(row[1]).contains("{nama}"), "%s: %s" % [row[0], row[1]])
	for l in EventDialogueLines.NPC_LINES.get("nasi_kotak", []):
		assert_true(str(l).contains("{nama}"), "nasi_kotak: " + str(l))


func test_every_choice_line_asks() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		if EventDialogueCatalog.entry(key)["mode"] != EventDialogueCatalog.MODE_CHOICE:
			continue
		var pools: Array = [EventDialogueLines.NPC_LINES.get(key, [])]
		pools.append_array(EventDialogueLines.STUDENT_LINES.get(key, {}).values())
		for pool in pools:
			for l in pool:
				assert_true(str(l).ends_with("?"), "%s: %s" % [key, l])


# ── fit ──────────────────────────────────────────────────────────────────────

func test_event_lines_fit_the_box() -> void:
	for row in _every_line():
		if not row[3]:
			assert_true(str(row[1]).length() <= EventDialogueCatalog.MAX_EVENT_LINE_CHARS,
				"%s is %d chars: %s" % [row[0], str(row[1]).length(), row[1]])


func test_win_lines_wrap_to_two_lines_of_the_bubble() -> void:
	var theme := ResourceLoader.load(_THEME, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var font := theme.get_font("font", "MinigameWinLine")
	var size := theme.get_font_size("font_size", "MinigameWinLine")
	var box := theme.get_stylebox("panel", "MinigameWinBubble")
	var screen := (load(_WIN_SCREEN) as PackedScene).instantiate()
	var bubble := screen.get_node("Root/Bubble") as Control
	var width := 1080.0 - bubble.offset_left + bubble.offset_right - box.content_margin_left - box.content_margin_right
	screen.free()
	var limit := font.get_height(size) * 2.0 + 1.0
	for row in _every_line():
		if row[3]:
			var h := font.get_multiline_string_size(str(row[1]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, width, size).y
			assert_true(h <= limit, "%s wraps past 2 lines: %s" % [row[0], row[1]])
```

- [ ] **Step 2: Run it**

Run a no-op `script_patch` on the new file, then
`test_run(suite="event_dialogue_lines", session_id=…)`.
Expected: the four coverage tests FAIL (every pool is missing). The language
and fit tests PASS vacuously.

- [ ] **Step 3: Commit**

Message: `test(event-dialogue): the lines suite`.

---

### Content tasks (5-8): shared brief

Each content task fills part of `EventDialogueLines.gd`. Do these in every
content task:

- **Before writing.** Re-read the spec's Language rules and Voice sheets.
- **Scope.** Write only the named pools, in the file's existing format: one
  line per string, tab-indented, and a trailing comma on every element.
- **Keep the existing line.** Wherever a pool's speaker used to say the
  entry's current `line`, keep that line (or its KBBI-fixed form) as one of
  the five.
- **Variety.** Each pool's lines must differ in idea, not only in wording.
  Aim for 1 or 2 opening particles or exclamations per pool, never the same
  opener twice.
- **Length.** Keep lines short and speakable: most under 90 characters for
  events, and under 45 for win lines.
- **Checks.** Run a no-op `script_patch`, then `test_run(suite="event_dialogue_lines", …)`.
  Expected: the task's own coverage test and every language and fit test
  PASS. Other tasks' coverage tests may still fail.
- **Commit** as `feat(event-dialogue): <what> lines`.

**What each event is about** (so lines stay accurate):

| Key | Speaker | Situation |
|---|---|---|
| `les_akademis` | student, CHOICE | The school opens extra after-school tutoring; the student asks the player's permission to join. Every line ends in `?`. |
| `Menjodohkan` | student | Question cards and answer cards got shuffled; match each pair before time runs out. |
| `Variabel` | student | A number puzzle on the board: work out the value of each symbol. |
| `PilihanGanda` | student | A pop quiz of three multiple-choice questions. |
| `Password` | student | The class cupboard only opens when the sum is right. |
| `Badminton` | student | A badminton match. |
| `BuatBatik` | student | Batik making with cloth, canting, wax (*malam*) and dye; the steps must go in the right order. |
| `LombaMenari` | student | A dance contest: follow the rhythm, don't misstep. |
| `MainBola` | Guru Penjas, to the students | Penalty kick practice: kick hard, don't let the keeper catch it. |
| `latihan_olahraga` | Guru Penjas, to the player, CHOICE | The field is empty this afternoon; may {nama} and the others do extra practice with him? Ends in `?`. |
| `workshop_seni` | Guru Seni Budaya, to the player, CHOICE | The sanggar runs a batik and traditional-dance *lokakarya*; may {nama} and friends join? Ends in `?`. |
| `nasi_kotak` | Mom, to the player | She brings boxed rice to cheer {nama} and friends on. Every line contains `{nama}`. |
| `hujan` | narrator | Heavy rain and slippery roads; students arrive wet, slip, and are tired and gloomy. |

---

### Task 5: NPC, narrator and teacher win lines (35 lines)

**Files:** Modify `Scripts/SchoolSimulation/EventDialogueLines.gd` (`NPC_LINES`
and `WIN_TEACHER_LINES`).

**Interfaces:** Consumes Task 3's empty dictionaries and Task 4's suite.
Produces the full `NPC_LINES` (5 keys × ≥5 lines) and `WIN_TEACHER_LINES`
(2 keys × ≥5 lines).

- [ ] **Step 1: Write `NPC_LINES`** for `nasi_kotak`, `hujan`,
  `latihan_olahraga`, `workshop_seni` and `MainBola`, at least 5 lines each,
  in the voice sheets' Guru Penjas, Guru Seni Budaya, Mom and narrator voices.
  The current `workshop_seni` line changes to end in `?` and use *lokakarya*.
  Its KBBI-fixed form is:
  `"Sanggar seni sedang mengadakan lokakarya batik dan tari daerah. Boleh {nama} dan teman-temannya ikut bergabung?"`
- [ ] **Step 2: Write `WIN_TEACHER_LINES`**, at least 5 each for `"Olahraga"`
  (Guru Penjas: dry praise, often with an extra lap) and `"SeniBudaya"`
  (Guru Seni Budaya: warm pride in the kids' work). Keep
  `"Kerja bagus! Latihannya berhasil."` and
  `"Indah sekali! Terima kasih sudah membimbing mereka."`.
- [ ] **Step 3: Check and commit** per the shared brief. Expected PASS:
  `test_every_npc_event_and_the_narrator_have_a_pool` and
  `test_both_teachers_have_a_win_pool`.

### Task 6: Student lines for the five Akademis events (150 lines)

**Files:** Modify `EventDialogueLines.gd` (`STUDENT_LINES` keys
`les_akademis`, `Menjodohkan`, `Variabel`, `PilihanGanda`, `Password`).

**Interfaces:** Produces `STUDENT_LINES[key][name]` for these 5 keys ×
6 students, at least 5 lines each.

- [ ] **Step 1: Write the pools**, one student at a time in voice-sheet
  order. Marcel and Shinta are in their specialty here. Doni, Andi, Citra and
  Thea react through their own lens:
  - Doni turns it into a competition.
  - Andi gets curious.
  - Citra is quiet and prefers working alone.
  - Thea keeps trying until it's perfect.
  Every `les_akademis` line asks permission and ends in `?`.
- [ ] **Step 2: Check and commit** per the shared brief. Expected: in
  `test_every_student_has_a_pool_for_every_event`, only the Task 7 keys
  still fail.

### Task 7: Student lines for Badminton, BuatBatik and LombaMenari (90 lines)

**Files:** Modify `EventDialogueLines.gd` (`STUDENT_LINES` keys `Badminton`,
`BuatBatik`, `LombaMenari`).

**Interfaces:** Produces `STUDENT_LINES[key][name]` for these 3 keys ×
6 students, at least 5 lines each.

- [ ] **Step 1: Write the pools.** Doni and Citra are in their specialty on
  Badminton, Andi and Thea on BuatBatik and LombaMenari. Citra is an athlete
  who dislikes crowds, so the dance contest is her hardest. Marcel reaches for
  what he has read, and Shinta jokes about getting out of it, then does it.
- [ ] **Step 2: Check and commit** per the shared brief. Expected:
  `test_every_student_has_a_pool_for_every_event` PASSES.

### Task 8: Student win lines (90 lines)

**Files:** Modify `EventDialogueLines.gd` (`WIN_STUDENT_LINES`).

**Interfaces:** Produces `WIN_STUDENT_LINES[name][category]` for 6 students ×
3 categories, at least 5 lines each.

- [ ] **Step 1: Write the pools.** Each is a thank-you or a whoop, addressed
  to "Pak", in the student's voice, reacting to that category's win. Keep
  them short: they are shown uppercase in Boohong, and at most two lines fit.
- [ ] **Step 2: Check and commit** per the shared brief. Expected: the whole
  `event_dialogue_lines` suite PASSES.

---

### Task 9: KBBI verification

**Files:** Modify `docs/superpowers/specs/2026-09-29-dialogue-variations-design.md`
(new `## Appendix: KBBI check`). Modify `EventDialogueLines.gd` only where a
word fails.

- [ ] **Step 1: List the distinct words.** `EventDialogueLines.gd` is plain
  source, so read it off disk with no editor involved. Run this in
  PowerShell from the worktree:

```powershell
$src = Get-Content "Scripts\SchoolSimulation\EventDialogueLines.gd" -Raw
$text = ([regex]::Matches($src, '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }) -join ' '
$words = [regex]::Matches($text.ToLower(), "[a-z]+(-[a-z]+)*") | ForEach-Object { $_.Value } | Sort-Object -Unique
$words | Set-Content "$env:TEMP\claude\dialogue-words.txt"
$words.Count
```

  The quoted strings also include dictionary keys (student names, event
  keys, categories). Drop those from the list by hand.
- [ ] **Step 2: Flag** every word that is not plainly standard vocabulary:
  every particle, every *cak.* candidate, every loanword, every reduplication
  and every clitic form (*kucatat, kulatih*).
- [ ] **Step 3: Look each flagged word up** on `https://kbbi.kemdikbud.go.id/entri/<word>`
  in the built-in browser (`get_page_text`). Record its label: *baku*, *cak.*,
  or not found. For a clitic or affixed form, look up the root.
- [ ] **Step 4: Replace every word that is not found**, re-run
  `event_dialogue_lines`, and write the appendix as a table
  (word | KBBI label | note).
- [ ] **Step 5: Commit** as `docs(dialogue): the KBBI check`.

---

### Task 10: Live check, docs, ship

**Files:** Modify `docs/superpowers/CHANGELOG.md` and `CLAUDE.md` (the loop
paragraph).

- [ ] **Step 1: Live check** in the worktree editor. Follow CLAUDE.md
  "Working efficiently here" item 1: seed the playtest state, pass through
  Atur Jadwal, and use the Debug overlay's minigame launcher. Check these
  screens:
  - (a) The `workshop_seni` dialogue: the new Guru Seni Budaya art is framed
    like Guru Penjas, and a drawn line shows.
  - (b) A SeniBudaya win with the teacher speaking.
  - (c) An Akademis win with a student: the two-line bubble at full size,
    with its overlap on the speaker judged at 1080×1920 and 1080×2400.

  Freeze the reveal with `Engine.time_scale` (memory:
  freeze-game-time-for-screenshots). Revert
  `Assets/Audio/default_bus_layout.tres` afterwards.
- [ ] **Step 2: Docs.**
  - Add a CHANGELOG entry, newest first, summarising the pools, the picker,
    the bubble and the art.
  - In CLAUDE.md's loop paragraph, change "then an EventDialogue line
    (`EventDialogueCatalog`)" to "then an EventDialogue line
    (`EventDialogueCatalog`, drawn from `EventDialogueLines`)".
- [ ] **Step 3: Ship** with the `ship-pr` skill. It runs the full suite,
  reviews locally, opens the PR, and binds and stamps it.
