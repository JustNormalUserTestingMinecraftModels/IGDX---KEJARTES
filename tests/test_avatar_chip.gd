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


## The strip is a ScrollContainer, which clips above its own top, and the
## "+N" rises about 100 px above the rings. The chip carries that headroom.
func test_the_floating_gain_has_room_to_rise() -> void:
	var headroom := _chip.get_node_or_null("Headroom") as Control
	assert_true(headroom != null, "the chip needs headroom above its rings")
	if headroom:
		assert_true(headroom.get_index() < _chip.get_node("Rings").get_index(), "above the rings")
		assert_true(headroom.custom_minimum_size.y >= 98.0,
			"room for create_floating_text's 90 px rise plus its 30 px lift")


func test_the_chip_builds_nothing_but_the_floating_gain() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/AvatarChip.gd")
	for t in ["Label.new(", "TextureRect.new(", "Panel.new(", "HBoxContainer.new("]:
		assert_false(src.contains(t), "the chip is a template, not built: " + t)
	assert_true(src.contains("AnimUtils.create_floating_text"), "the +N goes through AnimUtils")
	assert_true(src.contains("GameSettings.reduce_motion"), "the spring honours reduce_motion")
