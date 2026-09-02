@tool
extends McpTestSuite

## NOTE on test technique: the brief's original draft used two await
## patterns that are incompatible with this synchronous runner (see
## test_juice.gd's header note for the full explanation of why — the
## runner's `_run_one_test` calls `suite.call(method_name)` without await,
## so any coroutine test returns control at its first suspend point before
## its post-await assertions ever run, and gets scored "0 assertions").
## Both patterns needed a fix here:
##
## 1. `await Engine.get_main_loop().process_frame` — used in the brief to
##    wait for a freshly add_child()-ed node's _ready() to have run. This
##    turned out to be unnecessary: Godot invokes a child's _ready()
##    synchronously, from inside add_child(), whenever the parent is
##    already inside the SceneTree — which _root always is here, since it
##    was itself added under Engine.get_main_loop().root in setup(). No
##    frame needs to pass. This isn't a new discovery specific to this
##    suite: test_audio_director.gd already relies on exactly this —
##    test_sfx_voices_are_pooled_and_reused reads state that
##    AudioDirector's _ready() sets up, immediately after add_child(),
##    with no await at all, and it passes today. Verified empirically by
##    running this suite with the awaits simply deleted: every _ready()-
##    dependent assertion (margins applied, tint applied, theme variation
##    set) passes on the first try. The awaits are removed below.
##
## 2. `await Engine.get_main_loop().create_timer(...).timeout` — used to
##    wait for a Juice.fill_bar/count_up tween to finish. Fixed with the
##    technique test_juice.gd already established: snapshot
##    get_processed_tweens() before the action, diff after, and
##    custom_step() whatever tween(s) appeared to fast-forward them
##    synchronously. Reused verbatim as `_run_and_step` below.

func suite_name() -> String:
	return "ui_components"

var _root: Control


func setup() -> void:
	_root = Control.new()
	_root.size = Vector2(1080, 1920)
	Engine.get_main_loop().root.add_child(_root)
	track(_root)


func teardown() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null


## See note 2 above. Mirrors test_juice.gd's _run_and_step exactly.
func _run_and_step(action: Callable, duration: float) -> void:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var after: Array = Engine.get_main_loop().get_processed_tweens()
	for tw in after:
		if not before.has(tw) and is_instance_valid(tw):
			tw.custom_step(duration)


func test_safe_area_applies_at_least_the_screen_margin() -> void:
	var m := SafeAreaMargin.new()
	_root.add_child(m)
	var tokens := DesignTokens.load_default()
	# On desktop the safe area equals the window, so insets are zero and
	# only screen_margin applies. That is the floor we assert.
	assert_true(m.get_theme_constant("margin_left") >= tokens.screen_margin,
		"left margin must be at least screen_margin")
	assert_true(m.get_theme_constant("margin_top") >= tokens.screen_margin,
		"top margin must be at least screen_margin")


func test_safe_area_can_be_disabled() -> void:
	var m := SafeAreaMargin.new()
	m.use_safe_area = false
	_root.add_child(m)
	var tokens := DesignTokens.load_default()
	assert_eq(m.get_theme_constant("margin_left"), tokens.screen_margin,
		"with safe area off, margin is exactly screen_margin")


## Renamed from test_statbar_tints_itself_from_its_category: a StatBar-family
## bar no longer tints via self_modulate (that multiplied the WHOLE node,
## including the track behind the fill, so a value-0 bar rendered as a
## solid capsule). The category colour now lives in a per-category theme
## variation's fill stylebox instead (ThemeFactory._build_progress), so
## this asserts the bar picked the right variation AND stayed untinted.
func test_statbar_takes_its_category_variation() -> void:
	var bar := StatBar.new()
	bar.category = "Olahraga"
	_root.add_child(bar)
	assert_eq(bar.theme_type_variation, &"StatBarOlahraga",
		"a StatBar-family bar must resolve to its category's variation")
	assert_eq(bar.self_modulate, Color.WHITE,
		"the node itself must stay untinted -- the fill stylebox carries the colour now")


func test_statbar_uses_the_theme_variation() -> void:
	var bar := StatBar.new()
	_root.add_child(bar)
	# Default category is "Akademis", which now resolves to its own
	# per-category variation rather than the plain shared "StatBar" look.
	assert_eq(bar.theme_type_variation, &"StatBarAkademis",
		"StatBar must opt into its category's theme variation automatically")


func test_set_stat_without_animation_is_immediate() -> void:
	var bar := StatBar.new()
	_root.add_child(bar)
	bar.set_stat(64.0, false)
	assert_true(absf((bar.value) - (64.0)) <= 0.001, "unanimated set is immediate")


func test_set_stat_with_animation_reaches_the_target() -> void:
	var tokens := DesignTokens.load_default()
	var bar := StatBar.new()
	_root.add_child(bar)
	_run_and_step(func(): bar.set_stat(88.0, true), tokens.dur_slow + 0.2)
	assert_true(absf((bar.value) - (88.0)) <= 0.05, "animated set reaches target")


func test_set_stat_clamps_out_of_range_input() -> void:
	# Stats are computed from decay math that can overshoot.
	var bar := StatBar.new()
	_root.add_child(bar)
	bar.set_stat(150.0, false)
	assert_true(absf((bar.value) - (100.0)) <= 0.001, "clamps above max_value")
	bar.set_stat(-20.0, false)
	assert_true(absf((bar.value) - (0.0)) <= 0.001, "clamps below min_value")


func test_statbar_value_label_tracks_the_value() -> void:
	var tokens := DesignTokens.load_default()
	var bar := StatBar.new()
	bar.show_value_label = true
	_root.add_child(bar)
	_run_and_step(func(): bar.set_stat(77.0, true), tokens.dur_slow + 0.25)
	var label := bar.get_node_or_null("ValueLabel") as Label
	assert_true(label != null, "show_value_label must create a ValueLabel child")
	assert_eq(label.text, "77", "label must land on the exact value")


## Regression pin: StatBar is @tool, so _ready() -> _sync_label() runs at
## EDIT time too, whenever a scene containing one is opened and saved --
## not just in-game. ReportCard and StudentCard bars leave show_value_label
## at its default false while authoring their own ValueLabel children with
## meaningful text/alignment that those screens drive themselves. Opening
## and saving Scenes/ReportCard/report_card.tscn once adopted those
## authored labels and silently persisted stomped values into the .tscn:
## visible flipped to false, text overwritten from the authored "65/65" to
## a freshly computed "60", and horizontal_alignment forced from right (2)
## to centre (1). show_value_label = false must leave an authored child
## completely alone -- not adopt it, not hide it, not restyle it, not
## rewrite its text.
func test_statbar_leaves_an_authored_label_alone_when_show_value_label_is_false() -> void:
	var bar := StatBar.new()
	# show_value_label left at its default false, matching ReportCard/
	# StudentCard's authored bars.
	var authored := Label.new()
	authored.name = "ValueLabel"
	authored.text = "65/65"
	authored.visible = true
	authored.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(authored)
	_root.add_child(bar)

	assert_eq(authored.text, "65/65",
		"an authored label's text must survive _ready() when show_value_label is false")
	assert_true(authored.visible,
		"an authored label's visibility must survive _ready() when show_value_label is false")
	assert_eq(authored.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"an authored label's alignment must survive _ready() when show_value_label is false")


## self_modulate is unconditionally white for the whole StatBar family now,
## so `self_modulate.a > 0.0` would pass for any category and no longer
## exercises the fallback mapping at all. What actually matters is that an
## unrecognised category resolves to the neutral "StatBar" variation (whose
## fill stylebox is genuinely visible, see ThemeFactory._build_progress)
## rather than an empty/unknown theme_type_variation string.
func test_unknown_category_still_renders_visibly() -> void:
	var bar := StatBar.new()
	bar.category = "KategoriTidakDikenal"
	_root.add_child(bar)
	assert_true(bar.self_modulate.a > 0.0,
		"an unknown category must never render the bar invisible")
	assert_eq(bar.theme_type_variation, &"StatBar",
		"an unrecognised category must fall back to the neutral StatBar variation")


func test_stat_bar_defaults_to_its_own_variation() -> void:
	var bar := StatBar.new()
	assert_eq(bar.variation, &"StatBar",
		"an unconfigured StatBar must keep the shared look")
	bar.free()
