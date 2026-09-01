// Soft drop-shadow for a sprite: a small separable-ish gaussian applied in a
// single pass (9 offset taps) that blurs only the alpha silhouette, so the
// node's own `self_modulate` (a translucent black) stays flat while the edge
// goes soft. Used by DayStickyNote.tscn's Shadow node behind each sticky
// note. `blur` is in source texels; keep it small (2-4) -- this is chrome,
// not a bloom pass.
shader_type canvas_item;

uniform float blur : hint_range(0.0, 8.0) = 2.5;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	float a = 0.0;
	a += texture(TEXTURE, UV + vec2(-px.x, -px.y)).a * 0.0625;
	a += texture(TEXTURE, UV + vec2( 0.0,  -px.y)).a * 0.125;
	a += texture(TEXTURE, UV + vec2( px.x, -px.y)).a * 0.0625;
	a += texture(TEXTURE, UV + vec2(-px.x,  0.0 )).a * 0.125;
	a += texture(TEXTURE, UV                     ).a * 0.25;
	a += texture(TEXTURE, UV + vec2( px.x,  0.0 )).a * 0.125;
	a += texture(TEXTURE, UV + vec2(-px.x,  px.y)).a * 0.0625;
	a += texture(TEXTURE, UV + vec2( 0.0,   px.y)).a * 0.125;
	a += texture(TEXTURE, UV + vec2( px.x,  px.y)).a * 0.0625;
	COLOR = vec4(COLOR.rgb, COLOR.a * a);
}
