// Soft ambient-occlusion shadow behind a cutout illustration (the event
// dialogue's and the minigame win screen's speaker splash).
//
// It reads the illustration's own alpha at two blurred mip levels -- a near
// one that hugs the outline and a far one that fades wide -- and paints that
// in one flat colour. No offset and no hard edge: the shade is darkest right
// at the figure and falls off over roughly 60-130 px, like ambient occlusion,
// instead of the stamped silhouette a drop shadow gives.
//
// NEEDS MIPMAPS. textureLod only blurs when the texture was imported with
// mipmaps/generate=true (every splash is) and the node samples with a mipmap
// filter (SplashShadow sets texture_filter to LINEAR_WITH_MIPMAPS).
//
// Do not multiply by COLOR.a: on entry it holds the texture's own alpha, which
// is zero outside the figure, and would erase the shadow the blur just spread
// there (the first 2026-10-01 preview did exactly that).
shader_type canvas_item;

// Mip level of the near blur, the shade that hugs the outline. Each step
// doubles the radius; 4.5 is about 22 source px.
uniform float near_lod : hint_range(0.0, 10.0) = 4.5;
// Mip level of the wide falloff. 7.0 is about 128 source px.
uniform float far_lod : hint_range(0.0, 10.0) = 7.0;
// Share of the near blur in the mix, 0 to 1; the rest is the wide falloff.
uniform float near_weight : hint_range(0.0, 1.0) = 0.4;
// The shade's colour; its alpha is the strength (the owner's pick: 65%).
uniform vec4 shadow_color : source_color = vec4(0.12, 0.07, 0.03, 0.65);

void fragment() {
	float near = textureLod(TEXTURE, UV, near_lod).a;
	float far = textureLod(TEXTURE, UV, far_lod).a;
	float occlusion = clamp(near * near_weight + far * (1.0 - near_weight), 0.0, 1.0);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * occlusion);
}
