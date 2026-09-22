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
	"res://Scenes/Lobby/AndiFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/CitraFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/DoniFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/MarcelFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/ShintaFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/TheaFace.tscn": ["Canvas/Base"],
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


# ── The illustration grade ───────────────────────────────────────────────────

## One shared resource, so the whole game's look is tuned by editing one file.
func test_every_graded_node_shares_the_one_material() -> void:
	var shared: Material = load(GRADE_MATERIAL)
	assert_true(shared is ShaderMaterial, "the grade material must exist")
	for scene_path in GRADED:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in GRADED[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "%s is missing %s" % [scene_path, node_path])
			if node == null:
				continue
			assert_eq(node.material, shared,
				"%s/%s must wear the shared grade, not a copy"
					% [scene_path, node_path])


## The decision this whole pass rests on: grade the illustrations, not the
## interface, so design_tokens.tres stays the truth about the UI's colour. A
## grade on a Button, Label or themed Panel would break that.
func test_the_grade_never_lands_on_a_ui_node() -> void:
	var shared: Material = load(GRADE_MATERIAL)
	var offenders := PackedStringArray()
	for scene_path in GRADED:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		_collect_ui_offenders(root, shared, scene_path, offenders)
	assert_eq(offenders.size(), 0,
		"the grade is for painted art only; found it on UI: " + ", ".join(offenders))


func _collect_ui_offenders(node: Node, shared: Material, scene_path: String,
		offenders: PackedStringArray) -> void:
	var item := node as CanvasItem
	if item != null and item.material == shared:
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
