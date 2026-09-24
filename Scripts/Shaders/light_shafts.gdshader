shader_type canvas_item;
render_mode blend_add;

// Light shafts through a window. The rotating-shaft half of
// achievement_glow.gdshader, pulled out without the pulsing starburst core so a
// room can have sunlight without looking like an achievement popped.
//
// WHY ADDITIVE. blend_add only ever brightens what is behind it, which is what
// light does. An alpha-blended overlay would replace the art's colour with its
// own wherever it is opaque, flattening exactly the detail the light is
// supposed to reveal. Same reasoning as light_falloff.gdshader.
//
// THE CREAM PROBLEM, AND WHY IT DID NOT BITE HERE. This palette is mostly
// near-white -- surface_page is #FBF1E3 -- so additive light normally clips to
// flat white almost immediately: the window light beside these ships at 0.11
// against a measured knee of 0.12. Shafts were expected to behave the same and
// do not, because they cover a small fraction of the screen and fall mostly on
// the mid-tone classroom wall rather than on paper. Swept over the frozen Lobby
// at 1080x1920: 0.03 left the frame bit-identical, and 0.20 -- the top of the
// range -- moved whole-frame mean luminance by only +0.170% and drove 3 extra
// pixels to pure white out of ~127,000 sampled. It ships at 0.20, chosen from
// six real frames. Judge any change on a full-size capture, and re-sweep rather
// than assuming the knee is where the window light's is.

// Colour of the light. Warm, matching the window pool it sits beside.
uniform vec4 shaft_color : source_color = vec4(1.0, 0.898, 0.706, 1.0);
// Peak brightness. Keep it low over cream; see the header.
uniform float intensity : hint_range(0.0, 0.5) = 0.2;
// Where the shafts converge, in UV. The window, which is up and to the left.
uniform vec2 origin = vec2(0.12, -0.08);
// How many shafts. Fewer and wider reads as sun; many and thin reads as a
// starburst, which is the effect this was extracted to avoid.
uniform float shaft_count = 7.0;
// Edge softness of each shaft. Higher is softer.
uniform float softness : hint_range(1.0, 12.0) = 5.0;
// How far from the origin the shafts fade out, in UV.
uniform float reach : hint_range(0.1, 3.0) = 1.4;
// Speed of the slow drift. Dust moves; sunlight does not strobe.
uniform float drift_speed = 0.035;

void fragment() {
	vec2 p = UV - origin;
	float dist = length(p) / reach;
	float sector = (atan(p.y, p.x) + TIME * drift_speed) / TAU * shaft_count;
	float across = abs(fract(sector) - 0.5) * 2.0;
	float shaft = pow(1.0 - across, softness);
	float fade = smoothstep(1.0, 0.15, dist);
	COLOR = vec4(shaft_color.rgb, 1.0) * (shaft * fade * intensity);
}
