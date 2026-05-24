// HSV 彩虹滚动 —— 把屏幕坐标当 hue,加 TIME 偏移
shader_type canvas_item;

uniform float speed     : hint_range(0.0, 4.0) = 0.6;
uniform float saturation: hint_range(0.0, 1.0) = 0.85;
uniform float brightness: hint_range(0.0, 1.0) = 0.9;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    float hue = fract(UV.x * 1.0 + UV.y * 0.3 + TIME * speed);
    COLOR.rgb = hsv2rgb(vec3(hue, saturation, brightness));
}
