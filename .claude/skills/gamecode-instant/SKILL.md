---
name: gamecode-instant
description: Use when the user types /gamecode-instant, or asks for a KejarTes feature to be designed, planned and built in one unattended run with no check-ins along the way.
---

# gamecode-instant

`/gamecode` with its **user** gate removed — not its supervisor gates, which
all still run. Same pipeline, same sub-skills, same rules; the difference is
that nothing waits for the user until the work is built.

```
/gamecode-instant <idea>
  → recon → brainstorm → branch → spec → mockup ─ supervisor gate
  → plan ─ supervisor gate
  → the Summary + the mockup (sent, never awaited)
  → task loop, each task gated → supervisor sweep → report → "Ship it?"
```

**REQUIRED BACKGROUND:** `/gamecode` (`.claude/skills/gamecode/SKILL.md`). Every
section of it applies here. This file changes only what is listed below, and
adds §S.

**The supervisor gates matter more here, not less.** Nobody is reading over your
shoulder, so the fresh-context review at each phase is the only thing standing
between a wrong early reading and a merged PR. Dropping a gate to finish sooner
is the one shortcut that makes `-instant` worse than doing nothing.

| /gamecode | Under /gamecode-instant |
|---|---|
| §5 gate verdict `TANYA` | there is nobody to ask — see §S |
| §6 Plan Summary, then wait | the same message and the same mockup, sent as a notice — the run continues in the same turn (§R) |
| §7 amendment folded in after the yes | there is no yes — see **Interrupts** (§S) |
| §8 "Ship it?" | unchanged, and **not waivable** (§S) |
| §9 tuning diff applied on the user's yes | proposed and written to the report, never applied (§T) |

## R. The Summary

`/gamecode` §6 verbatim — same parts, same 200-word cap, same repo-relative
paths, same mockup rendered before it — with two changes:

- **`Paling perlu dilihat` carries more weight here**, because nobody is going
  to answer it. It is still the supervisor's line, never your own assessment:
  its `Kalau ini salah`, or its `Pertanyaan penting` when a gate returned
  `TANYA`. It is what the user scans for when they come back, and what tells
  them whether to read the branch or bin it. The mockup does the same job
  faster — send it even though nobody will reply.
- The closing line is a notice, not a question. Replace `Lanjut? …` with:

  > Aku lanjut sekarang — build, tanpa berhenti. Potong aja kalau ada yang
  > salah di atas. Berhenti sekali di akhir, sebelum PR.

Do not mention the skill, the pipeline, or that `-instant` differs from
`/gamecode`. The user knows what they typed.

## S. The only stops

This list is closed. Nothing else stops the run.

1. **Ship.** After the report, ask **"Ship it?"** and wait. Pushing opens a PR
   that `ci/auto_merge.sh` merges into `Textures` unattended — that is
   publishing, and typing `-instant` is not permission for it. The one
   exception: the user wrote `--ship` in the invocation, which is that
   permission, given in advance, for this run only.
2. **`Balance.gd` would have to change.** Propose the diff in the report;
   never apply it (CLAUDE.md → Conventions).
3. **New persistence.** Anything reaching `user://` beyond
   `GameState.inventory` needs asking (CLAUDE.md → Architecture).
4. **A pinned invariant would have to move.** `test_viewport_editability.gd`'s
   `BASELINE` is only ever lowered; `DISPLAY_ROSTER` is pinned both ways.
5. **Someone else's uncommitted work is in the way** and a worktree does not
   get you around it — including a force-kill of Godot with unsaved `(*)`
   tabs.
6. **A supervisor finding is real and load-bearing at the fix-round cap**
   (`/gamecode` §5). Real-but-not-load-bearing gets parked with a ruling and
   the run continues; a structural failure is not parkable, because every task
   after it builds on it.

Stop by reporting where you got to and what you need. Do not stop silently.

### Not stops — decide, record in the **Catatan** block of the report, continue

| Looks like a reason to stop | What to do instead |
|---|---|
| The idea is ambiguous | Take the reading closest to what they asked, name it in **Diputuskan** |
| A default might be wrong | Put it in **Paling perlu dilihat**. Branches are cheap |
| A gate returned `UBAH` | That is the gate working. Run the fix round (`/gamecode` §5) |
| A gate returned `TANYA` | Take the default, put the question in **Paling perlu dilihat**, continue |
| The supervisor wants a mockup | Draw it. It is required for visual work, not a check-in |
| A gate found something after the Summary went out | Fix it and note it in **Catatan**; the Summary is never re-sent |
| A plan step's test fails | That is test-first's red step. Progress, not a blocker |
| Your own test goes red | Fix it |
| The full suite is red outside your change | Report it; do not land an unrelated fix in this branch |
| Scope grew past the plan | Build the smallest honest version, put the growth at the top of the report |
| `executing-plans` wants a review checkpoint | Self-review and continue |
| Editor restart, dropped bridge, rescan, worktree setup | Routine, already authorized |
| "I should just confirm this one thing" | No. Record it and continue |

### Interrupts

The user's lever is interrupting, so make it work. A correction that arrives
mid-run is folded into the plan file, then executed, and confirmed in one line
— the Summary is never re-sent, and the run does not pause for approval of the
fold. If the correction invalidates work already committed, revert those
commits on the branch and say so; do not leave both versions in.

## T. The tuning loop

`/gamecode` §9 runs as written up to the proposal. The supervisor still appends
its per-dispatch line to `FEEDBACK.md` — that is a log, not a check-in, and it
never pauses anything.

The difference is the ending: a proposed `SKILL.md` diff needs the user's yes,
and there is no yes in an unattended run. So write the proposal to
`.superpowers/gamecode/<topic>/tuning.md`, put **one line** in the report
naming the pattern and the file, and apply nothing. A skill that edits itself
while nobody is watching is the one loop in this pipeline with no brakes.

## Red flags — you are about to break the run

- You skipped a supervisor gate, shortened its inputs, or told it what not to
  flag, because nobody is watching. Nobody watching is why the gate is there.
- You applied a `SKILL.md` edit without a yes.
- You wrote a question mark to the user before the report.
- You are explaining a trade-off instead of taking one.
- You caught yourself typing "should I", "mau aku", "prefer", "or would you".
- You are waiting for a reply that the user never agreed to give.
- The report's ask is anything other than "Ship it?".

All of these mean: pick the default, write it in **Diputuskan**, **Paling
perlu dilihat** or **Catatan**, and keep building.

## What still pauses the run

A permission prompt the harness raises on its own — `git push`, `git worktree
add`, a shell command outside the allowlist — halts an unattended run no matter
what this file says. It is not a stop you chose, so do not treat it as one:
answer it and carry on. If the user means to be away, the fix is theirs, in
`.claude/settings.json`, not a change to the pipeline. Say so once in the
report if a prompt actually cost the run time.
