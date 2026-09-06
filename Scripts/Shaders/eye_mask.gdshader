shader_type canvas_item;

// Clips a moving eye layer to the shape of another one, so a gaze offset can
// never paint the iris onto the cheek, the eyelid or the hair.
//
// StudentFace.gd assigns this to the Pupil layer with the Sclera texture as
// the mask, and rewrites mask_uv_offset/mask_uv_scale every time the pupil
// moves. Both uniforms are ratios of the rig's own canvas rects, so the clip
// is resolution independent -- it follows the sprite at any roster-slot size
// and through the lobby's breathing scale.

// The layer whose alpha channel defines where this one may draw.
uniform sampler2D mask_texture : filter_linear, repeat_disable;
// Mask UV of this layer's top-left corner: (pupil_pos - mask_pos) / mask_size.
uniform vec2 mask_uv_offset = vec2(0.0, 0.0);
// This layer's size as a fraction of the mask's: pupil_size / mask_size.
uniform vec2 mask_uv_scale = vec2(1.0, 1.0);
// Width of the alpha ramp at the mask's edge. 0.0 is a hard, aliased cut.
uniform float mask_softness : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec2 mask_uv = mask_uv_offset + UV * mask_uv_scale;
	// Outside the mask rect there is no mask art at all, so clamped sampling
	// would smear its edge pixels outward. Score those samples as empty.
	float inside = step(0.0, mask_uv.x) * step(mask_uv.x, 1.0)
		* step(0.0, mask_uv.y) * step(mask_uv.y, 1.0);
	float coverage = texture(mask_texture, clamp(mask_uv, vec2(0.0), vec2(1.0))).a * inside;
	COLOR.a *= smoothstep(0.5 - mask_softness, 0.5 + mask_softness, coverage);
}
