// 呼吸式"圆形发光":中心亮、边缘渐隐
shader_type canvas_item;

uniform vec3  inner_color : source_color = vec3(1.0, 0.9, 0.4);
uniform vec3  outer_color : source_color = vec3(0.9, 0.1, 0.2);
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float falloff     : hint_range(0.5, 6.0) = 2.5;

void fragment() {
    vec2 uv = UV;
    float d = distance(uv, vec2(0.5));

    // 呼吸缩放圆的"亮范围"
    float radius = 0.25 + 0.05 * sin(TIME * pulse_speed);
    float t = smoothstep(radius * 1.6, radius, d);
    t = pow(t, falloff);

    vec3 col = mix(outer_color, inner_color, t);
    float alpha = 1.0 - smoothstep(0.42, 0.5, d);   // 圆形 mask
    COLOR = vec4(col, alpha);
}
