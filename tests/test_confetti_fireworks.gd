@tool
extends McpTestSuite

## The three-burst celebration that replaced the per-star StarBurst spray.
##
## Placement is the point of the scene: the ask was to be able to see where
## each firework sits, so these tests pin that the three bursts are real
## authored nodes at three distinct points -- not one emitter fired three
## times, and not three bursts built in _ready().
##
## The scene is loaded through load() rather than preload() on purpose: a
## preload of a missing scene is a parse error that stops the whole suite
## loading, which reports as "broken" rather than as the one thing that is
## actually wrong.
##
## No test here is a coroutine.

func suite_name() -> String:
	return "confetti_fireworks"


const SCENE_PATH := "res://Scenes/Minigames/UI/ConfettiFireworks.tscn"


func _rig() -> Node:
	var packed: PackedScene = load(SCENE_PATH)
	assert_true(packed != null, "ConfettiFireworks.tscn must exist")
	if packed == null:
		return null
	return packed.instantiate()


func test_the_scene_carries_exactly_three_bursts() -> void:
	var rig := _rig()
	if rig == null:
		return
	assert_eq(rig.burst_count(), 3, "the volley must be three fireworks")
	rig.free()


func test_the_three_bursts_sit_at_three_distinct_places() -> void:
	# One emitter fired three times would pass burst_count but fail this.
	var rig := _rig()
	if rig == null:
		return
	var seen: Array[Vector2] = []
	for i in 3:
		var at: Vector2 = rig.burst_position(i)
		assert_false(seen.has(at), "burst %d must not share a place" % i)
		seen.append(at)
	rig.free()


func test_every_burst_is_confetti_not_stars() -> void:
	var rig := _rig()
	if rig == null:
		return
	for i in 3:
		var node: GPUParticles2D = rig.get_burst(i)
		assert_true(node != null, "burst %d must exist as a node" % i)
		if node == null:
			continue
		assert_true(node.texture != null, "burst %d must have art" % i)
		if node.texture != null:
			assert_true(String(node.texture.resource_path).contains("particle_confetti"),
				"burst %d must throw confetti, not stars" % i)
	rig.free()


func test_bursts_start_quiet() -> void:
	# A scene that emits on load would fire the volley the moment the card is
	# instanced, before a single star has landed.
	var rig := _rig()
	if rig == null:
		return
	for i in 3:
		var node: GPUParticles2D = rig.get_burst(i)
		if node == null:
			continue
		assert_false(node.emitting, "burst %d must wait to be fired" % i)
		assert_true(node.one_shot, "burst %d must be one_shot so it stops itself" % i)
	rig.free()


## An out-of-range index is ignored rather than erroring: a minigame may award
## one or two stars, and the popup fires one burst per star.
func test_firing_a_burst_a_short_volley_does_not_have_is_harmless() -> void:
	var rig := _rig()
	if rig == null:
		return
	rig.fire_burst(9)
	rig.fire_burst(-1)
	assert_true(true, "out-of-range fire_burst must not error")
	rig.free()


## Asserts the code, not the word: ResultStar's header still explains that it
## used to mount a StarBurst, and that history is worth keeping. What must be
## gone is the preload and the instantiation.
func test_result_star_no_longer_sprays_stars() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/ResultStar.gd")
	assert_true(src != "", "ResultStar.gd must exist")
	assert_false(src.contains('preload("res://Scenes/Minigames/UI/StarBurst.tscn")'),
		"ResultStar must not preload the star spray any more")
	assert_false(src.contains("_BURST_PACKED"),
		"the per-star star spray is what the fireworks replace")
	# MinigameScoreHUD still fires StarBurst into its own BurstSlot, so the
	# scene itself must stay on disk.
	assert_true(ResourceLoader.exists("res://Scenes/Minigames/UI/StarBurst.tscn"),
		"StarBurst.tscn still has a caller and must not be deleted")


func test_the_popup_fires_the_volley() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_true(src != "", "MinigameResultPopup.gd must exist")
	assert_true(src.contains("fire_burst("),
		"the popup must fire a burst as each star lands")


func test_the_full_house_rain_is_untouched() -> void:
	# ResultConfetti is the separate top-of-screen rain gated at three stars.
	# The fireworks replace the per-star spray, not this.
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_true(src.contains("confetti.fire()"),
		"the three-star confetti rain must still fire")
