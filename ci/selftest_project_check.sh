#!/usr/bin/env bash
# End-to-end self-test for the headless project check (ci/project_check.gd).
# Copies the working tree (tracked and new files, not ignored ones) to a temp
# folder, imports it, requires the check to PASS on the clean copy, then plants
# one breakage at a time -- a script that does not parse, a scene pointing at a
# missing texture, an autoload that errors on boot, a script that adds
# clean-code debt, a clean-code baseline with conflict markers -- and requires
# each to FAIL for its own reason; and requires a clean-code improvement to
# PASS with only a warning. Every run has a timeout, so a check that hangs
# fails instead of stalling the selftest.
# Local only: CI runs the check itself, not this.
#
#     bash ci/selftest_project_check.sh <path-to-godot-console-binary>
set -uo pipefail

GODOT="${1:?usage: selftest_project_check.sh <path-to-godot-binary>}"
ROOT="$(git rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export MSYS2_ARG_CONV_EXCL="*"   # Git Bash: hand res:// paths to Godot untouched
PROJECT="$WORK/p"
GODOT_PROJECT="$PROJECT"
if command -v cygpath > /dev/null; then GODOT_PROJECT="$(cygpath -m "$PROJECT")"; fi
failures=0

# The working tree, under its own user:// folder so the check never touches a
# developer's save data, freshly imported.
mkdir -p "$PROJECT"
( cd "$ROOT" && git ls-files -z --cached --others --exclude-standard \
    | tar --null --ignore-failed-read -cf - -T - ) | tar -xf - -C "$PROJECT"
sed -i 's/^config\/name="\(.*\)"/config\/name="\1-selftest"/' "$PROJECT/project.godot"
cp "$PROJECT/project.godot" "$WORK/project.godot.clean"
"$GODOT" --headless --path "$GODOT_PROJECT" --import > "$WORK/import.log" 2>&1

# run_check <pass|fail> <description> [pattern]: runs the check the way the
# workflow does, under a timeout. A case with a pattern must also print it, so
# it passes or fails for the reason it tests rather than for an unrelated one.
run_check() {
  timeout 600 "$GODOT" --headless --path "$GODOT_PROJECT" res://ci/project_check.tscn > "$WORK/check.log" 2>&1
  local status=$? errors verdict=pass
  errors=$(grep -cE '^(ERROR|SCRIPT ERROR):' "$WORK/check.log")
  if (( status != 0 || errors > 0 )); then verdict=fail; fi
  if [[ -n "${3:-}" ]] && ! grep -qF -- "$3" "$WORK/check.log"; then
    verdict="$verdict without \"$3\""
  fi
  if [[ "$verdict" == "$1" ]]; then
    echo "ok   - $2 ($verdict: exit $status, $errors error lines)"
  else
    echo "FAIL - $2: expected $1, got $verdict (exit $status, $errors error lines)"
    grep -E '^(PROJECT CHECK|ERROR|SCRIPT ERROR|WARNING)' "$WORK/check.log" | head -20
    failures=$((failures + 1))
  fi
}

run_check pass "the clean tree passes"

# The broken fixtures live at the project root: outside every folder the
# clean-code scan reads, while collect_files("res://") still loads them.
printf 'extends Node\nfunc broken(:\n\tpass\n' > "$PROJECT/zz_selftest_broken.gd"
run_check fail "a script that does not parse fails" "PROJECT CHECK FAIL: res://zz_selftest_broken.gd:"
rm "$PROJECT/zz_selftest_broken.gd"

cat > "$PROJECT/zz_selftest_missing.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://Assets/zz_does_not_exist.png" id="1_missing"]

[node name="Missing" type="Sprite2D"]
texture = ExtResource("1_missing")
EOF
run_check fail "a scene pointing at a missing texture fails" "missing dependency"
rm "$PROJECT/zz_selftest_missing.tscn"

printf 'extends Node\nfunc _ready() -> void:\n\tpush_error("selftest: autoload failed on boot")\n' \
  > "$PROJECT/zz_selftest_autoload.gd"
sed -i 's/^\[autoload\]$/[autoload]\n\nZzSelftest="*res:\/\/zz_selftest_autoload.gd"/' "$PROJECT/project.godot"
run_check fail "an autoload that errors on boot fails" "selftest: autoload failed on boot"
cp "$WORK/project.godot.clean" "$PROJECT/project.godot"
rm "$PROJECT/zz_selftest_autoload.gd"

printf 'extends Node\n## Selftest.\nfunc untyped(value):\n\tpass\n' > "$PROJECT/Scripts/ZzSelftestUntyped.gd"
run_check fail "untyped code fails the clean-code scan" "clean-code untyped grew"
rm "$PROJECT/Scripts/ZzSelftestUntyped.gd"

# A hand-merged baseline: the check must report it and exit, not hang.
cp "$PROJECT/ci/clean_code_baseline.gd" "$WORK/baseline.clean"
printf '<<<<<<< HEAD\n=======\n>>>>>>> selftest\n' >> "$PROJECT/ci/clean_code_baseline.gd"
run_check fail "a baseline with conflict markers fails fast" "clean-code scan did not load"
cp "$WORK/baseline.clean" "$PROJECT/ci/clean_code_baseline.gd"

# An improvement only warns in CI: type the first untyped class-level var.
shrink_target=$(grep -rlE '^var [a-z_]+ = ' --include='*.gd' "$PROJECT/Scripts" | grep -v '/Balance\.gd$' | head -1)
cp "$shrink_target" "$WORK/shrink.clean"
sed -i -E '0,/^var ([a-z_]+) = /s//var \1: Variant = /' "$shrink_target"
run_check pass "a clean-code shrink passes with a warning" "WARNING: clean-code untyped shrank"
cp "$WORK/shrink.clean" "$shrink_target"

echo "$failures failure(s)"
exit $(( failures > 0 ))
