@tool
extends McpTestSuite

## Paper shadows ride their paper. StudentCard and ReportCard used to draw one
## static Shadow behind the whole six-paper stack, so a paper thrown
## off-screen by _transition_page() left its shadow behind on the desk. Every
## paper now carries a PaperShadow.tscn instance as its first child, with
## show_behind_parent: it inherits the paper's position, tilt and fade, and
## draws underneath it. See docs/superpowers/specs/
## 2026-09-10-minigame-sky-and-paper-fixes-design.md §5.
##
## Why the template is two nodes. An instance under a non-container Control
## is saved with a `layout_mode = 0` override, and loading that resets the
## instance root's rect to the parent's top-left corner from a size cache
## that is still zero before the node enters the tree -- a shadow drawn by
## the root itself came back zero-size (found 2026-09-10). So the root is only
## a bare anchor on the paper's corner, where that reset puts it anyway, and
## the shadow is its child, Silhouette, whose rect no override touches.
##
## Scene instantiation only -- nothing enters the tree, so no script in
## either screen runs (StatBar.gd on the papers' bars is @tool).
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "paper_shadow"

const _TEMPLATE := "res://Scenes/UI/PaperShadow.tscn"
const _SCENES: Array[String] = [
	"res://Scenes/StudentCard/student_card.tscn",
	"res://Scenes/ReportCard/report_card.tscn",
]
const _PAPERS: Array[String] = [
	"KertasMurid1", "KertasMurid2", "KertasMurid3",
	"KertasMurid4", "KertasMurid5", "KertasMurid6",
]
## The Silhouette's rect inside the template, as offsets (left, top, right,
## bottom): 1080x1920, shifted +14/+18 -- the old static Shadow's placement.
const _RECT := Vector4(14, 18, 1094, 1938)


func _silhouette(shadow: Node) -> TextureRect:
	return shadow.get_node_or_null("Silhouette") as TextureRect


func test_the_template_is_a_soft_translucent_shadow_drawn_behind_its_parent() -> void:
	assert_true(ResourceLoader.exists(_TEMPLATE), "PaperShadow.tscn is missing")
	if not ResourceLoader.exists(_TEMPLATE):
		return
	var shadow := (load(_TEMPLATE) as PackedScene).instantiate() as Control
	track(shadow)
	assert_true(shadow != null, "PaperShadow.tscn's root must be a Control")
	if shadow == null:
		return
	assert_true(shadow.show_behind_parent, "the shadow must draw under its paper, not over it")
	assert_eq(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a shadow must never eat a tap")
	assert_eq(Vector4(shadow.offset_left, shadow.offset_top, shadow.offset_right, shadow.offset_bottom),
		Vector4.ZERO, "the root is a bare anchor on its paper's top-left corner")
	var sil := _silhouette(shadow)
	assert_true(sil != null, "the template needs its Silhouette TextureRect")
	if sil == null:
		return
	assert_true(sil.material is ShaderMaterial, "the Silhouette needs the soft_shadow ShaderMaterial")
	assert_true(sil.self_modulate.a < 1.0, "the Silhouette must be a translucent tint, not opaque")
	assert_eq(sil.texture.resource_path if sil.texture else "",
		"res://Assets/Images/StudentCard/card_bg.png", "the shadow is the paper's own silhouette")
	assert_eq(sil.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a shadow must never eat a tap")
	assert_eq(Vector4(sil.anchor_left, sil.anchor_top, sil.anchor_right, sil.anchor_bottom),
		Vector4.ZERO, "the Silhouette's rect must not lean on anchors")
	assert_eq(Vector4(sil.offset_left, sil.offset_top, sil.offset_right, sil.offset_bottom),
		_RECT, "the Silhouette is a 1080x1920 rect offset +14/+18 from its paper")
	assert_true(sil.scale.is_equal_approx(Vector2(1.03, 1.03)), "the shadow is 3% larger than its paper")


func test_every_paper_carries_its_own_shadow() -> void:
	for scene_path in _SCENES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for paper_name in _PAPERS:
			var paper := root.get_node_or_null(paper_name) as Control
			assert_true(paper != null, "%s is missing %s" % [scene_path, paper_name])
			if paper == null:
				continue
			var shadow := paper.get_node_or_null("PaperShadow") as Control
			assert_true(shadow != null, "%s/%s has no PaperShadow child" % [scene_path, paper_name])
			if shadow == null:
				continue
			assert_eq(shadow.scene_file_path, _TEMPLATE,
				"%s/%s's shadow must be the shared template, not a copy" % [scene_path, paper_name])
			assert_eq(shadow.get_index(), 0,
				"%s/%s's shadow should be its first child" % [scene_path, paper_name])
			assert_true(shadow.show_behind_parent,
				"%s/%s's shadow must draw behind its paper" % [scene_path, paper_name])
			# After loading -- and the layout_mode reset that comes with it --
			# the anchor must sit on the paper's corner, and the Silhouette must
			# still be exactly its paper's size, shifted +14/+18.
			var corner := Vector2(shadow.offset_left, shadow.offset_top)
			assert_eq(corner, Vector2.ZERO,
				"%s/%s's shadow anchor must sit on its paper's corner, got %s"
					% [scene_path, paper_name, corner])
			var sil := _silhouette(shadow)
			assert_true(sil != null, "%s/%s's shadow has no Silhouette" % [scene_path, paper_name])
			if sil == null:
				continue
			var rect := Vector4(sil.offset_left, sil.offset_top, sil.offset_right, sil.offset_bottom)
			assert_eq(rect, _RECT,
				"%s/%s's Silhouette lost its +14/+18 placement after loading, got %s"
					% [scene_path, paper_name, rect])
			var paper_size := Vector2(paper.offset_right - paper.offset_left,
				paper.offset_bottom - paper.offset_top)
			assert_eq(Vector2(rect.z - rect.x, rect.w - rect.y), paper_size,
				"%s/%s's Silhouette must be exactly its paper's size" % [scene_path, paper_name])


## --- Parameterisation (2026-09-22, premium-look PR 2) ---------------------
##
## The template grew @exports on its ROOT so it could be dropped on something
## other than StudentCard's paper. The knobs have to live on the root because
## properties set on an instanced scene's CHILDREN are dropped on save
## (CLAUDE.md 4b) -- which is why nobody re-textured this for thirteen
## instances. Defaults reproduce the original baked values exactly, which the
## template test above still pins.


## An instance is not in the tree here, so _ready() never runs -- the setters
## have to apply on their own, or every shadow placed in a .tscn would render
## with the template's defaults until something touched it.
func test_the_knobs_write_through_without_entering_the_tree() -> void:
	var shadow := (load(_TEMPLATE) as PackedScene).instantiate() as Control
	track(shadow)
	var sil := _silhouette(shadow)
	assert_true(sil != null, "no Silhouette")
	if sil == null:
		return
	var tex: Texture2D = load("res://Assets/Images/UI/papantulis.png")
	shadow.set("shadow_texture", tex)
	shadow.set("shadow_size", Vector2(400, 300))
	shadow.set("shadow_offset", Vector2(9, 11))
	shadow.set("shadow_alpha", 0.5)
	assert_eq(sil.texture, tex, "shadow_texture must reach the Silhouette")
	assert_eq(Vector4(sil.offset_left, sil.offset_top, sil.offset_right, sil.offset_bottom),
		Vector4(9, 11, 409, 311), "offset + size must become the Silhouette's rect")
	assert_true(is_equal_approx(sil.self_modulate.a, 0.5), "shadow_alpha must reach self_modulate")


## The soft-shadow material is ONE resource shared by every instance. Writing
## a shader parameter straight onto it would re-blur all thirteen papers and
## every shadow added later, from one instance's inspector.
func test_a_custom_blur_duplicates_the_material_instead_of_mutating_it() -> void:
	var shared: ShaderMaterial = load("res://Scripts/Shaders/soft_shadow_material.tres")
	var before: float = shared.get_shader_parameter("blur")

	var shadow := (load(_TEMPLATE) as PackedScene).instantiate() as Control
	track(shadow)
	shadow.set("blur", 6.0)
	var sil := _silhouette(shadow)
	assert_true(sil != null, "no Silhouette")
	if sil == null:
		return
	assert_true(sil.material != shared,
		"a custom blur must get its own material, not write onto the shared one")
	assert_true(is_equal_approx(sil.material.get_shader_parameter("blur"), 6.0),
		"the duplicate must carry the custom blur")
	assert_true(is_equal_approx(shared.get_shader_parameter("blur"), before),
		"the shared material must be untouched, or every other shadow re-blurs")

	# And the default keeps sharing, so this does not spawn a copy per instance.
	var plain := (load(_TEMPLATE) as PackedScene).instantiate() as Control
	track(plain)
	assert_eq(_silhouette(plain).material, shared,
		"the default blur must keep using the shared material")


## Where the contact shadows went. Each entry is a scene, the element that
## should cast, and whether it is a fixed-size piece or one that resizes with
## its container or the viewport.
const _CONTACT_SHADOWS := {
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
	"res://Scenes/Koperasi/koprasi.tscn": ["Stage/Herman"],
	"res://Scenes/AturJadwal/atur_jadwal.tscn": ["BGHari"],
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": ["Splash"],
}


func test_the_flat_elements_now_cast_a_shadow() -> void:
	for scene_path in _CONTACT_SHADOWS:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in _CONTACT_SHADOWS[scene_path]:
			var host := root.get_node_or_null(node_path) as TextureRect
			assert_true(host != null, "%s is missing %s" % [scene_path, node_path])
			if host == null:
				continue
			var shadow := host.get_node_or_null("Shadow") as Control
			assert_true(shadow != null,
				"%s/%s should cast a contact shadow" % [scene_path, node_path])
			if shadow == null:
				continue
			assert_eq(shadow.scene_file_path, _TEMPLATE,
				"%s/%s's shadow must be the shared template, not a hand-copy"
					% [scene_path, node_path])
			assert_true(shadow.show_behind_parent,
				"%s/%s's shadow must draw behind it" % [scene_path, node_path])
			# The shadow is its element's own silhouette, not a generic blob.
			assert_eq(shadow.get("shadow_texture"), host.texture,
				"%s/%s's shadow must use its element's own texture"
					% [scene_path, node_path])


## A Full Rect element is 1080x1920 on a 9:16 phone and 1080x2400 on a 20:9
## one, so its shadow cannot carry a baked size. Anchors cannot solve it
## either -- loading an instance resets the shadow ROOT's rect to zero, so the
## Silhouette's anchors would resolve against nothing. follow_parent_rect
## reads the parent's size instead.
func test_a_full_rect_element_gets_a_shadow_that_follows_its_size() -> void:
	var root := (load("res://Scenes/SchoolSimulation/EventDialogue.tscn") as PackedScene).instantiate()
	track(root)
	var splash := root.get_node_or_null("Splash") as TextureRect
	assert_true(splash != null, "Splash is gone")
	if splash == null:
		return
	assert_eq(Vector4(splash.anchor_left, splash.anchor_top, splash.anchor_right, splash.anchor_bottom),
		Vector4(0, 0, 1, 1), "Splash is Full Rect, which is what makes this necessary")
	var shadow := splash.get_node_or_null("Shadow") as Control
	assert_true(shadow != null, "Splash has no shadow")
	if shadow == null:
		return
	assert_true(shadow.get("follow_parent_rect"),
		"a Full Rect element's shadow must take its size from the parent")
	assert_eq(shadow.get("shadow_stretch_mode"), splash.stretch_mode,
		"the shadow must fill its rect the same way its element does, or the two "
			+ "diverge the moment the rect stops matching the texture's aspect")


func test_the_static_stack_shadow_is_gone() -> void:
	for scene_path in _SCENES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		assert_true(root.get_node_or_null("Shadow") == null,
			"%s still has the root-level Shadow, which stays on the desk when a paper flies" % scene_path)
