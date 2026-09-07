---
name: context-audit
description: Use when the always-loaded agent context file (CLAUDE.md / AGENTS.md) has grown bloated, stale, or is accumulating completed-work narrative, and when seeding the file-based memory directory from past session transcripts. Restructures the file so nothing is lost, installs a rule that stops it regrowing, and mines memory from real evidence rather than inventing it. Trigger on "audit CLAUDE.md", "CLAUDE.md is too long", "self improve", "clean up the project guide", "seed memory", or a request to cut always-loaded context.
---

# Context-file self-improvement pass

Restructure this project's always-loaded agent context (CLAUDE.md/AGENTS.md);
seed memory from evidence. Cut size, lose nothing, stop regrowth.

**1. Measure.** Table: total chars, chars + % per `##` section, which sections
duplicate files already on disk. No proposals before this table.

**2. Classify every paragraph three ways.** Two-way splits lose facts —
finished-work narrative has live facts embedded in it.
- **Current state** (changes how you work today, or contradicts a section
  above) → merge UP into the section it governs
- **Live debt** (placeholder, deferred item, known gap) → one standing
  `## Outstanding debt` section
- **History** (finished pass) → `docs/CHANGELOG.md`, verbatim

Lock the classification as a table with line ranges against a pinned SHA
before editing. Unclassifiable → keep in place and flag it.

**3. Approve.** Present target structure, before/after sizes, out-of-scope.
Batch up front: verify claims against source or trust docs? memory source?
install a maintenance rule? If trusting docs, still carry each claim's as-of
date when promoting it.

**4. Verify before changing.** Script three checks, run pre-change to watch
them fail: (a) every evicted sentence appears in the new file or archive, vs
`git show <sha>:<file>`; (b) every cited path resolves; (c) size vs budget.
Check (a) is a literal-substring scan, so any section you legitimately
*synthesize* trips it — verify each flag by hand, label it, and never pad the
file back out to satisfy the harness.

**5. Scope guard.** `git add` explicit paths only, never `-a` or `.`; confirm
with `git diff --cached --name-only`. No stash/checkout/reset/clean —
unrelated work may be uncommitted. Memory files are never committed.

**6. Grep for lost RULES, not lost text.** Section review catches dropped
paragraphs but misses *imperatives* that rode a narrative paragraph into the
archive. Grep the old file for never/always/must/do not/banned/before
touching; confirm each still appears in the new always-loaded file. Highest-
value check in the pass.

**Memory: mine, don't invent.** Real user turns from
`~/.claude/projects/<slug>/*.jsonl` (`type=="user"`, string content); drop
compaction summaries and system reminders — most of the bytes, none of the
signal. One fact per file: frontmatter (`name`, `description`,
`metadata.type`: user|feedback|project|reference), **Why:** / **How to
apply:** on project+feedback entries, `[[wikilinks]]`, one pointer line each
in `MEMORY.md`. Exclude what the repo already records. Approve the list before
writing. A mined constraint that contradicts the context file is the pass's
best finding — fix the file too, don't just record it.

**7. Maintenance rule.** Add `## Maintaining this file`: completed passes →
changelog; working facts → topical section; unfinished → debt section, deleted
when resolved; in-flight section holds only in-flight work; soft char budget.
Self-enforcing because always loaded.

**Report:** real before/after counts, relocated vs deleted (deleted should be
0), every finding left unfixed and why, every claim promoted unverified.
