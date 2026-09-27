# PR1 — Balance.gd Proposal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Balance.gd proposal doc for the collaborator with the short-run pacing numbers, difficulty ladder, sliding star threshold, wirausaha bump, and depth-mechanics constants — so they can review and edit Balance.gd themselves (per CLAUDE.md convention: we never edit Balance.gd).

**Architecture:** Single markdown doc under `docs/superpowers/plans/` with the numbers, the math, the holiday note, and the exact code snippet for the new constants. Nothing else changes in this PR.

**Tech Stack:** Markdown. No code.

**Spec:** `docs/superpowers/specs/2026-09-11-balance-and-depth-design.md`, sections "PR1 — Balance.gd proposal" and "Decisions (locked)".

## Global Constraints

- Balance.gd is owned by a collaborator; **never edit it directly**. This PR ships proposal text only.
- Indonesian for game-facing identifiers/copy; English for engine/systems commentary in the doc.
- Conventional Commits with scope: `docs(balance): …`.
- Soft budget: keep the doc under 4000 words. Numbers, math, note, snippet — no long prose.

---

### Task 1: Write the Balance.gd proposal doc

**Files:**
- Create: `docs/superpowers/plans/2026-09-11-balance-pacing-proposal.md`

**Interfaces:**
- Consumes: nothing (self-contained).
- Produces: the numbers PR3 tests will assume once collaborator merges them into Balance.gd — specifically the new `STAR_WIN_THRESHOLD_KELAS_*`, `DIMINISHING_DAY_*`, `FOKUS_*`, `DUET_BONUS`, `STRATEGIC_MECHANICS_ENABLED` constants.

- [ ] **Step 1: Draft the proposal file with all sections**

Content structure (write exactly this outline, filled with the numbers from the spec):

```markdown
# Proposal — Balance.gd Short-Run Pacing + Depth Constants

**Date:** 2026-09-11
**Reviewer:** collaborator (Balance.gd owner)
**Spec:** docs/superpowers/specs/2026-09-11-balance-and-depth-design.md

## Why

Playtest: G7 6-week runs feel too long; G8/G9 at 12/16 weeks are a slog. Scheduling is "matching" — no tactics. Fix: shorten runs, add three depth mechanics (rotation pressure, weekly fokus, duet bonus).

## Existing constants — new values

| Constant | Current | Proposed |
|---|---|---|
| JUMLAH_MINGGU_KELAS_7 | 6 | 4 |
| JUMLAH_MINGGU_KELAS_8 | 12 | 6 |
| JUMLAH_MINGGU_KELAS_9 | 16 | 8 |
| TARGET_KENAIKAN_KELAS_7 | 15 | 10 |
| TARGET_KENAIKAN_KELAS_8 | 34 | 22 |
| TARGET_KENAIKAN_KELAS_9 | 40 | 32 |
| WIRAUSAHA_UANG_MIN | 120 | 160 |
| WIRAUSAHA_UANG_MAX | 320 | 420 |

## New constants (add to Balance.gd)

Paste this block after WIRAUSAHA section:

    static var STAR_WIN_THRESHOLD_KELAS_7 := 2.00
    static var STAR_WIN_THRESHOLD_KELAS_8 := 1.83
    static var STAR_WIN_THRESHOLD_KELAS_9 := 1.67

    static var DIMINISHING_DAY_3 := 0.70
    static var DIMINISHING_DAY_4 := 0.50
    static var DIMINISHING_DAY_5 := 0.30

    static var FOKUS_BONUS := 0.30
    static var FOKUS_PENALTY := 0.20
    static var FOKUS_WIRAUSAHA_BONUS := 0.40
    static var FOKUS_WIRAUSAHA_REST_COIN := 50

    static var DUET_BONUS := 0.15

    static var STRATEGIC_MECHANICS_ENABLED := true

STAR_WIN_THRESHOLD (the existing 2.0 flat) can be left — the per-grade lookup replaces it in PR3. If preferred, delete it once PR3 lands.

## Math

- G7: 4×5 = 20 slots ÷ 4 students = 5/student. Favorite ~6 pt/day → ~18 realistic. Target 10 = teach.
- G8: 6×5 = 30 ÷ 4 = 7.5/student. Favorite ~5 pt/day → ~22–28. Target 22 = tight.
- G9: 8×5 = 40 ÷ 4 = 10/student. Favorite ~4 pt/day → ~28–36. Target 32 = mastery.

Sliding threshold rationale: G9 target is genuinely hard, so allow more per-student slippage there (1.67/3.0 = 10 of 12 cleared with 4-student roster). G7 stays at 2.0 (8 of 12) as the teaching baseline.

## Holiday note

HOLIDAYS in Scripts/AturJadwal/atur_jadwal.gd pins week 3 (Kemerdekaan) and week 6 (Maulid). G7 at 4 weeks loses Maulid — the last week has no holiday. Options:

1. Accept — G7 gets one holiday (week 3), rest is study.
2. Remap Maulid to G7-only week 4, keyed on current_grade.

No strong preference from design — flag for your call.

## Rollout

PR3 depends on these numbers being in place. PR2 (menari bug + variety picker) is independent and can land before or after this proposal.

STRATEGIC_MECHANICS_ENABLED is a master flag so we can flip depth mechanics off without a code revert if playtest hates them.
```

- [ ] **Step 2: Sanity-check the doc**

Read it once end-to-end. Confirm every number matches the spec's Section 2 table. Confirm the snippet compiles as GDScript (no typos on `static var`, no missing colons).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-09-11-balance-pacing-proposal.md
git commit -m "docs(balance): pacing + depth-constants proposal for collaborator"
```

---

## Done when

- Doc committed on the working branch.
- Numbers cross-check against the spec's decisions table exactly.
- Handoff message to collaborator prepared (one paragraph, links to the doc, calls out the holiday question).
