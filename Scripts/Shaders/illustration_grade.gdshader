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
// TWO MATERIALS, ONE SHADER. Full-bleed backdrops wear
// Scripts/Shaders/illustration_grade_material.tres; plates with an alpha
// edge -- the desks, the faces, the shopkeeper -- wear
// Scripts/Shaders/illustration_grade_cutout.tres instead, so they can carry
// the inner AO and rim taps without every backdrop paying for taps it cannot
// show. Both materials carry their own copies of saturation, contrast,
// exposure, tint and amount, and BOTH MUST BE EDITED TOGETHER: they are
// meant to share one look, and tests/test_illustration_ao.gd asserts the two
// agree on those five. The AO and rim strengths are the deliberate
// exception -- they differ by design, since the plain material keeps both at
// zero. Do not set a shader parameter on either material at runtime: each is
// the same resource everywhere it is assigned, and the write would land on
// every plate wearing it at once.
//
// The Lobby's desks wear a third copy, illustration_grade_cutout_lobby.tres:
// the cutout material with light_dir mirrored to the upper right, because the
// Lobby is lit from that side and the rest of the game is not.
//
// STRENGTH WAS HALVED TWICE, on 2026-09-22 and again on 2026-09-23, when the
// grade was extended to the minigames. A minigame screen is mostly one big
// painted plate, so contrast about mid-grey had far more of the screen to
// darken than it did in the Lobby, and the scenes read too dark. Saturation
// and contrast were each cut to half their distance from neutral, twice over:
// 1.07 -> 1.035 -> 1.0175, and 1.045 -> 1.0225 -> 1.01125. What is left is a
// quarter of the original grade, so the tint is now doing most of the work;
// tests/test_look_layer.gd pins the two as ceilings. On 2026-09-24 contrast
// lost another 30% of its distance from neutral, 1.01125 -> 1.007875.
//
// KEEP IT SUBTLE. Characters are graded separately from the backgrounds they
// stand in front of -- they are separate nodes -- so a strong grade would pull
// them apart from their own scene. Judge any change on a full-size capture.
shader_type canvas_item;

// Pull towards or away from grey. 1.0 is untouched.
uniform float saturation : hint_range(0.0, 2.0) = 1.0175;
// Contrast about mid-grey. 1.0 is untouched.
uniform float contrast : hint_range(0.5, 2.0) = 1.007875;
// Overall gain, applied last. Slightly under 1 keeps the added contrast from
// clipping the cream highlights this palette is mostly made of.
uniform float exposure : hint_range(0.5, 2.0) = 0.995;
// Multiplied per channel: warms the art towards the paper-diorama palette
// without touching the tokens that describe the UI.
uniform vec4 tint : source_color = vec4(1.022, 1.0, 0.972, 1.0);
// How much of the whole effect to apply -- colour grade, inner AO and rim
// alike -- 0 = off. A single dial for the whole game: at 0 the art renders
// untouched, not just ungraded.
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
// How far to look, on all four sides of a transparent AO tap, for solid plate
// before calling the gap an interior hole, in TEXELS of the plate's own
// texture. 0 disables it.
//
// The AO has the same blind spot the rim had (see rim_hole_reject_texels): it
// darkens toward ANY transparent neighbour, so on the six Lobby faces it drew
// a brown ring inside every eye socket, which read as eyeshadow. The rim's
// discriminator does not carry over -- it probes along one light direction,
// and AO has none -- so this one asks a different question: is the gap walled
// in by plate on all four sides? An eye socket is; the air beside a head is
// open on at least one side. Must reach across the widest hole, so it is set
// per material, not globally.
//
// Texels, unlike every other width here, because a hole is a feature of the
// art, not of the screen: the same socket is 38-54 px wide on a 1080-wide
// phone, twice that on a 1440 one, and half that in the editor's embedded run.
uniform float ao_hole_reject_texels : hint_range(0.0, 400.0) = 0.0;
// How bright the lit edge gets. 0 disables the rim.
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
// Width of the rim, in SCREEN pixels.
uniform float rim_radius_px : hint_range(0.0, 16.0) = 3.0;
// How far along the light direction to look for solid plate before believing an
// edge is a real silhouette, in TEXELS of the plate's own texture. 0 disables
// the check.
//
// A cutout can have holes in its middle -- the six Lobby faces are drawn with
// the eye sockets and the mouth punched out, so the eyes, eyelids and brows
// underneath show through. The rim test cannot tell those edges from the
// outline of the head, so it drew a cream ring around every eye and mouth in
// the room. This is the discriminator: step further along the light from the
// lit edge. Off the outside of a plate you land on nothing; off the edge of an
// interior hole you land back on the face. Must be larger than the widest hole
// to reject, so it is set per material, not globally.
//
// Texels for the reason ao_hole_reject_texels gives: a hole belongs to the art.
// This was first a screen-pixel reach, tuned in the editor's half-size run,
// where 24 px spanned ~160 texels; on a 1080-wide phone the same 24 px spanned
// ~80 and left most of each eye ring in place.
uniform float rim_hole_reject_texels : hint_range(0.0, 400.0) = 0.0;
// Colour of the lit edge. Cream, matching the window light.
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
// Where the light is, in UV space. Upper-left by default, agreeing with the
// three contact shadows the artist authored offset down-right. The Lobby is
// the exception: its desks wear illustration_grade_cutout_lobby.tres and its
// faces illustration_grade_face.tres, both lit from the upper right.
uniform vec2 light_dir = vec2(-0.6, -0.8);

// Rec. 709 luma, for a saturation that does not shift hues.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;

	// UV covered by one screen pixel. Computed here, before the branch below,
	// because fwidth() (and the implicit-LOD texture() taps that use it) is
	// undefined behaviour inside non-uniform control flow -- and the alpha
	// silhouette this branches on is exactly where that divergence happens.
	// It happened to render fine on the desktop GPU this was authored on;
	// Adreno/Mali/PowerVR are not guaranteed to agree. This is also what
	// makes the AO/rim band the same visual width on a desk drawn at 1.0 and
	// a racket drawn at 0.34.
	vec2 upp = fwidth(UV);

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

		// -- inner AO --------------------------------------------------------
		// Four taps of our own alpha. Deep inside, all four return 1 and edge
		// is 0. Near the rim some fall outside the silhouette and the average
		// drops. Ambient: no direction, all the way around. textureLod (not
		// texture) because an implicit-LOD tap inside this branch is the same
		// undefined-derivative problem as fwidth above.
		//
		// Each tap counts an interior hole as solid plate. `reach` is
		// ao_hole_reject_texels in UV; zero skips the check. The check only
		// runs when the tap found transparency, so the solid middle of a face
		// -- most of its pixels -- pays nothing. Two probes per side, not one,
		// for the reason the rim gives: a single far probe steps clean over a
		// narrow band of plate.
		//
		// A loop here rather than a helper function, on purpose: a helper has
		// to take TEXTURE as a sampler2D argument, and the shader compiler
		// rejects a builtin texture passed that way ("custom_samplers.has(
		// tex_builtin)") -- nine ERROR lines on every headless load, which is
		// what failed project-check on PR #73.
		if (ao_strength > 0.0) {
			vec2 r = upp * ao_radius_px;
			vec2 reach = TEXTURE_PIXEL_SIZE * ao_hole_reject_texels;
			vec2 rx = vec2(reach.x, 0.0);
			vec2 ry = vec2(0.0, reach.y);
			vec2 taps[4] = vec2[](vec2(r.x, 0.0), vec2(-r.x, 0.0), vec2(0.0, r.y), vec2(0.0, -r.y));
			float sum = 0.0;
			for (int i = 0; i < 4; i++) {
				vec2 uv = UV + taps[i];
				float a = textureLod(TEXTURE, uv, 0.0).a;
				if (a < 1.0 && reach.x > 0.0) {
					float walled = min(
						min(max(textureLod(TEXTURE, uv + rx * 0.5, 0.0).a, textureLod(TEXTURE, uv + rx, 0.0).a),
							max(textureLod(TEXTURE, uv - rx * 0.5, 0.0).a, textureLod(TEXTURE, uv - rx, 0.0).a)),
						min(max(textureLod(TEXTURE, uv + ry * 0.5, 0.0).a, textureLod(TEXTURE, uv + ry, 0.0).a),
							max(textureLod(TEXTURE, uv - ry * 0.5, 0.0).a, textureLod(TEXTURE, uv - ry, 0.0).a)));
					a = max(a, walled);
				}
				sum += a;
			}
			float edge = clamp(1.0 - sum * 0.25, 0.0, 1.0);
			graded = mix(graded, graded * ao_color.rgb, edge * ao_strength * amount);
		}

		// -- rim -------------------------------------------------------------
		// One tap, offset toward the light. If the neighbour that way is
		// transparent while we are opaque, we are standing on the lit edge.
		// Additive, because light brightens what is behind it.
		if (rim_strength > 0.0) {
			vec2 rr = upp * rim_radius_px * normalize(light_dir);
			float behind = textureLod(TEXTURE, UV + rr, 0.0).a;
			float lit = clamp(src.a - behind, 0.0, 1.0);
			if (rim_hole_reject_texels > 0.0) {
				// Two probes, not one. A single distance only rejects holes of
				// roughly that width: an eye socket and an eyelash gap are an
				// order of magnitude apart, and the far probe steps clean over
				// the small one into the next hole. Taking the strongest hit of
				// a near and a far probe catches both.
				vec2 dir = normalize(light_dir) * TEXTURE_PIXEL_SIZE * rim_hole_reject_texels;
				float solid = max(
					textureLod(TEXTURE, UV + dir * 0.35, 0.0).a,
					textureLod(TEXTURE, UV + dir, 0.0).a);
				lit *= 1.0 - solid;
			}
			graded += rim_color.rgb * (lit * rim_strength * amount);
		}

		COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), src.a);
	}
}
