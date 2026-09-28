shader_type canvas_item;
render_mode blend_add;

// Screen-space bloom for the look layer: the bright parts of the finished frame,
// blurred and added back over it.
//
// WHY THIS IS A 2D SHADER AND NOT (ONLY) A WorldEnvironment. This header used to
// say an Environment never runs in this game. That was wrong: a WorldEnvironment
// does apply to 2D, but only with background_mode = BG_CANVAS, and the
// 2026-09-23 experiment left it on the default, which is why every glow and
// tonemapper setting it tried produced the same frame. The Lobby now carries a
// Canvas-mode WorldEnvironment (Scenes/Lobby/lobby_environment.tres), because
// it previews in the 2D editor. This shader stays because it runs on every
// screen and turns off with the Efek Visual setting; the Lobby gets both, so
// tune them together. hdr_2d stays off either way: turning it on cost 41% of
// the frame's luminance.
//
// WHY ADDITIVE. blend_add only brightens what is behind it, which is what light
// does; an alpha-blended overlay would replace the art wherever it is opaque.
// Same reasoning as light_falloff.gdshader and light_shafts.gdshader.
//
// THE BLUR IS FREE, THE READ IS NOT. Three mip levels of the screen texture,
// averaged, stand in for a wide gaussian without a second pass -- the same
// trick blur.gdshader already uses for the pause-menu backdrop. What costs is
// the screen read itself, once per frame. That is why this lives inside the
// look layer, which removes itself from the draw list entirely when its
// setting is off, so an unchecked box costs nothing rather than costing a
// full-screen texture fetch.
//
// THE CREAM PROBLEM, AGAIN -- but threshold, not intensity, is the knob that
// matters. surface_page is #FBF1E3 and this game is mostly paper, so the
// highlights sit low: swept over the Lobby with the layer on,
//
//   no bloom      mean 0.508012  blown 1462
//   0.80 / 0.30   mean 0.509658  blown 1552
//   0.70 / 0.15   mean 0.512625  blown 1625
//   0.70 / 0.30   mean 0.516051  blown 1629
//
// at threshold 0.88 the effect all but vanishes, because almost nothing in the
// frame is that bright. It ships at 0.70 / 0.30, chosen from four real frames:
// the sunlit floor and the paper glow, and it reads as light rather than fog.
// Judge any change the same way, on a capture, not on the numbers alone.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// Brightness a pixel must already have before it blooms at all. Low values
// bloom the paper itself, which reads as fog rather than light.
uniform float threshold : hint_range(0.0, 1.0) = 0.70;
// How much of the bloom is added back. 0 disables it, and the shader still
// costs its screen read, so the layer hides the node instead.
uniform float intensity : hint_range(0.0, 2.0) = 0.30;
// Which mip to start the blur at. Higher is wider and softer, and costs the
// same -- the mips already exist.
uniform float spread : hint_range(0.0, 5.0) = 2.0;
// Colour the bloom is pushed toward. Warm, to sit in the paper-diorama palette
// rather than reading as a blue-white bulb.
uniform vec4 bloom_tint : source_color = vec4(1.0, 0.96, 0.88, 1.0);

void fragment() {
	// Three mips averaged: a wide, cheap blur with no second pass.
	vec3 blurred = (
		textureLod(screen_texture, SCREEN_UV, spread).rgb
		+ textureLod(screen_texture, SCREEN_UV, spread + 1.0).rgb
		+ textureLod(screen_texture, SCREEN_UV, spread + 2.0).rgb) / 3.0;

	// Only what is already bright blooms, renormalised so the threshold sets
	// where bloom starts without also scaling how strong it gets.
	vec3 bright = max(blurred - vec3(threshold), vec3(0.0)) / max(1.0 - threshold, 0.001);

	COLOR = vec4(bright * bloom_tint.rgb * intensity, 1.0);
}
