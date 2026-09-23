// The illustration colour grade: one shared look applied to the painted art
// and to nothing else.
//
// WHY THIS IS NOT A FULL-SCREEN PASS. The UI and the illustrations both sit
// on the default CanvasLayer 0 on every screen in this game, so there is no
// layer to grade between them. A screen-space pass would tint the buttons,
// the cards and the text along with the art -- and the whole point of grading
// the illustrations rather than the interface is that the design tokens stay
// the honest description of the UI's colour. So the grade is a material
// assigned per node, to the painted plates only.
//
// It is also cheaper than a screen pass: no backbuffer copy, no full-screen
// fill, just a handful of instructions on the pixels the art already covers.
//
// ONE SHARED MATERIAL. Every graded node points at
// Scripts/Shaders/illustration_grade_material.tres, so the whole game's look
// is tuned by editing that one resource. Do not set a shader parameter on a
// node's material at runtime: it is the same resource everywhere, and the
// write would land on every graded plate at once.
//
// STRENGTH WAS HALVED TWICE, on 2026-09-22 and again on 2026-09-23, when the
// grade was extended to the minigames. A minigame screen is mostly one big
// painted plate, so contrast about mid-grey had far more of the screen to
// darken than it did in the Lobby, and the scenes read too dark. Saturation
// and contrast were each cut to half their distance from neutral, twice over:
// 1.07 -> 1.035 -> 1.0175, and 1.045 -> 1.0225 -> 1.01125. What is left is a
// quarter of the original grade, so the tint is now doing most of the work;
// tests/test_look_layer.gd pins the two as ceilings.
//
// KEEP IT SUBTLE. Characters are graded separately from the backgrounds they
// stand in front of -- they are separate nodes -- so a strong grade would pull
// them apart from their own scene. Judge any change on a full-size capture.
shader_type canvas_item;

// Pull towards or away from grey. 1.0 is untouched.
uniform float saturation : hint_range(0.0, 2.0) = 1.0175;
// Contrast about mid-grey. 1.0 is untouched.
uniform float contrast : hint_range(0.5, 2.0) = 1.01125;
// Overall gain, applied last. Slightly under 1 keeps the added contrast from
// clipping the cream highlights this palette is mostly made of.
uniform float exposure : hint_range(0.5, 2.0) = 0.995;
// Multiplied per channel: warms the art towards the paper-diorama palette
// without touching the tokens that describe the UI.
uniform vec4 tint : source_color = vec4(1.022, 1.0, 0.972, 1.0);
// How much of the grade to apply, 0 = off. A single dial for the whole game.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

// -- AO and rim knobs -------------------------------------------------------
// Both are zero on the plain material, so the backdrops that wear it pay
// nothing: the uniform is constant across a draw call, so the branch below is
// coherent and free. See the design doc for why the split exists.

// How dark the edge band goes. 0 disables AO for every plate wearing this
// material.
uniform float ao_strength : hint_range(0.0, 1.0) = 0.0;
// Width of the AO band, in SCREEN pixels -- not texels. See fwidth below.
uniform float ao_radius_px : hint_range(0.0, 24.0) = 6.0;
// What the occluded edge is tinted toward. Warm, to stay in the paper palette.
uniform vec4 ao_color : source_color = vec4(0.17, 0.11, 0.06, 1.0);
// How bright the lit edge gets. 0 disables the rim.
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
// Width of the rim, in SCREEN pixels.
uniform float rim_radius_px : hint_range(0.0, 16.0) = 3.0;
// Colour of the lit edge. Cream, matching the window light.
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
// Where the light is, in UV space. Upper-left, agreeing with the Lobby window,
// the streaks painted into the classroom floor, and the three contact shadows
// the artist authored offset down-right.
uniform vec2 light_dir = vec2(-0.6, -0.8);

// Rec. 709 luma, for a saturation that does not shift hues.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;

	// Fully transparent pixels have no edge and no colour. Skipping them here
	// matters: a desk plate is 92% transparent but the fragment shader still
	// runs on every pixel of its rect, and the transparency is contiguous, so
	// whole tiles take this branch together.
	if (src.a <= 0.0) {
		COLOR = src;
	} else {
		vec3 rgb = src.rgb;
		rgb = mix(vec3(dot(rgb, LUMA)), rgb, saturation);
		rgb = (rgb - vec3(0.5)) * contrast + vec3(0.5);
		rgb *= tint.rgb * exposure;
		vec3 graded = clamp(mix(src.rgb, rgb, amount), vec3(0.0), vec3(1.0));

		// UV covered by one screen pixel. This is what makes the band the same
		// visual width on a desk drawn at 1.0 and a racket drawn at 0.34.
		vec2 upp = fwidth(UV);

		// -- inner AO --------------------------------------------------------
		// Four taps of our own alpha. Deep inside, all four return 1 and edge
		// is 0. Near the rim some fall outside the silhouette and the average
		// drops. Ambient: no direction, all the way around.
		if (ao_strength > 0.0) {
			vec2 r = upp * ao_radius_px;
			float a = texture(TEXTURE, UV + vec2(r.x, 0.0)).a
				+ texture(TEXTURE, UV - vec2(r.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, r.y)).a
				+ texture(TEXTURE, UV - vec2(0.0, r.y)).a;
			float edge = clamp(1.0 - a * 0.25, 0.0, 1.0);
			graded = mix(graded, graded * ao_color.rgb, edge * ao_strength);
		}

		// -- rim -------------------------------------------------------------
		// One tap, offset toward the light. If the neighbour that way is
		// transparent while we are opaque, we are standing on the lit edge.
		// Additive, because light brightens what is behind it.
		if (rim_strength > 0.0) {
			vec2 rr = upp * rim_radius_px * normalize(light_dir);
			float behind = texture(TEXTURE, UV + rr).a;
			float lit = clamp(src.a - behind, 0.0, 1.0);
			graded += rim_color.rgb * (lit * rim_strength);
		}

		COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), src.a);
	}
}
