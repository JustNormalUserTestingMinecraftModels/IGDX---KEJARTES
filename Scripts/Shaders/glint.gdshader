shader_type canvas_item;

// A glint: a diagonal band of light sweeping across a texture every
// `interval` seconds, like the shine running over a trophy (ambient kit,
// 2026-09-26). It recolours the texture's own pixels and keeps their alpha,
// so nothing is drawn outside the art. Every glinting node shares
// glint_material.tres; LookLayer sets `motion` on it, once, from Efek
// Suasana and Kurangi Gerakan -- 0 parks the band off the art.

// Colour of the shine. Its alpha scales it further.
uniform vec4 glint_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
// How far the band pulls a pixel toward glint_color at its centre.
uniform float strength : hint_range(0.0, 1.0) = 0.55;
// Seconds from one sweep's start to the next.
uniform float interval : hint_range(1.0, 20.0) = 5.0;
// Seconds one sweep takes to cross the art.
uniform float sweep_seconds : hint_range(0.1, 3.0) = 0.8;
// Half-width of the band, in UV.
uniform float band_width : hint_range(0.02, 0.5) = 0.12;
// Direction the band travels, in radians from the +x axis; 0.6 runs
// down-right on a diagonal.
uniform float angle : hint_range(-3.2, 3.2) = 0.6;
// 1 = sweeping, 0 = parked (set by LookLayer).
uniform float motion : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float t = mod(TIME, interval) / sweep_seconds;
	vec2 dir = vec2(cos(angle), sin(angle));
	float along = dot(UV - vec2(0.5), dir) + 0.5;
	float centre = mix(-band_width - 0.25, 1.25 + band_width, clamp(t, 0.0, 1.0));
	float band = 1.0 - smoothstep(0.0, band_width, abs(along - centre));
	band *= step(t, 1.0) * motion;
	COLOR.rgb = mix(COLOR.rgb, glint_color.rgb, band * strength * glint_color.a);
}
