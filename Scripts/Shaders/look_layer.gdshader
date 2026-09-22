// Global look layer: a vignette and a film grain drawn over the whole game
// by the LookLayer autoload (Scenes/Look/LookLayer.tscn, CanvasLayer 90).
//
// It is drawn PROCEDURALLY on a Full Rect ColorRect rather than as a texture,
// and that is a hard requirement, not a preference. The project runs with
// window/stretch/aspect="expand", so the viewport is 1080x1920 on a 9:16
// phone and 1080x2400 on a 20:9 one. A 1080x1920 vignette PNG under Keep
// Aspect Covered would crop its own left and right falloff off the sides of
// a tall screen -- the exact failure docs/superpowers/design/authoring-guide's
// "Tall phones" section warns about. A shader has no fixed resolution, so it
// simply fills whatever it is given.
//
// `viewport_size` is fed by LookLayer.gd on every size change and is used
// only to keep the vignette circular: without it the falloff is an ellipse
// stretched to the screen's aspect, which reads as a smear rather than a lens.
//
// The grain is the expensive half -- a hash evaluated per pixel per frame --
// and is why the whole layer sits behind an opt-in setting.
shader_type canvas_item;

// How dark the corners get, 0 = no vignette.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.34;
// Radius at which the falloff reaches full strength, in half-screen-heights.
uniform float vignette_radius : hint_range(0.2, 2.0) = 0.92;
// Width of the falloff band. Small values give a hard iris, large a soft one.
uniform float vignette_softness : hint_range(0.05, 1.5) = 0.62;
// The corner colour. Warm brown rather than black, to sit in the game's
// cream/brown palette instead of punching a grey hole in it.
uniform vec4 vignette_color : source_color = vec4(0.129, 0.078, 0.035, 1.0);

// Peak grain deviation. Above ~0.06 it stops reading as film and starts
// reading as a broken screen.
uniform float grain_amount : hint_range(0.0, 0.2) = 0.022;
// Grain refreshes per second. Quantised, so the noise holds for a whole
// frame instead of shimmering at the refresh rate.
uniform float grain_rate : hint_range(0.0, 60.0) = 14.0;

// Viewport size in pixels, pushed from LookLayer.gd.
uniform vec2 viewport_size = vec2(1080.0, 1920.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	// Aspect-correct so the vignette stays circular on any phone.
	vec2 centred = UV - vec2(0.5);
	centred.x *= max(viewport_size.x, 1.0) / max(viewport_size.y, 1.0);
	float dist = length(centred) / max(vignette_radius, 0.001);
	float vig = smoothstep(1.0 - vignette_softness, 1.0, dist) * vignette_strength;

	// Grain as its own black-or-white contribution, so it can lighten as well
	// as darken. An overlay that only ever darkened would read as dirt.
	float grain_a = 0.0;
	vec3 grain_rgb = vec3(0.0);
	if (grain_amount > 0.0) {
		vec2 seed = UV * viewport_size + vec2(floor(TIME * grain_rate));
		float n = hash21(seed) - 0.5;
		grain_rgb = n > 0.0 ? vec3(1.0) : vec3(0.0);
		grain_a = abs(n) * 2.0 * grain_amount;
	}

	float total = vig + grain_a;
	// Blend the two contributions by their share of the total alpha, so
	// neither washes the other out where they overlap in the corners.
	vec3 rgb = total > 0.0001
		? mix(grain_rgb, vignette_color.rgb, vig / total)
		: vignette_color.rgb;
	COLOR = vec4(rgb, clamp(total, 0.0, 1.0));
}
