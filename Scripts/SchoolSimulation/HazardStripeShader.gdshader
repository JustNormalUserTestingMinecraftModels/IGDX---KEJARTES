shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform vec4 color2 : source_color = vec4(0.06, 0.06, 0.06, 1.0);
uniform float speed : hint_range(-10.0, 10.0) = 2.0;
uniform float stripe_width : hint_range(1.0, 100.0) = 16.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;

void fragment() {
	// Rotate coordinates based on angle
	float rad = radians(angle);
	float x_rot = UV.x * cos(rad) - UV.y * sin(rad);
	
	// Create repeating pattern that moves over time
	float value = fract(x_rot * stripe_width - TIME * speed);
	float pattern = step(0.5, value);
	
	COLOR = mix(color2, color1, pattern);
}
