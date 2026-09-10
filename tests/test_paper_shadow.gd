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


func test_the_static_stack_shadow_is_gone() -> void:
	for scene_path in _SCENES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		assert_true(root.get_node_or_null("Shadow") == null,
			"%s still has the root-level Shadow, which stays on the desk when a paper flies" % scene_path)
