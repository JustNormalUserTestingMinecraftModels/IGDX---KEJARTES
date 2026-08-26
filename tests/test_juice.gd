@tool
extends McpTestSuite

## NOTE on test technique: the MCP test runner (addons/godot_ai/testing/
## test_runner.gd, `_run_one_test`) calls `suite.call(method_name)`
## synchronously and does not await coroutines. A test method that
## `await`s a real SceneTreeTimer therefore returns to the runner at the
## first suspension point, before any assertion after the await ever
## runs — the runner records "0 assertions" and moves on while the
## timer/tween finishes seconds later, orphaned. Real-timer awaits are
## fundamentally incompatible with this synchronous runner, regardless
## of timer length.
##
## Fix used here: drive Tweens deterministically and synchronously via
## Tween.custom_step(), which is the standard Godot technique for
## testing tween end-states without waiting on real frames. Juice's
## public API is untouched (still `-> void`, per the brief) — tests
## locate the Tween(s) Juice created via
## SceneTree.get_processed_tweens(), diffed against a before-snapshot
## so leftover tweens from earlier tests can't leak in.

func suite_name() -> String:
	return "juice"

var _root: Control


func setup() -> void:
	_root = Control.new()
	_root.size = Vector2(400, 400)
	Engine.get_main_loop().root.add_child(_root)
	track(_root)


func teardown() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _make_control() -> Control:
	var c := Control.new()
	c.size = Vector2(200, 100)
	_root.add_child(c)
	return c


## Snapshot active tweens, run `action`, then fast-forward every tween
## that appeared as a result of `action` by `duration` seconds. Diffing
## against the before-snapshot means tweens still finishing from an
## earlier test (or the editor's own UI) can never be mistaken for this
## test's tween.
func _run_and_step(action: Callable, duration: float) -> void:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var after: Array = Engine.get_main_loop().get_processed_tweens()
	for tw in after:
		if not before.has(tw) and is_instance_valid(tw):
			tw.custom_step(duration)


func test_set_pivot_center_puts_pivot_at_the_middle() -> void:
	# Without this, every scale tween grows from the top-left corner and
	# the button visibly slides instead of pulsing.
	var c := _make_control()
	Juice.set_pivot_center(c)
	assert_eq(c.pivot_offset, Vector2(100, 50), "pivot must be size/2")


func test_press_shrinks_the_node() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	_run_and_step(func(): Juice.press(c), tokens.dur_instant + 0.05)
	assert_true(absf((c.scale.x) - (tokens.press_scale)) <= 0.02, "press must settle at press_scale")


func test_release_returns_to_unit_scale() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	c.scale = Vector2(tokens.press_scale, tokens.press_scale)
	_run_and_step(func(): Juice.release(c), tokens.dur_fast + 0.15)
	assert_true(absf((c.scale.x) - (1.0)) <= 0.02, "release must settle at exactly 1.0")


func test_pop_in_makes_a_hidden_node_visible_at_unit_scale() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	_run_and_step(func(): Juice.pop_in(c), tokens.dur_normal + 0.15)
	assert_true(absf((c.scale.x) - (1.0)) <= 0.03, "pop_in ends at unit scale")
	assert_true(absf((c.modulate.a) - (1.0)) <= 0.03, "pop_in ends fully opaque")


func test_count_up_lands_exactly_on_the_target() -> void:
	# Off-by-one on a displayed stat is the kind of bug players screenshot.
	var tokens := DesignTokens.load_default()
	var label := Label.new()
	_root.add_child(label)
	_run_and_step(func(): Juice.count_up(label, 0.0, 87.0), tokens.dur_slow + 0.2)
	assert_eq(label.text, "87", "count_up must end on the exact target")


func test_count_up_respects_the_format_string() -> void:
	var tokens := DesignTokens.load_default()
	var label := Label.new()
	_root.add_child(label)
	_run_and_step(func(): Juice.count_up(label, 0.0, 42.0, "%d%%"), tokens.dur_slow + 0.2)
	assert_eq(label.text, "42%", "format string must be applied")


func test_fill_bar_lands_on_the_target_value() -> void:
	var tokens := DesignTokens.load_default()
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	_root.add_child(bar)
	_run_and_step(func(): Juice.fill_bar(bar, 73.5), tokens.dur_slow + 0.2)
	assert_true(absf((bar.value) - (73.5)) <= 0.01, "bar must land on target")


func test_stagger_in_eventually_shows_every_node() -> void:
	var tokens := DesignTokens.load_default()
	var nodes: Array[Control] = []
	for i in range(5):
		nodes.append(_make_control())
	var total := tokens.stagger_step * 5.0 + tokens.dur_normal + 0.2
	_run_and_step(func(): Juice.stagger_in(nodes), total)
	for i in nodes.size():
		assert_true(absf((nodes[i].modulate.a) - (1.0)) <= 0.03, "staggered node %d must end visible" % i)


func test_stagger_in_tolerates_an_empty_array() -> void:
	Juice.stagger_in([])
	assert_true(true, "empty stagger must not crash")


func test_helpers_tolerate_null_nodes() -> void:
	# Scene changes free nodes mid-tween all the time; by the time other
	# code reacts, the reference it's holding may already be null (or,
	# for a hard-freed Object, fail Godot's own typed-argument marshalling
	# before any GDScript of ours even runs — that's an engine-level
	# restriction on freed Objects passed to typed native parameters, not
	# something Juice's null/is_instance_valid guard could intercept, so
	# null is the faithful stand-in for "stale reference" here).
	Juice.press(null)
	Juice.release(null)
	Juice.pop_in(null)
	assert_true(true, "juice on a null node must be a no-op, not a crash")


func test_shake_returns_the_node_to_its_start_position() -> void:
	var tokens := DesignTokens.load_default()
	var c := _make_control()
	c.position = Vector2(50, 60)
	_run_and_step(func(): Juice.shake(c), tokens.dur_normal + 0.25)
	assert_true(absf((c.position.x) - (50.0)) <= 0.5, "shake must restore x")
	assert_true(absf((c.position.y) - (60.0)) <= 0.5, "shake must restore y")
