shader_type canvas_item;

uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform vec2 rect_size = vec2(1152.0, 648.0);
uniform vec2 hole_pos = vec2(100.0, 100.0);
uniform vec2 hole_size = vec2(200.0, 80.0);
uniform float feather : hint_range(0.0, 50.0) = 10.0;

void fragment() {
    vec2 pixel = UV * rect_size;
    vec2 half_size = hole_size * 0.5;
    vec2 center = hole_pos + half_size;
    vec2 d = abs(pixel - center) - half_size;
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    float mask = smoothstep(0.0, feather, dist);
    COLOR = vec4(overlay_color.rgb, overlay_color.a * mask);
}