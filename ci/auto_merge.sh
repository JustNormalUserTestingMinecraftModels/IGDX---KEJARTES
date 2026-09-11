#!/usr/bin/env bash
# The merge gate for pull requests
# (docs/superpowers/specs/2026-09-11-pr-automation-design.md).
#
# .github/workflows/auto-merge.yml runs it on every relevant event. Locally,
# DRY_RUN=1 prints each decision and every command it would run, and changes
# nothing:
#
#     DRY_RUN=1 bash ci/auto_merge.sh
#
# gate_decision() is pure and unit-tested by ci/test_auto_merge.sh. Everything
# that talks to GitHub goes through gh, using gh's own --jq.
set -euo pipefail

AUTO_MERGE_AUTHOR="${AUTO_MERGE_AUTHOR:-brineoutxd}"
AUTO_MERGE_BASE="${AUTO_MERGE_BASE:-Textures}"
HOLD_LABEL="hold"
CHECK_RUN="project-check"
REVIEW_RUN="claude-review"
TESTS_STAMP="kejartes/editor-tests"
REVIEW_STAMP="kejartes/local-review"
OUTDATED_STAMP="kejartes/up-to-date"

# gate_decision key=value...  prints exactly one line:
#   merge            every gate is green
#   outdated         every gate is green, but the base has moved on
#   wait: <reasons>  a PR this gate merges, but a gate is not green yet
#   skip: <reason>   not a PR this gate merges
# Keys: author base draft hold project_check editor_tests local_review
# cloud_review(on|off) claude_review behind_by mergeable. A missing key counts
# as not green. Returns 2 on an unknown key.
gate_decision() {
  local author="" base="" draft="" hold="" project_check="" editor_tests=""
  local local_review="" cloud_review="off" claude_review="" behind_by="" mergeable="" kv
  for kv in "$@"; do
    case "$kv" in
      author=*)        author="${kv#*=}" ;;
      base=*)          base="${kv#*=}" ;;
      draft=*)         draft="${kv#*=}" ;;
      hold=*)          hold="${kv#*=}" ;;
      project_check=*) project_check="${kv#*=}" ;;
      editor_tests=*)  editor_tests="${kv#*=}" ;;
      local_review=*)  local_review="${kv#*=}" ;;
      cloud_review=*)  cloud_review="${kv#*=}" ;;
      claude_review=*) claude_review="${kv#*=}" ;;
      behind_by=*)     behind_by="${kv#*=}" ;;
      mergeable=*)     mergeable="${kv#*=}" ;;
      *) echo "gate_decision: unknown argument '$kv'" >&2; return 2 ;;
    esac
  done

  if [[ "$author" != "$AUTO_MERGE_AUTHOR" ]]; then echo "skip: author is ${author:-unknown}"; return 0; fi
  if [[ "$base" != "$AUTO_MERGE_BASE" ]]; then echo "skip: base is ${base:-unknown}"; return 0; fi
  if [[ "$draft" == "true" ]]; then echo "skip: draft"; return 0; fi
  if [[ "$hold" == "true" ]]; then echo "skip: labelled $HOLD_LABEL"; return 0; fi

  local reasons=()
  [[ "$project_check" == "success" ]] || reasons+=("$CHECK_RUN is ${project_check:-missing}")
  [[ "$editor_tests" == "success" ]] || reasons+=("$TESTS_STAMP is ${editor_tests:-missing}")
  [[ "$local_review" == "success" ]] || reasons+=("$REVIEW_STAMP is ${local_review:-missing}")
  if [[ "$cloud_review" == "on" && "$claude_review" != "success" ]]; then
    reasons+=("$REVIEW_RUN is ${claude_review:-missing}")
  fi
  [[ "$mergeable" == "MERGEABLE" ]] || reasons+=("mergeable is ${mergeable:-unknown}")
  if [[ ! "$behind_by" =~ ^[0-9]+$ ]]; then
    reasons+=("distance from $AUTO_MERGE_BASE is unknown")
  elif (( behind_by > 0 && ${#reasons[@]} > 0 )); then
    reasons+=("behind $AUTO_MERGE_BASE by $behind_by")
  fi

  if (( ${#reasons[@]} > 0 )); then
    local joined
    joined="$(printf '%s; ' "${reasons[@]}")"
    echo "wait: ${joined%; }"
    return 0
  fi
  if (( behind_by > 0 )); then echo "outdated"; return 0; fi
  echo "merge"
}

# Runs a command that changes GitHub, or only prints it under DRY_RUN=1.
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "DRY_RUN: $*"; else "$@"; fi
}

# The conclusion of the newest check run named $2 on commit $1:
# success, failure, skipped, ... ; "pending" while it runs; "missing" if none.
check_conclusion() {
  gh api "repos/{owner}/{repo}/commits/$1/check-runs?check_name=$2" \
    --jq '.check_runs | sort_by(.id) | last | if . == null then "missing" else (.conclusion // "pending") end' \
    < /dev/null
}

# The state of the commit status named $2 on commit $1, or "missing".
status_state() {
  gh api "repos/{owner}/{repo}/commits/$1/status" \
    --jq "[.statuses[] | select(.context == \"$2\") | .state] | first // \"missing\"" \
    < /dev/null
}

# How many commits the base has that commit $1 lacks.
commits_behind() {
  gh api "repos/{owner}/{repo}/compare/$AUTO_MERGE_BASE...$1" --jq '.behind_by' < /dev/null
}

# Re-points this author's open PRs based on branch $1 at branch $2.
retarget_children() {
  local from="$1" to="$2" child
  for child in $(gh pr list --state open --base "$from" --author "$AUTO_MERGE_AUTHOR" \
                   --json number --jq '.[].number' < /dev/null); do
    run gh pr edit "$child" --base "$to" < /dev/null
    echo "#$child: re-pointed from $from to $to"
  done
}

main() {
  # A person merged a PR: its stacked children follow its base.
  if [[ -n "${CLOSED_PR_HEAD:-}" && -n "${CLOSED_PR_BASE:-}" ]]; then
    retarget_children "$CLOSED_PR_HEAD" "$CLOSED_PR_BASE"
  fi

  local number author base head sha draft hold mergeable decision
  while IFS=$'\t' read -r number author base head sha draft hold mergeable <&3; do
    decision="$(gate_decision author="$author" base="$base" draft="$draft" hold="$hold")"
    if [[ "$decision" == skip:* ]]; then
      echo "#$number: $decision"
      continue
    fi
    decision="$(gate_decision author="$author" base="$base" draft="$draft" hold="$hold" \
      project_check="$(check_conclusion "$sha" "$CHECK_RUN")" \
      editor_tests="$(status_state "$sha" "$TESTS_STAMP")" \
      local_review="$(status_state "$sha" "$REVIEW_STAMP")" \
      cloud_review="${CLOUD_REVIEW:-off}" \
      claude_review="$(check_conclusion "$sha" "$REVIEW_RUN")" \
      behind_by="$(commits_behind "$sha")" \
      mergeable="$mergeable")"
    echo "#$number: $decision"
    case "$decision" in
      merge)
        if run gh pr merge "$number" --merge --match-head-commit "$sha" < /dev/null; then
          retarget_children "$head" "$base"
        else
          echo "#$number: merge refused; will retry on the next event"
        fi
        ;;
      outdated)
        if [[ "$(status_state "$sha" "$OUTDATED_STAMP")" != "failure" ]]; then
          run gh api --silent -X POST "repos/{owner}/{repo}/statuses/$sha" \
            -f state=failure -f context="$OUTDATED_STAMP" \
            -f description="$AUTO_MERGE_BASE moved - merge it in and re-run the suite" < /dev/null
        fi
        ;;
    esac
  done 3< <(gh pr list --state open --limit 100 \
      --json number,author,baseRefName,headRefName,headRefOid,isDraft,labels,mergeable \
      --jq ".[] | [.number, .author.login, .baseRefName, .headRefName, .headRefOid, .isDraft, ([.labels[].name] | index(\"$HOLD_LABEL\") != null), .mergeable] | @tsv")
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
