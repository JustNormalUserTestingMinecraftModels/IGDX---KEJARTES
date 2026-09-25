@tool
extends McpTestSuite

## AvatarChip, one student on the SchoolDay avatar strip (2026-09-24
## liveliness pass, layer 5): a face in a round frame inside an energy ring
## (outer) and a mood ring (inner), and the student's name.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.

const SCENE_PATH := "res://Scenes/SchoolSimulation/AvatarChip.tscn"


func suite_name() -> String:
	return "avatar_chip"


var _chip: AvatarChip


func setup() -> void:
	_chip = (load(SCENE_PATH) as PackedScene).instantiate() as AvatarChip
	Engine.get_main_loop().root.add_child(_chip)
	track(_chip)


func teardown() -> void:
	if is_instance_valid(_chip):
		_chip.queue_free()
	_chip = null


func _student() -> StudentData:
	var s := StudentData.new()
	s.student_name = "Uji"
	s.energy = 64.0
	s.mood = 38.0
	return s


func test_the_chip_has_its_parts() -> void:
	for path in ["Rings/EnergyRing", "Rings/MoodRing", "Rings/Disc/Face", "NamePill/NameLabel"]:
		assert_true(_chip.get_node_or_null(path) != null, "AvatarChip.tscn must author " + path)
	var disc := _chip.get_node("Rings/Disc") as Panel
	assert_eq(disc.theme_type_variation, &"AvatarDisc", "the round frame's variation")
	assert_eq(disc.clip_children, CanvasItem.CLIP_CHILDREN_AND_DRAW, "the face is clipped to the circle")
	for ring in ["Rings/EnergyRing", "Rings/MoodRing"]:
		var bar := _chip.get_node(ring) as TextureProgressBar
		assert_eq(bar.fill_mode, TextureProgressBar.FILL_CLOCKWISE, ring + " sweeps round")
		assert_true(bar.texture_progress != null and bar.texture_under != null, ring + " has its art")


func test_the_rings_wear_the_need_colours() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq((_chip.get_node("Rings/EnergyRing") as TextureProgressBar).tint_progress,
		tokens.category_color_on_dark("Energy"), "energy is the outer ring's colour")
	assert_eq((_chip.get_node("Rings/MoodRing") as TextureProgressBar).tint_progress,
		tokens.category_color_on_dark("Mood"), "mood is the inner ring's colour")


func test_setup_writes_the_name_and_both_rings() -> void:
	_chip.setup(_student())
	assert_eq((_chip.get_node("NamePill/NameLabel") as Label).text, "Uji", "the name")
	assert_eq(_chip.needs(), Vector2(64.0, 38.0), "energy outside, mood inside")


func test_set_needs_moves_the_rings_at_once() -> void:
	_chip.set_needs(10.0, 90.0)
	assert_eq((_chip.get_node("Rings/EnergyRing") as Range).value, 10.0, "energy ring")
	assert_eq((_chip.get_node("Rings/MoodRing") as Range).value, 90.0, "mood ring")


## Every student gets a face, even without art -- the chip must not break.
func test_a_student_without_art_still_sets_up() -> void:
	var s := _student()
	s.splash_path = ""
	s.avatar_texture = null
	assert_true(AvatarChip.face_texture_for(s) == null, "no art, no face")
	_chip.setup(s)
	assert_eq((_chip.get_node("NamePill/NameLabel") as Label).text, "Uji", "the chip still fills")


## A tappable-looking thing on a screen that closes on any tap must not
## swallow the tap.
func test_the_chip_ignores_the_mouse() -> void:
	var stack: Array[Node] = [_chip]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s must not eat taps" % n.name)
		stack.append_array(n.get_children())


## The strip is a ScrollContainer, which clips above its own top, and a gain
## pop starts just above the rings and rises. The chip's headroom must hold
## the pop at the top of its rise, measured with the baked theme (a bare
## Control under the editor root measures the EDITOR's font).
func test_the_floating_gain_has_room_to_rise() -> void:
	var headroom := _chip.get_node_or_null("Headroom") as Control
	assert_true(headroom != null, "the chip needs headroom above its rings")
	if headroom == null:
		return
	assert_true(headroom.get_index() < _chip.get_node("Rings").get_index(), "above the rings")
	var pop := (load(POP_PATH) as PackedScene).instantiate() as StatGainPop
	pop.theme = load("res://Assets/Theme/kejartes_theme.tres")
	Engine.get_main_loop().root.add_child(pop)
	track(pop)
	pop.set_gain("akademis", 12)
	# Guard against a vacuous pass: the number must really have been measured
	# in the baked DaySummaryStat face, not left at zero height.
	var label_h := (pop.get_node("Value") as Label).get_combined_minimum_size().y
	assert_true(label_h >= 40.0, "the +N measured only %.0f px tall" % label_h)
	var top := pop.get_combined_minimum_size().y - AvatarChip.GAIN_TEXT_OFFSET.y + pop.rise_px
	assert_true(top <= headroom.custom_minimum_size.y,
		"the pop peaks %.0f px above the rings; the headroom is %.0f" % [top, headroom.custom_minimum_size.y])


## 2026-09-25: the in-day gain is dressed like the daily result card's row --
## one StatGainPop per skill, instanced from a template, never a bare "+N".
func test_the_chip_builds_nothing_and_pops_the_template() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/AvatarChip.gd")
	for t in ["Label.new(", "TextureRect.new(", "Panel.new(", "HBoxContainer.new("]:
		assert_false(src.contains(t), "the chip is a template, not built: " + t)
	assert_false(src.contains("create_floating_text"), "no bare +N any more")
	assert_true(src.contains('preload("res://Scenes/SchoolSimulation/StatGainPop.tscn")'),
		"each gain is the StatGainPop template")
	assert_true(src.contains("GameSettings.reduce_motion"), "the spring honours reduce_motion")


const POP_PATH := "res://Scenes/SchoolSimulation/StatGainPop.tscn"


## Only the skills that rose pop, in the card's row order.
func test_only_rising_skills_pop_in_card_order() -> void:
	assert_eq(AvatarChip.gaining_stats({"olahraga": 2, "akademis": 5, "seni_budaya": 0}),
		["akademis", "olahraga"] as Array[String], "card order, zero dropped")
	assert_eq(AvatarChip.gaining_stats({"mood": 4, "energy": 9}).size(), 0,
		"needs are the rings' job, not a pop's")


## One pop at a time (review 2026-09-25): two skills at once, or a second
## call while a pop still shows, queue behind it rather than stacking. In the
## editor a pop never plays out and frees, so the queue holds still to count.
func test_pops_queue_one_at_a_time() -> void:
	_chip.pop_gains({"akademis": 1, "olahraga": 2})
	var showing := func() -> int:
		return _chip.get_node("Rings").get_children().filter(
			func(c: Node) -> bool: return c is StatGainPop).size()
	assert_eq(showing.call(), 1, "only the first pop shows")
	assert_eq(_chip.pending_pop_count(), 1, "the second waits its turn")
	_chip.pop_gains({"seni_budaya": 3})
	assert_eq(showing.call(), 1, "a later call does not land on top")
	assert_eq(_chip.pending_pop_count(), 2, "it queues behind")


## The pop reads like DaySummaryStatRow: the stat's own icon, the gold up
## arrow, and the number in the card's DaySummaryStat face.
func test_the_pop_wears_the_daily_result_row() -> void:
	var pop := (load(POP_PATH) as PackedScene).instantiate() as StatGainPop
	track(pop)
	assert_true(pop != null, "StatGainPop.tscn must carry the StatGainPop script")
	if pop == null:
		return
	for key in DaySummaryStatRow.ICON_FOR:
		pop.set_gain(key, 7)
		assert_eq((pop.get_node("Icon") as TextureRect).texture, DaySummaryStatRow.ICON_FOR[key],
			"%s pops with its own icon" % key)
	assert_eq((pop.get_node("Value") as Label).text, "+7", "the gain reads +N")
	assert_eq((pop.get_node("Value") as Label).theme_type_variation, &"DaySummaryStat",
		"the number wears the daily result's face")
	assert_eq((pop.get_node("Chevron") as TextureRect).texture.resource_path,
		"res://Assets/Images/DaySummary/icon_chevron_up.png", "the card's gold up arrow")
	for n in [pop, pop.get_node("Icon"), pop.get_node("Chevron"), pop.get_node("Value")]:
		assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s must not eat taps" % n.name)
