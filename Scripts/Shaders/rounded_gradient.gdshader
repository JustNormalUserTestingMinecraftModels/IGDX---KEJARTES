// A rounded rectangle filled with a diagonal two-colour gradient, inside a
// rim carrying a gradient of its own. AturJadwal's objective strip wears it
// in brown with a gold rim, and its star chip in gold (2026-09-24 visual
// polish, D8: "gradient brown ... with gold-gradient accents -- not flat
// single-brown").
//
// WHY A SHADER. A StyleBoxFlat is one flat colour; a StyleBoxTexture of a
// GradientTexture2D has no corner radius. This draws both, on any ColorRect,
// at any size.
//
// SIZE WITHOUT A UNIFORM. The rect's size in pixels is 1 / fwidth(UV): UV
// runs 0-1 across the rect, so one screen pixel covers fwidth(UV) of it. The
// radius and rim width are therefore in real pixels at whatever size the
// node is laid out to, with nothing for a script to keep in sync.
//
// The colours are written from DesignTokens by atur_jadwal.gd; the defaults
// here are only what the editor shows before that runs.
shader_type canvas_item;

// Gradient body, from the top-left corner...
uniform vec4 color_a : source_color = vec4(0.612, 0.392, 0.251, 1.0);
// ...to the bottom-right corner.
uniform vec4 color_b : source_color = vec4(0.337, 0.196, 0.106, 1.0);
// Rim gradient, top-left...
uniform vec4 rim_a : source_color = vec4(1.0, 0.788, 0.235, 1.0);
// ...to bottom-right.
uniform vec4 rim_b : source_color = vec4(0.75, 0.55, 0.15, 1.0);
// Rim width in pixels. 0 draws no rim.
uniform float rim_px : hint_range(0.0, 16.0) = 4.0;
// Corner radius in pixels, clamped to half the short side (a pill).
uniform float radius_px : hint_range(0.0, 999.0) = 999.0;

// Signed distance from a rounded box of half-size `b` and radius `r`.
float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px_per_uv = 1.0 / max(fwidth(UV), vec2(1e-6));
	vec2 half_size = px_per_uv * 0.5;
	vec2 p = (UV - vec2(0.5)) * px_per_uv;
	float r = min(radius_px, min(half_size.x, half_size.y));
	float d = rounded_box(p, half_size, r);

	// Diagonal: 0 at the top-left corner, 1 at the bottom-right.
	float t = clamp((UV.x + UV.y) * 0.5, 0.0, 1.0);
	vec4 body = mix(color_a, color_b, t);
	vec4 rim = mix(rim_a, rim_b, t);

	// Inside the rim band (-rim_px < d <= 0) wears the rim; deeper, the body.
	float in_body = 1.0 - smoothstep(-rim_px - 0.75, -rim_px + 0.75, d);
	vec4 col = mix(rim, body, rim_px > 0.0 ? in_body : 1.0);
	float coverage = 1.0 - smoothstep(-0.75, 0.75, d);
	COLOR = vec4(col.rgb, col.a * coverage) * COLOR;
}
