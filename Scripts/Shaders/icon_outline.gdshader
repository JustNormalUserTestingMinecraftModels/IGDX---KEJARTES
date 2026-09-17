shader_type canvas_item;

// Draws a texture shrunk inside its rect by `outline_width` (a share of the
// rect), with a solid `outline_color` ring that follows the art's alpha --
// so rounded icon corners get a rounded outline. Used by
// icon_outline_material.tres on every achievement icon.

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.2) = 0.03;

const int DIRECTIONS = 16;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	float shrink = 1.0 - 2.0 * outline_width;
	vec2 uv = (UV - 0.5) / shrink + 0.5;
	vec4 art = vec4(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		art = texture(TEXTURE, uv);
	}
	float reach = outline_width / shrink;
	float ring = 0.0;
	for (int i = 0; i < DIRECTIONS; i++) {
		float a = TAU * float(i) / float(DIRECTIONS);
		vec2 dir = vec2(cos(a), sin(a));
		ring = max(ring, alpha_at(TEXTURE, uv + dir * reach));
		ring = max(ring, alpha_at(TEXTURE, uv + dir * reach * 0.5));
	}
	vec3 rgb = mix(outline_color.rgb, art.rgb, art.a);
	float alpha = max(art.a, ring * outline_color.a);
	COLOR = vec4(rgb, alpha) * v_modulate;
}
