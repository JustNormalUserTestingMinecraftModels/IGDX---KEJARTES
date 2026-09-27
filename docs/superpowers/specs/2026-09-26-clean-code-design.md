# Clean code for KejarTes — design

**Date:** 2026-09-26
**Status:** approved in brainstorming, section by section; revised after an
independent spec review in four rounds (round 1: 6 blocking, 12 non-blocking;
round 2: 3 blocking, 6 non-blocking; round 3: 1 blocking, 5 non-blocking;
round 4: approved, 2 wording fixes; all addressed)
**Source:** Codacy, "What is clean code"
(https://blog.codacy.com/what-is-clean-code), translated to GDScript and
Godot 4.6.
**Backup taken first:** `../backups/2026-09-26-pre-clean-code/` beside the
project folder (zip with `.git`, git bundle, uncommitted worktree patches,
`user://` saves; restore steps in its `README.txt`).

## Goal

Make the game's code clean, and keep it clean:

1. **Rules** — a written GDScript/Godot clean-code standard for this project.
2. **Guardrails** — a ratchet check, run in the editor suite *and* in CI,
   that freezes today's mess so it can only shrink.
3. **Hotspot fixes** — file renames, the stat-key rename, duplicate removal,
   and splitting the longest functions.

Behaviour does not change anywhere in this work. Every step is a refactor.

## What was measured (2026-09-26, 166 production scripts)

Numbers are approximate; PR1 records the exact baselines.

| Codacy principle | Finding |
|---|---|
| Meaningful names | Dict keys and node names `akademis2` (= seni budaya) and `kepribadian1` (= mood) disagree with `StudentData`'s real field names: ~1,180 occurrences in 48 files, the project's #1 bug source per CLAUDE.md. Misspelled `loby` (scripts, scenes, BGM, backdrops), `koprasi`, folder `MuridPotrait`; 19 scripts and 14 scenes are snake_case in a PascalCase codebase (147 scripts). |
| No hard-coded values | ~2,700 bare numeric literals inside function bodies. |
| Single responsibility / short functions | 106 functions over 50 lines, 24 over 100. Six scripts over 1,000 lines. |
| DRY | The tutorial flow is copy-pasted into 4 screens (and has drifted); `report_card.gd` is a fork of `student_card.gd`; 22 function bodies are byte-identical across files. |
| Comments | `##` docs already enforced by `tests/test_script_documentation.gd`. |
| Language standards | 1,397 untyped `var`s and 223 functions without `->` (1,620 before counting parameters). No GDScript warnings enabled in `project.godot`. |
| Continuous refactoring | The ratchet pattern already exists (`tests/test_viewport_editability.gd`). |

## Decisions made with the user

| Question | Decision |
|---|---|
| What to produce | Rules + ratchet + hotspot fixes + tidy file names. |
| File-name scope | Fix misspellings and junk names, and move the snake_case scripts and scenes to PascalCase. Not a project-wide snake_case conversion. |
| Stat keys | Rename to the real names (`seni_budaya`, `mood`, …). |
| Approach | A: guardrails first, then one small PR per kind of change. |
| Verification | Every PR loops test → independent reviewer agent → fix until clean. |

Rejected: one big cleanup branch (unreviewable, conflict magnet), and an
external linter (`gdtoolkit`: reformats every file, lags Godot 4.x syntax,
adds a Python CI dependency, duplicates what the ratchet does).

---

## 1. The rulebook

A new file, `docs/superpowers/design/clean-code.md`, beside the style guide and
authoring guide. CLAUDE.md gains one pointer line to it. **⚙** marks a rule the
ratchet (section 2) enforces; the rest are review guidance.

1. **Names say what a thing is.** GDScript style-guide casing: `snake_case`
   functions and variables, `PascalCase` classes and nodes, `CONSTANT_CASE`
   constants. Signals in the past tense (`week_finished`); booleans read as
   questions (`is_locked`, `has_item`). No numbered stand-ins (`akademis2`) and
   no `data`/`tmp`/`x2`. Indonesian for game words, English for engine and
   system code, as today. File names: PascalCase `.gd` and `.tscn`; a script
   with a `class_name` is named after it; a scene with its own dedicated root
   script shares that script's name (a script shared by many scenes, like
   `StudentFace.gd`, is named for its class); asset names use only
   `A–Z a–z 0–9 _ - .`; no misspelled file or folder names.
   ⚙ file names ⚙ legacy stat keys ⚙ literal paths resolve.
2. **No magic numbers.** A number that means something is a named `const`;
   one a designer tunes is an `@export` with a `##` line. Layout numbers live
   in the `.tscn`, not in code (the existing "no visual built at runtime"
   rule). Trivial values (0, 1, −1, 2, 0.5) are fine inline. Simulation tuning
   is proposed to `Balance.gd`'s owner, never edited. ⚙
3. **One job per function.** Engine callbacks (`_ready`, `_process`, `_input`)
   read like a table of contents that calls named `_setup_*` / `_update_*`
   steps. Over 50 body lines is a smell; over 100 is debt. ⚙
4. **Flat, not nested.** Guard clauses and early `return`; `match` for
   enum/string switches. Repeat an awaiting step with a loop, never recursion
   (the 2026-08-30 `_run_day()` stack overflow).
5. **Don't repeat yourself, the Godot way.** Repeated behaviour *with* visuals
   → one component scene, instanced where needed (composition first).
   Repeated behaviour *without* visuals → a `class_name` base class or a static
   helper (`Juice`, `AnimUtils`). Never re-implement an autoload's job. ⚙
6. **Engine logic: signals up, calls down.** A child emits signals and never
   reaches into its parent; a parent calls its children. Node references are
   taken once (`@onready var x: T = %Name`), never re-looked-up by string path
   mid-function. Autoloads are services and state, not a shortcut between
   screens. `GameState` stays the only source of truth.
7. **Type everything.** Typed variables, parameters and returns; typed arrays
   (`Array[StudentData]`); `:=` only when the right-hand type is obvious.
   Typed GDScript is checked at load time and runs faster. ⚙ When the untyped
   count reaches zero, turn on Godot's `untyped_declaration` warning so the
   engine enforces it (not reached in this project).
8. **Comments explain why.** `##` docs stay mandatory. Do not restate the
   code; no commented-out code (git remembers).
9. **Fail loudly.** `push_error` / `push_warning` for real problems,
   `assert()` for programmer mistakes. A missing node that means the scene is
   broken is an error, not a silent `if node:` skip. No leftover debug
   `print` (already enforced by `test_project_hygiene`).
10. **Leave it cleaner (Boy Scout rule).** A function you touch ends no longer
    and no less typed than you found it; the ratchet makes each gain
    permanent. A **new** script starts at zero debt: it has no baseline, so it
    must be fully clean.

Formatting is not ratcheted: match the file (tabs; GDScript style guide
spacing).

**Exempt from everything:** `Scripts/Balance.gd` (collaborator-owned),
`addons/`, `-REFERENCE-/`, `ci/`. **`tests/`** is scanned only by the legacy-stat-key
rule (identifiers and strings) and the misspelled-name rule; test file names
stay `test_*.gd` (the runner needs them), and the metrics do not apply, so
long fixture data is fine.

## 2. The ratchet (PR1)

**One scanner, two runners.** The scan lives in `ci/clean_code_scan.gd` (pure
text: `FileAccess`/`DirAccess` only, no autoloads, no scenes), with its
baselines in `ci/clean_code_baseline.gd` (`const` dicts). Two things run it:

- `tests/test_clean_code.gd` in the editor suite, built like
  `tests/test_viewport_editability.gd`: `@tool`, no coroutine tests, no scene
  instancing — milliseconds, so it never drops the MCP bridge.
- `ci/project_check.gd`, which already runs headless on every pull request and
  every push to `Textures`. It calls the scanner and reports **growth** and
  **must-be-zero** violations as `PROJECT CHECK FAIL:` lines (exit 1); a
  **shrink** is printed as a `WARNING:` line, which the workflow already copies
  into the step summary without failing. So CI reports regressions on
  everyone's changes, including the collaborator's, without editing a workflow
  file (which would block auto-merge). It *reports*; it cannot block a hand
  merge, because the repo has no branch protection.

Shrink-as-failure lives only in the editor suite. A shrink that lands by hand
merge therefore turns the next `ship-pr` suite red on the tighten check —
the same exposure `test_viewport_editability` already has. A red ratchet on
`Textures` is fixed by whoever landed it; failing that, the next session to
run `ship-pr` fixes it as its first commit — for a shrink, paste the printed
literal; for a growth (which makes every later PR's `project-check` red,
because CI tests each PR merged with `Textures`), fix the code or add a
commented baseline entry, and tell the user.

`ci/clean_code_scan.gd` is `@tool`, following `project_check.gd`'s precedent,
so the editor suite can call its static helpers. Shrinks never enter
`project_check.gd`'s `failures` array (which drives `quit(1)`) and never go
through `push_error`.

**CI selftest.** `ci/selftest_project_check.sh` plants broken files to prove
each check fails. Its parse and missing-dependency fixtures today live in
`Scripts/` and `Scenes/`, where the scan would flag them first (untyped
signature, unresolved literal path), so those cases would pass for the wrong
reason. PR1 moves both fixtures to the project root beside
`zz_selftest_autoload.gd` — outside every scanned root, while
`collect_files("res://")` still loads them — gives `run_check` an
expected-output pattern (`script has errors`, `missing dependency`,
`selftest: autoload failed on boot`, the scan's rule name) so each case
fails for the reason it tests, and adds a planted scan-violation case in
`Scripts/`.

**Mechanics.** Per measurement, a `BASELINE` of today's counts and two checks:
one fails when a count **grows** (the message names the file, the rule and
`clean-code.md`); one fails when a count **shrinks** without its baseline
being lowered, and prints the exact literal to paste back (editor suite only;
CI prints a `WARNING:` instead). `ALLOWED` is keyed
**per measurement** and holds reviewed, commented, permanent exceptions —
e.g. `ThemeFactory.gd` for long functions, large-script size and bare numbers,
because CLAUDE.md requires every new theme variation to be added there and
its `_build_*` functions are declarative style tables.

**Scope:** `res://Scripts/**/*.gd` minus the exemptions in section 1.
**Function bodies** are found by one function-range scanner. A function
starts at a column-0 `func` or `static func`; lambdas (`func(`) belong to the
enclosing body. A **signature** runs from `func` to the `:` that closes it at
parenthesis depth 0; 37 signatures span several lines today. An unclosed `(`
ends the signature at end of file — never a crash. The **body** runs from the
end of the signature to the next top-level statement. Class-level
`const`/`var` tables are never part of a function body, however they are
indented.

**Ratcheted measurements:**

| Measurement | Definition | Baseline form | Today |
|---|---|---|---|
| Long functions | Body lines that are neither blank nor comment-only. | `{"res://path::func": body_lines}` for every function over 50. A listed function may not grow; an unlisted one may not exceed 50. Any shrink updates the baseline. The PR6+ finish line is visible here: no entry over 100 outside `ALLOWED`. | ~106 |
| Untyped declarations | `var` declarations with neither `: Type` nor `:=`; signatures without `->`; parameters without `: Type`. `for` loop variables are not counted. | `{path: count}` | ~1,620 + parameters |
| Bare numbers | Numeric literals inside function bodies, after stripping strings and comments, other than `0 1 2 0.5 0.0 1.0 2.0`. | `{path: count}` | ~2,700 |
| Duplicate bodies | Function bodies of 5+ non-blank, non-comment lines that are identical (whitespace-normalised) in two or more files. | A list of today's groups (sorted `path::func` members). A new group fails. | 22 groups |
| Large scripts | Scripts over 1,000 total lines. | `{path: line_count}`. A listed script may not grow past its baseline; no other script may cross 1,000. The shrink check fires only when a listed script drops to 1,000 lines or fewer — not on every line removed. | 6 |

**Must-be-zero rules** (baselined with today's offenders; each empties when
its PR lands and stays empty):

| Rule | Checked over | Emptied by |
|---|---|---|
| `.gd` / `.tscn` base names match `^[A-Z][A-Za-z0-9]*$` | `Scripts/`, `Scenes/` | PR2 |
| A script with `class_name X` is named `X.gd` | `Scripts/` | PR2 |
| Asset base names use only `A–Z a–z 0–9 _ - .` | `Assets/` | PR2 |
| No file or **folder name** contains `loby`, `koprasi` or `Potrait` (any case). File contents are not scanned — constants like `KOPRASI_GD` may stay until their code is touched. | `Scripts/`, `Scenes/`, `Assets/`, `tests/` | PR2 |
| Every literal `res://` path names a file **or folder** that exists **with exact case**, checked against `DirAccess` listings because Windows ignores case (Linux CI and Android do not). A leading `*` (the autoload form in `project.godot`) is stripped. A formatted literal (containing `%` or `{`) is checked by its static prefix: the part up to the last `/` before the first `%`/`{` must be an existing folder. This rule has its own `ALLOWED` list for paths that are intentionally optional — e.g. `BaseMinigame.gd`'s `res://Assets/Images/pause_button.png`, guarded by `ResourceLoader.exists` — each with a comment. | `Scripts/`, `Scenes/`, `project.godot` | PR2 |
| No `akademis[123]` / `kepribadian[12]`, any case, inside any identifier or string | `Scripts/`, `Scenes/`, `tests/` | PR3 |

The scanner builds its misspelling and stat-key patterns by string
concatenation so it never matches its own source; so do
`tests/test_clean_code.gd`'s fixtures, since `tests/` is scanned too. Audio's camelCase names
(`cardFlip.ogg`) and font vendor names (`OpenSans-Bold.ttf`) pass the
character rule and are left as they are.

## 3. File renames (PR2)

**Scripts and scenes → PascalCase**, a scene and its dedicated root script
sharing one name:

| From | To |
|---|---|
| `Scripts/Lobby/loby.gd`, `Scenes/Lobby/loby.tscn` | `Lobby.gd`, `Lobby.tscn` |
| `Scripts/Koperasi/koprasi.gd`, `Scenes/Koperasi/koprasi.tscn` | `Koperasi.gd`, `Koperasi.tscn` |
| `Scripts/Koperasi/rakbarang_1.gd` | `KoperasiStage.gd` (the koperasi's Stage script) |
| `Scripts/Achievements/achievements_screen.gd`, `Scenes/Achievements/achievements.tscn` | `AchievementsScreen.gd`, `AchievementsScreen.tscn` |
| `Scripts/AturJadwal/atur_jadwal.gd`, `Scenes/AturJadwal/atur_jadwal.tscn` | `AturJadwal.gd`, `AturJadwal.tscn` |
| `Scripts/StudentCard/student_card.gd`, `Scenes/StudentCard/student_card.tscn` | `StudentCard.gd`, `StudentCard.tscn` |
| `Scripts/StudentList/student_list.gd`, `Scenes/StudentList/student_list.tscn` | `StudentList.gd`, `StudentList.tscn` |
| `Scripts/ReportCard/report_card.gd`, `Scenes/ReportCard/report_card.tscn` | `ReportCard.gd`, `ReportCard.tscn` |
| `Scripts/LevelSelect/level_select.gd`, `Scenes/LevelSelect/level_select.tscn` | `LevelSelect.gd`, `LevelSelect.tscn` |
| `Scripts/MainMenu/main_menu.gd`, `Scenes/MainMenu/main_menu.tscn` | `MainMenu.gd`, `MainMenu.tscn` (the main scene) |
| `Scripts/CutScene/cut_scene.gd`, `Scenes/CutScene/cut_scene.tscn` | `CutScene.gd`, `CutScene.tscn` |
| `Scripts/CutScene/hint_label.gd` | `HintLabel.gd` |
| `Scripts/Koperasi/cosmetic_shop.gd`, `shop_hub.gd`, `shop_hub_tile.gd` | `CosmeticShop.gd`, `ShopHub.gd`, `ShopHubTile.gd` |
| `Scripts/StudentCard/tutorial_step.gd` | `TutorialStepData.gd` (its `class_name`) |
| `Scenes/Audio/audio_director.tscn` | `AudioDirector.tscn` |
| `Scripts/Inventory/inventory.gd`, `Scenes/Inventory/inventory.tscn` | `Inventory.gd`, `Inventory.tscn` — case-only |
| `Scripts/Transition/transition.gd`, `Scenes/Transition/transition.tscn` | `Transition.gd`, `Transition.tscn` — case-only (an autoload) |
| `Scripts/Splashscreen/splashscreen.gd` | `Splashscreen.gd` — case-only |
| `Scripts/Inventory/item_database.tscn` | **deleted** — unreferenced (its uid appears only in itself) |

**Assets:**

- Folder `Assets/Images/MuridPotrait/` → `Assets/Images/MuridPortrait/`
  (118 tracked files).
- `loby` → `lobby`: `Assets/Audio/BGM/loby_song1..4.mp3` →
  `lobby_song1..4.mp3`; `Assets/Images/UI/loby.png` → `lobby.png`;
  `Assets/Images/UI/loby_no_tables.png` → `lobby_no_tables.png` (plus
  `BGM/CREDITS.md`).
- Spaces → underscores: `Meja/kanan atas.png`, `kanan bawah`, `kiri atas`,
  `kiri bawah`; `Shop/ItemRak/bank soal.png`, `lompat tali`, `pop es`.
- `Assets/Images/UI/pngwing.com (3).png` → `Assets/Images/UI/stamp_original.png`
  (the orange "ORIGINAL" approval stamp on StudentCard).
- **Delete** unreferenced junk and its `.import`s: `Shop/pngwing.com (2).png`,
  `Shop/pngwing.com (6).png`, `UI/pngwing.com (2|4|5).png`,
  `UI/Desain tanpa judul.png`, `UI/Screenshot 2026-08-02 104848.png`,
  `UI/—Pngtree—book icon vector_4358423.png`, `UI/Placeholders/Loby.png`,
  `Shop/rak 1.jpg`, `Shop/rak2.jpg` (DEBT.md already records the last two as
  unused; that entry is deleted). Each is re-checked for references (by path
  and by `uid://`) immediately before deletion — hits inside `-REFERENCE-/`
  do not count, since the prototype has its own `Asset/` folder; all stay recoverable from git
  and the backup.
- `-REFERENCE-/` is untouched.

**Method (Godot-specific):**

1. That worktree's Godot editor is closed for the move (CLAUDE.md 4b: an open
   editor writes its stale buffers back).
2. `git mv` each file together with its `.uid` / `.import` sidecar, so every
   UID is preserved and `uid://` references keep resolving. Case-only renames
   go in two steps (`inventory.gd` → temporary name → `Inventory.gd`): Windows
   ignores case, so git would otherwise miss the change, and it would work on
   the PC and break on Android.
3. Rewrite every **full** `res://` path (anchored, so `atur_jadwal.gd` never
   matches inside `test_atur_jadwal.gd`): scenes, scripts, tests, `.tres`,
   `project.godot` (autoloads, `run/main_scene`), `.claude/skills/`, and the
   live docs. Literal paths in code — `Transition.change_scene("res://…")`,
   `const LOBBY := "res://…"` — are covered, and afterwards the
   "literal paths resolve" rule proves none was missed.
4. Then grep, case-sensitively, every old **base name and stem** —
   `koprasi.tscn`, `cut_scene.tscn`, …, plus `MuridPotrait`, `loby_song`,
   `loby.png`, `loby_no_tables`, `Meja/kanan atas`, `pngwing.com (3)` — to
   catch mentions without a full `res://` path, including formatted paths
   such as `StudentSkins.gd`'s `"res://Assets/Images/MuridPotrait/%s.png"`.
   UI text that merely contains a word (e.g. "pojok kanan atas" in a
   dialogue line) stays. Negative source-scan assertions that name an old
   file (e.g. `tests/test_inventory.gd:73`, `tests/test_exam_progress.gd:67`)
   are rewritten by hand so they still test something.
5. **`.import` files are not hand-edited.** Their `dest_files` names hash the
   source path, so a moved asset needs a real reimport: launch the editor (or
   `godot --headless --import`) on the worktree, let it regenerate them,
   commit the result, and verify that every `uid=` line is unchanged.
6. Rescan, run `ci/project_check` (dependencies + the new scan), then the full
   suite.

**Docs:** historical specs, plans, handovers and `CHANGELOG.md` entries keep
the old names; they are records. Live docs are updated: CLAUDE.md,
`docs/superpowers/design/*.md`, `DEBT.md`, folder READMEs, `.claude/skills/`.
CLAUDE.md's "`loby.gd`, `koprasi.gd` are misspelled but load-bearing — do not
fix them" line is replaced by the naming rule. `Balance.gd`'s comments that
name `atur_jadwal.gd` are left as they are and the update is proposed to its
owner.

**What PR2 may contain (the reviewer checks against this list):** the
renames and deletions above; path-string and base-name edits; regenerated
`.import` files with unchanged `uid=` lines; baseline-dict key updates in
`ci/clean_code_baseline.gd` and `tests/test_viewport_editability.gd`, and
removal of the must-be-zero offender entries PR2 empties; live-doc
edits; the `DEBT.md` and `CHANGELOG.md` entries. Nothing else.
`git diff -M --stat` must show every moved file as a rename.

## 4. Stat-key rename (PR3)

One vocabulary for dicts, `StudentData` and node names:

| Old | Dict key / field | Node name / capitalised key |
|---|---|---|
| `akademis1` | `akademis` | `Akademis` |
| `akademis2` | `seni_budaya` | `SeniBudaya` |
| `akademis3` | `olahraga` | `Olahraga` |
| `kepribadian1` | `mood` | `Mood` |
| `kepribadian2` | `energy` | `Energy` |

**The full token table** (26 variants, all present today), replaced as exact
tokens, longest first — a `\b` match on the stem would miss
`target_akademis2` and `IconAkademis2`:

| Old tokens | New tokens |
|---|---|
| `akademis1/2/3`, `kepribadian1/2` | `akademis`, `seni_budaya`, `olahraga`, `mood`, `energy` |
| `Akademis1/2/3`, `Kepribadian1/2` | `Akademis`, `SeniBudaya`, `Olahraga`, `Mood`, `Energy` |
| `target_akademis1/2/3`, `target_kepribadian1/2` | `target_akademis`, `target_seni_budaya`, `target_olahraga`, `target_mood`, `target_energy` |
| `base_akademis1/2/3` | `base_akademis`, `base_seni_budaya`, `base_olahraga` |
| `roster_base_akademis1/2/3` | `roster_base_akademis`, `roster_base_seni_budaya`, `roster_base_olahraga` |
| `IconAkademis1/2/3`, `IconKepribadian1/2` | `IconAkademis`, `IconSeniBudaya`, `IconOlahraga`, `IconMood`, `IconEnergy` |

**Touches:** ~1,180 occurrences in 48 files — 21 scripts, 24 test files, and
the stat-bar nodes in `StudentCard.tscn`, `ReportCard.tscn` and
`AturJadwal.tscn` (with every node path, `%` unique name and animation track
that names them).

**Payoff:** the dict ↔ `StudentData` bridge
(`GameState.convert_to_student_data_array`,
`StudentManager.write_back_to_gamestate`) maps names to themselves; the
translation tables in `ApplyStudentRow.gd` and `DebugManager.gd` are
deleted; CLAUDE.md's "the naming does not line up" warning is removed.

**Method:**

1. Editor closed; scripted exact-token replacement from the table above.
2. **Before replacing, check collisions:** no renamed node lands beside a
   sibling of the same name (checked: none today), and no dict gains a
   duplicate key. Capitalised `Akademis`, `Olahraga`, `SeniBudaya` are also
   schedule-category names, so every dict keyed by capitalised strings
   (`StudentCardView`, `StatInfo`, …) is checked by hand.
3. **Meaning flips, handled by hand:** `tests/test_use_item_on_students.gd:43`
   asserts there is *no* `"mood"` key; `GameState.gd:442` treats
   `"mood"`/`"energy"` as dead keys; `tests/test_report_card.gd:88` asserts the
   source has no `"Akademis",`, which `ReportCard.gd`'s `CARD_ROW_ORDER` will
   contain. After the rename each of these means something else.
4. **Comments** are reviewed by hand after the replace (a mechanical pass
   garbles phrases like "akademis2/3").
5. Live docs that name the old keys are updated: CLAUDE.md,
   `docs/superpowers/design/authoring-guide.md` (its GameState doc example),
   `.claude/skills/gamecode/SKILL.md`.
6. The must-be-zero rule greps for leftovers.

No save migration: the roster is never written to disk, and `Balance.gd`
does not use these keys (checked). Lands after PR2, because it edits renamed
files.

## 5. Duplicates and long functions (PR4, PR5, PR6+)

**Behaviour is preserved.** Before a duplicate is touched, characterization
tests pin what each screen does today; they must stay green through the
refactor. Visual changes are checked with before/after screenshots at the same
state (debug seed + teleport), compared by the reviewer. Every component
extracted here is a new script, so it starts at zero debt (section 1, rule 10).

**PR4 — one `TutorialGuide` component replaces four copies** (Lobby,
StudentList, AturJadwal, StudentCard; about 7 functions each).

- The component owns the shared mechanics: spotlight highlight
  (`_highlight_multiple`, `_clear_highlight`), the `TutorialArrow`, the
  blinking prompt, panel positioning, tap-to-advance, and the existing
  `TutorialPanel` scene.
- Each screen keeps its own steps (`TutorialStepData` exports), its phases
  (Lobby 2, AturJadwal 3 plus an alternate step) and its ending, connected
  through the component's `step_shown(index)` and `finished` signals.
- The copies have drifted (`_show_step` is 41–63% similar between screens,
  `_end_tutorial` is screen-specific). Every visual difference becomes an
  `@export` knob set per screen, so no screen changes — the precedent set by
  `TutorialPanel`'s extraction (`tests/test_tutorial_panel.gd`).
- Runtime-built tutorial UI that moves into the component's scene also lowers
  `test_viewport_editability`'s baseline.

**PR5 — the remaining duplicates:**

| Duplicate | Becomes |
|---|---|
| `ReportCard.gd` forked from `StudentCard.gd` (23 shared function names, 5 identical) | Shared card rendering moves into the existing `StudentCardView`. |
| `StatDetailPopup` / `TraitDetailPopup` / `WeekRecapPillInfoPopup` open/close | One `InfoPopup` base class. |
| `_on_scroll_gui_input` ×3 (DailyDecayOverview, EventStudentSelectDialog, ResultCheckup) | One small script on the ScrollContainer node. |
| `_finish_quiz` and friends in Password, Variabel, PilihanGanda, Menjodohkan | A `QuizMinigame` base class. |
| `_make_btn_stylebox` in Menjodohkan, PilihanGanda, PauseMenu | One shared minigame helper with identical values. Not a `ThemeFactory` variation: minigames are outside the design system (CLAUDE.md), and this keeps their look exactly. |
| Per-screen hover/bounce (`_setup_button_juice`, `_on_btn_mouse_entered/exited`, `_animate_button_click_bounce`) | `UIPolish` has no hover handling, so nothing is deleted: the code moves into one `Juice` function with identical values. |
| `_get_button_display_name` ×3 | One shared helper. |
| Sample roster duplicated in `DebugManager.gd` and `StudentCard.gd` | One shared data resource. |

**PR6+ — split long functions**, one PR per area to keep conflicts small:
SchoolDay → AturJadwal → Lobby → StudentCard/StudentList → StudentManager →
minigames → DebugManager.

- "Extract function" refactors only: each new function is named for the step
  it performs; no logic changes.
- Any function touched gets its bare numbers named and its declarations
  typed (rule 10).
- **Finish line:** no long-function baseline entry over 100 outside
  `ALLOWED`. Functions of 50–100 lines, untyped declarations and bare numbers
  continue to shrink under the ratchet as code is touched.

**Out of scope:** decomposing `SchoolDay.gd` (1,638 lines) into components —
its own project; the ratchet stops it growing. Enabling GDScript warnings.
Renaming audio's camelCase files (only the misspelled `loby_song*` are
renamed). Editing `Balance.gd`.

## 6. Verification loop and workflow

**Every PR runs this loop until it is clean:**

1. **Test:** targeted `test_run` for the suites touched → `ci/project_check`
   → one full suite run on the exact commit to ship.
2. **Independent review:** a reviewer agent with fresh context (not the
   implementer) gets the spec section, `clean-code.md`, the diff, and the test
   output. It reviews:
   - *Output:* behaviour preserved; rules followed; ratchet baselines lowered
     correctly; no stray changes (the theme rebake or
     `default_bus_layout.tres` rewriting themselves).
   - *Process:* the editor was closed for text edits; tests ran on this
     commit; the PR holds only what its allow-list permits; historical docs
     untouched; `git status` clean.
   It returns findings marked **blocking** or **non-blocking**.
3. **Fix and repeat:** blocking findings are fixed, then steps 1 and 2 run
   again. Each round's new reviewer re-checks the previous findings and the
   whole diff.
4. **Done** = full suite green on the shipped commit **and** zero blocking
   findings. Then `ship-pr` opens the PR (its own suite + review + stamp).
5. **Safety valve:** a finding that survives 3 rounds, or a judgment call that
   belongs to the user, stops the loop and goes to the user.

The spec itself went through this loop before the user reviewed it.

**Workflow:**

- One branch and one worktree per PR, cut from the latest `Textures` after
  the previous PR merges. Order: PR1 → PR2 → PR3 → PR4 → PR5 → PR6+.
- The user's own Godot editor (main checkout) is never touched; verification
  runs in a second editor instance on the worktree.
- The user tells the collaborator before PR1 (the ratchet now runs in CI),
  PR2 (open branches should rebase onto the renames) and PR3 (it rewrites
  `GameState`, `StudentData` and `DebugManager`) merge. Nothing is sent on the
  user's behalf.
- **Pulling PR2 or PR3:** everyone closes Godot first, then checks
  `git status` for re-created old-name files (an editor left open re-saves
  them, and two files then share one UID).
- **CLAUDE.md is over its 23,000-character budget (24,149 characters today).** PR1 moves
  enough out to the relevant guides to fit the new pointer line under budget;
  PR3's removal of the stat-key warning frees more.
- Docs per PR: a `CHANGELOG.md` entry. PR2 replaces the misspelling rule;
  PR3 removes the stat-key trap. Remaining ratchet debt (untyped
  declarations, bare numbers, 50–100-line functions, SchoolDay decomposition)
  goes into `DEBT.md`.
- **Plans in three phases**, each written after the previous phase merges,
  because later code depends on the renames: Phase 1 = PR1–PR3 (rules,
  ratchet, mechanical renames); Phase 2 = PR4–PR5 (duplicates); Phase 3 =
  PR6+ (function splits).

## Success criteria

- `clean-code.md` exists and CLAUDE.md points to it, under budget.
- The scan passes in both the editor suite and CI's `project_check`, and
  every must-be-zero rule is empty.
- No file in `Scripts/`/`Scenes/` is snake_case or misspelled; no asset name
  has a space, bracket or non-ASCII character; every literal `res://` path
  outside that rule's `ALLOWED` list resolves with exact case.
- No `akademis[123]` / `kepribadian[12]` anywhere in code, scenes or tests.
- The tutorial exists once; the 22 duplicate groups are gone (or listed in
  `ALLOWED` with a reason).
- No long-function entry over 100 body lines outside `ALLOWED`.
- Every PR merged through the loop in section 6, with a green full suite.
- No gameplay or visual change.
