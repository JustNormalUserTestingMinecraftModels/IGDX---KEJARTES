---
name: ship-pr
description: Use when a branch's work is finished and should become a pull request that merges itself - "ship it", "open the PR", "send this for merge" - and again whenever the app wakes this session about that PR (a red check, a merge conflict, a review comment, or "Textures moved"). Runs the full editor suite and a local Claude review, pushes, opens the PR, and stamps the tested commit so GitHub's merge gate can merge it.
---

# Ship a PR

The local half of the pull-request automation. GitHub checks the PR
(`project-check`), reviews it (`claude-review`, once the owner adds a key) and
merges it (`ci/auto_merge.sh`), but only when this procedure has stamped the
exact commit it tested.

Design: `docs/superpowers/specs/2026-09-11-pr-automation-design.md`.

The gate merges only PRs authored by `brineoutxd` into `Textures`. Anyone can
run this skill; other people's PRs simply wait for a person to merge them.

## 1. Preflight

Stop and report, rather than continue, if any of these fails:

- `git branch --show-current` prints a branch, and it is not `Textures`.
- `git status --porcelain` prints nothing.
- `git fetch origin` succeeds.

## 2. Bring in the latest Textures

Run `git merge origin/Textures`. Resolve conflicts like this:

- `docs/superpowers/CHANGELOG.md`: keep both sides' entries, newest first.
- `Assets/Theme/kejartes_theme.tres`: never merge it by hand. Take either
  side, then rebake (CLAUDE.md → "Rebaking without File > Run") and check the
  bake by its content.
- `Scripts/Balance.gd`: take the collaborator's version (CLAUDE.md →
  Conventions).
- Anything else: resolve it properly, and say what you did in the PR.

## 3. Run the full editor suite

Run `test_run` with no `suite`, in the editor that has **this checkout** open:

- **The main checkout:** the bridge's usual editor.
- **A worktree** under `.claude/worktrees/<name>`: it needs its own editor.
  Copy `imported/`, `shader_cache/`, `uid_cache.bin`,
  `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main
  checkout's `.godot/` into the worktree's, launch
  `<Godot editor exe> --path <worktree> -e` in the background, find its session
  with `session_manage(op="list")`, and pass that `session_id` to every call.
  Never call `session_activate`, and never kill every Godot process.

A full run can drop the bridge (CLAUDE.md → Working efficiently here); its
results still count once they have arrived. Afterwards run `git status` and
`git checkout --` `Assets/Audio/default_bus_layout.tres` or
`Assets/Theme/kejartes_theme.tres` if the run changed them and you did not
mean it to.

Fix genuine failures this branch caused, then run the suite again. If a
failure has nothing to do with the branch, stop, report it and do not stamp.
Note the totals as `<passed>/<total>`.

## 4. Review the branch locally

Invoke the `code-review` skill at effort `high` on this branch. Weigh each
finding (superpowers:receiving-code-review): fix the real ones and note why you
rejected the rest. If you changed any code, commit it and go back to step 3.

## 5. Push and open the PR

```bash
git push -u origin HEAD
gh pr view --json number,url || gh pr create --base Textures --title "<type(scope): summary>" --body-file <file>
```

For stacked work, use the parent branch as `--base`. The body says what
changed, the suite totals, and the review summary: findings fixed, findings
rejected and why.

## 6. Stamp the tested commit

Only when steps 3 and 4 passed on this exact commit:

```bash
if [ -n "$(git status --porcelain)" ] || [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]; then
  echo "STOP: HEAD is not the clean, pushed commit that was tested"
else
  SHA=$(git rev-parse HEAD)
  gh api --silent -X POST "repos/{owner}/{repo}/statuses/$SHA" \
    -f state=success -f context=kejartes/editor-tests -f description="<passed>/<total> passed"
  gh api --silent -X POST "repos/{owner}/{repo}/statuses/$SHA" \
    -f state=success -f context=kejartes/local-review -f description="<n> findings fixed, 0 open"
fi
```

Never stamp a commit the suite did not run on. A new commit needs new stamps.

## 7. Let the app watch the PR

If the Claude desktop app's PR tools are available, the app bound the PR when
you ran `gh pr create` or pushed. Call `mcp__ccd_pr__set_monitor` with the
PR's url and `auto_fix: true` (the user approves it), so this session is woken
on a red check, a merge conflict or a review comment.

## 8. When the app wakes you

- **`project-check` failed:** read the log (`gh run view --log-failed`), fix,
  then go to step 2.
- **`claude-review` blocked:** read its inline comments. Fix what is real,
  answer what is not, then go to step 2.
- **A merge conflict, or `kejartes/up-to-date` failed:** go to step 2.
- **A comment from a person:** address it; if code changed, go to step 2.

## Stopping a merge

Label the PR `hold`, or mark it as a draft. Anyone can still merge by hand.

A PR that changes anything under `.github/workflows/` never merges itself:
GitHub's workflow token is not allowed to change workflow files, so the gate
skips it. Merge those by hand.
