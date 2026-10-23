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

void fragment() {
	vec4 c = textureLod(TEXTURE, UV, lod);
	COLOR = vec4(c.rgb * (1.0 - darkness), c.a);
}
