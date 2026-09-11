@tool
extends McpTestSuiteCompat

## WinStage (2026-09-11): the end-of-grade painting with the run's roster
## posed on it, shared by EndCutscene and RunResult so the two screens open
## and close on the same frame. dress() is plain synchronous code, so the
## layout is exercised live here; the host wiring is covered by
## test_end_cutscene.gd and test_run_result.gd. Suite is @tool and no test
## is a coroutine.

const _SCENE := "res://Scenes/EndGame/WinStage.tscn"
const _SCRIPT := "res://Scripts/EndGame/WinStage.gd"
const _FOUR := ["Doni", "Andi", "Citra", "Shinta"]


func suite_name() -> String:
	return "win_stage"


func _stage() -> WinStage:
	var s: WinStage = load(_SCENE).instantiate()
	track(s)
	return s


## In the editor's root so @onready resolves and dress() can measure a real
## viewport. The caller removes it again before asserting.
func _live_stage() -> WinStage:
	var s := _stage()
	Engine.get_main_loop().root.add_child(s)
	return s


# ───────────────────────────────────────────────────────────── scene shape

func test_the_scene_wears_win_stage() -> void:
	assert_true(_stage() is WinStage, "WinStage.tscn's root runs WinStage.gd")


func test_the_letterbox_bars_are_painted_behind_the_painting() -> void:
	var s := _stage()
	var bars = s.get_node_or_null("BarFill")
	assert_true(bars is ColorRect, "a ColorRect fills the letterbox bars")
	assert_true(bars.get_index() < s.get_node("Stage").get_index(),
		"the bars are behind the painting")
	assert_true(bars.color.a > 0.9, "the bars are opaque -- nothing shows through")
	assert_eq(bars.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the bars never eat a host's clicks")


func test_the_stage_is_the_paintings_art_space() -> void:
	var stage := _stage().get_node_or_null("Stage")
	assert_true(stage is Control, "Stage holds the painting and its figures")
	var backdrop = stage.get_node_or_null("Backdrop")
	assert_true(backdrop is TextureRect, "the painting")
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Backdrop covers whatever Stage it sits in, on both verdicts")
	assert_true(stage.get_node_or_null("Shadows") is Control, "the Shadows layer")
	assert_true(stage.get_node_or_null("Students") is Control, "the Students layer")


## All shadows are drawn before all figures, rather than pairing each shadow
## with its own sprite. Pairing would let Doni's wide crouch-shadow smear
## across the side students' shoes.
func test_shadows_draw_beneath_every_student() -> void:
	var stage := _stage().get_node("Stage")
	var backdrop: int = stage.get_node("Backdrop").get_index()
	var shadows: int = stage.get_node("Shadows").get_index()
	var students: int = stage.get_node("Students").get_index()
	assert_true(backdrop < shadows, "the backdrop is behind the shadows")
	assert_true(shadows < students, "every shadow is behind every figure")


func test_the_stage_has_four_authored_slots_and_four_shadows() -> void:
	var stage := _stage().get_node("Stage")
	for i in range(1, 5):
		assert_true(stage.get_node_or_null("Students/Student%d" % i) is TextureRect,
			"Student%d is authored in the scene, not built at runtime" % i)
		assert_true(stage.get_node_or_null("Shadows/Shadow%d" % i) is TextureRect,
			"Shadow%d is authored in the scene, not built at runtime" % i)


## The art lives here and only here -- neither host overrides it, which is
## what guarantees the two screens show the same picture.
func test_both_verdicts_art_is_wired() -> void:
	var s := _stage()
	assert_true(s.win_backdrop is Texture2D, "a win painting is assigned")
	assert_true(s.lose_backdrop is Texture2D, "a lose CG is assigned")
	assert_ne(s.win_backdrop, s.lose_backdrop, "the two outcomes look different")
	assert_eq(String(s.win_backdrop.resource_path),
		"res://Assets/Images/CG/Win/win_background.png", "the graduation painting")
	assert_true(s.shadow_texture is Texture2D, "the ground shadow art is assigned")


## Six typed Texture2D exports, not one Dictionary -- a Dictionary's nested
## values cannot be wired as Resources through the editor's property API.
func test_every_roster_name_has_a_splash_wired() -> void:
	var s := _stage()
	for student_name in ["Doni", "Andi", "Citra", "Shinta", "Marcel", "Thea"]:
		assert_true(s._splash_for(student_name) is Texture2D,
			student_name + "'s splash is a texture")
	assert_true(s._splash_for("Nobody") == null, "an unknown name has no splash")


func test_the_shadow_knobs_are_exported() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for prop in ["shadow_opacity", "shadow_spread", "shadow_flatness", "bar_color",
			"win_splash_doni"]:
		assert_true(src.contains("@export var " + prop), prop + " is tunable in the Inspector")


# ─────────────────────────────────────────────────────────────── the maths

func test_the_letterbox_fits_the_whole_painting_and_centres_it() -> void:
	var tall: Dictionary = WinStage.letterbox(Vector2(1080, 1920))
	assert_true(is_equal_approx(tall["scale"], 0.703125), "1080 / 1536")
	assert_eq(tall["position"], Vector2(0, 240), "240px bars top and bottom")
	var taller: Dictionary = WinStage.letterbox(Vector2(1080, 2340))
	assert_eq(taller["position"], Vector2(0, 450), "a taller phone gets taller bars")
	var native: Dictionary = WinStage.letterbox(Vector2(1536, 2048))
	assert_true(is_equal_approx(native["scale"], 1.0), "the art's own size is scale 1")
	assert_eq(native["position"], Vector2.ZERO, "with no bars")


func test_the_stage_fits_by_computed_scale_not_a_hardcoded_transform() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("minf("), "it fits by the smaller of the two ratios")
	assert_false(src.contains("0.703125"),
		"the letterbox scale is derived from the viewport, not pasted in")


func test_names_of_reads_names_in_roster_order() -> void:
	var names: Array = WinStage.names_of([{"name": "Citra"}, {"name": "Doni"}, {}])
	assert_eq(names, ["Citra", "Doni", ""], "one name per student, in roster order")


# ──────────────────────────────────────────────────────────────── dressing

func test_dressing_a_win_poses_the_roster_on_the_letterboxed_painting() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	var vp: Vector2 = s.get_viewport_rect().size
	var fit: Dictionary = WinStage.letterbox(vp)
	var stage: Control = s.get_node("Stage")
	var backdrop_tex: Texture2D = s.get_node("Stage/Backdrop").texture
	var shown := 0
	for i in range(1, 5):
		var sprite: TextureRect = s.get_node("Stage/Students/Student%d" % i)
		var shadow: TextureRect = s.get_node("Stage/Shadows/Shadow%d" % i)
		if sprite.visible and sprite.texture != null and shadow.visible:
			shown += 1
	var bars_size: Vector2 = s.get_node("BarFill").size
	Engine.get_main_loop().root.remove_child(s)
	assert_eq(backdrop_tex, s.win_backdrop, "the win painting")
	assert_eq(shown, 4, "four students stand on it, each with a shadow")
	assert_true(is_equal_approx(stage.scale.x, stage.scale.y), "scaled uniformly")
	assert_true(is_equal_approx(stage.scale.x, fit["scale"]), "by the letterbox scale")
	assert_true(stage.position.is_equal_approx(fit["position"]), "and centred")
	assert_eq(bars_size, vp, "the bars fill the whole screen behind it")


## Lose keeps the framing the CG always had: Stage fills the viewport and
## Backdrop's KEEP_ASPECT_COVERED crops it. Dressed after a win on purpose,
## so a stale lineup cannot survive onto the lose CG.
func test_dressing_a_loss_covers_the_screen_and_hides_the_lineup() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	s.dress(true, _FOUR)
	var vp: Vector2 = s.get_viewport_rect().size
	var stage: Control = s.get_node("Stage")
	var backdrop_tex: Texture2D = s.get_node("Stage/Backdrop").texture
	var visible_slots := 0
	for i in range(1, 5):
		if s.get_node("Stage/Students/Student%d" % i).visible:
			visible_slots += 1
		if s.get_node("Stage/Shadows/Shadow%d" % i).visible:
			visible_slots += 1
	Engine.get_main_loop().root.remove_child(s)
	assert_eq(backdrop_tex, s.lose_backdrop, "the lose CG")
	assert_eq(stage.scale, Vector2.ONE, "unscaled")
	assert_eq(stage.size, vp, "covering the viewport")
	assert_eq(visible_slots, 0, "no student or shadow survives onto the lose CG")


func test_the_lineup_comes_from_win_lineup() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("WinLineup.assign("), "slot assignment lives in WinLineup")
	assert_true(src.contains("WinLineup.shadow_for("), "so does shadow geometry")


## StatCheck wrote the verdict; the stage only draws what it is told.
func test_the_stage_never_decides_the_verdict() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_false(src.contains("check_semester_passed"),
		"WinStage must not recompute the verdict")
