---
name: gamecode
description: Use when the user types /gamecode, or asks to take a KejarTes game feature, mechanic, item, quirk, event or screen from idea to working code in one run.
---

# gamecode

One command for the whole feature pipeline, so the user never has to spell out
the skill sequence:

```
/gamecode <idea>
  → superpowers:brainstorming → the Brief  (changes? revise, re-show)
  → user says yes
  → branch → spec → superpowers:writing-plans → superpowers:executing-plans
  → "Ship it?" → ship-pr
```

Two questions reach the user: the Brief, and "Ship it?". Everything between
runs unattended. This file overrides only the gates below; otherwise each
sub-skill runs as written.

| Sub-skill gate | Under /gamecode |
|---|---|
| brainstorming: propose 2-3 approaches | recommend one; the rest become Decisions or **Not doing** (§1) |
| brainstorming: design in sections, approval after each | one Brief (§2), one approval |
| brainstorming: user reviews the written spec | met by the Brief's yes |
| brainstorming: writing-plans is the only next skill | branch first (§3), then writing-plans |
| writing-plans: header recommends subagent-driven-development | header names executing-plans only |
| writing-plans: "Subagent-driven or inline?" | executing-plans, no question |
| executing-plans: note to use subagent-driven-development instead | stay — the Godot bridge takes one client |
| executing-plans / using-git-worktrees: workspace and its consent | the Brief's **Branch** line; the yes is the consent (§3) |
| executing-plans → finishing-a-development-branch menu | report, then "Ship it?" (§4) |

## 1. Brainstorm

**REQUIRED SUB-SKILL:** invoke `superpowers:brainstorming` with the user's idea.
With no idea given, its first question is "What should the game do?"

- Ask only what the code and CLAUDE.md cannot answer. A choice with a sensible
  default goes in the Brief's **Decisions** block, not in a question.
- Recommend one approach. When another would play differently for the player,
  it becomes a Decision; otherwise it goes on the **Not doing** line.
- When the code contradicts the user's premise, say so in the Brief and make
  the way forward a Decision, with the option closest to what they asked for
  in bold.
- Diagrams go inside the Brief as text. The visual companion is used only when
  the user asks for a mockup.

## 2. The Brief

One message of about 250 words — one phone screen — in plain words and the
user's language, in-game names as the game spells them. These parts, in this
order:

```
**<Feature>** — <one sentence: what the player gets>.

<text flow, 3–6 lines: its place in the game loop
 (StudentCard → Lobby → AturJadwal → StudentList → SchoolDay → ResultCheckup), new step marked>

**Logic**
- <each rule in plain words; numbers as a named const/@export in the script
  that owns the rule; Balance.gd read-only>
- State: <GameState / StudentData fields read and written; across the bridge name
  both sides, e.g. `kepribadian1` (mood)>
- Grades: <how Kelas 7/8/9 differ, or "same in every grade">

**Files**
- `<file name>` — new | edit: <at most six words>     (one line per script, scene or asset)
- Tests: <suite names, new ones marked, all on this one line>

**Decisions** — "yes" takes the **bold** defaults
1. <choice the code forced or the user left open>: **<default>** / <other>

**Not doing:** <cuts, and the rejected approach>
**Branch:** `feat/<topic>` from `origin/Textures`, <this checkout | worktree>

Reply **yes** and I'll plan and build it without stopping, then ask before shipping.
```

Include **Decisions** only when a decision is open. **Logic** and **Files**
describe the bold defaults. **Branch** says *this checkout* when
`git status --porcelain --untracked-files=no` prints nothing and the editor
has no unsaved "(*)" tabs; otherwise *worktree*.

## 3. After yes

A yes is any agreement — "yes", "ok", "gas", "lanjut", "setuju", a thumbs-up —
with or without an amendment; picking a non-bold option is an amendment. An
amendment that changes **State** or **Files** gets the Brief re-shown; any
other is folded in.

Then, in one unbroken run:

1. **Branch.** `git fetch origin`, then create the Brief's branch from
   `origin/Textures`. In this checkout, restart the editor after the switch so
   its buffers match the tree. A worktree goes through
   `superpowers:using-git-worktrees`, then gets its own editor per `ship-pr` §3.
2. **Spec.** Save the agreed Brief, decisions resolved, as
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`; self-review; commit.
3. **REQUIRED SUB-SKILL:** `superpowers:writing-plans`. Test steps read
   `Run: test_run(suite="<x>")`, where `<x>` is what the suite's `suite_name()`
   returns — a new suite must override it, since the base returns `"unnamed"`.
   In a worktree every call also passes that editor's `session_id`. The last
   task runs the full suite.
4. **REQUIRED SUB-SKILL:** `superpowers:executing-plans`. Stop only on its
   "When to Stop" list. A failure a plan step predicts — the red step of
   test-first — is progress, not a stop. A plan concern that is not on that
   list goes in the final report.

## 4. Finish

Report in plain words: what was built, the final full run's totals, the
decisions as built, and the spec and plan paths. Then ask one question —
**"Ship it?"** `ship-pr` is this project's finish (CLAUDE.md); it pushes a PR
that merges itself, which the plan's yes did not cover. On yes, invoke
`ship-pr`.
