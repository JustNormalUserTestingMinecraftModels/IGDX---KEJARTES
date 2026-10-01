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
// The card's own splash again, read for the blur. Written when the project
// default was Nearest Mipmap (3), which made a mip read blocky; the default is
// Linear Mipmap (2) since 2026-10-01, and this sampler keeps the blur linear
// whatever the default says. SkinCard.show_skin binds it.
uniform sampler2D blur_source : filter_linear_mipmap, repeat_disable;

// Rec. 709 luma, for a saturation that does not shift hues.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// NO COLOUR GRADE HERE, on purpose (2026-09-30): the illustration grade that
// every other painted plate wears made Skin Select's splashes read too dark,
// so the cards show the art's own colours. Only the focus blur, the
// neighbour dimming (`brightness`), the flat `splash_gain` and the owner's
// `splash_saturation` / `splash_contrast` touch the splash;
// tests/test_skin_card.gd pins that.

// THE BLUR IS THE SPLASH'S OWN MIP CHAIN (2026-09-30 mobile performance
// pass). It was a 48-tap golden-angle spiral: on a neighbour card, which
// covers most of the screen, that is tens of millions of texture reads a
// frame, the kind of cost a phone GPU feels most. A mip level is already the
// art averaged over a square of texels, so reading the level whose texel is
// about as wide as the blur does the same job in one tap; four more, half a
// footprint out on the diagonals, hide the mip's blockiness. Five taps,
// whatever the radius. Every splash the carousel shows must carry mipmaps
// (tests/test_skin_card.gd pins that), or this reads level 0 and blurs
// nothing.
//
// How many texels wide the chosen mip's texel is, per texel of sigma. A box
// that wide, read bilinearly with the diagonal taps below, was matched by eye
// to the old Gaussian at 1.0 on a side-by-side capture (2.0 was visibly
// softer). Judge a change the same way.
const float FOOTPRINT_PER_SIGMA = 1.0;

void fragment() {
	vec4 c;
	if (sigma_texels < 0.05) {
		c = texture(TEXTURE, UV);
	} else {
		float footprint = max(sigma_texels * FOOTPRINT_PER_SIGMA, 1.0);
		float lod = log2(footprint);
		vec2 d = TEXTURE_PIXEL_SIZE * footprint * 0.5;
		// Premultiplied, so transparent texels' colour never bleeds into
		// the silhouette.
		vec4 s0 = textureLod(blur_source, UV, lod);
		vec4 s1 = textureLod(blur_source, UV + vec2(d.x, d.y), lod);
		vec4 s2 = textureLod(blur_source, UV + vec2(-d.x, d.y), lod);
		vec4 s3 = textureLod(blur_source, UV + vec2(d.x, -d.y), lod);
		vec4 s4 = textureLod(blur_source, UV + vec2(-d.x, -d.y), lod);
		vec4 acc = vec4(s0.rgb * s0.a, s0.a) * 0.4
			+ (vec4(s1.rgb * s1.a, s1.a) + vec4(s2.rgb * s2.a, s2.a)
			+ vec4(s3.rgb * s3.a, s3.a) + vec4(s4.rgb * s4.a, s4.a)) * 0.15;
		vec4 soft = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
		// Eased in over the first texel of sigma. The sharp read above is
		// one tap and the soft one averages five spread around it, so a hard switch would
		// soften the centred card by a visible step the moment a drag begins.
		c = mix(texture(TEXTURE, UV), soft, smoothstep(0.05, 1.0, sigma_texels));
	}
	// * COLOR reapplies the node's (and every inherited parent's) modulate,
	// which canvas_item shaders otherwise discard; SkinSelect fades cards by
	// tweening modulate.a, so dropping this stopped the splash art fading.
	vec3 rgb = mix(vec3(dot(c.rgb, LUMA)), c.rgb, splash_saturation);
	rgb = (rgb - vec3(0.5)) * splash_contrast + vec3(0.5);
	COLOR = vec4(rgb * brightness * splash_gain, c.a) * COLOR;
}
