# Project-guide restructure and memory seeding — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut `CLAUDE.md` from 27,619 to about 18,000 characters by relocating (never deleting) its archival narrative, and seed the empty memory directory with six facts mined from past session transcripts.

**Architecture:** Three-way split of `## Current work` — current-state facts merge up into the topical section they govern, live placeholder debt consolidates into one new standing section, and completed-pass narrative moves verbatim to a new `docs/superpowers/CHANGELOG.md`. A new `## Maintaining this file` section encodes the rule that prevents regrowth. Memory files live outside the repo and are never committed.

**Tech Stack:** Markdown, `git`, Python 3.14 (verification scripts only). No Godot, no GDScript, no `test_run`.

## Global Constraints

- **Documentation only.** No `.gd`, `.tscn`, `.tres`, `.svg`, `.import` or `project.godot` file may be created, modified or deleted. If a task appears to require one, stop and ask.
- **Scope guard.** The restructure commit (Task 5) stages exactly the two explicit paths `CLAUDE.md` and `docs/superpowers/CHANGELOG.md`. Never run `git commit -a`, `git stash`, `git checkout`, `git reset`, or `git clean`. The 16 uncommitted in-flight endgame files must remain unstaged and unmodified throughout. (This plan file and its spec are committed separately, before Task 1.)
- **Shell variables** used throughout, define once per session:

```bash
REPO="C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
MEMDIR="$HOME/.claude/projects/C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/memory"
SCRATCH="C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/edb748e5-d7db-4db0-8118-515f53ad8351/scratchpad"
```
- **Branch:** `Textures` (this is also the main branch — user has consented to working here directly).
- **Nothing is deleted.** Every evicted paragraph must land in `CHANGELOG.md` or a topical section. If a paragraph resists classification, leave it in `CLAUDE.md` and flag it in the completion report.
- **Dated claims carry their date.** Any promoted claim with an as-of date keeps it (e.g. "45 suites, 568 tests, all green (2026-09-01)"). Never restate a dated claim as timeless.
- **Memory files are never committed.** They live at `$HOME/.claude/projects/C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/memory/`, outside the repo.
- **Balance.gd values are collaborator-owned.** Do not edit them; do not restate specific `Balance.gd` constant values as authoritative in `CLAUDE.md`.
- **Scratchpad for throwaway scripts:** `C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/edb748e5-d7db-4db0-8118-515f53ad8351/scratchpad`. Verification scripts go here, not in the repo.

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `CLAUDE.md` | modify | Always-loaded project guide. After this plan: current facts, live debt, in-flight work, and the maintenance rule. No completed-pass narrative. |
| `docs/superpowers/CHANGELOG.md` | create | Newest-first archive of completed passes. Read on demand, never auto-loaded. |
| `$MEMDIR/*.md` (6 files) | create | One fact each, mined from transcripts. Outside repo. |
| `$MEMDIR/MEMORY.md` | create | One-line index pointing at each memory file. |
| `$SCRATCH/verify_restructure.py` | create | Three mechanical checks. Throwaway, outside repo. |
| `$SCRATCH/verify_memory.py` | create | Frontmatter and wikilink validation. Throwaway, outside repo. |

## Paragraph classification (locked)

Line numbers refer to `CLAUDE.md` at commit `4b892b9`. Verify with `git show 4b892b9:CLAUDE.md` if the file has drifted.

| Lines | Paragraph | Destination |
|---|---|---|
| 290–295 | `## Known issues` intro + tracked `BASELINE` debt | → `## Outstanding debt & placeholders` |
| 296–313 | Resolved issues 1, 2, 3 | → `CHANGELOG.md` |
| 316 | "Branch `Textures`…" | **stays** |
| 318–324 | 2026-09-04 end-game rebuild (Plans B/C in flight) | **stays** |
| 326–335 | `ExamProgress` pacing beat + `StatCheck` description | **stays** |
| 337–340 | "The win rule moved with it…" | → `CHANGELOG.md` (already stated in `## The game`; this is a duplicate) |
| 342–373 | 2026-09-04 grade-progression difficulty pass | → `CHANGELOG.md` |
| 375–381 | 2026-08-31 main menu rebuild | → `CHANGELOG.md` |
| 383–384 | 2026-08-30 stability sweep | → `CHANGELOG.md` |
| 386–394 | 2026-09-01 art pass | → `CHANGELOG.md` |
| 396–406 | 2026-09-02 AturJadwal polish pass | → `CHANGELOG.md` |
| 408–412 | **Deferred:** `ShelfEdge` | → `## Outstanding debt & placeholders` |
| 414–438 | 2026-09-02 end-of-grade sequence | → `CHANGELOG.md`; its placeholders → debt section |
| 440–460 | 2026-09-03 Daily Results polish pass | → `CHANGELOG.md`; its placeholders → debt section |
| 462–478 | 2026-09-04 minigame reward pass | → `CHANGELOG.md`; its placeholders → debt section |
| 480–484 | `-REFERENCE-/prototype/` note | → merge up into `## Architecture` |

---

### Task 1: Seed the memory directory

Independent of every other task — touches nothing in the repo. Do this first so its findings are available while rewriting `CLAUDE.md`.

**Files:**
- Create: `$MEMDIR/balance-gd-owned-by-collaborator.md`
- Create: `$MEMDIR/assets-arrive-via-downloads-folder.md`
- Create: `$MEMDIR/run-full-suite-before-pushing.md`
- Create: `$MEMDIR/works-async-wants-autonomous-execution.md`
- Create: `$MEMDIR/active-collaborator-pull-merge-is-routine.md`
- Create: `$MEMDIR/prefers-plain-language-and-diagrams.md`
- Create: `$MEMDIR/MEMORY.md`
- Test: `$SCRATCH/verify_memory.py`

where `MEMDIR="$HOME/.claude/projects/C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/memory"`

**Interfaces:**
- Consumes: nothing.
- Produces: the six slugs above, referenced by `[[wikilink]]` from each other and by `MEMORY.md`. Task 4 references `balance-gd-owned-by-collaborator` when writing the `## Conventions` line.

- [ ] **Step 1: Write the failing validation script**

Create `$SCRATCH/verify_memory.py`:

```python
import os, re, sys

MEMDIR = os.path.expanduser(
    "~/.claude/projects/"
    "C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/memory")

EXPECTED = {
    "balance-gd-owned-by-collaborator": "project",
    "assets-arrive-via-downloads-folder": "project",
    "run-full-suite-before-pushing": "feedback",
    "works-async-wants-autonomous-execution": "user",
    "active-collaborator-pull-merge-is-routine": "project",
    "prefers-plain-language-and-diagrams": "user",
}

fail = []
slugs = set()

for slug, want_type in EXPECTED.items():
    path = os.path.join(MEMDIR, slug + ".md")
    if not os.path.exists(path):
        fail.append("MISSING FILE: " + slug + ".md")
        continue
    slugs.add(slug)
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        fail.append(slug + ": no valid frontmatter block")
        continue
    fm, body = m.group(1), m.group(2).strip()
    if not re.search(r"^name:\s*" + re.escape(slug) + r"\s*$", fm, re.M):
        fail.append(slug + ": name: does not match filename")
    if not re.search(r"^description:\s*\S", fm, re.M):
        fail.append(slug + ": missing description:")
    if not re.search(r"^\s+type:\s*" + want_type + r"\s*$", fm, re.M):
        fail.append(slug + ": metadata.type is not '" + want_type + "'")
    if not body:
        fail.append(slug + ": empty body")
    if want_type in ("project", "feedback"):
        if "**Why:**" not in body:
            fail.append(slug + ": " + want_type + " entry missing **Why:** line")
        if "**How to apply:**" not in body:
            fail.append(slug + ": " + want_type + " entry missing **How to apply:** line")

index = os.path.join(MEMDIR, "MEMORY.md")
if not os.path.exists(index):
    fail.append("MISSING FILE: MEMORY.md")
else:
    idx = open(index, encoding="utf-8").read()
    if idx.lstrip().startswith("---"):
        fail.append("MEMORY.md must not have frontmatter")
    for slug in EXPECTED:
        if slug + ".md" not in idx:
            fail.append("MEMORY.md: no pointer line for " + slug)

for slug in slugs:
    text = open(os.path.join(MEMDIR, slug + ".md"), encoding="utf-8").read()
    for link in re.findall(r"\[\[([^\]]+)\]\]", text):
        if link not in EXPECTED:
            fail.append(slug + ": wikilink [[" + link + "]] targets no planned memory")

print("\n".join(fail) if fail else "OK: 6 memories + index valid")
sys.exit(1 if fail else 0)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
python "$SCRATCH/verify_memory.py"
```

Expected: exit 1, six `MISSING FILE:` lines plus `MISSING FILE: MEMORY.md` (the directory is currently empty).

- [ ] **Step 3: Write the six memory files**

`balance-gd-owned-by-collaborator.md`:

```markdown
---
name: balance-gd-owned-by-collaborator
description: Balance.gd values are maintained by the user's collaborator; never change them
metadata:
  type: project
---

`Scripts/.../Balance.gd` is owned by the user's collaborator, not by us. Its
constant values change frequently from their side. Read them freely; never
edit them.

**Why:** Stated directly on 2026-09-04 — "the balance.gd will always change
because my collaborator is the one handling that, make sure its values not
changed". CLAUDE.md works against this: it documents past retunes of
`TARGET_KENAIKAN_KELAS_8`, `MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7/8/9`
and `SKIP_PELUANG_KALAH_KELAS_7/8/9`, which reads as licence to edit them.

**How to apply:** If a task seems to need a Balance value changed, say so and
propose it — do not make the edit. When merging or resolving conflicts, take
the collaborator's Balance values, not ours. Verify Balance values are
unchanged before pushing. See [[active-collaborator-pull-merge-is-routine]].
```

`assets-arrive-via-downloads-folder.md`:

```markdown
---
name: assets-arrive-via-downloads-folder
description: New art and assets are dropped in the Windows /Downloads folder, not into the repo
metadata:
  type: project
---

The user delivers new art by placing files in the Windows Downloads folder
(`C:/Users/user/Downloads/`) and referring to it as "the /downloads folder".
Assets are not pre-imported into `Assets/`.

**Why:** Recurring across sessions on 2026-09-01 — "use the splash art that i
gave, all new asset are in the /downloads folder", "use the
meja_background.png in the /downloads folder as the backdrop". Looking for
these files inside the repo wastes a search every time.

**How to apply:** When the user says they "gave" an asset or names one that
isn't in `Assets/`, list the Downloads folder before asking where it is. Copy
it into the right `Assets/` subdirectory and let Godot import it; don't work
from the Downloads path directly.
```

`run-full-suite-before-pushing.md`:

```markdown
---
name: run-full-suite-before-pushing
description: Run the whole test suite and fix real breakage before pushing, without being asked
metadata:
  type: feedback
---

Before any push, run the full suite via the Godot MCP `test_run`, fix what is
genuinely broken, and only then push.

**Why:** Given as an explicit instruction on 2026-09-04 — "re-run the full
suite, fix whatever's genuinely broken, and only then push." The word
"genuinely" matters: the ask is to distinguish real breakage from noise, not
to chase every red line.

**How to apply:** Treat "push" as implying a verification pass first. Report
the actual suite numbers rather than asserting it passes. If something fails
that is unrelated to the current change, say so and ask rather than silently
fixing or silently pushing. Pairs with
[[works-async-wants-autonomous-execution]] — the user is often away, so the
verification has to happen without a prompt.
```

`works-async-wants-autonomous-execution.md`:

```markdown
---
name: works-async-wants-autonomous-execution
description: User frequently steps away and expects long autonomous multi-step execution
metadata:
  type: user
---

The user often leaves for hours mid-task and expects work to continue without
them. Sessions are full of "continue where you left off", "continue the
remaining task", "okay now continue".

**Why:** Asked directly on 2026-09-01 — "i will be go for a few hours, so i
want to ask couple question: can you start a new chat automatically? ... write
a couple of multi step plan so you can work automatically even when im gone."

**How to apply:** Prefer written plans with checkboxes over conversational
step-by-step, so progress survives a context break. Batch independent work
instead of stopping to confirm each step. Reserve blocking questions for
decisions that are genuinely unsafe to guess. When stopping, leave a clear
statement of what is done and what is next.
```

`active-collaborator-pull-merge-is-routine.md`:

```markdown
---
name: active-collaborator-pull-merge-is-routine
description: A second contributor pushes to the same repo; pull and merge are routine, not exceptional
metadata:
  type: project
---

This repo has an active second contributor. Pulling and merging their work is
a normal, frequent operation — six such requests across four sessions between
2026-09-01 and 2026-09-04 ("now pull", "merge", "scan the git and pull and
merge all the new one").

**Why:** Work regularly lands from outside our sessions, so local state can be
stale even when our own tree is clean. Assuming the branch is ours alone
produces avoidable conflicts.

**How to apply:** Before starting substantial work, check whether the remote
has moved. Expect conflicts in shared files and resolve them in the
collaborator's favour where the file is theirs — most importantly
[[balance-gd-owned-by-collaborator]].
```

`prefers-plain-language-and-diagrams.md`:

```markdown
---
name: prefers-plain-language-and-diagrams
description: Prefers plain-language explanations and diagrams over dense technical prose
metadata:
  type: user
---

The user asks for explanations in simple terms and reaches for diagrams:
"scan and explain the how the end game works with flowchart" (2026-09-04) and,
after a dense answer, "can you explain it in an easy to understand way?"
(2026-09-04). English appears to be a second language.

**How to apply:** Lead with the plain-language answer, then the detail. Prefer
tables, flowcharts and short sentences over long technical paragraphs. Define
project jargon on first use. When explaining a flow across several scenes or
systems, draw it rather than describing it in prose.
```

`MEMORY.md`:

```markdown
# Memory index — KejarTes

- [Balance.gd is collaborator-owned](balance-gd-owned-by-collaborator.md) — read its values, never change them.
- [Assets arrive via /Downloads](assets-arrive-via-downloads-folder.md) — new art is dropped in the Windows Downloads folder, not the repo.
- [Run the suite before pushing](run-full-suite-before-pushing.md) — full `test_run`, fix real breakage, then push.
- [Works async, wants autonomy](works-async-wants-autonomous-execution.md) — often away for hours; plan for unattended execution.
- [Active collaborator](active-collaborator-pull-merge-is-routine.md) — a second contributor pushes here; pull and merge are routine.
- [Plain language and diagrams](prefers-plain-language-and-diagrams.md) — lead with the simple answer; draw the flow.
```

- [ ] **Step 4: Run the validation script to verify it passes**

```bash
python "$SCRATCH/verify_memory.py"
```

Expected: `OK: 6 memories + index valid`, exit 0.

- [ ] **Step 5: Confirm nothing entered the repo**

```bash
git status --porcelain
```

Expected: exactly the 16 pre-existing in-flight entries, plus the untracked plan file. No memory file may appear.

**No commit** — memory lives outside the repo.

---

### Task 2: Build the restructure verification harness

Written before the restructure so it demonstrably fails first.

**Files:**
- Create: `$SCRATCH/verify_restructure.py`

**Interfaces:**
- Consumes: `git show 4b892b9:CLAUDE.md` as the reference copy.
- Produces: a three-check pass/fail report consumed by Task 5.

- [ ] **Step 1: Write the harness**

Create `$SCRATCH/verify_restructure.py`:

```python
import os, re, subprocess, sys

REPO = ("C:/Users/user/Downloads/KejarTestAlphaVer2.15/"
        "KejarTestAlphaVer2.15/new-game-project")
REF = "4b892b9"
TARGET_MAX = 20000

os.chdir(REPO)

def read(p):
    return open(p, encoding="utf-8").read() if os.path.exists(p) else ""

old = subprocess.run(["git", "show", REF + ":CLAUDE.md"],
                     capture_output=True, text=True, encoding="utf-8").stdout
new = read("CLAUDE.md")
chg = read("docs/superpowers/CHANGELOG.md")

fail = []

# Check 1 — nothing lost. Every non-trivial sentence of the old Current work
# and Known issues sections must survive somewhere.
start = old.find("## Known issues")
evicted = old[start:old.find("## Conventions")] if start != -1 else ""
haystack = new + "\n" + chg
missing = []
for sent in re.split(r"(?<=[.!?])\s+", evicted.replace("\n", " ")):
    s = " ".join(sent.split())
    if len(s) < 60 or s.startswith("#"):
        continue
    if " ".join(s.split()) not in " ".join(haystack.split()):
        missing.append(s[:90])
if missing:
    fail.append("CHECK 1 FAIL - %d sentence(s) lost:" % len(missing))
    fail += ["    " + m for m in missing[:12]]

# Check 2 — every cited docs path resolves.
for label, text in (("CLAUDE.md", new), ("CHANGELOG.md", chg)):
    for path in sorted(set(re.findall(r"`(docs/superpowers/[^`\s]+\.md)`", text))):
        if not os.path.exists(path):
            fail.append("CHECK 2 FAIL - %s cites missing path: %s" % (label, path))
    for stale in sorted(set(re.findall(r"`(\.superpowers/[^`\s]+)`", text))):
        if not os.path.exists(stale):
            fail.append("CHECK 2 FAIL - %s cites deleted ledger: %s" % (label, stale))

# Check 3 — size.
print("SIZE: old=%d  new=%d  changelog=%d  (target new <= %d)"
      % (len(old), len(new), len(chg), TARGET_MAX))
if len(new) > TARGET_MAX:
    fail.append("CHECK 3 FAIL - CLAUDE.md is %d chars, over the %d budget"
                % (len(new), TARGET_MAX))

print("\n".join(fail) if fail else "OK: all three checks pass")
sys.exit(1 if fail else 0)
```

- [ ] **Step 2: Run it against the current, un-restructured tree**

```bash
python "$SCRATCH/verify_restructure.py"
```

Expected: exit 1. Check 1 fails (no `CHANGELOG.md` yet, so evicted sentences are only in `CLAUDE.md` — they will pass trivially, so expect the real signal from checks 2 and 3), check 2 flags the `.superpowers/sdd/...` ledgers the file admits were deleted, check 3 reports `new=27619` and fails the 20,000 budget. Record this output; it is the "before" evidence.

**No commit** — the harness is a scratchpad throwaway.

---

### Task 3: Create `docs/superpowers/CHANGELOG.md`

**Files:**
- Create: `docs/superpowers/CHANGELOG.md`

**Interfaces:**
- Consumes: the paragraph classification table above; paragraph text from `git show 4b892b9:CLAUDE.md`.
- Produces: a file whose content satisfies check 1 for every evicted paragraph. Task 4 links to it from `## Maintaining this file`.

- [ ] **Step 1: Extract the source paragraphs verbatim**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
git show 4b892b9:CLAUDE.md > "$SCRATCH/claude_md_ref.md"
sed -n '290,313p;337,340p;342,478p' "$SCRATCH/claude_md_ref.md" > "$SCRATCH/evicted.md"
wc -c "$SCRATCH/evicted.md"
```

Expected: roughly 10,500 characters.

- [ ] **Step 2: Write the file header and entries**

Header, verbatim:

```markdown
# KejarTes — change log

Completed work, newest first. This file is **not** loaded into Claude Code
sessions; `CLAUDE.md` is. Anything here is history — read it on demand when you
need to know why something is the way it is.

Facts that still govern how you work on the project belong in `CLAUDE.md`, not
here. Unfinished placeholders belong in its `## Outstanding debt & placeholders`
section. See `CLAUDE.md`'s `## Maintaining this file`.
```

Then one `## ` entry per pass, newest first, in this order. Each entry carries its source paragraph **verbatim** — do not summarise, reword or trim; check 1 compares sentences literally. Add only the heading and the `**Spec:**` / `**Plan:**` link lines.

| Order | Heading | Source lines | Links to add |
|---|---|---|---|
| 1 | `## 2026-09-04 — Grade-progression balance and difficulty` | 342–373 | Spec: `docs/superpowers/specs/2026-09-04-grade-progression-balance-and-difficulty.md`; Plan: `docs/superpowers/plans/2026-09-04-grade-progression-balance-and-difficulty.md` |
| 2 | `## 2026-09-04 — Minigame reward feedback` | 462–478 | Plan: `docs/superpowers/plans/2026-09-04-minigame-reward-feedback.md` |
| 3 | `## 2026-09-04 — The star win rule` | 337–340 | none (superseded — now stated in `CLAUDE.md`'s `## The game`) |
| 4 | `## 2026-09-03 — Daily Results polish and rewards` | 440–460 | Spec: `docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md` |
| 5 | `## 2026-09-02 — End-of-grade sequence` | 414–438 | Spec: `docs/superpowers/specs/2026-09-02-end-of-grade-sequence.md`; Plan: `docs/superpowers/plans/2026-09-02-end-of-grade-sequence.md` |
| 6 | `## 2026-09-02 — AturJadwal warning frame and StatBar polish` | 396–406 | Spec: `docs/superpowers/specs/2026-09-02-atur-jadwal-warning-and-statbar-polish.md`; Plan: `docs/superpowers/plans/2026-09-02-atur-jadwal-warning-and-statbar-polish.md` |
| 7 | `## 2026-09-01 — Art pass and screen restyle` | 386–394 | Spec: `docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md` |
| 8 | `## 2026-08-31 — Main menu mockup rebuild` | 375–381 | Spec: `docs/superpowers/specs/2026-08-31-main-menu-mockup.md`; Plan: `docs/superpowers/plans/2026-08-31-main-menu-mockup-match.md` |
| 9 | `## 2026-08-30 — Project stability sweep` | 383–384, 296–313 | Spec: `docs/superpowers/specs/2026-08-30-project-stability-sweep-findings.md`; Plan: `docs/superpowers/plans/2026-08-30-project-stability-sweep.md` |

Entry 9 merges the stability-sweep paragraph with the three resolved `## Known issues` entries (the audio-director coroutine test, the `test_audio_coverage` double-SFX non-repro, and the stale `ext_resource` UIDs), since those record what that sweep closed.

- [ ] **Step 3: Strip references to deleted ledgers**

The source text cites `.superpowers/sdd/2026-09-02-end-of-grade-sequence/progress.md` and `.superpowers/sdd/2026-09-03-day-summary-polish-and-rewards/progress.md`, and says in the same breath that both were "deleted after merge". Check 2 will fail on these.

In entries 4 and 5, replace each such citation with the parenthetical `(its SDD ledger was deleted after merge)`. Keep the surrounding sentence otherwise intact.

- [ ] **Step 4: Verify every link resolves**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
grep -o '`docs/superpowers/[^`]*\.md`' docs/superpowers/CHANGELOG.md \
  | tr -d '`' | sort -u | while read -r p; do
      test -f "$p" && echo "OK   $p" || echo "MISS $p"
    done
```

Expected: every line begins `OK`. Any `MISS` must be fixed before proceeding — check the real filename in `docs/superpowers/plans/` or `specs/`.

- [ ] **Step 5: Stage only this file**

```bash
git add docs/superpowers/CHANGELOG.md
git status --porcelain | grep '^[AM]'
```

Expected: exactly one line, `A  docs/superpowers/CHANGELOG.md`.

**No commit yet** — committed together with `CLAUDE.md` in Task 5, per the spec.

---

### Task 4: Rewrite `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` — sections `## Architecture`, `## Testing`, `## Working efficiently here`, `## Known issues` (replaced), `## Current work` (shrunk), `## Conventions`; two new sections.

**Interfaces:**
- Consumes: `docs/superpowers/CHANGELOG.md` from Task 3; the slug `balance-gd-owned-by-collaborator` from Task 1.
- Produces: a `CLAUDE.md` under 20,000 characters that satisfies all three checks.

Sections **not** touched: the header, `## The game`, `## Visual system`, `## Godot MCP`. `## The game` already carries the corrected end-game flow and the star win rule as of commit `af0f93d`; no merge-up is needed there.

- [ ] **Step 1: Delete the evicted paragraphs from `## Current work`**

Remove lines 337–340 and 342–478 (the classification table's `→ CHANGELOG.md` and `→ debt` rows). Keep lines 316, 318–324 and 326–335 — the branch note and the two in-flight end-game paragraphs.

Append this closing line to the section:

```markdown
Everything completed before this is in `docs/superpowers/CHANGELOG.md`.
```

- [ ] **Step 2: Replace `## Known issues` with the debt section**

Delete the whole `## Known issues` section (lines 290–313) and put this in its place:

```markdown
## Outstanding debt & placeholders

Live, unfinished items. Delete an entry when it is resolved — do not mark it
done and leave it here.

**Audio placeholders.** Several `AudioDirector` cue ids alias existing streams
rather than having their own: `sfx_specialty_match` → `sfx_reward`; `tally` and
`sparkle` → existing SFX files; `star_earn_1/2/3`, `result_fanfare`,
`score_tick`, `combo_up` → `pop.ogg` / `reward.ogg`; and the BGM ids
`exam_notice`, `exam_cutscene`, `run_result` → existing tracks.

**Art placeholders.** The three particle sprites
(`Assets/Images/Particles/particle_*.png`) are crude flat geometry. The seven
minigame result icons and the report icons
(`Assets/Images/UI/Placeholders/icon_*.svg`) are flat white placeholder
geometry — real transparent SVGs, but not final art. The exam and win cutscene
backdrops reuse the intro's CG images.

**Copy placeholders.** Every cutscene line in the exam and win branches is
marked `[PLACEHOLDER]`.

**Pending a balance pass.** `RunGrade`'s scoring weights — especially
`MONEY_FULL_MARKS` — are estimates. `LombaMenari.best_combo` is tracked but not
yet fed into the star rubric.

**Deferred: the AturJadwal shelf.** It ships as two `ColorRect`s rather than the
intended `ShelfEdge` theme variation. A new `@export` on `DesignTokens` is
invisible to a running editor, so this needs an editor restart plus a manual
rebake. The exact diff to re-apply is in the STATUS block of
`docs/superpowers/plans/2026-09-01-atur-jadwal-mockup.md`.

**Ratchet debt.** `tests/test_viewport_editability.gd`'s `BASELINE` still lists
real unconverted runtime UI construction across roughly 20 files. The
2026-08-31 pass converted every shared-across-screens case but did not survey
every remaining file. The list and what each would need is in the authoring
guide's "Known gaps" section.

No outstanding *bugs* as of 2026-08-31 — the 2026-08-30 stability sweep closed
the previous three. See `docs/superpowers/CHANGELOG.md`.
```

- [ ] **Step 3: Merge the prototype note up into `## Architecture`**

Append to the end of `## Architecture` (after the two-student-representations subsection), verbatim from lines 480–484:

```markdown
`-REFERENCE-/prototype/` is the original prototype, kept for reference only —
not built, not imported. `koprasi&inventory` was a second programmer's separate
project; the spec's Asset Policy documents exactly which of its art is
finished (copy byte-identical) versus placeholder chrome (restyle onto our
theme).
```

- [ ] **Step 4: Trim the war-story tails in `## Working efficiently here`**

Keep all five numbered rules and their instructions **verbatim**. Remove only the retrospective anecdote sentences that justify a rule already stated:

- In rule 1: drop "Driving the shop purchase flow by simulated clicks to reach the same state took roughly forty-five calls and failed twice before working."
- In rule 5: drop the 2026-09-02 `ThemeFactory.gd` / `StatBar.gd` narrative sentences, keeping the rule itself ("A no-op `script_patch` on that same file forces the reload — add and remove a blank line", the error-code-43 note, and "Cheapest reliable fix: make edits through `script_patch` in the first place").

Do not touch rules 2, 3 or 4. Do not touch the closing paragraphs on the single-client MCP bridge or the coverage floor.

- [ ] **Step 5: Add `## Maintaining this file`**

Insert immediately before `## Conventions`:

```markdown
## Maintaining this file

This file is injected into every session before the user speaks. Everything in
it costs context on every single run, so it earns its place or it moves.

- A **completed pass** gets an entry in `docs/superpowers/CHANGELOG.md`, newest
  first — not a paragraph here.
- A fact that **changes how you work on the project** goes in the topical
  section it governs, not in `## Current work`.
- An **unfinished placeholder or deferred item** goes in `## Outstanding debt &
  placeholders`, and is deleted when resolved.
- `## Current work` holds **only what is in flight right now**. When it lands,
  it moves to the changelog.
- Soft budget: keep this file under **20,000 characters**. It was 27,619 on
  2026-09-05, of which 39% was completed-pass narrative.

Rationale and the full restructure record:
`docs/superpowers/specs/2026-09-05-project-guide-restructure-and-memory-seeding-design.md`.
```

- [ ] **Step 6: Add the `Balance.gd` ownership line to `## Conventions`**

Append as a new bullet:

```markdown
- **`Balance.gd` values are owned by a collaborator, not by us.** Read them
  freely; never change them. If a task appears to need a different value, say
  so and propose it rather than editing. On merge, take their version of that
  file.
```

- [ ] **Step 7: Run the harness**

```bash
python "$SCRATCH/verify_restructure.py"
```

Expected: `OK: all three checks pass`, and a `SIZE:` line showing `new` at roughly 17,000–18,500. If check 1 reports lost sentences, put each one back — into `CHANGELOG.md` if it is narrative, into the relevant `CLAUDE.md` section if it is a live fact.

- [ ] **Step 8: Stage only the two doc paths**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git diff --cached --name-only
```

Expected: exactly two lines, `CLAUDE.md` and `docs/superpowers/CHANGELOG.md`. If any `Scripts/`, `Scenes/`, `Assets/` or `tests/` path appears, unstage it with `git restore --staged <path>` and investigate.

**No commit yet** — Task 5.

---

### Task 5: Review and commit

**Files:**
- Modify: none. Verification and commit only.

**Interfaces:**
- Consumes: the staged pair from Tasks 3 and 4.
- Produces: one commit on `Textures`.

- [ ] **Step 1: Re-run both harnesses**

```bash
python "$SCRATCH/verify_memory.py" && python "$SCRATCH/verify_restructure.py"
```

Expected: both print `OK`, both exit 0.

- [ ] **Step 2: Confirm no engine file is staged**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
git diff --cached --name-only
```

Expected output, exactly these two lines and no others:

```
CLAUDE.md
docs/superpowers/CHANGELOG.md
```

If anything else appears, stop and unstage it.

- [ ] **Step 3: Show the user the diff and wait**

```bash
git diff --cached --stat
git diff --cached -- CLAUDE.md
```

Present the section-by-section summary and the before/after sizes. **Wait for the user's approval before committing** — the spec's execution table makes this an explicit gate.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
git commit -m "docs: restructure the project guide and archive completed passes

CLAUDE.md is injected into every session, and had grown to 27,619 chars with
39% of it a completed-pass changelog duplicating the spec and plan documents
already on disk.

Splits that section three ways: current-state facts merge up into the topical
section that governs them, live placeholder debt consolidates into a new
Outstanding debt & placeholders section replacing Known issues, and completed
pass narrative moves verbatim to docs/superpowers/CHANGELOG.md. Adds a
Maintaining this file section so the changelog section cannot regrow, and
records in Conventions that Balance.gd values are collaborator-owned.

Nothing is deleted; every paragraph is relocated. Documentation only -- no
engine, script or asset file is affected.

Spec: docs/superpowers/specs/2026-09-05-project-guide-restructure-and-memory-seeding-design.md

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Confirm the in-flight work is untouched**

```bash
git status --porcelain
```

Expected: the same 16 in-flight endgame entries as before this plan started, unmodified and unstaged.

- [ ] **Step 6: Report**

State the real before/after character counts, the number of paragraphs relocated, any paragraph that resisted classification and was left in place, and confirm that no file outside the two doc paths was written. Do not push — [[run-full-suite-before-pushing]] applies, and this change touches no code to test, so pushing is the user's call.

---

## Deviation from the spec

**`## The game` does not grow.** The spec's target-structure table projects it
at 2,313 → ~2,600 chars, "absorbs corrected end-game flow and star win rule".
Checking the file, both were *already* merged up by commits `2f51827` and
`af0f93d`: `## The game` already states the `TesNotice → ExamProgress →
StatCheck → RunResult → MainMenu` sequence and the `run_stars() >= 2.0` win
rule. So lines 337–340 of `## Current work` are a straight duplicate and are
evicted to the changelog rather than merged anywhere.

Consequence: the only current-state merge-up left is the
`-REFERENCE-/prototype/` note into `## Architecture` (Task 4, step 3), and the
final size lands slightly *under* the spec's ~18,000 estimate. This is the spec
being conservative, not scope being cut — no fact is lost either way.

## Notes on deviations from the writing-plans defaults

- **One commit, not per-task commits.** The approved spec fixes this (`## Execution and scope guard`, step 5). `CLAUDE.md` and `CHANGELOG.md` are two halves of one relocation; an intermediate commit would leave `CLAUDE.md` pointing at a changelog that does not yet exist.
- **No `test_run`.** No Godot suite reads `CLAUDE.md`. The two Python harnesses are the test cycle, and both are written before the change they check.
