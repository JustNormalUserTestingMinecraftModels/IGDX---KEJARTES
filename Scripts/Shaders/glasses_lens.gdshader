// Glasses on a lobby face rig (StudentFace): the frame draws as a plain
// opaque stroke, while the lens ADDS light to whatever is behind it.
//
// That split is how Marcel's flat portrait (MuridPotrait/Marcel.png) was
// flattened. Fitted 2026-09-14 over bare cheek seen through the lens: the
// portrait is base + glasses.rgb * alpha * gain, not an alpha mix -- a mix
// greys his eyes where the portrait keeps them bright white. The frame, in
// contrast, is simply the texture's own dark colour.
//
// blend_premul_alpha lets one texture do both. Its output is
// src.rgb + dst.rgb * (1 - src.a): a lens pixel emits src.a = 0 (pure
// addition) and a frame pixel src.a = 1 (a normal opaque draw). The node's
// modulate is not applied; nothing in the lobby fades a face on its own.
shader_type canvas_item;
render_mode blend_premul_alpha;

// Multiplier on the light the lens adds, fitted per character.
uniform float lens_gain = 1.0;
// Texture alpha at which a pixel starts to count as frame rather than lens.
// Marcel's lens tops out near 0.9 and his frame starts at 0.97.
uniform float frame_alpha_from : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float frame = smoothstep(frame_alpha_from, 1.0, tex.a);
	vec3 lens_light = tex.rgb * tex.a * lens_gain;
	COLOR = vec4(mix(lens_light, tex.rgb, frame), frame);
}
