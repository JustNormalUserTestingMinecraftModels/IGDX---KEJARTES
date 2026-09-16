---
name: gamecode-instant
description: Use when the user types /gamecode-instant, or asks for a KejarTes feature to be designed, planned and built in one unattended run with no check-ins along the way.
---

# gamecode-instant

`/gamecode` with its design gate removed. Same pipeline, same sub-skills, same
rules — the difference is that nothing waits for the user until the work is
built.

```
/gamecode-instant <idea>
  → read the code → the Receipt (sent, never awaited)
  → branch → spec → superpowers:writing-plans → superpowers:executing-plans
  → report → "Ship it?"
```

**REQUIRED BACKGROUND:** `/gamecode` (`.claude/skills/gamecode/SKILL.md`). Every
section of it applies here. This file changes only what is listed below, and
adds §S.

| /gamecode | Under /gamecode-instant |
|---|---|
| the Brief, then wait for yes | the **Receipt** (§R) — sent as a notice, the run continues in the same turn |
| **Decisions** block, "yes" takes the bold defaults | no open decisions: take the bold default, list it under **Diputuskan** |
| **Branch:** this checkout \| worktree | **always a worktree** when `git status --porcelain --untracked-files=no` prints anything or another session holds the checkout |
| the yes is the consent for the branch | the `/gamecode-instant` invocation is the consent |
| amendment re-shows the Brief | there is nothing to re-show — see **Interrupts** (§S) |
| "Ship it?" | unchanged, and **not waivable** (§S) |

## R. The Receipt

Same shape and length as the Brief, three changes:

- **It goes out after the reading pass, not before.** Grep the call sites,
  the enum, the tests. A Receipt whose **Files** and **Logic** lines are
  guesses is worse than no Receipt — its whole value is that the user can
  read real names and interrupt on a real mistake.
- **Decisions** becomes **Diputuskan** — the same list, stated as taken, each
  one line. Nothing is offered.
- The closing line is a notice, not a question:

  > Aku mulai sekarang — spec, plan, build, tanpa berhenti. Potong aja kalau
  > ada yang salah di atas. Berhenti sekali di akhir, sebelum PR.

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

Stop by reporting where you got to and what you need. Do not stop silently.

### Not stops — decide, record in the **Catatan** block of the report, continue

| Looks like a reason to stop | What to do instead |
|---|---|
| The idea is ambiguous | Take the reading closest to what they asked, name it in **Diputuskan** |
| A default might be wrong | That is what the Receipt is for. Branches are cheap |
| A plan step's test fails | That is test-first's red step. Progress, not a blocker |
| Your own test goes red | Fix it |
| The full suite is red outside your change | Report it; do not land an unrelated fix in this branch |
| Scope grew past the Receipt | Build the smallest honest version, put the growth at the top of the report |
| `executing-plans` wants a review checkpoint | Self-review and continue |
| Editor restart, dropped bridge, rescan, worktree setup | Routine, already authorized |
| "I should just confirm this one thing" | No. Record it and continue |

### Interrupts

The user's lever is interrupting, so make it work. A correction that arrives
mid-run is folded in at the next task boundary and confirmed in one line — the
Receipt is never re-sent, and the run does not pause for approval of the fold.
If the correction invalidates work already committed, revert those commits on
the branch and say so; do not leave both versions in.

## Red flags — you are about to break the run

- You wrote a question mark to the user before the report.
- You are explaining a trade-off instead of taking one.
- You caught yourself typing "should I", "mau aku", "prefer", "or would you".
- You are waiting for a reply that the user never agreed to give.
- The report's ask is anything other than "Ship it?".

All of these mean: pick the default, write it in **Diputuskan** or
**Catatan**, and keep building.

## What still pauses the run

A permission prompt the harness raises on its own — `git push`, `git worktree
add`, a shell command outside the allowlist — halts an unattended run no matter
what this file says. It is not a stop you chose, so do not treat it as one:
answer it and carry on. If the user means to be away, the fix is theirs, in
`.claude/settings.json`, not a change to the pipeline. Say so once in the
report if a prompt actually cost the run time.
