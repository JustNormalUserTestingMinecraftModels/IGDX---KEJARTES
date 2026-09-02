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
