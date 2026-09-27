shader_type canvas_item;
render_mode blend_mul;

// MoodTint's wash (ambient kit, 2026-09-26). A multiply: the result is what
// was already drawn times this colour, so it can only darken and tint, and it
// reaches nothing drawn after it -- the UI above all. The colour is the
// ColorRect's own `color` (arriving here as COLOR), which MoodTint.gd sets
// from the mood and its strength; this shader only fades it toward white
// down the rect when `vertical_falloff` asks for a tint heavier at the top.

// 0 = even tint top to bottom; 1 = full at the top edge, none at the bottom.
uniform float vertical_falloff : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float weight = 1.0 - vertical_falloff * UV.y;
	COLOR = vec4(mix(vec3(1.0), COLOR.rgb, weight), 1.0);
}
