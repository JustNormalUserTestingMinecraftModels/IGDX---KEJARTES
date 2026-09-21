# Dispatch contracts

Templates for `/gamecode`'s dispatches. Fill the angle brackets; keep the
shape. Paths are repo-relative.

## The block every dispatch carries

Paste this verbatim into every subagent dispatch, including the supervisor's.
It is what keeps the Godot bridge single-client.

> **Bridge rule.** Do not call any `mcp__godot-ai__*` tool, do not launch Godot,
> and do not run `godot` from a shell. The editor takes one client and the
> controller holds it — connecting displaces the whole run. When you need a
> suite run, an editor screenshot or a rescan, write what you need in your
> report and stop there; the controller runs it and comes back to you.
>
> **Artifacts are files.** Write your work to the paths below and return only
> the short contract at the end of this prompt. Do not paste file contents back.

## Phase subagent (recon, spec, plan)

```
<one line: where this feature fits in KejarTes>

Read first — these are your requirements, with the exact values to use verbatim:
- <brief or spec path>
- CLAUDE.md, and `docs/superpowers/DEBT.md` for anything already known-broken

Write your output to: <artifact path>
Write your report to:  <report path>

<the bridge-rule block>

Return: STATUS (DONE | NEEDS_CONTEXT | BLOCKED), the artifact path, and at most
three concerns. Nothing else.
```

## Supervisor gate

Dispatch with `subagent_type: "supervisor"`. A newly added agent file is not
always registered in an already-running session; if that type is rejected,
dispatch `general-purpose` on the most capable model and open the prompt with:

> Read `.claude/agents/supervisor.md` FIRST and follow it exactly — it is your
> complete role definition, including your passes, your required verdict slots
> and your red flags.

Either way the supervisor's own file carries its passes and its verdict
contract — do not restate them here.

```
Phase: <recon | spec | mockup | plan | task <N> | branch | tuning>
Feature: <topic>

Review:
- <artifact path(s)>
- <the implementer's report path, for a task gate>
- <the review package / diff path, for a task gate>
- <the suite output path — I ran it, this is what it printed>
- <the screenshot path, for a task that changed a screen>

Binding constraints for this phase, copied from the spec:
<verbatim: exact values, exact formats, the stated relationships between
components — "same layout as X", "matches Y". This block is the supervisor's
attention lens; do not paraphrase it.>

<if visual> Write the mockup widget code to: .superpowers/gamecode/<topic>/mockup.html
Write your verdict to: <report path>

<the bridge-rule block>

Return the Verdict line, the finding headlines, and Pertanyaan penting.
```

**Never pre-judge for the supervisor.** If the dispatch you are writing contains
"do not flag", "don't treat X as a defect", "at most Minor", or "the spec already
chose this" — stop. You are buying yourself a shorter gate by blinding the only
fresh reader in the run. Let it raise the finding and adjudicate it at the cap.

## Implementer (task loop)

Follows `superpowers:subagent-driven-development`'s implementer template, plus:

```
<the bridge-rule block>

Do not run tests yourself — you cannot reach the editor. Write the code and the
tests, then report STATUS = NEEDS_TESTS_RUN with the suite names, exactly as
`suite_name()` returns them. I will run them and send you the output.
```

The controller then, in order: rescans (a `.gd` written from outside the editor
needs a no-op `script_patch` on that same file to force the reload — it logs a
benign `GDScript reload failed with error code 43` and then works), runs
`test_run(suite=...)`, and returns the output to the implementer. Prefer
targeted runs; a full run drops the bridge and costs an editor restart.

## Tuning (end of run)

```
Phase: tuning
Read: .claude/skills/gamecode/FEEDBACK.md (the whole file) and
      .claude/skills/gamecode/SKILL.md

Find the patterns: three or more entries of the same shape since the last
accepted change. For each, propose the exact SKILL.md lines to change, with the
dated entries that justify them.

Fewer than three of a shape: say so and propose nothing. One entry is an
anecdote.

Write to: <report path>. Return the proposed diff and its evidence, under 80
words.

<the bridge-rule block>
```
