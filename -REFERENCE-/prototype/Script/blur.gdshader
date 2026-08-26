shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 5.0) = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 blur = textureLod(screen_texture, SCREEN_UV, lod);
	COLOR = vec4(blur.rgb * (1.0 - darkness), 1.0);
}
