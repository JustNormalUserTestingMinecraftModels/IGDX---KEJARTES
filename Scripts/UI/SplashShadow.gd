@tool
class_name SplashShadow
extends TextureRect

## The soft ambient-occlusion shade behind a speaker's splash art
## (soft_ao_shadow.gdshader): the splash's own silhouette, blurred through its
## mipmaps and painted in one warm dark colour, darkest at the figure and
## fading wide, with no offset and no hard edge.
##
## Place it as the splash TextureRect's first child: it is Full Rect and draws
## behind its parent (show_behind_parent), sharing the parent's stretch mode so
## the shade lines up with the art. The scene sets texture_filter to
## LINEAR_WITH_MIPMAPS, which the shader's mip reads need.
##
## The screen that changes the splash calls follow(splash) right after, so the
## shade always matches whoever is speaking. (The PaperShadow it replaced kept
## the texture it was authored with, so a student spoke in front of Mom's
## silhouette.)


## Takes `source`'s texture and stretch mode, so the shade matches the art
## the source shows now.
func follow(source: TextureRect) -> void:
	texture = source.texture
	stretch_mode = source.stretch_mode
