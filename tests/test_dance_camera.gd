@tool
extends McpTestSuite

## LombaMenari's Friday Night Funkin' note camera.
##
## A successful arrow leans the camera the way that arrow points -- RIGHT to
## the right, LEFT to the left, TOP_LEFT up-left, TOP_RIGHT up-right -- holds
## the lean for a beat, then drifts home. The stage (backdrop and dancer)
## slides the opposite way on screen, as the world does under a panning
## camera; the notes, hit zone and score HUD hold still, as FNF's HUD camera
## does.
##
## The lean itself lives in DanceCamera.gd, a @tool RefCounted, so it is
## tested here by behaviour. LombaMenari.gd extends BaseMinigame, which is
## deliberately not @tool (see test_minigame_star_rubric.gd), so its side is
## tested through a static helper and, where that runs out, by source scan.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "dance_camera"


const DanceCamera := preload("res://Scripts/Minigames/SeniBudaya/DanceCamera.gd")
## LombaMenari.gd declares no class_name -- see test_minigame_star_rubric.gd
## for why a preloaded Script const stands in for the class name.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")
const MENARI_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
const MENARI_SCENE := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"

## ln 2. At this follow speed every second closes exactly half the remaining
## gap (1 - e^-ln2 = 0.5), so each expectation below can be worked by hand.
const HALF_PER_SECOND: float = 0.6931472

## The design canvas the Background's anchors are measured against.
const SCREEN := Vector2(1080, 1920)


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01


## The text of `func fn_name(` up to the next top-level func.
func _func_body(src: String, fn_name: String) -> String:
	var start := src.find("func %s(" % fn_name)
	if start == -1:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, end - start) if end != -1 else src.substr(start)


# --- DanceCamera: the lean ---------------------------------------------------

## Break caught: FNF's frame-counted `lerp(cam, target, speed * elapsed)`
## ported as-is, which covers a different share of the gap per second at 30
## and at 120 fps, or a follow that jumps straight onto its target.
func test_follow_closes_the_same_share_of_the_gap_each_second() -> void:
	var one_second := DanceCamera.follow(Vector2.ZERO, Vector2(30, 0), HALF_PER_SECOND, 1.0)
	assert_true(_near(one_second, Vector2(15, 0)),
		"one second at ln 2 closes half the gap, got %s" % one_second)
	var half := DanceCamera.follow(Vector2.ZERO, Vector2(30, 0), HALF_PER_SECOND, 0.5)
	var two_halves := DanceCamera.follow(half, Vector2(30, 0), HALF_PER_SECOND, 0.5)
	assert_true(_near(two_halves, Vector2(15, 0)),
		"two half-second frames land where one full second does, got %s" % two_halves)


## Break caught: a weight that passes 1 on a long frame -- a hitch, or the
## first frame back from the pause menu -- flinging the stage past its mark.
func test_follow_settles_on_the_target_after_a_long_frame() -> void:
	var got := DanceCamera.follow(Vector2.ZERO, Vector2(30, 0), 4.0, 10.0)
	assert_true(_near(got, Vector2(30, 0)), "a 10 s frame lands on the target, got %s" % got)


## Break caught: a lean that never comes home, or one that heads home before
## its hold is up.
func test_a_lean_holds_then_drifts_home() -> void:
	var cam := DanceCamera.new()
	cam.lean(Vector2(30, 0), 1.0)
	var early := cam.step(0.5, HALF_PER_SECOND)
	var later := cam.step(0.25, HALF_PER_SECOND)
	assert_true(later.x > early.x,
		"inside the hold it keeps leaning out: %s then %s" % [early, later])
	cam.step(0.5, HALF_PER_SECOND) # the hold runs out during this frame
	var returning := cam.step(1.0, HALF_PER_SECOND)
	var nearer := cam.step(1.0, HALF_PER_SECOND)
	assert_true(nearer.x < returning.x and nearer.x >= 0.0,
		"past the hold it drifts home without overshooting: %s then %s" % [returning, nearer])


## Break caught: a miss that leaves the camera leaning into a pose the dancer
## has already dropped.
func test_recenter_heads_home_without_waiting_for_the_hold() -> void:
	var cam := DanceCamera.new()
	cam.lean(Vector2(30, 0), 5.0)
	var out := cam.step(1.0, HALF_PER_SECOND)
	assert_true(_near(out, Vector2(15, 0)), "halfway out after a second, got %s" % out)
	cam.recenter()
	var back := cam.step(1.0, HALF_PER_SECOND)
	assert_true(_near(back, Vector2(7.5, 0)),
		"with four seconds of hold unspent, it still heads home, got %s" % back)


## Break caught: a second hit that re-aims the camera but keeps the first
## hit's countdown, so a quick run of arrows snaps home mid-streak.
func test_every_hit_restarts_the_hold() -> void:
	var cam := DanceCamera.new()
	cam.lean(Vector2(30, 0), 1.0)
	cam.step(0.75, HALF_PER_SECOND)
	cam.lean(Vector2(30, 0), 1.0) # the same arrow again, 0.75 s later
	var a := cam.step(0.5, HALF_PER_SECOND) # 1.25 s after the first hit
	var b := cam.step(0.25, HALF_PER_SECOND)
	assert_true(b.x > a.x,
		"the second hit's hold is still running at 1.5 s: %s then %s" % [a, b])


## Break caught: a lean added to the last one instead of replacing it, so
## LEFT straight after RIGHT cancels out rather than swinging across.
func test_a_new_arrow_swings_the_camera_across() -> void:
	var cam := DanceCamera.new()
	cam.lean(Vector2(30, 0), 20.0)
	cam.step(10.0, 4.0) # settle on the right-hand lean
	cam.lean(Vector2(-30, 0), 20.0)
	var got := cam.step(1.0, HALF_PER_SECOND)
	assert_true(_near(got, Vector2.ZERO),
		"halfway from +30 to -30 is dead centre, got %s" % got)


# --- LombaMenari: the wiring -------------------------------------------------

## The request, one row per arrow: the camera leans the way the arrow points.
## Up is -y on a Godot screen; 21.213 is 30 * sqrt(0.5).
## Break caught: a swapped or mirrored arrow, a flipped y, a diagonal that
## leans 1.41x as far as a side arrow, or a distance that is never applied.
func test_each_arrow_leans_the_camera_its_own_way() -> void:
	var want := {
		MenariScript.NoteType.RIGHT: Vector2(30, 0),
		MenariScript.NoteType.LEFT: Vector2(-30, 0),
		MenariScript.NoteType.TOP_RIGHT: Vector2(21.213, -21.213),
		MenariScript.NoteType.TOP_LEFT: Vector2(-21.213, -21.213),
	}
	for arrow in want:
		var got: Vector2 = MenariScript._camera_lean_for(arrow, 30.0)
		assert_true(_near(got, want[arrow]),
			"%s leans to %s, got %s" % [MenariScript.NoteType.keys()[arrow], want[arrow], got])


## Break caught: a backdrop framed flush with the screen -- the first lean
## would slide it off an edge and bare a strip of nothing. The stage slides
## opposite the camera, so every lean needs the backdrop to reach at least
## that far past the edge the stage slides away from.
func test_the_backdrop_reaches_past_every_edge_a_lean_uncovers() -> void:
	var scene: Node = (load(MENARI_SCENE) as PackedScene).instantiate()
	track(scene)
	var bg := scene.get_node_or_null("Background") as Control
	assert_true(bg != null, "LombaMenari needs its Background")
	var distance: Variant = scene.get("camera_look_distance")
	assert_true(distance is float, "LombaMenari exposes camera_look_distance, got %s" % distance)
	if bg == null or not (distance is float):
		return
	# How far each edge of the backdrop reaches past the screen's.
	var spare_left: float = -(bg.anchor_left * SCREEN.x + bg.offset_left)
	var spare_right: float = bg.anchor_right * SCREEN.x + bg.offset_right - SCREEN.x
	var spare_top: float = -(bg.anchor_top * SCREEN.y + bg.offset_top)
	var spare_bottom: float = bg.anchor_bottom * SCREEN.y + bg.offset_bottom - SCREEN.y
	for arrow in MenariScript.NoteType.values():
		var slide: Vector2 = -MenariScript._camera_lean_for(arrow, distance)
		var arrow_name: String = MenariScript.NoteType.keys()[arrow]
		if slide.x > 0.0:
			assert_true(spare_left >= slide.x, "%s slides the stage %.1f px right, but the backdrop reaches only %.1f px past the left edge" % [arrow_name, slide.x, spare_left])
		if slide.x < 0.0:
			assert_true(spare_right >= -slide.x, "%s slides the stage %.1f px left, but the backdrop reaches only %.1f px past the right edge" % [arrow_name, -slide.x, spare_right])
		if slide.y > 0.0:
			assert_true(spare_top >= slide.y, "%s slides the stage %.1f px down, but the backdrop reaches only %.1f px past the top edge" % [arrow_name, slide.y, spare_top])
		if slide.y < 0.0:
			assert_true(spare_bottom >= -slide.y, "%s slides the stage %.1f px up, but the backdrop reaches only %.1f px past the bottom edge" % [arrow_name, -slide.y, spare_bottom])


## LombaMenari cannot run in this editor-hosted runner -- BaseMinigame is not
## @tool -- so the last link, from its judge to the camera and from the camera
## to the stage, is checked by source scan.
## Break caught: a hit that never leans the camera, a miss that leaves it
## leaning, or a camera whose slide never reaches the backdrop or the dancer.
func test_hits_lean_the_camera_misses_recenter_it_and_the_stage_follows() -> void:
	var src := FileAccess.get_file_as_string(MENARI_PATH)
	assert_contains(_func_body(src, "_play_dancer_motion"), "dance_camera.lean(",
		"a successful arrow leans the camera")
	assert_contains(_func_body(src, "_play_dancer_fail_motion"), "dance_camera.recenter()",
		"a miss sends it home")
	assert_contains(_func_body(src, "_ready"), "background_rest_position = background_rect.position",
		"the backdrop's authored framing is kept as the camera's rest, not reset to 0,0")
	var frame := _func_body(src, "_process")
	assert_contains(frame, "stage_slide: Vector2 = -dance_camera.step(",
		"the stage slides against the camera's lean, as the world does under a pan")
	assert_contains(frame, "background_rest_position + stage_slide",
		"the backdrop slides with the camera")
	assert_contains(frame, "dancer_base_position + stage_slide",
		"and so does the dancer")
