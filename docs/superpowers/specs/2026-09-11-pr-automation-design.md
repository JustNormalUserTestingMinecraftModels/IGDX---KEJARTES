# Pull-request automation — design

**Date:** 2026-09-11
**Status:** approved, not yet implemented
**Scope:** repository tooling only: GitHub Actions workflows, one headless
check scene under `ci/`, one Claude Code project skill, one test suite and a
short `CLAUDE.md` section. No game script, scene, resource or asset changes
behaviour.

## Problem

Every one of the 17 PRs so far was opened and merged by hand. The repo has no
CI at all: `.github/` does not exist and GitHub reports zero workflow runs. So
nothing checks a PR before it lands on `Textures`, and a finished branch waits
until someone is at a keyboard to click Merge.

The real safety net, the editor test suite (1,309 tests on 2026-09-11), cannot
help as things stand: it runs only inside the Godot editor through the MCP
bridge and cannot run headless (`CLAUDE.md` → Testing, constraint 5).

## Goals

Automate all four steps of a PR's life:

1. **Open** — a Claude session that finishes a branch opens the PR itself and
   keeps watching it.
2. **Check** — every PR gets a headless Godot check on GitHub.
3. **Review** — the user's PRs get a Claude review locally before they open;
   every PR, anyone's, gets a cloud Claude review on GitHub once a key exists.
4. **Merge** — PRs opened from `brineoutxd` merge themselves once every gate
   is green and the branch already contains the latest `Textures`.

## Non-goals

- Running the editor test suite on GitHub. It cannot run headless; the local
  session stays the only place it runs.
- Auto-merging anyone else's PRs. The owner's and `trainer5-ctrl`'s PRs get
  the check and the cloud review as advice and are merged by hand.
- Branch protection, rulesets, GitHub's native auto-merge and the Claude
  GitHub app. All of them need the repo owner (admin), and none is required.
- Exporting builds in CI. `export_presets.cfg` is git-ignored.
- Deleting branches after a merge.
- Resolving the two PRs open today (#15, #18). They pick up the new behaviour
  once it lands; nothing here merges them.

## Decisions

| Question | Answer |
|---|---|
| Which steps to automate | Open, Check, Review, Merge — all four |
| Whose PRs merge themselves | Only PRs authored by `brineoutxd` |
| Which review gates a merge | Both: the local review and the cloud review |
| Before the owner adds the key | Don't wait: merge on the check plus both local stamps; the cloud review joins the gate by itself once the key exists |

## Facts this design rests on (verified 2026-09-11)

**The repo.** Public, so Actions minutes on standard runners are free. Owned
by the personal account `JustNormalUserTestingMinecraftModels` (admin).
`brineoutxd` has write, not admin, so repo settings, secrets, branch
protection and GitHub apps are out of the user's reach. `allow_auto_merge` is
off. Zero workflows, zero runs. PRs land on `Textures` as merge commits
("Merge pull request #N from …"). No Git LFS.

**Headless Godot can run a load-everything check.** A throwaway probe on a
fresh `git archive` copy, with Godot 4.6.2, the version the team's editor
runs:

- `--headless --import`: exit 0 in 12 s. It logs `ERROR` lines for textures
  the theme references before they are imported. That is ordering noise: the
  check run straight afterwards logged none. The import's own log is not a
  signal.
- Running a scene that loads every `.gd`, `.tscn` and `.tres`, with every
  autoload booted: 446 files, 0 failures, **0 `ERROR`/`WARNING` lines**, 5 s.
- A planted parse error is caught: the script fails `can_instantiate()`.
- A planted scene pointing at a missing texture is **not** caught by
  `load()`. Godot logs an `ERROR` and returns the scene anyway. An explicit
  check that every entry of `ResourceLoader.get_dependencies()` exists does
  catch it.
- `-REFERENCE-/prototype/` holds its own `project.godot`, so Godot ignores it.
  A naive walk loads it and reports 62 false failures, so the check must skip
  nested projects the way Godot does.

**The review action, `anthropics/claude-code-action@v1`.**

- `--json-schema` in `claude_args` exposes the verdict as the
  `structured_output` step output, read with `fromJSON()`.
- Passing `github_token` makes the Claude GitHub app optional; comments then
  post as `github-actions`.
- On a PR it restores `CLAUDE.md` and `.claude/` from the **base** branch, so
  a PR cannot rewrite the rules it is reviewed against.
- It needs `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` as a repo secret,
  and on a personal-account repo only the owner can add one.

## Architecture

```
Claude session on the user's PC                     GitHub
-------------------------------                     ------
1 merge origin/Textures into the branch
2 full editor suite (test_run) -> fix until green
3 local review (/code-review) -> fix real findings
4 push, gh pr create, stamp the pushed commit:
    kejartes/editor-tests  success "1309/1309 passed"
    kejartes/local-review  success ----------------->  PR by brineoutxd
                                                         |- project-check  (headless load-all)
                                                         |- claude-review  (once a key exists)
                                                         '- auto-merge: every gate green
                                                              + contains latest Textures
                                                              + mergeable, not draft, no `hold`
                                                              -> merge commit into Textures
5 the app's Auto-fix wakes the session on a red check,
  a conflict, a review comment or "Textures moved" -> back to 1
```

### 1. Project check

Files: `ci/project_check.gd`, `ci/project_check.tscn`,
`.github/workflows/project-check.yml`.

`ci/project_check.tscn` is a bare `Node` running `ci/project_check.gd`. Run as
the main scene, it boots every autoload first, so an autoload that errors on
boot fails the check, which is wanted. Then it walks `res://`:

- skip dot-folders, folders holding a `.gdignore`, and folders holding their
  own `project.godot`;
- for every `.gd`: `load()` it and require `can_instantiate()`;
- for every `.tscn` and `.tres`: require every
  `ResourceLoader.get_dependencies()` entry to exist (a `uid://` entry through
  `ResourceUID`, falling back to the path Godot recorded beside it), then
  require `load()` to return non-null;
- print `PROJECT CHECK: checked N files, M failures` and one line per failure,
  then `quit(1)` on any failure.

The script is `@tool` with `_ready()` gated behind `Engine.is_editor_hint()`
(`CLAUDE.md` → Testing, constraint 3), so a suite can load it and call its
static helpers. It lives in `res://ci/` because the hygiene suites scan
`res://Scripts`, `res://Scenes` and `res://tests`, and one of them forbids
`print` under `Scripts/`; a CI tool's whole job is to print. It still carries
the `##` documentation the project requires everywhere.

The workflow runs on `pull_request` (opened, synchronize, reopened,
ready_for_review) against any base, on `push` to `Textures`, and on
`workflow_dispatch`, with per-ref `concurrency` that cancels superseded runs.
One job, named `project-check`, on `ubuntu-latest`, `timeout-minutes: 15`:

1. check out the PR;
2. download `Godot_v4.6.2-stable_linux.x86_64.zip` (68 MB) from the
   `godotengine/godot` `4.6.2-stable` release and verify it against the
   release's published SHA-512 sums;
3. `godot --headless --path . --import`, keeping its log but not judging it;
4. `godot --headless --path . res://ci/project_check.tscn`, failing on a
   non-zero exit **or** on any `ERROR` / `SCRIPT ERROR` line in its output
   (the clean baseline has none), and listing any `WARNING` lines in the job
   summary without failing.

The Godot version is pinned in one place in the workflow and must match the
editor the team uses.

### 2. Cloud review

File: `.github/workflows/claude-review.yml`.

Runs on `pull_request` (opened, synchronize, reopened, ready_for_review) for
every non-draft PR, whoever opened it. `concurrency` is per PR with
`cancel-in-progress`, so a burst of pushes pays for one review.

- Job `detect` reports whether either secret exists.
- Job `claude-review` runs only if one does. Without a key it is **skipped**,
  not failed, so it neither shows a red X nor wakes a session for something
  only the owner can fix.

`claude-review` checks out the PR and runs the action pinned to a full commit
SHA with a `# v1` comment, since it handles a secret on a public repo. It
passes `github_token: ${{ github.token }}` and needs `contents: read` and
`pull-requests: write`. The prompt asks it to review the diff against
`CLAUDE.md`'s rules, post inline comments only for real problems, and return
`{"verdict": "pass" | "block", "blocking": [...]}` through `--json-schema`.
`block` is reserved for defects that must be fixed before merging. A final
step reads the verdict through an environment variable, never interpolated
into the script, and fails the job on `block`. Allowed tools:
`mcp__github_inline_comment__create_inline_comment`, `Bash(gh pr diff:*)`,
`Bash(gh pr view:*)`, `Bash(gh pr comment:*)`. The model and a `--max-turns`
cap are set explicitly in `claude_args`; the values are chosen in the plan.

### 3. Auto-merge

Files: `.github/workflows/auto-merge.yml`, `ci/auto_merge.sh`.

The workflow gathers context and calls the script, so the rules live in one
reviewable file that can also run locally with `DRY_RUN=1`. It always checks
out `Textures`, so a PR cannot change the rules that merge it.

Triggers: `workflow_run` (Project check or Claude review completed), `status`
(a stamp landed), `pull_request` (closed, labeled, unlabeled,
ready_for_review), `push` to `Textures`, `schedule` every 30 minutes as a
safety net, and `workflow_dispatch`. `concurrency: auto-merge` without
cancel-in-progress, so evaluations never overlap. Permissions:
`contents: write`, `pull-requests: write`, `statuses: write`, `checks: read`.
The workflow passes `CLOUD_REVIEW=on` to the script when either review secret
exists.

For each open PR, `ci/auto_merge.sh` merges when **all** of these hold for the
PR's current head commit:

| Gate | Source |
|---|---|
| author is `brineoutxd`, base is `Textures`, not a draft, no `hold` label | the PR |
| check run `project-check` concluded `success` | GitHub |
| status `kejartes/editor-tests` is `success` | the local session |
| status `kejartes/local-review` is `success` | the local session |
| check run `claude-review` concluded `success`, **only when `CLOUD_REVIEW=on`** | GitHub |
| the head contains the current `Textures` head (compare API, `behind_by == 0`) | GitHub |
| GitHub reports the PR `MERGEABLE` | GitHub |

It merges with `gh pr merge <n> --merge --match-head-commit <sha>`, so a push
that lands mid-evaluation aborts the merge instead of slipping in untested. It
never deletes branches.

It has two side duties:

- **Out of date.** When everything else passes but `Textures` has moved on,
  it posts a failing `kejartes/up-to-date` status on the head commit, once,
  reading "Textures moved — merge it in and re-run the suite". That red check
  is what wakes the owning session.
- **Stacked PRs.** After any merge, its own or one a person made (the
  `closed` trigger), it re-points `brineoutxd`'s open PRs that were based on
  the merged PR's branch, so they target the merged PR's own base instead.
  When the owner merges #15, #18 moves to `Textures` by itself.

Stamps belong to one commit, so any push clears them automatically. Only a
commit that was itself tested and reviewed can merge, and because it must
already contain `Textures`, the merged tree is exactly the tested tree.

### 4. Ship procedure

File: `.claude/skills/ship-pr/SKILL.md`.

A project skill a session runs when a branch is finished ("ship it", "open
the PR"), and again whenever the app wakes it about that PR:

1. Refuse on `Textures`, on a detached HEAD, or with a dirty tree.
   `git fetch origin`.
2. Merge `origin/Textures` in. Resolve the changelog by hand. Never hand-merge
   `Assets/Theme/kejartes_theme.tres`; rebake it (`CLAUDE.md` → Visual
   system).
3. Run the full suite with `test_run` in the editor that has **this** checkout
   open; a worktree needs its own editor. Fix real breakage. A failure
   unrelated to the branch stops the procedure and is reported, with no stamp.
4. Run `/code-review` over the branch diff against `origin/Textures`. Fix what
   is real. If code changed, go back to step 3.
5. `git push -u origin HEAD`, then `gh pr create --base Textures` (or the
   parent branch, for stacked work) if no PR exists. The body carries the
   summary, the suite totals and the review summary.
6. Stamp the pushed commit, which must be the commit that was tested:
   `gh api repos/{owner}/{repo}/statuses/<sha> -f state=success
   -f context=kejartes/editor-tests -f description="<passed>/<total> passed"`,
   and the same for `kejartes/local-review` ("<n> findings fixed, 0 open").
7. Turn on the app's Auto-fix monitor for the PR where the app offers it, so
   the session is woken on red checks, conflicts and review comments. The app
   asks the user to approve.
8. When woken: fix, then go back to step 2. Never stamp a commit that was not
   tested.

A stamp asserts only what the session saw. That is the same trust the team
already places in "I ran the suite before pushing", now written onto the
commit where a machine can read it.

### 5. `CLAUDE.md`

A short `## Pull requests` section: the pipeline in three lines, the rules
(only `brineoutxd` auto-merges; the `hold` label; stamps belong to one
commit), and pointers to this spec and the skill. `## Current work` names this
branch while it is in flight, per the file's own maintenance rules.

## What needs the owner

1. **Optional: the cloud review.** Add one repository secret, either
   `CLAUDE_CODE_OAUTH_TOKEN` (made with `claude setup-token` on a paid Claude
   plan; reviews count toward that plan's limits) or `ANTHROPIC_API_KEY`
   (Claude Console, billed per use). Until one exists, reviews are skipped and
   do not gate merges.
2. **Only if the setup PR shows no checks:** allow Actions under Settings →
   Actions → General.

Nothing else: no app, no branch protection, no other settings change.

## Failure handling

| Situation | What happens |
|---|---|
| Project check fails | The PR's check goes red; Auto-fix wakes the session. |
| Cloud review returns `block` | The check fails with the blocking list, and inline comments show where. Auto-fix wakes the session. |
| Merge conflict | GitHub flags it; Auto-fix wakes the session, which reruns the skill from step 2. |
| `Textures` moved | `kejartes/up-to-date` goes red; the session merges `Textures` in, re-tests and re-stamps. |
| Someone else pushes to the branch | The stamps no longer match the head commit, so nothing merges until a session re-tests. |
| The key is added while PRs are open | Their heads have no review run yet, so they wait; a push, or re-running the review from the PR's Checks tab, starts one. |
| The owning session is gone | The PR waits. That is the safe state; any new session can pick it up with the skill. |
| The Godot download fails | The check fails; re-run the job. |
| An event is missed | The 30-minute schedule re-evaluates every open PR. |

## Testing

- **Check logic:** `tests/test_project_check.gd`, an `McpTestSuite` (`@tool`,
  no coroutines), covers the static helpers: the skip rules (dot-folder,
  `.gdignore`, nested `project.godot`) and dependency parsing (a `uid://`
  entry with a known uid, an unknown uid with a fallback path, a plain path, a
  missing path).
- **Check, end to end:** run the workflow's two Godot commands locally with
  the 4.6.2 console build on a `git archive` copy. The clean tree passes; a
  planted parse error, a planted missing texture and a planted autoload that
  errors on boot each fail.
- **Merge rules:** `DRY_RUN=1 ci/auto_merge.sh` against the real repo must
  report #15 skipped (author) and #18 skipped (base), and print each gate it
  evaluated.
- **Full suite:** the editor suite still passes with the new files in place;
  the documentation and hygiene suites must not trip on `ci/`.
- **Live, after the setup PR lands:** a tiny test PR shipped through the skill
  must merge by itself; a `hold`-labelled one and an unstamped one must not.

## Rollout

1. Build and verify everything above in the `feat/pr-automation` worktree.
2. Open the setup PR. Its own `project-check` runs, because `pull_request`
   workflows run from the PR's files. `claude-review` is skipped (no key).
3. **Merge the setup PR by hand.** GitHub runs `workflow_run`, `status` and
   `schedule` workflows only from the default branch, so nothing can merge
   itself until this lands.
4. Run the live test from Testing. Confirm the app's Auto-fix wakes a session
   on a failing commit status, not only on a failing check run. If it does
   not, the skill tells a resumed session to read the PR's status first.

## Risks

- **Stamps run on trust.** Anyone with write access can post a status. The
  gate trusts the user's own sessions, which is the trust already in place.
- **The cloud review costs per push.** It runs on every push to every
  non-draft PR; per-PR concurrency cancels superseded runs.
- **Schedules drift.** GitHub delays cron runs under load. The schedule is
  only a safety net; events drive the normal path.
- **A merge by the workflow's token triggers no further workflows**, so
  `project-check` does not re-run on `Textures` after an automatic merge. The
  merged tree is a tested tree, so nothing is lost.
- **Actions may be disabled** on the repo, and the user cannot see that
  setting. Step 2 of the rollout shows it at once.
