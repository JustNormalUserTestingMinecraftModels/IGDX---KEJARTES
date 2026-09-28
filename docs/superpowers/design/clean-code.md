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

- Today's debt is frozen in `ci/clean_code_baseline.gd` (generated; never
  edit it by hand). A count may only go **down**.
- **"grew"** means your change added debt. Fix the code: split the function,
  name the number, add the type. Reviewed, permanent exceptions exist only
  where `ci/clean_code_allowed.gd` has a list: a whole file's long functions,
  size (large scripts) or bare numbers, and single `source: literal` pairs
  for unresolved paths — each with a comment saying why. Nothing else can be
  excepted. Listing a file turns its baseline entries into "shrank", so run
  the dump afterwards.
- **"shrank"** means you improved something. Lock it in, in the same commit:

      <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd

  This default mode only ever lowers: if any entry would be added or raised
  it writes nothing, prints each as `RAISED (review):` and exits 1. Check that
  `git diff ci/clean_code_baseline.gd` only lowers numbers or removes
  entries. (The editor suite fails on an un-locked shrink; CI only prints a
  `WARNING:`.) An open editor keeps serving the old baseline until a no-op
  `script_patch` of it (CLAUDE.md, "Working efficiently here", item 5).
- **Moved, renamed or split** a script or function that carries debt? Its
  entries are keyed by path and name, so CI reports the new key as "grew" and
  the old one as "shrank". Re-key the baseline:

      <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd -- --rekey

  It writes every entry and prints the RAISED lines as warnings; put them in
  the PR description. The diff must show the same numbers under the new
  keys, and a split's pieces must each be smaller than the original.
- A **new** script has no baseline, so it is clean from its first commit.
- Never raise a baseline number by hand, and never re-key to hide new debt.
- **A merge conflict in `ci/clean_code_baseline.gd`:** never hand-merge it —
  a baseline that does not parse fails every check. Take one side whole
  (`git checkout --ours ci/clean_code_baseline.gd`, or `--theirs`), run the
  dump — with `-- --rekey` if the other side moved or renamed anything — and
  review the diff.
- **`Textures` went red on the ratchet** (a hand-merged change): whoever landed
  it fixes it; failing that, the next session to run `ship-pr` fixes it as
  its first commit — for a shrink, run the dump tool; for a growth, fix the
  code and tell the user.

## 1. Names say what a thing is

- Casing: `snake_case` functions and variables, `PascalCase` classes and
  node names, `CONSTANT_CASE` constants and enum values.
- Signals are past-tense events: `week_finished`, `item_bought`. Booleans
  read as questions: `is_locked`, `has_item`, `can_afford`.
- No numbered stand-ins (`value2`) and no `data`, `tmp`, `obj`, `x2`.
- **Legacy stat keys ⚙.** The numbered roster keys — `akademis[123]` and
  `kepribadian[12]`, in any case — count anywhere in a file's text:
  identifiers, strings and comments, in `.gd`, `.tscn` and `.tres` files (so
  their `target_…`, `base_…` and `…Icon` forms too). They are counted per
  file in `Scripts/`, `Scenes/` and `tests/`, and no file may gain one:
  adding one fails even in a file that already has them, and this rule has
  no ALLOWED list. The roster now uses `StudentData`'s field names
  (`akademis`, `seni_budaya`, `olahraga`, `mood`, `energy`); this rule keeps
  the old keys from coming back.
- **Misspelled names ⚙.** No file or folder name under `Scripts/`,
  `Scenes/`, `Assets/` or `tests/` may carry a stem from `MISSPELLED_STEMS`
  in `ci/clean_code_scan.gd` — the misspellings of *lobby*, *koperasi* and
  *portrait* — in any case. File contents are not checked.
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

**File names** (⚙ = checked by the ratchet; "review" = review guidance):

| What | Rule | Example | Checked |
|---|---|---|---|
| `.gd`, `.tscn` in `Scripts/`, `Scenes/` | PascalCase | `Lobby.gd`, `Lobby.tscn` | ⚙ |
| Script with `class_name X` | named `X.gd` | `TutorialStepData.gd` | ⚙ |
| A scene and its own root script | share one name | `StudentCard.tscn` + `StudentCard.gd` | review |
| A script shared by several scenes | named for its class | `StudentFace.gd` drives `AndiFace.tscn`, … | review |
| Assets | only `A–Z a–z 0–9 _ - .`; new art in `snake_case` | `kanan_atas.png` | ⚙ characters; `snake_case` review |
| Tests | `tests/test_<topic>.gd` | `tests/test_lobby.gd` | the test runner needs it |

**Every `res://` literal in `Scripts/`, `Scenes/` and `project.godot` must
match the file's exact case ⚙.** Windows ignores case, so a wrong-case path
works in the editor and breaks on Android and in Linux CI. A formatted path
(`"res://Assets/Images/X/%s.png"`) is checked by its folder.

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

**Large scripts ⚙.** A script over **1,000** lines is listed in the
baseline's `LARGE_SCRIPTS` and may not grow past its listed count — blank
and comment lines count too — and no other script may cross 1,000. Put new
behaviour in a new script or component, which starts at zero debt.

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

The ratchet lists every function body (5+ code lines, each line trimmed,
comments-only lines dropped) that is identical in two or more files; a new
one fails.

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
`var`s, and column-0 functions without `->` or with untyped parameters
(lambdas are not counted; see "What is exempt"). When the count reaches
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
- Methods of inner classes (`class X:`) are not measured; there are none with
  functions today.
- Property accessors — the `get:` / `set(value):` blocks under a `var` — and
  class-level lambdas are not functions to the ratchet: no long-function,
  bare-number or duplicate count reads them, and their parameters are not
  counted as untyped. They are still part of the script: an untyped `var`
  declared inside one counts toward the script's untyped total, and their
  lines count toward its length (large scripts).
- Lambda signatures (`func(...)`) are not counted by the untyped
  measurement; a lambda's body counts toward the enclosing function's lines
  and bare numbers.
- Permanent, reviewed exceptions: `ci/clean_code_allowed.gd` (its four lists
  only).

Formatting is not ratcheted: match the file (tabs; the GDScript style
guide's spacing).
