// Paper flutter for confetti particles. Squashes each piece's quad along its
// own x axis by cos(time), so a flat sheet reads as tumbling in 3D, and
// darkens the back face so the flip is legible. Phase and speed are hashed
// per particle from INSTANCE_ID. In a 2D canvas shader the particle's
// instance transform is folded into MODEL_MATRIX, so VERTEX here is still
// the quad's local space and the squash follows each piece's own rotation.
// Used by Scenes/SchoolSimulation/PaperConfetti.tscn.
shader_type canvas_item;

// Base flip rate, radians per second.
uniform float flip_speed : hint_range(0.0, 30.0) = 7.0;
// Per-piece speed spread, as a +/- fraction of flip_speed.
uniform float flip_speed_jitter : hint_range(0.0, 1.0) = 0.5;
// How much darker the back face is (0 = same as the front, 1 = black).
uniform float back_shade : hint_range(0.0, 1.0) = 0.35;

varying float shade;

// Integer hash to [0, 1).
float hash01(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 2147483647u) / 2147483648.0;
}

void vertex() {
	uint id = uint(INSTANCE_ID);
	float speed = flip_speed * (1.0 + flip_speed_jitter * (2.0 * hash01(id) - 1.0));
	float c = cos(TIME * speed + hash01(id + 7919u) * TAU);
	VERTEX.x *= c;
	shade = mix(1.0, 1.0 - back_shade, step(c, 0.0));
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb *= shade;
}
