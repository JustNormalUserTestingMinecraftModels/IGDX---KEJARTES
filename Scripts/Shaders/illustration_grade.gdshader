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
// KEEP IT SUBTLE. Characters are graded separately from the backgrounds they
// stand in front of -- they are separate nodes -- so a strong grade would pull
// them apart from their own scene. Judge any change on a full-size capture.
shader_type canvas_item;

// Pull towards or away from grey. 1.0 is untouched.
uniform float saturation : hint_range(0.0, 2.0) = 1.07;
// Contrast about mid-grey. 1.0 is untouched.
uniform float contrast : hint_range(0.5, 2.0) = 1.045;
// Overall gain, applied last. Slightly under 1 keeps the added contrast from
// clipping the cream highlights this palette is mostly made of.
uniform float exposure : hint_range(0.5, 2.0) = 0.995;
// Multiplied per channel: warms the art towards the paper-diorama palette
// without touching the tokens that describe the UI.
uniform vec4 tint : source_color = vec4(1.022, 1.0, 0.972, 1.0);
// How much of the grade to apply, 0 = off. A single dial for the whole game.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

// Rec. 709 luma, for a saturation that does not shift hues.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;

	// Grade in straight (un-premultiplied) colour, then hand the alpha back
	// untouched. Every plate here is a cutout, and multiplying alpha would
	// eat the soft edges the art is drawn with.
	vec3 rgb = src.rgb;
	rgb = mix(vec3(dot(rgb, LUMA)), rgb, saturation);
	rgb = (rgb - vec3(0.5)) * contrast + vec3(0.5);
	rgb *= tint.rgb * exposure;

	COLOR = vec4(clamp(mix(src.rgb, rgb, amount), vec3(0.0), vec3(1.0)), src.a);
}
