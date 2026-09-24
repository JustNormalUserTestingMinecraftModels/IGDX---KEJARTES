@tool
extends TextureRect

## Soft contact shadow for a textured element, as a reusable template
## (Scenes/UI/PaperShadow.tscn).
##
## The shape is two nodes for a reason documented at length in
## tests/test_paper_shadow.gd: an instance under a non-container Control is
## saved with `layout_mode = 0`, and loading that resets the instance ROOT's
## rect to zero size. So the root is a bare anchor on its parent's top-left
## corner, and the visible shadow is its child, Silhouette, whose rect no
## override touches.
##
## That same rule is why every knob here lives on the ROOT. Properties set on
## an instanced scene's children report success and are dropped on save
## (CLAUDE.md 4b), so an instance could never re-texture Silhouette directly --
## which is exactly why this template was hardcoded to StudentCard's
## 1080x1920 card_bg.png for its first thirteen uses. The @exports below are
## serialised on the instance root and written through to Silhouette here.
##
## Every default reproduces the original baked values exactly, so the thirteen
## pre-existing instances and both suites that pin them stay green without
## being touched.
##
## Must be @tool so a placed shadow previews in the editor viewport. It has no
## side effects beyond laying out its own child, so nothing here is gated
## behind Engine.is_editor_hint().

## Silhouette path relative to this node.
const SILHOUETTE_PATH := ^"Silhouette"

## The shared soft-shadow material. Duplicated per instance only when `blur`
## differs from the value baked into it, so the common case keeps sharing one
## resource rather than spawning fourteen copies.
const SHARED_MATERIAL := preload("res://Scripts/Shaders/soft_shadow_material.tres")

## The blur baked into SHARED_MATERIAL. Kept as a constant so the duplicate
## check does not have to read the resource before deciding.
const SHARED_BLUR := 2.5

@export_group("Silhouette")
## The alpha silhouette to cast. Defaults to StudentCard's paper, which is
## what every instance predating this script uses. Point it at the parent's
## own texture when dropping a shadow under some other element.
@export var shadow_texture: Texture2D = preload("res://Assets/Images/StudentCard/card_bg.png"):
	set(value):
		shadow_texture = value
		_apply()

## Size of the silhouette in pixels, before `shadow_scale`. This is the
## parent element's own size: the shadow is its parent's shape, offset and
## grown slightly, not a blob under it.
@export var shadow_size: Vector2 = Vector2(1080, 1920):
	set(value):
		shadow_size = value
		_apply()

## How far the shadow sits down and to the right of its parent, in pixels.
## The light in this game comes from the upper left, so both stay positive.
@export var shadow_offset: Vector2 = Vector2(14, 18):
	set(value):
		shadow_offset = value
		_apply()

## Uniform scale on the silhouette. A few percent over 1.0 reads as the
## shadow spreading as it falls away from the surface.
@export_range(1.0, 1.2, 0.001) var shadow_scale: float = 1.03:
	set(value):
		shadow_scale = value
		_apply()

## Opacity of the shadow. This is chrome: past roughly 0.4 it stops reading
## as a shadow and starts reading as a second, darker copy of the element.
@export_range(0.0, 1.0, 0.01) var shadow_alpha: float = 0.33:
	set(value):
		shadow_alpha = value
		_apply()

## Take the silhouette's size from the parent every time the parent resizes,
## instead of from `shadow_size`.
##
## Needed whenever the parent is not a fixed-size piece: a Full Rect element
## is 1080x1920 on a 9:16 phone and 1080x2400 on a 20:9 one, and a container
## child is whatever the container gives it. Anchors cannot do this job here,
## because loading an instance resets THIS node's own rect to zero size (see
## the header), so Silhouette's anchors would resolve against nothing.
##
## Off by default so the thirteen instances that predate this script keep
## their authored `shadow_size`.
@export var follow_parent_rect: bool = false:
	set(value):
		follow_parent_rect = value
		_apply()

## How the silhouette fills its rect. Must match the parent's own
## `stretch_mode`, or the two diverge the moment the rect stops matching the
## texture's aspect: a Keep Aspect Covered parent crops while a Scale shadow
## squashes, and the shadow slides out from under its element.
@export var shadow_stretch_mode: TextureRect.StretchMode = TextureRect.STRETCH_SCALE:
	set(value):
		shadow_stretch_mode = value
		_apply()

## Blur radius in SOURCE TEXELS, passed to soft_shadow.gdshader. Its own
## header warns to keep this between 2 and 4 -- "this is chrome, not a bloom
## pass". A small texture needs a smaller number than a 1080px one to look
## the same, because the unit is texels of the source, not screen pixels.
@export_range(0.0, 8.0, 0.1) var blur: float = SHARED_BLUR:
	set(value):
		blur = value
		_apply()


func _ready() -> void:
	var parent := get_parent() as Control
	if parent != null and not parent.resized.is_connected(_apply):
		parent.resized.connect(_apply)
	_apply()


## Writes every knob through to Silhouette. Safe to call before the node is in
## the tree and safe to call repeatedly; the setters above use it so a value
## typed in the inspector previews at once.
func _apply() -> void:
	var sil := get_node_or_null(SILHOUETTE_PATH) as TextureRect
	if sil == null:
		return
	var span := shadow_size
	if follow_parent_rect:
		var parent := get_parent() as Control
		if parent != null and parent.size.x > 0.0 and parent.size.y > 0.0:
			span = parent.size
	sil.texture = shadow_texture
	sil.stretch_mode = shadow_stretch_mode
	sil.offset_left = shadow_offset.x
	sil.offset_top = shadow_offset.y
	sil.offset_right = shadow_offset.x + span.x
	sil.offset_bottom = shadow_offset.y + span.y
	sil.scale = Vector2(shadow_scale, shadow_scale)
	sil.self_modulate = Color(0.0, 0.0, 0.0, shadow_alpha)
	_apply_blur(sil)


## Gives Silhouette the shared material, or its own copy when this instance
## wants a different blur. Duplicating matters: the material is one resource
## shared by every instance, so writing a shader parameter straight onto it
## would re-blur all of them.
func _apply_blur(sil: TextureRect) -> void:
	if is_equal_approx(blur, SHARED_BLUR):
		sil.material = SHARED_MATERIAL
		return
	var mat := sil.material as ShaderMaterial
	if mat == null or mat == SHARED_MATERIAL:
		mat = SHARED_MATERIAL.duplicate() as ShaderMaterial
		sil.material = mat
	mat.set_shader_parameter("blur", blur)


## Sizes and textures this shadow from `source`, the element it falls under.
## The common case for a new shadow: instance the template as the element's
## first child, then call this. Returns false when `source` has no texture to
## take a silhouette from.
func match_source(source: TextureRect) -> bool:
	if source == null or source.texture == null:
		return false
	shadow_texture = source.texture
	shadow_size = source.size
	shadow_stretch_mode = source.stretch_mode
	return true
