---
name: gamecode
description: Use when the user types /gamecode, or asks to take a KejarTes game feature, mechanic, item, quirk, event or screen from idea to working code in one run.
---

# gamecode

One command for the whole feature pipeline, so the user never has to spell out
the skill sequence.

Every phase runs in a **fresh subagent**. Every phase is then gated by the
**supervisor** subagent (`.claude/agents/supervisor.md`), which checks the work
against the real tree, draws the screen when the work is visual, and names the
one question that matters. You — the controller — dispatch, hold the Godot
bridge, and talk to the user.

```
/gamecode <idea>
  → recon + brainstorm ─┐
  → spec               ─┼→ supervisor gate (design)
  → mockup, if visual  ─┘
  → plan               ──→ supervisor gate (plan)
  → the Plan Summary + the mockup   ← the one review gate
  → user says yes
  → per task: implementer → your test_run → supervisor gate
  → supervisor sweep of the whole branch
  → report → "Ship it?"
  → supervisor logs the run; proposes a skill diff when the evidence is there
```

Two questions reach the user: the Plan Summary, and "Ship it?" — plus a third
after the run, only on the runs where the ledger has earned a skill change
(§9). Everything else runs unattended, gated by the supervisor rather than by
the user. This file overrides only the gates below; otherwise each sub-skill
runs as written.

| Sub-skill gate | Under /gamecode |
|---|---|
| brainstorming: propose 2-3 approaches | recommend one; the rest become Decisions or **Not doing** (§2) |
| brainstorming: design in sections, approval after each | no approval — the design goes into the spec (§3) |
| brainstorming: user reviews the written spec | met by the Plan Summary, which links it (§6) |
| brainstorming: writing-plans is the only next skill | branch, spec and mockup first, then writing-plans |
| writing-plans: "Subagent-driven or inline?" | subagent-driven, no question (§0) |
| executing-plans / subagent-driven-development | §7 — its task loop, with the supervisor as reviewer |
| SDD: "dispatch a task reviewer" | dispatch `supervisor`; it is this project's reviewer |
| SDD: workspace and its consent | the `/gamecode` invocation is the consent (§3) |
| SDD → finishing-a-development-branch menu | report, then "Ship it?" (§8) |

## 0. The split — read this before dispatching anything

**You own the Godot bridge. Subagents never touch it.** `mcp__godot-ai__*` is
single-client: a subagent that connects displaces this session and gets nothing
itself, and you both then see *"A different Godot AI backend is already
running"* (CLAUDE.md → Godot MCP). So:

| You (controller) | Subagents |
|---|---|
| `test_run`, `script_patch`, `scene_open`, `scene_save`, `editor_screenshot`, editor restarts | read the tree, draft docs, write `.gd` and `.tscn` code, review |
| branch / worktree / commit / push | never run git that rewrites the tree |
| every message to the user | write artifacts to files, return paths |
| rendering the mockup widget | write the widget code to a file |

A subagent that needs a suite run says so in its report. You run it and hand
back the output. Put that contract in every dispatch — the template is in
[dispatch.md](dispatch.md).

**The supervisor is always a subagent — including in inline mode.** A
supervisor that shares your context inherits your assumptions and rubber-stamps
the work. Its fresh context is the entire mechanism; a supervisor "run inline to
save a dispatch" is not a supervisor.

**Models.** Supervisor: as its agent file sets (most capable — it is the
judgment role). Implementers: mid-tier by default, cheapest tier only when the
plan text contains the code to write. Always name the model explicitly; an
omitted model inherits yours.

**Hand artifacts over as files.** Anything you paste into a dispatch, and
anything a subagent prints back, stays in your context for the rest of the run.

## 1. The ledger

Resolve `.superpowers/gamecode/<topic>/` (git-ignored) and create
`progress.md` with its identity on the first line:
`# gamecode ledger — <topic> — started <date>`.

Append a line at every phase boundary, every gate verdict, every fix round and
every adjudication. It is what survives compaction: after one, trust the ledger
and `git log` over your own recollection. A phase with a `complete` line is
done — do not re-run it.

## 2. Recon and brainstorm

Dispatch one subagent to read the tree for what the idea touches — the scenes,
the autoload fields, the suites that pin them, the `DEBT.md` entries — and
return a findings file. Then **REQUIRED SUB-SKILL:** `superpowers:brainstorming`
with the user's idea and that file. With no idea given, its first question is
"What should the game do?"

- Ask only what the code and CLAUDE.md cannot answer. A choice with a sensible
  default is taken, not asked, and listed in the summary's **Diputuskan**.
- Recommend one approach. When another would play differently for the player,
  say so in **Diputuskan**; otherwise it goes on the **Not doing** line.
- When the code contradicts the user's premise, take the way forward closest to
  what they asked for, and make it the summary's **Paling perlu dilihat** line.
- Diagrams go in the spec as text.

## 3. Branch, spec, mockup

No message goes out for this. In one unbroken run:

1. **Branch.** Use a worktree when
   `git status --porcelain --untracked-files=no` prints anything, or another
   session holds the checkout; otherwise this checkout. Then `git fetch origin`
   and branch from `origin/Textures`. In this checkout, restart the editor
   after the switch so its buffers match the tree. A worktree goes through
   `superpowers:using-git-worktrees`, then gets its own editor per `ship-pr` §3.
2. **Spec.** A subagent writes the design to
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` — the full Logic,
   State (name both sides across the `approved_students` ↔ `StudentData`
   bridge, e.g. `kepribadian1` (mood)), Files, and how Kelas 7/8/9 differ.
3. **Mockup — required when the feature changes a screen.** The supervisor
   draws it during the design gate below and writes the widget code to
   `.superpowers/gamecode/<topic>/mockup.html`. You render it at §6. There is
   no "the user didn't ask for a mockup" exemption: the mockup is what catches
   the class of bug a green suite cannot (CLAUDE.md's 960px empty card).

Then **the design gate**: dispatch `supervisor` over the findings file, the
spec and — if visual — the mockup path to write. Fix rounds per §5. On `LULUS`,
commit the spec.

## 4. Plan

**REQUIRED SUB-SKILL:** `superpowers:writing-plans`, in a subagent, from the
spec. Test steps read `Run: test_run(suite="<x>")`, where `<x>` is what the
suite's `suite_name()` returns — a new suite must override it, since the base
returns `"unnamed"`. In a worktree every call also passes that editor's
`session_id`. The last task runs the full suite.

Then **the plan gate**: dispatch `supervisor` over the spec and the plan. Its
pass 3 is the one that earns this gate — for each proposed test, "this passes
while ___ is broken."

## 5. Gates and fix rounds

Every gate resolves the same way. This list is closed.

- **LULUS** → next phase. Append `<phase>: complete` to the ledger.
- **UBAH** → fix round. Rounds 1–2 resume the phase's own subagent with the
  findings verbatim. Round 3 dispatches a fresh one on a more capable model.
  Three rounds is the cap for a design phase, five for a task.
- **TANYA** → the supervisor found a question only the user can answer. Do not
  stop the run for it here: carry it to the Plan Summary's **Paling perlu
  dilihat**, which is exactly what that line is for. It only becomes a stop
  when a wrong answer would make the *work already committed* worthless.
- **Minor findings never enter a fix round.** Ledger them and point the final
  sweep at that list.

At the cap, you adjudicate each open finding and write the ruling to the ledger
— `parked — <finding> — ruling: <why the work stands>`. A silent discard is
forbidden. A finding that is real *and* load-bearing is not parkable: report it
to the user and stop.

**Never fix a finding yourself.** Controller fixes skip the gate and pollute
your context for the rest of the run.

## 6. The Plan Summary — stop here

Render the mockup first with `mcp__visualize__show_widget` from the file the
supervisor wrote. Then one message, **200 words or fewer**, in the user's
language, in-game names as the game spells them. Repo-relative paths only,
never absolute ones. It has these parts, in this order, and nothing else:

```
**<Feature>** — <one sentence: what the player gets>.

Rencana: `docs/superpowers/plans/<file>.md` · Spec: `docs/superpowers/specs/<file>.md` · Branch: `feat/<topic>`

**Langkah** (semua test-first)
1. <one line per task, twelve words at most — what it does, not how it tests>
…

**Diputuskan**
- <each default taken, one line each>

**Tidak dikerjakan:** <cuts, and the rejected approach>

**Paling perlu dilihat:** <the supervisor's `Kalau ini salah`, or its
`Pertanyaan penting` when it returned TANYA — the guess most likely to be
wrong, and the cheaper alternative, with its cost now versus after the tests
are written>

Lanjut? Kalau ada yang salah, bilang sekarang.
```

**Paling perlu dilihat** is required, not optional, and it is **the
supervisor's line, not yours** — a fresh context naming the weak point, rather
than the agent that built the thing grading its own homework. That is what
makes this gate worth the user's time; a summary that reports only confidence
wastes it.

Do not restate the plan. The tasks are one line each because the plan is
linked; the user opens it when a line looks wrong.

Then **wait.** No code until they answer.

## 7. After the go-ahead — the task loop

A yes is any agreement — "yes", "ok", "gas", "lanjut", "setuju", a thumbs-up —
with or without an amendment. An amendment is folded into the plan *file*
first, then executed; re-show the summary only when the amendment changes the
task list.

**REQUIRED SUB-SKILL:** `superpowers:subagent-driven-development`, with three
changes this file makes:

1. Its task reviewer is the **supervisor**. Dispatch with the brief, the
   implementer's report, the review package and the suite output.
2. The implementer never runs `test_run`. It writes the code and the tests and
   reports `NEEDS_TESTS_RUN` with the suite names; **you** run them, rescanning
   first (a `.gd` edited from outside the editor needs a no-op `script_patch`
   to force the reload), and hand the output to both the implementer and the
   supervisor.
3. Its per-task screenshot: when a task changes a screen, take one with
   `editor_screenshot` at full size and give the supervisor the path. Judge it
   at full size — a scaled capture cannot show 1px detail, spacing or weight.

Stop only on SDD's "When to Stop" list. A failure a plan step predicts — the
red step of test-first — is progress, not a stop.

After the last task, dispatch the supervisor once over the **whole branch**
diff, pointed at the ledger's deferred-minor and parked lines.

## 8. Finish

Report in plain words: what was built, the final full run's totals, the
decisions as built, the supervisor's parked findings with their rulings, and
anything that grew past the plan. Then ask one question — **"Ship it?"**
`ship-pr` is this project's finish (CLAUDE.md); it pushes a PR that merges
itself, which the plan's yes did not cover. On yes, invoke `ship-pr`.

## 9. The improvement loop

The supervisor appends one dated line to
[FEEDBACK.md](FEEDBACK.md) on every dispatch — the finding this skill should
have prevented, or `bersih`.

After the ship question is answered, dispatch the supervisor once more in
**tuning** mode. It reads the whole ledger and:

- **Three entries of the same shape** since the last accepted change → it
  proposes a concrete `SKILL.md` diff, each line tied to the dated entries that
  justify it. Show the user the diff and the evidence, in under 80 words. Apply
  only on their yes.
- **Fewer than three** → it logs and says so. One entry is an anecdote; a rule
  invented from an anecdote is how a skill rots.

The supervisor never edits `SKILL.md` itself, and neither do you without the
user's yes. This is `superpowers:writing-skills`' Iron Law with the ledger as
the failing case: no skill edit without evidence of the failure first.

## Inline mode

`/gamecode --inline <idea>` runs the phases in this session instead of
dispatching them. The supervisor still runs as a subagent — that never changes.

Use it when the user wants to watch and steer, or for a change small enough
that a brief would restate the whole task. Everything else stays subagent-driven:
fresh context per phase is what stops an early wrong reading propagating to the
PR, which is the failure this pipeline exists to prevent.

Four things are **always** inline, flag or no flag, because they are yours:

1. Anything through the Godot bridge (§0).
2. Git operations that rewrite the tree.
3. Every message to the user.
4. Adjudicating a finding at the fix-round cap (§5).

Offer inline mode once, in one clause, when the user is clearly present and
the feature is a single-file change. Do not ask otherwise.

## Red flags

- You are about to dispatch a subagent that would call `mcp__godot-ai__*`.
- You are running the supervisor's checks yourself to save a dispatch.
- A phase advanced on a verdict you did not read.
- You fixed a supervisor finding yourself instead of resuming the phase agent.
- The feature changes a screen and no mockup exists at §6.
- **Paling perlu dilihat** is your own assessment rather than the supervisor's.
- A finding vanished without a ledger line.
- You are writing the fourth fix round of a design phase. The cap is three —
  adjudicate.
