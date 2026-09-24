// The cream paper of a DayStickyNote: the note's own texture, washed with a
// subtle vertical gradient from `top_color` to `bottom_color`.
//
// WHY A SHADER. The paper is a TextureButton drawing stickynotes.png, a
// tilted note with an alpha edge, and a TextureButton takes no StyleBox. A
// gradient node laid over it would not follow the tilted silhouette; this
// multiplies inside the texture's own alpha, so the shape stays the art's.
//
// Both colours are written by DayStickyNote.gd from DesignTokens
// (surface_card at the top, the warmer surface_page at the bottom), so the
// paper follows the tokens like the rest of the UI. The defaults here are
// white, which leaves the art untouched until the script sets them.
//
// The paper is never tinted by category any more (2026-09-24, AturJadwal
// visual polish D2): a saturated slab failed text contrast. The category
// colour lives on the WashiTape node instead.
shader_type canvas_item;

// Tint at the top edge of the note's rect.
uniform vec4 top_color : source_color = vec4(1.0);
// Tint at the bottom edge of the note's rect.
uniform vec4 bottom_color : source_color = vec4(1.0);

void fragment() {
	// Reading COLOR switches off the default texture multiply, so the texture
	// is sampled here; COLOR still carries the node's modulate.
	COLOR = texture(TEXTURE, UV) * COLOR * mix(top_color, bottom_color, UV.y);
}
