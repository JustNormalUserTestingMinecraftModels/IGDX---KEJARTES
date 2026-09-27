shader_type canvas_item;
render_mode blend_add;

// The light behind a claimed achievement's icon: a pulsing soft core and two
// layers of light shafts rotating in opposite directions, each shaft
// flickering on its own noise. Additive, so it only ever brightens what lies
// behind it. Drawn on a square ColorRect centred on the icon.

uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int ray_count = 14;
uniform float rotate_speed = 0.18;
uniform float flicker_speed = 1.4;
uniform float core_size : hint_range(0.05, 1.0) = 0.42;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

float rays(vec2 p, float dist, float turn, float count, float sharpness) {
	float sector = (atan(p.y, p.x) + turn) / TAU * count;
	float across = abs(fract(sector) - 0.5) * 2.0;
	float flicker = 0.5 + 0.5 * noise1(TIME * flicker_speed + floor(sector) * 7.13);
	return pow(1.0 - across, sharpness) * flicker * smoothstep(1.0, 0.2, dist);
}

void fragment() {
	vec2 p = UV - 0.5;
	float dist = length(p) * 2.0;
	float count = float(ray_count);
	float shafts = rays(p, dist, TIME * rotate_speed, count, 5.0)
		+ 0.6 * rays(p, dist, -TIME * rotate_speed * 0.6, count * 0.5, 9.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.2);
	float core = exp(-pow(dist / core_size, 2.0)) * pulse;
	float a = clamp(shafts * 0.5 + core, 0.0, 1.0) * intensity * glow_color.a;
	COLOR = vec4(glow_color.rgb, a) * vec4(1.0, 1.0, 1.0, v_modulate.a);
}
