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
	assert_true(src.contains("get_tree().change_scene_to_file(RUN_RESULT_SCENE)"),
		"the hand-off is a direct swap under the blur, not a wipe")
	assert_false(src.contains("Transition.change_scene"),
		"the project-wide wipe must be gone -- the blur IS the transition, "
		+ "and a wipe on top of it would read as two transitions")
	assert_true(src.contains("btn_next.pressed.connect(_on_next_pressed)"),
		"the button is wired to the hand-off")
	assert_false(src.contains("func _input(") or src.contains("InputEventScreenTouch"),
		"no tap-anywhere path -- the button is the only input")


func test_button_label_is_indonesian() -> void:
	var s := _scene()
	assert_eq(s.get_node("BtnNext").text, "Lanjut",
		"UI text is Indonesian, matching TesNotice's forward button")


# ─────────────────────────────────────────────────── the blur-out hand-off

const _BLUR_SHADER := "res://Scripts/Shaders/blur.gdshader"


## The exit blurs the backdrop in place instead of wiping the screen. The
## layer is authored in the .tscn, never built at runtime -- same ColorRect +
## blur.gdshader pattern the shop's BlurLayer uses (koprasi.tscn:Rak1/BlurLayer).
func test_the_scene_carries_an_authored_blur_layer() -> void:
	var s := _scene()
	var layer = s.get_node_or_null("BlurLayer")
	assert_true(layer is ColorRect, "BlurLayer is an authored ColorRect")
	assert_true(layer.material is ShaderMaterial, "it wears a ShaderMaterial")
	assert_eq(layer.material.shader.resource_path, _BLUR_SHADER,
		"reusing the project's blur shader rather than a second one")
	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the layer must never eat the Next button's clicks")


## It covers the screen but is inert until the button is pressed: hidden, and
## with both shader parameters at zero so showing it cannot pop. lod 0 makes
## textureLod an identity sample and darkness 0 leaves the colour untouched.
##
## Behavioural, not a read of the authored values: the scene stores
## darkness at the shader's own 0.3 default (Godot serialises uniform
## defaults, and the MCP property validator cannot author shader_parameter/*),
## so _ready() is what actually parks it at 0. Adding the node to the tree is
## what proves that -- checking the .tscn alone would assert 0.3 and pass
## while the real screen dimmed the instant the layer appeared.
func test_the_blur_layer_starts_inert() -> void:
	var s := _scene()
	var layer: ColorRect = s.get_node("BlurLayer")
	assert_false(layer.visible, "hidden until the hand-off")
	Engine.get_main_loop().root.add_child(s)
	var mat: ShaderMaterial = layer.material
	var lod := float(mat.get_shader_parameter("lod"))
	var dark := float(mat.get_shader_parameter("darkness"))
	Engine.get_main_loop().root.remove_child(s)
	assert_true(is_equal_approx(lod, 0.0),
		"lod is parked at 0 -- an identity sample, so showing it is invisible")
	assert_true(is_equal_approx(dark, 0.0),
		"and darkness at 0 for the same reason, whatever the scene stored")


## Draw order is the whole mechanism: the shader samples what is already on
## screen, so only siblings BEFORE it get blurred. Backdrop must be behind it;
## Badge and BtnNext must stay in front and stay sharp.
func test_the_blur_layer_blurs_the_backdrop_but_not_the_badge_or_button() -> void:
	var s := _scene()
	var order: Array[String] = []
	for c in s.get_children():
		order.append(String(c.name))
	var backdrop_at := order.find("Backdrop")
	var blur_at := order.find("BlurLayer")
	var badge_at := order.find("Badge")
	var btn_at := order.find("BtnNext")
	assert_true(backdrop_at < blur_at,
		"Backdrop draws first, so the shader samples it")
	assert_true(blur_at < badge_at and blur_at < btn_at,
		"Badge and BtnNext draw after the blur, so they stay sharp")
	assert_eq(String(s.get_children()[s.get_child_count() - 1].name), "WhiteFade",
		"WhiteFade still covers everything")


func test_the_blur_pacing_is_exported_and_tunable() -> void:
	var s := _scene()
	assert_true(s.blur_seconds > 0.0, "the blur takes a tunable time")
	assert_true(s.blur_lod > 0.0, "it reaches a tunable strength")
	assert_true(s.blur_darkness >= 0.0, "and a tunable dim")
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for name in ["blur_seconds", "blur_lod", "blur_darkness"]:
		assert_true(src.contains("@export var " + name),
			name + " is an @export, not a magic number")


## The order that matters: blur first, hand off second. Handing off first
## would swap the scene out before a single frame of the blur was drawn.
func test_the_exit_blurs_before_it_hands_off() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var blur_at := src.find("await _blur_out()")
	var swap_at := src.find("get_tree().change_scene_to_file(RUN_RESULT_SCENE)")
	assert_true(blur_at != -1, "the exit awaits the blur")
	assert_true(swap_at != -1, "then swaps to RunResult")
	assert_true(blur_at < swap_at, "blur first, swap second")
	assert_true(src.contains("shader_parameter/lod"),
		"the blur is animated by tweening the shader parameters")
