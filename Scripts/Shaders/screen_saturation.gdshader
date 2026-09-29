shader_type canvas_item;

// A screen-space saturation pass: everything drawn so far is pulled toward its
// own luminance by `saturation` (1 = unchanged, 0.7 = 30% less colour, 0 =
// greyscale). It reads the finished frame the way bloom.gdshader and
// blur.gdshader do, so it grades a whole composed scene -- a backdrop, the
// character over it, their shadow -- in one place instead of forking the shared
// illustration grade materials, which a dozen tests pin to one look.
//
// Multiplying the mix by the input COLOR.a is what makes it follow its node's
// modulate: a fading parent fades the grade too, instead of the desaturation
// popping in at full strength while the art fades (the light_shafts bug of
// 2026-09-28).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// 1.0 leaves the frame alone; 0.7 removes 30% of its colour.
uniform float saturation : hint_range(0.0, 2.0) = 0.7;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(grey), c, saturation), COLOR.a);
}
