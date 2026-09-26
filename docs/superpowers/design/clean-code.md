# Clean code in KejarTes

How this project applies Codacy's clean-code principles
([What is clean code](https://blog.codacy.com/what-is-clean-code)) to
GDScript and Godot 4.6. Why each rule is shaped the way it is:
`docs/superpowers/specs/2026-09-26-clean-code-design.md`. The language
baseline is Godot's own
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
and [static typing guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html).

**⚙ = enforced** by the clean-code ratchet: `ci/clean_code_scan.gd`, run by
`tests/test_clean_code.gd` in the editor suite and by `ci/project_check.gd`
on every pull request and every push to `Textures`. The rest is review
guidance.

## The ratchet in one minute

- Today's debt is frozen in `ci/clean_code_baseline.gd` (generated). A count
  may only go **down**.
- **"grew"** means your change added debt. Fix the code: split the function,
  name the number, add the type. A reviewed, permanent exception goes in
  `ci/clean_code_allowed.gd`, with a comment saying why.
- **"shrank"** means you improved something. Lock it in, in the same commit:

      <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd

  then check that `git diff ci/clean_code_baseline.gd` only lowers numbers or
  removes entries. (The editor suite fails on an un-locked shrink; CI only
  prints a `WARNING:`.)
- A **new** script has no baseline, so it is clean from its first commit.
- Never raise a baseline number by hand.
- **`Textures` went red on the ratchet** (a hand-merged change): whoever landed
  it fixes it; failing that, the next session to run `ship-pr` fixes it as
  its first commit — for a shrink, run the dump tool; for a growth, fix the
  code (or add a commented `ci/clean_code_allowed.gd` entry) and tell the
  user.

## 1. Names say what a thing is ⚙

- Casing: `snake_case` functions and variables, `PascalCase` classes and
  node names, `CONSTANT_CASE` constants and enum values.
- Signals are past-tense events: `week_finished`, `item_bought`. Booleans
  read as questions: `is_locked`, `has_item`, `can_afford`.
- No numbered stand-ins (`value2`) and no `data`, `tmp`, `obj`, `x2`.
- Game words in Indonesian, engine and system code in English; match the
  file you are in.

```gdscript
# Before
var d = GameState.approved_students[i]
signal done
var check := true

# After
var student: Dictionary = GameState.approved_students[index]
signal week_finished
var is_locked := true
```

**File names ⚙:**

| What | Rule | Example |
|---|---|---|
| `.gd`, `.tscn` | PascalCase | `Lobby.gd`, `Lobby.tscn` |
| Script with `class_name X` | named `X.gd` | `TutorialStepData.gd` |
| A scene and its own root script | share one name | `StudentCard.tscn` + `StudentCard.gd` |
| A script shared by several scenes | named for its class | `StudentFace.gd` drives `AndiFace.tscn`, … |
| Assets | only `A–Z a–z 0–9 _ - .`; new art in `snake_case` | `kanan_atas.png` |
| Tests | `tests/test_<topic>.gd` (the runner needs it) | `tests/test_lobby.gd` |

**Every `res://` literal must match the file's exact case ⚙.** Windows
ignores case, so a wrong-case path works in the editor and breaks on Android
and in Linux CI. A formatted path (`"res://Assets/Images/X/%s.png"`) is
checked by its folder.

## 2. No magic numbers ⚙

A number that means something gets a name.

```gdscript
# Before
if student.energy <= 5:
	_force_izin(student)

# After
## Energy at or below this forces "Izin", a forced Istirahat day.
const IZIN_ENERGY_THRESHOLD := 5.0

if student.energy <= IZIN_ENERGY_THRESHOLD:
	_force_izin(student)
```

- Logic constants → a `const` block at the top of the script that owns the
  behaviour (like `RunGrade.gd`'s `WEIGHT_*`). A local `const` inside a
  function also names its number.
- Anything a designer tunes → an `@export` with a `##` line.
- Layout numbers (positions, sizes, margins) → the `.tscn`, not code (the
  authoring guide's "no visual is built at runtime").
- Simulation tuning → `Scripts/Balance.gd`, which a collaborator owns:
  propose the change, never edit it.
- Fine inline: `0`, `1`, `2`, `-1`, `0.5`.

## 3. One job per function ⚙

A function does one thing, and its name says which. Engine callbacks read
like a table of contents:

```gdscript
func _ready() -> void:
	_bind_nodes()
	_apply_visual_exports()
	_populate_roster()
	_start_tutorial_if_needed()
```

Over **50** code lines is a warning sign; over **100** is debt. The ratchet
tracks every function over 50 by name. Split with "extract function": move a
step into its own function named for what it does, change no logic.

## 4. Flat, not nested

Guard clauses and early `return` instead of if-pyramids; `match` for a
switch on an enum or a string.

```gdscript
# Before
func _on_buy_pressed(item: ItemData) -> void:
	if item != null:
		if GameState.player_money >= item.price:
			_buy(item)

# After
func _on_buy_pressed(item: ItemData) -> void:
	if item == null or GameState.player_money < item.price:
		return
	_buy(item)
```

**Repeat an awaiting step with a loop, never recursion.** A coroutine that
calls itself never unwinds; SchoolDay's `_run_day()` overflowed the stack
this way on 2026-08-30.

```gdscript
# Before
func _run_day() -> void:
	await _simulate(current_day)
	current_day += 1
	_run_day()

# After
func _run_week() -> void:
	for day in DAYS_PER_WEEK:
		await _simulate(day)
```

## 5. Don't repeat yourself — the Godot way ⚙

Pick the tool by what repeats:

| Repeats | Becomes | Examples here |
|---|---|---|
| Behaviour **with** visuals | one component scene, instanced where needed (composition first) | `TutorialPanel.tscn`, `StatBar`, `RosterCard` |
| Behaviour **without** visuals | a `class_name` base class, or a static helper | `BaseMinigame`, `Juice`, `AnimUtils` |
| A cross-cutting service | an autoload — and never re-implement one | `UIPolish` already juices every Button |

The ratchet lists every function body (5+ code lines) that is identical in
two or more files; a new one fails.

## 6. Engine logic: signals up, calls down

A child **announces** with a signal and never reaches into its parent; a
parent **calls** its children.

```gdscript
# The row (child): announces, never reaches up.
signal picked(student_id: int)

func _on_pressed() -> void:
	picked.emit(student_id)

# The screen (parent): listens, and calls down.
func _add_row(student: Dictionary) -> void:
	var row: RosterCard = ROW_SCENE.instantiate()
	row.picked.connect(_on_row_picked)
	rows.add_child(row)
	row.setup(student)
```

- Never `get_parent().get_parent()._refresh()`, and never
  `get_node("/root/Lobby/...")` from another screen.
- Take node references once, at the top:
  `@onready var roster: VBoxContainer = %Roster`. Give every node a script
  touches a unique name (`%`), so moving it in the scene does not break the
  script.
- Autoloads are services and state, not a shortcut between screens.
  `GameState` is the only source of truth; do not keep copies of it that go
  stale.

## 7. Type everything ⚙

```gdscript
var count := 0                                  # obviously an int
var students: Array[StudentData] = []
@onready var title: Label = %Title

func gain_for(student: StudentData, category: String) -> float:
	var entry: Dictionary = table[category]     # Variant on the right: name the type
	return float(entry["gain"])
```

Typed GDScript is checked when the script loads (a typo fails at once, not
mid-game), runs faster, and completes better in the editor. Use `:=` only
when the right-hand side's type is obvious. The ratchet counts untyped
`var`s, functions without `->` and untyped parameters. When the count reaches
zero, Godot's own `untyped_declaration` warning gets turned on.

## 8. Comments explain why

- Every script has a `##` file header and every `@export` a `##` line
  (enforced by `tests/test_script_documentation.gd`; the authoring guide's
  "The documentation standard").
- Say *why* — the trap, the constraint, the reason for an odd choice. Do not
  restate what the code says.
- No commented-out code: git remembers it.

## 9. Fail loudly

- A real problem → `push_error()` / `push_warning()`; a programmer mistake
  → `assert()` (stripped from release builds).
- A missing node that means the scene is broken is an error, not a silent
  skip:

```gdscript
var bar := card.get_node_or_null("Mood") as StatBar
if bar == null:
	push_error("StudentCard: the Mood bar is missing from the card scene")
	return
```

- No leftover `print("DEBUG` outside `Scripts/Debug/`
  (`tests/test_project_hygiene.gd`).

## 10. Leave it cleaner (the Boy Scout rule)

A function you touch ends no longer, and no less typed, than you found it.
Name the bare numbers in it while you are there. The ratchet then makes the
improvement permanent.

## What is exempt

- `Scripts/Balance.gd` (collaborator-owned), `addons/`, `-REFERENCE-/`,
  `ci/` — from everything.
- `tests/` — only the legacy-stat-key and misspelled-name rules apply; long
  fixture data is fine, and test files keep their `test_*.gd` names.
- Permanent, reviewed exceptions: `ci/clean_code_allowed.gd`.

Formatting is not ratcheted: match the file (tabs; the GDScript style
guide's spacing).
