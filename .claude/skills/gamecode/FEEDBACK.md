# gamecode — feedback ledger

Evidence for the skill's improvement loop (`SKILL.md` §9). The supervisor
appends one line per dispatch; nobody edits `SKILL.md` from fewer than three
entries of the same shape.

Format:

```
- YYYY-MM-DD · <phase> · <feature> · <LULUS|UBAH|TANYA> · <the finding the skill
  should have prevented, or `bersih`>
```

## Accepted changes

- **2026-09-21 — the supervisor gate.** Every phase now runs in a fresh
  subagent and is reviewed by `.claude/agents/supervisor.md` before the next
  begins. Justified by the three seed entries below, all from the same run.

- **2026-09-21 — the mockup width is stated as a literal.** Two validation
  dispatches drew the same spec; one used `viewBox="0 0 680 740"`, the other a
  648px container with no 680 anywhere. Deferring to `showwidget`'s rule by
  reference was not binding, so the supervisor's **Mockups** section now states
  the number and says to pad inside it. Variance across reps is the signal:
  when guidance lands, reps converge on the same shape.

## Seed evidence (2026-09-21, mined from `docs/superpowers/CHANGELOG.md`)

These are the failures that produced the supervisor. They predate the ledger,
so they were reconstructed from the changelog rather than logged live.

- 2026-09-21 · task · minigame type ladder · UBAH · **A green suite is not a
  correct result.** `QuestionCard` shipped pinned at 960px so the choices could
  not move. Every test passed. On device, ~10 of 11 fallback questions rendered
  as a 960px empty field around one line of text. Only a screenshot showed it.
  → became supervisor pass 4 (*Draw it*) and pass 3 (*Would a green suite miss
  this?*).

- 2026-09-21 · spec · minigame type ladder · UBAH · **A constant was trusted
  instead of checked.** `SoalFit.FALLBACK_BOX` was 699×333, describing a 715×345
  card that had grown to 850×480 some time earlier. The reasoning built on it
  was sound; the number was stale.
  → became supervisor pass 1 (*Claims vs. tree*) and the required **Diperiksa**
  block with `file:line` per claim.

- 2026-09-21 · plan · minigame type ladder · UBAH · **Two real layout bugs
  survived planning** — PilihanGanda's image sat above the progress counter
  which sat above the question it referred to, and a `visible` toggle inside a
  centre-aligned `VBoxContainer` moved the choice buttons under the player's
  thumb mid-game. Neither was in the plan; both were found while building.
  → became the design gate at §3 and the *worst real data* re-read in
  **Mockups**.

## Live entries

<!-- newest last; the supervisor appends here -->
