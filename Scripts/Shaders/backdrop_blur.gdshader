shader_type canvas_item;

// Blurs a backdrop TextureRect from the texture's own mip chain: the same soft
// look as blur.gdshader at the same `lod`, without reading the screen. A screen
// read at a mip level needs the GPU to build mipmaps of a framebuffer copy; the
// Compatibility renderer that low-end phones fall back to can hand back black,
// and the old opaque blur layer turned EventDialogue's whole backdrop black
// (2026-10-23). Every GPU samples an imported texture's mips, so the texture
// must be imported with mipmaps/generate=true (tests/test_event_dialogue.gd).
//
// UV is the TextureRect's own texture coordinate, so this follows its stretch
// mode (EventDialogue's keep-aspect-covered) with no extra maths.

// Mip level to read: 3 is an 8x downscale, the blur EventDialogue always had.
uniform float lod : hint_range(0.0, 5.0) = 3.0;
// How much to darken the blurred backdrop so the speaker and text stand out.
uniform float darkness : hint_range(0.0, 1.0) = 0.12;
// How far apart the nine reads sit, in texels of the level they read: wider is
// softer. 1.5 reads close to the old screen blur at the default lod.
uniform float spread : hint_range(0.5, 3.0) = 1.5;

// The Compatibility renderer samples inside a mip level without smoothing, so a
// single read at `lod` shows each texel as a hard block. Nine reads one level
// finer, spread over that level's texels, average into the same soft blur on
// any GPU.
void fragment() {
	float level = max(lod - 1.0, 0.0);
	vec2 step_uv = exp2(level) / vec2(textureSize(TEXTURE, 0));
	vec4 sum = vec4(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			sum += textureLod(TEXTURE, UV + vec2(float(x), float(y)) * step_uv * spread, level);
		}
	}
	vec4 c = sum / 9.0;
	COLOR = vec4(c.rgb * (1.0 - darkness), c.a);
}
