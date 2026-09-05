@tool
extends McpTestSuite

## EndCutscene (2026-09-05): the win/lose beat between StatCheck and
## RunResult. One scene, dressed by GameState.run_failed.
##
## Structural checks on a bare instantiate() plus source scans -- the white
## fade-out, the badge slam and the button reveal are a tween/timer chain the
## runner cannot await (see test_lobby.gd's no-coroutine note). Suite is
## @tool and no test is a coroutine.

const _SCENE := "res://Scenes/EndGame/EndCutscene.tscn"
const _SCRIPT := "res://Scripts/EndGame/EndCutscene.gd"


func suite_name() -> String:
	return "end_cutscene"


func test_badges_and_backdrops_exist_on_disk() -> void:
	for p in ["res://Assets/Images/UI/Placeholders/stamp_lulus.svg",
			"res://Assets/Images/UI/Placeholders/stamp_gagal.svg",
			"res://Assets/Images/CG/cg_lose.jpg"]:
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")


## Godot rasterises SVG through ThorVG, whose <text> support varies by
## version -- a dropped <text> imports as an empty outlined box with no word
## in it, which looks fine in the file and wrong in the game. This samples
## the badge's interior, a band that the tilted rect's own stroke provably
## cannot reach (the -12 degree rotation moves the horizontal edges at most
## ~28px, well clear of it), so any opaque pixel found there is lettering.
func test_the_stamps_actually_rendered_their_word() -> void:
	for p in ["res://Assets/Images/UI/Placeholders/stamp_lulus.svg",
			"res://Assets/Images/UI/Placeholders/stamp_gagal.svg"]:
		# CACHE_MODE_IGNORE: the editor keeps imported textures alive for the
		# session, so a plain load() here can hand back the pre-reimport
		# rasterisation and quietly test the wrong bytes.
		var tex: Texture2D = ResourceLoader.load(
			p, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		var img: Image = tex.get_image()
		assert_not_null(img, p + " rasterised to an image")
		var w := img.get_width()
		var h := img.get_height()
		var opaque := 0
		for y in range(int(h * 0.44), int(h * 0.66)):
			for x in range(int(w * 0.35), int(w * 0.65)):
				if img.get_pixel(x, y).a > 0.1:
					opaque += 1
		assert_gt(opaque, 40,
			"%s has no lettering inside its frame (%d opaque px in a %dx%d " % [p, opaque, w, h] +
			"image) -- the word did not rasterise; redraw it as paths")


func _scene() -> Node:
	var s = load(_SCENE).instantiate()
	track(s)
	return s


func test_scene_has_the_chrome() -> void:
	var s := _scene()
	assert_true(s is EndCutscene, "the scene wears EndCutscene.gd")
	assert_true(s.get_node_or_null("Backdrop") is TextureRect, "Backdrop")
	assert_true(s.get_node_or_null("Badge") is TextureRect, "Badge")
	assert_true(s.get_node_or_null("BtnNext") is Button, "BtnNext")
	assert_true(s.get_node_or_null("WhiteFade") is ColorRect, "WhiteFade")


func test_white_overlay_starts_opaque_to_finish_stat_checks_fade() -> void:
	var s := _scene()
	var white: ColorRect = s.get_node("WhiteFade")
	assert_true(is_equal_approx(white.color.a, 1.0),
		"the overlay's colour is fully opaque")
	assert_true(is_equal_approx(white.modulate.a, 1.0),
		"and it is not pre-faded -- StatCheck hands over mid-white")
	assert_eq(white.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay must never eat the Next button's clicks")


func test_white_overlay_draws_over_everything() -> void:
	var s := _scene()
	var kids := s.get_children()
	assert_eq(String(kids[kids.size() - 1].name), "WhiteFade",
		"WhiteFade is the last child, so it covers backdrop, badge and button")


func test_badge_starts_invisible_in_the_top_left() -> void:
	var s := _scene()
	var badge: TextureRect = s.get_node("Badge")
	assert_true(is_equal_approx(badge.modulate.a, 0.0),
		"the badge is invisible until it slams")
	assert_true(badge.position.x < 200.0 and badge.position.y < 400.0,
		"the badge sits in the top-left corner")


func test_next_button_starts_hidden_and_disabled() -> void:
	var s := _scene()
	var btn: Button = s.get_node("BtnNext")
	assert_true(is_equal_approx(btn.modulate.a, 0.0),
		"the button is invisible until the badge has landed")
	assert_true(btn.disabled,
		"and unpressable -- it is the only way forward, so it must not " +
		"be clickable before its cue")


func test_both_verdicts_are_dressed_from_exports() -> void:
	var s := _scene()
	assert_true(s.win_backdrop is Texture2D, "a win backdrop is assigned")
	assert_true(s.lose_backdrop is Texture2D, "a lose backdrop is assigned")
	assert_true(s.win_badge is Texture2D, "a win badge is assigned")
	assert_true(s.lose_badge is Texture2D, "a lose badge is assigned")
	assert_ne(s.win_backdrop, s.lose_backdrop, "the two outcomes look different")
	assert_ne(s.win_badge, s.lose_badge, "so do their badges")
	assert_eq(String(s.win_bgm), "result_win", "win BGM")
	assert_eq(String(s.lose_bgm), "result_lose", "lose BGM")


func test_verdict_comes_from_the_flag_stat_check_wrote() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("GameState.run_failed"),
		"the screen dresses itself from StatCheck's verdict")
	assert_false(src.contains("check_semester_passed"),
		"it must not recompute the verdict -- StatCheck already decided it")


func test_sequence_is_fade_then_slam_then_button() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var fade_at := src.find("tween_property(white_fade, \"modulate:a\", 0.0, white_fade_seconds)")
	var slam_at := src.find("_slam_badge()")
	var enable_at := src.find("btn_next.disabled = false")
	assert_true(fade_at != -1, "the white overlay clears")
	assert_true(slam_at != -1, "the badge slams")
	assert_true(enable_at != -1, "the button becomes pressable")
	assert_true(fade_at < slam_at and slam_at < enable_at,
		"in that order: the image first, then the badge, then the button")


func test_slam_is_the_same_stamp_gesture_run_result_uses() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("badge.scale = Vector2(3.0, 3.0)"), "slams down from 3x")
	assert_true(src.contains("Tween.EASE_IN).set_trans(Tween.TRANS_BACK)"), "back-out overshoot")
	assert_true(src.contains("Juice.shake(badge.get_parent()"), "shakes the screen")
	assert_true(src.contains("AudioDirector.play_sfx(&\"stamp\")"), "the stamp cue")


func test_the_button_is_the_only_way_to_run_result() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const RUN_RESULT_SCENE := \"res://Scenes/EndGame/RunResult.tscn\""),
		"RunResult is the destination")
	assert_true(src.contains("Transition.change_scene(RUN_RESULT_SCENE)"),
		"the hand-off uses the project-wide wipe")
	assert_true(src.contains("btn_next.pressed.connect(_on_next_pressed)"),
		"the button is wired to the hand-off")
	assert_false(src.contains("func _input(") or src.contains("InputEventScreenTouch"),
		"no tap-anywhere path -- the button is the only input")


func test_button_label_is_indonesian() -> void:
	var s := _scene()
	assert_eq(s.get_node("BtnNext").text, "Lanjut",
		"UI text is Indonesian, matching TesNotice's forward button")
