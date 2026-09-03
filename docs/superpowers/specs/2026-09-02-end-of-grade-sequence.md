# End-of-Grade Sequence — Design Spec

**Date:** 2026-09-02
**Reference art:** the flow diagram the user supplied in chat (`WhatsApp Image 2026-09-02 at 1.42.01 PM.jpeg`) — save it to `docs/superpowers/mockups/end-of-grade-flow.jpeg` before starting Task 1
(the flow it shows: *Tes dimulai notice → cutscene tes → stat check → win
screen / lose screen → run result → main menu*)

## Problem

Today, when the player finishes the final week of a grade, `SchoolDay.gd`
jumps straight to `SemesterEnd.tscn`. That screen does four jobs at once —
per-student stat check, pass/fail verdict, narrative payoff, and routing —
and it does none of them with the ceremony a "final exam" deserves. There is
no notice that the Big School Test is coming, no narrative beat, and no
run-level report of what the player actually did across the whole grade
(minigames, items, wirausaha money, events). The loss path already has a
cutscene; the win path has none.

## The sequence

    SchoolDay (final week done)
      └─> TesNotice          "Tes Besar Sekolah akan dimulai"   (new)
          └─> CutScene       exam branch, 3–4 dialogues          (branch on existing scene)
              └─> SemesterEnd  stat check, restyled              (existing, restyled)
                  ├─> WinScreen   (new; cutscene-styled)   ─┐
                  └─> LoseScreen  (existing game-over       ├─> RunResult (new)
                                   cutscene branch)        ─┘      └─> MainMenu

Every grade (7, 8, 9) runs this same sequence at the end of its final week.
"Win" and "lose" are decided by the existing `GameState.check_semester_passed()`.
Progression to the next grade (or the beat-the-game reset) happens where it
happens today — in the restart handler — but moves out of SemesterEnd and onto
RunResult's exit button, because RunResult is now the last screen of a run.

## Screen by screen

### 1. TesNotice (`Scenes/EndGame/TesNotice.tscn`)

A single full-screen announcement, in the style of an event announcement, but
polished: `notice.png` as a nine-patch card over the blurred-classroom backdrop
(`blur_background.png`), a title (`TES BESAR SEKOLAH`), a subtitle naming the
grade, a body line, and one `PrimaryButton` ("Hadapi Tes"). It auto-advances
after `auto_advance_seconds` (default 6.0) if untouched.

It shows unconditionally at the end of the final week — whether the player is
about to pass or fail. It must not leak the verdict.

### 2. Exam cutscene (branch inside `Scenes/CutScene/cut_scene.tscn`)

`cut_scene.gd` already has two branches selected by `GameState`
(`is_game_over_cutscene` vs the intro). Add a third:
`GameState.is_exam_intro_cutscene`. Same typewriter, same `cutscene_dialogue.png`
chatbox, same fade — only the CG list and text differ. Four placeholder
dialogues, using the intro's existing `cg0..cg4` images as BG placeholders
until real art lands.

### 3. Stat check (`Scenes/EndGame/SemesterEnd.tscn`, restyled)

Keep the carousel, the stat rows, the stamp slam. Restyle only:
- Replace the flat `Color(0.04,0.05,0.08,1)` background `ColorRect` with the
  project's blurred-classroom backdrop plus a soft themed scrim, so it matches
  DaySummary / ResultCheckup / AturJadwal.
- Drop the emoji-laden title strings for the cuter, calmer copy in Task 8.
- Give the card container real margins and the page dots a themed variation
  rather than raw `add_theme_color_override` on a `Label`.
- The buttons stop routing to StudentCard/Lobby/MainMenu; the single forward
  button now goes to WinScreen or the lose cutscene.

### 4. Win screen (`Scenes/EndGame/WinScreen.tscn`)

Built to look and behave exactly like the intro cutscene: same
`cutscene_dialogue.png` chatbox, same `DialogueLabel` typewriter, same hint
label, same tap-to-advance. Four celebratory dialogue lines (placeholders,
written in Indonesian). Warm BGM (`result_win`). Exits to RunResult.

### 5. Lose screen

No new scene. Reuse the existing `is_game_over_cutscene` branch of
`cut_scene.gd`, but change its exit: it currently routes back into the run;
it must now route to RunResult with the run marked failed.

### 6. Run result (`Scenes/EndGame/RunResult.tscn`)

The report card for the whole grade, laid out like a typical cute mobile-game
results screen: a big letter grade that punches in, then a staggered list of
stat rows that count up, then the exit button.

Reported figures (all accumulated per grade, reset when a grade starts):

| Row | Source |
|---|---|
| Minigame selesai (menang) | run stats counter |
| Minigame kalah | run stats counter |
| Total poin minigame | sum of stat points awarded/deducted by minigames |
| Barang dipakai | count of `GameState.use_item()` successes |
| Uang dari wirausaha | sum of every wirausaha payout this grade |
| Murid ikut event | count of distinct students that appeared in an event |

**Letter grade:** `A+ A A- B+ B B- C+ C C-` on a win, always `D` on a loss.
A win's letter comes from a 0–100 run score (targets cleared, minigame win
rate, wirausaha money, event participation) — see Task 4 for the exact formula.

Exit button → MainMenu, after applying the grade progression that SemesterEnd
used to apply.

## Data the game does not track yet

`GameState` has no run-level counters. Everything above needs a new
`run_stats` dictionary on `GameState`, written by the four places that already
know these events happen (`StudentManager.record_minigame_result`,
`GameState.use_item`, `SchoolDay._pay_out_wirausaha`, and SchoolDay's event
branch), and reset by `GameState.set_grade()` / the grade-advance path.

## Audio

No new audio files. Register three new ids as aliases onto existing tracks so
the wiring is in place when real assets arrive:

| Id | Kind | Backing file today |
|---|---|---|
| `exam_notice` | BGM | `Assets/Audio/BGM/schoolsimulation.mp3` |
| `exam_cutscene` | BGM | `Assets/Audio/BGM/introcutscene.mp3` |
| `run_result` | BGM | `Assets/Audio/BGM/result_win.mp3` |

SFX all reuse existing ids: `popup_open` (notice appears), `confirm` (advance),
`stamp` (letter grade slam), `coin` (money row counts up), `reward` (A-range
grade), `fail` (D grade), `tap` (typewriter advance).

## Out of scope

New art, new audio files, a save system, and any change to the simulation math.

## STATUS

Implemented in full via `docs/superpowers/plans/2026-09-02-end-of-grade-sequence.md`
(14 tasks, subagent-driven-development, branch `end-of-grade-sequence` off
`sticky-note-polish`). Full test suite: 671 tests, 661 pass live in the
editor at time of writing; the other 10 (`economy_state` ×6, `wirausaha` ×3,
plus the `test_gamestate_exposes_a_run_stats_record` structural check) are
all one known, already-diagnosed Godot editor limitation, not a code defect
— see "Known gaps" below.

**Deviations from the plan:**

- **RunResultRow needs `class_name`.** The plan's Task 13 typed two
  `RunResult.gd` variables as `RunResultRow` to fix an inference bug, but
  Task 12's `RunResultRow.gd` never declared `class_name RunResultRow` —
  a real parse error the plan didn't anticipate. Fixed by adding the
  `class_name` declaration.
- **Two invalid `\u{XXXX}`-braced unicode escapes** in the plan's own
  Task 13 test text (GDScript only supports bare `\uXXXX`) broke the whole
  `test_run_result.gd` suite's ability to load. Fixed by using the literal
  emoji glyphs directly in the negative-check array.
- **Three more untyped-`:=`/base-typed-var GDScript inference bugs**, on top
  of the one flagged during planning, surfaced across Tasks 10, 12, and 13's
  brief text (`var mine = ...` / `var tapped := ...` in WinScreen's test and
  script, `var row := ...` / `var row: Control = ...` in RunResult.gd). All
  are the same class: a variable typed too broadly for a subclass-only
  member access under GDScript's `:=` inference. Fixed with explicit type
  annotations at each site; behavior unchanged in every case.
- **Two `@onready`-before-`_ready()` test gaps.** `test_the_exam_branch_has_four_dialogues`
  (Task 7) and `RunResultRow`'s `set_row`/`play_count_up` tests (Task 12)
  both called methods on a bare `instantiate()` without ever running
  `_ready()`, leaving `@onready` vars null. Fixed by (a) adding the node to
  the live SceneTree via `Engine.get_main_loop().root.add_child(...)` with
  matching cleanup, per this project's own `test_semester_end.gd` precedent,
  and (b) adding an explicit (empty) `_ready()` to `RunResultRow.gd`, which
  had none at all.
- **A stale pre-existing test broke on a legitimate refactor.**
  `test_go_to_gameplay_always_routes_through_student_card` (predates this
  plan) asserted a source-text scan of `go_to_gameplay()`'s body for a
  string literal that Task 7's refactor correctly moved into the new
  `_next_scene_path()` helper. Updated the test to check the new
  architecture instead of the code.
- **A stale `viewport_editability` `ALLOWED` entry regressed unnoticed
  since Task 9.** Task 9 converted `SemesterEnd.gd`'s runtime-built page
  dots to authored `.tscn` nodes, which should have removed that file's
  `ALLOWED` entry in the same commit — but Task 9's own test pass never ran
  `viewport_editability`, so the stale entry sat undetected until Task 13's
  own new entry triggered a full ratchet re-scan. Removed.
- **`GameState.set_grade()` doesn't clear `day_schedules`.** The plan
  flagged this as a "verify and patch if needed" item for Task 13; verified
  true against the real `GameState.gd`, and the beat-the-game progression
  branch now clears `day_schedules` explicitly (the other two branches
  already did).

**Known gaps:**

- **The Godot editor's live singleton autoload does not pick up new plain
  `var` fields on script hot-reload for objects instantiated before the
  edit.** This is the same class of limitation CLAUDE.md already documents
  for new `@export` fields on Resources ("invisible until the editor
  restarts... no headless path"), now also observed for `GameState`'s new
  `run_stats`/`is_exam_intro_cutscene`/`run_failed` fields. Every headless
  remedy available via the Godot MCP was tried (`filesystem_manage(scan)`,
  a no-op `script_patch`, `editor_reload_plugin`, `scene_open` on the main
  scene) — none clear it. The actual game code is independently confirmed
  correct: a genuinely fresh process, launched via `project_run` and probed
  with `editor_manage(game_eval)`, shows every `GameState.run_stats` read
  and write working exactly as specified, and the 661 passing tests include
  every suite that doesn't touch the stale singleton. **A human restarting
  the Godot editor once will clear the remaining 10 false failures** — no
  code change is needed. Re-run `test_run()` after a restart to confirm.
- Every cutscene line in the exam and win branches is a `[PLACEHOLDER]`
  awaiting real dialogue.
- The exam/win backdrops reuse the intro's CG images (`cg0.jpg`–`cg4.jpg`)
  as stand-ins.
- `exam_notice`/`exam_cutscene`/`run_result` BGM ids alias existing tracks
  per the Audio table above — no new audio files were added.
- `RunGrade`'s scoring weights, and especially `MONEY_FULL_MARKS`
  (20000 rupiah for full marks on the money component), are estimates with
  no real-run data behind them yet.
- Report icons (`Assets/Images/UI/Placeholders/icon_*.svg`) are
  placeholder-quality hand-authored SVGs, not finished art — see the plan's
  Task 11 for why SVG rather than PNG, and the drop-in path to real art.
