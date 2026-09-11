#!/usr/bin/env bash
# Unit tests for gate_decision() in ci/auto_merge.sh. Pure: no network, no gh.
#
#     bash ci/test_auto_merge.sh
set -euo pipefail
# shellcheck source=ci/auto_merge.sh
source "$(dirname "${BASH_SOURCE[0]}")/auto_merge.sh"

failures=0
# A PR every gate would merge; each case overrides only what it is about.
GREEN=(author=brineoutxd base=Textures draft=false hold=false workflows=false
       project_check=success editor_tests=success local_review=success
       cloud_review=off claude_review=missing behind_by=0 mergeable=MERGEABLE)

# expect <wanted prefix> <what the case proves> [key=value overrides...]
expect() {
  local want="$1" what="$2" got
  shift 2
  got="$(gate_decision "${GREEN[@]}" "$@")"
  if [[ "$got" == "$want"* ]]; then
    echo "ok   - $what"
  else
    echo "FAIL - $what: got '$got', want '$want...'"
    failures=$((failures + 1))
  fi
}

expect "merge"          "every gate green merges"
expect "skip: author"   "another author's PR is never merged" author=JustNormalUserTestingMinecraftModels
expect "skip: base"     "a PR stacked on another branch is not merged" base=feat/koperasi-rework
expect "skip: draft"    "a draft is not merged" draft=true
expect "skip: labelled" "a PR labelled hold is not merged" hold=true
expect "skip: changes"  "a PR that changes workflow files is left for a person" workflows=true
expect "wait:"          "a failed project check blocks" project_check=failure
expect "wait:"          "a project check still running blocks" project_check=pending
expect "wait:"          "a missing editor-tests stamp blocks" editor_tests=missing
expect "wait:"          "a failed editor-tests stamp blocks" editor_tests=failure
expect "wait:"          "a missing local-review stamp blocks" local_review=missing
expect "merge"          "without a key the cloud review is not required" cloud_review=off claude_review=missing
expect "wait:"          "with a key a missing cloud review blocks" cloud_review=on claude_review=missing
expect "wait:"          "with a key a blocking cloud review blocks" cloud_review=on claude_review=failure
expect "merge"          "with a key a passing cloud review merges" cloud_review=on claude_review=success
expect "outdated"       "a green PR behind Textures is flagged, not merged" behind_by=3
expect "wait:"          "behind Textures with another gate red waits" behind_by=3 editor_tests=missing
expect "wait:"          "an unknown distance from Textures waits" behind_by=
expect "wait:"          "a conflict blocks" mergeable=CONFLICTING
expect "wait:"          "mergeability not computed yet blocks" mergeable=UNKNOWN

if gate_decision "${GREEN[@]}" bogus=1 > /dev/null 2>&1; then
  echo "FAIL - an unknown key is rejected"
  failures=$((failures + 1))
else
  echo "ok   - an unknown key is rejected"
fi

echo "$failures failure(s)"
exit $(( failures > 0 ))
