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


## The volley used to throw `particle_confetti.png` -- the *same* texture uid
## as ResultConfetti's full-house rain, with the same chip silhouette and the
## same spin -- so a three-star win read as two helpings of confetti rather
## than as fireworks. The sprite is now `particle_spark.png`, a four-point
## flare (alpha on both axes, zero on the diagonals). Pinned so nobody points
## it back at the confetti chip.
func test_every_burst_is_a_spark_not_confetti() -> void:
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
			var path := String(node.texture.resource_path)
			assert_true(path.contains("particle_spark"),
				"burst %d must throw a spark, not confetti" % i)
			assert_false(path.contains("particle_confetti"),
				"burst %d must not share ResultConfetti's chip texture" % i)
	rig.free()


## Returns the three bursts' ParticleProcessMaterials, or [] if the rig or any
## material is missing. Keeps the six material tests below to one shape.
func _materials(rig) -> Array[ParticleProcessMaterial]:
	var out: Array[ParticleProcessMaterial] = []
	for i in 3:
		var node: GPUParticles2D = rig.get_burst(i)
		if node == null:
			continue
		var mat := node.process_material as ParticleProcessMaterial
		if mat != null:
			out.append(mat)
	return out


## "flipping like papers", pinned. A rounded confetti chip spinning at
## +/-320 deg/s over its life is what made the volley read as paper rather
## than as sparks. Written as an explicit 0.0 rather than a deleted property:
## a removed .tscn line does not reset a value in a running editor's cache.
func test_the_sparks_do_not_tumble() -> void:
	var rig := _rig()
	if rig == null:
		return
	var mats := _materials(rig)
	assert_eq(mats.size(), 3, "all three bursts must keep a process material")
	for i in mats.size():
		assert_eq(mats[i].angular_velocity_min, 0.0,
			"burst %d must not tumble like paper" % i)
		assert_eq(mats[i].angular_velocity_max, 0.0,
			"burst %d must not tumble like paper" % i)
	rig.free()


## One hue per burst -- a real shell is a single colour, and one colour per
## burst is the opposite of the "three colors" mixed spray the volley read as.
## None may reuse PaperConfetti's red/yellow/blue: that palette is the very
## thing the effect was being mistaken for.
func test_each_burst_wears_its_own_shell_colour() -> void:
	var rig := _rig()
	if rig == null:
		return
	var paper := [
		Color(0.8980392, 0.28235295, 0.3019608),
		Color(1, 0.7882353, 0.23529412),
		Color(0.23137255, 0.50980395, 0.9647059),
	]
	var hues: Array[Color] = []
	var mats := _materials(rig)
	for i in mats.size():
		var ramp := mats[i].color_initial_ramp as GradientTexture1D
		assert_true(ramp != null, "burst %d must carry a shell colour ramp" % i)
		if ramp == null or ramp.gradient == null:
			continue
		assert_gt(ramp.gradient.get_point_count(), 0,
			"burst %d's shell gradient must have a stop" % i)
		if ramp.gradient.get_point_count() > 0:
			hues.append(ramp.gradient.get_color(0))
	assert_eq(hues.size(), 3, "all three shells must declare a hue")
	for i in hues.size():
		for j in paper.size():
			assert_true(
				absf(hues[i].r - paper[j].r) > 0.01
				or absf(hues[i].g - paper[j].g) > 0.01
				or absf(hues[i].b - paper[j].b) > 0.01,
				"burst %d must not reuse PaperConfetti's palette" % i)
	if hues.size() == 3:
		assert_true(hues[0] != hues[1] and hues[1] != hues[2] and hues[0] != hues[2],
			"each burst must be its own colour")
	rig.free()


## The single biggest tell that this was not a firework: every piece vanished
## at full opacity. The shared fade ramp must end fully transparent.
func test_the_sparks_fade_out() -> void:
	var rig := _rig()
	if rig == null:
		return
	var mats := _materials(rig)
	for i in mats.size():
		var ramp := mats[i].color_ramp as GradientTexture1D
		assert_true(ramp != null, "burst %d must fade over its life" % i)
		if ramp == null or ramp.gradient == null:
			continue
		var last := ramp.gradient.get_point_count() - 1
		if last >= 0:
			assert_eq(ramp.gradient.get_color(last).a, 0.0,
				"burst %d must fade to nothing, not pop out at full alpha" % i)
	rig.free()


## A shell opens in every direction. 55 degrees was a narrow upward cone,
## which is a spray, not a burst.
func test_the_shell_opens_in_every_direction() -> void:
	var rig := _rig()
	if rig == null:
		return
	var mats := _materials(rig)
	for i in mats.size():
		assert_true(mats[i].spread >= 180.0,
			"burst %d must open in every direction, got spread %d"
				% [i, int(mats[i].spread)])
	rig.free()


## visibility_rect gates whether the NODE is processed; it never clips. All
## three bursts sit on screen, so nothing was ever being culled -- this is
## hygiene against a future reparent or off-screen placement, sized to the
## farthest a spark can travel (~839 px). Modelled on test_paper_confetti.gd.
func test_visibility_rect_covers_the_flight() -> void:
	var rig := _rig()
	if rig == null:
		return
	for i in 3:
		var node: GPUParticles2D = rig.get_burst(i)
		if node == null:
			continue
		assert_true(node.visibility_rect.size.x >= 1000.0,
			"burst %d's visibility_rect is too narrow for its flight" % i)
		assert_true(node.visibility_rect.size.y >= 1000.0,
			"burst %d's visibility_rect is too short for its flight" % i)
	rig.free()


## The volley used to fire all three bursts at every star count, because
## star_row always holds three children so the index was never out of range
## -- a one-star loss got the same celebration as a full house.
##
## Both halves of this scan matter: a check for the gate alone would pass
## while `_star_count` was never assigned, in which case NO burst ever fires
## and a three-star win is silent -- the opposite tonal bug. A behavioural
## assert is not available here because play() is a coroutine and no test in
## this runner may await.
func test_the_volley_is_gated_on_earned_stars() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_true(src != "", "MinigameResultPopup.gd must be readable")
	assert_true(src.contains("star_index < _star_count"),
		"the burst must be gated on the earned star count")
	assert_true(src.contains("_star_count = stars"),
		"_star_count must actually be assigned, or the gate silences every burst")


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
