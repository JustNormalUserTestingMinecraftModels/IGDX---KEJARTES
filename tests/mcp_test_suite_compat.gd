@tool
class_name McpTestSuiteCompat
extends McpTestSuite

## Restores assert_not_null(), deleted from the vendored
## addons/godot_ai/testing/test_suite.gd in the 2026-09-09 addon update with
## no replacement and no deprecation notice (git diff on that update touches
## nothing else -- this is the whole change). 22 suites in this project
## called it; without this shim they fail to instantiate ("abstract or
## broken"). Extend this instead of McpTestSuite directly in those files.
##
## Not named test_*.gd on purpose: test_run discovers suites by that glob,
## and this class defines no test_* methods of its own to run.
##
## Behavior is copied verbatim from the addon's pre-removal implementation
## (same default message, same short-circuit-on-prior-failure semantics,
## via assert_true's own bookkeeping) so restoring the upstream method later
## is a silent, harmless override shadow -- delete this file and revert the
## 22 `extends` lines when that happens.
func assert_not_null(value: Variant, msg: String = "") -> void:
	assert_true(value != null, msg if msg else "Expected non-null value")
