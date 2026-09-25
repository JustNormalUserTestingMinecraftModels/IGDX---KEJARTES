@tool
extends McpTestSuite

## The global look layer and the illustration grade (2026-09-22, premium-look
## PR 4).
##
## Two separate things, deliberately: a vignette and grain drawn over the
## whole game from one autoload, and a colour grade applied per node to the
## painted art and to nothing else. Keeping them separate is the point -- the
## design tokens stay the honest description of the UI's colour, because the
## grade never touches the UI.
##
## Must be @tool, and no test here may be a coroutine.

const LAYER_SCENE := "res://Scenes/Look/LookLayer.tscn"
const GRADE_MATERIAL := "res://Scripts/Shaders/illustration_grade_material.tres"
const GRADE_CUTOUT_MATERIAL := "res://Scripts/Shaders/illustration_grade_cutout.tres"
const GRADE_FACE_MATERIAL := "res://Scripts/Shaders/illustration_grade_face.tres"
## The Lobby desks' cutout grade, lit from the upper right (2026-09-24).
const GRADE_LOBBY_CUTOUT_MATERIAL := "res://Scripts/Shaders/illustration_grade_cutout_lobby.tres"

## Every node that wears the grade, by scene. These are painted plates only.
const GRADED := {
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/BGLayer", "Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
	"res://Scenes/Koperasi/koprasi.tscn": [
		"Stage/Background", "Stage/Herman", "Stage/Foreground",
	],
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": ["Splash"],
	"res://Scenes/Minigames/UI/MinigameWinScreen.tscn": ["Root/Splash"],
	"res://Scenes/Lobby/AndiFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/CitraFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/DoniFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/MarcelFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/ShintaFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/TheaFace.tscn": ["Canvas/Base"],
	# The minigames (2026-09-22). Painted plates only: the full-screen
	# backdrops, the painted characters and props, the calculator body. The
	# card chrome, tool icons and key caps stay ungraded -- they are interface
	# drawn from the tokens, the same line the rest of this dict holds.
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/Password.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/Variabel.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/Kalkulator.tscn": ["Body/BodyTexture"],
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": ["Background"],
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": ["Background"],
	"res://Scenes/Minigames/SeniBudaya/DancerRig.tscn": ["Body", "Head"],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": [
		"FieldBG", "Goalie/GFX", "Ball/GFX",
	],
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": [
		"Puck/Sprite2D", "PlayerPaddle/Sprite2D", "EnemyPaddle/Sprite2D",
	],
}


func suite_name() -> String:
	return "look_layer"


# ── The look layer ───────────────────────────────────────────────────────────

## 90 covers every screen (all of which live on layer 0) while staying under
## the things that must never be tinted. If someone raises it past the wipe or
## the debug overlay, those get graded too.
func test_the_layer_sits_above_the_game_and_below_the_tools() -> void:
	var layer: Node = Engine.get_main_loop().root.get_node_or_null("LookLayer")
	assert_true(layer != null, "the LookLayer autoload must be in the tree")
	if layer == null:
		return
	assert_eq(layer.layer, 90, "the look layer's CanvasLayer number")
	var transition: Node = Engine.get_main_loop().root.get_node_or_null("Transition")
	if transition != null:
		assert_true(layer.layer < transition.layer,
			"the wipe must cover the look layer, not be tinted by it")
	var toast: Node = Engine.get_main_loop().root.get_node_or_null("AchievementToast")
	if toast != null:
		assert_true(layer.layer < toast.layer, "the toast must not be vignetted")


## A full-screen overlay that accepts input makes the entire game unclickable.
## This is the single worst failure mode available to this node.
func test_the_cover_can_never_eat_a_tap() -> void:
	var scene := (load(LAYER_SCENE) as PackedScene).instantiate()
	track(scene)
	var cover := scene.get_node_or_null("Cover") as Control
	assert_true(cover != null, "LookLayer needs its Cover")
	if cover == null:
		return
	assert_eq(cover.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the cover spans the whole screen; hit-testable it would block everything")


## The vignette must be drawn in a shader on a Full Rect ColorRect, never as
## a texture. With aspect="expand" the viewport is 1080x2400 on a 20:9 phone,
## and a 1080x1920 vignette PNG under Keep Aspect Covered would crop its own
## left and right falloff off the sides.
func test_the_vignette_is_procedural_not_a_texture() -> void:
	var scene := (load(LAYER_SCENE) as PackedScene).instantiate()
	track(scene)
	var cover := scene.get_node_or_null("Cover") as ColorRect
	assert_true(cover != null, "the cover must be a ColorRect, not a TextureRect")
	if cover == null:
		return
	assert_true(cover.material is ShaderMaterial, "the cover needs the look shader")
	assert_eq(Vector4(cover.anchor_left, cover.anchor_top,
			cover.anchor_right, cover.anchor_bottom), Vector4(0, 0, 1, 1),
		"the cover must be Full Rect so it follows any viewport")
	assert_eq(Vector4(cover.offset_left, cover.offset_top,
			cover.offset_right, cover.offset_bottom), Vector4.ZERO,
		"the cover must not be inset")


## The hardware floor is unknown and the grain is a per-pixel term over the
## whole screen every frame, so the brief asked for one switch, defaulting
## off. A default of true here would ship that cost to every device.
func test_the_look_layer_is_opt_in() -> void:
	assert_false(GameSettings.look_layer_enabled,
		"the look layer must default OFF until someone measures the floor")
	assert_true(GameSettings.has_signal("look_layer_changed"),
		"the layer reacts to a flip by signal rather than polling the setting")


## The setting has to survive a relaunch like the other two in its section.
func test_the_setting_round_trips_through_disk() -> void:
	var before: bool = GameSettings.look_layer_enabled
	GameSettings.look_layer_enabled = not before
	GameSettings.save_settings()
	GameSettings.look_layer_enabled = before
	GameSettings.load_settings()
	assert_eq(GameSettings.look_layer_enabled, not before,
		"look_layer must be written to and read back from settings.cfg")
	# Put it back the way it was found, on disk as well as in memory.
	GameSettings.look_layer_enabled = before
	GameSettings.save_settings()


## The autoload must be declared after GameSettings, because its _ready()
## reads that setting and connects to its signal. Autoloads enter the tree in
## declaration order.
func test_the_autoload_is_declared_after_its_dependencies() -> void:
	var src := FileAccess.get_file_as_string("res://project.godot")
	var look := src.find("LookLayer=")
	var settings := src.find("GameSettings=")
	assert_true(look != -1, "LookLayer must be registered as an autoload")
	assert_true(settings != -1 and settings < look,
		"LookLayer reads GameSettings in _ready, so it must be declared after it")


## The bloom (2026-09-23). A canvas_item shader reading the screen, so it runs
## on every screen and turns off with the look layer. (It was first justified by
## the WorldEnvironment route being inert; that was a wrong background mode, not
## a limit of the engine -- see the Lobby environment test below.)
func test_the_bloom_is_additive_and_reads_the_screen() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Shaders/bloom.gdshader")
	assert_true(src.contains("render_mode blend_add"),
		"bloom brightens what is behind it; it does not paint over it")
	assert_true(src.contains("hint_screen_texture"),
		"a bloom has to read the finished frame")
	assert_true(src.contains("textureLod"),
		"the blur is three mip levels, not a second pass")


## It must sit UNDER the vignette. Drawn the other way round the bloom would
## wash the vignette out at the corners, which is where a vignette does its
## only job.
func test_the_bloom_draws_under_the_vignette() -> void:
	var layer := (load(LAYER_SCENE) as PackedScene).instantiate()
	track(layer)
	var bloom := layer.get_node_or_null("Bloom") as CanvasItem
	var cover := layer.get_node_or_null("Cover") as CanvasItem
	assert_true(bloom != null, "the look layer must carry the bloom")
	assert_true(cover != null, "the look layer must carry the cover")
	if bloom == null or cover == null:
		return
	assert_true(bloom.get_index() < cover.get_index(),
		"the bloom draws first, so the vignette lands on top of it")
	assert_eq(bloom.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"a full-screen bloom must never eat a tap")


## The screen read is the one genuinely expensive thing this layer does, so an
## unchecked setting has to cost nothing rather than cost a texture fetch. The
## layer takes itself out of the draw list entirely; this pins the mechanism it
## uses to do that, since a bloom left visible at intensity 0 would still read
## the screen every frame.
func test_the_bloom_costs_nothing_when_the_layer_is_off() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Look/LookLayer.gd")
	assert_true(src.contains("visible = false"),
		"the layer must leave the draw list when off, not just fade to alpha 0")
	assert_true(src.contains("$Bloom"), "the layer must own the bloom node")


## A fade-out ends by hiding the layer. Flip Efek Visual off and back on inside
## the fade and that closing `visible = false` used to land after the re-enable,
## leaving the setting on and the layer gone. _refresh runs only in a real game,
## so this pins the guard in the source: every new fade kills the one before.
func test_a_new_fade_kills_the_one_in_flight() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Look/LookLayer.gd")
	assert_true(src.contains("_tween.kill()"),
		"_refresh must kill the previous fade before starting another")
	assert_false(src.contains("var tween := create_tween()"),
		"the fade must be kept in _tween so the next _refresh can kill it")


## Over a palette this near-white -- surface_page is #FBF1E3 and the game is
## mostly paper -- a threshold low enough to catch the highlights catches the
## whole screen, and the picture turns to fog. Measured on the Lobby at
## 1080x1920 against the same baseline the AO pass used.
const LOBBY_SCENE := "res://Scenes/Lobby/loby.tscn"
const LOBBY_ENVIRONMENT := "res://Scenes/Lobby/lobby_environment.tres"


## The Lobby's WorldEnvironment (2026-09-23). An Environment reaches a 2D scene
## only with background_mode = BG_CANVAS: the 2D canvas becomes the background
## the environment post-processes. On the default mode it does nothing at all --
## measured: glow on the default background moved the frame by 0.00008, on
## Canvas by 0.040, and saturation 0 on Canvas turned it grey, in the game and in
## the 2D editor's viewport alike. That missing switch is why the first attempt
## was reverted as "inert".
func test_the_lobby_environment_applies_to_2d() -> void:
	var env: Environment = load(LOBBY_ENVIRONMENT)
	assert_true(env != null, "the Lobby environment resource must exist")
	if env == null:
		return
	assert_eq(env.background_mode, Environment.BG_CANVAS,
		"without Canvas background mode an Environment never touches a 2D scene")
	assert_true(env.glow_enabled, "the environment is there for its glow")
	assert_true(env.glow_hdr_threshold < 1.0,
		"hdr_2d is off, so nothing exceeds 1.0: a threshold at or above 1 blooms nothing")
	# Screen, not soft-light (2026-09-24): measured over the frozen Lobby,
	# soft-light at the same intensity moved 2.1% of the frame and read as no
	# bloom at all; screen moves 27.4%, which is visible at a glance.
	assert_eq(env.glow_blend_mode, Environment.GLOW_BLEND_MODE_SCREEN,
		"the Lobby's bloom must be visible, which soft-light at this intensity is not")
	assert_true(FileAccess.get_file_as_string(LOBBY_SCENE).contains(LOBBY_ENVIRONMENT),
		"the Lobby's WorldEnvironment must wear this resource")


## Turning hdr_2d on to reach the glow cost 41% of the Lobby's luminance
## (mean 0.509 -> 0.299: skin went orange, the room murky), and Canvas-mode glow
## does not need it.
func test_hdr_2d_stays_off() -> void:
	assert_false(bool(ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)),
		"hdr_2d darkens the whole game; the Canvas-mode glow works without it")


const BLOOM_THRESHOLD_FLOOR := 0.6


func test_the_bloom_threshold_stays_above_the_paper() -> void:
	var mat: ShaderMaterial = load("res://Scripts/Shaders/bloom_material.tres")
	assert_true(mat != null, "the bloom material must exist")
	if mat == null:
		return
	var threshold: float = mat.get_shader_parameter("threshold")
	assert_true(threshold >= BLOOM_THRESHOLD_FLOOR,
		"threshold %s blooms the paper itself, which reads as fog; floor is %s"
			% [threshold, BLOOM_THRESHOLD_FLOOR])


# ── The illustration grade ───────────────────────────────────────────────────

## One shader, four materials: the cutouts wear
## illustration_grade_cutout.tres, which adds AO and a rim (the Lobby's desks
## wear its upper-right-lit twin, and its faces a third), and the full-bleed
## backdrops wear the plain one. Both are the shared resources -- what this
## still forbids is a per-node copy, which would strand a plate the next time
## the grade is tuned. Which plate gets which is tested in illustration_ao.
func test_every_graded_node_shares_a_shared_material() -> void:
	var plain: Material = load(GRADE_MATERIAL)
	var cutout: Material = load("res://Scripts/Shaders/illustration_grade_cutout.tres")
	var face: Material = load("res://Scripts/Shaders/illustration_grade_face.tres")
	var lobby: Material = load(GRADE_LOBBY_CUTOUT_MATERIAL)
	assert_true(lobby is ShaderMaterial, "the Lobby cutout grade material must exist")
	assert_true(plain is ShaderMaterial, "the grade material must exist")
	assert_true(cutout is ShaderMaterial, "the cutout grade material must exist")
	assert_true(face is ShaderMaterial, "the face grade material must exist")
	for scene_path in GRADED:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in GRADED[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "%s is missing %s" % [scene_path, node_path])
			if node == null:
				continue
			assert_true(node.material == plain or node.material == cutout
					or node.material == face or node.material == lobby,
				"%s/%s must wear one of the four shared grades, not a copy"
					% [scene_path, node_path])


## The decision this whole pass rests on: grade the illustrations, not the
## interface, so design_tokens.tres stays the truth about the UI's colour. A
## grade on a Button, Label or themed Panel would break that.
func test_the_grade_never_lands_on_a_ui_node() -> void:
	var plain: Material = load(GRADE_MATERIAL)
	var cutout: Material = load("res://Scripts/Shaders/illustration_grade_cutout.tres")
	var lobby: Material = load(GRADE_LOBBY_CUTOUT_MATERIAL)
	var offenders := PackedStringArray()
	for scene_path in GRADED:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		_collect_ui_offenders(root, [plain, cutout, lobby], scene_path, offenders)
	assert_eq(offenders.size(), 0,
		"the grade is for painted art only; found it on UI: " + ", ".join(offenders))


func _collect_ui_offenders(node: Node, shared: Array, scene_path: String,
		offenders: PackedStringArray) -> void:
	var item := node as CanvasItem
	if item != null and item.material in shared:
		if item is Button or item is Label or item is RichTextLabel \
				or item is Panel or item is PanelContainer or item is NinePatchRect:
			offenders.append("%s/%s (%s)" % [scene_path, node.name, node.get_class()])
	for child in node.get_children():
		_collect_ui_offenders(child, shared, scene_path, offenders)


# ── The light-falloff primitive ──────────────────────────────────────────────

## Light must be additive. An alpha-blended overlay replaces the art's colour
## with its own wherever it is opaque, flattening exactly the detail a light
## is meant to reveal.
func test_the_light_is_additive() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Shaders/light_falloff.gdshader")
	assert_true(src.contains("render_mode blend_add"),
		"a light brightens what is behind it; it does not paint over it")


## The ceiling this game's palette imposes, measured rather than guessed.
##
## surface_page is #FBF1E3, so most of the screen is already near-white and
## additive light clips it to flat white fast. Sweeping the Lobby's window
## light over a frozen frame and counting pixels driven to pure white that
## were not already there: 0.16 pushed 20 sample points over, while 0.12 and
## below pushed one. The shipped value is 0.11, under the knee with a margin.
## Raise this only after re-running that sweep.
const LIGHT_INTENSITY_CEILING := 0.12


func test_the_window_light_stays_under_the_clipping_knee() -> void:
	var mat: ShaderMaterial = load("res://Scripts/Shaders/window_light_material.tres")
	assert_true(mat != null, "the window light material must exist")
	if mat == null:
		return
	var intensity: float = mat.get_shader_parameter("intensity")
	assert_true(intensity <= LIGHT_INTENSITY_CEILING,
		"intensity %s blows the cream palette out to flat white; measured knee is %s"
			% [intensity, LIGHT_INTENSITY_CEILING])

	# And it must actually be placed, or the primitive is unused code.
	var lobby := (load("res://Scenes/Lobby/loby.tscn") as PackedScene).instantiate()
	track(lobby)
	var light := lobby.get_node_or_null("Classroom/WindowLight") as Control
	assert_true(light != null, "the Lobby should carry the window light")
	if light == null:
		return
	assert_eq(light.material, mat, "the light must use the shared material")
	assert_eq(light.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"a light must never eat a tap")


## The grade must hand alpha back untouched. Every plate it lands on is a
## cutout -- the desks, the faces, the shopkeeper -- and a grade that multiplied
## alpha would eat the soft edges the art is drawn with.
func test_the_grade_leaves_alpha_alone() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Shaders/illustration_grade.gdshader")
	assert_true(src.contains("src.a"),
		"the shader must pass the source alpha straight through")
	assert_false(src.contains("COLOR.a *") or src.contains("a * a"),
		"nothing may scale alpha, or cutout edges get eaten")
## The ceilings on the grade's strength, halved on 2026-09-22 and again on
## 2026-09-23.
##
## The grade shipped at saturation 1.07 / contrast 1.045 and read too dark once
## it covered the minigames as well -- contrast about mid-grey pushes the
## shadowed half of every plate down, and a minigame is mostly one big plate.
## Both were cut to half their distance from neutral, then halved again on the
## same call, leaving a quarter of the original grade. These ceilings hold that
## line: a grade is meant to be felt, not seen, and characters are graded
## separately from the backgrounds they stand in front of, so a strong grade
## pulls them out of their own scene. Judge any raise on a full-size capture.
const GRADE_SATURATION_CEILING := 1.02
const GRADE_CONTRAST_CEILING := 1.0125


func test_the_grade_stays_subtle() -> void:
	# All three materials: plain, cutout and face share the same
	# five colour uniforms (test_illustration_ao.gd's
	# test_the_two_materials_agree_on_the_shared_grade pins that they must),
	# so the cutout material could otherwise be pushed past these ceilings
	# unnoticed while this test kept watching only the plain one.
	for path in [GRADE_MATERIAL, GRADE_CUTOUT_MATERIAL, GRADE_LOBBY_CUTOUT_MATERIAL,
			GRADE_FACE_MATERIAL]:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		var saturation: float = mat.get_shader_parameter("saturation")
		var contrast: float = mat.get_shader_parameter("contrast")
		assert_true(saturation <= GRADE_SATURATION_CEILING,
			"%s: saturation %s is louder than the agreed ceiling %s"
				% [path, saturation, GRADE_SATURATION_CEILING])
		assert_true(contrast <= GRADE_CONTRAST_CEILING,
			"%s: contrast %s darkens the plates past the agreed ceiling %s"
				% [path, contrast, GRADE_CONTRAST_CEILING])
