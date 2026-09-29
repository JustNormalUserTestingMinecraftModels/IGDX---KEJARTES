@tool
extends McpTestSuite

## Proves the shared MinigameHeader strip: its icon buttons wear the kit's
## MinigameHudIconButton variation, its centre is the shared MinigameScoreHUD
## (instanced, not forked), and its root API forwards down to it. Instances are
## added to the editor root and tracked, so @onready and _ready run; the
## header's own runtime side effects are editor-gated. The scene is load()ed,
## not preloaded, so this suite still parses before the scene exists.
## Must be @tool, and no test here may be a coroutine.

const HEADER_PATH := "res://Scenes/Minigames/UI/MinigameHeader.tscn"
const SCRIPT_PATH := "res://Scripts/Minigames/UI/MinigameHeader.gd"
const SCORE_HUD_PATH := "res://Scenes/Minigames/UI/MinigameScoreHUD.tscn"
const ICON_SKOR := "res://Assets/Images/UI/Placeholders/icon_skor.svg"
## The unique names the script binds.
const BOUND_NODES: Array[String] = ["%PauseButton", "%TimerButton", "%ScoreHud"]
## A sample round: 2 of 3.
const SAMPLE_TARGET := 3
const SAMPLE_SCORE := 2


func suite_name() -> String:
	return "minigame_header"


func _make() -> MinigameHeader:
	var scene: PackedScene = load(HEADER_PATH)
	var header: MinigameHeader = scene.instantiate()
	Engine.get_main_loop().root.add_child(header)
	track(header)
	return header


func test_the_scene_carries_every_node_the_script_binds() -> void:
	var header: MinigameHeader = _make()
	for unique_name: String in BOUND_NODES:
		assert_true(header.get_node_or_null(unique_name) != null,
			"%s is an authored unique-name node" % unique_name)


func test_pause_and_timer_are_hud_icon_buttons() -> void:
	var header: MinigameHeader = _make()
	for unique_name: String in ["%PauseButton", "%TimerButton"]:
		var button: Button = header.get_node(unique_name)
		assert_eq(button.theme_type_variation, &"MinigameHudIconButton",
			"%s wears the HUD icon-button variation" % unique_name)


func test_the_centre_is_the_shared_score_hud() -> void:
	var header: MinigameHeader = _make()
	var hud: Node = header.get_node("%ScoreHud")
	assert_eq(hud.scene_file_path, SCORE_HUD_PATH,
		"the score readout is an instance of MinigameScoreHUD.tscn, not a fork")


func test_set_score_reaches_the_shared_readout() -> void:
	var header: MinigameHeader = _make()
	header.setup(load(ICON_SKOR) as Texture2D, SAMPLE_TARGET)
	header.set_score(SAMPLE_SCORE)
	var hud: MinigameScoreHUD = header.get_node("%ScoreHud")
	assert_eq(hud.value_label.text, str(SAMPLE_SCORE), "set_score forwards down to the HUD")


func test_show_timer_false_hides_the_timer_button() -> void:
	var header: MinigameHeader = _make()
	header.show_timer = false
	var timer_button: Button = header.get_node("%TimerButton")
	assert_false(timer_button.visible, "show_timer drives the timer button")


## A saved show_timer = false must preview on scene open, i.e. an export set
## BEFORE the node enters the tree still takes effect once _ready runs.
func test_show_timer_set_before_entering_tree_hides_the_timer_button() -> void:
	var scene: PackedScene = load(HEADER_PATH)
	var header: MinigameHeader = scene.instantiate()
	header.show_timer = false
	Engine.get_main_loop().root.add_child(header)
	track(header)
	var timer_button: Button = header.get_node("%TimerButton")
	assert_false(timer_button.visible,
		"an export set before add_child still applies once the node is ready")


## Display-only decision: the timer button takes no focus and no taps.
func test_timer_button_is_display_only() -> void:
	var header: MinigameHeader = _make()
	var timer_button: Button = header.get_node("%TimerButton")
	assert_eq(timer_button.focus_mode, Control.FOCUS_NONE,
		"the timer button never takes keyboard/gamepad focus")
	assert_eq(timer_button.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the timer button never intercepts taps")


func test_the_pause_button_announces_pause_pressed() -> void:
	var header: MinigameHeader = _make()
	var presses: Array[int] = [0]
	header.pause_pressed.connect(func() -> void: presses[0] += 1)
	var pause_button: Button = header.get_node("%PauseButton")
	pause_button.pressed.emit()
	assert_eq(presses[0], 1, "a press is announced up, once")


func test_the_header_adds_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("add_theme_"), "chrome comes from the theme variations")
	var scene_src := FileAccess.get_file_as_string(HEADER_PATH)
	for banned: String in ["theme_override_colors", "theme_override_fonts",
			"theme_override_font_sizes", "theme_override_styles", "theme_override_icons"]:
		assert_false(scene_src.contains(banned), "no %s in the header scene" % banned)


func test_set_progress_fills_the_bar_and_writes_the_label() -> void:
	var header: MinigameHeader = _make()
	header.set_progress(3, 10, "Soal 3/10")
	var bar: ProgressBar = header.get_node("%ProgressBar")
	assert_eq(bar.max_value, 10.0, "max follows the round length")
	assert_eq(bar.value, 3.0, "value is written straight through in the editor")
	assert_eq((header.get_node("%ProgressLabel") as Label).text, "Soal 3/10")


func test_segmented_draws_one_tick_per_step() -> void:
	var header: MinigameHeader = _make()
	header.segmented = true
	header.set_progress(1, 4, "Langkah 1/4")
	assert_eq((header.get_node("%Ticks") as ProgressTicks).segments, 4)
	header.segmented = false
	header.set_progress(1, 4, "Langkah 1/4")
	assert_eq((header.get_node("%Ticks") as ProgressTicks).segments, 0)


func test_set_time_drains_the_ring_and_turns_danger_late() -> void:
	var header: MinigameHeader = _make()
	header.set_time(20.0, 40.0)
	var ring: TimerRing = header.get_node("%Ring")
	assert_true(is_equal_approx(ring.fraction, 0.5), "half the time left, half a ring")
	assert_false(ring.danger, "not yet in the danger window")
	header.set_time(header.danger_seconds - 0.1, 40.0)
	assert_true(ring.danger, "the last danger_seconds turn the ring red")


func test_hidden_score_and_progress_hide_their_nodes() -> void:
	var header: MinigameHeader = _make()
	header.show_score = false
	header.show_progress = false
	assert_false((header.get_node("%ScoreHud") as Control).visible)
	assert_false((header.get_node("%ProgressBar") as Control).is_visible_in_tree())


func test_hidden_timer_keeps_its_slot_so_the_pill_stays_centred() -> void:
	var header: MinigameHeader = _make()
	header.show_timer = false
	var slot := header.get_node("Stack/Row/TimerSlot") as Control
	assert_true(slot.visible, "the slot stays, only the button hides")
	assert_eq(slot.custom_minimum_size, Vector2(96, 96))


func test_icons_are_glyph_children_not_button_icons() -> void:
	var header: MinigameHeader = _make()
	assert_eq((header.get_node("%PauseGlyph") as TextureRect).texture.resource_path,
		"res://Assets/Images/UI/Icons/pause.svg")
	assert_eq((header.get_node("%TimerGlyph") as TextureRect).texture.resource_path,
		"res://Assets/Images/UI/Icons/timer.svg")
	assert_true((header.get_node("%PauseButton") as Button).icon == null,
		"a lipped button squeezes an icon; the glyph is a child")


func test_set_pause_enabled_disables_the_button() -> void:
	var header: MinigameHeader = _make()
	header.set_pause_enabled(false)
	assert_true((header.get_node("%PauseButton") as Button).disabled)
