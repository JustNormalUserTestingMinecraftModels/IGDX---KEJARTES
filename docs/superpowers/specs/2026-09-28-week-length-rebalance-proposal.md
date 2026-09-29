# Week-length rebalance — proposal for Balance.gd's owner

**Update 2026-09-29:** the owner asked for Kelas 7/8/9 = 4/6/8 weeks instead
(not the 6/9/12 below). That is applied as `GameState.WEEKS_BY_GRADE`, with
`Balance.gd` untouched and the targets unchanged, so Kelas 8 and 9 are now far
tighter than this doc's slack math allows -- see the pacing numbers in the PR.
The proposal below is kept for its method.

**Status:** Proposal only. Not applied. `Scripts/Balance.gd` is
collaborator-owned (`CLAUDE.md`, "Conventions") — this document is the
handoff artifact for that collaborator to review and, if they agree, apply
themselves. No code in this branch touches `Balance.gd`.

**Context:** part C of the level-selection-polish pass
(`docs/superpowers/specs/2026-09-28-level-selection-polish-design.md`).
Grade 8 (12 weeks) and Grade 9 (16 weeks) read as a drag in play. This
proposes shortening both, without changing how hard they feel.

## Why weeks and target move together

`Balance.gd` pairs two numbers per grade: `JUMLAH_MINGGU_KELAS_*` (how many
weeks the player has) and `TARGET_KENAIKAN_KELAS_*` (how many points every
subject must gain to pass). The file's own comment on
`JUMLAH_MINGGU_KELAS_*` says it directly: "Pasangan angka ini dengan
TARGET_KENAIKAN di atas: keduanya bareng yang menentukan satu kelas terasa
adil atau mustahil" (these two numbers together decide whether a grade feels
fair or impossible). Cutting weeks alone, with the target held fixed, removes
study time without removing work — it would make the grade harder, not
shorter. The lever that keeps difficulty constant while cutting playtime is
scaling weeks and target down **together**.

## Current numbers (read from `Scripts/Balance.gd`, unedited)

| Grade | `JUMLAH_MINGGU_KELAS_*` (weeks) | `TARGET_KENAIKAN_KELAS_*` (target uplift) | Source lines |
|---|---|---|---|
| 7 | 6 | 15.0 | `Balance.gd:31`, `:62` |
| 8 | 12 | 34.0 | `Balance.gd:32`, `:63` |
| 9 | 16 | 40.0 | `Balance.gd:33`, `:64` |

These match both `CLAUDE.md`'s grade table and the polish design doc's
current-state table exactly — no discrepancy to flag here.

## Deriving "rest slack" — the working

A grade's felt difficulty is not the target alone; it's the target measured
against how many school days the player actually has. Define:

- **Days** = weeks × 5 (a school week is Senin–Jumat; `SchoolDay` simulates 5
  days/week).
- **Study-days needed** = the days of dedicated study, per subject, required
  to close the target gap at the grade's base study rate, summed across all
  three skills (`akademis`, `seni_budaya`, `olahraga` all carry the same
  target). Balance.gd's base rate for a non-favorite, non-boosted study day
  is `BELAJAR_POIN_KELAS_*` (`Balance.gd:73-75`: 3.0 / 2.5 / 2.0 points per
  day for Grade 7/8/9). So:

  `study_days_needed = 3 × (target ÷ BELAJAR_POIN_KELAS_grade)`

  This is a floor estimate: it ignores the favorite-subject bonus, the
  `Seimbang`/off-specialty cost multipliers, personality decay, and any lost
  days to `Izin` or minigame outcomes — all of which only add friction on top
  of this number in real play. It is meant to compare grades against each
  other, not to predict an exact playthrough.
- **Rest slack** = `(days − study_days_needed) ÷ days` — the fraction of the
  grade's days left over for `Istirahat`, `Wirausaha`, minigames, and losses,
  after the minimum study grind is covered.

Working the current numbers:

| Grade | Days (weeks × 5) | Study-days needed = 3 × target ÷ rate | Rest slack |
|---|---|---|---|
| 7 | 6 × 5 = 30 | 3 × 15 ÷ 3.0 = 15.0 | (30 − 15) ÷ 30 = **50%** |
| 8 | 12 × 5 = 60 | 3 × 34 ÷ 2.5 = 40.8 | (60 − 40.8) ÷ 60 = **32.0%** |
| 9 | 16 × 5 = 80 | 3 × 40 ÷ 2.0 = 60.0 | (80 − 60) ÷ 80 = **25%** |

These reproduce the polish design doc's stated slack figures (~50% / ~32% /
~25%) exactly, confirming the formula the design doc used.

## Proposed cut: 0.75× on Grade 8 and Grade 9, Grade 7 untouched

| Grade | Weeks now → proposed | Target now → proposed | Factor |
|---|---|---|---|
| 7 | 6 (unchanged) | 15 (unchanged) | — |
| 8 | 12 → **9** | 34 → **26** | 0.75× (weeks exact; target 34 × 0.75 = 25.5, shown as the integer the picker will display) |
| 9 | 16 → **12** | 40 → **30** | 0.75× (exact both ways) |

Grade 9 scales cleanly (16 × 0.75 = 12, 40 × 0.75 = 30, both exact). Grade
8's target does not divide evenly: 34 × 0.75 = 25.5. `LevelSelect.target_for()`
displays `int(TARGET_KENAIKAN_KELAS_8)`, so whatever the collaborator stores
must read as **26** on the picker — i.e. the stored float should be `26.0`,
not the literal `25.5`. The slack math below shows both, so the collaborator
can see the difference is negligible either way.

## Slack math for the proposal — showing felt difficulty is held

Using the same formula as above, with the new weeks and target:

| Grade | Days (weeks × 5) | Study-days needed = 3 × target ÷ rate | Rest slack | vs. current |
|---|---|---|---|---|
| 7 | 30 (unchanged) | 15.0 (unchanged) | 50% | unchanged |
| 8 (target = 26.0) | 9 × 5 = 45 | 3 × 26 ÷ 2.5 = 31.2 | (45 − 31.2) ÷ 45 = **30.7%** | −1.3 pts vs. 32.0% |
| 8 (target = 25.5, unrounded) | 45 | 3 × 25.5 ÷ 2.5 = 30.6 | (45 − 30.6) ÷ 45 = **32.0%** | exact match |
| 9 | 12 × 5 = 60 | 3 × 30 ÷ 2.0 = 45.0 | (60 − 45) ÷ 60 = **25%** | exact match |

Grade 9 holds exactly. Grade 8 holds exactly at the true 0.75× value (25.5)
and comes out 1.3 points looser (30.7% vs. 32.0%) once rounded up to the
integer 26 the UI needs to show — a rounding artifact, not a difficulty
change, and still squarely between Grade 7's 50% and Grade 9's 25% on the
same difficulty curve (`Santai` → `Menantang` → `Susah`). Either stored value
is a defensible choice; this doc flags the trade-off rather than picking for
the owner.

**Net effect:** both long grades get 25% less total playtime (9 vs. 12
weeks, 12 vs. 16 weeks) while the ratio of grind-to-slack that makes each
grade feel `Menantang` / `Susah` is preserved to within a rounding point. A
roster still clears `run_stars() >= 2.0` under the same normal-play
assumptions as today; nothing about the win condition itself changes.

## What this doc does not do

This is a proposal, not a patch. It does not touch
`TARGET_KENAIKAN_KELAS_8`, `TARGET_KENAIKAN_KELAS_9`,
`JUMLAH_MINGGU_KELAS_8`, or `JUMLAH_MINGGU_KELAS_9` in `Scripts/Balance.gd` —
those four constants remain exactly as they are on this branch. Per
`CLAUDE.md`'s convention ("`Balance.gd` values are owned by a collaborator,
not by us... read it freely, never edit it, propose changes instead, and on
merge take their version"), applying this change is the `Balance.gd` owner's
call to make, on their own commit. Once they do, `LevelSelect.weeks_for()`
and `LevelSelect.target_for()` (`Scripts/LevelSelect/LevelSelect.gd:76-88`)
already read both constants live, so the level-select picker's week grid and
brief text update for free — no screen-side change is needed to ship this.
