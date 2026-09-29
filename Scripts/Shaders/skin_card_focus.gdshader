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
// Gain on every card's splash, on top of `brightness` (2026-09-30): the
// owner asked for Skin Select's splashes 25% brighter, so 1.25 lifts the
// centred card and its dimmed neighbours alike.
uniform float splash_gain = 1.25;
// Owner request (2026-09-30): the splashes 15% less saturated and 15% less
// contrasty. 1.0 is untouched; saturation pulls toward grey, contrast toward
// mid-grey, both before the brightness and the gain.
uniform float splash_saturation = 0.85;
uniform float splash_contrast = 0.85;

// Rec. 709 luma, for a saturation that does not shift hues.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// NO COLOUR GRADE HERE, on purpose (2026-09-30): the illustration grade that
// every other painted plate wears made Skin Select's splashes read too dark,
// so the cards show the art's own colours. Only the focus blur, the
// neighbour dimming (`brightness`), the flat `splash_gain` and the owner's
// `splash_saturation` / `splash_contrast` touch the splash;
// tests/test_skin_card.gd pins that.

// Golden-angle spiral taps covering ~3 sigma. A 2D Gaussian truncated at
// 2 sigma under-blurs (effective sigma ~0.83x what was asked for); 3 sigma
// keeps it close to the true value (~0.97x). TAPS is raised to keep the
// wider disk dense.
const int TAPS = 48;
const float GOLDEN_ANGLE = 2.39996323;
// Spiral reach in sigmas (see the TAPS comment above): how far the taps
// extend before the Gaussian is truncated. Coupled to the weight formula
// below -- change one, change the other.
const float REACH = 3.0;

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
			float r = sqrt((float(i) + 0.5) / float(TAPS)) * sigma_texels * REACH;
			float a = float(i) * GOLDEN_ANGLE;
			vec2 off = vec2(cos(a), sin(a)) * r * TEXTURE_PIXEL_SIZE;
			// r = sqrt((i+0.5)/TAPS) * REACH*sigma, so r^2/(2*sigma^2) reduces to
			// 0.5*REACH*REACH*(i+0.5)/TAPS regardless of sigma; skip the
			// redundant division.
			float w = exp(-0.5 * REACH * REACH * (float(i) + 0.5) / float(TAPS));
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
	vec3 rgb = mix(vec3(dot(c.rgb, LUMA)), c.rgb, splash_saturation);
	rgb = (rgb - vec3(0.5)) * splash_contrast + vec3(0.5);
	COLOR = vec4(rgb * brightness * splash_gain, c.a) * COLOR;
}
