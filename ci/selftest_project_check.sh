#!/usr/bin/env bash
# End-to-end self-test for the headless project check (ci/project_check.gd).
# Copies the working tree (tracked and new files, not ignored ones) to a temp
# folder, imports it, requires the check to PASS on the clean copy, then plants
# one breakage at a time -- a script that does not parse, a scene pointing at a
# missing texture, an autoload that errors on boot -- and requires each to FAIL.
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

# run_check <pass|fail> <description>: runs the check the way the workflow does.
run_check() {
  "$GODOT" --headless --path "$GODOT_PROJECT" res://ci/project_check.tscn > "$WORK/check.log" 2>&1
  local status=$? errors verdict=pass
  errors=$(grep -cE '^(ERROR|SCRIPT ERROR):' "$WORK/check.log")
  if (( status != 0 || errors > 0 )); then verdict=fail; fi
  if [[ "$verdict" == "$1" ]]; then
    echo "ok   - $2 ($verdict: exit $status, $errors error lines)"
  else
    echo "FAIL - $2: expected $1, got $verdict (exit $status, $errors error lines)"
    grep -E '^(PROJECT CHECK|ERROR|SCRIPT ERROR)' "$WORK/check.log" | head -20
    failures=$((failures + 1))
  fi
}

run_check pass "the clean tree passes"

printf 'extends Node\nfunc broken(:\n\tpass\n' > "$PROJECT/Scripts/zz_selftest_broken.gd"
run_check fail "a script that does not parse fails"
rm "$PROJECT/Scripts/zz_selftest_broken.gd"

cat > "$PROJECT/Scenes/zz_selftest_missing.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://Assets/zz_does_not_exist.png" id="1_missing"]

[node name="Missing" type="Sprite2D"]
texture = ExtResource("1_missing")
EOF
run_check fail "a scene pointing at a missing texture fails"
rm "$PROJECT/Scenes/zz_selftest_missing.tscn"

printf 'extends Node\nfunc _ready() -> void:\n\tpush_error("selftest: autoload failed on boot")\n' \
  > "$PROJECT/zz_selftest_autoload.gd"
sed -i 's/^\[autoload\]$/[autoload]\n\nZzSelftest="*res:\/\/zz_selftest_autoload.gd"/' "$PROJECT/project.godot"
run_check fail "an autoload that errors on boot fails"
cp "$WORK/project.godot.clean" "$PROJECT/project.godot"
rm "$PROJECT/zz_selftest_autoload.gd"

echo "$failures failure(s)"
exit $(( failures > 0 ))
