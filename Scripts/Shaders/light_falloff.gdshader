shader_type canvas_item;
render_mode blend_add;

// A soft pool of light. The plain falloff that achievement_glow.gdshader
// wraps in rotating shafts and flicker, pulled out on its own so a scene can
// put light somewhere without asking for a starburst.
//
// WHY ADDITIVE. blend_add only ever brightens what is behind it, which is
// what light does. An alpha-blended overlay would instead replace the art's
// colour with its own wherever it is opaque, flattening exactly the detail a
// light is supposed to reveal.
//
// THE CREAM PROBLEM. This game's palette is mostly near-white -- surface_page
// is #FBF1E3 -- and additive light on a near-white surface clips to flat
// white almost immediately, which reads as a blown-out patch rather than as
// illumination. So `intensity` wants to be small here, far smaller than it
// would on a dark game. Judge it on a full-size capture over the lightest
// surface in the scene, not the darkest.
//
// `radius` is in UV, where 0.5 reaches the edge of the node's own rect, and
// `aspect` keeps the pool round on a rect that is not square -- or lets it be
// deliberately elliptical, which is what a window casts onto a floor.

// Colour of the light. Warm by default, to sit in the paper-diorama palette.
uniform vec4 light_color : source_color = vec4(1.0, 0.898, 0.706, 1.0);
// Peak brightness at the centre. Keep it low over cream; see the header.
uniform float intensity : hint_range(0.0, 1.0) = 0.11;
// Distance from the centre at which the light has fallen to nothing, in UV.
uniform float radius : hint_range(0.05, 1.5) = 0.55;
// Falloff curve. 1 is linear, 2 is gaussian-ish, higher is a tighter core.
uniform float falloff : hint_range(0.5, 6.0) = 2.4;
// Horizontal stretch of the pool. Above 1 makes it wider than it is tall.
uniform float aspect : hint_range(0.1, 6.0) = 1.0;
// Very slow breathing, so a static room does not look frozen. 0 disables it.
uniform float breathe_amount : hint_range(0.0, 0.5) = 0.06;
uniform float breathe_speed : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x /= max(aspect, 0.001);
	float dist = length(p) / max(radius, 0.001);

	// 1 at the centre, 0 at the radius, with no hard edge anywhere.
	float pool = pow(clamp(1.0 - dist, 0.0, 1.0), max(falloff, 0.001));
	float breathe = 1.0 + breathe_amount * sin(TIME * breathe_speed * TAU);

	// COLOR carries the node's modulate, so a scene can fade the light in and
	// out with a tween without touching the shared material.
	COLOR = vec4(light_color.rgb, pool * intensity * breathe * light_color.a * COLOR.a);
}
