# Project-guide restructure and memory seeding — design

**Date:** 2026-09-05
**Status:** approved, not yet implemented
**Scope:** documentation and agent-context only. No `.gd`, `.tscn`, `.tres` or
asset file is touched. The game builds, runs and tests identically before and
after.

## Problem

`CLAUDE.md` is injected verbatim into every Claude Code session before the user
types anything. It is the project's entire cross-session memory. It has grown to
**27,619 characters**, and the growth is not evenly distributed:

| Section | Chars | Share |
|---|---:|---:|
| `## Current work` | 10,734 | 39% |
| `## Working efficiently here` | 6,614 | 24% |
| `## Visual system` | 2,417 | 9% |
| `## The game` | 2,313 | 8% |
| `## Architecture` | 1,723 | 6% |
| `## Known issues` | 1,306 | 5% |
| `## Testing` | 1,142 | 4% |
| `## Godot MCP` | 574 | 2% |
| `## Conventions` | 496 | 2% |

Three specific defects follow from this.

**1. `## Current work` is largely a prose duplicate of an index already on
disk.** Every paragraph in it has a matching document in
`docs/superpowers/specs/` (13 files) or `docs/superpowers/plans/` (41 files).
The convention — append a paragraph per completed pass — is the only recorded
maintenance rule, so the section regrows to the same size every few passes.

**2. Current-state facts are buried inside archival narrative, where they
contradict the sections above them.** `## The game` describes a flow that
`## Current work` later corrects; the star win rule
(`run_stars() >= Balance.STAR_WIN_THRESHOLD`) is stated 300 lines away from the
rules it governs. A reader who trusts the first statement is wrong.

**3. Live debt is scattered.** Placeholder assets, aliased audio cues,
`[PLACEHOLDER]` cutscene lines and deferred items are each mentioned inside the
pass paragraph that created them, so there is no single place to see what is
still outstanding. Meanwhile `## Known issues` says "None outstanding."

Separately, the file-based memory directory at
`~/.claude/projects/<project-slug>/memory/` is **empty**. Facts that do not
belong in a repo document — the user's working preferences, corrections given in
past sessions, and the reasons behind decisions — have nowhere to live, so they
are lost between sessions.

## Goals

- Cut always-loaded context by roughly a third without deleting any information.
- Make every fact in `CLAUDE.md` findable in the section it governs.
- Give live debt one home.
- Stop `## Current work` from regrowing.
- Seed the memory directory with facts mined from past sessions, not invented.

## Non-goals

- Rewriting `## Working efficiently here`'s five numbered rules. They are the
  highest-value text in the file and stay verbatim.
- Verifying the project's *gameplay and code* claims against source — const
  values, function names, suite counts. See "Accepted risk". (Verification check
  2 below does check that cited **document paths** resolve; that is a different,
  cheaper thing.)
- Cleaning the four stale worktrees in `.claude/worktrees/`. Separate task.
- Touching the 16 uncommitted in-flight endgame files.

## Design

### 1. Three-way split of `## Current work`

Each paragraph is classified into exactly one of three destinations:

| Kind | Example | Destination |
|---|---|---|
| **Current state** | "TesNotice → ExamProgress → StatCheck → RunResult → MainMenu is now accurate"; the star win rule | Merged **up** into the topical section it corrects |
| **Live debt** | `sfx_specialty_match` aliases `sfx_reward`; the six minigame cue ids alias `pop.ogg`/`reward.ogg`; `[PLACEHOLDER]` cutscene lines; `RunGrade` weights pending balance; unused `LombaMenari.best_combo`; the deferred `ShelfEdge` variation; the `test_viewport_editability.gd` `BASELINE` debt | New `## Outstanding debt & placeholders` |
| **Narrative history** | "built via subagent-driven development"; "one fix round needed a human editor restart"; "took roughly forty-five calls and failed twice" | `docs/superpowers/CHANGELOG.md` |

If a paragraph resists classification it **stays in `CLAUDE.md`** and is flagged
in the completion report. Erring toward keeping costs a few hundred characters;
erring toward eviction loses a fact.

### 2. Target structure

| Section | Before | After | Change |
|---|---:|---:|---|
| Header | 6 lines | same | — |
| `## The game` | 2,313 | ~2,600 | Absorbs corrected end-game flow and star win rule |
| `## Architecture` | 1,723 | same | — |
| `## Visual system` | 2,417 | same | — |
| `## Testing` | 1,142 | same | Dated counts gain as-of tags |
| `## Godot MCP` | 574 | same | — |
| `## Working efficiently here` | 6,614 | ~5,500 | Rules verbatim; war-story tails trimmed |
| `## Known issues` | 1,306 | — | Replaced by the row below |
| `## Outstanding debt & placeholders` | — | ~1,500 | **New** |
| `## Current work` | 10,734 | ~800 | In-flight work only |
| `## Maintaining this file` | — | ~600 | **New** |
| `## Conventions` | 496 | ~600 | Gains the `Balance.gd` ownership line |
| **Total** | **27,619** | **~18,000** | **−35%**, about 2.5k tokens per session |

### 3. `docs/superpowers/CHANGELOG.md`

New file. Newest-first. One entry per completed pass, each carrying the prose
evicted from `## Current work` and links to its spec and plan. Nothing is
summarised away; the text moves intact.

### 4. `## Maintaining this file`

A roughly 600-character section stating the rule that prevents regrowth:

- A completed pass gets an entry in `CHANGELOG.md`, not a paragraph here.
- A fact that changes how someone works on the project goes in the topical
  section it governs.
- An unfinished placeholder or deferred item goes in
  `## Outstanding debt & placeholders`, and is deleted when resolved.
- `## Current work` holds only what is in flight right now.
- Soft budget: keep the file under about 20,000 characters.

It is self-enforcing because it is always loaded.

### 5. `Balance.gd` ownership

`## Conventions` gains a line recording that `Balance.gd` values are owned by a
collaborator and must not be changed. This is stated in memory as well, but it is
load-bearing enough to belong in the always-loaded file: `CLAUDE.md` currently
documents retuning `TARGET_KENAIKAN_KELAS_8`,
`MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7/8/9` and
`SKIP_PELUANG_KALAH_KELAS_7/8/9`, which reads as licence to edit those values.

### 6. Memory seeding

Six files in `~/.claude/projects/<project-slug>/memory/`, each holding one fact,
each mined from a past session transcript rather than invented. Sourcing: 53 real
user turns extracted from 7 session transcripts (about 4.4 KB after stripping
auto-compaction summaries).

| Slug | Type | Source |
|---|---|---|
| `balance-gd-owned-by-collaborator` | project | 2026-09-04: "the balance.gd will always change because my collaborator is the one handling that, make sure its values not changed" |
| `assets-arrive-via-downloads-folder` | project | 2026-09-01, three times: "all new asset are in the /downloads folder" |
| `run-full-suite-before-pushing` | feedback | 2026-09-04: "re-run the full suite, fix whatever's genuinely broken, and only then push" |
| `works-async-wants-autonomous-execution` | user | 2026-09-01: "i will be go for a few hours… write a couple of multi step plan so you can work automatically even when im gone" |
| `active-collaborator-pull-merge-is-routine` | project | six pull/merge requests across four sessions |
| `prefers-plain-language-and-diagrams` | user | 2026-09-04: "can you explain it in an easy to understand way?"; "explain how the end game works with flowchart" |

Each file carries the required frontmatter (`name`, `description`,
`metadata.type`); `feedback` and `project` entries carry **Why:** and **How to
apply:** lines. Related entries are linked with `[[wikilinks]]`
(`balance-gd-owned-by-collaborator` with
`active-collaborator-pull-merge-is-routine`; `run-full-suite-before-pushing` with
`works-async-wants-autonomous-execution`). A `MEMORY.md` index carries one
pointer line per file.

The GitHub remote URL is deliberately **excluded** — `git remote -v` already
records it, and memory must not duplicate what the repo holds.

## Verification

A documentation change has no test suite. Three mechanical checks instead:

1. **Nothing lost.** `git show HEAD:CLAUDE.md` is the reference. A script
   confirms every paragraph of the old `## Current work` now appears in either
   `CHANGELOG.md` or a topical section, by content match.
2. **No broken pointers.** Every `docs/superpowers/**` path cited in the new
   `CLAUDE.md` and `CHANGELOG.md` resolves to a real file. The current file cites
   `.superpowers/sdd/…` ledgers that its own text says were deleted after merge;
   those are expected failures and get rewritten or dropped.
3. **Size check.** Report real before/after character counts against the ~18,000
   target.

`test_run` is not required — no suite reads `CLAUDE.md`.

## Execution and scope guard

| Step | Action | Commit |
|---|---|---|
| 1 | Write six memory files plus `MEMORY.md` | none — outside the repo |
| 2 | Build `docs/superpowers/CHANGELOG.md` | staged |
| 3 | Rewrite `CLAUDE.md` | staged |
| 4 | Run the three verification checks | — |
| 5 | Show the full diff, then one commit | one commit, two paths |

Work happens on branch `Textures`. `git add` receives exactly two explicit paths.
No `git commit -a`, `git stash`, `git checkout` or `git reset` is run. The 16
uncommitted in-flight endgame files are never staged.

## Accepted risk

Facts are promoted from existing documentation **without being verified against
source** — a deliberate choice to keep the pass cheap. Two known-dated claims are
already suspect: "45 suites, 568 tests, all green (2026-09-01)" and "Known issues
(as of 2026-08-31)", both predating the uncommitted endgame work.

Mitigation: every dated claim carries its as-of date when promoted, so a future
session sees the claim's age rather than reading it as timeless truth. This does
not eliminate the risk, and a later verification pass against source remains
worth doing.
