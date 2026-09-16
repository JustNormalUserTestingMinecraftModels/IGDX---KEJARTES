---
name: gamecode
description: Use when the user types /gamecode, or asks to take a KejarTes game feature, mechanic, item, quirk, event or screen from idea to working code in one run.
---

# gamecode

One command for the whole feature pipeline, so the user never has to spell out
the skill sequence:

```
/gamecode <idea>
  → superpowers:brainstorming → branch → spec → superpowers:writing-plans
  → the Plan Summary  (§4)  ← the one review gate
  → user says yes
  → superpowers:executing-plans
  → "Ship it?" → ship-pr
```

Two questions reach the user: the Plan Summary, and "Ship it?". Everything
else runs unattended — including the whole design phase, which lands in the
spec rather than in a message. This file overrides only the gates below;
otherwise each sub-skill runs as written.

| Sub-skill gate | Under /gamecode |
|---|---|
| brainstorming: propose 2-3 approaches | recommend one; the rest become Decisions or **Not doing** (§1) |
| brainstorming: design in sections, approval after each | no approval — the design goes into the spec (§2) |
| brainstorming: user reviews the written spec | met by the Plan Summary, which links it (§4) |
| brainstorming: writing-plans is the only next skill | branch and spec first (§2), then writing-plans |
| writing-plans: header recommends subagent-driven-development | header names executing-plans only |
| writing-plans: "Subagent-driven or inline?" | executing-plans, no question |
| executing-plans: note to use subagent-driven-development instead | stay — the Godot bridge takes one client |
| executing-plans: raise plan concerns before starting | raise them in the Plan Summary (§4), not after the yes |
| executing-plans / using-git-worktrees: workspace and its consent | the `/gamecode` invocation is the consent (§2) |
| executing-plans → finishing-a-development-branch menu | report, then "Ship it?" (§6) |

## 1. Brainstorm

**REQUIRED SUB-SKILL:** invoke `superpowers:brainstorming` with the user's idea.
With no idea given, its first question is "What should the game do?"

- Ask only what the code and CLAUDE.md cannot answer. A choice with a sensible
  default is taken, not asked, and listed in the summary's **Diputuskan**.
- Recommend one approach. When another would play differently for the player,
  say so in **Diputuskan**; otherwise it goes on the **Not doing** line.
- When the code contradicts the user's premise, take the way forward closest to
  what they asked for, and make it the summary's **Paling perlu dilihat** line.
- Diagrams go in the spec as text. The visual companion is used only when the
  user asks for a mockup.

## 2. Branch and spec

No message goes out for this. In one unbroken run:

1. **Branch.** Use a worktree when
   `git status --porcelain --untracked-files=no` prints anything, or another
   session holds the checkout; otherwise this checkout. Then `git fetch origin`
   and branch from `origin/Textures`. In this checkout, restart the editor
   after the switch so its buffers match the tree. A worktree goes through
   `superpowers:using-git-worktrees`, then gets its own editor per `ship-pr` §3.
2. **Spec.** Write the design to
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` — the full Logic,
   State (name both sides across the `approved_students` ↔ `StudentData`
   bridge, e.g. `kepribadian1` (mood)), Files, and how Kelas 7/8/9 differ.
   Self-review it; commit.

## 3. Plan

**REQUIRED SUB-SKILL:** `superpowers:writing-plans`. Test steps read
`Run: test_run(suite="<x>")`, where `<x>` is what the suite's `suite_name()`
returns — a new suite must override it, since the base returns `"unnamed"`.
In a worktree every call also passes that editor's `session_id`. The last task
runs the full suite.

## 4. The Plan Summary — stop here

One message, **200 words or fewer**, in the user's language, in-game names as
the game spells them. Repo-relative paths only, never absolute ones. It has
these parts, in this order, and nothing else:

```
**<Feature>** — <one sentence: what the player gets>.

Rencana: `docs/superpowers/plans/<file>.md` · Spec: `docs/superpowers/specs/<file>.md` · Branch: `feat/<topic>`

**Langkah** (semua test-first)
1. <one line per task, twelve words at most — what it does, not how it tests>
…

**Diputuskan**
- <each default taken, one line each>

**Tidak dikerjakan:** <cuts, and the rejected approach>

**Paling perlu dilihat:** <the single guess most likely to be wrong — usually a
tuning number you invented — and the cheaper alternative, with its cost now
versus after the tests are written>

Lanjut? Kalau ada yang salah, bilang sekarang.
```

**Paling perlu dilihat** is required, not optional. There is always one — the
number you picked, the reading of an ambiguous word, the pattern you copied.
Naming it is what makes this gate worth the user's time; a summary that reports
only confidence wastes it.

Do not restate the plan. The tasks are one line each because the plan is
linked; the user opens it when a line looks wrong.

Then **wait.** No code until they answer.

## 5. After the go-ahead

A yes is any agreement — "yes", "ok", "gas", "lanjut", "setuju", a thumbs-up —
with or without an amendment. An amendment is folded into the plan *file*
first, then executed; re-show the summary only when the amendment changes the
task list.

**REQUIRED SUB-SKILL:** `superpowers:executing-plans`. Stop only on its "When to
Stop" list. A failure a plan step predicts — the red step of test-first — is
progress, not a stop.

## 6. Finish

Report in plain words: what was built, the final full run's totals, the
decisions as built, and anything that grew past the plan. Then ask one question
— **"Ship it?"** `ship-pr` is this project's finish (CLAUDE.md); it pushes a PR
that merges itself, which the plan's yes did not cover. On yes, invoke
`ship-pr`.
