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

// Golden-angle spiral taps covering ~2 sigma. Enough for a sigma of
// 4-6 texels on two cards at a time.
const int TAPS = 32;
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
			float r = sqrt((float(i) + 0.5) / float(TAPS)) * sigma_texels * 2.0;
			float a = float(i) * GOLDEN_ANGLE;
			vec2 off = vec2(cos(a), sin(a)) * r * TEXTURE_PIXEL_SIZE;
			float w = exp(-(r * r) / (2.0 * sigma_texels * sigma_texels));
			vec4 s = texture(TEXTURE, UV + off);
			acc += vec4(s.rgb * s.a, s.a) * w;
			wsum += w;
		}
		acc /= wsum;
		c = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
	}
	COLOR = vec4(c.rgb * brightness, c.a);
}
