shader_type canvas_item;

// SkinSelect's per-card focus (spec
// docs/superpowers/specs/2026-09-23-skin-select-slide-design.md). Blurs and
// dims the card's OWN texture. blur.gdshader samples the screen instead,
// which on a card draws the background where the splash should be.
// SkinCard.set_pose drives both uniforms every frame the carousel moves.

// Gaussian sigma in texture pixels. 0 skips the blur entirely.
uniform float sigma_texels = 0.0;
// Multiplier on rgb: 1.0 untouched, the neighbour slot uses 0.71.
uniform float brightness = 1.0;

// Golden-angle spiral taps covering ~3 sigma. A 2D Gaussian truncated at
// 2 sigma under-blurs (effective sigma ~0.83x what was asked for); 3 sigma
// keeps it close to the true value (~0.97x). TAPS is raised to keep the
// wider disk dense.
const int TAPS = 48;
const float GOLDEN_ANGLE = 2.39996323;

void fragment() {
	vec4 c;
	if (sigma_texels < 0.05) {
		c = texture(TEXTURE, UV);
	} else {
		// Premultiplied, so transparent texels' colour never bleeds into
		// the silhouette.
		vec4 acc = vec4(0.0);
		float wsum = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float r = sqrt((float(i) + 0.5) / float(TAPS)) * sigma_texels * 3.0;
			float a = float(i) * GOLDEN_ANGLE;
			vec2 off = vec2(cos(a), sin(a)) * r * TEXTURE_PIXEL_SIZE;
			// r = sqrt((i+0.5)/TAPS) * 3*sigma, so r^2/(2*sigma^2) reduces to
			// 4.5*(i+0.5)/TAPS regardless of sigma; skip the redundant division.
			float w = exp(-4.5 * (float(i) + 0.5) / float(TAPS));
			vec4 s = texture(TEXTURE, UV + off);
			acc += vec4(s.rgb * s.a, s.a) * w;
			wsum += w;
		}
		acc /= wsum;
		c = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
	}
	// * COLOR reapplies the node's (and every inherited parent's) modulate,
	// which canvas_item shaders otherwise discard; SkinSelect fades cards by
	// tweening modulate.a, so dropping this stopped the splash art fading.
	COLOR = vec4(c.rgb * brightness, c.a) * COLOR;
}
